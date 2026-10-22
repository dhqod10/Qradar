import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_dialog_shell.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 저장하려는 동작.
enum QoinConfirmAction {
  /// 직접 설정 (숫자)
  set('적립률을 변경할까요?', '변경하기'),

  /// 적립 안 함 (0%)
  stop('적립을 중단할까요?', '적립 중단'),

  /// 상위 설정 따르기
  inherit('설정을 지우고 상위 설정을 따르게 할까요?', '되돌리기'),

  /// 끝나지 않은 일괄 적용 이어서 진행
  resume('일괄 적용을 이어서 진행할까요?', '이어서 적용');

  const QoinConfirmAction(this.question, this.confirmLabel);
  final String question;
  final String confirmLabel;
}

/// 비교 블록의 한 쪽 (현재 / 변경). **해석된 유효 값 + 출처 캡션**을 담는다 —
/// `상위 설정 따르기` 로 바꿀 때도 변경 쪽에 따르게 될 실제 값이 나온다.
class QoinConfirmValue {
  const QoinConfirmValue({
    required this.label,
    required this.caption,
    required this.spoken,
    this.tenths,
  });

  /// `3%` / `0%` / `설정 없음` / `—`.
  final String label;

  /// `전역 상속` / `브랜드 설정` / `적립 안 함` / `확인 필요` …
  final String caption;
  final String spoken;

  /// 환산용 0.1% 단위. 0 = 적립 없음. null = 환산 불가(해석 불가 / 설정 없음).
  final int? tenths;

  /// 해석 결과로부터. [target] 은 보는 대상 범위. 전역 대상이면 캡션은 `전역 기본값`.
  factory QoinConfirmValue.fromEffective(
    EffectiveQoinRate e, {
    required QoinRateScope target,
  }) {
    if (e.isInvalid) {
      return const QoinConfirmValue(
        label: '—',
        caption: QoinRateLabels.needsCheck,
        spoken: QoinRateLabels.needsCheck,
      );
    }
    final caption = target == QoinRateScope.global
        ? '전역 기본값'
        : QoinRateBadgeKind.of(e, target: target).label;
    return QoinConfirmValue(
      label: QoinRateValueLabel.effective(e),
      caption: caption,
      spoken: QoinRateValueLabel.spokenEffective(e),
      tenths: QoinPolicy.tenthsFromRate(e.rate!),
    );
  }

  /// 전역 문서가 아직 없을 때의 현재 값.
  static const QoinConfirmValue none = QoinConfirmValue(
    label: QoinRateLabels.none,
    caption: '',
    spoken: QoinRateLabels.none,
  );
}

/// 브랜드 일괄 적용 확인에 필요한 영향 범위 (클라이언트 **미리보기** — 이력에는 서버가 센 값이 남는다).
class QoinBulkConfirm {
  const QoinBulkConfirm({
    required this.total,
    required this.overridden,
    required this.overriddenStopped,
    required this.mode,
    this.remaining,
  });

  /// 산하 매장 수 N.
  final int total;

  /// 개별 설정이 있는 매장 수 M.
  final int overridden;

  /// 그중 `적립 안 함(0)` 인 매장 수 Z — 덮어쓰기는 이 매장도 다시 적립하게 만든다.
  final int overriddenStopped;
  final QoinBulkMode mode;

  /// 이어서 적용일 때 남은 매장 수 R.
  final int? remaining;
}

/// **3범위 공용 확인 다이얼로그.** 저장 버튼을 누르면 항상 연다.
///
/// 첫 줄 = 범위 + 대상명 (18/w800 — 다이얼로그에서 가장 큰 글자). 숫자보다 먼저 읽히도록 위계를 뒤집었다:
/// 범위 오입력(한 매장에 주려던 값을 전역에)이 100배 오입력보다 위험하다.
/// **인상 경고(`2배 이상이거나 10% 이상`) 문구와 판정은 이 파일에만 있다.**
/// 덮어쓰기/이어서 적용은 체크박스를 체크해야 실행 버튼이 활성된다 (열 때마다 미체크로 시작).
class QoinRateConfirmDialog extends StatefulWidget {
  const QoinRateConfirmDialog({
    super.key,
    required this.scope,
    this.targetName,
    required this.action,
    required this.current,
    required this.next,
    this.reason,
    this.followingStores,
    this.bulk,
  });

  final QoinRateScope scope;
  final String? targetName;
  final QoinConfirmAction action;
  final QoinConfirmValue current;
  final QoinConfirmValue next;
  final String? reason;

  /// 전역 편집일 때 "이 값을 따르는 매장 N곳". 계산 불가면 null (줄 생략, 저장은 막지 않는다).
  final int? followingStores;

  /// 브랜드일 때.
  final QoinBulkConfirm? bulk;

