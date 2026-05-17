import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/data/repositories/menu_item_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/usecases/clone_owner_store_menu_use_case.dart';
import 'package:qradar/domain/usecases/create_owner_store_menu_use_case.dart';
import 'package:qradar/domain/usecases/delete_owner_store_menu_use_case.dart';
import 'package:qradar/domain/usecases/update_owner_store_menu_use_case.dart';
import 'package:qradar/domain/usecases/watch_owner_store_menus_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

// ── DataSource / Repository ────────────────────────────────────────────────

final _ownerMenuItemRemoteDataSourceProvider =
    Provider<MenuItemRemoteDataSource>((_) => MenuItemRemoteDataSource());

final _ownerOptionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

/// owner 전용 MenuItemRepository.
///
/// StoreRemoteDataSource 주입 → createStoreOnlyMenu 등의 brandId 분기 + ownership 검증.
final ownerMenuItemRepositoryProvider = Provider<MenuItemRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  return MenuItemRepositoryImpl(
    ref.watch(_ownerMenuItemRemoteDataSourceProvider),
    storeRemoteDataSource: ref.watch(storeRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
    currentRoleGetter: () => authUser?.role.asString,
  );
});

// ── UseCase Provider ───────────────────────────────────────────────────────

final watchOwnerStoreMenusUseCaseProvider =
    Provider<WatchOwnerStoreMenusUseCase>((ref) {
  return WatchOwnerStoreMenusUseCase(
      ref.watch(ownerMenuItemRepositoryProvider));
});

final createOwnerStoreMenuUseCaseProvider =
    Provider<CreateOwnerStoreMenuUseCase>((ref) {
  return CreateOwnerStoreMenuUseCase(
      ref.watch(ownerMenuItemRepositoryProvider));
});

final updateOwnerStoreMenuUseCaseProvider =
    Provider<UpdateOwnerStoreMenuUseCase>((ref) {
  return UpdateOwnerStoreMenuUseCase(
      ref.watch(ownerMenuItemRepositoryProvider));
});

final deleteOwnerStoreMenuUseCaseProvider =
    Provider<DeleteOwnerStoreMenuUseCase>((ref) {
  return DeleteOwnerStoreMenuUseCase(
      ref.watch(ownerMenuItemRepositoryProvider));
});

final cloneOwnerStoreMenuUseCaseProvider =
    Provider<CloneOwnerStoreMenuUseCase>((ref) {
  return CloneOwnerStoreMenuUseCase(ref.watch(ownerMenuItemRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// 특정 매장의 메뉴 목록 실시간 스트림 (storeId 기반 family).
///
/// case A (brandId: null) — watchByStore 의 개인 매장 분기.
final ownerStoreMenusProvider =
    StreamProvider.family<List<MenuItemEntity>, String>((ref, storeId) {
  return ref.read(watchOwnerStoreMenusUseCaseProvider).call(storeId);
});

// ── 옵션 그룹 ──────────────────────────────────────────────────────────────

/// 전역(master) 옵션 그룹 목록. OptionGroupSelector 의 masterGroups 에 사용.
final masterOptionGroupsProvider =
    FutureProvider<List<OptionGroupEntity>>((ref) async {
  final ds = ref.watch(_ownerOptionRemoteDataSourceProvider);
  final models = await ds.fetchAllMaster();
  return models.map((m) => m.toEntity()).toList(growable: false);
});

/// 매장 한정(store) 옵션 그룹 목록 (storeId family). OptionGroupSelector 의 storeGroups.
final storeOptionGroupsProvider =
    FutureProvider.family<List<OptionGroupEntity>, String>(
        (ref, storeId) async {
  final ds = ref.watch(_ownerOptionRemoteDataSourceProvider);
  final models = await ds.fetchAllStore(storeId);
  return models.map((m) => m.toEntity()).toList(growable: false);
});
