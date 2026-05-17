import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/usecases/clone_master_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/count_stores_using_price_override_use_case.dart';
import 'package:qradar/domain/usecases/create_master_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/delete_master_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/update_master_menu_item_core_use_case.dart';
import 'package:qradar/domain/usecases/update_master_menu_item_operation_use_case.dart';
import 'package:qradar/domain/usecases/watch_master_menu_items_use_case.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── UseCase Provider ───────────────────────────────────────────────────────

final watchMasterMenuItemsUseCaseProvider =
    Provider<WatchMasterMenuItemsUseCase>((ref) {
  return WatchMasterMenuItemsUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

final createMasterMenuItemUseCaseProvider =
    Provider<CreateMasterMenuItemUseCase>((ref) {
  return CreateMasterMenuItemUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

/// 결정 J — 핵심 필드 수정 UseCase (status=pending 회귀).
final updateMasterMenuItemCoreUseCaseProvider =
    Provider<UpdateMasterMenuItemCoreUseCase>((ref) {
  return UpdateMasterMenuItemCoreUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

/// 결정 J — 운영 필드 수정 UseCase (status 보존, 즉시 반영).
final updateMasterMenuItemOperationUseCaseProvider =
    Provider<UpdateMasterMenuItemOperationUseCase>((ref) {
  return UpdateMasterMenuItemOperationUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

final deleteMasterMenuItemUseCaseProvider =
    Provider<DeleteMasterMenuItemUseCase>((ref) {
  return DeleteMasterMenuItemUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

final cloneMasterMenuItemUseCaseProvider =
    Provider<CloneMasterMenuItemUseCase>((ref) {
  return CloneMasterMenuItemUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

final countStoresUsingPriceOverrideUseCaseProvider =
    Provider<CountStoresUsingPriceOverrideUseCase>((ref) {
  return CountStoresUsingPriceOverrideUseCase(
      ref.watch(masterMenuItemRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// 현재 brand 사용자의 마스터 메뉴 전체 스트림.
final myMasterMenuItemsProvider =
    StreamProvider<List<MenuItemEntity>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final brandId = profile?.brandId;
  if (brandId == null || brandId.isEmpty) return Stream.value([]);
  return ref.read(watchMasterMenuItemsUseCaseProvider).call(brandId);
});

// ── 옵션 그룹 ─────────────────────────────────────────────────────────────

/// 옵션 DataSource. 마스터 메뉴 폼의 단일 사용처.
///
/// sub-phase 7 진입 시 brand_di_providers 또는 신규 brand_option_providers 로 승격 가능.
final _brandOptionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

/// 전역(master) 옵션 그룹 목록. 마스터 메뉴 폼의 OptionGroupSelector 에 사용.
///
/// owner 측 masterOptionGroupsProvider 와 동일 패턴.
/// brand 측에서는 master scope 만 사용 (S2 — 마스터 메뉴 옵션 그룹은 master 만 허용).
final brandMasterOptionGroupsProvider =
    FutureProvider<List<OptionGroupEntity>>((ref) async {
  final ds = ref.watch(_brandOptionRemoteDataSourceProvider);
  final models = await ds.fetchAllMaster();
  return models.map((m) => m.toEntity()).toList(growable: false);
});
