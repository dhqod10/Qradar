import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/storage_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/repositories/store_repository_impl.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';
import 'package:qradar/domain/usecases/approve_store_use_case.dart';
import 'package:qradar/domain/usecases/delete_store_use_case.dart';
import 'package:qradar/domain/usecases/get_store_by_id_use_case.dart';
import 'package:qradar/domain/usecases/lookup_brand_by_key_use_case.dart';
import 'package:qradar/domain/usecases/reject_store_use_case.dart';
import 'package:qradar/domain/usecases/submit_store_for_approval_use_case.dart';
import 'package:qradar/domain/usecases/update_store_core_fields_use_case.dart';
import 'package:qradar/domain/usecases/update_store_operation_fields_use_case.dart';
import 'package:qradar/domain/usecases/watch_my_store_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_stores_for_admin_use_case.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── 인프라 Provider ────────────────────────────────────────────────────────

final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  return StorageDataSource();
});

final storeRemoteDataSourceProvider = Provider<StoreRemoteDataSource>((ref) {
  return StoreRemoteDataSource();
});

/// T4: ownership / role 검증 콜백을 주입한 StoreRepository.
///
/// role 은 `currentUserProfileProvider` (Firestore users doc) 에서 읽어야 함.
/// `authProvider` 만 보면 Firebase Auth 정보만 있어 admin role 을 못 읽어
/// `_assertAdmin()` 가드가 항상 실패함.
final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return StoreRepositoryImpl(
    ref.watch(storeRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
    currentRoleGetter: () => profile?.role.asString ?? authUser?.role.asString,
  );
});

// ── UseCase Provider ───────────────────────────────────────────────────────

final submitStoreForApprovalUseCaseProvider =
    Provider<SubmitStoreForApprovalUseCase>((ref) {
  return SubmitStoreForApprovalUseCase(ref.watch(storeRepositoryProvider));
});

/// 점주 매장 등록 폼에서 brandKey 검증 시 사용 (V4).
///
/// [LookupBrandByKeyUseCase] 는 [BrandRepository] 에 의존하므로
/// brand_di_providers 의 [brandRepositoryProvider] 를 경유.
final ownerLookupBrandByKeyUseCaseProvider =
    Provider<LookupBrandByKeyUseCase>((ref) {
  return LookupBrandByKeyUseCase(ref.watch(brandRepositoryProvider));
});

final updateStoreCoreFieldsUseCaseProvider =
    Provider<UpdateStoreCoreFieldsUseCase>((ref) {
  return UpdateStoreCoreFieldsUseCase(ref.watch(storeRepositoryProvider));
});

final updateStoreOperationFieldsUseCaseProvider =
    Provider<UpdateStoreOperationFieldsUseCase>((ref) {
  return UpdateStoreOperationFieldsUseCase(ref.watch(storeRepositoryProvider));
});

final deleteStoreUseCaseProvider = Provider<DeleteStoreUseCase>((ref) {
  return DeleteStoreUseCase(ref.watch(storeRepositoryProvider));
});

final watchMyStoreUseCaseProvider = Provider<WatchMyStoreUseCase>((ref) {
  return WatchMyStoreUseCase(ref.watch(storeRepositoryProvider));
});

final approveStoreUseCaseProvider = Provider<ApproveStoreUseCase>((ref) {
  return ApproveStoreUseCase(ref.watch(storeRepositoryProvider));
});

final rejectStoreUseCaseProvider = Provider<RejectStoreUseCase>((ref) {
  return RejectStoreUseCase(ref.watch(storeRepositoryProvider));
});

final watchPendingStoresForAdminUseCaseProvider =
    Provider<WatchPendingStoresForAdminUseCase>((ref) {
  return WatchPendingStoresForAdminUseCase(ref.watch(storeRepositoryProvider));
});

final getStoreByIdUseCaseProvider = Provider<GetStoreByIdUseCase>((ref) {
  return GetStoreByIdUseCase(ref.watch(storeRepositoryProvider));
});

// ── 내 매장 Stream ─────────────────────────────────────────────────────────

/// 현재 로그인된 점주의 매장 (MVP: 1 매장).
/// 인증 세션이 없거나 uid 가 비면 `null` 스트림.
final myStoreProvider = StreamProvider<StoreEntity?>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  if (authUser == null) return Stream.value(null);
  return ref.read(watchMyStoreUseCaseProvider).call(authUser.uid);
});

// ── Admin 매장 승인 큐 Stream ──────────────────────────────────────────────

/// admin 승인 큐: status=pending 매장 목록.
final pendingStoresProvider = StreamProvider<List<StoreEntity>>((ref) {
  return ref.read(watchPendingStoresForAdminUseCaseProvider).call();
});

// ── Deprecated ──────────────────────────────────────────────────────────────
// 기존 코드 호환성 유지용 — 신규 코드는 submitStoreForApprovalUseCaseProvider 사용

/// @deprecated submitStoreForApprovalUseCaseProvider 사용.
@Deprecated('submitStoreForApprovalUseCaseProvider 사용')
// ignore: deprecated_member_use_from_same_package
final registerStoreUseCaseProvider = submitStoreForApprovalUseCaseProvider;

/// @deprecated updateStoreCoreFieldsUseCaseProvider 사용.
@Deprecated('updateStoreCoreFieldsUseCaseProvider 사용')
// ignore: deprecated_member_use_from_same_package
final updateStoreUseCaseProvider = updateStoreCoreFieldsUseCaseProvider;
