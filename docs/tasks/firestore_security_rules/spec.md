# firestore_security_rules 기능 명세

> Phase 3a 종결 작업. 현재 Firestore 콘솔에 임시 룰(`request.time < timestamp.date(2027,12,31)`) 만 존재해 사실상 모두 허용 상태다. 본 task 에서 **정식 권한 규칙** 을 작성하고, **git 으로 코드 관리** 한 뒤, `firebase deploy --only firestore:rules` 로 배포한다.
>
> 본 spec 은 designer / developer / tester 가 모두 기준으로 삼는 단일 진실원이다. 개별 컬렉션의 read/write 매트릭스, helper function 시그니처, orders update 분기, role 전이 정책, 테스트 시나리오를 모두 본 문서에 명시한다.

---

## 개요

- **목적**: 모든 Firestore 컬렉션에 대해 역할(role) 기반 권한을 코드로 정의하고 git 에 커밋. 프로덕션 진입 전 보안 게이트 확립.
- **작업 유형**: 신규 인프라 추가 (코드 + 배포). Flutter / Cloud Functions 코드 변경은 **원칙적으로 없음**. 단, 룰이 강제하는 클라이언트 동작과 어긋나는 부분이 발견되면 별도 follow-up task 로 분리한다.
- **영향 범위**:
  - 화면: 직접 영향 없음 (단, 룰이 잘못되면 정상 흐름이 `permission-denied` 로 깨지므로 모든 customer / owner / brand / admin 흐름을 회귀 검증 필요)
  - Domain: 변경 없음
  - Data: 변경 없음 (Cloud Functions 는 Admin SDK 사용 → 룰 우회되므로 무관)
  - Presentation: 변경 없음
  - 공통 컴포넌트: 변경 없음
  - 라우팅: 변경 없음
  - 권한 / 환경 설정: **`firestore.rules` 신규 추가** + **`firebase.json` 에 `firestore.rules` 경로 추가** + 배포 파이프라인에 `firebase deploy --only firestore:rules` 추가
  - 테스트: Firebase Emulator 또는 운영 콘솔에서 룰 동작 검증
- **비범위**:
  - **Storage 보안 규칙 (`storage.rules`)** — 별도 follow-up task. 본 phase 는 Firestore 만.
  - **Cloud Functions IAM / App Check** — 별 task.
  - **FCM 토큰 관리 / 푸시 알림 룰** — Phase 3 후속.
  - **회원 정지 / 강제 탈퇴 기능** — Phase 3+ admin 기능. role 에 `suspended` 추가 등은 본 phase 비범위 (기존 4개 role 만 다룬다).
  - **custom claims 마이그레이션** — 본 phase 는 `users/{uid}.role` 필드 기반. 추후 성능 이슈 시 custom claims 로 전환은 별 task.
  - **rate limit / abuse 차단** — 별 task.
  - **Firestore 트랜잭션 / batch write 패턴 변경** — 룰 통과를 위해 클라이언트가 단일 update 를 여러 update 로 쪼개야 한다면 follow-up task 로 분리.

---

## 요구사항

### 기능 요구사항

- [ ] `firestore.rules` 파일을 repo 루트에 생성 (Firebase 기본 위치).
- [ ] `firebase.json` 의 `"firestore"` 섹션에 `"rules": "firestore.rules"` 추가 (현재는 `"indexes"` 만 있음).
- [ ] 본 spec 의 **컬렉션 권한 매트릭스** 를 모두 반영.
- [ ] 본 spec 의 **helper function** 들을 룰 상단에 정의 (재사용 + 가독성).
- [ ] **orders 컬렉션** 의 write 분기 (create / status 전이 / refundRequest / refundRequest.deniedAt 제한) 를 정확히 구현.
- [ ] **role 전이** (customer ↔ owner ↔ brand) 정책을 정확히 구현. brandId 필드도 함께 검증.
- [ ] **마스터 데이터** (`mainCategories`, `subCategories` legacy global, `optionGroups` master) 는 admin 만 write.
- [ ] 인증 안 된 사용자는 어떤 컬렉션도 read/write 불가 (단, 가입 직후 `users/{uid}` self-create 만 예외).
- [ ] 기존 임시 룰을 대체. **임시 룰 만료(2027-12-31) 이전에 배포** 해 만료 후 전체 차단되는 사고 방지.
- [ ] `firebase deploy --only firestore:rules` 로 배포되도록 검증.

### UI 요구사항

- 본 task 는 UI 변경 없음. designer 호출 불필요.

### 상태 요구사항

- 본 task 는 화면 상태 요구사항 없음. 다만 룰 위반 시 클라이언트가 `permission-denied` 를 받게 되므로, 기존 화면의 error 핸들링이 정상 동작하는지 tester 가 회귀 검증.

---

## 데이터 모델

본 task 는 신규 entity / model 을 추가하지 않는다. 기존 컬렉션의 **필드 / 접근 패턴** 만 룰 작성에 사용한다. 각 컬렉션의 단일 진실원은 `lib/data/datasources/remote/*.dart` 와 `lib/core/constants/firestore_paths.dart`.

### 컬렉션 인벤토리 (룰 작성 대상)

코드를 실제로 읽어 도출한 **전체 컬렉션 목록**. 룰에 모두 명시적으로 등장해야 한다 (누락 = `match /{document=**}` fallback 으로 거부됨).

| # | 경로 | 비고 |
|---|---|---|
| 1 | `users/{uid}` | 본인 + admin. 가입 시 self-create. |
| 2 | `users/{uid}/orderLogs/{logId}` | 본인 read. write 는 Cloud Function 만 (verifyTossPayment). |
| 3 | `users/{uid}/favoriteStores/{storeId}` | 본인만. |
| 4 | `users/{uid}/favoriteMenuItems/{compositeId}` | 본인만. |
| 5 | `orders/{orderId}` | 핵심. 본인 / 매장 점주 / admin read. write 분기 다수. |
| 6 | `stores/{storeId}` | 모두 read (인증 사용자). ownerId + admin write. status 전이는 admin. |
| 7 | `stores/{storeId}/subCategories/{id}` | 모두 read, 점주 + admin write. |
| 8 | `stores/{storeId}/menuItems/{id}` | 모두 read, 점주 + admin write. (점포 한정 메뉴 — 승인 대기 status 포함) |
| 9 | `stores/{storeId}/menuOverrides/{masterMenuItemId}` | 모두 read, 점주 + admin write. |
| 10 | `stores/{storeId}/optionGroups/{id}` | 모두 read, 점주 + admin write. |
| 11 | `brands/{brandId}` | 모두 read, brand 본인(ownerId/brandId 일치) + admin write. status 전이는 admin. |
| 12 | `brands/{brandId}/menuItems/{id}` | 모두 read, 해당 brand + admin write. |
| 13 | `brands/{brandId}/subCategories/{id}` | 모두 read, 해당 brand + admin write. |
| 14 | `brands/{brandId}/optionGroups/{id}` | 모두 read, 해당 brand + admin write. |
| 15 | `mainCategories/{id}` | 모두 read, admin only write. |
| 16 | `subCategories/{id}` (legacy global) | 모두 read, admin only write. |
| 17 | `optionGroups/{id}` (master) | 모두 read, admin only write. |
| 18 | `reviews/{reviewId}` | (현 시점 사용 없음 — 경로 상수만 존재. 본 phase 에서는 **인증된 사용자 read + 본인 작성자만 write** 로 안전한 기본값 부여. 실제 도입 시 별 task 에서 보강.) |
| 99 | 그 외 모든 경로 | 명시적 deny (`match /{document=**} { allow read, write: if false; }`) |

