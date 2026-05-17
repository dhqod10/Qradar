import 'package:qradar/domain/repositories/order_repository.dart';

class AcceptOrderUseCase {
  final OrderRepository _repo;
  const AcceptOrderUseCase(this._repo);

  Future<void> call(String orderId) => _repo.setAcceptedByOwner(orderId);
}
