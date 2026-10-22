/// 평가 제출 자격 검증 실패 사유.
enum ReviewSubmitFailure {
  /// 주문이 completed 가 아님.
  orderNotCompleted,

  /// 본인 주문이 아님.
  notOrderOwner,

  /// 주문의 매장과 평가 대상 매장이 다름.
  storeMismatch,

  /// 픽업 완료 후 14일 경과.
  windowExpired,
}

/// SubmitStoreReviewUseCase 의 자격 검증 실패.
class ReviewSubmitException implements Exception {
  const ReviewSubmitException(this.reason);

  final ReviewSubmitFailure reason;

  @override
  String toString() => 'ReviewSubmitException: $reason';
}
