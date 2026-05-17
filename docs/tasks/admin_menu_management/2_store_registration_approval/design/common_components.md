# 공통 컴포넌트 디자인 명세 — sub-phase 2 (store_registration_approval)

> sub-phase 1 의 `common_components.md` 를 기반으로 sub-phase 2 에서 추가/확장되는 컴포넌트만 기록한다.
> 기존 컴포넌트 (ApprovalStatusBadge / RejectReasonDialog / ImageUploadField / ApprovalActionsBar) 는 변경 없이 그대로 재사용한다.

---

## 재사용 컴포넌트 (변경 없음)

| 컴포넌트 | 파일 | 재사용 방식 |
|---|---|---|
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | sub-phase 1 그대로 재사용. `isRevision` prop 포함. |
| `RejectReasonDialog` | `presentation/common/widgets/reject_reason_dialog.dart` | sub-phase 1 그대로 재사용. |
| `ApprovalActionsBar` | `presentation/admin/widgets/approval_actions_bar.dart` | sub-phase 1 그대로 재사용. |
| `ImageUploadField` | `presentation/common/widgets/image_upload_field.dart` | `StoreOperationFormPage` 에서 재사용. 아이콘을 `Icons.add_photo_alternate_rounded` 로 전달. |

---

## 신규 컴포넌트

---

## 1. StoreScopeBadge

- 파일: `presentation/admin/widgets/store_scope_badge.dart`
- 역할: 매장 scope ("개인 매장" / "브랜드 매장") 를 표시하는 인라인 배지. 본 sub-phase 에서는 항상 '개인 매장'.
- 사용 위치:
  - `AdminPendingStoresPage` 의 `_StoreQueueTile` title Row 내부
  - `AdminStoreApprovalDetailPage` 의 섹션 B (매장 이름 하단)

### 위젯 구조

```
Container (pill)
  └─ Row
       ├─ Icon(Icons.storefront_outlined, 11, AppColors.info)
       ├─ SizedBox(width: 4)
       └─ Text(label, fontSize 11, w600, AppColors.info)
```

### 스타일

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.info.withOpacity(0.12)` |
| border | 없음 |
| radius | 999 (pill) |
| height | 22 |
| padding | horizontal 8, vertical 3 |
| 아이콘 | `Icons.storefront_outlined`, size 11, `AppColors.info` |
| 텍스트 | `AppColors.info`, fontSize 11, w600 |

### 색상 선택 근거

- "개인 매장" 은 정보성 뱃지 (scope 식별용) → semantic `AppColors.info` 톤 사용
- `ApprovalStatusBadge` (pending=warning, approved=success, rejected=error) 와 시각적으로 구분됨
- sub-phase 3 에서 "브랜드 매장" 뱃지 추가 시 동일 위젯에 label prop 만 변경 (또는 별도 색상 분기 추가)

### Props

```dart
StoreScopeBadge({required String label})
```

현재 사용: `StoreScopeBadge(label: '개인 매장')`

---

## 2. RejectedBanner

- 파일: `presentation/owner/my_store/widgets/rejected_banner.dart`
- 역할: owner 매장 화면에서 status == rejected 일 때 반려 사유 + 재제출 CTA 를 표시하는 배너
- 사용 위치: `OwnerMyStorePage` 의 `_StoreHeaderCard` 바로 하단

### 위젯 구조

```
Container
  ├─ decoration:
  │    color: AppColors.error.withOpacity(0.06)
  │    borderRadius: 14
  │    border: AppColors.error.withOpacity(0.3) 1px
  └─ Padding(horizontal 16, vertical 14)
       └─ Column (crossAxisAlignment: start)
            ├─ Row
            │    ├─ Icon(Icons.cancel_outlined, 18, AppColors.error)
            │    ├─ SizedBox(width: 8)
            │    └─ Text '검토가 반려되었어요', fontSize 14, w700, AppColors.error
            ├─ SizedBox(height: 8)
            ├─ Text(rejectedReason 또는 '사유가 기록되지 않았어요',
            │         fontSize 13, AppColors.textBody 또는 AppColors.textMuted,
            │         height 1.5)
            ├─ SizedBox(height: 14)
            └─ SizedBox(width: double.infinity)
                 └─ OutlinedButton.icon(
                      icon: Icon(Icons.refresh_rounded, 16, AppColors.error)
                      label: '재제출하기'
                      style:
                        border: AppColors.error 1px
                        텍스트: AppColors.error, fontSize 14, w700
                        radius: 10
                        height: 44 (minimumSize: Size(double.infinity, 44))
                    )
