# admin_menu_management / 3_brand_store_customization 테스트 리포트

## 테스트 일시

- 2026-05-02

---

## 테스트 방법

- 정적 코드 검증 (파일 존재 / 내용 확인)
- 문서 교차 검증 (spec.md / design/ / implementation.md ↔ 실제 코드)
- `flutter analyze` — 0 issue 확인
- `flutter test` — 4/4 통과 확인
- grep 기반 아키텍처 규칙 검증 (Firebase import / Color 하드코딩 / rxdart import)

---

## 전체 결과

- PASS: 42개
- FAIL: 0개 (FAIL-1/2/3/4 모두 2026-05-01 해소)
- 보류: 5개

> 회귀: `flutter analyze` 0 issue 재확인 완료.

---

## PASS 항목

### 기능 검증

- [x] U1 — AdminApprovalQueuePage AppBar 타이틀 `'승인'` + 4탭 구조 (브랜드/메뉴/매장/매장 커스텀)
  - 근거: `admin_approval_queue_page.dart` line 38 `'승인'`, line 53–69 4탭 라벨 일치
  - 위치: `lib/presentation/admin/approval/admin_approval_queue_page.dart`

- [x] U2 — `menuOverrides.excluded` 활용한 매장 등록 시 미선택 마스터 메뉴 excluded batch seed
  - 근거: `SubmitStoreByBrandUseCase` / `MenuOverrideRepository.seedExclusionsForStore` 연동 구현됨
  - 위치: `lib/domain/usecases/submit_store_by_brand_use_case.dart`, `lib/domain/repositories/menu_override_repository.dart`

- [x] U3 — 점포 한정 메뉴 vs 가격 오버라이드 entity 분리 유지
  - 근거: `MenuOverrideEntity`(menuOverrides 컬렉션)와 `MenuItemEntity`(scope=store)가 각각 독립 구현
  - 위치: `lib/domain/entities/menu_override_entity.dart`, `lib/data/repositories/menu_item_repository_impl.dart`

- [x] U4 — collectionGroup 인덱스 별도 task 분리 — 코드는 query만 작성
  - 근거: `MenuOverrideRemoteDataSource.streamPending()` / `streamPendingStoreOnlyMenus()` 쿼리만 존재, `firestore.indexes.json` 별도 task로 분리 명시됨 (implementation.md 보류 항목)
  - 위치: `lib/data/datasources/remote/menu_override_remote_data_source.dart`

- [x] U5 — ownership 검증 `_assertBrandOwnership` / `_assertAdmin` 패턴 구현
  - 근거: `MenuOverrideRepositoryImpl._assertBrandOwnership`, `MasterMenuItemRepositoryImpl._assertOwnership`, `StoreRepositoryImpl._assertAdmin`
  - 위치: `lib/data/repositories/menu_override_repository_impl.dart`, `lib/data/repositories/master_menu_item_repository_impl.dart`

- [x] U6 — 마스터 메뉴 삭제 cascade 실제 동작 활성화
  - 근거: `MasterMenuItemRepositoryImpl.deleteWithCascade`가 `_dataSource.cascadeDeleteOverrides(menuItemId)` 호출 (line 119). `master_menu_list_page.dart`에서 `CountStoresUsingPriceOverrideUseCase` 호출 후 다이얼로그 표시 구현됨 (line 367–385)
  - 위치: `lib/data/repositories/master_menu_item_repository_impl.dart`, `lib/presentation/brand/master_menu/master_menu_list_page.dart`

- [x] U7 — 마스터 가격 변경 시 priceOverride 보존 알림 실제 구현
  - 근거: `master_menu_form_page.dart` line 201–211에서 `basePrice` 변경 시 `CountStoresUsingPriceOverrideUseCase` 호출 → `_showPriceChangeDialog(n)` 표시
  - 위치: `lib/presentation/brand/master_menu/master_menu_form_page.dart`

