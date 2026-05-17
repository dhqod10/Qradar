import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/presentation/brand/master_menu/master_menu_form_page.dart';
import 'package:qradar/presentation/brand/providers/brand_master_menu_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';

/// 마스터 메뉴 상세 읽기 전용 뷰 + 수정 / 복제 / 삭제 진입.
class MasterMenuDetailPage extends ConsumerWidget {
  final MenuItemEntity item;
  const MasterMenuDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeading),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textHeading,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHeading),
            color: AppColors.surfaceElevated,
            onSelected: (v) => _onAction(context, ref, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('수정')),
              const PopupMenuItem(value: 'clone', child: Text('복제')),
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            SizedBox(
              width: double.infinity,
              height: 220,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(item.imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(Icons.local_cafe_outlined,
                            size: 56, color: AppColors.textMuted),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: AppColors.textHeading)),
                      ),
                      if (item.status != null)
                        ApprovalStatusBadge(
                          status: item.status!,
                          isRevision: item.approvedAt != null &&
                              item.status == EntityApprovalStatus.pending,
                          large: true,
                        ),
                    ],
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 8),
                    Text(item.description!,
                        style: const TextStyle(fontSize: 14, color: AppColors.textBody)),
                  ],
                  const SizedBox(height: 16),
                  _DetailCard(children: [
                    _InfoRow('카테고리',
                        '${item.mainCategoryCode}${item.subCategoryId != null ? ' > ${item.subCategoryId}' : ''}'),
                    _InfoRow('노출 순서', '${item.displayOrder}'),
                    _InfoRow('메뉴 노출', item.visible ? '노출 중' : '숨김'),
                    if (item.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: item.tags
                            .map((t) => Chip(
                                  label: Text(t, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: AppColors.surface,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _DetailCard(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('기본가',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                        Text('₩${item.basePrice}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: AppColors.textHeading)),
                      ],
                    ),
                  ]),
                  if (item.status != null) ...[
                    const SizedBox(height: 12),
                    _DetailCard(children: [
                      if (item.submittedAt != null)
                        _InfoRow('제출일', _fmt(item.submittedAt)),
                      if (item.approvedAt != null)
                        _InfoRow('처리일', _fmt(item.approvedAt)),
                    ]),
                  ],
                  if (item.status == EntityApprovalStatus.rejected &&
                      item.rejectedReason != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 6),
                            Text('반려 사유',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: AppColors.error)),
                          ]),
                          const SizedBox(height: 8),
                          Text(item.rejectedReason!,
                              style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => MasterMenuFormPage(editItem: item)));
      case 'clone':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => MasterMenuFormPage(sourceForClone: item)));
      case 'delete':
        _confirmDelete(context, ref);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('메뉴를 삭제할까요?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textHeading)),
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
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
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
                      child: const Text('취소',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                            Navigator.pop(context);
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
      ),
    );
  }

  static String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textBody)),
        ],
      ),
    );
  }
}
