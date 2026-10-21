# Qradar Role Flows

이 문서는 Qradar 4개 역할(`customer` / `owner` / `brand` / `admin`)의 진입 조건, 가능 액션, 역할 전이 흐름을 정리한다.

**목적**: 신규 feature 설계 시 "이 기능은 어느 역할의 어느 흐름에 끼어드는가?" 를 즉시 판단하는 단일 진실원.

**범위 분리**:
- 데이터 접근 권한 / Security Rules 분기 → [`data_ownership.md`](./data_ownership.md)
- 엔티티 status 전이 / actor / 조건 → [`entity_lifecycle.md`](./entity_lifecycle.md)
- 역할별 기능 명세(무엇을 만드는가) → [`../product_scope.md`](../product_scope.md)

이 문서는 **"누가 어디서 무엇을 시작할 수 있는가"** 만 다룬다.

---

## 1. 역할 개요

| 역할 | role 값 | 진입 경로 | 메인 Scaffold | 주요 책임 |
|---|---|---|---|---|
| 고객 | `customer` | 가입 직후 기본값 | `ScaffoldWithNav` | 매장 탐색·주문·결제·취소·환불 요청 |
| 점주 | `owner` | customer → 자가 신청 (더보기) | `OwnerScaffold` | 매장 등록·운영·주문 접수·환불 거절/처리 |
| 브랜드 | `brand` | customer/owner → 자가 신청 + 브랜드 등록 폼 | `BrandScaffold` | 브랜드 정보·마스터 메뉴·가맹점 운영 |
| 관리자 | `admin` | Firestore 콘솔 수동 발급만 | `AdminScaffold` | 승인 게이트(브랜드/매장/메뉴/오버라이드) |

라우팅 단일 진입점: `lib/presentation/common/role_router.dart` — `users/{uid}.role` 스트림 기반 분기.

---

## 2. 진입 조건 (role 발급 방식)

### customer
- **진입 조건**: 신규 가입 직후 항상 `customer`.
- **트리거 코드**: `UserRemoteDataSource.createIfAbsent` → `users/{uid}` 신규 doc 생성. Security Rules `users.create` 가 `role='customer'` 만 허용.
- **회복 경로**: legacy 계정에서 `role` 필드 누락 시 `userRole()` helper 가 `'customer'` fallback (Security Rules).

### owner
- **진입 조건**: `customer`(또는 `brand`)이 자가 신청. admin 승인 불필요.
- **트리거**: 고객 더보기 → "점주이신가요?" 섹션 → 다이얼로그 확인 → `UpgradeToOwnerUseCase`.
- **권한 발효**: role 전이 즉시 `OwnerScaffold` 진입. 단, **매장 운영은 별도** — 매장 등록 + admin 승인을 거쳐야 `stores/{storeId}.status='approved'` 가 되어야 고객에게 노출됨.

### brand
- **진입 조건**: `customer` 또는 `owner` 가 자가 신청. role 전이는 즉시. 단, **brand doc 등록과 admin 승인은 별도 단계**.
- **트리거**:
  1. 고객 더보기 → "브랜드 운영자이신가요?" → `UpgradeToBrandUseCase` (`users.role='brand'`)
  2. `RoleRouter` → `BrandScaffold` 진입
  3. `BrandScaffold` 가 `users.brandId` 비어있으면 **자동으로 `BrandInfoFormPage` 강제 진입** (V8)
  4. 폼 제출 → `BrandRepository.upsertBrand` → batch write 로 `brands/{brandId}` (status=pending) + `users/{uid}.brandId` 갱신
  5. admin 승인 후 `brands/{brandId}.status='approved'` + `brandKey` 발급 → 본격 운영 시작
