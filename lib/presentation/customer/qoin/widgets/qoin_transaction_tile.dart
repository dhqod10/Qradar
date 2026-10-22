import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_type.dart';

/// 사유 문구. type 은 **문구 선택에만** 쓴다 (적립/회수 판정은 amount 부호).
/// earn 은 거래 문서의 `orderTotalPrice` / `accrualRate` (거래 당시 값) 를 쓴다 —
/// 정책이 바뀌어도 과거 행이 틀리지 않는다.
String qoinReasonText(QoinTransactionEntity tx) {
  switch (tx.type) {
    case QoinTransactionType.earn:
      final total = tx.orderTotalPrice;
      final rate = tx.accrualRate;
      if (total == null || rate == null || total <= 0 || rate <= 0) {
        return '픽업 완료 적립';
      }
      return '픽업 완료 적립 · 결제액 ${PriceFormatter.formatKrw(total)}의 '
          '${QoinPolicy.formatRatePercent(rate)}';
    case QoinTransactionType.clawback:
      return '환불로 회수';
    case null:
      return 'Qoin 조정';
  }
}

/// 스크린리더 문구. 음수 하이픈 대신 `적립`/`회수` 동사로 조립한다.
String qoinSpokenText(QoinTransactionEntity tx) {
  final amount = tx.amount;
  final abs = QoinFormatters.number(amount.abs());
  final store = tx.storeName.isEmpty ? 'Qoin 내역' : tx.storeName;
  final verb = amount > 0
      ? '$abs Q ${tx.type == QoinTransactionType.earn ? '적립' : '증가'}'
      : amount < 0
          ? '$abs Q ${tx.type == QoinTransactionType.clawback ? '회수' : '감소'}'
          : '0 Q';
  final after = amount >= 0 ? '적립 후' : '회수 후';
  final date = tx.createdAt == null
      ? ''
      : ', ${QoinFormatters.dateTimeSpoken(tx.createdAt!)}';
  return '$store, $verb, ${qoinReasonText(tx)}$date, '
      '$after 잔액 ${QoinFormatters.balanceSpoken(tx.balanceAfter)}'
      '${tx.orderId.isEmpty ? '' : '. 탭하면 주문 상세'}';
}

/// 원장 1행. 적립 `+` / 회수 `-` 판정은 amount 부호로. 회수에 error 색·취소선·dim 금지.
class QoinTransactionTile extends StatelessWidget {
  const QoinTransactionTile({super.key, required this.tx, this.onTap});

  final QoinTransactionEntity tx;

  /// null 이면 탭 비활성 (orderId 없는 행).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = tx.amount;
    final isLoss = amount < 0;
    final store = tx.storeName.isEmpty ? 'Qoin 내역' : tx.storeName;

    final IconData icon;
    if (tx.type == QoinTransactionType.earn) {
      icon = Icons.add_rounded;
    } else if (tx.type == QoinTransactionType.clawback) {
      icon = Icons.undo_rounded;
    } else {
      icon = Icons.swap_vert_rounded;
    }
    final Color iconBg = isLoss
        ? AppColors.textMuted.withValues(alpha: 0.15)
        : AppColors.primaryBright.withValues(alpha: 0.15);
    final Color iconFg = isLoss ? AppColors.textMuted : AppColors.primary;

    final hasOrder = tx.orderId.isNotEmpty && onTap != null;
    final now = DateTime.now();

    return Semantics(
      button: hasOrder,
      excludeSemantics: true,
      label: qoinSpokenText(tx),
      child: InkWell(
        onTap: hasOrder ? onTap : null,
        splashColor: hasOrder
            ? AppColors.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        highlightColor: hasOrder
            ? AppColors.primary.withValues(alpha: 0.02)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
                child: Icon(icon, size: 18, color: iconFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      qoinReasonText(tx),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textBody,
                      ),
                    ),
                    if (tx.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        QoinFormatters.dateTime(tx.createdAt!, now: now),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        QoinFormatters.signed(amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isLoss ? FontWeight.w600 : FontWeight.w700,
                          color: isLoss
                              ? AppColors.textMuted
                              : AppColors.textHeading,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '잔액 ${QoinFormatters.balance(tx.balanceAfter)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (hasOrder) ...[
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
