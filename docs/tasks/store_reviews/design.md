# 매장 평가 (store_reviews) 디자인 명세

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-10-22 | designer | 최초 작성. spec §12 D1~D6 / A1~A5 확정값 전제. 재논의 없음 |

---

## 참조한 디자인

- spec: `docs/tasks/store_reviews/spec.md` (§4 스키마, §5.3 화면 목록, §5.4 진입 판정, §6.3 상한 50, §12 확정)
- Figma: 없음
- 도메인: `lib/domain/entities/store_grade.dart` — `StoreGrade.label`("S급"), `StoreGradeColor.color` (S=`accent`, A=`primaryBright`, B=`primaryLight`, C=`textMuted`)
- 기존 위젯: `GradeBadge`(navy 단일 pill, 사용처 6개 위치/5개 파일), `OrderStatusBadge`, `_ActionSection`(info 안내 카드 패턴: surface + border + radius 12), `my_store_page._Metric`
- 직전 작업 톤: `docs/tasks/owner_sales/design.md` (카드 = surfaceElevated + border + radius 16, static skeleton, Icon + 제목 + 보조문구 빈 상태)
- 역할 흐름: `docs/processes/role_flows.md`. 작성 진입은 customer `Log → OrderDetailPage` 단일 (A4). 조회 진입은 customer `StoreMenuPage` 헤더, owner `MyStorePage` 지표 행. 모두 `Navigator.push(MaterialPageRoute)` 풀스크린 (신규 탭/라우트 없음)

---

## 핵심 디자인 결정 (요약)

| # | 결정 | 사유 |
|---|---|---|
| 1 | 등급 선택은 **세로 4장의 선택 카드(라디오 리스트)**. 세그먼트/칩 기각 | 등급마다 **의미 문구 1줄**이 필요하다. 세그먼트/칩은 글자 한 자만 담을 수 있어 "고르기 전에 기준을 안다" 를 충족하지 못한다. 4장이 같은 크기·같은 구조 = 동등한 선택지. 가로 4분할은 문구가 들어갈 폭이 없다 |
| 2 | **별(★) 아이콘·채워진 별 메타포 전면 금지.** 등급은 "글자 타일(S/A/B/C)" 로 표현 | 몇 점이 아니라 어느 등급인가. 점수 누적이 아닌 **분류** 로 읽혀야 한다 |
| 3 | **선택 전 4장은 전부 중립색**(타일 `surface`, 글자 `textMuted`). 등급 색은 **선택된 카드의 타일에만** 입힌다 | 선택 전부터 금색 S 가 시선을 끌면 S 로 쏠린다(프라이밍). 처음엔 4장이 정확히 같은 무게여야 한다 |
| 4 | **선택된 카드의 강조(테두리·체크)는 등급과 무관하게 항상 `primary`**. 등급 색은 타일만 | S 를 고를 때와 C 를 고를 때 카드가 **똑같이 단정하게** 선택된다. C 를 골라도 "경고/실패" 처럼 보이지 않는다 |
| 5 | **빨강/초록 사용 안 함.** 등급 색은 `StoreGradeColor.color` 를 **그대로** 따른다 (금/하늘/슬레이트/회색) | 기존 도메인 색이 이미 비-신호등 계열이다. C = `textMuted` 회색은 "나쁨" 이 아니라 "차분한 최하단" 으로 읽힌다. 새 색 불필요 |
| 6 | **기본 선택 없음.** 진입 시 4장 모두 미선택, 저장 버튼 비활성 (수정 모드는 기존 값 프리필) | 기본값이 S 면 앵커링으로 평가가 부풀려진다. 의도적으로 한 번 눌러야 저장된다 |
| 7 | 등급 의미 문구는 **감정이 아니라 재방문·추천 기준**으로 서술, C 도 비난 어조 금지 | "별로예요/나빠요" 는 C 선택을 도덕적 행위로 만든다. "기대에 못 미쳤어요" 는 사실 진술이라 솔직한 선택이 쉬워진다 |
| 8 | 폼 안에 **"솔직한 평가가 다른 Qrator 에게 가장 도움이 돼요"** 안내 1줄 | 솔직함을 명시적으로 허락. 등급 신뢰도 = 제품 가치 |
| 9 | 리뷰 카드 / 선택 카드의 등급 타일만 등급 색, **`GradeBadge`(집계)는 navy 단일 유지** | 집계 배지는 "매장의 등급", 타일은 "한 사람의 한 표". 가이드의 "등급 배지는 색 대신 텍스트" 원칙은 `GradeBadge` 에 그대로 유지하고, 개인 표 타일의 색은 기존 `StoreGradeColor` 재사용(신규 토큰 0) |
| 10 | `미평가` 는 navy 채움이 아니라 **`surface` 채움 + `textBody` 글자** 의 약한 pill | 등급이 아직 없다는 사실이 시각적으로도 "등급 배지보다 약해야" 한다. 5개 사용처 모두에서 폭이 기존 `C급 (-)` 보다 **좁아** 레이아웃 회귀 위험이 구조적으로 없다 |
| 11 | 리뷰 목록에서 **내 평가는 목록 최상단에 분리 노출**(`watchMyReview`), 일반 목록에서는 제외 | 내 평가 확인이 이 화면의 가장 흔한 목적. 50건 밖에 있어도 항상 보인다 |
| 12 | 목록에는 **수정 버튼을 두지 않는다.** 수정 진입은 `order_detail_page` 단일 | A4(확정) 우선. spec §11-4 의 "수정 진입" 과 충돌하나 A4 가 확정이므로 따름. 목록에서 수정하려면 14일 판정용 주문 조회가 추가로 필요하다 (잔여 결정 Q1) |
| 13 | 지연 반영 안내는 **저장 직후 스낵바 1회 + 목록 요약 카드의 불일치 감지 캡션** | 스낵바만으로는 목록 화면에서 헤더와 목록이 어긋난 이유를 설명할 수 없다. 낙관적 덮어쓰기는 하지 않음(확정) |
| 14 | **새 색상 토큰 0개**, 별(★)·`Icons.star*` 0개 | 전부 기존 `AppColors` / `StoreGradeColor` |

---

## 공통 규칙

### 등급 타일 (`GradeTile`) — 신규 소형 위젯

선택 카드와 리뷰 카드가 공유하는 정사각 글자 타일. **파일: `customer/review/widgets/grade_tile.dart`**

| 속성 | 값 |
|---|---|
| 크기 | `size` 파라미터. 선택 카드 40, 리뷰 카드 28 |
| radius | 선택 카드 12, 리뷰 카드 8 |
| 글자 | `grade.asString` (S/A/B/C 한 글자). 선택 카드 20 / w800, 리뷰 카드 14 / w800 |
| `neutral: true` | 배경 `AppColors.surface`, 글자 `AppColors.textMuted` (선택 전 상태) |
| `neutral: false` | 배경 `grade.color`, 글자는 아래 표 |

등급 색 위 글자색 (대비 확보. **`Color(0x...)` 금지, 토큰만**):

| 등급 | 배경 | 글자 | 대비(참고) |
|---|---|---|---|
| S | `AppColors.accent` | `AppColors.textHeading` | 약 12:1 |
| A | `AppColors.primaryBright` | `AppColors.textHeading` | 약 8:1 |
| B | `AppColors.primaryLight` | `AppColors.onPrimary` | 약 10:1 |
| C | `AppColors.textMuted` | `AppColors.onPrimary` | 약 4.8:1 |

> `onPrimary` 를 금/하늘 위에 쓰면 대비가 1.5~2:1 로 읽히지 않는다. 그래서 S/A 만 `textHeading` 을 쓴다. 이 매핑은 `GradeTile` 내부 `switch` 한 곳에만 둔다.

