# Phase 3c — sub-phase 3: 알림 설정 UI (고객 · 점주)

> 단일 진실원 / 참고:
> - 큰 그림: [docs/order_flow_summary.md](../../../order_flow_summary.md)
> - 역할 흐름: [docs/processes/role_flows.md](../../../processes/role_flows.md) §4.1 / §4.2
> - 엔티티 lifecycle: [docs/processes/entity_lifecycle.md](../../../processes/entity_lifecycle.md) §2
> - 데이터 소유권: [docs/processes/data_ownership.md](../../../processes/data_ownership.md) §2.1 (`users/{userId}`)
> - 직전 sub-phase: [docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/spec.md](../2_customer_notification_and_ui/spec.md)
> - FCM 인프라 단일 진실원: [docs/tasks/order_flow_phase3b/spec.md](../../order_flow_phase3b/spec.md)

---

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 초안 | architect | 본 spec 최초 작성 (결정 A~E + Q1~Q5). sub-phase 1·2 의 누적 보류 항목 (1)~(6) 전수 반영 |

---

## 개요

- **목적**: sub-phase 2 가 고객 알림을 도입하면서 **권한 sticky 정책** (`users/{uid}.notificationPermissionPrompted` 가 server-side 영속) 을 채택했다. 그 결과 사용자가 알림 권한 다이얼로그에서 한 번 "나중에" 를 누르면 **앱 내에서 알림을 다시 켤 경로가 전혀 없다**. 본 sub-phase 는 ① "더보기 > 알림 설정" 화면을 신설해 이 막다른 길을 해소하고 ② 알림 카테고리별 on/off 설정을 Firestore 에 영속화하여 Cloud Function 이 발화 전에 이를 반영하게 한다.
- **부수 목적**: ③ sub-phase 2 결정 B 에서 "미발화" 로 확정한 `ready → completed` 알림을 **옵트인 토글** 로 되살린다 (결정 B 의 옵션 (C) 경로). ④ OS 권한이 거부된 상태를 화면에서 명시하고 OS 설정 앱으로 유도한다. ⑤ "OS 설정에서 직접 권한을 허용했으나 fcmToken 이 등록되지 않은" sub-phase 2 비범위 edge case 를 reconcile 한다.
- **작업 유형**: 신규 화면 추가 + 기존 Cloud Function 3개에 게이트 추가 (신규 Cloud Function 없음).
- **actor**: customer / owner **양쪽**. 설정 화면은 공통 위젯 1개를 `audience` 로 분기 (`NotificationPermissionDialog` 의 기존 분기 패턴과 동일).
- **클라이언트 SDK 직접 write 경로**: `users/{uid}.notificationSettings` — 본인만. Firestore Rules `isSelfProfileUpdate` 화이트리스트 확장 필요 (유일한 Rules 변경).

### Phase 3c 전체 로드맵 (본 sub-phase 위치)

| sub-phase | 범위 | 본 spec 범위 |
|---|---|---|
| 3c-1 (완료) | Order 조리 단계 전이 + 점주 UI + Rules O5/O6/O7 + 환불 차단 (Q7) | ❌ (완료) |
| 3c-2 (완료) | 고객 측 FCM 알림 (status 전이 3건) + 고객 진행 인디케이터 + 고객 알림 권한 흐름 | ❌ (완료) |
| **3c-3 (본 spec)** | 알림 설정 UI (고객·점주) + 명시 재요청 경로 + 카테고리 on/off + `ready→completed` 옵트인 | ✅ |
| 3c-4 또는 별 phase (후보) | 환불 승인/거절 결과 알림 (`cancelled` / `refunded` 전이 알림) | ❌ (§비범위 — 후속 task 권고) |

### 누적 보류 항목 처리표

sub-phase 1·2 문서에서 "Phase 3c-3 에서 처리" 로 미뤄둔 항목의 본 spec 내 처리 위치.

| # | 항목 | 출처 | 본 spec 처리 |
|---|---|---|---|
| (1) | 알림 설정 UI 본체 (점주·고객 toggle / 카테고리별 on-off) | `2_.../spec.md:36`, `1_.../spec.md:37` | ✅ **포함** — 본 sub-phase 핵심 (결정 A / C) |
| (2) | sticky 정책의 명시 재요청 경로 ("더보기 > 알림 설정") | `2_.../spec.md:202-203` | ✅ **포함** — 본 sub-phase 핵심 가치 (결정 A / D) |
| (3) | `ready → completed` 옵트인 알림 | `2_.../spec.md:127-129` (결정 B 옵션 C) | ✅ **포함** — `pickupComplete` 토글 (결정 C / E) |
| (4) | `NotificationPermissionDialog` 고객 카피 개선 | `2_.../test_report.md:269` (O-1) | ⚠️ **변경 없음** — 라이브 검증 PASS 상태의 audience 분기 카피가 이미 적용됨 (`notification_permission_dialog.dart:40-51`). designer 가 **재검수만** 수행하고 변경 불필요 판정 시 design.md 에 사유 1줄 기록 (§작업 분배 U6) |
| (5) | 점주 환불 승인/거절 후속 알림 (고객 수신) | `2_.../spec.md:59` | ❌ **비범위** — 후속 task `order_refund_result_notification` 분리 권고 (§비범위 참조) |
| (6) | `cancelled` / `refunded` 전이 알림 | `2_.../spec.md:587` | ❌ **비범위** — (5) 와 동일 맥락. 같은 후속 task 로 묶음 |

### 영향 범위

| 레이어 | 영향 |
|---|---|
| **Domain** | 신규 `NotificationSettingsEntity` (freezed, 순수 Dart) + 신규 `NotificationCategory` enum. `UserEntity` 에 `notificationSettings` 필드 1개 추가. `UserRepository` 인터페이스에 메서드 1개 추가. 신규 UseCase 2개. |
| **Data** | 신규 `NotificationSettingsModel` (또는 `UserModel` 내 inline 매핑 — §데이터 모델 참조). `UserModel` 필드 1개 + `fromFirestore` 매핑 추가. `UserRemoteDataSource` 에 dot-path update 메서드 1개 추가. `UserRepositoryImpl` 위임 추가. |
| **Presentation (공통)** | 신규 `NotificationSettingsPage` (`lib/presentation/common/notification/notification_settings_page.dart`) — `audience` 파라미터로 customer/owner 분기. 신규 provider 파일 1개. |
| **Presentation (customer)** | `more_page.dart` 에 "알림 설정" 진입 타일 추가. MorePage 는 현재 재사용 가능한 `_Tile` 패턴이 없음 → designer 가 타일 스타일 정의 (§U4). |
| **Presentation (owner)** | `owner_more_page.dart` 에 "알림 설정" 진입 타일 추가 (기존 private `_Tile` 재사용). |
| **Provider DI** | 신규 `notification_settings_providers.dart`. 기존 `notification_providers.dart` / `user_profile_provider.dart` 재사용 (`currentUserProfileProvider` / `pushNotificationRepositoryProvider` / `requestNotificationPermissionUseCaseProvider` / `registerFcmTokenUseCaseProvider`). |
| **Firestore Rules** | **변경 있음** — `isSelfProfileUpdate` 의 `onlyChangedFields` 화이트리스트에 `notificationSettings` 추가. 유일한 Rules 변경. |
| **Cloud Functions** | 신규 함수 **없음**. 기존 3개 수정 — `onOrderStatusChanged` (게이트 + `ready→completed` 엔트리 추가), `onOrderCreated` (게이트), `onOrderRefundRequested` (게이트). 신규 공통 helper 파일 1개 (`notificationSettings.ts`). |
| **공통 컴포넌트** | 알림 설정 토글 타일 (신규) + OS 권한 상태 배너. 점주 측 `NotificationDeniedBanner` (`lib/presentation/owner/orders/widgets/notification_denied_banner.dart`) 를 **common 으로 승격할지 designer 판단** (§U3). |
| **라우팅** | `NotificationNavigator` 에 `orderCompleted` type 분기 추가 (customer `OrderDetailPage` push). `NotificationType` enum 에 case 1개 추가. 설정 화면 자체는 `Navigator.push` (named route 없음 — 기존 앱 패턴 그대로). |
| **권한 / 환경 설정** | 신규 패키지 **없음** — `app_settings: ^5.1.1` 이 이미 `pubspec.yaml` 에 존재하고 `NotificationDeniedBanner` 에서 사용 중. 신규 환경 변수 없음. iOS 는 `ios_apns_setup` task 완료 후 회귀. |
| **테스트** | sub-phase 1·2 회귀 + 본 sub-phase T1~T16. |

### 비범위

본 sub-phase 가 **명시적으로 다루지 않는** 항목.

- **환불 승인/거절 결과 알림** (누적 항목 (5)(6)) — `processRefund` CF 가 `refunded` 로 전이시킬 때 / 점주가 `refundRequest.deniedAt` 을 채울 때 **고객에게** 결과 알림. 발화 조건·카피·`refundRequest` sub-state diff 감지 로직이 모두 신규이고, `cancelled` 전이 (고객 자체 취소 vs 점주 거절, `cancelInfo.approvedBy` 분기) 까지 얽혀 범위가 비대해진다. → **후속 task `order_refund_result_notification` 로 분리 권고**. 단, 본 sub-phase 의 `notificationSettings` 스키마는 이 후속 task 가 `refundResult` 키를 **추가만 하면 되도록** 확장 가능하게 설계한다 (결정 B).
- **알림 설정의 세분화 확장** — 단계별 (`접수만` / `조리만` / `준비만`) 개별 토글. 결정 C 에서 coarse 2+2 로 확정. 요구가 생기면 스키마 변경 없이 키 추가로 가능.
- **알림 시간대 설정 (방해 금지 시간)** — 별 phase.
- **앱 내 알림함 / 수신 히스토리** — 별 phase (sub-phase 2 비범위 그대로).
- **FCM 토픽 구독 방식으로의 전환** — 결정 E 에서 기각. 현재 단일 토큰 직접 발송 유지.
- **멀티 디바이스 토큰 관리** — `users/{uid}.fcmToken` 단일 필드 구조 그대로. 별 phase.
- **iOS APNs 발급 / 설정** — 별 task `docs/tasks/ios_apns_setup/`. 본 sub-phase 라이브 검증은 Android 만.
- **다국어 알림 본문 / UI 카피** — 한국어 fixed.
- **`minInstances=1` 운영 설정** — sub-phase 1 보완 1 에서 보류. 별 task.
- **푸시 알림 거절 사용자의 대체 채널** (SMS / 이메일) — 별 phase.
- **설정 변경 이력 / 분석** — 별 phase.
- **`notificationPermissionPrompted` 필드 자체의 의미 변경** — sub-phase 2 의 sticky 정책 그대로 유지. 본 sub-phase 는 **우회 경로를 추가**할 뿐 플래그 정책을 바꾸지 않는다 (§결정 D-3).

