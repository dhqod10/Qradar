/**
 * Qoin 사용(spend) 원장 쓰기 — Firestore 트랜잭션 헬퍼. qoin_spend spec §5.4, §5.5, §7.2.
 *
 * 판정은 `qoinSpend.ts`(순수)가 하고, 여기는 **읽기 → 판정 → 차감+원장** 을 한 트랜잭션으로 묶는다.
 *
 * 설계 (사용자 확정 — 차감은 Toss confirm **전**):
 *   1. `reserveSpend` — confirm 전. 잔액 read·판정·차감·원장(`spend_{orderId}`)을 한 트랜잭션에서. 실패하면 돈이 안 움직인다.
 *      → "confirm 후 잔액 부족" 케이스가 원천적으로 없다 (동시 결제 2건이면 두 번째가 여기서 거절된다).
 *   2. confirm 실패·응답 검증 실패·주문 쓰기 실패 → `rollbackSpend` — 같은 트랜잭션에서 `spendRefund_{orderId}` 반전 원장 + 잔액 복원.
 *      삭제하지 않는다 (원장 append-only 유지, 불변식 `balance == Σ amount`).
 *      주문 키(idempotencyKey)는 결제 시도마다 새로 만들어지므로 같은 orderId 가 다시 쓰이지 않는다 — 반전 원장이 이후 복원과 충돌하지 않는다.
 *   3. 환불/취소 시 복원은 `onOrderQoinSettled` 가 같은 문서 ID(`spendRefund_{orderId}`) 로 멱등 처리한다.
 *
 * 멱등: `spend_{orderId}` 선존재 → `SpendConflictError` (같은 키로 처리 중이거나, 크래시로 남은 예약). 두 번째 호출은 차감하지 않고,
 * 롤백도 하지 않는다 (롤백은 자기가 만든 예약만 한다).
 *
 * 잔액은 절대값으로 쓴다 (`FieldValue.increment` 금지 — `balanceAfter` 정합). users 에는 `qoinBalance` 1필드만 쓴다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { SpendPolicy, SpendRejectReason, validateQoinSpend } from "./qoinSpend";

export class SpendRejectedError extends Error {
  constructor(
    public readonly reason: SpendRejectReason,
    public readonly detail: Record<string, unknown>
  ) {
    super(`spend rejected: ${reason}`);
  }
}

/** 같은 주문 키의 `spend_{orderId}` 가 이미 있다 — 동시 처리 중이거나 이전 시도가 남긴 예약. */
export class SpendConflictError extends Error {
  constructor() {
    super("spend ledger already exists for this order");
  }
}

const balanceOf = (snap: admin.firestore.DocumentSnapshot): number => {
  if (!snap.exists) return 0;
  const raw = snap.get("qoinBalance");
  return typeof raw === "number" && Number.isFinite(raw) ? raw : 0;
};

export const spendTxId = (orderId: string): string => `spend_${orderId}`;
export const spendRefundTxId = (orderId: string): string => `spendRefund_${orderId}`;

/**
 * `spendRefund` 원장 필드 — spend 원장에서 **상속**한다 (재계산·주문 문서 참조 금지, clawback 과 같은 패턴).
 * `amount` / `balanceAfter` / `createdAt` 은 호출자가 넣는다.
 */
export function spendRefundFields(
  spend: Record<string, unknown>,
  orderId: string,
  fallback: { storeId?: unknown; storeName?: unknown }
): Record<string, unknown> {
  return {
    txId: spendRefundTxId(orderId),
    type: "spendRefund",
    orderId,
    storeId: (spend.storeId as string | undefined) ?? (fallback.storeId as string | undefined) ?? "",
    storeName: (spend.storeName as string | undefined) ?? (fallback.storeName as string | undefined) ?? "",
    brandId: (spend.brandId as string | undefined) ?? null,
    orderSubtotal: spend.orderSubtotal ?? 0,
    orderTotalPrice: spend.orderTotalPrice ?? 0,
  };
}

/**
 * 예약(차감) — Toss confirm **전**. 한 트랜잭션: spend 선존재 가드 → 잔액 read → 판정 → 원장 create + 잔액 update.
 * 판정 실패는 `SpendRejectedError`, 선존재는 `SpendConflictError`. 그 외 예외는 그대로 전파(호출자가 일시장애로 처리).
 */
