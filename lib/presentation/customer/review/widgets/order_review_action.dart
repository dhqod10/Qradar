import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/review_window.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/presentation/customer/review/providers/store_review_providers.dart';
import 'package:qradar/presentation/customer/review/store_review_form_page.dart';
import 'package:qradar/presentation/customer/review/widgets/grade_copy.dart';
import 'package:qradar/presentation/customer/review/widgets/grade_tile.dart';

/// `completed` 주문 상세의 매장 평가 액션 카드.
///
/// 상태: A 평가 전 / B 평가 후 / C 기한 만료(C-1 평가 없음, C-2 평가 있음) / 로딩 / 에러.
/// `myReview` 는 **주문이 아니라 매장 기준** (같은 매장 다른 주문에서도 "수정" 으로 보임).
class OrderReviewAction extends ConsumerWidget {
  const OrderReviewAction({super.key, required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAsync = ref.watch(myStoreReviewProvider(order.storeId));
    final now = DateTime.now();
    final expired = ReviewWindow.isExpired(order.completedAt, now);

    return myAsync.when(
      // 값이 오기 전에는 버튼을 그리지 않는다 (라벨 깜빡임 방지).
      loading: () => Container(
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, _) => _ErrorCard(
        onRetry: () => ref.invalidate(myStoreReviewProvider(order.storeId)),
      ),
      data: (mine) {
        if (expired && mine == null) return const _ExpiredInfoCard();
        return _ReviewCard(
          order: order,
          mine: mine,
          expired: expired,
          now: now,
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.order,
    required this.mine,
    required this.expired,
    required this.now,
  });

  final OrderEntity order;
  final ReviewEntity? mine;
  final bool expired;
  final DateTime now;

  Future<void> _openForm(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<StoreReviewFormResult>(
      MaterialPageRoute(
        builder: (_) => StoreReviewFormPage(order: order, existingReview: mine),
      ),
    );
    if (result == null) return;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          result == StoreReviewFormResult.created
              ? '평가가 등록됐어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요'
              : '평가를 수정했어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = mine;
    final caption = expired
        ? null
        : ReviewWindow.countdownCaption(order.completedAt, now);
    final comment = review?.comment;

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
          if (review == null) ...[
            const Text(
              '이 매장은 어땠나요?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Qrator 의 평가가 매장 등급을 만들어요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: '매장 평가하기',
              filled: true,
              onPressed: () => _openForm(context),
            ),
          ] else ...[
            Semantics(
              container: true,
              label:
                  '이 매장에 남긴 내 평가, ${review.grade.label} '
                  '${review.grade.reviewName}'
                  '${(comment != null && comment.isNotEmpty) ? ', $comment' : ''}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이 매장에 남긴 내 평가',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GradeTile(grade: review.grade, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${review.grade.label} · ${review.grade.reviewName}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (expired)
              const Center(
                child: Text(
                  '수정 기간(14일)이 지났어요',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              _ActionButton(
                label: '평가 수정',
                filled: false,
                onPressed: () => _openForm(context),
              ),
          ],
          if (caption != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                caption,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: filled
              ? AppColors.primary
              : AppColors.surfaceElevated,
          foregroundColor: filled ? AppColors.onPrimary : AppColors.textBody,
          side: filled ? null : const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ExpiredInfoCard extends StatelessWidget {
  const _ExpiredInfoCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '평가 기간 14일이 지났어요',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '평가 기간(14일)이 지났어요',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '평가 정보를 불러오지 못했어요',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.primary,
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
