import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 즐겨찾기 ♥ 토글 아이콘.
///
/// **시각만 담당**한다. 비로그인 가드 / Firestore 토글 호출은 호출부 책임.
///
/// - active = `Icons.favorite` + [AppColors.error]
/// - inactive = `Icons.favorite_border_rounded` + [inactiveColor]
class FavoriteToggleIconButton extends StatelessWidget {
  const FavoriteToggleIconButton({
    super.key,
    required this.isActive,
    required this.onTap,
    this.inactiveColor = AppColors.textHeading,
    this.iconSize = 24,
    this.padding,
    this.tooltip,
  });

  final bool isActive;
  final VoidCallback onTap;
  final Color inactiveColor;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: padding ?? const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      tooltip: tooltip,
      icon: Icon(
        isActive ? Icons.favorite : Icons.favorite_border_rounded,
        color: isActive ? AppColors.error : inactiveColor,
        size: iconSize,
      ),
    );
  }
}
