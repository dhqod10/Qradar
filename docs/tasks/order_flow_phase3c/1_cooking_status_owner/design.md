# Phase 3c-1 점주 조리 상태 전이 디자인 명세

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 초안 | designer | 본 design 최초 작성 (Q1~Q6 기반) |
| 2026-06-07 | designer (정책 변경 Q7 반영) | **환불 차단 정책 (결정 F / Q7) 반영.** ① status × refundRequest 매트릭스의 충돌 행 4개 제거 (`making`+active, `ready`+active, `making`+denied 의 warning 안내, `ready`+denied 의 warning 안내 — making/ready 진입 후 신규 환불 요청 자체가 시스템 단에서 차단되어 발생 불가). ② `OwnerInProgressOrderTile` 의 환불 요청 활성 배지 + 관련 디자인 섹션 전체 제거. ③ `_NoActionInfoCard` 의 warning 톤 케이스 (Q6 카피) 제거. ④ `_ActionBar` 분기 매트릭스 단순화 (making/ready 는 단일 full-width 버튼만, 환불 분기 불필요). ⑤ 개발자 전달 `_ActionBar` 분기 로직 단순화 (isRefundActive 선행 체크 제거 가능 — making/ready/completed 에서 발생 불가). ⑥ 고객 `OrderDetailPage` 의 환불 차단 inline 안내 카드 (U7) 신규 추가. |
| 2026-06-21 | architect (drift 해소 / 보완 2) | **"조리 중" 탭 범위 확장 (결정 H / Q8) 반영.** 라이브 검증 중 발견된 UX 결함 (accepted 상태 주문이 어느 탭에도 미노출) 해소 + 코드 fix 완료에 맞춰 design.md 정정. ① OwnerOrdersPage 3탭 구조의 탭 2 "조리 중" 표시 범위를 `{making, ready}` → `{accepted, making, ready}` 로 명세 정정. ② `OwnerInProgressOrderTile._buildActionButton` 의 status 별 분기 명세를 3개로 확장 — `accepted → "조리 시작"` (outlined primary, 신규) / `making → "준비 완료"` (outlined primary, 기존) / `ready → "픽업 완료"` (filled primary, 기존). ③ "기존 디자인 대비 변경사항" 표에 본 결정 행 추가. ④ status 매트릭스 (sticky bottom) 변경 없음 — accepted 의 단일 액션 ("조리 시작") 은 이미 기존 매트릭스에 정의됨. 탭 표시 범위만 확장이며 OwnerOrderDetailPage 의 본문 / sticky bottom 영향 없음. 탭 이름 "조리 중" 은 그대로 유지. |

---

## 참조한 디자인

- 기존 화면: `docs/tasks/owner_order_detail_page/design.md` — Phase 3b sticky bottom 패턴 기반
- 기존 위젯: `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart` — OwnerInProgressOrderTile 패턴 참조
- 기존 위젯: `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` — showCompletePickup 패턴 참조
- 기존 위젯: `lib/presentation/common/order_status_badge.dart` — 재사용 (making/ready/completed 이미 정의됨)
- 기존 화면: `lib/presentation/owner/orders/owner_orders_page.dart` — TabBar 패턴 기반

---

## 화면 구성

### 1. OwnerOrdersPage — 3탭 구조

```
┌─────────────────────────────────┐
│  AppBar                         │
│  '주문 접수'                     │
├─────────────────────────────────┤
│  TabBar                         │
│  [ 신규 ]  [ 조리 중 ]  [ 환불 요청 ]
├─────────────────────────────────┤
│  TabBarView                     │
│  (각 탭 내용)                    │
└─────────────────────────────────┘
```

- 배경: `AppColors.background`
- AppBar: 기존과 동일
- TabController.length: 2 → **3**으로 변경

---

### 2. OwnerOrderDetailPage — 확장 (본문 + sticky bottom)

Phase 3b 레이아웃 유지. 새로운 섹션 및 분기 추가만 명세.

```
┌─────────────────────────────────┐
│  AppBar                         │
├─────────────────────────────────┤
│  SingleChildScrollView          │
│  padding: h20 / top 16          │
│                                 │
│  _StatusSection                 │  ← 기존
│  SizedBox(16)                   │
│  _OwnerRefundSection (조건부)    │  ← 기존 (accepted 단계 환불 요청 이력 표시 — Q7 이후 making/ready 분기 불필요)
│  SizedBox(16)                   │
│  _TimelineSection (조건부)       │  ← 신규 (makingStartedAt 등 있을 때)
│  SizedBox(16)                   │
│  _ItemsSection                  │  ← 기존
│  SizedBox(16)                   │
│  _PriceSection                  │  ← 기존
│  SizedBox(16)                   │
│  _PaymentInfoSection            │  ← 기존
│  SizedBox(24)                   │
│  [_NoActionInfoCard] (조건부)   │  ← 기존 + 신규 케이스
│  SizedBox(32)                   │
├─────────────────────────────────┤
│  _ActionBar (sticky)            │  ← 기존 + 신규 분기
└─────────────────────────────────┘
```

