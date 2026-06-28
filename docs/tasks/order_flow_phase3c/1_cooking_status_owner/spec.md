# Phase 3c — sub-phase 1: 점주 조리 상태 전이 (Order accepted → making → ready → completed)

> 단일 진실원 / 참고:
> - 큰 그림: [docs/order_flow_summary.md](../../../order_flow_summary.md)
> - 역할 흐름: [docs/processes/role_flows.md](../../../processes/role_flows.md) §4.2
> - 엔티티 lifecycle: [docs/processes/entity_lifecycle.md](../../../processes/entity_lifecycle.md) §2 (Order)
> - 데이터 소유권: [docs/processes/data_ownership.md](../../../processes/data_ownership.md) §2.4 (orders.update)
> - 직전 phase: [docs/tasks/order_flow_phase3a/spec.md](../../order_flow_phase3a/spec.md), [docs/tasks/order_flow_phase3b/spec.md](../../order_flow_phase3b/spec.md), [docs/tasks/owner_order_detail_page/spec.md](../../owner_order_detail_page/spec.md)

---

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 초안 | architect | 본 spec 최초 작성 (결정 A~E + Q1~Q6) |
| 2026-06-07 | architect (정책 변경) | **환불 차단 정책 도입 — 결정 F (Q7)**. 점주가 조리 시작 (`making`) 이후에는 고객의 환불 요청 자체를 시스템 단에서 차단. 영향: ① Firestore Rules O2 분기에서 허용 status 를 `accepted` 만으로 축소, ② 고객 OrderDetailPage 의 환불 요청 버튼 노출 조건을 `accepted` 만으로 축소 + making/ready/completed 시 inline 안내 노출, ③ 본 sub-phase 의 환불 + 조리 status 충돌 케이스 자체 발생 불가 → Q4 / Q6 무효화, ④ status 매트릭스의 making/ready + refundRequest active 케이스 (4개) 삭제. 사유: 카페 픽업 도메인 표준 (조리 시작 = 음료 폐기 비용 발생) + UX 단순화 + 충돌 케이스 자체 제거. |
| 2026-06-21 | architect (drift 해소 / 보완 2) | **"조리 중" 탭 범위 확장 — 결정 H (Q8)** 신규. 라이브 검증 중 발견된 UX 결함 (점주가 "주문 받기" 후 조리 시작 전 `accepted` 상태 주문이 어느 탭에도 표시되지 않음) 을 해소. ① `inProgressOrdersByStoreProvider` statusFilter 를 `{making, ready}` → `{accepted, making, ready}` 로 확장. ② `OwnerInProgressOrderTile._buildActionButton` 에 `accepted → "조리 시작"` 분기 추가 (outlined primary). ③ 탭 라벨 "조리 중" 은 유지 (이름 변경 없음). ④ status 매트릭스 (결정 E) 변경 없음 — 탭 표시 범위만 확장이며 sticky bottom 분기는 그대로. ⑤ F15 정의 정정, F24 액션 버튼 분기 보강. 코드는 fix 완료 (test_report.md 정정 이력 보완 2 참조). 사용자 결정 채택: 탭 2 범위 확장 + 탭 이름 유지. |

---

## 개요

- **목적**: Phase 3a 의 `paid → accepted` 전이만으로는 점주가 주문을 받은 뒤의 진행 상태 (조리 시작 / 준비 완료 / 픽업 완료) 를 시스템에 기록할 수 없다. 본 sub-phase 는 Order 의 `accepted → making → ready → completed` 3-단계 전이를 점주가 갱신할 수 있게 만든다.
- **부수 목적 (정책 변경 추가)**: 조리 진입 (`making`) 이후의 고객 환불 요청을 시스템 단에서 **차단**. 카페 픽업 도메인에서 조리 시작 = 음료 폐기 비용 발생 시점이므로, 환불 가능 status 를 `paid` / `accepted` 만으로 축소한다 (결정 F / Q7). 본 정책 변경은 Phase 3a 의 환불 흐름 (O2 분기) 과 고객 OrderDetailPage 의 환불 버튼 분기에 영향.
- **작업 유형**: 기존 기능 확장 (Order status enum 은 이미 정의됨, 코드 진입점/Repository/Rules/UI 모두 신규 분기 추가) + 기존 환불 정책 축소 (Rules O2 + 고객 UI).
- **트리거 actor**: `owner` 만 (조리 전이). 고객 측은 본 sub-phase 에서 **환불 요청 차단 분기**만 추가 (UI 가드 + Rules 축소). 고객 알림 / 설정은 본 sub-phase 범위 아님.
- **수신 대상**: 본인 매장 (`stores/{storeId}.ownerId == uid`) 의 주문.
- **PG 호출 없음**: 본 3-단계 전이는 외부 결제 게이트웨이 호출이 없는 **순수 Firestore status 전이**. 따라서 **Cloud Function 불필요** ([data_ownership.md §2.4.2](../../../processes/data_ownership.md)), 클라이언트 SDK 가 Firestore Rules O1 패턴을 그대로 확장하여 직접 update.

### Phase 3c 전체 로드맵 (참고)

| sub-phase | 범위 | 본 spec 범위 |
|---|---|---|
| **3c-1 (본 spec)** | Order 조리 단계 전이 (`accepted → making → ready → completed`) + 점주 UI 보강 + Rules O5/O6/O7 신규 분기 | ✅ |
| 3c-2 | 양방향 알림 (점주 상태 갱신 → 고객 FCM 알림 / 고객 UI status 표시 강화) | ❌ |
| 3c-3 | 알림 설정 UI (점주·고객의 알림 toggle) | ❌ |

### 영향 범위

| 레이어 | 영향 |
|---|---|
| **Domain** | `OrderStatus` enum **변경 없음** (이미 `making/ready/completed` 포함). `OrderRepository` 인터페이스에 메서드 3개 신규 추가. UseCase 3개 신규. |
| **Data** | `OrderRepositoryImpl` 메서드 3개 신규. `OrderRemoteDataSource` 는 기존 `update()` 메서드 재사용 (변경 없음). `OrderModel` 에 timestamp 필드 3개 (`makingStartedAt`, `readyAt`, `completedAt`) 추가. `OrderEntity` 도 동일 필드 추가. |
| **Presentation (owner)** | `OwnerOrderDetailPage` sticky bottom 액션 분기 확장 (3개 상태 추가). `OwnerOrdersPage` 탭 구조 검토 (결정 A — 사용자 확인). 기존 `OwnerOrderActionDialogs` 패턴 따라 확정 다이얼로그 추가 (결정 B 에 따라 결정). |
| **Presentation (customer)** | **(결정 F / Q7 신규)** 고객 `OrderDetailPage` 의 환불 요청 버튼 분기 축소. 환불 요청 버튼 노출 status: `accepted` 만. `making` / `ready` / `completed` 에서는 inline 안내 ("조리가 시작되어 환불 요청이 어려워요" 류) 노출. `completed` 의 기존 "완료된 주문" 안내와 통합 검토. |
| **Provider DI** | `order_di_providers.dart` 에 UseCase provider 3개 추가. `OwnerOrdersPage` 가 조리 중 주문 stream 을 쓰면 `inProgressOrdersByStoreProvider` (family) 신규. |
| **Firestore Rules** | `orders.update` 분기 O1 패턴 확장 → 신규 O5 (accepted→making), O6 (making→ready), O7 (ready→completed). 각 전이마다 변경 필드 화이트리스트. **본 sub-phase 핵심 보안 변경**. **(결정 F / Q7 신규)** 기존 O2 (`isCustomerRefundRequest`) 의 허용 status 를 `['accepted', 'making', 'ready', 'completed']` → `['accepted']` 로 축소. |
| **Firestore Indexes** | `firestore.indexes.json` 에 `storeId + status + createdAt` 복합 인덱스가 이미 있다면 추가 작업 없음. `whereIn` 으로 `making/ready` 동시 조회 시 동일 인덱스로 커버 가능 (점검 필요 — developer 확인). |
| **Cloud Functions** | **변경 없음** (트리거 기반 알림은 3c-2). |
| **공통 컴포넌트** | `OrderStatusBadge` 는 이미 `making/ready/completed` 라벨 정의됨 — 재사용. |
| **라우팅** | 변경 없음. |
| **테스트** | 기존 owner_order_detail / phase3a/3b 회귀 + 신규 T1~T13 (§테스트 시나리오) + 환불 차단 회귀 T14~T16. |

### 비범위

- 고객 측 알림 발송 (3c-2 예정). 점주가 making/ready/completed 로 전이할 때 고객 FCM 미발송.
- 고객 UI 의 status 표시 강화 (Order Log / 주문 상세에서 making/ready 진행 표시 UX) — 3c-2 또는 별도.
- 알림 설정 UI (3c-3).
- making / ready / completed 상태의 **환불 후속 처리** (점주 환불 승인 / 거절 / Cloud Function `processRefund`) — 본 sub-phase 는 **고객의 환불 요청 진입 자체를 차단** (결정 F / Q7) 하므로 후속 흐름 호출 경로가 차단됨. 단, 이미 `accepted` 상태에서 환불 요청을 보낸 주문은 그 뒤 점주가 `making` 으로 진입하면 기존 흐름대로 환불 승인/거절 처리 가능 (Rules O3 / `processRefund` 그대로). 본 sub-phase 는 환불 후속 처리 분기 자체는 변경하지 않음.
- 픽업 완료 후 후속 흐름 (리뷰 작성 / 평점 / 적립 등) — 별 phase.
- 자동 전이 (예: ready 후 N시간 경과 → completed 자동) — 별 phase. 본 sub-phase 는 점주 수동 갱신만.
- 매장의 영업시간 / 일시 휴무 검증 (조리 시작 시점에 영업 중인지 확인 등) — 별 phase.
- 다중 매장 / 점원(staff) 권한 위임 (한 매장에 여러 점원) — 별 phase.

