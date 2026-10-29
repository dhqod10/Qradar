import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';

/// "이 메뉴가 매장 메뉴 화면에 보이는가" — 단일 판정 (design §1 F5).
///
/// 매장 메뉴 화면(`filteredMenuItemsProvider`)과 홈 검색 결과(`menuSearchResultsProvider`)가
/// **같은 함수**를 써서 "검색에 걸렸는데 매장 화면에는 없다" 를 구조적으로 막는다.
/// 기준: 고객 노출(`visible`) + 활성 메인 카테고리 + **점주가 끄지 않은** 카테고리
/// ([excludedCategoryIds] = `store.excludedMainCategories`, store_category_optout). 순수 Dart.
///
/// 카테고리 제외(coarser)는 per-item override 제외(finer)와 독립 AND — 이 함수는 카테고리 쪽만 본다.
bool isMenuShownOnStoreScreen({
  required bool visible,
  required String mainCategoryCode,
  required Set<String> activeCategoryIds,
  Set<String> excludedCategoryIds = const <String>{},
}) {
  return visible &&
      activeCategoryIds.contains(mainCategoryCode) &&
      !excludedCategoryIds.contains(mainCategoryCode);
}

/// 브랜드 매장의 마스터 메뉴 1건에 그 매장의 override 를 **고객 기준으로** 적용한다 (spec §15.2).
///
/// 반환 `null` = 이 매장은 이 메뉴를 팔지 않는다 (`excluded`).
///
/// **비자명한 분기 — 이 함수가 유일한 구현이다** (매장 화면 목록 · 메뉴 상세 · 검색 2단계가 모두 이것만 쓴다):
/// - 핵심 필드 (`excluded` / `priceOverride`) : `override.status == approved` 일 때**만** 적용
/// - 운영 필드 (`soldOut` / `disabledOption*`) : status **무관** 즉시 적용
///
/// 마스터 자체의 `approved && visible` 필터는 이 함수의 책임이 아니다 (호출 측 목록 머지가 먼저 건다).
/// [override] 가 null 이면 마스터 그대로.
MenuItemEntity? applyOverrideForCustomer({
  required MenuItemEntity master,
  required MenuOverrideEntity? override,
}) {
  if (override == null) return master;
  final approved = override.status == EntityApprovalStatus.approved;
  if (approved && override.excluded) return null;
  return master.copyWith(
    basePrice: approved
        ? (override.priceOverride ?? master.basePrice)
        : master.basePrice,
    soldOut: override.soldOut,
    disabledOptionGroupIds: override.disabledOptionGroupIds,
    disabledOptionItemIds: override.disabledOptionItemIds,
  );
}
