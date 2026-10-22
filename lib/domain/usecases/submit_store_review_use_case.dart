import 'package:qradar/core/errors/review_submit_exception.dart';
import 'package:qradar/core/utils/review_window.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/repositories/review_repository.dart';

/// 매장 평가 작성/수정 (upsert).
///
/// 자격 검증(주문 completed / 본인 / 매장 일치 / 14일)을 수행한 뒤 저장한다.
/// 보안 경계는 Firestore Rules(14일 제외), 14일 기한은 여기(UI 정책)에서만 강제.
class SubmitStoreReviewUseCase {
  final ReviewRepository _repo;
  const SubmitStoreReviewUseCase(this._repo);

  Future<void> call({
    required String storeId,
    required String userId,
    required OrderEntity order,
    required StoreGrade grade,
    String? comment,
    DateTime? now,
  }) async {
    validateEligibility(
      storeId: storeId,
      userId: userId,
      order: order,
      now: now ?? DateTime.now(),
    );
    final trimmed = comment?.trim();
    await _repo.upsertReview(
      storeId: storeId,
      userId: userId,
      orderId: order.id,
      grade: grade,
      comment: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }

  /// 자격 검증. 실패 시 [ReviewSubmitException].
  static void validateEligibility({
    required String storeId,
    required String userId,
    required OrderEntity order,
    required DateTime now,
  }) {
    if (order.status != OrderStatus.completed) {
      throw const ReviewSubmitException(ReviewSubmitFailure.orderNotCompleted);
    }
    if (order.userId != userId) {
      throw const ReviewSubmitException(ReviewSubmitFailure.notOrderOwner);
    }
    if (order.storeId != storeId) {
      throw const ReviewSubmitException(ReviewSubmitFailure.storeMismatch);
    }
    if (ReviewWindow.isExpired(order.completedAt, now)) {
      throw const ReviewSubmitException(ReviewSubmitFailure.windowExpired);
    }
  }
}
