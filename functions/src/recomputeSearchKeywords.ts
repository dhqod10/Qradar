/**
 * stores.searchKeywords 재계산 I/O 코어 (search_keyword_enhancement). 트리거 2개와 백필이 같은 코어를 쓴다.
 * 소스 = 매장명 + (가맹점이면) 브랜드명 + menuCategories. 전량 재계산 → 멱등. 같은 값이면 write 생략(루프·churn 방지).
 * 쓰기는 `searchKeywords` 1필드뿐 (updatedAt 등 무변경).
 */
import * as admin from "firebase-admin";
import { RawDoc } from "./menuVisibility";
import { buildKeywords, sameKeywords } from "./searchKeywords";

export const FIELD = "searchKeywords";
const CHUNK = 400;
const CONCURRENCY = 10;

export interface KeywordPlan {
  storeId: string;
  before: unknown;
  after: string[];
  changed: boolean;
}

/** brandId → 브랜드명 (없으면 null). 한 실행 안에서 캐시 공유. */
export type BrandNameCache = Map<string, string | null>;

export async function loadBrandName(
  db: admin.firestore.Firestore,
  cache: BrandNameCache,
  brandId: string
): Promise<string | null> {
  if (cache.has(brandId)) return cache.get(brandId) ?? null;
  const snap = await db.collection("brands").doc(brandId).get();
  const n = snap.exists ? snap.get("name") : null;
  const name = typeof n === "string" && n.trim() !== "" ? n : null;
  cache.set(brandId, name);
  return name;
}

/** 소스 문자열 조립 (순수). */
export function assembleSources(store: RawDoc, brandName: string | null): string[] {
  const out: string[] = [];
  if (typeof store.name === "string") out.push(store.name);
  if (brandName != null) out.push(brandName);
  if (Array.isArray(store.menuCategories)) {
    for (const c of store.menuCategories) if (typeof c === "string") out.push(c);
  }
  return out;
}

export async function planStore(
  db: admin.firestore.Firestore,
  storeId: string,
  store: RawDoc,
  cache: BrandNameCache
): Promise<KeywordPlan> {
  const brandId = typeof store.brandId === "string" && store.brandId !== "" ? store.brandId : null;
  const brandName = brandId ? await loadBrandName(db, cache, brandId) : null;
  const after = buildKeywords(assembleSources(store, brandName));
  const before = store[FIELD];
  return { storeId, before, after, changed: !sameKeywords(before, after) };
}

export async function planStores(
  db: admin.firestore.Firestore,
  stores: Array<{ id: string; data: RawDoc }>,
  cache: BrandNameCache
): Promise<KeywordPlan[]> {
  const plans: KeywordPlan[] = [];
  for (let i = 0; i < stores.length; i += CONCURRENCY) {
    plans.push(...(await Promise.all(stores.slice(i, i + CONCURRENCY).map((s) => planStore(db, s.id, s.data, cache)))));
  }
  return plans;
}

export async function commitPlans(db: admin.firestore.Firestore, plans: KeywordPlan[]): Promise<number> {
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

/** 단일 매장 재계산 + (다르면) 쓰기. */
export async function recomputeStoreSearchKeywords(storeId: string, storeData?: RawDoc): Promise<void> {
  const db = admin.firestore();
  let data = storeData;
  if (data == null) {
    const snap = await db.collection("stores").doc(storeId).get();
    if (!snap.exists) return;
    data = snap.data() as RawDoc;
  }
  const plan = await planStore(db, storeId, data, new Map());
  if (plan.changed) await commitPlans(db, [plan]);
}

/** 한 브랜드 산하 전 매장 fan-out. */
export async function recomputeBrandSearchStores(brandId: string): Promise<{ total: number; written: number }> {
  const db = admin.firestore();
  const snap = await db.collection("stores").where("brandId", "==", brandId).get();
  const plans = await planStores(db, snap.docs.map((d) => ({ id: d.id, data: d.data() as RawDoc })), new Map());
  return { total: snap.size, written: await commitPlans(db, plans) };
}
