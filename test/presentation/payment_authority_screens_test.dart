import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/verify_payment_failure.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/payment_failure.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_availability_banner.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_line_tile.dart';
import 'package:qradar/presentation/customer/checkout/payment_result_page.dart';
import 'package:qradar/presentation/customer/checkout/widgets/checkout_blocked_sheet.dart';

CartItemEntity _line(String cartItemId, String menuItemId, String name) =>
    CartItemEntity(
      cartItemId: cartItemId,
      menuItemId: menuItemId,
      menuItemName: name,
      quantity: 1,
      unitPriceWithOptions: 4000,
      lineTotal: 4000,
    );

CartEntity _cart(List<CartItemEntity> items) => CartEntity(
  storeId: 's1',
  storeName: '테스트 매장',
  items: items,
  subtotal: items.fold(0, (a, b) => a + b.lineTotal),
);

PaymentFailure _gate(String token) => PaymentFailure.from(
  VerifyPaymentFailure(code: 'failed-precondition', message: '서버 원문 문장 $token'),
);

Future<ProviderContainer> _pumpFail(
  WidgetTester tester,
  PaymentFailure failure, {
  CartEntity? cart,
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cartProvider.overrideWith((ref) => Stream.value(cart))],
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
  // 카트 스트림이 값을 내보내도록 provider 를 구독시킨다.
  container.listen(cartProvider, (_, _) {});
  container.listen(paymentRejectedMenuIdsProvider, (_, _) {});
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('결제 실패 화면 갈래 B — 메뉴 이름은 카트에서 온다', () {
    testWidgets('이름이 카트 menuItemName 으로 그려지고, 중복은 1회, 미해석 id 는 출력되지 않는다', (
      tester,
    ) async {
      final cart = _cart([
        _line('c1', 'm1', '아메리카노'),
        _line('c2', 'm1', '아메리카노'), // 옵션이 달라 두 줄
        _line('c3', 'm2', '카페라떼'),
      ]);
      await _pumpFail(
        tester,
        _gate('[MENU_SOLD_OUT:m1,m2,ghost-id,m1]'),
        cart: cart,
      );

      expect(find.text('품절된 메뉴가 있어요'), findsOneWidget);
      expect(find.text('아래 메뉴를 카트에서 빼고 다시 결제해 주세요.'), findsOneWidget);
      expect(find.text('아메리카노'), findsOneWidget);
      expect(find.text('카페라떼'), findsOneWidget);
      expect(find.text('지금 품절인 메뉴'), findsOneWidget);
      // 서버 원문·미해석 id 는 화면 어디에도 없다.
      expect(find.textContaining('ghost-id'), findsNothing);
      expect(find.textContaining('서버 원문'), findsNothing);
      expect(find.textContaining('MENU_SOLD_OUT'), findsNothing);
      // 돈 줄 (갈래 B)
      expect(find.text('아직 결제되지 않았고, 요금도 청구되지 않았어요'), findsOneWidget);
    });

    testWidgets('전부 해석 실패하면 목록 카드 없이 이름 없는 문구', (tester) async {
      await _pumpFail(
        tester,
        _gate('[MENU_SOLD_OUT:ghost1,ghost2]'),
        cart: _cart([_line('c1', 'm1', '아메리카노')]),
      );
      expect(find.text('품절된 메뉴가 있어요. 카트에서 확인해 주세요.'), findsOneWidget);
      expect(find.text('지금 품절인 메뉴'), findsNothing);
      expect(find.text('아메리카노'), findsNothing);
      expect(find.text('카트에서 확인하기'), findsOneWidget);
    });

    testWidgets('카트가 비어 있어도 갈래 B 로 그려진다', (tester) async {
      await _pumpFail(tester, _gate('[MENU_EXCLUDED:m1]'));
      expect(find.text('판매가 중단된 메뉴가 있어요'), findsOneWidget);
      expect(find.text('판매가 중단된 메뉴'), findsNothing);
    });

    testWidgets('MENU_* 의 `카트에서 확인하기` 는 pop 직전에 지목한 id 를 기록한다', (tester) async {
      final container = await _pumpFail(
        tester,
        _gate('[MENU_SOLD_OUT:m1]'),
        cart: _cart([_line('c1', 'm1', '아메리카노'), _line('c2', 'm2', '카페라떼')]),
      );
      await tester.tap(find.text('카트에서 확인하기'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget); // pop 됨
      expect(container.read(paymentRejectedMenuIdsProvider), {'m1'});
    });

    testWidgets('STORE_NOT_SELLABLE 은 목록 카드가 없고 다른 매장 둘러보기가 홈 탭으로 보낸다', (
      tester,
    ) async {
      final container = await _pumpFail(
        tester,
        _gate('[STORE_NOT_SELLABLE]'),
        cart: _cart([_line('c1', 'm1', '아메리카노')]),
      );
      expect(find.text('지금은 이 매장에서 주문할 수 없어요'), findsOneWidget);
      expect(find.text('카트로 돌아가기'), findsOneWidget);
      container.read(selectedTabIndexProvider.notifier).set(3);
      await tester.tap(find.text('다른 매장 둘러보기'));
      await tester.pumpAndSettle();
      expect(container.read(selectedTabIndexProvider), 0);
      expect(container.read(paymentRejectedMenuIdsProvider), isEmpty);
    });
  });

  group('갈래 A / C 는 원문을 그리지 않는다', () {
    testWidgets('갈래 A 기본 문구 + 형식 통과한 코드만 캡션', (tester) async {
      await _pumpFail(
        tester,
        PaymentFailure.launch(errorCode: 'SOME_NEW_TOSS_CODE'),
      );
      expect(find.text('결제를 완료하지 못했어요. 다른 결제수단으로 다시 시도해 주세요'), findsOneWidget);
      expect(find.text('오류 코드: SOME_NEW_TOSS_CODE'), findsOneWidget);
      expect(find.textContaining('코드:'), findsOneWidget);
    });

    testWidgets('갈래 A 알려진 코드는 매핑 문구, 캡션 없음', (tester) async {
      await _pumpFail(
        tester,
        PaymentFailure.launch(errorCode: 'NOT_ENOUGH_BALANCE'),
      );
      expect(find.text('잔액이 부족합니다'), findsOneWidget);
      expect(find.textContaining('오류 코드'), findsNothing);
    });

    testWidgets('갈래 C: Log 에서 확인하기가 주 버튼, `요금`/`청구` 가 화면에 없다', (tester) async {
      final container = await _pumpFail(
        tester,
        PaymentFailure.from(
          VerifyPaymentFailure(
            code: 'unavailable',
            message: 'Unable to resolve host evil.example',
          ),
        ),
      );
      expect(find.text('주문이 완료됐는지 확인이 필요해요'), findsOneWidget);
      expect(find.text('Log 에서 확인하기'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
      expect(find.textContaining('evil.example'), findsNothing);

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(texts.contains('요금'), isFalse);
      expect(texts.contains('청구'), isFalse);

      await tester.tap(find.text('Log 에서 확인하기'));
      await tester.pumpAndSettle();
      expect(container.read(selectedTabIndexProvider), 3);
    });
  });

  group('카트 행 / 배너', () {
    Future<void> pumpTile(
      WidgetTester tester,
      CartLineAvailability a, {
      VoidCallback? onRemove,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartLineTile(
              item: _line('c1', 'm1', '아메리카노'),
              availability: a,
              onQuantityChanged: (_) {},
              onRemove: onRemove ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('normal 은 캡션도 빼기 버튼도 없다', (tester) async {
      await pumpTile(tester, CartLineAvailability.normal);
      expect(find.text('빼기'), findsNothing);
      expect(find.text('품절'), findsNothing);
    });

    testWidgets('soldOut: 품절 덮개 + 캡션 + 빼기', (tester) async {
      var removed = 0;
      await pumpTile(
        tester,
        CartLineAvailability.soldOut,
        onRemove: () => removed++,
      );
      expect(find.text('품절'), findsOneWidget);
      expect(find.text('지금은 품절이에요'), findsOneWidget);
      await tester.tap(find.text('빼기'));
      expect(removed, 1);
    });

    testWidgets('unavailable: 덮개만(품절 글자 없음) + 캡션', (tester) async {
      await pumpTile(tester, CartLineAvailability.unavailable);
      expect(find.text('품절'), findsNothing);
      expect(find.text('이 매장에서 더 이상 판매하지 않아요'), findsOneWidget);
      expect(find.text('빼기'), findsOneWidget);
    });

    testWidgets('rejectedByServer: 덮개 없음 + 경고 캡션 + 빼기', (tester) async {
      await pumpTile(tester, CartLineAvailability.rejectedByServer);
      expect(find.text('품절'), findsNothing);
      expect(find.text('직전 결제에서 확인된 메뉴예요. 지금은 바뀌었을 수 있어요'), findsOneWidget);
      expect(find.text('빼기'), findsOneWidget);
    });

    test('resolve: 직접 읽은 위반이 서버 지목보다 우선, 통과/모름은 normal', () {
      const v = CheckoutValidation(
        menus: [
          MenuViolation(menuItemId: 'a', kind: MenuViolationKind.soldOut),
          MenuViolation(menuItemId: 'b', kind: MenuViolationKind.unavailable),
        ],
      );
      CartLineAvailability r(
        String id, {
        Set<String> rej = const {},
        CheckoutValidation val = v,
      }) => resolveCartLineAvailability(
        menuItemId: id,
        validation: val,
        rejectedMenuItemIds: rej,
      );
      expect(r('a', rej: {'a'}), CartLineAvailability.soldOut);
      expect(r('b'), CartLineAvailability.unavailable);
      expect(r('c', rej: {'c'}), CartLineAvailability.rejectedByServer);
      expect(r('c'), CartLineAvailability.normal);
      expect(r('a', val: CheckoutValidation.none), CartLineAvailability.normal);
    });

    test('배너 변형: 매장 > 품절·중단 > 서버 지목만 > 없음', () {
      CartBannerVariant? b(
        List<CartLineAvailability> l, [
        CheckoutValidation v = CheckoutValidation.none,
      ]) => resolveCartBannerVariant(lines: l, validation: v);
      expect(b([CartLineAvailability.normal]), isNull);
      expect(
        b([CartLineAvailability.rejectedByServer]),
        CartBannerVariant.serverRejectedOnly,
      );
      expect(
        b([
          CartLineAvailability.rejectedByServer,
          CartLineAvailability.soldOut,
        ]),
        CartBannerVariant.unavailableMenus,
      );
      expect(
        b([
          CartLineAvailability.soldOut,
        ], const CheckoutValidation(store: StoreViolation.notSellable)),
        CartBannerVariant.storeUnavailable,
      );
      expect(
        b([
          CartLineAvailability.normal,
        ], const CheckoutValidation(store: StoreViolation.temporarilyClosed)),
        CartBannerVariant.storeTemporarilyClosed,
      );
      expect(
        b([
          CartLineAvailability.normal,
        ], const CheckoutValidation(store: StoreViolation.closedSchedule)),
        CartBannerVariant.storeClosedSchedule,
      );
    });

    testWidgets('배너: 제목/본문 + 다시 확인 탭 중 스피너, 끝나면 버튼 복귀', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartAvailabilityBanner(
              variant: CartBannerVariant.unavailableMenus,
              onRecheck: () => completer.future,
            ),
          ),
        ),
      );
      expect(find.text('결제하려면 확인이 필요한 메뉴가 있어요'), findsOneWidget);
      await tester.tap(find.text('다시 확인'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('다시 확인'), findsNothing);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('다시 확인'), findsOneWidget);
    });
  });

  group('체크아웃 차단 시트', () {
    Future<CheckoutBlockedChoice?> open(
      WidgetTester tester, {
      required List<String> names,
      bool store = false,
      required Future<void> Function() act,
    }) async {
      CheckoutBlockedChoice? result;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCheckoutBlockedSheet(
                    context,
                    names: names,
                    storeBlocked: store,
                  );
                  done = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      expect(done, isTrue);
      return result;
    }

    testWidgets('메뉴 2개: 목록 카드 + `이 메뉴 모두 빼기` -> removeMenus', (tester) async {
      final r = await open(
        tester,
        names: ['아메리카노', '카페라떼'],
        act: () async {
          expect(find.text('결제하기 전에 확인이 필요해요'), findsOneWidget);
          expect(find.text('빼야 하는 메뉴'), findsOneWidget);
          expect(find.text('아메리카노'), findsOneWidget);
          expect(find.text('카페라떼'), findsOneWidget);
          await tester.tap(find.text('이 메뉴 모두 빼기'));
        },
      );
      expect(r, CheckoutBlockedChoice.removeMenus);
    });

    testWidgets('메뉴 1개는 `이 메뉴 빼기`, 보조 버튼은 backToCart', (tester) async {
      final r = await open(
        tester,
        names: ['아메리카노'],
        act: () async {
          expect(find.text('이 메뉴 빼기'), findsOneWidget);
          await tester.tap(find.text('카트에서 확인하기'));
        },
      );
      expect(r, CheckoutBlockedChoice.backToCart);
    });

    testWidgets('매장 변형: 목록 카드·보조 버튼 없음', (tester) async {
      final r = await open(
        tester,
        names: const [],
        store: true,
        act: () async {
          expect(find.text('지금은 이 매장에서 주문할 수 없어요'), findsOneWidget);
          expect(find.text('카트에서 확인하기'), findsNothing);
          expect(find.text('빼야 하는 메뉴'), findsNothing);
          await tester.tap(find.text('카트로 돌아가기'));
        },
      );
      expect(r, CheckoutBlockedChoice.backToCart);
    });
  });

  group('paymentRejectedMenuIdsProvider 소거', () {
    test('카트에서 사라진 id 는 가지치기, 카트 비우기는 전부 소거, clear/retainOnly', () async {
      final ctrl = StreamController<CartEntity?>();
      final container = ProviderContainer(
        overrides: [cartProvider.overrideWith((ref) => ctrl.stream)],
      );
      addTearDown(() {
        container.dispose();
        ctrl.close();
      });
      container.listen(cartProvider, (_, _) {});
      container.listen(paymentRejectedMenuIdsProvider, (_, _) {});
      final n = container.read(paymentRejectedMenuIdsProvider.notifier);

      ctrl.add(_cart([_line('c1', 'm1', 'A'), _line('c2', 'm2', 'B')]));
      await Future<void>.delayed(Duration.zero);
      n.addAll({'m1', 'm2'});
      expect(container.read(paymentRejectedMenuIdsProvider), {'m1', 'm2'});

      ctrl.add(_cart([_line('c2', 'm2', 'B')])); // m1 줄 삭제
      await Future<void>.delayed(Duration.zero);
      expect(container.read(paymentRejectedMenuIdsProvider), {'m2'});

      n.addAll({'m2', 'x'});
      n.retainOnly({'x'}); // 다시 확인 정상: 위반 아닌 id 소거
      expect(container.read(paymentRejectedMenuIdsProvider), {'x'});

      n.addAll({'m2'});
      ctrl.add(null); // 카트 비우기
      await Future<void>.delayed(Duration.zero);
      expect(container.read(paymentRejectedMenuIdsProvider), isEmpty);

      n.addAll({'q'});
      n.clear(); // 새 결제 시도 시작
      expect(container.read(paymentRejectedMenuIdsProvider), isEmpty);
    });
  });
}
