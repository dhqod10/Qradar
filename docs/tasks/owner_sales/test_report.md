# 점주 매출 조회 (owner_sales) 테스트 리포트

- 검증 방식: **정적 검증** (코드 리딩 + 단위 테스트 추가 실행 + Riverpod 의미 확인용 임시 스크립트). 에뮬레이터 라이브 검증은 사용자가 수행 (§L)
- 검증일: 2026-10-22
- 기준: `spec.md` §12 (D1~D7), `design.md` (+ 맨 끝 "잔여 결정 확정" R1~R4), `implementation.md`

## 요약

| 구분 | 개수 |
|---|---|
| PASS | 21 |
| FAIL | **2** (P1 1건, P2 1건) |
| 보류 (라이브 예정) | 14 (§L) |
| 시나리오 결함 | 4 (§M) |

**먼저 고칠 것: F1 (오프라인 `get()` 이 캐시를 에러 없이 반환 → 조용히 틀린 숫자).** 이 결함 때문에 implementation.md 의 라이브 항목 "네트워크 차단 후 새로고침 → SnackBar" 는 현 코드에서 기대 결과가 나오지 않는다 (§M-1).

사용자가 이미 확인한 항목(analyze / test 71 / Firebase import 0 / `Color(0x` 0 / 인덱스 배포 / CF·Rules 변경 0)은 중복 검증하지 않았다. 단, 단위 테스트는 타임존 의존 여부를 보려고 `TZ` 를 바꿔 **추가 실행**했다 (K2).

---

## FAIL

### F1 (P1) 오프라인/불안정 네트워크에서 `get()` 이 캐시를 반환해 0원·부분 합계가 에러 없이 표시될 수 있음

- 위치: `lib/data/datasources/remote/order_remote_data_source.dart` `fetchByStoreInPeriod` 의 `.get()` (옵션 없음)
- 근거: `cloud_firestore` 모바일 SDK 는 영속성이 기본 ON 이다 (`main.dart` 에 `Settings` 변경 없음). `Query.get()` 의 기본 `Source.serverAndCache` 는 서버에 닿지 못하면 **예외 대신 로컬 캐시 결과**를 돌려준다. 쿼리는 문서 단건과 달리 캐시가 비어 있어도 에러가 아니라 **빈 스냅샷**이 반환된다. 캐시에는 점주 주문 화면 stream 이 받아 둔 일부 주문만 있을 수 있어, 범위 쿼리가 **일부 주문만의 합계** 또는 **0건** 이 될 수 있다.
- 영향: design "에러 시 0원 요약 금지 (조용히 틀린 숫자)" 원칙 위반 경로. 오프라인 상태의 새로고침도 SnackBar 없이 성공처럼 보인다.
- 수정 제안 (코드는 수정하지 않음): `.get(const GetOptions(source: Source.server))`. 오프라인이면 `unavailable` 예외가 되어 기존 에러 UI / 새로고침 실패 SnackBar 경로를 탄다. 대안은 `snap.metadata.isFromCache` 가 true 면 예외를 던지는 것.
- 확인 방법 (라이브): Mac Wi-Fi 를 끈 상태로 매출 탭 pull-to-refresh. 에러/SnackBar 가 안 뜨고 숫자만 바뀌거나 0원이 되면 재현.

### F2 (P2) 에러 화면에서 "다시 시도" 를 누르면 skeleton 이 아니라 에러 블록이 유지됨

- 위치: `owner_sales_page.dart` `_SalesBody.build` 의 분기 순서 `sales != null` → `async.hasError` → skeleton
- 근거 (실측): Riverpod 3.3 에서 에러 상태 provider 를 `invalidate` 하면 `AsyncLoading` 이지만 **이전 에러를 들고 있어 `hasError == true`** 다 (임시 스크립트로 확인: `isLoading=true hasValue=false hasError=true`). 따라서 `hasError` 분기가 `isLoading` 보다 먼저 평가되면 재시도 중에도 에러 블록이 그대로 보인다.
- 영향: design "다시 시도 탭 → `ref.invalidate` → 본문 skeleton" 위반. 버튼을 눌러도 아무 반응이 없는 것처럼 보여 연타 가능.
- 수정 제안: 분기를 `async.isLoading` → skeleton, 그다음 `hasError` 로 바꾸되 **값이 있는 refresh(`isRefreshing`)는 data 유지** 순서를 보존할 것 (`sales != null` 이 항상 먼저).
- 재현: 인덱스 미배포 등으로 에러를 만든 뒤 "다시 시도". 또는 §L-9.

---

## PASS 상세