---

## 사용자 확인 필요 결정 항목 (architect 잠정안)

다음 결정 A~E 는 architect 잠정안. 사용자 확인 후 designer / developer 호출.

### 결정 A. OwnerOrdersPage 탭 구조 — (B) 조리 중 탭 신규 추가 (architect 추천)

조리 중(`making`/`ready`) 주문을 어디에 표시할지 결정.

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 변경 없음 — 조리 중 주문은 `OwnerOrderDetailPage` 에서만 갱신 가능 | 코드 변경 최소 | 점주가 진행 중인 주문을 한눈에 볼 곳 없음. 신규 탭에서 paid 가 사라지면 어디서 making 으로 전이하는지 불명 → **결정 B 의 액션 흐름 자체가 막힘** |
| **(B) `OwnerOrdersPage` 에 "조리 중" 탭 1개 추가 → 총 3탭 (신규 / 조리 중 / 환불 요청)** (architect 추천) | 점주가 진행 중 주문 일괄 조회 + 카드에서 바로 "준비 완료" / "픽업 완료" 액션. paid → accepted 후 자동으로 이 탭으로 이동. 점주 워크플로우 직관적 | 탭 1개 증가 — 헤더 폭 부담. 카드 UI 추가 (action 버튼 분기 1세트 더) |
| (C) 별도 페이지 (`OwnerInProgressOrdersPage`) | OwnerOrdersPage 가 신규/환불에 집중 | OwnerScaffold 의 BottomNav 구조까지 손대야 함 — 범위 폭증 |
| (D) 검토 현황(brand) 패턴 모방 — 단일 페이지에 세로 섹션 | 한 화면 안에 모든 상태 | 스크롤 길어짐. 모바일 UX 약함 |

채택 = **(B)**. 탭 라벨은 결정 B 의 액션 라벨과 일관되게 정함.

- 탭 1: "신규" (paid)
- 탭 2: "조리 중" (**accepted + making + ready** — 결정 H / Q8 반영, 2026-06-21) — `whereIn`
- 탭 3: "환불 요청" (refundRequest active)

> **2026-06-21 정정 (결정 H / Q8)**: 탭 2 의 범위가 초안 `{making, ready}` → `{accepted, making, ready}` 로 확장됨. 사유는 결정 H 참조. 탭 이름은 "조리 중" 그대로 유지 (점주가 "주문 받기" 후 조리 시작 전 단계도 같은 워크플로우 안에서 처리하는 것이 자연스럽다는 사용자 판단).

**조리 중 탭의 카드 UI**:
- 카드 내부에 status 별 sticky-action: **accepted → "조리 시작"** (결정 H 추가), making → "준비 완료", ready → "픽업 완료"
- 거절 / 환불 액션은 없음. 환불 요청이 들어온 주문은 별도 탭(환불 요청)에서 처리. 단, 조리 중 주문에 환불 요청이 들어오면 카드 상단에 "환불 요청 있음" 배지 노출 (확인 필요 — 결정 C 와 결합).

### 결정 B. 액션 라벨 (마이크로카피)

각 전이의 버튼 라벨.

| 전이 | 옵션 1 | 옵션 2 | architect 추천 |
|---|---|---|---|
| accepted → making | "조리 시작" | "조리하기" | **"조리 시작"** (현재형보다 행위 명사 + 더 명확) |
| making → ready | "준비 완료" | "조리 완료" | **"준비 완료"** (픽업 가능 상태를 강조) |
| ready → completed | "픽업 완료" | "전달 완료" / "수령 확인" | **"픽업 완료"** (Qradar 가 픽업 모델 — `product_scope.md` 와 일관) |

SnackBar / dialog 카피 동일 톤 유지:
- 조리 시작 → "조리를 시작했어요"
- 준비 완료 → "준비를 완료했어요"
- 픽업 완료 → "픽업 완료로 표시했어요"

**확정 다이얼로그 필요 여부** (사용자 확인 필요 — Q1):
- 옵션 A: 모든 전이 즉시 실행 (다이얼로그 없음) — 빠른 응답 우선
- **옵션 B (architect 추천)**: "픽업 완료" 만 확정 다이얼로그 노출 ("픽업 완료로 표시하시겠어요?") — 종결 상태(되돌릴 수 없음) 보호. "조리 시작" / "준비 완료" 는 즉시 실행
- 옵션 C: 모든 전이에 다이얼로그 — 안전하지만 클릭 수 증가

채택 = **옵션 B**. `OwnerOrderActionDialogs.showCompletePickup(context)` 1개 추가.

### 결정 C. 환불 요청 활성 상태와 조리 액션 충돌 처리 — **결정 F 도입으로 단순화 (조리 액션 차단 케이스 거의 사라짐)**

> **2026-06-07 정책 변경 (결정 F / Q7) 이후**: 환불 요청은 status 가 `accepted` 일 때만 발생 가능. status 가 `making` / `ready` / `completed` 로 진입한 뒤에는 신규 환불 요청 자체가 차단됨. 따라서 본 결정 C 가 다루던 "making + refundRequest active" / "ready + refundRequest active" 충돌 케이스는 **시스템 단에서 발생 불가**.

남는 케이스 (Phase 3a 부터 존재했던 케이스, 본 sub-phase 가 변경하지 않음):

- `accepted` + refundRequest active — 기존 owner_order_detail / Phase 3a 흐름 그대로 (sticky bottom = "환불 승인" + "환불 거절"). 점주가 환불 거절 (`deniedAt` set) 해야만 "조리 시작" 액션 노출.
- `accepted` + refundRequest denied — sticky bottom 에 "조리 시작" 액션 노출 (결정 E 매트릭스 참조).
- `accepted` → 점주가 조리 시작 시도 시 refundRequest 가 active 라면 "조리 시작" 액션은 매트릭스에서 노출되지 않음 (Phase 3a 패턴 그대로). 별도 신규 차단 분기 필요 없음.

엣지 케이스: 점주가 accepted + refundRequest active 상태에서 조리 시작을 시도 → Rules O5 가 `resource.data.status == 'accepted'` 만 검증하므로 status 측은 통과 가능. 그러나 UI 매트릭스 (결정 E) 가 환불 요청 active 시 조리 액션을 노출하지 않으므로 정상 흐름에서 발생 안 함. Rules 추가 차단 불필요.

채택 = **단순화** (별도 옵션 채택 없음, Phase 3a 흐름 + 결정 E 매트릭스로 충분).

### 결정 D. timestamp 필드명 — (A) `makingStartedAt`, `readyAt`, `completedAt` (architect 추천)

기존 Order 필드 (`acceptedAt`, `cancelledAt`, `refundedAt`) 와 네이밍 일관성 검토.

| 옵션 | 필드명 |
|---|---|
| **(A)** (architect 추천) | `makingStartedAt`, `readyAt`, `completedAt` |
| (B) | `startedMakingAt`, `readyAt`, `pickedUpAt` |
| (C) | `makingAt`, `readyAt`, `completedAt` |

채택 근거: 기존 `acceptedAt` (전이 완료 시점), `cancelledAt` (취소 완료 시점) 패턴 → **"상태 명 + At"** 가 자연스러움.
- `acceptedAt` ↔ `<status>At` 패턴 → `readyAt`, `completedAt` 은 그대로 패턴 일치.
- 단 `making` 은 "조리 중(진행 중)" 이라는 진행 상태이므로 단순 `makingAt` 은 모호 (`making 으로 들어간 시점` 의도가 약함) → **`makingStartedAt`** 으로 명시적 시작 시점 강조.

채택 = **(A)** — `makingStartedAt` / `readyAt` / `completedAt`.

(참고: 코드/Rules 화이트리스트가 위 명을 정확히 사용해야 함. drift 방지.)

### 결정 E. status 매트릭스 — sticky bottom 액션 + body 표시 정합 (결정 F / Q7 적용 후 단순화)

`OwnerOrderDetailPage` 의 sticky bottom 액션과 본문 inline 안내 카드.

> **2026-06-07 정책 변경 (결정 F) 반영**: making / ready + refundRequest active 행 4개 삭제 (시스템 단 차단으로 발생 불가). 환불 요청은 `accepted` 단계에서만 발생 가능.

| status | refundRequest | sticky bottom 액션 | inline 안내 카드 (액션 없을 때) |
|---|---|---|---|
| `paid` | (무관) | "주문 받기" + "거절" | — |
| `accepted` | null | **"조리 시작"** (full width 또는 primary) | — |
| `accepted` | active | "환불 승인" + "환불 거절" (기존 Phase 3a 흐름 그대로, 조리 액션 미노출) | — |
| `accepted` | denied | **"조리 시작"** + 위에 거절 섹션 (회색 톤) | — |
| `making` | null | **"준비 완료"** | — |
| `making` | denied | **"준비 완료"** + 위에 거절 섹션 (이전 accepted 단계에서 거절된 이력) | — |
| `ready` | null | **"픽업 완료"** (확정 다이얼로그 — 결정 B) | — |
| `ready` | denied | **"픽업 완료"** + 위에 거절 섹션 | — |
| `completed` | (무관) | 없음 | "픽업이 완료된 주문이에요." |
| `cancelled` | — | 없음 | "취소된 주문이에요." |
| `refunded` | — | 없음 | "환불이 완료된 주문이에요." |

삭제된 행 (결정 F / Q7 으로 발생 불가):
- ~~`making` + active~~ — 환불 요청은 `accepted` 단계에서만 가능. making 진입 후 신규 환불 요청 차단 (Rules O2).
- ~~`ready` + active~~ — 동일 사유.

(`accepted` 의 환불 요청 active 케이스는 기존 phase3b/owner_order_detail 에서 이미 처리됨. 본 sub-phase 는 매트릭스 신규 케이스로 making/ready 의 **denied 이력 보존** 만 정의.)

