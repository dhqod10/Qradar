/**
 * auditBrandLinks — **임시** callable (admin 전용, **읽기 전용**). 브랜드 계정·브랜드·매장의 연결 상태를 분류해 보고한다.
 *
 * **상시 운영 점검 도구다** (임시 자산에서 승격). 이유: 브랜드 링크는 admin 의 Console 편집·문서 삭제·데이터 복구로 언제든 다시
 * 어긋날 수 있고, 데이터 유실 사고의 복구 검증에서 실제로 값을 했다. 읽기 전용(쓰기 0, 인자 없음)이라 유지 비용·위험이 작다.
 *
 * **쓰기 0. 요청 인자 자체가 없다 (dryRun 도 없다).** 자동 교정 금지 — 의도를 추측할 수 없으면 손대지 않는다.
 * `mismatch` 는 공격 증거가 아니다: admin 이 Console 로 수동 발급한 레거시 계정도 `submittedBy` 가 admin 이거나 부재다.
 *
 * 분류:
 *   users (role == 'brand')  brandId 부재 -> ok_onboarding / brands 문서 없음 -> dangling /
 *                            submittedBy != uid -> mismatch / 그 외 -> ok
 *   duplicate                같은 brandId 를 가진 brand 계정이 2명 이상 (양쪽 모두 보고). duplicate 인 계정은 ok 집계에서 제외한다.
 *   orphan_brand             어떤 users 도 brandId 로 가리키지 않는 브랜드 문서
 *   store_dangling_brand     stores.brandId 가 가리키는 브랜드 문서가 없음
 *   store_unapproved_brand   stores.brandId 가 가리키는 브랜드가 approved 가 아님
 *
 * 응답: { counts: { <분류>: number }, items: { <분류>: Item[] (각 최대 100) }, truncated: { <분류>: boolean } }
 *       ok / ok_onboarding 은 건수만 (목록 없음).
 */

import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { REGION, requireAdmin } from "./qoinAdmin";

const LOG = "[auditBrandLinks]";
const ITEM_MAX = 100;
const PAGE = 500;
const GET_ALL_CHUNK = 300;

const CLASSES = [
  "ok",
  "ok_onboarding",
  "dangling",
  "mismatch",
  "duplicate",
  "orphan_brand",
  "store_dangling_brand",
  "store_unapproved_brand",
] as const;
type Cls = (typeof CLASSES)[number];

interface Item {
  uid?: string;
  email?: string | null;
  storeId?: string;
  storeName?: string | null;
  brandId: string | null;
  brandName?: string | null;
  submittedBy?: string | null;
  status?: string | null;
}

interface BrandInfo {
  exists: boolean;
  name: string | null;
  submittedBy: string | null;
  status: string | null;
}

async function loadBrands(db: admin.firestore.Firestore, ids: string[]): Promise<Map<string, BrandInfo>> {
  const out = new Map<string, BrandInfo>();
  const unique = [...new Set(ids)];
  for (let i = 0; i < unique.length; i += GET_ALL_CHUNK) {
    const refs = unique.slice(i, i + GET_ALL_CHUNK).map((id) => db.collection("brands").doc(id));
    const snaps = await db.getAll(...refs);
    for (const s of snaps) {
      out.set(s.id, {
        exists: s.exists,
        name: s.exists ? ((s.get("name") as string | undefined) ?? null) : null,
        submittedBy: s.exists ? ((s.get("submittedBy") as string | undefined) ?? null) : null,
        status: s.exists ? ((s.get("status") as string | undefined) ?? null) : null,
      });
    }
  }
  return out;
}

function validId(v: unknown): v is string {
  return typeof v === "string" && v.length > 0 && !v.includes("/");
}

