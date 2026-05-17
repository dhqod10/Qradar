import 'package:qradar/domain/repositories/option_group_repository.dart';

/// 특정 옵션 그룹을 사용 중인 메뉴 수 조회 UseCase.
class CountOptionGroupUsageUseCase {
  final OptionGroupRepository _repository;
  CountOptionGroupUsageUseCase(this._repository);

  Future<int> call(String optionGroupId) =>
      _repository.countUsage(id: optionGroupId);
}
