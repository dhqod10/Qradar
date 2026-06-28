# Phase 3c-2 고객 알림 + 고객 UI 강화 — Implementation

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-06-21 | developer | 최초 작성 |

---

## 구현 완료 항목

| ID | 항목 | 상태 |
|---|---|---|
| A | Cloud Function `onOrderStatusChanged` 신규 | ✅ |
| B | `index.ts` export 추가 | ✅ |
| C | `RemoteNotificationMessage.NotificationType` enum 확장 (3 case) | ✅ |
| D | `NotificationNavigator` customer 분기 추가 | ✅ |
| E | `ScaffoldWithNav` 알림 권한 hook 이식 | ✅ |
| F | `_OrderProgressIndicator` 위젯 신규 (+ shimmer placeholder) | ✅ |

---

## 생성 / 수정 파일

### 신규 생성

| 파일 | 설명 |
|---|---|
| `functions/src/onOrderStatusChanged.ts` | status 전이 감지 → 고객 FCM 발송 Cloud Function |

### 수정

| 파일 | 변경 내용 |
|---|---|
| `functions/src/index.ts` | `onOrderStatusChanged` export 추가 |
| `lib/domain/entities/remote_notification_message.dart` | `NotificationType` enum 3 case 추가 + `fromData` switch 확장 |
| `lib/presentation/common/notification/notification_navigator.dart` | `orderAccepted` / `orderMaking` / `orderReady` case → customer `OrderDetailPage` push |
| `lib/presentation/common/scaffold_with_nav.dart` | `initState` + `_checkAndRequestNotificationPermission` 추가 (OwnerScaffold 동일 패턴) |
| `lib/presentation/customer/order/orders/order_detail_page.dart` | `_OrderProgressIndicator` 신규 위젯 + shimmer placeholder + `_showProgressIndicator` 헬퍼 |

---

## 구현 상세

### A. Cloud Function `onOrderStatusChanged.ts`

- `onDocumentUpdated('orders/{orderId}', region: 'asia-northeast3')` trigger
- `NOTIFICATION_MATRIX` 로 3개 전이 정의: `paid→accepted` / `accepted→making` / `making→ready`
- `ready→completed` 미발화 (결정 B)
- `before.status == after.status` → early return (F8 중복 방지)
- `after.userId` → `users/{userId}.fcmToken` 조회 → FCM data-only 발송
- invalid token 시 `fcmToken` 필드 delete + `fcmTokenUpdatedAt` serverTimestamp
- 기타 발송 실패 swallow + error 로그
- 알림 카피: design.md 확정안 (`{storeName}에서` 붙여쓰기, 공백 없음)

### B. `RemoteNotificationMessage` 확장

```dart
enum NotificationType {
  newOrder, refundRequest,
  orderAccepted, orderMaking, orderReady,  // 신규
  unknown,
}
```

`fromData` switch: `'order_accepted'` / `'order_making'` / `'order_ready'` 매핑 추가.

### C. `NotificationNavigator` 분기

- `orderAccepted` / `orderMaking` / `orderReady` → customer `OrderDetailPage(orderId: orderId)` push
- 기존 `newOrder` / `refundRequest` → `OwnerOrderDetailPage` 그대로 유지
- 주석: "Phase 3c 예정" → "Phase 3c-2 에서 customer status 전이 알림 추가됨"

### D. `ScaffoldWithNav` 권한 hook

`OwnerScaffold._checkAndRequestNotificationPermission` 완전 동일 패턴:
- `initState` → `addPostFrameCallback` → `_checkAndRequestNotificationPermission`
- `userRepositoryProvider.getNotificationPermissionPrompted(uid)` → `true` 면 early return
- `showNotificationPermissionDialog` → `'allow'` 시 OS 권한 요청 → `authorized` / `provisional` 시 `registerFcmTokenUseCaseProvider.call(uid)`
- 결과 무관하게 `markNotificationPermissionPrompted(uid)` (sticky)

### E. `_OrderProgressIndicator`

- `_OrderDetailBody.build()` 의 `_StatusSection` 직후, `_CancelInfoSection` 앞 삽입
- 노출 조건: `_showProgressIndicator(status)` — `cancelled` / `refunded` 시 미노출
- `_StepState` enum: `completed` / `current` / `upcoming`
- `_stepState(index)` 헬퍼: timestamp 존재 → completed, index==0 또는 직전 timestamp 존재 → current, 나머지 → upcoming
- `_lineCompleted(lineIndex)` 헬퍼: `[acceptedAt, makingStartedAt, readyAt][lineIndex] != null`
- 스테퍼 Row: `_StepNode(32×32) + Expanded(_StepLine) × 3`
- 라벨 Row: `SizedBox(width:40)` × 4 + `Spacer()` × 3 (중앙 정렬)
- 타임스탬프: `DateFormat('HH:mm').format(ts)` / 미도달 시 `'-'`
- 색상: design.md 토큰 표 100% 준수 (AppColors 전용)