### 결정 F. 환불 요청 허용 status 축소 — `paid` / `accepted` 만 허용 (Q7, 2026-06-07 사용자 확정)

조리 시작 (`making`) 이후의 환불 요청을 시스템 단에서 **차단**한다.

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 현행 유지 — `accepted` / `making` / `ready` / `completed` 전 구간 환불 요청 허용 (Phase 3a O2 정의) | 고객 자유도 ↑. 거절 권한은 점주에게 있음 | 카페 폐기 비용 부담 — 음료가 만들어지거나 픽업된 뒤의 환불 요청 자체가 비합리적 흐름. 점주 처리 비용 증가. UX 매트릭스 복잡도 ↑ (making/ready + refundRequest active 4개 케이스) |
| **(B) 환불 요청 허용 status 를 `accepted` 만으로 축소 (paid 는 cancel 흐름 유지)** (사용자 결정 / architect 확정) | 카페 픽업 도메인 표준. 조리 진입 = 폐기 비용 발생점에서 명확히 컷오프. 충돌 케이스 자체 제거 → 매트릭스 단순화. 점주 워크플로우 단순. | 고객이 `making` 이후 마음 바꿈 → 매장에 직접 연락해야 함. 앱 내 공식 채널 없음 (향후 별 phase 에서 in-app contact 검토 가능) |
| (C) 매장 별 설정 (영업자가 환불 허용 시점을 선택) | 유연 | 정책 복잡, 고객/점주 양측 인지 부담 |

채택 = **(B)**.

#### 영향 — Rules O2

기존 (Phase 3a `firestore_security_rules/spec.md` §O2):

```
function isCustomerRefundRequest() {
  return resource.data.userId == request.auth.uid
    && resource.data.status in ['accepted', 'making', 'ready', 'completed']
    && (resource.data.refundRequest == null
        || resource.data.refundRequest.deniedAt == null)
    && onlyChangedFields(['refundRequest', 'updatedAt'])
    && request.resource.data.refundRequest.keys().hasOnly(['reason', 'requestedAt']);
}
```

변경 후 (본 sub-phase 에서 수정):

```
function isCustomerRefundRequest() {
  return resource.data.userId == request.auth.uid
    && resource.data.status == 'accepted'          // ⬅ 'accepted' 만 허용 (축소)
    && (resource.data.refundRequest == null
        || resource.data.refundRequest.deniedAt == null)
    && onlyChangedFields(['refundRequest', 'updatedAt'])
    && request.resource.data.refundRequest.keys().hasOnly(['reason', 'requestedAt']);
}
```

#### 영향 — 고객 OrderDetailPage UI

`lib/presentation/customer/order/orders/order_detail_page.dart` 의 sticky bottom action 분기:

- 현재 (Phase 3a 구현): `accepted` / `making` / `ready` 모두에서 환불 요청 버튼 노출 (refundRequest 미존재 시) / 환불 요청 중 안내 (active 시) / 환불 거절 안내 (denied 시).
- 변경 후 (본 sub-phase): `accepted` 만 위 분기 유지. `making` / `ready` / `completed` 는 **환불 요청 버튼 미노출** + inline 안내 카드 노출.

신규 inline 안내 카피 (카피는 designer 가 결정 — 기본안):
- `making`: "조리가 시작되어 환불 요청이 어려워요. 매장에 직접 문의해 주세요."
- `ready`: "픽업 대기 상태로 환불 요청이 어려워요. 매장에 직접 문의해 주세요."
- `completed`: (기존 "픽업 완료" 안내 유지 — 변경 없음)

`accepted` + refundRequest active / denied 케이스의 안내 카피는 기존 Phase 3a 그대로 유지 ("환불 요청 중입니다" / "환불이 거절되어 더 이상 요청할 수 없어요").

#### 영향 — 매트릭스

결정 E 의 4개 행 (`making`+active, `making`+denied 의 inline 안내 카피 행, `ready`+active, `ready`+denied 의 inline 안내 카피 행) 중 active 2개 행 삭제 (위 결정 E 매트릭스 반영 완료). denied 2개 행은 유지 (`accepted` 단계에서 거절된 환불 요청 이력 보존 — 정상 케이스).

### 결정 H. "조리 중" 탭 범위 확장 — `accepted` 포함 (Q8, 2026-06-21 사용자 확정)

본 sub-phase 의 라이브 검증 (test_report.md 정정 이력 보완 2) 중 발견된 UX 결함을 해소하기 위한 정책.

**문제**:
- spec 초안 (F15) 은 `inProgressOrdersByStoreProvider.statusFilter = {making, ready}` 로 설계.
- 이 경우 점주가 "신규" 탭에서 "주문 받기" 를 누르면 주문 status 가 `paid → accepted` 로 전이하면서 **"신규" 탭에서 사라지지만**, 동시에 "조리 중" 탭의 필터 (`{making, ready}`) 에는 들어가지 않아 어느 탭에도 나타나지 않음.
- 결과: 점주가 다시 매장 상세 / 다른 경로를 거치지 않고서는 "조리 시작" 액션을 누를 수 있는 탭형 진입점이 없음 → 워크플로우 단절.

**옵션 검토**:

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 탭 2 범위 확장 — `{accepted, making, ready}` + 탭 이름 "조리 중" 유지 (사용자 채택) | 점주 워크플로우 연속 — 주문 받기 직후 같은 탭에서 "조리 시작" 액션. 탭 이름 변경 없음 — 다른 문서 / 화면 영향 최소. | 탭 이름 ("조리 중") 이 엄밀하게는 `accepted` 를 포함하지 않는 의미. 단, accepted = "조리 대기 / 곧 시작" 으로 자연스럽게 해석 가능 |
| (B) 탭 2 범위 확장 + 탭 이름 변경 ("진행 중" / "처리 중" 등) | 의미적 정확성 | 다른 문서 / 매트릭스 / spec 표 모두 갱신 필요. 변경 범위 폭증 |
| (C) "신규" 탭이 accepted 도 포함 (paid + accepted) | 탭 1 안에서 "주문 받기" → "조리 시작" 한 번에 처리 | "신규" 라벨이 모호해짐. paid 와 accepted 의 액션 분기 (주문 받기 / 거절 vs 조리 시작) 가 동일 탭에 섞임 |
| (D) 별도 4번째 탭 신규 추가 ("접수 완료") | 의미적 분리 | 탭 4개 — 헤더 폭 부담. 점주가 매번 탭을 옮겨다녀야 함 |

채택 = **(A)**. 사용자 결정 (2026-06-21).

**채택 근거**:
- 점주 워크플로우의 연속성 — `paid` (신규) → `accepted` (조리 대기) → `making` (조리 중) → `ready` (픽업 대기) → `completed` 모두 점주가 카드에서 단일 액션 버튼으로 다음 단계로 보낼 수 있어야 자연스러움.
- 탭 라벨 "조리 중" 의 의미를 "조리 워크플로우 안에 있는 모든 주문" 으로 확장 해석. 이 해석은 점주의 멘탈 모델 (주문을 받았으면 곧 조리 시작) 과 일치.
- 다른 영역 (status 매트릭스 — 결정 E, sticky bottom 분기, customer UI, Rules) 은 영향 없음. 점주 탭의 표시 범위만 확장.

**영향**:
- **F15 정정**: `inProgressOrdersByStoreProvider.statusFilter` = `{accepted, making, ready}`. `whereIn` 쿼리는 기존 `storeId + status + createdAt` 복합 인덱스로 그대로 커버.
- **F24 보강**: `OwnerInProgressOrderTile._buildActionButton` 에 `accepted → "조리 시작"` 분기 신규 추가. UI 톤은 `making → "준비 완료"` 와 동일한 outlined primary (중간 단계 전이) — `ready → "픽업 완료"` 만 filled primary 유지 (종결 액션).
- **데이터 흐름 E (조리 중 탭 리스트)**: `statusFilter:{accepted, making, ready}` 로 갱신.
- **status 매트릭스 (결정 E)**: 변경 없음 — sticky bottom 분기는 그대로. accepted 의 단일 액션 ("조리 시작") 행은 이미 결정 E 매트릭스에 정의됨.
- **role_flows.md §4.2**: 점주 흐름 표의 "조리 시작 (accepted→making)" 행은 그대로 (`_InProgressOrdersTab` 진입점). 본 결정으로 `_InProgressOrdersTab` 이 표시하는 status 범위에 `accepted` 가 포함됨이 명확해짐.

**확인 사항**:
- 시각적 차별화: 카드의 status badge 색상으로 accepted / making / ready 구분 (`OrderStatusBadge` 재사용 — 변경 없음).
- 카드 정렬: 기존 `createdAt desc` 그대로. accepted 가 가장 최근에 받은 주문이므로 자연스럽게 상단에 위치.
- empty 메시지 ("조리 중인 주문이 없어요") 는 그대로 유지 — 의미 확장에 자연스러움.

---

## 요구사항

### 기능 요구사항

#### 신규 status 전이 (3개)

- [ ] **F1**. `accepted → making`: 점주가 "조리 시작" 액션 → `status='making'`, `makingStartedAt=now`, `updatedAt=now`. 다른 필드 변경 금지.
- [ ] **F2**. `making → ready`: 점주가 "준비 완료" 액션 → `status='ready'`, `readyAt=now`, `updatedAt=now`. 다른 필드 변경 금지.
- [ ] **F3**. `ready → completed`: 점주가 "픽업 완료" 액션 → `status='completed'`, `completedAt=now`, `updatedAt=now`. 다른 필드 변경 금지.
- [ ] **F4**. 모든 전이는 본인 매장 (`stores/{storeId}.ownerId == uid`) 의 주문에 한정.
- [ ] **F5**. 환불 요청 활성 (`refundRequest != null && deniedAt == null`) 상태에서 F1~F3 액션 시도는 클라이언트에서 **차단**. 단 결정 F (Q7) 적용 후 발생 가능 케이스는 **accepted + active 만** 남음 (이는 기존 Phase 3a / owner_order_detail 매트릭스가 이미 처리). making / ready / completed 의 active 케이스는 시스템 단 차단으로 발생 불가. Rules 단 추가 차단 없음 (단순화).
- [ ] **F6**. 모든 전이 후 stream 으로 status 변경이 도착하면 UI 가 자동 갱신 (액션 영역이 다음 단계 액션으로 자동 전환).

