import 'package:qradar/core/constants/sales_query_limits.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/sales_period.dart';
import 'package:qradar/domain/entities/sales_summary_entity.dart';
import 'package:qradar/domain/entities/store_sales_entity.dart';
import 'package:qradar/domain/repositories/order_repository.dart';

/// 점주 매장의 기간 매출 조회.
///
/// I/O 는 [OrderRepository.getStoreOrdersInPeriod] 1회, 집계는
/// [aggregateStoreSales] 순수 함수. S5(CF 집계) 전환 시 데이터 획득부만 교체한다.
class GetStoreSalesUseCase {
  final OrderRepository _repo;
  const GetStoreSalesUseCase(this._repo);

  Future<StoreSalesEntity> call({
    required String storeId,
    required SalesPeriod period,
  }) async {
    const limit = SalesQueryLimits.maxDocumentsPerQuery;
    final orders = await _repo.getStoreOrdersInPeriod(
      storeId,
      startInclusive: period.start,
      endExclusive: period.endExclusive,
      limit: limit,
    );
    return StoreSalesEntity(
      summary: aggregateStoreSales(orders, period),
      orders: orders,
      isTruncated: orders.length >= limit,
    );
  }
}

/// 주문 목록 → 매출 요약. **매출 합산 로직이 존재하는 유일한 곳** (spec §8).
///
/// - 총 매출 = completed + 진행 중(paid/accepted/making/ready) 의 `totalPrice` 합.
/// - refunded / cancelled 는 총 매출에서 제외. 환불 금액은
///   `refundInfo.amount`, 없으면 `totalPrice` 로 fallback.
/// - `refundRequest` 만 있고 status 가 refunded 가 아닌 주문은 매출에 포함.
/// - 평균 객단가는 정수 나눗셈(버림), 건수 0 이면 0.
SalesSummaryEntity aggregateStoreSales(
  List<OrderEntity> orders,
  SalesPeriod period,
) {
  var confirmedSales = 0;
  var confirmedCount = 0;
  var inProgressSales = 0;
  var inProgressCount = 0;
  var refundedAmount = 0;
  var refundedCount = 0;
  var cancelledCount = 0;

  for (final o in orders) {
    switch (o.status) {
      case OrderStatus.completed:
        confirmedSales += o.totalPrice;
        confirmedCount++;
      case OrderStatus.paid:
      case OrderStatus.accepted:
      case OrderStatus.making:
      case OrderStatus.ready:
        inProgressSales += o.totalPrice;
        inProgressCount++;
      case OrderStatus.refunded:
        refundedAmount += o.refundInfo?.amount ?? o.totalPrice;
        refundedCount++;
      case OrderStatus.cancelled:
        cancelledCount++;
    }
  }

  final netSales = confirmedSales + inProgressSales;
  final orderCount = confirmedCount + inProgressCount;
  return SalesSummaryEntity(
    period: period,
    netSales: netSales,
    orderCount: orderCount,
    averageOrderValue: orderCount == 0 ? 0 : netSales ~/ orderCount,
    confirmedSales: confirmedSales,
    confirmedCount: confirmedCount,
    inProgressSales: inProgressSales,
    inProgressCount: inProgressCount,
    refundedAmount: refundedAmount,
    refundedCount: refundedCount,
    cancelledCount: cancelledCount,
  );
}
