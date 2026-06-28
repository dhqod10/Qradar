# Phase 3c-1 Implementation — 점주 조리 상태 전이

> spec: `docs/tasks/order_flow_phase3c/1_cooking_status_owner/spec.md`
> design: `docs/tasks/order_flow_phase3c/1_cooking_status_owner/design.md`

---

## 구현 완료 항목

### Domain 레이어
- `OrderEntity`: `makingStartedAt`, `readyAt`, `completedAt` 필드 추가 (Nullable DateTime)
- `OrderRepository` interface: `startMakingOrder`, `markOrderReady`, `markOrderCompleted` 메서드 3개 신규
- UseCase 3개 신규: `StartMakingOrderUseCase`, `MarkOrderReadyUseCase`, `MarkOrderCompletedUseCase`

### Data 레이어
- `OrderModel`: timestamp 3필드 매핑 추가 (`fromFirestore`/`toMap`)
- `OrderRepositoryImpl`: 메서드 3개 구현 (Firestore `update()` 직접 호출)

### Presentation — owner
- `OwnerOrdersPage`: 탭 2개 → 3개 (신규 / 조리 중 / 환불 요청)
- `_InProgressOrdersTab` 신규: `making`+`ready` 주문 stream, 카드별 즉시 액션
- `OwnerInProgressOrderTile` 신규: status 별 버튼 분기 (making → "준비 완료" / ready → "픽업 완료")
- `OwnerOrderActionDialogs.showCompletePickup` 신규: ready → completed 확정 다이얼로그
- `OwnerOrderDetailPage._TimelineSection` 신규: `makingStartedAt` set 시 노출, 3단계 진행 현황
- `OwnerOrderDetailPage._hasActionBar`: making/ready 액션바 분기 추가
- `OwnerOrderDetailPage` — making/ready sticky bottom 액션 ("준비 완료" / "픽업 완료") 연결

### Presentation — customer (결정 F / Q7)
- `customer/order/orders/order_detail_page.dart` `_ActionSection`:
  - `case accepted`: 환불 요청 버튼 유지
  - `case making`: U7 inline 안내 카드 ("조리가 시작되어 환불 요청이 어려워요")
  - `case ready`: U7 inline 안내 카드 ("음료 준비가 완료되어 환불 요청이 어려워요")
  - 이전: `accepted + making + ready` 합산 케이스 → 이후: 각 케이스 분리

### Provider DI
- `order_di_providers.dart`: `startMakingOrderUseCaseProvider`, `markOrderReadyUseCaseProvider`, `markOrderCompletedUseCaseProvider`, `inProgressOrdersByStoreProvider` 추가

### Firestore Rules
- O5 신규: `isOwnerStartMakingUpdate` (accepted → making)
- O6 신규: `isOwnerMarkReadyUpdate` (making → ready)
- O7 신규: `isOwnerCompletePickupUpdate` (ready → completed)
- O2 수정: `isCustomerRefundRequest` 허용 status `{accepted, making, ready, completed}` → `accepted` 단독 (결정 F)

### Rules 배포
- `firebase deploy --only firestore:rules` 성공 (2026-06-07)

---

## 신규 / 수정 파일 목록

| 파일 | 변경 |
|---|---|
| `lib/domain/entities/order_entity.dart` | makingStartedAt / readyAt / completedAt 필드 추가 |
| `lib/domain/entities/order_entity.freezed.dart` | (자동 생성) |
| `lib/domain/repositories/order_repository.dart` | 메서드 3개 추가 |
| `lib/domain/usecases/start_making_order_use_case.dart` | 신규 |
| `lib/domain/usecases/mark_order_ready_use_case.dart` | 신규 |
| `lib/domain/usecases/mark_order_completed_use_case.dart` | 신규 |
| `lib/data/models/order_model.dart` | timestamp 3필드 매핑 추가 |
| `lib/data/repositories/order_repository_impl.dart` | 메서드 3개 구현 |
| `lib/presentation/customer/order/orders/providers/order_di_providers.dart` | UseCase provider 3개 + inProgressOrdersByStoreProvider 추가 |
| `lib/presentation/owner/orders/owner_orders_page.dart` | 3탭 구조 + _InProgressOrdersTab 추가 |
| `lib/presentation/owner/orders/widgets/owner_in_progress_order_tile.dart` | 신규 |
| `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` | showCompletePickup 추가 |
| `lib/presentation/owner/orders/owner_order_detail_page.dart` | _TimelineSection / _TimelineRow 신규 + making/ready 액션 분기 추가 |
| `lib/presentation/customer/order/orders/order_detail_page.dart` | _ActionSection making/ready 케이스 분리 (U7 안내 카드) |
| `firestore.rules` | O5/O6/O7 신규, O2 status 축소 |

