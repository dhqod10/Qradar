# Qoin (앱 화폐) 1차 기능 명세

- 작성: architect
- 작성일: 2026-10-22
- 상태: 설계 완료, 사용자 결정 대기 (§13)

---

## 개요

**목적**: `Qoin` 은 Qradar 고유 용어 3종(`Qoin` / `Qrator` / `Log`) 중 **유일하게 이름만 있는 것**이다.
`Qrator`(평가)는 `store_reviews` 로, `Log`(주문 내역)는 Phase 3c 로 동작하게 됐고, Qoin 은 **고객 하단 네비 탭 1칸을 차지한 채 `준비 중입니다` 만 띄운다** (`lib/presentation/customer/qoin/qoin_page.dart:50`). 현재 네비 탭에 연결된 유일한 placeholder 다.

이 task 는 Qoin 을 **실제로 쌓이고 줄어드는 값**으로 만든다. 1차 범위는 **적립 → 잔액 → 내역** 한 바퀴를 닫는 것까지다.

**작업 유형**: 신규 기능 (+ 기존 죽은 인터페이스 1종 제거)

### 전제 — Qoin 은 금전 가치다

이 spec 의 모든 설계 판단은 다음 우선순위를 따른다.

1. **원자성** — 잔액 갱신과 거래 기록이 쪼개져 발생하면 안 된다
2. **멱등성** — CF 재시도 / 중복 트리거가 이중 적립을 만들면 안 된다
3. **감사 추적** — 모든 잔액 변동은 "언제 / 왜 / 얼마" 가 남은 거래 문서를 근거로 가져야 한다
4. 그다음에 비용 · UX

`store_reviews` 의 평점은 틀리면 "표시가 이상하다" 로 끝나지만, Qoin 이 틀리면 **실제 손해**다.
그래서 이 spec 은 `onReviewWritten` 의 전량 재계산 패턴을 **그대로 쓰지 않는다** (§4.2 에서 근거 제시).

---

## 1. 사전 조사 결과 (실측, 2026-10-22)

추측 없이 코드 / Rules / CF / 문서를 직접 읽은 결과만 기록한다.

### 1.1 이미 존재하는 것 (중복 설계 금지)

| 항목 | 위치 | 실측 상태 |
|---|---|---|
| `QoinAccrualHook` 인터페이스 | `lib/domain/repositories/qoin_accrual_hook.dart` | `onOrderPaid(OrderEntity)` / `onOrderRefunded(OrderEntity)` 2 메서드. 주석에 "Phase 4 에서 real 구현체로 교체" |
| `NoOpQoinAccrualHook` | `lib/data/repositories/no_op_qoin_accrual_hook.dart` | 두 메서드 모두 `async {}` — **완전 무동작** |
| provider | `lib/presentation/customer/order/orders/providers/order_di_providers.dart:60` | `qoinAccrualHookProvider` → `const NoOpQoinAccrualHook()` |
| `onOrderPaid` 호출부 | `lib/presentation/customer/checkout/checkout_page.dart:122` | `await ref.read(qoinAccrualHookProvider).onOrderPaid(order);` — 결제 성공 직후 1곳 |
| `onOrderRefunded` 호출부 | — | **0건. 어디서도 호출되지 않는다** (grep 전역 확인) |
| Qoin 탭 화면 | `lib/presentation/customer/qoin/qoin_page.dart` | `_PlaceholderScreen` — `QLogo` + `'Qoin'` + `'준비 중입니다'` |
| 탭 연결 | `lib/presentation/common/scaffold_with_nav.dart:92`, `bottom_nav.dart:46` | 탭 인덱스 1 = Qoin. `IndexedStack` 2번째 child |
| Qoin 관련 Entity / Model / Repository / DataSource / UseCase | — | **전부 없음** |
| Qoin 관련 Firestore 컬렉션 / Rules 블록 | `firestore.rules` | **없음**. `match /{document=**} { allow read, write: if false; }` 로 전부 거부 |

**`lib`/`functions`/`firestore.rules` 전역 grep 결과 — Qoin 은 위 표 외에 어디에도 없다.** 데이터도, 권한도, 화면도 0 에서 시작한다.

### 1.2 핵심 발견 — `onOrderRefunded` 는 구조적으로 호출될 수 없다

환불 / 취소는 Cloud Function 이 전담한다 (실측):

| 전이 | 주체 | 클라이언트가 아는가 |
|---|---|---|
| `paid → cancelled` | `cancelTossPayment` CF (`approvedBy: 'customer' \| 'owner'`) | 고객 취소면 알지만, **점주 거절이면 고객 앱은 호출 시점에 없다** |
| `accepted/making/ready/completed → refunded` | `processRefund` CF (점주만 호출) | **고객 앱은 전혀 개입하지 않는다** |

즉 `onOrderRefunded` 를 호출할 클라이언트 지점이 **존재할 수 없다**. 환불 승인은 점주 기기에서 일어나고 회수 대상은 고객 잔액이다.
→ `QoinAccrualHook` 이 죽은 인터페이스인 이유는 "아직 구현 안 함" 이 아니라 **설계가 애초에 성립하지 않았기 때문**이다. §7 (결정 D6) 에서 폐기한다.

### 1.3 핵심 발견 — `users.qoinBalance` 는 Rules 변경 없이 이미 안전하다

`firestore.rules` `isSelfProfileUpdate(userId)` 는 `onlyChangedFields([...])` = `affectedKeys().hasOnly(화이트리스트)` 를 쓴다. 화이트리스트(실측):

```
['role', 'displayName', 'photoUrl', 'fcmToken', 'fcmTokenUpdatedAt',
 'notificationPermissionPrompted', 'notificationPermissionLaterCount',
 'notificationSettings', 'updatedAt', 'brandId']
```

`hasOnly` 이므로 **목록에 없는 필드를 건드리는 모든 self update 는 자동 거부**된다.
→ `users/{uid}.qoinBalance` 를 추가해도 **고객이 자기 잔액을 직접 쓸 수 없다. `users` Rules 블록은 수정하지 않는다.**

| actor | `users/{uid}.qoinBalance` 쓰기 |
|---|---|
| 본인(customer) | ❌ `hasOnly` 화이트리스트 미포함 |
| 타인 | ❌ `uid() == userId` 실패 |
| owner / brand | ❌ 동일 |
| admin | ✅ (`allow update: if isAdmin()` 전권) — 운영 수단. §4.4 참조 |
| Cloud Function (Admin SDK) | ✅ Rules 우회 |

이것이 `data_ownership.md §3` 의 일반 규칙("A 가 쓴 문서로 B 소유 문서의 집계값을 갱신해야 하면 Cloud Function 이다")에 **정확히 들어맞는 형태**다. Qoin 은 더 강한 케이스다 — 적립 근거(`orders`)는 고객도 점주도 직접 못 쓰고, 결과(`users.qoinBalance`)는 본인조차 못 쓴다.

### 1.4 핵심 발견 — 사용자 프로필은 이미 live stream 이다

`lib/presentation/customer/auth/providers/user_profile_provider.dart:54`

```
currentUserProfileProvider = StreamProvider<UserEntity?>
  → WatchUserProfileUseCase → UserRepositoryImpl.watchCurrent
  → UserRemoteDataSource.watch(uid)  →  _doc(uid).snapshots()
```

`users/{uid}` 는 **이미 `snapshots()` 로 구독**되고 있고 `role_router` / `notification_settings_page` 가 이를 watch 한다.
→ `qoinBalance` 를 이 문서의 필드로 두면 **신규 구독 0개로 잔액이 실시간 갱신**된다. CF 가 쓰는 순간 화면이 바뀐다.

> 직전 커밋 `ac1d2c3 fix: 평가 반영이 화면에 안 보이던 문제 — 매장 단건 구독 추가` 는 `stores` 단건 구독이 없어서 생긴 문제였다. Qoin 은 **그 문제가 구조적으로 발생하지 않는 위치**를 택할 수 있다. 이것이 D1 의 결정적 근거다.

### 1.5 order status 전이 — 어디에 적립을 걸 수 있는가

`docs/processes/entity_lifecycle.md §2` + `lib/domain/entities/order_status.dart` 실측:

```
(없음) → paid        : verifyTossPayment CF (문서 create)
paid → accepted      : 점주, Rules O1 (update)
accepted → making    : 점주, Rules O5 (update)
making → ready       : 점주, Rules O6 (update)
ready → completed    : 점주, Rules O7 (update)   ← 정상 종료
paid → cancelled     : cancelTossPayment CF (update)
accepted/making/ready/completed → refunded : processRefund CF (update)
```

- `paid` 진입은 **document create** 다 (`orders.create: if false`, CF 만). 트리거 타입이 `onDocumentCreated`.
- `completed` 진입과 `refunded` 진입은 모두 **document update** 다. → **하나의 `onDocumentUpdated` 트리거로 적립과 회수를 둘 다 잡을 수 있다.**
- `completedAt` 은 Phase 3c 부터만 기록된다 (legacy `completed` 주문에 없을 수 있음). → Qoin 은 `completedAt` 에 의존하지 않는다 (`createdAt`/`serverTimestamp` 사용).

### 1.6 기존 CF 패턴 (재사용)

`functions/src/` 실측:

| 항목 | 값 |
|---|---|
| region | `asia-northeast3`, 각 파일에서 개별 지정 |
| 등록 | `functions/src/index.ts` 의 `export { X } from "./X";` 1줄 |
| `admin.initializeApp()` | `index.ts` 에서 1회 (`if (admin.apps.length === 0)`) |
| `orders` 트리거 CF | `onOrderCreated` (`onDocumentCreated`), `onOrderStatusChanged` (`onDocumentUpdated`), `onOrderRefundRequested` |
| `onOrderStatusChanged` 전이 처리 | `before.status != after.status` 로 `${before}->${after}` 키 매칭, 매트릭스 미정의면 early return |
| 집계 CF | `onReviewWritten` (`onDocumentWritten`) — `count()` + `sum()` 전량 재계산 |
| 실패 처리 | **알림 CF 는 `console.error` 후 swallow** (재시도 폭주 방지) |

→ `orders/{orderId}` 에 `onDocumentUpdated` 트리거가 이미 1개(`onOrderStatusChanged`) 붙어 있다. **같은 문서에 트리거 2개는 정상**이고, 돈 처리와 알림 발송은 실패 격리가 필요하므로 **별도 CF 로 분리**한다 (§7.2, 결정 A1).

> ⚠️ 단, **실패 처리 정책은 재사용하지 않는다.** 알림은 유실돼도 되지만 적립은 안 된다. §9 (에러 처리) 에서 별도 정의한다.

### 1.7 설정값을 둘 수 있는 곳 (실측)

| 수단 | 현황 |
|---|---|
| `--dart-define` / `String.fromEnvironment` | 사용 중 (`map_config.dart:15` KAKAO_JS_KEY, `toss_payment_remote_data_source.dart:63` 토스 클라이언트 키) — **클라이언트 전용. CF 가 못 읽는다** |
| `lib/core/constants/` | `grade_thresholds.dart` / `recommendation_thresholds.dart` / `sales_query_limits.dart` 등 Dart 상수 — **CF(TypeScript) 가 못 읽는다** |
| Firebase Remote Config | `pubspec.yaml` / `functions/package.json` 에 패키지 **없음**. 신규 도입 필요 |
| Firestore 설정 문서 | **`config` 컬렉션 없음.** Rules 블록도 없음 (catch-all deny) |

**핵심 제약**: 적립률은 **CF(TypeScript) 가 계산에 쓰고, 클라이언트(Dart) 가 안내 문구에 표시**해야 한다. 양쪽에서 읽어야 하는 값이므로 Dart 상수도 `--dart-define` 도 단일 진실원이 될 수 없다. → §6 (결정 D4).

### 1.8 Rules 테스트 하네스 (실측)

`test_rules/rules.test.mjs` — `@firebase/rules-unit-testing`, 에뮬레이터 `127.0.0.1:8137`, `fs.readFileSync('firestore.rules')`.
`withSecurityRulesDisabled` 로 시드 후 `run(name, 'allow'|'deny', fn)`. `owner_sales` → `store_reviews` 에서 확장한 구조를 그대로 재사용한다 (§11.1).

