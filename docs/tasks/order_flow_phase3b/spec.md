# order_flow_phase3b 기능 명세 (FCM 푸시 알림 인프라 — 점주 신규 주문/환불 요청 알림)

> 본 문서는 Qradar 의 **푸시 알림 인프라 첫 도입** phase. Phase 3a 결제 흐름의 후속.
>
> 큰 그림 단일 진실원: [docs/order_flow_summary.md](../../order_flow_summary.md) §3.
> 결제 흐름 단일 진실원: [docs/tasks/order_flow_phase3a/spec.md](../order_flow_phase3a/spec.md).
> 역할 흐름 / 엔티티 lifecycle / 데이터 소유권: [docs/processes/role_flows.md](../../processes/role_flows.md), [entity_lifecycle.md](../../processes/entity_lifecycle.md), [data_ownership.md](../../processes/data_ownership.md).

---

## 개요

- **목적**: Phase 3a 완료 후 점주가 `OwnerOrdersPage` 를 계속 열어둬야만 새 주문/환불 요청을 인지하는 불편을 해소한다. FCM 통한 푸시 알림 인프라를 구축해 **백그라운드/종료 상태에서도 점주가 즉시 알림** 받게 한다.
- **작업 유형**: 신규 인프라 도입 (대규모 — 클라이언트 + Cloud Functions + 네이티브 설정). 기존 결제 흐름 코드는 **변경 없음** (`verifyTossPayment` 등 그대로) — 알림은 Firestore trigger 기반으로 결합도 0.
- **트리거**: Firestore `onDocumentCreated` (orders 결제 직후) + `onDocumentUpdated` (환불 요청 추가 시) — Phase 3a 의 결제 / 환불 흐름과 **데코레이팅** 만.
- **수신 대상 (본 phase)**: **점주(`storeOwner`)** 만. 고객/관리자/브랜드 본사는 비범위 (별 phase).
- **알림 종류**:
  1. 신규 주문 (orders create, status='paid')
  2. 환불 요청 (orders update, `refundRequest` 신규 추가)

### 영향 범위

| 레이어 | 영향 |
|---|---|
| **클라이언트 (Flutter)** | (신규) FCM 초기화 / 토큰 발급·저장 / 권한 요청 / 메시지 수신 핸들러 / deep link 라우팅 |
| **Cloud Functions** | (신규) `onOrderCreated` (Firestore trigger) — 신규 주문 알림 / `onOrderRefundRequested` (Firestore trigger) — 환불 요청 알림 |
| **Firestore** | `users/{uid}.fcmToken` / `users/{uid}.fcmTokenUpdatedAt` 필드 활용 (이미 Rules 허용됨 — `isSelfProfileUpdate` 화이트리스트에 `fcmToken` 포함) |
| **iOS 네이티브** | APNs 인증서 / Capabilities (`Push Notifications`, `Background Modes - Remote notifications`) / `AppDelegate.swift` 수정 |
| **Android 네이티브** | `google-services.json` (이미 있을 가능성 — 확인 필요) / `AndroidManifest.xml` 알림 채널 메타 / `POST_NOTIFICATIONS` permission (Android 13+) |
| **Domain** | (신규) `PushNotificationRepository` 인터페이스 / `RegisterFcmTokenUseCase` / `RequestNotificationPermissionUseCase` / `HandleNotificationTapUseCase` |
| **Data** | (신규) `FcmRemoteDataSource` (FirebaseMessaging SDK 래퍼) / `PushNotificationRepositoryImpl` / (수정) `UserRemoteDataSource.updateFcmToken` |
| **Presentation** | (수정) `main.dart` (FCM 초기화 + 백그라운드 핸들러 등록) / (수정) `AuthNotifier` 또는 `RoleRouter` (로그인 직후 토큰 등록 hook) / (신규) `NotificationPermissionDialog` 위젯 / (신규) `notification_providers.dart` / `notification_navigator.dart` (deep link) |
| **공통 컴포넌트** | (신규) `NotificationPermissionDialog` |
| **라우팅** | `Navigator.push(MaterialPageRoute(...))` 패턴 유지 (Phase 3a 와 일관). 알림 탭 시 `Navigator` 전역 키 사용해 `OrderDetailPage` 진입 |
| **권한 / 환경 설정** | iOS APNs / Android FCM Server Key (FCM v1 API 는 Service Account JSON) / `firebase_messaging` 패키지 신규 설치 / `firebase-admin` 의 `messaging()` API 사용 (이미 설치됨) |
| **테스트** | FCM 콘솔 발송 + 실제 디바이스 테스트 (시뮬레이터/에뮬레이터는 push 미지원 — 실기기 필수) |

### 비범위

본 phase 가 **명시적으로 다루지 않는** 항목 (Phase 3c 또는 별 phase).

- **고객 측 알림** — 주문 접수됨(paid→accepted) / 환불 완료(refunded) / 환불 거절(refundRequest.deniedAt set) 알림 — Phase 3c 와 묶음
- **Order `making` / `ready` / `completed` 전이 알림** — Phase 3c 에서 함께
- **알림 설정 화면** (사용자가 알림 끄기 / 개별 카테고리 선택) — 별 phase (Phase 4 이상)
- **알림 히스토리** (앱 내 알림함) — 별 phase
- **브랜드 본사 / 관리자 알림** (가맹점 매출 요약, admin 승인 대기 알림 등) — 별 phase
- **소셜/마케팅 알림** (쿠폰, 공지) — 별 phase
- **알림 redelivery / 미수신 reconcile** (FCM 도착 실패 시 별도 큐) — 별 phase. 본 phase 는 FCM 자체 retry 만 신뢰
- **알림 클릭 통계 / 분석** — 별 phase
- **다국어 알림 본문** — 본 phase 는 한국어 fixed
- **iOS Critical Alert / Time-Sensitive Notification** (방해 금지 모드 우회) — 별 phase
- **Web 푸시** (브라우저) — 본 phase 는 iOS/Android 만
- **FCM 토픽 구독** (예: 매장별 토픽) — 본 phase 는 **개별 디바이스 토큰** 만 사용 (결정 D 참조)
- **Cloud Functions 의 다른 trigger 통합** (예: store 승인 알림) — 별 phase

---

## 사전 확인 결과 (architect 점검)