#### Repository 메서드 신규

- [ ] **F7**. `OrderRepository.setMakingByOwner(orderId)` — F1 호출.
- [ ] **F8**. `OrderRepository.setReadyByOwner(orderId)` — F2 호출.
- [ ] **F9**. `OrderRepository.setCompletedByOwner(orderId)` — F3 호출.
- [ ] **F10**. 모두 Firestore Rules 화이트리스트와 정확히 일치하는 필드만 update (drift 방지). 각 메서드는 단일 status 전이 + 단일 timestamp + updatedAt 만 set.

#### UseCase 신규

- [ ] **F11**. `StartMakingOrderUseCase(repo).call(orderId)` — `repo.setMakingByOwner`.
- [ ] **F12**. `MarkReadyOrderUseCase(repo).call(orderId)` — `repo.setReadyByOwner`.
- [ ] **F13**. `CompletePickupOrderUseCase(repo).call(orderId)` — `repo.setCompletedByOwner`.

(이름 결정: 기존 `AcceptOrderUseCase` 패턴은 동사 + Order. 본 3개는 결정 B 의 라벨(`조리 시작`/`준비 완료`/`픽업 완료`) 를 영문 동사로 번역.)

#### Provider 신규

- [ ] **F14**. `startMakingOrderUseCaseProvider` / `markReadyOrderUseCaseProvider` / `completePickupOrderUseCaseProvider` 를 `order_di_providers.dart` 에 추가.
- [ ] **F15** (2026-06-21 정정, 결정 H / Q8). `inProgressOrdersByStoreProvider` (`StreamProvider.family<List<OrderEntity>, String>`). `watchStoreOrdersUseCase.call(storeId, statusFilter: {accepted, making, ready})`. **`accepted` 포함은 결정 H** — 점주가 "주문 받기" 직후 "조리 시작" 액션을 같은 탭에서 처리할 수 있어야 한다는 워크플로우 연속성 요구. (원안: `{making, ready}` 만 — drift 정정).

#### OwnerOrderDetailPage 확장

- [ ] **F16**. sticky bottom 액션 분기 매트릭스 (결정 E) 구현. 환불 요청 우선 (결정 C).
- [ ] **F17**. `_NoActionInfoCard` 메시지 갱신 — making/ready 의 환불 요청 활성 안내 (결정 C 의 inline 안내).
- [ ] **F18**. 픽업 완료 액션은 확정 다이얼로그 (`OwnerOrderActionDialogs.showCompletePickup`) 노출 (결정 B 옵션 B).
- [ ] **F19**. 액션 진행 중 `_isActionLoading` 가드. spinner 노출. 중복 탭 방지.
- [ ] **F20**. 액션 성공 시 SnackBar (결정 B 카피).
- [ ] **F21**. 액션 후 페이지 pop 하지 않음 — stream 갱신으로 액션 영역 자동 재구성.

#### OwnerOrdersPage 탭 확장 (결정 A 옵션 B 채택 시)

- [ ] **F22**. `TabController` length 2 → 3. 탭 라벨: "신규" / "조리 중" / "환불 요청".
- [ ] **F23**. 신규 `_InProgressOrdersTab` 추가. `inProgressOrdersByStoreProvider(storeId)` watch.
- [ ] **F24** (2026-06-21 보강, 결정 H / Q8). 신규 카드 위젯 `OwnerInProgressOrderTile`:
  - 주문 요약 (주문번호 / 시각 / status badge / 메뉴 요약)
  - status 별 액션 버튼 (3개 분기):
    - **`accepted` → "조리 시작"** (outlined primary — 결정 H 신규 추가)
    - `making` → "준비 완료" (outlined primary — 중간 단계 전이)
    - `ready` → "픽업 완료" (filled primary — 종결 액션. 픽업 완료 확정 다이얼로그 호출)
  - 환불 요청 있음 시 상단 "환불 요청 있음" 배지 (결정 C 보조) — design.md Q7 단순화 후 making/ready 에서는 발생 불가. accepted 에서만 노출 가능 케이스 존재
  - 카드 onTap → `OwnerOrderDetailPage` push
- [ ] **F25**. `_processingOrderIds` 가드 그대로 사용 — 카드 액션 중복 탭 방지.

#### Firestore Rules 보강

- [ ] **F26**. `orders.update` 의 분기에 신규 함수 3개 추가 + `allow update` 표현식에 OR 추가.
- [ ] **F27**. O5: `isOwnerStartMakingUpdate()`:
  ```
  isStoreOwner(resource.data.storeId)
  && resource.data.status == 'accepted'
  && request.resource.data.status == 'making'
  && onlyChangedFields(['status', 'makingStartedAt', 'updatedAt'])
  ```
- [ ] **F28**. O6: `isOwnerMarkReadyUpdate()`:
  ```
  isStoreOwner(resource.data.storeId)
  && resource.data.status == 'making'
  && request.resource.data.status == 'ready'
  && onlyChangedFields(['status', 'readyAt', 'updatedAt'])
  ```
- [ ] **F29**. O7: `isOwnerCompletePickupUpdate()`:
  ```
  isStoreOwner(resource.data.storeId)
  && resource.data.status == 'ready'
  && request.resource.data.status == 'completed'
  && onlyChangedFields(['status', 'completedAt', 'updatedAt'])
  ```
- [ ] **F30**. 위 함수들은 기존 `isOwnerAcceptUpdate` (O1) 패턴과 정확히 동일한 구조 (3 line `&& chain` + 화이트리스트). drift 방지.
- [ ] **F31**. `data_ownership.md §2.4.1` 표 update — O5/O6/O7 분기 명시. 추가로 O2 분기의 허용 status 를 `accepted` 만으로 축소 반영 (결정 F).
- [ ] **F32**. `entity_lifecycle.md §2` 다이어그램 + 전이 표 update — `accepted→making`, `making→ready`, `ready→completed` 의 actor/메커니즘/조건/필드/Rules 분기 row 추가. `2.5 보류/미구현` 에서 making/ready/completed 항목 제거. §2.3 refundRequest lifecycle 의 "(없음) → Requested" 조건을 `status == 'accepted'` 만으로 축소 (결정 F 반영).
- [ ] **F36 (결정 F / Q7)**. Rules O2 (`isCustomerRefundRequest`) 의 허용 status 축소: `in ['accepted', 'making', 'ready', 'completed']` → `== 'accepted'` 만 허용. 위 결정 F §"영향 — Rules O2" 의 함수 시그니처 참조.
- [ ] **F37 (결정 F / Q7)**. `firestore_security_rules/spec.md` §O2 정의도 동일 축소 — 본 sub-phase 작업 후 architect 가 별도 task 분리 또는 즉시 갱신 (인계 — §"다른 task 영향 추적" 참조).

#### Entity / Model timestamp 필드 추가

- [ ] **F33**. `OrderEntity` 에 `makingStartedAt`, `readyAt`, `completedAt` (`DateTime?`) 추가 — freezed regenerate.
- [ ] **F34**. `OrderModel` 동일 필드 + `fromFirestore` / `toFirestore` / `toEntity` 매핑.
- [ ] **F35**. 기존 doc(필드 미존재)도 안전하게 deserialize (`toDate(data['makingStartedAt'])` → null).

#### 고객 OrderDetailPage 환불 차단 (결정 F / Q7)

- [ ] **F38**. `lib/presentation/customer/order/orders/order_detail_page.dart` 의 sticky bottom 분기에서 `case OrderStatus.making:` / `case OrderStatus.ready:` 의 환불 요청 버튼 노출을 제거. 신규 inline 안내 카드만 노출 (카피는 designer 가 결정 — 기본안: "조리가 시작되어 환불 요청이 어려워요. 매장에 직접 문의해 주세요." / "픽업 대기 상태로 환불 요청이 어려워요. 매장에 직접 문의해 주세요.").
- [ ] **F39**. `case OrderStatus.accepted:` 의 기존 분기는 **변경 없음** (Phase 3a 그대로 유지) — 본 정책 변경의 컷오프 지점.
- [ ] **F40**. 기존 refundRequest active / denied 상태일 때의 안내 카피 (`'환불 요청 중입니다'` / `'환불이 거절되어 더 이상 요청할 수 없어요'`) 는 `accepted` 상태에서만 보이도록 분기를 좁힘. making / ready 에서 active 가 발생하려면 accepted 단계에서 요청 후 점주가 조리 시작한 케이스로, 이 경우의 카피 톤은 designer 가 결정 (기본안: 기존 카피 유지 또는 "환불 요청 처리를 기다리는 중이에요"). denied 도 동일.
- [ ] **F41**. `case OrderStatus.completed:` 의 기존 "완료된 주문" 안내는 **변경 없음**. 환불 요청 진입 차단 정책에 의해 자연스럽게 환불 버튼 미노출 (현재도 미노출).

### UI 요구사항 (designer 위임)

- [ ] **U1**. `OwnerOrdersPage` 3탭 레이아웃 (헤더 폭 / 라벨 / indicator).
- [ ] **U2**. `OwnerInProgressOrderTile` 카드 디자인:
  - making / ready 시각 차별화 (badge 색 + 카드 배경 톤)
  - 액션 버튼 (1개) — 결정 B 라벨 + primary 톤
  - 환불 요청 배지 (결정 C 보조)
