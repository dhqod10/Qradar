# admin_menu_management 기능 명세 (Umbrella)

> ## 상태
>
> **APPROVED — 결정사항 확정 완료 / 5개 sub-phase 로 분할**
>
> 본 문서는 본 phase 전체의 **데이터 모델 · 결정사항 · 권한 매트릭스 · role 라우팅** 의 단일 진실원이다.
> 실제 작업은 아래 5개 sub-phase 로 분할되어 진행된다. 각 sub-phase 진입 시 architect 가 별도 호출되어 해당 sub-phase spec 을 보강한다.

## 개요

- **목적**: Phase 1a 시드(`lib/dev/seed/phase1_seed_data.dart`, DEV_ONLY) 로만 들어가던 메뉴 데이터를 운영 화면으로 대체. product_scope.md 의 "브랜드 단위 마스터 메뉴 + 매장별 가격 오버라이드" 모델로 데이터 구조를 확장하고, **brand role 신설** + **admin 승인 게이트** + **owner 권한 분기 (개인 매장 / 브랜드 매장)** 까지 포함한다.
- **작업 유형**: 신규 기능 (대규모 — admin 모듈 + brand 모듈 신설 + owner 모듈 메뉴 관리 탭 신설 + 데이터 모델 확장)
- **결정적 비기능 목표**: **고객(customer) 측 Repository 인터페이스 변경 0**. `MenuItemRepository.watchByStore(storeId)` 시그니처 그대로 유지하고, 케이스 분기 + 옵션 비활성화 필터 + visibility 필터 + status 필터는 `MenuItemRepositoryImpl` 내부에서 처리해 `StoreMenuPage` / `MenuItemDetailPage` / Phase 2 추천 / 시드 코드를 건드리지 않는다.

### 영향 범위 (전체 phase 합산)

| 레이어 | 영향 |
|---|---|
| 화면 (admin) | (신규) AdminScaffold + 매장 승인 / 브랜드 승인 / 마스터 메뉴 승인 / 매장 커스텀 승인 큐 (4종) + 더보기 |
| 화면 (brand) | (신규) BrandScaffold + 브랜드 정보 / 마스터 메뉴 CRUD / 매장 리스트 / 매장 커스텀 / 점포 한정 메뉴 / 가격 오버라이드 / 승인 트래킹 |
| 화면 (owner) | (신규) 메뉴 관리 탭 — 권한 분기(개인 매장 풀 권한 / 브랜드 매장 옵션·품절만). (수정) 점주 매장 등록 폼에 `submittedBy`/`status=pending` 자동 처리 |
| 화면 (customer) | **변경 없음** — Repository 인터페이스 불변, 내부 머지/필터만 추가 |
| Domain | (신규) `BrandEntity`, `MenuOverrideEntity`, `StoreApprovalStatus` enum (모든 status 대상 entity 공통). (수정) `StoreEntity` / `MenuItemEntity` / `MenuOverrideEntity` 에 status / brandId / disabled* 필드 추가. (신규) `BrandRepository`, `MasterMenuItemRepository`, `MenuOverrideRepository`. UseCase 다수. |
| Data | (신규) `BrandRemote`, `MasterMenuItemRemote`, `MenuOverrideRemote` DataSource + Model. (수정) `MenuItemRemote`, `StoreRemote`, `StorageDataSource`. (수정) `MenuItemRepositoryImpl.watchByStore` — `store.brandId` + status 분기 + override merge + 옵션 비활성 필터. |
| Presentation | (신규) `presentation/admin/`, `presentation/brand/`, `presentation/owner/menu_management/` 트리 |
| 라우팅 | `RoleRouter` 에 `admin` / `brand` / `owner` / `customer` 4분기 (admin/brand 신규) |
| 권한 / 환경 설정 | 클라이언트 가드만 (Firestore 보안 규칙은 별도 task `firestore_rules`). `RoleRouter` 분기 + 화면 진입 가드 |
| 테스트 | 기존 customer 화면(StoreMenuPage 등) **회귀 테스트 필수**. 시드 매장(brandId=null, status=approved) 기준 동작 그대로 |

### 비범위 (전체 phase 공통)

