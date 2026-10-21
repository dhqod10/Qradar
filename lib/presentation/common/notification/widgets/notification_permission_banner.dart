import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';

/// 알림 설정 화면 전용 OS 권한 배너 (denied / notDetermined).
///
/// 순수 표시 위젯 — 실제 동작(설정 열기 / 권한 요청)은 [onPrimaryTap] 으로 주입.
class NotificationPermissionBanner extends StatelessWidget {
  /// `denied` 또는 `notDetermined` 만 유효.
  final NotificationPermissionStatus status;

  /// true 면 owner 카피, false 면 customer 카피.
  final bool isOwner;

  /// "알림 켜기" 요청 진행 중 여부 (CTA 로딩 + 비활성).
  final bool isRequesting;

  final VoidCallback onPrimaryTap;

  const NotificationPermissionBanner({
    super.key,
    required this.status,
    required this.isOwner,
    required this.isRequesting,
    required this.onPrimaryTap,
  });

  bool get _denied => status == NotificationPermissionStatus.denied;

  @override
  Widget build(BuildContext context) {
    final tone = _denied ? AppColors.warning : AppColors.info;
    final title = _denied ? '기기 설정에서 알림이 꺼져 있어요' : '알림을 켜 보세요';
    final body = _denied
        ? '알림을 받으려면 기기 설정에서 Qradar 알림을 허용해 주세요.'
        : (isOwner
            ? '새 주문과 환불 요청을 바로 받아볼 수 있어요.'
            : '주문 진행 상황을 바로 받아볼 수 있어요.');
    final cta = _denied ? '설정 열기' : '알림 켜기';

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.10),
          border: Border.all(color: tone),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _denied
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: tone,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: isRequesting ? null : onPrimaryTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.onPrimary,
                  elevation: 0,
                  minimumSize: const Size(96, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: isRequesting
                    ? Semantics(
                        label: '알림 권한을 요청하는 중',
                        child: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      )
                    : Text(cta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
