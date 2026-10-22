# 점주 매출 조회 (owner_sales) 디자인 명세

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-10-21 | designer | 최초 작성. spec §12 D1~D7 확정값 전제. 재논의 없음 |

---

## 참조한 디자인

- spec: `docs/tasks/owner_sales/spec.md` (§2.3 상태표, §3 집계 규칙, §12 확정 D1~D7)
- Figma: 없음
- 기존 화면: `OwnerOrdersPage` (AppBar 20/w700, 카드 = `surfaceElevated` + `border` + radius 16 + margin h16 v6, 리스트 `bottom: 110`, 3행 static skeleton, `Icon + 제목 + 보조문구` Center 빈 상태)
- 기존 배너: `NotificationDeniedBanner` (warning 10% + warning 테두리 + radius 12), `MyStorePage._RejectedBanner` (error 6% + error 30% 테두리 + radius 14)
- 기존 배지: `lib/presentation/common/order_status_badge.dart` (`OrderStatusBadge`, small 22px pill)
- 직전 작업 톤: `docs/tasks/order_flow_phase3c/3_notification_settings/design.md`
- 역할 흐름: `docs/processes/role_flows.md` (§점주). 진입은 `OwnerScaffold` 하단 탭 3번째 "매출" (IndexedStack). 신규 라우트 없음. 주문 행 탭은 `Navigator.push(MaterialPageRoute → OwnerOrderDetailPage)` 풀스크린이며 `OwnerOrdersPage` 와 동일 패턴

---

## 핵심 디자인 결정 (요약)

| # | 결정 | 사유 |
|---|---|---|
| 1 | 요약은 **밝은 단일 카드**. 총 매출 32/w800 이 카드의 유일한 대형 요소. 네이비 채움 히어로 카드는 채택하지 않음 | 앱 컨셉(밝은 캔버스 + 네이비 포인트 제한 사용), 기존 점주 카드와 같은 집. 숫자 크기 차이만으로 위계가 충분히 선다 |
| 2 | 보조 지표는 총 매출 **바로 아래**, `AppColors.surface` 면(plate) 위 13px 3행으로 배치. 항상 3행 노출 | 같은 카드 안, 같은 시선 동선 안에 있어야 "왜 이 숫자인가" 가 설명된다. 크기(32 vs 13)와 면(plate)으로 위계는 낮추되, 숨기지 않는다. 0건이어도 행을 유지 → "제외된 게 없다" 도 정보이며 레이아웃이 흔들리지 않음 |
| 3 | 라벨을 `진행 중 포함` / `환불 제외` / `취소 제외` 로 **동사 어미 통일** | 총 매출에 들어간 것(포함)과 빠진 것(제외)이 한눈에 구분된다 |
| 4 | 환불·취소는 **error 색을 쓰지 않는다**. 금액은 `textBody` 숫자 + `-` 부호만. 목록에서는 muted + 취소선 | 환불은 이상 사건이 아니라 사실. 경고색은 truncated 처럼 "숫자를 신뢰하면 안 되는 상황" 에만 쓴다 |
| 5 | 환불 설명 각주 `환불은 주문한 날의 매출에서 차감돼요` 를 **refundedCount > 0 일 때만** 표시 | D2(주문일 기준) 때문에 "어제 금액이 줄었다" 는 의문이 생기는 유일한 경우에만 설명한다. 평소 화면은 조용하게 |
| 6 | truncated 경고는 **총 매출 숫자 바로 아래**, warning 톤 pill. 목록 끝에도 짧은 각주 | 숫자를 읽는 순간 같은 시야에서 한계가 보여야 한다. 경고색은 아이콘 + 틴트 배경만 사용, 글자는 `textBody` (warning 글자색은 흰 배경 대비 부족) |
| 7 | 기간 헤더(세그먼트 + 네비게이터)는 **스크롤과 분리해 상단 고정** | 목록이 길어도 기간 전환 가능. 기간 전환은 이 화면의 주 상호작용 |
| 8 | **기간이 바뀌면 skeleton**, pull-to-refresh 때는 **기존 내용 유지** | 새 기간 라벨 아래 이전 기간 숫자가 남는 "조용히 틀린 숫자" 를 원천 차단. 새로고침은 같은 기간의 갱신이므로 내용을 유지해도 틀리지 않는다 |
| 9 | 주문 행은 **신규 컴팩트 타일** (`SalesOrderTile`). 액션 버튼이 있는 기존 3종 타일은 재사용하지 않는다 | 매출 목록은 조회 전용. 기존 타일은 높이 110+ 에 버튼 중심 |
| 10 | 상태 배지 4종은 `OrderStatusBadge` 위임 + **진행 중 전용 배지만 신규** | 기존 배지 스타일 일관 + 신규 색 토큰 0개 |
| 11 | **새 색상 토큰 도입 없음** | 전부 기존 `AppColors` 로 해결 |

---

## 화면 구성

### OwnerSalesPage (`owner/sales/owner_sales_page.dart`)

```
┌───────────────────────────────────┐
│ AppBar            매출            │  background / elevation 0
├───────────────────────────────────┤
│ [ 일 | 주 | 월 ]  세그먼트 (고정) │  h16, top 8, 높이 40
│ ‹    10월 21일 (화)  [오늘]    ›  │  네비게이터 (고정) 높이 56
├───────────────────────────────────┤  ↓ 여기부터 RefreshIndicator + ListView
│ [매장 상태 배너]  pending/rejected만│
│ ┌─ 요약 카드 ───────────────────┐ │
│ │ 총 매출                       │ │
│ │ 60,000원          (32/w800)   │ │
│ │ [⚠ 주문이 많아 최근 1,000건만…]│ │  isTruncated 일 때만
│ │ ───────────────────────────── │ │
│ │ 주문 건수  │  평균 객단가      │ │
│ │ 9건        │  6,666원         │ │
│ │ ┌ plate (surface) ──────────┐ │ │
│ │ │ ⏲ 진행 중 포함  3건·18,000원│ │ │
│ │ │ ↩ 환불 제외     2건·-12,000원│ │ │
│ │ │ ⊘ 취소 제외              1건│ │ │
│ │ │ 환불은 주문한 날의 매출에서…│ │ │  refundedCount>0 만
│ │ └───────────────────────────┘ │ │
│ └───────────────────────────────┘ │
│ 주문 내역            환불·취소 포함 12건│
│ ┌ 주문 행 ──────────────────────┐ │
│ └───────────────────────────────┘ │
│ ... (bottom padding 110)          │
└───────────────────────────────────┘
```

- Scaffold `backgroundColor: AppColors.background`. 자체 Scaffold + AppBar 를 가진다 (다른 점주 탭과 동일).
- AppBar: `backgroundColor: AppColors.background`, `elevation: 0`, 제목 `매출` — 20 / w700 / `AppColors.textHeading` (`OwnerOrdersPage` 와 동일). **TabBar 없음**.
- 본문 분기 (위에서 아래 순서로 판정):
  1. `myStoreProvider` loading → 중앙 `CircularProgressIndicator(color: AppColors.primary)`
  2. `myStoreProvider` error → 매장 정보 에러 블록 (아래 "상태별 UI")
  3. `store == null` → 매장 미등록 빈 상태 (헤더 없음)
  4. 그 외 → `Column[ 기간 헤더(고정), Expanded(RefreshIndicator(ListView)) ]`
