import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';

/// 옵션 그룹 active 토글 UseCase.
class ToggleOptionGroupActiveUseCase {
  final OptionGroupRepository _repository;
  ToggleOptionGroupActiveUseCase(this._repository);

  Future<void> call({
    required OptionScope scope,
    required String id,
    required bool active,
    String? brandId,
    String? storeId,
  }) =>
      _repository.toggleActive(
        scope: scope,
        id: id,
        active: active,
        brandId: brandId,
        storeId: storeId,
      );
}
