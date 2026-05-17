/// 사용자 역할.
///
/// 로그인한 모든 사용자는 `users/{uid}.role` 필드로 이 값을 갖는다.
/// 기본값은 `customer` — 더보기에서 "점주로 등록하기" 를 거치면 `owner` 로 전환.
/// `brand` / `admin` 은 Firestore 콘솔에서 수동 발급.
enum UserRole {
  customer,
  owner,
  brand,
  admin;

  /// Firestore 에 저장되는 문자열.
  String get asString => name;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'brand':
        return UserRole.brand;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      case null:
      default:
        return UserRole.customer;
    }
  }
}
