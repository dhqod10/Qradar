import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/core/utils/store_schedule_format.dart';
import 'package:qradar/core/utils/store_sellability.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/favorite_toggle_icon_button.dart';
import 'package:qradar/presentation/common/store_open_state.dart';
import 'package:qradar/presentation/customer/home/widgets/grade_badge.dart';
import 'package:qradar/presentation/customer/review/store_reviews_page.dart';

class StoreMenuHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final openState = watchStoreOpenState(ref, store);
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
                  if (store.temporaryClosed)
                    const _TemporaryClosedBadge()
                  else
                    Flexible(child: _StoreOpenStatus(state: openState)),
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

/// 임시 휴업 배지 (temporary_closed_gate design §1-1). 영업시간 문구보다 우선한다.
class _TemporaryClosedBadge extends StatelessWidget {
  const _TemporaryClosedBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '임시 휴업중인 매장',
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Text(
          '임시 휴업중',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// 정기 휴무 / 영업시간 아님 배지 (store_business_schedule design §3.1).
/// 임시 휴업(빨강)과 구분되는 중립 톤 — 정해진 스케줄상 닫힘은 비정상이 아니다.
class _ScheduleClosedBadge extends StatelessWidget {
  const _ScheduleClosedBadge({required this.label, required this.semantics});
  final String label;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.textHeading.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// 헤더 영업 상태 — 공용 [StoreOpenState] 만 그린다 (자체 시간 계산 없음).
class _StoreOpenStatus extends StatelessWidget {
  const _StoreOpenStatus({required this.state});
  final StoreOpenState state;

  @override
  Widget build(BuildContext context) {
    switch (state.kind) {
      case StoreOpenKind.unrestricted:
        return const SizedBox.shrink();
      case StoreOpenKind.regularHoliday:
        return const _ScheduleClosedBadge(
          label: '정기 휴무',
          semantics: '정기 휴무 중인 매장',
        );
      case StoreOpenKind.outsideHours:
        return const _ScheduleClosedBadge(
          label: '영업시간 아님',
          semantics: '지금은 영업시간이 아닌 매장',
        );
      case StoreOpenKind.open:
        final until = formatCloseAt(
          state.closeAt,
          kstClockOf(DateTime.now()).dateKey,
        );
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '영업 중',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              if (until != null)
                TextSpan(
                  text: ' · $until',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}
