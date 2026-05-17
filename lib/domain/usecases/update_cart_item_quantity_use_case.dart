import 'package:qradar/domain/repositories/cart_repository.dart';

class UpdateCartItemQuantityUseCase {
  final CartRepository _repository;
  UpdateCartItemQuantityUseCase(this._repository);

  Future<void> call({
    required String cartItemId,
    required int quantity,
  }) {
    return _repository.updateQuantity(
      cartItemId: cartItemId,
      quantity: quantity,
    );
  }
}
