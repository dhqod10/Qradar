/**
 * backfillQoinAccrual — admin 전용 callable. 빠진 Qoin 적립을 **주문 당시 적립률로** 소급 적립한다
 * (docs/tasks/qoin_accrual_backfill/spec.md, Phase 1: UI 없음).
 *
 * 이 도구는 실제 Qoin(돈)을 발행한다. 경계:
 *   - dryRun 기본 true — `dryRun: false` 를 **명시**해야만 쓴다. dryRun 은 쓰기 0.
 *   - 무제한 스캔 금지 — source 별 필수 필터 + 건수/기간 상한. 필터 없는 호출은 invalid-argument.
 *   - 멱등 — `earn_{orderId}` 결정적 ID + 트랜잭션 내 선존재 가드 (라이브 `onOrderQoinSettled` 와 같은 ID 체계).
 *     라이브 트리거가 이미 적립했거나 동시에 적립해도 이중 적립되지 않는다.
 *   - fail-closed — 당시 요율을 복원할 수 없으면 적립하지 않는다. `overrideRate` 를 명시한 경우에만 적립하며
 *     원장에 `rateReconstruction.method: 'admin_override'` 로 박제한다 ("당시 요율 아님" 영구 기록).
 *   - 라이브 트리거와 같은 가드를 지난다: status==completed, totalPrice 유효, 자기적립 제외. 전역 kill switch(`config/qoin.enabled`)는
 *     **통과**한다 (D0-4: admin 의 의도된 복구 행위).
 *   - 새 원장 타입을 만들지 않는다: `type:'earn'` + 감사 필드 (clawback 은 earn_{orderId} 의 amount 를 읽으므로 그대로 동작).
 *   - `users/{uid}` 에는 `qoinBalance` 1필드만 쓴다. 잔액은 같은 트랜잭션에서 절대값으로 갱신 → balance == Σ amount 유지.
 *
 * 입력 { dryRun?, source: 'issues'|'orderIds'|'storeRange'|'range', orderIds?, storeId?, from?, to?, limit?,
 *        creditDisabledPeriod?, overrideRate?, reason? }
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { computeEarnAmount, isValidCallableRate } from "./qoinRate";
import { parseReason, REGION, requireAdmin } from "./qoinAdmin";
import { loadLayer, LayerInput, reconstructRate } from "./qoinRateReconstruct";
import { findSelfDealing } from "./selfDealing";

const LOG = "[backfillQoinAccrual]";

const DEFAULT_LIMIT = 200;
const MAX_LIMIT = 500;
const MAX_ORDER_IDS = 500;
/** 기간 소스의 조회 기간 상한 (31일). */
const MAX_RANGE_MS = 31 * 24 * 60 * 60 * 1000;
/** 기간 소스가 훑는 문서 수 상한 — 인덱스 추가 없이 completedAt 범위만 쿼리하고 나머지는 메모리 필터하므로 훑는 양을 막는다. */
const MAX_SCAN_DOCS = 2000;
const SAMPLE_CAP = 50;
/** 적립 누락 사유 (spend 계열은 대상 아님 — D0-2). */
const ACCRUAL_ISSUE_REASONS = new Set(["invalid_rate", "invalid_enabled", "invalid_store", "invalid_total"]);

type Source = "issues" | "orderIds" | "storeRange" | "range";

type SkipReason =
  | "already_earned"
  | "no_completedAt"
  | "rate_unrecoverable"
  | "disabled_period"
  | "invalid_total"
  | "store_unresolvable"
  // spec §2 목록 외 보조 사유 (라이브 트리거와 같은 가드를 지키기 위한 것)
  | "order_not_found"
  | "not_completed"
  | "no_user"
  | "self_dealing"
  | "zero_amount";

interface ItemResult {
  orderId: string;
  outcome: "credited" | "would_credit" | "already_applied" | "skipped" | "failed";
  skipReason?: SkipReason;
  detail?: string;
  rate?: number;
  rateSource?: string | null;
  amount?: number;
  reconstruction?: Record<string, unknown>;
  issueResolved?: boolean;
  warning?: string;
}

interface Params {
  dryRun: boolean;
  source: Source;
  orderIds: string[];
  storeId: string | null;
  fromMs: number | null;
  toMs: number | null;
  limit: number;
  creditDisabledPeriod: boolean;
  overrideRate: number | null;
  reason: string | null;
}

