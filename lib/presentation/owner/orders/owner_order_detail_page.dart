import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/refund_request_entity.dart';
import 'package:qradar/presentation/common/order_status_badge.dart';
import 'package:qradar/presentation/customer/checkout/widgets/receipt_web_view.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_view_providers.dart';
import 'package:qradar/presentation/customer/order/widgets/order_item_row.dart';
import 'package:qradar/presentation/customer/order/widgets/price_summary.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_order_action_dialogs.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 점주용 주문 상세 페이지.
///
/// - FCM 알림 탭 deep link 도착점 ([NotificationNavigator] 참조)
/// - [OwnerOrdersPage] 카드 탭 도착점
///
/// 권한 가드(결정 G): [myStoreProvider].id != order.storeId 이면 fallback UI.
class OwnerOrderDetailPage extends ConsumerStatefulWidget {
  const OwnerOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OwnerOrderDetailPage> createState() =>
      _OwnerOrderDetailPageState();
}

class _OwnerOrderDetailPageState extends ConsumerState<OwnerOrderDetailPage> {
  bool _isActionLoading = false;

  // ── 헬퍼 ──────────────────────────────────────────────────────────────────

  /// sticky bottom 액션 바가 있는 status 인지 판별.
  /// - paid: 주문 받기/거절
  /// - accepted + 환불 활성: 환불 승인/거절
  /// - accepted + 환불 비활성: 조리 시작
  /// - making: 준비 완료
  /// - ready: 픽업 완료
  /// - 그 외: 없음
  bool _hasActionBar(OrderEntity order) {
    return order.status == OrderStatus.paid ||
        order.status == OrderStatus.accepted ||
        order.status == OrderStatus.making ||
        order.status == OrderStatus.ready;
  }

  // ── 액션 ──────────────────────────────────────────────────────────────────