| 항목 | 상태 | 비고 |
|---|---|---|
| `firestore.rules` 의 `isSelfProfileUpdate` 화이트리스트 | ✅ `fcmToken` 포함됨 (line 90) | 추가 변경 불필요. 단, `fcmTokenUpdatedAt` 필드를 쓰려면 화이트리스트 추가 필요 (결정 C 참조) |
| 기존 `UserEntity` / `UserModel` 에 `fcmToken` 필드 | ❌ 없음 | 본 phase 에서 추가 |
| `firebase_messaging` 패키지 (`pubspec.yaml`) | ❌ 미설치 | 본 phase 에서 추가 (`firebase_messaging: ^15.x`) |
| `firebase-admin` (functions/package.json) | ✅ v12.7.0 설치됨 | `admin.messaging()` 사용 가능 |
| `firebase-functions` v2 (`onDocumentCreated`, `onDocumentUpdated`) | ✅ v6.3.2 설치됨 | `firebase-functions/v2/firestore` import 가능 |
| `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) | 확인 필요 | Phase 1c 소셜 로그인에서 이미 Firebase 통합됨 — 통상 존재. developer 가 실제 파일 확인 |
| iOS APNs 인증서 / `Push Notifications` Capability | ❌ 미설정 (예상) | 본 phase 에서 사용자 자체 발급 + Apple Developer / Firebase 콘솔 등록 — **사용자 manual 작업** 필요 |
| iOS `AppDelegate.swift` 의 messaging delegate / `UNUserNotificationCenter` 설정 | ❌ 미설정 (예상) | 본 phase 에서 추가 |
| Android `POST_NOTIFICATIONS` permission (Android 13+ 필수) | ❌ 미설정 (예상) | 본 phase 에서 추가 |
| `verifyTossPayment` (Cloud Function) 가 orders create 시 어떤 필드 set 하는지 | ✅ 확인 — `storeId`, `storeName`, `items`, `totalPrice`, `status='paid'`, `paymentInfo`, `userId` 등 (verifyTossPayment.ts:222-239) | trigger 함수에서 storeId 조회 → ownerId 조회 → fcmToken 조회 경로 가능 |

---

## architect 잠정 결정 (사용자 확인 필요)

⚠ 아래 결정 A~M 은 architect 잠정안이다. **사용자 승인 후 designer / developer 호출**.

### 결정 A. 알림 권한 요청 시점 — **(B) 점주 첫 OwnerScaffold 진입 시** (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 첫 로그인 직후 (모든 역할) | 누락 없이 권한 확보 | 고객은 본 phase 에 알림 받지 않는데도 권한 묻는 게 어색. 권한 거부율 ↑ |
| **(B) 점주가 `OwnerScaffold` 처음 진입할 때** (architect 추천) | "주문 알림을 받으려면 권한이 필요해요" 맥락이 명확. 본 phase 의 수신 대상(점주) 과 정합 | 첫 진입 시 다이얼로그 한번 더 — UX 약간 추가 |
| (C) 결제 직후 (고객) | 본 phase 수신 대상 아님 — 부적합 | — |
| (D) 더보기 메뉴의 "알림 설정" 진입 시 | 사용자가 명시적으로 켤 때만 | 본 phase 에 알림 설정 UI 비범위 — 부적합 |

채택 = **(B)**. 점주가 `OwnerScaffold` 진입 시 `users/{uid}.notificationPermissionPrompted` 플래그 확인 → 미설정이면 다이얼로그 노출 → 사용자 응답 후 플래그 set (재요청 방지).

> **고객/브랜드/관리자**: 본 phase 에서는 권한 요청 안 함. 향후 Phase 3c 에서 고객 알림 도입 시 동일 패턴 (`ScaffoldWithNav` 첫 진입) 적용 권장.

### 결정 B. 알림 payload 구조 — **`data-only` 메시지 + 클라이언트 측 로컬 알림 렌더링** (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) `notification` payload (FCM 자동 렌더링) | 구현 단순. 시스템이 자동으로 표시 | 백그라운드/종료 상태에서 `data` 콜백 안 옴 (iOS). Flutter 측 커스텀 처리 제한적 |
| **(B) `data-only` payload + `flutter_local_notifications` 로 클라이언트 측 렌더링** (architect 추천) | 포그라운드/백그라운드/종료 모든 상태에서 일관된 처리. deep link 정보(`orderId`) 안정적 전달 | `flutter_local_notifications` 패키지 추가 필요. 코드 복잡도 ↑ |
| (C) Hybrid: `notification` + `data` 동시 | iOS 는 자동 렌더링 + Android 는 커스텀 가능 | 플랫폼별 분기 복잡. data callback 보장 X |

채택 = **(B)**. 단, **MVP 단순화 옵션**: `flutter_local_notifications` 도입이 부담이면 **(C) Hybrid 채택 + `notification` 으로 시스템 표시 + `data` 에 orderId 동봉 + 탭 시 `data` 콜백으로 deep link** 로 간소화 가능. 사용자 확인 필요.

**payload 스키마 (결정 B 채택 시)**:

```jsonc
{
  "notification": {                      // (C) hybrid 시에만 포함
    "title": "신규 주문이 들어왔어요",
    "body": "{storeName} · {firstItemName} 외 {n-1}건 · {totalPrice}원"
  },
  "data": {
    "type": "new_order",                 // or "refund_request"
    "orderId": "ord_xxxxxxxx",
    "storeId": "store_xxxxxxxx",
    "storeName": "...",
    "totalPrice": "12000",
    "createdAt": "2026-05-29T12:34:56Z",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"  // Android 호환
  },
  "android": {
    "priority": "high",                  // 즉시 전송
    "notification": {
      "channel_id": "qradar_orders"      // Android 알림 채널
    }
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "sound": "default",
        "content-available": 1            // 백그라운드 wake 위해
      }
    }
  }
}
```

### 결정 C. FCM token 갱신 정책 — **(A) 매 로그인 + (B) onTokenRefresh 콜백 양쪽** (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 매 로그인 시점 | 명시적, 디버깅 용이 | onTokenRefresh 누락 시 토큰 stale |
| (B) `FirebaseMessaging.onTokenRefresh` 콜백 | FCM SDK 가 자동 처리. 가장 안전 | 콜백 등록 누락 시 동작 안 함 |
| **(A) + (B) 양쪽** (architect 추천) | 안전 + 자동. 토큰 stale 최소화 | 동일 토큰 중복 write 가능 (idempotent — 무해) |
| (D) 정기 (예: 매일 1회) | 불필요. FCM 토큰은 onTokenRefresh 시점 외에는 stable | — |

채택 = **(A) + (B)**.

**구현**:
- 로그인 직후 (auth 완료 시점 — `AuthNotifier.signIn*` 성공 후) → `RegisterFcmTokenUseCase` 호출
- `main.dart` 에서 `FirebaseMessaging.instance.onTokenRefresh.listen()` 등록 → `users/{uid}.fcmToken` update
- 로그아웃 시 → `users/{uid}.fcmToken = null` (또는 array 에서 제거 — 결정 D 참조)

**`fcmTokenUpdatedAt` 추가 여부**: 디버깅/운영 가시성 위해 함께 set 권장. Rules 화이트리스트에 추가 필요:
```
['role', 'displayName', 'photoUrl', 'fcmToken', 'fcmTokenUpdatedAt', 'updatedAt', 'brandId']
```
사용자 확인 필요 — Rules 수정 발생.

### 결정 D. 다중 디바이스 지원 — **(A) Single token (overwrite)** (architect 추천 — MVP 단순화)

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) Single token (overwrite)** (architect 추천 MVP) | 구현 단순. Firestore field 1개 | 사용자가 핸드폰 2대로 로그인 시 마지막 디바이스만 받음 |
| (B) Token array (`fcmTokens: string[]`) | 다중 디바이스 동시 알림 | 토큰 만료/제거 로직 필요. Cloud Function 발송 시 `sendEachForMulticast` |
| (C) 별도 서브컬렉션 (`users/{uid}/fcmTokens/{deviceId}`) | deviceId 별 메타(OS, lastSeen) 관리 가능 | 가장 복잡. 본 phase 과잉 |

채택 = **(A)**. 점주의 핵심 사용 패턴은 "매장에 비치한 단말 1대" 이므로 단순화. 향후 다중 디바이스 필요 시 별 phase 에서 (B) 또는 (C) 로 마이그레이션.

> **단, Rules 가 이미 `fcmToken` (단수) 만 허용하므로 (A) 가 Rules 와도 정합.** (B) 채택 시 `fcmTokens` 필드 신규 추가 + Rules 수정 필수.

### 결정 E. Cloud Function trigger 방식 — **`onDocumentCreated` (신규 주문) + `onDocumentUpdated` (환불 요청)** (architect 추천)

| 동작 | trigger | 이유 |
|---|---|---|
| 신규 주문 알림 | `onDocumentCreated('orders/{orderId}')` | Phase 3a 의 `verifyTossPayment` 가 orders doc 을 status='paid' 로 처음 생성. create 이벤트 = 결제 완료 시점 = 알림 시점. 단순 |
| 환불 요청 알림 | `onDocumentUpdated('orders/{orderId}')` | 환불 요청은 기존 doc 의 `refundRequest` 필드 추가 (O2 분기). diff 검사로 `before.refundRequest == null && after.refundRequest != null` 분기 |

**대안 — `onDocumentWritten` 통합**: 하나의 함수로 처리 가능하나, 분기 로직 복잡 + cold start 빈도 ↑. 별도 2개 함수 권장.

**중복 알림 방지** (`onDocumentUpdated`):
- 환불 요청 trigger 는 `before.refundRequest` 가 null 이고 `after.refundRequest` 가 non-null 일 때만 발송 (재update / 점주 거절 update 는 skip)
- `before.refundRequest != null && after.refundRequest.deniedAt != null` → 점주 거절 케이스 (본 phase 비범위 — 고객 알림은 Phase 3c)

### 결정 F. fcmToken 비어있는 사용자 처리 — **(A) Skip + 구조화된 로그** (architect 추천)

| 옵션 | 처리 |
|---|---|
| **(A) Skip + `console.warn` 구조화 로그** (architect 추천) | 점주가 권한 거부했거나 아직 첫 진입 안 함 — silent. 운영팀이 로그 monitoring 으로 발견 |
| (B) SMS / Email fallback | 본 phase 비범위 (별도 인프라) |
| (C) Firestore `notifications` 컬렉션에 적재 (앱 내 알림함) | 별 phase (알림 히스토리) |

채택 = **(A)**.

**로그 포맷**:
```json
{
  "event": "fcm_token_missing",
  "orderId": "ord_xxx",
  "storeId": "store_xxx",
  "ownerUid": "uid_xxx"
}
```

### 결정 G. 알림 전송 실패 시 재시도 — **(A) FCM SDK 자체 retry 만 신뢰 + 명시적 invalid token 정리** (architect 추천)

| 케이스 | 처리 |
|---|---|
| FCM 일시 장애 (5xx) | FCM SDK 가 자체 재시도. CF 는 throw 안 함 (재실행 방지 — 중복 알림 차단) |
| Invalid token (`messaging/registration-token-not-registered` 등) | CF 가 catch → `users/{ownerUid}.fcmToken = null` clear |
| 기타 오류 | `console.error` 로그만 — CF 는 성공 반환 (Firestore trigger 재실행 차단) |

**원칙**: Firestore trigger 재실행은 **중복 알림** 위험이므로 **거의 모든 오류는 swallow** + 로그만 남김. 본 phase 비범위로 **재시도 큐** 는 만들지 않음.

### 결정 H. 알림 탭 → deep link 구현 방식 — **(A) Navigator 전역 키 + 메시지 데이터 파싱** (architect 추천 — Phase 3a 와 일관)

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) Navigator 전역 키 + `RemoteMessage.data` 파싱** (architect 추천) | Phase 3a 의 `Navigator.push(MaterialPageRoute(...))` 패턴 그대로 유지. 추가 패키지 0 | 전역 key 관리 필요 |
| (B) URI scheme (`qradar://orders/{id}`) | 외부 deep link 호환 | 본 phase 외부 deep link 비범위. 과잉 |
| (C) go_router | 표준화 | Phase 3a 가 `MaterialPageRoute` 유지 결정 — 본 phase 도 일관 |

