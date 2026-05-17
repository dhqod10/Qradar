import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/approval/admin_store_approval_detail_page.dart';
import 'package:qradar/presentation/admin/providers/admin_store_approval_providers.dart';
import 'package:qradar/presentation/admin/widgets/brand_scope_badge.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// admin 매장 승인 큐 — pending 매장 목록.
class AdminPendingStoresPage extends ConsumerWidget {
  const AdminPendingStoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(adminPendingStoresProvider);

    return storesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBright),
      ),
      error: (e, _) => _ErrorView(
        message: '데이터를 불러오는 데 실패했어요.\n인덱스 설정이 필요할 수 있습니다.',
        onRetry: () => ref.invalidate(adminPendingStoresProvider),
      ),
      data: (stores) {
        if (stores.isEmpty) {
          return const _EmptyView(
            icon: Icons.storefront_outlined,
            message: '승인 대기 중인 매장이 없어요',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: stores.length,
          itemBuilder: (_, i) => _StoreQueueTile(store: stores[i]),
        );
      },
    );
  }
}

// ── Store Queue Tile ──────────────────────────────────────────────────────

class _StoreQueueTile extends StatelessWidget {
  final StoreEntity store;
  const _StoreQueueTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final firstImage =
        store.imageUrls.isNotEmpty ? store.imageUrls.first : store.imageUrl;

    return Card(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminStoreApprovalDetailPage(store: store),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대표 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: firstImage.isNotEmpty
                      ? Image.network(firstImage, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.storefront_rounded,
                              size: 24, color: AppColors.textMuted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + 배지 + ApprovalStatusBadge (수정 대기 분기)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 브랜드 매장 vs 개인 매장 분기
                        if (store.brandId != null && store.brandId!.isNotEmpty)
                          BrandScopeBadge(brandId: store.brandId!)
                        else
                          const StoreScopeBadge.personal(),
                        const SizedBox(width: 6),
                        ApprovalStatusBadge(
                          status: store.status,
                          isRevision: store.approvedAt != null &&
                              store.status == EntityApprovalStatus.pending,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 주소
                    if (store.address.isNotEmpty)
                      Text(
                        store.address,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // 카테고리
                    if (store.menuCategories.isNotEmpty)
                      Text(
                        store.menuCategories.first,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    const SizedBox(height: 4),
                    // 제출 시각 + 수정 대기 라벨
                    Row(
                      children: [
                        Text(
                          '${_fmt(store.submittedAt)} 제출',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        if (store.approvedAt != null &&
                            store.status == EntityApprovalStatus.pending) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '· 수정 대기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading),
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
            '불러오기 실패',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading),
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

String _fmt(DateTime? dt) {
  if (dt == null) return '-';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