### 등급 의미 문구 (선택 카드 · 단일 진실원)

| 등급 | 이름(굵게) | 설명(1줄) |
|---|---|---|
| S | `최고예요` | `다시 찾고, 주변에 먼저 추천하고 싶은 매장이에요` |
| A | `좋아요` | `만족스러웠고 또 방문할 의향이 있어요` |
| B | `보통이에요` | `무난했지만 아쉬운 점도 있었어요` |
| C | `아쉬워요` | `기대에 못 미쳤고 개선이 필요해요` |

- 기준 판단 축은 폼 상단 안내에서 한 번만 제시: `음료·서비스·분위기를 종합해서 골라주세요`
- 이 문구는 **선택 카드 전용**. 리뷰 목록의 카드에는 이름만(`최고예요`) 보조로 붙이지 않고 `S급` 글자만 둔다 (목록은 스캔이 목적, §리뷰 카드)

### 날짜 표기 (리뷰 카드 공통)

| 경과 | 표기 |
|---|---|
| 1분 미만 | `방금 전` |
| 1시간 미만 | `N분 전` |
| 24시간 미만 | `N시간 전` |
| 7일 미만 | `N일 전` |
| 7일 이상 | `yyyy.MM.dd` (`intl` DateFormat) |
| `updatedAt != null` | 위 표기 뒤에 ` · 수정됨` |

기준 시각은 `updatedAt ?? createdAt`. 단 "수정됨" 은 `updatedAt != null` 일 때만.

### 작성자 표기

- 타인: `Qrator {uid 앞 4자}` (예: `Qrator a3f9`). 소문자 그대로, 대문자 변환 금지 (식별 일관성)
- 내 평가: `내 평가` pill + 같은 줄에 `Qrator a3f9`
- 폼 하단 고지(§화면 1): 이 표기가 **점주를 포함해 공개** 됨을 저장 전에 알린다

---

## 화면 1. 평가 작성/수정 폼 — `StoreReviewFormPage`

(`customer/review/store_review_form_page.dart`, 작성/수정 겸용)

### 진입 인자

`storeId`, `storeName`, `orderId` (진입한 주문), `existingReview` (`ReviewEntity?`, 수정이면 non-null)

### 레이아웃

```
┌───────────────────────────────────┐
│ ←          매장 평가              │  AppBar (수정 모드: "평가 수정")
├───────────────────────────────────┤
│ 이 매장에 대한 내 평가   (12 muted)│  h20, top 16
│ 카페 모카포트            (20/w800) │  storeName, maxLines 2
│                                   │
│ [수정 모드 + orderId 다름일 때]    │
│ ┌ ⓘ 다른 주문으로 남긴 평가예요 … ┐ │  info 카드
│                                   │
│ 음료·서비스·분위기를 종합해서      │  13 textBody
│ 골라주세요                         │
│ ┌ [S] 최고예요            ○ ┐     │  선택 카드 ×4, gap 10
│ │     다시 찾고, 주변에 …      │     │
│ └─────────────────────────────┘     │
│ ┌ [A] 좋아요              ○ ┐     │
│ ┌ [B] 보통이에요          ○ ┐     │
│ ┌ [C] 아쉬워요            ○ ┐     │
│                                   │
│ 한마디 남기기 (선택)      (14/w700)│
│ ┌ TextField (4~6줄)           ┐   │
│ └                      0/300  ┘   │
│                                   │
│ 솔직한 평가가 다른 Qrator 에게     │  안내 (12 muted, 아이콘 없음)
│ 가장 도움이 돼요                   │
│ 평가는 'Qrator a3f9' 로 익명 공개되며│
│ 매장 점주도 볼 수 있어요           │
├───────────────────────────────────┤
│ [        평가 등록        ]       │  하단 고정 버튼 영역
└───────────────────────────────────┘
```

- Scaffold `backgroundColor: AppColors.background`. AppBar: `backgroundColor: AppColors.background`, `elevation: 0`, 제목 20 / w700 / `textHeading`, 뒤로가기 아이콘 `textHeading`
- 본문: `SingleChildScrollView`, 좌우 padding 20, bottom padding 24. `keyboardDismissBehavior: onDrag`. 키보드가 올라와도 하단 버튼이 가려지지 않도록 버튼 영역은 `bottomNavigationBar` 가 아니라 `Scaffold.bottomNavigationBar` + `resizeToAvoidBottomInset: true` (키보드 위로 따라 올라옴)
- 섹션 간격: 헤더 → 안내 문구 16, 안내 문구 → 첫 카드 12, 카드 gap 10, 마지막 카드 → 코멘트 라벨 28, 라벨 → 입력창 8, 입력창 → 안내 16
- 헤더: 라벨 `이 매장에 대한 내 평가` (12 / w500 / `textMuted`), 아래 4px 후 매장명 (20 / w800 / `textHeading`). 작성/수정 모두 동일 (spec §5.4: 다른 주문에서 와도 "매장 기준" 임을 명시)

### 컴포넌트 1. `GradeSelector` (`customer/review/widgets/grade_selector.dart`, 신규)

- 역할: 4개 등급 중 **정확히 하나** 선택. 값 `StoreGrade?`, 콜백 `ValueChanged<StoreGrade>`
- 위젯 구조: `Column` (gap 10) × 4 `GradeOptionCard`. S → A → B → C 순서 고정 (뱃지·도메인 순서와 동일, 재배열/랜덤화 금지)
- 그룹 시맨틱: 전체를 `Semantics(container: true, label: '등급 선택')` 로 감싼다

**`GradeOptionCard` (같은 파일 private 위젯)**

| 속성 | 값 |
|---|---|
| 높이 | min 72 (설명이 2줄로 줄바꿈되면 늘어남). 터치 영역 전체 카드 |
| padding | 가로 16 / 세로 14 |
| radius | 16 |
| 구조 | `Row[ GradeTile(40), gap 14, Expanded(Column[이름, gap 2, 설명]), gap 12, 선택 인디케이터 ]` |
| 이름 | 16 / w700 / `textHeading` |
| 설명 | 13 / w400 / `textMuted`, height 1.4, 줄바꿈 허용(maxLines 제한 없음) |
| 인디케이터 | 22px 아이콘 |

상태:

| 상태 | 배경 | border | 타일 | 인디케이터 |
|---|---|---|---|---|
| 미선택 | `surfaceElevated` | `border` 1px | `neutral: true` | `Icons.radio_button_unchecked_rounded` / `textMuted` |
| 선택 | `surfaceElevated` | **`primary` 2px** (등급과 무관) | `neutral: false` (등급 색) | `Icons.check_circle_rounded` / `primary` |
| 눌림(pressed) | `surface` | 상태 유지 | 상태 유지 | 상태 유지 |
| 비활성(제출 중) | 불투명도 유지, 탭만 무시 | — | — | — |

- 선택 전환 애니메이션: `AnimatedContainer` 150ms `Curves.easeOut` (border·타일 색). 크기 변화 없음. 레이아웃이 border 두께 변화로 1px 튀지 않도록 미선택에도 **투명 1px 여백을 두거나** border 를 항상 2px 로 그리되 미선택은 `border` 색 1px + padding 보정 (developer 가 택일, 시각적으로 카드가 움직이지 않으면 됨)
- 선택은 **색에만 의존하지 않는다**: 인디케이터 아이콘 형태(빈 원 ↔ 체크 원) + border 두께(1 ↔ 2)가 함께 바뀐다
- 햅틱: 선택 시 `HapticFeedback.selectionClick()` (선택사항)
- 선택 해제 불가 (라디오). 이미 선택된 카드를 다시 탭해도 변화 없음

**접근성 (스크린리더)**

