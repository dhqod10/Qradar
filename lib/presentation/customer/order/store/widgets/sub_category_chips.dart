import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';

class SubCategoryChips extends StatelessWidget {
  const SubCategoryChips({
    super.key,
    required this.subCategories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SubCategoryEntity> subCategories;
  final String? selectedId; // null = 전체
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (subCategories.length <= 1) {
      return const SizedBox.shrink();
    }
    final entries = <_ChipData>[
      const _ChipData(id: null, label: '전체'),
      for (final sc in subCategories) _ChipData(id: sc.id, label: sc.name),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = entries[i];
          final isSelected = e.id == selectedId;
          return _Chip(
            label: e.label,
            isSelected: isSelected,
            onTap: () => onSelect(e.id),
          );
        },
      ),
    );
  }
}

class _ChipData {
  final String? id;
  final String label;
  const _ChipData({required this.id, required this.label});
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: isSelected ? null : Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.onPrimary : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}
