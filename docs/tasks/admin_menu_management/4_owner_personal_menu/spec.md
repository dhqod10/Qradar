# sub-phase 4 — owner_personal_menu 기능 명세

> **상태**: APPROVED — architect 보강 완료
>
> **umbrella 단일 진실원**: 데이터 모델 / 결정사항 (1~12, A~F, G/H/I/J) / 권한 매트릭스 / role 라우팅 / customer 측 머지 규칙 → [`../spec.md`](../spec.md). 본 sub-phase 는 그 결정을 그대로 따른다 — 재서술하지 않는다.
>
> **sub-phase 1 산출물 재사용**: `MenuItemEntity` 확장 필드 (`scope`/`brandId?`/`tags`/`visible`/`disabledOption*`/`status?`/승인 메타) / `MenuItemScope` enum / `EntityApprovalStatus` enum / `MenuItemRepository.createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `updateStoreOnlyMenuOperation` / `deleteStoreOnlyMenu` / `MenuItemRemoteDataSource.streamByStore` / `StorageDataSource` / 공통 위젯 (`ImageUploadField`, `TagChipsSelector`, `VisibilityToggle`, `OptionGroupSelector`) → [`../1_brand_master/spec.md`](../1_brand_master/spec.md), [`../1_brand_master/implementation.md`](../1_brand_master/implementation.md).
>
> **sub-phase 2 산출물 재사용**: `StoreEntity.brandId` / `status` / 승인 메타 / `OwnerMyStorePage` 구조 / `StoreRepository.watchByOwner` / customer 측 status 필터 → [`../2_store_registration_approval/spec.md`](../2_store_registration_approval/spec.md).
>
> **sub-phase 3 무관**: 본 sub-phase 는 brand 매장이 아닌 **개인 매장(brandId==null)** 만 다룬다. 단 `MenuItemRepositoryImpl.watchByStore` 의 case A 분기 (sub-phase 3 에서 활성화된 머지 로직 중 개인 매장 분기) 는 본 sub-phase 가 점주 변경 → customer 즉시 반영의 회귀 무영향을 보증해야 한다.

---

## 개요

- **목적**: `admin_menu_management` 의 네 번째 sub-phase. **`store.brandId == null` 인 개인 매장 점주의 메뉴 CRUD — admin 승인 게이트 없음, customer 즉시 반영** (umbrella 권한 매트릭스 결정 I + 결정 H 의 "개인 매장 메뉴는 status 미사용 또는 default `approved`").
- **작업 유형**: 기존 sub-phase 1 의 점포 한정 메뉴 메서드(`createStoreOnlyMenu` 외 3종) 를 **개인 매장 케이스로 재활용** + Owner 모듈에 메뉴 관리 화면 트리 신설. brand 매장 점주는 본 sub-phase 진입 자체가 차단된다 (UI + Repository 양쪽 가드).
- **결정적 비기능 목표**: customer 측 Repository 인터페이스 변경 0. `MenuItemRepository.watchByStore(storeId, brandId: null)` 의 case A 분기 (sub-phase 1 / 3 산출) 는 시그니처 / 동작 모두 불변. 본 sub-phase 가 추가하는 Repository 메서드는 모두 write 측이며, 기존 read 시그니처를 건드리지 않는다.
- **영향 범위**:
  - 화면(owner): `OwnerMyStorePage` 의 매장 상세 영역에 "메뉴 관리" 진입 CTA 추가 (`store.brandId == null && store.status == approved` 일 때만 노출). 신규 화면 3종 (`OwnerStoreMenuListPage` / `OwnerStoreMenuFormPage` / `OwnerStoreMenuDetailPage`).
  - 화면(brand / admin / customer): **변경 없음**. brand 매장 점주가 메뉴 관리 진입을 시도해도 UI 단계에서 CTA 비노출, Repository 단에서 `PermissionDeniedException` 안전망.
  - Domain: `MenuItemEntity` 변경 없음 (sub-phase 1 에서 신규 필드 도입 완료). `MenuItemRepository` 시그니처 변경 없음 — 기존 `createStoreOnlyMenu` 외 3종을 **개인 매장 분기 처리** 하는 RepositoryImpl 보강. UseCase 5종 신규 (`CreateOwnerStoreMenuUseCase` 등).
  - Data: `MenuItemRepositoryImpl` 의 `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `updateStoreOnlyMenuOperation` / `deleteStoreOnlyMenu` 가 매장의 `brandId` 를 fetch 해서 분기 — `brandId == null` 이면 `status = approved` 강제 + 승인 메타 모두 null + ownership 검증 (점주 본인 매장만). 기존 brand 매장 (`brandId != null`) 분기는 sub-phase 3 동작 그대로 보존 (status=pending).
  - Presentation: `presentation/owner/store_menu/` 트리 신설 (List / Form / Detail 3 화면 + Provider). `OwnerMyStorePage` 의 매장 상세 영역 갱신.
  - 라우팅: 변경 없음 (`Navigator.push(MaterialPageRoute)` 패턴 유지).
  - 패키지: 추가 없음 (`image_picker` 이미 sub-phase 1 에서 사용 중, `rxdart` 는 sub-phase 3 에서 추가됨).
  - 테스트: customer Phase 1a~2 회귀 / sub-phase 1~3 회귀 강조. 점주 메뉴 변경 → customer 즉시 반영 여부 / brand 매장 메뉴 분기 무영향 / 시드 매장 (`brandId=null`, `status=approved` fallback) 에서 점주 메뉴 등록 흐름 동작.

---

## 범위 / 비범위

### 범위 (본 sub-phase)

#### A. 개인 매장 점주의 메뉴 CRUD — 즉시 반영

- `store.brandId == null` 인 매장의 점주만 진입 가능
- 메뉴 등록/수정/삭제/복제 → **`status = EntityApprovalStatus.approved` 즉시 박힘** (또는 nullable — fromFirestore fallback 으로 `approved` 처리)
- 승인 메타 (`submittedBy/At`, `approvedBy/At`, `rejectedReason`) 모두 null
- admin 승인 게이트 없음 (umbrella 결정 H — 개인 매장 메뉴는 즉시 반영)
- 가격 변경 / 카테고리 변경 / 이름 변경 등 모든 필드 변경 즉시 반영
- 운영 필드 (`visible` / `tags` / `displayOrder` / `imageUrl`) 도 동일하게 즉시 반영 (admin 승인 게이트 없으므로 핵심/운영 분리 의미 적음 — V2 결정)

#### B. 화면 구조 — sub-phase 1 의 마스터 메뉴 화면 패턴 차용

- `OwnerMyStorePage` (sub-phase 2 산출) 의 매장 상세 영역에 **"메뉴 관리" CTA 추가**:
  - 노출 조건: `store.brandId == null && store.status == EntityApprovalStatus.approved` (개인 매장 + 승인 완료)
  - brand 매장 (`store.brandId != null`) 점주는 CTA 비노출 (별도 안내 문구도 노출하지 않음 — 단순화)
  - pending / rejected 상태에서도 CTA 비노출 (메뉴는 매장 승인 후에만 등록 가능)
