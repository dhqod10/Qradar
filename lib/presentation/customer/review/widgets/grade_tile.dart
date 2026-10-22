import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// 등급 글자 타일 (S/A/B/C 한 글자). 선택 카드·리뷰 카드·액션 카드 공유.
///
/// [neutral] 이면 선택 전 중립 표현(`surface` + `textMuted`), 아니면 등급 색.
/// 등급 색 위 글자색 매핑은 이 위젯 내부 한 곳에만 둔다.
class GradeTile extends StatelessWidget {
  const GradeTile({
    super.key,
    required this.grade,
    required this.size,
    this.radius = 8,
    this.fontSize = 14,
    this.neutral = false,
  });

  final StoreGrade grade;
  final double size;
  final double radius;
  final double fontSize;
  final bool neutral;

  Color get _foreground => switch (grade) {
    StoreGrade.s || StoreGrade.a => AppColors.textHeading,
    StoreGrade.b || StoreGrade.c => AppColors.onPrimary,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: neutral ? AppColors.surface : grade.color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        grade.asString,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: neutral ? AppColors.textMuted : _foreground,
        ),
      ),
    );
  }
}
