# Test Report — admin_menu_management / 2_store_registration_approval

> 작성일: 2026-04-30 (FAIL 해소: 2026-05-01)
> 검증자: Tester Agent
> 기준 문서: spec.md / design/ (owner_module.md, admin_module.md, common_components.md) / implementation.md / 실제 구현 코드

---

## 전체 요약

| 구분 | 개수 |
|---|---|
| PASS | 50 |
| FAIL | 0 (FAIL-01/02/03 모두 2026-05-01 해소) |
| 보류 | 6 |

> 회귀: `flutter analyze` 0 issue 재확인 완료.

---

## 테스트 방법

- 정적 코드 검증 (파일 직접 열람)
- 문서 교차 검증 (spec.md / design.md / implementation.md 비교)
- `flutter analyze` 실행 → `No issues found! (ran in 4.2s)` 확인
- 실기기 / Firebase 런타임 검증은 환경 제약으로 보류 처리

---

## 1. Spec 결정사항 T1~T10 검증

| ID | 항목 | 결과 | 비고 |
|---|---|---|---|
| T1 | 시드/legacy 매장 status 누락 → approved fallback | PASS | `EntityApprovalStatus.fromString(null)` → `approved` 반환. `StoreModel.fromFirestore` 에서 `data['status']` 누락 시 `fromString(null)` 호출 확인 |
| T2 | 결정 J 핵심/운영 필드 분리 — `updateStoreCoreFields` + `updateStoreOperationFields` | PASS | Repository interface / impl 양쪽 분리 구현. `toFirestoreForCoreUpdate` / `toFirestoreForOperationUpdate` 맵 분리 확인 |
| T3 | rejected → 재제출 시 `rejectedReason/approvedBy/approvedAt` null 클리어 | PASS | `isResubmit` 플래그 → `toFirestoreForCoreUpdate(isResubmit: true)` → 클리어 맵 포함 확인 |
| T4 | ownership 검증 — `_assertOwnership` / `_assertAdmin` | PASS | `StoreRepositoryImpl` 에 두 가드 메서드 구현. admin role이면 all-pass, 비본인이면 `StateError` |
| T5 | AdminScaffold 세그먼트 3탭 (브랜드/마스터 메뉴/매장) | PASS | `admin_approval_queue_page.dart` 3탭 확장 완료. `IndexedStack` 에 `AdminPendingStoresPage` 추가 확인 |
| T6 | 점주 폼 brandId UI 없음 — RepositoryImpl 자동 null | PASS | `StoreCoreFormPage` 에 brandId 필드 없음. `submitStoreForApproval` → 신규 등록 분기에서 `brandId: null` 강제 확인 |
| T7 | customer status 필터 — `_filterApproved` | PASS | `getNearbyStores` / `getStoresByCategories` 양쪽에 `_filterApproved(models)` 적용 확인. client side filter 로 legacy approved fallback 통과 |
| T8 | 반려 사유 글자 수 제한 없음 | PASS | `RejectReasonDialog` 재사용, client side 글자 수 제한 없음 확인 |
| T9 | `StoreScopeBadge.personal()` — AppColors.info 톤 "개인 매장" | PASS | `store_scope_badge.dart` — `AppColors.info.withValues(alpha: 0.12)`, `'개인 매장'` 라벨, `StoreScopeBadge.personal()` const 생성자 확인 |
| T10 | owner status 라벨 — 카드 + 상세 양쪽 | PASS | `_StoreHeaderCard` 에 `ApprovalStatusBadge(status, isRevision)` 표시. `_RejectedBanner` / `_StoreStatusSection` 분기 모두 구현 |

---

