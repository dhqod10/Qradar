/// 한국어 조사 선택 — 받침 유무로 고른다. 이름·라벨을 문장에 끼워 넣을 때 `브랜드은` 같은 오류를 막는다.
///
/// 마지막 글자가 한글 음절이면 받침(종성) 유무로, 숫자는 읽는 소리(영·일·삼·육·칠·팔 = 받침 있음)로,
/// 그 밖의 글자(영문 등)는 받침 없음으로 본다. 문장에 사용자 입력 이름을 넣을 때는 이 함수를 거친다.
class KoreanParticle {
  KoreanParticle._();

  static bool hasBatchim(String word) {
    final trimmed = word.trimRight();
    if (trimmed.isEmpty) return false;
    final c = trimmed.codeUnitAt(trimmed.length - 1);
    if (c >= 0xAC00 && c <= 0xD7A3) return (c - 0xAC00) % 28 != 0;
    // 숫자: 영(0) 일(1) 삼(3) 육(6) 칠(7) 팔(8) 은 받침이 있다. 이(2) 사(4) 오(5) 구(9) 는 없다.
    if (c >= 0x30 && c <= 0x39) return const {0, 1, 3, 6, 7, 8}.contains(c - 0x30);
    return false;
  }

  /// 은/는
  static String topic(String word) => hasBatchim(word) ? '은' : '는';

  /// 이/가
  static String subject(String word) => hasBatchim(word) ? '이' : '가';

  /// 을/를
  static String object(String word) => hasBatchim(word) ? '을' : '를';

  /// 과/와
  static String with_(String word) => hasBatchim(word) ? '과' : '와';

  /// word + 은/는
  static String withTopic(String word) => '$word${topic(word)}';
}
