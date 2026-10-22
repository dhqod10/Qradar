import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/network_unavailable_exception.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/data/models/review_model.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// Firestore `reviews` 컬렉션 원격 데이터소스. **Firestore 직접 사용은 본 파일까지.**
///
/// 집계(`stores.averageScore/reviewCount`)는 Cloud Function `onReviewWritten` 전담이다.
class ReviewRemoteDataSource {
  final FirebaseFirestore _firestore;

  ReviewRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection(FirestorePaths.reviews);

  /// 매장 평가 목록. storeId == + createdAt desc + limit (인덱스 I1).
  Stream<List<ReviewModel>> streamByStore(String storeId, {int limit = 50}) {
    return _reviews
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) => !d.metadata.hasPendingWrites || _hasCreatedAt(d))
              .map(ReviewModel.fromFirestore)
              .toList(growable: false),
        );
  }

  bool _hasCreatedAt(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      d.data()['createdAt'] != null;

  /// 내 평가 (문서 ID 직접 접근).
  Stream<ReviewModel?> streamMine(String storeId, String userId) {
    return _reviews
        .doc(ReviewModel.docId(storeId, userId))
        .snapshots()
        .map((doc) => doc.exists ? ReviewModel.fromFirestore(doc) : null);
  }

  /// 존재 확인 후 create / update 분기.
  /// createdAt immutable + Rules 화이트리스트를 지키기 위해 set(merge) 를 쓰지 않는다.
  Future<void> upsert({
    required String storeId,
    required String userId,
    required String orderId,
    required StoreGrade grade,
    String? comment,
  }) async {
    final ref = _reviews.doc(ReviewModel.docId(storeId, userId));
    try {
      final snap = await ref.get();
      if (snap.exists) {
        await ref.update(
          ReviewModel.toFirestoreForUpdate(
            orderId: orderId,
            grade: grade,
            comment: comment,
          ),
        );
      } else {
        await ref.set(
          ReviewModel.toFirestoreForCreate(
            storeId: storeId,
            userId: userId,
            orderId: orderId,
            grade: grade,
            comment: comment,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const PermissionDeniedException();
      }
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw const NetworkUnavailableException();
      }
      if (e.code == 'failed-precondition') {
        debugPrint(
          '[ReviewRemoteDataSource] upsert failed-precondition: ${e.message}',
        );
      }
      rethrow;
    }
  }
}
