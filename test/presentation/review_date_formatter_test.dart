import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/presentation/customer/review/formatters/review_date_formatter.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12, 0, 0);
  String f(Duration ago, {Duration? editedAgo}) => formatReviewDate(
    createdAt: now.subtract(ago),
    updatedAt: editedAgo == null ? null : now.subtract(editedAgo),
    now: now,
  );

  test('상대 표기 경계', () {
    expect(f(const Duration(seconds: 30)), '방금 전');
    expect(f(const Duration(minutes: 1)), '1분 전');
    expect(f(const Duration(minutes: 59)), '59분 전');
    expect(f(const Duration(hours: 1)), '1시간 전');
    expect(f(const Duration(hours: 23)), '23시간 전');
    expect(f(const Duration(days: 1)), '1일 전');
    expect(f(const Duration(days: 6)), '6일 전');
    expect(f(const Duration(days: 7)), '2026.10.15');
  });

  test('수정됨: updatedAt 기준 시각 + 접미사', () {
    expect(
      f(const Duration(days: 30), editedAgo: const Duration(hours: 2)),
      '2시간 전 · 수정됨',
    );
  });
}
