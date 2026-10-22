/**
 * setQoinAccrualEnabled — callable (admin 전용). 매장 / 브랜드의 **적립 스위치**(`qoinAccrualEnabled`)를 켜고 끈다.
 *
 * 요청: { scope: 'store'|'brand', targetId, enabled: boolean, reason?: string }
 *       scope 'global' 은 거부 — 전역 비상 정지는 `config/qoin.enabled` (적립·회수 둘 다 멈추는 별개의 스위치).
 * 응답: { before: boolean|null, after: boolean|null, historyId: string|null, changed: boolean }
 *       null = 필드 부재 = 적립 사용 (기본값). `false` 만 저장하고, 다시 켜면 필드를 삭제한다 (spec §20.1.3).
 *
 * 스위치는 적립이 **발생하는지 자체**를 결정하므로 적립률과 완전히 같게 다룬다 (audit_trail §4):
 * 클라이언트 쓰기 전 역할 차단(Rules) · 서버 admin 재검증 · 값과 이력 1건을 **같은 트랜잭션** · 값이 같으면 아무것도
 * 쓰지 않는다 · 일괄 적용 진행 중 거부 (매장이면 소속 브랜드, 브랜드면 자신).
 * 일괄 적용(`applyBrandQoinRate`)은 이 필드를 읽지도 쓰지도 않는다 (Q1 — 덮어쓰기가 스키마 차원에서 불가능).
 * 브랜드 scope 에서 `partial` 포인터가 있으면 값 변경 성공 시 같은 트랜잭션에서 옛 이력을 `superseded` 로 마감하고
 * 포인터를 `superseded` 로 전이한다 (spec §21.2). 값이 같은 noop 은 닫지 않는다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { BULK_STALE_MS, isValidCallableSwitch } from "./qoinRate";
import {
  BULK_IN_PROGRESS_MESSAGE,
  historyCollection,
  isBulkInProgress,
  isBulkUnfinished,
  parseReason,
  readPartialHistory,
  REGION,
  requireAdmin,
  supersededPointerFields,
  supersedePartialHistory,
  switchBeforeInfo,
} from "./qoinAdmin";

const LOG = "[setQoinAccrualEnabled]";

interface Request {
  scope?: unknown;
  targetId?: unknown;
  enabled?: unknown;
  reason?: unknown;
}

export const setQoinAccrualEnabled = onCall({ region: REGION }, async (request) => {
  const db = admin.firestore();
  const uid = await requireAdmin(db, request);

  const data = (request.data ?? {}) as Request;
  const scope = data.scope;
  if (scope !== "store" && scope !== "brand") {
    // 'global' 포함. 전역은 별도 비상 정지 경로.
    throw new HttpsError("invalid-argument", "scope must be store|brand");
  }
  if (typeof data.targetId !== "string" || data.targetId.length === 0 || data.targetId.includes("/")) {
    throw new HttpsError("invalid-argument", "targetId required");
  }
  if (!isValidCallableSwitch(data.enabled)) {
    throw new HttpsError("invalid-argument", "enabled must be boolean");
  }
  const targetId = data.targetId;
  const enabled: boolean = data.enabled;
  const reason = parseReason(data.reason);

  const targetRef = db.collection(scope === "brand" ? "brands" : "stores").doc(targetId);
  const historyRef = historyCollection(db, scope, targetId).doc(); // 재시도에도 같은 ID

  const result = await db.runTransaction(async (t) => {
    const snap = await t.get(targetRef);
    if (!snap.exists) throw new HttpsError("not-found", "target not found");

    let oldPartial: admin.firestore.DocumentSnapshot | null = null;
    if (scope === "brand") {
      if (isBulkInProgress(snap, BULK_STALE_MS)) {
        throw new HttpsError("failed-precondition", BULK_IN_PROGRESS_MESSAGE);
      }
      // partial 이면 옛 이력도 읽는다 (read 는 write 앞). partial 이 아니면 추가 read 0.
      oldPartial = await readPartialHistory(t, snap, historyCollection(db, "brand", targetId), BULK_STALE_MS);
    } else {
      const brandId = snap.get("brandId");
      if (typeof brandId === "string" && brandId.length > 0) {
        const brandSnap = await t.get(db.collection("brands").doc(brandId));
        if (isBulkInProgress(brandSnap, BULK_STALE_MS)) {
          throw new HttpsError("failed-precondition", BULK_IN_PROGRESS_MESSAGE);
        }
      }
    }

    const raw = snap.get("qoinAccrualEnabled");
    const info = switchBeforeInfo(raw);
    const after: boolean | null = enabled ? null : false;

    // 값이 이미 같으면 아무것도 쓰지 않는다 (재시도 중복 이력 방지).
    if ((enabled === false && raw === false) || (enabled === true && raw === undefined)) {
      return { changed: false as const, before: info.before, after };
    }

    t.update(targetRef, {
      qoinAccrualEnabled: enabled ? FieldValue.delete() : false,
      ...(scope === "brand" && isBulkUnfinished(snap, BULK_STALE_MS) ? supersededPointerFields() : {}),
    });
    supersedePartialHistory(t, oldPartial, uid, null);
    t.set(historyRef, {
      scope,
      targetId,
      targetName: (snap.get("name") as string | undefined) ?? "",
      field: "accrualEnabled",
      before: info.before,
      beforeState: info.beforeState,
      beforeRaw: info.beforeRaw,
      after,
      op: after === null ? "clear" : "set",
      changedBy: uid,
      changedByRole: "admin",
      changedAt: FieldValue.serverTimestamp(),
      reason,
      source: "callable",
    });
    return { changed: true as const, before: info.before, after };
  });

  console.info(`${LOG} ${result.changed ? "applied" : "noop"}.`, { scope, targetId, enabled, uid });
  return {
    before: result.before,
    after: result.after,
    historyId: result.changed ? historyRef.id : null,
    changed: result.changed,
  };
});
