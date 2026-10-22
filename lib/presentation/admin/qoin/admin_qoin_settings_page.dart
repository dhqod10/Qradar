import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/presentation/customer/qoin/providers/qoin_di_providers.dart';
import 'package:qradar/presentation/customer/qoin/providers/qoin_providers.dart';

/// 관리자 Qoin 설정 (`config/qoin`: 적립률 + 적립 on/off).
///
/// 안전 설계:
///  - 적립률은 **퍼센트로 입력**받고 저장 시 1000 으로 나눈다(0.1% 단위 정수 연산).
///    하한 0.1% 가 `0.03` 오입력(100배 사고)의 차단선이다.
///  - 비상 정지(적립 사용 스위치)는 적립률 폼과 **저장 경로가 완전히 분리**된다.
///    적립률 검증에 막히지 않고, 작성 중인 적립률이 딸려 저장되지도 않는다.
class AdminQoinSettingsPage extends ConsumerStatefulWidget {
  const AdminQoinSettingsPage({super.key});

  @override
  ConsumerState<AdminQoinSettingsPage> createState() =>
      _AdminQoinSettingsPageState();
}

class _AdminQoinSettingsPageState extends ConsumerState<AdminQoinSettingsPage> {
  final TextEditingController _rateCtrl = TextEditingController();
  bool _initialized = false;
  bool _savingRate = false;
  bool _savingEnabled = false;

