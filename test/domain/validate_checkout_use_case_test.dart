import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/usecases/validate_checkout_use_case.dart';

class _FakeRepo implements CheckoutValidationRepository {
  _FakeRepo({
    this.store,
    this.docs = const {},
    this.storeError,
    this.docsError,
    this.docsDelay,
  });

  StoreSellabilityInput? store;
  Map<String, CheckoutMenuDocs> docs;
  Object? storeError;
  Object? docsError;
  Duration? docsDelay;
  int storeCalls = 0;
  List<List<String>> docsCalls = [];

  @override
  Future<StoreSellabilityInput?> fetchStoreFresh(String storeId) async {
    storeCalls++;
    if (storeError != null) throw storeError!;
    return store;
  }

  @override
  Future<Map<String, CheckoutMenuDocs>> fetchMenuDocsFresh({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  }) async {
    docsCalls.add(menuItemIds);
    if (docsDelay != null) await Future<void>.delayed(docsDelay!);
    if (docsError != null) throw docsError!;
    return {
      for (final id in menuItemIds) id: docs[id] ?? const CheckoutMenuDocs(),
    };
  }

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async => {for (final r in refs) optionRefKey(r.scope, r.id): null};
}

const _approved = StoreSellabilityInput(
  rawStatus: 'approved',
  hasApprovedAt: false,
);

MenuItemEntity _menu(String id, {bool soldOut = false, bool visible = true}) =>
    MenuItemEntity(
      id: id,
      storeId: 's1',
      name: '메뉴 $id',
      mainCategoryCode: 'coffee',
      basePrice: 3000,
      soldOut: soldOut,
      visible: visible,
    );