### ① 카피 문자열 — PASS (C1)
design "정확한 카피 문자열" 표의 **37개 문자열** 전부를 `lib/presentation/owner/sales`, `order_status_badge.dart` 에 대해 글자 단위 `grep -F` 로 대조했다. 누락·오탈자 0건.
- 3행 라벨 `진행 중 포함` / `환불 제외` / `취소 제외`, 배지 `완료` / `진행 중` / `환불 완료` / `취소됨`
- 배너 3변형 제목·본문 6문자열, `새로고침에 실패했어요`, 권한 에러 2문자열, 매장 정보 에러 3문자열
- truncated 경고·목록 각주는 `SalesFormatters` 가 `NumberFormat('#,###')` 로 `SalesQueryLimits.maxDocumentsPerQuery` 를 포맷해 `1,000` 생성 (숫자 하드코딩 없음) → 두 문장 모두 일치
- plate 값 `{n}건 · {금액}` (가운뎃점 U+00B7), 환불 `-12,000원` 은 `formatKrw(-amount)` 로 생성

### ② 확정 사항 — PASS (C2~C7)
| ID | 항목 | 결과 | 근거 |
|---|---|---|---|
| C2 | plate 3행 0건에도 상시 | PASS | `_BreakdownPlate` 의 3개 `_BreakdownRow` 는 무조건 렌더. 조건부인 것은 환불 **각주**뿐 (`refundedCount > 0`, design 허용). 0건은 `0건` + muted |
| C3 | 환불에 error 색 없음 | PASS | 환불 행·값·아이콘 `textBody`/`textMuted`, 목록 환불 금액 `textMuted` + 취소선. `error` 사용처는 취소 배지(기존 `OrderStatusBadge` 규칙), 반려 배너, 에러 아이콘뿐 (design 허용) |
| C4 | 진행 중 배지 글자 `primary` | PASS | `sales_status_badge.dart` 글자 `AppColors.primary`, 배경 `primaryBright` 15% |
| C5 | 주차 목요일 소속 | PASS | `thursdayWall` + `weekOfMonth = (day-1)~/7+1`. 단위 테스트가 10/21→`10월 4주차`, 9/28~10/4→`10월 1주차`, 연초·연말·윤년 포함 |
| C6 | D1~D7 | PASS | D1 진행 중 포함(+보조 분리) / D2 쿼리가 `createdAt` 범위만 사용, 환불 각주 / D3 월요일 / D4 KST / D5 limit 1000 + `maxMonthsBack` 12 + `isTruncated` / D6 `get()` 1회 + RefreshIndicator, stream 없음 / D7 페이지네이션 없음 |
| C7 | R2·R3·R4 | PASS | 라벨 유지, 배너 3변형(`pending && approvedAt != null` = 수정 검토), 세그먼트 재탭 무시(`selectType` 에서 `state.type == type` 이면 return) |

참고 (비차단): D7 문서는 `ListView.builder` 인데 구현은 `ListView(children: [... for ...])` 다. 위젯 객체는 일괄 생성되지만 build/layout 은 sliver 가 lazy 로 처리하므로 1,000건에서도 실사용 문제는 없다. 라이브에서 1,000건 스크롤 버벅임이 보이면 builder 로 전환.

### ③ 집계 단일 지점 — PASS (S1)
- `+=` 형태로 `totalPrice` 를 누적하는 코드: `aggregateStoreSales` 1곳 (`get_store_sales_use_case.dart:58/64/67`). `fold`/`reduce`/`sum` 은 owner 프레젠테이션·유스케이스에 0건.
- 위젯의 `totalPrice` 는 `sales_order_tile.dart:29` 행 표시 1곳, `orders.length` 는 건수 표시만.
- S5 전환 시 바꿀 지점: **`GetStoreSalesUseCase.call` 1곳** (repo 호출 + `aggregateStoreSales` → CF 집계 문서 읽기로 교체). provider(`storeSalesProvider`)와 화면은 `StoreSalesEntity` 만 소비하므로 무수정. 단 목록(`orders`)은 S5 후에도 별도 조회가 필요하다는 점은 S5 설계 때 고려 (현재 Entity 경계는 그대로 유지 가능).