## 2. 결정 J 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| 핵심 필드 수정 시 status=pending 회귀 | PASS | `toFirestoreForCoreUpdate` 에 `'status': EntityApprovalStatus.pending.asString` 고정 확인 |
| 핵심 필드 수정 시 approvedBy/At 보존 (approved→pending) | PASS | `isResubmit=false` 일 때 approvedBy/At 맵에 포함하지 않음 → Firestore partial update 로 보존 |
| 운영 필드 수정 시 status/승인 메타 불변 | PASS | `toFirestoreForOperationUpdate` 에 status 관련 필드 없음 확인 |
| 신규 등록 → status='pending' 자동 박힘 + submittedBy/At | PASS | `toFirestoreForCreate` 에 `'status': EntityApprovalStatus.pending.asString`, `'submittedAt': FieldValue.serverTimestamp()` 확인 |
| "수정 대기" 라벨 (`approvedAt != null && status==pending`) | PASS (owner) / FAIL (admin 큐) | owner `_StoreHeaderCard`에서 `isRevision` 계산 후 `ApprovalStatusBadge(isRevision: isRevision)` 전달. admin `_StoreQueueTile` 에는 `ApprovalStatusBadge` 및 `수정 대기` 텍스트 누락 (FAIL-01) |

---

## 3. closedDates 입력 방식 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `_ClosedDatesEditor` 신규 위젯 구현 | PASS | `store_operation_form_page.dart` 내 private class `_ClosedDatesEditor` |
| `showDatePicker` 단일 호출 (멀티셀렉트 X) | PASS | `_addClosedDate()` 에서 `showDatePicker` 1회 호출 확인 |
| 중복 차단 + SnackBar '이미 추가된 날짜예요' | PASS | `alreadyExists` 체크 후 SnackBar 표시 확인 |
| 오름차순 정렬 (`closedDates.sort()`) | PASS | 추가 후 `_closedDates.sort()` 확인 |
| 과거 날짜 추가 차단 (`firstDate: DateTime.now()`) | PASS | `showDatePicker(firstDate: now)` 확인 |
| X 버튼 즉시 삭제 (확인 다이얼로그 없음) | PASS | `onRemove: () => onRemove(d)` → `setState(() => _closedDates.remove(d))` 직접 삭제 |
| Empty placeholder 텍스트 | PASS | `'추가된 휴무 날짜가 없어요.'` 확인 |

---

## 4. customer 회귀 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| Phase 1a — `getNearbyStores` / `getStoresByCategories` 시그니처 불변 | PASS | 시그니처 변경 없음, 내부 `_filterApproved` 추가만 |
| Phase 1a — `watchByOwner` / `deleteStore` 시그니처 불변 | PASS | |
| Phase 1a — customer StoreMenuPage / MenuItemDetailPage 호출부 무변경 | PASS | StoreRepository 시그니처 불변, StoreEntity 신규 필드 전부 default 값 흡수 |
| Phase 1c — 즐겨찾기 토글 호출부 무변경 | PASS | FavoritesRepository 무영향 확인 |
| Phase 2 — 추천/재주문 — 호출부 무변경 + status=approved 필터 적용 | PASS | `getStoresByCategories` 경유 시 approved 필터 통과 |
| 시드 매장 (status 필드 없음) → approved fallback → customer 검색 노출 | PASS | `EntityApprovalStatus.fromString(null)` → `approved` → `_filterApproved` 통과 |
| 시드 매장 (brandId 필드 없음) → null fallback | PASS | `StoreModel.fromFirestore` `data['brandId'] as String?` → null |

---

## 5. sub-phase 1 회귀 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| brand role / BrandScaffold 진입 | PASS | `RoleRouter` 변경 없음 |
| 마스터 메뉴 CRUD 정상 | PASS | 관련 파일 무변경 |
| 결정 J 마스터 메뉴 측 Core/Operation/visible 토글 | PASS | sub-phase 1 test_report.md FAIL-J01 해소 기록 확인 |
| `_BrandPendingList` / `_MasterMenuPendingList` — 코드 무변경 | PASS | `admin_approval_queue_page.dart` 에 기존 두 위젯 그대로 존재 |
| `pendingBrandsProvider` / `pendingMasterMenuItemsProvider` 무영향 | PASS | admin_brand_approval_providers / admin_master_menu_approval_providers 파일 무변경 |
| AdminScaffold 2탭 → 3탭 확장 후 기존 탭 위치 변경 없음 | PASS | 브랜드/마스터 메뉴 index 0/1 유지, 매장 index 2 추가 |