- **핵심 결정**: `users.role='brand'` 가 되는 시점과 `users.brandId` 가 채워지는 시점이 **분리** 됨. Security Rules `users.create` 는 `brandId` 동시 set 차단. brand doc create 시 batch 로 `users.brandId` 동기화.
- **확인 필요**: `users.role='brand'` 이지만 `brandId=''` 상태에서 로그아웃 후 재로그인하면 동일하게 `BrandInfoFormPage` 로 진입함. 명확한 "도중에 포기" 회복 경로(예: customer 로 다운그레이드 버튼)는 BrandInfoFormPage 내부에는 없음 → **잠재적 UX 막다른 길**.

### admin
- **진입 조건**: Firestore 콘솔에서 수동으로 `users/{uid}.role='admin'` 설정.
- **자가 승격 금지**: Security Rules `isAllowedSelfRoleChange` 가 `admin` 으로의 전이를 명시적으로 차단.
- **트리거 UI 없음**: 클라이언트 어디에서도 admin 발급 경로 없음.

---

## 3. 역할 전이 (다이어그램)

```mermaid
stateDiagram-v2
    [*] --> customer: 가입 직후
    customer --> owner: 더보기 → 점주 전환
    customer --> brand: 더보기 → 브랜드 전환
    owner --> customer: 더보기 → 고객 모드
    owner --> brand: (rules 허용, UI 미구현)
    brand --> customer: (rules 허용, UI 미구현)
    brand --> owner: (rules 허용, UI 미구현)
    note right of admin
      admin 진입은 Firestore 콘솔만.
      자가 승격 금지.
    end note
    customer --> admin: ❌ 차단
    owner --> admin: ❌ 차단
    brand --> admin: ❌ 차단
```

### Security Rules 허용 전이표

`firestore.rules` `isAllowedSelfRoleChange(from, to)` 기준:

| from \ to | customer | owner | brand | admin |
|---|---|---|---|---|
| customer | (no-op) | ✅ | ✅ | ❌ |
| owner    | ✅ | (no-op) | ✅ | ❌ |
| brand    | ✅ | ✅ | (no-op) | ❌ |
| admin    | (admin 전권) | (admin 전권) | (admin 전권) | (admin 전권) |

### 클라이언트 UI 가 실제로 제공하는 전이

| 전이 | UI 진입점 | 트리거 UseCase |
|---|---|---|
| customer → owner | `presentation/customer/more/widgets/upgrade_to_owner_section.dart` | `UpgradeToOwnerUseCase` |
| customer → brand | `presentation/customer/more/widgets/upgrade_to_brand_section.dart` | `UpgradeToBrandUseCase` |
| owner → customer | `presentation/owner/more/owner_more_page.dart` ("고객 모드로 전환") | `DowngradeToCustomerUseCase` |
| brand → customer | **미구현** — `BrandMorePage` 에 다운그레이드 버튼 없음 | — |
| brand → owner | **미구현** | — |
| owner → brand | **미구현** — 점주 더보기에 브랜드 전환 진입점 없음 | — |

**불일치 (재설계 후보)**:
- Rules 상으로는 `owner → brand` / `brand → customer` 양방향 자유롭지만 UI 가 한쪽 방향만 제공.
- `users.brandId` 가 한 번 set 되면 Rules 의 `isSelfProfileUpdate` 의 마지막 조건(`brandId` 변경은 빈 값일 때만)으로 인해 **재변경 불가**. 따라서 `brand → customer → 다시 brand` 같은 흐름은 새로운 brand doc 생성이 불가능 → 사실상 brand 는 일회성. **이게 의도된 정책인지 확인 필요.**

---

## 4. 역할별 가능 액션 + 진입점

### 4.1 customer

