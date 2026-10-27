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
| update | `admin (전권) OR self(uid)` self 케이스: `onlyChangedFields(['role', 'displayName', 'photoUrl', 'fcmToken', 'fcmTokenUpdatedAt', 'notificationPermissionPrompted', 'notificationPermissionLaterCount', 'notificationSettings', 'updatedAt'])` + role 전이 화이트리스트 | 변경 가능: displayName, photoUrl, fcmToken, fcmTokenUpdatedAt, notificationPermissionPrompted(OS 권한 시트 소진 = 다이얼로그 `허용` 선택 시에만 true), notificationPermissionLaterCount(`나중에` 선택 횟수, `FieldValue.increment(1)`, 부재 시 0), notificationSettings(bool map, dot-path), role(허용 전이). **`brandId` 는 화이트리스트에 없다 — 🛠 CF 전담** |
| delete | `admin` | — |
| Cloud Function 전담 | **`qoinBalance` 갱신** (`onOrderQoinSettled`) — §2.11 · **`brandId` 설정** (`claimSubmittedBrand`) — 아래 | — |

⚠️ **`qoinBalance` 는 클라이언트가 쓸 수 없다.** create 에서 `!('qoinBalance' in request.resource.data)` 로 차단하고(막지 않으면 신규 계정이 `qoinBalance: 999999` 로 시작할 수 있다), update 는 self 화이트리스트에 없어 거부된다. 갱신은 `onOrderQoinSettled` 가 트랜잭션 안에서 **절대값**으로 쓴다 (`increment` 금지).

**role 자가 전이 허용** ([`role_flows.md §3`](./role_flows.md) 참조): customer ↔ owner ↔ brand 임의 방향. admin 으로의 전이는 **모든 방향 차단**.

**brandId 정책** (2026-10-22 `brand_authorization_hardening` 으로 개정):
- `brandId` 는 **권한 값**이다. 한 필드가 그 브랜드 트리 전체와 **산하 매장의 메뉴·가격(`menuOverrides`) 쓰기 권한**을 결정한다 (`isBrandHolder`).
- 가입 시점 set 금지 (`users.create`) — 변동 없음
- **클라이언트는 어떤 경로로도 쓸 수 없다.** 🛠 CF **`claimSubmittedBrand`** 가 `brands/{brandId}.submittedBy == uid` 를 검증한 뒤 값과 `users/{uid}/roleHistory` 1건을 **같은 트랜잭션**에 쓴다.
- ⚠️ **개정 전에는 본인 update 로 `'' → value` 1회가 허용됐다.** 그래서 아무 계정이나 `{role:'brand', brandId:<남의 브랜드>}` **1회 업데이트**로 그 브랜드의 보유자가 됐다 (읽기뿐 아니라 쓰기까지 열렸다).
- `isBrandHolder` 는 **비어있지 않은 문자열 동일성**만 인정한다. 예전에는 `brandId` 필드가 **없는** 매장(`get('brandId','')` → `''`)과 `brandId` 를 설정하지 않은 `role=='brand'` 계정이 `'' == ''` 로 매칭됐다.
- 교정은 **admin 만** (전권 update). 본인 교정을 열면 "본인이 선언하는 brandId" 가 되살아난다 — 의도된 제약이다.
- Rules 의 `get(brands).submittedBy == uid()` 안은 **기각됐다**: 신규 등록이 brand 문서 create 와 `users.brandId` 를 **한 batch** 로 보내고 Rules 의 `get()` 은 batch **적용 전** 상태를 보므로, 브랜드 문서가 아직 없어 평가가 실패하고 **브랜드 등록이 전면 거부**된다. 상세: `brand_authorization_hardening/spec.md` D1-1.
- ⚠️ **재설계 후보**: brand role 다운그레이드 후 다시 brand 신청 시 새 brand doc 생성 불가능.

**`users/{uid}/roleHistory/{autoId}`** — 권한 변경 이력 (신규)

| 작업 | 허용 |
|---|---|
| read | `self(uid) OR admin` |
| create / update / delete | 🔒 `if false` — 🛠 CF 전담 |

