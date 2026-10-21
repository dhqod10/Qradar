/**
 * onOrderStatusChanged — Cloud Function (onDocumentUpdated, asia-northeast3)
 *
 * 흐름:
 *   1. orders/{orderId} 문서 업데이트 트리거
 *   2. before.status != after.status diff 검사 — 매칭 전이가 아니면 early return
 *   3. 발화 전이: paid→accepted / accepted→making / making→ready (orderProgress)
 *      + ready→completed (pickupComplete 옵트인, Phase 3c-3 결정 E)
 *   4. orders/{orderId}.userId → users/{userId}.fcmToken 조회
 *   5. fcmToken 없으면 skip / 알림 설정(settingKey) off 면 skip
 *   6. FCM data-only 메시지 발송
 *   7. invalid token → Firestore fcmToken 정리
 *   8. 발송 실패는 swallow
 */

import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import {
  isNotificationEnabled,
  NotificationSettingKey,
} from "./notificationSettings";

// 발화 전이 매트릭스. ready→completed 는 pickupComplete 옵트인 (Phase 3c-3 결정 E).
const NOTIFICATION_MATRIX: Record<
  string,
  {
    type: string;
    title: string;
    body: (storeName: string) => string;
    settingKey: NotificationSettingKey;
  }
> = {
  "paid->accepted": {
    type: "order_accepted",
    title: "주문이 접수되었어요",
    body: (n) => `${n}에서 주문을 받았어요.`,
    settingKey: "orderProgress",
  },
  "accepted->making": {
    type: "order_making",
    title: "음료를 만들고 있어요",
    body: (n) => `${n}에서 조리를 시작했어요.`,
    settingKey: "orderProgress",
  },
  "making->ready": {
    type: "order_ready",
    title: "픽업 준비가 완료됐어요",
    body: (n) => `${n}에서 음료가 준비됐어요. 매장에 방문해 주세요.`,
    settingKey: "orderProgress",
  },
  // Phase 3c-3 결정 E: pickupComplete 옵트인 (기본 false → 기존 사용자 미발화)
  "ready->completed": {
    type: "order_completed",
    title: "픽업이 완료됐어요",
    body: (n) => `${n}에서 받은 음료, 맛있게 즐겨주세요.`,
    settingKey: "pickupComplete",
  },
};

export const onOrderStatusChanged = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-northeast3",
  },
  async (event) => {
    const orderId = event.params.orderId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) {
      console.warn("[onOrderStatusChanged] Missing before/after data. orderId:", orderId);
      return;
    }

    // 2. status diff 검사
    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;

    if (!beforeStatus || !afterStatus || beforeStatus === afterStatus) {
      return; // F8: status 무변경이면 skip
    }

    const matrixKey = `${beforeStatus}->${afterStatus}`;
    const matrix = NOTIFICATION_MATRIX[matrixKey];
    if (!matrix) {
      return; // 매트릭스 미정의 전이 — early return
    }

    // 3. userId / storeName / storeId 추출
    const userId: string | undefined = after.userId;
    const storeName: string = after.storeName ?? "매장";
    const storeId: string | undefined = after.storeId;

    if (!userId) {
      console.warn("[onOrderStatusChanged] userId missing. orderId:", orderId, "matrixKey:", matrixKey);
      return;
    }

    const db = admin.firestore();

    // 4. users/{userId}.fcmToken 조회
    let fcmToken: string | undefined;
    let userData: Record<string, unknown> | undefined;
    try {
      const userSnap = await db.collection("users").doc(userId).get();
      userData = userSnap.data();
      fcmToken = userData?.fcmToken as string | undefined;
    } catch (err) {
      console.error("[onOrderStatusChanged] Failed to fetch user. userId:", userId, err);
      return;
    }

    // 5. fcmToken 없으면 skip
    if (!fcmToken) {
      console.info(
        "[onOrderStatusChanged] No fcmToken.",
        { userId, orderId, matrixKey }
      );
      return;
    }

    // 5-1. 알림 설정 게이트 (Phase 3c-3)
    if (!isNotificationEnabled(userData, matrix.settingKey)) {
      console.info("[onOrderStatusChanged] Skipped.", {
        userId,
        orderId,
        key: matrix.settingKey,
        reason: "disabled_by_user",
      });
      return;
    }

    // payload 구성 (Phase 3b 와 동일 구조)
    const message: admin.messaging.Message = {
      token: fcmToken,
      data: {
        type: matrix.type,
        orderId,
        storeId: storeId ?? "",
        title: matrix.title,
        body: matrix.body(storeName),
      },
    };

    // 6. FCM 발송
    try {
      await admin.messaging().send(message);
      console.info(
        "[onOrderStatusChanged] FCM sent.",
        { orderId, userId, matrixKey }
      );
    } catch (err: unknown) {
      // 7. invalid token → Firestore fcmToken 정리
      const errorCode = (err as { code?: string })?.code;
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        console.warn(
          "[onOrderStatusChanged] Invalid FCM token — clearing. userId:", userId
        );
        try {
          await db.collection("users").doc(userId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (cleanupErr) {
          console.error("[onOrderStatusChanged] Failed to clear token:", cleanupErr);
        }
      } else {
        // 8. 그 외 발송 실패 — swallow
        console.error("[onOrderStatusChanged] FCM send failed (swallowed):", err);
      }
    }
  }
);