- `OwnerStoreMenuListPage` (신규) — 개인 매장 메뉴 리스트
  - sub-phase 1 의 `BrandMasterMenuListPage` 구조 재사용 (status 뱃지는 노출하지 않음 — 항상 approved)
  - FAB "메뉴 추가" → `OwnerStoreMenuFormPage(storeId, mode=create)`
  - 메뉴 카드: 이미지 / 이름 / 가격 / `visible` 토글 (인라인) / `tags` 칩 / 정렬 위치
  - 카드 탭 → `OwnerStoreMenuDetailPage`
  - 카드 long-press 또는 메뉴 버튼 → 수정 / 복제 / 삭제 액션 시트
- `OwnerStoreMenuFormPage` (신규) — 메뉴 등록/수정/복제
  - sub-phase 1 의 `BrandMasterMenuFormPage` 구조 재사용 — 단 status 회귀 안내 / Core/Operation 분리 안내 모두 미노출 (즉시 반영이므로)
  - 필드: 이름 / 이미지 (`ImageUploadField`) / 설명 / 메인 카테고리 / 부 카테고리 / `basePrice` / `optionGroupRefs` (`OptionGroupSelector`) / `tags` (`TagChipsSelector`) / `visible` (`VisibilityToggle`) / `displayOrder`
  - 본 sub-phase 폼에서 다루지 않는 필드: `disabledOption*` / `soldOut` (sub-phase 5 에서 활성화. entity default `[]` / `false` 박음)
  - 저장 버튼 → 신규 등록이면 `CreateOwnerStoreMenuUseCase`, 수정이면 `UpdateOwnerStoreMenuUseCase` (Core/Operation 분리 X — V2)
  - SnackBar: "즉시 반영되었습니다" (status 안내 없음)
- `OwnerStoreMenuDetailPage` (신규) — 메뉴 상세 + 액션
  - sub-phase 1 의 `BrandMasterMenuDetailPage` 구조 재사용
  - 표시: 이미지 / 이름 / 가격 / 설명 / 카테고리 / 옵션 그룹 / tags / visible 상태
  - 액션: 수정 / 복제 / 삭제 — 각각 `OwnerStoreMenuFormPage` 진입 또는 다이얼로그 확인 후 삭제

#### C. 데이터 모델

- `MenuItemEntity` (sub-phase 1 에서 확장 완료) 그대로 사용
- 개인 매장 메뉴 doc 의 필드 강제값:
  - `scope: MenuItemScope.store`
  - `brandId: null` (매장의 brandId 가 null 이므로)
  - `status: EntityApprovalStatus.approved` (RepositoryImpl 에서 강제. fromFirestore default 도 approved 이므로 fallback 도 안전)
  - `submittedBy / submittedAt / approvedBy / approvedAt / rejectedReason: null`
  - `disabledOptionGroupIds / disabledOptionItemIds: []` (sub-phase 5 에서 활성화)
  - `soldOut: false` (sub-phase 5 에서 활성화)
- Firestore 컬렉션 경로: `stores/{storeId}/menuItems/{menuItemId}` (Phase 1a 기존 + sub-phase 1 의 점포 한정 메뉴와 동일 컬렉션)

#### D. customer 측 case A 정합 (회귀 보증)

- `MenuItemRepositoryImpl.watchByStore(storeId, brandId: null)` (sub-phase 1/3 의 case A 분기) 는 시그니처 / 동작 불변
- 본 sub-phase 의 점주 변경 (메뉴 등록 / 수정 / 삭제 / visible 토글) 이 customer `StoreMenuPage` 에 즉시 반영 — `streamByStore` 가 Firestore snapshot 을 그대로 흘려보내므로 별도 작업 없이 자동 동작
- `visible == false` 메뉴는 customer 측에서 자동 필터 (sub-phase 1 결정 J 의 visible 운영 필드 활용 — case A 분기 안에 visible 필터가 이미 적용됨)
- `status == approved` 필터도 case A 분기에 이미 적용 — 본 sub-phase 의 메뉴는 항상 approved 박히므로 통과

#### E. 이미지 업로드

- sub-phase 1 의 `ImageUploadField` + `StorageDataSource` 그대로 재사용 (V5)
- Firebase Storage 경로: `menu_images/store/{storeId}/{menuItemId}/{timestamp}_{filename}` (sub-phase 1 의 마스터 메뉴 경로 패턴과 일관 — `menu_images/brand/{brandId}/...` 의 store 버전)
- 클라이언트 검증: JPG / PNG (image_picker 자동 처리), 5MB 이하 (초과 시 client-side 에러 메시지)
- 이미지 업로드 실패 시 메뉴 저장 자체를 막고 에러 스낵바 (sub-phase 1 패턴 동일)
- 메뉴 삭제 / 이미지 교체 시 이전 이미지 Storage 정리 (sub-phase 1 의 `StorageDataSource.deleteByUrl` 재사용)

#### F. 공통 위젯 재사용

- `ImageUploadField` (sub-phase 1)
- `TagChipsSelector` (sub-phase 1)
- `VisibilityToggle` (sub-phase 1)
- `OptionGroupSelector` (sub-phase 1) — **단 마스터 메뉴와 다르게 master + store 양쪽 옵션 그룹을 노출** (V6 결정)
- `MenuItemListTile` (sub-phase 1) — 카드 위젯 그대로

### 비범위

