# sub-phase 1 — brand_master 기능 명세

> **상태**: APPROVED — architect 보강 완료
>
> **umbrella 단일 진실원**: 데이터 모델 / 결정사항 (1~12, A~F, G/H/I) / 권한 매트릭스 / role 라우팅 / customer 측 머지 규칙 → [`../spec.md`](../spec.md). 본 sub-phase 는 그 결정을 그대로 따른다 — 재서술하지 않는다.
>
> **sub-phase 6 영향 (V1 / V2-1 / V9)**: sub-phase 6 진입 후 본 sub-phase 의 다음 항목이 갱신된다. 상세는 [`../6_upgrade_to_brand/spec.md`](../6_upgrade_to_brand/spec.md) 참조.
>
> - **`BrandEntity` 에 `brandKey: String` 필드 추가** (default `''`). `BrandModel` 직렬화 추가. status='approved' 박히는 시점에만 `BR-XXXXXXXX` 형식으로 채워짐 (sub-phase 6 의 V1).
> - **`BrandRepository.findByBrandKey(brandKey)` 메서드 추가** — brand 조회 (sub-phase 6 의 V4 — 점주 매장 등록 시 brandKey 검증 진입점).
> - **`BrandRepositoryImpl.upsertBrand` 의 신규 brand 분기 보강** — brand doc 생성과 동시에 `users/{currentUid}.brandId = newBrandId` batch 갱신 (sub-phase 6 의 V2-1).
> - **`BrandRepositoryImpl.approveBrand` 보강** — brandKey 자동 생성 (`Random.secure` + 32 char alphabet × 8자리, 0/O/I/1 제외) + `BrandRemoteDataSource.isBrandKeyTaken` 으로 unique 검증 + 1-2회 재시도 (sub-phase 6 의 V1).
> - **`BrandInfoPage` 에 brandKey read-only 노출** — status='approved' 일 때만 노출 (sub-phase 6 의 V9).
> - **결정 G ("admin 콘솔에서 수동 발급") 폐기** — sub-phase 6 진입 후 모든 brand 가입은 `UpgradeToBrandUseCase` (점주 패턴 차용) 로 일원화. admin 콘솔에서 수동으로 role='brand' / brandId 박는 흐름 미존재.

---

## 개요

- **목적**: `admin_menu_management` 의 첫 sub-phase. **brand role 신설** + **브랜드 등록** + **마스터 메뉴 CRUD** 기반 인프라를 깐다. 이 위에 sub-phase 2~5 가 쌓인다.
- **작업 유형**: 신규 기능 (대규모 — brand / admin 모듈 신설 + 신규 컬렉션 2개 + Repository 2종)
- **영향 범위**:
  - 화면(brand): `BrandScaffold` + 4탭 중 3탭 (브랜드 정보 / 마스터 메뉴 / 더보기. 매장 탭은 sub-phase 3 에서 활성화)
  - 화면(admin): `AdminScaffold` + 승인 큐 (brand / 마스터 메뉴) + 더보기
  - 화면(customer / owner): **변경 없음**
  - Domain: `BrandEntity` (신규), `EntityApprovalStatus` enum (신규), `MenuItemScope` enum (신규). 기존 `MenuItemEntity` 에 `scope` / `brandId?` / `tags` / `visible` / `disabledOption*` / `status?` / 승인 메타 필드 추가. `UserRole` 에 `brand` 추가
  - Data: `BrandRemoteDataSource` (신규), `MasterMenuItemRemoteDataSource` (신규), `BrandModel` (신규), `MenuItemModel` 확장. `BrandRepositoryImpl`, `MasterMenuItemRepositoryImpl` 신규
  - Presentation: `presentation/brand/` 트리 신설, `presentation/admin/` 트리 신설
  - 라우팅: `RoleRouter` 분기에 `brand`, `admin` 추가
  - 권한 / 환경 설정: 클라이언트 가드만. Firestore 보안 규칙은 별도 task `firestore_rules`
  - 테스트: 기존 customer / owner 화면 회귀 테스트 (시드 매장 `brandId=null` + `status=approved` default 기준 동작 그대로)
- **비범위** (umbrella 비범위 + 본 sub-phase 한정):
  - 매장 등록 / 매장 메뉴 CRUD → sub-phase 2 / 4
  - brand 의 매장 커스텀 (가격 오버라이드 / 점포 한정 추가 메뉴) → sub-phase 3
  - 점주 옵션 비활성 / 품절 토글 → sub-phase 5
  - admin 의 brand 계정 발급 UI → 본 sub-phase 비범위. Firestore 콘솔 수동 (umbrella 결정 G)
  - 브랜드 한정 옵션 그룹 CRUD → 별도 phase `admin_option_group_management`
  - 부 카테고리 CRUD → 별도 phase
  - N:1 brand 매핑 → 본 sub-phase 는 1:1
  - Firestore 보안 규칙 → 별도 task `firestore_rules`
  - 결제 (Phase 3)