- **결제(Phase 3)** : 변경 없음.
- **Customer 화면 변경** : `StoreMenuPage`, `MenuItemDetailPage`, `cart` 등은 **수정하지 않는다**.
- **옵션 그룹 / 부 카테고리 CRUD UI** : 본 phase 비범위. 메뉴 등록 시 **이미 존재하는 글로벌 옵션 그룹 / 부 카테고리에서 선택**만 가능. 별도 phase `admin_option_group_management`, `admin_sub_category_management`.
- **매출 조회 / 회원 관리 / 쿠폰 / 배너 / 공지** : product_scope.md 에 있으나 별도 phase.
- **다국어 / 알레르기 / 카드 뉴스 / 영양 정보 / 판매 기간 / 판매 시간대 / 재고 한정** : 본 phase 비범위.
- **드래프트 / 게시 분리(`published` 토글)** : 본 phase 비범위. 단 `visible: bool` (시즌 메뉴 미노출용) 은 포함.
- **마이그레이션 자동 스크립트** : 기존 매장 / 시드 매장의 `brandId` 는 모두 `null`, `status` 는 `approved` 로 두는 모델 default 만 보장.
- **N:1 brand 매핑** : 본 phase 는 `users/{uid}.brandId` 1:1. 한 사람이 여러 브랜드를 운영하는 경우는 후속 phase (인터페이스 호환 마이그레이션).
- **Cloud Functions cascade** : 모든 cascade 는 클라이언트 batch delete. 서버 측 cascade 는 별도 task.
- **자동화 마이그레이션 스크립트** : `users/{uid}.role = 'brand'`, `users/{uid}.brandId` 부여는 **admin 이 Firestore 콘솔에서 수동** (브랜드사가 자체 회원가입 X).

---

## 확정된 결정사항

> 모든 결정사항은 사용자 승인 완료. 본 섹션은 추후 변경 시 영향 범위 추적을 위한 기록이며, sub-phase 는 이 결정을 그대로 따른다.

### 기존 결정 1~12 (확정 유지)

1. **admin 역할 진입** — 기존 `users/{uid}.role` 그대로 사용. `RoleRouter` 가 `users/{uid}.role == 'admin'` 인 사용자를 `AdminScaffold` 로 분기.
2. ~~결정 2 (단일 admin role only)~~ **번복** — 결정 G 참조. **brand role 신설**.
3. **매장의 brandId 선택** — admin / brand 만. 점주 등록 폼에 `brandId` 선택 UI 없음 (점주는 항상 개인 매장 등록 → admin 승인 게이트).
4. **brandId 마이그레이션** — 자동 스크립트 없음. 기존 매장 / 시드 매장 모두 `brandId = null`, `status = approved` 모델 default.
5. **삭제 정책**:
   - 브랜드 삭제 시 소속 매장 존재 → **차단 + 다이얼로그**
   - 브랜드 삭제 시 마스터 메뉴 존재 → 확인 후 cascade
   - 마스터 메뉴 삭제 시 매장 override 존재 → 확인 후 cascade batch delete
   - 매장 삭제 시 menuItems / menuOverrides → client batch delete
6. **즉시 노출 + visible 토글** — `published` 드래프트 분리 없음. 단 `visible: bool` 필드 포함 (시즌 메뉴 미노출 용도).
7. **메뉴 이미지 업로드 정책** — `image_picker`. Storage 경로:
   - 브랜드 로고: `brand_images/{brandId}/{timestamp}_{filename}`
   - 마스터 메뉴: `menu_images/brand/{brandId}/{menuItemId}/{timestamp}_{filename}`
   - 매장 메뉴: `menu_images/store/{storeId}/{menuItemId}/{timestamp}_{filename}`
8. **부가 필드 — 본 phase 포함**: `tags` (`recommended`/`new`/`best`), `visible`, `displayOrder`, `description`, 카테고리, 이미지 업로드. **비범위**: 판매 기간 / 시간대 / 재고 한정 / 알레르기 / 영양 / 다국어 / 카드 뉴스.
9. **`rxdart` 의존 추가** — 브랜드 매장 케이스 stream 머지용. data 레이어에서만 사용.
10. **admin 매장 전체 조회** — Stream 기반 (페이지네이션 후속 phase).
11. **store.brandId 실시간 변경** — 화면 진입 시점 lock-in. 변경 시 재진입 필요.
12. **RoleRouter admin 분기** — `case UserRole.admin: → const AdminScaffold()`.

