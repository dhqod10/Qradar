/// 브랜드 비공개 프로필 — Firestore `brands/{brandId}/private/profile`.
///
/// 부모 `brands/{id}` 는 로그인 사용자 전원이 읽는다. 여기에는 그 부모에 둘 수 없는 것만 있다:
/// 가맹 신청의 열쇠(brandKey)와 사업자 PII. 읽기는 admin / 해당 브랜드 보유자만 가능하다.
///
/// - [brandKey] 는 **읽기 전용**이다 (`issueBrandKey` CF 전담). 이 엔티티를 저장 입력으로 쓸 때도
///   data 레이어는 brandKey 를 쓰지 않는다.
/// - PII 5개 중 [headOfficeAddress] / [representativeName] 은 선택이라 null 일 수 있다.
class BrandPrivateProfileEntity {
  const BrandPrivateProfileEntity({
    this.brandKey = '',
    this.businessRegistrationNumber = '',
    this.contactName = '',
    this.contactPhone = '',
    this.headOfficeAddress,
    this.representativeName,
  });

  /// 발급된 브랜드 키. 미발급이면 빈 문자열.
  final String brandKey;

  /// 사업자등록번호 000-00-00000 (필수).
  final String businessRegistrationNumber;

  /// 담당자 이름 (필수).
  final String contactName;

  /// 담당자 연락처 (필수).
  final String contactPhone;

  /// 본사 주소 (선택).
  final String? headOfficeAddress;

  /// 대표자 이름 (선택).
  final String? representativeName;

  bool get hasBrandKey => brandKey.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is BrandPrivateProfileEntity &&
      other.brandKey == brandKey &&
      other.businessRegistrationNumber == businessRegistrationNumber &&
      other.contactName == contactName &&
      other.contactPhone == contactPhone &&
      other.headOfficeAddress == headOfficeAddress &&
      other.representativeName == representativeName;

  @override
  int get hashCode => Object.hash(
    brandKey,
    businessRegistrationNumber,
    contactName,
    contactPhone,
    headOfficeAddress,
    representativeName,
  );
}
