import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// 알림 권한 다이얼로그를 노출할지 판정한다 (Phase 3c-4).
///
/// 판정 순서
/// 1. OS 권한이 이미 허용(authorized / provisional) → false (Firestore read 절약)
/// 2. `prompted` / `laterCount` 조회 → `canPromptAgain`
///
/// 주의: 1번은 반드시 **포함 판정**이어야 한다. `osStatus != notDetermined` 로 쓰면
/// Android 는 notDetermined 가 반환되지 않아 다이얼로그가 영구 차단된다.
///
/// 예외는 호출부로 전파한다.
class ShouldShowNotificationPermissionDialogUseCase {
  final UserRepository _userRepo;

  const ShouldShowNotificationPermissionDialogUseCase({
    required UserRepository userRepo,
  }) : _userRepo = userRepo;

  Future<bool> call({
    required String uid,
    required NotificationPermissionStatus osStatus,
  }) async {
    if (osStatus == NotificationPermissionStatus.authorized ||
        osStatus == NotificationPermissionStatus.provisional) {
      return false;
    }
    final state = await _userRepo.getNotificationPermissionPromptState(uid);
    return state.canPromptAgain;
  }
}
