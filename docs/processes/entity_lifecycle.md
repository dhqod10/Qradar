# Qradar Entity Lifecycle

이 문서는 Qradar 주요 엔티티의 **status 전이 다이어그램**과 각 전이의 **actor(주체) / 조건 / 갱신 필드 / Security Rules 분기**를 정리한다.

**목적**: 신규 기능에서 status 를 변경할 때, 누가 어떤 조건에서 어디로 갈 수 있는지를 즉시 확인.

**범위 분리**:
- 컬렉션별 데이터 접근 권한 매트릭스 → [`data_ownership.md`](./data_ownership.md)
- 역할별 진입점 / 액션 카탈로그 → [`role_flows.md`](./role_flows.md)

---

## 1. 다루는 엔티티

| 엔티티 | status enum | 위치 |
|---|---|---|
| Order | `OrderStatus` (paid/accepted/making/ready/completed/cancelled/refunded) | `orders/{orderId}` |
| Store | `EntityApprovalStatus` (pending/approved/rejected) | `stores/{storeId}` |
| Brand | `EntityApprovalStatus` | `brands/{brandId}` |
| MasterMenuItem (브랜드 마스터) | `EntityApprovalStatus` | `brands/{brandId}/menuItems/{id}` |
| StoreOnlyMenuItem (점포 한정) | `EntityApprovalStatus?` (개인 매장은 null, 브랜드 매장은 pending) | `stores/{storeId}/menuItems/{id}` |
| MenuOverride (가맹점 오버라이드) | `EntityApprovalStatus` | `stores/{storeId}/menuOverrides/{masterMenuItemId}` |
| RefundRequest (Order 내부 sub-doc) | (deniedAt null vs not-null) | `orders/{orderId}.refundRequest` |

**공통 표기**:
- "✅ Rules" — `firestore.rules` 가 명시적으로 허용/검증
- "🛠 CF" — Cloud Function 만 가능 (Admin SDK)
- "🔒 클라이언트 차단" — `allow X: if false` 또는 명시적 거부

**참고 (User 는 status enum 이 없다)**: 회원 탈퇴(`deleteMyAccount` CF, account_deletion)는 `users.deleted: true` 플래그 + 익명화로 표현한다 (하드 삭제 아님). Order 의 진행 중 status(`paid`/`accepted`/`making`/`ready`)가 1건이라도 있으면 탈퇴가 차단된다 (`deleteStore` 와 같은 집합). 소셜 재가입 시 `deleted` 문서는 신규 상태로 재초기화된다.

---

## 2. Order Lifecycle

### 2.1 다이어그램

```mermaid
stateDiagram-v2
    [*] --> paid: verifyTossPayment (CF)
    paid --> accepted: 점주 접수 (✅ Rules O1)
    paid --> cancelled: 고객/점주 취소 (cancelTossPayment CF)
    accepted --> making: 점주 조리 시작 (✅ Rules O5)
    making --> ready: 점주 준비 완료 (✅ Rules O6)
    ready --> completed: 점주 픽업 완료 (✅ Rules O7)
    accepted --> refunded: 점주 환불 승인 (processRefund CF)
    making --> refunded: 점주 환불 승인 (processRefund CF)
    ready --> refunded: 점주 환불 승인 (processRefund CF)
    completed --> refunded: 점주 환불 승인 (processRefund CF)
    cancelled --> [*]
    refunded --> [*]
    completed --> [*]
```

> `pickupNumber` (매장·일별 픽업 주문번호) 는 생성 시점(verifyTossPayment 트랜잭션)에 고정되는 **비-status 필드**다. 어떤 전이에서도 수정하지 않는다 (order_pickup_number).

### 2.2 전이 상세

