# Implementation — admin_menu_management / 2_store_registration_approval

## 개요

- 구현 목적: 점주의 개인 매장 등록 흐름에 admin 승인 게이트를 추가하고, admin 매장 승인 큐를 sub-phase 1 의 admin 모듈 위에 얹는다. customer 측 매장 검색은 Repository 내부 필터(`status == approved`)만 추가하여 호출부 변경을 0으로 유지한다.
- 기준 문서:
  - `docs/tasks/admin_menu_management/2_store_registration_approval/spec.md`
  - `docs/tasks/admin_menu_management/2_store_registration_approval/design/` (owner_module.md, admin_module.md, common_components.md)
- 핵심 설계 원칙: **결정 J — 핵심/운영 필드 분리**. 핵심 필드(name/address/lat·lng/menuCategories/businessRegistrationNumber) 수정 시 `status=pending` 회귀, 운영 필드(businessHours/temporaryClosed/closedDates/phone/imageUrls/description/notice) 수정 시 status/승인 메타 보존 즉시 반영.

---

## 구현 파일 목록

### 신규 파일

| 파일 | 레이어 | 설명 |
|---|---|---|
| `lib/domain/usecases/submit_store_for_approval_use_case.dart` | Domain | 점주 등록/핵심 수정/재제출 통합 UseCase |
| `lib/domain/usecases/update_store_core_fields_use_case.dart` | Domain | 핵심 필드 수정 UseCase (결정 J, T2) |
| `lib/domain/usecases/update_store_operation_fields_use_case.dart` | Domain | 운영 필드 수정 UseCase (결정 J, T2) |
| `lib/domain/usecases/approve_store_use_case.dart` | Domain | admin 매장 승인 UseCase |
| `lib/domain/usecases/reject_store_use_case.dart` | Domain | admin 매장 반려 UseCase |
| `lib/domain/usecases/watch_pending_stores_for_admin_use_case.dart` | Domain | admin 승인 큐 스트림 UseCase |
| `lib/presentation/owner/my_store/store_core_form_page.dart` | Presentation | 점주 핵심 필드 폼 (등록/수정/재제출) |
| `lib/presentation/owner/my_store/store_operation_form_page.dart` | Presentation | 점주 운영 필드 폼 (즉시 반영) |
| `lib/presentation/admin/widgets/store_scope_badge.dart` | Presentation | "개인 매장"/"브랜드 매장" scope 뱃지 (T9) |
| `lib/domain/usecases/watch_all_stores_for_admin_use_case.dart` | Domain | admin 전체 매장 실시간 감시 UseCase (2026-05-01 추가) |
| `lib/presentation/admin/providers/admin_store_approval_providers.dart` | Presentation | admin 매장 승인 UseCase/Stream Provider 등록 (2026-05-01 추가) |
| `lib/presentation/admin/approval/admin_pending_stores_page.dart` | Presentation | admin 매장 승인 큐 리스트 화면 (2026-05-01 추가) |
| `lib/presentation/admin/approval/admin_store_approval_detail_page.dart` | Presentation | 매장 승인 상세 + 승인/반려 액션 화면 (2026-05-01 추가) |

### 수정 파일

