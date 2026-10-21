import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';

/// 사용자 프로필 Repository (Firestore `users/{uid}` 문서 전담).
///
/// Firebase Auth 세션과는 별개로, 역할(role)을 비롯한 추가 프로필 필드를 관리.
abstract class UserRepository {
  /// 인증 사용자 기준으로 `users/{uid}` 문서를 조회하되, 없으면 기본값(customer)으로 생성한 뒤 반환.
  Future<UserEntity> getOrCreateUserProfile(UserEntity authUser);

  /// role 업데이트.
  Future<void> updateRole({required String uid, required UserRole role});

  /// 현재 사용자 프로필 실시간 감시.
  Stream<UserEntity?> watchCurrent(String uid);

  // ── FCM 토큰 관련 (Phase 3b) ──────────────────────────────────────────

  /// FCM 토큰을 업데이트한다. null 전달 시 토큰 필드를 제거한다.
  Future<void> updateFcmToken(String uid, String? token);

  /// 알림 권한 다이얼로그 노출 이력 플래그를 true 로 설정한다.
  Future<void> markNotificationPermissionPrompted(String uid);

  /// 알림 권한 다이얼로그 노출 이력을 조회한다.
  Future<bool> getNotificationPermissionPrompted(String uid);

  // ── 알림 설정 (Phase 3c-3) ─────────────────────────────────────────────

  /// 알림 카테고리 1개의 on/off 를 갱신한다 (다른 카테고리는 보존).
  Future<void> updateNotificationSetting({
    required String uid,
    required NotificationCategory category,
    required bool enabled,
  });
}
