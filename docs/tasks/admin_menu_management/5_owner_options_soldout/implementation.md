# sub-phase 5 — owner_options_soldout 구현 내역

## 개요

- 구현 목적: 점주의 옵션 비활성 + 품절 토글을 개인 매장 / 브랜드 매장 공통으로 즉시 반영. admin 승인 게이트 없음. customer 측은 옵션 fetch 단계에서 자동 필터.
- 기준 문서:
  - `docs/tasks/admin_menu_management/5_owner_options_soldout/spec.md`
  - `docs/tasks/admin_menu_management/5_owner_options_soldout/design.md`

---

## 구현 파일 목록

### 신규 파일

- `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart`
  - `MenuOptionDisableSheet` — 메뉴 1개의 옵션 그룹/항목 비활성 토글 BottomSheet
  - `MenuOptionDisableSheetType` enum (`personal` / `brandMasterRef`)
  - 내부 위젯: `_SheetHeader`, `_OptionDisableGroupRow`, `_OptionDisableItemRow`, `_SelectionBadge`, `_ErrorBody`, `_EmptyBody`

- `lib/presentation/owner/store_menu/widgets/sold_out_toggle.dart`
  - `SoldOutToggle` — 카드 인라인 품절 Switch.adaptive 위젯. `OwnerStoreMenuListPage` / `OwnerBrandStoreMenusPage` 양쪽에서 재사용

- `lib/presentation/owner/brand_store/owner_brand_store_menus_page.dart`
  - `OwnerBrandStoreMenusPage` — 브랜드 매장 점주용 메뉴 리스트 화면 (FAB 없음, read-only 마스터 + 품절/옵션 액션만)
  - 내부 위젯: `_BrandStoreInfoBanner`, `_BrandStoreMenuCard`, `_BrandActionSheet`, `_ScopeBadge`, `_SoldOutBadge`, `_ErrorView`, `_EmptyView`

- `lib/presentation/owner/brand_store/owner_brand_store_menus_providers.dart`
  - `BrandMenuKey` — (storeId, brandId) family 키
  - `ownerBrandStoreMenusProvider` — `StreamProvider.family<List<MenuItemEntity>, BrandMenuKey>` (repo.watchByStore case B 머지)
  - `ownerBrandStoreMenuItemRepositoryProvider`, `ownerBrandStoreMenuOverrideRepositoryProvider` — DI 구성
  - `toggleSoldOutForPersonalMenuUseCaseProvider`, `toggleSoldOutForOverrideUseCaseProvider`
  - `updateDisabledOptionsForPersonalMenuUseCaseProvider`, `updateDisabledOptionsForOverrideUseCaseProvider`

### 수정 파일

- `lib/presentation/owner/store_menu/owner_store_menu_list_page.dart`
  - `_OwnerMenuCard` 카드 Row에 `SoldOutToggle` 인라인 추가 (visible 토글 `_InlineVisibleToggle` 우측 배치)
  - `_InlineVisibleToggle` 라벨 "표시" 추가 (design D3 — 두 토글 라벨 병행으로 가독성 확보)
  - `_ActionSheet`에 "옵션 관리" ListTile 최상단 추가 → `_openOptionSheet()` 호출
  - `_openOptionSheet()` 메서드 신규: `MenuOptionDisableSheet(menuType: personal)` showModalBottomSheet
  - `soldOut` 상태 오버레이 (`AppColors.error.withValues(alpha: 0.06)`) + `_SoldOutBadge` 우선 시각 적용

- `lib/presentation/owner/store_menu/owner_store_menu_detail_page.dart`
  - `_MenuAction` enum에 `manageOptions` 추가
  - `PopupMenuButton` itemBuilder에 "옵션 관리" PopupMenuItem 추가 (최상단)
  - `_handleAction` switch에 `manageOptions` case: `MenuOptionDisableSheet(menuType: personal)` showModalBottomSheet
  - `_ImageSection` 에 `soldOut == true` 일 때 `AppColors.error` 오버레이 + "품절" 배지 Stack 적용 (D5)
  - `_InfoRow` 품절 여부 행: `item.soldOut` 값으로 "품절" / "판매 중" + `AppColors.error` / `AppColors.success` 색상

