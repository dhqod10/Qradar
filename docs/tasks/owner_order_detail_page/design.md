# owner_order_detail_page 디자인 명세

## 참조한 디자인

- 기존 화면: `lib/presentation/customer/order/orders/order_detail_page.dart` — 레이아웃 패턴 / 섹션 구조 / shimmer / ErrorBody 그대로 채택
- 기존 위젯: `lib/presentation/common/order_status_badge.dart` — 재사용
- 기존 위젯: `lib/presentation/customer/order/widgets/order_item_row.dart` — 재사용 (결정 B-A)
- 기존 위젯: `lib/presentation/customer/order/widgets/price_summary.dart` — 재사용
- 기존 카드: `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart` / `owner_refund_request_tile.dart` — InkWell 감싸기 수정 대상
- 기존 다이얼로그: `owner_orders_page.dart` 의 `_showRejectOrderDialog`, `_showApproveRefundDialog`, `_showDenyRefundDialog` — 공통 위젯으로 추출

---

## 화면 구성

### OwnerOrderDetailPage

```
┌─────────────────────────────────┐
│  AppBar                         │
│  ← (뒤로가기)   주문 상세        │
├─────────────────────────────────┤
│  [SingleChildScrollView]        │
│  padding: horizontal 20, top 16 │
│                                 │
│  ┌──────────────────────────┐   │
│  │  _StatusSection          │   │  ← 항상 표시
│  └──────────────────────────┘   │
│  SizedBox(height: 16)           │
│                                 │
│  ┌──────────────────────────┐   │
│  │  _OwnerRefundSection     │   │  ← refundRequest != null 일 때만
│  └──────────────────────────┘   │
│  SizedBox(height: 16)           │
│                                 │
│  ┌──────────────────────────┐   │
│  │  _ItemsSection           │   │  ← 항상 표시
│  └──────────────────────────┘   │
│  SizedBox(height: 16)           │
│                                 │
│  ┌──────────────────────────┐   │
│  │  _PriceSection           │   │  ← 항상 표시
│  └──────────────────────────┘   │
│  SizedBox(height: 16)           │
│                                 │
│  ┌──────────────────────────┐   │
│  │  _PaymentInfoSection     │   │  ← 항상 표시
│  └──────────────────────────┘   │
│                                 │
│  SizedBox(height: 24)           │
│  (액션 없는 status → inline 카드│
│   SizedBox(height: 32))         │
│                                 │
│  ← 하단 padding 보정:           │
│    액션 바 높이(80) + 16 = 96   │
├─────────────────────────────────┤
│  [Scaffold.bottomNavigationBar] │  ← 액션 있는 status 에서만
│  _ActionBar (sticky)            │
└─────────────────────────────────┘
```

- 배경: `AppColors.background`
- SafeArea: Scaffold 기본 동작에 위임
- Scroll: `SingleChildScrollView`
- padding (본문): `EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 96)`
  - 액션 바가 없는 status: `bottom: 32`
  - 개발자 주의: `_ActionBar` 유무에 따라 bottom padding 동적 조정 필요

---

## 컴포넌트 목록

---

### 1. AppBar

- 역할: 페이지 제목 + 뒤로가기
- 위젯: `AppBar`
- backgroundColor: `AppColors.background`
- elevation: 0
- title: `'주문 상세'`
  - fontSize: 18
  - fontWeight: w700
  - color: `AppColors.textHeading`
- leading: `Icons.arrow_back_rounded`
  - color: `AppColors.textHeading`
  - onPressed: `Navigator.of(context).pop()`

---

### 2. `_StatusSection` — 상태 카드