### ④ 에러 vs 0원 / 새로고침 — 부분 PASS (E1~E3 PASS, F1·F2 FAIL)
Riverpod 3.3 동작은 정적 판독이 아니라 임시 Dart 스크립트(`FutureProvider.autoDispose.family`)로 실측했다.
| 상황 | 실측 | 코드 반응 | 결과 |
|---|---|---|---|
| E1 첫 로드 에러 (값 없음) | `hasValue=false hasError=true` | `sales == null` → 에러 블록. 요약 카드 미렌더 | PASS |
| E2 값 있는 상태에서 refresh 실패 | `hasError=true hasValue=true value=기존값` | `async.value` 로 data 유지 + SnackBar | PASS |
| E2' refresh 진행 중 | `isLoading=true hasValue=true value=기존값` | skeleton 으로 안 바뀜 | PASS |
| E3 값 없는 에러에서 pull-to-refresh 재실패 | `hadValue=false` | SnackBar 미표시, 에러 블록 유지 | PASS |
| 에러 → "다시 시도" | `isLoading=true hasError=true hasValue=false` | 에러 블록 유지 | **F2** |
| 오프라인 | (SDK 가 캐시 반환) | 에러 자체가 안 남 | **F1** |

### ⑤ 기간 전환 vs refresh — PASS (P1, P2)
- 새 키(`StoreSalesQuery(storeId, period)` 가 freezed 값 동등성)는 별도 provider 인스턴스라 `hasValue=false, isLoading=true` (실측) → `sales == null`, `hasError == false` → skeleton. 이전 기간 숫자 잔존 불가.
- 같은 키는 `ref.refresh(...future)` 에서만 이전 값 유지 (실측). 기간 전환 경로에 `skipLoadingOnReload` 류 설정 없음.
- autoDispose 로 기간을 오가면 재조회한다 (implementation.md 에 명시된 의도된 비용).

### ⑥ KST 변환 지점 — PASS (K1, K2)
- `Kst` 를 import 하는 파일은 `lib/core/utils/kst.dart`(정의), `sales_period.dart`(경계 계산), `sales_formatters.dart`(표시) **3개**. 요청하신 "`Kst` 와 `SalesFormatters` 두 곳" 에 더해 `SalesPeriod` 가 `Kst` 를 호출하지만, 이는 경계 계산을 `SalesPeriod` 한 곳에 집중시키라는 spec §3.4 와 일치하고 변환 자체는 모두 `Kst` 의 `toWall`/`fromWall` 로만 일어난다. 위젯·provider·data 레이어에 변환 없음.
- `DateTime.now()` 는 `SalesPeriod.current/isCurrent/canGoNext/canGoPrevious` 기본값과 `periodTitle`(올해 판정)뿐이며 모두 **instant** 를 `Kst` 로 넘기므로 디바이스 타임존과 무관. `toLocal`, `timeZoneOffset`, `DateFormat` 사용 0건 (수동 포맷).
- 추가 실행: `TZ=America/Los_Angeles` (37 통과), `TZ=Pacific/Auckland` (sales_period + formatters 32 통과). 타임존 의존 숨은 버그 없음.
- data: `Timestamp.fromDate(startInclusive/endExclusive)` 는 UTC instant 그대로 전달, `>=` / `<` 반열린 구간.

### ⑦ Rules 함정 — PASS (R1)
`fetchByStoreInPeriod` 에 `where('storeId', isEqualTo: storeId)` 존재 (소스 주석에 "제거 시 permission-denied" 명시). 권한 에러는 `PermissionDeniedException` 으로 변환되어 presentation 은 Firebase 를 import 하지 않고 권한 전용 UI 로 분기한다. 인덱스 `(storeId ASC, createdAt DESC, __name__ DESC)` 는 쿼리 형태(equality + range + orderBy createdAt desc)와 일치.

### ⑧ 단위 테스트 품질 — PASS(권고 있음) (T1)
37건 = aggregate 5 + SalesPeriod 20 + formatters 12. 경계 커버 현황:

| 영역 | 덮인 경계 |
|---|---|
| 일/주/월 경계 | KST 23:59 / 00:00, UTC 15:00=KST 익일, 윤년 2/29, 연말, 일요일→직전 월요일, 월요일 00:00=새 주, 연·월 걸친 주, 윤년 2월 일수, `next().previous()==self` |
| bucketKey | day/month, W43, 연초 W01, 연말 W53 |
| 이동 | 현재 기간 `canGoNext` 불가, 자정 직전/직후, 월 단위 12개월 한도(12스텝), 일 단위 한도 경계 |
| 집계 | 0건, 7상태 혼합, `~/` 버림, `refundInfo.amount`/`totalPrice` fallback, `refundRequest`/거절 포함 |
| 포맷 | 목요일 규칙·월 경계 부제·연초/연말/윤년·작년 연도·KST 올해 판정·행 시각 KST |

