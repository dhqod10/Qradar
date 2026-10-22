import 'package:intl/intl.dart';
import 'package:qradar/core/constants/sales_query_limits.dart';
import 'package:qradar/core/utils/kst.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/sales_period.dart';

/// 매출 화면 표시용 순수 포매터.
///
/// **KST 변환은 이 파일(+[Kst])에서만** 일어난다. 위젯은 instant([DateTime])를
/// 그대로 넘기고 문자열만 받는다 (spec D4).
class SalesFormatters {
  SalesFormatters._();

  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String weekdayName(DateTime wall) => _weekdays[wall.weekday - 1];

  // ── 기간 라벨 ──────────────────────────────────────────────────────────────

  /// 네비게이터 제목.
  /// 일: `10월 21일 (수)` (올해 아니면 `2025년 12월 31일 (수)`)
  /// 주: `10월 4주차` — 목요일이 속한 달의 n번째 목요일 (ISO 8601)
  /// 월: `2026년 10월` (항상 연도 포함)
  /// "올해" 는 KST 기준 [now] 의 연도.
  static String periodTitle(SalesPeriod period, {DateTime? now}) {
    final thisYear = Kst.toWall(now ?? DateTime.now()).year;
    switch (period.type) {
      case SalesPeriodType.day:
        final w = period.startWall;
        final y = w.year == thisYear ? '' : '${w.year}년 ';
        return '$y${w.month}월 ${w.day}일 (${weekdayName(w)})';
      case SalesPeriodType.week:
        final th = period.thursdayWall;
        final y = th.year == thisYear ? '' : '${th.year}년 ';
        return '$y${th.month}월 ${weekOfMonth(th)}주차';
      case SalesPeriodType.month:
        final w = period.startWall;
        return '${w.year}년 ${w.month}월';
    }
  }

  /// 주 단위 부제 `10월 19일 ~ 10월 25일`. 일/월은 null.
  static String? periodSubtitle(SalesPeriod period) {
    if (period.type != SalesPeriodType.week) return null;
    final s = period.startWall;
    final e = period.lastDayWall;
    return '${s.month}월 ${s.day}일 ~ ${e.month}월 ${e.day}일';
  }

  /// 목요일(KST wall) 이 속한 달의 n번째 목요일 = 주차.
  static int weekOfMonth(DateTime thursdayWall) =>
      (thursdayWall.day - 1) ~/ 7 + 1;

  static String currentPillLabel(SalesPeriodType type) {
    switch (type) {
      case SalesPeriodType.day:
        return '오늘';
      case SalesPeriodType.week:
        return '이번 주';
      case SalesPeriodType.month:
        return '이번 달';
    }
  }

  static String periodSemanticLabel(SalesPeriod period, {DateTime? now}) {
    final title = periodTitle(period, now: now);
    final sub = periodSubtitle(period);
    if (sub == null) return title;
    return '$title, ${sub.replaceFirst(' ~ ', '부터 ')}';
  }

  // ── 주문 행 ────────────────────────────────────────────────────────────────

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 일 단위 `14:35`, 주·월 단위 `10/21 14:35` (KST).
  static String orderTime(DateTime createdAt, SalesPeriodType type) {
    final w = Kst.toWall(createdAt);
    final hm = '${_two(w.hour)}:${_two(w.minute)}';
    if (type == SalesPeriodType.day) return hm;
    return '${_two(w.month)}/${_two(w.day)} $hm';
  }

  /// 스크린리더용 `14시 35분` / `10월 21일 14시 35분` (KST).
  static String orderTimeSemantic(DateTime createdAt, SalesPeriodType type) {
    final w = Kst.toWall(createdAt);
    final hm = '${w.hour}시 ${w.minute}분';
    if (type == SalesPeriodType.day) return hm;
    return '${w.month}월 ${w.day}일 $hm';
  }

  /// 대표 메뉴 요약. `아메리카노` / `아메리카노 ×2` / `아메리카노 ×2 외 1개`.
  static String menuSummary(OrderEntity order) {
    if (order.items.isEmpty) return '항목 없음';
    final first = order.items.first;
    final qty = first.quantity > 1 ? ' ×${first.quantity}' : '';
    final more = order.items.length > 1 ? ' 외 ${order.items.length - 1}개' : '';
    return '${first.menuItemName}$qty$more';
  }

  /// 스크린리더용 메뉴 요약 (`×2` → `2개`).
  static String menuSummarySemantic(OrderEntity order) => menuSummary(
    order,
  ).replaceAllMapped(RegExp(r'×(\d+)'), (m) => '${m.group(1)}개');

  // ── 한계 고지 문구 (숫자는 SalesQueryLimits 에서) ─────────────────────────

  static String get limitText =>
      NumberFormat('#,###').format(SalesQueryLimits.maxDocumentsPerQuery);

  static String get truncatedWarning => '주문이 많아 최근 $limitText건만 집계했어요';

  static String get truncatedListFootnote => '최근 $limitText건까지만 표시돼요';
}
