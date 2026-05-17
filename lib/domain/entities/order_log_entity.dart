import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/selected_option.dart';

part 'order_log_entity.freezed.dart';

/// 주문 내역 (Qradar 용어: **Log**) 한 건.
///
/// 본 phase 에서는 인터페이스 호환용. 실제 사용/저장은 결제 phase.
@freezed
abstract class OrderLogItem with _$OrderLogItem {
  const factory OrderLogItem({
    required String menuItemId,
    required String menuItemName,
    required int quantity,
    @Default(<SelectedOption>[]) List<SelectedOption> optionsSnapshot,
    required int lineTotal,
  }) = _OrderLogItem;
}

@freezed
abstract class OrderLogEntity with _$OrderLogEntity {
  const factory OrderLogEntity({
    required String id,
    required String userId,
    required String storeId,
    required String storeName,
    @Default(<OrderLogItem>[]) List<OrderLogItem> items,
    required int total,
    required DateTime paidAt,
    @Default('') String paymentMethod,
  }) = _OrderLogEntity;
}
