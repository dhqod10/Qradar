import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/errors/qoin_rate_exception.dart';
import 'package:qradar/data/models/qoin_rate_change_model.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// Qoin 적립률 쓰기(callable 2개) + 이력 조회. **이 파일이 적립률 관련 Firebase 직접 사용의 전부다.**
///
/// 쓰기는 Firestore 직접 쓰기가 아니다 (Rules 가 막는다). 값과 이력이 같은 트랜잭션에 쓰여야 하기 때문이다.
class QoinRateRemoteDataSource {
  QoinRateRemoteDataSource({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<QoinRateSetResult> setRate({
    required QoinRateScope scope,
    String? targetId,
    double? rate,
    bool clear = false,
    String? reason,
  }) async {
    final data = await _call('setQoinAccrualRate', <String, dynamic>{
      'scope': scope.code,
      if (scope != QoinRateScope.global) 'targetId': targetId,
      if (clear) 'clear': true else 'rate': rate,
      'reason': ?reason,
    });
    return QoinRateSetResult(
      before: (data['before'] as num?)?.toDouble(),
      after: (data['after'] as num?)?.toDouble(),
      changed: data['changed'] == true,
      historyId: data['historyId'] as String?,
    );
  }

  Future<QoinBulkApplyResult> applyBrandRate({
    required String brandId,
    double? rate,
    bool clear = false,
    required QoinBulkMode mode,
    String? reason,
    String? resumeHistoryId,
  }) async {
    final data = await _call(
      'applyBrandQoinRate',
      <String, dynamic>{
        'brandId': brandId,
        'mode': mode.code,
        if (resumeHistoryId != null)
          'resumeHistoryId': resumeHistoryId
        else if (clear)
          'clear': true
        else
          'rate': rate,
        'reason': ?reason,
      },
      // 서버 timeoutSeconds(540) 보다 약간 길게.
      timeout: const Duration(seconds: 560),
    );
    int n(String k) => (data[k] as num?)?.toInt() ?? 0;
    return QoinBulkApplyResult(
      changed: data['changed'] == true,
      status: QoinBulkStatus.fromCode(data['status']) ?? QoinBulkStatus.partial,
      affectedCount: n('affectedCount'),
      clearedCount: n('clearedCount'),
      preservedCount: n('preservedCount'),
      processedCount: n('processedCount'),
      totalCount: n('totalCount'),
      historyId: data['historyId'] as String?,
    );
  }

  Future<Map<String, dynamic>> _call(
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
      throw QoinRateException(_classify(e.code), code: e.code);
    } on QoinRateException {
      rethrow;
    } catch (_) {
      // 네트워크 끊김 등 — 요청이 서버에 닿았는지 알 수 없다.
      throw const QoinRateException(QoinRateFailureKind.unknownOutcome);
    }
  }

  /// 확정 실패(서버가 거부, 반영되지 않음) vs 결과 불명(서버에서는 반영됐을 수 있음).
  static QoinRateFailureKind _classify(String code) {
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

  Stream<List<QoinRateChangeEntity>> watchHistory(
    QoinRateScope scope,
    String targetId, {
    required int limit,
  }) {
    final path = switch (scope) {
      QoinRateScope.global => FirestorePaths.globalQoinRateHistory,
      QoinRateScope.brand => FirestorePaths.brandQoinRateHistory(targetId),
      QoinRateScope.store => FirestorePaths.storeQoinRateHistory(targetId),
    };
    return _toEntities(
      _firestore
          .collection(path)
          .orderBy('changedAt', descending: true)
          .limit(limit)
          .snapshots(),
    );
  }

  /// admin 전체 이력 (collectionGroup). 정렬 `changedAt` 은 collection-group **단일 필드 인덱스**가 필요하다
  /// (자동 생성되지 않음 — `firestore.indexes.json` 의 fieldOverrides 배포 필요).
  Stream<List<QoinRateChangeEntity>> watchAllHistory({required int limit}) {
    return _toEntities(
      _firestore
          .collectionGroup(FirestorePaths.qoinRateHistory)
          .orderBy('changedAt', descending: true)
          .limit(limit)
          .snapshots(),
    );
  }

  Stream<List<QoinRateChangeEntity>> _toEntities(
    Stream<QuerySnapshot<Map<String, dynamic>>> source,
  ) {
    return source
        .map(
          (snap) => snap.docs
              .map(QoinRateChangeModel.fromFirestore)
              .whereType<QoinRateChangeEntity>()
              .toList(growable: false),
        )
        .handleError((Object e) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            throw const PermissionDeniedException();
          }
          throw e;
        });
  }
}
