import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/data/models/menu_override_model.dart';
import 'package:qradar/data/models/store_model.dart';
import 'package:qradar/data/repositories/menu_item_repository_impl.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';

/// 최우선 회귀 2건 (spec §15.14 tester).
///  ① `_mergeForBrandStore` 교체 전/후 동일 — 특히 status != approved override 의 분기
///  ② 매장 카드(목록) 가격 == 상세 가격 (개정 전에는 달랐다)
/// 리포지토리는 **실제 구현**(MenuItemRepositoryImpl)을 쓰고 Firestore 데이터 소스만 대체한다.
const _master = MenuItemEntity(
  id: 'm1',
  storeId: '',
  name: '아메리카노',
  mainCategoryCode: 'coffee',
  basePrice: 4000,
  status: EntityApprovalStatus.approved,
);

MenuOverrideEntity _ov({
  required EntityApprovalStatus status,
  bool excluded = false,
  int? price,
  bool soldOut = false,
  List<String> groups = const [],
  List<String> items = const [],
}) => MenuOverrideEntity(
  masterMenuItemId: 'm1',
  storeId: 's1',
  brandId: 'b1',
  priceOverride: price,
  excluded: excluded,
  soldOut: soldOut,
  disabledOptionGroupIds: groups,
  disabledOptionItemIds: items,
  status: status,
);

