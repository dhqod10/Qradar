# Phase 3c-2 고객 알림 + 고객 UI 강화 디자인 명세

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-06-21 | designer | 본 design 최초 작성 (Q1~Q5 사용자 확정 반영, 결정 A~E 기반) |

---

## 참조한 디자인

- 기존 화면: `lib/presentation/customer/order/orders/order_detail_page.dart` (현재 `_OrderDetailBody` 구조)
- 참조 패턴: `docs/tasks/order_flow_phase3c/1_cooking_status_owner/design.md` (점주 `_TimelineSection` 톤 / 포맷)
- 기존 위젯: `lib/presentation/common/order_status_badge.dart` (status 색상 일관성 기준)
- 알림 권한 패턴: `lib/presentation/owner/owner_scaffold.dart` (lines 36~81)
- 디자인 시스템: `docs/agents/designer_guide.md`

---

## 화면 구성

### 고객 OrderDetailPage — 확장 후 레이아웃

현재 `_OrderDetailBody.build()` 에 `_OrderProgressIndicator` 가 신규 삽입된다.
삽입 위치는 `_StatusSection` 직후이며, `_CancelInfoSection` / `_RefundRequestStatusSection` / `_RefundDeniedSection` 보다 앞이다.

```
┌─────────────────────────────────┐
│  AppBar ('주문 상세')            │
├─────────────────────────────────┤
│  SingleChildScrollView          │
│  padding: h20 / top 16          │
│                                 │
│  _StatusSection                 │  ← 기존 (주문번호 / 날짜 / StatusBadge)
│  SizedBox(16)                   │
│  _OrderProgressIndicator (조건부)│  ← 신규 (본 sub-phase 핵심)
│  SizedBox(16)                   │
│  _CancelInfoSection (조건부)    │  ← 기존
│  SizedBox(16)                   │
│  _RefundRequestStatusSection (조건부) │  ← 기존
│  SizedBox(16)                   │
│  _RefundDeniedSection (조건부)  │  ← 기존
│  SizedBox(16)                   │
│  _StoreSection                  │  ← 기존
│  SizedBox(16)                   │
│  _ItemsSection                  │  ← 기존
│  SizedBox(16)                   │
│  _PriceSection                  │  ← 기존
│  SizedBox(16)                   │
│  _PaymentInfoSection            │  ← 기존
│  SizedBox(24)                   │
│  _ActionSection                 │  ← 기존 (U7 inline 안내 포함 — sub-phase 1 완료)
│  SizedBox(32)                   │
└─────────────────────────────────┘
```

**삽입 규칙:**
- `_OrderProgressIndicator` 노출 조건: `status ∈ {paid, accepted, making, ready, completed}`
- `status == cancelled` 또는 `status == refunded` 일 때 미노출
- 인디케이터 미노출 시 `SizedBox(16)` 도 함께 제거 (조건부 `if` 블록으로 묶음)

---

## 컴포넌트 목록

---

### 1. `_OrderProgressIndicator` (신규 핵심 위젯)

#### 1-1. 역할

고객이 주문 진행 상황을 한눈에 파악할 수 있는 horizontal stepper. 4단계(접수 / 조리 / 준비 / 픽업)를 좌→우로 배치하며, 각 단계 아이콘·라벨·타임스탬프로 현재 진행 위치를 명확히 전달한다.

**점주 측 `_TimelineSection` (vertical) 과의 차별화:**
- 점주 = 조리 이력 운영 도구 (타임라인 기록, 각 행 시간 확인)
- 고객 = 진행 안내 도구 (전체 흐름 파악, 현재 위치 강조)
- horizontal stepper 가 "지금 어디쯤?" 안내 톤에 최적 — 모바일 가로폭을 전부 활용하여 4단계를 한눈에

#### 1-2. 외부 래퍼

```
Container(
  width: double.infinity,
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
  decoration: BoxDecoration(
    color: AppColors.surfaceElevated,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(16),
  ),
  child: _ProgressStepperContent,
)
```

- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` / 1px
- borderRadius: 16
- padding: h16 / v20

#### 1-3. 내부 레이아웃 (`_ProgressStepperContent`)

```
Column(children: [
  // 상단 헤더 (섹션 제목)
  Align(
    alignment: Alignment.centerLeft,
    child: Text('주문 진행'),   // 섹션 제목
  ),
  SizedBox(12),

  // 스테퍼 Row — 아이콘 + 연결선
  Row(children: [
    _StepNode(index: 0),  // 접수
    _StepLine(index: 0),  // 연결선 0~1
    _StepNode(index: 1),  // 조리
    _StepLine(index: 1),  // 연결선 1~2
    _StepNode(index: 2),  // 준비
    _StepLine(index: 2),  // 연결선 2~3
    _StepNode(index: 3),  // 픽업
  ]),

  SizedBox(8),

  // 라벨 + 타임스탬프 Row — 각 단계 아래
  Row(children: [
    _StepLabel(index: 0),  // '접수' + timestamp
    Spacer(),
    _StepLabel(index: 1),  // '조리' + timestamp
    Spacer(),
    _StepLabel(index: 2),  // '준비' + timestamp
    Spacer(),
    _StepLabel(index: 3),  // '픽업' + timestamp
  ]),
])
```

#### 1-4. 섹션 제목

- 텍스트: `'주문 진행'`
- fontSize: 15, fontWeight: w700, color: `AppColors.textHeading`
- 좌측 정렬

#### 1-5. `_StepNode` (단계 아이콘 원)

단계별 상태에 따른 시각 분기:

| 상태 | 아이콘 | 원 배경 | 원 테두리 | 원 크기 |
|---|---|---|---|---|
| **완료** | `Icons.check_rounded` (size 16) | `AppColors.success` | 없음 | 32 × 32 |
| **현재 단계** | 단계별 아이콘 (아래 표) | `AppColors.primary` | 없음 | 32 × 32 |
| **미도달** | 단계별 아이콘 (size 14, muted) | `AppColors.surface` | `AppColors.border` / 1.5px | 32 × 32 |

**현재 단계·미도달 단계 아이콘 (단계별):**

| 인덱스 | 라벨 | 아이콘 |
|---|---|---|
| 0 | 접수 | `Icons.receipt_long_rounded` |
| 1 | 조리 | `Icons.local_fire_department_rounded` |
| 2 | 준비 | `Icons.check_circle_outline_rounded` |
| 3 | 픽업 | `Icons.shopping_bag_outlined` |

**완료 단계 아이콘 색상:** `AppColors.onPrimary` (success 배경 위) — 흰색 체크

**현재 단계 아이콘 색상:** `AppColors.onPrimary` (primary 배경 위)

**미도달 단계 아이콘 색상:** `AppColors.textMuted`

**`_StepNode` 위젯 구조:**
```
Container(
  width: 32,
  height: 32,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: [상태에 따라],
    border: [미도달 시만 Border.all(color: AppColors.border, width: 1.5)],
  ),
  child: Icon(icon, size: [완료 16, 기타 14~16], color: [상태에 따라]),
)
```

#### 1-6. `_StepLine` (단계 간 연결선)

```
Expanded(
  child: Container(
    height: 2,
    color: [완료 구간 AppColors.success, 미완료 구간 AppColors.border],
  ),
)
```

| 연결선 인덱스 | 채움 조건 |
|---|---|
| 0 (접수~조리) | `accepted` 이상 도달 시 (`acceptedAt != null`) |
| 1 (조리~준비) | `making` 이상 도달 시 (`makingStartedAt != null`) |
| 2 (준비~픽업) | `ready` 이상 도달 시 (`readyAt != null`) |

- 채움: `AppColors.success`
- 미채움: `AppColors.border`
- height: 2

#### 1-7. `_StepLabel` (라벨 + 타임스탬프)

각 단계 아래에 라벨과 도달 타임스탬프를 표시한다.

```
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(label),      // '접수' / '조리' / '준비' / '픽업'
    SizedBox(2),
    Text(timeStr),    // HH:mm 또는 공란/placeholder
  ],
)
```

**라벨 텍스트 스타일:**
- 완료·현재 단계: fontSize 12, fontWeight w600, color `AppColors.textHeading`
- 미도달 단계: fontSize 12, fontWeight w400, color `AppColors.textMuted`

**타임스탬프 텍스트 스타일:**
- 도달 시: fontSize 11, color `AppColors.textMuted`, `DateFormat('HH:mm')`
- 미도달 시: fontSize 11, color `AppColors.border` (자리 유지, 공란) — `''` 빈 문자열 또는 `'-'`

> 개발자 참고: 타임스탬프 자리를 항상 렌더링해 단계 정렬이 흔들리지 않도록 한다. 미도달 시 `Text('-', style: ...)` 권장.

**4단계 라벨 + 타임스탬프 소스 필드:**

| 인덱스 | 라벨 | timestamp 소스 |
|---|---|---|
| 0 | `'접수'` | `order.acceptedAt` |
| 1 | `'조리'` | `order.makingStartedAt` |
| 2 | `'준비'` | `order.readyAt` |
| 3 | `'픽업'` | `order.completedAt` |

#### 1-8. 스테퍼 Row 레이아웃 (가로폭 분배)

```
Row(
  children: [
    _StepNode(0),            // 고정 32px
    Expanded(_StepLine(0)),  // 유연 확장
    _StepNode(1),            // 고정 32px
    Expanded(_StepLine(1)),  // 유연 확장
    _StepNode(2),            // 고정 32px
    Expanded(_StepLine(2)),  // 유연 확장
    _StepNode(3),            // 고정 32px
  ],
)
```

`_StepLine` 을 `Expanded` 로 감싸면 375~430pt 가로폭 모두에서 자연스럽게 배치된다.

**라벨 Row 는 고정 폭 기준으로 정렬:**
```
Row(
  children: [
    SizedBox(width: 40, child: _StepLabel(0)),   // 접수 — 중앙 정렬
    Spacer(),
    SizedBox(width: 40, child: _StepLabel(1)),   // 조리
    Spacer(),
    SizedBox(width: 40, child: _StepLabel(2)),   // 준비
    Spacer(),
    SizedBox(width: 40, child: _StepLabel(3)),   // 픽업
  ],
)
```

각 `_StepLabel` 은 `Column(crossAxisAlignment: CrossAxisAlignment.center)` 로 라벨+타임스탬프 중앙 정렬.

---

### 2. 진행 인디케이터 상태별 시각 매트릭스

#### 2-1. status 별 단계 상태 분기 (완료 / 현재 / 미도달)

| order.status | 단계 0 (접수) | 단계 1 (조리) | 단계 2 (준비) | 단계 3 (픽업) | 라인 0 | 라인 1 | 라인 2 |
|---|---|---|---|---|---|---|---|
| `paid` | **현재** (강조, 다음 단계 예고) | 미도달 | 미도달 | 미도달 | 미채움 | 미채움 | 미채움 |
| `accepted` | **완료** | **현재** | 미도달 | 미도달 | 채움 | 미채움 | 미채움 |
| `making` | **완료** | **완료** | **현재** | 미도달 | 채움 | 채움 | 미채움 |
| `ready` | **완료** | **완료** | **완료** | **현재** | 채움 | 채움 | 채움 |
| `completed` | **완료** | **완료** | **완료** | **완료** | 채움 | 채움 | 채움 |

**`paid` 단계 디자인 결정:**
- "다음 단계가 접수임을 예고" — 단계 0을 "현재(예고)" 상태로 처리.
- 아이콘: `Icons.receipt_long_rounded`, 원 배경 `AppColors.primary`, 아이콘 `AppColors.onPrimary` — 강조하되 체크 없이 (아직 완료 아님).
- 라벨: `'접수'`, fontWeight w600, `AppColors.textHeading`.
- 타임스탬프: `'-'` (acceptedAt 없음).
- 나머지 단계 1, 2, 3 은 미도달 처리.

> 설계 이유: 고객이 결제 직후 "지금 뭘 기다리고 있는가?"를 명확히 알 수 있다. 인디케이터 전체가 회색이면 안내 역할을 못한다.

#### 2-2. 환불 관련 상태에서 인디케이터 처리

| 케이스 | 인디케이터 처리 |
|---|---|
| `status == cancelled` | 인디케이터 **미노출**. 기존 `_CancelInfoSection` 만 표시 |
| `status == refunded` | 인디케이터 **미노출**. 기존 inline 안내 카드만 표시 |
| `status == accepted` + `refundRequest` active | 인디케이터 **정상 표시** (단계 1 완료, 단계 2 현재). `_RefundRequestStatusSection` 이 인디케이터 아래에 표시됨 |
| `status == accepted` + `refundRequest` denied | 인디케이터 **정상 표시**. `_RefundDeniedSection` 이 인디케이터 아래에 표시됨 |
| 환불 요청 후 **환불 거절** → status 여전히 `accepted` | 인디케이터 **정상 복귀** (단계 1 완료 상태). 별도 dim 처리 없음 |

> 설계 이유: 인디케이터는 주문 진행 안내 도구다. 환불 요청 이력은 `_RefundRequestStatusSection` / `_RefundDeniedSection` 이 담당하며, 두 정보는 분리하여 표시한다. 환불 거절 후 고객은 다시 주문 진행 흐름으로 복귀하므로 인디케이터가 정상 상태를 보여주는 것이 자연스럽다.

---

### 3. FCM 알림 카피 확정안

결정 D (반높임체 톤) 기반으로 Qradar 브랜드 톤을 반영해 검수한 최종 확정 카피.

#### 3-1. 알림 매트릭스 (3건 발화 — 결정 A/B)

| 전이 | FCM type | 제목 | 본문 |
|---|---|---|---|
| `paid → accepted` | `order_accepted` | `주문이 접수되었어요` | `{storeName}에서 주문을 받았어요.` |
| `accepted → making` | `order_making` | `음료를 만들고 있어요` | `{storeName}에서 조리를 시작했어요.` |
| `making → ready` | `order_ready` | `픽업 준비가 완료됐어요` | `{storeName}에서 음료가 준비됐어요. 매장에 방문해 주세요.` |

**카피 검수 결과 (designer):**
- 제목 3건: `'주문이 접수되었어요'` (13자) / `'음료를 만들고 있어요'` (11자) / `'픽업 준비가 완료됐어요'` (13자) — FCM 권장 30자 이내 충족.
- 본문 3건: 가장 긴 `'making → ready'` 본문 = `"{storeName}에서 음료가 준비됐어요. 매장에 방문해 주세요."` — storeName 최대 20자 가정 시 40자. FCM 권장 60자 이내 충족.
- 반높임체 톤 (`-어요` / `-해요`) 일관 유지.
- `storeName` 공백 처리: `{storeName}에서` 형식. 본문 내 공백은 spec.md 원안 (`{storeName} 에서`) 에서 붙여쓰기로 조정 — 알림 본문 가독성 향상.
- Qradar 브랜드 정합: 프리미엄 + 심플. 과도한 이모지·감탄사 없음. 담담하고 친근하게.

#### 3-2. 환불 관련 알림 (Phase 3b 기존, 재확인)

본 sub-phase 비범위. `onOrderRefundRequested` 가 이미 처리 중. 재정의 없음.

#### 3-3. `ready → completed` 알림 — 미발화 (결정 B)

`픽업 완료` 는 고객이 능동적으로 수행하는 행동이며, 알림은 사후 확인일 뿐 행동 유도 가치가 없다. 미발화로 확정.

---

### 4. 고객 알림 권한 안내 UI (`ScaffoldWithNav` 진입 시)

#### 4-1. 패턴

`OwnerScaffold._checkAndRequestNotificationPermission` (lines 36~81) 과 **동일 패턴** 그대로 이식. 별도 디자인 변경 없음.

기존 `NotificationPermissionDialog` 위젯을 재사용한다.

#### 4-2. 노출 조건

- 고객 최초 로그인 후 `ScaffoldWithNav` 첫 진입
- `users/{uid}.notificationPermissionPrompted == false` (필드 없으면 false)
- OS 권한이 이미 `authorized` 면 다이얼로그 없이 FCM 토큰 등록만 수행

#### 4-3. 사전 안내 모달 필요 여부 — 불필요 (designer 판단)

기존 `NotificationPermissionDialog` 가 이미 "알림 허용" 의도를 명확히 안내한다. 추가 사전 안내 모달은 단계 증가로 사용자 부담을 높이므로 도입하지 않는다.

#### 4-4. 권한 거절 시 안내

본 sub-phase 에서는 **별도 토스트·inline 안내 없음** (결정 E.C 기반). 한 번 거절 시 재노출 없이 조용히 종료. Phase 3c-3 의 알림 설정 UI 에서 사용자가 명시적으로 재요청할 수 있는 경로 제공 예정.

> 설계 이유: 거절 직후 바로 fallback 안내가 나오면 "알림 강요" 느낌을 준다. Qradar 브랜드 감성 (프리미엄 + 심플) 은 한 번의 정중한 요청 후 조용히 물러서는 방식이 적합하다.

---

### 5. `_OrderDetailShimmer` 확장 — 인디케이터 placeholder

기존 shimmer 에 진행 인디케이터 placeholder 1개를 추가한다.

**추가 위치:** `_shimmerBox(height: 100)` (상태 섹션) 과 `_shimmerBox(height: 72)` (매장 섹션) 사이.

```
// 기존: 상태 뱃지 + 주문번호 shimmer
_shimmerBox(height: 100, radius: 16),
SizedBox(16),