현재 기록하는 것은 `field: 'brandId'` 1종이다 (`claimSubmittedBrand`). `role` 자체의 이력은 미설계 — `audit_trail.md` A4.

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
| create | `owner` + `ownerId == uid` + `status == 'pending'` | **`brandId` 가 있으면 존재하는 `status=='approved'` 브랜드여야 한다** (`get(brands/{id})`). `brandId` 는 Qoin 적립률 상속의 신뢰원이므로 오타·미존재·반려 브랜드 지정을 막는다. ⚠️ **가맹 관계 자체는 Rules 로 증명할 수 없다** — 승인 게이트가 통제한다 (`brand_authorization_hardening/spec.md` D5) |
| update | `admin` OR `isStoreOwnerFieldUpdate(storeId)` OR `isStoreOwnerBrandUpdate()` | 화이트리스트: `name, imageUrl, location, phone, address, description, menuCategories, businessHours, isOpen, updatedAt, notice, tags` — **status / submittedBy / approvedBy 등 승인 메타는 admin 만** / **Qoin 보호 필드 집합(`qoinAccrualRate` / `qoinAccrualEnabled` / `qoinBulkHistoryId` / `qoinBulkStatus` / `qoinBulkAt`)은 모든 분기에서 차단** — `touchesQoinManaged()` (§2.11 / §2.11.1b) |
| create | (위) | **승인 메타(`approvedAt` / `approvedBy` / `rejectedReason`) 설정 금지 — 부재 또는 null 만 허용** (payment_server_authority Rules-A). 결제 게이트 `canSellNow` 가 `approvedAt` 을 **권한 판정 입력**으로 쓰므로 create 도 쓰기 경로다 (`onlyChangedFields` 는 update 전용이라 create 를 보호하지 않는다 — §6.7 상시 규칙). 현재 앱 create payload 2개는 이 키를 보내지 않는다 (가드 테스트가 고정) |
| create | (위) | **Qoin 보호 필드 집합 포함 create 차단** (`!hasQoinManagedOnCreate()` — 필드 목록은 Rules 의 `qoinManagedFields()` **1곳**에서 선언된다) |
| delete | `admin` | **점주 하드 삭제는 닫혔다** (payment_server_authority Rules-C). 정상 경로는 **`deleteStore` CF (admin)** — 이력(`storeDeletionHistory`) + 하위 문서 재귀 삭제 + Storage 정리, 진행 중 주문(`paid`/`accepted`/`making`/`ready`)이 있으면 차단. 이로써 "삭제·재생성으로 적립 중단 상태를 지우기" 가 양쪽에서 막힌다 (G1: 재생성 매장은 `approvedAt` 이 없어 결제 거절) |
| Cloud Function 전담 | **`averageScore` / `reviewCount`** (`onReviewWritten`) · **`qoinAccrualRate`** (`setQoinAccrualRate` / `applyBrandQoinRate` / `migrateQoinZeroRates`) · **`qoinAccrualEnabled`** (`setQoinAccrualEnabled` / `migrateQoinZeroRates`) · **`qoinBulk*` 포인터** (`applyBrandQoinRate` **단독**) | — |

**핵심 불일치**: ~~Repository 의 status='pending' 회귀가 Rules 에서 차단될 가능성~~ → **해소 확인** ([`entity_lifecycle.md §3.3`](./entity_lifecycle.md)): 화이트리스트에 `status`(`'pending'` 으로만) · `submittedBy/At` · `approvedBy/At`(null 클리어만) · `rejectedReason` 이 이미 들어 있다.

**결제 게이트가 읽는 필드의 쓰기 경로 매트릭스** (payment_server_authority §6.6 — `status` / `approvedAt` / `approvedBy` / `rejectedReason`):

| 필드 | 점주 create | 점주 update | admin | CF | Console |
|---|---|---|---|---|---|
| `status` | `'pending'` 만 | `'pending'` 만 | 전권 | 전권 | 전권(Rules 우회) |
| `approvedAt` / `approvedBy` / `rejectedReason`(create) | **부재/null 만 (Rules-A)** | `approvedAt`·`approvedBy` null 클리어만 | 전권 | 전권 | 전권(Rules 우회) |

Console 수동 편집은 Rules 를 우회한다 → 오타로 매출이 멈추는 사고는 `paymentGateRejections` 가 탐지한다.

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
| read | `isSignedIn()` | 부모에 남는 `name/logoUrl/description/companyName/status/qoin*` 는 비밀이 아니다. **brandKey·사업자·담당자 PII 는 §2.7a 로 이동했다** |
| create | `admin` OR (`isBrand()` + `submittedBy == uid` + `status == 'pending'` + `brandKey == ''` + **PII 5개 키 없음** + **`approvedAt`/`approvedBy` 부재 또는 null**) | PII 를 부모에 쓰는 구 앱 create 는 거부 (Rules-B), 승인 메타 자가 설정 금지 (Rules-A) |
| update | `admin` OR `isBrandSelfUpdate(brandId)` | 화이트리스트: `name, logoUrl, description, phone, address, businessHours, updatedAt, tags, companyName` + 재제출 메타(`status→pending`, `submittedBy`, `submittedAt`, `rejectedReason`) — **PII 5개는 제거(§2.7a)**, **status 승격 / approvedBy / approvedAt / brandKey / createdAt 은 본인 변경 불가** |
| delete | `admin` | — |
| Cloud Function 전담 | **`brandKey` 발급** (`issueBrandKey`, §2.7a) | — |

**brandKey** 는 admin 승인 시 **`issueBrandKey` CF** 가 발급한다 (`BR-` + 8자 alphabet). 클라이언트는 쓰지 못한다. 한 번 발급되면 같은 브랜드에 대해 멱등(같은 키 반환).

#### 2.7a `brands/{brandId}/private/profile` · `brandKeys/{key}` · `brands/{brandId}/keyHistory/{id}` (payment_server_authority B1)

| 대상 | read | write | 비고 |
|---|---|---|---|
| `private/profile` (`brandKey` + `businessRegistrationNumber` `representativeName` `contactName` `contactPhone` `headOfficeAddress`) | `admin` OR `brandHolder(brandId)` OR 그 브랜드의 제출자(`submittedBy == uid`, 신규 등록 직후 claim 전) | 브랜드 본인(보유자/제출자)이 **PII 5개만** (create: 키 집합이 PII 5개 이내, update: `onlyChangedFields`). **`brandKey` 는 CF 전담** — create·update 양쪽 거부, admin 도 직접 쓰지 않는다. delete 불가 | 고객·점주·타 브랜드는 읽을 수 없다 (R8·R9). 부모 read 는 열려 있으므로 고객의 서브컬렉션(`menuItems` 등) read 는 영향 없다 |
| `brandKeys/{BR-XXXXXXXX}` (`brandId`, `issuedAt`, `issuedBy`) | **없음** | **없음** (CF/Admin SDK 전담) | **문서 ID = 키 → 유일성이 구조로 보장된다** (R11). `lookupBrandByKey` 가 단건 get 으로 조회 |
| `brands/{id}/keyHistory/{autoId}` | `admin` | **없음** (CF 전담) | brandKey 발급 이력 (`changedBy` = admin uid) |

