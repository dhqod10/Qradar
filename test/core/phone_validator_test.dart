import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/phone_validator.dart';

void main() {
  test('유효한 한국 휴대폰 번호', () {
    expect(isValidKoreanMobile('01012345678'), isTrue);
    expect(isValidKoreanMobile('0111234567'), isTrue);
  });

  test('무효: 빈값/짧음/접두 불일치/비숫자/길이 초과', () {
    expect(isValidKoreanMobile(''), isFalse);
    expect(isValidKoreanMobile('010123456'), isFalse);
    expect(isValidKoreanMobile('02012345678'), isFalse);
    expect(isValidKoreanMobile('010-1234-5678'), isFalse);
    expect(isValidKoreanMobile('010123456789'), isFalse);
  });
}
