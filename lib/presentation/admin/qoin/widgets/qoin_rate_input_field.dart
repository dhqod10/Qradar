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
/// 입력은 퍼센트 + `%` 접미사 고정. 0 은 여기서 만들 수 없다 (`tooLow`) — 명시적 0% 는 `적립 안 함` 라디오 카드로만.
/// `0.03` 은 반드시 `tooLow` (하한 검사가 소수 자릿수 검사보다 먼저 — 100배 오입력 방어선).
class QoinRateInputField extends StatelessWidget {
  const QoinRateInputField({super.key, required this.controller});

  final TextEditingController controller;

  /// 현재 입력의 검증 결과 (페이지/폼이 저장 가능 여부를 알기 위해 쓴다).
  static RateInputResult resultOf(String text) =>
      QoinPolicy.validateRateInput(text);

  static String? errorTextFor(RateInputStatus status) {
    switch (status) {
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
  Widget build(BuildContext context) {
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
            return Semantics(
              label: '적립률, 퍼센트. 3퍼센트를 원하면 3을 입력',
              textField: true,
              child: TextField(
                controller: controller,
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
                  errorText: errorTextFor(status),
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
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${QoinPolicy.minPercentLabel} ~ ${QoinPolicy.maxPercentLabel}% 사이로 입력해요. '
          '3% 는 ‘3’ 으로 입력하세요 (0.03 이 아니에요)',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
