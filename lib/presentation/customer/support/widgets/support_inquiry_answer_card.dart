import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/support_inquiry_entity.dart';

/// 관리자 답변 카드 — 내 문의 카드(중립)와 구분되는 네이비 포인트 톤.
class SupportInquiryAnswerCard extends StatelessWidget {
  const SupportInquiryAnswerCard({super.key, required this.answer});

  final SupportInquiryAnswer answer;

  @override
  Widget build(BuildContext context) {
    final at = answer.answeredAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_outlined,
                  size: 18,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Qradar 고객센터',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
              if (at != null)
                Text(
                  DateFormat('yyyy.MM.dd').format(at),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            answer.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}