- **브랜드 매장 메뉴 CRUD** → sub-phase 3 (이미 완료, brand 측에서 점포 한정 메뉴 등록 + 가격 오버라이드 + admin 승인). 본 sub-phase 는 개인 매장만.
- **점주 옵션 비활성 / 품절 토글** → sub-phase 5 (개인 / 브랜드 공통, 즉시 반영). 본 sub-phase 의 폼은 `disabledOption*` / `soldOut` UI 미노출 (entity default 만).
- **마스터 메뉴 자체 CRUD** → sub-phase 1.
- **매장 등록 / 매장 승인** → sub-phase 2 / 3.
- **점주가 브랜드 매장의 메뉴 등록** → 권한 매트릭스 결정 I 에 따라 점주 불가 (V4 — UI + Repository 양쪽 가드).
- **메뉴 옵션 그룹 자체 CRUD** → 별도 phase `admin_option_group_management`. 메뉴 등록 시 이미 존재하는 옵션 그룹에서 선택만.
- **부 카테고리 CRUD** → 별도 phase.
- **Firestore 보안 규칙 / 인덱스** → 별도 task `firestore_rules` / `firestore_indexes`.
- **마이그레이션 자동 스크립트** → 시드 매장 / 기존 매장은 fromFirestore default 로 흡수 (`brandId=null`, `status=approved`).

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - **sub-phase 1 (brand_master)** — 마스터 메뉴 CRUD 패턴 (S1~S10) + 결정 J Core/Operation 분리 + 이미지 업로드 인프라 + 공통 위젯 (`ImageUploadField` / `TagChipsSelector` / `VisibilityToggle` / `OptionGroupSelector` / `MenuItemListTile`). 본 sub-phase 의 화면 구조는 `BrandMaster*` 화면을 owner 측으로 단순화한 형태.
  - **sub-phase 2 (store_registration_approval)** — `StoreEntity.brandId` / `status` / `OwnerMyStorePage` 의 매장 상세 영역. 본 sub-phase 가 `OwnerMyStorePage` 의 매장 상세에 "메뉴 관리" CTA 를 추가.
  - **sub-phase 3 (brand_store_customization)** — 비의존이지만 **코드 영향 검토 필수**. sub-phase 3 가 `MenuItemRepositoryImpl.createStoreOnlyMenu` 외 3종을 **brand 매장 점포 한정 메뉴용 (status=pending)** 로 구현했음. 본 sub-phase 가 동일 메서드를 **개인 매장 메뉴용 (status=approved)** 로 분기 추가하므로 sub-phase 3 의 동작이 회귀하지 않아야 함. → V1 잠정안 (재사용) 의 핵심 검증 포인트.
- **진입 조건**:
  - umbrella `spec.md` APPROVED (완료)
  - sub-phase 1 / sub-phase 2 / sub-phase 3 의 `spec.md` / `implementation.md` / `test_report.md` PASS (sub-phase 3 의 점포 한정 메뉴 실제 구현 패턴이 본 sub-phase 의 분기 추가의 베이스)
  - 테스트용 점주 1명 + **개인 매장 1개** (`brandId == null`, `status == approved`) 보유
  - (옵션) 비교 검증용 브랜드 매장 1개 (sub-phase 3 산출) — brand 매장 점주가 본 sub-phase 진입 시 CTA 비노출 / Repository 가드 발동 확인용

---

## 확정된 결정사항 (sub-phase 한정)

> umbrella 결정 1~12 / A~F / G/H/I/J 와 sub-phase 1 결정 S1~S10, sub-phase 2 결정 T1~T10, sub-phase 3 결정 U1~U? 는 단일 진실원 그대로 따른다. 여기서는 본 sub-phase 한정 결정만 기록한다.

### V1. Repository 메서드 — **(b) sub-phase 1/3 의 `createStoreOnlyMenu` / `updateStoreOnlyMenu*` / `deleteStoreOnlyMenu` 재사용 + RepositoryImpl 내부 brandId 분기**

