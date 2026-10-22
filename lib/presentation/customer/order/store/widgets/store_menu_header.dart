import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/favorite_toggle_icon_button.dart';
import 'package:qradar/presentation/customer/home/widgets/grade_badge.dart';
import 'package:qradar/presentation/customer/review/store_reviews_page.dart';

class StoreMenuHeader extends StatelessWidget {
  const StoreMenuHeader({
    super.key,
    required this.store,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  final StoreEntity store;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _backgroundImage()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.textHeading.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        Padding(
          // 배지 탭 영역(높이 44)을 확보하면서 시각 위치를 유지하기 위해 하단 padding 을 줄였다.
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      store.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                  FavoriteToggleIconButton(
                    isActive: isFavorite,
                    onTap: onFavoriteTap,
                    inactiveColor: AppColors.onPrimary,
                  ),
                ],
              ),
              Row(
                children: [
                  if (store.distanceKm != null) ...[
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: AppColors.onPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DistanceCalculator.formatKm(store.distanceKm!),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _OpenStatusText(hours: store.businessHours),
                  const Spacer(),
                  _TappableGradeBadge(store: store),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backgroundImage() {
    if (store.imageUrl.isEmpty) {
      return Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: const Icon(
          Icons.storefront_outlined,
          color: AppColors.textMuted,
          size: 48,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: store.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surface),
      errorWidget: (_, _, _) => Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        child: const Icon(
          Icons.storefront_outlined,
          color: AppColors.textMuted,
          size: 48,
        ),
      ),
    );
  }
}

/// 헤더 `GradeBadge` — 탭하면 매장 평가 목록으로 이동.
/// 눌림 피드백은 ripple 대신 불투명도 0.85 (사진 위에서 ripple 이 어색함).
class _TappableGradeBadge extends StatefulWidget {
  const _TappableGradeBadge({required this.store});
  final StoreEntity store;

  @override
  State<_TappableGradeBadge> createState() => _TappableGradeBadgeState();
}

class _TappableGradeBadgeState extends State<_TappableGradeBadge> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Semantics(
      button: true,
      label: store.reviewCount == 0
          ? '아직 평가가 없는 매장. 평가 목록 보기'
          : '${store.grade.label}, 평가 ${store.reviewCount}개. 평가 목록 보기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoreReviewsPage(store: store),
          ),
        ),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: _pressed ? 0.85 : 1,
                child: GradeBadge(
                  grade: store.grade,
                  reviewCount: store.reviewCount,
                  showChevron: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenStatusText extends StatelessWidget {
  const _OpenStatusText({required this.hours});
  final BusinessHours? hours;

  @override
  Widget build(BuildContext context) {
    if (hours == null) return const SizedBox.shrink();
    final open = _isOpenNow(hours!);
    return Text(
      open ? '영업 중' : '마감',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: open ? AppColors.success : AppColors.error,
      ),
    );
  }

  bool _isOpenNow(BusinessHours h) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    final open = _toMinutes(h.openTime);
    final close = _toMinutes(h.closeTime);
    if (open == null || close == null) return false;
    if (open == close) return false;
    if (open < close) {
      return nowMin >= open && nowMin < close;
    }
    // 자정 넘김
    return nowMin >= open || nowMin < close;
  }

  int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