**Rules vs Repository drift** ([`entity_lifecycle.md §4.3`](./entity_lifecycle.md) 참조): brand 본인이 핵심 필드 변경 시 Repository 가 status='pending' 으로 회귀시키지만 Rules 화이트리스트에 `status` 없음 → 차단 가능성. 확인 필요.

> **Qoin**: `brands/{brandId}` 의 보호 필드 집합(`qoinAccrualRate` / `qoinAccrualEnabled` / `qoinBulkHistoryId` / `qoinBulkStatus` / `qoinBulkAt`)은 **모든 분기(create·update·admin 전권)에서 클라이언트 차단**, CF 전담이다 (§2.11 / §2.11.1b).

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

`store_reviews` task 에서 Rules 를 **전면 교체**했다 (2026-10-22). 교체 전의 U-4 기본값은 필드 화이트리스트·자격 검증·중복 방지가 없어 `storeId` 변조와 무한 생성이 가능했다.

**문서 ID 규약**: `{storeId}_{userId}`. create 시 Rules 가 ID 와 본문 `storeId`/`userId` 의 일치를 강제하므로 **1인 1매장 1표**가 구조적으로 보장된다. 재평가는 같은 문서의 update 로 흡수된다.

| 작업 | 허용 |
|---|---|
| read | `isSignedIn()` |
| create | 본인(`userId == uid()`) + 문서 ID 일치 + 필드 화이트리스트(`hasOnly` 7 / `hasAll` 6) + `grade`↔`score` 일치 + `createdAt == request.time` + 주문 자격 |
| update | 본인 + `storeId`/`userId` 불변 + 화이트리스트(`hasOnly` 8 / `onlyChangedFields` 5) + `updatedAt == request.time` |
| delete | `admin OR (isSignedIn() AND resource.userId == uid)` |
| **Cloud Function 전담** | **`stores.averageScore` / `stores.reviewCount` 갱신** (아래 참조) |

**주문 자격 검증**: `orderId` 로 `get(orders/{orderId})` 하여 ① 본인 주문 ② `status == 'completed'` ③ 같은 매장을 확인한다. `get()` 은 `let` 바인딩으로 호출당 1회.

**14일 작성 기한은 Rules 에 넣지 않았다** (D2-b). Phase 3c 이전 `completed` 주문에 `completedAt` 이 없어 null 분기가 필요하고, 그러면 기한이 무력화되거나 legacy 주문이 영구 차단된다. 기한은 보안 경계가 아닌 품질 정책이며, 1인 1표가 이미 조작 상한을 막는다. UI 에서만 강제한다.

**`grade` ↔ `score` 비정규화**: `sum()` 집계 쿼리가 문자열을 합산할 수 없어 `score: int`(S=4/A=3/B=2/C=1)를 함께 저장한다. Rules 가 두 값의 일치를 강제하므로 `score` 단독 위조가 불가능하다.

⚠️ **`stores` 는 고객이 직접 쓸 수 없다.** `stores` update 화이트리스트에 `averageScore`/`reviewCount` 가 없고, Rules 를 완화하면 점주가 자기 매장 평점을 조작할 수 있게 된다. 그래서 집계를 Cloud Function 에 전담시켰다 (`stores` 블록은 **변경하지 않았다**).

### 2.11 Qoin — 적립률 / 전역 설정 / 변경 이력 / 원장

`qoin`(1차) + `qoin_accrual_rate_hierarchy`(계층화) 의 소유권 정리. **적립률은 발행되는 돈의 계수**이므로 쓰기는 전부 Cloud Function 전담이고, 이력은 admin 에게도 쓰기를 주지 않는다.

#### 2.11.1 적립률 필드 — `stores/{id}.qoinAccrualRate` / `brands/{id}.qoinAccrualRate` / `config/qoin.accrualRate`

| 값 | 의미 |
|---|---|
| 필드 부재 | 상위 상속 (매장 → 브랜드 → 전역) |
| `0.001 ~ 0.2` | 0.1% ~ 20%. 범위 밖·비number 는 **fail-closed** (상위 폴백 없이 적립 중단) |
| `0` | ❌ **유효값이 아니다.** 2026-10-22 사용자 결정(Q1)으로 "적립을 하냐" 는 **별도 스위치 필드**(§2.11.1a)로 분리됐다. `0` 은 어느 범위에서도 무효(fail-closed)다 |

⚠️ 운영에 남은 `qoinAccrualRate: 0` 은 1회성 CF `migrateQoinZeroRates` 가 스위치로 이전한다. 그 사이 **판독 측에만** 과도기 호환 분기가 있어 `0` 을 "사용 안 함" 과 동일 취급한다 (쓰기 측에는 예외가 없다). 상세: `qoin_accrual_rate_hierarchy/spec.md` §20.4.

