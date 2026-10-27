/// 신규 브랜드 등록에서 **부모 문서는 만들어졌는데** 비공개 프로필(PII) 쓰기가 실패한 경우.
///
/// 그냥 던지면 폼이 같은 입력으로 다시 저장해 부모 문서를 또 만든다(고아 브랜드).
/// [brandId] 로 폼이 이미 만들어진 브랜드를 기억해 재시도를 "수정" 경로로 보낸다.
class BrandPrivateProfileSaveException implements Exception {
  const BrandPrivateProfileSaveException(this.brandId);
  final String brandId;

  @override
  String toString() => 'BrandPrivateProfileSaveException(brandId: $brandId)';
}
