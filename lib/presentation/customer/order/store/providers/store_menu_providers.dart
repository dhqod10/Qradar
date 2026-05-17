import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/sub_category_remote_data_source.dart';
import 'package:qradar/data/repositories/menu_category_repository_impl.dart';
import 'package:qradar/data/repositories/menu_item_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/menu_category_repository.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/usecases/watch_menu_items_by_store_use_case.dart';
import 'package:qradar/domain/usecases/watch_sub_categories_use_case.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

// ── DI ───────────────────────────────────────────────────────────────────

final _subCategoryRemoteDataSourceProvider =
    Provider<SubCategoryRemoteDataSource>((_) => SubCategoryRemoteDataSource());

final _menuItemRemoteDataSourceProvider = Provider<MenuItemRemoteDataSource>(
  (_) => MenuItemRemoteDataSource(),
);

final _masterMenuItemRemoteDataSourceProvider =
    Provider<MasterMenuItemRemoteDataSource>(
  (_) => MasterMenuItemRemoteDataSource(),
);

final _menuOverrideRemoteDataSourceProvider =
    Provider<MenuOverrideRemoteDataSource>(
  (_) => MenuOverrideRemoteDataSource(),
);

final _storeRemoteDataSourceProvider = Provider<StoreRemoteDataSource>(
  (_) => StoreRemoteDataSource(),
);

final menuCategoryRepositoryProvider = Provider<MenuCategoryRepository>(
  (ref) => MenuCategoryRepositoryImpl(
    ref.watch(_subCategoryRemoteDataSourceProvider),
  ),
);

/// customer 측 MenuItemRepository — case B (브랜드 매장) 흐름에서도
/// 마스터 메뉴 + override 머지가 동작하도록 master/override/store DataSource
/// 를 모두 주입한다. 미주입 시 watchByStore 가 폴백으로 case A 처럼 빠져
/// 가맹점 매장의 마스터 메뉴가 customer 측에 노출되지 않는 회귀 발생.
final menuItemRepositoryProvider = Provider<MenuItemRepository>(
  (ref) => MenuItemRepositoryImpl(
    ref.watch(_menuItemRemoteDataSourceProvider),
    masterMenuDataSource: ref.watch(_masterMenuItemRemoteDataSourceProvider),
    menuOverrideDataSource: ref.watch(_menuOverrideRemoteDataSourceProvider),
    storeRemoteDataSource: ref.watch(_storeRemoteDataSourceProvider),
  ),
);

final watchSubCategoriesUseCaseProvider = Provider<WatchSubCategoriesUseCase>(
  (ref) => WatchSubCategoriesUseCase(ref.watch(menuCategoryRepositoryProvider)),
);

final watchMenuItemsByStoreUseCaseProvider =
    Provider<WatchMenuItemsByStoreUseCase>(
  (ref) =>
      WatchMenuItemsByStoreUseCase(ref.watch(menuItemRepositoryProvider)),
);

// ── Streams ──────────────────────────────────────────────────────────────

/// 메인 카테고리 id 에 속한 글로벌 부 카테고리 stream (legacy).
final subCategoriesProvider =
    StreamProvider.family<List<SubCategoryEntity>, String>(
  (ref, mainCategoryId) =>
      ref.watch(watchSubCategoriesUseCaseProvider)(mainCategoryId),
);

/// 매장 컨텍스트에서 메인 카테고리에 속한 active 서브 카테고리 stream.
///
/// store doc 의 brandId 로 자동 분기:
///   - brandId 있음(가맹점) → `brands/{brandId}/subCategories/` fetch
///   - brandId 없음(개인 매장) → `stores/{storeId}/subCategories/` fetch
///
/// sub-phase 8 (2-tier — 글로벌 sub 없음) 결정 반영. legacy global 컬렉션은
/// 더 이상 customer 측 진입 매장에서 사용하지 않는다.
final subCategoriesForStoreProvider = StreamProvider.autoDispose
    .family<List<SubCategoryEntity>,
        ({String storeId, String mainCategoryId})>((ref, key) async* {
  final storeDs = ref.watch(_storeRemoteDataSourceProvider);
  final subDs = ref.watch(_subCategoryRemoteDataSourceProvider);
  final store = await storeDs.getById(key.storeId);
  final brandId = store?.brandId;

  final source = (brandId != null && brandId.isNotEmpty)
      ? subDs.streamByBrand(brandId: brandId, activeOnly: true)
      : subDs.streamByStore(storeId: key.storeId, activeOnly: true);

  yield* source.map((models) => models
      .where((m) =>
          m.mainCategory == key.mainCategoryId && m.active)
      .map((m) => m.toEntity())
      .toList(growable: false));
});

/// 매장의 메뉴 stream.
final storeMenuItemsProvider =
    StreamProvider.family<List<MenuItemEntity>, String>(
  (ref, storeId) =>
      ref.watch(watchMenuItemsByStoreUseCaseProvider)(storeId),
);