  static Future<bool> show(
    BuildContext context, {
    required QoinRateScope scope,
    String? targetName,
    required QoinConfirmAction action,
    required QoinConfirmValue current,
    required QoinConfirmValue next,
    String? reason,
    int? followingStores,
    QoinBulkConfirm? bulk,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => QoinRateConfirmDialog(
        scope: scope,
        targetName: targetName,
        action: action,
        current: current,
        next: next,
        reason: reason,
        followingStores: followingStores,
        bulk: bulk,
      ),
    );
    return ok == true;
  }

  @override
  State<QoinRateConfirmDialog> createState() => _QoinRateConfirmDialogState();
}

class _QoinRateConfirmDialogState extends State<QoinRateConfirmDialog> {
  bool _checked = false;

  bool get _isResume => widget.action == QoinConfirmAction.resume;
  bool get _isOverwrite =>
      widget.bulk != null && widget.bulk!.mode == QoinBulkMode.overwrite && widget.bulk!.overridden > 0;
  bool get _needsCheck => _isResume || _isOverwrite;

  int get _clearCount => _isResume
      ? (widget.bulk?.remaining ?? 0)
      : (widget.bulk?.overridden ?? 0);

  String get _confirmLabel =>
      _isOverwrite && !_isResume ? '덮어쓰고 적용' : widget.action.confirmLabel;

  @override
  Widget build(BuildContext context) {
    final scopeLine = QoinScopeLabel.of(widget.scope, widget.targetName);
    final cur = widget.current;
    final next = widget.next;
    final pay = PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw);

    // ── 환산 줄 ────────────────────────────────────────────────────────────
    String? conversion;
    String? conversionSpoken;
    if (!_isResume && cur.tenths != null && next.tenths != null) {
      final a = cur.tenths == 0
          ? '적립 없음'
          : '${QoinFormatters.number(QoinPolicy.previewAmount(cur.tenths!))} Q';
      final b = next.tenths == 0
          ? '적립 없음'
          : '${QoinFormatters.number(QoinPolicy.previewAmount(next.tenths!))} Q';
      conversion = '$pay 결제 기준 $a → $b';
      conversionSpoken = '$pay 결제 기준 $a에서 $b';
    }
    // 현재 값(또는 변경 값)을 모르면 환산 줄을 생략한다.

    // ── 인상 경고 ──────────────────────────────────────────────────────────
    final nt = next.tenths;
    final ct = cur.tenths;
    final warnIncrease =
        !_isResume &&
        nt != null &&
        nt > 0 &&
        QoinPolicy.shouldWarnIncrease(
          // 현재가 0(적립 안 함)이면 "2배" 비교가 무의미하다 — 절대값(10%) 기준만 본다.
          currentTenths: (ct == null || ct == 0) ? null : ct,
          newTenths: nt,
        );

    final semantic = StringBuffer(
      '${scopeLine.replaceAll('"', '')}. ',
    );
    if (!_isResume) {
      semantic.write(
        widget.action == QoinConfirmAction.stop ? '적립을 ' : '적립률을 ',
      );
      semantic.write('현재 ${cur.spoken}');
      if (cur.caption.isNotEmpty) semantic.write(', ${cur.caption}');
      semantic.write('에서 ${next.spoken}');
      if (next.caption.isNotEmpty) semantic.write(', ${next.caption}');
      semantic.write(
        '${QoinRateValueLabel.particleEuroOrRo(next.caption.isEmpty ? next.spoken : next.caption)} 변경. ',
      );
      if (conversionSpoken != null) semantic.write('$conversionSpoken. ');
      if (widget.action == QoinConfirmAction.stop) {
        semantic.write('환불 회수는 계속돼요');
      }
    } else {
      semantic.write(widget.action.question);
    }

