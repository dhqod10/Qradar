/**
 * onOrderQoinSettled — Cloud Function (onDocumentUpdated, asia-northeast3)
 *
 * 주문 상태 전이에 따라 고객 Qoin 을 적립 / 회수한다.
 *   - `* -> completed`        : 적립 (floor(totalPrice * accrualRate))
 *   - `completed -> refunded` : 회수 (earn 원장의 amount 를 읽어 반전. 재계산 금지)
 *   - `* -> cancelled`, `* -> refunded` : 사용 복원 spendRefund (qoin_spend spec §6.1). `spend_{orderId}` 원장의 amount 를 반전한다 (재계산 금지).
 *       Qoin 을 쓰지 않은 주문은 spend 원장이 없어 no-op (read 1회). `completed -> refunded` 는 clawback 과 spendRefund 가 **둘 다** 일어난다
 *       (서로 독립 원장·독립 멱등 — 순 효과: 잔액이 주문 전으로 원복).
 *       복원은 `config/qoin.enabled` 만 본다 — **`spendEnabled=false` 는 복원을 막지 않는다** (막으면 환불된 고객 돈이 증발, D-7).
 *       `enabled=false`(전역 비상정지)면 복원도 멈추지만, 돈이 걸려 있으므로 `qoinSettlementIssues` 에 남겨 수동 복구 대상으로 둔다.
 *
 * 설계 (docs/tasks/qoin/spec.md §4, §5, §6, §9):
 *   - 원장 `users/{uid}/qoinTransactions/{txId}` 는 append-only.
 *     잔액 `users/{uid}.qoinBalance` 는 **같은 트랜잭션 안에서** 절대값으로 갱신한다.
 *     (전량 재계산 / FieldValue.increment 사용 금지 — 2차 Qoin 사용과 레이스 + balanceAfter 정합성)
 *   - 멱등: 결정적 문서 ID `earn_{orderId}` / `clawback_{orderId}` + 트랜잭션 내 선존재 가드.
 *   - users 에는 `qoinBalance` 1필드만 쓴다 (updatedAt 금지). orders 는 읽기 전용.
 *   - 적립률은 계층 해석(스위치 → 매장 → 브랜드 → 전역 `config/qoin`)으로 읽는다 (spec §20.3.1 개정판, N4).
 *     코드에 기본값 폴백을 두지 않는다 (fail-closed). 무효 값은 상위로 폴백하지 않고 멈춘다.
 *   - **브랜드 신뢰원은 `stores/{storeId}.brandId` 하나뿐이다** (F1). 주문 문서·cart 의 brandId 는 읽지도 쓰지도 않는다
 *     (클라이언트 값이라 신뢰할 수 없고, 앱은 애초에 보내지 않는다). 원장 `brandId` = 해석에 쓴 그 값 (정산 대비).
 *   - enabled !== true 이면 적립도 **회수도** 하지 않는다 (spec §5.5). 전역 비상 정지는 둘 다 멈춘다.
 *   - 매장/브랜드의 스위치(`qoinAccrualEnabled === false`)는 **적립만** 막는다. 회수는 적립률·스위치를 읽지 않고
 *     원장 금액을 반전하므로 스위치가 꺼져 있어도 통과한다 (막으면 환불된 Qoin 이 남아 돈이 샌다).
 *   - 스위치가 꺼져 적립하지 않는 것은 의도된 정책이라 `qoinSettlementIssues` 에 **기록하지 않는다**.
 *     무효 값(Q2 ⓐ)으로 적립이 멈추면 고객 돈이 누락된 것이므로 Firestore 에 기록한다 (소급 도구는 backlog).
 *   - 읽기: earn = `getAll([config/qoin, stores/{id}])` 1 RT + (브랜드 소속이면) `brands/{id}` 1 RT.
 *     이전(config 1 RT + getAll 1 RT)과 read 수 동일, 개인 매장은 오히려 1 RT 감소. 회수 경로는 변동 0.
 *   - 실패 정책: 알림 CF 와 정반대. 일시 장애는 throw (retry: true 로 재시도, 멱등하므로 안전),
 *     영구 오류는 console.error + return. 조용히 삼키지 않는다.
 *   - 단수 처리는 버림(floor) 고정. round / ceil 금지.
 *
 * 주의: 트리거가 onDocumentUpdated 이므로 completed 로 **생성**한 주문은 발화하지 않는다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import {
  classifyRate,
  classifySwitch,
  computeEarnAmount,
  InvalidReason,
  resolveEffectiveRate,
} from "./qoinRate";
import { describeRaw } from "./qoinAdmin";
import { findSelfDealing } from "./selfDealing";
import { recordSpendIssue, spendRefundFields, spendTxId } from "./qoinSpendLedger";

const LOG = "[onOrderQoinSettled]";

type Outcome = "applied" | "already_applied";

/**
 * config/qoin 스냅샷으로 kill switch 를 판정한다. 영구 오류(부재 / enabled != true)면 null (이미 로그 출력).
 * **적립률 검증은 여기서 하지 않는다** — 회수는 적립률을 읽지 않으며, 전역 적립률이 깨져도 환불 회수는 막히면 안 된다.
 */
