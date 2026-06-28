import 'package:qradar/domain/repositories/push_notification_repository.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// 로그아웃 시 FCM 토큰을 정리한다.
///
/// Firestore fcmToken 을 null 로 설정하고, 디바이스 토큰도 무효화.
class ClearFcmTokenUseCase {
  final PushNotificationRepository _pushRepo;
  final UserRepository _userRepo;

  const ClearFcmTokenUseCase({
    required PushNotificationRepository pushRepo,
    required UserRepository userRepo,
  })  : _pushRepo = pushRepo,
        _userRepo = userRepo;

  Future<void> call(String uid) async {
    try {
      // Auth 끊기기 전에 Firestore 업데이트 (Rules: 본인 self-update 통과)
      await _userRepo.updateFcmToken(uid, null);
      await _pushRepo.deleteToken();
    } catch (_) {
      // silent — 로그아웃 자체를 막으면 안 됨
    }
  }
}