**공백 (모두 FAIL 은 아니고 보강 권고)**
1. **`isTruncated` 경계 미테스트**: `GetStoreSalesUseCase` 는 fake repo 로 999/1000/1001건 테스트가 없다. 현재 `orders.length >= limit` 이라 **정확히 1,000건**이어도 경고가 뜬다 (오탐). `limit + 1` 조회 후 `> limit` 판정으로 바꾸거나 오탐을 문서화할 것 (P3).
2. **주·월 단위 `canGoNext` / `canGoPrevious`** 미테스트 (일·월 한도만). 주 단위 12개월 경계가 "겹치는 기간까지" 허용되는 동작이 테스트로 고정돼 있지 않다.
3. **`SalesFormatters.menuSummary`** (`×n`, `외 N개`, `항목 없음`), `periodSemanticLabel`, `SalesStatusBadge.labelOf` 4종 매핑 미테스트. 카피 회귀 방지용으로 값싼 테스트다.
4. **화면 계약 테스트 0건**: "3행 상시 표시", "환불 error 색 없음", "에러 시 요약 카드 없음", "refresh 값 유지 / 새 키 skeleton" 은 위젯/provider 테스트가 없어 이번 검증의 ④⑤ 는 일회성 스크립트로만 확인됐다. provider 테스트(fake `OrderRepository` 로 실패 주입) 1~2건이면 F2 같은 회귀도 잡힌다.
5. 밀리초 경계(23:59:59.999)는 `previous()` 의 `-1ms` 로 간접 검증될 뿐 직접 단언이 없다 (낮음).

### ⑨ 절대 규칙 / 아키텍처 — PASS (A1~A3, L1)
- A1 의존 방향: domain 은 `core` 만 import, data 가 `PermissionDeniedException` 변환, presentation 은 domain/core 만 사용. `orderRepositoryProvider` import 경로(`customer/order/.../order_di_providers.dart`)는 기존 owner 화면(`owner_orders_page`, `owner_order_detail_page`)과 동일한 선례.
- A2 `AppColors` 외 색 0건, `Colors.*` 는 `transparent` 만. 신규 토큰 0.
- A3 범위: 수정 파일은 implementation.md 목록과 일치. `streamPaidByStore` 등 기존 메서드 미변경. CF·`firestore.rules` 변경 0. 문서 변경은 spec §11 이 지시한 `role_flows.md` 와 backlog S6 기록.
- L1 `entity_lifecycle.md`: status 전이 로직 변경 없음(읽기 전용). `data_ownership.md`: 신규 쓰기 경로 없음, `orders` 점주 read 경로가 기존 Rules(`isStoreOwner(resource.data.storeId)`)와 일치 → silent drift 없음.

---

## Rules 하네스 케이스 제안 (필요 여부: **필요, P2**)

Rules 는 바뀌지 않았지만 매출 쿼리는 "`storeId ==` 가 빠지면 즉시 permission-denied" 라는 **클라이언트-Rules 사이 암묵 계약**에 기댄다. 다른 사람이 쿼리를 "정리" 하다 빠뜨리면 라이브에서만 드러나므로 하네스에 고정할 가치가 있다. 현 `rules.test.mjs` 는 `users` 케이스 12건뿐이고 `orders`/`stores` 시드가 없다.

시드 (`withSecurityRulesDisabled`): `stores/S_A {ownerId: OWNER, status:'approved'}`, `stores/S_B {ownerId: 'other-owner'}`, `stores/S_P {ownerId: OWNER, status:'pending'}`, `orders/o_a1 {storeId:'S_A', userId: CUSTOMER, status:'completed', totalPrice:1000, createdAt: Timestamp}`, `orders/o_b1 {storeId:'S_B', userId:'someone'}`.
쿼리는 앱과 동일하게: `query(collection(db,'orders'), where('storeId','==',X), where('createdAt','>=',t0), where('createdAt','<',t1), orderBy('createdAt','desc'), limit(1000))` + `assertSucceeds/assertFails(getDocs(q))`.

| # | 시나리오 | 기대 |
|---|---|---|
| R13 | OWNER 가 `storeId == S_A` 기간 쿼리 | allow |
| R14 | OWNER 가 `storeId == S_B` (타 매장) 기간 쿼리 | **deny** |
| R15 | OWNER 가 `storeId` 조건 **없이** `createdAt` 범위만 쿼리 | **deny** (함정 재현) |
| R16 | CUSTOMER 가 `storeId == S_A` 기간 쿼리 | deny (주문자 분기는 `userId` 필터 없이는 증명 불가) |
| R17 | OWNER 가 `pending` 매장 `S_P` 기간 쿼리 | allow (spec: 승인 대기 매장도 permission-denied 없어야 함) |
| R18 | 비로그인 `storeId == S_A` 쿼리 | deny |

한계: 에뮬레이터는 복합 인덱스를 강제하지 않으므로 인덱스 누락(F-precondition)은 이 하네스로 못 잡는다 (배포 확인으로 대체됨).
README 케이스 표와 "12건" 문구도 함께 갱신해야 한다.

