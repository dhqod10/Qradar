import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 카드 인라인 품절 토글 (sub-phase 5 — D2).
///
/// [_InlineVisibleToggle] 과 동일한 Switch.adaptive 패턴.
/// activeColor: AppColors.error 톤으로 위험성 강조.
/// OwnerStoreMenuListPage / OwnerBrandStoreMenusPage 양쪽에서 재사용.
class SoldOutToggle extends StatelessWidget {
  final bool soldOut;
  final bool isLoading;
  final void Function(bool) onChanged;

  const SoldOutToggle({
    super.key,
    required this.soldOut,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '품절',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 44,
          child: Switch.adaptive(
            value: soldOut,
            onChanged: isLoading ? null : onChanged,
            activeThumbColor: AppColors.error,
            activeTrackColor: AppColors.error.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surface,
          ),
        ),
      ],
    );
  }
}
