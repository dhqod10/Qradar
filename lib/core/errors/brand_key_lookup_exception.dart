/// brandKey 조회 실패 분류 (payment_server_authority B1, design §5.4).
///
/// 세 갈래는 **화면 문구가 서로 다르다** — 특히 [failed] 를 [notFound] 로 읽으면 "키가 틀렸다" 고 오해시킨다.
enum BrandKeyLookupFailure {
  /// 존재하지 않거나 미승인(서버는 두 경우를 구분하지 않는다) 또는 형식 불일치.
  notFound,

  /// 조회 횟수 초과 (`resource-exhausted`).
  rateLimited,

  /// 네트워크·서버·타임아웃·미인증 등 — 조회 자체를 하지 못했다.
  failed,
}

class BrandKeyLookupException implements Exception {
  const BrandKeyLookupException(this.kind);
  final BrandKeyLookupFailure kind;

  /// 서버 문자열을 싣지 않는다 (화면에 새지 않게).
  @override
  String toString() => 'BrandKeyLookupException(${kind.name})';
}
