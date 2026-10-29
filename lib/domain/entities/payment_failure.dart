import 'package:qradar/core/errors/verify_payment_failure.dart';

/// 결제 실패의 세 갈래 (design D3). 돈의 상태가 다르므로 문구와 버튼이 달라야 한다.
enum PaymentFailureFamily {
  /// A. 결제창 단계 실패 (Toss errorCode). 돈이 안 나갔다.
  launch,

  /// B. 서버 게이트 거절. Toss confirm **전**이라 돈이 안 나갔다.
  gate,

  /// C. 확인 단계의 알 수 없는 실패. 돈의 상태를 **모른다**.
  unknown,
}

/// 서버 게이트가 보내는 알려진 거절 사유 9개 (payment_server_authority spec §15.1 의 6개 +
/// payment_price_authority §9-1 의 금액 사유 2개). 목록 밖은 [unknown] → 갈래 C.
enum PaymentFailureReason {
  storeNotSellable('STORE_NOT_SELLABLE'),
  storeTemporarilyClosed('STORE_TEMPORARILY_CLOSED'),
  storeNotFound('STORE_NOT_FOUND'),
  menuSoldOut('MENU_SOLD_OUT'),
  menuExcluded('MENU_EXCLUDED'),
  menuNotFound('MENU_NOT_FOUND'),
  priceMismatch('PRICE_MISMATCH'),
  optionUnavailable('OPTION_UNAVAILABLE'),
  readFailed('READ_FAILED'),
  unknown('');

  const PaymentFailureReason(this.token);

  final String token;

  /// 토큰이 `menuItemId` 를 싣는 사유 (메뉴 사유 3종 + 금액 사유 2종 — 메뉴 사유 계열, payment_price_authority R11).
  bool get isMenuReason =>
      this == menuSoldOut ||
      this == menuExcluded ||
      this == menuNotFound ||
      this == priceMismatch ||
      this == optionUnavailable;

  static PaymentFailureReason? fromToken(String token) {
    for (final r in values) {
      if (r != unknown && r.token == token) return r;
    }
    return null;
  }
}

/// 결제 실패 화면의 **유일한 입력** (design §3.0). 순수 Dart.
///
/// 화면에 그리는 문자열은 코드 안 상수 + 고객 카트의 값뿐이다. 이 객체는 서버가 보낸 문자열(예외 toString,
/// FirebaseFunctionsException.message, Toss errorMessage)을 **담지 않는다**. [menuItemIds] 는 카트 조회 키이며
/// 출력되지 않는다. [rawCode] 는 형식 검증(`^[A-Z][A-Z0-9_]{2,39}$`)을 통과한 식별자뿐이다.
class PaymentFailure {
  const PaymentFailure._({
    required this.family,
    required this.reason,
    this.menuItemIds = const [],
    this.launchCode,
    this.rawCode,
  });

  final PaymentFailureFamily family;

  /// [family] == gate 일 때만 의미가 있다. 그 외에는 [PaymentFailureReason.unknown].
  final PaymentFailureReason reason;

  /// 메뉴 사유 계열([PaymentFailureReason.isMenuReason])일 때 토큰에서 파싱한 id (id 정규식 통과분만, 중복은 페이지가 제거).
  final List<String> menuItemIds;

  /// family == launch 일 때 Toss errorCode (문구 매핑 키로만 쓴다).
  final String? launchCode;

  /// 문의 코드 캡션용. 형식 검증을 통과한 토큰/코드만. 원문이 아니다.
  final String? rawCode;

  /// 갈래 A. [errorCode] 는 매핑 키로만 쓰고 [errorMessage] 는 받지도 않는다.
  factory PaymentFailure.launch({String? errorCode}) {
    final code = errorCode != null && _codeRe.hasMatch(errorCode)
        ? errorCode
        : null;
    return PaymentFailure._(
      family: PaymentFailureFamily.launch,
      reason: PaymentFailureReason.unknown,
      launchCode: code,
      rawCode: code,
    );
  }

  /// `verifyAndCreateOrder` 등에서 잡은 예외 → 갈래 B/C.
  ///
  /// 입력은 [VerifyPaymentFailure.message] (또는 임의 객체의 `toString()`) 이며 **끝의 토큰만** 읽는다.
  /// 알려진 9개 → 갈래 B. 그 밖(토큰 없음·모르는 토큰·파싱 불가)은 모두 갈래 C — 돈이 안 나갔다고 잘못 말하느니
  /// 확인을 시킨다 (design D4).
  factory PaymentFailure.from(Object error) {
    final text = error is VerifyPaymentFailure
        ? error.message
        : error.toString();
    final m = _tokenRe.firstMatch(text.trimRight());
    if (m == null) {
      return const PaymentFailure._(
        family: PaymentFailureFamily.unknown,
        reason: PaymentFailureReason.unknown,
      );
    }
    final token = m.namedGroup('reason')!;
    final reason = PaymentFailureReason.fromToken(token);
    if (reason == null) {
      return PaymentFailure._(
        family: PaymentFailureFamily.unknown,
        reason: PaymentFailureReason.unknown,
        rawCode: token,
      );
    }
    final ids = <String>[];
    if (reason.isMenuReason) {
      for (final piece in (m.namedGroup('ids') ?? '').split(',')) {
        if (_idRe.hasMatch(piece) && !ids.contains(piece)) ids.add(piece);
      }
    }
    return PaymentFailure._(
      family: PaymentFailureFamily.gate,
      reason: reason,
      menuItemIds: List.unmodifiable(ids),
      rawCode: token,
    );
  }

  /// spec §15.1 문법 (message 끝).
  static final RegExp _tokenRe = RegExp(
    r'\[(?<reason>[A-Z][A-Z0-9_]{2,39})(?::(?<ids>[A-Za-z0-9_,-]{1,2048}))?\]$',
  );
  static final RegExp _idRe = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final RegExp _codeRe = RegExp(r'^[A-Z][A-Z0-9_]{2,39}$');
}