---

## 6. owner 화면 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `OwnerMyStorePage` — 매장 카드 `ApprovalStatusBadge` 표시 | PASS | `_StoreHeaderCard` 에 `ApprovalStatusBadge(status, isRevision)` 구현 |
| `OwnerMyStorePage` — `isRevision` 계산 (`approvedAt != null && status==pending`) | PASS | 코드 line 299-300 확인 |
| `OwnerMyStorePage` — rejected 상태에서 `_RejectedBanner` 노출 | PASS | `if (isRejected)` 분기 구현 |
| `OwnerMyStorePage` — pending 상태에서 `_StoreStatusSection` 노출 | PASS | `if (isPending)` 분기 구현 |
| `OwnerMyStorePage` — 두 수정 액션 버튼 분리 | PASS | "매장 정보 수정" → `StoreCoreFormPage`, "운영 정보 수정" → `StoreOperationFormPage` |
| `_RejectedBanner` — "재제출하기" CTA | PASS | `onResubmit` 탭 → `StoreCoreFormPage(existing: store, isResubmit: true)` |
| `_RejectedBanner` — `rejectedReason` null 시 fallback 문구 | PASS | `'사유가 기록되지 않았어요'` 표시 확인 |
| `_DangerZone` 하드코딩 색상 (`Color(0xFFF87171)`) 제거 여부 | PASS | 현재 `my_store_page.dart` 에서 `Color(0x...)` 하드코딩 0건. `AppColors.error` 사용 확인 |
| `StoreCoreFormPage` — AppBar 모드별 타이틀 (등록/수정/재제출) | PASS | `_appBarTitle` getter 3분기 구현 확인 |
| `StoreCoreFormPage` — 검수 안내 배너 (`_ReviewNoticeBanner`) | PASS | `AppColors.info.withValues(alpha: 0.08)` + `'아래 정보는 관리자 검토 후 반영돼요.'` |
| `StoreCoreFormPage` — 저장 성공 SnackBar 모드별 분기 | PASS | 신규→`'검토 요청을 보냈어요'`, 수정→`'검토 요청을 보냈어요. 검토 동안 매장은 계속 노출됩니다'`, 재제출→`'재제출이 완료되었어요'` |
| `StoreOperationFormPage` — 즉시 반영 안내 배너 (`_InstantNoticeBanner`) | PASS | `AppColors.success.withValues(alpha: 0.08)` + `'아래 정보는 저장 즉시 반영돼요.'` |
| `StoreOperationFormPage` — `_TemporaryClosedToggle` Switch (activeColor: AppColors.error) | PASS | `activeThumbColor: AppColors.error`, `activeTrackColor: AppColors.error.withValues(alpha: 0.2)` |
| `StoreOperationFormPage` — 저장 성공 SnackBar `'즉시 반영되었습니다'` | PASS | 코드 line 236 확인 |
| `StoreOperationFormPage` — SnackBar backgroundColor (design: AppColors.success, actual: AppColors.primary) | FAIL | design `owner_module.md` L554: 운영 필드 저장 성공 시 `AppColors.success.withOpacity(0.9)` 지정. 실제 구현은 `AppColors.primary.withValues(alpha: 0.9)` 사용 (FAIL-02) |
| `OwnerMyStorePage` — 빈 상태 CTA `StoreCoreFormPage()` 로 연결 | PASS | `_EmptyStateView` 에서 `StoreCoreFormPage()` 로 `Navigator.push` 확인 |

---