- 4번 분기의 ListView 내용은 `storeSalesProvider` 상태로 분기: loading → skeleton / error → 에러 블록 / data → (배너) + 요약 카드 + (목록 | 주문 0건 안내).
- **배너(매장 상태)는 storeSalesProvider 상태와 무관**하게, `store.status != approved` 면 data / loading / error 어느 상태에서도 ListView 최상단에 표시한다.
- ListView: `physics: AlwaysScrollableScrollPhysics()` (빈/에러/짧은 내용에서도 pull-to-refresh 동작), `padding: EdgeInsets.only(top: 8, bottom: 110)`.

---

## 컴포넌트 목록

### 1. SalesPeriodHeader (신규, `widgets/sales_period_header.dart`)

- 역할: 기간 타입 세그먼트 + 기간 네비게이터. 화면 상단 고정.
- 위젯 구조: `Padding(fromLTRB 16, 8, 16, 0) > Column[ _PeriodSegment, SizedBox(8), _PeriodNavigator ]`
- 높이 합: 40 + 8 + 56 = 104 (+ top 8)

#### 1-a. 세그먼트 `_PeriodSegment`

| 항목 | 값 |
|---|---|
| 컨테이너 | 높이 40, `AppColors.surface` 배경, radius 12, 내부 padding 4 |
| 구성 | 3등분 `Row[Expanded x3]`, 라벨 `일` / `주` / `월` |
| 선택됨 | 배경 `AppColors.primary`, radius 9, 글자 `AppColors.onPrimary` 13 / w600 |
| 선택 안 됨 | 배경 투명, 글자 `AppColors.textMuted` 13 / w500 |
| 전환 애니메이션 | 배경 `AnimatedContainer` 150ms `Curves.easeOut`. 슬라이딩 썸 불필요 |
| 탭 영역 | 시각 높이 40, 터치 영역은 세로 44 이상 (컨테이너 바깥 투명 영역까지 `behavior: opaque` 로 확장) |
| 이미 선택된 세그먼트 재탭 | 동작 없음 (spec 에 없음. 현재 기간 복귀 기능은 추가하지 않음) |

- 세그먼트 탭 시 `salesPeriodTypeProvider` 변경 + 기간은 `SalesPeriod.current(type)` 로 리셋 (spec §5.3).

#### 1-b. 네비게이터 `_PeriodNavigator`

| 항목 | 값 |
|---|---|
| 높이 | 56 고정 (주 단위의 2줄 라벨 때문에 높이가 변하지 않도록) |
| 구성 | `Row[ 이전 버튼, Expanded(가운데 라벨), 다음 버튼 ]` |
| 이전/다음 버튼 | 48x48 `IconButton`, 아이콘 `Icons.chevron_left_rounded` / `Icons.chevron_right_rounded` size 28 |
| 활성 색 | `AppColors.textHeading` |
| **비활성 색 (미래 기간 / 12개월 한도)** | `AppColors.textMuted.withValues(alpha: 0.35)`. `onPressed: null`. 버튼 자리는 **유지** (숨기지 않음 → 라벨 중앙 정렬과 레이아웃 불변) |
| 비활성 시 splash | 없음 |
| 가운데 라벨 | `Column(mainAxisSize: min)` 중앙 정렬. 제목 16 / w700 / `AppColors.textHeading` |
| 부제 | 주 단위에서만 날짜 범위 `10월 19일 ~ 10월 25일` 12 / w400 / `AppColors.textMuted`, 제목 아래 gap 2. 일·월 단위는 부제 없음 (제목만 세로 중앙) |
| 현재 기간 표시 | 제목 오른쪽 gap 6 에 작은 pill. 현재 기간(`isCurrent`)일 때만. 일 `오늘` / 주 `이번 주` / 월 `이번 달` |
| pill 스타일 | 높이 20, h-padding 8, radius 999, 배경 `AppColors.primaryBright.withValues(alpha: 0.15)`, 글자 `AppColors.primary` 11 / w600 |

**기간 라벨 규칙 (Qradar 표기, 일/주/월)**

| 단위 | 올해 | 올해가 아님 |
|---|---|---|
| 일 | `10월 21일 (화)` | `2025년 12월 31일 (수)` |
| 주 | `10월 4주차` + 부제 `10월 19일 ~ 10월 25일` | `2025년 12월 5주차` + 부제 `12월 29일 ~ 1월 4일` |
| 월 | `2026년 10월` (항상 연도 포함) | 동일 |

- "올해" 판정은 **KST 기준** 현재 연도 (D4).
- 요일은 `DateFormat('E', 'ko_KR')` 로 `월 화 수 목 금 토 일`.
- **주차 규칙**: 주(월~일)에 속한 **목요일이 속한 달**이 그 주의 달이고, 그 달의 몇 번째 목요일인지가 주차다. `weekOfMonth = (목요일.day - 1) ~/ 7 + 1`, `month = 목요일.month`. 이는 ISO 8601 / D3(월요일 시작) 및 bucketKey(`2026-W43`)와 정합한다. 예: 2026-10-19(월)~10-25(일) 의 목요일은 10/22 → `10월 4주차`. 2026-09-28~10-04 의 목요일은 10/1 → `10월 1주차` (부제의 `9월 28일 ~ 10월 4일` 이 달 경계를 정직하게 보여 준다). **부제가 있으므로 달 경계 혼동은 부제가 해소한다.**
- 부제 포맷: 같은 달이면 `10월 19일 ~ 10월 25일`, 달이 다르면 시작·끝 각각 `월 일` 을 모두 표기 (`9월 28일 ~ 10월 4일`). 끝 날짜는 `endExclusive - 1일`.
- 이 라벨 계산은 **표시용 순수 포매터**(`presentation` 의 formatter 또는 `SalesPeriod` 확장)로 분리하고 단위 테스트를 둔다 (월말/연말/윤년/목요일 규칙).

**상태 / 전이**

| 상태 | 표현 |
|---|---|
| 현재 기간 | 다음 버튼 비활성 + `오늘/이번 주/이번 달` pill 표시 |
| 과거 기간 | 양쪽 활성, pill 없음 |
| 12개월 전 한도 | 이전 버튼 비활성 (색만 흐려짐. 별도 문구 없음) |
| 기간 이동 시 | 제목 텍스트 `AnimatedSwitcher` 없이 즉시 교체. 본문은 skeleton (캐시 있으면 즉시 data) |

**접근성**

