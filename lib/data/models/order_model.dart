import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/data/models/cancel_info_model.dart';
import 'package:qradar/data/models/order_item_model.dart';
import 'package:qradar/data/models/payment_info_model.dart';
import 'package:qradar/data/models/refund_info_model.dart';
import 'package:qradar/data/models/refund_request_model.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';

/// Firestore `orders/{orderId}` 문서 매퍼.
///
/// 모든 nested object 는 Firestore Map 으로 평탄화 (서브컬렉션 X).
class OrderModel {
  final String id;
  final String userId;
  final String storeId;
  final String storeName;
  final String? brandId;
  final List<OrderItemModel> items;
  final int subtotal;
  final int? discount;
  final int totalPrice;
  final OrderStatus status;
  final PaymentInfoModel paymentInfo;
  final RefundRequestModel? refundRequest;
  final RefundInfoModel? refundInfo;
  final CancelInfoModel? cancelInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? makingStartedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? refundedAt;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.storeId,
    required this.storeName,
    this.brandId,
    required this.items,
    required this.subtotal,
    this.discount,
    required this.totalPrice,
    required this.status,
    required this.paymentInfo,
    this.refundRequest,
    this.refundInfo,
    this.cancelInfo,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.makingStartedAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    this.refundedAt,
  });

  factory OrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OrderModel._fromMap(doc.id, data);
  }

  factory OrderModel._fromMap(String id, Map<String, dynamic> data) {
    DateTime? toDate(Object? v) =>
        v is Timestamp ? v.toDate() : null;

    final rawItems = (data['items'] as List<dynamic>?) ?? const [];
    final rawPaymentInfo =
        (data['paymentInfo'] as Map<String, dynamic>?) ?? const {};
    final rawRefundRequest =
        data['refundRequest'] as Map<String, dynamic>?;
    final rawRefundInfo =
        data['refundInfo'] as Map<String, dynamic>?;
    final rawCancelInfo =
        data['cancelInfo'] as Map<String, dynamic>?;

    return OrderModel(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      storeId: (data['storeId'] as String?) ?? '',
      storeName: (data['storeName'] as String?) ?? '',
      brandId: data['brandId'] as String?,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderItemModel.fromMap)
          .toList(growable: false),
      subtotal: (data['subtotal'] as num?)?.toInt() ?? 0,
      discount: (data['discount'] as num?)?.toInt(),
      totalPrice: (data['totalPrice'] as num?)?.toInt() ?? 0,
      status: OrderStatus.fromCode(data['status'] as String?),
      paymentInfo: PaymentInfoModel.fromMap(rawPaymentInfo),
      refundRequest: rawRefundRequest != null
          ? RefundRequestModel.fromMap(rawRefundRequest)
          : null,
      refundInfo:
          rawRefundInfo != null ? RefundInfoModel.fromMap(rawRefundInfo) : null,
      cancelInfo:
          rawCancelInfo != null ? CancelInfoModel.fromMap(rawCancelInfo) : null,
      createdAt: toDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: toDate(data['updatedAt']) ?? DateTime.now(),
      acceptedAt: toDate(data['acceptedAt']),
      makingStartedAt: toDate(data['makingStartedAt']),
      readyAt: toDate(data['readyAt']),
      completedAt: toDate(data['completedAt']),
      cancelledAt: toDate(data['cancelledAt']),
      refundedAt: toDate(data['refundedAt']),
    );
  }

  OrderEntity toEntity() {
    return OrderEntity(
      id: id,
      userId: userId,
      storeId: storeId,
      storeName: storeName,
      brandId: brandId,
      items: items.map((m) => m.toEntity()).toList(growable: false),
      subtotal: subtotal,
      discount: discount,
      totalPrice: totalPrice,
      status: status,
      paymentInfo: paymentInfo.toEntity(),
      refundRequest: refundRequest?.toEntity(),
      refundInfo: refundInfo?.toEntity(),
      cancelInfo: cancelInfo?.toEntity(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      acceptedAt: acceptedAt,
      makingStartedAt: makingStartedAt,
      readyAt: readyAt,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      refundedAt: refundedAt,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'userId': userId,
        'storeId': storeId,
        'storeName': storeName,
        if (brandId != null) 'brandId': brandId,
        'items': items.map((m) => m.toMap()).toList(growable: false),
        'subtotal': subtotal,
        if (discount != null) 'discount': discount,
        'totalPrice': totalPrice,
        'status': status.name,
        'paymentInfo': paymentInfo.toMap(),
        if (refundRequest != null) 'refundRequest': refundRequest!.toMap(),
        if (refundInfo != null) 'refundInfo': refundInfo!.toMap(),
        if (cancelInfo != null) 'cancelInfo': cancelInfo!.toMap(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
        if (makingStartedAt != null)
          'makingStartedAt': Timestamp.fromDate(makingStartedAt!),
        if (readyAt != null) 'readyAt': Timestamp.fromDate(readyAt!),
        if (completedAt != null)
          'completedAt': Timestamp.fromDate(completedAt!),
        if (cancelledAt != null)
          'cancelledAt': Timestamp.fromDate(cancelledAt!),
        if (refundedAt != null) 'refundedAt': Timestamp.fromDate(refundedAt!),
      };
}
