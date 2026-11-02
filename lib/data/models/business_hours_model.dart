import 'package:qradar/domain/entities/business_hours.dart';

/// Firestore `stores/{id}.businessHours` 맵 매퍼.
///
/// 신 스키마: `{ weeklyHours: { "1": {open, close}, ... } }` (키 부재 요일 = 휴무, 빈 맵 = 전체 휴무).
/// legacy `{openTime, closeTime, closedDays}` 는 읽기 시점에 "7요일 동일 시간(closedDays 제외)" 로 흡수한다.
/// 서버 `parseWeeklyHours`(functions/src/storeSellability.ts) 와 같은 규칙 — 교차 골든(`parseCases`)으로 고정.
class BusinessHoursModel {
  final Map<int, BusinessDayHours> weeklyHours;

  const BusinessHoursModel({required this.weeklyHours});

  static final RegExp _hm = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// 원시값 해석. 해석 불가/미설정 구조는 `null` = **시간 제한 없음** (Q1 — 기존 매장이 막히지 않게).
  static BusinessHoursModel? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final wh = raw['weeklyHours'];
    if (wh != null) {
      if (wh is! Map) return null;
      final out = <int, BusinessDayHours>{};
      for (final e in wh.entries) {
        final k = e.key;
        if (k is! String || !RegExp(r'^[1-7]$').hasMatch(k)) continue;
        final v = e.value;
        if (v is! Map) continue;
        final open = v['open'];
        final close = v['close'];
        if (open is! String || close is! String) continue;
        out[int.parse(k)] = BusinessDayHours(open: open, close: close);
      }
      return BusinessHoursModel(weeklyHours: out);
    }
    final openTime = raw['openTime'];
    final closeTime = raw['closeTime'];
    if (openTime is String && closeTime is String) {
      if (!_hm.hasMatch(openTime) || !_hm.hasMatch(closeTime)) return null;
      final closedRaw = raw['closedDays'];
      final closed = <int>{
        if (closedRaw is List)
          for (final x in closedRaw)
            if (x is num) x.toInt(),
      };
      return BusinessHoursModel(
        weeklyHours: {
          for (var d = 1; d <= 7; d++)
            if (!closed.contains(d))
              d: BusinessDayHours(open: openTime, close: closeTime),
        },
      );
    }
    return null;
  }

  factory BusinessHoursModel.fromEntity(BusinessHours entity) =>
      BusinessHoursModel(weeklyHours: entity.weeklyHours);

  Map<String, dynamic> toMap() => <String, dynamic>{
        'weeklyHours': {
          for (final e in weeklyHours.entries)
            '${e.key}': {'open': e.value.open, 'close': e.value.close},
        },
      };

  BusinessHours toEntity() => BusinessHours(weeklyHours: weeklyHours);
}