| 파일 | 레이어 | 핵심 변경 |
|---|---|---|
| `lib/domain/entities/store_entity.dart` | Domain | 신규 필드 11개 추가 (brandId / status / submittedBy / submittedAt / approvedBy / approvedAt / rejectedReason / businessRegistrationNumber / temporaryClosed / closedDates / imageUrls / notice / updatedAt) |
| `lib/domain/repositories/store_repository.dart` | Domain | 메서드 7개 추가 (watchAllForAdmin / watchPendingStoresForAdmin / approveStore / rejectStore / submitStoreForApproval / updateStoreCoreFields / updateStoreOperationFields), 기존 createStore / updateStore `@Deprecated` |
| `lib/data/models/store_model.dart` | Data | 신규 필드 직렬화 3종 추가 (fromFirestore / fromEntity / toEntity). 핵심/운영/승인 update 맵 메서드 추가 |
| `lib/data/datasources/remote/store_remote_data_source.dart` | Data | 메서드 6개 추가 (streamAll / streamPending / getById / updateCoreFields / updateOperationFields / updateApprovalFields) |
| `lib/data/repositories/store_repository_impl.dart` | Data | ownership/role 검증 콜백 주입, T7 `_filterApproved`, 결정 J 분리 메서드, admin 가드 |
| `lib/presentation/owner/my_store/my_store_page.dart` | Presentation | ApprovalStatusBadge 추가, `_RejectedBanner` + `_StoreStatusSection` 인라인 구현, 두 수정 버튼 분리 |
| `lib/presentation/admin/approval/admin_approval_queue_page.dart` | Presentation | 3탭 확장 완료 — "매장" 탭 추가, IndexedStack에 AdminPendingStoresPage 추가 (2026-05-01) |
| `lib/presentation/owner/providers/owner_providers.dart` | Presentation | 신규 UseCase/Repository Provider 등록, pendingStoresProvider 추가 |

### 폐기 (@Deprecated, 코드 유지)

| 파일 | 폐기 항목 | 대체 |
|---|---|---|
| `lib/domain/repositories/store_repository.dart` | `createStore` | `submitStoreForApproval` |
| `lib/domain/repositories/store_repository.dart` | `updateStore` | `updateStoreCoreFields` / `updateStoreOperationFields` |
| `lib/data/datasources/remote/store_remote_data_source.dart` | `update(StoreModel)` | `updateCoreFields` / `updateOperationFields` |
| `lib/presentation/owner/providers/owner_providers.dart` | `registerStoreUseCaseProvider` | `submitStoreForApprovalUseCaseProvider` |
| `lib/presentation/owner/providers/owner_providers.dart` | `updateStoreUseCaseProvider` | `updateStoreCoreFieldsUseCaseProvider` |

---

## 주요 결정사항 (T1~T10)

### T1. 시드 매장 / legacy doc 의 status 처리 — model fallback 채택

`StoreModel.fromFirestore` 에서 `status` 필드 누락 시 `EntityApprovalStatus.fromString(null)` 을 호출하며, `fromString` 은 null/unknown 값을 `approved` 로 fallback 처리한다.

```dart
// StoreModel.fromFirestore 내부
status: EntityApprovalStatus.fromString(data['status'] as String?),
```

legacy doc(`phase1_seed_store_001` 등) 은 status 필드가 없더라도 `approved` 로 읽혀 customer 검색에 정상 노출된다. 마이그레이션 스크립트 없이 code-only 호환성 확보.

### T2. status 회귀 정책 — 결정 J 메서드 분리 채택

핵심 필드 수정(`updateStoreCoreFields`)은 status=pending 회귀. 운영 필드 수정(`updateStoreOperationFields`)은 status 보존 즉시 반영.

```
[신규 등록]
  id='' → submitStoreForApproval → create (status=pending, brandId=null 강제)

[핵심 필드 수정]
  id 있음 → submitStoreForApproval → updateStoreCoreFields 위임
           → status=pending + submittedBy/At 갱신 + approvedBy/At 보존

[운영 필드 수정]
  updateStoreOperationFields 직접 호출
           → status/승인 메타 불변, 운영 필드만 partial update
```

admin 승인 큐에서 `approvedAt != null && status == pending` 이면 "수정 대기" 라벨 노출 (데이터 플래그 없음, UI 연산 — sub-phase 1 S3 패턴 동일).

### T3. rejected → 재제출 시 메타 클리어

`updateStoreCoreFields` 에서 현재 status 가 rejected 인지 확인하여 `isResubmit` 플래그를 `StoreModel.toFirestoreForCoreUpdate`에 전달한다.

```dart
// store_repository_impl.dart
final isResubmit = store.status == EntityApprovalStatus.rejected;
await _dataSource.updateCoreFields(
  store.id,
  model.toFirestoreForCoreUpdate(isResubmit: isResubmit),
);

// store_model.dart — toFirestoreForCoreUpdate
if (isResubmit) ...{
  'approvedBy': null,
  'approvedAt': null,
  'rejectedReason': null,
}
```

