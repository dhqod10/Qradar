import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/usecases/apply_repriced_cart_use_case.dart';
import 'package:qradar/presentation/customer/cart/providers/checkout_validation_providers.dart';

/// 가격 변동 배너·시트가 그리는 합계 요약. 금액은 `cart_pricing.dart` 의 같은 함수로 맞춘 값이다 (새 산식 아님).
class CartPriceChangeSummary {
  const CartPriceChangeSummary({
    required this.beforeSubtotal,
    required this.afterSubtotal,
    required this.hasIncrease,
    required this.hasDecrease,
  });

  final int beforeSubtotal;
  final int afterSubtotal;
  final bool hasIncrease;
  final bool hasDecrease;
}

/// 현재 카트에 남아 있는 가격 변동만으로 이전·현재 합계를 만든다 (라인을 지웠거나 수량을 바꿔도 맞는다).
/// 변동이 없으면 null — 배너·시트 모두 그리지 않는다 ("변동 없음" 과 "확인 실패" 는 같은 화면이다, P5).
CartPriceChangeSummary? summarizePriceChanges(
  CartEntity? cart,
  CartPriceChangesState changes,
) {
  if (cart == null || changes.isEmpty) return null;
  var before = cart.subtotal;
  var any = false;
  var up = false;
  var down = false;
  for (final line in cart.items) {
    final c = changes.byCartItemId[line.cartItemId];
    if (c == null) continue;
    any = true;
    before =
        before -
        line.lineTotal +
        computeLineTotal(unitPrice: c.beforeUnitPrice, quantity: line.quantity);
    if (c.isIncrease) {
      up = true;
    } else {
      down = true;
    }
  }
  if (!any) return null;
  return CartPriceChangeSummary(
    beforeSubtotal: before,
    afterSubtotal: cart.subtotal,
    hasIncrease: up,
    hasDecrease: down,
  );
}

/// 가격이 바뀐 메뉴 한 줄 (체크아웃 시트의 변동 목록). 금액은 라인 합계 기준이다.
class PriceChangeRow {
  const PriceChangeRow({
    required this.name,
    required this.before,
    required this.after,
  });

  final String name;
  final int before;
  final int after;
}

/// 방금 적용된 변동을 카트 라인의 수량에 맞춰 목록으로 만든다. 카트에 없는 라인은 건너뛴다.
/// 이전·현재 모두 적용 결과의 **단가**로 만든다 — 카트 스트림이 아직 갱신되지 않았어도 맞다.
List<PriceChangeRow> priceChangeRows(
  CartEntity? cart,
  Iterable<CartLinePriceChange> changes,
) {
  if (cart == null) return const [];
  final byId = {for (final l in cart.items) l.cartItemId: l};
  final out = <PriceChangeRow>[];
  for (final c in changes) {
    final line = byId[c.cartItemId];
    if (line == null) continue;
    out.add(
      PriceChangeRow(
        name: c.menuItemName,
        before: computeLineTotal(
          unitPrice: c.beforeUnitPrice,
          quantity: line.quantity,
        ),
        after: computeLineTotal(
          unitPrice: c.afterUnitPrice,
          quantity: line.quantity,
        ),
      ),
    );
  }
  return out;
}

/// `이전 → 현재` 합계 한 줄 (배너·시트 공용). 숫자는 [PriceFormatter] 로 앱이 포맷한다 — 서버 문자열이 아니다.
class CartTotalChangeRow extends StatelessWidget {
  const CartTotalChangeRow({
    super.key,
    required this.before,
    required this.after,
  });

  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '합계가 ${PriceFormatter.formatKrw(before)}에서 '
          '${PriceFormatter.formatKrw(after)}으로 바뀌었어요',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '합계',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  PriceFormatter.formatKrw(before),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Text(
                  '  →  ',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                Text(
                  PriceFormatter.formatKrw(after),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 카트 상단 가격 변동 배너 (design §5.2). 가격이 **바뀐 순간**을 조용히 넘기지 않는다.
/// `확인했어요` 는 사용자가 읽었다는 표시이지 가격이 검증됐다는 표시가 아니다 — 누르면 아무 문구도 남기지 않고 사라진다.
class CartPriceChangeBanner extends StatelessWidget {
  const CartPriceChangeBanner({
    super.key,
    required this.summary,
    required this.onAcknowledge,
  });

  final CartPriceChangeSummary summary;
  final VoidCallback onAcknowledge;

  static String titleOf(CartPriceChangeSummary s) {
    if (s.hasIncrease && s.hasDecrease) {
      return '메뉴 가격이 바뀌어 카트 금액을 새로 맞췄어요';
    }
    return s.hasIncrease
        ? '메뉴 가격이 올라 카트 금액을 새로 맞췄어요'
        : '메뉴 가격이 내려 카트 금액을 새로 맞췄어요';
  }

  static const String body = '바뀐 가격으로 카트를 다시 담았어요. 아래 금액을 확인하고 결제해 주세요.';

  @override
  Widget build(BuildContext context) {
    // 내림만 있을 때만 info 톤. 오름·섞임은 warning. success(초록)는 쓰지 않는다 — "검증 통과" 로 읽힌다 (P5).
    final tone = (!summary.hasIncrease && summary.hasDecrease)
        ? AppColors.info
        : AppColors.warning;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.price_change_outlined, size: 18, color: tone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titleOf(summary),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              body,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 10),
            CartTotalChangeRow(
              before: summary.beforeSubtotal,
              after: summary.afterSubtotal,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: onAcknowledge,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(
                    '확인했어요',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBright,
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
