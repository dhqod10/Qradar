import 'package:qradar/domain/repositories/store_repository.dart';

/// admin 매장 반려 UseCase.
class RejectStoreUseCase {
  final StoreRepository _repository;

  RejectStoreUseCase(this._repository);

  Future<void> call(String storeId, String adminUid, String reason) {
    return _repository.rejectStore(storeId, adminUid, reason);
  }
}
