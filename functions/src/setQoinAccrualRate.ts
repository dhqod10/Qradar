/**
 * setQoinAccrualRate — callable (admin 전용). 전역 / 브랜드 / 매장 중 **한 범위**의 적립률을 설정한다.
 *
 * 요청: { scope: 'global'|'brand'|'store', targetId?: string,
 *         rate?: number (0 = 적립 안 함), clear?: true (상위 설정 따르기), reason?: string }
 *       rate 와 clear 는 정확히 하나. 전역은 0 / clear 불가 (항상 유효한 숫자여야 한다).
 * 응답: { before, after, historyId | null, changed }
 *
 * 값 쓰기와 이력 생성을 **같은 트랜잭션**에 넣는다 → 이력 없는 변경이 구조적으로 불가능 (H7, audit_trail §4-2).
 * 이력 문서 ID 는 트랜잭션 밖에서 한 번 만들어 재시도에도 같은 문서에 쓴다.
 * 값이 이미 같으면 아무것도 쓰지 않는다 (결과 불명 후 재시도해도 중복 이력이 생기지 않는다).
 *
 * 쓰는 필드: 매장/브랜드는 `qoinAccrualRate` 1개만 (status / updatedAt 불변 — 소유권 경계를 넘는 쓰기는 최소 필드).
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { isValidCallableRate } from "./qoinRate";
import { historyCollection, parseReason, REGION, requireAdmin, Scope } from "./qoinAdmin";

const LOG = "[setQoinAccrualRate]";

interface Request {
  scope?: unknown;
  targetId?: unknown;
  rate?: unknown;
  clear?: unknown;
  reason?: unknown;
}

export const setQoinAccrualRate = onCall({ region: REGION }, async (request) => {
  const db = admin.firestore();
  const uid = await requireAdmin(db, request);

  const data = (request.data ?? {}) as Request;
  const scope = data.scope;
  if (scope !== "global" && scope !== "brand" && scope !== "store") {
    throw new HttpsError("invalid-argument", "scope must be global|brand|store");
  }
  const s: Scope = scope;

  let targetId = "qoin";
  if (s !== "global") {
    if (typeof data.targetId !== "string" || data.targetId.length === 0 || data.targetId.includes("/")) {
      throw new HttpsError("invalid-argument", "targetId required");
    }
    targetId = data.targetId;
  }

  // rate 와 clear 는 정확히 하나.
  const hasRate = data.rate !== undefined;
  const hasClear = data.clear !== undefined;
  if (hasRate === hasClear) {
    throw new HttpsError("invalid-argument", "exactly one of rate|clear required");
  }
  let after: number | null;
  if (hasClear) {
    if (data.clear !== true) throw new HttpsError("invalid-argument", "clear must be true");
    if (s === "global") throw new HttpsError("invalid-argument", "global cannot be cleared");
    after = null;
  } else {
    // 서버 경계: 화면 검증은 우회된다는 전제. 전역은 0 불가.
    if (!isValidCallableRate(data.rate, s !== "global")) {
      throw new HttpsError("invalid-argument", "rate out of range");
    }
    after = data.rate;
  }
  const reason = parseReason(data.reason);

  const targetRef =
    s === "global"
      ? db.collection("config").doc("qoin")
      : db.collection(s === "brand" ? "brands" : "stores").doc(targetId);
  const field = s === "global" ? "accrualRate" : "qoinAccrualRate";
  const histCol = historyCollection(db, s, targetId);
  const historyRef = histCol.doc(); // 재시도에도 같은 ID
  const enabledHistoryRef = histCol.doc();

  const result = await db.runTransaction(async (t) => {
    const snap = await t.get(targetRef);
    if (!snap.exists && s !== "global") {
      throw new HttpsError("not-found", "target not found");
    }
    const rawBefore = snap.exists ? snap.get(field) : undefined;
    const before: number | null = typeof rawBefore === "number" ? rawBefore : null;
    // 무효였던 값(문자열 등)도 덮어써야 하므로 "같음" 판정은 number 일치로만 한다.
    if (snap.exists && rawBefore !== undefined && rawBefore === after) {
      return { changed: false as const, before, after };
    }
    if (rawBefore === undefined && after === null) {
      return { changed: false as const, before, after };
    }

    const targetName =
      s === "global" ? "전역 기본값" : ((snap.get("name") as string | undefined) ?? "");
    const base = {
      scope: s,
      targetId,
      targetName,
      changedBy: uid,
      changedByRole: "admin",
      changedAt: FieldValue.serverTimestamp(),
      reason,
      source: "callable",
    };

    if (!snap.exists) {
      // 전역 최초 생성: enabled:false 로 만든다 (fail-closed). enabled 이력도 같이 남긴다.
      t.set(targetRef, { accrualRate: after, enabled: false });
      t.set(enabledHistoryRef, {
        ...base,
        field: "enabled",
        before: null,
        after: false,
        op: "set",
      });
    } else {
      t.update(targetRef, { [field]: after === null ? FieldValue.delete() : after });
    }
    t.set(historyRef, {
      ...base,
      field: "accrualRate",
      before,
      after,
      op: after === null ? "clear" : "set",
    });
    return { changed: true as const, before, after };
  });

  console.info(`${LOG} ${result.changed ? "applied" : "noop"}.`, {
    scope: s,
    targetId,
    before: result.before,
    after: result.after,
    uid,
  });
  return {
    before: result.before,
    after: result.after,
    historyId: result.changed ? historyRef.id : null,
    changed: result.changed,
  };
});