---

## 컴포넌트 목록

---

### 1. TabBar (OwnerOrdersPage 헤더)

- 역할: 신규 / 조리 중 / 환불 요청 탭 전환
- 위젯: `TabBar` (기존 패턴 그대로 확장)
- 탭 라벨:
  - 인덱스 0: `'신규'`
  - 인덱스 1: `'조리 중'` ← 신규
  - 인덱스 2: `'환불 요청'`
- `indicatorColor`: `AppColors.primary`
- `labelColor`: `AppColors.primary`
- `unselectedLabelColor`: `AppColors.textMuted`
- `indicatorWeight`: 2.5
- `labelStyle`: fontSize 14, fontWeight w600
- 탭 너비: 균등 분할 (기본 TabBar 동작)
- 카운트 뱃지: **미적용** — 탭 라벨만으로 충분. 뱃지는 과도한 정보 밀도 유발.

설계 이유: 기존 2탭과 동일한 스타일 그대로 탭 1개만 추가. 라벨 길이가 짧아 균등 분할이 자연스럽다.

---

### 2. `_InProgressOrdersTab` (OwnerOrdersPage "조리 중" 탭)

- 역할: **accepted + making + ready** 상태 주문 목록 표시 (결정 H / Q8, 2026-06-21 정정 — 초안의 `{making, ready}` 에서 `accepted` 포함으로 확장)
- 위젯 구조: `ConsumerWidget` — `inProgressOrdersByStoreProvider(storeId)` watch
- 표시 정렬: `createdAt desc` (기존). accepted (방금 접수) 가 자연스럽게 상단에 위치.
- loading: shimmer (기존 `_NewOrdersTab._buildShimmer()` 패턴 동일)
- error: 기존 `_buildError()` 패턴 동일
- empty: 아래 명세 참조

**Empty 상태:**

```
Center > Column(mainAxisSize: min):
  Icon(Icons.hourglass_empty_rounded, size: 56, color: AppColors.textMuted)
  SizedBox(12)
  Text('조리 중인 주문이 없어요')
    fontSize: 15, color: AppColors.textHeading
  SizedBox(4)
  Text('신규 주문을 받으면 여기에 표시됩니다')
    fontSize: 13, color: AppColors.textMuted
```

- ListView padding: `EdgeInsets.only(top: 8, bottom: 110)` — 기존 탭과 동일

---

### 3. `OwnerInProgressOrderTile` (신규 위젯)

- 역할: 조리 워크플로우 (**accepted / making / ready**) 주문 카드. status 별 액션 버튼 1개 내장. (결정 H / Q8 반영, 2026-06-21 — `accepted` 포함 확장)
- 파일 위치: `lib/presentation/owner/orders/widgets/owner_in_progress_order_tile.dart`
- 참조 패턴: `OwnerNewOrderTile` 구조 그대로 (Material + InkWell + Container)

#### 3-1. 카드 외부 래퍼

```
Material(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(16),
  child: InkWell(
    onTap: onTapDetail,
    splashColor: AppColors.primary.withValues(alpha: 0.04),
    highlightColor: AppColors.primary.withValues(alpha: 0.02),
    borderRadius: BorderRadius.circular(16),
    child: Container(...)
  )
)
```

#### 3-2. Container (카드 본체)

- margin: `EdgeInsets.symmetric(horizontal: 16, vertical: 6)`
- decoration:
  - color: `AppColors.surfaceElevated`
  - border: `AppColors.border` / 1px
  - borderRadius: 16
- padding: `EdgeInsets.all(16)`

#### 3-3. 카드 내부 레이아웃

> **Q7 정책 변경 반영**: making / ready 상태에서 환불 요청 자체가 시스템 단에서 차단되므로, 환불 요청 활성 배지 (행 1) 를 제거한다. `hasActiveRefundRequest` 조건 자체가 발생 불가.

```
Column(crossAxisAlignment: start):

  // 행 1: 시간 + status 배지
  Row:
    Text(timeFmt.format(order.createdAt))
      fontSize: 12, color: AppColors.textMuted
    Spacer()
    OrderStatusBadge(status: order.status, size: OrderStatusBadgeSize.small)

  SizedBox(8)

  // 행 2: 메뉴 요약
  Text(itemSummary)
    fontSize: 14, color: AppColors.textBody

  SizedBox(4)

  // 행 3: 총액
  Text(fmt.format(order.totalPrice))
    fontSize: 16, fontWeight: w700, color: AppColors.textHeading

  // 행 4: 진행 시간 (makingStartedAt 있을 때)
  if (order.makingStartedAt != null)
    SizedBox(6)
    Text(_elapsedLabel(order.makingStartedAt!))
      fontSize: 12, color: AppColors.textMuted

  SizedBox(12)

  // 행 5: 액션 버튼 (full width)
  _ActionButton(status, isLoading, onAction)
```