채택 = **(A)**.

**구현**:
- `main.dart` 에서 `final navigatorKey = GlobalKey<NavigatorState>();` 정의
- `MaterialApp(navigatorKey: navigatorKey, ...)`
- FCM 메시지 핸들러에서 `navigatorKey.currentState?.push(...)` 호출
- 메시지 `data.type` 분기:
  - `'new_order'` / `'refund_request'` → `OrderDetailPage(orderId: data['orderId'])` push (점주 시야)
- 앱 종료 상태에서 알림 탭 (`getInitialMessage`) → splash 끝나고 `RoleRouter` 진입 후 deferred deep link 처리 (NotificationNavigator 가 pending 데이터 보관)

### 결정 I. 알림 메시지 본문 포맷 — **신규 주문**: "신규 주문 · {storeName}" / "{firstItem} 외 {n-1}건 · {totalPrice}원"

```text
[신규 주문]
title: "신규 주문이 들어왔어요"
body:  "{storeName} · {firstItemName}{n>1 ? ' 외 N건' : ''} · {totalPrice.toString().toComma()}원"

[환불 요청]
title: "환불 요청이 도착했어요"
body:  "{storeName} · {firstItemName}{n>1 ? ' 외 N건' : ''} · 사유: {reason.substring(0, 30)}..."
```

> 사용자 확인 — 마케팅/브랜드톤 검토 필요 시 designer 단계에서 조율.

### 결정 J. 앱 상태별 처리 분기

| 앱 상태 | FCM SDK API | 처리 |
|---|---|---|
| **포그라운드** | `FirebaseMessaging.onMessage` 스트림 | (A) 시스템 알림 표시 (iOS 는 기본 미표시 → `setForegroundNotificationPresentationOptions` 호출) + (B) 인앱 SnackBar / 배너 노출 (UX 보강) — **결정 J-1** |
| **백그라운드** (앱 살아있음, 화면 X) | `FirebaseMessaging.onMessageOpenedApp` 스트림 (탭 시) | 알림은 시스템이 자동 표시. 사용자가 탭 시 deep link |
| **종료** (앱 프로세스 X) | `FirebaseMessaging.instance.getInitialMessage()` | 앱 시작 직후 1회 호출. 종료 상태에서 알림 탭 → 앱 실행됨. 메시지 받아 deep link |

**결정 J-1 (포그라운드 인앱 표시)**: architect 잠정 = **시스템 알림만 (B 생략)**. SnackBar/배너 중복은 UX 노이즈. 사용자가 OwnerOrdersPage 에 이미 있으면 stream 으로 신규 주문이 자동 표시되므로 SnackBar 불필요. **사용자 확인 — 알림 강조 원하면 SnackBar 추가**.

### 결정 K. 토큰 등록 / 알림 발송이 Cloud Function 인지 vs 클라이언트 직접 인지 — **(분리)**

| 동작 | 방식 | 이유 |
|---|---|---|
| `users/{uid}.fcmToken` set/clear | **클라이언트 SDK** (직접 Firestore update) | 단순 self profile update. Rules `isSelfProfileUpdate` 가 이미 허용 — CF 불필요 |
| 알림 발송 (`admin.messaging().send(...)`) | **Cloud Function** (Admin SDK) | FCM 발송은 Admin SDK 만 가능. Firestore trigger 로 자동 발동 |

`data_ownership.md` §4 흐름차트 기준:
- fcmToken update → "외부 API 호출 X / 다중 collection X / customer 본인 데이터" → 클라이언트 SDK ✅
- 알림 발송 → "외부 API 호출 O (FCM)" → CF 필수 ✅

### 결정 L. `users/{uid}` 의 `notificationPermissionPrompted` 플래그 — **추가**

| 옵션 | architect 의견 |
|---|---|
| **(A) `users/{uid}` 에 추가** (architect 추천) | Firestore 영속화 → 재로그인 / 디바이스 변경 시에도 유지. Rules 화이트리스트 추가 필요 |
| (B) SharedPreferences 로컬 보관 | 디바이스 reset / 재설치 시 다시 묻게 됨 |
| (C) 권한 거부 시점에 한번만 묻고 더 안 묻기 (네이티브 API) | OS 정책. 사용자 friction 적지만 우리 측 제어 불가 |

채택 = **(A)** — 디바이스 간 일관 + 운영 가시성. Rules `isSelfProfileUpdate` 화이트리스트에 `'notificationPermissionPrompted'` 추가.

### 결정 M. iOS APNs 인증서 — **출시 전 작업으로 보류 (2026-05-30 사용자 결정)**

