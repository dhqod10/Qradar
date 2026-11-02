import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/store_schedule_format.dart';
import 'package:qradar/domain/entities/business_hours.dart';

/// 요일별 영업 스케줄 편집 카드 (store_business_schedule design §1).
///
/// 운영 폼(미설정 허용)과 신규 등록 폼([required] — 건너뛰기 없음)이 공유한다. 저장은 호출한 폼의 버튼이 담당한다
/// (필드별 자동저장 아님, Q3). 값 [value]: `null` = 스케줄 미설정(시간 제한 없음), 빈 맵 = 전체 휴무.
class WeeklyScheduleEditor extends StatefulWidget {
  const WeeklyScheduleEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
  });

  final BusinessHours? value;
  final ValueChanged<BusinessHours?> onChanged;

  /// true = 신규 등록 (Q7): `스케줄 사용 안 함` 없음, 미설정 안내가 필수 문구.
  final bool required;
  final bool enabled;

  /// 저장 불가 행(시작 == 종료)이 있는가 (Q2).
  static bool hasInvalidRow(BusinessHours? h) =>
      h != null && h.weeklyHours.values.any((e) => e.open == e.close);

  static const BusinessDayHours defaultDay = BusinessDayHours(
    open: '09:00',
    close: '18:00',
  );

  @override
  State<WeeklyScheduleEditor> createState() => _WeeklyScheduleEditorState();
}

class _WeeklyScheduleEditorState extends State<WeeklyScheduleEditor> {
  /// 파생 UI 상태 (저장하지 않음): 월~금 묶음 보기.
  late bool _grouped;

  /// 휴무로 껐다 다시 켤 때 복원할 마지막 시간.
  final Map<int, BusinessDayHours> _lastTimes = {};

  Map<int, BusinessDayHours> get _w =>
      widget.value?.weeklyHours ?? const <int, BusinessDayHours>{};

