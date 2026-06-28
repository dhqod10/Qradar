import 'package:qradar/domain/repositories/order_repository.dart';

/// 점주가 주문 조리를 시작한다 (accepted → making).
class StartMakingOrderUseCase {
  final OrderRepository _repo;
  const StartMakingOrderUseCase(this._repo);

  Future<void> call(String orderId) => _repo.startMakingOrder(orderId);
}
