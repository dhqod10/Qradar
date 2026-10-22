import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';

/// 적립률 입력란 + 도움말 (1차 `_RateField` 추출 — 동작 그대로).
///
/// **검증 에러 문구(`0.1% 이상…`, `최대 … % 까지`, `소수 첫째 자리`)는 이 파일에만 존재한다.**
/// 전역/브랜드/매장 페이지는 `QoinPolicy.validateRateInput` 을 직접 호출하지 않는다 —
/// 검증 코드가 3벌이면 드리프트가 난다. 페이지는 [QoinRateInputField.statusOf] 로 상태만 얻는다.
///
/// 입력은 퍼센트 + `%` 접미사 고정. **0 은 적립률이 아니다** — `zero` 상태로 거부하고 스위치로 안내한다 (design §18-2.4).
/// `0.03` 은 반드시 `tooLow` (하한 검사가 소수 자릿수 검사보다 먼저 — 100배 오입력 방어선).
class QoinRateInputField extends StatefulWidget {
  const QoinRateInputField({
    super.key,
    required this.controller,
    this.onGoToSwitch,
  });

  final TextEditingController controller;

  /// 매장·브랜드 화면: `적립 사용 끄러 가기` 탭 동작 (스위치 카드로 스크롤). 스위치를 대신 누르지 않는다.
  /// null 이면 전역 화면 — 링크도 사전 안내 줄도 없다 (전역에는 이 화면에 스위치가 없다).
  final VoidCallback? onGoToSwitch;

  /// 현재 입력의 검증 결과 (페이지/폼이 저장 가능 여부를 알기 위해 쓴다).
  static RateInputResult resultOf(String text) =>
      QoinPolicy.validateRateInput(text);

  static String? errorTextFor(RateInputStatus status, {bool hasSwitch = true}) {
    switch (status) {
      case RateInputStatus.zero:
        return hasSwitch
            ? '0% 는 적립률로 입력할 수 없어요. 적립을 멈추려면 이 화면 아래쪽 ‘적립 사용’ 을 끄세요'
            : '0% 는 적립률로 입력할 수 없어요. 전체 적립을 멈추려면 Qoin 설정 화면의 ‘적립 사용’ 을 끄세요';
      case RateInputStatus.tooLow:
        return '${QoinPolicy.minPercentLabel}% 이상 입력해주세요. 3% 는 ‘3’ 으로 입력해요';
      case RateInputStatus.tooHigh:
        return '최대 ${QoinPolicy.maxPercentLabel}% 까지 입력할 수 있어요';
      case RateInputStatus.tooPrecise:
        return '소수 첫째 자리까지만 입력할 수 있어요';
      case RateInputStatus.empty:
      case RateInputStatus.malformed:
      case RateInputStatus.valid:
        return null;
    }
  }

  @override
  State<QoinRateInputField> createState() => _QoinRateInputFieldState();
}

class _QoinRateInputFieldState extends State<QoinRateInputField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// `0.5` 를 입력하는 도중 첫 글자 `0` 에서 에러가 번쩍이지 않게 한다:
  /// 입력이 정확히 `0` 한 글자인 동안은 포커스 중 에러를 숨기고 blur 에서 표시한다 (`0.` / `0.0` 은 즉시).
  bool _suppress(String text, RateInputStatus status) =>
      status == RateInputStatus.zero && text.trim() == '0' && _focus.hasFocus;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final hasSwitch = widget.onGoToSwitch != null;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final status = QoinPolicy.validateRateInput(controller.text).status;
            final showError = !_suppress(controller.text, status);
            final error = showError
                ? QoinRateInputField.errorTextFor(status, hasSwitch: hasSwitch)
                : null;
            final field = Semantics(
              label: '적립률, 퍼센트. 3퍼센트를 원하면 3을 입력',
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  hintStyle: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textMuted,
                  ),
                  suffixText: '%',
                  suffixStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                  errorText: error,
                  errorMaxLines: 2,
                  errorStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                  ),
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
            final showLink =
                hasSwitch && status == RateInputStatus.zero && showError;
            if (!showLink) return field;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field,
                Semantics(
                  button: true,
                  label: '적립 사용 끄러 가기, 버튼',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: widget.onGoToSwitch,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '적립 사용 끄러 가기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${QoinPolicy.minPercentLabel} ~ ${QoinPolicy.maxPercentLabel}% 사이로 입력해요. '
          '3% 는 ‘3’ 으로 입력하세요 (0.03 이 아니에요)',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        if (hasSwitch)
          const Text(
            '적립을 멈추려면 0 이 아니라 아래 ‘적립 사용’ 을 끄세요',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