    return QoinDialogShell(
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
            widget.action.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
      cancelLabel: '취소',
      confirmLabel: _confirmLabel,
      confirmEnabled: !_needsCheck || _checked,
      content: [
        if (!_isResume)
          Semantics(
            label: semantic.toString(),
            excludeSemantics: true,
            child: _CompareBlock(current: cur, next: next),
          ),
        if (conversion != null) ...[
          const SizedBox(height: 12),
          Text(conversion, style: QoinDialogShell.bodyStyle),
        ],
        ..._impact(),
        if (warnIncrease) ...[
          const SizedBox(height: 12),
          const _WarnPlate(
            text: '변경 값이 현재의 2배 이상이거나 10% 이상이에요. 입력값이 맞는지 한 번 더 확인해주세요',
          ),
        ],
        if (widget.action == QoinConfirmAction.stop) ...[
          const SizedBox(height: 12),
          const _WarnPlate(
            text: '이후 픽업이 완료되는 주문은 적립되지 않아요. 이미 적립된 Qoin 의 환불 회수는 계속돼요',
          ),
        ],
        if (_needsCheck) ...[
          const SizedBox(height: 8),
          _CheckRow(
            value: _checked,
            label: _isResume
                ? '남은 $_clearCount곳의 개별 설정이 지워지는 것을 확인했어요'
                : '개별 설정 $_clearCount곳이 지워지는 것을 확인했어요',
            onChanged: (v) => setState(() => _checked = v),
          ),
        ],
        if (widget.reason != null && widget.reason!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '사유: ${widget.reason}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textBody),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          '변경 후 픽업이 완료되는 주문부터 적용돼요. 이미 적립된 Qoin 은 바뀌지 않아요',
          style: QoinDialogShell.noteStyle,
        ),
      ],
    );
  }

  /// 범위별 영향 블록.
  List<Widget> _impact() {
    final b = widget.bulk;
    switch (widget.scope) {
      case QoinRateScope.global:
        if (widget.followingStores == null) return const [];
        return [
          const SizedBox(height: 12),
          Text(
            '이 값을 따르는 매장 ${widget.followingStores}곳에 적용돼요',
            style: QoinDialogShell.bodyStyle,
          ),
        ];
      case QoinRateScope.store:
        return [
          const SizedBox(height: 12),
          const Text('이 매장에만 적용돼요', style: QoinDialogShell.bodyStyle),
        ];
      case QoinRateScope.brand:
        if (b == null) return const [];
        if (_isResume) {
          return [
            const SizedBox(height: 12),
            _HeavyPlate(
              title: '남은 ${b.remaining ?? 0}곳의 개별 설정이 지워져요',
              body: null,
              stoppedLine: null,
            ),
          ];
        }
        if (b.total == 0) {
          return const [
            SizedBox(height: 12),
            Text(
              '산하 매장이 아직 없어요. 앞으로 등록되는 매장부터 적용돼요',
              style: QoinDialogShell.bodyStyle,
            ),
          ];
        }
        if (b.overridden == 0) {
          return [
            const SizedBox(height: 12),
            Text('산하 매장 ${b.total}곳 모두에 적용돼요', style: QoinDialogShell.bodyStyle),
          ];
        }
        if (b.mode == QoinBulkMode.preserve) {
          return [
            const SizedBox(height: 12),
            Text(
              '산하 매장 ${b.total}곳 중 개별 설정이 없는 ${b.total - b.overridden}곳에 적용돼요\n'
              '개별 설정이 있는 ${b.overridden}곳은 그대로 유지돼요',
              style: QoinDialogShell.bodyStyle,
            ),
          ];
        }
        return [
          const SizedBox(height: 12),
          _HeavyPlate(
            title: '개별 설정 ${b.overridden}곳이 지워져요',
            body:
                '산하 매장 ${b.total}곳 중 개별 설정이 있는 ${b.overridden}곳의 설정이 지워지고, '
                '${b.total}곳 모두 새 값을 따르게 돼요.',
            stoppedLine: b.overriddenStopped > 0
                ? '그중 적립 안 함 ${b.overriddenStopped}곳도 다시 적립해요'
                : null,
          ),
        ];
    }
  }
}

class _CompareBlock extends StatelessWidget {
  const _CompareBlock({required this.current, required this.next});
  final QoinConfirmValue current;
  final QoinConfirmValue next;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: Text('현재', style: QoinDialogShell.noteStyle)),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  '변경',
                  textAlign: TextAlign.end,
                  style: QoinDialogShell.noteStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  current.label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              Expanded(
                child: Text(
                  next.label,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(current.caption, style: QoinDialogShell.noteStyle),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  next.caption,
                  textAlign: TextAlign.end,
                  style: QoinDialogShell.noteStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarnPlate extends StatelessWidget {
  const _WarnPlate({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 덮어쓰기/이어서 적용의 무거운 영향 블록. 색은 `warning` 까지만 (`error` 금지).
class _HeavyPlate extends StatelessWidget {
  const _HeavyPlate({
    required this.title,
    required this.body,
    required this.stoppedLine,
  });
  final String title;
  final String? body;
  final String? stoppedLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, style: QoinDialogShell.bodyStyle),
          ],
          if (stoppedLine != null) ...[
            const SizedBox(height: 4),
            Text('· $stoppedLine', style: QoinDialogShell.bodyStyle),
          ],
          const SizedBox(height: 6),
          Text(
            '되돌리려면 매장마다 다시 설정해야 해요',
            style: QoinDialogShell.bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: '$label, 체크박스, ${value ? '선택됨' : '선택 안 됨'}. 체크해야 실행 버튼을 누를 수 있어요',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Checkbox(
                value: value,
                activeColor: AppColors.primary,
                onChanged: (v) => onChanged(v ?? false),
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