각 카드를 `Semantics(inMutuallyExclusiveGroup: true, checked: isSelected, button: true, label: ...)` 로 감싸고 내부 자식은 `ExcludeSemantics`.

| 등급 | semantics label (읽히는 문구) |
|---|---|
| S | `S급, 최고예요. 다시 찾고, 주변에 먼저 추천하고 싶은 매장이에요. 4개 중 1번째` |
| A | `A급, 좋아요. 만족스러웠고 또 방문할 의향이 있어요. 4개 중 2번째` |
| B | `B급, 보통이에요. 무난했지만 아쉬운 점도 있었어요. 4개 중 3번째` |
| C | `C급, 아쉬워요. 기대에 못 미쳤고 개선이 필요해요. 4개 중 4번째` |

- 선택 여부는 `checked`(라디오 상태)로 전달 — 스크린리더가 "선택됨/선택 안 됨" 을 읽는다. 라벨 문구 안에 "선택됨" 을 직접 넣지 않는다 (중복 낭독 방지)
- 선택 변경 시 `SemanticsService.announce('{S급} 선택됨')` 불필요 (checked 상태 변화로 충분)
- 포커스 순서: 안내 문구 → S → A → B → C → 코멘트 → 저장 버튼
- 최소 터치 영역 48 이상 충족 (카드 min 72)

### 컴포넌트 2. 코멘트 입력창

- 라벨 행: `한마디 남기기` (14 / w700 / `textHeading`) + 공백 + `(선택)` (13 / w400 / `textMuted`)
- `TextField`: `minLines: 4`, `maxLines: 6`, `maxLength: 300` (`LengthLimitingTextInputFormatter(300)` — 초과 입력은 **조용히 막는다**, 에러 표시 없음), `keyboardType: TextInputType.multiline`, `textInputAction: TextInputAction.newline`, `textCapitalization: sentences`
- 기본 `counterText: ''` 로 내장 카운터를 숨기고 **커스텀 카운터**를 입력창 우하단 바깥에 둔다: `{현재}/300`, 12 / w400 / `textMuted`. 280자 이상이면 `textHeading` / w600 으로 승격 (색 대신 굵기로 신호, warning 글자색은 흰 배경 대비 부족)
- 스타일: 채움 `AppColors.surfaceElevated`, border `AppColors.border` 1px, radius 12, contentPadding 14, 텍스트 14 / `textBody` / height 1.5, cursor `AppColors.primary`, 포커스 border `AppColors.primary` 1.5px
- hint: `방문하면서 느낀 점을 자유롭게 남겨주세요` (14 / `textMuted`)
- 공백만 입력한 코멘트는 저장 시 `trim()` 후 빈 문자열이면 **`comment` 필드 자체를 보내지 않는다** (developer 전달사항)
- 접근성: `Semantics(label: '한마디 남기기, 선택 입력, 최대 300자')`, 카운터는 `ExcludeSemantics` 하고 TextField 의 `maxLength` 시맨틱에 위임

### 컴포넌트 3. 안내 블록 (입력창 아래)

- 두 줄, 아이콘 없음, 12 / w400 / `textMuted`, height 1.5, 줄 간격 4
  1. `솔직한 평가가 다른 Qrator 에게 가장 도움이 돼요`
  2. `평가는 'Qrator {uid 앞 4자}' 로 익명 공개되며, 매장 점주도 볼 수 있어요`
- 2번째 줄의 `{uid 앞 4자}` 는 **실제 내 코드로 치환**해서 보여준다 (예: `Qrator a3f9`). 사용자가 자신이 어떻게 보일지 저장 전에 확인할 수 있어야 한다

### 컴포넌트 4. 다른 주문 평가 안내 카드 (조건부)

- 표시 조건: `existingReview != null && existingReview.orderId != 현재 orderId`
- 스타일: `OrderDetailPage` 의 `info_outline` 안내 카드 패턴 그대로 — 배경 `surface`, border `border`, radius 12, padding 가로 16 / 세로 12, 아이콘 `Icons.info_outline_rounded` 18 `info`, 글자 13 / `textMuted`
- 문구: `이전에 남긴 평가가 있어요. 저장하면 이번 주문 기준으로 바뀌어요`
- 위치: 헤더 아래, 안내 문구 위. 아래 간격 16

### 컴포넌트 5. 하단 저장 버튼 영역

- 컨테이너: 배경 `AppColors.background`, 상단 `border` 1px, padding `fromLTRB(20, 12, 20, 12 + safeArea.bottom)`
- 버튼: 가로 full, 높이 52, radius 12

| 상태 | 라벨 | 스타일 |
|---|---|---|
| 작성 · 등급 미선택 | `평가 등록` | 비활성: 배경 `surface`, 글자 `textMuted` |
| 작성 · 등급 선택됨 | `평가 등록` | 배경 `primary`, 글자 `onPrimary` (16 / w700) |
| 수정 · 변경 없음(등급·코멘트 동일) | `수정 완료` | 비활성 (위와 동일) |
| 수정 · 변경 있음 | `수정 완료` | 활성 |
| 제출 중 | 라벨 대신 스피너 | 배경 `primary`, `CircularProgressIndicator(strokeWidth 2, 18px, onPrimary)`. 탭 무시. 선택 카드·입력창도 입력 잠금 |

- 비활성 버튼의 접근성: `Semantics(button: true, enabled: false, hint: '등급을 먼저 선택해 주세요')` — 작성 모드에서만 hint 제공
- 제출 중 뒤로가기: `PopScope(canPop: !isSubmitting)`

### 인터랙션

| 동작 | 반응 |
|---|---|
| 등급 카드 탭 | 해당 카드 선택, 다른 카드 해제, 저장 버튼 활성화 |
| 코멘트 입력 | 카운터 갱신. 300자 도달 시 추가 입력 무시 |
| 저장 성공 | 폼 `pop` → 호출한 `order_detail_page` 로 복귀 + 스낵바(아래) |
| 저장 실패 | 폼 유지, 입력값 유지, 스낵바(아래) |
| 뒤로가기 / 스와이프 백 | **변경이 있을 때만** 확인 다이얼로그 (아래). 변경 없으면 즉시 pop |
| 이미 만료된 상태로 저장 | 저장 시점에 14일 재검증 → 실패 스낵바 |

**이탈 확인 다이얼로그** (변경 있음: 작성은 "등급 선택 또는 코멘트 입력됨", 수정은 "기존 값과 다름")

- 형태: 기존 `_CancelOrderDialog` 와 동일 (`AlertDialog`, 배경 `surfaceElevated`, radius 16, 버튼 2개 height 46 radius 10)
- 제목 `작성 중인 평가를 그만둘까요?` (18 / w700 / `textHeading`)
- 본문 `나가면 입력한 내용이 사라져요` (14 / `textBody`)
- 좌 `계속 작성` (Outlined: 배경 `surfaceElevated`, border `border`, 글자 `textBody`) / 우 `나가기` (Elevated: 배경 `primary`, 글자 `onPrimary`) — **파괴적 액션이어도 error 색 쓰지 않음** (평가 폐기는 위험 동작이 아니다)

### 스낵바 문구 (전체)

| 상황 | 문구 | 비고 |
|---|---|---|
| 작성 성공 | `평가가 등록됐어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요` | 표시 위치: 복귀한 `order_detail_page`. duration 4초 |
| 수정 성공 | `평가를 수정했어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요` | 동일 |
| 저장 실패(일반) | `평가를 저장하지 못했어요. 잠시 후 다시 시도해 주세요` | 폼 유지 |
| 저장 실패(권한/자격 — `permission-denied`) | `이 주문으로는 평가할 수 없어요` | 폼 유지 |
| 저장 실패(14일 초과) | `평가 기간이 지나 저장할 수 없어요` | 폼 유지 |
| 저장 실패(네트워크) | `네트워크 연결을 확인해 주세요` | 폼 유지 |

