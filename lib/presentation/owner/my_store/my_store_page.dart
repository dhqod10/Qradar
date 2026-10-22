import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/grade_badge.dart';
import 'package:qradar/presentation/owner/my_store/store_core_form_page.dart';
import 'package:qradar/presentation/owner/my_store/store_operation_form_page.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';
import 'package:qradar/presentation/owner/brand_store/owner_brand_store_menus_page.dart';
import 'package:qradar/presentation/owner/store_menu/owner_store_menu_list_page.dart';
import 'package:qradar/presentation/owner/option_groups/owner_store_option_group_list_page.dart';
import 'package:qradar/presentation/owner/reviews/owner_store_reviews_page.dart';
import 'package:qradar/presentation/owner/sub_categories/owner_store_sub_category_list_page.dart';

/// 점주의 "내 매장" 탭.
///
/// - 미등록: CTA 카드
/// - 등록됨: 매장 상세 카드 + status 배지 + 두 수정 액션 분리
class MyStorePage extends ConsumerWidget {
  const MyStorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStore = ref.watch(myStoreProvider);

    return SafeArea(
      child: asyncStore.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(myStoreProvider),
        ),
        data: (store) {
          if (store == null) return const _EmptyStateView();
          return _StoreDetailView(store: store);
        },
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              '매장 정보를 불러오지 못했어요',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading),
            ),
            const SizedBox(height: 8),
            const Text(
              '일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요',
              textAlign: TextAlign.center,
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
              child: const Text('다시 시도',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 빈 상태 CTA ───────────────────────────────────────────────────────────

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceElevated, AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryBright, AppColors.primaryDeep],
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OWNER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '첫 매장을 등록해 보세요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '매장 정보를 등록하면 Qrator들이 주변에서 발견할 수 있어요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StoreCoreFormPage(),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  '매장 등록하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textHeading,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 매장 상세 ─────────────────────────────────────────────────────────────

class _StoreDetailView extends ConsumerWidget {
  final StoreEntity store;
  const _StoreDetailView({required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBrandStore = store.brandId != null && store.brandId!.isNotEmpty;

    if (isBrandStore) {
      return _BrandStoreDetailView(store: store);
    }
    return _PersonalStoreDetailView(store: store);
  }
}

// ── 개인 매장 상세 (기존 동작 그대로) ─────────────────────────────────────

class _PersonalStoreDetailView extends StatelessWidget {
  final StoreEntity store;
  const _PersonalStoreDetailView({required this.store});

  @override
  Widget build(BuildContext context) {
    final isRejected = store.status == EntityApprovalStatus.rejected;
    final isPending = store.status == EntityApprovalStatus.pending;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.background,
          pinned: false,
          elevation: 0,
          title: const Text(
            '내 매장',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _StoreHeaderCard(store: store, scopeBadge: const StoreScopeBadge.personal()),
              const SizedBox(height: 12),
              if (isRejected) ...[
                _RejectedBanner(
                  rejectedReason: store.rejectedReason,
                  onResubmit: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoreCoreFormPage(
                        existing: store,
                        isResubmit: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isPending) ...[
                _StoreStatusSection(),
                const SizedBox(height: 16),
              ],
              _StoreInfoSection(store: store),
              const SizedBox(height: 20),
              _StoreMetricsSection(store: store),
              const SizedBox(height: 20),
              _StoreActionButtons(store: store),
              const SizedBox(height: 12),
              _MenuManagementButton(store: store),
              const SizedBox(height: 8),
              _SubCategoryManagementButton(store: store),
              const SizedBox(height: 8),
              _OptionGroupManagementButton(store: store),
              const SizedBox(height: 32),
              _DangerZone(store: store),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── 브랜드 매장 상세 ──────────────────────────────────────────────────────

class _BrandStoreDetailView extends ConsumerWidget {
  final StoreEntity store;
  const _BrandStoreDetailView({required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandAsync = ref.watch(brandByIdProvider(store.brandId!));
    final brandName =
        brandAsync.asData?.value?.name ?? '브랜드 매장';

    final isRejected = store.status == EntityApprovalStatus.rejected;
    final isPending = store.status == EntityApprovalStatus.pending;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.background,
          pinned: false,
          elevation: 0,
          title: const Text(
            '내 매장',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 브랜드 매장 표시: 'ABCD 강남점' 형태로 결합 (브랜드명 + 지점명)
              _StoreHeaderCard(
                store: store.copyWith(
                  name: brandName.isEmpty
                      ? store.name
                      : '$brandName ${store.name}',
                ),
                scopeBadge: StoreScopeBadge.brand(brandName),
              ),
              const SizedBox(height: 12),
              const _BrandStoreInfoBanner(),
              const SizedBox(height: 12),
              if (isRejected) ...[
                _BrandRejectedBanner(rejectedReason: store.rejectedReason),
                const SizedBox(height: 16),
              ],
              if (isPending) ...[
                _StoreStatusSection(),
                const SizedBox(height: 16),
              ],
              _StoreInfoSection(store: store),
              const SizedBox(height: 20),
              _StoreMetricsSection(store: store),
              const SizedBox(height: 20),
              _BrandStoreActionButtons(store: store),
              if (store.status == EntityApprovalStatus.approved) ...[
                const SizedBox(height: 12),
                _BrandMenuManagementButton(store: store),
              ],
              const SizedBox(height: 32),
              _DangerZone(store: store),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── 매장 헤더 카드 (ApprovalStatusBadge 추가) ─────────────────────────────

class _StoreHeaderCard extends StatelessWidget {
  final StoreEntity store;
  final Widget? scopeBadge;
  const _StoreHeaderCard({required this.store, this.scopeBadge});

  @override
  Widget build(BuildContext context) {
    final isRevision =
        store.approvedAt != null && store.status == EntityApprovalStatus.pending;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (store.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: store.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.surface),
                errorWidget: (_, _, _) => const _ImageFallback(),
              )
            else
              const _ImageFallback(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name.isEmpty ? '이름 없음' : store.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (scopeBadge != null) ...[
                          scopeBadge!,
                          const SizedBox(width: 6),
                        ],
                        ...store.menuCategories.take(3).map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _CategoryChip(label: c),
                              ),
                            ),
                        const Spacer(),
                        ApprovalStatusBadge(
                          status: store.status,
                          isRevision: isRevision,
                        ),
                        const SizedBox(width: 6),
                        GradeBadge(
                          grade: store.grade,
                          reviewCount: store.reviewCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 64,
          color: AppColors.textMuted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBright.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryBright,
        ),
      ),
    );
  }
}

// ── 반려 배너 ─────────────────────────────────────────────────────────────

class _RejectedBanner extends StatelessWidget {
  final String? rejectedReason;
  final VoidCallback onResubmit;

  const _RejectedBanner({
    required this.rejectedReason,
    required this.onResubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                '검토가 반려되었어요',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (rejectedReason != null && rejectedReason!.trim().isNotEmpty)
                ? rejectedReason!
                : '사유가 기록되지 않았어요',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: (rejectedReason != null && rejectedReason!.trim().isNotEmpty)
                  ? AppColors.textBody
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onResubmit,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: AppColors.error),
              label: const Text(
                '재제출하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 검토 대기 안내 섹션 ───────────────────────────────────────────────────

class _StoreStatusSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 16, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '검토 요청이 접수되었어요. 검토 완료까지 잠시 기다려주세요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.warning,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 매장 정보 섹션 ────────────────────────────────────────────────────────

class _StoreInfoSection extends StatelessWidget {
  final StoreEntity store;
  const _StoreInfoSection({required this.store});

  @override
  Widget build(BuildContext context) {
    final hours = store.businessHours;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: store.address.isEmpty ? '주소 미입력' : store.address,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.phone_outlined,
            text: store.phone.isEmpty ? '전화번호 미입력' : store.phone,
          ),
          if (hours != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.access_time_rounded,
              text: '매일 ${hours.openTime} ~ ${hours.closeTime}',
            ),
          ],
          if (store.description != null &&
              store.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.description_outlined,
              text: store.description!,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textBody,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 매장 지표 섹션 ────────────────────────────────────────────────────────

class _StoreMetricsSection extends StatelessWidget {
  final StoreEntity store;
  const _StoreMetricsSection({required this.store});

  @override
  Widget build(BuildContext context) {
    final unrated = store.reviewCount == 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: '등급',
              value: unrated ? '미평가' : store.grade.label,
              muted: unrated,
            ),
          ),
          _Divider(),
          Expanded(
            child: _Metric(
              label: '평균 점수',
              value: unrated ? '-' : store.averageScore.toStringAsFixed(1),
              muted: unrated,
            ),
          ),
          _Divider(),
          Expanded(
            child: _Metric(
              label: '리뷰 수',
              value: '${store.reviewCount}',
              semanticsLabel: '리뷰 수 ${store.reviewCount}개. 받은 평가 보기',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OwnerStoreReviewsPage(store: store),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.surfaceElevated);
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  /// 0건 등 값이 없을 때 `textMuted` 로 약하게 표시.
  final bool muted;

  /// non-null 이면 탭 가능 (라벨 뒤 chevron + InkWell).
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const _Metric({
    required this.label,
    required this.value,
    this.muted = false,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: muted ? AppColors.textMuted : AppColors.textHeading,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded,
                  size: 14, color: AppColors.textMuted),
            ],
          ],
        ),
      ],
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: content,
        ),
      ),
    );
  }
}

// ── 두 수정 액션 버튼 ──────────────────────────────────────────────────────

class _StoreActionButtons extends StatelessWidget {
  final StoreEntity store;
  const _StoreActionButtons({required this.store});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StoreCoreFormPage(existing: store),
                ),
              ),
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textBody),
              label: const Text(
                '매장 정보 수정',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StoreOperationFormPage(existing: store),
                ),
              ),
              icon: const Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.primary),
              label: const Text(
                '운영 정보 수정',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 위험 구역 (매장 삭제) ─────────────────────────────────────────────────

class _DangerZone extends ConsumerWidget {
  final StoreEntity store;
  const _DangerZone({required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmDelete(context, ref),
        icon: const Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color: AppColors.error,
        ),
        label: const Text(
          '매장 삭제',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '정말 삭제할까요?',
          style: TextStyle(color: AppColors.textHeading, fontSize: 17),
        ),
        content: const Text(
          '매장 정보와 연결된 이미지가 함께 삭제돼요. 되돌릴 수 없습니다.',
          style: TextStyle(color: AppColors.textBody, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;

    try {
      // imageUrls 전체 + 기존 imageUrl 삭제
      final storage = ref.read(storageDataSourceProvider);
      for (final url in store.imageUrls) {
        await storage.deleteByUrl(url);
      }
      if (store.imageUrl.isNotEmpty &&
          !store.imageUrls.contains(store.imageUrl)) {
        await storage.deleteByUrl(store.imageUrl);
      }
      await ref.read(deleteStoreUseCaseProvider).call(store.id);
    } catch (_) {
      if (!context.mounted) return;
      await showErrorDialog(context, '삭제에 실패했어요. 다시 시도해주세요');
    }
  }
}

// ── 브랜드 매장 전용 안내 배너 ────────────────────────────────────────────

class _BrandStoreInfoBanner extends StatelessWidget {
  const _BrandStoreInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.business_rounded, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '매장 핵심 정보는 브랜드 본사가 관리해요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 브랜드 매장 반려 배너 (재제출 CTA 없음) ───────────────────────────────

class _BrandRejectedBanner extends StatelessWidget {
  final String? rejectedReason;
  const _BrandRejectedBanner({required this.rejectedReason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                '검토가 반려되었어요',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (rejectedReason != null && rejectedReason!.trim().isNotEmpty)
                ? rejectedReason!
                : '사유가 기록되지 않았어요',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
                  (rejectedReason != null && rejectedReason!.trim().isNotEmpty)
                      ? AppColors.textBody
                      : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '재제출은 브랜드 본사에서 진행됩니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 메뉴 관리 CTA (개인 매장 + approved 전용, D3) ──────────────────────────

class _MenuManagementButton extends StatelessWidget {
  final StoreEntity store;
  const _MenuManagementButton({required this.store});

  @override
  Widget build(BuildContext context) {
    final isPersonalApproved = store.brandId == null &&
        store.status == EntityApprovalStatus.approved;
    if (!isPersonalApproved) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.restaurant_menu_rounded,
            size: 18, color: AppColors.onPrimary),
        label: const Text(
          '메뉴 관리',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OwnerStoreMenuListPage(store: store),
          ),
        ),
      ),
    );
  }
}

// ── 메뉴 분류 관리 CTA (개인 매장 + approved 전용, sub-phase 8) ─────────────

class _SubCategoryManagementButton extends StatelessWidget {
  final StoreEntity store;
  const _SubCategoryManagementButton({required this.store});

  @override
  Widget build(BuildContext context) {
    // brandId != null 이면 가맹점 점주 → 미노출
    final isPersonalApproved = store.brandId == null &&
        store.status == EntityApprovalStatus.approved;
    if (!isPersonalApproved) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.label_rounded,
            size: 18, color: AppColors.primary),
        label: const Text(
          '메뉴 분류 관리',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OwnerStoreSubCategoryListPage(storeId: store.id),
          ),
        ),
      ),
    );
  }
}