| 액션 | 화면(파일) | 의존 데이터 |
|---|---|---|
| 회원가입/로그인 | `customer/auth/login_page.dart` 외 | `auth_repository_impl` (Google/Kakao/Naver/Email) |
| 지도 기반 매장 탐색 | `customer/home/**` | `stores` (status=approved 필터) |
| 매장 상세 / 메뉴 보기 | `customer/store/**` | `stores/{id}` + `menuItems` 머지 (master + override + store-only) |
| 장바구니 (매장별 독립) | `customer/cart/**` | `CartRepositoryImpl` (local) |
| 결제 / 주문 생성 | `customer/checkout/checkout_page.dart` | `verifyTossPayment` Cloud Function |
| 결제 결과 / 영수증 | `customer/checkout/payment_result_page.dart` | `orders/{orderId}` watch |
| 주문 취소 (paid 단계만) | 주문 상세 / 결제 결과 페이지 | `cancelTossPayment` Cloud Function |
| 환불 요청 (accepted+ 단계) | 주문 상세 | `OrderRepository.requestRefund` (직접 Firestore update) |
| 주문 내역(Log) 조회 | `customer/log/**` | `users/{uid}/orderLogs` |
| 즐겨찾기 매장/메뉴 | `customer/home/widgets/favorites_*` | `users/{uid}/favoriteStores`, `/favoriteMenuItems` |
| Qoin (적립금) | `customer/qoin/**` | **미구현 — 컬렉션 미정의** |
| 알림 설정 변경 | `common/notification/notification_settings_page.dart` (더보기 > 알림 설정) | `users/{uid}.notificationSettings` (`orderProgress` / `pickupComplete`), OS 권한 3-state, 명시 재요청 |
| 선물하기 | — | **미구현** |
| 리뷰 작성 | — | **미구현** — `reviews/{reviewId}` Rules 만 정의, UI 없음 |

**핵심 진입점**: `ScaffoldWithNav` (홈 / 카트 / Log / 더보기 등 BottomNav).

### 4.2 owner

| 액션 | 화면(파일) | 의존 데이터 |
|---|---|---|
| 매장 등록 / 재등록 | `owner/my_store/store_core_form_page.dart` | `stores.create` (status=pending) + brandKey 매칭(`findByBrandKey`) |
| 매장 핵심 필드 수정 (이름/주소/사업자번호 등) | `owner/my_store/store_core_form_page.dart` | `submitStoreForApproval` (status=pending 회귀) |
| 매장 운영 필드 수정 (이미지/영업시간/공지 등) | `owner/my_store/**` | `updateStoreOperationFields` (status 보존) |
| 점포 한정 메뉴 CRUD (개인 매장) | `owner/store_menu/**` | `menu_item_repository_impl.createStoreOnlyMenu` (status=approved 즉시) |
| 점포 한정 옵션 그룹 CRUD | `owner/option_groups/**` | `stores/{storeId}/optionGroups` |
| 점포 한정 서브 카테고리 CRUD | `owner/sub_categories/**` | `stores/{storeId}/subCategories` |
| 브랜드 매장 운영 필드 토글 (가맹점) | `owner/brand_store/**` | `menuOverrides` 운영 필드만 (sub-phase 5) |
| 주문 접수 / 거절 | `owner/orders/owner_orders_page.dart` | `orders.update` (paid→accepted) / `cancelTossPayment` (owner 거절) |
| 조리 시작 (accepted→making) | `owner/orders/owner_orders_page.dart` `_InProgressOrdersTab` (statusFilter = `{accepted, making, ready}` — Phase 3c-1 결정 H) | `StartMakingOrderUseCase` → `orders.update` O5 |
| 준비 완료 (making→ready) | 동일 탭 `OwnerInProgressOrderTile` | `MarkOrderReadyUseCase` → `orders.update` O6 |
| 픽업 완료 (ready→completed) | `OwnerInProgressOrderTile` 픽업 완료 다이얼로그 | `MarkOrderCompletedUseCase` → `orders.update` O7 |
| 환불 요청 거절 | `owner/orders/**` | `orders.update` (refundRequest.deniedAt 채움) |
| 환불 요청 승인(전액 환불) | `owner/orders/**` | `processRefund` Cloud Function |
| 매출 조회 | `owner/placeholders/owner_sales_placeholder.dart` | **미구현 (placeholder)** |
| 알림 설정 변경 | `common/notification/notification_settings_page.dart` (더보기 > 알림 설정) | `users/{uid}.notificationSettings` (`newOrder` / `refundRequest`), OS 권한 3-state |
| 고객 모드 전환 | `owner/more/owner_more_page.dart` | `DowngradeToCustomerUseCase` |