| 작업 | 허용 | 비고 |
|---|---|---|
| read | `stores`/`brands` = `isSignedIn()` / `config` = `isSignedIn()` | 적립률은 고객에게 보여주는 혜택이라 공개를 수용 (spec §17 U1) |
| create / update / delete | 🔒 **모든 역할 차단 (admin 전권 분기 포함)** | `touchesQoinManaged()` / `hasQoinManagedOnCreate()` — 보호 필드 **집합**(`qoinAccrualRate` / `qoinAccrualEnabled` / `qoinBulkHistoryId` / `qoinBulkStatus` / `qoinBulkAt`)을 Rules 의 `qoinManagedFields()` **1곳**에서 선언한다 + `config` 의 `accrualRate` 차단 + `config` delete `if false` |
| 🛠 CF 전담 | `setQoinAccrualRate` (단건) · `applyBrandQoinRate` (브랜드 일괄) | admin role 을 **서버에서 재검증**하고 값 쓰기와 이력을 **같은 트랜잭션**에 둔다 → 이력 없는 변경이 구조적으로 불가능 |

**알려진 쓰기 경로 (막을 수 없는 것 포함)**

| 경로 | 상태 |
|---|---|
| Firebase Console / Admin SDK | ⚠️ **Rules 로 막을 수 없다.** `config/qoin` 은 `onQoinConfigWritten` 이 `source: 'direct'` 로 사후 기록. `stores`/`brands` 는 **감시 없음** (2차 N6) |
| 점주의 `stores` delete → 같은 ID 재생성 | ⚠️ 개별 설정이 **제거**된다. 재승인 필요(`status: 'pending'`) → **수용된 경로** |
| 발행 직전 경계 검증 | `onOrderQoinSettled` 가 저장된 값을 **믿지 않고** 범위를 재검사한다 (Console 편집 대비) |

#### 2.11.1a 적립 스위치 — `stores/{id}.qoinAccrualEnabled` / `brands/{id}.qoinAccrualEnabled`

"적립률이 얼마냐"(숫자)와 **"적립을 하냐"(스위치)** 를 한 필드가 겸하면, 브랜드 일괄 적용이 숫자를 통일할 때 "적립 안 함" 결정까지 함께 덮어쓴다. 그래서 스위치를 **별도 필드**로 분리했다 (사용자 결정 Q1).

| 값 | 의미 |
|---|---|
| 필드 부재 | **적립 사용** (기본값). 기존 문서에 필드를 심는 마이그레이션 불필요 |
| `false` | **적립 사용 안 함.** 적립만 막고 **회수는 통과**한다 (막으면 환불 주문의 Qoin 이 남아 돈이 샌다) |
| `true` | 적립 사용 (부재와 동일). 쓰기 경로는 `true` 를 저장하지 않고 **필드를 삭제**한다. 판독은 관대히 받는다 |
| 그 외 (비bool) | **fail-closed** — 적립 중단 + `qoinSettlementIssues` 기록 |

해석 순서: **스위치 단계(매장 → 브랜드) 를 전부 평가한 뒤 숫자 단계(매장 → 브랜드 → 전역) 로 내려간다.** 원칙은 **"스위치는 스위치만 이기고, 아랫단계의 숫자는 상위 스위치를 이길 수 없다"** 다 — **브랜드 스위치를 끄면 개별 적립률이 설정된 산하 매장도 함께 멈춘다** (사용자 결정 N4). `disabled` 판정은 `무효` 판정보다 **앞**이고, 둘 다 숫자 단계와 전역 기본값 검사보다 앞에서 단락한다 — 의도된 중단은 `qoinSettlementIssues`(고객 돈 누락 기록)를 만들지 않는다. 매장 스위치가 브랜드보다 먼저 평가되어 `source` 가 결정적이다. 상세: `qoin_accrual_rate_hierarchy/spec.md` §20.3.1.

| 작업 | 허용 | 비고 |
|---|---|---|
| read | `isSignedIn()` | 적립률과 동일 (공개 수용) |
| create / update / delete | 🔒 **모든 역할 차단 (admin 전권 분기 포함)** | Rules 헬퍼 `touchesQoinManaged()` / `hasQoinManagedOnCreate()` — 보호 필드 **집합** (`qoinAccrualRate`, `qoinAccrualEnabled`, `qoinBulkHistoryId`, `qoinBulkStatus`, `qoinBulkAt`) 을 **1곳**에서 선언한다 |
| 🛠 CF 전담 | `setQoinAccrualEnabled` (신규) | admin 서버 재검증 + bool 검증 + 값·이력 **같은 트랜잭션** + 일괄 적용 진행 중 거부 |

- **전역에는 스위치를 두지 않는다.** `config/qoin.enabled` 가 이미 있고 더 강하다 (적립·회수 **둘 다** 멈추는 비상 정지). `setQoinAccrualEnabled` 는 `scope: 'global'` 을 거부한다.
- **`applyBrandQoinRate` 는 스위치를 쓰지 않는다.** 읽기는 보고 목적뿐이고 어떤 분기도 바꾸지 않는다 — 산하 매장의 `disabledUntouchedCount` 와 브랜드 자신의 `brandDisabled`(꺼진 브랜드에 일괄 적용하면 **산하 전체가 적립되지 않는다**는 고지용).
- 변경 이력은 기존 `qoinRateHistory` 를 재사용한다 (`field: 'accrualEnabled'`).
- **알려진 미봉**: Console / Admin SDK 직접 편집은 Rules 로 막을 수 없고 `stores`/`brands` 에는 감시 트리거도 없다 (2차 N6 — 적립률과 동일 한계). 점주의 `stores.delete` → 같은 ID 재생성은 스위치도 **제거**한다 (재승인 `status: 'pending'` 필요 → **수용된 경로**, 사용자 결정 Q3).

