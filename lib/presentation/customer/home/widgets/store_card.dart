import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/core/utils/store_sellability.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/store_open_state.dart';
import 'package:qradar/presentation/customer/home/widgets/grade_badge.dart';
import 'package:shimmer/shimmer.dart';

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// 주변매장 섹션용 가로 카드.
class NearbyStoreCard extends StatelessWidget {
  final StoreEntity store;
  final VoidCallback onTap;

  const NearbyStoreCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.4;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width.clamp(140.0, 180.0),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: _StoreImage(
                    url: store.imageUrl,
                    width: double.infinity,
                    height: 112,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GradeBadge(
                    grade: store.grade,
                    reviewCount: store.reviewCount,
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: StoreOpenBadge(store: store),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.distanceKm != null
                            ? DistanceCalculator.formatKm(store.distanceKm!)
                            : '-',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 맞춤 추천 섹션용 가로형 카드.
class RecommendedStoreCard extends StatelessWidget {
  final StoreEntity store;
  final VoidCallback onTap;

  /// 이름이 아니라 **주소로만** 걸린 검색 결과에 매칭된 주소를 보조 표기한다.
  /// null(기본)이면 현행 2줄 레이아웃 그대로 — 3줄 배치는 값이 있을 때만.
  final String? subtitle;

  const RecommendedStoreCard({
    super.key,
    required this.store,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: _StoreImage(
                    url: store.imageUrl,
                    width: 96,
                    height: 96,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GradeBadge(
                    grade: store.grade,
                    reviewCount: store.reviewCount,
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: StoreOpenBadge(store: store),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          store.distanceKm != null
                              ? DistanceCalculator.formatKm(store.distanceKm!)
                              : '-',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const _StoreImage({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => _shimmer(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: Container(
        width: width,
        height: height,
        color: AppColors.surface,
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_outlined,
        color: AppColors.textMuted,
        size: 28,
      ),
    );
  }
}

/// 홈 카드 영업상태 배지 (store_business_schedule Q5). 공용 [StoreOpenState] 재사용.
///
/// 임시 휴업(error) / 정기 휴무·영업시간 아님(중립 어두운 pill) / 영업 중(success 점). 스케줄 미설정이면 표시 없음.
/// 목록 전체에 분 타이머를 걸지 않는다 — 카드가 그려질 때(진입·재빌드) 한 번 계산한다.
class StoreOpenBadge extends StatelessWidget {
  final StoreEntity store;
  const StoreOpenBadge({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    if (store.temporaryClosed) {
      label = '임시 휴업';
      bg = AppColors.error;
    } else {
      final state = storeOpenStateOf(store, DateTime.now());
      switch (state.kind) {
        case StoreOpenKind.unrestricted:
          return const SizedBox.shrink();
        case StoreOpenKind.open:
          label = '영업 중';
          bg = AppColors.success;
        case StoreOpenKind.regularHoliday:
          label = '정기 휴무';
          bg = AppColors.textHeading.withValues(alpha: 0.72);
        case StoreOpenKind.outsideHours:
          label = '영업시간 아님';
          bg = AppColors.textHeading.withValues(alpha: 0.72);
      }
    }
    return Semantics(
      label: '$label 매장',
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