| 전이 | actor | 메커니즘 | 조건 | 갱신 필드 | Rules 분기 |
|---|---|---|---|---|---|
| (없음) → paid | Cloud Function `verifyTossPayment` | 🛠 CF (Admin SDK) | Toss confirm 응답 검증 통과 + 동일 orderId doc 미존재 | 전체 doc create (status='paid', items, paymentInfo, createdAt, updatedAt 등) + `users/{uid}/orderLogs/{logId}` 동시 생성 | `orders.create: if false` (클라이언트 차단). CF 만 Admin SDK 로 우회 |
| paid → accepted | owner | ✅ Rules `isOwnerAcceptUpdate` | `isStoreOwner(storeId)` + `resource.status=='paid'` | `status='accepted'`, `acceptedAt`, `updatedAt` (이외 변경 차단) | `orders.update` O1 분기 |
| accepted → making | owner | ✅ Rules `isOwnerStartMakingUpdate` | `isStoreOwner(storeId)` + `resource.status=='accepted'` | `status='making'`, `makingStartedAt`, `updatedAt` | `orders.update` O5 분기 |
| making → ready | owner | ✅ Rules `isOwnerMarkReadyUpdate` | `isStoreOwner(storeId)` + `resource.status=='making'` | `status='ready'`, `readyAt`, `updatedAt` | `orders.update` O6 분기 |
| ready → completed | owner | ✅ Rules `isOwnerCompletePickupUpdate` | `isStoreOwner(storeId)` + `resource.status=='ready'` | `status='completed'`, `completedAt`, `updatedAt` | `orders.update` O7 분기. **후속 액션**: 이 전이 이후 고객이 해당 매장을 평가할 수 있다 (`completedAt` 기준 14일, UI 강제). 상세는 `docs/tasks/store_reviews/` |
| paid → cancelled (고객 취소) | customer | 🛠 CF `cancelTossPayment` (approvedBy='customer') | `order.userId == uid` + `order.status=='paid'` | `status='cancelled'`, `cancelInfo`, `cancelledAt`, `updatedAt` | 클라이언트 직접 update 차단. CF 가 권한·status 재검증 후 update |
| paid → cancelled (점주 거절) | owner | 🛠 CF `cancelTossPayment` (approvedBy='owner') | `stores/{storeId}.ownerId == uid` + `order.status=='paid'` | 동일 | 동일 |
| accepted+ → refunded | owner | 🛠 CF `processRefund` | `stores/{storeId}.ownerId == uid` + `order.refundRequest != null` + `order.status ∈ {accepted, making, ready, completed}` | `status='refunded'`, `refundInfo` (cancellationKey, reason, approvedBy=uid, processedAt, amount), `refundedAt`, `updatedAt` | 클라이언트 update 차단. CF 만 |
| paid/accepted+ → cancelled/refunded (admin 전권) | admin | ✅ Rules O4 (`isAdmin()`) | — | 임의 필드 update 가능 | `orders.update` O4 |

> **Qoin 사용(qoin_spend) 후속 액션**: `orders.discount > 0` 인 주문(= Qoin 사용분이 있는 주문)이 **`→ cancelled` 또는 `→ refunded`** 로 전이하면(위 표의 어떤 actor 든) `onOrderQoinSettled` 가 `spend_{orderId}` 원장을 반전해 `spendRefund_{orderId}` 로 **사용 Qoin 을 전액 복원**한다 (없으면 no-op). `completed → refunded` 는 적립 회수(`clawback`)와 사용 복원(`spendRefund`)이 **둘 다** 일어난다. 사용은 결제 시점(`verifyTossPayment`, Toss confirm 전 트랜잭션 차감)에 일어나므로 복원은 paid 이후의 모든 종료 전이를 덮는다. 상세: `docs/tasks/qoin_spend/spec.md` §6.

### 2.3 Order 내부 sub-state: refundRequest

`orders/{orderId}.refundRequest` 는 자체 status 가 아니라 **존재 여부 + deniedAt** 으로 분기.

```mermaid
stateDiagram-v2
    [*] --> NoRequest: 결제 직후
    NoRequest --> Requested: 고객 환불 요청 (O2)
    Requested --> Denied: 점주 거절 (O3)
    Requested --> [*]: processRefund (CF) → refunded
    Denied --> [*]: 재요청 차단 (O2 조건 위반)
```

