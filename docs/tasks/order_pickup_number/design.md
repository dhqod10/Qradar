# order_pickup_number — 디자인 명세

기준: `spec.md` (확정). 기존 컴포넌트에 번호 요소만 얹는다. 색상은 전부 `AppColors` 토큰. 신규 화면/라우팅 없음. entry point 변경 없음(기존 고객 결제완료/주문상세/Log, 점주 주문 탭/상세 그대로).

## 0. 핵심 결정

| 항목 | 결정 |
|---|---|
| D6 표기 포맷 | **제로패딩 없이 `3`**. 근거: 매장·일별 순번이라 대부분 1~2자리, "3번 고객님" 호출 UX 에 `003` 은 부자연스러움. 숫자가 4자리 이상이어도 깨지지 않도록 `FittedBox(scaleDown)` 적용. |
| 접두 | 고객: 라벨 "픽업 번호" + 숫자만. 점주: 숫자만(칩). Log: `#3`. |
| 숫자 폰트 | `fontFeatures: [FontFeature.tabularFigures()]` 로 자릿수 흔들림 방지. |
| null 처리 | **번호 영역 통째로 생략**(`"-"` 안 씀). 레이아웃이 비어 보이지 않고, 과거 주문은 기존 화면과 동일. |
| 신규 공통 위젯 | `PickupNumberDisplay` 1개(variant 3종: `hero` / `badge` / `inline`), 위치 `lib/presentation/common/widgets/` (개발자 기존 공통 폴더 규칙에 맞춰 배치). 입력 `int? number`; null 이면 `SizedBox.shrink()`. |

## 1. 고객 — 결제완료 화면 (`payment_result_page.dart` `_SuccessBody`) / 주문상세 (`order_detail_page.dart` `_StatusSection`)

두 곳 모두 variant `hero` 사용 (가장 크게).

### hero 스펙
- 컨테이너: 가로 stretch, padding `vertical 20 / horizontal 16`, 배경 `AppColors.primary`, radius 16, 그림자 없음.
- 라벨 "픽업 번호": fontSize 13, w600, `AppColors.onPrimary` (alpha 0.8 은 `withAlpha((0.8*255).round())`).
- 숫자: fontSize **56**, w800, height 1.1, `AppColors.onPrimary`, 가운데 정렬, tabularFigures. `FittedBox(fit: scaleDown)` 로 감쌈.
- 라벨-숫자 간격 4.
- 하단 보조문구(결제완료 화면에만): "매장에서 이 번호를 보여주세요" fontSize 12, `AppColors.onPrimary` alpha 0.8, 상단 간격 6. 주문상세에는 생략.
- 접근성: `Semantics(label: '픽업 번호 3번')`.

### 결제완료 화면 배치
- 현재: 체크 아이콘(80) → "결제가 완료되었어요" → "주문번호" 라벨 → shortId(14 w600).
- 변경: "결제가 완료되었어요" 아래 간격 20 → `hero` → 간격 16 → 기존 "주문번호 + shortId" 를 **유지하되 보조로 강등**(라벨 12, shortId 12 `textMuted`). 번호 null 이면 hero 만 빠지고 기존 레이아웃 그대로.
- 체크 아이콘 크기 80 → **64**, 상단 여백 60 → 40 (hero 가 들어갈 세로 공간 확보).
- 데이터: 현재 이 페이지는 `orderId` 만 가진다 → 기존 `WatchOrderUseCase` Provider 로 주문 watch 해서 `pickupNumber` 사용(신규 Provider 없음).
  - 스트림 loading: hero 자리에 skeleton(높이 약 108, 배경 `AppColors.surface`, radius 16, 기존 shimmer 패턴 있으면 재사용). 지연돼도 "결제가 완료되었어요"와 하단 버튼은 즉시 노출.
  - 스트림 error / 번호 null / 문서 미도달: hero 생략(조용히). 에러 문구 표시하지 않음.

### 주문상세 배치 (`_StatusSection`)
- 카드 내부 최상단에 `hero` 배치(상태 배지보다 위), 아래 간격 12, 이후 기존 상태 배지 → 주문번호(shortId) → 날짜 유지. 카드 padding 16 그대로이므로 hero 는 카드 안에서 radius 12 로 한 단계 낮춤.
- **취소/환불 등 종료 상태 주문**: 번호가 의미 없으므로 `status` 가 cancelled/refunded 계열이면 배경 `AppColors.surface`, 숫자 `AppColors.textMuted` 로 약화(variant 파라미터 `muted: true`). 접수 전/진행중/완료는 기본 primary.
- shortId 문구는 "주문번호 xxxx" → 번호와 혼동되므로 **"주문 ID xxxx"** 로 변경 권고(결제완료 화면 포함).

## 2. 점주 — 목록 타일 / 주문상세

