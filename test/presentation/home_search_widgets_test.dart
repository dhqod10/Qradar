import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/recommended_stores_page.dart';
import 'package:qradar/presentation/customer/home/widgets/recommended_stores_section.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:qradar/presentation/customer/review/providers/store_review_providers.dart';
import 'package:qradar/presentation/customer/search/providers/search_providers.dart';
import 'package:qradar/presentation/customer/search/search_page.dart';

StoreEntity store(
  String id,
  String name, {
  double km = 1,
  String address = '',
  String? brandId,
}) => StoreEntity(
  id: id,
  name: name,
  imageUrl: '',
  location: const UserLocation(latitude: 0, longitude: 0),
  grade: StoreGrade.a,
  averageScore: 4,
  reviewCount: 1,
  menuCategories: const ['추천메뉴'],
  createdAt: DateTime(2026),
  address: address,
  distanceKm: km,
  brandId: brandId,
);

const hit = MenuSearchHitEntity(
  menuItemId: 'm1',
  menuName: '아이스 아메리카노',
  mainCategoryCode: 'coffee',
  storeId: 's1',
  storeName: '강남점',
  distanceKm: 1.2,
  source: MenuHitSource.brandMaster,
);

Stream<List<MainCategoryEntity>> _cats() => Stream.value(const [
  MainCategoryEntity(id: 'coffee', label: '커피'),
  MainCategoryEntity(id: 'tea', label: '티'),
]);