#### `paid` 상태 처리

`acceptedAt == null` → `_stepState(0)` 이 `current` 분기 (index==0 조건) → 단계 0 강조(primary), 나머지 upcoming. 설계 의도: 결제 직후 고객이 "접수 대기 중"임을 인지.

### F. shimmer placeholder

`_OrderDetailShimmer` 에 `_shimmerBox(height: 88, radius: 16)` 1개 추가 — 상태 섹션(100) 과 매장명 섹션(72) 사이.

---

## 테스트 포인트

### T1 — FCM 발화: `paid → accepted`
1. 고객이 결제 완료 (status = `paid`)
2. 점주가 "주문 받기" 액션 → status `accepted`
3. 고객 디바이스에 `"주문이 접수되었어요"` 알림 수신 확인
4. 본문: `"{storeName}에서 주문을 받았어요."` (공백 없이 붙여쓰기)

### T2 — FCM 발화: `accepted → making`
- 점주 "조리 시작" → 고객에 `"음료를 만들고 있어요"` 알림

### T3 — FCM 발화: `making → ready`
- 점주 "준비 완료" → 고객에 `"픽업 준비가 완료됐어요"` 알림
- 본문: `"{storeName}에서 음료가 준비됐어요. 매장에 방문해 주세요."`

### T4 — FCM 미발화: `ready → completed`
- 점주 "픽업 완료" → 알림 **없음** (결정 B)

### T5 — deep link: 알림 탭 → 고객 `OrderDetailPage`
- 백그라운드/종료 상태에서 T1~T3 알림 탭
- `NotificationNavigator` → `OrderDetailPage(orderId)` push 확인

### T6 — 진행 인디케이터: `paid` 상태
- `OrderDetailPage` 진입 → 단계 0(접수) primary 강조, 나머지 muted
- 타임스탬프 모두 `-`

### T7 — 진행 인디케이터: `accepted` 상태
- 단계 0 완료(success), 단계 1 현재(primary), 나머지 upcoming
- 단계 0 아래 `acceptedAt` HH:mm 표시

### T8 — 진행 인디케이터: `making` 상태
- 단계 0, 1 완료, 단계 2 현재
- 라인 0, 1 success 색상 채움

### T9 — 진행 인디케이터: `ready` 상태
- 단계 0, 1, 2 완료, 단계 3 현재(primary)
- 라인 0, 1, 2 모두 success

### T10 — 진행 인디케이터: `completed` 상태
- 4단계 모두 완료(success), 타임스탬프 4개 모두 표시

### T11 — 진행 인디케이터 미노출: `cancelled` / `refunded`
- `_OrderProgressIndicator` 미렌더링 확인

### T12 — 고객 알림 권한 흐름: 최초 진입
1. 신규 고객 로그인 → `ScaffoldWithNav` 진입
2. `NotificationPermissionDialog` 노출 확인
3. "허용" → OS 권한 요청 → 허용 → `users/{uid}.fcmToken` set 확인
4. 재로그인 시 다이얼로그 미노출 (sticky)

### T13 — 고객 알림 권한 흐름: "나중에" 선택
- 다이얼로그 → "나중에" → OS 권한 요청 없음 + `notificationPermissionPrompted = true` set
- 재진입 시 다이얼로그 미노출

### 회귀 — sub-phase 1
- 점주 `OwnerScaffold` 알림 권한 흐름 변경 없음 확인
- 점주 `_TimelineSection` (vertical) 정상 표시 확인
- `onOrderRefundRequested` 환불 알림 정상 발화 확인

---

## 미구현 / 보류 항목

| 항목 | 사유 |
|---|---|
| `ready → completed` FCM 발화 | 결정 B — 미발화 확정. Phase 3c-3 알림 설정 UI 도입 후 옵트인 방식으로 확장 가능 |
| iOS APNs 실 검증 | 별도 task `docs/tasks/ios_apns_setup` 에서 처리. 본 sub-phase Android 한정 |
| 알림 설정 UI (toggle) | Phase 3c-3 예정 |
| 고객 Log 탭 status 배지 색상 재정의 | `OrderStatusBadge` 이미 완성됨 — 재정의 불필요 (spec 비범위 확인) |
| 전이 애니메이션 (`AnimatedContainer`) | design.md optional — MVP 즉각 전환 허용 |

---

## 빌드 결과

- `flutter analyze`: **No issues found**
- Cloud Function TypeScript 빌드 (`npm run build`): **성공 (오류 없음)**

---

## 후속 작업 (사용자 수동 실행 필요)

```bash
# Cloud Function 배포 (신규 onOrderStatusChanged 포함)
firebase deploy --only functions
```

배포 전 Firebase 프로젝트 로그인 상태 확인 권장.
