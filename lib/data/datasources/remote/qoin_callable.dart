import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/errors/qoin_rate_exception.dart';

/// Qoin callable 호출 + 실패 분류 공용 (적립률·스위치·임시 마이그레이션 데이터소스가 같이 쓴다).
class QoinCallable {
  const QoinCallable(this._functions);
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> payload, {
    Duration? timeout,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(
          timeout: timeout ?? const Duration(seconds: 70),
        ),
      );
      final res = await callable.call<Object?>(payload);
      final d = res.data;
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw _fromFunctionsException(e);
    } on QoinRateException {
      rethrow;
    } catch (_) {
      // 네트워크 끊김 등 — 요청이 서버에 닿았는지 알 수 없다.
      throw const QoinRateException(QoinRateFailureKind.unknownOutcome);
    }
  }

  static QoinRateException _fromFunctionsException(
    FirebaseFunctionsException e,
  ) {
    // TRANSITIONAL(spec §20.4.5): 일괄 적용 레거시 0 가드가 details 로 보낸 건수·ID.
    int? legacyCount;
    var legacyIds = const <String>[];
    final d = e.details;
    if (d is Map && d['legacyZeroCount'] is num) {
      legacyCount = (d['legacyZeroCount'] as num).toInt();
      final ids = d['storeIds'];
      if (ids is List) legacyIds = ids.whereType<String>().toList();
    }
    return QoinRateException(
      classify(e.code),
      code: e.code,
      legacyZeroCount: legacyCount,
      legacyZeroStoreIds: legacyIds,
    );
  }

  /// 확정 실패(서버가 거부, 반영되지 않음) vs 결과 불명(서버에서는 반영됐을 수 있음).
  static QoinRateFailureKind classify(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
      case 'invalid-argument':
      case 'not-found':
      case 'failed-precondition':
      case 'already-exists':
      case 'out-of-range':
        return QoinRateFailureKind.rejected;
      default:
        return QoinRateFailureKind.unknownOutcome;
    }
  }
}
