/// admin 이 brand 를 승인할 때 brandKey 자동 생성 중 충돌이 3회 연속 발생했을 때 던진다.
///
/// 32^8 ≈ 1.1조 조합 수로 실제 발생 확률은 0 에 가깝다.
/// admin 화면에서 이 예외를 catch 하여 "브랜드 키 발급에 실패했어요. 다시 시도해주세요" SnackBar 표시.
class BrandKeyCollisionException implements Exception {
  const BrandKeyCollisionException();

  @override
  String toString() =>
      'BrandKeyCollisionException: brandKey 자동 생성에 3회 모두 실패했습니다.';
}