- [ ] **U3**. `OwnerOrderDetailPage` sticky bottom 의 단일 액션 (making/ready 시 1개 버튼 full-width 또는 2:1 비율 검토 — paid 패턴과 시각 일관).
- [ ] **U4**. 픽업 완료 확정 다이얼로그 디자인 (`OwnerOrderActionDialogs.showCompletePickup`) — 환불 승인 다이얼로그 (`showApproveRefund`) 패턴 재사용.
- [ ] **U5**. 색상은 `AppColors` 만 사용 (절대 규칙).
- [ ] **U6**. `OrderStatusBadge` 의 making/ready/completed 색상은 이미 정의됨 — 재사용.
- [ ] **U7 (결정 F / Q7)**. 고객 `OrderDetailPage` 의 making / ready 환불 차단 inline 안내 카드 디자인 (카피 톤 + 시각 — 기존 phase3a 의 "환불 요청 중입니다" 카드 패턴 재사용 가능). 매장 연락 안내 문구 포함 검토.

### 상태 요구사항

| 상태 | UI |
|---|---|
| loading (탭 진입) | shimmer (기존 owner orders 패턴) |
| error (stream error) | "다시 시도" 버튼 |
| empty (조리 중 주문 없음) | "조리 중인 주문이 없어요" |
| 액션 진행 중 | 버튼 disabled + spinner |
| 액션 완료 후 | SnackBar + stream 자동 갱신 → 카드/상세 페이지 액션 영역 자동 재계산 |

---

## 데이터 모델

### Entity 변경

```dart
@freezed
abstract class OrderEntity with _$OrderEntity {
  const factory OrderEntity({
    // ... 기존 필드 ...
    DateTime? acceptedAt,
    DateTime? cancelledAt,
    DateTime? refundedAt,
    // 신규
    DateTime? makingStartedAt,  // accepted → making 전이 시점
    DateTime? readyAt,          // making → ready 전이 시점
    DateTime? completedAt,      // ready → completed 전이 시점
  }) = _OrderEntity;
}
```

### Model 변경

- `OrderModel` 도 동일 3개 필드 추가.
- `fromFirestore` 의 `toDate()` 매핑에 3개 row 추가.
- `toFirestore` 의 conditional set 에 3개 row 추가 (null 이면 미포함).
- `toEntity` 에서 그대로 전달.

### Firestore 문서 변경 (기존 doc 호환)

- 기존 doc 은 새 필드 미존재 → 모두 null 로 deserialize. 안전.
- 새 전이 시점에 해당 필드만 set (`OrderRepositoryImpl.setMakingByOwner` 등).

---

## 레이어 설계

### Domain

#### Entity
- `OrderEntity` 에 `makingStartedAt`, `readyAt`, `completedAt` (`DateTime?`) 추가 — F33.

#### Repository Interface (`lib/domain/repositories/order_repository.dart`)

```dart
abstract class OrderRepository {
  // ... 기존 메서드 ...

  /// 점주가 조리 시작 → status: accepted → making.
  Future<void> setMakingByOwner(String orderId);

  /// 점주가 준비 완료 → status: making → ready.
  Future<void> setReadyByOwner(String orderId);

  /// 점주가 픽업 완료 → status: ready → completed.
  Future<void> setCompletedByOwner(String orderId);
}
```

#### UseCase (각각 신규 파일)

- `lib/domain/usecases/start_making_order_use_case.dart`
- `lib/domain/usecases/mark_ready_order_use_case.dart`
- `lib/domain/usecases/complete_pickup_order_use_case.dart`

각 UseCase 구조 (기존 `AcceptOrderUseCase` 와 동일 패턴):

```dart
class StartMakingOrderUseCase {
  final OrderRepository _repo;
  const StartMakingOrderUseCase(this._repo);

  Future<void> call(String orderId) => _repo.setMakingByOwner(orderId);
}
```

### Data

#### Model (`lib/data/models/order_model.dart`)

- 3개 필드 + fromFirestore / toFirestore / toEntity 매핑 추가 — F34, F35.

#### DataSource (`lib/data/datasources/remote/order_remote_data_source.dart`)

- **변경 없음**. 기존 `update(orderId, data)` 메서드 그대로 사용.

#### Repository Implementation (`lib/data/repositories/order_repository_impl.dart`)

기존 `setAcceptedByOwner` 와 정확히 동일한 패턴:

```dart
@override
Future<void> setMakingByOwner(String orderId) async {
  final now = DateTime.now();
  await _ds.update(orderId, <String, dynamic>{
    'status': OrderStatus.making.name,
    'makingStartedAt': Timestamp.fromDate(now),
    'updatedAt': Timestamp.fromDate(now),
  });
}

@override
Future<void> setReadyByOwner(String orderId) async {
  final now = DateTime.now();
  await _ds.update(orderId, <String, dynamic>{
    'status': OrderStatus.ready.name,
    'readyAt': Timestamp.fromDate(now),
    'updatedAt': Timestamp.fromDate(now),
  });
}

@override
Future<void> setCompletedByOwner(String orderId) async {
  final now = DateTime.now();
  await _ds.update(orderId, <String, dynamic>{
    'status': OrderStatus.completed.name,
    'completedAt': Timestamp.fromDate(now),
    'updatedAt': Timestamp.fromDate(now),
  });
}
```

⚠ Rules 화이트리스트와 정확히 동일한 키 집합 사용 (drift 방지). status / `<status>At` / updatedAt — 3개만.

### Presentation

#### Provider (`lib/presentation/customer/order/orders/providers/order_di_providers.dart`)

- F14 UseCase provider 3개 추가.
- F15 `inProgressOrdersByStoreProvider` (family) 추가 — 결정 A (B) 채택 시.

```dart
// UseCase
final startMakingOrderUseCaseProvider =
    Provider<StartMakingOrderUseCase>((ref) {
  return StartMakingOrderUseCase(ref.watch(orderRepositoryProvider));
});

final markReadyOrderUseCaseProvider = Provider<MarkReadyOrderUseCase>((ref) {
  return MarkReadyOrderUseCase(ref.watch(orderRepositoryProvider));
});

final completePickupOrderUseCaseProvider =
    Provider<CompletePickupOrderUseCase>((ref) {
  return CompletePickupOrderUseCase(ref.watch(orderRepositoryProvider));
});

// Stream (조리 중 탭)
final inProgressOrdersByStoreProvider =
    StreamProvider.family<List<OrderEntity>, String>((ref, storeId) {
  return ref
      .read(watchStoreOrdersUseCaseProvider)
      .call(storeId, statusFilter: {OrderStatus.making, OrderStatus.ready});
});
```

#### Page

- `lib/presentation/owner/orders/owner_orders_page.dart`
  - TabController length 3, 탭 라벨 / 인덱스 갱신 — F22.
  - `_InProgressOrdersTab` 신규 추가 — F23.
  - 액션 핸들러 추가 (`_startMaking`, `_markReady`, `_completePickup`) — 기존 `_acceptOrder` 패턴 그대로.
- `lib/presentation/owner/orders/owner_order_detail_page.dart`
  - `_hasActionBar` 매트릭스 확장 (결정 E).
  - 액션 핸들러 3개 추가 (`_startMaking`, `_markReady`, `_completePickup`).
  - `_ActionBar` 분기 확장:
    - paid → 기존 그대로
    - 환불 요청 활성 (status ∈ {accepted, making, ready}) → 환불 승인/거절 (기존 그대로 + making/ready 도 포함)
    - accepted + (refundRequest null OR denied) → "조리 시작" (full width)
    - making + (refundRequest null OR denied) → "준비 완료" (full width)
    - ready + (refundRequest null OR denied) → "픽업 완료" (full width, 확정 다이얼로그)
  - `_NoActionInfoCard` 메시지: F17.

#### Widget

- `lib/presentation/owner/orders/widgets/owner_in_progress_order_tile.dart` (신규) — `OwnerNewOrderTile` / `OwnerRefundRequestTile` 와 동일 패턴.
- `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart`
  - `showCompletePickup(context, {storeName, customerName})` 신규 정적 메서드 추가 — F18, U4.

#### Customer Presentation (결정 F / Q7)

- `lib/presentation/customer/order/orders/order_detail_page.dart`
  - sticky bottom 분기 (`_buildActionBar` 내부 또는 동등 위치) 의 `case OrderStatus.making:` / `case OrderStatus.ready:` 처리 수정 — F38, F40.
  - `accepted` 분기는 그대로 유지 (F39).
  - inline 안내 카드 위젯은 기존 `Container + Text` 패턴 재사용 (Phase 3a 의 "환불 요청 중입니다" 카드 톤). designer 가 카피 / 색상 / 보조 안내 (매장 연락 안내) 결정 — U7.

### Firestore Rules (`firestore.rules`)

```
match /orders/{orderId} {
  // 기존 O1~O4 그대로 +
  allow update: if isAdmin()                       // O4
                || isOwnerAcceptUpdate()            // O1
                || isCustomerRefundRequest()        // O2 (본 sub-phase 에서 허용 status 축소 — 결정 F)
                || isOwnerDenyRefund()              // O3
                || isOwnerStartMakingUpdate()       // O5 신규
                || isOwnerMarkReadyUpdate()         // O6 신규
                || isOwnerCompletePickupUpdate();   // O7 신규

  // ─────────── O2 축소 (결정 F / Q7, 본 sub-phase) ───────────
  // 환불 요청 허용 status: ['accepted', 'making', 'ready', 'completed'] → 'accepted' 만.
  function isCustomerRefundRequest() {
    return resource.data.userId == request.auth.uid
      && resource.data.status == 'accepted'        // ⬅ 'accepted' 만 (축소)
      && (resource.data.refundRequest == null
          || resource.data.refundRequest.deniedAt == null)
      && onlyChangedFields(['refundRequest', 'updatedAt'])
      && request.resource.data.refundRequest.keys().hasOnly(['reason', 'requestedAt']);
  }

  // ─────────── 신규 분기 ───────────
  function isOwnerStartMakingUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'accepted'
      && request.resource.data.status == 'making'
      && onlyChangedFields(['status', 'makingStartedAt', 'updatedAt']);
  }

  function isOwnerMarkReadyUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'making'
      && request.resource.data.status == 'ready'
      && onlyChangedFields(['status', 'readyAt', 'updatedAt']);
  }

  function isOwnerCompletePickupUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'ready'
      && request.resource.data.status == 'completed'
      && onlyChangedFields(['status', 'completedAt', 'updatedAt']);
  }
}
```

