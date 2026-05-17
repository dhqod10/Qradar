# sub-phase 3 — brand_store_customization 기능 명세

> **상태**: APPROVED — architect 보강 완료
>
> **umbrella 단일 진실원**: 데이터 모델 / 결정사항 (1~12, A~F, G/H/I/J) / 권한 매트릭스 / role 라우팅 / customer 측 머지 규칙 → [`../spec.md`](../spec.md). 본 sub-phase 는 그 결정을 그대로 따른다 — 재서술하지 않는다.
>
> **sub-phase 1 산출물 재사용**: `EntityApprovalStatus` enum / `MenuItemScope` enum / `MenuItemEntity` 확장 필드 / `BrandEntity` / `MasterMenuItemRepository` / `BrandScaffold` 골격 / `ApprovalStatusBadge` / `RejectReasonDialog` / `ApprovalActionsBar` / `AdminScaffold` 의 승인 큐 골격 → [`../1_brand_master/spec.md`](../1_brand_master/spec.md).
>
> **sub-phase 2 산출물 재사용**: `StoreEntity` 의 `brandId` / `status` / 승인 메타 필드 / `StoreScopeBadge` / `submitStoreForApproval` / `updateStoreOperationFields` / customer 측 status 필터 / admin 매장 승인 큐 → [`../2_store_registration_approval/spec.md`](../2_store_registration_approval/spec.md).
>
> **sub-phase 6 영향 (V5 / V6)**: sub-phase 6 진입 후 본 sub-phase 의 다음 항목이 폐기 / 갱신된다. 상세는 [`../6_upgrade_to_brand/spec.md`](../6_upgrade_to_brand/spec.md) 참조.
>
> - **brand 가 매장 등록하는 흐름 자체 폐기** — 매장 등록은 항상 점주가 함 (sub-phase 6 의 V5). 다음 산출물 모두 삭제:
>   - `BrandStoreFormPage` (`lib/presentation/brand/stores/brand_store_form_page.dart`)
>   - `SubmitStoreByBrandUseCase`
>   - `StoreRepository.submitStoreForApprovalByBrand` 인터페이스 / 구현 / `StoreRemoteDataSource.submitByBrand` 모두 삭제
>   - `MenuOverrideRepository.seedExclusionsForStore` / `MenuOverrideRemoteDataSource.seedExclusionsForStore` 삭제
> - **결정 U2 (`menuOverrides.excluded` batch seed) 폐기** — brand 가 매장 등록하지 않으므로 등록 시점의 batch seed 가 발생하지 않는다. excluded 처리는 brand 가 사후에 `BrandStoreCustomizationPage` 에서 직접 추가.
> - **시나리오 #1 ("brand 매장 등록 → admin 승인 → customer 노출") 갱신** — 점주가 `StoreCoreFormPage` 에서 brandKey 입력 → 매장 등록 → admin 승인 → customer 노출 흐름으로 대체 (sub-phase 6 의 V4).
> - **`BrandStoresPage` 갱신** — 매장 등록 FAB / "+" 액션 제거 (sub-phase 6 의 V6). 매장 리스트는 `where('brandId','==',myBrandId).where('status','==','approved')` read-only 조회. 카드 [tap] → `BrandStoreCustomizationPage` 진입 (그대로).
> - **데이터 호환**: sub-phase 6 진입 전에 `BrandStoreFormPage` 로 등록된 매장 (시드 데이터 1건 — `phase3_brand_store_001`) 은 그대로 동작. 폐기는 신규 등록 진입점만이며, 기존 매장 데이터는 영향 없음.
> - **결정 U6 / U7 (cascade / 가격 변경 priceOverride 보존)**: sub-phase 6 진입 후 N>0 경로의 대상이 점주가 brandKey 입력해서 등록한 매장 + brand 가 사후 추가한 override. 기존 시그니처 / 흐름 그대로 유지.
> - **검증 항목**: U2 의 batch seed 검증 항목 제거. sub-phase 6 의 V5 / V6 관련 검증 추가.

---

## 개요

- **목적**: `admin_menu_management` 의 세 번째 sub-phase. **brand 가 자기 brand 의 매장(가맹점)을 운영 단계로 끌어올리는 sub-phase**:
  1. **브랜드 매장의 매장 등록** — 점주↔브랜드 오프라인 협의 후 brand 가 마스터 정보 기반으로 매장 등록 (status=pending) → admin 승인.
  2. **매장 커스텀** — 가격 오버라이드 (`menuOverrides/{masterMenuItemId}.priceOverride`) + 점포 한정 추가 메뉴 (`stores/{storeId}/menuItems` 의 scope=store) 입력. 둘 다 status=pending → admin 승인.
  3. **결정 J 적용** — 브랜드 매장의 운영 필드 (영업시간/사진/전화번호/매장 설명) 는 sub-phase 2 의 `updateStoreOperationFields` 그대로 점주 즉시 권한.
  4. **customer 측 머지 case B 활성화** — `MenuItemRepositoryImpl.watchByStore` 의 brandId != null 분기 (`Rx.combineLatest3` 로 master + override + storeOnly 머지).
- **작업 유형**: 신규 화면 다수 + Domain/Data 모델 확장 (대규모. sub-phase 1 보다 약간 작음)
- **영향 범위**:
  - 화면(brand): `BrandScaffold` 의 "매장" 탭 활성화 + brand 측 매장 리스트/등록폼/매장 커스텀(가격 오버라이드+점포 한정 메뉴)/승인 트래킹 — 약 7화면
  - 화면(admin): `AdminApprovalQueuePage` 의 세그먼트 3탭 → **4탭** 확장 (브랜드/마스터 메뉴/매장/매장 커스텀). 매장 커스텀 세그먼트 내부에서 가격 오버라이드와 점포 한정 메뉴 분기 — 약 4-5화면 + admin 직접 관리 진입점 1개
  - 화면(owner): `OwnerMyStorePage` 가 `store.brandId != null` 분기 — 핵심 필드 read-only, 운영 필드만 수정 가능 (메뉴 관리 진입은 sub-phase 4 / 5 에서 별도)
  - 화면(customer): **변경 없음** — `MenuItemRepository.watchByStore` 시그니처 불변. 내부 머지 case B 활성화만
  - Domain: `MenuOverrideEntity` (신규, freezed). `MenuOverrideRepository` (신규). `BrandRepository.watchStoresByBrand` 보강. `StoreRepository.submitStoreForApprovalByBrand` 보강. UseCase 약 14종 신규
  - Data: `MenuOverrideModel` / `MenuOverrideRemoteDataSource` / `MenuOverrideRepositoryImpl` 신규. `BrandRemoteDataSource.streamStoresByBrand` 보강. `MenuItemRepositoryImpl.watchByStore` 의 case B 분기 활성화 (`Rx.combineLatest3`)
  - Presentation: `presentation/brand/stores/`, `presentation/brand/customization/`, `presentation/brand/approval_tracking/` 트리 신설. `presentation/admin/approval/menu_override_*.dart` 와 `brand_store_item_*.dart` 신규. `OwnerMyStorePage` 갱신
  - 라우팅: 변경 없음 (`Navigator.push(MaterialPageRoute)` 유지)
  - 패키지: `pubspec.yaml` 에 `rxdart` 추가 (data 레이어 한정 — umbrella 결정 9)
  - 테스트: customer / Phase 1a~2 / sub-phase 1 / sub-phase 2 회귀 테스트 필수. **case B 활성화에 따른 customer 측 머지 결과 회귀 검증 강조**

---

## 비범위 (sub-phase 분리 원칙)

