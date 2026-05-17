# sub-phase 5 — owner_options_soldout 기능 명세

> **상태**: APPROVED — architect 보강 완료
>
> **umbrella 단일 진실원**: 데이터 모델 / 결정사항 (1~12, A~F, G/H/I/J) / 권한 매트릭스 / role 라우팅 / customer 측 머지 규칙 → [`../spec.md`](../spec.md). 본 sub-phase 는 그 결정을 그대로 따른다 — 재서술하지 않는다.
>
> **sub-phase 1 산출물 재사용**: `MenuItemEntity` 의 `disabledOptionGroupIds` / `disabledOptionItemIds` / `soldOut` 필드 / `_VisibleToggleButton` 인라인 토글 패턴 / `MenuItemListTile` / `OptionGroupSelector` 위젯 골격 / `EntityApprovalStatus` enum → [`../1_brand_master/spec.md`](../1_brand_master/spec.md).
>
> **sub-phase 2 산출물 재사용**: `OwnerMyStorePage` 의 매장 상세 영역 / 운영 정보 CTA 영역 → [`../2_store_registration_approval/spec.md`](../2_store_registration_approval/spec.md).
>
> **sub-phase 3 산출물 재사용**: `MenuOverrideEntity` 의 `disabledOptionGroupIds` / `disabledOptionItemIds` / `soldOut` 필드 + `priceOverride` / `excluded` / status / 승인 메타 / `MenuOverrideRepository.upsertMenuOverrideOperation` (또는 동등 — 운영 필드 partial update 진입점) / `MenuOverrideRemoteDataSource` / `MenuItemRepositoryImpl.watchByStore` 의 case B 머지 (`Rx.combineLatest3`) / `OwnerMyStorePage` 의 brandId 분기 (브랜드 매장 = 핵심 정보 read-only) → [`../3_brand_store_customization/spec.md`](../3_brand_store_customization/spec.md).
>
> **sub-phase 4 산출물 재사용**: `MenuItemRepository.updateStoreOnlyMenuOperation` (운영 필드 partial update — 본 sub-phase 가 `soldOut` / `disabledOption*` 필드만 변경) / `_assertOwnerOfPersonalStore` ownership helper / `OwnerStoreMenuListPage` / `OwnerStoreMenuDetailPage` / `MenuItemRepositoryImpl` 의 brandId 분기 (개인 매장 = 즉시 반영 / 브랜드 매장 점포 한정 메뉴 = 운영 필드 즉시 반영) → [`../4_owner_personal_menu/spec.md`](../4_owner_personal_menu/spec.md).

---

## 개요

- **목적**: `admin_menu_management` 의 다섯 번째 (마지막) sub-phase. **점주의 옵션 비활성 + 품절 토글 — 개인 매장 / 브랜드 매장 공통, admin 승인 게이트 없음, customer 즉시 반영** (umbrella 권한 매트릭스 결정 I + 결정 J 의 운영 필드 정책).
- **작업 유형**: 기존 sub-phase 1/3/4 의 entity 필드 (`disabledOption*` / `soldOut`) 와 Repository 운영 필드 메서드를 활용하는 **순수 추가** sub-phase. 데이터 필드 신규 추가 없음. 화면 신설 1종 (브랜드 매장용) + 공통 시트 1종 + sub-phase 4 화면 확장.
- **결정적 비기능 목표**: customer 측 Repository 인터페이스 변경 0. `MenuItemRepository.watchByStore(storeId)` 시그니처 / 동작 모두 불변. 본 sub-phase 가 활성화하는 옵션 필터는 **옵션 fetch 단계** (`OptionRepository`) 에서 처리 — 메뉴 머지 결과의 `disabledOption*` 필드만 보면 됨.
- **영향 범위**:
  - 화면(owner / 개인 매장): `OwnerStoreMenuListPage` (sub-phase 4) 카드에 **품절 토글** 추가 (visible 토글과 동등 인라인) + 카드 액션에 **"옵션 관리"** 진입 추가. `OwnerStoreMenuDetailPage` (sub-phase 4) 에 옵션 관리 / 품절 토글 액션 추가.
  - 화면(owner / 브랜드 매장): `OwnerMyStorePage` 의 브랜드 매장 분기 (sub-phase 3 산출) 에 **"메뉴 옵션·품절 관리"** CTA 추가. 신규 화면 `OwnerBrandStoreMenusPage` — 브랜드 매장의 머지된 메뉴 리스트(마스터 + override + 점포 한정) 노출 + 카드별 품절 토글 + 옵션 관리 진입.
  - 화면(공통): `MenuOptionDisableSheet` 신규 BottomSheet — 옵션 그룹/항목 토글 UI.
  - 화면(brand / admin / customer): **변경 없음**. customer 측은 옵션 fetch 단계에서 자동 필터.
  - Domain: 변경 없음 (모든 entity 필드 sub-phase 1/3 에서 정의 완료). Repository 보강 — 운영 필드 partial update 메서드 확장 (sub-phase 3/4 의 시그니처 그대로 활용 + 일부 신규 헬퍼). UseCase 신규 6종.
  - Data: `MenuItemRepositoryImpl` / `MenuOverrideRepositoryImpl` 의 운영 필드 update 메서드 보강 — `disabledOption*` / `soldOut` 필드 partial update + ownership 검증. `OptionRepositoryImpl` (Phase 1a 산출) 보강 — 옵션 fetch 시 menuItem / override 의 `disabledOption*` 필드를 받아 그룹/항목 필터.
  - Presentation: `presentation/owner/store_menu/` (sub-phase 4) 카드 / 상세 갱신. `presentation/owner/brand_store/` (신규) 트리. `presentation/common/option_disable_sheet/` (신규) 트리.
  - 라우팅: 변경 없음 (`Navigator.push(MaterialPageRoute)` 유지).
  - 패키지: 추가 없음.
  - 테스트: customer Phase 1a~2 / sub-phase 1/2/3/4 회귀 강조. 옵션 비활성 / 품절 → customer 즉시 반영 / status=pending override 와 무관하게 즉시 반영 / 브랜드 매장 점주의 핵심 정보 read-only 회귀 (sub-phase 3 동작 그대로).

---

## 범위 / 비범위

### 범위 (본 sub-phase)

#### A. 점주의 옵션 비활성 (개인 매장 + 브랜드 매장 공통)

- 점주는 자기 매장의 메뉴별로 **옵션 그룹 / 옵션 항목** 비활성화 가능
- 즉시 반영 — admin 승인 게이트 없음 (umbrella 결정 I)
- 데이터 저장 위치는 매장 종류 + 메뉴 종류에 따라 분기:
  - **개인 매장 (`store.brandId == null`)** : `stores/{storeId}/menuItems/{menuItemId}.disabledOptionGroupIds` / `.disabledOptionItemIds` 필드 partial update (sub-phase 4 의 `MenuItemEntity` 필드)
  - **브랜드 매장 마스터 메뉴 ref (`store.brandId != null` + 메뉴 scope 가 brand)** : `stores/{storeId}/menuOverrides/{masterMenuItemId}.disabledOptionGroupIds` / `.disabledOptionItemIds` 필드 upsert (override 가 없으면 신규 생성, 있으면 partial update — sub-phase 3 의 `MenuOverrideEntity` 필드)
  - **브랜드 매장 점포 한정 추가 메뉴 (`store.brandId != null` + 메뉴 scope 가 store)** : `stores/{storeId}/menuItems/{menuItemId}.disabledOptionGroupIds` / `.disabledOptionItemIds` 필드 partial update (sub-phase 4 의 `MenuItemEntity` 필드, 즉시 반영 — sub-phase 3 의 운영 필드 정책)
- customer 측 옵션 fetch 단계에서 비활성된 옵션 그룹 / 항목 자동 제거 (W4 결정 — `OptionRepository` 단계)
- compositeId 패턴: `disabledOptionItemIds` 의 항목 ID 는 `"{groupId}_{itemId}"` 복합 키 (sub-phase 1 의 결정 그대로)

#### B. 점주의 품절 토글

- 위 A 와 동일한 분기:
  - **개인 매장** : `stores/{storeId}/menuItems/{menuItemId}.soldOut` 필드 partial update
  - **브랜드 매장 마스터 메뉴 ref** : `stores/{storeId}/menuOverrides/{masterMenuItemId}.soldOut` 필드 upsert
  - **브랜드 매장 점포 한정 추가 메뉴** : `stores/{storeId}/menuItems/{menuItemId}.soldOut` 필드 partial update
- customer 측에서 `soldOut == true` 메뉴는 회색 오버레이 + "품절" 라벨 (Phase 1a 패턴 그대로 — `MenuItemEntity.soldOut` 필드 활용)
- 즉시 반영

#### C. 화면 구조 — 개인 매장 (sub-phase 4 화면 확장)

