import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/demographics.dart';

/// 성별·출생연도 입력 위젯 (선택 수집).
///
/// 가입 화면 / 내 정보 **두 곳이 같은 위젯을 쓴다** — 선택지와 문구가 갈라지면 개인정보처리방침에
/// 적은 수집 항목과 화면이 어긋난다.
///
/// 출생연도는 **고르는 값**이다. 휠에 만 [kMinSignupAge]세 ~ [kMaxPlausibleAge]세에 해당하는
/// 연도만 올리므로, 이용약관의 가입 연령 제한이 입력 단계에서 그냥 지켜진다 — 잘못 칠 방법이 없어
/// 오류 문구도 필요 없다.
class DemographicsPicker extends StatelessWidget {
  const DemographicsPicker({
    super.key,
    required this.gender,
    required this.birthYear,
    required this.onGenderChanged,
    required this.onBirthYearChanged,
  });

  final Gender? gender;
  final int? birthYear;
  final ValueChanged<Gender?> onGenderChanged;
  final ValueChanged<int?> onBirthYearChanged;

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year;
    final range = ageRangeFromBirthYear(birthYear, nowYear: nowYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('성별'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final g in Gender.values) ...[
              Expanded(
                child: _Chip(
                  label: g.label,
                  selected: gender == g,
                  // 같은 값을 다시 누르면 선택 해제 — 잘못 누른 걸 되돌릴 수 있어야 한다.
                  onTap: () => onGenderChanged(gender == g ? null : g),
                ),
              ),
              if (g != Gender.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const _Label('출생연도'),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openWheel(context, nowYear),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    birthYear == null ? '선택 안 함' : '$birthYear년',
                    style: TextStyle(
                      fontSize: 16,
                      color: birthYear == null
                          ? AppColors.textMuted
                          : AppColors.textHeading,
                    ),
                  ),
                ),
                // 고른 값이 어떻게 쓰이는지 바로 옆에서 보여 준다.
                if (range != null)
                  Text(
                    range.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openWheel(BuildContext context, int nowYear) async {
    // 최근 연도가 위로 오도록 내림차순. 범위 자체가 만 14세 ~ 120세다.
    final years = [
      for (var y = nowYear - kMinSignupAge; y >= nowYear - kMaxPlausibleAge; y--)
        y,
    ];
    // 고른 적이 없으면 30세 언저리에서 시작한다 — 양끝에서 시작하면 한참 굴려야 한다.
    final initial = birthYear != null && years.contains(birthYear)
        ? years.indexOf(birthYear!)
        : years.indexOf(nowYear - 30).clamp(0, years.length - 1);

    final picked = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _YearWheel(years: years, initialIndex: initial),
    );
    if (picked == null) return; // 취소 — 기존 값을 그대로 둔다.
    onBirthYearChanged(picked == _kClearYear ? null : picked);
  }
}

/// "선택 안 함" 을 고른 경우를 취소(null) 와 구분하기 위한 표식.
const int _kClearYear = -1;

class _YearWheel extends StatefulWidget {
  const _YearWheel({required this.years, required this.initialIndex});

  final List<int> years;
  final int initialIndex;

  @override
  State<_YearWheel> createState() => _YearWheelState();
}

class _YearWheelState extends State<_YearWheel> {
  late final FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year;
    final year = widget.years[_index];
    final range = ageRangeFromBirthYear(year, nowYear: nowYear);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    range == null ? '출생연도' : '${range.label}로 집계돼요',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(year),
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: _controller,
                itemExtent: 40,
                squeeze: 1.1,
                onSelectedItemChanged: (i) => setState(() => _index = i),
                children: [
                  for (final y in widget.years)
                    Center(
                      child: Text(
                        '$y년',
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.textHeading,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 밝히지 않기로 되돌릴 길을 남긴다 — 한 번 고르면 못 지우는 화면이 되면 안 된다.
            TextButton(
              onPressed: () => Navigator.of(context).pop(_kClearYear),
              child: const Text(
                '선택 안 함',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '선택',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha((0.06 * 255).round())
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textHeading,
          ),
        ),
      ),
    );
  }
}
