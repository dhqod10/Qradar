# sub-phase 3 — brand_store_customization 디자인 명세 (인덱스)

> **상태**: 작성 완료
>
> **참조 sub-phase**: sub-phase 1 (brand_master), sub-phase 2 (store_registration_approval)
>
> **디자인 시스템 단일 진실원**: [docs/agents/designer_guide.md](../../../agents/designer_guide.md)

---

## 산출물 구성

| 파일 | 내용 |
|---|---|
| [design/brand_module.md](design/brand_module.md) | Brand 모듈 7화면 + BrandScaffold 탭 갱신 |
| [design/admin_module.md](design/admin_module.md) | Admin 모듈 4-5화면 + AdminApprovalQueuePage 4탭 확장 |
| [design/common_components.md](design/common_components.md) | 공통 위젯 5종 + 상태 UI |

---

## 주요 디자인 결정사항

### 1. AdminApprovalQueuePage — 4탭 채택 (spec U1)

세그먼트 탭 `'브랜드 승인'` / `'마스터 메뉴 승인'` / `'매장 승인'` / `'매장 커스텀'` 4탭.

매장 커스텀 탭 본문에는 **인라인 sub-segment** (`가격 오버라이드` / `점포 한정 메뉴`) 2개를 추가한다.
sub-segment 는 PreferredSize 패턴이 아닌 탭 본문 상단 고정 Row 로 구현한다 — 이유: 세그먼트와 sub-segment 두 레이어가 AppBar 에 동시에 쌓이면 모바일 공간 낭비가 크므로, 매장 커스텀 본문에서만 sub-segment 를 스크롤 상단에 sticky 하게 유지한다.

### 2. StoreScopeBadge.brand(brandName) — primary 톤 채택

- `StoreScopeBadge.personal()`: `AppColors.info` 톤 (sub-phase 2 확정)
- `StoreScopeBadge.brand(brandName)`: `AppColors.primary` 톤 — brand 관계를 앱의 메인 포인트(primary)로 표현
  - 배경: `AppColors.primary.withOpacity(0.12)`
  - 아이콘 + 텍스트: `AppColors.primary`
  - 라벨: `'브랜드: {brandName}'` (예: `'브랜드: 스타벅스'`)
  - 아이콘: `Icons.business_rounded`

### 3. OwnerMyStorePage brandId 분기 — "매장 정보 수정" 비노출 채택

비노출(완전 제거) 방식으로 결정한다 (disabled + 안내 텍스트 방식 미채택). 이유: 점주가 brand 매장에서 핵심 필드 수정이 구조적으로 불가능하다는 사실을 명확히 전달하기 위해 버튼 자체를 숨긴다. disabled 상태는 "지금은 안 되지만 나중에 될 수 있다"는 오해를 줄 수 있다.

대신 brand 매장임을 알리는 안내 텍스트를 삽입한다: `'매장 핵심 정보는 브랜드 본사가 관리해요'`

### 4. 가격 오버라이드 미리보기 형식

`MasterMenuOverrideCard` 에서 가격 변경 표시: `'₩4,500 → ₩5,000'`
- 마스터 가격: `AppColors.textMuted`, fontSize 13, 취소선(`TextDecoration.lineThrough`)
- 화살표: `AppColors.textMuted`, fontSize 13
- override 가격: `AppColors.primary`, fontSize 14, w700

### 5. BrandApprovalTrackingPage — 단일 통합 리스트 채택

매장 / 가격 오버라이드 / 점포 한정 메뉴를 **타입 라벨로 구분하는 단일 리스트**로 표시.
인라인 탭 분리 방식 미채택 — 이유: brand 가 제출 항목을 종합적으로 모니터링하는 목적에서 단일 리스트가 직관적이다. 각 항목에 타입 뱃지를 표시한다.

---

## 재사용 컴포넌트 (sub-phase 1/2 에서 그대로)

| 컴포넌트 | 파일 | 재사용 위치 |
|---|---|---|
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | 전 화면 그대로 |
| `RejectReasonDialog` | `presentation/common/widgets/reject_reason_dialog.dart` | Admin 상세 페이지 반려 액션 |
| `ApprovalActionsBar` | `presentation/admin/widgets/approval_actions_bar.dart` | Admin 상세 페이지 하단 |
| `ImageUploadField` | `presentation/common/widgets/image_upload_field.dart` | BrandStoreOnlyMenuFormPage |
| `_TemporaryClosedToggle` | StoreOperationFormPage 내부 | 재사용 없음 (brand 폼 비범위) |
| `StoreScopeBadge` | `presentation/admin/widgets/store_scope_badge.dart` | brand 케이스 분기 추가 |
