/**
 * Qradar Cloud Functions — entry point.
 *
 * region: asia-northeast3 (서울)
 * 각 함수 파일에서 region 을 개별 지정하므로 여기서는 export 만 한다.
 */

import * as admin from "firebase-admin";

// firebase-admin 초기화 (이미 초기화된 경우 스킵)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { verifyTossPayment } from "./verifyTossPayment";
export { cancelTossPayment } from "./cancelTossPayment";
export { processRefund } from "./processRefund";
export { verifyNaverToken } from "./verifyNaverToken";
export { verifyKakaoToken } from "./verifyKakaoToken";
export { onOrderCreated } from "./onOrderCreated";
export { onOrderRefundRequested } from "./onOrderRefundRequested";
export { onOrderStatusChanged } from "./onOrderStatusChanged";
export { onReviewWritten } from "./onReviewWritten";
export { onOrderQoinSettled } from "./onOrderQoinSettled";
