import 'package:cloud_functions/cloud_functions.dart';

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

  CloudFunctionsRemoteDataSource({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<Map<String, dynamic>> verifyTossPayment({
    required String paymentKey,
    required String orderId,
    required int amount,
    required String idempotencyKey,
    required Map<String, dynamic> cartSnapshot,
    required String paymentMethod,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyTossPayment');
      final result = await callable.call<Object?>({
        'paymentKey': paymentKey,
        'orderId': orderId,
        'amount': amount,
        'idempotencyKey': idempotencyKey,
        'cart': cartSnapshot,
        'paymentMethod': paymentMethod,
      });
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception('결제 검증 응답 형식이 올바르지 않습니다.');
    } on FirebaseFunctionsException catch (e) {
      throw _convertFunctionsException(e);
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
      await callable.call<Object?>({
        'orderId': orderId,
        'reason': reason,
      });
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
