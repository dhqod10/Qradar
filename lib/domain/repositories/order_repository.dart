import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';

/// 주문 Repository 인터페이스.
///
/// Firestore `orders/{orderId}` 컬렉션의 읽기/상태전이.
/// 결제/환불 관련 PG 호출은 [PaymentGatewayRepository] 담당.
abstract class OrderRepository {
  /// 특정 주문 단건 stream. 없으면 null emit.
  Stream<OrderEntity?> watchOrder(String orderId);

  /// 특정 사용자의 모든 주문 stream. createdAt 내림차순.
  Stream<List<OrderEntity>> watchUserOrders(String userId);

  /// 특정 매장의 주문 stream. statusFilter 비어있으면 전체.
  Stream<List<OrderEntity>> watchStoreOrders(
    String storeId, {
    Set<OrderStatus>? statusFilter,
  });

  /// 특정 매장의 환불 요청 주문 stream (refundRequest != null && status != refunded).
  Stream<List<OrderEntity>> watchStoreRefundRequests(String storeId);

  /// 점주가 주문 접수 → status: paid → accepted.
  Future<void> setAcceptedByOwner(String orderId);

  /// customer 환불 요청 → orders/{orderId}.refundRequest set.
  Future<void> requestRefund(String orderId, String reason);

  /// 점주가 환불 요청 거절 → refundRequest.deniedAt / deniedReason set.
  Future<void> denyRefundRequest(
    String orderId,
    String deniedReason,
  );

  /// 점주가 조리 시작 → status: accepted → making.
  Future<void> startMakingOrder(String orderId);

  /// 점주가 준비 완료 → status: making → ready.
  Future<void> markOrderReady(String orderId);

  /// 점주가 픽업 완료 → status: ready → completed.
  Future<void> markOrderCompleted(String orderId);
}