- [x] U8 — customer 측 머지 case B 활성화 (`Rx.combineLatest3` + `_mergeForBrandStore`)
  - 근거: `menu_item_repository_impl.dart` line 40–66에서 `brandId != null` 분기 → `Rx.combineLatest3` 구현. `rxdart` data 레이어에서만 import
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart`

- [x] U9 — `OwnerMyStorePage` brandId 분기 (`_BrandStoreDetailView` / `_PersonalStoreDetailView`)
  - 근거: line 236–241 분기 구현. `_BrandStoreInfoBanner`, `_BrandRejectedBanner`, `_BrandStoreActionButtons` 구현됨
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart`

- [x] U10 — 시드 데이터 갱신 (brand doc + master menu 2개 + brand store 1개)
  - 근거: `Phase1SeedData.brandId='phase3_seed_brand_001'`, `brandStoreId='phase3_brand_store_001'`, Q브루어리 brand/store/masterMenu 2건 포함
  - 위치: `lib/dev/seed/phase1_seed_data.dart`, `lib/dev/seed/phase1_seed.dart`

- [x] `MenuOverrideEntity` freezed 정의 — spec 필드 전체 일치
  - 근거: `masterMenuItemId`, `storeId`, `brandId`, `priceOverride?`, `excluded`, `soldOut`, `disabledOptionGroupIds`, `disabledOptionItemIds`, `status`, 승인 메타 전부 구현됨
  - 위치: `lib/domain/entities/menu_override_entity.dart`

- [x] `MenuOverrideRepository` interface — spec 메서드 전체 일치
  - 근거: `watchByStore`, `watchPendingForAdmin`, `getByStoreAndMaster`, `upsertOverrideCore`, `approveOverride`, `rejectOverride`, `deleteOverride`, `deleteAllForMaster`, `seedExclusionsForStore`, `countStoresUsingPriceOverride` 모두 구현됨
  - 위치: `lib/domain/repositories/menu_override_repository.dart`

- [x] UseCase 17종 신규 파일 존재 확인
  - 근거: spec에 명시된 17개 UseCase 파일 모두 `lib/domain/usecases/`에 존재
  - 위치: `lib/domain/usecases/`

- [x] `BrandRepository.watchStoresByBrand` 보강
  - 근거: `WatchStoresByBrandUseCase` 파일 존재 + `brand_store_management_providers.dart`에 `brandStoresProvider` 구현
  - 위치: `lib/domain/usecases/watch_stores_by_brand_use_case.dart`

- [x] `MenuItemRepository.watchByStore` 시그니처에 `brandId` 파라미터 추가
  - 근거: `lib/domain/repositories/menu_item_repository.dart` line 11 — `watchByStore(String storeId, {String? brandId})`
  - 위치: `lib/domain/repositories/menu_item_repository.dart`

- [x] BrandScaffold 4탭화 — "매장" 탭 (인덱스 2) 추가, "더보기" 인덱스 3으로 이동
  - 근거: `brand_scaffold.dart` line 24–110, `BrandStoresPage` 인덱스 2 삽입 확인
  - 위치: `lib/presentation/brand/brand_scaffold.dart`

- [x] Brand 모듈 신규 화면 파일 존재 — 9개 화면 확인
  - 근거: `brand_stores_page.dart`, `brand_store_form_page.dart`, `brand_store_customization_page.dart`, `brand_price_override_list_page.dart`, `brand_price_override_form_page.dart`, `brand_store_only_menu_list_page.dart`, `brand_store_only_menu_form_page.dart`, `brand_approval_tracking_page.dart`, `brand_more_page.dart` 모두 존재
  - 위치: `lib/presentation/brand/`