| 전이 | actor | 메커니즘 | 조건 | 갱신 필드 | Rules 분기 |
|---|---|---|---|---|---|
| (없음) → Requested | customer | ✅ Rules `isCustomerRefundRequest` (O2) | `order.userId == uid` + `order.status == 'accepted'` (결정 F: making/ready/completed 차단) + `refundRequest == null` (또는 `deniedAt == null`) | `refundRequest={reason, requestedAt}`, `updatedAt`. **refundRequest 내부 reason/requestedAt 만 허용**. | `orders.update` O2 |
| Requested → Denied | owner | ✅ Rules `isOwnerDenyRefund` (O3) | `isStoreOwner(storeId)` + `refundRequest != null` + `deniedAt == null` | `refundRequest` 에 `deniedAt`, `deniedReason` 추가. 내부 필드 4개(`reason`, `requestedAt`, `deniedAt`, `deniedReason`)만 허용. | `orders.update` O3 |
| Requested → (사라짐, processRefund) | owner | 🛠 CF `processRefund` | (위 refunded 전이와 동일) | order doc 전체가 refunded 로 전이됨. `refundRequest` 는 그대로 남아있음 (이력) | — |

**결정 F (Phase 3c)**: 고객 환불 요청은 `accepted` 상태일 때만 허용. `making`/`ready`/`completed` 상태에서는 Rules(O2) + UI(U7 안내 카드) 양측에서 차단. 카페 픽업 도메인에서 조리 시작 후 환불은 표준적으로 불가.

**주의**: O2 의 "재요청 차단" 은 `deniedAt != null` 인 경우만 막는다. 한번 거절당하면 영구히 재요청 불가. **확인 필요** — UX 적으로 "다시 환불 요청" 이 가능해야 하는지 검토.

### 2.4 코드 진입점

| 전이 | 호출 경로 |
|---|---|
| paid 생성 | `presentation/customer/checkout/checkout_page.dart` → `verify_and_create_order_use_case` → `payment_gateway_repository_impl.verifyAndCreateOrder` → CF |
| paid → accepted | `presentation/owner/orders/owner_orders_page.dart` → `order_repository_impl.setAcceptedByOwner` (직접 Firestore update) |
| paid → cancelled (고객) | `presentation/customer/checkout/payment_result_page.dart` 또는 주문 상세 → `payment_gateway_repository_impl.cancelPaidOrder` (approvedBy='customer') |
| paid → cancelled (점주) | `presentation/owner/orders/**` → `cancelPaidOrder` (approvedBy='owner') |
| refund 요청 | `presentation/customer/order/**` → `order_repository_impl.requestRefund` |
| refund 거절 | `presentation/owner/orders/**` → `order_repository_impl.denyRefundRequest` |
| refund 승인 (전액) | `presentation/owner/orders/**` → `payment_gateway_repository_impl.processRefund` |

### 2.5 보류/미구현

- **making / ready / completed 전이 구현 완료 (Phase 3c)**: Security Rules O5/O6/O7 분기 추가. `StartMakingOrderUseCase` / `MarkOrderReadyUseCase` / `MarkOrderCompletedUseCase` 및 점주 UI(`OwnerOrdersPage` 3탭 + `OwnerInProgressOrderTile` + 픽업 완료 다이얼로그) 구현. `OwnerOrderDetailPage` 에 `_TimelineSection` 노출.
- **ready → completed 옵트인 알림 (Phase 3c-3)**: `onOrderStatusChanged` 가 `users/{userId}.notificationSettings.pickupComplete == true` 일 때만 고객에게 `order_completed` 알림 발송 (기본 false → 미발화). 전이 조건·actor 는 불변.
- **부분 환불 미구현**: `processRefund` 가 항상 전액 환불.
- **재환불 요청 차단** (위 2.3 주의 참조).

---

## 3. Store Lifecycle

### 3.1 다이어그램

```mermaid
stateDiagram-v2
    [*] --> pending: 점주 등록 (Rules: stores.create)
    pending --> approved: admin 승인 (Repository.approveStore)
    pending --> rejected: admin 반려 (Repository.rejectStore)
    rejected --> pending: 점주 재제출 (Repository: isResubmit=true)
    approved --> approved: 점주/브랜드 운영 필드 수정 (status 보존)
    approved --> pending: 점주 핵심 필드 수정 (resubmit)
    approved --> [*]: 점주/admin 삭제
    rejected --> [*]: admin 삭제
```

### 3.2 전이 상세

