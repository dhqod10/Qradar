import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_permission_prompt_state.freezed.dart';

/// 알림 권한 다이얼로그 최대 노출 횟수 (Phase 3c-4).
///
/// `laterCount` 가 0/1/2 일 때 노출, 3 에서 중단 → 총 3회.
const int kMaxNotificationPermissionPrompts = 3;

/// 알림 권한 다이얼로그 재권유 정책 상태 (`users/{uid}` 의 두 필드 묶음).
@freezed
abstract class NotificationPermissionPromptState
    with _$NotificationPermissionPromptState {
  const NotificationPermissionPromptState._();

  const factory NotificationPermissionPromptState({
    /// OS 권한 시트 소진 이력 (다이얼로그에서 `허용` 선택).
    @Default(false) bool prompted,

    /// `나중에` 선택 횟수. 필드 부재 시 0.
    @Default(0) int laterCount,
  }) = _NotificationPermissionPromptState;

  /// 다이얼로그 노출 이력 (OwnerOrdersPage 배너 게이트).
  bool get hasSeenDialog => prompted || laterCount > 0;

  /// 다이얼로그 재노출 가능 여부 (OS 상태는 포함하지 않음).
  bool get canPromptAgain =>
      !prompted && laterCount < kMaxNotificationPermissionPrompts;
}