**`_elapsedLabel` 표시 규칙:**

- `makingStartedAt` 기준 경과 시간.
- 1분 미만: `'방금 조리 시작'`
- 1분 이상: `'조리 시작 N분 전'`
- 60분 이상: `'조리 시작 1시간 이상 전'`
- 색상: `AppColors.textMuted`

설계 이유: 점주가 주문이 얼마나 오래 됐는지 빠르게 파악 가능. 복잡한 로직 없이 단순 diff 표시.

#### 3-4. 액션 버튼 스펙 (status 별 분기, 결정 H / Q8 후 3개 케이스)

> **2026-06-21 정정 (결정 H / Q8)**: 본 카드가 `accepted` 도 표시하게 되면서 액션 버튼 분기도 3개로 확장. `accepted` 케이스 신규 추가.

**accepted 상태 → "조리 시작" 버튼 (신규, 결정 H):**

```
SizedBox(
  width: double.infinity,
  height: 40,
  child: OutlinedButton(
    onPressed: isLoading ? null : onAction,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary, width: 1.5),
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: isLoading ? CircularProgressIndicator(...) : Text('조리 시작', ...)
  )
)
```

- 스타일: **primary outlined** (making 과 동일 톤 — 중간 단계 전이)
- 설계 이유: "조리 시작"은 점주가 주문 받기 직후 곧바로 누르는 진행 액션. 종결 액션이 아니므로 filled 보다 outlined 가 적절. "준비 완료" 와 동일 톤으로 묶어 시각적 워크플로우 일관성 확보. ready 의 "픽업 완료" 만 filled primary 로 차별화 (종결 액션 강조).

**making 상태 → "준비 완료" 버튼:**

```
SizedBox(
  width: double.infinity,
  height: 40,
  child: OutlinedButton(
    onPressed: isLoading ? null : onAction,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary, width: 1.5),
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: isLoading ? CircularProgressIndicator(...) : Text('준비 완료', ...)
  )
)
```

- 스타일: **primary outlined** (배경은 surfaceElevated, border는 primary)
- 설계 이유: "준비 완료"는 중간 단계 전이. primary filled 는 최종 CTA 에만 사용. 시각적 계층화로 "픽업 완료"와 구분.

**ready 상태 → "픽업 완료" 버튼:**

```
SizedBox(
  width: double.infinity,
  height: 40,
  child: ElevatedButton(
    onPressed: isLoading ? null : onAction,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ),
    child: isLoading ? CircularProgressIndicator(...) : Text('픽업 완료', ...)
  )
)
```

- 스타일: **primary filled** — 종결 액션이므로 최강조
- 버튼 텍스트 fontSize: 14, fontWeight: w600
- 로딩 인디케이터:
  - **accepted (outlined)** → `CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)` 18×18 (결정 H 신규)
  - making (outlined) → `CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)` 18×18
  - ready (filled) → `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)` 18×18

> **Q7 정책 변경 반영**: making / ready 상태에서 환불 요청 자체가 차단되므로, 환불 요청 활성 시 버튼 처리 분기가 존재하지 않는다. 카드 내 환불 배지 UI, 환불 액션 관련 분기 처리, `hasActiveRefundRequest` 판단 로직 모두 이 위젯에서 불필요하다.

#### 3-5. props (결정 H / Q8 반영)

```dart
class OwnerInProgressOrderTile extends StatelessWidget {
  final OrderEntity order;
  final VoidCallback onAction;         // accepted: _startMaking, making: _markReady, ready: _completePickup (다이얼로그)
  final bool isLoading;
  final VoidCallback? onTapDetail;
}
```

> `onAction` 콜백은 `order.status` 에 따라 호출자가 적절한 핸들러로 분기. `_OwnerOrdersPageState` 의 카드 build 분기에서 결정:
>
> ```dart
> onAction: switch (order.status) {
>   OrderStatus.accepted => () => _startMaking(order.id),
>   OrderStatus.making   => () => _markReady(order.id),
>   OrderStatus.ready    => () => _completePickupWithDialog(order.id),
>   _ => () {},  // 정상 흐름에서 미발생
> }
> ```

---

### 4. `OwnerOrderDetailPage` sticky bottom 확장 매트릭스

#### 4-1. `_hasActionBar` 헬퍼 확장

```
bool _hasActionBar(OrderEntity order) {
  return order.status == paid
      || order.status == accepted
      || order.status == making
      || order.status == ready;
}
```

- `_hasActionBar == true` → `Scaffold.bottomNavigationBar = _ActionBar(...)`
- `_hasActionBar == false` → `bottomNavigationBar = null`
- bottom padding: `_hasActionBar ? 96 : 32` (기존 규칙 그대로)

#### 4-2. `_ActionBar` 분기 매트릭스

