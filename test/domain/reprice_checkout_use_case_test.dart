import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/data/datasources/local/cart_local_data_source.dart';
import 'package:qradar/data/repositories/cart_repository_impl.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_item_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/domain/entities/selected_option.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/usecases/apply_repriced_cart_use_case.dart';
import 'package:qradar/domain/usecases/validate_checkout_use_case.dart';

/// payment_price_authority R9 — 체크아웃 진입 재가격 (선검증 확장). 선검증은 권위가 아니다 (읽기 실패 시 막지 않는다).
class _Repo implements CheckoutValidationRepository {
  _Repo({
    this.brandId,
    this.docs = const {},
    this.groups = const {},
    this.groupsError,
  });

  final String? brandId;
  final Map<String, CheckoutMenuDocs> docs;
  final Map<String, OptionGroupEntity?> groups;
  final Object? groupsError;
  int groupCalls = 0;
  int menuCalls = 0;
  List<List<OptionGroupRef>> groupRefs = [];

  @override
  Future<StoreSellabilityInput?> fetchStoreFresh(String storeId) async =>
      StoreSellabilityInput(
        rawStatus: 'approved',
        hasApprovedAt: true,
        brandId: brandId,
      );

  @override
  Future<Map<String, CheckoutMenuDocs>> fetchMenuDocsFresh({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  }) async {
    menuCalls++;
    return {
      for (final id in menuItemIds) id: docs[id] ?? const CheckoutMenuDocs(),
    };
  }

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async {
    groupCalls++;
    groupRefs.add(refs);
    if (groupsError != null) throw groupsError!;
    return {
      for (final r in refs)
        optionRefKey(r.scope, r.id): groups[optionRefKey(r.scope, r.id)],
    };
  }
}

MenuItemEntity _menu(
  String id, {
  int price = 4000,
  List<OptionGroupRef> refs = const [],
  bool soldOut = false,
  List<String> disabledItems = const [],
}) => MenuItemEntity(
  id: id,
  storeId: 's1',
  name: '메뉴 $id',
  mainCategoryCode: 'coffee',
  basePrice: price,
  optionGroupRefs: refs,
  soldOut: soldOut,
  disabledOptionItemIds: disabledItems,
);

OptionGroupEntity _group(
  String id,
  List<OptionItemEntity> items, {
  bool required = false,
  OptionSelectionType type = OptionSelectionType.single,
}) => OptionGroupEntity(
  id: id,
  scope: OptionScope.store,
  name: id,
  selectionType: type,
  required: required,
  items: items,
);

const _shot = OptionItemEntity(id: 'shot', label: '샷', priceDelta: 500);
const _ref = OptionGroupRef(scope: OptionScope.store, id: 'g1');

CartItemEntity _line(
  String cartItemId,
  String menuId, {
  int unit = 4000,
  int qty = 1,
  List<SelectedOption> opts = const [],
}) => CartItemEntity(
  cartItemId: cartItemId,
  menuItemId: menuId,
  menuItemName: '메뉴 $menuId',
  quantity: qty,
  selectedOptions: opts,
  unitPriceWithOptions: unit,
  lineTotal: unit * qty,
);

const _shotSel = SelectedOption(
  groupId: 'g1',
  groupName: 'g1',
  itemId: 'shot',
  label: '샷',
  priceDelta: 500,
);

Future<CheckoutValidation> _run(
  _Repo repo,
  List<CartItemEntity> cart, {
  bool reportFailure = false,
}) => ValidateCheckoutUseCase(repo).call(
  storeId: 's1',
  menuItemIds: cart.map((l) => l.menuItemId),
  cartItems: cart,
  reportFailure: reportFailure,
);

