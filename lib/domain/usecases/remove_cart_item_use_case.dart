import 'package:qradar/domain/repositories/cart_repository.dart';

class RemoveCartItemUseCase {
  final CartRepository _repository;
  RemoveCartItemUseCase(this._repository);

  Future<void> call(String cartItemId) =>
      _repository.removeItem(cartItemId);
}