⚠ 화이트리스트 키와 Repository 가 set 하는 키가 정확히 일치해야 함 (`status`, `<status>At`, `updatedAt`).

⚠ O2 축소는 **Phase 3a 환불 흐름의 보안 분기 변경**. tester 가 emulator 로 making / ready / completed 상태의 refundRequest 시도 시 `permission-denied` 응답을 확인 (T15).

### Firestore Indexes

- `inProgressOrdersByStoreProvider` 가 `storeId == X && status in [making, ready] && orderBy(createdAt desc)` 쿼리 → 기존 `storeId + status + createdAt` 복합 인덱스로 커버 (Phase 3a 에서 생성됨, 확인 필요). 누락 시 console error → developer 가 `firestore.indexes.json` 보강.

---

## 데이터 흐름

### A. accepted → making (점주 "조리 시작")

```
[OwnerOrdersPage 조리 중 탭 또는 OwnerOrderDetailPage]
"조리 시작" 탭 → ref.read(startMakingOrderUseCaseProvider).call(orderId)
  → StartMakingOrderUseCase
  → OrderRepository.setMakingByOwner(orderId)
  → OrderRemoteDataSource.update(orderId, {status:'making', makingStartedAt, updatedAt})
  → Firestore Rules O5 통과 (storeOwner + accepted→making + 화이트리스트)
  → Firestore doc update
  → stream emit (status=making, makingStartedAt set)
  → UI 자동 갱신 (액션 영역이 "준비 완료" 로 전환, OrderStatusBadge='제조 중')
```

### B. making → ready (점주 "준비 완료")

```
"준비 완료" 탭 → ref.read(markReadyOrderUseCaseProvider).call(orderId)
  → MarkReadyOrderUseCase → setReadyByOwner
  → update({status:'ready', readyAt, updatedAt})
  → Rules O6 통과
  → stream → UI 갱신 (액션 영역 = "픽업 완료", badge='픽업 대기')
```

### C. ready → completed (점주 "픽업 완료")

```
"픽업 완료" 탭 → OwnerOrderActionDialogs.showCompletePickup(context)
  → confirmed = true 일 때만
  → ref.read(completePickupOrderUseCaseProvider).call(orderId)
  → CompletePickupOrderUseCase → setCompletedByOwner
  → update({status:'completed', completedAt, updatedAt})
  → Rules O7 통과
  → stream → UI 갱신 (액션 영역 사라짐, badge='완료', inline 안내 노출)
```

### D. 환불 요청 활성 상태의 액션 우선순위 (결정 F / Q7 적용 후 단순화)

```
[Phase 3a 기존 흐름 — 변경 없음]
status == 'accepted' && order.refundRequest != null && order.refundRequest.deniedAt == null
  → sticky bottom = "환불 승인" + "환불 거절" (기존 그대로)
  → "조리 시작" 액션 미노출
  → 점주가 환불 거절 (deniedAt set) 시 → stream 갱신 → "조리 시작" 노출

[making / ready / completed + refundRequest active] — 시스템 단 차단으로 발생 불가 (결정 F)
  → 고객이 환불 요청 진입 시 Rules O2 가 차단 → permission-denied
  → 고객 UI 가 making/ready/completed 에서 환불 요청 버튼 미노출 (사전 차단)
```

### E. OwnerOrdersPage "조리 중" 탭 리스트 (결정 H / Q8 정정 후)

```
inProgressOrdersByStoreProvider(storeId) — StreamProvider.family
  → WatchStoreOrdersUseCase.call(storeId, statusFilter:{accepted, making, ready})  ← 결정 H 반영
  → OrderRepository.watchStoreOrders → DataSource.streamPaidByStore(storeId, statusFilter)
  → orders where storeId==X && status in [accepted, making, ready] orderBy createdAt desc
  → 카드 1장씩 렌더 → status 별 액션 버튼 분기 (accepted="조리 시작" / making="준비 완료" / ready="픽업 완료")
```

### F. 고객 환불 요청 차단 흐름 (결정 F / Q7)

