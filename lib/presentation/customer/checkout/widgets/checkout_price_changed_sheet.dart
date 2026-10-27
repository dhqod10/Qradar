import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/presentation/customer/cart/widgets/cart_price_change_banner.dart';
import 'package:qradar/presentation/customer/checkout/widgets/payment_menu_list_card.dart';

/// 가격 변동 시트에서 고객이 고른 것 (payment_price_authority design §5.4).
enum CheckoutPriceSheetChoice {
  /// `새 금액으로 계속하기` — 시트만 닫고 체크아웃에 머문다. **자동으로 결제하지 않는다.**
  stay,

  /// `카트에서 확인하기` — 체크아웃을 pop 한다.
  backToCart,
}

/// 옵션 위반 시트에서 고객이 고른 것.
enum CheckoutOptionSheetChoice {
  /// `카트에서 옵션 다시 고르기` — 체크아웃을 pop 한다 (카트 행이 옵션 단위로 지목한다).
  backToCart,

  /// `이 메뉴 (모두) 빼기` — 체크아웃에 머문다.
  removeMenus,
}

Future<T?> _show<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => child,
  );
}

/// 체크아웃 결제 탭에서 가격 변동이 발견됐을 때 (design §5.4). **카트 적용은 이 시트가 뜨기 전에 이미 끝나 있다** —
/// 시트를 아래로 밀어 닫아도 stale 상태가 남지 않는다. 시트는 알림이다. `그래도 이전 금액으로 결제` 는 없다(서버가 거절한다).
Future<CheckoutPriceSheetChoice?> showCheckoutPriceChangedSheet(
  BuildContext context, {
  required CartPriceChangeSummary summary,
  required List<PriceChangeRow> rows,
}) {
  return _show<CheckoutPriceSheetChoice>(
    context,
    CheckoutPriceChangedSheet(summary: summary, rows: rows),
  );
}

/// 옵션 위반 변형 (design §5.4): 우선순위는 옵션 위반 > 가격 변동.
Future<CheckoutOptionSheetChoice?> showCheckoutOptionSheet(
  BuildContext context, {
  required List<String> names,
}) {
  return _show<CheckoutOptionSheetChoice>(
    context,
    CheckoutOptionSheet(names: names),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textHeading,
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      height: 1.5,
      color: AppColors.textBody,
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _LineButton extends StatelessWidget {
  const _LineButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textBody,
        backgroundColor: AppColors.surfaceElevated,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class CheckoutPriceChangedSheet extends StatelessWidget {
  const CheckoutPriceChangedSheet({
    super.key,
    required this.summary,
    required this.rows,
  });

  final CartPriceChangeSummary summary;
  final List<PriceChangeRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      children: [
        const _Title('결제 금액이 바뀌었어요'),
        const SizedBox(height: 8),
        const _Body('메뉴 가격이 바뀌어 금액을 새로 맞췄어요. 결제는 아직 시작되지 않았어요.'),
        const SizedBox(height: 12),
        CartTotalChangeRow(
          before: summary.beforeSubtotal,
          after: summary.afterSubtotal,
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChangedRowsCard(rows: rows),
        ],
        const SizedBox(height: 16),
        _PrimaryButton(
          label: '새 금액으로 계속하기',
          onPressed: () =>
              Navigator.of(context).pop(CheckoutPriceSheetChoice.stay),
        ),
        const SizedBox(height: 8),
        _LineButton(
          label: '카트에서 확인하기',
          onPressed: () =>
              Navigator.of(context).pop(CheckoutPriceSheetChoice.backToCart),
        ),
      ],
    );
  }
}

/// 가격이 바뀐 메뉴 목록 카드. 전부 열거한다 (선행 D5) — 스크롤은 시트 본문의 몫이다.
class _ChangedRowsCard extends StatelessWidget {
  const _ChangedRowsCard({required this.rows});
  final List<PriceChangeRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가격이 바뀐 메뉴',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(color: AppColors.border, height: 1, thickness: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeading,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      PriceFormatter.formatKrw(rows[i].before),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const Text(
                      ' → ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      PriceFormatter.formatKrw(rows[i].after),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CheckoutOptionSheet extends StatelessWidget {
  const CheckoutOptionSheet({super.key, required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      children: [
        const _Title('옵션을 다시 골라야 해요'),
        const SizedBox(height: 8),
        const _Body('아래 메뉴에서 고르신 옵션을 지금은 선택할 수 없어요. 결제는 아직 시작되지 않았어요.'),
        if (names.isNotEmpty) ...[
          const SizedBox(height: 12),
          PaymentMenuListCard(
            header: '옵션을 다시 골라야 하는 메뉴',
            names: names,
            margin: EdgeInsets.zero,
            icon: Icons.tune_rounded,
          ),
        ],
        const SizedBox(height: 16),
        _PrimaryButton(
          label: '카트에서 옵션 다시 고르기',
          onPressed: () =>
              Navigator.of(context).pop(CheckoutOptionSheetChoice.backToCart),
        ),
        const SizedBox(height: 8),
        _LineButton(
          label: names.length > 1 ? '이 메뉴 모두 빼기' : '이 메뉴 빼기',
          onPressed: () =>
              Navigator.of(context).pop(CheckoutOptionSheetChoice.removeMenus),
        ),
      ],
    );
  }
}