---

## L. 보류 (라이브 예정) — 실행 가능성 감사

전제: 점주 계정 = iOS Simulator. FCM 불필요. 아래 **Console 작업은 사용자 몫**이다. 모든 데이터 세팅은 Firestore Console 의 문서 편집/추가(= Rules 우회)로 가능하고, 앱 내 결제 플로우는 필요 없다.

공통 사전 준비:
- 테스트 대상 점주 매장의 `stores/{storeId}` 문서 ID 를 확인한다. 새 주문 문서는 기존 주문(`orders/{기존id}`)의 **"문서 복제"** 후 필드만 바꾸는 방식이 가장 안전하다. 복제 필수 확인 필드: `storeId`(= 대상 매장), `userId`, `items`(menuItemName/quantity), `totalPrice`(**집계는 `subtotal` 이 아니라 `totalPrice`**), `status`, `createdAt`(Timestamp).
- Console 의 Timestamp 편집기는 **브라우저 로컬 타임존**으로 입력된다. Mac 이 KST 면 입력값이 곧 KST 시각이다. KST 가 아니면 UTC 로 환산해 입력한다 (예: KST 23:59:59 = 전날 14:59:59 UTC).
- 테스트용 주문에는 `storeName` 에 `[TEST]` 같은 표식을 두면 정리가 쉽다. **끝나면 복제 문서 삭제 및 원본 필드 복구.**
- 환불 행: `status: refunded` + `refundInfo` 맵 `{cancellationKey:'t', reason:'t', approvedBy:'owner', processedAt:<Timestamp>, amount:<totalPrice 와 같은 숫자>}`. **`amount` 를 빼면 모델 기본값 0 이 되어 환불 금액이 0원으로 보인다** (코드의 `?? totalPrice` fallback 은 `refundInfo` 자체가 없을 때만 작동. 실제 `processRefund` CF 는 항상 `amount` 를 쓰므로 운영 데이터 문제는 아님).
- 취소 행: `status: cancelled` (금액 표시는 없고 건수만 집계).

| # | 시나리오 | 세팅 (Console) | 기대 | 실행 가능 |
|---|---|---|---|---|
| L-1 | 요약/목록 기본 | 오늘 KST 로 `completed` 2건(예 4,500 / 5,500), `paid`·`accepted`·`making`·`ready` 중 2건(3,000 / 2,000) | 총 매출 15,000원, 주문 건수 4건, 평균 3,750원, `진행 중 포함 2건 · 5,000원` | 가능 |
| L-2 | 환불/취소 제외 + 목록 표기 | 같은 날 `refunded` 1건(6,000, amount 6,000), `cancelled` 1건 | 총 매출 불변, `환불 제외 1건 · -6,000원`, `취소 제외 1건`, 각주 노출, 두 행 취소선 + `환불 완료`/`취소됨` 배지 | 가능 |
| L-3 | 0건에도 3행 상시 | 주문이 없는 과거 날짜/주로 이동 | 총 매출 0원 + plate 3행 모두 `0건`(muted) + `이 기간에 주문이 없어요` | 가능 (별도 계정 불필요) |
| L-4 | KST 경계 (23:59:59 vs 00:00:00) | 주문 A `createdAt` = 어제 KST 23:59:59, 주문 B = 오늘 KST 00:00:00 | A 는 어제 일 단위에만, B 는 오늘 일 단위에만. 주 단위에서는 둘 다 같은 주(둘이 월요일 경계가 아닐 때) | 가능. 월요일 경계(일요일 23:59:59 ↔ 월요일 00:00:00)를 쓰면 주 단위 분리도 확인 |
| L-5 | 일/주/월 전환 skeleton | 위 데이터 유지 | 단위 전환·이전/다음 시 이전 숫자 잔존 없이 skeleton 후 새 값 | 가능. 눈으로 확인하기 짧으니 스크린 녹화 권장 |
| L-6 | 이전/다음 비활성 | 데이터 불필요 | 현재 기간에서 `›` 비활성, 월 단위로 12번 이전 이동 후 `‹` 비활성 | 가능 |
| L-7 | pull-to-refresh 값 갱신 + 유지 | 매출 탭을 연 채로 Console 에서 주문 `totalPrice`/`status` 변경 | 당기는 동안 기존 숫자 유지 → 완료 후 갱신. 당기기 전에는 **자동 갱신되지 않음** | 가능 |
| L-8 | S6 체감 확인 ("오래된 숫자") | 매출 탭을 연 채 다른 탭 이동 → Console 에서 신규 주문 추가(`createdAt` = 지금) → 매출 탭 복귀 | 자동으로 안 바뀌는지 확인하고 "모르고 보는 문제가 체감되는지" 판단 | 가능 |
| L-9 | 에러 → 다시 시도 (F2 재현) | 가장 단순한 방법: 시뮬레이터에서 에러를 만들 수단이 없으므로 **F1 수정 후** Wi-Fi 끄기로 대체, 또는 일회성으로 datasource 에 `throw` 삽입 | 재시도 탭 시 skeleton 으로 바뀌어야 함 (현재 FAIL 예상) | 조건부 (§M-1, §M-3 참고) |
| L-10 | 배너 3변형 | `stores/{id}.status` 를 `pending` + `approvedAt` 필드 **삭제** / `pending` + `approvedAt` **유지** / `rejected` 로 차례로 변경 | 각각 `매장 승인을 기다리고 있어요` / `수정한 내용을 검토하고 있어요` / `매장 검토가 반려되었어요`. 요약 카드는 항상 함께 표시, 배너 탭 → 내 매장 탭 | 가능. **`approvedAt` 삭제 전 값을 메모해 복구**. 상태 변경 중에는 주문 접수 탭 동작도 달라질 수 있으니 끝나면 `approved` 로 복구 |
| L-11 | 매장 미등록 | 일회성: `stores/{id}.ownerId` 를 임시로 다른 값으로 변경 → 앱에서 `myStoreProvider` stream 이 null 로 | `등록된 매장이 없어요` + CTA. 헤더 숨김. 에러 아님 | 가능하나 침습적(복구 필수). 대안: owner 역할만 있고 매장 없는 신규 계정 로그인 |
| L-12 | 행 탭 → 주문 상세 → 복귀 | 데이터 불필요 | 상세 진입, 뒤로 가면 선택 기간·스크롤 유지. 상세에서 상태를 바꿔도 목록은 pull 전까지 stale (design 에 의도 명시) | 가능 |
| L-13 | truncated 경고 | 코드 임시 수정 필요 (§M-2) | 경고 pill + 목록 끝 각주 | 조건부 |
| L-14 | 큰 글꼴(1.5x)·세로 겹침 | 데이터 불필요. iOS 설정 > 손쉬운 사용 > 글자 크기 | 총 매출 축소, 행 겹침 없음 | 가능 |

