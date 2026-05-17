import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_item_entity.dart';

enum OrderItemRowVariant { full, compact }

class OrderItemRow extends StatelessWidget {
  const OrderItemRow({
    super.key,
    required this.item,
    this.variant = OrderItemRowVariant.full,
  });

  final OrderItemEntity item;
  final OrderItemRowVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == OrderItemRowVariant.compact) {
      return _CompactRow(item: item);
    }
    return _FullRow(item: item);
  }
}

class _FullRow extends StatelessWidget {
  const _FullRow({required this.item});
  final OrderItemEntity item;

  @override
  Widget build(BuildContext context) {
    final optionStr = item.selectedOptions
        .map((o) => o.label)
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Thumbnail(imageUrl: item.imageUrl),
        const SizedBox(width: 12),
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
              if (optionStr.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  optionStr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '×${item.quantity}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
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
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.item});
  final OrderItemEntity item;

  @override
  Widget build(BuildContext context) {
    final optionStr = item.selectedOptions
        .map((o) => o.label)
        .where((s) => s.isNotEmpty)
        .join(', ');

    final label = optionStr.isNotEmpty
        ? '${item.menuItemName} ($optionStr)'
        : item.menuItemName;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
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
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, e, st) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surface,
      child: const Icon(
        Icons.image_not_supported,
        size: 20,
        color: AppColors.textMuted,
      ),
    );
  }
}
