import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/repositories/cart_repository.dart';

/// 재가격으로 단가가 달라진 라인 1건의 적용 결과 (카트 가격 변동 표시용). 금액은 **저장소가 계산한** 값이다.
class CartLinePriceChange {
  const CartLinePriceChange({
    required this.cartItemId,
    required this.menuItemId,
    required this.menuItemName,
    required this.beforeUnitPrice,
    required this.afterUnitPrice,
  });

  final String cartItemId;
  final String menuItemId;
  final String menuItemName;
  final int beforeUnitPrice;
  final int afterUnitPrice;

  bool get isIncrease => afterUnitPrice > beforeUnitPrice;
}

/// [ApplyRepricedCartUseCase] 결과: 실제로 바뀐 라인과 적용 전후 카트 소계.
class RepricedCartApplied {
  const RepricedCartApplied({
    this.changes = const [],
    this.subtotalBefore = 0,
    this.subtotalAfter = 0,
  });

  static const RepricedCartApplied none = RepricedCartApplied();

  final List<CartLinePriceChange> changes;
  final int subtotalBefore;
  final int subtotalAfter;

  bool get hasChanges => changes.isNotEmpty;
}

/// 선검증이 계산한 재가격 결과를 로컬 카트에 **적용**한다 (payment_price_authority R9, design P1).
///
/// presentation 은 금액을 계산하지 않는다 — 이 UseCase 가 [CartRepository.applyUnitPrices] 로 단가만 넘기고,
/// 합계는 저장소가 `cart_pricing.dart` 의 같은 식으로 다시 만든다. 이미 새 단가인 라인은 "바뀐 라인" 으로 세지 않는다
/// (두 번째 호출은 변동 0 — "새로 발견된 변동" 판별이 여기서 자연히 나온다).
class ApplyRepricedCartUseCase {
  ApplyRepricedCartUseCase(this._cart);

  final CartRepository _cart;

  Future<RepricedCartApplied> call(CartRepricing repricing) async {
    if (repricing.priceChanges.isEmpty) return RepricedCartApplied.none;
    final before = await _cart.getActiveCart();
    if (before == null) return RepricedCartApplied.none;

    final changes = <CartLinePriceChange>[];
    final toApply = <String, int>{};
    for (final r in repricing.priceChanges) {
      final line = before.items
          .where((l) => l.cartItemId == r.cartItemId)
          .firstOrNull;
      if (line == null || line.unitPriceWithOptions == r.newUnitPrice) {
        continue;
      }
      toApply[line.cartItemId] = r.newUnitPrice;
      changes.add(
        CartLinePriceChange(
          cartItemId: line.cartItemId,
          menuItemId: line.menuItemId,
          menuItemName: line.menuItemName,
          beforeUnitPrice: line.unitPriceWithOptions,
          afterUnitPrice: r.newUnitPrice,
        ),
      );
    }
    if (toApply.isEmpty) return RepricedCartApplied.none;

    await _cart.applyUnitPrices(toApply);
    final after = await _cart.getActiveCart();
    return RepricedCartApplied(
      changes: List.unmodifiable(changes),
      subtotalBefore: before.subtotal,
      subtotalAfter: after?.subtotal ?? sumLineTotals(const []),
    );
  }
}
