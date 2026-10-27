/**
 * auditOrderPriceIntegrity — **임시** callable (admin 전용, **읽기 전용**). payment_price_authority R14 (spec §12).
 * **임시 자산이다.** 배포 ⑩ 정리 커밋에서 삭제한다 (선행 migrate* 와 같은 패턴).
 *
 * 금액 게이트(enforce) 전에 **기준선**을 재고, 후에 다시 재서 증가 0 을 확인하는 도구다. 고치지 않는다 — 멈추고 보고한다.
 *
 * 출력 3부:
 *  ⓐ orders Tier 1 — 주문 문서 **내부 정합성** 4개 불변식 (추가 읽기 0, 오탐 0: 현행 클라이언트는 항상 정합하다).
 *       lineMath          모든 라인에서 lineTotal == unitPriceWithOptions × quantity
 *       subtotalSum       subtotal == Σ lineTotal
 *       totalEqSubtotal   totalPrice == subtotal
 *       amountEqTotal     paymentInfo.amount == totalPrice
 *     §0 의 공격(amount 1 + 17,000원어치 items)은 subtotalSum 으로 반드시 걸린다. 한계: 공격자가 lineTotal·unitPrice·subtotal 을 전부
 *     정합하게 위조하면 통과한다 — 그 경우 거짓은 단가 자체에 있어 Tier 2(가격 이력 대조)의 영역이다 (priceHistory 가 쌓인 뒤에만 가능).
 *  ⓑ self-approved override (§13-8) — menuOverrides 중 **효력 있는 핵심 필드**(priceOverride 값 또는 excluded:true)가 있고
 *     status 가 pending/rejected 가 아니며(앱은 모르는 문자열도 approved 로 읽는다) approvedBy 가 없거나 그 매장 점주 uid 인 건.
 *     ※ 핵심 필드가 없는 `status:'approved'` 문서(점주 운영 필드 upsert W2 가 만드는 정상 문서)는 위반이 아니라 `opsOnlyApproved` 로 센다.
 *  ⓒ store-scope ref (§4-4 / Q8) — **마스터 메뉴**(브랜드가 통제)가 scope=='store' 옵션 그룹을 참조하는 건. 그 그룹의 priceDelta 는
 *     가맹점주가 승인 없이 즉시 바꾼다. 가맹점 수를 곱한 영향 범위(storePairs)를 함께 낸다.
 *
 * 입력 { from?: ISO|ms, to?: ISO|ms, limit?: number(기본 20000, 최대 50000) } — 모두 선택. 쓰기는 `migrationHistory` 1건(실행 기록)뿐이다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { overrideIsApproved } from "./menuVisibility";
import { REGION, requireAdmin } from "./qoinAdmin";

const ITEM_MAX = 100;
const PAGE = 500;
const DEFAULT_LIMIT = 20000;
const MAX_LIMIT = 50000;

type Doc = Record<string, unknown>;

// ── ⓐ 주문 Tier 1 ────────────────────────────────────────────────────────────

export type Tier1Check = "lineMath" | "subtotalSum" | "totalEqSubtotal" | "amountEqTotal";

export interface OrderTier1Result {
  checks: Record<Tier1Check, boolean>;
  clientSubtotal: number | null;
  sumOfLineTotals: number | null;
  amount: number | null;
  /** items 가 배열이 아니다 — 판정할 수 없다(위반으로 센다). */
  malformed: boolean;
}

const isInt = (v: unknown): v is number => typeof v === "number" && Number.isSafeInteger(v);

/** 순수 — 단위 테스트 대상. */
export function checkOrderTier1(order: Doc): OrderTier1Result {
  const items = Array.isArray(order.items) ? (order.items as unknown[]) : null;
  const paymentAmount = (order.paymentInfo as Doc | undefined)?.amount;
  if (items === null) {
    return {
      checks: { lineMath: false, subtotalSum: false, totalEqSubtotal: order.totalPrice === order.subtotal, amountEqTotal: paymentAmount === order.totalPrice },
      clientSubtotal: isInt(order.subtotal) ? order.subtotal : null,
      sumOfLineTotals: null,
      amount: isInt(paymentAmount) ? paymentAmount : null,
      malformed: true,
    };
  }
  let lineMath = true;
  let sum: number | null = 0;
  for (const raw of items) {
    const it = (typeof raw === "object" && raw !== null ? raw : {}) as Doc;
    if (!isInt(it.lineTotal) || !isInt(it.unitPriceWithOptions) || !isInt(it.quantity) || it.lineTotal !== it.unitPriceWithOptions * it.quantity) {
      lineMath = false;
    }
    if (isInt(it.lineTotal) && sum !== null) sum += it.lineTotal;
    else sum = null;
  }
  return {
    checks: {
      lineMath,
      subtotalSum: sum !== null && order.subtotal === sum,
      totalEqSubtotal: order.totalPrice === order.subtotal,
      amountEqTotal: paymentAmount === order.totalPrice,
    },
    clientSubtotal: isInt(order.subtotal) ? order.subtotal : null,
    sumOfLineTotals: sum,
    amount: isInt(paymentAmount) ? paymentAmount : null,
    malformed: false,
  };
}

