import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/selected_option.dart';

part 'order_item_entity.freezed.dart';

/// 주문 라인 한 건.
@freezed
abstract class OrderItemEntity with _$OrderItemEntity {
  const factory OrderItemEntity({
    required String menuItemId,
    required String menuItemName,
    @Default('') String imageUrl,
    required int quantity,
    @Default(<SelectedOption>[]) List<SelectedOption> selectedOptions,
    required int unitPriceWithOptions,
    required int lineTotal,
  }) = _OrderItemEntity;
}
