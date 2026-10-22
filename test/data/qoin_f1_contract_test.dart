import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/data/datasources/remote/qoin_remote_data_source.dart';
import 'package:qradar/data/repositories/payment_gateway_repository_impl.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';

/// F1 재발 방지 (spec §19.1 T2 / F3).
///
/// 이 기능에서 가장 아픈 결함은 "앱이 보내지 않는 키를 서버가 신뢰원으로 읽었다" 였다 (`cart.brandId`).
/// 앱이 `verifyTossPayment` 로 보내는 cart 의 키 집합을 골든으로 고정한다. 서버(TS) 쪽 테스트가 **같은 파일**을 읽어
/// `data.cart` 에서 소비하는 키 집합과 비교한다 — 한쪽만 바뀌면 골든이 깨져 대조가 강제된다.
void main() {
  final golden =
      (jsonDecode(
                File(
                  'test_fixtures/qoin_cart_contract.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['keys']
          .cast<String>()
          .toList()
        ..sort();

  test('T2: _cartToMap 이 보내는 최상위 키 집합 = 골든 (brandId 는 의도적으로 없다)', () {
    const cart = CartEntity(
      storeId: 's1',
      storeName: '강남점',
      subtotal: 4500,
      items: [
        CartItemEntity(
          cartItemId: 'c1',
          menuItemId: 'm1',
          menuItemName: '아메리카노',
          quantity: 1,
          unitPriceWithOptions: 4500,
          lineTotal: 4500,
        ),
      ],
    );
    final keys = PaymentGatewayRepositoryImpl.cartToMap(cart).keys.toList()
      ..sort();
    expect(keys, golden);
    expect(keys.contains('brandId'), isFalse);
  });

  test('CartEntity 에는 brandId 필드가 없다 (추가하면 "앱이 보내는 브랜드" 라는 거짓 권위가 생긴다)', () {
    final src = File('lib/domain/entities/cart_entity.dart').readAsStringSync();
    expect(src.contains('brandId'), isFalse);
  });

  test('F3: 비상 정지 쓰기 맵은 enabled + 행위자(uid) + 시각을 한 번에 싣는다', () {
    final m = QoinRemoteDataSource.buildEnabledWrite(
      enabled: false,
      uid: 'adminUid',
    );
    expect(m.keys.toSet(), {'enabled', 'enabledChangedBy', 'enabledChangedAt'});
    expect(m['enabled'], false);
    expect(m['enabledChangedBy'], 'adminUid');
    // 적립률 필드는 절대 싣지 않는다 (Rules 가 accrualRate 변경을 막는다).
    expect(m.containsKey('accrualRate'), isFalse);
  });
}
