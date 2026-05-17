/// 같은 scope 내 동일 이름(normalized)의 부 카테고리가 이미 존재할 때 throw.
class DuplicateSubCategoryNameException implements Exception {
  final String name;
  final String scope; // 'brand' | 'store'

  const DuplicateSubCategoryNameException({
    required this.name,
    required this.scope,
  });

  @override
  String toString() =>
      'DuplicateSubCategoryNameException: name=$name, scope=$scope';
}