**본 phase 에서는 iOS APNs 미설정.** App Store 출시 1~2주 전 별도 task 로 진행.

본 phase 범위:
- iOS 네이티브 코드 (AppDelegate / Info.plist / Capabilities) 는 **모두 완성**
- `firebase_messaging` 통합도 iOS / Android 동일하게 구현
- **APNs Auth Key 만 Firebase Console 에 미업로드** 상태
- → Android 푸시는 본 phase 완료 시점부터 작동, iOS 푸시는 APNs 업로드 후 작동

출시 전 작업 체크리스트: **[docs/tasks/ios_apns_setup/spec.md](../ios_apns_setup/spec.md)** 참조.

사용자 결정 사유:
- 미출시 상태라 iOS 사용자 0명 → 즉시 영향 없음
- Apple Developer Program 가입 ($99/년) 은 출시 시점에 어차피 필요
- 코드는 미리 완성해두고 출시 직전 .p8 업로드 만 추가하면 iOS 푸시 즉시 작동
- 발생 가능 리스크 (출시 직전 발견 이슈) 는 출시 1~2주 전 검증으로 흡수

---

## 사용자 확인 항목 (요약)

| # | 항목 | 확정안 | 상태 (2026-05-30) |
|---|---|---|---|
| 1 | 권한 요청 시점 | (B) 점주 첫 OwnerScaffold 진입 시 | ✅ 확정 |
| 2 | payload 구조 | **(B) data-only + `flutter_local_notifications`** | ✅ 확정 |
| 3 | token 갱신 정책 | (A)+(B) 매 로그인 + onTokenRefresh | ✅ 확정 |
| 4 | 다중 디바이스 | (A) Single token (overwrite) | ✅ 확정 |
| 5 | trigger 방식 | onDocumentCreated + onDocumentUpdated 분리 | ✅ 확정 |
| 6 | fcmToken 비어있을 때 | (A) Skip + 로그 | ✅ 확정 |
| 7 | 알림 전송 실패 | (A) FCM SDK retry + invalid token clear, CF 는 swallow | ✅ 확정 |
| 8 | deep link 구현 | (A) Navigator 전역 키 + RemoteMessage.data 파싱 | ✅ 확정 |
| 9 | 알림 본문 포맷 | 결정 I 의 한국어 텍스트 | ✅ 확정 (designer 톤 검토 진행) |
| 10 | 포그라운드 인앱 표시 | 시스템 알림만 (SnackBar 생략) | ✅ 확정 |
| 11 | `notificationPermissionPrompted` 플래그 | `users` 에 추가 + Rules 화이트리스트 갱신 | ✅ 확정 |
| 12 | `fcmTokenUpdatedAt` 필드 추가 | 추가 + Rules 화이트리스트 갱신 | ✅ 확정 |
| 13 | iOS APNs 발급 | **출시 전 작업으로 보류** ([ios_apns_setup](../ios_apns_setup/spec.md)) | ✅ 확정 (보류) |
| 14 | `firebase_messaging` 버전 | latest stable (developer 위임) | ✅ 확정 |

---

## 요구사항

### 기능 요구사항

#### 클라이언트 (Flutter)

- [ ] `firebase_messaging` 패키지 추가 (`pubspec.yaml`)
- [ ] (결정 B 채택 시) `flutter_local_notifications` 패키지 추가
- [ ] `main.dart` 에서 FCM 초기화:
  - `FirebaseMessaging.instance` 준비
  - 백그라운드 핸들러 (`@pragma('vm:entry-point') Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage)`) 최상위 등록 (`FirebaseMessaging.onBackgroundMessage`)
  - `FirebaseMessaging.instance.onTokenRefresh.listen(...)` 등록 → 현재 로그인 사용자 있으면 `RegisterFcmTokenUseCase` 호출
- [ ] 권한 요청:
  - `OwnerScaffold` 첫 진입 시 (또는 진입 직후 build 후 1 frame) `users/{uid}.notificationPermissionPrompted` 확인 → 미설정이면 `NotificationPermissionDialog` 노출
  - 사용자 OK → `FirebaseMessaging.instance.requestPermission(...)` 호출 → 결과(`AuthorizationStatus`)에 따라 토큰 발급 및 등록
  - 권한 응답 후 무조건 `users/{uid}.notificationPermissionPrompted = true` 영속화 (재요청 차단)
- [ ] 로그인 직후 토큰 등록:
  - `AuthNotifier` 의 모든 `signIn*` / `signUpWithEmail` 메서드 success path 에서 → `RegisterFcmTokenUseCase` 호출 (단, 권한 미허용이면 skip)
  - 권한이 있으면 토큰 조회 → 기존 `users/{uid}.fcmToken` 과 비교 → 다르면 update
- [ ] 로그아웃 시 토큰 제거:
  - `AuthNotifier.signOut()` 에서 signOut 호출 **전에** `users/{uid}.fcmToken = null` set (Auth 끊기면 Rules 가 차단)
  - (선택) `FirebaseMessaging.instance.deleteToken()` 호출 — 디바이스 측 토큰도 무효화
- [ ] 메시지 수신 핸들러:
  - `FirebaseMessaging.onMessage` (포그라운드) — 시스템 알림 표시 (iOS: `setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true)`)
  - `FirebaseMessaging.onMessageOpenedApp` (백그라운드 → 탭) — deep link 처리
  - `FirebaseMessaging.instance.getInitialMessage()` (종료 → 탭) — 앱 시작 시 1회 deep link 처리
  - 백그라운드 핸들러: 알림 자체는 시스템이 표시. data-only 모드에서는 `flutter_local_notifications` 로 표시 (결정 B 채택 시)
- [ ] Deep link:
  - `MaterialApp(navigatorKey: appNavigatorKey)` 등록
  - 메시지 `data.type == 'new_order' || 'refund_request'` → `OrderDetailPage(orderId: data['orderId'])` push (점주 시야)
  - 종료 상태에서 알림 탭 → splash + RoleRouter 진입 완료 후 (pending) deep link 처리 (NotificationNavigator 가 pending 보관)

#### Cloud Functions

- [ ] `functions/src/onOrderCreated.ts` 신규
  - trigger: `onDocumentCreated('orders/{orderId}')` (region: `asia-northeast3`)
  - 입력: snapshot.data (이미 status='paid' 인 doc — verifyTossPayment 가 생성)
  - storeId → `stores/{storeId}.ownerId` 조회
  - ownerId → `users/{ownerId}.fcmToken` 조회 (없으면 skip + 로그)
  - `admin.messaging().send({...})` payload (결정 B 스키마) 호출
  - invalid token 오류 시 → `users/{ownerId}.fcmToken = null` clear
- [ ] `functions/src/onOrderRefundRequested.ts` 신규
  - trigger: `onDocumentUpdated('orders/{orderId}')` (region: `asia-northeast3`)
  - 분기: `before.refundRequest == null && after.refundRequest != null` 만 발송 (이외 모두 skip)
  - storeId → ownerId → fcmToken 조회 (동일 패턴)
  - payload `type: 'refund_request'`, `data.reason` 동봉
- [ ] `functions/src/index.ts` 에 export 추가
- [ ] 두 함수 모두 verifyTossPayment 와 동일 region (`asia-northeast3`)

#### Firestore / Security Rules

- [ ] `isSelfProfileUpdate` 화이트리스트에 다음 필드 추가:
  - `fcmTokenUpdatedAt` (결정 C)
  - `notificationPermissionPrompted` (결정 L)
- [ ] (`fcmToken` 은 이미 화이트리스트에 포함됨 — 변경 불필요)
- [ ] Rules 수정 후 `firebase deploy --only firestore:rules`

#### iOS 네이티브

