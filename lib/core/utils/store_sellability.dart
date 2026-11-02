/// "지금 이 매장이 주문을 받을 수 있는가" — 단일 판정 (payment_server_authority spec §6.3).
///
/// 서버 게이트(`functions/src/storeSellability.ts`)와 **같은 규칙**이며 교차 골든
/// (`test_fixtures/store_sellability_contract.json`)으로 고정된다. 판정식(Q1 ⓑ′):
///
///   `status == 'approved' || (status == 'pending' && approvedAt != null)`
///
/// - **입력은 가공 전 원시값이다.** `EntityApprovalStatus.fromString` 을 통과시키지 않는다 — 그 함수는 알 수 없는
///   값/부재를 `approved` 로 폴백(legacy 안전)하는 fail-open 이고, 돈 게이트는 그것을 복제할 수 없다 (spec §8.1).
/// - 이것은 **돈을 받을까** 의 질문이다. 고객 매장 목록의 노출 필터(`status == approved`)는 "보여줄까" 의 질문이라
///   이 함수로 통합하지 않는다 (spec §6.3 / §12 사실 1).
/// - 순수 Dart. 외부 SDK import 금지.
///
/// [scheduleClosedNow] 는 승인 전용 판정(예: 마이그레이션 이상치)에서는 생략(false)한다.
bool canSellNow({
  required String? rawStatus,
  required bool hasApprovedAt,
  required bool temporaryClosed,
  bool scheduleClosedNow = false,
}) =>
    storeGateReason(
      rawStatus: rawStatus,
      hasApprovedAt: hasApprovedAt,
      temporaryClosed: temporaryClosed,
      scheduleClosedNow: scheduleClosedNow,
    ) ==
    null;

/// 판매 불가 사유 코드 (서버 `GateReason` 과 동일 문자열).
const String kStoreNotSellable = 'STORE_NOT_SELLABLE';
const String kStoreTemporarilyClosed = 'STORE_TEMPORARILY_CLOSED';
const String kStoreClosedSchedule = 'STORE_CLOSED_SCHEDULE';

