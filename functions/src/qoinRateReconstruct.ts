/**
 * Qoin 적립률 point-in-time 재구성 (qoin_accrual_backfill spec §0 D0-1 ⓑ, §5.2).
 *
 * 주문이 완료된(`completedAt`) 시점에 유효했던 적립률을 `qoinRateHistory` 로 복원한다. **현재 문서값은 쓰지 않는다**
 * (이력이 전혀 없는데 현재값이 있는 경우는 "이력 밖에서 설정된 값" 이라 당시 값을 알 수 없으므로 fail-closed).
 * 해석은 라이브 트리거와 **같은** `classifySwitch` / `classifyRate` / `resolveEffectiveRate` 를 쓴다.
 *
 * 순수 부분(`pitRate` / `pitSwitch` / `reconstructRate`)은 Firebase 비의존이라 단위 테스트한다.
 * Firestore 읽기(`loadLayer`)만 Admin SDK 를 쓴다.
 */

import * as admin from "firebase-admin";
import {
  classifyRate,
  classifySwitch,
  RateCell,
  RateSource,
  resolveEffectiveRate,
  SwitchCell,
} from "./qoinRate";

/** `qoinRateHistory` 문서 중 재구성에 필요한 필드만. */
export interface HistEntry {
  field: string;
  changedAtMs: number;
  before: unknown;
  beforeState: unknown;
  beforeRaw: unknown;
  after: unknown;
}

/** 한 범위(매장 / 브랜드 / 전역)의 재구성 입력. */
export interface LayerInput {
  history: HistEntry[]; // changedAtMs asc
  currentRate: unknown; // 현재 문서의 적립률 필드 (이력 부재 시 "이력 밖 값" 탐지용 — 값 자체는 쓰지 않는다)
  currentSwitch: unknown; // 현재 문서의 스위치 필드 (전역은 undefined)
}

export interface ReconstructInput {
  anchorMs: number;
  store: LayerInput | null;
  brand: LayerInput | null;
  global: LayerInput;
  /** true 면 매장/브랜드 스위치를 전부 무시 (creditDisabledPeriod). */
  ignoreSwitch: boolean;
}

export type Reconstruction =
  | { status: "ok"; rate: number; source: RateSource; gaps: string[] }
  | { status: "disabled"; source: "store" | "brand"; gaps: string[] }
  | { status: "unrecoverable"; reason: string; gaps: string[] };

type Pit<C> = { cell: C } | { unrecoverable: string };

function sortedField(history: HistEntry[], field: string): HistEntry[] {
  return history.filter((h) => h.field === field).sort((a, b) => a.changedAtMs - b.changedAtMs);
}

/**
 * 이력에서 anchor 시점 값을 고른다 (D0-1 알고리즘 2~4).
 *  - anchor 이하의 최신 항목의 `after`
 *  - 없고 anchor 이후 최초 항목이 있으면 그 항목의 `before` (그 사이 변경이 없었다)
 *  - 이력이 아예 없으면 "설정된 적 없음"(absent). 단 현재값이 존재하면 이력 밖에서 설정된 값 → 복원 불가.
 */
function pick(
  entries: HistEntry[],
  anchorMs: number,
  currentRaw: unknown
): { from: "after"; e: HistEntry } | { from: "before"; e: HistEntry } | { from: "none" } | { unrecoverable: string } {
  let last: HistEntry | null = null;
  for (const e of entries) if (e.changedAtMs <= anchorMs) last = e;
  if (last) return { from: "after", e: last };
  const next = entries.find((e) => e.changedAtMs > anchorMs);
  if (next) return { from: "before", e: next };
  if (currentRaw !== undefined) return { unrecoverable: "untracked_current_value" };
  return { from: "none" };
}

export function pitRate(history: HistEntry[], anchorMs: number, currentRaw: unknown): Pit<RateCell> {
  const p = pick(sortedField(history, "accrualRate"), anchorMs, currentRaw);
  if ("unrecoverable" in p) return p;
  if (p.from === "none") return { cell: { kind: "absent" } };
  if (p.from === "after") {
    const a = p.e.after;
    return { cell: a === null || a === undefined ? { kind: "absent" } : classifyRate(a) };
  }
  // before: beforeState 로 "없음" / "값" / "무효" 를 구별한다.
  switch (p.e.beforeState) {
    case "absent":
      return { cell: { kind: "absent" } };
    case "value":
      return { cell: classifyRate(p.e.before) };
    case "invalid":
      return { cell: { kind: "invalid", raw: p.e.beforeRaw } };
    default:
      return { unrecoverable: "unknown_before_state" };
  }
}

