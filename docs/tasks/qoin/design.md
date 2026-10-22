# Qoin 1차 디자인 명세

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-10-22 | designer | 최초 작성. spec §15 "전건 확정"(D1~D7 / A1~A6, D4-d 관리자 화면 포함) 전제. 재논의 없음 |

---

## 참조한 디자인

- spec: `docs/tasks/qoin/spec.md` (§5 적립/회수 정책, §6 config, §9.2 클라이언트 에러, §10.4 미지 타입, §14 designer 과제, §15 확정)
- Figma: 없음
- 기존 화면 (같은 집에 살아야 하는 기준)
  - `lib/presentation/customer/log/orders_page.dart` — 빈 상태 `Icon 64 + 제목 16/w600 + 보조 13`, 에러 `Icon 48 error + 메시지 + primary 버튼`, 로딩은 `border` 색 정적 박스 skeleton, 상세 진입은 `Navigator.push(MaterialPageRoute → OrderDetailPage(orderId))`
  - `docs/tasks/owner_sales/design.md` — 요약 카드(총 매출 32/w800/height 1.1/letterSpacing -0.5/tabularFigures/FittedBox scaleDown), `surface` plate, 환불에 error 색 미사용, 음수 하이픈 대신 양수 + 동사로 읽기
  - `lib/presentation/admin/more/admin_more_page.dart` — 더보기 `_Tile`(icon 22 / title 15 w600 / subtitle 12 / chevron 18)
  - `lib/presentation/admin/menu_categories/admin_main_category_form_page.dart` — 폼 패턴: AppBar(뒤로가기 + 17/w700), 본문 `h20 v24`, 섹션 라벨 12/w600 muted + gap 6, 입력창 `surfaceElevated` + `border` radius 10 + 포커스 `primary`, 도움말 11 muted, 스위치 행(15/w500 + 12 muted + `Switch.adaptive`), 하단 52px 버튼 radius 12, 성공/실패는 SnackBar
- 색상 토큰: `lib/core/theme/app_colors.dart`. **신규 토큰 0개.** (`AppColors.accent` 는 designer_guide 에 "Qoin, 별점, 등급/프리미엄" 용으로 이미 정의돼 있어 재사용)
- 역할 흐름: `docs/processes/role_flows.md`
  - 고객: 하단 네비 1번 탭 `Qoin` → `ScaffoldWithNav` 의 `IndexedStack` child. **자체 AppBar / Scaffold 를 두지 않는다** (상단 `HomeHeader(mode: tabbed)` 가 이미 있음)
  - admin: `AdminScaffold` 더보기 탭 → `AdminMorePage` 신규 타일 → `Navigator.push(MaterialPageRoute → AdminQoinSettingsPage)` 풀스크린. 신규 named route 없음

---

## 핵심 디자인 결정 (요약)

| # | 결정 | 사유 |
|---|---|---|
| 1 | 잔액은 **밝은 단일 카드**, 숫자 `32/w800` 이 화면의 유일한 대형 요소. 단위 `Q` 는 같은 줄 `18/w700 textMuted`. 네이비 채움 히어로 카드 **미채택** | `owner_sales` 총 매출 카드와 같은 위계·같은 집. 숫자 크기 차이만으로 위계가 선다. 단위를 작고 muted 하게 두면 숫자가 "금액"으로 읽히고 `Q` 는 통화 기호처럼 보인다. 사용자 확정 표기(`1,200 Q`)를 그대로 지킨다 |
| 2 | 잔액 `0 Q` 는 **정상 상태**. `textHeading` 그대로, muted 로 흐리지 않음. 로딩 중에는 `0 Q` 를 **절대 보여주지 않고** skeleton | 로딩 중 `0 Q` 는 "조용히 틀린 숫자" — 적립 오해를 스스로 만든다 (`owner_sales` D 결정 8 과 같은 원칙) |
| 3 | **적립 시점 안내는 3곳에 중복 배치**: ① 잔액 카드 안 상시 plate ② 내역 빈 상태 ③ (권장) 진행 중 주문이 있을 때 배너 | 평가 기능에서 "기능은 정상인데 화면이 반영 안 해 결함으로 오인" 한 선례. 오해는 "결제했는데 Qoin 이 안 보인다" 는 **그 순간**에 생기므로 그 순간 시야에 있어야 한다. 한 곳에만 두면 스크롤·상태에 따라 사라진다 |
| 4 | 안내 문구는 **"픽업 완료 시"** 로 못박고 `결제 직후가 아니라` 를 **명시적으로 부정**한다. `결제 시 적립` 류 표현 전면 금지 | 기대 형성이 아니라 오해 차단이 목적. 사실(spec §5.3)과 일치 |
| 5 | 내역 증감은 **success / error 색 미사용.** 적립 = `textHeading` + `+`, 회수 = `textMuted` + `-`, 좌측 원형 아이콘(적립 `add` / 회수 `undo`)으로 2차 구분 | 회수는 이상 사건이 아니라 환불의 정상 귀결(owner_sales 결정 4). 또 `success`(16A34A) 16px 텍스트는 흰 배경 대비 약 3.3:1 로 WCAG AA 미달. 부호 + 아이콘 + 라벨 문구가 색 없이도 구분을 담당 |
| 6 | 내역은 **원장(ledger) 한 장 카드**: `surfaceElevated` + `border` + radius 16 안에 헤어라인 구분선으로 행을 나열 | 주문 카드처럼 행마다 카드를 쪼개면 50건에서 시각 소음이 크고 "돈 기록" 의 장부 느낌이 사라진다. 카드 색·radius·margin 은 `OrderCard`/`SalesOrderTile` 규격 계승 |
| 7 | 내역 행에 **적립 근거를 숫자로 노출**: `결제액 18,000원의 3%` (거래 문서의 `orderTotalPrice`·`accrualRate` 사용) | 사용자가 "왜 이 금액인가" 를 계산으로 검증할 수 있다. 정책이 바뀌어도 거래 당시 비율이 박혀 있으므로 과거 행이 틀리지 않는다 |
| 8 | 내역 행 **탭 → 주문 상세** (`OrderDetailPage`, `OrdersPage` 와 동일 push). `orderId` 비어 있는 미지 타입은 탭 불가 | 사유가 주문에 묶여 있으므로 "어떤 주문인지" 가 가장 정확히 답해지는 곳이 주문 상세. 신규 라우트 불필요 |
| 9 | 관리자 **적립 on/off 는 적립률 폼과 분리**된 즉시 반영 스위치 (확인 다이얼로그 1회) | 비상 정지 장치가 "적립률 입력 검증 실패" 나 "작성 중이던 적립률" 에 막히거나 휩쓸리면 안 된다. 두 값은 위험 성격이 달라 저장 경로도 분리 |
| 10 | 적립률은 **% 로 입력, 입력창 안에 `%` 고정 접미사, 하한 0.1% / 상한 20%, 소수 1자리, 실시간 환산 미리보기** (`결제 10,000원 → 300 Q 적립`) | `0.03` 오입력이 하한 미만(0.1) 으로 **구조적으로 걸러지고**, 설령 범위 내 오입력(`30` → 20 초과 거부, `0.5` 허용)이어도 미리보기 금액이 눈에 보인다 |
| 11 | 적립률 저장 전 **항상 확인 다이얼로그** — `현재 3% → 변경 5%` 와 `10,000원 결제 기준 300 Q → 500 Q` 비교 표시. 2배 이상 또는 10% 이상 인상이면 경고 줄 추가 | 돈을 발행하는 값. 되돌림 비용이 크고 즉시 손해가 발생. 확인 1탭의 비용은 무시 가능 |
| 12 | **새 색상 토큰 없음** | 전부 기존 `AppColors` 로 해결. 아래 "색상 사용" 참조 |
| 13 | 하단 네비 Qoin 탭 아이콘은 **`QLogo` 유지** | 메인 로고 확정 사항(MEMORY: QLogo 위젯 = 앱 아이콘). 탭 라벨 `Qoin` 이 의미를 전달한다. 코인 아이콘으로 바꾸면 로고와 화폐가 분리돼 브랜드 일관성이 약해진다. 변경 필요 시 별 task |

