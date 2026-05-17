# Owner 모듈 디자인 명세 — sub-phase 2 (store_registration_approval)

> 파일 위치: `lib/presentation/owner/my_store/`
> 참조: 기존 `my_store_page.dart` / `store_form_page.dart`, sub-phase 1 `common_components.md`

---

## 디자인 결정사항 요약

- **StoreFormPage 분리**: `StoreCoreFormPage` (핵심 필드) + `StoreOperationFormPage` (운영 필드) 두 페이지로 분리한다. spec T10 권장안을 채택한다. 이유: 점주가 어떤 변경이 검수에 들어가는지 명확히 인지할 수 있다.
- **OwnerMyStorePage 액션 분리**: 매장 상세 하단에 두 개의 별도 버튼을 배치한다. "매장 정보 수정" (핵심 필드, 검수 대상) 과 "운영 정보 수정" (즉시 반영).
- **RejectedBanner**: 반려 상태에서 `_StoreHeaderCard` 직하단에 배너를 표시하고 "재제출" CTA 를 배너 내부에 배치한다.
- **ApprovalStatusBadge 위치**: `_StoreHeaderCard` 하단 overlay 영역 우측에 배치한다. 기존 GradeBadge 좌측에 나란히 배치.
- **수정 대기 라벨**: `approvedAt != null && status == pending` 일 때 ApprovalStatusBadge 의 isRevision prop 을 true 로 전달하여 라벨을 '수정 대기'로 표시한다 (sub-phase 1 common_components.md 패턴 동일).

---

## 1. OwnerMyStorePage (수정)

- 파일: `presentation/owner/my_store/my_store_page.dart`
- 역할: 점주의 "내 매장" 탭. 기존 화면에 status 라벨, 반려 배너, 두 가지 수정 액션 진입점 추가.

### 레이아웃 변경사항

기존 구조를 유지하면서 아래 항목 추가:

```
CustomScrollView
  ├─ SliverAppBar (기존 그대로)
  └─ SliverPadding
       └─ SliverList
            ├─ _StoreHeaderCard (수정 — ApprovalStatusBadge 추가)
            ├─ SizedBox(height: 12)
            ├─ (status == rejected) RejectedBanner (신규)
            ├─ SizedBox(height: 16)           ← rejected 일 때만 노출
            ├─ _StoreStatusSection (신규 — pending 안내 문구)
            ├─ _StoreInfoSection (기존 그대로)
            ├─ SizedBox(height: 20)
            ├─ _StoreMetricsSection (기존 그대로)
            ├─ SizedBox(height: 20)
            ├─ _StoreActionButtons (신규 — 두 버튼)
            ├─ SizedBox(height: 32)
            └─ _DangerZone (기존 그대로)
```

### _StoreHeaderCard 수정 (ApprovalStatusBadge 추가)

기존 하단 overlay 의 Row 구조 변경:

```
Row (기존: categories + Spacer + GradeBadge)
  ├─ categories (take(3), 기존 그대로)
  ├─ Spacer
  ├─ ApprovalStatusBadge(        ← 신규 추가
  │    status: store.status,
  │    isRevision: store.approvedAt != null,
  │  )
  ├─ SizedBox(width: 6)
  └─ GradeBadge (기존 그대로)
```

- `ApprovalStatusBadge` 는 sub-phase 1 `common_components.md` 의 기본 variant (height 24) 사용
- 배경이 어두운 이미지 overlay 위에 노출되므로 배지 자체의 반투명 배경으로 가시성 확보 (sub-phase 1 배지는 이미 alpha 0.15 배경 포함)

### _StoreStatusSection (신규)

- 파일: `presentation/owner/my_store/widgets/store_status_section.dart`
- 역할: pending 상태일 때 점주에게 검토 진행 중 안내 문구 표시. rejected / approved 시에는 노출 안 함.

