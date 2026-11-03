import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/phone_validator.dart';

/// 전화번호 입력 formatter (숫자만, 최대 11자리). signup / 전화 수집 시트 공용.
List<TextInputFormatter> phoneInputFormatters() => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(kPhoneMaxLength),
];

/// 폼 TextField 공용 decoration (signup 과 동일 스타일).
InputDecoration formFieldDecoration(
  String label, {
  String? hintText,
  String? errorText,
}) {
  OutlineInputBorder border(Color? color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: color == null ? const BorderSide() : BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    errorText: errorText,
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
    border: border(null),
    focusedBorder: border(AppColors.primary),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
  );
}
