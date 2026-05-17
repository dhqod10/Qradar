import 'package:qradar/domain/entities/main_category_entity.dart';

/// 메인 카테고리 Repository 인터페이스.
abstract class MainCategoryRepository {
  /// 전체 또는 active 만 stream.
  /// [activeOnly] == true 면 active=true 인 카테고리만. displayOrder asc.
  Stream<List<MainCategoryEntity>> watchAll({bool activeOnly = false});

  /// id 로 단건 조회.
  Future<MainCategoryEntity?> findById(String id);

  /// 등록 또는 수정 (set merge). admin only.
  Future<void> upsert(MainCategoryEntity entity);

  /// 삭제. admin only.
  /// 내부에서 사용 중 검사: menuItem 또는 subCategory 참조가 1개 이상이면
  /// [MainCategoryInUseException] throw.
  Future<void> delete(String id);

  /// menuItem / subCategory 합산 사용 수.
  Future<int> countUsage(String id);

  /// 영향 데이터 상세: (menuCount, distinctStoreCount).
  /// DeactivateConfirmDialog 에 표시할 정보.
  Future<({int menuCount, int storeCount})> countDetailedUsage(String id);

  /// 컬렉션이 비었을 때 기본 3개(coffee/nonCoffee/dessert) 시드 (idempotent).
  Future<void> seedDefaultsIfEmpty();
}
