import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/data/datasources/local/cart_local_data_source.dart';
import 'package:qradar/data/repositories/cart_repository_impl.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/usecases/add_to_cart_use_case.dart';

/// test_report F-01 — 카트 라인 병합은 서버 수량 규칙(1~99)을 넘기지 않고, 잘렸다는 사실을 호출자에게 돌려준다.
CartItemEntity _line(String id, int qty) => CartItemEntity(
  cartItemId: id,
  menuItemId: 'm1',
  menuItemName: '아메리카노',
  quantity: qty,
  unitPriceWithOptions: 4000,
  lineTotal: 4000 * qty,
);

void main() {
  test('60 + 60 = 99 로 잘리고 true 를 돌려준다 (서버가 거절하는 120 이 만들어지지 않는다)', () {
    final ds = CartLocalDataSource();
    expect(
      ds.addItem(storeId: 's', storeName: 'n', item: _line('a', 60)),
      isFalse,
    );
    final clamped = ds.addItem(
      storeId: 's',
      storeName: 'n',
      item: _line('b', 60),
    );
    expect(clamped, isTrue);
    final line = ds.current!.items.single;
    expect(line.quantity, kMaxLineQuantity);
    expect(line.lineTotal, 4000 * 99, reason: '합계도 99 기준');
    expect(ds.current!.subtotal, 4000 * 99);
    expect(isValidLineQuantity(line.quantity), isTrue);
  });

  test('정확히 99 가 되는 병합은 잘린 것이 아니다', () {
    final ds = CartLocalDataSource();
    ds.addItem(storeId: 's', storeName: 'n', item: _line('a', 98));
    expect(
      ds.addItem(storeId: 's', storeName: 'n', item: _line('b', 1)),
      isFalse,
    );
    expect(ds.current!.items.single.quantity, 99);
  });

  test('이미 99 인 라인에 더 담으면 잘림 신호 (수량은 그대로 99)', () {
    final ds = CartLocalDataSource();
    ds.addItem(storeId: 's', storeName: 'n', item: _line('a', 99));
    expect(
      ds.addItem(storeId: 's', storeName: 'n', item: _line('b', 1)),
      isTrue,
    );
    expect(ds.current!.items.single.quantity, 99);
  });

  test('UseCase 가 잘림 신호를 그대로 전달한다 (화면이 고객에게 알리는 근거)', () async {
    final uc = AddToCartUseCase(CartRepositoryImpl(CartLocalDataSource()));
    expect(
      await uc(storeId: 's', storeName: 'n', item: _line('a', 80)),
      isFalse,
    );
    expect(
      await uc(storeId: 's', storeName: 'n', item: _line('b', 80)),
      isTrue,
    );
  });
}
