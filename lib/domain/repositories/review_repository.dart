import 'package:qradar/domain/entities/review_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// 매장 평가 Repository 인터페이스.
abstract class ReviewRepository {
  /// 매장 평가 목록 stream (최신순).
  Stream<List<ReviewEntity>> watchStoreReviews(String storeId, {int limit});

  /// 내가 이 매장에 남긴 평가 (없으면 null).
  Stream<ReviewEntity?> watchMyReview({
    required String storeId,
    required String userId,
  });

  /// 평가 작성/수정 (upsert). 문서 ID 는 `{storeId}_{userId}`.
  /// 존재하지 않으면 create, 존재하면 update 로 분기한다.
  /// [comment] 가 null 이면 코멘트 없음(수정 시 기존 코멘트 제거).
  Future<void> upsertReview({
    required String storeId,
    required String userId,
    required String orderId,
    required StoreGrade grade,
    String? comment,
  });
}