function evaluateConfig(
  snap: admin.firestore.DocumentSnapshot,
  orderId: string
): { rawAccrualRate: unknown } | null {
  if (!snap.exists) {
    console.error(`${LOG} skipped_no_config: config/qoin missing. orderId:`, orderId);
    return null;
  }
  const data = snap.data() ?? {};
  if (data.enabled !== true) {
    console.warn(`${LOG} skipped_disabled: config/qoin.enabled != true. orderId:`, orderId);
    return null;
  }
  return { rawAccrualRate: data.accrualRate };
}

/** 이슈 문서에 넣을 원시 값 (임의 타입을 그대로 넣지 않는다). */
function rawForIssue(v: unknown): unknown {
  if (v === undefined) return "(absent)";
  if (v === null || typeof v === "boolean" || (typeof v === "number" && Number.isFinite(v))) return v;
  return describeRaw(v);
}

type IssueReason = "invalid_rate" | "invalid_enabled" | "invalid_store" | "invalid_total";
type IssueScope = "store" | "brand" | "global" | null;

/**
 * 적립이 **멈춘 고객 돈**을 Firestore 에 남긴다 (Q2 ⓐ, audit_trail §4-6). 문서 ID = orderId → 멱등.
 * 쓰기 실패는 throw → 트리거 재시도 (retry: true). 소급 적립 도구는 만들지 않았다 (backlog).
 */
async function recordIssue(
  db: admin.firestore.Firestore,
  issue: {
    orderId: string;
    userId: string;
    storeId: unknown;
    brandId: string | null;
    reason: IssueReason;
    scope: IssueScope;
    values: Record<string, unknown>;
    totalPrice: unknown;
  }
): Promise<void> {
  try {
    await db
      .collection("qoinSettlementIssues")
      .doc(issue.orderId)
      .create({
        orderId: issue.orderId,
        userId: issue.userId,
        storeId: typeof issue.storeId === "string" ? issue.storeId : null,
        brandId: issue.brandId,
        reason: issue.reason,
        scope: issue.scope,
        values: issue.values,
        totalPrice: rawForIssue(issue.totalPrice),
        occurredAt: FieldValue.serverTimestamp(),
        resolved: false,
      });
  } catch (e) {
    // ALREADY_EXISTS (코드 6) = 재시도·중복 전달 → 이미 기록됨.
    if ((e as { code?: number }).code === 6) return;
    throw e;
  }
}

function issueFromInvalid(reason: InvalidReason): { reason: IssueReason; scope: IssueScope } {
  switch (reason) {
    case "invalid_store":
      return { reason: "invalid_rate", scope: "store" };
    case "invalid_brand":
      return { reason: "invalid_rate", scope: "brand" };
    case "invalid_global":
      return { reason: "invalid_rate", scope: "global" };
    case "invalid_store_enabled":
      return { reason: "invalid_enabled", scope: "store" };
    case "invalid_brand_enabled":
      return { reason: "invalid_enabled", scope: "brand" };
  }
}

interface TxInput {
  userRef: admin.firestore.DocumentReference;
  txRef: admin.firestore.DocumentReference;
  amount: number; // 부호 포함
  fields: Record<string, unknown>; // 거래 필드 (amount / balanceAfter / createdAt 제외)
}

/** 거래 문서 생성 + 잔액 갱신을 한 트랜잭션에서 수행. */
async function applyTransaction(
  db: admin.firestore.Firestore,
  input: TxInput
): Promise<Outcome | "no_user"> {
  const { userRef, txRef, amount, fields } = input;
  return db.runTransaction(async (t) => {
    const txSnap = await t.get(txRef); // 멱등 가드
    if (txSnap.exists) return "already_applied" as const;

    const userSnap = await t.get(userRef);
    if (!userSnap.exists) return "no_user" as const;

    const rawBefore = userSnap.get("qoinBalance");
    const before = typeof rawBefore === "number" && Number.isFinite(rawBefore) ? rawBefore : 0;
    const after = before + amount;

    t.set(txRef, {
      ...fields,
      amount,
      balanceAfter: after,
      createdAt: FieldValue.serverTimestamp(),
    });
    t.update(userRef, { qoinBalance: after }); // 이 1필드만. updatedAt 금지
    return "applied" as const;
  });
}