- **점주 개인 매장 메뉴 CRUD** → sub-phase 4 (개인 매장만)
- **점주 옵션 비활성 / 품절 토글** → sub-phase 5 (개인/브랜드 공통)
- **마스터 메뉴 자체 CRUD** → sub-phase 1
- **개인 매장 등록 / 매장 등록 승인** → sub-phase 2
- **brand role 발급 UI** → admin 콘솔 수동 (umbrella 결정 G)
- **N:1 brand 매핑** → 본 phase 전체 비범위
- **Firestore 보안 규칙 / collectionGroup query 인덱스 정의** → 별도 task `firestore_rules` / `firestore_indexes`
- **Cloud Functions cascade** → 본 phase 비범위. 본 sub-phase 의 `MasterMenuItemRepository.deleteWithCascade` 는 client batch delete (sub-phase 1 시그니처 그대로 + 본 sub-phase 에서 실제 동작)
- **결제 (Phase 3)**

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - **sub-phase 1 (brand_master)**: brand role / `BrandScaffold` 골격 / 마스터 메뉴 컬렉션 / `EntityApprovalStatus` / `ApprovalStatusBadge` / `RejectReasonDialog` / `ApprovalActionsBar` / `AdminScaffold` 의 승인 큐 골격 / `MenuItemEntity` 의 `scope` / `brandId?` / `tags` / `visible` / `disabledOption*` / `status?` / 승인 메타 필드
  - **sub-phase 2 (store_registration_approval)**: `StoreEntity.brandId` / `status` / 승인 메타 필드 / `StoreModel.fromFirestore` 의 default fallback / `StoreScopeBadge` / `submitStoreForApproval` / `updateStoreOperationFields` / `OwnerMyStorePage` 의 status 라벨 / customer 측 status 필터 / admin 매장 승인 큐
  - sub-phase 1 + 2 모두 완료 (PASS) 후 본 sub-phase 진입.
- **진입 조건**:
  - umbrella `spec.md` APPROVED (완료)
  - sub-phase 1 / sub-phase 2 의 `spec.md` / `implementation.md` / `test_report.md` PASS
  - 테스트용 brand 1개 등록 + admin 승인 완료 + 마스터 메뉴 2~3개 등록 + 승인 완료
  - 테스트용 admin 계정 1개 (sub-phase 1 / 2 에서 이미 사용 중)
  - 시드 매장 또는 admin 이 직접 만든 브랜드 매장 1개 (옵션 — 본 sub-phase implementation 시점에 admin 직접 등록 흐름으로 만들거나, brand 등록 → admin 승인 흐름으로 만들 수 있음)

---

## 확정된 결정사항 (sub-phase 한정)

> umbrella 결정 1~12 / A~F / G/H/I/J 와 sub-phase 1 결정 S1~S10, sub-phase 2 결정 T1~T10 은 단일 진실원 그대로 따른다. 여기서는 본 sub-phase 한정 결정만 기록한다.

### U1. AdminScaffold 세그먼트 탭 수 — **(a) 4탭 채택**

- 후보:
  - (a) **4탭** — 브랜드 / 마스터 메뉴 / 매장 / **매장 커스텀** (커스텀 세그먼트 내부에서 가격 오버라이드 / 점포 한정 메뉴 분기)
  - (b) 5탭 — 브랜드 / 마스터 메뉴 / 매장 / 가격 오버라이드 / 점포 한정 메뉴
- **채택**: **(a) 4탭**. 이유: 모바일 가로 폭 절약. "매장 커스텀" 이라는 의미 분류가 brand/admin 양쪽 멘탈 모델에 자연스러움 (가격 오버라이드와 점포 한정 메뉴는 매장 커스텀의 두 축). 5탭은 세그먼트 컨트롤이 한 화면에 다 안 들어와 가로 스크롤 필요.
- 매장 커스텀 세그먼트의 본문은 내부 inline 탭 바 (sub-phase 1 의 브랜드 폼 패턴) 로 가격 오버라이드 / 점포 한정 메뉴 두 리스트를 분기. pending count 뱃지는 두 리스트 합산.

### U2. brand 매장 등록 폼의 마스터 메뉴 선택 UI — **`menuOverrides.excluded` 필드 활용**

- 매장이 운영할 마스터 메뉴를 multi-select chip 으로 선택. 미선택 메뉴는 매장에서 노출 안 됨 (excluded 효과).
- 후보:
  - (a) `stores/{storeId}` 에 `enabledMasterMenuItemIds: List<String>` 신규 필드 추가
  - (b) `menuOverrides` 의 `excluded` 필드로 표현 — 매장 등록 시 선택 안 한 마스터 메뉴는 자동으로 `excluded=true` override 생성
- **채택**: **(b) `menuOverrides.excluded` 활용**. 이유: 별도 필드를 추가하지 않아 데이터 모델이 단순. customer 측 머지 case B 가 이미 `excluded` 를 처리하므로 추가 분기 불필요. brand 가 매장 등록 후 마스터 메뉴를 추가 선택해도 `excluded=false` 로 토글만 하면 됨.
- 등록 시 동작:
  - brand 가 매장 등록 폼에서 마스터 메뉴 chip 선택 — 미선택 메뉴마다 `menuOverrides/{masterMenuItemId}` 문서를 `excluded=true, status='pending', priceOverride=null` 로 생성 (batch write)
  - 선택된 마스터 메뉴는 `menuOverrides` 문서를 만들지 않음 (마스터 가격 그대로 사용 — customer 머지에서 override 없으면 마스터 그대로)
- **유의**: 마스터 메뉴를 신규 추가했을 때 (sub-phase 1 흐름) 자동으로 모든 가맹점에 노출됨 (override 없음 = 마스터 그대로). 신규 마스터 메뉴를 특정 매장에서 빼고 싶으면 brand 가 매장 커스텀 화면에서 `excluded=true` override 추가.

### U3. 점포 한정 추가 메뉴 vs 가격 오버라이드 entity 통합 여부 — **분리 유지 (umbrella 결정 그대로)**

- 점포 한정 메뉴 = `stores/{storeId}/menuItems` (scope=store, sub-phase 1 에서 정의)
- 가격 오버라이드 = `stores/{storeId}/menuOverrides` (본 sub-phase 신규)
- 둘 다 매장 메뉴 커스텀이지만 **저장 위치 / 의미 / customer 머지 로직** 이 다름:
  - 가격 오버라이드: 마스터 메뉴 doc (`brands/{brandId}/menuItems/{id}`) 의 일부 필드만 매장 단위로 덮어씀. customer 머지 단계에서 `priceOverride.status==approved` 면 `basePrice` 만 교체, `excluded.status==approved` 면 메뉴 자체 제거.
  - 점포 한정 메뉴: 매장 단위 신규 메뉴 doc. customer 머지 단계에서 마스터 결과에 append.
- **채택**: **분리 유지** (umbrella 결정 그대로). 통합하면 머지 로직이 복잡해지고 entity 의 의미가 흐려짐.

### U4. collectionGroup query 인덱스 — **별도 task 분리**

- 본 sub-phase 는 다음 collectionGroup query 를 사용:
  - `menuOverrides` collectionGroup + `status == 'pending'` + `submittedAt desc` (admin 매장 커스텀 승인 큐)
  - `menuItems` collectionGroup + `scope == 'store'` + `status == 'pending'` + `submittedAt desc` (admin 점포 한정 메뉴 승인 큐. sub-phase 1 의 마스터 메뉴 승인 큐와 같은 collectionGroup 이지만 scope 필터 다름)
  - `menuOverrides` collectionGroup + `masterMenuItemId == X` (마스터 메뉴 삭제 시 cascade)
- **채택**: 인덱스 정의는 **별도 task `firestore_indexes`**. 본 sub-phase 는 query 코드만 작성. 인덱스 누락 시 콘솔 안내 로그 + 에러 위젯 (sub-phase 1 의 S4 패턴 동일).

### U5. `MenuOverrideRepositoryImpl` 의 ownership 검증 — **sub-phase 1 의 S6 / sub-phase 2 의 T4 패턴 그대로**

- `currentUidGetter`, `currentRoleGetter`, `currentBrandIdGetter` 콜백을 받음.
- write 진입점 (upsert / approve / reject / delete) 에서 다음 검증:
  - **brand role**: `store.brandId == currentBrandId` 매장의 override 만 조작 가능 (UI 단 본인 brand 매장만 노출 + 방어선)
  - **admin role**: 모든 매장 override 조작 가능 (approve / reject / 직접 등록 진입점)
  - **owner role**: 본 sub-phase 진입점에서 owner 가 `MenuOverrideRepository` 직접 호출하는 경우는 없음. owner 의 옵션 비활성 / 품절 토글은 sub-phase 5 에서 별도 처리.
- 위반 시 `PermissionDeniedException` (UI 단 방어선).

### U6. 마스터 메뉴 삭제 시 cascade 동작 — **sub-phase 1 시그니처 + 본 sub-phase 실제 구현**

