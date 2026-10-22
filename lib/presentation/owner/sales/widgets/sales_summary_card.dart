import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/sales_summary_entity.dart';
import 'package:qradar/presentation/owner/sales/formatters/sales_formatters.dart';

/// 매출 요약 카드. [SalesSummaryEntity] 값을 **그대로 표시만** 한다 (합산 금지).
///
/// 위계: 총 매출(32) > 주문 건수 / 평균 객단가(18) > 내역 plate(13).
class SalesSummaryCard extends StatelessWidget {
  const SalesSummaryCard({
    super.key,
    required this.summary,
    required this.isTruncated,
  });

  final SalesSummaryEntity summary;
  final bool isTruncated;

  static const String totalLabel = '총 매출';
  static const String countLabel = '주문 건수';
  static const String averageLabel = '평균 객단가';
  static const String inProgressLabel = '진행 중 포함';
  static const String refundedLabel = '환불 제외';
  static const String cancelledLabel = '취소 제외';
  static const String refundFootnote = '환불은 주문한 날의 매출에서 차감돼요';

  @override
  Widget build(BuildContext context) {
    final net = PriceFormatter.formatKrw(summary.netSales);
    final avg = PriceFormatter.formatKrw(summary.averageOrderValue);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            excludeSemantics: true,
            label: '$totalLabel $net',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  totalLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    net,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: AppColors.textHeading,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isTruncated ? 12 : 16),
          if (isTruncated) ...[
            const _TruncatedNotice(),
            const SizedBox(height: 16),
          ],
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Stat(
                    label: countLabel,
                    value: '${summary.orderCount}건',
                    semantic: '$countLabel ${summary.orderCount}건',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _Stat(
                      label: averageLabel,
                      value: avg,
                      semantic: '$averageLabel $avg',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BreakdownPlate(summary: summary),
        ],
      ),
    );
  }
}

class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice();

  @override
  Widget build(BuildContext context) {
    final text = SalesFormatters.truncatedWarning;
    return Semantics(
      excludeSemantics: true,
      label: '주의. $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.semantic,
  });

  final String label;
  final String value;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: semantic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 내역 plate: `진행 중 포함` / `환불 제외` / `취소 제외` 3행은 0건이어도 항상 표시.
class _BreakdownPlate extends StatelessWidget {
  const _BreakdownPlate({required this.summary});

  final SalesSummaryEntity summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BreakdownRow(
            icon: Icons.schedule_rounded,
            label: SalesSummaryCard.inProgressLabel,
            value: s.inProgressCount == 0
                ? '0건'
                : '${s.inProgressCount}건 · ${PriceFormatter.formatKrw(s.inProgressSales)}',
            empty: s.inProgressCount == 0,
            semantic: s.inProgressCount == 0
                ? '진행 중 0건'
                : '진행 중 ${s.inProgressCount}건, '
                      '${PriceFormatter.formatKrw(s.inProgressSales)}, 총 매출에 포함',
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            icon: Icons.undo_rounded,
            label: SalesSummaryCard.refundedLabel,
            // 환불은 error 색을 쓰지 않는다. `-` 부호만.
            value: s.refundedCount == 0
                ? '0건'
                : '${s.refundedCount}건 · ${PriceFormatter.formatKrw(-s.refundedAmount)}',
            empty: s.refundedCount == 0,
            semantic: s.refundedCount == 0
                ? '환불 0건'
                : '환불 ${s.refundedCount}건, '
                      '${PriceFormatter.formatKrw(s.refundedAmount)} 제외',
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            icon: Icons.block_rounded,
            label: SalesSummaryCard.cancelledLabel,
            value: '${s.cancelledCount}건',
            empty: s.cancelledCount == 0,
            semantic: s.cancelledCount == 0
                ? '취소 0건'
                : '취소 ${s.cancelledCount}건, 총 매출에서 제외',
          ),
          if (s.refundedCount > 0) ...[
            const SizedBox(height: 10),
            const Text(
              SalesSummaryCard.refundFootnote,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.empty,
    required this.semantic,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool empty;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: semantic,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: empty ? AppColors.textMuted : AppColors.textBody,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