---

## 색상 사용 (토큰 전부 기존)

| 용도 | 토큰 |
|---|---|
| 카드 배경 / 테두리 | `AppColors.surfaceElevated` / `AppColors.border` |
| plate / skeleton / 비활성 | `AppColors.surface` |
| 잔액 숫자, 적립 금액 | `AppColors.textHeading` |
| 단위 `Q`, 회수 금액, 보조 문구 | `AppColors.textMuted` |
| 본문 | `AppColors.textBody` |
| 적립 아이콘 원 | 배경 `AppColors.primaryBright` alpha 0.15, 글리프 `AppColors.primary` |
| 회수 아이콘 원 | 배경 `AppColors.textMuted` alpha 0.15, 글리프 `AppColors.textMuted` |
| 잔액 카드 로고 배지 | 원 배경 `AppColors.accent` alpha 0.18, `QLogo` 색 `AppColors.primary` |
| 적립 중단 / 경고 | `AppColors.warning` alpha 0.10 배경 + 아이콘, **글자는 `textBody`** (warning 글자색은 흰 배경 대비 부족 — owner_sales 결정 6) |
| 에러 | `AppColors.error` 아이콘만 (orders_page 동일) |
| 주 버튼 | `AppColors.primary` / `AppColors.onPrimary` |

- `AppColors.accent`(gold) 는 **텍스트에 쓰지 않는다** (흰 배경 대비 약 1.4:1). 잔액 카드 로고 뒤 원형 배지의 **장식 틴트로만** 사용해 designer_guide 의 "프리미엄 강조 = Qoin" 규정을 충족하되 가독성을 해치지 않는다.
- `AppColors.success` 는 이 기능에서 **사용하지 않는다** (결정 5).

---

# 1. 고객 Qoin 탭 — `QoinPage` (전면 교체)

## 화면 구성

```
┌ HomeHeader (tabbed, 기존) ────────┐
├───────────────────────────────────┤
│ ┌─ QoinBalanceCard ─────────────┐ │
│ │ (◎) 내 Qoin                   │ │  QLogo 20 + accent 배지, 13/w600 muted
│ │ 1,200 Q              (32/w800)│ │
│ │ ───────────────────────────── │ │
│ │ ┌ plate (surface) ──────────┐ │ │
│ │ │ 🛍 픽업 완료 시 결제액의 3% 적립│ │ │  13/w600
│ │ │   결제 직후가 아니라, 매장에서…│ │ │  12 muted
│ │ │ ⓘ Qoin 사용은 준비 중이에요  │ │ │  13
│ │ └───────────────────────────┘ │ │
│ └───────────────────────────────┘ │
│ [진행 중 주문 배너]  (조건부·권장)    │
│ Qoin 내역                         │  15/w700
│ ┌ 원장 카드 ────────────────────┐ │
│ │ (+) 스타벅스 강남점      +540 Q › │ │
│ │     픽업 완료 · 결제액 18,000원의 3%│ │
│ │     10월 22일 (수) 14:35  잔액 1,200 Q│ │
│ │ ───────────────────────────── │ │
│ │ (↩) 스타벅스 강남점      -540 Q › │ │
│ │ ...                           │ │
│ └───────────────────────────────┘ │
│        최근 50건을 보여드려요 (50건일 때)│
│ (bottom padding 110)              │
└───────────────────────────────────┘
```

- 루트: `ListView(physics: ClampingScrollPhysics 기본, padding: only(top: 8, bottom: 110))`. 하단 110 은 `extendBody: true` + 하단 네비/FAB 가림 방지 (`OwnerOrdersPage` 와 동일 값).
- `SafeArea` 불필요 (`HomeHeader` 가 상단 처리). 기존 placeholder 의 `SafeArea > Center` 구조는 버린다.
- 배경은 `ScaffoldWithNav` 의 `AppColors.background` 를 그대로 사용. 자체 배경 지정 없음.
- 본문은 **세 블록이 독립 상태**를 가진다: ① 잔액 카드(프로필 스트림) ② 안내 plate 문구(config 스트림) ③ 내역(트랜잭션 스트림). 한 블록의 로딩/에러가 다른 블록을 가리지 않는다.
- pull-to-refresh 없음 (전부 live stream).

---

## 컴포넌트

### 1. QoinBalanceCard (신규, `customer/qoin/widgets/qoin_balance_card.dart`)

- 입력: `AsyncValue<UserEntity?>`(`currentUserProfileProvider`), `QoinConfigEntity?` 상태.
- 컨테이너: `margin: symmetric(horizontal: 16, vertical: 6)`, `padding: all(20)`, 배경 `surfaceElevated`, border `border` 1px, radius 16, shadow 없음.

**수직 구조**

| 순서 | 요소 | 스타일 | gap(아래) |
|---|---|---|---|
| 1 | 라벨 행 `[로고 배지] 내 Qoin` | 배지: 28x28 원, 배경 `accent` alpha 0.18, 안에 `QLogo(size: 16, animate: false, color: primary)` 중앙. 라벨 13 / w600 / `textMuted`, 배지와 gap 8 | 8 |
| 2 | 잔액 | `Text.rich`: 숫자 `32 / w800 / textHeading / height 1.1 / letterSpacing -0.5 / tabularFigures` + `SizedBox 4`(공백 span) + 단위 `Q` `18 / w700 / textMuted`. `FittedBox(fit: scaleDown, alignment: centerLeft)` 로 감싸 큰 글꼴·큰 금액 대응 | 16 |
| 3 | `Divider(height 1, color: border)` | | 16 |
| 4 | 안내 plate | 아래 1-a | 0 |

- 숫자 포맷: 천 단위 콤마, `Q` 앞 공백 1칸. 예 `1,200 Q`, `0 Q`. 표기는 **`1,200 Q` 확정(A5)**. `Qoin` 전체 표기나 로고로 단위를 대체하지 않는다. 로고 배지는 라벨 옆 장식일 뿐 단위가 아니다.
- 음수(2차 대비 방어): 부호 `-` 를 숫자 앞에 붙여 `-100 Q` 로 그대로 렌더. **색은 바꾸지 않는다**(`textHeading` 유지, error 금지). 별도 문구 없음 — 정책이 정의되지 않았으므로 설명을 지어내지 않는다. 레이아웃이 깨지지 않는 것만 보장한다.
- 매우 큰 값: FittedBox 가 축소. 9자리 이상 시 한 줄 유지.

**상태**

| 상태 | 숫자 영역 표현 |
|---|---|
| data (필드 있음) | 위 스타일 |
| data (`qoinBalance` 필드 부재) | **`0 Q` 정상 렌더** (에러 아님. spec §9.2) |
| loading | 숫자 자리에 `border` 색 skeleton 박스 (높이 34, 너비 140, radius 8). **`0 Q` 표시 금지** |
| error | 숫자 자리에 `-` (32/w800/textMuted) + 아래 gap 6 에 한 줄 `잔액을 불러오지 못했어요` 12 muted + `다시 시도` 텍스트 버튼(12/w600/`primary`, 높이 44 터치영역, `ref.invalidate(currentUserProfileProvider)`) |
| profile null (방어) | error 와 같은 `-`, 재시도 버튼 없이 `로그인이 필요해요` 12 muted |

