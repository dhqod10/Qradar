# Phase 3c — sub-phase 2: 고객 알림 + 고객 UI 강화

> 단일 진실원 / 참고:
> - 큰 그림: [docs/order_flow_summary.md](../../../order_flow_summary.md)
> - 역할 흐름: [docs/processes/role_flows.md](../../../processes/role_flows.md) §4.1
> - 엔티티 lifecycle: [docs/processes/entity_lifecycle.md](../../../processes/entity_lifecycle.md) §2
> - 데이터 소유권: [docs/processes/data_ownership.md](../../../processes/data_ownership.md) §2.4
> - 직전 sub-phase: [docs/tasks/order_flow_phase3c/1_cooking_status_owner/spec.md](../1_cooking_status_owner/spec.md)
> - FCM 인프라 단일 진실원: [docs/tasks/order_flow_phase3b/spec.md](../../order_flow_phase3b/spec.md)

---

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 초안 | architect | 본 spec 최초 작성 (결정 A~E + Q1~Q5) |

---

## 개요

- **목적**: sub-phase 1 에서 점주 측 조리 status 전이 (`accepted → making → ready → completed`) 가 완성됐으나, 변경된 status 가 **Firestore stream 으로만 고객에게 전달**되어 고객이 앱을 켜놓고 있을 때만 인지 가능했다. 본 sub-phase 는 ① 점주 측 status 전이를 **고객 FCM 푸시 알림**으로 발화시키고 ② 고객 측 `OrderDetailPage` 에 sub-phase 1 점주 측에 추가된 **조리 타임라인 + 진행 인디케이터**를 동등하게 노출하여 고객이 앱 외부에서도 진행 상황을 인지·확인할 수 있게 한다.
- **부수 목적**: ③ 고객 측 알림 권한 흐름 도입 (점주 측 `OwnerScaffold` 의 `_checkAndRequestNotificationPermission` 패턴을 customer 의 `ScaffoldWithNav` 에 동등 이식). ④ sub-phase 1 라이브 검증에서 발견된 `notificationPermissionPrompted` 영속 정책 명시화 (재요청 조건 + emulator wipe 후 재발화 정책).
- **작업 유형**: 기존 인프라 확장 (FCM 토큰 등록 + Cloud Function trigger + 클라이언트 메시지 핸들러 + deep link 라우터 모두 sub-phase 1 / Phase 3b 에서 점주용으로 구축 완료. 본 sub-phase 는 동일 인프라에 **customer 분기 + status 전이 트리거**만 추가).
- **트리거 actor**: 알림 **발화 actor 는 owner** (점주의 status 갱신). 알림 **수신 actor 는 customer** (해당 주문의 `userId`).
- **수신 대상**: `orders/{orderId}.userId` 의 `users/{userId}.fcmToken` 보유자.
- **클라이언트 SDK 직접 update 없음**: 본 sub-phase 의 Firestore 변경 경로는 sub-phase 1 의 O5/O6/O7 (점주 측) 가 유일. 본 sub-phase 는 **그 변경을 trigger 로 받는 Cloud Function 신규 1개 + 클라이언트 수신 분기 확장**만 추가.

### Phase 3c 전체 로드맵 (본 sub-phase 위치)

| sub-phase | 범위 | 본 spec 범위 |
|---|---|---|
| 3c-1 (완료) | Order 조리 단계 전이 + 점주 UI + Rules O5/O6/O7 + 환불 차단 (Q7) | ❌ (완료) |
| **3c-2 (본 spec)** | 고객 측 FCM 알림 (status 전이 트리거) + 고객 OrderDetailPage 타임라인/인디케이터 + 고객 알림 권한 흐름 | ✅ |
| 3c-3 (예정) | 알림 설정 UI (점주·고객의 알림 toggle / 카테고리별 on-off) | ❌ |

### 영향 범위

| 레이어 | 영향 |
|---|---|
| **Domain** | `RemoteNotificationMessage.NotificationType` enum 에 신규 case 4개 추가 (`order_accepted` / `order_making` / `order_ready` / `order_completed`). 결정 B 의 채택에 따라 마지막 1개는 제외 가능. |
| **Data** | `RemoteNotificationMessage.fromData` 의 typeStr 매핑 확장. `FcmRemoteDataSource` / `PushNotificationRepository` / `RegisterFcmTokenUseCase` 변경 **없음** (기존 인프라 재사용). |
| **Presentation (customer)** | `OrderDetailPage` 에 **`_TimelineSection` (또는 `_ProgressIndicator`) 신규** 추가 — sub-phase 1 owner_order_detail_page 의 `_TimelineSection` 과 시각 톤 통일. `ScaffoldWithNav` 에 `_checkAndRequestNotificationPermission` 추가 (owner_scaffold 패턴 그대로). `NotificationNavigator` 에 customer 분기 추가 — customer 측 `OrderDetailPage` push (현재는 owner 측만 push). |
| **Presentation (owner)** | **변경 없음** (sub-phase 1 그대로). |
| **Provider DI** | 변경 없음 (기존 `notification_providers.dart` / `order_view_providers.dart.currentOrderProvider` 재사용). |
| **Firestore Rules** | **변경 없음**. 본 sub-phase 는 Rules 분기 추가 없음. |
| **Cloud Functions** | 신규 1개 — `onOrderStatusChanged` (`onDocumentUpdated('orders/{orderId}')`). status 전이를 감지해 고객 FCM 발송. 환불 알림용 `onOrderRefundRequested` 와 분리 (단일 책임 + 중복 trigger 방지). |
| **공통 컴포넌트** | (신규) 진행 인디케이터 위젯 (`_OrderProgressIndicator` 또는 동등) — designer 가 결정 C 에 따라 horizontal stepper / vertical timeline 중 1개. |
| **라우팅** | `NotificationNavigator` 에 role 분기 추가. 현재 `NotificationType.newOrder` / `refundRequest` 둘 다 owner `OwnerOrderDetailPage` 로 push. 신규 4개 type 은 customer `OrderDetailPage` 로 push. |
| **권한 / 환경 설정** | iOS APNs 미발급 — 별도 task `ios_apns_setup` 에서 처리. 본 sub-phase 는 Android 만 실 검증 가능 (sub-phase 1 정책 그대로). |
| **테스트** | sub-phase 1 회귀 + 본 sub-phase T1~T13 (§테스트 시나리오) + 알림 권한 흐름 + deep link 검증. |

### 비범위

본 sub-phase 가 **명시적으로 다루지 않는** 항목.

- **iOS APNs 발급 / 설정** — 별도 task `docs/tasks/ios_apns_setup/`. 본 sub-phase 의 라이브 검증은 Android 만.
- **점주 측 추가 알림** — 환불 요청 알림은 Phase 3b 의 `onOrderRefundRequested` 가 이미 처리. 점주 측 환불 승인/거절 후속 알림은 sub-phase 3c-3 또는 별 phase.
- **알림 설정 UI** (사용자가 알림 토글 / 카테고리별 on-off) — Phase 3c-3 예정.
- **앱 내 알림함** (수신 히스토리) — 별 phase. 본 sub-phase 는 FCM 자체 retry 만 신뢰.
- **`minInstances=1` 운영 설정** — sub-phase 1 보완 1 에서 보류된 운영 환경 결정. 별 task (`cloud_functions_min_instances` 또는 동등).
- **다국어 알림 본문** — 본 sub-phase 는 한국어 fixed (Phase 3b 와 동일).
- **고객 Log 탭 (`OrdersPage` / `customer/log/orders_page.dart`) 의 status 배지 색상 재정의** — `OrderStatusBadge` 가 이미 `paid/accepted/making/ready/completed/cancelled/refunded` 7개 status 별 색상 + 라벨 정의 완료 (`order_status_badge.dart:58-98`). **재점검만 수행 (designer)**, 색상 재정의는 본 sub-phase 비범위. 단 시각 일관성 확인 의무 있음 (§"고객 측 UI 가시화 점검" 참조).
- **푸시 알림 권한이 거절된 사용자의 fallback** (SMS / 이메일 / 앱 내 알림함 등) — 별 phase.
- **알림 클릭 deep link 통계 / 분석** — 별 phase.
- **terminated 상태에서의 fast-launch 최적화** — Phase 3b 의 `getInitialMessage` + `PendingNotificationHolder` 패턴 그대로 사용. 본 sub-phase 는 status 전이 type 4개의 라우팅 분기만 추가.

