/**
 * 매장 판매 가능 판정 — Dart `lib/core/utils/store_sellability.dart` 의 TS 포팅 (한 사실에 하나).
 * payment_server_authority spec §6.3 · store_business_schedule spec §D1.
 * 교차 골든: `test_fixtures/store_sellability_contract.json`.
 *
 * 판정식 (Q1 ⓑ′): `status == 'approved' || (status == 'pending' && approvedAt != null)`
 *
 * - 입력은 **가공 전 원시값**이다. Dart 의 `EntityApprovalStatus.fromString` 이 알 수 없는 값/부재를 `approved` 로
 *   폴백하는 fail-open 인 것과 달리 돈 게이트는 **미지값·부재를 거절**한다 (spec §8.1).
 * - 영업 중 매장이 정보를 고치면 `status` 가 `pending` 으로 회귀하지만 `approvedAt` 이 남아 있으므로 막히지 않는다 (R2 불변식).
 * - Firebase 비의존 순수 함수. 시계(now)는 함수 안에서 읽지 않는다 — 호출자가 KST 로 계산해 주입한다.
 */
export type StoreGateReason =
  | "STORE_NOT_SELLABLE"
  | "STORE_TEMPORARILY_CLOSED"
  | "STORE_CLOSED_SCHEDULE";

/**
 * 판매 불가 **사유** 를 돌려주는 단일 판정. Dart `storeGateReason` 과 같은 규칙.
 * 우선순위: ① 승인 조건 실패 → STORE_NOT_SELLABLE ② 임시 휴업 → STORE_TEMPORARILY_CLOSED
 *          ③ 스케줄상 닫힘 → STORE_CLOSED_SCHEDULE ④ null.
 */
export function storeGateReason(args: {
  rawStatus: string | null;
  hasApprovedAt: boolean;
  temporaryClosed: boolean;
  scheduleClosedNow: boolean;
}): StoreGateReason | null {
  const approved =
    args.rawStatus === "approved" || (args.rawStatus === "pending" && args.hasApprovedAt);
  if (!approved) return "STORE_NOT_SELLABLE";
  if (args.temporaryClosed) return "STORE_TEMPORARILY_CLOSED";
  if (args.scheduleClosedNow) return "STORE_CLOSED_SCHEDULE";
  return null;
}

/** `scheduleClosedNow` 생략 = false (승인 전용 판정 — 예: 마이그레이션 이상치). */
export function canSellNow(args: {
  rawStatus: string | null;
  hasApprovedAt: boolean;
  temporaryClosed: boolean;
  scheduleClosedNow?: boolean;
}): boolean {
  return storeGateReason({ ...args, scheduleClosedNow: args.scheduleClosedNow ?? false }) === null;
}

// ═══════════════════════════════════════════════════════════════════════════
// 영업 스케줄 판정 (store_business_schedule spec §D1)
// ═══════════════════════════════════════════════════════════════════════════

/** 요일 하나의 영업 구간. "HH:mm" 24시 KST. open > close = 자정 넘김. 파싱 실패 / open == close = 그 요일 닫힘. */
export interface ScheduleDayHours {
  open: string;
  close: string;
}

/** 키 "1".."7" (1=월 … 7=일). 엔트리 부재 = 그날 휴무. 맵 자체가 null 이면 "시간 제한 없음". */
export type WeeklyHours = Record<string, ScheduleDayHours>;

export interface KstClock {
  /** 1=월 … 7=일 */
  weekday: number;
  /** 0..1439 */
  minuteOfDay: number;
  /** "YYYY-MM-DD" (KST) */
  dateKey: string;
}

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

const pad = (n: number, w = 2): string => String(n).padStart(w, "0");
const fmtDate = (y: number, m: number, d: number): string => `${pad(y, 4)}-${pad(m)}-${pad(d)}`;

/** 순간(instant) → KST 요일·분·날짜키. 서버는 신뢰 시계(`new Date()`)를 넣는다 (서버가 권위). */
export function kstClockOf(instant: Date): KstClock {
  const k = new Date(instant.getTime() + KST_OFFSET_MS);
  return {
    weekday: k.getUTCDay() === 0 ? 7 : k.getUTCDay(),
    minuteOfDay: k.getUTCHours() * 60 + k.getUTCMinutes(),
    dateKey: fmtDate(k.getUTCFullYear(), k.getUTCMonth() + 1, k.getUTCDate()),
  };
}

