# Qradar Data Ownership

이 문서는 Firestore 컬렉션별 **데이터 소유권** 과 **read / create / update / delete 권한** 을 한 곳에 정리한다.

**목적**: 새 feature 설계 시 "이 동작이 client SDK 로 가능한가, Cloud Function 이 필요한가?" 를 즉시 판단.

**단일 진실원**: [`firestore.rules`](../../firestore.rules). 이 문서는 그 요약 + 코드 매핑.

**범위 분리**:
- 엔티티 status 전이 + 갱신 필드 → [`entity_lifecycle.md`](./entity_lifecycle.md)
- 역할별 진입점 / 액션 카탈로그 → [`role_flows.md`](./role_flows.md)

---

## 1. 표기 약속

| 표기 | 의미 |
|---|---|
| `isSignedIn()` | 로그인 사용자 누구나 |
| `self(uid)` | `request.auth.uid == userId` |
| `owner` | `users.role == 'owner'` (Rules `isOwner()`) |
| `brand` | `users.role == 'brand'` (Rules `isBrand()`) |
| `admin` | `users.role == 'admin'` (Rules `isAdmin()`) |
| `storeOwner(storeId)` | `stores/{storeId}.ownerId == uid` (Rules `isStoreOwner`) |
| `brandHolder(brandId)` | `brand AND users.brandId == brandId` (Rules `isBrandHolder`) |
| 🔒 | `if false` — 클라이언트 직접 차단 |
| 🛠 CF | Cloud Function (Admin SDK) 가 우회하여 수행 |
| ✅ 허용 | Rules 통과 |
| ❌ 차단 | Rules 거부 |

---

## 2. 컬렉션별 권한 매트릭스

### 2.1 `users/{userId}`

| 작업 | 허용 | 필드 / 제약 |
|---|---|---|
| read | `self(uid) OR admin` | 모든 필드 |
| create | `self(uid)` | **`role == 'customer'` 강제**, **`brandId` 필드 동시 포함 금지** (가입 시점 brandId 차단) |
| update | `admin (전권) OR self(uid)` self 케이스: `onlyChangedFields(['role', 'displayName', 'photoUrl', 'fcmToken', 'fcmTokenUpdatedAt', 'notificationPermissionPrompted', 'notificationPermissionLaterCount', 'notificationSettings', 'updatedAt', 'brandId'])` + role 전이 화이트리스트 + `brandId` 는 empty→value 1회만 | 변경 가능: displayName, photoUrl, fcmToken, fcmTokenUpdatedAt, notificationPermissionPrompted(OS 권한 시트 소진 = 다이얼로그 `허용` 선택 시에만 true), notificationPermissionLaterCount(`나중에` 선택 횟수, `FieldValue.increment(1)`, 부재 시 0), notificationSettings(bool map, dot-path), role(허용 전이), brandId(최초 1회) |
| delete | `admin` | — |
| Cloud Function 전담 | 없음 (모든 작업 클라이언트에서 가능) | — |

**role 자가 전이 허용** ([`role_flows.md §3`](./role_flows.md) 참조): customer ↔ owner ↔ brand 임의 방향. admin 으로의 전이는 **모든 방향 차단**.

**brandId 정책**:
- 가입 시점 set 금지 (`users.create`)
- 본인 update 로 `'' → value` 1회만 허용 (`isSelfProfileUpdate`)
- 한번 set 되면 본인이 재변경 불가 (admin 만 가능)
- ⚠️ **재설계 후보**: brand role 다운그레이드 후 다시 brand 신청 시 새 brand doc 생성 불가능.

### 2.2 `users/{userId}/orderLogs/{logId}`

| 작업 | 허용 | 비고 |
|---|---|---|
| read | `self(uid) OR admin` | — |
| create | 🔒 (모두 차단) | **🛠 CF `verifyTossPayment` 만 batch 로 생성** |
| update | 🔒 | 동일 (CF 만) |
| delete | `admin` | — |

