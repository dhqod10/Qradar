import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// Qoin 화면 공용 로드 실패 뷰 (1차 `_LoadError` 를 일반화). 허브·목록·편집·이력 여러 곳이 쓴다.
class QoinLoadError extends StatelessWidget {
  const QoinLoadError({
    super.key,
    this.title = '설정을 불러오지 못했어요',
    this.message = '잠시 후 다시 시도해주세요',
    required this.onRetry,
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  /// true 면 카드 안에 들어가는 인라인형(아이콘 40).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 20 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: compact ? 40 : 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(160, 44),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return compact ? content : Center(child: content);
  }
}
