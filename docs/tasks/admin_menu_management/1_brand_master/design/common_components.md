# 공통 컴포넌트 디자인 명세

> 위치: `presentation/common/widgets/` (모듈 간 재사용) 또는 모듈 내 `widgets/` (단일 모듈 한정)

---

## 1. ApprovalStatusBadge

- 역할: `pending` / `approved` / `rejected` 세 상태를 색상 + 라벨로 시각화하는 인라인 배지
- 위치: `presentation/common/widgets/approval_status_badge.dart`
- 위젯 구조:
  ```
  Container (pill)
    └─ Row
         ├─ Container (8×8 원형 dot)
         └─ Text (라벨)
  ```
- 크기:
  - height: 24
  - padding: horizontal 10, vertical 4
  - dot: 8×8, radius 999
  - 라벨 Text gap (dot~text): 6
- radius: 999 (pill)
- border: 없음

### 상태별 색상

| status | 배경 | dot 색 | 라벨 색 | 라벨 텍스트 |
|---|---|---|---|---|
| pending | `AppColors.warning.withOpacity(0.15)` | `AppColors.warning` | `AppColors.warning` | `'검토 중'` |
| approved | `AppColors.success.withOpacity(0.15)` | `AppColors.success` | `AppColors.success` | `'승인됨'` |
| rejected | `AppColors.error.withOpacity(0.15)` | `AppColors.error` | `AppColors.error` | `'반려됨'` |

- 라벨 텍스트 스타일: fontSize 12, fontWeight w600

### 변형: 큰 배지 (admin 승인 상세 페이지 상단 강조)

- height: 32, padding: horizontal 14 vertical 6, dot: 10×10, 라벨 fontSize 13 w700

### 특이사항

- `approvedAt != null && status == pending` 케이스 → 라벨을 `'수정 대기'` 로 표시 (S3 정책). 배경/dot/라벨 색은 pending 과 동일.
- `ApprovalStatusBadge(status: entity.status, isRevision: entity.approvedAt != null)` 형태로 prop 전달.

---

## 2. RejectReasonDialog

- 역할: admin 이 반려 사유를 입력하는 다이얼로그
- 위치: `presentation/common/widgets/reject_reason_dialog.dart`
- 트리거: `AdminApprovalActionsBar` 의 "반려" 버튼 탭
- 노출 방식: `showDialog` (barrier dismissible: false)

### 위젯 구조

```
AlertDialog / Dialog (custom)
  └─ Column
       ├─ Text (제목)
       ├─ SizedBox(height: 16)
       ├─ TextField (멀티라인)
       ├─ SizedBox(height: 24)
       └─ Row
            ├─ TextButton '취소'
            └─ SizedBox(width: 8)
            └─ ElevatedButton '반려 확정'
```

### 스타일

- 배경: `AppColors.surfaceElevated`
- radius: 16
- padding (내부): horizontal 24, vertical 24
- 제목: fontSize 16, fontWeight w700, color `AppColors.textHeading`
- TextField:
  - maxLines: 3
  - minLines: 3
  -배경: `AppColors.surface`
  - border: `AppColors.border` 1px, radius 10
  - 포커스 border: `AppColors.primary`
  - hint: `'반려 사유를 입력해주세요'`, color `AppColors.textMuted`
  - 텍스트: `AppColors.textBody`
- '취소' 버튼:
  - TextButton
  - 텍스트: `AppColors.textMuted`, w500, 14
- '반려 확정' 버튼:
  - 배경: `AppColors.error`
  - 텍스트: `AppColors.onPrimary`, w600, 14
  - radius: 10
  - padding: horizontal 16 vertical 10
  - disabled: 사유 입력 0자일 때 비활성 (`AppColors.surface` 배경, `AppColors.textMuted` 텍스트)

### 인터랙션

- 사유 입력 0자 → "반려 확정" disabled
- 사유 1자 이상 → "반려 확정" 활성
- "취소" 탭 → 다이얼로그 pop (아무 동작 없음)
- "반려 확정" 탭 → `Navigator.pop(context, reason)` 으로 사유 반환 → 호출부에서 `RejectBrandUseCase` / `RejectMasterMenuItemUseCase` 실행

---

## 3. ImageUploadField

- 역할: 이미지 선택 → 미리보기 → 업로드 progress → 완료 미리보기 갱신. 브랜드 로고 / 메뉴 이미지 공통 사용.
- 위치: `presentation/common/widgets/image_upload_field.dart`

### 상태 분기

| 상태 | 표시 |
|---|---|
| 이미지 없음 (초기) | placeholder 영역 (점선 border + 아이콘 + 안내 문구) |
| 로컬 파일 선택 후 (업로드 전) | 로컬 이미지 미리보기 (File 기반 Image.file) + 우상단 X 버튼 |
| 업로드 중 | 이미지 위에 반투명 overlay + LinearProgressIndicator |
| 업로드 완료 | 네트워크 이미지 미리보기 (Image.network) + 우상단 X 버튼 |
| 에러 | placeholder 영역 + 에러 메시지 하단 + 재시도 안내 |

