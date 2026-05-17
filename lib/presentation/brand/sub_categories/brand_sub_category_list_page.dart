import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/presentation/brand/sub_categories/brand_sub_category_form_page.dart';
import 'package:qradar/presentation/brand/sub_categories/providers/brand_sub_category_providers.dart';
import 'package:qradar/presentation/common/widgets/sub_category_delete_dialog.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 브랜드 서브 카테고리 목록 페이지.
///
/// - 메인 카테고리 필터 칩 (전체 / 각 메인)
/// - "전체" 선택 시 메인별 섹션 헤더 그룹핑
/// - 특정 메인 선택 시 평면 리스트
/// - displayOrder 정렬, active Switch (즉시 토글), 편집/삭제 버튼, FAB
class BrandSubCategoryListPage extends ConsumerStatefulWidget {
  const BrandSubCategoryListPage({super.key});

  @override
  ConsumerState<BrandSubCategoryListPage> createState() =>
      _BrandSubCategoryListPageState();
}

class _BrandSubCategoryListPageState
    extends ConsumerState<BrandSubCategoryListPage> {
  /// null = 전체
  String? _filterMainCategoryId;

  @override
  Widget build(BuildContext context) {
    final subCategoriesAsync = ref.watch(brandSubCategoriesAllProvider);
    final mainCategoriesAsync = ref.watch(mainCategoriesActiveProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBody),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('서브 카테고리 관리'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const BrandSubCategoryFormPage(),
          ),
        ),
        child: const Icon(Icons.add_rounded,
            color: AppColors.onPrimary, size: 24),
      ),
      body: Column(
        children: [
          // 메인 카테고리 필터 칩
          mainCategoriesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox.shrink(),
            data: (categories) => _FilterChips(
              categories: categories,
              selected: _filterMainCategoryId,
              onSelect: (id) =>
                  setState(() => _filterMainCategoryId = id),
            ),
          ),
          // 리스트 본문
          Expanded(
            child: subCategoriesAsync.when(
              loading: () => const _LoadingBody(),
              error: (_, _) => _ErrorBody(
                onRetry: () =>
                    ref.invalidate(brandSubCategoriesAllProvider),
              ),
              data: (subs) {
                final filtered = _filterMainCategoryId == null
                    ? subs
                    : subs
                        .where((s) =>
                            s.mainCategoryCode == _filterMainCategoryId)
                        .toList();

                if (filtered.isEmpty) {
                  return const _EmptyBody();
                }

                if (_filterMainCategoryId != null) {
                  // 평면 리스트
                  return _FlatList(items: filtered);
                }

                // 전체: 메인별 섹션 그룹핑
                return mainCategoriesAsync.when(
                  loading: () => const _LoadingBody(),
                  error: (_, _) => _FlatList(items: filtered),
                  data: (categories) => _GroupedList(
                    items: filtered,
                    categories: categories,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 필터 칩 ───────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final List<MainCategoryEntity> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _FilterChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _Chip(
            label: '전체',
            isSelected: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          for (final cat in categories) ...[
            _Chip(
              label: cat.label,
              isSelected: selected == cat.id,
              onTap: () => onSelect(cat.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.onPrimary
                : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

// ── 평면 리스트 ───────────────────────────────────────────────────────────

class _FlatList extends StatelessWidget {
  final List<SubCategoryEntity> items;

  const _FlatList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _SubCategoryCard(entity: items[i]),
      ),
    );
  }
}

// ── 그룹 리스트 ───────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  final List<SubCategoryEntity> items;
  final List<MainCategoryEntity> categories;

  const _GroupedList({required this.items, required this.categories});

  @override
  Widget build(BuildContext context) {
    // 메인별 그룹
    final grouped = <MainCategoryEntity, List<SubCategoryEntity>>{};
    for (final cat in categories) {
      final group =
          items.where((s) => s.mainCategoryCode == cat.id).toList();
      if (group.isNotEmpty) grouped[cat] = group;
    }
    // mainCategories 에 없는 code 처리
    final unmapped = items
        .where((s) =>
            !categories.any((c) => c.id == s.mainCategoryCode))
        .toList();

    final sections = <Widget>[];
    for (final entry in grouped.entries) {
      sections.add(_SectionHeader(label: entry.key.label));
      for (final sub in entry.value) {
        sections.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SubCategoryCard(entity: sub),
        ));
      }
    }
    if (unmapped.isNotEmpty) {
      sections.add(const _SectionHeader(label: '기타'));
      for (final sub in unmapped) {
        sections.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SubCategoryCard(entity: sub),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: sections,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── 카드 ──────────────────────────────────────────────────────────────────

class _SubCategoryCard extends ConsumerStatefulWidget {
  final SubCategoryEntity entity;

  const _SubCategoryCard({required this.entity});

  @override
  ConsumerState<_SubCategoryCard> createState() =>
      _SubCategoryCardState();
}

class _SubCategoryCardState extends ConsumerState<_SubCategoryCard> {
  bool? _pendingActive;

  Future<void> _onSwitchChanged(bool newValue) async {
    setState(() => _pendingActive = newValue);
    try {
      await ref.read(toggleSubCategoryActiveUseCaseProvider).call(
            id: widget.entity.id,
            scope: widget.entity.scope!,
            active: newValue,
            brandId: widget.entity.brandId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue ? '분류를 활성화했어요' : '분류를 비활성화했어요'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingActive = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _pendingActive = null);
    }
  }

  void _pushEditPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BrandSubCategoryFormPage(editItem: widget.entity),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => SubCategoryDeleteDialog(entity: widget.entity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    final isActive = _pendingActive ?? entity.active;

    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: _pushEditPage,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ListTile(
            leading: _OrderBadge(displayOrder: entity.displayOrder),
            title: Text(
              entity.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.textHeading
                    : AppColors.textMuted,
              ),
            ),
            subtitle: _UsageChip(subCategoryId: entity.id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: isActive,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor:
                      AppColors.primaryBright.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surface,
                  onChanged: _onSwitchChanged,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.textMuted),
                  onSelected: (v) {
                    if (v == 'edit') _pushEditPage();
                    if (v == 'delete') _showDeleteDialog();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('편집')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 서브 위젯 ──────────────────────────────────────────────────────────────

class _OrderBadge extends StatelessWidget {
  final int displayOrder;

  const _OrderBadge({required this.displayOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$displayOrder',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _UsageChip extends ConsumerWidget {
  final String subCategoryId;

  const _UsageChip({required this.subCategoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync =
        ref.watch(subCategoryUsageProvider(subCategoryId));

    return usageAsync.when(
      loading: () => Container(
        width: 60,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      error: (_, _) => const Text('-',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      data: (count) => Text(
        count == 0 ? '사용 없음' : '사용 중 $count개',
        style:
            const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

// ── 상태 UI ───────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: 4,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const ListTile(
        leading: _ShimmerBox(width: 36, height: 36, radius: 8),
        title: _ShimmerBox(width: 120, height: 14, radius: 4),
        subtitle: _ShimmerBox(width: 72, height: 10, radius: 4),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            '분류 목록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '잠시 후 다시 시도해주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline_rounded,
              size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            '등록된 분류가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '아래 버튼으로 첫 분류를 추가해보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
