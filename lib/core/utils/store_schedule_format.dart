import 'package:qradar/core/utils/store_sellability.dart';

/// 영업 스케줄 표시용 순수 포맷터 (store_business_schedule design §1.6, §2.5, §3.0). 외부 SDK 의존 없음.

const List<String> _kDayLabel = ['월', '화', '수', '목', '금', '토', '일'];

/// 1=월 … 7=일 → '월' … '일'
String dayLabelOf(int weekday) => _kDayLabel[(weekday - 1) % 7];

/// 요일별 영업시간 요약 — 점주 요약줄 / 내 매장 / 관리자 상세 / 손님 표기가 모두 이 한 곳을 쓴다.
///
/// - `null` → `영업시간 제한 없음` (스케줄 미설정)
/// - 빈 맵 → `모든 요일 휴무`
/// - 같은 시간의 요일을 묶는다: 3일 이상 연속이면 `월~금`, 그 외 `월·수·금`. 7일 모두 같으면 `매일`.
/// - 휴무 요일은 끝에 `일 휴무` / `월·화 휴무`. 자정 넘김은 `22:00–익일 02:00`.
String formatWeeklySummary(WeeklyHoursInput? weekly) {
  if (weekly == null) return '영업시간 제한 없음';
  final open = <int>[
    for (var d = 1; d <= 7; d++)
      if (weekly[d] != null) d,
  ];
  if (open.isEmpty) return '모든 요일 휴무';

  final groups = <({String key, List<int> days})>[];
  for (final d in open) {
    final e = weekly[d]!;
    final key = _range(e);
    final i = groups.indexWhere((g) => g.key == key);
    if (i >= 0) {
      groups[i].days.add(d);
    } else {
      groups.add((key: key, days: [d]));
    }
  }
  final off = <int>[
    for (var d = 1; d <= 7; d++)
      if (weekly[d] == null) d,
  ];

  final parts = <String>[];
  for (final g in groups) {
    final days = g.days.length == 7 ? '매일' : _daysLabel(g.days);
    parts.add('$days ${g.key}');
  }
  if (off.isNotEmpty) parts.add('${_daysLabel(off)} 휴무');
  return parts.join(' · ');
}

String _range(ScheduleDayHours e) {
  final overnight = e.close.compareTo(e.open) < 0;
  return '${e.open}–${overnight ? '익일 ' : ''}${e.close}';
}

/// 연속 3일 이상 `a~b`, 그 외 `a·b`.
String _daysLabel(List<int> days) {
  final out = <String>[];
  var i = 0;
  while (i < days.length) {
    var j = i;
    while (j + 1 < days.length && days[j + 1] == days[j] + 1) {
      j++;
    }
    final len = j - i + 1;
    if (len >= 3) {
      out.add('${dayLabelOf(days[i])}~${dayLabelOf(days[j])}');
    } else {
      for (var k = i; k <= j; k++) {
        out.add(dayLabelOf(days[k]));
      }
    }
    i = j + 1;
  }
  return out.join('·');
}

/// `nextOpenAt`("YYYY-MM-DDTHH:mm" KST) → `오늘 18:00` / `내일(수) 09:00` / `11/9(월) 09:00`.
/// [todayDateKey] = 지금의 KST 날짜키. 해석 불가면 null.
String? formatNextOpen(String? nextOpenAt, String todayDateKey) {
  if (nextOpenAt == null || nextOpenAt.length != 16) return null;
  final date = nextOpenAt.substring(0, 10);
  final hm = nextOpenAt.substring(11);
  final d = _parseDate(date);
  final t = _parseDate(todayDateKey);
  if (d == null || t == null) return null;
  final diff = d.difference(t).inDays;
  if (diff == 0) return '오늘 $hm';
  final wd = dayLabelOf(d.weekday);
  if (diff == 1) return '내일($wd) $hm';
  return '${d.month}/${d.day}($wd) $hm';
}

/// `closeAt`("YYYY-MM-DDTHH:mm") → `21:00까지` / `익일 02:00까지`.
String? formatCloseAt(String? closeAt, String todayDateKey) {
  if (closeAt == null || closeAt.length != 16) return null;
  final hm = closeAt.substring(11);
  return closeAt.substring(0, 10) == todayDateKey ? '$hm까지' : '익일 $hm까지';
}

DateTime? _parseDate(String key) {
  final p = key.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}
