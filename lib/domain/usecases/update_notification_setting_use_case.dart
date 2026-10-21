import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

/// 알림 설정 토글 1개를 갱신한다. 실패 시 예외를 그대로 던진다 (UI 가 롤백 처리).
class UpdateNotificationSettingUseCase {
  final UserRepository _userRepo;

  const UpdateNotificationSettingUseCase(this._userRepo);

  Future<void> call({
    required String uid,
    required NotificationCategory category,
    required bool enabled,
  }) =>
      _userRepo.updateNotificationSetting(
        uid: uid,
        category: category,
        enabled: enabled,
      );
}