재제출 후 `approvedAt == null` 이 되므로 admin 큐에서 "수정 대기" 가 아닌 "최초 등록" 으로 식별된다.

### T4. ownership 검증 — UID + role 분기

`StoreRepositoryImpl` 생성자에 `currentUidGetter` / `currentRoleGetter` 콜백을 주입한다.

```dart
// store_repository_impl.dart
void _assertOwnership(String ownerId) {
  final role = _currentRoleGetter();
  if (role == 'admin') return;           // admin 은 모든 매장 write 가능
  final uid = _currentUidGetter();
  if (uid == null || uid.isEmpty || uid != ownerId) {
    throw StateError('권한이 없습니다. 본인 매장만 수정할 수 있어요.');
  }
}

void _assertAdmin() {
  final role = _currentRoleGetter();
  if (role != 'admin') {
    throw StateError('관리자만 수행할 수 있는 작업입니다.');
  }
}
```

Provider 주입부 (`owner_providers.dart`):
```dart
return StoreRepositoryImpl(
  ref.watch(storeRemoteDataSourceProvider),
  currentUidGetter: () => user?.uid,
  currentRoleGetter: () => user?.role.asString,
);
```

### T5. AdminApprovalQueuePage 세그먼트 3탭 확장

`admin_approval_queue_page.dart` 를 **브랜드 / 마스터 메뉴 / 매장 3탭** 구조로 확장 완료 (2026-05-01).

- `_SegTab` Row 에 `label: '매장'`, `_segIndex == 2` 탭 추가
- `IndexedStack` children 에 `AdminPendingStoresPage()` 추가
- `AdminPendingStoresPage` — `adminPendingStoresProvider` watch, `_StoreQueueTile` → `AdminStoreApprovalDetailPage` push
- `AdminStoreApprovalDetailPage` — `watchStoreByIdForAdminProvider(storeId)` 실시간 stream, `ApprovalActionsBar` pending 조건부 노출, `adminApproveStoreUseCaseProvider` / `adminRejectStoreUseCaseProvider` 호출

Provider 구성: `admin_store_approval_providers.dart` 신규 생성. `storeRepositoryProvider` (`owner_providers.dart`) 를 공유하여 별도 repository 인스턴스 없이 재사용.

### T6. 점주 폼 brandId 자동 null 강제

`StoreCoreFormPage._submit` 에서 entity 를 조립할 때 `brandId: e?.brandId` 로 기존 값을 이어받지만, `submitStoreForApproval` 의 신규 등록 분기에서 `brandId: null` 을 강제한다.

```dart
// store_repository_impl.dart — submitStoreForApproval
if (store.id.isEmpty) {
  final model = StoreModel.fromEntity(
    store.copyWith(
      brandId: null,          // 점주 등록: 항상 null 강제
      status: EntityApprovalStatus.pending,
      submittedBy: uid,
      submittedAt: DateTime.now(),
    ),
  );
  await _dataSource.create(model);
}
```

폼 UI 에 brandId 입력 필드 없음 (T6).

### T7. customer 측 status 필터 — client side filter

`getNearbyStores` / `getStoresByCategories` 양쪽에 `_filterApproved(models)` 를 적용한다. Firestore query level `where('status', ...)` 가 아닌 client side 이므로 missing status legacy doc 도 `fromFirestore` 단계에서 `approved` fallback 처리 후 필터를 통과한다.

```dart
// store_repository_impl.dart
List<StoreModel> _filterApproved(List<StoreModel> models) {
  return models
      .where((m) => m.status == EntityApprovalStatus.approved)
      .toList(growable: false);
}

@override
Future<List<StoreEntity>> getNearbyStores({...}) async {
  final models = await _dataSource.fetchAll(limit: 100);
  final approved = _filterApproved(models);   // T7
  ...
}
```

### T8. 반려 사유 글자 수 제한 없음

`RejectReasonDialog` (sub-phase 1 산출) 를 그대로 재사용. client side 글자 수 제한 없음. 서버측 제한은 별도 task `firestore_rules`.

### T9. StoreScopeBadge — "개인 매장" 뱃지