// ── ⓑ self-approved override ─────────────────────────────────────────────────

export interface SelfApprovedItem {
  storeId: string;
  masterMenuItemId: string;
  priceOverride: unknown;
  excluded: boolean;
  status: unknown;
  approvedBy: unknown;
}

/** 순수. override 1건 → 분류. */
export function classifyOverride(o: Doc, storeOwnerUid: string | null): "selfApproved" | "opsOnlyApproved" | "ok" {
  // 승인 분기는 menuVisibility.ts 의 유일한 구현을 쓴다 (앱은 status 부재를 pending, 모르는 문자열을 approved 로 읽는다).
  if (!overrideIsApproved(o)) return "ok";
  const approvedBy = typeof o.approvedBy === "string" && o.approvedBy.length > 0 ? o.approvedBy : null;
  const selfApprover = approvedBy === null || (storeOwnerUid !== null && approvedBy === storeOwnerUid);
  if (!selfApprover) return "ok";
  const hasCore = (o.priceOverride !== undefined && o.priceOverride !== null) || o.excluded === true;
  return hasCore ? "selfApproved" : "opsOnlyApproved";
}

// ── ⓒ store-scope ref ────────────────────────────────────────────────────────

export interface StoreScopeRefItem {
  brandId: string;
  menuItemId: string;
  groupId: string;
  franchiseStores: number;
}

/** 순수. 마스터 메뉴 1건의 store-scope ref 그룹 id 목록. */
export function storeScopeGroupIds(master: Doc): string[] {
  const refs = Array.isArray(master.optionGroupRefs) ? (master.optionGroupRefs as unknown[]) : [];
  const out: string[] = [];
  for (const r of refs) {
    if (typeof r !== "object" || r === null) continue;
    const m = r as Doc;
    if (m.scope === "store" && typeof m.id === "string" && m.id.length > 0) out.push(m.id);
  }
  return out;
}

// ── 날짜/입력 ────────────────────────────────────────────────────────────────

function parseDate(raw: unknown, dflt: Date): Date {
  if (raw === undefined || raw === null) return dflt;
  const d = typeof raw === "number" ? new Date(raw) : typeof raw === "string" ? new Date(raw) : null;
  if (d === null || Number.isNaN(d.getTime())) throw new HttpsError("invalid-argument", "from/to 는 ISO 문자열 또는 밀리초여야 해요.");
  return d;
}

