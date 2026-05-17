import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';

part 'cart_entity.freezed.dart';

/// 활성 카트 (1 매장).
///
/// 본 phase 에서는 인터페이스 호환용으로만 정의. 실제 사용은 Phase 1b.
@freezed
abstract class CartEntity with _$CartEntity {
  const factory CartEntity({
    required String storeId,
    required String storeName,
    @Default(<CartItemEntity>[]) List<CartItemEntity> items,
    @Default(0) int subtotal,
  }) = _CartEntity;
}