void main() {
  group('applyOverrideForCustomer — 핵심 필드는 approved 만, 운영 필드는 status 무관', () {
    test('override 없음 = 마스터 그대로', () {
      expect(
        applyOverrideForCustomer(master: _master, override: null),
        _master,
      );
    });

    test(
      'approved: excluded -> null / priceOverride 적용 / soldOut·disabled 적용',
      () {
        expect(
          applyOverrideForCustomer(
            master: _master,
            override: _ov(
              status: EntityApprovalStatus.approved,
              excluded: true,
            ),
          ),
          isNull,
        );
        final r = applyOverrideForCustomer(
          master: _master,
          override: _ov(
            status: EntityApprovalStatus.approved,
            price: 3500,
            soldOut: true,
            groups: ['g'],
            items: ['i'],
          ),
        )!;
        expect(r.basePrice, 3500);
        expect(r.soldOut, isTrue);
        expect(r.disabledOptionGroupIds, ['g']);
        expect(r.disabledOptionItemIds, ['i']);
      },
    );

    for (final st in [
      EntityApprovalStatus.pending,
      EntityApprovalStatus.rejected,
    ]) {
      test(
        '$st: excluded·priceOverride 는 무시, soldOut·disabled 는 즉시 적용 (뒤집히면 FAIL)',
        () {
          final r = applyOverrideForCustomer(
            master: _master,
            override: _ov(
              status: st,
              excluded: true,
              price: 1,
              soldOut: true,
              groups: ['g'],
              items: ['i'],
            ),
          );
          expect(r, isNotNull, reason: '승인 전 excluded 는 적용되면 안 된다');
          expect(r!.basePrice, 4000, reason: '승인 전 priceOverride 는 적용되면 안 된다');
          expect(r.soldOut, isTrue);
          expect(r.disabledOptionGroupIds, ['g']);
          expect(r.disabledOptionItemIds, ['i']);
        },
      );
    }
  });

  group('① _mergeForBrandStore 교체 전/후 동치 (실제 리포지토리 vs 교체 전 구현의 사본)', () {
    test(
      'status x excluded x price x soldOut x disabled 전 조합 + 마스터 필터 + 점포 한정',
      () async {
        final masters = <MenuItemEntity>[];
        final overrides = <MenuOverrideEntity>[];
        var n = 0;
        for (final st in EntityApprovalStatus.values) {
          for (final ex in [false, true]) {
            for (final price in [null, 3000]) {
              for (final sold in [false, true]) {
                for (final dis in [false, true]) {
                  final id = 'x${n++}';
                  masters.add(
                    _master.copyWith(
                      id: id,
                      name: id,
                      displayOrder: n,
                      soldOut: n.isEven,
                    ),
                  );
                  overrides.add(
                    MenuOverrideEntity(
                      masterMenuItemId: id,
                      storeId: 's1',
                      brandId: 'b1',
                      priceOverride: price,
                      excluded: ex,
                      soldOut: sold,
                      disabledOptionGroupIds: dis ? ['g$n'] : const [],
                      disabledOptionItemIds: dis ? ['i$n'] : const [],
                      status: st,
                    ),
                  );
                }
              }
            }
          }
        }
        // override 없는 마스터 / 승인 전·비노출 마스터 / 점포 한정 메뉴
        masters.addAll([
          _master.copyWith(id: 'plain', name: 'plain', displayOrder: 900),
          _master.copyWith(
            id: 'pend',
            name: 'pend',
            status: EntityApprovalStatus.pending,
          ),
          _master.copyWith(id: 'hid', name: 'hid', visible: false),
        ]);
        final storeOnly = [
          _master.copyWith(id: 'so1', name: 'so1', displayOrder: 5),
          _master.copyWith(
            id: 'so2',
            name: 'so2',
            status: EntityApprovalStatus.pending,
          ),
        ];

        final repo = _repo(
          masters: masters,
          overrides: overrides,
          storeOnly: storeOnly,
        );
        final actual = await repo.watchByStore('s1', brandId: 'b1').first;
        expect(actual, _legacyMerge(masters, overrides, storeOnly));
        // 조합이 실제로 분기를 밟았는지 (빈 비교 방지)
        expect(actual.length, greaterThan(40));
        expect(actual.any((m) => m.soldOut), isTrue);
      },
    );
  });

  group('② 메뉴 상세(watchById) 가 override 를 적용한다 — 카드 가격 == 상세 가격', () {
    Future<(MenuItemEntity? card, MenuItemEntity? detail)> both(
      MenuOverrideEntity? ov,
    ) async {
      final repo = _repo(
        masters: [_master],
        overrides: [?ov],
        storeOnly: const [],
      );
      final card = (await repo.watchByStore('s1', brandId: 'b1').first)
          .where((m) => m.id == 'm1')
          .firstOrNull;
      final detail = await repo
          .watchById(storeId: 's1', menuItemId: 'm1')
          .first;
      return (card, detail);
    }

    test(
      'approved priceOverride: 카드 3500 == 상세 3500 (개정 전 상세는 4000)',
      () async {
        final (card, detail) = await both(
          _ov(
            status: EntityApprovalStatus.approved,
            price: 3500,
            soldOut: true,
            groups: ['g'],
          ),
        );
        expect(card!.basePrice, 3500);
        expect(detail!.basePrice, card.basePrice);
        expect(detail.soldOut, isTrue);
        expect(detail.disabledOptionGroupIds, ['g']);
      },
    );

    test(
      'pending override: 가격은 마스터(둘 다 4000), 품절·비활성 옵션은 즉시 적용(둘 다)',
      () async {
        final (card, detail) = await both(
          _ov(
            status: EntityApprovalStatus.pending,
            price: 1,
            soldOut: true,
            items: ['i'],
          ),
        );
        expect(card!.basePrice, 4000);
        expect(detail!.basePrice, 4000);
        expect(detail.soldOut, card.soldOut);
        expect(detail.disabledOptionItemIds, ['i']);
      },
    );

    test(
      'approved excluded: 카드에서도 상세에서도 없음 (상세는 null -> _DeletedView)',
      () async {
        final (card, detail) = await both(
          _ov(status: EntityApprovalStatus.approved, excluded: true),
        );
        expect(card, isNull);
        expect(detail, isNull);
      },
    );

    test('override 문서 없음: 마스터 그대로', () async {
      final (card, detail) = await both(null);
      expect(detail, card);
    });

    test('override 스트림 실패: 마스터 값으로 폴백하지 않고 에러로 전파된다', () async {
      final repo = _repo(
        masters: [_master],
        overrides: const [],
        storeOnly: const [],
        overrideError: StateError('permission'),
      );
      expect(
        repo.watchById(storeId: 's1', menuItemId: 'm1').first,
        throwsA(isA<StateError>()),
      );
    });

    test('개인 매장(case A) 은 변화 없음 — override 를 구독하지 않는다', () async {
      final ds = _OvDs(const [])..error = StateError('호출되면 안 된다');
      final repo = MenuItemRepositoryImpl(
        _MenuDs(const [], byId: _model('p1')),
        masterMenuDataSource: _MasterDs(const []),
        menuOverrideDataSource: ds,
        storeRemoteDataSource: _StoreDs(brandId: null),
      );
      final r = await repo
          .watchById(storeId: 'p-store', menuItemId: 'p1')
          .first;
      expect(r!.id, 'p1');
    });
  });
}

// ── 교체 전 구현의 사본 (비교 기준) ─────────────────────────────────────────
List<MenuItemEntity> _legacyMerge(
  List<MenuItemEntity> master,
  List<MenuOverrideEntity> overrides,
  List<MenuItemEntity> storeOnly,
) {
  final approvedMaster = master
      .where((m) => m.status == EntityApprovalStatus.approved && m.visible)
      .toList();
  final approvedStoreOnly = storeOnly
      .where((m) => m.status == EntityApprovalStatus.approved && m.visible)
      .toList();
  final allOverrideMap = {for (final o in overrides) o.masterMenuItemId: o};
  final approvedOverrideMap = {
    for (final o in overrides.where(
      (o) => o.status == EntityApprovalStatus.approved,
    ))
      o.masterMenuItemId: o,
  };
  final mergedMaster = approvedMaster
      .where((m) => !(approvedOverrideMap[m.id]?.excluded ?? false))
      .map((m) {
        final approvedOv = approvedOverrideMap[m.id];
        final allOv = allOverrideMap[m.id];
        return m.copyWith(
          basePrice: approvedOv?.priceOverride ?? m.basePrice,
          soldOut: allOv?.soldOut ?? m.soldOut,
          disabledOptionGroupIds:
              allOv?.disabledOptionGroupIds ?? m.disabledOptionGroupIds,
          disabledOptionItemIds:
              allOv?.disabledOptionItemIds ?? m.disabledOptionItemIds,
        );
      })
      .toList();
  final merged = [...mergedMaster, ...approvedStoreOnly];
  merged.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return merged;
}

