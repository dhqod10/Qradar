import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/checkout_validation_remote_data_source.dart';
import 'package:qradar/data/repositories/checkout_validation_repository_impl.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';
import 'package:qradar/domain/usecases/apply_repriced_cart_use_case.dart';
import 'package:qradar/domain/usecases/validate_checkout_use_case.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';

// ── DI ────────────────────────────────────────────────────────────────────────

final checkoutValidationRemoteDataSourceProvider =
    Provider<CheckoutValidationRemoteDataSource>(
      (ref) => CheckoutValidationRemoteDataSource(),
    );

final checkoutValidationRepositoryProvider =
    Provider<CheckoutValidationRepository>(
      (ref) => CheckoutValidationRepositoryImpl(
        ref.watch(checkoutValidationRemoteDataSourceProvider),
      ),
    );

/// 자동 선검증 3초, 사용자가 직접 누른 동작(`다시 확인` · 거절 화면의 `최신 가격으로 다시 담기`) 5초 (design Q-D3).
final validateCheckoutUseCaseProvider = Provider<ValidateCheckoutUseCase>(
  (ref) => ValidateCheckoutUseCase(
    ref.watch(checkoutValidationRepositoryProvider),
    timeout: const Duration(seconds: 3),
    userTimeout: const Duration(seconds: 5),
  ),
);

final applyRepricedCartUseCaseProvider = Provider<ApplyRepricedCartUseCase>(
  (ref) => ApplyRepricedCartUseCase(ref.watch(cartRepositoryProvider)),
);

// ── 서버가 직전 결제에서 지목한 메뉴 (design D6) ─────────────────────────────────

/// 서버 게이트가 지목한 `menuItemId`. **메모리 전용** (앱 재시작 시 소거).
///
/// 소거 시점 (design §9.2): 카트 비우기 · 해당 줄 삭제(= 카트에서 사라진 id 가공 — 카트 변화 때 가지치기) ·
/// 새 결제 시도 시작([clear]) · `다시 확인` 에서 신선 읽기가 정상([retainOnly]) · 앱 재시작.
class PaymentRejectedMenuIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // 카트에서 사라진 메뉴(줄 삭제 · 카트 비우기 · 결제 성공 후 비우기)는 지목 기록에서도 지운다.
    ref.listen(cartProvider, (_, next) {
      final cart = next.value;
      if (state.isEmpty) return;
      if (cart == null) {
        state = const {};
        return;
      }
      final inCart = {for (final i in cart.items) i.menuItemId};
      final kept = state.where(inCart.contains).toSet();
      if (kept.length != state.length) state = kept;
    });
    return const {};
  }

  void addAll(Iterable<String> ids) {
    if (ids.isEmpty) return;
    state = {...state, ...ids};
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }

  /// [keep] 에 든 id 만 남긴다 (신선 읽기에서 위반이 아니었던 id 를 지운다).
  void retainOnly(Set<String> keep) {
    final kept = state.where(keep.contains).toSet();
    if (kept.length != state.length) state = kept;
  }
}

final paymentRejectedMenuIdsProvider =
    NotifierProvider<PaymentRejectedMenuIdsNotifier, Set<String>>(
      PaymentRejectedMenuIdsNotifier.new,
    );

/// 서버가 `OPTION_UNAVAILABLE` 로 지목한 `menuItemId` (payment_price_authority design §4.3 / §5.5). 소거 규칙은 위와 같다.
/// 카트 행이 "옵션이 바뀐 메뉴" 라고 말하는 폴백 캡션(클라이언트가 옵션을 특정하지 못했을 때)에 쓰인다.
class PaymentOptionRejectedMenuIdsNotifier
    extends PaymentRejectedMenuIdsNotifier {}

final paymentOptionRejectedMenuIdsProvider =
    NotifierProvider<PaymentOptionRejectedMenuIdsNotifier, Set<String>>(
      PaymentOptionRejectedMenuIdsNotifier.new,
    );

