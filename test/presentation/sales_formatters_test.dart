import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/kst.dart';
import 'package:qradar/domain/entities/sales_period.dart';
import 'package:qradar/presentation/owner/sales/formatters/sales_formatters.dart';

DateTime kst(int y, int m, int d, [int h = 0, int min = 0]) =>
    Kst.fromWall(y, m, d, h, min);

String week(DateTime anchor, {DateTime? now}) => SalesFormatters.periodTitle(
  SalesPeriod.week(anchor),
  now: now ?? kst(2026, 10, 21),
);

void main() {
  final now = kst(2026, 10, 21, 12);

  group('주차: 목요일 소속', () {
    test('2026-10-21(수) → 10월 4주차 / 10월 19일 ~ 10월 25일', () {
      final p = SalesPeriod.week(now);
      expect(SalesFormatters.periodTitle(p, now: now), '10월 4주차');
      expect(SalesFormatters.periodSubtitle(p), '10월 19일 ~ 10월 25일');
    });

    test('월 경계 주: 9/28~10/4 → 목요일 10/1 → 10월 1주차', () {
      final p = SalesPeriod.week(kst(2026, 9, 30));
      expect(SalesFormatters.periodTitle(p, now: now), '10월 1주차');
      expect(SalesFormatters.periodSubtitle(p), '9월 28일 ~ 10월 4일');
    });

    test('월 경계 주: 목요일이 말일 쪽이면 앞 달 마지막 주차', () {
      // 2026-08-31(월)~09-06(일): 목요일 9/3 → 9월 1주차
      expect(week(kst(2026, 9, 1)), '9월 1주차');
      // 2026-08-24(월)~08-30(일): 목요일 8/27 → 8월 4주차
      expect(week(kst(2026, 8, 26)), '8월 4주차');
    });

    test('연초: 2025-12-29~2026-01-04 → 목요일 1/1 → 1월 1주차 (올해)', () {
      final p = SalesPeriod.week(kst(2025, 12, 30));
      expect(SalesFormatters.periodTitle(p, now: now), '1월 1주차');
      expect(SalesFormatters.periodSubtitle(p), '12월 29일 ~ 1월 4일');
    });

    test('연말: 2026-12-28~2027-01-03 → 목요일 12/31 → 12월 5주차', () {
      final p = SalesPeriod.week(kst(2026, 12, 30));
      expect(SalesFormatters.periodTitle(p, now: now), '12월 5주차');
      expect(SalesFormatters.periodSubtitle(p), '12월 28일 ~ 1월 3일');
    });

    test('작년이면 연도 표기', () {
      final p = SalesPeriod.week(kst(2025, 12, 3));
      expect(SalesFormatters.periodTitle(p, now: now), '2025년 12월 1주차');
    });

    test('윤년 2월: 2028-02-29(화) 주 → 3월 1주차', () {
      // 2028-02-28(월)~03-05(일): 목요일 3/2 → 3월 1주차
      final p = SalesPeriod.week(kst(2028, 2, 29));
      expect(SalesFormatters.periodTitle(p, now: kst(2028, 3, 1)), '3월 1주차');
      expect(SalesFormatters.periodSubtitle(p), '2월 28일 ~ 3월 5일');
    });
  });

  group('일 / 월 라벨', () {
    test('올해 일: 연도 생략 + 요일', () {
      expect(
        SalesFormatters.periodTitle(SalesPeriod.day(now), now: now),
        '10월 21일 (수)',
      );
    });

    test('작년 일: 연도 표기', () {
      expect(
        SalesFormatters.periodTitle(
          SalesPeriod.day(kst(2025, 12, 31)),
          now: now,
        ),
        '2025년 12월 31일 (수)',
      );
    });

    test('올해 판정은 KST: UTC 로는 작년이어도 KST 새해면 올해', () {
      // 2026-12-31 15:00 UTC == 2027-01-01 00:00 KST
      final p = SalesPeriod.day(DateTime.utc(2026, 12, 31, 15));
      expect(
        SalesFormatters.periodTitle(p, now: DateTime.utc(2026, 12, 31, 15)),
        '1월 1일 (금)',
      );
    });

    test('월은 항상 연도 포함, 부제 없음', () {
      final p = SalesPeriod.month(now);
      expect(SalesFormatters.periodTitle(p, now: now), '2026년 10월');
      expect(SalesFormatters.periodSubtitle(p), isNull);
    });
  });

  group('주문 행 시각 (KST)', () {
    test('디바이스 타임존과 무관하게 KST 로 표시', () {
      final t = DateTime.utc(2026, 10, 21, 5, 35); // KST 14:35
      expect(SalesFormatters.orderTime(t, SalesPeriodType.day), '14:35');
      expect(SalesFormatters.orderTime(t, SalesPeriodType.week), '10/21 14:35');
      expect(
        SalesFormatters.orderTimeSemantic(t, SalesPeriodType.month),
        '10월 21일 14시 35분',
      );
    });
  });
}