**Cloud Function 전담**: `verifyTossPayment` 가 `orders/{orderId}` 생성과 동시에 `users/{uid}/orderLogs/{logId}` 도 batch write. 클라이언트는 절대 직접 생성/수정 불가.

### 2.3 `users/{userId}/favoriteStores/{storeId}` & `/favoriteMenuItems/{compositeId}`

| 작업 | 허용 |
|---|---|
| read, create, update, delete | `self(uid)` |

본인 전용. admin 도 명시적으로 허용되지 않음 (확인 필요 — 관리 차원에서 admin 접근이 필요할 수 있음).

### 2.4 `orders/{orderId}`

| 작업 | 허용 | 비고 |
|---|---|---|
| read | `userId == uid (본인)` OR `storeOwner(storeId)` OR `admin` | 고객/점주/관리자 |
| create | 🔒 | **🛠 CF `verifyTossPayment` 만** |
| update | `admin (전권 O4)` OR `isOwnerAcceptUpdate (O1)` OR `isCustomerRefundRequest (O2)` OR `isOwnerDenyRefund (O3)` OR `isOwnerStartMakingUpdate (O5)` OR `isOwnerMarkReadyUpdate (O6)` OR `isOwnerCompletePickupUpdate (O7)` | 7개 분기 — 상세는 §2.4.1 |
| delete | `admin` | — |
| Cloud Function 전담 | `verifyTossPayment` (생성), `cancelTossPayment` (paid→cancelled), `processRefund` (accepted+→refunded) | PG 호출 + status 전이 동시 |

#### 2.4.1 `orders.update` 7개 분기

| 분기 | 조건 | 허용 변경 필드 |
|---|---|---|
| O1 (점주 접수) | `storeOwner(storeId)` + `resource.status == 'paid'` + `request.status == 'accepted'` | `status`, `acceptedAt`, `updatedAt` |
| O2 (고객 환불 요청) | `userId == uid` + `resource.status == 'accepted'` + `refundRequest == null OR deniedAt == null` | `refundRequest` (내부 필드 `reason`, `requestedAt` 만), `updatedAt` |
| O3 (점주 환불 거절) | `storeOwner(storeId)` + `refundRequest != null` + `deniedAt == null` | `refundRequest` (내부 필드 `reason`, `requestedAt`, `deniedAt`, `deniedReason` 만), `updatedAt` |
| O4 (admin 전권) | `admin` | 모든 필드 |
| O5 (점주 조리 시작) | `storeOwner(storeId)` + `resource.status == 'accepted'` + `request.status == 'making'` | `status`, `makingStartedAt`, `updatedAt` |
| O6 (점주 준비 완료) | `storeOwner(storeId)` + `resource.status == 'making'` + `request.status == 'ready'` | `status`, `readyAt`, `updatedAt` |
| O7 (점주 픽업 완료) | `storeOwner(storeId)` + `resource.status == 'ready'` + `request.status == 'completed'` | `status`, `completedAt`, `updatedAt` |

#### 2.4.2 클라이언트 SDK vs Cloud Function 결정