> **Q7 정책 변경 반영 (2026-06-07)**: 환불 요청은 `accepted` 상태에서만 발생 가능. `making` / `ready` 진입 후 신규 환불 요청은 시스템 단 차단. 따라서 `making`+active, `ready`+active 행 2개, 그리고 `making`+denied, `ready`+denied 행의 의미가 바뀐다 — `making` / `ready` 에서 refundRequest denied 이력이 있다면, 그것은 `accepted` 단계에서 거절된 것. 실제로는 making/ready 단계에서 refundRequest 가 active 일 수 없으므로 denied 이력도 실질적으로 발생 경로가 없다 (accepted → making 전이는 환불 요청 active 시 차단). 결과적으로 making/ready 는 **단일 full-width 버튼만** 렌더링한다.

| status | refundRequest | sticky bottom 구성 |
|---|---|---|
| `paid` | 무관 | 기존: "주문 받기"(flex 2, primary) + "거절"(flex 1, error outlined) |
| `accepted` | null | **신규: "조리 시작" (full width, primary filled)** |
| `accepted` | active | 기존: "환불 승인"(1:1, primary) + "환불 거절"(1:1, error outlined) |
| `accepted` | denied | **신규: "조리 시작" (full width, primary filled)** |
| `making` | — | **신규: "준비 완료" (full width, primary filled)** — refundRequest active 케이스 발생 불가 (Q7) |
| `ready` | — | **신규: "픽업 완료" (full width, primary filled, 확정 다이얼로그)** — refundRequest active 케이스 발생 불가 (Q7) |
| `completed` | 무관 | 없음 (inline 안내 카드) |
| `cancelled` | — | 없음 (inline 안내 카드) |
| `refunded` | — | 없음 (inline 안내 카드) |

**제거된 행 (Q7, 발생 불가):**
- ~~`making` + active — 환불 승인 + 환불 거절~~
- ~~`ready` + active — 환불 승인 + 환불 거절~~

**"accepted/denied" 케이스 (Phase 3b 기존):** refundRequest.deniedAt != null 이면 환불 거절 완료 상태이므로, 점주는 다음 조리 단계로 진행 가능. 이 케이스도 "조리 시작" 버튼 full-width.

#### 4-3. 신규 단일 액션 버튼 (full width) 공통 스펙

- 위젯: `_PrimaryButton` (기존 컴포넌트 재사용)
- width: `double.infinity` (Row + Expanded(flex: 1))
- height: 48
- borderRadius: 12
- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`
- fontSize: 16, fontWeight: w700
- 로딩 시: `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)` 20×20
- disabled(isLoading): `backgroundColor: AppColors.surface`, `foregroundColor: AppColors.textMuted`

**개발자 전달:** 기존 `_PrimaryButton` 을 flex 없이 단독 `Expanded` 로 감싸면 full width 처리된다.

#### 4-4. _ActionBar Row 구성 예시

paid (2:1):
```
Row:
  Expanded(flex:2, _PrimaryButton('주문 받기'))
  SizedBox(12)
  Expanded(flex:1, _ErrorOutlinedButton('거절'))
```

신규 단일 액션 (1:0):
```
Row:
  Expanded(_PrimaryButton('조리 시작'))   // or '준비 완료' or '픽업 완료'
```

환불 처리 (1:1, 기존):
```
Row:
  Expanded(_PrimaryButton('환불 승인'))
  SizedBox(12)
  Expanded(_ErrorOutlinedButton('환불 거절'))
```

---

### 5. `_TimelineSection` — 진행 타임라인 (신규, 조건부)

- 노출 조건: `order.makingStartedAt != null` 인 경우
- 위치: `_OwnerRefundSection` (또는 미노출 시) 다음, `_ItemsSection` 앞
- 역할: 조리 진행 시점 정보를 시간 순으로 표시

```
Container(
  width: double.infinity,
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.surfaceElevated,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(crossAxisAlignment: start):
    Text('진행 현황')
      fontSize: 15, fontWeight: w700, color: AppColors.textHeading

    SizedBox(12)

    // 조리 시작 행 (항상 표시, makingStartedAt != null 이면)
    _TimelineRow(
      icon: Icons.local_fire_department_rounded,
      iconColor: AppColors.warning,
      label: '조리 시작',
      time: makingStartedAt,
    )

    // 준비 완료 행 (readyAt != null 이면)
    if (order.readyAt != null)
      SizedBox(8)
      _TimelineRow(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        label: '준비 완료',
        time: readyAt,
      )

    // 픽업 완료 행 (completedAt != null 이면)
    if (order.completedAt != null)
      SizedBox(8)
      _TimelineRow(
        icon: Icons.shopping_bag_outlined,
        iconColor: AppColors.primary,
        label: '픽업 완료',
        time: completedAt,
      )
)
```

**`_TimelineRow` 스펙:**

```
Row:
  Icon(icon, size: 16, color: iconColor)
  SizedBox(8)
  Text(label)
    fontSize: 13, fontWeight: w500, color: AppColors.textBody
  Spacer()
  Text(timeFmt.format(time))   // HH:mm 포맷 (예: 14:25)
    fontSize: 13, color: AppColors.textMuted
