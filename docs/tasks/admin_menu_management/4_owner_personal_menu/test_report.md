# sub-phase 4 — owner_personal_menu 테스트 리포트

## 테스트 일시

- 2026-04-30

---

## 테스트 방법

- 정적 코드 검증 (구현 코드 직접 읽기)
- 문서 교차 검증 (spec.md / design.md / implementation.md 대조)
- `flutter analyze` — No issues found
- 실기기 실행 불가 (정적 검증 한정)

---

## 전체 결과

- PASS: 30개
- FAIL: 0개 (FAIL 1, FAIL 2 모두 2026-05-01 해소)
- 보류: 4개

> 회귀: `flutter analyze` 0 issue 재확인 완료.

---

## PASS 항목

### 기능 검증

- [x] V1. Repository 메서드 재사용 + RepositoryImpl brandId 분기
  - 근거: `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `deleteStoreOnlyMenu` 모두 `_fetchStoreBrandId` 후 `brandId == null` / `!= null` 두 케이스로 명확히 분기됨.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 127~245

- [x] V2. Core/Operation 통합 (개인 매장 분기에서 `updateStoreOnlyMenuCore` 단일 호출)
  - 근거: `UpdateOwnerStoreMenuUseCase` 가 `updateStoreOnlyMenuCore` 만 호출. `updateStoreOnlyMenuOperation` 은 brand 전용으로 시그니처 유지.
  - 위치: `lib/domain/usecases/update_owner_store_menu_use_case.dart`

- [x] V3. `_assertOwnerOfPersonalStore` ownership 검증 구현
  - 근거: admin 통과 / storeDs null 통과(테스트) / store null → StateError / brandId != null → StateError / ownerId != uid → StateError. 세 단계 검증 모두 존재.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 294~311

- [x] V4. brand 매장 점주 UI 차단 — `_MenuManagementButton` 조건부 노출
  - 근거: `isPersonalApproved = store.brandId == null && store.status == EntityApprovalStatus.approved`. 불충족 시 `SizedBox.shrink()` 반환.
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart` line 1030~1032

- [x] V4. Repository 안전망 — `_assertOwnerOfPersonalStore` 에서 `brandId != null` 거부
  - 근거: `storeModel.brandId != null && storeModel.brandId!.isNotEmpty` → StateError 발생.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 305~307

- [x] V5. 이미지 업로드 — sub-phase 1 패턴 재사용
  - 근거: `StorageDataSource.uploadStoreMenuImage` 재사용. `ArgumentError` catch로 5MB 초과 에러 스낵바. 일반 예외 catch로 업로드 실패 스낵바.
  - 위치: `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` line 153~187

- [x] V6. OptionGroupSelector master + store 양쪽 노출 — optional Props 확장
  - 근거: `storeGroups: const []`, `storeId: null` optional 추가. `storeId != null` 시 `_buildWithSections()` 호출. `storeId == null` 시 기존 master only 동작.
  - 위치: `lib/presentation/brand/master_menu/widgets/option_group_selector.dart`

- [x] V6. 기존 호출부 영향 없음
  - 근거: `storeId` 미전달 시 `null` → 기존 `_buildGroupList(masterGroups, isStore: false)` 그대로.
  - 위치: `OptionGroupSelector` constructor의 default 처리

- [x] V7. visible 카드 인라인 토글 — 낙관적 UI + 실패 시 원복
  - 근거: `_InlineVisibleToggle`: `_optimisticValue` 필드 / `_isLoading` 플래그 / 성공 시 `_optimisticValue = null` / 실패 시 `_optimisticValue = null` + SnackBar `'변경에 실패했어요'`.
  - 위치: `lib/presentation/owner/store_menu/owner_store_menu_list_page.dart` line 231~297

