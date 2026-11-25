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
 * 옵션 키는 `groupId / groupName / itemId / label / priceDelta` 다. `imageUrl` 은 주문상세 썸네일용으로 보낸다(order_flow_phase1 "UI 캐싱" 의도 복원 — 이름·라벨과 같은 표시 스냅샷).
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

/**
 * `verifyTossPayment` **최상위 입력**(cart 밖)에서 소비하는 키 집합 (qoin_spend). `qoinToUse` 는 cart 가 아니라 여기 있다 —
 * 장바구니는 메뉴 선택을 표현하고 Qoin 차감은 결제 시점의 선택이다. Dart `CloudFunctionsRemoteDataSource.verifyPayload` 와
 * `test_fixtures/qoin_cart_contract.json` 의 `inputKeys` 로 양방향 고정된다 (한쪽만 바뀌면 골든이 깨진다).
 */
export const CONSUMED_INPUT_KEYS = [
  "amount",
  "cart",
  "clientLevel",
  "deviceId",
  "idempotencyKey",
  "orderId",
  "paymentKey",
  "paymentMethod",
  "qoinToUse",
] as const;

/** `data.cart.items[]` 에서 소비하는 키 집합 — Dart `cartToMap` 의 item 키와 골든으로 고정된다 (§1-5 재발 방지). */
export const CONSUMED_ITEM_KEYS = [
  "imageUrl",
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
 * `discount` 는 기본적으로 건드리지 않는다 (null 유지). **Qoin 사용(qoin_spend)** 주문만 세 번째 인자 `discount`(서버가 검증한 사용액)를
 * 넘기며, 이때 `pricing.expected` 는 이미 `소계 − discount` (서버 최종청구액) 이고 주문 문서 `discount` 가 그 값으로 쓰인다.
 * `discount` 를 생략/0 으로 부르면 결과는 현행과 바이트 동일하다.
 */
export function applyServerPricing(
  cart: CartSnapshot,
  pricing: { lines: ReadonlyArray<{ unitPrice: number; lineTotal: number }>; subtotal: number; expected: number },
  discount = 0
): CartSnapshot {
  return {
    ...cart,
    ...(discount > 0 ? { discount } : {}),
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
  times: { approvedAt: TS; now: TS },
  /** 서버가 발급한 매장·일별 픽업번호 (order_pickup_number). 없으면 키 자체를 쓰지 않는다. */
  pickupNumber?: number,
  /**
   * 주문 **시점**의 구매자 인구통계 (선택 수집, 통계 전용). users 문서에서 읽어 **복사**한다.
   *
   * 왜 조인하지 않고 복사하는가: ① 2026년에 20대였던 주문은 2032년에도 20대 주문이어야 한다
   * (users 를 조인하면 과거 통계가 현재 값으로 덮여 틀어진다). ② 탈퇴해 users 가 익명화돼도 통계가 남는다.
   * ③ 분석(BigQuery)에 orders 만 내보내면 되므로 이메일·전화번호 같은 PII 를 복사하지 않아도 된다.
   *
   * 미입력이면 null — "그 주문의 구매자는 밝히지 않았다" 는 사실 자체가 통계값이다.
   */
  buyer?: { gender: string | null; ageRange: string | null }
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
    buyerGender: buyer?.gender ?? null,
    buyerAgeRange: buyer?.ageRange ?? null,
    ...(pickupNumber !== undefined ? { pickupNumber } : {}),
  };
}

export const GENDER_CODES = ["male", "female"] as const;

/** 이용약관의 가입 연령 하한. 이보다 어린 값은 통계에 넣지 않는다. */
export const MIN_SIGNUP_AGE = 14;
/** 오타(1066 같은 값) 상한. */
export const MAX_PLAUSIBLE_AGE = 120;

/**
 * 출생연도 → 통계 구간. **users 에는 연령대가 아니라 출생연도가 저장된다** — 연령대를 저장하면
 * 값이 늙지 않아 몇 해 뒤 주문에 낡은 구간이 박히기 때문이다. 월·일을 받지 않으므로 연도 차이로만 센다.
 * 범위 밖이면 null.
 */
export function ageRangeFromBirthYear(birthYear: number, nowYear: number): string | null {
  const age = nowYear - birthYear;
  if (age < MIN_SIGNUP_AGE || age > MAX_PLAUSIBLE_AGE) return null;
  if (age < 20) return "teens";
  if (age < 30) return "twenties";
  if (age < 40) return "thirties";
  if (age < 50) return "forties";
  if (age < 60) return "fifties";
  return "sixtiesPlus";
}

/**
 * users 문서에서 통계용 인구통계만 꺼낸다. **PII 는 꺼내지 않는다** (이름·이메일·전화번호는 주문에 복사되지 않는다).
 * 모르는 값/부재는 null — 주문 기록이 users 의 쓰레기값을 물려받지 않게 한다.
 *
 * 연령대는 **주문 시점 기준으로 계산**한다. 같은 사람이 해를 넘겨 주문하면 구간이 바뀌는 게 정상이다.
 */
export function extractBuyerDemographics(
  userData: Record<string, unknown> | null | undefined,
  nowYear: number = new Date().getFullYear()
): { gender: string | null; ageRange: string | null } {
  const g = userData?.["gender"];
  const b = userData?.["birthYear"];
  return {
    gender: typeof g === "string" && (GENDER_CODES as readonly string[]).includes(g) ? g : null,
    ageRange: typeof b === "number" && Number.isInteger(b) ? ageRangeFromBirthYear(b, nowYear) : null,
  };
}

export function buildOrderLogData<TS>(
  cart: CartSnapshot,
  args: { logId: string; orderId: string; paymentMethod: string; /** 서버가 검증한 Qoin 사용액. 생략/0 이면 키 없음. */ discount?: number; /** orders 와 동일한 픽업번호. 없으면 키 없음. */ pickupNumber?: number },
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
    // Qoin 사용 주문만 (qoin_spend spec §7.3 — 내역 일관성). 호출자가 검증된 값을 명시로 넘길 때만 — 비-Qoin 은 키 자체가 없다.
    ...(args.discount !== undefined && args.discount > 0 ? { discount: args.discount } : {}),
    ...(args.pickupNumber !== undefined ? { pickupNumber: args.pickupNumber } : {}),
    status: "paid",
    paymentMethod: args.paymentMethod,
    paymentChannel: "toss",
    createdAt: times.approvedAt,
    updatedAt: times.now,
  };
}
