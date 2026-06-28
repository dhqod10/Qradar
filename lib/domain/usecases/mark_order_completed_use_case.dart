import 'package:qradar/domain/repositories/order_repository.dart';

/// 점주가 픽업 완료를 확정한다 (ready → completed).
class MarkOrderCompletedUseCase {
  final OrderRepository _repo;
  const MarkOrderCompletedUseCase(this._repo);

  Future<void> call(String orderId) => _repo.markOrderCompleted(orderId);
}
