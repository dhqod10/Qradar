import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/presentation/common/bottom_nav/bottom_nav.dart';
import 'package:qradar/presentation/common/notification/notification_permission_dialog.dart';
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/home/home_page.dart';
import 'package:qradar/presentation/customer/home/widgets/home_header.dart';
import 'package:qradar/presentation/customer/log/orders_page.dart';
import 'package:qradar/presentation/customer/more/more_page.dart';
import 'package:qradar/presentation/customer/order/order_page.dart';
import 'package:qradar/presentation/customer/qoin/qoin_page.dart';

/// 탭 인덱스 규약: 0=홈, 1=Qoin, 2=주문(FAB 별도), 3=Log, 4=더보기
/// FAB는 모달로 동작하므로 selectedTabIndex에 2가 영구 저장되지 않음.
final selectedTabIndexProvider =
    NotifierProvider<_SelectedTabIndexNotifier, int>(
  _SelectedTabIndexNotifier.new,
);

class _SelectedTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

/// 로그인 이후 메인 탭 전환의 공통 껍데기.
class ScaffoldWithNav extends ConsumerStatefulWidget {
  const ScaffoldWithNav({super.key});

  @override
  ConsumerState<ScaffoldWithNav> createState() => _ScaffoldWithNavState();
}

class _ScaffoldWithNavState extends ConsumerState<ScaffoldWithNav> {
  static const double _collapseThreshold = 24;
  bool _homeScrolled = false;

  @override
  void initState() {
    super.initState();
    // 빌드 사이클 방해 없이 첫 프레임 이후에 권한 체크 (OwnerScaffold 동일 패턴)
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
      audience: NotificationDialogAudience.customer,
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

  bool _onScroll(ScrollNotification n) {
    final scrolled = n.metrics.pixels > _collapseThreshold;
    if (scrolled != _homeScrolled) {
      setState(() => _homeScrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTabIndexProvider);
    final indexForStack = _stackIndex(selected);
    final HomeHeaderMode headerMode;
    if (selected != 0) {
      headerMode = HomeHeaderMode.tabbed;
    } else if (_homeScrolled) {
      headerMode = HomeHeaderMode.scrolled;
    } else {
      headerMode = HomeHeaderMode.full;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Column(
        children: [
          HomeHeader(mode: headerMode),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: IndexedStack(
                index: indexForStack,
                children: const [
                  HomePage(),
                  QoinPage(),
                  OrdersPage(),
                  MorePage(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: selected,
        onTap: (i) => ref.read(selectedTabIndexProvider.notifier).set(i),
        onOrderTap: () => _openOrder(context),
      ),
    );
  }

  int _stackIndex(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Qoin
      case 3:
        return 2; // Log
      case 4:
        return 3; // More
      default:
        return 0;
    }
  }

  void _openOrder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderPage(), fullscreenDialog: true),
    );
  }
}
