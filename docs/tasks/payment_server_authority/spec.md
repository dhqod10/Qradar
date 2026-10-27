# 결제·권한의 서버 권위화 (payment_server_authority) 기능 명세

- 작성: 2026-10-27
- 작성자: architect
- 묶음: "서버가 권위를 갖는가" 3건 + `home_search` F8(장바구니·결제 품절 검증)
- 선행 문서: `docs/backlog.md:280-320` · `docs/backlog.md:211-240` · `docs/backlog.md:600-625` ·
  `docs/tasks/home_search/spec.md:944` · `:1211` · `docs/processes/data_ownership.md` §2.5 ·
  `docs/processes/audit_trail.md` §4 · `docs/tasks/qoin_accrual_rate_hierarchy/spec.md` §21.7 ·
  `docs/tasks/qoin_accrual_rate_hierarchy/deploy_runbook.md`

---

## 0. 개요

- **목적**: 지금 서버가 전혀 보지 않는 4가지 사실을 서버의 권위 아래로 옮긴다.
  ① 결제 시점의 매장 판매 가능 여부 ② 결제 시점의 메뉴 품절·판매중단 여부
  ③ 브랜드 열쇠(`brandKey`)와 브랜드 PII 의 열람 범위 ④ 매장 하드 삭제 권한
- **작업 유형**: 기존 기능 수정 (보안·권위) + 소규모 신규 (CF 2개, 컬렉션 2개)
- **착수 근거**: **실결제 0회인 지금**이 결제 경로를 건드릴 수 있는 유일한 창이다.
  손님이 돌기 시작하면 잘못 막는 순간 매출이 멈추고 테스트 창도 좁아진다 (`backlog.md:613-616`).
- **묶는 근거**:
  - ⓐ Rules 배포를 한 번으로 줄인다. Rules 배포는 앱 배포와 순서를 맞춰야 한다 (런북 ③→④).
  - ⓑ 결제 시점 status 게이트와 F8 품절 검증은 **같은 지점**(`verifyTossPayment` 의 Toss confirm 직전)을
    건드린다. 따로 하면 같은 코드를 두 번 열고, 두 번째가 첫 번째의 가드 테스트를 깨뜨린다.

### 영향 범위

| 영역 | 내용 |
|---|---|
| 화면 | **결제 — `lib/presentation/customer/checkout/`** (`checkout_page.dart` 선검증·거절 전달 / `payment_result_page.dart` 거절 사유 매핑). ⚠️ **`customer/payment/` 는 존재하지 않는다 — 경로는 `customer/checkout/` 이다** (design 경로 정정 수용). **카트 — `lib/presentation/customer/cart/`** (`cart_page.dart`, `widgets/cart_line_tile.dart`). **빠른 재주문 — `lib/presentation/customer/home/widgets/quick_reorder_section.dart`**. **점주 — `owner/my_store/my_store_page.dart` 의 `_DangerZone` 호출 2곳(`:317` 개인 매장 / `:391` 브랜드 가맹 매장) 둘 다** (design 4-1·4-2 — spec 초판이 1곳으로 적은 것을 정정). **브랜드 — `brand/brand_info/brand_info_page.dart`**(brandKey 출처), **`owner/my_store/store_core_form_page.dart`**(brandKey 조회). **admin 신규 2화면 — `AdminStoreListPage` · `AdminStoreDeletePage`**(design §7, Q5 ⓐ 확정) + `admin_more_page.dart` 항목 1개 |
| Domain | `canSellNow` 판정 함수(신규, 순수 Dart), `LookupBrandByKeyUseCase` 경로 교체, `DeleteStoreUseCase` 폐기 또는 교체, `CartEntity`/`CartItemEntity` **무변경** |
| Data | `store_remote_data_source.deleteStore` 폐기, `brand_remote_data_source.findByBrandKey`/`isBrandKeyTaken` → callable 로 교체, `BrandModel` 의 비공개 필드 분리 |
| Presentation | checkout/cart/my_store/brand_info/store_core_form 의 Provider 소폭 + **`paymentRejectedMenuIdsProvider`(메모리 전용)** + **admin 매장 목록·삭제 화면용 Provider 2개** |
| 라우팅 | **admin 더보기 → `매장 관리` → 목록 → 삭제 화면** (신규 경로 2개, design §7.0 / Q5 ⓐ). `role_flows.md` §4.4 admin 표에 1행 추가 · §4.2 owner 의 매장 삭제 행 제거 |
| Cloud Functions | **`verifyTossPayment` 개정**(게이트 2개 + 거절 사유 토큰), **`menuVisibility.ts` 신규**(머지 규칙 TS 포팅), `lookupBrandByKey` 신규 callable, `deleteStore` 신규 callable(admin), `approveBrand` 계열의 brandKey 발급 이전 |
| Firestore 구조 | `brands/{id}/private/profile`(신규), `brandKeys/{key}`(신규), `storeDeletionHistory/{id}`(신규), `paymentGateRejections/{id}`(신규) |
| Rules | **`stores` `allow create` 에 승인 메타 설정 금지**(G1 의 성립 조건, §6.5) + `brands` read 축소 + 서브문서 2개 + `brandKeys` + `stores.delete` 축소 + 신규 컬렉션 3개 |
| 권한/환경 | Rules·CF 배포. 환경변수 변경 없음 |
| 테스트 | Rules 하네스, functions npm test, Dart↔TS 교차 골든, 가드 테스트 |

### 비범위 (이번 작업에서 제외)

1. **서버 가격 재계산** — 조사 중 발견한 **별개의 더 큰 구멍**이다 (§5-6). 이번에 읽기 경로만 만들어 두고
   실제 재계산은 분리한다 → **Q6**.
2. 매장 `status` 전이에 `closed`/`deleted` 를 추가하는 **lifecycle 변경** → Q3 ⓒ 를 고르지 않으면 제외.
3. 핵심 필드 수정을 `pending` 회귀와 분리하는 **심사 정책 변경** → Q1 ⓒ 를 고르지 않으면 제외.
4. `brands` 부모 문서의 `name`/`status`/`qoin*` 를 비공개화하는 것 (비밀이 아니다) → Q2 ⓐ 를 고르지 않으면 제외.
5. `quick_reorder_section` 의 가격 역산 제거 (§5-2 에 기록, 후속).
6. APNs / 매장 목록 100건 절단 / UI 전면 개편.

### 흡수하는 backlog 항목

- `docs/tasks/home_search/spec.md:1229` 의 완료 기준 **"`docs/backlog.md` 에 F8 등재"** 는 **미이행**이다.
  이 spec 이 F8 을 흡수하므로 그 체크는 **이 문서로 대체 이행**한다. developer 는 `backlog.md` 에
  "F8 → payment_server_authority 로 흡수" 1행을 남긴다.
- `backlog.md` 의 ⬜ 3건(결제 status 게이트 / brands read 축소 / stores.delete 재설계)과
  ⬜ 묶음 제안은 이 task 완료 시 ✅ 로 전환한다.

---

## 1. 의존 관계와 부분 배포 가능성

```
G1 결제 status 게이트 ──┐
                        ├─ 같은 CF 같은 지점. 함께 배포한다 (분리 불가)
G2 결제 품절 검증   ──┘        ↓ 완화
                        D1 stores.delete (G1 이 닫으면 "삭제·재생성으로 적립 재개" 가 막힌다)

B1 brands read / brandKey ── 독립 (G1·G2·D1 과 코드 접점 0)
```

| 항목 | 산출물 | 다른 항목에 대한 의존 | 혼자 배포 가능? |
|---|---|---|---|
| **G1** 매장 판매 가능 게이트 | **Rules(A) + CF** | **Rules-A 가 성립 조건이다** (§6.5) — 없으면 게이트가 무의미 | **가능** (Rules-A 는 앱과 순서 제약이 없다 — §17.1) |
| **G2** 품절·판매중단 게이트 | CF + 앱(선검증·문구) | G1 과 **같은 함수·같은 지점** | **불가** — G1 과 한 배포 |
| **B1** brands read / brandKey | Rules + CF + 앱 | 없음 | **가능** (단 ③→④ 순서 필수) |
| **D1** stores.delete | Rules + CF + 앱 | G1 이 **잔여 위험을 완화**하지만 선행은 아님 | **가능** (단 ③→④ 순서 필수) |

**하나가 실패했을 때**:

- **G1+G2 실패 → B1·D1 은 그대로 배포 가능.** 접점이 없다. 롤백은 CF 재배포 1회 + Rules-A 되돌리기.
- **B1 실패 → G1+G2 는 영향 없음.** 단 B1 은 Rules+앱 동시 롤백이므로 롤백 비용이 가장 크다.
- **D1 실패 → 나머지 영향 없음.** D1 단독 롤백은 Rules 1줄 되돌리기.
- **Rules 변경이 3덩어리다 — 서로 롤백 단위가 다르다.** 배포 전에 **Rules-A(G1 create 제약) /
  Rules-B(B1) / Rules-C(D1) 패치를 각각 분리 커밋**해 둔다 (developer 지시 사항).
  Rules-A 는 앱과 독립이므로 **먼저 보낸다**(§17). Rules-B·C 는 앱과 함께 움직인다.

> **묶음 근거 ⓐ("Rules 배포를 한 번으로") 는 여전히 유효하다.** 늘어난 것은 **앱과 순서를 맞출 필요가
> 없는** Rules 배포 1회(Rules-A)이고, **앱과 순서를 맞춰야 하는 Rules 배포는 1회(Rules-B+C)로 유지**된다.

---

## 2. 설계 원칙 (이 프로젝트에서 실제로 사고가 난 지점)

1. **검사와 실행은 같은 원자적 경계 안에 있어야 한다.** 검사 후 실행 사이에 상태가 바뀌면 같은 구멍이 난다
   (일괄 적용 S3). Firestore Rules 의 `get()` 은 **배치 이전 상태**를 본다.
2. **클라이언트가 선언한 값을 권위로 삼지 않는다.** F1 에서 `cart.brandId` 를 거부하고
   `stores/{storeId}.brandId` 로 옮긴 판단을 유지한다 (`orderBuilder.ts:10-12`).
3. **한 사실에는 하나의 판정 함수 + 표면 인벤토리 표 + grep 가드** (§21.7 R1~R5).
   표면 인벤토리 표의 **ⓐ 판정 출처 / ⓑ 출처 읽기 실패 시 보이는 것 / ⓒ 복구 동작** 세 열을 모두 채운다.
   ⓑ 가 빈 칸이면 미설계다.
4. **결제 거부는 "돈이 멈추는 방향"이다.** 각 게이트마다 **오탐 시 무슨 일이 일어나는가**를 적는다 (§8).
5. **판정의 fail 방향을 명시한다.** 돈을 주는 방향(적립)은 fail-closed, 돈을 막는 방향(결제 거부)은
   **데이터 부재와 데이터 위반을 구분**한다 (§8.1).

---

## 3. 요구사항

### 기능 요구사항

- [ ] **R1** `verifyTossPayment` 가 Toss confirm **전에** `stores/{cart.storeId}` 를 읽고
      "지금 이 매장이 주문을 받을 수 있는가" 를 판정한다. 판정은 단일 함수를 통과한다.
- [ ] **R2** 판정은 **"영업 중 매장이 정보를 고치는 동안 결제가 막히지 않는다"** 를 불변식으로 지킨다.
      즉 `status == 'approved'` 를 그대로 강제하지 않는다.
- [ ] **R3** `verifyTossPayment` 가 Toss confirm **전에** 카트의 모든 `menuItemId` 에 대해
      품절 / `excluded` / 삭제를 판정한다.
- [ ] **R4** 품절 판정은 `applyOverrideForCustomer` 와 **같은 규칙**이어야 하며, 두 구현이 갈라지지 않음을
      **기계로 고정**한다 (Dart↔TS 교차 골든).
- [ ] **R5** 게이트 거절 시 Toss 승인(confirm)을 **하지 않는다** — 돈이 움직이기 전에 거절한다.
- [ ] **R6** 게이트 거절 사유가 고객에게 **사람 문장으로** 보인다. 현재는 `e.toString()` 이 그대로 노출된다
      (`checkout_page.dart:137`).
- [ ] **R7** 게이트 거절 1건마다 Firestore 에 기록이 남는다 (오탐 탐지용, §9-7).
- [ ] **R8** `brandKey` 가 **로그인한 제3자에게 읽히지 않는다.**
- [ ] **R9** 브랜드 PII(`businessRegistrationNumber` / `representativeName` / `contactName` /
      `contactPhone` / `headOfficeAddress`)가 제3자에게 읽히지 않는다.
- [ ] **R10** `brandKey` 로 브랜드를 찾는 점주 흐름이 **계속 동작**한다 (경로만 CF 로 바뀐다).
- [ ] **R11** `brandKey` 의 유일성이 **쿼리가 아니라 구조로** 보장된다.
- [ ] **R12** 점주가 자기 매장을 **하드 삭제할 수 없다.**
- [ ] **R13** 매장 삭제에 **이력이 남고** 하위 데이터가 고아로 남지 않는다 (Q3 선택에 따름).
- [ ] **R14** 기존 승인 매장·브랜드가 마이그레이션 없이 깨지지 않거나, 필요한 백필이 명시된다.

### UI 요구사항

- [ ] **U1** 카트/체크아웃에서 **결제 버튼을 누른 뒤 Toss 창이 뜨기 전에** 품절·판매중단을 알린다 (Q4).
- [ ] **U2** 결제 실패 화면이 게이트 사유별로 다른 문장을 보여준다 (품절 / 매장 / 메뉴 없음).
- [ ] **U3** 점주 매장 삭제 버튼이 사라지거나 "폐업 신청" 으로 바뀐다. **버튼을 누르면 아무 일도 안 일어나는
      상태로 두지 않는다** (Rules 만 닫으면 `permission-denied` 가 "삭제에 실패했어요" 로 보인다 —
      `my_store_page.dart:1013`).
- [ ] **U4** `brand_info_page` 의 brandKey 행이 출처 변경 후에도 같은 것을 보여준다. **읽기 실패를
      "미발급" 으로 오해시키지 않는다** (`BrandModel.fromFirestore` 가 `brandKey` 부재 시 `''` 폴백 →
      "승인 후 발급" 문구로 조용히 바뀐다).

### 상태 요구사항

- [ ] loading — 선검증 중 결제 버튼 비활성 + 진행 표시 (기존 `_processing` 재사용)
- [ ] error — 선검증 자체가 실패(네트워크)했을 때: **결제를 막지 않는다.** 권위는 서버다 (§8.2)
- [ ] empty — 해당 없음

---

## 4. 용어

| 기호 | 의미 |
|---|---|
| **G1** | 결제 시점 매장 판매 가능 게이트 |
| **G2** | 결제 시점 메뉴 품절·판매중단 게이트 |
| **B1** | `brands` read 축소 / `brandKey` 비공개화 |
| **D1** | `stores.delete` 정책 재설계 |

---

## 5. 현상 (조사 결과 — 재조사하지 말고 여기서 출발한다)

### 5-1. 결제 경로 전체

```
cart_page.dart:312  → CheckoutPage (검증 0)
checkout_page.dart:45 _handlePay
  :56  amount = cart.subtotal
  :64  launchPayment  → TossPaymentRemoteDataSource.requestPayment:77
                        → _TossPaymentPage → PaymentWidget.requestPayment:249   ← 고객이 카드 입력·승인창 통과
  :109 verifyAndCreateOrder → payment_gateway_repository_impl.dart:96
                        → verifyTossPayment (CF)
                              :86-116  멱등 가드
                              ★ 여기가 유일한 "confirm 전 서버 지점" ★
                              :118-133 Toss confirm   ← 돈이 실제로 움직이는 곳
                              :137-160 응답 검증 (실패 시 cancelPayment)
                              :196-205 batch: orders/{id} + users/{uid}/orderLogs/{logId}
  :121 clearCart (성공 경로만)
  :133 catch → PaymentResultPage(fail, errorMessage: e.toString())
```

- **`orders` 의 클라이언트 create 는 Rules 로 차단되어 있다** (`firestore.rules:206 allow create: if false`).
  따라서 `verifyTossPayment` 가 **유일한 주문 생성 경로**이고, 여기에 게이트를 두면 우회로가 없다.
  **G1·G2 는 Rules 변경이 필요 없다.**
- CF 는 `stores` 를 전혀 읽지 않는다. `functions/src` 에서 `stores` 를 읽는 것은
  `cancelTossPayment.ts:85` · `onOrderCreated.ts:48` · `onOrderQoinSettled.ts:213` ·
  `auditBrandLinks.ts:150` · `onReviewWritten.ts` 뿐이다.
- `functions/src` 전체에 `soldOut` / `menuOverrides` 문자열 **0건**. **CF 쪽 override 머지 구현은 0개**다.
- 장바구니는 **완전 로컬 in-memory·비영속**이다 (`cart_local_data_source.dart:10`,
  "앱 재시작 시 초기화"). 활성 카트는 1매장만 (`:35-41`).

### 5-2. `soldOut`

- 판정 유일 구현: `lib/core/utils/store_menu_visibility.dart:39` `applyOverrideForCustomer`
  — **핵심 필드(`excluded`/`priceOverride`)는 `override.status == approved` 일 때만, 운영 필드
  (`soldOut`/`disabledOption*`)는 status 무관 즉시 적용.**
- 쓰기: `toggle_sold_out_use_case.dart:8-27` → 개인/점포한정은 `stores/{id}/menuItems/{id}.soldOut`,
  가맹점은 `stores/{id}/menuOverrides/{masterId}.soldOut` (upsert 시 `status:'approved'` 생성).
  **점주 토글용 CF 는 없다 — 클라이언트가 Firestore 에 직접 쓴다.**
- `cart_page.dart` / `checkout_page.dart` 에 `soldOut` 참조 **0건**. 담기 시점
  (`menu_item_detail_page.dart:646` 가드) 이후 결제까지 재검증이 전혀 없다.
- `quick_reorder_section.dart:226-245` 는 과거 주문의 items 를 **단가를 역산**해 그대로 카트에 재투입한다.
  품절·가격·존재 여부 확인이 없다. **G2 의 가장 쉬운 발생 경로**이므로 표면 인벤토리에 넣는다.
- `firestore.rules` 에 `soldOut` 문자열 0건 (필드 단위 규칙 없음).

### 5-3. 카트의 식별자 — CF 가 어느 문서를 읽어야 하는가

`CartItemEntity` (`cart_item_entity.dart:11-20`): `cartItemId`(로컬 uuid), `menuItemId`,
`menuItemName`, `imageUrl`, `quantity`, `selectedOptions`, `unitPriceWithOptions`, `lineTotal`.
`CartEntity` (`cart_entity.dart:12-16`): `storeId`, `storeName`, `items`, `subtotal`.

- `menuItemId` 의 의미가 **두 가지로 섞여 들어온다**:
  브랜드 마스터 메뉴면 `brands/{brandId}/menuItems/{id}`, 개인/점포한정이면
  `stores/{storeId}/menuItems/{id}`. `MenuItemEntity` 에는 `scope`(`:35`)·`brandId`(`:37`) 가 있지만
  **`CartItemEntity` 로 넘어가지 않고 `cartToMap` 도 보내지 않는다.**
- → **CF 는 문서 존재로 역추론한다.** `scope` 를 카트에 추가해 CF 가 믿는 설계는 원칙 2 위반이므로
  채택하지 않는다 (§6.3).

### 5-4. 매장 status 와 `approvedAt`

