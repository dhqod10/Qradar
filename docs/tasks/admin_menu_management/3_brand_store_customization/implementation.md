# 3_brand_store_customization 구현 내역

## 개요

- 구현 목적: 브랜드 본사(brand role)가 소속 매장의 메뉴를 커스터마이징(가격 오버라이드 / 제외 / 점포 한정 메뉴)할 수 있게 하고, admin 이 해당 변경사항을 승인·반려하는 워크플로우를 구현. 점주(owner)는 브랜드 매장일 때 핵심 정보 수정 권한이 없고 운영 정보만 즉시 변경 가능(결정 J).
- 기준 문서:
  - `docs/tasks/admin_menu_management/3_brand_store_customization/spec.md`
  - `docs/tasks/admin_menu_management/3_brand_store_customization/design/brand_module.md`
  - `docs/tasks/admin_menu_management/3_brand_store_customization/design/admin_module.md`
  - `docs/tasks/admin_menu_management/3_brand_store_customization/design/common_components.md`
- 구현 호출 순서: 호출 1(domain/data) → 호출 2(brand 화면 1부) → 호출 2-A(brand 화면 2부) → 호출 2-B(admin 화면) → 호출 3(owner 분기 + 시드 + implementation.md)

---

## 구현 파일 목록

### 신규 파일 (sub-phase 3 전체)

#### Domain

| 파일 | 내용 |
|---|---|
| `lib/domain/entities/menu_override_entity.dart` | 가격 오버라이드/제외 entity. `stores/{storeId}/menuOverrides/{masterMenuItemId}` 대응 |
| `lib/domain/entities/menu_override_entity.freezed.dart` | freezed 생성 파일 |
| `lib/domain/repositories/menu_override_repository.dart` | MenuOverrideRepository 인터페이스 |
| `lib/domain/usecases/upsert_menu_override_core_use_case.dart` | 핵심 필드(priceOverride/excluded) 변경 → status=pending |
| `lib/domain/usecases/delete_menu_override_use_case.dart` | override 삭제 |
| `lib/domain/usecases/watch_menu_overrides_by_store_use_case.dart` | 매장별 override 목록 스트림 |
| `lib/domain/usecases/watch_pending_menu_overrides_use_case.dart` | admin 승인 큐 override 스트림 |
| `lib/domain/usecases/approve_menu_override_use_case.dart` | admin 승인 |
| `lib/domain/usecases/reject_menu_override_use_case.dart` | admin 반려 |
| `lib/domain/usecases/create_store_only_menu_use_case.dart` | 점포 한정 메뉴 신규 생성 → status=pending |
| `lib/domain/usecases/update_store_only_menu_core_use_case.dart` | 점포 한정 메뉴 핵심 필드 수정 → status=pending |
| `lib/domain/usecases/update_store_only_menu_operation_use_case.dart` | 점포 한정 메뉴 운영 필드 수정 → 즉시 반영 |
| `lib/domain/usecases/delete_store_only_menu_use_case.dart` | 점포 한정 메뉴 삭제 |
| `lib/domain/usecases/watch_pending_store_only_menus_use_case.dart` | admin 승인 큐 점포 한정 메뉴 스트림 |
| `lib/domain/usecases/approve_store_only_menu_use_case.dart` | admin 점포 한정 메뉴 승인 |
| `lib/domain/usecases/reject_store_only_menu_use_case.dart` | admin 점포 한정 메뉴 반려 |
| `lib/domain/usecases/submit_store_by_brand_use_case.dart` | brand 가 매장 등록 신청. 미선택 마스터 메뉴 excluded batch seed 포함 |
| `lib/domain/usecases/watch_stores_by_brand_use_case.dart` | brand 소속 매장 목록 스트림 |
| `lib/domain/usecases/count_stores_using_price_override_use_case.dart` | 특정 마스터 메뉴에 priceOverride 설정된 매장 수 조회 (U7) |

#### Data

| 파일 | 내용 |
|---|---|
| `lib/data/datasources/remote/menu_override_remote_data_source.dart` | Firestore `stores/{storeId}/menuOverrides` CRUD. collectionGroup query |
| `lib/data/repositories/menu_override_repository_impl.dart` | MenuOverrideRepository 구현. `_assertBrandOwnership` 패턴 |
| `lib/data/repositories/menu_item_repository_impl.dart` | case A/B 분기 + Rx.combineLatest3 + `_mergeForBrandStore` (sub-phase 3 활성화) |
| `lib/data/repositories/master_menu_item_repository_impl.dart` | `cascadeDeleteOverrides` 실제 구현. `_assertOwnership` 패턴 |
| `lib/data/datasources/remote/master_menu_item_remote_data_source.dart` | `cascadeDeleteOverrides` 메서드 추가 |

