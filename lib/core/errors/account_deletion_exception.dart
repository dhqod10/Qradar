/// `deleteMyAccount` 호출 실패 분류 (account_deletion design §3-5).
enum AccountDeletionFailure {
  /// 진행 중인 주문이 있다 (`failed-precondition` + `[ACCOUNT_HAS_INFLIGHT_ORDERS]`).
  inFlightOrders,

  /// 로그인 정보가 없거나 만료됐다 (`unauthenticated`).
  unauthenticated,

  /// 그 밖의 실패 (네트워크/서버/중간 실패). 재호출이 이어서 진행한다 (멱등).
  failed,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.kind, {this.code, this.inFlightOrders});
  final AccountDeletionFailure kind;

  /// `FirebaseFunctionsException.code`. 네트워크 오류면 null.
  final String? code;

  /// 서버가 details 로 준 진행 중 주문 수 (없으면 null — 화면은 미리보기를 다시 읽는다).
  final int? inFlightOrders;

  /// 서버 문자열을 싣지 않는다 (화면에 새지 않게).
  @override
  String toString() => 'AccountDeletionException(${kind.name}, code: $code)';
}