---

## 사전 확인 결과 (architect 점검)

sub-phase 1 / Phase 3b 의 실제 코드 상태를 직접 검증한 결과.

| 항목 | 상태 | 비고 |
|---|---|---|
| Cloud Function `onOrderUpdated` (단일 통합 함수) 존재 여부 | ❌ 없음 | 본 spec 의 배경 설명에서 "기존 `functions/src/onOrderUpdated.ts` (또는 동등 파일) 확장" 으로 표현됐으나, 실제는 `onOrderCreated` (신규 주문) + `onOrderRefundRequested` (환불 요청) 2개로 분리됨. 본 sub-phase 는 **신규 함수 `onOrderStatusChanged` 추가** 가 자연스러움 (결정 정리 §"Cloud Function 분리 vs 통합" 참조). |
| sub-phase 1 의 timestamp 필드 4개 (`acceptedAt` / `makingStartedAt` / `readyAt` / `completedAt`) | ✅ 모두 `OrderEntity` / `OrderModel` 에 정의 완료 | sub-phase 1 F33~F35 완료. 본 sub-phase 의 timeline 섹션이 그대로 활용 가능. |
| `OrderEntity.acceptedAt` 가 Firestore stream 으로 고객에게 도달하는지 | ✅ 도달 — `currentOrderProvider` 가 stream 구독 (lib/presentation/customer/order/orders/providers/order_view_providers.dart) | 본 sub-phase 의 timeline 섹션은 별도 fetch 불필요. |
| 고객 `OrderDetailPage` 의 현재 상태 | sub-phase 1 의 결정 F (Q7) 가 반영됨 — `making` / `ready` 케이스에 환불 차단 inline 안내 카드 노출 (`_ActionSection` switch 의 case 557~606) | 본 sub-phase 의 UI 강화는 **타임라인 / 진행 인디케이터 신규 추가** 가 핵심. inline 안내 카드는 그대로 유지. |
| sub-phase 1 점주 측 `_TimelineSection` 위치 | ✅ `lib/presentation/owner/orders/owner_order_detail_page.dart:613` | 본 sub-phase 의 디자인 톤 참조 기준점. |
| `OrderStatusBadge` (status 7개 색상 + 라벨) | ✅ 완성됨 (`lib/presentation/common/order_status_badge.dart`) | 본 sub-phase 변경 없음. Log 탭 (`OrdersPage`) 에서 `OrderCard` 가 이미 사용 중 — making/ready/completed 색상 차별화 완료. |
| FCM 인프라 (`FcmRemoteDataSource` / `RegisterFcmTokenUseCase` / `HandleNotificationMessageUseCase` / `NotificationNavigator`) | ✅ 완성됨 (Phase 3b) | 본 sub-phase 는 메시지 type 4종 추가 + Navigator role 분기만. |
| 클라이언트 `NotificationNavigator` 의 분기 | 현재 `newOrder` / `refundRequest` 만 owner 측 `OwnerOrderDetailPage` 로 push. customer 분기 없음 (Phase 3b 의 `// 향후 고객 알림이 추가되면 role 별 분기 로직 추가 필요 (Phase 3c 예정)` 주석 — 본 sub-phase 가 이 주석을 해소). | 본 sub-phase 의 핵심 변경 1개. |
| customer 측 `ScaffoldWithNav` 의 알림 권한 흐름 | ❌ 없음 — `OwnerScaffold._checkAndRequestNotificationPermission` 만 존재. | 본 sub-phase 추가. |
| 고객 측 FCM 토큰 등록 경로 | `OwnerScaffold` 진입 시점에만 호출됨 (`registerFcmTokenUseCaseProvider.call(uid)`). 고객은 등록 경로 없음. | 본 sub-phase 추가. |
| `users/{uid}.fcmToken` 의 `customer` 역할 doc 에도 set 되는지 | ❌ 현재 안 됨 (위 항목과 동일 원인). | 본 sub-phase 가 등록 경로 추가 후 정상화. |
| `users/{uid}.notificationPermissionPrompted` 의 sticky 영속화 정책 | sub-phase 1 보완 4 에서 발견 — emulator Wipe 후 Firestore 의 doc 이 잔존하면 다이얼로그 미노출. 코드 변경 없이 "환경 이슈" 로 분류됨. 본 sub-phase 는 정책 명시 + 운영 가이드 spec 화. | 결정 E 에서 처리. |
| iOS APNs 인증서 | ❌ 미발급 (별 task `ios_apns_setup`). | 본 sub-phase 의 라이브 검증은 Android 만. iOS 는 `ios_apns_setup` 완료 후 별도 회귀. |

---

## architect 잠정 결정 (사용자 확인 필요)

⚠ 아래 결정 A~E 는 architect 잠정안. **사용자 승인 후 designer / developer 호출**.

### 결정 A. status 전이별 알림 발화 매트릭스 — `accepted` / `making` / `ready` 3건 (architect 추천)

배경 설명에서 4건 (`paid → accepted` / `accepted → making` / `making → ready` / `ready → completed`) 모두 후보. 본 결정에서 각 건별 발화 여부 + 메시지 카피 확정.

| 전이 | 알림 발화 후보 | architect 추천 | 사유 |
|---|---|---|---|
| `paid → accepted` (점주 주문 받기) | ✅ 발화 | ✅ 발화 | 점주가 주문 수락 = 매장의 첫 반응. 고객이 결제 후 가장 궁금해하는 시점. Phase 3b 의 점주 알림 (`onOrderCreated`) 과 대칭. **상태 = 사용자 결정 필요 (Q1)** |
| `accepted → making` (점주 조리 시작) | ✅ 발화 | ✅ 발화 | 조리 시작 = 음료 폐기 비용 발생점 (sub-phase 1 결정 F 기준). 환불 차단이 시작되는 결정적 시점이므로 고객에게 명확히 안내해야 함. |
| `making → ready` (점주 준비 완료) | ✅ 발화 | ✅ 발화 | 픽업 가능 = 본 phase 의 가장 중요한 행동 유도 시점. 고객이 매장으로 이동/도착해야 함. **놓치면 안 됨**. |
| `ready → completed` (점주 픽업 완료) | ⚠ 검토 (결정 B 와 결합) | ❌ **미발화** (architect 추천) | 픽업은 고객이 능동적으로 수행. 알림 = 사후 확인일 뿐 행동 유도 가치 낮음. 노이즈 가능성. UX 단순화. |

#### 알림 매트릭스 (architect 추천 채택 시 — Q1 + Q2 확정)

| 트리거 시점 | 알림 type (FCM data) | 알림 제목 | 알림 본문 (예시) | deep link |
|---|---|---|---|---|
| `paid → accepted` | `order_accepted` | "주문이 접수되었어요" | "{storeName} 에서 주문을 받았어요." | customer `OrderDetailPage` (orderId) |
| `accepted → making` | `order_making` | "음료를 만들고 있어요" | "{storeName} 에서 조리를 시작했어요." | customer `OrderDetailPage` (orderId) |
| `making → ready` | `order_ready` | "픽업 준비가 완료됐어요" | "{storeName} 에서 음료가 준비됐어요. 매장에 방문해 주세요." | customer `OrderDetailPage` (orderId) |
| ~~`ready → completed`~~ | (미발화) | — | — | — |

> 본 알림 카피는 **결정 D (알림 본문 카피 톤)** 의 산출물로 확정. 위는 architect 잠정안.

### 결정 B. 픽업 완료 (`ready → completed`) 알림 발화 — **미발화** (architect 추천)

결정 A 의 마지막 행 결정.

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 발화 — "픽업 완료" 안내 + 다음 주문 권유 | 결제 흐름 종결 명시. 리뷰 유도 가능 (별 phase) | 픽업 = 고객이 능동적으로 한 행동. 알림 = 사후 확인일 뿐. 노이즈 |
| **(B) 미발화** (architect 추천) | UX 단순화. 의미 있는 알림만 노출 → 알림 피로도 ↓ | 결제 흐름 종결 안내 부재. 단, 앱 내 상세에서 확인 가능 |
| (C) 옵트인 (사용자 설정에서 toggle) | 사용자 자율 | 본 sub-phase 알림 설정 UI 비범위 — 부적합 |

