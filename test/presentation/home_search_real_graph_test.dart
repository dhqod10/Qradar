import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
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
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/location_repository.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/usecases/get_current_location_use_case.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:qradar/presentation/customer/review/providers/store_review_providers.dart';
import 'package:qradar/presentation/customer/search/providers/search_providers.dart';
import 'package:qradar/presentation/customer/search/widgets/search_state_widgets.dart';

/// 검증 FAIL 3건 + 부수 수정의 회귀 테스트.
///
/// 원칙: provider 를 `overrideWith` 로 갈아끼우거나 `AsyncValue` 를 손으로 만들지 않는다.
/// I/O 경계(데이터 소스 / 리포지토리 / 스트림 원천)만 대체하고 **실제 provider 그래프**
/// (자동 재시도, whenData 변환, 전역 선택 상태, 실제 StoreMenuPage 화면)를 그대로 실행한다.
Stream<List<MainCategoryEntity>> _cats() => Stream.value(const [
  MainCategoryEntity(id: 'coffee', label: '커피'),
  MainCategoryEntity(id: 'tea', label: '티'),
]);

const _m1 = MenuItemEntity(
  id: 'm1',
  storeId: 's1',
  name: '아이스 아메리카노',
  mainCategoryCode: 'coffee',
  subCategoryId: 'sub-y',
  basePrice: 4000,
);
const _m2 = MenuItemEntity(
  id: 'm2',
  storeId: 's1',
  name: '라떼',
  mainCategoryCode: 'coffee',
  basePrice: 4500,
);
const _tea = MenuItemEntity(
  id: 't1',
  storeId: 's1',
  name: '녹차',
  mainCategoryCode: 'tea',
  basePrice: 4500,
);
const _dessert = MenuItemEntity(
  id: 'd1',
  storeId: 's1',
  name: '티라미수',
  mainCategoryCode: 'dessert', // 활성 카테고리 목록에 없음(비활성)
  basePrice: 6000,
);

StoreEntity _store() => StoreEntity(
  id: 's1',
  name: '강남점',
  imageUrl: '',
  location: const UserLocation(latitude: 0, longitude: 0),
  grade: StoreGrade.a,
  averageScore: 4,
  reviewCount: 1,
  menuCategories: const ['추천메뉴'],
  createdAt: DateTime(2026),
  distanceKm: 1,
);

