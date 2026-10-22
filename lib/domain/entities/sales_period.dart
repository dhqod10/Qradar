import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/core/constants/sales_query_limits.dart';
import 'package:qradar/core/utils/kst.dart';

part 'sales_period.freezed.dart';

/// 매출 조회 기간 단위.
enum SalesPeriodType { day, week, month }

/// 매출 조회 기간 값 객체. 경계는 `[start, endExclusive)` 반열린 구간.
///
/// - [start] / [endExclusive] 는 절대 시각(UTC instant)이다.
/// - 달력 계산(일/주/월 경계)은 **KST(UTC+9) 고정** (spec D4). 계산은 이 클래스의
///   팩토리에만 존재한다.
/// - 주는 **월요일 시작**, 주차는 **목요일 소속(ISO 8601)** (spec D3 / R1).
/// - 모든 "현재" 의존 로직은 `now` 를 주입할 수 있다 (단위 테스트 전제).
@freezed
abstract class SalesPeriod with _$SalesPeriod {
  const SalesPeriod._();

  const factory SalesPeriod({
    required SalesPeriodType type,
    required DateTime start,
    required DateTime endExclusive,
  }) = _SalesPeriod;

  /// [anchor] 가 속한 KST 하루.
  factory SalesPeriod.day(DateTime anchor) {
    final w = Kst.toWall(anchor);
    return SalesPeriod(
      type: SalesPeriodType.day,
      start: Kst.fromWall(w.year, w.month, w.day),
      endExclusive: Kst.fromWall(w.year, w.month, w.day + 1),
    );
  }

  /// [anchor] 가 속한 KST 주 (월요일 00:00 ~ 다음 월요일 00:00).
  factory SalesPeriod.week(DateTime anchor) {
    final w = Kst.toWall(anchor);
    final mondayDay = w.day - (w.weekday - DateTime.monday);
    return SalesPeriod(
      type: SalesPeriodType.week,
      start: Kst.fromWall(w.year, w.month, mondayDay),
      endExclusive: Kst.fromWall(w.year, w.month, mondayDay + 7),
    );
  }

  /// [anchor] 가 속한 KST 달.
  factory SalesPeriod.month(DateTime anchor) {
    final w = Kst.toWall(anchor);
    return SalesPeriod(
      type: SalesPeriodType.month,
      start: Kst.fromWall(w.year, w.month, 1),
      endExclusive: Kst.fromWall(w.year, w.month + 1, 1),
    );
  }

  /// [now] (기본 `DateTime.now()`) 가 속한 [type] 단위 기간.
  factory SalesPeriod.current(SalesPeriodType type, {DateTime? now}) =>
      SalesPeriod.ofType(type, now ?? DateTime.now());

  /// [anchor] 가 속한 [type] 단위 기간.
  factory SalesPeriod.ofType(SalesPeriodType type, DateTime anchor) {
    switch (type) {
      case SalesPeriodType.day:
        return SalesPeriod.day(anchor);
      case SalesPeriodType.week:
        return SalesPeriod.week(anchor);
      case SalesPeriodType.month:
        return SalesPeriod.month(anchor);
    }
  }

  // ── 이동 ───────────────────────────────────────────────────────────────────

  /// 직전 기간 (같은 단위).
  SalesPeriod previous() =>
      SalesPeriod.ofType(type, start.subtract(const Duration(milliseconds: 1)));

  /// 다음 기간 (같은 단위).
  SalesPeriod next() => SalesPeriod.ofType(type, endExclusive);

  /// [now] 가 이 기간에 속하는가.
  bool isCurrent({DateTime? now}) {
    final n = (now ?? DateTime.now()).toUtc();
    return !n.isBefore(start) && n.isBefore(endExclusive);
  }

  /// 다음 기간으로 이동 가능한가. 이미 끝난 기간만 가능 (미래 기간 불가).
  bool canGoNext({DateTime? now}) {
    final n = (now ?? DateTime.now()).toUtc();
    return !endExclusive.isAfter(n);
  }

  /// 이전 기간으로 이동 가능한가.
  /// 현재 달 1일 기준 [SalesQueryLimits.maxMonthsBack] 개월 전 경계와 겹치는
  /// 기간까지만 허용한다.
  bool canGoPrevious({DateTime? now}) {
    final w = Kst.toWall(now ?? DateTime.now());
    final oldestStart = Kst.fromWall(
      w.year,
      w.month - SalesQueryLimits.maxMonthsBack,
      1,
    );
    return start.isAfter(oldestStart);
  }

  // ── 표시/버킷 보조 ──────────────────────────────────────────────────────────

  /// 시작일의 KST wall (년월일 판독용).
  DateTime get startWall => Kst.toWall(start);

  /// 마지막 날(`endExclusive - 1일`)의 KST wall.
  DateTime get lastDayWall =>
      Kst.toWall(endExclusive.subtract(const Duration(days: 1)));

  /// 주 단위 전용: 이 주의 목요일(KST wall). 주차/ISO 연도 판정 기준.
  DateTime get thursdayWall {
    final s = startWall;
    return DateTime.utc(s.year, s.month, s.day + 3);
  }

  /// CF 집계 버킷 키와 1:1 대응 (`2026-10-21` / `2026-W43` / `2026-10`).
  String get bucketKey {
    final s = startWall;
    switch (type) {
      case SalesPeriodType.day:
        return '${s.year}-${_two(s.month)}-${_two(s.day)}';
      case SalesPeriodType.month:
        return '${s.year}-${_two(s.month)}';
      case SalesPeriodType.week:
        final th = thursdayWall;
        final dayOfYear = th.difference(DateTime.utc(th.year, 1, 1)).inDays + 1;
        final isoWeek = (dayOfYear - 1) ~/ 7 + 1;
        return '${th.year}-W${_two(isoWeek)}';
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
