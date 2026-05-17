import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/presentation/brand/master_menu/master_menu_detail_page.dart';
import 'package:qradar/presentation/brand/master_menu/master_menu_form_page.dart';
import 'package:qradar/presentation/brand/providers/brand_master_menu_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';

/// 브랜드의 마스터 메뉴 목록 + CRUD 진입.
class MasterMenuListPage extends ConsumerWidget {
  const MasterMenuListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(myMasterMenuItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '마스터 메뉴',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 26, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MasterMenuFormPage(),
              ),
            ),
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myMasterMenuItemsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyView(
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MasterMenuFormPage()),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _MasterMenuItemCard(item: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _MasterMenuItemCard extends ConsumerWidget {
  final MenuItemEntity item;
  const _MasterMenuItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MasterMenuDetailPage(item: item)),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₩${item.basePrice}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                          ),
                        ),
                        const Spacer(),
                        _CardActions(item: item),
                      ],
                    ),
                  ],
                ),
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
      builder: (_) => _ActionSheet(item: item),
    );
  }
}

class _CardActions extends ConsumerWidget {
  final MenuItemEntity item;
  const _CardActions({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // 결정 J — visible 즉시 토글 (운영 필드, status 보존)
        _VisibleToggleButton(item: item),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.textMuted),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MasterMenuFormPage(sourceForClone: item),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MasterMenuFormPage(editItem: item),
            ),
          ),
        ),
      ],
    );
  }
}

/// 카드 인라인 visible 토글 버튼.
///
/// onTap → updateMasterMenuItemOperationUseCase(visible: !current) 즉시 호출.
/// status 라벨은 그대로 유지.
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
          .read(updateMasterMenuItemOperationUseCaseProvider)
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

class _ActionSheet extends ConsumerWidget {
  final MenuItemEntity item;
  const _ActionSheet({required this.item});

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
                  builder: (_) => MasterMenuFormPage(editItem: item),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: AppColors.textMuted),
            title: const Text('복제'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MasterMenuFormPage(sourceForClone: item),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: AppColors.error),
            title: const Text('삭제', style: TextStyle(color: AppColors.error)),
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
      builder: (ctx) => _DeleteDialog(item: item),
    );
  }
}

class _DeleteDialog extends ConsumerWidget {
  final MenuItemEntity item;
  const _DeleteDialog({required this.item});

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
              '메뉴를 삭제할까요?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textHeading),
            ),
            const SizedBox(height: 12),
            FutureBuilder<int>(
              future: ref
                  .read(countStoresUsingPriceOverrideUseCaseProvider)
                  .call(item.brandId ?? '', item.id),
              builder: (context, snapshot) {
                final String message;
                if (snapshot.connectionState != ConnectionState.done) {
                  message = '영향 매장 확인 중...';
                } else if (snapshot.hasError) {
                  message = '영향 매장 확인에 실패했어요.';
                } else {
                  final n = snapshot.data ?? 0;
                  message = n == 0
                      ? '현재 연결된 매장이 없습니다.'
                      : '이 메뉴를 삭제하면 $n개 매장에서 제거됩니다.';
                }
                return Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final brandId = item.brandId ?? '';
                        await ref
                            .read(deleteMasterMenuItemUseCaseProvider)
                            .call(brandId, item.id);
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

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_cafe_outlined, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          const Text('아직 등록된 메뉴가 없어요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textHeading)),
          const SizedBox(height: 8),
          const Text('마스터 메뉴를 등록하고 admin 승인을 받아보세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('+ 메뉴 추가', style: TextStyle(fontWeight: FontWeight.w600)),
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
    return const Center(child: CircularProgressIndicator(color: AppColors.primaryBright));
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('데이터를 불러오지 못했어요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textHeading)),
          const SizedBox(height: 8),
          const Text('일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
