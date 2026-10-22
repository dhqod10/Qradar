/// `claimSubmittedBrand` 실패 분류 (brand_authorization_hardening D1).
///
/// - [alreadyLinked]  이미 다른 브랜드가 연결된 계정 (`failed-precondition`). 재시도 불가 — 교정은 admin 전담이다 (D4).
/// - [notSubmitter]   이 브랜드를 제출한 계정이 아니다 (`permission-denied`). 재시도 불가.
/// - [retryable]      그 밖의 모든 실패 (네트워크 · 서버 오류 · 브랜드 문서 일시 미존재 …). 브랜드 문서는 이미 있으므로
///                    **다시 등록하지 말고 다시 연결**하면 된다 (멱등 callable).
enum BrandClaimFailure { alreadyLinked, notSubmitter, retryable }

class BrandClaimException implements Exception {
  const BrandClaimException(this.kind, {this.code});
  final BrandClaimFailure kind;

  /// 서버 에러 코드 (`permission-denied` 등). 네트워크 오류면 null.
  final String? code;

  /// 사용자가 다시 시도해도 결과가 바뀌지 않는 실패인가.
  bool get isTerminal => kind != BrandClaimFailure.retryable;

  @override
  String toString() => 'BrandClaimException($kind, $code)';
}
