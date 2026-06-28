import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/common/order_status_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final OrderEntity order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final extra = order.items.length - 1;
    final menuSummary = firstItem == null
        ? '-'
        : extra > 0
            ? '${firstItem.menuItemName} 외 ${extra}개' // ignore: unnecessary_brace_in_string_interps
            : firstItem.menuItemName;

    final refundBadge = _refundBadgeFor(order);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha((0.04 * 255).round()),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeading,
                    ),
                  ),
                ),
                if (refundBadge != null) ...[
                  refundBadge,
                  const SizedBox(width: 6),
                ],
                OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    menuSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                Text(
                  PriceFormatter.formatKrw(order.totalPrice),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _relativeTime(order.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  /// 환불 요청 상태에 따른 보조 배지. status badge 옆에 함께 표시.
  /// - 진행 중: "환불 요청 중" (primary)
  /// - 거절됨: "환불 거절" (error)
  /// - 그 외: null (표시 안 함)
  static Widget? _refundBadgeFor(OrderEntity order) {
    if (order.status == OrderStatus.refunded) return null;
    final req = order.refundRequest;
    if (req == null) return null;
    if (req.deniedAt != null) {
      return const _OrderCardSubBadge(
        label: '환불 거절',
        color: AppColors.error,
      );
    }
    return const _OrderCardSubBadge(
      label: '환불 요청 중',
      color: AppColors.primary,
    );
  }
}

class _OrderCardSubBadge extends StatelessWidget {
  const _OrderCardSubBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
