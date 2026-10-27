import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_item_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/domain/entities/selected_option.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';
import 'package:qradar/domain/usecases/launch_payment_use_case.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';
import 'package:qradar/domain/usecases/check_client_update_required_use_case.dart';
import 'package:qradar/presentation/customer/checkout/checkout_page.dart';
import 'package:qradar/presentation/customer/checkout/providers/client_update_providers.dart';
import 'package:qradar/presentation/customer/checkout/update_required_page.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';

/// payment_price_authority R9 · design §5.4 — 체크아웃 결제 탭의 재가격. 결제(Toss 창)는 가격 변동·옵션 위반이면 시작하지 않는다.
class _Repo implements CheckoutValidationRepository {
  _Repo({
    required this.price,
    this.menu,
    this.groups = const {},
    this.fail = false,
  });
  int price;
  final MenuItemEntity? menu;
  final Map<String, OptionGroupEntity?> groups;
  bool fail;

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
    if (fail) throw StateError('offline');
    return {
      for (final id in menuItemIds)
        id: CheckoutMenuDocs(
          storeMenu:
              (menu ??
                      const MenuItemEntity(
                        id: 'm1',
                        storeId: 's1',
                        name: 'm',
                        mainCategoryCode: 'coffee',
                        basePrice: 0,
                      ))
                  .copyWith(id: id, basePrice: price),
        ),
    };
  }

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async => {
    for (final r in refs)
      optionRefKey(r.scope, r.id): groups[optionRefKey(r.scope, r.id)],
  };
}

class _Cfg implements AppConfigRepository {
  _Cfg({this.min, this.fail = false});
  final int? min;
  final bool fail;
  @override
  Future<int?> fetchMinClientLevel() async {
    if (fail) throw StateError('offline');
    return min;
  }
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
    return const PaymentLaunchResult(success: false, cancelled: true);
  }
}

CartItemEntity _line(
  String id,
  String menu, {
  int unit = 4000,
  int qty = 1,
  List<SelectedOption> opts = const [],
}) => CartItemEntity(
  cartItemId: id,
  menuItemId: menu,
  menuItemName: '메뉴 $menu',
  quantity: qty,
  selectedOptions: opts,
  unitPriceWithOptions: unit,
  lineTotal: unit * qty,
);

