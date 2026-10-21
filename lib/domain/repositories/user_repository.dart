import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/entities/notification_permission_prompt_state.dart';
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

  /// OS 권한 시트 소진 플래그(`notificationPermissionPrompted`)를 true 로 설정한다.
  ///
  /// 다이얼로그에서 `허용` 을 선택했을 때에만 호출한다.
  /// `나중에` / dedup(null) 에는 호출하지 않는다 (Phase 3c-4).
  Future<void> markNotificationPermissionPrompted(String uid);

  /// 알림 권한 재권유 정책 상태(`prompted`, `laterCount`)를 1회 read 로 조회한다.
  Future<NotificationPermissionPromptState>
  getNotificationPermissionPromptState(String uid);

  /// `나중에` 선택 횟수를 원자적으로 1 증가시킨다 (`FieldValue.increment`).
  Future<void> incrementNotificationPermissionLaterCount(String uid);

  // ── 알림 설정 (Phase 3c-3) ─────────────────────────────────────────────

  /// 알림 카테고리 1개의 on/off 를 갱신한다 (다른 카테고리는 보존).
  Future<void> updateNotificationSetting({
    required String uid,
    required NotificationCategory category,
    required bool enabled,
  });
}