- 후보:
  - (a) 신규 분리 — `MenuItemRepository` 에 `createPersonalStoreMenu` / `updatePersonalStoreMenu*` / `deletePersonalStoreMenu` 메서드 추가
  - (b) 재사용 — sub-phase 1/3 의 `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `updateStoreOnlyMenuOperation` / `deleteStoreOnlyMenu` 활용. RepositoryImpl 내부에서 매장의 brandId 를 fetch 해 분기:
    - `brandId == null` (개인 매장) → `status = approved` 강제 + 승인 메타 모두 null + ownership 검증 (점주 본인 매장만)
    - `brandId != null` (브랜드 매장 점포 한정 메뉴) → sub-phase 3 동작 그대로 (status=pending, brand uid 박음)
- **채택**: **(b) 재사용**. 이유:
  - store-only 메뉴 메서드는 scope='store' + Firestore 경로 (`stores/{storeId}/menuItems`) + entity 구조까지 동일. 다른 점은 status 강제값과 ownership 검증 주체뿐.
  - presentation 측 코드 단순화 — owner 와 brand 가 같은 UseCase / Repository 메서드 호출. 호출자가 storeId 만 전달하면 RepositoryImpl 이 알아서 분기.
  - sub-phase 3 의 회귀 위험은 RepositoryImpl 안에서 명확히 분기 (brandId 분기) 처리하면 차단 가능. tester 가 두 분기를 모두 검증한다.
- 단점: RepositoryImpl 이 매장의 brandId 를 매번 fetch (저장 직전) — 추가 read 1회. 다만 이 비용은 무시 가능 (한 번의 도큐먼트 읽기).
- **구현 패턴**: `MenuItemRepositoryImpl` 에 `StoreRepository` 또는 `StoreRemoteDataSource` 의존성 추가 (또는 `MenuItemRemoteDataSource` 안에 매장 brandId fetch helper 추가). 잠정안 — `_fetchStoreBrandIdAndOwner(storeId)` private helper. developer 가 의존성 주입 패턴 결정 (RepositoryImpl 가 Repository 를 의존하면 순환 위험 — DataSource 직접 의존이 안전).

### V2. 결정 J 적용 (Core/Operation 분리) — **(b) 통합 채택**

- 후보:
  - (a) 분리 — `updatePersonalStoreMenuCore` / `updatePersonalStoreMenuOperation` (sub-phase 1 패턴 그대로)
  - (b) 통합 — 단일 `updateOwnerStoreMenu` UseCase. RepositoryImpl 내부에서 (V1 의 brandId 분기 후) `brandId == null` 이면 모든 필드를 한 번에 partial update + status 보존 (이미 approved)
- **채택**: **(b) 통합**. 이유:
  - admin 승인 게이트 없음 → Core/Operation 분리의 의미 (status 회귀 vs 보존) 가 사라짐. 모든 필드 변경이 즉시 반영.
  - presentation 측 폼이 단순. 한 폼에서 모든 필드를 다루고, 저장 시 단일 메서드 호출.
  - **단**, RepositoryImpl 내부 구현은 sub-phase 1/3 의 메서드를 재사용하므로 메서드 시그니처 자체는 `updateStoreOnlyMenuCore` / `updateStoreOnlyMenuOperation` 이 그대로 노출됨. 본 sub-phase 의 UseCase 가 두 메서드 중 하나만 호출하면 되는데, 어떤 걸 부를지가 문제:
    - **선택**: `updateStoreOnlyMenuCore` 호출 (모든 필드를 다루므로). RepositoryImpl 안에서 brandId == null 분기에서 status / 승인 메타를 강제로 `approved` / null 로 박음. → 결과적으로 status 회귀가 일어나지 않음 (이미 approved 였고, 다시 approved 박힘).
    - 운영 필드만 변경되는 케이스 (예: visible 토글) 도 같은 메서드 사용. partial update 효율을 위해 RepositoryImpl 의 brandId == null 분기에서 변경된 필드만 보내는 최적화는 선택 (developer 재량).
- **호환성 가드**: brand 매장 (sub-phase 3) 의 점포 한정 메뉴는 여전히 Core/Operation 분리를 활용 (sub-phase 3 결정). 본 sub-phase 의 통합 결정은 **개인 매장 한정**이며, RepositoryImpl 의 brandId 분기로 두 케이스가 자연스럽게 공존.

### V3. ownership 검증 — **sub-phase 1 의 S6 / sub-phase 2 의 T4 패턴 적용**

- 점주가 본인 매장이 아닌 매장의 메뉴를 조작하려 하면 차단
- `MenuItemRepositoryImpl` 가 `currentUidGetter`, `currentRoleGetter` 콜백을 이미 받음 (sub-phase 1 산출). 본 sub-phase 가 추가하는 보강:
  - `_assertOwnerOfPersonalStore(storeId)` private helper 추가
  - 동작: storeId 로 매장 fetch → `store.ownerId == currentUid && store.brandId == null` 이면 통과, 아니면 `PermissionDeniedException`
  - role == admin 은 항상 통과 (운영 관리자가 직접 손볼 수 있는 길 — 단 본 sub-phase UI 진입점은 owner 만)
- 기존 `_assertOwnershipOrAdmin(storeId)` 는 brand 매장용 store-only 메뉴에 사용 중 (sub-phase 3). 본 sub-phase 의 `_assertOwnerOfPersonalStore` 와 분리해 사용 — 또는 통합 헬퍼로 brandId 분기 안에서 두 검증을 모두 수행 (developer 재량).

### V4. brand 매장 점주의 메뉴 진입 차단 — **UI + Repository 양쪽 가드**

- UI 단:
  - `OwnerMyStorePage` 가 `store.brandId != null` 이면 "메뉴 관리" CTA 비노출 (자연스러운 차단)
  - 별도 안내 문구는 노출하지 않음 (단순화 — brand 매장 점주는 메뉴 관리 권한이 없다는 것을 sub-phase 3 산출 brand UI 또는 admin 안내를 통해 인지)
- Repository 단 (race condition 안전망):
  - `MenuItemRepositoryImpl` 의 brandId 분기에서 `brandId == null` 분기는 V3 의 ownership 검증, `brandId != null` 분기는 sub-phase 3 의 brand role 검증 (sub-phase 3 동작)
  - 점주(role=owner) 가 brand 매장 storeId 로 createStoreOnlyMenu 호출 → V3 검증 (`store.brandId == null` 조건 위반) → `PermissionDeniedException`
- → **자연스러운 가드 + 안전망 병행**. tester 가 양쪽 검증.

### V5. 이미지 업로드 정책 — **sub-phase 1 패턴 그대로**

- `image_picker` 재사용 (sub-phase 1 / 점주 매장 이미지에서 도입됨)
- Firebase Storage 경로: `menu_images/store/{storeId}/{menuItemId}/{timestamp}_{filename}`
- 5MB 제한, JPG / PNG, 업로드 실패 시 메뉴 저장 차단 + 에러 스낵바
- 메뉴 삭제 / 이미지 교체 시 `StorageDataSource.deleteByUrl` 호출로 이전 이미지 정리

### V6. 옵션 그룹 선택 UI — **master + store 양쪽 노출**

- Phase 1a 의 `OptionGroupRepository.getOptionGroupsForMenuItem` 패턴 활용 — 마스터 옵션 그룹 (`optionGroups/{id}`) + 매장 한정 옵션 그룹 (`stores/{storeId}/optionGroups/{id}`) 양쪽 fetch 후 노출
- 개인 매장 메뉴는 `optionGroupRefs` 에 master scope 와 store scope 모두 허용
- `OptionGroupSelector` 위젯 (sub-phase 1 산출) 에 store 옵션 fetch 흐름 추가 — 본 sub-phase 가 위젯의 호출 인자만 확장 (storeId 전달 시 store 옵션도 fetch). 위젯 자체는 designer 가 재검토.
- 무결성: 마스터 메뉴와 달리 store 옵션 허용은 RepositoryImpl 의 검증에 추가하지 않음 (sub-phase 1 의 S2 가드는 마스터 메뉴 = scope='brand' 한정).

### V7. visible 토글 즉시 반영 — **sub-phase 1 의 카드 인라인 토글 패턴 그대로**

- `OwnerStoreMenuListPage` 의 메뉴 카드에 인라인 visible 토글 (sub-phase 1 의 `_VisibleToggleButton` 패턴)
- 토글 즉시 `UpdateOwnerStoreMenuVisibleUseCase` 호출 → RepositoryImpl 의 update 흐름 (V2 결정 — `updateStoreOnlyMenuCore` 호출, 단 partial update 로 visible 만 보냄)
- 토글 결과 즉시 customer 측 반영 (`watchByStore` case A 가 visible 필터 적용)

### V8. 메뉴 복제 — **sub-phase 1 의 마스터 메뉴 복제 패턴 그대로**

- 메뉴 카드 long-press / 메뉴 버튼 → 액션 시트 → "복제"
- `CloneOwnerStoreMenuUseCase` (또는 단순한 prefill helper) → 원본 메뉴 fetch → `copyWith(id='', name='{원본} 복사', status=approved, 승인 메타 reset, imageUrl='' (이미지는 복제하지 않고 사용자가 다시 업로드))` → DB 저장 X
- prefill 결과를 가지고 `OwnerStoreMenuFormPage(mode=create, prefill=cloned)` 진입 → 사용자 수정 후 저장 → 시나리오 1 동일

### V9. 화면 진입 경로 — **`OwnerMyStorePage` 매장 상세에 "메뉴 관리" CTA**

- sub-phase 2 의 매장 정보 수정 / 운영 정보 수정 CTA 옆에 **"메뉴 관리"** 버튼 배치 (잠정안 — designer 가 위치 / 디자인 재검토 가능)
- 진입 조건: `store.brandId == null && store.status == EntityApprovalStatus.approved`
  - brand 매장 (`store.brandId != null`) → 비노출 (V4)
  - pending → 비노출 (매장이 승인 안 된 상태에서 메뉴 등록 의미 적음)
  - rejected → 비노출
- 진입 후 `Navigator.push(MaterialPageRoute(builder: (_) => OwnerStoreMenuListPage(store)))` (router.dart 없음 — 본 phase 일관 패턴)

### V10. customer 측 case A 의 status 필터 — **자연 정합 (별도 보강 없음)**

- sub-phase 2 의 customer 측 매장 검색 status='approved' 필터 + sub-phase 1/3 의 case A 분기 안의 status='approved' / visible 필터 (이미 적용됨)
- 본 sub-phase 의 점주 등록 메뉴는 자동 status='approved' 박힘 → 두 필터 모두 통과
- 회귀 검증: 점주 등록 직후 customer `StoreMenuPage` 즉시 노출 / visible 토글 시 즉시 사라짐 / 삭제 시 즉시 사라짐 → tester 시나리오로 확인

---

## 데이터 모델

### Firestore (umbrella 모델 중 본 sub-phase 가 활성화하는 부분)

```text
stores/{storeId}                                             # sub-phase 2 산출
  ├─ brandId: null                                           # 본 sub-phase 대상은 항상 null
  ├─ status: 'approved'                                      # 본 sub-phase 진입 조건
  ├─ ownerId: <점주 uid>                                     # ownership 검증 키 (V3)
  └─ menuItems/{menuItemId}                                  # 개인 매장 메뉴 (본 sub-phase write)
       ├─ id (= doc.id)
       ├─ name, imageUrl, description
       ├─ scope: 'store'                                     # 강제 (V1)
       ├─ brandId: null                                      # 매장이 brandId=null 이므로
       ├─ mainCategory, subCategoryId?
       ├─ basePrice (int, 원)
       ├─ optionGroupRefs: [{scope:'master'|'store', id}]    # master + store 양쪽 허용 (V6)
       ├─ tags: List<String>
       ├─ visible: bool (default true)
       ├─ displayOrder
       ├─ disabledOptionGroupIds: []                          # sub-phase 5 활성, 본 sub-phase 는 default
       ├─ disabledOptionItemIds: []                           # 동일
       ├─ soldOut: false                                      # sub-phase 5 활성, 본 sub-phase 는 default
       ├─ status: 'approved'                                  # 강제 (V1, 즉시 반영)
       ├─ submittedBy: null, submittedAt: null
       ├─ approvedBy: null, approvedAt: null
       ├─ rejectedReason: null
       └─ createdAt, updatedAt
