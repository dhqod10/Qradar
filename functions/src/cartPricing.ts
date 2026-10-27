/**
 * 카트 금액 산술 — Dart `lib/core/utils/cart_pricing.dart` 의 **TS 포팅** (payment_price_authority spec §4-2, R7).
 *
 * 순수 산술이다. 승인 규칙(`priceOverride` 를 적용할지)은 판정하지 않는다 — `menuVisibility.ts` 가 이미 결정한 `basePrice` 가
 * 들어온다. 그래서 `applyOverrideForCustomer` 와 갈라질 분기가 없다. `test_fixtures/cart_pricing_contract.json` 이 고정한다.
 *
 *   line(i)      = basePrice(i) + Σ priceDelta
 *   lineTotal(i) = line(i) × quantity(i)
 *   subtotal     = Σ lineTotal
 *   expected     = subtotal − discount        (discount 는 항상 0 — spec §1-3)
 *
 * `priceDelta` 를 **합산**하는 TS 코드는 이 파일 1곳뿐이다 (grep 가드).
 */

export function computeLinePrice(args: { basePrice: number; priceDeltas: readonly number[] }): number {
  let unit = args.basePrice;
  for (const d of args.priceDeltas) unit += d;
  return unit;
}

export function computeLineTotal(args: { unitPrice: number; quantity: number }): number {
  return args.unitPrice * args.quantity;
}

export function sumLineTotals(lineTotals: readonly number[]): number {
  let total = 0;
  for (const t of lineTotals) total += t;
  return total;
}

export interface CartPricingLine {
  basePrice: number;
  priceDeltas: readonly number[];
  quantity: number;
}

export interface CartLinePricing {
  unitPrice: number;
  lineTotal: number;
}

export interface CartAmount {
  lines: CartLinePricing[];
  subtotal: number;
  /** 항상 0. */
  discount: number;
  /** 결제해야 하는 금액 = subtotal − discount. */
  expected: number;
}

export function computeCartAmount(lines: readonly CartPricingLine[]): CartAmount {
  const priced: CartLinePricing[] = lines.map((l) => {
    const unitPrice = computeLinePrice({ basePrice: l.basePrice, priceDeltas: l.priceDeltas });
    return { unitPrice, lineTotal: computeLineTotal({ unitPrice, quantity: l.quantity }) };
  });
  const subtotal = sumLineTotals(priced.map((p) => p.lineTotal));
  const discount = 0;
  return { lines: priced, subtotal, discount, expected: subtotal - discount };
}
