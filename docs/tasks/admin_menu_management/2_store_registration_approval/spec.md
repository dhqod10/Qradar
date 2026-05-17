# sub-phase 2 — store_registration_approval 기능 명세

> **상태**: APPROVED — architect 보강 완료
>
> **umbrella 단일 진실원**: 데이터 모델 / 결정사항 (1~12, A~F, G/H/I) / 권한 매트릭스 / role 라우팅 / customer 측 머지 규칙 → [`../spec.md`](../spec.md). 본 sub-phase 는 그 결정을 그대로 따른다 — 재서술하지 않는다.
>
> **sub-phase 1 산출물 재사용**: `EntityApprovalStatus` enum / `ApprovalStatusBadge` / `RejectReasonDialog` / `ApprovalActionsBar` / `AdminScaffold` / `RoleRouter.admin` 분기 → [`../1_brand_master/spec.md`](../1_brand_master/spec.md). 본 sub-phase 는 이를 확장만 한다.
>
> **sub-phase 6 영향 (V3 / V4)**: sub-phase 6 진입 후 본 sub-phase 의 결정 T6 / `StoreCoreFormPage` 가 갱신된다. 상세는 [`../6_upgrade_to_brand/spec.md`](../6_upgrade_to_brand/spec.md) 참조.
>
> - **결정 T6 보강**: "owner 매장 등록 시 brandId — 점주 폼에 brandId UI 없음. RepositoryImpl 가 자동으로 `null` 박음" 은 sub-phase 6 진입 후 갱신됨. **점주 폼에 "브랜드 가맹점입니까?" 토글 + brandKey 입력 필드 추가** (sub-phase 6 의 V3). 토글 OFF 시 기존 동작 (brandId=null), 토글 ON + brandKey 매칭 → `store.brandId` 자동 박힘.
> - **`StoreCoreFormPage` 갱신** — 토글 + brandKey 입력 + `LookupBrandByKeyUseCase` (sub-phase 6 신규 UseCase) 검증 호출. 매칭 X 시 SnackBar "정상 브랜드 키가 아닙니다" 후 제출 중단 (sub-phase 6 의 V4).
> - 검증 항목 추가: 토글 OFF/ON 흐름, brandKey 매칭 / 미스매치 흐름.

---

## 개요

- **목적**: `admin_menu_management` 의 두 번째 sub-phase. **점주(owner)의 개인 매장 등록 흐름** 을 기존 `owner_store_registration` phase 에 **admin 승인 게이트** 로 확장하고, **admin 의 매장 승인 큐** 를 sub-phase 1 의 admin 모듈 위에 얹는다. customer 측 매장 검색은 Repository 내부 필터(`status == approved`) 만 추가하여 호출부 변경을 0 으로 유지한다.
- **작업 유형**: 기존 phase 확장 + 신규 화면 (admin 매장 승인 큐 / 매장 상세) + Domain/Data 모델 확장
- **영향 범위**:
  - 화면(owner): `OwnerMyStorePage` / `StoreFormPage` 갱신 — status 라벨, 반려 사유, 재제출 CTA
  - 화면(admin): `AdminScaffold` 세그먼트 컨트롤 확장 (브랜드 / 마스터 메뉴 → **+ 매장**), `AdminPendingStoresPage` (신규), `AdminStoreApprovalDetailPage` (신규)
  - 화면(customer): **변경 없음** — `StoreRepository` 의 customer 진입점에 status 필터만 내부 추가. `Phase1a` / `Phase1b` / `Phase1c` / `Phase2` 호출부 무영향
  - 화면(brand): **변경 없음** — sub-phase 3 에서 brand 의 매장 커스텀 진입
  - Domain: `StoreEntity` 필드 확장 (`brandId?`, `status`, 승인 메타 6필드). Repository 메서드 추가. UseCase 6종 신규.
  - Data: `StoreModel` 직렬화 확장 + missing field default 적용. `StoreRemoteDataSource` 메서드 추가. `StoreRepositoryImpl` customer 측 read 에 status 필터 / ownership 검증 추가
  - Presentation: `presentation/admin/approval/` 확장 (세그먼트 3탭화 + 매장 승인 화면 2종). `presentation/owner/my_store/` 갱신
  - 라우팅: 변경 없음 (`Navigator.push(MaterialPageRoute)` 유지)
  - 테스트: customer / Phase 1a~2 회귀 테스트 필수 (시드 매장 `brandId=null`, missing status → `approved` fallback 동작 검증)
- **비범위** (umbrella + 본 sub-phase 한정):
  - 브랜드 매장 등록 / brand 의 매장 커스텀 → sub-phase 3
  - 점주 개인 매장 메뉴 CRUD → sub-phase 4
  - 점주 옵션 비활성 / 품절 토글 → sub-phase 5
  - brand role 매장 등록 (마스터 기반 커스텀) → sub-phase 3 (점주는 `brandId=null` 만 등록 가능)
  - 점주의 brandId 선택 UI (umbrella 결정 3 — 점주 폼은 항상 `brandId=null`)
  - N:1 brand 매핑 → 후속 phase
  - Cloud Functions cascade — 본 phase 비범위 (클라이언트 batch delete 만)
  - Firestore 보안 규칙 / 인덱스 → 별도 task `firestore_rules` / `firestore_indexes`
  - 매장 위치 기반 `geohash` 인덱스 변경 → Phase 1a 인덱스 그대로

---

## 의존 phase / 진입 조건

- **의존 phase**: 없음 (1_brand_master 와 독립). 단 sub-phase 1 의 다음 산출물을 **그대로 재사용**:
  - `EntityApprovalStatus` enum (`pending` / `approved` / `rejected`, `fromString` 의 missing → `approved` fallback 포함)
  - `ApprovalStatusBadge` (공통 위젯, status 색상 토큰 매핑)
  - `RejectReasonDialog` (공통 위젯, admin 반려 사유 입력 모달)
  - `ApprovalActionsBar` (공통 위젯, 승인/반려 버튼)
  - `AdminScaffold` 의 2탭(`승인 큐` / `더보기`) 골격 → 본 sub-phase 가 `승인 큐` 탭의 세그먼트 컨트롤만 2탭 → 3탭 확장
  - `RoleRouter` 의 `admin` 분기

  → 코드 워크플로우상 **sub-phase 1 진입 후** 본 sub-phase 진입이 자연스럽다. 1 미진입 상태에서 본 sub-phase 만 작업할 수도 있으나 그 경우 위 산출물을 본 sub-phase 가 먼저 만들어야 함.
