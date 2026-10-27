/// 최소 클라이언트 수준 게이트 판정 (payment_price_authority H-01). 순수.
///
/// **막는 건 "구버전임이 확인됐을 때" 뿐이다**: 서버 설정을 읽지 못했거나(null) 값이 없으면 막지 않는다. 이 게이트의 실패가
/// 정상 결제를 멈추면 안 된다 — 방향을 틀리면 게이트가 사고의 원인이 된다.
bool isClientUpdateRequired({required int clientLevel, int? minClientLevel}) =>
    minClientLevel != null && minClientLevel > clientLevel;
