/// 알림 설정 카테고리 (Phase 3c-3).
///
/// [asString] 은 Firestore `users/{uid}.notificationSettings` 의 map 키.
/// [defaultValue] 는 키 부재 시 fallback — Cloud Function
/// `functions/src/notificationSettings.ts` 의 `NOTIFICATION_SETTING_DEFAULTS` 와 일치해야 한다.
enum NotificationCategory {
  /// customer — 주문 접수 / 조리 시작 / 픽업 준비.
  orderProgress('orderProgress', true),

  /// customer — 픽업 완료 (옵트인).
  pickupComplete('pickupComplete', false),

  /// owner — 신규 주문.
  newOrder('newOrder', true),

  /// owner — 환불 요청.
  refundRequest('refundRequest', true);

  final String asString;
  final bool defaultValue;

  const NotificationCategory(this.asString, this.defaultValue);
}
