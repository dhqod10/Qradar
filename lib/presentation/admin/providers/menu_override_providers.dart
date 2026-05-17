import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/repositories/menu_override_repository_impl.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';
import 'package:qradar/domain/usecases/approve_menu_override_use_case.dart';
import 'package:qradar/domain/usecases/delete_menu_override_use_case.dart';
import 'package:qradar/domain/usecases/reject_menu_override_use_case.dart';
import 'package:qradar/domain/usecases/upsert_menu_override_core_use_case.dart';
import 'package:qradar/domain/usecases/watch_menu_overrides_by_store_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_menu_overrides_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── DataSource ─────────────────────────────────────────────────────────────

final menuOverrideRemoteDataSourceProvider =
    Provider<MenuOverrideRemoteDataSource>((ref) {
  return MenuOverrideRemoteDataSource();
});

// ── Repository ─────────────────────────────────────────────────────────────

final menuOverrideRepositoryProvider = Provider<MenuOverrideRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return MenuOverrideRepositoryImpl(
    ref.watch(menuOverrideRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
    currentBrandIdGetter: () => profile?.brandId,
  );
});

// ── UseCase ────────────────────────────────────────────────────────────────

final watchMenuOverridesByStoreUseCaseProvider =
    Provider<WatchMenuOverridesByStoreUseCase>((ref) {
  return WatchMenuOverridesByStoreUseCase(
      ref.watch(menuOverrideRepositoryProvider));
});

final upsertMenuOverrideCoreUseCaseProvider =
    Provider<UpsertMenuOverrideCoreUseCase>((ref) {
  return UpsertMenuOverrideCoreUseCase(
      ref.watch(menuOverrideRepositoryProvider));
});

final deleteMenuOverrideUseCaseProvider =
    Provider<DeleteMenuOverrideUseCase>((ref) {
  return DeleteMenuOverrideUseCase(ref.watch(menuOverrideRepositoryProvider));
});

final watchPendingMenuOverridesUseCaseProvider =
    Provider<WatchPendingMenuOverridesUseCase>((ref) {
  return WatchPendingMenuOverridesUseCase(
      ref.watch(menuOverrideRepositoryProvider));
});

final approveMenuOverrideUseCaseProvider =
    Provider<ApproveMenuOverrideUseCase>((ref) {
  return ApproveMenuOverrideUseCase(ref.watch(menuOverrideRepositoryProvider));
});

final rejectMenuOverrideUseCaseProvider =
    Provider<RejectMenuOverrideUseCase>((ref) {
  return RejectMenuOverrideUseCase(ref.watch(menuOverrideRepositoryProvider));
});