export function pitSwitch(history: HistEntry[], anchorMs: number, currentRaw: unknown): Pit<SwitchCell> {
  const p = pick(sortedField(history, "accrualEnabled"), anchorMs, currentRaw);
  if ("unrecoverable" in p) return p;
  if (p.from === "none") return { cell: { kind: "enabled" } };
  if (p.from === "after") {
    const a = p.e.after;
    return { cell: a === null || a === undefined ? { kind: "enabled" } : classifySwitch(a) };
  }
  switch (p.e.beforeState) {
    case "absent":
      return { cell: { kind: "enabled" } };
    case "value":
      return { cell: classifySwitch(p.e.before) };
    case "invalid":
      return { cell: { kind: "invalid", raw: p.e.beforeRaw } };
    default:
      return { unrecoverable: "unknown_before_state" };
  }
}

export function reconstructRate(input: ReconstructInput): Reconstruction {
  const { anchorMs, store, brand, global, ignoreSwitch } = input;
  // 매장/브랜드는 Console 직접 편집이 감시되지 않는다 (hierarchy N6) — 항상 고지. 전역은 onQoinConfigWritten 가 포착한다.
  const gaps: string[] = [];
  if (store) gaps.push("store_console_untracked");
  if (brand) gaps.push("brand_console_untracked");

  const absentRate: Pit<RateCell> = { cell: { kind: "absent" } };
  const enabledSw: Pit<SwitchCell> = { cell: { kind: "enabled" } };

  const sr = store ? pitRate(store.history, anchorMs, store.currentRate) : absentRate;
  const br = brand ? pitRate(brand.history, anchorMs, brand.currentRate) : absentRate;
  const gr = pitRate(global.history, anchorMs, global.currentRate);
  const ss = ignoreSwitch || !store ? enabledSw : pitSwitch(store.history, anchorMs, store.currentSwitch);
  const bs = ignoreSwitch || !brand ? enabledSw : pitSwitch(brand.history, anchorMs, brand.currentSwitch);

  for (const [name, p] of [
    ["store_rate", sr],
    ["brand_rate", br],
    ["global_rate", gr],
    ["store_switch", ss],
    ["brand_switch", bs],
  ] as const) {
    if ("unrecoverable" in p) return { status: "unrecoverable", reason: `${name}:${p.unrecoverable}`, gaps };
  }

  const r = resolveEffectiveRate(
    (ss as { cell: SwitchCell }).cell,
    (sr as { cell: RateCell }).cell,
    (bs as { cell: SwitchCell }).cell,
    (br as { cell: RateCell }).cell,
    (gr as { cell: RateCell }).cell
  );
  if (!r.ok) return { status: "unrecoverable", reason: r.reason, gaps };
  if (r.disabled) return { status: "disabled", source: r.source, gaps };
  return { status: "ok", rate: r.rate, source: r.source, gaps };
}

// ── Firestore 읽기 (data 경계) ──────────────────────────────────────────────

function toEntry(d: admin.firestore.QueryDocumentSnapshot): HistEntry | null {
  const ts = d.get("changedAt");
  // serverTimestamp 가 확정되지 않았거나 깨진 항목은 시각을 알 수 없어 재구성에 쓰지 않는다.
  if (!ts || typeof ts.toMillis !== "function") return null;
  return {
    field: String(d.get("field") ?? ""),
    changedAtMs: ts.toMillis(),
    before: d.get("before"),
    beforeState: d.get("beforeState"),
    beforeRaw: d.get("beforeRaw"),
    after: d.get("after"),
  };
}

/** 범위 1곳의 현재 문서 + 이력 전량을 읽는다. 문서가 없으면 null (이력 서브컬렉션은 문서 삭제 후에도 남지만 대상이 아니다). */
export async function loadLayer(
  db: admin.firestore.Firestore,
  scope: "store" | "brand" | "global",
  id: string
): Promise<LayerInput | null> {
  const ref = scope === "global" ? db.collection("config").doc("qoin") : db.collection(scope === "brand" ? "brands" : "stores").doc(id);
  const [snap, histSnap] = await Promise.all([ref.get(), ref.collection("qoinRateHistory").orderBy("changedAt", "asc").get()]);
  if (!snap.exists && scope !== "global") return null;
  const history = histSnap.docs.map(toEntry).filter((e): e is HistEntry => e !== null);
  return {
    history,
    currentRate: snap.exists ? snap.get(scope === "global" ? "accrualRate" : "qoinAccrualRate") : undefined,
    currentSwitch: scope === "global" || !snap.exists ? undefined : snap.get("qoinAccrualEnabled"),
  };
}