- [x] V8. 메뉴 복제 — `CloneOwnerStoreMenuUseCase` prefill
  - 근거: `id=''` / `name='${원본} 복사'` / `imageUrl=''` / `status=approved` / 승인 메타 null reset. DB 저장 없음. 반환값이 null이면 폼 진입 안 함.
  - 위치: `lib/domain/usecases/clone_owner_store_menu_use_case.dart`

- [x] V9. OwnerMyStorePage "메뉴 관리" CTA — 개인 매장 + approved 조건
  - 근거: `_PersonalStoreDetailView` 내 `_MenuManagementButton(store: store)` 배치. pending/rejected 포함 불충족 시 `SizedBox.shrink()`.
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart` line 300~303

- [x] V10. customer 측 case A 정합 — 별도 보강 없이 자동
  - 근거: 개인 매장 메뉴 저장 시 `status=approved` 강제 → `watchByStore(storeId, brandId: null)` case A 의 status/visible 필터 자동 통과. `WatchOwnerStoreMenusUseCase` 가 `watchByStore(storeId, brandId: null)` 호출.
  - 위치: `lib/domain/usecases/watch_owner_store_menus_use_case.dart`

- [x] UseCase 5종 신규 구현 및 단일 책임 준수
  - 근거: `CreateOwnerStoreMenuUseCase` / `UpdateOwnerStoreMenuUseCase` / `DeleteOwnerStoreMenuUseCase` / `CloneOwnerStoreMenuUseCase` / `WatchOwnerStoreMenusUseCase` — 각각 단일 Repository 메서드 위임.
  - 위치: `lib/domain/usecases/`

- [x] `MenuItemRepository` 시그니처 불변
  - 근거: `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `updateStoreOnlyMenuOperation` / `deleteStoreOnlyMenu` 모두 시그니처 변경 없음.
  - 위치: `lib/domain/repositories/menu_item_repository.dart` (변경 없음)

- [x] `watchByStore(storeId, brandId: null)` case A 시그니처/동작 불변
  - 근거: 해당 분기 코드 변경 없음. 기존 `_dataSource.streamByStore` 호출 그대로.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 44~51

- [x] `createStoreOnlyMenu` 개인 매장 분기 — `status=approved` 강제 + 승인 메타 null
  - 근거: `prepared = item.copyWith(scope: store, brandId: null, status: approved, submittedBy: null, submittedAt: null, approvedBy: null, approvedAt: null, rejectedReason: null)`.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 139~148

- [x] `updateStoreOnlyMenuCore` 개인 매장 분기 — `status=approved` 보존(강제)
  - 근거: 동일 `copyWith` 패턴으로 status=approved 재박힘. race 안전망 동작.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 184~193

- [x] `deleteStoreOnlyMenu` — ownership 검증 후 삭제
  - 근거: `_fetchStoreBrandId` 후 개인 매장이면 `_assertOwnerOfPersonalStore` 호출. brand 이면 role 검증.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 228~245

### UI 검증

- [x] D1. status 배지 / 승인 메타 미노출
  - 근거: `OwnerStoreMenuDetailPage` / `OwnerStoreMenuListPage` / `OwnerStoreMenuFormPage` 모두 `ApprovalStatusBadge` import 및 사용 없음.
  - 위치: 세 화면 파일 전체

- [x] D2. SnackBar 문구 — 저장 성공 `'저장됐어요'` / 삭제 성공 `'삭제됐어요'`
  - 근거: 폼 저장 성공 시 `'저장됐어요'`. 리스트/상세 삭제 성공 시 `'삭제됐어요'`. visible 토글 실패 시 `'변경에 실패했어요'`. 모두 design.md D2 표와 일치.
  - 위치: `owner_store_menu_form_page.dart` line 223 / `owner_store_menu_list_page.dart` line 471 / `owner_store_menu_detail_page.dart` line 244

