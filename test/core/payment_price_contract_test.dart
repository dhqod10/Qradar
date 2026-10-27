import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/core/utils/checkout_menu_gate.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/data/models/menu_override_model.dart';
import 'package:qradar/data/models/option_group_model.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';

/// payment_price_authority 교차 골든 (spec §19-1).
///
/// 두 fixture 를 **TS 쪽 테스트(`functions/test/priceAuthority.test.mjs`)도 같은 파일로** 읽는다.
/// 한쪽만 바뀌면 골든이 깨져 대조가 강제된다 (payment_server_authority 의 패턴).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('test_fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

/// 그룹 문서 → 엔티티. 실제 모델 경로(`OptionGroupModel.fromData`)로 해석한다.
OptionGroupEntity _group(String id, Map<String, dynamic> doc) =>
    OptionGroupModel.fromData(id, doc, scope: 'master').toEntity();

MenuItemEntity _menu(Map<String, dynamic> m, {String storeId = 's1'}) =>
    MenuItemModel.fromData('m1', {
      'name': '메뉴',
      'mainCategory': 'coffee',
      'status': 'approved',
      ...m,
    }, storeId: storeId).toEntity();

MenuOverrideEntity? _override(Map<String, dynamic>? o) {
  if (o == null) return null;
  return MenuOverrideModel(
    masterMenuItemId: 'm1',
    storeId: 's1',
    brandId: 'b1',
    priceOverride: (o['priceOverride'] as num?)?.toInt(),
    excluded: o['excluded'] as bool? ?? false,
    soldOut: o['soldOut'] as bool? ?? false,
    status: o['status'] as String? ?? 'pending',
  ).toEntity();
}

/// 결제 시점 기준가 — 서버 `classifyCartMenu(...).merged.basePrice` 와 같은 규칙.
int _basePrice(Map<String, dynamic> menu) {
  final storeMenu = menu['storeMenu'] as Map<String, dynamic>?;
  final master = menu['master'] as Map<String, dynamic>?;
  final hasBrand = menu['hasBrand'] as bool;
  if (storeMenu != null) return _menu(storeMenu).basePrice;
  if (hasBrand && master != null) {
    final merged = applyOverrideForCustomer(
      master: _menu(master, storeId: ''),
      override: _override(menu['override'] as Map<String, dynamic>?),
    );
    return merged!.basePrice;
  }
  throw StateError('골든 케이스의 메뉴는 판매 중이어야 한다');
}

void main() {
  group('option_availability_contract.json', () {
    final cases = (_load('option_availability_contract.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    assert(cases.length >= 12);
    for (final c in cases) {
      test(c['name'] as String, () {
        final disabledGroups = Set<String>.from(c['disabledGroupIds'] as List);
        final disabledItems = Set<String>.from(c['disabledItemIds'] as List);
        if (c['kind'] == 'resolve') {
          final groups = [
            for (final g in (c['groups'] as List).cast<Map<String, dynamic>>())
              _group(g['id'] as String, g['doc'] as Map<String, dynamic>),
          ];
          final r = resolveSelectableOptions(
            groups: groups,
            disabledGroupIds: disabledGroups,
            disabledItemIds: disabledItems,
          );
          expect([
            for (final g in r)
              {
                'id': g.id,
                'selectionType': g.selectionType.asString,
                'required': g.required,
                'items': [
                  for (final i in g.items)
                    {'id': i.id, 'priceDelta': i.priceDelta},
                ],
              },
          ], c['expect']);
          return;
        }
        final refs = [
          for (final r in (c['refs'] as List).cast<Map<String, dynamic>>())
            OptionGroupRef(
              scope: OptionScope.fromString(r['scope'] as String),
              id: r['id'] as String,
            ),
        ];
        final rawGroups = c['groups'] as Map<String, dynamic>;
        final byKey = <String, OptionGroupEntity?>{
          for (final e in rawGroups.entries)
            e.key: e.value == null
                ? null
                : _group(
                    e.key.split(':').last,
                    e.value as Map<String, dynamic>,
                  ),
        };
        final r = validateSelection(
          refs: refs,
          groupsByRefKey: byKey,
          disabledGroupIds: disabledGroups,
          disabledItemIds: disabledItems,
          selected: [
            for (final s
                in (c['selected'] as List).cast<Map<String, dynamic>>())
              (groupId: s['groupId'] as String, itemId: s['itemId'] as String),
          ],
        );
        final expected = c['expect'] as Map<String, dynamic>;
        expect([
          for (final i in r.issues)
            {
              'groupId': i.groupId,
              if (i.itemId != null) 'itemId': i.itemId,
              'kind': i.kind.asString,
            },
        ], expected['issues']);
        expect(r.priceDeltas, expected['priceDeltas']);
      });
    }
  });

  group('cart_pricing_contract.json — computeCartAmount', () {
    final cases = (_load('cart_pricing_contract.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    assert(cases.length >= 10);
    for (final c in cases) {
      test(c['name'] as String, () {
        final lines = [
          for (final l in (c['lines'] as List).cast<Map<String, dynamic>>())
            CartPricingLine(
              basePrice: _basePrice(l['menu'] as Map<String, dynamic>),
              priceDeltas: List<int>.from(l['deltas'] as List),
              quantity: l['quantity'] as int,
            ),
        ];
        final r = computeCartAmount(lines);
        final expected = c['expect'] as Map<String, dynamic>;
        expect([
          for (final l in r.lines) {'unit': l.unitPrice, 'total': l.lineTotal},
        ], expected['lines']);
        expect(r.subtotal, expected['subtotal']);
        expect(r.expected, expected['expected']);
        expect(r.discount, 0);
      });
    }
  });

  test(
    'classifyCheckoutMenu 와 같은 규칙: 골든의 메뉴는 전부 판매 가능으로 분류된다 (기준가 산식의 전제)',
    () {
      final cases = (_load('cart_pricing_contract.json')['cases'] as List)
          .cast<Map<String, dynamic>>();
      for (final c in cases) {
        for (final l in (c['lines'] as List).cast<Map<String, dynamic>>()) {
          final m = l['menu'] as Map<String, dynamic>;
          final storeMenu = m['storeMenu'] as Map<String, dynamic>?;
          final master = m['master'] as Map<String, dynamic>?;
          expect(
            classifyCheckoutMenu(
              hasBrand: m['hasBrand'] as bool,
              storeMenu: storeMenu == null ? null : _menu(storeMenu),
              master: master == null ? null : _menu(master, storeId: ''),
              override: _override(m['override'] as Map<String, dynamic>?),
            ),
            CheckoutMenuVerdict.ok,
            reason: c['name'] as String,
          );
        }
      }
    },
  );
}
