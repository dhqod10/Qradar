# Qoin 사용(spend) 디자인 명세

- 작성: designer
- 작성일: 2026-11-01
- 입력: `docs/tasks/qoin_spend/spec.md` (§0 전부 확정), `docs/agents/designer_guide.md`
- 확인한 기존 코드: `checkout_page.dart`, `checkout_summary_card.dart`, `customer/order/widgets/price_summary.dart`, `payment_failure_copy.dart`, `payment_failure.dart`, `qoin_transaction_tile.dart`, `qoin_balance_card.dart`, `qoin_formatters.dart`, `order_detail_page.dart`
- 색상은 전부 `AppColors` 토큰. HEX 직접 사용 없음.

---

## 0. 사용자 확인이 필요한 디자인 결정 (먼저 읽을 것)

> ✅ **DD-1~DD-5 전부 권고안대로 확정 (2026-11-02, 사용자 승인).** design 본문이 이미 권고안 기준으로 작성됨 → 그대로 구현.
> **DD-6 은 사용자 결정이 아니라 서버 기술 질문** → developer 단계에서 처리(설계상 잔액 차감이 Toss confirm *전* 이라 해당 케이스가 거의 발생 안 함; 필요 시 architect 재확인). 토큰 못 주면 갈래 C 폴백.

| # | 결정 | 권고안 (design 은 이 안으로 작성됨) | 대안 |
|---|---|---|---|
| **DD-1** | `spendEnabled=false` 또는 정책 로드 실패 시 Qoin 섹션 | **섹션을 통째로 숨긴다.** 배포 초기(`spendEnabled=false` 로 안착시키는 §13 절차) 동안 고객이 못 쓰는 기능을 보게 하지 않는다. | 비활성 카드로 "지금은 쓸 수 없어요" 노출. 기대감을 만들고 문의가 늘 수 있다. |
| **DD-2** | 입력값이 한도를 넘을 때 | **자동 클램프 + 인라인 경고.** 막지 않고 한도값으로 바꿔 입력창에 반영하고 안내 문구를 보여준다. 키 입력이 씹히는 느낌을 피한다. | 입력을 그대로 두고 에러만 표시한 뒤 결제 버튼 비활성. |
| **DD-3** | 결제 요약(소계 → Qoin → 최종액)의 위치 | **현재 위치(약관 아래) 유지 + 결제하기 버튼에 최종액을 실시간 표시.** 기존 흐름을 깨지 않는다. 대신 Qoin 섹션 안에 "결제 예정 금액" 한 줄을 둬 입력 직후 바로 확인되게 한다. | 요약 카드를 Qoin 섹션 바로 아래로 이동. |
| **DD-4** | 최소현금 문구의 결제수단 표현 | 현재 결제수단은 카드·카카오페이뿐이므로 "카드/계좌" 대신 **"선택한 결제수단"** 으로 쓴다. 수단이 늘어도 문구가 안 틀린다. | "카드·간편결제" 등 구체 표기. |
| **DD-5** | 적립 안내 한 줄 (D-4) | Qoin 을 쓰면 섹션에 **"Qoin 사용분을 뺀 결제액 기준으로 적립돼요"** 를 작게 표시한다. 적립이 줄어드는 것을 결제 후에 알게 되는 것을 막는다. | 표시하지 않음. |
| **DD-6** | 서버 후단(confirm 이후) 잔액 부족 abort 의 토큰 (아래 §6.3) | architect 확인 필요: Toss cancel 까지 성공한 이 경우를 **별도 토큰**(예: `QOIN_BALANCE_CHANGED`)으로 내려주면 정확한 문구를 쓸 수 있다. 못 주면 갈래 C(확인 필요)로 떨어진다. | 갈래 C 폴백(안전하지만 불안감이 큼). |

---

## 1. 화면 구조와 배치 (체크아웃)