- `OwnerStoreMenuListPage` (sub-phase 4 산출) 갱신:
  - 카드에 **품절 토글 인라인** 추가 (sub-phase 1 의 `_VisibleToggleButton` 패턴과 동등 배치 — visible 토글 옆 / 아래) — W5 결정 (a)
  - 카드 액션 시트 (long-press / 메뉴 버튼) 에 **"옵션 관리"** 항목 추가 — W6 결정 (a) BottomSheet 진입
  - 카드 시각: `soldOut == true` 면 카드 회색 + "품절" 뱃지 (sub-phase 1 의 visible=false 시각과 유사하나 다른 의미)
- `OwnerStoreMenuDetailPage` (sub-phase 4 산출) 갱신:
  - 액션 영역에 **"옵션 관리"** 버튼 + **품절 토글** 추가
  - "옵션 관리" 탭 시 `MenuOptionDisableSheet` 진입 (BottomSheet, modal)
  - 품절 토글 즉시 반영
- 진입 경로: `OwnerMyStorePage` → "메뉴 관리" CTA (sub-phase 4 V9) → `OwnerStoreMenuListPage` → 카드/상세 → 옵션 관리 / 품절

#### D. 화면 구조 — 브랜드 매장 (`OwnerMyStorePage` brandId 분기 확장)

- `OwnerMyStorePage` (sub-phase 3 의 brandId 분기) 갱신:
  - 브랜드 매장 분기에 **"메뉴 옵션·품절 관리"** CTA 추가 — W8 결정 (b)
  - 노출 조건: `store.brandId != null && store.status == EntityApprovalStatus.approved`
  - 핵심 정보 수정 / 메뉴 추가/삭제 / 가격 변경 등은 여전히 비노출 (sub-phase 3 결정 그대로)
- `OwnerBrandStoreMenusPage` (신규) — 브랜드 매장 점주용 메뉴 리스트:
  - 진입 시 `MenuItemRepository.watchByStore(storeId)` 호출 — case B 머지 결과 (마스터 메뉴 + override 머지 + 점포 한정 메뉴) 반환
  - 카드 구성:
    - 마스터 메뉴 ref (scope=brand): 머지된 결과의 메뉴 카드. 카드에 `soldOut` 토글 + "옵션 관리" 액션. 마스터 메뉴 자체 정보 (이름/가격/이미지/카테고리) 는 read-only.
    - 점포 한정 메뉴 (scope=store): sub-phase 4 의 카드 패턴과 동일 (단 점주는 추가/삭제 권한 없음 — sub-phase 3 결정).
  - 카드 시각:
    - 마스터 메뉴 ref + override 의 `excluded == true` (admin 승인된 경우) → customer 측 머지에서 제외되므로 본 화면에서도 카드 비노출 또는 "매장 제외됨" 안내 (W7 추가 결정)
    - `soldOut == true` 인 메뉴 → 회색 + "품절" 뱃지
  - FAB / 추가 / 삭제 액션 없음 (sub-phase 3 결정 — brand 만 메뉴 추가 가능)
  - 카드 long-press / 메뉴 → 액션 시트 ("옵션 관리" 만 노출, 수정/삭제/복제 미노출)

#### E. 공통 위젯 — `MenuOptionDisableSheet` (신규)

- 진입: 개인 매장 / 브랜드 매장 양쪽에서 `showModalBottomSheet` 로 호출. 메뉴 1개에 대한 옵션 그룹/항목 비활성 토글 UI.
- 입력:
  - `storeId` (필수)
  - `menuItemId` (필수 — 개인 매장 메뉴 / 브랜드 매장 점포 한정 메뉴 / 마스터 메뉴 ref 모두 동일하게 menuItemId)
  - `menuType: 'personal' | 'brandMasterRef' | 'brandStoreOnly'` enum (sheet 가 저장 시 분기 호출)
  - `currentDisabledGroupIds: List<String>` / `currentDisabledItemIds: List<String>` (현재 상태 — 그룹은 그룹id, 항목은 compositeId)
- 표시:
  - 메뉴의 `optionGroupRefs` 를 fetch (`OptionGroupRepository.getOptionGroupsForMenuItem(menuItemId)` Phase 1a 재사용)
  - 그룹별 row: 그룹 이름 / 토글 (활성 / 비활성). 비활성 그룹은 회색 + "비활성" 라벨
  - 그룹 펼치면 항목별 row: 항목 이름 / 가격 / 토글
  - 그룹 비활성 시 그룹 내 모든 항목도 비활성으로 간주 (항목 토글 disabled — 그룹부터 활성화하라고 안내)
- 저장:
  - 닫기 시 변경된 disabledOption* 가 있으면 분기 호출:
    - `menuType == 'personal'` 또는 `'brandStoreOnly'` → `UpdateMenuItemDisabledOptionsUseCase` (`MenuItemRepository.updateMenuItemOperationFields`)
    - `menuType == 'brandMasterRef'` → `UpdateOverrideDisabledOptionsUseCase` (`MenuOverrideRepository.upsertOverrideOperation` — 없으면 생성, 있으면 partial update)
  - 즉시 반영 SnackBar
- 변경 없으면 무동작 닫기

#### F. customer 측 옵션 비활성 필터 — W4 결정 (b) `OptionRepository` 단계

- 적용 위치: **옵션 fetch 단계** (`OptionRepositoryImpl.getOptionGroupsForMenuItem` 또는 동등). 메뉴 머지 단계 (`MenuItemRepositoryImpl.watchByStore`) 는 단순히 `MenuItemEntity.disabledOption*` 필드를 채워서 반환만 함 (이미 sub-phase 3 의 case B 머지가 override 의 `disabledOption*` 를 머지된 메뉴에 박아주므로 본 sub-phase 가 변경할 부분 없음 — 단 머지 시 status 무관 즉시 반영 조건 재확인 필요).
- 동작:
  ```text
  OptionRepository.getOptionGroupsForMenuItem(menuItemId, disabledGroupIds, disabledItemIds):
    1. 옵션 그룹 fetch (master + store optional)
    2. for each group:
         if group.id in disabledGroupIds: skip (그룹 통째로 제외)
         else:
           filtered_items = group.items.where(item.id not in disabledItemIds_for_this_group)
           # disabledItemIds 의 compositeId 를 group.id 로 분리 후 매칭
           yield group.copyWith(items: filtered_items)
  ```
- 호출자 (Phase 1a 의 `MenuItemDetailPage` Provider) 가 `MenuItemEntity.disabledOptionGroupIds` / `disabledOptionItemIds` 를 인자로 전달
- → 옵션 picker UI 는 자동으로 비활성 옵션 미노출. presentation 코드 변경 최소 (Provider 의 호출 인자만 추가)

#### G. customer 측 머지 보강 (회귀 안전망)

- `MenuItemRepositoryImpl.watchByStore` 의 case B 머지 (sub-phase 3 산출) 가 **override 의 `disabledOption*` / `soldOut` 을 status 무관 즉시 반영** 하는지 재확인:
  - umbrella 데이터 머지 규칙 (`menuOverrides 의 status 운용 규칙`) 에 따라:
    - `priceOverride` / `excluded` 변경 → status='approved' 일 때만 머지에 적용
    - `soldOut` / `disabledOption*` 변경 → status 무관 즉시 머지 (운영 필드)
  - sub-phase 3 의 case B 가 이 규칙을 정확히 따르는지 본 sub-phase 가 회귀 검증 (tester)
- 본 sub-phase 가 case B 머지 로직을 변경하는 것은 아니나, **기능 활성화 검증** 을 본 sub-phase 의 책임으로 둔다.

#### H. 즉시 반영 / status 무관

- 모든 토글 / 비활성 변경 → `status` 변경 없음 (admin 승인 게이트 없음)
- 기존 override (`status='pending'` / `'rejected'`) 가 있어도 `disabledOption*` / `soldOut` 만 partial update — status 보존
- 신규 override 가 점주 토글로 처음 생성되는 경우 (W2 — 점주가 마스터 메뉴 ref 에 처음 품절 토글 시) → `status='approved'` 즉시 박힘 + 승인 메타 모두 null + `priceOverride=null` + `excluded=false` (운영 필드만 값. 검수 게이트 들어갈 필드는 비어있어서 의미 없음)
- customer 측 stream 자동 갱신

### 비범위