```
// status == pending 일 때만 노출
Container
  ├─ decoration:
  │    color: AppColors.warning.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.warning.withOpacity(0.3) 1px
  └─ Padding(horizontal 16, vertical 12)
       └─ Row(crossAxisAlignment: center)
            ├─ Icon(Icons.hourglass_top_rounded, 16, AppColors.warning)
            ├─ SizedBox(width: 10)
            └─ Expanded
                 └─ Text('검토 요청이 접수되었어요. 검토 완료까지 잠시 기다려주세요.',
                          fontSize 13, AppColors.warning, height 1.4)
```

- 이 컨테이너는 `_StoreHeaderCard` 와 `_StoreInfoSection` 사이에 위치한다
- status 가 pending 이 아닐 때는 `SizedBox.shrink()` 반환

### _StoreActionButtons (신규)

- 역할: "매장 정보 수정" (핵심, 검수) 과 "운영 정보 수정" (즉시 반영) 두 버튼을 가로로 배치
- 배치 위치: `_StoreMetricsSection` 하단, `_DangerZone` 상단

```
Row
  ├─ Expanded
  │    └─ OutlinedButton (매장 정보 수정 — 핵심 필드)
  │         - 배경: AppColors.surfaceElevated
  │         - border: AppColors.border 1px
  │         - 텍스트: AppColors.textBody, fontSize 14, w600
  │         - height: 48
  │         - radius: 12
  │         - 아이콘: Icons.edit_outlined, size 16, AppColors.textBody
  │         - 탭 → StoreCoreFormPage(existing: store)
  ├─ SizedBox(width: 10)
  └─ Expanded
       └─ OutlinedButton (운영 정보 수정 — 즉시 반영)
            - 배경: AppColors.surfaceElevated
            - border: AppColors.primary.withOpacity(0.4) 1px
            - 텍스트: AppColors.primary, fontSize 14, w600
            - height: 48
            - radius: 12
            - 아이콘: Icons.tune_rounded, size 16, AppColors.primary
            - 탭 → StoreOperationFormPage(existing: store)
```

**두 버튼의 차이 표현 의도**:
- "매장 정보 수정": 중립 톤 (border, 회색 계열) — 검수가 필요하여 신중히 누르는 액션임을 암시
- "운영 정보 수정": primary 톤 테두리 — 일상적으로 자주 쓰는 액션임을 강조

두 버튼은 status 와 무관하게 항상 활성 상태. rejected 상태에서도 운영 정보 수정 허용 (spec T2).

---

## 2. RejectedBanner (신규 위젯)

- 파일: `presentation/owner/my_store/widgets/rejected_banner.dart`
- 역할: status == rejected 일 때 `_StoreHeaderCard` 바로 아래에 노출. 반려 사유 + "재제출" CTA 제공.

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
            │    └─ Text('검토가 반려되었어요', fontSize 14, w700, AppColors.error)
            ├─ SizedBox(height: 8)
            ├─ Text(rejectedReason,          ← 반려 사유 텍스트
            │         fontSize 13,
            │         AppColors.textBody,
            │         height 1.5)
            ├─ SizedBox(height: 14)
            └─ SizedBox(width: double.infinity)
                 └─ OutlinedButton '재제출하기'
                      - border: AppColors.error 1px
                      - 텍스트: AppColors.error, fontSize 14, w700
                      - radius: 10
                      - height: 44
                      - 아이콘: Icons.refresh_rounded, size 16, AppColors.error
                      - 탭 → StoreCoreFormPage(existing: store, isResubmit: true)
