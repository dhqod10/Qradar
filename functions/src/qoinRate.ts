/**
 * Qoin 적립률 — 경계 상수 + 계층 해석 (순수 함수, Firebase 비의존).
 *
 * **이 파일이 TS 쪽 경계 상수의 유일한 출처다.** (Dart 쪽 출처는 `QoinPolicy` 1곳)
 * 다른 파일에서 0.001 / 0.2 를 다시 선언하지 않는다 — 1차 F3 (화면은 0.1~20% 인데
 * CF 는 `0..1`) 의 재발 방지. 진리표는 `test_fixtures/qoin_rate_truth_table.json` 을
 * Dart / TS 양쪽 테스트가 같이 읽는다.
 *
 * 설계: docs/tasks/qoin_accrual_rate_hierarchy/spec.md §6, §10.
 */

/** 하한 0.1%. `0.03` 오입력(3% 를 비율로 입력)을 막는 선이다. 낮추지 말 것. */
export const MIN_RATE = 0.001;
/** 상한 20%. */
export const MAX_RATE = 0.2;

/** 일괄 적용 `in_progress` 가 이 시간 넘게 갱신이 없으면 중단된 것으로 본다 (5분). */
export const BULK_STALE_MS = 5 * 60 * 1000;

export type RateSource = "store" | "brand" | "global";

/** 저장된 값 1칸의 분류. 부재 / 유효 / 명시적 0 / 무효 4값을 뭉개지 않는다. */
export type RateCell =
  | { kind: "absent" }
  | { kind: "valid"; rate: number }
  | { kind: "zero" }
  | { kind: "invalid"; raw: unknown };

/**
 * 저장된 필드 값을 분류한다.
 * - `undefined` (필드 부재) → absent. `null` 은 무효 (spec §4-③: null 상태를 만들지 않는다).
 * - `allowZero=false` (전역) 이면 0 은 무효.
 */
export function classifyRate(raw: unknown, allowZero = true): RateCell {
  if (raw === undefined) return { kind: "absent" };
  if (typeof raw !== "number" || !Number.isFinite(raw)) return { kind: "invalid", raw };
  if (raw === 0) return allowZero ? { kind: "zero" } : { kind: "invalid", raw };
  if (raw < MIN_RATE || raw > MAX_RATE) return { kind: "invalid", raw };
  return { kind: "valid", rate: raw };
}

export type Resolved =
  | { ok: true; rate: number; source: RateSource } // rate === 0 이면 적립 안 함
  | { ok: false; reason: "invalid_store" | "invalid_brand" | "invalid_global" };

/**
 * 계층 해석 (매장 → 브랜드 → 전역). **무효 값은 상위로 폴백하지 않는다** (fail-closed).
 * `brand` 는 브랜드 미소속이면 absent 로 넘긴다.
 */
export function resolveEffectiveRate(
  store: RateCell,
  brand: RateCell,
  global: RateCell
): Resolved {
  if (store.kind === "zero") return { ok: true, rate: 0, source: "store" };
  if (store.kind === "valid") return { ok: true, rate: store.rate, source: "store" };
  if (store.kind === "invalid") return { ok: false, reason: "invalid_store" };

  if (brand.kind === "zero") return { ok: true, rate: 0, source: "brand" };
  if (brand.kind === "valid") return { ok: true, rate: brand.rate, source: "brand" };
  if (brand.kind === "invalid") return { ok: false, reason: "invalid_brand" };

  if (global.kind === "valid") return { ok: true, rate: global.rate, source: "global" };
  return { ok: false, reason: "invalid_global" };
}

/**
 * callable 입력 검증 (서버 경계). 저장값 분류보다 엄격하다:
 * 0.1% 단위(tenths) 정수 배수여야 한다 — 화면이 보내는 값과 같은 격자.
 * 0 은 `allowZero` 일 때만 (전역은 불가).
 */
export function isValidCallableRate(raw: unknown, allowZero: boolean): raw is number {
  const cell = classifyRate(raw, allowZero);
  if (cell.kind === "zero") return true;
  if (cell.kind !== "valid") return false;
  const tenths = cell.rate * 1000;
  return Math.abs(tenths - Math.round(tenths)) < 1e-9;
}

/** floor(total * rate). 부동소수 오차(4500*0.03 등) 를 피하려고 ppm 정수로 환산해 계산한다. */
export function computeEarnAmount(total: number, rate: number): number {
  const ppm = Math.round(rate * 1_000_000);
  return Math.floor((total * ppm) / 1_000_000);
}
