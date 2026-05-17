import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/presentation/admin/menu_categories/admin_main_category_form_page.dart';
import 'package:qradar/presentation/admin/menu_categories/widgets/main_category_deactivate_confirm_dialog.dart';
import 'package:qradar/presentation/admin/menu_categories/widgets/main_category_delete_dialog.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 메인 카테고리 목록 페이지 (admin 전용).
///
/// - displayOrder asc 정렬 (stream 에서 이미 정렬됨).
/// - initState 에서 seedDefaultsIfEmpty 1회 호출 (idempotent).
/// - 각 아이템: label / id / displayOrder / active Switch / 편집 / 삭제.
class AdminMainCategoryListPage extends ConsumerStatefulWidget {
  const AdminMainCategoryListPage({super.key});

  @override
  ConsumerState<AdminMainCategoryListPage> createState() =>
      _AdminMainCategoryListPageState();
}

class _AdminMainCategoryListPageState
    extends ConsumerState<AdminMainCategoryListPage> {
  @override
  void initState() {
    super.initState();
    // 컬렉션이 비었으면 기본 3개 시드 (idempotent).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainCategoryRepositoryProvider).seedDefaultsIfEmpty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(mainCategoriesAllProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBody),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('메인 카테고리 관리'),
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
            builder: (_) => const AdminMainCategoryFormPage(),
          ),
        ),
        child: const Icon(Icons.add_rounded,
            color: AppColors.onPrimary, size: 24),
      ),
      body: categoriesAsync.when(
        loading: () => const _LoadingBody(),
        error: (e, _) => _ErrorBody(
          onRetry: () => ref.invalidate(mainCategoriesAllProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const _EmptyBody();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MainCategoryListItem(entity: categories[i]),
              );
            },
          );
        },
      ),
    );
  }
}

// ── List Item ─────────────────────────────────────────────────────────────────

class _MainCategoryListItem extends ConsumerStatefulWidget {
  final MainCategoryEntity entity;

  const _MainCategoryListItem({required this.entity});

  @override
  ConsumerState<_MainCategoryListItem> createState() =>
      _MainCategoryListItemState();
}

class _MainCategoryListItemState
    extends ConsumerState<_MainCategoryListItem> {
  // 낙관적 UI 금지: 실제 toggle 완료 전까지 switch 값을 임시 상태로만 관리
  bool? _pendingValue;

  Future<void> _onSwitchChanged(bool newValue) async {
    if (!newValue) {
      // true → false: DeactivateConfirmDialog 표시
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => MainCategoryDeactivateConfirmDialog(
          entity: widget.entity,
        ),
      );
      if (confirmed != true) return; // 취소 → 원상복구 (setState 불필요, pendingValue 없음)
    }

    // false → true: 즉시 토글 / 또는 deactivate 확인 후 토글
    setState(() => _pendingValue = newValue);
    try {
      await ref
          .read(toggleMainCategoryActiveUseCaseProvider)
          .call(widget.entity.id, newValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              newValue ? '카테고리를 활성화했어요' : '카테고리를 비활성화했어요'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // 실패 시 원상복구
      setState(() => _pendingValue = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _pendingValue = null);
    }
  }

  void _pushEditPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminMainCategoryFormPage(editItem: widget.entity),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog<void>(
      context: context,
      builder: (_) =>
          MainCategoryDeleteDialog(entity: widget.entity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    final isActive = _pendingValue ?? entity.active;

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
              entity.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.textHeading
                    : AppColors.textMuted,
              ),
            ),
            subtitle: _UsageChip(categoryId: entity.id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActiveSwitch(
                  value: isActive,
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
  final String categoryId;

  const _UsageChip({required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(mainCategoryUsageProvider(categoryId));

    return usageAsync.when(
      loading: () => Container(
        width: 60,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      error: (_, _) => const Text(
        '-',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      data: (count) => Text(
        count == 0 ? '사용 없음' : '사용 중 $count개',
        style:
            const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

class _ActiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ActiveSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: value,
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primaryBright.withValues(alpha: 0.3),
      inactiveThumbColor: AppColors.textMuted,
      inactiveTrackColor: AppColors.surface,
      onChanged: onChanged,
    );
  }
}

// ── State UI ──────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: 4,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _SkeletonItem(),
      ),
    );
  }
}

class _SkeletonItem extends StatelessWidget {
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
            '카테고리 목록을 불러오지 못했어요',
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
            child: const Text(
              '다시 시도',
              style: TextStyle(color: AppColors.primary),
            ),
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
          Icon(Icons.category_outlined,
              size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            '등록된 카테고리가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '아래 버튼으로 첫 카테고리를 추가해보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
