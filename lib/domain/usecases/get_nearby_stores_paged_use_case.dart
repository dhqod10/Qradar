import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_page.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// 주변매장 전체보기 — 반경 [radiusKm] 이내 매장을 가까운 순으로 읽는다 (store_list_pagination).
///
/// 반경 확장 / 중복 제거 / 소진 판정 규칙은 순수 static 헬퍼로 분리해 단위 테스트한다.
class GetNearbyStoresPagedUseCase {
  final StoreRepository _repository;
  GetNearbyStoresPagedUseCase(this._repository);

  Future<StorePage> call({
    required UserLocation center,
    required double radiusKm,
  }) => _repository.getNearbyStoresPaged(center: center, radiusKm: radiusKm);

  /// [current] 다음 반경. 최대 반경을 넘지 않는다.
  static double nextRadius(double current) {
    final next = current * GradeThresholds.nearbyPagedRadiusFactor;
    return next > GradeThresholds.nearbyPagedMaxRadiusKm
        ? GradeThresholds.nearbyPagedMaxRadiusKm
        : next;
  }

  /// 더 확장할 수 없는 반경인가 (최대 반경 도달).
  static bool isMaxRadius(double radiusKm) =>
      radiusKm >= GradeThresholds.nearbyPagedMaxRadiusKm;

  /// [incoming] 중 [seenIds] 에 없는 것만 가까운 순으로 정렬해 돌려준다 (id 중복 제거, 거리 미상은 뒤).
  /// 호출 측은 결과를 기존 목록 **뒤에만** append 한다 — 기존 항목 순서가 요동치지 않는다.
  static List<StoreEntity> newItemsOnly(
    List<StoreEntity> incoming,
    Set<String> seenIds,
  ) {
    final fresh = <StoreEntity>[];
    final batchIds = <String>{};
    for (final s in incoming) {
      if (seenIds.contains(s.id) || !batchIds.add(s.id)) continue;
      fresh.add(s);
    }
    fresh.sort((a, b) {
      final da = a.distanceKm;
      final db = b.distanceKm;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return fresh;
  }
}