```

> **brand 매장 점포 한정 메뉴와의 차이** (sub-phase 3):
> - 같은 컬렉션 (`stores/{storeId}/menuItems`) 이지만 **scope=store + brandId 분기 (저장 시 RepositoryImpl 이 매장의 brandId 를 fetch 해 분기)**
> - brand 매장 점포 한정 메뉴: status='pending' → admin 승인. 승인 메타 박힘. brand uid 가 submittedBy.
> - 개인 매장 메뉴 (본 sub-phase): status='approved' 즉시. 승인 메타 모두 null.
> - customer 측 머지 (`watchByStore`) 가 status='approved' 필터를 적용하므로 두 케이스 모두 자연 정합.

### Domain Entity

- `MenuItemEntity` (sub-phase 1 에서 확장 완료) — 변경 없음
- 본 sub-phase 가 활용하는 entity 필드:
  - 모든 메뉴 메타 (name, imageUrl, description, mainCategory, subCategoryId, basePrice, optionGroupRefs, tags, visible, displayOrder)
  - scope (강제 store), brandId (강제 null), status (강제 approved), 승인 메타 (모두 null)
  - disabledOption*, soldOut (entity default — UI 활성은 sub-phase 5)

### DTO / Model

- `MenuItemModel` (sub-phase 1 에서 확장 완료) 그대로 사용
  - `fromFirestore` 의 default: `scope=store`, `status=approved`, `tags=[]`, `visible=true`, `disabledOption*=[]`, `soldOut=false` — legacy + 본 sub-phase 메뉴 모두 안전 흡수
  - `toFirestore` 는 모든 필드를 박음 (RepositoryImpl 이 전달한 값 그대로). RepositoryImpl 의 brandId 분기에서 status / 승인 메타를 강제 세팅 후 model 변환.

---

## 레이어 설계

### Domain

#### Entity (변경 없음)

- `MenuItemEntity` (sub-phase 1 산출) 그대로 사용

#### Repository Interface (변경 없음 — V1 결정 (b))

- `MenuItemRepository` (sub-phase 1/3 산출) 시그니처 변경 없음
  - `createStoreOnlyMenu(MenuItemEntity)`
  - `updateStoreOnlyMenuCore(MenuItemEntity)`
  - `updateStoreOnlyMenuOperation(MenuItemEntity)` — 본 sub-phase 의 UseCase 는 호출하지 않음 (V2 — Core 만 호출하면 모든 필드 partial update 가능). 단 brand 매장용으로 sub-phase 3 가 호출하므로 시그니처 유지.
  - `deleteStoreOnlyMenu(String storeId, String menuItemId)`
- 호출자(UseCase) 가 brandId 를 신경쓰지 않고 호출 → RepositoryImpl 이 내부 분기 (V1)

#### UseCase (신규, 5종)

- `CreateOwnerStoreMenuUseCase` — `MenuItemEntity` 받아 `createStoreOnlyMenu` 호출. 개인 매장 분기는 RepositoryImpl 내부.
- `UpdateOwnerStoreMenuUseCase` — `MenuItemEntity` 받아 `updateStoreOnlyMenuCore` 호출 (V2 — 통합. RepositoryImpl 의 개인 매장 분기에서 status 보존 처리)
- `DeleteOwnerStoreMenuUseCase` — `(storeId, menuItemId)` 받아 `deleteStoreOnlyMenu` 호출
- `CloneOwnerStoreMenuUseCase` — `(storeId, sourceMenuItemId)` 받아 원본 fetch + copyWith prefill (DB 저장 X)
- `WatchOwnerStoreMenusUseCase` — `(storeId)` 받아 `watchByStore(storeId, brandId: null)` 위임 (read API 그대로)

> **재사용**: `WatchMenuItemByIdUseCase` (Phase 1a 산출) 그대로 사용 가능 (메뉴 상세). 재정의 불필요.

### Data

#### Model (변경 없음)

- `MenuItemModel` (sub-phase 1 산출) 그대로

#### DataSource (변경 없음)

- `MenuItemRemoteDataSource` (sub-phase 1 산출) 그대로 사용
  - `createStoreOnly(storeId, data)` / `updateStoreOnly(storeId, menuItemId, data)` / `deleteStoreOnly(storeId, menuItemId)` — 이미 존재
- `StorageDataSource` (Phase 1a + sub-phase 1 산출) 그대로 — 경로 `menu_images/store/{storeId}/{menuItemId}/...` 그대로 사용

#### Repository Implementation (보강)

`MenuItemRepositoryImpl` (sub-phase 1/3 산출) 의 다음 메서드 보강:

- `createStoreOnlyMenu(MenuItemEntity item)` → 보강:
  ```text
  1. 매장 fetch (store = storeRepository.getById 또는 storeRemoteDataSource.getById)
  2. ownership 검증:
     - role == 'admin' 통과
     - store.brandId == null && store.ownerId == currentUid → 통과 (개인 매장 점주)
     - store.brandId != null && role == 'brand' && store.brandId == currentBrandId → 통과 (브랜드 매장 brand uid)
     - 그 외 → PermissionDeniedException (V3, V4)
  3. brandId 분기:
     - brandId == null (개인 매장):
       prepared = item.copyWith(
         scope: store, brandId: null,
         status: approved,
         submittedBy: null, submittedAt: null,
         approvedBy: null, approvedAt: null, rejectedReason: null,
       )
     - brandId != null (브랜드 매장 점포 한정 메뉴 — sub-phase 3 동작):
       prepared = item.copyWith(
         scope: store, brandId: store.brandId,
         status: pending,
         submittedBy: currentUid, submittedAt: now,
         approvedBy: null, approvedAt: null, rejectedReason: null,
       )
  4. dataSource.createStoreOnly(item.storeId, model.toFirestore())
  ```
- `updateStoreOnlyMenuCore(MenuItemEntity item)` → 보강:
  ```text
  1. 매장 fetch + ownership 검증 (위와 동일)
  2. brandId 분기:
     - brandId == null (개인 매장):
       prepared = item.copyWith(
         status: approved,
         submittedBy: null, submittedAt: null,
         approvedBy: null, approvedAt: null, rejectedReason: null,
       )
       partial map: 모든 폼 필드 + updatedAt (status 보존되지만 강제로 approved 다시 박음 — race 안전망)
     - brandId != null: sub-phase 3 동작 (status=pending 회귀)
  3. dataSource.updateStoreOnly(item.storeId, item.id, partialMap)
  ```
- `updateStoreOnlyMenuOperation(MenuItemEntity item)` → 보강 없음 (sub-phase 3 동작 그대로). 본 sub-phase UseCase 는 호출하지 않음 (V2). brand 매장이 호출.
- `deleteStoreOnlyMenu(storeId, menuItemId)` → 보강:
  - ownership 검증 (개인 매장 점주 / brand uid / admin 모두 허용)
  - 이미지 정리: 삭제 직전 메뉴 fetch → imageUrl 있으면 `storageDataSource.deleteByUrl(imageUrl)` 호출 (sub-phase 1 마스터 메뉴 삭제 패턴 동일)
  - dataSource.deleteStoreOnly 호출

> **의존성 추가**: `MenuItemRepositoryImpl` 가 매장의 brandId / ownerId 를 알아야 함. 두 가지 방식:
> - **(a)** 생성자에 `StoreRepository` 주입 (presentation DI 에서) — 도메인 의존성. data 레이어 끼리 의존하지 않으므로 안전.
> - **(b)** 생성자에 `StoreRemoteDataSource` 주입 — data 레이어 끼리 의존. 더 효율적.
> - **잠정안**: **(b) `StoreRemoteDataSource` 직접 주입**. `MenuItemRepositoryImpl(menuItemDataSource, masterMenuDataSource, menuOverrideDataSource, storeRemoteDataSource, currentUidGetter, currentRoleGetter, currentBrandIdGetter)`. developer 가 cycle / DI 충돌 검토.

> **cache 옵션**: 매장 brandId / ownerId fetch 는 매번 Firestore 읽기로 비용 1 read. 무시 가능. cache 도입은 별도 task.

### Presentation

#### Owner 모듈 확장 (`presentation/owner/store_menu/`)

```text
presentation/owner/store_menu/
├── owner_store_menu_list_page.dart           # 신규 — 메뉴 리스트 + FAB + 카드 인라인 visible 토글
├── owner_store_menu_form_page.dart           # 신규 — 등록/수정/복제 prefill 통합 폼
├── owner_store_menu_detail_page.dart         # 신규 — 메뉴 상세 + 액션 (수정/복제/삭제)
└── widgets/                                   # 신규 (필요시)
    └── owner_store_menu_card.dart            # 카드 위젯 (sub-phase 1 의 MenuItemListTile 활용 가능)

