import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/search_normalizer.dart';

void main() {
  group('SearchNormalizer', () {
    test('trim -> 소문자 -> 모든 공백 제거', () {
      expect(SearchNormalizer.normalize('  Ice  Americano\t'), 'iceamericano');
      expect(SearchNormalizer.normalize('아이스 아메리카노'), '아이스아메리카노');
      expect(SearchNormalizer.normalize('   '), '');
    });

    test('공백 유무와 무관하게 서로 잡힌다', () {
      expect(
        SearchNormalizer.matches(
          '아이스 아메리카노',
          SearchNormalizer.normalize('아이스아메리카노'),
        ),
        isTrue,
      );
      expect(
        SearchNormalizer.matches(
          '아이스아메리카노',
          SearchNormalizer.normalize('아이스 아메'),
        ),
        isTrue,
      );
      expect(
        SearchNormalizer.matches('Latte', SearchNormalizer.normalize('LAT')),
        isTrue,
      );
    });

    test('빈 질의는 아무것도 매칭하지 않는다', () {
      expect(SearchNormalizer.matches('아무거나', ''), isFalse);
    });
  });
}