```

- `timeFmt`: `DateFormat('HH:mm')`

설계 이유: 점주가 주문의 진행 이력을 한눈에 파악 가능. 색상 코딩으로 단계를 시각적으로 구분 (warning=조리 중, success=완료 준비, primary=픽업 완료).

---

### 6. `_NoActionInfoCard` 확장 — status별 inline 안내

노출 조건: `_ActionBar` 가 없는 status (`completed`, `cancelled`, `refunded`)

> **Q7 정책 변경 반영 (2026-06-07)**: 환불 요청은 `accepted` 단계에서만 발생 가능. `making` / `ready` 는 항상 `_ActionBar` 가 있는 단일 full-width 버튼 상태이므로, 환불 + 조리 충돌 케이스 자체가 발생하지 않는다. 따라서 다음 항목을 제거한다:
> - ~~`making` + refundRequest active — warning 카드 "환불 요청 처리 후 다음 단계로 진행할 수 있어요"~~
> - ~~`ready` + refundRequest active — 동일 warning 카드~~
> - ~~6-3 warning 톤 카드 전체 디자인~~
> - ~~`showWarningCard` 조건 / 노출 로직~~

#### 6-1. inline 안내 카드 케이스 (단순화 후)

| 케이스 | 카드 톤 | 문구 |
|---|---|---|
| `accepted` + refundRequest null | 회색 (기존) | `'주문을 받았어요. 준비를 시작해주세요.'` |
| `accepted` + refundRequest.deniedAt != null | 회색 (기존) | `'환불 요청을 거절했어요.'` |
| `making` | (inline 카드 없음 — _ActionBar 있음) | — |
| `ready` | (inline 카드 없음 — _ActionBar 있음) | — |
| `completed` | **회색 톤** | `'픽업이 완료된 주문이에요.'` |
| `cancelled` | 회색 톤 (기존) | `'취소된 주문이에요.'` |
| `refunded` | 회색 톤 (기존) | `'환불이 완료된 주문이에요.'` |

#### 6-2. 회색 톤 카드 (기존 패턴 동일, 단일 디자인만 유지)

```
Container(
  width: double.infinity,
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  ),
  child: Text(
    message,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
  ),
)
```

> warning 톤 카드 (6-3) 은 Q7 정책 변경으로 제거됨. `_NoActionInfoCard` 는 회색 톤 단일 디자인만 유지한다.

---

### 7. `showCompletePickup` 다이얼로그 (신규)

- 추가 위치: `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` — `showApproveRefund` 다음에 추가
- 패턴: `showApproveRefund` 와 동일 (AlertDialog, 텍스트 content, 취소+확인 버튼)

```
static Future<bool?> showCompletePickup(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        '픽업 완료로 표시할까요?',
        style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textHeading,
        ),
      ),
      content: Text(
        '주문이 완료 상태로 전환되며\n더 이상 수정할 수 없어요.',
        style: TextStyle(fontSize: 14, color: AppColors.textBody, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('취소', style: TextStyle(color: AppColors.textBody)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('확인'),
        ),
      ],
    ),
  );
}
```

- title: `'픽업 완료로 표시할까요?'`
- content: `'주문이 완료 상태로 전환되며\n더 이상 수정할 수 없어요.'`
- 취소 버튼: TextButton, `AppColors.textBody`
- 확인 버튼: ElevatedButton, `AppColors.primary` 배경, `AppColors.onPrimary` 텍스트
- borderRadius: 16 (다이얼로그), 10 (버튼)

설계 이유:
- title 은 명확한 의문형으로 — 점주가 의도했는지 한 번 더 확인.
- content 는 "되돌릴 수 없음"을 핵심으로 간결하게. 줄바꿈으로 두 메시지 분리.
- `showApproveRefund` 와 동일한 톤 + 패턴 유지 (primary = 긍정적 종결 액션).

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| "조리 중" 탭 전환 | TabBarView 슬라이드 (기존 패턴) |
| OwnerInProgressOrderTile 카드 영역 탭 | ripple → OwnerOrderDetailPage push |
| OwnerInProgressOrderTile 버튼 탭 | 해당 버튼 onPressed (카드 onTap 미발화) |
| "준비 완료" 버튼 탭 | 즉시 실행 → 버튼 disabled + spinner → SnackBar → stream 갱신 |
| "픽업 완료" 버튼 탭 (카드 또는 상세) | showCompletePickup 다이얼로그 → 확인 시 실행 → SnackBar → stream 갱신 |
| "조리 시작" 버튼 탭 (상세) | 즉시 실행 → 버튼 disabled + spinner → SnackBar |
| showCompletePickup 취소 탭 | 다이얼로그 닫힘, no-op |
| 액션 성공 | SnackBar → 페이지 pop 안 함 → stream 갱신으로 액션 영역 자동 재계산 |
| 액션 실패 | SnackBar 오류 메시지, 버튼 disabled 해제 |
| 액션 중 중복 탭 | `_processingOrderIds` (카드) / `_isActionLoading` (상세) 가드 |

---

## 상태별 UI

### Loading

- 조리 중 탭 진입: shimmer (기존 `_NewOrdersTab._buildShimmer()` 동일)
  - Container(height: 110, color: AppColors.surface, borderRadius: 16)
  - 3개 목업 카드 ListView
- OwnerOrderDetailPage: 기존 `_OwnerOrderDetailShimmer` 그대로

### Error

- 조리 중 탭:
  ```
  Center > Column:
    Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error)
    SizedBox(12)
    Text('불러오는 데 실패했어요', fontSize: 16, color: AppColors.textHeading)
  ```
  (기존 `_buildError()` 패턴 동일)
- OwnerOrderDetailPage: 기존 `_ErrorBody` 패턴 그대로

### Empty

- 조리 중 탭: 컴포넌트 2 의 Empty 상태 참조

### 액션 처리 중

- 카드 버튼: `isLoading = true` → 버튼 disabled + spinner (outlined: primary spinner, filled: onPrimary spinner)
- 상세 페이지 버튼: `_isActionLoading = true` → `_PrimaryButton(isLoading: true)` → spinner + disabled
- 중복 탭: `_processingOrderIds.contains(order.id)` (카드) 또는 `_isActionLoading` (상세) 가드

---

## SnackBar 마이크로카피

| 액션 | 성공 메시지 | 에러 메시지 |
|---|---|---|
| 조리 시작 | `'조리를 시작했어요'` | `'오류가 발생했습니다: $e'` |
| 준비 완료 | `'준비를 완료했어요'` | `'오류가 발생했습니다: $e'` |
| 픽업 완료 | `'픽업 완료로 표시했어요'` | `'오류가 발생했습니다: $e'` |

spec.md 결정 B 카피 그대로 적용.

---

## 8. 고객 `OrderDetailPage` — 환불 차단 inline 안내 카드 (U7, 신규)

> **신규 추가 (Q7 / 결정 F 반영)**

### 8-1. 노출 조건

- `order.status in [making, ready, completed]` 이고
- `order.refundRequest == null` 인 경우 (아직 환불 요청 없음)

이 두 조건을 모두 만족할 때 환불 요청 버튼 대신 inline 안내 카드를 노출한다.

> 참고: `completed` 상태에서는 기존에도 환불 버튼이 노출되지 않았으므로 실질적 변경은 `making`, `ready` 에서의 환불 버튼 제거.

### 8-2. UI 스펙

```
Container(
  width: double.infinity,
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          message,  // status 별 카피 (아래 참조)
          style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
        ),
      ),
    ],
  ),
)
```

- 톤: `info` / `textMuted` — 부정적 사건이 아닌 정책 안내. **절대 error / warning 톤 사용 금지.**
- 아이콘: `Icons.info_outline_rounded`, size 16, `AppColors.info`
- 카드 배경: `AppColors.surface` (회색 neutral)
- 카드 border: `AppColors.border`
- 텍스트: `AppColors.textMuted`, fontSize 14, height 1.4
- borderRadius: 12
- padding: 16 전체

### 8-3. status 별 카피 (마이크로카피 확정안)

| status | 카피 |
|---|---|
| `making` | `'조리가 시작되어 환불 요청이 어려워요'` |
| `ready` | `'음료 준비가 완료되어 환불 요청이 어려워요'` |
| `completed` | (기존 안내 유지 — `'완료된 주문입니다'`) |

> **사용자 확인 필요 (U7 카피)**: 위 카피는 designer 추천안. 두 가지 대안을 같이 제시한다.
>
> 대안 A (채택): "조리가 시작되어 환불 요청이 어려워요" / "음료 준비가 완료되어 환불 요청이 어려워요"
>
> 대안 B (매장 연락 안내 포함, spec.md 기본안 참조): "조리가 시작되어 환불 요청이 어려워요. 매장에 직접 문의해 주세요." / "픽업 대기 상태로 환불 요청이 어려워요. 매장에 직접 문의해 주세요."
>
> **디자이너 판단**: 대안 A 추천. "매장에 직접 문의해 주세요" 문구는 현재 in-app 연락 채널이 없는 상태에서 고객에게 책임을 전가하는 느낌을 줄 수 있다. 단순하고 담담한 정책 안내 톤이 더 자연스럽다. 향후 in-app 연락 기능이 생기면 링크를 넣는 방식으로 확장 가능.

### 8-4. 위치

`_ActionSection` (고객 OrderDetailPage 본문 하단) 에서 기존 환불 요청 버튼 노출 위치 대체.

현재 코드 (`lib/presentation/customer/order/orders/order_detail_page.dart`) 의 `_ActionSection.build()` switch 분기에서:
- 기존: `case OrderStatus.accepted, OrderStatus.making, OrderStatus.ready:` → 환불 요청 버튼 or 환불 상태 안내
- 변경 후:
  - `case OrderStatus.accepted:` → 환불 요청 버튼 (기존 그대로)
  - `case OrderStatus.making, OrderStatus.ready:` → U7 inline 안내 카드 (환불 버튼 제거)

### 8-5. 기존 환불 요청 active / denied 상태 안내 (accepted 한정)

`accepted` 상태에서 refundRequest 가 active 이거나 denied 인 경우의 안내 카피는 기존 Phase 3a 그대로 유지:
- active: `'환불 요청 중입니다'` (회색 카드)
- denied: `'환불이 거절되어 더 이상 요청할 수 없어요'` (회색 카드)

이 두 케이스는 `accepted` 상태에서만 노출. `making` / `ready` 에서 active 가 발생하는 경로 자체가 없으므로 분기 제거.

---

## 기존 디자인 대비 변경사항

| 항목 | Phase 3b / 3c-1 초안 | Q7 반영 후 최종 |
|---|---|---|
| OwnerOrdersPage 탭 수 | 2탭 (신규 / 환불 요청) | 3탭 (신규 / **조리 중** / 환불 요청) |
| `_ActionBar` 노출 status | paid / accepted(환불 활성) | paid / accepted / making / ready (환불 분기는 accepted 만) |
| `_ActionBar` 버튼 배치 | paid: 2:1, 환불: 1:1 | 신규 단일 액션: full width (flex 1). making/ready 는 항상 단일 버튼 |
| making 상태 inline 카드 (점주) | 초안: warning 카드 또는 미노출 | **미노출** — 액션 바 있고, 환불 충돌 케이스 자체 없음 |
| ready 상태 inline 카드 (점주) | 초안: warning 카드 또는 미노출 | **미노출** — 동일 |
| `making`/`ready` + refundRequest active (점주) | 초안: warning 카드 + 환불 승인/거절 버튼 | **발생 불가 (Q7 차단)** → 케이스 제거 |
| completed inline 카드 (점주) | "완료된 주문이에요." | **"픽업이 완료된 주문이에요."** (spec.md Q6 안) |
| 고객 making/ready 환불 요청 버튼 | 노출 (Phase 3a 기존) | **제거 → U7 inline 안내 카드로 대체** |
| 신규 섹션 (점주) | 없음 | `_TimelineSection` (조건부) |
| 신규 섹션 (고객) | 없음 | U7 환불 차단 inline 안내 카드 |
| `OwnerInProgressOrderTile` 환불 배지 | 초안: 노출 예정 | **제거** — making/ready 에서 환불 요청 불가 |
| warning 톤 카드 디자인 (점주) | 초안: 신규 추가 예정 | **제거** — 케이스 발생 불가 |
| `_InProgressOrdersTab` 표시 범위 (결정 H, 2026-06-21) | 초안 / Q7 후: `{making, ready}` | **`{accepted, making, ready}` 로 확장** — accepted 상태 주문이 어느 탭에도 미노출되는 UX 결함 해소 |
| `OwnerInProgressOrderTile` 액션 버튼 분기 (결정 H, 2026-06-21) | 2개 분기 (making / ready) | **3개 분기** — accepted 케이스 신규 추가 ("조리 시작" outlined primary) |
| `_InProgressOrdersTab` 탭 이름 | "조리 중" | **"조리 중" 그대로 유지** (의미 확장 — 조리 워크플로우 전체) |

---

## 개발자 전달 특이사항

### 재사용할 기존 컴포넌트

| 컴포넌트 | 경로 | 재사용 방식 |
|---|---|---|
| `OrderStatusBadge` | `lib/presentation/common/order_status_badge.dart` | 그대로 import (making/ready/completed 이미 정의됨) |
| `_PrimaryButton` | `owner_order_detail_page.dart` 내부 private | 단일 액션 full-width 에 그대로 사용 |
| `_ErrorOutlinedButton` | `owner_order_detail_page.dart` 내부 private | 환불 패턴 기존 그대로 |
| `OwnerOrderActionDialogs` | `widgets/owner_order_action_dialogs.dart` | `showCompletePickup` 메서드 추가 |

### 신규 생성 파일

```
lib/presentation/owner/orders/widgets/
└── owner_in_progress_order_tile.dart   ← 신규
```

### `_hasActionBar` 헬퍼 확장

기존 `_hasActionBar` 를 아래 기준으로 확장한다:

```dart
bool _hasActionBar(OrderEntity order) {
  final status = order.status;
  if (status == OrderStatus.paid) return true;
  if (status == OrderStatus.accepted) return true;
  if (status == OrderStatus.making) return true;
  if (status == OrderStatus.ready) return true;
  return false;
}
```

bottom padding 분기: `_hasActionBar(order) ? 96 : 32` — 기존 규칙 그대로.

### `_ActionBar` 분기 로직 순서 (Q7 단순화)

> **Q7 정책 변경 반영**: `making` / `ready` 에서 환불 요청 자체가 불가이므로, `isRefundActive` 선행 체크 범위를 `accepted` 상태로 한정한다. making / ready 에서는 무조건 단일 full-width 버튼을 렌더링.

```dart
// 환불 요청 활성 여부 — accepted 상태에서만 실질적 의미
bool isRefundActive = order.refundRequest != null
    && order.refundRequest!.deniedAt == null
    && order.status != OrderStatus.refunded;