채택 = **(B)**. 향후 Phase 3c-3 알림 설정 UI 도입 후 (C) 로 확장 가능.

### 결정 C. 고객 진행 인디케이터 디자인 — **horizontal stepper 4단계** (architect 추천)

sub-phase 1 점주 측 `_TimelineSection` (vertical, owner_order_detail_page.dart:613) 과의 일관성 vs 고객 측 UX 적합성.

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) Vertical timeline (sub-phase 1 점주 톤 그대로) | 시각 일관성 ↑. 코드 / 컴포넌트 재사용 가능 | 고객 화면은 owner_order_detail_page 처럼 정보 밀도가 높지 않음 → 세로 공간 차지가 비효율. 한눈에 진행 단계 파악 어려움 |
| **(B) Horizontal stepper 4단계 (접수 / 조리 / 준비 / 픽업)** (architect 추천) | 한눈에 진행 단계 파악 — 고객 UX 의 핵심 가치. 모바일 가로 폭 활용. 진행 중 단계 강조 효과 ↑ | 점주 측과 시각 분리 — 단, 점주 측은 운영 도구 / 고객 측은 안내 도구로 역할 분리는 자연스러움 |
| (C) Hybrid — horizontal stepper + 각 단계 펼치면 timestamp 노출 | 정보 밀도 + 가독성 동시 | 구현 복잡 (펼침 상호작용 디자인 추가). 본 sub-phase MVP 과잉 |
| (D) Text-only 진행 (예: "조리 중 · 5분 전 시작") | 가장 단순 | 시각적 진행감 부재. 고객이 현재 위치 인지 어려움 |

채택 = **(B)**. 단, 각 단계 아래 작은 timestamp 표시 (HH:mm 형식) 로 정보 보완.

**4단계 정의**:
1. **접수** (`acceptedAt`) — paid → accepted 완료
2. **조리** (`makingStartedAt`) — accepted → making 완료
3. **준비** (`readyAt`) — making → ready 완료
4. **픽업** (`completedAt`) — ready → completed 완료

**현재 단계 강조 규칙** (architect 잠정안 — designer 확정):
- 완료된 단계: filled circle + checkmark 또는 색상 채움
- 현재 단계: outline circle + 강조 색상 + 펄스 또는 굵은 라벨
- 미도달 단계: muted 색상 + 빈 circle

**노출 조건**:
- 본 인디케이터는 `status` 가 `paid` 이상 `completed` 이하 일 때만 노출 (즉, `cancelled` / `refunded` 는 미노출 — 이미 inline 안내 카드 또는 cancelInfo 섹션 노출).
- `paid` 단계는 인디케이터 자체는 노출되지만 4단계 모두 미달성 상태 (1단계만 시작 직전).

### 결정 D. 알림 본문 카피 톤 — **친근 + 정중 중간 (Qrator 브랜드 보이스)** (architect 추천)

| 옵션 | 톤 | 예시 (`paid → accepted`) | 예시 (`making → ready`) |
|---|---|---|---|
| (A) 친근 (반말 / 캐주얼) | 카페 동네 친구 톤 | "주문 받았어! 곧 만들기 시작할게" | "음료 다 됐어! 픽업하러 와" |
| **(B) 친근 + 정중 중간 (반높임체)** (architect 추천) | 친근하지만 존중. Qrator 브랜드 (프리미엄 + 심플) 정합 | "{storeName} 에서 주문을 받았어요." | "{storeName} 에서 음료가 준비됐어요. 매장에 방문해 주세요." |
| (C) 정중 (격식) | 백화점 안내 톤 | "{storeName} 에서 귀하의 주문을 접수했습니다." | "{storeName} 에서 음료 준비가 완료되었습니다." |

채택 = **(B)**. CLAUDE.md 의 Qradar 브랜드 정의 (프리미엄 + 심플 + Qrator 가 품질 선별자) + Phase 3a 의 기존 SnackBar 카피 (`'주문이 취소되었습니다'`, `'환불 요청이 접수되었습니다'`) 와 톤 정합.

**확정 카피 (결정 A 매트릭스에 반영)**:

| 전이 | 제목 | 본문 |
|---|---|---|
| `paid → accepted` | "주문이 접수되었어요" | "{storeName} 에서 주문을 받았어요." |
| `accepted → making` | "음료를 만들고 있어요" | "{storeName} 에서 조리를 시작했어요." |
| `making → ready` | "픽업 준비가 완료됐어요" | "{storeName} 에서 음료가 준비됐어요. 매장에 방문해 주세요." |

> `storeName` 은 `orders/{orderId}.storeName` (denormalized — Phase 3a verifyTossPayment 가 set). 별도 fetch 불필요.

### 결정 E. 알림 권한 흐름 — sub-phase 1 보완 4 의 sticky 정책 명세화 (architect 추천)

sub-phase 1 검증 중 발견된 이슈를 spec 단계에서 명세.

#### 발견된 이슈 (sub-phase 1 test_report.md 보완 4)

> 발생: Wipe 후에도 Firestore 점주 doc 에 `notificationPermissionPrompted: true` 잔존 → 권한 요청 다이얼로그 미노출.
> 해결: 명령줄로 `notificationPermissionPrompted` + `fcmToken` 필드 삭제 → 재로그인 → 다이얼로그 노출 → 허용 → 새 토큰 저장.
> 코드 변경: 없음. 디바이스 변경 시 동작 방식 후속 확인 후보.

#### 본 sub-phase 의 권한 흐름 정의 (확정안 — architect 잠정)

**A. 권한 prompt 노출 조건** (Customer / Owner 공통):
1. 로그인 후 `ScaffoldWithNav` (customer) 또는 `OwnerScaffold` (owner) 첫 진입
2. `users/{uid}.notificationPermissionPrompted == false` (필드 없으면 false 로 fallback)
3. OS 권한 status 가 `notDetermined` 또는 `denied` (이미 `authorized` 면 dialog 불필요 — 단순 토큰 등록만 호출)

**B. 권한 prompt 응답 후 처리**:
- "허용" → OS 권한 요청 → 결과 무관하게 `notificationPermissionPrompted = true` set
- "나중에" → 권한 요청 없이 `notificationPermissionPrompted = true` set
- 결과: **재로그인 / 재진입 시 다이얼로그 재노출 안 됨**

**C. 권한 거절 후 재요청 정책** (architect 잠정안):
- 본 sub-phase 에서는 **자동 재노출 없음** — 사용자가 "더보기 > 알림 설정" (Phase 3c-3) 에서 명시적으로 재요청 시에만 다시 노출.
- Phase 3c-3 의 알림 설정 UI 가 도입되기 전까지는 **앱 단에서 거절 후 재노출 경로 없음**. 이는 의도된 설계 (한 번 거절 시 반복 알림 노출은 거부감).
- ⚠ **단, 다음 케이스는 예외**: 사용자가 OS 설정에서 직접 권한을 허용한 경우 — Phase 3c-2 에서 별도 처리 없음 (FCM SDK 가 자동 감지하나, fcmToken 등록은 다음 로그인까지 보류). 본 sub-phase 비범위.

**D. emulator wipe 후 권한 prompt 재발화 정책**:
- Firestore 의 `notificationPermissionPrompted: true` 가 **device-local 이 아니라 server-side 영속** 이므로 wipe 후에도 잔존.
- **이는 설계 의도** — 사용자가 device 변경 / 재설치 후에도 알림 권한 응답 이력을 보존. 반복 노출 방지.
- **운영 가이드** (sub-phase 1 보완 4 와 동일): 개발 / 테스트 환경에서 prompt 를 다시 보고 싶다면 Firestore 의 `users/{uid}.notificationPermissionPrompted` 필드를 수동 삭제 (또는 `users/{uid}.fcmToken` 도 함께 삭제 권장). 본 운영 가이드를 `docs/operations.md` 또는 본 spec 의 §"운영 가이드" 에 명시.