`lib/presentation/admin/widgets/store_scope_badge.dart` 에 신규 구현. `AppColors.info` 톤.

```dart
class StoreScopeBadge extends StatelessWidget {
  final String label;
  const StoreScopeBadge({super.key, required this.label});
  const StoreScopeBadge.personal({super.key}) : label = '개인 매장';
  ...
}
```

본 sub-phase 에서는 항상 `StoreScopeBadge.personal()` 사용. sub-phase 3 에서 브랜드 매장 뱃지 확장 예정.

### T10. owner 측 status 라벨 노출

`my_store_page.dart` 의 `_StoreHeaderCard` 에서 `ApprovalStatusBadge` 를 표시하고, `_StoreDetailView` 에서 status 분기를 처리한다.

- `status == rejected` → `_RejectedBanner` 노출 (반려 사유 + "재제출하기" CTA)
- `status == pending` → `_StoreStatusSection` 노출 ("검토 요청이 접수되었어요" 안내)
- `isRevision = approvedAt != null && status == pending` → `ApprovalStatusBadge(isRevision: true)` 로 "수정 대기" 식별

두 수정 액션 버튼:
- `매장 정보 수정` → `StoreCoreFormPage(existing: store)` (핵심 폼, 저장 시 pending 회귀)
- `운영 정보 수정` → `StoreOperationFormPage(existing: store)` (운영 폼, 즉시 반영)

---

## 결정 J 적용 — 핵심/운영 필드 분리

sub-phase 1 의 brand/master menu 엔티티에 적용된 패턴을 StoreEntity 에 그대로 적용.

| 필드 | 분류 | 수정 진입점 | status 변화 |
|---|---|---|---|
| name | 핵심 | StoreCoreFormPage → submitStoreForApprovalUseCase | pending 회귀 |
| address / lat·lng | 핵심 | StoreCoreFormPage | pending 회귀 |
| menuCategories | 핵심 | StoreCoreFormPage | pending 회귀 |
| businessRegistrationNumber | 핵심 | StoreCoreFormPage | pending 회귀 |
| phone | 운영 | StoreOperationFormPage → updateStoreOperationFieldsUseCase | 보존 |
| businessHours | 운영 | StoreOperationFormPage | 보존 |
| temporaryClosed | 운영 | StoreOperationFormPage | 보존 |
| closedDates | 운영 | StoreOperationFormPage | 보존 |
| imageUrls / imageUrl | 운영 | StoreOperationFormPage | 보존 |
| description | 운영 | StoreOperationFormPage | 보존 |
| notice | 운영 | StoreOperationFormPage | 보존 |

폼 분리 방식: 두 폼 완전 분리 (`StoreCoreFormPage` / `StoreOperationFormPage`). 한 폼 + 섹션 분리 안은 채택하지 않음 (designer 결정 — 두 폼 분리 권장).

---

## Firestore 컬렉션 doc 형태 예시

`stores/{storeId}` — 신규 필드 직렬화 예시 (Phase 1a 기존 필드 생략):

```json
{
  "name": "커피 원스",
  "address": "서울시 강남구 테헤란로 1",
  "location": "GeoPoint(37.5, 127.0)",
  "menuCategories": ["커피", "디저트"],
  "ownerId": "uid_owner_abc",

  "brandId": null,
  "status": "pending",
  "submittedBy": "uid_owner_abc",
  "submittedAt": "Timestamp(2026-04-30T10:00:00)",
  "approvedBy": null,
  "approvedAt": null,
  "rejectedReason": null,
  "businessRegistrationNumber": "123-45-67890",

  "temporaryClosed": false,
  "closedDates": [],
  "imageUrls": ["https://..."],
  "imageUrl": "https://...",
  "notice": null,
  "updatedAt": "Timestamp(2026-04-30T10:00:00)"
}
```

승인 후 doc:
```json
{
  "status": "approved",
  "approvedBy": "uid_admin_xyz",
  "approvedAt": "Timestamp(2026-04-30T11:00:00)",
  "rejectedReason": null,
  "updatedAt": "Timestamp(2026-04-30T11:00:00)"
}
```

