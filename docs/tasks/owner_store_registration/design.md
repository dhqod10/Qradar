# 점주 매장 등록 디자인 명세

## 디자인 방침
- 기존 Qradar 다크 프리미엄 테마 유지 (`AppColors` 전용, 하드코딩 금지)
- 고객 화면은 **Electric Blue** 가 주액션 색. 점주 화면은 **Gold(Accent)** 를 보조 악센트로 추가해 "운영자/관리자" 영역임을 시각적으로 구분
- 전역 토큰(Border Radius / Spacing / Typography)은 `docs/tasks/home/design.md` 와 공유

---

## 전역 토큰 (재사용 + 추가)

### 재사용
- Border Radius, Spacing, Typography, 등급 색상은 홈 디자인 명세 그대로

### 추가
| 용도 | 크기 | 굵기 | 색상 |
|------|------|------|------|
| 폼 레이블 | 13 | w600 | AppColors.textDefault |
| 폼 placeholder | 15 | w400 | AppColors.textMuted |
| 폼 입력 텍스트 | 15 | w500 | AppColors.textDark |
| 필드 에러 메시지 | 12 | w500 | `Color(0xFFF87171)` → 차기 `AppColors.error`로 승격 권장 |
| 저장 버튼 라벨 | 15 | w700 | white |

---

## 화면 1: RoleRouter (라우팅)

진입 조건: `authProvider.state.data != null && currentUserProfileProvider.state.hasData`

```
if role == owner  → OwnerScaffold
else              → ScaffoldWithNav (고객)
```

로딩 중: AppColors.background + 중앙 CircularProgressIndicator(primaryBright)

---

## 화면 2: OwnerScaffold

**구조:**
```
Scaffold
  - backgroundColor: AppColors.background
  - body: IndexedStack
      ├─ MyStorePage        // index 0
      ├─ OwnerOrdersPlaceholder   // index 1 (placeholder)
      ├─ OwnerSalesPlaceholder    // index 2 (placeholder)
      └─ OwnerMorePage       // index 3 (점주 더보기: 고객으로 전환, 로그아웃)
  - bottomNavigationBar: OwnerBottomNav
```

### OwnerBottomNav

- 고객 BottomNav 와 같은 높이/구조 유지 (일관성)
- **중앙 FAB 없음** — 4개 탭 균등 분배
- 활성 색상을 `AppColors.accent` (Gold) 로 사용하여 고객 화면(primaryBright)과 차별화

| index | 아이콘 | 라벨 |
|-------|--------|------|
| 0 | `Icons.storefront_rounded` | 내 매장 |
| 1 | `Icons.receipt_long_rounded` | 주문 접수 |
| 2 | `Icons.bar_chart_rounded` | 매출 |
| 3 | `Icons.more_horiz_rounded` | 더보기 |

스타일:
```
color: active ? AppColors.accent : AppColors.textMuted
label: fontSize 11, w500, active ? AppColors.textDark : AppColors.textMuted
```

배경: AppColors.surface, 상단 border: surfaceElevated 1px.

---

## 화면 3: MyStorePage

### 상태 분기
```
myStoreProvider (StreamProvider<StoreEntity?>)
  - loading  → Shimmer 풀카드
  - null     → 매장 등록 CTA
  - data     → 매장 상세 카드
  - error    → 에러 UI + 재시도
```

### 3-1. 빈 상태 (등록 전)

중앙 정렬 Column.

```
Padding(horizontal: 20, top: 80)
  Column
    ├─ Container (CTA 카드)
    │    - width: double.infinity
    │    - padding: all 24
    │    - decoration:
    │        gradient: LinearGradient(
    │          [AppColors.surfaceElevated, AppColors.surface],
    │          begin: topLeft, end: bottomRight
    │        )
    │        borderRadius: 20
    │        border: Border.all(AppColors.accent.withAlpha(0.4), 1.5)
    │        boxShadow: BoxShadow(
    │          AppColors.accent.withAlpha(0.15),
    │          blur 20
    │        )
    │    - child: Column(crossAxisAlignment: start)
    │        ├─ Row
    │        │   ├─ Container(48x48, circle, gradient[primaryBright→primaryDeep])
    │        │   │   └─ Icon(storefront_rounded, 24, white)
    │        │   └─ Spacer + Text("OWNER" chip, fontSize 10, w700, accent)
    │        ├─ SizedBox(24)
    │        ├─ Text("첫 매장을 등록해 보세요",
    │        │       fontSize 20, w700, textDark)
    │        ├─ SizedBox(8)
    │        ├─ Text("매장 정보를 등록하면 Qrator들이 주변에서 발견할 수 있어요.",
    │        │       본문, textDefault)
    │        ├─ SizedBox(24)
    │        └─ FilledButton(
    │             onPressed: → StoreFormPage(create)
    │             style: accent 배경, white 텍스트, radius 12, height 52,
    │             child: Row(MainAxisSize.min)
    │                ├─ Icon(add_rounded, 18)
    │                └─ Text("매장 등록하기", w700)
    │           )
    └─ SizedBox(40)
```

