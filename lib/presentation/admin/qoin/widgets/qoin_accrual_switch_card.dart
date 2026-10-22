import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/qoin_rate_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_admin_ui.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_dialog_shell.dart';
import 'package:qradar/presentation/common/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_reenable_hint.dart';

/// `적립 사용 끄러 가기` / `적립 사용 켜러 가기` 가 카드로 스크롤하고 강조하게 하는 컨트롤러.
/// 페이지가 만들어 입력란·결과 카드와 [QoinAccrualSwitchCard] 에 같이 넘긴다.
/// **스위치를 대신 눌러 주지 않는다** — 돈이 멈추는 동작은 사용자가 직접 한다.
class QoinSwitchFocusController extends ChangeNotifier {
  final GlobalKey anchorKey = GlobalKey();
  final FocusNode focusNode = FocusNode(debugLabel: 'qoinAccrualSwitch');
  int _pulse = 0;
  int get pulse => _pulse;

  /// 카드로 스크롤 → 포커스 이동 → 테두리 강조(카드가 1.2초 뒤 원복).
  Future<void> go() async {
    final ctx = anchorKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.3,
      );
    }
    focusNode.requestFocus();
    _pulse++;
    notifyListeners();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}

/// 매장·브랜드 편집 화면의 `적립 사용` 스위치 카드 (design §18-2.2). 적립률 폼의 저장 버튼 **아래** 독립 카드.
///
/// - 낙관적으로 움직이지 않는다: 탭 → 확인 다이얼로그 → 호출 중 인디케이터 → 서버 스트림 값이 바뀌면 카드가 바뀐다.
/// - 폼 초안은 건드리지 않는다 (이 위젯은 폼의 상태를 모른다).
/// - 켜기 다이얼로그의 `다시 켜면 …` 는 사슬과 같은 [QoinReenableHint] 한 함수의 결과다.
class QoinAccrualSwitchCard extends ConsumerStatefulWidget {
  const QoinAccrualSwitchCard({
    super.key,
    required this.scope,
    required this.targetId,
    required this.targetName,
    required this.switchSetting,
    required this.effective,
    this.controller,
    this.subStoreTotal,
    this.subStoreOverridden,
  }) : assert(scope == QoinRateScope.store || scope == QoinRateScope.brand);

  /// store 또는 brand.
  final QoinRateScope scope;
  final String targetId;
  final String targetName;

  /// 대상 **자신**의 스위치 값.
  final QoinSwitchSetting switchSetting;

  /// 대상의 현재 해석 결과 (켜기 고지용).
  final EffectiveQoinRate effective;
  final QoinSwitchFocusController? controller;

  /// 브랜드 전용: 산하 매장 정보 (이 화면 기준 미리보기). 로딩 전이면 null → 끄기 다이얼로그가 숫자 괄호를 생략한다.
  final int? subStoreTotal;
  final int? subStoreOverridden;

  @override
  ConsumerState<QoinAccrualSwitchCard> createState() =>
      _QoinAccrualSwitchCardState();
}

class _QoinAccrualSwitchCardState extends ConsumerState<QoinAccrualSwitchCard> {
  bool _busy = false;
  bool _highlight = false;
  int _seenPulse = 0;
  Timer? _timer;

