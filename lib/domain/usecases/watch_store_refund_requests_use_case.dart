import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

class WatchStoreRefundRequestsUseCase {
  final OrderRepository _repo;
  const WatchStoreRefundRequestsUseCase(this._repo);

  Stream<List<OrderEntity>> call(String storeId) =>
      _repo.watchStoreRefundRequests(storeId);
}