presentation/owner/providers/
├── owner_store_menu_providers.dart           # 신규 — UseCase / Repository DI + 메뉴 리스트 stream provider
└── (기존) owner_providers.dart               # 변경 없음
```

#### `OwnerMyStorePage` 갱신

- 매장 상세 영역 (sub-phase 2 의 status 라벨 / 매장 정보 수정 / 매장 운영 정보 수정 옆) 에 **"메뉴 관리"** CTA 추가
- 노출 조건: `store.brandId == null && store.status == EntityApprovalStatus.approved`
- 탭 시 `Navigator.push(MaterialPageRoute(builder: (_) => OwnerStoreMenuListPage(store)))`
- designer 가 CTA 배치 / 디자인 재검토 (잠정안 — 매장 운영 정보 버튼 옆 또는 매장 카드 하단 액션 영역)

#### 라우팅

- `Navigator.push(MaterialPageRoute)` 패턴 유지 (router.dart 변경 없음)
- `RoleRouter` 변경 없음 (sub-phase 1 의 `OwnerScaffold` 분기 그대로)

---

## 데이터 흐름 (핵심 시나리오 5개)

### 1. 메뉴 신규 등록 (점주 → 즉시 반영)

```text
OwnerMyStorePage (개인 매장, status=approved)
  → "메뉴 관리" CTA 탭 → OwnerStoreMenuListPage(store)
  → FAB "메뉴 추가" → OwnerStoreMenuFormPage(storeId, mode=create)
  → 입력 + 이미지 업로드 + 저장
  → CreateOwnerStoreMenuUseCase
  → MenuItemRepository.createStoreOnlyMenu(item)
  → MenuItemRepositoryImpl:
     - 매장 fetch (storeRemoteDataSource.getById)
     - ownership 검증: store.brandId == null && store.ownerId == currentUid → 통과
     - brandId 분기: null → status=approved 강제, 승인 메타 모두 null
     - imageUrl: StorageDataSource.upload (menu_images/store/{storeId}/{menuItemId}/...)
     - dataSource.createStoreOnly(storeId, model.toFirestore())
  → SnackBar "즉시 반영되었습니다"
─── (customer) StoreMenuPage 자동 갱신
  → MenuItemRepository.watchByStore(storeId, brandId: null) — case A 분기
  → status='approved' + visible 필터 통과 → 노출
```

### 2. 메뉴 수정 (가격 / 이름 / visible 등 — 즉시 반영)

```text
OwnerStoreMenuListPage 카드 또는 OwnerStoreMenuDetailPage
  → 수정 버튼 → OwnerStoreMenuFormPage(storeId, mode=edit, item)
  → 필드 수정 (예: basePrice / name / mainCategory / visible / tags / displayOrder 등 자유 조합)
  → 저장
  → UpdateOwnerStoreMenuUseCase
  → MenuItemRepository.updateStoreOnlyMenuCore(item)  # V2 — 통합. Core 메서드 호출
  → MenuItemRepositoryImpl:
     - 매장 fetch + ownership 검증
     - brandId == null 분기:
       - status=approved 강제 (race 안전망)
       - submittedBy/At, approvedBy/At, rejectedReason 모두 null 강제
       - partial map: 모든 변경 필드 + updatedAt
     - dataSource.updateStoreOnly
  → SnackBar "즉시 반영되었습니다"
