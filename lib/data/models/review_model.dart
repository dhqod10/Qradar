import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// Firestore reviews/{reviewId} 문서 매퍼.
///
/// 문서 ID = `{storeId}_{userId}`. `score`(S=4…C=1)는 집계(sum)용 비정규화 값으로
/// 저장 시 [StoreGrade.score] 로 채우며, 읽을 때는 사용하지 않는다(grade 가 진실).
class ReviewModel {
  final String id;
  final String storeId;
  final String userId;
  final String orderId;
  final StoreGrade grade;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.orderId,
    required this.grade,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  /// 리뷰 문서 ID 규칙.
  static String docId(String storeId, String userId) => '${storeId}_$userId';

  factory ReviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ReviewModel.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  /// 필드 누락/오염에 안전한 파서 (단위 테스트 진입점).
  factory ReviewModel.fromMap(String id, Map<String, dynamic> data) {
    final createdAtTs = data['createdAt'] as Timestamp?;
    final updatedAtTs = data['updatedAt'] as Timestamp?;
    return ReviewModel(
      id: id,
      storeId: (data['storeId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      orderId: (data['orderId'] as String?) ?? '',
      grade: StoreGrade.fromString((data['grade'] as String?) ?? 'C'),
      comment: data['comment'] as String?,
      // serverTimestamp 가 아직 확정되지 않은 로컬 스냅샷은 null → 현재 시각으로 대체.
      createdAt: createdAtTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedAtTs?.toDate(),
    );
  }

  ReviewEntity toEntity() {
    return ReviewEntity(
      id: id,
      storeId: storeId,
      userId: userId,
      orderId: orderId,
      grade: grade,
      comment: comment,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// create 페이로드. **createdAt 은 serverTimestamp** (Rules 가 request.time 강제).
  /// 코멘트가 없으면 `comment` 키 자체를 보내지 않는다.
  static Map<String, dynamic> toFirestoreForCreate({
    required String storeId,
    required String userId,
    required String orderId,
    required StoreGrade grade,
    String? comment,
  }) {
    return {
      'storeId': storeId,
      'userId': userId,
      'orderId': orderId,
      'grade': grade.asString,
      'score': grade.score,
      'comment': ?comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// update 페이로드. 허용 필드 `grade / score / comment / orderId / updatedAt` 만.
  /// 코멘트가 없으면 `FieldValue.delete()` 로 기존 코멘트를 제거한다.
  static Map<String, dynamic> toFirestoreForUpdate({
    required String orderId,
    required StoreGrade grade,
    String? comment,
  }) {
    return {
      'orderId': orderId,
      'grade': grade.asString,
      'score': grade.score,
      'comment': comment ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
