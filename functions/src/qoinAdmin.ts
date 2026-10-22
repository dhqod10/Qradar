/**
 * Qoin 적립률 callable 공통 — admin 서버 재검증 + 이력 문서 생성 헬퍼.
 *
 * 클라이언트가 보낸 역할을 믿지 않는다 (spec H2). `users/{uid}.role === 'admin'` 을 서버에서 읽는다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
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

// ── 일괄 적용 포인터 상태 기계 (spec §21.2) ─────────────────────────────────────

/**
 * 브랜드 문서 포인터 `qoinBulkStatus` 의 값. **포인터는 지워지는 값이 아니라 상태 기계다** —
 * 3필드(`qoinBulkHistoryId/Status/At`)를 삭제하지 않고 종결 상태로 전이시킨다.
 * Dart 쪽 출처는 `QoinBulkStatus` enum 1곳. 구버전 앱은 모르는 코드를 null(= 중단 없음)로 읽는다.
 */
export const BULK_STATUS = {
  inProgress: "in_progress",
  partial: "partial",
  completed: "completed",
  superseded: "superseded",
} as const;

/**
 * 포인터가 "끝나지 않은 일괄 적용" 인가: `partial`, 또는 갱신이 [staleMs] 넘게 없는 `in_progress`(인스턴스가 중간에 죽은 상태).
 * **화면의 `resolveBulkBanner` 와 같은 사실에 대한 같은 기준이다** — 판정은 stale 을 중단으로 읽는데 마감이 `partial` 만 보면
 * 포인터가 영구히 남고 `이어서 적용` 이 항상 실패한다 (3차 F-2). 기준 시간은 `BULK_STALE_MS` 1곳이며
 * `test_fixtures/qoin_bulk_policy.json` 을 Dart·TS 테스트가 같이 읽어 두 상수가 어긋나지 않게 묶는다.
 */
export function isBulkUnfinished(brandSnap: admin.firestore.DocumentSnapshot, staleMs: number): boolean {
  if (!brandSnap.exists) return false;
  const st = brandSnap.get("qoinBulkStatus");
  if (st === BULK_STATUS.partial) return true;
  if (st !== BULK_STATUS.inProgress) return false;
  const at = brandSnap.get("qoinBulkAt") as admin.firestore.Timestamp | undefined;
  if (!at) return true;
  return Date.now() - at.toMillis() > staleMs;
}

/** 포인터가 종결 상태(`completed` / `superseded`) 인가. `partial` 은 종결이 아니다. */
export function isBulkTerminal(brandSnap: admin.firestore.DocumentSnapshot): boolean {
  if (!brandSnap.exists) return false;
  const st = brandSnap.get("qoinBulkStatus");
  return st === BULK_STATUS.completed || st === BULK_STATUS.superseded;
}

/**
 * 트랜잭션 안에서 끝나지 않은(`partial` 또는 stale `in_progress`) 포인터가 가리키는 옛 이력 문서를 읽는다. **모든 write 보다 먼저 호출해야 한다**
 * (Firestore 트랜잭션은 read 가 write 앞이어야 한다). `partial` 이 아니거나 id 가 없으면 null.
 */
export async function readPartialHistory(
  t: admin.firestore.Transaction,
  brandSnap: admin.firestore.DocumentSnapshot,
  histCol: admin.firestore.CollectionReference,
  staleMs: number
): Promise<admin.firestore.DocumentSnapshot | null> {
  if (!isBulkUnfinished(brandSnap, staleMs)) return null;
  const id = brandSnap.get("qoinBulkHistoryId");
  if (typeof id !== "string" || id.length === 0) return null;
  return t.get(histCol.doc(id));
}

/**
 * `partial` 뒤에 어떤 설정이 성공했을 때 옛 이력을 `superseded` 로 마감한다 (이력 문서는 삭제하지 않는다 — append-only 성질).
 * `supersededBy` = 새 일괄 적용의 historyId, 단건·스위치는 null. 같은 트랜잭션에서 포인터 전이와 함께 쓴다.
 */
export function supersedePartialHistory(
  t: admin.firestore.Transaction,
  oldHist: admin.firestore.DocumentSnapshot | null,
  uid: string,
  supersededBy: string | null
): void {
  if (!oldHist || !oldHist.exists) return;
  t.update(oldHist.ref, {
    status: "superseded",
    supersededBy,
    supersededAt: FieldValue.serverTimestamp(),
    supersededByUid: uid,
  });
}

/** 같은 값 + 지울 개별 설정 0 + `partial`: 남은 일이 없으므로 옛 이력을 `completed` 로 마감한다 (`nothing_left`). */
export function completePartialHistoryNothingLeft(
  t: admin.firestore.Transaction,
  oldHist: admin.firestore.DocumentSnapshot | null,
  uid: string
): void {
  if (!oldHist || !oldHist.exists) return;
  t.update(oldHist.ref, {
    status: "completed",
    closedReason: "nothing_left",
    closedBy: uid,
    closedAt: FieldValue.serverTimestamp(),
  });
}

/** 단건 적립률·스위치 성공 시 `partial` 포인터를 `superseded` 로 전이시키는 브랜드 문서 쓰기 필드. */
export function supersededPointerFields(): Record<string, unknown> {
  return { qoinBulkStatus: BULK_STATUS.superseded, qoinBulkAt: FieldValue.serverTimestamp() };
}

// TRANSITIONAL(spec §20.4.5): 레거시 `qoinAccrualRate: 0` 가드 문구 — 일괄·단건 두 경로가 공유한다 (보호가 한 경로에만 걸리지 않게).
export const LEGACY_MESSAGE_PREFIX = "레거시 0% 매장이 있어요. Qoin 설정 허브에서 마이그레이션을 먼저 실행하세요";