```

### 상태 분기

| 상태 | 사유 텍스트 | 사유 색상 |
|---|---|---|
| rejectedReason 있음 | 사유 텍스트 그대로 | `AppColors.textBody` |
| rejectedReason null / 빈 문자열 | `'사유가 기록되지 않았어요'` | `AppColors.textMuted` |

### Props

```dart
RejectedBanner({
  required String? rejectedReason,
  required VoidCallback onResubmit,
})
```

---

## 3. 공통 상태 UI 추가 (sub-phase 2 적용 화면)

sub-phase 1 의 공통 상태 UI 패턴을 본 sub-phase 신규 화면에도 동일하게 적용한다.

### 로딩 (본 sub-phase 적용 화면)

sub-phase 1 에서 CircularProgressIndicator 를 사용했으므로 본 sub-phase 도 동일하게 통일.

- `OwnerMyStorePage` 로딩: 기존 `CircularProgressIndicator(color: AppColors.accent)` 유지
- `AdminPendingStoresPage` 로딩: `CircularProgressIndicator(color: AppColors.primary)`
- `AdminStoreApprovalDetailPage` 로딩: 이미지 영역 `AppColors.surface` 배경 + 하단 `CircularProgressIndicator(color: AppColors.primary)`

### 에러 (본 sub-phase 신규 화면)

sub-phase 1 공통 Error 패턴 동일. 화면별 문구:

| 화면 | 에러 제목 | 재시도 방식 |
|---|---|---|
| `OwnerMyStorePage` | `'매장 정보를 불러오지 못했어요'` | `ref.refresh(myStoreProvider)` |
| `AdminPendingStoresPage` | `'데이터를 불러오는 데 실패했어요.'` | `ref.refresh(pendingStoresProvider)` |
| `AdminStoreApprovalDetailPage` | `'매장 정보를 불러오지 못했어요.'` | `Navigator.pop` 으로 돌아가기 |

### 빈 상태 (본 sub-phase 신규 화면)

기존 common_components.md Empty 표에 아래 항목 추가:

| 화면 | 아이콘 | 안내 문구 | CTA |
|---|---|---|---|
| `OwnerMyStorePage` (매장 미등록) | `Icons.storefront_outlined` | `'첫 매장을 등록해 보세요'` | `'매장 등록하기'` → `StoreCoreFormPage()` |
| `AdminPendingStoresPage` (큐 비어있음) | `Icons.check_circle_outline_rounded` | `'승인 대기 중인 매장이 없어요'` | 없음 |

---

## 디자인 시스템 일관성 체크리스트

본 sub-phase 신규 컴포넌트가 sub-phase 1 과 일관성을 유지하는지 확인:

| 항목 | sub-phase 1 | sub-phase 2 |
|---|---|---|
| 카드 radius | 14 | 14 (동일) |
| 카드 border | `AppColors.border` 1px | `AppColors.border` 1px (동일) |
| 카드 배경 | `AppColors.surfaceElevated` | `AppColors.surfaceElevated` (동일) |
| 다이얼로그 radius | 16 | 16 (동일, RejectReasonDialog 재사용) |
| AppBar 스타일 | background, elevation 0 | 동일 |
| 세그먼트 탭 높이 | 44 | 44 (동일) |
| 선택된 세그먼트 | `AppColors.primary` + 2px 언더라인 | 동일 |
| status 색 (pending) | `AppColors.warning` | 동일 |
| status 색 (approved) | `AppColors.success` | 동일 |
| status 색 (rejected) | `AppColors.error` | 동일 |
| 로딩 방식 | CircularProgressIndicator | CircularProgressIndicator (통일) |
| 에러 아이콘 | `Icons.error_outline_rounded`, size 48 | 동일 |
| 빈 상태 아이콘 | size 56 | size 56 (동일) |
