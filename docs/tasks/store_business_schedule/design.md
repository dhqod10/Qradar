# store_business_schedule 디자인 명세

매장 영업 스케줄(요일별 영업시간 `weeklyHours` + 특정 날짜 휴무 `closedDates`) UI/UX.

- 작성: designer / 2026-11-02
- 기준: `spec.md` (§0 전부 확정), `temporary_closed_gate/design.md` (패턴 원본), `store_category_optout/design.md`
- 코드 확인: `owner/my_store/store_operation_form_page.dart`, `customer/order/store/widgets/store_menu_header.dart`, `store_menu_page.dart`(`_TemporaryClosedBanner`), `menu/menu_item_detail_page.dart`(`_BottomAction`), `cart/widgets/cart_availability_banner.dart`, `cart/cart_page.dart`(`_onCheckout`), `checkout/payment_failure_copy.dart`
- 색상은 전부 `AppColors` 토큰. 신규 색 토큰 없음.

---

## 0. 사용자/architect 확인이 필요한 결정 (먼저 읽기)

> ✅ **전부 확정 (2026-11-02, 사용자 승인).**
> - **Q1 = 권고 채택**: `businessHours`/`weeklyHours` **미설정(null) = 시간 제한 없음(항상 영업, 게이트 미적용)**. 전체 휴무는 점주가 명시 저장한 빈 맵일 때만. 기존 매장은 **테스트 매장이라 배포 후 수동 후보정**(null=항상영업으로 현상유지 → 안 깨짐).
> - **Q5 = 변경(홈 카드 배지 포함, v1)**: 손님 **홈 카드(`store_card.dart`)에 영업상태 배지** 추가(§3.8 후속안을 v1으로 승격). `StoreOpenState` 재사용 — 영업중/휴업 구분 배지.
> - **Q7 = 신규 매장 등록 시 영업시간/휴무 "필수 입력"**: `store_form_page` 등록 폼에 요일별 스케줄 피커(§1.2~1.4 컴포넌트 재사용)를 **필수 필드**로 추가(기본값·건너뛰기 없음 — 새 매장이 24시간/새벽 주문되는 것 방지). null 미설정은 **기존(테스트) 매장에만** 해당. my_store/관리자 표기는 요약 문자열(§2.5)로 교체.
> - **Q2 / Q3 / Q4 / Q6 = 권고대로.**
> 아래 표는 근거 기록용.

| # | 결정 | 디자이너 권고 | 왜 중요한가 |
|---|---|---|---|
| **Q1** | **`businessHours == null`(스케줄 미설정) 매장의 게이트 거동.** 새 모델은 "요일 엔트리 부재 = 휴무"라서 맵이 비어 있으면 서버가 항상 `STORE_CLOSED_SCHEDULE`(spec §3 D1 "유효 엔트리 없음 → 항상 닫힘")로 거절한다. 지금 `businessHours` 를 한 번도 안 채운 매장(및 24시간 매장)은 배포 즉시 전부 주문 불가가 될 수 있다. | **필드 자체가 `null`(미설정) = 시간 제한 없음(항상 영업, 게이트 미적용)** 으로 구분. "전체 휴무"는 **점주가 명시 저장한 빈 맵**일 때만. 설정 UI에 "스케줄 사용 안 함" 상태를 둔다(§1.2). | 미구분 시 배포 사고. 이건 UI 가 아니라 D1 규칙 변경이므로 **architect/사용자 확인 필수**. 이 문서는 권고안(null = 항상 영업) 기준으로 작성. |
| **Q2** | 진짜 24시간 영업 표현 | `open == close` 는 "닫힘"(spec)이라 불가. UI에서 **저장 차단 + 안내**("24시간 영업은 00:00 ~ 23:59로 설정"). 또는 Q1의 "스케줄 사용 안 함"으로 대체. | 점주가 00:00~00:00 을 넣으면 의도와 반대(휴무)가 됨 |
| **Q3** | 운영폼 저장 방식 | 요청서의 "즉시저장"은 **필드별 자동저장이 아니다.** 기존 운영폼은 로컬 폼 상태 + 하단 `즉시 반영하기` 버튼 1회 저장이다(카테고리 노출도 동일). → **같은 방식**으로 간다(스케줄도 폼 상태, 하단 버튼으로 일괄 저장). 필드별 자동저장은 7행×시간 변경마다 쓰기가 나가고 "전체 휴무 경고/오늘 휴무 안내"를 걸 지점이 없어 부적합. | 일관성 + 경고 다이얼로그를 걸 저장 시점 확보 |
| **Q4** | `closedDates`(특정 날짜)의 손님 표기 | 별도 4번째 상태를 만들지 않고 **"정기 휴무"(휴무일) 로 표기**(점주가 미리 정한 휴무라는 점에서 동일). 배너 문구는 "오늘은 휴무일이에요". | 요청서가 3분류(임시휴업/정기휴무/영업시간 아님)만 지정 |
| **Q5** | 손님 **목록(홈 카드)** 휴업 표시 | **v1 제외 권고.** 현재 홈 카드(`store_card.dart`)는 `임시 휴업중`조차 표시하지 않고(temporary_closed_gate §비범위) 영업상태 자체가 없다. 목록에 시계 의존 칩을 넣으면 카드 전체 재계산 비용·깜빡임이 생긴다. 필요하면 §3.8 의 칩안을 후속으로. | 요청서에 "상세/목록"이 있어 명시 확인 |
| **Q6** | 설정 섹션 순서 변경 | 현재 `영업시간 → 임시 휴업 → 휴무 날짜`. 스케줄 항목끼리 묶기 위해 **`영업 스케줄 → 휴무 날짜 → 임시 휴업`** 으로 이동(임시 휴업에 "스케줄보다 우선" 보조문구 추가). | 사소하지만 기존 화면 순서가 바뀜 |
| **Q7** | 점주 `my_store_page` 의 영업시간 표기 `매일 09:00 ~ 21:00`, 관리자 승인 상세 `_businessHoursText` 는 요일별 모델에서 의미가 깨진다 → **요약 문자열(§2.5)** 로 교체 필요. 매장 **등록 폼**(`store_form_page`)의 단일 구간 피커 처리는 spec 범위 밖이므로 architect 결정 필요. | 연쇄 영향 |

