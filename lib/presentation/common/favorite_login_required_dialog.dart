import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 비로그인 사용자가 즐겨찾기 토글을 시도했을 때 띄우는 로그인 유도 다이얼로그.
///
/// 사용자가 "로그인하기" 누르면 `true` 를 반환한다 (호출부에서 LoginPage push).
/// "취소" 또는 dialog dismiss 시 `false` 또는 `null`.
///
/// 다이얼로그 톤: Phase 1b 의 카트 충돌 다이얼로그 (`_confirmReplaceCart`) 재사용.
Future<bool> showFavoriteLoginRequiredDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      title: const Text(
        '로그인이 필요해요',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
      content: const Text(
        '즐겨찾기를 저장하려면 Qrator 로그인이 필요해요.',
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
            '로그인하기',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