export const auditBrandLinks = onCall({ region: REGION, timeoutSeconds: 300 }, async (request) => {
  const db = admin.firestore();
  await requireAdmin(db, request);

  const counts = Object.fromEntries(CLASSES.map((c) => [c, 0])) as Record<Cls, number>;
  const items = Object.fromEntries(CLASSES.map((c) => [c, [] as Item[]])) as Record<Cls, Item[]>;
  const add = (cls: Cls, item: Item) => {
    counts[cls]++;
    if (cls === "ok" || cls === "ok_onboarding") return; // 건수만
    if (items[cls].length < ITEM_MAX) items[cls].push(item);
  };

  // ── ① role == 'brand' 계정 ──────────────────────────────────────────────
  interface BrandUser {
    uid: string;
    email: string | null;
    brandId: string | null;
  }
  const brandUsers: BrandUser[] = [];
  {
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let q = db.collection("users").where("role", "==", "brand").select("email", "brandId").limit(PAGE);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;
      for (const d of page.docs) {
        const b = d.get("brandId");
        brandUsers.push({
          uid: d.id,
          email: (d.get("email") as string | undefined) ?? null,
          brandId: validId(b) ? b : null,
        });
      }
      cursor = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
  }

  // brandId 를 가리키는 모든 users (role 불문) — orphan 판정용.
  const referenced = new Set<string>();
  {
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let q = db.collection("users").where("brandId", ">", "").select("brandId").limit(PAGE);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;
      for (const d of page.docs) {
        const b = d.get("brandId");
        if (validId(b)) referenced.add(b);
      }
      cursor = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
  }

  // ── ③ 매장 (brandId != null) ───────────────────────────────────────────
  interface StoreRef {
    id: string;
    name: string | null;
    brandId: string;
  }
  const stores: StoreRef[] = [];
  {
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let q = db.collection("stores").where("brandId", "!=", null).select("name", "brandId").limit(PAGE);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;
      for (const d of page.docs) {
        const b = d.get("brandId");
        if (typeof b === "string" && b.length > 0) {
          stores.push({ id: d.id, name: (d.get("name") as string | undefined) ?? null, brandId: b });
        }
      }
      cursor = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
  }

  // ── ② 모든 브랜드 (고아 판정) ────────────────────────────────────────────
  const allBrands = new Map<string, BrandInfo>();
  {
    let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let q = db.collection("brands").select("name", "submittedBy", "status").limit(PAGE);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;
      for (const d of page.docs) {
        allBrands.set(d.id, {
          exists: true,
          name: (d.get("name") as string | undefined) ?? null,
          submittedBy: (d.get("submittedBy") as string | undefined) ?? null,
          status: (d.get("status") as string | undefined) ?? null,
        });
      }
      cursor = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
  }
  // 전수 스캔에 없는 id (동시 변경·삭제) 는 getAll 로 보강한다.
  const missingIds = [
    ...brandUsers.map((u) => u.brandId),
    ...stores.map((s) => s.brandId),
  ].filter((id): id is string => id !== null && !allBrands.has(id));
  const extra = await loadBrands(db, missingIds);
  const brandOf = (id: string): BrandInfo =>
    allBrands.get(id) ?? extra.get(id) ?? { exists: false, name: null, submittedBy: null, status: null };

  // duplicate: 같은 brandId 의 brand 계정이 2명 이상
  const holders = new Map<string, BrandUser[]>();
  for (const u of brandUsers) {
    if (u.brandId === null) continue;
    holders.set(u.brandId, [...(holders.get(u.brandId) ?? []), u]);
  }
  const duplicateUids = new Set<string>();
  for (const [brandId, list] of holders) {
    if (list.length < 2) continue;
    const b = brandOf(brandId);
    for (const u of list) {
      duplicateUids.add(u.uid);
      add("duplicate", {
        uid: u.uid,
        email: u.email,
        brandId,
        brandName: b.name,
        submittedBy: b.submittedBy,
        status: b.status,
      });
    }
  }

  for (const u of brandUsers) {
    if (u.brandId === null) {
      add("ok_onboarding", { uid: u.uid, email: u.email, brandId: null });
      continue;
    }
    const b = brandOf(u.brandId);
    const item: Item = {
      uid: u.uid,
      email: u.email,
      brandId: u.brandId,
      brandName: b.name,
      submittedBy: b.submittedBy,
      status: b.status,
    };
    if (!b.exists) add("dangling", item);
    else if (b.submittedBy !== u.uid) add("mismatch", item);
    else if (!duplicateUids.has(u.uid)) add("ok", item);
  }

  for (const [id, b] of allBrands) {
    if (!referenced.has(id)) {
      add("orphan_brand", { brandId: id, brandName: b.name, submittedBy: b.submittedBy, status: b.status });
    }
  }

  for (const s of stores) {
    const b = brandOf(s.brandId);
    const item: Item = {
      storeId: s.id,
      storeName: s.name,
      brandId: s.brandId,
      brandName: b.name,
      status: b.status,
    };
    if (!b.exists) add("store_dangling_brand", item);
    else if (b.status !== "approved") add("store_unapproved_brand", item);
  }

  const truncated = Object.fromEntries(CLASSES.map((c) => [c, counts[c] > items[c].length && c !== "ok" && c !== "ok_onboarding"]));
  console.info(`${LOG} audited (read-only).`, counts);
  return { counts, items, truncated };
});
