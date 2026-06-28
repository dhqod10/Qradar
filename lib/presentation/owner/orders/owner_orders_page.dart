import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';
import 'package:qradar/presentation/owner/orders/owner_order_detail_page.dart';
import 'package:qradar/presentation/owner/orders/widgets/notification_denied_banner.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_in_progress_order_tile.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_new_order_tile.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_order_action_dialogs.dart';
import 'package:qradar/presentation/owner/orders/widgets/owner_refund_request_tile.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

/// 점주 주문 접수 페이지 (Phase 3c-1 확장).
///
/// 탭 1: 신규(paid) 주문 — 주문 받기 / 거절
/// 탭 2: 조리 중(making/ready) 주문 — 준비 완료 / 픽업 완료
/// 탭 3: 환불 요청 — 승인 / 거절
class OwnerOrdersPage extends ConsumerStatefulWidget {
  const OwnerOrdersPage({super.key});

  @override
  ConsumerState<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends ConsumerState<OwnerOrdersPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;

  // 처리 중인 주문 ID 세트 (버튼 중복 탭 방지)
  final Set<String> _processingOrderIds = {};

  // 알림 권한 거부 배너 표시 여부
  bool _showNotificationDeniedBanner = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotificationBanner();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  /// 앱이 포그라운드로 돌아왔을 때 권한 재확인 (설정 화면 복귀 대응).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationBanner();
    }
  }

  Future<void> _refreshNotificationBanner() async {
    final uid = ref.read(authProvider).asData?.value?.uid;
    if (uid == null) return;

    // prompted == true 인 경우에만 배너 노출 후보
    final prompted = await ref
        .read(userRepositoryProvider)
        .getNotificationPermissionPrompted(uid);
    if (!prompted) {
      if (mounted) setState(() => _showNotificationDeniedBanner = false);
      return;
    }

    final status = await ref
        .read(pushNotificationRepositoryProvider)
        .getPermissionStatus();

    if (!mounted) return;
    setState(() {
      _showNotificationDeniedBanner =
          status == NotificationPermissionStatus.denied;
    });
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

  // ── 조리 중 탭 처리 ──────────────────────────────────────────────────────

  Future<void> _startMaking(String orderId) async {
    if (_processingOrderIds.contains(orderId)) return;
    setState(() => _processingOrderIds.add(orderId));
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
      if (mounted) setState(() => _processingOrderIds.remove(orderId));
    }
  }

  Future<void> _markReady(String orderId) async {
    if (_processingOrderIds.contains(orderId)) return;
    setState(() => _processingOrderIds.add(orderId));
    try {
      await ref.read(markOrderReadyUseCaseProvider).call(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('준비를 완료했어요')),
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

  Future<void> _completePickupWithDialog(String orderId) async {
    final confirmed = await OwnerOrderActionDialogs.showCompletePickup(context);
    if (confirmed != true) return;
    if (_processingOrderIds.contains(orderId)) return;
    setState(() => _processingOrderIds.add(orderId));
    try {
      await ref.read(markOrderCompletedUseCaseProvider).call(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('픽업 완료로 표시했어요')),
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
  Future<String?> _showRejectOrderDialog() =>
      OwnerOrderActionDialogs.showRejectOrder(context);

  /// D6: 환불 승인 확인 다이얼로그. true 반환 시 승인.
  Future<bool?> _showApproveRefundDialog(OrderEntity order) =>
      OwnerOrderActionDialogs.showApproveRefund(
        context,
        totalPrice: order.totalPrice,
      );

  /// D7: 환불 거절 사유 다이얼로그. null 반환 시 취소.
  Future<String?> _showDenyRefundDialog() =>
      OwnerOrderActionDialogs.showDenyRefund(context);

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
            Tab(text: '조리 중'),
            Tab(text: '환불 요청'),
          ],
        ),
      ),
      body: storeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) {
          debugPrint('[OwnerOrdersPage] myStore error: $e');
          return _buildStoreError();
        },
        data: (store) {
          debugPrint(
              '[OwnerOrdersPage] myStore data: id=${store?.id} name=${store?.name}');
          if (store == null) return _buildNoStore();
          return Column(
            children: [
              if (_showNotificationDeniedBanner)
                const NotificationDeniedBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _NewOrdersTab(
                      storeId: store.id,
                      processingIds: _processingOrderIds,
                      onAccept: _acceptOrder,
                      onReject: _rejectOrder,
                    ),
                    _InProgressOrdersTab(
                      storeId: store.id,
                      processingIds: _processingOrderIds,
                      onStartMaking: _startMaking,
                      onMarkReady: _markReady,
                      onCompletePickup: _completePickupWithDialog,
                    ),
                    _RefundRequestsTab(
                      storeId: store.id,
                      processingIds: _processingOrderIds,
                      onApprove: _approveRefund,
                      onDeny: _denyRefund,
                    ),
                  ],
                ),
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
    final ordersAsync = ref.watch(newOrdersByStoreProvider(storeId));

    return ordersAsync.when(
      loading: () => _buildShimmer(),
      error: (e, _) {
        debugPrint('[OwnerOrdersPage] new orders error: $e');
        return _buildError();
      },
      data: (orders) {
        debugPrint(
            '[OwnerOrdersPage] new orders received: count=${orders.length} storeId=$storeId');
        if (orders.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final order = orders[i];
            return OwnerNewOrderTile(
              order: order,
              isLoading: processingIds.contains(order.id),
              onAccept: () => onAccept(order.id),
              onReject: () => onReject(order),
              onTapDetail: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      OwnerOrderDetailPage(orderId: order.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 110),
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

// ── 조리 중 탭 ───────────────────────────────────────────────────────────────

class _InProgressOrdersTab extends ConsumerWidget {
  const _InProgressOrdersTab({
    required this.storeId,
    required this.processingIds,
    required this.onStartMaking,
    required this.onMarkReady,
    required this.onCompletePickup,
  });

  final String storeId;
  final Set<String> processingIds;
  final Future<void> Function(String orderId) onStartMaking;
  final Future<void> Function(String orderId) onMarkReady;
  final Future<void> Function(String orderId) onCompletePickup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(inProgressOrdersByStoreProvider(storeId));

    return ordersAsync.when(
      loading: () => _buildShimmer(),
      error: (e, _) {
        debugPrint('[OwnerOrdersPage] in-progress orders error: $e');
        return _buildError();
      },
      data: (orders) {
        if (orders.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final order = orders[i];
            return OwnerInProgressOrderTile(
              order: order,
              isLoading: processingIds.contains(order.id),
              onAction: switch (order.status) {
                OrderStatus.accepted => () => onStartMaking(order.id),
                OrderStatus.making => () => onMarkReady(order.id),
                _ => () => onCompletePickup(order.id),
              },
              onTapDetail: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OwnerOrderDetailPage(orderId: order.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 110),
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
            Icons.hourglass_empty_rounded,
            size: 56,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            '조리 중인 주문이 없어요',
            style: TextStyle(fontSize: 15, color: AppColors.textHeading),
          ),
          SizedBox(height: 4),
          Text(
            '신규 주문을 받으면 여기에 표시됩니다',
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
    final ordersAsync = ref.watch(refundRequestsByStoreProvider(storeId));

    return ordersAsync.when(
      loading: () => _buildShimmer(),
      error: (e, _) {
        debugPrint('[OwnerOrdersPage] refund requests error: $e');
        return _buildError();
      },
      data: (orders) {
        debugPrint(
            '[OwnerOrdersPage] refund requests received: count=${orders.length} storeId=$storeId');
        if (orders.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final order = orders[i];
            return OwnerRefundRequestTile(
              order: order,
              isLoading: processingIds.contains(order.id),
              onApprove: () => onApprove(order),
              onDeny: () => onDeny(order),
              onTapDetail: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      OwnerOrderDetailPage(orderId: order.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 110),
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
