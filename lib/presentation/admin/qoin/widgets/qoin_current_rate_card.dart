import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_source_badge.dart';

/// 현재 적용 중 카드 (1차 `_CurrentConfigCard` 일반화).
/// 전역형([QoinCurrentRateCard.global]) — 허브/전역 편집. 값 + `적립 중/중단됨` pill + 10,000원 환산.
/// 대상형([QoinCurrentRateCard.target]) — 브랜드/매장 편집. 값 + 출처 배지 + 10,000원 환산.
class QoinCurrentRateCard extends StatelessWidget {
  const QoinCurrentRateCard._({
    super.key,
    this.cfg,
    this.effective,
    this.target,
  });

  const QoinCurrentRateCard.global({Key? key, required QoinConfigEntity? cfg})
    : this._(key: key, cfg: cfg);

  const QoinCurrentRateCard.target({
    Key? key,
    required EffectiveQoinRate effective,
    required QoinRateScope target,
  }) : this._(key: key, effective: effective, target: target);

  final QoinConfigEntity? cfg;
  final EffectiveQoinRate? effective;
  final QoinRateScope? target;

  @override
  Widget build(BuildContext context) {
    if (effective != null) return _buildTarget(effective!, target!);
    return _buildGlobal();
  }

  Widget _buildGlobal() {
    final rate = cfg?.accrualRate;
    final enabled = cfg?.enabled ?? false;
    final hasRate = rate != null;
    final tenths = hasRate ? QoinPolicy.tenthsFromRate(rate) : null;
    final preview = tenths == null ? null : QoinPolicy.previewAmount(tenths);
    final rateText = hasRate ? QoinPolicy.formatRatePercent(rate) : QoinRateLabels.none;
    final pill = enabled ? QoinRateLabels.enabledOn : QoinRateLabels.enabledOff;

    return Semantics(
      label: hasRate
          ? '전역 기본값. 적립률 ${QoinPolicy.formatTenths(tenths!)}퍼센트, $pill. '
                '결제 ${PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw)}이면 '
                '${QoinFormatters.number(preview!)} Q 적립'
          : '전역 기본값. 설정 없음, $pill',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '전역 기본값',
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '설정이 없어서 적립이 동작하지 않아요. 전역 기본값을 저장해 설정을 만들어주세요',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textBody),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarget(EffectiveQoinRate e, QoinRateScope target) {
    final kind = QoinRateBadgeKind.of(e, target: target);
    final tenths = e.isActive ? QoinPolicy.tenthsFromRate(e.rate!) : null;
    final preview = tenths == null ? null : QoinPolicy.previewAmount(tenths);
    final pay = PriceFormatter.formatKrw(QoinPolicy.previewPaymentKrw);

    return Semantics(
      label:
          '현재 적용 중. ${QoinRateValueLabel.spokenEffective(e)}, ${kind.label}'
          '${preview == null ? (e.isDisabled ? '. 결제 $pay이면 적립 없음' : '') : '. 결제 $pay이면 ${QoinFormatters.number(preview)} Q 적립'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration,
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
                QoinRateSourceBadge(kind: kind),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: QoinRateValueText(effective: e, kind: kind, fontSize: 28),
            ),
            const SizedBox(height: 8),
            if (e.isDisabled)
              Text(
                '결제 $pay → 적립 없음',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              )
            else if (preview != null)
              Text(
                '결제 $pay → ${QoinFormatters.number(preview)} Q 적립',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '적립률 설정에 문제가 있어 이 범위의 적립이 되지 않아요. 값을 다시 설정해주세요',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textBody),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static final BoxDecoration _cardDecoration = BoxDecoration(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
  );
}
