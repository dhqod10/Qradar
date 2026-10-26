import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/constants/menu_categories.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/store_model.dart';
import 'package:qradar/data/repositories/store_repository_impl.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/providers/recommended_stores_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';
import 'package:qradar/presentation/customer/search/providers/search_providers.dart';

/// 상태 판정(12상태 + 0/1글자)과 읽기 횟수 실측.
void main() {
  group('resolveSearchView — 한 함수가 모든 상태를 결정', () {
    final store = StoreEntity(
      id: 's',
      name: 'S',
      imageUrl: '',
      location: const UserLocation(latitude: 0, longitude: 0),
      grade: StoreGrade.a,
      averageScore: 0,
      reviewCount: 0,
      menuCategories: const [],
      createdAt: DateTime(2026),
    );
    AsyncValue<List<StoreEntity>> sData(int n) =>
        AsyncData(List.generate(n, (_) => store));
    const sLoad = AsyncLoading<List<StoreEntity>>();
    final sErr = AsyncError<List<StoreEntity>>(
      StateError('x'),
      StackTrace.empty,
    );
    AsyncValue<MenuSearchResults> m(int total, {int failed = 0}) => AsyncData(
      MenuSearchResults(
        rows: const [],
        total: total,
        failedSourceCount: failed,
      ),
    );
    const mLoad = AsyncLoading<MenuSearchResults>();
    final mErr = AsyncError<MenuSearchResults>(
      StateError('x'),
      StackTrace.empty,
    );

    test('질의 0글자 / 1글자', () {
      expect(resolveSearchView(sLoad, mLoad, ''), SearchView.initial);
      expect(resolveSearchView(sLoad, mLoad, '가'), SearchView.shortLoading);
      expect(resolveSearchView(sErr, mLoad, '가'), SearchView.shortError);
      expect(
        resolveSearchView(sData(2), m(0), '가'),
        SearchView.shortWithStores,
      );
      expect(resolveSearchView(sData(0), m(0), '가'), SearchView.shortNoStores);
    });

    test('2글자 이상 12상태 (design §3-c 번호)', () {
      const q = '가나';
      final table =
          <
            (
              AsyncValue<List<StoreEntity>>,
              AsyncValue<MenuSearchResults>,
              SearchView,
            )
          >[
            (sLoad, mLoad, SearchView.s1StoreLoading),
            (sErr, mLoad, SearchView.s2StoreError),
            (sData(2), mLoad, SearchView.s3StoresMenuLoading),
            (sData(2), m(3), SearchView.s4StoresMenuData),
            (sData(2), m(0), SearchView.s5StoresMenuEmpty),
            (sData(2), mErr, SearchView.s6StoresMenuError),
            (sData(2), m(3, failed: 1), SearchView.s7StoresMenuPartial),
            (sData(0), mLoad, SearchView.s8NoStoresMenuLoading),
            (sData(0), m(3), SearchView.s9NoStoresMenuData),
            (sData(0), m(0), SearchView.s10UnifiedEmpty),
            (sData(0), mErr, SearchView.s11NoStoresMenuError),
            (sData(0), m(0, failed: 2), SearchView.s12UnifiedEmptyPartial),
          ];
      for (final (s, mm, want) in table) {
        expect(resolveSearchView(s, mm, q), want, reason: '$want');
      }
    });

    test('통합 빈 상태는 메뉴가 확정일 때만 — 로딩/에러에서는 절대 나오지 않는다', () {
      const unified = {
        SearchView.s10UnifiedEmpty,
        SearchView.s12UnifiedEmptyPartial,
      };
      for (final menu in [mLoad, mErr]) {
        expect(
          unified.contains(resolveSearchView(sData(0), menu, '가나')),
          isFalse,
        );
      }
      for (final store in [sLoad, sErr]) {
        expect(unified.contains(resolveSearchView(store, m(0), '가나')), isFalse);
      }
    });

    test('재시도(refresh) 중에도 직전 값이 있으면 그 값의 상태를 유지한다', () async {
      // 실제 provider 의 invalidate 결과(isLoading && hasValue)를 그대로 판정 함수에 넣는다.
      final p = FutureProvider<MenuSearchResults>(
        (ref) async => m(3, failed: 1).requireValue,
      );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(p, (_, _) {});
      await c.read(p.future);
      c.invalidate(p);
      final refreshing = c.read(p);
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.hasValue, isTrue);
      expect(
        resolveSearchView(sData(2), refreshing, '가나'),
        SearchView.s7StoresMenuPartial,
      );
    });
  });

  group('읽기 횟수 실측 (카운팅 fake)', () {
    late _CountingStoreDs storeDs;
    late _CountingMenuRepo menuRepo;
    late _CountingMasterRepo masterRepo;
    late _CountingOverrideRepo ovRepo;
    late ProviderContainer c;

    setUp(() {
      storeDs = _CountingStoreDs(_fixtureStores());
      menuRepo = _CountingMenuRepo();
      masterRepo = _CountingMasterRepo();
      ovRepo = _CountingOverrideRepo();
      c = ProviderContainer(
        overrides: [
          storeRepositoryProvider.overrideWithValue(
            StoreRepositoryImpl(storeDs),
          ),
          userLocationProvider.overrideWith(_FixedLocation.new),
          menuItemRepositoryProvider.overrideWithValue(menuRepo),
          masterMenuItemRepositoryProvider.overrideWithValue(masterRepo),
          searchMenuOverrideRepositoryProvider.overrideWithValue(ovRepo),
          mainCategoriesActiveProvider.overrideWith(
            (ref) => Stream.value(const [
              MainCategoryEntity(id: 'coffee', label: '커피'),
            ]),
          ),
        ],
      );
      addTearDown(c.dispose);
    });

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> enterHome() async {
      c.listen(nearbyStoresProvider, (_, _) {});
      c.listen(filteredStoresProvider, (_, _) {});
      c.listen(recommendedStoresPreviewProvider, (_, _) {});
      c.listen(recommendedStoresFullProvider, (_, _) {});
      c.listen(recommendedTotalCountProvider, (_, _) {});
      await c.read(storeSnapshotProvider.future);
    }

    test(
      '홈 진입: fetchAll 1회 / 100 docs (이전 구조는 nearby 100 + filtered 100 = 200)',
      () async {
        await enterHome();
        // ignore: avoid_print
        print(
          '[실측] 홈 진입  fetchAll=${storeDs.fetchAllCalls} docs=${storeDs.docsReturned}',
        );
        expect(storeDs.fetchAllCalls, 1);
        expect(storeDs.docsReturned, 100);
      },
    );

    test('카테고리 토글 3회: 추가 읽기 0 (이전 구조는 토글당 100)', () async {
      await enterHome();
      final before = storeDs.docsReturned;
      final n = c.read(selectedCategoriesProvider.notifier);
      n.toggle('커피');
      n.toggle('티');
      n.toggle('커피');
      c.read(recommendedSortProvider.notifier).select(RecommendedSort.grade);
      await Future<void>.delayed(Duration.zero);
      // ignore: avoid_print
      print(
        '[실측] 토글 3회+정렬  추가 docs=${storeDs.docsReturned - before} fetchAll=${storeDs.fetchAllCalls}',
      );
      expect(storeDs.docsReturned - before, 0);
      expect(storeDs.fetchAllCalls, 1);
    });

    test(
      '홈 진입만으로는 메뉴 읽기 0 / 첫 검색: 1단계 32쿼리(D10) + 2단계 / 같은 세션 재검색 0 / 재진입 시 2단계만 재조회',
      () async {
        await enterHome();
        expect(menuRepo.calls + masterRepo.calls + ovRepo.calls, 0);

        c.listen(searchViewModelProvider, (_, _) {});
        c.read(searchQueryProvider.notifier).set('아메');
        await c.read(menuSearchIndexProvider.future);
        await settle();
        final stage1 = menuRepo.calls + masterRepo.calls;
        final stage1Docs = menuRepo.docs + masterRepo.docs;
        // 후보 30곳: 브랜드 2개(마스터 2) + 개인 15(매장 자체 15) + 브랜드 매장 15(점포 한정, D10) = 32
        expect(masterRepo.calls, 2);
        expect(menuRepo.calls, 30);
        expect(stage1, 32);
        // 2단계: 일치한 브랜드 매장 15곳 중 fan-out 상한 10곳
        expect(ovRepo.calls, 10);
        final vm = c.read(searchViewModelProvider);
        expect(vm.menu.fanOutTruncated, isTrue);
        // ignore: avoid_print
        print(
          '[실측 2차] 첫 메뉴 검색  1단계 get()=$stage1 (매장 자체 ${menuRepo.calls} + 브랜드 마스터 ${masterRepo.calls}) docs=$stage1Docs'
          ' / 2단계 override get()=${ovRepo.calls} docs=${ovRepo.docs} / 합계 ${stage1 + ovRepo.calls}',
        );

        // 같은 세션 안의 다른 질의 — 같은 매장이 다시 일치해도 0쿼리
        final before = menuRepo.calls + masterRepo.calls + ovRepo.calls;
        c.read(searchQueryProvider.notifier).set('브랜드메뉴1');
        await settle();
        c.read(searchQueryProvider.notifier).set('라떼'); // 개인 매장만 일치 -> 2단계 0
        await settle();
        expect(menuRepo.calls + masterRepo.calls + ovRepo.calls, before);

        // 검색 화면 재진입 = override 캐시 폐기 (SearchPage.dispose 가 하는 일) -> 1단계 0 / 2단계 다시
        c.invalidate(storeMenuOverridesProvider);
        c.read(searchQueryProvider.notifier).set('아메');
        await settle();
        expect(
          menuRepo.calls + masterRepo.calls,
          stage1,
          reason: '1단계 인덱스는 세션 캐시',
        );
        expect(ovRepo.calls, 20, reason: '재진입 시 2단계는 다시 조회');
      },
    );

    test('개인 매장(점포 한정 포함)만 일치하면 2단계는 0쿼리', () async {
      await enterHome();
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('라떼');
      await c.read(menuSearchIndexProvider.future);
      await settle();
      expect(ovRepo.calls, 0);
      expect(c.read(searchViewModelProvider).menuTotal, 15);
    });

    test('1글자 질의는 메뉴 인덱스를 구독하지 않는다 (읽기 0)', () async {
      await enterHome();
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아');
      await Future<void>.delayed(Duration.zero);
      expect(menuRepo.calls + masterRepo.calls + ovRepo.calls, 0);
    });

    test('후보는 10km 이내 가까운 30곳으로 제한된다', () async {
      await enterHome();
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아메');
      final idx = await c.read(menuSearchIndexProvider.future);
      final stores = c.read(storeSnapshotProvider).requireValue;
      final candidates = stores
          .where((s) => s.distanceKm! <= GradeThresholds.searchRadiusKm)
          .take(GradeThresholds.menuSearchStoreLimit)
          .map((s) => s.id)
          .toSet();
      expect(
        idx.hits.map((h) => h.storeId).toSet().difference(candidates),
        isEmpty,
      );
      expect(candidates.length, GradeThresholds.menuSearchStoreLimit);
    });

    test('홈 추천: 미리보기 5건 + 전체 건수는 같은 출처의 length', () async {
      await enterHome();
      final preview = c.read(recommendedStoresPreviewProvider).requireValue;
      final total = c.read(recommendedTotalCountProvider);
      final full = c.read(recommendedStoresFullProvider).requireValue;
      expect(preview.length, GradeThresholds.recommendedPreviewCount);
      expect(total, full.length);
      expect(total, 100);
    });

    test('등급순: averageScore 내림차순, 동점이면 거리', () async {
      await enterHome();
      c.read(recommendedSortProvider.notifier).select(RecommendedSort.grade);
      final full = c.read(recommendedStoresFullProvider).requireValue;
      for (var i = 1; i < full.length; i++) {
        final a = full[i - 1], b = full[i];
        expect(a.averageScore >= b.averageScore, isTrue);
        if (a.averageScore == b.averageScore) {
          expect(a.distanceKm! <= b.distanceKm!, isTrue);
        }
      }
    });

    test('메뉴 부분 실패: 결과는 유지되고 failedSourceCount 가 남는다 (provider 경로)', () async {
      await enterHome();
      masterRepo.failing.add('brand0');
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아메');
      await c.read(menuSearchIndexProvider.future);
      await c.read(mainCategoriesActiveProvider.future);
      await settle();
      final vm = c.read(searchViewModelProvider);
      expect(vm.menu.isPartial, isTrue);
      expect(vm.menuTotal, greaterThan(0));
      expect(vm.view, SearchView.s7StoresMenuPartial);
    });

    test('최근 검색어: 최대 10, 중복(정규화 기준)은 맨 앞, 빈 질의 무시', () {
      final n = c.read(recentSearchesProvider.notifier);
      for (var i = 0; i < 12; i++) {
        n.record('검색어$i');
      }
      n.record('검색어 5'); // 공백 차이 -> 같은 질의
      n.record('   ');
      final list = c.read(recentSearchesProvider);
      expect(list.length, GradeThresholds.recentSearchLimit);
      expect(list.first, '검색어 5');
      expect(list.where((e) => e.replaceAll(' ', '') == '검색어5').length, 1);
      n.remove('검색어 5');
      expect(c.read(recentSearchesProvider).contains('검색어 5'), isFalse);
      n.clear();
      expect(c.read(recentSearchesProvider), isEmpty);
    });
  });
}