```

### Props

```dart
RejectedBanner({
  required String? rejectedReason,
  required VoidCallback onResubmit,
})
```

- `rejectedReason` 이 null 또는 빈 문자열이면 사유 텍스트 대신 `'사유가 기록되지 않았어요'` 표시 (AppColors.textMuted, fontSize 13)
- `onResubmit` 탭 → `StoreCoreFormPage(existing: store, isResubmit: true)` 로 Navigator.push

### 노출 조건

- `store.status == EntityApprovalStatus.rejected` 일 때만 노출
- `_StoreHeaderCard` 아래, `_StoreStatusSection` 위치에 삽입 (SizedBox(height: 12) 간격)

---

## 3. StoreCoreFormPage (신규 — 기존 StoreFormPage 에서 핵심 필드 분리)

- 파일: `presentation/owner/my_store/store_core_form_page.dart`
- 역할: 핵심 필드만 편집. 저장 시 status=pending 회귀. 검수 대상 변경 안내 포함.
- 진입 경로:
  - `OwnerMyStorePage` "매장 정보 수정" 버튼 탭
  - `RejectedBanner` "재제출하기" 탭 (isResubmit: true)
  - 최초 매장 등록 (신규 등록 모드)

### 핵심 필드 (이 폼에서 다루는 필드)

| 필드 | 기존 StoreFormPage 위치 | 필수 여부 |
|---|---|---|
| `name` (매장명) | 있음 | 필수 |
| `address` (주소) | 있음 | 필수 |
| `lat / lng` (좌표) | 있음 (AddressSearchTile) | 필수 |
| `mainCategory` (카테고리) | 있음 (CategoryMultiSelect) | 필수 |
| `subCategories` | 있음 (CategoryMultiSelect 내부) | 선택 |
| `businessRegistrationNumber` (사업자번호) | **없음 — 신규 추가** | 선택 |

### 폼에서 제거된 필드 (StoreOperationFormPage 로 이동)

| 필드 | 이동 대상 |
|---|---|
| `phoneNumber` (전화번호) | StoreOperationFormPage |
| `businessHours` (영업시간) | StoreOperationFormPage |
| `description` (소개) | StoreOperationFormPage |
| `imageUrl` (대표 이미지) | StoreOperationFormPage |

### AppBar

- backgroundColor: `AppColors.background`, elevation 0
- leading: `Icons.close_rounded`, color `AppColors.textHeading`
- title:
  - 신규 등록: `'매장 등록'`, fontSize 17, w700, `AppColors.textHeading`
  - 수정 모드: `'매장 정보 수정'`, fontSize 17, w700, `AppColors.textHeading`
  - 재제출 모드: `'재제출'`, fontSize 17, w700, `AppColors.textHeading`

### 검수 안내 배너 (폼 최상단)

- 폼 상단, 첫 번째 필드 전 노출

```
Container
  ├─ decoration:
  │    color: AppColors.info.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.info.withOpacity(0.3) 1px
  └─ Padding(horizontal 14, vertical 10)
       └─ Row
            ├─ Icon(Icons.info_outline_rounded, 16, AppColors.info)
            ├─ SizedBox(width: 8)
            └─ Expanded
                 └─ Text('아래 정보는 관리자 검토 후 반영돼요.',
                          fontSize 12, AppColors.info, height 1.4)
