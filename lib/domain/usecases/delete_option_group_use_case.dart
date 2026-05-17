import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';

/// 옵션 그룹 삭제 UseCase.
///
/// 사용 중 (usageCount >= 1) 이면 [OptionGroupInUseException] throw.
class DeleteOptionGroupUseCase {
  final OptionGroupRepository _repository;
  DeleteOptionGroupUseCase(this._repository);

  Future<void> call({
    required OptionScope scope,
    required String id,
    String? brandId,
    String? storeId,
  }) =>
      _repository.delete(
        scope: scope,
        id: id,
        brandId: brandId,
        storeId: storeId,
      );
}
