import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/option_availability.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/cart/cart_page.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';
import 'package:qradar/domain/usecases/check_client_update_required_use_case.dart';
import 'package:qradar/presentation/customer/checkout/checkout_page.dart';
import 'package:qradar/presentation/customer/checkout/providers/client_update_providers.dart';
import 'package:qradar/presentation/customer/checkout/update_required_page.dart';

/// payment_price_authority R9 — 카트 화면의 재가격: 진입 시 자동 적용 + 배너, `결제하기` 탭은 새 변동이면 멈춘다 (design §5.0·§5.3).
class _Repo implements CheckoutValidationRepository {
  _Repo(this.prices, {this.fail = false});
  final Map<String, int> prices;
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
          storeMenu: MenuItemEntity(
            id: id,
            storeId: storeId,
            name: id,
            mainCategoryCode: 'coffee',
            basePrice: prices[id] ?? 4000,
          ),
        ),
    };
  }

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async => {for (final r in refs) optionRefKey(r.scope, r.id): null};
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

class _Auth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(uid: 'u1', provider: 'google');
}

CartItemEntity _line(String id, String menu, {int unit = 4000, int qty = 1}) =>
    CartItemEntity(
      cartItemId: id,
      menuItemId: menu,
      menuItemName: '메뉴 $menu',
      quantity: qty,
      unitPriceWithOptions: unit,
      lineTotal: unit * qty,
    );

Future<(ProviderContainer, _Repo)> _pump(
  WidgetTester tester, {
  AppConfigRepository? cfg,
  required Map<String, int> prices,
  bool fail = false,
  List<CartItemEntity>? lines,
}) async {
  final repo = _Repo(prices, fail: fail);
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checkoutValidationRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith(_Auth.new),
        checkClientUpdateRequiredUseCaseProvider.overrideWithValue(
          CheckClientUpdateRequiredUseCase(cfg ?? _Cfg()),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const CartPage();
          },
        ),
      ),
    ),
  );
  await container.read(authProvider.future); // 로그인 세션이 확정된 뒤에만 결제하기가 통과한다
  final ds = container.read(cartLocalDataSourceProvider);
  for (final l in lines ?? [_line('c1', 'm1', unit: 4000, qty: 2)]) {
    ds.addItem(storeId: 's1', storeName: '매장', item: l);
  }
  await tester.pumpAndSettle();
  return (container, repo);
}

