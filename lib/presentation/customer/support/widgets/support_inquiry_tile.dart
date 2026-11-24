import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';
import 'package:qradar/domain/entities/support_inquiry_status.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_status_badge.dart';

/// 문의 목록 타일. 미확인 답변([SupportInquiryEntity.hasUnreadAnswer])이면 dot + 강조 border.
class SupportInquiryTile extends StatelessWidget {
  const SupportInquiryTile({super.key, required this.inquiry, this.onTap});

  final SupportInquiryEntity inquiry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = inquiry.hasUnreadAnswer;
    final dimmed =
        inquiry.status == SupportInquiryStatus.closed ||
        inquiry.status == SupportInquiryStatus.withdrawn;
    final firstLine = inquiry.body.split('\n').first;
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? AppColors.primaryBright.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    inquiry.category.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Text(
                    ' · ',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    DateFormat('yyyy.MM.dd').format(inquiry.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  SupportInquiryStatusBadge(status: inquiry.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (unread) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      inquiry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        color: dimmed
                            ? AppColors.textMuted
                            : AppColors.textHeading,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                firstLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: dimmed ? AppColors.textMuted : AppColors.textBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
