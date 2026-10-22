import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 필터 칩 (매장 목록 / 이력 공용): 높이 36(터치 영역 44), radius 999 알약 — 배지(radius 6)와 구분된다.
class QoinFilterChip extends StatelessWidget {
  const QoinFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = false,
    this.trailing,
  });
  final String label;
  final bool selected;
  final bool outlined;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: outlined
                ? Border.all(color: AppColors.primary)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.onPrimary : AppColors.textBody,
                ),
              ),
              if (trailing != null)
                Icon(trailing, size: 18, color: AppColors.textBody),
            ],
          ),
        ),
      ),
    );
  }
}

