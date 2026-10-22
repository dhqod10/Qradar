import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/presentation/customer/review/widgets/grade_copy.dart';
import 'package:qradar/presentation/customer/review/widgets/grade_tile.dart';

/// S/A/B/C 4장 세로 선택 카드 (라디오). 기본 선택 없음.
///
/// 선택 전 4장 모두 중립색. 선택 후 테두리·체크는 등급 무관 `primary`,
/// 타일만 `StoreGrade.color`. 순서 S → A → B → C 고정.
class GradeSelector extends StatelessWidget {
  const GradeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final StoreGrade? selected;
  final ValueChanged<StoreGrade> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const grades = StoreGrade.values; // s, a, b, c
    return Semantics(
      container: true,
      label: '등급 선택',
      child: Column(
        children: [
          for (var i = 0; i < grades.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _GradeOptionCard(
              grade: grades[i],
              index: i,
              total: grades.length,
              isSelected: selected == grades[i],
              onTap: enabled
                  ? () {
                      if (selected == grades[i]) return;
                      HapticFeedback.selectionClick();
                      onChanged(grades[i]);
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _GradeOptionCard extends StatefulWidget {
  const _GradeOptionCard({
    required this.grade,
    required this.index,
    required this.total,
    required this.isSelected,
    required this.onTap,
  });

  final StoreGrade grade;
  final int index;
  final int total;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<_GradeOptionCard> createState() => _GradeOptionCardState();
}

class _GradeOptionCardState extends State<_GradeOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.grade;
    final selected = widget.isSelected;
    // 테두리 두께(1 <-> 2)가 바뀌어도 카드 크기가 움직이지 않도록 padding 으로 보정.
    final borderWidth = selected ? 2.0 : 1.0;
    final pad = 2.0 - borderWidth;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label:
          '${g.label}, ${g.reviewName}. ${g.reviewDescription}. '
          '${widget.total}개 중 ${widget.index + 1}번째',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 72),
          padding: EdgeInsets.fromLTRB(16 + pad, 14 + pad, 16 + pad, 14 + pad),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.surface : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: borderWidth,
            ),
          ),
          child: Row(
            children: [
              GradeTile(
                grade: g,
                size: 40,
                radius: 12,
                fontSize: 20,
                neutral: !selected,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.reviewName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g.reviewDescription,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
