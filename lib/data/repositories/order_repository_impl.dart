import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/data/datasources/remote/order_remote_data_source.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

/// [OrderRepository] 구현체.
///
/// Firestore `orders/{orderId}` 컬렉션 읽기 / 상태 전이 담당.
/// 결제/환불 PG 호출은 [PaymentGatewayRepositoryImpl] 에서 수행.
///
/// 의존: [OrderRemoteDataSource] 만 사용 (datasource 외 직접 Firestore 접근 금지).
class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource _ds;

  OrderRepositoryImpl(this._ds);

  // ── stream ──────────────────────────────────────────────────────────────────

  @override
  Stream<OrderEntity?> watchOrder(String orderId) {
    return _ds
        .streamById(orderId)
        .map((model) => model?.toEntity());
  }

  @override
  Stream<List<OrderEntity>> watchUserOrders(String userId) {
    return _ds
        .streamByUser(userId)
        .map((models) =>
            models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Stream<List<OrderEntity>> watchStoreOrders(
    String storeId, {
    Set<OrderStatus>? statusFilter,
  }) {
    return _ds
        .streamPaidByStore(storeId, statusFilter: statusFilter)
        .map((models) =>
            models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Stream<List<OrderEntity>> watchStoreRefundRequests(String storeId) {
    return _ds
        .streamRefundRequestsByStore(storeId)
        .map((models) =>
            models.map((m) => m.toEntity()).toList(growable: false));
  }

  // ── 상태 전이 ────────────────────────────────────────────────────────────────

  @override
  Future<void> setAcceptedByOwner(String orderId) async {
    await _ds.update(orderId, <String, dynamic>{
      'status': OrderStatus.accepted.name,
      'acceptedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> requestRefund(String orderId, String reason) async {
    final now = DateTime.now();
    await _ds.update(orderId, <String, dynamic>{
      'refundRequest': <String, dynamic>{
        'reason': reason,
        'requestedAt': Timestamp.fromDate(now),
      },
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  @override
  Future<void> denyRefundRequest(
    String orderId,
    String deniedReason,
  ) async {
    final now = DateTime.now();
    await _ds.update(orderId, <String, dynamic>{
      'refundRequest.deniedAt': Timestamp.fromDate(now),
      'refundRequest.deniedReason': deniedReason,
      'updatedAt': Timestamp.fromDate(now),
    });
  }
}
