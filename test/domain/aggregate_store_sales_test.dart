import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/domain/entities/payment_channel.dart';
import 'package:qradar/domain/entities/payment_info_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/domain/entities/refund_info_entity.dart';
import 'package:qradar/domain/entities/refund_request_entity.dart';
import 'package:qradar/domain/entities/sales_period.dart';
import 'package:qradar/domain/usecases/get_store_sales_use_case.dart';

final _period = SalesPeriod.day(DateTime.utc(2026, 10, 21, 3));

OrderEntity _order(
  OrderStatus status,
  int price, {
  RefundInfoEntity? refundInfo,
  RefundRequestEntity? refundRequest,
}) {
  return OrderEntity(
    id: '${status.name}-$price',
    userId: 'u',
    storeId: 's',
    storeName: 'store',
    subtotal: price,
    totalPrice: price,
    status: status,
    paymentInfo: PaymentInfoEntity(
      method: PaymentMethod.card,
      channel: PaymentChannel.toss,
      paymentKey: 'pk',
      transactionId: 'tx',
      approvedAt: DateTime.utc(2026, 10, 21),
      amount: price,
    ),
    refundInfo: refundInfo,
    refundRequest: refundRequest,
    createdAt: DateTime.utc(2026, 10, 21),
    updatedAt: DateTime.utc(2026, 10, 21),
  );
}

void main() {
  test('0건: 모두 0, 평균 0', () {
    final s = aggregateStoreSales(const [], _period);
    expect(s.netSales, 0);
    expect(s.orderCount, 0);
    expect(s.averageOrderValue, 0);
    expect(s.refundedCount, 0);
    expect(s.cancelledCount, 0);
    expect(s.period, _period);
  });

  test('completed + 진행 중 4종 포함, refunded/cancelled 제외', () {
    final s = aggregateStoreSales([
      _order(OrderStatus.completed, 10000),
      _order(OrderStatus.paid, 1000),
      _order(OrderStatus.accepted, 2000),
      _order(OrderStatus.making, 3000),
      _order(OrderStatus.ready, 4000),
      _order(OrderStatus.refunded, 5000),
      _order(OrderStatus.cancelled, 6000),
    ], _period);
    expect(s.netSales, 20000);
    expect(s.orderCount, 5);
    expect(s.confirmedSales, 10000);
    expect(s.confirmedCount, 1);
    expect(s.inProgressSales, 10000);
    expect(s.inProgressCount, 4);
    expect(s.refundedAmount, 5000);
    expect(s.refundedCount, 1);
    expect(s.cancelledCount, 1);
  });

  test('평균 객단가는 버림', () {
    final s = aggregateStoreSales([
      _order(OrderStatus.completed, 1000),
      _order(OrderStatus.completed, 1000),
      _order(OrderStatus.completed, 1001),
    ], _period);
    expect(s.netSales, 3001);
    expect(s.averageOrderValue, 1000); // 3001 ~/ 3
  });

  test('refundInfo 있으면 그 amount, 없으면 totalPrice fallback', () {
    final withInfo = _order(
      OrderStatus.refunded,
      5000,
      refundInfo: RefundInfoEntity(
        cancellationKey: 'k',
        reason: 'r',
        approvedBy: 'owner',
        processedAt: DateTime.utc(2026, 10, 22),
        amount: 3000,
      ),
    );
    final noInfo = _order(OrderStatus.refunded, 7000);
    final s = aggregateStoreSales([withInfo, noInfo], _period);
    expect(s.refundedAmount, 10000);
    expect(s.refundedCount, 2);
    expect(s.netSales, 0);
  });

  test('refundRequest 만 있고 refunded 가 아니면 매출에 포함 (거절 포함)', () {
    final requested = _order(
      OrderStatus.completed,
      4000,
      refundRequest: RefundRequestEntity(
        reason: 'r',
        requestedAt: DateTime.utc(2026, 10, 21),
      ),
    );
    final denied = _order(
      OrderStatus.accepted,
      6000,
      refundRequest: RefundRequestEntity(
        reason: 'r',
        requestedAt: DateTime.utc(2026, 10, 21),
        deniedAt: DateTime.utc(2026, 10, 21),
        deniedReason: 'no',
      ),
    );
    final s = aggregateStoreSales([requested, denied], _period);
    expect(s.netSales, 10000);
    expect(s.refundedCount, 0);
  });
}
