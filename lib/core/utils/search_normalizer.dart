/// 검색 질의 정규화 — 매장·메뉴 검색이 **반드시 이 하나만** 쓴다 (위젯에서 `toLowerCase().contains()` 직접 금지).
///
/// 규칙: `trim` -> 소문자화 -> 모든 공백 제거. 대상 문자열도 같은 규칙으로 정규화한 뒤 `contains` 로 비교한다.
/// `아이스아메리카노` 로 `아이스 아메리카노` 가 잡히고 그 역도 잡힌다.
/// 초성·오타·영한 혼용은 비범위다 (spec §5.4). 순수 Dart — Flutter 의존 금지.
class SearchNormalizer {
  SearchNormalizer._();

  static final RegExp _whitespace = RegExp(r'\s+');

  static String normalize(String raw) =>
      raw.trim().toLowerCase().replaceAll(_whitespace, '');

  /// [target] 을 정규화해 [normalizedQuery] 를 포함하는지. 빈 질의는 항상 false (전부 매칭되는 사고 방지).
  static bool matches(String target, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return false;
    return normalize(target).contains(normalizedQuery);
  }
}
