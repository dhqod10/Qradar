import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/presentation/admin/approval/admin_brand_store_item_approval_detail_page.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_customization_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// admin 점포 한정 메뉴 pending 큐 (IndexedStack 자식 — Scaffold 없음).
class AdminPendingBrandStoreItemsPage extends ConsumerWidget {
  const AdminPendingBrandStoreItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(pendingBrandStoreItemsProvider);

    return itemsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _ErrorView(
        message: '데이터를 불러오는 데 실패했어요.\n인덱스 설정이 필요할 수 있습니다.',
        onRetry: () => ref.invalidate(pendingBrandStoreItemsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyView();
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          itemBuilder: (_, i) => _BrandStoreItemTile(item: items[i]),
        );
      },
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────

class _BrandStoreItemTile extends StatelessWidget {
  final MenuItemEntity item;
  const _BrandStoreItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isRevision = item.approvedAt != null &&
        item.status == EntityApprovalStatus.pending;

    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                AdminBrandStoreItemApprovalDetailPage(menuItem: item),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.status != null)
                    ApprovalStatusBadge(
                      status: item.status!,
                      isRevision: isRevision,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '₩${_formatPrice(item.basePrice)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.storefront_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '매장: ${item.storeId}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.business_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '브랜드: ${item.brandId ?? '-'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '제출: ${_fmt(item.submittedAt)}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              if (isRevision)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '수정 대기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / Error Views ───────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_business_outlined,
              size: 56, color: AppColors.textMuted),
          SizedBox(height: 20),
          Text(
            '승인 대기 중인 점포 한정 메뉴가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '새로운 점포 한정 메뉴 요청이 들어오면 여기에 표시돼요.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
            '데이터를 불러오는 데 실패했어요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
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
            child: const Text('다시 시도',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _fmt(DateTime? dt) {
  if (dt == null) return '-';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatPrice(int price) => price
    .toString()
    .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
