/// 문의 상태. Firestore 직렬화는 `.name`.
///
/// 모르는 문자열은 [closed] 로 읽는다 — 추가 액션(철회 등)을 노출하지 않는 안전한 쪽.
enum SupportInquiryStatus {
  /// 접수 (답변 대기). 고객이 철회할 수 있는 유일한 상태.
  open('접수'),

  /// 답변 완료.
  answered('답변 완료'),

  /// 종결 (관리자 종결 / 작성자 탈퇴).
  closed('종결'),

  /// 고객이 답변 전에 철회.
  withdrawn('철회');

  const SupportInquiryStatus(this.label);

  final String label;

  static SupportInquiryStatus fromCode(String? code) {
    return SupportInquiryStatus.values.firstWhere(
      (e) => e.name == code,
      orElse: () => SupportInquiryStatus.closed,
    );
  }
}
