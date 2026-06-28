/**
 * verifyTossPayment — Cloud Function (onCall, asia-northeast3)
 *
 * 흐름:
 *   1. 인증 확인 (auth null → unauthenticated)
 *   2. 입력값 검증
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
import { defineSecret } from "firebase-functions/params";
import { v4 as uuidv4 } from "uuid";
import { confirmPayment, cancelPayment } from "./tossClient";

const tossSecretKey = defineSecret("TOSS_SECRET_KEY");

// ── 입력 타입 ─────────────────────────────────────────────────────────────────

interface OrderItem {
  menuItemId: string;
  menuItemName: string;
  imageUrl: string;
  quantity: number;
  selectedOptions: Array<{
    optionGroupId: string;
    optionGroupName: string;
    optionId: string;
    optionName: string;
    priceDelta: number;
  }>;
  unitPriceWithOptions: number;
  lineTotal: number;
}

interface CartSnapshot {
  storeId: string;
  storeName: string;
  brandId?: string | null;
  items: OrderItem[];
  subtotal: number;
  discount?: number | null;
  totalPrice: number;
}

interface VerifyPaymentInput {
  paymentKey: string;
  orderId: string;
  amount: number;
  idempotencyKey: string;
  cart: CartSnapshot;
  paymentMethod: string;
}

// ── 함수 ─────────────────────────────────────────────────────────────────────

export const verifyTossPayment = onCall(
  {
    region: "asia-northeast3",
    secrets: [tossSecretKey],
  },
  async (request) => {
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
    const db = admin.firestore();
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

    // 3. Toss Server API confirm 호출 (또는 Mock 분기 — docs 공개 키 사용 시)
    const secretKey = tossSecretKey.value();
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
      : await confirmPayment(secretKey, {
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
          await cancelPayment(secretKey, {
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
    const orderData = {
      userId: uid,
      storeId: data.cart.storeId,
      storeName: data.cart.storeName,
      brandId: data.cart.brandId ?? null,
      items: data.cart.items,
      subtotal: data.cart.subtotal,
      discount: data.cart.discount ?? null,
      totalPrice: data.cart.totalPrice,
      status: "paid",
      paymentInfo,
      refundRequest: null,
      refundInfo: null,
      createdAt: approvedAt,
      updatedAt: now,
      acceptedAt: null,
      cancelledAt: null,
      refundedAt: null,
    };

    // users/{uid}/orderLogs/{logId} 문서 (Phase 2 OrderLogEntity 스키마 준수)
    const logDoc = db
      .collection("users")
      .doc(uid)
      .collection("orderLogs")
      .doc(logId);
    const logData = {
      logId,
      orderId,
      storeId: data.cart.storeId,
      storeName: data.cart.storeName,
      brandId: data.cart.brandId ?? null,
      items: data.cart.items,
      totalPrice: data.cart.totalPrice,
      status: "paid",
      paymentMethod: resolvedPaymentMethod,
      paymentChannel: "toss",
      createdAt: approvedAt,
      updatedAt: now,
    };

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
);

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
