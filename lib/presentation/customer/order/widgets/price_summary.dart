import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';

/// 소계 / 할인 / 최종 결제액 요약 위젯.
///
/// [discount] > 0 일 때만 할인 행이 표시된다.
class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    this.discount = 0,
    required this.total,
  });

  final int subtotal;
  final int discount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          label: '소계',
          value: PriceFormatter.formatKrw(subtotal),
          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          valueStyle: const TextStyle(fontSize: 13, color: AppColors.textBody),
        ),
        if (discount > 0) ...[
          const SizedBox(height: 8),
          _row(
            label: '할인',
            value: '-${PriceFormatter.formatKrw(discount)}',
            labelStyle:
                const TextStyle(fontSize: 13, color: AppColors.success),
            valueStyle:
                const TextStyle(fontSize: 13, color: AppColors.success),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(color: AppColors.border, height: 1, thickness: 1),
        const SizedBox(height: 8),
        _row(
          label: '최종 결제액',
          value: PriceFormatter.formatKrw(total),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
          valueStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ],
    );
  }

  static Widget _row({
    required String label,
    required String value,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
  }) {
    return Row(
      children: [
        Text(label, style: labelStyle),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}
