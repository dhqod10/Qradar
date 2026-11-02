import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:qradar/core/constants/app_client_level.dart';
import 'package:qradar/core/errors/verify_payment_failure.dart';

/// Firebase Cloud Functions 호출 어댑터.
///
/// Phase 3a 포함 함수 (region: asia-northeast3):
/// - `verifyTossPayment` — Toss confirm + Firestore `orders/{orderId}` 생성.
/// - `cancelTossPayment` — paid → cancelled. PG 취소 API 호출.
/// - `processRefund`    — accepted+ → refunded. PG 환불 API 호출.
///
/// **Cloud Functions 직접 사용은 본 파일에서만**. (Clean Architecture 절대 규칙)
class CloudFunctionsRemoteDataSource {
  final FirebaseFunctions _functions;

  /// 설치 식별자 공급자 (prelaunch_security_bundle Layer2). 기본은 Firebase Installations ID.
  /// 테스트에서 주입한다. 실패/미지원이면 null — 서버는 `deviceIdHash: null` 로 저장하고 결제는 정상 진행한다.
  /// 잠정(사용자 검토 대기): D-3 deviceId 소스 = Firebase Installations ID.
  final Future<String?> Function() _deviceIdProvider;

  CloudFunctionsRemoteDataSource({
    FirebaseFunctions? functions,
    Future<String?> Function()? deviceIdProvider,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _deviceIdProvider = deviceIdProvider ?? _installationId;

  static Future<String?> _installationId() async {
    try {
      // 결제 경로를 막지 않도록 짧게 기다린다. 신호용일 뿐 판정에 쓰이지 않는다.
      return await FirebaseInstallations.instance.getId().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      return null;
    }
  }

  /// `verifyTossPayment` 최상위 입력. 키 집합은 `test_fixtures/qoin_cart_contract.json` 의 `inputKeys` 골든이 서버와 양방향으로 고정한다.
  ///
  /// **`qoinToUse`** (qoin_spend): 사용 요청액일 뿐 권위가 아니다. 0 이어도 항상 싣는다 — 서버는 0 을 "사용 안 함" 으로 읽고
  /// 기존 흐름과 동일하게 처리한다 (구버전 앱은 이 키가 없고 같은 결과).
  @visibleForTesting
  static Map<String, dynamic> verifyPayload({
    required String paymentKey,
    required String orderId,
    required int amount,
    required String idempotencyKey,
    required Map<String, dynamic> cartSnapshot,
    required String paymentMethod,
    required int qoinToUse,
    String? deviceId,
  }) {
    return <String, dynamic>{
      'paymentKey': paymentKey,
      'orderId': orderId,
      'amount': amount,
      'idempotencyKey': idempotencyKey,
      'cart': cartSnapshot,
      'paymentMethod': paymentMethod,
      'qoinToUse': qoinToUse,
      // 이 빌드가 금액 재가격(payment_price_authority R9)을 가진 수준이다. 서버는 거절 기록에 남겨 구버전 비율을 잰다.
      'clientLevel': kPaymentClientLevel,
      // Layer2 신호 (서버가 salt 와 해시해 orderSignals 에만 저장). 판정에 쓰지 않는다. 구버전·실패 시 키 없음.
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    };
  }

  Future<Map<String, dynamic>> verifyTossPayment({
    required String paymentKey,
    required String orderId,
    required int amount,
    required String idempotencyKey,
    required Map<String, dynamic> cartSnapshot,
    required String paymentMethod,
    int qoinToUse = 0,
  }) async {
    try {
      final deviceId = await _deviceIdProvider();
      final callable = _functions.httpsCallable('verifyTossPayment');
      final result = await callable.call<Object?>(
        verifyPayload(
          paymentKey: paymentKey,
          orderId: orderId,
          amount: amount,
          idempotencyKey: idempotencyKey,
          cartSnapshot: cartSnapshot,
          paymentMethod: paymentMethod,
          qoinToUse: qoinToUse,
          deviceId: deviceId,
        ),
      );
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception('결제 검증 응답 형식이 올바르지 않습니다.');
    } on FirebaseFunctionsException catch (e) {
      // 게이트 거절 토큰 `[REASON:ids]` 가 message 끝에 실려 온다 (payment_server_authority spec §15.1).
      // `_convertFunctionsException` 은 일부 코드에서 message 를 버리므로 verify 경로만 code+message 를 보존한다.
      throw VerifyPaymentFailure(code: e.code, message: e.message ?? '');
    }
  }

  Future<void> cancelTossPayment({
    required String orderId,
    required String reason,
    required String approvedBy,
  }) async {
    try {
      final callable = _functions.httpsCallable('cancelTossPayment');
      await callable.call<Object?>({
        'orderId': orderId,
        'reason': reason,
        'approvedBy': approvedBy,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _convertFunctionsException(e);
    }
  }

  Future<void> processRefund({
    required String orderId,
    required String reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('processRefund');
      await callable.call<Object?>({'orderId': orderId, 'reason': reason});
    } on FirebaseFunctionsException catch (e) {
      throw _convertFunctionsException(e);
    }
  }

  Exception _convertFunctionsException(FirebaseFunctionsException e) {
    final code = e.code;
    final message = e.message ?? '알 수 없는 오류가 발생했습니다.';
    switch (code) {
      case 'invalid-argument':
        return Exception('잘못된 요청입니다. ($message)');
      case 'not-found':
        return Exception('주문 또는 결제 정보를 찾을 수 없습니다. ($message)');
      case 'already-exists':
        return Exception('이미 처리된 요청입니다. ($message)');
      case 'permission-denied':
        return Exception('권한이 없습니다. ($message)');
      case 'failed-precondition':
        return Exception('현재 상태에서 처리할 수 없습니다. ($message)');
      case 'unavailable':
        return Exception('서비스에 일시적으로 접근할 수 없습니다. 잠시 후 다시 시도해 주세요.');
      case 'deadline-exceeded':
        return Exception('요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
      case 'unauthenticated':
        return Exception('로그인이 필요합니다.');
      default:
        return Exception('결제 처리 중 오류가 발생했습니다. ($code: $message)');
    }
  }
}
