import 'dart:async';

import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';

/// 카트 in-memory 저장소.
///
/// 앱 재시작 시 초기화 (Phase 1b 비범위: 영속화).
/// 활성 카트는 1개 매장만 보유. 다른 매장 추가 시 호출자가 사전에 [clearCart] 후 [addItem] 한다.
class CartLocalDataSource {
  CartEntity? _current;
  final StreamController<CartEntity?> _controller =
      StreamController<CartEntity?>.broadcast();

  CartEntity? get current => _current;

  Stream<CartEntity?> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  void _emit(CartEntity? next) {
    _current = next;
    _controller.add(next);
  }

  /// 동일 (menuItemId, selectedOptions key) 라인이 있으면 quantity 증가, 아니면 새 라인.
  /// storeId 가 다르면 ArgumentError. 호출자는 사전에 [clearCart] 했어야 함.
  ///
  /// 병합 수량은 [kMaxLineQuantity] 로 자른다. **자르면 true 를 돌려준다** — 호출자가 고객에게 알려야 한다
  /// (조용히 잘리면 "왜 2개가 사라졌지" 가 된다).
  bool addItem({
    required String storeId,
    required String storeName,
    required CartItemEntity item,
  }) {
    final existing = _current;
    if (existing != null && existing.storeId != storeId) {
      throw ArgumentError(
        'CartLocalDataSource.addItem: storeId mismatch '
        '(active=${existing.storeId}, incoming=$storeId). '
        'Caller must clear cart before switching stores.',
      );
    }
    final base = existing ??
        CartEntity(
          storeId: storeId,
          storeName: storeName,
          items: const <CartItemEntity>[],
          subtotal: 0,
        );
    final dedupKey = _dedupKey(item);
    final mergedItems = <CartItemEntity>[];
    var merged = false;
    var clamped = false;
    for (final line in base.items) {
      if (!merged && _dedupKey(line) == dedupKey) {
        final newQty = mergeLineQuantity(line.quantity, item.quantity);
        clamped = line.quantity + item.quantity > kMaxLineQuantity;
        mergedItems.add(line.copyWith(
          quantity: newQty,
          lineTotal: computeLineTotal(
            unitPrice: line.unitPriceWithOptions,
            quantity: newQty,
          ),
        ));
        merged = true;
      } else {
        mergedItems.add(line);
      }
    }
    if (!merged) mergedItems.add(item);
    _emit(base.copyWith(
      items: mergedItems,
      subtotal: _subtotal(mergedItems),
    ));
    return clamped;
  }

  /// quantity ≤ 0 이면 라인 제거. 마지막 라인이 사라지면 카트 자체 null 로.
  void updateQuantity({
    required String cartItemId,
    required int quantity,
  }) {
    final cart = _current;
    if (cart == null) return;
    if (quantity <= 0) {
      removeItem(cartItemId);
      return;
    }
    final updated = cart.items
        .map((line) => line.cartItemId == cartItemId
            ? line.copyWith(
                quantity: quantity,
                lineTotal: computeLineTotal(
                  unitPrice: line.unitPriceWithOptions,
                  quantity: quantity,
                ),
              )
            : line)
        .toList(growable: false);
    _emit(cart.copyWith(items: updated, subtotal: _subtotal(updated)));
  }

  /// 재가격: 라인 단가를 새 값으로 바꾸고 합계는 `cart_pricing.dart` 의 식으로 다시 만든다.
  /// 바뀐 라인이 없으면 emit 하지 않는다 (불필요한 리빌드·선검증 연쇄 방지).
  void applyUnitPrices(Map<String, int> unitPriceByCartItemId) {
    final cart = _current;
    if (cart == null || unitPriceByCartItemId.isEmpty) return;
    var changed = false;
    final updated = cart.items
        .map((line) {
          final next = unitPriceByCartItemId[line.cartItemId];
          if (next == null || next == line.unitPriceWithOptions) return line;
          changed = true;
          return line.copyWith(
            unitPriceWithOptions: next,
            lineTotal: computeLineTotal(
              unitPrice: next,
              quantity: line.quantity,
            ),
          );
        })
        .toList(growable: false);
    if (!changed) return;
    _emit(cart.copyWith(items: updated, subtotal: _subtotal(updated)));
  }

  void removeItem(String cartItemId) {
    final cart = _current;
    if (cart == null) return;
    final remaining = cart.items
        .where((l) => l.cartItemId != cartItemId)
        .toList(growable: false);
    if (remaining.isEmpty) {
      _emit(null);
      return;
    }
    _emit(cart.copyWith(items: remaining, subtotal: _subtotal(remaining)));
  }

  void clearCart() {
    if (_current == null) return;
    _emit(null);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  static String _dedupKey(CartItemEntity item) {
    final ids = item.selectedOptions
        .map((o) => '${o.groupId}:${o.itemId}')
        .toList()
      ..sort();
    return '${item.menuItemId}|${ids.join(',')}';
  }

  static int _subtotal(List<CartItemEntity> items) =>
      sumLineTotals(items.map((it) => it.lineTotal));
}
