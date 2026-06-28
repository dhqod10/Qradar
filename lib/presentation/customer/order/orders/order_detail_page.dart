import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/checkout/widgets/receipt_web_view.dart';
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
        loading: () => _OrderDetailShimmer(),
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
  static final _timeFormat = DateFormat('HH:mm');

  /// 진행 인디케이터 노출 조건 — cancelled / refunded 가 아닌 모든 status.
  static bool _showProgressIndicator(OrderStatus status) {
    return status != OrderStatus.cancelled && status != OrderStatus.refunded;
  }

  /// 환불 요청이 "진행 중" 인지 (요청 존재 + 거절되지 않음 + 아직 환불 완료 안됨).
  static bool _isRefundRequestActive(OrderEntity order) {
    final req = order.refundRequest;
    if (req == null) return false;
    if (req.deniedAt != null) return false;
    if (order.status == OrderStatus.refunded) return false;
    return true;
  }

  /// 환불 요청이 점주에게 거절된 상태인지.
  static bool _isRefundRequestDenied(OrderEntity order) {
    final req = order.refundRequest;
    if (req == null) return false;
    if (order.status == OrderStatus.refunded) return false;
    return req.deniedAt != null;
  }

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
          if (_showProgressIndicator(order.status)) ...[
            _OrderProgressIndicator(order: order, timeFormat: _timeFormat),
            const SizedBox(height: 16),
          ],
          if (order.status == OrderStatus.cancelled && order.cancelInfo != null) ...[
            _CancelInfoSection(order: order, dateFormat: _dateFormat),
            const SizedBox(height: 16),
          ],
          if (_isRefundRequestActive(order)) ...[
            _RefundRequestStatusSection(order: order, dateFormat: _dateFormat),
            const SizedBox(height: 16),
          ],
          if (_isRefundRequestDenied(order)) ...[
            _RefundDeniedSection(order: order, dateFormat: _dateFormat),
            const SizedBox(height: 16),
          ],
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
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ReceiptWebView(receiptUrl: info.receiptUrl!),
                ));
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
          height: 48,
          child: OutlinedButton(
            onPressed: isLoading ? null : onCancelOrder,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              foregroundColor: AppColors.error,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
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
        final req = order.refundRequest;
        final hasActiveRefundRequest = req != null && req.deniedAt == null;
        final isRefundDenied = req != null && req.deniedAt != null;
        if (hasActiveRefundRequest || isRefundDenied) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              hasActiveRefundRequest
                  ? '환불 요청 중입니다'
                  : '환불이 거절되어 더 이상 요청할 수 없어요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          );
        }
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

      // U7: 조리 시작 후 환불 요청 불가 안내 카드
      case OrderStatus.making:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '조리가 시작되어 환불 요청이 어려워요',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        );

      // U7: 음료 준비 완료 후 환불 요청 불가 안내 카드
      case OrderStatus.ready:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '음료 준비가 완료되어 환불 요청이 어려워요',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ),
            ],
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

// ── Cancel Info Section ───────────────────────────────────────────────────────

class _CancelInfoSection extends StatelessWidget {
  const _CancelInfoSection({required this.order, required this.dateFormat});

  final OrderEntity order;
  final DateFormat dateFormat;