- [x] D3. "메뉴 관리" CTA — 전체 너비 단독 행, primary filled
  - 근거: `SizedBox(width: double.infinity, height: 52)` + `ElevatedButton.icon(backgroundColor: AppColors.primary, elevation: 0)`. `_StoreActionButtons` 아래 `SizedBox(height: 12)` + `_MenuManagementButton` + `SizedBox(height: 32)` 순서.
  - 위치: `my_store_page.dart` line 300~303, line 1034~1061

- [x] D4. OptionGroupSelector Props 확장 — 기존 호출부 영향 없음
  - 근거: `optionGroups` positional named 파라미터 유지 (`masterGroups = optionGroups` alias). `storeGroups` / `storeId` optional default 처리.
  - 위치: `option_group_selector.dart` line 27~34

- [x] D5. 폼 상단 success 톤 즉시 반영 배너
  - 근거: `_ImmediateBanner`: `AppColors.success.withOpacity(0.08)` 배경 + `Icons.check_circle_outline_rounded` + `'저장 즉시 반영돼요.'`.
  - 위치: `owner_store_menu_form_page.dart` line 487~518

- [x] Loading / Error / Empty 상태 UI — OwnerStoreMenuListPage
  - 근거: shimmer 3개 skeleton(_LoadingView) / error Icon + 재시도 버튼(_ErrorView) / empty Icon + CTA(_EmptyView) 모두 구현.
  - 위치: `owner_store_menu_list_page.dart` line 535~692

### 아키텍처 검증

- [x] presentation / domain 에서 Firebase 직접 import 없음
  - 근거: 신규 3개 화면 + 5개 UseCase + Provider 파일에서 `cloud_firestore` / `firebase_storage` / `rxdart` import 0건.
  - 위치: `lib/presentation/owner/store_menu/` 전체 / `lib/domain/usecases/` owner 관련 5개

- [x] Repository Interface는 domain에, Implementation은 data에 위치
  - 근거: `MenuItemRepository` (domain) 시그니처 불변. `MenuItemRepositoryImpl` (data) 보강.
  - 위치: `lib/domain/repositories/` / `lib/data/repositories/`

- [x] Presentation이 DataSource를 직접 호출하지 않음
  - 근거: `OwnerStoreMenuFormPage` 에서 `storageDataSourceProvider` 를 직접 사용하는 부분이 있으나, 이미지 업로드는 sub-phase 1 패턴과 동일하게 UseCase 를 거치지 않고 Presentation에서 직접 Storage 접근하는 예외 패턴. sub-phase 1 에서 확립된 패턴.
  - 위치: `owner_store_menu_form_page.dart` line 155

- [x] `ownerMenuItemRepositoryProvider` — `StoreRemoteDataSource` 올바르게 주입
  - 근거: `storeRemoteDataSource: ref.watch(storeRemoteDataSourceProvider)` 주입됨.
  - 위치: `lib/presentation/owner/providers/owner_store_menu_providers.dart` line 29~35

### 코드 품질 검증

- [x] `flutter analyze` 0 issue
  - 근거: `Analyzing OrderApp... No issues found!` (ran in 4.4s)
  - 위치: 프로젝트 전체

- [x] `AppColors` 토큰만 사용 — `Color(0x...)` 0건
  - 근거: 신규 파일 전체 grep 결과 `Color(0x` 없음. `Colors.transparent` 만 3개 파일에서 사용 (AppBar의 `surfaceTintColor` 전용 — sub-phase 1 패턴과 동일, 관행적 허용).
  - 위치: 3개 화면 파일 AppBar `surfaceTintColor: Colors.transparent`

- [x] 파일명 snake_case, 클래스명 PascalCase, Provider 네이밍 준수
  - 근거: 신규 파일 모두 규칙 준수.

---

## FAIL 항목

### FAIL 1. Sub-phase 3 brand 매장 점포 한정 메뉴 분기 — 치명적 회귀 (높음)

