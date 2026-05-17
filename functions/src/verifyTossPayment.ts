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
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = request.auth.uid;
    const data = request.data as VerifyPaymentInput;

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

    // 3. Toss Server API confirm 호출
    const tossResponse = await confirmPayment(tossSecretKey.value(), {
      paymentKey: data.paymentKey,
      orderId: data.orderId,
      amount: data.amount,
    });

    // 4. 응답 검증
    const isStatusDone = tossResponse.status === "DONE";
    const isAmountMatch = tossResponse.totalAmount === data.amount;
    const isOrderIdMatch = tossResponse.orderId === data.idempotencyKey;

    if (!isStatusDone || !isAmountMatch || !isOrderIdMatch) {
      // 5. 검증 실패 → Toss cancel 시도 후 에러 throw
      try {
        await cancelPayment(tossSecretKey.value(), {
          paymentKey: data.paymentKey,
          cancelReason: "서버 측 검증 실패로 인한 자동 취소",
        });
      } catch (cancelErr) {
        // cancel 실패는 로그만 기록, 원본 에러를 throw
        console.error("verifyTossPayment: cancel 실패", cancelErr);
      }
      throw new HttpsError(
        "invalid-argument",
        `결제 검증 실패. status=${tossResponse.status}, ` +
          `amount=${tossResponse.totalAmount}(expected ${data.amount}), ` +
          `orderId=${tossResponse.orderId}(expected ${data.idempotencyKey})`
      );
    }

    // 6. Firestore batch write
    const db = admin.firestore();
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

    // orders/{orderId} 문서 — 동일 idempotencyKey 중복 결제 방지
    const orderDoc = db.collection("orders").doc(orderId);
    const existing = await orderDoc.get();
    if (existing.exists) {
      throw new HttpsError(
        "already-exists",
        "이미 처리된 결제입니다."
      );
    }
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
    return { orderId, status: "paid" };
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