- **점주 메뉴 CRUD** → sub-phase 4 (이미 완료)
- **마스터 메뉴 자체 옵션 그룹 변경 / 마스터 메뉴 CRUD** → sub-phase 1
- **brand 가 매장 커스텀 (가격 오버라이드 / 점포 제외 / 점포 한정 메뉴 등록)** → sub-phase 3
- **개인 매장 등록 / 매장 등록 승인** → sub-phase 2
- **admin 승인 게이트** → 본 sub-phase 비범위 (운영 필드라 즉시 반영)
- **Firestore 보안 규칙 / 인덱스** → 별도 task `firestore_rules` / `firestore_indexes`
- **옵션 그룹 자체 CRUD UI** → 별도 phase `admin_option_group_management`
- **마이그레이션 자동 스크립트** → 시드 매장 / 기존 매장은 fromFirestore default 로 흡수 (`disabledOption*=[]`, `soldOut=false`, override 미존재)
- **시드 데이터 변경** → W10 결정 — 시드는 그대로. 점주가 직접 토글하면 검증 가능

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - **sub-phase 1 (brand_master)** — `MenuItemEntity.disabledOption*` / `soldOut` 필드 / `EntityApprovalStatus` enum / `MenuItemListTile` / `_VisibleToggleButton` 패턴 / `OptionGroupSelector` (단 본 sub-phase 는 비활성화 UI 라 별도 위젯 — `MenuOptionDisableSheet`)
  - **sub-phase 2 (store_registration_approval)** — `OwnerMyStorePage` 골격 / 매장 status 라벨
  - **sub-phase 3 (brand_store_customization)** — `MenuOverrideEntity.disabledOption*` / `soldOut` / `priceOverride` / `excluded` / status / 승인 메타 / `MenuOverrideRepository` / `MenuOverrideRemoteDataSource` / `MenuItemRepositoryImpl.watchByStore` 의 case B 머지 / `OwnerMyStorePage` 의 brandId 분기
  - **sub-phase 4 (owner_personal_menu)** — `MenuItemRepository.updateStoreOnlyMenuOperation` / ownership helper / `OwnerStoreMenuListPage` / `OwnerStoreMenuDetailPage` / `MenuItemRepositoryImpl` 의 brandId 분기
- **진입 조건**:
  - umbrella `spec.md` APPROVED (완료)
  - sub-phase 1 / 2 / 3 / 4 모두 PASS
  - 테스트용 데이터:
    - 개인 매장 1개 (sub-phase 4 산출 메뉴 2~3개 보유, optionGroupRefs 포함)
    - 브랜드 매장 1개 (sub-phase 3 산출 — 마스터 메뉴 ref 머지 결과 + 점포 한정 메뉴 1~2개 보유)
    - admin / brand / 점주 / customer 계정 각 1개

---

## 확정된 결정사항 (sub-phase 한정)

> umbrella 결정 1~12 / A~F / G/H/I/J 와 sub-phase 1 결정 S1~S10, sub-phase 2 결정 T1~T10, sub-phase 3 결정 U1~U?, sub-phase 4 결정 V1~V10 은 단일 진실원 그대로 따른다. 여기서는 본 sub-phase 한정 결정만 기록한다.

### W1. Repository 메서드 — **(b) 재사용 + 운영 필드 partial update 활용 채택**

- 후보:
  - (a) 신규 분리 — `toggleSoldOut*` / `updateDisabledOptions*` 메서드 추가
  - (b) 재사용 — sub-phase 3 의 `MenuOverrideRepository.upsertMenuOverrideOperation` (운영 필드 upsert) + sub-phase 4 의 `MenuItemRepository.updateStoreOnlyMenuOperation` (운영 필드 partial update) 활용. UI 가 변경된 필드만 entity 에 담아 전달.
- **채택**: **(b) 재사용**. 이유:
  - 운영 필드 update 메서드는 partial update 라 자연스럽게 `soldOut` / `disabledOption*` 만 갱신 가능. UI 가 변경 필드만 담아서 전달하면 됨.
  - sub-phase 3/4 의 결정 J 메서드 분리 정책 (Core/Operation) 과 정합. 본 sub-phase 의 변경은 **운영 필드만** 다루므로 Operation 메서드 호출이 자연스러움.
  - 신규 메서드 추가 시 시그니처 폭증 — `toggleSoldOutForPersonal` / `toggleSoldOutForBrandRef` / `toggleSoldOutForBrandStoreOnly` / `updateDisabledOptions*` 등 6종 추가 필요. 재사용으로 분기는 RepositoryImpl 내부에서 처리 (sub-phase 4 의 brandId 분기 패턴 그대로).
- **단**, MenuOverride 측은 본 sub-phase 가 처음 활용. sub-phase 3 의 운영 필드 partial update 메서드명은 `upsertMenuOverrideOperation` 으로 가정 (sub-phase 3 spec 의 명명 — developer 가 sub-phase 3 implementation 확인 후 정확한 시그니처 매칭). 만약 sub-phase 3 가 운영 필드 메서드를 구현하지 않았다면 본 sub-phase 가 신규 추가 (Repository 인터페이스에 운영 필드 메서드 정의 — `MenuOverrideRepository.updateOverrideOperationFields(MenuOverrideEntity)` — 이름은 sub-phase 3 의 인터페이스 룩과 매칭).
- 본 sub-phase 가 신규 추가하는 메서드 (위 가정에 따라 0~2개):
  - **(필요 시)** `MenuOverrideRepository.updateOverrideOperationFields(MenuOverrideEntity item)` — sub-phase 3 가 운영 필드 메서드를 구현하지 않은 경우만 본 sub-phase 가 추가. 동작: `disabledOption*` / `soldOut` partial update + status 보존 + override 가 없으면 신규 생성 (`status='approved'`, 승인 메타 null, `priceOverride=null`, `excluded=false`).
  - 현재까지 **sub-phase 3 가 이 메서드를 정의/구현했다고 가정** (sub-phase 3 spec 의 결정 사항이 운영 필드 partial update 를 다루도록 되어있음).
  - developer 가 sub-phase 3 implementation 확인 시점에 메서드 존재 여부 검증. 없으면 본 sub-phase 가 신규 추가하고 implementation.md 에 명시.

### W2. 브랜드 매장 마스터 메뉴 비활성/품절 — **upsert 패턴 채택 (override 신규 생성 시 status='approved')**

- 마스터 메뉴 자체는 brand 가 관리. 점주는 이 메뉴에 대한 매장 단위 override 만 조작.
- 기존 override 가 없는 상태에서 점주가 처음 품절/비활성 토글하면:
  - 신규 `MenuOverrideEntity` 문서 생성: `priceOverride=null`, `excluded=false`, `disabledOption*=...` (변경된 값), `soldOut=...` (변경된 값), `status='approved'` (검수 게이트 들어갈 필드가 비어있으므로 즉시 approved), 승인 메타 모두 null, `submittedBy=currentUid`, `submittedAt=now` (추적용 — admin 이 점주 운영 데이터를 식별하기 위해).
- 기존 override 가 있는 상태에서 점주가 토글:
  - operation update — `disabledOption*` / `soldOut` 만 partial update + status 보존 (priceOverride / excluded 변경 시 검수 게이트는 별도 흐름 — sub-phase 3)
- override id = `${storeId}_${masterMenuItemId}` (composite) — sub-phase 3 결정 그대로
- **사유**: 운영 필드 변경 (점주 즉시) 만 가지고 새 override 를 만드는 경우는 어색하지 않음 — 검수 게이트 들어갈 필드 (`priceOverride` / `excluded`) 가 비어있으니 admin 이 처리할 게 없어 자연스럽게 approved 박힘. customer 머지에서도 `priceOverride==null` 이면 마스터 가격 그대로 사용, `excluded==false` 이므로 노출 정합.
- **submittedBy 박는 이유**: 추적용 (점주가 토글한 override 임을 admin 이 식별 가능). `updatedBy` 필드 (sub-phase 3 의 `'admin'|'brand'|'owner'`) 도 'owner' 로 박아 명확화.

### W3. 점주의 권한 검증 — **분리 채택 (개인 매장 / 브랜드 매장 helper 분리)**

- 후보:
  - (a) 통합 — 단일 helper (예: `_assertOwnerOfStore(storeId, allowBrand: bool)`) 가 매장 종류 분기
  - (b) 분리 — `_assertOwnerOfPersonalStore(storeId)` (sub-phase 4) + `_assertOwnerOfBrandStore(storeId)` (신규)
- **채택**: **(b) 분리**. 이유:
  - 두 케이스의 검증 조건이 다름:
    - 개인 매장: `store.brandId == null && store.ownerId == currentUid` (또는 admin)
    - 브랜드 매장: `store.brandId != null && store.ownerId == currentUid` (또는 admin) — `currentBrandId` 매칭은 brand 측이 아니라 점주 측이므로 brand 검증 불필요
  - RepositoryImpl 의 분기에 맞춤. 명시적 가드.
  - sub-phase 4 의 helper 와 충돌 없음 — 이름이 다름.
- 신규 helper: `_assertOwnerOfBrandStore(storeId)` — `MenuItemRepositoryImpl` 와 `MenuOverrideRepositoryImpl` 양쪽에서 활용 (또는 공통 base 또는 sub-phase 1 의 `currentUidGetter` / `currentRoleGetter` 활용 - developer 재량).

### W4. customer 측 옵션 비활성 필터 적용 위치 — **(b) `OptionRepository` 단계 채택**

- 후보:
  - (a) `MenuItemRepository.watchByStore` 의 머지 안 — 메뉴 단계
  - (b) `OptionRepository.getOptionGroupsForMenuItem` 안 — 옵션 단계
  - (c) Phase 1a 의 `MenuItemDetailPage` 측 Provider — UI 단계