반려 후 doc:
```json
{
  "status": "rejected",
  "approvedBy": "uid_admin_xyz",
  "approvedAt": "Timestamp(2026-04-30T11:05:00)",
  "rejectedReason": "사업자등록번호가 확인되지 않습니다.",
  "updatedAt": "Timestamp(2026-04-30T11:05:00)"
}
```

---

## status 전이 규칙

```
[점주 신규 등록]
  draft(미저장) → submitStoreForApproval (id='') → pending

[점주 핵심 필드 수정 - approved → pending]
  approved → updateStoreCoreFields → pending
  (approvedBy/At 보존 → admin 큐 "수정 대기" 식별)

[admin 승인]
  pending → approveStore → approved
  (approvedBy/At 기록, rejectedReason=null)

[admin 반려]
  pending → rejectStore(reason) → rejected
  (approvedBy/At 기록, rejectedReason 저장)

[점주 재제출]
  rejected → updateStoreCoreFields (isResubmit=true) → pending
  (approvedBy=null, approvedAt=null, rejectedReason=null 클리어)
  (admin 큐에서 "수정 대기" 아닌 "최초 등록" 으로 식별)

[운영 필드 수정 — status 불변]
  any status → updateStoreOperationFields → 동일 status 유지
  (customer 노출 상태 그대로 유지하면서 운영 정보만 갱신)
```

"수정 대기" 판별 공식: `approvedAt != null && status == pending`

---

## customer 측 진입점 status 필터

`StoreRepositoryImpl._filterApproved` 가 모든 customer 진입점에 적용된다.

```dart
// lib/data/repositories/store_repository_impl.dart

List<StoreModel> _filterApproved(List<StoreModel> models) {
  return models
      .where((m) => m.status == EntityApprovalStatus.approved)
      .toList(growable: false);
}
```

`getNearbyStores` 와 `getStoresByCategories` 양쪽에서 `fetchAll` 결과에 적용한다. Firestore query 단계가 아닌 client side filter 이므로:
- `status` 필드가 없는 legacy doc → `fromFirestore` 에서 `approved` fallback → 필터 통과 (노출)
- `status='pending'` 또는 `status='rejected'` → 필터 차단 (미노출)
- 호출부(`getNearbyStores`, `getStoresByCategories`) 시그니처 불변 — Phase 1a/1b/1c/Phase 2 호출부 수정 없음

---

## 테스트 포인트

### owner 신규 기능

- [ ] 점주 매장 등록 → Firestore `stores/{id}` 에 `status='pending'`, `brandId=null`, `submittedBy=uid`, `submittedAt` 세팅 확인
- [ ] `OwnerMyStorePage` 의 `ApprovalStatusBadge` — pending(노란색)/approved(초록색)/rejected(빨간색) 색상 확인
- [ ] `status==rejected` 상태에서 `_RejectedBanner` + 반려 사유 노출 + "재제출하기" CTA 동작 확인
- [ ] "재제출하기" 탭 → `StoreCoreFormPage(isResubmit: true)` 진입, 저장 후 `status=pending` 회귀 + `approvedBy/At/rejectedReason` 모두 null 확인 (T3)
- [ ] `status==approved` 상태에서 "매장 정보 수정" → 핵심 필드 변경 저장 → `status=pending` 회귀, `approvedBy/At` 보존 확인 (T2)
- [ ] `status==approved` 상태에서 "운영 정보 수정" → 운영 필드 변경 저장 → `status=approved` 보존, 즉시 반영 확인 (T2 / 결정 J)
- [ ] `status==pending` 상태에서 "운영 정보 수정" → `status=pending` 보존, 운영 정보 갱신 확인
- [ ] `status==rejected` 상태에서 "운영 정보 수정" → `status=rejected` 보존 확인
- [ ] `_StoreStatusSection` — pending 상태에서 "검토 요청이 접수되었어요" 안내 노출 확인
- [ ] 본인 외 매장 수정 시도 → `StateError('권한이 없습니다...')` throw 확인 (T4)

### admin 신규 기능

