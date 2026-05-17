import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';

class VerifyAndCreateOrderUseCase {
  final PaymentGatewayRepository _repo;
  const VerifyAndCreateOrderUseCase(this._repo);

  Future<OrderEntity> call({
    required String paymentKey,
    required String orderId,
    required int amount,
    required CartEntity cartSnapshot,
    required String uid,
  }) {
    return _repo.verifyAndCreateOrder(
      paymentKey: paymentKey,
      orderId: orderId,
      amount: amount,
      cartSnapshot: cartSnapshot,
      uid: uid,
    );
  }
}