─── (customer) StoreMenuPage 자동 갱신 — 변경된 필드 즉시 반영 (가격 변경도 즉시 노출)
```

### 3. 메뉴 삭제 (점주 → customer 즉시 제거)

```text
OwnerStoreMenuListPage 카드 long-press 또는 메뉴 → "삭제" 액션
  → 확인 다이얼로그 ("이 메뉴를 삭제하시겠습니까?")
  → 확인 → DeleteOwnerStoreMenuUseCase
  → MenuItemRepository.deleteStoreOnlyMenu(storeId, menuItemId)
  → MenuItemRepositoryImpl:
     - 매장 fetch + ownership 검증 (개인 매장 점주)
     - 이미지 정리: dataSource.streamById 로 imageUrl fetch → StorageDataSource.deleteByUrl
     - dataSource.deleteStoreOnly
  → SnackBar "삭제되었습니다"
─── (customer) StoreMenuPage 자동 갱신 — 메뉴 사라짐
```

### 4. 메뉴 visible 토글 (운영 필드 — 즉시 반영, 카드 인라인)

```text
OwnerStoreMenuListPage 카드의 visible 토글 (인라인, V7)
  → UpdateOwnerStoreMenuUseCase (visible 만 변경된 partial entity 전달)
  → MenuItemRepository.updateStoreOnlyMenuCore (V2 통합 — visible 도 Core 메서드로 처리)
  → MenuItemRepositoryImpl: brandId == null 분기 → status=approved 보존, partial map: visible + updatedAt
  → 즉시 갱신
─── (customer) watchByStore case A 의 visible 필터 — visible=false 면 즉시 제거, true 면 즉시 노출
```

### 5. 메뉴 복제 (V8)

```text
OwnerStoreMenuListPage 카드 long-press / 메뉴 → "복제" 액션
  → CloneOwnerStoreMenuUseCase
  → 원본 메뉴 fetch (watchById 1회 + cancel)
  → copyWith(id='', name='{원본} 복사', imageUrl='', status=approved, 승인 메타 reset)
  → DB 저장 X (prefill 만)
  → OwnerStoreMenuFormPage(storeId, mode=create, prefill=cloned)
  → 사용자 수정 후 저장 → 시나리오 1 동일
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 권한 미달 (점주 role 아님 — customer / admin / brand 가 OwnerStoreMenu* 진입 시도) | `RoleRouter` 가 분기에서 차단 (`OwnerScaffold` 안에서만 노출). admin 직접 진입은 본 sub-phase 비범위 |
| 권한 미달 (점주가 본인 외 매장 메뉴 조작 시도) | RepositoryImpl 의 `_assertOwnerOfPersonalStore` (V3) → `PermissionDeniedException` → 스낵바 "권한이 없습니다" |
| 권한 미달 (점주가 brand 매장 메뉴 조작 시도) | UI 단 CTA 비노출 (V4 자연 차단). race condition: storeId 직접 전달로 호출 시 RepositoryImpl 의 brandId 분기 → brand 매장은 brand uid 검증으로 차단 (점주 uid 매칭 X) → `PermissionDeniedException` |
| 이미지 업로드 실패 | 메뉴 저장 자체를 막고 에러 스낵바 (sub-phase 1 패턴) |
| 이미지 5MB 초과 | 업로드 직전 client validation → 에러 메시지 |
| 이미지 교체 시 이전 이미지 삭제 실패 | 메뉴 저장은 성공 처리, 이전 이미지는 Storage 잔존 (별도 cleanup 작업 — 본 sub-phase 비범위). 로그만 남김 |
| Firestore 읽기 실패 (네트워크) | `AsyncError` → 에러 위젯 + 재시도 버튼 (Riverpod refresh) |
| 매장 fetch 실패 (RepositoryImpl 내부 brandId fetch) | `StateError` → 스낵바 "매장 정보를 불러올 수 없습니다". 메뉴 저장 차단 |
| 매장이 삭제된 사이 메뉴 등록 시도 | 매장 fetch null → `StateError` → 차단 |
| 매장이 brand 매장으로 변경된 사이 메뉴 등록 시도 (race condition) | RepositoryImpl 의 brandId 분기에서 brand 매장 분기로 흘러감 → 점주 uid 가 brand 검증 통과 X → `PermissionDeniedException` (V4 안전망) |
| 메뉴 삭제 후 customer 가 진입 중인 상세 화면 | customer `MenuItemDetailPage` 의 `watchById` stream 이 null 반환 → 빈 상태 / 뒤로 (Phase 1a 동작 그대로) |
| optionGroupRefs 가 존재하지 않는 옵션 그룹 ref | UI 단 picker 가 존재 옵션만 노출 (V6). race 시 customer 측 fetch 단계에서 빈 옵션 처리 (Phase 1a 동작) |
| 인증 만료 | 기존 auth flow (재로그인) |

---

## 작업 분배 판단

### designer 호출 — **권장 (필수)**

신규 화면 3종 (`OwnerStoreMenuListPage` / `OwnerStoreMenuFormPage` / `OwnerStoreMenuDetailPage`) + `OwnerMyStorePage` 의 "메뉴 관리" CTA 배치. sub-phase 1 의 `BrandMaster*` 화면 디자인 토큰 / 컴포넌트를 그대로 차용하므로 디자인 작업량은 sub-phase 1 의 50~60% 수준.

- 디자인 산출물: `docs/tasks/admin_menu_management/4_owner_personal_menu/design.md`
- 전달할 사항:
  - `OwnerStoreMenuListPage` — sub-phase 1 의 `BrandMasterMenuListPage` 차용. 단 status 뱃지 미노출 (항상 approved). 카드 인라인 visible 토글 (V7).
  - `OwnerStoreMenuFormPage` — sub-phase 1 의 `BrandMasterMenuFormPage` 차용. Core/Operation 분리 안내 미노출 (V2 — 통합). status 회귀 안내 미노출. 저장 후 SnackBar "즉시 반영되었습니다".
  - `OwnerStoreMenuDetailPage` — sub-phase 1 의 `BrandMasterMenuDetailPage` 차용. status 뱃지 / 승인 메타 미노출.
  - `OwnerMyStorePage` 의 "메뉴 관리" CTA 위치 / 디자인 (잠정안 — 매장 운영 정보 버튼 옆)
  - `OptionGroupSelector` 의 master + store 양쪽 노출 UI (V6)
  - 빈 상태 / 로딩 / 에러 / 삭제 확인 다이얼로그 / 복제 액션 시트

### developer 호출

designer 완료 후. 의존 순서: Domain (UseCase 신규) → Data (RepositoryImpl 보강) → Presentation (화면 신설).

