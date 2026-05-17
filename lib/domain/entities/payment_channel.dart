/// 결제 PG(Payment Gateway) enum.
///
/// Phase 3a 는 [toss] 만 사용.
enum PaymentChannel {
  /// 토스페이먼츠.
  toss;

  static PaymentChannel fromCode(String? code) {
    return PaymentChannel.values.firstWhere(
      (e) => e.name == code,
      orElse: () => PaymentChannel.toss,
    );
  }
}