- `StoreModel.toFirestoreForCoreUpdate` (`store_model.dart:261-281`): 핵심 필드 수정 시
  `status: 'pending'` 회귀 + `submittedBy`/`submittedAt` 갱신. **`approvedBy`/`approvedAt` 는
  `isResubmit == true` 일 때만 null 로 클리어**한다 (`:276-280`).
- `store_repository_impl.dart:182` — `isResubmit` 는 **`rejected` 상태에서의 수정**일 때 참.
- `entity_approval_status.dart:3` 주석: **"`approvedAt != null && status == pending` 이면 수정 대기"**
  — 즉 **"한 번 승인된 적이 있다" 는 사실이 이미 `approvedAt` 에 남아 있다.**
- Rules 화이트리스트(`firestore.rules:326-353`)는 점주에게 `status`·`submittedBy`·`submittedAt`·
  `approvedBy`·`approvedAt` 변경을 **허용하지만**, `status` 는 `'pending'` 으로만, `approvedBy`/
  `approvedAt` 는 **null 클리어만** 허용한다. → **점주는 update 로 `approvedAt` 에 거짓 값을 심을 수 없다.**
- 🔴 **그러나 `create` 경로는 막혀 있지 않다** (`firestore.rules:302-309`). `allow create` 가 보는 것은
  `isOwner()` · `ownerId == uid()` · `status == 'pending'` · `!hasQoinManagedOnCreate()` ·
  `brandId` 얕은 검증 **5개뿐**이고, **`approvedBy`/`approvedAt`/`rejectedReason` 는 create payload 에서
  제한되지 않는다.** 즉 점주가 `status:'pending'` + `approvedAt:<임의 시각>` 으로 매장을 생성하면
  ⓑ′ 판정식을 **그대로 통과**한다. 이것은 D1 이 묘사하는 "삭제 후 같은 ID 재생성" 경로와 정확히 겹치고,
  **ⓑ′ 를 그대로 구현하면 게이트가 무의미해진다** → §6.5 가 성립 조건으로 닫는다.
- ✅ **현재 앱의 create payload 2개는 승인 메타를 보내지 않는다.** `toFirestoreForCreate`
  (`store_model.dart:238-259`)와 `toFirestoreForBrandCreate`(`:300-318`) 둘 다 `approvedBy`/
  `approvedAt`/`rejectedReason` 키가 없다 (`store_remote_data_source.dart:66`·`:72` 가 유일한 호출자).
  → **Rules create 제약은 구버전 앱과 호환되고, 앱보다 먼저 배포할 수 있다** (§17 순서의 근거).
- 참고: 앱의 매장 생성은 `_stores.add()`(자동 ID)다. **같은 ID 재생성은 앱 경로로는 불가능하고**
  SDK 직접 조작(`.doc(id).set()`)이 필요하다. 그래도 Rules 가 허용하는 한 성립한다.
- ⚠️ **`docs/processes/entity_lifecycle.md` §3.3 은 낡았다.** "Rules 화이트리스트에 승인 메타가
  없어서 차단될 가능성" 을 적고 "확인 필요" 로 남겨 두었는데, 실제 Rules 는 이미 3번 선택지
  (화이트리스트에 승인 메타 추가)를 채택했다. **이 spec 이 그 사실을 확정하고 문서를 갱신한다.**
- ⚠️ `EntityApprovalStatus.fromString` (`:14-23`) 은 **알 수 없는 값/부재를 `approved` 로 폴백**한다
  (legacy 안전). **CF 는 이 fail-open 을 복제하면 안 된다** (§8.1).

### 5-5. `brands`

- Rules `firestore.rules:438` — `allow read: if isSignedIn()`. 로그인한 누구나 모든 브랜드의
  `brandKey` + `companyName` + `businessRegistrationNumber` + `representativeName` +
  `contactName` + `contactPhone` + `headOfficeAddress` 를 읽는다.
- **`customer` 는 `brands/{id}` 문서를 읽지 않는다** (전수 확인). 고객이 의존하는 것은 서브컬렉션
  (`brands/{id}/menuItems` · `subCategories` · `optionGroups`) 뿐이다 →
  **부모 문서 read 를 좁혀도 고객 영향 0. 단 서브컬렉션 read 는 반드시 열어둔다.**
- `owner` 는 **남의 브랜드 문서를 단건으로 읽는다** (`my_store_page.dart:336`,
  `qoin_rate_info_row.dart:616`, `qoin_rate_providers.dart:59`). Rules 는 "이 사용자가 그 브랜드를
  가리키는 매장의 점주인가" 를 **storeId 없이 증명할 수 없다** → 부모 문서를 holder-only 로 좁히면
  점주 화면이 깨진다. 이것이 Q2 의 핵심 제약이다.
- `brandKey` 를 읽는 **CF 는 0개**. Rules 내부 `get(.../brands/...)` 는 **`firestore.rules:308` 단 1곳**이고
  **`status` 만** 본다. `isBrandHolder` (`:57-62`) 는 brands 를 읽지 않고 `users.brandId` 만 본다.
- brandKey 발급·유일성 검증이 **클라이언트**에 있다: `brand_repository_impl.dart:134-140`
  `_generateUniqueBrandKey` → `isBrandKeyTaken` (`where brandKey== .limit(1)`, 최대 3회) →
  `brand_remote_data_source.update` 가 **클라이언트에서 brandKey 를 쓴다.**
  **쿼리 기반 유일성이라 경쟁 조건에서 중복이 가능하다.**
- 표시 표면은 `brand_info_page.dart` 의 `_BrandKeyRow` **1곳**뿐 (조건 `:190`, 표시 `:211`,
  복사 `:231`, 미발급 안내 `:260`). admin 승인 상세는 brandKey 를 표시하지 않는다.
- 입력 표면: `store_core_form_page.dart:15` 정규식 `^BR-[A-Z2-9]{8}$`, 조회 `:290`.
- `BrandScopeBadge` (`admin/widgets/brand_scope_badge.dart:18-39`) 는 `brandId` 하나를 받아
  `storeBrandLinkProvider` → `brandByIdProvider` → `streamById` 로 **brand 문서를 읽는다**
  (`status`·`name`). 읽기 실패를 `lookupFailed`/`missing` 으로 구분해 경고를 띄우고
  **승인 버튼을 끈다** (`store_brand_link.dart:47` `approveEnabled`) — 의도된 fail-closed.
  사용 화면: `admin_pending_stores_page` · `admin_store_approval_detail_page` ·
  `my_store_page`(owner 도 쓴다).

### 5-6. ⚠️ 조사 중 발견 — 서버 가격 재계산이 없다 (이번 범위 밖, Q6)

`verifyTossPayment` 의 금액 검증은 2개뿐이다.

| 위치 | 비교 | 문제 |
|---|---|---|
| `:77-81` | `data.amount !== data.cart.totalPrice` | **둘 다 클라이언트 값**이다. 자기 자신과 비교하므로 의미가 없다 |
| `:141` | `tossResponse.totalAmount === data.amount` | Toss 승인액 vs 클라 요청액 — 승인액이 맞는지만 본다 |

`items[].unitPriceWithOptions` / `lineTotal` / `subtotal` 합산 검증도, 메뉴 문서 기준 단가 조회도 없다
(`orderBuilder.ts:57,59,84` 는 cart 값을 그대로 복사만 한다). **클라이언트가 보낸 가격이 그대로 주문·적립
기준이 된다.** G2 가 만드는 읽기 경로(마스터 메뉴 + override)에 **단가가 이미 들어 있으므로** 나중에 매우
싸게 닫을 수 있다 → **Q6**.

### 5-7. `stores.delete`

- Rules `:311` — `allow delete: if isAdmin() || isStoreOwner(storeId)`.
- 점주 UI: `my_store_page.dart:967` `_confirmDelete` → **Storage 이미지를 먼저 전부 삭제**(`:1000-1007`)
  → `deleteStoreUseCaseProvider.call(store.id)` (`:1009`) → `store_remote_data_source.dart:102`
  `_stores.doc(storeId).delete()`.
  - ⚠️ **이미지 삭제가 문서 삭제보다 먼저다.** 문서 삭제가 실패하면 이미지만 사라진 매장이 남는다.
    현재도 데이터 손실 경로다.
- **admin 에게는 매장 삭제 UI 가 없다** (`deleteStoreUseCaseProvider` 소비 지점은 owner 1곳뿐).
  즉 "admin 전용 하드 삭제" 는 현재 Firebase Console 에만 존재한다.
- 서브컬렉션 `qoinRateHistory` / `menuItems` / `menuOverrides` / `subCategories` / `optionGroups` 가
  고아가 되고, 점주 read 는 `get(store)` 실패로 거부되어 **admin 만 읽을 수 있다.**

---

## 6. 설계 — G1 매장 판매 가능 게이트

### 6.1 불변식

> **영업 중 매장이 정보를 고치는 동안 결제가 막히지 않는다.**

`status == 'approved'` 강제가 금지되는 이유: 승인된 매장이 이름·주소·전화·설명·카테고리를 고치면
`toFirestoreForCoreUpdate` 가 `status: 'pending'` 을 쓴다. **점주가 전화번호 한 줄 고치는 순간
정상 손님의 결제가 거부된다.**

### 6.2 안 비교 → **Q1 = ⓑ′ 확정** (2026-10-27 사용자 결정)

| 안 | 판정식 | 닫히는가 | 대가 |
|---|---|---|---|
| **ⓐ** `rejected` 만 막는다 | `status != 'rejected'` | **아니다.** 한 번도 승인되지 않은 `pending` 매장(삭제·재생성 포함)이 그대로 통과한다 → **잔여 위험이 남는다** | 가장 쌈. 마이그레이션 0 |
| **ⓑ′** 승인 이력으로 판정 — **신규 필드 없이** | `status == 'approved' \|\| (status == 'pending' && approvedAt != null)` | **닫힌다.** 신규/재생성 매장은 `approvedAt` 이 없고(create 경로가 쓰지 않는다), `rejected` 재제출은 `isResubmit` 가 `approvedAt` 를 클리어한다 | 소규모 백필 1건 (§11-1). 점주가 `approvedAt` 를 **null 로만** 바꿀 수 있어 위조 불가 |
| **ⓒ** 핵심 필드 수정을 `pending` 회귀와 분리 | `status == 'approved'` 를 그대로 쓸 수 있게 된다 | 닫힌다 | **심사 의미가 바뀐다.** `entity_lifecycle.md` 재검토 + admin 재심사 흐름 재설계 + "수정 대기" 개념 폐기. 이번 묶음에 넣으면 범위가 2배가 된다 |

**확정: ⓑ′.** 단 **§6.5 의 Rules 제약 2건(create + `rejected` 전이)이 성립 조건**이다
(선택적 보강이 아니다).

> 🔴 **2026-10-27 T-1 정정 — ⓑ′ 의 전제 한 줄이 틀렸다 (F-02).**
> 아래 "`rejected` 에서의 수정은 `isResubmit` 가 `approvedAt` 를 클리어한다" 는 **클라이언트 코드의
> 선택이고 Rules 가 강제하지 않는다.** 게다가 **`rejectFields` (`store_model.dart:331-340`) 가 반려할
> 때도 `approvedAt: serverTimestamp()` 를 쓴다** — 즉 **한 번도 승인되지 않고 반려만 된 매장도
> `approvedAt != null` 이다.** 점주가 `updateDoc({status:'pending'})` 만 보내면
> `pending && approvedAt != null` 을 통과한다(tester 가 에뮬레이터에서 `canSellNow === true` 재현).
> → **§6.5 의 전이 제약**이 즉시 차단하고, **§6.8 가 근본(`rejectedAt` 분리)을 고친다.**

- backlog 가 ⓑ 에 대해 적은 "승인 이력 필드 필요" 는 **이미 존재한다.** `approvedAt` 이 그 필드다
  (`entity_approval_status.dart:3` 이 그 의미를 명시한다). 새 필드·새 마이그레이션이 필요 없다.
- ⓐ 는 "삭제·재생성으로 적립 재개" 라는 **원래 잡으려던 잔여 위험을 못 잡는다.**
- ⓒ 는 올바른 장기 방향이다. 지금도 **승인 매장이 이름만 고치면 고객 목록에서 사라져 매출이 0 이 된다**
  — 서버 게이트와 무관한 기존 제품 결함이다. 하지만 심사 정책 변경이므로 **별도 task 로 분리**하고
  이 spec 은 `backlog.md` 에 등재만 한다. ⓒ 를 나중에 하더라도 ⓑ′ 판정식은 그대로 유효하다
  (`status == 'approved'` 가 항상 참이 되어 두 번째 절이 죽는다 — **ⓑ′ 는 ⓒ 의 전진을 막지 않는다**).

### 6.3 판정 함수 — 한 사실에 하나

```
domain (순수 Dart) : lib/core/utils/store_sellability.dart
    bool canSellNow({required String? rawStatus, required bool hasApprovedAt})

functions (TS)     : functions/src/storeSellability.ts
    export function canSellNow(args: {rawStatus: string | null; hasApprovedAt: boolean}): boolean
```

- **입력은 가공 전 원시값**이다. `EntityApprovalStatus.fromString` 을 **통과시키지 않는다** —
  그 함수는 미지값을 `approved` 로 폴백하는 fail-open 이고, 돈 게이트는 그것을 복제할 수 없다 (§8.1).
- 두 구현은 교차 골든으로 고정한다 (§12-2).
- 화면은 이 함수 결과만 렌더한다. `status` 문자열 직접 비교를 **게이트 목적으로** 새로 만들지 않는다
  (기존 목록 필터링 비교는 건드리지 않는다 — 그것은 노출 판정이고 게이트가 아니다. 가드 테스트의
  허용 목록에 명시한다).

### 6.4 CF 삽입 지점

`functions/src/verifyTossPayment.ts` — **`:116`(멱등 가드 종료) ~ `:118`(confirm 분기 시작) 사이.**
이것이 유일한 "Toss confirm 전 서버 지점"이다. 고객은 이미 승인창을 통과했지만 **돈은 confirm 에서
움직이므로 여기서 거절하면 금전 이동이 없다.**

### 6.5 ⓑ′ 의 성립 조건 — `allow create` 에 승인 메타 설정 금지 (Rules-A)

판정식이 `approvedAt` 을 **권한 판정 입력으로 쓰는 순간** 그 필드는 권한 값이 된다
(`audit_trail.md` §4-1 의 넓은 정의). **권한 값은 모든 쓰기 경로에서 막혀야 하고, create 는 그 경로다.**

```
match /stores/{storeId} {
  allow create: if isOwner()
                && request.resource.data.ownerId == uid()
                && request.resource.data.get('status', 'pending') == 'pending'
                && !hasQoinManagedOnCreate()
                && (!('brandId' in request.resource.data) || ... 기존 brandId 검증)
                // ★ Rules-A 신규 — 승인 메타 자가 설정 금지 (부재 또는 null 만 허용)
                && request.resource.data.get('approvedAt', null) == null
                && request.resource.data.get('approvedBy', null) == null
                && request.resource.data.get('rejectedReason', null) == null;

  // ★ Rules-A 신규 2 (F-02) — `rejected` 에서 벗어나는 전이는 승인 메타를 null 로 강제한다.
  //   isStoreOwnerFieldUpdate / isStoreOwnerBrandUpdate 양쪽 분기에 공통으로 적용한다.
  function leavingRejectedClearsApproval() {
    return !(resource.data.get('status', '') == 'rejected'
             && request.resource.data.get('status', '') != 'rejected')
           || (request.resource.data.get('approvedAt', null) == null
               && request.resource.data.get('approvedBy', null) == null);
  }
  allow update: if !touchesQoinManaged()
                && leavingRejectedClearsApproval()
                && (isAdmin() || isStoreOwnerFieldUpdate(storeId) || isStoreOwnerBrandUpdate());
}
```

**전이 제약(신규 2)의 성질**

| 항목 | 내용 |
|---|---|
| 구버전 앱 호환 | ✅ **깨지지 않는다.** 앱의 정상 재제출은 `isResubmit` 에서 `approvedBy`/`approvedAt`/`rejectedReason` 를 **이미 null 로 지운다** (`store_model.dart:276-280`, `store_repository_impl.dart:182`). 따라서 Rules-A 는 **여전히 앱보다 먼저 배포할 수 있다** (§17 ④ 자리 유지) |
| 걸리는 것 | ⓐ 점주의 SDK 직접 `updateDoc({status:'pending'})` ⓑ **반려 직후 stale entity 로 제출된 앱 폼** — 우연히도 같은 상태를 만든다. 둘 다 막힌다 |
| admin 영향 | `isAdmin()` 분기도 이 제약을 통과해야 한다. admin 이 `rejected → approved` 로 올릴 때 `approveFields` 는 `approvedAt` 에 **값을 쓴다** → ⚠️ **admin 승인이 막힌다.** 그래서 제약은 **점주·브랜드 분기에만** 적용한다 (위 코드는 `allow update` 전체에 걸었으므로 **developer 가 `isStoreOwnerFieldUpdate`/`isStoreOwnerBrandUpdate` 내부로 옮긴다**). 하네스에 **"admin 이 `rejected → approved` 승인" allow 케이스**를 반드시 넣는다 |
| 회귀 케이스 (필수) | **"`rejected → pending` + 승인 메타 null 클리어" 가 여전히 허용**되어야 한다. 점주 분기와 **브랜드 보유자 분기 둘 다** (§18.5) |

- **왜 "성립 조건" 인가**: 이것 없이 CF 게이트만 올리면, 게이트를 통과하는 가장 쉬운 방법이
  "`approvedAt` 을 넣어 매장을 만드는 것" 이 된다. **게이트가 아니라 장식이 된다.**
- 구버전 앱 호환: §5-4 의 ✅ 항목 — 현재 앱의 create payload 2개가 이 키들을 보내지 않으므로
  **이 제약은 앱보다 먼저 배포해도 아무것도 깨지지 않는다.** 그래서 §17 에서 Rules-A 를 선행시킨다.
- `brands` 에도 같은 계열 점검을 한다 — `firestore.rules:443-448` 의 brand create 는
  `brandKey == ''` 를 이미 강제하지만 `approvedBy`/`approvedAt` 는 제한하지 않는다.
  **`brands` 의 승인 메타는 현재 어떤 게이트의 입력도 아니므로 이번 범위에서 고치지 않되,
  B1 작업 중 같은 자리를 열므로 함께 막는다**(비용 0, developer 지시 사항).

### 6.6 판정식이 읽는 필드의 쓰기 경로 매트릭스

ⓑ′ 판정식은 `status` 와 `approvedAt` 두 필드를 읽는다. **각 필드를 누가 어느 경로로 쓸 수 있는가.**

**행위 열을 반드시 채운다 (F-02 가 드러낸 교훈 — 아래 §6.6.1).**

| 필드 | 점주 **create** | 점주 **update** | admin **승인** (`approveFields`) | admin **반려** (`rejectFields`) | 점주 **재제출** (`isResubmit`) | CF | Console |
|---|---|---|---|---|---|---|---|
| `status` | `'pending'` 만 (`:304`) | `'pending'` 만 (`:341-344`) | `approved` | `rejected` | `pending` | 전권 | **Rules 우회** |
| `approvedAt` | 🔴 무제한 → **Rules-A 가 null/부재만** | null 클리어만 (`:349-353`) | **값 설정** (`:325`) | 🔴 **값 설정** (`:338`) — **반려인데 승인 시각을 쓴다** | null 클리어 (`:277`) | 전권 | **Rules 우회** |
| `approvedBy` | 🔴 무제한 → **Rules-A 가 null/부재만** | null 클리어만 (`:345-348`) | 값 설정 | 🔴 **값 설정** (`:337`) | null 클리어 | 전권 | **Rules 우회** |
| `rejectedReason` | 🔴 무제한 → **Rules-A 가 null/부재만** | 변경 허용 | `null` | 값 설정 | null 클리어 | 전권 | **Rules 우회** |
| **전이 `rejected → pending`** | — | 🔴 **승인 메타를 그대로 둔 채 허용** → **Rules-A 전이 제약이 막는다** | — | — | 정상(메타 null) | — | **Rules 우회** |