export const auditOrderPriceIntegrity = onCall({ region: REGION, timeoutSeconds: 540, memory: "512MiB" }, async (request) => {
  const db = admin.firestore();
  const adminUid = await requireAdmin(db, request);
  const data = (request.data ?? {}) as { from?: unknown; to?: unknown; limit?: unknown };
  const from = parseDate(data.from, new Date(0));
  const to = parseDate(data.to, new Date(Date.now() + 24 * 3600 * 1000));
  const limit = Math.min(Math.max(Number.isInteger(data.limit) ? (data.limit as number) : DEFAULT_LIMIT, 1), MAX_LIMIT);

  // ⓐ ───────────────────────────────────────────────────────────────────────
  const byCheck: Record<Tier1Check, number> = { lineMath: 0, subtotalSum: 0, totalEqSubtotal: 0, amountEqTotal: 0 };
  const violations: Array<Record<string, unknown>> = [];
  let scanned = 0;
  let violationCount = 0;
  let truncated = false;
  let cursor: admin.firestore.DocumentSnapshot | null = null;
  for (;;) {
    let q = db
      .collection("orders")
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(from))
      .where("createdAt", "<", admin.firestore.Timestamp.fromDate(to))
      .orderBy("createdAt", "asc")
      .limit(Math.min(PAGE, limit - scanned));
    if (cursor !== null) q = q.startAfter(cursor);
    const snap = await q.get();
    if (snap.empty) break;
    for (const d of snap.docs) {
      scanned++;
      const o = d.data();
      const r = checkOrderTier1(o);
      const failed = (Object.keys(r.checks) as Tier1Check[]).filter((k) => !r.checks[k]);
      if (failed.length === 0) continue;
      violationCount++;
      for (const k of failed) byCheck[k]++;
      if (violations.length < ITEM_MAX) {
        violations.push({
          orderId: d.id,
          userId: o.userId ?? null,
          storeId: o.storeId ?? null,
          createdAt: (o.createdAt as admin.firestore.Timestamp | undefined)?.toDate?.().toISOString() ?? null,
          failed,
          malformed: r.malformed,
          clientSubtotal: r.clientSubtotal,
          sumOfLineTotals: r.sumOfLineTotals,
          amount: r.amount,
        });
      }
    }
    cursor = snap.docs[snap.docs.length - 1];
    if (scanned >= limit) {
      truncated = true;
      break;
    }
    if (snap.size < PAGE) break;
  }

  // ⓑⓒ — stores 는 점주 uid·brandId 를 위해 한 번 읽는다.
  const storesSnap = await db.collection("stores").get();
  const ownerOf = new Map<string, string | null>();
  const franchiseCount = new Map<string, number>();
  for (const s of storesSnap.docs) {
    const sd = s.data();
    ownerOf.set(s.id, typeof sd.ownerId === "string" ? sd.ownerId : null);
    if (typeof sd.brandId === "string" && sd.brandId.length > 0) {
      franchiseCount.set(sd.brandId, (franchiseCount.get(sd.brandId) ?? 0) + 1);
    }
  }

  const overrides = await db.collectionGroup("menuOverrides").get();
  const selfApproved: SelfApprovedItem[] = [];
  let selfApprovedCount = 0;
  let opsOnlyApproved = 0;
  for (const d of overrides.docs) {
    const storeId = d.ref.parent.parent?.id ?? "";
    const o = d.data();
    const cls = classifyOverride(o, ownerOf.get(storeId) ?? null);
    if (cls === "opsOnlyApproved") opsOnlyApproved++;
    if (cls !== "selfApproved") continue;
    selfApprovedCount++;
    if (selfApproved.length < ITEM_MAX) {
      selfApproved.push({
        storeId,
        masterMenuItemId: d.id,
        priceOverride: o.priceOverride ?? null,
        excluded: o.excluded === true,
        status: o.status ?? null,
        approvedBy: o.approvedBy ?? null,
      });
    }
  }

  const refItems: StoreScopeRefItem[] = [];
  let refCount = 0;
  let storePairs = 0;
  for (const [brandId, stores] of franchiseCount) {
    const menus = await db.collection("brands").doc(brandId).collection("menuItems").get();
    for (const m of menus.docs) {
      for (const groupId of storeScopeGroupIds(m.data())) {
        refCount++;
        storePairs += stores;
        if (refItems.length < ITEM_MAX) refItems.push({ brandId, menuItemId: m.id, groupId, franchiseStores: stores });
      }
    }
  }

  const report = {
    window: { from: from.toISOString(), to: to.toISOString(), limit },
    orders: { scanned, violationCount, byCheck, violations, truncated },
    selfApprovedOverrides: { scanned: overrides.size, count: selfApprovedCount, opsOnlyApproved, items: selfApproved },
    storeScopeRefs: { brandsWithFranchise: franchiseCount.size, count: refCount, storePairs, items: refItems },
  };

  // 실행 1건당 기록 1건 (audit_trail §4-5) — 영향 범위(scanned / 위반 수 / 기간)를 함께 남긴다.
  await db.collection("migrationHistory").add({
    name: "auditOrderPriceIntegrity",
    executedBy: adminUid,
    executedAt: FieldValue.serverTimestamp(),
    window: report.window,
    ordersScanned: scanned,
    ordersViolations: violationCount,
    ordersByCheck: byCheck,
    selfApprovedOverrides: selfApprovedCount,
    opsOnlyApproved,
    storeScopeRefs: refCount,
    storeScopeStorePairs: storePairs,
  });
  return report;
});