// ── UI State ─────────────────────────────────────────────────────────────

/// 현재 선택된 메인 카테고리 id. null = 미선택 (첫 카테고리 stream 도착 시 자동 선택).
final selectedMainCategoryProvider =
    NotifierProvider<SelectedMainCategoryNotifier, String?>(
  SelectedMainCategoryNotifier.new,
);

class SelectedMainCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    if (state == id) return;
    state = id;
    // 메인 카테고리 바뀌면 부 카테고리 선택도 초기화
    ref.read(selectedSubCategoryIdProvider.notifier).clear();
  }
}

/// 현재 선택된 부 카테고리 ID. null = 전체.
final selectedSubCategoryIdProvider =
    NotifierProvider<SelectedSubCategoryIdNotifier, String?>(
  SelectedSubCategoryIdNotifier.new,
);

class SelectedSubCategoryIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  void clear() => state = null;
}

// ── Derived ──────────────────────────────────────────────────────────────

/// 매장이 보유한 메인 카테고리 id 집합 (메뉴 0개인 카테고리 비활성 처리에 사용).
///
/// inactive 카테고리는 자동 제외 (spec 결정 4b — customer 측 탭에서 보이지 않음).
/// active 카테고리 stream 미도달 시에는 보수적으로 매장 전체 카테고리 노출.
final storeAvailableMainCategoriesProvider =
    Provider.family<Set<String>, String>((ref, storeId) {
  final asyncItems = ref.watch(storeMenuItemsProvider(storeId));
  final activeCategories = ref.watch(mainCategoriesActiveProvider).maybeWhen(
        data: (cats) => cats.map((c) => c.id).toSet(),
        orElse: () => null,
      );
  return asyncItems.maybeWhen(
    data: (items) => items
        .where((m) =>
            activeCategories == null ||
            activeCategories.contains(m.mainCategoryCode))
        .map((m) => m.mainCategoryCode)
        .toSet(),
    orElse: () => <String>{},
  );
});

/// 매장이 현재 메인 카테고리 안에서 보유한 subCategoryId 집합.
final storeAvailableSubCategoryIdsProvider =
    Provider.family<Set<String>, String>((ref, storeId) {
  final asyncItems = ref.watch(storeMenuItemsProvider(storeId));
  final main = ref.watch(selectedMainCategoryProvider);
  return asyncItems.maybeWhen(
    data: (items) => items
        .where((m) => m.mainCategoryCode == main && m.subCategoryId != null)
        .map((m) => m.subCategoryId!)
        .toSet(),
    orElse: () => <String>{},
  );
});

/// 현재 메인 + 부 카테고리 필터를 적용한 메뉴 리스트.
/// active 카테고리에 속한 메뉴만 포함 (inactive 카테고리 자동 제외).
///
/// active 카테고리 stream 미도달 시엔 빈 리스트 반환 (보수적). 이전엔 stream
/// 도달 전 모든 메뉴 통과시켰는데 inactive 카테고리 메뉴가 일시 노출되는
/// race 가 발견되어 변경. main_category_tabs 도 동일하게 미도달 시 빈 영역.
final filteredMenuItemsProvider =
    Provider.family<List<MenuItemEntity>, String>((ref, storeId) {
  final asyncItems = ref.watch(storeMenuItemsProvider(storeId));
  final main = ref.watch(selectedMainCategoryProvider);
  final subId = ref.watch(selectedSubCategoryIdProvider);
  // active 카테고리 id 집합. null = stream 미도달.
  final activeCategories = ref.watch(mainCategoriesActiveProvider).maybeWhen(
        data: (cats) => cats.map((c) => c.id).toSet(),
        orElse: () => null,
      );

  // active 카테고리 미도달 → 메뉴 노출 보류 (inactive 누수 방지).
  if (activeCategories == null) return const [];

  return asyncItems.maybeWhen(
    data: (items) {
      // selectedMain 이 매장에 없는 카테고리면 자동 무시 (예: 다른 매장에서
      // 선택했던 카테고리가 NotifierProvider 에 남아있는 경우 빈 화면 방지).
      final storeMains = items.map((m) => m.mainCategoryCode).toSet();
      final effectiveMain =
          (main != null && storeMains.contains(main)) ? main : null;
      return items.where((m) {
        // 비활성(visible=false) 메뉴 제외 — 개인 매장(case A) 흐름은 repository
        // 단에서 필터링이 없어 customer 측에서 직접 필터.
        if (!m.visible) return false;
        if (!activeCategories.contains(m.mainCategoryCode)) return false;
        if (effectiveMain != null && m.mainCategoryCode != effectiveMain) {
          return false;
        }
        if (subId != null && m.subCategoryId != subId) return false;
        return true;
      }).toList(growable: false);
    },
    orElse: () => const [],
  );
});