### 추가 결정 A~F (확정 유지 / A 는 결정 H 로 번복)

- ~~A (status 필드 적용 범위 — `stores/{id}` 만)~~ **번복** — 결정 H 참조. status 필드는 brand / 마스터 메뉴 / 매장 커스텀 / 매장 한정 추가 메뉴까지 확장.
- **B. 마스터 가격 변경 시 priceOverride 보존** — 매장이 priceOverride 를 가진 상태에서 마스터 가격이 변경되어도 매장 가격은 priceOverride 유지. brand 폼 저장 단계에서 "N개 매장은 priceOverride 적용 중" 정보성 다이얼로그.
- **C. 마스터 메뉴 삭제 cascade** — 모든 가맹점의 `menuOverrides/{masterMenuItemId}` batch delete. customer 화면 즉시 사라짐.
- **D. 마스터 메뉴 옵션 그룹 추가/변경 자동 적용** — 모든 가맹점 자동 반영. 단 점주가 비활성화한 항목은 비활성 유지.
- **E. 옵션 비활성화 데이터 모델** — `stores/{id}/menuOverrides/{masterMenuItemId}` 와 `stores/{id}/menuItems/{menuItemId}` 모두 `disabledOptionGroupIds` + `disabledOptionItemIds` 필드. 점주 즉시 반영.
- **F. 메뉴 복제** — 마스터 메뉴 / 개인 매장 메뉴 양쪽 폼에 "복제" 버튼. prefill + `"{원본} 복사"` prefix.

### 신규 결정 G — brand role 신설 (이전 결정 2 번복)

- **`users/{uid}.role = 'brand'`** + **`users/{uid}.brandId = '<brandId>'`** (1:1 매핑).
- brand 계정은 **admin 이 발급** (브랜드사가 자체 회원가입 X). admin 이 Firestore 콘솔에서 수동으로 `role = 'brand'` + `brandId` 세팅.
- brand 의 권한:
  - 자기 brand 정보 등록·수정 (admin 승인 게이트)
  - 자기 brand 의 마스터 메뉴 CRUD (admin 승인 게이트)
  - 자기 brand 가 운영하는 매장의 커스텀 (가격 오버라이드 + 점포 한정 추가 메뉴) 입력 (admin 승인 게이트)
  - 자기 brand 매장의 status / 승인 상태 트래킹 (read only)
- 향후 N:1 마이그레이션 가능성 명시 — `users/{uid}.brandIds: List<String>` 으로 확장 가능. 현 phase 인터페이스가 `brandId(String)` 을 가지지만, Repository 레이어에서 `userId → brandId` 매핑 함수만 추상화하면 N:1 전환 시 인터페이스 변경 최소화.
- `RoleRouter` 의 `case UserRole.brand: → const BrandScaffold()` 신규 분기 추가.

### 신규 결정 H — status 필드 적용 범위 확장 (이전 결정 A 번복)

이전 결정 A ("status 는 `stores/{id}` 만") 를 **번복**. 새로운 적용 범위:

| Entity | status 필드 | 사유 |
|---|---|---|
| `stores/{id}` | YES | 매장 등록 (개인 / 브랜드 양쪽) |
| `brands/{brandId}` | YES (신규) | brand 가 등록, admin 승인 |
| `brands/{brandId}/menuItems` | YES (신규) | brand 가 등록, admin 승인 |
| `stores/{id}/menuOverrides` | YES (신규) | brand 매장 커스텀, admin 승인 |
| `stores/{id}/menuItems` (개인 매장) | NO | 점주 즉시 반영 |
| `stores/{id}/menuItems` (브랜드 매장 점포 한정 추가) | YES (신규) | brand 가 등록, admin 승인. 같은 컬렉션이므로 status 필드는 entity level 에 존재. 디시리얼라이즈 시 `scope` + `brandId` 가 함께 이를 결정 |

**즉, 거의 모든 entity 에 status 필드** (개인 매장 메뉴만 예외).

