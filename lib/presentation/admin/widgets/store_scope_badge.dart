import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 매장 scope(개인 매장 / 브랜드 매장) 를 시각화하는 인라인 배지.
///
/// factory 생성자:
///   - [StoreScopeBadge.personal]: 개인 매장 (AppColors.info 톤)
///   - [StoreScopeBadge.brand]: 브랜드 매장 (AppColors.primary 톤)
class StoreScopeBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  /// 글자색. null 이면 [color] (기본 배지). 경고 배지는 글자를 `textBody` 로 둔다 (색 단독 전달 금지: 라벨 + 아이콘).
  final Color? textColor;

  const StoreScopeBadge({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.textColor,
  });

  /// 편의 생성자 — 개인 매장.
  const StoreScopeBadge.personal({super.key})
      : label = '개인 매장',
        icon = Icons.storefront_outlined,
        color = AppColors.info,
        textColor = null;

  /// 브랜드 조회 중 — 이름을 미리 그리지 않는다 (아이콘 없음, muted).
  const StoreScopeBadge.brandChecking({super.key})
      : label = '브랜드 확인 중',
        icon = null,
        color = AppColors.textMuted,
        textColor = null;

  /// 브랜드가 승인되지 않았다 (대기/반려).
  const StoreScopeBadge.brandUnapproved({super.key})
      : label = '브랜드 미승인',
        icon = Icons.warning_amber_rounded,
        color = AppColors.warning,
        textColor = AppColors.textBody;

  /// 브랜드가 없거나 조회에 실패했다 — 이름으로 폴백하지 않는다.
  const StoreScopeBadge.brandNeedsCheck({super.key})
      : label = '브랜드 확인 필요',
        icon = Icons.warning_amber_rounded,
        color = AppColors.warning,
        textColor = AppColors.textBody;

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
        color: color.withValues(alpha: textColor == null ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor ?? color,
            ),
          ),
        ],
      ),
    );
  }
}