- sub-phase 1 의 `MasterMenuItemRepository.deleteWithCascade` 가 시그니처만 정의 + 본 sub-phase N=0 (override 가 아직 없으므로 cascade 대상 0건).
- 본 sub-phase 진입 후 menuOverrides 가 활성화 → cascade 실제 동작 활성화:
  - `cascadeDeleteOverrides(masterMenuItemId)` 가 collectionGroup query 로 모든 매장의 `menuOverrides/{masterMenuItemId}` 조회 → batch delete
- **추가**: admin / brand UI 가 마스터 메뉴 삭제 직전 다이얼로그 — "이 메뉴를 삭제하면 N개 매장의 가격 오버라이드도 삭제됩니다" (`CountStoresUsingPriceOverrideUseCase` 결과 반영. sub-phase 1 의 S8/S9 패턴 그대로). N>0 케이스는 본 sub-phase 진입 후 처음 실현.

### U7. 마스터 가격 변경 시 priceOverride 보존 알림 — **sub-phase 1 시그니처 + 본 sub-phase 실제 구현**

- sub-phase 1 의 `CountStoresUsingPriceOverrideUseCase` 가 시그니처만 정의 + 본 sub-phase N=0.
- 본 sub-phase 진입 후 N>0 가능. brand 가 마스터 메뉴의 basePrice 를 변경할 때 (sub-phase 1 의 핵심 필드 변경 흐름):
  - `BrandMasterMenuFormPage` (sub-phase 1 산출) 가 저장 직전 `CountStoresUsingPriceOverrideUseCase(brandId, masterMenuItemId)` 호출
  - 다이얼로그 — "이 가격 변경은 priceOverride 적용 매장 N개에는 영향 없습니다" (umbrella 결정 B)
  - 확인 → `UpdateMasterMenuItemCoreUseCase` 호출 (sub-phase 1)
  - admin 승인 후 customer 측 머지 단계에서 `priceOverride.status==approved` 인 매장은 마스터 가격 변경에 영향 없음 (priceOverride 가 이긴다).

### U8. customer 측 머지 case B 활성화 — **본 sub-phase 진입 시점에 활성화 + `rxdart` 추가**

- `MenuItemRepositoryImpl.watchByStore` 의 brandId != null 분기 (umbrella case B):
  - sub-phase 1 / sub-phase 2 시점: case B 분기는 시그니처만 있고 빈 stream 반환 (또는 분기 없음 — 시드 매장이 모두 brandId=null)
  - 본 sub-phase 진입 시점: `Rx.combineLatest3(masterMenu, overrides, storeOnly).map(_mergeForBrandStore)` 활성화
- `pubspec.yaml` 에 `rxdart` 추가 (umbrella 결정 9). data 레이어에서만 사용. presentation / domain 에서는 import 금지 (CLAUDE.md 절대 규칙 2 — Firebase / 외부 SDK 직접 사용은 data 레이어만).
- 머지 결과:
  - `brands/{brandId}/menuItems` 의 `status==approved && visible` 마스터 메뉴 → 베이스
  - `stores/{storeId}/menuOverrides` 의 `status==approved && excluded==true` 매장에서 제거. `priceOverride` 는 `status==approved` 면 `basePrice` 교체. `soldOut` / `disabledOption*` 는 status 무관 즉시 적용 (umbrella 데이터 모델 주석 그대로)
  - `stores/{storeId}/menuItems` 의 `scope==store && status==approved && visible` 점포 한정 메뉴 append
  - `displayOrder` 정렬

### U9. brand 매장의 점주 권한 분리 — **sub-phase 2 의 owner 화면을 본 sub-phase 에서 brandId 분기 보강**

- `OwnerMyStorePage` (sub-phase 2 산출) 가 `store.brandId` 분기:
  - **`store.brandId == null` (개인 매장)**: 모든 핵심/운영 권한 (sub-phase 2 그대로 — 매장 정보 수정 + 매장 운영 정보 두 진입점 모두 활성)
  - **`store.brandId != null` (브랜드 매장)**: 핵심 필드 수정 진입점 비노출 (`매장 정보 수정` 버튼 숨김. brand role 만 admin 승인 게이트로 변경 가능). **운영 필드 수정 진입점은 활성** (`매장 운영 정보` 버튼 그대로. `StoreOperationFormPage` 진입 → `updateStoreOperationFields` 호출 → 즉시 반영. umbrella 결정 J — 브랜드 매장도 운영 필드는 점주 즉시)
- 메뉴 관리 진입점은 본 sub-phase 비범위 (sub-phase 4 — 개인 매장만 / sub-phase 5 — 옵션·품절 공통).
- 변경 사항은 `OwnerMyStorePage` 의 build 분기만 추가. RepositoryImpl 단계 (T4) 의 ownership 검증은 그대로 — owner 의 `updateStoreOperationFields` 호출은 본인 매장이면 brandId 무관 통과.

### U10. 시드 데이터 — 브랜드 매장 시드 — **본 sub-phase implementation 에 포함**

- 본 sub-phase 진입 후 시드에 브랜드 매장 1개 추가 권장. 동작 검증 / customer 측 case B 회귀 테스트에 필요.
- 후보:
  - (a) `lib/dev/seed/phase1_seed_data.dart` 에 시드 매장 1개 추가 + 시드 brand 1개 + 시드 마스터 메뉴 2~3개 + 시드 menuOverrides 1~2개 + 시드 점포 한정 메뉴 1개 — 모두 `status='approved'` 박힘
  - (b) admin 직접 등록 흐름 (admin 이 brand 등록 → 마스터 메뉴 등록 → 매장 등록 → 매장 커스텀) 으로 수동 시드
- **채택**: **(a) 시드 데이터 갱신** — 자동화 테스트 / 회귀 검증 / customer 측 case B 동작 즉시 확인 가능. (b) 흐름은 implementation 검증 단계에서 별도로 한 번 진행 (시드 + 수동 양쪽 검증).
- 시드 갱신은 별도 task 로 분리하지 않고 본 sub-phase implementation 에 포함.

---

## 데이터 모델

### Firestore (umbrella 모델 중 본 sub-phase 가 활성화하는 부분)

```text
stores/{storeId}
  ├─ ... (sub-phase 2 기존 필드: brandId?, status, 승인 메타 등)
  │
  ├─ menuItems/{menuItemId}                                 # 매장 직속
  │     # 케이스 1 (brandId == null): 개인 매장 메뉴 — 본 sub-phase 무영향 (sub-phase 4)
  │     # 케이스 2 (brandId != null): 점포 한정 추가 메뉴 — 본 sub-phase 활성화
  │     ├─ scope: 'store' (항상)
  │     ├─ brandId? (브랜드 매장이면 store.brandId 와 동일하게 박힘 — 무결성 가드)
  │     ├─ name, basePrice, optionGroupRefs, mainCategoryCode, subCategoryId?, description
  │     ├─ tags, visible, displayOrder, imageUrl
  │     ├─ disabledOptionGroupIds: List<String>             # sub-phase 5 활성, 본 sub-phase 직렬화 default 만
  │     ├─ disabledOptionItemIds: List<String>              # 동일
  │     ├─ soldOut: bool                                    # sub-phase 5 활성
  │     ├─ status: 'pending'|'approved'|'rejected'          # 본 sub-phase 활성 (브랜드 매장 한정 추가만 의미)
  │     ├─ submittedBy/At, approvedBy/At, rejectedReason
  │     └─ createdAt, updatedAt
  │
  └─ menuOverrides/{masterMenuItemId}                       # 본 sub-phase 신규 활성화 (브랜드 매장 전용)
       ├─ masterMenuItemId (= doc.id)
       ├─ storeId                                           # 무결성용 (collectionGroup query 후 그룹화에 유용)
       ├─ brandId                                           # store.brandId 와 동일 (collectionGroup query 필터)
       ├─ priceOverride?: int                               # null = 마스터 가격 사용
       ├─ excluded: bool (default false)                    # admin/brand: 매장에서 제외
       ├─ soldOut: bool (default false)                     # 점주 토글 (즉시) — sub-phase 5 활성
       ├─ disabledOptionGroupIds: List<String>              # 점주 비활성 (즉시) — sub-phase 5 활성
       ├─ disabledOptionItemIds: List<String>               # 점주 비활성 (즉시) — sub-phase 5 활성
       ├─ status: 'pending'|'approved'|'rejected'           # 본 sub-phase 활성
       ├─ submittedBy/At, approvedBy/At, rejectedReason     # 핵심 필드 (priceOverride/excluded) 변경 시
       ├─ updatedAt
       └─ updatedBy ('admin'|'brand'|'owner')               # 추적용
```

