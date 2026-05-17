/// 주문 상태 enum.
///
/// Phase 3a 실제 사용: [paid], [cancelled], [refunded], [accepted] (점주 접수).
/// Phase 3c 확장: [making], [ready], [completed].
///
/// Firestore 직렬화: `.name` (lower camelCase String).
/// 역직렬화: [OrderStatus.fromCode].
enum OrderStatus {
  /// 결제 완료. 매장 접수 대기. customer 가 취소 가능.
  paid,

  /// 매장이 접수. customer 취소 불가. 환불 흐름만 가능.
  accepted,

  /// 제조 중 (Phase 3c).
  making,

  /// 픽업 대기 (Phase 3c).
  ready,

  /// 픽업 완료. 정상 종료 (Phase 3c).
  completed,

  /// customer 가 결제 후 매장 접수 전에 직접 취소 → PG 취소 API 호출.
  /// 또는 점주가 주문 거절 시에도 동일 status.
  cancelled,

  /// 매장 접수 후 customer 요청 → 점주 동의 → PG 환불 API 호출.
  refunded;

  /// Firestore String 코드에서 복원. 알 수 없는 값은 [paid] 반환.
  static OrderStatus fromCode(String? code) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == code,
      orElse: () => OrderStatus.paid,
    );
  }
}