진입 경로는 기존과 같다(Cart → 결제하기 → `CheckoutPage`). 역할은 customer 이며 `role_flows.md` 상 신규 진입점은 없다. 기존 결제 흐름의 단계 순서와 CTA 위치는 바꾸지 않는다.

스크롤 영역 순서 (변경 부분은 **굵게**):

```
1. CheckoutSummaryCard        (기존: 매장명·메뉴·합계)
2. **Qoin 사용 섹션**          (신규)    ← 24 간격
3. 결제 수단                   (기존)
4. 약관 동의                   (기존)
5. PriceSummary               (기존, 소계 / **Qoin 사용(−)** / 최종 결제액)
─ 하단 고정 CTA: "{최종액} 결제하기"  (기존, 금액만 실시간)
```

배치 근거
- 사용액이 결제수단 선택 전에 정해져야 "남는 최소현금"이 결제수단에 의미를 가진다. 그래서 결제 수단보다 위에 둔다.
- `CheckoutSummaryCard` 의 "합계" 는 **소계 그대로** 둔다(메뉴 합계이므로). 최종 결제액은 §4 의 PriceSummary 와 CTA 가 담당한다.

### 1.1 섹션 구성 (Qoin 사용 섹션 = 헤더 + 카드)

기존 `_SectionHeader`(15 / w600 / `textHeading`, 좌우 20) 재사용. 제목은 **"Qoin 사용"**. 헤더 아래 12 간격 후 카드.

카드 공통 스타일 (CheckoutSummaryCard 와 동일 계열)
- margin 가로 20, padding 16, radius 16
- 배경 `AppColors.surfaceElevated`, border `AppColors.border` 1px
- 그림자 없음(기존 체크아웃 카드와 동일)

---

## 2. 컴포넌트 명세: `QoinSpendSection` (신규, 활성 상태)

신규 위젯. 위치 제안 `lib/presentation/customer/checkout/widgets/qoin_spend_section.dart` (developer 확정). 상태는 §7 의 provider 에서 읽는다.

### 2.1 활성 상태 레이아웃 (위에서 아래)

```
┌─────────────────────────────────────────┐
│ (Q아이콘) 보유 Qoin              12,300 Q │  ← 행 A
│                                         │
│ ┌──────────────────────────┐ [최대 사용] │  ← 행 B 입력 + 버튼
│ │ 0                      Q │            │
│ └──────────────────────────┘            │
│ 최대 4,700 Q까지 쓸 수 있어요             │  ← 행 C 보조/경고 문구
│ ─────────────────────────────────────── │
│ 결제 예정 금액                  4,500원   │  ← 행 D (사용액 > 0 일 때만)
│ Qoin 사용분을 뺀 결제액 기준으로 적립돼요   │  ← 행 E (사용액 > 0 일 때만)
└─────────────────────────────────────────┘
```

**행 A. 보유 Qoin**
- 좌: 28x28 원형 `AppColors.accent` alpha 0.18 배경 + `QLogo(size: 16, animate: false, color: AppColors.primary)` (Qoin 탭 `QoinBalanceCard._LabelRow` 와 동일 패턴 재사용, `ExcludeSemantics`)
- 라벨 "보유 Qoin": 13 / w600 / `textMuted`, 아이콘과 8 간격
- 우: 잔액 `QoinFormatters.balance(balance)` → "12,300 Q". 15 / w700 / `textHeading`, tabularFigures
- 잔액은 이미 구독 중인 `currentUserProfileProvider` 값을 사용(신규 구독 없음)

