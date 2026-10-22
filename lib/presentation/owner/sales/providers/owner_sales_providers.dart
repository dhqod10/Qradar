import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/sales_period.dart';
import 'package:qradar/domain/entities/store_sales_entity.dart';
import 'package:qradar/domain/entities/store_sales_query.dart';
import 'package:qradar/domain/usecases/get_store_sales_use_case.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';

/// 매출 UseCase. (provider 는 반드시 top-level 선언 — build() 안 inline 금지)
final getStoreSalesUseCaseProvider = Provider<GetStoreSalesUseCase>((ref) {
  return GetStoreSalesUseCase(ref.watch(orderRepositoryProvider));
});

/// 현재 조회 기간. 단위(일/주/월)는 [SalesPeriod.type] 이 곧 선택 상태다.
///
/// OwnerScaffold 가 IndexedStack 이라 탭을 떠나도 유지된다.
final salesPeriodProvider = NotifierProvider<SalesPeriodNotifier, SalesPeriod>(
  SalesPeriodNotifier.new,
);

class SalesPeriodNotifier extends Notifier<SalesPeriod> {
  @override
  SalesPeriod build() => SalesPeriod.current(SalesPeriodType.day);

  /// 단위 변경 → 해당 단위의 현재 기간으로 리셋. 같은 단위 재탭은 무시.
  void selectType(SalesPeriodType type) {
    if (state.type == type) return;
    state = SalesPeriod.current(type);
  }

  void goPrevious() {
    if (!state.canGoPrevious()) return;
    state = state.previous();
  }

  void goNext() {
    if (!state.canGoNext()) return;
    state = state.next();
  }
}

/// 기간 매출. **키(storeId, period)가 바뀌면 이전 data 를 남기지 않고 loading**
/// 이 되며, 같은 키의 invalidate/refresh 만 기존 값을 유지한다.
///
/// autoDispose: 기간을 여러 번 바꿔도 캐시가 쌓이지 않는다.
final storeSalesProvider = FutureProvider.autoDispose
    .family<StoreSalesEntity, StoreSalesQuery>((ref, query) {
      return ref
          .read(getStoreSalesUseCaseProvider)
          .call(storeId: query.storeId, period: query.period);
    });
