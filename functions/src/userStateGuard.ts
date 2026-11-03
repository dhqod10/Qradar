/**
 * 유저 상태 가드 (admin_user_moderation) — `verifyTossPayment` 의 Toss confirm **전**에서 호출.
 * 정지의 진짜 집행은 Firebase Auth disabled + revokeRefreshTokens 이고, 이 가드는 토큰 유효 잔여창(최대 1시간)을 닫는
 * 명시적 거절이다. deleted 유저의 결제 차단(account_deletion tester 보류)도 여기서 함께 해소한다.
 * 판정은 순수 함수 — Firestore 읽기는 호출 측이 한다.
 */
import { GateReason } from "./paymentGate";

type RawDoc = Record<string, unknown>;

/** 결제자 본인 문서 → 거절 사유 (없으면 null). 문서가 없으면 판정하지 않는다 (기존 동작 유지). */
export function buyerBlockReason(user: RawDoc | null | undefined): GateReason | null {
  if (!user) return null;
  if (user.deleted === true) return "USER_DELETED";
  if (user.suspended === true) return "USER_SUSPENDED";
  return null;
}

/** 매장 점주 문서 → 거절 사유. 점주 정지/탈퇴면 매장 판매 중단 (fan-out 쓰기 없이 결제 시점에 판독). */
export function ownerBlockReason(owner: RawDoc | null | undefined): GateReason | null {
  if (!owner) return null;
  return owner.suspended === true || owner.deleted === true ? "STORE_OWNER_SUSPENDED" : null;
}