- [ ] `ios/Runner/Info.plist`:
  - 기존 결제 흐름의 URL scheme 유지
  - (필요 시) `FirebaseAppDelegateProxyEnabled = false` — Firebase 가이드 따라
- [ ] `ios/Runner.xcodeproj` Capabilities:
  - `Push Notifications` 추가
  - `Background Modes` → `Remote notifications` 체크
- [ ] `ios/Runner/AppDelegate.swift`:
  - `import UserNotifications` / `import FirebaseMessaging` 등 (Firebase 가이드)
  - `UNUserNotificationCenter.current().delegate = self` 등록
  - `Messaging.messaging().delegate = self` 등록
- [ ] APNs Auth Key Firebase Console 업로드 (**사용자 manual 작업**)

#### Android 네이티브

- [ ] `android/app/src/main/AndroidManifest.xml`:
  - `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` (Android 13+)
  - `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="qradar_orders" />`
  - (선택) default icon, color 메타
- [ ] Android 13+ 런타임 권한 요청 — `firebase_messaging` 의 `requestPermission()` 호출이 OS-native dialog 자동 트리거 (Flutter SDK 가 처리)

### UI 요구사항

- [ ] `NotificationPermissionDialog` (designer 산출)
  - 아이콘 (알림 모양)
  - 본문: "주문이 들어오면 바로 알려드릴게요. 알림 권한을 허용해주세요."
  - 버튼: "허용" / "나중에"
  - 사용자 선택과 무관하게 다이얼로그 닫히면 `notificationPermissionPrompted = true` 영속화

### 상태 요구사항

| 화면 | loading | error | empty |
|---|---|---|---|
| OwnerScaffold (권한 다이얼로그 트리거) | 권한 요청 중 → 비동기 (다이얼로그가 막음) | 토큰 발급 실패 → silent 로그, UI 영향 없음 | — |
| NotificationPermissionDialog | — | — | — |

---

## 데이터 모델

### Entity 수정

#### `UserEntity` (수정)
| 필드 | 타입 | 설명 |
|---|---|---|
| (기존) uid, email, displayName, photoUrl, provider, role, createdAt, brandId | — | 변경 없음 |
| **fcmToken** (신규) | `String?` | FCM 디바이스 토큰. null 가능 (권한 거부 / 미발급) |
| **fcmTokenUpdatedAt** (신규) | `DateTime?` | 마지막 토큰 갱신 시각 (운영 가시성) |
| **notificationPermissionPrompted** (신규) | `bool` (default false) | 권한 다이얼로그 노출 이력 (재요청 방지) |

#### `UserModel` (수정)
- `UserModelFactory.fromFirestore` / `toFirestoreForCreate` / `toEntity` 모두 신규 필드 매핑 추가
- `toFirestoreForCreate` 는 신규 가입 시점이므로 `fcmToken` / `fcmTokenUpdatedAt` 는 set 안 함 (가입 시 `users.create` Rules 가 `brandId` 만 차단 — 다른 필드는 자유. 다만 본 phase 는 가입 직후 fcmToken 등록 안 함 — 권한 흐름 후 별도 update)
- 신규 필드 update 전용 메서드: `UserRemoteDataSource.updateFcmToken(uid, token, updatedAt)` / `markNotificationPermissionPrompted(uid)`

### Firestore 컬렉션 구조 (변경분)

```
users/{uid}
  ...기존 필드
  fcmToken: string?                            # 본 phase 추가
  fcmTokenUpdatedAt: Timestamp?                # 본 phase 추가
  notificationPermissionPrompted: boolean      # 본 phase 추가 (default false)
```

---

## 레이어 설계

### Domain (`lib/domain/`)

**Entities (수정)**:
- `entities/user_entity.dart` — 위 3개 필드 추가 (freezed 재생성 필요)

**Repository Interface (신규)**:
- `repositories/push_notification_repository.dart`
  - `Future<NotificationPermissionStatus> requestPermission()` — 권한 요청
  - `Future<NotificationPermissionStatus> getPermissionStatus()` — 현재 권한
  - `Future<String?> getToken()` — 현재 FCM 토큰 (권한 없으면 null)
  - `Stream<String> onTokenRefresh()` — 토큰 갱신 스트림
  - `Future<void> deleteToken()` — 디바이스 측 토큰 무효화
  - `Stream<RemoteNotificationMessage> onMessage()` — 포그라운드 메시지
  - `Stream<RemoteNotificationMessage> onMessageOpenedApp()` — 백그라운드 탭
  - `Future<RemoteNotificationMessage?> getInitialMessage()` — 종료 → 탭
  - `Future<void> setForegroundNotificationPresentationOptions(...)`

**Repository Interface (수정)**:
- `repositories/auth_repository.dart` — 변경 없음 (fcmToken 관리는 `PushNotificationRepository` 와 `UserRepository` 가 담당)
- (신규 또는 기존) `repositories/user_repository.dart` — `updateFcmToken`, `clearFcmToken`, `markNotificationPermissionPrompted` 메서드 추가
  - **확인 필요**: 현재 `UserRepository` 가 별도로 존재하는지. 없으면 본 phase 에서 신설 vs 기존 AuthRepository 에 메서드 추가 (architect 추천 = 신설 — 책임 분리)

**UseCases (신규)**:
- `domain/usecases/register_fcm_token_use_case.dart` — 토큰 발급 + Firestore update (권한 체크 포함)
- `domain/usecases/clear_fcm_token_use_case.dart` — 로그아웃 시
- `domain/usecases/request_notification_permission_use_case.dart` — 권한 요청 + 결과 영속화
- `domain/usecases/handle_notification_message_use_case.dart` — RemoteNotificationMessage → deep link 라우팅 데이터 변환

**Domain Value Objects (신규)**:
- `domain/entities/notification_permission_status.dart` — enum (`authorized`, `denied`, `provisional`, `notDetermined`)
- `domain/entities/remote_notification_message.dart` — `{type, orderId, storeId, title, body, data}` (외부 SDK 의존 차단 — `RemoteMessage` 를 domain layer 가 알지 않게 wrapping)
  - `type` 은 `enum NotificationType { newOrder, refundRequest, unknown }`

### Data (`lib/data/`)

**Models (수정)**:
- `models/user_model.dart` — 3개 필드 추가 + `UserModelFactory.fromFirestore` / `toEntity` 매핑

**DataSources (신규)**:
- `datasources/remote/fcm_remote_data_source.dart`
  - `firebase_messaging` SDK 직접 wrap
  - `Future<AuthorizationStatus> requestPermission()`
  - `Future<AuthorizationStatus> getPermissionStatus()`
  - `Future<String?> getToken()`
  - `Stream<String> onTokenRefresh()`
  - `Future<void> deleteToken()`
  - `Stream<RemoteMessage> onMessage()`
  - `Stream<RemoteMessage> onMessageOpenedApp()`
  - `Future<RemoteMessage?> getInitialMessage()`
  - `Future<void> setForegroundNotificationPresentationOptions(...)`
- (수정) `datasources/remote/user_remote_data_source.dart` — 다음 메서드 추가:
  - `Future<void> updateFcmToken(String uid, String? token)` — `fcmToken`, `fcmTokenUpdatedAt`, `updatedAt` 3개 필드 update
  - `Future<void> markNotificationPermissionPrompted(String uid)`
  - `Future<bool> getNotificationPermissionPrompted(String uid)`

**Repository Implementation (신규)**:
- `repositories/push_notification_repository_impl.dart` — `FcmRemoteDataSource` + `UserRemoteDataSource` 조합
- (신규 또는 수정) `repositories/user_repository_impl.dart` — 신설 or 기존 확장

### Presentation