**행 B. 입력 + 최대 사용** (행 A 아래 12 간격)
- `Row`: 입력창 `Expanded`, 8 간격, 버튼 고정폭
- 입력창
  - 높이 48, radius 12
  - 배경 `AppColors.surface`, border `AppColors.border` 1px
  - 포커스: border `AppColors.primary` 1.5px, cursor `AppColors.primary`
  - 에러(클램프 경고 상태): border `AppColors.error` 1px
  - 텍스트 16 / w600 / `textHeading`, 우측 정렬, tabularFigures
  - hint `0`: 16 / `textMuted`
  - suffix "Q": 14 / w600 / `textMuted` (우측 안쪽 padding 14)
  - 키보드 `TextInputType.number`, `digitsOnly` 필터, 선행 0 제거, `textInputAction: done`
  - 천 단위 콤마는 입력 중 표시하지 않고 포커스 아웃 시 콤마 표시(입력 커서 이슈 회피). developer 가 쉬운 쪽을 택해도 된다.
  - 입력값 0 또는 빈칸 = 사용 안 함
- "최대 사용" 버튼 (칩형 라인 버튼)
  - 높이 48, 폭 약 88(텍스트 14 / w600, 최소 padding 가로 14), radius 12
  - 기본: 배경 `AppColors.surfaceElevated`, border `AppColors.border`, 텍스트 `AppColors.primary`
  - **최대값이 이미 입력된 상태(= 선택됨)**: 배경 `AppColors.primary`, 텍스트 `AppColors.onPrimary`, 라벨 **"사용 취소"** 로 바뀌고 탭하면 입력을 0 으로 비운다(토글).
  - 탭하면 입력창에 `사용가능액` 을 채우고 키보드를 내린다.
  - 사용가능액이 0 이면 활성 상태가 아니라 §3 비활성 카드가 대신 보이므로 이 버튼은 항상 사용가능액 ≥ 1 일 때만 나타난다.

**행 C. 보조/경고 문구** (입력창 아래 8 간격, 12 / w400)
- 기본(입력 0 또는 정상 범위): `최대 {사용가능액} Q까지 쓸 수 있어요` — `textMuted`
- 한도가 최소현금에서 결정될 때(`주문소계 − minCashFloor < 보유잔액`) 같은 줄 아래 한 줄 추가: `최소 {minCashFloor}원은 선택한 결제수단으로 결제돼요` — `textMuted`, 11~12
- 한도가 잔액에서 결정될 때(`보유잔액 ≤ 주문소계 − minCashFloor`): 두 번째 줄 없음(불필요한 정책 문구 노출 금지). 단 최소현금 안내는 §2.3 클램프 시점에 한해 띄운다.
- 클램프가 발생했을 때(= 입력 > 사용가능액): §2.3.

**행 D. 결제 예정 금액** (사용액 ≥ 1 일 때만, 구분선 `border` 1px 위 12 / 아래 12)
- 좌 "결제 예정 금액": 13 / `textMuted`, 우 `PriceFormatter.formatKrw(소계 − 사용액)`: 16 / w700 / `textHeading`
- 이 줄은 PriceSummary 와 같은 값. 입력 직후 스크롤 없이 확인시키려는 중복이며 의도된 것이다.

**행 E. 적립 안내** (DD-5, 사용액 ≥ 1 일 때만, 6 간격 위) 11 / `textMuted`.

### 2.2 인터랙션

| 동작 | 결과 |
|---|---|
| 입력창 탭 | 키보드(숫자) 올라옴. 섹션이 키보드에 가리지 않도록 `Scrollable.ensureVisible`(alignment 0.3). 키보드가 올라와도 하단 CTA 는 기존대로 `Scaffold` 가 처리. |
| 숫자 입력 | 매 키 입력마다 요약/CTA 금액 실시간 갱신(디바운스 없음, 순수 계산). |
| 입력 > 사용가능액 | §2.3 클램프. |
| "최대 사용" | 사용가능액으로 채움 + 키보드 닫기 + 햅틱 `selectionClick`. |
| "사용 취소" | 0 으로 되돌림. |
| 입력창 외 영역 탭 | 키보드 닫기. |
| 결제 처리 중(`_processing`) | 기존 `IgnorePointer` 로 전체 비활성. 별도 처리 없음. |

### 2.3 한도 초과 → 자동 클램프 + 경고 (DD-2)

