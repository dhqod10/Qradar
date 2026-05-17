import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

class WatchUserOrdersUseCase {
  final OrderRepository _repo;
  const WatchUserOrdersUseCase(this._repo);

  Stream<List<OrderEntity>> call(String userId) =>
      _repo.watchUserOrders(userId);
}
