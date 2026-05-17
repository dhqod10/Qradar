import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart';
import 'package:qradar/presentation/brand/providers/brand_store_management_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';

/// 특정 매장의 점포 한정 메뉴 목록.
///
/// FAB 는 [BrandStoreCustomizationPage] 에서 노출.
/// long-press → 액션 시트(편집 / 복제 / 삭제).
class BrandStoreOnlyMenuListPage extends ConsumerWidget {
  final StoreEntity store;

  const BrandStoreOnlyMenuListPage({super.key, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(storeOnlyMenusProvider(store.id));

    return menuAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(
        onRetry: () => ref.invalidate(storeOnlyMenusProvider(store.id)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyView();
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _StoreOnlyMenuCard(
              item: items[index],
              store: store,
            );
          },
        );
      },
    );
  }
}

// ── 카드 ──────────────────────────────────────────────────────────────────────

class _StoreOnlyMenuCard extends ConsumerWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _StoreOnlyMenuCard({required this.item, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BrandStoreOnlyMenuFormPage(
            brandId: store.brandId ?? '',
            storeId: store.id,
            editItem: item,
          ),
        ),
      ),
      onLongPress: () => _showActions(context, ref),
      child: Container(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(item.imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.local_cafe_outlined,
                            size: 28,
                            color: AppColors.textMuted,
                          ),
                        ),
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
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                        if (item.status != null)
                          ApprovalStatusBadge(
                            status: item.status!,
                            isRevision: item.approvedAt != null &&
                                item.status == EntityApprovalStatus.pending,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₩${item.basePrice}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _VisibleToggleButton(item: item),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ActionSheet(item: item, store: store),
    );
  }
}

// ── 액션 시트 ─────────────────────────────────────────────────────────────────

class _ActionSheet extends ConsumerWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _ActionSheet({required this.item, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
            title: const Text('편집'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrandStoreOnlyMenuFormPage(
                    brandId: store.brandId ?? '',
                    storeId: store.id,
                    editItem: item,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.copy_rounded, color: AppColors.textMuted),
            title: const Text('복제'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrandStoreOnlyMenuFormPage(
                    brandId: store.brandId ?? '',
                    storeId: store.id,
                    sourceForClone: item,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: AppColors.error),
            title: const Text(
              '삭제',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(item: item, store: store),
    );
  }
}

// ── 삭제 확인 다이얼로그 ──────────────────────────────────────────────────────

class _DeleteDialog extends ConsumerWidget {
  final MenuItemEntity item;
  final StoreEntity store;

  const _DeleteDialog({required this.item, required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '점포 한정 메뉴를 삭제할까요?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${item.name} 메뉴를 삭제합니다.\n이 작업은 되돌릴 수 없어요.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await ref
                            .read(deleteStoreOnlyMenuUseCaseProvider)
                            .call(store.id, item.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('메뉴가 삭제되었습니다')),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          await showErrorDialog(context, '삭제에 실패했어요. 다시 시도해주세요');
                        }
                      }
                    },
                    child: const Text('삭제'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상태 뷰 ───────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 56,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 20),
          Text(
            '점포 한정 메뉴가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '아래 "+ 메뉴 추가" 버튼으로 등록해보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryBright),
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
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          const Text(
            '데이터를 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 점포 한정 메뉴 카드 인라인 visible 토글 (master_menu_list_page 패턴 차용).
///
/// onTap → `updateStoreOnlyMenuOperationUseCase(visible: !current)` 즉시 호출.
/// 운영 필드 변경이라 status pending 회귀 없음 (결정 J 정합).
class _VisibleToggleButton extends ConsumerStatefulWidget {
  final MenuItemEntity item;
  const _VisibleToggleButton({required this.item});

  @override
  ConsumerState<_VisibleToggleButton> createState() =>
      _VisibleToggleButtonState();
}

class _VisibleToggleButtonState extends ConsumerState<_VisibleToggleButton> {
  bool _isLoading = false;

  Future<void> _toggle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final next = widget.item.copyWith(visible: !widget.item.visible);
      await ref
          .read(updateStoreOnlyMenuOperationUseCaseProvider)
          .call(next);
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '노출 설정 변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.item.visible;
    return GestureDetector(
      onTap: _toggle,
      child: _isLoading
          ? const SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.primaryBright,
                  ),
                ),
              ),
            )
          : Icon(
              visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 20,
              color: visible ? AppColors.primaryBright : AppColors.textMuted,
            ),
    );
  }
}