---

## 사전 확인 결과 (architect 코드 점검)

본 spec 작성 시점에 실제 코드를 직접 확인한 결과.

| 항목 | 상태 | 비고 |
|---|---|---|
| `app_settings` 패키지 | ✅ `pubspec.yaml` 에 `app_settings: ^5.1.1` 존재 | `lib/presentation/owner/orders/widgets/notification_denied_banner.dart:14` 에서 `AppSettings.openAppSettings()` 사용 중. **신규 패키지 추가 불필요** (결정 D) |
| 점주 측 OS 권한 거부 배너 | ✅ 이미 존재 — `NotificationDeniedBanner` + `OwnerOrdersPage._refreshNotificationBanner` (`owner_orders_page.dart:66-88`) | `didChangeAppLifecycleState(resumed)` 에서 권한 재확인하는 패턴까지 완성됨. **본 sub-phase 설정 화면이 그대로 차용할 기준 패턴** |
| 고객 측 OS 권한 거부 배너 | ❌ 없음 | 본 sub-phase 의 설정 화면이 양쪽 공통으로 제공 |
| `MorePage` (고객 더보기) | `lib/presentation/customer/more/more_page.dart` — `ListView` + `UpgradeToOwnerSection` / `UpgradeToBrandSection` / 로그아웃 TextButton / 버전 텍스트. **재사용 가능한 ListTile 패턴 없음** | designer 가 고객 측 설정 진입 타일 스타일 정의 필요 (U4) |
| `OwnerMorePage` (점주 더보기) | `lib/presentation/owner/more/owner_more_page.dart` — private `_Tile` (ListTile 래퍼, icon/title/subtitle/chevron) 보유 | 점주 측은 `_Tile` 1개 추가로 끝. **공통 위젯 추출 여부는 designer 판단** (U4) |
| `NotificationPermissionDialog` 의 audience 분기 | ✅ 이미 구현됨 — `NotificationDialogAudience { owner, customer }` + `_primaryBody` / `_secondaryBody` switch (`notification_permission_dialog.dart:40-51`) | 누적 항목 (4) 는 **이미 해소됨**. 본 sub-phase 는 재검수만 (U6) |
| `DialogQueueService` 경유 | ✅ `showNotificationPermissionDialog` 가 `queue.enqueueDialog` 사용 | 본 sub-phase 의 설정 화면 내 재요청도 **동일 큐 경유 필수** (dedup key 충돌 주의 — §결정 D-2) |
| `users/{uid}` 의 알림 관련 필드 | `fcmToken`, `fcmTokenUpdatedAt`, `notificationPermissionPrompted` 3개 (`user_entity.dart:19-24`, `user_model.dart:24-33`) | 본 sub-phase 가 `notificationSettings` 1개 추가 |
| `UserRemoteDataSource` 의 쓰기 메서드 | `updateFcmToken` / `markNotificationPermissionPrompted` 존재 (`user_remote_data_source.dart:44-66`) | 동일 패턴으로 `updateNotificationSetting` 추가 |
| Firestore Rules `isSelfProfileUpdate` 화이트리스트 | `['role','displayName','photoUrl','fcmToken','fcmTokenUpdatedAt','notificationPermissionPrompted','updatedAt','brandId']` (`firestore.rules:90`) | `notificationSettings` 추가 필요 — **본 sub-phase 유일한 Rules 변경** |
| `currentUserProfileProvider` | ✅ `StreamProvider<UserEntity?>` 로 `users/{uid}` 실시간 구독 (`user_profile_provider.dart:52-72`) | 설정 화면이 **별도 stream 없이** 이 provider 를 watch 하면 토글 상태가 실시간 반영. 신규 stream 불필요 |
| `onOrderStatusChanged` 의 매트릭스 | `paid->accepted` / `accepted->making` / `making->ready` 3건. `ready->completed` 는 주석으로 미발화 명시 (`onOrderStatusChanged.ts:22-41`) | 본 sub-phase 가 `ready->completed` 엔트리 추가 + 전체에 게이트 삽입 |
| CF 3개의 `users/{uid}` 조회 시점 | `onOrderCreated.ts:62`, `onOrderRefundRequested.ts:73`, `onOrderStatusChanged.ts:91` — 모두 **이미 user doc 전체를 `.get()`** 함 | 설정을 같은 snapshot 에서 읽으면 **추가 Firestore read 0건** (결정 B 의 결정적 근거) |
| `NotificationType` enum | `newOrder` / `refundRequest` / `orderAccepted` / `orderMaking` / `orderReady` / `unknown` (`remote_notification_message.dart:2-10`) | `orderCompleted` 1개 추가 |
| `OrderStatus` 의 `refundCompleted` | ❌ 없음 — `refunded` 만 존재 (sub-phase 2 test_report O-2 확인) | 후속 환불 알림 task 설계 시 주의 |

---

## architect 잠정 결정 (사용자 확인 필요)

⚠ 아래 결정 A~E 는 architect 잠정안. **사용자 승인 후 designer / developer 호출**.

### 결정 A. 본 sub-phase 범위 — (B) 핵심 + 옵트인 (architect 추천)

누적 항목 (1)~(6) 중 무엇을 포함할지.

| 옵션 | 포함 항목 | 장점 | 단점 |
|---|---|---|---|
| (A) 최소 | (1)(2) 만 — 설정 화면 + 재요청 경로. 토글은 전체 on/off 1개 | 범위 최소. 1주 내 완료 | `ready→completed` 옵트인 (3) 이 또 미뤄짐. "전체 off" 는 OS 권한 끄기와 기능이 겹쳐 앱 내 토글의 존재 가치가 약함 |
| **(B) 핵심 + 옵트인** (architect 추천) | (1)(2)(3)(4 재검수만) | 설정 화면이 생기면 (3) 은 **토글 1개 + CF 매트릭스 1행** 으로 자연히 따라옴. (4) 는 이미 코드상 해소되어 재검수 비용만. 스키마를 1회만 설계·배포 | (5)(6) 이 또 미뤄짐 — 단 그 둘은 설정 UI 와 **의존 관계가 없음** |
| (C) 전체 | (1)~(6) 전부 | 누적 보류 전부 소진 | (5)(6) 은 `refundRequest` sub-state diff 감지 + `cancelInfo.approvedBy` 분기 + 신규 카피 3종 + 신규 알림 type 2~3종. 설정 UI 와 **독립적인 작업**이 본 sub-phase 를 2배로 비대화. 결정/검증 축이 2개로 늘어 tester 부담 급증 |

채택 = **(B)**. 사유: (5)(6) 은 "알림 설정" 이라는 본 sub-phase 의 축과 **의존하지 않는 독립 feature** 다. 설정 화면이 없어도 구현 가능하고, 설정 화면이 있어도 구현이 쉬워지지 않는다. 반면 (3) 은 설정 화면 없이는 구현 자체가 불가능하다 (옵트인 저장소가 없으므로). 따라서 의존 관계를 기준으로 분할한다.

> (5)(6) 은 §비범위 의 후속 task `order_refund_result_notification` 로 분리. 본 sub-phase 의 스키마가 `refundResult` 키를 **추가만 하면 되도록** 설계되므로 (결정 B), 후속 task 는 CF 측 작업만 남는다.

### 결정 B. 알림 설정 저장 위치 / 스키마 — (A) `users/{uid}.notificationSettings` map 필드 (architect 추천)

Cloud Function 이 발화 전에 읽어야 하므로 **서버 접근 가능**이 필수 요건.

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) `users/{uid}` 에 `notificationSettings` map 필드 추가** (architect 추천) | CF 3개가 **이미 `users/{uid}` 전체 doc 을 `.get()` 하고 있음** → 추가 Firestore read **0건**, 추가 지연 0ms. Rules 는 기존 `isSelfProfileUpdate` 화이트리스트에 키 1개 추가로 끝. `currentUserProfileProvider` 가 이미 이 doc 을 구독하므로 클라이언트 신규 stream 0개. 키 추가로 무한 확장 가능 | map 필드는 Rules 로 내부 키 단위 검증이 번거로움 (단, 본 필드는 bool map 이고 악용 시 영향이 "본인 알림이 안 옴" 뿐이라 위험 낮음) |
| (B) 하위 컬렉션 `users/{uid}/settings/notifications` | 필드 단위 Rules 분리 깔끔. doc 크기 분산 | CF 마다 **Firestore read +1건** (알림 1건당 비용·지연 증가). Rules 블록 신규. 클라이언트 stream 신규. 이득 없이 비용만 증가 |
| (C) 로컬 (SharedPreferences) | 서버 비용 0 | ❌ **요건 미충족** — CF 가 읽을 수 없어 발화 게이트 구현 불가. 기기 교체 시 유실. 즉시 기각 |
| (D) (A) + 로컬 캐시 병행 | 오프라인 즉시 반응 | 두 저장소 동기화 복잡. Firestore 오프라인 persistence 로 이미 충분. 과잉 |

채택 = **(A)**.

**스키마** (`users/{uid}`):

```
notificationSettings: {
  orderProgress:   bool,   // customer — 주문 접수 / 조리 시작 / 픽업 준비 (3건 묶음)
  pickupComplete:  bool,   // customer — 픽업 완료 (옵트인, 기본 false)
  newOrder:        bool,   // owner    — 신규 주문
  refundRequest:   bool,   // owner    — 환불 요청
}
```

**기본값 정책 (중요)**: 필드 또는 내부 키가 **없으면 기본값으로 fallback**. 클라이언트와 CF **양쪽**에서 동일 기본값을 적용한다. → 기존 사용자 doc 에 대한 **마이그레이션 불필요**.

| 키 | 기본값 | 사유 |
|---|---|---|
| `orderProgress` | `true` | sub-phase 2 의 현재 동작 (발화) 유지 — 기존 사용자에게 행동 변화 없음 |
| `pickupComplete` | **`false`** | sub-phase 2 결정 B 가 "미발화" 로 확정. 기본값을 true 로 하면 기존 사용자에게 **의도 없는 신규 알림**이 발생 → 반드시 `false` |
| `newOrder` | `true` | Phase 3b 의 현재 동작 유지 |
| `refundRequest` | `true` | Phase 3b 의 현재 동작 유지 |

> **후속 확장**: 환불 결과 알림 task 는 `refundResult: bool` (기본 `true`) 키를 추가하기만 하면 된다. 스키마 변경·마이그레이션 없음.

### 결정 C. 토글 카테고리 분류 — (B) 역할별 coarse 2개 (architect 추천)