void main() {
  group('StoreMenuPage 하이라이트 띠 — 실제 provider 그래프 (FAIL-1)', () {
    Future<ProviderContainer> pumpMenu(
      WidgetTester tester, {
      required List<MenuItemEntity> menus,
      String? initial,
      String? highlight,
      void Function(ProviderContainer c)? beforePump,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = _store();
      final c = ProviderContainer(
        overrides: [
          // I/O 원천만 대체 — 선택/필터/가용 카테고리 provider 는 전부 실제 코드.
          watchedStoreProvider.overrideWith((ref, id) => Stream.value(s)),
          storeMenuItemsProvider.overrideWith((ref, id) => Stream.value(menus)),
          mainCategoriesActiveProvider.overrideWith((ref) => _cats()),
          subCategoriesForStoreProvider.overrideWith(
            (ref, key) => Stream.value(const []),
          ),
          cartProvider.overrideWith((ref) => Stream.value(null)),
          favoriteStoreIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
        ],
      );
      addTearDown(c.dispose);
      beforePump?.call(c);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: StoreMenuPage(
              store: s,
              initialMainCategoryCode: initial,
              highlightMenuItemId: highlight,
            ),
          ),
        ),
      );
      return c;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    const notSold = '이 매장에서는 판매하지 않는 메뉴일 수 있어요';
    const found = '검색한 메뉴  아이스 아메리카노';

    testWidgets('경로 1: 진입 후 다른 카테고리 탭을 눌러도 띠가 바뀌지 않는다', (tester) async {
      await pumpMenu(
        tester,
        menus: [_m1, _m2, _tea],
        initial: 'coffee',
        highlight: 'm1',
      );
      await settle(tester);
      expect(find.text(found), findsOneWidget);
      await tester.tap(find.text('티'));
      await settle(tester);
      expect(find.text('녹차'), findsOneWidget); // 탭은 실제로 바뀌었다
      expect(find.text(found), findsOneWidget);
      expect(find.text(notSold), findsNothing);
    });

    testWidgets('경로 2: 이전 매장의 서브카테고리 선택이 남아 있어도 정리되고 띠가 정상', (tester) async {
      final c = await pumpMenu(
        tester,
        menus: [_m1, _m2, _tea],
        initial: 'coffee',
        highlight: 'm1',
        beforePump: (c) {
          // 이전 매장에서 남은 전역 선택: 같은 메인 + 다른 서브
          c.read(selectedMainCategoryProvider.notifier).select('coffee');
          c.read(selectedSubCategoryIdProvider.notifier).select('sub-x');
        },
      );
      await settle(tester);
      expect(c.read(selectedSubCategoryIdProvider), isNull);
      expect(find.text(found), findsOneWidget);
      expect(find.text(notSold), findsNothing);
      // 하이라이트 메뉴 카드가 실제로 목록에 보인다
      expect(find.text('아이스 아메리카노'), findsWidgets);
    });

    testWidgets('경로 3: 메뉴 스트림이 이미 살아 있고 전역에 이전 카테고리가 남아도 첫 프레임부터 오경보 없음', (
      tester,
    ) async {
      await pumpMenu(
        tester,
        menus: [_m1, _m2, _tea],
        initial: 'coffee',
        highlight: 'm1',
        beforePump: (c) {
          c.listen(storeMenuItemsProvider('s1'), (_, _) {});
          c.listen(mainCategoriesActiveProvider, (_, _) {});
          c.read(selectedMainCategoryProvider.notifier).select('tea');
        },
      );
      // pumpWidget 직후 = 첫 프레임. 아직 microtask 보정 전이어도 거짓 띠가 없어야 한다.
      expect(find.text(notSold), findsNothing);
      await settle(tester);
      expect(find.text(found), findsOneWidget);
      expect(find.text(notSold), findsNothing);
    });

    testWidgets('진짜 L2(머지 목록에 없음)는 여전히 정직하게 알린다', (tester) async {
      await pumpMenu(
        tester,
        menus: [_m2, _tea],
        initial: 'coffee',
        highlight: 'm1',
      );
      await settle(tester);
      expect(find.text(notSold), findsOneWidget);
    });
  });

  group('비활성 카테고리 (FAIL-2) — 인덱스 필터와 매장 화면 필터가 같은 판정', () {
    testWidgets('비활성 카테고리 메뉴로 진입해도 매장의 다른 메뉴는 사라지지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = _store();
      final c = ProviderContainer(
        overrides: [
          watchedStoreProvider.overrideWith((ref, id) => Stream.value(s)),
          storeMenuItemsProvider.overrideWith(
            (ref, id) => Stream.value([_m1, _m2, _dessert]),
          ),
          mainCategoriesActiveProvider.overrideWith((ref) => _cats()),
          subCategoriesForStoreProvider.overrideWith(
            (ref, key) => Stream.value(const []),
          ),
          cartProvider.overrideWith((ref) => Stream.value(null)),
          favoriteStoreIdsProvider.overrideWith(
            (ref) => Stream.value(const <String>{}),
          ),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: StoreMenuPage(
              store: s,
              initialMainCategoryCode: 'dessert',
              highlightMenuItemId: 'd1',
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.text('라떼'), findsOneWidget);
      expect(find.text('아이스 아메리카노'), findsOneWidget);
      expect(find.text('티라미수'), findsNothing);
      expect(find.text('이 매장에서는 판매하지 않는 메뉴일 수 있어요'), findsOneWidget);
    });

    test('검색 결과에 비활성 카테고리 메뉴가 없고, 결과의 모든 행은 매장 화면이 실제로 보여주는 메뉴다', () async {
      final storeDs = _FakeStoreDs([_model('s1', 0.5, brandId: null)]);
      final menus = _MenuRepo({
        's1': [
          _m1,
          _m2,
          _dessert,
          const MenuItemEntity(
            id: 'hid',
            storeId: 's1',
            name: '숨김 아메',
            mainCategoryCode: 'coffee',
            basePrice: 1,
            visible: false,
          ),
        ],
      });
      final c = _container(storeDs, menus);
      addTearDown(c.dispose);
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아');
      c.read(searchQueryProvider.notifier).set('아이');
      await c.read(menuSearchIndexProvider.future);
      await c.read(mainCategoriesActiveProvider.future);
      // 모든 질의 후보에 대해 "검색 결과 ⊆ 매장 화면 노출 목록" 을 확인한다.
      c.listen(storeMenuItemsProvider('s1'), (_, _) {});
      await c.read(storeMenuItemsProvider('s1').future);
      final screenIds = c
          .read(filteredMenuItemsProvider('s1'))
          .map((m) => m.id)
          .toSet();
      for (final q in ['아이', '라떼', '티라', '숨김', '메리']) {
        c.read(searchQueryProvider.notifier).set(q);
        final rows = c.read(searchViewModelProvider).menu.rows;
        for (final r in rows) {
          expect(
            screenIds.contains(r.menuItemId),
            isTrue,
            reason: '$q -> ${r.menuName}',
          );
        }
      }
      c.read(searchQueryProvider.notifier).set('티라');
      expect(c.read(searchViewModelProvider).menuTotal, 0);
    });
  });

  group('읽기 실패 자동 재시도 (FAIL-3) — 실제 Riverpod 재시도 타이머', () {
    testWidgets('스냅샷 읽기 실패: 38초가 아니라 2초 안에 에러로 확정된다 (일반 오류는 1회만 재시도)', (
      tester,
    ) async {
      final ds = _FakeStoreDs(const [])..error = StateError('net');
      final c = _container(ds, _MenuRepo({}));
      addTearDown(c.dispose);
      c.listen(storeSnapshotProvider, (_, _) {}, onError: (_, _) {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final v = c.read(storeSnapshotProvider);
      expect(v.hasError, isTrue);
      expect(v.isLoading, isFalse);
      expect(ds.calls, 2); // 최초 1 + 재시도 1
      await tester.pump(const Duration(seconds: 60));
      expect(ds.calls, 2); // 이후 더 시도하지 않는다
    });

    testWidgets('권한 거부는 재시도 없이 즉시 에러 + 검색 화면 상태는 s2', (tester) async {
      final ds = _FakeStoreDs(const [])
        ..error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      final c = _container(ds, _MenuRepo({}));
      addTearDown(c.dispose);
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아메');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ds.calls, 1);
      expect(c.read(searchViewModelProvider).view, SearchView.s2StoreError);
    });

    testWidgets('메뉴 인덱스 전체 실패: 2초 안에 s6(메뉴 에러, 매장 섹션 유지) — 각 출처 최대 2회', (
      tester,
    ) async {
      final ds = _FakeStoreDs([_model('s1', 0.5, name: '아메 하우스')]);
      final menus = _MenuRepo({
        's1': [_m1],
      })..failing = true;
      final c = _container(ds, menus);
      addTearDown(c.dispose);
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아메');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        c.read(searchViewModelProvider).view,
        SearchView.s6StoresMenuError,
      );
      expect(menus.calls, 2);
    });
  });

  group('범위 안내 — 실제 검색한 매장 수 (함께 고칠 것 ①②)', () {
    test('문구는 인덱스가 실제로 찾아본 매장 수를 말한다 (고정 30 아님)', () async {
      final ds = _FakeStoreDs([
        _model('s1', 0.5),
        _model('s2', 1.0),
        _model('s3', 1.5),
        _model('far', 30), // 10km 밖 — 후보 아님
      ]);
      final c = _container(
        ds,
        _MenuRepo({
          's1': [_m1],
          's2': [_m1],
          's3': [_m1],
        }),
      );
      addTearDown(c.dispose);
      c.listen(searchViewModelProvider, (_, _) {});
      c.read(searchQueryProvider.notifier).set('아이스');
      final idx = await c.read(menuSearchIndexProvider.future);
      expect(idx.searchedStoreCount, 3);
      expect(
        menuScopeSentence(idx.searchedStoreCount),
        '가까운 매장 3곳(10km 이내)의 메뉴에서 찾았어요',
      );
    });

    test('10km 안에 매장이 없으면 0곳을 찾았다고 하지 않고 정직하게 말한다', () async {
      final c = _container(_FakeStoreDs([_model('far', 30)]), _MenuRepo({}));
      addTearDown(c.dispose);
      final idx = await c.read(menuSearchIndexProvider.future);
      expect(idx.searchedStoreCount, 0);
      expect(menuScopeSentence(0), '10km 이내에 메뉴를 찾아볼 매장이 없어요');
      expect(menuScopeSentence(0), isNot(contains('찾았어요')));
    });
  });

  group('당겨서 새로고침 읽기 횟수 (⑤) — 실제 UserLocationNotifier', () {
    for (final granted in [true, false]) {
      test('권한 ${granted ? "허용" : "거부"}: 새로고침 1회 = fetchAll 정확히 1회 추가', () async {
        final ds = _FakeStoreDs([_model('s1', 0.5)]);
        final c = ProviderContainer(
          overrides: [
            storeRepositoryProvider.overrideWithValue(StoreRepositoryImpl(ds)),
            // userLocationProvider 는 실제 UserLocationNotifier (allowAndFetch / declineAndFallback 실제 코드).
            getCurrentLocationUseCaseProvider.overrideWithValue(
              GetCurrentLocationUseCase(_Loc()),
            ),
          ],
        );
        addTearDown(c.dispose);
        c.listen(storeSnapshotProvider, (_, _) {});
        await c.read(userLocationProvider.notifier).allowAndFetch();
        await c.read(storeSnapshotProvider.future);
        expect(ds.calls, 1);

        await refreshHomeStoreSnapshot(
          notifier: c.read(userLocationProvider.notifier),
          permissionGranted: granted,
          invalidateSnapshot: () => c.invalidate(storeSnapshotProvider),
        );
        await c.read(storeSnapshotProvider.future);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(ds.calls, 2, reason: '새로고침 한 번에 2회 읽으면 안 된다');
      });
    }
  });
}

// ── fixtures ───────────────────────────────────────────────────────────────

ProviderContainer _container(_FakeStoreDs ds, _MenuRepo menus) {
  return ProviderContainer(
    overrides: [
      storeRepositoryProvider.overrideWithValue(StoreRepositoryImpl(ds)),
      userLocationProvider.overrideWith(_FixedLocation.new),
      menuItemRepositoryProvider.overrideWithValue(menus),
      masterMenuItemRepositoryProvider.overrideWithValue(_NoMasterRepo()),
      mainCategoriesActiveProvider.overrideWith((ref) => _cats()),
      storeMenuItemsProvider.overrideWith(
        (ref, id) => Stream.value(menus.byStore[id] ?? const []),
      ),
    ],
  );
}

StoreModel _model(String id, double km, {String? name, String? brandId}) {
  return StoreModel(
    id: id,
    name: name ?? '매장 $id',
    imageUrl: '',
    // 위도 1도 ≈ 111km
    latitude: GradeThresholds.defaultLatitude + km / 111.0,
    longitude: GradeThresholds.defaultLongitude,
    averageScore: 4,
    reviewCount: 1,
    menuCategories: const [MenuCategories.defaultSelected],
    createdAt: DateTime(2026),
    brandId: brandId,
    status: EntityApprovalStatus.approved,
  );
}

class _FixedLocation extends UserLocationNotifier {
  @override
  Future<UserLocation> build() async => const UserLocation(
    latitude: GradeThresholds.defaultLatitude,
    longitude: GradeThresholds.defaultLongitude,
  );
}

class _Loc implements LocationRepository {
  @override
  Future<UserLocation> getCurrentLocation() async => const UserLocation(
    latitude: GradeThresholds.defaultLatitude,
    longitude: GradeThresholds.defaultLongitude,
  );

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeStoreDs implements StoreRemoteDataSource {
  _FakeStoreDs(this.models);
  final List<StoreModel> models;
  Object? error;
  int calls = 0;

  @override
  Future<List<StoreModel>> fetchAll({int limit = 100}) async {
    calls++;
    if (error != null) throw error!;
    return models;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _MenuRepo implements MenuItemRepository {
  _MenuRepo(this.byStore);
  final Map<String, List<MenuItemEntity>> byStore;
  bool failing = false;
  int calls = 0;

  @override
  Future<List<MenuItemEntity>> fetchStoreMenusOnce(String storeId) async {
    calls++;
    if (failing) throw StateError('boom');
    return byStore[storeId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _NoMasterRepo implements MasterMenuItemRepository {
  @override
  Future<List<MenuItemEntity>> fetchBrandMasterMenusOnce(
    String brandId,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}