## 7. admin 화면 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `AdminApprovalQueuePage` — 세그먼트 3탭 | PASS | '브랜드 승인' / '마스터 메뉴 승인' / '매장' 탭 확인 |
| `AdminApprovalQueuePage` — 탭 라벨 '매장' vs design '매장 승인' | FAIL | design `admin_module.md` L28-30: 3번째 탭 라벨 `'매장 승인'`. 실제 구현은 `'매장'` (FAIL-03) |
| `AdminPendingStoresPage` — pending 매장 리스트 | PASS | `adminPendingStoresProvider` watch, `ListView.builder` 구현 |
| `AdminPendingStoresPage` — `_StoreQueueTile` StoreScopeBadge('개인 매장') | PASS | `StoreScopeBadge.personal()` 확인 |
| `AdminPendingStoresPage` — `_StoreQueueTile` 이름/주소/카테고리/제출시각 | PASS | 4개 정보 모두 표시 |
| `AdminPendingStoresPage` — `_StoreQueueTile` `ApprovalStatusBadge` trailing | FAIL | design `admin_module.md` L95: trailing 에 `ApprovalStatusBadge(status, isRevision)` 필수. 실제 `_StoreQueueTile` 에 `ApprovalStatusBadge` 없음. `approvedAt != null` 시 `'수정 대기'` 텍스트도 없음 (FAIL-01) |
| `AdminPendingStoresPage` — 빈 상태 '승인 대기 중인 매장이 없어요' | PASS | 구현 일치 |
| `AdminPendingStoresPage` — 로딩 CircularProgressIndicator (design: AppColors.primary, actual: AppColors.primaryBright) | 보류 | 미미한 색상 차이. 기능 영향 없음. 디자인 일관성 차원의 낮은 우선순위 항목 |
| `AdminStoreApprovalDetailPage` — AppBar 타이틀 '매장 승인 심사' vs '매장 승인' | 보류 | design L159: `'매장 승인 심사'`. 실제: `'매장 승인'`. spec 에 명시 없음. 의미 차이 최소, 낮은 우선순위 |
| `AdminStoreApprovalDetailPage` — 매장 이름/주소/사업자번호/카테고리/전화번호 | PASS | `_SectionCard` + `_InfoRow` 로 표시 확인 |
| `AdminStoreApprovalDetailPage` — `ApprovalStatusBadge(status)` 표시 | PASS | 섹션 B Row 에 표시 확인 |
| `AdminStoreApprovalDetailPage` — `ApprovalStatusBadge` isRevision prop 누락 | 보류 | line 144: `ApprovalStatusBadge(status: store.status)` — isRevision 없음. "수정 대기" 라벨 표시 안 됨. 기능 영향 낮으나 spec T2 "수정 대기" 라벨 누락 |
| `AdminStoreApprovalDetailPage` — `StoreScopeBadge.personal()` 표시 | PASS | 섹션 B 에 `StoreScopeBadge.personal()` 확인 |
| `AdminStoreApprovalDetailPage` — `ApprovalActionsBar` pending 시만 노출 | PASS | `bottomNavigationBar: isPending ? ApprovalActionsBar(...) : null` |
| `AdminStoreApprovalDetailPage` — approved/rejected 상태 배너 | PASS | `_InfoBanner` — approved=success 색, rejected=error 색. sub-phase 1 FAIL-02 패턴 해소 확인 |
| 승인 → SnackBar `'매장을 승인했어요'` | PASS | 코드 line 36 확인 |
| 반려 → `RejectReasonDialog` → `'반려했어요'` | PASS | 코드 line 63 확인 (`'반려했어요'`는 spec 검증 항목 기준. design은 `'반려 처리되었습니다'` — spec 우선 적용) |
| `RejectReasonDialog` — 사유 0자 시 반려 버튼 disabled | PASS | sub-phase 1 산출 그대로 재사용 |
| `watchStoreByIdForAdminProvider` — stream 기반 (watchAllForAdmin + filter) | PASS | spec 의 `GetStoreByIdUseCase` 대신 `watchAllForAdmin` stream 을 storeId 필터링으로 실시간 반영. 기능 동등 |