- 스낵바 스타일은 앱 기본 `SnackBar` 를 따른다(`menu_item_detail_page` 와 동일 사용법). 별도 색 지정 없음
- spec §3.4 문구 `평가가 등급에 반영되기까지 잠시 걸릴 수 있어요` 를 **등록/수정 결과 문장과 결합**해 한 줄로 만들었다 (스낵바 2개 연속 방지)

### 상태별 UI (폼)

- **Loading (기존 평가 프리필 대기)**: 수정 모드 판정을 위해 `watchMyReview` 첫 값 대기 중에는 `existingReview` 를 모른다. 이 구간은 폼 본문 대신 선택 카드 4장 높이(72)와 코멘트 입력창 높이의 **static skeleton** (`AppColors.surface` 라운드 박스, radius 16)을 표시하고 저장 버튼은 비활성. 진입 인자로 `existingReview` 를 `order_detail_page` 가 이미 갖고 있으므로 **그 값을 넘겨 로딩 구간 자체를 없애는 것이 기본** (developer 전달사항 참조)
- **Error (프리필 로드 실패)**: 폼 대신 중앙 에러 블록(아래 공통 에러 블록). `다시 시도` → provider invalidate
- **Empty**: 해당 없음

---

## 화면 2. 매장 리뷰 목록 — `StoreReviewsPage` (고객) / `OwnerStoreReviewsPage` (점주)

두 화면은 **본문을 공유**한다. 신규 공용 위젯 `StoreReviewsView` (`customer/review/widgets/store_reviews_view.dart`)를 만들고, 고객·점주 페이지는 AppBar 와 파라미터만 다르다. 점주 쪽 파일(`owner/reviews/owner_store_reviews_page.dart`)은 이 위젯을 import 한다 (presentation 내부 의존이며 레이어 위반 아님).

### 파라미터 차이

| 항목 | 고객 `StoreReviewsPage` | 점주 `OwnerStoreReviewsPage` |
|---|---|---|
| AppBar 제목 | `매장 평가` | `받은 평가` |
| 입력 | `store` (이름/등급/평균/건수) | 동일 (`myStoreProvider` 의 store) |
| 내 평가 섹션 | 표시 (`watchMyReview`) | **없음** (`showMine: false`) |
| 빈 상태 문구 | 고객용 | 점주용 |
| 답글/신고/삭제 UI | 없음 | **없음** (R3/R4 는 2차) |

### 레이아웃

```
┌───────────────────────────────────┐
│ ←          매장 평가              │  AppBar
├───────────────────────────────────┤
│ ┌ 요약 카드 ─────────────────────┐ │
│ │ 카페 모카포트          (14 muted)│ │
│ │ A급              (32/w800)      │ │   0건이면 "미평가"
│ │ Qrator 평가 128개 · 평균 3.2 / 4 │ │
│ │ [등급 반영 안내 캡션 - 조건부]    │ │
│ └─────────────────────────────────┘ │
│                                   │
│ 내 평가                  (14/w700) │  고객 + myReview 있을 때만
│ ┌ 리뷰 카드(내 것) ──────────────┐ │
│ └─────────────────────────────────┘ │
│                                   │
│ 전체 평가 128개          (14/w700) │
│ ┌ 리뷰 카드 ─────────────────────┐ │
│ ┌ 리뷰 카드 ─────────────────────┐ │
│ ...                                │
│ 최근 50개 평가를 보여드려요 (12)    │  list.length >= 50
└───────────────────────────────────┘
```

- Scaffold `backgroundColor: AppColors.background`. AppBar 는 폼과 동일 스타일
- 본문: `ListView`, padding `fromLTRB(16, 12, 16, 32)`. pull-to-refresh 없음 (stream 이라 불필요)
- 섹션 제목 행: 위 24 / 아래 8, 14 / w700 / `textHeading`. 첫 섹션(요약 카드) 직후 간격 24

### 컴포넌트 1. 요약 카드 (`ReviewSummaryCard`, 신규, 같은 파일 private)

- 배경 `surfaceElevated`, border `border` 1px, radius 16, shadow `primary` alpha 0.04 (blur 12, offset 0,4), padding 20
- 구성 (위→아래, `crossAxisAlignment: start`):
  1. 매장명 — 13 / w500 / `textMuted`, maxLines 1 ellipsis
  2. gap 6
  3. 등급 — `grade.label` (32 / w800 / `textHeading`). **`reviewCount == 0` 이면 `미평가`** (32 / w800 / `textMuted`)
  4. gap 8
  5. 보조줄 — `Qrator 평가 {N}개 · 평균 {x.x} / 4` (13 / w400 / `textBody`). `x.x` = `averageScore.toStringAsFixed(1)`. 0건이면 보조줄 = `아직 평가가 없어요` (13 / `textMuted`)
- **등급 반영 안내 캡션 (조건부)**
  - 조건: `리스트 길이 < 50` 이고 `리스트 길이(내 평가 포함 합산) != store.reviewCount`
  - 위치: 보조줄 아래 gap 10, 상단 `border` 1px 구분선 + padding top 10
  - 구성: `Icons.schedule_rounded` 14 `textMuted` + gap 6 + 12 / `textMuted`
  - 문구: `방금 남긴 평가는 등급에 곧 반영돼요`
  - 목적: 리뷰 목록은 즉시, 요약은 CF 지연(수초) 이라 어긋난 순간만 설명. 일치하면 자동으로 사라진다. 판정 불가(≥50) 인 경우 표시하지 않는다
  - 접근성: 요약 카드 전체를 `Semantics(label: ...)` 로 묶어 한 번에 낭독
    - 일반: `{매장명}, {A급}, Qrator 평가 {128}개, 평균 {3.2}점 만점 4점`
    - 0건: `{매장명}, 아직 평가가 없는 매장`

> 요약 카드의 **등급 글자는 `GradeBadge` 와 달리 큰 텍스트**이며 navy 채움 pill 이 아니다. 같은 정보를 두 번(AppBar 아래 배지 + 카드) 그리지 않기 위해 카드에 배지를 넣지 않는다.

### 컴포넌트 2. 리뷰 카드 (`ReviewCard`, 신규 `customer/review/widgets/review_card.dart`)

- 역할: 한 Qrator 의 한 표. 읽기 전용
- 컨테이너: 배경 `surfaceElevated`, border `border` 1px, radius 16, padding 16, 카드 간 gap 10
- 구조:

```
Row[ GradeTile(28), gap 10,
     Expanded(Column[ Row[작성자, (내 평가 pill)], 날짜 ]),
   ]
(코멘트가 있을 때만) gap 12
Text(comment)
```

| 요소 | 스타일 |
|---|---|
| 등급 타일 | `GradeTile(size 28, neutral false)` — 등급 색 |
| 작성자 | `Qrator a3f9` — 13 / w600 / `textHeading` |
| 날짜 | §날짜 표기 규칙 — 12 / w400 / `textMuted`, 작성자 아래 2px |
| 코멘트 | 14 / w400 / `textBody`, height 1.5, **전체 표시(말줄임 없음)** — 최대 300자라 카드 높이가 폭주하지 않음 |

- 코멘트 없는 평가(등급만): 헤더 행만 있는 컴팩트 카드. "코멘트 없음" 같은 문구를 **넣지 않는다** (등급만 남기는 것이 정상 사용)
- **내 평가 카드** 변형 (`isMine: true`): border `AppColors.primary` 1.5px (배경 동일), 작성자 줄 끝에 `내 평가` pill — 배경 `primary`, 글자 `onPrimary` 11 / w700, padding 가로 8 세로 3, radius 999. **수정 버튼 없음** (결정 12)
- 접근성: 카드 하나를 `Semantics(label)` 로 병합. 내용: `{내 평가, }S급, Qrator a3f9, {3일 전}, {코멘트 본문}`. 코멘트 없으면 본문 생략
- 점주 화면 카드는 `isMine` 항상 false