**E. 본 sub-phase 의 코드 변경**:
- `ScaffoldWithNav` (customer) 에 `_checkAndRequestNotificationPermission` 추가 — `OwnerScaffold` 와 동일 패턴 (lib/presentation/owner/owner_scaffold.dart:36-81).
- 기존 점주 측 흐름 / sticky 정책 / Firestore 필드 명세는 변경 없음.

채택 = **(상기 A~E 안)**. designer / developer 가 본 정책 그대로 구현.

---

## 요구사항

### 기능 요구사항

#### 신규 status 전이 알림 (Cloud Function)

- [ ] **F1**. 신규 Cloud Function `onOrderStatusChanged` 추가 — `onDocumentUpdated('orders/{orderId}', region: 'asia-northeast3')`.
- [ ] **F2**. `before.status != after.status` diff 검사. 매칭되는 전이가 아니면 early return.
- [ ] **F3**. 발화 전이: `paid → accepted` / `accepted → making` / `making → ready` 3개 (결정 A 채택 시). `ready → completed` 는 미발화 (결정 B).
- [ ] **F4**. `orders/{orderId}.userId` 의 `users/{userId}.fcmToken` 조회. 없으면 skip + 구조화 로그 (Phase 3b 패턴 그대로).
- [ ] **F5**. FCM data-only payload 발송 — Phase 3b 의 `onOrderCreated` / `onOrderRefundRequested` 와 동일 구조 (title / body 를 `data` 에 동봉 → 클라이언트 측 `flutter_local_notifications` 로 렌더).
- [ ] **F6**. invalid token error → `users/{userId}.fcmToken` 정리 (Phase 3b 동일 패턴).
- [ ] **F7**. 발송 실패는 swallow + 에러 로그 (Phase 3b 동일 정책).
- [ ] **F8**. **중복 알림 방지**: 동일 `before.status == after.status` 인 경우 (필드만 갱신, status 무변경) skip. 매칭 status diff 외에는 trigger 됐어도 메시지 발송 없음.

#### Cloud Function payload 구조 (Phase 3b 와 통일)

```jsonc
{
  "token": "<fcmToken>",
  "data": {
    "type": "order_accepted",         // or "order_making" / "order_ready"
    "orderId": "ord_xxxxxxxx",
    "storeId": "store_xxxxxxxx",
    "title": "주문이 접수되었어요",
    "body": "{storeName} 에서 주문을 받았어요."
  }
}
```

- [ ] **F9**. `data.type` 4가지 신규 타입 (`order_accepted` / `order_making` / `order_ready` / 미발화 결정 시 `order_completed` 제외).
- [ ] **F10**. `data.orderId` / `data.storeId` 는 deep link 라우팅용. Phase 3b 와 동일 key 이름.
- [ ] **F11**. title / body 는 결정 D 카피 그대로. `storeName` 은 `after.storeName` 에서 substitution.

#### 클라이언트 — 알림 수신 분기

- [ ] **F12**. `RemoteNotificationMessage` 의 `NotificationType` enum 에 `orderAccepted` / `orderMaking` / `orderReady` 3개 case 추가 (결정 A / B 채택 시).
- [ ] **F13**. `RemoteNotificationMessage.fromData` 의 typeStr 매핑 확장 — `'order_accepted'` / `'order_making'` / `'order_ready'`.
- [ ] **F14**. `NotificationNavigator.navigate` 의 switch 에 신규 3개 case 추가 — customer 측 `OrderDetailPage(orderId: orderId)` 로 push.
- [ ] **F15**. `NotificationType.unknown` 분기는 그대로 (변경 없음).

#### 고객 측 OrderDetailPage — 진행 인디케이터

- [ ] **F16**. 신규 `_OrderProgressIndicator` 위젯 추가 (결정 C — horizontal stepper). 4단계 (접수 / 조리 / 준비 / 픽업).
- [ ] **F17**. 각 단계 도달 여부는 timestamp 존재로 판정 (`acceptedAt` / `makingStartedAt` / `readyAt` / `completedAt` != null).
- [ ] **F18**. 현재 단계는 `order.status` 로 결정 — `accepted` → 단계 1 강조, `making` → 단계 2, `ready` → 단계 3, `completed` → 단계 4 모두 완료.
- [ ] **F19**. 각 단계 아래 도달 시각 (`HH:mm` 형식, `intl` `DateFormat`) 표시 — designer 가 결정한 톤.
- [ ] **F20**. 노출 조건: `status ∈ {paid, accepted, making, ready, completed}`. `cancelled` / `refunded` 시 미노출.
- [ ] **F21**. 인디케이터 위치: `_StatusSection` 직후, 기존 `_CancelInfoSection` / `_RefundRequestStatusSection` / `_RefundDeniedSection` 보다 위.

#### 고객 측 OrderDetailPage — 기존 inline 안내 유지

- [ ] **F22**. sub-phase 1 의 결정 F (Q7) 로 추가된 `case OrderStatus.making:` / `case OrderStatus.ready:` 환불 차단 inline 안내 카드 (`_ActionSection`) **변경 없음**.
- [ ] **F23**. `case OrderStatus.completed:` / `cancelled:` / `refunded:` 의 안내 카드 **변경 없음**.
- [ ] **F24**. `case OrderStatus.accepted:` 의 환불 요청 버튼 / 안내 분기 **변경 없음**.

#### 고객 측 알림 권한 흐름

- [ ] **F25**. `ScaffoldWithNav` (customer 측 메인 Scaffold, `lib/presentation/common/scaffold_with_nav.dart`) 에 `_checkAndRequestNotificationPermission` 메서드 추가 — `OwnerScaffold._checkAndRequestNotificationPermission` 패턴 그대로 (lib/presentation/owner/owner_scaffold.dart:45-81).
- [ ] **F26**. `initState` 의 `WidgetsBinding.instance.addPostFrameCallback` 에서 위 메서드 호출.
- [ ] **F27**. 권한 허용 시 `RegisterFcmTokenUseCase` 호출 → `users/{uid}.fcmToken` set (기존 인프라 재사용).
- [ ] **F28**. 결과 무관하게 `markNotificationPermissionPrompted(uid)` 호출 — 재노출 방지 (결정 E.B).
- [ ] **F29**. 사용자가 "나중에" 선택 시 OS 권한 요청 skip + fcmToken 등록 skip + prompted flag 만 set.

#### Provider / DI / Repository

- [ ] **F30**. 본 sub-phase 는 신규 Provider / UseCase / Repository 추가 **없음**. 기존 `notification_providers.dart` 의 `registerFcmTokenUseCaseProvider` / `requestNotificationPermissionUseCaseProvider` / `userRepositoryProvider` 재사용.
- [ ] **F31**. `currentOrderProvider` (lib/presentation/customer/order/orders/providers/order_view_providers.dart) 재사용 — `OrderDetailPage` 가 이미 사용 중.

### UI 요구사항 (designer 위임)

- [ ] **U1**. `_OrderProgressIndicator` 위젯 디자인 — 결정 C 채택 (horizontal stepper 4단계 + 각 단계 timestamp HH:mm).
  - 완료된 단계 / 현재 단계 / 미도달 단계의 시각 차별화
  - circle / line / 색상 토큰 (`AppColors.primary` / `AppColors.success` / `AppColors.textMuted` 활용 — designer 가 토큰 매핑 확정)
  - 모바일 가로 폭에 4단계가 자연스럽게 들어가도록 (각 단계 라벨 `'접수'` / `'조리'` / `'준비'` / `'픽업'` — 2글자 균형)
- [ ] **U2**. `_OrderProgressIndicator` 의 노출 조건 매트릭스 디자인 — `paid` 단계 (4단계 모두 미달성) 의 시각 처리 (모두 muted 상태로 노출 vs 인디케이터 자체 미노출 vs 1단계만 회색 + "곧 접수 예정" 안내). architect 잠정안 = **인디케이터 노출 + 모두 muted + 1단계가 다음 단계로 강조**.
- [ ] **U3**. `OrderDetailPage` 내 인디케이터 위치 / 여백 (`_StatusSection` 직후, `SizedBox(16)` 간격).
- [ ] **U4**. 알림 본문 카피 (결정 D) 디자이너 검수 — Qradar 브랜드 톤 정합 최종 확인 + 길이 검증 (Android / iOS 알림 본문 자르기 안전 길이).
- [ ] **U5**. `AppColors` 만 사용 (CLAUDE.md 절대 규칙).
- [ ] **U6**. sub-phase 1 점주 측 `_TimelineSection` (vertical) 과의 시각 분리 정합성 검토 — 둘이 같은 정보 (timestamps) 를 다르게 표현하는 것의 일관성 / 브랜드 정합.