// ── 재가격으로 바뀐 카트 가격 (payment_price_authority design §5) ─────────────────

/// 재가격이 **카트에 적용한** 가격 변동 1건의 표시용 기록. 금액은 [ApplyRepricedCartUseCase] 가 계산한 값이다.
class CartPriceChangesState {
  const CartPriceChangesState({this.byCartItemId = const {}});

  /// cartItemId → 변동. 사용자가 `확인했어요` 를 누르기 전까지 같은 라인의 변동은 **처음 이전 단가**를 유지한다.
  final Map<String, CartLinePriceChange> byCartItemId;

  bool get isEmpty => byCartItemId.isEmpty;
}

/// 메모리 전용 (앱 재시작 시 소거). 소거 시점 (design §5.2): `확인했어요` · 카트 비우기 · 해당 라인 삭제(그 라인 몫만) ·
/// 결제 성공(카트 비움). **수량을 바꿔도 소거하지 않는다** — 가격 변동은 단가의 사실이다.
///
/// "변동 없음" 은 상태가 비어 있는 것과 같고, 확인 실패와 화면에서 구분되지 않는다 (design P5·N1 — 통과 표시 금지).
class CartPriceChangesNotifier extends Notifier<CartPriceChangesState> {
  @override
  CartPriceChangesState build() {
    ref.listen(cartProvider, (_, next) {
      if (state.isEmpty) return;
      final cart = next.value;
      if (cart == null) {
        state = const CartPriceChangesState();
        return;
      }
      final inCart = {for (final i in cart.items) i.cartItemId};
      final kept = {
        for (final e in state.byCartItemId.entries)
          if (inCart.contains(e.key)) e.key: e.value,
      };
      if (kept.length == state.byCartItemId.length) return;
      state = kept.isEmpty
          ? const CartPriceChangesState()
          : CartPriceChangesState(byCartItemId: kept);
    });
    return const CartPriceChangesState();
  }

  void record(RepricedCartApplied applied) {
    if (!applied.hasChanges) return;
    final merged = {...state.byCartItemId};
    for (final c in applied.changes) {
      final prev = merged[c.cartItemId];
      merged[c.cartItemId] = prev == null
          ? c
          : CartLinePriceChange(
              cartItemId: c.cartItemId,
              menuItemId: c.menuItemId,
              menuItemName: c.menuItemName,
              beforeUnitPrice: prev.beforeUnitPrice,
              afterUnitPrice: c.afterUnitPrice,
            );
    }
    state = CartPriceChangesState(byCartItemId: merged);
  }

  /// `확인했어요` — 사용자가 읽었다는 표시이지 가격이 검증됐다는 표시가 아니다.
  void acknowledge() {
    if (!state.isEmpty) state = const CartPriceChangesState();
  }
}

final cartPriceChangesProvider =
    NotifierProvider<CartPriceChangesNotifier, CartPriceChangesState>(
      CartPriceChangesNotifier.new,
    );

/// 카트 구성 서명 — menuItemId + 수량 + 옵션 id 목록 (가격은 넣지 않는다). 같은 구성에서 가격 거절이 반복되는지 판별한다.
String cartSignature(CartEntity cart) {
  final parts = [
    for (final i in cart.items)
      '${i.menuItemId}|${i.quantity}|'
          '${(i.selectedOptions.map((o) => '${o.groupId}:${o.itemId}').toList()..sort()).join(',')}',
  ]..sort();
  return parts.join(';');
}

/// 거절 화면(design P2 루프 차단기)이 "이미 재가격을 한 번 적용했다" 를 아는 메모리 값. 앱 재시작 시 소거.
/// 값은 재가격을 **적용한 뒤의** 카트 서명이다. 같은 서명으로 `PRICE_MISMATCH` 가 또 오면 재가격 버튼을 다시 주지 않는다.
class PriceRepricedCartSignatureNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void mark(String signature) => state = signature;
}

