import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// admin 승인 상세 페이지 하단 고정 액션 바 (반려 / 승인).
class ApprovalActionsBar extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isLoading;

  /// false 면 `승인` 만 꺼진다 (반려는 항상 켜져 있다 — 가짜 `brandId` 를 발견한 admin 이 그 자리에서 반려할 수 있어야 한다).
  final bool approveEnabled;

  /// [approveEnabled] 가 false 일 때 바 위에 보이는 사유 한 줄.
  final String? approveDisabledReason;

  const ApprovalActionsBar({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.isLoading = false,
    this.approveEnabled = true,
    this.approveDisabledReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!approveEnabled && approveDisabledReason != null) ...[
                Text(
                  approveDisabledReason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(child: _rejectButton()),
                  const SizedBox(width: 12),
                  Expanded(child: _approveButton()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rejectButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onReject,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '반려',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _approveButton() {
    return Semantics(
      enabled: approveEnabled && !isLoading,
      hint: approveEnabled ? null : approveDisabledReason,
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: (isLoading || !approveEnabled) ? null : onApprove,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            // 비활성: textMuted 배경 + onPrimary 글자 (저장 중 인디케이터와 구분).
            disabledBackgroundColor: approveEnabled
                ? null
                : AppColors.textMuted,
            disabledForegroundColor: approveEnabled
                ? null
                : AppColors.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text(
                  '승인',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
