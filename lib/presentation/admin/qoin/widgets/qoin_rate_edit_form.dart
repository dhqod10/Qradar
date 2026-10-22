import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_confirm_dialog.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_input_field.dart';
import 'package:qradar/presentation/admin/qoin/widgets/qoin_rate_preview.dart';

/// 폼이 만든 저장 요청. 페이지가 어느 UseCase 로 호출할지 정한다.
class QoinRateSubmission {
  const QoinRateSubmission({required this.value, this.reason, this.mode});
  final QoinRateValue value;
  final String? reason;

  /// 브랜드 전용. 개별 설정이 0곳이면 항상 preserve.
  final QoinBulkMode? mode;
}

/// 브랜드 산하 매장 통계 (클라이언트 미리보기).
class QoinBulkStats {
  const QoinBulkStats({
    required this.total,
    required this.overridden,
    this.disabled = 0,
  });
  final int total;
  final int overridden;

  /// 스위치가 꺼진 산하 매장 수 K (미리보기). 일괄 적용은 스위치를 건드리지 않는다.
  final int disabled;
}

/// 설정 방식 (브랜드·매장).
enum QoinSetMode { inherit, direct }

/// **3범위 공통 편집 폼.** 설정 방식 라디오(브랜드·매장) + 입력 + 미리보기 + 사유 + 저장 버튼 + 확인 다이얼로그 호출.
/// 입력·검증·확인·표기는 전부 여기와 [QoinRateInputField] / [QoinRateConfirmDialog] 가 소유하고,
/// 페이지는 "어느 대상을 어떤 UseCase 로 저장하나" 만 안다 (검증 카피가 페이지에 0줄 — 드리프트 방지).
///
/// 규칙:
/// - 0 은 적립률이 아니다. 입력란의 `0` 은 `zero` 로 거부하고 `적립 사용` 스위치로 안내한다 (스위치는 이 폼 밖, 저장 버튼 아래 독립 카드).
/// - 스위치가 꺼져 있어도 입력란은 비활성화하지 않는다 — 숫자와 스위치는 독립인 두 축이다 (design §18-2.3).
/// - 초기 선택 = 서버의 현재 상태 (부재 → 상위 설정 따르기, 그 외 → 직접 설정(유효면 값 채움)).
/// - 초안은 서버 값이 바뀌어도 덮어쓰지 않는다. 확인 다이얼로그의 `현재` 는 탭 시점의 서버 값.
/// - 상위 설정 따르기를 고르면 입력란을 그리지 않는다 (비활성 입력란 금지 — "비어 있는 칸" 방지).
class QoinRateEditForm extends ConsumerStatefulWidget {
  const QoinRateEditForm({
    super.key,
    required this.scope,
    this.targetName,
    this.brandName,
    required this.current,
    required this.effective,
    required this.saveLabel,
    required this.onSubmit,
    this.bulkStats,
    this.onRetryBulk,
    this.followingStores,
    this.onGoToSwitch,
  });

  /// 매장·브랜드: `적립 사용 끄러 가기` — 스위치 카드로 스크롤. 전역은 null (링크 없음).
  final VoidCallback? onGoToSwitch;

  final QoinRateScope scope;
  final String? targetName;

  /// 매장 편집에서 `브랜드 "{이름}" 의 …` 문장용.
  final String? brandName;

  /// 대상 **자신**의 저장 원본 (4값).
  final QoinRateSetting current;

  /// 대상의 현재 해석 결과 + 각 단계 원본. 전역이면 store/brand 는 absent.
  final EffectiveQoinRate effective;
  final String saveLabel;

  /// 저장 실행. 실패는 던진다 (폼은 저장 중 상태만 관리하고, 메시지는 페이지가 보여준다).
  final Future<void> Function(QoinRateSubmission submission) onSubmit;

  /// 브랜드 전용. 로딩/에러 중에는 저장 버튼이 비활성이다 (영향 매장 수를 못 보여주면 저장하지 못한다).
  final AsyncValue<QoinBulkStats>? bulkStats;
  final VoidCallback? onRetryBulk;

  /// 전역 확인 다이얼로그의 `이 값을 따르는 매장 N곳`. null 이면 줄 생략.
  final int? followingStores;

  @override
  ConsumerState<QoinRateEditForm> createState() => _QoinRateEditFormState();
}

class _QoinRateEditFormState extends ConsumerState<QoinRateEditForm> {
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  late QoinSetMode _mode;
  QoinBulkMode _bulkMode = QoinBulkMode.preserve;
  bool _saving = false;

