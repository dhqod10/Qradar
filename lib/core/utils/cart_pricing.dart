// 카트 금액 산술 (payment_price_authority spec §4-2, R7).
//
// **순수 산술이다.** 승인 규칙(`priceOverride` 를 적용할지)은 판정하지 않는다 — 그것은 `applyOverrideForCustomer` 가
// 이미 결정한 `basePrice` 로 들어온다. 그래서 `applyOverrideForCustomer` 와 갈라질 분기가 없다.
//
// 서버 `functions/src/cartPricing.ts` 가 같은 식의 포팅이며 `test_fixtures/cart_pricing_contract.json` 으로 양방향 고정된다.
// `priceDelta` 를 **합산**하는 코드는 Dart 에서 이 파일 1곳뿐이다 (grep 가드).
//
// 식:
//   line(i)      = basePrice(i) + Σ priceDelta
//   lineTotal(i) = line(i) × quantity(i)
//   subtotal     = Σ lineTotal
//   expected     = subtotal − discount        (discount 는 항상 0 — spec §1-3)

/// 한 라인의 수량 상한. 앱 `QuantityStepper` 의 1~99 이자 **서버 `MAX_LINE_QUANTITY`(cartPricing.ts) 와 같은 값**이다 —
/// 둘이 갈라지면 앱이 만든 정상 카트를 서버가 `PRICE_MISMATCH` 로 거절한다 (test_report F-01).
/// `test_fixtures/cart_pricing_contract.json` 의 `quantityCases` / `mergeCases` 가 양쪽을 같은 파일로 고정한다.
const int kMaxLineQuantity = 99;

/// 수량이 유효한가: 1 이상 [kMaxLineQuantity] 이하의 **정수**. 서버 `isValidLineQuantity` 와 같은 경계.
bool isValidLineQuantity(num quantity) =>
    quantity == quantity.truncate() &&
    quantity >= 1 &&
    quantity <= kMaxLineQuantity;

/// 같은 (메뉴, 옵션) 라인에 수량을 더할 때의 결과. 상한을 넘기지 않는다 — 넘기면 서버가 거절하는 카트가 만들어진다.
int mergeLineQuantity(int existing, int added) {
  final sum = existing + added;
  return sum > kMaxLineQuantity ? kMaxLineQuantity : sum;
}

/// 라인 단가 = 기준가 + 선택 옵션 가격 증감의 합. 음수 증감이 정상이다 (텀블러 −300).
int computeLinePrice({
  required int basePrice,
  required Iterable<int> priceDeltas,
}) {
  var unit = basePrice;
  for (final d in priceDeltas) {
    unit += d;
  }
  return unit;
}

/// 라인 합계 = 단가 × 수량.
int computeLineTotal({required int unitPrice, required int quantity}) =>
    unitPrice * quantity;

/// 라인 합계의 합 = 소계.
int sumLineTotals(Iterable<int> lineTotals) {
  var total = 0;
  for (final t in lineTotals) {
    total += t;
  }
  return total;
}

class CartPricingLine {
  const CartPricingLine({
    required this.basePrice,
    required this.priceDeltas,
    required this.quantity,
  });

  final int basePrice;
  final List<int> priceDeltas;
  final int quantity;
}

class CartLinePricing {
  const CartLinePricing({required this.unitPrice, required this.lineTotal});

  final int unitPrice;
  final int lineTotal;
}

class CartAmount {
  const CartAmount({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.expected,
  });

  final List<CartLinePricing> lines;
  final int subtotal;

  /// 항상 0 (할인이 들어가는 경로가 없다 — spec §1-3).
  final int discount;

  /// 결제해야 하는 금액 = subtotal − discount.
  final int expected;
}

/// 카트 전체 금액. 입력 순서와 같은 순서로 [CartAmount.lines] 를 돌려준다.
CartAmount computeCartAmount(List<CartPricingLine> lines) {
  final priced = <CartLinePricing>[
    for (final l in lines)
      () {
        final unit = computeLinePrice(
          basePrice: l.basePrice,
          priceDeltas: l.priceDeltas,
        );
        return CartLinePricing(
          unitPrice: unit,
          lineTotal: computeLineTotal(unitPrice: unit, quantity: l.quantity),
        );
      }(),
  ];
  final subtotal = sumLineTotals(priced.map((p) => p.lineTotal));
  const discount = 0;
  return CartAmount(
    lines: priced,
    subtotal: subtotal,
    discount: discount,
    expected: subtotal - discount,
  );
}
