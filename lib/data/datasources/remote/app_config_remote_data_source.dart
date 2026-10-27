import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';

/// `config/app` — 운영 설정 문서. 서버(Console)에서 `minClientLevel`(정수)을 둔다. 로그인 사용자 읽기, 쓰기는 admin.
/// 캐시를 쓰지 않는다 (`Source.server`) — 낡은 값으로 결제를 막거나 열지 않는다.
class AppConfigRemoteDataSource {
  AppConfigRemoteDataSource({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<int?> fetchMinClientLevel() async {
    final snap = await _db
        .collection(FirestorePaths.config)
        .doc(FirestorePaths.appConfigDocId)
        .get(const GetOptions(source: Source.server));
    if (!snap.exists) return null;
    final v = snap.data()?['minClientLevel'];
    return v is num ? v.toInt() : null;
  }
}
