/// Qoin 적립률 정책의 순수 계산/검증 (Flutter/Firebase 비의존).
///
/// 적립률 자체(기본 3%)는 여기 두지 않는다 — `config/qoin` 에서만 읽는다.
/// 여기 있는 것은 **입력 검증 경계**(0.1~20%)와 표시용 환산뿐이다.
///
/// **경계 상수([minTenths] / [maxTenths])의 Dart 쪽 유일한 출처다.** 다른 파일에서 0.001 / 0.2 /
/// 0.1 / 20 을 다시 선언하지 않는다 (1차 F3 재발 방지). TS 쪽 출처는 `functions/src/qoinRate.ts` 1곳이며,
/// 두 구현은 `test_fixtures/qoin_rate_truth_table.json` 을 같이 읽는 테스트로 묶여 있다.
///
/// 모든 환산은 0.1% 단위 정수("tenths", 30 = 3.0%)로 한다. 부동소수 오차 방지.
class QoinPolicy {
  QoinPolicy._();

  /// 하한 0.1% — `0.03` 오입력(3% 를 비율로 입력)을 차단하는 선이다. 낮추지 말 것.
  static const int minTenths = 1;

  /// 상한 20%.
  static const int maxTenths = 200;

  /// 미리보기/확인 다이얼로그 예시 결제액.
  static const int previewPaymentKrw = 10000;

  /// 내역 조회 상한 (쿼리 limit 과 푸터 문구가 같은 값을 쓴다).
  static const int historyLimit = 50;

  /// 변경 경고: 새 값이 이 값(10%) 이상이면 경고.
  static const int warnAbsoluteTenths = 100;

  static bool isValidTenths(int t) => t >= minTenths && t <= maxTenths;

  /// 비율 [rate] 가 유효 범위(0.001~0.2)인가. **명시적 0 은 여기서 유효가 아니다** — 0 은 [QoinRateSetting] 의 별도 상태.
  /// NaN / 무한대는 무효. 경계 비교는 tenths 상수에서 비율로 환산한 값으로 한다 (TS `MIN_RATE`/`MAX_RATE` 와 같은 double).
  static bool isValidRate(double rate) =>
      rate.isFinite && rate >= rateFromTenths(minTenths) && rate <= rateFromTenths(maxTenths);

  /// callable 입력 검증 (서버 `isValidCallableRate` 와 같은 진리표): 유효 범위 + 0.1% 격자, `allowZero` 면 0 허용.
  static bool isValidCallableRate(double rate, {required bool allowZero}) {
    if (!rate.isFinite) return false;
    if (rate == 0) return allowZero;
    if (!isValidRate(rate)) return false;
    final tenths = rate * 1000;
    return (tenths - tenths.roundToDouble()).abs() < 1e-9;
  }

  /// 명시적 0% (적립 안 함) 센티넬 값. 입력란으로는 만들 수 없다 ([validateRateInput] 은 0 을 [RateInputStatus.tooLow] 로 거부).
  static const double explicitOffRate = 0;

  /// 일괄 적용 `in_progress` 가 이 시간 넘게 갱신이 없으면 중단된 것으로 본다 (design D8: 5분, 단일 상수).
  /// 서버 쪽 `BULK_STALE_MS` 와 같은 값이어야 한다.
  static const Duration bulkStaleAfter = Duration(minutes: 5);

  /// 이력 목록 한 번에 불러오는 개수 / "더 보기" 증분.
  static const int historyPageSize = 50;

  /// 설명 사유 최대 길이 (서버 `parseReason` 과 같은 값).
  static const int reasonMaxLength = 200;

  /// 상·하한 카피용 문자열 (`0.1`, `20`).
  static String get minPercentLabel => formatTenths(minTenths);
  static String get maxPercentLabel => formatTenths(maxTenths);

  /// tenths → 저장용 비율. `30 → 0.03`.
  static double rateFromTenths(int tenths) => tenths / 1000;

  /// 비율 → tenths (0.1% 단위 반올림). `0.03 → 30`, `0.025 → 25`.
  static int tenthsFromRate(double rate) => (rate * 1000).round();

  /// tenths → 표시 숫자. `30 → '3'`, `25 → '2.5'`, `1 → '0.1'`.
  static String formatTenths(int tenths) {
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '$whole' : '$whole.$frac';
  }

  /// 비율 → `3%`/`2.5%`. 고객 plate / 관리자 화면이 같은 경로를 쓴다.
  static String formatRatePercent(double rate) =>
      '${formatTenths(tenthsFromRate(rate))}%';

  /// 관리자 적립률 입력(퍼센트 문자열) 검증.
  ///
  /// **100배 오입력 방어선**: `0.03`(3% 를 비율로 입력) 은 하한 0.1 미만이므로 [RateInputStatus.tooLow]
  /// 로 분류된다 (소수 둘째 자리라는 이유로 다른 상태로 새지 않도록 하한 검사를 먼저 한다).
  static RateInputResult validateRateInput(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const RateInputResult(RateInputStatus.empty);
    final m = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(s);
    if (m == null) return const RateInputResult(RateInputStatus.malformed);
    final whole = m.group(1) ?? '';
    var frac = m.group(2) ?? '';
    if (whole.isEmpty && frac.isEmpty) {
      return const RateInputResult(RateInputStatus.malformed);
    }
    final value = double.parse(
      '${whole.isEmpty ? '0' : whole}.${frac.isEmpty ? '0' : frac}',
    );
    if (value < minTenths / 10) {
      return const RateInputResult(RateInputStatus.tooLow);
    }
    if (value > maxTenths / 10) {
      return const RateInputResult(RateInputStatus.tooHigh);
    }
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    if (frac.length > 1) {
      return const RateInputResult(RateInputStatus.tooPrecise);
    }
    final tenths =
        (int.parse(whole.isEmpty ? '0' : whole)) * 10 +
        (frac.isEmpty ? 0 : int.parse(frac));
    return RateInputResult(RateInputStatus.valid, tenths);
  }

  /// 결제액 [paymentKrw] 에 [tenths] 적립 시 금액 (버림). 정수 연산.
  static int previewAmount(int tenths, {int paymentKrw = previewPaymentKrw}) =>
      (paymentKrw * tenths) ~/ 1000;

  /// 변경 확인 다이얼로그 경고 조건. 인상일 때만:
  /// 새 값 >= 현재 x 2 또는 새 값 >= 10%. 현재 값 없음(null)이면 10% 이상만.
  static bool shouldWarnIncrease({int? currentTenths, required int newTenths}) {
    if (currentTenths != null && newTenths <= currentTenths) return false;
    if (newTenths >= warnAbsoluteTenths) return true;
    return currentTenths != null && newTenths >= currentTenths * 2;
  }
}

enum RateInputStatus { empty, malformed, tooLow, tooHigh, tooPrecise, valid }

class RateInputResult {
  const RateInputResult(this.status, [this.tenths]);
  final RateInputStatus status;

  /// [RateInputStatus.valid] 일 때만 non-null.
  final int? tenths;
}