---

## 1. 점주 — 영업 스케줄 설정 (`StoreOperationFormPage` 내부)

### 1.0 위치 / 저장 모델

- 화면: 기존 `운영 정보` 폼(`store_operation_form_page.dart`). entry: 점주 `내 매장` → 운영 정보 수정 (role_flows owner "매장 운영 정보 수정"). 신규 라우트 없음.
- 기존 `_BusinessHoursPicker`(단일 구간) 를 **`_WeeklyScheduleCard`** 로 교체. `_ClosedDatesEditor` 는 유지·개선(§1.5).
- 저장: **기존 하단 `_SubmitBar` "즉시 반영하기" 1개로 일괄 저장**(Q3). 상단 `_InstantNoticeBanner`("아래 정보는 저장 즉시 반영돼요.") 그대로. 스케줄 카드 자체에는 로컬 상태만 있다.
- 신규 컴포넌트는 최소: `_WeeklyScheduleCard`(+`_DayRow`, `_CopyDaysSheet`), 기존 `_TimeTile`·`_ClosedDatesEditor`·`_DateChip` 재사용/확장. developer 가 등록 폼 재사용을 원하면 `lib/presentation/owner/my_store/widgets/` 로 추출(권고, 필수 아님).

### 1.1 섹션 순서 (Q6)

```
_InstantNoticeBanner
이미지 / 전화번호
_WeeklyScheduleCard      ← 신규 (구 영업시간 피커 자리)
_ClosedDatesEditor       ← 개선
_TemporaryClosedToggle   ← 보조문구 1줄 추가
_CategoryExposureSection
(설명/공지 …)
_SubmitBar
```
섹션 간 간격 20 (기존). 스케줄 카드와 휴무 날짜 카드 사이는 12 (같은 군).

### 1.2 `_WeeklyScheduleCard` 구조

카드 공통: 배경 `AppColors.surfaceElevated`, border `AppColors.border` 1px, radius 12 (`_TemporaryClosedToggle`/`_ClosedDatesEditor` 와 동일), padding 16.

```
Card
├─ Header Row: Icon(access_time_rounded 18, textHeading) + 8 + "영업 스케줄" (14/w600 textHeading)
├─ Sub (4 위): "요일마다 영업 시간을 다르게 정할 수 있어요. 시간이 없는 요일은 휴무예요." (12, textMuted)
├─ gap 12
├─ [상태별 본문]  ← A/B/C
├─ gap 12
├─ Summary 줄 (§1.6)
└─ (전체 휴무일 때) 경고 박스 (§2.1)
```

**상태별 본문**

- **A. 미설정(`hours == null`, Q1)** — 7행 대신 안내:
  - 박스: 배경 `AppColors.surface` radius 12 padding 14, Icon `Icons.all_inclusive_rounded` 18 `AppColors.textMuted` + 문구 (13, `AppColors.textBody`) "영업 스케줄이 없어요. 지금은 시간 제한 없이 주문을 받아요."
  - 그 아래 gap 12, 풀폭 라인 버튼 "영업 스케줄 설정하기" (높이 44, 배경 `surfaceElevated`, border `AppColors.border`, 텍스트 14/w600 `AppColors.primary`, radius 12). 탭 → B 로 전환, 기본값 **월~금 09:00–18:00 영업, 토·일 휴무**(점주가 바로 고칠 출발점. 0행으로 시작하면 "전체 휴무" 경고가 즉시 떠서 혼란).
- **B. 설정됨 — 평일 묶음 모드 (기본)**: 행 3개 `평일(월~금)` / `토` / `일` (§1.3). 하단에 `요일별로 따로 설정` 텍스트 버튼.
- **C. 설정됨 — 요일별 모드**: 행 7개 `월 … 일`. 하단 `평일 묶어서 보기` 텍스트 버튼.
- 카드 우측 상단(헤더 우측) 작은 텍스트 버튼 `스케줄 사용 안 함`(12, `AppColors.textMuted`, 탭영역 높이 44 확보) — 설정됨(B/C) 상태에서만. 탭 → 확인 다이얼로그(§2.4) 후 `hours = null`(A 로).

**모드 결정(초기)**: B/C 는 파생 UI 상태 `_grouped`. 초기값 = 월~금 5요일의 상태(영업 여부+open+close)가 모두 같으면 `true`, 하나라도 다르면 `false`(요일별). 토/일은 항상 개별.

**모드 전환**
- B→C `요일별로 따로 설정`: 월~금 5행으로 펼침(값은 평일 값 복제), 애니메이션 `AnimatedSize` 200ms `Curves.easeOut`.
- C→B `평일 묶어서 보기`: 월~금이 **모두 같으면** 즉시 접음. **다르면** 확인 다이얼로그 "월~금을 같은 시간으로 맞출까요?" / 본문 "지금 요일마다 다른 시간이 월요일 기준 시간으로 바뀌어요." / [취소][맞추기]. 맞추기 → 월요일 값을 월~금에 적용.
  (사용자가 다르게 해 둔 값을 말없이 덮지 않기 위함.)

### 1.3 `_DayRow` — 요일 행

높이 **min 64**(세로 padding 10), 행 사이 구분선 1px `AppColors.border` (카드 padding 안쪽 가로 전체). 마지막 행 아래 구분선 없음.

