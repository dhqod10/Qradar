/// 결제 수단 enum.
///
/// Phase 3a 사용: [card], [kakaoPay].
/// Phase 3b 확장: 나머지.
///
/// Firestore 직렬화: `.name` (camelCase String).
enum PaymentMethod {
  /// 신용/체크카드 직접 입력.
  card,

  /// 카카오페이 간편결제.
  kakaoPay,

  /// 네이버페이 (Phase 3b).
  naverPay,

  /// 토스페이 간편결제 (Phase 3b).
  tossPay,

  /// 삼성페이 (Phase 3b).
  samsungPay,

  /// 애플페이 (Phase 3b).
  applePay,

  /// 계좌이체 (Phase 3b).
  bankTransfer,

  /// 휴대폰결제 (Phase 3b).
  mobile,

  /// 페이코 (Phase 3b).
  payco;

  static PaymentMethod fromCode(String? code) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == code,
      orElse: () => PaymentMethod.card,
    );
  }

  /// UI 표시 라벨.
  String get label {
    switch (this) {
      case PaymentMethod.card:
        return '신용/체크카드';
      case PaymentMethod.kakaoPay:
        return '카카오페이';
      case PaymentMethod.naverPay:
        return '네이버페이';
      case PaymentMethod.tossPay:
        return '토스페이';
      case PaymentMethod.samsungPay:
        return '삼성페이';
      case PaymentMethod.applePay:
        return '애플페이';
      case PaymentMethod.bankTransfer:
        return '계좌이체';
      case PaymentMethod.mobile:
        return '휴대폰결제';
      case PaymentMethod.payco:
        return 'PAYCO';
    }
  }
}