### 컴포넌트 3. 섹션 구성 규칙

| 섹션 | 표시 조건 | 내용 |
|---|---|---|
| 요약 카드 | 항상 (로딩 중엔 skeleton) | — |
| `내 평가` | 고객 + `myReview != null` | 내 카드 1장 (변형) |
| `전체 평가 {N}개` | 목록 비어있지 않음 | 일반 카드들. **내 평가는 여기서 제외**. `{N}` = `store.reviewCount` |
| 50개 안내 | `list.length >= 50` | 목록 끝 중앙 `최근 50개 평가를 보여드려요` (12 / `textMuted`, padding top 16) |

> `전체 평가 {N}개` 의 N 은 CF 집계값이라 방금 쓴 평가 직후엔 내 카드 + 목록이 N 보다 많아 보일 수 있다 — 이 불일치는 위 요약 캡션이 설명한다. 내 평가만 있는 경우(내 평가 1건, 목록에서 제외 후 0건)는 `전체 평가` 섹션 제목과 목록을 **숨긴다**.

### 상태별 UI (목록)

#### Loading

- 요약 카드 skeleton: 카드 외곽(`surfaceElevated` + `border` + radius 16, padding 20) 안에 `surface` 라운드 박스 3줄 (폭 90/140/200, 높이 13/32/13, 간격 6/8, radius 6)
- 카드 skeleton ×3: 외곽 동일(padding 16) + 헤더 (`surface` 원형 28 radius 8 + 박스 2줄 폭 100/60) + 본문 박스 2줄 (폭 full/70%, 높이 13)
- **static skeleton** (owner_sales 와 동일, shimmer 애니메이션 없음). 패키지 `shimmer` 를 이미 쓰는 화면과의 통일이 필요하면 base `surface` / highlight `surfaceElevated` 로 교체 가능하나 기본은 static
- `Semantics(label: '평가를 불러오는 중')` 1개로 병합, 나머지 `ExcludeSemantics`

#### Error

- 중앙 정렬 Column, padding 32
- 아이콘 `Icons.error_outline_rounded` 48 / `AppColors.error`
- gap 12 → 제목 `평가를 불러오지 못했어요` (16 / w700 / `textHeading`)
- gap 6 → 설명 `네트워크 연결을 확인하고 다시 시도해 주세요` (13 / `textMuted`, 가운데)
- gap 20 → 버튼 `다시 시도` (배경 `primary`, 글자 `onPrimary`, 높이 44, 가로 padding 24, radius 12) → stream provider invalidate
- 요약 카드는 **에러 시에도 상단에 유지** (store 값은 이미 전달받음). 목록 영역만 에러 블록으로 대체

#### Empty (리뷰 0건)

- 요약 카드는 `미평가` 상태로 표시
- 목록 영역 중앙: 아이콘 `Icons.rate_review_outlined` 48 / `AppColors.textMuted` (**별 아이콘 금지**)

| | 고객 | 점주 |
|---|---|---|
| 제목 (16 / w700 / `textBody`) | `아직 평가가 없어요` | `아직 받은 평가가 없어요` |
| 설명 (13 / `textMuted`, 가운데, height 1.5) | `주문을 완료한 뒤 Log 에서 이 매장을 평가할 수 있어요` | `손님이 주문을 완료하고 평가를 남기면 여기에 표시돼요` |

- 고객 Empty 에 CTA 버튼은 두지 않는다 (평가 진입은 order_detail 단일, A4)
- 단, 고객 + 내 평가만 있고 일반 목록이 비는 경우(= 내 평가 1건뿐)는 Empty 가 아니다: `내 평가` 섹션만 표시

---

## 화면 3. 진입점 3곳

### 3-1. `order_detail_page` — `completed` 분기 (작성 진입)

현재 `_ActionSection` 은 `completed / cancelled / refunded` 를 `"완료된 주문입니다"` 회색 박스 하나로 처리한다. **`completed` 만 분리**하고 `cancelled` / `refunded` 는 **기존 그대로** 둔다.

- 상태 라벨은 화면 상단 `OrderStatusBadge` 가 이미 `완료` 를 전달하므로 `완료된 주문입니다` 문구는 `completed` 에서 제거한다 (중복)
- 위젯: `_ReviewActionCard` (같은 파일 private, 또는 `customer/review/widgets/order_review_action.dart`). 입력: `order`, `myReview` (`AsyncValue<ReviewEntity?>`)
- 판정 (spec §5.4): `expired = order.completedAt != null && now - order.completedAt > 14일`. `completedAt == null` 이면 만료 아님·카운트다운 없음

공통 카드 스타일: 배경 `surfaceElevated`, border `border` 1px, radius 16, padding 16, width full. 카드 안 세로 gap 12.

#### 상태 A — 평가 전 (`myReview == null`, 기한 내)

```
┌───────────────────────────────────┐
│ 이 매장은 어땠나요?      (16/w700) │
│ Qrator 의 평가가 매장 등급을       │  13 muted
│ 만들어요                           │
│ [     매장 평가하기      ]         │  Filled, h48
│ (D-3 이내) 3일 후 평가 기간이 끝나요│  12 muted
└───────────────────────────────────┘
```

- 버튼: 높이 48, full, radius 12, 배경 `primary`, 글자 `onPrimary` 15 / w700, 라벨 `매장 평가하기`. 탭 → `StoreReviewFormPage(existingReview: null)`
- 카운트다운 캡션은 `completedAt != null` 이고 남은 일수 ≤ 3 일 때만 (아래 표). 버튼 아래 gap 8, 가운데 정렬

| 남은 기간 | 캡션 |
|---|---|
| 24시간 이내 | `오늘까지 평가할 수 있어요` |
| 1~3일 | `{N}일 후 평가 기간이 끝나요` |
| 4일 이상 | 표시 안 함 |

#### 상태 B — 평가 후 (`myReview != null`, 기한 내)

```
┌───────────────────────────────────┐
│ 이 매장에 남긴 내 평가   (13 muted)│
│ [S]  S급 · 최고예요     (15/w700)  │  GradeTile 28 + 텍스트
│ "커피가 정말 맛있어요…"  (14, 2줄) │  코멘트 있을 때만
│ [      평가 수정      ]           │  Outlined, h48
└───────────────────────────────────┘
```

- 등급 줄: `GradeTile(28, 등급 색)` + gap 10 + `{S급} · {이름}` (15 / w700 / `textHeading`). 이름은 §등급 의미 문구의 굵은 이름
- 코멘트 미리보기: 14 / `textBody`, `maxLines: 2`, ellipsis. 없으면 줄 자체 생략
- 버튼: 높이 48, full, radius 12, 배경 `surfaceElevated`, border `border`, 글자 `textBody` 15 / w600, 라벨 `평가 수정`. 탭 → `StoreReviewFormPage(existingReview: myReview)`
- 같은 매장의 다른 주문 상세에서도 동일하게 보인다 (D3). 헤더 라벨이 "이 주문" 이 아니라 **"이 매장에"** 인 이유
- 카운트다운 캡션: 상태 A 와 동일 규칙

#### 상태 C — 기한 만료 (`expired`)

- C-1 평가 없음: **info 안내 카드** (기존 `ready/making` 카드 패턴과 동일: 배경 `surface`, border `border`, radius 12, padding 가로 16 / 세로 14, `Icons.info_outline_rounded` 18 `info`, 14 / `textMuted`)
  - 문구: `평가 기간(14일)이 지났어요`
  - 버튼 없음