- 입력 > 사용가능액이면 즉시 **사용가능액으로 치환**하고 커서를 끝으로 이동한다.
- 행 C 가 경고 문구로 바뀐다(입력창 border `AppColors.error`, 아이콘 `Icons.info_outline_rounded` 14 `AppColors.error` + 문구 12 / w500 / `AppColors.error`).

| 원인 | 경고 문구 |
|---|---|
| 잔액이 한도 (입력 > 보유잔액, 보유잔액이 더 작음) | `보유한 Qoin은 {balance} Q예요. 최대 {사용가능액} Q까지 적용했어요` |
| 최소현금이 한도 (보유잔액 ≥ 주문소계 − floor 이고 입력이 그것을 초과) | `최소 {floor}원은 결제해야 해서 최대 {사용가능액} Q까지 적용했어요` |

- 경고는 **다음 입력/포커스 아웃까지 유지**하되, 3초 후 자동으로 기본 문구(행 C 기본)로 돌아간다. 스크린리더에는 `liveRegion` 으로 1회 읽힌다.
- "전액 사용 시도" 는 별도 케이스가 아니다. 전액(= 소계) 입력은 위 "최소현금이 한도" 경로로 클램프되며 문구가 곧 최소현금 안내다.
- 에러 색은 "되돌려 졌음" 알림이지 차단이 아니므로 결제 버튼은 활성 유지(이미 유효 값으로 치환됨).

### 2.4 사용가능액 정의 (표시용, 권위는 서버)

```
사용가능액 = max(0, min(보유잔액, 주문소계 − minCashFloor))
주문소계   = cart.subtotal (체크아웃 시점)
```
- 정책 `minSpendUnit` 이 1 이 아닌 값으로 바뀐 경우: 입력/최대 사용 값을 `minSpendUnit` 배수로 내림(floor)하고 행 C 를 `{unit} Q 단위로 쓸 수 있어요` 로 보강. v1 은 1 이므로 단위 문구는 unit>1 일 때만 노출.
- 위 계산은 `core/utils` 순수 함수(spec §9)에서 하고, 위젯은 결과만 받는다.

---

## 3. 비활성/예외 상태 (카드는 동일 외형, 내용만 교체)

헤더 "Qoin 사용" 은 항상 유지(DD-1 로 숨기는 경우 제외). 입력창과 "최대 사용" 은 렌더하지 않는다(비활성 입력창을 보여 주면 "왜 못 쓰지" 혼란).

공통 비활성 카드: 행 A 의 "보유 Qoin" 줄(잔액 표시) + 그 아래 12 간격에 안내 한 블록.
- 안내 블록: 배경 `AppColors.surface`, radius 12, padding 12, 좌측 아이콘 `Icons.info_outline_rounded` 16 `AppColors.textMuted` + 문구 12~13 `AppColors.textBody`.

| 상태 | 조건 | 보유 Qoin 줄 | 안내 문구 |
|---|---|---|---|
| S1 잔액 0 | `balance == 0` | `0 Q` | `적립하면 결제에 쓸 수 있어요` |
| S2 음수 잔액 | `balance < 0` | `QoinFormatters.balance` 그대로(예 `-120 Q`), 값 색은 `textMuted`(error 금지, Qoin 탭 원칙과 동일) | `Qoin 잔액이 부족해 지금은 쓸 수 없어요` |
| S3 주문이 작음 | `balance > 0` 이고 `주문소계 − floor ≤ 0` | 잔액 표시 | `이 주문은 최소 {floor}원을 결제해야 해서 Qoin을 쓸 수 없어요` |
| S4 사용 중지 | `spendEnabled=false` | **섹션 숨김 (DD-1)** | — |
| S5 정책 로드 실패 | `qoinConfigProvider` error | **섹션 숨김** + 기존 결제(사용 0) 폴백. 스낵바/에러 노출 없음(고객이 해결할 수 없는 일). | — |

- 로딩 상태: §5.

---

