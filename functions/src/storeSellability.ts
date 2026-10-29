/**
 * 매장 판매 가능 판정 — Dart `lib/core/utils/store_sellability.dart canSellNow` 의 TS 포팅 (한 사실에 하나).
 * payment_server_authority spec §6.3. 교차 골든: `test_fixtures/store_sellability_contract.json`.
 *
 * 판정식 (Q1 ⓑ′): `status == 'approved' || (status == 'pending' && approvedAt != null)`
 *
 * - 입력은 **가공 전 원시값**이다. Dart 의 `EntityApprovalStatus.fromString` 이 알 수 없는 값/부재를 `approved` 로
 *   폴백하는 fail-open 인 것과 달리 돈 게이트는 **미지값·부재를 거절**한다 (spec §8.1).
 * - 영업 중 매장이 정보를 고치면 `status` 가 `pending` 으로 회귀하지만 `approvedAt` 이 남아 있으므로 막히지 않는다 (R2 불변식).
 * - Firebase 비의존 순수 함수.
 */
export type StoreGateReason = "STORE_NOT_SELLABLE" | "STORE_TEMPORARILY_CLOSED";

/**
 * 판매 불가 **사유** 를 돌려주는 단일 판정 (temporary_closed_gate spec D1). Dart `storeGateReason` 과 같은 규칙.
 * 우선순위: ① 승인 조건 실패 → STORE_NOT_SELLABLE (temporaryClosed 무시) ② 휴업 → STORE_TEMPORARILY_CLOSED ③ null.
 */
export function storeGateReason(args: {
  rawStatus: string | null;
  hasApprovedAt: boolean;
  temporaryClosed: boolean;
}): StoreGateReason | null {
  const approved =
    args.rawStatus === "approved" || (args.rawStatus === "pending" && args.hasApprovedAt);
  if (!approved) return "STORE_NOT_SELLABLE";
  if (args.temporaryClosed) return "STORE_TEMPORARILY_CLOSED";
  return null;
}

export function canSellNow(args: {
  rawStatus: string | null;
  hasApprovedAt: boolean;
  temporaryClosed: boolean;
}): boolean {
  return storeGateReason(args) === null;
}
