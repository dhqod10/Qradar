import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

class WatchOrderUseCase {
  final OrderRepository _repo;
  const WatchOrderUseCase(this._repo);

  Stream<OrderEntity?> call(String orderId) => _repo.watchOrder(orderId);
}
