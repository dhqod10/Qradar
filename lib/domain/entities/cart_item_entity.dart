import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/selected_option.dart';

part 'cart_item_entity.freezed.dart';

/// 카트 라인 1건.
///
/// 본 phase 에서는 인터페이스 호환용으로만 정의. 실제 사용은 Phase 1b.
@freezed
abstract class CartItemEntity with _$CartItemEntity {
  const factory CartItemEntity({
    required String cartItemId,
    required String menuItemId,
    required String menuItemName,
    @Default('') String imageUrl,
    required int quantity,
    @Default(<SelectedOption>[]) List<SelectedOption> selectedOptions,
    required int unitPriceWithOptions,
    required int lineTotal,
  }) = _CartItemEntity;
}
