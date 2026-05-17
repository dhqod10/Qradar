import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/repositories/cart_repository.dart';

class AddToCartUseCase {
  final CartRepository _repository;
  AddToCartUseCase(this._repository);

  Future<void> call({
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