- 세그먼트 그룹: `Semantics(label: '기간 단위')` 로 감싸고 각 세그먼트는 `Semantics(button: true, selected: isSelected, label: '일')` 등.
- 이전 버튼 `Semantics(label: '이전 기간', hint: ...)`. 비활성(한도) 시 `hint: '최대 12개월 전까지 조회할 수 있어요'`.
- 다음 버튼 `Semantics(label: '다음 기간')`. 비활성(현재 기간) 시 `hint: '현재 기간이 마지막이에요'`.
- 가운데 라벨 `Semantics(liveRegion: true, label: '<제목> <부제>')` → 이동 시 스크린리더가 새 기간을 자동으로 읽는다. 읽기 예: `10월 4주차, 10월 19일부터 10월 25일`. pill 은 `이번 주` 를 라벨 끝에 이어 읽는다.
- 모든 터치 타깃 ≥ 44.

---

### 2. SalesSummaryCard (신규, `widgets/sales_summary_card.dart`)

- 입력: `SalesSummaryEntity` + `isTruncated`. **화면은 이 값만 표시하고 합산하지 않는다** (spec §8).
- 컨테이너: `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)`, `padding: EdgeInsets.all(20)`, 배경 `AppColors.surfaceElevated`, border `AppColors.border` 1px, radius 16, shadow 없음 (기존 점주 카드와 동일).

**수직 구조 (위→아래)**

| 순서 | 요소 | 스타일 | gap(아래) |
|---|---|---|---|
| 1 | 라벨 `총 매출` | 13 / w600 / `AppColors.textMuted` | 4 |
| 2 | 총 매출 금액 `PriceFormatter.formatKrw(netSales)` | **32 / w800 / `AppColors.textHeading` / height 1.1 / letterSpacing -0.5 / `FontFeature.tabularFigures()`** / `FittedBox(fit: scaleDown, alignment: centerLeft)` 로 감싸 큰 글꼴·큰 금액에서 줄바꿈 대신 축소 | truncated 있으면 12, 없으면 16 |
| 3 | (조건부) truncated 경고 | 아래 2-a | 16 |
| 4 | `Divider(height: 1, color: AppColors.border)` | | 16 |
| 5 | 보조 2열 (주문 건수 / 평균 객단가) | 아래 2-b | 16 |
| 6 | 내역 plate | 아래 2-c | 0 |

#### 2-a. truncated 경고 (`isTruncated == true` 일 때만)

- 위치: 총 매출 금액 **바로 아래** (카드 안).
- 구조: `Container(padding: h10 v8, radius 8, color: AppColors.warning.withValues(alpha: 0.10))` > `Row[ Icon(Icons.info_outline_rounded, size 16, AppColors.warning), SizedBox(8), Expanded(Text) ]`
- 텍스트: `주문이 많아 최근 1,000건만 집계했어요` — 12 / w600 / `AppColors.textBody`. `1,000` 은 `SalesQueryLimits.maxDocumentsPerQuery` 를 `NumberFormat` 으로 포맷해 문자열에 삽입 (카피에 숫자 하드코딩 금지).
- 톤: 에러가 아니라 **한계 고지**. 경고 글자색은 쓰지 않는다.
- 접근성: 단독 `Semantics(label: '주의. 주문이 많아 최근 1,000건만 집계했어요')`.

#### 2-b. 보조 2열

- `IntrinsicHeight > Row[ Expanded(_Stat), VerticalDivider(width 1, thickness 1, color border), Expanded(_Stat) ]`. 두 번째 열은 left padding 16.
- `_Stat`: 라벨 12 / w500 / `AppColors.textMuted`, gap 2, 값 18 / w700 / `AppColors.textHeading`.
- 값: `주문 건수` → `{n}건` / `평균 객단가` → `PriceFormatter.formatKrw(averageOrderValue)`.
- 위계: 총 매출(32) ≫ 보조 2열(18) ≫ plate(13).

#### 2-c. 내역 plate `_BreakdownPlate`

- 컨테이너: 배경 `AppColors.surface`, radius 12, padding h14 v12. border 없음.
- 3행 항상 표시 (순서 고정): `진행 중 포함` / `환불 제외` / `취소 제외`. 행 간 gap 8.
- 행 구조: `Row[ Icon(size 16, AppColors.textMuted), SizedBox(8), Expanded(Text label), Text value ]`, 행 높이 ≥ 20.
- 라벨: 13 / w400 / `AppColors.textBody`. 값: 13 / w600 / `AppColors.textBody`, 우측 정렬, `tabularFigures`.

| 행 | 아이콘 | 라벨 | 값 (n>0) | 값 (n==0) |
|---|---|---|---|---|
| 진행 중 | `Icons.schedule_rounded` | `진행 중 포함` | `{n}건 · {formatKrw(inProgressSales)}` | `0건` (`textMuted`) |
| 환불 | `Icons.undo_rounded` | `환불 제외` | `{n}건 · -{formatKrw(refundedAmount)}` | `0건` (`textMuted`) |
| 취소 | `Icons.block_rounded` | `취소 제외` | `{n}건` (금액 없음. Entity 에 취소 금액 없음) | `0건` (`textMuted`) |

- 환불 금액 표기: `refundedAmount` 는 양수 int. 표시할 때 `-` 를 앞에 붙인 문자열 `-12,000원` (`PriceFormatter.formatKrw(-refundedAmount)` 가 `-12,000원` 을 반환하므로 그대로 써도 됨).
- **환불 값은 `error` 색을 쓰지 않는다.** `textBody` 그대로 (톤 ④).
- 환불 각주 (`refundedCount > 0` 일 때만): plate 맨 아래, gap 10, 11 / w400 / `AppColors.textMuted`, 문구 `환불은 주문한 날의 매출에서 차감돼요`.
- 값이 길어 한 줄을 넘을 때: 라벨 `Expanded` 가 줄어들고 값은 `Flexible` + `maxLines 1` + `FittedBox(scaleDown)`. 큰 글꼴(1.5x)에서는 라벨/값 2줄(`Column`) 전환을 허용 — 겹침 금지.

**접근성 (Semantics, `excludeSemantics: true` 로 자식 병합)**

| 요소 | 읽기 문구 |
|---|---|
| 총 매출 | `총 매출 60,000원` |
| 주문 건수 | `주문 건수 9건` |
| 평균 객단가 | `평균 객단가 6,666원` |
| 진행 중 | `진행 중 3건, 18,000원, 총 매출에 포함` (0건: `진행 중 0건`) |
| 환불 | `환불 2건, 12,000원 제외` (음수 부호는 읽지 않게 하고 의미를 `제외` 로 전달. 0건: `환불 0건`) |
| 취소 | `취소 1건, 총 매출에서 제외` (0건: `취소 0건`) |
| 각주 | 일반 텍스트로 읽힘 |

- 금액 포맷 `60,000원` 은 대부분의 스크린리더(VoiceOver / TalkBack)가 "육만 원" 으로 읽는다. 단 `-12,000원` 의 하이픈은 기기별로 "빼기" / 무시 / "하이픈" 으로 갈리므로 **음수 문자열을 Semantics label 에 쓰지 말고** 위 표처럼 양수 + `제외` 로 별도 label 을 준다.
- 시각 텍스트는 `ExcludeSemantics` 로 감싸고 label 은 `Semantics(label:)` 에서 일괄 제공.

