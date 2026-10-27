/// `deleteStore` 호출 실패 분류 (payment_server_authority D1, design §7.2).
enum StoreDeletionFailure {
  /// 진행 중인 주문이 있다 (`failed-precondition` + `[STORE_HAS_INFLIGHT_ORDERS]`).
  /// 미리보기에서는 0건이었는데 실행 시 생긴 경쟁이면 "방금 새 주문이 들어왔어요" 변형이 된다.
  inFlightOrders,

  /// 매장도 삭제 이력도 없다 (`not-found`).
  notFound,

  /// 그 밖의 실패 (중간 실패 포함). 같은 매장 재호출이 이어서 진행한다 (멱등).
  failed,
}

class StoreDeletionException implements Exception {
  const StoreDeletionException(this.kind, {this.code});
  final StoreDeletionFailure kind;

  /// `FirebaseFunctionsException.code`. 네트워크 오류면 null.
  final String? code;

  /// 서버 문자열을 싣지 않는다 (화면에 새지 않게).
  @override
  String toString() => 'StoreDeletionException(${kind.name}, code: $code)';
}
