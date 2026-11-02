import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_spend_calculator.dart';
import 'package:qradar/presentation/common/q_logo.dart';
import 'package:qradar/presentation/customer/checkout/providers/qoin_spend_providers.dart';

/// 체크아웃 "Qoin 사용" 섹션 (qoin_spend design §1~§3, §5).
///
/// 헤더 + 카드를 **스스로 그린다.** 숨김 상태(S4 사용 중지 · S5 로드 실패)에서는 아무것도 그리지 않아
/// 체크아웃 화면이 이전과 같다 (회귀 0). 앞 간격(24)도 이 위젯이 가진다.
///
/// 사용가능액·클램프는 **표시용**이다 (`QoinSpendCalculator`). 서버가 잔액·정책·서버 소계로 최종 판정한다.
/// 입력 상태는 [qoinToUseProvider] 에 둔다 — 결제 버튼 금액·PriceSummary·이 섹션이 같은 값을 본다.
class QoinSpendSection extends ConsumerWidget {
  const QoinSpendSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(qoinSpendViewProvider);
    if (view.phase == QoinSpendPhase.hidden) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Qoin 사용',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: switch (view.phase) {
              QoinSpendPhase.loading => const _Skeleton(),
              QoinSpendPhase.active => _ActiveBody(view: view),
              _ => _InactiveBody(view: view),
            },
          ),
        ],
      ),
    );
  }
}

