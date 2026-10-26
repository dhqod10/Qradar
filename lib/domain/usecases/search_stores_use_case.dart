import 'package:qradar/core/utils/search_normalizer.dart';
import 'package:qradar/domain/entities/store_entity.dart';

/// 홈 검색 — 매장 검색 (순수 compute, I/O 없음).
///
/// 대상 필드: `name` + `address`. 이름 매칭 그룹이 주소 매칭 그룹보다 항상 위, 각 그룹은 입력 순서
/// (스냅샷이 거리 오름차순) 를 보존한다. 질의는 호출 측이 [SearchNormalizer.normalize] 한 값이어야 한다.
class SearchStoresUseCase {
  SearchStoresUseCase._();

  static List<StoreEntity> compute({
    required List<StoreEntity> stores,
    required String normalizedQuery,
  }) {
    if (normalizedQuery.isEmpty) return const [];
    final byName = <StoreEntity>[];
    final byAddress = <StoreEntity>[];
    for (final s in stores) {
      if (SearchNormalizer.matches(s.name, normalizedQuery)) {
        byName.add(s);
      } else if (SearchNormalizer.matches(s.address, normalizedQuery)) {
        byAddress.add(s);
      }
    }
    return [...byName, ...byAddress];
  }

  /// 주소로**만** 걸린 매장인가 (카드 보조 줄 `subtitle` 표기 판단용).
  static bool isAddressOnlyMatch(StoreEntity store, String normalizedQuery) =>
      !SearchNormalizer.matches(store.name, normalizedQuery) &&
      SearchNormalizer.matches(store.address, normalizedQuery);
}
