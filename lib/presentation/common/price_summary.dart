import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';

class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    this.discount,
    required this.totalPrice,
  });

  final int subtotal;
  final int? discount;
  final int totalPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          label: '소계',
          value: PriceFormatter.formatKrw(subtotal),
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          valueStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textBody,
          ),
        ),
        if (discount != null && discount! > 0) ...[
          const SizedBox(height: 8),
          _Row(
            label: '할인',
            value: '-${PriceFormatter.formatKrw(discount!)}',
            labelStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.success,
            ),
            valueStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.success,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(color: AppColors.border, height: 1, thickness: 1),
        const SizedBox(height: 8),
        _Row(
          label: '최종 결제액',
          value: PriceFormatter.formatKrw(totalPrice),
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
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