## 4. 결제 요약 갱신 (`PriceSummary`)

체크아웃은 `customer/order/widgets/price_summary.dart` 의 `PriceSummary(subtotal, discount, total)` 를 이미 쓰며 **할인 행 지원이 이미 있다**(`discount > 0` 일 때만 노출, `AppColors.success`). 재사용하되 아래만 확장한다.

변경 1 — 라벨 파라미터 추가: `discountLabel` (기본값 `'할인'`, 하위호환). 체크아웃/주문상세에서 Qoin 사용분이면 `'Qoin 사용'` 을 넘긴다.

최종 형태
```
소계                      5,000원     13 / textMuted · textBody
Qoin 사용                −700원      13 / AppColors.success (라벨·값)
─────────────────────────────────── (border)
최종 결제액                4,300원     14 w600 · 18 w700 / textHeading
```
- 할인 행 값은 원화 표기 `-700원`(요약은 금액 단위 통일). "Q" 는 Qoin 섹션과 내역에서만 쓴다.
- 사용액이 0 이면 행이 없다 → **Q=0 일 때 화면이 현재와 동일**(회귀 방지).
- CTA 문구: `'{PriceFormatter.formatKrw(최종액)} 결제하기'` (현재 `cart.subtotal` → 최종액으로). 클램프 후 값 기준.
- 숫자 변경 시 애니메이션 없음(금액 점프 허용). 정확성이 우선이다.
- `_handlePay` 의 Toss `amount` 도 최종액(= subtotal − Q), `verifyAndCreateOrder` 에 `qoinToUse` 전달(spec §5.1).

**주문 상세(customer)**: `order.discount` 가 이제 값이 들어오므로 `_PriceSection` 의 `PriceSummary` 에 `discountLabel: 'Qoin 사용'` 지정. 별도 UI 추가 없음.
**주문 상세(owner)**: 같은 `discount` 가 들어온다. 점주 화면 `common/price_summary.dart` 도 할인 행을 이미 표시하므로 라벨을 `'Qoin 사용(고객)'` 처럼 구분할지는 점주 정산 정책(N4, 미설계)과 함께 결정 필요 — 이번 범위에서는 **변경하지 않고** developer 에게 "점주 화면은 할인 행이 새로 나타남" 만 전달한다.

---

## 5. 로딩 / 에러 / 빈 상태 요약

| 상태 | 처리 |
|---|---|
| 잔액 로딩 (`currentUserProfileProvider` loading) | 섹션 카드 높이를 유지한 skeleton: 행 A 자리에 `AppColors.surface` 바 2개(라벨 70x14, 값 80x16, radius 6), 입력 자리 `surface` 48 높이 라운드 12. shimmer base `surface`, highlight `surfaceElevated`. **로딩 중 `0 Q` 절대 표시 금지**(`QoinBalanceCard` 와 동일 원칙). 로딩 중 입력/최대 사용은 렌더하지 않음. |
| 정책 로딩 (`qoinConfigProvider` loading) | 위와 동일 skeleton. 정책은 다른 화면에서 캐시되어 보통 즉시 해결. |
| 잔액 에러 (프로필 에러) | 섹션 숨김(= S5와 동일하게 기존 결제 폴백). 고객은 현금 결제로 계속 진행 가능. |
| 정책 에러 | 숨김 (S5). |
| 잔액 0 / 사용가능액 0 / 음수 | §3 S1~S3. |
| 결제 중 잔액이 실시간 줄어듦(스트림 갱신) | 사용가능액 재계산 → 현재 입력 > 새 한도면 §2.3 클램프 규칙 재적용(문구는 잔액 기준). |
| 가격 변동 시트(`checkout_price_changed_sheet`) 등으로 `cart.subtotal` 변경 | 사용가능액 재계산 + 입력 클램프. 클램프가 일어나면 행 C 를 경고로 표시. 조용히 값이 바뀌지 않게 한다. |

---