> **menuOverrides 의 status 운용 규칙** (umbrella 결정 H + 결정 J):
> - `priceOverride` / `excluded` 는 **핵심 필드** — 변경 시 `status='pending'` 회귀, brand → admin 승인 게이트
> - `soldOut` / `disabledOption*` 는 **운영 필드** — 점주 즉시 반영, status 무관 (sub-phase 5 활성)
> - status 가 `pending` 인 동안에도 점주의 즉시 토글 (soldOut 등) 은 정상 동작 (status 무관 필드)
> - customer 머지: `status == approved` 일 때만 `priceOverride` / `excluded` 적용. `pending`/`rejected` 면 마스터 가격/노출 유지

### Domain Entity 정의

#### `MenuOverrideEntity` (신규)

```dart
@freezed
abstract class MenuOverrideEntity with _$MenuOverrideEntity {
  const factory MenuOverrideEntity({
    required String masterMenuItemId,         // doc.id (= masterMenuItemId)
    required String storeId,
    required String brandId,                  // 무결성 / collectionGroup query 필터
    int? priceOverride,                       // null = 마스터 가격 사용
    @Default(false) bool excluded,
    @Default(false) bool soldOut,             // sub-phase 5 활성, 본 sub-phase 직렬화 default 만
    @Default(<String>[]) List<String> disabledOptionGroupIds,
    @Default(<String>[]) List<String> disabledOptionItemIds,
    @Default(EntityApprovalStatus.pending) EntityApprovalStatus status,
    String? submittedBy,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedReason,
    String? updatedBy,                        // 'admin'|'brand'|'owner'
    DateTime? updatedAt,
  }) = _MenuOverrideEntity;
}
```

#### `MenuItemEntity` 확장 활성화

sub-phase 1 에서 이미 정의된 필드를 본 sub-phase 가 브랜드 매장 한정 추가 메뉴 케이스에서 실제로 활성화. 추가 필드 없음. 단, `MenuItemModel.fromFirestore` 가 `scope=='store' && brandId != null` 인 경우 `status` 를 not null 로 강제 (개인 매장 메뉴는 nullable 그대로).

### DTO / Model

- `MenuOverrideModel` (신규): `MenuOverrideEntity` 1:1 매핑. `fromFirestore` / `toFirestore`. `Timestamp ↔ DateTime` 변환 (sub-phase 1 헬퍼 재사용).
- `MenuItemModel` 추가 변경 없음 (sub-phase 1 에서 이미 직렬화 정의 완료. 본 sub-phase 는 브랜드 매장 한정 추가 케이스에서 사용만).
- `StoreModel` 추가 변경 없음 (sub-phase 2 에서 이미 brandId / status 정의 완료).

---

## 레이어 설계

### Domain

#### Entity (신규)
- `MenuOverrideEntity` — `lib/domain/entities/menu_override_entity.dart`

#### Repository Interface (신규)

`lib/domain/repositories/menu_override_repository.dart`:

```dart
abstract class MenuOverrideRepository {
  Stream<List<MenuOverrideEntity>> watchByStore(String storeId);
  Stream<List<MenuOverrideEntity>> watchPendingForAdmin();          // collectionGroup query
  Future<MenuOverrideEntity?> getByStoreAndMaster(String storeId, String masterMenuItemId);

  /// 핵심 필드 (priceOverride / excluded) 변경. status='pending' 회귀 + submittedBy/At 갱신 + approvedBy/At 보존.
  /// 운영 필드 (soldOut / disabledOption*) 만 변경하는 메서드는 sub-phase 5 에서 별도 정의.
  Future<void> upsertOverrideCore(MenuOverrideEntity override);

  Future<void> approveOverride(String storeId, String masterMenuItemId, String adminUid);
  Future<void> rejectOverride(String storeId, String masterMenuItemId, String adminUid, String reason);
  Future<void> deleteOverride(String storeId, String masterMenuItemId);

  /// 마스터 메뉴 삭제 cascade (sub-phase 1 의 deleteWithCascade 가 호출). collectionGroup batch delete.
  Future<void> deleteAllForMaster(String masterMenuItemId);

  /// 매장 등록 시 미선택 마스터 메뉴를 일괄 excluded 처리 (U2). batch write.
  Future<void> seedExclusionsForStore({
    required String storeId,
    required String brandId,
    required List<String> excludedMasterMenuItemIds,
  });
}
```

> **운영 필드(soldOut/disabledOption*) 메서드는 sub-phase 5 에서 추가**: 본 sub-phase 는 핵심 필드 (priceOverride/excluded) 흐름만 활성화. soldOut / disabledOption* 의 점주 즉시 토글 메서드는 sub-phase 5 의 spec 에서 보강.

#### Repository Interface (보강)

`lib/domain/repositories/brand_repository.dart`:

```dart
abstract class BrandRepository {
  // ... (sub-phase 1 기존 메서드)

  // ─── 신규 (본 sub-phase) ───
  /// brand 가 운영하는 매장 리스트. UI: BrandStoresPage. brand 본인의 brandId 만 호출 가능.
  Stream<List<StoreEntity>> watchStoresByBrand(String brandId);
}
```

`lib/domain/repositories/store_repository.dart`:

```dart
abstract class StoreRepository {
  // ... (sub-phase 1, 2 기존 메서드)

  // ─── 신규 (본 sub-phase) ───
  /// brand 가 마스터 기반 매장 신규 등록 / 핵심 필드 수정. brandId=현재 brandId 강제, status=pending.
  /// 신규 등록 시 enabledMasterMenuItemIds 를 받아 미선택 마스터 메뉴를 menuOverrides 에 excluded=true 로 batch seed (U2).
  Future<String> submitStoreForApprovalByBrand({
    required StoreEntity store,
    required List<String> enabledMasterMenuItemIds,
  });
}
```

`lib/domain/repositories/master_menu_item_repository.dart`:

```dart
abstract class MasterMenuItemRepository {
  // ... (sub-phase 1 기존 메서드)
  // 본 sub-phase 추가 변경 없음. deleteWithCascade / countStoresUsingPriceOverride 는 sub-phase 1 시그니처 그대로 + 본 sub-phase 에서 실제 동작.
}
```

#### UseCase (신규, 14종)

- 매장 / 매장 등록:
  - `WatchStoresByBrandUseCase` (`watchStoresByBrand`)
  - `SubmitStoreByBrandUseCase` (`submitStoreForApprovalByBrand`)
- 가격 오버라이드 (brand):
  - `WatchMenuOverridesByStoreUseCase`
  - `UpsertMenuOverrideCoreUseCase` (priceOverride / excluded 변경)
  - `DeleteMenuOverrideUseCase`
- 가격 오버라이드 (admin):
  - `WatchPendingMenuOverridesUseCase` (collectionGroup query)
  - `ApproveMenuOverrideUseCase`
  - `RejectMenuOverrideUseCase`
- 점포 한정 추가 메뉴 (brand):
  - `CreateStoreOnlyMenuUseCase` (status=pending)
  - `UpdateStoreOnlyMenuCoreUseCase` (핵심 필드 변경 — sub-phase 1 의 마스터 메뉴 패턴 동일)
  - `UpdateStoreOnlyMenuOperationUseCase` (운영 필드 변경 — 즉시 반영)
  - `DeleteStoreOnlyMenuUseCase`
- 점포 한정 추가 메뉴 (admin):
  - `WatchPendingStoreOnlyMenusUseCase` (collectionGroup query, scope=store + status=pending)
  - `ApproveStoreOnlyMenuUseCase`
  - `RejectStoreOnlyMenuUseCase`

> **참고**: `MenuItemRepository` (sub-phase 1 시점에 brand/store scope 통합) 는 점포 한정 메뉴 CRUD 메서드를 본 sub-phase 가 추가 — `createStoreOnlyMenu`, `updateStoreOnlyMenuCore`, `updateStoreOnlyMenuOperation`, `deleteStoreOnlyMenu`. ownership 검증은 RepositoryImpl 에서 brand role + brandId 일치 가드 (U5 패턴).

### Data

#### Model
- `MenuOverrideModel` — `lib/data/models/menu_override_model.dart` (신규, freezed + json_serializable)

