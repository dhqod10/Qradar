/**
 * setUserSuspension — callable (admin 전용). 계정 **정지 / 해제** (admin_user_moderation, 전 역할 대상).
 *
 * 입력 { targetUid, action:'suspend'|'unsuspend', reason? }
 * 응답 { changed, action, historyId }  (이미 같은 상태면 changed:false — 이력·Auth 재조치 없음)
 *
 * 순서 (멱등 재진입 가능): ① 대상 read + admin 대상 거부  ② 이력 `userModerationHistory/{uid}_{millis}`
 *   ③ users 플래그(Admin SDK, Rules 우회)  ④ Auth updateUser({disabled})  ⑤ 정지 시 revokeRefreshTokens.
 * 진짜 집행은 ④⑤ (제공자 무관). users.suspended 는 앱 UX·게이트 판독용 신호다.
 * Firestore 가 이미 목표 상태여도 Auth 가 어긋나 있을 수 있으므로(③ 후 ④ 실패) 재호출 시 Auth 조치는 항상 다시 맞춘다 —
 * 단 이력은 Firestore 상태가 실제로 바뀔 때만 남긴다.
 *
 * 에러 토큰: [CANNOT_MODERATE_ADMIN] (대상이 admin 이거나 본인)
 */
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { parseReason, REGION, requireAdmin } from "./qoinAdmin";

type RawDoc = Record<string, unknown>;
export type SuspensionAction = "suspend" | "unsuspend";
export const CANNOT_MODERATE_ADMIN = "CANNOT_MODERATE_ADMIN";

export interface SuspensionPorts {
  readUser(uid: string): Promise<RawDoc | null>;
  /** 이력 1건 + users 플래그를 한 번에(원자). */
  commit(args: {
    historyId: string;
    history: Record<string, unknown>;
    uid: string;
    userPatch: Record<string, unknown>;
  }): Promise<void>;
  /** Auth disabled 설정. 계정이 이미 없으면 무시(false 반환). */
  setAuthDisabled(uid: string, disabled: boolean): Promise<boolean>;
  revokeTokens(uid: string): Promise<void>;
}

export interface SuspensionResult {
  changed: boolean;
  action: SuspensionAction;
  historyId: string | null;
}

export async function runSetUserSuspension(
  ports: SuspensionPorts,
  args: { actorUid: string; targetUid: string; action: SuspensionAction; reason: string | null; now?: () => number }
): Promise<SuspensionResult> {
  const { actorUid, targetUid, action, reason } = args;
  if (targetUid === actorUid) {
    throw new HttpsError("permission-denied", `본인 계정은 처리할 수 없어요 [${CANNOT_MODERATE_ADMIN}]`, { reason: CANNOT_MODERATE_ADMIN });
  }
  const user = await ports.readUser(targetUid);
  if (!user) throw new HttpsError("not-found", "사용자를 찾을 수 없습니다.");
  if (user.role === "admin") {
    throw new HttpsError("permission-denied", `관리자 계정은 처리할 수 없어요 [${CANNOT_MODERATE_ADMIN}]`, { reason: CANNOT_MODERATE_ADMIN });
  }

  const suspend = action === "suspend";
  const wasSuspended = user.suspended === true;
  const changed = wasSuspended !== suspend;
  let historyId: string | null = null;

  if (changed) {
    historyId = `${targetUid}_${(args.now ?? Date.now)()}`;
    const userPatch: Record<string, unknown> = suspend
      ? {
          suspended: true,
          suspendedAt: FieldValue.serverTimestamp(),
          suspendedBy: actorUid,
          suspensionReason: reason ?? FieldValue.delete(),
        }
      : {
          suspended: false,
          suspendedAt: FieldValue.delete(),
          suspendedBy: FieldValue.delete(),
          suspensionReason: FieldValue.delete(),
        };
    await ports.commit({
      historyId,
      uid: targetUid,
      userPatch,
      history: {
        uid: targetUid,
        targetUid,
        action,
        before: { suspended: wasSuspended },
        after: { suspended: suspend },
        role: typeof user.role === "string" ? user.role : null,
        changedBy: actorUid,
        changedAt: FieldValue.serverTimestamp(),
        reason,
        authAction: suspend ? "disabled+revoked" : "enabled",
      },
    });
  }

  // Auth 집행 — changed 여부와 무관하게 맞춘다 (③ 후 ④ 실패 재진입).
  await ports.setAuthDisabled(targetUid, suspend);
  if (suspend) await ports.revokeTokens(targetUid);

  return { changed, action, historyId };
}

export function makeFirestoreSuspensionPorts(db: admin.firestore.Firestore): SuspensionPorts {
  return {
    async readUser(uid) {
      const s = await db.collection("users").doc(uid).get();
      return s.exists ? (s.data() as RawDoc) : null;
    },
    async commit({ historyId, history, uid, userPatch }) {
      const batch = db.batch();
      batch.set(db.collection("userModerationHistory").doc(historyId), history);
      batch.update(db.collection("users").doc(uid), userPatch);
      await batch.commit();
    },
    async setAuthDisabled(uid, disabled) {
      try {
        await admin.auth().updateUser(uid, { disabled });
        return true;
      } catch (e) {
        if ((e as { code?: string }).code === "auth/user-not-found") return false;
        throw e;
      }
    },
    async revokeTokens(uid) {
      try {
        await admin.auth().revokeRefreshTokens(uid);
      } catch (e) {
        if ((e as { code?: string }).code === "auth/user-not-found") return;
        throw e;
      }
    },
  };
}

export const setUserSuspension = onCall({ region: REGION }, async (request) => {
  const db = admin.firestore();
  const actorUid = await requireAdmin(db, request);
  const d = (request.data ?? {}) as { targetUid?: unknown; action?: unknown; reason?: unknown };
  if (typeof d.targetUid !== "string" || d.targetUid.length === 0 || d.targetUid.includes("/")) {
    throw new HttpsError("invalid-argument", "targetUid required");
  }
  if (d.action !== "suspend" && d.action !== "unsuspend") {
    throw new HttpsError("invalid-argument", "action must be suspend|unsuspend");
  }
  const result = await runSetUserSuspension(makeFirestoreSuspensionPorts(db), {
    actorUid,
    targetUid: d.targetUid,
    action: d.action,
    reason: parseReason(d.reason),
  });
  console.info("[setUserSuspension]", result.changed ? "applied" : "noop", { actorUid, targetUid: d.targetUid, action: d.action });
  return result;
});