- C-2 평가 있음: 상태 B 와 같은 카드이되 **버튼 대신** 하단에 캡션 `수정 기간(14일)이 지났어요` (12 / `textMuted`). 평가 내용은 그대로 보여준다

#### 로딩 / 에러 (`watchMyReview`)

- 로딩: 카드 높이 자리에 `surface` 라운드 박스 (full, 높이 96, radius 16). 라벨이 `매장 평가하기` → `평가 수정` 으로 깜빡 바뀌는 것을 막기 위해 **값이 오기 전에는 버튼을 그리지 않는다**
- 에러: 상태 C-1 과 같은 info 카드 스타일이되 아이콘 `Icons.error_outline_rounded` `error`, 문구 `평가 정보를 불러오지 못했어요`, 우측 `다시 시도` 텍스트 버튼 (13 / w600 / `primary`, 최소 터치 48)

#### 접근성

- 상태 A: 카드 `Semantics(container)`, 버튼은 일반 button (`매장 평가하기`)
- 상태 B: 등급 줄을 `Semantics(label: '이 매장에 남긴 내 평가, S급 최고예요, {코멘트}')` 로 병합. 버튼 `평가 수정`
- 상태 C-1: 안내 카드 낭독 `평가 기간 14일이 지났어요`

### 3-2. `store_menu_header` — `GradeBadge` 탭 → 리뷰 목록

헤더는 사진 위 어두운 그라디언트 위에 `GradeBadge` 가 우측에 놓인다(현 구현). 그 위에 탭 기능을 얹는다.

- 탭 대상: `GradeBadge` + 어포던스. 터치 영역을 **최소 48 × 44** 로 확보 (배지 자체는 약 22px 높이이므로 `InkResponse` / `Padding` 으로 상하 11, 좌우 8 이상의 투명 hit 영역 추가). 이 때문에 행 높이가 늘어나지 않도록 hit 영역은 **음의 레이아웃 없이 `GestureDetector(behavior: opaque)` + `ConstrainedBox(minHeight 44)`** 로 처리하고 시각 배치는 기존과 동일해야 한다 (우측 정렬 유지)
- 어포던스: `GradeBadge` 에 **옵션 `showChevron`(기본 false)** 추가. 헤더에서만 true → 텍스트 뒤 gap 2 + `Icons.chevron_right_rounded` 14, 색은 해당 배지의 글자색과 동일. 추가 폭 16px
- 눌림: 배지 불투명도 0.85 (150ms). ripple 은 사진 위에서 어색하므로 `InkWell` 대신 불투명도 피드백
- 이동: `Navigator.push(MaterialPageRoute → StoreReviewsPage(store))`
- 접근성: `Semantics(button: true, label: '{A급}, 평가 128개. 평가 목록 보기')`. 0건: `아직 평가가 없는 매장. 평가 목록 보기`
- 0건 매장도 탭 가능 (빈 상태 화면이 평가 방법을 안내). 비활성화하지 않는다

### 3-3. `my_store_page` — `리뷰 수` Metric 탭 → 점주용 목록

- `_StoreMetricsSection` 의 3번째 `_Metric` 만 탭 가능하게 한다. `등급` / `평균 점수` 는 탭 불가 (변경 없음)
- `_Metric` 에 선택 파라미터 `onTap` 추가. `onTap != null` 이면:
  - 라벨 `리뷰 수` 뒤에 `Icons.chevron_right_rounded` 14 / `textMuted` (라벨과 gap 2, 같은 Row, 가운데 정렬 유지)
  - `InkWell(borderRadius: 12)` 로 감싸고 세로 padding 8, 가로 padding 8 (섹션 padding 세로 20 안에서 터치 영역 약 56px 확보)
- 이동: `Navigator.push(MaterialPageRoute → OwnerStoreReviewsPage(store))`
- 접근성: `Semantics(button: true, label: '리뷰 수 {128}개. 받은 평가 보기')`. 0건: `리뷰 수 0개. 받은 평가 보기`
- **0건 표시 변경** (`reviewCount == 0`)

| Metric | 기존 | 0건 |
|---|---|---|
| 등급 | `C급` | `미평가` — 값 스타일 18 / w700 / **`textMuted`** |
| 평균 점수 | `0.0` | `-` — 값 스타일 18 / w700 / **`textMuted`** |
| 리뷰 수 | `0` | `0` (textHeading 유지, 탭 가능) |

- `reviewCount > 0` 이면 기존 표시와 완전히 동일 (값 색 `textHeading`)

---

## `GradeBadge` 수정 (F7 `미평가`)

`lib/presentation/customer/home/widgets/grade_badge.dart` — **수정**

### 분기

| 조건 | 표시 |
|---|---|
| `reviewCount > 0` | **현재와 100% 동일** (navy pill, `S급 (128)`) |
| `reviewCount == 0` | `미평가` 단독. 카운트 텍스트·`(-)`·간격 SizedBox 모두 제거 |

### `미평가` 스타일

| 속성 | 값 | 기존 대비 |
|---|---|---|
| padding | 가로 10 / 세로 4 | 동일 |
| radius | 999 | 동일 |
| 배경 | `AppColors.surface` | `primary` → `surface` |
| border | `AppColors.border` 1px | 신규 (흰 배경·사진 위에서 윤곽 확보) |
| 글자 | `미평가`, 11 / w700 / `AppColors.textBody` | 색 `onPrimary` → `textBody` (대비 확보. `textMuted` 는 `surface` 위에서 4.4:1 로 11px 에 부족) |
| 높이 | border 1px 때문에 +2px | **border 는 `Border.all` 대신 padding 을 세로 3, 가로 9 로 줄여 보정해 총 높이 동일 유지** |

> 총 높이/폭이 기존 `C급 (-)` 와 같거나 작아야 한다. 아래 표 참조.

### 신규 옵션

- `showChevron` (bool, 기본 `false`) — §3-2. 5개 사용처 중 **`store_menu_header` 만 true**. 나머지는 기본값이라 코드 변경 없음
- 접근성: `Semantics(label: ...)` 를 `GradeBadge` 자체가 소유 (`excludeSemantics` 로 내부 Text 낭독 중복 방지)
  - `reviewCount > 0`: `{label}, 평가 {N}개`
  - `reviewCount == 0`: `아직 평가가 없는 매장`

### 5개 사용처(6개 지점) 레이아웃 영향 점검

폭 추정: 기존 `C급 (-)` ≈ 66px, `S급 (128)` ≈ 72px / 신규 `미평가` ≈ 53px (+ chevron 이면 +16 = 69px, 메뉴 헤더 한정)

| # | 위치 | 배치 | 0건 영향 | 판정 |
|---|---|---|---|---|
| 1 | `store_card.dart:59` 세로 카드 | 112px 이미지 위 `Positioned(top 8, right 8)` | 폭 66 → 53. 사진 위 밝은 pill 이 되며 사진이 어두워도 `surface` + border 로 가독. 겹침 없음 | OK |
| 2 | `store_card.dart:148` 가로 카드 | 96×96 썸네일 위 `Positioned(top 8, left 8)`. 썸네일 폭 96 에서 8+66=74 사용 중 | 폭 감소 → 여유 증가 | OK |
| 3 | `frequent_stores_section.dart:168` | 이미지 위 `top 8, right 8`; 좌측에 `_CountBadge`(방문수, `top 8, left 8`) 공존 | 폭 감소 → 두 배지 충돌 가능성 낮아짐. `미평가` 가 밝은 pill 이라 `_CountBadge`(어두운 채움 추정)와 **시각적으로 구분**되어 오히려 혼동 감소 | OK |
| 4 | `store_map_marker_sheet.dart:90` | 흰 시트 안 `Row[거리, gap 10, GradeBadge]`, 우측에 `_OrderButton` | 폭 감소. 흰 배경에서 `surface` + border 로 윤곽 유지 (border 없으면 거의 안 보임 → border 필수 사유) | OK |
| 5 | `store_menu_header.dart:91` | 어두운 사진 + 그라디언트 위 `Row[거리, 영업상태, Spacer, GradeBadge]` | 0건: 53 + chevron 16 = 69 ≈ 기존 66. 영업상태 텍스트와 `Spacer` 사이 여유 충분(헤더 폭 − 40). 좁은 기기(320dp) 에서도 거리+영업상태+배지 합 약 220 이하 | OK, 단 **320dp 수동 확인 필요** |
| 6 | `my_store_page.dart:473` | 흰 카드 `Row[scopeBadge?, 카테고리칩×3, Spacer, ApprovalStatusBadge, gap 6, GradeBadge]` — 이미 가장 붐비는 Row | 폭 66 → 53 으로 **13px 감소**, 기존보다 안전 | OK (회귀 없음). 단 이 Row 는 기존에도 칩 3개 + 배지 2개로 좁은 기기에서 overflow 가능성이 있는 **기존 문제**이며 이 task 와 무관 |

