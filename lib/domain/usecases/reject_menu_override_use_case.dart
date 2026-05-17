import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// admin 가격 오버라이드 반려 UseCase.
class RejectMenuOverrideUseCase {
  final MenuOverrideRepository _repository;

  RejectMenuOverrideUseCase(this._repository);

  Future<void> call(
    String storeId,
    String masterMenuItemId,
    String adminUid,
    String reason,
  ) {
    return _repository.rejectOverride(
        storeId, masterMenuItemId, adminUid, reason);
  }
}