export type StoreOpenKind = "unrestricted" | "open" | "regularHoliday" | "outsideHours";

export interface StoreOpenState {
  kind: StoreOpenKind;
  /** "YYYY-MM-DDTHH:mm" (KST 벽시계). 닫혀 있을 때 다음 영업 시작 (8일 내, 없으면 null). */
  nextOpenAt: string | null;
  /** 영업 중일 때 이번 구간의 종료. */
  closeAt: string | null;
  /** 오늘 영업 구간 `09:00–18:00` (자정 넘김 `22:00–익일 02:00`). 없으면 null. */
  todayRange: string | null;
  isOpen: boolean;
}

interface Session {
  open: number;
  close: number;
}

function parseHm(s: unknown): number | null {
  if (typeof s !== "string") return null;
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(s);
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

function addDays(dateKey: string, n: number): string {
  const [y, m, d] = dateKey.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d) + n * 86400000);
  return fmtDate(t.getUTCFullYear(), t.getUTCMonth() + 1, t.getUTCDate());
}

const fmtHm = (minute: number): string => `${pad(Math.floor(minute / 60))}:${pad(minute % 60)}`;

/**
 * 지금 영업 중인가 + 다음 영업 시각 / 종료 시각. Dart `evaluateStoreOpenState` 와 같은 규칙 (교차 골든).
 * - weeklyHours === null → 시간 제한 없음. 빈 맵 = 점주가 저장한 전체 휴무.
 * - 오늘이 closedDateKeys 에 있으면 영업시간 무관 닫힘 (스케줄 미설정이어도 적용).
 * - 자정 넘김: [open, 24:00) ∪ 다음날 [00:00, close). 새벽 구간은 시작 요일 소속 → 전일 구간(전일이 closedDate 가 아닐 때)도 검사.
 */
export function evaluateStoreOpenState(args: {
  weeklyHours: WeeklyHours | null;
  closedDateKeys: ReadonlySet<string>;
  nowWeekday: number;
  nowMinuteOfDay: number;
  nowDateKey: string;
}): StoreOpenState {
  const { weeklyHours, closedDateKeys, nowWeekday, nowMinuteOfDay, nowDateKey } = args;
  const closedToday = closedDateKeys.has(nowDateKey);
  const mk = (
    kind: StoreOpenKind,
    over: Partial<Pick<StoreOpenState, "nextOpenAt" | "closeAt" | "todayRange">> = {}
  ): StoreOpenState => ({
    kind,
    nextOpenAt: over.nextOpenAt ?? null,
    closeAt: over.closeAt ?? null,
    todayRange: over.todayRange ?? null,
    isOpen: kind === "open" || kind === "unrestricted",
  });

  const sessionOn = (dateKey: string, weekday: number): Session | null => {
    if (closedDateKeys.has(dateKey)) return null;
    if (weeklyHours === null) return { open: 0, close: 1440 };
    const e = weeklyHours[String(weekday)];
    if (e == null) return null;
    const o = parseHm(e.open);
    const c = parseHm(e.close);
    if (o === null || c === null || o === c) return null;
    return { open: o, close: c };
  };

  const nextOpen = (): string | null => {
    for (let off = 0; off <= 8; off++) {
      const key = addDays(nowDateKey, off);
      const wd = ((nowWeekday - 1 + off) % 7) + 1;
      const s = sessionOn(key, wd);
      if (s === null) continue;
      if (off === 0 && s.open <= nowMinuteOfDay) continue;
      return `${key}T${fmtHm(s.open % 1440)}`;
    }
    return null;
  };

  if (weeklyHours === null) {
    if (!closedToday) return mk("unrestricted");
    return mk("regularHoliday", { nextOpenAt: nextOpen() });
  }

  const today = sessionOn(nowDateKey, nowWeekday);
  const overnight = (s: Session): boolean => s.close < s.open;
  const todayRange =
    today === null ? null : `${fmtHm(today.open)}–${overnight(today) ? "익일 " : ""}${fmtHm(today.close)}`;

  if (!closedToday) {
    if (today !== null) {
      if (!overnight(today) && nowMinuteOfDay >= today.open && nowMinuteOfDay < today.close) {
        return mk("open", { closeAt: `${nowDateKey}T${fmtHm(today.close)}`, todayRange });
      }
      if (overnight(today) && nowMinuteOfDay >= today.open) {
        return mk("open", { closeAt: `${addDays(nowDateKey, 1)}T${fmtHm(today.close)}`, todayRange });
      }
    }
    const prev = sessionOn(addDays(nowDateKey, -1), nowWeekday === 1 ? 7 : nowWeekday - 1);
    if (prev !== null && overnight(prev) && nowMinuteOfDay < prev.close) {
      return mk("open", { closeAt: `${nowDateKey}T${fmtHm(prev.close)}`, todayRange });
    }
  }

  return mk(today === null ? "regularHoliday" : "outsideHours", { nextOpenAt: nextOpen(), todayRange });
}