```

### 폼 필드 순서 및 스타일

기존 `store_form_page.dart` 의 `_FormField`, `_AddressSearchTile`, `_CategoryMultiSelect` 위젯을 그대로 재사용한다.

1. 매장명 (`_FormField`, 필수, maxLength 30)
2. SizedBox(height: 20)
3. 주소 + 좌표 (`_AddressSearchTile`, 필수)
4. SizedBox(height: 8)
5. 수동 주소 입력 `_FormField` (주소 텍스트 필드, 기존 그대로)
6. SizedBox(height: 20)
7. 카테고리 (`_CategoryMultiSelect`, 필수)
8. SizedBox(height: 20)
9. 사업자등록번호 (`_FormField`, 선택, keyboardType: number, placeholder: `'000-00-00000'`)

사업자등록번호 필드 스타일:
- 라벨: `'사업자등록번호'`, fontSize 13, w600, `AppColors.textBody`
- 배경: `AppColors.surfaceElevated`, radius 12
- hint: `'000-00-00000'`, `AppColors.textMuted`
- 입력 keyboardType: `TextInputType.number`

### ListView padding

`EdgeInsets.fromLTRB(20, 12, 20, 120)`

### BottomSheet 저장 버튼 (_SubmitBar)

기존 `_SubmitBar` 위젯 재사용 (스타일 동일). 변경 사항:

- 버튼 색상: `AppColors.primary` (기존 `AppColors.accent` 에서 변경 — 핵심 필드 = primary 액션)
- 텍스트 색: `AppColors.onPrimary`
- disabled 배경: `AppColors.surface`, 텍스트: `AppColors.textMuted`
- 버튼 텍스트:
  - 신규 등록: `'매장 등록'`
  - 수정 모드: `'검토 요청 보내기'`
  - 재제출 모드: `'재제출하기'`

저장 성공 후:
- 신규 등록 → SnackBar `'검토 요청을 보냈어요'` (AppColors.primary.withOpacity(0.9)) + pop
- 수정 모드 → SnackBar `'검토 요청을 보냈어요. 검토 동안 매장은 계속 노출됩니다'` + pop
- 재제출 모드 → SnackBar `'재제출이 완료되었어요'` + pop

필수 미충족 시:
- 버튼 disabled 상태 유지. 누를 수 없으므로 별도 SnackBar 불필요.
- 버튼 아래 작은 안내 텍스트: `'필수 항목을 모두 입력해주세요'`, fontSize 11, `AppColors.textMuted`, 중앙 정렬 (버튼 disabled 상태에서만 노출)

### 상태별 UI

- 로딩 (저장 중): `_SubmitBar` 내부 `CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2, size: 20)` + 버튼 disabled
- 에러: `AlertDialog` (배경 `AppColors.surfaceElevated`, radius 16) — 기존 StoreFormPage 패턴 동일

---

## 4. StoreOperationFormPage (신규)

- 파일: `presentation/owner/my_store/store_operation_form_page.dart`
- 역할: 운영 필드만 편집. 저장 시 status 변동 없이 즉시 반영.
- 진입 경로: `OwnerMyStorePage` "운영 정보 수정" 버튼 탭 (status 무관하게 항상 진입 가능)

### 운영 필드 (이 폼에서 다루는 필드)

| 필드 | 기존 StoreFormPage 위치 | 비고 |
|---|---|---|
| `phoneNumber` (전화번호) | 있음 | |
| `businessHours` (영업시간) | 있음 | |
| `temporaryClosed` (임시 휴무 토글) | **없음 — 신규 추가** | Switch |
| `closedDates` (휴무일 리스트) | **없음 — 신규 추가** | `_ClosedDatesEditor` 신규 (단일 날짜 추가 + 리스트 + 삭제 버튼) |
| `description` (소개) | 있음 | |
| `imageUrls` (대표 사진 + 내부 사진) | 있음 (단일 imageUrl) | `ImageUploadField` 재사용 |
| `notice` (매장 안내) | **없음 — 신규 추가** | maxLength 200 |

> **`closedDates` 입력 방식 — 사용자 확정**: `showDatePicker` 단일 호출로 한 번에 한 날짜씩 추가하고 리스트에 누적 표시. 각 날짜 옆에 X 버튼으로 개별 삭제. 카페 임시휴무는 보통 1~3일이라 멀티셀렉트 캘린더는 과한 UX, 표준 위젯만 사용해 의존성 추가 없음.

### AppBar

- backgroundColor: `AppColors.background`, elevation 0
- leading: `Icons.close_rounded`, color `AppColors.textHeading`
- title: `'운영 정보'`, fontSize 17, w700, `AppColors.textHeading`

### 즉시 반영 안내 배너 (폼 최상단)

```
Container
  ├─ decoration:
  │    color: AppColors.success.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.success.withOpacity(0.3) 1px
  └─ Padding(horizontal 14, vertical 10)
       └─ Row
            ├─ Icon(Icons.check_circle_outline_rounded, 16, AppColors.success)
            ├─ SizedBox(width: 8)
            └─ Expanded
                 └─ Text('아래 정보는 저장 즉시 반영돼요.',
                          fontSize 12, AppColors.success, height 1.4)
