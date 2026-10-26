import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/utils/search_normalizer.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/usecases/search_menu_items_use_case.dart';
import 'package:qradar/domain/usecases/search_stores_use_case.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';

// ── 질의 ─────────────────────────────────────────────────────────────────

/// debounce 가 끝난 질의 원문(trim 한 입력 그대로). 입력창 위젯이 Timer 로 debounce 후 [set].
final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String raw) => state = raw.trim();
  void clear() => state = '';
}

/// 정규화된 질의 — 매장·메뉴 검색이 모두 이 값 하나로 비교한다.
final normalizedQueryProvider = Provider.autoDispose<String>(
  (ref) => SearchNormalizer.normalize(ref.watch(searchQueryProvider)),
);

// ── 매장 ─────────────────────────────────────────────────────────────────

/// 매장 검색 결과 (스냅샷 파생, 읽기 0). 메뉴 인덱스를 기다리지 않는다.
final searchStoreResultsProvider =
    Provider.autoDispose<AsyncValue<List<StoreEntity>>>((ref) {
      final q = ref.watch(normalizedQueryProvider);
      return ref
          .watch(storeSnapshotProvider)
          .whenData(
            (stores) =>
                SearchStoresUseCase.compute(stores: stores, normalizedQuery: q),
          );
    });

// ── 메뉴 ─────────────────────────────────────────────────────────────────

final searchMenuItemsUseCaseProvider = Provider<SearchMenuItemsUseCase>(
  (ref) => SearchMenuItemsUseCase(
    ref.watch(menuItemRepositoryProvider),
    ref.watch(masterMenuItemRepositoryProvider),
  ),
);

/// 메뉴 인덱스 — **세션 캐시** (autoDispose 아님 = 화면을 나가도 남는다).
///
/// 질의를 보지 않는다 (질의마다 재빌드되면 캐시 의미가 없다). UI 가 정규화 길이 >= 2 일 때만 구독한다.
/// 후보 매장 = 스냅샷에서 반경 [GradeThresholds.searchRadiusKm] 이내, 가까운 순 상위
/// [GradeThresholds.menuSearchStoreLimit] 곳. `get()` 1회씩 — 상시 listener 없음.
final menuSearchIndexProvider = FutureProvider<MenuSearchIndex>((ref) async {
  final stores = await ref.watch(storeSnapshotProvider.future);
  final candidates = stores
      .where(
        (s) =>
            s.distanceKm != null &&
            s.distanceKm! <= GradeThresholds.searchRadiusKm,
      )
      .take(GradeThresholds.menuSearchStoreLimit)
      .toList(growable: false);
  return ref
      .read(searchMenuItemsUseCaseProvider)
      .buildIndex(candidateStores: candidates);
}, retry: searchReadRetry);

/// 메뉴 검색 결과 — 인덱스 + 질의. [total] 은 상한 적용 전 일치 수, [rows] 는 최대 `menuSearchResultLimit`.
class MenuSearchResults {
  const MenuSearchResults({
    required this.rows,
    required this.total,
    this.failedSourceCount = 0,
    this.searchedStoreCount = 0,
  });

  static const MenuSearchResults empty = MenuSearchResults(rows: [], total: 0);

  final List<MenuSearchHitEntity> rows;
  final int total;
  final int failedSourceCount;

  /// 실제로 메뉴를 찾아본 후보 매장 수 — 범위 안내 문구의 근거 (고정 숫자를 말하지 않는다).
  final int searchedStoreCount;

  bool get isPartial => failedSourceCount > 0;
  bool get isTruncated => total > rows.length;
}

/// 정규화 길이가 [GradeThresholds.menuSearchMinQueryLength] 미만이면 인덱스를 **구독하지 않는다** (읽기 0).
final menuSearchResultsProvider =
    Provider.autoDispose<AsyncValue<MenuSearchResults>>((ref) {
      final q = ref.watch(normalizedQueryProvider);
      if (q.length < GradeThresholds.menuSearchMinQueryLength) {
        return const AsyncData(MenuSearchResults.empty);
      }
      final indexAsync = ref.watch(menuSearchIndexProvider);
      if (indexAsync.hasError && !indexAsync.hasValue) {
        return AsyncError(
          indexAsync.error!,
          indexAsync.stackTrace ?? StackTrace.empty,
        );
      }
      // F5 단일 판정: 매장 화면에 보이지 않을 메뉴(비활성 카테고리 등)는 결과에서 뺀다.
      // 활성 카테고리를 모르는 동안 행을 먼저 보여주면 나중에 사라질 수 있으므로 로딩으로 둔다.
      final activeAsync = ref.watch(mainCategoriesActiveProvider);
      if (!activeAsync.hasValue) {
        return activeAsync.hasError
            ? AsyncError(
                activeAsync.error!,
                activeAsync.stackTrace ?? StackTrace.empty,
              )
            : const AsyncLoading();
      }
      final activeIds = activeAsync.requireValue.map((c) => c.id).toSet();
      return indexAsync.whenData((index) {
        final shown = index.hits
            .where(
              (h) => isMenuShownOnStoreScreen(
                visible: true, // 인덱스가 visible 메뉴만 담는다 (buildIndex 필터)
                mainCategoryCode: h.mainCategoryCode,
                activeCategoryIds: activeIds,
              ),
            )
            .toList(growable: false);
        final all = SearchMenuItemsUseCase.filter(
          index: shown,
          normalizedQuery: q,
        );
        return MenuSearchResults(
          rows: all
              .take(GradeThresholds.menuSearchResultLimit)
              .toList(growable: false),
          total: all.length,
          failedSourceCount: index.failedSourceCount,
          searchedStoreCount: index.searchedStoreCount,
        );
      });
    });

