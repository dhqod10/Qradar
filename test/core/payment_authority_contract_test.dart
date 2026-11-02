import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/checkout_menu_gate.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/core/utils/store_sellability.dart';
import 'package:qradar/data/models/business_hours_model.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/data/models/menu_override_model.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';

/// payment_server_authority 교차 골든 (spec §7.1 · §18.2).
///
/// 세 fixture 를 **TS 쪽 테스트(`functions/test/paymentAuthority.test.mjs`)도 같은 파일로** 읽는다.
/// 한쪽만 바뀌면 골든이 깨져 대조가 강제된다 (기존 `qoin_cart_contract.json` 패턴).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('test_fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

/// 마스터 메뉴는 실제 모델 경로(`MenuItemModel.fromData`)로 만든다 — `optionGroupRefs` 해석(scope 부재/모르는 값 = master,
/// id 부재 = '', 객체가 아닌 요소 건너뜀)을 서버 `menuVisibility.ts` 와 같은 fixture 로 고정하기 위해서다.
MenuItemEntity _master(Map<String, dynamic> m) => MenuItemModel.fromData(
  'm1',
  {'name': '아메리카노', 'mainCategory': 'coffee', 'status': 'approved', ...m},
  storeId: '',
).toEntity();

MenuItemEntity _storeMenu(Map<String, dynamic> m) => MenuItemEntity(
  id: 'm1',
  storeId: 's1',
  name: '점포 메뉴',
  mainCategoryCode: 'coffee',
  basePrice: 3000,
  soldOut: m['soldOut'] as bool? ?? false,
  visible: m['visible'] as bool? ?? true,
);

/// 실제 모델 경로와 같은 기본값을 쓴다: status 부재 = 'pending' (MenuOverrideModel 기본),
/// 알 수 없는 문자열 = EntityApprovalStatus.fromString 폴백 (toEntity 가 호출한다).
MenuOverrideEntity? _override(Map<String, dynamic>? o) {
  if (o == null) return null;
  return MenuOverrideModel(
    masterMenuItemId: 'm1',
    storeId: 's1',
    brandId: 'b1',
    priceOverride: (o['priceOverride'] as num?)?.toInt(),
    excluded: o['excluded'] as bool? ?? false,
    soldOut: o['soldOut'] as bool? ?? false,
    disabledOptionGroupIds: List<String>.from(
      o['disabledOptionGroupIds'] as List? ?? const [],
    ),
    disabledOptionItemIds: List<String>.from(
      o['disabledOptionItemIds'] as List? ?? const [],
    ),
    status: o['status'] as String? ?? 'pending',
  ).toEntity();
}

