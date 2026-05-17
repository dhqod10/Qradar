import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_new_order_tile.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_refund_request_tile.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 점주 주문 접수 페이지 (Phase 3a 최소 구현).
///
/// 탭 1: 신규(paid) 주문 — 주문 받기 / 거절
/// 탭 2: 환불 요청 — 승인 / 거절
class OwnerOrdersPage extends ConsumerStatefulWidget {
  const OwnerOrdersPage({super.key});

  @override
  ConsumerState<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends ConsumerState<OwnerOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 처리 중인 주문 ID 세트 (버튼 중복 탭 방지)
  final Set<String> _processingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── 신규 주문 처리 ────────────────────────────────────────────────────────

  Future<void> _acceptOrder(String orderId) async {
    if (_processingOrderIds.contains(orderId)) return;
    setState(() => _processingOrderIds.add(orderId));
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
      if (mounted) setState(() => _processingOrderIds.remove(orderId));
    }
  }

  Future<void> _rejectOrder(OrderEntity order) async {
    final reason = await _showRejectOrderDialog();
    if (reason == null) return;
    if (_processingOrderIds.contains(order.id)) return;
    setState(() => _processingOrderIds.add(order.id));
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
      if (mounted) setState(() => _processingOrderIds.remove(order.id));
    }
  }

  // ── 환불 요청 처리 ────────────────────────────────────────────────────────

  Future<void> _approveRefund(OrderEntity order) async {
    final confirmed = await _showApproveRefundDialog(order);
    if (confirmed != true) return;
    if (_processingOrderIds.contains(order.id)) return;
    setState(() => _processingOrderIds.add(order.id));
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
      if (mounted) setState(() => _processingOrderIds.remove(order.id));
    }
  }

  Future<void> _denyRefund(OrderEntity order) async {
    final reason = await _showDenyRefundDialog();
    if (reason == null) return;
    if (_processingOrderIds.contains(order.id)) return;
    setState(() => _processingOrderIds.add(order.id));
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
      if (mounted) setState(() => _processingOrderIds.remove(order.id));
    }
  }

  // ── 다이얼로그 ────────────────────────────────────────────────────────────

  /// D8: 주문 거절 사유 다이얼로그. null 반환 시 취소.
  Future<String?> _showRejectOrderDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '주문을 거절하시겠어요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '거절 사유 (선택 입력)',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '아니요',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }

  /// D6: 환불 승인 확인 다이얼로그. true 반환 시 승인.
  Future<bool?> _showApproveRefundDialog(OrderEntity order) async {
    final fmt = NumberFormat('#,###원', 'ko_KR');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '환불을 승인하시겠어요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: Text(
          '전액 ${fmt.format(order.totalPrice)}이 환불됩니다.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('환불 승인'),
          ),
        ],
      ),
    );
  }

  /// D7: 환불 거절 사유 다이얼로그. null 반환 시 취소.
  Future<String?> _showDenyRefundDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '환불 요청 거절',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '거절 사유를 입력해주세요',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '주문 접수',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '신규'),
            Tab(text: '환불 요청'),
          ],
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _buildStoreError(),
        data: (store) {
          if (store == null) return _buildNoStore();
          return TabBarView(
            controller: _tabController,
            children: [
              _NewOrdersTab(
                storeId: store.id,
                processingIds: _processingOrderIds,
                onAccept: _acceptOrder,
                onReject: _rejectOrder,
              ),
              _RefundRequestsTab(
                storeId: store.id,
                processingIds: _processingOrderIds,
                onApprove: _approveRefund,
                onDeny: _denyRefund,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            '매장 정보를 불러오지 못했어요',
            style: TextStyle(fontSize: 16, color: AppColors.textHeading),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStore() {
    return const Center(
      child: Text(
        '등록된 매장이 없어요',
        style: TextStyle(fontSize: 15, color: AppColors.textMuted),
      ),
    );
  }
}

// ── 신규 주문 탭 ─────────────────────────────────────────────────────────────

class _NewOrdersTab extends ConsumerWidget {
  const _NewOrdersTab({
    required this.storeId,
    required this.processingIds,
    required this.onAccept,
    required this.onReject,
  });

  final String storeId;
  final Set<String> processingIds;
  final Future<void> Function(String orderId) onAccept;
  final Future<void> Function(OrderEntity order) onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(
      StreamProvider((r) => r
          .read(watchStoreOrdersUseCaseProvider)
          .call(storeId, statusFilter: {OrderStatus.paid})),
    );

    return ordersAsync.when(
      loading: () => _buildShimmer(),
      error: (e, _) => _buildError(),
      data: (orders) {
        if (orders.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final order = orders[i];
            return OwnerNewOrderTile(
              order: order,
              isLoading: processingIds.contains(order.id),
              onAccept: () => onAccept(order.id),
              onReject: () => onReject(order),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 3,
      itemBuilder: (_, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
          SizedBox(height: 12),
          Text(
            '불러오는 데 실패했어요',
            style: TextStyle(fontSize: 16, color: AppColors.textHeading),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: AppColors.success,
          ),
          SizedBox(height: 12),
          Text(
            '신규 주문이 없어요',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '새 주문이 들어오면 여기에 표시됩니다',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── 환불 요청 탭 ─────────────────────────────────────────────────────────────

class _RefundRequestsTab extends ConsumerWidget {
  const _RefundRequestsTab({
    required this.storeId,
    required this.processingIds,
    required this.onApprove,
    required this.onDeny,
  });

  final String storeId;
  final Set<String> processingIds;
  final Future<void> Function(OrderEntity order) onApprove;
  final Future<void> Function(OrderEntity order) onDeny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(
      StreamProvider((r) => r
          .read(watchStoreRefundRequestsUseCaseProvider)
          .call(storeId)),
    );

    return ordersAsync.when(
      loading: () => _buildShimmer(),
      error: (e, _) => _buildError(),
      data: (orders) {
        if (orders.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final order = orders[i];
            return OwnerRefundRequestTile(
              order: order,
              isLoading: processingIds.contains(order.id),
              onApprove: () => onApprove(order),
              onDeny: () => onDeny(order),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 3,
      itemBuilder: (_, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
          SizedBox(height: 12),
          Text(
            '불러오는 데 실패했어요',
            style: TextStyle(fontSize: 16, color: AppColors.textHeading),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            '환불 요청이 없어요',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textHeading,
            ),
          ),
        ],
      ),
    );
  }
}
