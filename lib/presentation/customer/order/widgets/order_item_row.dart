import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_item_entity.dart';

/// 단일 주문 라인 표시 위젯.
///
/// [compact] = true → CheckoutSummaryCard 용 (이미지 없음, 한 줄 요약).
/// [compact] = false → OrderDetailPage 용 (이미지 + 옵션 + 수량).
class OrderItemRow extends StatelessWidget {
  const OrderItemRow({super.key, required this.item, this.compact = false});

  final OrderItemEntity item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact ? _compact() : _full();
  }

  Widget _full() {
    final optionText = item.selectedOptions.isNotEmpty
        ? item.selectedOptions.map((o) => o.label).join(', ')
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.imageUrl.isNotEmpty
              ? Image.network(
                  item.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.menuItemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeading,
                ),
              ),
              if (optionText != null)
                Text(
                  optionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '×${item.quantity}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            Text(
              PriceFormatter.formatKrw(item.lineTotal),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _compact() {
    final optionText = item.selectedOptions.isNotEmpty
        ? item.selectedOptions.map((o) => o.label).join(', ')
        : null;
    final nameWithOption = optionText != null
        ? '${item.menuItemName} · $optionText'
        : item.menuItemName;

    return Row(
      children: [
        Expanded(
          child: Text(
            nameWithOption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          PriceFormatter.formatKrw(item.lineTotal),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
      ],
    );
  }

  static Widget _imagePlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surface,
      child: const Icon(
        Icons.image_not_supported,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
  }
}