**디자인 의도:**
- Accent Gold 글로우로 "중요한 다음 액션" 시각적 강조
- 일반 primaryBright 버튼이 아닌 **accent 배경** 버튼 → 점주 주액션을 확실히 차별화

### 3-2. 등록 완료 상태

```
CustomScrollView
  slivers:
    ├─ SliverAppBar(
    │    backgroundColor: AppColors.background,
    │    pinned: false,
    │    title: Text("내 매장", 섹션 제목),
    │    actions: [
    │      IconButton(Icons.edit, → StoreFormPage(update))
    │    ]
    │  )
    └─ SliverList(...)
       ├─ StoreHeaderCard (이미지 + 이름 + 등급 배지)
       ├─ StoreInfoSection (주소/전화/카테고리/운영시간)
       ├─ StoreMetricsSection (평균 점수, 리뷰 수 — 읽기 전용)
       └─ DangerZone (매장 삭제 버튼)
```

**StoreHeaderCard:**
```
Container
  - height: 220
  - decoration: radius 16, border surfaceElevated
  - child: Stack
      ├─ CachedNetworkImage (fit: cover, 이미지 없으면 gradient 플레이스홀더)
      ├─ Positioned(bottom: 0, left: 0, right: 0):
      │   Container(
      │     gradient: [transparent, AppColors.background.withAlpha(0.9)],
      │     padding: all 16
      │   )
      │   └─ Column
      │       ├─ Text(name, fontSize 22, w700, textDark)
      │       └─ Row: 카테고리 칩들(max 3) + GradeBadge
      └─ (등록 이미지 없으면) 중앙에 Icon(storefront, 64, textMuted.alpha 0.4)
```

**StoreInfoSection:**
각 행은 `Row(Icon + 16px gap + Text)` 레이아웃. 아이콘 20px textMuted, 텍스트 본문 스타일.
- 📍 주소
- ☎ 전화번호 (tap → `tel:` 링크)
- 🏷 카테고리 (칩들을 Wrap로)
- 🕐 운영시간 ("매일 09:00 ~ 22:00" 포맷)
- 📝 소개 (있으면)

**StoreMetricsSection:**
3열 Row, 각 Cell은:
```
Column
  ├─ Text(value, fontSize 18, w700, textDark)
  └─ Text(label, 보조 레이블)
```
셀: 등급(GradeBadge 확장) / 평균점수(`4.1`) / 리뷰수(`124`)

**DangerZone:**
```
TextButton.icon(
  icon: Icon(delete_outline, 18, Color(0xFFF87171)),
  label: Text("매장 삭제", color: Color(0xFFF87171), w600),
  → 확인 다이얼로그 → deleteStore
)
```

---

## 화면 4: StoreFormPage (등록/수정 공통)

### 구조
```
Scaffold
  - backgroundColor: AppColors.background
  - appBar: AppBar(
      backgroundColor: AppColors.background,
      title: Text(isEdit ? "매장 수정" : "매장 등록"),
      leading: IconButton(close, → confirm if dirty)
    )
  - body: Form + ListView
      ├─ ImagePickerTile       // 대표 이미지
      ├─ FormField: 매장명
      ├─ FormField: 전화번호
      ├─ FormField: 주소
      ├─ LocationPickerTile    // "현재 위치 불러오기" 버튼
      ├─ CategoryMultiSelect   // 12 카테고리 중 복수 선택
      ├─ BusinessHoursPicker   // open/close 단일 구간
      ├─ FormField: 소개 (multi-line, max 200)
      └─ SizedBox(32)
  - bottomSheet: 저장 버튼 (고정)
```

**전체 패딩:** horizontal 20, 각 필드 간 세로 간격 20.

### 4-1. StoreFormField (공통 입력 필드)

```
Column(crossAxisAlignment: start)
  ├─ Row
  │    ├─ Text(label, 폼 레이블 스타일)
  │    ├─ if required: Text(" *", color: AppColors.accent)
  │    └─ Spacer + (optional counter: "12 / 30")
  ├─ SizedBox(8)
  ├─ Container
  │    - padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)
  │    - decoration:
  │        color: AppColors.surfaceElevated
  │        borderRadius: 12
  │        border: Border.all(
  │          focused  ? AppColors.primaryBright
  │          : hasError ? Color(0xFFF87171)
  │          : Colors.transparent,
  │          1.5
  │        )
  │    - child: TextField(
  │        style: 폼 입력 텍스트,
  │        decoration: InputDecoration.collapsed(hintText: placeholder),
  │        cursorColor: AppColors.primaryBright,
  │      )
  └─ if error: Padding(top 6): Text(errorText, 필드 에러 메시지 스타일)
```