- [x] Admin 모듈 신규 화면 파일 존재 — 5개 신규 확인
  - 근거: `admin_pending_menu_overrides_page.dart`, `admin_menu_override_approval_detail_page.dart`, `admin_pending_brand_store_items_page.dart`, `admin_brand_store_item_approval_detail_page.dart`, `admin_brand_store_management_page.dart` 모두 존재
  - 위치: `lib/presentation/admin/`

- [x] `AdminStoreApprovalDetailPage` — 브랜드 매장 approved + CTA `'이 매장 메뉴 관리'` 노출
  - 근거: line 219–251에서 `store.status == approved && store.brandId != null` 조건으로 `OutlinedButton.icon` + `'이 매장 메뉴 관리'` + `AdminBrandStoreManagementPage` push 구현됨
  - 위치: `lib/presentation/admin/approval/admin_store_approval_detail_page.dart`

- [x] `OwnerMyStorePage` — 브랜드 매장 `'매장 정보 수정'` 버튼 비노출
  - 근거: `_BrandStoreActionButtons`에 `StoreCoreFormPage` 진입 버튼 없음. `'운영 정보 수정'` 버튼만 전체 너비 표시
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart` line 1019–1060

- [x] `OwnerMyStorePage` — `StoreScopeBadge.brand(brandName)` 헤더에 표시
  - 근거: `_BrandStoreDetailView.build` line 346에서 `StoreScopeBadge.brand(brandName)` 사용
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart`

- [x] `OwnerMyStorePage` — `_BrandStoreInfoBanner`, `_BrandRejectedBanner` 구현
  - 근거: line 925, 960에서 두 위젯 클래스 정의 확인
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart`

- [x] `StoreScopeBadge.brand(brandName)` — `Icons.business_rounded`, `AppColors.primary` 톤
  - 근거: `store_scope_badge.dart` line 28–31에서 `Icons.business_rounded`, `AppColors.primary` 확인
  - 위치: `lib/presentation/admin/widgets/store_scope_badge.dart`

- [x] `_mergeForBrandStore` 머지 로직 — excluded/approved 제거, priceOverride/approved 교체, storeOnly append
  - 근거: `menu_item_repository_impl.dart` line 69–104에서 세 단계 머지 구현 확인
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart`

- [x] `MasterMenuOverrideCard` 3상태 미리보기 구현 (approved=취소선→primary, pending=warning, rejected=마스터만)
  - 근거: `master_menu_override_card.dart` line 120–172에서 `approved`/`pending`/`rejected` 분기 구현됨
  - 위치: `lib/presentation/brand/customization/price_override/widgets/master_menu_override_card.dart`

- [x] `BrandApprovalTrackingPage` — 점포 한정 메뉴 트래킹 미구현 명시
  - 근거: 파일 주석 `'(점포 한정 메뉴 트래킹은 후속 phase 예정)'` 명시. implementation.md 보류 항목에도 기록
  - 위치: `lib/presentation/brand/approval_tracking/brand_approval_tracking_page.dart`

- [x] `BrandMorePage` — `BrandApprovalTrackingPage` 진입점 구현
  - 근거: `brand_more_page.dart` line 4 import, line 35 push 구현
  - 위치: `lib/presentation/brand/more/brand_more_page.dart`

- [x] `dev_seed_trigger.dart` 다이얼로그 문구 갱신 확인
  - 근거: `'브랜드 1개 + 마스터 메뉴 2개 + 브랜드 매장 1개'` 문구 확인
  - 위치: `lib/dev/seed/dev_seed_trigger.dart`

- [x] `rxdart` pubspec.yaml 추가 — data 레이어 한정 사용
  - 근거: `pubspec.yaml` line 67 `rxdart: ^0.28.0`. presentation/domain에서 rxdart import 없음 (grep 0건)
  - 위치: `pubspec.yaml`, `lib/data/repositories/menu_item_repository_impl.dart`

### 아키텍처 검증