**접근성**: 라벨+숫자 묶음을 `Semantics(label: '내 Qoin 잔액 1,200 Q', excludeSemantics: true)` 로 병합. 스크린리더는 숫자 부분을 천 단위로 읽고 `Q` 는 "큐" 로 읽는 것이 일반적이므로 별도 치환 없이 `Q` 유지 (실기기 VoiceOver / TalkBack 확인 항목으로 test 에 전달). 음수는 `-` 를 쓰지 않고 `내 Qoin 잔액 마이너스 100 Q` 로 별도 조립 (owner_sales 와 동일 원칙: 하이픈은 기기별로 읽기가 갈린다). 0 은 `내 Qoin 잔액 0 Q`. loading: `Semantics(label: '잔액을 불러오는 중')`.

#### 1-a. 안내 plate `_QoinPolicyPlate` (카드 내부)

- 배경 `surface`, radius 12, padding `h14 v12`, border 없음. 두 행, 행 간 gap 10.
- 행 구조: `Row(crossAxisAlignment: start)[ Icon(16, textMuted), SizedBox 8, Expanded(Column[주문구, 보조구]) ]`.

**행 1 — 적립 시점 (이 화면에서 가장 중요한 카피)**

| 조건 | 아이콘 | 주문구 (13 / w600 / textBody) | 보조구 (12 / w400 / textMuted / height 1.4, gap 2) |
|---|---|---|---|
| config 정상 (`enabled && rate > 0`) | `Icons.shopping_bag_outlined` | `픽업 완료 시 결제액의 3% 적립` | `결제 직후가 아니라, 매장에서 픽업 완료 처리가 되면 반영돼요` |
| config 로딩 중 / 읽기 실패 / 문서 없음 | 동일 | `픽업 완료 시 적립돼요` (**비율 생략**. 틀린 비율을 보여주지 않는다 — spec §6) | 동일 |
| 적립 중단 (`enabled == false` 또는 `accrualRate == 0`) | `Icons.pause_circle_outline_rounded` (색 `warning`) | `지금은 Qoin 적립이 잠시 중단되어 있어요` | `이 기간에 픽업 완료된 주문은 적립 대상에서 빠질 수 있어요` |

- 중단 상태에서는 **plate 배경을 `warning` alpha 0.10 으로 바꾸고** 글자는 `textBody` 유지. (한계 고지 톤. error 색 아님.)
- 비율 표기 규칙: `accrualRate * 100` 을 소수 1자리로 반올림 후 불필요한 `.0` 제거. `0.03 → 3%`, `0.025 → 2.5%`, `0.07 → 7%` (부동소수 오차 `7.000000000000001` 방지). 카피에 비율 숫자를 하드코딩하지 않는다 (config 에서만).
- config 로딩 → 로드 시 문구가 `픽업 완료 시 적립돼요` → `…결제액의 3% 적립` 으로 바뀌는 것은 허용 (깜빡임 최소화를 위해 애니메이션 없음).

**행 2 — 사용 불가 안내 (U5)**

- 아이콘 `Icons.info_outline_rounded`, 문구 `Qoin 사용은 준비 중이에요` — 13 / w400 / `textBody`. 보조구 없음.
- 톤: 숨기지 않되 기대를 부풀리지 않는다. 시점·약속(`곧`, `업데이트 예정`) 문구 금지.

**접근성**: 각 행을 `Semantics(label: '<주문구>. <보조구>', excludeSemantics: true)`. 아이콘은 장식(`excludeSemantics`).

---

### 2. QoinInProgressBanner (신규·**권장·조건부**, `widgets/qoin_in_progress_banner.dart`)

> 사용자가 가장 오해하기 쉬운 순간 — "방금 결제했는데 Qoin 이 그대로" — 에 정확히 응답하는 요소. **신규 구독 0** (`myOrdersProvider` 는 Log 탭이 이미 구독 중). 금액을 보여주지 않으므로 spec 의 Q3("적립 예정 금액 표시") 범위가 아니다. 단, 스코프 경계에 걸치므로 **사용자 확인 항목**(아래 "잔여 결정 1")으로 둔다. 거절되어도 나머지 설계에 영향 없음.

- 표시 조건: `myOrdersProvider` 가 data 이고 `status ∈ {paid, accepted, making, ready}` 인 주문이 1건 이상. loading / error / 0건이면 **아무것도 렌더하지 않음** (조용히 생략, 에러 노출 금지).
- 위치: 잔액 카드 바로 아래, 내역 헤더 위. `margin: fromLTRB(16, 2, 16, 6)`.
- 구조: `InkWell(radius 12) > Container(padding h16 v12, radius 12, 배경 primaryBright alpha 0.10, border primaryBright alpha 0.30) > Row[ Icon(Icons.schedule_rounded, 20, primary), 10, Expanded(Column[제목, 본문]), Icon(chevron_right_rounded 18 textMuted) ]`
- 제목 `진행 중인 주문이 {n}건 있어요` 13 / w700 / textHeading. 본문 `픽업이 완료되면 Qoin 이 적립돼요` 12 / textBody / height 1.4.
- 탭 → `ref.read(selectedTabIndexProvider.notifier).set(3)` (Log 탭). 하단 chevron 으로 탭 가능 표시.
- 접근성: `Semantics(button: true, label: '진행 중인 주문이 2건 있어요. 픽업이 완료되면 Qoin 이 적립돼요. 탭하면 Log 탭으로 이동')`.

---

### 3. QoinTransactionList / QoinTransactionTile (신규, `widgets/qoin_transaction_tile.dart`)

**섹션 헤더**: `Padding(fromLTRB 20, 16, 20, 8) > Text('Qoin 내역')` 15 / w700 / textHeading, `Semantics(header: true)`. 내역이 loading / data(1건+) / error 일 때 표시. **empty 일 때는 헤더 생략** (빈 상태 블록이 자체 제목을 가짐).

**원장 카드 (컨테이너)**: `margin: symmetric(horizontal: 16)`, 배경 `surfaceElevated`, border `border`, radius 16, `clipBehavior: antiAlias`. 행 사이 `Divider(height: 1, color: border, indent: 16, endIndent: 16)`. 마지막 행 아래 구분선 없음.

**행 `QoinTransactionTile`**

- `InkWell(splash primary alpha 0.04, highlight alpha 0.02) > Padding(h16 v14)`.
- 레이아웃: `Row(crossAxisAlignment: start)[ 아이콘 원 32, 12, Expanded(Column 좌), 12, Column 우(end), (chevron) ]`.

| 영역 | 내용 | 스타일 |
|---|---|---|
| 아이콘 원 | 32x32 원. 적립 `Icons.add_rounded` / 회수 `Icons.undo_rounded` / 미지 `Icons.swap_vert_rounded`. 색은 위 "색상 사용" 표 | 글리프 18 |
| 좌 1행 | 매장명 `storeName` | 14 / w600 / textHeading / 1줄 ellipsis. 빈 문자열이면 `Qoin 내역` 으로 대체 |
| 좌 2행 (gap 2) | 사유 | 12 / w400 / textBody / 최대 2줄 (아래 사유 표) |
| 좌 3행 (gap 2) | 일시 | 12 / textMuted. `10월 22일 (수) 14:35`. 올해가 아니면 `2025년 12월 31일 14:35`. 요일은 `DateFormat('E','ko_KR')` |
| 우 1행 | 증감액 | 16 / w700 (적립) 또는 w600 (회수) / `FittedBox(scaleDown)` / tabularFigures |
| 우 2행 (gap 4) | 거래 후 잔액 | `잔액 1,200 Q` 11 / textMuted / tabularFigures |
| 끝 | `Icons.chevron_right_rounded` 18 / textMuted — **`orderId` 가 있는 행만** | 우측 열과 gap 4 |

**증감액 표기**

