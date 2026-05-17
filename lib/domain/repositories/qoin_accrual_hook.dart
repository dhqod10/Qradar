import 'package:qradar/domain/entities/order_entity.dart';

/// Qoin 적립/회수 hook 인터페이스.
///
/// Phase 3a 는 [NoOpQoinAccrualHook] 으로 주입 (아무것도 하지 않음).
/// Phase 4 에서 real 구현체로 교체.
abstract class QoinAccrualHook {
  /// 결제 성공 시 호출. Phase 4 에서 Qoin 적립 로직 구현.
  Future<void> onOrderPaid(OrderEntity order);

  /// 환불/취소 시 호출. Phase 4 에서 Qoin 회수 로직 구현.
  Future<void> onOrderRefunded(OrderEntity order);
}
