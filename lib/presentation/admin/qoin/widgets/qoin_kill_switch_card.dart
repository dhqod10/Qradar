import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_dialog_shell.dart';

/// 적립 사용 스위치 (비상 정지). 1차 `_EnabledSwitchCard` + 켜기/끄기 다이얼로그를 그대로 옮겼다 —
/// **전역 전용이라 공유 위젯이 아니다.** 900줄 파일로 돌아가지 않게 파일만 분리했다.
///
/// 즉시 반영, 적립률 폼과 독립. 낙관적 갱신 없음(서버 스트림 값만 표시).
/// 이 스위치는 적립·**회수 모두** 멈춘다. 한 곳만 멈추려면 해당 화면의 `적립 사용` 스위치를 쓴다 (캡션이 말한다).
class QoinKillSwitchCard extends StatelessWidget {
  const QoinKillSwitchCard({
    super.key,
    required this.cfg,
    required this.saving,
    required this.onToggle,
  });

  final QoinConfigEntity? cfg;
  final bool saving;
  final ValueChanged<bool> onToggle;

  static const String caption =
      '전체 비상 정지예요. 매장·브랜드 한 곳만 멈추려면 해당 화면의 ‘적립 사용’ 을 끄세요';

  @override
  Widget build(BuildContext context) {
    final enabled = cfg?.enabled ?? false;
    // 문서가 없거나 전역 기본값이 유효하지 않으면 켤 수 없다 (끄는 것은 항상 가능).
    final canUse = cfg != null && (enabled || cfg!.accrualRate != null);
    final interactive = canUse && !saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '적립 사용',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textBody,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          enabled
                              ? '픽업 완료된 주문에 Qoin 을 적립해요'
                              : '지금은 적립과 환불 회수가 모두 멈춰 있어요',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (saving) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Semantics(
                    label: 'Qoin 적립 사용',
                    toggled: enabled,
                    hint: '끄면 적립과 환불 회수가 모두 멈춰요',
                    child: Switch.adaptive(
                      // 낙관적 업데이트 금지: 값은 항상 서버(스트림) 값.
                      value: enabled,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primaryBright.withValues(
                        alpha: 0.3,
                      ),
                      inactiveThumbColor: AppColors.textMuted,
                      inactiveTrackColor: AppColors.surface,
                      onChanged: interactive ? onToggle : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                caption,
                style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        if (!canUse) ...[
          const SizedBox(height: 4),
          const Text(
            '설정 없음 — 먼저 전역 기본값을 저장해주세요',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// 끄기: "환불 회수도 멈춘다" 를 반드시 명시한다 (모르고 끄면 환불받은 고객이 Qoin 을 그대로 갖는다).
class QoinDisableDialog extends StatelessWidget {
  const QoinDisableDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return QoinDialogShell.text(
      title: 'Qoin 적립을 중단할까요?',
      cancelLabel: '취소',
      confirmLabel: '적립 중단',
      content: const [
        Text('지금부터 아래 동작이 모두 멈춰요.', style: QoinDialogShell.bodyStyle),
        SizedBox(height: 8),
        Text('• 픽업이 완료되어도 Qoin 이 적립되지 않아요', style: QoinDialogShell.bodyStyle),
        Text(
          '• 이미 적립된 주문이 환불되어도 Qoin 이 회수되지 않아요',
          style: QoinDialogShell.bodyStyle,
        ),
        Text(
          '• 중단 중에 픽업 완료된 주문은 다시 켜도 자동으로 적립되지 않아요',
          style: QoinDialogShell.bodyStyle,
        ),
        SizedBox(height: 10),
        Text(
          '고객 Qoin 탭에는 ‘적립이 잠시 중단되어 있어요’ 가 표시돼요',
          style: QoinDialogShell.noteStyle,
        ),
      ],
    );
  }
}

class QoinEnableDialog extends StatelessWidget {
  const QoinEnableDialog({super.key, required this.rateLabel});
  final String rateLabel;

  @override
  Widget build(BuildContext context) {
    return QoinDialogShell.text(
      title: 'Qoin 적립을 다시 시작할까요?',
      cancelLabel: '취소',
      confirmLabel: '적립 시작',
      content: [
        Text(
          '지금 설정된 적립률 $rateLabel 로, 이후 픽업 완료되는 주문부터 적립돼요. '
          '중단된 동안 완료된 주문은 소급 적립되지 않아요.',
          style: QoinDialogShell.bodyStyle,
        ),
      ],
    );
  }
}