```
Row(crossAxisAlignment: center)
├─ DayLabel  (width 48; 평일 묶음은 2줄: "평일" 15/w700 + "월~금" 11 textMuted; 개별은 "월" 15/w700 textHeading)
├─ gap 8
├─ Expanded: [영업일] Row[_TimeTile(시작) , "~" , _TimeTile(종료)]   |   [휴무] Text("휴무", 14/w500, textMuted)
├─ gap 8
└─ Switch (영업 ON / 휴무 OFF)
```

- **토글 의미**: Switch ON = 영업, OFF = 휴무. 스위치 옆 별도 라벨은 없고, **OFF 일 때 시간 칸이 "휴무" 텍스트로 대체**되어 상태가 읽힌다. `activeThumbColor: AppColors.onPrimary`, `activeTrackColor: AppColors.primary`, `inactiveTrackColor: AppColors.surface`, `inactiveThumbColor: AppColors.textMuted`. (임시 휴업 스위치는 `AppColors.error` 로 "켜면 닫힘"이라 의미가 반대 → 색으로 구분됨.) Semantics: "월요일 영업 켜짐/꺼짐(휴무)".
- 평일 묶음 행의 스위치는 월~금 전체를 한 번에 켜고/끈다.
- 휴무 행(OFF) 은 시간 칸 대신 텍스트라서 행 높이가 줄지 않게 min 64 유지.
- 휴무→영업 전환 시 값: 그 행이 마지막으로 가졌던 시간이 있으면 복원, 없으면 **09:00 ~ 18:00**.
- **복사**는 행 아이콘이 아니라 카드 하단 단일 버튼 `다른 요일에 복사`(§1.4)로 제공한다(360dp 에서 행 폭 확보). 휴무 상태도 복사 원본이 될 수 있다.

**`_TimeTile` (재사용·compact 변형)**
- 기존 `_TimeTile`(라벨+값, 높이 약 62) 은 7행에 너무 크다. **compact 변형**: 높이 **44**, 라벨 없음, 값만 중앙(15/w600 `AppColors.textHeading`), 배경 `AppColors.surface`(카드 안이라 `surfaceElevated` 가 아닌 surface), radius 10, 아이콘 없음, 가로 padding 8.
- 360dp 가용폭: 360 −40(페이지 padding) −32(카드 padding) −48(요일) −8 −8 −52(스위치) −16(`~`) ≈ 156 → 시간 칸 각 ≈ 78. 15sp `09:00` 은 약 40dp 라 충분(`익일` 접두 포함 시에도 수용).
- 탭 → `showTimePicker`: 기존 `_pick` 재사용하되 **테마 수정**: 기존 코드는 `ColorScheme.dark(...)` 를 쓰고 있어 밝은 캔버스 앱에서 다크 피커가 뜬다. → `ColorScheme.light(primary: AppColors.primary, onPrimary: AppColors.onPrimary, surface: AppColors.surfaceElevated, onSurface: AppColors.textHeading)`. 24시간 표기: `MediaQuery(data: ... alwaysUse24HourFormat: true)` 로 감싼다. 초기값 = 현재 값, 없으면 09:00(시작)/18:00(종료).
- 값 표시 `HH:mm` 24시 (spec 저장 포맷 일치).

**자정 넘김(심야영업) 표현**
- `close < open`(예 22:00 ~ 02:00) 이면:
  - 종료 칸 값 앞에 작은 접두 **`익일`**(10/w600, `AppColors.primaryBright`) + `02:00`.
  - 행 아래(구분선 위) 한 줄 힌트: `Icons.nightlight_round` 12 `primaryBright` + "다음날 02:00까지 영업해요" (11, `AppColors.textMuted`). 행 높이 +18.
- 판단은 입력 직후 즉시(별도 토글 없음 — spec "open>close = 자정넘김" 그대로). 첫 심야 입력 시 1회성 안내 없음(힌트 줄로 충분).
- 소속 요일 규칙: "새벽 구간은 영업을 시작한 요일 소속"(spec §D1). 힌트 줄 문구가 "다음날"을 명시하므로 별도 설명 불필요. 요약(§1.6)에서도 `22:00–익일 02:00`.
- `open == close`: 종료 칸에 border 1px `AppColors.error`, 행 아래 에러 줄 `Icons.error_outline_rounded` 12 `error` + "시작과 종료 시간이 같아요 (24시간 영업은 00:00 ~ 23:59)" (11, `AppColors.error`). **저장 차단**(Q2): 저장 탭 시 SnackBar "영업시간을 확인해 주세요" + 첫 오류 행으로 스크롤.

### 1.4 일괄/복사 편의 (확정 UX: 평일 일괄 적용)

1. **평일 묶음 모드(기본, §1.2-B)** — 핵심. 평일 1행만 고치면 월~금 5일 동시 적용. 5번 찍을 필요 없음. 토·일만 개별.
2. **`다른 요일에 복사`**: 카드 하단 좌측 텍스트 버튼(아이콘 `Icons.content_copy_outlined` 16 + 라벨 13/w600 `AppColors.primary`, 높이 44). 탭 → **바텀시트** `_CopyDaysSheet`:
   - 시트: 배경 `AppColors.surfaceElevated`, 상단 radius 20, padding 20, 핸들 바 40×4 `AppColors.border`.
   - 제목 "어떤 요일의 시간을 복사할까요?" (16/w700). 요일 선택 칩 7개 단일선택(원본, 선택 시 `primary`/`onPrimary` pill) 아래에 부제 "대상 요일" 다중선택 칩 7개(선택 시 `primary` 배경, 비선택 `surfaceElevated`+border; 원본 요일은 비활성 `textMuted`). 칩 높이 40, 간격 8, Wrap.
   - 빠른 선택 칩 `평일` `주말` `모든 요일`(대상 일괄 선택 단축).
   - 하단 `적용` 버튼 (높이 52 `primary`/`onPrimary` radius 14), 대상 0개면 비활성(`surfaceElevated`/`textMuted`). 적용 시 원본의 영업/휴무 상태와 시간을 대상에 복사, 시트 닫힘, SnackBar 없음(행이 바로 바뀌는 게 피드백).
   - 평일 묶음 모드 중 대상에 월~금 일부만 선택해 복사 → 5일이 달라지므로 모드가 자동으로 C(요일별)로 전환(값이 같으면 B 유지).