#### DataSource
- `MenuOverrideRemoteDataSource` — `lib/data/datasources/remote/menu_override_remote_data_source.dart` (신규)
  - `streamByStore(storeId)`, `streamPending()` (collectionGroup), `getByStoreAndMaster(storeId, masterMenuItemId)`, `set(storeId, masterMenuItemId, model)`, `update(storeId, masterMenuItemId, partial)`, `delete(storeId, masterMenuItemId)`, `cascadeDeleteByMaster(masterMenuItemId)` (collectionGroup → batch delete)
  - `seedExclusionsForStore(storeId, brandId, excludedIds)` — batch write
- `BrandRemoteDataSource` 보강 — `streamStoresByBrand(brandId)` 추가 (`stores` 컬렉션 query: `where('brandId', isEqualTo, brandId)`)
- `MenuItemRemoteDataSource` 보강 — `streamPendingStoreOnlyMenus()` (collectionGroup, `scope=='store' && status=='pending'`)
- `StoreRemoteDataSource` 보강 — `submitByBrand(storeModel, enabledMasterMenuItemIds)` 진입점 (내부에서 store create + override seed batch)

#### Repository Implementation

- `MenuOverrideRepositoryImpl` — `(MenuOverrideRemoteDataSource, currentUidGetter, currentRoleGetter, currentBrandIdGetter, storeRepository)`. ownership 검증 (U5) + status='pending' 회귀 (핵심 필드 변경 시).
- `MenuItemRepositoryImpl.watchByStore` 의 case B 분기 활성화 (umbrella 결정 9 + U8):
  ```text
  if store.brandId != null:
    masterStream    = brandRemote.streamMenuItems(brandId).where(status==approved && visible)
    overrideStream  = menuOverrideRemote.streamByStore(storeId)
    storeOnlyStream = menuItemRemote.streamByStore(storeId).where(scope==store && status==approved && visible)
    return Rx.combineLatest3(masterStream, overrideStream, storeOnlyStream, _mergeForBrandStore)
  ```
  `_mergeForBrandStore` 함수: 위 데이터 흐름 시나리오 #6 참조 (umbrella 머지 규칙 그대로).
- `BrandRepositoryImpl` 보강 — `watchStoresByBrand` 위임 + ownership 검증 (본인 brandId 만).
- `StoreRepositoryImpl` 보강 — `submitStoreForApprovalByBrand`:
  - role==brand 가드, brandId=currentBrandId 강제, status=pending 강제
  - `StoreRemoteDataSource.submitByBrand` 호출 → store create + 미선택 마스터 메뉴를 `MenuOverrideRemoteDataSource.seedExclusionsForStore` 로 batch seed (U2)
- `MasterMenuItemRepositoryImpl` 보강 — `deleteWithCascade` 가 `MenuOverrideRemoteDataSource.cascadeDeleteByMaster(masterMenuItemId)` 호출 (U6 — sub-phase 1 시그니처 + 본 sub-phase 실제 동작). `countStoresUsingPriceOverride` 가 collectionGroup query 로 실제 개수 반환 (U7 — N>0 가능).

### Presentation

#### Brand 모듈 확장 (`presentation/brand/`)

```text
presentation/brand/
├── brand_scaffold.dart                          # (수정) "매장" 탭 활성화 (sub-phase 1 placeholder → 실제 페이지)
├── brand_info/                                  # (sub-phase 1 그대로)
├── master_menu/                                 # (sub-phase 1 그대로)
├── stores/                                      # (신규 트리)
│   ├── brand_stores_page.dart                   # 매장 리스트 + 등록 FAB
│   ├── brand_store_form_page.dart               # 매장 등록/수정 (마스터 메뉴 multi-select chip 포함)
│   └── widgets/
│       └── brand_store_card.dart                # 매장 카드 (이름/주소/StoreScopeBadge.brand/ApprovalStatusBadge)
├── customization/                               # (신규 트리)
│   ├── brand_store_customization_page.dart      # 매장 선택 후 진입 — inline 탭 (가격 오버라이드 / 점포 한정 메뉴)
│   ├── price_override/
│   │   ├── brand_price_override_list_page.dart  # 마스터 메뉴 + override 머지 리스트 (read-only 카드 + override 액션)
│   │   └── brand_price_override_form_page.dart  # 단일 마스터 메뉴 카드 read-only + priceOverride 입력 + excluded 토글
│   └── store_only_menu/
│       ├── brand_store_only_menu_list_page.dart # 점포 한정 메뉴 리스트 + CRUD 액션 + 복제
│       └── brand_store_only_menu_form_page.dart # 등록/수정/복제(prefill) 통합. 핵심/운영 필드 폼 (sub-phase 1 의 BrandMasterMenuFormPage 패턴)
├── approval_tracking/                           # (신규 트리)
│   └── brand_approval_tracking_page.dart        # 자기 brand 제출분 (매장 / 매장 커스텀 / 점포 한정 메뉴) 의 status 모니터
├── more/                                        # (sub-phase 1 그대로)
└── providers/
    ├── brand_di_providers.dart                  # (수정) MenuOverrideRepository / 신규 UseCase 추가
    ├── brand_stores_providers.dart              # (신규) watchStoresByBrand 등
    ├── brand_customization_providers.dart       # (신규) override + storeOnly menu 통합 providers
    └── brand_approval_tracking_providers.dart   # (신규)
```

#### Admin 모듈 확장 (`presentation/admin/`)

```text
presentation/admin/
├── admin_scaffold.dart                          # (sub-phase 2 골격 그대로 — 승인 큐/더보기 2탭)
├── approval/
│   ├── admin_approval_queue_page.dart           # (수정) 세그먼트 3탭 → 4탭 (브랜드/마스터 메뉴/매장/매장 커스텀, U1)
│   ├── admin_brand_approval_detail_page.dart    # (sub-phase 1)
│   ├── admin_master_menu_approval_detail_page.dart # (sub-phase 1)
│   ├── admin_pending_stores_page.dart           # (sub-phase 2 — brandId 분기로 "개인 매장"/"브랜드 매장" 뱃지 분기)
│   ├── admin_store_approval_detail_page.dart    # (sub-phase 2 — 브랜드 매장 케이스 분기 추가: 브랜드명 + 활성 마스터 메뉴 chip 리스트)
│   ├── admin_pending_menu_overrides_page.dart   # (신규) 매장 커스텀 세그먼트의 가격 오버라이드 본문
│   ├── admin_pending_brand_store_items_page.dart # (신규) 매장 커스텀 세그먼트의 점포 한정 메뉴 본문
│   ├── admin_menu_override_approval_detail_page.dart # (신규) 가격 오버라이드 상세 + 승인/반려
│   ├── admin_brand_store_item_approval_detail_page.dart # (신규) 점포 한정 메뉴 상세 + 승인/반려
│   └── widgets/
│       ├── store_scope_badge.dart               # (sub-phase 2 — brand 케이스 분기 추가: StoreScopeBadge.brand(brandName))
│       └── customization_segment_inline_tab.dart # (신규) 가격 오버라이드 / 점포 한정 메뉴 inline 탭 위젯
├── brand_store_management/                      # (신규 트리 — admin 직접 진입)
│   └── admin_brand_store_management_page.dart   # admin 이 브랜드 매장의 메뉴 관리 직접 진입 (admin 직접 등록 시 status=approved 즉시)
└── providers/
    ├── admin_di_providers.dart                  # (수정) MenuOverrideRepository 등 추가
    ├── admin_brand_approval_providers.dart      # (sub-phase 1)
    ├── admin_master_menu_approval_providers.dart # (sub-phase 1)
    ├── admin_store_approval_providers.dart      # (sub-phase 2)
    ├── admin_menu_override_approval_providers.dart # (신규)
    └── admin_brand_store_item_approval_providers.dart # (신규)
```

#### Owner 모듈 갱신 (`presentation/owner/my_store/`)

`OwnerMyStorePage` (sub-phase 2 산출) 의 build 분기 추가 (U9):

