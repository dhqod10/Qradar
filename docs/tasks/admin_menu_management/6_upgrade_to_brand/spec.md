# sub-phase 6 — upgrade_to_brand 기능 명세

> **상태**: APPROVED — architect 보강 완료
>
> **umbrella 단일 진실원**: 데이터 모델 / 결정사항 / 권한 매트릭스 / role 라우팅 / customer 측 머지 규칙 → [`../spec.md`](../spec.md). 본 sub-phase 는 그 결정을 그대로 따른다 — 재서술하지 않는다.
>
> **선행 sub-phase 의 변경**: 본 sub-phase 진입과 함께 sub-phase 1 / 2 / 3 spec 의 일부가 갱신된다. 변경 요약은 [선행 sub-phase 영향](#선행-sub-phase-영향) 섹션 참조.

---

## 개요

- **목적**: `admin_menu_management` 의 여섯 번째 sub-phase. **brand 가입 흐름을 점주 패턴(`UpgradeToOwnerUseCase`) 과 동등하게 재설계**한다. customer 가 더보기 페이지에서 "브랜드로 전환" CTA → 다이얼로그 확인 → 즉시 `role='brand'` 박힘 → BrandScaffold 진입 → 브랜드 마스터 정보 입력 → admin 승인. **점주 매장 등록 폼에 brandKey 입력 필드** 를 추가하여 점주가 직접 자기 매장을 브랜드 가맹점으로 신청할 수 있게 한다 (BrandStoreFormPage 폐기 — brand 가 매장 등록하는 흐름 자체 제거).
- **작업 유형**: 신규 기능 (작음 — 신규 진입점 / UseCase 1종 / brandKey 검증 / 일부 화면 폐기 + 일부 화면 갱신)
- **결정적 비기능 목표**: 점주 패턴 (`UpgradeToOwnerUseCase` + `UpgradeToOwnerSection` + `UpgradeToOwnerDialog`) 그대로 차용 — 새 패턴을 도입하지 않는다. brand 가입 흐름의 일관성으로 운영 / 코드 mental model 단순화.

### 영향 범위

| 레이어 | 영향 |
|---|---|
| 화면 (customer) | (수정) `MorePage` 에 `UpgradeToBrandSection` 추가 (점주 섹션 아래 또는 옆). 새 다이얼로그 `UpgradeToBrandDialog` |
| 화면 (brand) | **변경 없음** — sub-phase 1 의 `BrandScaffold` 진입 흐름 그대로 (role='brand' + brandId 발급 후 진입). 단 brandId 미발급 케이스 ("브랜드 마스터 등록 대기") 의 안내 문구만 보강 (sub-phase 6 의 진입점이 즉시 role 변경하므로 BrandInfoFormPage 진입 전 brandId 가 없는 케이스 발생) |
| 화면 (admin) | (수정) `AdminBrandApprovalDetailPage` — brand 승인 시 brandKey 자동 생성 + Firestore unique 검증 (sub-phase 1 spec 갱신) |
| 화면 (owner) | (수정) `StoreCoreFormPage` — "브랜드 가맹점입니까?" 토글 + brandKey 입력 필드 + 검증 (sub-phase 2 spec 갱신) |
| 화면 (customer 검색) | **변경 없음** — sub-phase 2 의 status 필터 그대로 |
| Domain | (신규) `UpgradeToBrandUseCase` (점주 패턴 차용). (신규) `LookupBrandByKeyUseCase` (brandKey → brandId 매칭). (수정) `BrandEntity` 에 `brandKey: String` 필드 추가 (sub-phase 1 spec 갱신). `BrandRepository` 메서드 보강 (`findByBrandKey`) |
| Data | (수정) `BrandModel` — brandKey 직렬화. `BrandRemoteDataSource` — `findByBrandKey(key)` 추가. `BrandRepositoryImpl.approveBrand` — brandKey 자동 생성 + unique 검증 + 1-2회 재시도 |
| Presentation | (수정) `MorePage` 에 섹션 추가. (신규) `UpgradeToBrandSection`, `UpgradeToBrandDialog`. (수정) `StoreCoreFormPage` — brandKey 토글/입력/검증 |
| 라우팅 | **변경 없음** — sub-phase 1 의 `RoleRouter.brand` 분기 그대로. role 변경 → `currentUserProfileProvider` 자동 감지 → RoleRouter 재진입 |
| 권한 / 환경 설정 | 변경 없음 — Firestore 보안 규칙은 별도 task `firestore_rules` |
| 테스트 | brand 등록 → admin 승인 (brandKey 자동 생성) → 점주가 매장 등록 시 brandKey 입력 → 매칭 → 매장 brandId 박힘 end-to-end 회귀 |

### 비범위

- **brand role 인 사용자가 "다시 customer 로 돌아가기"** — 점주 다운그레이드도 미존재. 본 sub-phase 비범위.
- **brandKey 재발급 / 회전** — 본 sub-phase 비범위. brandKey 는 admin 승인 시점 1회 발급 후 불변. 회전이 필요하면 별도 task.
- **brand 가 brandKey 를 직접 보는 UI** — 본 sub-phase 는 BrandInfoPage 에 brandKey 노출 (read-only) 까지만 포함. 복사 / QR 등의 편의 기능은 비범위.
- **점주 매장 등록 시 brandKey 입력의 다중 brand 매칭** — 본 sub-phase 는 1:1 매칭 (한 brandKey = 한 brandId). N:1 매핑은 후속 phase.
- **BrandStoreFormPage / `submitStoreForApprovalByBrand` / `SubmitStoreByBrandUseCase` 의 폐기 코드** — 본 sub-phase implementation 단계에서 코드 제거. 단 데이터 (이미 등록된 시드 매장) 는 영향 없음 — 점주가 매장 등록한 것과 데이터 구조 동일 (`store.brandId` 박힘).
- **N:1 brand 매핑** — `users/{uid}.brandIds: List<String>` 으로 확장하는 흐름은 본 sub-phase 비범위.
- **Firestore 보안 규칙 / 인덱스** → 별도 task.
- **결제 (Phase 3)**

---

## 의존 phase / 진입 조건

- **의존 phase**: sub-phase 1, 2, 3 모두 완료 (PASS) 후 본 sub-phase 진입.
  - sub-phase 1: `BrandEntity` / `BrandRepository` / `AdminBrandApprovalDetailPage` (brand 승인 시 brandKey 자동 생성 보강 대상)
  - sub-phase 2: `StoreCoreFormPage` / `submitStoreForApproval` (brandKey 토글/입력/검증 보강 대상)
  - sub-phase 3: `BrandStoreFormPage` / `SubmitStoreByBrandUseCase` / `submitStoreForApprovalByBrand` (폐기 대상). `BrandStoresPage` (read-only 갱신 대상)
- **진입 조건**:
  - umbrella `spec.md` APPROVED (완료)
  - sub-phase 1 / 2 / 3 의 `spec.md` / `implementation.md` / `test_report.md` PASS
  - 기존 점주 패턴 (`UpgradeToOwnerUseCase` / `UpgradeToOwnerSection` / `UpgradeToOwnerDialog`) 활성 상태
  - 테스트용 admin 1개 + customer 1개 + 점주 1개 계정

---

## 확정된 결정사항 (sub-phase 한정)

> umbrella 결정 1~12 / A~F / G/H/I/J 와 sub-phase 1 결정 S1~S10, sub-phase 2 결정 T1~T10, sub-phase 3 결정 U1~U10 은 단일 진실원 그대로 따른다. 여기서는 본 sub-phase 한정 결정만 기록한다.

### V1. brandKey 자동 생성 — **`BR-` prefix + 8자리 영문숫자 alphabet 32 (헷갈리는 문자 제외) + admin 승인 시 발급 + Firestore unique 검증 1-2회 재시도**

- **포맷**: `BR-` + 8자리. alphabet = `A-Z` ∪ `0-9` 에서 `0` / `O` / `I` / `1` 제외 → 총 **32 char** (예: `BR-A2B3C4D5`).
- **조합 수**: 32^8 ≈ 1.1조. 매우 큼. 충돌 확률 사실상 0 (1만 brand 등록까지 충돌 0.000001% 수준).
- **부여 시점**: **admin 이 brand 승인 시** (`AdminBrandApprovalDetailPage` 의 `_approve` 액션 내부). brand 등록 시점 (`upsertBrand`) 에는 발급 X — 반려된 brand 에는 brandKey 박지 않음.
- **충돌 처리**: `Random.secure` 로 키 생성 → `BrandRemoteDataSource.findByBrandKey(key)` 로 unique 검증 → 매칭 doc 있으면 1-2회 재시도. 2회 시도 후에도 충돌 시 `BrandKeyCollisionException` (실제 발생 확률 0).
- **저장**: `brands/{brandId}.brandKey: String` (sub-phase 1 의 `BrandEntity` 에 신규 필드 추가). `brandKey` 는 status='approved' 박히는 시점에만 채워지고 그 이전에는 빈 문자열 (default).
- **불변성**: 한 번 발급된 brandKey 는 변경 불가. brand 가 핵심 필드 변경 시 status=pending 회귀 (sub-phase 1 의 결정 J/S3) 하지만 brandKey 는 보존.
- **legacy 호환**: 본 sub-phase 진입 전 시드 brand (`phase3_seed_brand_001`) 또는 운영 DB 의 status=approved brand 들은 brandKey 미존재 (default `''`). implementation 단계에서 시드 데이터 갱신 시 명시적으로 brandKey 박는다 (예: `BR-SEED0001`). 운영 DB 도 admin 이 콘솔에서 수동으로 brandKey 박을 수 있음 (마이그레이션 스크립트는 본 phase 비범위).

### V2. UpgradeToBrandUseCase — **점주 패턴(`UpgradeToOwnerUseCase`) 그대로 차용**

- 즉시 `users/{uid}.role = 'brand'` 변경. 검수 게이트 없음. 점주 패턴과 정확히 동등.
- 사용자 결정: "검수 게이트 vs 즉시 변경" 중 즉시 변경 채택 (사용자 결정사항 2).
- 사유:
  - 점주 패턴과 일관성 — 코드/UX mental model 단순.
  - role='brand' 진입 직후 BrandScaffold 의 `BrandInfoFormPage` 가 자동 노출 → 마스터 정보 입력 → admin 승인 게이트 (sub-phase 1 의 흐름 그대로). 즉 검수 게이트는 brand 정보 등록 단계에 살아있음.
  - 사용자가 customer 로 다시 돌아가기는 본 phase 비범위 — 잘못된 가입은 admin 이 직접 데이터 손질.
- 시그니처: `UpgradeToBrandUseCase(UserRepository).call(String uid)` — `_repository.updateRole(uid: uid, role: UserRole.brand)`. 점주 UseCase 와 동일한 시그니처.
- **brandId 시점**: role='brand' 변경 직후에는 `users/{uid}.brandId` 가 null. BrandScaffold 진입 시점에 sub-phase 1 의 `_BrandIdMissingView` 가 자동 노출되어 안내 — 사용자는 직접 BrandInfoFormPage 진입 → 등록 후 admin 승인 시점에 brandId 박힘 (`brands/{brandId}` doc 생성과 함께 `users/{uid}.brandId = brandId` 갱신).

### V2-1. brandId 발급 시점 / users 문서 갱신 흐름 — **brand 정보 등록 시점에 박음**

- 본 sub-phase 의 새 흐름:
  ```text
  customer (role='customer', brandId=null)
    → MorePage [브랜드로 전환] → UpgradeToBrandDialog → 확인
    → UpgradeToBrandUseCase → users/{uid}.role = 'brand', brandId 미박힘
    → RoleRouter 자동 전환 → BrandScaffold 진입 → _BrandIdMissingView (sub-phase 1 산출)
    → "브랜드 마스터 정보 입력" CTA → BrandInfoFormPage (sub-phase 1)
    → 사용자가 정보 입력 후 저장 → UpsertBrandUseCase
    → BrandRepositoryImpl.upsertBrand:
       - 신규 brand doc 생성 (id = Firestore auto-id)
       - status='pending', submittedBy=uid, submittedAt=now
       - brandKey='' (V1 — 승인 시점 발급)
       - **users/{uid}.brandId = newBrandId 동시에 갱신** (batch write)
    → BrandScaffold 가 brandId 인식 → BrandInfoPage 본문 (status=pending 라벨) 노출
  ─── (admin) AdminApprovalQueuePage [브랜드 세그먼트] → AdminBrandApprovalDetailPage
    → 승인 → BrandRepositoryImpl.approveBrand:
       - brandKey 자동 생성 (V1) + unique 검증 1-2회 재시도
       - status='approved', approvedBy/At, brandKey 세팅
    → brand 가 BrandInfoPage 에서 brandKey read-only 노출 (V1 의 후속 UX)
  ```
- 핵심: `users/{uid}.brandId` 는 **brand 정보 등록 시점에 박힘** (sub-phase 1 의 흐름과 일관). admin 콘솔에서 수동 발급 흐름 (umbrella 결정 G — 이전 패턴) 은 본 sub-phase 진입 후 폐기 (admin 이 콘솔에서 수동으로 role='brand' + brandId 박는 케이스 미존재 — 모든 brand 가입은 본 sub-phase 의 진입점 통과).
- `BrandRepositoryImpl.upsertBrand` 의 신규 brand 분기에 `users/{uid}.brandId` 갱신 로직을 추가한다 (sub-phase 1 spec 의 `upsertBrand` 보강).

### V3. 점주 매장 등록 폼의 brandKey 입력 — **토글 + TextField (사용자 결정 4)**

- `StoreCoreFormPage` (sub-phase 2 산출) 에 신규 UI 추가:
  - **"브랜드 가맹점입니까?" 토글** (`SwitchListTile` 또는 `CheckboxListTile`)
  - 토글 ON 시 **brandKey 입력 필드** (TextField) 노출. placeholder: `BR-A1B2C3D4`. 입력 마스크: `BR-` 자동 prefix.
  - 토글 OFF (default): 개인 매장으로 등록. brandKey 입력 필드 미노출.
- 토글 후보 비교:
  - **(a) Switch 토글** — 한 줄에 토글 + 펼쳐지는 입력 필드. 모바일 UX 단순.
  - (b) Radio 버튼 ("개인 매장" vs "브랜드 가맹점") — 명시성 높음. 두 옵션 모두 라벨 노출.
  - (c) 별도 페이지 (StorePage 등록 시작 시 "개인" / "브랜드" 선택 → 분기) — UX 무거움.
- **채택**: **(a) Switch 토글** — 모바일에서 자연스럽고 default 가 "개인 매장" 임이 명확. designer 가 (b) 로 변경할 수 있음 (designer 위임).
- 검증 패턴 (V4 참조).

### V4. brandKey 검증 — **`brands` 컬렉션 query + `where('brandKey','==',input).where('status','==','approved')`**

- 점주가 매장 등록 시 입력한 brandKey 가 정상인지 검증:
  - `BrandRepository.findByBrandKey(key)` 호출 → `brands` 컬렉션에서 매칭 doc 조회.
  - 매칭 O + status=='approved' → `brand` 반환. `store.brandId = brand.id` 자동 박음.
  - 매칭 X 또는 status != 'approved' → "정상 브랜드 키가 아닙니다" 에러 SnackBar (제출 차단).
- 매칭 시점: `StoreCoreFormPage` 의 저장 버튼 onTap 직후 (제출 직전 검증). 입력 중 실시간 검증은 본 sub-phase 비범위 (입력 디바운스 / async UI 추가 비용). designer 가 입력 중 검증을 원하면 후속.
- **검증 후 store.brandId 박힘**: `submitStoreForApproval(store.copyWith(brandId: matchedBrand.id))` 호출. 이후 sub-phase 2 의 흐름 그대로 — status='pending' → admin 승인 → 매장 활성. 매장이 brand 가맹점으로 자동 인식되어 sub-phase 3 의 case B 머지 / brand 측 BrandStoresPage 에 노출.
- **충돌 케이스**: 점주 본인이 brand role 인 경우는 `RoleRouter` 가 OwnerScaffold 진입을 막음 (점주 폼에 들어올 수 없음). brand role 사용자가 자기 brandKey 를 입력하는 케이스는 발생 안 함 (점주 폼은 owner role 만 진입).
- **점주 ownership / brand mastership 의 분리** (사용자 결정사항 5 그대로): 점주가 brandKey 입력해서 매장 등록하면 `store.brandId = brand.id` + `store.ownerId = 점주 uid`. **brand 의 uid 와 점주 uid 는 별개**. 즉 점주는 매장을 운영하고, brand 는 마스터 정보를 보유한다 (분리된 두 사용자). sub-phase 3 의 `OwnerMyStorePage` 의 브랜드 매장 분기 (U9) 가 본 분리를 그대로 살림 — 점주는 운영 필드만 즉시 수정, 핵심 필드는 brand 가 admin 승인 게이트로 변경.

### V5. BrandStoreFormPage / `submitStoreForApprovalByBrand` / `SubmitStoreByBrandUseCase` 폐기 (사용자 결정사항 4)

- 본 sub-phase 진입과 함께 **brand 가 매장 등록하는 흐름 자체 제거**. 매장 등록은 항상 점주가 함 (개인 매장이든 브랜드 매장이든).
- 폐기 대상 (sub-phase 3 spec 의 갱신):
  - `BrandStoreFormPage` (`lib/presentation/brand/stores/brand_store_form_page.dart`) — 파일 삭제.
  - `SubmitStoreByBrandUseCase` (`lib/domain/usecases/submit_store_by_brand_use_case.dart`) — 파일 삭제.
  - `StoreRepository.submitStoreForApprovalByBrand` 메서드 — interface / impl / datasource 모두 삭제.
  - `StoreRemoteDataSource.submitByBrand` — 삭제.
  - `MenuOverrideRepository.seedExclusionsForStore` — 삭제. brand 매장 등록 시점에 미선택 마스터 메뉴를 menuOverrides 에 batch seed 하던 흐름 (U2) 폐기. 점주가 brandKey 입력해서 매장 등록할 때는 모든 마스터 메뉴가 default 활성 (override 없음 = 마스터 그대로). brand 가 특정 마스터 메뉴를 매장에서 빼고 싶으면 sub-phase 3 의 `BrandStoreCustomizationPage` → `BrandPriceOverrideFormPage` 에서 `excluded=true` override 추가 (sub-phase 3 의 흐름 그대로 활용).
  - `BrandStoresPage` 의 매장 등록 FAB / "+" 액션 — 제거 (V6 참조).
  - `BrandStoresProvider` / `brandStoresProviders.dart` 의 `submitStoreForApprovalByBrand` 관련 wiring — 제거.
- 정합성:
  - sub-phase 3 의 시나리오 #1 (brand 매장 등록 → admin 승인 → customer 노출) 은 본 sub-phase 진입 후 점주가 brandKey 입력해서 매장 등록 → admin 승인 → customer 노출 흐름으로 대체.
  - sub-phase 3 의 결정 U2 (`menuOverrides.excluded` seed) 는 본 sub-phase 진입 후 무효화. 점주가 brandKey 입력해서 매장 등록 시점에 menuOverrides 는 만들지 않는다. brand 가 사후에 `BrandStoreCustomizationPage` 에서 직접 excluded 추가.
  - 데이터 호환: 본 sub-phase 진입 전에 BrandStoreFormPage 로 등록된 매장 (시드 데이터 1건 — `phase3_brand_store_001`) 은 그대로 동작 — `store.brandId` 가 박혀 있으므로 sub-phase 3 의 case B 머지가 그대로 적용. 폐기는 신규 등록 진입점만이며, 기존 매장 데이터는 영향 없음.

### V6. brand 의 매장 탭 = 점주 등록 가맹점 read-only + 커스텀 (사용자 결정사항 5)

- `BrandStoresPage` (sub-phase 3 산출) 의 갱신:
  - **매장 등록 FAB / "+" 액션 제거** (V5 — brand 가 매장 등록하지 않음).
  - 매장 리스트는 `BrandRepository.watchStoresByBrand(myBrandId)` 의 결과 read-only 조회. 그대로 유지 (sub-phase 3 의 시그니처 변경 없음).
  - `where('brandId','==',myBrandId).where('status','==','approved')` query 적용. status=pending / rejected 매장도 brand 가 트래킹 가능하도록 segment / filter 추가는 비범위 (단순화). status=approved 만 노출.
  - 카드 onTap → `BrandStoreCustomizationPage` (sub-phase 3 그대로) 진입.
    - 가격 오버라이드 등록/수정 (sub-phase 3 의 흐름 그대로)
    - 점포 한정 메뉴 등록/수정 (sub-phase 3 의 흐름 그대로)
- 핵심: **brand 는 매장을 등록하지 않고, 점주가 등록한 가맹점을 read-only 로 보면서 커스텀(가격 오버라이드 / 점포 한정 메뉴) 만 한다**.

### V7. 시드 데이터 — **본 sub-phase 진입 후 brandKey 시드 1건 추가**

- 시드 brand (`phase3_seed_brand_001`) 에 명시적 brandKey 추가 (예: `BR-SEED0001`). 본 sub-phase implementation 시점에 `lib/dev/seed/phase1_seed_data.dart` 갱신.
- 시드 점주 (sub-phase 3 의 `phase3_brand_store_001` 매장 점주 — 별도 시드 점주 uid) 의 매장은 이미 `store.brandId='phase3_seed_brand_001'` 이 박힌 상태로 시드되어 있으므로 그대로 동작 (재시드 불필요).
- (선택) 본 sub-phase implementation 단계에서 점주 시드를 추가하여 "brandKey 입력 → 매장 등록 → admin 승인 → 매장 활성" end-to-end 회귀를 자동화할 수도 있음 (developer 판단).

### V8. UI 위치 — **`MorePage` 점주 섹션 아래에 brand 섹션 추가**

- `MorePage` (`lib/presentation/customer/more/more_page.dart`) 갱신:
  - 기존 `UpgradeToOwnerSection` 그대로 유지 (점주 가입).
  - 그 아래에 `UpgradeToBrandSection` 신규 섹션 추가 (브랜드 가입).
- 디자인 톤은 designer 가 결정 (점주 섹션과 차별 — 색상 토큰 / 아이콘 / 카피). 잠정안: 점주 섹션과 동등한 카드 패턴 + 다른 아이콘 (`Icons.workspace_premium_outlined` 또는 `Icons.business_rounded`) + 다른 카피 ("브랜드 운영자이신가요?" / "마스터 메뉴를 관리하고 가맹점을 통합 운영하세요").
- `UpgradeToBrandDialog` 도 점주 다이얼로그 (`UpgradeToBrandDialog`) 의 패턴 그대로 차용 — 약관 / 본인 정보 확인 후 즉시 role 변경.

### V9. brand 의 `BrandInfoPage` 에 brandKey read-only 노출 — **승인 후 노출 + "복사" 버튼 (선택)**

- sub-phase 1 의 `BrandInfoPage` 갱신: brand 의 status=approved 일 때 brandKey 를 read-only 카드에 노출 (V1 의 후속 UX).
- 형식: `브랜드 키: BR-A1B2C3D4` + (선택) 복사 버튼. 복사 버튼은 designer 가 결정.
- 사유: 점주가 매장 등록 시 brandKey 를 입력해야 하므로, brand 가 자기 brandKey 를 알고 점주에게 전달할 수 있어야 한다.
- pending / rejected 상태에서는 brandKey 미존재 → 노출 안 함.

### V10. 충돌 / 에러 처리

- brandKey 입력 검증 실패 (매칭 X 또는 status != approved) → SnackBar "정상 브랜드 키가 아닙니다" + 제출 차단.
- brandKey 자동 생성 충돌 (V1 — 1-2회 재시도 후에도 충돌) → admin 화면에서 "브랜드 키 발급 실패. 잠시 후 다시 시도해주세요" SnackBar. 실제 발생 확률 0.
- brand 정보 등록 직후 admin 승인 전 → BrandInfoPage 가 status=pending 라벨 노출. brandKey 미발급 영역은 "관리자 승인 후 발급됩니다" 안내.
- 본 sub-phase 진입 후 시드 brand 갱신 누락 (brandKey 미존재) → BrandInfoPage 에서 "브랜드 키가 없습니다" 안내 + admin 콘솔 수동 발급 가이드 (운영 데이터 임시 호환). 실제로는 V7 의 시드 갱신으로 이 케이스 발생 안 함.

---

## 데이터 모델

### Firestore (umbrella 모델 중 본 sub-phase 가 활성화하는 부분)

```text
brands/{brandId}                                      # sub-phase 1 기존 + 본 sub-phase 추가
  ├─ ... (id, name, logoUrl, description, status, ...)
  └─ brandKey: String                                 # 신규 (V1). default '' (pending/rejected) → 승인 시 'BR-XXXXXXXX'

users/{uid}                                           # sub-phase 1 기존
  ├─ role: 'customer' | 'owner' | 'admin' | 'brand'   # 'brand' 는 본 sub-phase 진입점에서 즉시 변경 (V2)
  └─ brandId?: String                                 # role='brand' 시 brand 정보 등록 후 박힘 (V2-1)

stores/{storeId}                                      # sub-phase 2 기존
  └─ brandId?: String | null                          # 본 sub-phase: 점주가 brandKey 입력해서 매장 등록 시 자동 박힘 (V4)
```

본 sub-phase 가 **추가하지 않는** 컬렉션 / 필드: 없음 (`brands.brandKey` 단 하나만 추가).

### Domain Entity 정의

#### `BrandEntity` 수정 (sub-phase 1 산출 + 본 sub-phase 추가)

기존 필드 + 추가:
- `String brandKey` (default `''`) — `BR-XXXXXXXX` 포맷. status='approved' 일 때만 의미. pending/rejected 면 빈 문자열.

```dart
@freezed
abstract class BrandEntity with _$BrandEntity {
  const factory BrandEntity({
    required String id,
    required String name,
    @Default('') String logoUrl,
    String? description,
    @Default('') String brandKey,                  // 신규 — V1
    @Default(EntityApprovalStatus.pending) EntityApprovalStatus status,
    String? submittedBy,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BrandEntity;
}
```

`UserRole` 변경 없음. 이미 sub-phase 1 에서 `brand` 추가 완료.

### DTO / Model

- `BrandModel` 수정 — `brandKey` 직렬화 추가. `fromFirestore` 누락 시 default `''`. `toFirestore` 는 그대로 직렬화.

---

## 레이어 설계

### Domain

#### Entity (수정)
- `BrandEntity` (`lib/domain/entities/brand_entity.dart`) — `brandKey` 필드 추가
  - `freezed` 재생성 필요 (`dart run build_runner build --delete-conflicting-outputs`)

#### Repository Interface (보강)

`lib/domain/repositories/brand_repository.dart`:

```dart
abstract class BrandRepository {
  // ... (sub-phase 1 / 3 기존 메서드)

  // ─── 신규 (본 sub-phase) ───
  /// brandKey 로 brand 조회. status='approved' 인 brand 만 매칭 (V4).
  /// 미매칭 시 null. 점주 매장 등록 시 brandKey 검증 진입점.
  Future<BrandEntity?> findByBrandKey(String brandKey);
}
```

`UserRepository` (점주 패턴 그대로 — 변경 없음). `UpgradeToBrandUseCase` 가 `updateRole` 호출.

#### UseCase (신규, 2종)

- `UpgradeToBrandUseCase` (`lib/domain/usecases/upgrade_to_brand_use_case.dart`)
  - 시그니처: `UpgradeToBrandUseCase(UserRepository).call(String uid)` → `_repository.updateRole(uid, UserRole.brand)`. 점주 UseCase 와 동일 패턴.
- `LookupBrandByKeyUseCase` (`lib/domain/usecases/lookup_brand_by_key_use_case.dart`)
  - 시그니처: `LookupBrandByKeyUseCase(BrandRepository).call(String brandKey)` → `_repository.findByBrandKey(brandKey)`. `BrandEntity?` 반환.

### Data

#### Model (수정)
- `BrandModel` (`lib/data/models/brand_model.dart`) — `brandKey` 직렬화 추가. fromFirestore 누락 시 default `''`.

#### DataSource (보강)
- `BrandRemoteDataSource` (`lib/data/datasources/remote/brand_remote_data_source.dart`):
  - 신규: `Future<BrandModel?> findByBrandKey(String key)` — `where('brandKey','==',key).where('status','==','approved').limit(1)` query.
  - 신규: `Future<bool> isBrandKeyTaken(String key)` — V1 의 unique 검증용. `where('brandKey','==',key).limit(1).get().docs.isNotEmpty`.

#### Repository Implementation (보강)
- `BrandRepositoryImpl` (`lib/data/repositories/brand_repository_impl.dart`):
  - `approveBrand(brandId, adminUid)` 보강:
    1. `_generateUniqueBrandKey()` 호출 — 32 char alphabet × 8자리 random (V1) → `isBrandKeyTaken` 검증 → 매칭 시 1-2회 재시도 → 최종 unique key 확보 → 충돌 지속 시 `BrandKeyCollisionException`.
    2. partial update: `status='approved'`, `approvedBy/At`, `brandKey=newKey`.
  - `upsertBrand(brand)` 보강 (V2-1):
    - 신규 brand (id 비어 있음) 분기: brand doc 생성 + `users/{currentUid}.brandId = newBrandId` batch write 갱신. 점주 패턴 (`UpgradeToOwnerUseCase` 가 role 만 갱신하던 것) 과 다른 점 — brand 는 brandId 를 brand 정보 등록 시점에 박는다.
    - 기존 brand 수정 분기: 기존 패턴 그대로 (sub-phase 1 의 결정 J 안 (a) 그대로).
  - `findByBrandKey(brandKey)` 위임 (BrandRemoteDataSource).

### Presentation

#### Customer 모듈 갱신 (`presentation/customer/more/`)

```text
presentation/customer/more/
├── more_page.dart                              # (수정) UpgradeToBrandSection 추가
└── widgets/
    ├── upgrade_to_owner_section.dart           # (그대로)
    ├── upgrade_to_owner_dialog.dart            # (그대로)
    ├── upgrade_to_brand_section.dart           # (신규) — UpgradeToBrandSection
    └── upgrade_to_brand_dialog.dart            # (신규) — UpgradeToBrandDialog
```

#### Owner 모듈 갱신 (`presentation/owner/my_store/`)

`StoreCoreFormPage` (`lib/presentation/owner/my_store/store_core_form_page.dart`) 갱신:
- 폼 하단 (또는 적절한 위치) 에 신규 섹션 추가:
  - `SwitchListTile` "브랜드 가맹점입니까?" — `_isBrandFranchise` 상태 (default false)
  - 토글 ON 시 `TextField` "브랜드 키" — `_brandKeyCtrl` (placeholder `BR-A1B2C3D4`)
- `_submit()` 메서드 갱신:
  - `_isBrandFranchise == false` → 기존 동작 (개인 매장으로 등록)
  - `_isBrandFranchise == true` → `LookupBrandByKeyUseCase(brandKey).call()` → 결과:
    - null 또는 status != approved → SnackBar "정상 브랜드 키가 아닙니다" + 제출 중단
    - matched brand → `store.brandId = matchedBrand.id` 박은 뒤 `submitStoreForApproval` 호출 (sub-phase 2 의 흐름 그대로)
- 신규 prop / 의존성: `LookupBrandByKeyUseCase` 를 `ref.read` 로 주입 (Owner provider 에 등록).

#### Brand 모듈 갱신 (`presentation/brand/`)

```text
presentation/brand/
├── brand_scaffold.dart                         # (그대로 — sub-phase 1)
├── brand_info/
│   ├── brand_info_page.dart                    # (수정) brandKey read-only 노출 (V9)
│   └── brand_info_form_page.dart               # (그대로 — sub-phase 1)
├── stores/
│   ├── brand_stores_page.dart                  # (수정) FAB 제거 (V6). read-only + 커스텀 진입
│   ├── brand_store_form_page.dart              # (삭제) — V5
│   └── widgets/
│       └── brand_store_card.dart               # (그대로)
├── customization/                              # (그대로 — sub-phase 3)
├── approval_tracking/                          # (그대로 — sub-phase 3)
├── more/                                       # (그대로 — sub-phase 1)
└── providers/
    ├── brand_di_providers.dart                 # (수정) BrandStoreForm 관련 wiring 제거 (V5)
    ├── brand_stores_providers.dart             # (수정) submitStoreForApprovalByBrand 관련 제거
    └── ... (그대로)
```

#### Admin 모듈 갱신 (`presentation/admin/approval/`)

`AdminBrandApprovalDetailPage` (`lib/presentation/admin/approval/admin_brand_approval_detail_page.dart`) 갱신:
- `_approve()` 메서드 — `ApproveBrandUseCase` 호출은 그대로. brandKey 자동 생성은 RepositoryImpl 단계 (V1) 에서 처리되므로 UI 추가 변경 없음.
- 단, 승인 성공 SnackBar 메시지를 "브랜드를 승인했어요" → "브랜드를 승인했어요. 브랜드 키가 발급되었습니다" 정도로 보강 (선택).
- 충돌 케이스 (BrandKeyCollisionException) 처리 — try-catch 에서 "브랜드 키 발급에 실패했어요. 다시 시도해주세요" SnackBar.

#### 라우팅
- `Navigator.push(MaterialPageRoute)` 패턴 유지 (router.dart 변경 없음)
- `RoleRouter` 변경 없음 — sub-phase 1 의 brand 분기 그대로. role 변경 시 `currentUserProfileProvider` stream 자동 갱신 → RoleRouter 재진입 (점주 패턴 그대로).

#### 공통 위젯
- 신규 위젯 없음 — 기존 `UpgradeToOwnerSection` / `UpgradeToOwnerDialog` 의 패턴 그대로 차용. 토큰 / 파일은 새로 만들되 패턴 동일.

---

## 데이터 흐름 (핵심 시나리오 4개)

### 1. customer → brand 가입 → BrandScaffold 진입 → 마스터 정보 입력 → admin 승인 (brandKey 발급)

```text
MorePage
  → UpgradeToBrandSection [tap]
  → UpgradeToBrandDialog → 약관 / 본인 정보 확인 → 확인
  → UpgradeToBrandUseCase → UserRepository.updateRole(uid, UserRole.brand)
  → users/{uid}.role = 'brand', brandId 미박힘
  → currentUserProfileProvider stream 자동 갱신
  → RoleRouter 자동 전환 → BrandScaffold 진입
  → sub-phase 1 의 _BrandIdMissingView 노출 (brandId=null)
  → "브랜드 마스터 정보 입력" CTA → BrandInfoFormPage (sub-phase 1)
  → 사용자가 정보 입력 후 저장 → UpsertBrandUseCase
  → BrandRepositoryImpl.upsertBrand:
     - 신규 brand doc 생성 (auto-id), status='pending', brandKey=''
     - users/{uid}.brandId = newBrandId batch 갱신 (V2-1)
  → BrandScaffold 가 brandId 인식 → BrandInfoPage (status=pending 라벨)
─── (admin) AdminApprovalQueuePage [브랜드 세그먼트] → AdminBrandApprovalDetailPage
  → 승인 → ApproveBrandUseCase → BrandRepositoryImpl.approveBrand:
     - _generateUniqueBrandKey: random 32×8 → isBrandKeyTaken 검증 → 1-2회 재시도 → unique key (V1)
     - status='approved', approvedBy/At, brandKey='BR-A1B2C3D4'
  → SnackBar "브랜드를 승인했어요. 브랜드 키가 발급되었습니다"
─── (brand) BrandInfoPage 자동 갱신 — status=approved 라벨 + brandKey 'BR-A1B2C3D4' read-only 노출 (V9)
```

### 2. 점주가 자기 매장을 브랜드 가맹점으로 등록 → admin 승인

```text
StoreCoreFormPage (점주, 신규 등록)
  → 매장 정보 입력 (이름 / 주소 / 카테고리 / 사업자번호)
  → "브랜드 가맹점입니까?" 토글 ON → "브랜드 키" 입력 ('BR-A1B2C3D4')
  → 저장 [tap]
  → LookupBrandByKeyUseCase.call('BR-A1B2C3D4')
  → BrandRepositoryImpl.findByBrandKey:
     - brands.where('brandKey','==',key).where('status','==','approved').limit(1)
     - 매칭 → BrandEntity 반환
  → store.brandId = matchedBrand.id 박음
  → SubmitStoreForApprovalUseCase (sub-phase 2)
  → StoreRepositoryImpl.submitStoreForApproval:
     - createStore: status=pending, brandId=matchedBrand.id, submittedBy=uid 강제
     - imageUrl: StorageDataSource.upload (기존 경로)
  → SnackBar "검토 대기 중으로 전환되었습니다"
─── (admin) AdminApprovalQueuePage [매장 세그먼트] → AdminPendingStoresPage
  → StoreScopeBadge.brand(brandName) 노출 (sub-phase 2/3 그대로)
  → AdminStoreApprovalDetailPage → 승인 → status=approved
─── (customer) StoreSearchPage → status='approved' 통과 → 매장 노출
─── (customer) StoreMenuPage → MenuItemRepository.watchByStore(storeId) → store.brandId != null → case B 머지 활성 (sub-phase 3 의 U8)
```

### 3. brandKey 미스매치 → 에러

```text
StoreCoreFormPage (점주)
  → "브랜드 가맹점입니까?" 토글 ON → "브랜드 키" 입력 ('BR-INVALID')
  → 저장 [tap]
  → LookupBrandByKeyUseCase.call('BR-INVALID')
  → BrandRepositoryImpl.findByBrandKey: 매칭 X → null 반환
  → SnackBar "정상 브랜드 키가 아닙니다"
  → 제출 중단 (status / brandId 모두 박지 않음)
```

### 4. brand 가 자기 매장(점주가 등록한 가맹점) 을 read-only 로 보고 커스텀 진입 (V6)

```text
brand role 사용자가 BrandScaffold [매장 탭] 진입
  → BrandStoresPage
  → BrandRepository.watchStoresByBrand(myBrandId)
  → BrandRemoteDataSource: stores.where('brandId','==',myBrandId).where('status','==','approved')
  → 매장 카드 리스트 (read-only)
  → 매장 등록 FAB 없음 (V6)
  → 매장 카드 [tap] → BrandStoreCustomizationPage (sub-phase 3 그대로)
     - 가격 오버라이드 inline 탭 → BrandPriceOverrideFormPage → priceOverride / excluded 입력 → status=pending → admin 승인
     - 점포 한정 메뉴 inline 탭 → BrandStoreOnlyMenuFormPage → 등록 → status=pending → admin 승인
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| brandKey 미스매치 (점주 입력) | SnackBar "정상 브랜드 키가 아닙니다" + 제출 중단 (V4) |
| brandKey 매칭 brand 가 status != approved | 위와 동일 — SnackBar (브랜드가 아직 승인 안 됨) |
| brandKey 자동 생성 충돌 (1-2회 재시도 후) | `BrandKeyCollisionException` → admin 화면 SnackBar "브랜드 키 발급에 실패했어요. 다시 시도해주세요" (실제 발생 확률 0) |
| brand role 변경 후 brandId=null 상태 | sub-phase 1 의 `_BrandIdMissingView` 그대로 — "브랜드 마스터 정보 입력" CTA 노출 |
| upsertBrand 실패 (네트워크) | SnackBar "브랜드 정보 저장에 실패했어요" — role='brand' 는 박혀있어 BrandScaffold 그대로 (재시도 가능) |
| users.brandId 갱신 실패 (V2-1) | brand doc 생성은 성공했으나 user 문서 갱신 실패 — RepositoryImpl 가 transaction / batch 보장 (atomicity). 부분 실패 케이스 없음 |
| 점주가 자기 brandKey 를 입력하는 케이스 | RoleRouter 가 brand role 사용자를 OwnerScaffold 에서 차단 — 발생 안 함 |
| brand 가 같은 매장에 이미 가맹된 경우 점주가 다시 brandKey 입력 | 점주는 매장 1개만 가짐 (Phase 1a 정책 — 1점주 1매장). 가맹 변경은 매장 핵심 필드 수정으로 진입. `StoreCoreFormPage(existing=...)` 에서 brandKey 변경 가능. 변경 시 status=pending 회귀 (sub-phase 2 의 T2) |
| 본 sub-phase 진입 전 brand (brandKey 미존재) | BrandInfoPage 가 "브랜드 키가 없습니다" 안내 — 시드 갱신 (V7) 또는 admin 콘솔 수동 발급 필요 (실제 운영에서는 발생 안 함) |

---

## 작업 분배 판단

### designer 호출 — **권장**

신규 화면이 적음 (UpgradeToBrandSection / UpgradeToBrandDialog — 점주 패턴 그대로 차용. StoreCoreFormPage 의 토글 + brandKey 입력 — 기존 폼에 섹션 추가). 디자인 작업량은 sub-phase 1 / 2 / 3 보다 훨씬 작음.

- 디자인 산출물: `docs/tasks/admin_menu_management/6_upgrade_to_brand/design.md`
- 전달할 사항:
  - `UpgradeToBrandSection` 디자인 — 점주 섹션과 차별 (다른 아이콘 / 카피 / 톤). 점주 섹션 아래 위치
  - `UpgradeToBrandDialog` — 점주 다이얼로그 패턴 그대로
  - `StoreCoreFormPage` 의 "브랜드 가맹점입니까?" 토글 + brandKey 입력 필드 위치 / 톤 (V3)
  - `BrandInfoPage` 의 brandKey read-only 노출 + (선택) 복사 버튼 (V9)
  - `BrandStoresPage` 의 FAB 제거 + read-only 톤 일관성 (V6)
  - 빈 상태 / 로딩 / 에러 UI (sub-phase 1~3 패턴 일관)

### developer 호출

designer 완료 후. 의존 순서: Domain → Data → Presentation.

- 구현 항목: 위 레이어 설계의 모든 파일
- 재사용:
  - 점주 패턴 (`UpgradeToOwnerUseCase` / `UpgradeToOwnerSection` / `UpgradeToOwnerDialog`) 의 모든 코드 패턴
  - sub-phase 1 의 `BrandEntity` / `BrandRepository` / `BrandRemoteDataSource` / `BrandModel` (필드 추가만)
  - sub-phase 2 의 `StoreCoreFormPage` / `submitStoreForApproval`
  - sub-phase 3 의 `BrandStoresPage` (FAB 제거만) / `BrandStoreCustomizationPage` (그대로)
  - 기존 freezed / Riverpod / `Navigator.push(MaterialPageRoute)` 패턴
- 폐기 작업:
  - `BrandStoreFormPage` (`lib/presentation/brand/stores/brand_store_form_page.dart`) 파일 삭제
  - `SubmitStoreByBrandUseCase` (`lib/domain/usecases/submit_store_by_brand_use_case.dart`) 파일 삭제
  - `StoreRepository.submitStoreForApprovalByBrand` 메서드 + `StoreRepositoryImpl` 구현 + `StoreRemoteDataSource.submitByBrand` 모두 삭제
  - `MenuOverrideRepository.seedExclusionsForStore` + `MenuOverrideRemoteDataSource.seedExclusionsForStore` 삭제
  - `BrandStoresPage` 의 FAB / "+" 액션 위젯 / 호출부 삭제
  - 관련 provider wiring 제거
- 시드 데이터 갱신:
  - `lib/dev/seed/phase1_seed_data.dart` 의 시드 brand (`phase3_seed_brand_001`) 에 `brandKey: 'BR-SEED0001'` 추가 (V7)
- 주의할 레이어 규칙:
  - `_generateUniqueBrandKey` 의 `Random.secure()` 는 data 레이어 (`BrandRepositoryImpl`) 에서만 사용
  - `BrandEntity.brandKey` 추가 시 freezed 재생성 + 기존 사용처 무영향 확인 (default '' 로 흡수)
  - `users/{uid}.brandId` 갱신은 `BrandRepositoryImpl.upsertBrand` 의 신규 brand 분기에서 batch write — atomicity 보장
  - `LookupBrandByKeyUseCase` 는 `BrandRepository` 만 의존. 점주 매장 등록 폼이 본 UseCase 를 호출하므로 owner provider 에 등록 필요
- `pubspec.yaml`: 추가 패키지 없음

### tester 호출

developer 완료 후. `test_report.md`. **회귀 검증을 강조** — sub-phase 1 / 2 / 3 / 4 / 5 모두 무영향 확인 필수. 특히 sub-phase 3 의 case B 머지 회귀 (점주가 brandKey 입력해서 등록한 매장이 case B 머지 적용 받는지).

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능 (customer → brand 가입)
- [ ] MorePage 에 UpgradeToBrandSection 노출 (점주 섹션 아래)
- [ ] UpgradeToBrandSection [tap] → UpgradeToBrandDialog 노출 → 확인 → role='brand' 즉시 변경
- [ ] role 변경 후 RoleRouter 자동 전환 → BrandScaffold 진입 → _BrandIdMissingView 노출 (brandId=null)
- [ ] BrandInfoFormPage 진입 → 정보 입력 → 저장 → brand doc 생성 + users.brandId 박힘 + status=pending
- [ ] BrandScaffold 가 brandId 인식 → BrandInfoPage (status=pending 라벨)

### 신규 기능 (admin 승인 + brandKey 자동 발급)
- [ ] AdminBrandApprovalDetailPage [승인] → status=approved + brandKey 자동 발급 (V1)
- [ ] brandKey 포맷: `BR-` + 8자리. alphabet = 32 char (0/O/I/1 제외) 검증
- [ ] brandKey unique 검증 — 두 번째 brand 승인 시도 시 다른 brandKey 발급 (충돌 회피)
- [ ] BrandInfoPage — status=approved 시 brandKey read-only 노출 (V9)
- [ ] (선택) brandKey 복사 버튼 동작

### 신규 기능 (점주 매장 등록 시 brandKey)
- [ ] StoreCoreFormPage — "브랜드 가맹점입니까?" 토글 (default OFF) (V3)
- [ ] 토글 OFF → 기존 동작 (개인 매장 등록, brandId=null)
- [ ] 토글 ON → brandKey 입력 필드 노출
- [ ] brandKey 입력 + 저장 → LookupBrandByKeyUseCase 호출 → 매칭 시 store.brandId 박힘 → status=pending → admin 승인 → customer 노출
- [ ] brandKey 미스매치 → SnackBar "정상 브랜드 키가 아닙니다" + 제출 중단
- [ ] brandKey 매칭 brand 가 status != approved → 위와 동일 (V4)

### 신규 기능 (brand 매장 read-only)
- [ ] BrandStoresPage — 매장 등록 FAB 제거 확인 (V6)
- [ ] BrandStoresPage — `where('brandId','==',myBrandId).where('status','==','approved')` 결과만 노출
- [ ] 매장 카드 [tap] → BrandStoreCustomizationPage 진입 (sub-phase 3 그대로)
- [ ] 가격 오버라이드 / 점포 한정 메뉴 등록 흐름 (sub-phase 3 그대로 동작)

### 폐기 검증
- [ ] BrandStoreFormPage 파일 삭제 확인
- [ ] SubmitStoreByBrandUseCase 파일 삭제 확인
- [ ] StoreRepository.submitStoreForApprovalByBrand 인터페이스 / 구현 / 호출부 모두 삭제 확인
- [ ] MenuOverrideRepository.seedExclusionsForStore 삭제 확인
- [ ] `flutter analyze` 0 issue (orphan import / dead code 없음)

### 회귀 (sub-phase 1, 2, 3, 4, 5 무영향)
- [ ] sub-phase 1 — brand 등록 / 마스터 메뉴 CRUD 동작 그대로 (단 brand 등록 시 V2-1 의 batch users.brandId 갱신 추가됨)
- [ ] sub-phase 1 — admin 승인 큐 (브랜드 / 마스터 메뉴) 동작 그대로 (단 brand 승인 시 brandKey 자동 발급 추가됨)
- [ ] sub-phase 2 — 점주 개인 매장 등록 / 수정 / 재제출 동작 그대로 (토글 OFF 케이스)
- [ ] sub-phase 2 — admin 매장 승인 큐 동작 그대로
- [ ] sub-phase 3 — case B 머지 (시나리오 #7) 동작 그대로 — 점주가 brandKey 입력해서 등록한 매장도 동일하게 머지 적용
- [ ] sub-phase 3 — BrandStoreCustomizationPage / BrandPriceOverrideFormPage / BrandStoreOnlyMenuFormPage 동작 그대로
- [ ] sub-phase 3 — admin 매장 커스텀 승인 큐 동작 그대로
- [ ] sub-phase 4 — 점주 개인 매장 메뉴 CRUD 동작 그대로
- [ ] sub-phase 5 — 옵션 비활성 / 품절 토글 동작 그대로 (개인 / 브랜드 공통)

### 회귀 (Phase 1a/1b/1c, Phase 2, customer 무영향)
- [ ] customer `StoreMenuPage` / `MenuItemDetailPage` / `cart` / 추천 / 즐겨찾기 / 검색 모두 동작 그대로
- [ ] `MenuItemRepository.watchByStore` 시그니처 불변
- [ ] `StoreRepository` 의 customer 측 read 메서드 (`getNearbyStores` 등) 시그니처 불변

### 회귀 (Repository 시그니처)
- [ ] `BrandRepository` — 기존 메서드 시그니처 불변 (`findByBrandKey` 만 추가)
- [ ] `StoreRepository` — `submitStoreForApprovalByBrand` 메서드 삭제 외 모두 시그니처 불변
- [ ] `MenuOverrideRepository` — `seedExclusionsForStore` 메서드 삭제 외 모두 시그니처 불변

### 코드 품질
- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (BrandEntity freezed 재생성)
- [ ] 색상 토큰 — `AppColors` 만 사용, hardcoded `Color(0x...)` 0건
- [ ] CLAUDE.md 절대 규칙 — Firebase 직접 사용은 data 레이어만, presentation/domain 에서 import 0
- [ ] `Random.secure()` 는 data 레이어에서만 사용 (BrandRepositoryImpl)

---

## 선행 sub-phase 영향

본 sub-phase 진입과 함께 다음 sub-phase spec 의 일부가 갱신된다. 각 spec 파일에는 본 sub-phase 와의 관계를 명시한 짧은 주석 / 변경 안내 섹션이 추가된다.

### sub-phase 1 (`1_brand_master/spec.md`) 갱신

- **데이터 모델**: `BrandEntity` 에 `brandKey: String` (default `''`) 필드 추가. `BrandModel` 직렬화 추가.
- **결정 / 흐름 보강**:
  - "결정 G — brand role 신설" 의 "admin 콘솔에서 수동 발급" 항목은 본 sub-phase 진입 후 폐기. 모든 brand 가입은 sub-phase 6 의 진입점 통과.
  - `BrandRepositoryImpl.upsertBrand` 의 신규 brand 분기에 `users/{uid}.brandId = newBrandId` batch 갱신 추가 (V2-1).
  - `BrandRepositoryImpl.approveBrand` 에 brandKey 자동 생성 + unique 검증 + 1-2회 재시도 추가 (V1).
  - `BrandRepository` 에 `findByBrandKey(brandKey)` 메서드 추가.
- **화면**:
  - `BrandInfoPage` — status=approved 시 brandKey read-only 노출 (V9).
  - `AdminBrandApprovalDetailPage` — 승인 시 brandKey 자동 발급 (V1) — UI 변경은 SnackBar 카피 보강만.
- **검증 항목 추가**: 위 V1 / V2-1 / V9 관련 검증.

### sub-phase 2 (`2_store_registration_approval/spec.md`) 갱신

- **결정 T6 보강**: "owner 매장 등록 시 brandId — 점주 폼에 brandId UI 없음. RepositoryImpl 가 자동으로 `null` 박음" 은 본 sub-phase 진입 후 갱신.
  - 점주 폼에 "브랜드 가맹점입니까?" 토글 + brandKey 입력 추가 (V3).
  - 토글 OFF 시 기존 동작 (brandId=null).
  - 토글 ON + brandKey 매칭 → store.brandId 자동 박힘.
- **화면**:
  - `StoreCoreFormPage` — 토글 + brandKey 입력 필드 + `LookupBrandByKeyUseCase` 검증 호출 추가 (V3, V4).
- **검증 항목 추가**: 위 V3 / V4 관련 검증.

### sub-phase 3 (`3_brand_store_customization/spec.md`) 갱신

- **결정 U2 폐기**: "brand 매장 등록 폼의 마스터 메뉴 선택 UI — `menuOverrides.excluded` 필드 활용" 의 batch seed 흐름 폐기 (V5). brand 가 매장 등록하지 않으므로 등록 시점의 batch seed 가 발생하지 않는다. excluded 처리는 brand 가 사후에 `BrandStoreCustomizationPage` 에서 직접 추가.
- **결정 U6 / U7**: 마스터 메뉴 삭제 cascade / 가격 변경 priceOverride 보존 — 본 sub-phase 진입 후 N>0 경로는 점주가 brandKey 입력해서 등록한 매장 + brand 가 사후 추가한 override 가 대상. 기존 시그니처 / 흐름 그대로 유지.
- **시나리오 #1 갱신**: "brand 매장 등록 → admin 승인 → customer 노출" 의 흐름은 점주가 brandKey 입력해서 매장 등록 → admin 승인 → customer 노출 흐름으로 대체 (V5).
- **화면 / 코드 폐기**:
  - `BrandStoreFormPage` 파일 삭제 (V5).
  - `SubmitStoreByBrandUseCase` 파일 삭제.
  - `StoreRepository.submitStoreForApprovalByBrand` / `StoreRepositoryImpl` / `StoreRemoteDataSource.submitByBrand` 삭제.
  - `MenuOverrideRepository.seedExclusionsForStore` / `MenuOverrideRemoteDataSource.seedExclusionsForStore` 삭제.
  - `BrandStoresPage` 의 매장 등록 FAB 제거 (V6).
- **검증 항목 갱신**: U2 의 batch seed 검증 항목 제거. V5 / V6 관련 검증 추가.

> 위 sub-phase 1 / 2 / 3 spec 파일에는 본 sub-phase 진입 시점에 짧은 안내 섹션이 추가된다 (architect 가 본 sub-phase spec 작성과 함께 갱신). 각 spec 의 단일 진실원 원칙은 유지 — 데이터 모델 / 결정사항 / 화면 / 검증 항목은 자기 sub-phase 에 살아 있고, 본 sub-phase 는 그 갱신을 인덱싱한다.

---

## 완료 기준

- [ ] `spec.md` 본 문서 (현재) 확정
- [ ] sub-phase 1 / 2 / 3 spec 의 영향 부분 갱신 확정 (architect — 본 sub-phase 작업 단계)
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] customer → 브랜드 전환 → BrandScaffold 진입 → 마스터 정보 입력 → admin 승인 → brandKey 발급 end-to-end 동작
- [ ] 점주 매장 등록 폼에서 brandKey 입력 → 매칭 → 매장 brandId 자동 박힘 → admin 승인 → customer 노출 end-to-end 동작
- [ ] BrandStoreFormPage / submitStoreForApprovalByBrand / seedExclusionsForStore 모두 폐기 확인
- [ ] BrandStoresPage 매장 등록 FAB 제거 확인
- [ ] sub-phase 1 / 2 / 3 / 4 / 5 회귀 0
- [ ] customer / Phase 1a~2 회귀 0
- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (`BrandEntity` freezed 재생성)