// accepted 에서만 환불 액션 우선 분기
if (order.status == OrderStatus.accepted && isRefundActive) {
  return _refundActionBar(...);
}

// status 별 분기 (making/ready 는 항상 단일 버튼)
switch (order.status) {
  case paid:     return _paidActionBar(...);
  case accepted: return _singleActionBar('조리 시작', _startMaking);
  case making:   return _singleActionBar('준비 완료', _markReady);
  case ready:    return _singleActionBar('픽업 완료', () => _completePickupWithDialog());
  default:       return null;
}
```

### `_TimelineSection` 노출 조건 및 위치

- 노출 조건: `order.makingStartedAt != null`
- 위치: `_OwnerRefundSection` 바로 다음 (환불 섹션 없으면 `_StatusSection` 다음)
- `SizedBox(height: 16)` 로 섹션 간격 유지

> **warning inline 카드 노출 로직 제거 (Q7)**: `showWarningCard` 조건 및 관련 위젯이 더 이상 필요 없다. 점주 OwnerOrderDetailPage 본문에는 warning 카드가 노출되지 않는다.

### `OwnerInProgressOrderTile` — `onAction` 연결

OwnerOrdersPage 에서 카드 생성 시:

```dart
OwnerInProgressOrderTile(
  order: order,
  isLoading: processingIds.contains(order.id),
  onAction: order.status == OrderStatus.making
      ? () => _markReady(order.id)
      : () => _completePickupWithDialog(order.id),
  onTapDetail: () => Navigator.of(context).push(...),
)
```

"픽업 완료" 카드 액션도 `showCompletePickup` 다이얼로그를 거쳐야 함. `_completePickupWithDialog(orderId)` 는 다이얼로그 → confirmed 시 UseCase 호출.

### `_elapsedLabel` 구현 힌트

```dart
String _elapsedLabel(DateTime makingStartedAt) {
  final diff = DateTime.now().difference(makingStartedAt);
  if (diff.inMinutes < 1) return '방금 조리 시작';
  if (diff.inMinutes < 60) return '조리 시작 ${diff.inMinutes}분 전';
  return '조리 시작 1시간 이상 전';
}
```

이 값은 정적으로 빌드 시 계산되므로 실시간 갱신이 필요하면 `StreamProvider` 또는 `Timer` 로 별도 처리. 현재 Phase 에서는 stream 갱신 시점에 재빌드되는 수준으로 충분하다 — 실시간 초 단위 타이머는 비범위.

### AppColors 토큰 목록 (이 명세에서 사용)

> **Q7 정책 변경 반영**: 경고 카드 / 환불 배지 관련 토큰 3종 제거됨 (해당 UI 제거).

| 용도 | 토큰 |
|---|---|
| 카드 배경 | `AppColors.surfaceElevated` |
| 카드 border | `AppColors.border` |
| 전체 배경 | `AppColors.background` |
| 주요 액션 버튼 배경 | `AppColors.primary` |
| 주요 액션 버튼 텍스트 | `AppColors.onPrimary` |
| 준비 완료 outlined border/텍스트 | `AppColors.primary` |
| 에러 버튼 | `AppColors.error` |
| 조리 시작 타임라인 아이콘 | `AppColors.warning` |
| 준비 완료 타임라인 아이콘 | `AppColors.success` |
| 픽업 완료 타임라인 아이콘 | `AppColors.primary` |
| 고객 환불 차단 안내 카드 배경 | `AppColors.surface` |
| 고객 환불 차단 안내 카드 border | `AppColors.border` |
| 고객 환불 차단 안내 아이콘 | `AppColors.info` |
| 본문 제목 | `AppColors.textHeading` |
| 본문 텍스트 | `AppColors.textBody` |
| 보조 텍스트 / 안내 | `AppColors.textMuted` |
| shimmer base | `AppColors.surface` |

**제거된 토큰 (Q7 이후 사용처 없음):**
- ~~`AppColors.warning.withValues(alpha: 0.08)` — 경고 카드 배경~~
- ~~`AppColors.warning.withValues(alpha: 0.35)` — 경고 카드 border~~
- ~~`AppColors.error.withValues(alpha: 0.10)` — 환불 배지 배경~~
- ~~`AppColors.error.withValues(alpha: 0.30)` — 환불 배지 border~~

### 후속 task 항목 (비범위)

- `_elapsedLabel` 실시간 타이머 (초 단위 갱신) — 3c-2 또는 별도
- `_TimelineSection` 을 공통 컴포넌트로 분리 — 추후 고객 상세에서도 재사용 가능성 있음
- `OrderItemRow` / `PriceSummary` 의 common 승격 (Phase 3b 후속 항목 그대로 유지)
