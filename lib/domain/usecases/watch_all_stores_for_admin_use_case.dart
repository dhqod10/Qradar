import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// admin 전체 매장 실시간 감시 UseCase (status 무관).
class WatchAllStoresForAdminUseCase {
  final StoreRepository _repository;

  WatchAllStoresForAdminUseCase(this._repository);

  Stream<List<StoreEntity>> call() {
    return _repository.watchAllForAdmin();
  }
}
