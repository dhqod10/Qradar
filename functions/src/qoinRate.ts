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

/**
 * 저장된 적립률 1칸의 분류. **3값** (부재 / 유효 / 무효).
 * 0 은 어느 범위에서도 적립률이 아니다 (Q1: "적립 안 함" 은 스위치로 분리됐다).
 */
export type RateCell =
  | { kind: "absent" }
  | { kind: "valid"; rate: number }
  | { kind: "invalid"; raw: unknown };

/**
 * 저장된 필드 값을 분류한다.
 * - `undefined` (필드 부재) → absent. `null` 은 무효 (null 상태를 만들지 않는다).
 * - 0 은 무효다 (어느 범위에서도 적립률이 아니다 — "적립 안 함" 은 스위치의 일이다).
 */
export function classifyRate(raw: unknown): RateCell {
  if (raw === undefined) return { kind: "absent" };
  if (typeof raw !== "number" || !Number.isFinite(raw)) return { kind: "invalid", raw };
  if (raw < MIN_RATE || raw > MAX_RATE) return { kind: "invalid", raw };
  return { kind: "valid", rate: raw };
}

/** 적립 스위치 1칸의 분류. 부재·`true` = 사용, `false` = 사용 안 함, 그 외(비bool) = 무효 (fail-closed). */
export type SwitchCell = { kind: "enabled" } | { kind: "disabled" } | { kind: "invalid"; raw: unknown };

export function classifySwitch(raw: unknown): SwitchCell {
  if (raw === undefined || raw === true) return { kind: "enabled" };
  if (raw === false) return { kind: "disabled" };
  return { kind: "invalid", raw };
}

export type InvalidReason =
  | "invalid_store"
  | "invalid_brand"
  | "invalid_global"
  | "invalid_store_enabled"
  | "invalid_brand_enabled";

export type Resolved =
  | { ok: true; disabled: false; rate: number; source: RateSource }
  // 스위치가 꺼져 적립하지 않는다.
  | { ok: true; disabled: true; source: "store" | "brand" }
  | { ok: false; reason: InvalidReason };

/**
 * 계층 해석 (spec §20.3.1 **개정판, N4**). 스위치 단계가 숫자 단계를 통째로 앞서고,
 * 스위치 단계 안에서 `disabled` 가 `invalid` 보다 앞선다. **무효 값은 상위로 폴백하지 않는다** (fail-closed).
 *
 *   1) storeSwitch disabled -> DISABLED(store)      4) brandSwitch invalid -> INVALID(invalid_brand_enabled)
 *   2) brandSwitch disabled -> DISABLED(brand)      5) storeRate -> brandRate -> globalRate (무효는 즉시 멈춤)
 *   3) storeSwitch invalid  -> INVALID(invalid_store_enabled)
 *
 * ⚠️ 순서를 바꾸지 말 것 — "매장요율 → 브랜드스위치" 로 쓰면 R06(N4) 이 깨진다. Dart 쪽
 * `resolveEffectiveQoinRate` 와 분기 순서가 같아야 한다 (진리표 공유).
 * `brand*` 는 브랜드 미소속이면 absent / enabled 로 넘긴다.
 */
export function resolveEffectiveRate(
  storeSwitch: SwitchCell,
  storeRate: RateCell,
  brandSwitch: SwitchCell,
  brandRate: RateCell,
  globalRate: RateCell
): Resolved {
  // ── 1단계: 스위치 (숫자보다 먼저. 매장 → 브랜드, disabled → invalid) ──────
  if (storeSwitch.kind === "disabled") return { ok: true, disabled: true, source: "store" };
  if (brandSwitch.kind === "disabled") return { ok: true, disabled: true, source: "brand" };
  if (storeSwitch.kind === "invalid") return { ok: false, reason: "invalid_store_enabled" };
  if (brandSwitch.kind === "invalid") return { ok: false, reason: "invalid_brand_enabled" };

  // ── 2단계: 숫자 (상속) ───────────────────────────────────────────────
  if (storeRate.kind === "invalid") return { ok: false, reason: "invalid_store" };
  if (storeRate.kind === "valid") return { ok: true, disabled: false, rate: storeRate.rate, source: "store" };
  if (brandRate.kind === "invalid") return { ok: false, reason: "invalid_brand" };
  if (brandRate.kind === "valid") return { ok: true, disabled: false, rate: brandRate.rate, source: "brand" };
  if (globalRate.kind === "valid") return { ok: true, disabled: false, rate: globalRate.rate, source: "global" };
  return { ok: false, reason: "invalid_global" };
}

/**
 * callable 입력 검증 (서버 경계). 저장값 분류보다 엄격하다:
 * 0.1% 단위(tenths) 정수 배수여야 한다 — 화면이 보내는 값과 같은 격자. **0 은 항상 거부** (쓰기 측 예외 0).
 */
export function isValidCallableRate(raw: unknown): raw is number {
  const cell = classifyRate(raw);
  if (cell.kind !== "valid") return false;
  const tenths = cell.rate * 1000;
  return Math.abs(tenths - Math.round(tenths)) < 1e-9;
}

/** `setQoinAccrualEnabled` 입력 경계: 정확히 bool 만. */
export function isValidCallableSwitch(raw: unknown): raw is boolean {
  return typeof raw === "boolean";
}

/** floor(total * rate). 부동소수 오차(4500*0.03 등) 를 피하려고 ppm 정수로 환산해 계산한다. */
export function computeEarnAmount(total: number, rate: number): number {
  const ppm = Math.round(rate * 1_000_000);
  return Math.floor((total * ppm) / 1_000_000);
}
