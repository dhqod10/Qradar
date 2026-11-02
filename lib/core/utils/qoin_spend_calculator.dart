/// Qoin 사용(qoin_spend) 정책 + 표시용 계산. **순수 Dart** — 서버 `functions/src/qoinSpend.ts` 의 규칙 사본이다.
///
/// **권위가 아니다.** 체크아웃 화면의 사용가능액·클램프를 계산할 뿐이며, 최종 판정은 서버(`verifyTossPayment`)가
/// 잔액·정책·**서버가 다시 만든 소계**로 한다. 규칙은 `test_fixtures/qoin_spend_contract.json` 골든이 양쪽을 같은 파일로 고정한다
/// (한쪽만 바꾸면 Dart·TS 테스트가 깨진다).
library;

/// 정책 값 상한 — 서버 `MAX_MIN_SPEND_UNIT` / `MAX_MIN_CASH_FLOOR` 와 같은 값 (골든이 경계를 고정).
const int kMaxMinSpendUnit = 10000;
const int kMaxMinCashFloor = 100000;

/// `config/qoin` 에서 해석한 **유효 사용 정책**. [enabled] 가 false 면 나머지 값은 의미 없다 (fail-closed).
class QoinSpendPolicy {
  const QoinSpendPolicy({
    required this.enabled,
    this.minUnit = 1,
    this.minCashFloor = 0,
  });

  /// 사용 불가 (정책 부재·꺼짐·무효). 체크아웃은 Qoin 섹션을 숨기고 기존 결제(사용 0)로 폴백한다.
  static const QoinSpendPolicy disabled = QoinSpendPolicy(enabled: false);

  /// 전역 `enabled == true` && `spendEnabled == true` && 정책값 유효 — 서버 `resolveSpendPolicy` 와 같은 기준.
  final bool enabled;

  /// 최소 사용 단위 (D-2, 기본 1).
  final int minUnit;

  /// 결제수단 무관 단일 최소 현금 결제액 (D-3).
  final int minCashFloor;

  /// `config/qoin` 원시 문서 → 정책. 문서가 없으면 null 을 넘긴다.
  ///   - `spendEnabled` 부재/비-bool → 차단 / 전역 `enabled != true` → 차단 (상위 비상정지)
  ///   - `minSpendUnit` 부재 → 1, 존재하나 무효(1~10000 정수 아님) → 차단
  ///   - `minCashFloor` 부재/무효(1~100000 정수 아님) → 차단
  factory QoinSpendPolicy.fromConfig(Map<String, dynamic>? config) {
    if (config == null || config['enabled'] != true) return disabled;
    if (config['spendEnabled'] != true) return disabled;
    final rawUnit = config['minSpendUnit'];
    if (rawUnit != null && !_isIntInRange(rawUnit, kMaxMinSpendUnit)) {
      return disabled;
    }
    final floor = config['minCashFloor'];
    if (!_isIntInRange(floor, kMaxMinCashFloor)) return disabled;
    return QoinSpendPolicy(
      enabled: true,
      minUnit: rawUnit == null ? 1 : (rawUnit as num).toInt(),
      minCashFloor: (floor as num).toInt(),
    );
  }

  static bool _isIntInRange(Object? v, int max) =>
      v is num && v.isFinite && v == v.truncate() && v >= 1 && v <= max;

  @override
  bool operator ==(Object other) =>
      other is QoinSpendPolicy &&
      other.enabled == enabled &&
      other.minUnit == minUnit &&
      other.minCashFloor == minCashFloor;

  @override
  int get hashCode => Object.hash(enabled, minUnit, minCashFloor);
}

/// 한도가 무엇에 의해 정해졌는가 — 안내 문구 선택용 (design §2.1 행 C, §2.3).
enum QoinSpendLimitedBy {
  /// 사용 안 함 / 해당 없음.
  none,

  /// 보유 잔액이 한도.
  balance,

  /// 최소 현금(`소계 − minCashFloor`)이 한도.
  cashFloor,
}

class QoinSpendCalculator {
  const QoinSpendCalculator._();

  /// 표시용 사용가능액 = `floor_unit(max(0, min(balance, subtotal − minCashFloor)))` (design §2.4).
  /// 음수 잔액은 0 으로 본다. 정책이 [QoinSpendPolicy.enabled] 가 아니면 0.
  static int maxSpendable({
    required int balance,
    required int subtotal,
    required QoinSpendPolicy policy,
  }) {
    if (!policy.enabled) return 0;
    final bal = balance < 0 ? 0 : balance;
    final byFloor = subtotal - policy.minCashFloor;
    var raw = bal < byFloor ? bal : byFloor;
    if (raw < 0) raw = 0;
    return raw - (raw % policy.minUnit);
  }

  /// 한도를 정한 쪽. `보유잔액 ≤ 소계 − 최소현금` 이면 잔액, 아니면 최소현금 (design §2.1).
  static QoinSpendLimitedBy limitedBy({
    required int balance,
    required int subtotal,
    required QoinSpendPolicy policy,
  }) {
    if (maxSpendable(balance: balance, subtotal: subtotal, policy: policy) <=
        0) {
      return QoinSpendLimitedBy.none;
    }
    final bal = balance < 0 ? 0 : balance;
    return bal <= subtotal - policy.minCashFloor
        ? QoinSpendLimitedBy.balance
        : QoinSpendLimitedBy.cashFloor;
  }

  /// 서버 판정(`validateQoinSpend`) 의 ok 여부와 같아야 한다 (골든). 0 은 항상 통과.
  static bool isAllowed({
    required int requested,
    required int balance,
    required int subtotal,
    required QoinSpendPolicy policy,
  }) {
    if (requested == 0) return true;
    if (!policy.enabled || requested < 1) return false;
    if (requested % policy.minUnit != 0) return false;
    return requested <=
        maxSpendable(balance: balance, subtotal: subtotal, policy: policy);
  }

  /// 입력값을 한도로 자른다 (DD-2). 음수는 0, 한도 초과는 [maxSpendable], 단위가 안 맞으면 내림.
  static int clamp({
    required int requested,
    required int balance,
    required int subtotal,
    required QoinSpendPolicy policy,
  }) {
    if (requested <= 0) return 0;
    final max = maxSpendable(
      balance: balance,
      subtotal: subtotal,
      policy: policy,
    );
    final capped = requested > max ? max : requested;
    return capped - (capped % policy.minUnit);
  }

  /// 결제 예정 금액 = 소계 − 사용액 (표시용 · Toss 승인 요청액). 서버가 같은 값을 재계산해 대조한다.
  static int finalAmount({required int subtotal, required int qoinToUse}) =>
      subtotal - qoinToUse;
}