- **채택**: **(b) `OptionRepository` 단계**. 이유:
  - 옵션 fetch 시 menuItem 의 `disabledOptionGroupIds` / `disabledOptionItemIds` 만 받아서 필터하면 됨 — 메뉴 머지 로직과 분리되어 책임 명확.
  - (a) 는 메뉴 머지 결과에 옵션 자체를 박아야 하는데, 옵션은 별도 컬렉션이므로 N+1 쿼리 발생.
  - (c) 는 presentation 단 변경 — Repository 인터페이스를 거치지 않으므로 테스트 / 재사용성 떨어짐.
- **구현 패턴**:
  - `OptionRepository.getOptionGroupsForMenuItem` 시그니처 보강 (또는 새 메서드 추가):
    ```dart
    // Phase 1a 시그니처 (가정):
    // Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(String menuItemId);
    //
    // 본 sub-phase 보강안:
    Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
      String menuItemId, {
      List<String> disabledGroupIds = const [],
      List<String> disabledItemIds = const [],
    });
    ```
  - 호출자 (Phase 1a 의 `MenuItemDetailPage` Provider) 가 `MenuItemEntity.disabledOption*` 를 인자로 전달.
  - **시그니처 변경 영향**: 호출자가 1~2곳 (Phase 1a 의 옵션 picker provider) — 본 sub-phase 가 호출자 갱신.
  - 또는 새 메서드 (`getFilteredOptionGroupsForMenuItem`) 로 분리 + Phase 1a 호출자가 새 메서드로 전환 — developer 재량.

### W5. 카드 인라인 품절 토글 위치 — **카드 인라인 visible 토글 옆 동등 배치 채택**

- 후보:
  - (a) 카드 인라인 — visible 토글 옆 / 아래 (sub-phase 1 의 `_VisibleToggleButton` 패턴)
  - (b) 액션 시트 — long-press / 메뉴 → "품절 처리" 항목
- **채택**: **(a) 카드 인라인 — visible 토글 옆 동등 배치**. 이유:
  - 자주 쓰는 운영 액션은 카드에서 즉시 토글이 자연스러움 (배민 / 메가커피 / 스타벅스 같은 도메인의 일반적 운영 패턴).
  - sub-phase 1 의 visible 토글과 동등한 UX — visible 도 운영 필드, 품절도 운영 필드.
- 액션 시트에는 **"옵션 관리"** 만 노출 (수정 / 복제 / 삭제 는 sub-phase 4 산출 그대로 — 단 브랜드 매장 점주는 수정/복제/삭제 미노출).
- 카드 시각:
  - `visible == false` → 카드 흐림 + "비공개" 라벨 (sub-phase 1 동작)
  - `soldOut == true` → 카드 흐림 + "품절" 라벨 (본 sub-phase)
  - 둘 다 true → "품절" 라벨 우선 (운영 빈도 / 의미가 더 명확)

### W6. 옵션 비활성 화면 — **(a) BottomSheet 채택**

- 후보:
  - (a) `MenuOptionDisableSheet` (BottomSheet)
  - (b) `MenuOptionDisablePage` (Navigator.push)
- **채택**: **(a) BottomSheet**. 이유:
  - 옵션 그룹 / 항목 토글은 단순 작업. 페이지 전환 부담 최소화.
  - 시트 안에 ListView + 각 그룹 row + 펼치면 항목 row + 토글 + 닫기.
  - 시트 닫기 시 변경 사항 저장 (또는 명시적 "저장" 버튼 — designer 결정).
- 시트 크기: `DraggableScrollableSheet` 또는 `showModalBottomSheet(isScrollControlled: true)` 으로 화면 80% 이상.

### W7. 신규 화면 — **`OwnerBrandStoreMenusPage` 채택**

- 브랜드 매장 점주용 메뉴 리스트 화면 신규.
- 진입: `OwnerMyStorePage` 의 브랜드 매장 분기에서 "메뉴 옵션·품절 관리" CTA → `Navigator.push(MaterialPageRoute(builder: (_) => OwnerBrandStoreMenusPage(store)))`.
- 데이터: `MenuItemRepository.watchByStore(storeId)` 호출 — case B 머지 결과.
- 카드 종류 식별:
  - 머지 결과의 `MenuItemEntity.scope` 를 보고 분기:
    - `scope == brand` → 마스터 메뉴 ref. 카드에 "마스터" 뱃지. 옵션 관리 / 품절 토글만 가능.
    - `scope == store` → 점포 한정 메뉴. 카드에 "매장 한정" 뱃지. 옵션 관리 / 품절 토글만 가능 (수정/삭제는 brand 가 sub-phase 3 에서).
  - 두 종류 모두 점주가 옵션/품절은 가능, 그 외 변경 불가.
- 핵심 정보 / 가격 / 카테고리는 read-only 표시 (단순 noticing — "이 매장은 브랜드 매장입니다. 메뉴 정보 변경은 브랜드 본사에 문의하세요" 안내 띠 또는 비슷한 안내 - designer 가 결정).
- 정렬: 머지 결과의 `displayOrder` 기준 (sub-phase 3 case B 머지 결과 그대로).

### W8. 진입 경로 — **두 경로 분리 채택**

- 매장 종류에 따라 진입 화면이 다름. UI 단계에서 분기:
  - **개인 매장** (`store.brandId == null`): `OwnerMyStorePage` → "메뉴 관리" CTA (sub-phase 4 V9) → `OwnerStoreMenuListPage` (sub-phase 4) — 카드/상세에 품절 토글 + 옵션 관리 추가 (본 sub-phase)
  - **브랜드 매장** (`store.brandId != null`): `OwnerMyStorePage` → "메뉴 옵션·품절 관리" CTA (본 sub-phase 신규) → `OwnerBrandStoreMenusPage` (본 sub-phase 신규)
- 두 진입점은 `OwnerMyStorePage` 의 매장 상세 영역에서 brandId 분기로 노출 — sub-phase 3 / 4 의 분기 패턴 그대로.

### W9. customer 측 회귀 검증 — **W4 + Phase 1a 패턴 활용**

- 옵션 비활성 / 품절 변경이 customer 측에서 즉시 반영되는지 회귀:
  - W4 의 (b) `OptionRepository` 단계 필터 — Phase 1a 의 `MenuItemDetailPage` 옵션 그룹 fetch 가 disabled* 인자 통과 후 비활성 그룹/항목 미노출
  - Phase 1a 의 회색 오버레이 + "품절" 라벨 패턴 그대로 — `MenuItemEntity.soldOut` 필드 활용
- 본 sub-phase 가 추가하는 회귀 시나리오:
  - 점주 토글 → 1~2초 내 customer `StoreMenuPage` 카드 회색 / 라벨 / `MenuItemDetailPage` 진입 시 옵션 picker 자동 갱신
  - 브랜드 매장의 status='pending' override 가 있는 상태에서 점주가 `soldOut` 토글 → status 보존 + customer 즉시 반영 (status 무관 운영 필드 정책 검증)
  - 신규 override 생성 (점주 첫 토글) → status='approved' 박힘 + customer 즉시 반영

### W10. 시드 데이터 — **변경 없음 채택**

- 후보:
  - (a) 시드 매장에 옵션 비활성 / 품절 sample 박기
  - (b) 시드는 그대로. 점주가 직접 토글하면 검증 가능
- **채택**: **(b) 변경 없음**. 이유:
  - 점주가 직접 토글하면 검증 가능. 시드 변경은 회귀 위험 (다른 phase 의 customer / Phase 1a~2 회귀에 영향 줄 수 있음).
  - 점주 운영 필드라 시드보다는 실제 사용자 인터랙션 흐름 검증이 중요.

---

## 데이터 모델

### Firestore (umbrella 모델 중 본 sub-phase 가 활성화하는 부분 — 필드 변경 없음)

```text
stores/{storeId}                                             # sub-phase 2 산출
  ├─ brandId: null | <brandId>                              # 분기 키
  ├─ status: 'approved'
  ├─ ownerId: <점주 uid>                                    # ownership 검증 키 (W3)
  │
  ├─ menuItems/{menuItemId}                                  # 개인 매장 메뉴 + 브랜드 매장 점포 한정 메뉴
  │     ├─ ... (sub-phase 4 / sub-phase 3 산출 필드)
  │     ├─ disabledOptionGroupIds: List<String>             # 본 sub-phase 활성화 (개인 매장) + (브랜드 점포 한정 메뉴)
  │     ├─ disabledOptionItemIds: List<String>              # compositeId = "{groupId}_{itemId}"
  │     └─ soldOut: bool                                    # 본 sub-phase 활성화
  │
  └─ menuOverrides/{masterMenuItemId}                        # 브랜드 매장 마스터 메뉴 ref (sub-phase 3 산출)
       ├─ priceOverride?: int                              # sub-phase 3 - 핵심 (검수 게이트)
       ├─ excluded: bool                                   # sub-phase 3 - 핵심 (검수 게이트)
       ├─ soldOut: bool                                    # 본 sub-phase 활성화 (운영, 즉시)
       ├─ disabledOptionGroupIds: List<String>             # 본 sub-phase 활성화 (운영, 즉시)
       ├─ disabledOptionItemIds: List<String>              # 본 sub-phase 활성화 (운영, 즉시)
       ├─ status: 'pending'|'approved'|'rejected'          # 핵심 필드 변경 시만 회귀. 본 sub-phase 의 변경은 status 보존
       ├─ submittedBy/At, approvedBy/At, rejectedReason
       ├─ updatedBy: 'admin'|'brand'|'owner'              # W2 - 본 sub-phase 의 변경은 'owner'
       └─ updatedAt
```

