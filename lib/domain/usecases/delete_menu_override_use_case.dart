import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// 가격 오버라이드 삭제 UseCase (brand 전용).
class DeleteMenuOverrideUseCase {
  final MenuOverrideRepository _repository;

  DeleteMenuOverrideUseCase(this._repository);

  Future<void> call(String storeId, String masterMenuItemId) {
    return _repository.deleteOverride(storeId, masterMenuItemId);
  }
}