### 위젯 구조

```
Column
  ├─ GestureDetector (이미지 영역 탭 → image_picker 실행)
  │    └─ ClipRRect (radius 12)
  │         └─ Stack
  │              ├─ [상태에 따라] Placeholder / Image / 업로드 오버레이
  │              └─ Positioned (우상단) — X 버튼 (로컬 선택 후 / 완료 시)
  └─ (에러 시) Text (에러 메시지)
```

### Placeholder 영역 스타일

- 크기: width 전체, height 180 (메뉴 이미지) / height 120 (브랜드 로고, 정사각 160×160 옵션 있음)
- 배경: `AppColors.surface`
- border: `AppColors.border` 1.5px dashed, radius 12
- 아이콘: 브랜드 로고 → `Icons.storefront_rounded` / 메뉴 이미지 → `Icons.local_cafe_outlined`, size 36, `AppColors.textMuted`
- 안내 텍스트: `'탭하여 이미지 선택'`, fontSize 13, `AppColors.textMuted`
- 서브 텍스트: `'JPG / PNG, 최대 5MB'`, fontSize 11, `AppColors.textMuted`

### 업로드 중 오버레이

- 배경: `AppColors.primary.withOpacity(0.4)` 전체 오버레이
- LinearProgressIndicator: `AppColors.primaryBright` (valueColor), `AppColors.surface` (backgroundColor), 중앙 하단 배치, height 4
- 업로드 진행률 (0.0~1.0) 을 `value` 로 전달. 정확한 progress 는 `StorageDataSource.uploadWithProgress` stream 사용.

### X 버튼 (제거)

- `Icons.cancel_rounded`, size 22
- 배경: `AppColors.surfaceElevated` 원형 (24×24)
- 아이콘 색: `AppColors.error`
- 탭 → 선택 이미지 초기화 (placeholder 상태로 복귀)

### 에러 메시지

- fontSize 12, `AppColors.error`
- 텍스트: `'이미지 용량이 5MB를 초과했습니다'` / `'이미지 업로드에 실패했어요. 다시 시도해주세요'`

---

## 4. TagChipsSelector

- 역할: `recommended` / `new` / `best` 태그 다중 선택 chip
- 위치: `presentation/common/widgets/tag_chips_selector.dart`

### 위젯 구조

```
Wrap (spacing 8, runSpacing 8)
  └─ [각 태그마다] FilterChip 또는 커스텀 Chip
```

### 태그 표시 텍스트

| 값 | 표시 라벨 |
|---|---|
| `recommended` | `'추천'` |
| `new` | `'신메뉴'` |
| `best` | `'베스트'` |

### Chip 스타일

선택됨:
- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`, fontSize 13, w600
- border: 없음
- radius: 999

선택 안 됨:
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- 텍스트: `AppColors.textBody`, fontSize 13, w400
- radius: 999

- height: 36, padding: horizontal 14

### 인터랙션

- 탭 → 토글 (다중 선택 허용, 최대 3개 전부 선택 가능)
- 상위 위젯에 `onChanged(List<String> tags)` 콜백으로 현재 선택 목록 전달

---

## 5. VisibilityToggle

- 역할: 메뉴 `visible` 값 토글 + 도움말 텍스트
- 위치: `presentation/brand/master_menu/widgets/visibility_toggle.dart` (brand 모듈 한정)

### 위젯 구조

```
Row
  ├─ Column (flex 1)
  │    ├─ Text '메뉴 노출 여부'
  │    └─ Text '비활성화 시 고객에게 노출되지 않습니다'
  └─ Switch
```

### 스타일

- 컨테이너: `AppColors.surfaceElevated` 배경, radius 12, padding 16, border `AppColors.border` 1px
- 라벨: fontSize 14, fontWeight w600, `AppColors.textHeading`
- 도움말: fontSize 12, `AppColors.textMuted`
- Switch 활성: `AppColors.primary` (activeColor) / `AppColors.accent` (thumbColor 활성) — 구현 시 `Switch.adaptive` 또는 `CupertinoSwitch` 스타일 검토
- Switch 비활성: `AppColors.surface` (trackColor)

---

## 6. OptionGroupSelector

- 역할: 마스터 메뉴 폼에서 옵션 그룹 다중 선택 (master scope only, store scope 미노출)
- 위치: `presentation/brand/master_menu/widgets/option_group_selector.dart`

### 위젯 구조

```
Column
  ├─ Text '옵션 그룹' (섹션 제목)
  ├─ SizedBox(height: 8)
  └─ ListView.builder (shrinkWrap: true, physics: NeverScrollableScrollPhysics)
       └─ [각 optionGroup] CheckboxListTile (커스텀 스타일)