final priceRepricedCartSignatureProvider =
    NotifierProvider<PriceRepricedCartSignatureNotifier, String?>(
      PriceRepricedCartSignatureNotifier.new,
    );

// ── 카트 화면의 선검증 결과 ──────────────────────────────────────────────────────

/// 카트 화면이 마지막으로 **직접 읽어서 확인한** 위반. 어느 매장에 대한 결과인지 함께 보관한다.
class CartValidationState {
  const CartValidationState({
    this.storeId,
    this.validation = CheckoutValidation.none,
  });

  final String? storeId;
  final CheckoutValidation validation;
}

/// 호출 시점: 카트 진입 1회 · 앱 포그라운드 복귀 · `결제하기` 탭 · `다시 확인`.
/// 카트 스트림 변화마다 호출하지 않는다 (읽기 폭증). 자동 호출(`reportFailure: false`)의 실패는 무음이다.
class CartValidationNotifier extends Notifier<CartValidationState> {
  @override
  CartValidationState build() => const CartValidationState();

  /// 다른 화면(체크아웃 차단 시트)이 이미 직접 읽어서 확인한 결과를 카트 화면에 반영한다.
  void applyKnown(String storeId, CheckoutValidation validation) {
    state = CartValidationState(storeId: storeId, validation: validation);
  }

  /// 신선 선검증 + 재가격 적용. 반환값은 이번 호출의 결과다 (`결제하기` 탭 가로채기가 사용).
  /// [reportFailure] 가 true 일 때만 읽기 실패를 예외로 던진다 (design N3). 실패하면 아무것도 적용하지 않는다.
  Future<CartRefreshResult> refreshAndReprice({
    bool reportFailure = false,
  }) async {
    final cart = ref.read(cartProvider).value;
    if (cart == null || cart.items.isEmpty) {
      state = const CartValidationState();
      return const CartRefreshResult(CheckoutValidation.none);
    }
    final result = await ref
        .read(validateCheckoutUseCaseProvider)
        .call(
          storeId: cart.storeId,
          menuItemIds: cart.items.map((i) => i.menuItemId),
          cartItems: cart.items,
          reportFailure: reportFailure,
        );
    if (!ref.mounted) return CartRefreshResult(result);
    // 가격 변동은 카트에 적용하고 표시한다 (design §5.0). 읽기 실패는 위에서 none 이므로 아무것도 적용되지 않는다.
    final applied = await ref
        .read(applyRepricedCartUseCaseProvider)
        .call(result.repricing);
    if (!ref.mounted) return CartRefreshResult(result, applied: applied);
    ref.read(cartPriceChangesProvider.notifier).record(applied);
    state = CartValidationState(storeId: cart.storeId, validation: result);
    if (reportFailure && result.store == null) {
      // 이번 메뉴 읽기가 성공이다 → 위반이 아니었던 메뉴의 서버 지목 플래그를 지운다 (design D6).
      ref
          .read(paymentRejectedMenuIdsProvider.notifier)
          .retainOnly(result.violatedMenuItemIds);
      ref
          .read(paymentOptionRejectedMenuIdsProvider.notifier)
          .retainOnly(result.optionViolatedMenuItemIds);
    }
    return CartRefreshResult(result, applied: applied);
  }

  /// [refreshAndReprice] 의 검증 결과만 돌려주는 형태 (기존 호출부 호환).
  Future<CheckoutValidation> refresh({bool reportFailure = false}) async =>
      (await refreshAndReprice(reportFailure: reportFailure)).validation;
}

/// 선검증 1회의 결과: 위반 + 실제로 카트에 **새로** 적용된 가격 변동.
class CartRefreshResult {
  const CartRefreshResult(
    this.validation, {
    this.applied = RepricedCartApplied.none,
  });

  final CheckoutValidation validation;
  final RepricedCartApplied applied;
}

final cartValidationProvider =
    NotifierProvider.autoDispose<CartValidationNotifier, CartValidationState>(
      CartValidationNotifier.new,
    );