void main() {
  group('재가격 (R9)', () {
    test('카트 단가가 문서 가격과 같으면 변동 없음 = none (표시할 것이 없다)', () async {
      final r = await _run(
        _Repo(docs: {'m1': CheckoutMenuDocs(storeMenu: _menu('m1'))}),
        [_line('c1', 'm1')],
      );
      expect(r.hasPriceChanges, isFalse);
      expect(r.hasViolations, isFalse);
      expect(identical(r, CheckoutValidation.none), isTrue);
    });

    test('가격이 올랐다: 새 단가를 계산하고, 위반은 아니다', () async {
      final r = await _run(
        _Repo(
          docs: {'m1': CheckoutMenuDocs(storeMenu: _menu('m1', price: 4500))},
        ),
        [_line('c1', 'm1', qty: 2)],
      );
      expect(r.hasViolations, isFalse, reason: '가격 변동은 위반이 아니다');
      expect(r.priceChanges, hasLength(1));
      expect(r.priceChanges.single.oldUnitPrice, 4000);
      expect(r.priceChanges.single.newUnitPrice, 4500);
      expect(r.priceChanges.single.isIncrease, isTrue);
    });

    test('가격이 내렸다: 내림도 변동이다 (조용히 바뀌는 것은 둘 다 사고)', () async {
      final r = await _run(
        _Repo(
          docs: {'m1': CheckoutMenuDocs(storeMenu: _menu('m1', price: 3500))},
        ),
        [_line('c1', 'm1')],
      );
      expect(r.priceChanges.single.newUnitPrice, 3500);
      expect(r.priceChanges.single.isIncrease, isFalse);
    });

    test('옵션 단가는 문서에서 다시 계산한다 — 카트가 선언한 priceDelta 를 믿지 않는다', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(storeMenu: _menu('m1', refs: [_ref])),
        },
        groups: {
          optionRefKey(OptionScope.store, 'g1'): _group('g1', [
            const OptionItemEntity(id: 'shot', label: '샷', priceDelta: 700),
          ]),
        },
      );
      // 카트는 +500 을 선언했지만 문서는 +700.
      final r = await _run(repo, [
        _line('c1', 'm1', unit: 4500, opts: [_shotSel]),
      ]);
      expect(r.priceChanges.single.newUnitPrice, 4700);
      expect(repo.groupCalls, 1);
      expect(repo.menuCalls, 1, reason: '메뉴 문서는 이미 읽은 것을 재사용한다 (추가 읽기 0)');
    });

    test('같은 메뉴를 옵션만 달리해 2줄: 메뉴 읽기 1회, 라인별로 따로 재가격', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(
            storeMenu: _menu('m1', price: 4200, refs: [_ref]),
          ),
        },
        groups: {
          optionRefKey(OptionScope.store, 'g1'): _group('g1', [_shot]),
        },
      );
      final r = await _run(repo, [
        _line('c1', 'm1', unit: 4000),
        _line('c2', 'm1', unit: 4500, opts: [_shotSel]),
      ]);
      expect(repo.menuCalls, 1);
      expect(
        {for (final c in r.priceChanges) c.cartItemId: c.newUnitPrice},
        {'c1': 4200, 'c2': 4700},
      );
    });

    test('옵션을 쓰지 않는 카트는 옵션 그룹을 읽지 않는다', () async {
      final repo = _Repo(
        docs: {'m1': CheckoutMenuDocs(storeMenu: _menu('m1', price: 4500))},
      );
      await _run(repo, [_line('c1', 'm1')]);
      expect(repo.groupCalls, 0);
    });

    test(
      '브랜드 메뉴: approved priceOverride 만 적용, pending 은 마스터 가격 (판정은 applyOverrideForCustomer 한 곳)',
      () async {
        MenuOverrideEntity ov(EntityApprovalStatus st) => MenuOverrideEntity(
          masterMenuItemId: 'm1',
          storeId: 's1',
          brandId: 'b1',
          priceOverride: 3000,
          status: st,
        );
        final approved = await _run(
          _Repo(
            brandId: 'b1',
            docs: {
              'm1': CheckoutMenuDocs(
                master: _menu('m1', price: 4000),
                override: ov(EntityApprovalStatus.approved),
              ),
            },
          ),
          [_line('c1', 'm1')],
        );
        expect(approved.priceChanges.single.newUnitPrice, 3000);
        final pending = await _run(
          _Repo(
            brandId: 'b1',
            docs: {
              'm1': CheckoutMenuDocs(
                master: _menu('m1', price: 4000),
                override: ov(EntityApprovalStatus.pending),
              ),
            },
          ),
          [_line('c1', 'm1')],
        );
        expect(pending.hasPriceChanges, isFalse, reason: 'pending 가격은 효력이 없다');
      },
    );

    test('옵션 위반 라인: 위반으로 보고하고 가격 변동에는 넣지 않는다 (유효한 가격이 없다)', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(
            storeMenu: _menu(
              'm1',
              price: 5000,
              refs: [_ref],
              disabledItems: ['g1_shot'],
            ),
          ),
        },
        groups: {
          optionRefKey(OptionScope.store, 'g1'): _group('g1', [_shot]),
        },
      );
      final r = await _run(repo, [
        _line('c1', 'm1', unit: 4500, opts: [_shotSel]),
      ]);
      expect(r.hasViolations, isTrue);
      expect(r.optionIssues, hasLength(1));
      expect(r.optionIssues.single.cartItemId, 'c1');
      expect(r.optionIssues.single.issue.kind, OptionIssueKind.disabled);
      expect(r.optionIssues.single.issue.itemId, 'shot');
      expect(r.hasPriceChanges, isFalse);
      expect(r.optionViolatedMenuItemIds, {'m1'});
    });

    test('필수 그룹에 선택이 없으면 requiredEmpty (그룹 단위, itemId 없음)', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(storeMenu: _menu('m1', refs: [_ref])),
        },
        groups: {
          optionRefKey(OptionScope.store, 'g1'): _group('g1', [
            _shot,
          ], required: true),
        },
      );
      final r = await _run(repo, [_line('c1', 'm1')]);
      expect(r.optionIssues.single.issue.kind, OptionIssueKind.requiredEmpty);
      expect(r.optionIssues.single.issue.itemId, isNull);
    });

    test('품절 라인은 재가격하지 않고 메뉴 위반만 보고한다', () async {
      final r = await _run(
        _Repo(
          docs: {
            'm1': CheckoutMenuDocs(
              storeMenu: _menu('m1', price: 9999, soldOut: true),
            ),
          },
        ),
        [_line('c1', 'm1')],
      );
      expect(r.menus.single.kind, MenuViolationKind.soldOut);
      expect(r.hasPriceChanges, isFalse);
    });

    test('옵션 그룹 읽기 실패 (자동): 재가격만 생략하고 메뉴 위반은 그대로 돌려준다 — 결제를 막지 않는다', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(storeMenu: _menu('m1', refs: [_ref])),
          'm2': CheckoutMenuDocs(storeMenu: _menu('m2', soldOut: true)),
        },
        groupsError: StateError('boom'),
      );
      final r = await _run(repo, [_line('c1', 'm1'), _line('c2', 'm2')]);
      expect(r.menus.single.menuItemId, 'm2');
      expect(r.hasPriceChanges, isFalse);
      expect(r.optionIssues, isEmpty);
    });

    test('옵션 그룹 읽기 실패 (reportFailure: 사용자가 직접 누름): 정직하게 던진다', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(storeMenu: _menu('m1', refs: [_ref])),
        },
        groupsError: StateError('boom'),
      );
      await expectLater(
        _run(repo, [_line('c1', 'm1')], reportFailure: true),
        throwsA(isA<StateError>()),
      );
    });

    test('cartItems 를 주지 않으면 재가격하지 않는다 (기존 호출부 호환)', () async {
      final repo = _Repo(
        docs: {
          'm1': CheckoutMenuDocs(
            storeMenu: _menu('m1', price: 4500, refs: [_ref]),
          ),
        },
      );
      final r = await ValidateCheckoutUseCase(
        repo,
      ).call(storeId: 's1', menuItemIds: const ['m1']);
      expect(r.hasPriceChanges, isFalse);
      expect(repo.groupCalls, 0);
    });

    test(
      '옵션 그룹 수 상한(kMaxOptionGroupDocs) 초과: 클라이언트는 재가격하지 않는다 (서버가 거절한다)',
      () async {
        final refs = [
          for (var i = 0; i <= kMaxOptionGroupDocs; i++)
            OptionGroupRef(scope: OptionScope.store, id: 'g$i'),
        ];
        final repo = _Repo(
          docs: {
            'm1': CheckoutMenuDocs(
              storeMenu: _menu('m1', price: 4500, refs: refs),
            ),
          },
        );
        final r = await _run(repo, [_line('c1', 'm1')]);
        expect(r.hasPriceChanges, isFalse);
        expect(repo.groupCalls, 0);
      },
    );
  });

  group('ApplyRepricedCartUseCase', () {
    CartLocalDataSource seeded() {
      final ds = CartLocalDataSource();
      ds.addItem(
        storeId: 's1',
        storeName: '매장',
        item: _line('c1', 'm1', unit: 4000, qty: 2),
      );
      ds.addItem(
        storeId: 's1',
        storeName: '매장',
        item: _line('c2', 'm2', unit: 3000),
      );
      return ds;
    }

    RepricedLine change(String id, int oldU, int newU) => RepricedLine(
      cartItemId: id,
      menuItemId: 'm',
      menuItemName: '이름',
      oldUnitPrice: oldU,
      newUnitPrice: newU,
    );

    test('단가만 받아 적용하고 라인 합계·소계는 저장소가 같은 식으로 다시 만든다', () async {
      final ds = seeded();
      final uc = ApplyRepricedCartUseCase(CartRepositoryImpl(ds));
      final applied = await uc(
        CartRepricing(priceChanges: [change('c1', 4000, 4500)]),
      );
      expect(applied.hasChanges, isTrue);
      expect(applied.changes.single.beforeUnitPrice, 4000);
      expect(applied.changes.single.afterUnitPrice, 4500);
      expect(applied.subtotalBefore, 8000 + 3000);
      expect(applied.subtotalAfter, 9000 + 3000);
      final cart = ds.current!;
      expect(cart.items.first.lineTotal, 9000, reason: '수량 2 유지');
      expect(cart.items.first.quantity, 2);
      expect(cart.items.last.lineTotal, 3000, reason: '바뀌지 않은 라인은 그대로');
      expect(cart.subtotal, 12000);
    });

    test('두 번째 호출은 변동 0 — "새로 발견된 변동" 판별이 여기서 나온다', () async {
      final ds = seeded();
      final uc = ApplyRepricedCartUseCase(CartRepositoryImpl(ds));
      final rep = CartRepricing(priceChanges: [change('c1', 4000, 4500)]);
      await uc(rep);
      final second = await uc(rep);
      expect(second.hasChanges, isFalse);
      expect(ds.current!.subtotal, 12000);
    });

    test('없는 라인 id 는 무시하고, 바뀐 것이 없으면 카트를 emit 하지 않는다', () async {
      final ds = seeded();
      final emitted = <Object?>[];
      final sub = ds.watch().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);
      emitted.clear();
      final uc = ApplyRepricedCartUseCase(CartRepositoryImpl(ds));
      final applied = await uc(
        CartRepricing(priceChanges: [change('ghost', 1, 2)]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(applied.hasChanges, isFalse);
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test('빈 카트·변동 없음은 아무 일도 하지 않는다', () async {
      final ds = CartLocalDataSource();
      final uc = ApplyRepricedCartUseCase(CartRepositoryImpl(ds));
      expect((await uc(CartRepricing.none)).hasChanges, isFalse);
      expect(
        (await uc(
          CartRepricing(priceChanges: [change('c1', 1, 2)]),
        )).hasChanges,
        isFalse,
      );
    });
  });
}
