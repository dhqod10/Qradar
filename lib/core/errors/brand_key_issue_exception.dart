/// `issueBrandKey` 호출 실패. admin 승인은 이 실패 시 **상태를 바꾸지 않고** 중단한다 (키 없는 승인 금지).
///
/// 서버 문자열을 싣지 않는다 (화면에 새지 않게).
class BrandKeyIssueException implements Exception {
  const BrandKeyIssueException({this.code});

  /// `FirebaseFunctionsException.code`. 네트워크 오류면 null.
  final String? code;

  @override
  String toString() => 'BrandKeyIssueException(code: $code)';
}