// ── fixtures ───────────────────────────────────────────────────────────────

List<StoreModel> _fixtureStores() {
  // 100곳. i * 0.002도(~0.22km) 씩 북쪽으로 — i<=45 가 10km 이내.
  return List.generate(100, (i) {
    return StoreModel(
      id: 's$i',
      name: i == 7 ? '강남 아메 하우스' : '매장$i',
      imageUrl: '',
      latitude: GradeThresholds.defaultLatitude + i * 0.002,
      longitude: GradeThresholds.defaultLongitude,
      averageScore: (i * 37 % 50) / 10,
      reviewCount: 1,
      menuCategories: const [MenuCategories.defaultSelected, '커피'],
      createdAt: DateTime(2026),
      address: '서울 $i번지',
      brandId: i.isEven ? 'brand${i % 4}' : null,
      status: EntityApprovalStatus.approved,
    );
  });
}

class _FixedLocation extends UserLocationNotifier {
  @override
  Future<UserLocation> build() async => const UserLocation(
    latitude: GradeThresholds.defaultLatitude,
    longitude: GradeThresholds.defaultLongitude,
  );
}

class _CountingStoreDs implements StoreRemoteDataSource {
  _CountingStoreDs(this.models);
  final List<StoreModel> models;
  int fetchAllCalls = 0;
  int docsReturned = 0;