**핵심 진입점**: `OwnerScaffold` — 4탭 (내 매장 / 주문 접수 / 매출 / 더보기). MVP 는 "내 매장" 탭만 실구현, 매출은 placeholder.

### 4.3 brand

| 액션 | 화면(파일) | 의존 데이터 |
|---|---|---|
| 브랜드 등록 (최초) | `brand/brand_info/brand_info_form_page.dart` (자동 진입) | `BrandRepository.upsertBrand` (batch: brand doc + users.brandId) |
| 브랜드 정보 수정 (이름/설명/로고) | `brand/brand_info/brand_info_page.dart` | `upsertBrand` — 핵심 필드 변경 시 status=pending 회귀 |
| 마스터 메뉴 CRUD | `brand/master_menu/**` | `brands/{brandId}/menuItems` (status=pending → admin 승인) |
| 브랜드 서브 카테고리 CRUD | `brand/sub_categories/**` | `brands/{brandId}/subCategories` |
| 브랜드 옵션 그룹 CRUD | `brand/option_groups/**` | `brands/{brandId}/optionGroups` |
| 가맹점(매장) 목록 조회 | `brand/stores/**` | `stores` where `brandId == myBrandId` |
| 가맹점 매장 운영 필드 수정 | `brand/stores/**` | `stores.update` (Rules `isStoreOwnerBrandUpdate`) |
| 가맹점별 마스터 메뉴 오버라이드 (priceOverride/excluded) | `brand/customization/**` | `menuOverrides` 핵심 필드 → status=pending |
| 가맹점별 마스터 메뉴 운영 토글 | `brand/customization/**` | `menuOverrides` 운영 필드 즉시 반영 |
| 검토 현황(승인 대기 추적) | `brand/approval_tracking/brand_approval_tracking_page.dart` | 모든 본인 brand 산하 pending 엔티티 집계 |
| 로그아웃 | `brand/more/brand_more_page.dart` | `authProvider.signOut()` |

**핵심 진입점**: `BrandScaffold` — 4탭 (브랜드 정보 / 마스터 메뉴 / 매장 / 더보기). `users.brandId` 비어있으면 등록 폼 강제.

**미구현**: brand 가 가맹점 마스터 옵션그룹 직접 수정(매장 한정) — sub-phase 7 S2 에 따라 마스터 메뉴는 master ∪ brand scope 만 허용.

### 4.4 admin

| 액션 | 화면(파일) | 의존 데이터 |
|---|---|---|
| 승인 큐 (브랜드/메뉴/매장/매장 커스텀) | `admin/approval/admin_approval_queue_page.dart` | 각 컬렉션의 `status=pending` 스트림 |
| 브랜드 승인/반려 | `admin/approval/admin_brand_approval_detail_page.dart` | `approveBrand` (brandKey 자동 발급) / `rejectBrand` |
| 매장 승인/반려 | `admin/approval/admin_store_approval_detail_page.dart` | `approveStore` / `rejectStore` |
| 마스터 메뉴 승인/반려 (브랜드별) | `admin/approval/admin_master_menu_approval_detail_page.dart` | `approveMasterMenuItem` / `rejectMasterMenuItem` |
| 메뉴 오버라이드 승인/반려 | `admin/approval/admin_menu_override_approval_detail_page.dart` | `approveOverride` / `rejectOverride` |
| 브랜드 매장 한정 메뉴 승인/반려 | `admin/approval/admin_brand_store_item_approval_detail_page.dart` | `approveStoreOnlyMenu` / `rejectStoreOnlyMenu` |
| 브랜드/매장 관리 | `admin/brand_store_management/**` | 모든 brand/store CRUD (Rules 전권) |
| 메뉴 카테고리 마스터 데이터 | `admin/menu_categories/**` | `mainCategories`, 글로벌 `subCategories`, 글로벌 `optionGroups` |
| 더보기 | `admin/more/admin_more_page.dart` | — |

