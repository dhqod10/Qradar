/// 한국어 상대시간 포맷터.
///
/// design.md 명세 (Phase 2):
/// - `< 24h` (당일) → "오늘"
/// - `< 48h` (어제 자정 기준) → "어제"
/// - `< 7일` → "{n}일 전"
/// - `< 30일` → "{n}주 전"
/// - 그 외 → `"yyyy.MM.dd"`
class RelativeTimeFormatter {
  RelativeTimeFormatter._();

  /// 한국어 상대시간 문자열 반환.
  ///
  /// 비교는 **자정 기준 일자 차이**(`startOfDay`) 로 한다 — 23:59 와 00:01 이
  /// "어제" / "오늘" 로 깔끔하게 갈리도록.
  static String formatKo(DateTime now, DateTime target) {
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    final daysAgo = today.difference(targetDay).inDays;

    if (daysAgo <= 0) return '오늘';
    if (daysAgo == 1) return '어제';
    if (daysAgo < 7) return '$daysAgo일 전';
    if (daysAgo < 30) return '${daysAgo ~/ 7}주 전';
    return _yyyyMMdd(target);
  }

  static String _yyyyMMdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y.$m.$day';
  }
}