- **진입 조건**:
  - umbrella `spec.md` APPROVED (완료)
  - sub-phase 1 진입 권장 (필수 아님)
  - 기존 `owner_store_registration` phase 의 산출물(`StoreFormPage`, `OwnerMyStorePage`, `StoreRepository`, `StoreRepositoryImpl`) 활성 상태
  - 테스트용 admin 계정 1개 (Firestore 콘솔에서 `users/{uid}.role='admin'`)

---

## 확정된 결정사항 (sub-phase 한정)

> umbrella 결정 1~12 / A~F / G/H/I 와 sub-phase 1 결정 S1~S10 은 단일 진실원 그대로 따른다. 여기서는 본 sub-phase 한정 결정만 기록한다.

### T1. 시드 매장 / 기존 매장의 status 처리 — **(b) Repository / model fallback** 채택

- 마이그레이션 스크립트 없이 코드 단으로 호환성 확보.
- `StoreModel.fromFirestore` 가 `status` 필드 누락 시 `EntityApprovalStatus.approved` 로 default (sub-phase 1 의 `EntityApprovalStatus.fromString` 이 이미 missing → `approved` fallback 을 가짐).
- `StoreModel.fromFirestore` 가 `brandId` 필드 누락 시 `null`.
- `phase1_seed_data.dart` 의 시드 매장(`phase1_seed_store_001` 등) 은 향후 갱신 시 `status='approved'` 명시 가능 (선택). 갱신 안 해도 fallback 으로 흡수되므로 기존 시드 호환성 보장.
- 운영 DB 의 기존 매장(이미 박힌 doc) 은 fallback 으로 `approved` 처리되어 customer 검색에 그대로 노출.

### T2. status 회귀 정책 — **핵심/운영 필드 분리 (umbrella 결정 J 적용)**

> **변경 이력**: 본 결정의 초기안은 "모든 매장 정보 수정 → status=pending 회귀" 였으나, 사용자 의도("등록만 검수, 이후 자율 운영") 와 어긋나고 운영 효율(영업시간 / 사진 / 전화번호 변경 같은 일상 운영) 을 해친다는 판단으로 **결정 J — 핵심/운영 필드 분리** 로 갱신.

```text
[draft, 미저장]
   ↓ (점주 등록)
pending  ───→ (admin 승인)  ───→ approved
   ↑                                    │
   │ (점주 재제출)                      │ (점주 핵심 필드 수정)
   │                                    ↓
rejected ←── (admin 반려, 사유 메모)  pending  ←── 핵심 필드만 회귀
                                         │
                                        approved ←── 운영 필드 변경은 즉시 반영, status 회귀 X
```

**매장 필드 분류** (umbrella 결정 J 단일 진실원 그대로):

| 필드 | 분류 | 정책 | 사유 |
|---|---|---|---|
| `name` | 핵심 | 변경 시 status=pending 회귀 | 매장 신원. 가맹/검색 결과 일관성 |
| `address` | 핵심 | 회귀 | 위치 정합성 / 검색 결과 정확도 |
| `lat`, `lng` | 핵심 | 회귀 | 위치 인덱스 / geohash 영향 |
| `mainCategory` | 핵심 | 회귀 | 카테고리 검색 노출 일관성 |
| `subCategories` | 핵심 | 회귀 | 카테고리 검색 노출 일관성 |
| `businessRegistrationNumber` | 핵심 | 회귀 (등록 1회, 보통 수정 없음) | 사업자 신원 |
| `businessHours` (영업시간) | 운영 | 즉시 반영 | 시즌별/요일별 변경 빈도 높음 |
| `temporaryClosed` (임시 휴무 토글) | 운영 | 즉시 | 일상 운영 (휴가 등) |
| `closedDates` (휴무일 리스트) | 운영 | 즉시 | 위와 동일 |
| `phoneNumber` (전화번호) | 운영 | 즉시 | 회선 변경 — 위험 낮음 |
| `imageUrls` (대표 사진) | 운영 | 즉시 | 사진 갱신 — 검수 ROI 낮음 |
| `interiorImages` (내부 사진) | 운영 | 즉시 | 위와 동일 |
| `description` (매장 설명) | 운영 | 즉시 | 마케팅 텍스트 — 위험 낮음 |
| `notice` (매장 안내) | 운영 | 즉시 | 공지 — 즉시성 필요 |

**status 운용**:
- 점주가 매장 핵심 필드를 변경하면 `status=pending` 으로 회귀 + `submittedBy/At` 갱신 + `approvedBy/At` 보존 (수정 대기 라벨 식별용).
- 점주가 매장 운영 필드만 변경하면 status / 승인 메타 모두 보존. `updatedAt` 만 갱신. customer 검색에서 사라지지 않고 즉시 반영.
- 한 폼/세션에서 핵심 + 운영 동시 변경 → 핵심 필드 우선 → status=pending 회귀 + UI 안내.
- admin 승인 큐 화면에서 `approvedAt != null && status==pending` 이면 "수정 대기" 라벨 노출 (UI 단계, 데이터 별도 플래그 없음 — sub-phase 1 의 S3 패턴 동일).