- `store.brandId == null` 시: sub-phase 2 그대로 ("매장 정보 수정" + "매장 운영 정보" 두 진입점)
- `store.brandId != null` 시:
  - "매장 정보 수정" 버튼 비노출 (brand role 만 변경 가능)
  - "매장 운영 정보" 버튼 활성 (점주가 영업시간 / 사진 / 전화 / 설명 / 안내 즉시 변경)
  - 카드에 `StoreScopeBadge.brand(brandName)` 노출 (brand 정보는 `BrandRepository.watchById` 결과 join — 점주가 자기 매장의 brand 정보를 read-only 로 봄)
  - `매장 운영 정보` 진입 시 `StoreOperationFormPage` 그대로 (sub-phase 2 산출). RepositoryImpl 단계 (T4) 의 ownership 검증은 그대로 — owner 의 `updateStoreOperationFields` 호출은 본인 매장이면 brandId 무관 통과.

#### 라우팅

- `Navigator.push(MaterialPageRoute)` 패턴 유지 (router.dart 변경 없음)
- `RoleRouter` 변경 없음 (sub-phase 1 / 2 에서 이미 brand / admin / owner / customer 4분기 완료)

#### 공통 위젯 추가

- `StoreScopeBadge.brand(brandName)` — sub-phase 2 의 `StoreScopeBadge` 에 brand 케이스 추가. 톤은 `.personal()` 과 다르게 설정 (designer 결정).
- `MasterMenuChipMultiSelect` — `BrandStoreFormPage` 의 마스터 메뉴 multi-select chip (재사용 — `presentation/brand/widgets/`)
- `CustomizationSegmentInlineTab` — admin 매장 커스텀 세그먼트의 inline 탭 (재사용 — `presentation/admin/approval/widgets/`)

---

## 데이터 흐름 (핵심 시나리오 7개)

### 1. brand 매장 등록 → admin 승인 → customer 노출

```text
BrandStoresPage [+ 매장 등록 FAB]
  → BrandStoreFormPage(신규 등록)
    - 매장 핵심 필드 입력 (이름/주소/카테고리/사업자번호)
    - 마스터 메뉴 multi-select chip (운영할 메뉴만 선택)
    - 매장 운영 필드 입력 (영업시간/전화번호/사진 — 즉시 권한이지만 등록 시점에는 같이 입력)
  → 저장 → SubmitStoreByBrandUseCase
  → StoreRepositoryImpl.submitStoreForApprovalByBrand:
     - role==brand 가드, brandId=currentBrandId 강제, status=pending 강제
     - StoreRemoteDataSource.submitByBrand:
        - store doc create
        - 미선택 마스터 메뉴 N개 → menuOverrides batch seed (excluded=true, status=pending, priceOverride=null) (U2)
─── (admin) AdminApprovalQueuePage [매장 세그먼트, T5/sub-phase 2 그대로]
  → AdminPendingStoresPage 카드 — StoreScopeBadge.brand(brandName) 분기 (sub-phase 2 의 "개인 매장" → 본 sub-phase 에서 "브랜드 매장: {name}")
  → AdminStoreApprovalDetailPage:
     - 매장 정보 + 활성 마스터 메뉴 chip 리스트 (excluded=false 인 메뉴만)
     - 승인 / 반려 액션
  → ApproveStoreUseCase → status=approved
─── (customer) StoreSearchPage / 추천 / 지도 → status='approved' 통과 → 노출
```

### 2. brand 가격 오버라이드 등록 → admin 승인 → customer 머지 결과 적용

```text
BrandStoresPage → 매장 카드 탭 → BrandStoreCustomizationPage [가격 오버라이드 inline 탭]
  → 마스터 메뉴 카드 (read-only) + override 액션
  → BrandPriceOverrideFormPage (특정 마스터 메뉴 선택)
    - 마스터 메뉴 카드 read-only (이름 / basePrice / 옵션 그룹)
    - priceOverride 입력 (TextField)
    - excluded 토글
  → 저장 → UpsertMenuOverrideCoreUseCase
  → MenuOverrideRepositoryImpl.upsertOverrideCore:
     - ownership 검증 (U5)
     - status=pending 강제 + submittedBy=brandUid + submittedAt=now
     - 기존 status==approved 였으면 approvedBy/At 보존 (수정 대기 라벨)
─── (admin) AdminApprovalQueuePage [매장 커스텀 세그먼트 → 가격 오버라이드 inline 탭, U1]
  → AdminPendingMenuOverridesPage 리스트
  → 카드 탭 → AdminMenuOverrideApprovalDetailPage
     - 매장 정보 + 마스터 메뉴 정보 + 변경 내용 (priceOverride / excluded)
     - 승인 / 반려 액션
  → ApproveMenuOverrideUseCase → status=approved
─── (customer) StoreMenuPage → MenuItemRepository.watchByStore(storeId)
  → MenuItemRepositoryImpl: store.brandId != null → case B 머지 활성 (U8)
  → Rx.combineLatest3(master, overrides, storeOnly) → _mergeForBrandStore
  → 해당 마스터 메뉴: priceOverride 적용 (basePrice 교체) 또는 excluded 면 제거
```

### 3. brand 점포 한정 추가 메뉴 등록 → admin 승인 → customer 머지 append

```text
BrandStoreCustomizationPage [점포 한정 메뉴 inline 탭]
  → BrandStoreOnlyMenuFormPage (등록 모드)
    - 메뉴 핵심 필드 입력 (이름 / basePrice / optionGroupRefs / category / description)
    - 메뉴 운영 필드 입력 (visible / tags / displayOrder / imageUrl)
    - 옵션 그룹은 마스터 그룹 또는 store 그룹 선택 가능 (sub-phase 1 의 S2 와 다름 — 점포 한정 메뉴는 store 그룹도 OK. 다만 store 옵션 그룹 CRUD 는 별도 phase)
  → 저장 → CreateStoreOnlyMenuUseCase
  → MenuItemRepositoryImpl.createStoreOnlyMenu:
     - ownership 검증 (U5 — brand role + store.brandId == currentBrandId)
     - scope='store', brandId=store.brandId, status=pending 강제
     - imageUrl: StorageDataSource.upload (menu_images/store/{storeId}/{newId}/...)
─── (admin) AdminApprovalQueuePage [매장 커스텀 → 점포 한정 메뉴 inline 탭]
  → AdminPendingBrandStoreItemsPage → 카드 탭 → AdminBrandStoreItemApprovalDetailPage
  → 승인 / 반려
─── (customer) case B 머지 → _mergeForBrandStore 의 storeOnlyStream 결과에 append
```

### 4. brand 마스터 메뉴 가격 변경 → admin 승인 → 모든 가맹점 자동 동기화 (priceOverride 보존)

```text
BrandMasterMenuFormPage (sub-phase 1, 수정 모드)
  → basePrice 변경 후 저장
  → CountStoresUsingPriceOverrideUseCase(brandId, masterMenuItemId) (U7)
     - 본 sub-phase 이전: N=0 (override 없음)
     - 본 sub-phase 진입 후: collectionGroup query → 실제 N 반환
  → 다이얼로그 "이 가격 변경은 priceOverride 적용 매장 N개에는 영향 없습니다" (umbrella 결정 B)
  → 확인 → UpdateMasterMenuItemCoreUseCase (sub-phase 1)
  → MasterMenuItemRepositoryImpl.updateMasterMenuItemCore:
     - status=pending 회귀 + submittedBy/At 갱신 + approvedBy/At 보존
─── (admin) AdminMasterMenuApprovalDetailPage → 승인 → status=approved
─── (customer) case B 머지 단계:
   - priceOverride 가 status=approved 인 매장: priceOverride 가 이긴다 (마스터 가격 변경 무영향)
   - priceOverride 가 없거나 status=pending/rejected 인 매장: 마스터 새 basePrice 적용
```

### 5. brand 마스터 메뉴 삭제 → admin 승인 → cascade 로 모든 가맹점 menuOverrides 삭제

```text
BrandMasterMenuListPage (sub-phase 1) [삭제]
  → CountStoresUsingPriceOverrideUseCase → N (실제 cascade 대상)
  → 다이얼로그 "이 메뉴를 삭제하면 N개 매장의 가격 오버라이드도 삭제됩니다" (U6)
  → 확인 → DeleteMasterMenuItemUseCase (sub-phase 1)
  → MasterMenuItemRepositoryImpl.deleteWithCascade:
     - collectionGroup query: stores/*/menuOverrides where masterMenuItemId == id
     - batch: brands/{brandId}/menuItems/{id} delete + 모든 override delete
     - MenuOverrideRemoteDataSource.cascadeDeleteByMaster 호출
─── (customer) case B 머지 단계: 해당 마스터 메뉴 즉시 사라짐 (master stream 에서 빠짐 + override 도 삭제됨)
```

