import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';

/// 옵션 그룹 CRUD Repository 인터페이스.
///
/// - brand scope: `brands/{brandId}/optionGroups/{id}`
/// - store scope: `stores/{storeId}/optionGroups/{id}`
/// - master scope: read-only 호환 (신규 write 불가)
abstract class OptionGroupRepository {
  // ── Stream ──────────────────────────────────────────────────────────────

  /// brand scope 옵션 그룹 stream.
  Stream<List<OptionGroupEntity>> watchByBrand({
    required String brandId,
    bool activeOnly = false,
  });

  /// store scope 옵션 그룹 stream.
  Stream<List<OptionGroupEntity>> watchByStore({
    required String storeId,
    bool activeOnly = false,
  });

  // ── CRUD ────────────────────────────────────────────────────────────────

  /// 옵션 그룹 생성/수정 (upsert).
  ///
  /// [entity.id] 가 비어있으면 신규 생성, 있으면 merge update.
  /// master scope 입력 시 [ArgumentError] throw.
  Future<void> upsert(OptionGroupEntity entity);

  /// active 토글.
  Future<void> toggleActive({
    required OptionScope scope,
    required String id,
    required bool active,
    String? brandId,
    String? storeId,
  });

  /// 옵션 그룹 hard delete.
  ///
  /// 사용 중 (usageCount >= 1) 이면 [OptionGroupInUseException] throw.
  Future<void> delete({
    required OptionScope scope,
    required String id,
    String? brandId,
    String? storeId,
  });

  // ── 검증 ────────────────────────────────────────────────────────────────

  /// 같은 scope/context 내 동일 이름(normalized) 존재 여부.
  ///
  /// [excludeId]: 수정 모드에서 자기 자신 제외.
  Future<bool> findDuplicateName({
    required String name,
    required OptionScope scope,
    String? brandId,
    String? storeId,
    String? excludeId,
  });

  /// 특정 옵션 그룹을 참조하는 menuItem 수.
  ///
  /// Firestore 배열 평면 필드 fallback 적용:
  /// `menuItem.optionGroupRefIds` (`List&lt;String&gt;`) 에 `arrayContains` 쿼리.
  Future<int> countUsage({
    required String id,
  });
}
