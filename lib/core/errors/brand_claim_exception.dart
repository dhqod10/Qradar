/// `claimSubmittedBrand` 실패 분류 (brand_authorization_hardening D1).
///
/// 서버는 같은 에러 코드라도 사유(`details.reason`, 또는 message 끝의 `[reason]`)로 구분해 보낸다 —
/// `failed-precondition` 은 "이미 다른 브랜드에 연결" 과 "브랜드 계정이 아님" 두 가지라 코드만으로는 오분류된다.
///
/// - [alreadyLinked]    이미 다른 브랜드가 연결된 계정 (`already_linked`). 재시도 불가 — 교정은 admin 전담이다 (D4).
/// - [notSubmitter]     이 브랜드를 제출한 계정이 아니다 (`permission-denied`). 재시도 불가.
/// - [notBrandAccount]  계정 역할이 브랜드가 아니다 (`not_brand_account`). 재시도 불가.
/// - [brandMissing]     연결하려던 브랜드 문서가 없다 (`not-found`). `다시 연결` 은 같은 실패를 되풀이하므로 **다시 확인**(재조회)만 준다.
/// - [retryable]        그 밖의 실패 (네트워크 · 서버 오류 …). 브랜드 문서는 이미 있으므로 **다시 연결**하면 된다 (멱등 callable).
enum BrandClaimFailure {
  alreadyLinked,
  notSubmitter,
  notBrandAccount,
  brandMissing,
  retryable,
}

class BrandClaimException implements Exception {
  const BrandClaimException(this.kind, {this.code});
  final BrandClaimFailure kind;

  /// 서버 에러 코드 (`permission-denied` 등). 네트워크 오류면 null.
  final String? code;

  /// `다시 연결` 을 줘도 결과가 바뀌지 않는 실패인가.
  bool get isTerminal => kind != BrandClaimFailure.retryable;

  /// 서버 에러 코드 + 사유 -> 분류. [reason] 은 `details['reason']` 이거나 message 끝 `[reason]` 에서 뽑은 값이다.
  /// 사유 없는 `failed-precondition` 은 **어느 쪽인지 모르므로** 재시도 가능으로 둔다(잘못 "이미 연결" 이라 말하지 않는다).
  static BrandClaimFailure classify(String code, {String? reason}) {
    switch (reason) {
      case 'already_linked':
        return BrandClaimFailure.alreadyLinked;
      case 'not_brand_account':
        return BrandClaimFailure.notBrandAccount;
      case 'not_submitter':
        return BrandClaimFailure.notSubmitter;
      case 'brand_not_found':
        return BrandClaimFailure.brandMissing;
    }
    switch (code) {
      case 'permission-denied':
        return BrandClaimFailure.notSubmitter;
      case 'not-found':
        return BrandClaimFailure.brandMissing;
      default:
        return BrandClaimFailure.retryable;
    }
  }

  /// message 끝의 `[reason]` 토큰 (details 가 Map 으로 오지 않는 환경 대비).
  static String? reasonFromMessage(String? message) {
    if (message == null) return null;
    final m = RegExp(r'\[([a-z_]+)\]\s*$').firstMatch(message);
    return m?.group(1);
  }

  @override
  String toString() => 'BrandClaimException($kind, $code)';
}
