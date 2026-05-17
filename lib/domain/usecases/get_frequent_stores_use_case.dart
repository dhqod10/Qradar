import 'package:qradar/core/constants/recommendation_thresholds.dart';
import 'package:qradar/domain/entities/frequent_store_entity.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/order_log_repository.dart';

/// "자주 찾는 매장" 카드 stream.
///
/// 입력은 OrderLog stream + favoriteStoreIds Set + storesById lookup.
/// Stream 합성은 Provider 단에서 chain 으로 처리하기 때문에 본 UseCase 는
/// **순수 계산** + uid 가드만 담당한다.
///
/// 알고리즘:
/// 1. uid 없으면 `Stream.value(const [])`
/// 2. lookbackDays(=30) 내 OrderLog 만 필터
/// 3. storeId 별 visitCount 집계
/// 4. score = visitCount + (isFavorite ? favoriteScoreBoost : 0)
/// 5. score >= frequentStoreMinVisits 만 통과 — 단, **visitCount > 0** 추가 가드
///    (즐겨찾기 boost 단독으로는 노출 X — Phase 2 spec 결정 F 잠정안)
/// 6. score 내림차순 상위 frequentStoreMaxItems 개
/// 7. StoreEntity lookup 후 합성 (없으면 카드에서 hide)
class GetFrequentStoresUseCase {
  final OrderLogRepository _repository;
  final String? Function() _currentUidGetter;

  GetFrequentStoresUseCase(this._repository, this._currentUidGetter);

  /// 정적 합성 헬퍼. Provider 단에서 OrderLog stream + favoriteIds + stores 를
  /// 합성한 뒤 본 메서드를 호출한다.
  static List<FrequentStoreEntity> compute({
    required List<OrderLogEntity> logs,
    required Set<String> favoriteStoreIds,
    required Map<String, StoreEntity> storesById,
    DateTime? now,
  }) {
    if (logs.isEmpty && favoriteStoreIds.isEmpty) {
      return const <FrequentStoreEntity>[];
    }
    final cutoff = (now ?? DateTime.now()).subtract(
      Duration(days: RecommendationThresholds.frequentStoreLookbackDays),
    );

    // storeId 별 (visitCount, lastSeenName) 집계
    final visitCountByStore = <String, int>{};
    final nameByStore = <String, String>{};
    for (final log in logs) {
      if (log.paidAt.isBefore(cutoff)) continue;
      visitCountByStore[log.storeId] =
          (visitCountByStore[log.storeId] ?? 0) + 1;
      // 최신 stream 기준 매장명 — log 는 paidAt desc 정렬을 가정하므로 첫 항목이 최신
      nameByStore.putIfAbsent(log.storeId, () => log.storeName);
    }

    final results = <FrequentStoreEntity>[];
    for (final entry in visitCountByStore.entries) {
      final storeId = entry.key;
      final visitCount = entry.value;
      final isFav = favoriteStoreIds.contains(storeId);
      final score = visitCount +
          (isFav ? RecommendationThresholds.favoriteScoreBoost : 0);
      if (score < RecommendationThresholds.frequentStoreMinVisits) continue;
      // visitCount 0 (즐겨찾기 단독) 인 경우는 위 visitCountByStore 에 안 들어와서
      // 자연 제외됨. visitCount >= 1 + score 임계값 통과만 노출.
      results.add(
        FrequentStoreEntity(
          storeId: storeId,
          storeName: nameByStore[storeId] ??
              storesById[storeId]?.name ??
              '',
          visitCount: visitCount,
          isFavorite: isFav,
          score: score,
          store: storesById[storeId],
        ),
      );
    }

    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.visitCount.compareTo(a.visitCount);
    });

    final take = results.length > RecommendationThresholds.frequentStoreMaxItems
        ? results.sublist(0, RecommendationThresholds.frequentStoreMaxItems)
        : results;
    return List<FrequentStoreEntity>.unmodifiable(take);
  }

  /// uid 가드만 적용해 logs stream 을 그대로 통과시키는 helper.
  /// 외부 합성을 Provider 가 담당하므로 본 메서드는 거의 사용되지 않는다 — 호출자는
  /// 직접 [_currentUidGetter] 와 [_repository.watchUserLogs] 를 사용해도 된다.
  Stream<List<OrderLogEntity>> watchUserLogsOrEmpty() {
    final uid = _currentUidGetter();
    if (uid == null) {
      return Stream<List<OrderLogEntity>>.value(const <OrderLogEntity>[]);
    }
    return _repository.watchUserLogs(uid);
  }
}