| 전이 | actor | 메커니즘 | 조건 | 갱신 필드 | Rules 분기 |
|---|---|---|---|---|---|
| (없음) → pending | owner | ✅ Rules `stores.create` | `isOwner()` + `ownerId == uid` + `status == 'pending'` | 전체 doc create. `submittedBy=uid`, `submittedAt=now`, `brandId` (brandKey 매칭 시) | `stores.create` |
| pending → approved | admin | ✅ Rules `stores.update` (admin 전권) | `_assertAdmin()` (StoreRepository) | `status='approved'`, `approvedBy=adminUid`, `approvedAt`, `rejectedReason=null`, `updatedAt` | admin 분기 |
| pending → rejected | admin | 동일 | 동일 | `status='rejected'`, `approvedBy=adminUid`, `rejectedReason`, `updatedAt` | admin 분기 |
| rejected → pending (재제출) | owner | ✅ Rules `isStoreOwnerFieldUpdate` | `isStoreOwner(storeId)` + 핵심 필드(name, menuCategories, address 등) 수정 | `status='pending'`, `submittedBy=uid` 갱신, `approvedBy/approvedAt/rejectedReason` 클리어 (`updatedAt`) | owner update — 화이트리스트에 승인 메타 포함 (§3.3). `approvedAt` 클리어 → 결제 게이트가 다시 거절 |
| approved → pending (점주 핵심 수정) | owner | 동일 | 동일 | `status='pending'`, `submittedBy/submittedAt` 갱신 (**`approvedAt` 보존**) | 동일. **`approvedAt` 이 남으므로 결제는 계속 성립** (`canSellNow`) |
| approved → approved (운영 필드만) | owner | ✅ Rules `isStoreOwnerFieldUpdate` | `isStoreOwner(storeId)` + name/imageUrl/phone/address 등 운영 필드만 변경 | 해당 필드 + `updatedAt` | Rules 통과 |
| approved → approved (브랜드 운영 필드) | brand (가맹점주가 아닌 본사) | ✅ Rules `isStoreOwnerBrandUpdate` | `isBrandHolder(store.brandId)` + 운영 필드만 변경 | 동일 | Rules 통과 |
| 모든 status → 삭제 | **admin 전담** | ✅ `deleteStore` CF (Rules `stores.delete` = `isAdmin()`) | 진행 중 주문(`paid`/`accepted`/`making`/`ready`) 없음. **점주 삭제는 닫혔다** | `storeDeletionHistory` 이력 → doc delete → 하위 문서 재귀 삭제 → Storage 정리 (`phase` 재진입, 멱등) | delete (Admin SDK) |

### 3.3 Rules 와 Repository 의 정합 (확정 — payment_server_authority 가 낡은 "확인 필요" 를 사실로 교체)

`StoreRepositoryImpl.updateStoreCoreFields` 는 핵심 필드 수정 시 `status` 를 `pending` 으로 회귀시킨다 (`isResubmit` 이면 `approvedBy/approvedAt` 클리어). **Rules 는 이미 3번 선택지(화이트리스트에 승인 메타 추가)를 채택했다**:

- `isStoreOwnerFieldUpdate` / `isStoreOwnerBrandUpdate` 화이트리스트에 `status`, `submittedBy`, `submittedAt`, `approvedBy`, `approvedAt`, `rejectedReason`, `businessRegistrationNumber` 가 **들어 있다.**
- `status` 는 **`'pending'` 으로만** 설정 가능 (자기 승격 차단). `approvedBy` / `approvedAt` 는 **null 클리어만** 가능 (값 설정 불가).
- 따라서 점주 핵심 필드 수정(승인 → pending 회귀)과 재제출(rejected → pending)은 **차단되지 않는다.**
- **create 경로**는 `status == 'pending'` 만 보던 구멍이 있었다 (`approvedAt` 임의 설정 가능) → **Rules-A 가 `approvedAt`/`approvedBy`/`rejectedReason` 의 자가 설정을 create 에서도 금지**한다. 결제 게이트가 `approvedAt` 을 판정 입력으로 쓰기 때문이다.

**승인 이력의 의미**: `approvedAt != null && status == pending` = "한 번 승인된 적이 있고 지금 수정 대기". 결제 판정 `canSellNow` 는 이 사실을 쓴다: `status == approved || (status == pending && approvedAt != null)` — 영업 중 매장이 정보를 고치는 동안 결제가 막히지 않는다. (고객 매장 **목록 노출**은 별개로 `status == approved` 만 보인다 — "수정 대기 매장이 목록에서 사라지는" 기존 제품 결함은 backlog N2.)