### 상태 요구사항

| 상태 | UI |
|---|---|
| 인디케이터 로딩 (`currentOrderProvider` loading) | 기존 `_OrderDetailShimmer` 그대로 — 본 sub-phase 변경 없음. 단 shimmer 에 인디케이터 placeholder 1개 추가 권장 (designer 검토). |
| 인디케이터 정상 — paid | 4단계 모두 muted, 1단계가 다음 강조 |
| 인디케이터 정상 — accepted | 1단계 완료 + 2단계 강조 |
| 인디케이터 정상 — making | 1, 2단계 완료 + 3단계 강조 |
| 인디케이터 정상 — ready | 1, 2, 3단계 완료 + 4단계 강조 |
| 인디케이터 정상 — completed | 4단계 모두 완료 |
| 인디케이터 미노출 — cancelled / refunded | 노출 안 함 (기존 inline 안내 카드만 노출) |
| 알림 도착 (foreground) | sub-phase 1 / Phase 3b 의 `flutter_local_notifications` 처리 그대로 — UI 위에 로컬 알림 표시 |
| 알림 도착 (background / terminated) | OS 알림 표시 → 탭 시 `NotificationNavigator` 가 customer `OrderDetailPage` push |
| 권한 거절 후 | inline 안내 없음 (별 phase). 본 sub-phase 비범위 |

---

## 데이터 모델

### Entity / Model 변경

**없음**. sub-phase 1 에서 추가된 `acceptedAt` / `makingStartedAt` / `readyAt` / `completedAt` 필드 그대로 활용.

단 도메인 enum 1개 확장:

```dart
enum NotificationType {
  newOrder,       // 기존 (Phase 3b)
  refundRequest,  // 기존 (Phase 3b)
  orderAccepted,  // 신규 (본 sub-phase)
  orderMaking,    // 신규 (본 sub-phase)
  orderReady,     // 신규 (본 sub-phase)
  unknown,        // 기존
}
```

`RemoteNotificationMessage.fromData` 의 typeStr 매핑:

```dart
final type = switch (typeStr) {
  'new_order' => NotificationType.newOrder,
  'refund_request' => NotificationType.refundRequest,
  'order_accepted' => NotificationType.orderAccepted,
  'order_making' => NotificationType.orderMaking,
  'order_ready' => NotificationType.orderReady,
  _ => NotificationType.unknown,
};
```

### Firestore 변경

**없음**. `users/{uid}.fcmToken` / `users/{uid}.notificationPermissionPrompted` 모두 기존 사용 그대로.

---

## 레이어 설계

### Domain

#### Entity
- `RemoteNotificationMessage.NotificationType` enum 확장 (위 §데이터 모델 참조).

#### Repository / UseCase
- 변경 없음. 기존 `PushNotificationRepository` / `RegisterFcmTokenUseCase` / `RequestNotificationPermissionUseCase` / `HandleNotificationMessageUseCase` 재사용.

### Data

#### DataSource
- 변경 없음. `FcmRemoteDataSource` 의 `onMessage()` / `onMessageOpenedApp()` / `getInitialMessage()` 가 이미 모든 type 의 data payload 를 도메인으로 변환 중 (`RemoteNotificationMessage.fromData`).

#### Repository
- 변경 없음.

#### Cloud Functions (`functions/src/onOrderStatusChanged.ts` 신규)

새 파일 `functions/src/onOrderStatusChanged.ts` 추가. 기존 `functions/src/onOrderRefundRequested.ts` 의 구조 그대로 따름 (단일 책임 + 분기 단순화).

```ts
import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const NOTIFICATION_MATRIX: Record<string, { type: string; title: string; body: (storeName: string) => string }> = {
  "paid->accepted": { type: "order_accepted", title: "주문이 접수되었어요", body: (n) => `${n} 에서 주문을 받았어요.` },
  "accepted->making": { type: "order_making", title: "음료를 만들고 있어요", body: (n) => `${n} 에서 조리를 시작했어요.` },
  "making->ready": { type: "order_ready", title: "픽업 준비가 완료됐어요", body: (n) => `${n} 에서 음료가 준비됐어요. 매장에 방문해 주세요.` },
  // "ready->completed" — 결정 B 미발화
};

export const onOrderStatusChanged = onDocumentUpdated(
  { document: "orders/{orderId}", region: "asia-northeast3" },
  async (event) => {
    const orderId = event.params.orderId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;
    if (!beforeStatus || !afterStatus || beforeStatus === afterStatus) return;

    const matrixKey = `${beforeStatus}->${afterStatus}`;
    const matrix = NOTIFICATION_MATRIX[matrixKey];
    if (!matrix) return;

    const userId: string | undefined = after.userId;
    const storeName: string = after.storeName ?? "매장";
    const storeId: string | undefined = after.storeId;
    if (!userId) return;

    const db = admin.firestore();
    const userSnap = await db.collection("users").doc(userId).get();
    const fcmToken = userSnap.data()?.fcmToken as string | undefined;
    if (!fcmToken) {
      console.info("[onOrderStatusChanged] No fcmToken.", { userId, orderId, matrixKey });
      return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      data: {
        type: matrix.type,
        orderId,
        storeId: storeId ?? "",
        title: matrix.title,
        body: matrix.body(storeName),
      },
    };

    try {
      await admin.messaging().send(message);
      console.info("[onOrderStatusChanged] FCM sent.", { orderId, userId, matrixKey });
    } catch (err: unknown) {
      const errorCode = (err as { code?: string })?.code;
      if (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
          fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        console.error("[onOrderStatusChanged] FCM send failed (swallowed):", err);
      }
    }
  }
);
```

`functions/src/index.ts` 에 export 추가:
```ts
export { onOrderStatusChanged } from "./onOrderStatusChanged";
```

#### Cloud Function 분리 vs 통합

| 옵션 | 채택 | 사유 |
|---|---|---|
| (A) 신규 `onOrderStatusChanged` 분리 (architect 추천) | ✅ | 단일 책임 (status 전이만). `onOrderRefundRequested` (환불 분기) 와 trigger key 가 다름. 분리 시 디버깅 / 로그 분리. 함수 cold start 부담은 v2 + 동일 region 으로 최소화. |
| (B) `onOrderRefundRequested` 를 `onOrderChanged` 로 통합 | ❌ | 단일 함수에 환불 분기 + status 4종 분기가 섞임. 분기 로직 복잡 + 회귀 위험. |
| (C) 클라이언트 측에서 stream 으로 직접 status 변화 감지 → 로컬 알림만 | ❌ | 앱 종료/백그라운드 시 동작 불가 — 본 sub-phase 핵심 목적 (앱 외부 알림) 미달. |

채택 = **(A)**.

### Presentation

#### Page (customer)

- `lib/presentation/customer/order/orders/order_detail_page.dart`
  - `_OrderProgressIndicator` 신규 위젯 추가 (F16~F20). `_OrderDetailBody.build` 의 `_StatusSection` 직후 SizedBox(16) 다음에 삽입 (F21).
  - 노출 조건 분기 (`status ∈ {paid, accepted, making, ready, completed}`).
  - 기존 `_ActionSection` switch 분기는 변경 없음 (F22~F24).
  - shimmer 영역 (`_OrderDetailShimmer`) 에 인디케이터 placeholder 1개 추가 권장 (U1).

- `lib/presentation/common/scaffold_with_nav.dart`
  - `_ScaffoldWithNavState.initState` 에 `WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRequestNotificationPermission())` 추가 (F26).
  - `_checkAndRequestNotificationPermission` 메서드 신규 — `OwnerScaffold` 의 동명 메서드와 동일 패턴 그대로 (F25~F29).

#### Routing