## 6. 서버 거절/실패 문구 (결제 실패 화면)

기존 `PaymentFailure` / `GateFailureCopy` 체계(갈래 B: confirm 전 거절 = 돈 안 나감)에 사유를 추가한다. 서버 문자열은 절대 보간하지 않는다(기존 규칙). 돈 줄은 기존 `kGateMoneyLine` ("아직 결제되지 않았고, 요금도 청구되지 않았어요") 재사용. 모든 사유에서 금액 숫자는 넣지 않는다(PRICE_MISMATCH 와 같은 원칙).

### 6.1 신규 PaymentFailureReason 토큰 → 갈래 B 문구

| 토큰 (spec §10) | headline | body | 주 버튼 / 보조 |
|---|---|---|---|
| `QOIN_INSUFFICIENT_BALANCE` | `Qoin 잔액이 부족해요` | `보유한 Qoin이 결제하려는 금액보다 적어요. 카트로 돌아가 사용할 Qoin을 줄이거나 쓰지 않고 결제해 주세요.` | `카트로 돌아가기` (popToCart) / `닫기` |
| `QOIN_SPEND_DISABLED` | `지금은 Qoin을 결제에 쓸 수 없어요` | `Qoin 사용이 잠시 중단됐어요. Qoin 없이 결제하거나 잠시 후 다시 시도해 주세요. 보유한 Qoin은 그대로예요.` | `카트로 돌아가기` / `닫기` |
| `QOIN_BELOW_CASH_FLOOR` | `Qoin을 최대로 쓸 수 없는 주문이에요` | `주문 금액 중 일부는 카드 등으로 결제해야 해요. 카트로 돌아가 Qoin 사용액을 줄여 주세요.` | `카트로 돌아가기` / `닫기` |
| `QOIN_*` 그 외(단위/상한/`EXCEEDS_CAP`/`BELOW_MIN_UNIT`/`NOT_UNIT_MULTIPLE`) | `Qoin 사용액을 확인해 주세요` | `사용하려는 Qoin 금액을 적용할 수 없어요. 카트로 돌아가 다시 입력해 주세요.` | `카트로 돌아가기` / `닫기` |

- 위 4종 모두 subBody: `Qoin 사용 내역은 바뀌지 않았어요.` (돈 줄 아래, 12 / `textMuted`)
- 아이콘/레이아웃은 기존 갈래 B 화면 템플릿 그대로. 사유별 색 변화 없음.
- `PRICE_MISMATCH` 가 Qoin 주문에서 발생하면 기존 문구/동작(`repriceAndReturn`)을 그대로 사용. 재가격 후 카트로 돌아가면 체크아웃 재진입 시 Qoin 입력은 **초기화(0)** 된다 — 가격이 바뀐 상태에서 이전 사용액을 유지하면 한도가 어긋날 수 있으므로 의도된 동작. 별도 안내 불필요.
- `READ_FAILED` 가 Qoin 주문(서버 재계산 실패)에서 발생하면 기존 `readFailed` 문구 사용.
- 최대한 사용 금액 변경(클램프)이 결제 직전 클라 단계에서 선처리되므로 위 거절은 정상 사용 경로에서는 드물어야 한다(정책이 방금 바뀐 경우 등).

### 6.2 `copy` 파일 반영 요령 (developer)

- `PaymentFailureReason` 에 위 토큰 4종을 추가하고 `gateFailureCopy` switch 가 컴파일 오류로 누락을 알려 주는 기존 설계를 따른다.
- `isMenuReason` 은 false(메뉴 id 없음). 문의 코드 캡션(`rawCode`)은 기존대로 토큰을 표시.

### 6.3 confirm 이후 abort (spec §5.5, §10: "잔액 부족(트랜잭션 재검증, confirm 후) → Toss cancel + 에러")

