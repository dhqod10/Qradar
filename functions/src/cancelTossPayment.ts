/**
 * cancelTossPayment — Cloud Function (onCall, asia-northeast3)
 *
 * paid → cancelled 상태 전이.
 *
 * 흐름:
 *   1. 인증 확인
 *   2. 입력값 검증
 *   3. Firestore orders/{orderId} read
 *   4. status === 'paid' 확인 (아니면 failed-precondition)
 *   5. Toss cancel API 호출
 *   6. Firestore update: status='cancelled', cancelInfo, updatedAt, cancelledAt
 *   7. 반환 { orderId, status: 'cancelled' }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { cancelPayment } from "./tossClient";

const tossSecretKey = defineSecret("TOSS_SECRET_KEY");

interface CancelPaymentInput {
  orderId: string;
  reason: string;
  approvedBy: "customer" | "owner";
}

export const cancelTossPayment = onCall(
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
    const data = request.data as CancelPaymentInput;

    // 2. 입력값 검증
    if (!data.orderId || !data.reason || !data.approvedBy) {
      throw new HttpsError(
        "invalid-argument",
        "필수 입력값이 누락되었습니다. (orderId, reason, approvedBy)"
      );
    }
    if (data.approvedBy !== "customer" && data.approvedBy !== "owner") {
      throw new HttpsError(
        "invalid-argument",
        "approvedBy 는 'customer' 또는 'owner' 여야 합니다."
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

    // 4. status 확인 (atomic)
    if (order["status"] !== "paid") {
      const currentStatus = order["status"];
      // 이미 accepted 이상이면 환불 흐름 안내
      throw new HttpsError(
        "failed-precondition",
        `이미 매장이 접수했어요. 환불 요청을 이용해주세요. (현재 상태: ${currentStatus})`
      );
    }

    // customer 인 경우 본인 주문인지 확인
    if (data.approvedBy === "customer" && order["userId"] !== uid) {
      throw new HttpsError("permission-denied", "본인의 주문만 취소할 수 있습니다.");
    }

    // owner 인 경우 해당 매장 점주인지 확인
    if (data.approvedBy === "owner") {
      const storeId = order["storeId"] as string;
      const storeSnap = await db.collection("stores").doc(storeId).get();
      if (!storeSnap.exists || storeSnap.data()?.["ownerId"] !== uid) {
        throw new HttpsError("permission-denied", "해당 매장의 점주만 취소할 수 있습니다.");
      }
    }

    // 5. Toss cancel API
    const paymentInfo = order["paymentInfo"] as Record<string, unknown>;
    const paymentKey = paymentInfo["paymentKey"] as string;

    const tossResponse = await cancelPayment(tossSecretKey.value(), {
      paymentKey,
      cancelReason: data.reason,
    });

    // cancels 배열에서 첫 번째 항목 추출
    const cancelEntry = tossResponse.cancels?.[0];

    // 6. Firestore update
    const now = admin.firestore.FieldValue.serverTimestamp();
    const cancelledAt = cancelEntry?.canceledAt
      ? admin.firestore.Timestamp.fromDate(new Date(cancelEntry.canceledAt))
      : now;

    await orderRef.update({
      status: "cancelled",
      cancelInfo: {
        reason: data.reason,
        approvedBy: data.approvedBy,
        cancelledAt,
        cancellationKey: cancelEntry?.transactionKey ?? null,
      },
      cancelledAt,
      updatedAt: now,
    });

    // 7. 반환
    return { orderId: data.orderId, status: "cancelled" };
  }
);