  static const _weekdays = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _grouped = _weekdaysUniform(_w);
  }

  static bool _weekdaysUniform(Map<int, BusinessDayHours> w) {
    final first = w[1];
    for (final d in _weekdays) {
      if (w[d] != first) return false;
    }
    return true;
  }

  void _emit(Map<int, BusinessDayHours> next) =>
      widget.onChanged(BusinessHours(weeklyHours: Map.unmodifiable(next)));

  void _setDays(List<int> days, BusinessDayHours? h) {
    final next = Map<int, BusinessDayHours>.from(_w);
    for (final d in days) {
      final prev = next[d];
      if (prev != null) _lastTimes[d] = prev;
      if (h == null) {
        next.remove(d);
      } else {
        next[d] = h;
      }
    }
    _emit(next);
  }

  void _toggle(List<int> days, bool on) {
    if (!on) {
      _setDays(days, null);
      return;
    }
    final restore = _lastTimes[days.first] ?? WeeklyScheduleEditor.defaultDay;
    _setDays(days, restore);
  }

  void _setTime(List<int> days, {String? open, String? close}) {
    final cur = _w[days.first] ?? WeeklyScheduleEditor.defaultDay;
    _setDays(
      days,
      BusinessDayHours(open: open ?? cur.open, close: close ?? cur.close),
    );
  }

  Future<void> _showAsUngroup() async {
    if (!_grouped) {
      if (_weekdaysUniform(_w)) {
        setState(() => _grouped = true);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '월~금을 같은 시간으로 맞출까요?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          content: const Text(
            '지금 요일마다 다른 시간이 월요일 기준 시간으로 바뀌어요.',
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                '맞추기',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      _setDays(_weekdays, _w[1]);
      setState(() => _grouped = true);
      return;
    }
    setState(() => _grouped = false);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '시간 제한 없이 주문을 받을까요?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          '영업 스케줄을 지우면 영업시간과 관계없이 항상 주문을 받아요. 특정 날짜 휴무는 그대로 유지돼요.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '지우기',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.onChanged(null);
  }

  Future<void> _openCopySheet() async {
    final result = await showModalBottomSheet<({int source, Set<int> targets})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CopyDaysSheet(),
    );
    if (result == null || !mounted) return;
    final src = _w[result.source];
    _setDays(result.targets.toList()..sort(), src);
    // 월~금이 서로 달라졌으면 요일별 보기로 (같으면 묶음 유지).
    if (_grouped && !_weekdaysUniform(widget.value?.weeklyHours ?? {})) {
      setState(() => _grouped = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.value != null;
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: AppColors.textHeading,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.required ? '영업 스케줄 (필수)' : '영업 스케줄',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const Spacer(),
                  if (set && !widget.required)
                    TextButton(
                      onPressed: _confirmClear,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        '스케줄 사용 안 함',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '요일마다 영업 시간을 다르게 정할 수 있어요. 시간이 없는 요일은 휴무예요.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              if (!set) _unsetBody() else ..._setBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unsetBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                widget.required
                    ? Icons.edit_calendar_outlined
                    : Icons.all_inclusive_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.required
                      ? '영업 요일과 시간을 설정해 주세요. 설정하지 않으면 등록할 수 없어요.'
                      : '영업 스케줄이 없어요. 지금은 시간 제한 없이 주문을 받아요.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              _grouped = true;
              _emit({
                for (final d in _weekdays) d: WeeklyScheduleEditor.defaultDay,
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '영업 스케줄 설정하기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _setBody() {
    final w = _w;
    final rows = <Widget>[];
    void addRow(Widget r) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, color: AppColors.border));
      }
      rows.add(r);
    }

    if (_grouped) {
      addRow(
        _DayRow(
          label: '평일',
          sub: '월~금',
          entry: w[1],
          onToggle: (on) => _toggle(_weekdays, on),
          onOpen: (t) => _setTime(_weekdays, open: t),
          onClose: (t) => _setTime(_weekdays, close: t),
        ),
      );
      for (final d in [6, 7]) {
        addRow(_rowFor(d, w));
      }
    } else {
      for (var d = 1; d <= 7; d++) {
        addRow(_rowFor(d, w));
      }
    }

    final summary = formatWeeklySummary(widget.value!.scheduleInput);
    return [
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(children: rows),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _showAsUngroup,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          child: Text(
            _grouped ? '요일별로 따로 설정' : '평일 묶어서 보기',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _openCopySheet,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          icon: const Icon(
            Icons.content_copy_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          label: const Text(
            '다른 요일에 복사',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '손님에게 보이는 영업시간',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
          ],
        ),
      ),
      if (w.isEmpty) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '모든 요일이 휴무예요',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeading,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '이대로 저장하면 매장이 영구 휴업 상태가 돼요. 손님은 주문할 수 없어요.',
                        style: TextStyle(fontSize: 12, color: AppColors.textBody),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _rowFor(int d, Map<int, BusinessDayHours> w) => _DayRow(
    label: dayLabelOf(d),
    entry: w[d],
    onToggle: (on) => _toggle([d], on),
    onOpen: (t) => _setTime([d], open: t),
    onClose: (t) => _setTime([d], close: t),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    this.sub,
    required this.entry,
    required this.onToggle,
    required this.onOpen,
    required this.onClose,
  });

  final String label;
  final String? sub;
  final BusinessDayHours? entry;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final equal = e != null && e.open == e.close;
    final overnight = e != null && !equal && e.close.compareTo(e.open) < 0;
    return Semantics(
      container: true,
      label: e == null
          ? '$label요일 휴무'
          : '$label요일, 영업, ${e.open}부터 ${e.close}까지',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeading,
                          ),
                        ),
                        if (sub != null)
                          Text(
                            sub!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: e == null
                        ? const Text(
                            '휴무',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _TimeTile(value: e.open, onPick: onOpen),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '~',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                              Expanded(
                                child: _TimeTile(
                                  value: e.close,
                                  prefix: overnight ? '익일' : null,
                                  error: equal,
                                  onPick: onClose,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: e != null,
                    onChanged: onToggle,
                    activeThumbColor: AppColors.onPrimary,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surface,
                    inactiveThumbColor: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            if (equal)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 12,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '시작과 종료 시간이 같아요 (24시간 영업은 00:00 ~ 23:59)',
                        style: TextStyle(fontSize: 11, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            if (overnight)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      size: 12,
                      color: AppColors.primaryBright,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '다음날 ${e.close}까지 영업해요',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// compact 시간 칸 (높이 44). 24시간 표기 / 밝은 테마 피커.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.value,
    required this.onPick,
    this.prefix,
    this.error = false,
  });

  final String value;
  final String? prefix;
  final bool error;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: error ? Border.all(color: AppColors.error) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                if (prefix != null)
                  const TextSpan(
                    text: '익일 ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBright,
                    ),
                  ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final parts = value.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              surface: AppColors.surfaceElevated,
              onSurface: AppColors.textHeading,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    if (picked == null) return;
    onPick(
      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
  }
}

/// `다른 요일에 복사` 바텀시트 (design §1.4).
class _CopyDaysSheet extends StatefulWidget {
  const _CopyDaysSheet();

  @override
  State<_CopyDaysSheet> createState() => _CopyDaysSheetState();
}

class _CopyDaysSheetState extends State<_CopyDaysSheet> {
  int _source = 1;
  final Set<int> _targets = {};

  void _quick(Iterable<int> days) => setState(() {
    _targets
      ..clear()
      ..addAll(days.where((d) => d != _source));
  });

  Widget _chip({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: !enabled
                ? AppColors.textMuted
                : selected
                ? AppColors.onPrimary
                : AppColors.textHeading,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '어떤 요일의 시간을 복사할까요?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  _chip(
                    label: dayLabelOf(d),
                    selected: _source == d,
                    enabled: true,
                    onTap: () => setState(() {
                      _source = d;
                      _targets.remove(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '대상 요일',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  _chip(
                    label: dayLabelOf(d),
                    selected: _targets.contains(d),
                    enabled: d != _source,
                    onTap: () => setState(() {
                      _targets.contains(d) ? _targets.remove(d) : _targets.add(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '평일',
                  selected: false,
                  enabled: true,
                  onTap: () => _quick([1, 2, 3, 4, 5]),
                ),
                _chip(
                  label: '주말',
                  selected: false,
                  enabled: true,
                  onTap: () => _quick([6, 7]),
                ),
                _chip(
                  label: '모든 요일',
                  selected: false,
                  enabled: true,
                  onTap: () => _quick([1, 2, 3, 4, 5, 6, 7]),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _targets.isEmpty
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop((source: _source, targets: Set<int>.from(_targets))),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.surfaceElevated,
                  disabledForegroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '적용',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
