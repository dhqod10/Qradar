import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// admin 매장 승인 큐: status=pending 매장 실시간 스트림 UseCase.
class WatchPendingStoresForAdminUseCase {
  final StoreRepository _repository;

  WatchPendingStoresForAdminUseCase(this._repository);

  Stream<List<StoreEntity>> call() {
    return _repository.watchPendingStoresForAdmin();
  }
}