#### 6.6.1 왜 초판 매트릭스가 F-02 를 못 잡았는가

초판은 **"누가 쓸 수 있는가"** 는 적었지만 **"admin 이 어떤 행위에서 무엇을 쓰는가"** 는 적지 않았다.
`admin: 전권` 한 칸이 **승인과 반려를 같은 칸에 뭉쳐서** `rejectFields` 가 `approvedAt` 에 값을
쓴다는 사실을 가렸다. 권한 판정 입력 필드의 매트릭스는 **주체 × 행위**로 쪼개야 한다.

> **드러난 사실: `approvedAt` 은 "승인됨" 을 뜻하지 않는다. 그 필드 이름이 출처를 거짓으로 말한다.**
> 승인과 반려가 같은 필드에 시각을 쓰므로, `approvedAt != null` 은 "admin 이 이 매장을 **심사했다**"
> 까지만 의미한다. ⓑ′ 는 그 필드를 "승인 이력" 으로 읽었고 그것이 F-02 의 뿌리다.
> → **근본 수정은 §6.8** (`rejectedAt` 분리).

**상시 규칙 보강 (§6.7 에 합산)**: 권한 판정에 쓰는 필드는 `create`·`update` **양쪽 경로**에 더해
**그 필드에 값을 쓰는 모든 행위를 열거**하고, **상태 전이(from → to)** 단위로도 확인한다.
"필드별 허용" 만 보면 **전이 조합**이 빠진다 — F-02 가 정확히 그 구멍이었다.

- **Console 수동 편집은 Rules 를 우회한다.** 따라서 "데이터가 항상 정합하다" 를 가정할 수 없고,
  게이트는 **데이터가 틀어졌을 때 무슨 일이 일어나는지**를 §8 에 적어 두는 방식으로만 방어된다.
  Console 로 `approvedAt` 을 심는 것은 **프로젝트 소유자 권한**이므로 위협 모델 밖이다(그 사람은
  무엇이든 할 수 있다). 다만 **오타로 매장 매출이 멈추는 사고**는 위협 모델 안이고, §9-7 기록이 받는다.
- **M1 백필은 이 표의 🔴 로 이미 생긴 이상치를 함께 찾는다** (§16 M1).

### 6.7 상시 규칙으로 승격 — create·update 교차 확인

> **권한 판정에 쓰는 필드는 `create` 와 `update` **양쪽** 경로를 교차 확인한다.**

이 누락은 **같은 패턴의 네 번째**다 (`isBrandHolder` 의 빈 문자열 구멍도 create 비포함 계열이었다).
`onlyChangedFields` 화이트리스트는 **update 전용 장치**이고, create 에는 아무 보호도 주지 않는다.
**"update 가 막혀 있다" 를 "그 필드가 보호된다" 로 읽는 것이 이 패턴의 공통 원인**이다.

- **표면 인벤토리 표(§21.7 R2)와 같은 급의 상시 가드**로 둔다 → §21 완료 기준 + `tester_guide.md`.
- 기계적 수단: Rules 하네스가 **판정 입력 필드마다 create 거부 케이스를 1건씩** 들고 있어야 한다 (§18.5).

---

### 6.8 근본 수정 — 반려는 `approvedAt` 을 쓰지 않는다 (`rejectedAt` 분리)

**`rejectFields` (`store_model.dart:331-340`) 가 `approvedAt` 대신 `rejectedAt` 을 쓰게 바꾼다.**

```dart
static Map<String, dynamic> rejectFields(String adminUid, String reason) => {
      'status': 'rejected',
      'approvedBy': adminUid,        // 심사자 — 유지 (이름이 사실과 맞지 않지만 이번 범위에서 안 건드린다)
      'rejectedAt': FieldValue.serverTimestamp(),   // ← approvedAt 에서 교체
      'rejectedReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    };
```

- Rules 화이트리스트(점주 update)에 **`rejectedAt` 를 추가하고 null 클리어만 허용**한다
  (`approvedAt` 과 같은 모양). create 에서도 `rejectedAt` 설정을 금지한다(§6.5 신규 1 에 1줄 추가).
- `StoreModel` / `StoreEntity` 에 `rejectedAt` 필드 추가. **G1 판정식은 `rejectedAt` 을 읽지 않는다**
  — 판정 입력은 `status` + `approvedAt` 그대로다(입력을 늘리면 오탐 방향이 늘어난다).
- 이 변경으로 **`entity_approval_status.dart:3` 의 주석(`approvedAt != null && status == pending`
  = "수정 대기")이 더 정확해진다.** 지금은 "반려만 된 매장" 도 그 조건을 만족할 수 있어 주석이
  반쯤 거짓이었다. 전환 후에는 `approvedAt` 이 **승인 행위에서만** 쓰이므로 주석이 참이 된다.
  developer 는 그 주석에 "`approvedAt` 은 승인 행위에서만 쓴다(반려는 `rejectedAt`)" 를 덧붙인다.

**과거 데이터는 복구 불가 — 그래서 자동으로 고치지 않는다.**

반려가 승인 시각을 **덮어썼기** 때문에 `status == 'rejected' && approvedAt != null` 인 매장에서
**"승인 후 반려" 와 "반려만" 을 구분할 수 없다.** 따라서:

- **M1 ⓒ 이상치 감사를 확장**해 `status == 'rejected' && approvedAt != null` 을 **전부 모호 건으로
  보고**한다(§16). **자동으로 고치지 않고 멈추고 보고한다** — 기존 M1 ⓒ 방침과 같다.
- 추가 감사 1건(F-02 self-regress 흔적): **`status == 'pending' && rejectedReason != null &&
  approvedAt != null`**. 기존 감사(`approvedBy == null` 기준)는 이 경우를 **못 잡는다** —
  `approvedBy` 가 admin 값으로 남아 있기 때문이다.

**M1 감사 결과가 0건이 아니어도 배포를 막지 않는다 (판단 근거)**

- 현재 `rejected` 매장은 판정식의 **첫 항(`approved`)·둘째 항(`pending && …`) 모두 불통과**라
  **지금 당장 결제를 받지 않는다.**
- 위험이 발생하는 것은 **점주가 `rejected → pending` 으로 옮기는 순간**뿐이고, **그것을 §6.5 의
  전이 제약이 막는다.**
- 따라서 **§6.5 전이 제약이 배포에 포함된다는 전제 아래**, 모호 건은 "기록으로 남기고 사람이
  판단할 목록" 이며 배포 차단 조건이 아니다. 전이 제약이 빠지면 이 판단도 무효다.

---

### 6.9 `temporaryClosed` 는 **아무 일도 하지 않는다** — 판정식에 넣지 않는다

조사 결과: **`temporaryClosed` 는 쓰기만 되고 아무도 읽지 않는다.** 점주 폼
(`store_operation_form_page.dart:114`)과 모델·엔티티에만 존재하고, **고객 코드 참조 0건 ·
CF 참조 0건**이며 `update_store_operation_fields_use_case.dart:6` 주석에만 등장한다.
→ **점주가 임시 휴업을 켜도 고객 주문이 막히지 않는다.** 점주가 켤 수 있는 스위치가
아무 효과도 내지 못하는 상태다.

**G1 판정식과의 관계 — 이번 범위에 넣지 않는다 (명시적 결정).**

| 안 | 판정식 | 대가 |
|---|---|---|
| **넣지 않는다 (확정)** | `approved \|\| (pending && approvedAt != null)` 그대로 | 임시 휴업 매장의 결제가 **계속 성립한다**(현재와 동일). 구멍이 아니라 **기존 상태 유지**다 |
| 넣는다 | `... && temporaryClosed != true` | **오탐 방향이 하나 늘어난다** — 점주가 휴업을 끄는 것을 잊으면 **매출이 멈춘다.** 그런데 그 필드는 지금껏 아무 효과가 없었으므로 **점주들이 켜 둔 채 방치했을 가능성이 있고, 그 값은 아무도 검증한 적이 없다.** 돈을 멈추는 게이트의 입력으로 쓰기에 **신뢰도가 가장 낮은 필드**다 |

이 필드는 **별개 결함**이다 (주제는 같은 계열 — "서버가 권위를 갖는가"). **N6 으로 등재**하고
이번 묶음의 범위를 넓히지 않는다. N6 을 할 때는 ⓐ 고객 노출 ⓑ 결제 게이트 ⓒ 점주 화면의
"지금 휴업 중" 표시를 **한 번에** 설계해야 한다 — 셋 중 하나만 하면 또 반쪽이 된다.

> **design 에 넘길 수정 1건**: design §6.2 의 점주 안내 문구 첫 문장
> (`잠시 쉬려면 '운영 정보 수정'에서 임시 휴업을 켤 수 있어요`)은 **근거가 사실이 아니다.**
> 그 토글은 고객에게 아무 효과가 없으므로, 점주에게 "쉴 수 있다" 고 안내하면 **거짓 안내**가 된다.
> design §6.2 가 "developer 가 확인하고 아니라면 첫 문장을 빼고 보고한다" 로 열어 둔 조건이
> **확인 결과 성립하지 않는다** → **첫 문장을 제거**한다 (§19 designer 수정 목록 1번).

---

## 7. 설계 — G2 품절·판매중단 게이트

### 7.1 판정은 기존 규칙 1개를 TS 로 **포팅**한다 (복제가 아니다)

`applyOverrideForCustomer` 의 비자명한 분기(핵심 필드는 approved 일 때만 / 운영 필드는 status 무관
즉시)가 서버와 갈라지면 **같은 사실에 두 판정**이 생긴다. 이 저장소에서 그 종류의 FAIL 이 세 번 났고
매번 원인은 "표를 만들었는데 그 사실을 말하는 표면 한 행이 표에 없었다" 였다.

```
functions/src/menuVisibility.ts
    applyOverrideForCustomer({master, override}) → MergedMenu | null
```

**고정 수단 (R4)** — `test_fixtures/menu_visibility_contract.json` (기존
`test_fixtures/qoin_cart_contract.json` 패턴을 그대로 따른다):

| 케이스 | override | 기대 |
|---|---|---|
| 1 | null | 마스터 그대로 |
| 2 | `approved` + `excluded:true` | **null** (판매 안 함) |
| 3 | `pending` + `excluded:true` | 마스터 그대로 (excluded 미적용) |
| 4 | `approved` + `priceOverride:3000` | 가격 3000 |
| 5 | `pending` + `priceOverride:3000` | **마스터 가격** |
| 6 | `pending` + `soldOut:true` | **품절** (status 무관) |
| 7 | `approved` + `soldOut:false` + 마스터 `soldOut:true` | **품절 아님** (override 가 이긴다) |
| 8 | `pending` + `disabledOptionGroupIds:[g1]` | 적용됨 |

Dart 테스트와 `functions npm test` 가 **같은 fixture** 를 읽어 단언한다. 한쪽만 바뀌면 골든이 깨진다.

### 7.2 CF 가 읽는 문서 — 존재로 역추론한다

카트에 `scope`/`brandId` 가 없다 (§5-3). **클라이언트가 선언한 scope 를 믿지 않는다** (원칙 2).

```
① stores/{cart.storeId}                       ← G1 에서 이미 읽는다 (brandId 도 여기서 얻는다)
② getAll(  ← round-trip 1회로 묶는다
     stores/{s}/menuItems/{id}      for each menuItemId
     stores/{s}/menuOverrides/{id}  for each menuItemId
     brands/{b}/menuItems/{id}      for each menuItemId   (store.brandId != null 일 때만)
   )
③ menuItemId 별 분류
     stores/{s}/menuItems/{id} 존재      → 개인/점포한정. soldOut = 그 문서. visible==false → 위반
     없고 brands/{b}/menuItems/{id} 존재 → applyOverrideForCustomer(master, override)
                                            → null        → MENU_EXCLUDED
                                            → soldOut true → MENU_SOLD_OUT
     둘 다 없음                          → MENU_NOT_FOUND
④ 위반 1건이라도 있으면 confirm 하지 않고 거절 (사유 + 위반 메뉴명 목록)
```

읽기 비용: 카트 3품목·가맹점이면 `1 + 9 = 10` reads. `getAll` 로 round-trip 1회. 결제 1건당 비용이고
결제는 희소하므로 수용한다.

> **이것이 CF 쪽 override 머지의 최초 구현이다** (현재 0개). 그래서 §7.1 의 교차 골든을 **먼저** 만든다.

### 7.3 원자적 경계 — confirm 이후를 재검사할 것인가 → **Q5**

Toss confirm 은 외부 HTTP 호출이므로 **Firestore 트랜잭션 안에 넣을 수 없다.** 따라서 게이트와
confirm 사이에 왕복 지연(수백 ms~수초)의 창이 남는다.

| 안 | 동작 | 대가 |
|---|---|---|
| **ⓐ** confirm 후 재검증하지 않는다 (추천) | 게이트는 confirm 직전 1회 | 창 동안 점주가 품절 토글을 누르면 그 1건이 통과한다. **보상 경로가 이미 있다** — 점주 주문 거절/환불(`processRefund`) |
| ⓑ confirm 후 트랜잭션에서 재검증, 위반 시 `cancelPayment` + 주문 미생성 | 창이 거의 0 | **돈이 빠졌는데 주문이 없는 상태**를 만들 수 있다. cancel 이 실패하면 고객은 결제됐고 주문은 없다. 현행 코드도 cancel 실패를 **로그만 남긴다** (`:154`) |
| ⓒ 게이트를 결제창 **앞**의 별도 CF 로 옮긴다 | UX 가 좋다 | 창이 **훨씬 커진다**(고객이 카드 입력하는 시간 전체). 권위 지점이 아니다 |

**설계자 추천: ⓐ.** 원칙 1("검사와 실행이 같은 경계")의 실행은 **금전 이동(confirm)** 이고,
게이트를 그 직전에 두는 것이 이 경계에서 가능한 최선이다. ⓑ 는 구멍을 ms 로 줄이는 대신
**더 나쁜 상태(돈만 빠짐)를 새로 만든다.** spec 에 창의 크기와 보상 경로를 명시하는 것으로 수용한다.

### 7.4 선검증 (클라이언트) → **Q4**

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ** 포함 (추천, 최소) | 체크아웃 **진입 시** 1회 + 결제 버튼 누른 직후 Toss 창 **전에** 1회, 기존 Dart `applyOverrideForCustomer` + `canSellNow` 로 판정. 위반 시 결제창을 띄우지 않고 카트로 되돌린다 | designer 필요(작음). 읽기 1~N회 추가 |
| ⓑ 제외 | 서버만 막는다 | 고객이 **카드 승인창을 끝까지 통과한 뒤** 거절된다. 체감이 매우 나쁘고, "결제됐는데 주문이 없다" 는 오해를 부른다 |

**추천 ⓐ.** 단 **선검증은 권위가 아니다** — 선검증이 네트워크 실패해도 결제를 막지 않고 서버에 맡긴다
(§8.2). 선검증은 UX 장치이고 게이트는 CF 다. **두 곳이 같은 Dart 판정 함수를 쓰므로 판정은 하나다.**

---

## 8. 오탐 — 게이트별 "잘못 막히면 무슨 일이 일어나는가"

### 8.1 fail 방향 표

| 게이트 | 데이터 상태 | 판정 | 결과 | 오탐 시 |
|---|---|---|---|---|
| G1 | `status` 필드 **부재** | **거절**(fail-closed) | 결제 불가 | **legacy 매장이 전부 막힌다.** `StoreModel` 은 부재를 `approved` 로 폴백하므로 앱에서는 정상으로 보인다 → **§11-1 백필이 필수 선행**이다 |
| G1 | `status` 가 알 수 없는 문자열 | **거절** | 결제 불가 | 수동 편집으로만 생긴다. Console 오타가 매장 매출을 멈춘다 → §9-7 기록으로 탐지 |
| G1 | `status:'pending'` + `approvedAt` 있음 | **허용** | 정상 | — |
| G1 | `status:'pending'` + `approvedAt` 없음 | 거절 | 결제 불가 | **신규 미승인 매장.** 의도된 동작. 단 점주가 `approvedAt` 를 null 로 클리어한 승인 매장도 같이 막힌다(재제출 경로뿐이므로 의도와 일치) |
| **모드** | `PAYMENT_GATE_MODE` 가 **없거나 모르는 값** | **`off`** — 평가하지 않는다 | 결제 성립(현재와 동일) | **구멍이 열린 채로 유지된다.** 의도된 선택이다 — **설정 오타로 매출이 멈추는 것보다 구멍이 하루 더 열려 있는 게 낫다**(§17.0). 대가는 "`enforce` 인 줄 알았는데 `off`" 를 놓치기 쉬운 것이고, 런북 ⑥-c 의 **거절 1건 실측**이 그것을 받는다 |
| **모드** | `shadow` | 판정·기록만 | 결제 성립 | **오탐이 기록으로만 나타난다.** 돈이 멈추지 않으므로 ⑥-b 에서 정상 매장이 잡히는지 확인하는 창이 된다 |
| G1 | `status:'rejected'` + `approvedAt` 있음 (반려 매장) | **거절** | 결제 불가 | 의도된 동작. ⚠️ **"영업 중이던 매장의 수정이 반려되면 그 순간 결제가 멈춘다"** (test_report H-08) — 이전에는 장바구니로 계속 결제됐다. 정책 판단이 필요하며 **N2(핵심 수정과 pending 회귀 분리)가 풀어야 할 문제**다. 이번 범위에서는 거절을 유지한다 |
| G1 | `stores/{id}` 문서 자체 부재 | **거절** | 결제 불가 | 매장이 삭제된 것이다. D1 이 이 경로를 줄인다 |
| G1 | 매장 문서 **읽기 실패**(Firestore 장애) | **거절** | 결제 불가 | 전 매장 결제 중단. 대안은 "읽기 실패 시 통과" 인데 그것은 게이트를 무력화한다 → **거절 + 기록 + 재시도 안내** |
| G2 | `soldOut: true` | 거절 | 결제 불가 | **점주가 품절을 끄는 것을 잊으면 정상 손님이 막힌다.** 가장 현실적인 오탐 — 문구가 **어느 메뉴인지 지목**해야 손님이 스스로 복구할 수 있다 |
| G2 | 마스터·점포 문서 둘 다 부재 | 거절 | 결제 불가 | 메뉴가 삭제됐다. 의도된 동작 |
| G2 | `override.status == 'pending'` + `excluded` | **허용** | 정상 | `applyOverrideForCustomer` 와 동일. **여기서 갈라지면 고객이 본 화면과 결제 결과가 다르다** |
| G2 | override 문서 읽기 실패 | **거절** | 결제 불가 | 위와 같다 |

### 8.2 선검증(클라이언트)의 fail 방향은 **반대**다

| 상황 | 동작 | 이유 |
|---|---|---|
| 선검증이 위반을 찾음 | **결제창을 띄우지 않는다** | 서버가 어차피 거절한다. 미리 알리는 것이 친절하다 |
| 선검증 자체가 실패(네트워크/권한) | **결제를 진행한다** | 선검증은 권위가 아니다. 여기서 막으면 **네트워크가 잠깐 나쁜 정상 손님의 결제를 클라이언트가 막는다** — 서버 게이트가 없을 때와 똑같은 종류의 사고다 |