- 역할: status badge + 주문번호 + createdAt + 매장명을 묶어 상단에 배치
- 위젯 구조: `Container` > `Column`
- 크기: `width: double.infinity`
- padding: `EdgeInsets.all(16)`
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` / 1px
- borderRadius: 16
- shadow: 없음 (customer 패턴 동일)

**내부 레이아웃 (위→아래):**

```
OrderStatusBadge(status: order.status, size: OrderStatusBadgeSize.large)
SizedBox(height: 12)
Text('주문번호 ${shortOrderId}')   ← orderId 앞 12자 + '...'
SizedBox(height: 4)
Text(dateFormat.format(order.createdAt))   ← 'yyyy.MM.dd HH:mm' ko
SizedBox(height: 4)
Text(order.storeName)
```

- `'주문번호 ...'` 텍스트:
  - fontSize: 13
  - color: `AppColors.textMuted`
- `createdAt` 텍스트:
  - fontSize: 13
  - color: `AppColors.textMuted`
- `storeName` 텍스트:
  - fontSize: 15
  - fontWeight: w600
  - color: `AppColors.textHeading`

설계 이유: customer `_StatusSection` 과 시각 일관 유지. 점주는 매장명도 즉시 확인해야 하므로 status 카드 안에 통합 (별도 `_StoreSection` 불필요 — customer 패턴과 다른 점주 전용 결정).

---

### 3. `_OwnerRefundSection` — 환불 요청 섹션 (조건부)

노출 조건: `order.refundRequest != null`

내부는 두 서브 케이스로 분기한다.

#### 3-A. 환불 요청 활성 (`refundRequest != null && refundRequest.deniedAt == null && order.status != refunded`)

- 역할: 점주에게 환불 요청이 들어왔음을 강조
- 위젯 구조: `Container` > `Column`
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.error` / 1.5px  ← customer 패턴은 `AppColors.primary` 사용했으나 점주 관점에서 "긴급 처리 필요" 시각 강조 필요, error 톤 채택
- borderRadius: 16
- padding: `EdgeInsets.all(16)`

**내부 레이아웃:**

```
Row:
  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error)
  SizedBox(width: 6)
  Text('환불 요청 접수')
    fontSize: 14, fontWeight: w700, color: AppColors.error
SizedBox(height: 10)
Text('요청 사유')
  fontSize: 12, color: AppColors.textMuted
SizedBox(height: 2)
Text(refundRequest.reason)
  fontSize: 14, color: AppColors.textBody, height: 1.4
SizedBox(height: 10)
Text('요청 ${dateFormat.format(refundRequest.requestedAt)}')
  fontSize: 12, color: AppColors.textMuted
```

#### 3-B. 환불 요청 거절됨 (`refundRequest.deniedAt != null`)

- 역할: 환불 거절이 완료된 상태 표시 (회색 톤)
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` / 1px  ← 거절 완료 = 처리 종료, 덜 강조
- borderRadius: 16
- padding: `EdgeInsets.all(16)`

**내부 레이아웃:**

```
Row:
  Icon(Icons.do_not_disturb_on_rounded, size: 18, color: AppColors.textMuted)
  SizedBox(width: 6)
  Text('환불 거절됨')
    fontSize: 14, fontWeight: w700, color: AppColors.textMuted
SizedBox(height: 10)
Text('요청 사유')
  fontSize: 12, color: AppColors.textMuted
SizedBox(height: 2)
Text(refundRequest.reason)
  fontSize: 14, color: AppColors.textBody, height: 1.4
if (refundRequest.deniedReason != null && deniedReason.isNotEmpty):
  SizedBox(height: 10)
  Text('거절 사유')
    fontSize: 12, color: AppColors.textMuted
  SizedBox(height: 2)
  Text(refundRequest.deniedReason!)
    fontSize: 14, color: AppColors.textBody, height: 1.4
SizedBox(height: 10)
Text('거절 ${dateFormat.format(refundRequest.deniedAt!)}')
  fontSize: 12, color: AppColors.textMuted
```

설계 이유: 거절 완료는 점주가 이미 처리한 상태이므로 강조 불필요. border 회색, 아이콘 회색으로 시각적 중요도 낮춤.

---

### 4. `_ItemsSection` — 주문 내역

- customer `_ItemsSection` 과 동일 디자인 (그대로 재사용 가능한 구조)
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` / 1px
- borderRadius: 16
- padding: `EdgeInsets.all(16)`

**내부 레이아웃:**

```
Text('주문 내역')
  fontSize: 15, fontWeight: w700, color: AppColors.textHeading
SizedBox(height: 12)
...order.items.map((item) =>
  Padding(bottom: 12) > OrderItemRow(item: item)
)
```

