/// 문의 유형. Firestore 직렬화는 `.name`.
///
/// 모르는 문자열은 [etc] 로 읽는다 (안전한 쪽).
enum SupportInquiryCategory {
  order('주문'),
  refund('환불'),
  qoin('Qoin'),
  account('계정'),
  store('매장'),
  bug('앱 오류'),
  etc('기타');

  const SupportInquiryCategory(this.label);

  /// 화면 표시 라벨 (칩/목록/상세 공통).
  final String label;

  static SupportInquiryCategory fromCode(String? code) {
    return SupportInquiryCategory.values.firstWhere(
      (e) => e.name == code,
      orElse: () => SupportInquiryCategory.etc,
    );
  }
}