### 8.3 오탐 탐지 수단

§9-7 의 `paymentGateRejections` 가 **오탐 탐지 장치**다. 거절이 "악용 차단" 인지 "데이터가 틀어져서
정상 손님을 막은 것" 인지는 **건수와 분포를 봐야** 구분된다. 기록이 없으면 그 구분이 불가능하다.

---

## 9. 이력 / 감사 추적 (`audit_trail.md` §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| **1** | 돈·권한·정책 값을 바꾸는가 → **설정 변경 이력이 기본값** | **그렇다, 3건.** ⓐ **`brandKey` 발급/재발급** — 열쇠는 가맹 신청의 권한 근거이므로 **권한 값**이다(§4-1 의 넓은 정의: 한 필드가 자원 트리의 쓰기 권한을 결정하면 권한 값이다). 지금은 **클라이언트가 brandKey 를 쓰고 이력이 없다** → **CF 전담 + `brands/{id}/keyHistory/{autoId}`.** ⓑ **매장 삭제** → `storeDeletionHistory/{autoId}` (Q3). ⓒ **매장 status 전이** — admin 승인/반려에 이력이 없다. ⚠️ **이번 범위에 넣지 않는다**(§9-주의) |
| **2** | 덮어쓰기로 사라지는 값 | **매장 하드 삭제가 문서 전체를 지운다.** D1 이 닫는다. `brandKey` 는 `brand_repository_impl.dart:110` 이 보존하지만 admin 재발급 시 **이전 키가 사라진다** → `keyHistory` 가 받는다 |
| **3** | 거래/기록 문서가 정책 값을 참조만 하는가 | 주문은 가격을 박제한다(`orderBuilder.ts`). **단 박제하는 값이 클라이언트 값이다** (§5-6) → Q6 |
| **4** | "누가" 가 기록되는가 | `keyHistory.changedBy` = admin uid, `storeDeletionHistory.deletedBy` = admin uid, `paymentGateRejections.uid` = 고객 uid + `storeId` |
| **5** | 일괄 처리가 있는가 | 백필 2건(§11). **1건으로 묶어** `migrationHistory` 성격의 기록을 남기고 **영향 범위(대상 수)** 를 함께 적는다 |
| **6** | CF 로그에 의존하지 않는가 | ⚠️ **여기가 가장 놓치기 쉽다.** 게이트 거절을 `console.log` 로만 남기면 Cloud Logging 보존 기간 뒤에 사라지고, **오탐 분포를 영구히 못 본다** → 7번 |

### 9-7. `paymentGateRejections/{autoId}` (신규)

```
paymentGateRejections/{autoId}
  uid          고객 uid
  storeId      매장
  reason       STORE_NOT_SELLABLE | STORE_NOT_FOUND | MENU_SOLD_OUT | MENU_EXCLUDED | MENU_NOT_FOUND | READ_FAILED
  detail       { rawStatus, hasApprovedAt, violatedMenuItemIds[], violatedMenuNames[] }
  amount       거절된 결제 금액 (오탐의 크기를 본다)
  createdAt    serverTimestamp
```

- **쓰기 주체는 CF 단독** (Rules: `read: isAdmin()`, `write: false`). 클라이언트가 쓰면 위조·누락된다.
- 이것은 **거래 이력이 아니라 거절 이력**이다. §2 의 구분대로 둘은 다르다.
- 돈이 움직이지 않은 사건이므로 결제 실패 자체를 원장에 남길 필요는 없다.

### 9-주의. 이번에 **남기지 않기로 한 것과 사유**

- **매장 `status` 전이 이력(승인/반려)** — `audit_trail.md` A4 성격의 과제이고 admin 승인 흐름 전반을
  건드린다. 이 묶음은 이미 4건이며 결제 경로를 포함한다. **`backlog.md` 에 등재하고 이번에는 남기지
  않는다.** 사유: 범위. (반려 사유는 `rejectedReason` 에 1개만 남아 덮어쓰기된다는 점도 함께 등재)
- **brandKey 조회 시도 이력** — `lookupBrandByKey` 호출 로그를 Firestore 에 남기지 않는다. 사유:
  볼륨이 크고, 무차별 대입 방어는 §10.3 의 rate limit 로 한다. **Cloud Logging 으로 충분한 유일한 항목**이며
  영구 보존 필요가 없다.

---

## 10. 설계 — B1 `brands` read 축소 / `brandKey` 비공개화

### 10.1 제약 재확인

- 고객은 부모 문서를 **읽지 않는다** → 고객 영향 0.
- 점주는 **남의 브랜드 문서**를 읽어야 한다(매장이 가리키는 브랜드의 이름·status·적립률).
  Rules 는 storeId 없이 그 자격을 증명할 수 없다.
- `BrandScopeBadge` 는 읽기 실패 시 **경고 + 매장 승인 버튼 비활성**이다(의도된 fail-closed).
  좁힌 뒤 admin 경로가 막히면 **매장 승인이 전면 불가**가 된다.

### 10.2 안 비교 → **Q2**

| 안 | 구조 | 닫히는가 | 대가 |
|---|---|---|---|
| **ⓐ** 공개 미러 | 부모를 `isAdmin() \|\| isBrandHolder()` 로 좁히고 `brands/{id}/public/profile` 에 `name·logoUrl·status·qoin*` 를 **CF 트리거로 미러** | 완전히 닫힌다 | **미러 CF + 드리프트 위험 + 백필 + 7개 표면 재배선.** 미러가 늦으면 적립률 해석이 낡은 값을 본다 — **돈과 닿는 파생 데이터를 새로 만든다** |
| **ⓑ** 비공개 서브문서 (추천) | 부모는 `isSignedIn()` 유지. **비밀·PII 만** `brands/{id}/private/profile` 로 옮긴다 (`brandKey`, `businessRegistrationNumber`, `representativeName`, `contactName`, `contactPhone`, `headOfficeAddress`). read: `isAdmin() \|\| isBrandHolder(brandId)`, write: `false`(CF 전담) | **R8·R9 를 닫는다.** 부모에 남는 것은 `name·logoUrl·description·status·qoin*` — 비밀이 아니다 | 마이그레이션 1건(필드 이동). `findByBrandKey` 쿼리가 **불가능해지므로** callable CF 필수. brandKey 발급도 CF 로 이동. 점주·admin 화면 **재배선 0** |
| ⓒ 현행 유지 | — | 아니다 | 가맹 신청의 열쇠가 계속 열쇠가 아니다 |

**설계자 추천: ⓑ.** 보안 목표(열쇠 + PII)를 ⓐ 의 몇 분의 일 비용으로 달성하고,
**점주·admin 화면을 하나도 건드리지 않는다**(= 배포 실패 표면이 작다). `name`/`status`/`qoin*` 의
로그인 사용자 노출은 비밀이 아니므로 수용한다. ⓐ 는 "부모 read 축소" 를 글자 그대로 달성하지만
**돈과 닿는 미러를 새로 만드는 대가**가 이 묶음의 위험 예산을 넘는다.

### 10.3 `brandKey` 조회·발급의 서버 이동

**`brandKeys/{brandKey}` (신규 인덱스 컬렉션)**

```
brandKeys/{BR-XXXXXXXX}
  brandId    브랜드 문서 ID
  issuedAt   serverTimestamp
  issuedBy   admin uid
Rules: read: if false;  write: if false;    ← CF(Admin SDK) 전담
```

- **문서 ID 가 brandKey 이므로 유일성이 구조로 보장된다** (R11). 지금의 `where brandKey==` 쿼리
  유일성은 경쟁 조건에서 깨진다.
- `lookupBrandByKey` CF 가 O(1) 단건 get 으로 조회한다.

**`lookupBrandByKey` (신규 callable, asia-northeast3)**

| 항목 | 설계 |
|---|---|
| 인증 | `isSignedIn` 필수. role 제한은 두지 않는다(점주 전환 전 사용자도 폼을 볼 수 있다) — 단 §rate limit |
| 입력 | `brandKey` (서버에서 `^BR-[A-Z2-9]{8}$` 재검증 — 클라 정규식을 권위로 삼지 않는다) |
| 동작 | `brandKeys/{key}` → `brandId` → `brands/{brandId}` 의 `status == 'approved'` 확인 |
| 반환 | `{ brandId, name, logoUrl }` **만.** PII·brandKey 를 되돌려주지 않는다 |
| 미매칭 | 존재하지 않음과 미승인을 **같은 응답**으로 돌린다 (열거 오라클 방지) |
| rate limit | uid 당 분당 N회 초과 시 `resource-exhausted`. 초과를 Cloud Logging 에 남긴다 |

**brandKey 발급을 CF 로 옮긴다.** 현재는 `brand_repository_impl.dart:134-140` 이 클라이언트에서
생성·검증·쓰기를 한다. 승인 CF 또는 `issueBrandKey` callable 이 ① 키 생성 ②
`brandKeys/{key}` create(ID 충돌 = 유일성) ③ `brands/{id}/private/profile.brandKey` 쓰기 ④
`brands/{id}/keyHistory/{autoId}` 1건을 **한 트랜잭션**에 쓴다.

> **원칙 1 적용**: ②~④ 가 한 트랜잭션이어야 한다. 지금처럼 "쿼리로 비었나 보고 쓴다" 는
> 검사와 실행이 분리된 구조이고, 그것이 S3 와 같은 틈이다.

### 10.4 B1 의 표면 재배선 목록 (전수)

| # | 표면 | 변경 |
|---|---|---|
| 1 | `brand_remote_data_source.dart:98-106` `findByBrandKey` | 쿼리 삭제 → callable 호출로 교체 |
| 2 | `brand_remote_data_source.dart:111-117` `isBrandKeyTaken` | **삭제** (유일성은 `brandKeys` 문서 ID) |
| 3 | `brand_repository_impl.dart:134-140` `_generateUniqueBrandKey` | **삭제** → CF 이동 |
| 4 | `brand_remote_data_source.dart:67` `update` 의 brandKey 쓰기 | **삭제** (CF 전담) |
| 5 | `brand_info_page.dart` `_BrandKeyRow` (`:183-260`) | 출처를 `brands/{id}/private/profile` 로. **읽기 실패를 "미발급" 으로 표시하지 않는다**(U4) — 별도 에러 문구 |
| 6 | `brand_model.dart:84` `brandKey` 폴백 `''` | 부모 문서에서 brandKey 를 읽지 않도록 정리. 폴백이 조용히 "미발급" 을 만들던 경로를 끊는다 |
| 7 | `brand_info_form_page` 의 PII 입력·저장 | 쓰기 대상이 `private/profile` 로 이동. **brand 본인이 자기 PII 를 쓰는 것은 유지**(Rules write 는 `false` 가 아니라 holder 허용 — brandKey 만 CF 전담) |
| 8 | `brand_link_gate_provider.dart:73` `fetchBySubmitter` | 부모 read 를 유지하므로 **무변경** (ⓑ 선택 시) |
| 9 | `BrandScopeBadge` / `store_brand_block` / `qoin_rate_providers` / `my_store_page:336` / `qoin_rate_info_row:616` | ⓑ 선택 시 **무변경** |
| 10 | `firestore.rules:308` 의 `get(brands/...)` | `status` 만 보므로 **무변경** |
| 11 | CF 7개 (`claimSubmittedBrand` 등) | Admin SDK 라 Rules 우회 → **무변경**. 단 `auditBrandLinks:170` 의 `.select("name","submittedBy","status")` 는 부모 필드만 보므로 안전 |
| 12 | `phase1_seed_data.dart:23` `brandKey: 'BR-SEED0001'` | 시드가 `private/profile` + `brandKeys` 를 함께 심어야 한다 |

> **9·10·11 이 "무변경" 인 것이 ⓑ 를 고르는 이유다.** ⓐ 를 고르면 9 가 전부 재배선 대상이 된다.

---

## 11. 설계 — D1 `stores.delete`

### 11.1 안 비교 → **Q3**

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ** 구멍만 닫기 | Rules `delete: if isAdmin()`. 점주 UI 는 삭제 버튼 제거 + 안내 | 가장 쌈. **하드 삭제가 Console 전용이 되어 이력이 영영 남지 않는다**(§4-2 위반을 수용) |
| **ⓑ** + admin 전담 CF (추천) | ⓐ + `deleteStore` callable(admin): ① `storeDeletionHistory` 1건 ② 서브컬렉션 재귀 삭제 ③ Storage 이미지 삭제 ④ 매장 문서 삭제 를 **순서대로** | CF 1개 + admin UI 1개(작음). **이력이 남는 경로가 존재**하고 Console 사용을 권장하지 않을 근거가 생긴다 |
| ⓒ 소프트 삭제 | `status:'deleted'`(또는 `closed`) 전이 도입 | **`entity_lifecycle.md` 의 store 전이도가 바뀌고 주문·메뉴·목록·검색 전반이 영향**을 받는다. G1 판정식도 바뀐다. 이 묶음에 넣으면 범위가 2배 |

**설계자 추천: ⓑ.** ⓐ 는 "조용히 사라지는 운영 데이터" 를 점주에서 admin 으로 옮기기만 한다.
ⓑ 는 **이력이 남는 경로를 하나 만들어** §4-2·4-4 를 실제로 통과시킨다. ⓒ 는 올바르지만 별도 task.

### 11.2 ⓑ 선택 시 설계

```
deleteStore (callable, admin only)
  입력: { storeId, reason, dryRun }
  ① storeDeletionHistory/{deletionId}  ← 먼저 쓴다 (phase:'started')
       storeId, storeName, ownerId, brandId, status, deletedBy, deletedAt, reason,
       snapshot(매장 문서 전체), phase, affected{ menuItems, menuOverrides, subCategories,
                                              optionGroups, qoinRateHistory, images }
  ② stores/{storeId} 삭제          ← 쓰기를 먼저 봉쇄한다 (§11.5)
  ③ 서브컬렉션 재귀 삭제 (batch 500 단위)
  ④ Storage 이미지 삭제
  ⑤ 이력 phase:'done' + 실제 affected 확정
Rules: storeDeletionHistory read: isAdmin(), write: false
```

- **①을 가장 먼저 쓰는 이유**: 중간에 실패해도 "지우려 했다 + 당시 스냅샷" 이 남는다. 현재 점주 경로는
  **이미지를 먼저 지우고 문서를 나중에 지워서** 실패 시 복구 불가 상태를 만든다 (§5-7).
- **②(매장 문서)를 서브컬렉션보다 먼저 지우는 이유 — spec 초판을 뒤집는다.** 점주의 하위 문서 쓰기는
  Rules 가 `isStoreOwner(storeId)`(= `get(store).ownerId`)로 판정하므로, **매장 문서가 사라지면
  점주의 모든 하위 쓰기가 즉시 거부된다.** 하위를 먼저 지우면 지우는 동안 점주가 메뉴를 추가해
  **새 고아가 생기는 창**이 열린다. 초판 순서(문서 삭제 마지막)는 "중간 실패 시 재진입점이
  사라진다" 를 걱정한 것이지만, **재진입점은 매장 문서가 아니라 ① 의 이력 문서**다 (§11.5).
  따라서 순서를 바꾸는 쪽이 모든 면에서 낫다.
- 점주 UI (`my_store_page.dart` `_DangerZone` 호출 **2곳** `:317`·`:391`): 삭제 버튼을 제거하고
  **안내 문구 한 줄**로 바꾼다(design §6.2, Q3 ⓐ 확정). **버튼·링크는 두지 않는다** — 앱에 문의 채널이
  없어서 눌러도 아무 일도 안 일어나는 버튼이 되고, 연락처 하드코딩은 절대 규칙 4 위반 위험이다.
  ⚠️ **안내 문구에 `temporaryClosed`(임시 휴업)를 권하지 않는다 — 그 토글은 아무 효과가 없다**(§6.9).
  `_confirmDelete` 의 Storage 삭제 코드(`:1000-1007`)도 함께 제거한다(이미지 정리는 CF 가 한다).
  폐업 신청 전용 흐름은 **N4**.
  **버튼을 남기고 Rules 만 닫으면 "삭제에 실패했어요" 가 되므로 반드시 UI 를 함께 바꾼다**(U3).
- 점주 삭제가 닫히면 **"적립 중단된 매장의 점주가 삭제·재생성으로 중단 상태를 지우고 미승인 상태에서
  결제를 태워 적립을 재개" 경로가 양쪽에서 막힌다** — G1(`approvedAt` 없음 → 거절)과 D1(삭제 불가).
- ⚠️ **점주 공백을 수용한다** (design Q3 ⓐ 확정): 폐업·중복 등록·**브랜드 반려 후 정리**
  (`_BrandRejectedBanner` — 재제출은 본사만 가능)를 점주가 스스로 할 길이 없어지고,
  **앱에 문의 채널 자체가 없다.** 이번 범위에서는 안내 문구만 두고 **공백은 N4(폐업 신청 흐름)로
  미룬다.** design §6.2 의 문구가 그 최선이다.

### 11.3 영향 범위 숫자의 출처 — `dryRun` **확정** (design 전달 사항 2)

design §7.2 의 삭제 확인 화면은 **삭제 전에** 영향 범위 숫자가 필요하다. 확정:

```
deleteStore({ storeId, reason?, dryRun: true })
  → 쓰기 0건. { affected{...}, blockedBy{...} } 만 반환한다.
  → reason 은 dryRun 일 때 선택(미검증).
```

| 결정 | 근거 |
|---|---|
| **클라이언트 `count()` 쿼리를 쓰지 않는다** | 화면이 보여준 숫자와 삭제가 실제로 센 숫자가 **다른 코드로 계산되면 한 사실에 두 판정**이 된다 (원칙 3). 서브컬렉션 6종에 대한 admin read 권한 분기도 새로 필요해진다 |
| **같은 CF 의 같은 카운트 함수를 `dryRun` 과 실행이 공유한다** | 숫자가 갈라질 길이 없다 |
| **dryRun 숫자는 스냅샷이 아니다** | 세고 나서 실제 삭제까지 사이에 값이 변할 수 있다. 화면 숫자는 "확인 시점의 값" 이고 **이력에 기록되는 `affected` 는 실행 시점 값**이다 (⑤ 에서 확정). 둘이 달라도 버그가 아니다 — developer 는 **화면 숫자를 이력에 쓰지 않는다** |
| **dryRun 은 이력을 남기지 않는다** | 쓰기 0건이고 파괴적 동작이 아니다. §9-주의 와 같은 판단(볼륨 대비 가치) |
| **dryRun 실패 시 삭제 버튼 비활성** (design 4-4) | 파괴적 동작은 **fail-closed.** 결제 선검증과 반대 방향인 것이 맞다 — design §7.2 가 그 대비를 정확히 적었다 |

### 11.4 진행 중인 주문이 있는 매장의 삭제 — **가드를 둔다** (design 전달 사항 3)

design 은 이 행을 넣지 않았다. **넣어야 한다. 근거가 UX 가 아니라 돈이다.**

- `cancelTossPayment.ts:85` 와 `processRefund.ts:80` 이 **`stores/{storeId}` 를 읽어 점주 자격을
  확인**한다. 매장 문서가 없으면 `!storeSnap.exists` → `permission-denied`.
- 즉 **매장을 지우면 그 매장의 진행 중 주문을 점주가 취소할 수도, 환불을 승인할 수도 없게 된다.
  돈이 묶인다.** (고객의 `paid` 단계 직접 취소는 `stores` 를 읽지 않아 살아남는다 — 부분적 생존이
  오히려 더 헷갈리는 상태다.)

