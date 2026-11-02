/**
 * Qoin 사용(spend) 순수 판정 — Firebase 비의존 (priceGate / qoinRate 와 같은 패턴). qoin_spend spec §5.2.
 *
 * 이 모듈은 **판정만** 한다. 잔액 read·차감·원장 쓰기는 `qoinSpendLedger.ts`, 호출 지점은 `verifyTossPayment.ts`.
 * 클라이언트 화면의 사용가능액(`lib/core/utils/qoin_spend_calculator.dart`)은 같은 규칙의 **표시용 사본**이며,
 * `test_fixtures/qoin_spend_contract.json` 이 양쪽을 같은 파일로 고정한다 (한쪽만 바꾸면 골든이 깨진다).
 *
 * 권위 규칙:
 *   - `serverSubtotal` 은 **서버가 문서에서 다시 만든 소계**여야 한다 (클라 값 금지 — 소계 뻥튀기 공격).
 *   - 부재/비정상 정책은 fail-closed (사용 차단). 돈을 쓰는 기능은 명시적으로 켜야 켜진다.
 *   - 전역 `enabled !== true` 는 상위 비상정지라 사용도 막는다 (spec D-7).
 */

/** 사용 거절 사유 (판정 내부). 서버 토큰은 `QOIN_` 접두를 붙인 것 — `SPEND_REJECT_TOKEN`. */
export type SpendRejectReason =
  | "DISABLED"
  | "BELOW_MIN_UNIT"
  | "NOT_UNIT_MULTIPLE"
  | "INSUFFICIENT_BALANCE"
  | "BELOW_CASH_FLOOR";

/** 거절 사유 → `paymentGateRejections.reason` / 응답 토큰 (`paymentGate.ts` 의 GateReason 과 같은 문자열). */
export const SPEND_REJECT_TOKEN = {
  DISABLED: "QOIN_SPEND_DISABLED",
  BELOW_MIN_UNIT: "QOIN_BELOW_MIN_UNIT",
  NOT_UNIT_MULTIPLE: "QOIN_NOT_UNIT_MULTIPLE",
  INSUFFICIENT_BALANCE: "QOIN_INSUFFICIENT_BALANCE",
  BELOW_CASH_FLOOR: "QOIN_BELOW_CASH_FLOOR",
} as const satisfies Record<SpendRejectReason, string>;

export type SpendRejectToken = (typeof SPEND_REJECT_TOKEN)[SpendRejectReason];

/** 정책 상한 — 오타(예: minCashFloor 3000000)로 사용이 사실상 영구 차단되는 것을 callable 이 막는다. */
export const MAX_MIN_SPEND_UNIT = 10_000;
export const MAX_MIN_CASH_FLOOR = 100_000;

export interface SpendPolicy {
  /** 전역 `enabled === true` && `spendEnabled === true` && 정책값이 유효할 때만 true. */
  spendEnabled: boolean;
  minUnit: number;
  minCashFloor: number;
  /** spendEnabled 가 false 인 이유 (로그/거절 기록용). enabled 면 null. */
  disabledBecause: null | "globalDisabled" | "spendDisabled" | "invalidMinSpendUnit" | "invalidMinCashFloor";
}

const isPosInt = (v: unknown): v is number => typeof v === "number" && Number.isSafeInteger(v) && v >= 1;

/** `spendEnabled` / `minSpendUnit` / `minCashFloor` 값 검증 (callable 과 정책 해석이 같은 기준). */
export const isValidMinSpendUnit = (v: unknown): v is number => isPosInt(v) && v <= MAX_MIN_SPEND_UNIT;
export const isValidMinCashFloor = (v: unknown): v is number => isPosInt(v) && v <= MAX_MIN_CASH_FLOOR;

/**
 * `config/qoin` 문서 데이터 → 사용 정책. 문서가 없으면 `undefined` 를 넘긴다.
 *   - `spendEnabled` 부재/비-boolean → 차단 (fail-closed)
 *   - `minSpendUnit` 부재 → 1 (D-2) / 존재하지만 무효 → 차단
 *   - `minCashFloor` 부재/무효 → 차단 (초기 세팅 300, D-3)
 */
