import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/user_model.dart';

/// Firestore `users` 컬렉션 원격 데이터소스.
class UserRemoteDataSource {
  final FirebaseFirestore _firestore;

  UserRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(FirestorePaths.users).doc(uid);

  Future<UserModel?> fetch(String uid) async {
    final snapshot = await _doc(uid).get();
    if (!snapshot.exists) return null;
    return UserModelFactory.fromFirestore(snapshot);
  }

  /// 신규 `users/{uid}` 문서 생성. 이미 존재하면 덮어쓰지 않는다 (merge).
  Future<void> createIfAbsent(UserModel model) async {
    await _doc(model.uid).set(
      model.toFirestoreForCreate(),
      SetOptions(merge: true),
    );
  }

  Future<void> updateRole({required String uid, required String role}) async {
    await _doc(uid).update({'role': role});
  }

  Stream<UserModel?> watch(String uid) {
    return _doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModelFactory.fromFirestore(doc);
    });
  }
}
