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

  /// `3%` / `설정 없음` / `—`.
  final String label;

  /// `전역 상속` / `브랜드 설정` / `확인 필요` …
  final String caption;
  final String spoken;

  /// 환산용 0.1% 단위. null = 환산 불가(해석 불가 / 설정 없음).
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
    // 비교는 "켜져 있다면 적용될 값" 끼리 한다 (호출자가 asIfEnabled 를 넘긴다). 방어적으로만 처리.
    if (e.isDisabled) {
      return QoinConfirmValue(
        label: QoinRateLabels.switchOff,
        caption: QoinRateBadgeKind.of(e, target: target).label,
        spoken: QoinRateLabels.switchOff,
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
    required this.mode,
    this.disabledUntouched = 0,
    this.brandDisabled = false,
    this.remaining,
  });

  /// 산하 매장 수 N.
  final int total;

  /// 개별 설정이 있는 매장 수 M.
  final int overridden;

  /// 스위치가 꺼진 산하 매장 수 K (미리보기). 일괄 적용은 스위치를 건드리지 않으므로 이 매장은 새 값을 받아도 적립이 시작되지 않는다.
  final int disabledUntouched;

  /// 브랜드 자신의 스위치가 꺼져 있다 (N4) — 산하 매장 전체가 적립되지 않는다. 있으면 K 줄은 숨긴다.
  final bool brandDisabled;
  final QoinBulkMode mode;

  /// 이어서 적용일 때 남은 매장 수 R.
  final int? remaining;
}

/// **3범위 공용 확인 다이얼로그.** 저장 버튼을 누르면 항상 연다.
///
/// 첫 줄 = 범위 + 대상명 (18/w800 — 다이얼로그에서 가장 큰 글자). 숫자보다 먼저 읽히도록 위계를 뒤집었다:
/// 범위 오입력(한 매장에 주려던 값을 전역에)이 100배 오입력보다 위험하다.
/// **인상 경고(`2배 이상이거나 10% 이상`) 문구와 판정은 이 파일에만 있다.**
/// 체크박스는 없다 (design §18-5). 마찰은 범위·대상명, 경고 plate, 동사 버튼(`덮어쓰고 적용`)이 진다.
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
    this.savedWhileDisabled = false,
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

  /// 지금 이 대상이 `사용 안 함` 상태에서 적립률을 저장한다 → `바꾼 값은 다시 켤 때부터 적용돼요` 한 줄.
  final bool savedWhileDisabled;

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
    bool savedWhileDisabled = false,
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
        savedWhileDisabled: savedWhileDisabled,
      ),
    );
    return ok == true;
  }

  @override
  State<QoinRateConfirmDialog> createState() => _QoinRateConfirmDialogState();
}

class _QoinRateConfirmDialogState extends State<QoinRateConfirmDialog> {
  bool get _isResume => widget.action == QoinConfirmAction.resume;
  bool get _isOverwrite =>
      widget.bulk != null && widget.bulk!.mode == QoinBulkMode.overwrite && widget.bulk!.overridden > 0;

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
      final a = '${QoinFormatters.number(QoinPolicy.previewAmount(cur.tenths!))} Q';
      final b = '${QoinFormatters.number(QoinPolicy.previewAmount(next.tenths!))} Q';
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
        QoinPolicy.shouldWarnIncrease(currentTenths: ct, newTenths: nt);

    final semantic = StringBuffer(
      '${scopeLine.replaceAll('"', '')}. ',
    );
    if (!_isResume) {
      semantic.write('적립률을 ');
      semantic.write('현재 ${cur.spoken}');
      if (cur.caption.isNotEmpty) semantic.write(', ${cur.caption}');
      semantic.write('에서 ${next.spoken}');
      if (next.caption.isNotEmpty) semantic.write(', ${next.caption}');
      semantic.write(
        '${QoinRateValueLabel.particleEuroOrRo(next.caption.isEmpty ? next.spoken : next.caption)} 변경. ',
      );
      if (conversionSpoken != null) semantic.write('$conversionSpoken. ');
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
      confirmEnabled: true,
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
        if (widget.savedWhileDisabled && !_isResume) ...[
          const SizedBox(height: 12),
          const Text(
            '지금은 적립 사용 안 함이라, 바꾼 값은 다시 켤 때부터 적용돼요',
            style: QoinDialogShell.bodyStyle,
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
    // 브랜드 자신이 꺼져 있으면 (모드 무관, 이어서 적용 제외) 맨 위에 plate 1개. K 줄은 숨긴다 (전체 정지가 K 를 포함).
    final brandOff = b != null && b.brandDisabled && !_isResume;
    final infoK = b != null && !brandOff && !_isResume && b.disabledUntouched > 0
        ? _InfoLine(
            text:
                '적립 사용 안 함 ${b.disabledUntouched}곳은 새 값을 받아도 적립이 시작되지 않아요',
            note: '이 화면 기준이에요. 실제 수는 완료 후 알려드려요',
          )
        : null;
    final inner = _impactInner(b);
    if (widget.scope != QoinRateScope.brand) return inner;
    return [
      if (brandOff) ...[
        const SizedBox(height: 12),
        const _WarnPlate(
          title: '이 브랜드는 지금 적립 사용 안 함이에요',
          text: '새 값을 적용해도 브랜드의 ‘적립 사용’ 을 켜기 전에는 산하 매장 전부가 적립되지 않아요',
        ),
      ],
      ...inner,
      ?infoK == null ? null : const SizedBox(height: 12),
      ?infoK,
    ];
  }

  List<Widget> _impactInner(QoinBulkConfirm? b) {
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
              // 수치를 모르면(보조 읽기 실패) 숫자 없이 말한다. 서버가 재개 시점에 다시 검증하고 확정 수치는 결과 카드로 돌아온다.
              title: b.remaining == null
                  ? '남은 매장의 개별 설정이 지워져요'
                  : '남은 ${b.remaining}곳의 개별 설정이 지워져요',
              body: null,
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
  const _WarnPlate({required this.text, this.title});
  final String text;

  /// 있으면 14/w700 제목 줄 + 13 본문.
  final String? title;

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
            child: title == null
                ? Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(text, style: QoinDialogShell.bodyStyle),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 일괄 적용 정보 줄 — 경고 plate 가 아니라 **안내**다 (배경 없음, `info` 아이콘, 접두 `경고` 없음).
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text, this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '정보. $text',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: QoinDialogShell.bodyStyle),
                if (note != null)
                  Text(note!, style: QoinDialogShell.noteStyle.copyWith(fontSize: 11)),
              ],
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
  });
  final String title;
  final String? body;

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
