import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';

/// 주문 탭 검색어. 입력창 debounce 이후 갱신됨.
final orderSearchQueryProvider =
    NotifierProvider<OrderSearchQueryNotifier, String>(
  OrderSearchQueryNotifier.new,
);

class OrderSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

/// 주문 탭 등급 필터. 기본: 전체 선택. 최소 1개 유지.
final orderGradeFilterProvider =
    NotifierProvider<OrderGradeFilterNotifier, Set<StoreGrade>>(
  OrderGradeFilterNotifier.new,
);

class OrderGradeFilterNotifier extends Notifier<Set<StoreGrade>> {
  @override
  Set<StoreGrade> build() => {
        StoreGrade.s,
        StoreGrade.a,
        StoreGrade.b,
        StoreGrade.c,
      };

  void toggle(StoreGrade grade) {
    final next = <StoreGrade>{...state};
    if (next.contains(grade)) {
      if (next.length <= 1) return; // 최소 1개 유지
      next.remove(grade);
    } else {
      next.add(grade);
    }
    state = next;
  }
}

/// 사용자 위치 기준 주문 가능 매장 원본 리스트 (서버 조회).
/// 필터링 없이 `orderRadiusKm` 반경 내 최대 `orderStoresLimit` 개.
final orderBaseStoresProvider = FutureProvider<List<StoreEntity>>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  final useCase = ref.watch(getNearbyStoresUseCaseProvider);
  return useCase(
    location: location,
    radiusKm: GradeThresholds.orderRadiusKm,
    limit: GradeThresholds.orderStoresLimit,
  );
});

/// 검색어 + 등급 필터를 적용한 최종 매장 리스트. 거리 오름차순.
///
/// base 의 AsyncValue 상태(loading/error/data)를 그대로 전달하되,
/// data 단계에서 클라이언트 필터링 + 정렬을 수행.
final orderStoresProvider = Provider<AsyncValue<List<StoreEntity>>>((ref) {
  final base = ref.watch(orderBaseStoresProvider);
  final query = ref.watch(orderSearchQueryProvider).trim().toLowerCase();
  final grades = ref.watch(orderGradeFilterProvider);

  return base.whenData((stores) {
    final filtered = stores.where((s) {
      if (!grades.contains(s.grade)) return false;
      if (query.isEmpty) return true;
      return s.name.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      return da.compareTo(db);
    });

    return filtered;
  });
});