### 4-2. ImagePickerTile

```
GestureDetector(onTap: → image_picker)
  Container
    - height: 160
    - decoration:
        color: AppColors.surfaceElevated
        borderRadius: 16
        border: Border.all(
          image == null ? AppColors.surfaceElevated : AppColors.primaryBright.alpha(0.5),
          style: dashed (container-only — if painful, use solid 1px)
        )
    - child: Stack
        if 이미지 없음:
          Center(
            Column
              ├─ Icon(add_photo_alternate_rounded, 36, textMuted)
              ├─ SizedBox(8)
              └─ Text("대표 이미지 추가 (선택)", 본문, textMuted)
          )
        else:
          ClipRRect(radius 16, child: Image.file(picked, fit: cover))
          Positioned(top 8, right 8):
            GestureDetector(onTap: clear, child:
              Container(circle, AppColors.background.alpha(0.7), 32x32)
                Icon(close, 16, white)
            )
```

### 4-3. LocationPickerTile

```
Container
  - padding: all 16, radius 12, AppColors.surfaceElevated
  - child: Row
      ├─ Icon(location_on_rounded, 24, primaryBright)
      ├─ SizedBox(12)
      ├─ Expanded
      │    └─ Column
      │        ├─ Text("매장 위치", 폼 레이블)
      │        └─ Text(
      │            hasLocation
      │              ? "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}"
      │              : "아직 설정되지 않음",
      │            본문,
      │            color: hasLocation ? textDefault : textMuted
      │          )
      └─ TextButton(
           "현재 위치 불러오기",
           onPressed: async {
             위치 권한 확인 → 없으면 PrePermissionDialog 재사용
             허용 → geolocator.getCurrentPosition → 폼 상태에 주입
             거부/실패 → SnackBar
           },
           textColor: primaryBright, w600
         )
```

**재사용 주의:** 기존 `PrePermissionDialog` 와 `CheckLocationPermissionUseCase` 를 그대로 쓴다.

### 4-4. CategoryMultiSelect

```
Column(crossAxisAlignment: start)
  ├─ Row(레이블 + " *")
  ├─ SizedBox(8)
  └─ Wrap(spacing 8, runSpacing 8, children: CategoryChip×12)
```

- `CategoryChip` 스타일은 홈의 `_CategoryChip` 와 동일 (선택 시 primaryBright 배경 + 글로우)
- 최소 1개 제약은 폼 유효성으로만 체크 (선택 0개 → 에러 메시지)

### 4-5. BusinessHoursPicker

MVP — 단일 open/close 구간.

```
Row
  ├─ Expanded: TimeField(label: "영업 시작", value: openTime)
  ├─ Padding(horizontal 8): Text("~", textMuted)
  └─ Expanded: TimeField(label: "영업 종료", value: closeTime)
```

`TimeField`:
```
GestureDetector(onTap: showTimePicker)
  StoreFormField(
    label: label,
    placeholder: "--:--",
    value: formattedTime,
    suffixIcon: Icon(access_time_rounded, 18, textMuted),
    readOnly: true,
  )
```

`showTimePicker` 는 Flutter 기본 사용하되 `Theme(data: Theme.of(context).copyWith(...다크...))` 로 래핑.

### 4-6. 저장 버튼 (bottomSheet)

```
Container
  - color: AppColors.background
  - padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomSafeArea)
  - child: SafeArea(top: false, child: SizedBox(
      height: 52, width: double.infinity,
      child: FilledButton(
        onPressed: formValid && !submitting ? submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,   // 점주 주액션 = Gold
          foregroundColor: AppColors.textDark, // Gold 위 어두운 글자 (대비)
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: submitting
          ? CircularProgressIndicator(color: textDark, size: 20)
          : Text(isEdit ? "수정 완료" : "매장 등록", 저장 버튼 라벨),
      ),
    ))
```

### 4-7. 저장 실패/성공 피드백

- 성공 → Navigator.pop(context) + ScaffoldMessenger(SnackBar, "매장 정보가 저장되었습니다", backgroundColor: AppColors.accent.alpha 0.9)
- 실패 → AlertDialog(AppColors.surfaceElevated) + "재시도" FilledButton

---

## 화면 5: 점주 전환 확인 다이얼로그