### 1.9 `docs/backlog.md` "Phase 4 — Qoin 도메인" 검증 결과

실측(`docs/backlog.md:86~91`):

```
### Phase 4 — Qoin 도메인 (별도 분리 — 사용자 결정)
- QoinBalanceEntity / QoinTransactionEntity / QoinRepository
- `users/{uid}/qoinBalance` + `users/{uid}/qoinTransactions/{txId}` 또는 root `qoinTransactions/`
- 적립 / 사용 / 환불 흐름 (atomic Transaction)
- 마이페이지 잔액 표시 / 결제 화면에 Qoin 사용 옵션
- Phase 3a 의 적립 hook 에 연결
```

| 항목 | 판정 |
|---|---|
| `QoinTransactionEntity` / `QoinRepository` | ✅ 유효. 이 spec 이 채택 |
| `QoinBalanceEntity` | ❌ **불필요.** 잔액은 `UserEntity` 의 int 필드 1개 (§5.1, D1) — 별 Entity 를 만들면 §1.4 의 무료 구독 이점을 버린다 |
| `users/{uid}/qoinBalance` (경로 표기) | ⚠️ 서브컬렉션 경로처럼 쓰여 있으나 **필드**로 둔다 (§4.1) |
| `atomic Transaction` | ✅ 유효. 단 **클라이언트가 아니라 CF(Admin SDK) 안에서** (§4.2) |
| "적립 hook 에 연결" | ❌ **낡았다.** hook 은 폐기한다 (§1.2, D6) |
| "결제 화면에 Qoin 사용 옵션" | ❌ **1차 제외** (사용자 확정). 2차 Q1 |
| "마이페이지 잔액 표시" | ⚠️ 1차는 **Qoin 탭**이 주 진입점. 더보기 노출은 2차 Q4 |

→ backlog 가 **두 군데 낡았다** (`QoinBalanceEntity`, hook 연결). 구현 완료 후 정정 (§12 X1).

---

## 2. 요구사항

### 2.1 기능 요구사항 — 1차 범위

| # | 요구사항 |
|---|---|
| F1 | 주문이 **`completed`(픽업 완료)** 로 전이되면 결제액의 일정 비율이 고객 Qoin 으로 **자동 적립** |
| F2 | 적립된 주문이 **`refunded`** 로 전이되면 **적립분과 정확히 같은 금액이 회수** |
| F3 | 적립 / 회수는 **Cloud Function 이 Firestore Transaction 안에서** 거래 문서 생성 + 잔액 갱신을 **원자적으로** 수행 |
| F4 | 같은 주문에 대한 적립은 **1회만** 발생 (CF 재시도 / 중복 트리거에도 이중 적립 없음) |
| F5 | 모든 잔액 변동이 **거래 내역 문서**로 남는다 (금액 / 사유 / 근거 주문 / 변동 후 잔액) |
| F6 | 고객이 **Qoin 탭에서 현재 잔액을 조회** (실시간 갱신) |
| F7 | 고객이 **Qoin 탭에서 적립 / 회수 내역을 최신순 조회** |
| F8 | 적립률이 **코드에 하드코딩되지 않고** CF 와 클라이언트가 같은 출처에서 읽는다 |
| F9 | Qoin 적립이 **일시 중단 가능** (kill switch) — 금전 기능의 운영 안전장치 |
| F10 | 죽은 `QoinAccrualHook` 인터페이스 / NoOp 구현 / provider / 호출부 **제거** |

### 2.2 UI 요구사항

| # | 요구사항 |
|---|---|
| U1 | Qoin 탭 placeholder 제거 → 잔액 카드 + 내역 리스트 |
| U2 | 적립 정책 안내 ("픽업 완료 시 결제액의 N% 적립") — N 은 §6 의 설정값에서 읽는다 |
| U3 | 내역 항목에 매장명 / 금액(부호 포함) / 일시 / 사유(적립·회수) 표시 |
| U4 | 적립이 **결제 직후가 아니라 픽업 완료 시점**임을 사용자가 오해하지 않게 명시 (§5.3 D3 의 UX 비용) |
| U5 | 1차는 **Qoin 을 쓸 수 없음**을 명확히 안내 (잔액만 쌓인다는 사실을 숨기지 않는다) |

### 2.3 상태 요구사항

| 상태 | 요구 |
|---|---|
| loading | 잔액 / 내역 각각 독립 로딩 (잔액은 이미 구독 중인 프로필에서 오므로 보통 즉시) |
| empty | 내역 0건 — "아직 적립 내역이 없어요" + 적립 조건 안내 |
| error | 내역 조회 실패 — 에러 UI + 재시도. 잔액은 프로필 스트림 에러에 종속 |
| 잔액 0 | empty 가 아니라 **정상 상태** `0 Qoin` 으로 표시 |

### 2.4 2차 범위 (이번에 하지 않음 — 명시적 제외)

`owner_sales` 의 S1~S6 / `store_reviews` 의 R1~R8 과 동일하게 별 task 로 분리한다.

| # | 항목 | 미루는 이유 |
|---|---|---|
| **Q1** | **결제 시 Qoin 사용(차감)** | **사용자 확정 제외.** 토스 키 교체 + Mock 모드 해제가 예정돼 있어 결제 금액 계산을 동시에 건드리면 문제 원인 추적이 불가능해진다. §4.2 의 설계는 이 확장을 전제로 선택됐다 |
| Q2 | 적립 FCM 알림 | `onOrderStatusChanged` 가 이미 `ready→completed` 에 `pickupComplete` 알림을 보낸다. 적립 알림을 따로 보내면 같은 전이에 푸시 2건 — 알림 설계 재검토 필요 |
| Q3 | "적립 예정 Qoin" 표시 (`paid`~`ready` 주문) | 주문 상세 / Qoin 탭에 미확정 금액을 표시하려면 적립률 × 진행 중 주문 쿼리가 필요. 범위 확대 |
| Q4 | 더보기 / 홈 헤더 잔액 노출 | Qoin 탭이 1차 진입점. 노출 지점 확대는 designer 판단 선행 필요 |
| Q5 | 내역 페이지네이션 / 기간 필터 | 1차는 `limit(50)` 고정 |
| Q6 | 소멸(유효기간) 정책 | 소멸은 **잔액을 줄이는 세 번째 사유**이고 배치 CF(스케줄러)가 필요. 거래 타입 설계는 확장 가능하게 두되(§4.3) 구현은 2차 |
| Q7 | 등급별 차등 적립률 / 프로모션 가산 | 설정 구조가 단일 비율에서 룰 엔진으로 커진다 |
| Q8 | 선물하기 / 사용자 간 이전 | `role_flows.md` 의 "선물하기 — 미구현" 과 연결. 송신·수신 양쪽 잔액 트랜잭션 필요 |
| Q9 | admin Qoin 수동 조정 화면 | 1차는 Console + 거래 문서 수동 생성으로 대응 (§4.4) |
| Q10 | 잔액 ↔ 내역 정합성 자동 감사(reconciliation) CF | 1차는 식(§4.2)과 수동 점검 절차만 정의. 자동 감사는 Q1(사용) 도입 시 같이 |
| Q11 | 부분 환불 대응 | `processRefund` 가 현재 **항상 전액 환불**이다 (`entity_lifecycle.md §2.5`). 부분 환불이 생기면 비례 회수 설계가 필요 |

---

## 3. 영향 범위

| 영역 | 영향 |
|---|---|
| 화면 / Widget | `qoin_page.dart` **전면 교체**, 신규 widget 2종. `checkout_page.dart` 1줄 + import 제거 |
| Provider | 신규 `qoin_di_providers.dart` / `qoin_providers.dart`. `order_di_providers.dart` 에서 `qoinAccrualHookProvider` **제거** |
| Domain Entity | `UserEntity` **수정**(`qoinBalance`). 신규 `QoinTransactionEntity` / `QoinTransactionType` / `QoinConfigEntity`. `QoinAccrualHook` **삭제** |
| UseCase | 신규 2종 |
| Repository Interface | 신규 `QoinRepository`. `QoinAccrualHook` 삭제 |
| DataSource | 신규 `QoinRemoteDataSource` |
| DTO / Model | `UserModel` + `UserModelFactory.fromFirestore` **수정**. 신규 `QoinTransactionModel` / `QoinConfigModel` |
| Repository Impl | 신규 `QoinRepositoryImpl`. `NoOpQoinAccrualHook` **삭제** |
| Firebase 구조 | **신규 CF 1개** / **Rules 신규 블록 2개** / 신규 Firestore 컬렉션 1 + 서브컬렉션 1 / 신규 설정 문서 1 |
| 공통 컴포넌트 | 없음 (`AppColors` 재사용) |
| 라우팅 | 없음 (Qoin 은 `IndexedStack` 탭. 내역 전체 보기 push 는 1차 미도입) |
| 권한 / 환경 설정 | `firestore.rules` 배포, CF 배포. `--dart-define` 추가 **없음** |
| 테스트 | Rules 테스트 확장, CF 에뮬레이터 테스트 신규, Dart 단위 테스트 신규 |

---

## 4. 저장 구조 설계 (결정 D1 / D2 / D7)

### 4.1 저장 위치 — `users/{uid}.qoinBalance` 필드 + `users/{uid}/qoinTransactions/{txId}` 서브컬렉션 (결정 D1)

| 선택지 | 잔액 조회 비용 | 내역 조회 | Rules | CF 접근성 | 판정 |
|---|---|---|---|---|---|
| **A. `users/{uid}.qoinBalance` 필드 + `users/{uid}/qoinTransactions/` 서브컬렉션** | **0 read** — 이미 구독 중인 프로필 문서에 포함 (§1.4) | 서브컬렉션 `orderBy createdAt desc` — **복합 인덱스 불필요** | 잔액은 Rules **변경 없이 이미 차단**(§1.3). 서브컬렉션은 `orderLogs` 블록 복제 | 동일 문서 + 하위 경로 → **한 Transaction 안에서 처리 가능** | ✅ **추천** |
| B. `users/{uid}/qoin/{doc}` 서브컬렉션에 잔액 문서 | 별도 구독 1개 추가 | 동일 | 신규 블록 1개 | 잔액 문서와 거래 문서가 같은 트랜잭션 가능 | ❌ §1.4 의 무료 구독 이점을 버린다. 단건 구독 누락이 `ac1d2c3` 버그를 재생산한다 |
| C. root `qoinTransactions/` (+ `userId` 필드) | 잔액 위치가 여전히 필요 | `where userId == + orderBy createdAt desc` → **복합 인덱스 필요** | 신규 블록 + `userId` 기반 read 제한. 타인 내역 유출 리스크 표면 증가 | 동일 | ❌ 인덱스·권한 비용만 늘고 얻는 게 없다. 내역은 **항상 사용자 단위로만** 조회한다 |

**A 추천의 결정적 근거 3개**

1. **§1.4** — `users/{uid}` 는 이미 `snapshots()` 구독 중이다. 잔액을 그 문서의 필드로 두면 **CF 가 쓰는 순간 화면이 갱신**된다. 신규 구독 0, 신규 provider 0, 단건 구독 누락 버그 구조적으로 불가능.
2. **§1.3** — `isSelfProfileUpdate` 의 `hasOnly` 화이트리스트 덕에 **`users` Rules 를 한 글자도 안 고치고** 고객 직접 쓰기가 차단된다. 가장 위험한 쓰기 경로가 **기본값으로 닫혀 있다.**
3. **`orderLogs` 선례** — `users/{uid}/orderLogs/{logId}` 가 이미 "CF 만 쓰고 본인만 읽는 append-only 서브컬렉션" 이다 (`read: self||admin`, `create/update: if false`). Qoin 거래 내역은 **성격이 완전히 동일**하므로 그 블록을 복제한다. 신규 패턴을 만들지 않는다.

### 4.2 잔액의 신뢰 원천 — 거래 내역이 진실, 잔액은 **트랜잭션 안에서 갱신되는 투영** (결정 D2)

**불변식 (invariant)**

```
users/{uid}.qoinBalance  ==  Σ qoinTransactions[*].amount        (amount 는 부호 포함)
```

이 등식은 **절대 깨지지 않아야 하고, 어떤 경우에도 clamp 되지 않는다** (§8.3).

