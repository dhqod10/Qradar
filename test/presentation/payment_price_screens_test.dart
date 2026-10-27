import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/verify_payment_failure.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/payment_failure.dart';
import 'package:qradar/domain/entities/selected_option.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/usecases/apply_repriced_cart_use_case.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_line_tile.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_price_change_banner.dart';
import 'package:qradar/presentation/customer/checkout/payment_result_page.dart';
import 'package:qradar/presentation/customer/checkout/widgets/checkout_price_changed_sheet.dart';

/// payment_price_authority — 거절 화면(PRICE_MISMATCH · OPTION_UNAVAILABLE), 카트 가격 변동 UI, 체크아웃 시트.
/// 핵심은 무한 거절 루프(spec §7-2)의 탈출구가 실제로 동작하는가다.

class _FakeRepo implements CheckoutValidationRepository {
  _FakeRepo({this.menus = const {}, this.fail = false, this.delay});

  final Map<String, MenuItemEntity> menus;
  bool fail;
  Duration? delay;
  int menuCalls = 0;

  @override
  Future<StoreSellabilityInput?> fetchStoreFresh(String storeId) async {
    if (fail) throw StateError('offline');
    return const StoreSellabilityInput(
      rawStatus: 'approved',
      hasApprovedAt: true,
    );
  }

  @override
  Future<Map<String, CheckoutMenuDocs>> fetchMenuDocsFresh({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  }) async {
    menuCalls++;
    if (delay != null) await Future<void>.delayed(delay!);
    if (fail) throw StateError('offline');
    return {
      for (final id in menuItemIds) id: CheckoutMenuDocs(storeMenu: menus[id]),
    };
  }

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async => {for (final r in refs) optionRefKey(r.scope, r.id): null};
}

MenuItemEntity _menu(String id, int price) => MenuItemEntity(
  id: id,
  storeId: 's1',
  name: '메뉴 $id',
  mainCategoryCode: 'coffee',
  basePrice: price,
);

CartItemEntity _line(
  String cartItemId,
  String menuId,
  String name, {
  int unit = 4000,
  int qty = 1,
}) => CartItemEntity(
  cartItemId: cartItemId,
  menuItemId: menuId,
  menuItemName: name,
  quantity: qty,
  unitPriceWithOptions: unit,
  lineTotal: unit * qty,
);

PaymentFailure _gate(String token) => PaymentFailure.from(
  VerifyPaymentFailure(code: 'failed-precondition', message: '서버 원문 문장 $token'),
);

class _Harness {
  _Harness(this.container, this.repo);
  final ProviderContainer container;
  final _FakeRepo repo;
  CartEntity? get cart => container.read(cartLocalDataSourceProvider).current;
}