| 종류 | 표기 | 색 | 굵기 |
|---|---|---|---|
| 적립 (amount > 0) | `+540 Q` | `textHeading` | w700 |
| 회수 (amount < 0) | `-540 Q` | `textMuted` | w600 |
| 미지 타입 | **금액의 부호 그대로** `+100 Q` / `-100 Q` (색·굵기는 부호가 양수면 적립 규칙, 음수면 회수 규칙) | | |

- **적립/회수 판정은 `type` 이 아니라 `amount` 의 부호로** 한다 (spec §10.4 — 미지 타입 전방 호환). `type` 은 사유 문구 선택에만 쓴다.
- 회수 행에 취소선·dim·error 색 **금지** (환불 표시와 같은 원칙). 회수는 "사실" 이다.

**사유 문구 (2행)**

| type | 사유 문구 |
|---|---|
| `earn` | `픽업 완료 적립 · 결제액 {orderTotalPrice}원의 {rate}%` (예: `픽업 완료 적립 · 결제액 18,000원의 3%`) |
| `clawback` | `환불로 회수` (예: 보조 설명 없이 한 줄. 환불된 주문의 적립이 되돌려졌다는 사실만 전달) |
| 그 외(미지) | `Qoin 조정` (중립. 금액은 부호대로) |

- `{rate}%` 는 거래 문서의 `accrualRate` (거래 당시 값) 를 위 비율 표기 규칙으로 변환. 현재 config 값이 아니다.
- `orderTotalPrice` 는 `PriceFormatter.formatKrw` 의 콤마 포맷 재사용 (`원` 포함 문자열 그대로).
- `accrualRate`/`orderTotalPrice` 가 누락·비정상인 거래 문서면 `earn` 도 `픽업 완료 적립` 까지만 표시 (방어).

**인터랙션**

- `orderId` 가 있으면 행 전체 탭 → `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: tx.orderId)))` (`OrdersPage` 와 동일).
- `orderId` 가 비어 있으면 탭 비활성, chevron 숨김, InkWell 피드백 없음.
- 주문 상세에서 주문 문서를 못 찾는 경우의 처리는 기존 `OrderDetailPage` 에 위임 (이 task 범위 밖).

**접근성** (`Semantics(button: orderId 있음, excludeSemantics: true)`, 시각 텍스트는 ExcludeSemantics)

| 종류 | 읽기 문구 |
|---|---|
| 적립 | `{매장명}, 540 Q 적립, 결제액 18,000원의 3%, 10월 22일 14시 35분, 적립 후 잔액 1,200 Q. 탭하면 주문 상세` |
| 회수 | `{매장명}, 540 Q 회수, 환불로 회수, 10월 22일 15시 10분, 회수 후 잔액 660 Q. 탭하면 주문 상세` |
| 미지 | `{매장명}, 100 Q 증가(또는 감소), Qoin 조정, …` |

- **음수 하이픈을 읽기 문구에 쓰지 않는다.** 금액은 항상 양수로 조립하고 `적립` / `회수` 동사로 방향을 전달한다 (owner_sales 선례). 잔액이 음수인 방어 케이스만 `마이너스 100 Q`.
- 일시는 `14:35` 대신 `14시 35분` 로 별도 조립.

**50건 상한 푸터**: 내역이 정확히 50건(상한)일 때만 카드 아래 `Padding(h20 v16)`, 중앙, 12 / textMuted, `최근 50건을 보여드려요`. 숫자 `50` 은 쿼리 limit 상수에서 가져와 포맷 (카피에 하드코딩 금지).

---

### 4. QoinStatusBlock (신규 공용 상태 블록, `widgets/qoin_status_block.dart`)

- 파라미터: `icon`, `iconColor`, `title`, `message?`, `actionLabel?`, `onAction?`.
- 구조: `Padding(top 32, h32) > Column(min, center)[ Icon, 12, Text(title), 6, Text(message), 16, 버튼 ]` — `Center` 로 전체를 채우지 않는다 (잔액 카드를 밀어내지 않도록 **ListView 안에 인라인** 배치).
- 아이콘 크기 56. 제목 16 / w600 / textHeading. 보조 13 / textMuted / 중앙 / height 1.4.
- 버튼(재시도): 높이 44, radius 12, 최소 너비 160, 배경 `surfaceElevated`, border `primary` 1.5, 글자 `primary` 14 / w600. (owner_sales 외곽선 버튼과 동일 톤. `orders_page` 의 채움 버튼 대신 이 규격으로 통일 — 두 화면이 한 앱 안에서 다르게 생겨 보이지 않는 것보다, 최근 기준(owner_sales)을 따른다.)

---

## 상태별 UI — 고객 Qoin 탭

### 잔액 (프로필 스트림)

위 1번 컴포넌트의 상태 표 참조.

### 내역 (`qoinTransactionsProvider`)

| 상태 | 표현 |
|---|---|
| **Loading** | 섹션 헤더 + 원장 카드 안에 skeleton 4행. 행: 좌 32 원(`border`), 우측 두 줄 박스(제목 높이 14 너비 120, 사유 높이 12 너비 180, 일시 높이 12 너비 90, radius 6), 맨 오른쪽 금액 박스(높이 16 너비 64). `orders_page._buildShimmer` 와 같은 정적 박스 방식 (색 `AppColors.border`) |
| **Data (1건+)** | 원장 카드 + (50건이면 푸터) |
| **Empty (0건)** | 헤더 생략. `QoinStatusBlock(icon: Icons.toll_rounded, iconColor: textMuted, title: '아직 적립된 Qoin 이 없어요', message: '주문이 픽업 완료되면 여기에 쌓여요.\n결제 직후에는 보이지 않을 수 있어요')` — **액션 버튼 없음** (적립을 위해 사용자가 할 수 있는 즉각 행동은 "주문하기" 뿐인데, 하단 FAB 가 이미 그 진입점이다) |
| **Error (일반)** | 헤더 유지 + `QoinStatusBlock(icon: Icons.error_outline_rounded, iconColor: error, title: '내역을 불러오지 못했어요', message: '잠시 후 다시 시도해주세요', actionLabel: '다시 시도', onAction: invalidate(qoinTransactionsProvider))` |
| **Error (permission-denied)** | 동일 구조, message 만 `권한 문제로 불러오지 못했어요. 계속되면 문의해주세요` (Rules 블록 누락의 1차 증상을 일반 네트워크 실패와 구분 — spec §9.2). `e.toString()` 을 화면에 노출하지 않는다 |
| 잔액 > 0 인데 내역 0건 | 별도 처리 없음. 두 블록은 독립적으로 각자 상태대로 렌더 |

- **빈 상태는 흰 화면도 에러도 아니다**: 신규 사용자는 `0 Q` 가 박힌 잔액 카드 + 적립 시점 plate + `아직 적립된 Qoin 이 없어요` 블록을 한 화면에서 모두 본다. 첫 방문에 "무엇이 언제 쌓이는지" 가 세 번(plate / 빈 상태 / (진행 중 주문 있으면) 배너) 설명되는 구성이다.
- 에러 블록은 ListView 안에서 렌더 (잔액 카드는 계속 보임).

---

# 2. 관리자 Qoin 설정 — `AdminQoinSettingsPage`

## 진입

- `AdminMorePage` 의 `메인 카테고리 관리` 타일 **바로 아래** 신규 타일 (로그아웃 위):
  - 아이콘 `Icons.toll_rounded` (22, textBody)
  - 제목 `Qoin 설정`
  - 부제 (config 로드 시): `적립률 3% · 적립 중` / `적립률 3% · 적립 중단됨` / 문서 없음 `설정되지 않음`. 로딩·에러 시 부제 생략 (타일은 항상 탭 가능). 부제는 12 / textMuted (기존 `_Tile` 규격 그대로)
  - 탭 → `Navigator.push(MaterialPageRoute<void>(builder: (_) => const AdminQoinSettingsPage()))`