```
[Customer OrderDetailPage]
  status == 'accepted' 일 때만 환불 요청 버튼 노출
    → 점주가 조리 시작하기 전이면 → 기존 Phase 3a 환불 요청 흐름 그대로
    → 점주가 조리 시작 (status='making') 후 stream emit → 버튼 영역이 inline 안내 카드 ("조리가 시작되어 환불 요청이 어려워요...") 로 자동 전환
  status == 'making' / 'ready' / 'completed' 진입 시
    → 환불 요청 버튼 미노출
    → inline 안내 카드만 노출
    → 사용자가 어떤 우회 경로로 refundRequest update 시도해도 Rules O2 (`status == 'accepted'`) 가 차단 → permission-denied
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| `setMakingByOwner` 실패 (네트워크 / Rules 차단) | catch → SnackBar (`"오류가 발생했습니다: $e"`). 버튼 disable 해제. stream 은 이전 status 유지 |
| 다른 상태에서 전이 시도 (예: paid 에서 setMaking 호출) | Rules O5 의 `resource.data.status == 'accepted'` 검증 실패 → permission-denied. UI 에서는 매트릭스로 사전 차단됨 — 정상 흐름에선 발생 안함. 발생 시 SnackBar 로 fallback |
| 환불 요청 활성 상태에서 조리 액션 (UI 가드 우회 등) | UI 가 차단하므로 발생 안함. 발생해도 Rules 가 차단하지는 않음 (Rules 는 status 만 검증). 추가 보호 필요시 추후 보강 (확인 필요 — Q3) |
| 다른 매장 점주가 다른 매장 주문에 액션 시도 | Rules `isStoreOwner(resource.data.storeId)` 차단 → SnackBar |
| 중복 탭 (액션 중) | `_isActionLoading` 또는 `_processingOrderIds` 가드 |
| stream 으로 status 가 액션보다 먼저/늦게 도착 race | UI 는 stream 을 단일 진실원으로 사용. 액션 결과는 SnackBar 만, UI 는 stream 으로 갱신 |
| 픽업 완료 확정 다이얼로그 취소 | no-op |
| timestamp 필드 미존재 doc | `toDate(data['makingStartedAt'])` 가 null → 안전 (기존 doc 호환) |

---

## 권한 / 보안

### Firestore Rules

신규 3개 분기 (O5/O6/O7) — `orders.update` 의 OR 체인에 추가. 각 분기는:
- `isStoreOwner(resource.data.storeId)` — actor 검증
- 이전 status 검증 (`resource.data.status == 'accepted'/'making'/'ready'`)
- 다음 status 검증 (`request.resource.data.status == 'making'/'ready'/'completed'`)
- 화이트리스트 (`status`, `<status>At`, `updatedAt`) — 정확히 3개

drift 방지:
- Repository 의 update payload key = 3개 (`status`, `makingStartedAt`/`readyAt`/`completedAt`, `updatedAt`)
- Rules 화이트리스트 = 정확히 동일 3개
- developer 가 둘 다 동일하게 유지하는지 implementation.md 에서 명시적으로 cross-check.

### 클라이언트 UX 가드

- 환불 요청 활성 상태에서 조리 액션 미노출 (결정 C). Rules 단에서는 추가 차단하지 않음 (단순화).
- `OwnerOrderDetailPage` 의 페이지 진입 시 점주 매장 매칭 가드 (기존 G 결정 그대로).

---

## 작업 분배

### designer

- UI 변경 필요 여부: **예**.
- 디자인 산출물 (`docs/tasks/order_flow_phase3c/1_cooking_status_owner/design.md`):
  - `OwnerOrdersPage` 3탭 헤더 레이아웃
  - `OwnerInProgressOrderTile` 카드 디자인 (making vs ready 시각 차별화 / 액션 버튼 / **환불 요청 배지**는 결정 F 적용 후에도 carry-over 케이스 (accepted 에서 요청한 환불을 owner 가 making 진입 후에도 처리해야 함) 가 가능 — 유지 검토)
  - `OwnerOrderDetailPage` sticky bottom 의 단일 액션 배치 (paid 의 2:1 패턴과 시각 일관)
  - 픽업 완료 확정 다이얼로그 디자인 (`showCompletePickup`)
  - 상태별 UI 매트릭스 (결정 E, 결정 F 반영 후 매트릭스) 와이어
  - **(결정 F / Q7 신규)** 고객 `OrderDetailPage` 의 making/ready/completed 환불 차단 inline 안내 카드 카피 / 톤 / 보조 안내 (매장 연락 안내) — U7
- 전달할 사항:
  - `AppColors` 만 사용 (절대 규칙)
  - 기존 `OrderStatusBadge` 색상 그대로 (변경 없음)
  - 기존 `OwnerOrderActionDialogs.showApproveRefund` 패턴 따라 `showCompletePickup` 디자인 (Confirm 다이얼로그 톤)
  - `_StatusSection`, `_RefundRequestSection`, `_NoActionInfoCard` 의 making/ready 분기는 owner_order_detail_page 기존 패턴 그대로 — 신규 디자인 최소화
  - **결정 F / Q7 반영 — design.md 갱신 시 다음 항목 제거 또는 단순화**:
    - making + 환불 요청 active 액션 차단 / inline warning 카드 / sticky bottom 환불 매트릭스 4개 case (making+active, ready+active 의 sticky bottom 환불 액션 + inline 안내) — 발생 불가
    - making/ready 의 "환불 요청 처리 후 다음 단계로 진행할 수 있어요" 안내 — 발생 불가
  - 고객 OrderDetailPage 의 making / ready inline 안내 카드 디자인 신규 추가

### developer

- 구현 항목:
  - `OrderEntity` / `OrderModel` 필드 3개 추가 + freezed regenerate (F33~F35)
  - `OrderRepository` 인터페이스 + `OrderRepositoryImpl` 메서드 3개 (F7~F10)
  - UseCase 3개 신규 파일 (F11~F13)
  - `order_di_providers.dart` 의 UseCase provider 3개 + `inProgressOrdersByStoreProvider` 추가 (F14, F15)
  - `OwnerOrderActionDialogs.showCompletePickup` 정적 메서드 추가 (F18)
  - `OwnerOrderDetailPage` 액션 분기 매트릭스 확장 + 핸들러 3개 추가 (F16, F17, F19~F21)
  - `OwnerOrdersPage` TabController length 3 + `_InProgressOrdersTab` + 핸들러 3개 + 위젯 import (F22~F25)
  - 신규 `owner_in_progress_order_tile.dart` (F24)
  - `firestore.rules` 의 `orders.update` 분기 3개 추가 (F26~F30) + **O2 분기 허용 status 축소 (F36)**
  - `firestore.indexes.json` 검토 — `storeId + status + createdAt` 인덱스가 `whereIn` 쿼리에 작동하는지 확인 (필요 시 보강)
  - **(결정 F / Q7)** 고객 `OrderDetailPage` 의 making/ready 환불 분기 제거 + inline 안내 카드 노출 (F38~F41) — designer 의 카피 결정 후 반영
  - 문서 갱신 — `data_ownership.md §2.4.1`, `entity_lifecycle.md §2`, `entity_lifecycle.md §2.3` (F31, F32) + `firestore_security_rules/spec.md §O2` (F37, 또는 별도 task)
- 재사용할 기존 구조:
  - `OrderRemoteDataSource.update()` (변경 없음)
  - `WatchStoreOrdersUseCase` (statusFilter 인자만 활용)
  - `OrderStatusBadge`, `OrderItemRow`, `PriceSummary`
  - `OwnerOrderActionDialogs` (3개 기존 + 1개 추가)
  - `_PrimaryButton`, `_ErrorOutlinedButton` (OwnerOrderDetailPage 내부 위젯)
- 주의할 레이어 규칙:
  - **drift 방지**: Repository update payload 키와 Rules `onlyChangedFields` 화이트리스트가 정확히 동일해야 함. implementation.md 에 cross-check 표 작성.
  - Firebase / 외부 SDK 는 data 레이어에서만 사용
  - `AppColors` 강제. `Color(0x...)` 금지
  - freezed regenerate: `dart run build_runner build --delete-conflicting-outputs`
- 구현 후 산출물 (`docs/tasks/order_flow_phase3c/1_cooking_status_owner/implementation.md`):
  - 생성/수정 파일 목록
  - drift cross-check 표 (Repository payload 키 vs Rules 화이트리스트)
  - 사용된 provider / useCase 목록
  - 결정 사항 (A~E, Q1~Q3) 과의 일치 여부

### tester

- 주요 검증 기준 — §"테스트 시나리오" T1~T16.
- 반드시 확인할 예외 케이스:
  - paid 상태에서 setMakingByOwner 호출 (Rules 차단 → permission-denied)
  - 다른 매장 점주가 다른 매장 주문에 액션 (Rules 차단)
  - accepted 단계에서 환불 요청 활성 시 조리 액션 노출 안 됨 (UX 가드)
  - 환불 거절 후 → 조리 액션 재노출
  - **(결정 F / Q7)** making / ready / completed 의 고객 OrderDetailPage 환불 요청 버튼 미노출 + inline 안내 카드 노출 — T14
  - **(결정 F / Q7)** Rules O2 — making / ready / completed 상태의 refundRequest update 시도 차단 (emulator) — T15. 기존 accepted ALLOW 회귀 검증
  - **(결정 F / Q7)** 점주 making 진입 직후 고객 UI 환불 버튼 → inline 안내 카드 자동 전환 (stream 기반) — T16
  - 기존 phase3a/3b/owner_order_detail 회귀 (paid 흐름 / **accepted 단계 환불 흐름** 변경 없음)
- 산출물 (`docs/tasks/order_flow_phase3c/1_cooking_status_owner/test_report.md`): PASS/FAIL 표 + 재현 절차 + 발견 이슈.

---

## 테스트 시나리오 (T1~T16)

| # | 시나리오 | 사전 조건 | 검증 |
|---|---|---|---|
| T1 | accepted → making 전이 (상세 페이지) | accepted 주문, refundRequest 없음 | "조리 시작" 탭 → status='making', makingStartedAt set, badge='제조 중', 액션 영역 = "준비 완료" |
| T2 | making → ready 전이 (상세 페이지) | T1 후 | "준비 완료" 탭 → status='ready', readyAt set, badge='픽업 대기', 액션 = "픽업 완료" |
| T3 | ready → completed 전이 (확정 다이얼로그) | T2 후 | "픽업 완료" 탭 → 확정 다이얼로그 → 승인 → status='completed', completedAt set, badge='완료', 액션 영역 사라짐, inline 안내 "픽업이 완료된 주문이에요." |
| T4 | 확정 다이얼로그 취소 | T2 후 | "픽업 완료" 탭 → 다이얼로그 → 취소 → status 변화 없음 |
| T5 | OwnerOrdersPage "조리 중" 탭 노출 | 매장에 making 주문 1, ready 주문 1 | 탭에 2건 카드 표시, 각 카드에 status 별 액션 버튼 |
| T6 | 조리 중 탭 카드 액션 (making → ready) | 사전 조건 | 카드 "준비 완료" → status='ready' → 카드 액션이 "픽업 완료" 로 갱신 |
| T7 | 조리 중 탭 카드 액션 (ready → completed) | 사전 조건 | 카드 "픽업 완료" → 다이얼로그 → 승인 → 카드가 탭에서 사라짐 (조리 중 탭 stream 조건 미충족) |
| T8 | 환불 요청 활성 상태의 액션 우선순위 (accepted, **결정 F 적용 후 유일하게 가능한 케이스**) | accepted 주문 + 환불 요청 활성 (기존 Phase 3a 흐름) | 상세 페이지 sticky bottom = "환불 승인" + "환불 거절", "조리 시작" 미노출. 기존 Phase 3a / owner_order_detail 흐름 회귀 |
| T9 | 환불 요청 거절 후 조리 액션 재노출 (accepted) | T8 후, 환불 거절 액션 | refundRequest.deniedAt set → 액션 영역이 "조리 시작" 으로 전환 |
| T10 | Rules 차단 — 잘못된 status 전이 (paid 에서 making 시도) | paid 주문 | Repository 호출 시 Firestore permission-denied → SnackBar 오류. status 유지 |
| T11 | Rules 차단 — 다른 매장 점주 액션 | 매장 A 의 accepted 주문에 매장 B 의 점주 액션 | Rules `isStoreOwner` 차단 → permission-denied |
| T12 | 액션 중복 탭 방지 | making 주문 | "준비 완료" 빠른 연타 → 1회만 호출, 버튼 disabled |
| T13 | 기존 흐름 회귀 — paid → accepted | paid 주문 | 기존 동작 변경 없음 ("주문 받기" → accepted → 액션 사라지거나 환불 분기) |
| **T14** (결정 F / Q7) | 고객 환불 요청 버튼 차단 — making | making 상태 주문 (점주가 조리 시작) | 고객 OrderDetailPage 진입 시 환불 요청 버튼 미노출. inline 안내 카드 노출 ("조리가 시작되어 환불 요청이 어려워요..." 류). 동일하게 ready / completed 도 차단 검증 |
| **T15** (결정 F / Q7) | Rules O2 차단 — making 상태에서 refundRequest update 시도 | making 상태 주문, 고객 SDK 가 임의로 refundRequest 필드 직접 update 시도 (emulator) | `permission-denied`. ready / completed 도 동일 검증. 기존 `accepted` 상태는 ALLOW 유지 (회귀) |
| **T16** (결정 F / Q7) | 점주 making 진입 후 고객 환불 요청 시도 불가 (UI + Rules 일관성) | accepted 주문에서 고객이 환불 요청 버튼 진입 → 동일 시각 점주가 making 으로 전이 → stream 갱신 | 고객 UI 가 making 진입 즉시 환불 버튼 → inline 안내 카드로 전환. 이미 열려 있는 RefundRequestSheet 에서 제출 시도 → Rules O2 차단 → SnackBar 오류 |

---

## 완료 기준

- [ ] 모든 요구사항 (F1~F41 / U1~U7) 구현 또는 보류 사유 명시
- [ ] `design.md` 작성 완료 (UI 확장 명세 + 결정 F 반영: 충돌 처리 디자인 제거 + 고객 환불 차단 inline 안내 카드 신규)
- [ ] `implementation.md` 작성 완료 + drift cross-check 표 포함 + O2 축소 변경 표기
- [ ] `test_report.md` 작성 완료 + T1~T16 모두 PASS 또는 FAIL 후속 task 분리
- [ ] `data_ownership.md §2.4.1` 표 update (O5/O6/O7 + O2 축소)
- [ ] `entity_lifecycle.md §2` 다이어그램 + 표 update (3개 전이 row), `§2.3` refundRequest lifecycle 의 "(없음) → Requested" 조건 축소, `2.5 보류/미구현` 의 making/ready/completed 항목 제거
- [ ] `role_flows.md §4.2 owner` 액션 표 update — "조리 시작 / 준비 완료 / 픽업 완료" 행 추가. customer 환불 요청 가능 status 도 함께 축소 반영
- [ ] customer / 기타 점주 흐름 regression 없음 (특히 accepted 단계 환불 흐름 회귀)
- [ ] `flutter analyze` warning 0
- [ ] designer / developer / tester 모두 본 spec 의 결정 항목 (A~F, H, Q1~Q3, Q5, Q7, Q8) 에 따라 작업했음을 산출물에서 명시 (Q4 / Q6 은 무효화)

---

## 사용자 확인 필요 항목 (요약)

설계자 잠정안은 위 본문에 기록. 다음 항목은 designer 호출 전 사용자 확인 필요.

| Q# | 항목 | architect 잠정안 | 다른 선택지 | 상태 |
|---|---|---|---|---|
| **Q1** | OwnerOrdersPage 탭 구조 (결정 A) | (B) "조리 중" 탭 신규 추가 — 총 3탭 | (A) 변경 없음 / (C) 별도 페이지 / (D) 단일 페이지 세로 섹션 | 사용자 확인 필요 |
| **Q2** | 액션 라벨 마이크로카피 (결정 B) | "조리 시작" / "준비 완료" / "픽업 완료" | "조리하기" / "조리 완료" / "수령 확인" 등 | 사용자 확인 필요 |
| **Q3** | 픽업 완료 확정 다이얼로그 (결정 B 옵션) | 픽업 완료에만 다이얼로그 | 모든 전이에 다이얼로그 / 다이얼로그 없음 | 사용자 확인 필요 |
| ~~**Q4**~~ | ~~환불 요청 활성 + 조리 액션 충돌 (결정 C)~~ | ~~(B) 조리 액션 차단 + 환불 처리 우선~~ | ~~(A) 둘 다 노출 / (C) status 자동 freeze~~ | **무효화 (2026-06-07, 결정 F / Q7 적용)** — making/ready + refundRequest active 케이스 자체 발생 불가. accepted + active 케이스는 Phase 3a 흐름 그대로 유지 |
| **Q5** | timestamp 필드명 (결정 D) | `makingStartedAt`, `readyAt`, `completedAt` | `startedMakingAt`, `pickedUpAt` 등 | 사용자 확인 필요 |
| ~~**Q6**~~ | ~~status 매트릭스 (결정 E) — making/ready 의 환불 활성 inline 안내 카피~~ | ~~"환불 요청 처리 후 다음 단계로 진행할 수 있어요"~~ | ~~다른 카피 / inline 안내 미노출~~ | **무효화 (2026-06-07, 결정 F / Q7 적용)** — 해당 inline 안내 노출 케이스 자체 발생 불가 |
| **Q7** | **환불 요청 허용 status 축소 (결정 F)** | (B) `accepted` 만 허용 — 조리 시작 후 환불 요청 시스템 단 차단 | (A) 현행 유지 (accepted/making/ready/completed 전 구간) / (C) 매장별 설정 | **확정 (2026-06-07, 사용자 결정)** |
| **Q8** | **"조리 중" 탭 범위 확장 (결정 H)** | (A) statusFilter = `{accepted, making, ready}` + 탭 이름 "조리 중" 유지 | (B) 탭 이름 변경 / (C) "신규" 탭이 accepted 포함 / (D) 4번째 탭 신설 | **확정 (2026-06-21, 사용자 결정)** — 라이브 검증 보완 2 |

위 Q1, Q2, Q3, Q5 확정 후 designer 호출. Q4 / Q6 은 무효화되어 designer 작업 범위에서 제외. Q7 은 확정되어 본 spec 의 결정 F 로 반영. Q8 은 검증 단계에서 발견된 보완으로 확정되어 본 spec 의 결정 H 로 반영 (코드 fix 완료).

### 정책 변경 (Q7) 이 design.md / implementation.md 에 미치는 영향

- **design.md (designer 갱신 필요)**:
  - 충돌 처리 디자인 (액션 차단 / inline warning 카드 / sticky bottom 환불 매트릭스 case 4개: making+active, making+active inline 안내, ready+active, ready+active inline 안내) **제거**
  - 상태별 UI 매트릭스 단순화 (위 결정 E 매트릭스 반영)
  - 고객 OrderDetailPage 의 making/ready 환불 차단 inline 안내 카드 디자인 **신규 추가** (카피 / 톤 / 매장 연락 안내)
- **implementation.md (developer 작업 분배)**:
  - 위 §"작업 분배 > developer" 의 F36, F38~F41 신규 항목 포함

---

## 다른 task / 코드 영향 추적 (결정 F / Q7)

본 정책 변경이 다른 spec / 문서 / 코드에 미치는 영향. 본 sub-phase 작업 시점에 함께 갱신할지, 별도 task 로 분리할지 명시.

| 대상 | 현재 정의 | 변경 필요 | 처리 방식 |
|---|---|---|---|
| `firestore.rules` (실제 코드) | O2 (`isCustomerRefundRequest`) 가 `status in ['accepted','making','ready','completed']` 허용 | `status == 'accepted'` 만 허용 | 본 sub-phase 개발자가 함께 수정 (F36) |
| `docs/tasks/firestore_security_rules/spec.md` §O2 | 위 동일 정의 + 조건 / 테스트 (T-O-O2-1 등) | O2 의 status 허용 조건 축소 + 신규 차단 케이스 (T-O-O2-3: making 에서 refundRequest 시도 → DENY) 추가 | **별도 갱신 task 후보** (architect 가 본 sub-phase 완료 직후 인계). 또는 본 sub-phase 의 F37 로 포함 |
| `docs/tasks/order_flow_phase3a/spec.md` | "환불 흐름 — Phase 3a 포함" 결정 4 에서 환불 가능 status 가 `accepted` 이상 (구체적으로 `accepted/making/ready/completed`) 으로 암시됨 | "Phase 3a 시점 정책: accepted 이상. **Phase 3c-1 정책 변경 (2026-06-07): accepted 만**" 노트 추가 | **이력 보존 형태** — Phase 3a 본문은 유지 + 변경 이력 노트 추가. 본 sub-phase 작업 시 함께 갱신 또는 별도 task |
| `docs/tasks/order_flow_phase3b/spec.md` | `onOrderRefundRequested` CF trigger: `before.refundRequest == null && after.refundRequest != null` → 알림. 어떤 status 에서 trigger 되는지 명시 없음 | accepted 단계 외 trigger 불가능해짐 — 단, before/after diff 로직 자체는 변경 불필요. 노트만 추가 ("결정 F 적용 후 trigger 는 status='accepted' 시점에만 발생") | 노트 추가 (코드 변경 없음). 본 sub-phase 작업 시 함께 갱신 또는 별도 task |
| `docs/processes/entity_lifecycle.md` §2.3 refundRequest lifecycle | "(없음) → Requested" 조건: `order.status ∈ {accepted, making, ready, completed}` | `order.status == 'accepted'` 만 허용 + §2.4.3 표 update + 다이어그램 update | 본 sub-phase 의 F32 에 포함 (developer 또는 architect 가 함께 갱신) |
| `docs/processes/data_ownership.md` §2.4.1 O2 행 | 위 동일 정의 | 동일 축소 | 본 sub-phase 의 F31 에 포함 |
| `docs/order_flow_summary.md` | 큰 그림 — refundRequest 가능 status 가 언급되어 있는지 점검 필요 | 필요 시 noted | 점검 후 결정 |
| `lib/data/repositories/order_repository_impl.dart` `requestRefund(orderId, reason)` | 클라이언트 측 status 가드는 없음 (Rules 가 차단) | 그대로 유지 (Rules O2 차단). 클라이언트 측 추가 가드 권장 — `assert(order.status == accepted)` 또는 호출 전 status 체크 | developer 가 검토 (필수 아님 — UI 가드로 충분) |

### 본 sub-phase 작업 후 architect 가 인계할 후속 작업

1. **`firestore_security_rules/spec.md` 갱신** (F37 — O2 정의 + 테스트 케이스 보강)
2. **`order_flow_phase3a/spec.md` 변경 이력 노트 추가** (정책 변경 시점 + 사유)
3. **`order_flow_phase3b/spec.md` 노트 추가** (trigger 조건 자연 축소)
4. **`order_flow_summary.md` 점검** (큰 그림 다이어그램에 환불 가능 status 표시가 있는지)

---

## 참고 자료

- Phase 3a spec / implementation: `docs/tasks/order_flow_phase3a/`
- Phase 3b spec / implementation: `docs/tasks/order_flow_phase3b/`
- owner_order_detail_page spec: `docs/tasks/owner_order_detail_page/spec.md`
- order_flow_summary: `docs/order_flow_summary.md`
- 단일 진실원: `docs/processes/role_flows.md` §4.2, `docs/processes/entity_lifecycle.md` §2, `docs/processes/data_ownership.md` §2.4
- enum: `lib/domain/entities/order_status.dart` (이미 making/ready/completed 정의됨)
- OrderEntity: `lib/domain/entities/order_entity.dart`
- OrderRepository: `lib/domain/repositories/order_repository.dart`
- OrderRepositoryImpl: `lib/data/repositories/order_repository_impl.dart`
- OrderRemoteDataSource: `lib/data/datasources/remote/order_remote_data_source.dart`
- 점주 페이지: `lib/presentation/owner/orders/owner_orders_page.dart`, `owner_order_detail_page.dart`
- 액션 다이얼로그: `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart`
- OrderStatusBadge: `lib/presentation/common/order_status_badge.dart`
- Firestore Rules: `firestore.rules`
- Firestore Indexes: `firestore.indexes.json`
- 고객 페이지 (결정 F / Q7 영향): `lib/presentation/customer/order/orders/order_detail_page.dart`, `lib/presentation/customer/order/widgets/refund_request_sheet.dart`
