import 'package:qradar/domain/repositories/payment_gateway_repository.dart';

class ProcessRefundUseCase {
  final PaymentGatewayRepository _repo;
  const ProcessRefundUseCase(this._repo);

  Future<void> call({required String orderId, required String reason}) {
    return _repo.processRefund(orderId: orderId, reason: reason);
  }
}