`StoreApprovalStatus` enum 을 모든 status 가 있는 entity 에서 재사용 → `EntityApprovalStatus` 로 rename 하지 않고 (기존 호환), enum 이름만 그대로 두되 의미를 "Entity approval status — pending / approved / rejected" 로 확장한다.

### 신규 결정 I — 운영 단계 권한 매트릭스

기존 권한 매트릭스 번복. 다음 표를 단일 진실원으로 한다.

| 동작 | 개인 매장 (brandId=null) | 브랜드 매장 (brandId!=null) |
|---|---|---|
| 브랜드 등록 / 마스터 메뉴 CRUD / 마스터 가격 변경 | — | **brand** → admin 승인 |
| 매장 등록 | **점주** → admin 승인 | **brand 가 마스터 기반 커스텀 입력** → admin 승인 (점주는 오프라인 요청만) |
| 매장 핵심 정보 수정 (이름/주소/카테고리/사업자번호) | **점주** → admin 재승인 | **brand** → admin 재승인 |
| **매장 운영 정보 수정 (영업시간/임시휴무/전화번호/대표·내부 사진/매장 설명·안내)** | **점주 즉시** (status 회귀 X) | **점주 즉시** (status 회귀 X) |
| 매장 메뉴 등록 / 삭제 | **점주 즉시** | **brand** → admin 승인 (점주 불가) |
| 매장 메뉴 가격 변경 | **점주 즉시** | **brand or admin** (점주 불가) |
| 가격 오버라이드 / 점포 한정 추가 메뉴 | — | **brand** → admin 승인 |
| 마스터 메뉴 핵심 변경 (name/basePrice/optionGroupRefs/category/description) | 해당 없음 | **brand** → admin 재승인 |
| **마스터 메뉴 운영 변경 (visible/tags/displayOrder/imageUrl)** | 해당 없음 | **brand 즉시** (status 회귀 X) |
| 옵션 그룹/항목 매장 비활성화 | **점주 즉시** | **점주 즉시** (동일) |
| 품절 토글 | **점주 즉시** | **점주 즉시** (동일) |
| 마스터 메뉴 가격 변경 시 priceOverride 보유 매장 | 해당 없음 | priceOverride **보존** (결정 B) |
| 마스터 메뉴 삭제 cascade | 해당 없음 | 모든 매장 `menuOverrides/{id}` batch delete |
| 마스터 메뉴 옵션 그룹 추가 | 해당 없음 | 자동 적용. 단 점주 비활성 항목은 비활성 유지 |
| 메뉴 복제 | 점주 폼에 복제 버튼 | brand 마스터 메뉴 폼에 복제 버튼 |

> **주의**: 점주의 메뉴 수정 권한은 **매장의 `brandId` 분기**로 결정된다. 같은 점주라도 두 매장(개인/브랜드)을 가진다면 매장에 따라 권한이 다르다.
>
> **핵심 vs 운영 분리** (결정 J 참조): 같은 entity 라도 변경 필드가 핵심이냐 운영이냐에 따라 status 회귀 여부가 갈린다. 점주가 영업시간만 바꾸면 즉시 반영, 매장 이름을 바꾸면 admin 재승인. brand 가 마스터 메뉴의 visible 토글만 하면 즉시 반영, basePrice 를 바꾸면 admin 재승인.

### 신규 결정 J — 핵심 필드 vs 운영 필드 분리 정책

모든 entity (매장 / 마스터 메뉴 / 매장 커스텀 등) 의 필드를 두 그룹으로 분리한다.

- **핵심 필드** (검수 필요) — 신원 / 정합성 / 가맹 표준이 걸린 필드. 변경 시 `status='pending'` 으로 회귀하여 admin 재승인을 받는다.
- **운영 필드** (즉시 반영) — 운영 빈도가 높거나 위험성이 낮은 필드. 권한자가 변경하면 status 회귀 없이 즉시 반영한다.

**사유**: 운영 빈도 / 위험성 / ROI 차등. 카페 / F&B 도메인 (배민, 요기요, 스타벅스, 메가커피 등) 의 일반적인 운영 모델과 정합. 모든 변경에 검수를 걸면 시즌 메뉴 ON/OFF 같은 일상 운영이 막혀 사용자 경험과 운영 효율이 크게 떨어진다.

