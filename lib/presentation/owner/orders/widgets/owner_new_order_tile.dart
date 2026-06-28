import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/common/order_status_badge.dart';

/// 신규(paid) 주문 카드 타일.
///
/// [onTapDetail] 이 null 이 아니면 카드 영역 탭 시 상세 페이지로 이동한다.
/// 버튼 탭은 Flutter hit test 가 자식 우선 처리하므로 자동으로 카드 onTap 과 분리된다.
class OwnerNewOrderTile extends StatelessWidget {
  const OwnerNewOrderTile({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
    this.isLoading = false,
    this.onTapDetail,
  });

  final OrderEntity order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isLoading;

  /// 카드 전체 탭 콜백 (버튼 영역 제외). null 이면 탭 비활성.
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###원', 'ko_KR');
    final timeFmt = DateFormat('MM/dd HH:mm');
    final itemSummary = _buildItemSummary();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTapDetail,
        splashColor: AppColors.primary.withValues(alpha: 0.04),
        highlightColor: AppColors.primary.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timeFmt.format(order.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              const OrderStatusBadge(
                status: OrderStatus.paid,
                size: OrderStatusBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            itemSummary,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(order.totalPrice),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text(
                            '주문 받기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 40,
                child: OutlinedButton(
                  onPressed: isLoading ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    backgroundColor: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '거절',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  String _buildItemSummary() {
    if (order.items.isEmpty) return '항목 없음';
    final first = order.items.first.menuItemName;
    if (order.items.length == 1) return first;
    return '$first 외 ${order.items.length - 1}개';
  }
}
