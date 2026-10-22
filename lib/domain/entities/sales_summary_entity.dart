import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/sales_period.dart';

part 'sales_summary_entity.freezed.dart';

/// 기간 매출 집계 결과. 화면은 이 값을 그대로 표시만 한다 (합산 금지).
///
/// 총 매출 = 결제 성공 전체(진행 중 포함), 환불·취소 제외 (spec D1 / D2).
@freezed
abstract class SalesSummaryEntity with _$SalesSummaryEntity {
  const factory SalesSummaryEntity({
    required SalesPeriod period,

    /// 총 매출 (completed + 진행 중).
    required int netSales,

    /// 집계 대상 주문 건수 (completed + 진행 중).
    required int orderCount,

    /// 평균 객단가 (버림). 건수 0 이면 0.
    required int averageOrderValue,
    required int confirmedSales,
    required int confirmedCount,
    required int inProgressSales,
    required int inProgressCount,
    required int refundedAmount,
    required int refundedCount,
    required int cancelledCount,
  }) = _SalesSummaryEntity;
}
