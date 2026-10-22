/// Qoin 적립률 정책의 순수 계산/검증 (Flutter/Firebase 비의존).
///
/// 적립률 자체(기본 3%)는 여기 두지 않는다 — `config/qoin` 에서만 읽는다.
/// 여기 있는 것은 **입력 검증 경계**(0.1~20%)와 표시용 환산뿐이다.
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