**적용 entity / 필드 분류 (사용자 확정)**:

| entity | 핵심 필드 | 운영 필드 | 출처 sub-phase |
|---|---|---|---|
| `stores/{id}` | `name`, `address`, `lat`, `lng`, `mainCategory`, `subCategories`, `businessRegistrationNumber` | `businessHours`, `temporaryClosed`, `closedDates`, `phoneNumber`, `imageUrls`, `interiorImages`, `description`, `notice` | sub-phase 2 |
| `brands/{brandId}/menuItems` (마스터 메뉴) | `name`, `basePrice`, `optionGroupRefs`, `mainCategoryCode`, `subCategoryId`, `description` | `visible`, `tags`, `displayOrder`, `imageUrl` | sub-phase 1 |
| `stores/{id}/menuOverrides` | `priceOverride`, `excluded` | `soldOut`, `disabledOptionGroupIds`, `disabledOptionItemIds` (이미 결정 H 보강에 정의됨) | sub-phase 3 |
| `stores/{id}/menuItems` (개인 매장) | (status 필드 없음 — 점주 모든 변경 즉시) | (위와 동일) | sub-phase 4 |
| `stores/{id}/menuItems` (브랜드 매장 한정 추가) | `name`, `basePrice`, `optionGroupRefs`, `mainCategoryCode`, `subCategoryId`, `description` | `visible`, `tags`, `displayOrder`, `imageUrl`, `disabledOption*`, `soldOut` | sub-phase 3, 5 |

**구현 패턴 (Repository 레이어)**: 두 가지 안 중 sub-phase 별 spec 에서 선택한다.

- **(a) 단일 메서드 + 변경 필드 분석**: `updateXxx(entity)` 가 변경된 필드 셋을 분석해 핵심 필드 포함 시 `status='pending'` 회귀, 운영 필드만 변경 시 status 보존.
- **(b) 메서드 분리** (권장 — Domain 레이어 의도가 명확): `updateCoreFields(entity)` 와 `updateOperationFields(entity)` 두 개로 분리. UseCase / 폼도 분리.

**잠정안**: **(b) 메서드 분리** 채택. 이유 — Domain 레이어에서 "검수 게이트로 들어가는 변경" vs "즉시 반영" 의도가 메서드 시그니처로 드러나 호출자가 실수할 여지가 줄고, 테스트 / 권한 가드도 메서드 단위로 명확히 분리된다. designer 도 두 폼을 분리할지 통합할지 자유롭게 선택할 수 있다.

**designer 위임**: 사용자 측 폼은 두 가지 모두 가능 — "매장 정보 수정" (핵심) 과 "매장 운영 정보" (운영) 두 폼으로 분리하거나, 한 폼에서 섹션을 나누고 저장 시 분기. designer 가 UX 관점에서 결정.

**status 운용**:
- 핵심 필드 변경 → `status='pending'` 회귀 + `submittedBy/At` 갱신 + `approvedBy/At` 보존 (수정 대기 라벨 식별, sub-phase 1 의 S3 / sub-phase 2 의 T2 패턴 동일)
- 운영 필드 변경 → status / 승인 메타 모두 불변. `updatedAt` 만 갱신. customer 측 즉시 반영
- 둘이 한 트랜잭션에 섞이는 경우 (예: 점주가 한 폼에서 이름과 영업시간 동시 변경) → 핵심 필드 우선 정책으로 status=pending 회귀. UI 단계에서 안내.

**비범위**: 본 결정 J 는 정책 차원의 단일 진실원 정의. 각 sub-phase spec 이 자기 entity 에 대해 Repository 메서드 시그니처 / UseCase / UI 흐름을 보강한다.

---

## 데이터 모델

### Firestore 구조