  Future<void> _acceptOrder(String orderId) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(acceptOrderUseCaseProvider).call(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주문을 받았습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _rejectOrder(OrderEntity order) async {
    final reason = await OwnerOrderActionDialogs.showRejectOrder(context);
    if (reason == null) return;
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(cancelPaidOrderUseCaseProvider).call(
            orderId: order.id,
            reason: reason.isEmpty ? '점주 사유' : reason,
            approvedBy: 'owner',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주문을 거절했습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _approveRefund(OrderEntity order) async {
    final confirmed = await OwnerOrderActionDialogs.showApproveRefund(
      context,
      totalPrice: order.totalPrice,
    );
    if (confirmed != true) return;
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(processRefundUseCaseProvider).call(
            orderId: order.id,
            reason: order.refundRequest?.reason ?? '',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환불을 승인했습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _denyRefund(OrderEntity order) async {
    final reason = await OwnerOrderActionDialogs.showDenyRefund(context);
    if (reason == null) return;
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(denyRefundRequestUseCaseProvider).call(
            orderId: order.id,
            deniedReason: reason.isEmpty ? '점주 사유' : reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환불 요청을 거절했습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _startMaking(String orderId) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(startMakingOrderUseCaseProvider).call(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조리를 시작했습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markReady(String orderId) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(markOrderReadyUseCaseProvider).call(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('준비 완료 처리했습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _completePickup(String orderId) async {
    final confirmed = await OwnerOrderActionDialogs.showCompletePickup(context);
    if (confirmed != true) return;
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(markOrderCompletedUseCaseProvider).call(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('픽업 완료 처리했습니다')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myStoreProvider);
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
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppColors.textHeading),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(storeAsync, orderAsync),
      bottomNavigationBar: _buildBottomBar(storeAsync, orderAsync),
    );
  }

  Widget _buildBody(
    AsyncValue storeAsync,
    AsyncValue<OrderEntity?> orderAsync,
  ) {
    // 로딩
    if (storeAsync.isLoading || orderAsync.isLoading) {
      return const _OwnerOrderDetailShimmer();
    }

    // 스트림 에러
    if (storeAsync.hasError) {
      return _ErrorBody(
        message: '매장 정보를 불러오지 못했어요',
        onRetry: () => ref.invalidate(myStoreProvider),
      );
    }
    if (orderAsync.hasError) {
      return _ErrorBody(
        message: orderAsync.error.toString(),
        onRetry: () =>
            ref.invalidate(currentOrderProvider(widget.orderId)),
      );
    }

    final store = storeAsync.asData?.value;
    final order = orderAsync.asData?.value;

    // 매장 없음
    if (store == null) {
      return _FallbackBody(
        icon: Icons.store_outlined,
        title: '등록된 매장이 없어요',
        subtitle: null,
        buttonLabel: '돌아가기',
        onButton: () => Navigator.of(context).pop(),
      );
    }

    // 주문 없음
    if (order == null) {
      return _FallbackBody(
        icon: Icons.receipt_long_rounded,
        title: '주문을 찾을 수 없어요',
        subtitle: '이미 처리되었거나 존재하지 않는 주문이에요.',
        buttonLabel: '주문 목록으로',
        onButton: () => Navigator.of(context).pop(),
      );
    }

    // 권한 가드 (결정 G): 다른 매장 주문
    if (order.storeId != store.id) {
      return _FallbackBody(
        icon: Icons.store_rounded,
        title: '이 주문은 다른 매장의 주문이에요',
        subtitle: '확인하려는 주문이 맞는지 다시 확인해주세요.',
        buttonLabel: '주문 목록으로',
        onButton: () => Navigator.of(context).pop(),
      );
    }

    final hasActionBar = _hasActionBar(order);
    return _OwnerOrderDetailBody(
      order: order,
      isActionLoading: _isActionLoading,
      hasActionBar: hasActionBar,
    );
  }

  Widget? _buildBottomBar(
    AsyncValue storeAsync,
    AsyncValue<OrderEntity?> orderAsync,
  ) {
    if (storeAsync.isLoading ||
        orderAsync.isLoading ||
        storeAsync.hasError ||
        orderAsync.hasError) {
      return null;
    }

    final store = storeAsync.asData?.value;
    final order = orderAsync.asData?.value;

    if (store == null || order == null || order.storeId != store.id) {
      return null;
    }

    if (!_hasActionBar(order)) return null;

    return _ActionBar(
      order: order,
      isLoading: _isActionLoading,
      onAccept: () => _acceptOrder(order.id),
      onReject: () => _rejectOrder(order),
      onApproveRefund: () => _approveRefund(order),
      onDenyRefund: () => _denyRefund(order),
      onStartMaking: () => _startMaking(order.id),
      onMarkReady: () => _markReady(order.id),
      onCompletePickup: () => _completePickup(order.id),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _OwnerOrderDetailBody extends StatelessWidget {
  const _OwnerOrderDetailBody({
    required this.order,
    required this.isActionLoading,
    required this.hasActionBar,
  });

  final OrderEntity order;
  final bool isActionLoading;
  final bool hasActionBar;

  static final _dateFormat = DateFormat('yyyy.MM.dd HH:mm', 'ko');

  String get _shortOrderId {
    final id = order.id;
    if (id.length <= 12) return id;
    return '${id.substring(0, 12)}...';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: hasActionBar ? 96 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusSection(
            order: order,
            shortId: _shortOrderId,
            dateFormat: _dateFormat,
          ),
          const SizedBox(height: 16),
          if (order.refundRequest != null) ...[
            _OwnerRefundSection(
              refundRequest: order.refundRequest!,
              orderStatus: order.status,
              dateFormat: _dateFormat,
            ),
            const SizedBox(height: 16),
          ],
          if (order.makingStartedAt != null) ...[
            _TimelineSection(order: order, dateFormat: _dateFormat),
            const SizedBox(height: 16),
          ],
          _ItemsSection(order: order),
          const SizedBox(height: 16),
          _PriceSection(order: order),
          const SizedBox(height: 16),
          _PaymentInfoSection(order: order),
          const SizedBox(height: 24),
          if (!hasActionBar) ...[
            _NoActionInfoCard(order: order),
            const SizedBox(height: 32),
          ],
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
          OrderStatusBadge(
            status: order.status,
            size: OrderStatusBadgeSize.large,
          ),
          const SizedBox(height: 12),
          Text(
            '주문번호 $shortId',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            dateFormat.format(order.createdAt),
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            order.storeName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refund Section ────────────────────────────────────────────────────────────

/// 환불 요청 섹션. `deniedAt` 여부로 내부 서브 케이스 분기.
class _OwnerRefundSection extends StatelessWidget {
  const _OwnerRefundSection({
    required this.refundRequest,
    required this.orderStatus,
    required this.dateFormat,
  });

  final RefundRequestEntity refundRequest;
  final OrderStatus orderStatus;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final isDenied = refundRequest.deniedAt != null;

    if (isDenied) {
      return _buildDenied();
    } else {
      return _buildActive();
    }
  }

  // 3-A: 환불 요청 활성 (error 톤)
  Widget _buildActive() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 6),
              const Text(
                '환불 요청 접수',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
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
            refundRequest.reason,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '요청 ${dateFormat.format(refundRequest.requestedAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // 3-B: 환불 요청 거절됨 (회색 톤)
  Widget _buildDenied() {
    final deniedReason = refundRequest.deniedReason;
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
          Row(
            children: [
              const Icon(Icons.do_not_disturb_on_rounded,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Text(
                '환불 거절됨',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
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
            refundRequest.reason,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
          if (deniedReason != null && deniedReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '거절 사유',
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
          const SizedBox(height: 10),
          Text(
            '거절 ${dateFormat.format(refundRequest.deniedAt!)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Timeline Section ──────────────────────────────────────────────────────────

/// 진행 현황 타임라인. [OrderEntity.makingStartedAt] 이 set 된 시점부터 노출.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.order,
    required this.dateFormat,
  });

  final OrderEntity order;
  final DateFormat dateFormat;

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
            '진행 현황',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 14),
          _TimelineRow(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            label: '조리 시작',
            timestamp: order.makingStartedAt != null
                ? dateFormat.format(order.makingStartedAt!)
                : null,
          ),
          if (order.readyAt != null) ...[
            const SizedBox(height: 12),
            _TimelineRow(
              icon: Icons.check_circle_rounded,
              iconColor: AppColors.success,
              label: '준비 완료',
              timestamp: dateFormat.format(order.readyAt!),
            ),
          ],
          if (order.completedAt != null) ...[
            const SizedBox(height: 12),
            _TimelineRow(
              icon: Icons.shopping_bag_rounded,
              iconColor: AppColors.primary,
              label: '픽업 완료',
              timestamp: dateFormat.format(order.completedAt!),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.timestamp,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
        const Spacer(),
        if (timestamp != null)
          Text(
            timestamp!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
      ],
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
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const Spacer(),
        Text(value,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textBody)),
      ],
    );
  }
}

// ── No Action Info Card ───────────────────────────────────────────────────────

class _NoActionInfoCard extends StatelessWidget {
  const _NoActionInfoCard({required this.order});
  final OrderEntity order;

  String get _message {
    final req = order.refundRequest;
    switch (order.status) {
      case OrderStatus.accepted:
        if (req != null && req.deniedAt != null) {
          return '환불 요청을 거절했어요.';
        }
        return '주문을 받았어요. 준비를 시작해주세요.';
      case OrderStatus.making:
        return '현재 제조 중인 주문이에요.';
      case OrderStatus.ready:
        return '픽업 대기 중인 주문이에요.';
      case OrderStatus.completed:
        return '완료된 주문이에요.';
      case OrderStatus.cancelled:
        return '취소된 주문이에요.';
      case OrderStatus.refunded:
        return '환불이 완료된 주문이에요.';
      case OrderStatus.paid:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style:
            const TextStyle(fontSize: 14, color: AppColors.textMuted),
      ),
    );
  }
}

// ── Action Bar (sticky bottom) ────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.order,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
    required this.onApproveRefund,
    required this.onDenyRefund,
    required this.onStartMaking,
    required this.onMarkReady,
    required this.onCompletePickup,
  });

  final OrderEntity order;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onApproveRefund;
  final VoidCallback onDenyRefund;
  final VoidCallback onStartMaking;
  final VoidCallback onMarkReady;
  final VoidCallback onCompletePickup;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // paid: 주문 받기 + 거절 (2:1)
    if (order.status == OrderStatus.paid) {
      return _buildPaidButtons();
    }
    // accepted + 환불 활성: 환불 승인 + 거절 (1:1)
    if (order.status == OrderStatus.accepted) {
      final req = order.refundRequest;
      final isRefundActive = req != null && req.deniedAt == null;
      if (isRefundActive) {
        return _buildRefundButtons();
      }
      // accepted + 환불 비활성: 조리 시작 (단일)
      return _PrimaryButton(
        label: '조리 시작',
        onTap: onStartMaking,
        isLoading: isLoading,
      );
    }
    // making: 준비 완료 (단일)
    if (order.status == OrderStatus.making) {
      return _PrimaryButton(
        label: '준비 완료',
        onTap: onMarkReady,
        isLoading: isLoading,
      );
    }
    // ready: 픽업 완료 (단일, 다이얼로그 확정)
    if (order.status == OrderStatus.ready) {
      return _PrimaryButton(
        label: '픽업 완료',
        onTap: onCompletePickup,
        isLoading: isLoading,
      );
    }
    return const SizedBox.shrink();
  }

  // 7-A: paid 상태 — 2:1 비율
  Widget _buildPaidButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _PrimaryButton(
            label: '주문 받기',
            onTap: onAccept,
            isLoading: isLoading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ErrorOutlinedButton(
            label: '거절',
            onTap: onReject,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }

  // 7-B: 환불 요청 활성 상태 — 1:1 비율
  Widget _buildRefundButtons() {
    return Row(
      children: [
        Expanded(
          child: _PrimaryButton(
            label: '환불 승인',
            onTap: onApproveRefund,
            isLoading: isLoading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ErrorOutlinedButton(
            label: '환불 거절',
            onTap: onDenyRefund,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}

// ── Button Widgets ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.isLoading,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _ErrorOutlinedButton extends StatelessWidget {
  const _ErrorOutlinedButton({
    required this.label,
    required this.onTap,
    required this.isLoading,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          disabledForegroundColor: AppColors.textMuted,
          side: isLoading
              ? const BorderSide(color: AppColors.border)
              : const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ── Fallback Body ─────────────────────────────────────────────────────────────

class _FallbackBody extends StatelessWidget {
  const _FallbackBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onButton,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String buttonLabel;
  final VoidCallback onButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onButton,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(160, 44),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
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
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textMuted),
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

// ── Shimmer ───────────────────────────────────────────────────────────────────

class _OwnerOrderDetailShimmer extends StatelessWidget {
  const _OwnerOrderDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(height: 120, radius: 16),
          const SizedBox(height: 16),
          _shimmerBox(height: 72, radius: 16),
          const SizedBox(height: 16),
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