- `OrderItemRow`: `lib/presentation/customer/order/widgets/order_item_row.dart` 그대로 import (결정 B-A)
- 마지막 아이템 하단 padding은 0으로 처리해도 무방 (12px 고정 유지도 OK)

---

### 5. `_PriceSection` — 가격 요약

- customer `_PriceSection` 과 동일 디자인
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` / 1px
- borderRadius: 16
- padding: `EdgeInsets.all(16)`

**내부:**
```
PriceSummary(
  subtotal: order.subtotal,
  discount: order.discount ?? 0,
  total: order.totalPrice,
)
```

---

### 6. `_PaymentInfoSection` — 결제 정보

- customer `_PaymentInfoSection` 과 동일 디자인 완전 재사용
- 결제 수단 / 결제 키 마스킹 / 영수증 보기 링크 / 카드사 / 카드번호 / 결제 금액 포함
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` / 1px
- borderRadius: 16
- padding: `EdgeInsets.all(16)`

---

### 7. `_ActionBar` — sticky bottom 액션 영역

노출 조건 (Scaffold.bottomNavigationBar 에 배치):
- `status == paid` → 주문 받기 + 거절 버튼
- `status == accepted && refundRequest != null && refundRequest.deniedAt == null` → 환불 승인 + 환불 거절 버튼
- 그 외 → `null` (Scaffold.bottomNavigationBar = null, 본문 하단 inline 안내 카드 표시)

**공통 컨테이너:**

```
Container(
  padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
  decoration: BoxDecoration(
    color: AppColors.surfaceElevated,
    border: Border(top: BorderSide(color: AppColors.border, width: 1)),
  ),
  child: Row(...)
)
```

- padding bottom: `24 + MediaQuery.of(context).padding.bottom` — 홈 인디케이터 영역 확보
- 최소 컨테이너 높이: 약 80px (버튼 height 48 + 위아래 padding 12+12, 기기 inset 별도)

#### 7-A. paid 상태 버튼 배치

```
Row(
  children: [
    Expanded(
      flex: 2,
      child: _PrimaryButton(label: '주문 받기', onTap: onAccept, isLoading: isLoading)
    ),
    SizedBox(width: 12),
    Expanded(
      flex: 1,
      child: _ErrorOutlinedButton(label: '거절', onTap: onReject, isLoading: isLoading)
    ),
  ],
)
```

- 비율: 2:1 (flex 2 : flex 1)
- 설계 이유: "주문 받기"가 핵심 액션이므로 시각적 우선순위 부여. "거절" 은 보조 위치.

#### 7-B. 환불 요청 활성 상태 버튼 배치

```
Row(
  children: [
    Expanded(
      child: _PrimaryButton(label: '환불 승인', onTap: onApproveRefund, isLoading: isLoading)
    ),
    SizedBox(width: 12),
    Expanded(
      child: _ErrorOutlinedButton(label: '환불 거절', onTap: onDenyRefund, isLoading: isLoading)
    ),
  ],
)
```

- 비율: 1:1 (환불 승인 / 거절은 동등한 비중)

#### 버튼 공통 스펙

**_PrimaryButton (채움 버튼):**

- widget: `ElevatedButton`
- height: 48
- 배경: `AppColors.primary`
- 텍스트 색: `AppColors.onPrimary`
- 비활성(isLoading): `backgroundColor: AppColors.surface`, `foregroundColor: AppColors.textMuted`
- borderRadius: 12
- elevation: 0
- fontSize: 16, fontWeight: w700
- 로딩 시: `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)` — 20×20

**_ErrorOutlinedButton (아웃라인 에러 버튼):**

- widget: `OutlinedButton`
- height: 48
- border: `AppColors.error` / 1.5px
- 텍스트 색: `AppColors.error`
- 비활성(isLoading): `foregroundColor: AppColors.textMuted`, `side: AppColors.border`
- borderRadius: 12
- fontSize: 16, fontWeight: w700
- 로딩 시: `CircularProgressIndicator(strokeWidth: 2, color: AppColors.error)` — 20×20

---

### 8. 액션 없는 status — inline 안내 카드 (본문 하단 배치)

