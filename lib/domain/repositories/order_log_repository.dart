import 'package:qradar/domain/entities/order_log_entity.dart';

/// 주문 내역(Log) Repository 인터페이스.
///
/// **본 phase(1a)에서는 인터페이스만 정의.** Impl 은 결제 phase(3) 에서 작성.
abstract class OrderLogRepository {
  /// 결제 완료 시 1건 기록.
  Future<void> appendLog(OrderLogEntity log);

  /// 사용자 주문 내역 stream. paidAt desc.
  Stream<List<OrderLogEntity>> watchUserLogs(String userId);
}
