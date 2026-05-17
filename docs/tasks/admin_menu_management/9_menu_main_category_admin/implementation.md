# sub-phase 9 menu_main_category_admin — implementation

## 구현 완료 항목

### 1. Domain
- `MainCategoryEntity` (freezed): `id`, `label`, `displayOrder`, `active`, `createdAt`, `updatedAt`
- `MainCategoryRepository` 인터페이스 (read + admin CRUD + countDetailedUsage + seedDefaultsIfEmpty)
- `MainCategoryInUseException` (`core/errors/`)
- UseCase 5개 (`domain/usecases/`):
  - `WatchMainCategoriesAllUseCase`
  - `WatchMainCategoriesActiveUseCase`
  - `UpsertMainCategoryUseCase`
  - `ToggleMainCategoryActiveUseCase`
  - `DeleteMainCategoryUseCase`
  - `CountMainCategoryDetailedUsageUseCase`

### 2. Data
- `MainCategoryModel` (mapper)
- `MainCategoryRemoteDataSource` (Firestore `mainCategories/{id}`)
- `MainCategoryRepositoryImpl`

### 3. enum 제거 + 마이그레이션
- `MainCategoryCode` enum **삭제**
- `MenuItemEntity.mainCategoryCode: MainCategoryCode` → `String` (doc id)
- `SubCategoryEntity.mainCategoryCode: MainCategoryCode` → `String`
- `MenuItemModel`, `SubCategoryModel` 매퍼 시그니처 변경
- freezed/json_serializable 재생성 완료
- 호출처 마이그레이션:
  - 메뉴 폼 3종 (`master_menu_form_page`, `owner_store_menu_form_page`, `brand_store_only_menu_form_page`)
  - admin/owner/brand detail 페이지들 (`.name`, `.asString`, `.label` → 직접 String)
  - customer `store_menu_page` (Set<String> 호환)

### 4. customer MainCategoryTabs 동적 fetch
- 가로 스크롤 (design.md 결정)
- `mainCategoriesActiveProvider` watch → inactive 자동 제외
- minWidth 80, 선택 시 자동 스크롤 동작은 향후 보강 여지

### 5. admin UI 4종 신규
- `AdminMainCategoryListPage` — displayOrder 정렬, active Switch, 편집/삭제 액션, FAB, `_UsageChip` (영향 데이터 N/M 독립 watch + skeleton/error)
- `AdminMainCategoryFormPage` — 등록/수정 통합 (id/label/displayOrder/active)
- `MainCategoryDeleteDialog` — 사용 0개일 때만 hard delete, 사용 중이면 차단 + "비활성화로 전환" 직접 액션 (추가 confirm 안 거침 — design 결정)
- `MainCategoryDeactivateConfirmDialog` (4d Lite) — admin Switch true→false 시 노출, 영향 데이터 표시, 낙관적 UI 금지 (Switch 원상복구 패턴)

### 6. AdminMorePage 진입
- `AdminMorePage` 에 "메뉴 카테고리 관리" ListTile 추가 → push

### 7. 메뉴 폼 3종 동적 fetch + 4d Lite 경고 배너
- 3개 폼 모두:
  - 하드코딩 `_categories` 상수 제거
  - `mainCategoriesAllProvider` watch
  - 신규 등록 모드: active 만 노출
  - 수정 모드: 전체 노출, inactive 칩은 dim + IgnorePointer (선택 불가, 단 현재 선택값이면 시각적으로 강조)
  - 현재 선택값이 inactive 면 `InactiveCategoryWarningBanner` 노출
  - 폼 submit 정책: inactive 그대로 저장 허용 (design 결정)

### 8. 공통 위젯
- `lib/presentation/common/widgets/inactive_category_warning_banner.dart` — 4d Lite 경고 배너 공통 재사용
- 카피 확정: "이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요"

### 9. 인덱스
- `firestore.indexes.json` 신규 생성:
  - collectionGroup `menuItems`, `mainCategoryCode` ASC (사용 데이터 검사용)

---

## 신규 / 수정 파일

### 신규
- `lib/domain/entities/main_category_entity.dart`
- `lib/domain/repositories/main_category_repository.dart`
- `lib/domain/usecases/watch_main_categories_all_use_case.dart`
- `lib/domain/usecases/watch_main_categories_active_use_case.dart`
- `lib/domain/usecases/upsert_main_category_use_case.dart`
- `lib/domain/usecases/toggle_main_category_active_use_case.dart`
- `lib/domain/usecases/delete_main_category_use_case.dart`
- `lib/domain/usecases/count_main_category_detailed_usage_use_case.dart`
- `lib/data/models/main_category_model.dart`
- `lib/data/datasources/remote/main_category_remote_data_source.dart`
- `lib/data/repositories/main_category_repository_impl.dart`
- `lib/core/errors/main_category_in_use_exception.dart`
- `lib/presentation/customer/order/store/providers/main_category_providers.dart`
- `lib/presentation/admin/menu_categories/admin_main_category_list_page.dart`
- `lib/presentation/admin/menu_categories/admin_main_category_form_page.dart`
- `lib/presentation/admin/menu_categories/widgets/main_category_delete_dialog.dart`
- `lib/presentation/admin/menu_categories/widgets/main_category_deactivate_confirm_dialog.dart`
- `lib/presentation/common/widgets/inactive_category_warning_banner.dart`
- `firestore.indexes.json`

