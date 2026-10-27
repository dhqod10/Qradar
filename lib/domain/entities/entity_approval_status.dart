/// 브랜드 / 마스터 메뉴 아이템의 승인 상태.
///
/// `approvedAt != null && status == pending` 이면 "수정 대기" (S3 정책).
///
/// `approvedAt` 은 **승인 행위에서만** 쓴다 (반려는 `rejectedAt` — payment_server_authority §6.8).
/// 그래서 위 조건은 "승인된 적이 있는 매장의 수정 대기" 를 정확히 뜻한다.
enum EntityApprovalStatus {
  pending,
  approved,
  rejected;

  /// Firestore 에 저장되는 문자열.
  String get asString => name;

  static EntityApprovalStatus fromString(String? v) {
    switch (v) {
      case 'pending':
        return EntityApprovalStatus.pending;
      case 'rejected':
        return EntityApprovalStatus.rejected;
      default:
        return EntityApprovalStatus.approved;
    }
  }
}