> **데이터 필드 신규 추가 없음** — 모두 sub-phase 1/3 에서 정의 완료. 본 sub-phase 는 활용만.

### Domain Entity (변경 없음)

- `MenuItemEntity` (sub-phase 1 산출) — 본 sub-phase 가 활용하는 필드: `disabledOptionGroupIds` / `disabledOptionItemIds` / `soldOut`. 변경 없음.
- `MenuOverrideEntity` (sub-phase 3 산출) — 본 sub-phase 가 활용하는 필드: `disabledOptionGroupIds` / `disabledOptionItemIds` / `soldOut`. 변경 없음.
- `OptionGroupEntity` (Phase 1a 산출) — 변경 없음. 본 sub-phase 는 fetch 단계 필터만 보강.

### DTO / Model (변경 없음)

- 모든 model 의 fromFirestore default 는 이미 sub-phase 1/3 에서 정의됨 (`disabledOption*=[]`, `soldOut=false`).
- toFirestore 는 모든 필드를 박음 (RepositoryImpl 이 전달한 값 그대로).

---

## 레이어 설계

### Domain

#### Entity (변경 없음)

- `MenuItemEntity`, `MenuOverrideEntity`, `OptionGroupEntity` 모두 기존 필드 활용.

#### Repository Interface

- `MenuItemRepository` (sub-phase 1/3/4 산출) — 시그니처 변경 없음:
  - `updateStoreOnlyMenuOperation(MenuItemEntity item)` — 본 sub-phase 가 호출 (운영 필드 partial update). RepositoryImpl 의 brandId 분기에서 개인 / 브랜드 점포 한정 양쪽 흡수.
- `MenuOverrideRepository` (sub-phase 3 산출) — 시그니처 변경 가능성 (W1 가정에 따름):
  - **(가정 A)** sub-phase 3 가 운영 필드 partial update 메서드를 정의했음:
    - `updateOverrideOperationFields(MenuOverrideEntity item)` 또는 동등명. 본 sub-phase 가 호출.
  - **(가정 B)** sub-phase 3 가 정의하지 않았음:
    - 본 sub-phase 가 신규 추가 — `updateOverrideOperationFields(MenuOverrideEntity item)`. 동작: override 가 없으면 신규 생성 (`status='approved'`, 승인 메타 null, `priceOverride=null`, `excluded=false`, `submittedBy=currentUid`, `submittedAt=now`, `updatedBy='owner'`), 있으면 partial update (`disabledOption*` / `soldOut` / `updatedAt` / `updatedBy='owner'` 만, status 보존).
- `OptionRepository` (Phase 1a 산출) — 시그니처 보강 (W4):
  - `getOptionGroupsForMenuItem(menuItemId, {disabledGroupIds, disabledItemIds})` — 인자 추가. 호출자 갱신 (Phase 1a 의 옵션 picker provider).

#### UseCase (신규, 6종)

- `ToggleSoldOutForPersonalMenuUseCase` — 개인 매장 메뉴의 `soldOut` 토글. 입력: `(MenuItemEntity)`. 호출: `MenuItemRepository.updateStoreOnlyMenuOperation`.
- `UpdateDisabledOptionsForPersonalMenuUseCase` — 개인 매장 메뉴의 `disabledOption*` 갱신. 입력: `(MenuItemEntity)`. 호출: 위와 동일 메서드 (운영 필드 partial update).
- `ToggleSoldOutForBrandStoreOnlyMenuUseCase` — 브랜드 매장 점포 한정 메뉴의 `soldOut` 토글. 입력 / 호출 동일 — RepositoryImpl 의 brandId 분기에서 처리.
- `UpdateDisabledOptionsForBrandStoreOnlyMenuUseCase` — 브랜드 매장 점포 한정 메뉴의 `disabledOption*` 갱신. 입력 / 호출 동일.
- `ToggleSoldOutForOverrideUseCase` — 브랜드 매장 마스터 메뉴 ref 의 `soldOut` 토글 (override upsert). 입력: `(MenuOverrideEntity)`. 호출: `MenuOverrideRepository.updateOverrideOperationFields`.
- `UpdateDisabledOptionsForOverrideUseCase` — 브랜드 매장 마스터 메뉴 ref 의 `disabledOption*` 갱신 (override upsert). 입력 / 호출 동일.

> **단순화 옵션**: 위 6종 중 인접한 두 메서드 (예: `ToggleSoldOutForPersonal` + `ToggleSoldOutForBrandStoreOnly`) 는 RepositoryImpl 의 brandId 분기가 처리하므로 UseCase 레벨에서도 통합 가능 (예: `ToggleSoldOutForStoreMenuUseCase`). developer 재량.

> **재사용**: `WatchOptionGroupsForMenuItemUseCase` (Phase 1a 산출) — 본 sub-phase 가 시그니처 보강 (W4). `WatchOwnerStoreMenusUseCase` (sub-phase 4) — 개인 매장. `WatchByStoreUseCase` (Phase 1a / sub-phase 3 case B) — 브랜드 매장 점주가 자기 매장 메뉴 보는 용도.

### Data

#### Model (변경 없음)

- `MenuItemModel`, `MenuOverrideModel`, `OptionGroupModel` 모두 기존 필드 활용.

#### DataSource

- `MenuItemRemoteDataSource` (sub-phase 1 산출) — 변경 없음. `updateStoreOnly(storeId, menuItemId, partialMap)` 그대로 활용.
- `MenuOverrideRemoteDataSource` (sub-phase 3 산출) — `upsertOverride(storeId, masterMenuItemId, partialMap)` 또는 동등 메서드 활용. 없으면 본 sub-phase 가 추가 (set with merge).
- `OptionRepositoryImpl` 또는 `OptionRemoteDataSource` (Phase 1a 산출) — 옵션 fetch 단계에서 `disabledOption*` 인자 받아 필터.

#### Repository Implementation (보강)

##### `MenuItemRepositoryImpl` (sub-phase 1/3/4 산출) 의 `updateStoreOnlyMenuOperation` 보강

```text
1. 매장 fetch (storeRemoteDataSource.getById)
2. ownership 검증:
   - role == 'admin' 통과
   - store.brandId == null && store.ownerId == currentUid → 통과 (개인 매장 점주, sub-phase 4 V3)
   - store.brandId != null && store.ownerId == currentUid → 통과 (브랜드 매장 점주, 본 sub-phase W3)
   - 그 외 → PermissionDeniedException
3. brandId 분기 + 운영 필드 partial update:
   - brandId == null (개인 매장):
     prepared = item.copyWith(
       status: approved,
       submittedBy: null, submittedAt: null,
       approvedBy: null, approvedAt: null, rejectedReason: null,
     )
     partial map: 변경 필드 (soldOut, disabledOptionGroupIds, disabledOptionItemIds, visible, tags, displayOrder, imageUrl) + updatedAt
   - brandId != null (브랜드 매장 점포 한정 메뉴):
     prepared = item.copyWith() (status 그대로 — sub-phase 3 결정 J: 점포 한정 메뉴의 운영 필드는 점주 즉시)
     partial map: 변경 필드 + updatedAt
4. dataSource.updateStoreOnly(item.storeId, item.id, partialMap)
```

##### `MenuOverrideRepositoryImpl` (sub-phase 3 산출) 의 `updateOverrideOperationFields` 보강 (또는 신규)

```text
1. 매장 fetch + ownership 검증:
   - role == 'admin' 통과
   - store.brandId != null && store.ownerId == currentUid → 통과 (W3)
   - 그 외 → PermissionDeniedException
2. override 존재 여부 확인:
   - dataSource.getById(storeId, masterMenuItemId)
3. 분기:
   - 존재 X (점주 첫 토글):
     prepared = MenuOverrideEntity(
       masterMenuItemId, storeId,
       priceOverride: null, excluded: false,
       soldOut: item.soldOut, disabledOptionGroupIds: item.disabledOptionGroupIds, disabledOptionItemIds: item.disabledOptionItemIds,
       status: approved,
       submittedBy: currentUid, submittedAt: now,
       approvedBy: null, approvedAt: null, rejectedReason: null,
       updatedBy: 'owner', updatedAt: now,
     )
     dataSource.create(storeId, masterMenuItemId, prepared.toFirestore())
   - 존재 O:
     partial map: { soldOut, disabledOptionGroupIds, disabledOptionItemIds, updatedAt, updatedBy: 'owner' }
     dataSource.update(storeId, masterMenuItemId, partialMap)
     # status 보존 - 핵심 필드 (priceOverride / excluded) 가 변경되지 않으므로 status 회귀 X
```

