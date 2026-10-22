import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/usecases/get_store_reviews_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/review/providers/store_review_providers.dart';
import 'package:qradar/presentation/customer/review/widgets/review_card.dart';

/// 매장 평가 목록 본문. 고객/점주 화면이 공유한다.
///
/// - [showMine]: 고객 화면에서만 true (최상단 `내 평가` 섹션).
/// - [showAverage]: **점주 화면에서만 true**. 고객 화면은 등급 + 건수만 노출한다
///   (`store.averageScore` 는 받지만 표시하지 않음).
class StoreReviewsView extends ConsumerWidget {
  const StoreReviewsView({
    super.key,
    required this.store,
    this.showMine = true,
    this.showAverage = false,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final StoreEntity store;
  final bool showMine;
  final bool showAverage;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(storeReviewsProvider(store.id));
    final myReview = showMine
        ? ref.watch(myStoreReviewProvider(store.id)).asData?.value
        : null;
    final uid = ref.watch(authProvider).asData?.value?.uid;

    final all = reviewsAsync.asData?.value;
    final captionVisible =
        all != null &&
        all.length < GetStoreReviewsUseCase.defaultLimit &&
        all.length != store.reviewCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _ReviewSummaryCard(
          store: store,
          showAverage: showAverage,
          showSyncCaption: captionVisible,
        ),
        ...reviewsAsync.when(
          loading: () => const [_ListSkeleton()],
          error: (_, _) => [
            _ErrorBlock(
              onRetry: () => ref.invalidate(storeReviewsProvider(store.id)),
            ),
          ],
          data: (list) => _buildList(list, myReview, uid),
        ),
      ],
    );
  }

  List<Widget> _buildList(
    List<ReviewEntity> list,
    ReviewEntity? mine,
    String? uid,
  ) {
    final others = (showMine && uid != null)
        ? list.where((r) => r.userId != uid).toList(growable: false)
        : list;

    if (list.isEmpty && mine == null) {
      return [_EmptyBlock(title: emptyTitle, description: emptyDescription)];
    }

    final now = DateTime.now();
    return [
      if (showMine && mine != null) ...[
        const _SectionTitle('내 평가'),
        ReviewCard(review: mine, isMine: true, now: now),
      ],
      if (others.isNotEmpty) ...[
        _SectionTitle('전체 평가 ${store.reviewCount}개'),
        for (final r in others) ...[
          ReviewCard(review: r, now: now),
          const SizedBox(height: 10),
        ],
      ],
      if (list.length >= GetStoreReviewsUseCase.defaultLimit)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Center(
            child: Text(
              '최근 50개 평가를 보여드려요',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.store,
    required this.showAverage,
    required this.showSyncCaption,
  });

  final StoreEntity store;
  final bool showAverage;
  final bool showSyncCaption;

  @override
  Widget build(BuildContext context) {
    final unrated = store.reviewCount == 0;
    final subtitle = unrated
        ? '아직 평가가 없어요'
        : showAverage
        ? 'Qrator 평가 ${store.reviewCount}개 · 평균 ${store.averageScore.toStringAsFixed(1)} / 4'
        : 'Qrator 평가 ${store.reviewCount}개';
    final semanticsLabel = unrated
        ? '${store.name}, 아직 평가가 없는 매장'
        : showAverage
        ? '${store.name}, ${store.grade.label}, Qrator 평가 ${store.reviewCount}개, '
              '평균 ${store.averageScore.toStringAsFixed(1)}점 만점 4점'
        : '${store.name}, ${store.grade.label}, Qrator 평가 ${store.reviewCount}개';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                unrated ? '미평가' : store.grade.label,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: unrated ? AppColors.textMuted : AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: unrated ? AppColors.textMuted : AppColors.textBody,
                ),
              ),
              if (showSyncCaption) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '방금 남긴 평가는 등급에 곧 반영돼요',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            '평가를 불러오지 못했어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '네트워크 연결을 확인하고 다시 시도해 주세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ),
        ],
      ),
    );
  }
}

/// static skeleton (shimmer 애니메이션 없음).
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '평가를 불러오는 중',
      child: ExcludeSemantics(
        child: Column(
          children: [
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++) ...[
              const _SkeletonCard(),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  Widget _box(double? w, double h, {double r = 6}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              _box(28, 28, r: 8),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(100, 13),
                  const SizedBox(height: 6),
                  _box(60, 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _box(null, 13),
          const SizedBox(height: 6),
          _box(200, 13),
        ],
      ),
    );
  }
}
