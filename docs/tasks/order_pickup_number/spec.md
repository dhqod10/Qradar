# order_pickup_number (픽업 주문번호) 기능 명세

## 개요

- 목적: 픽업(테이크아웃) 매장에서 주문자끼리 헷갈리지 않도록, 결제된 주문마다 **사람이 읽기 쉬운 짧은 주문번호**를 부여한다. 카페의 "3번 고객님" 호출처럼 고객·점주가 같은 번호로 소통한다.
- 작업 유형: 기존 기능 수정 + 신규 필드/서버 로직 추가 (주문 생성 흐름 확장)
- 영향 범위:
  - 화면: 고객 결제완료/주문상세, 점주 주문목록(새주문·진행중)·주문상세, Log(주문내역) 카드
  - Domain: `OrderEntity`, `OrderLogEntity` 에 `pickupNumber` 필드 추가 (신규 UseCase 없음)
  - Data: `OrderModel`, `OrderLogModel` 매핑 확장
  - Presentation: 표시용 Widget 수정 (신규 Provider 없음 — 기존 watch 스트림 재사용)
  - 서버(functions/TS): `verifyTossPayment` 의 최종 쓰기를 **트랜잭션**으로 전환 + 매장·일별 카운터 할당 모듈 신규, `orderBuilder` 확장
  - 공통 컴포넌트: 픽업번호 표시 배지/칩 (designer 가 정의)
  - 라우팅: 변경 없음
  - 권한 / 환경 설정: `firestore.rules` 에 카운터 서브컬렉션 1개 추가 (CF 전담)
- 비범위:
  - 번호를 이용한 **알림/호출 자동화**(FCM "픽업 준비됐어요 N번" 문구 변경 등)는 이번 범위 아님. 기존 `onOrderStatusChanged` 문구는 그대로 둔다.
  - 과거 주문(기능 배포 전 생성) **backfill 안 함** (§7, §0-5).
  - 주문번호 기반 검색/필터 기능 없음.
  - 번호 재사용/반납·수동 재발급 없음 (자동 발급·불변).

---

## 0. 사용자 확인이 필요한 결정사항 (권고 포함)

> 설계자가 아래를 권고값으로 진행하되, 사용자 확정 후 구현 분배한다. 권고값에 이견 없으면 그대로 진행.

- **D1. 번호 형식** — (A) 매장·일별 순번 `1,2,3…` / (B) 4자리 랜덤 코드 / (C) 기타.
  **권고: (A)**. "3번 고객님" 호출 UX 에 가장 자연스럽고 짧다. 트레이드오프: 원자적 카운터가 필요(동시 주문 경합)하지만, 서버 트랜잭션으로 해결되고 런칭 전 규모(매장 1개)에서 경합은 사실상 없다. (B)는 카운터가 불필요하나 "3842번 고객님"은 호출에 부자연스럽고, 매장+일 내 충돌 회피 로직이 별도로 필요해 오히려 복잡하다.
- **D2. 유니크 범위** — 전역 / 매장별 / **매장+일별**.
  **권고: 매장+일별**. 픽업 호출은 같은 매장·같은 날 안에서만 구분되면 충분하다. 매일 1부터 다시 시작해 번호가 작게 유지된다.
- **D3. 리셋 시점** — **매일 자정 KST**.
  **권고: 자정 KST 리셋**. 카운터 문서 ID 에 KST 날짜(`yyyyMMdd`)를 넣어, 날짜가 바뀌면 자동으로 새 카운터가 1부터 시작한다. 별도 스케줄 리셋 작업 불필요.
- **D4. 표시 강조 수준** — 고객 결제완료/주문상세: **크게·가장 눈에 띄게**(호출 대조용). 점주 목록/상세: **크게**(호출 주체). Log: **보조 표기**(지난 기록, 날짜와 함께).
  **권고: 위와 같이 차등**. 정확한 크기/컴포넌트는 designer 가 design.md 에서 확정.
- **D5. 과거 주문 처리** — **backfill 안 함**. 번호 없는 주문은 UI 에서 번호 영역을 생략(또는 "-"). 픽업번호는 당일 운영 식별자라 지난 주문에 소급 부여할 실익이 없다. (§7)
- **D6. (경미) 표시 포맷** — 저장은 정수(`int`). 화면 표기(예: `3` vs `003` 제로패딩)는 designer 결정.

---

## 요구사항

### 기능 요구사항