#### 2.11.1b 일괄 적용 포인터 — `brands/{id}.qoinBulkHistoryId` / `.qoinBulkStatus` / `.qoinBulkAt`

브랜드 일괄 적용은 산하 매장을 청크로 돌기 때문에 **중간에 멈출 수 있다.** 그 사실을 이력 컬렉션 조회(collection group + 인덱스)에 의존하지 않고 알 수 있어야 해서 **브랜드 문서 자신에** 포인터 3필드를 둔다.

| 필드 | 의미 |
|---|---|
| `qoinBulkHistoryId` | **마지막 일괄 시도**의 이력 문서 ID. 중단 배너의 처리 수/전체 수를 이 ID 로 이력 1건을 읽어 채운다 |
| `qoinBulkStatus` | `in_progress`(진행 중 = 잠금) / `partial`(중단) / `completed`(정상 종결) / `superseded`(뒤에 다른 설정 변경이 와서 마감) |
| `qoinBulkAt` | 마지막 상태 전이 시각(`serverTimestamp`). `in_progress` 의 stale 판정과 오래된 스캔 무효화에 쓴다 |

- **작성자는 `applyBrandQoinRate` 단독**이다. `setQoinAccrualRate` / `setQoinAccrualEnabled` 는 `partial` 포인터를 `superseded` 로 **마감만** 한다 (같은 트랜잭션).
- **읽는 쪽**은 admin 허브 배너 · 브랜드 목록 태그 · 브랜드 편집 페이지 배너 3곳이고, **세 곳이 같은 판정 함수**(`resolveBulkBanner`)를 쓴다. 화면이 필드를 직접 비교하지 않는다 (2차 S1: 편집 페이지만 이력 스트림으로 판정해 허브와 결과가 어긋났다).
- **포인터는 삭제되지 않는다.** 종결은 `completed` / `superseded` 전이이고, 그래서 "지울 방법이 없는 중단 상태" 가 존재하지 않는다 (2차 S2). 상세: `qoin_accrual_rate_hierarchy/spec.md` §21.1 / §21.2.
- 클라이언트 쓰기는 보호 필드 집합에 포함되어 **모든 역할에서 차단**된다(admin 전권 포함). 읽기는 `brands` 문서와 동일(`isSignedIn()`).

#### 2.11.2 `config/qoin` — 전역 기본값 + 비상 정지

| 필드 | 작업 | 허용 |
|---|---|---|
| `accrualRate` | create / update / delete | 🔒 **차단** — 🛠 CF `setQoinAccrualRate` 전담 |
| `enabled` (비상 정지, 적립·회수 **둘 다** 멈춤) | update | ✅ **admin 직접 쓰기 유지** |

`enabled` 만 직접 쓰기를 남긴 이유: **CF 장애 중에도 끌 수 있어야 한다.** 이력은 `onQoinConfigWritten` 트리거가 남긴다. 행위자(`changedBy`)를 남기려면 같은 write 에 **`enabledChangedBy == uid()` 와 `enabledChangedAt == request.time`(= `FieldValue.serverTimestamp()`) 을 둘 다 Rules 로 강제**한다. `enabledChangedBy` 만 강제하면 **생략**으로 우회된다 — 둘 중 하나를 빼고 쓰면 트리거가 Console 편집과 구별하지 못해 이력의 행위자가 `null` 로 남는다 (2차 정정, `audit_trail.md` §4-4). 상세: `qoin_accrual_rate_hierarchy/spec.md` §19.3 / §21.9-1.

#### 2.11.3 `{config/qoin | brands/{id} | stores/{id}}/qoinRateHistory/{autoId}` — 설정 변경 이력

| 작업 | 허용 |
|---|---|
| read (전역) | `admin` |
| read (브랜드) | `admin OR brandHolder(brandId)` |
| read (매장) | `admin OR storeOwner(storeId) OR brandHolder(stores/{id}.brandId)` |
| read (collection group `/{path=**}/qoinRateHistory/{id}`) | `admin` **만** (admin 전체 이력 화면) |
| create / update / delete | 🔒 **전부 `if false` — admin 도 불가** |
| 🛠 CF 전담 | `setQoinAccrualRate` · `applyBrandQoinRate` · `onQoinConfigWritten` |

`field` 값은 `'accrualRate'`(적립률) / `'accrualEnabled'`(매장·브랜드 스위치) / `'globalEnabled'`(전역 비상 정지) 3종이고, `source` 는 `'callable' | 'bulk' | 'direct' | 'app_direct' | 'migration'` 이다.

세 범위의 **컬렉션 이름이 같아야** collection group 조회가 성립한다. CG 쿼리(`orderBy changedAt desc`)는 **인덱스 배포가 선행**돼야 한다 (에뮬레이터는 인덱스를 강제하지 않는다).

#### 2.11.4 `users/{uid}/qoinBalance` (필드) / `users/{uid}/qoinTransactions/{txId}` (원장)

| 작업 | 허용 |
|---|---|
| read | `self(uid) OR admin` |
| create / update / delete | 🔒 **전부 `if false` — append-only, admin 도 불가** |
| 🛠 CF 전담 | `onOrderQoinSettled` (`* → completed` 적립 / `completed → refunded` 회수) |