| 방식 | 판정 |
|---|---|
| **A. 거래 문서 생성 + 잔액 갱신을 하나의 `db.runTransaction` 안에서** (거래 문서 선존재 시 abort) | ✅ **추천** |
| B. `onReviewWritten` 식 **전량 재계산** — 매 변동 때 `sum(amount)` 집계 후 절대값 overwrite | ❌ 2차 Q1 과 양립 불가 (아래) |
| C. `FieldValue.increment(delta)` 단독 (트랜잭션 없이) | ❌ 멱등성 보장 수단이 없고 `balanceAfter` 감사 필드를 쓸 수 없다 |

#### B(전량 재계산)를 쓰지 않는 이유 — `onReviewWritten` 과 무엇이 다른가

`store_reviews` 가 전량 재계산을 택한 이유는 3개였다 (`store_reviews/spec.md §3.2`): 멱등 / 자기 치유 / **수정·삭제 보정 불필요**. Qoin 에서는 전제가 바뀐다.

1. **증분의 약점이 Qoin 에는 없다.** 리뷰는 **가변**이다 — 수정·삭제가 있으니 증분은 delta 보정이 복잡하고 한번 틀어지면 영구 누적된다. 그래서 재계산이 이겼다.
   Qoin 거래 내역은 **append-only 불변 원장**이다 (수정·삭제 없음, Rules 로 강제 §8.1). 보정해야 할 delta 자체가 발생하지 않으므로 **증분을 기각할 근거가 사라진다.**
2. **비용은 결정 요인이 아니다.** Firestore 집계 쿼리는 인덱스 엔트리 1024개당 1 read 다. 재계산 범위가 **사용자 1명의 서브컬렉션**이므로 평생 500건 주문 사용자도 1 read 다. 요구사항이 "비용까지 따져라" 였으나 **실측 구조상 비용 차이는 유의하지 않다.** 따라서 비용이 아니라 **원자성과 2차 확장성**으로 갈라야 한다.
3. **결정적 이유 — 2차 Q1(Qoin 사용)과 양립 불가.** 사용이 들어오면 결제 시점에 "잔액 확인 → 차감" 이 **하나의 트랜잭션**이어야 한다(안 그러면 이중 사용). 그때 잔액이 "CF 가 나중에 집계해 덮어쓰는 지연 투영" 이면:
   - 차감 트랜잭션과 CF 의 재계산 overwrite 가 **레이스**한다
   - CF 가 (차감 거래를 아직 못 본 시점의) 집계값으로 덮으면 **이미 쓴 Qoin 이 부활**한다 — 돈이 복제되는 버그
   A 방식은 모든 변동이 동일한 트랜잭션 규율을 따르므로 Q1 을 **설계 변경 없이** 받는다.
4. **감사 추적.** A 는 트랜잭션 안에서 잔액을 읽으므로 거래 문서에 `balanceAfter` 를 기록할 수 있다. 원장 체인을 따라 "어디서 틀어졌는지" 를 역추적할 수 있다. B 는 불가능하다.

#### A 의 멱등성·자기 치유 확보

- **멱등성**: 거래 문서 ID 가 결정적(§4.3)이고, 트랜잭션이 **먼저 그 문서의 존재를 읽어 있으면 즉시 종료**한다. 재시도·중복 트리거는 무해한 no-op 이 된다 (§4.3, D7).
- **자기 치유**: A 는 B 처럼 자동 치유되지 않는다. 대신 **불변식이 검증 가능**하다 — `qoinBalance` 와 `sum(amount)` 를 비교하면 불일치를 **탐지**할 수 있다. 1차는 탐지 절차(§8.4)와 수동 복구만 정의하고, 자동 감사 CF 는 2차 Q10 으로 분리한다.
  > 트레이드오프를 숨기지 않는다: **B 보다 자기 치유가 약하다.** 금전 기능에서는 "조용히 자동 보정" 보다 "불일치를 탐지해 사람이 확인" 이 옳다 — 자동 보정은 버그를 은폐한다.

#### 트랜잭션 의사 구조 (CF, Admin SDK)

```
db.runTransaction(async (t) => {
  const txSnap = await t.get(txRef);            // 멱등 가드
  if (txSnap.exists) return 'already_applied';  // ← 재시도 안전

  const userSnap = await t.get(userRef);
  if (!userSnap.exists) return 'no_user';
  const before = userSnap.get('qoinBalance') ?? 0;   // 필드 부재 → 0
  const after  = before + amount;                     // amount 는 부호 포함

  t.set(txRef, { ...거래필드, amount, balanceAfter: after, createdAt: FieldValue.serverTimestamp() });
  t.update(userRef, { qoinBalance: after });          // ← 절대값. qoinBalance 1필드만
  return 'applied';
});
```

- 잔액은 `increment` 가 아니라 **트랜잭션 read 기반 절대값**으로 쓴다 — `balanceAfter` 와 실제 기록값이 반드시 일치해야 하므로. (`increment` 는 쓴 값을 알 수 없다.)
- **`users/{uid}` 에는 `qoinBalance` 1필드만 쓴다.** `updatedAt` 은 건드리지 않는다 — `store_reviews` 가 `stores.updatedAt` 을 보호한 것과 같은 이유(소유권 경계를 넘는 쓰기는 최소 필드로 제한, `data_ownership.md §3`).
- 경합: 쓰기 범위가 사용자 1명이고 주문 완료는 직렬적이므로 트랜잭션 재시도 경합은 사실상 없다.

### 4.3 멱등성 — 결정적 거래 문서 ID (결정 D7)

| 거래 | 문서 ID | 근거 |
|---|---|---|
| 적립 | `earn_{orderId}` | `orderId` = `idempotencyKey` = Toss orderId (uuid v4). **주문당 유일** (`order_entity.dart` 주석 실측) |
| 회수 | `clawback_{orderId}` | 동일. 주문 1건은 1회만 `refunded` 가 된다 |

이 설계로 §2.1 F4 가 **구조적으로** 보장된다.

- CF 가 재시도되면 → `t.get(txRef)` 가 존재를 보고 → no-op
- 트리거가 중복 발화하면 → 동일
- `completed → refunded` 외의 전이에서 실수로 호출되면 → 트리거 매트릭스(§7.2)에서 먼저 걸러짐

> `orderId` 가 문서 ID 에 들어가는 덕에 **"이 주문이 적립됐는가" 를 쿼리 없이 단건 read 로 확인**할 수 있다. 회수 로직(§8.2)이 이에 의존한다.

**적립 예정 금액 0원 처리**: 버림 결과가 `0` 이면 **거래 문서를 만들지 않는다** (0원 원장 노이즈 방지). 재실행해도 다시 0 이므로 멱등성에 영향 없다.

### 4.4 admin 의 직접 쓰기 (알려진 구멍, 수용)

`users.update` 는 `isAdmin()` 전권이므로 admin 은 Rules 상 `qoinBalance` 를 직접 쓸 수 있다. Console 은 애초에 Rules 를 우회한다.
→ **수용한다.** admin 은 신뢰 주체이고, 잔액만 고쳐 원장을 안 남기면 **§4.2 불변식 위반으로 탐지된다**(§8.4). 즉 "조작은 가능하지만 은폐는 불가능" 하다. admin 조정 화면은 2차 Q9.

---

## 5. 적립 / 회수 정책

### 5.1 데이터 모델

#### `users/{uid}` 추가 필드

| 필드 | 타입 | 비고 |
|---|---|---|
| `qoinBalance` | int | 현재 잔액. **필드 부재 → 0 으로 해석** (legacy 사용자 백필 마이그레이션 **불필요**, 결정 A3) |

> `UserModelFactory.fromFirestore` 는 이미 모든 필드를 방어적으로 파싱한다(`parseLaterCount` 패턴). `qoinBalance` 도 `num` 아니면 0, 음수는 **그대로 보존**(음수는 회수로 발생 가능한 정상값이므로 `parseLaterCount` 처럼 0 으로 clamp 하지 **않는다** — §8.3).

#### `users/{uid}/qoinTransactions/{txId}`

| 필드 | 타입 | 비고 |
|---|---|---|
| `txId` | string | = 문서 ID. `earn_{orderId}` / `clawback_{orderId}` |
| `type` | string | `'earn'` \| `'clawback'`. 소멸(Q6) 등 확장 여지 |
| `amount` | int | **부호 포함.** earn = 양수, clawback = 음수 |
| `balanceAfter` | int | 이 거래 직후 잔액. 감사 추적 (§4.2) |
| `orderId` | string | 근거 주문 |
| `storeId` | string | 근거 매장 |
| `storeName` | string | **비정규화.** 내역 화면에서 매장명 표시 시 추가 read 회피. 주문 문서의 `storeName` 복사 |
| `orderTotalPrice` | int | 적립 산정 기준 금액 (감사 추적) |
| `accrualRate` | number | 적립 시 적용된 비율. **정책이 바뀌어도 과거 거래의 근거가 보존**된다 |
| `createdAt` | timestamp | `FieldValue.serverTimestamp()` |

- **모든 필드가 읽힌다.** 죽은 필드를 넣지 않는다 (`store_reviews` 가 `stores.grade` 에서 배운 것).
- `clawback` 의 `accrualRate` / `orderTotalPrice` 는 원본 `earn` 거래에서 복사한다 (재계산하지 않음 — §8.2).
- **`storeName` 비정규화의 트레이드오프**: 매장이 이름을 바꾸면 과거 내역은 옛 이름으로 남는다. **의도된 동작** — 거래 당시의 사실 기록이 맞다 (주문 문서 `orders.storeName` 도 같은 방식).

#### `config/qoin` (신규 컬렉션 / 문서, §6)

| 필드 | 타입 | 비고 |
|---|---|---|
| `accrualRate` | number | 적립 비율. 예: `0.03` = 3% |
| `enabled` | bool | kill switch (F9). `false` → 적립·회수 **모두** 중단 |

> `rounding` 같은 "CF 가 읽지 않는 설정 필드" 는 **넣지 않는다.** 버림(floor)은 §5.2 로 고정이고 spec + CF 주석이 단일 진실원이다.

### 5.2 적립 금액 산식 (결정 D4-b)

```
base   = order.totalPrice           // 실제 결제 금액 (할인 적용 후). subtotal 아님
amount = floor(base * config.accrualRate)
if (amount == 0) → 거래 문서 생성하지 않음 (§4.3)
```

**버림(floor)을 쓰는 이유 2개**

1. Qoin 은 **부채**다. 반올림/올림은 없던 가치를 만든다. 금전 계산의 기본은 발행자에게 불리하지 않은 방향 — 즉 버림.
2. **회수 대칭성.** 회수는 적립 금액을 **재계산하지 않고 원장에서 읽어 반전**한다(§8.2). 따라서 반올림 방식이 바뀌어도 과거 거래의 회수가 틀어지지 않는다 — 단수 처리 방식은 적립 시점에만 영향을 준다.

`base = totalPrice` 인 이유: `OrderEntity` 는 `subtotal` / `discount` / `totalPrice` 를 모두 갖지만, 적립은 **실제로 받은 돈**에 대한 보상이다. `totalPrice` 가 할인 후 최종 결제액이다.

### 5.3 적립 트리거 시점 — `* → completed` (결정 D3)

| 선택지 | 판정 |
|---|---|
| **A. `completed` (픽업 완료) 진입 시** | ✅ **추천** |
| B. `paid` (결제 직후) 시 | ❌ |

**A 추천 근거 4개**

1. **회수 경로가 1개로 줄어든다.** `paid` 적립이면 회수가 필요한 전이가 **`paid→cancelled`(고객 취소) + `paid→cancelled`(점주 거절) + `accepted/making/ready/completed→refunded`** 로 번진다. `completed` 적립이면 **`completed→refunded` 단 하나**다.
   `paid→cancelled` 는 점주 거절 포함이라 **실제 운영에서 빈번**하다. 적립→즉시회수가 원장을 노이즈로 채우고 사용자에게 "쌓였다가 사라지는" 혼란을 준다.