노출 조건: `_ActionBar` 가 없는 모든 status (`making`, `ready`, `completed`, `cancelled`, `refunded`, `accepted` 단 환불 요청 없음 또는 거절 완료)

- 위치: `SingleChildScrollView` 본문 최하단 (`_PaymentInfoSection` 아래 `SizedBox(height: 24)` 후)
- Scaffold.bottomNavigationBar: null (sticky 영역 없음)

**위젯 구조:**

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
    _inlineMessage,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
  ),
)
SizedBox(height: 32)
```

**status별 안내 문구:**

| status | refundRequest 상태 | 문구 |
|---|---|---|
| `accepted` | null | '주문을 받았어요. 준비를 시작해주세요.' |
| `accepted` | deniedAt != null | '환불 요청을 거절했어요.' |
| `making` | — | '현재 제조 중인 주문이에요.' |
| `ready` | — | '픽업 대기 중인 주문이에요.' |
| `completed` | — | '완료된 주문이에요.' |
| `cancelled` | — | '취소된 주문이에요.' |
| `refunded` | — | '환불이 완료된 주문이에요.' |

---

### 9. 권한 가드 / 안전 가드 — Fallback UI (결정 G)

세 가지 fallback 케이스. 모두 Center + Column 배치.

#### 9-A. 다른 매장의 주문 (storeId 불일치)

```
Icon(Icons.store_rounded, size: 56, color: AppColors.textMuted)
SizedBox(height: 16)
Text('이 주문은 다른 매장의 주문이에요')
  fontSize: 16, fontWeight: w600, color: AppColors.textHeading
SizedBox(height: 8)
Text('확인하려는 주문이 맞는지 다시 확인해주세요.')
  fontSize: 14, color: AppColors.textMuted
SizedBox(height: 24)
ElevatedButton(label: '주문 목록으로', onPressed: Navigator.pop)
  — _PrimaryButton 스타일, minWidth: 160, height: 44
```

#### 9-B. 주문 없음 (currentOrderProvider → null)

```
Icon(Icons.receipt_long_rounded, size: 56, color: AppColors.textMuted)
SizedBox(height: 16)
Text('주문을 찾을 수 없어요')
  fontSize: 16, fontWeight: w600, color: AppColors.textHeading
SizedBox(height: 8)
Text('이미 처리되었거나 존재하지 않는 주문이에요.')
  fontSize: 14, color: AppColors.textMuted
SizedBox(height: 24)
ElevatedButton(label: '주문 목록으로', onPressed: Navigator.pop)
```

#### 9-C. 등록된 매장 없음 (myStore == null)

```
Icon(Icons.store_outlined, size: 56, color: AppColors.textMuted)
SizedBox(height: 16)
Text('등록된 매장이 없어요')
  fontSize: 16, fontWeight: w600, color: AppColors.textHeading
SizedBox(height: 24)
ElevatedButton(label: '돌아가기', onPressed: Navigator.pop)
```

모든 fallback 버튼:
- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`
- borderRadius: 10
- elevation: 0
- height: 44

---

## 다이얼로그 명세

기존 `owner_orders_page.dart` 의 세 다이얼로그를 `widgets/owner_order_action_dialogs.dart` 로 추출한다. 디자인은 기존과 **동일**하게 유지.

### RejectOrderDialog (주문 거절)

- AlertDialog
- backgroundColor: `AppColors.surfaceElevated`
- borderRadius: 16
- title: `'주문을 거절하시겠어요?'` — fontSize: 18, w700, `AppColors.textHeading`
- content: TextField (사유 입력, 선택)
  - minLines: 2, maxLines: 3
  - hint: `'거절 사유 (선택 입력)'`
  - hint color: `AppColors.textMuted`
  - fill: `AppColors.surface`
  - border (기본): `AppColors.border`
  - border (포커스): `AppColors.primary`
  - borderRadius: 10
  - fontSize: 14, `AppColors.textBody`
- actions:
  - `'아니요'` TextButton — `AppColors.textBody`
  - `'거절'` ElevatedButton — `AppColors.error` 배경, `AppColors.onPrimary` 텍스트, borderRadius: 10