3. 모드 B 에서 **토/일을 평일과 같게**: 평일 행이 원본인 복사 시트에서 `주말` 빠른 선택 → 적용.

### 1.5 `_ClosedDatesEditor` (특정 날짜 휴무) 개선

기존 구조(카드, 헤더 `휴무 날짜`, 칩 Wrap, `휴무 날짜 추가` 텍스트 버튼) 유지하고 다음만 변경:

- 헤더 문구 `휴무 날짜` → **`특정 날짜 휴무`**, 보조 `공휴일·임시 휴무처럼 하루만 쉬는 날을 추가해 주세요. 요일별 스케줄보다 우선해요.`
- 칩 라벨 `2026-11-24` → **`11월 24일 (화)`** (요일 포함, 점주가 요일 실수 확인). 연도가 올해와 다르면 `2027년 1월 1일 (금)`.
- 칩 규격: 높이 36, padding 가로 12, radius 8, 배경 `AppColors.background`, border `AppColors.border`, 텍스트 13/w500 `AppColors.textHeading`. 삭제 `X` 아이콘 16 `textMuted`, **터치 영역 40×36**(기존 14dp 아이콘만 탭 가능한 문제 개선). 삭제는 즉시(확인 없음 — 저장 전까지 폼 상태일 뿐이고 되돌리려면 재추가).
- **오늘** 날짜 칩: 오른쪽에 `오늘` 미니 태그(10/w700, `onPrimary` on `primary`, pill 높이 16, padding 6)로 현재 영향 표시.
- **지난 날짜**: 칩 텍스트 `textMuted` + `지남` 태그(10, `textMuted` on `surface`). 정렬은 오름차순, 지난 날짜는 목록 끝으로 분리. 지난 날짜가 1개 이상이면 카드 우측 상단 텍스트 버튼 `지난 날짜 정리`(12, `textMuted`)로 일괄 삭제(선택 기능, spec §2.2 "UI 정리 선택").
- 날짜 선택: 기존 `_addClosedDate` 의 `showDatePicker` 사용, `firstDate = 오늘`, `lastDate = 오늘+1년`, 테마 `ColorScheme.light(primary: AppColors.primary, onPrimary: AppColors.onPrimary, surface: AppColors.surfaceElevated, onSurface: AppColors.textHeading)`. 중복이면 기존 SnackBar "이미 추가된 날짜예요".
- empty: 기존 문구 유지 `추가된 휴무 날짜가 없어요.` (12, italic → italic 제거 권고, `textMuted`).
- 하단 `+ 휴무 날짜 추가` 텍스트 버튼 유지(색 `AppColors.primary`).

### 1.6 요약 줄 (Summary) — "저장하면 이렇게 보여요"

카드 본문 아래, 배경 `AppColors.surface` radius 10 padding 12: 첫 줄 라벨 `손님에게 보이는 영업시간`(11, `textMuted`), 아래에 같은 포맷터로 만든 문자열(13/w600, `textHeading`): `월~금 09:00–21:00 · 토 09:00–15:00 · 일 휴무`.
- 같은 값이 연속한 요일은 `월~금`, 비연속은 `월·수·금` 로 묶는다. 휴무는 `일 휴무` / `월·화 휴무`. 자정넘김 `금·토 22:00–익일 02:00`.
- 이 포맷터(`BusinessScheduleSummary.format(weeklyHours)`)는 §2.5 와 손님 상세 영업시간 시트에서 **공용**(순수 함수, domain/core 에 한 곳).
- 행 변경 즉시 실시간 갱신.

### 1.7 저장 시 흐름·다이얼로그

저장 탭 순서(`_submit` 확장):
1. 기존 카테고리 전부 OFF 확인 다이얼로그가 필요하면 그것 먼저(기존).
2. **스케줄 검증**: open==close 행 있으면 SnackBar + 스크롤, 중단(§1.3).
3. **전체 휴무 확인 다이얼로그**(§2.1)가 필요하면 표시. 취소하면 폼 유지.
4. **"오늘 영업 종료" 안내**(§2.3)가 필요하면 표시(전체 휴무 다이얼로그와 겹치면 하나로 합침).
5. 저장 중 상태(§2.6) → 성공 SnackBar `즉시 반영되었습니다`(기존).

---

## 2. 상태 / 경고 UI

### 2.1 전체 휴무 경고

조건: 설정됨(B/C)이고 **7요일 모두 휴무**(`weeklyHours` 비어 있음). `closedDates` 는 무관.

**인라인(실시간)** — 카드 맨 아래, 요약 줄 바로 아래 gap 8:
- 컨테이너: 배경 `AppColors.warning.withValues(alpha: 0.08)`, border `AppColors.warning.withValues(alpha: 0.35)` 1px, radius 12, padding 12×14 (`CartAvailabilityBanner` 와 동일 톤).
- Row: `Icons.warning_amber_rounded` 18 `AppColors.warning` + 8 + Column: 제목 "모든 요일이 휴무예요" (13/w600 `textHeading`), 본문 "이대로 저장하면 매장이 영구 휴업 상태가 돼요. 손님은 주문할 수 없어요." (12, `textBody`).
- 요약 줄은 `모든 요일 휴무` 로 표기.
- 저장 버튼은 **막지 않는다**(spec: 막지 않고 경고).

