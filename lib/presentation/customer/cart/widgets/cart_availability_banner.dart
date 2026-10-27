import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';

/// 카트 상단 배너 (design §4.2). "막는 장치"가 아니라 "미리 알려 주는 장치"다 — 통과를 알리는 표시는 어디에도 없다.
///
/// 본문에 메뉴 이름을 넣지 않는다 (이름은 해당 행이 지목한다).
class CartAvailabilityBanner extends StatefulWidget {
  const CartAvailabilityBanner({
    super.key,
    required this.variant,
    required this.onRecheck,
  });

  final CartBannerVariant variant;

  /// `다시 확인`. 실패 알림(SnackBar)은 호출자가 처리한다 — 이 위젯은 끝날 때까지 스피너만 그린다.
  final Future<void> Function() onRecheck;

  static String titleOf(CartBannerVariant v) => switch (v) {
    CartBannerVariant.unavailableMenus => '결제하려면 확인이 필요한 메뉴가 있어요',
    CartBannerVariant.serverRejectedOnly => '직전 결제에서 문제가 있던 메뉴가 있어요',
    CartBannerVariant.storeUnavailable => '지금은 이 매장에서 주문할 수 없어요',
  };

  static String bodyOf(CartBannerVariant v) => switch (v) {
    CartBannerVariant.unavailableMenus =>
      '표시된 메뉴를 빼고 결제해 주세요. 방금 다시 판매를 시작했을 수도 있으니 \'다시 확인\'을 눌러 보세요.',
    CartBannerVariant.serverRejectedOnly =>
      '표시된 메뉴를 빼거나, 상황이 바뀌었을 수 있으니 \'다시 확인\'을 눌러 보세요.',
    CartBannerVariant.storeUnavailable =>
      '잠시 후 \'다시 확인\'을 눌러 보거나, 다른 매장에서 담아 주세요.',
  };

  @override
  State<CartAvailabilityBanner> createState() => _CartAvailabilityBannerState();
}

class _CartAvailabilityBannerState extends State<CartAvailabilityBanner> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRecheck();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  CartAvailabilityBanner.titleOf(widget.variant),
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
          Text(
            CartAvailabilityBanner.bodyOf(widget.variant),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 44,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _tap,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text(
                        '다시 확인',
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
    );
  }
}
