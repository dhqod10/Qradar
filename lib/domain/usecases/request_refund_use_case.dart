import 'package:qradar/domain/repositories/order_repository.dart';

class RequestRefundUseCase {
  final OrderRepository _repo;
  const RequestRefundUseCase(this._repo);

  Future<void> call({required String orderId, required String reason}) {
    return _repo.requestRefund(orderId, reason);
  }
}
