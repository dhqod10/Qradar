import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 메뉴 폼 3종 공통 — inactive 카테고리 선택 시 표시하는 경고 배너.
///
/// 수정 모드에서 메뉴의 mainCategoryCode 가 active=false 인 카테고리에
/// 속해 있을 때 카테고리 칩 영역 바로 위에 배치한다.
class InactiveCategoryWarningBanner extends StatelessWidget {
  const InactiveCategoryWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
