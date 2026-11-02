/**
 * setQoinSpendPolicy — callable (admin 전용). 전역 Qoin **사용 정책**(`config/qoin`)을 설정한다. qoin_spend spec §0 D-6, §7.1, §8.2.
 *
 * 요청: { spendEnabled?: boolean, minSpendUnit?: int (1~10000), minCashFloor?: int (1~100000), reason?: string }
 *       **적어도 하나**. 보낸 필드만 바꾼다 (나머지는 건드리지 않는다).
 * 응답: { changes: [{ field, before, after, historyId }], changed: boolean }
 *
 * `setQoinAccrualRate` 패턴 복제: 값 쓰기와 이력 생성을 **같은 트랜잭션**에 넣는다 → 이력 없는 변경이 구조적으로 불가능 (audit_trail §4-2).
 * 이력은 `config/qoin/qoinRateHistory` (field = 'spendEnabled' | 'minSpendUnit' | 'minCashFloor', scope 'global', source 'callable').
 * 값이 이미 같으면 아무것도 쓰지 않는다 (재시도해도 중복 이력 없음). 이력 문서 ID 는 트랜잭션 밖에서 한 번 만들어 재시도에도 같다.
 *
 * `config/qoin` 이 없으면 만들지 않는다 (failed-precondition) — 전역 문서 생성은 `setQoinAccrualRate` 의 일이고, 이 함수가
 * 적립률 없는 문서를 만들면 `enabled` 도 없는 반쪽 문서가 생긴다. 이 함수는 `accrualRate` / `enabled` 를 절대 쓰지 않는다.
 *
 * 켜기 안전장치: `spendEnabled: true` 는 (요청 또는 기존 문서 기준) `minCashFloor` 가 유효한 값일 때만 허용한다 — 최소현금 없이
 * 켜면 사용이 fail-closed 로 계속 막혀 "켰는데 안 되는" 상태가 되기 때문이다.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { describeRaw, parseReason, REGION, requireAdmin } from "./qoinAdmin";
import { isValidMinCashFloor, isValidMinSpendUnit } from "./qoinSpend";

const LOG = "[setQoinSpendPolicy]";

interface Request {
  spendEnabled?: unknown;
  minSpendUnit?: unknown;
  minCashFloor?: unknown;
  reason?: unknown;
}

const FIELDS = ["spendEnabled", "minSpendUnit", "minCashFloor"] as const;
type Field = (typeof FIELDS)[number];

const isValidFor = (f: Field, v: unknown): boolean =>
  f === "spendEnabled" ? typeof v === "boolean" : f === "minSpendUnit" ? isValidMinSpendUnit(v) : isValidMinCashFloor(v);

export const setQoinSpendPolicy = onCall({ region: REGION }, async (request) => {
  const db = admin.firestore();
  const uid = await requireAdmin(db, request);
  const data = (request.data ?? {}) as Request;

  // 서버 경계: 화면 검증은 우회된다는 전제.
  const next: Partial<Record<Field, boolean | number>> = {};
  for (const f of FIELDS) {
    if (data[f] === undefined) continue;
    if (!isValidFor(f, data[f])) throw new HttpsError("invalid-argument", `${f} is invalid`);
    next[f] = data[f] as boolean | number;
  }
  const requested = FIELDS.filter((f) => next[f] !== undefined);
  if (requested.length === 0) throw new HttpsError("invalid-argument", "at least one of spendEnabled|minSpendUnit|minCashFloor required");
  const reason = parseReason(data.reason);

  const configRef = db.collection("config").doc("qoin");
  const histCol = configRef.collection("qoinRateHistory");
  const historyRefs = new Map(requested.map((f) => [f, histCol.doc()] as const)); // 재시도에도 같은 ID

  const result = await db.runTransaction(async (t) => {
    const snap = await t.get(configRef);
    if (!snap.exists) throw new HttpsError("failed-precondition", "config/qoin missing");

    // 켜기 안전장치: 최종 문서 상태에서 minCashFloor 가 유효해야 한다.
    if (next.spendEnabled === true) {
      const floor = next.minCashFloor !== undefined ? next.minCashFloor : snap.get("minCashFloor");
      if (!isValidMinCashFloor(floor)) {
        throw new HttpsError("failed-precondition", "minCashFloor must be set before enabling spend");
      }
    }

    const updates: Record<string, boolean | number> = {};
    const changes: Array<{ field: Field; before: boolean | number | null; after: boolean | number; historyId: string }> = [];
    for (const f of requested) {
      const raw = snap.get(f);
      const after = next[f] as boolean | number;
      if (raw === after) continue; // 이미 같다 — 이력 없음
      const valid = isValidFor(f, raw);
      const before = valid ? (raw as boolean | number) : null;
      const beforeState = raw === undefined ? "absent" : valid ? "value" : "invalid";
      updates[f] = after;
      const historyRef = historyRefs.get(f) as admin.firestore.DocumentReference;
      t.set(historyRef, {
        scope: "global",
        targetId: "qoin",
        targetName: "전역 기본값",
        field: f,
        before,
        beforeState,
        beforeRaw: beforeState === "invalid" ? describeRaw(raw) : null,
        after,
        changedBy: uid,
        changedByRole: "admin",
        changedAt: FieldValue.serverTimestamp(),
        reason,
        source: "callable",
        op: "set",
      });
      changes.push({ field: f, before, after, historyId: historyRef.id });
    }
    if (changes.length > 0) t.update(configRef, updates); // 보낸 필드만. accrualRate / enabled 는 쓰지 않는다
    return changes;
  });

  console.info(`${LOG} ${result.length > 0 ? "applied" : "noop"}.`, { uid, changes: result.map((c) => `${c.field}:${c.before}->${c.after}`) });
  return { changes: result, changed: result.length > 0 };
});
