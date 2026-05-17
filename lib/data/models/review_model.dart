import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// Firestore reviews/{reviewId} 문서 매퍼.
class ReviewModel {
  final String id;
  final String storeId;
  final String userId;
  final StoreGrade grade;
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.grade,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtTs = data['createdAt'] as Timestamp?;
    return ReviewModel(
      id: doc.id,
      storeId: (data['storeId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      grade: StoreGrade.fromString((data['grade'] as String?) ?? 'C'),
      comment: data['comment'] as String?,
      createdAt: createdAtTs?.toDate() ?? DateTime.now(),
    );
  }

  ReviewEntity toEntity() {
    return ReviewEntity(
      id: id,
      storeId: storeId,
      userId: userId,
      grade: grade,
      comment: comment,
      createdAt: createdAt,
    );
  }
}