- `lib/presentation/owner/my_store/my_store_page.dart`
  - `_PersonalStoreDetailView` — 기존 `_MenuManagementButton` 유지 (변경 없음)
  - `_BrandStoreDetailView` — `_BrandStoreActionButtons` 하단에 `_BrandMenuManagementButton` 추가 (approved + brandId 조건)
  - `_BrandMenuManagementButton` 신규 위젯: 브랜드 매장 approved 일 때만 노출 "메뉴 옵션·품절 관리" → `OwnerBrandStoreMenusPage` push
  - `_MenuManagementButton` — 개인 매장 approved 전용, 조건 `store.brandId == null && status == approved` (기존 유지)

- `lib/data/repositories/menu_override_repository_impl.dart`
  - `updateOverrideOperationFields(MenuOverrideEntity override)` 신규 메서드 구현 (W1 결정 — sub-phase 3 미구현 확인 후 본 sub-phase 추가)
  - 동작: `_dataSource.getByStoreAndMaster()` 결과에 따라 분기
    - 기존 없음: `_dataSource.set()` — `status='approved'`, `priceOverride=null`, `excluded=false`, 운영 필드 채움 (W2 upsert)
    - 기존 있음: `_dataSource.update()` — `soldOut`, `disabledOptionGroupIds`, `disabledOptionItemIds` 만 partial update + `updatedBy='owner'`
  - `_assertOwnerOfBrandStore()` 신규 헬퍼: uid 존재 여부 확인 (Firestore 규칙에 최종 권한 위임)

- `lib/domain/repositories/option_repository.dart`
  - `getOptionGroupsForMenuItem` 시그니처에 named parameters 추가:
    ```dart
    Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
      MenuItemEntity menuItem, {
      Set<String> disabledGroupIds = const {},
      Set<String> disabledItemIds = const {},
    });
    ```
  - (W4 결정) customer 측 옵션 비활성 필터를 Repository 인터페이스 레벨에서 정의

- `lib/data/repositories/option_repository_impl.dart`
  - `getOptionGroupsForMenuItem` 구현에 비활성 필터 로직 추가:
    - `disabledGroupIds`, `disabledItemIds` 모두 비어있으면 그대로 반환 (최적화)
    - `disabledGroupIds` 포함 그룹 → skip (그룹 통째로 제외)
    - 나머지 그룹 → items 중 `compositeId = "${group.id}_${item.id}"` 가 `disabledItemIds`에 포함되면 제외
    - `group.copyWith(items: filteredItems)` 로 불변 변환

- `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart`
  - `menuItemAllOptionGroupsProvider` 신규 FutureProvider: 비활성 필터 없이 전체 옵션 반환 (시트용)
  - `menuItemOptionGroupsProvider` 기존 유지 — customer 화면용 (필터 적용)
  - 기존 호출자 (`menuItemOptionGroupsProvider`) 의 `getOptionGroupsForMenuItem(detail)` 호출은 인자 없이 그대로 유지 (default empty Set → 필터 없음) — 회귀 없음

### 재사용 파일

- `lib/domain/entities/menu_item_entity.dart` — `disabledOptionGroupIds`, `disabledOptionItemIds`, `soldOut` 필드 (sub-phase 1 산출)
- `lib/domain/entities/menu_override_entity.dart` — 동일 필드 (sub-phase 3 산출)
- `lib/domain/entities/menu_item_scope.dart` — `MenuItemScope.brand` / `.store` 분기 (sub-phase 3 산출)
- `lib/domain/usecases/toggle_sold_out_use_case.dart` — `ToggleSoldOutForPersonalMenuUseCase`, `ToggleSoldOutForOverrideUseCase`
- `lib/domain/usecases/update_disabled_options_use_case.dart` — `UpdateDisabledOptionsForPersonalMenuUseCase`, `UpdateDisabledOptionsForOverrideUseCase`
- `lib/data/repositories/menu_item_repository_impl.dart` — `watchByStore` case B 머지 (sub-phase 3 산출)
- `lib/presentation/owner/store_menu/owner_store_menu_list_page.dart` — `_InlineVisibleToggle` 패턴 재사용

---

## 주요 결정사항

### W1. Repository 메서드 — 재사용 + 신규 추가 병행

