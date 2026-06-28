/**
 * onOrderRefundRequested — Cloud Function (onDocumentUpdated, asia-northeast3)
 *
 * 흐름:
 *   1. orders/{orderId} 문서 업데이트 트리거
 *   2. before/after diff: before.refundRequest == null && after.refundRequest != null 일 때만 처리
 *   3. storeId → stores/{storeId} → ownerId 조회
 *   4. users/{ownerId}.fcmToken 조회
 *   5. fcmToken 없으면 skip
 *   6. FCM data-only 메시지 발송
 *   7. invalid token → Firestore fcmToken 정리
 *   8. 발송 실패는 swallow
 */

import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

export const onOrderRefundRequested = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-northeast3",
  },
  async (event) => {
    const orderId = event.params.orderId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) {
      console.warn("[onOrderRefundRequested] Missing before/after data. orderId:", orderId);
      return;
    }

    // 2. refundRequest 신규 등록 여부 확인
    const hadRefundRequest = before.refundRequest != null;
    const hasRefundRequest = after.refundRequest != null;

    if (hadRefundRequest || !hasRefundRequest) {
      // 이미 refundRequest 있었거나, after 에도 없으면 skip
      return;
    }

    const storeId: string | undefined = after.storeId;
    const storeName: string = after.storeName ?? "매장";
    const items: Array<{ menuItemName?: string; quantity?: number }> =
      after.items ?? [];
    const refundRequest: { reason?: string } = after.refundRequest ?? {};

    if (!storeId) {
      console.warn("[onOrderRefundRequested] storeId missing. orderId:", orderId);
      return;
    }

    const db = admin.firestore();

    // 3. stores/{storeId} → ownerId
    let ownerId: string | undefined;
    try {
      const storeSnap = await db.collection("stores").doc(storeId).get();
      ownerId = storeSnap.data()?.ownerId as string | undefined;
    } catch (err) {
      console.error("[onOrderRefundRequested] Failed to fetch store. storeId:", storeId, err);
      return;
    }

    if (!ownerId) {
      console.warn("[onOrderRefundRequested] ownerId missing. storeId:", storeId, "orderId:", orderId);
      return;
    }

    // 4. users/{ownerId}.fcmToken
    let fcmToken: string | undefined;
    try {
      const userSnap = await db.collection("users").doc(ownerId).get();
      fcmToken = userSnap.data()?.fcmToken as string | undefined;
    } catch (err) {
      console.error("[onOrderRefundRequested] Failed to fetch user. ownerId:", ownerId, err);
      return;
    }

    // 5. fcmToken 없으면 skip
    if (!fcmToken) {
      console.info(
        "[onOrderRefundRequested] No fcmToken. ownerId:", ownerId, "orderId:", orderId
      );
      return;
    }

    // payload 구성
    const firstItemName = items[0]?.menuItemName ?? "메뉴";
    const extraCount = items.length - 1;
    const reasonSnippet = refundRequest.reason
      ? refundRequest.reason.length > 20
        ? refundRequest.reason.substring(0, 20) + "…"
        : refundRequest.reason
      : "";

    const bodyText =
      extraCount > 0
        ? `${firstItemName} 외 ${extraCount}건 · ${reasonSnippet}`
        : `${firstItemName} · ${reasonSnippet}`;

    const message: admin.messaging.Message = {
      token: fcmToken,
      data: {
        type: "refund_request",
        orderId,
        storeId,
        title: `환불 요청 · ${storeName}`,
        body: bodyText,
      },
    };

    // 6. FCM 발송
    try {
      await admin.messaging().send(message);
      console.info(
        "[onOrderRefundRequested] FCM sent. orderId:", orderId, "ownerId:", ownerId
      );
    } catch (err: unknown) {
      // 7. invalid token → Firestore fcmToken 정리
      const errorCode = (err as { code?: string })?.code;
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        console.warn(
          "[onOrderRefundRequested] Invalid FCM token — clearing. ownerId:", ownerId
        );
        try {
          await db.collection("users").doc(ownerId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (cleanupErr) {
          console.error("[onOrderRefundRequested] Failed to clear token:", cleanupErr);
        }
      } else {
        // 8. 그 외 발송 실패 — swallow
        console.error("[onOrderRefundRequested] FCM send failed (swallowed):", err);
      }
    }
  }
);