### ApproveRefundDialog (환불 승인)

- title: `'환불을 승인하시겠어요?'` — fontSize: 18, w700, `AppColors.textHeading`
- content: `'전액 {금액}이 환불됩니다.'` — fontSize: 14, `AppColors.textBody`
- actions:
  - `'취소'` TextButton — `AppColors.textBody`
  - `'환불 승인'` ElevatedButton — `AppColors.primary` 배경, borderRadius: 10

### DenyRefundDialog (환불 거절)

- title: `'환불 요청 거절'` — fontSize: 18, w700, `AppColors.textHeading`
- content: TextField (사유 입력)
  - hint: `'거절 사유를 입력해주세요'`
  - minLines: 2, maxLines: 4
  - 나머지 스타일 RejectOrderDialog 와 동일
- actions:
  - `'취소'` TextButton — `AppColors.textBody`
  - `'거절'` ElevatedButton — `AppColors.error` 배경, `AppColors.onPrimary` 텍스트, borderRadius: 10

---

## OwnerOrdersPage 카드 수정 명세

### 대상 위젯

- `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart`
- `lib/presentation/owner/orders/widgets/owner_refund_request_tile.dart`

### 수정 방식

기존 root `Container` 를 `Material` + `InkWell` 로 감싼다.

**적용 구조:**

```
Material(
  color: Colors.transparent,  ← AppColors.background 또는 transparent — 카드 자체 색은 내부 Container 가 처리
  borderRadius: BorderRadius.circular(16),
  child: InkWell(
    onTap: onTapDetail,    ← 신규 prop: VoidCallback? onTapDetail
    splashColor: AppColors.primary.withValues(alpha: 0.04),
    highlightColor: AppColors.primary.withValues(alpha: 0.02),
    borderRadius: BorderRadius.circular(16),
    child: 기존 Container(...)
  ),
)
```

- `Material`의 `color`는 `Colors.transparent` 사용 — 카드의 실제 배경은 내부 `Container(color: AppColors.surfaceElevated)` 가 담당
- splash 색상: `AppColors.primary.withValues(alpha: 0.04)` — 매우 약하게, 카드 배경을 거의 바꾸지 않는 수준
- highlight 색상: `AppColors.primary.withValues(alpha: 0.02)`
- borderRadius: 16 — 카드 모서리와 동일하게 적용하여 ripple 이 카드 경계 밖으로 벗어나지 않음

### 탭 우선순위 동작

Flutter hit test 는 자식 위젯의 tap handler 를 우선 처리한다. 기존 `ElevatedButton` / `OutlinedButton` 이 그대로 유지되므로:

- 버튼 탭 → 버튼 onPressed 발화, InkWell.onTap 미발화 (자동)
- 버튼 사이 갭(8px), 카드 패딩 영역 탭 → InkWell.onTap 발화 → OwnerOrderDetailPage push

### chevron 아이콘 추가 여부

**채택: 추가하지 않음.**

이유:
1. 기존 카드에 버튼이 이미 2개 있어 시각 요소가 충분히 밀집되어 있다.
2. 점주의 주 업무는 버튼 액션이고, 상세 이동은 보조 동작이다.
3. ripple 효과만으로 탭 가능함을 충분히 전달한다.
4. 카드 레이아웃을 변경하지 않아 개발 범위를 최소화한다.

### `onTapDetail` prop 추가

두 타일 위젯에 선택적 콜백을 추가한다:
- `final VoidCallback? onTapDetail;`
- null 이면 `InkWell.onTap = null` (탭 비활성 — ripple 없음)

