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
    case QoinTransactionType.spend:
      // 결제수단을 특정하지 않는다 (design §8.1). orderTotalPrice = 거래 당시 현금 결제액 (박제값).
      final cash = tx.orderTotalPrice;
      if (cash == null || cash <= 0) return '결제에 사용';
      return '결제에 사용 · 현금 결제 ${PriceFormatter.formatKrw(cash)}';
    case QoinTransactionType.spendRefund:
      return '주문 취소·환불로 사용한 Qoin 복원';
    case null:
      return 'Qoin 조정';
  }
}

/// 스크린리더 문구. 음수 하이픈 대신 `적립`/`회수`/`사용`/`복원` 동사로 조립한다.
String qoinSpokenText(QoinTransactionEntity tx) {
  final amount = tx.amount;
  final abs = QoinFormatters.number(amount.abs());
  final store = tx.storeName.isEmpty ? 'Qoin 내역' : tx.storeName;
  final verb = amount > 0
      ? '$abs Q ${_increaseVerb(tx.type)}'
      : amount < 0
      ? '$abs Q ${_decreaseVerb(tx.type)}'
      : '0 Q';
  final after = _afterPrefix(tx.type, amount);
  final date = tx.createdAt == null
      ? ''
      : ', ${QoinFormatters.dateTimeSpoken(tx.createdAt!)}';
  return '$store, $verb, ${qoinReasonText(tx)}$date, '
      '$after 잔액 ${QoinFormatters.balanceSpoken(tx.balanceAfter)}'
      '${tx.orderId.isEmpty ? '' : '. 탭하면 주문 상세'}';
}

String _increaseVerb(QoinTransactionType? t) => switch (t) {
  QoinTransactionType.earn => '적립',
  QoinTransactionType.spendRefund => '복원',
  _ => '증가',
};

String _decreaseVerb(QoinTransactionType? t) => switch (t) {
  QoinTransactionType.clawback => '회수',
  QoinTransactionType.spend => '사용',
  _ => '감소',
};

/// `… 후 잔액` 접두사. **타입별**로 고른다 — 예전의 부호 2갈래(`적립 후`/`회수 후`)는 사용(spend)을 "회수 후" 로 읽었다.
/// 미지 타입은 부호로 폴백 (전방 호환).
String _afterPrefix(QoinTransactionType? t, int amount) => switch (t) {
  QoinTransactionType.earn => '적립 후',
  QoinTransactionType.clawback => '회수 후',
  QoinTransactionType.spend => '사용 후',
  QoinTransactionType.spendRefund => '복원 후',
  null => amount >= 0 ? '적립 후' : '회수 후',
};

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

    // 아이콘 모양만 타입으로 고른다. 배경/전경/값 색은 amount 부호 (isLoss) 로 — 사용은 정상 거래라 error 색 금지.
    final IconData icon = switch (tx.type) {
      QoinTransactionType.earn => Icons.add_rounded,
      QoinTransactionType.clawback => Icons.undo_rounded,
      QoinTransactionType.spend => Icons.shopping_bag_outlined,
      QoinTransactionType.spendRefund => Icons.replay_rounded,
      null => Icons.swap_vert_rounded,
    };
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBg,
                ),
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
                          fontWeight: isLoss
                              ? FontWeight.w600
                              : FontWeight.w700,
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