- `lib/presentation/common/notification/notification_navigator.dart`
  - `NotificationNavigator.navigate` 의 switch 분기에 신규 3개 case 추가 (F14):
    ```dart
    case NotificationType.orderAccepted:
    case NotificationType.orderMaking:
    case NotificationType.orderReady:
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => OrderDetailPage(orderId: orderId),
        ),
      );
    ```
  - `OrderDetailPage` 는 customer 측 (`lib/presentation/customer/order/orders/order_detail_page.dart`).
  - 기존 `newOrder` / `refundRequest` (owner) 분기는 그대로 유지.
  - 향후 role 별 분기 주석 ("Phase 3c 예정") 갱신 — "Phase 3c-2 에서 customer status 전이 알림 추가됨" 명시.

#### Domain entity 갱신

- `lib/domain/entities/remote_notification_message.dart`
  - `NotificationType` enum 에 3개 case 추가 (F12).
  - `fromData` factory 의 switch 확장 (F13).

---

## 데이터 흐름

### A. 점주 status 전이 → 고객 FCM 알림

```
[OwnerOrderDetailPage 또는 OwnerInProgressOrderTile]
  → 점주가 "주문 받기" / "조리 시작" / "준비 완료" 액션
  → AcceptOrderUseCase / StartMakingOrderUseCase / MarkOrderReadyUseCase
  → OrderRepository.setAcceptedByOwner / startMakingOrder / markOrderReady
  → Firestore orders/{orderId} update (sub-phase 1 의 Rules O1/O5/O6)
  → onDocumentUpdated trigger
  → onOrderStatusChanged (신규 CF)
    → before.status / after.status diff
    → NOTIFICATION_MATRIX lookup
    → orders/{orderId}.userId → users/{userId}.fcmToken
    → FCM data-only payload 발송
  → 고객 device 도착
  → foreground: onMessage stream → HandleNotificationMessageUseCase → flutter_local_notifications.show
  → background: 시스템 OS 가 자동 표시 (data-only + flutter_local_notifications 백그라운드 핸들러)
  → terminated: 시스템 OS 가 자동 표시
```

### B. 고객 알림 탭 → deep link

```
[고객이 OS 알림 탭]
  → foreground: onMessageOpenedApp stream → NotificationNavigator.navigate
  → background: 동일
  → terminated: getInitialMessage → PendingNotificationHolder → 첫 빌드 후 NotificationNavigator.navigate
  → NotificationNavigator.navigate
    → switch (message.type)
      → orderAccepted / orderMaking / orderReady → customer OrderDetailPage push
      → newOrder / refundRequest → owner OwnerOrderDetailPage push (sub-phase 1 / Phase 3b 그대로)
  → 고객 OrderDetailPage 진입 → currentOrderProvider 가 Firestore stream 구독 → 최신 status / 인디케이터 / inline 안내 카드 자동 갱신
```

### C. 고객 OrderDetailPage 진행 인디케이터 갱신

```
[고객 OrderDetailPage 열림]
  → currentOrderProvider(orderId) Firestore stream
  → status / acceptedAt / makingStartedAt / readyAt / completedAt 실시간 수신
  → _OrderProgressIndicator rebuild
    → status 가 accepted 면 단계 1 완료 + 단계 2 강조
    → status 가 making 이면 단계 1, 2 완료 + 단계 3 강조
    → status 가 ready 면 단계 1, 2, 3 완료 + 단계 4 강조
    → 각 단계 아래 timestamp (HH:mm) 표시
```

### D. 고객 로그인 → 알림 권한 prompt → FCM 토큰 등록

```
[로그인 성공]
  → RoleRouter → role 분기 → ScaffoldWithNav (customer)
  → initState → addPostFrameCallback → _checkAndRequestNotificationPermission
    → users/{uid}.notificationPermissionPrompted == true → early return
    → false → NotificationPermissionDialog 노출
      → "허용" → requestNotificationPermissionUseCase → OS 권한 응답
        → authorized → RegisterFcmTokenUseCase → users/{uid}.fcmToken set
      → "나중에" → 권한 요청 skip
    → 결과 무관하게 markNotificationPermissionPrompted(uid)
  → 차후 로그인 / 진입 시 다이얼로그 미노출 (sticky)
```

### E. emulator wipe / 재테스트 시나리오 (운영 가이드)