**저장 시 확인 다이얼로그** (`_confirmAllOff` AlertDialog 스타일 재사용: 배경 `surfaceElevated`, radius 16):
- 제목 "매장이 영구 휴업 상태가 돼요" (16/w700 `textHeading`)
- 본문 "모든 요일이 휴무라서 손님이 이 매장에서 주문할 수 없어요. 요일별 영업시간을 다시 켜기 전까지 계속돼요. 그래도 저장할까요?" (13, height 1.5, `textBody`)
- 버튼: `돌아가기`(autofocus, `textMuted`), `그래도 저장`(`AppColors.error`, w700).
- 이미 전부 휴무로 저장돼 있고 그대로면 생략(기존 `wasAllOff` 규칙과 동일, 반복 경고 방지).

### 2.2 임시 휴업과의 관계 안내 (정보)

`_TemporaryClosedToggle` 본문에 한 줄 추가: "임시 휴업은 영업 스케줄보다 우선해요." (12, `textMuted`, 기존 설명 아래). 진행 중 주문 가드 문구는 그대로.

### 2.3 진행 중 주문이 있는데 오늘/지금을 휴무로 바꿀 때 (차단 아님, 안내)

spec D0-6-4: 가드·차단 없음. **저장 직전 확인 안내**만:
- 트리거: 저장 전 `isStoreOpenNow(기존)=true` 이고 `isStoreOpenNow(변경 후)=false`(= 이번 저장으로 "지금부터" 닫힘). 요일 휴무 전환, 영업시간 단축, 오늘 날짜 `closedDates` 추가 모두 포함. 이미 닫힌 상태에서 내일 휴무 지정 등은 해당 없음.
- 활성 주문 수 조회: 기존 `countActiveStoreOrdersUseCaseProvider` 재사용. **조회 실패는 숫자 없이 같은 안내 표시**(막지 않음).
- 다이얼로그: 제목 "지금부터 새 주문을 받지 않아요" (16/w700) / 본문 
  - n>0: "이미 받은 주문 {n}건은 그대로 진행돼요. 새 주문만 받지 않아요."
  - n==0 또는 조회 실패: "저장하면 바로 새 주문을 받지 않아요."
  - 공통 보조: "자동으로 취소되는 주문은 없어요." 
- 버튼: `돌아가기`(`textMuted`), `저장하기`(`primary`, w700). 활성 주문이 없고 닫히기만 한다면 이 다이얼로그는 **n==0 일 때 생략**(불필요한 마찰 방지). → 즉 **n>0 이거나 조회 실패일 때만** 표시.
- 전체 휴무 다이얼로그(§2.1)와 동시 해당: 하나의 다이얼로그에 본문 마지막 줄로 "이미 받은 주문 {n}건은 그대로 진행돼요." 를 덧붙인다.

### 2.4 `스케줄 사용 안 함` 확인 (Q1)

AlertDialog: 제목 "시간 제한 없이 주문을 받을까요?" / 본문 "영업 스케줄을 지우면 영업시간과 관계없이 항상 주문을 받아요. 특정 날짜 휴무는 그대로 유지돼요." / [취소][지우기(`error`)]. 확인 → A 상태. (특정 날짜 휴무는 `weeklyHours == null` 이어도 별도 게이트 입력이므로 유지 — architect/developer 규칙 확인 필요: `weeklyHours` 가 null 이어도 `closedDates` 일치 시 닫힘으로 둘지. **권고: 닫힘 유지**.)

### 2.5 다른 점주/관리자 화면의 영업시간 표기

- `my_store_page.dart` `_StoreInfoSection`: `매일 09:00 ~ 21:00` → 요약 포맷터 문자열(§1.6)을 같은 `_InfoRow`(아이콘 `access_time_rounded`)에. 길면 줄바꿈 허용(maxLines 3). 미설정이면 "영업시간 제한 없음".
- 관리자 승인 상세 `_businessHoursText`: 동일 포맷터 사용. `-` 는 미설정일 때 "미설정".

### 2.6 저장 중 / 실패

- 저장 중: `_submitting=true`. 기존 `_SubmitBar` 스피너(20×20, `onPrimary`, strokeWidth 2) + 버튼 비활성. 스케줄/휴무 날짜 카드는 `IgnorePointer` + `Opacity 0.6`(편집 불가 표시). 카테고리 섹션의 `enabled: !_submitting` 와 같은 규칙.
- 실패: 기존 `showErrorDialog('저장에 실패했어요. 다시 시도해주세요')`. 폼 상태 유지(입력 보존), `_submitting=false`.
- loading(초기): 스케줄 카드는 `widget.existing` 로 동기 초기화 → 별도 로딩 없음.
- empty: 미설정(A) 상태와 `closedDates` 비어 있음이 empty. 문구는 각각 §1.2-A, §1.5.
- 접근성: 모든 터치 영역 최소 44dp(시간 칸 44 높이, 스위치 기본, 칩 삭제 40×36 → 가로 40 허용). 요일 행 Semantics "월요일, 영업, 09:00부터 21:00까지".

---

## 3. 손님 — 휴업 상태 UI

### 3.0 상태 모델 (presentation 파생 값)

한 곳(`StoreOpenState`, 순수)에서 계산하고 모든 화면이 공유한다. 입력: `store.temporaryClosed`, `weeklyHours`, `closedDates`, 현재 KST 시각(`isStoreOpenNow` 와 같은 요일/분/날짜키 주입 — spec §D1 규칙을 그대로 쓰며 UI는 여기에 `수치`만 추가로 파생).