### 컬렉션 권한 매트릭스 (요약)

표기:
- `O` = 허용 (조건부 포함)
- `X` = 거부
- `(CF)` = Cloud Function 만 가능 (클라이언트 차단)
- `self` = 본인 (`request.auth.uid == resource.uid` 등)
- `owner` = 매장 점주 (`stores/{storeId}.ownerId == auth.uid`)
- `brand` = 브랜드 보유자 (`users/{auth.uid}.role == 'brand' && users/{auth.uid}.brandId == brandId`)
- `admin` = `users/{auth.uid}.role == 'admin'`
- `auth` = 로그인 된 사용자 (role 무관)
- `unauth` = 비로그인

| 컬렉션 | read | create | update | delete |
|---|---|---|---|---|
| `users/{uid}` | self, admin | self (가입 직후) | self (제한 필드만), admin | admin |
| `users/{uid}/orderLogs/{logId}` | self, admin | (CF) | (CF) | admin |
| `users/{uid}/favoriteStores/{storeId}` | self | self | self | self |
| `users/{uid}/favoriteMenuItems/{id}` | self | self | self | self |
| `orders/{orderId}` | self(userId), owner(매장 점주), admin | (CF) | self / owner / admin (필드별 분기, 아래 §orders update 분기 참조) | admin |
| `stores/{storeId}` | auth | owner 본인 (ownerId == auth.uid), admin | owner / brand(brandId 일치) / admin (필드별 분기, status 전이는 admin only) | owner, admin |
| `stores/{storeId}/{sub}` (subCategories/menuItems/menuOverrides/optionGroups) | auth | owner of store, brand(매장의 brandId 일치), admin | 동일 | 동일 |
| `brands/{brandId}` | auth | admin / brand 자가 신청자 (submittedBy=uid, status='pending', brandKey='' 강제 — U-1 2단계) | brand(본인) / admin (필드별 분기, status 전이는 admin only, brandKey 는 admin only) | admin |
| `brands/{brandId}/{sub}` (menuItems/subCategories/optionGroups) | auth | brand 본인, admin | 동일 | 동일 |
| `mainCategories/{id}` | auth | admin | admin | admin |
| `subCategories/{id}` (legacy global) | auth | admin | admin | admin |
| `optionGroups/{id}` (master) | auth | admin | admin | admin |
| `reviews/{reviewId}` | auth | self (작성자 == auth.uid) | self | self, admin |
| 그 외 | X | X | X | X |

---

## helper functions

룰 상단에 아래 함수를 정의해 재사용. `get()` 호출은 트랜잭션당 10건 제한이 있으므로 helper 안에서 한 번만 fetch 하고 결과를 활용.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ─── helper functions ─────────────────────────────────────────────────

    function isSignedIn() {
      return request.auth != null;
    }

    function uid() {
      return request.auth.uid;
    }

    function userDoc() {
      return get(/databases/$(database)/documents/users/$(uid())).data;
    }

    function userRole() {
      // users/{uid}.role 이 없으면 'customer' 로 간주.
      return isSignedIn() && exists(/databases/$(database)/documents/users/$(uid()))
        ? userDoc().role
        : 'customer';
    }

    function isAdmin() {
      return isSignedIn() && userRole() == 'admin';
    }

    function isOwner() {
      return isSignedIn() && userRole() == 'owner';
    }

    function isBrand() {
      return isSignedIn() && userRole() == 'brand';
    }

    // 매장 점주 여부 (storeId 기준).
    function isStoreOwner(storeId) {
      return isSignedIn()
        && get(/databases/$(database)/documents/stores/$(storeId)).data.ownerId == uid();
    }

    // brand 본인 여부 (brandId 기준).
    // users/{uid}.brandId 가 brandId 와 일치할 때.
    function isBrandHolder(brandId) {
      return isBrand() && userDoc().brandId == brandId;
    }

    // update 시 특정 필드들 외에는 변경 불가하도록 강제.
    function onlyChangedFields(allowedFields) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(allowedFields);
    }

    // create 시 특정 필드들만 허용 (선택적 사용 — 본 spec 은 주로 update 에서 사용).
    function onlyHasFields(allowedFields) {
      return request.resource.data.keys().hasOnly(allowedFields);
    }

    // ... (각 컬렉션 match 블록)
  }
}
```

### helper 선택 원칙

- **권한 체크는 가능한 한 helper 로** — 가독성. 단, `get()` 은 1 회 호출당 read 1 회 비용이 발생하므로 동일 룰 안에서 중복 호출은 피한다 (룰 엔진이 자동 캐싱하지 않음).
- **role 검증은 `userRole()` 한 함수로 통일** — 추후 custom claims 마이그레이션 시 이 함수 1곳만 교체.
- **role 변경 update 룰은 `userDoc()` 을 호출하지 않는다** — 본인 update 자체는 self 체크만 하면 되므로. 단, role 값 자체에 대한 enum 검증은 룰 안에서 직접 수행.

---

## 레이어 설계

본 task 는 Flutter / TypeScript 코드 레이어 변경이 없다. 산출물은 **Firestore 룰 파일** 과 **Firebase 설정 파일** 만이다.

### 산출 파일

```
/firestore.rules         # 신규 — 본 spec 의 모든 룰
/firebase.json           # 수정 — firestore 섹션에 "rules" 추가
```

### `firebase.json` diff

```diff
 {
   "firestore": {
+    "rules": "firestore.rules",
     "indexes": "firestore.indexes.json"
   },
   ...
 }
```

### 데이터 흐름 (룰 평가)

```text
Client SDK 의 read/write 요청
  → Firestore 룰 엔진
  → helper functions (필요 시 users/{uid} get 1회)
  → match /{컬렉션}/{문서} 블록
  → allow read / create / update / delete 판단
  → 허용 → Firestore 에 반영 → 클라이언트에 결과 전송
  → 거부 → permission-denied → 클라이언트 SDK 에 예외 throw