### 3.4 코드 진입점

| 전이 | 호출 경로 |
|---|---|
| 등록 (pending) | `owner/my_store/store_core_form_page.dart` → `submit_store_for_approval_use_case` → `store_repository_impl.submitStoreForApproval` |
| 점주 핵심 수정 | 동일 폼 (existing != null) → `updateStoreCoreFields` |
| 점주 운영 필드 | `owner/my_store/**` → `updateStoreOperationFields` |
| admin 승인/반려 | `admin/approval/admin_store_approval_detail_page.dart` → `approveStore` / `rejectStore` |
| 브랜드(본사) 가맹점 운영 필드 | `brand/stores/**` → (확인 필요 — repository 호출 명확치 않음) |

---

## 4. Brand Lifecycle

### 4.1 다이어그램

```mermaid
stateDiagram-v2
    [*] --> pending: brand 유저 self-create (BrandRepository.upsertBrand isNew=true)
    pending --> approved: admin 승인 (brandKey 자동 발급)
    pending --> rejected: admin 반려
    approved --> pending: brand 핵심 수정 (name/description 변경 시 회귀)
    approved --> approved: logoUrl 만 수정 (status 보존)
    rejected --> pending: brand 재제출 (코드상 미구분, upsertBrand 가 핵심 필드 변경 검출)
    pending --> [*]: admin 삭제
    approved --> [*]: admin 삭제
    rejected --> [*]: admin 삭제
```

### 4.2 전이 상세

| 전이 | actor | 메커니즘 | 조건 | 갱신 필드 | Rules 분기 |
|---|---|---|---|---|---|
| (없음) → pending | brand 유저 | ✅ Rules `brands.create` | `isBrand()` + `submittedBy == uid` + `status == 'pending'` + `brandKey == ''` | brand doc 전체 create + batch 로 `users/{uid}.brandId=brandId` 동시 set | `brands.create` |
| pending → approved | admin | ✅ Rules `brands.update` (admin 전권) | (admin) | `status='approved'`, `approvedBy=adminUid`, `approvedAt`, `brandKey`(자동 생성 `BR-XXXXXXXX`, unique 검증 최대 3회 retry), `rejectedReason=null`, `updatedAt` | admin 분기 |
| pending → rejected | admin | 동일 | (admin) | `status='rejected'`, `approvedBy`, `rejectedReason`, `updatedAt` | admin 분기 |
| approved → pending (핵심 수정) | brand 본인 | ✅ Rules `isBrandSelfUpdate` | `isBrandHolder(brandId)` + 변경 필드 화이트리스트 (name, description 등) | `status='pending'`, `submittedBy/submittedAt` 갱신, **`approvedBy/approvedAt` 보존** (수정 대기 라벨 구분용), `brandKey` 보존 (V1 불변성) | brand 분기 ⚠️ **Store 와 동일한 화이트리스트 이슈 가능성** |
| approved → approved (logoUrl만) | brand 본인 | 동일 | logoUrl 단독 변경 | `logoUrl`, `updatedAt` | brand 분기 |
| 모든 status → 삭제 | admin | ✅ Rules `brands.delete: if isAdmin()` | (admin) | doc delete | admin 분기 |

### 4.3 불일치 (재설계 후보)

**Rules 화이트리스트 vs 코드 갱신 필드 불일치**:
- Rules `isBrandSelfUpdate` 의 `onlyChangedFields`: `['name', 'imageUrl', 'description', 'phone', 'address', 'businessHours', 'updatedAt', 'tags', 'logoUrl']`
- `BrandRepositoryImpl.upsertBrand` 가 핵심 필드 변경 시 set 하는 필드: `status`, `submittedBy`, `submittedAt`, `updatedAt` 등 (전체 doc set with merge)
- Rules 가 화이트리스트에 없는 필드(status, submittedBy 등) 변경을 차단 → **현재 형태로는 brand 본인 재제출 차단됨** ⚠️ **확인 필요**

이것이 바로 task 의 동기인 "users.brandId 설정 시점이 코드 곳곳에 흩어져 있어 Rules 와 불일치" 의 한 사례.

### 4.4 코드 진입점