```

### CheckboxListTile 스타일

- 배경: `AppColors.surfaceElevated`, radius 10, margin bottom 8
- border: `AppColors.border` 1px
- title: 옵션 그룹 이름, fontSize 14, w500, `AppColors.textBody`
- subtitle: `'마스터 옵션'` 라벨 (scope 확인용, 회색), fontSize 11, `AppColors.textMuted`
- Checkbox 활성: `AppColors.primary`
- Checkbox 비활성 (border): `AppColors.border`

### 빈 상태

- 등록된 master scope 옵션 그룹 없음 → `'등록된 옵션 그룹이 없어요'` 텍스트, `AppColors.textMuted`, fontSize 13, 중앙 정렬
- padding: 24

### 로딩 상태

- Shimmer: 옵션 그룹 항목 3개 형태의 skeleton (높이 52, radius 10, `AppColors.surface` → `AppColors.surfaceElevated`)

---

## 7. ApprovalActionsBar

- 역할: admin 승인 상세 페이지 하단 고정 액션 바 (반려 / 승인)
- 위치: `presentation/admin/widgets/approval_actions_bar.dart`

### 위젯 구조

```
Container (bottomNavigationBar 영역)
  └─ SafeArea (top: false)
       └─ Padding (horizontal 20, vertical 12)
            └─ Row
                 ├─ Expanded — '반려' 버튼
                 ├─ SizedBox(width: 12)
                 └─ Expanded — '승인' 버튼
```

### 컨테이너 스타일

- 배경: `AppColors.surfaceElevated`
- border top: `AppColors.border` 1px
- elevation: 0

### '반려' 버튼

- 배경: `AppColors.error.withOpacity(0.1)`
- 텍스트: `AppColors.error`, fontSize 15, w700
- border: `AppColors.error` 1px
- radius: 12
- height: 52
- 탭 → `RejectReasonDialog` 노출

### '승인' 버튼

- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`, fontSize 15, w700
- border: 없음
- radius: 12
- height: 52
- 탭 → 확인 SnackBar + 이전 화면 pop (`'승인 처리되었습니다'`)

### 로딩 상태 (승인/반려 처리 중)

- 두 버튼 모두 disabled 처리
- '승인' 버튼 내부 `CircularProgressIndicator` (크기 20, `AppColors.onPrimary`)

---

## 8. 공통 상태 UI

### Loading (Shimmer)

모든 리스트 / 카드 로딩 시 shimmer skeleton 사용.

- shimmer base: `AppColors.surface`
- shimmer highlight: `AppColors.surfaceElevated`
- progress color (LinearProgressIndicator 단독 사용 시): `AppColors.primaryBright`
- 구조: 실제 카드와 동일한 형태의 `Container` (rounded, 크기 동일)

### Error

```
Center
  └─ Column
       ├─ Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error)
       ├─ SizedBox(height: 16)
       ├─ Text (에러 제목, fontSize 16, w700, AppColors.textHeading)
       ├─ SizedBox(height: 8)
       ├─ Text (에러 설명, fontSize 13, AppColors.textMuted, 중앙 정렬)
       ├─ SizedBox(height: 24)
       └─ ElevatedButton '다시 시도'
            - 배경: AppColors.primary
            - 텍스트: AppColors.onPrimary, w600
            - radius: 12
            - padding: horizontal 24 vertical 12
```

에러 설명 기본 문구: `'일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요'`

### Empty

```
Center
  └─ Column
       ├─ Icon (화면별 적합한 아이콘, size: 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text (안내 문구, fontSize 16, w600, AppColors.textHeading)
       ├─ SizedBox(height: 8)
       ├─ Text (보조 설명, fontSize 13, AppColors.textMuted)
       └─ (CTA 있는 경우) SizedBox(height: 24) + ElevatedButton
```

화면별 Empty 문구 / 아이콘 / CTA:

| 화면 | 아이콘 | 안내 문구 | CTA |
|---|---|---|---|
| BrandInfoPage (미등록) | `Icons.storefront_outlined` | `'아직 브랜드가 등록되지 않았어요'` | `'브랜드 등록하기'` → BrandFormPage |
| MasterMenuListPage | `Icons.local_cafe_outlined` | `'아직 등록된 메뉴가 없어요'` | `'+ 메뉴 추가'` → MasterMenuFormPage |
| AdminPendingQueuePage (brand 세그먼트) | `Icons.check_circle_outline_rounded` | `'검토 대기 중인 브랜드가 없어요'` | 없음 |
| AdminPendingQueuePage (메뉴 세그먼트) | `Icons.check_circle_outline_rounded` | `'검토 대기 중인 메뉴가 없어요'` | 없음 |

### 권한 없음 (_BrandIdMissingView)

- BrandScaffold 진입 시 brandId null 케이스 전용 뷰
- 구조:
  ```
  Center
    └─ Column
         ├─ Icon(Icons.warning_amber_rounded, size: 56, AppColors.warning)
         ├─ SizedBox(height: 20)
         ├─ Text '브랜드 계정 설정이 필요해요'  (fontSize 17, w700, AppColors.textHeading)
         ├─ SizedBox(height: 12)
         └─ Text '관리자에게 브랜드 ID 발급을 요청해주세요.\n로그아웃 후 다시 로그인하면 확인할 수 있어요'
                  (fontSize 13, AppColors.textMuted, 중앙 정렬)
  ```