/** 지금 영업 중인가 (스케줄 미설정 = true). storeGateReason 의 `scheduleClosedNow` 는 `!isStoreOpenNow(...)`. */
export function isStoreOpenNow(args: {
  weeklyHours: WeeklyHours | null;
  closedDateKeys: ReadonlySet<string>;
  nowWeekday: number;
  nowMinuteOfDay: number;
  nowDateKey: string;
}): boolean {
  return evaluateStoreOpenState(args).isOpen;
}

// ── 원시 Firestore 값 파싱 (Dart `BusinessHoursModel.fromMap` / `StoreModel` closedDates 와 같은 규칙 — 교차 골든) ──

/**
 * `stores/{id}.businessHours` 원시값 → WeeklyHours | null.
 *  - `weeklyHours` 맵이 있으면 그대로 (빈 맵 = 전체 휴무). 키 "1".."7" + open/close 가 문자열인 엔트리만 유지.
 *  - legacy `{openTime, closeTime, closedDays}`: 둘 다 유효한 HH:mm 이면 7요일 동일 시간(closedDays 요일 제외). 아니면 null(제한 없음).
 *  - 그 외(부재/비객체/알 수 없는 구조) → null = 시간 제한 없음 (Q1: 미설정 기존 매장이 막히지 않게).
 */
export function parseWeeklyHours(raw: unknown): WeeklyHours | null {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return null;
  const obj = raw as Record<string, unknown>;
  const wh = obj.weeklyHours;
  if (wh !== undefined && wh !== null) {
    if (typeof wh !== "object" || Array.isArray(wh)) return null;
    const out: WeeklyHours = {};
    for (const [k, v] of Object.entries(wh as Record<string, unknown>)) {
      if (!/^[1-7]$/.test(k)) continue;
      if (v === null || typeof v !== "object") continue;
      const e = v as Record<string, unknown>;
      if (typeof e.open !== "string" || typeof e.close !== "string") continue;
      out[k] = { open: e.open, close: e.close };
    }
    return out;
  }
  if (typeof obj.openTime === "string" && typeof obj.closeTime === "string") {
    if (parseHm(obj.openTime) === null || parseHm(obj.closeTime) === null) return null;
    const closedDays = new Set(
      (Array.isArray(obj.closedDays) ? obj.closedDays : []).filter((x): x is number => typeof x === "number")
    );
    const out: WeeklyHours = {};
    for (let d = 1; d <= 7; d++) {
      if (!closedDays.has(d)) out[String(d)] = { open: obj.openTime, close: obj.closeTime };
    }
    return out;
  }
  return null;
}

/** `stores/{id}.closedDates` 원시값(Timestamp | Date 배열) → "YYYY-MM-DD"(KST) 키 집합. 해석 불가 원소는 무시. */
export function closedDateKeysFromRaw(raw: unknown): Set<string> {
  const keys = new Set<string>();
  if (!Array.isArray(raw)) return keys;
  for (const v of raw) {
    let d: Date | null = null;
    if (v instanceof Date) d = v;
    else if (v !== null && typeof v === "object" && typeof (v as { toDate?: unknown }).toDate === "function") {
      d = (v as { toDate: () => Date }).toDate();
    }
    if (d !== null && !Number.isNaN(d.getTime())) keys.add(kstClockOf(d).dateKey);
  }
  return keys;
}