`PrePermissionDialog` 와 같은 스타일 가이드:
- 배경: AppColors.surfaceElevated
- 아이콘 컨테이너: 56x56 circle, **accent gradient** ([accent, accent.alpha 0.7])
- 아이콘: `Icons.storefront_rounded`, white, 28
- 제목: "점주로 전환하시겠어요?"
- 본문: "점주로 전환하면 매장을 직접 등록하고 관리할 수 있어요. 언제든 더보기에서 다시 고객 모드로 돌아올 수 있습니다."
- 좌: TextButton "취소" (textMuted)
- 우: FilledButton "점주로 전환" (accent 배경, textDark 글자)

---

## 화면 6: MorePage 점주 전환 섹션 (고객측)

기존 MorePage 상단에 추가:

```
Container
  - margin: EdgeInsets.fromLTRB(20, 16, 20, 24)
  - padding: EdgeInsets.all(16)
  - decoration:
      gradient: LinearGradient([surfaceElevated, surface])
      borderRadius: 16
      border: Border.all(accent.alpha(0.3))
  - child: Row
      ├─ Container(40x40 circle, accent.alpha(0.15))
      │    └─ Icon(storefront_rounded, 20, accent)
      ├─ SizedBox(12)
      ├─ Expanded
      │    └─ Column(crossAxisAlignment: start)
      │        ├─ Text("점주이신가요?", fontSize 15, w700, textDark)
      │        └─ Text("매장을 등록하고 Qrator를 만나보세요", fontSize 12, textMuted)
      └─ Icon(chevron_right, 20, textMuted)
  - onTap: → UpgradeConfirmDialog
```

---

## 화면 7: OwnerMorePage (점주측 더보기)

MVP — 단순 목록.
```
ListTile들:
  - "고객 모드로 전환" (role 을 다시 customer 로)
  - "로그아웃"
  - "앱 정보"
```
각 항목 색상: textDark, subtitle textMuted.

---

## 상태 UI 규약

| 상태 | 화면 |
|------|------|
| `myStoreProvider` 로딩 | StoreHeaderCard 자리에 Shimmer(surfaceElevated baseColor, surface highlightColor, 220h) |
| 저장 중 | 저장 버튼 `CircularProgressIndicator`, 배경 유지 |
| 삭제 확인 | AlertDialog("정말 삭제할까요?" / 되돌릴 수 없음), 삭제 버튼 `Color(0xFFF87171)` |
| 이미지 업로드 실패 | 이미지 타일 테두리 빨간색 + "업로드에 실패했어요, 이미지 없이 저장할까요?" SnackBar + Action "이미지 없이 저장" |

---

## 재사용 자산

| 자산 | 재사용 대상 |
|------|------------|
| `AppColors.*` | 전 영역 |
| `GradeBadge` | `StoreHeaderCard`, `StoreMetricsSection` |
| `_CategoryChip` (홈) | `CategoryMultiSelect` — 동일 위젯화해 분리: `lib/presentation/common/chips/category_chip.dart` 로 승격 권장 |
| `PrePermissionDialog` | `LocationPickerTile` 권한 요청 시 그대로 재사용 |
| `CheckLocationPermissionUseCase` | 동일 |
| `QLogo` | 변경 없음 (점주 화면에선 미사용, 필요 시 AppBar 로고로만) |

---

## 접근성 / 마이크로카피 규약

- **필수 필드 표기:** `*` Gold accent
- **캐릭터 카운터:** 매장명 `12 / 30`, 소개 `48 / 200` — 제한 도달 시 색상 Gold accent
- **버튼 비활성 조건:** 필수 필드 미입력 또는 카테고리 0개
- **다이얼로그 dismiss:** 배경 탭으로 닫히되 "취소" 결과로 해석
- **에러 메시지 톤:** "~~해주세요" (요청형, 나무람 금지) — 예: "매장명을 입력해주세요"

---

## 자율 결정 사항 요약 (사용자 확인 요망)

1. **점주 주액션 색상 = Gold (accent)**: 고객 주액션(primaryBright)과 차별화하되, 브랜드 팔레트 내에서 해결
2. **OwnerBottomNav 4탭 균등**: 중앙 FAB 없음 (점주는 "주문하기" 액션 없음)
3. **매장 삭제는 MVP 포함**: 잘못 등록 시 복구 수단 필요
4. **빈 상태 CTA 카드에 Accent 글로우**: 온보딩 성공률 관점에서 시각 강조
5. **에러 색상은 이번에도 하드코딩(`#F87171`)**: `AppColors.error` 승격은 차기 디자인 PR에서 일괄. 도메인 위반은 아니므로 용인.
6. **주소 검색 API 없음 → 주소 텍스트 직접 입력 + 좌표는 "현재 위치 불러오기"**: 점주가 매장 앞에서 등록한다는 전제. 오프셋 오차는 차기 지도 픽 UI 도입 시 해소.