| 동작 | 결정 | 이유 |
|---|---|---|
| 주문 생성 (결제 성공) | 🛠 CF | Toss confirm 호출 + 검증 + Firestore batch write (orders + orderLogs) |
| 점주 접수 (paid→accepted) | ✅ 클라이언트 SDK | 단순 status 전이, PG 호출 불필요 |
| 고객 환불 요청 (`accepted` 만) | ✅ 클라이언트 SDK | refundRequest 필드 추가만, PG 호출 불필요. `making`/`ready`/`completed` 에서는 차단 (Q7) |
| 점주 환불 거절 | ✅ 클라이언트 SDK | refundRequest 에 denied 메타 추가만 |
| 점주 조리 시작 (accepted→making) | ✅ 클라이언트 SDK | 단순 status 전이, PG 호출 불필요 |
| 점주 준비 완료 (making→ready) | ✅ 클라이언트 SDK | 단순 status 전이, PG 호출 불필요 |
| 점주 픽업 완료 (ready→completed) | ✅ 클라이언트 SDK | 단순 status 전이, PG 호출 불필요 |
| 고객 paid 취소 | 🛠 CF | Toss cancel API 호출 + status 전이 동시 |
| 점주 paid 거절 | 🛠 CF | 동일 (approvedBy='owner' 로 구분) |
| 환불 승인 (전액 환불) | 🛠 CF | Toss cancel API 호출 + status='refunded' + refundInfo |
| making/ready/completed 전이 | (미구현) | 향후 클라이언트 SDK 예정 (PG 호출 없음) |

### 2.5 `stores/{storeId}`

| 작업 | 허용 | 필드 제약 |
|---|---|---|
| read | `isSignedIn()` | (status=pending 도 read 가능, 클라이언트가 approved 필터링 — T7) |
| create | `owner` + `ownerId == uid` + `status == 'pending'` | — |
| update | `admin` OR `isStoreOwnerFieldUpdate(storeId)` OR `isStoreOwnerBrandUpdate()` | 화이트리스트: `name, imageUrl, location, phone, address, description, menuCategories, businessHours, isOpen, updatedAt, notice, tags` — **status / submittedBy / approvedBy 등 승인 메타는 admin 만** |
| delete | `admin OR storeOwner(storeId)` | — |
| Cloud Function 전담 | 없음 | — |

**핵심 불일치** ([`entity_lifecycle.md §3.3`](./entity_lifecycle.md) 참조):
- Repository 가 핵심 필드 수정 시 status='pending' 회귀를 의도하지만 Rules 화이트리스트에 `status` 없음 → 차단 가능성. 확인 필요.

**브랜드 본사(brand) 의 가맹점 update**: `isStoreOwnerBrandUpdate` — `isBrandHolder(store.brandId)` 가 storeOwner 와 동일한 운영 필드 화이트리스트를 update 가능 (U-3 결정).

### 2.6 `stores/{storeId}/subCategories/{id}`, `/menuItems/{id}`, `/menuOverrides/{id}`, `/optionGroups/{id}`

모두 동일한 패턴:

| 작업 | 허용 |
|---|---|
| read | `isSignedIn()` |
| create, update, delete | `admin OR storeOwner(storeId) OR brandHolder(store.brandId)` |

**중요**:
- store.brandId 가 채워진 가맹점이면 brand 본사도 write 가능. 개인 매장(brandId=null) 이면 brandHolder 조건은 자동 fail.
- Repository 계층이 추가로 검증:
  - `MenuItemRepositoryImpl`: 개인 매장 메뉴는 owner only, 브랜드 매장 점포한정 메뉴는 brand only (Rules 보다 엄격)
  - `MenuOverrideRepositoryImpl`: 핵심 필드는 brand only, 운영 필드는 owner/brand 모두 가능

⚠️ **방어 계층 일관성**: Rules 는 owner/brand/admin 모두 통과시키지만 Repository 가 case-by-case 로 제한. Rules 단에서 더 엄격히 갈라야 하는지 확인 필요.

### 2.7 `brands/{brandId}`

| 작업 | 허용 | 필드 제약 |
|---|---|---|
| read | `isSignedIn()` | — |
| create | `admin` OR (`isBrand()` + `submittedBy == uid` + `status == 'pending'` + `brandKey == ''`) | — |
| update | `admin` OR `isBrandSelfUpdate(brandId)` | 화이트리스트: `name, imageUrl, description, phone, address, businessHours, updatedAt, tags, logoUrl` — **status / submittedBy / approvedBy / brandKey 는 admin 만** |
| delete | `admin` | — |
| Cloud Function 전담 | 없음 | — |

