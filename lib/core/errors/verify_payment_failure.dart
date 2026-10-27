/// `verifyTossPayment` 호출 실패를 **code + message 보존**으로 data 레이어가 던지는 예외.
///
/// 서버 게이트(payment_server_authority spec §15.1)는 거절 시
/// `HttpsError(code, "<사람 문장> [REASON:ids]")` 를 던진다. 기존 `_convertFunctionsException` 은 `unavailable` 에서
/// message 를 버리고 다른 코드에서는 원문을 문장에 섞어 `READ_FAILED` 토큰이 사라졌다. 이 예외는 토큰이 살아서
/// presentation 의 `PaymentFailure.from` 까지 가도록 한다 (presentation 은 `cloud_functions` 를 import 할 수 없다).
///
/// **[message] 는 화면에 그리지 않는다.** 토큰 파싱 입력으로만 쓰인다 (design D4). [toString] 도 message 를 싣지 않는다.
class VerifyPaymentFailure implements Exception {
  const VerifyPaymentFailure({required this.code, required this.message});

  /// `FirebaseFunctionsException.code` (예: `failed-precondition`, `unavailable`).
  final String code;

  /// `FirebaseFunctionsException.message` 원문. 끝에 `[REASON]` 토큰이 붙을 수 있다.
  final String message;

  @override
  String toString() => 'VerifyPaymentFailure(code: $code)';
}