- [ ] `admin` role 계정 로그인 → `AdminApprovalQueuePage` 진입 확인
- [ ] 매장 탭 세그먼트 노출 확인 (현재 미완료 — T5 미구현, 후술)
- [ ] `pendingStoresProvider` 스트림 — `status='pending'` 매장 목록 실시간 반영 확인
- [ ] `approveStoreUseCaseProvider` 호출 → `status='approved'`, `approvedBy/At` 기록 확인
- [ ] `rejectStoreUseCaseProvider(reason)` 호출 → `status='rejected'`, `rejectedReason` 저장 확인
- [ ] `StoreScopeBadge.personal()` 렌더링 — "개인 매장" 라벨, AppColors.info 색상 확인 (T9)
- [ ] admin 이 아닌 role 에서 `approveStore` / `rejectStore` 호출 → `StateError` throw 확인 (T4)

### customer status 필터

- [ ] 점주 신규 등록 매장(`status=pending`) — customer 매장 검색에서 미노출 확인
- [ ] admin 승인 후(`status=approved`) — customer 검색에서 노출 확인
- [ ] admin 반려(`status=rejected`) — customer 검색에서 미노출 확인

### 회귀 검증

- [ ] 시드 매장(status 필드 없음) — `fromString(null)` → `approved` fallback → customer 검색 노출 확인 (T1)
- [ ] 시드 매장(brandId 필드 없음) — `null` fallback, 점주 매장과 동일 동작 확인
- [ ] `StoreRepository.getNearbyStores` / `getStoresByCategories` 시그니처 불변, 호출부 무수정 확인
- [ ] `StoreRepository.watchByOwner` 시그니처 불변 확인
- [ ] customer `StoreSearchPage` / `StoreMenuPage` / `MenuItemDetailPage` / 추천 / 지도 / 즐겨찾기 동작 그대로 확인
- [ ] Phase 2 추천 / Phase 1c 즐겨찾기 호출부 변경 없음 + 동작 확인
- [ ] sub-phase 1 의 브랜드 / 마스터 메뉴 승인 큐 동작 그대로 확인
- [ ] `flutter analyze` 0 issue 확인

---

## 회귀 검증 (코드 확인 기반)

### Phase 1a customer 진입점

`getNearbyStores` / `getStoresByCategories` 시그니처 불변. 내부에 `_filterApproved` 추가됐으나 fallback 처리로 legacy doc 은 모두 통과한다. 호출부 (`GetNearbyStoresUseCase`, `GetStoresByCategoriesUseCase`, customer Provider) 수정 없음.

### Phase 1a owner 진입점

`watchByOwner` 시그니처 불변. `deleteStore` 시그니처 불변. 기존 `owner_store_registration` phase 의 등록 흐름은 `submitStoreForApprovalUseCase` 로 전환됐으나 provider alias (`registerStoreUseCaseProvider` → `submitStoreForApprovalUseCaseProvider` 위임) 유지로 기존 호출부 무영향.

### sub-phase 1 admin 진입점

`admin_approval_queue_page.dart` 의 `_BrandPendingList` / `_MasterMenuPendingList` 코드 무변경. `pendingBrandsProvider` / `pendingMasterMenuItemsProvider` 무영향. admin DI provider 도 기존 brand/masterMenu 경로만 사용.

### StoreEntity 필드 추가 영향

신규 필드 전체가 `@Default(...)` 또는 nullable 이므로 기존 `StoreEntity(...)` 생성 코드(시드 데이터, 테스트 픽스처 등)에서 컴파일 에러 없이 흡수된다.
- `status`: `@Default(EntityApprovalStatus.approved)` — 기존 생성 코드는 `approved` 로 처리됨
- `brandId`: nullable `String?` — 기존 코드 `null` 처리됨
- `temporaryClosed`: `@Default(false)` — 기존 코드 안전
- `closedDates`, `imageUrls`: `@Default([])` — 기존 코드 안전

---

## spec.md 대비 차이

### T5. AdminApprovalQueuePage 3탭 확장 미완료

