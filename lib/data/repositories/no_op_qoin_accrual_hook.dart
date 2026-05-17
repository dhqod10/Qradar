import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/repositories/qoin_accrual_hook.dart';

/// Phase 3a 용 NoOp 구현. Phase 4 에서 real 구현체로 교체.
class NoOpQoinAccrualHook implements QoinAccrualHook {
  const NoOpQoinAccrualHook();

  @override
  Future<void> onOrderPaid(OrderEntity order) async {}

  @override
  Future<void> onOrderRefunded(OrderEntity order) async {}
}