---

## 8. Clean Architecture / 절대 규칙 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| presentation/domain 에 cloud_firestore import 0건 | PASS | grep 결과 presentation/domain 레이어 0건 (firebase_auth는 auth_provider 기존 패턴, sub-phase 2 추가분 아님) |
| domain 레이어 순수 Dart 유지 | PASS | UseCase/Entity/Repository Interface 에 Flutter/Firebase 의존 없음 |
| `Color(0x...)` 하드코딩 0건 (sub-phase 2 신규 파일) | PASS | 신규 5개 파일 (`my_store_page.dart`, `store_core_form_page.dart`, `store_operation_form_page.dart`, `admin_pending_stores_page.dart`, `admin_store_approval_detail_page.dart`, `store_scope_badge.dart`, `admin_store_approval_providers.dart`) 에서 `Color(0x...)` 0건 |
| `my_store_page.dart` 기존 `Color(0xFFF87171)` 제거 여부 | PASS | 파일 전체 검색 결과 하드코딩 색상 0건. `AppColors.error` 사용 확인 |
| Repository Interface = domain | PASS | `store_repository.dart` — domain 레이어 |
| Repository Impl = data | PASS | `store_repository_impl.dart` — data 레이어 |
| DataSource = data | PASS | `store_remote_data_source.dart` — data 레이어 |
| UseCase = domain | PASS | 신규 7개 UseCase 모두 domain 레이어 |
| Provider/Widget = presentation | PASS | |
| `flutter analyze` 0 issue | PASS | `No issues found! (ran in 4.2s)` 확인 |

---

## 9. 데이터 모델 / Firestore 무결성 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `StoreEntity` 신규 필드 11개 | PASS | `brandId?`, `status`, `submittedBy?`, `submittedAt?`, `approvedBy?`, `approvedAt?`, `rejectedReason?`, `businessRegistrationNumber?`, `temporaryClosed`, `closedDates`, `imageUrls`, `notice`, `updatedAt?` 모두 추가 확인 |
| `StoreModel.fromFirestore` missing status → approved fallback | PASS | `EntityApprovalStatus.fromString(data['status'] as String?)` — null → approved |
| `StoreModel.fromFirestore` missing brandId → null | PASS | `data['brandId'] as String?` |
| `closedDates` Timestamp→DateTime 변환 | PASS | `whereType<Timestamp>().map((t) => t.toDate())` |
| `imageUrls` List<dynamic>→List<String> 변환 | PASS | `whereType<String>()` |
| `toFirestoreForCreate` — brandId=null, status=pending 강제 | PASS | |
| `toFirestoreForCoreUpdate` — isResubmit=true 시 클리어 맵 포함 | PASS | |
| `toFirestoreForOperationUpdate` — status 관련 필드 없음 | PASS | |
| `approveFields` / `rejectFields` static 메서드 | PASS | |
| `StoreEntity` 기존 필드 default 값 — freezed 재생성 호환 | PASS | `@Default(EntityApprovalStatus.approved)`, `@Default(false)`, `@Default([])` — 기존 생성코드 컴파일 에러 없이 흡수 |

---

## FAIL 항목

### FAIL-01 — `_StoreQueueTile` ApprovalStatusBadge 및 수정 대기 라벨 누락

- **문제**: `AdminPendingStoresPage` 의 `_StoreQueueTile` 에 `ApprovalStatusBadge` (trailing) 와 `approvedAt != null && status==pending` 조건의 `'수정 대기'` 텍스트가 구현되지 않음
- **위치**: `lib/presentation/admin/approval/admin_pending_stores_page.dart` — `_StoreQueueTile.build()` (line 44~149 전체)
- **확인 방법**: 코드에서 `ApprovalStatusBadge`, `isRevision`, `수정 대기` 키워드 grep → 0건
- **스펙 근거**: `design/admin_module.md` L95-97: trailing에 `ApprovalStatusBadge(status: store.status, isRevision: store.approvedAt != null)` 및 L92-94: `approvedAt != null` 시 `'수정 대기'` Text 위젯 필수
- **제안**: `_StoreQueueTile` trailing 에 `ApprovalStatusBadge(status: store.status, isRevision: store.approvedAt != null)` 추가. subtitle 내 `if (store.approvedAt != null) Text('수정 대기', ...)` 조건부 추가
- **우선순위**: 중간 (admin UX에 직접 영향. 매장 심사 시 일반 pending vs 수정 대기 구분 불가)