void main() {
  Future<void> pumpSearch(
    WidgetTester tester, {
    required List<StoreEntity> stores,
    required Future<MenuSearchIndex> Function() index,
    required String query,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeSnapshotProvider.overrideWith((ref) async => stores),
          menuSearchIndexProvider.overrideWith((ref) => index()),
          mainCategoriesActiveProvider.overrideWith((ref) => _cats()),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 300)); // debounce 250ms
    await tester.pump();
  }

  testWidgets('중간 상태: 매장 완성 + 메뉴 로딩 — 메뉴 건수 없음, 통합 빈 상태 없음, 이후 도착해도 매장 위치 불변', (
    tester,
  ) async {
    final done = Completer<MenuSearchIndex>();
    await pumpSearch(
      tester,
      stores: [store('s1', '아메 하우스')],
      index: () => done.future,
      query: '아메',
    );
    expect(find.text('매장 (1)'), findsOneWidget);
    expect(find.text('메뉴를 찾고 있어요'), findsOneWidget);
    expect(find.textContaining('메뉴 ('), findsNothing);
    expect(find.textContaining('일치하는 매장이나 메뉴가 없어요'), findsNothing);
    final before = tester.getTopLeft(find.text('매장 (1)'));

    done.complete(MenuSearchIndex(hits: const [hit]));
    await tester.pump();
    await tester.pump();
    expect(find.text('메뉴 (1)'), findsOneWidget);
    expect(find.text('아이스 아메리카노'), findsOneWidget);
    expect(tester.getTopLeft(find.text('매장 (1)')), before);
    // 카테고리 태그 = 이동 후 선택될 탭의 글자, 범위 안내 고정 문구
    expect(find.text('커피'), findsOneWidget);
    expect(find.text('가격, 판매 여부, 매장 한정 메뉴는 매장 화면에서 확인해 주세요'), findsOneWidget);
    // 가격·숫자 칸 없음
    expect(find.textContaining('원'), findsNothing);
    expect(find.textContaining('₩'), findsNothing);
  });

  testWidgets('매장 0 + 메뉴 0 = 통합 빈 상태 (메뉴 확정일 때만)', (tester) async {
    await pumpSearch(
      tester,
      stores: [store('s1', '다른 매장')],
      index: () async => const MenuSearchIndex(hits: []),
      query: '없는검색어',
    );
    await tester.pump();
    expect(find.textContaining('일치하는 매장이나 메뉴가 없어요'), findsOneWidget);
  });

  testWidgets('매장 0 + 메뉴 전체 에러: 통합 빈 상태 금지, 메뉴 에러 카드 + 다시 시도', (tester) async {
    await pumpSearch(
      tester,
      stores: [store('s1', '다른 매장')],
      index: () => Future<MenuSearchIndex>.error(StateError('x')),
      query: '없는검색어',
    );
    await tester.pump();
    expect(find.textContaining('일치하는 매장이나 메뉴가 없어요'), findsNothing);
    expect(find.text("'없는검색어' 와 일치하는 매장이 없어요"), findsOneWidget);
    expect(find.text('메뉴를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('메뉴 에러에서도 매장 섹션은 그대로', (tester) async {
    await pumpSearch(
      tester,
      stores: [store('s1', '아메 하우스')],
      index: () => Future<MenuSearchIndex>.error(StateError('x')),
      query: '아메',
    );
    await tester.pump();
    expect(find.text('매장 (1)'), findsOneWidget);
    expect(find.text('메뉴를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('메뉴'), findsOneWidget); // 헤더만, 건수 없음
  });

  testWidgets('부분 실패: 결과 행 유지 + 부분 실패 줄', (tester) async {
    await pumpSearch(
      tester,
      stores: [store('s1', '아메 하우스')],
      index: () async =>
          const MenuSearchIndex(hits: [hit], failedSourceCount: 1),
      query: '아메',
    );
    await tester.pump();
    expect(find.text('아이스 아메리카노'), findsOneWidget);
    expect(find.text('일부 매장의 메뉴를 불러오지 못했어요'), findsOneWidget);
  });

  testWidgets('부분 실패 + 결과 0 + 매장 0 = 통합 빈 상태 + 부분 실패 줄', (tester) async {
    await pumpSearch(
      tester,
      stores: const [],
      index: () async => const MenuSearchIndex(hits: [], failedSourceCount: 2),
      query: '없는검색어',
    );
    await tester.pump();
    expect(find.textContaining('일치하는 매장이나 메뉴가 없어요'), findsOneWidget);
    expect(find.text('일부 매장의 메뉴를 불러오지 못했어요'), findsOneWidget);
  });

  testWidgets('1글자: 매장은 검색하고 메뉴 자리에는 안내, 메뉴 인덱스는 호출하지 않는다', (tester) async {
    var indexCalls = 0;
    await pumpSearch(
      tester,
      stores: [store('s1', '아메 하우스')],
      index: () {
        indexCalls++;
        return Future.value(const MenuSearchIndex(hits: []));
      },
      query: '아',
    );
    expect(find.text('매장 (1)'), findsOneWidget);
    expect(find.text('메뉴는 두 글자부터 찾아요'), findsOneWidget);
    expect(indexCalls, 0);
  });

  testWidgets('주소로만 걸린 매장은 카드에 주소 보조 줄', (tester) async {
    await pumpSearch(
      tester,
      stores: [store('s1', '이름다름', address: '서울 역삼동 12')],
      index: () async => const MenuSearchIndex(hits: []),
      query: '역삼',
    );
    expect(find.text('서울 역삼동 12'), findsOneWidget);
  });

  testWidgets('스냅샷 에러: 예외 원문 없이 고정 문구 + 다시 시도', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeSnapshotProvider.overrideWith(
            (ref) => Future<List<StoreEntity>>.error(StateError('SECRET-RAW')),
          ),
          menuSearchIndexProvider.overrideWith(
            (ref) async => const MenuSearchIndex(hits: []),
          ),
          mainCategoriesActiveProvider.overrideWith((ref) => _cats()),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.enterText(find.byType(TextField), '아메');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1)); // 자동 재시도 1회(0.8s) 이후 에러 확정
    await tester.pump();
    expect(find.text('매장 정보를 불러올 수 없어요'), findsOneWidget);
    expect(find.text('잠시 후 다시 시도해 주세요'), findsOneWidget);
    expect(find.textContaining('SECRET-RAW'), findsNothing);
    expect(find.text('메뉴'), findsNothing); // 검색 영역 전체가 에러 블록 — 메뉴 섹션을 그리지 않는다
  });

  testWidgets('최근 검색어: 제출 시 기록, 탭하면 채움, 개별/전체 삭제', (tester) async {
    await pumpSearch(
      tester,
      stores: [store('s1', '아메 하우스')],
      index: () async => const MenuSearchIndex(hits: []),
      query: '',
    );
    expect(find.text('매장 이름, 주소, 메뉴로 찾아보세요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '아메');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    // 지우면 최근 검색어가 보인다
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.text('최근 검색어'), findsOneWidget);
    expect(find.text('아메'), findsOneWidget);
    await tester.tap(find.text('전체 삭제'));
    await tester.pump();
    expect(find.text('최근 검색어'), findsNothing);
  });

  group('홈 추천 미리보기', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      required List<StoreEntity> stores,
      bool fail = false,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeSnapshotProvider.overrideWith(
              (ref) => fail
                  ? Future<List<StoreEntity>>.error(StateError('RAW-EXC'))
                  : Future.value(stores),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: RecommendedStoresSection()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // 재시도 1회 이후
      await tester.pump();
    }

    testWidgets('5건 초과: 헤더 전체 건수 + 5장 + 전체보기 + 더 보기 버튼', (tester) async {
      await pumpHome(
        tester,
        stores: List.generate(8, (i) => store('s$i', '매장$i', km: i.toDouble())),
      );
      expect(find.text('맞춤 추천 (8)'), findsOneWidget);
      expect(find.text('전체보기'), findsOneWidget);
      expect(find.text('맞춤 추천 3곳 더 보기'), findsOneWidget);
      expect(find.text('매장4'), findsOneWidget);
      expect(find.text('매장5'), findsNothing);
      // 전체보기 터치 영역 >= 44
      final size = tester.getSize(
        find
            .ancestor(of: find.text('전체보기'), matching: find.byType(InkWell))
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('5건 이하: 전체보기/더 보기 없음, 건수는 그대로', (tester) async {
      await pumpHome(
        tester,
        stores: List.generate(3, (i) => store('s$i', '매장$i')),
      );
      expect(find.text('맞춤 추천 (3)'), findsOneWidget);
      expect(find.text('전체보기'), findsNothing);
      expect(find.textContaining('더 보기'), findsNothing);
    });

    testWidgets('에러: 예외 원문 노출 없이 고정 문구, 헤더에 건수 없음', (tester) async {
      await pumpHome(tester, stores: const [], fail: true);
      expect(find.text('맞춤 추천'), findsOneWidget);
      expect(find.text('매장 정보를 불러올 수 없어요'), findsOneWidget);
      expect(find.text('잠시 후 다시 시도해 주세요'), findsOneWidget);
      expect(find.textContaining('RAW-EXC'), findsNothing);
      expect(find.text('전체보기'), findsNothing);
    });

    testWidgets('더 보기 버튼 -> 추천 전체 화면: 전체 건수 + 정렬 토글 + 100행까지 지연 생성', (
      tester,
    ) async {
      await pumpHome(
        tester,
        stores: List.generate(8, (i) => store('s$i', '매장$i', km: i.toDouble())),
      );
      await tester.tap(find.text('맞춤 추천 3곳 더 보기'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
      expect(find.byType(RecommendedStoresPage), findsOneWidget);
      expect(find.text('전체 8곳'), findsOneWidget);
      expect(find.text('거리순'), findsOneWidget);
      expect(find.text('등급순'), findsOneWidget);
      await tester.tap(find.text('등급순'));
      await tester.pump();
      expect(find.text('전체 8곳'), findsOneWidget);
    });
  });

  group('StoreMenuPage — 검색 진입', () {
    final menu = [
      const MenuItemEntity(
        id: 'm1',
        storeId: 's1',
        name: '아이스 아메리카노',
        mainCategoryCode: 'coffee',
        basePrice: 4000,
      ),
      const MenuItemEntity(
        id: 'm2',
        storeId: 's1',
        name: '녹차',
        mainCategoryCode: 'tea',
        basePrice: 4500,
      ),
    ];

    Future<ProviderContainer> pumpMenu(
      WidgetTester tester, {
      String? initialCategory,
      String? highlight,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = store('s1', '강남점');
      final container = ProviderContainer(
        overrides: [
          watchedStoreProvider.overrideWith((ref, id) => Stream.value(s)),
          storeMenuItemsProvider.overrideWith((ref, id) => Stream.value(menu)),
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
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StoreMenuPage(
              store: s,
              initialMainCategoryCode: initialCategory,
              highlightMenuItemId: highlight,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets('initialMainCategoryCode: 해당 카테고리만 보이고 나갈 때 선택이 되돌려진다', (
      tester,
    ) async {
      final c = await pumpMenu(tester, initialCategory: 'tea');
      expect(c.read(selectedMainCategoryProvider), 'tea');
      expect(find.text('녹차'), findsOneWidget);
      expect(find.text('아이스 아메리카노'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump();
      expect(c.read(selectedMainCategoryProvider), isNull);
    });

    testWidgets('매장에 없는 카테고리면 기존 동작(전체 노출)으로 폴백', (tester) async {
      await pumpMenu(tester, initialCategory: 'dessert');
      expect(find.text('녹차'), findsOneWidget);
      expect(find.text('아이스 아메리카노'), findsOneWidget);
    });

    testWidgets('미지정: 기존 동작 그대로 (선택 provider 를 건드리지 않는다)', (tester) async {
      final c = await pumpMenu(tester);
      expect(c.read(selectedMainCategoryProvider), isNull);
      expect(find.textContaining('검색한 메뉴'), findsNothing);
    });

    testWidgets('highlightMenuItemId 가 목록에 있으면 띠 `검색한 메뉴  {이름}`, 닫으면 사라진다', (
      tester,
    ) async {
      await pumpMenu(tester, initialCategory: 'coffee', highlight: 'm1');
      expect(find.text('검색한 메뉴  아이스 아메리카노'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pump();
      expect(find.textContaining('검색한 메뉴'), findsNothing);
    });

    testWidgets('목록에 없으면 정직한 안내 띠', (tester) async {
      await pumpMenu(tester, initialCategory: 'coffee', highlight: 'gone');
      expect(find.text('이 매장에서는 판매하지 않는 메뉴일 수 있어요'), findsOneWidget);
    });
  });
}