**"진행 중" 의 정의**

| status | 판정 | 근거 |
|---|---|---|
| `paid` · `accepted` · `making` · `ready` | **진행 중 → 삭제 차단** | 아직 돈·물건이 움직일 수 있다. 취소·환불 경로가 `stores` 를 필요로 한다 |
| `completed` · `cancelled` · `refunded` | 종결 → 차단하지 않음 | 더 이상 `stores` 를 읽는 전이가 없다 |

- 별도의 "환불 요청 중" 절은 **필요 없다.** 환불 요청은 `status` 를 `accepted` 로 유지한 채
  `refundRequest` 만 채우므로(`firestore.rules:229` O2) 위 4개에 이미 포함된다.
- 쿼리: `orders where storeId == {id} and status in ['paid','accepted','making','ready'] limit 1`
  (건수 표시용으로는 `count()`). **복합 인덱스 필요 여부를 developer 가 확인**하고 필요하면
  `firestore.indexes.json` 에 추가한다 → 배포 ① 단계가 비어 있지 않을 수 있다.
- CF 는 `dryRun` 과 실행 **양쪽에서** 이 쿼리를 돌리고, **실행 경로에서는 ① 이력 쓰기보다 먼저**
  검사해 차단한다(차단은 삭제 시도가 아니므로 이력을 남기지 않는다).
- 반환: `blockedBy: { inFlightOrders: n }` → `failed-precondition` + 토큰 `[STORE_HAS_INFLIGHT_ORDERS]`.

**design 에 넘길 화면 요구** (designer 재호출 시 §7.2 에 추가):

| 요소 | 내용 |
|---|---|
| 영향 범위 섹션에 행 추가 | `진행 중인 주문` **n건** — 0 이면 다른 행과 같이 `0` 을 표시한다(숨기지 않는다) |
| n ≥ 1 일 때 | **삭제 버튼 비활성** + 그 자리에 사유: `진행 중인 주문이 n건 있어요. 모두 완료·취소된 뒤에 삭제할 수 있어요.` 그리고 **왜**를 한 줄: `지금 삭제하면 그 주문의 취소·환불을 처리할 수 없게 돼요.` |
| 복구 동작 | `다시 불러오기`(카운트 갱신). admin 이 주문을 강제 종결시키는 수단은 이번에 만들지 않는다 |
| 경쟁 상황 | 화면은 0건이었는데 실행 시 1건이 되어 CF 가 거부할 수 있다 → §7.2 "삭제 실패" 박스의 변형으로 `방금 새 주문이 들어왔어요. 다시 확인해 주세요.` |

### 11.5 `deleteStore` 재실행 멱등 — 보장 범위 **확정** (design 전달 사항 4)

design §7.2 의 실패 문구 "**같은 매장을 다시 삭제하면 이어서 진행돼요. 삭제 이력은 중복 기록되지
않아요**" 는 성립한다. 아래가 그 성립 조건이다.

```
deletionId = `${storeId}_${storeCreatedAtMillis}`      // createdAt 부재(legacy) → `${storeId}_0`
storeDeletionHistory/{deletionId}   phase: 'started' | 'docDeleted' | 'subDeleted' | 'storageDeleted' | 'done'
```

- **이력 문서가 재진입점이다** (매장 문서가 아니다 — ② 에서 이미 사라진다). 재실행은
  `storeDeletionHistory/{deletionId}` 를 읽어 `phase` 이후 단계만 수행한다. 쓰기는 `set(merge)` 라
  **같은 삭제 시도에 대해 이력 문서는 1건**이다.
- **`deletionId` 에 `createdAt` 을 넣는 이유**: 같은 ID 로 매장이 재생성된 뒤 다시 삭제되면
  `createdAt` 이 달라 **별도 이력**이 남는다. `storeId` 만 쓰면 두 번째 삭제가 첫 번째 이력을
  덮어써 **과거 삭제 기록이 사라진다** (§9-2 가 막으려던 바로 그 일).

| 멱등을 **보장**하는 것 | 보장하지 **않는** 것 |
|---|---|
| 이력 1건 (중복 기록 없음) | **dryRun 숫자와 실행 `affected` 의 일치** (§11.3) |
| 서브컬렉션·Storage 삭제 (이미 없으면 skip — 본질적으로 멱등) | **삭제 도중 admin/CF 가 새로 만든 하위 문서** — 점주 쓰기는 ② 로 봉쇄되지만 Admin SDK 는 봉쇄되지 않는다. 재실행이 그것을 치운다 |
| 매장 문서 삭제 (이미 없으면 skip) | **Storage 삭제의 부분 실패 복구 순서** — 재실행이 남은 것부터 지운다. 그래서 `phase:'storageDeleted'` 를 별도 단계로 둔다 |
| `phase == 'done'` + 매장 문서 없음 → **`이미 삭제된 매장이에요`** 반환 (design §7.2 마지막 행) | — |

- **중단 가능 단계는 ②~④ 다.** ① 이 실패하면 아무것도 지워지지 않는다(이력 없이 삭제가 시작되는
  경로가 없다 — §4-2 요구).
- developer 가 이 구조를 구현하지 못하면 **design §7.2 의 실패 문구를 바꿔야 한다.** 그 경우
  구현 전에 보고한다.

---

## 12. 표면 인벤토리 (§21.7 R2 — ⓑ 가 빈 칸이면 미설계)

> **design §2 가 이 표를 이전·확장했다 (행 번호 부여 + `신규`/`변경`/`기존` 구분 + 누락 행 2개 추가
> — `frequent_menu_items_section`(2-11), `store_menu_page` 하단 카트 바(2-12)).
> 구현·검증의 기준은 design §2 다.** 아래는 설계 시점 원본으로 남긴다. 새 표면을 만들면
> **design §2 에 행을 추가**한다(여기가 아니다).

### 사실 1 — "지금 이 매장이 주문을 받을 수 있는가" (`canSellNow`)

| 표면 | ⓐ 판정 출처 | ⓑ 출처 읽기 실패 시 보이는 것 | ⓒ 복구 동작 |
|---|---|---|---|
| `verifyTossPayment` 게이트 (권위) | `storeSellability.ts canSellNow(rawStatus, hasApprovedAt)` — `stores/{id}` 직접 read | **거절** + `reason: READ_FAILED` + `paymentGateRejections` 1건 | 없음(거절). 고객에게 "잠시 후 다시 시도" |
| **결제 실패 화면 문구** (`payment_result_page.dart` `_FailBody`) | CF 가 message 끝에 실은 `[reason]` 토큰 → `_mapErrorCode` | 토큰 파싱 실패 → **일반 실패 문구**(현행 `e.toString()` 노출을 없앤다) | `카트로 돌아가기` |
| 체크아웃 선검증 (`checkout_page.dart`) | `store_sellability.dart canSellNow` (같은 규칙) | **결제를 막지 않는다**(§8.2). 배너 없이 그대로 진행 | — |
| 고객 매장 목록 | 기존 `status == approved` 필터 (`store_repository_impl.dart:224`) | 목록 에러 → 기존 에러 UI | 재시도 |
| 점주 `my_store_page` 승인 상태 표시 | 기존 `StoreEntity.status` | 기존 에러 UI | 재시도 |
| admin 승인 큐 | 기존 | 기존 | — |

> 목록 필터링은 **노출 판정**이고 게이트가 아니다. `canSellNow` 로 통합하지 않는다 —
> 둘은 다른 질문이다("보여줄까" vs "돈을 받을까"). **가드 테스트의 허용 목록에 이 구분을 명시**한다.

### 사실 2 — "이 메뉴를 지금 팔 수 있는가" (`applyOverrideForCustomer`)

| 표면 | ⓐ 판정 출처 | ⓑ 출처 읽기 실패 시 보이는 것 | ⓒ 복구 동작 |
|---|---|---|---|
| `verifyTossPayment` 게이트 (권위) | `functions/src/menuVisibility.ts` (Dart 와 교차 골든) | **거절** + `READ_FAILED` + 기록 1건 | 없음(거절) |
| **결제 실패 화면 문구** | `[MENU_SOLD_OUT]` + 위반 메뉴명 목록 | 메뉴명 전달 실패 → **"품절된 메뉴가 있어요"**(이름 없이) | `카트로 돌아가기` |
| 체크아웃 선검증 | Dart `applyOverrideForCustomer` | **막지 않는다**(§8.2) | — |
| 카트 화면 품절 표시 (`cart_page.dart`) | 같은 Dart 함수 | 표시 생략(카트는 로컬이라 항상 그려진다) | 해당 품목 삭제 버튼(기존) |
| 메뉴 상세 `담기` 가드 | `menu_item_detail_page.dart:646` (기존) | 기존 `_DeletedView` | `매장 메뉴 보기` |
| 매장 화면 카드 | `menu_item_card.dart` (기존) | 기존 | — |
| 검색 결과 행 | `menu_search_result_tile.dart` (기존) | 기존 | — |
| **빠른 재주문** (`quick_reorder_section.dart:226-245`) | **없다 — 과거 주문 items 를 품절·존재 확인 없이 재투입하고 단가를 역산한다** | 확인 자체를 안 하므로 실패 표면이 없다 | **없다** → **이번에 품절 확인을 넣는다**(G2 의 최빈 발생 경로) |
| 점주 품절 토글 | `sold_out_toggle.dart` (쓰기) | 기존 | 재시도 |

### 사실 3 — "이 브랜드의 brandKey"

| 표면 | ⓐ 판정 출처 | ⓑ 출처 읽기 실패 시 보이는 것 | ⓒ 복구 동작 |
|---|---|---|---|
| `brand_info_page` `_BrandKeyRow` | `brands/{id}/private/profile.brandKey` | **"브랜드 키를 불러오지 못했어요 · 다시 시도"** — **"승인 후 발급" 문구로 떨어지지 않는다**(U4) | `다시 시도` |
| 점주 매장 등록 폼 brandKey 조회 | `lookupBrandByKey` CF | 네트워크 실패 → "확인하지 못했어요 · 다시 시도". **미매칭과 구분한다** | `다시 시도` |
| brandKey 발급 (admin 승인) | `issueBrandKey` CF (트랜잭션) | 발급 실패 → 승인 자체를 롤백하고 admin 에게 사유 표시 | 승인 재시도 |
| `brandKeys/{key}` | CF 전담 | 클라이언트는 읽지 않는다 | — |

### 사실 4 — "이 매장을 삭제할 수 있는가"

| 표면 | ⓐ 판정 출처 | ⓑ 출처 읽기 실패 시 보이는 것 | ⓒ 복구 동작 |
|---|---|---|---|
| 점주 `my_store_page` | **삭제 버튼 없음** (정적) | — | 안내: 폐업은 admin 문의 |
| admin 삭제 화면 (Q3 ⓑ) | `deleteStore` CF | 실패 사유 표시 + 부분 진행 상태 | 재시도(멱등: history 중복 방지 키) |
| Rules | `isAdmin()` | — | — |

---

## 13. 레이어 설계

### Domain (순수 Dart)

- `lib/core/utils/store_sellability.dart` — `canSellNow({String? rawStatus, bool hasApprovedAt})` **신규**
- `lib/core/utils/store_menu_visibility.dart` — **무변경** (단일 판정 유지)
- UseCase: `LookupBrandByKeyUseCase` — 시그니처 유지, Repository 구현만 교체
- UseCase: `DeleteStoreUseCase` — **삭제** (Q3 ⓑ 면 admin 용 `AdminDeleteStoreUseCase` 로 교체)
- UseCase: `ValidateCheckoutUseCase` **신규** (Q4 ⓐ) — 매장 + 카트 품목을 받아 위반 목록 반환.
  **판정은 `canSellNow` + `applyOverrideForCustomer` 를 호출만 한다** (자체 판정 금지)
- Entity: `CartEntity` / `CartItemEntity` **무변경** (클라 선언값을 늘리지 않는다)

### Data

- `store_remote_data_source.deleteStore` **삭제** (또는 callable 호출로 교체)
- `brand_remote_data_source`: `findByBrandKey` → callable, `isBrandKeyTaken` 삭제,
  `update` 의 brandKey 쓰기 삭제, `fetchPrivateProfile`/`watchPrivateProfile` 신규
- `BrandModel` — 비공개 필드를 `BrandPrivateProfileModel` 로 분리. `brandKey` 기본값 `''` 폴백 정리
- `functions_remote_data_source` — `lookupBrandByKey` / `deleteStore` 추가

### Presentation

- `checkout_page.dart` — 선검증 호출(Q4 ⓐ) + 거절 사유 전달
- `payment_result_page.dart` — `_mapErrorCode` 에 게이트 사유 추가. **`e.toString()` 노출 제거**
- `cart_page.dart` — 품절 표시 + 체크아웃 진입 차단
- `quick_reorder_section.dart` — 재투입 전 품절·존재 확인
- `my_store_page.dart` — 삭제 버튼 → 안내
- `brand_info_page.dart` — brandKey 출처 변경 + 실패 문구 분리
- `store_core_form_page.dart` — brandKey 조회가 callable 경유

### Cloud Functions

| 파일 | 변경 |
|---|---|
| `verifyTossPayment.ts` | `:116`~`:118` 사이에 G1·G2 게이트 + 거절 기록 + `[reason]` 토큰 |
| `storeSellability.ts` | **신규** — `canSellNow` |
| `menuVisibility.ts` | **신규** — `applyOverrideForCustomer` TS 포팅 |
| `lookupBrandByKey.ts` | **신규** callable |
| `issueBrandKey.ts` (또는 승인 CF 확장) | **신규** — 키 생성 + `brandKeys` + `keyHistory` 트랜잭션 |
| `deleteStore.ts` | **신규** callable (Q3 ⓑ) |
| `index.ts` | export 추가 |

### 레이어 규칙 주의 (developer 에게)

- `canSellNow` / `applyOverrideForCustomer` 는 **순수 Dart**다. `cloud_firestore` 를 import 하지 않는다.
- 선검증은 presentation 이 **UseCase 경유**로 호출한다. Page 가 Firestore 를 직접 읽지 않는다.
- CF 는 Admin SDK 라 Rules 를 우회한다. **게이트는 Rules 가 아니라 CF 코드가 집행한다.**

---

## 14. 데이터 흐름

### 결제 (G1·G2 적용 후)

```
CheckoutPage
  → ValidateCheckoutUseCase            (Q4 ⓐ: 선검증, 권위 아님)
      → StoreRepository / MenuItemRepository
      → canSellNow + applyOverrideForCustomer   ← Dart 판정 1개
  → (위반 있으면 결제창 띄우지 않고 중단)
  → LaunchPaymentUseCase → Toss 결제창
  → VerifyAndCreateOrderUseCase
      → verifyTossPayment (CF)
           멱등 가드
           ─── 게이트 ───────────────────────────────
           stores/{storeId} read  → canSellNow          ← TS 판정 1개(골든으로 Dart 와 고정)
           getAll(menuItems / menuOverrides / 마스터)  → applyOverrideForCustomer
           위반 → paymentGateRejections 1건 + failed-precondition "[REASON]"  (confirm 안 함)
           ────────────────────────────────────────
           Toss confirm          ← 돈이 움직인다
           응답 검증 (현행)
           batch: orders + orderLogs (현행)
  → PaymentResultPage(success | fail(reason 매핑))
```

### brandKey 조회

```
StoreCoreFormPage → LookupBrandByKeyUseCase → BrandRepositoryImpl
  → FunctionsDataSource.lookupBrandByKey   (callable)
      → brandKeys/{key} → brandId → brands/{brandId}.status=='approved'
      → { brandId, name, logoUrl }
```

---

## 15. 에러 처리 / 문구

> **아래 문구표는 사유 ↔ 코드 ↔ 의미의 계약이다. 화면에 실제로 나가는 문장·구조는
> `design.md` §3.1~§3.5(헤드라인 + 본문 + 돈 줄 + 목록 카드)가 상위다.** design 이 바꾼 지점과
> 이유는 design §3.1 의 "spec §15 문구와 달라진 점" 표에 있고, 설계자는 그 변경을 **수용**한다
> (한 문장에 메뉴명을 이어 붙이면 여러 건일 때 읽을 수 없다는 근거가 타당하다).
>
> ⚠️ **문구 표기 규칙 (F-04) — spec·design 의 문구에 마크다운 백틱을 쓰지 않는다.**
> `` `다시 확인` `` 처럼 적으면 **구현이 백틱을 문자열에 그대로 복사해 화면에 ` 문자가 출력된다**
> (실제로 `cart_availability_banner.dart:28,30,32` 에서 발생했다). 문구 안에서 버튼·화면 이름을
> 가리킬 때는 **작은따옴표('다시 확인')** 또는 꾸밈 없는 평문을 쓴다. 이것은 문서 서식 취향이
> 아니라 **구현 사고를 막는 규칙**이다 — 문구 칸의 내용은 복사되어 코드가 된다.

CF 는 `HttpsError` 의 `code` + **message 끝에 `[REASON]` 토큰**을 함께 싣는다
(실기기에서 `details` 가 Map 으로 안 올 수 있다는 기존 교훈 — `backlog.md:566-569`). 이중 장치다.

| reason | HttpsError code | 고객 문구 | 비고 |
|---|---|---|---|
| `STORE_NOT_SELLABLE` | `failed-precondition` | **"지금은 이 매장이 주문을 받을 수 없어요. 잠시 후 다시 시도해주세요"** | 미승인/반려를 구분해 말하지 않는다(매장 심사 상태를 고객에게 노출하지 않는다) |
| `STORE_NOT_FOUND` | `not-found` | **"매장 정보를 찾을 수 없어요. 카트를 비우고 다시 담아주세요"** | |
| `MENU_SOLD_OUT` | `failed-precondition` | **"품절된 메뉴가 있어요 — {메뉴명}. 카트에서 빼고 다시 시도해주세요"** | **이름을 반드시 지목한다** (오탐 시 고객이 스스로 복구할 유일한 수단) |
| `MENU_EXCLUDED` | `failed-precondition` | **"이 매장에서 더 이상 판매하지 않는 메뉴가 있어요 — {메뉴명}"** | |
| `MENU_NOT_FOUND` | `not-found` | **"메뉴 정보가 변경됐어요. 카트를 비우고 다시 담아주세요"** | |
| `READ_FAILED` | `unavailable` | **"일시적인 오류예요. 잠시 후 다시 시도해주세요"** | 전 매장 영향 가능 → 기록으로 즉시 탐지 |
| `STORE_HAS_INFLIGHT_ORDERS` | `failed-precondition` | **admin 전용** — 고객 경로가 아니다. design §7.2 의 비활성 사유 문구(§11.4) | 신규. `deleteStore` 전용 사유이며 결제 6종과 **다른 목록**이다 — 결제 화면의 "알려진 6개" 에 넣지 않는다 |
| (입력 품목 초과) | `invalid-argument` | 토큰 없음 → **갈래 C** | `cart.items.length > 50` (§15.1). 정상 고객 도달 불가 |
| (brandKey 미매칭) | `not-found` | **"브랜드를 찾을 수 없어요. 키를 다시 확인해주세요"** | 미존재/미승인 동일 문구 |
| (brandKey rate limit) | `resource-exhausted` | **"조회를 너무 많이 시도했어요. 잠시 후 다시 시도해주세요"** | |
| (매장 삭제 시도) | `permission-denied` | **점주 UI 에서 버튼 자체를 없앤다** | Rules 만 닫고 버튼을 남기면 "삭제에 실패했어요" 가 된다 |

**`payment_result_page.dart:71` 의 `_mapErrorCode(errorCode, errorMessage)` 가 현재 `message`
기본 폴백으로 `e.toString()` 을 노출한다.** 게이트 사유 매핑을 추가하면서 **원시 예외 문자열 노출을
제거**한다 (R6).

### 15.1 거절 토큰 형식 — **확정** (design 전달 사항 1)

design §3.5 는 품절 거절 시 **어느 메뉴인지 반드시 지목**한다(오탐일 때 고객의 유일한 복구 수단).
spec 초판은 `[REASON]` 만 적어 **id 가 없어 그 요구사항이 성립하지 않았다.** 아래로 확정한다.

```
HttpsError.message 의 맨 끝에 토큰 1개를 붙인다.

  메뉴 사유 3종 :  [MENU_SOLD_OUT:id1,id2]   [MENU_EXCLUDED:id1]   [MENU_NOT_FOUND:id1,id2,id3]
  그 외 3종     :  [STORE_NOT_SELLABLE]      [STORE_NOT_FOUND]     [READ_FAILED]

