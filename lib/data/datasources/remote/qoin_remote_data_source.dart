import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/data/models/qoin_config_model.dart';
import 'package:qradar/data/models/qoin_transaction_model.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';

/// Qoin 원격 데이터소스. **Firestore 직접 사용은 본 파일에서만**.
///
/// - 원장 `users/{uid}/qoinTransactions` : 읽기 전용 (쓰기는 CF).
/// - 설정 `config/qoin` : 읽기 + admin 의 `enabled` 쓰기. **적립률 쓰기는 없다** (CF 전담 — `QoinRateRemoteDataSource`).
class QoinRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  QoinRemoteDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _configDoc => _firestore
      .collection(FirestorePaths.config)
      .doc(FirestorePaths.qoinConfigDocId);

  /// 본인 내역. 단일 필드 정렬이라 복합 인덱스 불필요.
  Stream<List<QoinTransactionEntity>> watchTransactions(
    String uid, {
    required int limit,
  }) {
    return _firestore
        .collection(FirestorePaths.userQoinTransactions(uid))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(QoinTransactionModel.fromFirestore)
              .toList(growable: false),
        )
        .handleError((Object e) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            throw const PermissionDeniedException();
          }
          throw e;
        });
  }

  Stream<QoinConfigEntity?> watchConfig() {
    return _configDoc.snapshots().map(
      (doc) => doc.exists ? QoinConfigModel.fromFirestore(doc) : null,
    );
  }

  /// `enabled` + 행위자(`enabledChangedBy` = 로그인 uid, `enabledChangedAt`)를 **한 번의 쓰기**로 저장한다.
  /// Rules 가 `enabledChangedBy == request.auth.uid` 를 강제하므로 uid 가 다르거나 없으면 거부된다 (F3).
  /// 문서 없으면 update 가 실패한다 (의도).
  Future<void> setEnabled(bool enabled) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const PermissionDeniedException('로그인이 필요해요');
    return _configDoc.update(buildEnabledWrite(enabled: enabled, uid: uid));
  }

  /// 비상 정지 쓰기 맵 (테스트가 키 집합을 고정한다).
  static Map<String, Object> buildEnabledWrite({
    required bool enabled,
    required String uid,
  }) => <String, Object>{
    'enabled': enabled,
    'enabledChangedBy': uid,
    'enabledChangedAt': FieldValue.serverTimestamp(),
  };
}