**Pages 수정**:
- `main.dart`:
  - `WidgetsFlutterBinding.ensureInitialized()` 후 FCM 초기화
  - `FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler)` (top-level 함수)
  - `MaterialApp(navigatorKey: appNavigatorKey, ...)`
  - `ProviderScope` 외부에서 `runApp` 호출 전에 background handler 등록
- `lib/presentation/owner/owner_scaffold.dart` (또는 본 phase 에서 hook 진입점 결정):
  - `initState` 또는 첫 build 직후 `WidgetsBinding.instance.addPostFrameCallback` 으로 권한 다이얼로그 트리거 체크 (1 frame 지연으로 build cycle 방해 X)
- `lib/presentation/customer/auth/auth_provider.dart`:
  - `AuthNotifier` 의 모든 `signIn*` / `signUp*` success path 에서 `ref.read(registerFcmTokenUseCaseProvider).call()` 호출 (silently ignore failure)
  - `signOut` 에서 `clearFcmTokenUseCase` 호출 → `firebase signOut`

**Pages 신규**:
- `lib/presentation/common/notification/notification_permission_dialog.dart`
- `lib/presentation/common/notification/notification_navigator.dart` — 메시지 데이터 → Navigator 라우팅
- `lib/presentation/common/notification/pending_notification_holder.dart` — 종료 상태 진입 시 deferred 처리용

**Providers 신규**:
- `lib/presentation/common/notification/providers/notification_providers.dart`
  - `fcmRemoteDataSourceProvider`
  - `pushNotificationRepositoryProvider`
  - `registerFcmTokenUseCaseProvider`
  - `clearFcmTokenUseCaseProvider`
  - `requestNotificationPermissionUseCaseProvider`
  - `handleNotificationMessageUseCaseProvider`
  - `appNavigatorKeyProvider` (or top-level final `appNavigatorKey`)

---

## 데이터 흐름

### A. 점주 첫 OwnerScaffold 진입 → 권한 요청 → 토큰 등록

```
[Owner 로그인 후 RoleRouter → OwnerScaffold 첫 진입]
OwnerScaffold.initState
  → WidgetsBinding.addPostFrameCallback
  → ref.read(userRepositoryProvider).getNotificationPermissionPrompted(uid)
  → if false:
       showDialog(NotificationPermissionDialog)
       → user "허용"
         → ref.read(requestNotificationPermissionUseCaseProvider).call()
              → PushNotificationRepository.requestPermission() (FCM SDK)
              → if authorized:
                  → registerFcmTokenUseCase.call()
                    → token = PushNotificationRepository.getToken()
                    → UserRepository.updateFcmToken(uid, token)  // Firestore self update (Rules 통과)
       → user "나중에" 또는 OS 다이얼로그 거부
         → (토큰 등록 skip)
       → 무조건: UserRepository.markNotificationPermissionPrompted(uid)
```

### B. 매 로그인 시 토큰 자동 갱신

```
[로그인 성공 후 AuthNotifier.signIn* success]
ref.read(registerFcmTokenUseCaseProvider).call()
  → PushNotificationRepository.getPermissionStatus()
  → if authorized:
      → getToken() → UserRepository.updateFcmToken(uid, token)
  → else: skip (권한 거부 상태)
```

### C. FCM SDK onTokenRefresh

```
[main.dart 초기화]
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return; // 로그인 전 → skip
  UserRepository.updateFcmToken(uid, newToken);
});
```

### D. 신규 주문 → CF trigger → 점주 알림

```
[Customer 결제 완료]
verifyTossPayment (Phase 3a CF)
  → orders/{orderId} create (status='paid')
  → CF 완료

[Firestore trigger 발화]
onOrderCreated (onDocumentCreated, asia-northeast3)
  → snapshot.data 로 orderId, storeId, items, totalPrice 추출
  → stores/{storeId} read → ownerId 획득
  → users/{ownerId} read → fcmToken 획득
  → if fcmToken == null:
      → console.warn({event: 'fcm_token_missing', orderId, storeId, ownerUid})
      → return (skip)
  → payload 구성 (결정 B 스키마)
  → admin.messaging().send(payload)
  → if invalid token error:
      → users/{ownerId}.fcmToken = null (clear)
```

### E. 환불 요청 → CF trigger → 점주 알림

```
[Customer 환불 요청]
OrderDetailPage → orderRepository.requestRefund(orderId, reason)
  → orders/{orderId} update (refundRequest = {reason, requestedAt}, updatedAt)
  → (O2 Rules 통과)

[Firestore trigger 발화]
onOrderRefundRequested (onDocumentUpdated, asia-northeast3)
  → before.refundRequest == null && after.refundRequest != null 분기 확인
  → 아니면 skip
  → 맞으면: ownerId → fcmToken → admin.messaging().send(...)
```

### F. 알림 수신 + 탭 → deep link

```
[포그라운드]
FirebaseMessaging.onMessage.listen((msg) {
  // 시스템 알림 (iOS: setForegroundNotificationPresentationOptions 으로 자동 표시)
  // 본 phase: 인앱 SnackBar 미표시 (결정 J-1)
});

[백그라운드 → 사용자 알림 탭]
FirebaseMessaging.onMessageOpenedApp.listen((msg) {
  HandleNotificationMessageUseCase.call(msg) → NotificationNavigator.navigate(msg.data)
});

[종료 → 사용자 알림 탭]
main.dart:
  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    PendingNotificationHolder.set(initialMsg); // splash → RoleRouter 완료 후 처리
  }
RoleRouter (또는 splash 완료 시점):
  final pending = PendingNotificationHolder.consume();
  if (pending != null) NotificationNavigator.navigate(pending);

NotificationNavigator:
  switch (data.type) {
    case 'new_order':
    case 'refund_request':
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: data.orderId, viewMode: OrderDetailViewMode.owner))
      );
  }
```

### G. 로그아웃 시 토큰 정리