void main() {
  testWidgets('카트 진입: 문서 가격이 올랐으면 자동으로 카트에 적용하고 배너 + 라인 표시를 보인다 (결제로 넘어가지 않는다)', (
    tester,
  ) async {
    final (container, _) = await _pump(tester, prices: {'m1': 4500});
    // 카트에 이미 담겨 있던 라인이 있었다고 가정 — addItem 후 자동 선검증은 initState 시점이므로 한 번 더 확인을 시킨다.
    await container.read(cartValidationProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(
      container
          .read(cartLocalDataSourceProvider)
          .current!
          .items
          .single
          .unitPriceWithOptions,
      4500,
    );
    expect(find.text('메뉴 가격이 올라 카트 금액을 새로 맞췄어요'), findsOneWidget);
    expect(find.text('가격이 올랐어요'), findsOneWidget);
    expect(find.text('8,000원'), findsWidgets, reason: '이전 합계/이전 라인 금액 (취소선)');
    expect(find.text('9,000원'), findsWidgets);
    expect(find.byType(CheckoutPage), findsNothing);

    // 확인했어요 → 배너와 라인 표시가 아무 문구도 남기지 않고 사라진다 (확인됨 표시 금지).
    await tester.tap(find.text('확인했어요'));
    await tester.pumpAndSettle();
    expect(find.text('메뉴 가격이 올라 카트 금액을 새로 맞췄어요'), findsNothing);
    expect(find.text('가격이 올랐어요'), findsNothing);
    expect(find.textContaining('확인됨'), findsNothing);
    expect(find.textContaining('최신'), findsNothing);
  });

  testWidgets('결제하기 탭에서 새 변동이 발견되면 체크아웃으로 가지 않고 카트에서 멈춘다 — 두 번째 탭이 동의다', (
    tester,
  ) async {
    final (container, repo) = await _pump(tester, prices: {'m1': 4000});
    expect(find.text('가격이 올랐어요'), findsNothing, reason: '진입 시점엔 같은 가격');

    // 그 사이 점주가 가격을 올렸다.
    repo.prices['m1'] = 4500;
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(
      find.byType(CheckoutPage),
      findsNothing,
      reason: '금액이 바뀐 채로 결제 화면에 들어가지 않는다',
    );
    expect(find.text('메뉴 가격이 올라 카트 금액을 새로 맞췄어요'), findsOneWidget);
    expect(container.read(cartLocalDataSourceProvider).current!.subtotal, 9000);

    // 두 번째 탭: 새 변동이 없으므로 체크아웃으로 진행한다.
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsOneWidget);
  });

  testWidgets('내림도 같은 규칙으로 멈춘다 (오름·내림·섞임 하나의 규칙, Q-D1) — info 톤 제목', (
    tester,
  ) async {
    final (_, repo) = await _pump(tester, prices: {'m1': 4000});
    repo.prices['m1'] = 3500;
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsNothing);
    expect(find.text('메뉴 가격이 내려 카트 금액을 새로 맞췄어요'), findsOneWidget);
    expect(find.text('가격이 내려갔어요'), findsOneWidget);
  });

  testWidgets('읽기 실패: 아무것도 적용하지 않고, 표시도 없고, 결제를 막지 않는다 (선검증은 권위가 아니다)', (
    tester,
  ) async {
    final (container, _) = await _pump(
      tester,
      prices: {'m1': 4500},
      fail: true,
    );
    expect(find.text('메뉴 가격이 올라 카트 금액을 새로 맞췄어요'), findsNothing);
    expect(find.text('가격이 올랐어요'), findsNothing);
    expect(
      container.read(cartLocalDataSourceProvider).current!.subtotal,
      8000,
      reason: '카트 불변',
    );
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(
      find.byType(CheckoutPage),
      findsOneWidget,
      reason: '확인하지 못했으면 서버가 판정한다',
    );
  });

  testWidgets('같은 가격이면 어떤 가격 표시도 없다 (통과를 암시하는 요소 금지)', (tester) async {
    await _pump(tester, prices: {'m1': 4000});
    expect(find.textContaining('가격이'), findsNothing);
    expect(find.textContaining('확인했어요'), findsNothing);
  });

  testWidgets('빠른 재주문처럼 옛 단가로 담긴 라인도 카트 진입 시 현재 가격으로 교정되고 배너가 알린다', (
    tester,
  ) async {
    final (container, _) = await _pump(
      tester,
      prices: {'m1': 5000},
      lines: [_line('c1', 'm1', unit: 4000, qty: 1)],
    );
    await container.read(cartValidationProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(
      container
          .read(cartLocalDataSourceProvider)
          .current!
          .items
          .single
          .unitPriceWithOptions,
      5000,
    );
    expect(find.text('메뉴 가격이 올라 카트 금액을 새로 맞췄어요'), findsOneWidget);
  });

  testWidgets('H-01: 서버가 요구한 최소 수준 미만으로 확인되면 결제하기가 업데이트 화면으로 간다 (체크아웃 아님)', (tester) async {
    await _pump(tester, prices: {'m1': 4000}, cfg: _Cfg(min: 2));
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredPage), findsOneWidget);
    expect(find.text('앱을 업데이트해 주세요'), findsOneWidget);
    expect(find.byType(CheckoutPage), findsNothing);
    expect(find.textContaining('조작'), findsNothing);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredPage), findsNothing);
  });

  testWidgets('H-01: 버전 확인이 실패해도 결제를 막지 않는다 (fail-open)', (tester) async {
    await _pump(tester, prices: {'m1': 4000}, cfg: _Cfg(fail: true));
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateRequiredPage), findsNothing);
    expect(find.byType(CheckoutPage), findsOneWidget);
  });

  testWidgets('H-01: 설정이 없거나 충분한 수준이면 막지 않는다', (tester) async {
    await _pump(tester, prices: {'m1': 4000}, cfg: _Cfg(min: 1));
    await tester.tap(find.text('결제하기'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsOneWidget);
  });
}