| 전이 | 호출 경로 |
|---|---|
| 등록 (pending) | `BrandScaffold` 자동 진입 → `brand/brand_info/brand_info_form_page.dart` → `upsertBrandUseCase` → `BrandRepositoryImpl.upsertBrand` (isNew=true → batch) |
| brand 본인 수정 | 동일 폼 (brand != null) → `upsertBrand` (isNew=false) — 핵심/운영 자동 분기 |
| admin 승인 | `admin/approval/admin_brand_approval_detail_page.dart` → `approveBrandUseCase` → `BrandRepositoryImpl.approveBrand` (brandKey 자동 발급) |
| admin 반려 | 동일 → `rejectBrandUseCase` → `rejectBrand` |

---

## 5. MenuItem Lifecycle (master / store / store-only 3종)

MenuItem 은 **3가지 변종** 이 있고 각각 lifecycle 이 다르다.

### 5.1 변종 구분

| 변종 | 경로 | scope | status |
|---|---|---|---|
| 마스터 메뉴 (브랜드 본사) | `brands/{brandId}/menuItems/{id}` | `brand` | `EntityApprovalStatus` 필수 |
| 점포 한정 메뉴 (개인 매장) | `stores/{storeId}/menuItems/{id}` | `store`, `brandId=null` | **null** (개인 매장은 승인 불필요) |
| 점포 한정 메뉴 (브랜드 매장) | `stores/{storeId}/menuItems/{id}` | `store`, `brandId=<brandId>` | `EntityApprovalStatus` 필수 |

머지 규칙: `MenuItemRepositoryImpl._mergeForBrandStore` — 가맹점 화면에는 `master(approved+visible)` + `storeOnly(approved+visible)` + `override(approved 시 핵심필드 적용, 운영필드는 status 무관)` 머지.

### 5.2 마스터 메뉴 (brand-scope)

```mermaid
stateDiagram-v2
    [*] --> pending: brand create (MasterMenuItemRepository.createMasterMenuItem)
    pending --> approved: admin 승인
    pending --> rejected: admin 반려
    approved --> pending: brand 핵심 수정 (updateMasterMenuItemCore)
    approved --> approved: brand 운영 필드 수정 (updateMasterMenuItemOperation)
    rejected --> pending: brand 재제출
    pending --> [*]: brand/admin cascade delete (with overrides)
    approved --> [*]: 동일
    rejected --> [*]: 동일
```

| 전이 | actor | 갱신 | Rules 분기 |
|---|---|---|---|
| (없음) → pending | brand | scope='brand', brandId=myBrandId, status='pending', submittedBy=uid | `brands/{brandId}/menuItems.create`: `isAdmin() || (isBrandHolder(brandId) && noSelfApproveOnCreate())` — 브랜드는 `status='pending'` + 승인 메타 부재·null 만 (brand_self_approve_guard) |
| pending → approved | admin | status, approvedBy, approvedAt, rejectedReason=null | 동일 — admin 통과. **브랜드는 Rules 에서 거부** (`noSelfApproveOnUpdate`) |
| pending → rejected | admin | status='rejected', rejectedReason | 동일 |
| approved → pending (핵심 수정) | brand | status='pending', submittedBy/At 갱신, **approvedBy/At 보존** (수정 대기 라벨 구분) | 동일 |
| approved → approved (운영) | brand | `visible`, `tags`, `displayOrder`, `imageUrl`, `updatedAt` 만 (status 무관) | 동일 |
| cascade delete | brand/admin | doc delete + `menuOverrides` 일괄 삭제 (collectionGroup) | 동일 |

**갈래**: bulk approve/reject 도 admin 전용 (`_assertAdminOnly`).

### 5.3 점포 한정 메뉴 — 개인 매장 (brandId=null)

```mermaid
stateDiagram-v2
    [*] --> approvedImmediate: owner create
    approvedImmediate --> approvedImmediate: owner 수정 (status 보존)
    approvedImmediate --> [*]: owner/admin 삭제
    note right of approvedImmediate
      status='approved' 강제 + 승인 메타 null.
      개인 매장은 승인 불필요.
    end note
```

