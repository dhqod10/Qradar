import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';

/// pending / approved / rejected 상태를 색상 + 라벨로 시각화하는 인라인 배지.
///
/// [isRevision]: `approvedAt != null && status == pending` 이면 true.
/// 이 경우 라벨을 '수정 대기' 로 표시 (S3 정책).
/// [large]: admin 승인 상세 페이지 상단 강조용 큰 배지.
class ApprovalStatusBadge extends StatelessWidget {
  final EntityApprovalStatus status;
  final bool isRevision;
  final bool large;

  const ApprovalStatusBadge({
    super.key,
    required this.status,
    this.isRevision = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _badgeConfig(status, isRevision);
    final height = large ? 32.0 : 24.0;
    final hPad = large ? 14.0 : 10.0;
    final vPad = large ? 6.0 : 4.0;
    final dotSize = large ? 10.0 : 8.0;
    final fontSize = large ? 13.0 : 12.0;
    final fontWeight = large ? FontWeight.w700 : FontWeight.w600;

    return Container(
      height: height,
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: config.dot,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: config.labelColor,
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeConfig _badgeConfig(
      EntityApprovalStatus status, bool isRevision) {
    switch (status) {
      case EntityApprovalStatus.pending:
        return _BadgeConfig(
          bg: AppColors.warning.withValues(alpha: 0.15),
          dot: AppColors.warning,
          labelColor: AppColors.warning,
          label: isRevision ? '수정 대기' : '검토 중',
        );
      case EntityApprovalStatus.approved:
        return _BadgeConfig(
          bg: AppColors.success.withValues(alpha: 0.15),
          dot: AppColors.success,
          labelColor: AppColors.success,
          label: '승인됨',
        );
      case EntityApprovalStatus.rejected:
        return _BadgeConfig(
          bg: AppColors.error.withValues(alpha: 0.15),
          dot: AppColors.error,
          labelColor: AppColors.error,
          label: '반려됨',
        );
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color dot;
  final Color labelColor;
  final String label;

  const _BadgeConfig({
    required this.bg,
    required this.dot,
    required this.labelColor,
    required this.label,
  });
}