// ── 행 A: 보유 Qoin ──────────────────────────────────────────────────────────

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    // 음수 잔액은 error 색을 쓰지 않는다 — Qoin 탭 원칙과 같다 (design S2).
    final negative = balance < 0;
    return Semantics(
      label: '보유 Qoin ${QoinFormatters.balanceSpoken(balance)}',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.18),
            ),
            child: const ExcludeSemantics(
              child: QLogo(size: 16, animate: false, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '보유 Qoin',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            QoinFormatters.balance(balance),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: negative ? AppColors.textMuted : AppColors.textHeading,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 비활성 (S1~S3) ───────────────────────────────────────────────────────────

class _InactiveBody extends StatelessWidget {
  const _InactiveBody({required this.view});
  final QoinSpendView view;

  String get _message => switch (view.phase) {
    QoinSpendPhase.noBalance => '적립하면 결제에 쓸 수 있어요',
    QoinSpendPhase.negativeBalance => 'Qoin 잔액이 부족해 지금은 쓸 수 없어요',
    QoinSpendPhase.orderTooSmall =>
      '이 주문은 최소 ${PriceFormatter.formatKrw(view.policy.minCashFloor)}을 결제해야 해서 Qoin을 쓸 수 없어요',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BalanceRow(balance: view.balance),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
                child: Text(
                  _message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 로딩 ─────────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  Widget _bar(double w, double h, {double r = 6}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // 로딩 중 `0 Q` 를 절대 보이지 않는다 (0 은 정상 값이라 로딩과 혼동된다).
    return Semantics(
      label: 'Qoin 정보를 불러오는 중',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [_bar(70, 14), const Spacer(), _bar(80, 16)],
          ),
          const SizedBox(height: 12),
          _bar(double.infinity, 48, r: 12),
        ],
      ),
    );
  }
}

// ── 활성 ─────────────────────────────────────────────────────────────────────

class _ActiveBody extends ConsumerStatefulWidget {
  const _ActiveBody({required this.view});
  final QoinSpendView view;

  @override
  ConsumerState<_ActiveBody> createState() => _ActiveBodyState();
}

class _ActiveBodyState extends ConsumerState<_ActiveBody> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  Timer? _warnTimer;

  /// 클램프 경고 문구. null 이면 기본 문구. 3초 후 자동 해제 (design §2.3).
  String? _warning;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(qoinToUseProvider);
    _controller = TextEditingController(text: initial > 0 ? '$initial' : '');
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _warnTimer?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  QoinSpendView get _view => widget.view;

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      // 키보드에 가리지 않게 (design §2.2).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _fieldKey.currentContext;
        if (mounted && ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    } else {
      // 포커스 아웃: 단위가 맞지 않는 입력(minSpendUnit > 1)은 여기서 내림 값으로 정리한다.
      _writeText(_view.applied);
    }
  }

  void _writeText(int value) {
    final text = value > 0 ? '$value' : '';
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setWarning(String? text) {
    _warnTimer?.cancel();
    setState(() => _warning = text);
    if (text != null) {
      _warnTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _warning = null);
      });
    }
  }

  /// 한도를 넘은 입력의 경고 문구 (design §2.3). 잔액이 한도면 잔액 문구, 최소현금이 한도면 최소현금 문구.
  String _clampMessage() {
    final v = _view;
    final max = QoinFormatters.number(v.maxSpendable);
    if (v.limitedBy == QoinSpendLimitedBy.balance) {
      return '보유한 Qoin은 ${QoinFormatters.balance(v.balance)}예요. 최대 $max Q까지 적용했어요';
    }
    return '최소 ${PriceFormatter.formatKrw(v.policy.minCashFloor)}은 결제해야 해서 최대 $max Q까지 적용했어요';
  }

  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = digits.isEmpty ? 0 : (int.tryParse(digits) ?? _view.maxSpendable + 1);
    final max = _view.maxSpendable;
    if (parsed > max) {
      _writeText(max);
      ref.read(qoinToUseProvider.notifier).set(max);
      _setWarning(_clampMessage());
      return;
    }
    // 선행 0 제거 ("007" → "7").
    final normalized = parsed > 0 ? '$parsed' : '';
    if (digits.isNotEmpty && normalized != digits) _writeText(parsed);
    ref.read(qoinToUseProvider.notifier).set(parsed);
    if (_warning != null) _setWarning(null);
  }

  void _toggleMax() {
    HapticFeedback.selectionClick();
    final isMax = _view.applied > 0 && _view.applied == _view.maxSpendable;
    final next = isMax ? 0 : _view.maxSpendable;
    ref.read(qoinToUseProvider.notifier).set(next);
    _writeText(next);
    _setWarning(null);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final applied = view.applied;
    final max = view.maxSpendable;
    final isMax = applied > 0 && applied == max;

    // 스트림 갱신(잔액 감소 · 카트 소계 변경)으로 한도가 줄어 입력이 한도를 넘으면 조용히 바꾸지 않고 경고와 함께 클램프 (design §5).
    ref.listen<QoinSpendView>(qoinSpendViewProvider, (prev, next) {
      if (next.phase != QoinSpendPhase.active) return;
      final requested = ref.read(qoinToUseProvider);
      if (requested > next.maxSpendable) {
        ref.read(qoinToUseProvider.notifier).set(next.maxSpendable);
        _writeText(next.maxSpendable);
        _setWarning(_clampMessage());
      }
    });

    final warning = _warning;
    final unit = view.policy.minUnit;
    final String hint = '최대 ${QoinFormatters.number(max)} Q까지 쓸 수 있어요';
    final bool showFloorLine = view.limitedBy == QoinSpendLimitedBy.cashFloor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BalanceRow(balance: view.balance),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Qoin 사용 금액 입력, 최대 ${QoinFormatters.number(max)} Q',
                textField: true,
                child: Container(
                  key: _fieldKey,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: warning != null
                          ? AppColors.error
                          : _focus.hasFocus
                          ? AppColors.primary
                          : AppColors.border,
                      width: warning == null && _focus.hasFocus ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 14, right: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.right,
                          cursorColor: AppColors.primary,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          onChanged: _onChanged,
                          onSubmitted: (_) => _focus.unfocus(),
                          onTapOutside: (_) => _focus.unfocus(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Q',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: isMax ? '사용 취소' : '최대 사용, ${QoinFormatters.number(max)} Q 입력',
              excludeSemantics: true,
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _toggleMax,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: isMax
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                    foregroundColor: isMax
                        ? AppColors.onPrimary
                        : AppColors.primary,
                    side: BorderSide(
                      color: isMax ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isMax ? '사용 취소' : '최대 사용',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (warning != null)
          Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (unit > 1)
            Text(
              '${QoinFormatters.number(unit)} Q 단위로 쓸 수 있어요',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          if (showFloorLine)
            Text(
              '최소 ${PriceFormatter.formatKrw(view.policy.minCashFloor)}은 선택한 결제수단으로 결제돼요',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
        if (applied > 0) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '결제 예정 금액',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const Spacer(),
              Text(
                PriceFormatter.formatKrw(view.finalAmount(view.subtotal)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Qoin 사용분을 뺀 결제액 기준으로 적립돼요',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