---

## M. 시나리오 결함 (FAIL 아님)

implementation.md "테스트 포인트 > 라이브" 의 아래 항목은 **현재 문서 그대로는 기대 결과가 나오지 않거나 실행 방법이 빠져 있다.** 직전 작업(`notification_permission_retry` §L)처럼 환경 제약으로 보류되지 않도록 대안을 붙인다.

1. **"네트워크 차단 후 새로고침 → SnackBar + 내용 유지"**
   - 결함: F1 때문에 오프라인 `get()` 이 예외 없이 캐시를 돌려줘 SnackBar 가 뜨지 않는다. 또한 iOS Simulator 는 호스트 네트워크를 쓰므로 "차단" 수단이 Mac Wi-Fi 끄기 / Network Link Conditioner 뿐이다 (Simulator 단독 에어플레인 모드 없음).
   - 대안: ① **F1 수정(Source.server) 후** Mac Wi-Fi 를 끄고 L-7 수행 → SnackBar + 기존 숫자 유지 확인. ② 수정 전에는 이 시나리오를 "F1 재현용" 으로 쓴다 (기대 = 에러가 안 뜨는 것이 문제). ③ 네트워크 없이 확인하려면 datasource 에 일회성 `throw Exception()` 을 넣고 핫 리스타트 (확인 후 되돌림).
2. **"truncated 는 `maxDocumentsPerQuery` 를 임시로 낮춰 재현"**
   - 결함: 낮춘 값 이상의 주문이 있어야 하고, `static const` 라 **핫 리로드로는 반영되지 않는다 (핫 리스타트 필요)**. 구체 값이 없다.
   - 대안: 값을 `3` 으로 낮추고 같은 기간에 주문 3건 이상(L-1/L-2 데이터로 충분)을 두고 **핫 리스타트**. 확인 후 반드시 `1000` 으로 복구하고 `git diff` 로 잔여 변경이 없는지 확인. 정확히 3건일 때도 경고가 뜨는 것(오탐, §⑧-1)이 보이면 정상 재현.
3. **"디바이스 타임존을 KST 가 아닌 곳으로 바꿔 경계/시각 확인"**
   - 결함: iOS Simulator 는 타임존을 호스트 macOS 설정에 따르며 시뮬레이터 단독 변경이 불가능하다. 바꾸려면 Mac 시스템 설정을 변경해야 해 비용·부작용이 크다.
   - 대안: 이미 정적 검증에서 `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` 로 단위 테스트를 실행해 통과했고, 모든 변환이 `Kst` 로 일원화돼 있다 (K1·K2). 라이브는 **선택 사항**으로 낮추고, 하고 싶다면 Mac 날짜/시간 설정에서 타임존을 일시 변경한 뒤 앱을 **재시작**해 L-4 를 반복한다.
