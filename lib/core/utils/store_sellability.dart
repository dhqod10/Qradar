/// "지금 이 매장이 주문을 받을 수 있는가" — 단일 판정 (payment_server_authority spec §6.3).
///
/// 서버 게이트(`functions/src/storeSellability.ts`)와 **같은 규칙**이며 교차 골든
/// (`test_fixtures/store_sellability_contract.json`)으로 고정된다. 판정식(Q1 ⓑ′):
///
///   `status == 'approved' || (status == 'pending' && approvedAt != null)`
///
/// - **입력은 가공 전 원시값이다.** `EntityApprovalStatus.fromString` 을 통과시키지 않는다 — 그 함수는 알 수 없는
///   값/부재를 `approved` 로 폴백(legacy 안전)하는 fail-open 이고, 돈 게이트는 그것을 복제할 수 없다 (spec §8.1).
/// - 이것은 **돈을 받을까** 의 질문이다. 고객 매장 목록의 노출 필터(`status == approved`)는 "보여줄까" 의 질문이라
///   이 함수로 통합하지 않는다 (spec §6.3 / §12 사실 1).
/// - 순수 Dart. 외부 SDK import 금지.
bool canSellNow({required String? rawStatus, required bool hasApprovedAt}) {
  if (rawStatus == 'approved') return true;
  if (rawStatus == 'pending' && hasApprovedAt) return true;
  return false;
}