원장은 **당시 값을 박제**한다 (`accrualRate`, `accrualRateSource`, `orderTotalPrice`, `storeId`, `brandId`, `balanceAfter`). `brandId` 는 적립 비용 정산(`audit_trail.md` §5)의 선행 자산이며, **해석에 쓴 `stores/{id}.brandId`** 를 기록한다 (주문 문서의 `brandId` 는 클라이언트 값이라 금액·정산에 쓰지 않는다). 멱등 ID 는 `earn_{orderId}` / `clawback_{orderId}`.

#### 2.11.5 `qoinSettlementIssues/{orderId}` — 적립 누락 기록 (**구현됨**)

적립률이 무효(Console 편집 등)여서 fail-closed 로 적립이 중단된 주문을 Firestore 에 남긴다. Cloud Logging 은 보존 기간이 있어 **고객 돈의 누락**을 담기에 부적절하다 (`audit_trail.md` §4-6).

| 작업 | 허용 |
|---|---|
| read | `admin` |
| create / update / delete | 🔒 `if false` |
| 🛠 CF 전담 | `onOrderQoinSettled` (`skipped_invalid_rate` / `skipped_invalid_store` / `skipped_invalid_total` / `skipped_invalid_enabled`) |

**의도된 중단은 기록하지 않는다**: 스위치가 꺼져 적립을 건너뛴 경우(`skipped_accrual_disabled`)는 Cloud Logging 에만 남는다 — 값이 사라진 사건이 아니라 **설정대로 동작한 사건**이고 그 설정 자체는 `qoinRateHistory` 에 영구 보존된다(빈도도 높아 노이즈가 된다). 반면 스위치 값이 **무효**(비bool, Console 편집)여서 fail-closed 된 경우(`skipped_invalid_enabled`)는 **고객 돈의 영구 누락**이므로 기록한다. 상세: `qoin_accrual_rate_hierarchy/spec.md` §19.4 / §20.3.4.

> 구 코드의 `skipped_rate_zero` 는 삭제됐다 (0 은 더 이상 적립률 값이 아니다 — 사용자 결정 Q1).

### 2.13 결제 게이트 · 삭제 이력 컬렉션 (payment_server_authority)

| 컬렉션 | read | write | 내용 |
|---|---|---|---|
| `paymentGateRejections/{autoId}` | `admin` | **없음** (CF 전담) | `uid, storeId, reason(STORE_NOT_SELLABLE\|STORE_NOT_FOUND\|MENU_SOLD_OUT\|MENU_EXCLUDED\|MENU_NOT_FOUND\|READ_FAILED), detail{rawStatus,hasApprovedAt,violatedMenuItemIds,violatedMenuNames}, amount, createdAt`. **오탐 탐지 장치** — 거절이 악용 차단인지 데이터가 틀어져 정상 손님을 막은 것인지는 건수·분포로만 구분된다 |
| `storeDeletionHistory/{storeId_createdAtMillis}` | `admin` | **없음** (CF 전담) | `storeId, storeName, ownerId, brandId, status, deletedBy, deletedAt, reason, snapshot(삭제 직전 매장 문서), imageUrls, affected, phase(started\|docDeleted\|subDeleted\|storageDeleted\|done)` |
| `migrationHistory/{autoId}` | (규칙 없음 = 클라이언트 접근 불가) | Admin SDK | 일괄 처리 1건 + 영향 범위(대상 수) |
| `brandKeyLookupLimits/{uid}` | (규칙 없음) | Admin SDK | `lookupBrandByKey` rate limit 창 카운터 |

### 2.12 fallback

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
| `onReviewWritten` | customer (평가 작성·수정·삭제) | `reviews/{reviewId}` written 트리거 | 해당 `storeId` 의 리뷰를 `count()` + `sum('score')` 로 **전량 재계산**해 `stores.averageScore` / `reviewCount` **2필드만** overwrite | 1) 고객은 `stores` 를 쓸 권한이 없고, Rules 를 완화하면 **점주가 자기 평점을 조작**할 수 있다 2) 전량 재계산이라 멱등하고 시드 오염이 자기 치유되며, 수정·삭제가 생성과 같은 코드 경로를 타 **집계 보정 로직이 불필요**하다 |

