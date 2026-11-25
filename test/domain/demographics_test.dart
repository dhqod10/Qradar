import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/demographics.dart';

void main() {
  group('ageRangeFromBirthYear — 연령대는 저장값이 아니라 출생연도에서 계산한다', () {
    test('해가 바뀌면 같은 사람의 구간도 따라 바뀐다 (이게 출생연도를 받는 이유)', () {
      expect(ageRangeFromBirthYear(1996, nowYear: 2025), AgeRange.twenties);
      expect(ageRangeFromBirthYear(1996, nowYear: 2026), AgeRange.thirties);
    });

    test('구간 경계', () {
      expect(ageRangeFromBirthYear(2007, nowYear: 2026), AgeRange.teens); // 19세
      expect(ageRangeFromBirthYear(2006, nowYear: 2026), AgeRange.twenties); // 20세
      expect(ageRangeFromBirthYear(1996, nowYear: 2026), AgeRange.thirties); // 30세
      expect(ageRangeFromBirthYear(1986, nowYear: 2026), AgeRange.forties);
      expect(ageRangeFromBirthYear(1976, nowYear: 2026), AgeRange.fifties);
      expect(ageRangeFromBirthYear(1966, nowYear: 2026), AgeRange.sixtiesPlus);
      // 60대 이상은 상한(만 120세)까지 한 구간으로 묶인다.
      expect(ageRangeFromBirthYear(1906, nowYear: 2026), AgeRange.sixtiesPlus);
    });

    test('null 이면 null (밝히지 않은 사용자)', () {
      expect(ageRangeFromBirthYear(null, nowYear: 2026), isNull);
    });

    test('약관상 가입 불가 연령과 비현실적인 값은 구간이 없다', () {
      expect(ageRangeFromBirthYear(2013, nowYear: 2026), isNull); // 13세
      expect(ageRangeFromBirthYear(2012, nowYear: 2026), AgeRange.teens); // 14세
      expect(ageRangeFromBirthYear(1800, nowYear: 2026), isNull);
      expect(ageRangeFromBirthYear(2030, nowYear: 2026), isNull); // 미래
    });
  });

  group('isValidBirthYear — 이용약관의 만 14세 제한을 입력 단계에서 집행한다', () {
    test('만 14세가 하한이다', () {
      expect(isValidBirthYear(2012, nowYear: 2026), isTrue); // 14세
      expect(isValidBirthYear(2013, nowYear: 2026), isFalse); // 13세
    });

    test('상한과 미래 연도를 막는다', () {
      expect(isValidBirthYear(1906, nowYear: 2026), isTrue); // 120세
      expect(isValidBirthYear(1905, nowYear: 2026), isFalse); // 121세
      expect(isValidBirthYear(2027, nowYear: 2026), isFalse);
    });
  });

  group('코드 직렬화', () {
    test('Gender 는 밝히지 않음을 값으로 두지 않는다 (null 이 그 뜻)', () {
      expect(Gender.values.length, 2);
      expect(Gender.fromCode('male'), Gender.male);
      expect(Gender.fromCode('undisclosed'), isNull);
      expect(Gender.fromCode(null), isNull);
      expect(Gender.fromCode(''), isNull);
    });

    test('AgeRange 코드 왕복', () {
      for (final v in AgeRange.values) {
        expect(AgeRange.fromCode(v.name), v);
      }
      expect(AgeRange.fromCode('unknown'), isNull);
    });
  });
}
