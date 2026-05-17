# sub-phase 8 — menu_sub_category_management 구현 결과

> **상태**: DONE  
> **날짜**: 2026-05-03  
> **flutter analyze**: 0 issues

---

## 구현 파일 목록

### 신규 생성

| 파일 | 설명 |
|---|---|
| `lib/domain/entities/sub_category_entity.dart` | SubCategoryScope enum + entity 필드 확장 (scope/brandId/storeId/createdAt/updatedAt) |
| `lib/core/errors/duplicate_sub_category_name_exception.dart` | 중복 이름 예외 |
| `lib/core/errors/sub_category_in_use_exception.dart` | 사용 중 삭제 예외 |
| `lib/domain/repositories/sub_category_repository.dart` | 2-tier Repository 인터페이스 |
| `lib/data/repositories/sub_category_repository_impl.dart` | Repository 구현 (중복 검증 + normalizedName 저장) |
| `lib/domain/usecases/watch_sub_categories_by_scope_use_case.dart` | WatchSubCategoriesByBrand/Store UseCase |
| `lib/domain/usecases/upsert_sub_category_use_case.dart` | UpsertSubCategory UseCase |
| `lib/domain/usecases/toggle_sub_category_active_use_case.dart` | ToggleSubCategoryActive UseCase |
| `lib/domain/usecases/delete_sub_category_use_case.dart` | DeleteSubCategory UseCase |
| `lib/domain/usecases/find_duplicate_sub_category_name_use_case.dart` | FindDuplicateSubCategoryName UseCase (디바운스 lookup) |
| `lib/domain/usecases/count_sub_category_usage_use_case.dart` | CountSubCategoryUsage UseCase |
| `lib/presentation/brand/sub_categories/providers/brand_sub_category_providers.dart` | Brand DI + Stream/Usage providers |
| `lib/presentation/owner/sub_categories/providers/owner_sub_category_providers.dart` | Owner DI + Stream providers |
| `lib/presentation/brand/sub_categories/brand_sub_category_list_page.dart` | Brand 목록 (필터 칩 + 섹션 그룹핑 + Switch 즉시 토글) |
| `lib/presentation/brand/sub_categories/brand_sub_category_form_page.dart` | Brand 등록/수정 폼 (디바운스 300ms 중복 검증) |
| `lib/presentation/owner/sub_categories/owner_store_sub_category_list_page.dart` | Owner 목록 |
| `lib/presentation/owner/sub_categories/owner_store_sub_category_form_page.dart` | Owner 등록/수정 폼 |
| `lib/presentation/common/widgets/sub_category_delete_dialog.dart` | 공통 삭제 다이얼로그 (사용 0 → hard delete / 사용 중 → 비활성화 유도) |
| `lib/presentation/common/widgets/sub_category_chips_selector.dart` | 메뉴 폼 공통 칩 선택기 + InactiveSubCategoryWarningLabel |

### 수정

| 파일 | 변경 내용 |
|---|---|
| `lib/domain/entities/sub_category_entity.dart` | scope/brandId/storeId/createdAt/updatedAt 추가, SubCategoryScope enum 추가 |
| `lib/domain/entities/sub_category_entity.freezed.dart` | build_runner 재생성 |
| `lib/data/models/sub_category_model.dart` | 2-tier 필드 + normalizedName 처리 + toFirestoreCreate() |
| `lib/data/datasources/remote/sub_category_remote_data_source.dart` | brand/store 서브컬렉션 CRUD + collectionGroup usage count |
| `lib/core/constants/firestore_paths.dart` | subCategoriesSubcollection, brandSubCategoriesPath, storeSubCategoriesPath 추가 |
| `lib/presentation/brand/more/brand_more_page.dart` | "서브 카테고리 관리" ListTile 추가 |
| `lib/presentation/owner/my_store/my_store_page.dart` | _SubCategoryManagementButton 추가 (brandId==null 가드) |
| `lib/presentation/brand/master_menu/master_menu_form_page.dart` | _selectedSubCategoryId 상태 + 메인 카테고리 cascade reset + SubCategoryChipsSelector 삽입 |
| `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart` | 동일 패턴 적용 (brand scope sub) |
| `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` | _selectedSubCategoryId 상태 + cascade reset + SubCategoryChipsSelector 삽입 (store scope sub) |
| `firestore.indexes.json` | menuItems collectionGroup subCategoryId ASC 인덱스 추가 |

---

## 핵심 변경 요약

### Step 1 — Domain / Data
- `SubCategoryScope` enum (`brand` / `store`) 을 entity 에 추가.
- `SubCategoryEntity` 에 scope/brandId/storeId/createdAt/updatedAt 추가. 기존 `mainCategoryCode` 유지 → customer 호환.
- `SubCategoryRepository` 신규 인터페이스: watchByBrand/watchByStore/findById/upsert/toggleActive/delete/findDuplicateName/countUsage.
- `SubCategoryRemoteDataSource`: brand(`brands/{brandId}/subCategories/`) / store(`stores/{storeId}/subCategories/`) 각각 CRUD. legacy global read 유지.
- `SubCategoryRepositoryImpl.upsert()` 내부에서 중복 이름 검증 → `DuplicateSubCategoryNameException` throw. normalizedName 필드(`trim().toLowerCase()`) 를 Firestore 에 함께 저장.

