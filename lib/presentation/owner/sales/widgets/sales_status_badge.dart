import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/common/order_status_badge.dart';

/// 매출 목록용 상태 배지 4종: 완료 / 진행 중 / 환불 완료 / 취소됨.
///
/// completed / refunded / cancelled 는 [OrderStatusBadge] 에 위임하고,
/// 진행 중(paid/accepted/making/ready)만 신규 pill 이다. 글자색은
/// `primaryBright` 가 아닌 `primary` (틴트 배경 대비 확보).
class SalesStatusBadge extends StatelessWidget {
  const SalesStatusBadge({super.key, required this.status});

  final OrderStatus status;

  static const String inProgressLabel = '진행 중';

  /// 접근성 라벨용.
  static String labelOf(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return '완료';
      case OrderStatus.refunded:
        return '환불 완료';
      case OrderStatus.cancelled:
        return '취소됨';
      case OrderStatus.paid:
      case OrderStatus.accepted:
      case OrderStatus.making:
      case OrderStatus.ready:
        return inProgressLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OrderStatus.completed:
      case OrderStatus.refunded:
      case OrderStatus.cancelled:
        return OrderStatusBadge(status: status);
      case OrderStatus.paid:
      case OrderStatus.accepted:
      case OrderStatus.making:
      case OrderStatus.ready:
        return Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryBright.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: const Text(
            inProgressLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              height: 1,
            ),
          ),
        );
    }
  }
}