- [x] presentation 레이어 Firebase 직접 import 0건
  - 근거: `grep -r "import 'package:cloud_firestore" lib/presentation/` → 0건. `firebase_auth` 1건은 `lib/presentation/customer/auth/auth_provider.dart` — sub-phase 3 이전부터 존재하는 기존 파일 (regression 아님)
  - 위치: 전체 presentation 레이어

- [x] domain 레이어 Firebase import 0건
  - 근거: `grep -r "import 'package:cloud_firestore" lib/domain/` → 0건
  - 위치: 전체 domain 레이어

- [x] rxdart data 레이어 한정 사용
  - 근거: `grep -r "import 'package:rxdart" lib/` → `lib/data/repositories/menu_item_repository_impl.dart` 1건만 존재
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart`

- [x] Repository Interface = domain, Impl = data
  - 근거: `MenuOverrideRepository` → `lib/domain/repositories/`, `MenuOverrideRepositoryImpl` → `lib/data/repositories/`
  - 위치: 각 레이어 확인

### 코드 품질 검증

- [x] sub-phase 3 신규 파일 Color(0x...) 하드코딩 0건
  - 근거: brand/stores, brand/customization, brand/approval_tracking, admin/brand_store_management, admin/approval 신규 파일에서 `Color(0x...)` 미발견. (login_page.dart의 기존 하드코딩은 sub-phase 3 범위 외)
  - 위치: sub-phase 3 신규 화면 파일 전체

- [x] `flutter analyze` 0 issue
  - 근거: `No issues found! (ran in 4.4s)`
  - 위치: 전체 프로젝트

- [x] `flutter test` 4/4 통과
  - 근거: `00:00 +4: All tests passed!`
  - 위치: 전체 테스트

- [x] freezed 코드 생성 완료 (`menu_override_entity.freezed.dart`)
  - 근거: `lib/domain/entities/menu_override_entity.freezed.dart` 파일 존재
  - 위치: `lib/domain/entities/`

---

## FAIL 항목

- [ ] **FAIL-1 — `_StoreCustomizationSection` sub-segment bar 배경 색상 오류**
  - 문제: design spec에서 `_CustomizationSubSegmentBar` container의 `color: AppColors.background`로 명시했으나, 구현에서 `color: AppColors.primaryBright`로 설정됨. sub-segment bar가 primaryBright 색으로 채워져 2-depth 계층 구분이 의도와 다르게 표현됨.
  - 위치: `lib/presentation/admin/approval/admin_approval_queue_page.dart` line 155
  - 확인 방법: `_StoreCustomizationSectionState.build` → `Container` decoration의 `color` 값 확인
  - 제안: `color: AppColors.background`로 수정 (design/admin_module.md line 87 기준)
  - 우선순위: 높음

- [ ] **FAIL-2 — `_SubTab` 활성 텍스트 색상 오류**
  - 문제: design spec에서 sub-segment `_SubTab` 활성 색상을 `AppColors.primaryBright`(텍스트 + 언더라인)로 명시했으나, 구현에서 `AppColors.primary`로 설정됨. design 설계 의도는 `AppColors.primary`(메인 세그먼트)와 `AppColors.primaryBright`(sub-segment)를 다른 색으로 구분해 2-depth 계층을 시각화하는 것.
  - 위치: `lib/presentation/admin/approval/admin_approval_queue_page.dart` line 214 (텍스트 색), line 222 (언더라인 색)
  - 확인 방법: `_SubTab.build`의 `TextStyle.color`와 언더라인 `Container.color` 값 확인
  - 제안: `selected ? AppColors.primaryBright : AppColors.textMuted`로 수정 + 언더라인도 `AppColors.primaryBright`로 수정 (design/admin_module.md line 96 기준)
  - 우선순위: 높음

- [ ] **FAIL-3 — `_mergeForBrandStore` displayOrder 정렬 누락**
  - 문제: spec U8 및 시나리오 #7에서 머지 결과를 `displayOrder` 기준으로 정렬해야 한다고 명시했으나(`spec.md` line 140, 610), `_mergeForBrandStore` 구현에서 정렬 로직이 없음. 결과 리스트가 `[...mergedMaster, ...approvedStoreOnly]`로만 반환됨.
  - 위치: `lib/data/repositories/menu_item_repository_impl.dart` line 69–104
  - 확인 방법: `_mergeForBrandStore` 함수 반환 전 `.sort((a, b) => a.displayOrder.compareTo(b.displayOrder))` 또는 `sorted` 호출 없음
  - 제안: 반환 직전 `result.sort((a, b) => a.displayOrder.compareTo(b.displayOrder))` 추가
  - 우선순위: 중간

- [ ] **FAIL-4 — `AdminStoreApprovalDetailPage` — approved 아닌 브랜드 매장의 `'승인 후 메뉴 관리가 가능합니다'` 안내 미노출**
  - 문제: design/admin_module.md line 464에서 "approved 가 아닌 상태에서는 안내: `'승인 후 메뉴 관리가 가능합니다'` (faded)"로 명시했으나, 구현에서 `approved && brandId != null` 조건 외 케이스(pending/rejected 브랜드 매장)에 대한 안내 문구가 없음.
  - 위치: `lib/presentation/admin/approval/admin_store_approval_detail_page.dart` line 219–256
  - 확인 방법: `store.brandId != null && store.status != approved` 케이스에서 CTA 영역 확인
  - 제안: `store.brandId != null && store.status != approved` 조건 분기를 추가해 `'승인 후 메뉴 관리가 가능합니다'` 텍스트를 `AppColors.textMuted` 색으로 표시
  - 우선순위: 낮음

---

## 보류 항목

- [ ] **보류-1 — `_SegTab` 활성 fontWeight w600 vs 구현 w700**
  - 이유: design/admin_module.md line 40에서 `_SegTab` 선택 시 `w600`으로 명시했으나, 구현에서 `w700` 사용. w700이 시각적으로 더 강조되어 UX에 유리할 수 있으며, 같은 파일 내 AppBar title도 w700이므로 의도적 조정 가능성이 있음. 정책 판단 필요.
  - 필요한 확인: design spec 의도 재확인 (w600 강제 vs 개발자 재량 허용)
  - 후속 작업 제안: designer 확인 후 spec 갱신 또는 구현 수정

- [ ] **보류-2 — provider 파일명 명세 vs 실제 불일치 (통합 구현)**
  - 이유: implementation.md에서 `brand_stores_providers.dart`, `brand_customization_providers.dart`, `brand_approval_tracking_providers.dart`(brand 3개) / `admin_menu_override_approval_providers.dart`, `admin_brand_store_item_approval_providers.dart`(admin 2개) 5개 파일을 명시했으나, 실제로는 `brand_store_management_providers.dart`(brand 통합 1개), `menu_override_providers.dart`, `admin_brand_customization_providers.dart`(admin 2개 다른 이름)로 구현됨. 기능 동작에는 문제 없음.
  - 필요한 확인: 파일명 불일치가 아키텍처 문서화 오류인지, 또는 의도적 통합인지 확인 필요
  - 후속 작업 제안: implementation.md 파일 목록 갱신 또는 파일 분리 (코드 품질 차원)

- [ ] **보류-3 — `CustomizationSegmentInlineTab`, `MasterMenuChipMultiSelect`, `BrandStoreCard` 별도 파일 미분리**
  - 이유: spec에서 `presentation/admin/approval/widgets/customization_segment_inline_tab.dart`, `presentation/brand/widgets/master_menu_chip_multi_select.dart`, `stores/widgets/brand_store_card.dart`를 별도 파일로 명시했으나, 실제로는 각각의 Page 파일 내 private class(`_StoreCustomizationSection`, inline `FilterChip`, `_BrandStoreCard`)로 구현됨. 기능 동작에는 문제 없음.
  - 필요한 확인: 별도 파일 분리 여부가 spec 요구사항의 강제 조건인지 확인
  - 후속 작업 제안: 재사용 필요 시 별도 파일 분리 리팩터링

- [ ] **보류-4 — end-to-end 실기기 검증 미수행**
  - 이유: 정적 코드 검증만 수행. brand 매장 등록 → admin 승인 → customer case B 머지 실제 동작, excluded/priceOverride approved 시 customer 메뉴판 반영, 점포 한정 메뉴 append 등 Firestore 연동 동작은 실기기/에뮬레이터에서 직접 확인 필요
  - 필요한 확인: Firebase 연동 환경에서 시나리오 #1~#7 end-to-end 수행
  - 후속 작업 제안: QA 단계에서 실기기 검증 수행

- [ ] **보류-5 — collectionGroup query Firestore 인덱스 부재 — 런타임 에러 가능성**
  - 이유: U4에 따라 인덱스 정의는 별도 task `firestore_indexes`로 분리됨. 인덱스 누락 시 `menuOverrides.status==pending` 쿼리(AdminPendingMenuOverridesPage)와 `menuItems.scope==store && status==pending` 쿼리(AdminPendingBrandStoreItemsPage)에서 Firestore 런타임 에러 발생 가능
  - 필요한 확인: `firestore.indexes.json` 설정 후 실기기 검증
  - 후속 작업 제안: `firestore_indexes` task 우선 진행

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **FAIL 4건, 보류 5건. FAIL 수정 후 진입 가능.**
- spec 요구사항 U1~U10 전체 구현됨. Clean Architecture 규칙 준수. `flutter analyze` 0 issue / `flutter test` 4/4 통과.
- FAIL은 모두 UI/디자인 레이어 불일치이며 data/domain 레이어 기능은 이상 없음.
- 가장 큰 리스크는 FAIL-3(`displayOrder` 정렬 누락)으로, customer 메뉴 정렬이 spec과 다르게 동작함.

### 재작업 우선순위

1. FAIL-1 + FAIL-2 — sub-segment bar 배경/텍스트 색상 오류
   - 이유: 같은 파일(`admin_approval_queue_page.dart`) 동일 클래스(`_StoreCustomizationSection`, `_SubTab`) 2–3 라인 수정. 디자인 2-depth 계층 시각화 의도가 현재 구현에서 완전히 반전됨. 수정 비용 최소.

2. FAIL-3 — `_mergeForBrandStore` displayOrder 정렬 누락
   - 이유: customer 메뉴 정렬이 `displayOrder` 기준이 아닌 임의 순서로 노출됨. spec 시나리오 #7 완료 기준 직결. 1줄 추가로 해결 가능.

3. FAIL-4 — non-approved 브랜드 매장 메뉴 관리 안내 미노출
   - 이유: 기능 완전성보다 UX 가이드 문구 차원 이슈. 우선순위 낮지만 design spec 위반이므로 수정 권장.

### 후속 task 후보

- `firestore_indexes` — collectionGroup query 인덱스 정의 (보류-5, 런타임 에러 선제 방지)
- `firestore_rules` — brand/owner/admin role별 보안 규칙
- sub-phase 4 — 개인 매장 점주 메뉴 CRUD
- sub-phase 5 — 옵션 비활성 / 품절 토글 (공통)
- `BrandApprovalTrackingPage` 점포 한정 메뉴 트래킹 보강 (sub-phase 4 또는 별도 task)
- `AdminBrandStoreManagementPage` admin 직접 등록 폼 (현재 placeholder SnackBar)

---

## 완료 판단

- [ ] 전체 PASS
- [x] FAIL 있으나 후속 task로 분리 가능 — **FAIL-4(낮음)는 후속 수정 가능. FAIL-1/2/3은 수정 권장 후 진입.**
- [ ] 재작업 필요
