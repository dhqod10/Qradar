import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';

part 'menu_item_entity.freezed.dart';

/// 매장 또는 브랜드가 보유한 메뉴 1건.
///
/// - `scope == store`: 매장 개별 메뉴 (`stores/{storeId}/menuItems/{id}`)
/// - `scope == brand`: 브랜드 마스터 메뉴 (`brands/{brandId}/menuItems/{id}`)
///
/// `optionGroupRefs` 는 글로벌(`master`) 또는 매장(`store`) 두 출처를 모두
/// 가리킬 수 있다. 실제 옵션 데이터는 `OptionRepository.getOptionGroupsForMenuItem`
/// 으로 머지해서 가져온다.
///
/// 기존 매장 메뉴(scope==store): 신규 필드는 모두 default/null 이므로 영향 없음.
@freezed
abstract class MenuItemEntity with _$MenuItemEntity {
  const factory MenuItemEntity({
    required String id,
    required String storeId,
    required String name,
    @Default('') String imageUrl,
    String? description,
    required String mainCategoryCode,
    String? subCategoryId,
    required int basePrice,
    @Default(<OptionGroupRef>[]) List<OptionGroupRef> optionGroupRefs,
    @Default(false) bool soldOut,
    @Default(0) int displayOrder,
    DateTime? createdAt,
    // ── Phase 1b (brand_master) 신규 필드 ─────────────────────────────
    /// 메뉴 출처. 기존 매장 메뉴는 기본값 `store`.
    @Default(MenuItemScope.store) MenuItemScope scope,
    /// 브랜드 마스터 메뉴이면 해당 brandId. 개인 매장 메뉴는 null.
    String? brandId,
    /// 태그 목록 ('recommended' | 'new' | 'best').
    @Default(<String>[]) List<String> tags,
    /// 고객에게 노출 여부. 기본값 true.
    @Default(true) bool visible,
    /// 점주가 비활성화한 옵션 그룹 ID 목록 (sub-phase 5 활성).
    @Default(<String>[]) List<String> disabledOptionGroupIds,
    /// 점주가 비활성화한 옵션 항목 ID 목록 (sub-phase 5 활성).
    @Default(<String>[]) List<String> disabledOptionItemIds,
    /// 승인 상태. 개인 매장 메뉴는 null (승인 불필요).
    EntityApprovalStatus? status,
    String? submittedBy,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedReason,
    DateTime? updatedAt,
  }) = _MenuItemEntity;
}
