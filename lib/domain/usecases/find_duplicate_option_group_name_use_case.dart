import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';

/// 동일 scope 내 옵션 그룹 이름 중복 여부 조회 UseCase.
class FindDuplicateOptionGroupNameUseCase {
  final OptionGroupRepository _repository;
  FindDuplicateOptionGroupNameUseCase(this._repository);

  Future<bool> call({
    required String name,
    required OptionScope scope,
    String? brandId,
    String? storeId,
    String? excludeId,
  }) =>
      _repository.findDuplicateName(
        name: name,
        scope: scope,
        brandId: brandId,
        storeId: storeId,
        excludeId: excludeId,
      );
}
