import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/repositories/menu_item_repository_impl.dart';
import 'package:qradar/data/repositories/menu_override_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';
import 'package:qradar/domain/usecases/toggle_sold_out_use_case.dart';
import 'package:qradar/domain/usecases/update_disabled_options_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

// ── DataSource ─────────────────────────────────────────────────────────────

final _brandMenuItemRemoteDataSourceProvider =
    Provider<MenuItemRemoteDataSource>((_) => MenuItemRemoteDataSource());

final _brandMasterMenuItemRemoteDataSourceProvider =
    Provider<MasterMenuItemRemoteDataSource>(
        (_) => MasterMenuItemRemoteDataSource());

final _brandMenuOverrideRemoteDataSourceProvider =
    Provider<MenuOverrideRemoteDataSource>(
        (_) => MenuOverrideRemoteDataSource());

// ── Repository ──────────────────────────────────────────────────────────────

/// 브랜드 매장 점주용 MenuItemRepository (case B 머지 지원).
final ownerBrandStoreMenuItemRepositoryProvider =
    Provider<MenuItemRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  return MenuItemRepositoryImpl(
    ref.watch(_brandMenuItemRemoteDataSourceProvider),
    masterMenuDataSource:
        ref.watch(_brandMasterMenuItemRemoteDataSourceProvider),
    menuOverrideDataSource:
        ref.watch(_brandMenuOverrideRemoteDataSourceProvider),
    storeRemoteDataSource: ref.watch(storeRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
    currentRoleGetter: () => authUser?.role.asString,
  );
});

/// 브랜드 매장 점주용 MenuOverrideRepository.
final ownerBrandStoreMenuOverrideRepositoryProvider =
    Provider<MenuOverrideRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  return MenuOverrideRepositoryImpl(
    ref.watch(_brandMenuOverrideRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid,
  );
});

// ── UseCase ─────────────────────────────────────────────────────────────────

/// 개인 매장 / 브랜드 점포 한정 메뉴 품절 토글.
final toggleSoldOutForPersonalMenuUseCaseProvider =
    Provider<ToggleSoldOutForPersonalMenuUseCase>((ref) {
  return ToggleSoldOutForPersonalMenuUseCase(
    ref.watch(ownerBrandStoreMenuItemRepositoryProvider),
  );
});

/// 브랜드 매장 마스터 ref 품절 토글 (override upsert).
final toggleSoldOutForOverrideUseCaseProvider =
    Provider<ToggleSoldOutForOverrideUseCase>((ref) {
  return ToggleSoldOutForOverrideUseCase(
    ref.watch(ownerBrandStoreMenuOverrideRepositoryProvider),
  );
});

/// 개인 매장 / 브랜드 점포 한정 메뉴 옵션 비활성 업데이트.
final updateDisabledOptionsForPersonalMenuUseCaseProvider =
    Provider<UpdateDisabledOptionsForPersonalMenuUseCase>((ref) {
  return UpdateDisabledOptionsForPersonalMenuUseCase(
    ref.watch(ownerBrandStoreMenuItemRepositoryProvider),
  );
});

/// 브랜드 매장 마스터 ref 옵션 비활성 업데이트 (override upsert).
final updateDisabledOptionsForOverrideUseCaseProvider =
    Provider<UpdateDisabledOptionsForOverrideUseCase>((ref) {
  return UpdateDisabledOptionsForOverrideUseCase(
    ref.watch(ownerBrandStoreMenuOverrideRepositoryProvider),
  );
});

// ── Stream Provider ──────────────────────────────────────────────────────────

// ── key 타입 ─────────────────────────────────────────────────────────────────

class BrandMenuKey {
  final String storeId;
  final String brandId;

  const BrandMenuKey({required this.storeId, required this.brandId});

  @override
  bool operator ==(Object other) =>
      other is BrandMenuKey &&
      other.storeId == storeId &&
      other.brandId == brandId;

  @override
  int get hashCode => Object.hash(storeId, brandId);
}

// ── Stream Provider ──────────────────────────────────────────────────────────

/// 브랜드 매장 메뉴 목록 실시간 스트림 (storeId + brandId family).
///
/// case B 머지 결과 (마스터 + override + 점포 한정).
final ownerBrandStoreMenusProvider =
    StreamProvider.family<List<MenuItemEntity>, BrandMenuKey>(
  (ref, key) {
    final repo = ref.watch(ownerBrandStoreMenuItemRepositoryProvider);
    return repo.watchByStore(key.storeId, brandId: key.brandId);
  },
);
