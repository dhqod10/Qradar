// TRANSITIONAL(brand_authorization_hardening §4): 임시 점검 자산. 정리 커밋에서 이 파일째 삭제한다.

/// `auditBrandLinks` 의 분류. 서버 코드와 같은 이름이다.
enum BrandLinkClass {
  dangling('dangling'),
  duplicate('duplicate'),
  storeDanglingBrand('store_dangling_brand'),
  storeUnapprovedBrand('store_unapproved_brand'),
  mismatch('mismatch'),
  orphanBrand('orphan_brand'),
  ok('ok'),
  okOnboarding('ok_onboarding');

  const BrandLinkClass(this.code);
  final String code;

  static BrandLinkClass? fromCode(String code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// 점검 결과의 항목 1건. 분류에 따라 쓰이는 필드가 다르다 (계정 / 브랜드 / 매장).
class BrandLinkAuditItem {
  const BrandLinkAuditItem({
    this.uid,
    this.email,
    this.storeId,
    this.storeName,
    this.brandId,
    this.brandName,
    this.submittedBy,
    this.status,
  });
  final String? uid;
  final String? email;
  final String? storeId;
  final String? storeName;
  final String? brandId;
  final String? brandName;
  final String? submittedBy;
  final String? status;
}

/// `auditBrandLinks` 결과. **읽기 전용 보고**다 — 자동 교정은 없다. 건수는 0 도 보존한다 (빠진 분류가 "없음" 인지
/// "안 보여준 것" 인지 헷갈리지 않게).
class BrandLinkAuditResult {
  const BrandLinkAuditResult({
    required this.counts,
    required this.items,
    required this.truncated,
    required this.checkedAt,
  });

  /// 8개 분류 전부의 건수.
  final Map<BrandLinkClass, int> counts;

  /// 분류별 항목 (최대 100건). `ok` / `okOnboarding` 은 항상 비어 있다 (건수만).
  final Map<BrandLinkClass, List<BrandLinkAuditItem>> items;

  /// 건수가 목록보다 많은 분류 (서버가 100건에서 잘랐다).
  final Set<BrandLinkClass> truncated;
  final DateTime checkedAt;

  int count(BrandLinkClass c) => counts[c] ?? 0;
  List<BrandLinkAuditItem> itemsOf(BrandLinkClass c) => items[c] ?? const [];

  /// 바로 교정이 필요한 묶음.
  static const List<BrandLinkClass> fixNow = [
    BrandLinkClass.dangling,
    BrandLinkClass.duplicate,
    BrandLinkClass.storeDanglingBrand,
    BrandLinkClass.storeUnapprovedBrand,
  ];

  /// 사람이 판단해야 하는 묶음.
  static const List<BrandLinkClass> judge = [
    BrandLinkClass.mismatch,
    BrandLinkClass.orphanBrand,
  ];

  int get fixNowTotal => fixNow.fold(0, (a, c) => a + count(c));
  int get judgeTotal => judge.fold(0, (a, c) => a + count(c));
  bool get allClear => fixNowTotal == 0 && judgeTotal == 0;
}
