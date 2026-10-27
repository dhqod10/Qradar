import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/checkout/widgets/payment_menu_list_card.dart';

/// 체크아웃 차단 시트에서 고객이 고른 것 (design §4.4).
enum CheckoutBlockedChoice {
  /// `이 메뉴 (모두) 빼기` — 체크아웃에 머문다. 자동 결제하지 않는다.
  removeMenus,

  /// `카트에서 확인하기` / `카트로 돌아가기` — 체크아웃을 pop 한다.
  backToCart,
}

/// 선검증이 위반을 **직접 읽어서 확인했을 때만** 띄운다 (design §4.4). 취소 가능하며 결제를 시작하는 단계가 아니다.
/// `그래도 결제` 버튼은 없다 (위반은 서버가 어차피 거절한다). 시트 바깥 탭/스와이프는 null 을 반환한다.
///
/// [names] 는 고객 카트의 `menuItemName` 이다. [storeBlocked] 이면 목록 카드·보조 버튼 없이 매장 변형을 그린다.
Future<CheckoutBlockedChoice?> showCheckoutBlockedSheet(
  BuildContext context, {
  required List<String> names,
  required bool storeBlocked,
}) {
  return showModalBottomSheet<CheckoutBlockedChoice>(
    context: context,
    isDismissible: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        CheckoutBlockedSheet(names: names, storeBlocked: storeBlocked),
  );
}

class CheckoutBlockedSheet extends StatelessWidget {
  const CheckoutBlockedSheet({
    super.key,
    required this.names,
    required this.storeBlocked,
  });

  final List<String> names;
  final bool storeBlocked;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final title = storeBlocked ? '지금은 이 매장에서 주문할 수 없어요' : '결제하기 전에 확인이 필요해요';
    final body = storeBlocked
        ? '잠시 후 다시 시도하거나 다른 매장에서 주문해 주세요. 결제는 아직 시작되지 않았어요.'
        : '아래 메뉴는 지금 주문할 수 없어요. 빼고 계속하거나 카트에서 확인해 주세요. 결제는 아직 시작되지 않았어요.';
    final primaryLabel = storeBlocked
        ? '카트로 돌아가기'
        : (names.length > 1 ? '이 메뉴 모두 빼기' : '이 메뉴 빼기');

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
            if (!storeBlocked && names.isNotEmpty) ...[
              const SizedBox(height: 12),
              PaymentMenuListCard(
                header: '빼야 하는 메뉴',
                names: names,
                margin: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  storeBlocked
                      ? CheckoutBlockedChoice.backToCart
                      : CheckoutBlockedChoice.removeMenus,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!storeBlocked) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(CheckoutBlockedChoice.backToCart),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textBody,
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '카트에서 확인하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
