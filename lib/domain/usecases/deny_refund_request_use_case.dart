import 'package:qradar/domain/repositories/order_repository.dart';

class DenyRefundRequestUseCase {
  final OrderRepository _repo;
  const DenyRefundRequestUseCase(this._repo);

  Future<void> call({
    required String orderId,
    required String deniedReason,
  }) {
    return _repo.denyRefundRequest(orderId, deniedReason);
  }
}