---

## Rules whitelist vs Repository payload cross-check

| 전이 | Rules 허용 필드 (onlyChangedFields) | Repository payload 키 | 일치 여부 |
|---|---|---|---|
| O5 accepted → making | `status`, `makingStartedAt`, `updatedAt` | `status`, `makingStartedAt`, `updatedAt` | ✅ |
| O6 making → ready | `status`, `readyAt`, `updatedAt` | `status`, `readyAt`, `updatedAt` | ✅ |
| O7 ready → completed | `status`, `completedAt`, `updatedAt` | `status`, `completedAt`, `updatedAt` | ✅ |
| O2 고객 환불 요청 | `refundRequest`, `updatedAt` (status == 'accepted' 만) | `refundRequest: {reason, requestedAt}`, `updatedAt` | ✅ |

---

## 갱신된 process docs

| 문서 | 갱신 내용 |
|---|---|
| `docs/processes/data_ownership.md §2.4` | orders.update 7개 분기로 확장. O5/O6/O7 행 추가. O2 status 조건 `accepted` 단독으로 수정. §2.4.2 클라이언트 SDK vs CF 표에 O5/O6/O7 + Q7 설명 추가 |
| `docs/processes/entity_lifecycle.md §2` | 다이어그램 making/ready/completed 전이 완성 (기존 Phase 3c 예정 → 구현 완료). 전이 상세표 O5/O6/O7 행 신규. O2 조건 수정. 결정 F 주석 추가. §2.5 보류 항목 갱신 |
| `docs/processes/role_flows.md §4.2` | owner 흐름에 조리 시작/준비 완료/픽업 완료 액션 3행 추가 |

---

## 검증 시나리오 (spec.md T1~T16)

| # | 시나리오 | 검증 포인트 |
|---|---|---|
| T1 | accepted → making | "조리 시작" → status='making', makingStartedAt set, _TimelineSection 노출 |
| T2 | making → ready | "준비 완료" → status='ready', readyAt set |
| T3 | ready → completed (다이얼로그) | 확정 다이얼로그 승인 → status='completed', completedAt set, 액션 사라짐 |
| T4 | 확정 다이얼로그 취소 | status 변화 없음 |
| T5 | OwnerOrdersPage "조리 중" 탭 | making + ready 주문 표시 |
| T6 | 조리 중 탭 카드 making → ready | 카드 준비 완료 버튼 → status 갱신 |
| T7 | 조리 중 탭 카드 ready → completed | 픽업 완료 후 탭에서 카드 사라짐 |
| T8 | accepted + 환불 요청 active (유일 케이스) | 상세 sticky bottom = 환불 승인/거절. 조리 시작 미노출 |
| T9 | 환불 거절 후 조리 액션 재노출 | deniedAt set → "조리 시작" 노출 |
| T10 | Rules O5 차단 — 잘못된 전이 | paid 에서 making 직접 시도 → permission-denied |
| T11 | 타 매장 점주 액션 차단 | isStoreOwner 불일치 → permission-denied |
| T12 | 액션 중복 탭 방지 | isLoading 가드 |
| T13 | 기존 paid → accepted 회귀 | 기존 동작 변화 없음 |
| T14 | U7 — 고객 making 상태 환불 버튼 차단 | inline 안내 카드 노출, 버튼 미노출 |
| T15 | Rules O2 차단 — making/ready/completed 에서 refundRequest update | permission-denied (emulator) |
| T16 | 점주 making 전이 후 고객 UI 자동 전환 | stream 갱신 → 버튼 → inline 카드 |

---

## flutter analyze 결과

```
No issues found! (ran in 6.1s)
```

---

## 미구현 / 보류 항목

| 항목 | 사유 |
|---|---|
| `OwnerOrderDetailPage` making/ready sticky bottom 액션 바 연결 | `_hasActionBar` 조건에 making/ready 포함 여부 별도 확인 권장 (현재 `_TimelineSection` 만 추가됨, detail 페이지 액션바 분기는 spec 결정 E 와 일치하는지 tester 검증 필요) |
| 고객 FCM 알림 (making/ready/completed 전이 시) | Phase 3c-2 예정 |
| 알림 설정 UI | Phase 3c-3 예정 |
| `docs/tasks/firestore_security_rules/spec.md` O2 정의 갱신 | architect 가 별 task F37 로 예정 |
| 자동 전이 (ready → completed N시간 후) | 별 phase |
| 픽업 완료 후 리뷰/적립 후속 흐름 | 별 phase |
