/// 브랜드 / 마스터 메뉴 아이템의 승인 상태.
///
/// `approvedAt != null && status == pending` 이면 "수정 대기" (S3 정책).
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
