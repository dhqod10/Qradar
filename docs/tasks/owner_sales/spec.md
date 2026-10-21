# 점주 매출 조회 (owner_sales) 기능 명세

> 작성: architect / 2026-10-21
> 선행 조사: 코드 실측 기준. 조사 결과와 기존 문서의 불일치는 §10 에 기록.

---

## 개요

- **목적**: 점주 4개 탭 중 유일하게 비어 있는 "매출" 탭(`owner_scaffold.dart:63` → `OwnerSalesPlaceholder`)을 실구현한다. 점주가 일 / 주 / 월 단위로 **총 매출 · 주문 건수 · 평균 객단가**와 **해당 기간 주문 목록**을 확인할 수 있게 한다.
- **작업 유형**: 신규 기능 (placeholder 교체)
- **집계 방식**: **클라이언트 집계**. `orders` 컬렉션을 기간 query 해서 앱에서 합산한다. **Cloud Functions 변경 0건.**
- **영향 범위**
  - 화면: `OwnerScaffold` 탭 2 (placeholder 제거), 신규 `OwnerSalesPage` + 하위 위젯
  - Domain: Entity 2종 신규, UseCase 1종 신규, `OrderRepository` 메서드 1개 추가
  - Data: `OrderRemoteDataSource` 메서드 1개 추가, `OrderRepositoryImpl` 구현 추가. **Model 변경 없음**
  - Presentation: `owner/sales/**` 신규 (Page / Provider / Widget)
  - 공통 컴포넌트: 변경 없음 (`PriceFormatter` 재사용)
  - 라우팅: 변경 없음 (`OwnerScaffold` 의 `IndexedStack` 내부 교체뿐)
  - 권한 / 환경 설정: **`firestore.rules` 변경 없음**. `firestore.indexes.json` 은 §6.3 결론에 따라 **변경 불필요(검증 필요)**
  - 테스트: 집계 로직 / 기간 경계 계산에 대한 단위 테스트 신규
- **비범위 (2차 — `docs/backlog.md` "점주 매출 조회 — 2차 범위" S1~S5)**
  - S1 메뉴별 판매 순위 / S2 시간대별 분포 차트 / S3 카드사별 매출 / S4 연 단위·기간 비교 / S5 CF 집계 전환
  - 매출 데이터 내보내기(CSV·엑셀), 세금계산서·정산, 매장 여러 개 합산(MVP 는 점주 1 매장), admin 전체 매출

---

## 1. 사전 조사 결과 (실측)

### 1.1 `orders` 금액 필드

`lib/domain/entities/order_entity.dart` / `lib/data/models/order_model.dart` 실측:

| 필드 | 타입 | 집계에서의 의미 |
|---|---|---|
| `subtotal` | `int` (필수) | 할인 전 소계 |
| `discount` | `int?` | 할인액. 현재 생성 경로에서 거의 항상 null |
| `totalPrice` | `int` (필수) | **실제 결제 금액. 매출 집계의 유일한 기준 필드** |
| `paymentInfo.amount` | `int` (필수) | PG 승인 금액. 정상 주문에서 `totalPrice` 와 동일해야 함 |
| `refundInfo.amount` | `int` (필수, nullable 객체) | 환불 금액. `processRefund` 가 **항상 전액 환불**이므로 `totalPrice` 와 동일 |

**결정**: 매출 = `totalPrice` 합계. `paymentInfo.amount` 는 쓰지 않는다(PG 응답 기준값이라 할인/쿠폰 도입 시 어긋날 수 있음).

### 1.2 타임스탬프 계열

`createdAt`(필수) / `updatedAt`(필수) / `acceptedAt` / `makingStartedAt` / `readyAt` / `completedAt` / `cancelledAt` / `refundedAt` (뒤 6개 nullable).

**결정**: 기간 query 축은 `createdAt`. 이유 — (a) 필수 필드라 누락이 없다, (b) 기존 인덱스 3개가 모두 `createdAt` 축이다, (c) 회계상 "매출 발생일 = 결제일" 이 자연스럽다.

### 1.3 결제 정보 저장 범위

`PaymentInfoEntity` 에 `method` / `channel` / `paymentKey` / `transactionId` / `receiptUrl` / `approvedAt` / `amount` / **`cardCompany`** / `cardNumberMasked` / **`easyPayProvider`** 가 모두 있다.

→ **backlog S3("카드사별 매출 — PG 응답에 카드사 정보가 저장되고 있는지 미확인")의 선행 조건은 이미 충족돼 있다.** 2차에서 별도 실측 없이 바로 착수 가능. (S3 자체는 이번 비범위.)

### 1.4 `orders` 읽기 권한 (점주)

`firestore.rules:146-150`:

```
allow read: if isAdmin()
            || (isSignedIn() && resource.data.userId == uid())
            || (isSignedIn() && isStoreOwner(resource.data.storeId));
```

`isStoreOwner(storeId)` 는 `get(/stores/$(storeId)).data.ownerId == uid()` (rules:45-48).

- **점주의 기간 query 는 Rules 변경 없이 그대로 허용된다.** 단, Firestore 의 query-rules 모델상 **query 결과 전체가 규칙을 만족함을 쿼리 제약으로 증명해야** 하므로, query 에 `where('storeId', isEqualTo: myStoreId)` 가 **반드시 포함**돼야 한다. storeId 없는 전역 기간 query 는 `permission-denied` 로 거부된다.
- `isStoreOwner` 의 `get()` 은 모든 결과 doc 이 동일 `stores/{storeId}` 경로를 참조하므로 요청 내 캐시된다 → 쿼리당 추가 read 는 **1회**.
- 매장 `status` 는 검사하지 않는다 → **pending / rejected 매장도 query 자체는 성공**한다(결과가 비어 있을 뿐).

### 1.5 재사용할 기존 패턴 (점주 주문 조회)

`lib/presentation/owner/orders/owner_orders_page.dart` 기준:

