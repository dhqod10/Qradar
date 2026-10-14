import 'package:flutter/material.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 다이얼로그 호출 주체 — 카피 분기용.
enum NotificationDialogAudience { owner, customer }

/// FCM 알림 권한 요청 다이얼로그.
///
/// [audience] 에 따라 본문 카피가 점주 / 고객 관점으로 분기된다.
/// [queue] 를 통해 글로벌 dialog 큐를 경유하므로 동시 stacking 이 발생하지 않는다.
///
/// 반환값:
/// - `'allow'`: 사용자가 "허용" 탭 → 호출부에서 OS 권한 요청 진행.
/// - `'later'`: 사용자가 "나중에" 탭 → 권한 요청 skip.
/// - `null`: context 만료 또는 dedup 으로 인한 skip. 'later' 와 동일 처리.
Future<String?> showNotificationPermissionDialog(
  BuildContext context, {
  required NotificationDialogAudience audience,
  required DialogQueueService queue,
}) {
  return queue.enqueueDialog<String>(
    context: context,
    key: 'notification_permission_${audience.name}',
    barrierDismissible: false,
    barrierColor: AppColors.textHeading.withValues(alpha: 0.6),
    builder: (ctx) => _NotificationPermissionDialog(audience: audience),
  );
}

class _NotificationPermissionDialog extends StatelessWidget {
  const _NotificationPermissionDialog({required this.audience});

  final NotificationDialogAudience audience;

  String get _primaryBody => switch (audience) {
        NotificationDialogAudience.owner =>
          '새 주문과 환불 요청을 바로 알려드릴게요.',
        NotificationDialogAudience.customer =>
          '주문 진행 상황을 바로 알려드릴게요.',
      };

  String get _secondaryBody => switch (audience) {
        NotificationDialogAudience.owner => '매장을 떠나 있어도 놓치지 않아요.',
        NotificationDialogAudience.customer =>
          '조리 시작과 픽업 준비 알림을 받아볼 수 있어요.',
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 아이콘 컨테이너 ─────────────────────────────────────────────
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.onPrimary,
                size: 28,
              ),
            ),
            // ── 제목 ────────────────────────────────────────────────────────
            const SizedBox(height: 20),
            const Text(
              '알림을 받으시겠어요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            // ── 본문 (1차) ──────────────────────────────────────────────────
            const SizedBox(height: 12),
            Text(
              _primaryBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
            // ── 본문 (2차) ──────────────────────────────────────────────────
            const SizedBox(height: 6),
            Text(
              _secondaryBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            // ── 버튼 ────────────────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                // 나중에 버튼 (secondary)
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop('later'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '나중에',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 허용 버튼 (primary)
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop('allow'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '허용',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
