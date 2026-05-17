import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 매장 메뉴 화면의 메인 카테고리 탭.
///
/// 항상 `mainCategoriesActiveProvider` 의 active 카테고리만 그린다. 이전엔 stream
/// 미도달 시 매장 보유 카테고리 fallback 을 썼지만, fallback 이 inactive 카테고리를
/// 일시 노출하는 race 가 발견되어 제거. stream 도달 전엔 빈 영역(높이 유지) 노출.
///
/// [availableCategories] 에 없는 (= 매장이 메뉴 보유 안 한) 카테고리는 disabled
/// (dim + IgnorePointer) 로 표시.
class MainCategoryTabs extends ConsumerWidget {
  const MainCategoryTabs({
    super.key,
    required this.selected,
    required this.availableCategories,
    required this.onSelect,
  });

  /// 현재 선택된 카테고리 id. null = 미선택.
  final String? selected;

  /// 매장이 메뉴를 보유한 카테고리 id 집합.
  final Set<String> availableCategories;

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(mainCategoriesActiveProvider);
    final activeCats = activeAsync.asData?.value;

    // stream 미도달: 영역 자체 숨김 (잔상 방지). filteredMenuItemsProvider 도
    // 동일하게 미도달 시 빈 결과라 카테고리 탭 + 메뉴 동시 노출.
    if (activeCats == null) {
      return const SizedBox.shrink();
    }

    final tabs = activeCats
        .map((c) => _TabData(id: c.id, label: c.label))
        .toList(growable: false);

    if (tabs.isEmpty) {
      // active 카테고리 0개 → 탭 영역 자체 숨김
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final t = tabs[i];
          final isSelected = t.id == selected;
          final isDisabled = !availableCategories.contains(t.id);
          return _Tab(
            label: t.label,
            isSelected: isSelected,
            isDisabled: isDisabled,
            onTap: () => onSelect(t.id),
          );
        },
      ),
    );
  }
}

class _TabData {
  final String id;
  final String label;
  const _TabData({required this.id, required this.label});
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tabContent = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 80),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isDisabled
                      ? AppColors.textMuted.withValues(alpha: 0.4)
                      : (isSelected
                          ? AppColors.primary
                          : AppColors.textMuted),
                ),
              ),
            ),
            if (isSelected && !isDisabled)
              Container(
                height: 2.5,
                width: 32,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
    if (isDisabled) {
      return IgnorePointer(child: tabContent);
    }
    return InkWell(onTap: onTap, child: tabContent);
  }
}