// ── 옵션 그룹 관리 CTA (개인 매장 + approved 전용, sub-phase 7) ───────────────

class _OptionGroupManagementButton extends StatelessWidget {
  final StoreEntity store;
  const _OptionGroupManagementButton({required this.store});

  @override
  Widget build(BuildContext context) {
    // brandId != null 이면 가맹점 점주 → 미노출
    final isPersonalApproved = store.brandId == null &&
        store.status == EntityApprovalStatus.approved;
    if (!isPersonalApproved) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.tune_rounded,
            size: 18, color: AppColors.primary),
        label: const Text(
          '옵션 그룹 관리',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OwnerStoreOptionGroupListPage(storeId: store.id),
          ),
        ),
      ),
    );
  }
}

// ── 브랜드 매장 메뉴 옵션·품절 관리 진입 (sub-phase 5 W8 / D1 — FAIL-1 해소) ──

class _BrandMenuManagementButton extends StatelessWidget {
  final StoreEntity store;
  const _BrandMenuManagementButton({required this.store});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OwnerBrandStoreMenusPage(store: store),
          ),
        ),
        icon: const Icon(
          Icons.tune_rounded,
          size: 16,
          color: AppColors.onPrimary,
        ),
        label: const Text(
          '메뉴 옵션·품절 관리',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
      ),
    );
  }
}

// ── 브랜드 매장 액션 버튼 ("운영 정보 수정" 전체 너비, "매장 정보 수정" 비노출) ──

class _BrandStoreActionButtons extends StatelessWidget {
  final StoreEntity store;
  const _BrandStoreActionButtons({required this.store});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoreOperationFormPage(existing: store),
          ),
        ),
        icon: const Icon(Icons.tune_rounded,
            size: 16, color: AppColors.primary),
        label: const Text(
          '운영 정보 수정',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
