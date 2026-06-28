import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 알림 권한이 거부된 상태일 때 점주에게 설정 안내 배너를 표시한다.
///
/// 탭 시 OS 앱 설정 화면으로 이동.
class NotificationDeniedBanner extends StatelessWidget {
  const NotificationDeniedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AppSettings.openAppSettings(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.warning),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 20,
              color: AppColors.warning,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '알림이 꺼져 있어요. 설정에서 켜주세요.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
