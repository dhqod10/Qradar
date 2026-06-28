import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/cancel_info_entity.dart';
import 'package:qradar/domain/entities/order_item_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/payment_info_entity.dart';
import 'package:qradar/domain/entities/refund_info_entity.dart';
import 'package:qradar/domain/entities/refund_request_entity.dart';

part 'order_entity.freezed.dart';

/// 주문 엔티티. source of truth = Firestore `orders/{orderId}`.
///
/// [id] = idempotencyKey = Toss orderId (uuid v4).
@freezed
abstract class OrderEntity with _$OrderEntity {
  const factory OrderEntity({
    required String id,
    required String userId,
    required String storeId,
    required String storeName,
    String? brandId,
    @Default(<OrderItemEntity>[]) List<OrderItemEntity> items,
    required int subtotal,
    int? discount,
    required int totalPrice,
    required OrderStatus status,
    required PaymentInfoEntity paymentInfo,
    RefundRequestEntity? refundRequest,
    RefundInfoEntity? refundInfo,
    CancelInfoEntity? cancelInfo,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? acceptedAt,
    DateTime? makingStartedAt,
    DateTime? readyAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? refundedAt,
  }) = _OrderEntity;
}
