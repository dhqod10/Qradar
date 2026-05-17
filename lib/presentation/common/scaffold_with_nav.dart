import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/bottom_nav/bottom_nav.dart';
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
