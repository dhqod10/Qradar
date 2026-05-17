import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/presentation/customer/order/providers/order_providers.dart';

/// 등급 필터 칩 4개(S/A/B/C). 가로 균등 분배. 최소 1개 유지.
class GradeFilterChips extends ConsumerWidget {
  const GradeFilterChips({super.key});

  static const List<StoreGrade> _grades = [
    StoreGrade.s,
    StoreGrade.a,
    StoreGrade.b,
    StoreGrade.c,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(orderGradeFilterProvider);
    final notifier = ref.read(orderGradeFilterProvider.notifier);

    return Row(
      children: [
        for (var i = 0; i < _grades.length; i++) ...[
          Expanded(
            child: _GradeChip(
              grade: _grades[i],
              selected: selected.contains(_grades[i]),
              onTap: () => notifier.toggle(_grades[i]),
            ),
          ),
          if (i != _grades.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _GradeChip extends StatelessWidget {
  final StoreGrade grade;
  final bool selected;
  final VoidCallback onTap;

  const _GradeChip({
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(
          grade.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}