void main() {
  Future<CheckoutValidation> run(
    _FakeRepo repo,
    List<String> ids, {
    bool reportFailure = false,
    Duration timeout = const Duration(seconds: 3),
  }) => ValidateCheckoutUseCase(
    repo,
    timeout: timeout,
  ).call(storeId: 's1', menuItemIds: ids, reportFailure: reportFailure);

  test('위반 0건 -> none', () async {
    final r = await run(
      _FakeRepo(
        store: _approved,
        docs: {'a': CheckoutMenuDocs(storeMenu: _menu('a'))},
      ),
      ['a'],
    );
    expect(r.hasViolations, isFalse);
  });

  test('품절 1건', () async {
    final r = await run(
      _FakeRepo(
        store: _approved,
        docs: {
          'a': CheckoutMenuDocs(storeMenu: _menu('a')),
          'b': CheckoutMenuDocs(storeMenu: _menu('b', soldOut: true)),
        },
      ),
      ['a', 'b'],
    );
    expect(r.store, isNull);
    expect(r.menus, hasLength(1));
    expect(r.menus.single.menuItemId, 'b');
    expect(r.menus.single.kind, MenuViolationKind.soldOut);
  });

  test('excluded (점포 메뉴 visible=false) -> unavailable', () async {
    final r = await run(
      _FakeRepo(
        store: _approved,
        docs: {'a': CheckoutMenuDocs(storeMenu: _menu('a', visible: false))},
      ),
      ['a'],
    );
    expect(r.menus.single.kind, MenuViolationKind.unavailable);
  });

  test('브랜드 마스터 + approved excluded override -> unavailable', () async {
    final r = await run(
      _FakeRepo(
        store: const StoreSellabilityInput(
          rawStatus: 'approved',
          hasApprovedAt: true,
          brandId: 'b1',
        ),
        docs: {
          'a': CheckoutMenuDocs(
            master: _menu('a'),
            override: const MenuOverrideEntity(
              masterMenuItemId: 'a',
              storeId: 's1',
              brandId: 'b1',
              excluded: true,
              status: EntityApprovalStatus.approved,
            ),
          ),
        },
      ),
      ['a'],
    );
    expect(r.menus.single.kind, MenuViolationKind.unavailable);
  });

  test(
    'pending excluded override 는 적용되지 않는다 (applyOverrideForCustomer 와 동일)',
    () async {
      final r = await run(
        _FakeRepo(
          store: const StoreSellabilityInput(
            rawStatus: 'approved',
            hasApprovedAt: true,
            brandId: 'b1',
          ),
          docs: {
            'a': CheckoutMenuDocs(
              master: _menu('a'),
              override: const MenuOverrideEntity(
                masterMenuItemId: 'a',
                storeId: 's1',
                brandId: 'b1',
                excluded: true,
                status: EntityApprovalStatus.pending,
              ),
            ),
          },
        ),
        ['a'],
      );
      expect(r.hasViolations, isFalse);
    },
  );

  test('메뉴 부재 (문서 3종 모두 없음) -> unavailable', () async {
    final r = await run(_FakeRepo(store: _approved), ['ghost']);
    expect(r.menus.single.menuItemId, 'ghost');
    expect(r.menus.single.kind, MenuViolationKind.unavailable);
  });

  test('매장 부재 -> store notFound, 메뉴는 읽지 않는다', () async {
    final repo = _FakeRepo(store: null);
    final r = await run(repo, ['a']);
    expect(r.store, StoreViolation.notFound);
    expect(repo.docsCalls, isEmpty);
  });

  test('매장 불가 (pending + approvedAt 없음 / 미지 status / status 부재)', () async {
    for (final raw in <String?>['pending', 'rejected', 'weird', null]) {
      final r = await run(
        _FakeRepo(
          store: StoreSellabilityInput(rawStatus: raw, hasApprovedAt: false),
        ),
        ['a'],
      );
      expect(r.store, StoreViolation.notSellable, reason: '$raw');
    }
  });

  test('임시 휴업 -> store temporarilyClosed, 미승인이면 notSellable 이 우선', () async {
    final closed = await run(
      _FakeRepo(
        store: const StoreSellabilityInput(
          rawStatus: 'approved',
          hasApprovedAt: true,
          temporaryClosed: true,
        ),
      ),
      ['a'],
    );
    expect(closed.store, StoreViolation.temporarilyClosed);
    final unapproved = await run(
      _FakeRepo(
        store: const StoreSellabilityInput(
          rawStatus: 'pending',
          hasApprovedAt: false,
          temporaryClosed: true,
        ),
      ),
      ['a'],
    );
    expect(unapproved.store, StoreViolation.notSellable);
  });

  group('영업 스케줄 (store_business_schedule) — 기기 시계 KST, 선검증은 권위 아님', () {
    // 2026-11-02 = 월요일. 12:00 KST.
    final monNoon = DateTime.utc(2026, 11, 2, 3);
    Future<CheckoutValidation> runAt(StoreSellabilityInput store) =>
        ValidateCheckoutUseCase(
          _FakeRepo(
            store: store,
            docs: {'a': CheckoutMenuDocs(storeMenu: _menu('a'))},
          ),
          now: () => monNoon,
        ).call(storeId: 's1', menuItemIds: ['a']);

    StoreSellabilityInput withHours(
      Map<int, BusinessDayHours> w, {
      bool temporaryClosed = false,
      List<DateTime> closedDates = const [],
    }) => StoreSellabilityInput(
      rawStatus: 'approved',
      hasApprovedAt: true,
      temporaryClosed: temporaryClosed,
      businessHours: BusinessHours(weeklyHours: w),
      closedDates: closedDates,
    );

    const open9to18 = BusinessDayHours(open: '09:00', close: '18:00');
    const open9to11 = BusinessDayHours(open: '09:00', close: '11:00');

    test('스케줄 미설정(null) -> 통과 (기존 매장 회귀 안전, Q1)', () async {
      final r = await runAt(
        const StoreSellabilityInput(rawStatus: 'approved', hasApprovedAt: true),
      );
      expect(r.hasViolations, isFalse);
    });

    test('영업 중 -> 통과', () async {
      expect((await runAt(withHours({1: open9to18}))).hasViolations, isFalse);
    });

    test('영업시간 밖 / 요일 엔트리 부재 / 전체 휴무(빈 맵) -> closedSchedule', () async {
      expect((await runAt(withHours({1: open9to11}))).store,
          StoreViolation.closedSchedule);
      expect((await runAt(withHours({2: open9to18}))).store,
          StoreViolation.closedSchedule);
      expect((await runAt(withHours({}))).store, StoreViolation.closedSchedule);
    });

    test('오늘이 closedDates -> closedSchedule', () async {
      final r = await runAt(
        withHours({1: open9to18}, closedDates: [DateTime.utc(2026, 11, 1, 15)]),
      );
      expect(r.store, StoreViolation.closedSchedule);
    });

    test('우선순위: 임시 휴업 > 스케줄, 미승인 > 스케줄', () async {
      expect(
        (await runAt(withHours({}, temporaryClosed: true))).store,
        StoreViolation.temporarilyClosed,
      );
      final unapproved = await runAt(
        const StoreSellabilityInput(
          rawStatus: 'pending',
          hasApprovedAt: false,
          businessHours: BusinessHours(),
        ),
      );
      expect(unapproved.store, StoreViolation.notSellable);
    });
  });

  test('pending + approvedAt 있음 -> 통과 (R2 불변식)', () async {
    final r = await run(
      _FakeRepo(
        store: const StoreSellabilityInput(
          rawStatus: 'pending',
          hasApprovedAt: true,
        ),
        docs: {'a': CheckoutMenuDocs(storeMenu: _menu('a'))},
      ),
      ['a'],
    );
    expect(r.hasViolations, isFalse);
  });

  test('같은 menuItemId 여러 줄 -> 종류 단위로 1회만 판정', () async {
    final repo = _FakeRepo(
      store: _approved,
      docs: {'a': CheckoutMenuDocs(storeMenu: _menu('a', soldOut: true))},
    );
    final r = await run(repo, ['a', 'a', 'a']);
    expect(repo.docsCalls.single, ['a']);
    expect(r.menus, hasLength(1));
  });

  group('읽기 실패는 결제를 막지 않는다 (spec §8.2)', () {
    test('매장 읽기 실패 -> none', () async {
      final r = await run(_FakeRepo(storeError: Exception('unavailable')), [
        'a',
      ]);
      expect(r.hasViolations, isFalse);
    });

    test('메뉴 읽기 실패 -> none', () async {
      final r = await run(
        _FakeRepo(store: _approved, docsError: StateError('permission-denied')),
        ['a'],
      );
      expect(r.hasViolations, isFalse);
    });

    test('타임아웃 -> none', () async {
      final r = await run(
        _FakeRepo(
          store: _approved,
          docsDelay: const Duration(milliseconds: 200),
        ),
        ['a'],
        timeout: const Duration(milliseconds: 20),
      );
      expect(r.hasViolations, isFalse);
    });

    test('reportFailure: true 는 실패를 예외로 던진다', () async {
      expect(
        () => run(_FakeRepo(storeError: Exception('x')), [
          'a',
        ], reportFailure: true),
        throwsA(isA<Exception>()),
      );
      expect(
        () => run(
          _FakeRepo(
            store: _approved,
            docsDelay: const Duration(milliseconds: 200),
          ),
          ['a'],
          reportFailure: true,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('reportFailure: true 여도 성공하면 정상 결과', () async {
      final r = await run(_FakeRepo(store: _approved), [], reportFailure: true);
      expect(r.hasViolations, isFalse);
    });
  });
}