  String get _approvedByLabel {
    switch (order.cancelInfo?.approvedBy) {
      case 'customer':
        return '고객 직접 취소';
      case 'owner':
        return '매장 거절';
      default:
        return '취소됨';
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = order.cancelInfo!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 6),
              Text(
                _approvedByLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '사유',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            info.reason,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            dateFormat.format(info.cancelledAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Refund Denied Section ─────────────────────────────────────────────────────

class _RefundDeniedSection extends StatelessWidget {
  const _RefundDeniedSection({
    required this.order,
    required this.dateFormat,
  });

  final OrderEntity order;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final req = order.refundRequest!;
    final deniedReason = req.deniedReason;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.do_not_disturb_on_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 6),
              const Text(
                '환불 요청이 거절되었어요',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          if (deniedReason != null && deniedReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '매장 답변',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              deniedReason,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textBody,
                height: 1.4,
              ),
            ),
          ],
          if (req.deniedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              '거절 ${dateFormat.format(req.deniedAt!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Refund Request Status Section ─────────────────────────────────────────────

class _RefundRequestStatusSection extends StatelessWidget {
  const _RefundRequestStatusSection({
    required this.order,
    required this.dateFormat,
  });

  final OrderEntity order;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final req = order.refundRequest!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '환불 요청 중',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '요청 사유',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            req.reason,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '요청 ${dateFormat.format(req.requestedAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          const Text(
            '매장 승인 후 환불이 진행됩니다',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Detail Shimmer ────────────────────────────────────────────────────────────

class _OrderDetailShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 뱃지 + 주문번호 섹션
          _shimmerBox(height: 100, radius: 16),
          const SizedBox(height: 16),
          // 진행 인디케이터 placeholder
          _shimmerBox(height: 88, radius: 16),
          const SizedBox(height: 16),
          // 매장명 섹션
          _shimmerBox(height: 72, radius: 16),
          const SizedBox(height: 16),
          // 아이템 행 3개
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 15, width: 60, radius: 6),
                const SizedBox(height: 14),
                _shimmerBox(height: 13, radius: 6),
                const SizedBox(height: 10),
                _shimmerBox(height: 13, radius: 6),
                const SizedBox(height: 10),
                _shimmerBox(height: 13, radius: 6),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 가격 요약
          _shimmerBox(height: 80, radius: 16),
        ],
      ),
    );
  }

  static Widget _shimmerBox({
    required double height,
    double? width,
    double radius = 8,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

// ── Order Progress Indicator ──────────────────────────────────────────────────

enum _StepState { completed, current, upcoming }

class _OrderProgressIndicator extends StatelessWidget {
  const _OrderProgressIndicator({
    required this.order,
    required this.timeFormat,
  });

  final OrderEntity order;
  final DateFormat timeFormat;

  static const _labels = ['접수', '조리', '준비', '픽업'];
  static const _icons = [
    Icons.receipt_long_rounded,
    Icons.local_fire_department_rounded,
    Icons.check_circle_outline_rounded,
    Icons.shopping_bag_outlined,
  ];

  _StepState _stepState(int index) {
    final timestamps = [
      order.acceptedAt,
      order.makingStartedAt,
      order.readyAt,
      order.completedAt,
    ];
    if (timestamps[index] != null) return _StepState.completed;
    // paid 상태에서 단계 0 은 "현재(예고)" — 나머지 모두 upcoming
    if (index == 0) return _StepState.current;
    if (timestamps[index - 1] != null) return _StepState.current;
    return _StepState.upcoming;
  }

  bool _lineCompleted(int lineIndex) {
    final timestamps = [order.acceptedAt, order.makingStartedAt, order.readyAt];
    return timestamps[lineIndex] != null;
  }

  DateTime? _timestamp(int index) {
    return [
      order.acceptedAt,
      order.makingStartedAt,
      order.readyAt,
      order.completedAt,
    ][index];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문 진행',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          // 스테퍼 Row — 아이콘 + 연결선
          Row(
            children: [
              _buildStepNode(0),
              Expanded(child: _buildStepLine(0)),
              _buildStepNode(1),
              Expanded(child: _buildStepLine(1)),
              _buildStepNode(2),
              Expanded(child: _buildStepLine(2)),
              _buildStepNode(3),
            ],
          ),
          const SizedBox(height: 8),
          // 라벨 + 타임스탬프 Row
          Row(
            children: [
              SizedBox(width: 40, child: _buildStepLabel(0)),
              const Spacer(),
              SizedBox(width: 40, child: _buildStepLabel(1)),
              const Spacer(),
              SizedBox(width: 40, child: _buildStepLabel(2)),
              const Spacer(),
              SizedBox(width: 40, child: _buildStepLabel(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index) {
    final state = _stepState(index);
    final Color bgColor;
    final Color? borderColor;
    final IconData icon;
    final Color iconColor;
    final double iconSize;

    switch (state) {
      case _StepState.completed:
        bgColor = AppColors.success;
        borderColor = null;
        icon = Icons.check_rounded;
        iconColor = AppColors.onPrimary;
        iconSize = 16;
      case _StepState.current:
        bgColor = AppColors.primary;
        borderColor = null;
        icon = _icons[index];
        iconColor = AppColors.onPrimary;
        iconSize = 16;
      case _StepState.upcoming:
        bgColor = AppColors.surface;
        borderColor = AppColors.border;
        icon = _icons[index];
        iconColor = AppColors.textMuted;
        iconSize = 14;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }

  Widget _buildStepLine(int lineIndex) {
    return Container(
      height: 2,
      color: _lineCompleted(lineIndex) ? AppColors.success : AppColors.border,
    );
  }

  Widget _buildStepLabel(int index) {
    final state = _stepState(index);
    final ts = _timestamp(index);
    final isActive = state == _StepState.completed || state == _StepState.current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _labels[index],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.textHeading : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          ts != null ? timeFormat.format(ts) : '-',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: ts != null ? AppColors.textMuted : AppColors.border,
          ),
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
