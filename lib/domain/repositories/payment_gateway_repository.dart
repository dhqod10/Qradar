import 'package:flutter/widgets.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';

/// Toss 결제 런치 결과.
class PaymentLaunchResult {
  final bool success;
  final String? paymentKey;
  final String? orderId;
  final int? amount;
  final String? errorCode;
  final String? errorMessage;
  final bool cancelled;

  const PaymentLaunchResult({
    required this.success,
    this.paymentKey,
    this.orderId,
    this.amount,
    this.errorCode,
    this.errorMessage,
    this.cancelled = false,
  });
}

/// 결제 게이트웨이 Repository 인터페이스.
///
/// Toss SDK 호출 및 Cloud Functions 검증 파이프라인을 추상화.
abstract class PaymentGatewayRepository {
  /// Toss SDK 결제창 실행. success/fail/cancel 결과를 [PaymentLaunchResult] 로 반환.
  Future<PaymentLaunchResult> launchPayment({
    required BuildContext context,
    required PaymentMethod method,
    required String idempotencyKey,
    required int amount,
    required String orderName,
    required String customerEmail,
    required String customerName,
  });

  /// Cloud Functions `verifyTossPayment` 호출 → Firestore `orders/{orderId}` 생성.
  Future<OrderEntity> verifyAndCreateOrder({
    required String paymentKey,
    required String orderId,
    required int amount,
    required CartEntity cartSnapshot,
    required String uid,
  });

  /// Cloud Functions `cancelTossPayment` 호출.
  /// paid → cancelled (customer 직접 취소 또는 점주 거절).
  Future<void> cancelPaidOrder({
    required String orderId,
    required String reason,
    required String approvedBy,
  });

  /// Cloud Functions `processRefund` 호출.
  /// accepted+ → refunded (점주 환불 승인).
  Future<void> processRefund({
    required String orderId,
    required String reason,
  });
}
