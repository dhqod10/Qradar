import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

/// 매장의 진행 중 주문(paid / accepted / making / ready) 건수 1회 조회.
/// 점주 임시 휴업 전환 가드 (temporary_closed_gate R5) 용. 조회 실패 시 예외를 그대로 전파한다.
class CountActiveStoreOrdersUseCase {
  final OrderRepository _repo;
  const CountActiveStoreOrdersUseCase(this._repo);

  static const activeStatuses = {
    OrderStatus.paid,
    OrderStatus.accepted,
    OrderStatus.making,
    OrderStatus.ready,
  };

  Future<int> call(String storeId) =>
      _repo.countStoreOrdersByStatuses(storeId, activeStatuses);
}
