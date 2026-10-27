/**
 * verifyTossPayment — Cloud Function (onCall, asia-northeast3)
 *
 * 흐름:
 *   1. 인증 확인 (auth null → unauthenticated)
 *   2. 입력값 검증
 *   2-b. 결제 게이트 (G1 매장 판매 가능 + G2 메뉴 품절·판매중단) — Toss confirm **전**. 거절하면 돈이 움직이지 않는다
 *        (payment_server_authority, `paymentGate.ts`). 멱등 가드 직후 ~ confirm 직전이 유일한 "confirm 전 서버 지점"이다.
 *   2-c. 금액 게이트 — 카트 금액을 Firestore 문서에서 다시 계산해 대조 (payment_price_authority, `priceGate.ts`). 2-b 가 읽은
 *        메뉴를 재사용한다 (추가 읽기 0, 옵션 그룹만 +1 round-trip).
 *   3. Toss Server API POST /v1/payments/confirm 호출
 *   4. 응답 검증 (status === 'DONE' && totalAmount === amount && orderId 일치)
 *   5. 검증 실패 → Toss cancel + error throw
 *   6. 검증 성공 → Firestore batch:
 *      - orders/{orderId} set
 *      - users/{uid}/orderLogs/{logId} set
 *   7. 반환 { orderId, status: 'paid' }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { v4 as uuidv4 } from "uuid";
import { confirmPayment, cancelPayment } from "./tossClient";
import { applyServerPricing, buildOrderData, buildOrderLogData, CartSnapshot } from "./orderBuilder";
import { buildRejectionMessage, evaluatePaymentGate, GATE_HTTPS_CODE, GateReader, MAX_CART_ITEMS, resolveGateMode } from "./paymentGate";
import { evaluatePriceAuthority, resolveMenusForPricing, resolvePriceMode, storeUnreadableResult } from "./priceGate";
import { MergedMenu } from "./menuVisibility";
import { makeFirestoreGateReader, recordGateRejection } from "./paymentGateReader";

const tossSecretKey = defineSecret("TOSS_SECRET_KEY");

/**
 * 결제 게이트 모드 (payment_server_authority spec §17.0): off | shadow | enforce.
 * 값은 **배포 시점에** functions params 로 해석된다 — `functions/.env.<projectId>` (또는 `functions/.env`) 의
 * `PAYMENT_GATE_MODE=...` 한 줄. 값을 바꾸면 재배포해야 반영된다 (docs/tasks/payment_server_authority/implementation.md §8).
 * default 를 둬서 값이 없어도 배포가 대화형 프롬프트로 멈추지 않는다. 없거나 모르는 값은 `resolveGateMode` 가 `off` 로 떨어뜨린다.
 */
const paymentGateMode = defineString("PAYMENT_GATE_MODE", { default: "off" });

/**
 * 결제 금액 게이트 모드 (payment_price_authority spec §8, Q3): off | shadow | enforce. **`PAYMENT_GATE_MODE` 와 독립**이다.
 * 읽는 방식·폴백은 위와 같다 (`resolvePriceMode` = `resolveGateMode`). 운영 방법은 docs/operations.md §6 이 단일 진실원이다.
 */
const paymentPriceMode = defineString("PAYMENT_PRICE_MODE", { default: "off" });

// ── 입력 타입 ─────────────────────────────────────────────────────────────────
// OrderItem / CartSnapshot 은 orderBuilder.ts (주문 문서 구성의 단일 출처, T1).

interface VerifyPaymentInput {
  paymentKey: string;
  orderId: string;
  amount: number;
  idempotencyKey: string;
  cart: CartSnapshot;
  paymentMethod: string;
  /** 앱이 싣는 결제 클라이언트 수준 (lib/core/constants/app_client_level.dart). 구버전은 이 키가 없다. 거절 기록에만 쓴다 — 권위가 아니다. */
  clientLevel?: unknown;
}

// ── 함수 ─────────────────────────────────────────────────────────────────────

