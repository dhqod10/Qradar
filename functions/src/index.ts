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
export { setQoinAccrualRate } from "./setQoinAccrualRate";
export { setQoinAccrualEnabled } from "./setQoinAccrualEnabled";
// qoin_spend — 전역 사용 정책 (admin callable, 변경 이력 동시 기록)
export { setQoinSpendPolicy } from "./setQoinSpendPolicy";
export { applyBrandQoinRate } from "./applyBrandQoinRate";
export { onQoinConfigWritten } from "./onQoinConfigWritten";
export { claimSubmittedBrand } from "./claimSubmittedBrand";
// 읽기 전용 운영 점검 도구 (상시) — 쓰기 0, 인자 없음. 데이터 사고 복구 검증에서 값을 했다.
export { auditBrandLinks } from "./auditBrandLinks";

// payment_server_authority — brandKey 서버 발급·조회, 매장 삭제(admin 전담)
export { lookupBrandByKey } from "./lookupBrandByKey";
export { issueBrandKey } from "./issueBrandKey";
export { deleteStore } from "./deleteStore";
// payment_server_authority — 임시 마이그레이션 (완료 후 정리 커밋으로 삭제: 배포 ⑪)
export { migrateStoreApprovalMeta } from "./migrateStoreApprovalMeta";
export { migrateBrandPrivateProfile } from "./migrateBrandPrivateProfile";

// payment_price_authority — 가격 변경 이력 트리거 (R16, 상시). 문서 종류별 진입점이 같은 핵심(recordPriceChange)을 쓴다.
export {
  onMenuPriceWritten,
  onBrandMenuPriceWritten,
  onMenuOverridePriceWritten,
  onOptionGroupPriceWritten,
  onBrandOptionGroupPriceWritten,
  onMasterOptionGroupPriceWritten,
} from "./onMenuPriceWritten";
// payment_price_authority — 임시 감사 도구 (읽기 전용, 완료 후 정리 커밋으로 삭제: 배포 ⑩)
export { auditOrderPriceIntegrity } from "./auditOrderPriceIntegrity";

// store_category_optout Phase B — stores.availableMainCategories 파생 (CF 전담, 홈 카테고리 필터용 soft freshness).
export {
  onStoreOwnMenuWritten,
  onStoreMenuOverrideWritten,
  onStoreOptoutWritten,
  onBrandMasterMenuWritten,
  onMainCategoryActiveWritten,
} from "./onAvailableCategoriesWritten";
// 임시 자산 아님 — 트리거 누락 치유/신규 시드용 상시 정합 재조정 도구 (admin, dryRun 기본, migrationHistory 1건).
export { backfillAvailableMainCategories } from "./backfillAvailableMainCategories";