2. **미픽업 주문이 자동으로 올바르게 처리된다.** 결제만 하고 안 가져간 주문(`paid`/`ready` 에서 멈춘 주문)은 **적립되지 않는다** — 소비가 발생하지 않았으므로 보상도 없다. 별도 처리 로직이 필요 없다.
3. **트리거 타입이 하나로 통일된다.** `completed` 진입과 `refunded` 진입은 모두 document **update** 다(§1.5). `onDocumentUpdated` 하나로 적립·회수를 다 잡는다. `paid` 는 create 라 트리거가 2개로 쪼개진다.
4. **`store_reviews` 와 자격 기준이 일치한다.** 평가 자격도 `completed` 다(`store_reviews/spec.md §4.2`). "픽업 완료 = 거래 정상 종료" 라는 도메인 정의를 두 기능이 공유한다.

**A 의 비용 (숨기지 않는다)**

- 사용자가 **결제 직후에 Qoin 을 못 본다.** 점주가 픽업 완료 처리를 해야 적립된다.
- 점주가 픽업 완료 처리를 **누락하면 적립되지 않는다.** → `ready` 에 머문 주문은 적립 없음. 1차는 수용하고, "적립 예정" 표시는 2차 Q3.
- → **U4 (UI 안내)로 완화한다.** Qoin 탭 / 적립 정책 문구를 "**픽업 완료 시** 결제액의 N% 적립" 으로 못박는다. "결제 시 적립" 이라고 쓰면 안 된다.

**전이 매트릭스** (`onOrderStatusChanged` 의 키 매칭 패턴 재사용)

| `before->after` | 동작 |
|---|---|
| `ready->completed` | **적립** |
| `completed->refunded` | **회수** |
| 그 외 전부 | early return (아무것도 안 함) |

> `ready->completed` 만 명시한다. Rules O7 이 `resource.status=='ready'` 를 강제하므로 `completed` 진입 경로는 이것뿐이다. 단 **admin 전권(O4)** 으로 임의 전이가 가능하므로, 매트릭스를 `*->completed` 로 넓힐지 `ready->completed` 로 좁힐지는 §13 D3-b 결정 항목으로 둔다. **추천: `*->completed`** — 적립 누락(사용자 손해)보다 admin 수동 전이도 적립하는 게 안전하고, 멱등 가드가 이중 적립을 막는다.

### 5.4 회수(환불) 정책 (결정 D5)

```
회수 금액 = earn_{orderId} 문서의 amount   (재계산하지 않는다)
earn 문서 없음 → no-op (적립된 적 없는 주문)
```

| 항목 | 결정 |
|---|---|
| 회수 범위 | **적립분 전액.** 부분 회수 없음 (`processRefund` 가 항상 전액 환불이므로 — `entity_lifecycle.md §2.5`. 부분 환불 도입 시 2차 Q11) |
| 금액 산출 | **원장에서 읽어 반전.** `floor(totalPrice * 현재 rate)` 로 재계산하지 **않는다** — 적립 후 정책이 바뀌면 회수액이 적립액과 달라져 불변식이 깨진다 |
| 적립 안 된 주문의 환불 | no-op. `accepted/making/ready → refunded` 는 `completed` 를 거치지 않았으므로 `earn` 문서가 없다 |
| 이미 쓴 Qoin 이 있는 경우 | **1차에는 발생 불가** — Qoin 사용이 2차(Q1)이므로 적립분은 반드시 잔액에 남아 있다 |
| **잔액이 음수가 될 수 있는가** | **1차: 불가능** (근거 아래). **2차 이후: 가능하며, 그때도 clamp 하지 않는다** |

#### 음수 잔액 — 왜 clamp 하지 않는가

- **1차에서 음수는 발생하지 않는다.** 사용(차감)이 없으므로 모든 잔액 변동은 `earn` 과 그 `clawback` 쌍뿐이고, 회수액은 적립액과 정확히 같다. 즉 `잔액 ≥ 0` 이 수학적으로 보장된다.
- **2차(Q1)에서는 발생할 수 있다.** 적립 100 → 100 사용 → 원 주문 환불 → 100 회수 → 잔액 −100. 사용자가 이미 가치를 썼으므로 **−100 은 사실**이다.
- **그때도 0 으로 clamp 하지 않는다.** clamp 는 `qoinBalance == Σ amount` 불변식(§4.2)을 깨뜨린다. 그 불변식이 **유일한 감사 수단**이다(§8.4). 깨면 "틀어진 것" 과 "일부러 깎은 것" 을 구분할 수 없게 되고, 감사가 영구히 무력화된다.
- 2차에서 음수를 막아야 한다면 **회수 시점이 아니라 사용 시점**에 막는다 — "잔액 범위 내에서만 사용" 가드. 이것이 Q1 의 설계 과제다.
- 1차 UI: 음수가 나올 수 없으므로 특수 표시 불필요. 단 **방어적으로 음수도 깨지지 않고 렌더되게** 한다 (designer 과제).

### 5.5 kill switch (F9)

`config/qoin.enabled == false` → CF 가 **적립도 회수도 하지 않고** `console.warn` 후 return.

- 중단 중 발생한 전이는 **소급 적립되지 않는다** (1차). 필요하면 재활성화 후 Console 로 `orders` 를 다시 건드려 트리거를 발화시킬 수 있다 — 멱등 가드가 있으니 안전하다.
- **적립만 끄고 회수는 켜두는 분리 플래그는 두지 않는다.** 적립을 끈 기간에 발생한 환불은 회수할 적립분이 애초에 없고(no-op), 적립된 주문의 환불을 막으면 불변식이 깨진다. 단일 플래그가 옳다.

---

## 6. 적립률 설정의 위치 (결정 D4)

| 선택지 | 판정 |
|---|---|
| **A. Firestore 설정 문서 `config/qoin`** | ✅ **추천** |
| B. Dart 상수 (`lib/core/constants/qoin_policy.dart`) + TS 상수 | ❌ **CF 와 클라이언트에 같은 숫자를 2번 쓴다.** drift 발생 시 "표시된 적립률 ≠ 실제 적립액" — 금전 기능에서 가장 나쁜 종류의 버그 |
| C. Firebase Remote Config | ❌ 1차에는 과대. 패키지가 **양쪽 모두 미설치**(§1.7)이고 CF 쪽은 Remote Config 서버 API 연동이 추가로 필요. 운영 도구가 필요해지면 2차 |
| D. `--dart-define` | ❌ **CF 가 못 읽는다**(§1.7). 구조적으로 불가 |

**A 추천 근거**

- CF(Admin SDK)와 클라이언트가 **같은 문서 1개**를 읽는다. 단일 진실원이 물리적으로 보장된다.
- 재배포 없이 Console 에서 비율 변경 / kill switch 조작이 가능하다 (금전 기능 운영 요구).
- 과거 거래의 `accrualRate` 가 원장에 박혀 있으므로(§5.1), 정책 변경이 과거를 소급 왜곡하지 않는다.
- 비용: 적립당 1 read 추가. 주문 완료 1건당 1 read 는 무시 가능.

**CLAUDE.md 절대 규칙 4 와의 관계**: "API key / secret / 환경별 설정값 하드코딩 금지". 적립률은 secret 이 아니라 **비즈니스 정책값**이지만, 환경·시점에 따라 바뀌고 두 런타임이 공유해야 하므로 **같은 금지의 정신이 적용된다.** Dart 상수에 박는 것은 규칙 위반으로 본다.

**신규 Rules 블록** (§8.1):

```
match /config/{docId} {
  allow read:  if isSignedIn();     // 클라이언트가 적립률 안내 문구에 사용
  allow write: if isAdmin();        // Console / admin 만
}
```

**설정 부재 / 비정상 시 동작 — fail-closed** (결정 D4-c)

| 상황 | CF 동작 |
|---|---|
| `config/qoin` 문서 없음 | `console.error` + **적립 중단** (추측한 비율로 돈을 발행하지 않는다) |
| `accrualRate` 가 number 아님 / 음수 / `> 1` | 동일 — `console.error` + 중단 |
| `enabled != true` | `console.warn` + 중단 (정상 경로) |
| 설정 read 실패 (네트워크 등) | **throw** → 트리거 재시도 (일시 장애이므로 재시도가 옳다. §9) |

> 기본값 상수를 CF 에 심어 폴백하지 **않는다.** 잘못된 비율로 조용히 적립하는 것이 적립 누락보다 나쁘다 — 누락은 원장이 비어 있어 탐지·소급 가능하지만, 잘못된 금액은 원장에 **정상 거래로 기록**돼 사후 구분이 불가능하다.
> → 그래서 `config/qoin` 생성은 **CF 배포 전 필수 선행 작업**이다 (§13 배포 체크리스트).

**클라이언트 쪽 폴백**: 설정 문서를 못 읽으면 적립률 **문구를 숨긴다** (틀린 비율을 보여주지 않는다). 잔액·내역 표시는 영향받지 않는다.

---

## 7. 인프라 변경 (배포 필요 작업)

### 7.1 Cloud Function — `onOrderQoinSettled` **신규** (결정 A1)

| 항목 | 값 |
|---|---|
| 파일 | `functions/src/onOrderQoinSettled.ts` (신규) |
| 등록 | `functions/src/index.ts` 에 `export { onOrderQoinSettled } from "./onOrderQoinSettled";` 1줄 |
| 트리거 | `onDocumentUpdated`, `document: "orders/{orderId}"` |
| region | `asia-northeast3` |

**`onOrderStatusChanged` 에 합치지 않는 이유 (A1)**

- 알림 CF 는 실패를 **swallow** 해야 한다(유실 허용, 재시도 폭주 방지). 적립 CF 는 일시 장애에서 **재시도해야** 한다(§9). 실패 정책이 정반대다.
- 알림 로직 버그가 적립을 막거나, 적립 throw 가 알림을 반복 재발송하게 만들어선 안 된다. **실패 격리**.
- 같은 문서에 `onDocumentUpdated` 트리거 2개는 Firestore 가 정상 지원한다.

**로직**

1. `before` / `after` 추출. 없으면 `console.warn` 후 return
2. `before.status === after.status` → return (`onOrderStatusChanged` 와 동일한 F8 가드)
3. 전이 키 `${before.status}->${after.status}` 를 §5.3 매트릭스에 매칭. 미정의면 return
4. `userId` / `storeId` / `storeName` / `totalPrice` 추출. `userId` 없으면 `console.error` 후 return
5. `config/qoin` read → `enabled` / `accrualRate` 검증 (§6 fail-closed)
6. 분기
   - **적립**: `amount = floor(totalPrice * accrualRate)`. `0` 이면 return. `txRef = users/{userId}/qoinTransactions/earn_{orderId}`
   - **회수**: `earnRef` read. 없으면 `console.info` 후 return (적립 안 된 주문). 있으면 `amount = -earn.amount`, `txRef = .../clawback_{orderId}`, `accrualRate`/`orderTotalPrice` 는 earn 문서에서 복사
7. `db.runTransaction` 으로 §4.2 의 의사 구조 실행
8. 결과를 구조화 로그로 남긴다 (`applied` / `already_applied` / `no_user` / `skipped_*`) — **금전 기능이므로 모든 분기에 로그**
9. 에러 처리는 §9

**금지 사항 (developer)**

- `users/{uid}` 에 **`qoinBalance` 외 어떤 필드도 쓰지 않는다** (`updatedAt` 금지)
- `orders` 문서를 **수정하지 않는다** (읽기 전용. 적립 플래그를 주문에 쓰고 싶은 유혹 → 원장 ID 가 이미 그 역할)
- 적립률을 TS 상수로 **복제하지 않는다** (§6)
- `floor` 외의 단수 처리 금지 (§5.2)

**배포**:
```bash
cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only functions:onOrderQoinSettled
```

### 7.2 Firestore Rules — 신규 블록 2개 (기존 블록 수정 0)

**① `users/{userId}/qoinTransactions/{txId}`** — `orderLogs` 블록(실측 `firestore.rules:123`)과 동일 패턴

| 작업 | 허용 | 비고 |
|---|---|---|
| read | `isAdmin() \|\| (isSignedIn() && uid() == userId)` | 본인 내역만 |
| create | `if false` | **CF(Admin SDK) 전용** |
| update | `if false` | **append-only 원장** |
| delete | `if false` | **append-only.** `orderLogs` 는 `isAdmin()` 을 허용하지만 Qoin 원장은 **admin 에게도 Rules 상 삭제를 허용하지 않는다** — 삭제는 불변식을 깨고 감사를 무력화한다. (Console 은 Rules 를 우회하므로 운영상 막히지 않는다. Rules 는 **의도 선언**으로 둔다.) |