문법:  \[(?<reason>[A-Z][A-Z0-9_]{2,39})(?::(?<ids>[A-Za-z0-9_,-]{1,2048}))?\]$
id   :  ^[A-Za-z0-9_-]{1,64}$  (Firestore 문서 ID — `,` `:` `[` `]` 가 들어가지 않는다)
```

| 결정 | 내용 | 근거 |
|---|---|---|
| **서버는 `menuItemId` 만 싣는다. 이름을 싣지 않는다** | 이름은 **고객 카트의 `menuItemName`** 으로 그린다 (design D5) | ⓐ 고객이 카트에서 보던 이름과 같아야 알아본다 ⓑ 한글·쉼표 인코딩 문제가 없다 ⓒ `details` 가 실기기에서 Map 으로 안 오는 기존 문제(`backlog.md:566-569`)에 토큰만으로 버틴다 |
| **D4("서버 문자열을 화면에 보간하지 않는다")와 일관된다** | id 는 **조회 키로만** 쓰이고 **화면에 출력되지 않는다.** 해석에 성공하면 카트의 이름이 그려지고, 실패하면 그 id 는 **건너뛴다 — 미해석 id 를 화면에 그리지 않는다** | 화면에 나가는 문자열은 여전히 ⓐ 코드 안의 상수 ⓑ 고객 카트의 값 둘뿐이다. 서버가 보낸 바이트가 화면에 도달하는 경로가 없다 |
| **형식 검증을 통과하지 못한 토큰 조각은 버린다** | `reason` 이 알려진 6개가 아니면 **갈래 C**, `ids` 중 id 정규식에 안 맞는 조각은 **그 조각만 폐기** | 서버가 예상 밖 문자열을 실어도 화면에 새지 않는다 |
| **중복 제거는 클라이언트가 한다** | 같은 `menuItemId` 가 옵션이 달라 카트에 여러 줄이면 이름을 한 번만 (design D5) | 서버는 **메뉴 종류 단위**로 id 를 보낸다(라인 단위가 아니다) |

**id 가 카트에서 해석되지 않을 때 화면이 그리는 것** (design §3.6 empty 행과 일치):

| 경우 | 화면 |
|---|---|
| 일부 해석 실패 | 해석된 이름만 목록에 그린다. **부족하다는 표시를 하지 않는다** — 고객이 할 일(그 메뉴를 뺀다)은 달라지지 않는다 |
| **전부 해석 실패** | 목록 카드를 **그리지 않고** 이름 없는 문구("품절된 메뉴가 있어요. 카트에서 확인해 주세요.")로 내려간다. 버튼은 동일 | 
| 카트가 비어 있다(앱 재시작 등) | 위와 같다. 카트는 로컬·비영속이다 (§5-1) |

**품목 수 상한 — 토큰을 절단하지 않고 입력을 제한한다**

design D5 는 "N개 + 더보기로 줄이지 않고 **전부 열거**" 다. 토큰을 절단하면 그 요구가 깨진다.
그래서 **토큰에 상한을 두지 않고 `cart.items` 길이에 상한을 둔다.**

- **CF 입력 검증에 `cart.items.length <= 50` 을 추가한다.** 초과 시 `invalid-argument`
  (토큰 없음 → 갈래 C). 메뉴 **종류** 수는 이보다 적으므로 토큰은 최대 50개 id ≈ 1,050자 —
  위 `ids` 상한 2048 안에 들어온다. **절단이 구조적으로 발생하지 않는다.**
- 이 상한은 **별도의 이득**도 있다: G2 는 품목당 최대 3문서를 읽으므로(§7.2) 상한이 없으면
  **품목 수 × 3 만큼 읽기가 늘어난다.** 1,000품목 카트 1건이 3,000 reads 다.
  상한은 **G2 가 새로 만드는 비용의 뚜껑**이기도 하다.
- 50 은 카트 UI 의 현실 상한을 크게 넘는 값이라 정상 고객에게 **도달 불가**다(오탐 0).

---

## 16. 마이그레이션

| # | 대상 | 내용 | 필수 여부 |
|---|---|---|---|
| **M1** | `stores` (전건, 현재 7곳) | ⓐ `status` 가 **부재한** 문서에 명시적으로 `status` 를 쓴다 ⓑ `status=='approved'` 인데 **`approvedAt` 이 없는** 문서에 `approvedAt` 를 백필한다 **ⓓ `willBeRejected` 목록 (F-01 신규) — 백필을 가정한 뒤에도 `canSellNow` 가 false 인 매장**을 `{id, name, status, hasApprovedAt}` 로 보고한다. 운영자가 ⑥ 전에 "이 매장들은 막힌다" 를 눈으로 확인하는 유일한 수단이다 (dry-run 리포트가 이것을 안 보여 주면 **M1 을 돌려도 어느 매장이 막힐지 모른다**) **ⓔ 모호 건 감사 (F-02/§6.8 신규)** — `status=='rejected' && approvedAt != null` **전건**(승인 후 반려와 반려만을 구분할 수 없다) + `status=='pending' && rejectedReason != null && approvedAt != null`(self-regress 흔적 — `approvedBy` 가 admin 값으로 남아 기존 ⓒ 기준이 못 잡는다). **자동으로 고치지 않고 멈추고 보고한다.** ⓔ 가 0건이 아니어도 **배포를 막지 않는다** — 근거는 §6.8 마지막 블록(§6.5 전이 제약이 포함된다는 전제) ⓒ **승인 메타 이상치 감사** — `status != 'approved' && approvedAt != null && approvedBy == null` 인 문서를 **목록으로 보고한다.** admin 승인(`approveFields:325-329`)은 `approvedAt` 과 `approvedBy` 를 **항상 함께** 쓰므로, `approvedAt` 만 있고 `approvedBy` 가 없으면 §5-4 🔴 의 create 경로로 심긴 값일 가능성이 있다. **자동 삭제하지 않는다 — 멈추고 보고한다** (정상 경로로도 생길 수 있는지 사람이 판단한다) | **Q1 ⓑ′ 의 필수 선행.** 안 하면 legacy 매장이 전부 결제 거부된다 (§8.1 1·2행) — **G1 의 유일한 오탐 대량 발생 경로** |
| **M2** | `brands` (전건) | PII+brandKey 를 `brands/{id}/private/profile` 로 이동(복사 후 부모에서 제거), `brandKeys/{key}` 생성 | **Q2 ⓑ 선택 시 필수** |
| M3 | `lib/dev/seed/phase1_seed_data.dart:23` | 시드가 `private/profile` + `brandKeys` 를 함께 심게 수정 | 개발 환경용 |

- M1·M2 는 **dry-run 을 먼저 제공**한다 (기존 `migrateQoinZeroRates` 패턴). 대상 건수와 "무효 값
  목록" 을 보여주고, 비어 있지 않으면 **멈추고 보고**한다 (자동 변환하지 않는다).
- M1·M2 는 각각 **기록 1건**을 남긴다 (§9-5: 일괄 처리는 1건으로 묶고 영향 범위를 함께).
- 두 마이그레이션은 **임시 자산**이다. 완료 후 수일 뒤 정리 커밋으로 삭제한다(런북 ⑧ 패턴).

---

## 17. 배포 순서

> **실행 절차와 전체 명령은 `docs/tasks/payment_server_authority/deploy_runbook.md` 에 있다.**
> 이 절은 **왜 그 순서인가**를 적고, 런북은 **무엇을 어떻게 치는가**를 적는다.

### 17.0 게이트 모드 스위치 `PAYMENT_GATE_MODE` — **확정** (F-01)

게이트는 **되돌릴 수 없는 방향의 실패**(정상 결제 거부)를 만들 수 있고, 그 안전이 지금까지
**배포 순서에만** 달려 있었다. 순서를 어기는 것을 코드가 막지도 감지하지도 못한다
(② 와 ⑥ 이 같은 `index.ts`·같은 배포 명령이라 `npm run deploy` 한 번으로 게이트가 켜진다).
그래서 **순서 전제를 코드 밖에서 코드 안으로 옮긴다.**

```
functions param   PAYMENT_GATE_MODE  =  off | shadow | enforce
```

| 값 | 동작 |
|---|---|
| `off` | 게이트를 **평가하지 않는다.** `stores`·메뉴 읽기도 하지 않는다(비용 0). 현재와 완전히 동일 |
| `shadow` | **판정하고 `paymentGateRejections` 에 기록하되 거절하지 않는다** (`detail.shadow: true`). 결제는 그대로 성립 → **무엇이 막혔을지를 돈을 움직이지 않고 본다** |
| `enforce` | 판정 + 기록 + **거절** (§7 본설계) |

**기본값과 미지값 — `off`** (명시적 결정)

- **값이 없거나 모르는 값이면 `off`.**
- 근거: 게이트는 **돈을 멈추는 장치**다. **설정 오타로 매출이 멈추는 것보다 구멍이 하루 더 열려 있는
  것이 낫다.** Qoin 적립(돈을 **주는** 방향)이 fail-closed 인 것과 **반대이고, 반대인 것이 맞다** —
  fail 방향은 "그 실패가 누구에게서 무엇을 빼앗는가" 로 결정된다.
- ⚠️ 대가: **`enforce` 로 올렸다고 믿는데 오타로 `off` 인 상태를 알아차리기 어렵다.** 그래서 런북
  ⑥-c 에서 **전환 직후 미승인 매장으로 거절 1건을 실제로 유도해 확인**한다. 확인 없이는 전환이
  끝난 것으로 보지 않는다.

**선검증(앱)과의 관계 — 앱은 `enforce` 전환 이후에 배포한다**

선검증은 Dart 쪽이라 **서버 모드와 무관하게 동작**한다. 서버가 `shadow` 인데 앱이 선검증으로
막으면 **거절 판단이 서버의 안전망 없이 클라이언트로 옮겨간다** — shadow 를 둔 이유가 사라진다.
→ **⑥-c(`enforce`) → ⑦(앱)** 순서를 고정한다.

**shadow 가 완화하는 제약 — ④ Rules-A 의 단독 배포 압박**

`shadow` 가 있으면 ⑥ 에서 게이트가 켜져도 거절이 없으므로, **"④ 가 ⑥ 보다 먼저" 의 위험도가
내려간다**(§17.1 의 "위조가 데이터로 굳는다" 는 여전하므로 **순서 자체는 바꾸지 않는다**).
실무적으로는 **④ 를 놓친 채 ⑥ 을 올려도 `shadow` 면 돈이 멈추지 않는다** — 다만 그때
`enforce` 로 넘어가면 안 된다. 런북 ⑥-c 의 전제 조건에 **"④ 라이브 확인 완료"** 를 넣는다.

---

**원칙**: Rules 는 앱보다 **나중**이다 (런북 ③→④) — **단 그 원칙의 근거는 "새 Rules 가 구버전 앱의
쓰기를 거부하면 기능이 전면 실패한다" 다.** 구버전 앱이 애초에 보내지 않는 필드를 막는 Rules 는
그 위험이 없으므로 **먼저 보내는 쪽이 낫다.** 이번 Rules 변경은 그 성질로 **2덩어리로 갈린다.**

| Rules 덩어리 | 내용 | 구버전 앱을 깨뜨리는가 | 자리 |
|---|---|---|---|
| **Rules-A** | `stores` `allow create` 승인 메타 금지 (§6.5) + `brands` create 동일 보강 | **아니다.** 현재 앱의 create payload 2개가 그 키를 보내지 않는다 (§5-4 ✅) | **CF 보다 먼저** |
| **Rules-B+C** | `brands` private 서브문서 · `brandKeys` · `stores.delete` 축소 · 신규 컬렉션 3개 | **그렇다.** 구 앱은 클라이언트에서 brandKey 를 쓰고 삭제 버튼을 들고 있다 | **앱 직후** (런북 ③→④ 그대로) |

**확정 순서**

| 단계 | 내용 | 왜 이 자리인가 |
|---|---|---|
| **①** Firestore 인덱스 | 필요 시 (현재 예상: 없음 — `brandKeys` 는 문서 ID 조회) | 빌드 시간이 있다 |
| **②** 임시 마이그레이션 CF 배포 (`migrateStoreApprovalMeta`, `migrateBrandPrivateProfile`) | 백필 수단만 먼저 올린다 | 게이트 CF 보다 먼저 와야 한다 |
| **③** **M1 실행** (dry-run → 실행) | `stores.status`/`approvedAt` 백필 + **승인 메타 이상치 감사** | **G1 게이트가 켜지기 전에** 데이터를 정상화한다. 뒤집으면 legacy 매장 결제가 전부 멈춘다 |
| **④** **Rules-A 배포** | create 승인 메타 금지 | **⑤(게이트 CF) 보다 먼저.** 뒤집으면 §17.1 의 구멍 구간이 생긴다. 구버전 앱 호환이므로 여기 둘 수 있다 |
| **⑤** **M2 1단계 실행** (dry-run → 실행) | `brands` PII·brandKey 를 `private/profile` 로 **복사** + `brandKeys` 생성 | Rules-B 가 `private/profile` 을 요구하기 전에 문서가 있어야 한다. **부모 필드는 아직 지우지 않는다**(2단 삭제) |
| **⑥** 본 Cloud Functions 배포 — **`PAYMENT_GATE_MODE=shadow`** | `verifyTossPayment` 개정(G1·G2) + `lookupBrandByKey` + `issueBrandKey` + `deleteStore` | 게이트 코드가 올라가지만 **거절하지 않는다.** 데이터(③)와 위조 차단(④)이 선행됐어도 **실측 없이 거절을 켜지 않는다** |
| **⑥-b** shadow 관측 | `paymentGateRejections` 에서 `shadow:true` 기록을 본다. **정상 매장·정상 메뉴가 잡히면 멈추고 원인부터 찾는다** | 오탐을 **돈이 멈추기 전에** 본다. M1 의 `willBeRejected` 와 교차 확인 |
| **⑥-c** `PAYMENT_GATE_MODE=enforce` 전환 | 파라미터만 바꿔 재배포 | 전제: ④ 라이브 확인 완료 + ⑥-b 가 깨끗함. **전환 직후 미승인 매장으로 거절 1건을 실제로 유도해 확인**(§17.0 — 확인 없이는 전환이 끝난 것으로 보지 않는다) |
| **⑦** 앱 빌드·설치 | callable 경유 brandKey, 삭제 버튼 없음, 거절 문구, 선검증 | **⑥-c 이후**(선검증이 서버 안전망 없이 막지 않게) **그리고 Rules-B+C 보다 먼저** |
| **⑧** **Rules-B+C 배포 — ⑦ 직후 바로** | `brands` private, `brandKeys`, `stores.delete`, 신규 컬렉션 3개 | ⑦ 과의 창을 수 분으로 줄인다 (런북 ③→④) |
| **⑨** **M2 2단계** — 부모 문서의 PII·brandKey **제거** | ⑧ 이후, 구버전 앱이 없음을 확인한 뒤 | 먼저 지우면 구버전 앱의 brand 정보 화면이 빈다 |
| **⑩** 라이브 검증 | §17.2 | |
| **⑪** 정리 커밋 (며칠 뒤) | 임시 마이그레이션 CF 2개 삭제 | 런북 ⑧ 패턴 |

### 17.1 과도기 구간의 안전성

| 구간 | 상태 | 안전한가 |
|---|---|---|
| ③~④ | 게이트 없음 + create 위조 가능 | **현재와 동일하다.** 새 구멍이 열리지 않는다 |
| **④~⑥** | create 위조는 막혔고 게이트는 아직 없다 | **안전.** 이 순서가 핵심이다 — **만약 ④ 와 ⑥ 을 뒤집으면 "게이트는 켜졌는데 그 게이트를 통과하는 위조가 열려 있는" 구간**이 생긴다. 그 구간에 만들어진 매장은 ④ 이후에도 **문서에 `approvedAt` 이 남아 계속 통과**하므로, 구멍이 구간으로 끝나지 않고 **데이터로 굳는다.** 그래서 Rules-A 를 선행시킨다 |
| ⑥~⑦ (신 CF, 구 앱) | 구 앱이 결제하면 게이트가 집행된다. 거절 시 구 앱은 `e.toString()` 을 노출한다 | **기능적으로 안전**(돈 안 움직임), **문구만 추하다.** M1 이 끝났으므로 오탐은 없다 |
| ⑥~⑨ | 구 앱의 brandKey 조회는 여전히 쿼리다. 부모에 복사본이 남아 있어 동작한다 | 안전 |
| ⑦~⑧ (신 앱, 구 Rules) | 신 앱이 `private/profile` 을 읽는다. 구 Rules 에 그 경로가 없다 → **`permission-denied`** | **brand 정보 화면의 brandKey 행만** 깨진다. ⑧ 을 즉시 붙여 창을 수 분으로 |
| ⑧~⑨ | 부모에 PII 복사본이 남아 있다 | **보안 목표가 아직 달성되지 않은 구간**이다. ⑨ 를 미루면 R9 미이행 — **완료 기준에 포함** |

> **④ 를 먼저 보내지 못하는 사정이 생기면**(예: Rules 하네스 실패) **⑥ 도 함께 미룬다.**
> G1 게이트만 먼저 올리는 조합은 선택지가 아니다 — 위조가 데이터로 굳는다.

### 17.2 라이브 검증 (⑩)

1. 승인 매장에서 **정상 결제 1건** → 성공
2. 그 매장의 핵심 필드(전화번호)를 점주가 수정 → `status:'pending'` 회귀 확인 → **같은 매장에서 결제 1건 → 성공** (R2 불변식, **이번 설계의 핵심 검증**)
3. 미승인 신규 매장(`approvedAt` 없음)에 대해 CF 직접 호출 → **거절** + `paymentGateRejections` 1건
3-b. **점주 계정으로 `approvedAt` 을 담은 매장 create 를 SDK 로 직접 시도 → 거부**
   (§6.5 Rules-A. **이 항목이 통과하지 못하면 3번의 거절은 우회 가능한 거절이다**)
3-c. **점주 계정으로 `approvedBy` / `rejectedReason` 를 담은 create → 각각 거부**
4. 메뉴 1개를 점주가 품절 → 그 메뉴를 담은 카트로 결제 → **거절** + 문구에 **메뉴명이 보인다**
5. 가맹점 메뉴의 override 를 `pending` + `soldOut:true` 로 둔 채 결제 → **거절** (status 무관 즉시 적용 확인)
6. 가맹점 메뉴의 override 를 `pending` + `excluded:true` 로 둔 채 결제 → **성공** (excluded 는 approved 일 때만)
7. 점주 계정에서 brandKey 조회 → 정상. 다른 브랜드 문서 직접 read 시도 → `private/profile` **거부**
8. brandKey 를 아는 점주의 매장 등록 → 정상 (R10)
9. 점주 계정으로 `stores/{자기매장}` delete 직접 시도 → **거부**
10. admin **더보기 → 매장 관리 → 목록 → 삭제 화면** 진입 → `dryRun` 숫자 표시 →
   `deleteStore` 1회(테스트 매장) → `storeDeletionHistory` 1건(`phase:'done'`) + 서브컬렉션 0 +
   Storage 이미지 0 확인
10-b. **진행 중 주문이 있는 매장**의 삭제 화면 → 버튼 비활성 + 사유 표시 (§11.4)
10-c. **Q1 사실 확인 (T-2 전용)** — 실제 테스트 카드/카카오페이로 게이트 거절을 일으키고
   **카드사 알림·결제 내역에 아무것도 남지 않는지** 확인한다. 남으면 design §3.4 의 돈 줄을
   `아직 결제가 완료되지 않았어요`(Q1 ⓑ)로 **즉시 교체**한다
11. **품절을 되돌린 뒤 같은 카트로 결제 → 성공** (오탐 복구 경로)

### 17.3 중단 기준

- ③ 또는 ⑤ 의 dry-run 에 **무효 값 목록이 비어 있지 않으면 멈추고 보고**한다 (자동 변환 금지).
  ③ 의 **승인 메타 이상치**(§16 M1)가 0건이 아니면 **멈추고 보고**한다 — 자동 정리하지 않는다.
- ④(Rules-A)가 실패하면 **⑥ 을 진행하지 않는다** (§17.1 마지막 단락).
- ⑩-2 가 실패하면(정보 수정 중 결제 거부) **즉시 ⑥ 을 롤백**한다. 불변식 위반이고 돈이 멈추는 방향이다.
- ⑩-3b/3c 가 실패하면(create 위조가 통과) **⑥ 을 롤백**한다. 게이트가 장식이 된 상태다.
- ⑩-7 에서 admin 매장 승인 화면의 `BrandScopeBadge` 가 경고로 떨어지면 **⑧ 을 롤백**한다
  (매장 승인이 전면 불가가 된다).
- **롤백 단위**: ④ 단독 / ⑥ 단독 / ⑦+⑧ 함께. ③⑤ 는 되돌리지 않는다
  (데이터 정상화·복사는 그대로 두는 것이 안전하다).

---

## 18. 테스트 / 가드

### 18.1 단위 (Dart)

- `canSellNow` 진리표: approved / pending+approvedAt / pending 단독 / rejected / 미지문자열 / null
- `applyOverrideForCustomer` — 기존 테스트 유지 + 골든 fixture 케이스 8개
- `ValidateCheckoutUseCase` — 위반 0건 / 품절 1건 / excluded / 메뉴 부재 / 매장 부재

### 18.2 교차 골든 (R4 — 이 task 의 핵심 가드)

- `test_fixtures/menu_visibility_contract.json` — Dart 테스트와 `functions npm test` 가 **같은 파일**을 읽는다
- `test_fixtures/store_sellability_contract.json` — 같은 방식으로 `canSellNow` 를 고정
- 한쪽만 바뀌면 골든이 깨져 **대조가 강제**된다 (기존 `qoin_cart_contract.json` 패턴)

### 18.3 grep 가드 (§21.7 R3)

`test/.../payment_authority_guard_test.dart` 신규:

1. `soldOut` 직접 비교 / `override.status == approved` 비교가 **TS 측에서 `menuVisibility.ts` 1곳에만** 나온다
2. `'approved'` / `'pending'` / `'rejected'` **문자열 리터럴 비교가 결제 경로(`verifyTossPayment.ts`,
   `checkout_*`, `cart_*`)에 없다** — `canSellNow` 만 쓴다
3. `EntityApprovalStatus.fromString` 이 **게이트 판정 경로에서 호출되지 않는다** (fail-open 복제 금지)
4. `stores.doc(...).delete()` 가 클라이언트 코드에 **0건**이다
5. `where('brandKey'` 가 클라이언트 코드에 **0건**이다
6. `payment_result_page.dart` 에 `e.toString()` 류 원시 예외 노출이 **0건**이다
6-c. **design §9.2 가 제안한 가드 4건을 채택한다**: ⓐ 모르는 토큰·임의 예외 문자열을
   `PaymentFailure.from` 에 넣으면 **결과 어떤 텍스트에도 입력 문자열이 포함되지 않는다**
   (§15.1 의 "서버 바이트가 화면에 도달하는 경로가 없다" 를 기계로 고정) ⓑ 알려진 6개 사유가
   각각 design §3.1 의 헤드라인·버튼을 가진다(사유 추가 시 표 누락이 테스트 실패) ⓒ **갈래 C
   화면에 `요금`/`청구` 단어가 0건**(돈을 단정하지 않는 규칙) ⓓ `CartLineAvailability` 에
   `verified`/`ok` 값이 **없다**(design N2 — UI 가 "확인됨" 을 그릴 수 있는 길 자체를 없앤다)
6-b. `StoreModel` 의 **create payload 2개**(`toFirestoreForCreate` · `toFirestoreForBrandCreate`)에
   `approvedBy`/`approvedAt`/`rejectedReason` 키가 **0건**이다 — 누군가 나중에 추가하면 Rules-A 가
   매장 등록을 전면 거부하므로 **빠르게 실패하도록** 고정한다
7. **허용 목록**: 매장 목록 노출 필터(`store_repository_impl.dart:224`)는 게이트가 아니므로 2번의 예외로 명시

### 18.4 functions

- 게이트 단위 테스트: 매장 상태 6케이스 × 메뉴 5케이스
- **confirm 이 호출되지 않음을 단언**한다 (거절 경로에서 Toss 를 치지 않는 것이 R5 다)
- `paymentGateRejections` 1건이 쓰이는지
- `issueBrandKey` 동일 키 동시 2회 → 1회만 성공 (문서 ID 유일성)
- `lookupBrandByKey` 미존재/미승인 응답이 **동일**한지

### 18.5 Rules 하네스

**create·update 교차 확인 (§6.7 — 이 블록이 이번 가드의 핵심이다)**

- 점주 매장 **create** 에 `approvedAt` 포함 → **거부**
- 점주 매장 **create** 에 `approvedBy` 포함 → **거부**
- 점주 매장 **create** 에 `rejectedReason` 포함 → **거부**
- 점주 매장 **create** 에 세 필드를 **명시적 `null`** 로 포함 → **허용** (부재와 동등)
- 점주 매장 create 정상 payload(현재 앱과 동일한 키 집합) → **허용** (회귀 — 매장 등록이 막히면 안 된다)
- 점주 매장 **create** 에 `rejectedAt` 포함 → **거부** (§6.8 신규 필드)
- 점주 매장 **update** 로 `approvedAt` 에 값 설정 → **거부** (기존 보호 회귀)
- 점주 매장 **update** 로 `approvedAt: null` → **허용** (T3 재제출 회귀)
- **F-03 — 게이트 입력 `status` 의 create 케이스 (초판 누락)**
  - 점주 매장 **create** 에 `status:'approved'` → **거부**
  - 점주 매장 **create** 에 `status:'rejected'` → **거부**
  - 점주 매장 **create** 에 `status` **부재** → **허용** (앱은 항상 `pending` 을 쓰지만 Rules 는 부재 허용)
- **F-02 — `rejected` 전이 (초판 누락, 가장 중요)**
  - `rejected` → `pending` 인데 **`approvedAt` 을 그대로 둠** → **거부** (점주 분기)
  - 같은 케이스, **브랜드 보유자 분기**(`isStoreOwnerBrandUpdate`) → **거부**
  - 🔁 **회귀 (필수)** `rejected` → `pending` + **승인 메타 null 클리어** → **허용** (점주 분기)
  - 🔁 **회귀 (필수)** 같은 케이스, **브랜드 보유자 분기** → **허용**
  - 🔁 **회귀 (필수)** **admin 이 `rejected` → `approved`** 로 승인(`approveFields` 가 `approvedAt` 에
    값을 쓴다) → **허용.** 이 케이스가 없으면 전이 제약이 **admin 승인을 막은 것을 아무도 모른다**
- brand **create** 에 `approvedAt`/`approvedBy` 포함 → **거부** (§6.5 마지막 항목)

**B1 / D1**

- 제3자 로그인 사용자: `brands/{id}/private/profile` read **거부**, `brands/{id}` read 허용(Q2 ⓑ)
- holder / admin: `private/profile` read 허용, `brandKey` write **거부**
- 점주: `stores/{자기매장}` delete **거부**, admin delete 허용
- `brandKeys/{key}` read·write **모두 거부**
- `paymentGateRejections` / `storeDeletionHistory`: admin read 허용, 전원 write 거부
- 고객: `brands/{id}/menuItems`·`subCategories`·`optionGroups` read **계속 허용** (회귀 방지 — 좁히다 같이 막으면 메뉴가 전부 사라진다)

### 18.6 회귀

- 승인 매장 정상 결제 (불변식)
- **핵심 필드 수정 직후 결제** (R2 — 가장 중요한 회귀)
- 점주 brandKey 매장 등록
- admin 매장 승인 (`BrandScopeBadge` 정상)
- 브랜드 신규 등록 / 브랜드 정보 수정
- `flutter analyze` 무경고 · `flutter test` · `functions npm test` 전건 통과

---

## 19. 작업 분배

### designer — **1차 완료** (`design.md`, 702줄, `88b6e4c`) → **재호출 1회 필요**

**design.md 1차는 수용한다.** spec §15 문구를 구조로 바꾼 판단, 실패를 돈 상태에 따라
3갈래(A/B/C)로 나눈 판단, 선검증에 **긍정 표시 금지(N1·N2)** 를 규칙으로 세운 판단은 모두
spec §8.2 의 fail 방향을 UI 로 정확히 옮긴 것이다. 아래 **수정 4건 + 추가 1건**만 반영한다.

| # | 수정 | 근거 |
|---|---|---|
| **1** | **§6.2 점주 안내 문구의 첫 문장 제거** — `잠시 쉬려면 '운영 정보 수정'에서 임시 휴업을 켤 수 있어요` | **`temporaryClosed` 는 아무 효과가 없다**(§6.9). 그대로 두면 거짓 안내다. design 이 열어 둔 "developer 가 확인하고 아니라면 빼고 보고" 조건이 **확인 결과 성립하지 않는다.** 두 번째 문장만 남긴다 |
| **2** | **§7.2 영향 범위 섹션에 `진행 중인 주문 n건` 행 추가** + n ≥ 1 이면 삭제 버튼 비활성 + 사유·이유 2줄 + 경쟁 상황 문구 | §11.4 — 근거가 UX 가 아니라 **돈**이다. 매장을 지우면 그 주문의 취소·환불이 영구히 막힌다 |
| **3** | **§3.5·§3.6 에 "일부 해석 실패" 행 명시** — 일부만 해석되면 **해석된 이름만 그리고 부족하다는 표시를 하지 않는다** | §15.1. design 은 "전부 해석 실패" 만 적었다. 일부 실패가 더 흔하다(카트가 그 사이 바뀜) |
| **4** | **§2 인벤토리 4-4 의 `카운트 출처 미정` 을 `deleteStore(dryRun: true)` 로 확정 기입** | §11.3 |
| **5 (추가)** | **품목 수 상한 50 의 UI 영향 없음을 확인만** — design D5 의 "전부 열거" 는 그대로 유효하다. 토큰 절단 처리를 UI 에 만들지 **않는다** | §15.1. 입력 상한으로 절단이 구조적으로 발생하지 않는다 |

**design Q1~Q7 전건 추천안 확정** (사용자, 2026-10-27): Q1 "요금 청구 없음" **사용**(T-2 에서
실결제로 사실 확인, 어긋나면 ⓑ 약한 문구로 교체) / Q2 오류 코드 캡션은 **갈래 A 기본 문구·갈래 C
화면에만** / Q3 점주 공백 **수용**(안내 문구만, 후속 N4) / Q4 브랜드 `pending` 회귀 시 **키를
보여주고 주의 문구** / Q5 **더보기 → 매장 관리 → 목록 → 삭제**(전체 매장 목록 화면 **신설**) /
Q6 선검증 타임아웃 **3초** / Q7 빠른 재주문은 **이름 열거 후 "나머지만 담기"**.

> **Q5 가 화면 1개를 신설한다** → §0 영향 범위·라우팅, §19 developer, §17.2 배포 검증에 반영했다.

#### (참고) 1차 design 에 요청했던 범위

산출물: `docs/tasks/payment_server_authority/design.md`

| # | 항목 |
|---|---|
| 1 | **결제 거절 화면** — `payment_result_page.dart` `_FailBody` 의 사유별 문구·아이콘·액션. 특히 `MENU_SOLD_OUT` 의 **메뉴명 목록 표시 레이아웃**(1개/여러 개) |
| 2 | **체크아웃 선검증 차단 UI** (Q4 ⓐ) — 결제 버튼을 누른 뒤 위반을 알리는 방식(다이얼로그 vs 카트 복귀 + 배너). "해당 품목 빼기" 액션 포함 |
| 3 | **카트 화면 품절 표시** — 기존 `menu_item_card.dart` `_soldOutOverlay` / `menu_search_result_tile` 의 톤과 통일. `home_search` design §15.6b 가 세운 "품절은 볼 수 있고 담을 수 없다" 규칙을 카트에 확장 |
| 4 | **점주 매장 삭제 → 안내 전환** — 버튼 제거 후 그 자리에 무엇을 둘지(폐업 문의 안내). 위험한 빨간 버튼을 없애는 것이므로 레이아웃 변화가 있다 |
| 5 | **brand 정보 화면 brandKey 행의 3상태** — 발급됨 / 미발급 / **읽기 실패**. 세 번째가 신규이고, 두 번째와 **혼동되면 안 된다**(U4) |
| 6 | admin 매장 삭제 화면 (Q3 ⓑ 선택 시) — 확인 다이얼로그 + 영향 범위(서브컬렉션 건수) 표시 |
| 7 | `AppColors` 만 사용. `Color(0x...)` 금지 |

> 전달 사항: **§12 표면 인벤토리 표를 design.md 에 그대로 옮기고 행을 추가한다.** 화면을 추가하면서
> 표에 행을 넣지 않으면 리뷰 FAIL (§21.7 R2).

### developer — **T-1 FAIL 재작업 (2026-10-27, 우선)**

`test_report.md` F-01~F-04. **아래 4커밋으로 끊는다** (커밋 경계가 롤백 단위다).

| 커밋 | 내용 | 왜 이 경계인가 |
|---|---|---|
| **C1 — Rules-A 보강 + 하네스** | ⓐ `firestore.rules`: §6.5 **전이 제약**(`leavingRejectedClearsApproval`)을 **`isStoreOwnerFieldUpdate` / `isStoreOwnerBrandUpdate` 내부에** 넣는다(`allow update` 전체에 걸면 **admin 승인이 막힌다** — §6.5 표) + create 에 `rejectedAt` 금지 1줄 ⓑ `test_rules/rules.test.mjs` PSA-A 블록에 **§18.5 의 F-02 6건 + F-03 3건** 추가 | **Rules-A 는 ④ 에서 가장 먼저 나간다.** 이 보강이 ④ 이전에 들어가야 Rules 를 두 번 배포하지 않는다. 하네스를 같은 커밋에 두는 이유는 F-03 이 "규칙의 결함이 아니라 회귀 방지 장치의 공백" 이기 때문이다 — 규칙과 그 규칙을 지키는 테스트가 떨어지면 안 된다 |
| **C2 — 게이트 모드 스위치** | `PAYMENT_GATE_MODE` param(`off`/`shadow`/`enforce`, **미지값 → `off`**), `verifyTossPayment` 에 모드 분기, `shadow` 기록에 `detail.shadow:true`, **`off` 에서는 읽기조차 하지 않는다**(비용 0). `functions/test/paymentGate.test.mjs` 에 **모드 3값 × 위반 유무** 케이스 | ⑥ 을 **어떤 명령으로 올려도 안전**하게 만드는 보험이다. C1 과 분리하는 이유: Rules 와 CF 는 배포 단위가 다르고 롤백도 따로 한다 |
| **C3 — M1 리포트 확장** | `migrateStoreApprovalMeta` dry-run 에 **ⓓ `willBeRejected`** + **ⓔ 모호 건 2종**(§16). **자동 수정 없음 — 목록만** | 운영자가 ⑥ 전에 "어느 매장이 막힌다" 를 보는 **유일한 수단**이다. 코드 변경 범위가 작고 독립적이다 |
| **C4 — `rejectedAt` 분리 + F-04** | ⓐ `rejectFields` 가 `rejectedAt` 을 쓴다(§6.8), `StoreModel`/`StoreEntity` 에 필드 추가, Rules 화이트리스트에 `rejectedAt`(null 클리어만), `entity_approval_status.dart:3` 주석 보강 ⓑ `cart_availability_banner.dart:28,30,32` **백틱 3곳 제거** | 근본 수정이지만 **배포를 막지 않는다**(§6.8 마지막 블록 — C1 이 즉시 차단을 담당한다). F-04 를 여기 붙이는 이유는 둘 다 "급하지 않고 독립적" 이라서다. **C4 없이 C1~C3 만으로도 배포 가능** |

> **배포 차단 조건은 C1 + C2 + C3 다.** C4 는 같은 배포에 넣는 것이 좋지만 빠져도 GO 다.
> C1 이 빠지면 §6.8 의 "모호 건이 배포를 막지 않는다" 판단도 **무효**가 된다.

추가 산출물: **`deploy_runbook.md`** (§17 + 런북 파일. 아래 "런북" 항목)

#### (1차) 구현 순서 — **순서를 지킨다** (의존 때문):

| 순서 | 항목 |
|---|---|
| 1 | `test_fixtures/menu_visibility_contract.json` + `store_sellability_contract.json` **먼저** 만든다. Dart 측 테스트를 통과시킨 뒤 TS 포팅을 한다 (갈라짐을 구조적으로 막는다) |
| 2 | `functions/src/storeSellability.ts` · `menuVisibility.ts` + npm test |
| 3 | `verifyTossPayment.ts` 게이트 — **`:116`~`:118` 사이**. `getAll` 1회로 묶는다. **거절 경로에서 Toss 를 호출하지 않는다.** 조회 결과는 **단가(`basePrice`/`priceOverride`)까지 포함한 구조로 반환**한다 — N1(서버 가격 재계산)이 그 반환값만 소비하면 되게 (§20 Q6) |
| 4 | `paymentGateRejections` 쓰기 + **`[REASON]` / `[REASON:id1,id2]` 토큰 (§15.1 문법 그대로)** + **`cart.items.length <= 50` 입력 검증** |
| 5 | 임시 마이그레이션 CF 2개 (dry-run 필수) |
| 6 | `lookupBrandByKey` · `issueBrandKey` · **`deleteStore`(`dryRun` 분기 + 진행 중 주문 가드 + `phase` 멱등 — §11.3·§11.4·§11.5. 순서는 ①이력 → ②매장문서 → ③서브컬렉션 → ④Storage → ⑤done)** |
| 6-b | **`orders` 진행 중 주문 쿼리의 복합 인덱스 필요 여부 확인** → 필요하면 `firestore.indexes.json` 에 추가하고 **배포 ① 단계를 비워 두지 않는다** (§11.4) |
| 7 | Dart: `store_sellability.dart`, `ValidateCheckoutUseCase`(반환 타입에 `failed` 를 UI 로 노출하지 않는다 — design §4.0), **`PaymentFailure.from(Object)` 순수 Dart 1개**(design §3.0, 토큰 파싱은 §15.1 정규식), `paymentRejectedMenuIdsProvider`, repository/datasource 교체 |
| 8 | 화면: 결제 실패 3갈래 · 카트 행·배너 · 체크아웃 차단 시트 · 빠른 재주문 다이얼로그 · `_ClosingGuide`(2곳) · brandKey 행 5상태 · **`AdminStoreListPage` + `AdminStoreDeletePage` + `admin_more_page` 항목**(design §7, Q5 ⓐ). admin 목록은 **기존 `watch_all_stores_for_admin_use_case.dart` 재사용**(신규 UseCase 금지) |
| 9 | `firestore.rules` — **Rules-A(§6.5 create 제약) / Rules-B(B1) / Rules-C(D1) 를 각각 분리 커밋**한다. Rules-A 는 **앱과 독립이고 ④ 에서 먼저 배포**되므로 반드시 독립 적용 가능한 패치여야 한다 (§1 · §17) |
| 10 | grep 가드 테스트 (§18.3) + **Rules 하네스의 create·update 교차 블록** (§18.5, §6.7) |
| 11 | 문서 갱신: `data_ownership.md` §2.5(**create 제약 1행 추가** + delete 정책 교체)·§2.x(신규 컬렉션 4개) / `entity_lifecycle.md` **§3.3 의 낡은 "확인 필요" 를 확정 사실로 교체**(§5-4) / `audit_trail.md` 에 신규 이력 3종 **+ §6.7 의 create·update 교차 확인을 §4 체크리스트 7번으로 추가** / `tester_guide.md` 상시 항목 1건 / `backlog.md`(⬜ 4건 → ✅, F8 흡수, 신규 후속 N1~N5 등재) |

**재사용할 기존 구조**

- 멱등 가드 패턴 (`verifyTossPayment.ts:86-116`)
- `cancelPayment` 보상 (`:145-156`) — 단 게이트 거절 경로에서는 쓰지 않는다(confirm 전이므로)
- 골든 fixture 양방향 고정 (`qoin_cart_contract.json`)
- dry-run → 실행 마이그레이션 (`migrateQoinZeroRates`)
- `[reason]` 토큰 이중 장치 (`backlog.md:566-569`)
- `QoinLoadError` / `다시 시도` 에러 UI 패턴

**주의할 레이어 규칙**

- `canSellNow` / `applyOverrideForCustomer` 는 순수 Dart. 외부 SDK import 금지
- 선검증은 UseCase 경유. Page 에서 Firestore 직접 접근 금지
- `CartEntity` / `CartItemEntity` 에 `scope`·`brandId` 를 **추가하지 않는다** (원칙 2)
- 색상은 `AppColors` 만

### tester — **구현 완료 후 1회 + 배포 후 1회**

산출물: `docs/tasks/payment_server_authority/test_report.md`

**시점 판단**: 이 task 는 **코드 검증과 배포 검증이 분리**된다.

| 시점 | 범위 |
|---|---|
| **T-1 (구현 직후, 에뮬레이터)** | §18.1~18.5 전건. 특히 **거절 경로에서 Toss confirm 이 호출되지 않음**과 **교차 골든**. Rules 하네스의 "고객 서브컬렉션 read 계속 허용" 회귀 |
| **T-2 (배포 후, 라이브)** | §17.2 의 11개. **⑨-2(정보 수정 중 결제 성공)가 최우선 항목**이다 |

**반드시 확인할 예외 케이스**

1. **승인 매장이 핵심 필드를 수정한 직후의 결제** — 불변식. 실패하면 FAIL·즉시 롤백
2. `status` 필드가 없는 legacy 매장 — M1 전/후 동작 차이
3. override `pending` + `soldOut:true` → **거절** / `pending` + `excluded:true` → **성공**
4. 품절 메뉴명이 거절 문구에 **실제로 보이는가** (이름이 없으면 고객이 복구할 수 없다)
5. 선검증이 네트워크 실패했을 때 **결제가 막히지 않는가** (§8.2)
6. `brand_info_page` 의 읽기 실패가 **"미발급" 으로 보이지 않는가** (U4)
7. 점주 매장 삭제 버튼이 **남아 있지 않은가** ("삭제에 실패했어요" 가 보이면 FAIL)
8. admin 매장 승인 흐름의 `BrandScopeBadge` 회귀
9. **같은 사실을 말하는 표면을 전수 열거했는가** (`tester_guide.md` 상시 항목, §21.7 R5)
9-b. **권한 판정에 쓰는 필드의 `create`·`update` 양쪽 경로를 교차 확인했는가** (§6.7 — `tester_guide.md`
   상시 항목으로 **신규 등재**. 이번 분배에 포함). 구체적으로 `approvedAt` 을 담은 매장 create 가 거부되는지 —
   **이 1건이 FAIL 이면 G1 게이트 전체가 우회 가능하다**
10. **빠른 재주문에서 전부 위반일 때 기존 카트가 유지되는가** — 현행 `quick_reorder_section.dart:225`
   가 **카트를 먼저 비우고 담는다.** design §4.5 가 선검증을 비우기 **앞**으로 옮겨 이것을 막는다.
   이 항목이 FAIL 이면 고객의 카트가 통째로 날아간다
11. **품절 거절 토큰에 id 가 실려 오고, 화면에 이름이 보이는가** (§15.1). 2개 이상 전부 열거되는가.
   같은 메뉴가 옵션 2줄일 때 이름이 한 번만 나오는가. **미해석 id 가 화면에 그대로 그려지지 않는가**
12. **진행 중 주문이 있는 매장의 삭제가 차단되는가** (§11.4). 차단 뒤 그 주문의 **점주 취소·환불
   승인이 정상 동작하는가**(`cancelTossPayment` / `processRefund` 가 `stores` 를 읽는다)
13. **`deleteStore` 를 중간 실패 후 재실행하면 이력이 1건인가** (§11.5). 같은 ID 로 재생성 후 다시
   삭제하면 **이력이 2건**인가(`createdAt` 이 다르므로)
14. admin 신규 2화면의 loading / error / empty(0건) / empty(검색 0건)

---

## 20. 사용자 결정 — **전건 확정** (2026-10-27)

| Q | 확정값 | 구현 시 반드시 함께 지킬 것 |
|---|---|---|
| **Q1** | **ⓑ′** `status == 'approved' \|\| (status == 'pending' && approvedAt != null)`. M1 백필 선행 | **§6.5 Rules-A 가 성립 조건**이다. 이것 없이 게이트만 올리면 create 경로로 위조가 통과하고, 그 위조는 **데이터로 굳는다**(§17.1). §6.6 쓰기 경로 매트릭스 · §6.7 상시 규칙 동반 |
| **Q2** | **ⓑ** 비밀·PII 만 `brands/{id}/private/profile` 로 분리 | 점주·admin 표면 **재배선 0**(§10.4 의 9·10·11 행이 "무변경" 인 것이 이 안을 고른 이유다). **M2 는 2단**이고 ⑨(부모 필드 제거)까지 가야 R9 이행 |
| **Q3** | **ⓑ** 점주 delete 권한 제거 + admin 전담 `deleteStore` CF | **이력을 가장 먼저 기록**한다(§11.2 ①). 현재 점주 경로가 이미지를 먼저 지워 복구 불가를 만드는 순서와 반대로 간다. **점주 UI 를 함께 바꾼다**(U3 — 버튼만 남기면 "삭제에 실패했어요" 가 된다) |
| **Q4** | **ⓐ** 클라이언트 선검증 최소 포함 | **선검증의 fail 방향은 반대다**(§8.2) — 선검증이 네트워크 실패하면 **결제를 막지 않는다. 권위는 서버다.** 선검증과 서버 게이트가 **같은 판정 함수**를 쓰므로 판정은 하나다 |
| **Q5** | **ⓐ** confirm 이후 재검증 안 함 | "돈만 빠지고 주문 없음" 을 새로 만들지 않는다. **창(confirm 왕복, 수백 ms~수초)과 보상 경로(기존 점주 거절/환불)를 §7.3 에 명시한 대로 유지**한다 |
| **Q6** | **ⓑ** 서버 가격 재계산은 **별도 task, 이번 묶음 직후 최우선** | **N1 로 등재**(§21 후속 표). G2 가 만드는 메뉴 문서 읽기 경로(`stores/{s}/menuItems` · `menuOverrides` · `brands/{b}/menuItems` 를 `getAll` 1회로 묶는 §7.2 의 구조)를 **그 task 가 그대로 재사용**한다 → 추가 읽기 0 으로 닫을 수 있다. developer 는 §7.2 의 조회 결과를 **단가(`basePrice`/`priceOverride`)까지 포함한 형태로 반환**하게 구현해 둔다(사용하지 않더라도 — N1 이 그 반환값만 소비하면 되게) |

### 20.1 결정 근거 기록 (원래의 선택지 비교 — 보존)

아래는 결정 전 비교표다. 되돌아볼 때를 위해 남긴다.


| Q | 결정할 것 | 선택지와 대가 | 추천 |
|---|---|---|---|
| **Q1** | 결제 시점 매장 판매 가능 판정식 | **ⓐ** `rejected` 만 막는다 — 가장 싸지만 **원래 잡으려던 미승인/재생성 매장을 못 막는다**(잔여 위험 유지) / **ⓑ′** `approved \|\| (pending && approvedAt != null)` — **신규 필드 불필요**(`approvedAt` 이 이미 승인 이력이다). 대가는 `approvedAt` 백필 1건(M1)이고, 안 하면 legacy 매장이 전부 거부된다 / **ⓒ** 핵심 필드 수정을 `pending` 회귀와 분리 — 올바른 장기 방향이고 "이름 고치면 목록에서 사라지는" 기존 결함도 같이 고치지만, **심사 의미가 바뀌고 `entity_lifecycle.md` 재검토 + admin 재심사 흐름 재설계**가 따라온다(범위 2배) | **ⓑ′** (ⓒ 는 별도 task 로 등재. ⓑ′ 는 ⓒ 의 전진을 막지 않는다) |
| **Q2** | `brands` 비공개화 방식 | **ⓐ** 부모를 holder/admin 으로 좁히고 공개 미러 서브문서 — 완전하지만 **미러 CF + 드리프트 + 백필 + 점주·admin 표면 7곳 재배선**, 그리고 **돈과 닿는 파생 데이터를 새로 만든다** / **ⓑ** 부모는 그대로 두고 **비밀·PII 만** `private/profile` 로 — R8·R9 를 닫고 **점주·admin 화면 재배선 0**. 대가: `name`/`status`/`qoin*` 는 로그인 사용자에게 계속 보인다 / **ⓒ** 현행 유지 — 열쇠가 열쇠가 아닌 상태 지속 | **ⓑ** |
| **Q3** | `stores.delete` 범위 | **ⓐ** Rules 를 admin 전용으로 좁히고 점주 UI 만 정리 — 가장 싸지만 **하드 삭제가 Console 전용이 되어 이력이 영영 없다**(§4-2 수용) / **ⓑ** ⓐ + admin 전담 `deleteStore` CF(이력 1건 + 서브컬렉션·이미지 정리) — **이력이 남는 경로가 생긴다.** 대가: CF 1개 + admin UI 1개 / **ⓒ** 소프트 삭제(`status:'deleted'`) — `entity_lifecycle.md` 전이도 + 주문·메뉴·목록·검색 전반 영향, G1 판정식도 바뀜 | **ⓑ** |
| **Q4** | 결제창 **앞**의 클라이언트 선검증 | **ⓐ** 포함(최소) — 고객이 카드 승인창을 통과한 뒤 거절되는 것을 막는다. designer 작업 1건 추가 / **ⓑ** 제외 — 서버만 막는다. 거절이 **승인창 통과 후**에 오므로 "결제됐는데 주문이 없다" 는 오해를 부른다 | **ⓐ** (단 선검증은 권위가 아니다 — 선검증 실패 시 결제를 막지 않는다) |
| **Q5** | Toss confirm **이후** 재검증 | **ⓐ** 재검증하지 않는다 — 창은 confirm 왕복(수백 ms~수초)이고 보상 경로는 기존 점주 거절/환불 / **ⓑ** 트랜잭션에서 재검증 + 위반 시 `cancelPayment` — 창이 거의 0 이 되지만 **"돈은 빠졌고 주문은 없다"** 를 새로 만들 수 있다(현행 코드도 cancel 실패를 로그만 남긴다) / **ⓒ** 게이트를 결제창 앞으로 — 창이 훨씬 커진다 | **ⓐ** |
| **Q6** | **서버 가격 재계산**을 이번에 넣을지 | 조사 중 발견: **클라이언트가 보낸 가격이 그대로 주문·적립 기준이 된다**(§5-6). `:77` 의 금액 검증은 클라 값끼리의 비교라 의미가 없다. **ⓐ** 이번에 포함 — G2 가 만드는 읽기 경로에 단가가 이미 있어 추가 읽기 0. 그러나 **가격 불일치가 곧 결제 거부**이므로 오탐 표면이 하나 더 늘고(옵션 `priceDelta`·`priceOverride` 반영 시점·할인) 테스트 행렬이 커진다 / **ⓑ** 별도 task 로 분리 — 이번에 읽기 경로를 만들어 두어 **다음 task 가 매우 싸진다**. 그동안 구멍은 남는다(실행에 SDK 직접 호출 + 본인 결제 필요) | **ⓑ** — 단 **이번 묶음 직후 최우선 후속**으로 등재한다. 실결제가 돌기 전이라는 창은 Q6 에도 똑같이 적용된다 |

> **전건 추천안대로 확정됐다** (§20 상단 표). 위 비교표는 근거 보존용이며, 구현 기준은 §20 상단 표다.

---

## 21. 완료 기준

- [x] Q1~Q6 이 모두 결정되고 spec 에 반영됐다 (§20, 2026-10-27 확정)
- [ ] **§6.7 상시 항목 — 권한 판정에 쓰는 필드마다 `create`·`update` 양쪽 경로를 교차 확인했다.**
      Rules 하네스에 **판정 입력 필드별 create 거부 케이스가 1건씩** 있다 (§18.5).
      *표면 인벤토리 표와 같은 급의 가드다. 이 누락은 같은 패턴의 네 번째였다.*
- [ ] **Rules-A 가 ⑥(게이트 CF)보다 먼저 배포됐다** — 뒤집히면 위조가 데이터로 굳는다 (§17.1)
- [ ] **F-02 — `rejected → pending` 전이가 승인 메타를 유지한 채 통과하지 못한다.** 그리고
      **정상 재제출(메타 null 클리어)과 admin 승인은 여전히 허용된다** (§18.5 회귀 3건)
- [ ] **F-03 — 게이트 입력 `status` 의 create 거부 케이스가 하네스에 있다** (3건)
- [ ] **`PAYMENT_GATE_MODE` 가 없거나 모르는 값일 때 `off` 로 떨어진다** (§17.0)
- [ ] **`enforce` 전환 직후 거절 1건을 실제로 유도해 확인했다** — 확인 없이는 전환 완료가 아니다
- [ ] **M1 dry-run 이 `willBeRejected` 와 모호 건 2종을 보여준다** (§16 ⓓⓔ)
- [ ] **`deploy_runbook.md` 가 있고 11+2단계의 전체 한 줄 명령이 적혀 있다** (모든 명령에 `--project`)
- [ ] 화면 문구에 **마크다운 백틱이 0건** (F-04 + §15 머리말 규칙)
- [ ] `design.md` 작성 완료 (§19 designer 7항목 + §12 표면 인벤토리 이전·확장)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료 (T-1 + T-2)
- [ ] **R1~R14 각 항목이 구현 또는 보류 사유 명시**
- [ ] **승인 매장이 핵심 필드를 수정한 직후 결제가 성공한다** (불변식 — 이 항목이 FAIL 이면 배포 중단)
- [ ] 게이트 거절 경로에서 **Toss confirm 이 호출되지 않는다** (단위 테스트로 단언)
- [ ] 품절 거절 문구에 **메뉴명이 보인다** (토큰에 id 가 실리고 카트 이름으로 해석된다 — §15.1)
- [ ] **미해석 id·서버 원문이 화면 어느 문자열에도 포함되지 않는다** (§15.1 + design D4 가드 테스트)
- [ ] **진행 중 주문이 있는 매장은 삭제되지 않는다** (§11.4) — 이 항목이 FAIL 이면 그 매장의
      취소·환불이 영구히 막힌다
- [ ] **`deleteStore` 재실행이 이력을 중복 기록하지 않는다** (§11.5). 구현이 달라지면
      **design §7.2 실패 문구를 먼저 고친 뒤** 구현한다
- [ ] admin 매장 목록·삭제 화면이 동작하고 `role_flows.md` §4.4 에 1행이 추가됐다 (Q5 ⓐ)
- [ ] `payment_result_page` 에 원시 예외 문자열 노출이 **0건**
- [ ] Dart↔TS 교차 골든 2종이 양쪽 테스트에서 통과한다
- [ ] grep 가드 7항목 통과
- [ ] Rules 하네스: 제3자 `private/profile` 거부 · 점주 매장 delete 거부 · **고객 브랜드 서브컬렉션 read 허용(회귀)**
- [ ] M1·M2 가 dry-run 0건으로 수렴하고 **⑨(부모 문서 PII·brandKey 제거)까지 완료**됐다
      — ⑧ 에서 멈추면 R9 미이행이다
- [ ] M1 ⓒ 의 **승인 메타 이상치가 0건**이거나, 0건이 아닌 경우 사람이 판단한 처리 결과가 기록됐다
- [ ] 이력 3종(`brands/{id}/keyHistory`, `storeDeletionHistory`, `paymentGateRejections`)이 실제로 쓰인다
- [ ] 문서 갱신 완료: `data_ownership.md` · `entity_lifecycle.md` §3.3 · `audit_trail.md` · `backlog.md`
      (⬜ 4건 → ✅, **F8 흡수 1행**, 신규 후속 3건 등재)
- [ ] `flutter analyze` 무경고 / `flutter test` / `functions npm test` 전건 통과
- [ ] FAIL 없음 또는 후속으로 분리

### 이 spec 이 새로 등재하는 후속 과제 (`backlog.md`)

| # | 과제 | 근거 |
|---|---|---|
| N1 | **서버 가격 재계산** | §5-6. **Q6 ⓑ 확정 — 이번 묶음 직후 최우선.** §7.2 가 만든 메뉴 문서 읽기 경로(`getAll` 1회)를 재사용하므로 **추가 읽기 0** 으로 닫을 수 있다. 착수 근거도 동일하다 — **실결제 0회라는 창은 N1 에도 적용된다** |
| N2 | 핵심 필드 수정을 `pending` 회귀와 분리 (심사 정책) | §6.2 ⓒ. "이름 고치면 고객 목록에서 사라진다" 는 기존 제품 결함 포함 |
| N3 | 매장 `status` 전이 이력 (승인/반려) + `rejectedReason` 덮어쓰기 | §9-주의 |
| N4 | 매장 폐업 신청 흐름 / 소프트 삭제 | §11.1 ⓒ |
| N5 | `quick_reorder_section` 의 단가 역산 제거 | §5-2 |
| **N6** | **`temporaryClosed` 가 아무 일도 하지 않는다** — 점주가 켤 수 있는 스위치가 고객·CF 어디에도 효과가 없다 | §6.9. 같은 계열("서버가 권위를 갖는가")이지만 범위를 넓히지 않는다. 할 때는 ⓐ 고객 노출 ⓑ 결제 게이트 ⓒ 점주 화면 표시를 **한 번에** |
