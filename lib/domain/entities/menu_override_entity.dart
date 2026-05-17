import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';

part 'menu_override_entity.freezed.dart';

/// 브랜드 매장의 마스터 메뉴 오버라이드 1건.
///
/// Firestore `stores/{storeId}/menuOverrides/{masterMenuItemId}` 문서에 대응.
///
/// - priceOverride / excluded 는 **핵심 필드** → 변경 시 status=pending 회귀, admin 승인 게이트.
/// - soldOut / disabledOption* 는 **운영 필드** → 점주 즉시 반영, status 무관 (sub-phase 5 활성).
/// - customer 머지: status==approved 일 때만 priceOverride / excluded 적용.
@freezed
abstract class MenuOverrideEntity with _$MenuOverrideEntity {
  const factory MenuOverrideEntity({
    /// doc.id (= masterMenuItemId). collectionGroup query 에서도 사용.
    required String masterMenuItemId,
    required String storeId,
    /// store.brandId 와 동일. collectionGroup query 필터용.
    required String brandId,
    /// null = 마스터 가격 사용.
    int? priceOverride,
    /// 이 매장에서 해당 마스터 메뉴를 제외할지 여부.
    @Default(false) bool excluded,
    /// 품절 여부. sub-phase 5 에서 점주 즉시 토글. status 무관.
    @Default(false) bool soldOut,
    /// 점주가 비활성화한 옵션 그룹 ID 목록. sub-phase 5 활성.
    @Default(<String>[]) List<String> disabledOptionGroupIds,
    /// 점주가 비활성화한 옵션 항목 ID 목록. sub-phase 5 활성.
    @Default(<String>[]) List<String> disabledOptionItemIds,
    /// 핵심 필드(priceOverride / excluded) 의 승인 상태.
    @Default(EntityApprovalStatus.pending) EntityApprovalStatus status,
    String? submittedBy,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedReason,
    /// 최종 수정자 역할 추적 ('admin'|'brand'|'owner').
    String? updatedBy,
    DateTime? updatedAt,
  }) = _MenuOverrideEntity;
}
