import 'package:flutter/widgets.dart';
import 'package:qradar/data/datasources/remote/cloud_functions_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/order_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/toss_payment_remote_data_source.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/domain/repositories/payment_gateway_repository.dart';

/// [PaymentGatewayRepository] 구현체.
///
/// 파이프라인:
///   1. [TossPaymentRemoteDataSource] — SDK 결제창 실행 (launchPayment).
///   2. [CloudFunctionsRemoteDataSource] — verifyTossPayment / cancelTossPayment /
///      processRefund Cloud Functions 호출.
///   3. [OrderRemoteDataSource] — verifyAndCreateOrder 완료 후 Firestore 주문 조회.
///
/// **모든 외부 SDK / Firestore 접근은 DataSource 에 위임**. 본 클래스는
/// 결과 변환과 파이프라인 조율만 담당.
class PaymentGatewayRepositoryImpl implements PaymentGatewayRepository {
  final TossPaymentRemoteDataSource _tossDs;
  final CloudFunctionsRemoteDataSource _functionsDs;
  final OrderRemoteDataSource _orderDs;

  const PaymentGatewayRepositoryImpl({
    required TossPaymentRemoteDataSource tossDs,
    required CloudFunctionsRemoteDataSource functionsDs,
    required OrderRemoteDataSource orderDs,
  })  : _tossDs = tossDs,
        _functionsDs = functionsDs,
        _orderDs = orderDs;

  // ── launchPayment ────────────────────────────────────────────────────────────

  /// Toss SDK 결제창 실행 → [PaymentLaunchResult] 반환.
  ///
  /// [PaymentMethod] → Toss SDK method 문자열 변환:
  ///   - [PaymentMethod.card]      → 'CARD'
  ///   - [PaymentMethod.kakaoPay]  → 'KAKAO_PAY'
  @override
  Future<PaymentLaunchResult> launchPayment({
    required BuildContext context,
    required PaymentMethod method,
    required String idempotencyKey,
    required int amount,
    required String orderName,
    required String customerEmail,
    required String customerName,
  }) async {
    final tossResult = await _tossDs.requestPayment(
      context: context,
      method: _toTossMethodString(method),
      idempotencyKey: idempotencyKey,
      amount: amount,
      orderName: orderName,
      customerEmail: customerEmail,
      customerName: customerName,
    );

    return switch (tossResult) {
      TossPaymentSuccess(:final paymentKey, :final orderId, :final amount) =>
        PaymentLaunchResult(
          success: true,
          paymentKey: paymentKey,
          orderId: orderId,
          amount: amount,
        ),
      TossPaymentFailure(:final code, :final message) => PaymentLaunchResult(
          success: false,
          errorCode: code,
          errorMessage: message,
        ),
      TossPaymentCancelled() => const PaymentLaunchResult(
          success: false,
          cancelled: true,
        ),
    };
  }

  // ── verifyAndCreateOrder ─────────────────────────────────────────────────────

  /// Cloud Functions `verifyTossPayment` 호출 → Firestore 주문 doc 조회 반환.
  ///
  /// Functions 내부에서 주문 doc 을 생성하므로 완료 후 [OrderRemoteDataSource]
  /// 로 단건 조회한다. doc 이 없는 경우(Functions 실패 예외 미전파) [StateError].
  @override
  Future<OrderEntity> verifyAndCreateOrder({
    required String paymentKey,
    required String orderId,
    required int amount,
    required CartEntity cartSnapshot,
    required String uid,
    required PaymentMethod paymentMethod,
  }) async {
    await _functionsDs.verifyTossPayment(
      paymentKey: paymentKey,
      orderId: orderId,
      amount: amount,
      idempotencyKey: orderId,
      cartSnapshot: _cartToMap(cartSnapshot),
      paymentMethod: paymentMethod.name,
    );

    // Functions 완료 후 Firestore 에서 생성된 주문 조회.
    final model = await _orderDs.streamById(orderId).first;
    if (model == null) {
      throw StateError(
        'verifyAndCreateOrder: Firestore 주문 doc 이 없습니다. orderId=$orderId',
      );
    }
    return model.toEntity();
  }

  // ── cancelPaidOrder ──────────────────────────────────────────────────────────

  /// Cloud Functions `cancelTossPayment` 호출. paid → cancelled.
  @override
  Future<void> cancelPaidOrder({
    required String orderId,
    required String reason,
    required String approvedBy,
  }) {
    return _functionsDs.cancelTossPayment(
      orderId: orderId,
      reason: reason,
      approvedBy: approvedBy,
    );
  }

  // ── processRefund ────────────────────────────────────────────────────────────

  /// Cloud Functions `processRefund` 호출. accepted+ → refunded.
  @override
  Future<void> processRefund({
    required String orderId,
    required String reason,
  }) {
    return _functionsDs.processRefund(orderId: orderId, reason: reason);
  }

  // ── 내부 헬퍼 ────────────────────────────────────────────────────────────────

  /// [PaymentMethod] → Toss SDK method 문자열 변환.
  ///
  /// Phase 3a 지원: card, kakaoPay.
  /// Phase 3b 이후 추가 수단은 아래 주석 케이스를 활성화.
  String _toTossMethodString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.card:
        return 'CARD';
      case PaymentMethod.kakaoPay:
        return 'KAKAO_PAY';
      case PaymentMethod.naverPay:
        return 'NAVERPAY';
      case PaymentMethod.tossPay:
        return 'TOSSPAY';
      case PaymentMethod.samsungPay:
        return 'SAMSUNG_PAY';
      case PaymentMethod.applePay:
        return 'APPLEPAY';
      case PaymentMethod.bankTransfer:
        return 'TRANSFER';
      case PaymentMethod.mobile:
        return 'MOBILE_PHONE';
      case PaymentMethod.payco:
        return 'PAYCO';
    }
  }

  /// [CartEntity] → Cloud Functions 전달용 Map 변환.
  ///
  /// Functions 측에서 storeId / storeName / items 를 사용하여
  /// Firestore orders/{orderId} doc 을 생성.
  Map<String, dynamic> _cartToMap(CartEntity cart) {
    return <String, dynamic>{
      'storeId': cart.storeId,
      'storeName': cart.storeName,
      'subtotal': cart.subtotal,
      'discount': null,
      'totalPrice': cart.subtotal,
      'items': cart.items
          .map((item) => _cartItemToMap(item))
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _cartItemToMap(CartItemEntity item) {
    return <String, dynamic>{
      'menuItemId': item.menuItemId,
      'menuItemName': item.menuItemName,
      'quantity': item.quantity,
      'unitPriceWithOptions': item.unitPriceWithOptions,
      'lineTotal': item.lineTotal,
      'selectedOptions': item.selectedOptions
          .map((opt) => <String, dynamic>{
                'groupId': opt.groupId,
                'groupName': opt.groupName,
                'itemId': opt.itemId,
                'label': opt.label,
                'priceDelta': opt.priceDelta,
              })
          .toList(growable: false),
    };
  }
}
