import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';

/// 추천 전체보기 정렬. 기본은 거리순 (현행 동작).
enum RecommendedSort { distance, grade }

final recommendedSortProvider =
    NotifierProvider<RecommendedSortNotifier, RecommendedSort>(
      RecommendedSortNotifier.new,
    );

class RecommendedSortNotifier extends Notifier<RecommendedSort> {
  @override
  RecommendedSort build() => RecommendedSort.distance;

  void select(RecommendedSort sort) => state = sort;
}

/// 정렬 규칙(순수) — `grade`: averageScore 내림차순, 동점이면 거리 오름차순(거리 미상은 뒤).
/// `distance`: 스냅샷이 이미 거리순이므로 입력 순서 그대로.
List<StoreEntity> sortRecommended(
  List<StoreEntity> stores,
  RecommendedSort sort,
) {
  if (sort == RecommendedSort.distance) return stores;
  final copy = [...stores];
  copy.sort((a, b) {
    final c = b.averageScore.compareTo(a.averageScore);
    if (c != 0) return c;
    return (a.distanceKm ?? double.infinity).compareTo(
      b.distanceKm ?? double.infinity,
    );
  });
  return copy;
}

/// `맞춤 추천` 전체 목록 — 홈과 전체보기 화면이 **같은 기준**으로 공유한다 (건수·`전체보기` 노출의 단일 출처).
/// 카테고리 선택 + 스냅샷 파생이므로 토글·정렬 변경은 읽기를 만들지 않는다.
final recommendedStoresFullProvider = Provider<AsyncValue<List<StoreEntity>>>((
  ref,
) {
  final sort = ref.watch(recommendedSortProvider);
  return ref
      .watch(filteredStoresProvider)
      .whenData((list) => sortRecommended(list, sort));
});

/// 홈 미리보기 — 상위 [GradeThresholds.recommendedPreviewCount] 건. 홈은 항상 거리순을 쓰도록
/// 정렬 상태(전체보기 화면 전용)를 보지 않고 필터 결과를 직접 자른다.
final recommendedStoresPreviewProvider =
    Provider<AsyncValue<List<StoreEntity>>>((ref) {
      return ref
          .watch(filteredStoresProvider)
          .whenData(
            (list) => list
                .take(GradeThresholds.recommendedPreviewCount)
                .toList(growable: false),
          );
    });

/// 전체 건수 — 헤더 `(n)` / `전체보기` / 더 보기 버튼의 단일 출처. 데이터가 없는 동안은 null.
final recommendedTotalCountProvider = Provider<int?>((ref) {
  return ref.watch(filteredStoresProvider).asData?.value.length;
});