interface Candidate {
  orderId: string;
  order?: admin.firestore.DocumentSnapshot; // 이미 읽은 경우 (기간 소스)
}

function parseTime(raw: unknown, name: string): number {
  let ms: number;
  if (typeof raw === "number") ms = raw;
  else if (typeof raw === "string") ms = Date.parse(raw);
  else throw new HttpsError("invalid-argument", `${name} required (ISO string or millis)`);
  if (!Number.isFinite(ms) || ms <= 0) throw new HttpsError("invalid-argument", `${name} invalid`);
  return ms;
}

function parseParams(raw: unknown): Params {
  const d = (raw ?? {}) as Record<string, unknown>;
  const dryRun = d.dryRun !== false; // 기본 true. 정확히 false 일 때만 실제 적립.

  const source = d.source;
  if (source !== "issues" && source !== "orderIds" && source !== "storeRange" && source !== "range") {
    throw new HttpsError("invalid-argument", "source must be issues|orderIds|storeRange|range");
  }

  let limit = DEFAULT_LIMIT;
  if (d.limit !== undefined) {
    if (typeof d.limit !== "number" || !Number.isInteger(d.limit) || d.limit < 1 || d.limit > MAX_LIMIT) {
      throw new HttpsError("invalid-argument", `limit must be integer 1..${MAX_LIMIT}`);
    }
    limit = d.limit;
  }

  let orderIds: string[] = [];
  if (source === "orderIds") {
    if (!Array.isArray(d.orderIds) || d.orderIds.length === 0 || d.orderIds.length > MAX_ORDER_IDS) {
      throw new HttpsError("invalid-argument", `orderIds must be 1..${MAX_ORDER_IDS} strings`);
    }
    for (const id of d.orderIds) {
      if (typeof id !== "string" || id.length === 0 || id.includes("/")) {
        throw new HttpsError("invalid-argument", "orderIds contains invalid id");
      }
    }
    orderIds = Array.from(new Set(d.orderIds as string[]));
  }

  let storeId: string | null = null;
  if (source === "storeRange") {
    if (typeof d.storeId !== "string" || d.storeId.length === 0 || d.storeId.includes("/")) {
      throw new HttpsError("invalid-argument", "storeId required");
    }
    storeId = d.storeId;
  }

  let fromMs: number | null = null;
  let toMs: number | null = null;
  if (source === "storeRange" || source === "range") {
    fromMs = parseTime(d.from, "from");
    toMs = parseTime(d.to, "to");
    if (toMs <= fromMs) throw new HttpsError("invalid-argument", "to must be after from");
    if (toMs - fromMs > MAX_RANGE_MS) throw new HttpsError("invalid-argument", "range exceeds 31 days");
  }

  if (d.creditDisabledPeriod !== undefined && typeof d.creditDisabledPeriod !== "boolean") {
    throw new HttpsError("invalid-argument", "creditDisabledPeriod must be boolean");
  }
  let overrideRate: number | null = null;
  if (d.overrideRate !== undefined && d.overrideRate !== null) {
    if (!isValidCallableRate(d.overrideRate)) {
      throw new HttpsError("invalid-argument", "overrideRate out of allowed range or step");
    }
    overrideRate = d.overrideRate;
  }

  return {
    dryRun,
    source,
    orderIds,
    storeId,
    fromMs,
    toMs,
    limit,
    creditDisabledPeriod: d.creditDisabledPeriod === true,
    overrideRate,
    reason: parseReason(d.reason),
  };
}

