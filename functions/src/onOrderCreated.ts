/**
 * onOrderCreated — Cloud Function (onDocumentCreated, asia-northeast3)
 *
 * 흐름:
 *   1. orders/{orderId} 문서 생성 트리거
 *   2. storeId → stores/{storeId} → ownerId 조회
 *   3. users/{ownerId}.fcmToken 조회
 *   4. fcmToken 없으면 skip + 구조화된 로그
 *   5. FCM data-only 메시지 발송 (결정 B)
 *   6. invalid token → Firestore fcmToken 정리 (결정 G)
 *   7. 발송 실패는 swallow (결정 G)
 */

import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { isNotificationEnabled } from "./notificationSettings";

export const onOrderCreated = onDocumentCreated(
  {
    document: "orders/{orderId}",
    region: "asia-northeast3",
  },
  async (event) => {
    const orderId = event.params.orderId;
    const orderData = event.data?.data();

    if (!orderData) {
      console.warn("[onOrderCreated] No data in event. orderId:", orderId);
      return;
    }

    const storeId: string | undefined = orderData.storeId;
    const storeName: string = orderData.storeName ?? "매장";
    const items: Array<{ menuItemName?: string; quantity?: number }> =
      orderData.items ?? [];
    const totalPrice: number = orderData.totalPrice ?? 0;

    if (!storeId) {
      console.warn("[onOrderCreated] storeId missing. orderId:", orderId);
      return;
    }

    const db = admin.firestore();

    // 2. stores/{storeId} → ownerId
    let ownerId: string | undefined;
    try {
      const storeSnap = await db.collection("stores").doc(storeId).get();
      ownerId = storeSnap.data()?.ownerId as string | undefined;
    } catch (err) {
      console.error("[onOrderCreated] Failed to fetch store. storeId:", storeId, err);
      return;
    }

    if (!ownerId) {
      console.warn("[onOrderCreated] ownerId missing. storeId:", storeId, "orderId:", orderId);
      return;
    }

    // 3. users/{ownerId}.fcmToken
    let fcmToken: string | undefined;
    let userData: Record<string, unknown> | undefined;
    try {
      const userSnap = await db.collection("users").doc(ownerId).get();
      userData = userSnap.data();
      fcmToken = userData?.fcmToken as string | undefined;
    } catch (err) {
      console.error("[onOrderCreated] Failed to fetch user. ownerId:", ownerId, err);
      return;
    }

    // 4. fcmToken 없으면 skip
    if (!fcmToken) {
      console.info("[onOrderCreated] No fcmToken. ownerId:", ownerId, "orderId:", orderId);
      return;
    }

    // 4-1. 알림 설정 게이트 (Phase 3c-3) — newOrder
    if (!isNotificationEnabled(userData, "newOrder")) {
      console.info("[onOrderCreated] Skipped.", {
        userId: ownerId,
        orderId,
        key: "newOrder",
        reason: "disabled_by_user",
      });
      return;
    }

    // payload 구성
    const firstItemName = items[0]?.menuItemName ?? "메뉴";
    const extraCount = items.length - 1;
    const bodyText =
      extraCount > 0
        ? `${firstItemName} 외 ${extraCount}건 · ${totalPrice.toLocaleString("ko-KR")}원`
        : `${firstItemName} · ${totalPrice.toLocaleString("ko-KR")}원`;

    const message: admin.messaging.Message = {
      token: fcmToken,
      data: {
        type: "new_order",
        orderId,
        storeId,
        title: `주문이 들어왔어요 · ${storeName}`,
        body: bodyText,
      },
    };

    // 5. FCM 발송
    try {
      await admin.messaging().send(message);
      console.info("[onOrderCreated] FCM sent. orderId:", orderId, "ownerId:", ownerId);
    } catch (err: unknown) {
      // 6. invalid token → Firestore fcmToken 정리
      const errorCode = (err as { code?: string })?.code;
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        console.warn(
          "[onOrderCreated] Invalid FCM token — clearing. ownerId:",
          ownerId
        );
        try {
          await db.collection("users").doc(ownerId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (cleanupErr) {
          console.error("[onOrderCreated] Failed to clear token:", cleanupErr);
        }
      } else {
        // 7. 그 외 발송 실패 — swallow
        console.error("[onOrderCreated] FCM send failed (swallowed):", err);
      }
    }
  }
);