- 구현 항목: 위 레이어 설계의 모든 파일
- 재사용:
  - sub-phase 1 의 `MenuItemEntity` / `MenuItemModel` / `MenuItemRemoteDataSource` / `MenuItemRepository` (시그니처 그대로)
  - sub-phase 1 의 공통 위젯 (`ImageUploadField` / `TagChipsSelector` / `VisibilityToggle` / `OptionGroupSelector` / `MenuItemListTile`) — 단 `OptionGroupSelector` 는 store 옵션 fetch 추가 (V6)
  - sub-phase 1/3 의 `MenuItemRepositoryImpl` — V1/V2/V3/V4 보강 추가
  - sub-phase 2 의 `OwnerMyStorePage` / `StoreEntity.brandId` / `status` — CTA 추가만
  - 기존 `StorageDataSource` / `Navigator.push` / freezed / Riverpod 패턴
- 주의할 레이어 규칙:
  - `MenuItemRepositoryImpl` 의 `StoreRemoteDataSource` 의존 추가 — 생성자 시그니처 변경. presentation DI 에서 주입 (sub-phase 1 / 3 의 DI 도 같이 갱신).
  - sub-phase 3 의 brand 매장 점포 한정 메뉴 동작 (status=pending) 과 본 sub-phase 의 개인 매장 메뉴 동작 (status=approved) 가 RepositoryImpl 의 brandId 분기 안에서 명확히 분기되어야 함. tester 가 두 분기를 모두 검증.
  - `Color(0x...)` 직접 하드코딩 금지 — `AppColors` 만 사용
  - Firebase 직접 import 는 data 레이어에서만 (sub-phase 1 패턴 그대로)
- `pubspec.yaml`: 추가 패키지 없음 (image_picker 이미 sub-phase 1, rxdart 이미 sub-phase 3)

### tester 호출

developer 완료 후. `test_report.md`. **회귀 검증 강조** — sub-phase 1/2/3 + customer Phase 1a~2 + brand 매장 메뉴 분기 무영향.

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능 (owner)

- [ ] `OwnerMyStorePage` 의 "메뉴 관리" CTA — 개인 매장 + approved 일 때만 노출, brand 매장 / pending / rejected 시 비노출 (V4, V9)
- [ ] `OwnerStoreMenuListPage` 진입 — 메뉴 리스트 노출 + FAB 동작
- [ ] 메뉴 신규 등록 → status=approved 즉시 박힘, 승인 메타 모두 null, customer `StoreMenuPage` 즉시 노출
- [ ] 메뉴 수정 (이름 / 가격 / 카테고리 / 옵션그룹 / 설명) → status=approved 보존 (race 안전망), customer 즉시 반영
- [ ] 메뉴 운영 필드 변경 (visible / tags / displayOrder / imageUrl) → 즉시 반영, status 보존
- [ ] 카드 인라인 visible 토글 → 즉시 반영, customer 즉시 노출 / 미노출 (V7)
- [ ] 메뉴 삭제 → 다이얼로그 → customer 즉시 제거 + Storage 이미지 정리
- [ ] 메뉴 복제 → 폼 prefill + name='{원본} 복사' + status=approved (저장 X, 사용자 수정 후 저장 시 시나리오 1) (V8)
- [ ] 이미지 업로드 / 교체 / 5MB 초과 에러
- [ ] `optionGroupRefs` master + store 양쪽 노출 (V6)

### 권한 / 가드 (V3, V4)

- [ ] 점주가 본인 외 매장 storeId 로 메뉴 조작 (직접 호출 시뮬레이션) → `PermissionDeniedException`
- [ ] 점주가 brand 매장 storeId 로 메뉴 조작 시도 → `PermissionDeniedException` (race 안전망)
- [ ] customer / admin / brand role 이 `OwnerStoreMenuListPage` 진입 시도 → `RoleRouter` 차단

### 회귀 (sub-phase 1/2/3 + customer Phase 1a~2)

- [ ] **sub-phase 3 brand 매장 점포 한정 메뉴 분기 무영향** — brand 매장에서 점포 한정 메뉴 등록 → status=pending 그대로 박힘 + admin 승인 큐 등장 + 점주 직접 등록 차단 (sub-phase 3 동작 그대로)
- [ ] **sub-phase 3 가격 오버라이드 분기 무영향** — brand 매장의 priceOverride / excluded 동작 그대로
- [ ] **sub-phase 1 마스터 메뉴 CRUD 무영향** — 마스터 메뉴 등록 / 수정 / 삭제 / 승인 흐름 그대로
- [ ] **sub-phase 2 매장 등록 / 승인 무영향** — 점주 매장 등록 → admin 승인 → customer 노출 그대로
- [ ] **customer Phase 1a~2 무영향** — 시드 매장 + 점주 등록 매장 + brand 매장 모두 customer 검색 / `StoreMenuPage` / `MenuItemDetailPage` 동작 그대로
- [ ] customer `watchByStore(storeId, brandId: null)` case A — 본 sub-phase 의 메뉴 즉시 노출 + visible 필터 + status filter 모두 동작
- [ ] customer `watchByStore(storeId, brandId: 'X')` case B — sub-phase 3 의 머지 흐름 그대로
- [ ] 시드 매장 (`brandId=null`, `status=approved` fallback) — 본 sub-phase 흐름으로 메뉴 등록 가능, 정상 동작 (T1 / V10 자연 정합)
- [ ] `MenuItemRepository.watchByStore` 시그니처 / 동작 불변

### Repository / Data 분기

- [ ] RepositoryImpl 의 `createStoreOnlyMenu` 의 brandId 분기 — 개인 매장 (null) → status=approved 강제 + 승인 메타 null, 브랜드 매장 (not null) → status=pending + brand uid 박음 (sub-phase 3 동작)
- [ ] RepositoryImpl 의 `updateStoreOnlyMenuCore` 의 brandId 분기 — 개인 매장 → status=approved 보존, 브랜드 매장 → status=pending 회귀 (sub-phase 3 동작)
- [ ] RepositoryImpl 의 `deleteStoreOnlyMenu` — 두 분기 모두 ownership 검증 + Storage 이미지 정리

### 코드 품질

- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (entity 변경 없으므로 영향 적음)
- [ ] 색상 토큰 — `AppColors` 만 사용, `Color(0x...)` 0건
- [ ] Firebase / 외부 SDK 직접 import 는 data 레이어만

---

## 완료 기준

- [ ] `spec.md` 본 문서 (현재) 확정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] `OwnerMyStorePage` "메뉴 관리" CTA 진입 (개인 매장 한정)
- [ ] 개인 매장 메뉴 신규 등록 / 수정 / 삭제 / 복제 / visible 토글 모두 동작
- [ ] 가격 변경 / 이름 변경 / 카테고리 변경 즉시 customer 반영 (admin 승인 게이트 없음)
- [ ] 메뉴 이미지 업로드 / 교체 / 삭제 + Storage 정리
- [ ] brand 매장 점주의 본 sub-phase 진입 차단 (UI + Repository 양쪽)
- [ ] sub-phase 1/2/3 회귀 0 (특히 sub-phase 3 brand 매장 점포 한정 메뉴 분기)
- [ ] customer Phase 1a~2 회귀 0
- [ ] `flutter analyze` 0 issue
