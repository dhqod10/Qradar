import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/user_remote_data_source.dart';
import 'package:qradar/data/repositories/user_repository_impl.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/user_repository.dart';
import 'package:qradar/domain/usecases/downgrade_to_customer_use_case.dart';
import 'package:qradar/domain/usecases/get_or_create_user_profile_use_case.dart';
import 'package:qradar/domain/usecases/upgrade_to_brand_use_case.dart';
import 'package:qradar/domain/usecases/upgrade_to_owner_use_case.dart';
import 'package:qradar/domain/usecases/watch_user_profile_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

// ── 인프라 Provider ────────────────────────────────────────────────────────

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(userRemoteDataSourceProvider));
});

// ── UseCase Provider ───────────────────────────────────────────────────────

final getOrCreateUserProfileUseCaseProvider =
    Provider<GetOrCreateUserProfileUseCase>((ref) {
  return GetOrCreateUserProfileUseCase(ref.watch(userRepositoryProvider));
});

final watchUserProfileUseCaseProvider =
    Provider<WatchUserProfileUseCase>((ref) {
  return WatchUserProfileUseCase(ref.watch(userRepositoryProvider));
});

final upgradeToOwnerUseCaseProvider = Provider<UpgradeToOwnerUseCase>((ref) {
  return UpgradeToOwnerUseCase(ref.watch(userRepositoryProvider));
});

final upgradeToBrandUseCaseProvider = Provider<UpgradeToBrandUseCase>((ref) {
  return UpgradeToBrandUseCase(ref.watch(userRepositoryProvider));
});

final downgradeToCustomerUseCaseProvider =
    Provider<DowngradeToCustomerUseCase>((ref) {
  return DowngradeToCustomerUseCase(ref.watch(userRepositoryProvider));
});

// ── 현재 사용자 프로필 (Firestore users/{uid}) ─────────────────────────────

/// 로그인된 사용자의 Firestore 프로필.
///
/// - 인증 세션이 없으면 `null` emit.
/// - 최초 조회 시 `users/{uid}` 문서가 없으면 `getOrCreateUserProfile` 로 생성 후 스트림 재연결.
final currentUserProfileProvider =
    StreamProvider<UserEntity?>((ref) async* {
  final authState = ref.watch(authProvider);
  final authUser = authState.asData?.value;
  if (authUser == null) {
    yield null;
    return;
  }

  // users/{uid} 가 없으면 초기화
  await ref
      .read(getOrCreateUserProfileUseCaseProvider)
      .call(authUser);

  yield* ref.read(watchUserProfileUseCaseProvider).call(authUser.uid);
});
