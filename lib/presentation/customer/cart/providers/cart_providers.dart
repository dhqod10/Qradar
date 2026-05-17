import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/local/cart_local_data_source.dart';
import 'package:qradar/data/repositories/cart_repository_impl.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/repositories/cart_repository.dart';
import 'package:qradar/domain/usecases/add_to_cart_use_case.dart';
import 'package:qradar/domain/usecases/clear_cart_use_case.dart';
import 'package:qradar/domain/usecases/remove_cart_item_use_case.dart';
import 'package:qradar/domain/usecases/update_cart_item_quantity_use_case.dart';
import 'package:qradar/domain/usecases/watch_cart_use_case.dart';

// ── DI ────────────────────────────────────────────────────────────────────────

final cartLocalDataSourceProvider = Provider<CartLocalDataSource>((ref) {
  final ds = CartLocalDataSource();
  ref.onDispose(ds.dispose);
  return ds;
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepositoryImpl(ref.watch(cartLocalDataSourceProvider));
});

final watchCartUseCaseProvider = Provider<WatchCartUseCase>((ref) {
  return WatchCartUseCase(ref.watch(cartRepositoryProvider));
});

final addToCartUseCaseProvider = Provider<AddToCartUseCase>((ref) {
  return AddToCartUseCase(ref.watch(cartRepositoryProvider));
});

final updateCartItemQuantityUseCaseProvider =
    Provider<UpdateCartItemQuantityUseCase>((ref) {
  return UpdateCartItemQuantityUseCase(ref.watch(cartRepositoryProvider));
});

final removeCartItemUseCaseProvider = Provider<RemoveCartItemUseCase>((ref) {
  return RemoveCartItemUseCase(ref.watch(cartRepositoryProvider));
});

final clearCartUseCaseProvider = Provider<ClearCartUseCase>((ref) {
  return ClearCartUseCase(ref.watch(cartRepositoryProvider));
});

// ── State ─────────────────────────────────────────────────────────────────────

/// 활성 카트 stream. 비어있으면 null emit.
final cartProvider = StreamProvider<CartEntity?>((ref) {
  return ref.watch(watchCartUseCaseProvider).call();
});

/// 합산 quantity (뱃지용). 카트 없으면 0.
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).value;
  if (cart == null) return 0;
  var sum = 0;
  for (final line in cart.items) {
    sum += line.quantity;
  }
  return sum;
});