- 부제를 두는 이유: 목록 화면에서 **현재 적립이 켜져 있는지** 를 진입 없이 확인할 수 있다 (운영 안전장치 가시성).

## 화면 구성

```
┌ AppBar  ‹  Qoin 설정 ─────────────┐  뒤로가기 + 17/w700 (메인 카테고리 폼과 동일)
├───────────────────────────────────┤
│ ┌ 현재 적용 중 ─────────────────┐ │
│ │ 현재 적용 중        [적립 중]  │ │
│ │ 3%                  (28/w800)  │ │
│ │ 결제 10,000원 → 300 Q 적립     │ │
│ └───────────────────────────────┘ │
│ ┌ 적립 사용 ────────────────────┐ │
│ │ 적립 사용                 [●━] │ │
│ │ 픽업 완료된 주문에 Qoin 을 적립해요│ │
│ └───────────────────────────────┘ │
│ 적립률                            │  라벨 12/w600 muted
│ ┌────────────────────────── % ┐ │
│ └───────────────────────────────┘ │
│ 0.1 ~ 20% 사이로 입력해요. 3% 는 3 으로… │  11 muted
│ ┌ 미리보기 (surface plate) ─────┐ │
│ │ 결제 10,000원 → 500 Q 적립     │ │
│ └───────────────────────────────┘ │
│ 고객 Qoin 탭에 '픽업 완료 시 결제액의 N% 적립'으로 표시돼요 │
│ [        저장 (52h)            ] │
└───────────────────────────────────┘
```

- 본문: `SingleChildScrollView(padding: symmetric(h20, v24))`, 섹션 간 gap 20. AppBar/배경/뒤로가기는 `AdminMainCategoryFormPage` 와 동일 (`background`, elevation 0, surfaceTint transparent).
- 키보드 노출 시 저장 버튼이 가려지지 않도록 스크롤 가능(`resizeToAvoidBottomInset` 기본값). 입력창 포커스 시 자동 스크롤.

### A. 현재 적용 중 카드 `_CurrentConfigCard`

- 서버(`config/qoin` 스트림) 값을 **읽기 전용**으로 표시. 입력값(초안)과 분리된 "지금 실제로 적용되는 값" 이다 — 변경 전후 비교의 기준이자 저장 성공의 시각적 확인.
- 컨테이너: `surfaceElevated` + border + radius 16 + padding 20.
- 행 1: 라벨 `현재 적용 중` 13 / w600 / textMuted, 우측 상태 pill. 행 2 (gap 4): 적립률 `3%` 28 / w800 / textHeading / tabularFigures. 행 3 (gap 8): `결제 10,000원 → 300 Q 적립` 13 / textBody.
- 상태 pill (높이 24, h-padding 10, radius 999, 12 / w600):
  - 적립 중 (`enabled == true`): 배경 `primaryBright` alpha 0.15, 글자 `primary`, 라벨 `적립 중`
  - 중단됨 (`enabled == false`): 배경 `warning` alpha 0.15, 글자 `textBody`, 라벨 `적립 중단됨`
- 문서 없음(fail-closed 상태): 적립률 자리 `설정 없음` (28 → 20 / w700 / textMuted), pill `적립 중단됨`, 행 3 대신 warning plate `설정이 없어서 적립이 동작하지 않아요. 적립률을 저장해 설정을 만들어주세요`.
- 접근성: `Semantics(label: '현재 적용 중. 적립률 3퍼센트, 적립 중. 결제 10,000원이면 300 Q 적립', excludeSemantics: true)`.

### B. 적립 사용 스위치 카드 `_EnabledSwitchCard` — **즉시 반영, 적립률 폼과 독립**

- 컨테이너: `surfaceElevated` + border + radius 14 + padding `h16 v14`. 행: `Row[ Expanded(Column[제목 15/w500 textBody, 부제 12 textMuted]), Switch.adaptive ]` (`active` 스위치 스타일 그대로: `activeThumbColor primary`, `activeTrackColor primaryBright alpha 0.3`, `inactiveThumbColor textMuted`, `inactiveTrackColor surface`).
- 제목 `적립 사용`.
- 부제: ON → `픽업 완료된 주문에 Qoin 을 적립해요` / OFF → `지금은 적립과 환불 회수가 모두 멈춰 있어요`.
- **스위치 변경은 서버 값이 바뀔 때만 시각이 바뀐다.** 탭 즉시 낙관적으로 뒤집지 않는다 (다이얼로그 취소 시 되돌릴 필요 없음, 저장 실패 시 거짓 상태 없음). 탭 → 확인 다이얼로그 → 확정 시 저장 → 스트림 갱신으로 반영.
- 저장 중: 스위치 `onChanged: null` + 카드 우측에 16x16 `CircularProgressIndicator(strokeWidth 2, primary)` (스위치 왼쪽 gap 8). 중복 탭 방지.
- config 로딩/에러/문서 없음일 때: 스위치 비활성 (`onChanged: null`). 문서 없음에서는 `설정 없음 — 먼저 적립률을 저장해주세요` 11 muted 를 카드 아래 gap 4.

**다이얼로그 B-1 — 끄기 (`AlertDialog`, `surfaceElevated`, radius 16)**

| 항목 | 값 |
|---|---|
| 제목 | `Qoin 적립을 중단할까요?` (17 / w700 / textHeading) |
| 본문 (13 / textBody / height 1.5) | `지금부터 아래 동작이 모두 멈춰요.` |
| 항목 1 | `• 픽업이 완료되어도 Qoin 이 적립되지 않아요` |
| 항목 2 | `• 이미 적립된 주문이 환불되어도 Qoin 이 회수되지 않아요` |
| 항목 3 | `• 중단 중에 픽업 완료된 주문은 다시 켜도 자동으로 적립되지 않아요` |
| 안내 | `고객 Qoin 탭에는 ‘적립이 잠시 중단되어 있어요’ 가 표시돼요` (12 / textMuted) |
| 취소 버튼 | `취소` (outlined, 기존 폼 취소 버튼 규격) |
| 확인 버튼 | `적립 중단` (`primary` 채움). **error 색 쓰지 않음** — 정지 장치는 정상 운영 도구이며 위험은 본문이 전달한다 |

- 항목 2 가 핵심: 끄면 **환불 회수도 멈춘다**(spec §5.5). 이를 모르고 끄면 환불된 고객이 Qoin 을 그대로 갖는다. admin 이 켜고 끄는 결정을 정확한 정보로 하게 한다.

**다이얼로그 B-2 — 켜기**

| 항목 | 값 |
|---|---|
| 제목 | `Qoin 적립을 다시 시작할까요?` |
| 본문 | `지금 설정된 적립률 3% 로, 이후 픽업 완료되는 주문부터 적립돼요. 중단된 동안 완료된 주문은 소급 적립되지 않아요.` (`3%` 는 서버 현재 값) |
| 버튼 | `취소` / `적립 시작` |

- 켜기에도 확인을 두는 이유: 돈 발행이 재개되는 동작이고, 현재 적립률을 한 번 더 보여줄 기회다. 문서 없음 상태에서는 스위치가 비활성이라 이 다이얼로그에 도달하지 않는다.

### C. 적립률 입력 `_RateField` + 미리보기