| 요소 | 현재 구현 | 매출 탭에서의 처리 |
|---|---|---|
| storeId 획득 | `ref.watch(myStoreProvider)` (`owner/providers/owner_providers.dart`) → `StoreEntity?` → `store.id` | **그대로 재사용** |
| 데이터 공급 | `StreamProvider.family` (`newOrdersByStoreProvider` 등, `customer/order/orders/providers/order_di_providers.dart`) | **`FutureProvider.family` 로 신설** (§5.3, 결정 D6) |
| UseCase 경유 | `watchStoreOrdersUseCaseProvider` → `OrderRepository.watchStoreOrders` → `OrderRemoteDataSource.streamPaidByStore` | 동일 계층 구조로 기간 조회 메서드 추가 |
| 금액 표기 | `intl` `NumberFormat` 또는 `PriceFormatter.formatKrw` | **`PriceFormatter.formatKrw` 로 통일** (core util 우선) |
| 로딩 | 리스트 모양 skeleton `Container` (shimmer 톤) | 동일 패턴 |
| 빈 상태 / 에러 | `Icon + 제목 + 보조문구` Center 조합 | 동일 패턴 |

> `build()` 안에서 inline provider 를 만들면 매 rebuild 마다 재생성돼 loading 에 머무는 안티패턴이 있다 — `order_di_providers.dart` 주석에 기록된 교훈. **매출 provider 도 반드시 top-level `family` 로 선언한다.**

### 1.6 `OwnerScaffold` 구조상의 주의

탭은 `IndexedStack` 이다 → 매출 페이지는 **한 번 빌드되면 탭을 떠나도 dispose 되지 않는다.** 따라서 "탭 재진입 시 자동 갱신" 은 일어나지 않는다. 갱신은 §4.4 의 명시적 트리거(기간 변경 / pull-to-refresh)로만 한다.

---

## 2. 요구사항

### 2.1 기능 요구사항

- [ ] **F1** 기간 타입 선택: `일` / `주` / `월` 3개 중 하나 (기본값 `일` = 오늘)
- [ ] **F2** 선택된 기간 타입 안에서 **이전 / 다음 기간 이동** (다음 이동은 현재 기간을 넘지 못함)
- [ ] **F3** 요약 지표 3종 노출
  - **총 매출** = 집계 대상 주문의 `totalPrice` 합 (환불/취소 제외 — §3)
  - **주문 건수** = 집계 대상 주문 수
  - **평균 객단가** = `총 매출 ÷ 주문 건수` (건수 0 이면 `0원`, 소수점은 버림 — `~/`)
- [ ] **F4** 보조 지표 노출: **환불 제외 금액 / 건수**, **취소 제외 건수**, (D1 선택에 따라) **진행 중 금액 / 건수**
- [ ] **F5** 해당 기간 주문 목록: `createdAt` 내림차순. 각 행에 시각 / 대표 메뉴 + 수량 / 금액 / 상태 배지
- [ ] **F6** 주문 목록에는 **환불·취소 건도 표시**하되 배지로 구분하고 금액은 취소선 또는 muted 처리 → 점주가 "왜 합계가 작은지" 를 화면에서 납득할 수 있어야 한다
- [ ] **F7** 주문 행 탭 → 기존 `OwnerOrderDetailPage(orderId:)` 재사용 진입
- [ ] **F8** 조회 가능 기간 상한 적용 (§7, 결정 D5)
- [ ] **F9** 집계 로직은 **UseCase + 순수 함수**로 분리. Page / Widget 은 집계 결과 Entity 만 소비한다 → S5(CF 집계) 전환 시 화면 무수정 (§8)

### 2.2 UI 요구사항

- [ ] **U1** AppBar 제목 `매출`, 기존 점주 화면과 동일한 `AppColors.background` / `textHeading` 톤
- [ ] **U2** 기간 타입 세그먼트(일/주/월) + 기간 네비게이터(`‹ 2026년 10월 21일 (화) ›` 형태) 헤더
- [ ] **U3** 요약 카드: 총 매출을 가장 크게, 주문 건수 / 평균 객단가를 보조로. 보조 지표(환불/취소/진행 중)는 하단 분리 영역
- [ ] **U4** 주문 목록은 요약 카드 아래 스크롤 연속. `bottom: 110` 패딩(점주 바텀 네비 높이 72 + 여유) — 기존 점주 리스트와 동일
- [ ] **U5** `AppColors` 만 사용. `Color(0x...)` 금지
- [ ] **U6** 금액 표기는 `PriceFormatter.formatKrw`, 날짜/시각은 `intl` `DateFormat` (`ko_KR` 은 `main.dart` 에서 이미 초기화됨)

### 2.3 상태 요구사항

| 상태 | 조건 | 화면 |
|---|---|---|
| loading (매장) | `myStoreProvider` loading | 중앙 `CircularProgressIndicator(color: AppColors.primary)` |
| **매장 없음** | `myStoreProvider` data == null | `등록된 매장이 없어요` + 보조문구 `매장을 등록하면 매출이 집계됩니다` + "내 매장" 탭으로 이동 CTA |
| **매장 승인 대기/반려** | `store.status != approved` | 요약(0원)과 빈 목록을 **정상 렌더**하고 상단에 안내 배너 `승인 완료 후 주문이 접수됩니다` (조회 자체는 Rules 상 허용되므로 차단하지 않는다) |
| loading (집계) | 기간 조회 진행 중 | 요약 카드 + 3행 리스트 skeleton |
| **empty (주문 0건)** | 조회 성공, 주문 0건 | 요약 카드는 **0원 / 0건 / 0원으로 렌더**(숨기지 않는다) + 목록 영역에 `이 기간에 주문이 없어요` + 보조문구 `주문이 들어오면 매출에 반영됩니다` |
| error | 조회 실패 | `불러오는 데 실패했어요` + **다시 시도** 버튼 (`ref.invalidate`) |
| error (권한) | `permission-denied` | `매출을 조회할 권한이 없어요` + 보조문구 `매장 소유자 계정으로 로그인했는지 확인해 주세요`. 재시도 버튼 없음 |