**구현 패턴 (umbrella 결정 J 의 잠정안 (b) 메서드 분리 채택)** — Repository 시그니처 / UseCase / 폼 구성은 아래 [Repository Interface](#repository-interface-확장) 와 [Owner 모듈 갱신](#owner-모듈-갱신-presentationownermy_store) 섹션 참조.

**designer 위임**: 점주 매장 폼을 두 폼(`매장 정보 수정` — 핵심 / `매장 운영 정보` — 운영) 으로 분리하거나, 한 폼에서 섹션을 나누고 저장 시 자동 분기. designer 가 UX 관점에서 결정. 잠정안 — **두 폼 분리 권장** (사용자가 어떤 변경이 검수에 들어가는지 명확히 인지). designer 가 번복 가능.

### T3. rejected → 재제출 시 메타 클리어 — **rejectedReason / approvedBy / approvedAt 모두 null 클리어**

- 점주가 rejected 매장을 수정 후 재제출 → `status=pending` + `rejectedReason=null` + `approvedBy=null` + `approvedAt=null` 로 클리어. `submittedBy=uid`, `submittedAt=now` 갱신 (재제출 시점이 새로운 신청).
- 이유: rejected → pending 회귀는 "신규 등록 재시도" 로 보고, 이전 승인 흔적 / 반려 사유는 의미 없음. UI 도 "수정 대기" 가 아닌 "최초 등록" 으로 식별됨 (`approvedAt == null`).

### T4. ownership 검증 — **sub-phase 1 의 S6 패턴 그대로 적용 (UID + role 분기)**

- `StoreRepositoryImpl` 가 `currentUidGetter`, `currentRoleGetter` 콜백을 받음.
- 본인 매장(`ownerId == currentUid`) 외 매장에 점주가 write 시도 → `PermissionDeniedException` (UI 단 방어선).
- `role == admin` 인 사용자는 모든 매장 write 가능 (approve / reject 액션 진입점).
- read 메서드 (`watchByOwner` / `getNearbyStores` 등) 는 ownership 검증 없이 진행 (read 권한은 기본적으로 어드민/본인이 호출. customer read 는 status='approved' 필터로 가림).

### T5. AdminScaffold 세그먼트 확장 — **본 sub-phase 진입 후 3탭 (브랜드 / 마스터 메뉴 / 매장)**

- sub-phase 1 진입 후: `브랜드` / `마스터 메뉴` (2탭)
- 본 sub-phase 진입 후: `브랜드` / `마스터 메뉴` / **`매장`** (3탭)
- sub-phase 3 진입 후의 추가 세그먼트 (매장 커스텀 등) 는 sub-phase 3 spec 작성 시 결정 (본 sub-phase 비범위).
- 세그먼트 컨트롤은 단일 위젯 `AdminApprovalQueueSegmented` (sub-phase 1 산출) 가 다루며, segment item 만 enum 으로 추가하면 됨.

### T6. owner 매장 등록 시 brandId — **점주 폼에 brandId UI 없음. RepositoryImpl 가 자동으로 `null` 박음**

- `StoreFormPage` (점주 폼) UI 변경 없음 (brandId 입력 필드 노출 X).
- `StoreRepositoryImpl.createStore` 가 자동으로 `brandId=null` 강제. brand role 의 매장 등록 진입점은 sub-phase 3 에서 별도 메서드(`createBrandStore`) 또는 동일 `createStore` + caller(role=brand) 분기로 처리 (sub-phase 3 결정 사항).

### T7. customer 측 status 필터 — **단일 헬퍼 `_filterApproved` 또는 query level `where('status','==','approved')`**

- 모든 customer 진입점 (`getNearbyStores` / `getStoresByCategories` / 매장 검색 / 추천 등) 에 `status == 'approved'` 필터 적용.
- 구현: `StoreRepositoryImpl` 내부에서 query 단계에 `where('status', isEqualTo, 'approved')` 추가. **단**, missing status 인 legacy doc 은 query 매칭에서 빠지므로 다음 안전망 필요:
  - **(a)** 마이그레이션 스크립트로 모든 legacy doc 에 `status='approved'` 박기 — 본 phase 비범위
  - **(b)** Firestore query 가 아닌 client side filter — `streamAll().where(model.status==approved)`. missing 은 fromFirestore default 로 `approved` 가 되므로 통과.
  - 잠정안 (확정): **(b) client side filter** 채택. 매장 수가 많아지기 전(MVP 단계) 까지 client filter 로 충분. 매장 수 폭증 시점에 마이그레이션 스크립트 + query level filter 로 전환 (별도 task).

### T8. 반려 사유 글자 수 제한 — **제한 없음** (sub-phase 1 패턴 동일)

- `RejectReasonDialog` (sub-phase 1 산출) 그대로 재사용. client side 글자 수 제한 없음. 서버측 제한은 별도 task `firestore_rules`.

### T9. 매장 카드 뱃지 — **"개인 매장" 뱃지만**

- 본 sub-phase 의 admin 매장 승인 큐 / 매장 상세 화면 카드에 `개인 매장` 뱃지 노출 (점주 등록 매장 = `brandId=null` 인 매장만 본 sub-phase 대상).
- 브랜드 매장 뱃지 (`{브랜드명}` 또는 `브랜드 매장` 표시) 는 sub-phase 3 에서 추가.
- `ApprovalStatusBadge` 와 별개의 위젯 — `StoreScopeBadge('개인 매장' | '브랜드 매장')`. 본 sub-phase 에서는 항상 "개인 매장" 표시.

### T10. owner 측 status 라벨 노출 — **카드 + 상세 양쪽 노출**

- `OwnerMyStorePage` 의 매장 카드: `ApprovalStatusBadge` 표시 (pending=노란색, approved=초록색, rejected=빨간색 — 토큰은 designer 결정).
- pending 상태: "검토 대기 중" 라벨 + 매장 정보 수정 가능 (수정 시 pending 회귀 X — 이미 pending).
- approved 상태: 라벨 + 매장 정보 수정 가능 (수정 시 pending 회귀, T2).
- rejected 상태: 라벨 + `rejectedReason` 노출 + "재제출" CTA (CTA 클릭 시 `StoreFormPage` 진입, 저장 시 T3 동작).

---

## 데이터 모델

### Firestore (umbrella 모델 중 본 sub-phase 가 활성화하는 부분)

```text
stores/{storeId}
  ├─ ... (Phase 1a 기존 필드: id, name, imageUrl, location, grade, ownerId, ...)
  ├─ brandId?: String | null                                # 신규 (default null, 점주 등록 매장은 항상 null)
  ├─ status: 'pending'|'approved'|'rejected'                # 신규 (default 'approved' — legacy fallback)
  ├─ submittedBy?: String                                   # 점주 uid
  ├─ submittedAt?: Timestamp                                # 점주 제출 시점
  ├─ approvedBy?: String                                    # admin uid (approve/reject 양쪽 갱신)
  ├─ approvedAt?: Timestamp                                 # admin 승인 시점 (rejected 도 동일 필드 사용)
  └─ rejectedReason?: String                                # admin 반려 사유 (status=rejected 일 때만 의미)
```

> **status 운용 규칙**:
> - 점주 신규 등록 → `status='pending'` 강제
> - admin 승인 → `status='approved'` + `approvedBy/At`
> - admin 반려 → `status='rejected'` + `approvedBy/At` + `rejectedReason`
> - 점주 수정 (approved → pending) → `status='pending'` + `submittedBy/At` 갱신, `approvedBy/At` 보존 (T2 "수정 대기" 식별)
> - 점주 재제출 (rejected → pending) → `status='pending'` + `submittedBy/At` 갱신 + `approvedBy/At/rejectedReason` 모두 null 클리어 (T3)
> - customer 검색 진입점 → `status='approved'` 만 노출 (T7)

### Domain Entity 정의

#### `StoreEntity` 수정 (Phase 1a 기반 + 본 sub-phase 추가)

기존 필드 + 추가:
- `String? brandId` (default `null`)
- `EntityApprovalStatus status` (default `EntityApprovalStatus.approved` — legacy 안전)
- `String? submittedBy`
- `DateTime? submittedAt`
- `String? approvedBy`
- `DateTime? approvedAt`
- `String? rejectedReason`

`StoreEntity` 의 `ownerId` 와 `submittedBy` 의 의미 분리:
- `ownerId` : 매장 소유 점주 uid (변경 잘 안 됨, Phase 1a 기존)
- `submittedBy` : "이번 신청을 제출한 사용자" (점주가 매번 갱신. 추후 brand role 매장 등록 시 brand uid 가 박힐 수 있음 — sub-phase 3)

#### `EntityApprovalStatus` (sub-phase 1 산출 그대로)

`pending` / `approved` / `rejected`. `fromString` 이 missing → `approved` fallback 을 가짐 (legacy 매장 안전).

### DTO / Model

- `StoreModel` 수정 — `fromFirestore` / `toFirestore` 양쪽에 신규 필드 직렬화 추가:
  - `brandId`: 누락 시 `null`
  - `status`: 누락 시 `EntityApprovalStatus.approved` (T1)
  - `submittedBy/At`, `approvedBy/At`, `rejectedReason`: 누락 시 `null`
  - `Timestamp ↔ DateTime` 변환 (Phase 1a 기존 헬퍼 재사용)

---

## 레이어 설계

### Domain

#### Entity (수정)
- `StoreEntity` (`lib/domain/entities/store_entity.dart`) — 필드 7개 추가 (위 데이터 모델 참조)
  - `freezed` 재생성 필요 (`dart run build_runner build --delete-conflicting-outputs`)

#### Repository Interface (확장)

`lib/domain/repositories/store_repository.dart` 메서드 추가:

```dart
abstract class StoreRepository {
  // ─── 기존 (Phase 1a) ───
  Future<List<StoreEntity>> getNearbyStores({...});       // (수정 X 시그니처) 내부 status='approved' 필터
  Future<List<StoreEntity>> getStoresByCategories({...}); // (수정 X 시그니처) 내부 status='approved' 필터
  Future<String> createStore(StoreEntity store);          // (확장) 점주: status=pending + brandId=null 자동
  Future<void> deleteStore(String storeId);
  Stream<StoreEntity?> watchByOwner(String ownerId);

  // ─── 신규 (본 sub-phase) ───
  Future<StoreEntity?> getById(String storeId);                       // admin 상세 진입
  Stream<List<StoreEntity>> watchAllForAdmin();                       // status 무관, admin 전용
  Stream<List<StoreEntity>> watchPendingStoresForAdmin();             // status='pending' 만, admin 승인 큐
  Future<void> approveStore(String storeId, String adminUid);
  Future<void> rejectStore(String storeId, String adminUid, String reason);
  Future<void> submitStoreForApproval(StoreEntity store);             // 점주 등록/재제출 통합 진입점

  // ─── 신규 (T2 — 핵심/운영 필드 분리, umbrella 결정 J 잠정안 (b) 메서드 분리) ───
  /// 매장 핵심 필드 (name/address/lat/lng/mainCategory/subCategories/businessRegistrationNumber) 변경.
  /// status=pending 으로 회귀 + submittedBy/At 갱신 + approvedBy/At 보존.
  /// rejected 상태에서 호출되면 T3 동작 (재제출 — approvedBy/At/rejectedReason 모두 null 클리어).
  Future<void> updateStoreCoreFields(StoreEntity store);
  /// 매장 운영 필드 (businessHours/temporaryClosed/closedDates/phoneNumber/imageUrls/interiorImages/description/notice) 변경.
  /// status / 승인 메타 모두 보존. updatedAt 만 갱신. customer 검색에서 즉시 반영.
  Future<void> updateStoreOperationFields(StoreEntity store);
}
```

> **호환성 가드**: 기존 `updateStore(store)` 메서드는 본 sub-phase 진입과 함께 폐기(@Deprecated 후 제거). owner_store_registration phase 의 `StoreFormPage` 호출부는 `submitStoreForApproval` (핵심 폼 / 신규 등록) 또는 `updateStoreOperationFields` (운영 폼) 로 갈린다 — `submitStoreForApproval` 내부에서 신규 등록(id 빈 문자열) 이면 `createStore`, 기존 매장이면 `updateStoreCoreFields` 위임. 운영 폼은 `updateStoreOperationFields` 직접 호출.

#### UseCase (신규, 7종)

- `WatchPendingStoresForAdminUseCase` (admin 승인 큐 데이터 소스)
- `WatchAllStoresForAdminUseCase` (admin 전체 매장 리스트, 본 sub-phase 진입점은 승인 큐만이므로 우선 시그니처만)
- `GetStoreByIdUseCase` (admin 매장 상세)
- `ApproveStoreUseCase`
- `RejectStoreUseCase`
- `SubmitStoreForApprovalUseCase` (점주 등록 / 핵심 필드 수정 / 재제출 — RepositoryImpl 안에서 신규 vs 핵심 수정 vs 재제출 자동 분기)
- `UpdateStoreOperationFieldsUseCase` (점주 운영 필드 변경 — 즉시 반영. T2 / 결정 J)

owner 측 매장 watch 는 기존 `WatchOwnerStoreUseCase` (Phase 1a 산출) 그대로 사용. status 라벨은 entity 의 status 필드를 보면 됨.

### Data

#### Model (수정)
- `StoreModel` (`lib/data/models/store_model.dart`) — 신규 필드 직렬화 추가. `fromFirestore` 의 default 적용 (T1).

#### DataSource (확장)
- `StoreRemoteDataSource` (`lib/data/datasources/remote/store_remote_data_source.dart`) 메서드 추가:
  - `streamAll()` (status 무관)
  - `streamPending()` (status='pending')
  - `getById(storeId)`
  - `update(storeId, partialFields)` — approve/reject 시 부분 갱신용
- 기존 메서드 (`streamByOwner`, `streamNearby`, `streamByCategories`) 시그니처 불변. 단 `streamNearby`/`streamByCategories` 는 RepositoryImpl 단계에서 client filter (T7).

#### Repository Implementation (확장)
- `StoreRepositoryImpl` (`lib/data/repositories/store_repository_impl.dart`) — `(StoreRemoteDataSource, StorageDataSource, currentUidGetter, currentRoleGetter)` 의존:
  - `createStore(store)` → 점주 등록: `store.copyWith(brandId=null, status=pending, submittedBy=uid, submittedAt=now)` 강제 후 datasource 호출
  - `updateStoreCoreFields(store)` → ownership 검증 (T4). 기존 매장 status 가 `approved` 면 `status=pending + submittedBy/At` 갱신, `approvedBy/At` 보존 (T2). `rejected` 면 T3 동작 (재제출 — `approvedBy/At/rejectedReason` 모두 null 클리어). `pending` 이면 그대로 (재제출 의미).
  - `updateStoreOperationFields(store)` → ownership 검증 (T4). status / 승인 메타 모두 무변경. 운영 필드만 partial update + `updatedAt=now`. 어떤 status (pending/approved/rejected) 에서도 호출 가능. customer 측 즉시 반영 (status='approved' 였다면 검색 결과 그대로 유지하면서 운영 정보만 갱신).
  - `submitStoreForApproval(store)` → `store.id` 가 빈 문자열이면 createStore, 있으면 updateStoreCoreFields 위임 (편의 메서드).
  - `approveStore(storeId, adminUid)` → role==admin 가드 + `status=approved + approvedBy + approvedAt + rejectedReason=null`
  - `rejectStore(storeId, adminUid, reason)` → role==admin 가드 + `status=rejected + approvedBy + approvedAt + rejectedReason=reason`
  - `getNearbyStores` / `getStoresByCategories` → 기존 query 결과를 client side `.where((s) => s.status == approved)` 로 필터 (T7)
  - `watchAllForAdmin` / `watchPendingStoresForAdmin` → datasource 직접 위임 (status 필터 없거나 pending 만)

> **`StoreRemoteDataSource.update` partial update 패턴**: 운영 필드만 변경하는 경우 `set(merge=true)` 또는 `update(...)` 로 운영 필드 + `updatedAt` 만 보내고 status / 승인 메타는 건드리지 않는다. 동시 편집 (admin 이 승인 처리 중 점주가 영업시간 변경) 케이스에서 race 안전.

### Presentation

#### Owner 모듈 갱신 (`presentation/owner/my_store/`)

```text
presentation/owner/my_store/
├── my_store_page.dart                  # (수정) ApprovalStatusBadge + rejected 사유 + 재제출 CTA + 운영 정보 수정 버튼 추가
├── store_form_page.dart                # (수정) 핵심 필드만 다룸. 저장은 SubmitStoreForApprovalUseCase
├── store_operation_form_page.dart      # (신규, T2) 운영 필드만 다룸. 저장은 UpdateStoreOperationFieldsUseCase. 즉시 반영
└── widgets/                            # (신규)
    ├── store_status_section.dart       # status 라벨 + 사유 + 재제출 CTA
    └── rejected_banner.dart            # rejected 매장 진입 시 상단 배너
```

> **두 폼 분리 — designer 위임**: 위는 잠정안. designer 가 한 폼 + 섹션 분리 안으로 갈아낼 수 있다. 본 spec 은 메서드 / UseCase 분리만 강제하고 UI 구성은 designer 가 결정.

`OwnerMyStorePage` 변경 사항:
1. 매장 카드 상단 또는 우측 상단에 `ApprovalStatusBadge(status)` 표시
2. status==rejected 면 카드 하단 또는 별도 섹션에 `RejectedBanner(reason, onResubmit)` — onResubmit 은 `StoreFormPage` (핵심 폼) 로 이동
3. status==pending 이면 "검토 대기 중" 안내 + 핵심 정보 수정 버튼 활성 (pending 상태에서도 수정 가능 — 보강 입력)
4. status==approved 면 라벨만 표시
5. **두 가지 수정 액션** (잠정안 — designer 결정 가능):
   - `매장 정보 수정` 버튼 → `StoreFormPage` (핵심 필드. 저장 시 status=pending 회귀)
   - `매장 운영 정보` 버튼 → `StoreOperationFormPage` (운영 필드. 저장 시 status 보존, 즉시 반영)
   - 운영 정보 수정 버튼은 status 와 무관하게 항상 활성 (pending / rejected 상태에서도 영업시간 / 사진 / 전화 / 설명 / 안내 변경 허용)

`StoreFormPage` 변경 사항 (핵심 폼):
- 다루는 필드: `name`, `address`, `lat/lng`, `mainCategory`, `subCategories`, `businessRegistrationNumber`
- 저장 버튼 동작: `SubmitStoreForApprovalUseCase` 호출 (신규 등록 또는 핵심 필드 수정)
- brandId 필드 UI 없음 (T6) — 기존 폼 그대로
- 저장 성공 후 SnackBar: "검토 대기 중으로 전환되었습니다" (status=pending 안내)

`StoreOperationFormPage` (신규, T2):
- 다루는 필드: `businessHours`, `temporaryClosed`, `closedDates`, `phoneNumber`, `imageUrls`, `interiorImages`, `description`, `notice`
- 저장 버튼 동작: `UpdateStoreOperationFieldsUseCase` 호출
- 저장 성공 후 SnackBar: "즉시 반영되었습니다" (status 무관)
- ownership 검증 / 권한 가드는 RepositoryImpl 단계 (T4) 와 동일

#### Admin 모듈 확장 (`presentation/admin/approval/`)

```text
presentation/admin/approval/
├── admin_approval_queue_page.dart                     # (수정) 세그먼트 3탭화 (브랜드/마스터 메뉴/매장)
├── admin_brand_approval_detail_page.dart              # (sub-phase 1 그대로)
├── admin_master_menu_approval_detail_page.dart       # (sub-phase 1 그대로)
├── admin_pending_stores_page.dart                    # (신규) 세그먼트 컨테이너 — 매장 세그먼트 본문
├── admin_store_approval_detail_page.dart             # (신규) 매장 상세 + 승인/반려
└── widgets/
    └── store_scope_badge.dart                         # (신규) "개인 매장" / "브랜드 매장" 뱃지 (T9, sub-phase 3 에서 확장)
```

```text
presentation/admin/providers/
├── admin_di_providers.dart                            # (수정) StoreRepository / UseCase 추가 등록
├── admin_brand_approval_providers.dart                # (sub-phase 1 그대로)
├── admin_master_menu_approval_providers.dart          # (sub-phase 1 그대로)
└── admin_store_approval_providers.dart                # (신규) WatchPendingStoresForAdminUseCase / Approve / Reject 노출
```

`AdminApprovalQueuePage` 변경:
- 세그먼트 컨트롤 enum 에 `stores` 추가 (기존 `brands` / `masterMenus` + 신규 `stores`)
- `stores` 세그먼트 선택 시 `AdminPendingStoresPage` 가 본문에 노출
- 세그먼트 라벨에 pending count 뱃지 (sub-phase 1 이 이미 BadgedSegmentControl 도입했다면 그대로 매장 세그먼트도 카운트 노출)

`AdminPendingStoresPage`:
- `WatchPendingStoresForAdminUseCase` 의 stream 을 `ref.watch`
- `ListView.builder` 로 매장 카드 노출 — 카드 구성: 매장 이미지 / 이름 / `StoreScopeBadge('개인 매장')` / `ApprovalStatusBadge(pending)` / 점주 이름 / 제출 시점 / 수정 대기 라벨 (`approvedAt != null` 시)
- 카드 탭 → `AdminStoreApprovalDetailPage` 로 이동 (`Navigator.push`)
- 빈 상태: "대기 중인 매장이 없습니다"
- 로딩 / 에러 상태는 sub-phase 1 패턴

`AdminStoreApprovalDetailPage`:
- `GetStoreByIdUseCase` 로 매장 상세 fetch + watch
- 표시: 매장 정보 (이미지 / 이름 / 주소 / 영업시간 / 점주 이름 / 점주 연락처 / 제출 시점)
- `ApprovalActionsBar` (sub-phase 1 산출) 재사용 — 승인 / 반려 버튼
  - 승인 → `ApproveStoreUseCase` 호출 → 성공 시 SnackBar + Pop
  - 반려 → `RejectReasonDialog` (sub-phase 1) → 사유 입력 → `RejectStoreUseCase` → SnackBar + Pop

#### 라우팅

- `Navigator.push(MaterialPageRoute)` 패턴 유지 (router.dart 변경 없음)
- `RoleRouter` 변경 없음 (sub-phase 1 가 admin 분기 추가 완료)

---

## 데이터 흐름 (핵심 시나리오 5개)

### 1. 점주 매장 등록 (status=pending 자동)

```text
StoreFormPage(점주, 신규 등록)
  → SubmitStoreForApprovalUseCase
  → StoreRepositoryImpl.submitStoreForApproval (id 빈 문자열 → createStore 위임)
  → StoreRepositoryImpl.createStore:
     - brandId=null, status=pending, submittedBy=uid, submittedAt=now 강제
     - imageUrl: StorageDataSource.upload (기존 경로)
     - StoreRemoteDataSource.create
  → SnackBar "검토 대기 중으로 전환되었습니다"
  → OwnerMyStorePage 자동 갱신 (watchByOwner stream) — pending 라벨 노출
─── (admin) AdminApprovalQueuePage [매장 세그먼트]
  → WatchPendingStoresForAdminUseCase
  → AdminPendingStoresPage 카드 등장
  → 카드 탭 → AdminStoreApprovalDetailPage
  → ApprovalActionsBar [승인]
  → ApproveStoreUseCase → status=approved + approvedBy/At
  → SnackBar + Pop
─── (customer) 매장 검색 → status='approved' 통과 → 노출
```

### 2. 점주 매장 핵심 필드 수정 (approved → pending 회귀)

```text
OwnerMyStorePage (status=approved)
  → "매장 정보 수정" 버튼 → StoreFormPage(핵심 폼, 수정 모드)
  → 핵심 필드 (예: name, address) 변경 후 저장
  → SubmitStoreForApprovalUseCase (id 있음 → updateStoreCoreFields 위임)
  → StoreRepositoryImpl.updateStoreCoreFields:
     - ownership 검증 (T4)
     - 기존 status=approved → 새 status=pending + submittedBy=uid + submittedAt=now 갱신
     - approvedBy/At 보존 (수정 대기 식별, T2)
  → SnackBar "재검토 대기 중으로 전환되었습니다"
─── (admin) AdminPendingStoresPage 카드 — `approvedAt != null` 이면 "수정 대기" 라벨
  → AdminStoreApprovalDetailPage → 승인 → status=approved + approvedBy/At 갱신
─── (customer) 검색 노출 그대로 유지 (단 customer 입장에서는 pending 동안 잠깐 미노출 발생)
```

> **트레이드오프**: 매장 핵심 필드 수정 → pending 회귀 동안 customer 검색에서 일시적으로 사라짐. 운영상 admin 승인이 빠르다는 가정. 추후 "수정 사항만 검토 + 매장 자체는 노출 유지" 정책으로 전환 가능 (별도 task).

### 2-1. 점주 매장 운영 필드 수정 (즉시 반영, T2 / 결정 J)

```text
OwnerMyStorePage (status=approved 또는 pending 또는 rejected)
  → "매장 운영 정보" 버튼 → StoreOperationFormPage (운영 폼)
  → 운영 필드 (예: businessHours, phoneNumber, imageUrls, description) 변경 후 저장
  → UpdateStoreOperationFieldsUseCase
  → StoreRepositoryImpl.updateStoreOperationFields:
     - ownership 검증 (T4)
     - 핵심 필드 / status / 승인 메타 모두 무변경
     - 운영 필드만 partial update + updatedAt=now
  → SnackBar "즉시 반영되었습니다"
─── (admin) 승인 큐 진입 X. AdminStoreApprovalDetailPage 도 무영향 (단 detail 화면이 stream 으로 watch 중이면 운영 정보 갱신은 즉시 반영되어 보임)
─── (customer) status=='approved' 매장이라면 검색 결과 그대로 유지하면서 영업시간/사진/전화/설명/안내 즉시 갱신
```

> **혼합 케이스**: 한 폼/세션에서 핵심 + 운영 동시 변경 — 잠정안에서는 두 폼 분리이므로 세션 내 동시 변경 케이스 없음. 만약 designer 가 단일 폼으로 갈면 핵심 필드 변경 감지 시 `updateStoreCoreFields` 우선 호출 (status=pending 회귀) + UI 안내.

### 3. admin 반려 → 점주 재제출

```text
AdminStoreApprovalDetailPage [반려]
  → RejectReasonDialog → 사유 입력
  → RejectStoreUseCase → status=rejected + approvedBy + approvedAt + rejectedReason
─── OwnerMyStorePage (status=rejected)
  → ApprovalStatusBadge(rejected) + RejectedBanner(reason)
  → "재제출" CTA → StoreFormPage(수정 모드)
  → 점주가 수정 후 저장
  → SubmitStoreForApprovalUseCase → updateStore
  → StoreRepositoryImpl.updateStore:
     - ownership 검증
     - 기존 status=rejected → status=pending + submittedBy + submittedAt 갱신
     - approvedBy=null + approvedAt=null + rejectedReason=null 모두 클리어 (T3)
  → admin 승인 큐에 재등장 ("최초 등록" 라벨, approvedAt==null)
```

### 4. 시드 매장 호환성 (legacy doc, status 필드 없음)

```text
phase1_seed_store_001 (Firestore doc, status 필드 없음, brandId 필드 없음)
  → StoreModel.fromFirestore:
     - status 누락 → EntityApprovalStatus.approved (T1, fromString fallback)
     - brandId 누락 → null
  → StoreEntity (status=approved, brandId=null)
─── customer 매장 검색 → status='approved' 필터 통과 → 노출
─── owner OwnerMyStorePage → ApprovalStatusBadge(approved) 노출 — 시각적 변화만
```

### 5. customer 검색 status 필터 회귀 검증

```text
customer 진입 (StoreSearchPage / 추천 / 지도)
  → StoreRepository.getNearbyStores / getStoresByCategories
  → StoreRepositoryImpl: datasource 결과 client filter (s) => s.status == approved
  → pending / rejected 매장 제외, approved 만 반환
─── Phase 1a 시드 매장 (status=approved fallback) → 노출
─── 점주 신규 등록 매장 (status=pending) → 미노출
─── admin 승인 후 (status=approved) → 노출
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 권한 미달 (owner 가 본인 외 매장 수정 시도) | `PermissionDeniedException` (T4) → 스낵바 "권한이 없습니다" |
| 권한 미달 (customer / brand role 이 매장 폼 진입 시도) | `RoleRouter` 분기에서 차단 (StoreFormPage 는 OwnerScaffold 안에서만 노출) |
| 권한 미달 (owner 가 approve/reject UseCase 직접 호출 시도) | role==admin 가드 → `PermissionDeniedException` |
| 동시 편집 (admin 이 승인하는 동안 owner 가 수정) | 마지막 write 우선. updatedAt 비교 X. 다음 stream tick 으로 자동 갱신 (sub-phase 1 패턴 동일) |
| `getById` 시 매장 doc 없음 | `null` 반환 → admin 상세 화면에서 "매장을 찾을 수 없습니다" 위젯 |
| 이미지 업로드 실패 | sub-phase 1 패턴 — 매장 저장 자체를 막고 에러 스낵바 |
| Firestore 읽기 실패 (네트워크) | `AsyncError` → 에러 위젯 + 재시도 (Riverpod refresh) |
| `EntityApprovalStatus.fromString` 실패 (예상 못한 값) | `approved` fallback (legacy 안전) — 에러 throw X |
| 인덱스 누락 (status + submittedAt 정렬 query) | 콘솔 안내 로그 + 에러 위젯 (인덱스 자동 생성 또는 수동은 별도 task) |
| 인증 만료 | 기존 auth flow (재로그인) |

---

## 작업 분배 판단

### designer 호출 — **권장**

신규 화면이 적당히 있음 (admin 매장 승인 큐 본문 / 매장 상세 + owner status 라벨 / rejected 배너 / 재제출 CTA). sub-phase 1 의 디자인 토큰 (`ApprovalStatusBadge` 색상, `ApprovalActionsBar`, `RejectReasonDialog`) 을 그대로 재사용하므로 디자인 작업량은 sub-phase 1 의 절반 이하.

- 디자인 산출물: `docs/tasks/admin_menu_management/2_store_registration_approval/design.md`
- 전달할 사항:
  - `OwnerMyStorePage` status 라벨 위치 / rejected 배너 / 재제출 CTA
  - `AdminPendingStoresPage` 매장 카드 디자인 (이미지 + 이름 + 점주 + 제출 시점 + status 뱃지 + scope 뱃지)
  - `AdminStoreApprovalDetailPage` 정보 영역 + ApprovalActionsBar 배치
  - `StoreScopeBadge('개인 매장')` 색상 토큰 (브랜드 매장 뱃지는 sub-phase 3)
  - 빈 상태 / 로딩 / 에러 UI (sub-phase 1 패턴 일관)

### developer 호출

designer 완료 후. 의존 순서: Domain → Data → Presentation.

- 구현 항목: 위 레이어 설계의 모든 파일
- 재사용:
  - sub-phase 1 의 `EntityApprovalStatus`, `ApprovalStatusBadge`, `RejectReasonDialog`, `ApprovalActionsBar`, `AdminScaffold`
  - 기존 `StorageDataSource` (이미지 업로드 — 경로 변경 없음)
  - 기존 freezed / Riverpod / `Navigator.push(MaterialPageRoute)` 패턴
- 주의할 레이어 규칙:
  - `StoreRepositoryImpl` 의 client side filter (T7) — Firebase SDK 직접 사용은 data 레이어에서만
  - `StoreEntity` 수정 시 기존 사용처 (Phase 1a/1b/1c, Phase 2, owner_store_registration) 무영향 확인 — DTO default 값 (status=approved, brandId=null) 으로 흡수
  - `MenuItemEntity` 와 달리 `StoreEntity.status` 는 nullable 아님 (default 값으로 항상 채움). entity 사용처에서 `?` 분기 추가 필요 없음
- `pubspec.yaml`: 추가 패키지 없음

### tester 호출

developer 완료 후. `test_report.md`. **회귀 검증을 강조** — Phase 1a/1b/1c, Phase 2, sub-phase 1 모두 무영향 확인 필수.

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능 (owner)
- [ ] 점주가 매장 등록 → status=pending, submittedBy=uid, submittedAt 자동 세팅 확인
- [ ] OwnerMyStorePage 의 ApprovalStatusBadge — pending/approved/rejected 색상 정확
- [ ] rejected 상태에서 RejectedBanner + reason 노출 + "재제출" CTA 동작
- [ ] approved 상태에서 매장 핵심 필드(name/address/카테고리) 수정 → pending 회귀, approvedBy/At 보존 (T2)
- [ ] approved 상태에서 매장 운영 필드(영업시간/전화/사진/설명/안내) 수정 → status=approved 보존, 즉시 반영 (T2 / 결정 J)
- [ ] pending 상태에서 운영 필드 수정 → status=pending 보존, 운영 정보 갱신
- [ ] rejected 상태에서 운영 필드 수정 → status=rejected 보존 (재제출은 핵심 폼에서만)
- [ ] rejected 상태에서 매장 핵심 필드 수정 후 재제출 → pending 회귀, approvedBy/At/rejectedReason 모두 null (T3)
- [ ] customer 검색 — approved 매장의 운영 필드 변경 시 검색 노출 유지하면서 영업시간/사진 즉시 갱신
- [ ] 점주가 본인 외 매장 수정 시도 (직접 firestore manipulation 시뮬레이션) → 차단 (T4)

### 신규 기능 (admin)
- [ ] AdminScaffold 진입 (`role='admin'`) — 승인 큐 탭의 세그먼트 3개 (브랜드 / 마스터 메뉴 / 매장) 노출 (T5)
- [ ] AdminPendingStoresPage — pending 매장 리스트 노출, "개인 매장" 뱃지 표시 (T9)
- [ ] AdminPendingStoresPage — `approvedAt != null` 매장에 "수정 대기" 라벨 (T2)
- [ ] AdminStoreApprovalDetailPage — 매장 정보 정확 표시
- [ ] 승인 → status=approved + approvedBy/At 세팅 + 승인 큐에서 사라짐
- [ ] 반려 → RejectReasonDialog → 사유 입력 → status=rejected + reason 표시
- [ ] 사유 미입력 시 반려 버튼 비활성 (sub-phase 1 패턴)
- [ ] 빈 큐 상태 — "대기 중인 매장이 없습니다"

### 신규 기능 (customer status 필터)
- [ ] 점주 신규 등록 매장 (status=pending) — customer 검색에서 미노출
- [ ] admin 승인 후 (status=approved) — customer 검색에서 노출
- [ ] admin 반려 (status=rejected) — customer 검색에서 미노출

### 회귀 (Phase 1a/1b/1c, Phase 2 무영향)
- [ ] 시드 매장 (status 필드 없음) — fallback 으로 approved 처리 → customer 검색 노출 (T1)
- [ ] 시드 매장 (brandId 필드 없음) — fallback 으로 null 처리, 점주 매장과 동일 동작
- [ ] customer `StoreSearchPage` / `StoreMenuPage` / `MenuItemDetailPage` / 추천 / 지도 / 즐겨찾기 모두 동작 그대로
- [ ] Phase 2 추천 / Phase 1c 즐겨찾기 호출부 변경 없음 + 동작 그대로
- [ ] owner_store_registration phase 의 매장 등록 흐름 동작 그대로 (단 status=pending 자동 박힘만 추가)
- [ ] sub-phase 1 의 brand / 마스터 메뉴 승인 큐 동작 그대로

### 회귀 (Repository 시그니처)
- [ ] `StoreRepository.getNearbyStores` / `getStoresByCategories` 시그니처 불변 + 호출부 무수정
- [ ] `StoreRepository.watchByOwner` 시그니처 불변
- [ ] `StoreRepository.createStore` / `updateStore` / `deleteStore` 시그니처 불변

### 코드 품질
- [ ] `flutter analyze` 0 issue
- [ ] `dart run build_runner build --delete-conflicting-outputs` 성공 (StoreEntity freezed 재생성)
- [ ] 색상 토큰 — `AppColors` 만 사용, hardcoded `Color(0x...)` 0건

---

## 완료 기준

- [ ] `spec.md` 본 문서 (현재) 확정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] 점주 매장 등록 → admin 승인 → customer 노출 end-to-end 동작
- [ ] 점주 매장 수정 → pending 회귀 → admin 재승인 동작 (T2)
- [ ] admin 반려 → 사유 → 점주 재제출 (T3) 동작
- [ ] 시드 매장 fallback (T1) — customer 노출 그대로
- [ ] customer / Phase 1a/1b/1c / Phase 2 / sub-phase 1 회귀 0
- [ ] `flutter analyze` 0 issue
