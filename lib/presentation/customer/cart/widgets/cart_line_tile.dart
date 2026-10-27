import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/presentation/common/quantity_stepper.dart';
import 'package:qradar/presentation/common/sold_out_overlay.dart';
import 'package:qradar/presentation/customer/cart/cart_line_availability.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.availability = CartLineAvailability.normal,
  });

  final CartItemEntity item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  /// 행 상태 (design §4.1). `normal` 이면 기존 모양과 같다.
  final CartLineAvailability availability;

  bool get _blocked =>
      availability == CartLineAvailability.soldOut ||
      availability == CartLineAvailability.unavailable;

  Widget _dim(Widget child) =>
      _blocked ? Opacity(opacity: 0.45, child: child) : child;

  Widget? _caption() {
    final (text, color, weight) = switch (availability) {
      CartLineAvailability.normal => (
        null,
        AppColors.textMuted,
        FontWeight.w500,
      ),
      CartLineAvailability.soldOut => (
        '지금은 품절이에요',
        AppColors.error,
        FontWeight.w600,
      ),
      CartLineAvailability.unavailable => (
        '이 매장에서 더 이상 판매하지 않아요',
        AppColors.error,
        FontWeight.w600,
      ),
      CartLineAvailability.rejectedByServer => (
        '직전 결제에서 확인된 메뉴예요. 지금은 바뀌었을 수 있어요',
        AppColors.warning,
        FontWeight.w500,
      ),
    };
    if (text == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: weight, color: color),
            ),
          ),
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              '빼기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = item.selectedOptions.map((o) => o.label).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(url: item.imageUrl, availability: availability),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _dim(
                        Text(
                          item.menuItemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: '라인 삭제',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _dim(
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 못 사는 메뉴는 수량을 바꿀 이유가 없다. 서버 지목만 있는 행은 막지 않는다 (N6).
                    IgnorePointer(
                      ignoring: _blocked,
                      child: QuantityStepper(
                        value: item.quantity,
                        onChanged: onQuantityChanged,
                      ),
                    ),
                    _dim(
                      Text(
                        PriceFormatter.formatKrw(item.lineTotal),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                // 캡션 줄은 위반 행에서만 추가된다 — 늦게 도착한 선검증 결과로 행 높이가 한 번 움직이므로 완화한다.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _caption() ?? const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.availability});
  final String url;
  final CartLineAvailability availability;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isEmpty
                ? _placeholder()
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppColors.surface),
                    errorWidget: (_, _, _) => _placeholder(),
                  ),
            if (availability == CartLineAvailability.soldOut)
              const SoldOutOverlay(
                fontSize: 11,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            // 판매 중단/메뉴 부재는 `품절` 이 사실이 아니므로 글자 없이 덮개만.
            if (availability == CartLineAvailability.unavailable)
              const SoldOutOverlay(showLabel: false),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_cafe_outlined,
        color: AppColors.textMuted,
        size: 24,
      ),
    );
  }
}
