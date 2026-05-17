import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/brand/brand_info/brand_info_form_page.dart';
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
                      ? Image.network(brand.logoUrl, fit: BoxFit.cover)
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
            _BrandKeyRow(brand: brand),
          ],
        ],
      ),
    );
  }
}

class _BrandKeyRow extends StatelessWidget {
  final BrandEntity brand;
  const _BrandKeyRow({required this.brand});

  @override
  Widget build(BuildContext context) {
    final isApprovedWithKey = brand.status == EntityApprovalStatus.approved &&
        brand.brandKey.isNotEmpty;

    if (isApprovedWithKey) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '브랜드 키',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      brand.brandKey,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                tooltip: '복사',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: brand.brandKey),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('복사됐어요'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '이 키를 점주에게 공유하면 가맹점 등록 시 사용할 수 있어요',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    // pending 또는 brandKey 비어있음
    return const Row(
      children: [
        Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.textMuted),
        SizedBox(width: 8),
        Text(
          '관리자 승인 후 브랜드 키가 발급됩니다',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          const Text(
            '아직 브랜드가 등록되지 않았어요',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textHeading),
          ),
          const SizedBox(height: 8),
          const Text(
            '브랜드를 등록하고 마스터 메뉴를 관리해보세요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrandInfoFormPage(brand: null)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('브랜드 등록하기',
                style: TextStyle(fontWeight: FontWeight.w600)),
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
