/// 매장 평가 작성/수정 가능 기간(픽업 완료 후 14일) 판정. **UI/UseCase 전용 정책**
/// (Firestore Rules 에는 넣지 않는다 — legacy completed 주문은 completedAt 이 없을 수 있음).
class ReviewWindow {
  ReviewWindow._();

  static const Duration duration = Duration(days: 14);

  /// 기간이 지났는가. `completedAt == null` 이면 만료 아님(허용).
  /// 정확히 14일 경과 시점까지는 허용, 초과부터 만료.
  static bool isExpired(DateTime? completedAt, DateTime now) {
    if (completedAt == null) return false;
    return now.difference(completedAt) > duration;
  }

  /// 남은 기간. `completedAt == null` 또는 만료면 null.
  static Duration? remaining(DateTime? completedAt, DateTime now) {
    if (completedAt == null) return null;
    final left = duration - now.difference(completedAt);
    if (left.isNegative) return null;
    return left;
  }

  /// 마감 임박 캡션 문구 (design: 24시간 이내 / 1~3일 / 4일 이상 표시 안 함).
  static String? countdownCaption(DateTime? completedAt, DateTime now) {
    final left = remaining(completedAt, now);
    if (left == null) return null;
    if (left < const Duration(hours: 24)) return '오늘까지 평가할 수 있어요';
    final days = (left.inMinutes / (24 * 60)).ceil();
    if (days <= 3) return '$days일 후 평가 기간이 끝나요';
    return null;
  }
}
