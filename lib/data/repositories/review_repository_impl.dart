import 'package:qradar/data/datasources/remote/review_remote_data_source.dart';
import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/repositories/review_repository.dart';

/// [ReviewRepository] 구현체. DataSource 외 직접 Firestore 접근 금지.
class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource _ds;
  ReviewRepositoryImpl(this._ds);

  @override
  Stream<List<ReviewEntity>> watchStoreReviews(
    String storeId, {
    int limit = 50,
  }) {
    return _ds
        .streamByStore(storeId, limit: limit)
        .map((list) => list.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Stream<ReviewEntity?> watchMyReview({
    required String storeId,
    required String userId,
  }) {
    return _ds.streamMine(storeId, userId).map((m) => m?.toEntity());
  }

  @override
  Future<void> upsertReview({
    required String storeId,
    required String userId,
    required String orderId,
    required StoreGrade grade,
    String? comment,
  }) {
    return _ds.upsert(
      storeId: storeId,
      userId: userId,
      orderId: orderId,
      grade: grade,
      comment: comment,
    );
  }
}
