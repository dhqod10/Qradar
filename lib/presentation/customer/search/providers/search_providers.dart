import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/utils/search_normalizer.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/repositories/menu_override_repository_impl.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';
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

/// 메뉴 검색 2단계(override 검증)가 쓰는 override 저장소. customer 읽기 경로 — auth 의존 없음.
final searchMenuOverrideRepositoryProvider = Provider<MenuOverrideRepository>(
  (ref) => MenuOverrideRepositoryImpl(MenuOverrideRemoteDataSource()),
);

/// 매장 1곳의 `menuOverrides` 전체 (2단계). **검색 화면 수명** 캐시 (D12):
/// 화면을 열어 둔 동안은 같은 매장이 다시 일치해도 0쿼리, [SearchPage] 가 닫힐 때
/// `invalidate(storeMenuOverridesProvider)` 로 비워 재진입 시 다시 읽는다 (가격·품절의 신선도를 방문 단위로 보장).
/// 쿼리: `_overrideCol(storeId).get()` — where / collectionGroup 없음 (인덱스 0건).
final storeMenuOverridesProvider =
    FutureProvider.family<List<MenuOverrideEntity>, String>(
      (ref, storeId) => ref
          .read(searchMenuOverrideRepositoryProvider)
          .fetchByStoreOnce(storeId),
      retry: searchReadRetry,
    );

/// 2단계 검증이 전멸했을 때 에러에 실리는 매장 id (재시도가 이 매장만 다시 읽는다).
class MenuVerificationException implements Exception {
  const MenuVerificationException(this.storeIds);
  final List<String> storeIds;
  @override
  String toString() => 'MenuVerificationException($storeIds)';
}

/// 메뉴 검색 결과 — 인덱스 + 질의 + 2단계 검증.
///
/// [total] 은 **검증을 통과한** 일치 수 (R5), [rows] 는 최대 `menuSearchResultLimit`.
class MenuSearchResults {
  const MenuSearchResults({
    required this.rows,
    required this.total,
    this.failedSourceCount = 0,
    this.searchedStoreCount = 0,
    this.fanOutTruncated = false,
    this.refreshing = false,
    this.failedStoreIds = const [],
    this.indexFailedCount = 0,
  });

  static const MenuSearchResults empty = MenuSearchResults(rows: [], total: 0);

  final List<MenuSearchHitEntity> rows;
  final int total;
  final int failedSourceCount;

  /// 실제로 메뉴를 찾아본 후보 매장 수 — 범위 안내 문구의 근거 (고정 숫자를 말하지 않는다).
  final int searchedStoreCount;

  /// 2단계 검증에 실패한 매장 id (부분 실패 `다시 시도` 가 이 매장만 다시 읽는다).
  final List<String> failedStoreIds;

  /// 1단계 인덱스에서 실패한 출처 수.
  final int indexFailedCount;

  /// 2단계 fan-out 상한(R4) 밖 브랜드 매장의 행이 버려졌다.
  final bool fanOutTruncated;

  bool get isPartial => failedSourceCount > 0;
  bool get isTruncated => total > rows.length || fanOutTruncated;

  /// override 재시도 중 (직전 검증 결과는 유지한 채).
  final bool refreshing;

  MenuSearchResults withRefreshing() => MenuSearchResults(
    rows: rows,
    total: total,
    failedSourceCount: failedSourceCount,
    searchedStoreCount: searchedStoreCount,
    fanOutTruncated: fanOutTruncated,
    refreshing: true,
    failedStoreIds: failedStoreIds,
    indexFailedCount: indexFailedCount,
  );
}

