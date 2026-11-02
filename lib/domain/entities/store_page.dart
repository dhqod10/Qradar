import 'package:qradar/domain/entities/store_entity.dart';

/// 주변매장 반경 조회 결과 (store_list_pagination).
///
/// [items] 는 중심에서 [loadedRadiusKm] 이내의 승인 매장 **전부**를 가까운 순으로 담는다.
/// 거리 커서가 아니라 반경이 페이지 경계다 (Firestore 는 거리 기준 커서를 지원하지 않는다).
class StorePage {
  const StorePage({
    required this.items,
    required this.loadedRadiusKm,
    required this.exhausted,
  });

  final List<StoreEntity> items;
  final double loadedRadiusKm;

  /// 최대 반경까지 읽었다 — 더 확장할 수 없다.
  final bool exhausted;
}
