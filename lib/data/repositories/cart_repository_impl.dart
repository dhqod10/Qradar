import 'package:qradar/data/datasources/local/cart_local_data_source.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  final CartLocalDataSource _local;

  CartRepositoryImpl(this._local);

  @override
  Stream<CartEntity?> watchActiveCart() => _local.watch();

  @override
  Future<void> addItem({
    required String storeId,
    required String storeName,
    required CartItemEntity item,
  }) async {
    _local.addItem(storeId: storeId, storeName: storeName, item: item);
  }

  @override
  Future<void> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    _local.updateQuantity(cartItemId: cartItemId, quantity: quantity);
  }

  @override
  Future<void> removeItem(String cartItemId) async {
    _local.removeItem(cartItemId);
  }

  @override
  Future<void> clearCart() async {
    _local.clearCart();
  }
}