  bool get _isGlobal => widget.scope == QoinRateScope.global;

  @override
  void initState() {
    super.initState();
    // 최초 1회만 서버 값으로 초안을 채운다 — 이후 서버 값이 바뀌어도 덮어쓰지 않는다.
    final c = widget.current;
    if (_isGlobal) {
      _mode = QoinSetMode.direct;
    } else if (c.isAbsent) {
      _mode = QoinSetMode.inherit;
    } else {
      _mode = QoinSetMode.direct;
    }
    if (c.isValid) {
      _rateCtrl.text = QoinPolicy.formatTenths(
        QoinPolicy.tenthsFromRate(c.value!),
      );
    }
    _rateCtrl.addListener(_rebuild);
    _reasonCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _rateCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── 상태 계산 ────────────────────────────────────────────────────────────

  int? get _currentTenths => widget.current.isValid
      ? QoinPolicy.tenthsFromRate(widget.current.value!)
      : null;

  RateInputResult get _input => QoinRateInputField.resultOf(_rateCtrl.text);

  /// 저장하려는 값. 저장 불가 상태면 null.
  QoinRateValue? get _pending {
    switch (_mode) {
      case QoinSetMode.inherit:
        return widget.current.isAbsent ? null : const QoinRateValue.inherit();
      case QoinSetMode.direct:
        final r = _input;
        if (r.status != RateInputStatus.valid || r.tenths == null) return null;
        // 서버가 이미 이 값이면 변경 아님. 서버가 부재/무효였다가 직접 설정으로 바꿔 같은 숫자를 넣으면 "변경".
        if (widget.current.isValid && r.tenths == _currentTenths) return null;
        return QoinRateValue.rate(r.tenths!);
    }
  }

  QoinBulkStats? get _stats => widget.bulkStats?.asData?.value;

  bool get _bulkReady =>
      widget.scope != QoinRateScope.brand ||
      (widget.bulkStats?.hasValue ?? false);

  bool get _canSave => _pending != null && _bulkReady && !_saving;

  /// 상위 설정(이 대상이 상속하게 될 값). 매장은 브랜드→전역, 브랜드는 전역.
  EffectiveQoinRate get _upstream {
    // 스위치와 무관하게 "상속하게 될 숫자" 를 본다 (스위치 상태는 사슬이 말한다).
    final e = widget.effective.asIfEnabled();
    final isStore = widget.scope == QoinRateScope.store;
    return resolveEffectiveQoinRate(
      store: QoinRateSetting.absent,
      brand: isStore ? e.brand : QoinRateSetting.absent,
      global: e.global,
      hasBrand: isStore && e.hasBrand,
    );
  }

  String _inheritDescription() {
    final up = _upstream;
    if (up.isInvalid) return '상위 설정을 확인할 수 없어요';
    final pct = QoinPolicy.formatRatePercent(up.rate!);
    if (up.source == QoinRateSource.brand) {
      final n = widget.brandName ?? '';
      return '브랜드 "$n" 의 $pct 를 따라요';
    }
    return '전역 기본값 $pct 를 따라요';
  }

  // ── 저장 ─────────────────────────────────────────────────────────────────

  QoinBulkMode get _effectiveBulkMode {
    final s = _stats;
    return (s == null || s.overridden == 0) ? QoinBulkMode.preserve : _bulkMode;
  }

  Future<void> _onSave() async {
    final value = _pending;
    if (value == null) return;
    final reasonText = _reasonCtrl.text.trim();
    final reason = reasonText.isEmpty ? null : reasonText;

    // ── 확인 다이얼로그 입력 (현재는 탭 시점의 서버 값) ────────────────────
    // 비교는 스위치와 무관하게 "켜져 있다면 적용될 값" 끼리 한다 (design §18-2.3).
    final e = widget.effective.asIfEnabled();
    final QoinRateSetting nextSetting;
    final QoinConfirmAction action;
    switch (value) {
      case QoinRateValueRate(:final tenths):
        nextSetting = QoinRateSetting.valid(QoinPolicy.rateFromTenths(tenths));
        action = QoinConfirmAction.set;
      case QoinRateValueInherit():
        nextSetting = QoinRateSetting.absent;
        action = QoinConfirmAction.inherit;
    }
    final EffectiveQoinRate nextEffective;
    switch (widget.scope) {
      case QoinRateScope.global:
        nextEffective = resolveEffectiveQoinRate(
          store: QoinRateSetting.absent,
          brand: QoinRateSetting.absent,
          global: nextSetting,
          hasBrand: false,
        );
      case QoinRateScope.brand:
        nextEffective = resolveEffectiveQoinRate(
          store: QoinRateSetting.absent,
          brand: nextSetting,
          global: e.global,
        );
      case QoinRateScope.store:
        nextEffective = resolveEffectiveQoinRate(
          store: nextSetting,
          brand: e.brand,
          global: e.global,
          hasBrand: e.hasBrand,
        );
    }

    final current = (_isGlobal && widget.current.isAbsent)
        ? QoinConfirmValue.none
        : QoinConfirmValue.fromEffective(e, target: widget.scope);
    final next = QoinConfirmValue.fromEffective(
      nextEffective,
      target: widget.scope,
    );

    final stats = _stats;
    final bulk = widget.scope == QoinRateScope.brand && stats != null
        ? QoinBulkConfirm(
            total: stats.total,
            overridden: stats.overridden,
            disabledUntouched: stats.disabled,
            brandDisabled: widget.effective.brandSwitch.isDisabled,
            mode: _effectiveBulkMode,
          )
        : null;

    final ok = await QoinRateConfirmDialog.show(
      context,
      scope: widget.scope,
      targetName: widget.targetName,
      action: action,
      current: current,
      next: next,
      reason: reason,
      followingStores: widget.followingStores,
      bulk: bulk,
      savedWhileDisabled: widget.effective.isDisabled,
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        QoinRateSubmission(
          value: value,
          reason: reason,
          mode: widget.scope == QoinRateScope.brand ? _effectiveBulkMode : null,
        ),
      );
      if (mounted) _reasonCtrl.clear();
    } catch (_) {
      // 메시지는 페이지(onSubmit)가 보여준다. 폼은 저장 중 상태만 되돌린다.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final directTenths = input.status == RateInputStatus.valid
        ? input.tenths
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('적립률'),
        const SizedBox(height: 6),
        if (_isGlobal) ...[
          QoinRateInputField(controller: _rateCtrl),
          const SizedBox(height: 12),
          QoinRatePreview(tenths: directTenths),
        ] else ...[
          if (widget.effective.isDisabled) ...[
            _DisabledNotice(
              byBrand:
                  widget.effective.disabledSource == QoinRateSource.brand &&
                  widget.scope == QoinRateScope.store,
            ),
            const SizedBox(height: 12),
          ],
          const _SectionLabel('설정 방식'),
          const SizedBox(height: 6),
          _buildModeCards(directTenths),
        ],
        if (widget.scope == QoinRateScope.brand) ..._buildBulkSection(),
        const SizedBox(height: 20),
        const _SectionLabel('사유 (선택)'),
        const SizedBox(height: 6),
        _ReasonField(controller: _reasonCtrl),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canSave ? _onSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSave ? AppColors.primary : AppColors.textMuted,
              disabledBackgroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Text(
                    widget.saveLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCards(int? directTenths) {
    final isBrand = widget.scope == QoinRateScope.brand;
    final upstreamInvalid = _upstream.isInvalid;

    return Column(
      children: [
        _ModeCard(
          index: 1,
          selected: _mode == QoinSetMode.inherit,
          enabled: !upstreamInvalid && !_saving,
          title: '상위 설정 따르기',
          description: _inheritDescription(),
          onTap: () => setState(() => _mode = QoinSetMode.inherit),
        ),
        const SizedBox(height: 8),
        _ModeCard(
          index: 2,
          selected: _mode == QoinSetMode.direct,
          enabled: !_saving,
          title: '직접 설정',
          description: isBrand ? '이 브랜드의 적립률을 정해요' : '이 매장만의 적립률을 정해요',
          onTap: () => setState(() => _mode = QoinSetMode.direct),
          expanded: _mode == QoinSetMode.direct
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QoinRateInputField(
                      controller: _rateCtrl,
                      onGoToSwitch: widget.onGoToSwitch,
                    ),
                    const SizedBox(height: 12),
                    QoinRatePreview(tenths: directTenths),
                  ],
                )
              : null,
        ),
      ],
    );
  }

  /// 브랜드 전용: 산하 매장 정보 로딩 상태 + 하위 매장 처리 방식.
  List<Widget> _buildBulkSection() {
    final async = widget.bulkStats;
    if (async == null) return const [];
    return async.when(
      loading: () => const [
        SizedBox(height: 8),
        Text(
          '산하 매장 정보를 불러오는 중이에요',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
      error: (_, _) => [
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              '산하 매장을 불러오지 못했어요',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: widget.onRetryBulk,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
      data: (s) {
        // 개별 설정이 0곳이면 모드 선택을 건너뛴다 (보존과 동일하므로). 변경 상태일 때만 보인다.
        if (s.overridden == 0 || _pending == null) return const <Widget>[];
        final n = s.total;
        final m = s.overridden;
        return [
          const SizedBox(height: 20),
          const _SectionLabel('개별 설정이 있는 매장 처리'),
          const SizedBox(height: 4),
          Text(
            '산하 매장 $n곳 중 $m곳이 자기 적립률을 따로 정해 두었어요',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          _ModeCard(
            index: 1,
            groupSize: 2,
            selected: _bulkMode == QoinBulkMode.preserve,
            enabled: !_saving,
            title: '개별 설정 보존',
            description: '따로 정해 둔 $m곳은 그대로 두고, 나머지 ${n - m}곳에 새 값을 적용해요',
            onTap: () => setState(() => _bulkMode = QoinBulkMode.preserve),
          ),
          const SizedBox(height: 8),
          _ModeCard(
            index: 2,
            groupSize: 2,
            selected: _bulkMode == QoinBulkMode.overwrite,
            enabled: !_saving,
            warning: true,
            warnIcon: Icons.warning_amber_rounded,
            title: '개별 설정 덮어쓰기',
            description:
                '따로 정해 둔 $m곳의 설정을 지우고, $n곳 모두 새 값을 따르게 해요\n'
                '되돌리려면 매장마다 다시 설정해야 해요',
            onTap: () => setState(() => _bulkMode = QoinBulkMode.overwrite),
          ),
          if (s.disabled > 0 && !widget.effective.brandSwitch.isDisabled) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '적립 사용 안 함 ${s.disabled}곳은 어느 쪽을 골라도 적립이 시작되지 않아요',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            '영향 매장 수는 이 화면 기준이에요. 실제 적용 결과는 완료 후 이력에서 확인할 수 있어요',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ];
      },
    );
  }
}

/// 꺼져 있을 때 `적립률` 섹션 맨 위의 사실 고지 plate. 위험 경고가 아니므로 `warning` 색을 쓰지 않는다.
/// 브랜드 때문에 멈춘 매장에서도 "개별 적립률로 우회할 수 있다" 는 암시를 하지 않는다 (N4).
class _DisabledNotice extends StatelessWidget {
  const _DisabledNotice({required this.byBrand});
  final bool byBrand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
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
            child: byBrand
                ? const Text(
                    '브랜드가 적립 사용 안 함이라, 이 매장은 적립률과 관계없이 적립되지 않아요',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '지금은 적립 사용 안 함 상태예요.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '적립률을 바꿔도 다시 켜기 전에는 적립되지 않아요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
    ),
  );
}

/// 라디오 카드 (설정 방식 / 하위 매장 처리 방식 공용). 선택 시 테두리 `primary` 1.5px,
/// `warning` 카드는 선택 시 틴트 + `warning` 테두리 + 제목 앞 아이콘.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.index,
    required this.selected,
    required this.enabled,
    required this.title,
    required this.description,
    required this.onTap,
    this.expanded,
    this.warning = false,
    this.warnIcon = Icons.pause_circle_outline_rounded,
    this.groupSize = 2,
  });

  final int index;
  final int groupSize;
  final bool selected;
  final bool enabled;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? expanded;
  final bool warning;
  final IconData warnIcon;

  @override
  Widget build(BuildContext context) {
    final warnSelected = warning && selected;
    final borderColor = warnSelected
        ? AppColors.warning
        : selected
        ? AppColors.primary
        : AppColors.border;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: '$title, ${description.replaceAll('\n', ', ')}, $groupSize개 중 $index번째'
          '${selected ? ', 선택됨' : ''}',
      excludeSemantics: expanded == null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: warnSelected
              ? AppColors.warning.withValues(alpha: 0.10)
              : AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 22,
                            color: warnSelected
                                ? AppColors.warning
                                : selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (warnSelected) ...[
                                    Icon(warnIcon, size: 18, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textHeading,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (expanded != null) ...[
                      const SizedBox(height: 12),
                      expanded!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      maxLength: QoinPolicy.reasonMaxLength,
      minLines: 1,
      maxLines: 3,
      style: const TextStyle(fontSize: 15, color: AppColors.textBody),
      decoration: InputDecoration(
        hintText: '예: 10월 프로모션',
        hintStyle: const TextStyle(fontSize: 15, color: AppColors.textMuted),
        counterStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary),
      ),
    );
  }
}
