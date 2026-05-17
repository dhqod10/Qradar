import 'package:qradar/core/errors/duplicate_option_group_name_exception.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';

/// 옵션 그룹 등록/수정 UseCase.
///
/// 저장 전 동일 scope/context 내 이름 중복 검사를 수행한다.
/// 중복 시 [DuplicateOptionGroupNameException] throw.
class UpsertOptionGroupUseCase {
  final OptionGroupRepository _repository;
  UpsertOptionGroupUseCase(this._repository);

  Future<void> call(OptionGroupEntity entity) async {
    // submit 시점 race condition 방지 최종 중복 검사
    final isDuplicate = await _repository.findDuplicateName(
      name: entity.name,
      scope: entity.scope,
      brandId: entity.brandId,
      storeId: entity.storeId,
      excludeId: entity.id.isEmpty ? null : entity.id,
    );
    if (isDuplicate) {
      throw DuplicateOptionGroupNameException(
        name: entity.name,
        scope: entity.scope.asString,
      );
    }
    await _repository.upsert(entity);
  }
}
