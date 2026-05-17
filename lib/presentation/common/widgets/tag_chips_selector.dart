import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 태그 다중 선택 chip ('recommended' / 'new' / 'best').
class TagChipsSelector extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const TagChipsSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _tags = [
    ('recommended', '추천'),
    ('new', '신메뉴'),
    ('best', '베스트'),
  ];

  void _toggle(String tag) {
    final next = List<String>.from(selected);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((t) {
        final (value, label) = t;
        final isSelected = selected.contains(value);
        return GestureDetector(
          onTap: () => _toggle(value),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.primary : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textBody,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}
