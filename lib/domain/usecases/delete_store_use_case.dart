import 'package:qradar/domain/repositories/store_repository.dart';

class DeleteStoreUseCase {
  final StoreRepository _repository;
  DeleteStoreUseCase(this._repository);

  Future<void> call(String storeId) => _repository.deleteStore(storeId);
}
