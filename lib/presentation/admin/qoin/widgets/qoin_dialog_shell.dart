import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// Qoin 다이얼로그 공용 껍데기 (1차 `_dialog` 헬퍼 추출). 켜기·끄기·확인·이어서 적용이 공유한다.
/// 제목이 [Widget] 이라 2줄 헤더(범위 + 동작 질문)를 담을 수 있다. 본문은 스크롤 가능 (텍스트 1.5x 대응).
class QoinDialogShell extends StatelessWidget {
  const QoinDialogShell({
    super.key,
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    this.confirmEnabled = true,
  });

  /// 문자열 제목 편의 생성.
  factory QoinDialogShell.text({
    Key? key,
    required String title,
    required List<Widget> content,
    required String cancelLabel,
    required String confirmLabel,
    bool confirmEnabled = true,
  }) => QoinDialogShell(
    key: key,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textHeading,
      ),
    ),
    content: content,
    cancelLabel: cancelLabel,
    confirmLabel: confirmLabel,
    confirmEnabled: confirmEnabled,
  );

  final Widget title;
  final List<Widget> content;
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmEnabled;

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: AppColors.textBody,
  );
  static const TextStyle noteStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: title,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: AppColors.surfaceElevated,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: confirmEnabled
              ? () => Navigator.of(context).pop(true)
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: confirmEnabled
                ? AppColors.primary
                : AppColors.textMuted,
            disabledBackgroundColor: AppColors.textMuted,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
