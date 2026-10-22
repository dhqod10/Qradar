/**
 * onQoinConfigWritten — out-of-band 감시 (onDocumentWritten `config/qoin`).
 *
 * Firebase Console / Admin SDK 쓰기는 Rules 를 우회한다. 전역 적립률이 콘솔에서 바뀌어도,
 * `enabled` 비상 정지 토글(클라이언트 직접 쓰기 — 단순성 유지, spec §4-⑩)이어도 이력이 남게 한다.
 *
 *   - `accrualRate` / `enabled` 가 바뀐 필드마다 1건, 그 외 변경은 early return.
 *   - callable 이 방금 남긴 이력(source: 'callable', after 일치, 이벤트 시각 ±2분)이 있으면 중복 기록하지 않는다.
 *   - 직접 수정은 `source: 'direct'` / `changedBy: null` — 행위자는 알 수 없고 before / after / 시각은 확실히 남는다.
 *   - 이력 문서 ID 를 `direct_{eventId}_{field}` 로 고정해 이벤트 재전달에도 중복되지 않는다 (create 충돌 무시).
 *
 * `stores` / `brands` 의 Console 직접 편집은 감시하지 않는다 (N6, 2차).
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { REGION } from "./qoinAdmin";

const LOG = "[onQoinConfigWritten]";
const CALLABLE_WINDOW_MS = 2 * 60 * 1000;
const FIELDS = ["accrualRate", "enabled"] as const;

function pick(snap: admin.firestore.DocumentSnapshot | undefined, field: string): unknown {
  if (!snap || !snap.exists) return undefined;
  return snap.get(field);
}

function same(a: unknown, b: unknown): boolean {
  return a === b;
}

/** 이력에 넣을 값: number | boolean | null (그 외·부재는 null). */
function recordable(v: unknown): number | boolean | null {
  return typeof v === "number" || typeof v === "boolean" ? v : null;
}

export const onQoinConfigWritten = onDocumentWritten(
  { document: "config/{docId}", region: REGION },
  async (event) => {
    if (event.params.docId !== "qoin") return;

    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    const eventMs = event.time ? Date.parse(event.time) : Date.now();
    const db = admin.firestore();
    const histCol = db.collection("config").doc("qoin").collection("qoinRateHistory");

    // 최근 이력 몇 건만 본다 (단일 필드 정렬 — 복합 인덱스 불필요).
    let recent: admin.firestore.QueryDocumentSnapshot[] | null = null;

    for (const field of FIELDS) {
      const b = pick(beforeSnap, field);
      const a = pick(afterSnap, field);
      if (same(b, a)) continue;

      if (recent === null) {
        recent = (await histCol.orderBy("changedAt", "desc").limit(10).get()).docs;
      }
      const matchedCallable = recent.some((d) => {
        if (d.get("field") !== field || d.get("source") !== "callable") return false;
        if (!same(d.get("after"), recordable(a))) return false;
        const ts = d.get("changedAt") as admin.firestore.Timestamp | null;
        return ts !== null && Math.abs(ts.toMillis() - eventMs) <= CALLABLE_WINDOW_MS;
      });
      if (matchedCallable) {
        console.info(`${LOG} skipped_callable_recorded.`, { field });
        continue;
      }

      try {
        await histCol.doc(`direct_${event.id}_${field}`).create({
          scope: "global",
          targetId: "qoin",
          targetName: "전역 기본값",
          field,
          before: recordable(b),
          after: recordable(a),
          changedBy: null,
          changedByRole: null,
          changedAt: FieldValue.serverTimestamp(),
          reason: null,
          source: "direct",
          op: recordable(a) === null ? "clear" : "set",
        });
        console.info(`${LOG} recorded_direct.`, { field, before: b, after: a });
      } catch (e) {
        // ALREADY_EXISTS (코드 6) = 이벤트 재전달 → 이미 기록됨. 그 외는 재시도 없이 로그.
        if ((e as { code?: number }).code === 6) continue;
        throw e;
      }
    }
  }
);