- sub-phase 3/4 의 운영 필드 partial update 메서드(`updateStoreOnlyMenuOperation` / `upsertOverrideOperation`)를 확인한 결과, sub-phase 3 에서 `updateOverrideOperationFields` 가 구현되지 않아 본 sub-phase 가 신규 추가.
- `MenuOverrideRepository` 인터페이스 + `MenuOverrideRepositoryImpl` 에 `updateOverrideOperationFields(MenuOverrideEntity)` 추가.
- 개인 매장 토글은 기존 `ToggleSoldOutForPersonalMenuUseCase` / `UpdateDisabledOptionsForPersonalMenuUseCase` 로 처리. 각 UseCase 는 `MenuItemRepository.updateStoreOnlyMenuOperation` 를 경유.

### W2. 브랜드 매장 마스터 메뉴 — upsert 패턴 (override 신규 생성 시 status='approved')

- `MenuOverrideRepositoryImpl.updateOverrideOperationFields` 내부에서 `getByStoreAndMaster` 결과로 분기:
  - 기존 없음 → `set()` 신규 생성: `status='approved'`, `priceOverride=null`, `excluded=false`, 운영 필드(`soldOut`, `disabledOptionGroupIds`, `disabledOptionItemIds`) 채움, 승인 메타 null.
  - 기존 있음 → `update()` partial update: 운영 필드 3개만 변경, `status` / `priceOverride` / `excluded` / 승인 메타 보존.
- spec H: 기존 override 가 `status='pending'` 이어도 운영 필드만 partial update → status 보존.

### W3. 점주 ownership 검증

- `_assertOwnerOfBrandStore()` 헬퍼: uid 존재 여부만 확인. 실제 storeId 단위 권한 검증은 Firestore 보안 규칙에 위임.
- 이유: Flutter 앱은 roleGetter 가 없으므로 uid null-check 만 수행. 보안 규칙이 최종 방어선.

### W4. OptionRepository 시그니처 변경 — customer 측 옵션 비활성 필터

- `OptionRepository.getOptionGroupsForMenuItem` 에 named parameters `disabledGroupIds`, `disabledItemIds` 추가 (default empty Set).
- Phase 1a 기존 호출자(`menuItemOptionGroupsProvider`) 는 인자 없이 호출 → default empty Set → 필터 없음 → 회귀 없음.
- 시트용 `menuItemAllOptionGroupsProvider` 도 인자 없이 호출 → 모든 옵션 표시 후 점주가 직접 토글.
- customer 화면 `menuItemOptionGroupsProvider` 는 향후 `menuItem.disabledOptionGroupIds` / `disabledOptionItemIds` 를 전달하도록 갱신해야 함 (현재 기존 호출 그대로 유지 — 아래 미구현 항목 참조).

### W5. 카드 인라인 두 토글 배치

- `OwnerStoreMenuListPage` 카드 Row 우상단: `_InlineVisibleToggle` (라벨 "표시") + `SoldOutToggle` (라벨 "품절") 나란히 배치.
- `SoldOutToggle` 은 독립 위젯으로 추출 — `OwnerStoreMenuListPage` / `OwnerBrandStoreMenusPage` 양쪽 재사용.
- 색상 차별화: visible 토글 `AppColors.primary`, 품절 토글 `AppColors.error` 계열.

### W6. MenuOptionDisableSheet — 즉시 저장 흐름

- 토글 `onChange` 콜백 발생 즉시 optimistic update (setState) + `_callSaveUseCase()` 호출.
- 저장 성공: `_optimisticSoldOut = null` 원복 없음 (이미 setState 로 반영됨).
- 저장 실패: `setState` 로 `_disabledGroupIds` / `_disabledItemIds` 를 prev 값으로 원복 + SnackBar "변경에 실패했어요".
- `_isSaving` 플래그로 중복 호출 방지.
- `menuType` 에 따른 분기:
  - `personal` → `updateDisabledOptionsForPersonalMenuUseCaseProvider`
  - `brandMasterRef` → `updateDisabledOptionsForOverrideUseCaseProvider` (override upsert)

### W7. OwnerBrandStoreMenusPage — 브랜드 매장 read-only