export const onOrderQoinSettled = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-northeast3",
    retry: true, // 일시 장애 throw 시 재시도. 멱등 가드가 있어 안전.
  },
  async (event) => {
    const orderId = event.params.orderId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) {
      console.warn(`${LOG} missing before/after. orderId:`, orderId);
      return;
    }

    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;
    if (!beforeStatus || !afterStatus || beforeStatus === afterStatus) return;

    // 전이 매트릭스: `* -> completed` 적립, `completed -> refunded` 회수, `* -> cancelled|refunded` 사용 복원. 그 외 무동작.
    const isEarn = afterStatus === "completed";
    const isClawback = beforeStatus === "completed" && afterStatus === "refunded";
    const isRestore = afterStatus === "cancelled" || afterStatus === "refunded";
    if (!isEarn && !isClawback && !isRestore) return;
    const kind: "earn" | "clawback" = isEarn ? "earn" : "clawback";

    const userId = after.userId as string | undefined;
    if (!userId) {
      console.error(`${LOG} userId missing. orderId:`, orderId);
      return;
    }

    const db = admin.firestore();
    const configRef = db.collection("config").doc("qoin");
    const userRef = db.collection("users").doc(userId);
    const txCol = userRef.collection("qoinTransactions");

    if (kind === "earn") {
      // 읽기 묶음 1: config/qoin + stores/{storeId} (1 라운드트립). 매장 ID 가 유효하지 않으면 config 만.
      const storeId = after.storeId;
      const storeIdOk = typeof storeId === "string" && storeId.length > 0;
      const first = await db.getAll(...(storeIdOk ? [configRef, db.collection("stores").doc(storeId)] : [configRef])); // 실패 시 throw -> 재시도
      // 설정 검증 (fail-closed). enabled=false 면 적립/회수 모두 중단.
      const config = evaluateConfig(first[0], orderId);
      if (!config) return;
      const storeSnap = storeIdOk ? first[1] : undefined;

      const total = after.totalPrice;
      if (typeof total !== "number" || !Number.isFinite(total) || total <= 0) {
        console.error(`${LOG} skipped_invalid_total. orderId:`, orderId, "totalPrice:", total);
        await recordIssue(db, {
          orderId, userId, storeId, brandId: null, reason: "invalid_total", scope: null, values: {}, totalPrice: total,
        });
        return;
      }
      if (!storeIdOk || !storeSnap) {
        // 조용한 빈 값 방지: 매장을 특정할 수 없으면 어떤 적립률도 고를 수 없다.
        console.error(`${LOG} skipped_invalid_store. orderId:`, orderId, "storeId:", storeId);
        await recordIssue(db, {
          orderId, userId, storeId, brandId: null, reason: "invalid_store", scope: null, values: {}, totalPrice: total,
        });
        return;
      }

      // ── 자기적립 제외 (prelaunch_security_bundle Layer1-C, 잠정 D-2: 브랜드 보유자 포함). 이미 읽은 매장 문서로 판정 (추가 read 0,
      //    브랜드 소속 매장일 때만 users/{uid} +1). **적립만** 막는다 — 회수(clawback)는 이 분기를 지나지 않아 불변.
      //    의도된 정책이라 qoinSettlementIssues 에 기록하지 않는다 (skipped_accrual_disabled 와 동일, Cloud Logging 만).
      if (storeSnap.exists) {
        const selfMatch = await findSelfDealing(db, userId, storeSnap.data() ?? {}); // 실패 시 throw -> 재시도
        if (selfMatch !== null) {
          console.info(`${LOG} skipped_self_dealing. orderId:`, orderId, { storeId, matchedBy: selfMatch });
          return;
        }
      }

      // ── 브랜드의 유일한 신뢰원: stores/{storeId}.brandId (F1). 주문·cart 의 brandId 는 보지 않는다.
      const storeBrand = storeSnap.exists ? storeSnap.get("brandId") : undefined;
      const brandId = typeof storeBrand === "string" && storeBrand.length > 0 ? storeBrand : null;
      // 읽기 묶음 2: 브랜드 소속일 때만 brands/{brandId} (순차 2단 — brandId 를 매장을 읽은 뒤에야 안다).
      const brandSnap = brandId ? await db.collection("brands").doc(brandId).get() : undefined;

      // 문서 부재(!exists) = 그 단계 설정 없음 = 상위 상속. 필드 부재(undefined) 도 같다.
      const rawStoreRate = storeSnap.exists ? storeSnap.get("qoinAccrualRate") : undefined;
      const rawStoreSwitch = storeSnap.exists ? storeSnap.get("qoinAccrualEnabled") : undefined;
      const rawBrandRate = brandSnap?.exists ? brandSnap.get("qoinAccrualRate") : undefined;
      const rawBrandSwitch = brandSnap?.exists ? brandSnap.get("qoinAccrualEnabled") : undefined;
      const resolved = resolveEffectiveRate(
        classifySwitch(rawStoreSwitch),
        classifyRate(rawStoreRate),
        classifySwitch(rawBrandSwitch),
        classifyRate(rawBrandRate),
        classifyRate(config.rawAccrualRate)
      );

      if (!resolved.ok) {
        // fail-closed. 어느 범위 때문에 멈췄는지 로그만으로 판별되게 reason 을 남기고, Firestore 에도 기록한다 (Q2 ⓐ).
        console.error(`${LOG} skipped_invalid_rate: ${resolved.reason}. orderId:`, orderId, { storeId, brandId });
        const { reason, scope } = issueFromInvalid(resolved.reason);
        await recordIssue(db, {
          orderId,
          userId,
          storeId,
          brandId,
          reason,
          scope,
          values: {
            storeRate: rawForIssue(rawStoreRate),
            storeEnabled: rawForIssue(rawStoreSwitch),
            brandRate: rawForIssue(rawBrandRate),
            brandEnabled: rawForIssue(rawBrandSwitch),
            globalRate: rawForIssue(config.rawAccrualRate),
          },
          totalPrice: total,
        });
        return;
      }
      if (resolved.disabled) {
        // 스위치 꺼짐 = 의도된 정책. 적립만 막는다 (회수는 이 분기를 지나지 않는다). 이슈 기록 없음 — 설정 이력이 영구 보존돼 있다.
        console.info(`${LOG} skipped_accrual_disabled. orderId:`, orderId, {
          source: resolved.source,
          storeId,
          brandId,
        });
        return;
      }

      const amount = computeEarnAmount(total, resolved.rate);
      if (amount <= 0) {
        console.info(`${LOG} skipped_zero_amount. orderId:`, orderId, { total, rate: resolved.rate });
        return;
      }

      const result = await applyTransaction(db, {
        userRef,
        txRef: txCol.doc(`earn_${orderId}`),
        amount,
        fields: {
          txId: `earn_${orderId}`,
          type: "earn",
          orderId,
          storeId: (after.storeId as string | undefined) ?? "",
          storeName: (after.storeName as string | undefined) ?? "",
          // brandId 는 매장별/브랜드별 적립 비용 정산에 필요하다 (audit_trail.md §5).
          // 요율을 결정한 바로 그 값(= stores/{id}.brandId)을 박제한다 — 정산 집계의 브랜드와 요율 결정의 브랜드가 같아야 한다.
          brandId,
          orderTotalPrice: total,
          accrualRate: resolved.rate,
          // 이 적립이 누구의 정책 때문에 발생했는지 (정산 N1 의 선행 자산). 지금 박제하지 않으면 소급 불가.
          accrualRateSource: resolved.source,
        },
      });
      logResult(result, "earn", orderId, userId, amount);
      return;
    }

    const ctx: LedgerCtx = { orderId, userId, after, configRef, userRef, txCol };
    if (isClawback) {
      // completed → refunded: config · earn · spend 를 한 왕복(getAll)으로 읽는다 — 사용 복원 확인이 왕복을 늘리지 않게 한다 (CH16).
      const [configSnap, earnSnap, spendSnap] = await db.getAll(
        configRef,
        txCol.doc(`earn_${orderId}`),
        txCol.doc(spendTxId(orderId))
      ); // 실패 시 throw -> 재시도
      await clawbackEarn(db, ctx, configSnap, earnSnap);
      await restoreSpend(db, ctx, spendSnap, configSnap);
    } else if (isRestore) {
      await restoreSpend(db, ctx);
    }
  }
);

