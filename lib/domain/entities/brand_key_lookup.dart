/// `lookupBrandByKey` 의 성공 결과 — 승인된 브랜드의 공개 정보만. PII·brandKey 는 돌려주지 않는다.
class BrandKeyLookup {
  const BrandKeyLookup({
    required this.brandId,
    required this.name,
    this.logoUrl = '',
  });

  final String brandId;
  final String name;
  final String logoUrl;
}