#### Presentation — Brand 모듈

| 파일 | 내용 |
|---|---|
| `lib/presentation/brand/stores/brand_stores_page.dart` | brand 소속 매장 목록. FAB → BrandStoreFormPage |
| `lib/presentation/brand/stores/brand_store_form_page.dart` | 매장 등록/수정 폼. 마스터 메뉴 multi-select FilterChip |
| `lib/presentation/brand/customization/brand_store_customization_page.dart` | IndexedStack 2탭(가격 오버라이드 / 점포 한정 메뉴) |
| `lib/presentation/brand/customization/price_override/brand_price_override_list_page.dart` | 마스터 메뉴별 override 카드 목록 |
| `lib/presentation/brand/customization/price_override/brand_price_override_form_page.dart` | 가격 오버라이드 / 제외 설정 폼 |
| `lib/presentation/brand/customization/price_override/widgets/master_menu_override_card.dart` | `MasterMenuOverrideCard` — 마스터 메뉴 + override 상태 표시 |
| `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_list_page.dart` | 점포 한정 메뉴 목록 + FAB |
| `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart` | 점포 한정 메뉴 등록/수정 폼 |
| `lib/presentation/brand/customization/widgets/excluded_toggle.dart` | `ExcludedToggle` — excluded 여부 토글 UI |
| `lib/presentation/brand/customization/widgets/price_override_input.dart` | `PriceOverrideInput` — 가격 오버라이드 입력 필드 |
| `lib/presentation/brand/approval_tracking/brand_approval_tracking_page.dart` | 제출한 매장·override·점포 한정 메뉴 승인 현황 추적 |
| `lib/presentation/brand/more/brand_more_page.dart` | brand MorePage — BrandApprovalTrackingPage 진입점 |
| `lib/presentation/brand/providers/brand_store_management_providers.dart` | brand 매장 관리 Provider 모음 |
| `lib/presentation/brand/providers/brand_info_providers.dart` | `brandByIdProvider(brandId)` 추가 (호출 3) |

#### Presentation — Admin 모듈

| 파일 | 내용 |
|---|---|
| `lib/presentation/admin/approval/admin_approval_queue_page.dart` | AppBar 타이틀 `'승인'`, 4탭 구조(매장/브랜드/가격오버라이드/점포한정) |
| `lib/presentation/admin/approval/admin_pending_menu_overrides_page.dart` | 가격 오버라이드 승인 큐 목록 |
| `lib/presentation/admin/approval/admin_menu_override_approval_detail_page.dart` | 가격 오버라이드 단건 승인·반려 폼 |
| `lib/presentation/admin/approval/admin_pending_brand_store_items_page.dart` | 점포 한정 메뉴 승인 큐 목록 |
| `lib/presentation/admin/approval/admin_brand_store_item_approval_detail_page.dart` | 점포 한정 메뉴 단건 승인·반려 폼 |
| `lib/presentation/admin/brand_store_management/admin_brand_store_management_page.dart` | admin 특정 브랜드 매장의 override/점포 한정 메뉴 목록 |
| `lib/presentation/admin/providers/menu_override_providers.dart` | admin override 관련 Provider 모음 |
| `lib/presentation/admin/providers/admin_brand_customization_providers.dart` | admin 브랜드 커스터마이징 Provider 모음 |
| `lib/presentation/admin/widgets/store_scope_badge.dart` | `StoreScopeBadge.personal()` / `StoreScopeBadge.brand(brandName)` |

#### Presentation — Owner 모듈 (호출 3)

| 파일 | 내용 |
|---|---|
| `lib/presentation/owner/my_store/my_store_page.dart` | `store.brandId` 분기 추가. 브랜드 매장 전용 뷰 분리 |

#### 공통 위젯

`StoreScopeBadge` 는 admin/widgets 에 위치하며 brand, owner 모듈에서 import 해 사용한다.

#### 시드 (호출 3)

| 파일 | 내용 |
|---|---|
| `lib/dev/seed/phase1_seed_data.dart` | brand doc + brand master menu 2개 + brand store 1개 추가 |
| `lib/dev/seed/phase1_seed.dart` | brand/brand master menu/brand store 시드 실행 로직 추가. `SeedResult` 필드 확장 |
| `lib/dev/seed/dev_seed_trigger.dart` | 다이얼로그 안내 문구 갱신 |

