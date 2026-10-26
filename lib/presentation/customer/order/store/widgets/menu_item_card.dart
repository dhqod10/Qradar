import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/presentation/common/sold_out_overlay.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    super.key,
    required this.menuItem,
    required this.onTap,
    this.highlighted = false,
  });

  final MenuItemEntity menuItem;
  final VoidCallback onTap;

  /// 홈 검색에서 넘어온 "찾은 메뉴" 표시 — 테두리만 `primary` 1.5px (스크롤 이동 없음).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final soldOut = menuItem.soldOut;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${menuItem.name}, ${soldOut ? '품절, ' : ''}${PriceFormatter.formatKrw(menuItem.basePrice)}. 탭하면 메뉴 상세로 이동',
      child: GestureDetector(
        // D9: 품절은 볼 수 있고 담을 수 없다 — 카드 탭은 막지 않는다 (상세가 품절을 표시하고 담기를 막는다).
        onTap: onTap,
        child: Container(
          decoration: _decoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [_image(), if (soldOut) const SoldOutOverlay()],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menuItem.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: soldOut
                            ? AppColors.textMuted
                            : AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PriceFormatter.formatKrw(menuItem.basePrice),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: soldOut
                            ? AppColors.textMuted
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image() {
    if (menuItem.imageUrl.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: menuItem.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surface),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_cafe_outlined,
        color: AppColors.textMuted,
        size: 28,
      ),
    );
  }

  BoxDecoration _decoration() {
    return BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      border: highlighted
          ? Border.all(color: AppColors.primary, width: 1.5)
          : Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
