import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/owner/brand_store/owner_brand_store_menus_providers.dart';
import 'package:qradar/presentation/owner/store_menu/widgets/sold_out_toggle.dart';

/// 브랜드 매장 점주용 메뉴 리스트 화면 (sub-phase 5 — W7).
///
/// - 마스터 ref + 점포 한정 메뉴를 watchByStore case B 머지 결과로 표시.
/// - 품절 토글 + 옵션 관리만 가능. 메뉴 추가/수정/삭제 불가.
/// - FAB 없음.
class OwnerBrandStoreMenusPage extends ConsumerWidget {
  final StoreEntity store;

  const OwnerBrandStoreMenusPage({super.key, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = BrandMenuKey(
      storeId: store.id,
      brandId: store.brandId ?? '',
    );
    final menuAsync = ref.watch(ownerBrandStoreMenusProvider(key));

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
      body: Column(
        children: [
          const _BrandStoreInfoBanner(),
          Expanded(
            child: menuAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, st) => _ErrorView(
                onRetry: () =>
                    ref.invalidate(ownerBrandStoreMenusProvider(key)),
              ),
              data: (items) {
                if (items.isEmpty) return const _EmptyView();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: items.length,
                  itemBuilder: (_, i) =>
                      _BrandStoreMenuCard(item: items[i], store: store),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 안내 배너 ─────────────────────────────────────────────────────────────

class _BrandStoreInfoBanner extends StatelessWidget {
  const _BrandStoreInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: AppColors.info.withValues(alpha: 0.25),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.info),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '점주는 품절과 옵션 비활성화만 가능해요. 메뉴 추가/수정은 브랜드 본사에서 관리합니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.info,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 메뉴 카드 ─────────────────────────────────────────────────────────────

class _BrandStoreMenuCard extends ConsumerStatefulWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _BrandStoreMenuCard({required this.item, required this.store});

  @override
  ConsumerState<_BrandStoreMenuCard> createState() =>
      _BrandStoreMenuCardState();
}

class _BrandStoreMenuCardState extends ConsumerState<_BrandStoreMenuCard> {
  bool _soldOutLoading = false;
  bool? _optimisticSoldOut;

  Future<void> _toggleSoldOut(bool nextValue) async {
    if (_soldOutLoading) return;
    setState(() {
      _soldOutLoading = true;
      _optimisticSoldOut = nextValue;
    });
    try {
      if (widget.item.scope == MenuItemScope.brand) {
        // 마스터 ref → override upsert
        final override = MenuOverrideEntity(
          masterMenuItemId: widget.item.id,
          storeId: widget.store.id,
          brandId: widget.store.brandId ?? '',
          soldOut: nextValue,
        );
        await ref
            .read(toggleSoldOutForOverrideUseCaseProvider)
            .call(override, nextValue);
      } else {
        // 점포 한정 메뉴
        await ref
            .read(toggleSoldOutForPersonalMenuUseCaseProvider)
            .call(widget.item, nextValue);
      }
      if (mounted) setState(() => _optimisticSoldOut = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _optimisticSoldOut = null);
      await showErrorDialog(context, '변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _soldOutLoading = false);
    }
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BrandActionSheet(
        item: widget.item,
        store: widget.store,
      ),
    );
  }

  void _openOptionSheet(BuildContext context) {
    final menuType = widget.item.scope == MenuItemScope.brand
        ? MenuOptionDisableSheetType.brandMasterRef
        : MenuOptionDisableSheetType.personal;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuOptionDisableSheet(
        storeId: widget.store.id,
        menuItem: widget.item,
        menuType: menuType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = _optimisticSoldOut ?? widget.item.soldOut;

    return GestureDetector(
      onLongPress: () => _showActions(context),
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
                  // 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: widget.item.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, st) =>
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
                            _ScopeBadge(scope: widget.item.scope),
                            const SizedBox(width: 6),
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
                            if (soldOut) const _SoldOutBadge(),
                            const SizedBox(width: 8),
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
                            IconButton(
                              icon: const Icon(Icons.tune_rounded,
                                  size: 20, color: AppColors.primary),
                              tooltip: '옵션 관리',
                              onPressed: () => _openOptionSheet(context),
                            ),
                          ],
                        ),
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

// ── 스코프 배지 ───────────────────────────────────────────────────────────

class _ScopeBadge extends StatelessWidget {
  final MenuItemScope scope;

  const _ScopeBadge({required this.scope});

  @override
  Widget build(BuildContext context) {
    final isBrand = scope == MenuItemScope.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isBrand
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isBrand ? '마스터' : '매장 한정',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isBrand ? AppColors.primary : AppColors.accent,
        ),
      ),
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

// ── 브랜드 액션 시트 (옵션 관리만) ───────────────────────────────────────

class _BrandActionSheet extends StatelessWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _BrandActionSheet({required this.item, required this.store});

  @override
  Widget build(BuildContext context) {
    final menuType = item.scope == MenuItemScope.brand
        ? MenuOptionDisableSheetType.brandMasterRef
        : MenuOptionDisableSheetType.personal;

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
            ListTile(
              leading:
                  const Icon(Icons.tune_rounded, color: AppColors.primary),
              title: const Text(
                '옵션 관리',
                style: TextStyle(fontSize: 15, color: AppColors.textBody),
              ),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MenuOptionDisableSheet(
                    storeId: store.id,
                    menuItem: item,
                    menuType: menuType,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상태 위젯 ─────────────────────────────────────────────────────────────

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
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 56, color: AppColors.textMuted),
          SizedBox(height: 20),
          Text(
            '아직 등록된 메뉴가 없어요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading),
          ),
          SizedBox(height: 8),
          Text(
            '브랜드 본사에서 마스터 메뉴를 추가하면 여기에 표시돼요.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