> **신규 매장이 첫 진입에서 보는 화면**: 매장 승인 전이면 "승인 대기 배너 + 0원 요약 + 주문 없음 안내", 승인 후 주문 전이면 "0원 요약 + 주문 없음 안내". **에러 화면이나 빈 흰 화면을 보이지 않는다.**

---

## 3. 매출 집계 규칙 (핵심)

### 3.1 status 분류

`OrderStatus` = `paid / accepted / making / ready / completed / cancelled / refunded` (`lib/domain/entities/order_status.dart`).
`docs/processes/entity_lifecycle.md §2.1` 기준 종료 상태는 `completed` / `cancelled` / `refunded` 3개뿐이고, `paid~ready` 는 모두 **결제가 성공한 진행 중** 상태다.

| status | 분류 | 총 매출 포함? |
|---|---|---|
| `completed` | 확정 매출 | ✅ 항상 |
| `paid` / `accepted` / `making` / `ready` | 진행 중 (결제 완료, 미종료) | **D1 결정 대상** |
| `cancelled` | 결제 취소 (PG 취소 완료, 입금 없음) | ❌ 항상 제외 |
| `refunded` | 환불 완료 (전액) | ❌ 항상 제외 |

- `cancelled`: `cancelTossPayment` CF 가 Toss cancel API 를 호출한 뒤 전이 → **애초에 매출이 아니다.** "취소 제외 건수" 로만 표시.
- `refunded`: `processRefund` CF 가 **항상 전액 환불** (`entity_lifecycle.md §2.5`) → 부분 차감 로직이 필요 없다. 전액 제외.
- `refundRequest` 가 있지만 `status != refunded` (요청 중 / 거절됨) → **아직 환불이 아니다. 매출에 그대로 포함.** 거절된 요청(`deniedAt != null`)도 포함.

### 3.2 환불 시점 기준 — **주문일(`createdAt`) 기준 차감**

같은 기간 query 결과 안에서 `status == refunded` 인 주문을 제외하는 방식이다. 즉 **환불은 그 주문이 발생한 날의 매출에서 빠진다** (환불 처리일이 아님).

- 10/01 주문이 10/20 에 환불되면 → **10/01 매출에서 차감**되고, 10/20 매출에는 아무 영향이 없다.
- **채택 이유**
  1. 단일 query(`storeId` + `createdAt` 범위)로 요약과 목록을 모두 만들 수 있다. 환불일 기준이면 `refundedAt` 범위 query 를 **한 번 더** 돌려야 하고(읽기 비용 2배), 기간 밖에서 발생한 과거 주문의 환불을 당겨와야 해서 목록과 요약의 대상 집합이 어긋난다.
  2. 과거 기간을 다시 조회했을 때 **숫자가 재현된다** (해당 기간 주문의 최종 상태만 보면 됨).
  3. S5(CF 집계 문서)로 전환해도 같은 규칙을 "주문일 버킷 재계산" 으로 그대로 구현할 수 있다.
- **부작용(명시)**: 이미 본 과거 기간의 매출 숫자가 나중 환불로 **사후 감소**할 수 있다. 정산 관점에서 더 정확한 쪽이지만, 점주가 "어제 금액이 줄었다" 고 느낄 수 있으므로 요약 카드에 **`환불 제외 n건 / -N원`** 을 항상 노출해 설명 가능하게 한다 (F4).
- 부분 환불은 현재 도메인에 존재하지 않는다. 도입 시 `refundInfo.amount` 로 **차감 금액을 계산**하도록 §3.3 집계식만 고치면 되게 설계한다.

### 3.3 집계식 (순수 함수 명세)

입력: 기간 내 `List<OrderEntity>` (status 무관 전체)

```
confirmed  = orders where status == completed
inProgress = orders where status in {paid, accepted, making, ready}
refunded   = orders where status == refunded
cancelled  = orders where status == cancelled

confirmedSales  = sum(confirmed.totalPrice)
inProgressSales = sum(inProgress.totalPrice)
refundedAmount  = sum(refunded.refundInfo?.amount ?? refunded.totalPrice)   // 부분 환불 대비
cancelledCount  = cancelled.length

// D1 에 따라 총 매출 정의가 갈린다
netSales   = confirmedSales (+ inProgressSales if D1 = 결제기준)
orderCount = confirmed.length (+ inProgress.length if D1 = 결제기준)
averageOrderValue = orderCount == 0 ? 0 : netSales ~/ orderCount
```

- 모든 금액은 `int`(원). **부동소수점을 쓰지 않는다.** 평균은 `~/` 로 버림.
- 합계가 `int` 범위를 넘는 일은 없다 (월 매출 수억 원도 `int64` 안).

### 3.4 기간 경계

| 기간 타입 | 시작(포함) | 끝(제외) |
|---|---|---|
| 일 | 해당일 `00:00:00.000` | 다음일 `00:00:00.000` |
| 주 | 주 시작 요일 `00:00:00.000` (D3) | +7일 `00:00:00.000` |
| 월 | 해당월 1일 `00:00:00.000` | 다음월 1일 `00:00:00.000` |

- 경계는 **`start <= createdAt < endExclusive`** 반열구간. `<=` 양끝을 쓰면 자정 주문이 두 기간에 중복 집계된다.
- 타임존 처리는 **D4 결정 대상**. 어느 쪽이든 경계 계산은 `SalesPeriod` 의 순수 팩토리에 **한 곳으로 집중**하고 단위 테스트로 고정한다(월말/연말/윤년/주 경계).
- `OrderModel._fromMap` 은 `Timestamp.toDate()` 를 쓴다 → 반환 `DateTime` 은 **디바이스 로컬 타임존**이다. 따라서 D4 를 "로컬" 로 정하면 추가 변환이 없고, "KST 고정" 으로 정하면 **data 레이어에서 UTC+9 로 정규화**해야 한다(presentation 에서 하지 않는다).