---

## 의존 phase / 진입 조건

- **의존 phase**: 없음. 본 sub-phase 가 첫 진입.
- **진입 조건**:
  - umbrella `spec.md` APPROVED (현재 완료)
  - Firestore 콘솔에서 테스트용 brand 계정 1개 수동 생성 가능 (`users/{uid}.role='brand'` + `brandId='<value>'`)

---

## 확정된 결정사항 (sub-phase 한정)

> umbrella 결정 1~12 / A~F / G/H/I 는 [`../spec.md`](../spec.md) 의 단일 진실원 그대로 적용. 여기서는 본 sub-phase 한정 결정만 기록한다.

### S1. `MasterMenuItemEntity` vs `MenuItemEntity + scope` 통합 — **(b) 통합 채택**

- 별도 entity 를 만들지 않고, **기존 `MenuItemEntity` 에 `scope` / `brandId?` / `tags` / `visible` / `disabledOption*` / `status?` / 승인 메타** 를 추가해서 단일 entity 로 운용한다.
- 이유: customer 측 `MenuItemRepository.watchByStore` 머지 (umbrella 결정대로) 가 단순해진다. `MasterMenuItemEntity` 와 `MenuItemEntity` 를 별도 entity 로 두면 머지 단계에서 변환 비용이 발생.
- `MenuItemEntity.storeId` 는 마스터 메뉴 케이스에서 빈 문자열 허용 (DTO 직렬화 단계에서 `scope==brand` 면 `storeId=''`). customer 머지 단계가 `scope==brand` 결과를 `storeId={해당 매장ID}` 로 채워서 yield 한다.

### S2. 마스터 메뉴 옵션 그룹 참조 가드

- 마스터 메뉴(`scope==brand`) 의 `optionGroupRefs` 는 **`scope: 'master'` 만 허용**. UI: brand 폼 picker 에서 store scope 미노출. 무결성: `MasterMenuItemRepositoryImpl.create/update` 가 저장 직전 `optionGroupRefs.every((r) => r.scope == 'master')` 검증. 위반 시 `ArgumentError`.

### S3. status 전이 규칙 + 핵심/운영 필드 분리 (umbrella 결정 J 적용)

```text
[draft, 미저장]
   ↓ (brand 저장)
pending  ───→ (admin 승인)  ───→ approved
   ↑                                    │
   │ (brand 재제출, 수정 후)           │ (brand 핵심 필드 수정)
   │                                    ↓
rejected ←── (admin 반려, 사유 메모)  pending  ←── 핵심 필드 변경만 회귀
                                         │
                                        approved ←── 운영 필드 변경은 즉시 반영, status 회귀 X
```

- `approved` → **핵심 필드 수정** → `pending` 으로 회귀 (단순 정책. `approved_pending_update` 같은 별도 상태 없음).
- `approved` → **운영 필드 수정** → status 보존 (즉시 반영). 시즌 메뉴 ON/OFF 등 일상 운영을 막지 않기 위함.
- admin 승인 큐 화면에는 "최초 등록" / "수정 대기" 라벨로 구분 노출 (UI 단계, 데이터에는 별도 플래그 없음 — `approvedAt != null` 이면 "수정 대기").

**마스터 메뉴 필드 분류** (umbrella 결정 J 단일 진실원 그대로):

| 필드 | 분류 | 정책 | 사유 |
|---|---|---|---|
| `name` | 핵심 | 변경 시 status=pending 회귀 | 신원 / 가맹 표준 |
| `basePrice` | 핵심 | 회귀 | 가맹 표준 가격. 점포 priceOverride 와도 직결 |
| `optionGroupRefs` | 핵심 | 회귀 | 결정 D — 자동 적용 영향 광범위 |
| `mainCategoryCode` | 핵심 | 회귀 | 카테고리 일관성 |
| `subCategoryId` | 핵심 | 회귀 | 카테고리 일관성 |
| `description` | 핵심 | 회귀 | 신원 / 메뉴 설명 표준 |
| `visible` | 운영 | 즉시 반영 | 시즌 메뉴 ON/OFF — 운영 빈도 높음 |
| `tags` (`recommended`/`new`/`best`) | 운영 | 즉시 | 마케팅 운영 — 위험 낮음 |
| `displayOrder` | 운영 | 즉시 | UI 정렬 — 위험 거의 없음 |
| `imageUrl` | 운영 | 즉시 | 이미지 갱신 — 검수 ROI 낮음 |

**참고** — `disabledOptionGroupIds` / `disabledOptionItemIds` 는 마스터 메뉴(`brands/{brandId}/menuItems`)에 존재하지 않는다 (매장 단위 필드 — `menuOverrides` 또는 `stores/{id}/menuItems`). 본 sub-phase 무관.

