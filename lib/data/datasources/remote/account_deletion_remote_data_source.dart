import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/errors/account_deletion_exception.dart';
import 'package:qradar/domain/entities/account_deletion_preview.dart';

/// `deleteMyAccount` callable 어댑터 (region: asia-northeast3).
///
/// **SDK 예외는 이 파일 밖으로 나가지 않는다.** 서버 message 는 화면에 싣지 않고 토큰
/// (`[ACCOUNT_HAS_INFLIGHT_ORDERS]`) 분류에만 쓴다.
class AccountDeletionRemoteDataSource {
  AccountDeletionRemoteDataSource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  static const String inFlightOrdersToken = '[ACCOUNT_HAS_INFLIGHT_ORDERS]';

  /// `dryRun: true` — 쓰기 0건.
  Future<AccountDeletionPreview> preview() async {
    final data = await _call(<String, dynamic>{'dryRun': true});
    return parsePreview(data);
  }

  /// 응답 파싱. 숫자를 읽지 못한 응답은 "0건" 이 아니라 실패다 (파괴적 동작 — fail-closed).
  static AccountDeletionPreview parsePreview(Map<String, dynamic> data) {
    if (data['alreadyDeleted'] == true) {
      return const AccountDeletionPreview(
        inFlightOrderCount: 0,
        qoinToForfeit: 0,
        alreadyDeleted: true,
      );
    }
    final inFlight = data['inFlightOrders'];
    final qoin = data['qoinToForfeit'];
    if (inFlight is! num || qoin is! num) {
      throw const AccountDeletionException(AccountDeletionFailure.failed);
    }
    return AccountDeletionPreview(
      inFlightOrderCount: inFlight.toInt(),
      qoinToForfeit: qoin.toInt() < 0 ? 0 : qoin.toInt(),
    );
  }

  /// `dryRun: false`.
  Future<AccountDeletionResult> deleteMyAccount({String reason = ''}) async {
    final data = await _call(<String, dynamic>{
      'reason': reason,
      'dryRun': false,
    });
    final q = data['forfeitedQoin'];
    return AccountDeletionResult(
      forfeitedQoin: q is num ? q.toInt() : 0,
      alreadyDeleted: data['alreadyDeleted'] == true,
    );
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) async {
    final Object? data;
    try {
      final result = await _functions
          .httpsCallable(
            'deleteMyAccount',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call<Object?>(payload);
      data = result.data;
    } on FirebaseFunctionsException catch (e) {
      throw AccountDeletionException(
        classifyError(e.code, e.message),
        code: e.code,
        inFlightOrders: _inFlightFromDetails(e.details),
      );
    } catch (_) {
      throw const AccountDeletionException(AccountDeletionFailure.failed);
    }
    if (data is! Map) {
      throw const AccountDeletionException(AccountDeletionFailure.failed);
    }
    return Map<String, dynamic>.from(data);
  }

  static int? _inFlightFromDetails(Object? details) {
    if (details is Map) {
      final n = details['inFlightOrders'];
      if (n is num) return n.toInt();
    }
    return null;
  }

  /// 에러 코드 + message 끝 토큰 -> 분류. 토큰 없는 `failed-precondition` 은 가드로 읽지 않는다.
  static AccountDeletionFailure classifyError(String code, String? message) {
    if (code == 'failed-precondition' &&
        (message ?? '').trimRight().endsWith(inFlightOrdersToken)) {
      return AccountDeletionFailure.inFlightOrders;
    }
    if (code == 'unauthenticated') {
      return AccountDeletionFailure.unauthenticated;
    }
    return AccountDeletionFailure.failed;
  }
}