| 옵션 | 고객 토글 | 점주 토글 | 장점 | 단점 |
|---|---|---|---|---|
| (A) 전체 on/off 1개 | 1개 | 1개 | 가장 단순 | OS 권한 끄기와 기능 중복 → 앱 내 토글의 존재 이유가 약함. `ready→completed` 옵트인 (3) 구현 불가 |
| **(B) 역할별 coarse 2개** (architect 추천) | `주문 진행 알림` (접수/조리/준비 묶음) + `픽업 완료 알림` (옵트인) | `신규 주문 알림` + `환불 요청 알림` | 각 토글이 **실제 의사결정 단위**와 일치. 화면당 2행 — 인지 부담 최소. 옵트인 (3) 자연 수용 | "조리 시작만 끄기" 불가 — 단 그런 요구는 관측되지 않음 |
| (C) status 단계별 세분 | 4~5개 (접수/조리/준비/픽업/환불결과) | 2~3개 | 최대 자율성 | 과도한 세분화 = UX 부담 (CLAUDE.md 의 "심플" 브랜드 원칙 위배). 설정 화면이 체크리스트처럼 보임. CF 게이트 분기도 4배 |
| (D) 전체 1개 + 카테고리 2개 (master + child) | 3개 | 3개 | 전체 끄기 shortcut | master off 시 child 상태 보존/복원 규칙이 복잡. OS 권한 off 와 의미 중복 |

채택 = **(B)**.

**토글 정의**:

| audience | 라벨 (잠정 — designer 확정) | 설명 보조 문구 (잠정) | 스키마 키 | 기본값 | 발화하는 알림 |
|---|---|---|---|---|---|
| customer | 주문 진행 알림 | 접수 · 조리 시작 · 픽업 준비 상태를 알려드려요 | `orderProgress` | `true` | `order_accepted` / `order_making` / `order_ready` |
| customer | 픽업 완료 알림 | 픽업이 완료되면 알려드려요 | `pickupComplete` | `false` | `order_completed` (신규) |
| owner | 신규 주문 알림 | 새 주문이 들어오면 바로 알려드려요 | `newOrder` | `true` | `new_order` |
| owner | 환불 요청 알림 | 고객이 환불을 요청하면 알려드려요 | `refundRequest` | `true` | `refund_request` |

**audience 판정**: `currentUserProfileProvider` 의 `UserEntity.role` 기준. `customer` → 고객 2개, `owner` → 점주 2개, `brand` / `admin` → **고객 2개로 fallback** (brand/admin 전용 알림이 아직 없으므로. 역할 전환이 자유로운 Qradar 특성상 설정 자체는 역할 무관하게 보존됨).

> ⚠️ 역할 전환 (customer ↔ owner) 시 **상대 역할의 설정 키는 Firestore 에 그대로 보존**된다. 화면에만 노출되지 않는다. 이는 의도된 설계 (역할 왕복 시 설정 유실 방지).

### 결정 D. OS 권한이 거부된 상태의 처리 — 3-state 화면 + OS 설정 유도 (architect 추천)

OS 권한이 꺼져 있으면 앱 내 토글이 켜져 있어도 알림이 오지 않는다. 이 괴리를 화면이 반드시 명시해야 한다.

#### D-1. 설정 화면의 3-state

`PushNotificationRepository.getPermissionStatus()` (기존 메서드, 변경 없음) 결과에 따른 분기.

| OS 권한 상태 | 상단 영역 | 토글 영역 | 주 CTA |
|---|---|---|---|
| `authorized` / `provisional` | 정상 — 배너 없음 (또는 "알림을 받고 있어요" 성공 톤, designer 판단) | **활성** | 없음 |
| `denied` | ⚠️ 경고 배너 — "기기 설정에서 알림이 꺼져 있어요" | **활성 유지** (아래 D-4 참조) | **"설정 열기"** → `AppSettings.openAppSettings()` |
| `notDetermined` | ℹ️ 안내 배너 — "알림을 켜면 주문 진행 상황을 바로 받아볼 수 있어요" | **활성 유지** | **"알림 켜기"** → 앱 내 권한 요청 (D-2) |

#### D-2. "알림 켜기" = sticky 정책의 명시 재요청 경로 (본 sub-phase 핵심 가치)

`notDetermined` 상태에서 사용자가 "알림 켜기" 를 탭하면:

1. `RequestNotificationPermissionUseCase.call()` 호출 (기존 UseCase 재사용) — OS 권한 시트 노출
2. 결과가 `authorized` / `provisional` → `RegisterFcmTokenUseCase.call(uid)` 호출 (기존 UseCase 재사용)
3. 결과가 `denied` → 화면을 `denied` state 로 전환 (배너 + "설정 열기")
4. **`notificationPermissionPrompted` 는 건드리지 않는다** — 이미 `true` 이며 본 흐름은 그 플래그와 무관한 명시 경로다

> ⚠️ **다이얼로그 재노출 금지**: 설정 화면의 "알림 켜기" 는 `showNotificationPermissionDialog` 를 **호출하지 않는다**. 사용자가 설정 화면에서 명시적으로 탭한 것 자체가 동의 의사이므로, 앞단 다이얼로그는 중복이다. `DialogQueueService` 의 dedup key (`notification_permission_<audience>`) 와 충돌할 위험도 함께 제거된다. → **OS 권한 시트를 바로 띄운다.**

#### D-3. sub-phase 2 sticky 정책과의 관계

| 항목 | 변경 여부 |
|---|---|
| `notificationPermissionPrompted` 의 의미 ("최초 권한 다이얼로그 노출 이력") | **변경 없음** |
| `ScaffoldWithNav` / `OwnerScaffold` 의 `_checkAndRequestNotificationPermission` | **변경 없음** — `prompted == true` 면 early return 유지 |
| 자동 재노출 | **여전히 없음** — 본 sub-phase 는 자동 재노출을 도입하지 않는다 |
| 명시 재요청 | **신규 추가** — "더보기 > 알림 설정 > 알림 켜기" 만이 유일한 재요청 경로 |

즉 본 sub-phase 는 sticky 정책을 **우회하지도 변경하지도 않고, 그 정책이 전제한 "명시 재요청 경로" 를 뒤늦게 공급**한다. sub-phase 2 spec:202-203 의 설계 의도와 정확히 일치한다.

#### D-4. OS 권한이 꺼진 상태에서 앱 내 토글의 동작

| 옵션 | 판단 |
|---|---|
| 토글을 **disable** (회색 처리) | ❌ — 사용자가 OS 설정을 켜고 돌아왔을 때 토글을 다시 조작해야 함. 2단계 요구는 이탈 유발 |
| **토글 활성 유지 + 배너로 괴리 명시** (architect 추천) | ✅ — 설정값은 Firestore 에 정상 저장되고, OS 권한이 켜지는 순간 즉시 유효해진다. 배너가 "지금은 안 온다" 는 사실을 책임지고 알린다 |

채택 = **활성 유지 + 배너 명시**.

#### D-5. OS 설정 복귀 시 reconcile (sub-phase 2 비범위 edge case 해소)

`WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` 에서 (`OwnerOrdersPage._refreshNotificationBanner` 와 **동일 패턴**):

1. `getPermissionStatus()` 재조회 → 3-state 갱신
2. 권한이 `authorized` / `provisional` **이고** `users/{uid}.fcmToken == null` 이면 → `RegisterFcmTokenUseCase.call(uid)` 호출

2번이 sub-phase 2 spec:216-217 이 비범위로 남긴 **"사용자가 OS 설정에서 직접 권한을 허용한 경우 fcmToken 등록이 다음 로그인까지 보류"** 를 해소한다. `SyncNotificationTokenUseCase` 로 캡슐화 (§레이어 설계).

### 결정 E. Cloud Function 의 설정 반영 방식 — (A) user doc 조회 후 게이트 (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) 발화 직전 user doc 의 설정 확인 후 skip** (architect 추천) | CF 3개가 **이미 user doc 을 `.get()` 함** → 추가 read 0건. 변경량 최소 (함수당 ~4줄 + 공통 helper 1개). 설정 변경이 **즉시** 반영 | 발송 skip 시에도 CF 가 cold start 비용을 쓴다 (무시 가능) |
| (B) FCM 토픽 구독 (`orderProgress` 토픽 등) | 서버가 user doc 을 읽지 않아도 됨 | 클라이언트가 토글마다 `subscribeToTopic`/`unsubscribeFromTopic` 호출 → 실패 시 서버 상태와 괴리 (복구 불가). 토픽은 **대상 전체 브로드캐스트**용이며 특정 1인 발송에 부적합. `orderId` 별 개인화 payload 와 궁합 나쁨. FCM SDK 호출면이 넓어짐. **기각** |
| (C) 클라이언트가 수신 후 필터링 | CF 변경 0 | ❌ 알림이 **이미 OS 에 표시된 뒤** 걸러짐 → 의미 없음. data-only 메시지 + 로컬 알림 구조에서도 백그라운드 핸들러 신뢰성 낮음. 기각 |

채택 = **(A)**.

**구현 형태** — 공통 helper `functions/src/notificationSettings.ts` 신규:

```
isNotificationEnabled(userData, key) → boolean
  - userData.notificationSettings?.[key] 가 boolean 이면 그 값
  - 아니면 DEFAULTS[key] (결정 B 의 기본값 표)
```

각 CF 는 이미 가져온 `userSnap.data()` 를 그대로 넘긴다. 기본값 표가 helper 1곳에만 존재해야 한다 (클라이언트 `NotificationSettingsEntity` 의 `@Default` 와 **값이 일치**해야 하며, implementation.md 에 cross-check 표 필수 — §작업 분배).

**각 CF 의 게이트 위치**:

| CF | 게이트 키 | 삽입 위치 |
|---|---|---|
| `onOrderCreated` | `newOrder` | `fcmToken` 조회 직후 (`onOrderCreated.ts:68` 부근), 발송 전 |
| `onOrderRefundRequested` | `refundRequest` | `fcmToken` 조회 직후 (`onOrderRefundRequested.ts:79` 부근), 발송 전 |
| `onOrderStatusChanged` | 매트릭스 엔트리별 (`orderProgress` 또는 `pickupComplete`) | `fcmToken` 조회 직후, 발송 전 |

skip 시 `console.info` 구조화 로그 (`{ userId, orderId, key, reason: "disabled_by_user" }`) — tester 가 로그로 검증할 수 있어야 한다.

**`onOrderStatusChanged` 매트릭스 확장**:

| 전이 | type | 제목 | 본문 | 게이트 키 |
|---|---|---|---|---|
| `paid->accepted` | `order_accepted` | 주문이 접수되었어요 | {storeName}에서 주문을 받았어요. | `orderProgress` |
| `accepted->making` | `order_making` | 음료를 만들고 있어요 | {storeName}에서 조리를 시작했어요. | `orderProgress` |
| `making->ready` | `order_ready` | 픽업 준비가 완료됐어요 | {storeName}에서 음료가 준비됐어요. 매장에 방문해 주세요. | `orderProgress` |
| **`ready->completed`** (신규) | `order_completed` | **픽업이 완료됐어요** | **{storeName} 주문이 완료됐어요. 맛있게 즐겨주세요.** | `pickupComplete` |

> 신규 카피는 sub-phase 2 결정 D 의 톤 (친근 + 정중 중간, 반높임체) 을 따른다. designer 검수 대상 (U5).

---

## 요구사항

### 기능 요구사항

#### 설정 저장 / 조회 (Domain · Data)

- [ ] **F1** `NotificationCategory` enum 신규 — `orderProgress` / `pickupComplete` / `newOrder` / `refundRequest`. 각 case 에 Firestore 키 문자열 (`asString`) 과 기본값 (`defaultValue`) 을 보유.
- [ ] **F2** `NotificationSettingsEntity` 신규 (freezed, 순수 Dart) — bool 4개 + `@Default` 는 결정 B 의 기본값 표와 일치. `bool valueOf(NotificationCategory)` 헬퍼 제공.
- [ ] **F3** `UserEntity` 에 `@Default(NotificationSettingsEntity()) NotificationSettingsEntity notificationSettings` 필드 추가.
- [ ] **F4** `UserModel` 에 동일 필드 추가 (`@JsonKey(includeFromJson: false, includeToJson: false)` — Firestore 전용, 기존 FCM 필드 3개와 동일 처리).
- [ ] **F5** `UserModelFactory.fromFirestore` 에 `notificationSettings` 매핑 — map 이 없거나 키가 없으면 **기본값 fallback** (마이그레이션 불필요).
- [ ] **F6** `UserModelX.toEntity()` 에 필드 전달 추가.
- [ ] **F7** `UserRemoteDataSource.updateNotificationSetting({uid, key, enabled})` 신규 — **dot-path update** (`'notificationSettings.$key': enabled`) 로 다른 키를 덮어쓰지 않을 것. `updatedAt: serverTimestamp` 동반 (기존 메서드 패턴).
- [ ] **F8** `UserRepository` 인터페이스에 `Future<void> updateNotificationSetting({required String uid, required NotificationCategory category, required bool enabled})` 추가.
- [ ] **F9** `UserRepositoryImpl` 에서 F7 로 위임. 도메인 enum → Firestore 키 변환은 **data 레이어 책임**.

#### UseCase (Domain)

- [ ] **F10** `UpdateNotificationSettingUseCase` 신규 — 단일 책임: 토글 1개 갱신.
- [ ] **F11** `SyncNotificationTokenUseCase` 신규 — OS 권한이 `authorized`/`provisional` 인데 `users/{uid}.fcmToken` 이 null 이면 `RegisterFcmTokenUseCase` 를 호출. 결정 D-5 캡슐화. 권한이 없거나 토큰이 이미 있으면 **no-op** (멱등).

#### 설정 화면 (Presentation)

- [ ] **F12** `NotificationSettingsPage` 신규 (`lib/presentation/common/notification/notification_settings_page.dart`) — `ConsumerStatefulWidget` + `WidgetsBindingObserver`. `audience` 파라미터 없이 **`currentUserProfileProvider` 의 `role` 로 자동 판정** (결정 C).
- [ ] **F13** 토글 상태는 `currentUserProfileProvider` (기존 `StreamProvider<UserEntity?>`) 를 watch 하여 표시 — **신규 stream 추가 금지**.
- [ ] **F14** OS 권한 상태는 `pushNotificationRepositoryProvider.getPermissionStatus()` 로 조회하고 local state 에 보관. `initState` 의 post-frame + `didChangeAppLifecycleState(resumed)` 양쪽에서 갱신 (`OwnerOrdersPage._refreshNotificationBanner` 패턴).
- [ ] **F15** 3-state 배너 / CTA 분기 (결정 D-1).
- [ ] **F16** `denied` 상태의 "설정 열기" → `AppSettings.openAppSettings()`. ⚠️ `app_settings` 는 외부 패키지이지만 **플랫폼 설정 화면 호출 전용** 이며 Firebase/데이터 SDK 가 아니다. 기존 `NotificationDeniedBanner` 가 presentation 에서 직접 호출하는 선례를 따른다 (레이어 규칙 위배 아님 — §레이어 규칙 주의 참조).
- [ ] **F17** `notDetermined` 상태의 "알림 켜기" → `RequestNotificationPermissionUseCase` → 허용 시 `RegisterFcmTokenUseCase`. **다이얼로그 경유 금지** (결정 D-2).
- [ ] **F18** `resumed` 시 `SyncNotificationTokenUseCase` 호출 (결정 D-5 / F11).
- [ ] **F19** 토글 탭 → `UpdateNotificationSettingUseCase` 호출. **optimistic UI** — 즉시 토글 반영 후 실패 시 롤백 + SnackBar. 연타 방지 (진행 중 키 집합 보유 — `OwnerOrdersPage._processingOrderIds` 패턴).
- [ ] **F20** 저장 중 토글 비활성 또는 로딩 표시 (designer 확정 — U2).

#### 진입점 (Presentation)

- [ ] **F21** `more_page.dart` (고객) 에 "알림 설정" 진입 타일 추가 → `Navigator.push(NotificationSettingsPage)`. 배치 위치는 designer 확정 (U4).
- [ ] **F22** `owner_more_page.dart` (점주) 에 `_Tile(icon: Icons.notifications_outlined, title: '알림 설정', ...)` 추가 → 동일 push. "고객 모드로 전환" 위/아래 배치는 designer 확정 (U4).

#### 알림 type 확장 (Presentation · Domain)

- [ ] **F23** `NotificationType` enum 에 `orderCompleted` 추가. `fromData` 의 typeStr 매핑에 `'order_completed'` 추가.
- [ ] **F24** `NotificationNavigator` 의 switch 에 `orderCompleted` → customer `OrderDetailPage` push 분기 추가. 클래스 doc comment 갱신 ("Phase 3c-3 에서 orderCompleted 추가").

#### Cloud Functions

- [ ] **F25** `functions/src/notificationSettings.ts` 신규 — `NOTIFICATION_SETTING_DEFAULTS` + `isNotificationEnabled(userData, key)`. **기본값의 유일한 서버측 진실원**.
- [ ] **F26** `onOrderCreated.ts` — `newOrder` 게이트 삽입 + skip 구조화 로그.
- [ ] **F27** `onOrderRefundRequested.ts` — `refundRequest` 게이트 삽입 + skip 구조화 로그.
- [ ] **F28** `onOrderStatusChanged.ts` — `NOTIFICATION_MATRIX` 각 엔트리에 `settingKey` 필드 추가 + 게이트 삽입 + skip 구조화 로그.
- [ ] **F29** `onOrderStatusChanged.ts` — `ready->completed` 엔트리 신규 추가 (결정 E 표). 기존 "결정 B: 미발화" 주석을 "결정 3c-3 E: pickupComplete 옵트인" 으로 갱신.
- [ ] **F30** `functions/src/index.ts` — **변경 없음** (신규 함수 없음). helper 는 export 하지 않는다.

#### Firestore Rules

- [ ] **F31** `isSelfProfileUpdate` 의 `onlyChangedFields` 화이트리스트에 `'notificationSettings'` 추가. 다른 분기 변경 없음.

#### 문서 갱신

- [ ] **F32** `docs/processes/role_flows.md` §4.1 (customer) / §4.2 (owner) 에 "알림 설정 변경" 행 추가 (화면: `common/notification/notification_settings_page.dart`, 의존 데이터: `users/{uid}.notificationSettings`).
- [ ] **F33** `docs/processes/data_ownership.md` §2.1 의 `users.update` self 케이스 화이트리스트에 `notificationSettings` 반영 (현 문서는 `fcmTokenUpdatedAt` / `notificationPermissionPrompted` 도 누락된 상태 — 함께 정정).
- [ ] **F34** `docs/processes/entity_lifecycle.md` §2.4 또는 §2.5 — `ready→completed` 전이에 옵트인 알림이 결합됨을 1줄 기록.

### UI 요구사항 (designer 위임)

- [ ] **U1** `NotificationSettingsPage` 전체 레이아웃 — AppBar(제목 "알림 설정") + 상태 배너 영역 + 토글 섹션. 섹션 헤더 유무 / 여백 / 구분선.
- [ ] **U2** 토글 타일 디자인 — 라벨 + 보조 설명 + `Switch`. 저장 중 / 비활성 / 에러 상태 시각. 토글 라벨·보조 문구 최종 확정 (결정 C 표는 잠정안).
- [ ] **U3** 3-state 배너 디자인 (`authorized` / `denied` / `notDetermined`). 점주 측 `NotificationDeniedBanner` (`warning` 10% 배경 + `warning` 테두리 + 아이콘 + chevron) 를 **common 으로 승격해 재사용할지**, 설정 화면 전용으로 새로 디자인할지 판단하고 사유 기록.
- [ ] **U4** 더보기 진입 타일 — 고객 `MorePage` (ListTile 패턴 부재) 와 점주 `OwnerMorePage` (private `_Tile` 보유) 양쪽. **공통 `MoreTile` 위젯 추출 권고 여부**를 판단하고 사유 기록.
- [ ] **U5** `order_completed` 알림 카피 검수 (결정 E 표 잠정안) — sub-phase 2 결정 D 의 톤 정합.
- [ ] **U6** `NotificationPermissionDialog` 카피 재검수 — 누적 항목 (4). 현재 audience 분기 카피가 라이브 검증 PASS 상태이므로 **변경 불필요 판정이 기본 기대값**. 변경을 제안할 경우 근거 필수, 변경 없음일 경우에도 그 사유를 design.md 에 1줄 기록.
- [ ] **U7** `AppColors` 만 사용. `Color(0x...)` 금지 (CLAUDE.md 절대 규칙).
- [ ] **U8** 모바일 가로 폭 375~430pt 에서 토글 라벨 + 보조 문구가 줄바꿈 없이 또는 자연스럽게 2줄 처리되는지.

### 상태 요구사항

- [ ] **loading** — `currentUserProfileProvider` 가 loading 일 때: 토글 섹션 shimmer 또는 스켈레톤 (designer 확정). OS 권한 상태 조회 중에는 배너 영역 미노출 (깜빡임 방지).
- [ ] **error** — 프로필 조회 실패 시 에러 바디 + 재시도. 토글 저장 실패 시 **optimistic 롤백 + SnackBar** (전체 화면 에러로 전환하지 않음).
- [ ] **empty** — 해당 없음 (토글은 항상 고정 개수).
- [ ] **unauthenticated** — `uid == null` 이면 화면 진입 자체가 불가 (더보기 탭은 로그인 후에만 도달). 방어적으로 early return.

