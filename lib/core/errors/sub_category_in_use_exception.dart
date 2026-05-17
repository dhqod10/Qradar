/// 부 카테고리가 사용 중일 때 hard delete 를 시도하면 throw 되는 예외.
class SubCategoryInUseException implements Exception {
  final String subCategoryId;
  final int usageCount;

  const SubCategoryInUseException({
    required this.subCategoryId,
    required this.usageCount,
  });

  @override
  String toString() =>
      'SubCategoryInUseException: subCategoryId=$subCategoryId, usageCount=$usageCount';
}
