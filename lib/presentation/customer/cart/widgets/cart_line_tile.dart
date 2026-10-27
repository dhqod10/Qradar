import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/cart_pricing.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/usecases/apply_repriced_cart_use_case.dart';
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
    this.priceChange,
    this.unavailableOptionItemIds = const {},
    this.serverRejectedOption = false,
    this.onReselectOptions,
  });

  final CartItemEntity item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  /// 행 상태 (design §4.1). `normal` 이면 기존 모양과 같다.
  final CartLineAvailability availability;

  /// 재가격으로 이 라인의 단가가 바뀌었다 (payment_price_authority design §5.1). null 이면 표시 없음 —
  /// "변동 없음" 과 "확인 실패" 가 같은 화면이다 (N1·P5).
  final CartLinePriceChange? priceChange;

  /// 선택할 수 없게 된 옵션 항목 id (`optionUnavailable` 일 때). 해당 라벨만 취소선으로 칠한다 (design §5.5, DQ5).
  final Set<String> unavailableOptionItemIds;

  /// `rejectedByServer` 가 옵션 사유(`OPTION_UNAVAILABLE`)에서 왔다 — 캡션만 다르다.
  final bool serverRejectedOption;

  /// `다시 고르기` — 라인을 빼고 메뉴 상세로 보낸다. null 이면 버튼을 그리지 않는다.
  final VoidCallback? onReselectOptions;

  bool get _blocked =>
      availability == CartLineAvailability.soldOut ||
      availability == CartLineAvailability.unavailable;

  /// 못 사는 메뉴·옵션이 깨진 라인은 수량을 바꿀 이유가 없다.
  bool get _stepperLocked =>
      _blocked || availability == CartLineAvailability.optionUnavailable;

  /// 가격 변동은 품절·판매 중단·옵션 위반 캡션이 이긴다 (그 라인은 어차피 결제 불가라 금액이 의미 없다).
  bool get _showPriceChange =>
      priceChange != null &&
      (availability == CartLineAvailability.normal ||
          availability == CartLineAvailability.rejectedByServer);

  Widget _dim(Widget child) =>
      _blocked ? Opacity(opacity: 0.45, child: child) : child;

  Widget? _caption() {
    // 가격 변동 캡션: 방향은 글자가 말한다 (아이콘 없음). 내림은 info 톤 — success(초록)는 "확인됨" 으로 읽혀 쓰지 않는다.
    if (_showPriceChange) {
      final up = priceChange!.isIncrease;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          up ? '가격이 올랐어요' : '가격이 내려갔어요',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: up ? AppColors.warning : AppColors.info,
          ),
        ),
      );
    }
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
      CartLineAvailability.optionUnavailable => (
        '선택할 수 없는 옵션이 있어요',
        AppColors.error,
        FontWeight.w600,
      ),
      CartLineAvailability.rejectedByServer => (
        serverRejectedOption
            ? '직전 결제에서 옵션이 바뀐 메뉴예요. 지금은 다시 바뀌었을 수 있어요'
            : '직전 결제에서 확인된 메뉴예요. 지금은 바뀌었을 수 있어요',
        AppColors.warning,
        FontWeight.w500,
      ),
    };
    if (text == null) return null;
    final reselect =
        onReselectOptions != null &&
        (availability == CartLineAvailability.optionUnavailable ||
            (availability == CartLineAvailability.rejectedByServer &&
                serverRejectedOption));
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
          if (reselect)
            TextButton(
              onPressed: onReselectOptions,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                '다시 고르기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBright,
                ),
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

  /// 옵션 요약 줄. 선택할 수 없게 된 옵션 라벨만 취소선 + error 색 (design §5.5). 나머지는 기존 스타일.
  Widget _optionSummary() {
    const base = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    );
    if (availability != CartLineAvailability.optionUnavailable ||
        unavailableOptionItemIds.isEmpty) {
      return Text(
        item.selectedOptions.map((o) => o.label).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final spans = <InlineSpan>[];
    for (var i = 0; i < item.selectedOptions.length; i++) {
      final o = item.selectedOptions[i];
      if (i > 0) spans.add(const TextSpan(text: ' · '));
      final bad = unavailableOptionItemIds.contains(o.itemId);
      spans.add(
        TextSpan(
          text: o.label,
          style: bad
              ? const TextStyle(
                  color: AppColors.error,
                  decoration: TextDecoration.lineThrough,
                )
              : null,
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }

  /// 금액 영역. 가격이 바뀐 라인은 이전 금액(취소선) 위에 현재 금액을 둔다 (design §5.1).
  Widget _priceArea() {
    const current = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );
    final change = priceChange;
    if (!_showPriceChange || change == null) {
      return _dim(Text(PriceFormatter.formatKrw(item.lineTotal), style: current));
    }
    final before = computeLineTotal(
      unitPrice: change.beforeUnitPrice,
      quantity: item.quantity,
    );
    return Semantics(
      label:
          '가격이 ${PriceFormatter.formatKrw(before)}에서 '
          '${PriceFormatter.formatKrw(item.lineTotal)}으로 바뀌었어요',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              PriceFormatter.formatKrw(before),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(PriceFormatter.formatKrw(item.lineTotal), style: current),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOptions = item.selectedOptions.isNotEmpty;
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
                if (hasOptions) ...[
                  const SizedBox(height: 4),
                  _dim(_optionSummary()),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 못 사는 메뉴·옵션이 깨진 라인은 수량을 바꿀 이유가 없다. 서버 지목만 있는 행은 막지 않는다 (N6).
                    IgnorePointer(
                      ignoring: _stepperLocked,
                      child: QuantityStepper(
                        value: item.quantity,
                        onChanged: onQuantityChanged,
                      ),
                    ),
                    _priceArea(),
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