export function resolveSpendPolicy(config: Record<string, unknown> | undefined): SpendPolicy {
  const blocked = (because: NonNullable<SpendPolicy["disabledBecause"]>): SpendPolicy => ({
    spendEnabled: false,
    minUnit: 1,
    minCashFloor: 0,
    disabledBecause: because,
  });
  if (!config || config.enabled !== true) return blocked("globalDisabled");
  if (config.spendEnabled !== true) return blocked("spendDisabled");
  const rawUnit = config.minSpendUnit;
  if (rawUnit !== undefined && !isValidMinSpendUnit(rawUnit)) return blocked("invalidMinSpendUnit");
  if (!isValidMinCashFloor(config.minCashFloor)) return blocked("invalidMinCashFloor");
  return {
    spendEnabled: true,
    minUnit: rawUnit === undefined ? 1 : rawUnit,
    minCashFloor: config.minCashFloor,
    disabledBecause: null,
  };
}

export type SpendValidation =
  | { ok: true; validatedQ: number }
  | { ok: false; reason: SpendRejectReason; detail: Record<string, unknown> };

/**
 * 사용 요청 판정. 규칙 순서는 spec §5.2 와 같다.
 *   1 요청 0 → 항상 통과 (Qoin 안 씀)  2 비활성 → DISABLED  3 정수·양수 아님 → BELOW_MIN_UNIT
 *   4 단위 배수 아님  5 잔액 초과  6 소계 − 최소현금 초과
 * `balance` 가 유한한 수가 아니면 0, 음수면 0 으로 취급한다 (음수 잔액으로는 쓸 수 없다).
 */
export function validateQoinSpend(args: {
  requested: number;
  balance: unknown;
  serverSubtotal: number;
  policy: SpendPolicy;
}): SpendValidation {
  const { requested, serverSubtotal, policy } = args;
  if (requested === 0) return { ok: true, validatedQ: 0 };
  if (!policy.spendEnabled) {
    return { ok: false, reason: "DISABLED", detail: { because: policy.disabledBecause, requested } };
  }
  if (!Number.isSafeInteger(requested) || requested <= 0) {
    return { ok: false, reason: "BELOW_MIN_UNIT", detail: { requested } };
  }
  if (requested % policy.minUnit !== 0) {
    return { ok: false, reason: "NOT_UNIT_MULTIPLE", detail: { requested, minUnit: policy.minUnit } };
  }
  const balance = typeof args.balance === "number" && Number.isFinite(args.balance) ? Math.max(0, args.balance) : 0;
  if (requested > balance) {
    return { ok: false, reason: "INSUFFICIENT_BALANCE", detail: { requested, balance } };
  }
  const maxByFloor = serverSubtotal - policy.minCashFloor;
  if (requested > maxByFloor) {
    return {
      ok: false,
      reason: "BELOW_CASH_FLOOR",
      detail: { requested, serverSubtotal, minCashFloor: policy.minCashFloor, maxByFloor },
    };
  }
  return { ok: true, validatedQ: requested };
}

/**
 * 사용 가능 최대액 (표시용 — Dart 계산기와 골든으로 고정). `min(잔액, 소계 − 최소현금)` 을 단위 배수로 내림, 하한 0.
 * 서버 판정은 이 값을 쓰지 않는다 (`validateQoinSpend` 가 권위) — 골든 대조용으로만 export.
 */
export function maxSpendable(args: { balance: number; subtotal: number; minUnit: number; minCashFloor: number }): number {
  const bal = Number.isFinite(args.balance) ? Math.max(0, args.balance) : 0;
  const raw = Math.max(0, Math.min(bal, args.subtotal - args.minCashFloor));
  return raw - (raw % args.minUnit);
}

/**
 * `verifyTossPayment` 입력 `qoinToUse` 파싱. 미전송/null → 0 (구버전 앱 하위호환, F10).
 * 전송됐는데 안전 정수·0 이상이 아니면 `null` (호출자가 invalid-argument 로 거절 — 음수는 금액을 깎는 입력이다).
 */
export function parseQoinToUse(raw: unknown): number | null {
  if (raw === undefined || raw === null) return 0;
  if (typeof raw !== "number" || !Number.isSafeInteger(raw) || raw < 0) return null;
  return raw;
}
