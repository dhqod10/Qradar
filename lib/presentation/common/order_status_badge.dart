import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/order_status.dart';

enum OrderStatusBadgeSize { small, large }

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.status,
    this.size = OrderStatusBadgeSize.small,
  });

  final OrderStatus status;
  final OrderStatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _config(status);
    final double height;
    final double fontSize;
    final double hPad;
    final FontWeight fw;

    switch (size) {
      case OrderStatusBadgeSize.small:
        height = 22;
        fontSize = 11;
        hPad = 8;
        fw = FontWeight.w600;
      case OrderStatusBadgeSize.large:
        height = 32;
        fontSize = 14;
        hPad = 14;
        fw = FontWeight.w700;
    }

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fw,
          color: fg,
          height: 1,
        ),
      ),
    );
  }

  static (Color bg, Color fg, String label) _config(OrderStatus status) {
    switch (status) {
      case OrderStatus.paid:
        return (
          AppColors.primaryBright.withAlpha((0.15 * 255).round()),
          AppColors.primaryBright,
          '결제 완료',
        );
      case OrderStatus.accepted:
        return (
          AppColors.info.withAlpha((0.15 * 255).round()),
          AppColors.info,
          '접수 완료',
        );
      case OrderStatus.making:
        return (
          AppColors.warning.withAlpha((0.15 * 255).round()),
          AppColors.warning,
          '제조 중',
        );
      case OrderStatus.ready:
        return (
          AppColors.success.withAlpha((0.15 * 255).round()),
          AppColors.success,
          '픽업 대기',
        );
      case OrderStatus.completed:
        return (AppColors.surface, AppColors.textMuted, '완료');
      case OrderStatus.cancelled:
        return (
          AppColors.error.withAlpha((0.12 * 255).round()),
          AppColors.error,
          '취소됨',
        );
      case OrderStatus.refunded:
        return (
          AppColors.textMuted.withAlpha((0.15 * 255).round()),
          AppColors.textMuted,
          '환불 완료',
        );
    }
  }
}