```
[테스트 환경에서 권한 prompt 를 다시 보고 싶을 때]
  → Firestore console / firebase CLI 로 users/{uid} doc 의 다음 필드 삭제:
    - notificationPermissionPrompted
    - fcmToken (선택 — 함께 삭제 시 토큰 재발급 검증 가능)
  → 앱 재로그인 → prompt 재노출 → 정상 흐름 검증
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| `onOrderStatusChanged` 의 fcmToken 미존재 | skip + `console.info` 로그. 점주 측 onOrderCreated 패턴 그대로. |
| `onOrderStatusChanged` 의 FCM invalid token | `users/{userId}.fcmToken` delete + `fcmTokenUpdatedAt = serverTimestamp`. Phase 3b 동일. |
| `onOrderStatusChanged` 의 기타 발송 실패 | swallow + error 로그. Phase 3b 동일. |
| status diff 가 매트릭스 미정의 (예: `cancelled` / `refunded` 전이) | early return. 본 sub-phase 비범위 — Phase 3c-3 에서 처리 가능. |
| 클라이언트 알림 탭 시 orderId 누락 | `NotificationNavigator.navigate` 가 이미 `if (orderId == null) return` 처리 — 별도 변경 없음. |
| customer 가 OrderDetailPage 에 진입했는데 orders/{orderId}.userId 가 본인 uid 가 아님 | 기존 `currentOrderProvider` 가 Firestore Rules `orders.read` 분기 (userId 검증) 로 차단 → `error` state. 기존 `_ErrorBody` 노출. |
| 권한 거절 후 알림 미수신 | 본 sub-phase 비범위 — 정책상 한 번 거절 시 본 sub-phase 에서 자동 재요청 안 함. 운영 가이드 (sticky 정책) 만 명시. |
| 인디케이터 노출 중 timestamp 필드 누락 (legacy doc) | 각 단계 도달 여부는 timestamp 존재 vs status 둘 다 검증. timestamp 없어도 status 만으로 도달 판정 가능 (fallback). |

---

## 권한 / 보안

### Firestore Rules

**변경 없음**. 본 sub-phase 는:
- 클라이언트 SDK 직접 update 경로 없음 — sub-phase 1 의 O5/O6/O7 가 유일한 status 전이 경로.
- Cloud Function `onOrderStatusChanged` 는 Admin SDK 사용 — Rules 우회.
- customer 알림 권한 prompt 의 Firestore 쓰기 (`notificationPermissionPrompted`, `fcmToken`) 는 기존 Phase 3b 의 `isSelfProfileUpdate` 화이트리스트로 이미 허용됨.

### FCM 보안

- payload 에 민감 정보 포함 금지. 본 sub-phase 의 data payload 에는 `orderId` / `storeId` / `storeName` / `title` / `body` 만 포함 — 결제 정보 / 카드번호 / userId 미포함.
- fcmToken 은 사용자 본인만 read/write 가능 (기존 `users.read/update` 권한 그대로).

### 알림 발송 actor 정합

- `onOrderStatusChanged` 가 `users/{after.userId}.fcmToken` 으로 발송 → **주문 본인에게만** 알림. 다른 사용자에게 누설 없음.
- `users/{userId}` 조회 시 doc 미존재 / fcmToken 미존재 / 권한 거절 모두 silent skip — 정보 누설 없음.

---

## 작업 분배

### designer

- UI 변경 필요 여부: **예**.
- 디자인 산출물 (`docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/design.md`):
  - `_OrderProgressIndicator` 위젯 디자인 (결정 C — horizontal stepper 4단계) — circle / line / 색상 / 라벨 / timestamp 톤 (U1)
  - 4단계 시각 차별화 매트릭스 (완료 / 현재 / 미도달) (U1)
  - `OrderDetailPage` 내 인디케이터 위치 + 여백 + shimmer placeholder (U2, U3)
  - 알림 본문 카피 검수 (결정 D — Qrator 브랜드 톤 정합) (U4)
  - sub-phase 1 점주 측 `_TimelineSection` (vertical) 과의 시각 분리 정합성 검토 — 같은 정보 다른 표현이 자연스러운지 (U6)
  - 인디케이터 노출 조건 매트릭스 (paid / accepted / making / ready / completed 단계별 시각) (U2)
- 전달할 사항:
  - `AppColors` 만 사용 (CLAUDE.md 절대 규칙)
  - 기존 `OrderStatusBadge` 색상과의 일관성 (paid='결제 완료'/primaryBright, accepted='접수 완료'/info, making='제조 중'/warning, ready='픽업 대기'/success, completed='완료'/textMuted)
  - 모바일 가로 폭 (375~430pt) 에 4단계가 자연스럽게 배치되도록
  - 각 단계 라벨은 `'접수'` / `'조리'` / `'준비'` / `'픽업'` 2글자 통일 — designer 가 변경 가능 (Qradar 톤 정합 검토 후)

### developer

- 구현 항목:
  - **Cloud Function 신규** (F1~F11):
    - `functions/src/onOrderStatusChanged.ts` 신규 작성
    - `functions/src/index.ts` 에 export 추가
    - NOTIFICATION_MATRIX 의 type / title / body 카피는 결정 D 확정 후 반영
  - **Domain enum 확장** (F12~F13):
    - `lib/domain/entities/remote_notification_message.dart` 의 `NotificationType` enum + `fromData` 매핑
  - **NotificationNavigator 분기 확장** (F14, F15):
    - `lib/presentation/common/notification/notification_navigator.dart` 의 switch 에 customer 측 OrderDetailPage push 분기 추가
    - 주석 갱신 ("Phase 3c-2 에서 customer 분기 추가됨")
  - **customer OrderDetailPage 인디케이터** (F16~F21):
    - `lib/presentation/customer/order/orders/order_detail_page.dart` 의 `_OrderDetailBody` 에 `_OrderProgressIndicator` 위젯 삽입
    - 위젯 자체 신규 작성 (designer 의 시각 명세 반영)
    - 노출 조건 분기
    - shimmer 영역 placeholder (선택)
  - **ScaffoldWithNav 권한 흐름** (F25~F29):
    - `lib/presentation/common/scaffold_with_nav.dart` 의 `_ScaffoldWithNavState.initState` 에 권한 체크 hook 추가
    - `_checkAndRequestNotificationPermission` 메서드 신규 — `OwnerScaffold` 패턴 그대로 복제
    - `userRepositoryProvider` / `requestNotificationPermissionUseCaseProvider` / `registerFcmTokenUseCaseProvider` 재사용
- 재사용할 기존 구조:
  - `FcmRemoteDataSource` / `PushNotificationRepositoryImpl` / `HandleNotificationMessageUseCase` (변경 없음)
  - `RegisterFcmTokenUseCase` / `RequestNotificationPermissionUseCase` / `MarkNotificationPermissionPromptedUseCase` 등 (변경 없음)
  - `NotificationPermissionDialog` / `PendingNotificationHolder` (변경 없음)
  - `currentOrderProvider` (변경 없음)
  - `OrderStatusBadge` (변경 없음)
- 주의할 레이어 규칙:
  - **Firebase / firebase_messaging SDK 직접 import 금지** (presentation / domain). `FcmRemoteDataSource` 만 사용.
  - `AppColors` 강제. `Color(0x...)` 금지.
  - Cloud Function 의 환경 변수 / API key 하드코딩 금지 — 본 sub-phase 는 신규 환경 변수 없음.
  - `RemoteNotificationMessage.fromData` 의 typeStr 매핑은 Cloud Function 의 `data.type` 문자열과 정확히 일치해야 함 (drift 방지) — implementation.md 에 cross-check 표 작성.
- 구현 후 산출물 (`docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/implementation.md`):
  - 생성/수정 파일 목록
  - Cloud Function 의 `data.type` 문자열 ↔ 클라이언트 `RemoteNotificationMessage.fromData` 매핑 cross-check 표
  - Cloud Function NOTIFICATION_MATRIX 의 status 키 ↔ 클라이언트 분기 cross-check
  - 결정 A~E 와의 일치 여부

### tester

- 주요 검증 기준 — §"테스트 시나리오" T1~T13.
- 반드시 확인할 예외 케이스:
  - fcmToken 미존재 사용자의 status 전이 → skip (로그 확인)
  - status diff 가 매트릭스 미정의 (예: paid → cancelled / accepted → refunded 등) → 알림 미발화 (회귀)
  - `notificationPermissionPrompted` sticky 정책 — 한 번 응답 후 재로그인 시 다이얼로그 미노출
  - emulator wipe 후 Firestore doc 정리 → prompt 재발화 (운영 가이드 검증)
  - iOS 는 별도 task `ios_apns_setup` 완료 후 회귀 — 본 sub-phase 라이브 검증은 Android 만
  - sub-phase 1 점주 측 흐름 회귀 (조리 status 전이 자체에 영향 없음)
- 산출물 (`docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/test_report.md`): PASS/FAIL 표 + 재현 절차 + 발견 이슈.

---

## 테스트 시나리오 (T1~T13)

| # | 시나리오 | 사전 조건 | 검증 |
|---|---|---|---|
| T1 | paid → accepted 알림 발화 (Android) | customer 권한 허용 + fcmToken 등록 완료 + paid 상태 주문 | 점주가 "주문 받기" → 고객 device 에 알림 도착 ("주문이 접수되었어요" / "{storeName} 에서 주문을 받았어요.") |
| T2 | accepted → making 알림 발화 (Android) | T1 후 | 점주가 "조리 시작" → 고객 device 에 알림 ("음료를 만들고 있어요" / "{storeName} 에서 조리를 시작했어요.") |
| T3 | making → ready 알림 발화 (Android) | T2 후 | 점주가 "준비 완료" → 고객 device 에 알림 ("픽업 준비가 완료됐어요" / "{storeName} 에서 음료가 준비됐어요. 매장에 방문해 주세요.") |
| T4 | ready → completed 알림 미발화 (결정 B 회귀) | T3 후 | 점주가 "픽업 완료" → 고객 device 알림 도착 안 함. 단, OrderDetailPage 의 진행 인디케이터는 4단계 완료로 갱신 |
| T5 | 진행 인디케이터 갱신 (status 전이별) | customer OrderDetailPage 열어둔 상태 | 점주가 status 전이 → stream 갱신 → 인디케이터 단계 / 강조 / timestamp 자동 갱신 (앱 열어둔 상태에서 알림과 별개로) |
| T6 | 진행 인디케이터 cancelled / refunded 미노출 | cancelled 또는 refunded 상태 주문 | 인디케이터 미노출 + 기존 inline 안내 카드 노출 |
| T7 | 알림 deep link — foreground | 알림 도착 + 앱 foreground | 알림 표시 → 탭 → onMessageOpenedApp → customer OrderDetailPage push (해당 orderId) |
| T8 | 알림 deep link — background | 앱 background | OS 알림 표시 → 탭 → 앱 복귀 + customer OrderDetailPage push |
| T9 | 알림 deep link — terminated | 앱 terminated | OS 알림 표시 → 탭 → 앱 cold start + 첫 빌드 후 customer OrderDetailPage push (PendingNotificationHolder 검증) |
| T10 | 고객 알림 권한 prompt — 첫 진입 | 신규 로그인 (notificationPermissionPrompted == false) | ScaffoldWithNav 진입 → NotificationPermissionDialog 노출 → "허용" → OS 권한 → fcmToken 등록 → notificationPermissionPrompted = true |
| T11 | 고객 알림 권한 prompt — 재진입 | T10 후 재로그인 또는 ScaffoldWithNav 재진입 | 다이얼로그 미노출 (sticky) |
| T12 | 고객 알림 권한 거절 후 알림 미수신 | T10 에서 "나중에" 선택 | fcmToken 미등록 → 점주 status 전이 시 onOrderStatusChanged 가 skip + 로그 ("No fcmToken") → 알림 미수신 |
| T13 | sub-phase 1 회귀 — 점주 측 조리 status 전이 자체에 영향 없음 | sub-phase 1 의 T1~T13 그대로 | 모두 PASS (status 전이 / OwnerInProgressOrderTile / sticky bottom 액션 등) |

---

## 완료 기준

- [ ] 모든 요구사항 (F1~F31 / U1~U6) 구현 또는 보류 사유 명시
- [ ] `design.md` 작성 완료 (U1~U6)
- [ ] `implementation.md` 작성 완료 + Cloud Function ↔ 클라이언트 매핑 cross-check 표
- [ ] `test_report.md` 작성 완료 + T1~T13 모두 PASS 또는 FAIL 후속 task 분리
- [ ] sub-phase 1 / Phase 3b 회귀 없음 (점주 흐름 / 환불 흐름 / FCM 발송 분기 모두 영향 없음)
- [ ] `entity_lifecycle.md §2.4 코드 진입점` 표에 customer 측 알림 진입점 (paid→accepted / accepted→making / making→ready) 행 추가 또는 §2.5 보류/미구현 의 알림 항목 갱신
- [ ] `role_flows.md §4.1 customer` 표에 "주문 진행 알림 수신" 행 추가
- [ ] `data_ownership.md` 변경 없음 (Rules 변경 없음 — 단 본 sub-phase 작업 사실은 §2.4 의 노트로 기록 가능)
- [ ] `flutter analyze` warning 0
- [ ] designer / developer / tester 모두 본 spec 의 결정 항목 (A~E) 에 따라 작업했음을 산출물에서 명시

---

## 사용자 확인 필요 항목 (요약)

설계자 잠정안은 본문에 기록. 다음 항목은 designer 호출 전 사용자 확인 필요.

| Q# | 항목 | architect 잠정안 | 다른 선택지 | 상태 |
|---|---|---|---|---|
| **Q1** | status 전이 알림 매트릭스 (결정 A) | `paid → accepted` + `accepted → making` + `making → ready` 3건 발화 | 4건 모두 발화 / 2건만 발화 (making/ready만) | 사용자 확인 필요 |
| **Q2** | 픽업 완료 (`ready → completed`) 알림 발화 (결정 B) | (B) 미발화 — UX 단순화 | (A) 발화 / (C) 옵트인 (Phase 3c-3 후로 보류) | 사용자 확인 필요 |
| **Q3** | 고객 진행 인디케이터 디자인 (결정 C) | (B) Horizontal stepper 4단계 + timestamp | (A) Vertical timeline / (C) Hybrid / (D) Text-only | 사용자 확인 필요 |
| **Q4** | 알림 본문 카피 톤 (결정 D) | (B) 친근 + 정중 중간 (반높임체) | (A) 친근 (반말) / (C) 정중 (격식) | 사용자 확인 필요 |
| **Q5** | 알림 권한 sticky 정책 (결정 E) | A~E 안 그대로 — 한 번 거절 시 본 sub-phase 비범위 (Phase 3c-3 에서 명시 재요청 UI). Firestore 측 영속화 + emulator wipe 운영 가이드 spec 명시 | sub-phase 별로 prompt 재요청 / device-local 만 영속화 / 거절 후 inline 안내 | 사용자 확인 필요 |

위 Q1~Q5 확정 후 designer 호출. 결정 D 의 카피는 designer 검수 후 최종 확정.

---

## 다른 task / 코드 영향 추적

본 sub-phase 의 변경이 다른 spec / 문서 / 코드에 미치는 영향. 본 sub-phase 작업 시점에 함께 갱신할지, 별도 task 로 분리할지 명시.

| 대상 | 현재 정의 | 변경 필요 | 처리 방식 |
|---|---|---|---|
| `functions/src/index.ts` | `onOrderCreated` / `onOrderRefundRequested` export | `onOrderStatusChanged` export 추가 | 본 sub-phase 개발자가 함께 수정 (F1) |
| `lib/presentation/common/notification/notification_navigator.dart` | 주석 `// 향후 고객 알림이 추가되면 role 별 분기 로직 추가 필요 (Phase 3c 예정)` | 분기 추가 + 주석 갱신 ("Phase 3c-2 에서 customer 분기 추가됨") | 본 sub-phase 개발자가 함께 수정 (F14) |
| `lib/presentation/common/scaffold_with_nav.dart` | 알림 권한 흐름 없음 | `_checkAndRequestNotificationPermission` 추가 | 본 sub-phase 개발자가 함께 수정 (F25) |
| `docs/processes/role_flows.md §4.1 customer` | 알림 수신 행 없음 | "주문 진행 알림 수신" 행 추가 | 본 sub-phase 개발자 또는 architect 가 함께 갱신 |
| `docs/processes/entity_lifecycle.md §2.4 코드 진입점` | 알림 트리거 관련 코드 진입점 없음 | "customer 측 진행 알림 (paid→accepted/accepted→making/making→ready)" 행 추가 또는 §2.5 보류/미구현 의 "알림" 항목 갱신 | 본 sub-phase 개발자 또는 architect 가 함께 갱신 |
| `docs/tasks/order_flow_phase3b/spec.md` | Phase 3b 가 점주 알림 인프라 — 비범위에 "고객 측 알림 (3c 예정)" 명시 | "Phase 3c-2 에서 고객 측 알림 (status 전이 트리거) 도입됨" 노트 추가 | 노트 추가 (코드 변경 없음). 본 sub-phase 작업 시 함께 갱신 또는 별도 task |
| `docs/tasks/order_flow_phase3c/1_cooking_status_owner/spec.md` | sub-phase 1 의 비범위에 "고객 측 알림 (3c-2)" 명시 | sub-phase 2 spec 경로를 직접 참조하도록 노트 추가 (선택) | 본 sub-phase 작업 후 architect 가 노트 추가 |
| `docs/operations.md` | 알림 권한 sticky 정책 운영 가이드 없음 | "테스트 환경에서 prompt 재발화 절차" 추가 (결정 E 의 emulator wipe 운영 가이드) | 본 sub-phase 작업 시 함께 갱신 또는 별도 task |
| `docs/tasks/ios_apns_setup/spec.md` | 별 task. Phase 3b 와 통합 | 본 sub-phase 의 4종 신규 type 도 검증 대상이라는 노트 추가 | architect 가 후속 인계 |