---

### 3. SalesOrderTile (신규, `widgets/sales_order_tile.dart`)

- 관계: `OwnerNewOrderTile` / `OwnerInProgressOrderTile` / `OwnerRefundRequestTile` 는 **재사용하지 않음** (액션 버튼 포함, 높이 110+). 대신 **카드 스타일(색·radius·margin·InkWell 시각 피드백)만 동일 규격으로 계승**한 컴팩트 신규 타일.
- 컨테이너: `Material(transparent) > InkWell(radius 16, splash `AppColors.primary` alpha 0.04, highlight alpha 0.02) > Container(margin h16 v6, padding h16 v14, 배경 surfaceElevated, border `AppColors.border`, radius 16)`. 높이 약 76 (내용 기준).
- 레이아웃: `Row(crossAxisAlignment: start)[ Expanded(Column 좌), SizedBox(12), Column 우(end) ]`

| 영역 | 내용 | 스타일 |
|---|---|---|
| 좌 1행 | 시각 | 12 / `AppColors.textMuted`. 일 단위: `HH:mm`, 주·월 단위: `MM/dd HH:mm` (기존 타일 포맷과 동일) |
| 좌 2행 (gap 4) | 대표 메뉴 요약 | 14 / w500 / 최대 1줄 ellipsis. 일반: `AppColors.textBody`, 제외 건(환불·취소): `AppColors.textMuted` |
| 우 1행 | 상태 배지 (`SalesStatusBadge`) | 아래 4번 |
| 우 2행 (gap 6) | 금액 | 아래 표 |

**대표 메뉴 요약 규칙**: 첫 항목 `menuItemName` + (수량 > 1 이면 ` ×{quantity}`) + (항목이 2개 이상이면 ` 외 {items.length - 1}개`). 예: `아메리카노`, `아메리카노 ×2`, `아메리카노 ×2 외 1개`. 항목이 비어 있으면 `항목 없음` (기존 타일과 동일).

**금액 표현 (상태별)**

| 상태 | 스타일 |
|---|---|
| completed / 진행 중 4종 | 16 / w700 / `AppColors.textHeading` |
| refunded / cancelled | 16 / w600 / `AppColors.textMuted` / `decoration: TextDecoration.lineThrough` / `decorationColor: AppColors.textMuted` |

- 금액 값은 `PriceFormatter.formatKrw(order.totalPrice)`.
- 환불·취소 행의 카드 자체는 **dim(opacity) 처리하지 않는다** (접근성·탭 가능). 텍스트 색만 muted.
- 금액을 `FittedBox(scaleDown)` 로 감싸 큰 글꼴 대응.

**인터랙션**: 카드 전체 탭 → `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OwnerOrderDetailPage(orderId: order.id)))` (`OwnerOrdersPage` 와 동일).

**접근성**: 타일 전체를 `Semantics(button: true, label: ...)` 로 병합, `excludeSemantics: true`.
- 일반: `{시각}, {메뉴 요약}, {금액}, {상태}. 탭하면 주문 상세`
- 환불/취소: `{시각}, {메뉴 요약}, {금액}, {상태}, 총 매출에서 제외됨. 탭하면 주문 상세`
- 시각 읽기 문구: 일 단위 `14시 35분`, 주·월 단위 `10월 21일 14시 35분`. (`14:35` 는 시각으로 읽히지 않는 기기가 있어 한글 단위 문자열을 별도 생성)
- `×2` → `2개`, `외 1개` 는 그대로.

---

### 4. SalesStatusBadge (신규 얇은 래퍼, `widgets/sales_status_badge.dart`)

- 목적: 매출 목록에서 상태를 **4종**으로 보여 준다. 기존 `OrderStatusBadge` 는 수정하지 않는다 (고객 화면 등에서도 사용).
- 크기: `OrderStatusBadgeSize.small` 과 동일 규격 (높이 22, h-padding 8, 11 / w600, radius 999).

| 표시 | 해당 status | 구현 | 배경 | 글자 | 라벨 |
|---|---|---|---|---|---|
| 완료 | `completed` | **`OrderStatusBadge` 위임** | `AppColors.surface` | `AppColors.textMuted` | `완료` |
| **진행 중** | `paid` / `accepted` / `making` / `ready` | **신규 pill** | `AppColors.primaryBright.withAlpha(0.15)` | **`AppColors.primary`** | `진행 중` |
| 환불 | `refunded` | **`OrderStatusBadge` 위임** | `AppColors.textMuted` 15% | `AppColors.textMuted` | `환불 완료` |
| 취소 | `cancelled` | **`OrderStatusBadge` 위임** | `AppColors.error` 12% | `AppColors.error` | `취소됨` |

- 라벨은 기존 `OrderStatusBadge` 의 `완료` / `환불 완료` / `취소됨` 을 **그대로 계승**한다 (일관성 우선). 사용자 요청 표기 `환불` / `취소` 와 1:1 은 아니나, 같은 앱 안에서 동일 상태가 다른 이름으로 불리지 않게 하기 위함이다.
- **진행 중 글자를 `primaryBright` 가 아닌 `primary`(네이비) 로 한 이유**: 기존 `paid` 배지가 쓰는 `primaryBright` 글자는 흰/연한 틴트 배경 대비가 약 2:1 로 WCAG 미달이다. 틴트 배경(= 기존 paid 배지와 같은 계열)은 유지하되 글자만 네이비로 해 가독성을 확보한다. 새 토큰은 필요 없다.
- 4종 시각 분리: `완료` 와 `환불 완료` 는 둘 다 회색 계열이라 배지만으로는 비슷하다. 의도적이다 (환불을 붉게 칠하지 않음 · 톤 ④). 두 상태의 구분은 **라벨 텍스트 + 금액 취소선**(3번)이 담당한다. 취소만 `error` 틴트를 유지하는 것은 기존 배지 규칙을 따른 것이다.
- 접근성: 라벨 텍스트 자체가 의미를 전달하므로 색에만 의존하지 않는다.

---

### 5. SalesOrderListHeader (신규, 작은 인라인 위젯)

- 위치: 요약 카드 아래, 주문이 1건 이상일 때만.
- 구조: `Padding(fromLTRB 20, 16, 20, 4) > Row[ 제목, Spacer, 건수 ]`
- 제목 `주문 내역` 15 / w700 / `AppColors.textHeading`
- 건수 `환불·취소 포함 {orders.length}건` 12 / `AppColors.textMuted`
- **`주문 건수`(요약) 와 숫자가 다를 수 있는 이유** (환불·취소 포함 전체 건수 vs 집계 대상 건수) 를 라벨로 직접 설명하기 위해 `환불·취소 포함` 을 고정 문구로 붙인다.
- 접근성: `Semantics(header: true)` 제목.

