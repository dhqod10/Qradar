import 'package:qradar/domain/repositories/payment_gateway_repository.dart';

class CancelPaidOrderUseCase {
  final PaymentGatewayRepository _repo;
  const CancelPaidOrderUseCase(this._repo);

  Future<void> call({
    required String orderId,
    required String reason,
    required String approvedBy,
  }) {
    return _repo.cancelPaidOrder(
      orderId: orderId,
      reason: reason,
      approvedBy: approvedBy,
    );
  }
}
