import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/repositories/order_log_repository.dart';

/// 결제 완료 시 OrderLog 1건 기록.
///
/// Phase 2 에서는 시드가 DataSource 를 직접 호출하므로 본 UseCase 는 호출되지 않는다.
/// Phase 3 결제 콜백에서 hook 만 추가하면 동작한다.
class WriteOrderLogUseCase {
  final OrderLogRepository _repository;
  WriteOrderLogUseCase(this._repository);

  Future<void> call(OrderLogEntity log) => _repository.appendLog(log);
}
