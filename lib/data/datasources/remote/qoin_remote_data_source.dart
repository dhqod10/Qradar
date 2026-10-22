import 'package:cloud_firestore/cloud_firestore.dart';
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

  QoinRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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

  /// `enabled` 만 저장. 문서 없으면 update 가 실패한다 (의도).
  Future<void> setEnabled(bool enabled) {
    return _configDoc.update({'enabled': enabled});
  }
}
