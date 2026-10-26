import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/usecases/get_nearby_stores_use_case.dart';
import 'package:qradar/domain/usecases/get_stores_by_categories_use_case.dart';
import 'package:qradar/domain/usecases/search_menu_items_use_case.dart';
import 'package:qradar/domain/usecases/search_stores_use_case.dart';

StoreEntity store(
  String id,
  String name, {
  String address = '',
  double? km,
  String? brandId,
  List<String> cats = const ['추천메뉴'],
}) => StoreEntity(
  id: id,
  name: name,
  imageUrl: '',
  location: const UserLocation(latitude: 37, longitude: 127),
  grade: StoreGrade.a,
  averageScore: 4,
  reviewCount: 1,
  menuCategories: cats,
  createdAt: DateTime(2026),
  address: address,
  distanceKm: km,
  brandId: brandId,
);

MenuItemEntity item(
  String id,
  String name, {
  bool visible = true,
  EntityApprovalStatus? status,
  String cat = 'coffee',
}) => MenuItemEntity(
  id: id,
  storeId: '',
  name: name,
  mainCategoryCode: cat,
  basePrice: 1000,
  visible: visible,
  status: status,
);

class _FakeMenuRepo implements MenuItemRepository {
  final Map<String, List<MenuItemEntity>> byStore = {};
  final Set<String> failing = {};
  final List<String> calls = [];
  @override
  Future<List<MenuItemEntity>> fetchStoreMenusOnce(String storeId) async {
    calls.add(storeId);
    if (failing.contains(storeId)) throw StateError('boom $storeId');
    return byStore[storeId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeMasterRepo implements MasterMenuItemRepository {
  final Map<String, List<MenuItemEntity>> byBrand = {};
  final Set<String> failing = {};
  final List<String> calls = [];
  @override
  Future<List<MenuItemEntity>> fetchBrandMasterMenusOnce(String brandId) async {
    calls.add(brandId);
    if (failing.contains(brandId)) throw StateError('boom $brandId');
    return byBrand[brandId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  group('SearchStoresUseCase', () {
    final stores = [
      store('1', '강남 카페', address: '서울 강남구', km: 1),
      store('2', '역삼 로스터스', address: '서울 강남구 역삼동', km: 0.5),
      store('3', '강남 베이커리', address: '서울 서초구', km: 3),
    ];

    test('이름 매칭 그룹이 주소 매칭 그룹보다 위, 그룹 내 입력(거리) 순서 보존', () {
      final r = SearchStoresUseCase.compute(
        stores: stores,
        normalizedQuery: '강남',
      );
      expect(r.map((s) => s.id), ['1', '3', '2']);
    });

    test('주소로만 걸린 매장 판별', () {
      expect(SearchStoresUseCase.isAddressOnlyMatch(stores[1], '강남'), isTrue);
      expect(SearchStoresUseCase.isAddressOnlyMatch(stores[0], '강남'), isFalse);
    });

    test('공백 무시 + 소문자', () {
      final s = [store('1', 'Blue Bottle', km: 1)];
      expect(
        SearchStoresUseCase.compute(stores: s, normalizedQuery: 'bluebo'),
        hasLength(1),
      );
    });

    test('빈 질의는 빈 목록', () {
      expect(
        SearchStoresUseCase.compute(stores: stores, normalizedQuery: ''),
        isEmpty,
      );
    });
  });

  group('스냅샷 파생 순수 함수 (기존 Repository 규칙과 동일)', () {
    final snap = [
      store('a', 'A', km: 1, cats: ['커피']),
      store('b', 'B', km: 5, cats: ['티']),
      store('c', 'C', km: 25, cats: ['커피', '티']),
      store('d', 'D', km: null, cats: ['커피']),
    ];
    test('withinRadius: 반경 20km 이내, 거리 미상 제외, limit', () {
      expect(GetNearbyStoresUseCase.withinRadius(snap).map((s) => s.id), [
        'a',
        'b',
      ]);
      expect(
        GetNearbyStoresUseCase.withinRadius(snap, limit: 1).map((s) => s.id),
        ['a'],
      );
    });
    test('filterByCategories: 하나라도 가지면 포함, 빈 선택은 빈 목록, 순서 보존', () {
      expect(
        GetStoresByCategoriesUseCase.filterByCategories(snap, {
          '커피',
        }).map((s) => s.id),
        ['a', 'c', 'd'],
      );
      expect(
        GetStoresByCategoriesUseCase.filterByCategories(snap, {}),
        isEmpty,
      );
    });
  });

  group('SearchMenuItemsUseCase.buildIndex', () {
    late _FakeMenuRepo menus;
    late _FakeMasterRepo masters;
    late SearchMenuItemsUseCase uc;
    setUp(() {
      menus = _FakeMenuRepo();
      masters = _FakeMasterRepo();
      uc = SearchMenuItemsUseCase(menus, masters);
    });

    test('브랜드는 출처당 1회(매장 수와 무관), 개인 매장은 매장당 1회 — 브랜드 메뉴는 후보 매장으로 전개', () async {
      masters.byBrand['bA'] = [
        item('m1', '아메리카노', status: EntityApprovalStatus.approved),
      ];
      menus.byStore['p1'] = [item('x1', '아메 라떼')];
      final idx = await uc.buildIndex(
        candidateStores: [
          store('s1', 'S1', km: 1, brandId: 'bA'),
          store('s2', 'S2', km: 2, brandId: 'bA'),
          store('p1', 'P1', km: 3),
        ],
      );
      expect(masters.calls, ['bA']);
      expect(menus.calls, ['p1']);
      expect(idx.hits.map((h) => '${h.storeId}:${h.menuItemId}'), [
        's1:m1',
        's2:m1',
        'p1:x1',
      ]);
      expect(idx.failedSourceCount, 0);
      expect(idx.hits.first.source, MenuHitSource.brandMaster);
      expect(idx.hits.last.source, MenuHitSource.storeOwn);
    });

    test(
      '필터: 마스터 = visible && approved, 개인 = visible && (status null 또는 approved)',
      () async {
        masters.byBrand['bA'] = [
          item('ok', '가', status: EntityApprovalStatus.approved),
          item('pending', '나', status: EntityApprovalStatus.pending),
          item(
            'hidden',
            '다',
            visible: false,
            status: EntityApprovalStatus.approved,
          ),
          item('nostatus', '라'),
        ];
        menus.byStore['p1'] = [
          item('p-null', '마'),
          item('p-ok', '바', status: EntityApprovalStatus.approved),
          item('p-pending', '사', status: EntityApprovalStatus.pending),
          item('p-hidden', '아', visible: false),
        ];
        final idx = await uc.buildIndex(
          candidateStores: [
            store('s1', 'S1', km: 1, brandId: 'bA'),
            store('p1', 'P1', km: 2),
          ],
        );
        expect(idx.hits.map((h) => h.menuItemId).toSet(), {
          'ok',
          'p-null',
          'p-ok',
        });
      },
    );

    test('정렬: 거리 오름차순 -> 같으면 메뉴명 가나다', () async {
      menus.byStore['near'] = [item('1', '다'), item('2', '가')];
      menus.byStore['far'] = [item('3', '가')];
      final idx = await uc.buildIndex(
        candidateStores: [store('far', 'F', km: 5), store('near', 'N', km: 1)],
      );
      expect(idx.hits.map((h) => h.menuItemId), ['2', '1', '3']);
    });

    test('일부 출처 실패는 흡수되고 failedSourceCount 로 남는다', () async {
      masters.failing.add('bA');
      menus.byStore['p1'] = [item('x', '메뉴')];
      final idx = await uc.buildIndex(
        candidateStores: [
          store('s1', 'S1', km: 1, brandId: 'bA'),
          store('p1', 'P1', km: 2),
        ],
      );
      expect(idx.hits, hasLength(1));
      expect(idx.failedSourceCount, 1);
      expect(idx.isPartial, isTrue);
    });

    test('전체 실패는 예외 (호출 측이 메뉴 섹션만 에러로 그린다)', () async {
      masters.failing.add('bA');
      menus.failing.add('p1');
      expect(
        uc.buildIndex(
          candidateStores: [
            store('s1', 'S1', km: 1, brandId: 'bA'),
            store('p1', 'P1', km: 2),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('후보 0곳은 빈 인덱스(예외 아님)', () async {
      final idx = await uc.buildIndex(candidateStores: const []);
      expect(idx.hits, isEmpty);
      expect(idx.failedSourceCount, 0);
    });

    test('filter: 정규화 질의로 전체 일치 행을 순서 보존해 반환', () {
      const hits = [
        MenuSearchHitEntity(
          menuItemId: '1',
          menuName: '아이스 아메리카노',
          mainCategoryCode: 'c',
          storeId: 's',
          storeName: 'S',
          source: MenuHitSource.storeOwn,
        ),
        MenuSearchHitEntity(
          menuItemId: '2',
          menuName: '라떼',
          mainCategoryCode: 'c',
          storeId: 's',
          storeName: 'S',
          source: MenuHitSource.storeOwn,
        ),
      ];
      expect(
        SearchMenuItemsUseCase.filter(
          index: hits,
          normalizedQuery: '아이스아메',
        ).map((h) => h.menuItemId),
        ['1'],
      );
      expect(
        SearchMenuItemsUseCase.filter(index: hits, normalizedQuery: ''),
        isEmpty,
      );
    });
  });
}