##### `OptionRepositoryImpl` (Phase 1a 산출) 의 `getOptionGroupsForMenuItem` 보강 (W4)

```text
1. 옵션 그룹 fetch (master + store optional, Phase 1a 흐름)
2. for each group:
     if group.id in disabledGroupIds: skip
     else:
       filtered_items = group.items.where((item) =>
         '${group.id}_${item.id}' not in disabledItemIds  # compositeId 매칭
       )
       yield group.copyWith(items: filtered_items)
3. return filtered groups
```

> **호출자 갱신**: Phase 1a 의 `MenuItemDetailPage` Provider — `MenuItemEntity.disabledOption*` 를 인자로 전달.

### Presentation

#### Owner 모듈 확장 (`presentation/owner/store_menu/`) — 개인 매장

- `OwnerStoreMenuListPage` (sub-phase 4 산출) 갱신:
  - 카드에 품절 토글 인라인 추가 (W5)
  - 카드 액션 시트에 "옵션 관리" 항목 추가 (W6 — `MenuOptionDisableSheet` 진입)
- `OwnerStoreMenuDetailPage` (sub-phase 4 산출) 갱신:
  - 액션 영역에 "옵션 관리" 버튼 + 품절 토글 추가

#### Owner 모듈 신설 (`presentation/owner/brand_store/`) — 브랜드 매장

```text
presentation/owner/brand_store/
├── owner_brand_store_menus_page.dart           # 신규 — 브랜드 매장 메뉴 리스트 (W7)
└── widgets/
    └── owner_brand_store_menu_card.dart        # 신규 — 카드 (마스터 ref / 점포 한정 분기)

presentation/owner/providers/
├── owner_brand_store_providers.dart            # 신규 — UseCase / Repository DI + 머지 stream provider
└── (기존) owner_store_menu_providers.dart      # sub-phase 4 산출, 변경 없음
```

#### 공통 모듈 신설 (`presentation/common/option_disable_sheet/`)

```text
presentation/common/option_disable_sheet/
├── menu_option_disable_sheet.dart              # 신규 — 공통 BottomSheet (W6)
└── providers/
    └── menu_option_disable_providers.dart      # 신규 — 옵션 fetch + 토글 상태 관리
```

#### `OwnerMyStorePage` 갱신

- 매장 상세 영역에 brandId 분기로 CTA 노출:
  - **개인 매장**: "메뉴 관리" CTA (sub-phase 4 V9 그대로) — 이미 존재. 본 sub-phase 가 변경 없음.
  - **브랜드 매장**: "메뉴 옵션·품절 관리" CTA (본 sub-phase 신규) — 노출 조건 `store.brandId != null && store.status == approved`. 탭 시 `Navigator.push(MaterialPageRoute(builder: (_) => OwnerBrandStoreMenusPage(store)))`.

#### 라우팅

- `Navigator.push(MaterialPageRoute)` 패턴 유지 (router.dart 변경 없음)
- `RoleRouter` 변경 없음

---

## 데이터 흐름 (핵심 시나리오 6개)

### 1. 개인 매장 메뉴 품절 토글 (점주 → 즉시 반영)

```text
OwnerMyStorePage (개인 매장, status=approved)
  → "메뉴 관리" CTA → OwnerStoreMenuListPage(store)  # sub-phase 4
  → 카드 인라인 품절 토글 탭 (W5)
  → ToggleSoldOutForPersonalMenuUseCase (변경: soldOut: true)
  → MenuItemRepository.updateStoreOnlyMenuOperation(item.copyWith(soldOut: true))
  → MenuItemRepositoryImpl:
     - 매장 fetch + ownership 검증 (개인 매장 점주)
     - brandId == null 분기: status=approved 보존, 승인 메타 null
     - partial map: { soldOut: true, updatedAt: now }
     - dataSource.updateStoreOnly
─── (customer) StoreMenuPage 자동 갱신
  → MenuItemRepository.watchByStore (case A)
  → 카드 회색 + "품절" 라벨 (Phase 1a 패턴)
─── (customer) MenuItemDetailPage 진입 시
  → "품절" 라벨 + 장바구니 추가 비활성 (Phase 1a 동작)
```

### 2. 개인 매장 메뉴 옵션 그룹 비활성 (점주 → customer 옵션 fetch 시 제거)

```text
OwnerStoreMenuListPage 카드 long-press → 액션 시트 → "옵션 관리"
  → MenuOptionDisableSheet(storeId, menuItemId, menuType: 'personal', currentDisabledGroupIds: [], currentDisabledItemIds: [])
  → 옵션 그룹 fetch (OptionGroupRepository.getOptionGroupsForMenuItem — 단 sheet 안에서는 비활성 인자 0 으로 호출. 점주가 모든 그룹/항목을 봐야 비활성을 선택할 수 있으므로)
  → 사용자가 그룹 1개 토글 (예: '시럽 추가' 그룹 비활성)
  → 시트 닫기 → UpdateDisabledOptionsForPersonalMenuUseCase (변경: disabledOptionGroupIds: ['syrup_group_id'])
  → MenuItemRepository.updateStoreOnlyMenuOperation (위 시나리오 1 흐름 — partial map: { disabledOptionGroupIds: [...], updatedAt })
─── (customer) MenuItemDetailPage 진입 시
  → OptionRepository.getOptionGroupsForMenuItem(menuItemId, disabledGroupIds: ['syrup_group_id'], disabledItemIds: [])
  → '시럽 추가' 그룹 자동 제외
```

### 3. 브랜드 매장 마스터 메뉴 ref 품절 토글 (override 신규 생성)

```text
OwnerMyStorePage (브랜드 매장, status=approved)
  → "메뉴 옵션·품절 관리" CTA → OwnerBrandStoreMenusPage(store)  # 본 sub-phase 신규
  → MenuItemRepository.watchByStore(storeId)  # case B 머지
  → 마스터 메뉴 ref 카드 (예: '아메리카노') 의 품절 토글 탭
  → ToggleSoldOutForOverrideUseCase (변경: soldOut: true, override entity 구성)
  → MenuOverrideRepository.updateOverrideOperationFields(overrideEntity)
  → MenuOverrideRepositoryImpl:
     - 매장 fetch + ownership 검증 (브랜드 매장 점주, W3)
     - override 존재 여부 확인 (dataSource.getById(storeId, masterMenuItemId))
     - 존재 X:
       - 신규 생성: priceOverride=null, excluded=false, soldOut=true, status=approved, submittedBy=currentUid, updatedBy='owner'
       - dataSource.create
─── (customer) StoreMenuPage 자동 갱신
  → MenuItemRepository.watchByStore (case B 머지)
  → override.status='approved' 이므로 머지 진행
  → soldOut=true 머지 결과 → 카드 회색 + "품절" 라벨
```

### 4. 브랜드 매장 마스터 메뉴 ref 옵션 비활성 (기존 override 가 있는 경우 — partial update + status 보존)

```text
# 사전: brand 가 sub-phase 3 에서 priceOverride=4500 으로 override 생성, admin 승인 → status=approved
OwnerBrandStoreMenusPage 마스터 메뉴 ref 카드 long-press → "옵션 관리"
  → MenuOptionDisableSheet(storeId, menuItemId, menuType: 'brandMasterRef', currentDisabledGroupIds: [], currentDisabledItemIds: [])
  → 사용자가 그룹/항목 토글
  → 시트 닫기 → UpdateDisabledOptionsForOverrideUseCase
  → MenuOverrideRepository.updateOverrideOperationFields(...)
  → MenuOverrideRepositoryImpl:
     - 매장 fetch + ownership 검증
     - override 존재 O (priceOverride=4500, status=approved)
     - partial map: { disabledOptionGroupIds: [...], disabledOptionItemIds: [...], updatedAt, updatedBy: 'owner' }
     - dataSource.update (status / priceOverride / excluded / 승인 메타 보존)
─── (customer) StoreMenuPage 자동 갱신
  → case B 머지: priceOverride=4500 적용 (status=approved) + disabledOption* 머지
  → MenuItemDetailPage 옵션 picker 자동 필터
```

### 5. 브랜드 매장 점포 한정 메뉴 품절 / 옵션 비활성 (sub-phase 4 의 Operation update 재사용)

