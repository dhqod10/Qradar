/// 매장 검색 키워드 토크나이저 — search_keyword_enhancement spec §4 (단일 진실원 규칙).
///
/// TS 구현(`functions/src/searchKeywords.ts`)과 **동일 규칙**이어야 한다. 두 구현은
/// `test_fixtures/search_keyword_contract.json` (cross-golden) 으로 lockstep 을 검증한다.
/// 현재는 groundwork 단계라 질의 경로에서 쓰이지 않는다(나중의 '전환' 단계 대비). 순수 Dart — Flutter 의존 금지.
///
/// 색인(`buildKeywords`): source 마다 trim → 소문자 → 공백 분할, 각 단어의 모든 prefix + 공백제거 전체 문자열의 모든 prefix.
/// 삽입 순서를 보존하며 중복 제거, [maxKeywords] 초과 시 앞에서 자른다. 길이는 code point(rune) 기준.
class SearchKeywordTokenizer {
  SearchKeywordTokenizer._();

  static const int maxKeywords = 300;
  static const int maxQueryTokens = 10;

  static final RegExp _ws = RegExp(r'\s+');

  static List<String> _prefixes(String word) {
    final out = <String>[];
    final buf = StringBuffer();
    for (final r in word.runes) {
      buf.writeCharCode(r);
      out.add(buf.toString());
    }
    return out;
  }

  static List<String> buildKeywords(
    Iterable<String> sources, {
    int maxKeywords = SearchKeywordTokenizer.maxKeywords,
  }) {
    final set = <String>{}; // LinkedHashSet — 삽입 순서 보존
    for (final raw in sources) {
      final s = raw.trim().toLowerCase();
      if (s.isEmpty) continue;
      for (final w in s.split(_ws)) {
        if (w.isEmpty) continue;
        set.addAll(_prefixes(w));
      }
      set.addAll(_prefixes(s.replaceAll(_ws, '')));
    }
    return set.take(maxKeywords).toList(growable: false);
  }

  /// 질의 토큰: trim → 소문자 → 공백 분할 → 빈 것/중복 제거 → 최대 [max]개.
  static List<String> queryTokens(String raw, {int max = maxQueryTokens}) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return const [];
    final out = <String>[];
    for (final w in s.split(_ws)) {
      if (w.isEmpty || out.contains(w)) continue;
      out.add(w);
      if (out.length >= max) break;
    }
    return out;
  }
}
