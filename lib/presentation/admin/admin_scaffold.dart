import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/admin/approval/admin_approval_queue_page.dart';
import 'package:qradar/presentation/admin/more/admin_more_page.dart';

final _adminTabIndexProvider =
    NotifierProvider<_AdminTabNotifier, int>(_AdminTabNotifier.new);

class _AdminTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

/// admin role 사용자의 메인 Scaffold. 2탭 (승인 큐 / 더보기).
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_adminTabIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: selected,
        children: const [
          AdminApprovalQueuePage(),
          AdminMorePage(),
        ],
      ),
      bottomNavigationBar: _AdminBottomNav(
        selectedIndex: selected,
        onTap: (i) => ref.read(_adminTabIndexProvider.notifier).set(i),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomNav({
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
              _AdminNavItem(
                icon: Icons.pending_actions_rounded,
                label: '승인 큐',
                active: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _AdminNavItem(
                icon: Icons.more_horiz_rounded,
                label: '더보기',
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _AdminNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? AppColors.accent : AppColors.textMuted;
    final labelColor = active ? AppColors.textHeading : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: iconColor),
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
