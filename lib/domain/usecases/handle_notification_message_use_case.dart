import 'package:qradar/domain/entities/remote_notification_message.dart';

/// FCM 메시지 data payload 를 [RemoteNotificationMessage] 로 변환한다.
///
/// Presentation 레이어에서 직접 Map 파싱을 방지하고 domain 변환을 캡슐화.
class HandleNotificationMessageUseCase {
  const HandleNotificationMessageUseCase();

  RemoteNotificationMessage call(Map<String, dynamic> data) {
    return RemoteNotificationMessage.fromData(data);
  }
}