  @override
  Future<List<StoreModel>> fetchAll({int limit = 100}) async {
    fetchAllCalls++;
    final r = models.take(limit).toList();
    docsReturned += r.length;
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

MenuItemEntity _menu(String id, String name, {EntityApprovalStatus? status}) =>
    MenuItemEntity(
      id: id,
      storeId: '',
      name: name,
      mainCategoryCode: 'coffee',
      basePrice: 4000,
      status: status,
    );

class _CountingMenuRepo implements MenuItemRepository {
  int calls = 0;
  int docs = 0;
  @override
  Future<List<MenuItemEntity>> fetchStoreMenusOnce(String storeId) async {
    calls++;
    final r = [
      _menu('$storeId-1', '아메리카노'),
      _menu('$storeId-2', '라떼'),
      _menu('$storeId-3', '카푸치노'),
    ];
    docs += r.length;
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _CountingMasterRepo implements MasterMenuItemRepository {
  int calls = 0;
  int docs = 0;
  final Set<String> failing = {};
  @override
  Future<List<MenuItemEntity>> fetchBrandMasterMenusOnce(String brandId) async {
    calls++;
    if (failing.contains(brandId)) throw StateError('boom');
    final r = [
      for (var k = 0; k < 5; k++)
        _menu(
          '$brandId-m$k',
          k == 0 ? '아메리카노' : '브랜드메뉴$k',
          status: EntityApprovalStatus.approved,
        ),
    ];
    docs += r.length;
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _CountingOverrideRepo implements MenuOverrideRepository {
  int calls = 0;
  int docs = 0;
  final Set<String> failing = {};
  final Map<String, List<MenuOverrideEntity>> byStore = {};

  @override
  Future<List<MenuOverrideEntity>> fetchByStoreOnce(String storeId) async {
    calls++;
    if (failing.contains(storeId)) throw StateError('boom');
    final r = byStore[storeId] ?? const <MenuOverrideEntity>[];
    docs += r.length;
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}
