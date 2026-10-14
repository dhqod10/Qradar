import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/location_permission_status.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/category_filter_section.dart';
import 'package:qradar/presentation/customer/home/widgets/frequent_menu_items_section.dart';
import 'package:qradar/presentation/customer/home/widgets/frequent_stores_section.dart';
import 'package:qradar/presentation/customer/home/widgets/nearby_stores_section.dart';
import 'package:qradar/presentation/customer/home/widgets/pre_permission_dialog.dart';
import 'package:qradar/presentation/customer/home/widgets/quick_reorder_section.dart';
import 'package:qradar/presentation/customer/home/widgets/recommended_stores_section.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _fallbackSnackShown = false;
  bool _permissionFlowStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _permissionFlowStarted) return;
      _permissionFlowStarted = true;
      _resolveLocationPermission();
    });
  }

  /// 위치 권한 상태에 따라 (a) 바로 조회, (b) pre-permission 대화상자, (c) 폴백 중 하나를 수행.
  Future<void> _resolveLocationPermission() async {
    final notifier = ref.read(userLocationProvider.notifier);
    final status = await ref.read(checkLocationPermissionUseCaseProvider)();
    if (!mounted) return;

    switch (status) {
      case LocationPermissionStatus.granted:
        await notifier.allowAndFetch();
      case LocationPermissionStatus.deniedForever:
      case LocationPermissionStatus.serviceDisabled:
        notifier.declineAndFallback();
      case LocationPermissionStatus.notYetAsked:
        final agreed = await PrePermissionDialog.show(
          context,
          queue: ref.read(dialogQueueServiceProvider),
        );
        if (!mounted) return;
        if (agreed) {
          await notifier.allowAndFetch();
        } else {
          notifier.declineAndFallback();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그아웃 감지 → 로그인 페이지로
    ref.listen(authProvider, (prev, next) {
      next.whenOrNull(
        data: (user) {
          if (user == null) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          }
        },
      );
    });

    // 위치 폴백 안내 (한 번만)
    ref.listen(userLocationProvider, (prev, next) {
      next.whenOrNull(
        data: (loc) {
          if (loc.isFallback && !_fallbackSnackShown) {
            _fallbackSnackShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('위치 권한 없이 기본 위치로 표시 중입니다'),
                ),
              );
            });
          }
        },
      );
    });

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: const [
          SliverToBoxAdapter(child: SizedBox(height: 48)),
          SliverToBoxAdapter(child: QuickReorderSection()),
          SliverToBoxAdapter(child: FrequentStoresSection()),
          SliverToBoxAdapter(child: FrequentMenuItemsSection()),
          SliverToBoxAdapter(child: NearbyStoresSection()),
          SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: CategoryFilterSection()),
          SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(child: RecommendedStoresSection()),
          SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    final notifier = ref.read(userLocationProvider.notifier);
    final status = await ref.read(checkLocationPermissionUseCaseProvider)();
    if (!mounted) return;

    if (status == LocationPermissionStatus.granted) {
      await notifier.allowAndFetch();
    } else {
      // pull-to-refresh 중 대화상자 재노출은 방해되므로 폴백 유지.
      notifier.declineAndFallback();
    }
    ref.invalidate(nearbyStoresProvider);
    ref.invalidate(filteredStoresProvider);
    await ref.read(userLocationProvider.future);
  }
}
