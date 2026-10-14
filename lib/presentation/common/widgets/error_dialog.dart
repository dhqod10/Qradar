import 'package:flutter/material.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 에러 / 실패 안내 다이얼로그.
///
/// 사용자가 즉시 확인해야 하는 메시지에 사용. SnackBar 보다 강한 주의.
/// 성공 메시지는 SnackBar 사용.
///
/// [queue] 를 전달하면 글로벌 dialog 큐를 경유하여 동시 에러 stacking 을 방지한다.
/// 동일 [message] 의 에러 dialog 는 key 기반 dedup 으로 중복 표시되지 않는다.
/// [queue] 가 null 이면 기존 방식(`showDialog` 직접 호출) 으로 동작한다 (P2 점진 적용 호환).
Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  DialogQueueService? queue,
  String title = '오류',
  String confirmLabel = '확인',
}) async {
  Widget builder(BuildContext ctx) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 아이콘
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              // 제목
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // 메시지
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // 확인 버튼
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  if (queue != null) {
    return queue.enqueueDialog<void>(
      context: context,
      key: 'error_${message.hashCode}',
      barrierDismissible: false,
      builder: builder,
    );
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: builder,
  );
}