  bool get _isBrand => widget.scope == QoinRateScope.brand;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onPulse);
  }

  @override
  void didUpdateWidget(covariant QoinAccrualSwitchCard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onPulse);
      widget.controller?.addListener(_onPulse);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onPulse);
    _timer?.cancel();
    super.dispose();
  }

  void _onPulse() {
    final c = widget.controller;
    if (c == null || c.pulse == _seenPulse) return;
    _seenPulse = c.pulse;
    setState(() => _highlight = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlight = false);
    });
  }

  Future<void> _toggle(bool turnOn) async {
    if (_busy) return;
    final hint = QoinReenableHint.of(widget.effective, target: widget.scope);
    final reason = await QoinAccrualSwitchDialog.show(
      context,
      scope: widget.scope,
      targetName: widget.targetName,
      turnOn: turnOn,
      hint: hint,
      subStoreTotal: widget.subStoreTotal,
      subStoreOverridden: widget.subStoreOverridden,
    );
    if (reason == null || !mounted) return; // 취소
    setState(() => _busy = true);
    try {
      await ref.read(setQoinAccrualEnabledUseCaseProvider)(
        scope: widget.scope,
        targetId: widget.targetId,
        enabled: turnOn,
        reason: reason.isEmpty ? null : reason,
      );
      if (mounted) {
        qoinSnack(
          context,
          QoinMessages.switchChanged(widget.scope, enabled: turnOn),
        );
      }
    } catch (e) {
      if (mounted) {
        qoinSnack(
          context,
          e is QoinRateException
              ? QoinMessages.failure(e, switchChange: true)
              : QoinMessages.enabledFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.switchSetting;
    final on = s.isEnabled;
    final invalid = s.isInvalid;
    final who = _isBrand ? '이 브랜드' : '이 매장';
    final title = '$who 적립 사용';
    final description = on
        ? (_isBrand
              ? '이 브랜드 매장의 주문은 픽업 완료 시 Qoin 이 적립돼요'
              : '이 매장의 주문은 픽업 완료 시 Qoin 이 적립돼요')
        : (_isBrand
              ? '이 브랜드는 기본으로 Qoin 을 적립하지 않아요. 환불로 인한 회수는 계속돼요'
              : '이 매장은 Qoin 을 적립하지 않아요. 환불로 인한 회수는 계속돼요');
    final brandNote = _isBrand
        ? (on
              ? '${widget.subStoreTotal == null ? '' : '산하 매장 ${widget.subStoreTotal}곳\n'}'
                    '일부 매장만 멈추려면 이 스위치가 아니라 각 매장의 ‘적립 사용’ 을 끄세요'
              : '산하 매장 전부가 적립을 멈춰 있어요. 적립률을 따로 정한 매장도 포함이에요')
        : null;
    final footer = _isBrand
        ? '위 ‘브랜드 설정 저장’ 과 별개로 바로 적용돼요'
        : '위 ‘매장 설정 저장’ 과 별개로 바로 적용돼요';

    final off = !on;
    final border = _highlight
        ? Border.all(color: AppColors.primary, width: 1.5)
        : Border.all(
            color: off
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.border,
          );

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '$title, 스위치, ${on ? '켜짐' : '꺼짐'}. '
          '${on ? '' : '${invalid ? QoinRateLabels.needsCheck : QoinRateLabels.switchOff}. '}'
          '$description. 적립률 저장과 별개로 바로 적용돼요',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: widget.controller?.anchorKey,
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: off
              ? AppColors.warning.withValues(alpha: 0.10)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  off ? Icons.pause_circle_outline_rounded : Icons.toll_rounded,
                  size: 22,
                  color: off ? AppColors.warning : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      if (off)
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            invalid
                                ? QoinRateLabels.needsCheck
                                : QoinRateLabels.switchOff,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 48,
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Switch(
                            value: on,
                            focusNode: widget.controller?.focusNode,
                            activeThumbColor: AppColors.onPrimary,
                            activeTrackColor: AppColors.primary,
                            onChanged: _toggle,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
            if (brandNote != null) ...[
              const SizedBox(height: 6),
              Text(
                brandNote,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              footer,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 스위치 확인 다이얼로그 (끄기 / 켜기 공용). 확정이면 사유 문자열(빈 문자열 가능), 취소면 null.
class QoinAccrualSwitchDialog extends StatefulWidget {
  const QoinAccrualSwitchDialog({
    super.key,
    required this.scope,
    required this.targetName,
    required this.turnOn,
    this.hint,
    this.subStoreTotal,
    this.subStoreOverridden,
  });

  final QoinRateScope scope;
  final String targetName;
  final bool turnOn;

  /// 켜기일 때 본문. 끄기에서는 쓰지 않는다.
  final QoinReenableHint? hint;
  final int? subStoreTotal;
  final int? subStoreOverridden;

  static Future<String?> show(
    BuildContext context, {
    required QoinRateScope scope,
    required String targetName,
    required bool turnOn,
    QoinReenableHint? hint,
    int? subStoreTotal,
    int? subStoreOverridden,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => QoinAccrualSwitchDialog(
        scope: scope,
        targetName: targetName,
        turnOn: turnOn,
        hint: hint,
        subStoreTotal: subStoreTotal,
        subStoreOverridden: subStoreOverridden,
      ),
    );
  }

  @override
  State<QoinAccrualSwitchDialog> createState() =>
      _QoinAccrualSwitchDialogState();
}

class _QoinAccrualSwitchDialogState extends State<QoinAccrualSwitchDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _isBrand => widget.scope == QoinRateScope.brand;

  @override
  Widget build(BuildContext context) {
    final turnOn = widget.turnOn;
    final scopeLine = QoinScopeLabel.of(widget.scope, widget.targetName);
    final hint = widget.hint;

    final total = widget.subStoreTotal;
    final overridden = widget.subStoreOverridden ?? 0;

    final content = <Widget>[
      if (!turnOn) ...[
        const Text(
          '이후 픽업이 완료되는 주문은 적립되지 않아요. 이미 적립된 Qoin 의 환불 회수는 계속돼요',
          style: QoinDialogShell.bodyStyle,
        ),
        if (_isBrand) ...[
          const SizedBox(height: 12),
          const Text(
            '산하 매장 전부가 적립을 멈춰요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          if (total != null && total > 0)
            Text(
              overridden > 0
                  ? '이 화면 기준 $total곳 · 적립률을 따로 정한 $overridden곳도 포함이에요'
                  : '이 화면 기준 $total곳',
              style: QoinDialogShell.noteStyle,
            ),
          const SizedBox(height: 6),
          const Text(
            '일부 매장만 멈추려면 브랜드는 켠 채 매장별로 끄세요',
            style: QoinDialogShell.noteStyle,
          ),
        ],
      ] else ...[
        Text(
          hint?.headline ?? '다시 켜면 현재 요율로 적립돼요',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
        if (hint?.dialogSub != null) ...[
          const SizedBox(height: 4),
          Text(hint!.dialogSub!, style: QoinDialogShell.noteStyle),
        ],
      ],
      const SizedBox(height: 14),
      TextField(
        controller: _reason,
        maxLength: QoinPolicy.reasonMaxLength,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(fontSize: 14, color: AppColors.textBody),
        decoration: InputDecoration(
          labelText: '사유 (선택)',
          hintText: turnOn ? '예: 점검 종료' : '예: 점검 기간 동안 중단',
          counterStyle: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
        ),
      ),
      if (!turnOn) ...[
        const SizedBox(height: 8),
        const Text(
          '이 변경은 바로 적용돼요. 다시 켜면 현재 요율로 적립돼요',
          style: QoinDialogShell.noteStyle,
        ),
      ],
    ];

    return _ReasonReturningShell(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scopeLine,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            turnOn ? '적립을 다시 시작할까요?' : '적립을 중단할까요?',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
      content: content,
      confirmLabel: turnOn ? '적립 시작' : '적립 중단',
      reasonController: _reason,
    );
  }
}

/// [QoinDialogShell] 은 확정 시 `true` 를 돌려주므로, 사유 문자열을 돌려주도록 감싼다.
class _ReasonReturningShell extends StatelessWidget {
  const _ReasonReturningShell({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.reasonController,
  });

  final Widget title;
  final List<Widget> content;
  final String confirmLabel;
  final TextEditingController reasonController;

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
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: AppColors.surfaceElevated,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '취소',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ),
        // 적립 중단은 정상 운영 결정이다 — error 색이 아니라 primary.
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(reasonController.text.trim()),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: AppColors.primary,
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
