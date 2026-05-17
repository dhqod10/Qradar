import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 매장 scope(개인 매장 / 브랜드 매장) 를 시각화하는 인라인 배지.
///
/// factory 생성자:
///   - [StoreScopeBadge.personal]: 개인 매장 (AppColors.info 톤)
///   - [StoreScopeBadge.brand]: 브랜드 매장 (AppColors.primary 톤)
class StoreScopeBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const StoreScopeBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  /// 편의 생성자 — 개인 매장.
  const StoreScopeBadge.personal({super.key})
      : label = '개인 매장',
        icon = Icons.storefront_outlined,
        color = AppColors.info;

  /// 편의 생성자 — 브랜드 매장.
  factory StoreScopeBadge.brand(String brandName) => StoreScopeBadge(
        label: '브랜드: $brandName',
        icon: Icons.business_rounded,
        color: AppColors.primary,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