```

### 폼 필드 순서 및 스타일

1. **대표 이미지** (`ImageUploadField` — sub-phase 1 common_components.md 재사용)
   - 높이: 180, 아이콘: `Icons.add_photo_alternate_rounded`
   - 기존 StoreFormPage 의 `_ImagePickerTile` 을 `ImageUploadField` 로 교체
2. SizedBox(height: 20)
3. **전화번호** (`_FormField`, 선택, keyboardType: phone)
4. SizedBox(height: 20)
5. **영업시간** (`_BusinessHoursPicker` — 기존 StoreFormPage 위젯 재사용)
6. SizedBox(height: 20)
7. **임시 휴무** (`_TemporaryClosedToggle` — 신규)
8. SizedBox(height: 12)
9. **휴무 날짜 리스트** (`_ClosedDatesEditor` — 신규, `temporaryClosed` 와 무관하게 항상 노출)
10. SizedBox(height: 20)
11. **소개** (`_FormField`, 선택, maxLength 200, maxLines 4)
10. SizedBox(height: 20)
11. **매장 안내** (`_FormField`, 선택, maxLength 200, maxLines 3, label `'매장 안내'`, placeholder `'주차 안내, 포인트 적립 등 안내 사항을 입력해주세요'`)

### _TemporaryClosedToggle (신규 위젯 — StoreOperationFormPage 전용)

```
Container
  ├─ decoration: AppColors.surfaceElevated 배경, radius 12, border AppColors.border 1px
  └─ Padding(16)
       └─ Row
            ├─ Column (flex 1)
            │    ├─ Text '임시 휴무', fontSize 14, w600, AppColors.textHeading
            │    └─ Text '활성화 시 잠시 휴무 상태로 표시돼요.',
            │              fontSize 12, AppColors.textMuted
            └─ Switch(
                 value: temporaryClosed,
                 activeColor: AppColors.error,      ← 휴무 = 경고 톤
                 activeTrackColor: AppColors.error.withOpacity(0.2),
                 inactiveTrackColor: AppColors.surface,
               )
```

- Switch 활성 (temporaryClosed=true): `AppColors.error` track + thumb — 휴무 상태의 위험성을 암시
- Switch 비활성 (temporaryClosed=false): `AppColors.surface` track

### _ClosedDatesEditor (신규 위젯 — StoreOperationFormPage 전용)

특정 날짜에 매장이 쉴 때 사용자에게 미리 알리는 휴무 날짜 리스트.

```
Container
  ├─ decoration: AppColors.surfaceElevated 배경, radius 12, border AppColors.border 1px
  └─ Padding(16)
       └─ Column (crossAxisAlignment: start)
            ├─ Row
            │    ├─ Icon(Icons.event_busy_rounded, 18, AppColors.textHeading)
            │    ├─ SizedBox(width: 8)
            │    └─ Text '휴무 날짜', fontSize 14, w600, AppColors.textHeading
            ├─ SizedBox(height: 4)
            ├─ Text '특정 날짜에 휴무인 경우 추가해주세요.',
            │       fontSize 12, AppColors.textMuted
            ├─ SizedBox(height: 12)
            ├─ (closedDates 가 비어있을 때) Empty placeholder
            │       Text '추가된 휴무 날짜가 없어요.',
            │              fontSize 12, AppColors.textMuted, italic
            ├─ (closedDates 가 있을 때) Wrap(spacing: 8, runSpacing: 8) — 날짜 칩 리스트
            │       └─ for each DateTime in closedDates:
            │            Container
            │              ├─ decoration: AppColors.background 배경, radius 8,
            │              │             border AppColors.border 1px
            │              └─ Padding(horizontal 10, vertical 6)
            │                   └─ Row(mainAxisSize: min)
            │                        ├─ Text 'YYYY-MM-DD' (intl DateFormat 또는 string padding),
            │                        │       fontSize 13, w500, AppColors.textHeading
            │                        ├─ SizedBox(width: 6)
            │                        └─ GestureDetector
            │                             onTap: () => onRemove(date)
            │                             child: Icon(Icons.close_rounded, 14,
            │                                          AppColors.textMuted)
            ├─ SizedBox(height: 12)
            └─ TextButton.icon(
                 onPressed: _onAddDate,
                 icon: Icon(Icons.add_rounded, 18, AppColors.primary),
                 label: Text '휴무 날짜 추가',
                          fontSize 13, w600, AppColors.primary,
                 style: TextButton.styleFrom(
                   padding: EdgeInsets.symmetric(horizontal 12, vertical 8),
                   foregroundColor: AppColors.primary,
                 ),
               )