- [ ] 결제 성공으로 주문이 생성될 때마다 `pickupNumber`(정수)가 **서버에서** 부여된다.
- [ ] 번호는 **매장+일(KST)** 단위로 1부터 순증한다 (D1·D2 권고 기준).
- [ ] 번호 발급은 **주문 생성과 같은 원자 단위(트랜잭션)** 에서 이뤄져 중복·누락이 없다.
- [ ] `verifyTossPayment` 의 **멱등 재시도** 시 번호가 재발급되지 않는다(기존 주문의 번호 그대로 반환).
- [ ] 클라이언트는 `pickupNumber` 를 **생성·수정할 수 없다**(위조·중복 방지).
- [ ] `pickupNumber` 는 `orders` 와 `users/{uid}/orderLogs` 양쪽에 동일 값으로 기록된다.

### UI 요구사항

- [ ] 고객 결제완료 화면 / 주문상세에 픽업번호를 **크게** 표시 (D4).
- [ ] 점주 주문목록(새주문·진행중 탭)·주문상세에 픽업번호를 **크게** 표시.
- [ ] Log(주문내역) 카드에 픽업번호를 보조 표기(날짜와 함께).
- [ ] 색상은 `AppColors` 만 사용.

### 상태 요구사항

- [ ] loading: 기존 주문 스트림 로딩 UI 재사용.
- [ ] error: 번호 필드 부재/매핑 실패 시 화면이 깨지지 않고 번호 영역만 생략.
- [ ] empty: 과거 주문 등 `pickupNumber == null` 이면 번호 영역 생략(또는 "-").

---

## 데이터 모델

### Entity 변경

`OrderEntity` (`lib/domain/entities/order_entity.dart`)
- `int? pickupNumber` 추가. null = 번호 미부여(과거 주문).

`OrderLogEntity` (`lib/domain/entities/order_log_entity.dart`)
- `int? pickupNumber` 추가. null = 미부여.

> 두 엔티티 모두 freezed. 필드 추가 후 `dart run build_runner build --delete-conflicting-outputs` 필요.

### Firestore 문서

`orders/{orderId}` (서버 전담 create)
```
pickupNumber: 3          // int. 매장+일(KST) 내 1부터 순증. 미부여 주문엔 필드 없음
```

`users/{uid}/orderLogs/{logId}` (서버 전담 create)
```
pickupNumber: 3          // orders 와 동일 값
```

`stores/{storeId}/pickupCounters/{yyyyMMdd}` (**신규, CF 전담**) — 매장·일별 카운터
```
current: 3               // 해당 매장·해당 날짜(KST)에 마지막으로 발급된 번호
updatedAt: <serverTimestamp>
```
- 문서 ID = KST 날짜(`yyyyMMdd`). 날짜가 바뀌면 다음 주문이 새 문서를 만들고 1부터 시작(자동 리셋, D3).
- 클라이언트 read/write 전면 차단(`if false`). 번호는 `orders` 문서로 전달되므로 클라이언트가 카운터를 읽을 필요가 없다.

### Model 변환 기준

- `OrderModel.fromFirestore`: `pickupNumber: (data['pickupNumber'] as num?)?.toInt()`.
- `OrderModel.toFirestore`: **`pickupNumber` 를 쓰지 않는다**(서버 소유 필드). 클라이언트 update 경로(접수·조리·환불요청 등)는 전용 필드 맵을 쓰므로 영향 없음. 라운드트립이 필요하면 조건부 생략으로 둔다.
- `OrderLogModel.fromFirestore`: 동일 패턴으로 `pickupNumber` 읽기. `toEntity`/`fromEntity` 매핑 추가.

---

## 레이어 설계

### Domain
- Entity: `OrderEntity.pickupNumber`, `OrderLogEntity.pickupNumber` 추가.
- UseCase: **신규 없음**. 번호는 기존 `WatchOrderUseCase` / `WatchUserOrdersUseCase` / `WatchStoreOrdersUseCase` 가 반환하는 엔티티에 실려 흐른다.
- Repository Interface: 시그니처 변경 없음(엔티티 필드만 늘어남).

### Data
- Model: `OrderModel`, `OrderLogModel` 매핑 확장(위 §데이터 모델).
- DataSource: 스키마 변경 없음(읽기만 — 필드 자동 포함).
- Repository Impl: 매핑 외 로직 변경 없음.

### Presentation
- Provider: 신규 없음.
- Page/Widget: 픽업번호 배지 추가 — 고객(`order_detail_page`, 결제완료/`payment_result_page`), 점주(`owner_orders_page` 타일들·`owner_order_detail_page`), Log(`order_card` / `orders_page`). 정확한 위치·컴포넌트는 design.md.