/** 대상 수집. 어느 source 든 상한이 있다 (무제한 스캔 금지). */
async function collectCandidates(
  db: admin.firestore.Firestore,
  p: Params
): Promise<{ candidates: Candidate[]; truncated: boolean; scanned: number }> {
  if (p.source === "issues") {
    // resolved==false 단일 필드 등치 (자동 인덱스). 사유는 메모리 필터 — 복합 인덱스 추가를 피한다.
    const snap = await db.collection("qoinSettlementIssues").where("resolved", "==", false).limit(MAX_SCAN_DOCS).get();
    const all = snap.docs.filter((d) => ACCRUAL_ISSUE_REASONS.has(String(d.get("reason"))));
    return {
      candidates: all.slice(0, p.limit).map((d) => ({ orderId: d.id })),
      truncated: all.length > p.limit || snap.size >= MAX_SCAN_DOCS,
      scanned: snap.size,
    };
  }
  if (p.source === "orderIds") {
    return {
      candidates: p.orderIds.slice(0, p.limit).map((orderId) => ({ orderId })),
      truncated: p.orderIds.length > p.limit,
      scanned: p.orderIds.length,
    };
  }
  // storeRange | range: completedAt 범위만 쿼리 (단일 필드 자동 인덱스). status/storeId 는 메모리 필터.
  const snap = await db
    .collection("orders")
    .where("completedAt", ">=", admin.firestore.Timestamp.fromMillis(p.fromMs as number))
    .where("completedAt", "<=", admin.firestore.Timestamp.fromMillis(p.toMs as number))
    .orderBy("completedAt", "asc")
    .limit(MAX_SCAN_DOCS)
    .get();
  const all = snap.docs.filter(
    (d) => d.get("status") === "completed" && (p.storeId === null || d.get("storeId") === p.storeId)
  );
  return {
    candidates: all.slice(0, p.limit).map((d) => ({ orderId: d.id, order: d })),
    truncated: all.length > p.limit || snap.size >= MAX_SCAN_DOCS,
    scanned: snap.size,
  };
}

/** 이 실행 안에서 매장/브랜드/전역 이력 읽기를 공유한다. */
class LayerCache {
  private m = new Map<string, Promise<LayerInput | null>>();
  constructor(private db: admin.firestore.Firestore) {}
  get(scope: "store" | "brand" | "global", id: string): Promise<LayerInput | null> {
    const key = `${scope}:${id}`;
    let v = this.m.get(key);
    if (!v) {
      v = loadLayer(this.db, scope, id);
      this.m.set(key, v);
    }
    return v;
  }
}

