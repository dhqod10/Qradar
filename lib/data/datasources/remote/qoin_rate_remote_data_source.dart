import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/data/datasources/remote/qoin_callable.dart';
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
  late final QoinCallable _callable = QoinCallable(_functions);

  Future<QoinRateSetResult> setRate({
    required QoinRateScope scope,
    String? targetId,
    double? rate,
    bool clear = false,
    String? reason,
  }) async {
    final data = await _callable.call('setQoinAccrualRate', <String, dynamic>{
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
      closed: data['closed'] == true,
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
    final data = await _callable.call(
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
      disabledUntouchedCount: n('disabledUntouchedCount'),
      clearedValueCount: n('clearedValueCount'),
      clearedInvalidCount: n('clearedInvalidCount'),
      brandDisabled: data['brandDisabled'] == true,
      closed: data['closed'] == true,
      staleScan: data['staleScan'] == true,
    );
  }

  Future<QoinAccrualEnabledResult> setAccrualEnabled({
    required QoinRateScope scope,
    required String targetId,
    required bool enabled,
    String? reason,
  }) async {
    final data = await _callable.call(
      'setQoinAccrualEnabled',
      <String, dynamic>{
        'scope': scope.code,
        'targetId': targetId,
        'enabled': enabled,
        'reason': ?reason,
      },
    );
    return QoinAccrualEnabledResult(
      before: data['before'] as bool?,
      after: data['after'] as bool?,
      changed: data['changed'] == true,
      historyId: data['historyId'] as String?,
      closed: data['closed'] == true,
    );
  }

  /// 이력 문서 1건 직접 읽기 (스트림 아님 — CG 인덱스에 의존하지 않고 20건 창 문제도 없다). 문서가 없거나 해석할 수 없으면 null.
  /// 배너 본문 수치용 보조 읽기라 호출자는 실패해도 배너를 숨기지 않는다 (spec §21.1).
  Future<QoinRateChangeEntity?> fetchHistory(
    QoinRateScope scope,
    String targetId,
    String historyId,
  ) async {
    final base = switch (scope) {
      QoinRateScope.global => FirestorePaths.globalQoinRateHistory,
      QoinRateScope.brand => FirestorePaths.brandQoinRateHistory(targetId),
      QoinRateScope.store => FirestorePaths.storeQoinRateHistory(targetId),
    };
    final doc = await _firestore.collection(base).doc(historyId).get();
    if (!doc.exists) return null;
    return QoinRateChangeModel.fromFirestore(doc);
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
