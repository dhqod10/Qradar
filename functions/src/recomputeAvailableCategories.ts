/**
 * availableMainCategories 재계산 I/O 코어 (store_category_optout Phase B, spec §12.1.3~4).
 * 트리거 5개와 백필 콜러블이 **같은 코어**를 쓴다. 증분이 아니라 소스에서 **전량 재계산** → 멱등.
 *
 * 쓰기는 `stores/{s}.availableMainCategories` 1필드뿐 (updatedAt 등 건드리지 않음). 계산값 == 저장값이면 write 생략(루프·churn 방지).
 */

import * as admin from "firebase-admin";
import { computeAvailableMainCategories, sameCodeSet, BrandMasterMenu } from "./availableCategories";
import { RawDoc } from "./menuVisibility";

export const FIELD = "availableMainCategories";
const CHUNK = 400;
const CONCURRENCY = 10;

export interface SharedReads {
  activeCodes: Set<string>;
  /** brandId → 마스터 메뉴 (브랜드 fan-out 1회당 1번 읽어 매장 루프에서 공유). */
  masters: Map<string, BrandMasterMenu[]>;
}

export interface StorePlan {
  storeId: string;
  before: unknown;
  after: string[];
  changed: boolean;
}

/** mainCategories 에서 active 인 id 집합 (active 부재 = true — Dart `MainCategoryModel`). */
export async function loadActiveCodes(db: admin.firestore.Firestore): Promise<Set<string>> {
  const snap = await db.collection("mainCategories").get();
  const out = new Set<string>();
  for (const d of snap.docs) if (d.get("active") !== false) out.add(d.id);
  return out;
}

export async function loadMasters(
  db: admin.firestore.Firestore,
  shared: SharedReads,
  brandId: string
): Promise<BrandMasterMenu[]> {
  const cached = shared.masters.get(brandId);
  if (cached) return cached;
  const snap = await db.collection("brands").doc(brandId).collection("menuItems").get();
  const list = snap.docs.map((d) => ({ id: d.id, data: d.data() as RawDoc }));
  shared.masters.set(brandId, list);
  return list;
}

/** 매장 1곳 계산 (쓰기 없음). storeData = stores/{s} 문서 data. */
export async function planStore(
  db: admin.firestore.Firestore,
  storeId: string,
  storeData: RawDoc,
  shared: SharedReads
): Promise<StorePlan> {
  const storeRef = db.collection("stores").doc(storeId);
  const brandId = typeof storeData.brandId === "string" && storeData.brandId !== "" ? storeData.brandId : null;
  const [ownSnap, overrideSnap, masters] = await Promise.all([
    storeRef.collection("menuItems").get(),
    brandId ? storeRef.collection("menuOverrides").get() : Promise.resolve(null),
    brandId ? loadMasters(db, shared, brandId) : Promise.resolve(null),
  ]);
  const overrides = new Map<string, RawDoc>();
  overrideSnap?.docs.forEach((d) => overrides.set(d.id, d.data() as RawDoc));
  const optedOut = Array.isArray(storeData.excludedMainCategories)
    ? storeData.excludedMainCategories.filter((x): x is string => typeof x === "string")
    : [];
  const after = computeAvailableMainCategories({
    storeOwnMenus: ownSnap.docs.map((d) => d.data() as RawDoc),
    brandMasterMenus: masters,
    storeOverrides: overrides,
    activeCodes: shared.activeCodes,
    excludedByStore: optedOut,
  });
  const before = storeData[FIELD];
  return { storeId, before, after, changed: !sameCodeSet(before, after) };
}

/** 변경된 plan 만 400건 청크 배치로 쓴다. 쓴 건수 반환. */
export async function commitPlans(db: admin.firestore.Firestore, plans: StorePlan[]): Promise<number> {
  const changed = plans.filter((p) => p.changed);
  for (let i = 0; i < changed.length; i += CHUNK) {
    const batch = db.batch();
    for (const p of changed.slice(i, i + CHUNK)) {
      batch.update(db.collection("stores").doc(p.storeId), { [FIELD]: p.after });
    }
    await batch.commit();
  }
  return changed.length;
}

/** 매장 목록을 제한된 동시성으로 계산한다. */
export async function planStores(
  db: admin.firestore.Firestore,
  stores: Array<{ id: string; data: RawDoc }>,
  shared: SharedReads
): Promise<StorePlan[]> {
  const plans: StorePlan[] = [];
  for (let i = 0; i < stores.length; i += CONCURRENCY) {
    const part = await Promise.all(stores.slice(i, i + CONCURRENCY).map((s) => planStore(db, s.id, s.data, shared)));
    plans.push(...part);
  }
  return plans;
}

export function newShared(activeCodes: Set<string>): SharedReads {
  return { activeCodes, masters: new Map() };
}

/** 단일 매장 재계산 + (다르면) 쓰기. 매장이 없으면 skip. */
export async function recomputeStore(storeId: string, storeData?: RawDoc): Promise<void> {
  const db = admin.firestore();
  let data = storeData;
  if (data == null) {
    const snap = await db.collection("stores").doc(storeId).get();
    if (!snap.exists) return;
    data = snap.data() as RawDoc;
  }
  const shared = newShared(await loadActiveCodes(db));
  const plan = await planStore(db, storeId, data, shared);
  if (plan.changed) await commitPlans(db, [plan]);
}

/** 한 브랜드 산하 전 매장 fan-out (마스터는 1회만 읽는다). 갱신 건수 반환. */
export async function recomputeBrandStores(brandId: string): Promise<{ total: number; written: number }> {
  const db = admin.firestore();
  const snap = await db.collection("stores").where("brandId", "==", brandId).get();
  const shared = newShared(await loadActiveCodes(db));
  const plans = await planStores(db, snap.docs.map((d) => ({ id: d.id, data: d.data() as RawDoc })), shared);
  return { total: snap.size, written: await commitPlans(db, plans) };
}

/** 전 매장 fan-out. */
export async function recomputeAllStores(): Promise<{ total: number; written: number }> {
  const db = admin.firestore();
  const snap = await db.collection("stores").get();
  const shared = newShared(await loadActiveCodes(db));
  const plans = await planStores(db, snap.docs.map((d) => ({ id: d.id, data: d.data() as RawDoc })), shared);
  return { total: snap.size, written: await commitPlans(db, plans) };
}
