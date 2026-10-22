/// 적립률을 설정하는 범위. 서버 이력의 `scope` 코드와 같다.
enum QoinRateScope {
  global('global'),
  brand('brand'),
  store('store');

  const QoinRateScope(this.code);
  final String code;

  /// 알 수 없는 코드는 null — 폴백하지 않는다 (1차 `QoinTransactionType.fromCode` 와 같은 정책).
  static QoinRateScope? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}