**brandKey** 는 admin 의 approveBrand 시점에 자동 발급 (`BR-` + 8자 alphabet). 한번 발급되면 변경 불가 (V1 불변성 — `BrandRepositoryImpl` 의 `coreChanged` 분기에서 `brandKey` 를 entity 에서 빼지 않으므로 보존됨).

**Rules vs Repository drift** ([`entity_lifecycle.md §4.3`](./entity_lifecycle.md) 참조): brand 본인이 핵심 필드 변경 시 Repository 가 status='pending' 으로 회귀시키지만 Rules 화이트리스트에 `status` 없음 → 차단 가능성. 확인 필요.

### 2.8 `brands/{brandId}/menuItems`, `/subCategories`, `/optionGroups`

| 작업 | 허용 |
|---|---|
| read | `isSignedIn()` |
| create, update, delete | `admin OR brandHolder(brandId)` |

**일관성 양호**: Rules 가 명확히 brand 본사 + admin 으로 제한. Repository (`MasterMenuItemRepositoryImpl`) 도 동일한 ownership 검증.

### 2.9 `mainCategories/{id}`, `subCategories/{id}` (글로벌), `optionGroups/{id}` (글로벌)

마스터 데이터. nested subCategories / optionGroups 와는 별개 컬렉션.

| 작업 | 허용 |
|---|---|
| read | `isSignedIn()` |
| create, update, delete | `admin` |
| Cloud Function 전담 | 없음 |

### 2.10 `reviews/{reviewId}`

현재 안전한 기본값만 부여 (U-4 결정). 실제 리뷰 기능 도입 시 별 task 에서 보강 예정.

| 작업 | 허용 |
|---|---|
| read | `isSignedIn()` |
| create | `isSignedIn() AND request.userId == uid` |
| update | `isSignedIn() AND resource.userId == uid` (본인 작성자만) |
| delete | `admin OR (isSignedIn() AND resource.userId == uid)` |
| Cloud Function 전담 | 없음 |

⚠️ **미구현 UI**: 현재 리뷰 작성/조회 UI 자체가 없음. 평점/별점은 `stores` doc 의 `averageScore`, `reviewCount` 필드로 표시되지만 이를 갱신하는 로직 없음.

### 2.11 fallback

`match /{document=**} { allow read, write: if false; }` — 명시되지 않은 모든 경로는 거부.

---

## 3. Cloud Function 전담 작업 카탈로그

클라이언트 SDK 로 절대 수행 불가능한 작업 목록.

| Cloud Function | 트리거 actor | 입력 | 부수 효과 | 이유 |
|---|---|---|---|---|
| `verifyTossPayment` | customer (결제 직후) | paymentKey, orderId, amount, idempotencyKey, cart, paymentMethod | Toss confirm API + `orders/{orderId}` create + `users/{uid}/orderLogs/{logId}` create (batch) | 1) PG 서버 검증 2) 보안상 amount/orderId 변조 차단 3) orders 컬렉션 `create: if false` |
| `cancelTossPayment` | customer / owner | orderId, reason, approvedBy ('customer' \| 'owner') | Toss cancel API + `orders/{orderId}` update (status='cancelled', cancelInfo) | 1) PG 호출 2) 권한 재검증 (storeOwner / userId) 3) status 원자성 보장 |
| `processRefund` | owner | orderId, reason | Toss cancel API (전액) + `orders/{orderId}` update (status='refunded', refundInfo) | 동일 — PG + 권한 재검증 |
| `verifyKakaoToken` | 비로그인 (Kakao OAuth 직후) | accessToken | Kakao API 호출 → Firebase Custom Token (`kakao_{kakaoUid}`) 발급 | Kakao OAuth → Firebase Auth 브릿지. 클라이언트가 Firebase Admin SDK 사용 불가 |
| `verifyNaverToken` | 동일 | accessToken | 동일 (`naver_{naverUid}`) | 동일 |

