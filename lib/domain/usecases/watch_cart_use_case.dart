import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/repositories/cart_repository.dart';

class WatchCartUseCase {
  final CartRepository _repository;
  WatchCartUseCase(this._repository);

  Stream<CartEntity?> call() => _repository.watchActiveCart();
}