// ── fixtures ───────────────────────────────────────────────────────────────
MenuItemModel _model(String id) => MenuItemModel(
  id: id,
  storeId: 'p-store',
  name: id,
  mainCategory: 'coffee',
  basePrice: 1000,
);

MenuItemModel _toModel(MenuItemEntity e) => MenuItemModel(
  id: e.id,
  storeId: e.storeId,
  name: e.name,
  imageUrl: e.imageUrl,
  mainCategory: e.mainCategoryCode,
  basePrice: e.basePrice,
  soldOut: e.soldOut,
  displayOrder: e.displayOrder,
  scope: e.scope.name,
  tags: e.tags,
  visible: e.visible,
  disabledOptionGroupIds: e.disabledOptionGroupIds,
  disabledOptionItemIds: e.disabledOptionItemIds,
  status: e.status?.asString,
);

MenuItemRepositoryImpl _repo({
  required List<MenuItemEntity> masters,
  required List<MenuOverrideEntity> overrides,
  required List<MenuItemEntity> storeOnly,
  Object? overrideError,
}) {
  return MenuItemRepositoryImpl(
    _MenuDs(storeOnly.map(_toModel).toList()),
    masterMenuDataSource: _MasterDs(masters.map(_toModel).toList()),
    menuOverrideDataSource: _OvDs(overrides)..error = overrideError,
    storeRemoteDataSource: _StoreDs(brandId: 'b1'),
  );
}

class _MenuDs implements MenuItemRemoteDataSource {
  _MenuDs(this.items, {this.byId});
  final List<MenuItemModel> items;
  final MenuItemModel? byId;
  @override
  Stream<List<MenuItemModel>> streamByStore(String storeId) =>
      Stream.value(items);
  @override
  Stream<MenuItemModel?> streamById({
    required String storeId,
    required String menuItemId,
  }) => Stream.value(byId != null && byId!.id == menuItemId ? byId : null);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _MasterDs implements MasterMenuItemRemoteDataSource {
  _MasterDs(this.items);
  final List<MenuItemModel> items;
  @override
  Stream<List<MenuItemEntity>> watchAllByBrand(String brandId) => Stream.value(
    items
        .map(
          (m) => MenuItemEntity(
            id: m.id,
            storeId: '',
            name: m.name,
            imageUrl: m.imageUrl,
            mainCategoryCode: m.mainCategory,
            basePrice: m.basePrice,
            soldOut: m.soldOut,
            displayOrder: m.displayOrder,
            visible: m.visible,
            disabledOptionGroupIds: m.disabledOptionGroupIds,
            disabledOptionItemIds: m.disabledOptionItemIds,
            status: m.status == null
                ? null
                : EntityApprovalStatus.fromString(m.status!),
          ),
        )
        .toList(),
  );
  @override
  Stream<MenuItemModel?> streamById(String brandId, String menuItemId) =>
      Stream.value(items.where((m) => m.id == menuItemId).firstOrNull);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _OvDs implements MenuOverrideRemoteDataSource {
  _OvDs(this.overrides);
  final List<MenuOverrideEntity> overrides;
  Object? error;
  MenuOverrideModel _m(MenuOverrideEntity o) => MenuOverrideModel(
    masterMenuItemId: o.masterMenuItemId,
    storeId: o.storeId,
    brandId: o.brandId,
    priceOverride: o.priceOverride,
    excluded: o.excluded,
    soldOut: o.soldOut,
    disabledOptionGroupIds: o.disabledOptionGroupIds,
    disabledOptionItemIds: o.disabledOptionItemIds,
    status: o.status.asString,
  );
  @override
  Stream<List<MenuOverrideModel>> streamByStore(String storeId) =>
      Stream.value(overrides.map(_m).toList());
  @override
  Stream<MenuOverrideModel?> streamByStoreAndMaster(
    String storeId,
    String masterMenuItemId,
  ) {
    if (error != null) return Stream.error(error!);
    final o = overrides
        .where((o) => o.masterMenuItemId == masterMenuItemId)
        .firstOrNull;
    return Stream.value(o == null ? null : _m(o));
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _StoreDs implements StoreRemoteDataSource {
  _StoreDs({required this.brandId});
  final String? brandId;
  @override
  Future<StoreModel?> getById(String storeId) async => StoreModel(
    id: storeId,
    name: 's',
    imageUrl: '',
    latitude: 0,
    longitude: 0,
    averageScore: 0,
    reviewCount: 0,
    menuCategories: const [],
    createdAt: DateTime(2026),
    brandId: brandId,
  );
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}