---

## 4. 데이터 모델

### 4.1 Entity (신규, 모두 순수 Dart + freezed)

**`SalesPeriodType`** (enum): `day`, `week`, `month`

**`SalesPeriod`** — 기간 값 객체 (freezed)

| 필드 | 타입 | 설명 |
|---|---|---|
| `type` | `SalesPeriodType` | 일/주/월 |
| `start` | `DateTime` | 포함 경계 |
| `endExclusive` | `DateTime` | 제외 경계 |

팩토리(순수, 테스트 대상): `SalesPeriod.day(DateTime anchor)` / `.week(DateTime anchor)` / `.month(DateTime anchor)` / `.current(SalesPeriodType, {DateTime? now})`
이동: `previous()` / `next()` / `bool get isCurrent` / `bool get canGoNext` / `bool get canGoPrevious` (상한은 D5)

> `now` 를 주입 가능하게 한다 (`DateTime.now()` 하드 참조 금지) — 기간 경계 단위 테스트의 전제.

**`SalesSummaryEntity`** — 집계 결과 (freezed)

| 필드 | 타입 | 설명 |
|---|---|---|
| `period` | `SalesPeriod` | 집계 기간 |
| `netSales` | `int` | 총 매출 (환불·취소 제외) |
| `orderCount` | `int` | 집계 대상 주문 건수 |
| `averageOrderValue` | `int` | 평균 객단가 (버림) |
| `confirmedSales` | `int` | `completed` 분 매출 |
| `confirmedCount` | `int` | `completed` 건수 |
| `inProgressSales` | `int` | 진행 중 분 매출 |
| `inProgressCount` | `int` | 진행 중 건수 |
| `refundedAmount` | `int` | 환불로 제외된 금액 |
| `refundedCount` | `int` | 환불 건수 |
| `cancelledCount` | `int` | 취소 건수 |

> `netSales` / `orderCount` / `averageOrderValue` 는 D1 정책이 반영된 **최종 표시값**이다. 화면은 이 3개만 크게 보여주고, 나머지는 내역 설명용. **정책이 바뀌어도 화면 코드는 그대로다.**

**`StoreSalesEntity`** — 화면이 소비하는 단일 결과 (freezed)

| 필드 | 타입 | 설명 |
|---|---|---|
| `summary` | `SalesSummaryEntity` | 요약 |
| `orders` | `List<OrderEntity>` | 기간 내 전체 주문 (`createdAt` desc, 환불·취소 포함) |
| `isTruncated` | `bool` | 상한(§7)에 걸려 일부만 가져왔는지 |

> **S5 전환 시 핵심**: CF 집계로 바꾸면 `orders` 를 빈 리스트로 두거나 별도 lazy 조회로 분리하고 `summary` 만 서버 문서에서 읽으면 된다. `StoreSalesEntity` 가 경계를 고정한다.

### 4.2 Model / DTO

**신규 없음.** `OrderModel` 을 그대로 쓴다. Firestore 필드 추가·변경 **0건**, 마이그레이션 **없음**.

---

## 5. 레이어 설계

### 5.1 Domain

| 산출물 | 경로 | 책임 |
|---|---|---|
| Entity | `lib/domain/entities/sales_period.dart` | `SalesPeriodType` + `SalesPeriod` + 경계/이동 순수 로직 |
| Entity | `lib/domain/entities/sales_summary_entity.dart` | `SalesSummaryEntity` |
| Entity | `lib/domain/entities/store_sales_entity.dart` | `StoreSalesEntity` |
| UseCase | `lib/domain/usecases/get_store_sales_use_case.dart` | `call({required String storeId, required SalesPeriod period}) → Future<StoreSalesEntity>`. Repository 로 기간 주문을 받아 **순수 집계 함수**에 넘긴다 |
| 순수 집계 함수 | 위 UseCase 파일 내 top-level `@visibleForTesting SalesSummaryEntity aggregateStoreSales(List<OrderEntity>, SalesPeriod)` | §3.3 집계식. **Repository·Firebase·Riverpod 무의존** |
| Repository Interface | `lib/domain/repositories/order_repository.dart` (기존 수정) | 메서드 1개 추가 |

추가 메서드:

```dart
/// 특정 매장의 [startInclusive, endExclusive) 기간 주문. createdAt 내림차순.
/// status 필터 없음 — 환불/취소 포함 전체를 반환한다 (집계는 UseCase 책임).
Future<List<OrderEntity>> getStoreOrdersInPeriod(
  String storeId, {
  required DateTime startInclusive,
  required DateTime endExclusive,
  int? limit,
});
```

- **`Stream` 이 아니라 `Future`** 인 이유는 D6.
- status 필터를 **데이터 소스에 넣지 않는다**: (a) 환불/취소 건도 목록에 보여야 하고(F6), (b) `whereIn` 조합이 늘면 인덱스가 늘어나며, (c) 집계 정책(D1)이 바뀔 때 쿼리를 안 고쳐도 되게 한다.

### 5.2 Data

| 산출물 | 경로 | 내용 |
|---|---|---|
| DataSource (기존 수정) | `lib/data/datasources/remote/order_remote_data_source.dart` | `Future<List<OrderModel>> fetchByStoreInPeriod(...)` 추가 |
| Repository Impl (기존 수정) | `lib/data/repositories/order_repository_impl.dart` | `getStoreOrdersInPeriod` 구현 (`Model → Entity` 매핑만) |

쿼리 형태 (data 레이어 전용):

```
orders
  .where('storeId', isEqualTo: storeId)
  .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive))
  .where('createdAt', isLessThan:              Timestamp.fromDate(endExclusive))
  .orderBy('createdAt', descending: true)
  .limit(limit ?? <상한>)
  .get()
```