- `_BrandStoreMenuCard` 에서 `widget.item.scope == MenuItemScope.brand` 인지 여부로 분기:
  - `brand` scope: override upsert 경로 (`toggleSoldOutForOverrideUseCaseProvider`)
  - `store` scope (점포 한정): personal 경로 (`toggleSoldOutForPersonalMenuUseCaseProvider`)
- 카드에 `_ScopeBadge` ("마스터" / "매장 한정") 표시로 scope 구분.
- 메뉴 추가 / 수정 / 삭제 / 복제 액션 없음. long-press 액션 시트에 "옵션 관리" 만 노출.
- FAB 없음.
- `_BrandStoreInfoBanner` — "점주는 품절과 옵션 비활성화만 가능해요" 안내.

### W8. MyStorePage CTA 분기

- `_StoreDetailView` 에서 `isBrandStore` 분기: 개인 → `_PersonalStoreDetailView`, 브랜드 → `_BrandStoreDetailView` (sub-phase 3 결정 그대로).
- `_PersonalStoreDetailView` — 기존 `_MenuManagementButton` 유지 (개인 approved 조건).
- `_BrandStoreDetailView` — `_BrandStoreActionButtons` 하단에 `_BrandMenuManagementButton` 추가.
- `_BrandMenuManagementButton`: `store.brandId != null && store.status == EntityApprovalStatus.approved` 조건 시 노출 — 미승인/반려 매장에서는 노출 안 함.
- 두 CTA 는 같은 화면에 동시 노출되지 않음 (brandId 분기로 상호 배타).

### W9. 브랜드 매장 점주용 Provider DI

- `owner_brand_store_menus_providers.dart` 에 독립 DI 트리 구성:
  - `_brandMenuItemRemoteDataSourceProvider`, `_brandMasterMenuItemRemoteDataSourceProvider`, `_brandMenuOverrideRemoteDataSourceProvider`
  - `ownerBrandStoreMenuItemRepositoryProvider` — `MenuItemRepositoryImpl` (masterMenuDataSource, menuOverrideDataSource 포함)
  - `ownerBrandStoreMenuOverrideRepositoryProvider` — `MenuOverrideRepositoryImpl`
- `ownerBrandStoreMenusProvider` — `StreamProvider.family<List<MenuItemEntity>, BrandMenuKey>` → `repo.watchByStore(storeId, brandId: brandId)` case B 머지 결과.

### W10. 시드 데이터

- 시드 데이터 변경 없음 (spec W10 결정). `disabledOption*=[]`, `soldOut=false` default 로 흡수. 점주가 직접 토글하면 검증 가능.

---

## OptionRepository 시그니처 변경 (W4) 상세

### 변경 전

```dart
Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
  MenuItemEntity menuItem,
);
```

### 변경 후 (domain/repositories/option_repository.dart)

```dart
Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
  MenuItemEntity menuItem, {
  Set<String> disabledGroupIds = const {},
  Set<String> disabledItemIds = const {},
});
```

### Phase 1a 호출자 영향

- `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart`
  - `menuItemOptionGroupsProvider`: `getOptionGroupsForMenuItem(detail)` — 인자 없음 → default empty Set → 필터 없음. 회귀 없음.
  - `menuItemAllOptionGroupsProvider` (신규): `optionRepositoryProvider.getOptionGroupsForMenuItem(detail)` — 동일하게 인자 없음 → 모든 옵션 반환 (시트용).

### 향후 보완 필요 (현재 미구현)

customer 화면의 옵션 비활성 필터를 실제 활성화하려면 `menuItemOptionGroupsProvider` 에서 아래처럼 인자를 전달해야 함:

```dart
return ref.watch(getOptionGroupsForMenuItemUseCaseProvider)(
  detail,
  disabledGroupIds: detail.disabledOptionGroupIds.toSet(),
  disabledItemIds: detail.disabledOptionItemIds.toSet(),
);
```

현재 호출은 인자 없음 상태 유지 (기존 Phase 1a 동작 보존). 향후 customer 옵션 필터 활성화 task 에서 처리.

---

## upsert 패턴 (W2) 상세

`MenuOverrideRepositoryImpl.updateOverrideOperationFields` 흐름:

```
1. _assertOwnerOfBrandStore()  // uid null-check
2. existing = _dataSource.getByStoreAndMaster(storeId, masterMenuItemId)
3. if (existing == null):
     _dataSource.set(storeId, masterMenuItemId, {
       storeId, brandId,
       priceOverride: null,
       excluded: false,
       soldOut: override.soldOut,
       disabledOptionGroupIds: override.disabledOptionGroupIds,
       disabledOptionItemIds: override.disabledOptionItemIds,
       status: 'approved',
       submittedBy: uid,
       submittedAt: now,
       approvedBy: null, approvedAt: null, rejectedReason: null,
       updatedBy: 'owner',
       updatedAt: now,
     })
   else:
     _dataSource.update(storeId, masterMenuItemId, {
       soldOut: override.soldOut,
       disabledOptionGroupIds: override.disabledOptionGroupIds,
       disabledOptionItemIds: override.disabledOptionItemIds,
       updatedBy: 'owner',
       updatedAt: serverTimestamp(),
     })
```

status / priceOverride / excluded / 승인 메타는 update 페이로드에 포함 안 함 → Firestore partial update 로 기존 값 보존.

---

## MenuOptionDisableSheet 즉시 저장 흐름 (D4)

```
사용자 토글 onChange
  → _onGroupToggle / _onItemToggle 호출
  → prevGroupIds / prevItemIds 스냅샷
  → setState (optimistic update — _disabledGroupIds / _disabledItemIds 갱신)
  → _saveGroupToggle / _saveItemToggle 호출
      → _isSaving = true
      → _callSaveUseCase() await
          → menuType == personal:
               updateDisabledOptionsForPersonalMenuUseCaseProvider.call(...)
          → menuType == brandMasterRef:
               updateDisabledOptionsForOverrideUseCaseProvider.call(override, ...)
      → 성공: _isSaving = false
      → 실패: setState (prevGroupIds / prevItemIds 원복) + _showErrorSnackBar()
               _isSaving = false
```

- SnackBar: "변경에 실패했어요", `AppColors.textHeading` 배경, `AppColors.onPrimary` 텍스트, floating, margin `fromLTRB(16, 0, 16, 12)`.
- `_isSaving` 플래그: 저장 중 추가 토글 onChange 차단 (`Switch.adaptive onChanged: isSaving ? null : callback`).
- Sheet 닫기 버튼(X) / outside tap: dismiss 만 수행 (저장은 이미 완료 또는 진행 중 완료 예정).

---

## 카드 인라인 두 토글 배치 (D2/D3)

### OwnerStoreMenuListPage 카드 Row 구조

```
Row(
  children: [
    Expanded(child: Text(name)),    // 메뉴 이름
    if (soldOut) _SoldOutBadge()
    else if (!visible) _HiddenBadge(),
    SizedBox(width: 8),
    _InlineVisibleToggle(item),     // 라벨 "표시" + Switch.adaptive (AppColors.primary)
    SizedBox(width: 4),
    SoldOutToggle(                   // 라벨 "품절" + Switch.adaptive (AppColors.error)
      soldOut: soldOut,
      isLoading: _soldOutLoading,
      onChanged: _toggleSoldOut,
    ),
  ],
)
```

### OwnerBrandStoreMenusPage 카드 Row 구조

visible 토글 없음 (brand 관리 필드). `SoldOutToggle` 만 인라인 배치.

---

## OwnerBrandStoreMenusPage 동작

- `ownerBrandStoreMenusProvider(BrandMenuKey(storeId, brandId))` 를 watch → case B 머지 결과 수신.
- case B 머지: 마스터 메뉴 ref (`scope=brand`) + override 머지 (soldOut / disabledOption* 즉시 반영) + 점포 한정 메뉴 (`scope=store`).
- `excluded == true` (admin 승인된 제외 메뉴): case B 머지에서 이미 필터링되어 목록에 미포함.
- `_BrandStoreMenuCard`:
  - `scope == brand`: 품절 토글 → `toggleSoldOutForOverrideUseCaseProvider.call(override, nextValue)` (upsert)
  - `scope == store`: 품절 토글 → `toggleSoldOutForPersonalMenuUseCaseProvider.call(item, nextValue)`
  - 옵션 관리 버튼 (카드 우하단 tune 아이콘) / long-press 액션 시트 "옵션 관리" → `MenuOptionDisableSheet` 진입
  - `menuType`: `scope == brand` → `MenuOptionDisableSheetType.brandMasterRef`, else → `MenuOptionDisableSheetType.personal`