**② `config/{docId}`** — §6

| 작업 | 허용 |
|---|---|
| read | `isSignedIn()` |
| write | `isAdmin()` |

**`users/{userId}` 블록은 한 글자도 고치지 않는다** (§1.3 — `hasOnly` 가 이미 `qoinBalance` 를 차단).
**`orders` 블록도 고치지 않는다** (CF 가 Admin SDK 로 읽는다).

> ⚠️ developer 주의: `users/{userId}` 의 **중첩 `match` 안에** `qoinTransactions` 블록을 넣어야 한다 (`orderLogs`/`favoriteStores` 와 같은 위치, `firestore.rules:123~140` 구간). 상위 `match /users/{userId}` 의 규칙은 서브컬렉션에 **상속되지 않으므로**, 블록을 안 만들면 catch-all deny 에 걸려 **본인도 내역을 못 읽는다.**

**배포**: `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only firestore:rules`

### 7.3 Firestore 인덱스 — **추가 불필요 (추정, developer 확정)**

| 쿼리 | 인덱스 |
|---|---|
| `users/{uid}/qoinTransactions` `orderBy('createdAt', descending: true).limit(50)` | **단일 필드 정렬 → 자동 인덱스.** 복합 인덱스 불필요 |
| `config/qoin` 단건 read | 불필요 |
| CF 의 `earn_{orderId}` 단건 read | 불필요 |

→ `firestore.indexes.json` **변경 없음**. §4.1 선택지 C(root 컬렉션)를 기각한 부수 이득이다.
> developer 가 에뮬레이터 실행 중 인덱스 에러 메시지로 **최종 확정**한다 (추측 금지).

### 7.4 Firestore 초기 데이터 — `config/qoin` 생성 (사용자 작업)

CF 배포 **전에** Firebase Console 에서 문서를 만들어야 한다 (§6 fail-closed).

```
컬렉션: config
문서 ID: qoin
  accrualRate : number  → <§13 D4-a 에서 확정할 값>
  enabled     : boolean → true
```

---

## 8. 보안 · 정합성 요약

### 8.1 쓰기 경로 전수 (설계 후)

| 대상 | customer | owner / brand | admin | CF |
|---|---|---|---|---|
| `users/{uid}.qoinBalance` | ❌ `hasOnly` | ❌ | ✅ 전권 (§4.4) | ✅ |
| `users/{uid}/qoinTransactions/*` | ❌ `if false` | ❌ | ❌ (Console 우회만) | ✅ |
| `config/qoin` | ❌ | ❌ | ✅ | ✅ (read 만) |
| `orders/*` | 기존 O2 만 | 기존 O1/O3/O5/O6/O7 | ✅ O4 | ✅ |

→ **고객이 Qoin 을 스스로 늘릴 경로가 0개다.** 적립의 유일한 입력은 "점주가 픽업 완료 처리한 주문" 이고, 점주는 잔액을 쓸 수 없다.

### 8.2 회수가 재계산을 쓰지 않는 것의 의미

회수액이 `earn` 원장에서 오므로:
- 적립 후 `accrualRate` 가 바뀌어도 회수액 = 적립액 (불변식 유지)
- 적립 후 `totalPrice` 가 admin 에 의해 변경돼도 영향 없음
- `earn` 문서가 없으면 회수도 없음 (유령 차감 불가)

### 8.3 clamp 금지

`qoinBalance` 는 **어디에서도 clamp 되지 않는다** — CF, Model 파싱(§5.1), UI 모두. 불변식 `qoinBalance == Σ amount` 가 §8.4 의 유일한 감사 수단이기 때문이다.

### 8.4 정합성 점검 절차 (1차 = 수동, 자동화는 Q10)

```
1. users/{uid}.qoinBalance 읽기
2. users/{uid}/qoinTransactions 전부 읽어 amount 합산
3. 두 값이 다르면 불일치 → 최신 거래의 balanceAfter 체인을 거슬러 올라가 어긋난 지점 특정
```

- 모든 거래가 `balanceAfter` 를 갖고 있으므로 **끊긴 고리를 정확히 지목**할 수 있다.
- 복구는 **잔액을 고치는 게 아니라 보정 거래를 추가**하는 방향이 원칙이다 (원장 무결성 유지). 1차에는 Console 수동.

---

## 9. 에러 처리

### 9.1 Cloud Function — **알림 CF 와 정책이 다르다**

기존 알림 CF 는 전부 swallow 한다. 적립 CF 는 **일시 장애와 영구 오류를 구분**한다.

| 케이스 | 처리 | 이유 |
|---|---|---|
| 전이 매트릭스 미정의 | `return` (로그 없음 또는 debug) | 정상. `orders` update 는 대부분 적립 무관 |
| `before.status == after.status` | `return` | 정상 |
| `config/qoin` 부재 / 비정상값 | `console.error` + **`return`** | **영구 오류.** 재시도해도 같으므로 throw 는 무한 재시도만 만든다. 적립은 중단되고 원장이 비어 있어 **탐지·소급 가능** (§6) |
| `enabled == false` | `console.warn` + `return` | 의도된 중단 |
| `userId` 부재 / `users/{uid}` 문서 없음 | `console.error` + `return` | 영구 오류 |
| `amount == 0` | `console.info` + `return` | 정상 (§4.3) |
| 거래 문서 이미 존재 | `console.info('already_applied')` + 트랜잭션 내 종료 | **정상. 멱등 가드가 동작한 것** |
| 회수 대상 `earn` 문서 없음 | `console.info` + `return` | 정상 (적립 안 된 주문의 환불) |
| Firestore read/write 일시 실패, 트랜잭션 경합 | **throw** → 트리거 자동 재시도 | **일시 장애.** 멱등하므로 재시도가 안전하고, 적립 유실보다 재시도가 옳다 |

> **swallow 금지 원칙**: 적립이 조용히 실패하면 사용자는 돈을 잃고 아무도 모른다. 일시 장애는 throw 해서 재시도하고, 영구 오류는 `console.error` 로 남겨 운영자가 보게 한다. 어느 쪽도 "조용히 넘어가지" 않는다.

### 9.2 클라이언트

| 케이스 | 처리 |
|---|---|
| 미로그인 상태로 Qoin 탭 진입 | 기존 `role_router` 가 로그인 전 진입을 차단. 방어적으로 잔액 `-` / 내역 empty |
| `qoinBalance` 필드 부재 (legacy 사용자) | **0 으로 표시.** 에러 아님 (§5.1 A3) |
| 내역 조회 permission-denied | 에러 UI + 재시도. Rules 블록 누락의 1차 증상이므로 메시지에 구분 가능한 문구 |
| 내역 조회 네트워크 실패 | 에러 UI + 재시도 |
| `config/qoin` read 실패 | **적립률 문구만 숨긴다.** 잔액·내역은 정상 표시 (§6) |
| 내역 50건 초과 | 하단 안내 "최근 50건을 보여드려요" (2차 Q5) |
| 적립 지연 (픽업 완료 후 수초) | 잔액은 프로필 스트림으로 **자동 갱신** (§1.4). 별도 처리 불필요 |

---

## 10. 레이어 설계

`docs/architecture.md` 기준. 의존 방향 `presentation → domain ← data`.

### 10.1 Domain (순수 Dart, Firebase import 금지)

| 파일 | 변경 | 내용 |
|---|---|---|
| `lib/domain/entities/user_entity.dart` | **수정** | `@Default(0) int qoinBalance` 추가 |
| `lib/domain/entities/qoin_transaction_type.dart` | 신규 | `enum QoinTransactionType { earn, clawback }` + `fromCode(String?)` / `asString` (`OrderStatus.fromCode` 패턴). 알 수 없는 값 처리는 §10.4 |
| `lib/domain/entities/qoin_transaction_entity.dart` | 신규 | `txId / type / amount / balanceAfter / orderId / storeId / storeName / orderTotalPrice / accrualRate / createdAt` (freezed) |
| `lib/domain/entities/qoin_config_entity.dart` | 신규 | `accrualRate(double) / enabled(bool)` (freezed) |
| `lib/domain/repositories/qoin_repository.dart` | 신규 | 인터페이스 (아래) |
| `lib/domain/usecases/watch_qoin_transactions_use_case.dart` | 신규 | `Stream<List<QoinTransactionEntity>>` |
| `lib/domain/usecases/watch_qoin_config_use_case.dart` | 신규 | `Stream<QoinConfigEntity?>` — 적립률 안내 문구용 |
| `lib/domain/repositories/qoin_accrual_hook.dart` | **삭제** | §1.2 (D6) |

```
abstract class QoinRepository {
  Stream<List<QoinTransactionEntity>> watchTransactions(String uid, {int limit});
  Stream<QoinConfigEntity?>           watchConfig();
}
```

- **잔액 조회 메서드를 두지 않는다.** 잔액은 `UserEntity.qoinBalance` 로 `currentUserProfileProvider` 에서 온다 (§1.4 / §4.1 A). 별 메서드를 만들면 두 번째 구독이 생기고 두 값이 어긋날 수 있다.
- **쓰기 메서드를 두지 않는다.** 클라이언트는 Qoin 을 쓸 수 없다 (§8.1). 인터페이스에 쓰기 메서드가 없는 것 자체가 설계 의도의 표현이다.

### 10.2 Data

| 파일 | 변경 | 내용 |
|---|---|---|
| `lib/data/models/user_model.dart` | **수정** | `UserModel` 에 `qoinBalance`(`@JsonKey(includeFromJson: false, includeToJson: false)`, `@Default(0)` — Firestore 전용, Auth 페이로드 아님). `UserModelFactory.fromFirestore` 에 방어적 파싱 추가. `toEntity()` 매핑. **`toFirestoreForCreate()` 에는 넣지 않는다** — `users.create` 는 고객이 수행하고 Rules 가 `brandId` 처럼 특정 필드를 검사하므로 잔액 필드를 가입 시점에 보내지 않는다 (부재 → 0 해석) |
| `lib/data/models/qoin_transaction_model.dart` | 신규 | `fromFirestore` + `toEntity`. **쓰기 메서드 없음** (CF 전용) |
| `lib/data/models/qoin_config_model.dart` | 신규 | 동일 |
| `lib/data/datasources/remote/qoin_remote_data_source.dart` | 신규 | `cloud_firestore` 직접 사용은 여기까지 |
| `lib/data/repositories/qoin_repository_impl.dart` | 신규 | Model ↔ Entity 매핑 |
| `lib/core/constants/firestore_paths.dart` | **수정** | `qoinTransactions` 서브컬렉션 키 + `userQoinTransactions(uid)` 헬퍼 + `config` / `qoinConfigDocId` 상수 (`orderLogs` / `userOrderLogs(uid)` 패턴) |
| `lib/data/repositories/no_op_qoin_accrual_hook.dart` | **삭제** | §1.2 (D6) |

```
// 내역
collection('users').doc(uid).collection('qoinTransactions')
  .orderBy('createdAt', descending: true).limit(50).snapshots()

// 설정
collection('config').doc('qoin').snapshots()
```

### 10.3 Presentation

| 파일 | 변경 | 내용 |
|---|---|---|
| `lib/presentation/customer/qoin/qoin_page.dart` | **전면 교체** | placeholder 제거. 잔액 카드 + 적립 정책 안내 + 내역 리스트 |
| `lib/presentation/customer/qoin/providers/qoin_di_providers.dart` | 신규 | DataSource / Repository / UseCase provider (`order_di_providers.dart` 패턴) |
| `lib/presentation/customer/qoin/providers/qoin_providers.dart` | 신규 | `qoinTransactionsProvider` (StreamProvider), `qoinConfigProvider` (StreamProvider) |
| `lib/presentation/customer/qoin/widgets/qoin_balance_card.dart` | 신규 | 잔액 + 적립 정책 문구 |
| `lib/presentation/customer/qoin/widgets/qoin_transaction_tile.dart` | 신규 | 내역 1건 |
| `lib/presentation/customer/checkout/checkout_page.dart` | **수정** | L122 `await ref.read(qoinAccrualHookProvider).onOrderPaid(order);` **삭제** + 미사용 import 제거 |
| `lib/presentation/customer/order/orders/providers/order_di_providers.dart` | **수정** | L60~62 `qoinAccrualHookProvider` **삭제** + 관련 import 3줄 제거 |