  @override
  void initState() {
    super.initState();
    _rateCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  /// 입력창 초기값은 최초 1회만 서버 값으로 채운다 — 이후 서버 값이 바뀌어도 초안을 덮어쓰지 않는다.
  void _initFrom(QoinConfigEntity? cfg) {
    if (_initialized) return;
    _initialized = true;
    final r = cfg?.accrualRate;
    if (r != null) {
      _rateCtrl.text = QoinPolicy.formatTenths(QoinPolicy.tenthsFromRate(r));
    }
  }

  static int? _serverTenths(QoinConfigEntity? cfg) {
    final r = cfg?.accrualRate;
    return r == null ? null : QoinPolicy.tenthsFromRate(r);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onSaveRate(QoinConfigEntity? cfg) async {
    final input = QoinPolicy.validateRateInput(_rateCtrl.text);
    final newTenths = input.tenths;
    if (input.status != RateInputStatus.valid || newTenths == null) return;

    // 다이얼로그의 "현재" 는 탭 시점의 서버 값.
    final latest = ref.read(qoinConfigProvider).asData?.value ?? cfg;
    final current = _serverTenths(latest);
    if (current == newTenths) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RateChangeDialog(currentTenths: current, newTenths: newTenths),
    );
    if (ok != true || !mounted) return;

    setState(() => _savingRate = true);
    try {
      await ref.read(saveQoinAccrualRateUseCaseProvider).call(newTenths);
      if (!mounted) return;
      _snack('적립률을 ${QoinPolicy.formatTenths(newTenths)}% 로 변경했어요');
    } catch (_) {
      if (!mounted) return;
      _snack('저장에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _savingRate = false);
    }
  }

  Future<void> _onToggleEnabled(QoinConfigEntity cfg, bool next) async {
    final latest = ref.read(qoinConfigProvider).asData?.value ?? cfg;
    final rateLabel = latest.accrualRate == null
        ? ''
        : QoinPolicy.formatRatePercent(latest.accrualRate!);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          next ? _EnableDialog(rateLabel: rateLabel) : const _DisableDialog(),
    );
    if (ok != true || !mounted) return;

    setState(() => _savingEnabled = true);
    try {
      // 적립률 폼과 독립된 경로: enabled 1필드만 저장.
      await ref.read(setQoinEnabledUseCaseProvider).call(next);
      if (!mounted) return;
      _snack(next ? 'Qoin 적립을 시작했어요' : 'Qoin 적립을 중단했어요');
    } catch (_) {
      if (!mounted) return;
      _snack('변경하지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _savingEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qoinConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textBody,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Qoin 설정'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: async.when(
        // 값을 모른 채 덮어쓰는 사고 방지: 로딩/에러 중에는 입력·스위치·저장을 노출하지 않는다.
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, _) =>
            _LoadError(onRetry: () => ref.invalidate(qoinConfigProvider)),
        data: (cfg) {
          _initFrom(cfg);
          return _buildBody(cfg);
        },
      ),
    );
  }

  Widget _buildBody(QoinConfigEntity? cfg) {
    final input = QoinPolicy.validateRateInput(_rateCtrl.text);
    final serverTenths = _serverTenths(cfg);
    final valid = input.status == RateInputStatus.valid;
    final changed = valid && input.tenths != serverTenths;
    final canSave = changed && !_savingRate;

    String? errorText;
    switch (input.status) {
      case RateInputStatus.tooLow:
        errorText =
            '${QoinPolicy.minPercentLabel}% 이상 입력해주세요. 3% 는 ‘3’ 으로 입력해요';
      case RateInputStatus.tooHigh:
        errorText = '최대 ${QoinPolicy.maxPercentLabel}% 까지 입력할 수 있어요';
      case RateInputStatus.tooPrecise:
        errorText = '소수 첫째 자리까지만 입력할 수 있어요';
      case RateInputStatus.empty:
      case RateInputStatus.malformed:
      case RateInputStatus.valid:
        errorText = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CurrentConfigCard(cfg: cfg),
          const SizedBox(height: 20),
          _EnabledSwitchCard(
            cfg: cfg,
            saving: _savingEnabled,
            onToggle: (next) => _onToggleEnabled(cfg!, next),
          ),
          const SizedBox(height: 20),
          const Text(
            '적립률',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          _RateField(controller: _rateCtrl, errorText: errorText),
          const SizedBox(height: 4),
          Text(
            '${QoinPolicy.minPercentLabel} ~ ${QoinPolicy.maxPercentLabel}% 사이로 입력해요. '
            '3% 는 ‘3’ 으로 입력하세요 (0.03 이 아니에요)',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _RatePreview(tenths: valid ? input.tenths : null),
          const SizedBox(height: 8),
          const Text(
            '고객 Qoin 탭에 ‘픽업 완료 시 결제액의 N% 적립’ 으로 표시돼요',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canSave ? () => _onSaveRate(cfg) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canSave
                    ? AppColors.primary
                    : AppColors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _savingRate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 로드 에러 ────────────────────────────────────────────────────────────────

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              '설정을 불러오지 못했어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '잠시 후 다시 시도해주세요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(160, 44),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 현재 적용 중 카드 ─────────────────────────────────────────────────────────

class _CurrentConfigCard extends StatelessWidget {
  const _CurrentConfigCard({required this.cfg});
  final QoinConfigEntity? cfg;

  @override
  Widget build(BuildContext context) {
    final rate = cfg?.accrualRate;
    final enabled = cfg?.enabled ?? false;
    final hasRate = rate != null;
    final tenths = hasRate ? QoinPolicy.tenthsFromRate(rate) : null;
    final preview = tenths == null ? null : QoinPolicy.previewAmount(tenths);

    final rateText = hasRate ? QoinPolicy.formatRatePercent(rate) : '설정 없음';
    final pill = enabled ? '적립 중' : '적립 중단됨';

    return Semantics(
      label: hasRate
          ? '현재 적용 중. 적립률 ${QoinPolicy.formatTenths(tenths!)}퍼센트, $pill. '
                '결제 ${PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw)}이면 '
                '${QoinFormatters.number(preview!)} Q 적립'
          : '현재 적용 중. 설정 없음, $pill',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '현재 적용 중',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: enabled
                        ? AppColors.primaryBright.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    pill,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: enabled ? AppColors.primary : AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              rateText,
              style: TextStyle(
                fontSize: hasRate ? 28 : 20,
                fontWeight: hasRate ? FontWeight.w800 : FontWeight.w700,
                color: hasRate ? AppColors.textHeading : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            if (hasRate)
              Text(
                '결제 ${PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw)} → '
                '${QoinFormatters.number(preview!)} Q 적립',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '설정이 없어서 적립이 동작하지 않아요. 적립률을 저장해 설정을 만들어주세요',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textBody,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 적립 사용 스위치 (즉시 반영, 적립률 폼과 독립) ──────────────────────────────

class _EnabledSwitchCard extends StatelessWidget {
  const _EnabledSwitchCard({
    required this.cfg,
    required this.saving,
    required this.onToggle,
  });

  final QoinConfigEntity? cfg;
  final bool saving;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = cfg?.enabled ?? false;
    // 문서가 없거나 적립률이 유효하지 않으면 켤 수 없다 (끄는 것은 항상 가능).
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
          child: Row(
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
        ),
        if (!canUse) ...[
          const SizedBox(height: 4),
          const Text(
            '설정 없음 — 먼저 적립률을 저장해주세요',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ── 적립률 입력 + 미리보기 ────────────────────────────────────────────────────

class _RateField extends StatelessWidget {
  const _RateField({required this.controller, required this.errorText});
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return Semantics(
      label: '적립률, 퍼센트. 3퍼센트를 원하면 3을 입력',
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // 숫자와 점만. 소수 자릿수는 검증이 안내한다 (0.03 이 조용히 막히지 않고 하한 에러가 보이도록).
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          LengthLimitingTextInputFormatter(5),
        ],
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textBody,
        ),
        decoration: InputDecoration(
          hintText: '예: 3',
          hintStyle: const TextStyle(fontSize: 18, color: AppColors.textMuted),
          suffixText: '%',
          suffixStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
          errorText: errorText,
          errorMaxLines: 2,
          errorStyle: const TextStyle(fontSize: 11, color: AppColors.error),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary),
          errorBorder: border(AppColors.error),
          focusedErrorBorder: border(AppColors.error),
        ),
      ),
    );
  }
}

class _RatePreview extends StatelessWidget {
  const _RatePreview({required this.tenths});
  final int? tenths;

  @override
  Widget build(BuildContext context) {
    final amount = tenths == null
        ? '—'
        : QoinFormatters.number(QoinPolicy.previewAmount(tenths!));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text:
                  '결제 ${PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw)} → ',
              style: const TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            TextSpan(
              text: '$amount Q',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            if (tenths != null)
              const TextSpan(
                text: ' 적립',
                style: TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 다이얼로그 ────────────────────────────────────────────────────────────────

AlertDialog _dialog({
  required String title,
  required List<Widget> content,
  required String cancelLabel,
  required String confirmLabel,
  required BuildContext context,
}) {
  return AlertDialog(
    backgroundColor: AppColors.surfaceElevated,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textHeading,
      ),
    ),
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
        onPressed: () => Navigator.of(context).pop(true),
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

const TextStyle _bodyStyle = TextStyle(
  fontSize: 13,
  height: 1.5,
  color: AppColors.textBody,
);
const TextStyle _noteStyle = TextStyle(
  fontSize: 12,
  color: AppColors.textMuted,
);

/// 끄기: "환불 회수도 멈춘다" 를 반드시 명시한다 (모르고 끄면 환불받은 고객이 Qoin 을 그대로 갖는다).
class _DisableDialog extends StatelessWidget {
  const _DisableDialog();

  @override
  Widget build(BuildContext context) {
    return _dialog(
      context: context,
      title: 'Qoin 적립을 중단할까요?',
      cancelLabel: '취소',
      confirmLabel: '적립 중단',
      content: const [
        Text('지금부터 아래 동작이 모두 멈춰요.', style: _bodyStyle),
        SizedBox(height: 8),
        Text('• 픽업이 완료되어도 Qoin 이 적립되지 않아요', style: _bodyStyle),
        Text('• 이미 적립된 주문이 환불되어도 Qoin 이 회수되지 않아요', style: _bodyStyle),
        Text('• 중단 중에 픽업 완료된 주문은 다시 켜도 자동으로 적립되지 않아요', style: _bodyStyle),
        SizedBox(height: 10),
        Text('고객 Qoin 탭에는 ‘적립이 잠시 중단되어 있어요’ 가 표시돼요', style: _noteStyle),
      ],
    );
  }
}

class _EnableDialog extends StatelessWidget {
  const _EnableDialog({required this.rateLabel});
  final String rateLabel;

  @override
  Widget build(BuildContext context) {
    return _dialog(
      context: context,
      title: 'Qoin 적립을 다시 시작할까요?',
      cancelLabel: '취소',
      confirmLabel: '적립 시작',
      content: [
        Text(
          '지금 설정된 적립률 $rateLabel 로, 이후 픽업 완료되는 주문부터 적립돼요. '
          '중단된 동안 완료된 주문은 소급 적립되지 않아요.',
          style: _bodyStyle,
        ),
      ],
    );
  }
}

/// 적립률 변경 확인 (항상 표시): 현재 -> 변경 비교 + 10,000원 기준 환산.
class _RateChangeDialog extends StatelessWidget {
  const _RateChangeDialog({
    required this.currentTenths,
    required this.newTenths,
  });

  final int? currentTenths;
  final int newTenths;

  @override
  Widget build(BuildContext context) {
    final cur = currentTenths;
    final warn = QoinPolicy.shouldWarnIncrease(
      currentTenths: cur,
      newTenths: newTenths,
    );
    final curLabel = cur == null ? '설정 없음' : '${QoinPolicy.formatTenths(cur)}%';
    final newLabel = '${QoinPolicy.formatTenths(newTenths)}%';
    final curAmount = cur == null
        ? '—'
        : QoinFormatters.number(QoinPolicy.previewAmount(cur));
    final newAmount = QoinFormatters.number(
      QoinPolicy.previewAmount(newTenths),
    );
    final pay = PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw);

    return _dialog(
      context: context,
      title: '적립률을 변경할까요?',
      cancelLabel: '취소',
      confirmLabel: '변경하기',
      content: [
        Semantics(
          label: cur == null
              ? '적립률을 설정 없음에서 ${QoinPolicy.formatTenths(newTenths)}퍼센트로 변경. '
                    '$pay 결제 기준 $newAmount Q'
              : '적립률을 현재 ${QoinPolicy.formatTenths(cur)}퍼센트에서 '
                    '${QoinPolicy.formatTenths(newTenths)}퍼센트로 변경. '
                    '$pay 결제 기준 $curAmount Q에서 $newAmount Q',
          excludeSemantics: true,
          child: Container(
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
                    Expanded(child: Text('현재', style: _noteStyle)),
                    SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        '변경',
                        textAlign: TextAlign.end,
                        style: _noteStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        curLabel,
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
                        newLabel,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('$pay 결제 기준 $curAmount Q → $newAmount Q', style: _bodyStyle),
        if (warn) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '변경 값이 현재의 2배 이상이거나 10% 이상이에요. 입력값이 맞는지 한 번 더 확인해주세요',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          '변경 후 픽업이 완료되는 주문부터 적용돼요. 이미 적립된 Qoin 은 바뀌지 않아요',
          style: _noteStyle,
        ),
        if (cur == null) ...[
          const SizedBox(height: 6),
          const Text('적립은 ‘적립 사용’ 을 켜야 시작돼요', style: _noteStyle),
        ],
      ],
    );
  }
}
