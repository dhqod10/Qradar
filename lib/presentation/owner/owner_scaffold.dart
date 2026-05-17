import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/owner/more/owner_more_page.dart';
import 'package:qradar/presentation/owner/my_store/my_store_page.dart';
import 'package:qradar/presentation/owner/orders/owner_orders_page.dart';
import 'package:qradar/presentation/owner/placeholders/owner_sales_placeholder.dart';

final ownerTabIndexProvider =
    NotifierProvider<_OwnerTabNotifier, int>(_OwnerTabNotifier.new);

class _OwnerTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

/// 점주(owner) 역할 사용자의 메인 Scaffold.
///
/// 탭 구성: 내 매장 / 주문 접수 / 매출 / 더보기
/// MVP 범위: "내 매장" 탭만 실구현, 나머지 두 탭은 placeholder.
class OwnerScaffold extends ConsumerWidget {
  const OwnerScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(ownerTabIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: selected,
        children: const [
          MyStorePage(),
          OwnerOrdersPage(),
          OwnerSalesPlaceholder(),
          OwnerMorePage(),
        ],
      ),
      bottomNavigationBar: _OwnerBottomNav(
        selectedIndex: selected,
        onTap: (i) => ref.read(ownerTabIndexProvider.notifier).set(i),
      ),
    );
  }
}

class _OwnerBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _OwnerBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceElevated, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _OwnerNavItem(
                icon: Icons.storefront_rounded,
                label: '내 매장',
                active: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _OwnerNavItem(
                icon: Icons.receipt_long_rounded,
                label: '주문 접수',
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _OwnerNavItem(
                icon: Icons.bar_chart_rounded,
                label: '매출',
                active: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _OwnerNavItem(
                icon: Icons.more_horiz_rounded,
                label: '더보기',
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

class _OwnerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OwnerNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textMuted;
    final labelColor = active ? AppColors.textDark : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
