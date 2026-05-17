/// 메인 카테고리가 사용 중일 때 hard delete 를 시도하면 throw 되는 예외.
class MainCategoryInUseException implements Exception {
  final String categoryId;
  final int usageCount;

  const MainCategoryInUseException({
    required this.categoryId,
    required this.usageCount,
  });

  @override
  String toString() =>
      'MainCategoryInUseException: categoryId=$categoryId, usageCount=$usageCount';
}