void main() {
  group('menu_visibility_contract.json — applyOverrideForCustomer', () {
    final cases = (_load('menu_visibility_contract.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    assert(cases.isNotEmpty);
    for (final c in cases) {
      test(c['name'] as String, () {
        final r = applyOverrideForCustomer(
          master: _master(c['master'] as Map<String, dynamic>),
          override: _override(c['override'] as Map<String, dynamic>?),
        );
        final expected = c['expect'] as Map<String, dynamic>?;
        if (expected == null) {
          expect(r, isNull);
          return;
        }
        expect(r, isNotNull);
        expect(r!.basePrice, expected['basePrice']);
        expect(r.soldOut, expected['soldOut']);
        expect(r.disabledOptionGroupIds, expected['disabledOptionGroupIds']);
        expect(r.disabledOptionItemIds, expected['disabledOptionItemIds']);
        expect(
          [
            for (final ref in r.optionGroupRefs)
              {'scope': ref.scope.asString, 'id': ref.id},
          ],
          expected['optionGroupRefs'],
        );
      });
    }
  });

  group('store_sellability_contract.json — canSellNow', () {
    final cases = (_load('store_sellability_contract.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    assert(cases.isNotEmpty);
    for (final c in cases) {
      test(c['name'] as String, () {
        final rawStatus = c['rawStatus'] as String?;
        final hasApprovedAt = c['hasApprovedAt'] as bool;
        final temporaryClosed = c['temporaryClosed'] as bool;
        final scheduleClosedNow = c['scheduleClosedNow'] as bool;
        expect(
          storeGateReason(
            rawStatus: rawStatus,
            hasApprovedAt: hasApprovedAt,
            temporaryClosed: temporaryClosed,
            scheduleClosedNow: scheduleClosedNow,
          ),
          c['expectReason'] as String?,
        );
        expect(
          canSellNow(
            rawStatus: rawStatus,
            hasApprovedAt: hasApprovedAt,
            temporaryClosed: temporaryClosed,
            scheduleClosedNow: scheduleClosedNow,
          ),
          c['expect'] as bool,
        );
      });
    }
  });

  group('store_sellability_contract.json — evaluateStoreOpenState / isStoreOpenNow', () {
    final cases = (_load('store_sellability_contract.json')['openStateCases']
            as List)
        .cast<Map<String, dynamic>>();
    assert(cases.length >= 20);
    const kinds = {
      'unrestricted': StoreOpenKind.unrestricted,
      'open': StoreOpenKind.open,
      'regularHoliday': StoreOpenKind.regularHoliday,
      'outsideHours': StoreOpenKind.outsideHours,
    };
    for (final c in cases) {
      test(c['name'] as String, () {
        final raw = c['weeklyHours'] as Map<String, dynamic>?;
        final weekly = raw == null
            ? null
            : <int, ScheduleDayHours>{
                for (final e in raw.entries)
                  int.parse(e.key): (
                    open: (e.value as Map)['open'] as String,
                    close: (e.value as Map)['close'] as String,
                  ),
              };
        final now = c['now'] as Map<String, dynamic>;
        final closed = (c['closedDateKeys'] as List).cast<String>().toSet();
        final r = evaluateStoreOpenState(
          weeklyHours: weekly,
          closedDateKeys: closed,
          nowWeekday: now['weekday'] as int,
          nowMinuteOfDay: now['minuteOfDay'] as int,
          nowDateKey: now['dateKey'] as String,
        );
        final expected = c['expect'] as Map<String, dynamic>;
        expect(r.kind, kinds[expected['kind']]);
        expect(r.isOpen, expected['isOpen']);
        expect(r.nextOpenAt, expected['nextOpenAt']);
        expect(r.closeAt, expected['closeAt']);
        expect(r.todayRange, expected['todayRange']);
        expect(
          isStoreOpenNow(
            weeklyHours: weekly,
            closedDateKeys: closed,
            nowWeekday: now['weekday'] as int,
            nowMinuteOfDay: now['minuteOfDay'] as int,
            nowDateKey: now['dateKey'] as String,
          ),
          expected['isOpen'],
        );
      });
    }
  });

  group('store_sellability_contract.json — BusinessHoursModel.tryParse', () {
    final cases = (_load('store_sellability_contract.json')['parseCases']
            as List)
        .cast<Map<String, dynamic>>();
    assert(cases.length >= 8);
    for (final c in cases) {
      test(c['name'] as String, () {
        final m = BusinessHoursModel.tryParse(c['raw']);
        final expected = c['expect'] as Map<String, dynamic>?;
        if (expected == null) {
          expect(m, isNull);
          return;
        }
        expect(m, isNotNull);
        expect(m!.toMap()['weeklyHours'], expected);
      });
    }
  });

  group('checkout_menu_gate_contract.json — classifyCheckoutMenu', () {
    final cases = (_load('checkout_menu_gate_contract.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    assert(cases.isNotEmpty);
    const verdicts = {
      'OK': CheckoutMenuVerdict.ok,
      'MENU_SOLD_OUT': CheckoutMenuVerdict.soldOut,
      'MENU_EXCLUDED': CheckoutMenuVerdict.excluded,
      'MENU_NOT_FOUND': CheckoutMenuVerdict.notFound,
    };
    for (final c in cases) {
      test(c['name'] as String, () {
        final storeMenu = c['storeMenu'] as Map<String, dynamic>?;
        final master = c['master'] as Map<String, dynamic>?;
        expect(
          classifyCheckoutMenu(
            hasBrand: c['hasBrand'] as bool,
            storeMenu: storeMenu == null ? null : _storeMenu(storeMenu),
            master: master == null ? null : _master(master),
            override: _override(c['override'] as Map<String, dynamic>?),
          ),
          verdicts[c['expect']],
        );
      });
    }
  });
}