| 상태 | 조건 (우선순위 위→아래) | 배지 | 주문 |
|---|---|---|---|
| `temporarilyClosed` | `temporaryClosed == true` | `임시 휴업중` (기존 error pill) | 차단 |
| `regularHoliday` | 오늘 요일 엔트리 없음 또는 오늘 ∈ `closedDates` (자정 넘김 영업 중인 어제 구간 제외) | `정기 휴무` | 차단 |
| `outsideHours` | 오늘 엔트리는 있으나 지금이 영업 구간 밖 | `영업시간 아님` | 차단 |
| `open` | 그 외 | `영업 중` (기존 텍스트) | 허용 |
| `unknown` | `weeklyHours == null` (Q1 미설정) | 표시 없음(기존 `SizedBox.shrink`) | 허용 |

(승인 실패 `STORE_NOT_SELLABLE` 은 본 UI 범위 밖 — 기존 처리.)
부가 파생: `nextOpenAt`(다음 영업 시작 시각, 오늘 이후 최대 8일 탐색, `closedDates` 반영, 못 찾으면 null), `todayRange`(오늘 영업 구간 문자열), `closeAt`(영업 중일 때 오늘 종료 시각).

**시각 갱신**: 화면이 켜져 있는 동안 영업 시작/종료 시각을 넘으면 상태가 바뀌어야 한다. `storeOpenStateProvider(store)` 는 **다음 경계 시각(다음 분 정렬)에 갱신**하는 타이머를 가진다(분 단위, 화면 dispose 시 취소, 앱 resume 시 즉시 재계산). 기기 시계는 표시/선검증용(권위 아님, spec D0-3).

**`nextOpenAt` 표기 포맷** (`formatNextOpen`):
- 오늘 이후(같은 날): `오늘 18:00`
- 내일: `내일(수) 09:00`
- 그 외: `11/9(월) 09:00` 
- null: 문구 생략.

### 3.1 매장 상세 헤더 (`store_menu_header.dart`) — `_OpenStatusText` 변경

현재: `if (store.temporaryClosed) _TemporaryClosedBadge else _OpenStatusText(hours)`; `_OpenStatusText` 는 단일 구간 `openTime/closeTime` 으로 "영업 중/마감"만 그림(주문 영향 없음). 변경:

- `_OpenStatusText` 는 **`_StoreOpenStatus(state)`** 로 대체(요일별 맵 + closedDates 기준). 자체 시간 계산(`_isOpenNow`/`_toMinutes`)은 **삭제**하고 공용 `StoreOpenState` 를 쓴다(한 사실에 하나).
- 분기:
  - `temporarilyClosed` → 기존 `_TemporaryClosedBadge` **그대로**(높이 22, `AppColors.error` 배경, "임시 휴업중").
  - `regularHoliday` / `outsideHours` → 신규 `_ScheduleClosedBadge`:
    - 높이 22, 가로 padding 8, radius 11(기존 배지와 동일 규격), **배경 `AppColors.textHeading.withValues(alpha: 0.72)`**, border 1px `AppColors.onPrimary.withValues(alpha: 0.35)`, 텍스트 12/w700 `AppColors.onPrimary`, 라벨 `정기 휴무` / `영업시간 아님`.
    - **임시 휴업(빨강)과 색으로 구분**: 빨강 = 점주의 즉시 휴업(비정상), 중립 어두운 pill = 정해진 스케줄상 닫힘(정상). 사진 위 가독성을 위해 배경 반투명 어둡게.
    - Semantics: `정기 휴무 중인 매장` / `지금은 영업시간이 아닌 매장`.
  - `open` → 텍스트 `영업 중`(13/w600, `AppColors.success` — **기존 유지**). 뒤에 `closeAt` 이 있으면 ` · 21:00까지`(13/w500, `AppColors.onPrimary` alpha 0.85) 를 같은 Text.rich 에 이어 붙임. 좁으면 `Flexible`+ellipsis 로 `· 21:00까지` 부분이 먼저 잘리게 한다. 심야 구간이면 `· 익일 02:00까지`.
  - `unknown` → `SizedBox.shrink`.
- 기존 `마감`(빨강 텍스트) 표기는 폐지 — 닫힘은 배지로 통일(영업 중이 아닐 때 텍스트 하나가 아니라 pill 로 눈에 띄게).
- 헤더 줄 폭(360dp): 거리(약 64) + 12 + 배지(약 80) + Spacer + `_TappableGradeBadge`(약 90). 가로 여유 충분. `영업 중 · 21:00까지` 는 ≈110 → 세 요소 합이 넘으면 위 Flexible 규칙으로 흡수.

### 3.2 안내 배너 (`store_menu_page.dart`)

현재 `if (liveStore.temporaryClosed) SliverToBoxAdapter(_TemporaryClosedBanner)`. 변경: 상태에 따라 **배너 1개만**(임시 휴업 > 스케줄).

- 임시 휴업 → 기존 `_TemporaryClosedBanner` **불변**.
- `regularHoliday`/`outsideHours` → 신규 `_ScheduleClosedBanner` (같은 위치·마진 `fromLTRB(16,12,16,0)`, padding 12×14, radius 12, 탭 없음):
  - 배경 `AppColors.surface`, border 1px `AppColors.border` (오류가 아닌 중립 톤. 임시 휴업의 error 톤과 대비).
  - Row: `Icons.schedule_rounded` 18 `AppColors.primary` + 8 + Column
    - 제목 13/w600 `textHeading`
    - 본문 12 `textBody` (gap 2)
  - 문구:

| 상태 | 제목 | 본문 |
|---|---|---|
| `outsideHours` (영업 전, 오늘 이후 시작) | "지금은 영업시간이 아니에요" | "오늘 {todayRange}에 영업해요. 메뉴는 볼 수 있지만 주문은 영업시간에 할 수 있어요." |
| `outsideHours` (오늘 영업 종료 후) | "오늘 영업이 끝났어요" | "다음 영업: {nextOpenAt}. 메뉴는 볼 수 있지만 주문은 영업을 시작한 뒤에 할 수 있어요." |
| `regularHoliday` | "오늘은 휴무일이에요" | "다음 영업: {nextOpenAt}. 메뉴는 볼 수 있지만 주문은 영업일에 할 수 있어요." |

  - `nextOpenAt == null`(다음 영업일 없음 = 전체 휴무 등): 본문 "메뉴는 볼 수 있지만 지금은 주문을 받지 않아요."
- 메뉴 카드(`menu_item_card.dart`)는 임시 휴업과 동일하게 **변경 없음**: 탭해서 상세 둘러보기 허용, 품절 딤 금지(곧 열리는 상태라 구경은 허용).

### 3.3 주문 차단 — 메뉴 상세 하단 (`_BottomAction`)

`closed`(임시 휴업) 판정을 **`closedKind`**(없음/임시/휴무/영업시간아님)로 확장. 판정 순서: **① 임시 휴업 ② 정기 휴무/영업시간 아님 ③ soldOut ④ `_busy` ⑤ required 미선택** (매장 단위 닫힘이 메뉴 단위 품절보다 우선 — temporary_closed_gate 결정 승계).
- 버튼 `onPressed: null`, 배경/글자 = 품절과 동일 비활성(`AppColors.surface` / `AppColors.textMuted`), 합계 금액색 `AppColors.textMuted`.
- 라벨(16/w700): `임시 휴업중` / `오늘은 휴무일이에요` / `지금은 영업시간이 아니에요`. (정기 휴무·영업시간 아님은 버튼 안에서 이유가 읽히도록 전체 문장.)
- **다음 영업 안내 줄**: 스케줄 닫힘일 때만 `합계` Row 위에 한 줄 gap 8 추가: `Icons.schedule_rounded` 14 `textMuted` + "다음 영업 {nextOpenAt}" (12, `AppColors.textMuted`). `nextOpenAt==null` 이면 줄 생략. 임시 휴업은 줄 없음.
- 토스트/스낵바 없음(라벨이 이유를 말함 — 기존 규칙).
- 옵션 영역 조작은 그대로 허용(둘러보기). `_onAddPressed` 시작부에 `closedKind != 없음` 이면 **조용히 return**(경쟁 상태 방어).
- 시간 경과로 영업이 시작되면 §3.0 타이머로 버튼이 **자동 활성화**(토스트 없음).

### 3.4 카트 (`cart_availability_banner.dart`, `cart_page.dart`)

카트는 닫혀 있어도 진입 허용(담긴 카트 보존), **결제 시점에 막는다**(temporary_closed_gate §2-2 승계).

- `CartBannerVariant.storeClosedSchedule` **1개 추가**(임시 휴업 variant 와 별도, 레이아웃/색(`warning` 톤)·"다시 확인" 버튼 동일). 정기 휴무/영업시간 아님을 구분하지 않고 **한 문구**(카트에선 행동 유도가 같음):
  - title: **"지금은 매장이 문을 닫았어요"**
  - body: **"다음 영업: {nextOpenAt}. 영업을 시작하면 '다시 확인'을 눌러 결제할 수 있어요. 카트는 그대로 남아 있어요."** (`nextOpenAt==null` 이면 "다음 영업: …. " 문장 생략)
- `_onCheckout` 스낵바: `StoreViolation.closedSchedule` → **"지금은 매장 영업시간이 아니에요. 영업을 시작하면 결제할 수 있어요."** (지속 2초·`clearSnackBars` 불변). 선검증 우선순위는 임시 휴업 > 스케줄(기존 temporarilyClosed 분기 앞에 스케줄 분기 추가가 아니라 `notSellable/temporarilyClosed/closedSchedule/notFound` 각각 매핑).
- 결제하기 버튼: 기존처럼 활성 상태 유지 후 탭 시 선검증 스낵바 방식(카트 버튼을 비활성으로 바꾸지 않음 — 기존 임시 휴업과 동일 UX; 선검증은 권위가 아니라서).

### 3.5 결제 실패 화면 (`payment_failure_copy.dart`)

`PaymentFailureReason.storeClosedSchedule` case 추가(switch 가 컴파일 오류로 누락 알림). 레이아웃·버튼 구조는 `storeTemporarilyClosed` 와 동일(갈래 B, `kGateMoneyLine` "아직 결제되지 않았고, 요금도 청구되지 않았어요" 자동 노출).

```
headline: 지금은 매장 영업시간이 아니에요
body: 영업시간이 아니거나 휴무일이라 주문을 받을 수 없어요. 결제하는 사이 영업이 끝났을 수도 있어요. 영업을 시작한 뒤 다시 결제해 주세요. 카트는 그대로 남아 있어요.
primaryLabel: 카트로 돌아가기   primaryAction: popToCart
secondaryLabel: 다른 매장 둘러보기   secondaryAction: browseStores
(subBody / listHeader 없음)
```
- 서버는 사유를 1개로 묶어 보내므로 이 화면은 **정기 휴무/영업시간 아님을 구분하지 않는다**(구분은 매장 상세·카트에서). 서버 문자열 보간 금지(기존 원칙) — 다음 영업 시각도 넣지 않음(결제 실패 화면에서 매장 데이터 비동기 조회는 불필요한 의존).
- 임시 휴업 copy 와 headline 이 달라 점주 조치(재개 대기)와 스케줄(시간 경과)을 구분.

### 3.6 상태 UI 요약 (손님)