// 신규: 진행 인디케이터 placeholder
_shimmerBox(height: 88, radius: 16),   ← 추가
SizedBox(16),

// 기존: 매장명 shimmer
_shimmerBox(height: 72, radius: 16),
...
```

- height: 88 — 실제 `_OrderProgressIndicator` 렌더 높이 (v20 패딩 × 2 + 헤더 20 + gap 12 + 아이콘 32 + gap 8 + 라벨 28 ≈ 88)
- borderRadius: 16
- 색상: `AppColors.surface`

---

## 인터랙션 / 애니메이션

| 동작 | 반응 |
|---|---|
| status 전이 (stream 갱신) | `currentOrderProvider` rebuild → `_OrderProgressIndicator` 자동 재빌드. 단계 아이콘·라인·라벨 상태 전환 |
| 전이 애니메이션 | `AnimatedContainer` / `AnimatedSwitcher` 사용 **선택 사항** (optional). MVP 에서는 즉각 전환도 허용. duration 200ms, curve `Curves.easeOut` 권장 |
| 인디케이터 탭 | 별도 인터랙션 없음 (탭 미지원 — 안내 전용) |
| 알림 수신 (foreground) | `flutter_local_notifications` 로컬 알림 표시 (기존 Phase 3b 처리 그대로) |
| 알림 탭 (OS) | `NotificationNavigator` → customer `OrderDetailPage` push → 인디케이터 최신 status 로 표시 |

---

## 상태별 UI

### Loading

- `currentOrderProvider` loading 상태: 기존 `_OrderDetailShimmer` 표시
- 변경: shimmer 에 `_shimmerBox(height: 88)` 추가 (컴포넌트 5 참조)

### Error

- `currentOrderProvider` error 상태: 기존 `_ErrorBody` 표시 (변경 없음)
- 인디케이터는 data 이후에만 렌더링되므로 별도 에러 처리 없음

### 인디케이터 — `paid` (첫 진입)

```
[접수 — 현재/예고] ——————— [조리 — 미도달] ——————— [준비 — 미도달] ——————— [픽업 — 미도달]
  receipt 아이콘(primary)        fire(muted)              check(muted)            bag(muted)
       '접수'                      '조리'                    '준비'                   '픽업'
         -                          -                          -                       -
