import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_item_entity.dart';
import 'package:qradar/presentation/common/order_item_row.dart';

class CheckoutSummaryCard extends StatelessWidget {
  const CheckoutSummaryCard({
    super.key,
    required this.storeName,
    required this.items,
    required this.totalPrice,
  });

  final String storeName;
  final List<OrderItemEntity> items;
  final int totalPrice;

  @override
  Widget build(BuildContext context) {
    const maxVisible = 3;
    final visible = items.take(maxVisible).toList();
    final extra = items.length - maxVisible;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            storeName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 10),
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OrderItemRow(
                item: item,
                variant: OrderItemRowVariant.compact,
              ),
            ),
          ),
          if (extra > 0)
            Text(
              '외 $extra개',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1, thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '합계',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                PriceFormatter.formatKrw(totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
