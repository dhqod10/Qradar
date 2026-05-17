import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';

/// 메뉴 폼 sub-category 선택 칩 영역 (공통).
///
/// - props 주입 방식 (provider 직접 watch X)
/// - 메인 카테고리가 null/변경이면 선택 해제 (호출자가 관리)
/// - 빈 상태(sub 0개): 안내 없이 SizedBox.shrink
/// - 선택은 선택 사항 (없어도 메뉴 등록 가능)
/// - inactive sub 가 prefill 되어 있으면 [InactiveSubCategoryWarningLabel] 표시
class SubCategoryChipsSelector extends StatelessWidget {
  final List<SubCategoryEntity> subCategories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const SubCategoryChipsSelector({
    super.key,
    required this.subCategories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (subCategories.isEmpty) return const SizedBox.shrink();

    // inactive prefill 경고
    final isSelectedInactive = selectedId != null &&
        subCategories.any((s) => s.id == selectedId && !s.active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSelectedInactive) ...[
          const InactiveSubCategoryWarningLabel(),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // "없음" 칩
            _Chip(
              label: '없음',
              isSelected: selectedId == null,
              isActive: true,
              onTap: () => onSelect(null),
            ),
            for (final sub in subCategories)
              _Chip(
                label: sub.name,
                isSelected: selectedId == sub.id,
                isActive: sub.active,
                onTap: () =>
                    onSelect(selectedId == sub.id ? null : sub.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? AppColors.primary : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(
                  color: isActive ? AppColors.border : AppColors.textMuted,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.onPrimary
                : (isActive ? AppColors.textBody : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// inactive sub-category 가 prefill 되어 있을 때 표시하는 경고 레이블.
class InactiveSubCategoryWarningLabel extends StatelessWidget {
  const InactiveSubCategoryWarningLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: AppColors.warning),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              '이 분류는 비활성화되었습니다. 다른 분류로 변경해주세요.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
