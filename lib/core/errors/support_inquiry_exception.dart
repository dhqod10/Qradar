/// 고객센터 문의 실패 사유. 서버 raw message 는 화면에 싣지 않고 토큰으로만 분류한다.
enum SupportInquiryFailure {
  rateLimited,
  invalidInput,
  notFound,
  alreadyAnswered,
  notOwner,
  accountDeleted,
  orderNotFound,
  invalidAttachment,
  imageUploadFailed,
  network,
  unauthenticated,

  /// 철회가 Rules 에 거부됨 (그 사이 답변이 등록됨).
  withdrawRejected,
  failed,
}

class SupportInquiryException implements Exception {
  const SupportInquiryException(this.reason);

  final SupportInquiryFailure reason;

  @override
  String toString() => 'SupportInquiryException: $reason';
}