### 본 sub-phase 작업 후 architect 가 인계할 후속 작업

1. **`order_flow_phase3b/spec.md` 비범위 노트 갱신** — "Phase 3c-2 에서 customer 측 알림 도입됨" 추가
2. **`ios_apns_setup/spec.md` 회귀 대상 갱신** — 신규 4종 type 검증 대상 추가
3. **`operations.md` 운영 가이드 추가** — 알림 권한 prompt 재발화 절차 (Firestore doc 정리)
4. **Phase 3c-3 (알림 설정 UI)** — 본 sub-phase 의 sticky 정책이 막다른 길이 되지 않게 명시 재요청 경로 도입
5. **Cloud Function `minInstances` 운영 결정** — `onOrderStatusChanged` 도 cold start 영향 받음. sub-phase 1 보완 1 과 묶음 처리

---

## 참고 자료

- Phase 3b spec / implementation: `docs/tasks/order_flow_phase3b/`
- Phase 3c-1 spec / design / implementation / test_report: `docs/tasks/order_flow_phase3c/1_cooking_status_owner/`
- 단일 진실원: `docs/processes/role_flows.md` §4.1 (customer), `docs/processes/entity_lifecycle.md` §2 (Order)
- Cloud Functions: `functions/src/onOrderCreated.ts`, `functions/src/onOrderRefundRequested.ts` (참조 패턴), `functions/src/index.ts`
- FCM 인프라: `lib/data/datasources/remote/fcm_remote_data_source.dart`, `lib/data/repositories/push_notification_repository_impl.dart`, `lib/domain/entities/remote_notification_message.dart`
- 알림 라우팅: `lib/presentation/common/notification/notification_navigator.dart`, `lib/presentation/common/notification/pending_notification_holder.dart`
- 알림 권한 패턴 (참조): `lib/presentation/owner/owner_scaffold.dart` (lines 36~81)
- customer OrderDetailPage: `lib/presentation/customer/order/orders/order_detail_page.dart`
- customer ScaffoldWithNav: `lib/presentation/common/scaffold_with_nav.dart`
- sub-phase 1 점주 타임라인 (시각 참조): `lib/presentation/owner/orders/owner_order_detail_page.dart` `_TimelineSection` (line 613)
- OrderStatusBadge: `lib/presentation/common/order_status_badge.dart`
- 별 task: `docs/tasks/ios_apns_setup/spec.md`