Future<(ProviderContainer, _Repo, _SpyLaunch)> _pump(
  WidgetTester tester, {
  required _Repo repo,
  List<CartItemEntity>? lines,
  AppConfigRepository? cfg,
}) async {
  final spy = _SpyLaunch();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checkoutValidationRepositoryProvider.overrideWithValue(repo),
        launchPaymentUseCaseProvider.overrideWithValue(spy),
        checkClientUpdateRequiredUseCaseProvider.overrideWithValue(
          CheckClientUpdateRequiredUseCase(cfg ?? _Cfg()),
        ),
        currentUserProfileProvider.overrideWith(
          (ref) => Stream.value(
            const UserEntity(
              uid: 'u1',
              provider: 'google',
              email: 'a@b.c',
              displayName: '고객',
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
                    MaterialPageRoute<void>(
                      builder: (_) => const CheckoutPage(),
                    ),
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
  final ds = container.read(cartLocalDataSourceProvider);
  for (final l in lines ?? [_line('c1', 'm1', unit: 4000, qty: 2)]) {
    ds.addItem(storeId: 's1', storeName: '매장', item: l);
  }
  container.listen(currentUserProfileProvider, (_, _) {});
  container.listen(cartProvider, (_, _) {});
  container.listen(cartPriceChangesProvider, (_, _) {});
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  // 결제 수단 + 약관 동의 → 결제 가능 상태.
  await tester.tap(find.text(PaymentMethod.card.label));
  await tester.tap(find.byType(Checkbox).first); // 전체 동의
  await tester.pumpAndSettle();
  return (container, repo, spy);
}

Future<void> _pay(WidgetTester tester, String amountLabel) async {
  await tester.tap(find.text('$amountLabel 결제하기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '가격이 올랐다: 카트를 먼저 새 금액으로 맞춘 뒤 시트를 띄우고, Toss 결제창은 열지 않는다 (자동 결제 없음)',
    (tester) async {
      final (container, _, spy) = await _pump(tester, repo: _Repo(price: 4500));
      await _pay(tester, '8,000원');

      expect(spy.calls, 0, reason: '결제창을 열지 않는다 — 금액이 바뀐 채로 결제하게 하지 않는다');
      expect(find.text('결제 금액이 바뀌었어요'), findsOneWidget);
      expect(
        find.text('메뉴 가격이 바뀌어 금액을 새로 맞췄어요. 결제는 아직 시작되지 않았어요.'),
        findsOneWidget,
      );
      expect(find.text('가격이 바뀐 메뉴'), findsOneWidget);
      // 적용은 시트가 뜨기 전에 끝나 있다 (밀어 닫아도 stale 상태가 남지 않는다).
      expect(
        container.read(cartLocalDataSourceProvider).current!.subtotal,
        9000,
      );
      expect(container.read(cartPriceChangesProvider).isEmpty, isFalse);

      // 시트를 밀어 닫는다 → 체크아웃에 머물고, 합계·버튼이 새 금액이다.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.text('9,000원 결제하기'), findsOneWidget);
      expect(spy.calls, 0);
    },
  );

  testWidgets('새 금액으로 계속하기: 체크아웃에 머문다. 다시 탭해야 결제가 시작된다 (고객의 동의)', (
    tester,
  ) async {
    final (_, _, spy) = await _pump(tester, repo: _Repo(price: 4500));
    await _pay(tester, '8,000원');
    await tester.tap(find.text('새 금액으로 계속하기'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(spy.calls, 0);

    await _pay(tester, '9,000원');
    expect(spy.calls, 1, reason: '변동이 이미 적용돼 있으므로 두 번째 탭은 통과한다');
    expect(spy.amount, 9000, reason: '새 금액으로 결제창을 연다');
  });

  testWidgets('카트에서 확인하기: 체크아웃을 닫고 카트로 보낸다', (tester) async {
    final (_, _, spy) = await _pump(tester, repo: _Repo(price: 4500));
    await _pay(tester, '8,000원');
    await tester.tap(find.text('카트에서 확인하기'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsNothing);
    expect(find.text('go'), findsOneWidget);
    expect(spy.calls, 0);
  });

  testWidgets('가격이 내렸다: 같은 규칙으로 알리고 멈춘다 (고객에게 이득이어도 조용히 바뀌지 않는다)', (
    tester,
  ) async {
    final (container, _, spy) = await _pump(tester, repo: _Repo(price: 3500));
    await _pay(tester, '8,000원');
    expect(find.text('결제 금액이 바뀌었어요'), findsOneWidget);
    expect(container.read(cartLocalDataSourceProvider).current!.subtotal, 7000);
    expect(spy.calls, 0);
  });

  testWidgets('가격 변동 없음: 바로 결제창 (시트 없음, 통과 표시 없음)', (tester) async {
    final (_, _, spy) = await _pump(tester, repo: _Repo(price: 4000));
    await _pay(tester, '8,000원');
    expect(spy.calls, 1);
    expect(find.text('결제 금액이 바뀌었어요'), findsNothing);
  });

  testWidgets('읽기 실패: 재가격하지 않고 결제를 진행한다 (선검증은 권위가 아니다 — 서버가 판정한다)', (
    tester,
  ) async {
    final (container, _, spy) = await _pump(
      tester,
      repo: _Repo(price: 4500, fail: true),
    );
    await _pay(tester, '8,000원');
    expect(spy.calls, 1);
    expect(container.read(cartLocalDataSourceProvider).current!.subtotal, 8000);
  });

  testWidgets('옵션 위반: 옵션 시트 (가격 변동보다 우선), 결제창을 열지 않는다', (tester) async {
    const ref = OptionGroupRef(scope: OptionScope.store, id: 'g1');
    final repo = _Repo(
      price: 4500, // 가격도 바뀌었지만 옵션 위반이 우선이다
      menu: const MenuItemEntity(
        id: 'm1',
        storeId: 's1',
        name: 'm',
        mainCategoryCode: 'coffee',
        basePrice: 0,
        optionGroupRefs: [ref],
        disabledOptionItemIds: ['g1_shot'],
      ),
      groups: {
        optionRefKey(OptionScope.store, 'g1'): const OptionGroupEntity(
          id: 'g1',
          scope: OptionScope.store,
          name: 'g1',
          selectionType: OptionSelectionType.single,
          items: [OptionItemEntity(id: 'shot', label: '샷', priceDelta: 500)],
        ),
      },
    );
    final (_, _, spy) = await _pump(
      tester,
      repo: repo,
      lines: [
        _line(
          'c1',
          'm1',
          unit: 4500,
          opts: const [
            SelectedOption(
              groupId: 'g1',
              groupName: 'g1',
              itemId: 'shot',
              label: '샷',
              priceDelta: 500,
            ),
          ],
        ),
      ],
    );
    await _pay(tester, '4,500원');
    expect(find.text('옵션을 다시 골라야 해요'), findsOneWidget);
    expect(find.text('결제 금액이 바뀌었어요'), findsNothing);
    expect(find.text('옵션을 다시 골라야 하는 메뉴'), findsOneWidget);
    expect(spy.calls, 0);
  });

  testWidgets('H-01: 구버전으로 확인되면 결제창도 선검증도 열지 않고 업데이트 화면', (tester) async {
    final (_, _, spy) = await _pump(tester, repo: _Repo(price: 4000), cfg: _Cfg(min: 2));
    await _pay(tester, '8,000원');
    expect(find.byType(UpdateRequiredPage), findsOneWidget);
    expect(spy.calls, 0);
  });

  testWidgets('H-01: 버전 확인 실패는 막지 않는다 — 결제창이 열린다', (tester) async {
    final (_, _, spy) = await _pump(tester, repo: _Repo(price: 4000), cfg: _Cfg(fail: true));
    await _pay(tester, '8,000원');
    expect(find.byType(UpdateRequiredPage), findsNothing);
    expect(spy.calls, 1);
  });
}