```

#### _onAddDate 인터랙션

1. `showDatePicker` 호출 (Flutter 표준):
   - `initialDate`: `DateTime.now()`
   - `firstDate`: `DateTime.now()` (과거 날짜 추가 차단)
   - `lastDate`: `DateTime.now().add(const Duration(days: 365))` (1년 이내)
   - `helpText`: `'휴무 날짜 선택'`
   - `confirmText`: `'추가'`, `cancelText`: `'취소'`
   - `builder`: `Theme(data: ThemeData.light().copyWith(...AppColors.primary 톤))` 으로 다이얼로그 톤 통일
2. 사용자가 날짜 선택 → 리스트에 push (중복 시 무시 + `'이미 추가된 날짜예요'` SnackBar)
3. `closedDates` 정렬은 오름차순 (`closedDates.sort()`)

#### _onRemove 인터랙션

- 칩 우측 X 버튼 탭 → 즉시 리스트에서 제거 (확인 다이얼로그 없음, 삭제 후 다시 추가 가능)

#### Empty / 채워짐 / 5+ 개 분기

- 0건 → Empty placeholder
- 1~4건 → Wrap 으로 칩 표시
- 5+건 → 그대로 Wrap (스크롤 ListView 가 폼 전체를 감싸고 있어 자연스럽게 처리됨)

#### `temporaryClosed` 와의 관계

- 두 필드는 독립. `temporaryClosed=true` 면 즉시 휴무, `closedDates` 는 미래 예약 휴무.
- 한 매장이 둘 다 활성일 수 있음 (예: 오늘 임시 휴무 + 다음주 5/15 휴무 등록).
- customer 측은 두 필드 OR 로 휴무 표시 (디자인 영향 없음, 본 sub-phase 비범위).

### ListView padding

`EdgeInsets.fromLTRB(20, 12, 20, 120)`

### BottomSheet 저장 버튼 (_SubmitBar)

기존 `_SubmitBar` 위젯 재사용. 변경 사항:
- 버튼 색상: `AppColors.primary`
- 텍스트 색: `AppColors.onPrimary`
- 버튼 텍스트: `'즉시 반영하기'`
- disabled 조건: 없음 (운영 필드는 모두 선택 사항 — 변경 없이도 저장 가능)
  - 변경 없이 저장 시: 버튼은 활성 상태이나 UseCase 내부에서 변경 사항 없으면 pop 만 수행

저장 성공 후:
- SnackBar `'즉시 반영되었습니다'` + pop

---

## 5. OwnerMyStorePage — 빈 상태 (매장 미등록)

기존 `_EmptyStateView` 구조를 유지하되 텍스트만 업데이트.

- 기존 텍스트: `'첫 매장을 등록해 보세요'` → 유지
- 기존 CTA: `'매장 등록하기'` → `StoreCoreFormPage()` (신규 등록 모드)로 네비게이션 대상 변경
- 기존 `StoreFormPage()` 로의 네비게이션을 `StoreCoreFormPage()` 로 교체

---

## 6. 상태별 UI — OwnerMyStorePage

### Loading

- 기존 `_LoadingView`: `CircularProgressIndicator(color: AppColors.accent)` — 기존 유지 (sub-phase 1 CircularProgressIndicator 통일 패턴)

### Error

기존 `_ErrorView` 를 공통 Error 패턴으로 업그레이드:

```
Padding(all 24)
  └─ Center
       └─ Column
            ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
            ├─ SizedBox(height: 16)
            ├─ Text '매장 정보를 불러오지 못했어요', fontSize 16, w700, AppColors.textHeading
            ├─ SizedBox(height: 8)
            ├─ Text '일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요',
            │         fontSize 13, AppColors.textMuted, 중앙 정렬
            ├─ SizedBox(height: 24)
            └─ ElevatedButton '다시 시도'
                 - 배경: AppColors.primary
                 - 텍스트: AppColors.onPrimary, w600
                 - radius: 12
                 - padding: horizontal 24 vertical 12
                 - 탭 → ref.refresh(myStoreProvider)
