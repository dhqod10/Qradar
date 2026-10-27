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

/**
 * 한 라인의 수량 상한 — Dart `kMaxLineQuantity`(cart_pricing.dart)와 **같은 값**이다 (test_report F-01).
 * `test_fixtures/cart_pricing_contract.json` 의 `quantityCases` / `mergeCases` 가 양쪽을 같은 파일로 고정한다.
 */
export const MAX_LINE_QUANTITY = 99;

/** 1 이상 MAX_LINE_QUANTITY 이하의 정수. Dart `isValidLineQuantity` 와 같은 경계. */
export function isValidLineQuantity(q: unknown): q is number {
  return typeof q === "number" && Number.isInteger(q) && q >= 1 && q <= MAX_LINE_QUANTITY;
}

/** 같은 라인에 수량을 더한 결과(상한으로 자름). 서버 판정에는 쓰이지 않고 Dart 와의 골든 대칭을 위해 둔다. */
export function mergeLineQuantity(existing: number, added: number): number {
  return Math.min(existing + added, MAX_LINE_QUANTITY);
}

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