- 섹션 라벨 `적립률` (12 / w600 / textMuted, gap 6) — 기존 `_FormSection` 규격.
- 입력창: 기존 `_buildTextField` 규격(`surfaceElevated`, border radius 10, 포커스 `primary`, 글자 `18 / w600 / textBody` (기존 폼 15 보다 키움) — 이 값은 가장 중요한 입력이므로 한 단계 키움). **접미사 `%` 를 입력창 안 우측에 고정** (`suffixText: '%'`, 글자 `18 / w600 / textMuted`) — 사용자가 단위를 "입력"할 필요도 오해할 여지도 없다.
- 키보드: `TextInputType.numberWithOptions(decimal: true)`. 입력 필터: 숫자와 점 1개만, 소수 1자리, 최대 4자(`20.0`). 힌트 텍스트 `예: 3`.
- 초기값: 서버 현재 `accrualRate * 100` (예 `3`). 문서 없음이면 비워 둠.
- 도움말 (11 / textMuted, gap 4): `0.1 ~ 20% 사이로 입력해요. 3% 는 ‘3’ 으로 입력하세요 (0.03 이 아니에요)`.
- **검증 (입력 중 실시간, 에러는 입력창 아래 11 / `error`)**

| 입력 | 에러 문구 | 저장 |
|---|---|---|
| 비어 있음 | (표시 없음) | 비활성 |
| 숫자 아님 / `.` 만 | (표시 없음) | 비활성 |
| `< 0.1` (예: `0.03`, `0`) | `0.1% 이상 입력해주세요. 3% 는 ‘3’ 으로 입력해요` | 비활성 |
| `> 20` (예: `30`, `300`) | `최대 20% 까지 입력할 수 있어요` | 비활성 |
| 서버 현재 값과 동일 | (표시 없음) | 비활성 (변경 없음) |
| 유효 + 변경됨 | — | 활성 |

- 하한 `0.1` 이 `0.03` → 100배 사고의 **핵심 차단선**이다. `0.03` 이 `0.1` 미만이므로 반드시 걸린다. `0` 으로 적립을 끄는 것은 지원하지 않는다 (끄기는 스위치의 역할 — 의미 중복·모호성 제거).
- 상·하한 숫자(0.1 / 20)는 단일 상수로 두고 카피·검증이 함께 참조한다 (카피에 숫자 하드코딩 금지).

- **미리보기 plate** (입력창 아래 gap 12): 배경 `surface`, radius 12, padding `h14 v12`. 한 줄 `결제 10,000원 → 500 Q 적립` — `10,000원` 13 / textBody, 환산 결과 `500 Q` 15 / w700 / textHeading. 값은 입력 유효 시에만 갱신, 무효·비어 있으면 `—` (`결제 10,000원 → — Q`). 환산은 **버림(floor)** 이며 정수 연산으로 계산해 부동소수 오차(`0.07 * 10000`)를 피한다. 예시 결제액 `10,000원` 은 상수.
- 하단 캡션 (gap 8): `고객 Qoin 탭에 ‘픽업 완료 시 결제액의 N% 적립’ 으로 표시돼요` 11 / textMuted.

### D. 저장 버튼

- 높이 52, radius 12, 폭 전체. 활성: `primary` / 글자 `onPrimary` 15 / w600, 라벨 `저장`. 비활성: 배경 `textMuted`. 저장 중: 20x20 인디케이터(`onPrimary`), `onPressed: null`. (기존 폼 규격 그대로. 취소 버튼은 두지 않음 — 뒤로가기가 취소.)
- 탭 → **확인 다이얼로그 C-1** (항상).

**다이얼로그 C-1 — 적립률 변경 확인**

```
 적립률을 변경할까요?
 ┌─────────────────────────────┐
 │  현재          변경           │   라벨 12 muted
 │  3%    →     5%               │   20/w800, 변경 값 textHeading, 현재 값 textMuted, 화살표 muted
 └─────────────────────────────┘
 10,000원 결제 기준
 300 Q  →  500 Q
 [경고 줄: 조건부]
 변경 후 픽업이 완료되는 주문부터 적용돼요.
 이미 적립된 Qoin 은 바뀌지 않아요.
        [취소]   [변경하기]
```

| 요소 | 스타일 |
|---|---|
| 제목 | `적립률을 변경할까요?` 17 / w700 |
| 비교 블록 | `surface` plate radius 12 padding 16, 가운데 `Icons.arrow_forward_rounded` 18 muted. 좌 `현재` 값 20 / w700 / textMuted, 우 `변경` 값 20 / w800 / textHeading |
| 환산 줄 | 13 / textBody: `10,000원 결제 기준 300 Q → 500 Q` |
| 경고 줄 (조건부) | `변경 값이 현재의 2배 이상이거나 10% 이상이에요. 입력값이 맞는지 한 번 더 확인해주세요` — warning 10% 틴트 + `Icons.info_outline_rounded` warning + 글자 `textBody` 12 / w600. **조건: 새 값 ≥ 현재 × 2 또는 새 값 ≥ 10%** (인상일 때만. 인하는 경고 없음). 문서 없음(현재 값 없음)에서 처음 저장할 때도 새 값 ≥ 10% 면 표시 |
| 안내 | `변경 후 픽업이 완료되는 주문부터 적용돼요. 이미 적립된 Qoin 은 바뀌지 않아요` 12 / textMuted |
| 버튼 | `취소`(outlined) / `변경하기`(`primary` 채움) |

- 문서 없음 첫 저장: 비교 블록의 현재 값은 `설정 없음`, 하단에 `적립은 ‘적립 사용’ 을 켜야 시작돼요` 한 줄 추가.

### 저장 결과 피드백

| 상황 | 피드백 |
|---|---|
| 적립률 저장 성공 | SnackBar `적립률을 5% 로 변경했어요`. **페이지에 머문다** (pop 하지 않음) — 위 "현재 적용 중" 카드가 새 값으로 바뀌는 것이 시각 확인이다. 저장 버튼은 다시 비활성(변경 없음) |
| 적립률 저장 실패 | SnackBar `저장에 실패했어요. 다시 시도해주세요`. 입력값 유지, 버튼 재활성 |
| 적립 중단 성공 | SnackBar `Qoin 적립을 중단했어요` |
| 적립 시작 성공 | SnackBar `Qoin 적립을 시작했어요` |
| 스위치 저장 실패 | SnackBar `변경하지 못했어요. 다시 시도해주세요`. 스위치는 서버 값 그대로(낙관 변경 안 했으므로 복구 불필요) |

- 토스트 문구는 기존 폼의 `…했어요` / `처리에 실패했어요. 다시 시도해주세요` 어미를 계승.

## 상태별 UI — 관리자 설정

| 상태 | 표현 |
|---|---|
| **Loading** (config 스트림) | 본문 중앙 `CircularProgressIndicator(color: primary)`. 입력·스위치·저장 모두 **노출하지 않음** (값을 모른 채 덮어쓰는 사고 방지) |
| **Error** | 본문 중앙 `Icons.error_outline_rounded` 48 `error` + `설정을 불러오지 못했어요` 16 / w600 + `잠시 후 다시 시도해주세요` 13 muted + `다시 시도` 외곽선 버튼 (`ref.invalidate`). 입력·저장 노출 안 함 |
| **문서 없음** | 정상 레이아웃으로 렌더하되 위 A 의 "설정 없음" 변형. 스위치 비활성. 적립률 입력·저장 가능 |
| **서버 값 변경 (다른 admin / Console)** | "현재 적용 중" 카드는 실시간 갱신. **입력창의 초안은 덮어쓰지 않는다.** 저장 시 다이얼로그의 `현재` 는 그 시점의 서버 값을 쓴다 |

## 접근성 — 관리자

- 입력창: `Semantics(label: '적립률, 퍼센트. 3퍼센트를 원하면 3을 입력', textField: true)`. 접미사 `%` 는 장식(`excludeSemantics`).
- 스위치: `Semantics(label: 'Qoin 적립 사용', toggled: enabled, hint: '끄면 적립과 환불 회수가 모두 멈춰요')`.
- 검증 에러는 `liveRegion` 으로 읽히게 (`errorText` 기본 동작 확인).
- 다이얼로그 비교 블록: `Semantics(label: '적립률을 현재 3퍼센트에서 5퍼센트로 변경. 10,000원 결제 기준 300 Q에서 500 Q')`.
- 모든 터치 타깃 ≥ 44.

