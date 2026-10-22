import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qrator_name.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/presentation/customer/review/formatters/review_date_formatter.dart';
import 'package:qradar/presentation/customer/review/widgets/grade_tile.dart';

/// 한 Qrator 의 한 표. 읽기 전용 (탭 반응 없음).
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.isMine = false,
    DateTime? now,
  }) : _now = now;

  final ReviewEntity review;
  final bool isMine;
  final DateTime? _now;

  @override
  Widget build(BuildContext context) {
    final now = _now ?? DateTime.now();
    final name = maskedQratorName(review.userId);
    final date = formatReviewDate(
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
      now: now,
    );
    final comment = review.comment;
    final hasComment = comment != null && comment.isNotEmpty;

    return Semantics(
      container: true,
      label:
          '${isMine ? '내 평가, ' : ''}${review.grade.label}, $name, $date'
          '${hasComment ? ', $comment' : ''}',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMine ? AppColors.primary : AppColors.border,
              width: isMine ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradeTile(grade: review.grade, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHeading,
                                ),
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '내 평가',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasComment) ...[
                const SizedBox(height: 12),
                Text(
                  comment,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textBody,
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