```
users/{uid}
  ├─ role: 'customer' | 'owner' | 'admin' | 'brand'      # 'brand' 신규 (결정 G)
  └─ brandId?: String                                       # role='brand' 일 때만 (결정 G, 1:1)

brands/{brandId}                                            # 신규 컬렉션
  ├─ id, name, logoUrl, description
  ├─ status: 'pending'|'approved'|'rejected'                # 신규 (결정 H)
  ├─ submittedBy?: String, submittedAt?: Timestamp
  ├─ approvedBy?: String, approvedAt?: Timestamp
  ├─ rejectedReason?: String
  ├─ createdAt, updatedAt
  └─ menuItems/{menuItemId}                                 # 마스터 메뉴 (서브컬렉션)
       ├─ id, name, imageUrl, description
       ├─ mainCategory ('coffee'|'nonCoffee'|'dessert')
       ├─ subCategoryId?
       ├─ basePrice (int, 원)
       ├─ optionGroupRefs: [{scope:'master', id}]           # master 만 허용
       ├─ tags: List<String> (['recommended'|'new'|'best'])
       ├─ visible: bool (default true)
       ├─ displayOrder
       ├─ status: 'pending'|'approved'|'rejected'           # 신규 (결정 H)
       ├─ submittedBy/At, approvedBy/At, rejectedReason
       └─ createdAt, updatedAt

stores/{storeId}
  ├─ ... (기존 필드)
  ├─ brandId?: String | null                                # 신규 (분기 키)
  ├─ status: 'pending'|'approved'|'rejected'                # 신규 (default 'approved' for legacy)
  ├─ submittedBy?: String, submittedAt?: Timestamp
  ├─ approvedBy?: String, approvedAt?: Timestamp
  ├─ rejectedReason?: String
  │
  ├─ menuItems/{menuItemId}                                 # 매장 직속
  │     # 케이스 1 (brandId == null): 개인 매장 모든 메뉴 — status 필드 NO (점주 즉시)
  │     # 케이스 2 (brandId != null): 점포 한정 추가 메뉴 — status 필드 YES (brand → admin)
  │     ├─ ... (기존 필드)
  │     ├─ scope: 'store'                                   # 항상 store
  │     ├─ tags: List<String>, visible: bool
  │     ├─ disabledOptionGroupIds: List<String>             # 점주 비활성
  │     ├─ disabledOptionItemIds: List<String>              # compositeId = "{groupId}_{itemId}"
  │     ├─ soldOut: bool                                    # 점주 토글
  │     ├─ optionGroupRefs: [{scope:'master'|'store', id}]
  │     ├─ status?: 'pending'|'approved'|'rejected'         # 신규 (브랜드 매장 한정 추가만 의미. 개인 매장은 항상 'approved' 또는 미존재)
  │     └─ submittedBy/At, approvedBy/At, rejectedReason
  │
  └─ menuOverrides/{masterMenuItemId}                       # 신규 서브컬렉션 (브랜드 매장 전용)
       ├─ masterMenuItemId (= doc.id)
       ├─ priceOverride?: int                               # null = 마스터 가격 사용
       ├─ excluded: bool (default false)                    # admin/brand: 매장에서 제외
       ├─ soldOut: bool (default false)                     # 점주 토글 (즉시)
       ├─ disabledOptionGroupIds: List<String>              # 점주 비활성 (즉시)
       ├─ disabledOptionItemIds: List<String>               # 점주 비활성 (즉시)
       ├─ status: 'pending'|'approved'|'rejected'           # 신규 (priceOverride / excluded 변경 시 사용. soldOut/disabled* 는 status 무관 즉시)
       ├─ submittedBy/At, approvedBy/At, rejectedReason
       ├─ updatedAt
       └─ updatedBy ('admin'|'brand'|'owner')               # 추적용
```

> **menuOverrides 의 status 운용 규칙** (결정 H 보강):
> - `priceOverride` / `excluded` 변경 → `status` 사용 (brand → admin 승인 게이트)
> - `soldOut` / `disabledOption*` 변경 → `status` 무관 점주 즉시 반영
> - 따라서 status 가 `pending` 인 동안에도 점주의 즉시 토글은 정상 동작. customer 머지 단계에서 `status == approved` 면 `priceOverride` / `excluded` 적용, `pending`/`rejected` 면 마스터 가격/노출 유지.

### Domain Entity 요약