### 6. 점주가 브랜드 매장 진입 → 핵심 필드 read-only / 운영 필드 수정 (결정 J 적용, U9)

```text
OwnerMyStorePage (점주가 자기 브랜드 매장 진입, store.brandId != null)
  → build 분기 (U9):
     - 카드: StoreScopeBadge.brand(brandName) + ApprovalStatusBadge(store.status)
     - 매장 정보 (이름 / 주소) read-only 노출
     - "매장 정보 수정" 버튼 비노출 (brand role 만 변경 가능)
     - "매장 운영 정보" 버튼 활성
  → 점주가 "매장 운영 정보" 버튼 → StoreOperationFormPage (sub-phase 2)
  → 영업시간 / 전화번호 / 사진 / 설명 / 안내 변경 후 저장
  → UpdateStoreOperationFieldsUseCase (sub-phase 2)
  → StoreRepositoryImpl.updateStoreOperationFields:
     - ownership 검증 (T4) — owner 가 본인 매장이면 brandId 무관 통과
     - 핵심 필드 / status / 승인 메타 무변경, 운영 필드 + updatedAt 갱신
  → SnackBar "즉시 반영되었습니다"
─── (customer) case B 머지: 운영 필드는 customer 머지 단계와 무관 (StoreEntity 의 운영 필드는 매장 검색/상세에서 직접 사용. menuItems 머지에 영향 없음)
─── (customer) StoreSearchPage / StoreMenuPage 의 매장 카드 / 헤더에서 영업시간 / 전화 / 사진 즉시 갱신
```

### 7. customer 측 case B 머지 시나리오 (마스터 4 + override 2 + 점포 한정 1 → 노출 4)

