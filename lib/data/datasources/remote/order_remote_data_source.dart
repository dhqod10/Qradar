import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/order_model.dart';
import 'package:qradar/domain/entities/order_status.dart';

/// Firestore `orders/{orderId}` 컬렉션 원격 데이터소스.
///
/// **Firestore 직접 사용은 본 파일에서만**. (Clean Architecture 절대 규칙)
///
/// 정렬: createdAt 내림차순. Firestore 복합 인덱스 필요 시
/// (storeId + status + createdAt) console 에서 생성.
class OrderRemoteDataSource {
  final FirebaseFirestore _firestore;

  OrderRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestorePaths.orders);

  // ── 단건 stream ─────────────────────────────────────────────────────────────

  /// 주문 단건 실시간 stream. 문서 없으면 null emit.
  Stream<OrderModel?> streamById(String orderId) {
    return _orders.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromFirestore(doc);
    });
  }

  // ── 사용자 주문 stream ───────────────────────────────────────────────────────

  /// 특정 사용자의 전체 주문 stream. createdAt 내림차순.
  Stream<List<OrderModel>> streamByUser(String uid) {
    return _orders
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(OrderModel.fromFirestore).toList(growable: false));
  }

  // ── 매장 주문 stream ─────────────────────────────────────────────────────────

  /// 특정 매장의 주문 stream.
  ///
  /// [statusFilter] 가 비어있으면 전체 status 조회.
  /// Firestore `in` 쿼리는 최대 10개까지 허용 (OrderStatus 값이 7개이므로 안전).
  Stream<List<OrderModel>> streamPaidByStore(
    String storeId, {
    Set<OrderStatus>? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _orders
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where(
        'status',
        whereIn: statusFilter.map((s) => s.name).toList(growable: false),
      );
    }

    return query
        .snapshots()
        .map((snap) =>
            snap.docs.map(OrderModel.fromFirestore).toList(growable: false));
  }

  /// 특정 매장의 환불 요청 주문 stream.
  ///
  /// 조건: `refundRequest` 필드가 존재 + status != refunded.
  /// Firestore 는 null 비교 불가하므로 `refundRequest` 존재 여부로 필터링.
  /// 클라이언트에서 status == refunded 제외.
  Stream<List<OrderModel>> streamRefundRequestsByStore(String storeId) {
    return _orders
        .where('storeId', isEqualTo: storeId)
        .where('refundRequest', isNull: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final all =
          snap.docs.map(OrderModel.fromFirestore).toList(growable: false);
      return all
          .where((m) => m.status != OrderStatus.refunded)
          .toList(growable: false);
    });
  }

  // ── 쓰기 ────────────────────────────────────────────────────────────────────

  /// 주문 doc 부분 업데이트.
  Future<void> update(String orderId, Map<String, dynamic> data) async {
    await _orders.doc(orderId).update(data);
  }

  /// 주문 doc 존재 여부 확인.
  Future<bool> exists(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    return doc.exists;
  }
}
