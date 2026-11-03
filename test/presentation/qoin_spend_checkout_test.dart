import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_spend_calculator.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';
import 'package:qradar/domain/usecases/check_client_update_required_use_case.dart';
import 'package:qradar/domain/usecases/launch_payment_use_case.dart';
import 'package:qradar/domain/usecases/verify_and_create_order_use_case.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/presentation/customer/checkout/checkout_page.dart';
import 'package:qradar/presentation/customer/checkout/providers/client_update_providers.dart';
import 'package:qradar/presentation/customer/checkout/widgets/qoin_spend_section.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';

/// qoin_spend design §1~§5 — 체크아웃 Qoin 사용 섹션. 가장 중요한 것은 **Q=0/숨김이면 화면·금액이 이전과 같다** (회귀 0).
class _Repo implements CheckoutValidationRepository {
  _Repo(this.price);
  final int price;

  @override
  Future<StoreSellabilityInput?> fetchStoreFresh(String storeId) async =>
      const StoreSellabilityInput(rawStatus: 'approved', hasApprovedAt: true);

  @override
  Future<Map<String, CheckoutMenuDocs>> fetchMenuDocsFresh({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  }) async => {
    for (final id in menuItemIds)
      id: CheckoutMenuDocs(
        storeMenu: MenuItemEntity(
          id: id,
          storeId: 's1',
          name: 'm',
          mainCategoryCode: 'coffee',
          basePrice: price,
        ),
      ),
  };

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async => {};
}

class _Cfg implements AppConfigRepository {
  @override
  Future<int?> fetchMinClientLevel() async => null;
}

class _SpyLaunch implements LaunchPaymentUseCase {
  int calls = 0;
  int? amount;

  @override
  Future<PaymentLaunchResult> call({
    required BuildContext context,
    required PaymentMethod method,
    required String idempotencyKey,
    required int amount,
    required String orderName,
    required String customerEmail,
    required String customerName,
  }) async {
    calls++;
    this.amount = amount;
    return PaymentLaunchResult(
      success: true,
      paymentKey: 'pk',
      orderId: idempotencyKey,
      amount: amount,
    );
  }
}

class _SpyVerify implements VerifyAndCreateOrderUseCase {
  int calls = 0;
  int? amount;
  int? qoinToUse;
  int? cartSubtotal;

  @override
  Future<OrderEntity> call({
    required String paymentKey,
    required String orderId,
    required int amount,
    required CartEntity cartSnapshot,
    required String uid,
    required PaymentMethod paymentMethod,
    int qoinToUse = 0,
  }) async {
    calls++;
    this.amount = amount;
    this.qoinToUse = qoinToUse;
    cartSubtotal = cartSnapshot.subtotal;
    throw StateError('테스트: 주문 생성 대신 실패로 끝낸다');
  }
}

const _policyOn = QoinSpendPolicy(enabled: true, minUnit: 1, minCashFloor: 300);

CartItemEntity _line({int unit = 4000, int qty = 2}) => CartItemEntity(
  cartItemId: 'c1',
  menuItemId: 'm1',
  menuItemName: '메뉴 m1',
  quantity: qty,
  unitPriceWithOptions: unit,
  lineTotal: unit * qty,
);

Future<(_SpyLaunch, _SpyVerify)> _pump(
  WidgetTester tester, {
  required int balance,
  QoinConfigEntity? config,
  bool configError = false,
  int unit = 4000,
  int qty = 2,
}) async {
  final launch = _SpyLaunch();
  final verify = _SpyVerify();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checkoutValidationRepositoryProvider.overrideWithValue(_Repo(unit)),
        launchPaymentUseCaseProvider.overrideWithValue(launch),
        verifyAndCreateOrderUseCaseProvider.overrideWithValue(verify),
        checkClientUpdateRequiredUseCaseProvider.overrideWithValue(
          CheckClientUpdateRequiredUseCase(_Cfg()),
        ),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserEntity(
              uid: 'u1',
              provider: 'google',
              email: 'a@b.c',
              displayName: '고객',
              phone: '01012345678',
              qoinBalance: balance,
            ),
          ),
        ),
        qoinConfigProvider.overrideWith(
          (ref) => configError
              ? Stream<QoinConfigEntity?>.error(StateError('offline'))
              : Stream.value(
                  config ??
                      const QoinConfigEntity(
                        enabled: true,
                        spendPolicy: _policyOn,
                      ),
                ),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
                  ),
                  child: const Text('go'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  container.read(cartLocalDataSourceProvider).addItem(
    storeId: 's1',
    storeName: '매장',
    item: _line(unit: unit, qty: qty),
  );
  container.listen(currentUserProfileProvider, (_, _) {});
  container.listen(cartProvider, (_, _) {});
  container.listen(qoinConfigProvider, (_, _) {});
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return (launch, verify);
}

