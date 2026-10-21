import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/presentation/common/notification/notification_permission_dialog.dart';
import 'package:qradar/presentation/common/notification/providers/notification_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 메인 scaffold 진입 시 알림 권한 다이얼로그 노출 + 결과 기록 플로우 (Phase 3c-4).
///
/// customer / owner scaffold 가 [audience] 만 바꿔 공유한다 (drift 방지).
///
/// 결과 기록 정책
/// - `'allow'`: OS 권한 요청 → (허용 시) 토큰 등록 → `prompted = true`
/// - `'later'`: `laterCount` 를 `FieldValue.increment(1)` (prompted 변경 없음)
/// - `null`: dedup / context 만료 — 사용자의 선택이 아니므로 아무것도 기록하지 않음
///
/// [isMounted] 는 호출부 State 의 `mounted`. 비동기 경계마다 확인하며,
/// false 면 `ref` 접근 없이 중단한다.
///
/// 모든 예외는 삼킨다 — 다이얼로그를 띄우지 못하는 것이 앱 진입을 막아선 안 된다.
Future<void> runNotificationPermissionPrompt({
  required BuildContext context,
  required WidgetRef ref,
  required NotificationDialogAudience audience,
  required bool Function() isMounted,
}) async {
  try {
    final uid = ref.read(authProvider).asData?.value?.uid;
    if (uid == null) return;

    final osStatus = await ref
        .read(pushNotificationRepositoryProvider)
        .getPermissionStatus();
    if (!isMounted()) return;

    final shouldShow = await ref
        .read(shouldShowNotificationPermissionDialogUseCaseProvider)
        .call(uid: uid, osStatus: osStatus);
    if (!shouldShow) return;
    if (!isMounted() || !context.mounted) return;

    final result = await showNotificationPermissionDialog(
      context,
      audience: audience,
      queue: ref.read(dialogQueueServiceProvider),
    );
    if (!isMounted()) return;

    final userRepo = ref.read(userRepositoryProvider);
    switch (result) {
      case 'allow':
        final status = await ref
            .read(requestNotificationPermissionUseCaseProvider)
            .call();
        if (status == NotificationPermissionStatus.authorized ||
            status == NotificationPermissionStatus.provisional) {
          await ref.read(registerFcmTokenUseCaseProvider).call(uid);
        }
        // OS 시트를 소진했으므로 허용/거부와 무관하게 prompted = true
        await userRepo.markNotificationPermissionPrompted(uid);
      case 'later':
        await userRepo.incrementNotificationPermissionLaterCount(uid);
      default:
        // null: 기록하지 않는다
        break;
    }
  } catch (e) {
    debugPrint('[NotificationPermissionPrompt] skipped: $e');
  }
}
