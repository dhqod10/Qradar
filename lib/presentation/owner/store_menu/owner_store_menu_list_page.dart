import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/owner/brand_store/owner_brand_store_menus_providers.dart';
import 'package:qradar/presentation/owner/providers/owner_store_menu_providers.dart';
import 'package:qradar/presentation/owner/store_menu/owner_store_menu_detail_page.dart';
import 'package:qradar/presentation/owner/store_menu/owner_store_menu_form_page.dart';
import 'package:qradar/presentation/owner/store_menu/widgets/sold_out_toggle.dart';

/// 개인 매장 메뉴 목록 화면 (sub-phase 4 + 5 갱신).
///
/// - FAB "메뉴 추가" → OwnerStoreMenuFormPage(mode=create)
/// - 카드 탭 → OwnerStoreMenuDetailPage
/// - 카드 long-press → 액션 시트 (옵션 관리 / 편집 / 복제 / 삭제)
/// - 카드 인라인 visible 토글 (V7) + 품절 토글 (sub-phase 5)
class OwnerStoreMenuListPage extends ConsumerWidget {
  final StoreEntity store;

  const OwnerStoreMenuListPage({super.key, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(ownerStoreMenusProvider(store.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHeading),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '메뉴 관리',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 22, color: AppColors.onPrimary),
        label: const Text(
          '메뉴 추가',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OwnerStoreMenuFormPage(store: store),
          ),
        ),
      ),
      body: menuAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(ownerStoreMenusProvider(store.id)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyView(
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => OwnerStoreMenuFormPage(store: store)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _OwnerMenuCard(item: items[i], store: store),
          );
        },
      ),
    );
  }
}

// ── 카드 ──────────────────────────────────────────────────────────────────

class _OwnerMenuCard extends ConsumerStatefulWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _OwnerMenuCard({required this.item, required this.store});

  @override
  ConsumerState<_OwnerMenuCard> createState() => _OwnerMenuCardState();
}

class _OwnerMenuCardState extends ConsumerState<_OwnerMenuCard> {
  bool _soldOutLoading = false;
  bool? _optimisticSoldOut;

  Future<void> _toggleSoldOut(bool nextValue) async {
    if (_soldOutLoading) return;
    setState(() {
      _soldOutLoading = true;
      _optimisticSoldOut = nextValue;
    });
    try {
      await ref
          .read(toggleSoldOutForPersonalMenuUseCaseProvider)
          .call(widget.item, nextValue);
      if (mounted) setState(() => _optimisticSoldOut = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _optimisticSoldOut = null);
      await showErrorDialog(context, '변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _soldOutLoading = false);
    }
  }

  void _openOptionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuOptionDisableSheet(
        storeId: widget.store.id,
        menuItem: widget.item,
        menuType: MenuOptionDisableSheetType.personal,
      ),
    );
  }

  void _showActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ActionSheet(
        item: widget.item,
        store: widget.store,
        onOptionsTap: () {
          Navigator.pop(context);
          _openOptionSheet();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = _optimisticSoldOut ?? widget.item.soldOut;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OwnerStoreMenuDetailPage(store: widget.store, item: widget.item),
        ),
      ),
      onLongPress: _showActions,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 메뉴 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: widget.item.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) =>
                                  _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textHeading,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // 배지: 품절 우선, 그 다음 비공개
                            if (soldOut)
                              const _SoldOutBadge()
                            else if (!widget.item.visible)
                              const _HiddenBadge(),
                            const SizedBox(width: 8),
                            // visible 토글 (라벨 "표시" 추가 — D3)
                            _InlineVisibleToggle(item: widget.item),
                            const SizedBox(width: 12),
                            // 품절 토글 (sub-phase 5)
                            SoldOutToggle(
                              soldOut: soldOut,
                              isLoading: _soldOutLoading,
                              onChanged: _toggleSoldOut,
                            ),
                          ],
                        ),
                        if (widget.item.description != null &&
                            widget.item.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.item.description!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '₩${widget.item.basePrice}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHeading,
                              ),
                            ),
                            const Spacer(),
                            _CardActions(
                              item: widget.item,
                              store: widget.store,
                            ),
                          ],
                        ),
                        if (widget.item.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: widget.item.tags
                                .map((t) => _TagChipSmall(tag: t))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // soldOut 오버레이 — 시각적 dim 만, 터치 이벤트는 통과시켜야
          // 토글/옵션 버튼이 계속 동작 가능
          if (soldOut)
            Positioned.fill(
              bottom: 12,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Icon(Icons.local_cafe_outlined,
          size: 28, color: AppColors.textMuted),
    );
  }
}

// ── 품절 배지 ─────────────────────────────────────────────────────────────

class _SoldOutBadge extends StatelessWidget {
  const _SoldOutBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: const Text(
        '품절',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
        ),
      ),
    );
  }
}

// ── 비공개 배지 ───────────────────────────────────────────────────────────

