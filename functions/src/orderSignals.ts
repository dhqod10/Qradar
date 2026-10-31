/**
 * orderSignals/{orderId} — Layer2 신호수집 (prelaunch_security_bundle spec §2). **데이터만 저장한다. 탐지·플래그·UI 없음.**
 *
 * 최소수집: 기기 ID · 카드 지문 · IP 모두 HMAC-SHA256(salt) 해시로만 저장하고 원본은 저장하지 않는다.
 * salt 는 secret `SIGNAL_HASH_SALT` (코드에 값 없음). 컬렉션은 admin read 전용 + CF write 전담 (점주가 고객 기기/IP 를 못 본다).
 *
 * 잠정(사용자 검토 대기): D-3 deviceId=Firebase Installations ID / D-4 ipHash / D-5 분리 컬렉션 / D-6 best-effort write.
 */

import * as admin from "firebase-admin";
import { createHmac } from "crypto";

/** 종류 접두사로 도메인을 분리한다 (같은 문자열이 deviceId 와 ip 에서 같은 해시가 되지 않게). */
export function hashSignal(salt: string, kind: "device" | "card" | "ip", value: unknown): string | null {
  if (typeof value !== "string") return null;
  const v = value.trim();
  if (v.length === 0 || v.length > 512) return null;
  return createHmac("sha256", salt).update(`${kind}:${v}`).digest("hex");
}

export interface OrderSignalInput {
  orderId: string;
  userId: string;
  storeId: string;
  storeOwnerId: string | null;
  storeBrandId: string | null;
  deviceId: unknown;
  card: { company?: string; number?: string } | undefined;
  ip: unknown;
}

/** 문서 본문 구성 (순수). 비카드 결제(card 없음)는 cardFingerprint/cardCompany 가 null. */
export function buildOrderSignalDoc(salt: string, i: OrderSignalInput, createdAt: unknown): Record<string, unknown> {
  const cardKey =
    i.card && (i.card.number || i.card.company) ? `${i.card.company ?? ""}|${i.card.number ?? ""}` : null;
  return {
    orderId: i.orderId,
    userId: i.userId,
    storeId: i.storeId,
    storeOwnerId: i.storeOwnerId,
    storeBrandId: i.storeBrandId,
    deviceIdHash: hashSignal(salt, "device", i.deviceId),
    cardFingerprint: cardKey === null ? null : hashSignal(salt, "card", cardKey),
    cardCompany: typeof i.card?.company === "string" ? i.card.company : null,
    ipHash: hashSignal(salt, "ip", i.ip),
    createdAt,
  };
}

/**
 * best-effort 기록 (D-6). 어떤 실패도 던지지 않는다 — 신호 때문에 주문 성공이 뒤집히면 안 된다.
 * 문서 ID = orderId 라 `create` 는 멱등 (이미 있으면 무시).
 */
export async function writeOrderSignal(
  db: admin.firestore.Firestore,
  salt: string | undefined,
  input: OrderSignalInput
): Promise<void> {
  try {
    if (!salt) {
      console.warn("[orderSignals] SIGNAL_HASH_SALT 없음 — 신호 저장 생략. orderId:", input.orderId);
      return;
    }
    const doc = buildOrderSignalDoc(salt, input, admin.firestore.FieldValue.serverTimestamp());
    await db.collection("orderSignals").doc(input.orderId).create(doc);
  } catch (e) {
    if ((e as { code?: number }).code === 6) return; // ALREADY_EXISTS
    console.error("[orderSignals] write failed (주문은 성공 처리)", input.orderId, e);
  }
}
