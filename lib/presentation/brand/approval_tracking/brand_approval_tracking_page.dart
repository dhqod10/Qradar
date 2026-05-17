import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/brand/providers/brand_store_management_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// 브랜드 사용자가 제출한 항목의 검토 현황 트래킹.
///
/// 현재 phase: 매장 + 가격 오버라이드.
/// (점포 한정 메뉴 트래킹은 후속 phase 예정)
class BrandApprovalTrackingPage extends ConsumerWidget {
  const BrandApprovalTrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(brandStoresProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '검토 현황',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: storesAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(brandStoresProvider),
        ),
        data: (stores) => _TrackingBody(stores: stores),
      ),
    );
  }
}

// ── 본문 ──────────────────────────────────────────────────────────────────────

class _TrackingBody extends ConsumerWidget {
  final List<StoreEntity> stores;

  const _TrackingBody({required this.stores});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 각 매장의 오버라이드 stream watch
    final overrideAsyncList = stores
        .map((s) => ref.watch(menuOverridesByStoreProvider(s.id)))
        .toList();

    // 하나라도 로딩 중이면 로딩 표시
    final isLoading = overrideAsyncList.any((a) => a.isLoading);
    if (isLoading) return const _LoadingView();

    // 통합 트래킹 항목 수집
    final items = <_TrackingItem>[];

    // 1) 매장 항목 (status != approved 인 것만 — pending/rejected 노출)
    for (final store in stores) {
      if (store.status != EntityApprovalStatus.approved) {
        items.add(_TrackingItem.fromStore(store));
      }
    }

    // 2) 가격 오버라이드 항목 (status != approved 인 것만)
    for (var i = 0; i < stores.length; i++) {
      final overrideAsync = overrideAsyncList[i];
      final overrides = overrideAsync.asData?.value ?? [];
      final store = stores[i];
      for (final o in overrides) {
        if (o.status != EntityApprovalStatus.approved) {
          items.add(_TrackingItem.fromOverride(o, storeName: store.name));
        }
      }
    }

    // submittedAt desc 정렬
    items.sort((a, b) {
      final ta = a.submittedAt;
      final tb = b.submittedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    if (items.isEmpty) {
      return const _EmptyView();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _TrackingTile(item: items[index]);
      },
    );
  }
}

// ── 트래킹 데이터 모델 ────────────────────────────────────────────────────────

enum _ItemType { store, priceOverride }

class _TrackingItem {
  final _ItemType type;
  final String title;
  final String storeName;
  final EntityApprovalStatus status;
  final DateTime? submittedAt;
  final String? rejectedReason;
  final bool isRevision;

  const _TrackingItem({
    required this.type,
    required this.title,
    required this.storeName,
    required this.status,
    this.submittedAt,
    this.rejectedReason,
    this.isRevision = false,
  });

  factory _TrackingItem.fromStore(StoreEntity store) {
    return _TrackingItem(
      type: _ItemType.store,
      title: store.name,
      storeName: store.name,
      status: store.status,
      submittedAt: store.submittedAt,
      rejectedReason: store.rejectedReason,
      isRevision: store.approvedAt != null &&
          store.status == EntityApprovalStatus.pending,
    );
  }

  factory _TrackingItem.fromOverride(
    MenuOverrideEntity o, {
    required String storeName,
  }) {
    return _TrackingItem(
      type: _ItemType.priceOverride,
      title: '가격 오버라이드',
      storeName: storeName,
      status: o.status,
      submittedAt: o.submittedAt,
      rejectedReason: o.rejectedReason,
      isRevision:
          o.approvedAt != null && o.status == EntityApprovalStatus.pending,
    );
  }
}

// ── 트래킹 타일 ───────────────────────────────────────────────────────────────

class _TrackingTile extends StatelessWidget {
  final _TrackingItem item;

  const _TrackingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 타입 뱃지 + 상태 뱃지
            Row(
              children: [
                _TypeBadge(type: item.type),
                const SizedBox(width: 8),
                ApprovalStatusBadge(
                  status: item.status,
                  isRevision: item.isRevision,
                ),
                const Spacer(),
                if (item.submittedAt != null)
                  Text(
                    _formatDate(item.submittedAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 제목
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            // 매장명 (매장 타입이 아닌 경우만)
            if (item.type != _ItemType.store) ...[
              const SizedBox(height: 4),
              Text(
                item.storeName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            // 반려 사유
            if (item.status == EntityApprovalStatus.rejected &&
                item.rejectedReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.rejectedReason!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ── 타입 뱃지 ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final _ItemType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (type) {
      _ItemType.store => (AppColors.info, '매장'),
      _ItemType.priceOverride => (AppColors.accent, '가격'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              '제출한 항목이 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '매장 또는 가격 재정의를 제출하면\n여기에서 검토 상태를 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
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
