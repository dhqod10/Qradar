import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/option_item_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';

part 'option_group_entity.freezed.dart';

/// 옵션 그룹 (예: 온도, 샷 추가).
///
/// - `scope = master`: 글로벌 시드 컬렉션 (read-only legacy).
/// - `scope = brand`: `brands/{brandId}/optionGroups/{id}`.
/// - `scope = store`: `stores/{storeId}/optionGroups/{id}`.
@freezed
abstract class OptionGroupEntity with _$OptionGroupEntity {
  const factory OptionGroupEntity({
    required String id,
    required OptionScope scope,
    /// brand scope 일 때 채움. store/master scope 에서는 null.
    String? brandId,
    /// store scope 일 때 채움. brand/master scope 에서는 null.
    String? storeId,
    required String name,
    required OptionSelectionType selectionType,
    @Default(false) bool required,
    @Default(<OptionItemEntity>[]) List<OptionItemEntity> items,
    @Default(0) int displayOrder,
    /// active=false 이면 메뉴 폼 및 고객 화면에서 숨겨짐.
    @Default(true) bool active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _OptionGroupEntity;
}

/// 메뉴 → 옵션 그룹 참조 페어.
///
/// `MenuItemEntity.optionGroupRefs` 가 글로벌(`master`) / 매장(`store`) 두 출처를
/// 모두 가리킬 수 있도록 출처와 ID 를 함께 들고 다닌다.
@freezed
abstract class OptionGroupRef with _$OptionGroupRef {
  const factory OptionGroupRef({
    required OptionScope scope,
    required String id,
  }) = _OptionGroupRef;
}
