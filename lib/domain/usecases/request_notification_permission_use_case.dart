import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/repositories/push_notification_repository.dart';

/// OS 알림 권한을 요청한다.
///
/// 결과 [NotificationPermissionStatus] 를 반환. 오류 시 [denied] 반환.
class RequestNotificationPermissionUseCase {
  final PushNotificationRepository _pushRepo;

  const RequestNotificationPermissionUseCase({
    required PushNotificationRepository pushRepo,
  }) : _pushRepo = pushRepo;

  Future<NotificationPermissionStatus> call() async {
    try {
      return await _pushRepo.requestPermission();
    } catch (_) {
      return NotificationPermissionStatus.denied;
    }
  }
}