`OwnerOrdersPage` 에서 빌더 시 `onTapDetail: () => Navigator.push(...)` 전달.

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| 카드(버튼 외 영역) 탭 | ripple → OwnerOrderDetailPage push |
| 카드 내 버튼 탭 | 해당 버튼 onPressed (카드 onTap 미발화) |
| '주문 받기' 탭 | RejectOrderDialog 없이 즉시 실행 → 버튼 disabled + spinner → SnackBar |
| '거절' 탭 | RejectOrderDialog 표시 → 사유 입력 → 확인 → 버튼 disabled + spinner → SnackBar |
| '환불 승인' 탭 | ApproveRefundDialog 표시 → 확인 → 버튼 disabled + spinner → SnackBar |
| '환불 거절' 탭 | DenyRefundDialog 표시 → 사유 입력 → 확인 → 버튼 disabled + spinner → SnackBar |
| 액션 성공 | SnackBar 표시, 페이지 pop 안 함, stream 자동 갱신 → UI 재계산 |
| 액션 실패 | SnackBar 에러 메시지, 버튼 disabled 해제 |
| 액션 중 중복 탭 | `_isActionLoading` 플래그로 버튼 disabled — 중복 호출 차단 |
| 뒤로가기 | `Navigator.of(context).pop()` |

---

## 상태별 UI

### Loading

- 표시 방식: shimmer (customer `_OrderDetailShimmer` 패턴 그대로 사용)
- 색상: `AppColors.surface` (shimmer base), `AppColors.border` (shimmer 셀 border)
- 구조:
  ```
  SingleChildScrollView > Column:
    _shimmerBox(height: 120, radius: 16)   ← _StatusSection 자리
    SizedBox(height: 16)
    _shimmerBox(height: 72, radius: 16)    ← 조건부 섹션 자리 (없어도 무방)
    SizedBox(height: 16)
    Container(아이템 행 3개) / 내부 shimmer 라인
    SizedBox(height: 16)
    _shimmerBox(height: 80, radius: 16)    ← _PriceSection 자리
  ```

### Error (stream error)

- 표시 방식: `_ErrorBody` (customer 패턴 그대로 사용)
- 아이콘: `Icons.error_outline_rounded`, size: 48, color: `AppColors.error`
- 제목: error.toString() — fontSize: 14, `AppColors.textMuted`
- 재시도 버튼: `'다시 시도'` — `AppColors.primary` 배경, `AppColors.onPrimary` 텍스트
- onRetry: `ref.invalidate(currentOrderProvider(orderId))`

### Empty / Fallback

→ 컴포넌트 9 (권한 가드 / 안전 가드) 명세 참조.

---

## 스낵바 마이크로카피

| 액션 | 성공 메시지 | 에러 메시지 |
|---|---|---|
| 주문 받기 | `'주문을 받았습니다'` | `'오류가 발생했습니다: $e'` |
| 주문 거절 | `'주문을 거절했습니다'` | `'오류가 발생했습니다: $e'` |
| 환불 승인 | `'환불을 승인했습니다'` | `'오류가 발생했습니다: $e'` |
| 환불 거절 | `'환불 요청을 거절했습니다'` | `'오류가 발생했습니다: $e'` |

기존 `OwnerOrdersPage` 카피와 동일하게 맞춘다.

---

## 마이크로카피 확정안

아래는 작업 지시에서 사용자 확인 후보로 제시된 항목의 디자이너 제안안이다.

| 항목 | 채택 | 기각 후보 | 이유 |
|---|---|---|---|
| 주문 받기 버튼 | **`'주문 받기'`** | `'접수'`, `'조리 시작'` | 기존 OwnerNewOrderTile 카피 일관성 유지. `'조리 시작'`은 Phase 3c making 전환 시 의미. |
| 거절 버튼 | **`'거절'`** | `'주문 거절'` | 버튼이 좁으므로 단어 최소화. 다이얼로그에서 `'주문을 거절하시겠어요?'`로 맥락 제공. |
| 환불 승인 버튼 | **`'환불 승인'`** | `'환불 처리'` | 점주의 의사결정 행위 명확화. `'환불 처리'`는 시스템 동작 뉘앙스. |
| 환불 거절 버튼 | **`'환불 거절'`** | — | 명확. |
| 환불 거절 사유 입력 prompt | **`'거절 사유를 입력해주세요'`** | — | 기존 다이얼로그 카피 그대로 유지. |

---

## 기존 디자인 대비 변경사항

