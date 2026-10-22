import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/sales_summary_entity.dart';

part 'store_sales_entity.freezed.dart';

/// 매출 화면이 소비하는 단일 결과. (S5 CF 집계 전환 시 경계)
@freezed
abstract class StoreSalesEntity with _$StoreSalesEntity {
  const factory StoreSalesEntity({
    required SalesSummaryEntity summary,

    /// 기간 내 전체 주문 (createdAt 내림차순, 환불·취소 포함).
    required List<OrderEntity> orders,

    /// 조회 상한에 걸려 일부만 집계했는가.
    required bool isTruncated,
  }) = _StoreSalesEntity;
}