---

## 데이터 모델

### Entity

`lib/domain/entities/notification_settings_entity.dart` (신규)

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `orderProgress` | `bool` | `true` | customer — 접수/조리/준비 알림 |
| `pickupComplete` | `bool` | **`false`** | customer — 픽업 완료 알림 (옵트인) |
| `newOrder` | `bool` | `true` | owner — 신규 주문 알림 |
| `refundRequest` | `bool` | `true` | owner — 환불 요청 알림 |

`lib/domain/entities/notification_category.dart` (신규, 또는 위 파일에 동거 — developer 판단)

| case | Firestore 키 | 기본값 | audience |
|---|---|---|---|
| `orderProgress` | `orderProgress` | `true` | customer |
| `pickupComplete` | `pickupComplete` | `false` | customer |
| `newOrder` | `newOrder` | `true` | owner |
| `refundRequest` | `refundRequest` | `true` | owner |

`UserEntity` 변경: `@Default(NotificationSettingsEntity()) NotificationSettingsEntity notificationSettings` 1개 추가.

### Model / DTO

`UserModel` 에 동일 필드 추가. JSON 직렬화 제외 (`includeFromJson: false, includeToJson: false`) — 기존 `fcmToken` / `fcmTokenUpdatedAt` / `notificationPermissionPrompted` 와 동일 처리.

`UserModelFactory.fromFirestore` 매핑 규칙:

```
data['notificationSettings'] 가 Map 이 아니면 → 전부 기본값
Map 이면 각 키를 bool 로 캐스팅, 캐스팅 실패 또는 키 부재 시 해당 키만 기본값
```

> ⚠️ `toFirestoreForCreate()` 에는 **추가하지 않는다**. 가입 시점에 설정을 쓰지 않고, 부재 시 기본값 fallback 으로 동작한다 (Rules `users.create` 의 필드 제약과 충돌 회피). 사용자가 처음 토글을 조작할 때 dot-path update 로 처음 생성된다.

### Firestore 변경

`users/{uid}`:

| 필드 | 타입 | 쓰기 주체 | 비고 |
|---|---|---|---|
| `notificationSettings` | `map<string, bool>` | **본인만** (클라이언트 SDK, dot-path update) | 부재 허용. CF 는 read 만 |

**마이그레이션**: 없음. 기존 doc 은 필드 부재 → 클라이언트·CF 양쪽 기본값 fallback.

**인덱스**: 없음 (쿼리 대상 아님).

---

## 레이어 설계

### Domain

#### Entity

- `lib/domain/entities/notification_settings_entity.dart` (신규, freezed)
- `lib/domain/entities/notification_category.dart` (신규 enum — 또는 위 파일에 동거)
- `lib/domain/entities/user_entity.dart` (수정 — 필드 1개)

#### Repository Interface

`lib/domain/repositories/user_repository.dart` (수정) — FCM 섹션 아래에 추가:

```
/// 알림 카테고리 1개의 on/off 를 갱신한다 (다른 카테고리는 보존).
Future<void> updateNotificationSetting({
  required String uid,
  required NotificationCategory category,
  required bool enabled,
});
```

> `PushNotificationRepository` 는 **변경 없음** (`getPermissionStatus` / `requestPermission` / `getToken` 모두 기존 메서드로 충분).

#### UseCase

| 파일 (신규) | 책임 | 의존 |
|---|---|---|
| `lib/domain/usecases/update_notification_setting_use_case.dart` | 토글 1개 갱신 | `UserRepository` |
| `lib/domain/usecases/sync_notification_token_use_case.dart` | OS 권한 authorized + fcmToken null → 토큰 등록 (멱등 no-op) | `PushNotificationRepository`, `UserRepository` |

> 기존 `RegisterFcmTokenUseCase` / `RequestNotificationPermissionUseCase` 는 **그대로 재사용**. `SyncNotificationTokenUseCase` 가 내부적으로 `RegisterFcmTokenUseCase` 를 합성할지 repository 를 직접 쓸지는 developer 판단 (기존 `RegisterFcmTokenUseCase` 의 생성자 패턴 `{pushRepo, userRepo}` 참고).

### Data

#### DataSource

`lib/data/datasources/remote/user_remote_data_source.dart` (수정) — FCM 섹션 아래 추가:

```
/// 알림 설정 1개 키를 dot-path 로 갱신 (다른 키 보존).
/// 허용 필드: `notificationSettings`, `updatedAt` (Rules 화이트리스트).
Future<void> updateNotificationSetting({
  required String uid,
  required String key,
  required bool enabled,
}) async { ... 'notificationSettings.$key': enabled, 'updatedAt': serverTimestamp ... }
```

⚠️ `update()` 는 doc 이 없으면 실패한다. `users/{uid}` 는 로그인 시 `getOrCreateUserProfile` 로 보장되므로 기존 `markNotificationPermissionPrompted` 와 동일 전제로 충분하다. 별도 `set(merge:true)` 전환 불필요.

#### Model

`lib/data/models/user_model.dart` (수정) — 필드 + `fromFirestore` 매핑 + `toEntity` 전달. **domain enum → Firestore 키 변환은 data 레이어에서 수행** (domain enum 의 `asString` 를 data 에서 호출).

#### Repository Implementation

`lib/data/repositories/user_repository_impl.dart` (수정) — DataSource 위임 1개.

#### Cloud Functions

`functions/src/notificationSettings.ts` (신규):

```
export const NOTIFICATION_SETTING_DEFAULTS = {
  orderProgress: true,
  pickupComplete: false,   // 결정 B — 기존 사용자에게 의도 없는 신규 알림 금지
  newOrder: true,
  refundRequest: true,
} as const;

export type NotificationSettingKey = keyof typeof NOTIFICATION_SETTING_DEFAULTS;

export function isNotificationEnabled(
  userData: Record<string, unknown> | undefined,
  key: NotificationSettingKey,
): boolean { /* map 조회 → boolean 이면 사용, 아니면 DEFAULTS[key] */ }
```

| 수정 파일 | 변경 |
|---|---|
| `onOrderCreated.ts` | `userSnap.data()` 를 변수로 보관 → `isNotificationEnabled(userData, 'newOrder')` 가 false 면 구조화 로그 + return |
| `onOrderRefundRequested.ts` | 동일, 키 `refundRequest` |
| `onOrderStatusChanged.ts` | `NOTIFICATION_MATRIX` 엔트리에 `settingKey` 추가 + `ready->completed` 엔트리 신규 + 게이트 |

> ⚠️ `onOrderStatusChanged` 와 `onOrderRefundRequested` 는 **둘 다 `orders/{orderId}` 의 `onDocumentUpdated`** 를 구독한다. 환불 요청 update 는 `status` 가 바뀌지 않으므로 `onOrderStatusChanged` 가 early return 하고, status 전이 update 는 `refundRequest` 가 새로 생기지 않으므로 `onOrderRefundRequested` 가 early return 한다. 본 sub-phase 는 이 분리를 **변경하지 않는다** (회귀 검증 대상 — T14).

### Presentation

#### Page (신규)

`lib/presentation/common/notification/notification_settings_page.dart`

- `ConsumerStatefulWidget` + `with WidgetsBindingObserver`
- local state: `NotificationPermissionStatus? _osStatus`, `Set<NotificationCategory> _saving`
- `initState` → `addObserver` + post-frame `_refreshOsStatus()`
- `dispose` → `removeObserver`
- `didChangeAppLifecycleState(resumed)` → `_refreshOsStatus()` + `SyncNotificationTokenUseCase`
- `build` → `currentUserProfileProvider` watch → role 로 토글 목록 결정 → 배너 + 토글 리스트

> **위치 근거**: customer / owner 양쪽이 쓰므로 `lib/presentation/common/notification/` 이 맞다 (`notification_permission_dialog.dart` 와 동일 디렉토리). `docs/architecture.md` 의 공통 컴포넌트 배치 기준 준수.

#### Widget (신규)

- 토글 타일 위젯 (`_SettingToggleTile` private 또는 `widgets/` 분리 — designer 의 U2 결과에 따라 developer 판단)
- 상태 배너 위젯 — U3 결과에 따라 `NotificationDeniedBanner` 승격 또는 신규

#### Provider (신규)

`lib/presentation/common/notification/providers/notification_settings_providers.dart`

| Provider | 타입 | 내용 |
|---|---|---|
| `updateNotificationSettingUseCaseProvider` | `Provider<UpdateNotificationSettingUseCase>` | `userRepositoryProvider` 주입 |
| `syncNotificationTokenUseCaseProvider` | `Provider<SyncNotificationTokenUseCase>` | `pushNotificationRepositoryProvider` + `userRepositoryProvider` 주입 |

> 재사용 (신규 없음): `currentUserProfileProvider`, `userRepositoryProvider`, `pushNotificationRepositoryProvider`, `requestNotificationPermissionUseCaseProvider`, `registerFcmTokenUseCaseProvider`, `authProvider`.
>
> ⚠️ 설정 상태를 담는 **별도 AsyncNotifier 를 만들지 않는다** — `currentUserProfileProvider` 가 이미 `users/{uid}` 를 실시간 구독하므로 Firestore write 후 토글이 자동 갱신된다. optimistic UI 용 임시 상태만 page 의 local state 로 둔다.

#### 진입점 (수정)

| 파일 | 변경 |
|---|---|
| `lib/presentation/customer/more/more_page.dart` | "알림 설정" 타일 추가 (designer 의 U4 스타일) |
| `lib/presentation/owner/more/owner_more_page.dart` | `_Tile` 1개 추가 |

#### Routing (수정)

| 파일 | 변경 |
|---|---|
| `lib/domain/entities/remote_notification_message.dart` | `NotificationType.orderCompleted` + `'order_completed'` 매핑 |
| `lib/presentation/common/notification/notification_navigator.dart` | `orderCompleted` → `OrderDetailPage` push 분기 + doc comment 갱신 |

### Firestore Rules

`firestore.rules` — `isSelfProfileUpdate` (line 87~105) 의 `onlyChangedFields` 한 줄만 변경:

```
onlyChangedFields(['role', 'displayName', 'photoUrl', 'fcmToken', 'fcmTokenUpdatedAt',
                   'notificationPermissionPrompted', 'notificationSettings', 'updatedAt', 'brandId'])
```