```

### Empty (매장 미등록)

기존 `_EmptyStateView` 구조 유지. CTA 진입 대상만 `StoreCoreFormPage()` 로 변경.

---

## 7. 인터랙션 정리

| 동작 | 반응 |
|---|---|
| "매장 정보 수정" 버튼 탭 | `StoreCoreFormPage(existing: store)` Navigator.push |
| "운영 정보 수정" 버튼 탭 | `StoreOperationFormPage(existing: store)` Navigator.push |
| `RejectedBanner` "재제출하기" 탭 | `StoreCoreFormPage(existing: store, isResubmit: true)` Navigator.push |
| `StoreCoreFormPage` 저장 (신규) | `SubmitStoreForApprovalUseCase` 호출 → SnackBar + pop |
| `StoreCoreFormPage` 저장 (수정) | `SubmitStoreForApprovalUseCase` 호출 → SnackBar + pop |
| `StoreCoreFormPage` 저장 (재제출) | `SubmitStoreForApprovalUseCase` 호출 → SnackBar + pop |
| `StoreOperationFormPage` 저장 | `UpdateStoreOperationFieldsUseCase` 호출 → SnackBar + pop |
| `StoreCoreFormPage` 취소 (AppBar leading) | Navigator.pop (변경 저장 안 됨) |
| `StoreOperationFormPage` 취소 | Navigator.pop |

---

## 8. 개발자 전달 특이사항 (Owner 모듈)

### 기존 StoreFormPage 처리

기존 `store_form_page.dart` 는 두 파일로 분리된다:
- `store_core_form_page.dart` — 핵심 필드 (name, address, lat/lng, mainCategory, subCategories, businessRegistrationNumber)
- `store_operation_form_page.dart` — 운영 필드 (phoneNumber, businessHours, temporaryClosed, closedDates, description, imageUrls, notice)

기존 `StoreFormPage` 는 `@Deprecated` 처리 후 두 신규 폼에서 사용하지 않는 필드를 각각 제거. 재사용 가능한 내부 위젯 클래스:

| 기존 위젯 | 재사용 위치 |
|---|---|
| `_FormField` | 두 폼 모두 재사용 |
| `_AddressSearchTile` | `StoreCoreFormPage` 만 |
| `_CategoryMultiSelect` | `StoreCoreFormPage` 만 |
| `_BusinessHoursPicker` | `StoreOperationFormPage` 만 |
| `_ImagePickerTile` | `StoreOperationFormPage` 로 이동 또는 `ImageUploadField` 로 교체 |
| `_SubmitBar` | 두 폼 모두 재사용 (색상 변경) |

### 사업자등록번호 필드 신규 추가

`StoreEntity` / `StoreModel` 에 `businessRegistrationNumber: String?` 필드가 spec 에 정의되어 있음. `StoreCoreFormPage` 에서 이 필드를 `_FormField` 로 추가. 기존 StoreFormPage 에는 없던 필드이므로 Entity/Model 에 먼저 추가 필요.

### 기존 `_DangerZone` 의 하드코딩 색상

`my_store_page.dart` 의 `_DangerZone` 에 `Color(0xFFF87171)` 하드코딩이 있음. 이를 `AppColors.error` 로 교체 필요 (CLAUDE.md 절대 규칙).

### SnackBar 색상 통일

- 핵심 필드 저장 성공: `AppColors.primary.withOpacity(0.9)` 배경, `AppColors.onPrimary` 텍스트
- 운영 필드 저장 성공: `AppColors.success.withOpacity(0.9)` 배경, `AppColors.onPrimary` 텍스트
- 실패: `AppColors.error` 배경

### myStoreProvider 확장

기존 `WatchOwnerStoreUseCase` 는 Stream&lt;StoreEntity?&gt; 반환 — 변경 없이 그대로 사용. `StoreEntity` 에 status 필드가 추가되면 자동으로 반영됨.
