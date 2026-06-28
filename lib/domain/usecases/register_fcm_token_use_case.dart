import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/repositories/push_notification_repository.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// FCM 토큰을 발급받아 Firestore `users/{uid}.fcmToken` 에 저장한다.
///
/// 권한 없는 경우 skip (silent). 오류 발생 시 throw 하지 않고 log만.
class RegisterFcmTokenUseCase {
  final PushNotificationRepository _pushRepo;
  final UserRepository _userRepo;

  const RegisterFcmTokenUseCase({
    required PushNotificationRepository pushRepo,
    required UserRepository userRepo,
  })  : _pushRepo = pushRepo,
        _userRepo = userRepo;

  /// [uid] 에 해당하는 사용자의 FCM 토큰을 등록한다.
  /// 권한이 없으면 null 리턴 (토큰 미등록).
  Future<String?> call(String uid) async {
    try {
      final status = await _pushRepo.getPermissionStatus();
      if (status != NotificationPermissionStatus.authorized &&
          status != NotificationPermissionStatus.provisional) {
        return null;
      }
      final token = await _pushRepo.getToken();
      if (token == null) return null;
      await _userRepo.updateFcmToken(uid, token);
      return token;
    } catch (e) {
      // silent — 알림 토큰 등록 실패가 앱 정상 동작을 막으면 안 됨
      return null;
    }
  }
}
