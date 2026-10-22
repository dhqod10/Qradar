/**
 * Qoin 적립률 callable 공통 — admin 서버 재검증 + 이력 문서 생성 헬퍼.
 *
 * 클라이언트가 보낸 역할을 믿지 않는다 (spec H2). `users/{uid}.role === 'admin'` 을 서버에서 읽는다.
 */

import * as admin from "firebase-admin";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

export const REGION = "asia-northeast3";

export type Scope = "global" | "brand" | "store";

/** 로그인 + admin 이 아니면 HttpsError. 통과하면 uid 반환. */
export async function requireAdmin(
  db: admin.firestore.Firestore,
  request: CallableRequest<unknown>
): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "login required");
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists || snap.get("role") !== "admin") {
    throw new HttpsError("permission-denied", "admin only");
  }
  return uid;
}

/** reason: 선택, 문자열, trim 후 최대 200자. 비면 null. 잘못된 타입은 invalid-argument. */
export function parseReason(raw: unknown): string | null {
  if (raw === undefined || raw === null) return null;
  if (typeof raw !== "string") throw new HttpsError("invalid-argument", "reason must be string");
  const t = raw.trim();
  if (t.length === 0) return null;
  if (t.length > 200) throw new HttpsError("invalid-argument", "reason too long");
  return t;
}

/** 대상 범위의 이력 서브컬렉션 (세 범위 모두 이름이 같아야 collection group 조회가 된다). */
export function historyCollection(
  db: admin.firestore.Firestore,
  scope: Scope,
  targetId: string
): admin.firestore.CollectionReference {
  const base =
    scope === "global"
      ? db.collection("config").doc("qoin")
      : db.collection(scope === "brand" ? "brands" : "stores").doc(targetId);
  return base.collection("qoinRateHistory");
}