4. **"타 매장 storeId 접근 시 permission-denied"**
   - 결함: 앱 UI 에는 타 매장 ID 를 넣을 경로가 없어 라이브로 만들 수 없다. 권한 에러 화면(`매출을 조회할 권한이 없어요`) 도 자연 발생이 불가능하다.
   - 대안: Rules 동작은 위 **하네스 R14/R15** 로 검증하고, 권한 에러 **UI 만** 보고 싶다면 datasource 에 일회성 `throw const PermissionDeniedException()` 을 넣고 핫 리스타트해 화면 확인(재시도 버튼 없음) 후 되돌린다.

보조 지적:
- implementation.md 는 "신규 매장(0건)·pending·rejected" 를 별도 계정 전제처럼 적었으나, L-3·L-10 처럼 **기존 계정 + Console 편집**으로 충분하다. 새 계정은 필수가 아니다.
- "환불/취소 행" 시나리오는 데이터를 앱 플로우(고객 환불 요청 → 점주 승인)로 만들려면 고객 계정/결제 환경이 필요하다. Console 세팅(L-2)이 유일하게 확실한 방법이다. (`processRefund` 는 mock 모드가 있으나 고객 기기 접근이 필요해 권장하지 않음.)

---

## 후속 / 권고 요약

| 우선 | 항목 |
|---|---|
| P1 | F1 `Source.server` 적용 (또는 `isFromCache` 검사) |
| P2 | F2 `isLoading` 분기를 `hasError` 앞에 배치 |
| P2 | Rules 하네스 R13~R18 추가 |
| P3 | `isTruncated` 오탐(정확히 1,000건) 처리 + use case 단위 테스트 |
| P3 | provider 테스트(새 키 skeleton / refresh 유지 / 에러 재시도), 주·월 `canGoPrevious/Next`, `menuSummary`/`labelOf` 테스트 |
| P3 | 앱을 자정 넘겨 켜 둔 경우 `salesPeriodProvider` 의 "오늘" stale (implementation.md 기재된 알려진 한계, S6 와 묶어 2차) |

---

## Z. FAIL 2건 처리 + 라이브 검증 결과 (2026-10-22)

### Z-1. F1 — 오프라인 캐시 fallback → **수정 완료**

`fetchByStoreInPeriod` 의 `.get()` 이 옵션 없이 호출돼, 서버에 닿지 못하면 예외 없이 **로컬 캐시**를 반환했다. 캐시가 비면 0원, 일부만 있으면 축소된 금액이 정상 수치처럼 보인다. 매출 화면에서 이는 조용히 틀린 숫자를 보여주는 것이다.

```dart
// 매출 집계는 캐시 결과를 쓰면 안 된다.
// 기본 `get()` 은 서버에 닿지 못하면 예외 없이 로컬 캐시를 돌려주는데,
// 캐시가 비었으면 0원, 일부만 있으면 축소된 금액이 "정상 수치"처럼 보인다.
// 틀린 숫자를 조용히 보여주느니 에러를 띄운다 ("0원" 과 "모름" 은 다르다).
.get(const GetOptions(source: Source.server));
```

`Source.server` 는 캐시 fallback 자체를 제거한다. 오프라인이면 예외가 나고 에러 화면으로 간다 — 매출 화면에서는 이것이 올바른 동작이다.

### Z-2. F2 — 재시도 시 skeleton 미표시 → **수정 완료**

Riverpod 에서 에러 상태를 `invalidate` 하면 `isLoading` 과 `hasError` 가 **동시에 true** 다. 페이지 분기가 `hasError` 를 먼저 보고 있어 "다시 시도" 를 눌러도 에러 블록이 남았다.

`isLoading` 분기를 `hasError` **앞으로** 옮겼다. 값이 있는 refresh 는 `sales != null` 분기가 먼저 걸리므로 기존 동작(data 유지)은 그대로다.

수정 후 `flutter analyze` No issues found / `flutter test` 71 passed 재확인.

### Z-3. 라이브 검증 결과

