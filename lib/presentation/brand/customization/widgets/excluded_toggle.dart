import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 이 매장에서 마스터 메뉴를 제외할지 여부 토글.
///
/// [value] == true 일 때 경고 컨테이너 노출.
class ExcludedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ExcludedToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '이 매장에서 메뉴 제외',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '활성화하면 이 매장 메뉴에서 해당 메뉴가 표시되지 않아요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.error,
                activeTrackColor: AppColors.error.withValues(alpha: 0.20),
                inactiveTrackColor: AppColors.surface,
              ),
            ],
          ),
        ),
        if (value) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.30),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '제외 처리도 관리자 검토 후 반영됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