### 서버 (functions/src, TS) — 핵심
- **신규 `pickupCounter.ts`**: `allocatePickupNumber(tx, db, storeId, kstDate)` — 트랜잭션 안에서 `stores/{storeId}/pickupCounters/{yyyyMMdd}` 를 읽어 `current+1` 을 계산·기록하고 그 값을 반환. KST 날짜 포맷 헬퍼 포함(approvedAt 또는 서버 now 기준, Asia/Seoul).
- **`orderBuilder.ts`**: `buildOrderData` / `buildOrderLogData` 가 `pickupNumber` 를 받아 문서에 포함(값이 있을 때만).
- **`verifyTossPayment.ts`**: 현재 step 6 의 `db.batch()` 최종 쓰기를 **`db.runTransaction`** 으로 전환한다.
  - Toss confirm(네트워크 호출)은 트랜잭션 **밖**(기존 위치)에서 선행 — 트랜잭션에 비결정적/비가역 호출을 넣지 않는다.
  - 트랜잭션 내부: ① 주문 문서(`idempotencyKey`) 재-존재 확인(동시 중복 커밋 방지) → ② `allocatePickupNumber` 로 번호 할당 → ③ `orders/{orderId}`·`orderLogs/{logId}`·카운터 문서 set.
  - Qoin 예약(`reserveSpend`)은 현행대로 confirm **전** 유지. Layer2 신호(`writeOrderSignal`)는 커밋 **후** best-effort 유지.
  - 멱등: 기존 3-pre 가드(confirm 전 저렴한 체크)는 유지하되, 번호 중복 발급의 실제 방지선은 트랜잭션 내부 재확인이다. 커밋 전 실패 시 트랜잭션이 abort 되어 카운터가 증가하지 않는다(오펀 번호 없음).

---

## 데이터 흐름

생성(서버):
```
결제 성공 (Toss confirm DONE, 트랜잭션 밖)
  → db.runTransaction:
      주문 doc 미존재 재확인
      → allocatePickupNumber(storeId, KST yyyyMMdd)  // counter.current+1
      → set orders/{orderId}       (pickupNumber 포함)
      → set orderLogs/{logId}      (pickupNumber 포함)
      → set stores/{storeId}/pickupCounters/{yyyyMMdd} {current, updatedAt}
  → (커밋 후) writeOrderSignal best-effort
```