```text
브랜드 매장 doc:
  - status=approved, brandId='brand_A'
  - 마스터 메뉴 4개 (M1=4500, M2=5000, M3=5500, M4=6000, 모두 visible=true && status=approved)
  - menuOverrides 2개:
     - M2: priceOverride=4800, status=approved → M2 가격 4800
     - M3: excluded=true, status=approved → M3 제거
  - 점포 한정 메뉴 S1 (scope=store, status=approved, visible=true)

customer StoreMenuPage 진입
  → MenuItemRepository.watchByStore(storeId)
  → MenuItemRepositoryImpl: store.brandId='brand_A' → case B (U8)
  → Rx.combineLatest3:
     - masterStream: [M1, M2, M3, M4] (모두 status=approved && visible)
     - overrideStream: {M2: priceOverride=4800/status=approved, M3: excluded=true/status=approved}
     - storeOnlyStream: [S1] (status=approved && visible)
  → _mergeForBrandStore:
     - M1: override 없음 → as-is (4500)
     - M2: override.priceOverride=4800/status=approved → basePrice=4800 으로 교체
     - M3: override.excluded=true/status=approved → skip
     - M4: override 없음 → as-is (6000)
     - S1: 점포 한정 → append
  → 결과: [M1(4500), M2(4800), M4(6000), S1] — 4개 메뉴
  → displayOrder 정렬
  → MenuItemRepository 가 yield
─── StoreMenuPage 화면 갱신 (변경 없음 — Repository 시그니처 불변, customer 호출부 무영향)
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| brand role 미발급 (admin 콘솔에서 brandId 누락) | sub-phase 1 의 `_BrandIdMissingView` 그대로 노출 |
| brand 가 다른 brand 매장 조작 시도 | `PermissionDeniedException` (U5) → 스낵바 "권한이 없습니다" |
| brand 가 매장의 brandId 와 본인 brandId 가 어긋남 (DB 불일치) | UI 단 노출 차단 (`watchStoresByBrand` 가 본인 brandId 만 stream) + RepositoryImpl 가드 |
| collectionGroup query 인덱스 누락 | 콘솔 안내 로그 + 에러 위젯 (U4 — 인덱스는 별도 task) |
| status 상태 어긋남 (override.status=approved 인데 store.status=rejected) | customer 머지 단계에서 store.status=approved 가 우선 — store 가 rejected 면 빈 리스트 (umbrella 머지 규칙) |
| 마스터 메뉴 삭제 시 cascade 실패 (네트워크 등) | `MasterMenuItemRepositoryImpl.deleteWithCascade` 가 transaction / batch 보장 — 실패 시 마스터 메뉴 자체가 삭제 안 됨 (atomicity). 부분 실패 케이스 없음 |
| Rx.combineLatest3 stream 중 하나가 에러 | `MenuItemRepositoryImpl.watchByStore` 가 try-catch + onErrorReturn(빈 리스트) — customer 화면이 안전하게 빈 메뉴 노출 |
| 시드 매장 (brandId=null, 본 sub-phase 무관) | case A (sub-phase 2 그대로). 본 sub-phase 무영향 |
| 동시 편집 (admin 이 승인 중 brand 가 추가 수정) | 마지막 write 우선 (sub-phase 1 / 2 패턴 동일) |
| 이미지 업로드 실패 | 메뉴/매장 저장 자체를 막고 에러 스낵바 (sub-phase 1 패턴) |
| 인증 만료 | 기존 auth flow (재로그인) |

---

## 작업 분배 판단

### designer 호출 — **권장 (필수)**

신규 화면이 다수 (brand 측 7화면 + admin 측 4-5화면 + 공통 위젯 5-6종). sub-phase 1 / 2 의 디자인 토큰 (`ApprovalStatusBadge`, `StoreScopeBadge`, `RejectReasonDialog`, `ApprovalActionsBar`) 을 그대로 재사용하므로 디자인 작업량은 sub-phase 1 보다 약간 작음.

- 디자인 산출물: `docs/tasks/admin_menu_management/3_brand_store_customization/design.md`
- 전달할 사항:
  - `BrandStoresPage` 매장 카드 디자인 (이름/주소/StoreScopeBadge.brand/ApprovalStatusBadge)
  - `BrandStoreFormPage` 의 마스터 메뉴 multi-select chip 영역 + 매장 핵심/운영 필드 섹션 분리
  - `BrandStoreCustomizationPage` 의 inline 탭 디자인 (가격 오버라이드 / 점포 한정 메뉴)
  - `BrandPriceOverrideFormPage` — 마스터 메뉴 read-only 카드 + priceOverride 입력 + excluded 토글 배치
  - `BrandStoreOnlyMenuFormPage` — sub-phase 1 의 `BrandMasterMenuFormPage` 패턴 일관 (등록/수정/복제 통합 폼)
  - `BrandApprovalTrackingPage` — 자기 brand 제출분 status 모니터 (매장 / 매장 커스텀 / 점포 한정 메뉴 통합 리스트)
  - `AdminApprovalQueuePage` 4탭 세그먼트 디자인 (U1) + 매장 커스텀 inline 탭 본문
  - `AdminMenuOverrideApprovalDetailPage` / `AdminBrandStoreItemApprovalDetailPage` 상세 디자인
  - `OwnerMyStorePage` 의 brandId != null 분기 — "매장 정보 수정" 비노출 / "매장 운영 정보" 활성 + StoreScopeBadge.brand
  - `StoreScopeBadge.brand(brandName)` 톤 (sub-phase 2 의 .personal 과 구별)
  - 빈 상태 / 로딩 / 에러 UI (sub-phase 1 / 2 패턴 일관)

### developer 호출

designer 완료 후. 의존 순서: `pubspec.yaml` (rxdart 추가) → Domain → Data → Presentation.

- 구현 항목: 위 레이어 설계의 모든 파일
- 재사용:
  - sub-phase 1 의 `EntityApprovalStatus`, `MenuItemScope`, `MenuItemEntity`, `BrandRepository`, `MasterMenuItemRepository`, `BrandScaffold`, `ApprovalStatusBadge`, `RejectReasonDialog`, `ApprovalActionsBar`, `MenuImagePicker`, `OptionGroupRefPicker`
  - sub-phase 2 의 `StoreEntity` 확장 필드, `StoreModel.fromFirestore` default, `StoreScopeBadge`, `StoreOperationFormPage`, `OwnerMyStorePage`, customer 측 status 필터, admin 매장 승인 큐, `submitStoreForApproval`, `updateStoreOperationFields`
  - 기존 `StorageDataSource` (이미지 업로드 — 경로만 추가), 기존 freezed / Riverpod / `Navigator.push(MaterialPageRoute)` 패턴
- 주의할 레이어 규칙:
  - `MenuOverrideRepositoryImpl` 의 collectionGroup query — Firebase SDK 직접 사용은 data 레이어에서만 (CLAUDE.md 절대 규칙 2)
  - `Rx.combineLatest3` — `rxdart` 는 data 레이어에서만 import (`MenuItemRepositoryImpl`)
  - `MenuItemEntity` / `StoreEntity` 추가 변경 없음 (sub-phase 1 / 2 에서 이미 정의)
  - 시드 데이터 갱신 (U10) — `lib/dev/seed/phase1_seed_data.dart` 에 시드 brand 1개 + 마스터 메뉴 2~3개 + 매장 1개 + menuOverrides 1~2개 + 점포 한정 메뉴 1개 추가
- `pubspec.yaml`: **`rxdart` 추가** (umbrella 결정 9). 다른 패키지 추가 없음.

### tester 호출

developer 완료 후. `test_report.md`. **회귀 검증을 강조** — Phase 1a/1b/1c, Phase 2, sub-phase 1, sub-phase 2 모두 무영향 확인 필수. customer 측 case B 머지 결과 회귀 시나리오 #7 우선 검증.

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능 (brand)
- [ ] BrandScaffold "매장" 탭 활성화 — 자기 brand 매장 리스트 노출 (다른 brand 매장 미노출, U5)
- [ ] BrandStoreFormPage — 매장 핵심 필드 + 마스터 메뉴 multi-select chip + 운영 필드 입력 + 저장 → status=pending, brandId=현재 brandId 자동 박힘
- [ ] BrandStoreFormPage 등록 시 미선택 마스터 메뉴 → menuOverrides 에 excluded=true 자동 batch seed (U2)
- [ ] BrandStoreCustomizationPage inline 탭 — 가격 오버라이드 / 점포 한정 메뉴 두 리스트 노출
- [ ] BrandPriceOverrideFormPage — priceOverride 입력 / excluded 토글 후 저장 → status=pending
- [ ] BrandStoreOnlyMenuFormPage — 점포 한정 메뉴 등록 (status=pending) / 수정 핵심 필드 (status=pending 회귀) / 수정 운영 필드 (status 보존, 즉시 반영) / 복제 prefill / 삭제
- [ ] BrandApprovalTrackingPage — 자기 brand 제출분 (매장 / 매장 커스텀 / 점포 한정 메뉴) 의 status 모니터링 (pending/approved/rejected 라벨)

### 신규 기능 (admin)
- [ ] AdminApprovalQueuePage 세그먼트 4탭 노출 (브랜드 / 마스터 메뉴 / 매장 / 매장 커스텀, U1)
- [ ] 매장 커스텀 세그먼트 inline 탭 — 가격 오버라이드 / 점포 한정 메뉴 본문 분기
- [ ] AdminPendingMenuOverridesPage — collectionGroup query 로 전 매장의 pending override 노출
- [ ] AdminMenuOverrideApprovalDetailPage — 매장/마스터 메뉴/변경 내용 표시 + 승인/반려
- [ ] AdminPendingBrandStoreItemsPage — collectionGroup query 로 전 매장의 pending 점포 한정 메뉴 노출
- [ ] AdminBrandStoreItemApprovalDetailPage — 승인/반려
- [ ] AdminPendingStoresPage — 브랜드 매장 케이스 카드에 StoreScopeBadge.brand(brandName) 노출
- [ ] admin 직접 진입 — `AdminBrandStoreManagementPage` 에서 매장 커스텀 등록 시 status=approved 즉시 반영

### 신규 기능 (owner — 결정 J 적용, U9)
- [ ] 점주가 본인 브랜드 매장 진입 — "매장 정보 수정" 버튼 비노출 (핵심 필드 read-only)
- [ ] 점주가 본인 브랜드 매장 진입 — "매장 운영 정보" 버튼 활성, 영업시간 / 전화 / 사진 / 설명 / 안내 변경 즉시 반영 (status 보존)
- [ ] 점주가 본인 개인 매장 진입 — sub-phase 2 그대로 (분기 회귀)
- [ ] OwnerMyStorePage 의 카드에 StoreScopeBadge.brand(brandName) 노출

### 신규 기능 (customer — case B 머지 활성화, U8)
- [ ] customer StoreMenuPage — 시나리오 #7 검증 (마스터 4 + override 2 + 점포 한정 1 → 노출 4)
- [ ] priceOverride.status=approved 매장에서 마스터 가격 변경 시 priceOverride 가 이김 (umbrella 결정 B)
- [ ] excluded.status=approved 매장에서 해당 마스터 메뉴 미노출
- [ ] 점포 한정 메뉴 status=approved 매장 메뉴에 append
- [ ] override.status=pending/rejected 시 마스터 가격/노출 그대로 유지 (override 미적용)
- [ ] master 또는 storeOnly 메뉴 visible=false 면 노출 X
- [ ] master 메뉴 status=rejected 면 노출 X

### 회귀 (sub-phase 1, 2 무영향)
- [ ] sub-phase 1 의 brand / 마스터 메뉴 / 더보기 탭 동작 그대로
- [ ] sub-phase 1 의 admin 승인 큐 (브랜드 / 마스터 메뉴) 동작 그대로
- [ ] sub-phase 2 의 점주 개인 매장 등록 / 수정 / 재제출 흐름 동작 그대로
- [ ] sub-phase 2 의 admin 매장 승인 큐 — 브랜드 매장 케이스 추가 후에도 개인 매장 승인 동작 그대로

### 회귀 (Phase 1a/1b/1c, Phase 2, customer 무영향)
- [ ] customer `StoreMenuPage` / `MenuItemDetailPage` / `cart` 시그니처 무변경 + 시드 매장 (brandId=null) 머지 case A 동작 그대로
- [ ] `MenuItemRepository.watchByStore` 시그니처 불변
- [ ] Phase 2 추천 / Phase 1c 즐겨찾기 호출부 변경 없음 + 동작 그대로

### 회귀 (Repository 시그니처)
- [ ] `MenuItemRepository.watchByStore` 시그니처 불변
- [ ] `BrandRepository` / `StoreRepository` / `MasterMenuItemRepository` 의 sub-phase 1, 2 메서드 시그니처 불변 (보강만, 기존 메서드 변경 없음)

### 코드 품질
- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (`MenuOverrideEntity` / `MenuOverrideModel` freezed 재생성)
- [ ] 색상 토큰 — `AppColors` 만 사용, hardcoded `Color(0x...)` 0건
- [ ] `pubspec.yaml` — `rxdart` 추가 확인 (data 레이어 외 import 0)
- [ ] CLAUDE.md 절대 규칙 — Firebase / rxdart 직접 사용은 data 레이어만, presentation/domain 에서 import 0

---

## 완료 기준

- [ ] `spec.md` 본 문서 (현재) 확정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] BrandScaffold "매장" 탭 활성화 + 매장 등록 / 매장 커스텀 / 승인 트래킹 동작
- [ ] brand 매장 등록 → admin 승인 → status=approved → customer 검색 노출 end-to-end
- [ ] 가격 오버라이드 등록 → admin 승인 → customer 매장 메뉴 가격 반영 end-to-end (시나리오 #2)
- [ ] excluded → customer 메뉴에서 사라짐 (시나리오 #7)
- [ ] 점포 한정 추가 메뉴 등록 → admin 승인 → customer 메뉴 노출 end-to-end (시나리오 #3)
- [ ] 마스터 가격 변경 시 priceOverride 적용 매장은 보존 (시나리오 #4 — sub-phase 1 의 알림 다이얼로그 + 본 phase 데이터 검증)
- [ ] 마스터 메뉴 삭제 cascade 실제 동작 (시나리오 #5 — sub-phase 1 시그니처 + 본 sub-phase 실제 동작)
- [ ] 점주가 브랜드 매장 진입 시 핵심 필드 read-only / 운영 필드 즉시 반영 (시나리오 #6, U9, 결정 J)
- [ ] customer 측 case B 머지 (시나리오 #7) 회귀 0
- [ ] customer / Phase 1a~2 / sub-phase 1, 2 회귀 0
- [ ] `flutter analyze` 0 issue
- [ ] `pubspec.yaml` 에 `rxdart` 추가
