import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/korean_particle.dart';

void main() {
  test('받침 유무로 은/는', () {
    expect(KoreanParticle.withTopic('브랜드'), '브랜드는');
    expect(KoreanParticle.withTopic('매장'), '매장은');
    expect(KoreanParticle.withTopic('전역'), '전역은');
    expect(KoreanParticle.withTopic('Q브루어리'), 'Q브루어리는');
    expect(KoreanParticle.withTopic('CAFE'), 'CAFE는');
  });
  test('이/가 · 을/를 · 과/와', () {
    expect(KoreanParticle.subject('브랜드'), '가');
    expect(KoreanParticle.subject('매장'), '이');
    expect(KoreanParticle.object('브랜드'), '를');
    expect(KoreanParticle.object('매장'), '을');
    expect(KoreanParticle.with_('브랜드'), '와');
    expect(KoreanParticle.with_('매장'), '과');
  });
  test('숫자·공백·빈 문자열', () {
    expect(KoreanParticle.topic('10'), '은'); // 십 → 받침 (끝자리 0 = 영)
    expect(KoreanParticle.topic('2'), '는'); // 이
    expect(KoreanParticle.topic('3'), '은'); // 삼
    expect(KoreanParticle.topic('매장 '), '은');
    expect(KoreanParticle.topic(''), '는');
  });
}
