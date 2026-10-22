import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_reenable_hint.dart';

/// 우선순위 사슬 — "왜 이 값이지?" 에 답한다. 매장 편집 3줄 / 브랜드 편집 2줄. 읽기 전용(chevron·ripple 없음).
/// 이기고 있는 줄 하나만 굵게 + `적용 중` pill. 필드 부재는 `설정 없음`, 스위치가 꺼진 줄은 **숫자 대신 `사용 안 함`** —
/// `5%` 로 읽히면 안 된다 (spec §20.6.2). 꺼진 줄이 있으면 하단에 `다시 켜면 …` 고지 ([QoinReenableHint] 한 함수).
///
/// 이 위젯은 "개별 적립률이 있으면 적립" 같은 분기를 만들지 않는다. 승자는 [EffectiveQoinRate] 가 정한다.
class QoinRateChain extends StatelessWidget {
  const QoinRateChain({
    super.key,
    required this.effective,
    required this.target,
  });

  final EffectiveQoinRate effective;

  /// store → 매장/브랜드/전역 3줄, brand → 브랜드/전역 2줄.
  final QoinRateScope target;

  @override
  Widget build(BuildContext context) {
    final e = effective;
    final QoinRateScope? winner = e.isInvalid
        ? null
        : (e.isDisabled
              ? (e.disabledSource == QoinRateSource.store
                    ? QoinRateScope.store
                    : QoinRateScope.brand)
              : (e.source == QoinRateSource.store
                    ? QoinRateScope.store
                    : e.source == QoinRateSource.brand
                    ? QoinRateScope.brand
                    : QoinRateScope.global));

    final rows = <_Row>[
      if (target == QoinRateScope.store)
        _Row('매장', QoinRateScope.store, e.store, e.storeSwitch),
      if (target != QoinRateScope.global &&
          (target == QoinRateScope.brand || e.hasBrand))
        _Row('브랜드', QoinRateScope.brand, e.brand, e.brandSwitch),
      _Row('전역', QoinRateScope.global, e.global, QoinSwitchSetting.enabled),
    ];

    final hint = QoinReenableHint.of(e, target: target);

    final spoken = StringBuffer('지금 적용되는 값.');
    for (final r in rows) {
      spoken.write(' ${r.label}은 ${_spokenValue(r)}');
      if (r.scope == winner) spoken.write(', 적용 중');
      spoken.write('.');
    }
    if (hint != null) spoken.write(' ${hint.headline}');

    return Semantics(
      container: true,
      label: spoken.toString(),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '지금 적용되는 값',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            for (final r in rows) ...[
              const SizedBox(height: 10),
              _ChainLine(
                row: r,
                wins: r.scope == winner,
                maskedByBrand:
                    r.scope == QoinRateScope.store &&
                    e.isDisabled &&
                    e.disabledSource == QoinRateSource.brand,
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              _HintBlock(hint: hint),
            ],
          ],
        ),
      ),
    );
  }

  static String _spokenValue(_Row r) {
    if (r.off) return QoinRateLabels.switchOff;
    if (r.switchInvalid) return QoinRateLabels.needsCheck;
    return QoinRateValueLabel.spokenSetting(r.setting);
  }
}

class _Row {
  const _Row(this.label, this.scope, this.setting, this.switchSetting);
  final String label;
  final QoinRateScope scope;
  final QoinRateSetting setting;
  final QoinSwitchSetting switchSetting;

  /// 이 줄이 꺼져 있는가 (스위치 off, 또는 TRANSITIONAL 레거시 0).
  bool get off => switchSetting.isDisabled || setting.isLegacyZero;
  bool get switchInvalid => switchSetting.isInvalid;
}

class _ChainLine extends StatelessWidget {
  const _ChainLine({
    required this.row,
    required this.wins,
    required this.maskedByBrand,
  });
  final _Row row;
  final bool wins;

  /// 브랜드 스위치가 꺼져서 이 (매장) 줄의 숫자가 효력이 없다.
  final bool maskedByBrand;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final invalid = r.setting.isInvalid || r.switchInvalid;
    final String value;
    if (r.off) {
      value = QoinRateLabels.switchOff;
    } else if (r.switchInvalid) {
      value = QoinRateLabels.needsCheck;
    } else {
      value = QoinRateValueLabel.setting(r.setting);
    }
    // 꺼진 줄이 이기지 못하면 `(가려짐)`, 숫자 줄이 브랜드 스위치에 가려져도 `(가려짐)`.
    final masked =
        (r.off && !wins) || (maskedByBrand && r.setting.isValid && !r.off);
    // R04b: 꺼진 줄에 개별 적립률이 남아 있으면 작게·흐리게 보조 줄.
    final ownRate = r.off && r.setting.isValid
        ? '개별 적립률 ${QoinPolicy.formatRatePercent(r.setting.value!)} 가 설정돼 있어요'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                r.label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (invalid)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 11,
                        color: AppColors.error,
                      ),
                    ),
                  if (r.off)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.pause_circle_outline_rounded,
                        size: 14,
                        color: wins ? AppColors.warning : AppColors.textMuted,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: wins ? FontWeight.w800 : FontWeight.w500,
                        color: wins
                            ? AppColors.textHeading
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (masked)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        '(가려짐)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (wins)
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryBright.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '적용 중',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ),
          ],
        ),
        if (ownRate != null)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 2),
            child: Text(
              ownRate,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

/// 사슬 하단 `다시 켜면 …` 블록 (고지 위치 1/2). 문장은 [QoinReenableHint] 가 만든다.
class _HintBlock extends StatelessWidget {
  const _HintBlock({required this.hint});
  final QoinReenableHint hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.restart_alt_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint.headline,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
              if (hint.sub != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint.sub!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
