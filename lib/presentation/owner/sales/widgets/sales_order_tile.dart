import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/sales_period.dart';
import 'package:qradar/presentation/owner/orders/owner_order_detail_page.dart';
import 'package:qradar/presentation/owner/sales/formatters/sales_formatters.dart';
import 'package:qradar/presentation/owner/sales/widgets/sales_status_badge.dart';

/// 매출 목록의 주문 1행 (조회 전용 컴팩트 타일). 탭 → 주문 상세.
class SalesOrderTile extends StatelessWidget {
  const SalesOrderTile({
    super.key,
    required this.order,
    required this.periodType,
  });

  final OrderEntity order;
  final SalesPeriodType periodType;

  bool get _excluded =>
      order.status == OrderStatus.refunded ||
      order.status == OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final menu = SalesFormatters.menuSummary(order);
    final amount = PriceFormatter.formatKrw(order.totalPrice);
    final badge = SalesStatusBadge.labelOf(order.status);
    final semantic =
        '${SalesFormatters.orderTimeSemantic(order.createdAt, periodType)}, '
        '${SalesFormatters.menuSummarySemantic(order)}, $amount, $badge'
        '${_excluded ? ', 총 매출에서 제외됨' : ''}. 탭하면 주문 상세';

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: semantic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.04),
          highlightColor: AppColors.primary.withValues(alpha: 0.02),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnerOrderDetailPage(orderId: order.id),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SalesFormatters.orderTime(order.createdAt, periodType),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        menu,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _excluded
                              ? AppColors.textMuted
                              : AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SalesStatusBadge(status: order.status),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        amount,
                        style: _excluded
                            ? const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textMuted,
                              )
                            : const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHeading,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
