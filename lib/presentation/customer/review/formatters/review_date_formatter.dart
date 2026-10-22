import 'package:intl/intl.dart';

/// 리뷰 카드 날짜 표기.
///
/// 1분 미만 `방금 전` / 1시간 미만 `N분 전` / 24시간 미만 `N시간 전` /
/// 7일 미만 `N일 전` / 그 외 `yyyy.MM.dd`. 기준 시각은 `updatedAt ?? createdAt`,
/// `updatedAt != null` 이면 ` · 수정됨` 이 붙는다.
String formatReviewDate({
  required DateTime createdAt,
  DateTime? updatedAt,
  required DateTime now,
}) {
  final base = updatedAt ?? createdAt;
  final diff = now.difference(base);
  final String text;
  if (diff.inMinutes < 1) {
    text = '방금 전';
  } else if (diff.inHours < 1) {
    text = '${diff.inMinutes}분 전';
  } else if (diff.inHours < 24) {
    text = '${diff.inHours}시간 전';
  } else if (diff.inDays < 7) {
    text = '${diff.inDays}일 전';
  } else {
    text = DateFormat('yyyy.MM.dd').format(base);
  }
  return updatedAt != null ? '$text · 수정됨' : text;
}
