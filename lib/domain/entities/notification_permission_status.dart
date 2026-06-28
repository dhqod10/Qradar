/// FCM 알림 권한 상태 (외부 SDK 의존 차단 — domain 전용 enum).
enum NotificationPermissionStatus {
  /// 권한 허용됨.
  authorized,

  /// 권한 거부됨 (OS에서 거부 or iOS provisional 거부).
  denied,

  /// iOS provisional — 조용한 알림 허용 상태.
  provisional,

  /// 아직 요청하지 않은 상태.
  notDetermined,
}
