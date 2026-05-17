# sub-phase 2 — store_registration_approval 디자인 명세 (인덱스)

> **상태**: 작성 완료
>
> **참조 sub-phase**: sub-phase 1 (brand_master) — 디자인 토큰 / 공통 위젯 재사용
>
> **디자인 시스템 단일 진실원**: [docs/agents/designer_guide.md](../../../agents/designer_guide.md)

---

## 산출물 구성

| 파일 | 내용 |
|---|---|
| [design/owner_module.md](design/owner_module.md) | OwnerMyStorePage 갱신 / StoreCoreFormPage / StoreOperationFormPage / `_TemporaryClosedToggle` / `_ClosedDatesEditor` |
| [design/admin_module.md](design/admin_module.md) | AdminApprovalQueuePage 세그먼트 3탭 확장 / AdminPendingStoresPage / AdminStoreApprovalDetailPage |
| [design/common_components.md](design/common_components.md) | `StoreScopeBadge.personal()` / `RejectedBanner` / 공통 상태 UI |

---

## 주요 디자인 결정사항

### 1. StoreFormPage — 두 페이지 분리 (spec T2 / 결정 J)

기존 단일 `StoreFormPage` 를 **`StoreCoreFormPage`** + **`StoreOperationFormPage`** 두 페이지로 분리.

이유: 점주가 "이 변경이 검수를 유발하는지 여부"를 폼 진입 전에 명확히 인지할 수 있어야 함. 단일 폼 + 섹션 분리 방식 미채택.

진입은 `OwnerMyStorePage` 의 두 액션 버튼:
- **"매장 정보 수정"** (중립 톤 — 회색 보더) → `StoreCoreFormPage` (검수 게이트)
- **"운영 정보 수정"** (primary 톤 보더) → `StoreOperationFormPage` (즉시 반영)

### 2. StoreScopeBadge.personal() — info 톤 채택

- 라벨: `'개인 매장'`
- 아이콘: `Icons.person_rounded`
- 색: `AppColors.info` (정보성 식별자 — `ApprovalStatusBadge` 의 warning/success/error 와 시각 구분)

> 브랜드 매장 뱃지는 sub-phase 3 에서 `.brand(brandName)` factory 로 확장.

### 3. status 색상 매핑 (sub-phase 1 패턴 그대로)

- `pending` → `AppColors.warning` (배경 alpha 0.15)
- `approved` → `AppColors.success`
- `rejected` → `AppColors.error`
- "수정 대기" (`approvedAt != null && status==pending`) → pending 색 + 라벨만 `'수정 대기'`

### 4. 임시 휴무 Switch — error 톤 채택

`_TemporaryClosedToggle` 의 active Switch 는 `AppColors.error` 톤. 임시 휴무 = 영업 중단 위험성을 시각적으로 암시.

### 5. closedDates 입력 방식 (사용자 확정)

`_ClosedDatesEditor` 신규 위젯:
- `showDatePicker` 단일 호출 (멀티셀렉트 X, table_calendar 패키지 미도입)
- 추가된 날짜는 칩 리스트로 누적 표시 + 각 칩 X 버튼으로 개별 삭제
- 중복 차단 + 오름차순 정렬

이유: 카페 임시휴무는 보통 1~3일이라 멀티셀렉트 캘린더는 과한 UX. 표준 위젯만 사용해 의존성 추가 없음.

### 6. RejectedBanner — `_StoreHeaderCard` 바로 아래 배치

점주가 화면 진입 직후 반려 상황을 인지하고 재제출 액션으로 바로 이어지게 함.

### 7. AdminApprovalQueuePage — 세그먼트 3탭 (sub-phase 1 의 2탭 → 3탭)

`'브랜드 승인'` / `'마스터 메뉴 승인'` / `'매장 승인'` 3탭. `IndexedStack` 으로 subscription 유지.

> sub-phase 3 에서 4탭으로 확장 + AppBar 타이틀 `'승인'` 통일 + 라벨 짧게 변경 예정.

### 8. AdminPendingStoresPage — 매장 카드 + ScopeBadge

매장 승인 큐 카드는 `StoreScopeBadge.personal()` 명시 — sub-phase 2 시점은 개인 매장만 (브랜드 매장 등록 흐름은 sub-phase 3).

---

## 재사용 컴포넌트 (sub-phase 1 그대로)

| 컴포넌트 | 파일 | 재사용 위치 |
|---|---|---|
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | OwnerMyStorePage 매장 카드, AdminPendingStoresPage 카드, AdminStoreApprovalDetailPage 헤더 |
| `RejectReasonDialog` | `presentation/common/widgets/reject_reason_dialog.dart` | AdminStoreApprovalDetailPage 반려 액션 |
| `ApprovalActionsBar` | `presentation/admin/widgets/approval_actions_bar.dart` | AdminStoreApprovalDetailPage 하단 |
| `ImageUploadField` | `presentation/common/widgets/image_upload_field.dart` | StoreOperationFormPage 사진 입력 |

---

## customer 측 회귀 (디자인 영향 없음)

결정 T7 — customer 매장 검색/추천/지도 진입점에 `status=='approved'` 필터 추가. 디자인 변경 없음. 시드 매장 / legacy 매장은 model `fromFirestore` 의 fallback 으로 'approved' 처리되어 정상 노출.
