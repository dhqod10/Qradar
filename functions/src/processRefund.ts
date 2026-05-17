/**
 * processRefund — Cloud Function (onCall, asia-northeast3)
 *
 * accepted+ → refunded 상태 전이. 점주(owner) 가 환불 요청을 승인할 때 호출.
 *
 * 흐름:
 *   1. 인증 확인
 *   2. 입력값 검증
 *   3. Firestore orders/{orderId} read
 *   4. refundRequest 존재 확인
 *   5. 점주 권한 확인 (storeId.ownerId === auth.uid)
 *   6. status 가 환불 가능 상태인지 확인 (accepted / making / ready / completed)
 *   7. Toss cancel API 전액 환불
 *   8. Firestore update: status='refunded', refundInfo, refundedAt, updatedAt
 *   9. 반환 { orderId, status: 'refunded' }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { cancelPayment } from "./tossClient";

const tossSecretKey = defineSecret("TOSS_SECRET_KEY");

/** 환불 가능 상태 목록. paid 는 cancelTossPayment 로 처리하므로 제외. */
const REFUNDABLE_STATUSES = new Set([
  "accepted",
  "making",
  "ready",
  "completed",
]);

interface ProcessRefundInput {
  orderId: string;
  reason: string;
}

export const processRefund = onCall(
  {
    region: "asia-northeast3",
    secrets: [tossSecretKey],
  },
  async (request) => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = request.auth.uid;
    const data = request.data as ProcessRefundInput;

    // 2. 입력값 검증
    if (!data.orderId || !data.reason) {
      throw new HttpsError(
        "invalid-argument",
        "필수 입력값이 누락되었습니다. (orderId, reason)"
      );
    }

    // 3. Firestore read
    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(data.orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      throw new HttpsError("not-found", `주문을 찾을 수 없습니다. (${data.orderId})`);
    }

    const order = orderSnap.data() as Record<string, unknown>;

    // 4. refundRequest 존재 확인
    if (!order["refundRequest"]) {
      throw new HttpsError(
        "failed-precondition",
        "환불 요청이 존재하지 않습니다. 고객이 먼저 환불 요청을 해야 합니다."
      );
    }

    // 5. 점주 권한 확인
    const storeId = order["storeId"] as string;
    const storeSnap = await db.collection("stores").doc(storeId).get();

    if (!storeSnap.exists) {
      throw new HttpsError("not-found", `매장을 찾을 수 없습니다. (${storeId})`);
    }

    const storeData = storeSnap.data() as Record<string, unknown>;
    if (storeData["ownerId"] !== uid) {
      throw new HttpsError(
        "permission-denied",
        "해당 매장의 점주만 환불을 처리할 수 있습니다."
      );
    }

    // 6. 환불 가능 상태 확인
    const currentStatus = order["status"] as string;
    if (!REFUNDABLE_STATUSES.has(currentStatus)) {
      throw new HttpsError(
        "failed-precondition",
        `현재 상태(${currentStatus})에서는 환불 처리가 불가능합니다. ` +
          `환불 가능 상태: ${[...REFUNDABLE_STATUSES].join(", ")}`
      );
    }

    // 7. Toss cancel API (전액 환불)
    const paymentInfo = order["paymentInfo"] as Record<string, unknown>;
    const paymentKey = paymentInfo["paymentKey"] as string;

    const tossResponse = await cancelPayment(tossSecretKey.value(), {
      paymentKey,
      cancelReason: data.reason,
    });

    const cancelEntry = tossResponse.cancels?.[0];

    // 8. Firestore update
    const now = admin.firestore.FieldValue.serverTimestamp();
    const refundedAt = cancelEntry?.canceledAt
      ? admin.firestore.Timestamp.fromDate(new Date(cancelEntry.canceledAt))
      : now;

    await orderRef.update({
      status: "refunded",
      refundInfo: {
        cancellationKey: cancelEntry?.transactionKey ?? null,
        reason: data.reason,
        approvedBy: uid,
        processedAt: refundedAt,
        amount: order["totalPrice"] as number,
      },
      refundedAt,
      updatedAt: now,
    });

    // 9. 반환
    return { orderId: data.orderId, status: "refunded" };
  }
);