```

### 인디케이터 — `accepted` (접수 완료)

```
[접수 — 완료] ═══════════ [조리 — 현재] ——————— [준비 — 미도달] ——————— [픽업 — 미도달]
 check(success bg)        fire 아이콘(primary)     check(muted)           bag(muted)
     '접수'                    '조리'                  '준비'                  '픽업'
    HH:mm                        -                      -                      -
```

### 인디케이터 — `making` (조리 중)

```
[접수 — 완료] ═══════════ [조리 — 완료] ═══════════ [준비 — 현재] ——————— [픽업 — 미도달]
 check(success)            check(success)           check_outline(primary)   bag(muted)
     '접수'                    '조리'                    '준비'                   '픽업'
    HH:mm                     HH:mm                      -                       -
```

### 인디케이터 — `ready` (픽업 대기)

```
[접수 — 완료] ═══════════ [조리 — 완료] ═══════════ [준비 — 완료] ═══════════ [픽업 — 현재]
 check(success)            check(success)            check(success)           bag(primary)
     '접수'                    '조리'                    '준비'                   '픽업'
    HH:mm                     HH:mm                    HH:mm                     -
```

### 인디케이터 — `completed` (픽업 완료)

```
[접수 — 완료] ═══════════ [조리 — 완료] ═══════════ [준비 — 완료] ═══════════ [픽업 — 완료]
 check(success)            check(success)            check(success)           check(success)
     '접수'                    '조리'                    '준비'                   '픽업'
    HH:mm                     HH:mm                    HH:mm                    HH:mm
