import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 우선순위 사슬 — "왜 이 값이지?" 에 답한다. 매장 편집 3줄 / 브랜드 편집 2줄. 읽기 전용(chevron·ripple 없음).
/// 이기고 있는 줄 하나만 굵게 + `적용 중` pill. 필드 부재는 `설정 없음`, 명시 0 은 `0% · 적립 안 함` —
/// "비어 보임" 을 만들지 않는다.
class QoinRateChain extends StatelessWidget {
  const QoinRateChain({super.key, required this.effective, required this.target});

  final EffectiveQoinRate effective;

  /// store → 매장/브랜드/전역 3줄, brand → 브랜드/전역 2줄.
  final QoinRateScope target;

  @override
  Widget build(BuildContext context) {
    final e = effective;
    final winner = e.isInvalid
        ? null
        : (e.source == QoinRateSource.store
              ? QoinRateScope.store
              : e.source == QoinRateSource.brand
              ? QoinRateScope.brand
              : QoinRateScope.global);

    final rows = <_Row>[
      if (target == QoinRateScope.store)
        _Row('매장', e.store, QoinRateScope.store),
      if (target != QoinRateScope.global && (target == QoinRateScope.brand || e.hasBrand))
        _Row('브랜드', e.brand, QoinRateScope.brand),
      _Row('전역', e.global, QoinRateScope.global),
    ];

    final spoken = StringBuffer('지금 적용되는 값.');
    for (final r in rows) {
      spoken.write(' ${r.label}은 ${QoinRateValueLabel.spokenSetting(r.setting)}');
      if (r.scope == winner) spoken.write(', 적용 중');
      spoken.write('.');
    }

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
              _ChainLine(row: r, wins: r.scope == winner),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.setting, this.scope);
  final String label;
  final QoinRateSetting setting;
  final QoinRateScope scope;
}

class _ChainLine extends StatelessWidget {
  const _ChainLine({required this.row, required this.wins});
  final _Row row;
  final bool wins;

  @override
  Widget build(BuildContext context) {
    final s = row.setting;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            row.label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (s.isInvalid)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 11,
                    color: AppColors.error,
                  ),
                ),
              Flexible(
                child: Text(
                  QoinRateValueLabel.chain(s),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: wins ? FontWeight.w800 : FontWeight.w500,
                    color: wins ? AppColors.textHeading : AppColors.textMuted,
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
    );
  }
}