Future<void> _agreeAndPickCard(WidgetTester tester) async {
  await tester.ensureVisible(find.text(PaymentMethod.card.label));
  await tester.tap(find.text(PaymentMethod.card.label));
  await tester.ensureVisible(find.byType(Checkbox).first);
  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
}

Finder get _input => find.byType(TextField);

void main() {
  group('숨김 = 이전 화면과 동일 (회귀 0)', () {
    testWidgets('사용 중지(spendEnabled=false 상당): 섹션도 헤더도 없고 PriceSummary 에 Qoin 행이 없다', (tester) async {
      await _pump(
        tester,
        balance: 5000,
        config: const QoinConfigEntity(enabled: true), // spendPolicy 기본 = disabled
      );
      expect(find.text('Qoin 사용'), findsNothing);
      expect(find.byType(QoinSpendSection), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('8,000원 결제하기'), findsOneWidget);
    });

    testWidgets('정책 로드 실패: 섹션 숨김 + 기존 결제(사용 0) 폴백, 에러 노출 없음', (tester) async {
      final (launch, verify) = await _pump(tester, balance: 5000, configError: true);
      expect(find.text('Qoin 사용'), findsNothing);
      await _agreeAndPickCard(tester);
      await tester.tap(find.text('8,000원 결제하기'));
      await tester.pumpAndSettle();
      expect(launch.amount, 8000);
      expect(verify.qoinToUse, 0);
    });

    testWidgets('Q 를 쓰지 않으면 결제도 이전과 같다: Toss 금액 = 소계, qoinToUse = 0', (tester) async {
      final (launch, verify) = await _pump(tester, balance: 5000);
      expect(find.text('Qoin 사용'), findsOneWidget); // 섹션은 보이지만
      await _agreeAndPickCard(tester);
      await tester.tap(find.text('8,000원 결제하기'));
      await tester.pumpAndSettle();
      expect(launch.amount, 8000);
      expect(verify.qoinToUse, 0);
      expect(verify.amount, 8000);
      expect(verify.cartSubtotal, 8000);
    });
  });

  group('비활성 카드 (S1~S3)', () {
    testWidgets('S1 잔액 0: 안내 문구, 입력 없음', (tester) async {
      await _pump(tester, balance: 0);
      expect(find.text('Qoin 사용'), findsOneWidget);
      expect(find.text('0 Q'), findsOneWidget);
      expect(find.text('적립하면 결제에 쓸 수 있어요'), findsOneWidget);
      expect(_input, findsNothing);
    });

    testWidgets('S2 음수 잔액: 부호 보존 + 쓸 수 없다는 안내', (tester) async {
      await _pump(tester, balance: -120);
      expect(find.text('-120 Q'), findsOneWidget);
      expect(find.text('Qoin 잔액이 부족해 지금은 쓸 수 없어요'), findsOneWidget);
      expect(_input, findsNothing);
    });

    testWidgets('S3 주문이 작음(소계 ≤ 최소현금): 최소현금 안내', (tester) async {
      await _pump(tester, balance: 5000, unit: 300, qty: 1);
      expect(
        find.text('이 주문은 최소 300원을 결제해야 해서 Qoin을 쓸 수 없어요'),
        findsOneWidget,
      );
      expect(_input, findsNothing);
    });
  });

  group('활성', () {
    testWidgets('최소현금이 한도: 최대 7,700 Q + 최소현금 안내 줄', (tester) async {
      await _pump(tester, balance: 12300);
      expect(find.text('12,300 Q'), findsOneWidget);
      expect(find.text('최대 7,700 Q까지 쓸 수 있어요'), findsOneWidget);
      expect(find.text('최소 300원은 선택한 결제수단으로 결제돼요'), findsOneWidget);
      expect(find.text('최대 사용'), findsOneWidget);
    });

    testWidgets('잔액이 한도: 두 번째 정책 줄 없음 (불필요한 정책 문구 금지)', (tester) async {
      await _pump(tester, balance: 1200);
      expect(find.text('최대 1,200 Q까지 쓸 수 있어요'), findsOneWidget);
      expect(find.textContaining('선택한 결제수단'), findsNothing);
    });

    testWidgets('700 입력: 결제 예정 금액·요약 Qoin 행·CTA 금액이 실시간으로 바뀐다 (+ 적립 안내)', (tester) async {
      await _pump(tester, balance: 12300);
      await tester.enterText(_input, '700');
      await tester.pump();
      expect(find.text('7,300원 결제하기'), findsOneWidget);
      expect(find.text('8,000원 결제하기'), findsNothing);
      expect(find.text('결제 예정 금액'), findsOneWidget);
      expect(find.text('Qoin 사용분을 뺀 결제액 기준으로 적립돼요'), findsOneWidget);
      await tester.ensureVisible(find.text('-700원'));
      expect(find.text('-700원'), findsOneWidget);
      expect(find.text('Qoin 사용'), findsNWidgets(2)); // 섹션 헤더 + 요약 행
    });

    testWidgets('한도 초과 입력(전액 시도 포함)은 한도로 자동 클램프 + 최소현금 경고, 결제 버튼은 활성 유지', (tester) async {
      await _pump(tester, balance: 12300);
      await tester.enterText(_input, '8000');
      await tester.pump();
      expect(
        tester.widget<TextField>(_input).controller!.text,
        '7700',
      );
      expect(
        find.text('최소 300원은 결제해야 해서 최대 7,700 Q까지 적용했어요'),
        findsOneWidget,
      );
      expect(find.text('300원 결제하기'), findsOneWidget);
      // 3초 뒤 기본 문구로 복귀
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('최대 7,700 Q까지 쓸 수 있어요'), findsOneWidget);
    });

    testWidgets('잔액 초과 입력: 잔액 기준 경고', (tester) async {
      await _pump(tester, balance: 1200);
      await tester.enterText(_input, '5000');
      await tester.pump();
      expect(tester.widget<TextField>(_input).controller!.text, '1200');
      expect(
        find.text('보유한 Qoin은 1,200 Q예요. 최대 1,200 Q까지 적용했어요'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('최대 사용 ↔ 사용 취소 토글', (tester) async {
      await _pump(tester, balance: 12300);
      await tester.tap(find.text('최대 사용'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_input).controller!.text, '7700');
      expect(find.text('사용 취소'), findsOneWidget);
      expect(find.text('300원 결제하기'), findsOneWidget);
      await tester.tap(find.text('사용 취소'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_input).controller!.text, '');
      expect(find.text('최대 사용'), findsOneWidget);
      expect(find.text('8,000원 결제하기'), findsOneWidget);
    });

    testWidgets('선행 0 은 제거된다', (tester) async {
      await _pump(tester, balance: 12300);
      await tester.enterText(_input, '007');
      await tester.pump();
      expect(tester.widget<TextField>(_input).controller!.text, '7');
    });
  });

  group('결제 요청', () {
    testWidgets('Q=700: Toss 승인 요청액 = 소계 − 700, 서버 요청에 qoinToUse=700 (표시용 클램프와 별개로 서버가 최종 판정)', (tester) async {
      final (launch, verify) = await _pump(tester, balance: 12300);
      await tester.enterText(_input, '700');
      await tester.pump();
      await _agreeAndPickCard(tester);
      await tester.tap(find.text('7,300원 결제하기'));
      await tester.pumpAndSettle();
      expect(launch.amount, 7300);
      expect(verify.calls, 1);
      expect(verify.amount, 7300);
      expect(verify.qoinToUse, 700);
      expect(verify.cartSubtotal, 8000, reason: 'cart 스냅샷의 소계는 원본 (서버가 재계산)');
    });
  });
}
