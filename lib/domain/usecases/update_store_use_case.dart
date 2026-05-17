import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

class UpdateStoreUseCase {
  final StoreRepository _repository;
  UpdateStoreUseCase(this._repository);

  Future<void> call(StoreEntity store) => _repository.updateStore(store);
}
