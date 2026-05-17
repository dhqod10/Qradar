/**
 * Toss Payments Server API HTTP 래퍼.
 *
 * 모든 요청은 Basic 인증을 사용한다.
 * Authorization: Basic base64(`${TOSS_SECRET_KEY}:`)  ← 콜론 포함, password 는 빈 문자열
 *
 * 환경변수 `TOSS_SECRET_KEY` 는 Firebase Secrets Manager 에서 주입.
 * (firebase functions:secrets:set TOSS_SECRET_KEY)
 */

import axios, { AxiosError } from "axios";
import { HttpsError } from "firebase-functions/v2/https";

const TOSS_BASE_URL = "https://api.tosspayments.com";

/** Toss API 인증 헤더 생성. */
function buildAuthHeader(secretKey: string): string {
  const encoded = Buffer.from(`${secretKey}:`).toString("base64");
  return `Basic ${encoded}`;
}

/** Toss 응답에서 에러 처리 후 throw. */
function handleTossError(error: unknown): never {
  if (error instanceof AxiosError && error.response) {
    const { code, message } = error.response.data as {
      code?: string;
      message?: string;
    };
    throw new HttpsError(
      "internal",
      `Toss API 오류 [${code ?? "UNKNOWN"}]: ${message ?? "알 수 없는 오류"}`
    );
  }
  throw new HttpsError("internal", "Toss API 호출에 실패했습니다.");
}

// ── 응답 타입 ────────────────────────────────────────────────────────────────

export interface TossConfirmResponse {
  paymentKey: string;
  orderId: string;
  status: string;
  totalAmount: number;
  approvedAt: string;
  method: string;
  transactionKey?: string;
  receipt?: { url?: string };
  card?: { company?: string; number?: string };
  easyPay?: { provider?: string };
}

export interface TossCancelResponse {
  paymentKey: string;
  orderId: string;
  status: string;
  cancels: Array<{
    transactionKey: string;
    cancelReason: string;
    canceledAt: string;
    cancelAmount: number;
  }>;
}

// ── API 함수 ─────────────────────────────────────────────────────────────────

/**
 * POST /v1/payments/confirm
 * 결제 승인 요청. 반드시 서버 측에서만 호출해야 한다 (클라이언트 노출 금지).
 */
export async function confirmPayment(
  secretKey: string,
  params: {
    paymentKey: string;
    orderId: string;
    amount: number;
  }
): Promise<TossConfirmResponse> {
  try {
    const response = await axios.post<TossConfirmResponse>(
      `${TOSS_BASE_URL}/v1/payments/confirm`,
      {
        paymentKey: params.paymentKey,
        orderId: params.orderId,
        amount: params.amount,
      },
      {
        headers: {
          Authorization: buildAuthHeader(secretKey),
          "Content-Type": "application/json",
        },
      }
    );
    return response.data;
  } catch (error) {
    handleTossError(error);
  }
}

/**
 * POST /v1/payments/{paymentKey}/cancel
 * 결제 취소 (paid → cancelled) 또는 환불 (accepted+ → refunded).
 * 전액 취소만 지원 (Phase 3a 확정 사항). cancelAmount 미전달 = 전액.
 */
export async function cancelPayment(
  secretKey: string,
  params: {
    paymentKey: string;
    cancelReason: string;
  }
): Promise<TossCancelResponse> {
  try {
    const response = await axios.post<TossCancelResponse>(
      `${TOSS_BASE_URL}/v1/payments/${encodeURIComponent(params.paymentKey)}/cancel`,
      {
        cancelReason: params.cancelReason,
      },
      {
        headers: {
          Authorization: buildAuthHeader(secretKey),
          "Content-Type": "application/json",
        },
      }
    );
    return response.data;
  } catch (error) {
    handleTossError(error);
  }
}
