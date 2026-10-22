import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
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
  /// 조건: `refundRequest` 필드가 존재 + status != refunded + 아직 거절되지 않음.
  /// Firestore 는 null 비교 불가하므로 `refundRequest` 존재 여부로 필터링.
  /// 클라이언트에서 status == refunded 와 deniedAt != null 제외.
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
          .where((m) =>
              m.status != OrderStatus.refunded &&
              m.refundRequest?.deniedAt == null)
          .toList(growable: false);
    });
  }

  /// 특정 매장의 `[startInclusive, endExclusive)` 기간 주문 1회 조회 (createdAt 내림차순).
  ///
  /// `where('storeId')` 는 Rules(`isStoreOwner(resource.data.storeId)`) 통과를 위한
  /// **필수 제약**이다. 제거하면 permission-denied.
  /// status 필터는 두지 않는다 (환불/취소도 목록에 필요).
  Future<List<OrderModel>> fetchByStoreInPeriod(
    String storeId, {
    required DateTime startInclusive,
    required DateTime endExclusive,
    required int limit,
  }) async {
    try {
      final snap = await _orders
          .where('storeId', isEqualTo: storeId)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endExclusive))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          // 매출 집계는 캐시 결과를 쓰면 안 된다.
          // 기본 `get()` 은 서버에 닿지 못하면 예외 없이 로컬 캐시를 돌려주는데,
          // 캐시가 비었으면 0원, 일부만 있으면 축소된 금액이 "정상 수치"처럼 보인다.
          // 틀린 숫자를 조용히 보여주느니 에러를 띄운다 ("0원" 과 "모름" 은 다르다).
          .get(const GetOptions(source: Source.server));
      return snap.docs.map(OrderModel.fromFirestore).toList(growable: false);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const PermissionDeniedException();
      }
      if (e.code == 'failed-precondition') {
        debugPrint(
          '[OrderRemoteDataSource] fetchByStoreInPeriod 인덱스 누락 의심: '
          'orders(storeId ==, createdAt range, orderBy createdAt desc) ${e.message}',
        );
      }
      rethrow;
    }
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