| 상태 | 처리 |
|---|---|
| loading (매장 정보 로딩 중) | 기존 매장 상세 스켈레톤 그대로. 상태 불명이면 `unknown`(표시 없음, 막지 않음) |
| error (매장 읽기 실패) | 기존 처리. 선검증은 막지 않음(서버 백스톱) |
| empty (스케줄 미설정) | 표시 없음 = 항상 영업 취급(Q1) |
| 시계 드리프트 | 표시만 어긋날 수 있음. 서버 거절 시 §3.5 화면이 최종 안내 |

### 3.7 홈 카드 등 목록 (Q5, v1 제외 권고)

후속으로 하게 되면: `NearbyStoreCard`/`RecommendedStoreCard` 이미지 좌하단에 높이 20 pill(배경 `AppColors.textHeading` alpha 0.72, `onPrimary` 11/w700 `영업 종료`/`휴무`), 임시 휴업(`error`)도 함께 노출해야 일관. 카드 리스트 전체에 분 단위 타이머를 거는 대신 화면 진입/resume 시점 1회 계산. → 사용자 확인 후 별도 작업.

---

## 4. 인터랙션 요약

| 동작 | 반응 |
|---|---|
| 요일 시간 칸 탭 | 24시간제 시간 피커(밝은 테마) → 값 반영, 요약 줄 갱신 |
| 요일 스위치 | 영업↔휴무. 휴무→영업은 이전 값 복원/기본 09:00–18:00 |
| 평일 행 편집 | 월~금 동시 적용 |
| `요일별로 따로 설정` / `평일 묶어서 보기` | 행 펼침/접기(200ms). 접을 때 값이 다르면 확인 |
| `다른 요일에 복사` | 바텀시트 → 원본·대상 선택 → 적용 |
| `+ 휴무 날짜 추가` | 날짜 피커(오늘~+1년), 중복 시 스낵바 |
| 날짜 칩 X | 즉시 삭제(폼 상태) |
| 저장 탭 | 검증 → (전체 휴무/오늘 영업 종료 안내) → 저장 중 → 성공 스낵바 / 실패 다이얼로그 |
| 손님: 메뉴 상세 담기 버튼(휴업) | 비활성, 라벨+다음 영업 안내 |
| 손님: 카트 결제하기(휴업) | 선검증 스낵바 + 카트 배너 |

---

## 5. Figma / 기존안 대비 변경

| 항목 | 기존 | 변경 |
|---|---|---|
| 영업시간 피커 | 단일 구간 2칸 (`매일`) | 요일별 행 + 평일 묶음 + 복사 |
| 시간 피커 테마 | `ColorScheme.dark` (밝은 앱에서 다크) | `ColorScheme.light` + 24h (기존 버그성 불일치 수정) |
| 휴무 날짜 칩 | `yyyy-MM-dd`, 14dp X | `M월 d일 (요일)`, 삭제 터치 확대, 오늘/지남 태그 |
| 헤더 영업 표시 | 텍스트 `영업 중`/`마감`(주문 무영향) | 배지(임시/정기휴무/영업시간 아님) + 텍스트 `영업 중 · HH:mm까지`, **주문 게이트와 일치** |
| 헤더 계산 | 헤더 내부 로컬 계산 | 공용 `StoreOpenState` (한 곳) |
| 휴업 배너 | 임시 휴업만 | 스케줄 닫힘 배너 추가(중립 톤) |

---

## 6. 개발자 전달 특이사항

1. **Q1 선결**: 미설정(null) vs 전체 휴무(빈 맵) 구분을 domain 모델·서버 `isStoreOpenNow` 규칙과 맞춘 뒤 UI 구현. 이 문서 §1.2-A/§2.4/§3.0 `unknown` 이 그 전제다.
2. 색상은 모두 `AppColors`. 반투명은 기존 패턴 `AppColors.xxx.withValues(alpha: …)` 만(`Color(0x…)`/`Colors.white` 금지).
3. **신규 위젯**: `_WeeklyScheduleCard`, `_DayRow`, `_CopyDaysSheet`, `_ScheduleClosedBadge`, `_ScheduleClosedBanner` 과 순수 `StoreOpenState`/`formatNextOpen`/`BusinessScheduleSummary.format`. 나머지는 기존 위젯(`_TimeTile` compact 변형 포함) 확장·재사용.
4. `StoreOpenState` 계산은 `store_sellability.dart` 의 `isStoreOpenNow` 와 **동일 규칙**(자정 넘김의 전일 구간 포함)을 써야 한다. UI 전용 중복 구현 금지 → 공용 함수가 요일/분/날짜키 주입 방식이므로 거기에 `nextOpenAt`/`closeAt` 계산을 같은 모듈(순수 Dart)에 두고 골든 테스트 대상에 포함 권고(tester).
5. 분 단위 갱신 타이머(§3.0)는 화면 dispose 시 취소, 앱 resume 시 재계산. 타이머 없이 build 시점 1회 계산이면 영업 시작 후에도 버튼이 비활성으로 남는 문제가 생긴다.
6. 폼 `_hours` 상태는 `Map<int, (open,close)?>` 와 `_grouped` UI 플래그. `_grouped` 는 저장하지 않는다(파생).
7. 저장 경로·권한은 기존 `UpdateStoreOperationFieldsUseCase`(운영 필드, status 무변동) 그대로. 활성 주문 수 조회(§2.3)는 **안내용 읽기**이며 실패해도 저장을 막지 않는다.
8. 접근성: 요일 행/스위치/배지 Semantics 라벨 지정(각 절 참고).
9. 후속 분리: 홈 카드 영업 칩(Q5), 등록 폼 재사용(Q7), 공휴일 자동 휴무(spec 비범위), 24시간 영업 전용 토글(Q2 — 필요 시 "스케줄 사용 안 함"으로 대체).