**잔액 출처**: `ref.watch(currentUserProfileProvider)` → `.value?.qoinBalance ?? 0`. 신규 구독 없음.

> ⚠️ `qoin_page.dart` 의 `_PlaceholderScreen` / `_QoinIcon` 은 **이 파일에만 있는 private 클래스**다 (grep 확인). 다른 placeholder 와 공유하지 않으므로 함께 삭제해도 안전하다. `QLogo` 는 공통 위젯이므로 **삭제하지 않는다**.

### 10.4 `QoinTransactionType` 미지 값 처리

`OrderStatus.fromCode` 는 미지 값을 `paid` 로 폴백한다. Qoin 은 **다르게 간다** — 미지 타입을 `earn`/`clawback` 중 하나로 폴백하면 **금액 부호와 문구가 틀어진다**.

→ `QoinTransactionType.fromCode` 는 **nullable 반환** 또는 `unknown` 멤버를 두고, UI 는 `amount` 의 **부호로 적립/회수를 판정**한다. `type` 은 표시 문구 결정에만 쓴다. 미지 타입은 "조정" 등 중립 문구로 렌더하고 금액은 부호대로 보여준다 (2차 Q6 소멸 타입이 추가될 때 구버전 앱이 깨지지 않게 하는 전방 호환).

---

## 11. 데이터 흐름

### 11.1 적립

```
점주가 픽업 완료 (owner_orders_page → MarkOrderCompletedUseCase)
  → orders/{orderId}.status: ready → completed      [Rules O7]
      ↓ (Firestore onDocumentUpdated 트리거)
  CF onOrderQoinSettled
      ├ 전이 매트릭스 매칭: ready->completed → 적립
      ├ config/qoin read → enabled / accrualRate 검증      [fail-closed]
      ├ amount = floor(order.totalPrice * accrualRate)
      └ db.runTransaction
            ├ get users/{uid}/qoinTransactions/earn_{orderId}  → 존재하면 종료 [멱등]
            ├ get users/{uid}                                   → before
            ├ set 거래문서 (amount, balanceAfter = before+amount, ...)
            └ update users/{uid}.qoinBalance = before + amount   [1필드만]
                ↓ (users/{uid} snapshots — 기존 구독)
            currentUserProfileProvider → UserEntity.qoinBalance → 잔액 카드 자동 갱신
                ↓ (qoinTransactions snapshots)
            qoinTransactionsProvider → 내역 리스트 자동 갱신
```

같은 전이에서 `onOrderStatusChanged` 가 병행 실행돼 `pickupComplete` 알림을 보낸다 (기존 동작, 상호 영향 없음).

### 11.2 회수

```
점주가 환불 승인 (owner → processRefund CF)
  → Toss cancel + orders/{orderId}.status: completed → refunded
      ↓ (onDocumentUpdated)
  CF onOrderQoinSettled
      ├ 매트릭스: completed->refunded → 회수
      ├ get earn_{orderId} → 없으면 종료 (적립 안 된 주문)
      ├ amount = -(earn.amount)                      [재계산 아님]
      └ db.runTransaction (clawback_{orderId}, 동일 구조)
```

### 11.3 조회

```
Qoin 탭 진입
  ├ 잔액  : currentUserProfileProvider (기존 구독) → UserEntity.qoinBalance
  ├ 내역  : qoinTransactionsProvider → WatchQoinTransactionsUseCase
  │           → QoinRepository → DataSource
  │           → users/{uid}/qoinTransactions orderBy createdAt desc limit 50
  └ 정책  : qoinConfigProvider → config/qoin → "픽업 완료 시 N% 적립"
```

---

## 12. 조사 중 발견한 문서 / 코드 불일치 (갱신 필요)

| # | 위치 | 현재 기술 | 실제 | 조치 |
|---|---|---|---|---|
| X1 | `docs/backlog.md:86~91` (Phase 4) | `QoinBalanceEntity`, "적립 hook 에 연결", 경로 `users/{uid}/qoinBalance` | `QoinBalanceEntity` 불필요(§1.9), hook 폐기(§1.2), 잔액은 **필드** | 구현 완료 후 절 **교체** — 1차 완료 기술 + 2차 Q1~Q11 로 대체 |
| X2 | `docs/backlog.md:16` | "고객 Qoin — `customer/qoin/qoin_page.dart:50` placeholder, Phase 4 로 분리" | 1차에서 해소 | placeholder 표에서 **제거** |
| X3 | `docs/backlog.md:79` (Phase 3a) | "Qoin 적립 hook 만 미리 마련 (실제 적립은 Qoin phase)" | hook 은 **설계가 성립하지 않아** 폐기됨 (§1.2) | 1줄 정정 — 폐기 사실과 이유 기록 |
| X4 | `docs/processes/role_flows.md:123` | "Qoin (적립금) — **미구현 — 컬렉션 미정의**" | 구현 후 해소 | customer 4.1 액션표에 Qoin 탭 진입점 + 적립 조건 기술 |
| X5 | `docs/processes/role_flows.md:215` | "Qoin 적립 / 사용 — 미구현, `no_op_qoin_accrual_hook` placeholder 만 존재" | 적립은 구현, **사용은 여전히 2차(Q1)**. hook 은 삭제됨 | 적립/회수 = 구현, 사용 = 미구현으로 **분리 기술** |
| X6 | `docs/processes/data_ownership.md §2.1` | `users` 변경 가능 필드 목록에 `qoinBalance` 없음 | 신규 필드. **고객 쓰기 불가, CF 전담** | "Cloud Function 전담: 없음" → `qoinBalance` 1건 추가 |
| X7 | `docs/processes/data_ownership.md §2` | `users/{uid}/qoinTransactions` / `config` 컬렉션 항목 없음 | 신규 | §2.3 다음에 두 절 신규 추가 (`orderLogs` 절 형식) |
| X8 | `docs/processes/data_ownership.md §3` CF 카탈로그 | `onOrderQoinSettled` 없음 | 신규 | 카탈로그 1행 추가. §3 일반 규칙의 **두 번째 적용 사례**로 명시 |
| X9 | `docs/processes/entity_lifecycle.md §2.2` | `ready→completed` 후속 액션에 `store_reviews` 만 기재. `completed→refunded` 에 Qoin 언급 없음 | 두 전이 모두 Qoin 부수 효과 발생 | 두 행에 1줄씩 추가. **status 전이 자체는 불변** (Qoin 은 전이를 만들지 않으므로 다이어그램 변경 없음) |

> Qoin 거래는 status 필드가 없는 **append-only 원장**이므로 `entity_lifecycle.md` 에 전이 다이어그램을 추가하지 않는다 (`reviews` 와 같은 판단).

---

## 13. 테스트 전략 — 실행 가능성 우선

**토스가 Mock 모드이고 전자결제 심사 중이므로 실결제는 쓸 수 없다.**
`store_reviews §9.4` 가 Console 수동 주문으로 실결제 0회를 달성한 사례를 확장한다. **1차 범위에 실결제가 필요한 시나리오는 없다.**

### 13.1 Rules 검증 — `test_rules/rules.test.mjs` 확장 (결제 0회)

**환경**: `cd /Users/Byeonguk/Developer/OrderApp && firebase emulators:start --only firestore` (포트 8137), 별 터미널에서 `cd /Users/Byeonguk/Developer/OrderApp && node test_rules/rules.test.mjs`
**시드**: `withSecurityRulesDisabled` 로 `users/{CUSTOMER}.qoinBalance = 500`, `users/{CUSTOMER}/qoinTransactions/earn_o1`, `config/qoin` 주입

| # | 시나리오 | 기대 |
|---|---|---|
| QR1 | CUSTOMER 가 본인 `qoinTransactions` 목록 read | allow |
| QR2 | OTHER 가 CUSTOMER 의 `qoinTransactions` read | **deny** |
| QR3 | 비로그인 read | deny |
| QR4 | CUSTOMER 가 본인 `qoinTransactions` 문서 create | **deny** (CF 전용) |
| QR5 | CUSTOMER 가 본인 거래 문서 update (`amount` 변경) | **deny** (append-only) |
| QR6 | CUSTOMER 가 본인 거래 문서 delete | **deny** (append-only) |
| QR7 | admin 이 거래 문서 delete | **deny** (§7.2 의도적 — `orderLogs` 와 다른 점) |
| QR8 | admin 이 CUSTOMER 거래 문서 read | allow |
| QR9 | **CUSTOMER 가 본인 `users/{uid}.qoinBalance` 직접 update** | **deny** ← §1.3 회귀 방지, **가장 중요** |
| QR10 | CUSTOMER 가 `qoinBalance` + `displayName` 을 함께 update | **deny** (`hasOnly` 위반) |
| QR11 | OWNER 가 타인 `qoinBalance` update | deny |
| QR12 | admin 이 `qoinBalance` update | allow (§4.4 수용) |
| QR13 | CUSTOMER 가 `config/qoin` read | allow |
| QR14 | CUSTOMER 가 `config/qoin` write | **deny** |
| QR15 | OWNER 가 `config/qoin` write | **deny** |
| QR16 | admin 이 `config/qoin` write | allow |
| QR17 | 비로그인 `config/qoin` read | deny |
| QR18 | 내역 쿼리 `orderBy createdAt desc limit 50` | allow (인덱스 동작 확인 겸용, §7.3) |

### 13.2 Cloud Function 검증 — 에뮬레이터 (결제 0회)

**환경**:
```bash
cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build
cd /Users/Byeonguk/Developer/OrderApp && firebase emulators:start --only firestore,functions
```
**시드**: 에뮬레이터 Firestore 에 `users/{U}`, `config/qoin {accrualRate: 0.03, enabled: true}`, `orders/{O}` (status=`ready`, userId=U, storeId, storeName, totalPrice=`4500`)

> ⚠️ 트리거가 `onDocumentUpdated` 이므로 **문서를 `completed` 로 바로 생성하면 발화하지 않는다.** 반드시 `ready` 로 만든 뒤 `completed` 로 **수정**해야 한다. (tester 필수 인지 사항)

| # | 시나리오 | 기대 |
|---|---|---|
| QC1 | `ready → completed` (totalPrice=4500, rate=0.03) | `earn_{O}` 생성, `amount=135`, `balanceAfter=135`, `users.qoinBalance=135` |
| QC2 | 단수 처리 — totalPrice=`4100`, rate=0.03 (=123.0) / totalPrice=`4150` (=124.5) | 각각 `123` / `124` (**버림**) |
| QC3 | **이중 적립 방지** — QC1 후 같은 주문을 `completed→completed` 가 아닌 방식으로 재발화 (Console 에서 무관 필드 수정 후 status 왕복) | 거래 문서 1개, `qoinBalance` 불변. 로그 `already_applied` |
| QC4 | `completed → refunded` (QC1 이후) | `clawback_{O}` 생성, `amount=-135`, `balanceAfter=0`, `users.qoinBalance=0` |
| QC5 | **이중 회수 방지** — QC4 재발화 | 거래 문서 1개, 잔액 불변 |
| QC6 | 적립 없는 주문의 환불 — `accepted → refunded` | 거래 문서 **생성 안 됨**, 잔액 불변, 로그에 skip 사유 |
| QC7 | `paid → accepted` / `accepted → making` / `making → ready` | 전부 **no-op** (매트릭스 미정의) |
| QC8 | `config/qoin` 문서 삭제 후 `ready → completed` | **적립 안 됨** + `console.error` (fail-closed §6) |
| QC9 | `config/qoin.enabled = false` 후 `ready → completed` | 적립 안 됨 + `console.warn` |
| QC10 | `accrualRate` 를 문자열 `"0.03"` 으로 설정 후 전이 | 적립 안 됨 + `console.error` |
| QC11 | 적립액 0 — totalPrice=`10`, rate=0.03 (=0.3 → 0) | 거래 문서 **생성 안 됨**, 잔액 불변 |
| QC12 | `users/{uid}` 문서 없는 주문 | 적립 안 됨 + `console.error`, 예외 전파 없음 |
| QC13 | **`users/{uid}` 2필드 불변** — 적립 전후 `displayName`/`role`/`updatedAt`/`notificationSettings` 비교 | `qoinBalance` **1필드만** 변경 (§4.2) |
| QC14 | **`orders` 문서 불변** — 적립 전후 주문 문서 비교 | CF 가 주문을 수정하지 않음 (§7.1 금지사항) |
| QC15 | **불변식 검증** — 적립 3건 + 회수 1건 후 | `qoinBalance == Σ amount` (§4.2) |
| QC16 | `balanceAfter` 체인 — QC15 의 거래들을 `createdAt` 순으로 | 각 `balanceAfter` 가 누적합과 일치 (§8.4) |
| QC17 | **알림 CF 와의 공존** — `ready → completed` 시 | `onOrderStatusChanged` 와 `onOrderQoinSettled` 가 **둘 다** 실행 (로그로 확인) |
| QC18 | `accrualRate = 0` | 적립액 0 → 거래 문서 없음 (QC11 과 동일 경로) |