```
AuthNotifier.signOut()
  → uid = currentUser.uid
  → UserRepository.updateFcmToken(uid, null)  // Rules: 본인 update 통과
  → PushNotificationRepository.deleteToken()  // 디바이스 측 invalidation
  → FirebaseAuth.instance.signOut()
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 사용자가 권한 요청 거부 | `notificationPermissionPrompted=true` 영속화 → 재요청 안 함. 별도 UI 변경 없음 (앱 정상 동작). 향후 별 phase 의 알림 설정 화면에서 재요청 경로 추가 |
| iOS 시뮬레이터 / Android 에뮬레이터에서 실행 | 시뮬레이터는 push 미지원. 토큰 발급 실패 가능 → silent skip. 테스트는 실기기 |
| FCM 토큰 발급 실패 (네트워크) | `getToken()` 이 null 또는 throw → silent log, UI 영향 없음. onTokenRefresh 가 추후 발화 |
| Firestore `users/{uid}.fcmToken` update 실패 (네트워크) | silent retry 1회 → 실패 시 log only. onTokenRefresh / 다음 로그인 시 재시도 |
| Cloud Function 의 `stores/{storeId}` read 실패 (deleted store 등) | log + skip 알림 |
| Cloud Function 의 `users/{ownerId}` read 실패 | log + skip 알림 |
| `admin.messaging().send()` 의 `messaging/registration-token-not-registered` | catch → `users/{ownerId}.fcmToken = null` clear. 다음 로그인 / onTokenRefresh 시 재등록 |
| `admin.messaging().send()` 의 기타 오류 | log only. CF 는 success return (trigger 재실행 차단) |
| 동일 doc 이 빠르게 두 번 update 되어 trigger 두 번 발화 (이론상) | 두 번째 trigger 에서 `before.refundRequest != null` 이므로 자동 skip (결정 E 의 분기) |
| 종료 상태 알림 탭 → 앱 시작 → 로그인 안 된 사용자 | `PendingNotificationHolder` 가 들고 있다가 LoginPage 노출 → 로그인 후 RoleRouter 진입 시 처리 (드문 케이스). 또는 단순 drop |
| 알림 탭 → OrderDetailPage 진입했지만 해당 orderId 권한 없음 (점주가 아닌 매장 주문) | OrderDetailPage 가 Firestore stream error → 기존 에러 UI 활용 |
| 백그라운드 핸들러에서 Riverpod ref 접근 불가 | 백그라운드 핸들러는 별도 Isolate. `Firebase.initializeApp()` 만 호출하고 UI 갱신은 안 함. data-only 모드에서 `flutter_local_notifications` 만 표시 |
| OS 알림 채널 미생성 (Android) | `firebase_messaging` SDK 가 기본 채널 자동 생성. 단, 우리는 `qradar_orders` 채널을 manifest 메타로 명시 |
| 다중 로그아웃-로그인 race (토큰 정리 중 새 로그인) | signOut 의 fcmToken=null 이 새 로그인의 토큰 update 보다 늦게 도착하는 race — 본 phase 비범위 (희소 케이스, onTokenRefresh 가 결과적으로 복구) |

---

## 보안 / 환경 설정

### Cloud Functions

- 신규 함수도 `region: 'asia-northeast3'` 일관 (Phase 3a 와 동일)
- `admin.messaging()` 은 default credentials 사용 (functions 환경에서 자동)
- Functions 의 IAM: `roles/firebasemessaging.admin` (default firebase-functions service account 가 이미 보유 — 확인 필요)

### Firestore Rules 변경

`isSelfProfileUpdate` 의 `onlyChangedFields` 확장:

```diff
- onlyChangedFields(['role', 'displayName', 'photoUrl', 'fcmToken', 'updatedAt', 'brandId'])
+ onlyChangedFields([
+   'role', 'displayName', 'photoUrl',
+   'fcmToken', 'fcmTokenUpdatedAt', 'notificationPermissionPrompted',
+   'updatedAt', 'brandId'
+ ])
```

`firebase deploy --only firestore:rules` 필요.

### iOS 환경

- Apple Developer 계정에서 APNs Authentication Key (`.p8`) 발급 (사용자 manual)
- Firebase Console → Project Settings → Cloud Messaging → "Apple app configuration" → `.p8` 업로드 + Key ID + Team ID
- Xcode → Runner target → Signing & Capabilities:
  - `+ Capability` → `Push Notifications`
  - `+ Capability` → `Background Modes` → `Remote notifications` 체크
- Provisioning Profile 갱신 필요 시 자동 (Xcode managed)

### Android 환경

- `google-services.json` 확인 (이미 있을 가능성 — Phase 1 Firebase 설정 시 추가됨)
- `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  <application>
    <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="qradar_orders" />
    <meta-data
      android:name="com.google.firebase.messaging.default_notification_icon"
      android:resource="@mipmap/ic_launcher" />
    <!-- (선택) default color -->
  </application>
  ```
- Android 13+ 런타임 권한은 `firebase_messaging` 의 `requestPermission()` 이 자동 처리

### FCM 토큰 보안

- FCM 토큰은 **민감 정보** — 탈취 시 임의 사용자에게 알림 발송 가능
- Firestore `users/{uid}` 의 `read` 권한이 `self || admin` 이므로 본인/관리자만 read → 안전
- 토큰을 클라이언트 로그에 출력 금지 (`debugPrint` 등)

### Cloud Function 권한 재검증

- `onOrderCreated` / `onOrderRefundRequested` 는 trigger 기반이라 사용자 권한 검증 X (Firestore 가 이미 검증한 상태에서 발화). 추가 검증 불필요
- 단, store/user doc read 실패 시 throw 하지 말고 log + return (재실행 차단)

---

## 테스트 시나리오

### T1 — 점주 첫 OwnerScaffold 진입 시 권한 다이얼로그 노출
- 신규 owner 계정 (또는 `notificationPermissionPrompted == false` reset)
- OwnerScaffold 진입 → NotificationPermissionDialog 표시
- 사용자 "허용" → OS 권한 다이얼로그 → 허용 → `users/{uid}.fcmToken` set 확인

### T2 — 권한 거부 / "나중에" 선택 시 재요청 안 함
- T1 후 사용자 "나중에" 또는 OS "거부"
- `users/{uid}.notificationPermissionPrompted = true` 영속화
- 앱 재시작 → OwnerScaffold 진입 → 다이얼로그 노출 X

### T3 — 로그인 시 fcmToken 자동 등록
- 권한 있는 사용자가 로그아웃 → 재로그인
- `users/{uid}.fcmToken` 이 최신 토큰으로 update 확인

### T4 — 로그아웃 시 fcmToken null clear
- 로그아웃 → Firestore `users/{uid}.fcmToken == null` 확인
- 디바이스 측 `FirebaseMessaging.instance.getToken()` 호출 시 새 토큰 발급되는지 확인

### T5 — onTokenRefresh 시 자동 update
- 디바이스 측에서 `FirebaseMessaging.instance.deleteToken()` 강제 호출 후 `getToken()`
- onTokenRefresh 발화 → `users/{uid}.fcmToken` update 확인

### T6 — 신규 주문 → 점주 푸시 수신 (포그라운드)
- 점주가 앱 포그라운드 상태
- 고객이 결제 완료 (Phase 3a 흐름)
- `onOrderCreated` 발화 → 점주 디바이스에 시스템 알림 표시 (iOS/Android)
- 탭 시 OrderDetailPage 진입 확인

### T7 — 신규 주문 → 점주 푸시 수신 (백그라운드)
- 점주가 앱 백그라운드 (홈 화면)
- 결제 → 알림 표시 → 탭 → 앱 복귀 + OrderDetailPage 진입

### T8 — 신규 주문 → 점주 푸시 수신 (앱 종료)
- 점주 앱 종료 (kill)
- 결제 → 알림 표시 → 탭 → 앱 시작 → splash 완료 후 OrderDetailPage 진입

### T9 — 환불 요청 → 점주 푸시 수신
- 점주 매장의 주문 status='accepted' 상태
- 고객이 환불 요청 (OrderDetailPage)
- `onOrderRefundRequested` 발화 → 점주 알림 표시
- 탭 → OrderDetailPage (refundRequest 표시)

### T10 — 환불 거절 update 시 알림 발송 안 함 (중복 방지)
- 환불 요청 후 점주 거절 (refundRequest.deniedAt set)
- `onOrderRefundRequested` trigger 발화는 일어나지만 `before.refundRequest != null` 분기로 알림 skip 확인 (Cloud Function 로그 검증)

### T11 — fcmToken 없는 점주에게 결제 발생 시 silent skip
- 권한 거부한 owner 의 매장 주문
- CF 로그에 `event: 'fcm_token_missing'` 기록 + 알림 발송 안 됨

### T12 — Invalid token (만료) 시 자동 정리
- `users/{ownerId}.fcmToken` 에 인위적으로 invalid token 주입 (테스트용)
- 결제 → CF 실행 → `messaging/registration-token-not-registered` → `fcmToken` clear 확인

### T13 — 동일 매장에 다른 결제 두 건 빠르게 발생
- 두 건 모두 알림 수신 확인

### T14 — Cloud Function region / cold start
- `asia-northeast3` 배포 확인
- cold start 시 2~5s 지연 허용 (FCM 도착 시점)

### T15 — Rules 변경 후 기존 동작 회귀 검증
- `fcmTokenUpdatedAt`, `notificationPermissionPrompted` 화이트리스트 추가가 기존 fcmToken update / brandId update / role 전이 등을 깨지 않는지 확인
- 점주 로그인 → fcmToken update → 성공
- customer → owner 전환 → 성공 (회귀 없음)

### T16 — 백그라운드 핸들러가 Riverpod 의존성 없이 동작
- (자동 검증 어려움 — 실기기 + 종료 상태 알림 수동)

### T17 — Firestore Rules 단위 (Firebase emulator)
- `users/{uid}` update with `fcmToken` 만 → 통과
- `users/{uid}` update with `fcmTokenUpdatedAt` 만 → 통과
- `users/{uid}` update with `notificationPermissionPrompted` 만 → 통과
- `users/{uid}` update with `fcmToken` + 임의 필드 (예: `provider`) → 거부

---

## 작업 분배

### designer

- **UI 변경 여부**: 있음 (소규모)
- **디자인 산출물 (`design.md`)**:
  - `NotificationPermissionDialog` 디자인 (Qradar 톤 — 밝은 캔버스 + 미드나잇 네이비 포인트). 아이콘 + 본문 + 버튼 2개 ("허용" / "나중에"). 기존 다이얼로그 패턴(예: 환불 요청 다이얼로그) 재사용 권장
  - (확정 후) 알림 본문 텍스트 마이크로카피 검토 (결정 I)
- **전달할 사항**:
  - `NotificationPermissionDialog` 노출 진입점은 `OwnerScaffold` 진입 시 1회. 재요청 없음
  - 결정 J-1 의 포그라운드 시 SnackBar/배너 표시 여부 — designer 의견 반영
  - 사용자 결정 항목 #9 (알림 본문 포맷) 마무리

### developer

- **구현 항목 (요약)**:
  - `firebase_messaging` 패키지 설치 + (결정 B 채택 시) `flutter_local_notifications` 설치
  - Domain: `PushNotificationRepository` 인터페이스, UseCase 4개, `NotificationPermissionStatus` enum, `RemoteNotificationMessage` value object
  - Data: `FcmRemoteDataSource`, `PushNotificationRepositoryImpl`, `UserRemoteDataSource` 확장, `UserModel` 확장 (fcmToken / fcmTokenUpdatedAt / notificationPermissionPrompted) + freezed 재생성
  - Presentation: `main.dart` 수정 (FCM 초기화 + 백그라운드 핸들러 + navigatorKey), `OwnerScaffold` 권한 다이얼로그 hook, `AuthNotifier` signIn/signOut 토큰 등록/정리, `NotificationPermissionDialog` 위젯, `NotificationNavigator` + `PendingNotificationHolder`, `notification_providers.dart`
  - Cloud Functions: `onOrderCreated.ts`, `onOrderRefundRequested.ts`, `index.ts` export 추가
  - Firestore Rules 수정 + deploy
  - iOS: `AppDelegate.swift` 수정, Capabilities 추가, APNs Auth Key (사용자 발급 후 Firebase Console 업로드)
  - Android: `AndroidManifest.xml` 수정 (POST_NOTIFICATIONS, FCM 메타)
- **재사용할 기존 구조**:
  - Phase 3a 의 `OrderRepository` 그대로 활용 (변경 없음)
  - `verifyTossPayment` / `processRefund` 등 기존 CF 변경 없음 (Firestore trigger 가 decouple)
  - Phase 1c 의 `UserRemoteDataSource` 확장 (`updateFcmToken` 등 메서드 추가)
  - `RoleRouter` 가 OwnerScaffold 라우팅 책임 — 권한 다이얼로그 hook 은 `OwnerScaffold.initState`
- **주의할 레이어 규칙**:
  - `firebase_messaging` 은 **data layer 에서만 import** — domain / presentation 은 wrapping value object (`RemoteNotificationMessage`) 만 사용 (CLAUDE.md 절대 규칙 2)
  - 백그라운드 핸들러는 top-level 함수 + `@pragma('vm:entry-point')` 필수 (별 isolate). Riverpod ref 접근 금지
  - `appNavigatorKey` 는 `main.dart` 의 top-level final + `MaterialApp` 에 주입
  - 색상은 `AppColors` 만 (CLAUDE.md 절대 규칙 3)
  - 환경 변수 / Secret 은 `--dart-define` (현재 phase 신규 secret 없음, APNs 키는 Firebase Console 보관)

### tester

- **주요 검증 기준**:
  - T1~T17 시나리오 PASS
  - 특히 T6/T7/T8 (포그라운드/백그라운드/종료) 의 알림 수신 + deep link 동작 — **실기기** 필수
  - T10 (중복 알림 방지) — Cloud Function 로그로 검증
  - T15/T17 (Rules 회귀) — Firebase emulator + 실제 디바이스 update 양쪽
- **반드시 확인할 예외 케이스**:
  - 권한 거부 사용자가 결제 발생 시 silent skip (T11)
  - Invalid token clear (T12)
  - 환불 거절 / 점주 접수 등의 다른 orders update 가 푸시 발송 trigger 안 함
  - 시뮬레이터에서 토큰 발급 실패 시 앱 정상 동작
  - 다른 role (customer, brand, admin) 은 권한 다이얼로그 노출 X
  - 로그아웃 → fcmToken null + 디바이스 토큰 무효화

---

## 완료 기준

- [ ] 사용자 결정 항목 1~14 확정
- [ ] iOS APNs Auth Key Firebase Console 업로드 (**사용자**)
- [ ] `firebase_messaging` 패키지 설치 + `pubspec.yaml` 커밋
- [ ] Firestore Rules `isSelfProfileUpdate` 확장 + deploy
- [ ] `UserEntity` / `UserModel` 신규 3필드 추가 + freezed 재생성
- [ ] `PushNotificationRepository` + Impl + UseCase 신규
- [ ] `FcmRemoteDataSource` 구현
- [ ] `UserRemoteDataSource` 확장
- [ ] `main.dart` FCM 초기화 + navigatorKey + 백그라운드 핸들러
- [ ] `OwnerScaffold` 권한 다이얼로그 hook
- [ ] `AuthNotifier` signIn/signOut 토큰 등록/정리
- [ ] `NotificationPermissionDialog` 위젯
- [ ] `NotificationNavigator` + deep link 라우팅
- [ ] Cloud Functions `onOrderCreated`, `onOrderRefundRequested` 신규 + deploy
- [ ] iOS Capabilities + AppDelegate 수정
- [ ] Android Manifest 수정
- [ ] `design.md` 작성 완료 (designer)
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester)
- [ ] FAIL 항목 없거나 후속 task 로 분리됨

---

## 참고 문서

- [CLAUDE.md](../../../CLAUDE.md) — 절대 규칙
- [docs/architecture.md](../../architecture.md) — Clean Architecture 기준
- [docs/processes/role_flows.md](../../processes/role_flows.md) — owner 진입 흐름 (`OwnerScaffold`)
- [docs/processes/entity_lifecycle.md](../../processes/entity_lifecycle.md) — order lifecycle (paid / refundRequest)
- [docs/processes/data_ownership.md](../../processes/data_ownership.md) — CF vs 클라이언트 결정 흐름차트
- [docs/tasks/order_flow_phase3a/spec.md](../order_flow_phase3a/spec.md) — Phase 3a 결제 흐름 (trigger 의 source)
- [firestore.rules](../../../firestore.rules) — 현재 보안 규칙 (특히 `isSelfProfileUpdate`)
- [functions/src/verifyTossPayment.ts](../../../functions/src/verifyTossPayment.ts) — orders create 시점
- [lib/domain/entities/user_entity.dart](../../../lib/domain/entities/user_entity.dart) — 확장 대상
- [lib/data/models/user_model.dart](../../../lib/data/models/user_model.dart) — 확장 대상
- Firebase 공식: <https://firebase.google.com/docs/cloud-messaging/flutter/client>, <https://firebase.google.com/docs/cloud-messaging/flutter/receive>
