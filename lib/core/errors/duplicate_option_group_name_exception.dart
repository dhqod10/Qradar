/// 같은 scope 내 동일 이름(normalized)의 옵션 그룹이 이미 존재할 때 throw.
class DuplicateOptionGroupNameException implements Exception {
  final String name;
  final String scope; // 'brand' | 'store'

  const DuplicateOptionGroupNameException({
    required this.name,
    required this.scope,
  });

  @override
  String toString() =>
      'DuplicateOptionGroupNameException: name=$name, scope=$scope';
}