### 수정 파일 (기존 파일 변경)

| 파일 | 변경 내용 |
|---|---|
| `lib/domain/repositories/menu_item_repository.dart` | `watchByStore` 시그니처에 `brandId` 파라미터 추가 |
| `lib/presentation/admin/approval/admin_pending_stores_page.dart` | `StoreScopeBadge.personal()` 표시 추가 |
| `lib/presentation/admin/approval/admin_store_approval_detail_page.dart` | 브랜드 매장 CTA 분기 (재제출 버튼 비노출) |

---

## 주요 결정사항 (U1~U10)

### U1: MenuOverrideEntity 위치 및 doc.id 전략

- `domain/entities/menu_override_entity.dart` (freezed)
- `doc.id = masterMenuItemId` — 매장당 마스터 메뉴 1개에 override 1개 보장
- `storeId` / `brandId` 필드를 entity 에 포함해 collectionGroup query 필터 지원

### U2: 매장 등록 시 미선택 마스터 메뉴 excluded batch seed

- `SubmitStoreByBrandUseCase` 에 `enabledMasterMenuItemIds` 파라미터 전달
- UseCase 내부에서 `MenuOverrideRepository.seedExclusionsForStore` 호출
- 배치 단위로 Firestore write (500 doc 제한 내 처리)

### U3: case B 머지 (`MenuItemRepositoryImpl.watchByStore`)

```
watchByStore(storeId, {String? brandId})
  brandId == null → case A: stores/{storeId}/menuItems 단순 stream
  brandId != null → case B: Rx.combineLatest3
      stream1: brands/{brandId}/menuItems (master)
      stream2: stores/{storeId}/menuOverrides (override)
      stream3: stores/{storeId}/menuItems (scope=store, 점포 한정)
    → _mergeForBrandStore(master, overrides, storeOnly)
```

`_mergeForBrandStore` 동작:
1. master 메뉴 중 `excluded==true && override.status==approved` 인 항목 제거
2. `priceOverride != null && override.status==approved` 인 항목 basePrice 교체
3. storeOnly 메뉴(scope=store, status==approved) append

### U4: status 전이 규칙

| 이벤트 | status 결과 |
|---|---|
| brand 핵심 필드 변경 (priceOverride/excluded) | pending |
| brand 운영 필드 변경 (soldOut 등, sub-phase 5) | 변경 없음 |
| admin 승인 | approved |
| admin 반려 | rejected |
| 재제출 (핵심 필드 재변경) | pending |

### U5: 점포 한정 메뉴 scope 필드

- `stores/{storeId}/menuItems/{id}` 에 `scope: 'store'` 필드 기록
- `brandId` 필드로 collectionGroup 필터 지원
- 신규 생성 시 status=pending 강제 (admin 승인 게이트)
- 운영 필드(soldOut, displayOrder) 만 변경 시 즉시 반영 (`UpdateStoreOnlyMenuOperationUseCase`)

### U6: 권한 매트릭스 코드 적용

- `MenuOverrideRepositoryImpl._assertBrandOwnership(brandId)` — brand 본인 매장만 override 변경 가능
- `MasterMenuItemRepositoryImpl._assertOwnership(brandId)` — brand 본인 마스터 메뉴만 수정 가능
- admin 전용 메서드: `approveOverride`, `rejectOverride`, `approveStoreOnlyMenu`, `rejectStoreOnlyMenu`
- StoreRepository: `_assertAdmin` 로 admin 전용 API 보호

### U7: 마스터 메뉴 삭제 cascade

- `MasterMenuItemRepositoryImpl.deleteWithCascade(menuItemId)`:
  1. `menuOverrideRepository.deleteAllForMaster(menuItemId)` — collectionGroup batch delete
  2. 마스터 메뉴 doc 삭제
- `CountStoresUsingPriceOverrideUseCase` — 삭제 전 영향 매장 수 확인 (UI 경고용)

### U8: AdminApprovalQueuePage 4탭

- 탭 구조: 매장 / 브랜드 / 가격 오버라이드 / 점포 한정 메뉴
- 기존 2탭(매장/브랜드) 에서 2탭 추가
- AppBar 타이틀 `'승인'` (spec 명세)

### U9: OwnerMyStorePage brandId 분기 (호출 3 — 본 호출)

