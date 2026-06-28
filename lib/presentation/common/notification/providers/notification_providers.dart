import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/fcm_remote_data_source.dart';
import 'package:qradar/data/repositories/push_notification_repository_impl.dart';
import 'package:qradar/domain/repositories/push_notification_repository.dart';
import 'package:qradar/domain/usecases/clear_fcm_token_use_case.dart';
import 'package:qradar/domain/usecases/handle_notification_message_use_case.dart';
import 'package:qradar/domain/usecases/register_fcm_token_use_case.dart';
import 'package:qradar/domain/usecases/request_notification_permission_use_case.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── 인프라 Provider ────────────────────────────────────────────────────────

final fcmRemoteDataSourceProvider = Provider<FcmRemoteDataSource>((ref) {
  return FcmRemoteDataSource();
});

final pushNotificationRepositoryProvider =
    Provider<PushNotificationRepository>((ref) {
  return PushNotificationRepositoryImpl(
    ref.watch(fcmRemoteDataSourceProvider),
  );
});

// ── UseCase Provider ───────────────────────────────────────────────────────

final registerFcmTokenUseCaseProvider =
    Provider<RegisterFcmTokenUseCase>((ref) {
  return RegisterFcmTokenUseCase(
    pushRepo: ref.watch(pushNotificationRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
  );
});

final clearFcmTokenUseCaseProvider = Provider<ClearFcmTokenUseCase>((ref) {
  return ClearFcmTokenUseCase(
    pushRepo: ref.watch(pushNotificationRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
  );
});

final requestNotificationPermissionUseCaseProvider =
    Provider<RequestNotificationPermissionUseCase>((ref) {
  return RequestNotificationPermissionUseCase(
    pushRepo: ref.watch(pushNotificationRepositoryProvider),
  );
});

final handleNotificationMessageUseCaseProvider =
    Provider<HandleNotificationMessageUseCase>((ref) {
  return const HandleNotificationMessageUseCase();
});