---

## 기존 위젯 재사용 / 신규 구분

| 구분 | 항목 |
|---|---|
| **재사용 (수정 없음)** | `AppColors` 전 토큰, `QLogo`, `PriceFormatter.formatKrw`(결제액 `원` 표기), `OrderDetailPage`, `currentUserProfileProvider`, `myOrdersProvider`·`selectedTabIndexProvider`(배너), `AdminMorePage._Tile` 규격, `AdminMainCategoryFormPage` 의 폼 규격(AppBar / 섹션 라벨 / 입력창 데코 / 스위치 / 52px 버튼) |
| **수정** | `qoin_page.dart` 전면 교체, `AdminMorePage` 타일 1개 추가 (부제용으로 config provider 를 watch) |
| **신규 (customer)** | `QoinBalanceCard`, `QoinTransactionTile`(+ 내역 카드 래퍼 / skeleton), `QoinStatusBlock`, `QoinInProgressBanner`(권장·조건부) |
| **신규 (admin)** | `AdminQoinSettingsPage`, 내부 위젯 `_CurrentConfigCard` / `_EnabledSwitchCard` / `_RateField` / `_RatePreview`, 다이얼로그 3종(끄기 / 켜기 / 적립률 변경 확인) |
| **신규 (유틸)** | Qoin 금액 포맷터 (`1,200 Q`, 부호 포함 `+540 Q` / `-540 Q`, 접근성용 양수 조립) — `PriceFormatter._grouped` 는 private 이므로 콤마 포맷은 `NumberFormat('#,###')` 로 별도 구현. 비율 표기 헬퍼(`0.03 → '3%'`, 반올림 + `.0` 제거). 두 곳(고객 plate / 관리자)에서 같은 헬퍼를 써야 표시가 일치한다 |
| **`_FormSection` 중복 주의** | `AdminMainCategoryFormPage` 의 `_FormSection`·`_buildTextField` 는 private. 새 페이지에서 **복제하거나 공용 위젯으로 추출**할지는 developer 판단 (기존 화면 수정 범위가 늘면 복제 권장) |

---

## 개발자 전달 특이사항

1. **카피 전부는 아래 "카피 문자열 일람" 의 그대로 쓴다.** 특히 적립 시점 문구는 임의 수정 금지 (`결제 시 적립` 류 금지).
2. 적립률 `%` 표기는 config 값 → 표시 한 경로만 거친다. 카피 내 `3%` 하드코딩 금지.
3. **로딩 중 `0 Q` 렌더 금지.** `AsyncValue.when` 의 loading 분기를 반드시 skeleton 으로.
4. 적립/회수 판정은 `amount` 부호 기준. `type` 은 사유 문구 선택에만.
5. 스크린리더용 문구에 음수 하이픈 사용 금지 (적립 / 회수 동사로 조립).
6. 관리자 스위치는 **낙관적 업데이트 금지** — 서버 스트림 값으로만 표시.
7. 관리자 적립률 환산(미리보기·다이얼로그)은 **정수 연산** 사용. `rate` 저장값은 `round(percent * 10) / 1000` 형태로 소수 오차 없이 만든다 (0.1% 단위이므로).
8. 문서 없음 상태에서 **적립률을 처음 저장할 때 `enabled` 의 초기값은 `false`** 로 만들 것을 권장 (fail-closed 유지, 사용자가 의도적으로 켜게). → 잔여 결정 2.
9. `HomeHeader` 가 `tabbed` 모드에서 Qoin 탭 제목을 이미 표시하는지 확인할 것. 표시한다면 잔액 카드 위에 별도 제목을 추가하지 않는다(현 명세도 제목 없음). 표시하지 않는다면 잔액 카드 라벨 `내 Qoin` 이 제목 역할을 한다.
10. 이 명세에 **2차 UI(사용·선물·적립 예정 금액·기간 필터)는 없다**. 잔액 카드에 "사용하기" 류 비활성 버튼도 두지 않는다.

---

## 카피 문자열 일람 (그대로 사용)

### 고객 Qoin 탭

| 위치 | 문자열 |
|---|---|
| 잔액 카드 라벨 | `내 Qoin` |
| 잔액 표기 | `{n} Q` (예 `1,200 Q`, `0 Q`) |
| 잔액 오류 | `잔액을 불러오지 못했어요` / 버튼 `다시 시도` |
| 잔액 비로그인(방어) | `로그인이 필요해요` |
| plate 행1 (정상) 주문구 | `픽업 완료 시 결제액의 {rate}% 적립` |
| plate 행1 (정상) 보조구 | `결제 직후가 아니라, 매장에서 픽업 완료 처리가 되면 반영돼요` |
| plate 행1 (비율 모름) 주문구 | `픽업 완료 시 적립돼요` |
| plate 행1 (중단) 주문구 | `지금은 Qoin 적립이 잠시 중단되어 있어요` |
| plate 행1 (중단) 보조구 | `이 기간에 픽업 완료된 주문은 적립 대상에서 빠질 수 있어요` |
| plate 행2 | `Qoin 사용은 준비 중이에요` |
| 진행 중 배너 제목 | `진행 중인 주문이 {n}건 있어요` |
| 진행 중 배너 본문 | `픽업이 완료되면 Qoin 이 적립돼요` |
| 내역 섹션 제목 | `Qoin 내역` |
| 적립 사유 | `픽업 완료 적립 · 결제액 {금액}원의 {rate}%` |
| 회수 사유 | `환불로 회수` |
| 미지 타입 사유 | `Qoin 조정` |
| 매장명 비어 있을 때 | `Qoin 내역` |
| 증감액 | `+{n} Q` / `-{n} Q` |
| 거래 후 잔액 | `잔액 {n} Q` |
| 50건 푸터 | `최근 50건을 보여드려요` |
| 빈 상태 제목 | `아직 적립된 Qoin 이 없어요` |
| 빈 상태 보조 | `주문이 픽업 완료되면 여기에 쌓여요.` + 줄바꿈 + `결제 직후에는 보이지 않을 수 있어요` |
| 내역 오류 제목 | `내역을 불러오지 못했어요` |
| 내역 오류 보조 | `잠시 후 다시 시도해주세요` |
| 내역 오류 (권한) 보조 | `권한 문제로 불러오지 못했어요. 계속되면 문의해주세요` |
| 재시도 버튼 | `다시 시도` |
| 접근성 (잔액) | `내 Qoin 잔액 {n} Q` / 음수 `내 Qoin 잔액 마이너스 {n} Q` / 로딩 `잔액을 불러오는 중` |
| 접근성 (적립 행) | `{매장명}, {n} Q 적립, 결제액 {금액}원의 {rate}%, {M월 d일 H시 m분}, 적립 후 잔액 {n} Q. 탭하면 주문 상세` |
| 접근성 (회수 행) | `{매장명}, {n} Q 회수, 환불로 회수, {M월 d일 H시 m분}, 회수 후 잔액 {n} Q. 탭하면 주문 상세` |

### 관리자

