import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/repositories/review_repository.dart';

/// 내가 이 매장에 남긴 평가 (없으면 null).
class GetMyStoreReviewUseCase {
  final ReviewRepository _repo;
  const GetMyStoreReviewUseCase(this._repo);

  Stream<ReviewEntity?> call({
    required String storeId,
    required String userId,
  }) => _repo.watchMyReview(storeId: storeId, userId: userId);
}
