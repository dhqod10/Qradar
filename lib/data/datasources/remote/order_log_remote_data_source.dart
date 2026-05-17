import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/order_log_model.dart';

/// Firestore 주문 로그 원격 데이터소스.
///
/// 컬렉션: `users/{uid}/orderLogs/{logId}` (Phase 2 spec 결정 E)
///
/// **Firestore 직접 사용은 본 파일에서만**. (Clean Architecture 절대 규칙)
class OrderLogRemoteDataSource {
  final FirebaseFirestore _firestore;

  OrderLogRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logs(String uid) => _firestore
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.orderLogs);

  /// 사용자 주문 로그 stream. paidAt desc.
  Stream<List<OrderLogModel>> watchUserLogs(String uid) {
    return _logs(uid)
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(OrderLogModel.fromFirestore)
            .toList(growable: false));
  }

  /// 주문 로그 1건 추가 (id 가 비어 있으면 doc 자동 생성).
  /// 동일 id 존재 시 merge 로 덮어쓴다 (시드 재실행 안전).
  Future<void> appendLog(String uid, OrderLogModel model) async {
    final ref = model.id.isEmpty
        ? _logs(uid).doc()
        : _logs(uid).doc(model.id);
    await ref.set(model.toFirestore(), SetOptions(merge: true));
  }
}
