import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/repositories/review_repository.dart';

/// 매장 평가 목록 (최신순, 상한 [defaultLimit]).
class GetStoreReviewsUseCase {
  static const int defaultLimit = 50;

  final ReviewRepository _repo;
  const GetStoreReviewsUseCase(this._repo);

  Stream<List<ReviewEntity>> call(String storeId, {int limit = defaultLimit}) =>
      _repo.watchStoreReviews(storeId, limit: limit);
}
