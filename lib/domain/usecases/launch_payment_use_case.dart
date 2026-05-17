import 'package:flutter/widgets.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';

class LaunchPaymentUseCase {
  final PaymentGatewayRepository _repo;
  const LaunchPaymentUseCase(this._repo);

  Future<PaymentLaunchResult> call({
    required BuildContext context,
    required PaymentMethod method,
    required String idempotencyKey,
    required int amount,
    required String orderName,
    required String customerEmail,
    required String customerName,
  }) {
    return _repo.launchPayment(
      context: context,
      method: method,
      idempotencyKey: idempotencyKey,
      amount: amount,
      orderName: orderName,
      customerEmail: customerEmail,
      customerName: customerName,
    );
  }
}
