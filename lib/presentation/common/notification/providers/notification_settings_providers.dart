import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/usecases/sync_notification_token_use_case.dart';
import 'package:qradar/domain/usecases/update_notification_setting_use_case.dart';
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

final updateNotificationSettingUseCaseProvider =
    Provider<UpdateNotificationSettingUseCase>((ref) {
  return UpdateNotificationSettingUseCase(ref.watch(userRepositoryProvider));
});

final syncNotificationTokenUseCaseProvider =
    Provider<SyncNotificationTokenUseCase>((ref) {
  return SyncNotificationTokenUseCase(
    pushRepo: ref.watch(pushNotificationRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
  );
});
