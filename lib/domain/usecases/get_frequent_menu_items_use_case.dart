import 'package:qradar/core/constants/recommendation_thresholds.dart';
import 'package:qradar/domain/entities/frequent_menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/repositories/order_log_repository.dart';

/// "자주 찾는 메뉴" 카드 stream.
///
/// 입력은 OrderLog stream + favoriteMenuItemKeys Set + menuItems lookup
/// (이미지/가격 보강용). Stream 합성은 Provider 단에서.
///
/// 알고리즘:
/// 1. uid 없으면 `Stream.value(const [])`
/// 2. lookbackDays(=30) 내 OrderLog 만 필터
/// 3. (storeId, menuItemId) 페어별 orderCount aggregate (quantity 합 X — 발생 횟수만)
/// 4. key = `'${storeId}_${menuItemId}'` 가 favoriteMenuItemKeys 에 있으면 isFavorite=true
/// 5. score = orderCount + (isFavorite ? favoriteScoreBoost : 0)
/// 6. score >= frequentMenuPairMinVisits 만 통과 (orderCount > 0 자연 가드)
/// 7. score 내림차순 상위 frequentMenuPairMaxItems 개
/// 8. menuItems lookup 으로 imageUrl / basePrice 합성
class GetFrequentMenuItemsUseCase {
  final OrderLogRepository _repository;
  final String? Function() _currentUidGetter;

  GetFrequentMenuItemsUseCase(this._repository, this._currentUidGetter);

  static String pairKey({
    required String storeId,
    required String menuItemId,
  }) =>
      '${storeId}_$menuItemId';

  /// 정적 합성 헬퍼. Provider 단에서 호출.
  static List<FrequentMenuItemEntity> compute({
    required List<OrderLogEntity> logs,
    required Set<String> favoriteMenuItemKeys,
    required Map<String, List<MenuItemEntity>> menuItemsByStore,
    DateTime? now,
  }) {
    if (logs.isEmpty) return const <FrequentMenuItemEntity>[];
    final cutoff = (now ?? DateTime.now()).subtract(
      Duration(days: RecommendationThresholds.frequentMenuPairLookbackDays),
    );

    final orderCountByPair = <String, int>{};
    // 페어 메타 (메뉴명 / 매장명) — log 가 paidAt desc 정렬 가정, 최신 라벨 사용.
    final storeIdByPair = <String, String>{};
    final menuItemIdByPair = <String, String>{};
    final menuNameByPair = <String, String>{};
    final storeNameByPair = <String, String>{};

    for (final log in logs) {
      if (log.paidAt.isBefore(cutoff)) continue;
      for (final item in log.items) {
        final k = pairKey(storeId: log.storeId, menuItemId: item.menuItemId);
        orderCountByPair[k] = (orderCountByPair[k] ?? 0) + 1;
        storeIdByPair.putIfAbsent(k, () => log.storeId);
        menuItemIdByPair.putIfAbsent(k, () => item.menuItemId);
        menuNameByPair.putIfAbsent(k, () => item.menuItemName);
        storeNameByPair.putIfAbsent(k, () => log.storeName);
      }
    }

    final results = <FrequentMenuItemEntity>[];
    for (final entry in orderCountByPair.entries) {
      final k = entry.key;
      final orderCount = entry.value;
      final isFav = favoriteMenuItemKeys.contains(k);
      final score = orderCount +
          (isFav ? RecommendationThresholds.favoriteScoreBoost : 0);
      if (score < RecommendationThresholds.frequentMenuPairMinVisits) continue;

      final storeId = storeIdByPair[k]!;
      final menuItemId = menuItemIdByPair[k]!;
      // menuItems lookup 으로 imageUrl / basePrice 보강
      String imageUrl = '';
      int basePrice = 0;
      final list = menuItemsByStore[storeId];
      if (list != null) {
        for (final m in list) {
          if (m.id == menuItemId) {
            imageUrl = m.imageUrl;
            basePrice = m.basePrice;
            break;
          }
        }
      }

      results.add(
        FrequentMenuItemEntity(
          storeId: storeId,
          storeName: storeNameByPair[k] ?? '',
          menuItemId: menuItemId,
          menuItemName: menuNameByPair[k] ?? '',
          imageUrl: imageUrl,
          basePrice: basePrice,
          orderCount: orderCount,
          isFavorite: isFav,
          score: score,
        ),
      );
    }

    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.orderCount.compareTo(a.orderCount);
    });

    final take =
        results.length > RecommendationThresholds.frequentMenuPairMaxItems
            ? results.sublist(
                0, RecommendationThresholds.frequentMenuPairMaxItems)
            : results;
    return List<FrequentMenuItemEntity>.unmodifiable(take);
  }

  Stream<List<OrderLogEntity>> watchUserLogsOrEmpty() {
    final uid = _currentUidGetter();
    if (uid == null) {
      return Stream<List<OrderLogEntity>>.value(const <OrderLogEntity>[]);
    }
    return _repository.watchUserLogs(uid);
  }
}