async function processOne(
  db: admin.firestore.Firestore,
  uid: string,
  p: Params,
  cache: LayerCache,
  cand: Candidate
): Promise<ItemResult> {
  const orderId = cand.orderId;
  const skip = (skipReason: SkipReason, extra: Partial<ItemResult> = {}): ItemResult => ({
    orderId,
    outcome: "skipped",
    skipReason,
    ...extra,
  });

  const orderSnap = cand.order ?? (await db.collection("orders").doc(orderId).get());
  if (!orderSnap.exists) return skip("order_not_found");
  const order = orderSnap.data() ?? {};

  // 소급은 정의상 완료된 주문만. 환불/취소 주문에 적립하면 안 된다.
  if (order.status !== "completed") return skip("not_completed", { detail: String(order.status) });
  const userId = order.userId;
  if (typeof userId !== "string" || userId.length === 0) return skip("no_user");
  const completedAt = order.completedAt;
  if (!completedAt || typeof completedAt.toMillis !== "function") return skip("no_completedAt");
  const anchorMs: number = completedAt.toMillis();

  // 사전 필터: earn 원장 존재 확인 + (있으면) 해소할 이슈 문서.
  const userRef = db.collection("users").doc(userId);
  const earnRef = userRef.collection("qoinTransactions").doc(`earn_${orderId}`);
  const issueRef = db.collection("qoinSettlementIssues").doc(orderId);
  const [earnSnap, issueSnap] = await db.getAll(earnRef, issueRef);
  if (earnSnap.exists) return skip("already_earned");
  const sourceIssueId =
    issueSnap.exists && ACCRUAL_ISSUE_REASONS.has(String(issueSnap.get("reason"))) && issueSnap.get("resolved") === false
      ? issueSnap.id
      : null;

  const total = order.totalPrice;
  if (typeof total !== "number" || !Number.isFinite(total) || total <= 0) return skip("invalid_total");

  const storeId = order.storeId;
  if (typeof storeId !== "string" || storeId.length === 0) return skip("store_unresolvable");
  const storeSnap = await db.collection("stores").doc(storeId).get();
  if (!storeSnap.exists) return skip("store_unresolvable");
  const store = storeSnap.data() ?? {};

  // 라이브와 같은 자기적립 제외 (적립만 막는다). 소급이 이 정책의 우회로가 되면 안 된다.
  const selfMatch = await findSelfDealing(db, userId, store);
  if (selfMatch !== null) return skip("self_dealing", { detail: selfMatch });

  // 브랜드 신뢰원은 stores/{storeId}.brandId 하나뿐 (F1). 현재 값 — 매장의 브랜드 이동 이력은 없다.
  const brandId = typeof store.brandId === "string" && store.brandId.length > 0 ? store.brandId : null;

  const [storeLayer, brandLayer, globalLayer] = await Promise.all([
    cache.get("store", storeId),
    brandId ? cache.get("brand", brandId) : Promise.resolve(null),
    cache.get("global", "qoin"),
  ]);
  if (!storeLayer || !globalLayer) return skip("store_unresolvable");

  const rec = reconstructRate({
    anchorMs,
    store: storeLayer,
    brand: brandLayer,
    global: globalLayer,
    ignoreSwitch: p.creditDisabledPeriod,
  });

  let rate: number;
  let accrualRateSource: string | null;
  let reconstruction: Record<string, unknown>;
  if (rec.status === "disabled") {
    // creditDisabledPeriod=false 일 때만 도달 (true 면 스위치를 무시한다).
    return skip("disabled_period", { detail: rec.source, reconstruction: { anchor: anchorMs, gaps: rec.gaps } });
  } else if (rec.status === "unrecoverable") {
    if (p.overrideRate === null) {
      return skip("rate_unrecoverable", {
        detail: rec.reason,
        reconstruction: { anchor: anchorMs, gaps: rec.gaps },
      });
    }
    rate = p.overrideRate;
    accrualRateSource = null; // 당시 정책 출처가 아니다. 거짓 출처를 박제하지 않는다.
    reconstruction = {
      method: "admin_override",
      anchor: anchorMs,
      resolvedSource: null,
      gaps: [...rec.gaps, `unrecoverable:${rec.reason}`],
    };
  } else {
    rate = rec.rate;
    accrualRateSource = rec.source;
    reconstruction = {
      method: "history_pit",
      anchor: anchorMs,
      resolvedSource: rec.source,
      gaps: rec.gaps,
      ...(p.creditDisabledPeriod ? { switchIgnored: true } : {}),
    };
  }

  const amount = computeEarnAmount(total, rate);
  if (amount <= 0) return skip("zero_amount", { rate, reconstruction });

  const base: ItemResult = { orderId, outcome: "would_credit", rate, rateSource: accrualRateSource, amount, reconstruction };
  if (p.dryRun) return base;

  // ── 실제 적립: onOrderQoinSettled.applyTransaction 과 같은 형태 (선존재 가드 → 잔액 절대값 갱신) ──
  const outcome = await db.runTransaction(async (t) => {
    const txSnap = await t.get(earnRef); // 멱등 가드 (라이브/동시 소급과 경합 시 뒤쪽이 여기서 빠진다)
    if (txSnap.exists) return "already_applied" as const;
    const userSnap = await t.get(userRef);
    if (!userSnap.exists) return "no_user" as const;
    const rawBefore = userSnap.get("qoinBalance");
    const before = typeof rawBefore === "number" && Number.isFinite(rawBefore) ? rawBefore : 0;
    const after = before + amount;
    t.set(earnRef, {
      // 라이브 earn 과 동일한 핵심 필드
      txId: `earn_${orderId}`,
      type: "earn",
      orderId,
      storeId,
      storeName: typeof order.storeName === "string" ? order.storeName : "",
      brandId,
      orderTotalPrice: total,
      accrualRate: rate,
      accrualRateSource,
      amount,
      balanceAfter: after,
      createdAt: FieldValue.serverTimestamp(),
      // 소급 감사 필드 (D0-7)
      origin: "backfill",
      backfilledBy: uid,
      backfilledAt: FieldValue.serverTimestamp(),
      backfillReason: p.reason,
      sourceIssueId,
      rateReconstruction: reconstruction,
    });
    t.update(userRef, { qoinBalance: after }); // 이 1필드만. updatedAt 금지
    return "applied" as const;
  });

  if (outcome === "already_applied") return { ...base, outcome: "already_applied" };
  if (outcome === "no_user") return skip("no_user");

  const result: ItemResult = { ...base, outcome: "credited" };
  if (sourceIssueId) {
    // 적립이 진실원이다. 마킹 실패는 적립을 되돌리지 않고 경고만 남긴다 (spec §6).
    try {
      await issueRef.update({
        resolved: true,
        resolvedBy: uid,
        resolvedAt: FieldValue.serverTimestamp(),
        resolvedTxId: `earn_${orderId}`,
      });
      result.issueResolved = true;
    } catch (e) {
      console.error(`${LOG} issue_mark_failed. orderId:`, orderId, e);
      result.issueResolved = false;
      result.warning = "issue_mark_failed";
    }
  }
  return result;
}