환경: iOS Simulator iPhone 17 / 점주 계정 / 개인매장. 인덱스 배포 후 수행.

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| L-A | 인덱스 배포 전 동작 | **PASS** | `불러오는 데 실패했어요` + `다시 시도`. **0원 요약으로 대체하지 않음**. data 레이어가 쿼리 형태와 함께 로그 출력 |
| L-B | **KST 경계 (D4)** | **PASS** | 실제 쿼리 로그 `createdAt >= 1792594800`, `< 1792681200` = **2026-10-22 00:00:00 ~ 10-23 00:00:00 KST**, 범위 정확히 86,400초 |
| L-C | **Rules 함정 회피** | **PASS** | 쿼리 로그에 `storeId==TRdrkidlroX7HuONtuay` 포함, permission-denied 없음 |
| L-D | **D5 상한** | **PASS** | 쿼리 로그 `l:1000` |
| L-E | 0건 기간 (오늘) | **PASS** | 0원 요약 **정상 렌더** + `이 기간에 주문이 없어요`. 3행 전부 0건 표시. 환불 각주 **미표시** |
| L-F | **집계 정확도 (일)** | **PASS** | 아래 손계산 대조 |
| L-G | 집계 정확도 (월) | **PASS** | 136,500원 / 5건 / 평균 27,300원 (= 136,500 ÷ 5 정확히 나눠떨어짐), 목록 `환불·취소 포함 6건` |
| L-H | **주차 표기 (R1)** | **PASS** | `10월 4주차, 10월 19일부터 10월 25일, 이번 주` — 목요일(10/22) 소속 기준 일치 |
| L-I | 기간 네비게이터 | **PASS** | 오늘에서 `오늘` pill 표시 + 다음 비활성, 10/21 에서 pill 소멸 + 다음 활성 |
| L-J | 단위 전환 | **PASS** | 일 → 월 → 주 전환 시 각 단위 라벨·수치 정상 |
| L-K | 주문 상세 진입 | **PASS** | 행 탭 → `주문 상세` (주문번호 `c0ecd27d` 일치) |
| L-L | 환불 각주 조건부 | **PASS** | 환불 1건인 10/21 에만 `환불은 주문한 날의 매출에서 차감돼요` 표시 |
| L-M | 접근성 라벨 | **PASS** | `총 매출 101,500원 / … / 환불 1건, 37,000원 제외 / …` — **음수 하이픈 대신 양수 + "제외"** 로 조립됨 (design 요구사항). 월 단위에서는 행 라벨에 날짜 접두 추가 |

#### L-F 손계산 대조 (2026-10-21, 개인매장)

| 주문 | 금액 | 집계 |
|---|---|---|
| 16:15 우니 ×5 | 60,000 | 포함 |
| 15:23 우니 외 1개 | 17,000 | 포함 |
| 10:32 수제버거 2개 외 1개 | 24,500 | 포함 |
| 우니 외 1개 (환불) | 37,000 | **제외** |
| 10/20 주문 | 18,000 | **기간 밖** |

```
총 매출   60,000 + 17,000 + 24,500 = 101,500원   ← 화면 101,500원 ✅
주문 건수 3건                                     ← 화면 3건 ✅
평균      101,500 ÷ 3 = 33,833.33 → 33,833원      ← 화면 33,833원 ✅ (버림)
환불      1건 · -37,000원                          ← 화면 일치 ✅
목록      3 + 1 = 4건                              ← 화면 `환불·취소 포함 4건` ✅
```

**날짜 경계도 실증**됐다 — 10/20 주문(18,000원)이 10/21 집계에 들어오지 않았다.

### Z-4. 보류

| 항목 | 사유 |
|---|---|
| F1 수정의 라이브 재현 (오프라인 새로고침) | Mac Wi-Fi 를 꺼야 하는데 세션 연결이 함께 끊겨 복구 명령을 보낼 수 없다. `Source.server` 는 캐시 fallback 을 API 수준에서 제거하므로 계약상 보장되나, **눈으로 본 것은 아니다** |
| F2 수정의 라이브 재현 (재시도 → skeleton) | 에러 상태를 만들려면 동일하게 네트워크 차단이 필요 |
| truncated 경고 | `SalesQueryLimits.maxDocumentsPerQuery` 를 3 으로 낮추고 핫 리스타트 필요 |
| 타 매장 permission-denied | UI 로 재현 불가. `test_rules` R13~R18 로 대체 권장 (tester 제안, 미적용) |
| 디바이스 타임존 변경 | Simulator 가 호스트 macOS 타임존을 따라 단독 변경 불가. `TZ` 환경변수 단위 테스트로 대체 완료 |

### Z-5. 후속 후보 (backlog 반영 대상)

- `isTruncated` 가 `>=` 판정이라 정확히 1,000건일 때도 경고가 뜬다 (보수적 오탐, P3)
- provider·위젯 계약 테스트 0건 — 있었다면 F2 를 정적으로 잡았다
- `test_rules` 에 `orders` 시드 + R13~R18 추가
