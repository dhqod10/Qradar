import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 품절 오버레이 — 메뉴 카드 · 메뉴 상세 이미지가 **같은 색 규칙**을 쓴다 (design §13-2).
/// 배경 덮개 `background` alpha 0.7 + 중앙 pill(`textHeading` alpha 0.85, 글자 `품절`).
/// [showLabel] 이 false 면 덮개만 (검색 행 썸네일처럼 56px 에서 글자가 읽기 어려운 곳).
class SoldOutOverlay extends StatelessWidget {
  const SoldOutOverlay({
    super.key,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.showLabel = true,
  });

  final double fontSize;
  final EdgeInsets padding;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.7),
        ),
        child: showLabel
            ? Center(
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: AppColors.textHeading.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '품절',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
