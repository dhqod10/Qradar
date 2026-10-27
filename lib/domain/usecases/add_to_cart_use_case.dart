import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/repositories/cart_repository.dart';

class AddToCartUseCase {
  final CartRepository _repository;
  AddToCartUseCase(this._repository);

  /// 수량 상한에 걸려 잘렸으면 true.
  Future<bool> call({
    required String storeId,
    required String storeName,
    required CartItemEntity item,
  }) {
    return _repository.addItem(
      storeId: storeId,
      storeName: storeName,
      item: item,
    );
  }
}