```

Cloud Functions 는 Admin SDK 를 사용하므로 룰 우회. (verifyTossPayment / cancelTossPayment / processRefund 는 본 룰 영향 받지 않음.)

---

## orders update 분기 상세

`orders/{orderId}` 의 update 는 본 phase 의 가장 복잡한 부분이므로 분기별로 분리한다.

### 허용되는 update 케이스

| # | 트리거 | actor | 허용 필드 | 조건 |
|---|---|---|---|---|
| O1 | 매장 점주가 paid → accepted 전이 (`OrderRepositoryImpl.setAcceptedByOwner`) | `isStoreOwner(resource.data.storeId)` | `status`, `acceptedAt`, `updatedAt` | `resource.data.status == 'paid'` && `request.resource.data.status == 'accepted'` |
| O2 (Phase 3c-1 정책 변경 — 2026-06-07) | 본인이 환불 요청 (`OrderRepositoryImpl.requestRefund`) | `resource.data.userId == uid()` | `refundRequest`, `updatedAt` | `resource.data.refundRequest == null` (또는 deniedAt == null 인 케이스로 갱신 불가). **status 가 `accepted` 일 때만** (이전: `accepted` / `making` / `ready` / `completed` — Phase 3c-1 결정 F / Q7 로 `accepted` 단독 축소). `paid` 는 cancel 흐름으로. `making` / `ready` / `completed` 에서는 시스템 단 차단 (카페 픽업 도메인 — 조리 시작 = 음료 폐기 비용 발생 시점). |
| O3 | 점주가 환불 요청 거절 (`OrderRepositoryImpl.denyRefundRequest`) | `isStoreOwner(resource.data.storeId)` | `refundRequest.deniedAt`, `refundRequest.deniedReason`, `updatedAt` | `resource.data.refundRequest != null` && `resource.data.refundRequest.deniedAt == null` |
| O4 | admin 의 임의 수정 | `isAdmin()` | (모든 필드) | 무조건 허용 (운영 대응용) |
| **O5** (Phase 3c-1 신규 — 2026-06-07) | 점주 조리 시작 (`OrderRepositoryImpl.startMakingOrder`) | `isStoreOwner(resource.data.storeId)` | `status`, `makingStartedAt`, `updatedAt` | `resource.data.status == 'accepted'` && `request.resource.data.status == 'making'` |
| **O6** (Phase 3c-1 신규 — 2026-06-07) | 점주 준비 완료 (`OrderRepositoryImpl.markOrderReady`) | `isStoreOwner(resource.data.storeId)` | `status`, `readyAt`, `updatedAt` | `resource.data.status == 'making'` && `request.resource.data.status == 'ready'` |
| **O7** (Phase 3c-1 신규 — 2026-06-07) | 점주 픽업 완료 (`OrderRepositoryImpl.markOrderCompleted`) | `isStoreOwner(resource.data.storeId)` | `status`, `completedAt`, `updatedAt` | `resource.data.status == 'ready'` && `request.resource.data.status == 'completed'` |

### 차단되는 update 케이스

- **클라이언트가 직접 `status` 를 'cancelled' / 'refunded' 로 전이** — 차단. Cloud Function 만 가능 (admin SDK).
- ~~`status` 를 'making' / 'ready' / 'completed' 로 클라이언트 전이 차단~~ — **Phase 3c-1 정책 변경**: 점주(매장 owner) 본인은 O5/O6/O7 분기로 허용. 일반 클라이언트는 차단 유지 (`isStoreOwner()` 미통과).
- **클라이언트가 `paymentInfo` / `cancelInfo` / `refundInfo` / `userId` / `storeId` / `totalPrice` / `items` 등 핵심 필드 수정** — 차단.
- **재환불 요청** (`refundRequest.deniedAt` 이 있는데 다시 `refundRequest` 를 새 값으로 덮어쓰기) — 차단.
- **환불 요청 — `making` / `ready` / `completed` 상태에서 시도** (Phase 3c-1 결정 F / Q7) — 차단. O2 가 `status == 'accepted'` 만 허용.

### 룰 의사 코드

```text
match /orders/{orderId} {
  allow read: if isAdmin()
              || (isSignedIn() && resource.data.userId == uid())
              || (isSignedIn() && isStoreOwner(resource.data.storeId));

  // 클라이언트 직접 생성 차단. 모든 생성은 verifyTossPayment 만.
  allow create: if false;

  // delete 는 admin 만.
  allow delete: if isAdmin();

  // update 는 actor 별 분기.
  allow update: if isAdmin()
                || isOwnerAcceptUpdate()           // O1
                || isCustomerRefundRequest()       // O2 (Phase 3c-1: status='accepted' 만 허용)
                || isOwnerDenyRefund()             // O3
                || isOwnerStartMakingUpdate()      // O5 (Phase 3c-1 신규)
                || isOwnerMarkReadyUpdate()        // O6 (Phase 3c-1 신규)
                || isOwnerCompletePickupUpdate(); // O7 (Phase 3c-1 신규)

  function isOwnerAcceptUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'paid'
      && request.resource.data.status == 'accepted'
      && onlyChangedFields(['status', 'acceptedAt', 'updatedAt']);
  }

  // ─────────── O2 — Phase 3c-1 결정 F / Q7 (2026-06-07) 로 status 축소 ───────────
  // 환불 요청 허용 status: ['accepted', 'making', 'ready', 'completed'] → 'accepted' 만.
  // 사유: 카페 픽업 도메인 표준 — 조리 시작 (making) = 음료 폐기 비용 발생 시점.
  function isCustomerRefundRequest() {
    return resource.data.userId == uid()
      && resource.data.status == 'accepted'        // ⬅ 'accepted' 만 (축소)
      // 새로 요청하거나 (refundRequest 가 null), 거절된 적 없는 경우만.
      && (resource.data.refundRequest == null
          || resource.data.refundRequest.deniedAt == null)
      && onlyChangedFields(['refundRequest', 'updatedAt'])
      // refundRequest 안의 status 핵심 필드는 변조 불가. requestedAt, reason 만.
      && request.resource.data.refundRequest.keys().hasOnly(['reason', 'requestedAt']);
  }

  function isOwnerDenyRefund() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.refundRequest != null
      && resource.data.refundRequest.deniedAt == null
      // dot-path update: refundRequest.deniedAt, refundRequest.deniedReason.
      // diff().affectedKeys() 는 top-level 만 보므로 refundRequest 전체가 변경된 것으로 보임.
      && onlyChangedFields(['refundRequest', 'updatedAt'])
      // 거절 후의 refundRequest 는 요청 시 필드 + deniedAt + deniedReason 만.
      && request.resource.data.refundRequest.keys()
          .hasOnly(['reason', 'requestedAt', 'deniedAt', 'deniedReason']);
  }

  // ─────────── O5 — Phase 3c-1 신규 (점주 조리 시작) ───────────
  // accepted → making. timestamp 필드 makingStartedAt 함께 set.
  function isOwnerStartMakingUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'accepted'
      && request.resource.data.status == 'making'
      && onlyChangedFields(['status', 'makingStartedAt', 'updatedAt']);
  }

  // ─────────── O6 — Phase 3c-1 신규 (점주 준비 완료) ───────────
  // making → ready. timestamp 필드 readyAt 함께 set.
  function isOwnerMarkReadyUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'making'
      && request.resource.data.status == 'ready'
      && onlyChangedFields(['status', 'readyAt', 'updatedAt']);
  }

  // ─────────── O7 — Phase 3c-1 신규 (점주 픽업 완료, 종결 상태) ───────────
  // ready → completed. timestamp 필드 completedAt 함께 set. 종결 상태이므로 이후 추가 전이 없음.
  function isOwnerCompletePickupUpdate() {
    return isStoreOwner(resource.data.storeId)
      && resource.data.status == 'ready'
      && request.resource.data.status == 'completed'
      && onlyChangedFields(['status', 'completedAt', 'updatedAt']);
  }
}
```

> **O5/O6/O7 공통 패턴**: actor 검증 (`isStoreOwner`) + 이전 status 검증 + 다음 status 검증 + 화이트리스트 (`status`, `<status>At`, `updatedAt`) 정확히 3개. O1 (`isOwnerAcceptUpdate`) 의 패턴을 그대로 이어가므로 drift 위험 없음.
>
> **Repository 와의 drift 방지**: `OrderRepositoryImpl.startMakingOrder` / `markOrderReady` / `markOrderCompleted` 가 set 하는 키 집합이 위 화이트리스트와 정확히 동일해야 함. Phase 3c-1 implementation.md 의 drift cross-check 표 참조.

> 결정 R1 — **`OrderRepositoryImpl.denyRefundRequest` 가 현재 `refundRequest.deniedAt` 같은 dot-path 로 partial update 하고 있다.** Firestore 룰의 `request.resource.data.refundRequest.keys()` 가 dot-path 일 때 어떻게 평가되는지는 룰 엔진의 merge 결과 기준이므로 룰이 정상 통과한다. tester 가 emulator 로 반드시 확인할 항목 (T-O3-2).

---

## role 변경 흐름 (users/{uid})

코드 분석 결과 role 변경은 **클라이언트가 `UserRepositoryImpl.updateRole` → `UserRemoteDataSource.updateRole` 로 직접 `users/{uid}.role` 을 update** 한다. Cloud Function 경유 아님. 룰이 이를 적절히 검증해야 한다.

### 현재 클라이언트가 수행하는 role 전이

| UseCase | 전이 | 추가 변경 |
|---|---|---|
| `UpgradeToOwnerUseCase` | `customer → owner` | (없음. role 만) |
| `UpgradeToBrandUseCase` | `customer → brand` 또는 `owner → brand` (자가 신청 단계) | role 만 update. `brandId` 는 이 단계에서 박지 않음. 실제 권한 부여는 admin 승인 단계의 `BrandRepositoryImpl.upsertBrand` batch write 에서 `brandId` 가 박힘 |
| `DowngradeToCustomerUseCase` | `owner → customer` / `brand → customer` | role 만. |

### role 전이 룰

- **본인이 `customer ↔ owner` 자유롭게 전이 가능** — Phase 3a 현재 정책. (`/more` → "점주로 등록하기" 흐름. 가입 게이트 없음.)
- **`customer/owner → brand` 자가 신청 허용** (U-1 결정의 1단계). 단순 신청자 상태이며 실제 brand 권한은 부여되지 않음 — `users/{uid}.brandId` 가 비어 있는 한 `isBrandHolder()` 가 false 이므로 마스터 메뉴 / 가맹점 nested 컬렉션 write 차단.
- **실제 brand 권한 게이트는 두 조건의 곱** — (a) `users/{uid}.role == 'brand'` + (b) `users/{uid}.brandId == 대상 brandId`. 두 조건 모두 만족해야 `isBrandHolder(brandId)` 통과. (b) 의 set 은 `BrandRepositoryImpl.upsertBrand` 의 batch write 에서만 일어나며, rule 은 `brandId` 의 self-set 을 "현재 비어있음 → value" 1회만 허용 (이미 박힌 경우 변경 차단).
- **brand → customer / brand → owner 본인 다운그레이드 허용** — 클라이언트의 `DowngradeToCustomerUseCase` 케이스. (admin 운영 부담 최소화).
- **`admin` 으로의 자가 승격은 어떤 경우에도 차단** — rule 의 `isAllowedSelfRoleChange` 에 `admin` 도착 케이스 없음.
- **`brandId` 임의 set / 변경 차단** — 위의 "1회만 empty → value 허용" 정책. 이미 박힌 `brandId` 의 변경은 admin 만 가능 (다른 브랜드 데이터 권한 탈취 방지).

### `users/{uid}` update 분기 (의사 코드)

```text
match /users/{userId} {
  allow read: if isAdmin() || (isSignedIn() && uid() == userId);

  // 가입 직후 self-create. uid 가 자기 자신이고 role='customer' 인 doc 만 허용.
  allow create: if isSignedIn()
                && uid() == userId
                && request.resource.data.role == 'customer'
                && !('brandId' in request.resource.data);

  allow delete: if isAdmin();

  allow update: if isAdmin()
                || isSelfProfileUpdate(userId);

  function isSelfProfileUpdate(userId) {
    return isSignedIn()
      && uid() == userId
      // 변경 가능한 필드. uid / createdAt / provider 는 immutable.
      // brandId 는 변경 가능 필드에 포함하되 별도 게이트 (현재 empty 일 때만).
      && onlyChangedFields(['role', 'displayName', 'photoUrl', 'fcmToken', 'updatedAt', 'brandId'])
      // role 변경의 경우 허용 전이만.
      && (
        request.resource.data.get('role', 'customer') == resource.data.get('role', 'customer')
        || isAllowedSelfRoleChange(
            resource.data.get('role', 'customer'),
            request.resource.data.get('role', 'customer')
          )
      )
      // brandId: 현재 비어있을 때만 set 허용 (BrandRepositoryImpl.upsertBrand 의 batch write 가
      // 신규 brand doc 생성과 함께 박는 1회의 set 만 허용). 이미 박힌 brandId 변경 차단.
      && (
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['brandId'])
        || resource.data.get('brandId', '') == ''
      );
  }

  // U-1 결정 반영: brand 가입은 2단계.
  //   1) 자가 신청: customer/owner → brand 허용. 단순 신청자 상태.
  //   2) admin 승인: brands/{brandId}.status='approved' 박힌 뒤 isBrandHolder() 통과로 실제 권한 부여.
  // admin 자가 승격은 어떤 경우에도 차단.
  function isAllowedSelfRoleChange(from, to) {
    return (from == 'customer' && to == 'owner')
        || (from == 'owner' && to == 'customer')
        || (from == 'customer' && to == 'brand')  // U-1: 자가 신청
        || (from == 'owner' && to == 'brand')      // U-1: 자가 신청
        || (from == 'brand' && to == 'customer')   // 본인 다운그레이드
        || (from == 'brand' && to == 'owner');     // 본인 다운그레이드
  }
}
```

### 부작용 검토

- U-1 결정의 2단계 흐름 (자가 신청 + admin 승인) 이 본 룰에 정확히 반영됨.
  - `UpgradeToBrandUseCase` (`lib/domain/usecases/upgrade_to_brand_use_case.dart`) 의 자가 호출은 1단계 (단순 신청자 등록) 로 룰 통과.
  - `BrandRepositoryImpl.upsertBrand` 의 batch write 가 `users/{uid}.brandId = newBrandId` 를 박는 것은 "brandId 가 현재 비어있을 때만 set 허용" 게이트로 룰 통과.
  - admin 승인 단계의 `BrandRepositoryImpl.approveBrand` 는 admin 권한으로 `brands.status='approved'` + `brandKey` 발급. 이때 비로소 `isBrandHolder(brandId)` 통과.
  - 결과적으로 admin 승인 전에는 brand role 사용자가 마스터 메뉴 / 가맹점 nested 컬렉션 write 불가 (안전).

---

## 마스터 데이터 (admin only write)

다음 컬렉션은 모두 **인증된 사용자 read + admin write**.

- `mainCategories/{id}`
- `subCategories/{id}` (legacy global. brand/store nested 와 구분)
- `optionGroups/{id}` (master. brand/store nested 와 구분)

### 시드 함수

`MainCategoryRemoteDataSource.seedDefaultsIfEmpty()` 는 클라이언트에서 호출 가능하다. 본 룰 도입 시 일반 사용자가 시드를 실행하면 `permission-denied` 발생. 처음 한 번은 admin 계정으로 시드하거나 Cloud Function 으로 옮긴다.

- **결정 R2** — 시드 함수는 운영자가 admin 계정 1회 호출. 추후 자동화는 Cloud Function 으로 이동 (별 task).

---

## stores 및 nested 권한

### `stores/{storeId}`

- `read`: 인증된 사용자 누구나.
- `create`: 점주(`isOwner()`) 가 본인 ownerId 로 매장 등록. `request.resource.data.ownerId == uid()` 강제. `status` 는 `'pending'` 으로 시작.
- `update`:
  - 점주 본인 (`ownerId == uid()`) 또는 brand (`isBrandHolder(resource.data.brandId)`) 가 운영 필드 (`name, imageUrl, location, phone, address, description, menuCategories, businessHours, ...`) 수정 가능.
  - **status 전이 (pending → approved / rejected)** 는 admin 만.
  - **ownerId / brandId** 는 한 번 set 된 뒤 immutable (admin 만 수정 가능).
- `delete`: ownerId 본인 + admin.

### `stores/{storeId}/{sub}` (subCategories / menuItems / menuOverrides / optionGroups)

- `read`: 인증된 사용자 누구나.
- `create / update / delete`:
  - 점주 (`isStoreOwner(storeId)`) 또는
  - brand (`isBrandHolder(get(stores/{storeId}).data.brandId)`) 또는
  - admin.

> brand 가 자기 가맹점 매장의 menuOverride / subCategory 를 수정하는 흐름이 존재하는지 확인 필요. 본 spec 은 **존재한다고 가정** 하고 권한 부여. 사용자 확인 항목 U-3.

---

## brands 및 nested 권한

### `brands/{brandId}`

- `read`: 인증된 사용자 누구나.
- `create`: admin 또는 **brand 자가 신청자** (U-1 2단계). brand 자가 신청자의 조건:
  - `isBrand()` (role='brand' 자가 신청 1단계 완료 상태)
  - `request.resource.data.submittedBy == uid()`
  - `request.resource.data.status == 'pending'`
  - `request.resource.data.brandKey == ''` (승인 전 미발급 강제)
- `update`:
  - brand 본인 (`isBrandHolder(brandId)`) 이 운영 필드 수정.
  - **status 전이** 및 `brandKey` / `approvedBy` / `approvedAt` / `createdAt` 변경은 admin 만 (`isBrandSelfUpdate` 에서 명시적 차단).
- `delete`: admin.

### `brands/{brandId}/{sub}` (menuItems / subCategories / optionGroups)

- `read`: 인증된 사용자 누구나.
- `create / update / delete`: `isBrandHolder(brandId)` + admin.

---

## reviews

코드상 `FirestorePaths.reviews = 'reviews'` 경로만 존재하고 datasource 는 아직 없다. 본 phase 는 안전한 기본값:

- `read`: 인증된 사용자.
- `create`: 작성자 == `uid()` && `request.resource.data.userId == uid()`.
- `update`: 본인 (작성자) 만.
- `delete`: 본인 + admin.

실제 리뷰 기능 도입 시 별 task 로 보강.

---

## 에러 처리

룰 거부 시 클라이언트는 `FirebaseException(code: 'permission-denied')` 를 받는다. 본 task 의 에러 처리 책임 분담:

| 케이스 | 처리 방식 |
|---|---|
| 정상 흐름이 룰에 막힘 | tester 가 회귀 케이스로 발견 → developer 가 follow-up 으로 룰 보강 또는 클라이언트 update 패턴 수정 |
| 임시 룰 만료 (2027-12-31) | 본 task 배포로 영구 대체. 별도 처리 불필요 |
| 룰 배포 실패 | `firebase deploy --only firestore:rules` 가 syntax error 를 콘솔에 표시. CI 에서 `firebase firestore:rules:test` 또는 `firebase emulators:exec` 로 사전 검증 권장 (follow-up) |
| 신규 컬렉션 추가 시 룰 누락 | 본 spec 의 컬렉션 인벤토리 표를 매 phase 갱신. spec 변경 없으면 거부됨 (`{document=**}` deny) |

---

## 테스트 시나리오

각 케이스는 emulator 또는 운영 콘솔에서 시뮬레이션 가능. tester 는 **Firebase Emulator (`firebase emulators:start --only firestore`)** + **rules unit test (`@firebase/rules-unit-testing`)** 를 사용해 자동화하거나, 콘솔의 "Rules Playground" 로 수동 검증.

> 결정 R3 — 자동화 테스트 도입은 권장이나, 본 phase 의 산출물은 룰 파일 + 배포까지. unit test 도입은 follow-up task. tester 는 최소한 콘솔 Playground 로 아래 표의 모든 케이스를 통과시켜야 한다.

### users

| ID | 시나리오 | 기대 |
|---|---|---|
| T-U-1 | unauth 가 임의 users 문서 read | DENY |
| T-U-2 | self user 가 자신의 doc read | ALLOW |
| T-U-3 | self user 가 다른 사용자 doc read | DENY |
| T-U-4 | admin 이 임의 사용자 doc read | ALLOW |
| T-U-5 | self user 가 자신의 displayName/photoUrl update | ALLOW |
| T-U-6 | self user 가 자신의 role: customer → owner | ALLOW |
| T-U-7 | self user 가 자신의 role: customer → brand (U-1 1단계 자가 신청) | ALLOW |
| T-U-7a | brand role 사용자가 brandId=null 상태에서 `brands/{brandId}/menuItems` write 시도 (U-1 2단계 미승인) | DENY (`isBrandHolder()` false) |
| T-U-7b | brand role 사용자가 자기 brand doc 생성 (submittedBy=uid, status='pending', brandKey='') | ALLOW (V2-1 자가 신청 폼 제출) |
| T-U-7c | admin 승인 후 brand 사용자가 자기 brandId 의 nested 컬렉션 write | ALLOW (`isBrandHolder()` true) |
| T-U-8 | self user 가 자신의 role: customer → admin | DENY |
| T-U-9 | self user 가 자신의 brandId 를 empty → value 로 1회 set (V2-1 batch write) | ALLOW |
| T-U-9a | self user 가 이미 박힌 brandId 를 다른 값으로 변경 시도 | DENY |
| T-U-10 | admin 이 임의 사용자 role / brandId 변경 | ALLOW |
| T-U-11 | self user 가 자신의 uid / createdAt / provider 수정 | DENY |
| T-U-12 | 가입 직후 self-create (role='customer') | ALLOW |
| T-U-13 | self-create 시 role='admin' 시도 | DENY |

### users/orderLogs

| ID | 시나리오 | 기대 |
|---|---|---|
| T-OL-1 | self 가 자신의 orderLogs read | ALLOW |
| T-OL-2 | self 가 자신의 orderLogs create | DENY (CF 만) |
| T-OL-3 | 다른 사용자가 타인 orderLogs read | DENY |
| T-OL-4 | admin 이 임의 orderLogs read | ALLOW |

### favorites

| ID | 시나리오 | 기대 |
|---|---|---|
| T-F-1 | self 가 자신의 favoriteStores CRUD | ALLOW |
| T-F-2 | 다른 사용자가 타인 favoriteStores CRUD | DENY |
| T-F-3 | favoriteMenuItems 동일 | ALLOW / DENY |

### orders

| ID | 시나리오 | 기대 |
|---|---|---|
| T-O-1 | 본인이 자기 orders read | ALLOW |
| T-O-2 | 점주가 자기 매장 orders read | ALLOW |
| T-O-3 | 본인이 타인 orders read | DENY |
| T-O-4 | admin 이 임의 orders read | ALLOW |
| T-O-5 | 클라이언트가 orders create 시도 | DENY |
| T-O-O1-1 | 점주가 paid → accepted (자기 매장 주문) | ALLOW |
| T-O-O1-2 | 점주가 다른 매장 주문 status 변경 시도 | DENY |
| T-O-O1-3 | customer 가 status 임의 변경 시도 | DENY |
| T-O-O2-1 | 본인이 accepted 주문에 refundRequest 추가 | ALLOW |
| T-O-O2-2 | 본인이 paid 주문에 refundRequest 추가 | DENY (paid 는 cancel 흐름) |
| **T-O-O2-3** (Phase 3c-1 — 결정 F / Q7) | 본인이 `making` / `ready` / `completed` 상태 주문에 refundRequest 추가 시도 | **DENY** (Phase 3c-1 O2 축소 — `status == 'accepted'` 만 허용. 카페 픽업 도메인 표준 — 조리 시작 = 음료 폐기 비용 발생 시점) |
| T-O-O3-1 | 점주가 자기 매장 refundRequest deny | ALLOW |
| T-O-O3-2 | 점주가 deny 된 refundRequest 를 본인이 다시 요청 | DENY (재요청 차단) |
| T-O-O3-3 | customer 가 refundRequest 의 deniedAt 을 임의 set | DENY |
| **T-O-O5-1** (Phase 3c-1 신규) | 점주가 accepted → making 전이 (자기 매장 주문, payload = `{status, makingStartedAt, updatedAt}`) | ALLOW |
| **T-O-O5-2** | 점주가 paid 주문에 직접 making 시도 | DENY (resource.status != 'accepted') |
| **T-O-O5-3** | 점주가 다른 매장 주문에 making 시도 | DENY (`isStoreOwner` 미통과) |
| **T-O-O5-4** | 점주가 accepted→making 시 화이트리스트 외 필드 (`totalPrice` 등) 함께 변경 시도 | DENY (`onlyChangedFields` 위반) |
| **T-O-O6-1** (Phase 3c-1 신규) | 점주가 making → ready 전이 (자기 매장 주문, payload = `{status, readyAt, updatedAt}`) | ALLOW |
| **T-O-O6-2** | 점주가 accepted 주문에 직접 ready 시도 | DENY (resource.status != 'making') |
| **T-O-O6-3** | 점주가 다른 매장 주문에 ready 시도 | DENY |
| **T-O-O7-1** (Phase 3c-1 신규) | 점주가 ready → completed 전이 (자기 매장 주문, payload = `{status, completedAt, updatedAt}`) | ALLOW |
| **T-O-O7-2** | 점주가 making 주문에 직접 completed 시도 | DENY (resource.status != 'ready') |
| **T-O-O7-3** | 점주가 다른 매장 주문에 completed 시도 | DENY |
| **T-O-O7-4** | 점주가 ready→completed 시 화이트리스트 외 필드 함께 변경 시도 | DENY |
| T-O-5 | 클라이언트가 status='cancelled' / 'refunded' 직접 set | DENY (CF 만) |
| T-O-6 | 클라이언트가 totalPrice / items 수정 | DENY |
| T-O-7 | admin 이 임의 필드 update | ALLOW |
| T-O-8 | 클라이언트가 delete | DENY |

### stores

| ID | 시나리오 | 기대 |
|---|---|---|
| T-S-1 | auth user 가 매장 read | ALLOW |
| T-S-2 | unauth 가 매장 read | DENY |
| T-S-3 | owner role 사용자가 ownerId=self 로 매장 create | ALLOW |
| T-S-4 | customer role 이 매장 create 시도 | DENY |
| T-S-5 | 점주가 다른 사람 ownerId 로 매장 create 시도 | DENY |
| T-S-6 | 점주가 자기 매장 운영 필드 update | ALLOW |
| T-S-7 | 점주가 자기 매장 status 를 'approved' 로 변경 | DENY (admin 만) |
| T-S-8 | admin 이 status 'pending' → 'approved' | ALLOW |
| T-S-9 | 점주가 자기 매장 ownerId 를 다른 uid 로 변경 | DENY |
| T-S-10 | brand 가 자기 brandId 의 매장 운영 필드 update | ALLOW |
| T-S-11 | 점주가 다른 점주 매장 update 시도 | DENY |

### stores/{storeId}/{sub}

| ID | 시나리오 | 기대 |
|---|---|---|
| T-SS-1 | auth user 가 menuItems / menuOverrides read | ALLOW |
| T-SS-2 | 점주가 자기 매장 menuOverrides CRUD | ALLOW |
| T-SS-3 | brand 가 자기 brandId 매장의 menuOverrides CRUD | ALLOW |
| T-SS-4 | 다른 점주가 타 매장 menuItems CRUD | DENY |

### brands

| ID | 시나리오 | 기대 |
|---|---|---|
| T-B-1 | auth user 가 brand read | ALLOW |
| T-B-2 | brand 본인이 brand 운영 필드 update | ALLOW |
| T-B-3 | brand 가 자기 status 'pending' → 'approved' | DENY (admin 만) |
| T-B-4 | brand 가 다른 brand 의 menuItems CRUD | DENY |
| T-B-5 | brand 본인이 자기 menuItems CRUD (admin 승인 후 — brandId 박힌 상태) | ALLOW |
| T-B-6 | brand role 자가 신청자 (brandId=null) 가 본인 brand doc 생성 (submittedBy=uid, status='pending', brandKey='') | ALLOW (U-1 2단계 — 자가 신청 폼 제출) |
| T-B-7 | brand role 자가 신청자가 본인 brand doc 생성 시 status='approved' 시도 | DENY (status 자기 승격 차단) |
| T-B-8 | brand role 자가 신청자가 본인 brand doc 생성 시 brandKey 임의 set | DENY (brandKey 는 admin 승인 시점에만 발급) |
| T-B-9 | brand 본인이 자기 brand doc 의 brandKey / approvedBy / approvedAt 변경 시도 | DENY |

### 마스터 데이터

| ID | 시나리오 | 기대 |
|---|---|---|
| T-M-1 | auth user 가 mainCategories read | ALLOW |
| T-M-2 | unauth 가 mainCategories read | DENY |
| T-M-3 | customer 가 mainCategories write | DENY |
| T-M-4 | admin 이 mainCategories CRUD | ALLOW |
| T-M-5 | customer 가 master optionGroups write | DENY |

### 그 외

| ID | 시나리오 | 기대 |
|---|---|---|
| T-X-1 | 정의되지 않은 임의 컬렉션 read/write | DENY |

---

## 배포 / 마이그레이션

### 배포 명령

```bash
firebase deploy --only firestore:rules
```

성공 시 콘솔 → Firestore → Rules 탭의 최신 버전이 본 룰로 교체된다. 이전 버전은 Firestore 가 자동 보관 (rollback 가능).

### 마이그레이션 단계

1. **emulator 로 dry-run**: `firebase emulators:start --only firestore` 후 본 spec 의 테스트 시나리오를 콘솔 또는 unit test 로 통과.
2. **임시 룰 백업**: 콘솔의 현 룰을 한 번 캡처 (사고 시 즉시 rollback 용).
3. **운영 배포**: `firebase deploy --only firestore:rules`.
4. **회귀 검증**: 운영 환경에서 customer / owner / brand / admin 4계정으로 핵심 흐름 (장보기 + 결제 + 매장관리 + 어드민 승인) 1회 수행.
5. **임시 룰 만료일까지 모니터링**: 운영 중 발생하는 `permission-denied` 로그를 Firebase 콘솔 → Firestore → 통계 에서 1주일 추적.

### 부작용 후보

| 후보 | 원인 | 대응 |
|---|---|---|
| 기존 사용자의 `users/{uid}` doc 에 `role` 필드가 누락된 경우 → `userRole()` 이 'customer' 반환 → admin 이었던 사용자가 차단 | 과거 가입 흐름에서 role 미설정 | 별 task: admin 계정 수동 검증. 본 phase 는 신규 가입자만 정상 흐름 보장 |
| `MainCategoryRemoteDataSource.seedDefaultsIfEmpty` 가 customer 호출 시 차단 | 룰이 admin only | 결정 R2 — admin 1회 호출. 자동화는 별 task |
| `UpgradeToBrandUseCase` 자가 호출 시 동작 | 룰이 self → brand 자가 신청 허용 (U-1 1단계) | 결정 U-1 — 의도된 동작. 자가 신청 → brand 자가 폼 제출 → admin 승인 시점에 실제 권한 부여 (2단계). 사용자가 brand role 만 받고 brand doc 미제출 시에는 BrandScaffold 가 `_BrandIdMissingView` 로 안내 |
| 점포 한정 메뉴 / menuOverrides 의 admin 승인 큐 (status='pending') 가 customer 에게 보이는 문제 | read 가 auth 누구나 허용 | spec 의도대로. 클라이언트가 `status='approved'` 필터로 노출 제어 |
| `firestore.indexes.json` 의 collectionGroup 쿼리 (`menuOverrides` `status` `submittedAt`) 는 admin 만 호출하므로 read 권한이 필요 — 본 룰의 nested read 가 auth 면 허용되므로 무관 | — | — |

---

## 작업 분배

### designer

- UI 변경 없음. **호출 불필요**.

### developer

- 구현 항목:
  - `firestore.rules` 신규 작성 — 본 spec 의 helper / 컬렉션 권한 매트릭스 / orders update 분기 / role 전이 모두 반영.
  - `firebase.json` 의 firestore 섹션에 `"rules": "firestore.rules"` 추가.
  - (선택) `firebase emulators:start` 로 syntax 검증.
- 재사용할 기존 구조:
  - 컬렉션 경로 / 필드명 → `lib/core/constants/firestore_paths.dart` 와 각 datasource 의 시그니처를 단일 진실원으로.
  - role 문자열 → `lib/domain/entities/user_role.dart` (`'customer'` / `'owner'` / `'brand'` / `'admin'`).
- 주의할 레이어 규칙:
  - 본 task 는 Flutter 코드 변경 **없음** 이 원칙. 룰이 강제하는 동작과 충돌하는 클라이언트 호출이 발견되면 spec 의 follow-up 후보로 정리하고 **임의 코드 수정 금지** — architect 에게 보고.
  - Cloud Functions 코드 변경 없음 (Admin SDK 사용 → 룰 우회).
- 산출물: `docs/tasks/firestore_security_rules/implementation.md` — 작성한 룰의 전체 코드 + 결정 R1/R2/R3 + U-1/U-3 에 대한 처리 결과 기록.

### tester

- 주요 검증 기준:
  - 본 spec 의 모든 **테스트 시나리오 표** (T-U / T-OL / T-F / T-O / T-S / T-SS / T-B / T-M / T-X) 의 케이스를 emulator 또는 콘솔 Rules Playground 로 통과시킨다. 각 케이스의 ALLOW / DENY 결과를 `test_report.md` 에 기록.
  - 추가로 4계정 (customer / owner / brand / admin) 으로 운영 환경 핵심 흐름 회귀:
    - customer: 가입 → 매장 탐색 → 카트 → 결제 → 환불 요청
    - owner: 매장 등록 → 운영 → 주문 접수 → 환불 동의 (Cloud Function 호출)
    - brand: 마스터 메뉴 등록 → 가맹점 매장 운영
    - admin: 매장/브랜드 승인 → 마스터 데이터 관리
- 반드시 확인할 예외 케이스:
  - 임시 룰 만료일 (2027-12-31) 이전 / 이후 동작 (배포 후에는 만료일 무관).
  - 기존 user doc 에 role 필드가 없을 때의 동작.
  - `refundRequest.deniedAt` dot-path update 가 룰을 통과하는지 (T-O-O3-1).
  - `MainCategoryRemoteDataSource.seedDefaultsIfEmpty` 호출 결과 (T-M-3 / T-M-4).
- 산출물: `docs/tasks/firestore_security_rules/test_report.md` — 시나리오별 PASS/FAIL, 보류 항목, follow-up 후보 목록.

---

## 사용자 확인 필요 항목

배포 전 사용자 결정이 필요한 항목.

- **U-1. `customer/owner → brand` 가입 정책 — 2단계 흐름**. (2026-05-26 갱신: 자가 신청 + admin 승인 2단계로 확정)
  - **결정**: 자가 신청 허용, 단 실제 brand 권한은 admin 승인 후에만 부여.
  - **1단계 (자가 신청)**: 사용자가 `users/{uid}.role` 을 직접 `'brand'` 로 변경 가능. 허용 전이는 `customer → brand`, `owner → brand`, `brand → customer`, `brand → owner`. 이 단계는 **단순 신청자 상태** — `users/{uid}.brandId` 는 미발급이므로 `isBrandHolder()` 가 통과되지 않아 실제 brand 권한 (마스터 메뉴 / 가맹점 매장 nested 컬렉션 write 등) 은 부여되지 않는다. 클라이언트는 `BrandScaffold` 가 `_BrandIdMissingView` → `BrandInfoFormPage` 로만 진입시킨다.
  - **2단계 (admin 승인)**: brand 등록 폼 제출 시 `brands/{brandId}` doc 이 생성된다 (`status='pending'`, `submittedBy=uid`, `brandKey=''`). 이때 `BrandRepositoryImpl.upsertBrand` 가 **batch write** 로 `users/{uid}.brandId = newBrandId` 를 함께 박는다. 이후 admin 이 `AdminBrandApprovalDetailPage` 에서 승인 → `status='approved'` + `brandKey` 자동 발급 → 비로소 `isBrandHolder(brandId)` 가 통과되어 실제 brand 권한 부여.
  - **설계 사유**:
    - admin 운영 부담 최소화 — 사용자가 폼을 채우는 단계까지 self-service.
    - admin 은 게이트키퍼 역할만 — 자료를 검토하고 승인/반려.
    - 자가 신청 단계에서는 데이터 권한이 0 이므로 보안 위험 없음. 실제 권한 부여 게이트는 `brands.status='approved'` + `users.brandId` 박힘 (배치 set 시점) 두 조건.
  - **명시적 차단**: `admin` 으로의 자가 승격은 어떤 경우에도 차단 (rule 의 `isAllowedSelfRoleChange` 에 `admin` 도착 케이스 없음).
  - **`brandId` 직접 set 차단**: 사용자가 `brandId` 를 임의 set 하는 것은 차단. `brandId` 의 발급은 오직 `BrandRepositoryImpl.upsertBrand` 의 batch write 에서만 일어나며, rule 에서 `brandId` 가 현재 비어있을 때만 set 허용 (`resource.data.brandId == ''`). 이미 박힌 `brandId` 의 변경 차단.
  - **관련 sub-phase spec**: `docs/tasks/admin_menu_management/6_upgrade_to_brand/spec.md` 의 결정 V2 / V2-1 과 정합. 본 spec 의 U-1 은 그 흐름을 룰 관점에서 명시.
- **U-2. 운영 중 임시 룰 → 정식 룰 전환 시점**.
  - architect 권장: 배포 시 service window 최소화. emulator dry-run + 4계정 회귀 후 즉시 배포.
- **U-3. brand 가 자기 가맹점 매장의 nested 컬렉션 (menuOverrides / subCategories / optionGroups) 을 직접 수정하는 흐름이 운영상 존재하는지**.
  - architect 잠정: 존재한다고 가정하고 룰에 권한 부여. 미존재 시 권한을 brand 에게서 제거.
- **U-4. `reviews` 컬렉션 룰**.
  - architect 잠정: 인증된 사용자 read + 본인 작성자 write 의 안전한 기본값. 실제 리뷰 기능 도입 시 별 task 로 보강.
- **U-5. emulator 자동 unit test 도입 여부**.
  - architect 잠정: 본 phase 는 산출물에서 제외 (follow-up). 본 phase 는 콘솔 Playground 또는 emulator 수동 검증으로 충분.

---

## 완료 기준

- [ ] `firestore.rules` 가 repo 루트에 생성되고 git 에 커밋됨.
- [ ] `firebase.json` 의 firestore 섹션이 `"rules": "firestore.rules"` 를 포함.
- [ ] `firebase deploy --only firestore:rules` 가 성공.
- [ ] 본 spec 의 모든 테스트 시나리오가 PASS (또는 보류 사유 명시).
- [ ] 사용자 확인 항목 U-1 ~ U-5 모두 결정됨.
- [ ] `implementation.md` / `test_report.md` 작성 완료.
- [ ] follow-up task (Storage rules / emulator unit test 등) 가 `docs/backlog.md` 또는 별 task 로 분리됨.

---

## 변경 이력

| 날짜 | 변경자 | 항목 | 내용 |
|---|---|---|---|
| 2026-05-25 | architect | 초안 | Phase 3a 종결 — `firestore.rules` 정식화 spec 초안 |
| 2026-05-25 | tester | F3 | test_report 의 F3 — `isAllowedSelfRoleChange` 가 brand 자가 승격을 허용하는 코드와 spec 의 "admin only" 표현 불일치 보고 |
| 2026-05-26 | architect | U-1 갱신 | U-1 결정을 **2단계 흐름** (자가 신청 + admin 승인) 으로 정정. 이유: 현 구현 (`UpgradeToBrandUseCase` + `isAllowedSelfRoleChange` + `brands` create rule + `BrandRepositoryImpl.upsertBrand` batch write) 이 보안과 운영 효율 모두에서 더 합리적이며, admin 부담을 줄이면서도 권한 부여 게이트 (`brands.status='approved'` + `users.brandId` 박힘) 가 안전하게 분리됨. 코드 / 룰 변경 없음. spec 만 코드에 맞춰 정합화. |
| 2026-05-26 | architect | role 전이 표 / 의사 코드 / 테스트 시나리오 갱신 | U-1 갱신에 따라 §role 변경 흐름 본문 / 의사 코드 (`isAllowedSelfRoleChange`) / T-U-7 / T-U-9 / T-B-5~9 정합화. brand nested 권한 게이트 (실제 `isBrandHolder` 통과 조건) 명시. |
| 2026-05-26 | architect | 부작용 검토 / brands create 매트릭스 / brands 본문 갱신 | brand 자가 신청 흐름의 룰 통과 경로 명시. `UpgradeToBrandUseCase` 의 동작은 이제 차단이 아닌 의도된 1단계로 정정. |
| 2026-06-21 | architect | **Phase 3c-1 (cooking_status_owner) 정책 반영 — F37 처리** | Phase 3c-1 sub-phase 1 의 결정 F (Q7) / 신규 O5/O6/O7 분기를 본 spec 에 정합화. ① **O2 정의 축소**: 환불 요청 허용 status `['accepted','making','ready','completed']` → `'accepted'` 만. 사유: 카페 픽업 도메인 표준 (조리 시작 = 음료 폐기 비용 발생) + UX 단순화 + 충돌 케이스 자체 제거. ② **O5/O6/O7 신규 분기 정의 추가**: 점주 `accepted→making` / `making→ready` / `ready→completed` 전이. 각 분기 actor = `isStoreOwner(resource.data.storeId)`, 화이트리스트 = `{status, <status>At, updatedAt}` 정확히 3개. O1 패턴 그대로 이어감 (drift 위험 없음). ③ **차단 케이스 표 정정**: `making`/`ready`/`completed` 클라이언트 직접 전이는 점주 본인만 O5/O6/O7 로 허용 + 환불 차단 명시. ④ **테스트 시나리오 추가**: T-O-O2-3 (making/ready/completed 환불 차단), T-O-O5-1~4 / T-O-O6-1~3 / T-O-O7-1~4 (전이 분기 권한 + 화이트리스트 검증). 코드 측은 `firestore.rules` 에 이미 반영 완료 (Phase 3c-1 implementation.md / test_report.md F26~F30, F36 PASS). 본 변경은 spec ↔ rules 정합화 목적. |