/// 정규화 길이가 [GradeThresholds.menuSearchMinQueryLength] 미만이면 인덱스를 **구독하지 않는다** (읽기 0).
///
/// 1단계 인덱스 -> 활성 카테고리 필터 -> 질의 일치 -> **2단계 override 검증** 순서.
/// **R1**: 2단계가 끝나기 전에는 1단계 행을 그리지 않는다 (나중에 사라지거나 가격이 바뀌는 깜빡임 금지) —
/// 전부 도달할 때까지 `AsyncLoading`.
final menuSearchResultsProvider =
    Provider.autoDispose<AsyncValue<MenuSearchResults>>((ref) {
      final q = ref.watch(normalizedQueryProvider);
      if (q.length < GradeThresholds.menuSearchMinQueryLength) {
        return const AsyncData(MenuSearchResults.empty);
      }
      final indexAsync = ref.watch(menuSearchIndexProvider);
      // 자동 재시도 중(isLoading)에는 에러로 확정하지 않는다 — 에러가 잠깐 비쳤다 사라지는 깜빡임 방지.
      // 최종 실패(재시도까지 끝난 에러)는 직전 값이 남아 있어도 **에러로 본다**: 가격이 걸린 화면이라
      // 낡았을 수 있는 값을 설명 없이 보이지 않는다 (Riverpod 3 은 에러 후에도 이전 값을 유지한다).
      if (indexAsync.hasError && !indexAsync.isLoading) {
        return AsyncError(
          indexAsync.error!,
          indexAsync.stackTrace ?? StackTrace.empty,
        );
      }
      // F5 단일 판정: 매장 화면에 보이지 않을 메뉴(비활성 카테고리 등)는 결과에서 뺀다.
      // 활성 카테고리를 모르는 동안 행을 먼저 보여주면 나중에 사라질 수 있으므로 로딩으로 둔다.
      final activeAsync = ref.watch(mainCategoriesActiveProvider);
      if (!activeAsync.hasValue) {
        return activeAsync.hasError && !activeAsync.isLoading
            ? AsyncError(
                activeAsync.error!,
                activeAsync.stackTrace ?? StackTrace.empty,
              )
            : const AsyncLoading();
      }
      // 실패 후 재시도 중에는 낡은 값을 보이지 않고 로딩으로 둔다.
      if (!indexAsync.hasValue || indexAsync.hasError) {
        return const AsyncLoading();
      }
      final index = indexAsync.requireValue;
      final activeIds = activeAsync.requireValue.map((c) => c.id).toSet();
      // 매장별 점주 제외 카테고리 (스냅샷 파생, 추가 읽기 0). 스냅샷에 없는 매장은 제외 없음으로 본다.
      final excludedByStore = <String, Set<String>>{
        for (final s in ref.watch(storeSnapshotProvider).asData?.value ??
            const <StoreEntity>[])
          if (s.excludedMainCategories.isNotEmpty)
            s.id: s.excludedMainCategories.toSet(),
      };

      final shown = index.hits
          .where(
            (h) => isMenuShownOnStoreScreen(
              visible: true, // 인덱스가 visible 메뉴만 담는다 (buildIndex 필터)
              mainCategoryCode: h.mainCategoryCode,
              activeCategoryIds: activeIds,
              excludedCategoryIds: excludedByStore[h.storeId] ?? const {},
            ),
          )
          .toList(growable: false);
      final matched = SearchMenuItemsUseCase.filter(
        index: shown,
        normalizedQuery: q,
      );

      // ── 2단계: 일치한 브랜드 매장(거리순 상한)의 override 를 읽는다 ──
      final plan = SearchMenuItemsUseCase.planVerification(
        matched,
        storeLimit: GradeThresholds.menuSearchVerifyStoreLimit,
      );
      final overrides = <String, List<MenuOverrideEntity>>{};
      final failedStores = <String>{};
      var pending = false;
      var refreshing = false;
      for (final storeId in plan.storeIds) {
        final a = ref.watch(storeMenuOverridesProvider(storeId));
        if (a.isLoading) {
          if (a.hasValue && !a.hasError) {
            // 정상 새로고침 중: 직전 검증 결과 유지 (이미 검증된 행을 지우지 않는다)
            overrides[storeId] = a.requireValue;
            refreshing = true;
          } else {
            pending = true; // 첫 로딩 또는 실패 후 재시도 중 — 아직 모른다 (낡은 값을 보이지 않는다)
          }
        } else if (a.hasError) {
          // 최종 실패. 직전 값이 남아 있어도 쓰지 않는다: 가격이 걸려 있어 낡았을 수 있는 값을 설명 없이
          // 보이지 않는다 (R6 과 같은 규칙 — 검증 못 한 행은 그리지 않고 부분 실패로 알린다).
          failedStores.add(storeId);
        } else {
          overrides[storeId] = a.requireValue;
        }
      }
      if (pending) return const AsyncLoading(); // R1: 검증 전 행은 그리지 않는다

      final verified = SearchMenuItemsUseCase.applyVerification(
        matched: matched,
        plan: plan,
        overridesByStore: overrides,
        failedStores: failedStores,
      );

      // 일치 행이 전부 브랜드 매장이고 검증이 전멸이면 메뉴 전체 에러 (s6 / s11).
      final onlyBrandRows =
          matched.isNotEmpty &&
          matched.every((h) => h.source == MenuHitSource.brandMaster);
      if (onlyBrandRows &&
          plan.storeIds.isNotEmpty &&
          failedStores.length == plan.storeIds.length &&
          verified.hits.isEmpty) {
        return AsyncError(
          MenuVerificationException(failedStores.toList(growable: false)),
          StackTrace.empty,
        );
      }

      final results = MenuSearchResults(
        rows: verified.hits
            .take(GradeThresholds.menuSearchResultLimit)
            .toList(growable: false),
        total: verified.hits.length,
        failedSourceCount: index.failedSourceCount + verified.failedStoreCount,
        searchedStoreCount: index.searchedStoreCount,
        fanOutTruncated: verified.truncated,
        failedStoreIds: failedStores.toList(growable: false),
        indexFailedCount: index.failedSourceCount,
      );
      // 인덱스 새로고침 중이면 whenData 가 isLoading 플래그를 실어 준다 (부분 실패 재시도 스피너용).
      final carried = indexAsync.whenData((_) => results);
      if (refreshing && !carried.isLoading) {
        // override 재시도 중: 플래그를 실을 수 없으므로 결과에 표시한다.
        return AsyncData(results.withRefreshing());
      }
      return carried;
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

  /// 13: 매장 일치 O + 메뉴 검증 통과 0 + **fan-out 상한 밖 매장을 읽지 못했다** — "없다" 고 단정하지 않는다.
  s13StoresMenuTruncatedEmpty,

  /// 13': 매장 일치 X + 같은 조건 (통합 빈 상태 아님).
  s13UnifiedTruncatedEmpty,
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
  // 새 축 `fanOutTruncated` x 빈 결과: 상한 때문에 못 본 매장이 있으면 "없다" 는 확정이 아니다.
  if (m.total == 0 && m.fanOutTruncated) {
    return hasStores
        ? SearchView.s13StoresMenuTruncatedEmpty
        : SearchView.s13UnifiedTruncatedEmpty;
  }
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
    menuRefreshing:
        (menuAsync.hasValue && menuAsync.isLoading) ||
        (menuAsync.value?.refreshing ?? false),
  );
});