### 수정
- `lib/domain/entities/menu_item_entity.dart` (mainCategoryCode: String)
- `lib/domain/entities/sub_category_entity.dart` (mainCategoryCode: String)
- `lib/data/models/menu_item_model.dart`
- `lib/data/models/sub_category_model.dart`
- `lib/presentation/customer/order/store/widgets/main_category_tabs.dart` (동적 fetch + 가로 스크롤)
- `lib/presentation/customer/order/store/store_menu_page.dart` (subCategoriesProvider 가드)
- `lib/presentation/customer/order/store/providers/store_menu_providers.dart` (시그니처 변경)
- `lib/presentation/admin/more/admin_more_page.dart` (ListTile 추가)
- `lib/presentation/brand/master_menu/master_menu_form_page.dart` (동적 fetch + 경고 배너)
- `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` (동적 fetch + 경고 배너)
- `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart` (동적 fetch + 경고 배너)
- `lib/presentation/brand/master_menu/master_menu_detail_page.dart` (.asString → 직접 String)
- `lib/presentation/owner/store_menu/owner_store_menu_detail_page.dart` (.label → 직접 String)
- `lib/presentation/admin/approval/admin_brand_store_item_approval_detail_page.dart` (.name → 직접 String)
- `lib/presentation/admin/approval/admin_master_menu_approval_detail_page.dart` (.name → 직접 String)

### 삭제
- `lib/domain/entities/main_category_code.dart` ✅

---

## flutter analyze

```
Analyzing OrderApp...
No issues found! (ran in 4.7s)
```

---

## 사용자 실기기 검증 시나리오

### 핵심 (반드시 확인)
1. **admin 첫 진입 시드**: admin 더보기 → "메뉴 카테고리 관리" 첫 진입 → 기본 3개 (커피/논커피/디저트) 자동 시드 노출
2. **카테고리 추가**: FAB → 신규 등록 (예: "베이커리") → 리스트에 즉시 반영
3. **active Switch 비활성화**: 카테고리 선택 → Switch true→false → DeactivateConfirmDialog 영향 데이터 N/M 표시 → 확인 → inactive 처리. 취소 시 Switch 원상복구
4. **삭제 차단**: 사용 중 카테고리 삭제 시도 → DeleteDialog 차단 + "비활성화로 전환" 액션 → 즉시 비활성화 (추가 confirm 없음)
5. **하드 삭제**: 사용 0개 카테고리 → DeleteDialog 정상 삭제 가능

### 메뉴 폼 회귀
6. 마스터 메뉴 / 점주 / 브랜드 점포 한정 메뉴 신규 등록 시 active 카테고리 칩만 노출 + 정상 저장
7. 수정 모드에서 inactive 카테고리에 묶여있던 메뉴 진입 시 `InactiveCategoryWarningBanner` 노출
8. 수정 모드에서 inactive 칩 IgnorePointer 동작 (다른 active 카테고리는 선택 가능)
9. inactive 카테고리 그대로 저장 허용 (경고만 표시)

### customer 회귀
10. customer 매장 메뉴 진입 → MainCategoryTabs 가로 스크롤 + active 카테고리만 노출 + inactive 자동 제외
11. 매장이 보유하지 않은 카테고리 탭은 dim 처리

### 회귀 영향 점검
12. sub-phase 1 (마스터 메뉴 옵션 selector — 결정 J 회귀): 옵션 그룹 변경 시 status pending 회귀 정상
13. sub-phase 3 (점포 한정 메뉴 등록): brand 가맹점 점포 한정 메뉴 등록 정상
14. sub-phase 4 (점주 개인 메뉴): 개인 매장 메뉴 등록 정상
15. **menuItem audit**: 기존 menuItem 의 `mainCategoryCode` 가 doc id 와 매칭되는지 (이전 hotfix silent fallback 우려)

---

## 미구현 / 보류

없음. spec 결정사항 + 4d Lite 모두 구현 완료.

비범위 (사용자 결정 — Follow-up):
- F1: 4d Heavy (FCM/이메일 외부 알림)
- F2: 시각 토큰 별도 정리
- F3: i18n
- F4: `MenuCategories.all` 동적화 (별 도메인)

---

## 인덱스 갱신

`firestore.indexes.json` 신규 생성. Firebase CLI 로 배포 필요:
```bash
firebase deploy --only firestore:indexes
```

배포 전에는 collectionGroup 쿼리가 실패할 수 있음 (사용 데이터 카운트 등). 사용자가 Firebase Console 에서 직접 인덱스 추가하거나 CLI 배포 필요.
