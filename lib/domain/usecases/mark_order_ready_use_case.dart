import 'package:qradar/domain/repositories/order_repository.dart';

/// 점주가 음료 준비 완료를 표시한다 (making → ready).
class MarkOrderReadyUseCase {
  final OrderRepository _repo;
  const MarkOrderReadyUseCase(this._repo);

  Future<void> call(String orderId) => _repo.markOrderReady(orderId);
}