### 5-b. 목록 끝 각주 (`isTruncated` 일 때만)

- 목록 마지막 아이템 아래, `Padding(h20 v16)`, 중앙 정렬, 12 / `AppColors.textMuted`, 문구 `최근 1,000건까지만 표시돼요` (숫자는 상수에서 포맷).

---

### 6. 매장 상태 배너 `SalesStoreStatusBanner` (신규, `widgets/sales_store_status_banner.dart`)

- 표시 조건: `store.status != approved`. **요약 카드는 항상 함께 렌더 (차단 금지)**.
- 위치: ListView 최상단 (요약 카드 위), `margin: fromLTRB(16, 4, 16, 6)`.
- 공통 구조: `InkWell(radius 12) > Container(padding h16 v12, radius 12) > Row[ Icon 20, SizedBox(10), Expanded(Column[제목, 본문]), Icon(chevron_right_rounded, size 18, textMuted) ]`
- 탭 → `ref.read(ownerTabIndexProvider.notifier).set(0)` ("내 매장" 탭). 화살표 chevron 으로 탭 가능함을 표시.
- 제목 13 / w700 / `AppColors.textHeading`, 본문 12 / w400 / `AppColors.textBody` height 1.4.

| 변형 | 조건 | 배경 / 테두리 / 아이콘 | 제목 | 본문 |
|---|---|---|---|---|
| 승인 대기 (신규) | `pending` && `approvedAt == null` | `warning` 8% / `warning` 30% / `Icons.hourglass_empty_rounded` `AppColors.warning` | `매장 승인을 기다리고 있어요` | `승인 완료 후 주문이 접수됩니다` |
| 수정 검토 중 | `pending` && `approvedAt != null` | 동일 warning 톤 | `수정한 내용을 검토하고 있어요` | `검토 중에도 기존 주문 매출은 그대로 확인할 수 있어요` |
| 반려 | `rejected` | `error` 6% / `error` 30% / `Icons.cancel_outlined` `AppColors.error` (`MyStorePage._RejectedBanner` 와 동일 톤) | `매장 검토가 반려되었어요` | `내 매장 탭에서 사유를 확인하고 다시 제출해 주세요` |

- **승인 대기 문구 `승인 완료 후 주문이 접수됩니다` 는 spec §2.3 확정 카피**를 본문에 그대로 사용했다. 제목은 이를 보조하는 신규 카피.
- "수정 검토 중" 변형을 둔 이유: 이미 승인됐던 매장이 정보를 수정해 `pending` 으로 돌아가면 **과거 주문과 매출이 실제로 존재**한다. 이때 "승인 후 주문이 접수됩니다" 만 보여 주면 0원이 아닌 숫자와 모순된다 (`MyStorePage._StoreHeaderCard.isRevision` 과 같은 판정식). 반려 매장도 과거 주문이 있을 수 있어 요약은 있는 그대로 렌더한다.
- 접근성: `Semantics(button: true, label: '{제목}. {본문}. 탭하면 내 매장 탭으로 이동')`.

---

### 7. SalesEmptyState (공용 상태 블록, `widgets/sales_empty_state.dart`)

- 파라미터: `icon`, `iconColor`, `title`, `message?`, `actionLabel?`, `onAction?`, `compact`.
- 구조: `Column(mainAxisSize: min, center)[ Icon, SizedBox(12), Text(title), SizedBox(4), Text(message), SizedBox(16), 버튼 ]`
- 아이콘 size: 전체 화면형 56, compact(요약 카드 아래) 48.
- 제목: 15 / w600 / `AppColors.textHeading` (에러는 16). 보조: 13 / `AppColors.textMuted` / 중앙 정렬 / height 1.4 / `padding horizontal 32`.
- 버튼:
  - 채움 (CTA): 높이 44, radius 12, 배경 `AppColors.primary`, 글자 `AppColors.onPrimary` 14 / w600, 최소 너비 160
  - 외곽선 (재시도): 높이 44, radius 12, 배경 `AppColors.surfaceElevated`, border `AppColors.primary` 1.5, 글자 `AppColors.primary` 14 / w600 (기존 점주 타일의 외곽선 버튼과 동일 톤)
- 전체 화면형은 `Center`, compact 형은 요약 카드 아래 `Padding(top 32)` 에 배치 (`Center` 안 씀 → 요약 카드를 밀어내지 않음).
- 에러/빈 상태는 **ListView 안에서** 렌더해 pull-to-refresh 가 동작하게 한다 (`SliverFillRemaining` 또는 `ConstrainedBox(minHeight)`).

---

## 상태별 UI

### 매장 단계 (`myStoreProvider`)

| 상태 | 화면 | 상세 |
|---|---|---|
| **loading** | AppBar + 중앙 `CircularProgressIndicator(color: AppColors.primary)` | 기존 점주 화면과 동일. 기간 헤더 없음 |
| **error** | AppBar + 에러 블록 | 아이콘 `Icons.cloud_off_rounded` 56 `AppColors.error` / 제목 `매장 정보를 불러오지 못했어요` / 보조 `잠시 후 다시 시도해 주세요` / 외곽선 버튼 `다시 시도` → `ref.invalidate(myStoreProvider)`. (`OwnerOrdersPage` 의 같은 상태에는 버튼이 없으나 이 화면은 재시도를 제공한다) |
| **매장 미등록** (`store == null`) | AppBar + 중앙 빈 상태. **기간 헤더 숨김** (집계할 대상이 없음) | 아이콘 `Icons.storefront_outlined` 56 `AppColors.textMuted` / 제목 `등록된 매장이 없어요` / 보조 `매장을 등록하면 매출이 집계됩니다` / 채움 버튼 `내 매장 탭으로 이동` → `ownerTabIndexProvider.notifier.set(0)`. 에러 아님 |

### 집계 단계 (`storeSalesProvider`) — 기간 헤더는 이 단계에서 항상 표시

| 상태 | 화면 |
|---|---|
| **loading** | (배너가 있으면 배너) + **요약 카드 skeleton** + **주문 행 skeleton 3개** |
| **data / 주문 ≥ 1** | (배너) + 요약 카드 + 목록 헤더 + 주문 행 N개 (+ truncated 각주) |
| **data / 주문 0건** | (배너) + **요약 카드를 0 값으로 정상 렌더** + 요약 카드 아래 compact 빈 안내 |
| **error (일반)** | (배너) + 에러 블록 (아래) |
| **error (권한)** | (배너) + 권한 에러 블록 (아래) |

### Loading