- 신규: `BrandEntity`, `MenuItemScope` (enum: `brand`|`store`), `EntityApprovalStatus` (`pending`|`approved`|`rejected`, 기존 `StoreApprovalStatus` 의 의미 확장), `MenuOverrideEntity`
- 수정: `MenuItemEntity` (`scope`, `brandId?`, `tags`, `visible`, `disabledOption*`, `status?`, 승인 메타), `StoreEntity` (`brandId`, `status`, 승인 메타)
- DTO 직렬화 default:
  - `MenuItemScope` 누락 시 `store`
  - `EntityApprovalStatus` 누락 시 `approved` (legacy 안전)
  - `tags`, `disabledOption*` 누락 시 `[]`
  - `visible` 누락 시 `true`

상세 entity 필드 / Repository 인터페이스 / UseCase 명세는 각 sub-phase spec 에서 정의한다.

---

## role 진입 / 라우팅

```dart
// RoleRouter
switch (userRole) {
  case UserRole.admin:    return const AdminScaffold();    // sub-phase 1, 2, 3 의 승인 큐
  case UserRole.brand:    return const BrandScaffold();    // sub-phase 1, 3 (브랜드 등록 / 마스터 메뉴 / 매장 커스텀)
  case UserRole.owner:    return const OwnerScaffold();    // sub-phase 2, 4, 5 (매장 등록 / 메뉴 / 옵션·품절)
  case UserRole.customer: return const CustomerScaffold(); // 변경 없음
}
```

- 페이지 이동은 `Navigator.push(MaterialPageRoute)` 패턴 (router.dart 없음).
- AdminScaffold / BrandScaffold / OwnerScaffold 의 하단 탭 구성은 각 sub-phase 에서 확정.

---

## Customer 측 데이터 머지 규칙 (Customer 측 비변경 보장)

`MenuItemRepositoryImpl.watchByStore(storeId)` 의 새로운 동작:

```text
1. store = await storeRepository.getById(storeId)
2. if store.status != approved: return Stream.value([])  // 비공개
3. if store.brandId == null:
     return menuItemRemoteDataSource.streamByStore(storeId)
       .map(items =>
         items.where(visible == true)
              .map(applyOptionDisableFilter)
              .toList())
4. else (브랜드 매장):
     a. masterStream    = brandRemoteDataSource.streamMenuItems(brandId)
                            .where(status == approved && visible)
                            .map(_ => MenuItemEntity(scope=brand, storeId=storeId, ...))
     b. overrideStream  = menuOverrideRemoteDataSource.streamByStore(storeId)
                            // soldOut/disabledOption* 는 status 무관 즉시 반영
                            // priceOverride/excluded 는 status == approved 일 때만 적용
     c. storeOnlyStream = menuItemRemoteDataSource.streamByStore(storeId)
                            .where(scope == store && status == approved && visible)
     d. combine (Rx.combineLatest3):
          for each masterMenu where masterMenu.visible && masterMenu.status == approved:
            override = overrides[masterMenu.id]
            // excluded 는 status==approved 일 때만 적용
            if override?.status == 'approved' && override.excluded == true: skip
            yield masterMenu.copyWith(
              basePrice              = (override?.status == 'approved' ? override.priceOverride : null) ?? masterMenu.basePrice,
              soldOut                = (override?.soldOut == true) || masterMenu.soldOut,
              disabledOptionGroupIds = override?.disabledOptionGroupIds ?? [],
              disabledOptionItemIds  = override?.disabledOptionItemIds ?? [],
            )
          for each storeOnlyMenu where storeOnlyMenu.visible && status == approved: yield as-is
     e. sort by displayOrder
```

**옵션 비활성 필터**: customer 측 옵션 fetch 단계가 `disabledOption*` 를 적용. 이 필터는 `OptionRepository` 또는 customer presentation 안의 옵션 렌더링 단계에서 처리 — Repository 머지 결과의 `MenuItemEntity.disabledOption*` 필드만 보면 된다 (presentation 코드 변경은 옵션 렌더링 부분만 최소 수정 또는 무영향).

**Customer 측 비변경 보장**:
- `MenuItemRepository.watchByStore` 시그니처 불변 → `StoreMenuPage` / `MenuItemDetailPage` / Phase 1c 즐겨찾기 / Phase 2 추천 / 시드 코드 모두 무영향.
- `StoreRepository` 의 customer 측 read 메서드 (`getNearbyStores` 등) 는 내부에서 `status == approved` 필터 적용 → 검색 호출부 변경 없음.

---

## sub-phase 인덱스