class _HiddenBadge extends StatelessWidget {
  const _HiddenBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '비공개',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── 인라인 visible 토글 (V7) ──────────────────────────────────────────────

class _InlineVisibleToggle extends ConsumerStatefulWidget {
  final MenuItemEntity item;

  const _InlineVisibleToggle({required this.item});

  @override
  ConsumerState<_InlineVisibleToggle> createState() =>
      _InlineVisibleToggleState();
}

class _InlineVisibleToggleState extends ConsumerState<_InlineVisibleToggle> {
  bool _isLoading = false;
  bool? _optimisticValue;

  Future<void> _toggle(bool nextValue) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _optimisticValue = nextValue;
    });
    try {
      final updated = widget.item.copyWith(visible: nextValue);
      await ref.read(updateOwnerStoreMenuUseCaseProvider).call(updated);
      if (mounted) setState(() => _optimisticValue = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _optimisticValue = null);
      await showErrorDialog(context, '변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = _optimisticValue ?? widget.item.visible;
    if (_isLoading) {
      return const SizedBox(
        width: 44,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '표시',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 44,
          child: Switch.adaptive(
            value: currentValue,
            onChanged: _toggle,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveTrackColor: AppColors.surface,
          ),
        ),
      ],
    );
  }
}

// ── 카드 액션 (편집 / 복제) ───────────────────────────────────────────────

class _CardActions extends ConsumerWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _CardActions({required this.item, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.copy_rounded,
              size: 20, color: AppColors.textMuted),
          tooltip: '복제',
          onPressed: () => _clone(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded,
              size: 20, color: AppColors.primary),
          tooltip: '편집',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OwnerStoreMenuFormPage(store: store, editItem: item),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clone(BuildContext context, WidgetRef ref) async {
    final cloned =
        await ref.read(cloneOwnerStoreMenuUseCaseProvider).call(store.id, item.id);
    if (cloned == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OwnerStoreMenuFormPage(store: store, prefillItem: cloned),
      ),
    );
  }
}

// ── 액션 시트 ─────────────────────────────────────────────────────────────

class _ActionSheet extends ConsumerWidget {
  final MenuItemEntity item;
  final StoreEntity store;
  final VoidCallback? onOptionsTap;

  const _ActionSheet({
    required this.item,
    required this.store,
    this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 옵션 관리 (최상단 — sub-phase 5)
            ListTile(
              leading:
                  const Icon(Icons.tune_rounded, color: AppColors.primary),
              title: const Text('옵션 관리',
                  style: TextStyle(fontSize: 15, color: AppColors.textBody)),
              onTap: onOptionsTap,
            ),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading:
                  const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('편집',
                  style: TextStyle(fontSize: 15, color: AppColors.textBody)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OwnerStoreMenuFormPage(store: store, editItem: item),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.copy_rounded, color: AppColors.textMuted),
              title: const Text('복제',
                  style: TextStyle(fontSize: 15, color: AppColors.textBody)),
              onTap: () async {
                Navigator.pop(context);
                final cloned = await ref
                    .read(cloneOwnerStoreMenuUseCaseProvider)
                    .call(store.id, item.id);
                if (cloned == null || !context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OwnerStoreMenuFormPage(store: store, prefillItem: cloned),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('삭제',
                  style:
                      TextStyle(fontSize: 15, color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('메뉴를 삭제할까요?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading)),
        content: const Text('삭제된 메뉴는 복구할 수 없어요.',
            style: TextStyle(fontSize: 14, color: AppColors.textBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제',
                style: TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(deleteOwnerStoreMenuUseCaseProvider)
          .call(store.id, item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('삭제됐어요'),
            backgroundColor: AppColors.primary.withValues(alpha: 0.9),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제에 실패했어요: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// ── 작은 태그 칩 ──────────────────────────────────────────────────────────

class _TagChipSmall extends StatelessWidget {
  final String tag;

  const _TagChipSmall({required this.tag});

  String get _label {
    switch (tag) {
      case 'recommended':
        return '추천';
      case 'new':
        return '신메뉴';
      case 'best':
        return '베스트';
      default:
        return tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── 상태 위젯 ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 3,
      itemBuilder: (_, _) => _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      height: 14,
                      width: 120,
                      color: AppColors.surfaceElevated),
                  const SizedBox(height: 8),
                  Container(
                      height: 12,
                      width: 80,
                      color: AppColors.surfaceElevated),
                  const SizedBox(height: 8),
                  Container(
                      height: 12,
                      width: 60,
                      color: AppColors.surfaceElevated),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            '메뉴를 불러오지 못했어요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading),
          ),
          const SizedBox(height: 8),
          const Text(
            '잠시 후 다시 시도해주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_cafe_outlined,
              size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          const Text(
            '아직 등록된 메뉴가 없어요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading),
          ),
          const SizedBox(height: 8),
          const Text(
            '+ 버튼을 눌러 첫 메뉴를 등록해보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text(
              '+ 첫 메뉴 등록하기',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