### Step 2 — Brand 본사 CRUD UI
- `BrandSubCategoryListPage`: 메인 카테고리 필터 칩(전체/각 메인), 전체 시 섹션 헤더 그룹핑, Switch 즉시 토글, 사용 수 chip, FAB.
- `BrandSubCategoryFormPage`: 이름 디바운스(300ms) lookup + submit 시 UseCase race 차단 이중 방어.
- `SubCategoryDeleteDialog`: 사용 0 → hard delete / 사용 중 → "비활성화로 전환" 버튼.
- `BrandMorePage` 에 "서브 카테고리 관리" ListTile 추가.

### Step 3 — Owner 개인 매장 CRUD UI
- `OwnerStoreSubCategoryListPage` / `OwnerStoreSubCategoryFormPage`: brand 와 동일 구조, store scope.
- `MyStorePage._SubCategoryManagementButton`: `store.brandId == null` 가드 → 가맹점 점주 미노출.

### Step 4 — 메뉴 폼 3종 sub-category 칩
- `SubCategoryChipsSelector` 공통 위젯: props 주입, inactive prefill 경고(`InactiveSubCategoryWarningLabel`), "없음" 칩 포함, 선택 사항.
- `MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage`: brand sub 칩 삽입, 메인 카테고리 변경 시 `_selectedSubCategoryId = null` cascade reset.
- `OwnerStoreMenuFormPage`: store sub 칩 삽입, 동일 cascade reset.
- 세 폼 모두 `subCategoryId` 필드를 entity 에 반영해 제출.

### Step 5 — 인덱스
- `firestore.indexes.json` 에 `collectionGroup('menuItems') / subCategoryId ASC` 추가.
- **사용자 수동 작업 필요**: Firebase Console → Firestore → 색인 → 단일 필드 → 예외 추가
  - 컬렉션 ID: `menuItems`
  - 필드: `subCategoryId`
  - 쿼리 범위: 컬렉션 그룹 — ASC

---

## Firestore 인덱스 추가 안내 (사용자 수동)

`countMenuItemUsage` 가 `collectionGroup('menuItems').where('subCategoryId', ...)` 를 사용하므로 아래 색인을 Firebase Console 에서 직접 추가해야 한다.

1. Firebase Console → Firestore Database → 색인 탭
2. **단일 필드** 색인 → 예외 추가
3. 컬렉션 ID: `menuItems` / 필드: `subCategoryId` / 쿼리 범위: **컬렉션 그룹** / 순서: ASC

---

## 테스트 포인트

### 자동 (dart analyze)
- `flutter analyze`: 0 issues 확인 완료.

### 사용자 실기기 검증

#### Brand 본사
1. **서브 카테고리 등록**: BrandMorePage → "서브 카테고리 관리" → FAB → 이름/메인 카테고리 선택 → 저장 → 목록에 노출 확인.
2. **중복 이름 차단**: 같은 이름 입력 → 디바운스 300ms 후 inline 에러 "이미 같은 이름의 분류가 있어요" 노출.
3. **편집**: 목록 카드 탭/팝업 편집 → 수정 후 저장 → 반영 확인.
4. **active Switch 즉시 토글**: confirm dialog 없이 즉시 active 변경 확인.
5. **삭제 (사용 없음)**: 사용 0개 항목 삭제 → hard delete 확인.
6. **삭제 (사용 중)**: 메뉴에 sub 연결 후 삭제 시도 → "비활성화로 전환" 다이얼로그 노출 → 버튼 탭 시 비활성화 처리 확인.
7. **필터 칩**: 전체 → 섹션 헤더 그룹핑 / 특정 메인 → 평면 리스트 전환 확인.

#### Owner 개인 매장
8. **메뉴 분류 관리 진입**: MyStorePage → "메뉴 분류 관리" 버튼 노출 (개인 매장 + approved 상태).
9. **가맹점 점주 미노출**: brandId 있는 매장 → "메뉴 분류 관리" 버튼 미노출 확인.
10. **store sub 등록/편집/삭제**: brand sub 와 동일 시나리오 store scope 로 검증.
11. **다른 scope 간 동일 이름 허용**: brand sub 와 store sub 에 같은 이름 등록 가능 확인 (차단 안됨).

#### 메뉴 폼 sub-category 칩
12. **MasterMenuFormPage**: 메인 카테고리 선택 시 해당 brand sub 칩 노출 → 선택 → 저장 후 menuItem.subCategoryId 반영 확인.
13. **Cascade reset**: 메인 카테고리 변경 시 sub 선택 해제 확인.
14. **inactive prefill 경고**: 이미 선택된 sub가 비활성화되면 "이 분류는 비활성화되었습니다..." 경고 레이블 노출.
15. **sub 선택 없이 저장 가능**: "없음" 선택 또는 선택 안 해도 메뉴 등록 가능 확인.
16. **OwnerStoreMenuFormPage**: store scope sub 칩 노출 확인.
17. **BrandStoreOnlyMenuFormPage**: brand scope sub 칩 노출 확인.

---

## 미구현 / 보류

없음. spec 범위 내 모두 구현 완료.

단, `MenuCategoryRepository.watchSubCategories()` (legacy global) 는 customer 호환용으로 유지. 기존 `WatchSubCategoriesUseCase` 도 유지.
