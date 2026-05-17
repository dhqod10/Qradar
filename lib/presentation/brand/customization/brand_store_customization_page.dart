import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/customization/price_override/brand_price_override_list_page.dart';
import 'package:qradar/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart';
import 'package:qradar/presentation/brand/customization/store_only_menu/brand_store_only_menu_list_page.dart';

/// 특정 매장의 커스텀 설정 진입점.
///
/// sub-segment 2탭:
///   index 0 — 가격 오버라이드 (BrandPriceOverrideListPage)
///   index 1 — 점포 한정 메뉴 (BrandStoreOnlyMenuListPage)
///
/// FAB: index == 1 일 때만 노출 → BrandStoreOnlyMenuFormPage(신규 등록)
class BrandStoreCustomizationPage extends StatefulWidget {
  final StoreEntity store;

  const BrandStoreCustomizationPage({super.key, required this.store});

  @override
  State<BrandStoreCustomizationPage> createState() =>
      _BrandStoreCustomizationPageState();
}

class _BrandStoreCustomizationPageState
    extends State<BrandStoreCustomizationPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.store.name,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _SubSegmentTabBar(
            selectedIndex: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          BrandPriceOverrideListPage(store: widget.store),
          BrandStoreOnlyMenuListPage(store: widget.store),
        ],
      ),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 3,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                '메뉴 추가',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrandStoreOnlyMenuFormPage(
                    brandId: widget.store.brandId ?? '',
                    storeId: widget.store.id,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── 인라인 sub-segment 탭 바 ───────────────────────────────────────────────

class _SubSegmentTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _labels = ['가격 오버라이드', '점포 한정 메뉴'];

  const _SubSegmentTabBar({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? AppColors.textHeading
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