| 전이 | actor | 메커니즘 | 갱신 |
|---|---|---|---|
| 생성 | owner (`_assertOwnerOfPersonalStore`) | `MenuItemRepositoryImpl.createStoreOnlyMenu` | `scope='store'`, `brandId=null`, `status='approved'`, `submittedBy/At/approvedBy/At/rejectedReason=null` |
| 수정 | owner | `updateStoreOnlyMenuCore` 또는 `updateStoreOnlyMenuOperation` | status='approved' 유지 |
| 삭제 | owner / admin | `deleteStoreOnlyMenu` | doc delete |

**옵션 그룹 ref 제약 (sub-phase 7 S2)**: 개인 매장 메뉴는 `optionGroupRefs.scope ∈ {master, store}` 만 허용. `brand` scope 차단.

### 5.4 점포 한정 메뉴 — 브랜드 매장 (brandId=<brandId>)

```mermaid
stateDiagram-v2
    [*] --> pending: brand create (점주 직접 등록 불가)
    pending --> approved: admin 승인
    pending --> rejected: admin 반려
    approved --> pending: brand 핵심 수정 (status=pending 회귀)
    rejected --> pending: brand 재제출
```

| 전이 | actor | 메커니즘 | 갱신 |
|---|---|---|---|
| 생성 | brand | `createStoreOnlyMenu` (role=='admin' || 'brand' 만 통과) | scope='store', brandId=storeBrandId, status='pending', submittedBy=uid |
| pending → approved | admin | `approveStoreOnlyMenu` | status, approvedBy, approvedAt |
| pending → rejected | admin | `rejectStoreOnlyMenu` | status, approvedBy, rejectedReason |
| approved → pending (핵심 수정) | brand | `updateStoreOnlyMenuCore` (brandId!=null 분기) | status='pending' 회귀 |

**Rules 분기**: `stores/{storeId}/menuItems` 는 admin / `isStoreOwner(storeId)` / `isBrandHolder(store.brandId)` 허용. **브랜드 분기는 brand_self_approve_guard 로 닫혔다** — create `noSelfApproveOnCreate()`, update `noSelfApproveOnUpdate()` (status 는 `pending` 만, 승인 메타 non-null 불가; 브랜드 자가승인 차단, delete 유지). ⚠️ **남은 지점**: **점주 분기**는 Rules 가 여전히 제한 없이 통과시키고 Repository role 검증으로만 차단한다 — 가맹점주가 브랜드 매장 점포한정 메뉴를 `status:'approved'` 로 직접 쓸 여지가 있다. 개인 매장 점주의 정당한 `approved` 쓰기와 공유되는 분기라 `stores.brandId` 기반 분리가 필요해 별도 task 로 분리했다 (D2).

### 5.5 MenuOverride (가맹점의 마스터 메뉴 오버라이드)

`stores/{storeId}/menuOverrides/{masterMenuItemId}` — 가맹점이 마스터 메뉴의 가격/제외/품절 등을 매장별로 덮어쓰는 doc.

```mermaid
stateDiagram-v2
    [*] --> pending: brand upsertOverrideCore (핵심 필드)
    pending --> approved: admin 승인
    pending --> rejected: admin 반려
    approved --> pending: brand 핵심 수정 (priceOverride/excluded)
    rejected --> pending: brand 재제출
    [*] --> approvedOp: owner 운영 필드 신규 (status='approved' 즉시)
    approvedOp --> approvedOp: owner 운영 필드 토글 (status 보존)
```

| 전이 | actor | 메커니즘 | 갱신 |
|---|---|---|---|
| 핵심 필드 (priceOverride/excluded) 변경 | brand | `MenuOverrideRepository.upsertOverrideCore` | `status='pending'`, submittedBy, updatedBy='brand', updatedAt |
| pending → approved | admin | `approveOverride` | status, approvedBy, approvedAt, updatedBy='admin' |
| pending → rejected | admin | `rejectOverride` | status='rejected', rejectedReason, updatedBy='admin' |
| 운영 필드 (soldOut/disabledOption*) — override 없을 때 | owner (가맹점주) | `updateOverrideOperationFields` 첫 케이스 | doc 신규 set, status='approved' 즉시, priceOverride=null, excluded=false, updatedBy='owner' |
| 운영 필드 — override 있을 때 | owner | 동일 두번째 케이스 | partial update, status 보존 |

**머지 규칙**: customer 화면에 노출될 때
- 핵심 필드 (priceOverride / excluded) — `status==approved` 일 때만 적용
- 운영 필드 (soldOut / disabledOption*) — status 무관 즉시 적용

