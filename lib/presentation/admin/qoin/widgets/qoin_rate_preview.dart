import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';

/// `결제 10,000원 → 300 Q 적립` 환산 미리보기 (1차 `_RatePreview` 추출 — 동작 그대로).
/// [tenths] 가 null(무효 입력)이면 `—`.
class QoinRatePreview extends StatelessWidget {
  const QoinRatePreview({super.key, required this.tenths});
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
