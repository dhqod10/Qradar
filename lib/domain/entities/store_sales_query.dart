import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/sales_period.dart';

part 'store_sales_query.freezed.dart';

/// `storeSalesProvider` family 키. 값 동등성으로 캐시가 동작한다.
@freezed
abstract class StoreSalesQuery with _$StoreSalesQuery {
  const factory StoreSalesQuery({
    required String storeId,
    required SalesPeriod period,
  }) = _StoreSalesQuery;
}