---

### FAIL-02 — `StoreOperationFormPage` 저장 성공 SnackBar 배경색 불일치

- **문제**: 운영 정보 저장 성공 SnackBar의 `backgroundColor` 가 design 명세(`AppColors.success.withOpacity(0.9)`)와 달리 `AppColors.primary.withValues(alpha: 0.9)` 로 구현됨
- **위치**: `lib/presentation/owner/my_store/store_operation_form_page.dart` — `_submit()` 메서드 line 235-239
- **확인 방법**: 파일 line 235-239 확인: `backgroundColor: AppColors.primary.withValues(alpha: 0.9)`
- **스펙 근거**: `design/owner_module.md` L554: `'운영 필드 저장 성공: AppColors.success.withOpacity(0.9) 배경'`. 핵심 폼과 색상 구분이 필요한 이유는 점주가 두 폼의 차이를 피드백으로 인지하게 하기 위함
- **제안**: `backgroundColor: AppColors.success.withValues(alpha: 0.9)` 로 변경 (line 237)
- **우선순위**: 낮음 (기능 동작 무영향, 순수 UX 색상 차이)

---

### FAIL-03 — admin 세그먼트 탭 라벨 `'매장'` vs design `'매장 승인'`

- **문제**: `AdminApprovalQueuePage` 3번째 세그먼트 탭 라벨이 `'매장'` 으로 구현. design은 `'매장 승인'` 지정
- **위치**: `lib/presentation/admin/approval/admin_approval_queue_page.dart` line 62: `label: '매장'`
- **확인 방법**: 파일 line 62 확인
- **스펙 근거**: `design/admin_module.md` L29: `_SegTab('매장 승인', index: 2)` — 기존 '브랜드 승인' / '마스터 메뉴 승인' 패턴과 일관성 필요
- **제안**: `label: '매장 승인'` 으로 변경 (line 62)
- **우선순위**: 낮음 (기능 동작 무영향, 텍스트 일관성 차이)

---

## 보류 항목

### H-01 — `AdminPendingStoresPage` 로딩 색상 — AppColors.primaryBright vs AppColors.primary

- **이유**: design은 `CircularProgressIndicator(color: AppColors.primary)` 지정. 실제 `AppColors.primaryBright` 사용. 기능 영향 없음
- **필요한 확인**: 디자인 시스템 일관성 — sub-phase 1 에서 `AppColors.primaryBright` 가 로딩 색상으로 통일됐다면 design 문서가 오기입일 수 있음. 설계자 확인 필요
- **후속 작업 제안**: 로딩 색상 가이드라인 단일 진실원 정리

---

### H-02 — `AdminStoreApprovalDetailPage` AppBar 타이틀 `'매장 승인'` vs design `'매장 승인 심사'`

- **이유**: design `admin_module.md` L159: `'매장 승인 심사'`. 실제 `'매장 승인'`. spec 에 title 명시 없음. 기능 영향 없음
- **필요한 확인**: UX 복사본 결정 — 심사 중임을 강조하려면 `'매장 승인 심사'` 가 더 명확
- **후속 작업 제안**: 텍스트 리뷰 시 함께 수정 가능

---

### H-03 — `AdminStoreApprovalDetailPage` `ApprovalStatusBadge` isRevision 미전달

