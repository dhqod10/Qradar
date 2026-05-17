import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/owner/providers/owner_store_menu_providers.dart';
import 'package:qradar/presentation/owner/store_menu/owner_store_menu_form_page.dart';

/// 개인 매장 메뉴 상세 화면 (sub-phase 4).
///
/// D1: ApprovalStatusBadge / 승인 메타 섹션 완전 미노출.
/// PopupMenu: 수정 / 복제 / 삭제.
class OwnerStoreMenuDetailPage extends ConsumerWidget {
  final StoreEntity store;
  final MenuItemEntity item;

  const OwnerStoreMenuDetailPage({
    super.key,
    required this.store,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: Text(
          item.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textHeading),
            onSelected: (action) =>
                _handleAction(context, ref, action),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _MenuAction.manageOptions,
                child: Text('옵션 관리'),
              ),
              const PopupMenuItem(
                value: _MenuAction.edit,
                child: Text('수정'),
              ),
              const PopupMenuItem(
                value: _MenuAction.clone,
                child: Text('복제'),
              ),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: Text(
                  '삭제',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            _ImageSection(item: item),

            // 기본 정보
            _BasicInfoSection(item: item),

            const SizedBox(height: 12),

            // 카테고리 / 태그 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DetailSectionCard(
                child: Column(
                  children: [
                    _InfoRow(
                      label: '카테고리',
                      value: item.mainCategoryCode +
                          (item.subCategoryId != null
                              ? ' > ${item.subCategoryId}'
                              : ''),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: '노출 순서',
                      value: '${item.displayOrder}',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: '메뉴 노출',
                      value: item.visible ? '노출 중' : '숨김',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: '품절 여부',
                      value: item.soldOut ? '품절' : '판매 중',
                      valueColor: item.soldOut
                          ? AppColors.error
                          : AppColors.success,
                    ),
                    if (item.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: item.tags
                            .map((t) => _TagChip(tag: t))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 가격 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DetailSectionCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '기본가',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                    ),
                    Text(
                      '₩${item.basePrice}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 옵션 그룹 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _OptionGroupSection(item: item),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, _MenuAction action) async {
    switch (action) {
      case _MenuAction.manageOptions:
        if (!context.mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MenuOptionDisableSheet(
            storeId: store.id,
            menuItem: item,
            menuType: MenuOptionDisableSheetType.personal,
          ),
        );
      case _MenuAction.edit:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OwnerStoreMenuFormPage(store: store, editItem: item),
          ),
        );
      case _MenuAction.clone:
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
      case _MenuAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '메뉴를 삭제할까요?',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading),
        ),
        content: const Text(
          '삭제된 메뉴는 복구할 수 없어요.',
          style: TextStyle(fontSize: 14, color: AppColors.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(deleteOwnerStoreMenuUseCaseProvider)
          .call(store.id, item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('삭제됐어요'),
          backgroundColor: AppColors.primary.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      await showErrorDialog(context, '삭제에 실패했어요. 다시 시도해주세요');
    }
  }
}

enum _MenuAction { manageOptions, edit, clone, delete }

// ── 이미지 영역 ───────────────────────────────────────────────────────────

class _ImageSection extends StatelessWidget {
  final MenuItemEntity item;

  const _ImageSection({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageWidget = item.imageUrl.isNotEmpty
        ? Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 220,
            errorBuilder: (ctx, err, st) => _placeholder(),
          )
        : _placeholder();

    if (!item.soldOut) return imageWidget;

    // soldOut 오버레이 (sub-phase 5 — D5)
    return Stack(
      children: [
        imageWidget,
        Positioned.fill(
          child: Container(
            color: AppColors.error.withValues(alpha: 0.45),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: const Text(
                  '품절',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 220,
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.local_cafe_outlined,
            size: 56, color: AppColors.textMuted),
      ),
    );
  }
}

// ── 기본 정보 섹션 ────────────────────────────────────────────────────────

class _BasicInfoSection extends StatelessWidget {
  final MenuItemEntity item;

  const _BasicInfoSection({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 8),
          if (item.description != null && item.description!.isNotEmpty)
            Text(
              item.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textBody,
                height: 1.5,
              ),
            )
          else
            const Text(
              '설명이 없어요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 디테일 섹션 카드 ──────────────────────────────────────────────────────

class _DetailSectionCard extends StatelessWidget {
  final Widget child;

  const _DetailSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// ── 정보 행 ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textMuted)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textBody)),
      ],
    );
  }
}

// ── 태그 칩 ───────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── 옵션 그룹 섹션 ────────────────────────────────────────────────────────

class _OptionGroupSection extends StatelessWidget {
  final MenuItemEntity item;

  const _OptionGroupSection({required this.item});

  @override
  Widget build(BuildContext context) {
    return _DetailSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '옵션 그룹',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (item.optionGroupRefs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '선택된 옵션 그룹 없음',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: item.optionGroupRefs.length,
              itemBuilder: (_, i) {
                final ref = item.optionGroupRefs[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    ref.id,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBody),
                  ),
                  subtitle: Text(
                    ref.scope.asString == 'store'
                        ? '매장 한정 옵션'
                        : '마스터 옵션',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
