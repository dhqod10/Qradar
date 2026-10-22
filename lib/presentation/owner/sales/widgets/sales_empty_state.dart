import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

enum SalesEmptyActionStyle { filled, outlined }

/// 빈 상태 / 에러 / 권한 에러 공용 블록.
class SalesEmptyState extends StatelessWidget {
  const SalesEmptyState({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionStyle = SalesEmptyActionStyle.outlined,
    this.compact = false,
    this.titleSize = 15,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final SalesEmptyActionStyle actionStyle;
  final bool compact;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final filled = actionStyle == SalesEmptyActionStyle.filled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 48 : 56, color: iconColor),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160),
              child: filled
                  ? FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(actionLabel!),
                    )
                  : OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(actionLabel!),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