**핵심 진입점**: `AdminScaffold` — 2탭 (승인 큐 / 더보기). 회원 정지·매출 종합·공지/배너·쿠폰 등 product_scope 의 다른 admin 기능은 **미구현**.

---

## 5. 흐름별 끼어들기 가이드 (신규 feature 작성 시 참고)

신규 기능을 추가할 때, 다음 표를 보고 어디에 진입점을 둘지 결정한다.

| 신규 기능 성격 | 추가 위치 (Scaffold) | 권한 검증 | 데이터 측면 |
|---|---|---|---|
| 고객 탐색 / 주문 흐름 확장 | `customer/...` | role 검증 불필요 (로그인만) | `stores` / `orders` / `users/{uid}/*` |
| 고객 주문 후 액션 (취소/환불/리뷰) | `customer/order/...` | `userId == uid` 본인 검증 | `orders.update` Rules 분기 또는 Cloud Function |
| 점주의 매장 운영 기능 | `owner/...` | `stores/{id}.ownerId == uid` (Rules) + Repository `_assertOwnership` | `stores/**` 또는 `orders` (storeId 매칭) |
| 브랜드 본사 통합 관리 | `brand/...` | `users.brandId == brandId` (`isBrandHolder`) | `brands/{brandId}/**` 또는 `stores` (brandId 매칭) |
| admin 승인 게이트 | `admin/approval/...` | `userRole() == 'admin'` | 모든 컬렉션의 status=pending 스트림 |
| 결제 / 환불 / 외부 API | (UI는 customer/owner 어디든) | Cloud Function 내부에서 재검증 | **반드시 Cloud Function 경유** (Firestore 직접 update 금지) |

---

## 6. 알려진 미구현 / 보류

| 항목 | 상태 |
|---|---|
| 리뷰 작성/평점 UI | **미구현** — `reviews` Rules 만 정의 |
| Qoin 적립 / 사용 | **미구현** — 컬렉션 미정의, `no_op_qoin_accrual_hook` placeholder 만 존재 |
| 선물하기 (기프트카드/쿠폰) | **미구현** |
| 매출 조회 (owner/admin) | **미구현** — `OwnerSalesPlaceholder` |
| FCM 푸시 (주문 상태 변화) | **확인 필요** — `users.fcmToken` 필드는 Rules 허용, 실제 발송 로직 미확인 |
| 회원 정지 / 탈퇴 (admin) | **미구현** — Rules `users.delete: if isAdmin()` 만 정의 |
| 공지 / 배너 / 쿠폰 관리 (admin) | **미구현** |
| brand role 자체 다운그레이드 UI | **미구현 (불일치)** — Rules 는 허용하나 UI 진입점 없음 |
| owner → brand UI 진입점 | **미구현** — 점주 더보기에 없음 |
| `users.brandId` 재할당 | **불일치 (재설계 후보)** — Rules 가 빈 값일 때만 set 허용, 한번 채워지면 재변경 불가 |

---

## 7. 참조

- 사용자 역할 정의: [`lib/domain/entities/user_role.dart`](../../lib/domain/entities/user_role.dart)
- 라우터: [`lib/presentation/common/role_router.dart`](../../lib/presentation/common/role_router.dart)
- 각 Scaffold:
  - [`lib/presentation/customer/...` (ScaffoldWithNav)](../../lib/presentation/common/scaffold_with_nav.dart)
  - [`lib/presentation/owner/owner_scaffold.dart`](../../lib/presentation/owner/owner_scaffold.dart)
  - [`lib/presentation/brand/brand_scaffold.dart`](../../lib/presentation/brand/brand_scaffold.dart)
  - [`lib/presentation/admin/admin_scaffold.dart`](../../lib/presentation/admin/admin_scaffold.dart)
- Security Rules 의 role 분기: [`firestore.rules`](../../firestore.rules) (`userRole()`, `isAllowedSelfRoleChange` 등)