- 표시 방식: 기존 `OwnerOrdersPage` 와 동일하게 **정적 skeleton 박스** (shimmer 애니메이션 불필요, 기존 패턴 일치).
- 요약 카드 skeleton: `Container(margin h16 v6, height 280, 배경 AppColors.surface, radius 16)`.
- 주문 행 skeleton ×3: `Container(margin h16 v6, height 76, 배경 AppColors.surface, radius 16)`.
- 기간 헤더는 skeleton 중에도 조작 가능 (전환 중 다시 전환 가능).
- **기간/단위를 바꿨을 때는 반드시 skeleton** (이전 기간 숫자 잔존 금지). 같은 기간의 pull-to-refresh 는 skeleton 으로 전환하지 않고 기존 내용 위에 인디케이터만 보인다 (developer: `ref.refresh(provider.future)` 를 `RefreshIndicator.onRefresh` 에서 await. `AsyncValue.isLoading` 이어도 `valueOrNull` 이 있으면 기존 내용을 유지하는 `skipLoadingOnRefresh` 동작에 의존).
- 색상: `AppColors.surface` / progress `AppColors.primary`.

### Error

| 종류 | 아이콘 | 제목 | 보조 | 버튼 |
|---|---|---|---|---|
| 일반 | `Icons.cloud_off_rounded` 56 `AppColors.error` | `불러오는 데 실패했어요` | `네트워크 상태를 확인하고 다시 시도해 주세요` | 외곽선 `다시 시도` → `ref.invalidate(storeSalesProvider(query))` |
| 권한 (`permission-denied`) | `Icons.lock_outline_rounded` 56 `AppColors.error` | `매출을 조회할 권한이 없어요` | `매장 소유자 계정으로 로그인했는지 확인해 주세요` | **없음** (재시도로 해결되지 않음) |

- 에러 시에는 **요약 카드를 렌더하지 않는다** (신뢰할 숫자가 없음). 0원을 대신 보여 주는 것은 "조용히 틀린 숫자" 이므로 금지.
- `failed-precondition` 등 기타 에러는 일반 에러 UI. 원인 상세(`$e`)는 화면에 노출하지 않는다 (`debugPrint` 만).

### Empty — 주문 0건

- 요약 카드: `총 매출 0원` / `주문 건수 0건` / `평균 객단가 0원` / plate 3행 모두 `0건` (muted). truncated 경고·환불 각주 없음. **총 매출 숫자 색을 muted 로 낮추지 않는다** (0원도 정상 값. 기본값으로 정상 렌더).
- 목록 헤더(`주문 내역`) 는 숨김.
- 요약 카드 아래 compact 빈 안내: 아이콘 `Icons.receipt_long_outlined` 48 `AppColors.textMuted` / 제목 `이 기간에 주문이 없어요` / 보조 `주문이 들어오면 매출에 반영됩니다`.
- 과거 기간·미래 없는 현재 기간 모두 동일 카피.

### Empty — 승인 대기·반려 매장

- 위 "주문 0건" 화면 **그대로** + 최상단에 6번 배너. 요약은 0 값으로 렌더하며 화면을 막지 않는다.
- 신규 매장 첫 진입 시나리오 (spec §2.3 하단): 승인 전 = `배너 + 0원 요약 + 이 기간에 주문이 없어요`, 승인 후 주문 전 = `0원 요약 + 이 기간에 주문이 없어요`. **흰 화면과 에러 화면은 어느 경우에도 나오지 않는다.**

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| 세그먼트 탭 (다른 단위) | 선택 전환 (배경 150ms) → 기간을 해당 단위의 현재 기간으로 리셋 → 본문 skeleton → data |
| 세그먼트 탭 (이미 선택) | 변화 없음 |
| 이전 버튼 | 한 기간 과거로. 본문 skeleton (캐시 hit 이면 즉시 data) |
| 다음 버튼 | 한 기간 미래로 (현재 기간 초과 불가). 현재 기간에서는 **비활성** (흐린 아이콘, `onPressed: null`, 터치 무반응) |
| 이전 버튼 (12개월 한도) | 비활성. 별도 토스트/문구 없음 |
| 주문 행 탭 | `OwnerOrderDetailPage(orderId)` 풀스크린 push. 뒤로 가면 매출 탭 상태(선택 기간·스크롤) 유지 |
| 배너 탭 | "내 매장" 탭으로 전환 |
| 빈 상태 CTA 탭 | "내 매장" 탭으로 전환 |
| 다시 시도 탭 | `ref.invalidate` → 본문 skeleton |
| **pull-to-refresh** | 아래 |
| 스와이프 좌우 | 정의하지 않음 (기간 이동은 버튼만) |

### pull-to-refresh 표현

- `RefreshIndicator(color: AppColors.primary, backgroundColor: AppColors.surfaceElevated, displacement: 40, strokeWidth: 2.5)`. 대상은 **기간 헤더 아래 ListView** (헤더는 당겨지지 않음).
- 당기는 동안·새로고침 동안 **기존 내용 유지** (skeleton 으로 바꾸지 않음). 완료되면 숫자만 갱신.
- 모든 상태(data / 주문 0건 / error / 권한 error / 배너만 있는 상태)에서 동작 — 내용이 화면보다 짧아도 `AlwaysScrollableScrollPhysics`.
- 새로고침 실패 시: 기존 내용을 유지하되 에러를 놓치지 않도록 `SnackBar` `새로고침에 실패했어요` 1회 노출 (developer: 기존 data 가 있는 상태에서 refresh 가 error 로 끝난 경우에만). 에러 화면으로 갈아 끼우지 않는다.
- 접근성: 스크린리더 사용자를 위해 별도 새로고침 수단은 두지 않는다 (OS 의 스크롤 새로고침 제스처 지원에 의존). 에러 화면에는 `다시 시도` 버튼이 있다.

---

## 접근성 총정리

- 금액 `60,000원`: 스크린리더가 "육만 원" 으로 읽는 것을 전제로 하되, **Semantics label 은 직접 조립한 문자열**로 제공 (쉼표 읽기 편차 방지 및 부호 처리).
- **음수 금액(`-12,000원`)은 label 에 쓰지 않는다.** `12,000원 제외` 로 치환.
- 환불·취소 행: 취소선은 시각 정보이므로 label 에 `총 매출에서 제외됨` 을 반드시 포함.
- 상태 정보는 색이 아닌 **텍스트 라벨**로 전달 (배지 라벨 + 라벨 문구).
- `warning` 색은 글자에 쓰지 않는다 (대비 부족). 아이콘/틴트에만 사용.
- 최소 터치 영역: 세그먼트 44, 이전/다음 48, 주문 행 전체, 배너 전체.
- 큰 글꼴(최대 1.5x) 대비: 총 매출 `FittedBox(scaleDown)`, 주문 행 메뉴 요약 ellipsis 1줄, plate 값은 줄바꿈 허용, 네비게이터 제목은 1줄 ellipsis (부제는 숨기지 않음).
- 기간 라벨 `liveRegion` 으로 이동 결과를 자동 공지.

---

## 기존 `OwnerOrdersPage` 요소의 재사용 / 신규 구분

