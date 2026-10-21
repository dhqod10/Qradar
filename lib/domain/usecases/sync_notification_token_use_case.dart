import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/repositories/push_notification_repository.dart';
import 'package:qradar/domain/repositories/user_repository.dart';
import 'package:qradar/domain/usecases/register_fcm_token_use_case.dart';

/// OS 권한이 허용됐는데 `users/{uid}.fcmToken` 이 비어 있으면 토큰을 등록한다 (reconcile).
///
/// 권한이 없거나 토큰이 이미 있으면 no-op (멱등). 실패해도 throw 하지 않는다.
class SyncNotificationTokenUseCase {
  final PushNotificationRepository _pushRepo;
  final UserRepository _userRepo;
  final RegisterFcmTokenUseCase _register;

  SyncNotificationTokenUseCase({
    required PushNotificationRepository pushRepo,
    required UserRepository userRepo,
  })  : _pushRepo = pushRepo,
        _userRepo = userRepo,
        _register = RegisterFcmTokenUseCase(
          pushRepo: pushRepo,
          userRepo: userRepo,
        );

  /// 토큰을 새로 등록했으면 true.
  Future<bool> call(String uid) async {
    try {
      final status = await _pushRepo.getPermissionStatus();
      if (status != NotificationPermissionStatus.authorized &&
          status != NotificationPermissionStatus.provisional) {
        return false;
      }
      final user = await _userRepo.watchCurrent(uid).first;
      if (user == null) return false;
      final existing = user.fcmToken;
      if (existing != null && existing.isNotEmpty) return false;
      final token = await _register.call(uid);
      return token != null;
    } catch (_) {
      return false;
    }
  }
}