- spec 정의: 승인 큐 세그먼트를 3탭(브랜드 / 마스터 메뉴 / 매장)으로 확장, `AdminPendingStoresPage` / `AdminStoreApprovalDetailPage` 신규 생성
- 실제 구현: `admin_approval_queue_page.dart` 는 2탭(브랜드 / 마스터 메뉴) 구조 그대로 유지. `AdminPendingStoresPage`, `AdminStoreApprovalDetailPage` 파일 미생성.
- 이유: 이전 developer 작업이 Domain/Data/Owner 화면까지 구현 후 admin 화면 구현 전 단계에서 중단된 것으로 추정됨.
- 영향 범위: owner 측 등록/수정/재제출 흐름과 customer 측 status 필터는 정상 동작. admin 이 매장을 UI 로 승인/반려할 수 없는 상태 (Firestore 콘솔 직접 조작 또는 후속 구현으로 해결 필요).

### admin 파일 구조 — 인라인 vs 별도 파일

- spec 정의: `admin_pending_stores_page.dart`, `admin_store_approval_detail_page.dart` 별도 파일
- 실제 구현: 두 파일 모두 미생성. `admin_approval_queue_page.dart` 에 인라인 구현도 없음.

---

## design.md 대비 차이

- `_RejectedBanner` 위치: spec/design 에서는 `presentation/owner/my_store/widgets/rejected_banner.dart` 별도 파일 권장. 실제 구현은 `my_store_page.dart` 내 private class `_RejectedBanner` 로 인라인 구현됨. 동일 파일 내 관련 위젯은 재사용성이 낮으므로 이 방식이 현 MVP 규모에서 적절하다.
- `_StoreStatusSection` 위치: 마찬가지로 `my_store_page.dart` 내 private class 로 인라인 구현.

---

## 미구현 / 보류 항목

### 1. admin 매장 승인 큐 UI — 해소됨 (2026-05-01)

- 이전 미완료 항목: `AdminApprovalQueuePage` 3탭 확장, `AdminPendingStoresPage`, `AdminStoreApprovalDetailPage`
- 현재 상태: 모두 구현 완료. 신규 파일 4개 생성, `admin_approval_queue_page.dart` 3탭 확장 완료, `flutter analyze` 0 issues 확인.

### 2. closedDates — 과거 날짜 정리 옵션 (d)

- spec 에서 (d) 옵션으로 제시: 표시된 휴무 날짜 중 과거 날짜 자동 제거 로직
- 현 구현: 미적용. 미래 날짜만 선택 가능하도록 `DatePicker` 의 `firstDate: DateTime.now()` 로 신규 추가를 제한하지만, 기존 저장된 과거 closedDates 는 그대로 표시됨.
- 후속 작업: `_ClosedDatesEditor` 에서 현재 날짜 이후 날짜만 렌더링하거나, `updateStoreOperationFields` 호출 시 필터링 적용 (별도 task).

### 3. WatchAllStoresForAdminUseCase — 해소됨 (2026-05-01)

- `lib/domain/usecases/watch_all_stores_for_admin_use_case.dart` 신규 생성 완료.
- `adminWatchAllStoresUseCaseProvider` (`admin_store_approval_providers.dart`) 에 Provider 등록 완료.
- `watchStoreByIdForAdminProvider` 에서 `watchAllForAdmin` stream 을 storeId 필터링으로 활용.

### 4. Firestore 인덱스 — stores 컬렉션 복합 인덱스

- `streamPending` 은 `where('status', isEqualTo: 'pending').orderBy('submittedAt', descending: true)` 복합 쿼리 사용
- Firestore 는 복합 쿼리에 복합 인덱스가 필요하며, 자동 생성 링크가 콘솔 에러 로그에 표시됨
- 인덱스 설정은 별도 task `firestore_indexes` 범위

### 5. Firestore 보안 규칙

- ownership 검증 / role 가드는 현재 client side(`StoreRepositoryImpl`) 에서만 수행
- Firestore Rules 단계의 server side 검증은 별도 task `firestore_rules` 범위

---

## flutter analyze 결과

```
No issues found! (ran in 4.3s)   ← 최초 구현 시
No issues found! (ran in 4.5s)   ← admin UI 3파일 추가 후 (2026-05-01)
```