표시(클라이언트):
```
Page → 기존 watch Provider → UseCase → Repository → DataSource → Firestore(orders/orderLogs)
  → OrderEntity.pickupNumber / OrderLogEntity.pickupNumber → Widget 배지
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 카운터 문서 없음(그날 첫 주문) | `current` 부재 → 1 로 시작 (정상 경로) |
| 트랜잭션 경합(동시 주문) | Firestore 자동 재시도. 재시도마다 counter 재읽기 → 번호 중복 없음 |
| confirm 후·커밋 전 실패 | 트랜잭션 abort → 번호 미할당(카운터 불변). 기존 catch 의 Qoin 롤백/Toss cancel 경로 유지 |
| 멱등 재시도(이미 커밋된 주문) | 3-pre 가드가 기존 주문 반환 → 번호 재발급 안 함 |
| 과거 주문(`pickupNumber == null`) | UI 번호 영역 생략(또는 "-"). 매핑은 null 허용 |
| 번호 필드 매핑 실패 | null 로 떨어뜨리고 화면 유지(크래시 금지) |

---

## 감사 추적 / 이력 (audit_trail.md §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** — **아니오.** `pickupNumber` 는 **식별자**이며 금액·권한·정책 계수가 아니다. 따라서 **설정 변경 이력은 불필요**(기본값 "남긴다"의 예외 사유를 여기 명시). 단, 번호 중복은 돈 문제가 아니어도 픽업 혼선이므로 **발급의 원자성·멱등은 돈에 준해 정확히** 설계한다(위 트랜잭션).
2. **덮어쓰기로 사라지는 값?** — 없음. `pickupNumber` 는 생성 시 1회 기록 후 **불변**(어떤 전이에서도 수정하지 않음). 카운터의 `current` 는 단조 증가하며 발급 근거는 주문 문서 자체에 박제된다.
3. **거래 기록이 정책 값을 참조만 하는가?** — 번호는 정책 값이 아님. 주문·로그 양쪽에 **실제 값으로 박제**(참조 아님).
4. **"누가" 기록되는가?** — 발급 주체는 항상 서버(CF). 행위자 추적 불필요(운영자 행위가 아님).
5. **batch/일괄 처리?** — 없음(건별 발급).
6. **CF 로그 의존?** — 아니오. 번호는 Firestore 영구 문서(`orders`/`orderLogs`)에 남는다.
7. **권한 판정 필드의 create/update 교차 확인** — `pickupNumber` 는 권한 판정 입력이 아니다. 그래도 클라이언트 쓰기 차단을 교차 확인: `orders.create = if false`(CF 전담), `orders.update` O1~O7 `onlyChangedFields` 화이트리스트에 `pickupNumber` 가 **없어** 클라이언트가 추가·변경할 수 없다(회귀 테스트로 고정). 카운터 서브컬렉션은 read/write `if false`.

---

## 소유권 / Rules 변경 (data_ownership.md 반영 필요)

- `orders.pickupNumber` — **CF `verifyTossPayment` 전담** 생성. 클라이언트 create 차단(기존 `if false`), update 화이트리스트 제외로 수정 차단. → data_ownership.md §2.4 "Cloud Function 전담" 에 추가.
- `orders/{uid}/orderLogs.pickupNumber` — 동일 CF 가 함께 기록(기존 §2.2 전담 범위에 필드만 추가).
- **신규** `stores/{storeId}/pickupCounters/{yyyyMMdd}` — read/create/update/delete **전부 `if false`**(CF/Admin SDK 전담). → data_ownership.md §2.5 하위에 소컬렉션 추가, firestore.rules `stores/{storeId}` match 블록 내부에 추가.
- `entity_lifecycle.md`: Order 의 status 전이·enum 은 **변경 없음**. `pickupNumber` 는 생성 시점에 고정되는 비-status 필드임을 §2 주석으로 1줄 명시.

---

## 작업 분배

### designer (필요)
- UI 변경 있음. design.md 산출.
- 전달 사항: 픽업번호 표시 3개 맥락의 강조 차등(D4) — 고객 결제완료/상세(가장 크게), 점주 목록/상세(크게), Log(보조). 제로패딩 등 표기 포맷 결정. `AppColors`·미드나잇 네이비 포인트 일관. 번호 없는(과거) 주문의 빈 상태 표현.

### developer
- 구현 항목:
  - 서버: `pickupCounter.ts`(KST 날짜 헬퍼 + 트랜잭션 할당), `orderBuilder.ts` 확장, `verifyTossPayment.ts` 최종 쓰기를 트랜잭션으로 전환(§레이어-서버).
  - Rules: `stores/{storeId}/pickupCounters/{date}` match 추가(`if false`).
  - Dart: `OrderEntity`/`OrderLogEntity` 필드 추가 + build_runner, `OrderModel`/`OrderLogModel` 매핑, 표시 Widget(design.md 반영).
  - 문서 갱신: data_ownership.md(§2.2/§2.4/§2.5), entity_lifecycle.md(§2 주석), audit_trail.md(§3 표에 pickupNumber 식별자 기록 1줄).
- 재사용: 기존 watch 스트림/Provider, `orderBuilder` 순수 함수 패턴, Qoin 예약이 쓰는 트랜잭션 패턴 참고.
- 주의할 레이어 규칙: domain 순수 유지(Firebase import 금지), 표시 로직은 presentation, 번호 발급 권위는 서버뿐. `toFirestore` 에 서버 소유 필드를 쓰지 않는다.

### tester
- 주요 검증 기준:
  - 매장+일 내 순증·유니크, 다음 날 1 리셋(KST 경계).
  - **동시 주문 경합** 시 번호 중복 없음(트랜잭션 재시도).
  - **멱등 재시도** 시 번호 재발급 없음(3-pre 가드 + 트랜잭션 재확인).
  - confirm 후 커밋 실패 시 카운터 불변(오펀 번호 없음) + Qoin 롤백 경로 회귀.
  - 클라이언트가 `pickupNumber` 를 create/update 로 쓰지 못함(Rules 거부) + 정상 주문/전이 payload 회귀 통과.
  - 과거 주문(null) UI 미깨짐.
- 반드시 확인할 예외 케이스: KST 자정 직전/직후 발급, 같은 ms 동시 2건, mock 모드 발급.

---

## 완료 기준

- [ ] §0 결정사항 사용자 확정(최소 D1·D2·D3)
- [ ] 서버 발급(트랜잭션·멱등·KST 리셋) 구현
- [ ] Entity/Model/Rules/문서 반영
- [ ] 고객·점주·Log 표시 구현 (design.md 반영)
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료 (경합·멱등·리셋 포함)
- [ ] FAIL 항목 없거나 후속 분리
