import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

class WatchStoreOrdersUseCase {
  final OrderRepository _repo;
  const WatchStoreOrdersUseCase(this._repo);

  Stream<List<OrderEntity>> call(
    String storeId, {
    Set<OrderStatus>? statusFilter,
  }) =>
      _repo.watchStoreOrders(storeId, statusFilter: statusFilter);
}