**보안 판단**: `notificationSettings` 는 본인 doc 의 bool map 이다. 악의적 조작의 최대 영향은 "본인이 알림을 못 받음" 이며 타인/시스템에 영향이 없다. 내부 키 단위 Rules 검증 (키 화이트리스트 / 타입 검사) 은 **과잉** 으로 판단하고 도입하지 않는다. CF 측 `isNotificationEnabled` 가 `typeof === 'boolean'` 검사로 비정상 값을 기본값으로 흡수한다 (방어선).

---

## 데이터 흐름

### A. 설정 화면 진입 (고객)

```
MorePage "알림 설정" 탭
  → Navigator.push(NotificationSettingsPage)
  → initState: addObserver + postFrame _refreshOsStatus()
      → pushNotificationRepositoryProvider.getPermissionStatus()
      → FcmRemoteDataSource.getPermissionStatus()  [data 레이어]
      → FirebaseMessaging.getNotificationSettings()
      → setState(_osStatus)
  → build: ref.watch(currentUserProfileProvider)
      → WatchUserProfileUseCase → UserRepositoryImpl → UserRemoteDataSource.watch(uid)
      → Firestore users/{uid} snapshots
      → UserEntity.notificationSettings (부재 시 기본값)
  → role 로 토글 목록 결정 → 배너(_osStatus) + 토글(settings) 렌더
```

### B. 토글 조작 (optimistic)

```
Switch onChanged(enabled)
  → _saving.add(category) + setState (optimistic 반영)
  → UpdateNotificationSettingUseCase(uid, category, enabled)
  → UserRepository.updateNotificationSetting
  → UserRemoteDataSource.updateNotificationSetting  [data 레이어]
  → Firestore users/{uid}.update({'notificationSettings.<key>': enabled, updatedAt})
      ├ 성공 → currentUserProfileProvider stream 이 새 값 emit → optimistic 상태 해제
      └ 실패 → optimistic 롤백 + SnackBar ('설정 저장에 실패했어요')
  → _saving.remove(category)
```

### C. 명시 재요청 (sticky 우회 — 본 sub-phase 핵심)

```
[전제] users/{uid}.notificationPermissionPrompted == true (sub-phase 2 에서 "나중에" 선택)
       OS 권한 == notDetermined → 앱 내 재요청 경로 없음 (= 해소 대상)

더보기 > 알림 설정 진입 → 배너 "알림을 켜면 ..." + "알림 켜기" CTA
  → RequestNotificationPermissionUseCase.call()
  → PushNotificationRepository.requestPermission()  [data]
  → FirebaseMessaging.requestPermission() → OS 권한 시트
      ├ authorized/provisional
      │   → RegisterFcmTokenUseCase.call(uid)
      │   → getToken() → users/{uid}.update({fcmToken, fcmTokenUpdatedAt})
      │   → _refreshOsStatus() → 배너 제거
      └ denied
          → _refreshOsStatus() → denied 배너 + "설정 열기" CTA

※ notificationPermissionPrompted 는 건드리지 않는다 (이미 true, 의미 불변)
※ showNotificationPermissionDialog 는 호출하지 않는다 (결정 D-2)
```

### D. OS 설정 복귀 reconcile

```
"설정 열기" → AppSettings.openAppSettings() → OS 설정 앱
사용자가 알림 허용 → 앱 복귀
  → didChangeAppLifecycleState(resumed)
  → _refreshOsStatus() → authorized → 배너 제거
  → SyncNotificationTokenUseCase.call(uid)
      → getPermissionStatus() == authorized?
      → users/{uid}.fcmToken == null?
      → 둘 다 참이면 RegisterFcmTokenUseCase 로 토큰 등록
      → (아니면 no-op)
  ※ sub-phase 2 spec:216-217 의 비범위 edge case 해소
```

### E. 설정 반영 발화 (Cloud Function)

```
점주 "준비 완료" → orders/{orderId}.update(status: ready, readyAt)
  → onOrderStatusChanged (onDocumentUpdated)
  → status diff = 'making->ready' → NOTIFICATION_MATRIX 매칭 (settingKey: 'orderProgress')
  → users/{after.userId}.get()  [기존 조회 — 추가 read 없음]
  → fcmToken 없으면 skip (기존 동작)
  → isNotificationEnabled(userData, 'orderProgress')
      ├ true  → admin.messaging().send(...)
      └ false → console.info({userId, orderId, key, reason:'disabled_by_user'}) + return
```

### F. 픽업 완료 옵트인 발화