| `onOrderQoinSettled` | customer/owner (주문 status 전이) | `orders/{orderId}` updated 트리거 | 계층 해석(매장→브랜드→전역) 후 `users/{uid}/qoinTransactions/{txId}` create + `users/{uid}.qoinBalance` 절대값 갱신 (한 트랜잭션) | 1) 원장·잔액은 클라이언트 쓰기 `if false` 2) **적립률은 돈의 계수** — 저장값을 믿지 않고 발행 직전 경계 재검증 3) 멱등 가드(`earn_{orderId}`)가 서버에만 있을 수 있다 |
| `setQoinAccrualRate` | admin (단건 설정) | `{scope, targetId, rate\|clear, reason?}` | `stores`/`brands`/`config` 의 적립률 1필드 + `qoinRateHistory` 1건 (**같은 트랜잭션**) | 1) 클라이언트는 이 필드를 쓸 수 없다(admin 포함) 2) 이력을 클라이언트가 쓰면 **위조·누락** 가능 3) admin role **서버 재검증** + 범위 검증 |
| `applyBrandQoinRate` | admin (브랜드 일괄) | `{brandId, rate\|clear, mode: preserve\|overwrite, reason?, resumeHistoryId?}` | 브랜드 값 1 write + 이력 선기록(한 트랜잭션) → (overwrite) 산하 매장 개별 설정 청크 삭제 + 매장별 이력 → 이력 마감 | 1) 500 batch 한도·권한 재검증·이력 위조 2) **A 가 쓴 문서로 B 소유 문서를 갱신** (§3 규칙) 3) 재개(`partial`) 멱등 처리 |
| `setQoinAccrualEnabled` | admin (적립 사용 토글) | `{scope: store\|brand, targetId, enabled: boolean, reason?}` | `stores`/`brands` 의 `qoinAccrualEnabled` 1필드(또는 삭제) + `qoinRateHistory` 1건 (**같은 트랜잭션**) | 1) 클라이언트는 이 필드를 쓸 수 없다(admin 포함) 2) **적립이 발생하는지 자체를 결정**하는 정책 값이므로 적립률과 동급 3) 이력 위조·누락 차단. `scope: 'global'` 은 거부 (전역은 `config/qoin.enabled`) |
| `lookupBrandByKey` | 로그인 사용자 | `{brandKey}` | 쓰기: rate limit 카운터(`brandKeyLookupLimits/{uid}`) 만. 반환 `{brandId,name,logoUrl}` | 1) `brandKey` 가 비공개(§2.7a)라 클라이언트 쿼리가 불가능 2) 미존재/미승인을 **같은 응답**으로 (열거 오라클 방지) 3) uid 당 분당 10회 |
| `issueBrandKey` | admin | `{brandId}` | `brandKeys/{key}` create + `private/profile.brandKey` + `keyHistory` 1건 (**한 트랜잭션**). 멱등 | 쿼리 기반 유일성은 경쟁 조건에서 깨진다 → 문서 ID 유일성. 이력 위조·누락 차단 |
| `deleteStore` | admin | `{storeId, reason, dryRun}` | `storeDeletionHistory/{storeId_createdAtMillis}` (재진입점, `phase`) → 매장 문서 삭제 → 하위 문서 재귀 삭제 → Storage 이미지 → `done`. **진행 중 주문이 있으면 차단**. `dryRun` 은 쓰기 0 | 이력 없는 하드 삭제 제거. 재실행 멱등 (이력 1건) |
| `verifyTossPayment` 게이트 (G1·G2) | — | — | 거절 시 `paymentGateRejections/{autoId}` 1건 (Toss confirm 전, 돈 이동 없음) | 아래 §2.13 |
| `migrateStoreApprovalMeta` · `migrateBrandPrivateProfile` ⏳**임시** | admin (1회성) | `{dryRun}` · `{stage, dryRun}` | `stores.status/approvedAt` 백필(이상치는 멈추고 보고) · `brands` PII/brandKey → `private/profile` 복사(stage copy) / 부모 제거(stage cleanup). `migrationHistory` 1건 | payment_server_authority M1·M2. **배포 ⑪ 정리 커밋에서 삭제** |
| `migrateQoinZeroRates` ⏳**임시** | admin (1회성) | `{dryRun: boolean}` | `qoinAccrualRate == 0` 인 `stores`/`brands` 를 `{rate 삭제, qoinAccrualEnabled: false}` + 이력 1건(`source: 'migration'`, `migratedFromRate: 0`) 으로 이전. 멱등 | Q1 결정 이전용. **마이그레이션 0건 확인 후 과도기 호환 분기와 함께 삭제한다** (`qoin_accrual_rate_hierarchy/spec.md` §20.4.5) |
| `claimSubmittedBrand` | brand 신청자 (브랜드 마스터 정보 등록 직후) | `{ brandId }` | `brands/{brandId}.submittedBy == uid` 검증 후 `users/{uid}.brandId` 설정 + `users/{uid}/roleHistory` 1건 (**같은 트랜잭션**). 멱등 | 1) `brandId` 는 **권한 값**이다 — 클라이언트가 쓰면 임의 브랜드의 보유자가 된다 2) Rules 로는 검증 불가: 신규 등록이 brand create 와 같은 **batch** 라 `get()` 이 brand 문서를 보지 못한다 3) 권한 변경 이력을 값과 같은 트랜잭션에 둔다 |
| `auditBrandLinks` ⏳**임시** | admin (1회성) | `{}` | **쓰기 0.** `users(role=='brand')` / `brands` / `stores.brandId` 를 스캔해 `ok` · `ok_onboarding` · `dangling` · `mismatch` · `duplicate` · `orphan_brand` · `store_dangling_brand` · `store_unapproved_brand` 로 분류해 **보고만** 한다 | 개정 전 Rules 로 잘못 연결된 계정이 운영에 있을 수 있고 설계자는 운영 Firestore 를 읽을 수 없다. 자동 교정하지 않는다(의도를 추측할 수 없으면 손대지 않는다). **정리 커밋에서 삭제** (`brand_authorization_hardening/spec.md` §4 · §8-A2) |
| `onQoinConfigWritten` | 누구든 (`config/qoin` written) | `config/qoin` written 트리거 | `accrualRate`/`enabled` 변경을 `config/qoin/qoinRateHistory` 에 1건 기록 (callable 이 이미 남긴 건 skip) | **Console / Admin SDK 쓰기는 Rules 를 우회한다.** 직접 쓰기를 유지하는 `enabled` 와 콘솔 편집을 사후 포착하는 유일한 수단 |