- `store.brandId == null` → `_PersonalStoreDetailView` (기존 동작 그대로)
- `store.brandId != null` → `_BrandStoreDetailView`
  - `brandByIdProvider(store.brandId!)` 로 브랜드명 조회
  - `StoreScopeBadge.brand(brandName)` 헤더 카드에 표시
  - `_BrandStoreInfoBanner`: "매장 핵심 정보는 브랜드 본사가 관리해요." (info 톤)
  - "매장 정보 수정" 버튼 비노출
  - "운영 정보 수정" 버튼만 전체 너비 표시 → `StoreOperationFormPage` 진입
  - rejected 상태: `_BrandRejectedBanner` (재제출 CTA 없음, 사유만 + 안내 문구)

### U10: 시드 데이터 갱신 (호출 3 — 본 호출)

신규 추가:
- `brands/phase3_seed_brand_001` — Q브루어리 (status=approved)
- `brands/phase3_seed_brand_001/menuItems/bm_signature_americano` — 마스터 메뉴 1
- `brands/phase3_seed_brand_001/menuItems/bm_house_latte` — 마스터 메뉴 2
- `stores/phase3_brand_store_001` — Q브루어리 강남점 (brandId=phase3_seed_brand_001, status=approved)

---

## 결정 J 적용: 브랜드 매장 운영 필드 점주 즉시

spec 결정 J: 브랜드 매장에서도 운영 필드(영업시간, 전화번호, 사진 등)는 점주가 즉시 수정 가능.

구현:
- sub-phase 2 의 `UpdateStoreOperationFieldsUseCase` 를 그대로 활용
- `_BrandStoreDetailView` 에서 "운영 정보 수정" 버튼 → `StoreOperationFormPage(existing: store)` 진입
- `StoreOperationFormPage` 는 `UpdateStoreOperationFieldsUseCase` 를 호출 (brandId 분기 불필요)
- "매장 정보 수정" (`StoreCoreFormPage`) 버튼만 비노출 처리

---

## case B 머지 활성화

`lib/data/repositories/menu_item_repository_impl.dart` 의 `watchByStore` 메서드가 sub-phase 3 에서 실제 활성화됨.

```
brandId == null → case A
brandId != null → Rx.combineLatest3(
  masterDs.watchAllByBrand(brandId),     // brands/{brandId}/menuItems
  overrideDs.watchByStore(storeId),      // stores/{storeId}/menuOverrides
  storeOnlyDs.watchStoreOnly(storeId),   // stores/{storeId}/menuItems (scope=store)
) → _mergeForBrandStore(...)
```

customer 화면에서 `watchByStore(storeId, brandId: store.brandId)` 를 호출하면 자동으로 case B 경로 진입.

---

## Firestore 컬렉션 doc 형태

### `stores/{storeId}/menuOverrides/{masterMenuItemId}`

```
{
  masterMenuItemId: String,       // doc.id 와 동일
  storeId: String,
  brandId: String,
  priceOverride: int?,            // null 이면 기본가 유지
  excluded: bool,                 // true 이면 해당 매장 메뉴판에서 제거
  soldOut: bool,                  // 운영 필드 (sub-phase 5)
  disabledOptionGroupIds: [String],
  disabledOptionItemIds: [String],
  status: 'pending' | 'approved' | 'rejected',
  submittedBy: String?,
  submittedAt: Timestamp?,
  approvedBy: String?,
  approvedAt: Timestamp?,
  rejectedReason: String?,
  updatedBy: String?,
  updatedAt: Timestamp?
}
```

### `stores/{storeId}/menuItems/{id}` (scope=store, 점포 한정 메뉴)

```
{
  name: String,
  imageUrl: String,
  description: String?,
  mainCategory: String,
  subCategoryId: String?,
  basePrice: int,
  optionGroupRefs: [{ scope, id }],
  soldOut: bool,
  displayOrder: int,
  scope: 'store',                 // 점포 한정 식별자
  brandId: String,                // collectionGroup filter 용
  storeId: String,
  status: 'pending' | 'approved' | 'rejected',
  submittedBy: String?,
  submittedAt: Timestamp?,
  approvedBy: String?,
  approvedAt: Timestamp?,
  rejectedReason: String?,
  createdAt: Timestamp?
}
```

### `brands/{brandId}` (시드)