export async function reserveSpend(
  db: admin.firestore.Firestore,
  args: {
    uid: string;
    orderId: string;
    requested: number;
    policy: SpendPolicy;
    serverSubtotal: number;
    serverFinal: number;
    storeId: string;
    storeName: string;
    brandId: string | null;
  }
): Promise<{ balanceAfter: number }> {
  const userRef = db.collection("users").doc(args.uid);
  const spendRef = userRef.collection("qoinTransactions").doc(spendTxId(args.orderId));
  return db.runTransaction(async (t) => {
    const spendSnap = await t.get(spendRef); // 멱등 가드
    if (spendSnap.exists) throw new SpendConflictError();
    const userSnap = await t.get(userRef);
    const before = balanceOf(userSnap);

    const verdict = validateQoinSpend({
      requested: args.requested,
      balance: before,
      serverSubtotal: args.serverSubtotal,
      policy: args.policy,
    });
    if (!verdict.ok) throw new SpendRejectedError(verdict.reason, verdict.detail);

    const after = before - verdict.validatedQ;
    t.set(spendRef, {
      txId: spendTxId(args.orderId),
      type: "spend",
      amount: -verdict.validatedQ,
      balanceAfter: after,
      orderId: args.orderId,
      storeId: args.storeId,
      storeName: args.storeName,
      brandId: args.brandId,
      // 당시 값 박제 (audit_trail §4-3) — 정책이 바뀌어도 과거 사용 기록은 불변.
      orderSubtotal: args.serverSubtotal,
      orderTotalPrice: args.serverFinal,
      createdAt: FieldValue.serverTimestamp(),
    });
    t.update(userRef, { qoinBalance: after }); // 이 1필드만. updatedAt 금지
    return { balanceAfter: after };
  });
}

export type RollbackOutcome = "rolled_back" | "no_spend" | "already_refunded";

/**
 * 롤백 — 예약을 반전 원장(`spendRefund_{orderId}`)으로 되돌린다. 멱등 (이미 반전됐으면 no-op).
 * `reason` 은 원장에 박제된다 (왜 되돌렸나 — confirm 실패 / 응답 검증 실패 / 주문 쓰기 실패).
 */
export async function rollbackSpend(
  db: admin.firestore.Firestore,
  args: { uid: string; orderId: string; reason: string; storeId: string; storeName: string }
): Promise<RollbackOutcome> {
  const userRef = db.collection("users").doc(args.uid);
  const col = userRef.collection("qoinTransactions");
  const spendRef = col.doc(spendTxId(args.orderId));
  const refundRef = col.doc(spendRefundTxId(args.orderId));
  return db.runTransaction(async (t) => {
    const spendSnap = await t.get(spendRef);
    if (!spendSnap.exists) return "no_spend" as const;
    const refundSnap = await t.get(refundRef);
    if (refundSnap.exists) return "already_refunded" as const;
    const userSnap = await t.get(userRef);

    const spend = spendSnap.data() ?? {};
    const spent = spend.amount;
    if (typeof spent !== "number" || !Number.isFinite(spent) || spent >= 0) {
      throw new Error(`invalid spend amount: ${String(spent)}`);
    }
    const amount = -spent;
    const after = balanceOf(userSnap) + amount;
    t.set(refundRef, {
      ...spendRefundFields(spend, args.orderId, args),
      amount,
      balanceAfter: after,
      rollbackReason: args.reason,
      createdAt: FieldValue.serverTimestamp(),
    });
    t.update(userRef, { qoinBalance: after });
    return "rolled_back" as const;
  });
}

/**
 * 롤백/복원이 **실패하거나 건너뛴** 고객 돈을 Firestore 에 남긴다 (`qoinSettlementIssues`, 문서 ID = orderId → 멱등).
 * 로그에만 남기면 사라진다 (audit_trail §4-6). 쓰기 실패는 삼키고 로그 (이미 실패 처리 중이라 원본 에러를 가리지 않는다).
 */
export async function recordSpendIssue(
  db: admin.firestore.Firestore,
  issue: {
    orderId: string;
    userId: string;
    storeId: string;
    reason: "spend_rollback_failed" | "spend_restore_skipped_disabled";
    values: Record<string, unknown>;
  }
): Promise<void> {
  try {
    await db.collection("qoinSettlementIssues").doc(issue.orderId).create({
      orderId: issue.orderId,
      userId: issue.userId,
      storeId: issue.storeId,
      brandId: null,
      reason: issue.reason,
      scope: null,
      values: issue.values,
      totalPrice: "(n/a)",
      occurredAt: FieldValue.serverTimestamp(),
      resolved: false,
    });
  } catch (e) {
    if ((e as { code?: number }).code === 6) return; // ALREADY_EXISTS
    console.error("[qoinSpendLedger] recordSpendIssue failed", issue.reason, issue.orderId, e);
  }
}