```

### 인디케이터 — `cancelled` / `refunded`

인디케이터 **미노출**. 기존 `_CancelInfoSection` 또는 `_ActionSection` 의 안내 카드만 표시.

---

## `_OrderDetailBody.build()` 변경 명세

현재 코드 (`order_detail_page.dart:174~213`) 를 아래와 같이 수정한다.

**현재:**
```dart
_StatusSection(order: order, ...),
const SizedBox(height: 16),
if (order.status == OrderStatus.cancelled && order.cancelInfo != null) ...[
  _CancelInfoSection(...),
  const SizedBox(height: 16),
],
if (_isRefundRequestActive(order)) ...[
  ...
```

**변경 후:**
```dart
_StatusSection(order: order, ...),
const SizedBox(height: 16),
// 신규: 진행 인디케이터 (paid/accepted/making/ready/completed 시 노출)
if (_showProgressIndicator(order.status)) ...[
  _OrderProgressIndicator(order: order),
  const SizedBox(height: 16),
],
if (order.status == OrderStatus.cancelled && order.cancelInfo != null) ...[
  _CancelInfoSection(...),
  const SizedBox(height: 16),
],
if (_isRefundRequestActive(order)) ...[
  ...
```

**`_showProgressIndicator` 헬퍼 (디자이너 정의, 개발자 구현):**
```
bool _showProgressIndicator(OrderStatus status) {
  return status != OrderStatus.cancelled && status != OrderStatus.refunded;
}
```

---

## 다크모드 / 색상 토큰 전체 목록

| 용도 | 토큰 |
|---|---|
| 인디케이터 카드 배경 | `AppColors.surfaceElevated` |
| 인디케이터 카드 border | `AppColors.border` |
| 섹션 제목 | `AppColors.textHeading` |
| 완료 단계 원 배경 | `AppColors.success` |
| 완료 단계 아이콘 (체크) | `AppColors.onPrimary` |
| 현재 단계 원 배경 | `AppColors.primary` |
| 현재 단계 아이콘 | `AppColors.onPrimary` |
| 미도달 단계 원 배경 | `AppColors.surface` |
| 미도달 단계 원 border | `AppColors.border` |
| 미도달 단계 아이콘 | `AppColors.textMuted` |
| 완료 연결선 | `AppColors.success` |
| 미완료 연결선 | `AppColors.border` |
| 완료·현재 단계 라벨 | `AppColors.textHeading` |
| 미도달 단계 라벨 | `AppColors.textMuted` |
| 타임스탬프 | `AppColors.textMuted` |
| 미도달 타임스탬프 placeholder | `AppColors.border` (거의 보이지 않게) |
| shimmer placeholder | `AppColors.surface` |
| 전체 배경 | `AppColors.background` |

> `AppColors` 이외의 색상 하드코딩 금지 (CLAUDE.md 절대 규칙).

---

## 기존 디자인 대비 변경사항

| 항목 | Phase 3c-1 이후 기존 | 본 sub-phase 적용 |
|---|---|---|
| 고객 OrderDetailPage 진행 정보 | 없음 (status badge 만) | `_OrderProgressIndicator` (horizontal stepper 4단계) 신규 추가 |
| 인디케이터 위치 | — | `_StatusSection` 직후, 기존 섹션들 앞 |
| shimmer | 상태 / 매장 / 아이템 / 가격 placeholder | 진행 인디케이터 placeholder 1개 추가 |
| 고객 알림 권한 흐름 | 없음 | `ScaffoldWithNav` 진입 시 `NotificationPermissionDialog` (OwnerScaffold 동일 패턴) |
| 고객 FCM 토큰 등록 경로 | 없음 | 알림 권한 허용 시 `RegisterFcmTokenUseCase` 호출 |
| 점주 진행 표시 (`_TimelineSection`) | vertical (타임라인 기록 운영 도구) | 변경 없음 — 고객용 horizontal 과 시각 분리 의도적 |

---

## 개발자 전달 특이사항

### 재사용할 기존 컴포넌트

| 컴포넌트 | 경로 | 재사용 방식 |
|---|---|---|
| `NotificationPermissionDialog` | `lib/presentation/common/notification/notification_permission_dialog.dart` (또는 동등 경로) | `ScaffoldWithNav` 에서 그대로 호출 |
| `OrderStatusBadge` | `lib/presentation/common/order_status_badge.dart` | 변경 없음 — `_StatusSection` 기존 사용 |
| `_OrderDetailShimmer` | `order_detail_page.dart` 내부 | `_shimmerBox(height: 88)` 1개 추가 |
| `_showProgressIndicator` 헬퍼 | `_OrderDetailBody` 내부 정적 메서드 | 신규 추가 |

### 신규 생성 위젯

- `_OrderProgressIndicator` — `order_detail_page.dart` 내부 private 위젯으로 추가
  - `_StepNode` / `_StepLine` / `_StepLabel` 을 내부 헬퍼 위젯으로 분리하거나 빌드 메서드로 처리
  - props: `OrderEntity order`

### 단계 상태 계산 로직

```
enum _StepState { completed, current, upcoming }

_StepState _stepState(int index, OrderEntity order) {
  // index: 0=접수, 1=조리, 2=준비, 3=픽업
  final timestamps = [
    order.acceptedAt,
    order.makingStartedAt,
    order.readyAt,
    order.completedAt,
  ];
  if (timestamps[index] != null) return _StepState.completed;
  // 현재 단계 = 직전 단계까지 완료됐거나 paid 상태에서 첫 단계
  if (index == 0) return _StepState.current; // paid 시 단계 0이 현재(예고)
  if (timestamps[index - 1] != null) return _StepState.current;
  return _StepState.upcoming;
}
```

> `paid` 상태에서 `acceptedAt == null` 이므로 단계 0 이 `current` 로 분기됨. 단계 1, 2, 3 은 모두 `upcoming`.

### 연결선 채움 판정

```
bool _lineCompleted(int lineIndex, OrderEntity order) {
  // lineIndex 0: acceptedAt, 1: makingStartedAt, 2: readyAt
  final timestamps = [order.acceptedAt, order.makingStartedAt, order.readyAt];
  return timestamps[lineIndex] != null;
}
```

### `ScaffoldWithNav` 권한 흐름 구현 참조

`lib/presentation/owner/owner_scaffold.dart` lines 36~81 패턴 그대로 복제.
- `_checkAndRequestNotificationPermission` 메서드 이름 동일하게 사용
- `registerFcmTokenUseCaseProvider` / `requestNotificationPermissionUseCaseProvider` / `userRepositoryProvider` 재사용
- `markNotificationPermissionPrompted` 호출 — 결과 무관하게 sticky set

### Cloud Function 카피 연동

`functions/src/onOrderStatusChanged.ts` 의 `NOTIFICATION_MATRIX` body 에서 `storeName` 을 substitution 할 때 공백 없이 붙여쓰기:
- `\`${n}에서 주문을 받았어요.\`` (공백 없음)
- `\`${n}에서 조리를 시작했어요.\``
- `\`${n}에서 음료가 준비됐어요. 매장에 방문해 주세요.\``

> spec.md 의 `{storeName} 에서` (공백 있음) 에서 붙여쓰기로 조정. 알림 본문 가독성 향상을 위한 designer 결정. 개발자는 NOTIFICATION_MATRIX body 에 이 확정 카피를 반영할 것.

### `DateFormat` 타임스탬프 포맷

- `DateFormat('HH:mm')` — 점주 `_TimelineSection` 과 동일 포맷
- import: `package:intl/intl.dart`

### 애니메이션 (optional)

MVP 에서는 즉각 전환 허용. 여유 있으면 단계 원 색상 전환에 `AnimatedContainer(duration: Duration(milliseconds: 200), curve: Curves.easeOut)` 적용 가능.

### AppColors 사용 규칙 요약

- `Color(0x...)` 직접 하드코딩 금지
- `Colors.white`, `Colors.black` 직접 사용 금지
- 모든 색상은 위 토큰 표의 `AppColors.*` 만 사용

---

## 사용자 추가 확인 필요 항목

본 design.md 작성 기준인 Q1~Q5 는 모두 사용자 확정 완료 상태이다. 추가 확인이 필요한 디자인 결정사항은 없다.

단, 아래 1건은 구현 중 선택이 필요한 사항으로 개발자 판단에 위임한다:

| 항목 | designer 권고 | 개발자 선택 |
|---|---|---|
| 단계 전이 애니메이션 | optional — MVP 에서 즉각 전환 허용 | `AnimatedContainer` 200ms 적용 여부 |