/// 거절 화면을 연다. 카트는 실제 in-memory 저장소로 시드한다 (재가격이 카트를 정말 바꾸는지 보기 위해).
Future<_Harness> _pumpFail(
  WidgetTester tester,
  PaymentFailure failure, {
  required List<CartItemEntity> cartLines,
  _FakeRepo? repo,
}) async {
  final fake = repo ?? _FakeRepo();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [checkoutValidationRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PaymentResultPage(
                        variant: PaymentResultVariant.fail,
                        failure: failure,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  final ds = container.read(cartLocalDataSourceProvider);
  for (final l in cartLines) {
    ds.addItem(storeId: 's1', storeName: '매장', item: l);
  }
  container.listen(cartProvider, (_, _) {});
  container.listen(paymentRejectedMenuIdsProvider, (_, _) {});
  container.listen(cartPriceChangesProvider, (_, _) {});
  container.listen(priceRepricedCartSignatureProvider, (_, _) {});
  container.listen(cartValidationProvider, (_, _) {});
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return _Harness(container, fake);
}

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

void main() {
  group('PRICE_MISMATCH 기본형 — 주 버튼은 실제로 복구하는 동작이다', () {
    testWidgets('문구·버튼·목록 카드, 그리고 금액 숫자가 어디에도 없다 (Q6=ⓒ)', (tester) async {
      await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1,ghost]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
      );
      expect(find.text('메뉴 가격이 바뀌었어요'), findsOneWidget);
      expect(find.text('아직 결제되지 않았고, 요금도 청구되지 않았어요'), findsOneWidget);
      expect(find.textContaining('최신 가격으로 다시 담으면'), findsOneWidget);
      expect(find.text('카트에 담은 메뉴와 수량은 그대로 남아요.'), findsOneWidget);
      expect(find.text('가격을 다시 확인할 메뉴'), findsOneWidget);
      expect(find.text('아메리카노'), findsOneWidget);
      expect(find.text('최신 가격으로 다시 담기'), findsOneWidget);
      expect(find.text('카트로 돌아가기'), findsOneWidget);
      expect(
        find.textContaining('ghost'),
        findsNothing,
        reason: '미해석 id 는 출력하지 않는다',
      );
      expect(find.textContaining('서버 원문'), findsNothing);
      expect(
        find.textContaining('오류 코드'),
        findsNothing,
        reason: '기본형에는 코드 캡션이 없다',
      );
      final all = _allText(tester);
      expect(
        RegExp(r'\d{1,3}(,\d{3})*원').hasMatch(all),
        isFalse,
        reason: '거절 화면에는 원 단위 숫자가 없다 — 숫자는 카트에서',
      );
      expect(RegExp(r'[`*_]').hasMatch(all.replaceAll('_', '')), isFalse);
    });

    testWidgets('id 없는 [PRICE_MISMATCH] (차이가 총액에만 있음): 목록 카드 없이도 본문이 성립한다', (
      tester,
    ) async {
      await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
      );
      expect(find.text('메뉴 가격이 바뀌었어요'), findsOneWidget);
      expect(find.text('가격을 다시 확인할 메뉴'), findsNothing);
      expect(find.text('최신 가격으로 다시 담기'), findsOneWidget);
    });

    testWidgets('주 버튼: 신선 읽기 → 카트가 실제로 최신 가격이 되고 → 카트로 pop. pop 단독이 아니다', (
      tester,
    ) async {
      final h = await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노', unit: 4000, qty: 2)],
        repo: _FakeRepo(menus: {'m1': _menu('m1', 4500)}),
      );
      expect(h.cart!.subtotal, 8000);
      await tester.tap(find.text('최신 가격으로 다시 담기'));
      await tester.pumpAndSettle();

      expect(h.repo.menuCalls, 1, reason: '재가격 UseCase 호출 1회');
      expect(find.text('open'), findsOneWidget, reason: '성공하면 카트로 돌아간다 (pop)');
      expect(h.cart!.items.single.unitPriceWithOptions, 4500);
      expect(h.cart!.items.single.lineTotal, 9000, reason: '수량 유지');
      expect(h.cart!.subtotal, 9000);
      // 카트가 가격 변동을 표시할 재료가 남는다 — 조용히 바뀌지 않는다.
      final ch = h.container.read(cartPriceChangesProvider).byCartItemId['c1']!;
      expect(ch.beforeUnitPrice, 4000);
      expect(ch.afterUnitPrice, 4500);
      expect(h.container.read(priceRepricedCartSignatureProvider), isNotNull);
    });

    testWidgets(
      '재가격 후 같은 구성에서 PRICE_MISMATCH 가 또 오면 처음부터 변형 N — 재가격 버튼을 다시 주지 않는다 (루프 차단)',
      (tester) async {
        final h = await _pumpFail(
          tester,
          _gate('[PRICE_MISMATCH:m1]'),
          cartLines: [_line('c1', 'm1', '아메리카노')],
          repo: _FakeRepo(menus: {'m1': _menu('m1', 4500)}),
        );
        await tester.tap(find.text('최신 가격으로 다시 담기'));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);

        // 같은 카트로 다시 결제 → 또 거절.
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(h.cart!.items.single.unitPriceWithOptions, 4500);
        // 위 push 는 같은 failure 객체(예: 서버가 한 번 더 거절)를 그린다.
        expect(find.text('가격을 다시 확인했는데 달라진 게 없어요'), findsOneWidget);
        expect(find.text('최신 가격으로 다시 담기'), findsNothing);
        expect(find.text('카트 비우고 메뉴 보러가기'), findsOneWidget);
      },
    );
  });

  group('PRICE_MISMATCH — 재가격이 실패하거나 소용없을 때', () {
    testWidgets('읽기 실패: 이 화면에 머문다. pop 없음, 카트 불변, 인라인 오류, 라벨 다시 불러오기', (
      tester,
    ) async {
      final h = await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
        repo: _FakeRepo(menus: {'m1': _menu('m1', 4500)}, fail: true),
      );
      await tester.tap(find.text('최신 가격으로 다시 담기'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsNothing, reason: 'pop 되지 않는다');
      expect(find.text('메뉴 가격이 바뀌었어요'), findsOneWidget);
      expect(
        find.text('최신 가격을 불러오지 못했어요. 네트워크를 확인하고 다시 눌러 주세요.'),
        findsOneWidget,
      );
      expect(find.text('다시 불러오기'), findsOneWidget);
      expect(find.text('최신 가격으로 다시 담기'), findsNothing);
      expect(
        h.cart!.items.single.unitPriceWithOptions,
        4000,
        reason: '아무것도 적용하지 않는다',
      );
      expect(h.container.read(cartPriceChangesProvider).isEmpty, isTrue);
      // 원시 예외 문자열은 노출하지 않는다.
      expect(find.textContaining('offline'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
      // 읽기에 실패해도 보조 버튼은 계속 활성이다 — 막다른 길이 아니다.
      expect(find.text('카트로 돌아가기'), findsOneWidget);
      // 연속 2회째에는 힌트 한 줄.
      expect(find.text('계속 안 되면 카트에서 메뉴를 빼고 다시 담아 보세요.'), findsNothing);
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('계속 안 되면 카트에서 메뉴를 빼고 다시 담아 보세요.'), findsOneWidget);
    });

    testWidgets('실패 뒤 네트워크가 돌아오면 같은 버튼으로 복구된다', (tester) async {
      final repo = _FakeRepo(menus: {'m1': _menu('m1', 4500)}, fail: true);
      final h = await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
        repo: repo,
      );
      await tester.tap(find.text('최신 가격으로 다시 담기'));
      await tester.pumpAndSettle();
      repo.fail = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(h.cart!.items.single.unitPriceWithOptions, 4500);
    });

    testWidgets('진행 중에는 버튼이 스피너로 바뀌고 보조 버튼이 비활성이다', (tester) async {
      final repo = _FakeRepo(
        menus: {'m1': _menu('m1', 4500)},
        delay: const Duration(seconds: 1),
      );
      await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
        repo: repo,
      );
      await tester.tap(find.text('최신 가격으로 다시 담기'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('가격을 다시 불러오는 중'), findsOneWidget);
      final secondary = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '카트로 돌아가기'),
      );
      expect(secondary.onPressed, isNull);
      await tester.pumpAndSettle();
    });

    testWidgets(
      '재가격해도 달라진 게 없으면 변형 N 으로 바뀐다: 재가격 버튼 없음 · 코드 캡션 · 카트 비우기가 탈출구',
      (tester) async {
        final h = await _pumpFail(
          tester,
          _gate('[PRICE_MISMATCH:m1]'),
          cartLines: [_line('c1', 'm1', '아메리카노')],
          repo: _FakeRepo(menus: {'m1': _menu('m1', 4000)}), // 카트와 같은 가격
        );
        await tester.tap(find.text('최신 가격으로 다시 담기'));
        await tester.pumpAndSettle();

        expect(
          find.text('open'),
          findsNothing,
          reason: '카트로 보내지 않는다 (바뀐 게 없다)',
        );
        expect(find.text('가격을 다시 확인했는데 달라진 게 없어요'), findsOneWidget);
        expect(
          find.text(
            '카트의 금액은 지금 가격과 같아요. 가격이 잠깐 바뀌었다가 돌아왔을 수 있어요. 카트로 돌아가 다시 결제해 보세요.',
          ),
          findsOneWidget,
        );
        expect(find.text('최신 가격으로 다시 담기'), findsNothing);
        expect(find.text('다시 불러오기'), findsNothing);
        expect(find.text('오류 코드: PRICE_MISMATCH'), findsOneWidget);
        expect(find.text('가격을 다시 확인할 메뉴'), findsNothing, reason: '지목할 것이 없다');
        expect(find.text('카트로 돌아가기'), findsOneWidget);
        expect(find.text('카트 비우고 메뉴 보러가기'), findsOneWidget);

        // 최후 탈출구: 카트를 비운다.
        await tester.tap(find.text('카트 비우고 메뉴 보러가기'));
        await tester.pumpAndSettle();
        expect(h.cart, isNull);
        expect(find.text('open'), findsOneWidget);
      },
    );

    testWidgets('변형 N 의 주 버튼 카트로 돌아가기는 pop', (tester) async {
      await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
        repo: _FakeRepo(menus: {'m1': _menu('m1', 4000)}),
      );
      await tester.tap(find.text('최신 가격으로 다시 담기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카트로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('재가격 결과 품절 등 다른 위반이 있으면 변형 N 이 아니라 카트로 보낸다 (카트가 바뀐다)', (
      tester,
    ) async {
      final h = await _pumpFail(
        tester,
        _gate('[PRICE_MISMATCH:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
        repo: _FakeRepo(
          menus: {'m1': _menu('m1', 4000).copyWith(soldOut: true)},
        ),
      );
      await tester.tap(find.text('최신 가격으로 다시 담기'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(
        h.container
            .read(cartValidationProvider)
            .validation
            .menus
            .single
            .menuItemId,
        'm1',
      );
    });
  });

  group('OPTION_UNAVAILABLE', () {
    testWidgets('메뉴 단위 지목, 주 버튼은 카트로(pop) + 옵션 사유 id 기록, 숫자 없음', (
      tester,
    ) async {
      final h = await _pumpFail(
        tester,
        _gate('[OPTION_UNAVAILABLE:m1]'),
        cartLines: [_line('c1', 'm1', '아메리카노'), _line('c2', 'm2', '카페라떼')],
      );
      expect(find.text('선택하신 옵션이 바뀌었어요'), findsOneWidget);
      expect(
        find.text(
          '아래 메뉴에서 고르신 옵션을 지금은 선택할 수 없어요. 카트에서 어떤 옵션인지 확인하고 다시 골라 주세요.',
        ),
        findsOneWidget,
      );
      expect(find.text('옵션을 다시 골라야 하는 메뉴'), findsOneWidget);
      expect(find.text('아메리카노'), findsOneWidget);
      expect(find.text('카페라떼'), findsNothing);
      expect(find.text('아직 결제되지 않았고, 요금도 청구되지 않았어요'), findsOneWidget);
      expect(RegExp(r'\d{1,3}(,\d{3})*원').hasMatch(_allText(tester)), isFalse);
      expect(find.text('닫기'), findsOneWidget);

      await tester.tap(find.text('카트에서 확인하기'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(h.container.read(paymentRejectedMenuIdsProvider), {'m1'});
      expect(h.container.read(paymentOptionRejectedMenuIdsProvider), {'m1'});
    });

    testWidgets('전부 해석 실패하면 목록 카드 없이 이름 없는 문구', (tester) async {
      await _pumpFail(
        tester,
        _gate('[OPTION_UNAVAILABLE:ghost]'),
        cartLines: [_line('c1', 'm1', '아메리카노')],
      );
      expect(find.text('선택하신 옵션이 바뀐 메뉴가 있어요. 카트에서 확인해 주세요.'), findsOneWidget);
      expect(find.text('옵션을 다시 골라야 하는 메뉴'), findsNothing);
    });
  });

  group('카트 행: 가격 변동 표시 (design §5.1)', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));
    CartLinePriceChange change(int before, int after) => CartLinePriceChange(
      cartItemId: 'c1',
      menuItemId: 'm1',
      menuItemName: '아메리카노',
      beforeUnitPrice: before,
      afterUnitPrice: after,
    );

    testWidgets('오름: 이전 금액 취소선 + 현재 금액 + warning 캡션 (수량 반영)', (tester) async {
      await tester.pumpWidget(
        host(
          CartLineTile(
            item: _line('c1', 'm1', '아메리카노', unit: 4500, qty: 2),
            priceChange: change(4000, 4500),
            onQuantityChanged: (_) {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.text('8,000원'), findsOneWidget, reason: '이전 4,000 × 2');
      expect(find.text('9,000원'), findsOneWidget);
      final before = tester.widget<Text>(find.text('8,000원'));
      expect(before.style!.decoration, TextDecoration.lineThrough);
      final cap = tester.widget<Text>(find.text('가격이 올랐어요'));
      expect(cap.style!.color, AppColors.warning);
    });

    testWidgets('내림: info 캡션이고 success(초록)를 쓰지 않는다 — 검증 통과로 읽히면 안 된다', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CartLineTile(
            item: _line('c1', 'm1', '아메리카노', unit: 3500),
            priceChange: change(4000, 3500),
            onQuantityChanged: (_) {},
            onRemove: () {},
          ),
        ),
      );
      final cap = tester.widget<Text>(find.text('가격이 내려갔어요'));
      expect(cap.style!.color, AppColors.info);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.style?.color, isNot(AppColors.success));
      }
    });

    testWidgets('변동 없음: 가격 표시도 캡션도 없다 (통과를 암시하는 요소 금지, N1)', (tester) async {
      await tester.pumpWidget(
        host(
          CartLineTile(
            item: _line('c1', 'm1', '아메리카노'),
            onQuantityChanged: (_) {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.textContaining('가격이'), findsNothing);
      expect(find.text('4,000원'), findsOneWidget);
    });

    testWidgets('품절·판매 중단 캡션이 가격 변동을 이긴다', (tester) async {
      await tester.pumpWidget(
        host(
          CartLineTile(
            item: _line('c1', 'm1', '아메리카노', unit: 4500),
            availability: CartLineAvailability.soldOut,
            priceChange: change(4000, 4500),
            onQuantityChanged: (_) {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.text('지금은 품절이에요'), findsOneWidget);
      expect(find.text('가격이 올랐어요'), findsNothing);
      expect(
        find.text('4,000원'),
        findsNothing,
        reason: '그 라인은 어차피 결제 불가라 금액이 의미 없다',
      );
    });
  });

  group('카트 행: 옵션 위반 (design §5.5, DQ5 — 옵션 라벨 단위)', () {
    testWidgets('선택할 수 없는 옵션 라벨만 error 색 + 취소선, 나머지는 기존 스타일', (tester) async {
      var reselected = 0;
      var removed = 0;
      final item = CartItemEntity(
        cartItemId: 'c1',
        menuItemId: 'm1',
        menuItemName: '아메리카노',
        quantity: 1,
        unitPriceWithOptions: 4500,
        lineTotal: 4500,
        selectedOptions: const [
          SelectedOption(
            groupId: 'g1',
            groupName: '온도',
            itemId: 'hot',
            label: 'HOT',
          ),
          SelectedOption(
            groupId: 'g2',
            groupName: '샷',
            itemId: 'shot',
            label: '샷 추가',
            priceDelta: 500,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartLineTile(
              item: item,
              availability: CartLineAvailability.optionUnavailable,
              unavailableOptionItemIds: const {'shot'},
              onReselectOptions: () => reselected++,
              onQuantityChanged: (_) {},
              onRemove: () => removed++,
            ),
          ),
        ),
      );
      expect(find.text('선택할 수 없는 옵션이 있어요'), findsOneWidget);
      final rich = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      final bad = spans.firstWhere((s) => s.text == '샷 추가');
      final ok = spans.firstWhere((s) => s.text == 'HOT');
      expect(bad.style!.color, AppColors.error);
      expect(bad.style!.decoration, TextDecoration.lineThrough);
      expect(ok.style, isNull);
      // 가격은 재계산하지 않고 담은 가격 그대로 (불가 옵션이 낀 라인은 유효한 가격이 없다).
      expect(find.text('4,500원'), findsOneWidget);

      await tester.tap(find.text('다시 고르기'));
      await tester.tap(find.text('빼기'));
      expect(reselected, 1);
      expect(removed, 1);
    });

    testWidgets(
      '서버만 옵션 사유로 지목한 행(rejectedByServer + serverRejectedOption): 폴백 캡션 + 다시 고르기',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CartLineTile(
                item: _line('c1', 'm1', '아메리카노'),
                availability: CartLineAvailability.rejectedByServer,
                serverRejectedOption: true,
                onReselectOptions: () {},
                onQuantityChanged: (_) {},
                onRemove: () {},
              ),
            ),
          ),
        );
        expect(
          find.text('직전 결제에서 옵션이 바뀐 메뉴예요. 지금은 다시 바뀌었을 수 있어요'),
          findsOneWidget,
        );
        expect(find.text('다시 고르기'), findsOneWidget);
      },
    );

    test('availability: 옵션 위반은 라인(cartItemId) 단위로 해석된다 · 메뉴 위반이 우선', () {
      final v = CheckoutValidation(
        repricing: CartRepricing(
          optionIssues: [
            LineOptionIssue(
              cartItemId: 'c2',
              menuItemId: 'm1',
              issue: const OptionIssue(
                groupId: 'g',
                kind: OptionIssueKind.missing,
              ),
            ),
          ],
        ),
      );
      CartLineAvailability a(String cartItemId) => resolveCartLineAvailability(
        menuItemId: 'm1',
        cartItemId: cartItemId,
        validation: v,
        rejectedMenuItemIds: const {},
      );
      expect(
        a('c1'),
        CartLineAvailability.normal,
        reason: '같은 메뉴라도 옵션이 다른 줄은 정상',
      );
      expect(a('c2'), CartLineAvailability.optionUnavailable);
      expect(
        resolveCartBannerVariant(lines: [a('c1'), a('c2')], validation: v),
        CartBannerVariant.optionUnavailable,
      );
    });
  });

  group('가격 변동 배너·요약', () {
    CartPriceChangesState st(Map<String, CartLinePriceChange> m) =>
        CartPriceChangesState(byCartItemId: m);
    CartLinePriceChange c(String id, int b, int a) => CartLinePriceChange(
      cartItemId: id,
      menuItemId: 'm',
      menuItemName: '이름',
      beforeUnitPrice: b,
      afterUnitPrice: a,
    );

    test('이전·현재 합계: 수량을 바꿔도, 라인을 지워도 현재 카트 기준으로 맞는다', () {
      final cart = CartEntity(
        storeId: 's1',
        storeName: '매장',
        items: [
          _line('c1', 'm1', 'a', unit: 4500, qty: 3), // 이전 4000 × 3
          _line('c2', 'm2', 'b', unit: 3000, qty: 1), // 변동 없음
        ],
        subtotal: 13500 + 3000,
      );
      final s = summarizePriceChanges(cart, st({'c1': c('c1', 4000, 4500)}))!;
      expect(s.beforeSubtotal, 12000 + 3000);
      expect(s.afterSubtotal, 16500);
      expect(s.hasIncrease, isTrue);
      expect(s.hasDecrease, isFalse);
    });

    test('변동이 카트에 남아 있지 않으면 요약이 없다 — 배너를 그리지 않는다', () {
      final cart = CartEntity(
        storeId: 's1',
        storeName: '매장',
        items: [_line('c2', 'm2', 'b')],
        subtotal: 4000,
      );
      expect(
        summarizePriceChanges(cart, st({'c1': c('c1', 4000, 4500)})),
        isNull,
      );
      expect(
        summarizePriceChanges(null, st({'c1': c('c1', 4000, 4500)})),
        isNull,
      );
      expect(
        summarizePriceChanges(cart, const CartPriceChangesState()),
        isNull,
      );
    });

    testWidgets('제목 3변형과 톤, 합계 이전→현재, 확인했어요 콜백', (tester) async {
      var acked = 0;
      Future<void> pumpBanner(CartPriceChangeSummary s) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartPriceChangeBanner(
              summary: s,
              onAcknowledge: () => acked++,
            ),
          ),
        ),
      );
      await pumpBanner(
        const CartPriceChangeSummary(
          beforeSubtotal: 4000,
          afterSubtotal: 4500,
          hasIncrease: true,
          hasDecrease: false,
        ),
      );
      expect(find.text('메뉴 가격이 올라 카트 금액을 새로 맞췄어요'), findsOneWidget);
      expect(
        find.text('바뀐 가격으로 카트를 다시 담았어요. 아래 금액을 확인하고 결제해 주세요.'),
        findsOneWidget,
      );
      expect(find.text('4,000원'), findsOneWidget);
      expect(find.text('4,500원'), findsOneWidget);
      expect(find.text('  →  '), findsOneWidget);

      await pumpBanner(
        const CartPriceChangeSummary(
          beforeSubtotal: 4000,
          afterSubtotal: 3500,
          hasIncrease: false,
          hasDecrease: true,
        ),
      );
      expect(find.text('메뉴 가격이 내려 카트 금액을 새로 맞췄어요'), findsOneWidget);
      final box = tester.widget<Container>(find.byType(Container).first);
      final deco = box.decoration! as BoxDecoration;
      expect(
        deco.color,
        AppColors.info.withValues(alpha: 0.08),
        reason: '내림은 info 톤',
      );

      await pumpBanner(
        const CartPriceChangeSummary(
          beforeSubtotal: 4000,
          afterSubtotal: 4100,
          hasIncrease: true,
          hasDecrease: true,
        ),
      );
      expect(find.text('메뉴 가격이 바뀌어 카트 금액을 새로 맞췄어요'), findsOneWidget);

      await tester.tap(find.text('확인했어요'));
      expect(acked, 1);
    });

    test(
      'CartPriceChangesNotifier: 확인 전 같은 라인의 변동은 처음 이전 단가를 유지, 라인 삭제는 그 몫만 소거, 카트가 비면 전부 소거',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(cartProvider, (_, _) {});
        container.listen(cartPriceChangesProvider, (_, _) {});
        final ds = container.read(cartLocalDataSourceProvider);
        ds.addItem(
          storeId: 's1',
          storeName: '매장',
          item: _line('c1', 'm1', 'a'),
        );
        ds.addItem(
          storeId: 's1',
          storeName: '매장',
          item: _line('c2', 'm2', 'b'),
        );
        await Future<void>.delayed(Duration.zero);
        final n = container.read(cartPriceChangesProvider.notifier);
        RepricedCartApplied ap(String id, int b, int a) => RepricedCartApplied(
          changes: [c(id, b, a)],
          subtotalBefore: 1,
          subtotalAfter: 2,
        );
        n.record(ap('c1', 4000, 4500));
        n.record(ap('c1', 4500, 5000)); // 확인 전에 또 올랐다
        n.record(ap('c2', 4000, 3000));
        var s = container.read(cartPriceChangesProvider).byCartItemId;
        expect(s['c1']!.beforeUnitPrice, 4000, reason: '고객이 처음 본 가격');
        expect(s['c1']!.afterUnitPrice, 5000);

        ds.removeItem('c1');
        await Future<void>.delayed(Duration.zero);
        s = container.read(cartPriceChangesProvider).byCartItemId;
        expect(s.keys, ['c2']);

        // 수량을 바꿔도 소거하지 않는다 (가격 변동은 단가의 사실).
        ds.updateQuantity(cartItemId: 'c2', quantity: 3);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(cartPriceChangesProvider).byCartItemId.keys, [
          'c2',
        ]);

        ds.clearCart();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(cartPriceChangesProvider).isEmpty, isTrue);
      },
    );

    test('acknowledge 는 사라질 뿐 어떤 상태도 남기지 않는다 (확인했어요 ≠ 검증됨)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(cartPriceChangesProvider, (_, _) {});
      final n = container.read(cartPriceChangesProvider.notifier);
      n.record(RepricedCartApplied(changes: [c('c1', 1, 2)]));
      expect(container.read(cartPriceChangesProvider).isEmpty, isFalse);
      n.acknowledge();
      expect(container.read(cartPriceChangesProvider).isEmpty, isTrue);
    });
  });

  group('체크아웃 시트 (design §5.4)', () {
    Future<CheckoutPriceSheetChoice?> openPrice(
      WidgetTester tester, {
      required Completer<CheckoutPriceSheetChoice?> out,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => out.complete(
                  await showCheckoutPriceChangedSheet(
                    context,
                    summary: const CartPriceChangeSummary(
                      beforeSubtotal: 8000,
                      afterSubtotal: 9000,
                      hasIncrease: true,
                      hasDecrease: false,
                    ),
                    rows: const [
                      PriceChangeRow(name: '아메리카노', before: 8000, after: 9000),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return null;
    }

    testWidgets('가격 변동 시트: 문구, 합계 이전→현재, 변동 목록, 그래도 이전 금액 결제 버튼은 없다', (
      tester,
    ) async {
      final out = Completer<CheckoutPriceSheetChoice?>();
      await openPrice(tester, out: out);
      expect(find.text('결제 금액이 바뀌었어요'), findsOneWidget);
      expect(
        find.text('메뉴 가격이 바뀌어 금액을 새로 맞췄어요. 결제는 아직 시작되지 않았어요.'),
        findsOneWidget,
      );
      expect(find.text('가격이 바뀐 메뉴'), findsOneWidget);
      expect(find.text('아메리카노'), findsOneWidget);
      expect(find.text('새 금액으로 계속하기'), findsOneWidget);
      expect(find.text('카트에서 확인하기'), findsOneWidget);
      expect(find.textContaining('이전 금액으로'), findsNothing);
      await tester.tap(find.text('새 금액으로 계속하기'));
      await tester.pumpAndSettle();
      expect(await out.future, CheckoutPriceSheetChoice.stay);
    });

    testWidgets('가격 변동 시트를 밀어 닫으면 null — 결제를 시작하는 선택이 아니다', (tester) async {
      final out = Completer<CheckoutPriceSheetChoice?>();
      await openPrice(tester, out: out);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await out.future, isNull);
    });

    testWidgets('옵션 위반 시트: 문구, 목록, 선택지 둘', (tester) async {
      final out = Completer<CheckoutOptionSheetChoice?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => out.complete(
                  await showCheckoutOptionSheet(
                    context,
                    names: const ['아메리카노', '라떼'],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('옵션을 다시 골라야 해요'), findsOneWidget);
      expect(find.text('옵션을 다시 골라야 하는 메뉴'), findsOneWidget);
      expect(find.text('카트에서 옵션 다시 고르기'), findsOneWidget);
      expect(find.text('이 메뉴 모두 빼기'), findsOneWidget, reason: '여러 개면 모두');
      await tester.tap(find.text('이 메뉴 모두 빼기'));
      await tester.pumpAndSettle();
      expect(await out.future, CheckoutOptionSheetChoice.removeMenus);
    });
  });
}