**구현 패턴**: umbrella 결정 J 의 잠정안 (b) 메서드 분리 채택. Repository 시그니처는 아래 [Repository Interface](#repository-interface-신규) 참조.

**브랜드 entity (`brands/{brandId}`)**: 본 sub-phase 의 `BrandEntity` 도 같은 분리를 적용한다.

| 필드 | 분류 |
|---|---|
| `name` | 핵심 |
| `description` | 핵심 (브랜드 정체성) |
| `logoUrl` | 운영 (즉시 반영. 이미지 갱신 검수 ROI 낮음) |

`BrandRepository.upsertBrand` 가 변경 필드 분석해서 핵심 필드 변경 시만 `status=pending` 회귀, 운영 필드만 변경 시 status 보존. 단순화를 위해 본 sub-phase 는 brand 의 `logoUrl` 단일 운영 필드만 즉시 반영 처리 (메서드 분리 대신 (a) 변경 필드 분석 안 — 운영 필드가 1개이므로 별도 메서드를 둘 ROI 가 낮음).

### S4. 승인 큐 collectionGroup query

- 마스터 메뉴는 `brands/{brandId}/menuItems` 서브컬렉션. 모든 brand 의 pending 마스터 메뉴를 한 번에 보려면 **collectionGroup query** 사용.
- Firestore 인덱스: `menuItems` collectionGroup + `status == 'pending'` + `submittedAt desc` 단일 인덱스. 인덱스 자동 생성 또는 수동 생성은 별도 task `firestore_rules`/`firestore_indexes` 에서 처리. 본 sub-phase 는 query 코드만 작성하고 인덱스 누락 시 콘솔 안내 로그 노출.

### S5. brand role 화면 가드

- `RoleRouter` 분기에서만 처리 (각 화면 내부에 추가 가드 X). `RoleRouter` 가 `users/{uid}.role == 'brand'` 일 때만 `BrandScaffold` 진입 허용.
- role 미스매치 케이스 (예: brand role 인데 brandId 가 `null`) → fallback `LoginPage` + 에러 스낵바. 이 케이스는 admin 의 콘솔 세팅 누락 시에만 발생.

### S6. brand 의 brandId ownership 검증

- `BrandRepositoryImpl` / `MasterMenuItemRepositoryImpl` 가 `currentUidGetter`, `currentBrandIdGetter` 콜백을 받아 본인 brandId 가 아닌 entity 조작 시 `PermissionDeniedException`. UI 단 본인 brandId 만 노출 + 방어선.

### S7. 이미지 업로드 패턴

- **이미 사용 중인 `image_picker` 재사용** (점주 매장 이미지 업로드에서 도입됨). 추가 의존성 없음.
- Firebase Storage 경로:
  - 브랜드 로고: `brand_images/{brandId}/{timestamp}_{filename}`
  - 마스터 메뉴 이미지: `menu_images/brand/{brandId}/{menuItemId}/{timestamp}_{filename}`
- 클라이언트 검증:
  - 포맷: JPG / PNG (image_picker 가 자동 처리)
  - 용량: 5MB 이하 (초과 시 client-side 에러 메시지). 보안 규칙은 별도 task.
- 업로드 실패 시 메뉴/브랜드 저장 자체를 막고 에러 스낵바 표시 (이미지가 없는 entity 는 의미가 적음).

### S8. priceOverride 보존 알림 UseCase 시그니처만 정의

- `CountStoresUsingPriceOverrideUseCase(brandId, masterMenuItemId)` 와 Repository 메서드 시그니처 정의. **본 sub-phase 에서는 항상 0 반환** (매장 커스텀이 sub-phase 3 도입). 0 이어도 알림 다이얼로그는 표시 — sub-phase 3 후 실제 N 으로 자동 동작.

### S9. 마스터 메뉴 삭제 cascade 정의

- `MasterMenuItemRepository.deleteWithCascade(brandId, masterMenuItemId)`:
  1. `brands/{brandId}/menuItems/{masterMenuItemId}` 삭제
  2. **collectionGroup query** 로 모든 매장의 `menuOverrides/{masterMenuItemId}` 조회 → batch delete
- 본 sub-phase 에서 cascade 대상 0건 (sub-phase 3 후 실제 동작). brand UI 가 삭제 직전 확인 다이얼로그 (`N개 매장에서 제거됩니다` — N 은 S8 카운트).

### S10. AdminScaffold 탭 구성 (본 sub-phase 한정)

- 본 sub-phase 의 AdminScaffold 는 **2탭**: `승인 큐` / `더보기`.
- `승인 큐` 탭 내부에 **세그먼트 컨트롤** 로 `brand 승인` / `마스터 메뉴 승인` 분리.
- sub-phase 2 / 3 에서 `매장 승인` / `매장 커스텀 승인` 세그먼트가 추가된다.

---

## 데이터 모델

### Firestore (umbrella 모델 중 본 sub-phase 가 활성화하는 부분만)

```text
users/{uid}
  ├─ role: 'customer' | 'owner' | 'admin' | 'brand'      # 'brand' 신규 (umbrella 결정 G)
  └─ brandId?: String                                       # role='brand' 일 때만

brands/{brandId}                                            # 신규 컬렉션
  ├─ id, name, logoUrl, description
  ├─ status: 'pending'|'approved'|'rejected'
  ├─ submittedBy?, submittedAt?, approvedBy?, approvedAt?, rejectedReason?
  ├─ createdAt, updatedAt
  └─ menuItems/{menuItemId}                                 # 마스터 메뉴
       ├─ id, name, imageUrl, description
       ├─ scope: 'brand' (항상)
       ├─ brandId
       ├─ mainCategory, subCategoryId?
       ├─ basePrice
       ├─ optionGroupRefs: [{scope:'master', id}]           # master 만 (S2)
       ├─ tags, visible, displayOrder
       ├─ status: 'pending'|'approved'|'rejected'
       ├─ submittedBy?, submittedAt?, approvedBy?, approvedAt?, rejectedReason?
       └─ createdAt, updatedAt
```

본 sub-phase 에서 **추가하지 않는** 컬렉션 (umbrella 에 정의됨 — sub-phase 2~5 에서 활성):
- `stores/{id}.brandId`, `stores/{id}.status` (sub-phase 2)
- `stores/{id}/menuOverrides` (sub-phase 3)
- `stores/{id}/menuItems` 의 `disabledOption*` / `soldOut` (sub-phase 5)

### Domain Entity 정의

#### `BrandEntity` (신규)

```dart
@freezed
abstract class BrandEntity with _$BrandEntity {
  const factory BrandEntity({
    required String id,
    required String name,
    @Default('') String logoUrl,
    String? description,
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

#### `EntityApprovalStatus` (신규 enum)

```dart
enum EntityApprovalStatus {
  pending,
  approved,
  rejected;

  String get asString => name;
  static EntityApprovalStatus fromString(String? v) =>
    switch (v) { 'pending' => pending, 'rejected' => rejected, _ => approved }; // legacy default
}
```

#### `MenuItemScope` (신규 enum)

```dart
enum MenuItemScope { brand, store; ... }
```

#### `MenuItemEntity` 수정

기존 필드 + 추가:
- `MenuItemScope scope` (default `store`, DTO 누락 시 `store`)
- `String? brandId` (scope=brand 면 필수, scope=store + 브랜드 매장 한정 추가는 필수, 그 외 null)
- `List<String> tags` (default `[]`)
- `bool visible` (default `true`)
- `List<String> disabledOptionGroupIds` (default `[]`) — sub-phase 5 활성, 본 sub-phase 는 직렬화 default 만
- `List<String> disabledOptionItemIds` (default `[]`) — 동일
- `EntityApprovalStatus? status` (nullable — 개인 매장 메뉴는 null. 브랜드 마스터 / 점포 한정 추가는 not null)
- `submittedBy?`, `submittedAt?`, `approvedBy?`, `approvedAt?`, `rejectedReason?`
- `DateTime? updatedAt`

`storeId` 의미 확장: scope=brand 면 빈 문자열. customer 머지 단계에서 `storeId={매장ID}` 로 채워서 yield (umbrella 머지 규칙).

#### `UserRole` 수정

```dart
enum UserRole { customer, owner, admin, brand; ... }
fromString: 'brand' → UserRole.brand 추가.
```

### DTO / Model

- `BrandModel` (신규): `BrandEntity` 1:1 매핑. `fromFirestore` / `toFirestore`. `Timestamp ↔ DateTime` 변환.
- `MenuItemModel` 수정: 신규 필드 직렬화. `scope` 누락 시 `store`, `status` 는 nullable 유지 (`null` = 개인 매장 메뉴, `approved` = legacy 브랜드 메뉴 — 구분 필요). 그 외 default 는 umbrella 표 적용.

---

## 레이어 설계

### Domain

#### Entity (신규)
- `BrandEntity` — `lib/domain/entities/brand_entity.dart`
- `EntityApprovalStatus` — `lib/domain/entities/entity_approval_status.dart`
- `MenuItemScope` — `lib/domain/entities/menu_item_scope.dart`

#### Entity (수정)
- `MenuItemEntity` (위 신규 필드 추가), `UserRole` (`brand` 멤버 추가)

#### Repository Interface (신규)

`lib/domain/repositories/brand_repository.dart`:

```dart
abstract class BrandRepository {
  Stream<List<BrandEntity>> watchAll();                          // admin
  Stream<List<BrandEntity>> watchPendingForAdmin();              // admin
  Stream<BrandEntity?> watchById(String brandId);                // brand 본인 / admin
  /// 신규 등록 또는 핵심 필드(name/description) 변경 시. status=pending 회귀.
  /// 운영 필드(logoUrl) 만 변경 시 내부에서 자동 분기하여 status 보존 (S3 결정 J 적용).
  Future<String> upsertBrand(BrandEntity brand);
  Future<void> approveBrand(String brandId, String adminUid);
  Future<void> rejectBrand(String brandId, String adminUid, String reason);
  Future<void> deleteBrand(String brandId);                      // 매장 존재 시 차단 (sub-phase 2 진입 후 의미)
}
```

> **`upsertBrand` 의 내부 분기**: 신규 등록(id=='' 또는 doc 없음) 이면 항상 `status='pending'` 강제. 기존 brand 수정이면 변경 필드 셋을 분석 — `name` 또는 `description` 이 변경되면 `status='pending'` 회귀 + `submittedBy/At` 갱신 + `approvedBy/At` 보존, `logoUrl` 만 변경되면 status / 승인 메타 보존 + `updatedAt` 만 갱신. (운영 필드가 1개뿐이라 별도 메서드 분리 ROI 낮음 — 결정 J 의 안 (a) 채택)

`lib/domain/repositories/master_menu_item_repository.dart`:

```dart
abstract class MasterMenuItemRepository {
  Stream<List<MenuItemEntity>> watchByBrand(String brandId);     // brand 본인 + admin
  Stream<List<MenuItemEntity>> watchPendingForAdmin();           // collectionGroup query
  Future<String> createMasterMenuItem(MenuItemEntity item);      // status=pending 강제

  // ─── S3: 핵심/운영 분리 (umbrella 결정 J — 잠정안 (b) 메서드 분리 채택) ───
  /// 핵심 필드 (name, basePrice, optionGroupRefs, mainCategoryCode, subCategoryId, description) 변경.
  /// status=pending 으로 회귀 + submittedBy/At 갱신 + approvedBy/At 보존 (수정 대기 라벨용).
  Future<void> updateMasterMenuItemCore(MenuItemEntity item);
  /// 운영 필드 (visible, tags, displayOrder, imageUrl) 변경.
  /// status / 승인 메타 모두 보존. updatedAt 만 갱신. customer 측 즉시 반영.
  Future<void> updateMasterMenuItemOperation(MenuItemEntity item);

  Future<void> deleteWithCascade(String brandId, String menuItemId); // S9
  Future<MenuItemEntity> cloneAsDraft(String brandId, String sourceId); // 폼 prefill 용 — DB 저장 X. id='', name='{원본} 복사'
  Future<int> countStoresUsingPriceOverride(String brandId, String menuItemId); // S8 — 본 sub-phase 항상 0
  Future<void> approveMasterMenuItem(String brandId, String menuItemId, String adminUid);
  Future<void> rejectMasterMenuItem(String brandId, String menuItemId, String adminUid, String reason);
}
```

> **호환성 가드**: 기존 `updateMasterMenuItem(item)` 메서드는 폐기(@Deprecated 마커 후 제거). developer 가 본 sub-phase 의 마스터 메뉴 update 코드를 갱신할 때 호출부를 `updateMasterMenuItemCore` / `updateMasterMenuItemOperation` 둘로 분리해야 한다 (작업 분배 섹션 참조). `BrandMasterMenuFormPage` 가 변경된 필드 셋을 분석해 적절한 메서드를 호출 — 핵심 필드가 하나라도 포함되면 `updateMasterMenuItemCore`, 아니면 `updateMasterMenuItemOperation`. 두 종류가 한 폼에 섞이면 `updateMasterMenuItemCore` 우선 (status=pending 회귀가 안전쪽).

#### UseCase (신규, 13개. 단일 책임. Repository 2종만 의존)

- 브랜드: `WatchBrandByIdUseCase`, `WatchAllBrandsForAdminUseCase`, `WatchPendingBrandsUseCase`, `UpsertBrandUseCase`, `ApproveBrandUseCase`, `RejectBrandUseCase`
- 마스터 메뉴: `WatchMasterMenuItemsUseCase`, `WatchPendingMasterMenuItemsUseCase`, `CreateMasterMenuItemUseCase`, `UpdateMasterMenuItemCoreUseCase` (핵심 필드 변경 — status=pending 회귀), `UpdateMasterMenuItemOperationUseCase` (운영 필드 변경 — 즉시 반영), `DeleteMasterMenuItemUseCase`, `CloneMasterMenuItemUseCase`, `CountStoresUsingPriceOverrideUseCase`, `ApproveMasterMenuItemUseCase`, `RejectMasterMenuItemUseCase`

### Data

#### Model
- `BrandModel` — `lib/data/models/brand_model.dart`
- `MenuItemModel` 수정 — 신규 필드 직렬화. fromFirestore default 표 적용

#### DataSource (신규)
- `BrandRemoteDataSource` — `lib/data/datasources/remote/brand_remote_data_source.dart`
  - `streamAll()`, `streamPending()`, `streamById(brandId)`, `set(brandId, model)`, `update(brandId, partial)`, `delete(brandId)`
- `MasterMenuItemRemoteDataSource` — `lib/data/datasources/remote/master_menu_item_remote_data_source.dart`
  - `streamByBrand(brandId)`, `streamPending()` (collectionGroup), CRUD, `cascadeDeleteOverrides(masterMenuItemId)` (collectionGroup → batch)
  - 이미지 업로드는 기존 `StorageDataSource` 재사용. Storage 경로만 추가.

#### Repository Implementation
- `BrandRepositoryImpl` (`lib/data/repositories/brand_repository_impl.dart`) — `(BrandRemoteDataSource, currentUidGetter)`. `upsertBrand` 가 status=pending + submittedBy/At 세팅. approve/reject 가 admin uid 전달받아 메타 갱신.
- `MasterMenuItemRepositoryImpl` (`lib/data/repositories/master_menu_item_repository_impl.dart`) — `(MasterMenuItemRemoteDataSource, currentUidGetter, currentBrandIdGetter)`. ownership 검증 (S6) + optionGroupRefs scope 검증 (S2). `deleteWithCascade` 가 `cascadeDeleteOverrides` 호출.

### Presentation

#### Brand 모듈 (신규) — `presentation/brand/`

```text
presentation/brand/
├── brand_scaffold.dart                          # 3탭: 정보/메뉴/더보기 (매장은 sub-phase 3)
├── brand_info/
│   ├── brand_info_page.dart                     # 본인 brand status 라벨 + 수정 버튼
│   └── brand_info_form_page.dart                # 등록/수정 통합 폼 (이름/설명/로고)
├── master_menu/
│   ├── master_menu_list_page.dart               # status 뱃지 + CRUD 액션
│   ├── master_menu_form_page.dart               # 등록/수정/복제(prefill) 통합
│   └── master_menu_detail_page.dart             # 읽기 전용 상세 (옵션 셋)
├── more/
│   └── brand_more_page.dart                     # 로그아웃 / 버전
└── providers/
    ├── brand_di_providers.dart                  # Repository / DataSource DI
    ├── brand_info_providers.dart                # watchById, upsert
    └── brand_master_menu_providers.dart         # watchByBrand, count, CRUD
```

#### Admin 모듈 (신규) — `presentation/admin/`

```text
presentation/admin/
├── admin_scaffold.dart                          # 2탭: 승인 큐 / 더보기 (S10)
├── approval/
│   ├── admin_approval_queue_page.dart           # 세그먼트: brand 승인 / 마스터 메뉴 승인
│   ├── admin_brand_approval_detail_page.dart    # brand 정보 + 승인/반려
│   └── admin_master_menu_approval_detail_page.dart
├── more/
│   └── admin_more_page.dart                     # 로그아웃 / 버전
└── providers/
    ├── admin_di_providers.dart
    ├── admin_brand_approval_providers.dart      # watchPendingBrands
    └── admin_master_menu_approval_providers.dart # watchPendingMasterMenuItems
```

#### 공통 위젯 (신규)

- `ApprovalStatusBadge` — pending/approved/rejected 색상 뱃지
- `RejectReasonDialog` — admin 반려 사유 입력
- `MenuImagePicker` / `BrandLogoPicker` — image_picker 래퍼
- `OptionGroupRefPicker` — 옵션 그룹 다중 선택 (master scope only)
- `SubCategoryDropdown`, `TagsSelector`, `MenuItemListTile`

위치: 재사용 가능한 것 (`MenuImagePicker`, `ApprovalStatusBadge`, `RejectReasonDialog`) → `presentation/common/`. 모듈 한정 (`OptionGroupRefPicker`) → 모듈 내 widgets/.

#### 라우팅 — `RoleRouter` 수정

```dart
switch (user.role) {
  case UserRole.admin:    return const AdminScaffold();    // 신규
  case UserRole.brand:    return const BrandScaffold();    // 신규
  case UserRole.owner:    return const OwnerScaffold();    // 기존
  case UserRole.customer: return const ScaffoldWithNav();  // 기존
}
```

페이지 이동은 `Navigator.push(MaterialPageRoute)` 패턴 유지. router.dart 변경 없음.

---

## 데이터 흐름 (핵심 시나리오 5개)

### 1. 브랜드 등록 (brand → admin 승인)

```text
BrandInfoFormPage → UpsertBrandUseCase → BrandRepository.upsertBrand
→ BrandRepositoryImpl: status=pending, submittedBy/At 세팅, logoUrl: StorageDataSource.upload, Firestore set
─── (admin) AdminApprovalQueuePage[brand 세그먼트] → WatchPendingBrandsUseCase
→ AdminBrandApprovalDetailPage → ApproveBrandUseCase / RejectBrandUseCase(RejectReasonDialog)
→ BrandRepositoryImpl: status=approved/rejected + approvedBy/At/rejectedReason 세팅
```

### 2. 마스터 메뉴 등록 (brand → admin 승인)

```text
BrandMasterMenuListPage[+] → BrandMasterMenuFormPage(등록) → CreateMasterMenuItemUseCase
→ MasterMenuItemRepositoryImpl:
   - ownership 검증 (S6) + optionGroupRefs.every(scope==master) 검증 (S2)
   - scope=brand, status=pending 강제
   - imageUrl: StorageDataSource.upload (menu_images/brand/{brandId}/{newId}/...)
   - Firestore set
─── (admin) AdminApprovalQueuePage[메뉴 세그먼트] → WatchPendingMasterMenuItemsUseCase(collectionGroup)
→ AdminMasterMenuApprovalDetailPage → Approve/RejectMasterMenuItemUseCase
```

### 3. 마스터 메뉴 가격 변경 (brand → 핵심 필드 → priceOverride 보존 알림)

```text
BrandMasterMenuFormPage(수정, basePrice 변경 — 핵심 필드)
→ 저장 → 변경 필드 분석: basePrice 포함 → 핵심 필드 분기
→ CountStoresUsingPriceOverrideUseCase → 다이얼로그 "priceOverride 적용 매장 N개에 영향 없음" (본 sub-phase N=0)
→ 확인 → UpdateMasterMenuItemCoreUseCase → MasterMenuItemRepository.updateMasterMenuItemCore
→ status=pending 회귀 (S3) + submittedBy/At 갱신 + approvedBy/At 보존 (수정 대기 라벨)
→ admin 승인 큐 ["수정 대기"] 라벨 노출 → 승인 → status=approved → 적용
```

### 3-1. 마스터 메뉴 운영 필드 변경 (brand → 즉시 반영)

```text
BrandMasterMenuListPage 카드의 visible 토글 (시즌 메뉴 ON/OFF) — 또는 폼에서 tags / displayOrder / imageUrl 만 변경
→ 변경 필드 분석: 운영 필드만 포함 → 운영 필드 분기
→ UpdateMasterMenuItemOperationUseCase → MasterMenuItemRepository.updateMasterMenuItemOperation
→ status / 승인 메타 모두 보존, updatedAt 만 갱신
→ Firestore 갱신 즉시 customer 머지 단계 반영 (umbrella 머지 규칙: status==approved && visible 인 마스터만 yield)
→ admin 승인 큐 진입 X. brand 폼에서 SnackBar "즉시 반영되었습니다"
```

> **혼합 케이스**: 한 폼에서 visible 과 basePrice 를 동시에 변경 → 핵심 필드 우선 → `updateMasterMenuItemCore` 호출 (status=pending 회귀). UI 단계에서 "가격이 변경되어 검수 대기로 전환됩니다" 안내. 운영 필드만 단독 토글하는 케이스를 보호하기 위해 리스트 카드의 visible / tags 토글은 form 진입 없이 직접 운영 메서드 호출.

### 4. 마스터 메뉴 복제 (brand 화면, 폼 prefill)

```text
BrandMasterMenuListPage[복제] → CloneMasterMenuItemUseCase → cloneAsDraft
→ 원본 fetch → copyWith(id='', name='{원본} 복사', status=null, 승인 메타 reset) — DB 저장 X
→ BrandMasterMenuFormPage(등록 모드 + prefill) → 수정 후 저장 → 시나리오 2 동일
```

### 5. 마스터 메뉴 삭제 (cascade)

```text
BrandMasterMenuListPage[삭제] → CountStoresUsingPriceOverrideUseCase → N
→ 다이얼로그 "N개 매장에서 제거됩니다" → 확인 → DeleteMasterMenuItemUseCase
→ MasterMenuItemRepositoryImpl.deleteWithCascade:
   - collectionGroup query: stores/*/menuOverrides where masterMenuItemId == id
   - batch: brands/{brandId}/menuItems/{id} delete + 모든 override delete
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 권한 미달 (brand role 아님) | `RoleRouter` 가 분기에서 차단. 직접 진입 시도 시 `LoginPage` fallback |
| brand role 인데 brandId null | `BrandScaffold` 진입 시 `_BrandIdMissingView` 노출 + admin 재발급 안내 |
| 다른 brand 의 entity 조작 시도 | `PermissionDeniedException` (S6) → 스낵바 "권한이 없습니다" |
| Firestore 읽기 실패 (네트워크) | `AsyncError` → 에러 위젯 + 재시도 버튼 (Riverpod refresh) |
| 동시 편집 (admin 이 승인하는 동안 brand 가 수정) | 마지막 write 우선. updatedAt 비교 X. 다음 stream tick 으로 자동 갱신 |
| 이미지 업로드 실패 | 메뉴/브랜드 저장 자체를 막고 에러 스낵바 |
| 이미지 용량 초과 (5MB) | 업로드 직전 client validation → 에러 메시지 |
| optionGroupRefs scope 위반 (S2) | `ArgumentError` → 폼 단계에서 미리 차단 (UI 가 이미 store scope 미노출) |
| collectionGroup query 인덱스 누락 | 에러 위젯 + 콘솔 안내 로그 (인덱스 자동/수동 생성은 별도 task) |
| 인증 만료 | 기존 auth flow (재로그인) |

---

## 작업 분배 판단

### designer 호출 — **권장 (필수)**

새 화면이 다수 (brand 모듈 4종 + admin 모듈 3종 + 공통 위젯 8종). 디자인 시스템 적용 / 상태 UI / 컴포넌트 정의가 큼.

- 디자인 산출물: `docs/tasks/admin_menu_management/1_brand_master/design.md`
- 전달할 사항:
  - BrandScaffold (3탭) / AdminScaffold (2탭) 의 BottomNavigation 디자인
  - `ApprovalStatusBadge` 색상 — pending=primaryBright, approved=success, rejected=error 등 토큰 매핑
  - 폼 화면 (`BrandInfoFormPage`, `BrandMasterMenuFormPage`) 의 입력 필드 / picker 배치
  - 승인 큐 리스트 / 상세 / 반려 사유 다이얼로그 흐름
  - 빈 상태 / 로딩 / 에러 UI

### developer 호출

designer 완료 후. 의존 순서: Domain → Data → Presentation.

- 구현 항목: 위 레이어 설계의 모든 파일
- 재사용:
  - `image_picker` 패턴 (점주 매장 이미지 업로드)
  - `StorageDataSource` (경로만 추가)
  - `Navigator.push(MaterialPageRoute)`
  - 기존 freezed / Riverpod 패턴
- 주의할 레이어 규칙:
  - `RoleRouter` 의 `brand` 분기 추가 시 import 순환 주의 (presentation 끼리는 OK)
  - `MasterMenuItemRepositoryImpl` 의 collectionGroup query — Firebase SDK 직접 사용은 data 레이어에서만
  - `MenuItemEntity` 수정 시 기존 사용처 (customer / owner) 무영향 확인 — DTO default 값으로 흡수
- `pubspec.yaml`: 추가 패키지 없음 (image_picker 이미 존재). `rxdart` 는 sub-phase 3 에서 추가.

### tester 호출

developer 완료 후. `test_report.md`.

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능
- [ ] BrandScaffold 진입 (`role='brand'` + `brandId` 세팅된 사용자) — 3탭 노출
- [ ] BrandScaffold 진입 (`role='brand'` + `brandId=null`) — 안내 화면
- [ ] AdminScaffold 진입 (`role='admin'`) — 2탭 노출 (승인 큐 / 더보기)
- [ ] 브랜드 등록 → status=pending → admin 승인 → status=approved 확인
- [ ] 브랜드 등록 후 admin 반려 (사유 입력) → status=rejected + reason 표시
- [ ] 마스터 메뉴 CRUD (생성/수정/삭제) 동작
- [ ] 마스터 메뉴 등록 후 admin 승인 → status=approved
- [ ] 마스터 메뉴 핵심 필드 변경 (basePrice / name / optionGroupRefs / category / description) → 알림 다이얼로그 → status=pending 회귀 + approvedBy/At 보존 (수정 대기 라벨)
- [ ] 마스터 메뉴 운영 필드 변경 (visible / tags / displayOrder / imageUrl) → status 보존 (즉시 반영) + admin 승인 큐 진입 X
- [ ] 운영 필드 + 핵심 필드 혼합 변경 → 핵심 우선 → status=pending 회귀
- [ ] 브랜드 운영 필드 변경 (logoUrl 만 변경) → status 보존, 핵심 필드(name/description) 변경 시 status=pending 회귀
- [ ] 마스터 메뉴 복제 → 폼 prefill + name='{원본} 복사' 확인
- [ ] 마스터 메뉴 삭제 → 확인 다이얼로그 → 삭제됨 (cascade 대상 0건)
- [ ] 옵션 그룹 picker 에서 store scope 미노출
- [ ] 다른 brand 의 entity 조작 시도 (직접 firestore manipulation 시뮬레이션) → 차단 (UI 단)
- [ ] 이미지 5MB 초과 업로드 → 에러
- [ ] 승인 큐 collectionGroup query — 두 브랜드 이상의 pending 메뉴를 한 화면에서 노출

### 회귀 (customer / owner 무영향)
- [ ] 시드 매장 (brandId=null, status=approved default) — 메뉴 그대로 노출
- [ ] customer `StoreMenuPage` / `MenuItemDetailPage` 동작 그대로
- [ ] owner 점주 `OwnerScaffold` / `MyStorePage` 동작 그대로
- [ ] `MenuItemRepository.watchByStore` 시그니처 불변 + 동작 동일

### 코드 품질
- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (freezed/json_serializable 재생성)

---

## 완료 기준

- [ ] `spec.md` 본 문서 (현재) 확정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] BrandScaffold 진입 + 브랜드 등록 + admin 승인 동작
- [ ] 마스터 메뉴 CRUD + 복제 + 삭제 cascade (대상 0건) + 가격 변경 알림 다이얼로그 동작
- [ ] AdminScaffold 의 brand / 마스터 메뉴 승인 큐 동작 (collectionGroup query)
- [ ] customer / owner 회귀 0
- [ ] `flutter analyze` 0 issue