| 요소 | 구분 | 내용 |
|---|---|---|
| `myStoreProvider` 분기 (loading / error / null) | **재사용(패턴)** | 로딩 스피너·중앙 안내 패턴 동일. error 에는 재시도 버튼 추가 |
| AppBar (배경, 20/w700, elevation 0) | **재사용(규격)** | TabBar 만 없음 |
| 카드 스타일 (surfaceElevated + border + radius 16 + margin h16 v6) | **재사용(규격)** | 요약 카드·주문 행에 동일 규격 |
| `InkWell` splash/highlight (primary alpha 0.04/0.02) | **재사용(규격)** | 주문 행 |
| 리스트 `padding bottom 110` | **재사용** | |
| 3행 static skeleton | **재사용(패턴)** | 높이만 76 으로 조정, 요약 카드 skeleton 추가 |
| `Icon + 제목 + 보조문구` 빈 상태 / 에러 | **재사용(패턴)** → `SalesEmptyState` 로 공용화 | 사용 위치가 7+ 곳이라 공용 위젯으로 통합. 기존 페이지 코드는 건드리지 않음 |
| 에러 카피 `불러오는 데 실패했어요` + `cloud_off_rounded` | **재사용(카피·아이콘)** | |
| `OrderStatusBadge` | **재사용(위임)** | completed / refunded / cancelled |
| `OwnerOrderDetailPage` + push 방식 | **재사용** | 행 탭 진입 |
| `PriceFormatter.formatKrw` | **재사용** | 모든 금액. 신규 포맷터 금지 (`OwnerInProgressOrderTile` 의 `NumberFormat('#,###원')` 사용례는 따르지 않음) |
| 대표 메뉴 요약 로직 (`첫 항목 외 N개`) | **변형** | 수량 `×n` 추가 |
| `OwnerNewOrderTile` / `OwnerInProgressOrderTile` / `OwnerRefundRequestTile` | **재사용 안 함** | 액션 버튼 포함 |
| `NotificationDeniedBanner` | **재사용 안 함 / 톤만 계승** | 탭 동작이 달라 신규 배너. warning 톤은 동일 |
| `SalesPeriodHeader` (세그먼트 + 네비게이터) | **신규** | |
| `SalesSummaryCard` (+ 내역 plate, truncated 경고) | **신규** | |
| `SalesOrderTile` | **신규** | |
| `SalesStatusBadge` (진행 중 pill) | **신규(얇은 래퍼)** | |
| `SalesStoreStatusBanner` | **신규** | |
| `SalesEmptyState` | **신규(공용)** | |
| `SalesOrderListHeader` / 목록 각주 | **신규(인라인)** | |

---

## 색상 토큰 사용 요약

| 용도 | 토큰 |
|---|---|
| 화면 배경 | `AppColors.background` |
| 카드 / 주문 행 | `AppColors.surfaceElevated` + `AppColors.border` |
| 세그먼트 트랙 / 내역 plate / skeleton | `AppColors.surface` |
| 세그먼트 선택 | `AppColors.primary` / `AppColors.onPrimary` |
| 총 매출·값 | `AppColors.textHeading` |
| 본문·내역 라벨·값 | `AppColors.textBody` |
| 보조·비활성·제외 건 | `AppColors.textMuted` (+ 비활성 chevron 은 alpha 0.35) |
| 진행 중 배지 | 배경 `AppColors.primaryBright` 15% / 글자 `AppColors.primary` |
| 현재 기간 pill | 배경 `AppColors.primaryBright` 15% / 글자 `AppColors.primary` |
| truncated 경고 | 틴트 `AppColors.warning` 10% + 아이콘 `AppColors.warning`, 글자 `AppColors.textBody` |
| 승인 대기 배너 | `AppColors.warning` 8% / 30% 테두리 |
| 반려 배너 / 에러 아이콘 | `AppColors.error` |
| CTA / 재시도 | `AppColors.primary` / `AppColors.onPrimary` |

- `Color(0x...)` 직접 사용 0건. **신규 색상 토큰 도입 없음.**
- `Colors.transparent` 외 `Colors.*` 사용 금지.

---

## Figma 대비 변경사항

Figma 없음. 대신 spec §2.2/§11 및 기존 점주 화면 대비:

| 항목 | spec / 기존 | 이 디자인 |
|---|---|---|
| 상태 배지 라벨 | spec 표기 `완료/진행 중/환불/취소` | 기존 `OrderStatusBadge` 라벨 `완료/환불 완료/취소됨` 을 유지하고 `진행 중` 만 신규 |
| 취소/환불 건 금액 | spec "취소선 또는 muted" | 취소선 **과** muted 둘 다 |
| 매출 탭 에러 화면 | 기존 점주 에러는 버튼 없음 | 재시도 버튼 추가 (권한 에러 제외) |
| 승인 대기 배너 | spec 문구 1종 | 3변형 (승인 대기 / 수정 검토 중 / 반려) |
| 기간 헤더 | spec `‹ 2026년 10월 21일 (화) ›` | 연도는 올해가 아닐 때만 표기. `오늘/이번 주/이번 달` pill 추가 |

---

## 개발자 전달 특이사항

### 정확한 카피 문자열

| 위치 | 문자열 |
|---|---|
| AppBar | `매출` |
| 세그먼트 | `일` / `주` / `월` |
| 현재 기간 pill | `오늘` / `이번 주` / `이번 달` |
| 요약 카드 라벨 | `총 매출` / `주문 건수` / `평균 객단가` |
| 요약 값 | `{n}건` / `PriceFormatter.formatKrw(...)` |
| 내역 plate | `진행 중 포함` / `환불 제외` / `취소 제외` |
| plate 값 | `{n}건 · {금액}` (진행 중) / `{n}건 · -{금액}` (환불) / `{n}건` (취소) / `0건` |
| 환불 각주 (`refundedCount>0`) | `환불은 주문한 날의 매출에서 차감돼요` |
| truncated 경고 | `주문이 많아 최근 1,000건만 집계했어요` |
| truncated 목록 각주 | `최근 1,000건까지만 표시돼요` |
| 목록 헤더 | `주문 내역` / `환불·취소 포함 {n}건` |
| 진행 중 배지 | `진행 중` (그 외는 `OrderStatusBadge` 라벨) |
| 승인 대기 배너 | 제목 `매장 승인을 기다리고 있어요` / 본문 `승인 완료 후 주문이 접수됩니다` |
| 수정 검토 배너 | 제목 `수정한 내용을 검토하고 있어요` / 본문 `검토 중에도 기존 주문 매출은 그대로 확인할 수 있어요` |
| 반려 배너 | 제목 `매장 검토가 반려되었어요` / 본문 `내 매장 탭에서 사유를 확인하고 다시 제출해 주세요` |
| 매장 미등록 | `등록된 매장이 없어요` / `매장을 등록하면 매출이 집계됩니다` / 버튼 `내 매장 탭으로 이동` |
| 주문 0건 | `이 기간에 주문이 없어요` / `주문이 들어오면 매출에 반영됩니다` |
| 일반 에러 | `불러오는 데 실패했어요` / `네트워크 상태를 확인하고 다시 시도해 주세요` / 버튼 `다시 시도` |
| 권한 에러 | `매출을 조회할 권한이 없어요` / `매장 소유자 계정으로 로그인했는지 확인해 주세요` |
| 매장 정보 에러 | `매장 정보를 불러오지 못했어요` / `잠시 후 다시 시도해 주세요` / 버튼 `다시 시도` |
| 새로고침 실패 SnackBar | `새로고침에 실패했어요` |
| 항목 없음 | `항목 없음` |

