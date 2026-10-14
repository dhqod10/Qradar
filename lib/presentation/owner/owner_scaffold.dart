import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/presentation/common/notification/notification_permission_dialog.dart';
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
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
/// - 첫 진입 시 알림 권한 다이얼로그를 노출한다 (결정 A).
class OwnerScaffold extends ConsumerStatefulWidget {
  const OwnerScaffold({super.key});

  @override
  ConsumerState<OwnerScaffold> createState() => _OwnerScaffoldState();
}

class _OwnerScaffoldState extends ConsumerState<OwnerScaffold> {
  @override
  void initState() {
    super.initState();
    // 빌드 사이클 방해 없이 첫 프레임 이후에 권한 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    final authState = ref.read(authProvider);
    final uid = authState.asData?.value?.uid;
    if (uid == null) return;

    // notificationPermissionPrompted 플래그 조회
    final prompted = await ref
        .read(userRepositoryProvider)
        .getNotificationPermissionPrompted(uid);
    if (prompted) return; // 이미 노출됨 → 재노출 안 함

    if (!mounted) return;

    // 다이얼로그 노출
    final result = await showNotificationPermissionDialog(
      context,
      audience: NotificationDialogAudience.owner,
      queue: ref.read(dialogQueueServiceProvider),
    );

    if (!mounted) return;

    // 결과 처리
    if (result == 'allow') {
      // OS 권한 요청
      final status = await ref
          .read(requestNotificationPermissionUseCaseProvider)
          .call();

      // 권한 허용 시 토큰 등록
      if (status == NotificationPermissionStatus.authorized ||
          status == NotificationPermissionStatus.provisional) {
        await ref.read(registerFcmTokenUseCaseProvider).call(uid);
      }
    }

    // 결과와 무관하게 플래그 set (재노출 방지)
    await ref
        .read(userRepositoryProvider)
        .markNotificationPermissionPrompted(uid);
  }

  @override
  Widget build(BuildContext context) {
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