/** 외부 의존 주입 — 거절 경로에서 Toss 를 호출하지 않음을 단위 테스트로 단언하기 위한 이음새 (R5). */
export interface VerifyDeps {
  db: admin.firestore.Firestore;
  secretKey: () => string;
  confirm: typeof confirmPayment;
  cancel: typeof cancelPayment;
  /** 테스트에서 Firestore 대신 주입. 기본은 db 기반 어댑터. */
  gateReader?: GateReader;
  /**
   * 게이트 모드 원시 값을 돌려주는 thunk (spec §17.0). **thunk 인 이유**: 요청마다 읽고, `off` 일 때는 게이트 코드를 아예 타지 않는다.
   * 생략하면 `off` — "설정이 없으면 평가하지 않는다" 와 같은 방향이다.
   */
  gateMode?: () => unknown;
  /** 금액 게이트 모드 원시 값 thunk (payment_price_authority §8). 생략하면 `off` — 옵션 그룹을 읽지 않는다. */
  priceMode?: () => unknown;
}

export const verifyTossPayment = onCall(
  {
    region: "asia-northeast3",
    secrets: [tossSecretKey],
  },
  (request) =>
    handleVerifyTossPayment(
      {
        db: admin.firestore(),
        secretKey: () => tossSecretKey.value(),
        confirm: confirmPayment,
        cancel: cancelPayment,
        gateMode: () => paymentGateMode.value(),
        priceMode: () => paymentPriceMode.value(),
      },
      request
    )
);

