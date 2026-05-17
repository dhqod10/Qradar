import 'package:qradar/domain/repositories/store_repository.dart';

/// admin 매장 승인 UseCase.
class ApproveStoreUseCase {
  final StoreRepository _repository;

  ApproveStoreUseCase(this._repository);

  Future<void> call(String storeId, String adminUid) {
    return _repository.approveStore(storeId, adminUid);
  }
}