**Rules (payment_price_authority Rules-1, 2026-10-27)**: `admin` 은 create/update/delete 전부 가능하다(제출·승인·반려). **`brandHolder` 는 제출만** — create `noSelfApproveOnCreate()` · update `noSelfApproveOnUpdate()` (brand_self_approve_guard: `status` 를 approved/rejected 로 전이하거나 `approvedBy`/`approvedAt` 를 non-null 로 쓰면 거부, 자가승인 차단), delete 는 가능. **점주(`storeOwner`)는 승인 상태의 핵심 필드를 쓸 수 없다** — create 는 `approvedBy`/`approvedAt` 부재·null + (`status != 'approved'` 또는 `priceOverride == null && excluded == false`) + `status ∈ {pending, approved, rejected}`, update 는 운영 필드(`soldOut` `disabledOptionGroupIds` `disabledOptionItemIds` `updatedBy` `updatedAt`)만. 위 표의 점주 전이 두 줄(운영 필드 신규 `status='approved'` / partial update)은 그대로 통과한다. 이전에는 점주가 `{status:'approved', priceOverride:1}` 을 직접 쓸 수 있어 "핵심 필드는 approved 일 때만 적용" 분기가 의미를 갖지 못했다. 상세: [`data_ownership.md §2.6`](./data_ownership.md).

> **order 의 `→ paid` 진입 조건에 서버 금액 일치가 추가된다** (§2.2, payment_price_authority): `PAYMENT_PRICE_MODE=enforce` 에서 `verifyTossPayment` 가 카트 금액을 문서에서 다시 계산해 불일치면 **주문 생성 전에** 거절한다. 새 status 는 없고 거절은 전이가 아니라 **진입 차단**이다.

> **알려진 우회로 (Q8 ⓑ, 현행 유지)**: `priceOverride` 의 승인 요건과 별개로 브랜드 마스터 메뉴가 store-scope 옵션 그룹을 참조하면 그 옵션의 `priceDelta` 는 가맹점주가 승인 없이 즉시 바꾼다. 서버는 문서 값을 그대로 권위로 쓴다(후속 P2).


---

## 6. RefundRequest (Order 내부 sub-doc, 재확인)

별도 컬렉션 아님. Order doc 내 `refundRequest` 필드. 상세는 [§2.3](#23-order-내부-sub-state-refundrequest) 참조.

요약:
- 생성 / 거절 / 환불 승인 모두 별도 actor / 메커니즘.
- 거절 후 재요청은 현재 차단됨 (확인 필요).

---

## 7. 상태별 검증 체크리스트 (신규 feature 추가 시)

신규 status 전이를 추가할 때 다음을 모두 충족해야 한다:

1. **누가 트리거하는가?** (customer/owner/brand/admin/CF 중 명확히)
2. **Security Rules 분기 추가** — actor 검증 + 이전 status 검증 + 변경 필드 화이트리스트 (`onlyChangedFields`)
3. **Repository 갱신 필드 목록** — Rules 화이트리스트와 정확히 일치 (코드/Rules drift 방지)
4. **승인 메타** (approvedBy, approvedAt, submittedBy, submittedAt, rejectedReason 등) 의 갱신/보존 정책 명시
5. **다른 doc 영향** (cascade delete, batch write 동기화 — 예: brand doc 생성 시 users.brandId)
6. **Cloud Function 필요 여부** — PG 호출, 외부 검증, 다중 collection batch 등은 CF 필수
7. **누락된 진입점이나 회복 경로가 없는지** (예: pending 으로 다시 못 가는 막다른 길)

---

## 8. 참조

- enum 정의:
  - [`lib/domain/entities/order_status.dart`](../../lib/domain/entities/order_status.dart)
  - [`lib/domain/entities/entity_approval_status.dart`](../../lib/domain/entities/entity_approval_status.dart)
  - [`lib/domain/entities/menu_item_scope.dart`](../../lib/domain/entities/menu_item_scope.dart)
- Repository 구현체: `lib/data/repositories/*.dart`
- Cloud Functions: `functions/src/{verifyTossPayment,cancelTossPayment,processRefund}.ts`
- Security Rules: [`firestore.rules`](../../firestore.rules)