| 항목 | customer OrderDetailPage / 기존 | OwnerOrderDetailPage 변경 |
|---|---|---|
| storeName 위치 | 별도 `_StoreSection` 카드 | `_StatusSection` 카드 하단에 통합 |
| 액션 영역 위치 | 본문 하단 스크롤 내 (`_ActionSection`) | sticky bottom (`Scaffold.bottomNavigationBar`) |
| 환불 요청 섹션 border 색상 | `AppColors.primary` (요청 중) | `AppColors.error` (요청 중) — 점주 관점 "긴급 처리" 강조 |
| 환불 요청 섹션 아이콘 | `Icons.hourglass_top_rounded` primary | `Icons.warning_amber_rounded` error |
| 환불 거절 섹션 | error border, error 아이콘 | border → `AppColors.border` (회색), 아이콘 → `AppColors.textMuted` — 점주가 이미 처리 완료한 건 |
| 버튼 배치 | 세로 단일 버튼 또는 Row | sticky bar Row, 비율 2:1 (paid) / 1:1 (환불) |
| 액션 없는 status | `_ActionSection` 내 inline 카드 | `_ActionBar = null`, 본문 하단 inline 카드 |

---

## 개발자 전달 특이사항

### 재사용할 기존 컴포넌트

| 컴포넌트 | 경로 | 재사용 방식 |
|---|---|---|
| `OrderStatusBadge` | `lib/presentation/common/order_status_badge.dart` | 그대로 import |
| `OrderItemRow` | `lib/presentation/customer/order/widgets/order_item_row.dart` | 그대로 import (결정 B-A, 임시 허용) |
| `PriceSummary` | `lib/presentation/customer/order/widgets/price_summary.dart` | 그대로 import |
| `_OrderDetailShimmer` 패턴 | customer `order_detail_page.dart` | 동일 private 클래스 `_OwnerOrderDetailShimmer` 로 복제 (별도 파일 불필요) |
| `_ErrorBody` 패턴 | customer `order_detail_page.dart` | 동일 private 클래스 `_ErrorBody` 로 복제 |

### 신규 작성 파일

```
lib/presentation/owner/orders/
├── owner_order_detail_page.dart   ← 본 phase 핵심 파일
└── widgets/
    └── owner_order_action_dialogs.dart  ← 기존 3개 다이얼로그 추출
```

### `_ActionBar` sticky 구현 방식

`Scaffold.bottomNavigationBar` 에 `_ActionBar` 위젯을 전달한다. 액션이 없는 status 에서는 `bottomNavigationBar: null` 이 되어 Scaffold 가 자동으로 bottom padding 을 확보하지 않는다.

개발자는 `SingleChildScrollView` 의 bottom padding 을 아래와 같이 분기해야 한다:
- 액션 바 있음: `bottom: 96` (버튼 높이 48 + 상하 padding 12+12 + 여유 12)
- 액션 바 없음: `bottom: 32`

이를 위해 `_hasActionBar(order)` 헬퍼 bool 메서드 사용 권장.

### `_isActionLoading` 스코프

`OwnerOrderDetailPage` 는 단일 주문 단건 처리이므로 Set 이 아닌 `bool _isActionLoading = false` 로 충분하다. `OwnerOrdersPage` 의 `Set<String>` 패턴은 다수 카드 동시 처리용이므로 상세 페이지에서는 불필요.

### InkWell splash API

Flutter의 `withValues(alpha: ...)` 는 flutter 3.27+ 에서 지원된다. 기존 코드베이스 API 수준에 맞게 `withValues` 또는 `withOpacity` 를 선택한다. 의도하는 시각 효과는 alpha 0.04 (primary 기준) 수준이다.

### 환불 요청 섹션 분기 로직 요약

```
refundRequest 이 null 이면 → 섹션 미렌더
refundRequest.deniedAt == null → 3-A (활성, error border)
refundRequest.deniedAt != null → 3-B (거절 완료, 회색)
```

액션 바 분기와 별개로 섹션은 항상 `refundRequest != null` 이면 렌더한다.

### 후속 task 항목 (본 phase 비범위)

- `OrderItemRow` / `PriceSummary` 를 `presentation/common/order/` 로 승격 (결정 B-A 임시 허용 해소)
- customer `_OrderDetailShimmer`, `_ErrorBody` 를 `presentation/common/` 공통화
