import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/kst.dart';
import 'package:qradar/domain/entities/sales_period.dart';

DateTime kst(int y, int m, int d, [int h = 0, int min = 0]) =>
    Kst.fromWall(y, m, d, h, min);

void main() {
  group('SalesPeriod.day (KST)', () {
    test('KST 자정 경계: 23:59 와 00:00 은 서로 다른 날', () {
      final a = SalesPeriod.day(kst(2026, 10, 21, 23, 59));
      final b = SalesPeriod.day(kst(2026, 10, 22, 0, 0));
      expect(a.start, kst(2026, 10, 21));
      expect(a.endExclusive, kst(2026, 10, 22));
      expect(b.start, a.endExclusive);
    });

    test('UTC 15:00 = KST 다음날 00:00', () {
      final p = SalesPeriod.day(DateTime.utc(2026, 10, 21, 15, 0));
      expect(p.startWall.day, 22);
    });

    test('윤년 2/29', () {
      final p = SalesPeriod.day(kst(2028, 2, 29, 12));
      expect(p.endExclusive, kst(2028, 3, 1));
      expect(p.next().startWall.month, 3);
    });

    test('연말 이동', () {
      final p = SalesPeriod.day(kst(2026, 12, 31, 10));
      expect(p.next().startWall, DateTime.utc(2027, 1, 1));
      expect(p.next().previous(), p);
    });
  });

  group('SalesPeriod.week (월요일 시작)', () {
    test('2026-10-21(수) → 10/19(월) ~ 10/26(월)', () {
      final p = SalesPeriod.week(kst(2026, 10, 21, 9));
      expect(p.start, kst(2026, 10, 19));
      expect(p.endExclusive, kst(2026, 10, 26));
    });

    test('일요일은 직전 월요일 주에 속함', () {
      final p = SalesPeriod.week(kst(2026, 10, 25, 23, 59));
      expect(p.start, kst(2026, 10, 19));
    });

    test('월요일 00:00 은 새 주', () {
      final p = SalesPeriod.week(kst(2026, 10, 26));
      expect(p.start, kst(2026, 10, 26));
    });

    test('월/연 경계를 걸치는 주', () {
      final p = SalesPeriod.week(kst(2026, 1, 1, 12)); // 목
      expect(p.start, kst(2025, 12, 29));
      expect(p.endExclusive, kst(2026, 1, 5));
    });

    test('이전/다음 주', () {
      final p = SalesPeriod.week(kst(2026, 10, 21));
      expect(p.previous().start, kst(2026, 10, 12));
      expect(p.next().start, kst(2026, 10, 26));
    });
  });

  group('SalesPeriod.month', () {
    test('월말 / 연말', () {
      final p = SalesPeriod.month(kst(2026, 12, 31, 23, 59));
      expect(p.start, kst(2026, 12, 1));
      expect(p.endExclusive, kst(2027, 1, 1));
      expect(p.next().startWall, DateTime.utc(2027, 1, 1));
    });

    test('윤년 2월은 29일까지', () {
      final p = SalesPeriod.month(kst(2028, 2, 10));
      expect(p.endExclusive.difference(p.start).inDays, 29);
      expect(
        SalesPeriod.month(
          kst(2026, 2, 10),
        ).endExclusive.difference(kst(2026, 2, 1)).inDays,
        28,
      );
    });

    test('previous 는 이전 달 전체', () {
      final p = SalesPeriod.month(kst(2026, 3, 15)).previous();
      expect(p.start, kst(2026, 2, 1));
      expect(p.endExclusive, kst(2026, 3, 1));
    });
  });

  group('bucketKey (ISO 8601)', () {
    test('day / month', () {
      expect(SalesPeriod.day(kst(2026, 10, 21)).bucketKey, '2026-10-21');
      expect(SalesPeriod.month(kst(2026, 10, 21)).bucketKey, '2026-10');
    });

    test('2026-10-21 → W43', () {
      expect(SalesPeriod.week(kst(2026, 10, 21)).bucketKey, '2026-W43');
    });

    test('연초: 2026-01-01(목) 이 속한 주는 2026-W01', () {
      expect(SalesPeriod.week(kst(2026, 1, 1)).bucketKey, '2026-W01');
      expect(SalesPeriod.week(kst(2025, 12, 29)).bucketKey, '2026-W01');
    });

    test('연말: 2027-01-01(금) 이 속한 주는 2026-W53', () {
      expect(SalesPeriod.week(kst(2027, 1, 1)).bucketKey, '2026-W53');
    });
  });

  group('isCurrent / canGoNext / canGoPrevious (now 주입)', () {
    final now = kst(2026, 10, 21, 14);

    test('현재 기간: isCurrent, 다음 불가', () {
      final p = SalesPeriod.current(SalesPeriodType.day, now: now);
      expect(p.isCurrent(now: now), isTrue);
      expect(p.canGoNext(now: now), isFalse);
      expect(p.previous().canGoNext(now: now), isTrue);
    });

    test('자정 직전/직후', () {
      final p = SalesPeriod.day(kst(2026, 10, 21));
      expect(p.isCurrent(now: kst(2026, 10, 21, 23, 59)), isTrue);
      expect(p.isCurrent(now: kst(2026, 10, 22)), isFalse);
      expect(p.canGoNext(now: kst(2026, 10, 22)), isTrue);
    });

    test('월 단위: 12개월 전 경계', () {
      // 현재 2026-10 → 가장 오래된 허용 시작 = 2025-10-01
      var p = SalesPeriod.current(SalesPeriodType.month, now: now);
      var steps = 0;
      while (p.canGoPrevious(now: now)) {
        p = p.previous();
        steps++;
      }
      expect(steps, 12);
      expect(p.start, kst(2025, 10, 1));
    });

    test('일 단위: 2025-10-01 까지 이동 가능, 그 이전 불가', () {
      final edge = SalesPeriod.day(kst(2025, 10, 1));
      expect(edge.canGoPrevious(now: now), isFalse);
      expect(edge.next().canGoPrevious(now: now), isTrue);
    });
  });
}