```
{
  name: 'Q브루어리',
  logoUrl: '',
  description: String,
  status: 'approved',
  submittedBy: 'seed',
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### `stores/{storeId}` — 브랜드 매장 추가 필드

```
{
  ...기존 필드...,
  brandId: String,   // null 이면 개인 매장, non-null 이면 브랜드 매장
  status: 'approved' | 'pending' | 'rejected'
}
```

---

## status 전이 규칙 요약

```
[신규 override]
  brand 생성 → pending
  admin 승인 → approved
  admin 반려 → rejected
  brand 재제출(핵심 필드) → pending

[점포 한정 메뉴]
  brand 생성 → pending
  admin 승인 → approved
  admin 반려 → rejected
  brand 핵심 필드 수정 → pending
  brand 운영 필드만 수정 → status 변경 없음 (즉시 반영)

[브랜드 매장 등록]
  brand SubmitStoreByBrandUseCase → pending
  admin 승인 → approved (매장 노출)
  admin 반려 → rejected (재제출: brand 측에서 핵심 정보 수정 후 재제출)
```

---

## 권한 매트릭스 코드 적용

| 액션 | 호출 주체 | 가드 |
|---|---|---|
| UpsertMenuOverrideCore | brand | `_assertBrandOwnership(override.brandId)` |
| DeleteMenuOverride | brand | `_assertBrandOwnership(override.brandId)` |
| ApproveMenuOverride | admin | `_assertAdmin()` |
| RejectMenuOverride | admin | `_assertAdmin()` |
| CreateStoreOnlyMenu | brand | `_assertOwnership(menu.brandId)` |
| UpdateStoreOnlyMenuCore | brand | `_assertOwnership(menu.brandId)` |
| ApproveStoreOnlyMenu | admin | `_assertAdmin()` |
| RejectStoreOnlyMenu | admin | `_assertAdmin()` |
| DeleteMasterMenuWithCascade | brand | `_assertOwnership(brandId)` |
| ApproveBrand / ApproveStore | admin | `_assertAdmin()` |

---

## 테스트 포인트

### 브랜드 모듈

- [ ] `BrandStoresPage`: brand 소속 매장 목록 표시. 빈 상태 CTA 표시
- [ ] `BrandStoreFormPage`: 마스터 메뉴 multi-select (FilterChip). 저장 시 `SubmitStoreByBrandUseCase` 호출 + 미선택 메뉴 excluded batch seed
- [ ] `BrandStoreCustomizationPage`: 2탭(가격 오버라이드 / 점포 한정 메뉴) IndexedStack 전환
- [ ] `BrandPriceOverrideListPage`: 마스터 메뉴별 `MasterMenuOverrideCard` 표시. override 없으면 기본가 표시
- [ ] `BrandPriceOverrideFormPage`: priceOverride 입력 저장 → status=pending, SnackBar '검토 요청을 보냈어요'
- [ ] `ExcludedToggle` ON → excluded=true → status=pending 회귀
- [ ] `BrandStoreOnlyMenuFormPage`: 신규 저장 → `CreateStoreOnlyMenuUseCase` → status=pending
- [ ] `BrandStoreOnlyMenuFormPage`: 운영 필드만 저장 → `UpdateStoreOnlyMenuOperationUseCase` → 즉시 반영 SnackBar
- [ ] `BrandApprovalTrackingPage`: 매장·override·점포 한정 메뉴 제출 현황 합산 표시

### Admin 모듈

- [ ] `AdminApprovalQueuePage`: AppBar 타이틀 '승인', 4탭(매장/브랜드/가격오버라이드/점포한정) 정상 전환
- [ ] `AdminPendingMenuOverridesPage`: pending override 목록 표시. 탭 카운트 배지
- [ ] `AdminMenuOverrideApprovalDetailPage`: 승인 → status=approved, 반려 → rejected + 사유 저장
- [ ] `AdminPendingBrandStoreItemsPage`: pending 점포 한정 메뉴 목록 표시
- [ ] `AdminBrandStoreItemApprovalDetailPage`: 승인/반려 동작
- [ ] `AdminBrandStoreManagementPage`: 브랜드 매장의 override + 점포 한정 메뉴 목록 표시
- [ ] `AdminStoreApprovalDetailPage`: 브랜드 매장 반려 시 재제출 CTA 비노출

### Owner 모듈 (호출 3)

- [ ] `store.brandId == null` → `_PersonalStoreDetailView` 렌더링 (기존 동작 그대로)
- [ ] `store.brandId != null` → `_BrandStoreDetailView` 렌더링
  - [ ] `StoreScopeBadge.brand(brandName)` 헤더 카드에 표시
  - [ ] `_BrandStoreInfoBanner` 표시 ("매장 핵심 정보는 브랜드 본사가 관리해요.")
  - [ ] "매장 정보 수정" 버튼 비노출 확인
  - [ ] "운영 정보 수정" 버튼 → `StoreOperationFormPage` 정상 진입
  - [ ] rejected 상태 → `_BrandRejectedBanner` 표시 (재제출 CTA 없음, 사유 + 안내 문구)
  - [ ] `brandByIdProvider` 로딩 중 → brandName 'placeholder' `'브랜드 매장'` 표시

### 시드

- [ ] 시드 실행 후 Firestore 에 `brands/phase3_seed_brand_001` 생성 확인
- [ ] `brands/phase3_seed_brand_001/menuItems` 에 2건 생성 확인
- [ ] `stores/phase3_brand_store_001` 에 `brandId: 'phase3_seed_brand_001'` + `status: 'approved'` 확인
- [ ] customer 화면에서 Q브루어리 강남점 매장이 case B 경로로 메뉴 로드 확인

### case B 머지

- [ ] 브랜드 매장에서 excluded=true + approved override → customer 메뉴판에서 해당 메뉴 미표시
- [ ] priceOverride + approved override → customer 메뉴판에서 오버라이드 가격 표시
- [ ] 점포 한정 메뉴 approved → customer 메뉴판 append 표시

### 아키텍처

- [ ] brand/admin/owner presentation 레이어에서 Firebase 직접 import 없음 (`flutter analyze` 0 issue 확인)
- [ ] MenuOverrideRepositoryImpl, MasterMenuItemRepositoryImpl 의 권한 가드 동작
- [ ] 색상 하드코딩 없음 (AppColors 토큰만 사용)

---

## 회귀 검증

- Phase 1a/1b/1c (매장 등록, 카테고리, 옵션그룹): `watchByStore` case A 경로 그대로 (brandId=null)
- Phase 2 (AI 추천, 리뷰, Qoin): 영향 없음 (새 컬렉션만 추가)
- sub-phase 1 (master menu 관리): `cascadeDeleteOverrides` 실제 구현만 추가, 기존 CRUD 불변
- sub-phase 2 (admin 매장 승인): AdminApprovalQueuePage 탭 2개 추가 (기존 2탭 그대로 유지)
- 개인 매장 점주 → `_PersonalStoreDetailView` 분기로 기존 동작 완전 보존

grep 검증:
```bash
grep -r "import 'package:cloud_firestore" lib/presentation/ --include="*.dart" | wc -l  # 0 이어야 함
grep -r "import 'package:firebase_" lib/presentation/ --include="*.dart" | wc -l       # 0 이어야 함
grep -r "import 'package:cloud_firestore" lib/domain/ --include="*.dart" | wc -l       # 0 이어야 함
```

---

## 미구현/보류 항목

| 항목 | 이유 | 후속 작업 |
|---|---|---|
| AdminBrandStoreManagementPage "+ 추가" | admin 직접 등록 폼은 복잡도 높음. 현재 placeholder SnackBar | 별도 task |
| BrandApprovalTrackingPage 점포 한정 메뉴 트래킹 | 현재 매장·override 까지만 구현. 점포 한정 메뉴 stream 미포함 | sub-phase 4 또는 별도 task |
| Firestore 인덱스 (collectionGroup query) | `menuOverrides` / `menuItems(scope=store)` collectionGroup query 에 복합 인덱스 필요 | `firestore.indexes.json` 별도 task |
| Firestore 보안 규칙 | brand/owner/admin role 별 규칙 미작성 | 보안 규칙 별도 task |
| override 운영 필드 (soldOut 토글) | sub-phase 5 에서 점주 즉시 토글 구현 예정 | sub-phase 5 |
| 가격 오버라이드 삭제 시 U7 경고 | `CountStoresUsingPriceOverrideUseCase` 구현됨. 마스터 메뉴 삭제 UI 경고 연동은 미구현 | sub-phase 4 |

---

## 코드 생성 필요 여부

- freezed 코드 생성 완료 (`menu_override_entity.freezed.dart`)
- 신규 entity 추가 시 재실행 명령:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 검증 결과

```
flutter analyze
Analyzing OrderApp...
No issues found! (ran in 4.4s)
```

0 issue 확인. tester 호출 가능 상태.
