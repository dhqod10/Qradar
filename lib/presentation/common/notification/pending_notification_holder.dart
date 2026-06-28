import 'package:qradar/domain/entities/remote_notification_message.dart';

/// 앱 종료 상태에서 알림 탭 시 pending 메시지를 임시 보관한다.
///
/// `main.dart` 에서 `getInitialMessage()` 결과를 여기에 set 하고,
/// `RoleRouter` 진입 완료 후 consume 해 deep link 처리한다.
class PendingNotificationHolder {
  PendingNotificationHolder._();

  static RemoteNotificationMessage? _pending;

  static void set(RemoteNotificationMessage message) {
    _pending = message;
  }

  /// pending 메시지를 소비 후 제거. 없으면 null.
  static RemoteNotificationMessage? consume() {
    final msg = _pending;
    _pending = null;
    return msg;
  }
}
