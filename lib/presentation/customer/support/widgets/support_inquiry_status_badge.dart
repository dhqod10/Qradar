import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/support_inquiry_status.dart';

/// 문의 상태 배지 4종 (`ApprovalStatusBadge` 와 같은 pill 구조). 색만이 아니라 라벨이 항상 함께 있다.
class SupportInquiryStatusBadge extends StatelessWidget {
  const SupportInquiryStatusBadge({
    super.key,
    required this.status,
    this.large = false,
  });

  final SupportInquiryStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = _config(status);
    return Container(
      height: large ? 32 : 24,
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
        border: c.border ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 10 : 8,
            height: large ? 10 : 8,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: large ? 13 : 12,
              fontWeight: large ? FontWeight.w700 : FontWeight.w600,
              color: c.color,
            ),
          ),
        ],
      ),
    );
  }

  static ({Color color, Color bg, bool border}) _config(
    SupportInquiryStatus s,
  ) {
    switch (s) {
      case SupportInquiryStatus.open:
        return (
          color: AppColors.info,
          bg: AppColors.info.withValues(alpha: 0.15),
          border: false,
        );
      case SupportInquiryStatus.answered:
        return (
          color: AppColors.success,
          bg: AppColors.success.withValues(alpha: 0.15),
          border: false,
        );
      case SupportInquiryStatus.closed:
        return (
          color: AppColors.textMuted,
          bg: AppColors.surface,
          border: false,
        );
      case SupportInquiryStatus.withdrawn:
        return (
          color: AppColors.textMuted,
          bg: Colors.transparent,
          border: true,
        );
    }
  }
}