### 목록 타일 (`OwnerNewOrderTile`, `OwnerInProgressOrderTile`) — variant `badge`
- 타일의 최좌측 leading 으로 배치, 타일 기존 내부 Row 의 첫 요소로 삽입 후 오른쪽 간격 12.
- 크기 고정 **52 x 52**, radius 12, 배경 `AppColors.primary`, 숫자 fontSize **26**, w800, `AppColors.onPrimary`, 가운데, tabularFigures, `FittedBox(scaleDown)` + 내부 padding 4 (3~4자리 대응).
- 세로 정렬: 타일 내용 상단과 맞추지 말고 `crossAxisAlignment: center`(타일 높이가 가변이므로 Row 에서 센터).
- 환불요청 타일(`OwnerRefundRequestTile`)도 동일 badge 를 추가 권고(환불 대상 주문 식별). spec 필수 범위는 새주문·진행중이며, 환불요청 타일은 같은 위젯 재사용 한 줄 추가 수준(선택).
- null: badge 와 12 간격 모두 생략 → 기존 타일 레이아웃 동일.
- 상태별 badge 색 변형은 두지 않는다(상태 구분은 기존 상태 배지에 맡김).

### 주문상세 (`owner_order_detail_page.dart`)
- 상단 최상단 요약 영역(상태 배지가 있는 첫 카드) 에 `badge` 보다 큰 `badge` large 크기: **64 x 64, 숫자 32 w800**, 같은 색. 첫 카드 Row 좌측에 배치, 우측에 기존 상태 배지/주문시각 컬럼 유지.
- null: 생략.

## 3. Log (`OrderCard`, `customer/order/widgets/order_card.dart`, Log 페이지가 이 카드를 사용) — variant `inline`

- 위치: 하단 시간 텍스트(`_relativeTime`, fontSize 12 `textMuted`) 와 같은 줄 앞에 접두. 형태: `#3 · 3분 전`.
- 번호 부분: fontSize 12, w700, `AppColors.textBody`. 구분자 " · " 와 시간: 기존 12 `textMuted`. 한 `Text.rich` 로 구성.
- 카드 높이/레이아웃 변화 없음. null 이면 기존 시간 텍스트만.
- `OrderLogEntity` 가 카드에 쓰이는 경우(도메인 타입이 다르면) 동일 위젯 입력만 `log.pickupNumber` 로 교체.

## 4. 상태 UI 요약

| 맥락 | loading | error | empty(null) |
|---|---|---|---|
| 결제완료 | hero skeleton (`AppColors.surface`) | hero 생략 | hero 생략 |
| 주문상세(고객) | 기존 페이지 로딩 UI 재사용 | 기존 에러 UI 재사용 | hero 생략 |
| 점주 목록/상세 | 기존 목록 로딩 UI 재사용 | 기존 에러 UI | badge 생략 |
| Log | 기존 로딩 UI | 기존 에러 UI | `#N · ` 접두 생략 |

번호 매핑 실패/부재로 인한 별도 에러 문구는 없음. 화면은 항상 정상 렌더링.

## 5. 개발자 전달 특이사항

1. 공통 위젯 `PickupNumberDisplay`(variant `hero`/`badge`/`inline`, `muted` 옵션) 1개로 4곳(고객 2, 점주 2, Log 1) 처리. 수치는 위 값 그대로 쓰되 variant 별 상수는 위젯 내부에 둔다.
2. 색상은 `AppColors.primary`, `onPrimary`, `surface`, `textBody`, `textMuted` 만 사용. `Color(0x...)` 금지. alpha 는 기존 코드처럼 `withAlpha((x*255).round())`.
3. 결제완료 화면은 현재 `orderId` 만 가지므로 주문 watch 추가가 필요(기존 Provider 재사용, 신규 없음). 로딩 중에도 완료 문구/버튼 차단하지 말 것.
4. 제로패딩 없음. 숫자가 길어질 경우를 위해 `FittedBox(BoxFit.scaleDown)` 필수.
5. "주문번호"(shortId) 라벨을 "주문 ID" 로 바꾸는 문구 변경 포함(번호와의 혼동 방지). 사용자 확인 필요 항목 참고.
6. 번호 null 이면 영역과 간격(SizedBox)까지 함께 생략해 빈 여백이 남지 않게 한다.

## 6. 사용자 확인 필요

- D6: 제로패딩 없이 `3` 표기 (권고안) 확정 여부.
- 기존 "주문번호 xxxx"(주문 ID 일부) 라벨을 "주문 ID" 로 변경해도 되는지.
- 점주 환불요청 타일에도 badge 추가할지(권고: 추가, 위젯 재사용이라 비용 낮음).
- 취소/환불 주문의 번호를 muted 로 약화하는 처리(권고안) 적용 여부.
