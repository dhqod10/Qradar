import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';
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
    required PaymentMethod paymentMethod,

    /// 사용할 Qoin (1 Qoin = 1원). 요청일 뿐 — 서버가 잔액·정책·서버 소계로 검증한다. 0 이면 기존 결제 흐름과 동일.
    int qoinToUse = 0,
  }) {
    return _repo.verifyAndCreateOrder(
      paymentKey: paymentKey,
      orderId: orderId,
      amount: amount,
      cartSnapshot: cartSnapshot,
      uid: uid,
      paymentMethod: paymentMethod,
      qoinToUse: qoinToUse,
    );
  }
}