export async function handleVerifyTossPayment(
  deps: VerifyDeps,
  request: { auth?: { uid: string } | null; data: unknown }
) {
    console.log("[verifyTossPayment] START");
    try {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = request.auth.uid;
    const data = request.data as VerifyPaymentInput;
    console.log("[verifyTossPayment] input:", JSON.stringify({
      uid,
      paymentKey: data.paymentKey?.substring(0, 20),
      orderId: data.orderId,
      amount: data.amount,
      idempotencyKey: data.idempotencyKey,
      paymentMethod: data.paymentMethod,
      cartKeys: data.cart ? Object.keys(data.cart) : null,
    }));

    // 2. 입력값 검증
    if (
      !data.paymentKey ||
      !data.orderId ||
      !data.amount ||
      !data.idempotencyKey ||
      !data.cart ||
      !data.paymentMethod
    ) {
      throw new HttpsError(
        "invalid-argument",
        "필수 입력값이 누락되었습니다. (paymentKey, orderId, amount, idempotencyKey, cart, paymentMethod)"
      );
    }
    // 품목 수 상한 (spec §15.1) — 토큰 절단을 구조적으로 막고 G2 읽기 비용(품목당 최대 3문서)의 뚜껑이 된다. 토큰 없음 → 앱은 갈래 C.
    if (!Array.isArray(data.cart.items) || data.cart.items.length > MAX_CART_ITEMS) {
      throw new HttpsError("invalid-argument", "cart.items 가 올바르지 않습니다.");
    }
    if (data.amount !== data.cart.totalPrice) {
      throw new HttpsError(
        "invalid-argument",
        `amount(${data.amount})와 cart.totalPrice(${data.cart.totalPrice})가 일치하지 않습니다.`
      );
    }

    // 3-pre. 멱등성 가드: Toss confirm 호출 전에 동일 idempotencyKey 문서 존재 확인
    //   - 정상 처리된 주문(status='paid' 이상) → already-exists 에러 + 기존 orderId 반환
    //   - 비정상 상태(status 누락 / 알 수 없는 값) → internal 에러
    //   - 존재하지 않으면 기존 흐름 진행
    const db = deps.db;
    const idempotencyDocRef = db.collection("orders").doc(data.idempotencyKey);
    const idempotencyDocSnap = await idempotencyDocRef.get();
    if (idempotencyDocSnap.exists) {
      const existingData = idempotencyDocSnap.data();
      const existingStatus = existingData?.status as string | undefined;
      const terminalStatuses = ["paid", "accepted", "making", "ready", "completed", "cancelled", "refunded"];
      if (existingStatus && terminalStatuses.includes(existingStatus)) {
        console.log(
          "[verifyTossPayment] idempotency hit — already processed. orderId:",
          data.idempotencyKey,
          "status:",
          existingStatus
        );
        // 정상 처리된 주문: 동일 결과 반환 (새 doc 생성 없음)
        return { orderId: data.idempotencyKey, status: existingStatus };
      }
      // 비정상 상태 문서가 존재하는 경우 — 중복 write 금지
      console.error(
        "[verifyTossPayment] idempotency conflict — unexpected status:",
        existingStatus,
        "orderId:",
        data.idempotencyKey
      );
      throw new HttpsError(
        "internal",
        "동일 주문 키로 처리 중인 요청이 있습니다. 잠시 후 다시 시도해주세요."
      );
    }

    // 2-b. 결제 게이트 (G1 + G2) — Toss confirm 전. 거절하면 confirm 을 호출하지 않는다 (R5).
    //   판정은 canSellNow / classifyCartMenu 두 함수뿐이다 (paymentGate.ts). 클라이언트가 선언한 scope/brandId 를 쓰지 않는다.
    //   모드 (spec §17.0): off = 평가·읽기 모두 하지 않는다(비용 0) / shadow = 판정·기록만, 거절 없음 / enforce = 판정·기록·거절.
    //   값이 없거나 모르면 off — 설정 오타로 매출이 멈추는 것보다 구멍이 하루 더 열려 있는 편이 낫다.
    const gateMode = resolveGateMode(deps.gateMode?.());
    const reader = deps.gateReader ?? makeFirestoreGateReader(db);
    // 2-b 가 읽어 해석한 메뉴 — 2-c 가 재사용한다 (추가 읽기 0). 게이트가 꺼졌거나 위반으로 끝났으면 null.
    let gateMenus: { menus: Map<string, MergedMenu>; storeBrandId: string | null } | null = null;
    if (gateMode !== "off") {
      const shadow = gateMode === "shadow";
      try {
        const gate = await evaluatePaymentGate(reader, data.cart);
        if (gate.ok) {
          gateMenus = {
            menus: new Map(gate.resolved.map((r) => [r.menuItemId, r.merged])),
            storeBrandId: gate.storeBrandId,
          };
        }
        if (!gate.ok) {
          await recordGateRejection(db, {
            uid,
            storeId: String(data.cart.storeId ?? ""),
            reason: gate.reason,
            detail: gate.detail,
            amount: data.amount,
            shadow,
          });
          console.warn(
            `[verifyTossPayment] GATE ${shadow ? "SHADOW (not rejected)" : "REJECT"}`,
            gate.reason,
            JSON.stringify(gate.detail)
          );
          if (!shadow) {
            throw new HttpsError(GATE_HTTPS_CODE[gate.reason], buildRejectionMessage(gate.reason, gate.menuItemIds), {
              reason: gate.reason,
              menuItemIds: gate.menuItemIds,
            });
          }
        }
      } catch (e) {
        // shadow 는 관측용이다 — 게이트 코드의 예상 밖 예외가 결제를 막아서는 안 된다. enforce 의 거절(HttpsError)은 그대로 던진다.
        if (!shadow || e instanceof HttpsError) throw e;
        console.error("[verifyTossPayment] shadow gate error (결제는 계속 진행)", e);
      }
    }

    // 2-c. 금액 게이트 (payment_price_authority). 모드 off 면 메뉴도 옵션 그룹도 읽지 않는다 (비용 0).
    //   shadow = 판정·기록만 (주문 문서는 클라 값 그대로) / enforce = 판정·기록·거절 + 주문 문서의 금액 필드를 서버 값으로 쓴다.
    //   PAYMENT_GATE_MODE=off + 가격 모드 != off 조합: 2-b 가 메뉴를 읽지 않았으므로 여기서 직접 읽는다 — 조용히 통과시키지 않는다.
    let serverPricing: { lines: Array<{ unitPrice: number; lineTotal: number }>; subtotal: number; expected: number } | null = null;
    const priceMode = resolvePriceMode(deps.priceMode?.());
    if (priceMode !== "off") {
      const shadow = priceMode === "shadow";
      try {
        const menus =
          gateMenus ?? (await resolveMenusForPricing(reader, { storeId: data.cart.storeId, items: data.cart.items }));
        const result =
          menus === null
            ? storeUnreadableResult(data.amount)
            : await evaluatePriceAuthority(reader, {
                storeId: data.cart.storeId,
                storeBrandId: menus.storeBrandId,
                menus: menus.menus,
                amount: data.amount,
                cart: data.cart,
              });
        if (!result.ok) {
          await recordGateRejection(db, {
            uid,
            storeId: String(data.cart.storeId ?? ""),
            reason: result.reason,
            // clientLevel: null = 구버전(재가격 없음). ⑤-b 관측에서 구버전 비율을 재는 수단 (H-01). 판정에는 쓰지 않는다.
            detail: { ...result.detail, clientLevel: Number.isInteger(data.clientLevel) ? data.clientLevel : null },
            amount: data.amount,
            shadow,
          });
          console.warn(
            `[verifyTossPayment] PRICE ${shadow ? "SHADOW (not rejected)" : "REJECT"}`,
            result.reason,
            JSON.stringify(result.detail)
          );
          if (!shadow) {
            throw new HttpsError(GATE_HTTPS_CODE[result.reason], buildRejectionMessage(result.reason, result.menuItemIds), {
              reason: result.reason,
              menuItemIds: result.menuItemIds,
            });
          }
        } else if (!shadow) {
          serverPricing = result.pricing;
        }
      } catch (e) {
        // shadow 는 관측용이다 — 예상 밖 예외가 결제를 막아서는 안 된다. enforce 의 거절(HttpsError)은 그대로 던진다.
        if (!shadow || e instanceof HttpsError) throw e;
        console.error("[verifyTossPayment] shadow price gate error (결제는 계속 진행)", e);
      }
    }

    // 3. Toss Server API confirm 호출 (또는 Mock 분기 — docs 공개 키 사용 시)
    const secretKey = deps.secretKey();
    const isMockMode = secretKey.startsWith("test_gsk_docs_");
    const tossResponse = isMockMode
      ? {
          paymentKey: data.paymentKey,
          orderId: data.idempotencyKey,
          status: "DONE",
          totalAmount: data.amount,
          approvedAt: new Date().toISOString(),
          method: data.paymentMethod,
        }
      : await deps.confirm(secretKey, {
          paymentKey: data.paymentKey,
          orderId: data.orderId,
          amount: data.amount,
        });
    if (isMockMode) {
      console.log("[verifyTossPayment] MOCK MODE — Toss confirm SKIP");
    }

    // 4. 응답 검증
    const isStatusDone = tossResponse.status === "DONE";
    const isAmountMatch = tossResponse.totalAmount === data.amount;
    const isOrderIdMatch = tossResponse.orderId === data.idempotencyKey;

    if (!isStatusDone || !isAmountMatch || !isOrderIdMatch) {
      // 5. 검증 실패 → Toss cancel 시도 후 에러 throw
      if (!isMockMode) {
        try {
          await deps.cancel(secretKey, {
            paymentKey: data.paymentKey,
            cancelReason: "서버 측 검증 실패로 인한 자동 취소",
          });
        } catch (cancelErr) {
          // cancel 실패는 로그만 기록, 원본 에러를 throw
          console.error("verifyTossPayment: cancel 실패", cancelErr);
        }
      }
      throw new HttpsError(
        "invalid-argument",
        `결제 검증 실패. status=${tossResponse.status}, ` +
          `amount=${tossResponse.totalAmount}(expected ${data.amount}), ` +
          `orderId=${tossResponse.orderId}(expected ${data.idempotencyKey})`
      );
    }

    // 6. Firestore batch write
    const now = admin.firestore.FieldValue.serverTimestamp();
    const logId = uuidv4();
    const orderId = data.idempotencyKey;

    // approvedAt 파싱 (Toss ISO 8601 문자열 → Timestamp)
    const approvedAt = admin.firestore.Timestamp.fromDate(
      new Date(tossResponse.approvedAt)
    );

    // paymentMethod 정규화 (easyPay 제공자 기반)
    const resolvedPaymentMethod = normalizePaymentMethod(
      data.paymentMethod,
      tossResponse.easyPay?.provider
    );

    // paymentInfo 맵 구성
    const paymentInfo: Record<string, unknown> = {
      method: resolvedPaymentMethod,
      channel: "toss",
      paymentKey: tossResponse.paymentKey,
      transactionId: tossResponse.transactionKey ?? null,
      receiptUrl: tossResponse.receipt?.url ?? null,
      approvedAt,
      amount: tossResponse.totalAmount,
      cardCompany: tossResponse.card?.company ?? null,
      cardNumberMasked: maskCardNumber(tossResponse.card?.number),
      easyPayProvider: tossResponse.easyPay?.provider ?? null,
    };

    // orders/{orderId} 문서 (멱등성 가드 통과 후 신규 write)
    const orderDoc = idempotencyDocRef; // 이미 step 3-pre 에서 참조 확보
    // R8: enforce 에서는 금액 필드를 서버가 문서에서 다시 만든 값으로 쓴다. shadow / off 는 클라 값 그대로 (관측만).
    const cartForOrder = serverPricing === null ? data.cart : applyServerPricing(data.cart, serverPricing);
    const orderData = buildOrderData(cartForOrder, uid, paymentInfo, { approvedAt, now });

    // users/{uid}/orderLogs/{logId} 문서 (Phase 2 OrderLogEntity 스키마 준수)
    const logDoc = db
      .collection("users")
      .doc(uid)
      .collection("orderLogs")
      .doc(logId);
    const logData = buildOrderLogData(
      cartForOrder,
      { logId, orderId, paymentMethod: resolvedPaymentMethod },
      { approvedAt, now }
    );

    const batch = db.batch();
    batch.set(orderDoc, orderData);
    batch.set(logDoc, logData);
    await batch.commit();

    // 7. 반환
    console.log("[verifyTossPayment] SUCCESS orderId:", orderId);
    return { orderId, status: "paid" };
    } catch (err) {
      console.error("[verifyTossPayment] FATAL:", err);
      if (err instanceof Error) {
        console.error("[verifyTossPayment] stack:", err.stack);
      }
      throw err;
    }
}

// ── 헬퍼 ─────────────────────────────────────────────────────────────────────

/** Toss easyPay provider 기반으로 paymentMethod 정규화. */
function normalizePaymentMethod(
  requestedMethod: string,
  easyPayProvider?: string
): string {
  if (easyPayProvider) {
    const provider = easyPayProvider.toUpperCase();
    if (provider === "KAKAOPAY") return "kakaoPay";
    if (provider === "NAVERPAY") return "naverPay";
    if (provider === "TOSSPAY") return "tossPay";
    if (provider === "SAMSUNGPAY") return "samsungPay";
    if (provider === "APPLEPAY") return "applePay";
    if (provider === "PAYCO") return "payco";
  }
  // 카드 / 계좌이체 등
  return requestedMethod;
}

/** 카드 번호 마스킹. "1234567812345678" → "1234-****-****-5678". */
function maskCardNumber(number?: string): string | null {
  if (!number) return null;
  const digits = number.replace(/\D/g, "");
  if (digits.length < 8) return null;
  const first4 = digits.slice(0, 4);
  const last4 = digits.slice(-4);
  return `${first4}-****-****-${last4}`;
}