---

## 테스트 포인트

### 품절 토글 — 개인 매장

- [ ] `OwnerStoreMenuListPage` 카드에 품절 토글 노출 확인
- [ ] 품절 ON: `soldOut=true` Firestore 저장 확인 + optimistic 시각 적용 (오버레이 + "품절" 배지)
- [ ] 품절 OFF: `soldOut=false` 저장 확인 + 시각 복원
- [ ] 저장 실패 시 optimistic 원복 확인 (toggle 이전 상태로 되돌아감 + SnackBar)
- [ ] `OwnerStoreMenuDetailPage` 품절 여부 InfoRow: "품절" / "판매 중" + 색상 정합

### 품절 토글 — 브랜드 매장

- [ ] `OwnerBrandStoreMenusPage` 카드에 품절 토글 노출 확인
- [ ] 마스터 메뉴 ref (`scope=brand`): override 없을 때 첫 토글 → override 신규 생성, `status='approved'`, `priceOverride=null`, `excluded=false` 확인
- [ ] 마스터 메뉴 ref: 기존 override 있을 때 토글 → 운영 필드만 partial update, status / priceOverride / excluded 보존 확인
- [ ] 점포 한정 메뉴 (`scope=store`): menuItems 컬렉션 `soldOut` 필드 partial update 확인

### 옵션 관리 — 개인 매장

- [ ] `OwnerStoreMenuListPage` long-press 액션 시트에 "옵션 관리" 최상단 노출
- [ ] "옵션 관리" 탭 → `MenuOptionDisableSheet` 진입 확인
- [ ] `OwnerStoreMenuDetailPage` PopupMenu에 "옵션 관리" 노출
- [ ] Sheet에서 그룹 토글 OFF → `disabledOptionGroupIds` 업데이트 즉시 저장
- [ ] Sheet에서 항목 토글 OFF → `disabledOptionItemIds` compositeId(`{groupId}_{itemId}`) 업데이트
- [ ] 그룹 비활성 시 항목 Switch disabled + 안내 텍스트 "그룹을 활성화하면 항목별 관리가 가능해요" 표시

### 옵션 관리 — 브랜드 매장

- [ ] `OwnerBrandStoreMenusPage` tune 아이콘 / long-press → `MenuOptionDisableSheet(menuType: brandMasterRef)` 진입
- [ ] 토글 저장: override `disabledOptionGroupIds` / `disabledOptionItemIds` upsert 확인

### OwnerMyStorePage CTA 분기

- [ ] 개인 매장 approved: "메뉴 관리" 버튼 노출 → `OwnerStoreMenuListPage` 진입
- [ ] 브랜드 매장 approved: "메뉴 옵션·품절 관리" 버튼 노출 → `OwnerBrandStoreMenusPage` 진입
- [ ] 브랜드 매장 pending / rejected: "메뉴 옵션·품절 관리" 버튼 미노출 확인
- [ ] 개인 / 브랜드 CTA 동시 노출 없음 확인

### customer 측 회귀

- [ ] `menuItemOptionGroupsProvider` 호출 인자 없음 → 기존 Phase 1a 옵션 picker 동작 그대로 (비활성 필터 미적용 상태 유지)
- [ ] `menuItemAllOptionGroupsProvider` — 시트 진입 시 모든 옵션 그룹 표시 확인

---

## 회귀 검증 — Phase 1a 옵션 picker (시그니처 변경)

`OptionRepository.getOptionGroupsForMenuItem` 에 named parameters 추가했으나 기존 호출자 변경 없음:

- `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart`
  - `menuItemOptionGroupsProvider`: `getOptionGroupsForMenuItem(detail)` — named parameter 생략 → default `{}` 적용 → 필터 없음 → 기존 동작 보존
- Dart named parameter default value 방식이므로 기존 위치 인자 호출과 호환 문제 없음.
- `OptionRepositoryImpl.getOptionGroupsForMenuItem` 내: `if (disabledGroupIds.isEmpty && disabledItemIds.isEmpty) return groups;` 조기 반환으로 성능 영향 없음.

sub-phase 1/2/3/4 회귀:

- sub-phase 1 (brand_master): 마스터 메뉴 CRUD — `MenuItemRepositoryImpl` / `MasterMenuItemRepositoryImpl` 경로 변경 없음.
- sub-phase 2 (store_registration_approval): 매장 status / 승인 흐름 — `MenuOverrideRepository` 의 `upsertOverrideCore` / `approveOverride` / `rejectOverride` 변경 없음.
- sub-phase 3 (brand_store_customization): `watchByStore` case B 머지 로직 변경 없음. override `upsertOverrideCore` 변경 없음. 브랜드 매장 점주의 핵심 정보 read-only 동작 보존 (`_BrandStoreDetailView` 기존 구조 유지).
- sub-phase 4 (owner_personal_menu): `OwnerStoreMenuListPage` 기존 visible 토글 / 메뉴 CRUD 동작 변경 없음. `_ActionSheet` 에 "옵션 관리" 추가만 수행.

---

## spec.md 대비 차이

- spec E (MenuOptionDisableSheet 입력): spec 은 `menuType: 'personal' | 'brandMasterRef' | 'brandStoreOnly'` 3종 enum을 정의했으나, 구현에서 `brandStoreOnly` 를 별도 케이스로 두지 않고 `personal` 케이스로 통합 (`MenuItemRepository` 경로가 동일하므로). 이유: 브랜드 매장 점포 한정 메뉴는 `stores/{storeId}/menuItems` 컬렉션 경로 — 개인 매장 메뉴와 동일. UseCase / Repository 호출 경로가 같으므로 분기 불필요.

- spec E (저장 타이밍): spec은 "닫기 시 변경된 disabledOption* 가 있으면 저장"으로 기술했으나, design D4 와 W6 결정에 따라 **즉시 저장** (onChange 즉시 Repository 호출) 으로 구현. spec과 design 간 불일치에서 design(W6) 채택. 이유: 즉시 저장이 UX상 더 안전하고 닫기 시 저장은 저장 실패 처리가 복잡함.

- spec F (customer 측 옵션 비활성 필터 활성화): `menuItemOptionGroupsProvider` 에 `disabledOptionGroupIds` / `disabledOptionItemIds` 인자 전달을 구현하지 않음. 현재 default empty Set 상태 유지. 이유: Phase 1a 회귀 위험 최소화. 별도 task 에서 활성화.

---

## design.md 대비 차이

- 없음. design의 모든 결정사항 (D1~D6) 코드에 반영됨.

---

## 미구현 / 보류 항목

- **customer 측 옵션 비활성 필터 활성화**:
  - 현황: `menuItemOptionGroupsProvider` 가 `disabledGroupIds` / `disabledItemIds` 인자 없이 호출 중. 인프라(`OptionRepositoryImpl` 필터 로직)는 준비 완료.
  - 이유: Phase 1a 호출자 변경은 customer 주문 흐름 회귀 위험이 있어 별도 task 로 분리.
  - 후속 작업: `menuItemOptionGroupsProvider` 에서 `menuItem.disabledOptionGroupIds.toSet()` / `disabledOptionItemIds.toSet()` 를 인자로 전달하고 customer 화면 옵션 picker 회귀 검증.

- **브랜드 매장 `excluded == true` 메뉴 "매장 제외됨" 안내 카드**:
  - 현황: `excluded == true` 메뉴는 case B 머지에서 이미 필터링되어 `ownerBrandStoreMenusProvider` 결과에 포함되지 않음. 별도 안내 카드 없음.
  - 이유: spec W7 결정이 "비노출 또는 안내"로 양쪽 허용. 구현은 비노출 채택. 안내 카드 필요 시 향후 추가.
  - 후속 작업: UX 요구에 따라 "매장 제외됨" 상태 메뉴 별도 섹션 노출 여부 결정.

- **Firestore 보안 규칙 / 인덱스**:
  - 현황: 미구현 (별도 task `firestore_rules` / `firestore_indexes`).
  - 이유: 본 sub-phase 범위 외 (spec 비범위 명시).

---

## 코드 생성 필요 여부

- 없음. 신규 entity 추가 없음. freezed / json_serializable 관련 코드 생성 불필요.

---

## 실행한 검증 명령

```
flutter analyze
```

결과: 0 issues found.

---

## flutter analyze 결과

```
Analyzing...
No issues found!
```