```text
OwnerBrandStoreMenusPage 점포 한정 메뉴 카드 (scope=store)
  → 품절 토글 또는 "옵션 관리" → 시트
  → ToggleSoldOutForBrandStoreOnlyMenuUseCase 또는 UpdateDisabledOptionsForBrandStoreOnlyMenuUseCase
  → MenuItemRepository.updateStoreOnlyMenuOperation
  → MenuItemRepositoryImpl:
     - 매장 fetch + ownership 검증 (브랜드 매장 점주, W3)
     - brandId != null 분기: status 그대로 (sub-phase 3 결정 J - 점포 한정 메뉴의 운영 필드는 점주 즉시)
     - partial map + dataSource.updateStoreOnly
─── (customer) 즉시 반영
```

### 6. customer 매장 진입 → 머지 결과에서 비활성 옵션 / 품절 메뉴 자동 처리

```text
customer 매장 카드 탭 → StoreMenuPage(storeId)
  → MenuItemRepository.watchByStore(storeId)
  → store.brandId 분기:
     - case A (개인 매장): menuItems stream + status=approved + visible 필터 + (본 sub-phase) soldOut + disabledOption* 필드 그대로 흘림
     - case B (브랜드 매장): master + override + storeOnly Rx.combineLatest3 머지
       - override 의 status=approved 면 priceOverride / excluded 적용
       - override 의 soldOut / disabledOption* 는 status 무관 즉시 머지 (umbrella 머지 규칙)
  → MenuItemEntity 결과: soldOut / disabledOption* 가 머지된 상태
─── 카드 시각:
  → soldOut == true → 회색 + "품절" 라벨
─── customer MenuItemDetailPage 진입:
  → OptionRepository.getOptionGroupsForMenuItem(menuItemId, disabledGroupIds: menu.disabledOptionGroupIds, disabledItemIds: menu.disabledOptionItemIds)
  → 비활성 그룹/항목 자동 제외
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 권한 미달 (점주 role 아님 — customer / admin / brand 가 OwnerStoreMenu* 또는 OwnerBrandStoreMenusPage 진입 시도) | `RoleRouter` 가 분기에서 차단 (`OwnerScaffold` 안에서만 노출). |
| 권한 미달 (점주가 본인 외 매장 메뉴 조작 시도) | RepositoryImpl 의 `_assertOwnerOfPersonalStore` (sub-phase 4 V3) / `_assertOwnerOfBrandStore` (W3) → `PermissionDeniedException` → 스낵바 "권한이 없습니다" |
| 권한 미달 (브랜드 매장 점주가 마스터 메뉴 자체 변경 시도 — race condition) | UI 단 마스터 메뉴 정보 read-only (W7). race condition: API 직접 호출은 본 sub-phase UseCase 가 운영 필드만 노출하므로 마스터 메뉴 자체 변경은 불가. 추가 안전망: `MasterMenuItemRepository` 의 변경 메서드는 brand role 검증 (sub-phase 1) → 점주 차단 |
| Firestore 읽기 실패 (네트워크) | `AsyncError` → 에러 위젯 + 재시도 버튼 (Riverpod refresh) |
| 매장 fetch 실패 (RepositoryImpl 내부 brandId fetch) | `StateError` → 스낵바 "매장 정보를 불러올 수 없습니다". 토글 / 비활성 차단 |
| 매장이 삭제된 사이 토글 시도 | 매장 fetch null → `StateError` → 차단 |
| 매장이 brand 매장으로 변경된 사이 (개인 → 브랜드) 토글 시도 (race) | RepositoryImpl 의 brandId 분기에서 자연스럽게 브랜드 분기 처리 — ownership 검증 통과하면 동작. 단 UI 진입점은 다르므로 일반적 시나리오 아님 |
| 동시 편집 (점주가 시트 열어둔 상태에서 다른 단말로 토글) | partial update 라 last-write-wins. 시트 닫기 직전에 변경 필드만 덮어씀. UX 단계에서 시트 진입 시 최신 상태 fetch |
| 옵션 그룹이 fetch 실패 / 빈 응답 (시트 진입 시) | 시트 안에 에러 위젯 + "옵션 그룹을 불러올 수 없습니다" + 재시도 버튼 |
| optionGroupRefs 가 존재하지 않는 옵션 그룹 ref (race condition — 옵션 그룹이 삭제된 사이) | 시트가 빈 옵션으로 표시. 점주 토글 무동작 |
| disabledOptionItemIds compositeId 형식 오류 (legacy 데이터) | toFirestore default 가 빈 배열로 흡수. fromFirestore 가 List<String> 검증 (json_serializable 기본). 잘못된 entry 는 단순 무시 |
| 인증 만료 | 기존 auth flow (재로그인) |

---

## 작업 분배 판단

### designer 호출 — **권장 (필수)**

신규 화면 1종 (`OwnerBrandStoreMenusPage`) + 신규 시트 1종 (`MenuOptionDisableSheet`) + 기존 화면 갱신 2종 (`OwnerStoreMenuListPage` 카드 / `OwnerStoreMenuDetailPage` 액션 / `OwnerMyStorePage` 의 브랜드 매장 CTA). sub-phase 1 의 `_VisibleToggleButton` 패턴 / sub-phase 4 의 카드 패턴을 그대로 차용하므로 디자인 작업량은 sub-phase 4 의 30~40% 수준.

- 디자인 산출물: `docs/tasks/admin_menu_management/5_owner_options_soldout/design.md`
- 전달할 사항:
  - `OwnerStoreMenuListPage` 카드 갱신 — 품절 토글 인라인 (W5: visible 토글 옆 동등 배치) + `soldOut == true` 회색 + "품절" 뱃지
  - `OwnerStoreMenuDetailPage` 갱신 — 액션 영역에 "옵션 관리" 버튼 + 품절 토글
  - `OwnerBrandStoreMenusPage` 신규 — 브랜드 매장 점주용 메뉴 리스트 (W7). 마스터 ref 카드 / 점포 한정 카드 분기 시각. 마스터 ref 카드는 read-only 핵심 정보 + 점주 운영 액션만. "이 매장은 브랜드 매장입니다" 안내 띠.
  - `MenuOptionDisableSheet` 신규 — BottomSheet (W6). 그룹 row + 항목 row + 토글 + 닫기. 그룹 비활성 시 항목 비활성 (disabled). DraggableScrollableSheet 또는 화면 80% 높이 시트.
  - `OwnerMyStorePage` 의 브랜드 매장 분기 — "메뉴 옵션·품절 관리" CTA 위치 / 디자인 (잠정안 — 매장 운영 정보 버튼 옆)
  - 빈 상태 / 로딩 / 에러 / 토글 즉시 반영 SnackBar / 옵션 비활성 안내

### developer 호출

designer 완료 후. 의존 순서: Domain (UseCase / Repository 인터페이스 보강 W4) → Data (RepositoryImpl 보강 W1/W2/W3 + OptionRepository W4) → Presentation (시트 신설 / 페이지 신설 / 카드 갱신).

- 구현 항목: 위 레이어 설계의 모든 파일
- 재사용:
  - sub-phase 1 의 `MenuItemEntity.disabledOption*` / `soldOut` 필드 / `_VisibleToggleButton` 패턴 / `MenuItemListTile`
  - sub-phase 3 의 `MenuOverrideEntity.disabledOption*` / `soldOut` / `MenuOverrideRepository` / `MenuOverrideRemoteDataSource` / case B 머지
  - sub-phase 4 의 `MenuItemRepository.updateStoreOnlyMenuOperation` / ownership helper / `OwnerStoreMenuListPage` / `OwnerStoreMenuDetailPage` / `MenuItemRepositoryImpl` 의 brandId 분기
  - Phase 1a 의 `OptionRepository.getOptionGroupsForMenuItem` / `MenuItemDetailPage` Provider (W4 시그니처 변경 호출자 갱신)
  - 기존 `Navigator.push` / freezed / Riverpod 패턴
- 주의할 레이어 규칙:
  - `MenuOverrideRepositoryImpl` 의 `updateOverrideOperationFields` — sub-phase 3 가 정의했는지 확인. 없으면 본 sub-phase 가 추가 (Repository 인터페이스 + Impl + RemoteDataSource set-with-merge).
  - `OptionRepository.getOptionGroupsForMenuItem` 시그니처 변경 시 호출자 (Phase 1a 의 옵션 picker provider) 갱신 — 회귀 위험 검증
  - sub-phase 3 의 case B 머지가 `disabledOption*` / `soldOut` 을 status 무관 즉시 적용하는지 회귀 검증
  - `Color(0x...)` 직접 하드코딩 금지 — `AppColors` 만 사용
  - Firebase 직접 import 는 data 레이어에서만 (sub-phase 1 패턴 그대로)
- `pubspec.yaml`: 추가 패키지 없음

### tester 호출

developer 완료 후. `test_report.md`. **회귀 검증 강조** — sub-phase 1/2/3/4 + customer Phase 1a~2 + 브랜드 매장 핵심 정보 read-only 무영향. **본 sub-phase 가 admin_menu_management phase 의 마지막이므로 umbrella 의 완료 기준 전체 검증.**

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능 (개인 매장)

- [ ] `OwnerStoreMenuListPage` 카드의 품절 토글 인라인 (W5) — 즉시 반영, customer 측 회색 + "품절" 라벨
- [ ] `OwnerStoreMenuListPage` 카드 액션 시트의 "옵션 관리" 항목 → `MenuOptionDisableSheet` 진입 (W6)
- [ ] `OwnerStoreMenuDetailPage` 의 "옵션 관리" 버튼 + 품절 토글 — 동작
- [ ] `MenuOptionDisableSheet` — 그룹 토글 / 항목 토글 / 그룹 비활성 시 항목 disabled / 닫기 시 저장 / 변경 없으면 무동작
- [ ] 옵션 비활성 → customer `MenuItemDetailPage` 옵션 picker 즉시 자동 갱신 (W4 — 비활성 그룹/항목 미노출)

### 신규 기능 (브랜드 매장)

- [ ] `OwnerMyStorePage` 의 브랜드 매장 분기에 "메뉴 옵션·품절 관리" CTA — `store.brandId != null && approved` 일 때만 노출 (W8)
- [ ] `OwnerBrandStoreMenusPage` 진입 — 마스터 메뉴 ref + 점포 한정 메뉴 머지 결과 노출 (W7)
- [ ] 마스터 메뉴 ref 카드 — 핵심 정보 read-only, 품절 토글 + 옵션 관리만 가능
- [ ] 점포 한정 메뉴 카드 — 동일 동작 (sub-phase 4 패턴, 단 추가/삭제 미노출)
- [ ] 마스터 메뉴 ref 의 품절 토글 (override 신규 생성, W2) — `status='approved'` 즉시 박힘 + customer 즉시 반영
- [ ] 마스터 메뉴 ref 의 옵션 비활성 (기존 override + status='approved') — partial update + status 보존 + customer 즉시 반영
- [ ] 마스터 메뉴 ref 의 옵션 비활성 (기존 override + status='pending' priceOverride) — `disabledOption*` 만 partial update + status='pending' 보존 + customer 즉시 반영 (운영 필드 status 무관)
- [ ] 점포 한정 메뉴의 품절 / 옵션 비활성 (sub-phase 4 의 운영 필드 update 재사용) — 동작

### 권한 / 가드

- [ ] 점주가 본인 외 개인 매장 → `PermissionDeniedException`
- [ ] 점주가 본인 외 브랜드 매장 → `PermissionDeniedException`
- [ ] customer / admin / brand role 이 OwnerBrandStoreMenusPage 진입 시도 → `RoleRouter` 차단
- [ ] 브랜드 매장 점주가 마스터 메뉴 정보 변경 시도 (race / direct API) → 차단 (sub-phase 1 의 brand role 검증)

### 회귀 (sub-phase 1/2/3/4 + customer Phase 1a~2)

- [ ] **sub-phase 1 마스터 메뉴 CRUD 무영향** — brand 의 마스터 메뉴 등록 / 수정 / 삭제 / 승인 흐름 그대로
- [ ] **sub-phase 2 매장 등록 / 승인 무영향** — 점주 매장 등록 / brand 매장 등록 → admin 승인 → customer 노출 그대로
- [ ] **sub-phase 3 case B 머지 무영향** — 마스터 + override + 점포 한정 머지 결과 그대로 (priceOverride / excluded status='approved' 시만 적용)
- [ ] **sub-phase 3 case B 운영 필드 머지 정합** — override 의 `disabledOption*` / `soldOut` 가 status 무관 즉시 머지 (umbrella 머지 규칙) — 본 sub-phase 가 처음 검증
- [ ] **sub-phase 3 가격 오버라이드 / 점포 한정 메뉴 분기 무영향** — brand 등록 → admin 승인 흐름 그대로
- [ ] **sub-phase 3 OwnerMyStorePage 의 브랜드 매장 read-only 무영향** — 핵심 정보 수정 / 메뉴 추가 / 삭제 / 가격 변경 등 비노출 그대로
- [ ] **sub-phase 4 개인 매장 CRUD 무영향** — 메뉴 등록 / 수정 / 삭제 / 복제 흐름 그대로
- [ ] **sub-phase 4 운영 필드 update 무영향** — visible 토글 그대로
- [ ] **customer Phase 1a~2 무영향** — 시드 매장 / 점주 등록 매장 / 브랜드 매장 모두 customer 검색 / `StoreMenuPage` / `MenuItemDetailPage` / 장바구니 동작 그대로
- [ ] customer `watchByStore(storeId)` case A — 본 sub-phase 의 `disabledOption*` / `soldOut` 필드 즉시 반영
- [ ] customer `watchByStore(storeId)` case B — 본 sub-phase 의 override 운영 필드 + 점포 한정 메뉴 운영 필드 즉시 반영
- [ ] customer `OptionRepository.getOptionGroupsForMenuItem` 시그니처 변경 — Phase 1a 호출자 갱신 후 옵션 picker 정상 동작
- [ ] 시드 매장 (`brandId=null`, 시드 메뉴) — 본 sub-phase 흐름으로 점주 토글 가능, 정상 동작
- [ ] `MenuItemRepository.watchByStore` 시그니처 / 동작 불변

### Repository / Data 분기

- [ ] `MenuItemRepositoryImpl.updateStoreOnlyMenuOperation` 의 brandId 분기 — 개인 매장 (null) → status=approved 보존 + 운영 필드 partial, 브랜드 매장 (not null) → status 그대로 + 운영 필드 partial (sub-phase 3 점포 한정 메뉴)
- [ ] `MenuOverrideRepositoryImpl.updateOverrideOperationFields` — override 미존재 시 신규 생성 (status='approved', 승인 메타 null, priceOverride=null, excluded=false, updatedBy='owner', submittedBy=currentUid), override 존재 시 partial update (status / 핵심 필드 보존, updatedBy='owner')
- [ ] `OptionRepositoryImpl.getOptionGroupsForMenuItem` 의 disabledGroupIds / disabledItemIds 인자 — 그룹 통째 제외 / 항목 compositeId 매칭 제외 / 빈 인자 시 무동작 (Phase 1a 호환)

### 코드 품질

- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (entity 변경 없으므로 영향 적음 — 단 freezed 재생성 안전)
- [ ] 색상 토큰 — `AppColors` 만 사용, `Color(0x...)` 0건
- [ ] Firebase / 외부 SDK 직접 import 는 data 레이어만

### 본 phase (admin_menu_management) 전체 완료 기준 검증 (umbrella)

> 본 sub-phase 가 마지막이므로 umbrella 의 완료 기준 전체를 tester 가 추가 검증.

- [ ] **role 라우팅 4분기 동작** — admin / brand / owner / customer 모두 각 Scaffold 진입
- [ ] **admin 승인 큐 4탭 동작** — 브랜드 / 마스터 메뉴 / 매장 / 매장 커스텀 (sub-phase 1/2/3 산출)
- [ ] **brand 모듈 동작** — 브랜드 등록 / 마스터 메뉴 CRUD / 매장 커스텀 / 점포 한정 메뉴 / 승인 트래킹 (sub-phase 1/3 산출)
- [ ] **owner 모듈 동작** — 매장 등록 / 메뉴 관리 (개인) / 메뉴 옵션·품절 (개인 + 브랜드) (sub-phase 2/4/5 산출)
- [ ] **customer 회귀** — Phase 1a~2 모두 무영향
- [ ] **시드 회귀** — `brandId=null` + `status=approved` fallback 그대로 동작
- [ ] **권한 매트릭스 (umbrella 결정 I) 전체 검증** — 개인 매장 점주 / 브랜드 매장 점주 / brand / admin 각자의 동작 분기 정합
- [ ] **결정 J (핵심 / 운영 필드 분리)** — 매장 / 마스터 메뉴 / 매장 커스텀 / 매장 한정 메뉴 모두 분리 동작 정합

---

## 완료 기준

- [ ] `spec.md` 본 문서 (현재) 확정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] `MenuOptionDisableSheet` 동작 (개인 / 브랜드 매장 양쪽)
- [ ] 품절 토글 동작 (개인 / 브랜드 매장 양쪽)
- [ ] customer 옵션 화면에서 비활성 그룹 / 항목 미노출 (W4)
- [ ] customer 메뉴 카드에 품절 표시 (Phase 1a 패턴)
- [ ] override 가 없는 상태에서 점주가 처음 토글 시 새 override doc 생성 + status='approved' + 즉시 반영 (W2)
- [ ] override 가 status='pending' 또는 'rejected' 인 상태에서 점주가 운영 필드 토글 → status 보존 + 즉시 반영
- [ ] sub-phase 1/2/3/4 회귀 0
- [ ] customer Phase 1a~2 회귀 0
- [ ] `flutter analyze` 0 issue
- [ ] **본 phase (admin_menu_management) 전체 완료** — umbrella 의 완료 기준 검증 (customer 회귀 / 시드 / 매장 승인 / 브랜드 매장 e2e / role 4분기 / 권한 매트릭스)