6개 sub-phase 로 분할. 각 sub-phase 는 본 umbrella 의 결정사항 / 데이터 모델 / 권한 매트릭스를 그대로 따른다.

| # | sub-phase | 디렉토리 | 핵심 산출 | 의존 |
|---|---|---|---|---|
| 1 | brand_master | `1_brand_master/` | brand role + BrandScaffold + 브랜드 등록 + 마스터 메뉴 CRUD + 가격 변경/삭제 cascade + 복제. admin 측 brand/마스터 메뉴 승인 큐 | (없음) |
| 2 | store_registration_approval | `2_store_registration_approval/` | 점주 개인 매장 등록 (status=pending → admin 승인). admin 매장 승인 큐. owner 측 status 라벨 | (없음, 1과 독립) |
| 3 | brand_store_customization | `3_brand_store_customization/` | brand 가 마스터 기반 매장 커스텀 (가격 오버라이드 + 점포 한정 추가 메뉴) → admin 승인. **(sub-phase 6 진입 후 brand 매장 등록 흐름 폐기 — 점주가 brandKey 입력해서 등록)** | 1, 2 |
| 4 | owner_personal_menu | `4_owner_personal_menu/` | 개인 매장 점주 메뉴 CRUD (즉시 반영). 복제 버튼 | 2 |
| 5 | owner_options_soldout | `5_owner_options_soldout/` | 점주 옵션 비활성화 + 품절 토글 (개인/브랜드 공통, 즉시 반영). MenuOptionDisableSheet | 1, 2, 3, 4 |
| 6 | upgrade_to_brand | `6_upgrade_to_brand/` | brand 가입 흐름을 점주 패턴으로 재설계 — `UpgradeToBrandUseCase` + 더보기 CTA + 다이얼로그. **brandKey 자동 발급 (admin 승인 시 `BR-XXXXXXXX` 8자리 영문숫자, 32 char alphabet)** + 점주 매장 등록 폼에 brandKey 입력 토글 + BrandStoreFormPage 폐기 + BrandStoresPage read-only 갱신 | 1, 2, 3 |

### 의존 순서 (권장 작업 순서)

```
1_brand_master       (독립 시작 가능)
       ↓
2_store_registration_approval   (1과 독립이지만 워크플로우상 1 다음)
       ↓
3_brand_store_customization     (1 + 2 모두 의존)
       ↓
4_owner_personal_menu           (2 의존)
       ↓
5_owner_options_soldout         (1, 2, 3, 4 모두 깔린 후)
       ↓
6_upgrade_to_brand              (1, 2, 3 의존. brand 가입 흐름 재설계 + brandKey 도입)
```

### 각 sub-phase 진입 절차

1. 본 umbrella 의 결정사항 / 데이터 모델 / 권한 매트릭스를 단일 진실원으로 참조.
2. 해당 sub-phase 디렉토리의 `spec.md` 를 architect 가 보강 (스켈레톤 → 본 spec).
3. `spec.md` 확정 후 `/designer` 호출 → `design.md`.
4. 디자인 확정 후 `/developer` 호출 → 구현 + `implementation.md`.
5. 구현 완료 후 `/tester` 호출 → `test_report.md`.
6. PASS 시 다음 sub-phase 진입.

각 sub-phase 산출물 위치:

```
docs/tasks/admin_menu_management/[N]_[name]/
├── spec.md
├── design.md
├── implementation.md
└── test_report.md
```

---

## 신규 패키지 / 환경

- `rxdart` (`combineLatest3` 머지용, data 레이어에서만 사용) — sub-phase 3 진입 시 추가
- `image_picker` (이미 점주 매장 이미지에서 사용 중) — 추가 작업 없음
- Firestore 보안 규칙 / Storage 보안 규칙 — 별도 task `firestore_rules` (본 umbrella 비범위)
- `--dart-define` / 환경 변수 — 추가 없음

---

## 산출물 위치

- 본 umbrella spec: `docs/tasks/admin_menu_management/spec.md` (현재 문서)
- sub-phase 5종: `docs/tasks/admin_menu_management/[1-5]_*/spec.md`
- 각 sub-phase 의 design / implementation / test_report 는 sub-phase 진입 시 작성