### 구현 시 주의

- **집계 금지**: 위젯은 `SalesSummaryEntity` 의 값을 그대로 표시한다. `orders` 를 순회하며 `totalPrice` 를 더하는 코드를 위젯에 두지 않는다 (spec §8). 목록 헤더의 `{orders.length}` 는 합산이 아니라 단순 길이이므로 허용.
- **시간 표시와 D4**: 기간 경계는 KST 고정이다. 주문 행의 시각·라벨의 "오늘/올해" 판정도 **KST 로 맞춰 표시**한다. 디바이스 타임존이 KST 가 아닐 때 행의 시각이 기간 라벨과 어긋나지 않게 한다. 변환 위치는 formatter 한 곳.
- 기간 라벨·주차 계산은 순수 함수로 분리하고 단위 테스트 (연말/연초 주, 월 경계 주, 윤년 2월).
- `SalesStatusBadge` 는 `OrderStatus` 4종 분류를 자체 판단하지 말고, `completed` / `refunded` / `cancelled` 는 `OrderStatusBadge` 로 위임, 나머지(진행 중 4종)만 신규 pill.
- 요약 카드 항목 라벨 문자열은 `const` 로 한곳에 모아 두면 테스트에서 참조하기 쉽다.
- 기간이 바뀔 때 **이전 data 를 `valueOrNull` 로 남겨 두지 말 것** (새 family 키는 자연스럽게 loading 이 되므로 `skipLoadingOnReload` 를 기간 전환 경로에 적용하지 않는다). 같은 키의 `invalidate`/`refresh` 에서만 기존 값 유지.
- 숫자 열은 `FontFeature.tabularFigures()` 를 써서 기간 전환 시 자릿수 흔들림을 줄인다.
- `Semantics` 문자열은 위 표를 따르되 금액은 `PriceFormatter.formatKrw` 결과(양수)만 사용한다.
- 로딩/에러/빈 상태는 모두 스크롤 가능한 컨테이너 안에서 렌더 (pull-to-refresh).
- `OwnerSalesPlaceholder` 삭제, `owner_scaffold.dart` 교체, `role_flows.md` 갱신은 spec §11 developer 항목대로.

### 후속 / 선택 제안 (이번 범위 아님)

- 현재 기간에서 데이터가 오래된 채 남는 문제 (IndexedStack + `get()` 1회): "n분 전 기준" 갱신 시각 표기는 Entity 에 `fetchedAt` 이 필요해 spec 변경이 필요하다. 이번엔 넣지 않음.
- 주·월 단위 목록의 날짜 구분 헤더(`10월 21일 (화)`) 는 이번엔 넣지 않음 (각 행의 `MM/dd HH:mm` 으로 대체).
- 주문 상세에서 돌아왔을 때 소프트 갱신: 이번엔 정의하지 않음.

---

## 사용자 확인이 필요한 잔여 결정

| # | 항목 | designer 선택 (기본값) | 확인 필요 사유 |
|---|---|---|---|
| R1 | **주차 정의**: "그 주의 목요일이 속한 달의 n주차" + 주 단위에 날짜 범위 부제 | 목요일 규칙 (ISO / D3 정합) | 요청 예시 `10월 3주차` 는 정의가 없었다. "1일이 포함된 주 = 1주차" 같은 다른 규칙과는 달의 첫 주 판정이 갈리는 달이 있다 |
| R2 | 배지 라벨: 기존 `환불 완료` / `취소됨` 유지 vs 요청안의 `환불` / `취소` | 기존 유지 | 앱 전체 일관성 vs 요청 문구 |
| R3 | 매장 상태 배너를 **3변형**으로 확장 (spec 은 1종 문구) | 3변형 | 수정 검토 중·반려 매장에 과거 주문이 있을 수 있어 "승인 완료 후 주문이 접수됩니다" 단독 노출이 모순되기 때문 |
| R4 | 같은 단위 세그먼트 **재탭 시 현재 기간 복귀** 기능 | 미제공 (spec 없음) | 편의 기능이지만 spec 에 없어 임의 추가하지 않음 |

---

## 잔여 결정 확정 (2026-10-21)

designer 가 남긴 R1~R4 를 확정한다. **본 절이 design 본문의 해당 제안보다 우선한다.**

| # | 항목 | 확정 | 사유 |
|---|---|---|---|
| **R1** | 주차 정의 | **목요일 소속 기준** (ISO 8601) — 사용자 직접 확인 | 월요일 시작(D3) · S5 버킷 키와 일치. 연말·연초가 어긋나지 않는다. 달 첫 날 기준은 1주차가 최소 1일까지 짧아져 전주 대비 비교가 왜곡된다. 달 경계 혼동은 날짜 범위 부제(`10월 19일 ~ 10월 25일`)로 푼다. 2026-10-21(수) → **`10월 4주차`** |
| **R2** | 배지 라벨 | **`환불 완료` / `취소됨` 유지** (수용) | 고객 화면과 용어가 갈라지면 안 된다. spec 작성 시 예시로 쓴 `환불` / `취소` 가 부정확했다 |
| **R3** | 배너 3변형 (승인 대기 / 수정 검토 중 / 반려) | **채택** (수용) | 이미 승인됐다가 수정으로 `pending` 이 된 매장과 반려 매장은 **과거 주문이 실제로 존재**한다. 이때 "승인 완료 후 주문이 접수됩니다" 만 뜨면 0이 아닌 매출 숫자와 모순된다. spec 이 1종만 상정한 것이 누락이었다 |
| **R4** | 세그먼트 재탭으로 현재 기간 복귀 | **넣지 않음** (수용) | 이전/다음 버튼으로 돌아갈 수 있고, 숨은 동작은 발견되지 않아 가치가 낮다. 필요가 확인되면 추가한다 |

### 갱신 시각 표기 — 보류

designer 가 제기한 `n분 전 기준` 표기는 **1차에서 넣지 않는다.**
이 화면은 `IndexedStack` + `get()` 1회라 탭을 떠났다 돌아와도 재조회되지 않으므로, 오늘 매출이 오래된 채 남을 수 있다는 지적 자체는 타당하다.
다만 `StoreSalesEntity` 에 `fetchedAt` 추가가 필요한 **spec 변경**이라 범위를 넘는다.
대신 pull-to-refresh 가 있고 기간 전환 시 항상 재조회되므로 갱신 수단은 확보돼 있다.
→ 라이브 검증에서 **"오래된 숫자를 모르고 보는 문제가 실제로 체감되는지"** 를 확인하고, 체감되면 2차에 `fetchedAt` 과 함께 처리한다. (`docs/backlog.md` 매출 2차 범위에 S6 으로 기록)
