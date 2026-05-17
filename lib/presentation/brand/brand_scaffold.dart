import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_page.dart';
import 'package:qradar/presentation/brand/master_menu/master_menu_list_page.dart';
import 'package:qradar/presentation/brand/more/brand_more_page.dart';
import 'package:qradar/presentation/brand/stores/brand_stores_page.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

final _brandTabIndexProvider =
    NotifierProvider<_BrandTabNotifier, int>(_BrandTabNotifier.new);

class _BrandTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

/// brand role 사용자의 메인 Scaffold. 4탭 BottomNav.
///
/// 탭 구성:
///   0 - 브랜드 정보 (BrandInfoPage)
///   1 - 마스터 메뉴 (MasterMenuListPage)
///   2 - 매장 (BrandStoresPage)
///   3 - 더보기 (BrandMorePage)
///
/// brandId == null 케이스: [_BrandIdMissingView] 표시 (BottomNav 숨김).
class BrandScaffold extends ConsumerWidget {
  const BrandScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final brandId = profile?.brandId;

    // sub-phase 6 (V8): 신규 brand 가입 흐름.
    // brandId 미발급 (customer → brand 전환 직후) → 브랜드 등록 폼으로 자동 진입.
    // upsertBrand 가 brandId + users.brandId batch write → profile stream 갱신 → 정상 BottomNav 노출.
    if (brandId == null || brandId.isEmpty) {
      return const BrandInfoFormPage(brand: null);
    }

    final selected = ref.watch(_brandTabIndexProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: selected,
        children: const [
          BrandInfoPage(),
          MasterMenuListPage(),
          BrandStoresPage(),
          BrandMorePage(),
        ],
      ),
      bottomNavigationBar: _BrandBottomNav(
        selectedIndex: selected,
        onTap: (i) => ref.read(_brandTabIndexProvider.notifier).set(i),
      ),
    );
  }
}

class _BrandBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BrandBottomNav({
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
              _BrandNavItem(
                icon: Icons.storefront_rounded,
                label: '브랜드 정보',
                active: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _BrandNavItem(
                icon: Icons.menu_book_rounded,
                label: '마스터 메뉴',
                active: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _BrandNavItem(
                icon: Icons.location_city_rounded,
                label: '매장',
                active: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              _BrandNavItem(
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

class _BrandNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BrandNavItem({
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

// _BrandIdMissingView: sub-phase 6 (V8) 에서 폐기. brandId 없으면 BrandInfoFormPage 자동 진입.
