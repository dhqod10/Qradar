import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

class WatchMyStoreUseCase {
  final StoreRepository _repository;
  WatchMyStoreUseCase(this._repository);

  Stream<StoreEntity?> call(String ownerId) =>
      _repository.watchByOwner(ownerId);
}