/// 판매 불가 **사유** 를 돌려주는 단일 판정 (temporary_closed_gate spec D1). 판매 가능이면 `null`.
///
/// 우선순위: ① 승인 조건 실패 → [kStoreNotSellable] (`temporaryClosed`/스케줄 무시)
/// ② 임시 휴업 → [kStoreTemporarilyClosed] ③ 스케줄상 닫힘 → [kStoreClosedSchedule] ④ `null`.
/// TS `storeGateReason` 과 같은 규칙이며 교차 골든으로 고정된다.
///
/// 시간(now)은 이 함수 안에서 읽지 않는다 — 호출자가 [isStoreOpenNow] 로 판정해 [scheduleClosedNow] 로 **주입**한다.
String? storeGateReason({
  required String? rawStatus,
  required bool hasApprovedAt,
  required bool temporaryClosed,
  required bool scheduleClosedNow,
}) {
  final approved =
      rawStatus == 'approved' || (rawStatus == 'pending' && hasApprovedAt);
  if (!approved) return kStoreNotSellable;
  if (temporaryClosed) return kStoreTemporarilyClosed;
  if (scheduleClosedNow) return kStoreClosedSchedule;
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════
// 영업 스케줄 판정 (store_business_schedule spec §D1) — TS `storeSellability.ts` 와 한 사실에 하나.
// ═══════════════════════════════════════════════════════════════════════════

/// 요일 하나의 영업 구간. "HH:mm" 24시 KST. `open > close` = 자정 넘김. 파싱 실패 / `open == close` = 그 요일 닫힘.
typedef ScheduleDayHours = ({String open, String close});

/// 요일별 영업시간 (1=월 … 7=일, ISO-8601). **엔트리 부재 = 그날 휴무.** 맵 자체가 `null` 이면 "시간 제한 없음".
typedef WeeklyHoursInput = Map<int, ScheduleDayHours>;

/// 호출자가 KST 로 계산해 넘기는 "지금" (순수 함수에 시계를 넣지 않기 위한 주입값).
class KstClock {
  const KstClock({
    required this.weekday,
    required this.minuteOfDay,
    required this.dateKey,
  });

  /// 1=월 … 7=일
  final int weekday;

  /// 0..1439
  final int minuteOfDay;

  /// "YYYY-MM-DD" (KST)
  final String dateKey;
}

const Duration _kstOffset = Duration(hours: 9);

/// 순간(instant) → KST 요일·분·날짜키. 서버는 신뢰 시계, 클라는 기기 시계를 넣는다 (서버가 권위).
KstClock kstClockOf(DateTime instant) {
  final k = instant.toUtc().add(_kstOffset);
  return KstClock(
    weekday: k.weekday,
    minuteOfDay: k.hour * 60 + k.minute,
    dateKey: _fmtDate(k.year, k.month, k.day),
  );
}

/// `closedDates` 를 "YYYY-MM-DD"(KST) 키 집합으로 정규화한다.
Set<String> closedDateKeysOf(Iterable<DateTime> closedDates) => {
      for (final d in closedDates) kstClockOf(d).dateKey,
    };

enum StoreOpenKind {
  /// 스케줄 미설정(`weeklyHours == null`) — 시간 제한 없음. 표시 없음 / 주문 허용.
  unrestricted,

  /// 영업 중.
  open,

  /// 오늘 영업 엔트리가 없거나 오늘이 `closedDates` — 정기 휴무.
  regularHoliday,

  /// 오늘 영업일이지만 지금은 구간 밖.
  outsideHours,
}

/// [evaluateStoreOpenState] 결과. [nextOpenAt]/[closeAt] 은 "YYYY-MM-DDTHH:mm" (KST 벽시계 문자열 — 시간대 없음).
class StoreOpenState {
  const StoreOpenState({
    required this.kind,
    this.nextOpenAt,
    this.closeAt,
    this.todayRange,
  });

  final StoreOpenKind kind;

  /// 닫혀 있을 때 다음 영업 시작 (오늘 포함 8일 내 탐색, 못 찾으면 null).
  final String? nextOpenAt;

  /// 영업 중일 때 이번 구간의 종료.
  final String? closeAt;

  /// 오늘 영업 구간 표기 `09:00–18:00` (자정 넘김이면 `22:00–익일 02:00`). 오늘 구간이 없으면 null.
  final String? todayRange;

  /// 주문을 받을 수 있는 시간대인가 (미설정 포함).
  bool get isOpen =>
      kind == StoreOpenKind.open || kind == StoreOpenKind.unrestricted;
}

class _Session {
  const _Session(this.open, this.close);
  final int open;
  final int close;
  bool get overnight => close < open;
}

int? _parseHm(String s) {
  final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(s);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

String _fmtDate(int y, int m, int d) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

String _addDays(String dateKey, int n) {
  final p = dateKey.split('-');
  final d = DateTime.utc(
    int.parse(p[0]),
    int.parse(p[1]),
    int.parse(p[2]),
  ).add(Duration(days: n));
  return _fmtDate(d.year, d.month, d.day);
}

String _fmtHm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

/// 지금 영업 중인가 + 다음 영업 시각 / 종료 시각. 순수 — 시계는 인자로 받는다.
///
/// 규칙 (spec §D1 + 설계 단계 Q1):
/// - `weeklyHours == null` → 시간 제한 없음 ([StoreOpenKind.unrestricted]). 빈 맵(`{}`) = 점주가 저장한 **전체 휴무**.
/// - 오늘이 `closedDateKeys` 에 있으면 영업시간 무관 닫힘 (스케줄 미설정이어도 적용).
/// - 자정 넘김(`close < open`): `[open, 24:00) ∪ 다음날 [00:00, close)`. 새벽 구간은 **영업을 시작한 요일** 소속이라
///   지금이 새벽이면 전일 구간(전일이 `closedDates` 가 아닐 때)도 검사한다.
StoreOpenState evaluateStoreOpenState({
  required WeeklyHoursInput? weeklyHours,
  required Set<String> closedDateKeys,
  required int nowWeekday,
  required int nowMinuteOfDay,
  required String nowDateKey,
}) {
  final closedToday = closedDateKeys.contains(nowDateKey);

  _Session? sessionOn(String dateKey, int weekday) {
    if (closedDateKeys.contains(dateKey)) return null;
    if (weeklyHours == null) return const _Session(0, 1440);
    final e = weeklyHours[weekday];
    if (e == null) return null;
    final o = _parseHm(e.open);
    final c = _parseHm(e.close);
    if (o == null || c == null || o == c) return null;
    return _Session(o, c);
  }

  String? nextOpen() {
    for (var off = 0; off <= 8; off++) {
      final key = _addDays(nowDateKey, off);
      final wd = ((nowWeekday - 1 + off) % 7) + 1;
      final s = sessionOn(key, wd);
      if (s == null) continue;
      if (off == 0 && s.open <= nowMinuteOfDay) continue;
      return '${key}T${_fmtHm(s.open % 1440)}';
    }
    return null;
  }

  if (weeklyHours == null) {
    if (!closedToday) {
      return const StoreOpenState(kind: StoreOpenKind.unrestricted);
    }
    return StoreOpenState(
      kind: StoreOpenKind.regularHoliday,
      nextOpenAt: nextOpen(),
    );
  }

  final today = sessionOn(nowDateKey, nowWeekday);
  String? todayRange;
  if (today != null) {
    todayRange =
        '${_fmtHm(today.open)}–${today.overnight ? '익일 ' : ''}${_fmtHm(today.close)}';
  }

  if (!closedToday) {
    if (today != null) {
      if (!today.overnight &&
          nowMinuteOfDay >= today.open &&
          nowMinuteOfDay < today.close) {
        return StoreOpenState(
          kind: StoreOpenKind.open,
          closeAt: '${nowDateKey}T${_fmtHm(today.close)}',
          todayRange: todayRange,
        );
      }
      if (today.overnight && nowMinuteOfDay >= today.open) {
        return StoreOpenState(
          kind: StoreOpenKind.open,
          closeAt: '${_addDays(nowDateKey, 1)}T${_fmtHm(today.close)}',
          todayRange: todayRange,
        );
      }
    }
    final prev = sessionOn(
      _addDays(nowDateKey, -1),
      nowWeekday == 1 ? 7 : nowWeekday - 1,
    );
    if (prev != null && prev.overnight && nowMinuteOfDay < prev.close) {
      return StoreOpenState(
        kind: StoreOpenKind.open,
        closeAt: '${nowDateKey}T${_fmtHm(prev.close)}',
        todayRange: todayRange,
      );
    }
  }

  return StoreOpenState(
    kind: today == null ? StoreOpenKind.regularHoliday : StoreOpenKind.outsideHours,
    nextOpenAt: nextOpen(),
    todayRange: todayRange,
  );
}

/// 지금 영업 중인가 (스케줄 미설정 = true). [storeGateReason] 의 `scheduleClosedNow` 는 `!isStoreOpenNow(...)`.
bool isStoreOpenNow({
  required WeeklyHoursInput? weeklyHours,
  required Set<String> closedDateKeys,
  required int nowWeekday,
  required int nowMinuteOfDay,
  required String nowDateKey,
}) => evaluateStoreOpenState(
      weeklyHours: weeklyHours,
      closedDateKeys: closedDateKeys,
      nowWeekday: nowWeekday,
      nowMinuteOfDay: nowMinuteOfDay,
      nowDateKey: nowDateKey,
    ).isOpen;

/// 편의: 순간(instant) 하나로 [evaluateStoreOpenState]. UI·선검증이 쓴다 (판정 로직은 위 한 곳).
StoreOpenState evaluateStoreOpenStateAt({
  required WeeklyHoursInput? weeklyHours,
  required Iterable<DateTime> closedDates,
  required DateTime instant,
}) {
  final c = kstClockOf(instant);
  return evaluateStoreOpenState(
    weeklyHours: weeklyHours,
    closedDateKeys: closedDateKeysOf(closedDates),
    nowWeekday: c.weekday,
    nowMinuteOfDay: c.minuteOfDay,
    nowDateKey: c.dateKey,
  );
}
