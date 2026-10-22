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
| Cloud Function 전담 | **`qoinBalance` 갱신** (`onOrderQoinSettled`) — §2.11 | — |

⚠️ **`qoinBalance` 는 클라이언트가 쓸 수 없다.** create 에서 `!('qoinBalance' in request.resource.data)` 로 차단하고(막지 않으면 신규 계정이 `qoinBalance: 999999` 로 시작할 수 있다), update 는 self 화이트리스트에 없어 거부된다. 갱신은 `onOrderQoinSettled` 가 트랜잭션 안에서 **절대값**으로 쓴다 (`increment` 금지).

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
| update | `admin` OR `isStoreOwnerFieldUpdate(storeId)` OR `isStoreOwnerBrandUpdate()` | 화이트리스트: `name, imageUrl, location, phone, address, description, menuCategories, businessHours, isOpen, updatedAt, notice, tags` — **status / submittedBy / approvedBy 등 승인 메타는 admin 만** / **`qoinAccrualRate` 는 모든 분기에서 차단** (§2.11) |
| create | (위) | **`qoinAccrualRate` 포함 create 차단** (`!hasQoinRateOnCreate()`) |
| delete | `admin OR storeOwner(storeId)` | ⚠️ 점주 삭제가 **열려 있다.** 같은 ID 로 재생성하면 `qoinAccrualRate` 개별 설정이 사라진다 (§2.11 의 알려진 경로). 재생성은 `status: 'pending'` 강제 → admin 재승인 전까지 주문·적립 불가. 삭제 자체는 **이력에 남지 않고** `qoinRateHistory` 서브컬렉션이 고아가 된다 |
| Cloud Function 전담 | **`averageScore` / `reviewCount`** (`onReviewWritten`) · **`qoinAccrualRate`** (`setQoinAccrualRate` / `applyBrandQoinRate`) | — |

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

> **Qoin**: `brands/{brandId}.qoinAccrualRate` 는 **모든 분기(create·update·admin 전권)에서 클라이언트 차단**, CF 전담이다 (§2.11).

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
| create / update / delete | 🔒 **모든 역할 차단 (admin 전권 분기 포함)** | `touchesQoinRate()` / `hasQoinRateOnCreate()` / `config` 의 `accrualRate` 차단 + `config` delete `if false` |
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

해석 순서: **매장 스위치 → 매장 요율 → 브랜드 스위치 → 브랜드 요율 → 전역 기본값.** 매장 스위치가 꺼져 있으면 숫자를 읽지 않고, 전역 기본값 검사보다 **앞에서 단락**한다(전역이 깨져 있어도 의도된 중단은 누락 사건으로 기록되지 않는다). **매장 개별 숫자는 브랜드 스위치를 이긴다.**

| 작업 | 허용 | 비고 |
|---|---|---|
| read | `isSignedIn()` | 적립률과 동일 (공개 수용) |
| create / update / delete | 🔒 **모든 역할 차단 (admin 전권 분기 포함)** | Rules 헬퍼 `touchesQoinManaged()` / `hasQoinManagedOnCreate()` — 보호 필드 **집합** (`qoinAccrualRate`, `qoinAccrualEnabled`, `qoinBulkHistoryId`, `qoinBulkStatus`, `qoinBulkAt`) 을 **1곳**에서 선언한다 |
| 🛠 CF 전담 | `setQoinAccrualEnabled` (신규) | admin 서버 재검증 + bool 검증 + 값·이력 **같은 트랜잭션** + 일괄 적용 진행 중 거부 |

- **전역에는 스위치를 두지 않는다.** `config/qoin.enabled` 가 이미 있고 더 강하다 (적립·회수 **둘 다** 멈추는 비상 정지). `setQoinAccrualEnabled` 는 `scope: 'global'` 을 거부한다.
- **`applyBrandQoinRate` 는 스위치를 쓰지 않는다.** 읽기는 집계(`disabledUntouchedCount`) 목적 1곳뿐이고 어떤 분기도 바꾸지 않는다.
- 변경 이력은 기존 `qoinRateHistory` 를 재사용한다 (`field: 'accrualEnabled'`).
- **알려진 미봉**: Console / Admin SDK 직접 편집은 Rules 로 막을 수 없고 `stores`/`brands` 에는 감시 트리거도 없다 (2차 N6 — 적립률과 동일 한계). 점주의 `stores.delete` → 같은 ID 재생성은 스위치도 **제거**한다 (재승인 `status: 'pending'` 필요 → **수용된 경로**, 사용자 결정 Q3).

