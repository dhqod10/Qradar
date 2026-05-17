import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/repositories/menu_item_repository_impl.dart';
import 'package:qradar/data/repositories/store_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/repositories/store_repository.dart';
import 'package:qradar/domain/usecases/approve_store_only_menu_use_case.dart';
import 'package:qradar/domain/usecases/create_store_only_menu_use_case.dart';
import 'package:qradar/domain/usecases/delete_store_only_menu_use_case.dart';
import 'package:qradar/domain/usecases/reject_store_only_menu_use_case.dart';
import 'package:qradar/domain/usecases/update_store_only_menu_core_use_case.dart';
import 'package:qradar/domain/usecases/update_store_only_menu_operation_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_store_only_menus_use_case.dart';
import 'package:qradar/domain/usecases/watch_stores_by_brand_use_case.dart';
import 'package:qradar/presentation/admin/providers/menu_override_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── DataSource ─────────────────────────────────────────────────────────────

final brandMenuItemRemoteDataSourceProvider =
    Provider<MenuItemRemoteDataSource>((ref) {
  return MenuItemRemoteDataSource();
});

final brandOwnedStoreRemoteDataSourceProvider =
    Provider<StoreRemoteDataSource>((ref) {
  return StoreRemoteDataSource();
});

// ── Repository ─────────────────────────────────────────────────────────────

/// brand 전용 MenuItemRepository (점포 한정 메뉴 CRUD 포함).
///
/// `storeRemoteDataSource` 를 주입하여 `_fetchStoreBrandId` 가 정상 동작하도록 함.
/// 누락 시 sub-phase 3 의 brand 점포 한정 메뉴가 개인 매장 분기로 폴백되어 status=approved
/// 가 강제 박혀 admin 승인 게이트가 무력화되는 회귀 발생 (sub-phase 4 tester FAIL-1 해소).
final brandMenuItemRepositoryProvider = Provider<MenuItemRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  // role 은 Firestore users doc 의 진짜 값을 사용. authUser.role 은 SNS 로그인 시
  // 항상 default('customer') 로 박혀서 brand 권한 검증을 통과하지 못한다.
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return MenuItemRepositoryImpl(
    ref.watch(brandMenuItemRemoteDataSourceProvider),
    storeRemoteDataSource: ref.watch(brandOwnedStoreRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
    currentRoleGetter: () => profile?.role.asString ?? authUser?.role.asString,
  );
});

/// brand 전용 StoreRepository (currentBrandIdGetter 포함).
final brandOwnedStoreRepositoryProvider = Provider<StoreRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return StoreRepositoryImpl(
    ref.watch(brandOwnedStoreRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
    // role 은 Firestore users doc 우선. authUser.role 은 SNS 로그인 default 'customer'.
    currentRoleGetter: () => profile?.role.asString ?? authUser?.role.asString,
    currentBrandIdGetter: () => profile?.brandId,
  );
});

// ── UseCase ────────────────────────────────────────────────────────────────

final watchStoresByBrandUseCaseProvider =
    Provider<WatchStoresByBrandUseCase>((ref) {
  return WatchStoresByBrandUseCase(ref.watch(brandRepositoryProvider));
});

// V5: brand 가 매장 등록하는 흐름 폐기. 점주가 brandKey 입력으로 등록.
// `submitStoreByBrandUseCaseProvider` 제거됨. 매장 등록은 `submitStoreForApprovalUseCaseProvider` (owner 측) 만 사용.

final createStoreOnlyMenuUseCaseProvider =
    Provider<CreateStoreOnlyMenuUseCase>((ref) {
  return CreateStoreOnlyMenuUseCase(ref.watch(brandMenuItemRepositoryProvider));
});

final updateStoreOnlyMenuCoreUseCaseProvider =
    Provider<UpdateStoreOnlyMenuCoreUseCase>((ref) {
  return UpdateStoreOnlyMenuCoreUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

final updateStoreOnlyMenuOperationUseCaseProvider =
    Provider<UpdateStoreOnlyMenuOperationUseCase>((ref) {
  return UpdateStoreOnlyMenuOperationUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

final deleteStoreOnlyMenuUseCaseProvider =
    Provider<DeleteStoreOnlyMenuUseCase>((ref) {
  return DeleteStoreOnlyMenuUseCase(ref.watch(brandMenuItemRepositoryProvider));
});

final watchPendingStoreOnlyMenusUseCaseProvider =
    Provider<WatchPendingStoreOnlyMenusUseCase>((ref) {
  return WatchPendingStoreOnlyMenusUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

final approveStoreOnlyMenuUseCaseProvider =
    Provider<ApproveStoreOnlyMenuUseCase>((ref) {
  return ApproveStoreOnlyMenuUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

final rejectStoreOnlyMenuUseCaseProvider =
    Provider<RejectStoreOnlyMenuUseCase>((ref) {
  return RejectStoreOnlyMenuUseCase(ref.watch(brandMenuItemRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// brand 가 운영하는 매장 목록 실시간 스트림.
final brandStoresProvider = StreamProvider<List<StoreEntity>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final brandId = profile?.brandId;
  if (brandId == null || brandId.isEmpty) return Stream.value(const []);
  return ref.read(watchStoresByBrandUseCaseProvider).call(brandId);
});

/// 특정 매장의 가격 오버라이드 목록 실시간 스트림 (storeId 기반 family).
final menuOverridesByStoreProvider =
    StreamProvider.family<List<MenuOverrideEntity>, String>((ref, storeId) {
  return ref
      .read(watchMenuOverridesByStoreUseCaseProvider)
      .call(storeId);
});

/// 특정 매장의 점포 한정 메뉴(scope=store) 실시간 스트림 (storeId 기반 family).
final storeOnlyMenusProvider =
    StreamProvider.family<List<MenuItemEntity>, String>((ref, storeId) {
  return ref
      .read(brandMenuItemRepositoryProvider)
      .watchByStore(storeId);
});
