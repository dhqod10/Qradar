import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/user_model.dart';
import 'package:qradar/domain/entities/notification_permission_prompt_state.dart';

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

  // ── FCM 토큰 관련 (Phase 3b) ──────────────────────────────────────────────

  /// FCM 토큰을 업데이트한다.
  /// [token] 이 null 이면 Firestore 에서 해당 필드를 제거한다.
  /// 허용 필드: `fcmToken`, `fcmTokenUpdatedAt`, `updatedAt` (Rules 화이트리스트).
  Future<void> updateFcmToken(String uid, String? token) async {
    await _doc(uid).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// `notificationPermissionPrompted` 플래그(OS 권한 시트 소진)를 true 로 설정한다.
  /// 다이얼로그에서 `허용` 선택 시에만 호출한다. `나중에` 에는 호출하지 않는다.
  Future<void> markNotificationPermissionPrompted(String uid) async {
    await _doc(uid).update({
      'notificationPermissionPrompted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// `notificationPermissionPrompted` + `notificationPermissionLaterCount` 를
  /// 1회 read 로 조회한다. doc 부재 / 필드 부재 시 기본값.
  Future<NotificationPermissionPromptState>
  getNotificationPermissionPromptState(String uid) async {
    final snapshot = await _doc(uid).get();
    if (!snapshot.exists) return const NotificationPermissionPromptState();
    final data = snapshot.data() ?? {};
    return NotificationPermissionPromptState(
      prompted: (data['notificationPermissionPrompted'] as bool?) ?? false,
      laterCount: UserModelFactory.parseLaterCount(
        data['notificationPermissionLaterCount'],
      ),
    );
  }

  /// `나중에` 선택 횟수를 원자적으로 +1 한다 (read-then-write 금지).
  /// 허용 필드: `notificationPermissionLaterCount`, `updatedAt` (Rules 화이트리스트).
  Future<void> incrementNotificationPermissionLaterCount(String uid) async {
    await _doc(uid).update({
      'notificationPermissionLaterCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 알림 설정 (Phase 3c-3) ────────────────────────────────────────────────

  /// 알림 설정 1개 키를 dot-path 로 갱신 (다른 키 보존).
  /// 허용 필드: `notificationSettings`, `updatedAt` (Rules 화이트리스트).
  Future<void> updateNotificationSetting({
    required String uid,
    required String key,
    required bool enabled,
  }) async {
    await _doc(uid).update({
      'notificationSettings.$key': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