**규칙**: 결제 / 외부 OAuth / 다중 collection batch + 권한 재검증이 필요한 작업은 모두 Cloud Function.

**추가 규칙 (2026-10-22, `qoin_accrual_rate_hierarchy`)**: **설정 변경 이력을 남겨야 하는 값은 쓰기도 Cloud Function 이다.** 값과 이력을 **같은 트랜잭션**에 두지 않으면 "변경됐는데 이력이 없는" 상태가 만들어진다. 이력 컬렉션은 **admin 에게도 쓰기를 주지 않는다** (`audit_trail.md` §4).

**추가 규칙 (2026-10-22, `store_reviews`)**: **A 가 쓴 문서로 B 소유 문서의 집계값을 갱신해야 하면 Cloud Function 이다.** Rules 를 완화해 B 에게 직접 쓰기를 허용하면 B 가 자기 통계를 조작할 수 있다.
`onReviewWritten` 이 `stores.updatedAt`(점주 운영 필드)과 `grade`(파생 필드)를 건드리지 않는 것도 같은 이유 — **소유권 경계를 넘는 쓰기는 최소 필드로 제한**한다.

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
| ~~`users.brandId` 를 본인이 임의 값으로 1회 set 할 수 있다 (자가 `brand` 역할 전이와 결합해 임의 브랜드의 보유자가 된다 — **쓰기까지**)~~ | **해소 (2026-10-22)** `brand_authorization_hardening` — CF 전담 + `isBrandHolder` 공백 매칭 차단 | — |
| `users.brandId` 한번 set 후 재할당 불가 (admin 만 교정) | **의도로 확정 (2026-10-22)** | admin 교정 화면은 backlog. brand 다운그레이드 후 재가입 시 새 brand 등록 불가 |
| `brand → customer` UI 미구현 (rules 는 허용) | UI 누락 | brand 가 역할 변경 못함 |
| `owner → brand` UI 미구현 (rules 는 허용) | UI 누락 | 점주가 추후 본사 전환 못함 |
| `stores/{storeId}/menuItems` Rules 는 owner 도 write 허용, Repository 는 brand 매장은 brand only | Rules 가 느슨 | 점주가 SDK 직접 호출로 우회 가능성? |
| `stores/{storeId}/menuOverrides` Rules 는 owner 도 핵심 필드 write 허용 | Rules 가 느슨 | 점주가 마스터 가격을 임의로 set 가능성? |
| ~~`brands` read 가 `isSignedIn()` 전면 공개 → brandKey·PII 노출~~ | **해소 (코드 완료, 배포 ⑧⑨ 후 확정)** payment_server_authority B1 — §2.7a | R9 는 M2 stage cleanup(부모 PII 제거)까지 가야 이행 |
| ~~`verifyTossPayment` 가 `stores` 를 읽지 않아 `pending` 매장도 결제·적립이 성립~~ | **해소 (코드 완료, 배포 ⑥ 후 확정)** payment_server_authority G1 — `canSellNow` + Rules-A | §2.5 |
| ~~`reviews` Rules 만 있고 UI 없음 / `stores.averageScore`, `reviewCount` 갱신 경로 없음~~ | **해소 (2026-10-22)** `store_reviews` task — Rules 전면 교체 + `onReviewWritten` CF 집계 | — |
| `users/{uid}/favoriteStores`, `/favoriteMenuItems` admin read 권한 명시 안 됨 | 정책 모호 | admin 운영 시 favorites 통계 못 봄 |
| ~~Qoin 적립률 / `config/qoin` / `qoinRateHistory` / `qoinTransactions` 가 이 문서에 없음~~ | **해소 (2026-10-22)** `qoin_accrual_rate_hierarchy` tester F6 → §2.11 / §3 추가 | — |
| ~~`stores.delete` 가 점주에게 열려 있다~~ | **해소 (코드 완료, 배포 ⑧ 후 확정)** payment_server_authority D1 — Rules-C + `deleteStore` CF | 소프트 삭제(`status:'deleted'`)는 N4 로 분리. §2.5 |
| `stores`/`brands` 의 `qoinAccrualRate` Console 직접 편집 감시 없음 | 수용 (2차 N6) | 콘솔로 바꾸면 이력이 빈다. 전역(`config/qoin`)만 감시 중 |

각 항목은 별도 spec.md 또는 추적 task 로 해결해야 한다.

---

## 6. 참조

- 단일 진실원: [`firestore.rules`](../../firestore.rules)
- Cloud Functions: [`functions/src/index.ts`](../../functions/src/index.ts) 외
- Repository 구현체: [`lib/data/repositories/*.dart`](../../lib/data/repositories/)
- 역할 흐름: [`role_flows.md`](./role_flows.md)
- 엔티티 lifecycle: [`entity_lifecycle.md`](./entity_lifecycle.md)
- 이력 / 감사 추적: [`audit_trail.md`](./audit_trail.md)
- 관련 task: [`docs/tasks/firestore_security_rules/spec.md`](../tasks/firestore_security_rules/spec.md), [`docs/tasks/owner_store_registration/spec.md`](../tasks/owner_store_registration/spec.md), [`docs/tasks/qoin/spec.md`](../tasks/qoin/spec.md), [`docs/tasks/qoin_accrual_rate_hierarchy/spec.md`](../tasks/qoin_accrual_rate_hierarchy/spec.md)
