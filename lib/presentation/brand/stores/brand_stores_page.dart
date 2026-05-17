import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/brand/customization/brand_store_customization_page.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_store_management_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 브랜드가 운영하는 가맹점 목록 (read-only).
///
/// V6: brand 는 매장을 직접 등록하지 않는다. 점주가 등록한 가맹점을 조회하고
/// 커스텀(가격 오버라이드 / 점포 한정 메뉴) 진입만 한다.
class BrandStoresPage extends ConsumerWidget {
  const BrandStoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(brandStoresProvider);
    final brandAsync = ref.watch(myBrandProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final brandId = profile?.brandId ?? '';

    final brandName = brandAsync.asData?.value?.name ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '가맹점',
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
        data: (stores) {
          if (stores.isEmpty) {
            return const _EmptyView();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: stores.length + 1,
            itemBuilder: (context, index) {
              if (index == stores.length) {
                return const SizedBox(height: 40);
              }
              final store = stores[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BrandStoreCard(
                  store: store,
                  brandName: brandName,
                  brandId: brandId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── 매장 카드 ──────────────────────────────────────────────────────────────

class _BrandStoreCard extends StatelessWidget {
  final StoreEntity store;
  final String brandName;
  final String brandId;

  const _BrandStoreCard({
    required this.store,
    required this.brandName,
    required this.brandId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BrandStoreCustomizationPage(store: store),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 행 1: 매장명 + 승인 배지
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ApprovalStatusBadge(
                    status: store.status,
                    isRevision: store.approvedAt != null &&
                        store.status.name == 'pending',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 행 2: 주소
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      store.address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 행 3: scope 배지 + 커스텀 관리 링크
              Row(
                children: [
                  if (brandName.isNotEmpty)
                    StoreScopeBadge.brand(brandName)
                  else
                    const StoreScopeBadge.personal(),
                  const Spacer(),
                  const Row(
                    children: [
                      Text(
                        '커스텀 관리',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryBright,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.primaryBright,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 56,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 16),
          Text(
            '아직 등록된 가맹점이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '점주가 브랜드 키를 입력해 매장을 등록하면\n여기에 표시됩니다',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 로딩 상태 (shimmer skeleton) ──────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 3,
      itemBuilder: (context, i) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

// ── 에러 뷰 ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          const Text(
            '가맹점 목록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
