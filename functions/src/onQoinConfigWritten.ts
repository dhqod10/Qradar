/**
 * onQoinConfigWritten — out-of-band 감시 (onDocumentWritten `config/qoin`).
 *
 * Firebase Console / Admin SDK 쓰기는 Rules 를 우회한다. 전역 적립률이 콘솔에서 바뀌어도,
 * `enabled` 비상 정지 토글(클라이언트 직접 쓰기 — 단순성 유지)이어도 이력이 남게 한다.
 *
 *   - `accrualRate` / `enabled` / 사용 정책(`spendEnabled` / `minSpendUnit` / `minCashFloor`, qoin_spend) 이 바뀐 필드마다 1건, 그 외 변경은 early return.
 *     `enabled` 의 이력 `field` 는 `'globalEnabled'` (매장·브랜드 스위치 `'accrualEnabled'` 와 구별).
 *   - callable 이 방금 남긴 이력(source: 'callable', after 일치, 이벤트 시각 ±2분)이 있으면 중복 기록하지 않는다.
 *   - **F3**: 앱 토글은 `enabledChangedBy`(=auth uid, Rules 가 강제) + `enabledChangedAt` 을 같이 쓴다.
 *     `enabledChangedAt` 이 이번 쓰기로 바뀌었으면 `source: 'app_direct'` + 행위자 uid 를 남긴다.
 *     바뀌지 않았으면(= 필드를 안 쓰는 Console 편집) `source: 'direct'` / `changedBy: null` — 행위자는 알 수 없고
 *     before / after / 시각만 확실히 남는다.
 *   - `beforeState` / `beforeRaw` 로 이전 값이 "없음" 인지 "무효" 인지 구별한다 (부가 B).
 *   - 이력 문서 ID 를 `{source}_{eventId}_{field}` 로 고정해 이벤트 재전달에도 중복되지 않는다 (create 충돌 무시).
 *
 * `stores` / `brands` 의 Console 직접 편집은 감시하지 않는다 (N6, 2차).
 */

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { describeRaw, REGION } from "./qoinAdmin";
import { classifyRate } from "./qoinRate";
import { isValidMinCashFloor, isValidMinSpendUnit } from "./qoinSpend";

const LOG = "[onQoinConfigWritten]";
const CALLABLE_WINDOW_MS = 2 * 60 * 1000;
const FIELDS = ["accrualRate", "enabled", "spendEnabled", "minSpendUnit", "minCashFloor"] as const;
/** config 필드명 → 이력 `field` 값. 사용 정책(qoin_spend)은 필드명 그대로 (setQoinSpendPolicy 와 같다). */
const HISTORY_FIELD = {
  accrualRate: "accrualRate",
  enabled: "globalEnabled",
  spendEnabled: "spendEnabled",
  minSpendUnit: "minSpendUnit",
  minCashFloor: "minCashFloor",
} as const;

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

/** 이전 값 → beforeState / beforeRaw. 전역 적립률은 유효 범위 number, enabled·spendEnabled 는 boolean, 사용 정책 정수는 범위 내 정수만 'value'. */
function beforeInfo(field: (typeof FIELDS)[number], raw: unknown) {
  if (raw === undefined) return { beforeState: "absent", beforeRaw: null as string | null };
  const isValue =
    field === "accrualRate"
      ? classifyRate(raw).kind === "valid"
      : field === "minSpendUnit"
        ? isValidMinSpendUnit(raw)
        : field === "minCashFloor"
          ? isValidMinCashFloor(raw)
          : typeof raw === "boolean";
  return isValue
    ? { beforeState: "value", beforeRaw: null as string | null }
    : { beforeState: "invalid", beforeRaw: describeRaw(raw) };
}

function millisOf(v: unknown): number | null {
  return v instanceof Timestamp ? v.toMillis() : null;
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
        if (d.get("field") !== HISTORY_FIELD[field] || d.get("source") !== "callable") return false;
        if (!same(d.get("after"), recordable(a))) return false;
        const ts = d.get("changedAt") as admin.firestore.Timestamp | null;
        return ts !== null && Math.abs(ts.toMillis() - eventMs) <= CALLABLE_WINDOW_MS;
      });
      if (matchedCallable) {
        console.info(`${LOG} skipped_callable_recorded.`, { field });
        continue;
      }

      // F3: 앱이 이번 쓰기로 enabledChangedAt 을 갱신했으면 행위자가 있다 (Rules 가 uid 일치를 강제).
      let actor: string | null = null;
      if (field === "enabled") {
        const by = pick(afterSnap, "enabledChangedBy");
        const atBefore = millisOf(pick(beforeSnap, "enabledChangedAt"));
        const atAfter = millisOf(pick(afterSnap, "enabledChangedAt"));
        if (typeof by === "string" && by.length > 0 && atAfter !== null && atAfter !== atBefore) actor = by;
      }
      const source = actor ? "app_direct" : "direct";
      try {
        await histCol.doc(`${source}_${event.id}_${field}`).create({
          scope: "global",
          targetId: "qoin",
          targetName: "전역 기본값",
          field: HISTORY_FIELD[field],
          before: recordable(b),
          ...beforeInfo(field, b),
          after: recordable(a),
          changedBy: actor,
          changedByRole: actor ? "admin" : null,
          changedAt: FieldValue.serverTimestamp(),
          reason: null,
          source,
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