돈이 한 번 승인됐다가 자동 취소된 경우다. 일반 갈래 B 의 "청구되지 않았어요" 는 **사실이 아니므로** 쓰지 않는다. 별도 토큰(DD-6, 가칭 `QOIN_BALANCE_CHANGED`)을 받을 수 있다면 갈래 B 변형으로 표시:

- headline: `결제가 자동으로 취소됐어요`
- body: `결제하는 사이 Qoin 잔액이 바뀌어 주문을 완료하지 못했어요. 승인된 금액은 자동으로 취소되며, 카드사에 따라 반영까지 시간이 걸릴 수 있어요.`
- subBody: `Log 에서 주문이 없는지 확인한 뒤 다시 결제해 주세요.`
- 주 버튼 `Log 에서 확인하기` (goToLog) / 보조 `카트로 돌아가기`
- 토큰이 없거나 cancel 실패면 기존 갈래 C(`kUnknown*`, "요금/청구" 단어 금지 규칙 유지) 로 자연 폴백된다. 이 경우 별도 작업 없음.

---

## 7. 상태 관리 요구 (developer 전달용 UI 관점 요약)

- 체크아웃 화면 로컬 상태: `qoinToUse: int` (기본 0). 위젯이 `StateNotifier`/Notifier provider 로 보관하든 로컬 state 든 developer 판단. 단 **결제 버튼의 금액·PriceSummary·QoinSpendSection 이 같은 값을 본다.**
- `사용가능액` 은 순수 함수 결과를 provider(`잔액 + 정책 + cart.subtotal` 조합)로 노출. 입력 클램프는 이 값 기준.
- Qoin 섹션 노출 조건: 정책 `AsyncData` + `spendEnabled==true` + 프로필 `AsyncData`. 그 외는 숨김/skeleton(§3, §5).
- 체크아웃을 나가면 상태 폐기(재진입 시 0).

## 8. Qoin 내역 / 잔액 노출 (U5)

### 8.1 `QoinTransactionTile` (`qoin_transaction_tile.dart`) 확장

기존 패턴: 타입별 아이콘, 증가(+)는 `primaryBright` 15% 배경 + `primary` 아이콘 + `textHeading` w700 값, 감소(−)는 `textMuted` 15% 배경 + `textMuted` 아이콘 + `textMuted` w600 값. **감소에 error 색·취소선·dim 금지** 원칙 유지(사용은 정상 거래이며 손실이 아니다).

| 타입 | 아이콘 | 색(배경/아이콘) | 값 표기·색 | 사유 문구 (12 / `textBody`) |
|---|---|---|---|---|
| `earn` (기존) | `Icons.add_rounded` | primaryBright 15% / primary | `+540 Q` · textHeading w700 | 변경 없음 |
| `clawback` (기존) | `Icons.undo_rounded` | textMuted 15% / textMuted | `-540 Q` · textMuted w600 | 변경 없음 |
| **`spend`** | `Icons.shopping_bag_outlined` | textMuted 15% / textMuted (감소 규칙 동일) | `-700 Q` · textMuted w600 | `결제에 사용` + (orderTotalPrice 가 있으면) ` · 카드 등 현금 결제 {orderTotalPrice}원` |
| **`spendRefund`** | `Icons.replay_rounded` | primaryBright 15% / primary (증가 규칙 동일) | `+700 Q` · textHeading w700 | `주문 취소·환불로 사용한 Qoin 복원` |
| `null`(미지 타입) | `Icons.swap_vert_rounded` | 부호 규칙 동일 | 동일 | `Qoin 조정` (기존 중립 폴백 유지) |