```
[전제] 고객이 알림 설정에서 "픽업 완료 알림" ON → notificationSettings.pickupComplete = true

점주 "픽업 완료" → orders/{orderId}.update(status: completed, completedAt)
  → onOrderStatusChanged → 'ready->completed' 매칭 (settingKey: 'pickupComplete')
  → isNotificationEnabled(userData, 'pickupComplete') == true
  → FCM 발송 (type: 'order_completed')
  → 클라이언트 수신 → RemoteNotificationMessage.fromData → NotificationType.orderCompleted
  → 탭 → NotificationNavigator → customer OrderDetailPage(orderId)

[기본 상태] pickupComplete 기본값 false → 기존 사용자 전원 미발화 (sub-phase 2 결정 B 동작 보존)
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 토글 저장 실패 (네트워크 / Rules 거부) | optimistic 롤백 + SnackBar. 전체 화면 에러 전환 없음 |
| `users/{uid}` doc 부재 상태에서 토글 조작 | `update()` 실패 → 위와 동일 처리. 로그인 시 `getOrCreateUserProfile` 로 보장되므로 실제 발생 가능성 낮음 |
| `currentUserProfileProvider` error | 에러 바디 + 재시도 버튼 (`ref.invalidate`) |
| `getPermissionStatus()` 실패 / 지연 | `_osStatus == null` 동안 배너 영역 미노출. 실패 시 배너 생략 (토글은 정상 동작) |
| `requestPermission()` 중 사용자가 시트를 밖으로 닫음 | 결과가 `notDetermined` 로 돌아옴 → 배너 유지, 재탭 가능 |
| `AppSettings.openAppSettings()` 실패 | try/catch + SnackBar ('설정 화면을 열 수 없어요'). 플랫폼 미지원 시 무음 실패 방지 |
| 토글 연타 | `_saving` 집합으로 동일 카테고리 중복 요청 차단 |
| `notificationSettings` 가 map 이 아닌 타입으로 오염 | 클라이언트 `fromFirestore` 가 기본값 fallback. CF `isNotificationEnabled` 가 `typeof` 검사로 기본값 fallback. 양쪽 모두 crash 없음 |
| CF 가 설정 조회 중 user doc 조회 실패 | 기존 동작 그대로 (`console.error` + return). 게이트 때문에 새 실패 경로가 생기지 않음 |
| role 이 `brand` / `admin` | 고객 토글 2개로 fallback (결정 C). 화면 비어 보이지 않게 보장 |
| 설정 화면 진입 시 `uid == null` | early return + 이전 화면 pop (방어적) |
| `order_completed` 알림을 구버전 클라이언트가 수신 | `NotificationType.unknown` → `NotificationNavigator` 가 아무것도 하지 않음 (기존 방어 로직). crash 없음 |

---

## 권한 / 보안

### Firestore Rules

- 변경: `isSelfProfileUpdate` 화이트리스트에 `notificationSettings` 추가 (F31).
- `users.read` 는 `self OR admin` 그대로 — 타인의 설정 조회 불가.
- CF 3개는 Admin SDK 로 Rules 우회 (기존과 동일).
- **사용자는 자기 설정만 수정 가능** — `uid() == userId` 조건이 `isSelfProfileUpdate` 에 이미 존재하므로 추가 조건 불필요.
- `users.create` 에는 `notificationSettings` 를 넣지 않는다 (`toFirestoreForCreate` 미포함) → create 분기의 `!('brandId' in ...)` 외 제약과 충돌 없음.

### 설정값 오염 / 악용

| 시나리오 | 영향 | 방어 |
|---|---|---|
| 본인이 `notificationSettings` 에 임의 키 주입 | 없음 (CF 는 알려진 키만 조회) | CF 의 키 화이트리스트 (helper 의 `DEFAULTS` keyof) |
| 본인이 bool 아닌 값 주입 | 없음 | 양쪽 `typeof` / 캐스팅 fallback |
| 타인의 설정 변경 | 불가 | `uid() == userId` (Rules) |
| 타인의 설정 조회 | 불가 | `users.read` self/admin 한정 |

### FCM 보안

- payload 구조 변경 없음. `order_completed` 도 기존 4개와 동일한 필드 (`type` / `orderId` / `storeId` / `title` / `body`) — 민감 정보 미포함.
- 수신 대상 정합: `onOrderStatusChanged` 가 `after.userId` 의 토큰으로만 발송 (기존). 변경 없음.

---

## 작업 분배

### designer

- UI 변경 필요 여부: **예** (신규 화면 1개 + 진입 타일 2곳).
- 디자인 산출물 (`docs/tasks/order_flow_phase3c/3_notification_settings/design.md`):
  - `NotificationSettingsPage` 레이아웃 (U1)
  - 토글 타일 + 저장 중/에러 시각 + 라벨·보조 문구 최종 확정 (U2)
  - 3-state 배너 (U3) — `NotificationDeniedBanner` common 승격 여부 판단 + 사유
  - 더보기 진입 타일 (U4) — 공통 `MoreTile` 추출 권고 여부 + 사유
  - `order_completed` 카피 검수 (U5)
  - `NotificationPermissionDialog` 카피 재검수 결과 (U6) — **변경 없음이 기본 기대값**, 어느 쪽이든 사유 1줄 필수
  - loading / error 상태 시각 (§상태 요구사항)
- 전달할 사항:
  - `AppColors` 만 사용 (CLAUDE.md 절대 규칙). `Color(0x...)` 금지
  - 기존 톤 참조: `NotificationDeniedBanner` (warning 10% 배경 + warning 테두리), `OwnerMorePage._Tile` (ListTile + chevron), `NotificationPermissionDialog` (surfaceElevated + radius 20)
  - 토글 2개뿐인 화면이 빈약해 보이지 않도록 섹션 헤더 / 설명 문구로 밀도 보완
  - 고객 `MorePage` 는 현재 ListTile 패턴이 없다 — 타일 1개만 추가하면 기존 구성과 톤이 어긋날 수 있으니 배치/스타일을 명시할 것
  - "알림 켜기" / "설정 열기" CTA 는 **배너 내부 탭** vs **별도 버튼** 중 택일하고 사유 기록

### developer

- 구현 항목:
  - **Domain** (F1~F3, F10~F11): `NotificationSettingsEntity` / `NotificationCategory` / `UserEntity` 필드 / UseCase 2개 / `UserRepository` 메서드 1개 (F8)
  - **Data** (F4~F7, F9): `UserModel` 필드 + `fromFirestore` fallback 매핑 / `UserRemoteDataSource.updateNotificationSetting` (dot-path) / `UserRepositoryImpl` 위임
  - **Presentation** (F12~F22): `NotificationSettingsPage` / 토글·배너 위젯 / provider 파일 1개 / 더보기 진입 타일 2곳
  - **알림 type** (F23~F24): `NotificationType.orderCompleted` + `fromData` 매핑 + `NotificationNavigator` 분기
  - **Cloud Functions** (F25~F30): `notificationSettings.ts` helper + CF 3개 게이트 + `ready->completed` 매트릭스 엔트리
  - **Rules** (F31): 화이트리스트 1줄
  - **문서** (F32~F34): `role_flows.md` / `data_ownership.md` / `entity_lifecycle.md`
- 재사용할 기존 구조 (**신규 작성 금지**):
  - `currentUserProfileProvider` — 설정 상태 stream (신규 stream 만들지 말 것)
  - `pushNotificationRepositoryProvider.getPermissionStatus()` — OS 권한 조회
  - `RequestNotificationPermissionUseCase` / `RegisterFcmTokenUseCase` — 권한 요청 / 토큰 등록
  - `OwnerOrdersPage._refreshNotificationBanner` (`owner_orders_page.dart:66-88`) — `resumed` 재확인 패턴
  - `OwnerOrdersPage._processingOrderIds` — 연타 방지 패턴
  - `NotificationDeniedBanner` — 배너 시각 (designer 의 U3 결과에 따라 승격 또는 참조)
  - `OwnerMorePage._Tile` — 점주 진입 타일
  - `app_settings` 패키지 (이미 pubspec 존재 — **추가 금지**)
- 주의할 레이어 규칙:
  - **`firebase_messaging` / `cloud_firestore` 직접 import 금지** (presentation / domain). `FcmRemoteDataSource` / `UserRemoteDataSource` 경유만.
  - `app_settings` 는 **예외적으로 presentation 에서 직접 사용 가능** — Firebase/외부 데이터 SDK 가 아니라 플랫폼 설정 화면을 여는 OS 호출이며, 기존 `NotificationDeniedBanner` 가 동일 패턴을 쓴다. CLAUDE.md 절대 규칙 2 의 대상이 아니다. **단, 데이터를 읽거나 쓰는 외부 SDK 라면 반드시 data 레이어로 격리할 것.**
  - `domain` 은 순수 Dart — `NotificationSettingsEntity` / `NotificationCategory` 에 Firestore 타입 참조 금지. Firestore 키 문자열은 enum 의 `asString` 으로 domain 에 두되, **Map 구성·파싱은 data 레이어** 에서 수행.
  - `AppColors` 강제. `Color(0x...)` 금지.
  - 신규 환경 변수 / API key 없음. 하드코딩 금지 규칙 해당 사항 없음.
  - freezed 필드 추가 후 `dart run build_runner build --delete-conflicting-outputs` 필수.
- 구현 후 산출물 (`docs/tasks/order_flow_phase3c/3_notification_settings/implementation.md`):
  - 생성/수정 파일 목록 (presentation / domain / data / functions / rules / docs)
  - **기본값 cross-check 표** (필수): 클라이언트 `NotificationSettingsEntity` 의 `@Default` ↔ CF `NOTIFICATION_SETTING_DEFAULTS` ↔ 본 spec 결정 B 표 — 3자 일치 확인
  - **키 문자열 cross-check 표** (필수): domain `NotificationCategory.asString` ↔ Firestore map 키 ↔ CF `NotificationSettingKey`
  - **type 문자열 cross-check 표**: CF `order_completed` ↔ 클라이언트 `fromData` 매핑 ↔ `NotificationNavigator` 분기
  - 결정 A~E 와의 일치 여부
  - Rules 변경 diff

### tester

- 주요 검증 기준 — §테스트 시나리오 T1~T16.
- 반드시 확인할 예외 케이스:
  - **기본값 회귀 (최우선)**: `notificationSettings` 필드가 **없는 기존 user doc** 으로 ① 주문 진행 알림 3건이 그대로 발화하는지 ② 픽업 완료 알림은 발화하지 **않는지** ③ 점주 신규 주문 / 환불 요청 알림이 그대로 발화하는지. 하나라도 어긋나면 **FAIL** (기존 사용자 행동 변화 = 결정 B 위반)
  - **sticky 우회 경로**: `notificationPermissionPrompted == true` + OS 권한 `notDetermined` 상태에서 설정 화면의 "알림 켜기" 로 권한 획득 + fcmToken 등록까지 도달하는지 (본 sub-phase 핵심 가치)
  - **다이얼로그 미노출**: "알림 켜기" 탭 시 `NotificationPermissionDialog` 가 **노출되지 않고** OS 시트가 바로 뜨는지 (결정 D-2)
  - **reconcile**: OS 설정에서 알림을 켜고 복귀했을 때 fcmToken 이 **재로그인 없이** 등록되는지 (결정 D-5)
  - **dot-path 보존**: 토글 1개 변경 시 다른 키가 유실되지 않는지 (Firestore doc 직접 확인)
  - **역할 전환 보존**: customer → owner 전환 후에도 customer 측 설정 키가 Firestore 에 남아 있는지 (결정 C)
  - **Rules 거부**: 타인 uid 의 `notificationSettings` update 시도 → 거부 (에뮬레이터 또는 수동)
  - **CF 로그**: 설정 off 시 `disabled_by_user` 구조화 로그가 남고 FCM 발송이 **없는지**
  - sub-phase 1·2 회귀 (조리 status 전이 / 고객 진행 인디케이터 / deep link 3상태 / 점주 알림)
  - iOS 는 별 task `ios_apns_setup` 완료 후 회귀 — 본 sub-phase 라이브 검증은 **Android 만**
- 산출물 (`docs/tasks/order_flow_phase3c/3_notification_settings/test_report.md`): PASS/FAIL 표 + 재현 절차 + 발견 이슈 + spec↔design↔implementation drift 점검.

---

## 테스트 시나리오 (T1~T16)

| # | 시나리오 | 사전 조건 | 검증 |
|---|---|---|---|
| T1 | 고객 설정 화면 진입 | 로그인 (customer) | 더보기 > 알림 설정 → 토글 2개 (주문 진행 / 픽업 완료) 노출. 픽업 완료는 **OFF** |
| T2 | 점주 설정 화면 진입 | 로그인 (owner) | 더보기 > 알림 설정 → 토글 2개 (신규 주문 / 환불 요청), 둘 다 **ON** |
| T3 | 토글 OFF 저장 | T1 | "주문 진행 알림" OFF → Firestore `users/{uid}.notificationSettings.orderProgress == false`. 화면 재진입 시 OFF 유지 |
| T4 | 토글 OFF 반영 (발화 차단) | T3 | 점주가 "주문 받기"/"조리 시작"/"준비 완료" → 고객 device 알림 **미도착**. CF 로그에 `disabled_by_user` |
| T5 | 토글 ON 복귀 | T4 | 다시 ON → 점주 status 전이 → 알림 **정상 도착** |
| T6 | 픽업 완료 옵트인 발화 | T1 에서 "픽업 완료 알림" ON | 점주 "픽업 완료" → 고객 device 에 `order_completed` 알림 도착. 탭 → 고객 `OrderDetailPage` |
| T7 | 픽업 완료 기본 미발화 (결정 B 보존) | `pickupComplete` 미설정 또는 OFF | 점주 "픽업 완료" → 알림 **미도착**. sub-phase 2 T4 회귀 PASS |
| T8 | **기본값 회귀 (필드 부재)** | `notificationSettings` 필드가 없는 기존 user doc | 진행 알림 3건 발화 ✅ / 픽업 완료 미발화 ✅ / 점주 신규 주문·환불 요청 발화 ✅ |
| T9 | **sticky 우회 — 명시 재요청** | `notificationPermissionPrompted == true` + OS 권한 `notDetermined` (sub-phase 2 에서 "나중에" 선택) | 설정 화면에 "알림 켜기" CTA 노출 → 탭 → **다이얼로그 없이** OS 권한 시트 → 허용 → `users/{uid}.fcmToken` 등록 → 배너 사라짐 → 알림 수신 정상화 |
| T10 | OS 권한 거부 상태 표시 + 설정 유도 | OS 설정에서 앱 알림 OFF | 설정 화면에 `denied` 배너 + "설정 열기" → OS 설정 앱 진입 |
| T11 | **OS 설정 복귀 reconcile** | T10 에서 OS 알림 ON 후 앱 복귀 (재로그인 없이) | 배너 사라짐 + `users/{uid}.fcmToken` 등록됨 (sub-phase 2 비범위 edge case 해소) |
| T12 | OS 권한 OFF 상태의 토글 조작 | T10 | 토글이 **활성** 상태이며 조작 시 Firestore 에 정상 저장. 배너는 유지 (결정 D-4) |
| T13 | 점주 토글 반영 | T2 | "신규 주문 알림" OFF → 고객이 주문 생성 → 점주 device 알림 미도착 + `onOrderCreated` 로그에 `disabled_by_user`. "환불 요청 알림" OFF → 고객 환불 요청 → 점주 알림 미도착 |
| T14 | **CF 분리 회귀** | — | 환불 요청 update 시 `onOrderStatusChanged` 가 early return (알림 1건만). status 전이 update 시 `onOrderRefundRequested` 가 early return. 중복 알림 없음 |
| T15 | dot-path 보존 + 역할 전환 보존 | 고객 토글 2개 설정 후 owner 전환 → 점주 토글 조작 | Firestore doc 에 customer 2키 + owner 2키 **모두 공존**. 어느 토글 변경도 다른 키를 지우지 않음 |
| T16 | sub-phase 1·2 회귀 | sub-phase 1 T1~T16 / sub-phase 2 T1~T13 | 모두 PASS (점주 조리 전이 / 고객 진행 인디케이터 / deep link foreground·background·terminated / 권한 다이얼로그 sticky) |

---

## 완료 기준

- [ ] 모든 요구사항 (F1~F34 / U1~U8) 구현 또는 보류 사유 명시
- [ ] `design.md` 작성 완료 (U1~U8, U3·U4·U6 는 판단 사유 포함)
- [ ] `implementation.md` 작성 완료 + **기본값 / 키 문자열 / type 문자열 cross-check 표 3종**
- [ ] `test_report.md` 작성 완료 + T1~T16 모두 PASS 또는 FAIL 후속 task 분리
- [ ] **T8 (기본값 회귀) PASS** — 기존 사용자에게 행동 변화 없음. 본 항목 FAIL 은 릴리스 차단 사유
- [ ] **T9 (sticky 우회) PASS** — 본 sub-phase 핵심 가치
- [ ] sub-phase 1·2 / Phase 3b 회귀 없음
- [ ] `firestore.rules` 변경 배포 + 타인 설정 update 거부 확인
- [ ] `docs/processes/role_flows.md` §4.1 / §4.2 에 "알림 설정 변경" 행 추가
- [ ] `docs/processes/data_ownership.md` §2.1 화이트리스트 정정 (`notificationSettings` + 기존 누락 2개)
- [ ] `docs/processes/entity_lifecycle.md` 에 `ready→completed` 옵트인 알림 1줄 기록
- [ ] `flutter analyze` warning 0 / `flutter test` PASS
- [ ] `functions` 빌드 (`npm run build` 또는 동등) 통과
- [ ] designer / developer / tester 모두 본 spec 의 결정 A~E 에 따라 작업했음을 산출물에서 명시

---

## 사용자 확인 필요 항목 (요약)

설계자 잠정안은 본문에 기록. 다음 항목은 **designer 호출 전 사용자 확인 필요**.

| Q# | 항목 | architect 잠정안 | 다른 선택지 | 상태 |
|---|---|---|---|---|
| **Q1** | 본 sub-phase 범위 (결정 A) | (B) 핵심 + 옵트인 — 누적 항목 (1)(2)(3) + (4 재검수). (5)(6) 은 후속 task 분리 | (A) 최소 ((1)(2) 만) / (C) 전체 ((1)~(6)) | 사용자 확인 필요 |
| **Q2** | 설정 저장 위치 / 스키마 (결정 B) | (A) `users/{uid}.notificationSettings` map 필드. 기본값 fallback → 마이그레이션 없음. `pickupComplete` 기본 **false** | (B) 하위 컬렉션 / (D) Firestore + 로컬 캐시 병행 | 사용자 확인 필요 |
| **Q3** | 토글 카테고리 분류 (결정 C) | (B) 역할별 coarse 2개 — 고객 `주문 진행` + `픽업 완료`, 점주 `신규 주문` + `환불 요청` | (A) 전체 on/off 1개 / (C) status 단계별 세분 / (D) master + child | 사용자 확인 필요 |
| **Q4** | OS 권한 거부 상태 처리 (결정 D) | 3-state 배너 + `app_settings` 로 OS 설정 유도 + 토글 활성 유지 + `resumed` reconcile. "알림 켜기" 는 다이얼로그 없이 OS 시트 직행 | 토글 disable / 다이얼로그 경유 재요청 / 배너 없이 토글만 | 사용자 확인 필요 |
| **Q5** | CF 의 설정 반영 방식 (결정 E) | (A) 발화 직전 user doc 설정 확인 후 skip (추가 read 0건, 공통 helper 1개) | (B) FCM 토픽 구독 / (C) 클라이언트 수신 후 필터 | 사용자 확인 필요 |

**추가 확인 희망 항목** (선택):

| # | 항목 | architect 의견 |
|---|---|---|
| Q6 | `order_completed` 알림 카피 — "픽업이 완료됐어요 / {storeName} 주문이 완료됐어요. 맛있게 즐겨주세요." | sub-phase 2 결정 D 톤 정합. designer 검수 (U5) 로 확정 가능 — 사용자 확인 생략 가능 |
| Q7 | 고객 `MorePage` 의 구조 정비를 본 sub-phase 에서 함께 할지 | **비권고** — 타일 1개 추가 범위를 넘어선다. designer 가 U4 에서 "공통 `MoreTile` 추출 권고" 를 남기면 별 task 로 처리 |

위 Q1~Q5 확정 후 designer 호출.

---

## 다른 task / 코드 영향 추적

| 대상 | 현재 정의 | 변경 필요 | 처리 방식 |
|---|---|---|---|
| `firestore.rules` `isSelfProfileUpdate` | 화이트리스트 8개 필드 | `notificationSettings` 추가 | 본 sub-phase 개발자 (F31) |
| `functions/src/onOrderCreated.ts` | 게이트 없음 | `newOrder` 게이트 | 본 sub-phase 개발자 (F26) |
| `functions/src/onOrderRefundRequested.ts` | 게이트 없음 | `refundRequest` 게이트 | 본 sub-phase 개발자 (F27) |
| `functions/src/onOrderStatusChanged.ts` | 매트릭스 3건, `ready->completed` 미발화 주석 | 게이트 + `ready->completed` 엔트리 + 주석 갱신 | 본 sub-phase 개발자 (F28, F29) |
| `functions/src/index.ts` | CF 8개 export | **변경 없음** (신규 함수 없음) | — |
| `lib/domain/entities/remote_notification_message.dart` | type 6개 (unknown 포함) | `orderCompleted` 추가 | 본 sub-phase 개발자 (F23) |
| `lib/presentation/common/notification/notification_navigator.dart` | customer 3 type 분기 | `orderCompleted` 분기 + doc comment | 본 sub-phase 개발자 (F24) |
| `lib/presentation/owner/orders/widgets/notification_denied_banner.dart` | owner 전용 | common 승격 여부 | designer 의 U3 판단 → 승격 시 개발자가 이동 + `OwnerOrdersPage` import 갱신 |
| `lib/presentation/common/scaffold_with_nav.dart` / `owner_scaffold.dart` | sticky 권한 hook | **변경 없음** (결정 D-3) | 회귀 검증만 (T16) |
| `docs/processes/role_flows.md` §4.1 / §4.2 | 알림 설정 행 없음 | "알림 설정 변경" 행 추가 | 본 sub-phase 개발자 또는 architect (F32) |
| `docs/processes/data_ownership.md` §2.1 | `users.update` 화이트리스트가 **현재 코드와 이미 불일치** (`fcmTokenUpdatedAt` / `notificationPermissionPrompted` 누락) | `notificationSettings` 추가 + 기존 누락 2개 정정 | 본 sub-phase 개발자 또는 architect (F33) |
| `docs/processes/entity_lifecycle.md` §2.4 / §2.5 | `ready→completed` 알림 기록 없음 | 옵트인 알림 결합 1줄 | 본 sub-phase 개발자 또는 architect (F34) |
| `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/spec.md` | 결정 B 가 "미발화" 확정 / 결정 E-C 가 "3c-3 재요청 경로" 예고 | "3c-3 에서 옵트인으로 확장됨 / 재요청 경로 도입됨" 노트 추가 | 본 sub-phase 작업 후 architect |
| `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/test_report.md` 미해소 보류 표 | 4개 항목 중 3개가 본 sub-phase 대상 | 해소 표시 | 본 sub-phase 작업 후 architect |
| `docs/tasks/ios_apns_setup/spec.md` | 회귀 대상에 3c-2 의 4종 type | `order_completed` + 설정 화면 회귀 대상 추가 | architect 후속 인계 |
| `docs/operations.md` | 알림 권한 prompt 재발화 운영 가이드 (3c-2 인계분) | "이제 앱 내 알림 설정에서 재요청 가능" 노트 추가 — Firestore doc 수동 정리 절차의 필요성이 줄어듦 | 본 sub-phase 작업 시 함께 갱신 |

### 후속 task 분리 권고

| 우선순위 | task 후보 | 내용 | 본 sub-phase 와의 관계 |
|---|---|---|---|
| **1 (높음)** | `order_refund_result_notification` | 누적 항목 (5)(6) — 점주 환불 승인(`refunded`)/거절(`refundRequest.deniedAt`)/취소(`cancelled`) 결과를 **고객에게** 알림. `cancelInfo.approvedBy` (customer/owner) 분기 포함. 신규 type 2~3종 + `processRefund` CF 후속 발화 또는 `onOrderStatusChanged` 매트릭스 확장 | 본 sub-phase 의 `notificationSettings` 에 `refundResult` 키를 **추가만** 하면 됨 (스키마 변경 없음) |
| 2 | `cloud_functions_min_instances` | sub-phase 1 보완 1 + 3c-2 인계 — CF cold start 운영 결정. 현재 CF 4개가 알림 발화 경로 | 독립 |
| 3 | `ios_apns_setup` (기존) | iOS APNs 발급 + 알림 전체 회귀. 본 sub-phase 의 `order_completed` + 설정 화면 포함 | 독립 |
| 4 | `more_page_restructure` (선택) | 고객 `MorePage` 가 ListTile 패턴 없이 섹션 위젯 + TextButton 혼재. 공통 `MoreTile` 추출 + 재구성 | designer 의 U4 판단 결과에 따라 발의 |
| 5 | `notification_inbox` (선택) | 앱 내 알림함 / 수신 히스토리 | 독립 |

---

## 참고 자료

- Phase 3b spec / implementation: `docs/tasks/order_flow_phase3b/`
- Phase 3c-1 / 3c-2 산출물: `docs/tasks/order_flow_phase3c/1_cooking_status_owner/`, `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/`
- 단일 진실원: `docs/processes/role_flows.md` §4.1 / §4.2, `docs/processes/entity_lifecycle.md` §2, `docs/processes/data_ownership.md` §2.1
- Cloud Functions: `functions/src/onOrderStatusChanged.ts`, `functions/src/onOrderCreated.ts`, `functions/src/onOrderRefundRequested.ts`, `functions/src/index.ts`
- FCM 인프라: `lib/data/datasources/remote/fcm_remote_data_source.dart`, `lib/data/repositories/push_notification_repository_impl.dart`, `lib/domain/repositories/push_notification_repository.dart`, `lib/domain/entities/remote_notification_message.dart`
- 알림 라우팅: `lib/presentation/common/notification/notification_navigator.dart`, `lib/presentation/common/notification/pending_notification_holder.dart`
- 알림 권한 흐름 (sticky): `lib/presentation/common/scaffold_with_nav.dart:45-94`, `lib/presentation/owner/owner_scaffold.dart:37-86`
- 알림 권한 다이얼로그 (audience 분기): `lib/presentation/common/notification/notification_permission_dialog.dart`
- OS 권한 거부 배너 + resumed 재확인 패턴: `lib/presentation/owner/orders/widgets/notification_denied_banner.dart`, `lib/presentation/owner/orders/owner_orders_page.dart:58-88`
- 사용자 프로필: `lib/domain/entities/user_entity.dart`, `lib/data/models/user_model.dart`, `lib/data/datasources/remote/user_remote_data_source.dart`, `lib/presentation/customer/auth/providers/user_profile_provider.dart`
- 더보기 화면: `lib/presentation/customer/more/more_page.dart`, `lib/presentation/owner/more/owner_more_page.dart`
- Rules: `firestore.rules:64-118` (`users/{userId}` + `isSelfProfileUpdate`)
- 별 task: `docs/tasks/ios_apns_setup/spec.md`