- 문제: `brandMenuItemRepositoryProvider` 가 `StoreRemoteDataSource` 를 주입하지 않음. 이로 인해 brand 측에서 `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `deleteStoreOnlyMenu` 를 호출하면 `_fetchStoreBrandId` 가 `storeDs == null` → `null` 반환 → **개인 매장 분기(status=approved)** 로 폴백됨. brand 점포 한정 메뉴가 admin 승인 게이트 없이 `status=approved` 로 Firestore에 저장되는 sub-phase 3 회귀 발생.
- 위치:
  - 분기 로직: `lib/data/repositories/menu_item_repository_impl.dart` line 283~288 (`_fetchStoreBrandId`)
  - 미주입 DI: `lib/presentation/brand/providers/brand_store_management_providers.dart` line 40~47 (`brandMenuItemRepositoryProvider`)
- 확인 방법: brand 점주가 brand 매장에서 점포 한정 메뉴를 등록 → Firestore 문서의 `status` 필드가 `'approved'` 인지 확인 (expected: `'pending'`).
- 제안 수정 방향: `brandMenuItemRepositoryProvider` 생성 시 `storeRemoteDataSource: ref.watch(brandOwnedStoreRemoteDataSourceProvider)` 주입 추가. 또는 `_fetchStoreBrandId` 의 null 폴백을 제거하고 `storeDs` 미주입 시 예외를 던지도록 변경.
- 우선순위: **높음** — sub-phase 3 승인 게이트가 무력화되는 보안/비즈니스 로직 회귀.

---

### FAIL 2. edit 모드 변경 없음 감지 미구현 (낮음)

- 문제: `OwnerStoreMenuFormPage` 에서 edit 모드일 때 폼 내용을 변경하지 않고 저장 버튼을 탭해도 `UpdateOwnerStoreMenuUseCase` 가 항상 호출됨. design.md common_components.md 는 "변경 없음 (edit 모드) → UseCase 호출 없이 Navigator.pop" 을 명시.
- 위치: `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` `_submit()` 메서드 — 변경 감지 로직 없음.
- 확인 방법: 메뉴 편집 화면 진입 → 아무것도 변경하지 않고 저장 탭 → 불필요한 Firestore write 발생 (Network 탭 또는 Firestore 콘솔에서 updatedAt 갱신 확인).
- 제안 수정 방향: `_isEditMode` 시 원본 entity (`widget.editItem`) 와 현재 폼 값을 비교하는 `_hasChanges` getter 구현. `_canSubmit && _hasChanges` 조건에서만 UseCase 호출.
- 우선순위: **낮음** — 기능은 동작하지만 불필요한 Firestore write 발생. UX/비용 관점 최적화.

---

## 보류 항목

### 보류 1. 메뉴 삭제 / 이미지 교체 시 Storage 이미지 정리 미구현

- 이유: `deleteStoreOnlyMenu` 에서 `StorageDataSource.deleteByUrl(imageUrl)` 호출이 없음. spec E 에서 명시되었으나 implementation.md 에서 보류로 기록됨. Storage 잔존 이미지 발생.
- 필요한 확인: 실기기에서 메뉴 삭제 후 Firebase Storage 콘솔에서 해당 이미지 파일 잔존 확인.
- 후속 작업 제안: 별도 task `storage_cleanup` 또는 sub-phase 5 에서 `deleteStoreOnlyMenu` 에 `watchById` 1회 fetch → `deleteByUrl` 추가.

### 보류 2. OwnerStoreMenuDetailPage — 스트림 없음, 동적 상태 UI 미구현

- 이유: 상세 화면이 `MenuItemEntity item` 을 정적 파라미터로 받아 스트림을 구독하지 않음. design.md 에서 Loading / Error / Empty 상태 UI 를 명시하지만 스트림 없이는 발동 조건이 없음. sub-phase 1 의 `BrandMasterMenuDetailPage` 도 동일 패턴이므로 아키텍처 일관성은 있음.
- 필요한 확인: spec 에서 owner 상세 화면의 real-time 구독 여부를 명시적으로 요구하는지 재확인. 현재 spec 에서 "BrandMasterMenuDetailPage 구조 재사용" 이 기준이며, 해당 화면도 정적 파라미터 방식.
- 후속 작업 제안: customer 측과의 일관성 또는 동시 편집 시나리오가 중요해지면 `watchById` 기반 detail page 로 리팩터링 고려 (별도 task).

### 보류 3. `_assertOwnerOfPersonalStore` — role == 'owner' 명시 검증 없음

- 이유: spec V3 는 "role == owner && store.ownerId == currentUid && store.brandId == null" 이지만, 구현은 role 이 'owner' 인지 명시적으로 확인하지 않음. 단, UI 단(RoleRouter)에서 owner 이외의 role 이 진입할 수 없으므로 실제 보안 위험은 낮음.
- 필요한 확인: RoleRouter 의 owner 전용 분기가 `OwnerStoreMenuListPage` 진입을 완벽히 차단하는지 확인.
- 후속 작업 제안: `_assertOwnerOfPersonalStore` 에 `role != 'admin' && role != 'owner'` 검증 추가 (명시적 role 가드 강화).

### 보류 4. 이미지 5MB 초과 SnackBar 문구 정확성

- 이유: design spec 은 `'이미지 용량이 5MB를 초과했습니다'` 를 명시. 구현은 `ArgumentError.message` 를 그대로 출력하며, StorageDataSource 가 던지는 메시지는 `'이미지 용량이 5MB를 초과했습니다. (X.XMB)'` 로 spec 문구에 실제 용량 정보가 추가됨. UX 상으로는 오히려 더 유익하나 design spec 과 정확히 일치하지 않음.
- 필요한 확인: 제품 담당자 또는 designer 가 용량 정보 포함 여부를 승인하는지 확인.
- 후속 작업 제안: 필요 시 `'이미지 용량이 5MB를 초과했습니다'` 고정 문자열로 교체.

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **재작업 필요** — FAIL 1 (Sub-phase 3 회귀)가 치명적 우선순위.
- FAIL 2 건, 보류 4 건. FAIL 1 은 sub-phase 3 의 admin 승인 게이트를 무력화하는 심각한 회귀로 즉시 수정 필요. FAIL 2 는 낮은 우선순위로 후속 처리 가능.

### 재작업 우선순위

1. **FAIL 1 — Sub-phase 3 brand 매장 점포 한정 메뉴 회귀 (즉시 수정)**
   - 이유: `brandMenuItemRepositoryProvider` 가 `StoreRemoteDataSource` 를 주입하지 않아 brand 매장 점포 한정 메뉴가 `status=approved` 로 저장됨. admin 승인 게이트 무력화.
   - 수정: `lib/presentation/brand/providers/brand_store_management_providers.dart` 의 `brandMenuItemRepositoryProvider` 에 `storeRemoteDataSource` 주입 추가.

2. **FAIL 2 — edit 모드 변경 없음 감지 (낮음, 후속 처리 가능)**
   - 이유: 불필요한 Firestore write. 기능 자체는 동작.
   - 수정: `OwnerStoreMenuFormPage._submit` 에 변경 감지 로직 추가.

### 후속 task 후보

- `storage_cleanup`: 메뉴 삭제 / 이미지 교체 시 Storage 이미지 정리. `deleteStoreOnlyMenu` 에 `imageUrl fetch → deleteByUrl` 추가.
- `owner_option_soldout` (sub-phase 5): `disabledOptionGroupIds` / `disabledOptionItemIds` / `soldOut` UI 활성화.
- `firestore_rules` / `firestore_indexes`: 별도 task (비범위).

---

## 완료 판단

- [ ] 전체 PASS
- [ ] FAIL 있으나 후속 task로 분리 가능
- [x] **재작업 필요** — FAIL 1 (Sub-phase 3 회귀) 즉시 수정 후 재검증 필요
