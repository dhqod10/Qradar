/// 옵션 그룹이 사용 중일 때 hard delete 를 시도하면 throw 되는 예외.
class OptionGroupInUseException implements Exception {
  final String optionGroupId;
  final int usageCount;

  const OptionGroupInUseException({
    required this.optionGroupId,
    required this.usageCount,
  });

  @override
  String toString() =>
      'OptionGroupInUseException: optionGroupId=$optionGroupId, usageCount=$usageCount';
}
