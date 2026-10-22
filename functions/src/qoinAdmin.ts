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

// ── 공용 헬퍼 (이력 스키마 · 일괄 적용 잠금) ───────────────────────────────────

/** 이력 `beforeState` — 이전 값의 상태. `before: null` 이 "설정 없음" 인지 "무효" 인지를 구별한다 (부가 B). */
export type BeforeState = "absent" | "value" | "invalid";

/**
 * 무효 값의 원형을 문자열로 (최대 100자). 문자열은 따옴표를 붙여 `"3"` 과 `3` 을 구별한다.
 * 이력/이슈 문서에 임의 타입을 그대로 넣지 않기 위한 것이다.
 */
export function describeRaw(raw: unknown): string {
  let t: string;
  if (raw === undefined) t = "(absent)";
  else if (typeof raw === "number") t = Number.isNaN(raw) ? "NaN" : String(raw);
  else {
    try {
      t = JSON.stringify(raw) ?? String(raw);
    } catch {
      t = String(raw);
    }
  }
  return t.length > 100 ? t.slice(0, 100) : t;
}

export interface BeforeInfo<T> {
  before: T | null;
  beforeState: BeforeState;
  beforeRaw: string | null;
}

/** 적립률 필드의 이전 값 → 이력 필드 3종. 유효 범위의 number 만 'value' (0 포함 그 외 number 는 무효). */
export function rateBeforeInfo(raw: unknown, isValue: boolean): BeforeInfo<number> {
  if (raw === undefined) return { before: null, beforeState: "absent", beforeRaw: null };
  if (isValue) return { before: raw as number, beforeState: "value", beforeRaw: null };
  return { before: null, beforeState: "invalid", beforeRaw: describeRaw(raw) };
}

/** 스위치(bool) 필드의 이전 값 → 이력 필드 3종. */
export function switchBeforeInfo(raw: unknown): BeforeInfo<boolean> {
  if (raw === undefined) return { before: null, beforeState: "absent", beforeRaw: null };
  if (typeof raw === "boolean") return { before: raw, beforeState: "value", beforeRaw: null };
  return { before: null, beforeState: "invalid", beforeRaw: describeRaw(raw) };
}

/**
 * 브랜드 문서의 일괄 적용 잠금 판정 (F5). `qoinBulkStatus == 'in_progress'` 이고 `qoinBulkAt` 이 5분 안이면 진행 중.
 * 트랜잭션 **안에서** 이미 읽은 브랜드 스냅샷으로 판정한다 (추가 read 0, 같은 문서 경합이라 직렬화된다).
 */
export function isBulkInProgress(brandSnap: admin.firestore.DocumentSnapshot, bulkStaleMs: number): boolean {
  if (!brandSnap.exists) return false;
  if (brandSnap.get("qoinBulkStatus") !== "in_progress") return false;
  const at = brandSnap.get("qoinBulkAt") as admin.firestore.Timestamp | undefined;
  if (!at) return false;
  return Date.now() - at.toMillis() <= bulkStaleMs;
}

export const BULK_IN_PROGRESS_MESSAGE = "이 브랜드에 일괄 적용이 진행 중이에요";
