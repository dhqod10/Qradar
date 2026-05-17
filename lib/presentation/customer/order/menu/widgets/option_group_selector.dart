import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';

/// 옵션 그룹 1건 표시 + 선택 콜백.
///
/// 단일/필수 → 라디오 (첫 항목 자동 선택, "선택 안함" 없음)
/// 단일/선택 → 라디오 + "선택 안함"
/// 다중/선택 → 체크박스
class OptionGroupSelector extends StatelessWidget {
  const OptionGroupSelector({
    super.key,
    required this.group,
    required this.selectedItemIds,
    required this.onSelectSingle,
    required this.onClearSingle,
    required this.onToggleMulti,
  });

  final OptionGroupEntity group;
  final Set<String> selectedItemIds;
  final ValueChanged<String> onSelectSingle;
  final VoidCallback onClearSingle;
  final ValueChanged<String> onToggleMulti;

  bool get _isSingle => group.selectionType == OptionSelectionType.single;
  bool get _showNoneOption => _isSingle && !group.required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(name: group.name, required: group.required),
          const SizedBox(height: 12),
          if (_showNoneOption)
            _OptionRow(
              label: '선택 안함',
              priceDelta: 0,
              isSelected: selectedItemIds.isEmpty,
              isMulti: false,
              onTap: onClearSingle,
            ),
          for (final item in group.items)
            _OptionRow(
              label: item.label,
              priceDelta: item.priceDelta,
              isSelected: selectedItemIds.contains(item.id),
              isMulti: !_isSingle,
              onTap: _isSingle
                  ? () => onSelectSingle(item.id)
                  : () => onToggleMulti(item.id),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.required});
  final String name;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '필수',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.priceDelta,
    required this.isSelected,
    required this.isMulti,
    required this.onTap,
  });

  final String label;
  final int priceDelta;
  final bool isSelected;
  final bool isMulti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isSelected ? AppColors.textHeading : AppColors.textBody;
    final labelWeight = isSelected ? FontWeight.w700 : FontWeight.w500;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _Indicator(isSelected: isSelected, isMulti: isMulti),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: labelWeight,
                  color: labelColor,
                ),
              ),
            ),
            if (priceDelta != 0)
              Text(
                PriceFormatter.formatDelta(priceDelta),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: priceDelta < 0
                      ? AppColors.success
                      : AppColors.textBody,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.isSelected, required this.isMulti});
  final bool isSelected;
  final bool isMulti;

  @override
  Widget build(BuildContext context) {
    if (isMulti) {
      return Icon(
        isSelected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded,
        size: 22,
        color: isSelected ? AppColors.primary : AppColors.border,
      );
    }
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.onPrimary,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

