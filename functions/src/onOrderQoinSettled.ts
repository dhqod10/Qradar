/**
 * onOrderQoinSettled — Cloud Function (onDocumentUpdated, asia-northeast3)
 *
 * 주문 상태 전이에 따라 고객 Qoin 을 적립 / 회수한다.
 *   - `* -> completed`        : 적립 (floor(totalPrice * accrualRate))
 *   - `completed -> refunded` : 회수 (earn 원장의 amount 를 읽어 반전. 재계산 금지)
 *
 * 설계 (docs/tasks/qoin/spec.md §4, §5, §6, §9):
 *   - 원장 `users/{uid}/qoinTransactions/{txId}` 는 append-only.
 *     잔액 `users/{uid}.qoinBalance` 는 **같은 트랜잭션 안에서** 절대값으로 갱신한다.
 *     (전량 재계산 / FieldValue.increment 사용 금지 — 2차 Qoin 사용과 레이스 + balanceAfter 정합성)
 *   - 멱등: 결정적 문서 ID `earn_{orderId}` / `clawback_{orderId}` + 트랜잭션 내 선존재 가드.
 *   - users 에는 `qoinBalance` 1필드만 쓴다 (updatedAt 금지). orders 는 읽기 전용.
 *   - 적립률은 `config/qoin` 에서만 읽는다. 코드에 기본값 폴백을 두지 않는다 (fail-closed).
 *   - enabled !== true 이면 적립도 **회수도** 하지 않는다 (spec §5.5).
 *   - 실패 정책: 알림 CF 와 정반대. 일시 장애는 throw (retry: true 로 재시도, 멱등하므로 안전),
 *     영구 오류는 console.error + return. 조용히 삼키지 않는다.
 *   - 단수 처리는 버림(floor) 고정. round / ceil 금지.
 *
 * 주의: 트리거가 onDocumentUpdated 이므로 completed 로 **생성**한 주문은 발화하지 않는다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const LOG = "[onOrderQoinSettled]";

type Outcome = "applied" | "already_applied";

/** config/qoin 을 검증해 반환. 영구 오류면 null (이미 로그 출력). 읽기 실패는 throw. */
async function loadConfig(
  db: admin.firestore.Firestore,
  orderId: string
): Promise<{ accrualRate: number } | null> {
  const snap = await db.collection("config").doc("qoin").get(); // 실패 시 throw -> 재시도
  if (!snap.exists) {
    console.error(`${LOG} skipped_no_config: config/qoin missing. orderId:`, orderId);
    return null;
  }
  const data = snap.data() ?? {};
  if (data.enabled !== true) {
    console.warn(`${LOG} skipped_disabled: config/qoin.enabled != true. orderId:`, orderId);
    return null;
  }
  const rate = data.accrualRate;
  // 관리자 화면의 경계(0.1~20%)와 동일하게 서버에서도 막는다.
  // CF 가 0..1 만 보면 Console 로 `0.5` 를 써 50% 적립이 가능해진다 — 화면 검증은
  // 우회될 수 있으므로 돈을 발행하는 쪽에도 같은 경계가 있어야 한다.
  const MIN_RATE = 0.001; // 0.1%
  const MAX_RATE = 0.2; //  20%
  if (
    typeof rate !== "number" ||
    !Number.isFinite(rate) ||
    rate < MIN_RATE ||
    rate > MAX_RATE
  ) {
    console.error(`${LOG} skipped_invalid_rate: accrualRate invalid. orderId:`, orderId, "value:", rate);
    return null;
  }
  return { accrualRate: rate };
}

/**
 * floor(total * rate). 부동소수 오차(4500*0.03 등) 를 피하려고 ppm 정수로 환산해 계산한다.
 */
function computeEarnAmount(total: number, rate: number): number {
  const ppm = Math.round(rate * 1_000_000);
  return Math.floor((total * ppm) / 1_000_000);
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

    // 전이 매트릭스: `* -> completed` 적립, `completed -> refunded` 회수. 그 외 무동작.
    let kind: "earn" | "clawback";
    if (afterStatus === "completed") {
      kind = "earn";
    } else if (beforeStatus === "completed" && afterStatus === "refunded") {
      kind = "clawback";
    } else {
      return;
    }

    const userId = after.userId as string | undefined;
    if (!userId) {
      console.error(`${LOG} userId missing. orderId:`, orderId);
      return;
    }

    const db = admin.firestore();

    // 설정 검증 (fail-closed). enabled=false 면 적립/회수 모두 중단.
    const config = await loadConfig(db, orderId);
    if (!config) return;

    const userRef = db.collection("users").doc(userId);
    const txCol = userRef.collection("qoinTransactions");

    if (kind === "earn") {
      const total = after.totalPrice;
      if (typeof total !== "number" || !Number.isFinite(total) || total <= 0) {
        console.error(`${LOG} skipped_invalid_total. orderId:`, orderId, "totalPrice:", total);
        return;
      }
      const amount = computeEarnAmount(total, config.accrualRate);
      if (amount <= 0) {
        console.info(`${LOG} skipped_zero_amount. orderId:`, orderId, { total, rate: config.accrualRate });
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
          // 나중에 추가하면 과거 원장에 값이 없어 소급 집계가 불가능하므로 지금부터 남긴다.
          brandId: (after.brandId as string | undefined) ?? null,
          orderTotalPrice: total,
          accrualRate: config.accrualRate,
        },
      });
      logResult(result, "earn", orderId, userId, amount);
      return;
    }

    // clawback: earn 원장에서 금액을 읽어 반전 (재계산 금지)
    const earnSnap = await txCol.doc(`earn_${orderId}`).get(); // 실패 시 throw -> 재시도
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
        brandId: (earn.brandId as string | undefined) ?? (after.brandId as string | undefined) ?? null,
        orderTotalPrice: earn.orderTotalPrice ?? 0,
        accrualRate: earn.accrualRate ?? 0,
      },
    });
    logResult(result, "clawback", orderId, userId, amount);
  }
);

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