결론: `미평가` 는 모든 사용처에서 기존 `C급 (-)` 보다 좁거나 같고, `reviewCount > 0` 경로는 코드·시각 모두 불변이므로 기존 레이아웃 회귀 위험이 없다. 유일한 증분 폭은 `showChevron` 을 켠 메뉴 헤더 1곳(+16px)이다.

---

## 컴포넌트 목록 (재사용/수정/신규)

| 구분 | 위젯 | 위치 | 비고 |
|---|---|---|---|
| **수정** | `GradeBadge` | `customer/home/widgets/grade_badge.dart` | `미평가` 분기 + `showChevron` 옵션 + Semantics |
| **수정** | `StoreMenuHeader` | `customer/order/store/widgets/store_menu_header.dart` | 배지 탭 + `showChevron: true` + hit 영역 |
| **수정** | `_ActionSection` completed 분기 | `customer/order/orders/order_detail_page.dart` | completed 분리 + `_ReviewActionCard`. cancelled/refunded 불변 |
| **수정** | `_StoreMetricsSection` / `_Metric` | `owner/my_store/my_store_page.dart` | 0건 표시 + 3번째 Metric 탭 |
| **신규** | `StoreReviewFormPage` | `customer/review/store_review_form_page.dart` | 작성/수정 겸용 |
| **신규** | `GradeSelector` (+ private `GradeOptionCard`) | `customer/review/widgets/grade_selector.dart` | 라디오 카드 4장 |
| **신규** | `GradeTile` | `customer/review/widgets/grade_tile.dart` | 선택 카드·리뷰 카드·액션 카드 공유 |
| **신규** | `ReviewCard` | `customer/review/widgets/review_card.dart` | `isMine` 변형 |
| **신규** | `StoreReviewsView` (+ private `ReviewSummaryCard`) | `customer/review/widgets/store_reviews_view.dart` | 고객/점주 공유 본문 |
| **신규** | `StoreReviewsPage` | `customer/review/store_reviews_page.dart` | AppBar + `StoreReviewsView` |
| **신규** | `OwnerStoreReviewsPage` | `owner/reviews/owner_store_reviews_page.dart` | AppBar + `StoreReviewsView(showMine: false)` |
| **재사용** | `OrderStatusBadge`, 기존 info 안내 카드 패턴, `AlertDialog` 패턴(`_CancelOrderDialog` 와 동일 스타일) | — | 신규 컴포넌트 없이 스타일만 복제 |

> spec §5.3 의 `review_card.dart`, `grade_selector.dart`, `store_review_form_page.dart`, `store_reviews_page.dart`, `owner_store_reviews_page.dart` 와 일치. 추가된 신규 파일은 `grade_tile.dart`, `store_reviews_view.dart` 2개.

---

## 인터랙션 요약

| 화면 | 동작 | 반응 |
|---|---|---|
| order_detail (completed) | `매장 평가하기` / `평가 수정` | 폼 push |
| 폼 | 등급 카드 탭 | 선택 전환, 저장 활성 |
| 폼 | 저장 | 제출 중 스피너 → 성공 시 pop + 스낵바 |
| 폼 | 뒤로가기 (변경 있음) | 이탈 확인 다이얼로그 |
| store_menu 헤더 | 배지 탭 | `StoreReviewsPage` push |
| my_store | `리뷰 수` 탭 | `OwnerStoreReviewsPage` push |
| 리뷰 목록 | 카드 탭 | 반응 없음 (읽기 전용, 카드에 ripple 두지 않음) |
| 리뷰 목록 | 에러 `다시 시도` | provider invalidate |

---

## 개발자 전달 특이사항

### 카피 문자열 전체 (그대로 사용)

**등급 선택**
- 안내: `음료·서비스·분위기를 종합해서 골라주세요`
- S: `최고예요` / `다시 찾고, 주변에 먼저 추천하고 싶은 매장이에요`
- A: `좋아요` / `만족스러웠고 또 방문할 의향이 있어요`
- B: `보통이에요` / `무난했지만 아쉬운 점도 있었어요`
- C: `아쉬워요` / `기대에 못 미쳤고 개선이 필요해요`

**폼**
- AppBar: `매장 평가` (수정 모드 `평가 수정`)
- 헤더 라벨: `이 매장에 대한 내 평가`
- 코멘트 라벨: `한마디 남기기` + `(선택)`
- 코멘트 hint: `방문하면서 느낀 점을 자유롭게 남겨주세요`
- 카운터: `{n}/300`
- 안내 1: `솔직한 평가가 다른 Qrator 에게 가장 도움이 돼요`
- 안내 2: `평가는 'Qrator {코드}' 로 익명 공개되며, 매장 점주도 볼 수 있어요`
- 다른 주문 안내: `이전에 남긴 평가가 있어요. 저장하면 이번 주문 기준으로 바뀌어요`
- 버튼: `평가 등록` / `수정 완료`
- 비활성 hint(스크린리더): `등급을 먼저 선택해 주세요`
- 이탈 다이얼로그: `작성 중인 평가를 그만둘까요?` / `나가면 입력한 내용이 사라져요` / `계속 작성` / `나가기`

**스낵바**
- `평가가 등록됐어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요`
- `평가를 수정했어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요`
- `평가를 저장하지 못했어요. 잠시 후 다시 시도해 주세요`
- `이 주문으로는 평가할 수 없어요`
- `평가 기간이 지나 저장할 수 없어요`
- `네트워크 연결을 확인해 주세요`

**order_detail 액션 카드**
- 상태 A: `이 매장은 어땠나요?` / `Qrator 의 평가가 매장 등급을 만들어요` / `매장 평가하기`
- 카운트다운: `오늘까지 평가할 수 있어요` / `{N}일 후 평가 기간이 끝나요`
- 상태 B: `이 매장에 남긴 내 평가` / `{S급} · {이름}` / `평가 수정`
- 상태 C-1: `평가 기간(14일)이 지났어요`
- 상태 C-2 캡션: `수정 기간(14일)이 지났어요`
- 로드 실패: `평가 정보를 불러오지 못했어요` / `다시 시도`