**규칙**: 결제 / 외부 OAuth / 다중 collection batch + 권한 재검증이 필요한 작업은 모두 Cloud Function.

---

## 4. 신규 feature 권한 결정 흐름차트

```mermaid
flowchart TD
    A[새 feature 설계 시작] --> B{외부 API 호출 필요?<br/>(PG/OAuth/푸시 등)}
    B -- Yes --> CF[🛠 Cloud Function 필수]
    B -- No --> C{다중 collection<br/>batch write?}
    C -- Yes --> D{원자성 / 보안<br/>재검증 중요?}
    D -- Yes --> CF
    D -- No --> E[클라이언트 batch 가능 검토]
    C -- No --> F{누가 트리거?}
    F -- customer 본인 데이터 --> G[Rules: self uid 검증]
    F -- owner 본인 매장 --> H[Rules: storeOwner 검증]
    F -- brand 본인 산하 --> I[Rules: brandHolder 검증]
    F -- admin --> J[Rules: isAdmin 분기]
    G & H & I & J --> K{status 전이 포함?}
    K -- Yes --> L[Rules onlyChangedFields 화이트리스트<br/>+ 이전 status 검증]
    K -- No --> M[Rules 화이트리스트만]
    L & M --> N[Repository 갱신 필드<br/>= Rules 화이트리스트<br/>(drift 방지)]
```

---

## 5. drift 발견 / 의심 항목 (작성 시점)

이 task 의 발단인 "코드와 Rules 불일치" 의심 항목 정리.

| 항목 | 상태 | 영향 |
|---|---|---|
| `brands` 본인 핵심 필드 수정 시 Repository 가 status=pending 회귀, Rules 화이트리스트는 status 미포함 | 확인 필요 | brand 가 자기 정보 재제출 시 silently 차단? |
| `stores` 본인 핵심 필드 수정 시 동일 패턴 | 확인 필요 | 점주 매장 재제출 흐름 영향 |
| `users.brandId` 한번 set 후 재할당 불가 | 정책 모호 | brand 다운그레이드 후 재가입 시 새 brand 등록 불가 |
| `brand → customer` UI 미구현 (rules 는 허용) | UI 누락 | brand 가 역할 변경 못함 |
| `owner → brand` UI 미구현 (rules 는 허용) | UI 누락 | 점주가 추후 본사 전환 못함 |
| `stores/{storeId}/menuItems` Rules 는 owner 도 write 허용, Repository 는 brand 매장은 brand only | Rules 가 느슨 | 점주가 SDK 직접 호출로 우회 가능성? |
| `stores/{storeId}/menuOverrides` Rules 는 owner 도 핵심 필드 write 허용 | Rules 가 느슨 | 점주가 마스터 가격을 임의로 set 가능성? |
| `reviews` Rules 만 있고 UI 없음 / `stores.averageScore`, `reviewCount` 갱신 경로 없음 | 미구현 | 통계 불일치 |
| `users/{uid}/favoriteStores`, `/favoriteMenuItems` admin read 권한 명시 안 됨 | 정책 모호 | admin 운영 시 favorites 통계 못 봄 |

각 항목은 별도 spec.md 또는 추적 task 로 해결해야 한다.

---

## 6. 참조

- 단일 진실원: [`firestore.rules`](../../firestore.rules)
- Cloud Functions: [`functions/src/index.ts`](../../functions/src/index.ts) 외
- Repository 구현체: [`lib/data/repositories/*.dart`](../../lib/data/repositories/)
- 역할 흐름: [`role_flows.md`](./role_flows.md)
- 엔티티 lifecycle: [`entity_lifecycle.md`](./entity_lifecycle.md)
- 관련 task: [`docs/tasks/firestore_security_rules/spec.md`](../tasks/firestore_security_rules/spec.md), [`docs/tasks/owner_store_registration/spec.md`](../tasks/owner_store_registration/spec.md)