- `where('storeId', ...)` 는 **Rules 통과를 위한 필수 제약**이다 (§1.4). 제거하면 `permission-denied`.
- `get()` 사용 → `snapshots()` 아님 (D6).
- 기존 `streamPaidByStore` / `streamRefundRequestsByStore` 는 **손대지 않는다** (주문 접수 탭 회귀 방지).

### 5.3 Presentation

경로: `lib/presentation/owner/sales/`

| 산출물 | 파일 | 내용 |
|---|---|---|
| DI / Provider | `providers/owner_sales_providers.dart` | 아래 목록 |
| Page | `owner_sales_page.dart` | `ConsumerWidget`. `myStoreProvider` → 분기 → 요약 + 목록 |
| Widget | `widgets/sales_period_header.dart` | 일/주/월 세그먼트 + `‹ 기간 ›` 네비게이터 |
| Widget | `widgets/sales_summary_card.dart` | 총 매출 / 건수 / 객단가 + 보조 지표 |
| Widget | `widgets/sales_order_tile.dart` | 주문 1행 (시각 / 대표 메뉴 / 금액 / 상태 배지) |
| Widget | `widgets/sales_empty_state.dart` | 빈 상태 / 에러 / 권한 에러 공용 |
| 삭제 | `lib/presentation/owner/placeholders/owner_sales_placeholder.dart` | 참조가 사라지므로 **파일까지 제거** (죽은 파일 방치 금지) |
| 수정 | `lib/presentation/owner/owner_scaffold.dart` | `OwnerSalesPlaceholder()` → `OwnerSalesPage()`, import 교체 |

Provider 목록 (**모두 top-level 선언**):

| Provider | 타입 | 설명 |
|---|---|---|
| `getStoreSalesUseCaseProvider` | `Provider<GetStoreSalesUseCase>` | `orderRepositoryProvider` 주입 (기존 `order_di_providers.dart` 의 provider 재사용) |
| `salesPeriodTypeProvider` | `NotifierProvider<_, SalesPeriodType>` | 기본 `day` |
| `salesPeriodProvider` | `NotifierProvider<_, SalesPeriod>` | 현재 조회 기간. 타입 변경 시 `SalesPeriod.current(type)` 로 리셋, 이동 시 `previous()/next()` |
| `storeSalesProvider` | `FutureProvider.family<StoreSalesEntity, StoreSalesQuery>` | `StoreSalesQuery(storeId, period)` — `==`/`hashCode` 가 있는 freezed 값객체여야 family 캐시가 동작한다 |

- Page 는 `salesPeriodProvider` 와 `myStoreProvider` 를 watch 해 `storeSalesProvider(StoreSalesQuery(...))` 를 watch 한다.
- pull-to-refresh / 재시도 = `ref.invalidate(storeSalesProvider(query))`.
- `autoDispose` 를 쓴다 (기간을 여러 번 바꿔도 메모리가 쌓이지 않게). 단 §1.6 때문에 **탭 이동으로는 dispose 되지 않는다**는 점을 developer 가 알고 있어야 한다.
- `presentation` 에서 `cloud_firestore` / `Timestamp` 를 **import 하지 않는다**. 경계는 `DateTime`.

---

## 6. 데이터 흐름

```text
OwnerSalesPage
  → myStoreProvider (StoreEntity?)            // 기존 재사용
  → salesPeriodProvider (SalesPeriod)
  → storeSalesProvider(StoreSalesQuery)
  → GetStoreSalesUseCase
      ├─ OrderRepository.getStoreOrdersInPeriod   (I/O)
      └─ aggregateStoreSales(orders, period)      (순수 집계 — S5 전환 시 이 자리만 교체)
  → OrderRepositoryImpl
  → OrderRemoteDataSource.fetchByStoreInPeriod
  → Firestore `orders` (storeId == X AND createdAt in [start, end))
```

### 6.1 Rules

**변경 없음.** 기존 `orders.read` 의 `isStoreOwner(resource.data.storeId)` 분기로 충족 (§1.4).

### 6.2 Cloud Functions

**변경 0건.** 신규 CF 없음, 기존 CF 호출 없음.

### 6.3 Firestore 복합 인덱스

필요 쿼리: `storeId ==` + `createdAt range` + `orderBy createdAt desc`
→ 요구 인덱스 = **(`storeId` ASC, `createdAt` DESC)**

`firestore.indexes.json` 실측: `orders` 에 이미
**(`storeId` ASC, `createdAt` DESC, `refundRequest` DESC, `__name__` DESC)** 가 존재한다.
Firestore 복합 인덱스는 **필드 접두(prefix)** 쿼리를 처리할 수 있으므로, 이 인덱스가 `(storeId, createdAt)` 쿼리를 커버한다.

**결론: 인덱스 추가는 불필요할 것으로 판단. 단 반드시 실측 검증한다.**

- developer: 에뮬레이터 또는 dev 프로젝트에서 실제 쿼리를 1회 실행해 `failed-precondition: The query requires an index` 가 나오지 않는지 확인하고 결과를 `implementation.md` 에 기록한다.
- 만약 에러가 나면 아래를 `firestore.indexes.json` 의 `indexes` 배열에 추가하고 **"배포 필요 작업"** 으로 분류한다 (`firebase deploy --only firestore:indexes`).

