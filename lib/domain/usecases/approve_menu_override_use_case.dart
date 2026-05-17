import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// admin 가격 오버라이드 승인 UseCase.
class ApproveMenuOverrideUseCase {
  final MenuOverrideRepository _repository;

  ApproveMenuOverrideUseCase(this._repository);

  Future<void> call(
    String storeId,
    String masterMenuItemId,
    String adminUid,
  ) {
    return _repository.approveOverride(storeId, masterMenuItemId, adminUid);
  }
}