- 아이콘 배경/전경과 값 색은 **타입이 아니라 amount 부호**로 결정하는 기존 규칙을 유지한다(`isLoss = amount < 0`). 아이콘 모양과 사유 문구만 타입으로 고른다.
- `spend` 사유 문구의 "카드 등 현금 결제" 대신 결제수단을 특정하지 않는 표현을 쓴다. `orderTotalPrice` 가 없거나 0 이하이면 `결제에 사용` 만.
- `spendRefund` 는 환불/고객취소/점주거절 모두 이 한 문구(원인 구분은 주문 상세에서). 문구가 길어 2줄이 되면 기존 `maxLines: 2` 에 따른다.
- 탭하면 주문 상세로 이동(기존 `orderId` 로직 그대로).
- 스크린리더 `qoinSpokenText`: 동사에 `사용`/`복원` 추가 — spend: `{n} Q 사용`, spendRefund: `{n} Q 복원`, 그리고 `after` 접두사를 `amount >= 0 ? '적립 후' : '회수 후'` 에서 **타입별(`적립 후`/`회수 후`/`사용 후`/`복원 후`)** 로 확장(현재 로직은 두 갈래뿐이라 spend 가 "회수 후 잔액" 으로 읽힘 → 반드시 수정).

### 8.2 잔액 카드 / 목록

- `QoinBalanceCard` 레이아웃 변경 없음. 잔액이 줄어드는 것은 내역으로 설명되므로 추가 UI 불필요.
- `QoinPolicyPlate`(적립 정책 안내) 에 사용 정책 한 줄을 추가할지는 이번 범위에서 **제안만**: `spendEnabled==true` 일 때 `결제 시 Qoin을 쓸 수 있어요 (최소 {floor}원은 결제)`. 필수 아님. 사용 시작 후 문의가 있으면 추가.
- 내역 리스트의 필터/그룹/빈 상태는 기존 그대로.

---

## 9. 접근성 / 카피 규칙

- 용어는 "Qoin", "Qrator", 단위 `Q`. 화면 문구에서 "포인트" 금지.
- 입력창 `Semantics(label: 'Qoin 사용 금액 입력, 최대 {n} Q')`, 최대 사용 버튼 `Semantics(button: true, label: '최대 사용, {n} Q 입력')`, 토글 후 `'사용 취소'`.
- 클램프 경고/상태 변화는 `liveRegion`.
- 터치 영역 최소 48x48 (입력창·버튼 높이 48 충족).
- 금액 텍스트는 `fontFeatures: [FontFeature.tabularFigures()]` (기존 Qoin 화면 패턴).
- 색에만 의존하지 않는다: 경고는 색 + 아이콘 + 문구.

## 10. 사용하는 토큰 요약

`background`, `surface`, `surfaceElevated`, `border`, `textHeading`, `textBody`, `textMuted`, `primary`, `onPrimary`, `primaryBright`, `accent`, `success`(할인 행), `error`(클램프 경고만). 하드코딩 색상 없음.

## 11. 개발자 전달 특이사항

1. **Q=0 이면 화면이 현재와 완전히 같아야 한다.** PriceSummary 할인 행 없음, CTA 금액 = subtotal, Qoin 섹션만 추가. (spec §12 회귀 0 과 동일 목표.)
2. 신규 위젯 1개(`QoinSpendSection`), 기존 수정은 `PriceSummary.discountLabel`(하위호환), `CheckoutPage` 배치/금액/`qoinToUse` 전달, `QoinTransactionTile`·`qoinSpokenText`, `PaymentFailureReason` + `gateFailureCopy`.
3. `qoinSpokenText` 의 `after` 접두사 버그성 로직(부호 2갈래)을 반드시 타입별로 고칠 것 — 안 고치면 spend 가 "회수 후" 로 읽힌다.
4. 정책/잔액 로드 실패 시 **섹션 숨김** — 틀린 정책으로 차감 유도 금지(spec §2.3).
5. 클램프는 표시용이다. 서버가 최종 판정하므로 거절 UI(§6)도 구현해야 한다.
6. 점주 주문 상세에 할인 행이 새로 나타난다(§4). 이번 범위에서 변경하지 않고 후속(N4)으로 이관.
7. 문의 코드 캡션 정규식(`^[A-Z][A-Z0-9_]{2,39}$`)에 `QOIN_*` 토큰이 통과하는지 확인.
