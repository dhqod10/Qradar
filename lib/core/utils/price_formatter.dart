/// 원화 포맷터.
class PriceFormatter {
  PriceFormatter._();

  /// `4500` → `"4,500원"`. 음수도 자연스럽게 표시 (`"-4,500원"`).
  static String formatKrw(int price) {
    return '${_grouped(price)}원';
  }

  /// 옵션 priceDelta 표기. 양수면 `+`, 음수면 `-`, 0 이면 빈 문자열.
  static String formatDelta(int delta) {
    if (delta == 0) return '';
    if (delta > 0) return '+${_grouped(delta)}원';
    return '-${_grouped(-delta)}원';
  }

  static String _grouped(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final mod = s.length % 3;
    if (mod != 0) {
      buf.write(s.substring(0, mod));
      if (s.length > mod) buf.write(',');
    }
    for (var i = mod; i < s.length; i += 3) {
      buf.write(s.substring(i, i + 3));
      if (i + 3 < s.length) buf.write(',');
    }
    return buf.toString();
  }
}
