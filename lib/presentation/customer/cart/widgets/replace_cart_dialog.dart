import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 다른 매장 카트가 활성화된 상태에서 새 매장으로 전환할지 확인하는 다이얼로그.
///
/// Phase 1b 의 `_confirmReplaceCart` 와 Phase 2 "다시 주문" 카드의 매장 충돌
/// 처리에서 공통으로 사용한다.
///
/// 반환값: `true` = "비우고 시작" 선택, 그 외(취소 / 외부 탭) = `false`.
Future<bool> showReplaceCartDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      title: const Text(
        '기존 카트를 비울까요?',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
      content: const Text(
        '다른 매장의 카트가 있어요.\n비우고 새 매장으로 시작할까요?',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textBody,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            '취소',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            '비우고 시작',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