**리뷰 목록**
- AppBar: 고객 `매장 평가` / 점주 `받은 평가`
- 요약: `Qrator 평가 {N}개 · 평균 {x.x} / 4`, 0건 `미평가` + `아직 평가가 없어요`
- 반영 캡션: `방금 남긴 평가는 등급에 곧 반영돼요`
- 섹션: `내 평가` / `전체 평가 {N}개`
- pill: `내 평가`
- 날짜: `방금 전` / `{N}분 전` / `{N}시간 전` / `{N}일 전` / `yyyy.MM.dd` + ` · 수정됨`
- 50개 안내: `최근 50개 평가를 보여드려요`
- 에러: `평가를 불러오지 못했어요` / `네트워크 연결을 확인하고 다시 시도해 주세요` / `다시 시도`
- 빈 상태(고객): `아직 평가가 없어요` / `주문을 완료한 뒤 Log 에서 이 매장을 평가할 수 있어요`
- 빈 상태(점주): `아직 받은 평가가 없어요` / `손님이 주문을 완료하고 평가를 남기면 여기에 표시돼요`
- 로딩 접근성: `평가를 불러오는 중`

**배지 / 점주 지표**
- 배지 0건: `미평가` (접근성 `아직 평가가 없는 매장`)
- my_store 0건: 등급 `미평가`, 평균 점수 `-`, 리뷰 수 `0`

### 구현 주의

1. **별 아이콘 금지**: `Icons.star*`, `Icons.thumb_*` 도 쓰지 않는다 (엄지 척 메타포도 이분법). 빈 상태는 `Icons.rate_review_outlined`.
2. **프리필 로딩 제거**: `order_detail_page` 가 이미 `watchMyReview` 를 구독하므로 폼 진입 시 `existingReview` 를 **인자로 전달**한다. 폼이 자체 구독을 하면 첫 프레임에 작성/수정 모드가 바뀌는 깜빡임이 생긴다.
3. **수정 모드 변경 감지**: 초기값(등급, 코멘트 trim 결과)과 현재값을 비교. 등급이 같고 코멘트 trim 이 같으면 저장 비활성.
4. **코멘트 trim**: 저장 전 `trim()`, 빈 문자열이면 `comment` 키를 전송하지 않는다 (Rules 의 `hasOnly` / 길이 규칙과 일치). 수정 시 코멘트를 지운 경우 `comment` 를 문서에서 제거해야 하는지(`FieldValue.delete()`)는 data 레이어에서 결정 — Rules update 화이트리스트에 `comment` 가 있으므로 삭제 가능.
5. **저장 버튼 중복 탭 방지**: 제출 중 상태 플래그로 이중 submit 차단.
6. **내 평가 uid 코드**: `uid.substring(0, 4)`. uid 길이 4 미만 방어. 폼의 안내 2 와 `ReviewCard` 가 같은 헬퍼(`maskedQratorName(uid)` 등, domain 또는 presentation util)를 쓴다.
7. **`GradeTile` 글자색 매핑**은 위젯 내부 한 곳에만. `Color(0x...)` / `Colors.white` 금지.
8. **요약 캡션 판정 입력**: `list.length`(일반) + `myReview != null ? 1 : 0` 가 `store.reviewCount` 와 다르고 `list.length + mine < 50` 일 때만. 점주 화면은 `mine = 0` 으로 계산 (점주는 작성자가 아님).
9. **내 평가 중복 제거**: 일반 목록에서 `review.userId == currentUid` 를 제외한다 (최상단 `내 평가` 와 중복 방지).
10. `StoreReviewsPage` 에 넘기는 `store` 는 스냅샷이다. 요약이 CF 반영 시 갱신되길 원하면 `storeProvider(storeId)` 를 watch (developer 판단, 디자인상 둘 다 허용).
11. 날짜 포맷은 `intl` (`pubspec` 에 이미 있음).

### AppColors 토큰 사용 목록 (신규 0개)

`primary`, `primaryLight`(B 타일), `primaryBright`(A 타일), `accent`(S 타일), `onPrimary`, `background`, `surface`, `surfaceElevated`, `border`, `textHeading`, `textBody`, `textMuted`, `info`, `error`.

### 애니메이션 수치

- 등급 카드 선택 전환: `AnimatedContainer` 150ms `Curves.easeOut`
- 헤더 배지 눌림: 불투명도 0.85, 100ms
- 그 외 애니메이션 없음 (skeleton 도 static)

---

## Figma 대비 변경사항

Figma 없음. 기존 화면 대비 변경:

| 항목 | 기존 | 적용 |
|---|---|---|
| `GradeBadge` 0건 | navy `C급 (-)` | 약한 `surface` pill `미평가` |
| `my_store` 0건 지표 | `C급 / 0.0 / 0` | `미평가 / - / 0` (앞 두 값 `textMuted`) |
| `order_detail` completed | 회색 박스 `완료된 주문입니다` | 평가 액션 카드 3상태 (상태 라벨은 상단 `OrderStatusBadge` 가 담당) |
| 헤더 `GradeBadge` | 비탭 | 탭 + chevron |
| 등급 색 | `GradeBadge` 는 색 없음 | 불변. 개인 표 타일에만 `StoreGradeColor` 사용 (사유: 결정 9) |

---

## 후속 작업 (2차 범위, 이번 설계에서 일부러 제외)

- 평가 삭제 (R1): 폼 AppBar 우측 `삭제` 또는 내 카드의 더보기 메뉴 자리를 확보해 두되 1차엔 UI 없음
- 등급 분포 막대(S/A/B/C 건수): 목록이 50건 상한이라 정확도 문제. 집계 필드(`gradeCounts`)를 CF 가 쓰게 되면 요약 카드에 추가하기 좋다
- 점주 답글 (R3), 신고 (R4), 사진 (R6), 페이지네이션 (R8)

---

## 잔여 결정 확정 (2026-10-22)

designer 가 남긴 Q1~Q3 를 확정한다. **본 절이 design 본문의 해당 제안보다 우선한다.**

| # | 항목 | 확정 | 사유 |
|---|---|---|---|
| **Q2** | 평균 점수(`평균 3.2 / 4`) 노출 | **점주 화면에만.** 고객 화면은 **등급 + 건수만** (예: `A급 · 평가 12건`) — 사용자 직접 확인 | 고객은 "4점 만점" 이라는 내부 스케일을 알 이유가 없고, 노출하면 별점으로 오해할 여지가 생긴다. 브랜드 언어는 S~C 다. 반면 점주는 등급이 바뀌기까지 얼마나 남았는지 알 필요가 있으므로 유지한다 |
| **Q1** | 리뷰 목록에서 수정 진입 | **넣지 않음** (A4 우선, 수용) | 작성·수정 진입은 `order_detail_page` 단일. 목록에서도 수정하려면 14일 판정용 주문 조회가 추가로 필요해 1차 범위가 늘어난다. 내 평가는 목록 최상단에 `내 평가` pill 로 분리해 찾기 쉽게 한다 |
| **Q3** | 등급 분포 막대 (S/A/B/C 건수) | **2차** (수용) | 목록이 50건 상한이라 분포가 정확하지 않다. CF 가 `gradeCounts` 를 집계하게 되면 그때 정확한 값으로 추가한다 |

### Q2 구현 메모

고객용과 점주용이 같은 `StoreReviewsView` 본문을 공유하므로, **요약 카드의 평균 줄만 플래그로 분기**한다 (예: `showAverage` 기본 false, 점주 화면에서만 true).
평균을 숨긴다고 데이터를 안 받는 것은 아니다 — `store.averageScore` 는 그대로 있고 **표시만** 하지 않는다.

### designer 가 확인하지 못했다고 밝힌 항목 (developer 작업 시 실측 필요)

1. `store_card.dart` / `frequent_stores_section.dart` 의 `_CountBadge` 스타일 — `미평가` pill 과 나란히 놓였을 때 시각적으로 구분되는지
2. 폭 수치(53 / 66 / 72px)는 글꼴 폭 **추정값** — 특히 메뉴 헤더의 chevron(+16px)이 **320dp 기기**에서 넘치지 않는지

둘 다 "추정" 이라고 명시돼 있으므로 developer 가 실제 렌더로 확인하고 `implementation.md` 에 결과를 기록한다.
