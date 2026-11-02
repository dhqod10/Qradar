import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/data/datasources/remote/cloud_functions_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/qoin_remote_data_source.dart';
import 'package:qradar/data/repositories/payment_gateway_repository_impl.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/selected_option.dart';

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

  test('payment_price_authority §1-5: items[] 와 selectedOptions[] 의 키 집합 = 골든 (서버 CONSUMED_ITEM_KEYS / CONSUMED_OPTION_KEYS 와 같은 파일)', () {
    final full =
        jsonDecode(File('test_fixtures/qoin_cart_contract.json').readAsStringSync())
            as Map<String, dynamic>;
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
          selectedOptions: [
            SelectedOption(
              groupId: 'g1',
              groupName: '샷',
              itemId: 'i1',
              label: '샷 추가',
              priceDelta: 500,
            ),
          ],
        ),
      ],
    );
    final item =
        (PaymentGatewayRepositoryImpl.cartToMap(cart)['items'] as List).first
            as Map<String, dynamic>;
    expect(item.keys.toList()..sort(), (full['itemKeys'] as List).cast<String>());
    final opt = (item['selectedOptions'] as List).first as Map<String, dynamic>;
    expect(
      opt.keys.toList()..sort(),
      (full['selectedOptionKeys'] as List).cast<String>(),
    );
    // 서버 타입이 한때 선언했던 거짓 키 (§1-5) — 앱은 보낸 적이 없다.
    expect(opt.containsKey('optionGroupId'), isFalse);
    expect(opt.containsKey('optionId'), isFalse);
    // imageUrl 은 이제 보낸다 (주문상세 썸네일용, order_flow_phase1 'UI 캐싱' 의도 복원).
    expect(item.containsKey('imageUrl'), isTrue);
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

  group('qoin_spend: 최상위 입력 계약 + cartToMap discount/totalPrice', () {
    final full =
        jsonDecode(File('test_fixtures/qoin_cart_contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final inputKeys = (full['inputKeys'] as List).cast<String>().toList()..sort();
    final requiredInputKeys =
        (full['requiredInputKeys'] as List).cast<String>().toList()..sort();
    const cart = CartEntity(
      storeId: 's1',
      storeName: '강남점',
      subtotal: 8000,
      items: [
        CartItemEntity(
          cartItemId: 'c1',
          menuItemId: 'm1',
          menuItemName: '아메리카노',
          quantity: 2,
          unitPriceWithOptions: 4000,
          lineTotal: 8000,
        ),
      ],
    );

    Map<String, dynamic> payload({String? deviceId, int qoin = 0}) =>
        CloudFunctionsRemoteDataSource.verifyPayload(
          paymentKey: 'pk',
          orderId: 'o1',
          amount: cart.subtotal - qoin,
          idempotencyKey: 'o1',
          cartSnapshot: PaymentGatewayRepositoryImpl.cartToMap(cart, qoinToUse: qoin),
          paymentMethod: 'card',
          qoinToUse: qoin,
          deviceId: deviceId,
        );

    test('verifyTossPayment 최상위 입력 키 집합 = 골든 inputKeys (deviceId 있을 때 전부 / 없으면 requiredInputKeys)', () {
      expect((payload(deviceId: 'dev').keys.toList()..sort()), inputKeys);
      expect((payload().keys.toList()..sort()), requiredInputKeys);
      expect(payload().containsKey('qoinToUse'), isTrue);
    });

    test('qoinToUse 는 cart 밖 최상위 입력이다 (cart 키 골든은 그대로)', () {
      final p = payload(qoin: 700);
      expect(p['qoinToUse'], 700);
      expect((p['cart'] as Map).containsKey('qoinToUse'), isFalse);
      expect(((p['cart'] as Map).keys.toList()..sort()), (full['keys'] as List).cast<String>().toList()..sort());
    });

    test('Q=0: cartToMap 은 이전과 바이트 동일 (discount null, totalPrice = subtotal)', () {
      final m = PaymentGatewayRepositoryImpl.cartToMap(cart);
      expect(m['discount'], isNull);
      expect(m['totalPrice'], 8000);
      expect(
        PaymentGatewayRepositoryImpl.cartToMap(cart, qoinToUse: 0),
        m,
      );
    });

    test('Q>0: discount = Q, totalPrice = subtotal − Q (표시·기록용 — 권위는 서버), subtotal 은 원본', () {
      final m = PaymentGatewayRepositoryImpl.cartToMap(cart, qoinToUse: 700);
      expect(m['discount'], 700);
      expect(m['totalPrice'], 7300);
      expect(m['subtotal'], 8000);
    });

    test('amount 는 cart.totalPrice 와 일치한다 (서버 amount === cart.totalPrice 자기정합)', () {
      final p = payload(qoin: 700);
      expect(p['amount'], (p['cart'] as Map)['totalPrice']);
    });
  });
}