### 13.3 Dart 단위 테스트 (환경 불필요)

| # | 대상 | 내용 |
|---|---|---|
| QU1 | `UserModelFactory.fromFirestore` | `qoinBalance` 부재 → 0 / `int` → 그 값 / `double 135.0` → 135 / 문자열 → 0 / **음수 `-100` → `-100` 보존** (clamp 금지 §8.3) |
| QU2 | `QoinTransactionModel.fromFirestore` | 필드 누락 / `type` 미지 문자열 / `amount` 부호 / `createdAt` 비-Timestamp |
| QU3 | `QoinTransactionType.fromCode` | `'earn'` / `'clawback'` / 미지 값 (§10.4 — `earn` 폴백이 **아님**을 확인) |
| QU4 | `QoinConfigModel.fromFirestore` | `enabled` 부재 → `false` (fail-closed) / `accrualRate` 비-number → 무효 처리 |
| QU5 | 내역 표시 포맷 순수 함수 | 부호 표기 (`+135` / `-135`), 0, 음수 잔액 |

**실행**: `cd /Users/Byeonguk/Developer/OrderApp && flutter test`

> `flutter test` 에는 **적립 계산 로직 테스트가 없다** — 산식은 CF(TypeScript) 에만 있고 Dart 에 복제하지 않기 때문이다(의도). 산식 검증은 QC1/QC2/QC11/QC18 이 담당한다.

### 13.4 수동 UI 검증 — **실결제 0회**

`orders.create` 는 `if false` 지만 **Console 은 Rules 를 우회**한다 (`store_reviews §1.6` 선례).

**준비 (Firebase Console, 결제 없음)**

1. `config/qoin` 문서 생성 (§7.4)
2. `orders` 에 문서 수동 생성 — **status 를 `ready` 로 만든다** (`completed` 로 바로 만들면 트리거가 안 돈다)
```
문서 ID: manual_qoin_test_01
userId: <내 uid>          storeId: <테스트 매장 id>      storeName: <이름>
status: "ready"            totalPrice: 4500               subtotal: 4500
createdAt / updatedAt / readyAt: 현재 시각 (Timestamp)
items: []                  paymentInfo: {}
```

| # | 시나리오 | 결제 |
|---|---|---|
| QM1 | Qoin 탭 진입 → placeholder 사라지고 잔액 `0 Qoin` + 적립 정책 문구 + 내역 empty | 불필요 |
| QM2 | Console 에서 `status` 를 `completed` 로 수정 → **앱을 건드리지 않고** 수초 내 잔액이 `135` 로 자동 갱신 | 불필요 |
| QM3 | 내역에 매장명 / `+135` / 일시 / `적립` 표시 | 불필요 |
| QM4 | Console 에서 `status` 를 `refunded` 로 수정 → 잔액 `0`, 내역에 `-135` `회수` 2건째 추가 | 불필요 |
| QM5 | `config/qoin.accrualRate` 를 `0.05` 로 변경 → 적립 정책 문구가 `5%` 로 갱신 | 불필요 |
| QM6 | `config/qoin.enabled = false` → 새 주문 전이에 적립 없음 | 불필요 |
| QM7 | 내역 50건 초과 상태 (Console 로 다건 주입) → 안내 문구 노출 | 불필요 |
| QM8 | 내역 로딩 / 에러(기기 오프라인) / empty 3상태 | 불필요 |
| QM9 | **hook 제거 회귀** — Mock 결제로 주문 1건 생성 → 결제 성공 흐름이 정상 (L122 삭제로 깨지지 않음), 장바구니 비워짐, 결과 페이지 진입 | **Mock 결제** (실결제 아님) |
| QM10 | 적립 직후 다른 탭 → Qoin 탭 복귀 시 값 유지 (`IndexedStack`) | 불필요 |

> QM2 가 이 task 의 핵심 검증이다 — **앱에서 아무 동작도 하지 않았는데 Console 의 status 변경만으로 잔액이 갱신된다.** §1.4 의 무료 구독 설계가 동작함을 증명한다.
> QM9 는 §10.3 의 `checkout_page.dart` L122 삭제가 결제 흐름을 깨지 않았는지 확인하는 **회귀 테스트**다. Mock 모드이므로 실제 과금 없음.

---

## 14. 작업 분배

### designer — **호출 필요 (필수)**

Qoin 탭 **화면 전체가 신규**다 (placeholder → 실화면). UI 비중이 크다.

산출물: `docs/tasks/qoin/design.md`

1. **`qoin_page`** — 잔액 카드 + 적립 정책 안내 + 내역 리스트의 전체 레이아웃. 기존 `HomeHeader` 가 상단에 이미 있는 **탭 내부 화면**임에 주의 (`scaffold_with_nav.dart` 의 `IndexedStack` child — 자체 AppBar 를 두지 않는다)
2. **`qoin_balance_card`** — 잔액 표기. **단위 표기 확정 필요**: `1,200 Qoin` / `1,200 Q` / 숫자 + Q 로고 중 무엇인가 (§13 A5). `QLogo` 위젯 활용 여부 판단. 0 / 큰 수 / **음수**(2차 대비 방어) 렌더
3. **적립 정책 문구** — "**픽업 완료 시** 결제액의 N% 적립" (U4). **"결제 시 적립" 로 쓰면 안 된다** (§5.3 — 사용자가 결제 직후 잔액을 찾다가 혼란). `config` 미로딩 시 문구를 숨기는 상태도 정의
4. **1차는 Qoin 을 쓸 수 없음 안내** (U5) — 톤 결정. 숨기지 말고, 기대만 부풀리지도 말 것
5. **`qoin_transaction_tile`** — 매장명 / 금액(부호) / 일시 / 사유. **적립과 회수의 시각적 구분** (`AppColors.success` / `AppColors.error` 사용 여부 판단). 미지 타입의 중립 렌더(§10.4)
6. **상태 UI 3종** — 내역 loading(Shimmer) / error(재시도) / empty("아직 적립 내역이 없어요" + 적립 조건 안내). **잔액 0 은 empty 가 아니라 정상 상태**
7. **내역 상한 안내** — 50건 초과 시 하단 문구 (§9.2)
8. **탭 아이콘** — `bottom_nav.dart:46` 의 `QLogo` 유지 여부 (현재 Qoin 탭 아이콘이 앱 로고와 동일하다 — 실화면이 생긴 뒤에도 적절한지 판단)

용어: 앱 화폐 = **Qoin**, 사용자 = **Qrator**, 주문 내역 = **Log**. 색상은 `AppColors` 만 (`Color(0x...)` 금지).
답글·사용·선물 등 2차(Q1~Q11) UI 는 **넣지 말 것**.

### developer — **호출 필요**

산출물: `docs/tasks/qoin/implementation.md`

구현 순서 (의존 역순):

1. **`firestore.rules`** 신규 블록 2개 (§7.2) — `qoinTransactions` 는 **`users/{userId}` 중첩 match 안**에. **`users` / `orders` / `stores` 블록은 건드리지 말 것**
2. **`functions/src/onOrderQoinSettled.ts`** + `index.ts` export (§7.1)
3. `FirestorePaths` 상수 추가 (§10.2)
4. Domain: `UserEntity` 수정 + 신규 Entity 3종 + `QoinRepository` + UseCase 2종 → `dart run build_runner build --delete-conflicting-outputs`
5. Data: `UserModel`/`UserModelFactory` 수정 + Model 2종 + DataSource + RepositoryImpl
6. Presentation: DI providers → `qoin_page` 교체 → widget 2종
7. **hook 제거 (D6)** — 4곳: `qoin_accrual_hook.dart` 삭제 / `no_op_qoin_accrual_hook.dart` 삭제 / `order_di_providers.dart:60~62` + import 제거 / `checkout_page.dart:122` + import 제거
8. `test_rules/rules.test.mjs` 확장 (§13.1)
9. `flutter analyze` 0 issue + `flutter test` 전건 PASS

**주의**

- `cloud_firestore` import 는 **`data` 레이어만** (CLAUDE.md 절대 규칙 2)
- `AppColors` 만 사용, `Color(0x...)` 금지 (절대 규칙 3)
- **적립률을 Dart 상수 / TS 상수 / `--dart-define` 에 복제하지 말 것** (§6, 절대 규칙 4)
- CF 는 `users/{uid}` 에 **`qoinBalance` 1필드만** 쓴다. `updatedAt` 금지 (§4.2)
- CF 는 `orders` 를 **수정하지 않는다** (§7.1)
- 단수 처리는 **버림(floor)** 고정. `Math.round` / `Math.ceil` 금지 (§5.2)
- 회수액은 **`earn` 문서에서 읽는다.** 재계산 금지 (§5.4)
- 잔액은 **어디서도 clamp 하지 않는다** — CF / Model 파싱 / UI 전부 (§8.3). `parseLaterCount` 의 음수→0 패턴을 따라하지 말 것
- 잔액은 트랜잭션 read 기반 **절대값 쓰기**. `FieldValue.increment` 아님 (`balanceAfter` 정합성, §4.2)
- `QoinRepository` 에 **쓰기 메서드를 추가하지 말 것** (§10.1)
- `qoin_page.dart` 삭제 시 `QLogo`(공통 위젯)는 **남긴다** (§10.3)
- CF 에러 처리는 **swallow 금지.** 일시 장애는 throw, 영구 오류는 `console.error` + return (§9.1). 기존 알림 CF 의 swallow 패턴을 복사하지 말 것

### tester — **호출 필요**

산출물: `docs/tasks/qoin/test_report.md`

§13 전부 수행. **보류 사유로 "실결제 필요" 는 받지 않는다** — §13.4 가 Console 수동 주문으로 실결제를 제거했다 (QM9 만 Mock 결제).

**반드시 실행할 보안 / 정합성 회귀 테스트**

- **QR9 / QR10** — 고객의 `qoinBalance` 직접 쓰기 차단 (§1.3 회귀 방지). **이 task 에서 가장 중요한 테스트**
- **QR4 / QR5 / QR6 / QR7** — 원장 append-only 강제
- **QC3 / QC5** — 이중 적립 / 이중 회수 방지 (멱등성)
- **QC13 / QC14** — CF 가 `qoinBalance` 1필드만 쓰고 `orders` 를 안 건드림
- **QC15 / QC16** — 불변식 `qoinBalance == Σ amount` 와 `balanceAfter` 체인
- **QC8 / QC10** — fail-closed (설정 없거나 비정상이면 적립하지 않음)
- **QM9** — hook 제거가 결제 흐름을 깨지 않음

**필수 인지 사항**: 트리거가 `onDocumentUpdated` 이므로 `orders` 문서를 `completed` 로 **생성**하면 발화하지 않는다. 반드시 `ready` 로 만든 뒤 **수정**해야 한다 (§13.2 경고).

---

## 15. 사용자 확인이 필요한 결정사항 — **전건 확정 (2026-10-22)**

**D1~D7 / A1~A6 모두 확정됐다.** 아래 4건은 사용자에게 직접 확인했고, 나머지는 실측 근거로 추천안을 수용했다.

