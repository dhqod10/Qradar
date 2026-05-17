import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';

/// 카트 Repository 인터페이스.
///
/// **본 phase(1a)에서는 인터페이스만 정의.** Impl 은 Phase 1b 에서 작성.
abstract class CartRepository {
  /// 현재 사용자 활성 카트 stream. 비었거나 없으면 null.
  Stream<CartEntity?> watchActiveCart();

  /// 카트에 라인 추가. 다른 매장 카트가 있을 경우 호출자가 충돌 처리.
  Future<void> addItem({
    required String storeId,
    required String storeName,
    required CartItemEntity item,
  });

  /// 라인 수량 변경 (0 이면 제거).
  Future<void> updateQuantity({
    required String cartItemId,
    required int quantity,
  });

  /// 라인 단건 제거.
  Future<void> removeItem(String cartItemId);

  /// 카트 전체 비우기.
  Future<void> clearCart();
}
