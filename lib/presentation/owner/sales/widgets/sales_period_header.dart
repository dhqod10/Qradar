import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/sales_query_limits.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/sales_period.dart';
import 'package:qradar/presentation/owner/sales/formatters/sales_formatters.dart';
import 'package:qradar/presentation/owner/sales/providers/owner_sales_providers.dart';

/// 기간 단위 세그먼트(일/주/월) + `‹ 기간 ›` 네비게이터. 화면 상단 고정.
class SalesPeriodHeader extends ConsumerWidget {
  const SalesPeriodHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(salesPeriodProvider);
    final notifier = ref.read(salesPeriodProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          _PeriodSegment(selected: period.type, onSelect: notifier.selectType),
          const SizedBox(height: 8),
          _PeriodNavigator(
            period: period,
            onPrevious: period.canGoPrevious() ? notifier.goPrevious : null,
            onNext: period.canGoNext() ? notifier.goNext : null,
          ),
        ],
      ),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({required this.selected, required this.onSelect});

  final SalesPeriodType selected;
  final ValueChanged<SalesPeriodType> onSelect;

  static const _items = <(SalesPeriodType, String)>[
    (SalesPeriodType.day, '일'),
    (SalesPeriodType.week, '주'),
    (SalesPeriodType.month, '월'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '기간 단위',
      container: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final (type, label) in _items)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: type == selected,
                  label: label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: type == selected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: type == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: type == selected
                              ? AppColors.onPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });

  final SalesPeriod period;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final title = SalesFormatters.periodTitle(period);
    final subtitle = SalesFormatters.periodSubtitle(period);
    final isCurrent = period.isCurrent();
    final pill = isCurrent
        ? SalesFormatters.currentPillLabel(period.type)
        : null;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: '이전 기간',
            disabledHint:
                '최대 ${SalesQueryLimits.maxMonthsBack}개월 전까지 조회할 수 있어요',
            onPressed: onPrevious,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              excludeSemantics: true,
              label:
                  '${SalesFormatters.periodSemanticLabel(period)}'
                  '${pill == null ? '' : ', $pill'}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),
                      if (pill != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBright.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pill,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: '다음 기간',
            disabledHint: '현재 기간이 마지막이에요',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.semanticLabel,
    required this.disabledHint,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final String disabledHint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      hint: enabled ? null : disabledHint,
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          onPressed: onPressed,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          icon: Icon(
            icon,
            size: 28,
            color: enabled
                ? AppColors.textHeading
                : AppColors.textMuted.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