type OrderData = admin.firestore.DocumentData;
interface LedgerCtx {
  orderId: string;
  userId: string;
  after: OrderData;
  configRef: admin.firestore.DocumentReference;
  userRef: admin.firestore.DocumentReference;
  txCol: admin.firestore.CollectionReference;
}

/** clawback: config(kill switch 만) → earn 원장에서 금액을 읽어 반전 (재계산 금지). 계층 read 0. (qoin_spend 이전 코드 그대로 — 함수로만 분리) */
async function clawbackEarn(
  db: admin.firestore.Firestore,
  ctx: LedgerCtx,
  configSnap: admin.firestore.DocumentSnapshot,
  earnSnap: admin.firestore.DocumentSnapshot
): Promise<void> {
    const { orderId, userId, after, userRef, txCol } = ctx;
    const config = evaluateConfig(configSnap, orderId);
    if (!config) return;
    if (!earnSnap.exists) {
      console.info(`${LOG} skipped_no_earn: no earn ledger for refunded order. orderId:`, orderId);
      return;
    }
    const earn = earnSnap.data() ?? {};
    const earnAmount = earn.amount;
    if (typeof earnAmount !== "number" || !Number.isFinite(earnAmount) || earnAmount <= 0) {
      console.error(`${LOG} skipped_invalid_earn_amount. orderId:`, orderId, "amount:", earnAmount);
      return;
    }
    const amount = -earnAmount;

    const result = await applyTransaction(db, {
      userRef,
      txRef: txCol.doc(`clawback_${orderId}`),
      amount,
      fields: {
        txId: `clawback_${orderId}`,
        type: "clawback",
        orderId,
        storeId: (earn.storeId as string | undefined) ?? (after.storeId as string | undefined) ?? "",
        storeName: (earn.storeName as string | undefined) ?? (after.storeName as string | undefined) ?? "",
        // earn 문서에서 상속한다 (재계산·주문 문서 참조 금지). 없던 과거 원장은 null.
        brandId: (earn.brandId as string | undefined) ?? null,
        orderTotalPrice: earn.orderTotalPrice ?? 0,
        accrualRate: earn.accrualRate ?? 0,
        // clawback 은 earn 문서에서 상속한다 (brandId 와 같은 패턴). 없던 과거 원장은 null.
        accrualRateSource: earn.accrualRateSource ?? null,
      },
    });
    logResult(result, "clawback", orderId, userId, amount);
}

