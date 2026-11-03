/**
 * adminDeleteUser — callable (admin 전용). 관리자 **강제 탈퇴** (admin_user_moderation Phase 1, customer 전용).
 *
 * 입력 { targetUid, reason?, dryRun? } — dryRun:true 는 쓰기 0건, `{inFlightOrders, qoinToForfeit, canDelete}`.
 * 새 익명화 로직을 만들지 않는다 — account_deletion 코어 `runDeleteMyAccount` 를 actorUid=admin 으로 재사용한다
 * (진행중 주문 가드 · phase 멱등 · dryRun · Auth 삭제 승계). 이력은 `accountDeletionHistory` (`deletedBy`=admin uid, `byAdmin:true`).
 *
 * 에러 토큰 (message 끝 `[TOKEN]`):
 *   [CANNOT_MODERATE_ADMIN]       대상이 admin (또는 본인)
 *   [FORCE_DELETE_CUSTOMER_ONLY]  대상이 owner/brand (Phase 2)
 *   [ACCOUNT_HAS_INFLIGHT_ORDERS] 진행중 주문 존재 (코어 토큰 승계 — self-탈퇴와 같은 문자열)
 */
import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { parseReason, REGION, requireAdmin } from "./qoinAdmin";
import { AccountPorts, DeleteAccountResult, makeFirestoreAccountPorts, runDeleteMyAccount } from "./deleteMyAccount";

export const CANNOT_MODERATE_ADMIN_TOKEN = "CANNOT_MODERATE_ADMIN";
export const FORCE_DELETE_CUSTOMER_ONLY_TOKEN = "FORCE_DELETE_CUSTOMER_ONLY";

export async function runAdminDeleteUser(
  ports: AccountPorts,
  args: { actorUid: string; targetUid: string; reason: string | null; dryRun: boolean }
): Promise<DeleteAccountResult> {
  const { actorUid, targetUid } = args;
  if (targetUid === actorUid) {
    throw new HttpsError("permission-denied", `본인 계정은 처리할 수 없어요 [${CANNOT_MODERATE_ADMIN_TOKEN}]`, {
      reason: CANNOT_MODERATE_ADMIN_TOKEN,
    });
  }
  const user = await ports.readUser(targetUid);
  if (user && user.role === "admin") {
    throw new HttpsError("permission-denied", `관리자 계정은 처리할 수 없어요 [${CANNOT_MODERATE_ADMIN_TOKEN}]`, {
      reason: CANNOT_MODERATE_ADMIN_TOKEN,
    });
  }
  if (user && user.role !== undefined && user.role !== "customer") {
    throw new HttpsError("failed-precondition", `customer 계정만 강제 탈퇴할 수 있어요 [${FORCE_DELETE_CUSTOMER_ONLY_TOKEN}]`, {
      reason: FORCE_DELETE_CUSTOMER_ONLY_TOKEN,
    });
  }
  return runDeleteMyAccount(ports, { uid: targetUid, reason: args.reason, dryRun: args.dryRun, actorUid });
}

export const adminDeleteUser = onCall({ region: REGION, timeoutSeconds: 120 }, async (request) => {
  const db = admin.firestore();
  const actorUid = await requireAdmin(db, request);
  const d = (request.data ?? {}) as { targetUid?: unknown; reason?: unknown; dryRun?: unknown };
  if (typeof d.targetUid !== "string" || d.targetUid.length === 0 || d.targetUid.includes("/")) {
    throw new HttpsError("invalid-argument", "targetUid required");
  }
  const dryRun = d.dryRun === true;
  const result = await runAdminDeleteUser(makeFirestoreAccountPorts(db), {
    actorUid,
    targetUid: d.targetUid,
    reason: parseReason(d.reason),
    dryRun,
  });
  console.info("[adminDeleteUser]", dryRun ? "dryRun" : "run", { actorUid, targetUid: d.targetUid });
  return result;
});
