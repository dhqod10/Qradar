import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/common/order_status_badge.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_view_providers.dart';
import 'package:qradar/presentation/customer/order/widgets/order_item_row.dart';
import 'package:qradar/presentation/customer/order/widgets/price_summary.dart';
import 'package:qradar/presentation/customer/order/widgets/refund_request_sheet.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(currentOrderProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '주문 상세',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textHeading),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentOrderProvider(widget.orderId)),
        ),
        data: (order) {
          if (order == null) {
            return const Center(
              child: Text(
                '주문을 찾을 수 없습니다',
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
            );
          }
          return _OrderDetailBody(
            order: order,
            isActionLoading: _isActionLoading,
            onCancelOrder: () => _handleCancelOrder(order),
            onRefundRequest: () => _handleRefundRequest(order),
          );
        },
      ),
    );
  }

  Future<void> _handleCancelOrder(OrderEntity order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CancelOrderDialog(
        isLoading: _isActionLoading,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final useCase = ref.read(cancelPaidOrderUseCaseProvider);
      await useCase(
        orderId: order.id,
        reason: '고객 취소 요청',
        approvedBy: 'customer',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주문이 취소되었습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('취소 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRefundRequest(OrderEntity order) async {
    final result = await RefundRequestSheet.show(context);
    if (result == null) return;
    if (!mounted) return;

    setState(() => _isActionLoading = true);
    try {
      final useCase = ref.read(requestRefundUseCaseProvider);
      await useCase(orderId: order.id, reason: result.reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환불 요청이 접수되었습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('환불 요청 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({
    required this.order,
    required this.isActionLoading,
    required this.onCancelOrder,
    required this.onRefundRequest,
  });

  final OrderEntity order;
  final bool isActionLoading;
  final VoidCallback onCancelOrder;
  final VoidCallback onRefundRequest;

  static final _dateFormat = DateFormat('yyyy.MM.dd HH:mm', 'ko');

  String get _shortOrderId {
    final id = order.id;
    if (id.length <= 12) return id;
    return '${id.substring(0, 12)}...';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusSection(order: order, shortId: _shortOrderId, dateFormat: _dateFormat),
          const SizedBox(height: 16),
          _StoreSection(storeName: order.storeName),
          const SizedBox(height: 16),
          _ItemsSection(order: order),
          const SizedBox(height: 16),
          _PriceSection(order: order),
          const SizedBox(height: 16),
          _PaymentInfoSection(order: order),
          const SizedBox(height: 24),
          _ActionSection(
            order: order,
            isLoading: isActionLoading,
            onCancelOrder: onCancelOrder,
            onRefundRequest: onRefundRequest,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Status Section ────────────────────────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.order,
    required this.shortId,
    required this.dateFormat,
  });

  final OrderEntity order;
  final String shortId;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderStatusBadge(
            status: order.status,
            size: OrderStatusBadgeSize.large,
          ),
          const SizedBox(height: 12),
          Text(
            '주문번호 $shortId',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateFormat.format(order.createdAt),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Store Section ─────────────────────────────────────────────────────────────

class _StoreSection extends StatelessWidget {
  const _StoreSection({required this.storeName});
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매장',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            storeName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Items Section ─────────────────────────────────────────────────────────────

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.order});
  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문 내역',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderItemRow(item: item),
              )),
        ],
      ),
    );
  }
}

// ── Price Section ─────────────────────────────────────────────────────────────

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.order});
  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: PriceSummary(
        subtotal: order.subtotal,
        discount: order.discount ?? 0,
        total: order.totalPrice,
      ),
    );
  }
}

// ── Payment Info Section ──────────────────────────────────────────────────────

class _PaymentInfoSection extends StatelessWidget {
  const _PaymentInfoSection({required this.order});
  final OrderEntity order;

  String _maskedKey(String key) {
    if (key.length <= 4) return key;
    return '****${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final info = order.paymentInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '결제 정보',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow('결제 수단', info.method.label),
          const SizedBox(height: 8),
          _infoRow('결제 키', _maskedKey(info.paymentKey)),
          if (info.receiptUrl != null && info.receiptUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(info.receiptUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                '영수증 보기',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          if (info.cardCompany != null && info.cardCompany!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow('카드사', info.cardCompany!),
          ],
          if (info.cardNumberMasked != null &&
              info.cardNumberMasked!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow('카드번호', info.cardNumberMasked!),
          ],
          const SizedBox(height: 8),
          _infoRow('결제 금액', PriceFormatter.formatKrw(info.amount)),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.textBody),
        ),
      ],
    );
  }
}

// ── Action Section ────────────────────────────────────────────────────────────

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.order,
    required this.isLoading,
    required this.onCancelOrder,
    required this.onRefundRequest,
  });

  final OrderEntity order;
  final bool isLoading;
  final VoidCallback onCancelOrder;
  final VoidCallback onRefundRequest;

  @override
  Widget build(BuildContext context) {
    switch (order.status) {
      case OrderStatus.paid:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: isLoading ? null : onCancelOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.surface,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text(
                    '주문 취소',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        );

      case OrderStatus.accepted:
      case OrderStatus.making:
      case OrderStatus.ready:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: isLoading ? null : onRefundRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor: AppColors.surface,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text(
                    '환불 요청',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        );

      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            switch (order.status) {
              OrderStatus.cancelled => '취소된 주문입니다',
              OrderStatus.refunded => '환불 처리된 주문입니다',
              _ => '완료된 주문입니다',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        );
    }
  }
}

// ── Cancel Order Dialog ───────────────────────────────────────────────────────

class _CancelOrderDialog extends StatelessWidget {
  const _CancelOrderDialog({
    required this.isLoading,
    required this.onConfirm,
    required this.onCancel,
  });

  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '주문을 취소하시겠어요?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
      content: const Text(
        '취소하면 결제가 자동 환불됩니다.',
        style: TextStyle(fontSize: 14, color: AppColors.textBody),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textBody,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('아니요'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
                      : const Text('주문 취소'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Error Body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
