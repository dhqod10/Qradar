/**
 * 주문 / 주문 로그 문서 구성 — `verifyTossPayment` 의 순수 함수 분리 (T1, spec §19.1).
 *
 * **왜 분리하나**: 1차 F1(주문의 `brandId` 가 항상 null) 이 테스트에 안 잡힌 이유는 모든 E2E 가 주문을 손으로
 * 시드했기 때문이다. 이제 에뮬레이터 E2E 는 이 함수로 주문을 만든다 — "테스트가 쓰는 주문" 과 "운영이 쓰는 주문" 의
 * 모양이 같은 코드에서 나온다. Firebase 비의존 (타임스탬프는 호출자가 넘긴다).
 *
 * **`brandId` 는 항상 null 을 기록한다.** `cart` 는 클라이언트 값이라 신뢰원이 될 수 없다. 브랜드의 유일한 신뢰원은
 * `stores/{storeId}.brandId` 이고 적립 시점(`onOrderQoinSettled`)에 읽는다. 클라이언트 지정 값을 저장 자체 하지 않음으로써
 * "나중에 누가 다시 신뢰원으로 쓰는" 재발 경로를 끊는다. `CartEntity` 에도 `brandId` 를 추가하지 않는다.
 */

/**
 * 클라이언트가 실제로 보내는 item 형태 (payment_price_authority §1-5 — 이전 선언은 런타임과 달랐다).
 * 옵션 키는 `groupId / groupName / itemId / label / priceDelta` 이며 `imageUrl` 은 보내지 않는다.
 * 키 집합은 `test_fixtures/qoin_cart_contract.json` (itemKeys / selectedOptionKeys) 이 Dart 와 양방향으로 고정한다.
 */
export interface OrderItem {
  menuItemId: string;
  menuItemName: string;
  imageUrl?: string;
  quantity: number;
  selectedOptions: Array<{
    groupId: string;
    groupName: string;
    itemId: string;
    label: string;
    priceDelta: number;
  }>;
  unitPriceWithOptions: number;
  lineTotal: number;
}

/** 클라이언트가 보내는 cart. 여기에 없는 키(brandId 등)는 읽지 않는다. */
export interface CartSnapshot {
  storeId: string;
  storeName: string;
  items: OrderItem[];
  subtotal: number;
  discount?: number | null;
  totalPrice: number;
}

/**
 * `data.cart` 에서 **소비하는** 키 집합 (T2). Dart `PaymentGatewayRepositoryImpl.cartToMap` 이 보내는 키 집합과
 * `test_fixtures/qoin_cart_contract.json` 으로 양방향 고정된다 — 한쪽만 바뀌면 골든이 깨져 대조가 강제된다.
 */
export const CONSUMED_CART_KEYS = ["discount", "items", "storeId", "storeName", "subtotal", "totalPrice"] as const;

/** `data.cart.items[]` 에서 소비하는 키 집합 — Dart `cartToMap` 의 item 키와 골든으로 고정된다 (§1-5 재발 방지). */
export const CONSUMED_ITEM_KEYS = [
  "lineTotal",
  "menuItemId",
  "menuItemName",
  "quantity",
  "selectedOptions",
  "unitPriceWithOptions",
] as const;

/** `items[].selectedOptions[]` 에서 소비하는 키 집합. */
export const CONSUMED_OPTION_KEYS = ["groupId", "groupName", "itemId", "label", "priceDelta"] as const;

/**
 * R8 (payment_price_authority §10): enforce 에서 주문 문서의 **금액 필드만** 서버가 문서에서 다시 만든 값으로 바꾼다
 * (`unitPriceWithOptions` / `lineTotal` / `subtotal` / `totalPrice`). 이름·옵션 라벨은 클라 값 그대로다 (Q4 ⓐ).
 * 클라 값이 주문 문서에 도달하는 경로 자체를 없애는 것이 목적이다 — enforce 에서는 값이 같아야 통과하므로 바이트는 같다.
 * `discount` 는 건드리지 않는다 (null 유지).
 */
export function applyServerPricing(
  cart: CartSnapshot,
  pricing: { lines: ReadonlyArray<{ unitPrice: number; lineTotal: number }>; subtotal: number; expected: number }
): CartSnapshot {
  return {
    ...cart,
    items: cart.items.map((it, i) => ({
      ...it,
      unitPriceWithOptions: pricing.lines[i].unitPrice,
      lineTotal: pricing.lines[i].lineTotal,
    })),
    subtotal: pricing.subtotal,
    totalPrice: pricing.expected,
  };
}

export function buildOrderData<TS>(
  cart: CartSnapshot,
  uid: string,
  paymentInfo: Record<string, unknown>,
  times: { approvedAt: TS; now: TS }
): Record<string, unknown> {
  return {
    userId: uid,
    storeId: cart.storeId,
    storeName: cart.storeName,
    brandId: null, // 신뢰원 아님 — 위 설명 참조
    items: cart.items,
    subtotal: cart.subtotal,
    discount: cart.discount ?? null,
    totalPrice: cart.totalPrice,
    status: "paid",
    paymentInfo,
    refundRequest: null,
    refundInfo: null,
    createdAt: times.approvedAt,
    updatedAt: times.now,
    acceptedAt: null,
    cancelledAt: null,
    refundedAt: null,
  };
}

export function buildOrderLogData<TS>(
  cart: CartSnapshot,
  args: { logId: string; orderId: string; paymentMethod: string },
  times: { approvedAt: TS; now: TS }
): Record<string, unknown> {
  return {
    logId: args.logId,
    orderId: args.orderId,
    storeId: cart.storeId,
    storeName: cart.storeName,
    brandId: null, // 위와 같다
    items: cart.items,
    totalPrice: cart.totalPrice,
    status: "paid",
    paymentMethod: args.paymentMethod,
    paymentChannel: "toss",
    createdAt: times.approvedAt,
    updatedAt: times.now,
  };
}