| # | 항목 | 확정 | 방식 |
|---|---|---|---|
| **D4-a** | 적립률 | **기본 3%** (`accrualRate: 0.03`), `enabled: true` | 사용자 직접 확인 |
| **D4-d (신규)** | 적립률 **관리자 화면** | **1차에 포함.** `config/qoin` 의 `accrualRate` + `enabled` 를 admin 앱에서 편집 | 사용자 직접 확인 |
| **D3** | 적립 시점 `completed` 의 UX 비용 | **수용.** 결제 직후엔 Qoin 이 보이지 않는다 — UI 문구로 안내(§U4) | 사용자 직접 확인 |
| **A5** | 단위 표기 | **`1,200 Q`** | 사용자 직접 확인 |
| D1·D2·D5·D6·D7 | 저장 위치 / 신뢰 원천 / 회수 / hook 제거 / 멱등성 | 추천안 수용 | 실측 근거 |
| A1~A4·A6 | — | 추천안 수용 | — |

### D4-d — 관리자 화면을 1차에 넣는 이유 (설계 변경)

최초 판단은 "admin 운영 도구가 없으니 Console 로 두고 2차" 였으나 **틀렸다.**
실측 결과 `lib/presentation/admin/` 에 **화면이 14개** 있고(`approval` / `brand_store_management` / `menu_categories` / `more`), 이미 운영 설정을 다루고 있다. 적립률 화면만 따로 2차로 미룰 이유가 없다.

Rules 도 이미 `match /config/{docId} { allow write: if isAdmin(); }` 로 설계돼 있어 **권한 작업이 추가로 필요 없다.**

**범위**: `accrualRate`(%) 입력 + `enabled` 토글 **두 값만**.
- `enabled` 토글을 함께 두는 이유: 적립에 문제가 생겼을 때 **재배포 없이 즉시 중단**할 수 있는 안전장치다. 돈이 걸린 기능에는 끄는 수단이 있어야 한다.
- **사용자 잔액 직접 조정은 1차 범위 밖**(Q9 유지). 원장 무결성·감사 추적 설계가 추가로 필요해 범위가 커진다.

**입력 검증 필수**: `3`(퍼센트)과 `0.03`(비율)을 혼동하면 적립이 100배가 된다. 화면은 **퍼센트로 입력받고 저장 시 100 으로 나눈다.** 상한도 둔다 (§designer 에 전달).

---

### (원문) 결정사항과 선택지

요구사항의 ①~⑦ 은 전부 아래에 매핑했다. **D4-a(적립률 값) 1건은 비즈니스 정책이라 architect 가 결정할 수 없다.**

| # | 결정 항목 | 선택지 | **추천안** | 상태 |
|---|---|---|---|---|
| **D1** | **저장 위치** (①) | A: `users.qoinBalance` 필드 + `users/{uid}/qoinTransactions/` / B: `users/{uid}/qoin/{doc}` / C: root `qoinTransactions/` | **A.** 잔액 조회 **0 read**(기존 프로필 구독에 포함, §1.4) + `users` Rules **변경 0**(§1.3) + 복합 인덱스 **0**(§7.3) + `orderLogs` 선례 복제 | 추천 — 실측 근거 |
| **D2** | **잔액의 신뢰 원천** (②) | A: 트랜잭션 안에서 원장 생성 + 잔액 갱신 / B: `onReviewWritten` 식 전량 재계산 / C: `increment` 단독 | **A.** `onReviewWritten` 과 **의도적으로 다르게 간다** — ① 원장이 append-only 라 증분의 약점(delta 보정)이 없고 ② **비용 차이는 유의하지 않으며**(per-user 집계는 1 read) ③ 결정적으로 **2차 Q1(사용)과 양립 불가**(재계산 overwrite 가 차감과 레이스 → 쓴 Qoin 부활) ④ `balanceAfter` 감사 추적 가능. 대가는 자기 치유 약화 → 불변식 **탐지**(§8.4)로 대체 | 추천 — §4.2 |
| **D3** | **적립 트리거 시점** (③) | A: `* → completed` / B: `paid` 즉시 | **A(`completed`).** 회수 경로가 **1개**로 줄고(`completed→refunded`), 미픽업·취소 주문이 자동으로 올바르게 처리되고, 트리거 1개로 통일되고, `store_reviews` 의 자격 기준과 일치. 대가는 "결제 직후 Qoin 안 보임" → U4 안내로 완화 | 추천 — §5.3 |
| **D3-b** | 매트릭스 범위 | `ready->completed` 만 / `*->completed` | **`*->completed`.** admin 전권(Rules O4) 수동 전이도 적립. 적립 누락(사용자 손해)보다 안전하고 멱등 가드가 이중 적립을 막는다 | 추천 |
| **D4** | **적립률의 위치** (④) | A: `config/qoin` Firestore 문서 / B: Dart+TS 상수 / C: Remote Config / D: `--dart-define` | **A.** CF 와 클라이언트가 **같은 문서 1개**를 읽는다 — B 는 숫자 2곳 복제로 "표시 ≠ 실제" drift, C 는 양쪽 패키지 미설치로 과대, D 는 **CF 가 읽을 수 없다**(§1.7) | 추천 — §6 |
| **D4-a** | **적립률 값과 kill switch 초기값** | 비율 n% / 정액 | **⚠️ 사용자 결정 필요.** architect 추천: **비율 3% (`accrualRate: 0.03`), `enabled: true`**. 비율을 추천하는 이유 — 정액은 소액 주문에서 결제액보다 적립이 커질 수 있고 객단가 변화에 대응이 안 된다. 3% 는 흔한 카페 적립 수준이지만 **수익 구조는 사용자만 안다** | **미결정** |
| **D4-b** | 단수 처리 | 버림 / 반올림 / 올림 | **버림(floor).** Qoin 은 부채 — 올림·반올림은 없던 가치를 발행한다. 회수가 원장 반전이라 단수 방식 변경이 과거를 깨지 않는다 | 추천 — §5.2 |
| **D4-c** | 설정 부재 시 동작 | fail-closed(적립 중단) / 기본값 폴백 | **fail-closed.** 틀린 비율로 조용히 적립하면 원장에 **정상 거래로 기록**돼 사후 구분이 불가능하다. 적립 누락은 원장이 비어 있어 탐지·소급 가능 | 추천 — §6 |
| **D5** | **회수 정책** (⑤) | 적립분 전액 / 비례 / 회수 없음 | **적립분 전액.** 금액은 `earn` 원장에서 **읽어 반전**(재계산 금지 — 정책 변경 시 불변식 깨짐). `earn` 없으면 no-op | 추천 — §5.4 |
| **D5-b** | **음수 잔액 허용 여부** | 허용(clamp 금지) / 0 clamp / 환불 차단 | **clamp 금지.** **1차에는 음수가 수학적으로 발생 불가**(사용 없음 → 회수액 == 적립액). 2차에는 발생 가능하고 **그것은 사실**이므로 clamp 하지 않는다 — clamp 는 불변식을 깨 **유일한 감사 수단을 영구 무력화**한다. 음수 방지는 2차의 **사용 시점 가드**가 담당 | 추천 — §5.4 |
| **D6** | **`QoinAccrualHook` 처리** (⑥) | 제거 / 유지 / 역할 재정의 | **완전 제거** (4곳: 인터페이스·NoOp·provider·`checkout_page.dart:122`). §1.2 — 환불/취소가 CF 전담이라 `onOrderRefunded` 를 **호출할 클라이언트 지점이 존재할 수 없다.** 설계가 성립하지 않는 인터페이스다. NoOp 를 남기면 "적립되는 것처럼 보이는 죽은 코드" 가 되어 **이 task 의 문제 인식 자체를 왜곡했던 것처럼** 또 오해를 만든다 (`store_reviews` 의 `stores.grade` 죽은 필드와 같은 교훈) | 추천 — §1.2 |
| **D7** | **멱등성** (⑦) | 결정적 문서 ID + 트랜잭션 가드 / 주문 문서에 플래그 / 없음 | **결정적 ID `earn_{orderId}` / `clawback_{orderId}` + 트랜잭션 내 선존재 가드.** `orderId` 는 Toss orderId(uuid v4) 로 주문당 유일. 재시도·중복 트리거가 무해한 no-op 이 되고, "적립됐는가" 를 **쿼리 없이 단건 read** 로 확인 가능(회수 로직이 이에 의존) | 추천 — §4.3 |
| **A1** | CF 분리 vs `onOrderStatusChanged` 확장 | 신규 CF / 기존 확장 | **신규 CF `onOrderQoinSettled`.** 실패 정책이 정반대(알림=swallow, 적립=재시도) + 실패 격리 | 추천 — §7.1 |
| **A2** | CF 실패 처리 | 일시/영구 구분 / 전부 swallow / 전부 throw | **구분.** 일시 장애 throw(재시도, 멱등하므로 안전) / 영구 오류 `console.error`+return. **기존 알림 CF 의 전면 swallow 를 복사하지 않는다** | 추천 — §9.1 |
| **A3** | legacy 사용자 `qoinBalance` 백필 | 마이그레이션 없음(부재→0) / 전체 백필 | **마이그레이션 없음.** 방어적 파싱으로 부재를 0 으로 읽는다. 첫 적립 시 CF 가 필드를 만든다 | 추천 |
| **A4** | 내역 상한 | `limit(50)` / 페이지네이션 | **`limit(50)`.** 페이지네이션은 2차 Q5 (`store_reviews` 의 R8 과 동일 판단) | 추천 |
| **A5** | **Qoin 단위 표기** | `1,200 Qoin` / `1,200 Q` / 숫자+Q로고 | **designer 과제 + 사용자 취향.** architect 는 확정하지 않는다. 브랜드 표기이므로 §14 designer 항목 2 로 넘긴다 | **designer/사용자** |
| **A6** | 인덱스 추가 | 불필요 / 필요 | **불필요** (서브컬렉션 단일 필드 정렬). developer 가 에뮬레이터 에러 메시지로 **최종 확정** | 추천 — §7.3 |

### 배포가 필요한 작업 (사용자 손이 필요)

순서가 중요하다 — **③ 을 ② 보다 먼저** 해야 한다 (fail-closed, §6).

1. **Firebase Console 에서 `config/qoin` 문서 생성** — `accrualRate` (D4-a 확정값), `enabled: true` (§7.4)
2. `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only firestore:rules` — 신규 블록 2개
3. `cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only functions:onOrderQoinSettled` — **신규 CF**
4. (인덱스는 §7.3 기준 **배포 불필요**. developer 가 필요하다고 확정하면 `firebase deploy --only firestore:indexes` 추가)

> 1 을 건너뛰고 3 을 배포하면 적립이 **전부 조용히 중단**된다 (의도된 fail-closed). 로그에 `console.error` 가 남으므로 탐지는 되지만, 그 사이 완료된 주문은 **소급 적립되지 않는다**.

---

## 16. 완료 기준

- [ ] `firestore.rules` 신규 블록 2개 배포 + QR1~QR18 전건 PASS (특히 **QR9 / QR10**)
- [ ] `onOrderQoinSettled` CF 배포 + QC1~QC18 전건 PASS (특히 **QC3 / QC5 / QC13 / QC15**)
- [ ] `config/qoin` 문서 생성 완료 (D4-a 확정값)
- [ ] `flutter analyze` 0 issue / `flutter test` 전건 PASS (QU1~QU5 포함)
- [ ] QM1~QM10 수동 검증 PASS, **실결제 0회** (QM9 만 Mock 결제)
- [ ] `QoinAccrualHook` / `NoOpQoinAccrualHook` / `qoinAccrualHookProvider` / `checkout_page.dart:122` **전부 제거되고 grep 결과 0건**
- [ ] `qoin_page.dart` 에 `준비 중입니다` 문자열이 **존재하지 않음**
- [ ] 불변식 `users.qoinBalance == Σ qoinTransactions.amount` 가 QC15 에서 검증됨
- [ ] `backlog.md` / `role_flows.md` / `data_ownership.md` / `entity_lifecycle.md` 갱신 (§12 X1~X9)
- [ ] **Console 에서 주문 status 를 `completed` 로 바꾸면 앱을 건드리지 않고도 Qoin 잔액이 수초 내 증가하는 것이 눈으로 확인됨** (= 이 task 의 목적)