/**
 * 사용 복원 (qoin_spend spec §6.1): spend 원장을 읽어 금액을 반전한다. 적립률·스위치 계층을 읽지 않는다 (read: spend 1 + config 1).
 * spend 원장이 없으면 no-op (Qoin 을 쓰지 않은 주문 — 대부분). 멱등 ID `spendRefund_{orderId}` — 결제 실패 롤백(verifyTossPayment)과 같은 ID.
 */
async function restoreSpend(
  db: admin.firestore.Firestore,
  ctx: LedgerCtx,
  knownSpendSnap?: admin.firestore.DocumentSnapshot,
  knownConfigSnap?: admin.firestore.DocumentSnapshot
): Promise<void> {
  const { orderId, userId, after, configRef, userRef, txCol } = ctx;
  const spendSnap = knownSpendSnap ?? (await txCol.doc(spendTxId(orderId)).get()); // 실패 시 throw -> 재시도
  if (!spendSnap.exists) return; // Qoin 미사용 주문 — 정상 경로

  const configSnap = knownConfigSnap ?? (await configRef.get()); // 실패 시 throw -> 재시도
  if (!configSnap.exists || (configSnap.data() ?? {}).enabled !== true) {
    // 전역 비상정지 중 복원 불가. 돈이 걸려 있어 로그로만 두지 않는다 — 수동 복구 대상 목록.
    console.warn(`${LOG} skipped_restore_disabled: config/qoin.enabled != true, spend ledger exists. orderId:`, orderId);
    await recordSpendIssue(db, {
      orderId,
      userId,
      storeId: typeof after.storeId === "string" ? after.storeId : "",
      reason: "spend_restore_skipped_disabled",
      values: { spendAmount: rawForIssue(spendSnap.get("amount")) },
    });
    return;
  }

  const spend = spendSnap.data() ?? {};
  const spent = spend.amount;
  if (typeof spent !== "number" || !Number.isFinite(spent) || spent >= 0) {
    console.error(`${LOG} skipped_invalid_spend_amount. orderId:`, orderId, "amount:", spent);
    return;
  }
  const amount = -spent;

  const result = await applyTransaction(db, {
    userRef,
    txRef: txCol.doc(`spendRefund_${orderId}`),
    amount,
    fields: spendRefundFields(spend, orderId, after),
  });
  logResult(result, "spendRefund", orderId, userId, amount);
}

function logResult(
  result: Outcome | "no_user",
  kind: string,
  orderId: string,
  userId: string,
  amount: number
): void {
  if (result === "no_user") {
    console.error(`${LOG} no_user: users doc missing. kind:`, kind, "orderId:", orderId, "userId:", userId);
    return;
  }
  console.info(`${LOG} ${result}.`, { kind, orderId, userId, amount });
}