```json
{
  "collectionGroup": "orders",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "storeId",   "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

- **배포 필요 작업 체크리스트**: Rules 배포 ❌ 불필요 / CF 배포 ❌ 불필요 / **인덱스 배포 — 위 검증 결과에 따라 조건부**.

---

## 7. 읽기 비용과 조회 기간 상한

### 7.1 비용 구조

클라이언트 집계는 **조회 기간의 주문 수 = document read 수** 다. 여기에 Rules `isStoreOwner` 의 `get(stores/{storeId})` **1회**가 쿼리당 더해진다 (동일 경로이므로 캐시되어 1회).

| 매장 규모 | 일 조회 | 월 조회 |
|---|---|---|
| 일 20건 | 20 reads | ~600 reads |
| 일 100건 | 100 reads | ~3,000 reads |
| 일 300건 | 300 reads | ~9,000 reads |

- 기간을 바꿀 때마다 재조회가 발생한다. `FutureProvider.family` 캐시로 **같은 기간 재방문은 0 read**.
- 월 수천 건대에 들어가면 backlog **S5(CF 집계)** 전환 검토 구간이다 (`backlog.md` 의 전환 기준과 일치).

### 7.2 상한 결정 — **둔다**

**사유**: 상한이 없으면 (a) 대형 매장이 월 탭을 몇 번 누르는 것만으로 수만 read 가 발생하고, (b) 결과 리스트가 수천 건이 되어 집계·렌더가 모두 느려지며, (c) 사고가 나도 화면에 아무 신호가 없다. 1차는 클라이언트 집계이므로 **방어선을 코드에 박아 둔다.**

적용 방식:

1. **단일 조회 문서 상한** `limit(1000)` 을 쿼리에 고정한다. `orderBy createdAt desc` 이므로 잘릴 때 **최신 1000건**이 남는다.
2. 결과가 상한에 닿으면 `StoreSalesEntity.isTruncated = true` → 요약 카드에 경고 문구 `주문이 많아 최근 1,000건만 집계했어요` 를 노출한다. **조용히 틀린 숫자를 보여주지 않는다.**
3. **과거 이동 상한**: 현재 기간 기준 **최대 12개월 전까지** (`SalesPeriod.canGoPrevious`). 그 이전은 버튼 비활성.
4. 상한값은 `lib/core/constants/` 에 **명명 상수**로 둔다 (매직 넘버 금지). 예: `SalesQueryLimits.maxDocumentsPerQuery`, `SalesQueryLimits.maxMonthsBack`.

> 1,000 은 "일 300건 매장의 월 조회(약 9,000건)" 를 다 담지는 못한다. **의도된 선택**이다 — 그 규모면 클라이언트 집계 자체가 맞지 않으므로 S5 로 가는 신호(`isTruncated`)를 띄우는 편이 낫다. 2차에서 상한 조정이 아니라 S5 전환으로 해결한다.

---

## 8. S5(CF 집계) 전환을 막지 않기 위한 제약

1. **집계는 `aggregateStoreSales` 순수 함수 하나에만 존재한다.** Page / Widget / Provider 어디에도 `totalPrice` 를 더하는 코드를 두지 않는다.
2. **화면은 `StoreSalesEntity` 만 안다.** `OrderEntity` 리스트를 받아 스스로 합산하지 않는다.
3. 전환 시 변경 지점은 **`GetStoreSalesUseCase` 의 데이터 획득부 1곳**이다 — `OrderRepository.getStoreOrdersInPeriod` 호출을 (신설) `SalesAggregateRepository.getSummary(storeId, period)` 로 바꾸고, 요약은 서버 문서에서, 목록은 필요 시 lazy 로 가져온다. **Page / Widget / Provider 시그니처 무변경.**
4. `SalesPeriod` 의 경계 계산을 공유 가능하게 둔다 → CF 가 쓰는 버킷 키(`2026-10-21` / `2026-W43` / `2026-10`)와 1:1 대응되도록 `SalesPeriod.bucketKey` getter 를 **1차에서 미리 넣어 둔다** (1차 화면에서는 안 쓰더라도 포맷을 지금 고정해 두는 편이 싸다).
5. S1(메뉴별) / S2(시간대별) 는 같은 `List<OrderEntity>` 입력에 **집계 함수를 추가**하는 형태로 얹히게, `aggregateStoreSales` 의 시그니처를 `(orders, period) → Summary` 로 좁게 유지한다.

---

## 9. 에러 처리

| 케이스 | 처리 |
|---|---|
| 네트워크 / 알 수 없는 실패 | 리스트 영역 에러 UI + **다시 시도**(`ref.invalidate`) |
| `permission-denied` | `매출을 조회할 권한이 없어요` + 안내문구. 재시도 버튼 없음. 원인: storeId 불일치 또는 매장 소유자 아님 |
| `failed-precondition` (인덱스 누락) | 사용자에겐 일반 에러 UI. `debugPrint` 로 쿼리 조건을 남겨 §6.3 조건부 인덱스 배포로 유도 |
| 매장 미등록 (`store == null`) | empty 안내 + "내 매장" 탭 이동 CTA (에러 아님) |
| 매장 승인 대기 / 반려 | 안내 배너 + 0원 요약 정상 렌더 (차단하지 않음) |
| 주문 0건 | empty 안내 + 0원 요약 (에러 아님) |
| 상한 초과 (`isTruncated`) | 요약 카드에 경고 문구. 숫자는 표시하되 "일부만 집계" 를 명시 |
| `refundInfo == null` 인데 `status == refunded` | `totalPrice` 로 fallback 차감 (§3.3). 데이터 이상이지만 화면은 깨지지 않음 |

---

## 10. 조사 중 발견한 문서/코드 불일치

| # | 내용 | 조치 |
|---|---|---|
| 1 | `backlog.md` S3 가 "PG 응답에 카드사 정보가 저장되고 있는지 미확인" 이라고 적고 있으나, `PaymentInfoEntity` 에 `cardCompany` / `cardNumberMasked` / `easyPayProvider` 가 **이미 저장 중**이다 | S3 선행 조건 충족. backlog 갱신 권장 (이번 작업 비범위) |
| 2 | `docs/processes/role_flows.md:148,215` 및 `:153` 이 매출을 "미구현 (placeholder)" 로 기술 | 본 기능 완료 시 **role_flows.md 갱신 필요** — developer 작업 항목에 포함 |
| 3 | `OrderRemoteDataSource.streamPaidByStore` 는 이름이 `Paid` 지만 실제로는 임의 status 필터를 받는 범용 메서드 | 이번 작업에서 **개명하지 않는다** (주문 접수 탭 회귀 위험). backlog 기술 부채로 기록 권장 |

---

## 11. 작업 분배

### designer — **호출 필요 (필수)**

새 화면 1개 + 신규 UI 요소(기간 세그먼트 / 기간 네비게이터 / 요약 카드 / 주문 행 / 빈 상태 4종)가 추가되므로 `architect_guide.md` 의 "새 화면이 필요한 경우 → designer → developer" 에 해당한다.

산출물: `docs/tasks/owner_sales/design.md`

전달 사항:
- 기존 점주 화면(`OwnerOrdersPage`, `MyStorePage`)과 **같은 톤**을 유지한다. 밝은 캔버스 + 미드나잇 네이비 포인트.
- **요약 카드의 정보 위계**가 이 화면의 전부다: 총 매출(최대) > 주문 건수 / 평균 객단가(보조) > 환불·취소·진행 중(설명용 작은 영역).
- **환불/취소 건이 목록에 섞여 보인다.** 합계에서 빠졌다는 걸 배지와 금액 처리(취소선 또는 muted)로 즉시 알 수 있게 한다.
- **빈 상태를 4종 설계**: 매장 없음 / 승인 대기 배너 / 주문 0건 / 에러(일반·권한). **0원 요약 카드를 숨기지 말고 0으로 렌더**하는 전제.
- `isTruncated` 경고 문구의 자리.
- 상태 배지 색: `completed` / 진행 중 / `refunded` / `cancelled` 4종을 `AppColors` 토큰으로 지정.
- 기간 네비게이터에서 `다음` 이 비활성인 상태(현재 기간)의 표현.
- **차트는 넣지 않는다** (S2, 2차).

### developer — **호출 필요**

구현 항목:
1. Domain Entity 3종 (`sales_period.dart` / `sales_summary_entity.dart` / `store_sales_entity.dart`) + `StoreSalesQuery` 값객체
2. `GetStoreSalesUseCase` + 순수 함수 `aggregateStoreSales`
3. `OrderRepository.getStoreOrdersInPeriod` 추가 + `OrderRepositoryImpl` 구현 + `OrderRemoteDataSource.fetchByStoreInPeriod`
4. `lib/core/constants/` 에 `SalesQueryLimits` 상수
5. `owner/sales/**` Provider / Page / Widget
6. `owner_scaffold.dart` 교체 + `owner_sales_placeholder.dart` **삭제**
7. `docs/processes/role_flows.md` 의 매출 "미구현" 기술 갱신 (§10-2)
8. §6.3 인덱스 실측 검증 결과를 `implementation.md` 에 기록
9. 단위 테스트: `SalesPeriod` 경계(월말/연말/윤년/주 시작/다음 이동 상한) + `aggregateStoreSales`(환불·취소 제외 / 0건 평균 / 진행 중 분기 / `refundInfo` null fallback)

재사용할 기존 구조:
- `myStoreProvider` (`owner/providers/owner_providers.dart`)
- `orderRepositoryProvider` / `orderRemoteDataSourceProvider` (`customer/order/orders/providers/order_di_providers.dart`)
- `OwnerOrderDetailPage(orderId:)` — 주문 행 탭 진입
- `PriceFormatter.formatKrw`, `intl DateFormat`(ko 로케일은 `main.dart` 에서 초기화 완료)
- 로딩 skeleton / 빈 상태 / 에러 UI 패턴 (`owner_orders_page.dart`)

주의할 레이어 규칙:
- `Timestamp` / `cloud_firestore` 는 **data 레이어 안에서만**. `presentation`·`domain` 경계는 `DateTime`.
- `domain` 은 순수 Dart (`flutter/material.dart` import 금지. `@visibleForTesting` 은 `meta` 경유)
- `AppColors` 만. `Color(0x...)` 금지
- 상한·기간 상수는 명명 상수로. 매직 넘버 금지
- **집계 코드를 Widget 에 두지 않는다** (§8-1)
- 기존 `streamPaidByStore` / `streamRefundRequestsByStore` 수정 금지
- top-level provider 선언 (`build()` 안 inline provider 금지 — §1.5 주석 참조)

### tester — **호출 필요**

주요 검증 기준:
- 요약 3지표가 §3.3 집계식과 일치 (수동 계산 대조)
- `refunded` / `cancelled` 가 총 매출에서 제외되고, 보조 지표에는 건수·금액이 **표시**되는지
- `refundRequest` 가 있지만 `status != refunded` 인 주문은 **매출에 포함**되는지 (거절된 요청 포함)
- 기간 경계: 23:59:59 주문과 00:00:00 주문이 각각 **한 기간에만** 집계되는지
- 일 / 주 / 월 전환, 이전·다음 이동, 현재 기간에서 `다음` 비활성, 12개월 상한에서 `이전` 비활성
- 과거 주문을 환불시킨 뒤 **그 주문일 기간**의 매출이 감소하는지 (환불일 기간은 불변)
- 평균 객단가: 0건일 때 `0원`, 나눗셈 버림 확인

반드시 확인할 예외 케이스:
- 매장 미등록 점주 → empty 안내 (에러 아님)
- 매장 `pending` / `rejected` → 안내 배너 + 0원 요약, `permission-denied` 미발생
- 주문 0건 신규 매장의 **첫 진입 화면** (흰 화면 / 에러 화면이 아님)
- 다른 매장의 `storeId` 로 조회 시 `permission-denied` (Rules 검증 — `test_rules/` 하네스에 케이스 추가 검토)
- 탭을 떠났다 돌아왔을 때 (IndexedStack) 데이터·선택 기간 유지 및 비정상 재조회 없음
- `isTruncated` 경고 (상한을 임시로 낮춰 재현)
- 오프라인 / 네트워크 실패 후 **다시 시도** 복구
- `flutter analyze` 0 경고, `grep -rl "package:firebase_\|package:cloud_firestore" lib/presentation/ lib/domain/` → **0건**

---

## 12. 사용자 확인이 필요한 결정사항 — **전건 확정 (2026-10-21)**

**D1 ~ D7 모두 추천안 그대로 확정됐다.**
D1(진행 중 주문 포함) · D2(환불 주문일 기준 차감) · D4(KST 고정)는 점주가 보는 숫자가 달라지는 항목이라 **사용자에게 직접 확인**했다.
D3 · D5 · D6 · D7 은 근거가 명확해 추천안을 수용했다 (미질의).

| # | 확정 | 확정 방식 |
|---|---|---|
| D1 | 진행 중 주문 **포함** (결제 성공 전체) + 진행 중 보조 지표 분리 | 사용자 직접 확인 |
| D2 | 환불 **주문일(`createdAt`) 기준** 차감 + `환불 제외 n건 / -N원` 상시 노출 | 사용자 직접 확인 |
| D3 | 주 시작 **월요일** | 수용 |
| D4 | 기간 경계 **KST(UTC+9) 고정** | 사용자 직접 확인 |
| D5 | 단일 쿼리 **1,000건** + 과거 **12개월**, 상한 도달 시 `isTruncated` 경고 | 수용 |
| D6 | `get()` 1회 + pull-to-refresh (stream 미사용) | 수용 |
| D7 | 페이지네이션 없음 (`ListView.builder` lazy 렌더) | 수용 |

아래는 확정 전 architect 가 제시한 원문이다.

---

### (원문) 결정사항과 선택지

> 각 항목에 추천안이 있다. 별도 지시가 없으면 **추천안으로 확정**하고 `design.md` / 구현에 반영한다.

| # | 결정 | 선택지 | 추천 | 사유 |
|---|---|---|---|---|
| **D1** | 총 매출에 **진행 중 주문**(`paid`/`accepted`/`making`/`ready`)을 포함할지 | (A) `completed` 만 — 확정 매출<br>(B) **결제 성공 전체(진행 중 포함)** | **(B)** | 점주가 매출 탭을 보는 가장 흔한 순간은 "오늘 장사 얼마 했나" 다. (A) 면 영업 중 매출이 계속 과소 표시되고, 픽업 완료 터치를 깜빡한 주문이 매출에서 영구 누락된다. (B) 로 하고 **`진행 중 n건 / N원` 을 보조 지표로 분리 표시**해 확정분과 구분한다 |
| **D2** | 환불 차감 시점 기준 | (A) **주문일(`createdAt`) 기준**<br>(B) 환불일(`refundedAt`) 기준 | **(A)** | §3.2 — 단일 쿼리로 요약·목록이 일관되고, 과거 기간 숫자가 재현되며, S5 전환과 호환. (B) 는 쿼리 2회 + 목록/요약 대상 집합 불일치 |
| **D3** | 주(週) 시작 요일 | (A) **월요일**<br>(B) 일요일 | **(A)** | 한국 주간 영업 집계 관행 + ISO 8601. S5 의 주 버킷 키(`2026-W43`)와도 일치 |
| **D4** | 기간 경계 타임존 | (A) **디바이스 로컬 타임존**<br>(B) KST(UTC+9) 고정 | **(B)** | 사업 지역이 한국 단일이고 KST 는 DST 가 없다. (A) 면 점주가 해외에서 앱을 열었을 때 "오늘" 경계가 밀려 숫자가 바뀐다. 다만 (B) 는 data 레이어에 UTC+9 정규화가 추가되므로 (A) 보다 구현이 조금 늘어난다. **구현 부담을 최소화하려면 (A) 도 현실적으로 무해** — 사용자 판단 요청 |
| **D5** | 조회 가능 기간 상한 | (A) 상한 없음<br>(B) **단일 쿼리 1,000건 + 과거 12개월** | **(B)** | §7.2 |
| **D6** | 실시간 반영 방식 | (A) `snapshots()` 실시간 stream<br>(B) **`get()` 1회 + pull-to-refresh**<br>(C) 당일만 stream, 과거는 get | **(B)** | 매출은 초 단위 실시간이 필요한 화면이 아니다(실시간 주문 관리는 "주문 접수" 탭의 역할). stream 은 기간 내 주문이 전이될 때마다 리스너가 재발화해 월 조회에서 읽기 비용이 예측 불가해진다. (C) 는 분기 2개를 유지해야 해 1차 범위에 과하다 |
| **D7** | 주문 목록 페이지네이션 | (A) **없음 — 상한 내 전량 렌더(`ListView.builder`)**<br>(B) 무한 스크롤 | **(A)** | 집계를 위해 어차피 전량을 받아야 한다. `ListView.builder` 면 렌더는 lazy 라 1,000건도 충분. 페이지네이션은 집계 완전성과 상충 |

---

## 13. 완료 기준

- [ ] `owner_scaffold.dart` 의 매출 탭이 `OwnerSalesPage` 를 가리키고, `owner_sales_placeholder.dart` 가 삭제됐다
- [ ] F1~F9 가 모두 구현 또는 보류 사유 명시됨
- [ ] 집계 로직이 `aggregateStoreSales` 순수 함수 1곳에만 존재한다 (§8-1 — tester 가 grep 으로 확인)
- [ ] `StoreSalesEntity` 경계가 지켜져 화면이 `OrderEntity` 합산을 하지 않는다
- [ ] Cloud Functions 변경 0건, `firestore.rules` 변경 0건
- [ ] 인덱스 필요 여부가 실측으로 판정되어 `implementation.md` 에 기록됨 (필요 시 배포 작업으로 분류)
- [ ] `SalesPeriod` 경계 + `aggregateStoreSales` 단위 테스트 통과
- [ ] `flutter analyze` 0 경고 / `flutter test` 통과
- [ ] `presentation`·`domain` 에 Firebase import 0건
- [ ] `docs/processes/role_flows.md` 의 매출 "미구현" 기술 갱신
- [ ] `design.md` / `implementation.md` / `test_report.md` 작성 완료
- [ ] FAIL 항목 없음 또는 후속 작업으로 분리