export const backfillQoinAccrual = onCall({ region: REGION, timeoutSeconds: 540 }, async (request) => {
  const db = admin.firestore();
  const uid = await requireAdmin(db, request);
  const p = parseParams(request.data);

  const { candidates, truncated, scanned } = await collectCandidates(db, p);
  const cache = new LayerCache(db);
  const results: ItemResult[] = [];

  // 순차 처리: 같은 사용자의 잔액 트랜잭션 경합과 부분 실패 보고를 단순하게 유지한다. 멱등하므로 재실행 안전.
  for (const cand of candidates) {
    try {
      results.push(await processOne(db, uid, p, cache, cand));
    } catch (e) {
      // 일시 장애는 해당 대상만 실패로 보고하고 계속한다.
      console.error(`${LOG} item_failed. orderId:`, cand.orderId, e);
      results.push({ orderId: cand.orderId, outcome: "failed", detail: e instanceof Error ? e.message : String(e) });
    }
  }

  const credited = results.filter((r) => r.outcome === "credited");
  const would = results.filter((r) => r.outcome === "would_credit");
  const skippedCounts: Record<string, number> = {};
  for (const r of results) {
    if (r.outcome === "skipped") skippedCounts[r.skipReason as string] = (skippedCounts[r.skipReason as string] ?? 0) + 1;
    else if (r.outcome === "already_applied" || r.outcome === "failed") {
      skippedCounts[r.outcome] = (skippedCounts[r.outcome] ?? 0) + 1;
    }
  }
  const sum = (xs: ItemResult[]) => xs.reduce((a, r) => a + (r.amount ?? 0), 0);

  const response: Record<string, unknown> = {
    dryRun: p.dryRun,
    source: p.source,
    scanned,
    eligible: p.dryRun ? would.length : credited.length,
    truncated,
    ...(p.dryRun ? { wouldCredit: would.length } : { credited: credited.length }),
    skippedCounts,
    totalQoin: p.dryRun ? sum(would) : sum(credited),
    results,
  };

  if (!p.dryRun) {
    // 운영 행위 영구 기록 (audit_trail §4-1/§4-5/§4-6). 적립은 이미 끝났으므로 기록 실패는 응답 경고로 남긴다.
    try {
      const ref = db.collection("qoinBackfillHistory").doc();
      await ref.set({
        name: "backfillQoinAccrual",
        changedBy: uid,
        changedAt: FieldValue.serverTimestamp(),
        dryRun: false,
        source: p.source,
        params: {
          orderIdsCount: p.orderIds.length,
          storeId: p.storeId,
          fromMs: p.fromMs,
          toMs: p.toMs,
          limit: p.limit,
          creditDisabledPeriod: p.creditDisabledPeriod,
          overrideRate: p.overrideRate,
        },
        reason: p.reason,
        scanned,
        eligible: credited.length,
        credited: credited.length,
        skippedCounts,
        totalQoin: sum(credited),
        truncated,
        sampleResults: credited.slice(0, SAMPLE_CAP).map((r) => ({
          orderId: r.orderId,
          amount: r.amount,
          rate: r.rate,
          rateSource: r.rateSource ?? null,
          method: (r.reconstruction as { method?: string } | undefined)?.method ?? null,
        })),
      });
      response.historyId = ref.id;
    } catch (e) {
      console.error(`${LOG} history_write_failed (credits already applied).`, e);
      response.historyWarning = "history_write_failed";
    }
  }

  console.info(`${LOG} done.`, {
    uid,
    dryRun: p.dryRun,
    source: p.source,
    scanned,
    eligible: response.eligible,
    totalQoin: response.totalQoin,
  });
  return response;
});
