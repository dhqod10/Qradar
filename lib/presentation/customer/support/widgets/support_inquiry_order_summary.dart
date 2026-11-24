import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';

/// 주문 요약 한 줄 (연결 주문 행 · 시트 행 · 상세 연결 주문 카드 공용). 내용만 그린다.
class SupportInquiryOrderSummary extends StatelessWidget {
  const SupportInquiryOrderSummary({
    super.key,
    required this.storeName,
    required this.pickupNumber,
    required this.totalPrice,
    required this.date,
  });

  final String storeName;
  final int? pickupNumber;
  final int totalPrice;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (pickupNumber != null) '#$pickupNumber',
      PriceFormatter.formatKrw(totalPrice),
      if (date != null) DateFormat('yyyy.MM.dd').format(date!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          storeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          parts.join(' · '),
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