#### 2.11.2 `config/qoin` — 전역 기본값 + 비상 정지

| 필드 | 작업 | 허용 |
|---|---|---|
| `accrualRate` | create / update / delete | 🔒 **차단** — 🛠 CF `setQoinAccrualRate` 전담 |
| `enabled` (비상 정지, 적립·회수 **둘 다** 멈춤) | update | ✅ **admin 직접 쓰기 유지** |

`enabled` 만 직접 쓰기를 남긴 이유: **CF 장애 중에도 끌 수 있어야 한다.** 이력은 `onQoinConfigWritten` 트리거가 남긴다. 행위자(`changedBy`)를 남기려면 같은 write 에 `enabledChangedBy == uid()` 를 Rules 로 강제한다 (`qoin_accrual_rate_hierarchy/spec.md` §19.3).

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

#### 2.11.5 `qoinSettlementIssues/{orderId}` — 적립 누락 기록 (설계 확정 / 미구현)

적립률이 무효(Console 편집 등)여서 fail-closed 로 적립이 중단된 주문을 Firestore 에 남긴다. Cloud Logging 은 보존 기간이 있어 **고객 돈의 누락**을 담기에 부적절하다 (`audit_trail.md` §4-6).

| 작업 | 허용 |
|---|---|
| read | `admin` |
| create / update / delete | 🔒 `if false` |
| 🛠 CF 전담 | `onOrderQoinSettled` (`skipped_invalid_rate` / `skipped_invalid_store` / `skipped_invalid_total`) |

의도된 정책인 `skipped_rate_zero`(명시적 0%)는 기록하지 않는다. 상세: `qoin_accrual_rate_hierarchy/spec.md` §19.4.

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
| `migrateQoinZeroRates` ⏳**임시** | admin (1회성) | `{dryRun: boolean}` | `qoinAccrualRate == 0` 인 `stores`/`brands` 를 `{rate 삭제, qoinAccrualEnabled: false}` + 이력 1건(`source: 'migration'`, `migratedFromRate: 0`) 으로 이전. 멱등 | Q1 결정 이전용. **마이그레이션 0건 확인 후 과도기 호환 분기와 함께 삭제한다** (`qoin_accrual_rate_hierarchy/spec.md` §20.4.5) |
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
| `users.brandId` 한번 set 후 재할당 불가 | 정책 모호 | brand 다운그레이드 후 재가입 시 새 brand 등록 불가 |
| `brand → customer` UI 미구현 (rules 는 허용) | UI 누락 | brand 가 역할 변경 못함 |
| `owner → brand` UI 미구현 (rules 는 허용) | UI 누락 | 점주가 추후 본사 전환 못함 |
| `stores/{storeId}/menuItems` Rules 는 owner 도 write 허용, Repository 는 brand 매장은 brand only | Rules 가 느슨 | 점주가 SDK 직접 호출로 우회 가능성? |
| `stores/{storeId}/menuOverrides` Rules 는 owner 도 핵심 필드 write 허용 | Rules 가 느슨 | 점주가 마스터 가격을 임의로 set 가능성? |
| ~~`reviews` Rules 만 있고 UI 없음 / `stores.averageScore`, `reviewCount` 갱신 경로 없음~~ | **해소 (2026-10-22)** `store_reviews` task — Rules 전면 교체 + `onReviewWritten` CF 집계 | — |
| `users/{uid}/favoriteStores`, `/favoriteMenuItems` admin read 권한 명시 안 됨 | 정책 모호 | admin 운영 시 favorites 통계 못 봄 |
| ~~Qoin 적립률 / `config/qoin` / `qoinRateHistory` / `qoinTransactions` 가 이 문서에 없음~~ | **해소 (2026-10-22)** `qoin_accrual_rate_hierarchy` tester F6 → §2.11 / §3 추가 | — |
| `stores.delete` 가 점주에게 열려 있다 (삭제 이력 없음 / 서브컬렉션 고아 / 같은 ID 재생성으로 개별 설정 초기화) | **미해결 — backlog** | 소프트 삭제 또는 admin 전용 + 삭제 이력 필요. §2.5 / §2.11.1 참조 |
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
