import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/bottom_nav/order_fab.dart';
import 'package:qradar/presentation/common/q_logo.dart';

/// 하단 글로벌 네비게이션. Qoin / 주문(FAB) / Log 3개 슬롯.
///
/// 탭 인덱스 규약: 0=홈, 1=Qoin, 2=주문(FAB), 3=Log, 4=더보기
/// 홈과 더보기는 홈 헤더에서 토글되므로 하단바에 노출하지 않는다.
class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onOrderTap;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                customIcon: QLogo(
                  size: 22,
                  animate: false,
                  color: selectedIndex == 1
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                label: 'Qoin',
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              OrderFab(onTap: onOrderTap),
              _NavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Log',
                active: selectedIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    this.icon,
    this.customIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    final labelColor = active ? AppColors.textHeading : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null)
              SizedBox(
                height: 24,
                child: Center(child: customIcon),
              )
            else
              Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
