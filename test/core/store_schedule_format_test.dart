import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/store_schedule_format.dart';
import 'package:qradar/core/utils/store_sellability.dart';

ScheduleDayHours _h(String o, String c) => (open: o, close: c);

void main() {
  group('formatWeeklySummary', () {
    test('null = 시간 제한 없음, 빈 맵 = 전체 휴무', () {
      expect(formatWeeklySummary(null), '영업시간 제한 없음');
      expect(formatWeeklySummary({}), '모든 요일 휴무');
    });

    test('월~금 묶음 + 토 단축 + 일 휴무', () {
      expect(
        formatWeeklySummary({
          for (var d = 1; d <= 5; d++) d: _h('09:00', '21:00'),
          6: _h('09:00', '15:00'),
        }),
        '월~금 09:00–21:00 · 토 09:00–15:00 · 일 휴무',
      );
    });

    test('7일 동일 = 매일, 비연속 = 가운뎃점, 자정 넘김 = 익일', () {
      expect(
        formatWeeklySummary({for (var d = 1; d <= 7; d++) d: _h('10:00', '20:00')}),
        '매일 10:00–20:00',
      );
      expect(
        formatWeeklySummary({
          1: _h('09:00', '18:00'),
          3: _h('09:00', '18:00'),
          5: _h('22:00', '02:00'),
        }),
        '월·수 09:00–18:00 · 금 22:00–익일 02:00 · 화·목·토·일 휴무',
      );
    });
  });

  test('formatNextOpen: 오늘 / 내일 / 그 외', () {
    expect(formatNextOpen('2026-11-02T18:00', '2026-11-02'), '오늘 18:00');
    expect(formatNextOpen('2026-11-03T09:00', '2026-11-02'), '내일(화) 09:00');
    expect(formatNextOpen('2026-11-09T09:00', '2026-11-02'), '11/9(월) 09:00');
    expect(formatNextOpen(null, '2026-11-02'), isNull);
  });

  test('formatCloseAt: 당일 / 익일', () {
    expect(formatCloseAt('2026-11-02T21:00', '2026-11-02'), '21:00까지');
    expect(formatCloseAt('2026-11-03T02:00', '2026-11-02'), '익일 02:00까지');
  });

  test('kstClockOf: UTC 15:00 = 다음날 00:00 KST, 일요일 = 7', () {
    final c = kstClockOf(DateTime.utc(2026, 11, 7, 15)); // 일요일 00:00 KST
    expect(c.weekday, 7);
    expect(c.minuteOfDay, 0);
    expect(c.dateKey, '2026-11-08');
  });
}
