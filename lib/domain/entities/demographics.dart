/// 인구통계 속성 (성별 / 출생연도).
///
/// **선택 수집이다.** 주문·결제 어디에도 쓰이지 않고 통계에만 쓴다 — 거부해도 모든 기능이 정상이어야 한다
/// (개인정보보호법상 서비스 제공에 필수가 아닌 항목은 필수 동의로 받을 수 없다).
///
/// ### 왜 연령대가 아니라 출생연도인가
/// 연령대(`20대`)를 그대로 저장하면 **값이 늙지 않는다**. 2026년에 20대로 입력한 사람이 2031년에 30대가 돼도
/// 저장된 값은 20대라, 2031년 주문에 20대가 박혀 **그 시점 통계가 틀린다**. 출생연도는 주문 때마다
/// 다시 계산하므로 시간이 지나도 정확하다.
///
/// 저장은 연도 하나뿐이다 — 월·일은 받지 않는다. 연도만으로는 같은 값을 가진 사람이 수백만 명이라
/// 개인을 좁히지 않으면서 통계에는 충분하다.
library;

/// 성별. 고르지 않으면 `null` 이다 — "밝히지 않음" 을 별도 값으로 두지 않는다
/// (물어봤는지는 `users.demographicsAskedAt` 이 가린다).
enum Gender {
  male,
  female;

  static Gender? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final v in Gender.values) {
      if (v.name == code) return v;
    }
    return null;
  }

  String get label => switch (this) {
        Gender.male => '남성',
        Gender.female => '여성',
      };
}

/// 통계 집계 단위. **저장하는 값이 아니라 출생연도에서 계산하는 값**이다
/// (주문 문서의 `buyerAgeRange` 는 서버가 주문 시점에 계산해 박는다).
enum AgeRange {
  teens,
  twenties,
  thirties,
  forties,
  fifties,
  sixtiesPlus;

  static AgeRange? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final v in AgeRange.values) {
      if (v.name == code) return v;
    }
    return null;
  }

  String get label => switch (this) {
        AgeRange.teens => '10대',
        AgeRange.twenties => '20대',
        AgeRange.thirties => '30대',
        AgeRange.forties => '40대',
        AgeRange.fifties => '50대',
        AgeRange.sixtiesPlus => '60대 이상',
      };
}

/// 가입 가능 최소 연령. 이용약관이 "만 14세 미만은 가입할 수 없다" 고 정하고 있어
/// 출생연도도 그 아래로는 받지 않는다 (받아 두면 약관 위반을 알고도 보관하는 셈이 된다).
const int kMinSignupAge = 14;

/// 입력받을 수 있는 최고 연령. 오타(1066 같은 값)를 거르는 상한이다.
const int kMaxPlausibleAge = 120;

/// 나이 계산 기준 연도. 월·일을 받지 않으므로 **연도 차이**로만 센다 — 생일 전인 사람은 한 살 많게
/// 잡히지만 통계 구간(10년) 안에서는 대부분 흡수된다.
int ageFromBirthYear(int birthYear, {required int nowYear}) =>
    nowYear - birthYear;

/// 출생연도로 입력 가능한 범위인지 본다 (만 14세 이상, 120세 이하).
bool isValidBirthYear(int birthYear, {required int nowYear}) {
  final age = ageFromBirthYear(birthYear, nowYear: nowYear);
  return age >= kMinSignupAge && age <= kMaxPlausibleAge;
}

/// 출생연도 → 통계 구간. 범위 밖이면 null (주문에 쓰레기값이 박히지 않게 한다).
AgeRange? ageRangeFromBirthYear(int? birthYear, {required int nowYear}) {
  if (birthYear == null) return null;
  if (!isValidBirthYear(birthYear, nowYear: nowYear)) return null;
  final age = ageFromBirthYear(birthYear, nowYear: nowYear);
  if (age < 20) return AgeRange.teens;
  if (age < 30) return AgeRange.twenties;
  if (age < 40) return AgeRange.thirties;
  if (age < 50) return AgeRange.forties;
  if (age < 60) return AgeRange.fifties;
  return AgeRange.sixtiesPlus;
}
