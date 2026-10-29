import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_page.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_tile.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_info_row.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';
import 'package:qradar/presentation/brand/brand_info/widgets/brand_key_row.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// 본인 브랜드의 현재 상태 표시 + 수정 진입.
class BrandInfoPage extends ConsumerWidget {
  const BrandInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandAsync = ref.watch(myBrandProvider);

    return brandAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(error: e, onRetry: () => ref.invalidate(myBrandProvider)),
      data: (brand) {
        if (brand == null) return const _EmptyView();
        return _BrandInfoContent(brand: brand);
      },
    );
  }
}

class _BrandInfoContent extends StatelessWidget {
  final BrandEntity brand;
  const _BrandInfoContent({required this.brand});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '브랜드 정보',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrandInfoFormPage(brand: brand),
                ),
              ),
              child: const Text(
                '수정',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _BrandCard(brand: brand),
              const SizedBox(height: 16),
              // 승인된 브랜드에서만: 승인 전·반려 브랜드는 아직 적립이 일어나지 않는다.
              if (brand.status == EntityApprovalStatus.approved) ...[
                _QoinRateCard(brand: brand),
                const SizedBox(height: 16),
              ],
              _SubmitInfoSection(brand: brand),
              if (brand.status == EntityApprovalStatus.rejected) ...[
                const SizedBox(height: 16),
                _RejectedReasonSection(reason: brand.rejectedReason ?? ''),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _BrandCard extends StatelessWidget {
  final BrandEntity brand;
  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: brand.logoUrl.isNotEmpty
                      ? ColoredBox(
                          color: AppColors.surface,
                          child: Image.network(
                            brand.logoUrl,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 32,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ApprovalStatusBadge(
                      status: brand.status,
                      isRevision: brand.approvedAt != null &&
                          brand.status == EntityApprovalStatus.pending,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (brand.description != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            Text(
              brand.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textBody,
              ),
            ),
          ],
          // brandKey 섹션 (V9) — rejected 제외
          if (brand.status != EntityApprovalStatus.rejected) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            BrandKeyRow(brand: brand),
          ],
        ],
      ),
    );
  }
}

/// Qoin 적립률 — 읽기 전용 카드. 이 화면 AppBar 의 `수정` 은 브랜드 정보 수정이라 적립률과 무관하다.
/// 혼동을 막기 위해 이 카드에는 어떤 수정 어피던스도 두지 않는다.
class _QoinRateCard extends StatelessWidget {
  final BrandEntity brand;
  const _QoinRateCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: QoinBrandRateInfo(
        brand: brand,
        onOpenHistory: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => QoinRateHistoryPage(
              scope: QoinRateScope.brand,
              targetId: brand.id,
              targetName: brand.name,
              viewer: QoinHistoryViewer.brand,
              brandId: brand.id,
              brandName: brand.name,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitInfoSection extends StatelessWidget {
  final BrandEntity brand;
  const _SubmitInfoSection({required this.brand});

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? dt) {
      if (dt == null) return '-';
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(label: '제출일', value: fmt(brand.submittedAt)),
          if (brand.approvedBy != null)
            _InfoRow(label: '담당자 UID', value: brand.approvedBy!),
          if (brand.approvedAt != null)
            _InfoRow(label: '처리일', value: fmt(brand.approvedAt)),
        ],
      ),
    );
  }
}

class _RejectedReasonSection extends StatelessWidget {
  final String reason;
  const _RejectedReasonSection({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
              SizedBox(width: 6),
              Text(
                '반려 사유',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reason, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `brandId` 는 있는데 브랜드 문서를 읽지 못한(없는) 계정. `BrandScaffold` 는 `brandId` 가 있을 때만 이 화면을 연다.
///
/// **등록 버튼이 없다.** 이 계정은 이미 브랜드에 연결돼 있고(문서만 사라졌다) `claimSubmittedBrand` 는 기존 연결을 덮지 않으므로,
/// 여기서 폼을 열어 저장하면 저장할 때마다 연결되지 않는 고아 브랜드만 쌓인다 (3차 F-S2). 교정은 admin 이 한다(D4).
/// 등록 폼으로 가는 길은 `BrandIdMissingView` 게이트 하나뿐이다 (가드 테스트가 lib 전체를 본다).
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
            Icon(Icons.link_off_rounded, size: 56, color: AppColors.textMuted),
            SizedBox(height: 20),
            Text(
              '연결된 브랜드를 찾지 못했어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '관리자에게 문의해 주세요. 브랜드를 다시 등록하지 않아도 돼요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textHeading)),
          const SizedBox(height: 8),
          const Text('일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center),
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