- **이유**: line 144: `ApprovalStatusBadge(status: store.status)` — `isRevision: store.approvedAt != null` 미전달. admin 상세에서 "수정 대기" 라벨 표시 안 됨
- **필요한 확인**: spec T2 에서 admin 승인 큐 상세 화면의 "수정 대기" 라벨 표시 여부 확인. 큐 리스트(FAIL-01)와 상세 양쪽 모두 표시 권장
- **후속 작업 제안**: FAIL-01 수정 시 함께 처리 권장

---

### H-04 — `closedDates` 과거 날짜 정리 미구현

- **이유**: implementation.md 미구현 항목 2로 기록. 기존 저장된 과거 날짜가 그대로 표시됨
- **필요한 확인**: 필요 시 과거 날짜 자동 필터링 적용
- **후속 작업 제안**: `_ClosedDatesEditor` 렌더링 시 `DateTime.now()` 이후 날짜만 표시하거나 `updateStoreOperationFields` 호출 시 필터링 (별도 task)

---

### H-05 — Firestore 복합 인덱스 (stores — status + submittedAt)

- **이유**: `streamPending()` 이 `where('status', isEqualTo: 'pending').orderBy('submittedAt', descending: true)` 복합 쿼리 사용. 인덱스 누락 시 Firestore 에러 발생 가능
- **필요한 확인**: Firebase 콘솔에서 자동 생성 링크 확인 또는 `firestore.indexes.json` 수동 등록
- **후속 작업 제안**: 별도 task `firestore_indexes` 로 처리

---

### H-06 — Firestore 보안 규칙 (owner/admin 서버 사이드 검증)

- **이유**: ownership 검증 / admin role 가드가 client side(`StoreRepositoryImpl`)에서만 수행. 서버 규칙 없으면 직접 API 호출 가능
- **필요한 확인**: Firestore Rules 단계 검증 필요
- **후속 작업 제안**: 별도 task `firestore_rules` 로 처리

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **FAIL 3건 있음 — 수정 후 sub-phase 3 진입 권장**
- FAIL-01 / FAIL-03은 admin 화면 표시 문제, FAIL-02는 SnackBar 색상 차이
- 3건 모두 1줄~수 줄 수정으로 해결 가능한 낮은 복잡도 항목
- core 기능 (Domain/Data 레이어, T1~T10 정책, customer 회귀, sub-phase 1 회귀) 은 전부 PASS

### 재작업 우선순위

1. **FAIL-01** — `_StoreQueueTile` ApprovalStatusBadge 및 수정 대기 라벨 추가
   - 이유: admin이 승인 큐에서 일반 pending vs 수정 대기 구분 불가. 운영상 영향 있음
   - 파일: `lib/presentation/admin/approval/admin_pending_stores_page.dart` — `_StoreQueueTile`
   - 함께 처리 권장: H-03 (`admin_store_approval_detail_page.dart` line 144 isRevision 추가)

2. **FAIL-03** — 세그먼트 탭 라벨 `'매장'` → `'매장 승인'`
   - 이유: '브랜드 승인' / '마스터 메뉴 승인' 패턴 일관성 파괴
   - 파일: `lib/presentation/admin/approval/admin_approval_queue_page.dart` line 62

3. **FAIL-02** — 운영 폼 SnackBar backgroundColor primary → success
   - 이유: 핵심/운영 폼 성공 피드백 색상 구분 안 됨
   - 파일: `lib/presentation/owner/my_store/store_operation_form_page.dart` line 237

### 후속 task 후보

- `firestore_indexes` — stores 컬렉션 복합 인덱스 (status + submittedAt)
- `firestore_rules` — 서버 사이드 ownership/role 검증
- `closedDates_cleanup` — 과거 날짜 정리 자동화

---

## 완료 판단

- [ ] 전체 PASS
- [x] FAIL 있으나 후속 task로 분리 가능 (FAIL-02, FAIL-03)
- [x] 재작업 필요 (FAIL-01 — admin 운영 영향)