// ── 최근 검색어 (세션 메모리) ─────────────────────────────────────────────

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  /// 기록 시점: 키보드 제출 · 결과 탭 (debounce 반영만으로는 기록하지 않는다).
  /// 정규화 후 빈 질의는 무시. 같은 질의(정규화 기준)는 중복 없이 맨 앞.
  void record(String raw) {
    final text = raw.trim();
    final key = SearchNormalizer.normalize(text);
    if (key.isEmpty) return;
    final next = <String>[
      text,
      ...state.where((e) => SearchNormalizer.normalize(e) != key),
    ];
    state = next
        .take(GradeThresholds.recentSearchLimit)
        .toList(growable: false);
  }

  void remove(String text) =>
      state = state.where((e) => e != text).toList(growable: false);

  void clear() => state = const [];
}

// ── 화면 상태 판정 (단일 함수) ────────────────────────────────────────────

/// 검색 본문의 모든 상태. 위젯은 이 enum 만 보고 렌더한다.
/// `s*` = 질의 2글자 이상의 12상태 (design §3-c 번호), `short*` = 1글자, `initial` = 0글자.
enum SearchView {
  initial,
  shortLoading,
  shortError,
  shortWithStores,
  shortNoStores,
  s1StoreLoading,
  s2StoreError,
  s3StoresMenuLoading,
  s4StoresMenuData,
  s5StoresMenuEmpty,
  s6StoresMenuError,
  s7StoresMenuPartial,
  s8NoStoresMenuLoading,
  s9NoStoresMenuData,
  s10UnifiedEmpty,
  s11NoStoresMenuError,
  s12UnifiedEmptyPartial,
}

/// 모든 상태를 결정하는 **유일한** 함수. 통합 빈 상태(s10/s12)는 메뉴가 확정(데이터 0 또는 부분 실패)일 때만 나온다.
/// `hasValue` 우선: 재시도(refresh) 중에도 직전 값이 있으면 그 값을 유지한다 (결과 행이 사라지지 않게).
SearchView resolveSearchView(
  AsyncValue<List<StoreEntity>> storeAsync,
  AsyncValue<MenuSearchResults> menuAsync,
  String normalizedQuery,
) {
  if (normalizedQuery.isEmpty) return SearchView.initial;

  final storeError = storeAsync.hasError && !storeAsync.hasValue;
  final storeLoading = !storeAsync.hasValue && !storeError;
  final stores = storeAsync.value ?? const <StoreEntity>[];

  if (normalizedQuery.length < GradeThresholds.menuSearchMinQueryLength) {
    if (storeError) return SearchView.shortError;
    if (storeLoading) return SearchView.shortLoading;
    return stores.isEmpty
        ? SearchView.shortNoStores
        : SearchView.shortWithStores;
  }

  if (storeError) return SearchView.s2StoreError;
  if (storeLoading) return SearchView.s1StoreLoading;

  final hasStores = stores.isNotEmpty;
  final menuError = menuAsync.hasError && !menuAsync.hasValue;
  final menuLoading = !menuAsync.hasValue && !menuError;
  final menu = menuAsync.value;

  if (menuLoading) {
    return hasStores
        ? SearchView.s3StoresMenuLoading
        : SearchView.s8NoStoresMenuLoading;
  }
  if (menuError) {
    return hasStores
        ? SearchView.s6StoresMenuError
        : SearchView.s11NoStoresMenuError;
  }
  final m = menu!;
  if (hasStores) {
    if (m.isPartial) return SearchView.s7StoresMenuPartial;
    return m.total > 0
        ? SearchView.s4StoresMenuData
        : SearchView.s5StoresMenuEmpty;
  }
  if (m.total > 0) return SearchView.s9NoStoresMenuData;
  return m.isPartial
      ? SearchView.s12UnifiedEmptyPartial
      : SearchView.s10UnifiedEmpty;
}

/// 화면이 쓰는 값 묶음 — 판정(enum) + 건수. 건수는 여기서만 `length` 로 만든다.
class SearchViewModel {
  const SearchViewModel({
    required this.view,
    required this.stores,
    required this.menu,
    required this.normalizedQuery,
    this.menuRefreshing = false,
  });

  final SearchView view;
  final List<StoreEntity> stores;
  final MenuSearchResults menu;
  final String normalizedQuery;

  /// 메뉴 인덱스를 다시 읽는 중 (직전 값은 유지된 채). 부분 실패 `다시 시도` 스피너용.
  final bool menuRefreshing;

  int get storeCount => stores.length;
  int get menuTotal => menu.total;
}

final searchViewModelProvider = Provider.autoDispose<SearchViewModel>((ref) {
  final q = ref.watch(normalizedQueryProvider);
  final storeAsync = ref.watch(searchStoreResultsProvider);
  final menuAsync = ref.watch(menuSearchResultsProvider);
  return SearchViewModel(
    view: resolveSearchView(storeAsync, menuAsync, q),
    stores: storeAsync.value ?? const [],
    menu: menuAsync.value ?? MenuSearchResults.empty,
    normalizedQuery: q,
    menuRefreshing: menuAsync.hasValue && menuAsync.isLoading,
  );
});