| 위치 | 문자열 |
|---|---|
| 더보기 타일 제목 | `Qoin 설정` |
| 더보기 부제 | `적립률 {rate}% · 적립 중` / `적립률 {rate}% · 적립 중단됨` / `설정되지 않음` |
| AppBar | `Qoin 설정` |
| 현재 카드 라벨 | `현재 적용 중` |
| 상태 pill | `적립 중` / `적립 중단됨` |
| 환산 줄 | `결제 10,000원 → {n} Q 적립` |
| 문서 없음 | `설정 없음` / `설정이 없어서 적립이 동작하지 않아요. 적립률을 저장해 설정을 만들어주세요` |
| 스위치 제목 | `적립 사용` |
| 스위치 부제 ON | `픽업 완료된 주문에 Qoin 을 적립해요` |
| 스위치 부제 OFF | `지금은 적립과 환불 회수가 모두 멈춰 있어요` |
| 스위치 비활성(문서 없음) | `설정 없음 — 먼저 적립률을 저장해주세요` |
| 끄기 다이얼로그 제목 | `Qoin 적립을 중단할까요?` |
| 끄기 다이얼로그 본문 | `지금부터 아래 동작이 모두 멈춰요.` |
| 끄기 항목 1 | `• 픽업이 완료되어도 Qoin 이 적립되지 않아요` |
| 끄기 항목 2 | `• 이미 적립된 주문이 환불되어도 Qoin 이 회수되지 않아요` |
| 끄기 항목 3 | `• 중단 중에 픽업 완료된 주문은 다시 켜도 자동으로 적립되지 않아요` |
| 끄기 안내 | `고객 Qoin 탭에는 ‘적립이 잠시 중단되어 있어요’ 가 표시돼요` |
| 끄기 버튼 | `취소` / `적립 중단` |
| 켜기 다이얼로그 제목 | `Qoin 적립을 다시 시작할까요?` |
| 켜기 다이얼로그 본문 | `지금 설정된 적립률 {rate}% 로, 이후 픽업 완료되는 주문부터 적립돼요. 중단된 동안 완료된 주문은 소급 적립되지 않아요.` |
| 켜기 버튼 | `취소` / `적립 시작` |
| 입력 섹션 라벨 | `적립률` |
| 입력 힌트 | `예: 3` |
| 입력 접미사 | `%` |
| 도움말 | `0.1 ~ 20% 사이로 입력해요. 3% 는 ‘3’ 으로 입력하세요 (0.03 이 아니에요)` |
| 에러 (하한) | `0.1% 이상 입력해주세요. 3% 는 ‘3’ 으로 입력해요` |
| 에러 (상한) | `최대 20% 까지 입력할 수 있어요` |
| 미리보기 | `결제 10,000원 → {n} Q 적립` / 무효 `결제 10,000원 → — Q` |
| 하단 캡션 | `고객 Qoin 탭에 ‘픽업 완료 시 결제액의 N% 적립’ 으로 표시돼요` |
| 저장 버튼 | `저장` |
| 변경 다이얼로그 제목 | `적립률을 변경할까요?` |
| 변경 비교 라벨 | `현재` / `변경` |
| 변경 환산 | `10,000원 결제 기준 {a} Q → {b} Q` |
| 변경 경고 | `변경 값이 현재의 2배 이상이거나 10% 이상이에요. 입력값이 맞는지 한 번 더 확인해주세요` |
| 변경 안내 | `변경 후 픽업이 완료되는 주문부터 적용돼요. 이미 적립된 Qoin 은 바뀌지 않아요` |
| 변경 (문서 없음) 추가 | `적립은 ‘적립 사용’ 을 켜야 시작돼요` |
| 변경 버튼 | `취소` / `변경하기` |
| 성공 SnackBar | `적립률을 {rate}% 로 변경했어요` / `Qoin 적립을 중단했어요` / `Qoin 적립을 시작했어요` |
| 실패 SnackBar | `저장에 실패했어요. 다시 시도해주세요` / `변경하지 못했어요. 다시 시도해주세요` |
| 설정 로드 오류 | `설정을 불러오지 못했어요` / `잠시 후 다시 시도해주세요` / `다시 시도` |

> 용어 표기: 문장 안 `Qoin 이` / `Qoin 을` 은 띄어쓰기 형태로 통일했다 (`Qoin`이 외래어 고유 명사이므로 조사 분리). 앱 내 기존 카피(`주문 상세`, `다시 시도`)와 어미(`~했어요`, `~돼요`)를 맞췄다.

---

## 완료 기준 (디자인 관점)

- [ ] 신규 사용자 화면에 `0 Q` + 적립 시점 plate + 빈 상태 블록이 모두 보이고 흰 화면·에러가 없다
- [ ] 로딩 중 잔액 자리에 `0 Q` 가 나타나지 않는다
- [ ] `결제 시 적립` 류 문구가 코드·카피 어디에도 없다
- [ ] 적립/회수 구분이 색 없이도(부호 + 아이콘 + 사유 문구) 성립한다
- [ ] 회수 행에 `error` 색 / 취소선 / dim 이 없다
- [ ] `Color(0x...)` 직접 사용 0건, 신규 토큰 0개
- [ ] 관리자: `0.03` 입력 시 저장이 막히고 에러가 보인다 / `30` 입력 시 막힌다
- [ ] 관리자: 적립 끄기 다이얼로그에 "환불 회수도 멈춘다" 가 보인다
- [ ] 관리자: 적립률 저장 시 현재 → 변경 비교가 항상 보인다
- [ ] 스크린리더 라벨에 음수 하이픈이 없다
- [ ] 텍스트 스케일 1.5x 에서 겹침·잘림 없음 (잔액 FittedBox, 금액 FittedBox, 사유 2줄)

---

## 잔여 결정 확정 (2026-10-22)

designer 가 남긴 6건을 확정한다. **본 절이 design 본문의 해당 제안보다 우선한다.**

| # | 항목 | 확정 | 사유 |
|---|---|---|---|
| **1** | 진행 중 주문 배너 | **포함** — 사용자 직접 확인 | `paid`~`ready` 주문이 있을 때 `진행 중인 주문이 N건 있어요 / 픽업이 완료되면 Qoin 이 적립돼요`. 오늘 평가 기능에서 **실제로 발생한 오해**("반영이 안 됐다")를 그 순간에 막는다. 기존 `myOrdersProvider` 재사용이라 신규 구독 0개 |
| **4** | 중지 기간 소급 적립 | **없음** — 사용자 직접 확인 | 끄기 다이얼로그에서 명시한다. 필요 시 Console 로 개별 재트리거 가능. 소급을 지원하면 기간 재조회·중복 적립 방지 로직이 붙어 1차가 커진다 |
| **2** | `config/qoin` 부재 시 초기 `enabled` | **`false`** (수용) | fail-closed 유지. 적립은 **의도적으로 켜야** 시작된다. 이때 스위치는 비활성 |
| **3** | 적립률 범위 0.1~20%, 소수 1자리 | **채택** (수용) | **하한 0.1 이 `0.03` 오입력의 차단선**이다. 0.01% 단위를 요구하면 이 방어선이 무너지므로 먼저 재검토해야 한다 |
| **5** | `Qoin 사용은 준비 중이에요` 톤 | **채택** (수용) | `곧` / `예정` 같은 시점 약속을 넣지 않은 것이 맞다. 2차 일정이 확정되지 않았다 |
| **6** | 스크린리더 `Q` 발음 | **tester 실기 확인 항목으로 이관** | VoiceOver / TalkBack 이 `Q` 를 "큐" 로 읽는지 코드로 알 수 없다 |

### 1번 확정의 의미

이 배너는 **장식이 아니라 오해 방지 장치**다.

```
적립 시점이 completed  →  결제 직후엔 Qoin 이 0
                      →  사용자: "적립이 안 됐네?"
                      →  배너: "진행 중 1건, 픽업 완료되면 적립돼요"
```

오늘 `store_reviews` 에서 정확히 같은 구조의 문제가 났다. 기능은 정상이고 자동 검증도 전부 통과했는데, 화면이 사실을 말해주지 않아 사용자가 결함으로 믿었다 (`ac1d2c3`). 그 수정은 사후 대응이었고, 이 배너는 **사전 예방**이다.

spec Q3(적립 예정 표시) 경계에 걸치지만, Q3 는 "개별 주문의 예상 적립액 표시" 이고 이 배너는 **건수와 시점 안내만** 한다. 금액을 보여주지 않으므로 Q3 를 당겨오는 것이 아니다.
