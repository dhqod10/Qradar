# prelaunch_security_bundle 기능 명세

> 런칭 전 **자기거래(self-dealing) 방어 묶음**. Q3 Layer1(자기거래 가드) + Layer2(신호수집 선제) + D2(점주 self-approve 가드)를 한 배포 묶음으로 설계한다.
> 근거: `docs/backlog.md` "Q3 결정 (2026-10-29)", "[분리] stores/menuItems 점주 분기 self-approve (D2)". 참조: `docs/processes/entity_lifecycle.md §5.3/§5.4`, `docs/processes/data_ownership.md §2.4/§2.6/§2.10/§2.13`, `docs/processes/audit_trail.md §4`.

작성: 2026-10-31 (architect)

---

## 개요

- **목적**: 점주/브랜드 보유자가 **자기 매장**을 상대로 거래·평가·적립을 만들어 매출/등급/Qoin 을 조작하는 경로를 런칭 전에 닫는다. 동시에, 코드로는 못 막는 부계정(sock-puppet) 어뷰징의 **사후 탐지를 위한 신호를 미리 수집**해 둔다. 함께, 점주의 메뉴 자가승인(admin 검토 우회) 구멍을 닫는다.
- **작업 유형**: 기존 기능 수정(보안 하드닝) 3건.
  - **Q3 Layer1 — 자기거래 가드** (서버 전담): 결제 거절 + 자기 리뷰 차단 + Qoin 자기적립 제외.
  - **Q3 Layer2 — 신호수집 선제**: 기기 식별자 / 카드 지문(해시) / IP 저장. **탐지·플래그·admin UI 는 비범위**.
  - **D2 — 점주 stores/menuItems self-approve 가드** (Rules): 독립매장 vs 가맹매장 분기 보존.
- **영향 범위**:
  - 화면: 거의 없음. 자기거래 결제 거절 시 체크아웃 **에러 문구 1개** 추가(기존 `VerifyPaymentFailure` 경로 재사용). 신규 화면 없음.
  - Domain: 없음(엔티티/UseCase 신규 없음). 기존 결제 UseCase 흐름 유지.
  - Data: 클라이언트가 `verifyTossPayment` 호출에 `deviceId` 1필드 추가(Layer2). `clientLevel` 과 동일 패턴.
  - Cloud Functions: `verifyTossPayment`(Layer1 결제 거절 + Layer2 신호 write), `onOrderQoinSettled`(Qoin 자기적립 제외).
  - Firestore Rules: `reviews`(자기리뷰 차단), `stores/{id}/menuItems` 점주 분기(D2), `orderSignals/{orderId}`(신규 컬렉션 — admin read, client write 전면 차단).
  - 공통 컴포넌트: 설치 식별자(install id) 확보용 소형 core 유틸 1개(Layer2).
  - 라우팅: 없음.
  - 권한/환경: Rules 재배포 + functions 재배포 2단위.
- **비범위**:
  - Layer2 **탐지·룰·플래그·admin 검토 UI** (프로젝트급 — backlog Q3 결정의 Layer2 본체).
  - Qoin **사용(spend)** / 적립률 계층화 변경 (backlog Q2, 별 task).
  - 등급 최소 리뷰 수(`grade_min_reviews`) — 별 task.
  - App Check, 스토어/콘솔 작업, 부분환불.
  - **부계정(다른 uid) 우회 차단** — Layer1 로는 불가능(명시). Layer2 데이터가 쌓여야 Layer2(탐지)에서 다룬다.

---

## 핵심 공통 개념 — "자기 매장(self store)" 판정

세 건 모두 **"주문자/작성자 uid 가 그 매장의 이해관계자인가"** 를 판정한다. 신뢰원을 하나로 고정한다.

| 판정 입력 | 신뢰원 | 비고 |
|---|---|---|
| 점주 자기거래 | `stores/{storeId}.ownerId == uid` | 매장 문서의 ownerId 가 유일 신뢰원 |
| 브랜드 보유자 자기거래 | `stores/{storeId}.brandId` 가 비어있지 않고 `users/{uid}.role=='brand' && users/{uid}.brandId == stores/{storeId}.brandId` | `isBrandHolder` 와 **동일 규칙**(공백 매칭 차단). 주문/카트의 brandId 는 **쓰지 않는다**(클라 값) |

**isSelfDealing(uid, store) = (store.ownerId == uid) OR (store.brandId 유효 AND buyer 가 그 brandId 의 보유자)**

- 이 판정은 `canSellNow`/`storeSellability` 와 같은 "**한 사실을 양쪽에 포팅**" 패턴을 따른다: Rules(자기리뷰·D2) 와 TS(verifyTossPayment·onOrderQoinSettled) 에 각각 구현하되 규칙을 문서로 고정한다.
- **한계(명시)**: ownerId/brandId 기반이라 **같은 계정·"고객 모드 전환" 경로만** 막는다. 부계정은 못 막는다(backlog Q3 결정과 동일). 이것이 Layer2 신호수집의 존재 이유다.

---

## 건별 설계

### 1. Q3 Layer1 — 자기거래 가드

#### 1-A. verifyTossPayment 결제 거절 (self-order 차단)

- **지점**: `functions/src/verifyTossPayment.ts`. **멱등 가드 직후 ~ 결제 게이트(2-b) 전**. Toss confirm 이 호출되기 전이어야 돈이 움직이지 않는다(`paymentGate` 와 동일 원칙).
- **로직**: `stores/{cart.storeId}` 1회 read → `isSelfDealing(uid, store)` 참이면 `HttpsError('permission-denied', ...)` 로 거절. 브랜드 보유자 판정이 필요할 때만(= `store.brandId` 존재) `users/{uid}` 1회 추가 read.
- **읽기 비용**:
  - 매장 read 1회가 **항상** 추가된다(게이트 off 여도 자기거래 가드는 상시 동작). 단 게이트가 on 이면 게이트 리더가 어차피 매장을 읽으므로, 매장 read 를 **가드와 게이트가 공유**하도록 `verifyTossPayment` 에서 매장 스냅샷을 1회 읽어 양쪽에 넘기는 작은 리팩터를 권고(추가 비용 0 수렴). 공유가 설계상 번거로우면 가드 전용 매장 read 1회(품목당 비용 아님, 주문당 1회)로 수용 가능.
  - 브랜드 보유자 판정용 `users/{uid}` read 는 `store.brandId` 가 있을 때만(개인 매장은 0).
- **모드 정책(결정 대기 D-1)**: 권고는 **상시 enforce**(모드 스위치 없음). 자기거래 판정은 `ownerId` 동일성 비교라 **결정적이며 정상 손님 오탐이 구조적으로 없다** — `PAYMENT_GATE_MODE`/`PAYMENT_PRICE_MODE` 처럼 데이터 틀어짐으로 정상 손님을 막을 위험이 없기 때문에 shadow 단계가 불필요하다.
- **거절 기록**: `paymentGateRejections` 에 `reason: 'SELF_DEALING'` 1건 추가 기록(기존 `recordGateRejection` 재사용, `detail` 에 `{storeOwnerId, matchedBy: 'owner'|'brandHolder'}`). audit_trail §4-6(거절 이력 영구 보존) 준수. **기록 실패는 거절 결과를 바꾸지 않는다**(기존 규칙).
- **클라이언트 에러 표면**: `permission-denied` → 체크아웃이 기존 `VerifyPaymentFailure` 매핑으로 "본인 매장은 주문할 수 없습니다." 류 문구 노출. 신규 화면 없음(developer 가 문구/매핑만).

#### 1-B. 자기 리뷰 차단

- **현황**: `reviews` create/update 는 `reviewOrderEligible` 로 "본인/completed/같은 매장" 만 검증하고, **작성자가 그 매장의 점주/브랜드 보유자인지는 보지 않는다**(`firestore.rules:742`).
- **구조적 상호작용(중요)**: 1-A 배포 후에는 자기 주문이 `completed` 에 도달할 수 없으므로 **신규 자기 주문 기반 자기리뷰는 자연 차단**된다. 그러나 ⓐ Layer1 **이전**에 생성된 completed 자기주문, ⓑ defense-in-depth 를 위해 Rules 가드를 함께 넣는다.
- **지점**: `firestore.rules` `reviews` 블록. `reviewOrderEligible`(또는 create/update 조건)에 **자기 매장 작성 차단** 추가.
  - 점주 차단: `get(stores/{d.storeId}).data.ownerId != uid()`.
  - 브랜드 보유자 차단(결정 대기 D-2 에 따라 선택): `store.brandId` 유효 시 `isBrandHolder` 가 아닐 것.
- **읽기 비용**: review create/update 당 `get(stores)` **+1**(점주 차단). 브랜드 보유자까지 보면 `users/{uid}` 조회가 `isBrandHolder` 안에서 +1. 리뷰는 저빈도라 수용. 동일 평가 내 중복 get 은 1회로 과금(Rules 캐시)된다.

#### 1-C. Qoin 자기적립 제외

- **지점**: `functions/src/onOrderQoinSettled.ts`. earn 분기에서 이미 `stores/{storeId}`(ownerId/brandId 포함)를 읽는다 — **추가 read 0** 로 `ownerId == after.userId` 판정 가능. 브랜드 보유자 판정은 `after.userId` 의 `users` 문서 read 가 필요(= `store.brandId` 있을 때만 +1 RT, 결정 대기 D-2).
- **로직**: earn 계산 전에 `isSelfDealing(order.userId, store)` 참이면 **적립 건너뜀**(회수 분기는 영향 없음 — 회수는 원장 반전이라 매장을 읽지 않고, 자기주문도 환불은 정상 통과해야 돈이 새지 않는다).
- **기록 정책**: 자기적립 제외는 **의도된 정책**이므로 `qoinSettlementIssues` 에 **기록하지 않는다**(스위치 꺼짐 `skipped_accrual_disabled` 와 동일 취급, Cloud Logging 만). 고객 돈 누락이 아니다.
- **상호작용**: 1-A 배포 후엔 자기주문이 completed 에 못 가므로 earn 트리거 자체가 거의 안 뜬다 — 1-C 는 legacy/엣지 대비 belt-and-suspenders.

---

### 2. Q3 Layer2 — 신호수집 선제 (데이터만 저장, 탐지 없음)

#### 2-A. 수집 값과 출처

| 신호 | 출처 | 획득 방식 | 프라이버시 |
|---|---|---|---|
| **기기 식별자** | 클라이언트 | `verifyTossPayment` 입력에 `deviceId` 1필드 추가(`clientLevel` 패턴). CF 가 **salt 와 함께 SHA-256 해시**해 `deviceIdHash` 로 저장(원본 저장 안 함) | 설치 단위 식별자만. 원본 미저장 |
| **카드 지문** | Toss confirm 응답 | 서버가 받은 **이미 마스킹된** 카드 정보(`card.company` + `card.number`(first4+last4 마스킹형))를 결합해 **SHA-256 해시** → `cardFingerprint`. 비카드(easyPay)면 `null` | **전체 PAN 미수신**(Toss 가 마스킹). 해시만 저장 |
| **IP** | 서버 | onCall v2 `request.rawRequest.ip`(서버 관측값, 클라 자기신고 아님) → `ipHash`(또는 원본 IP, 결정 대기 D-4) | 서버 관측. 해시 권고 |

- **클라이언트 deviceId 소스(결정 대기 D-3)**: 권고는 **Firebase Installations ID**(`firebase_installations`, 기존 Firebase 스택에 포함 — 신규 무거운 의존 없음). 재설치 시 바뀌지만 "한 설치의 반복 주문" 상관엔 충분. 대안: 로컬 영속 UUID(`uuid`+`shared_preferences`/`secure_storage` 신규 의존).
- **최소수집 원칙**: 기기/카드/IP 모두 **해시 또는 마스킹형**으로 저장. 원본 PAN·원본 deviceId 는 저장하지 않는다. salt 는 하드코딩 금지 — functions secret/param 으로 주입(CLAUDE.md 절대규칙 4).

#### 2-B. 저장 위치 — `orderSignals/{orderId}` (신규 컬렉션, orders 문서 아님)

> **결정 대기 D-5 의 권고안**: order 문서에 직접 넣지 않는다. `orders` 는 **점주가 read 가능**(`data_ownership §2.4`)하므로, 기기/IP/카드 지문을 order 에 넣으면 **점주가 고객의 기기·IP 를 본다** — 프라이버시 역진. 별도 컬렉션으로 분리해 **admin read 전용**으로 둔다.

스키마 `orderSignals/{orderId}`:
```
orderId         string
userId          string         (주문자)
storeId         string
storeOwnerId    string         (당시 매장 ownerId — 자기/부계정 분석용 박제)
storeBrandId    string|null
deviceIdHash    string|null    (salt+SHA-256)
cardFingerprint string|null    (마스킹형 카드정보 SHA-256, easyPay 면 null)
cardCompany     string|null    (Toss card.company)
ipHash          string|null    (또는 ip 원본 — D-4)
createdAt       serverTimestamp
```
- 문서 ID = `orderId` → 멱등(재전달/중복 write 안전).
- write 주체: **`verifyTossPayment` 만**(주문 생성 batch 와 **같은 batch**에 추가 — 신호가 주문과 원자적으로 함께 남는다).
- Rules: `orderSignals` read = `isAdmin()`, create/update/delete = `if false`(CF 전담). `paymentGateRejections`/`storeDeletionHistory` 와 동일 패턴(`data_ownership §2.13`).

---

### 3. D2 — 점주 stores/menuItems self-approve 가드

- **현황**: `firestore.rules:480-495` `stores/{storeId}/menuItems` 의 **점주(`isStoreOwner`) 분기는 필드/status 제약이 전혀 없다** → 가맹점주가 점포한정 메뉴를 `status:'approved'` 로 직접 써 **admin 검토를 우회**할 수 있다. 브랜드 분기는 D1(brand_self_approve_guard)로 이미 닫혔다. 점주 분기만 남았다.
- **보존해야 하는 정상 케이스**(`entity_lifecycle §5.3`): **독립매장(brandId 없음)** 점주의 점포한정 메뉴는 `status:'approved'` **즉시**가 정상(승인 불필요). 블런트 차단은 이 플로우를 깬다.
- **설계**: `get(stores/{storeId}).data.brandId` 로 분기.
  - **독립매장(brandId 비어있음)**: 점주 create/update 에 `status:'approved'` 허용 — 단 **승인 메타(`approvedBy`/`approvedAt`)는 부재/null 강제**(§5.3 이 null 로 쓴다). 현행 정상 플로우 보존.
  - **가맹매장(brandId 유효)**: 점주는 **자가승인 불가** — create 는 `noSelfApproveOnCreate()`(pending + 메타 null), update 는 `noSelfApproveOnUpdate()`(approved/rejected 전이·메타 non-null 금지). 승인/반려는 admin 전담(D1 과 동일 헬퍼 재사용).
- **구현 형태**(헬퍼 재사용):
  ```
  // 점주 분기용 — 독립매장은 approved 허용(메타 null), 가맹매장은 self-approve 차단
  function ownerStoreMenuOk(storeId, onUpdate) {
    let brandId = get(/.../stores/$(storeId)).data.get('brandId', '');
    return brandId == ''
      ? (approvedBy/approvedAt 부재·null)              // 독립매장: approved 허용, 메타 자가설정만 차단
      : (onUpdate ? noSelfApproveOnUpdate() : noSelfApproveOnCreate());  // 가맹매장
  }
  ```
  create/update 점주 분기에 `&& ownerStoreMenuOk(storeId, false/true)` 추가. delete 는 승인과 무관 → 현행 유지.
- **읽기 비용**: `isStoreOwner(storeId)` 가 이미 `get(stores)` 를 하므로 같은 평가 내 `get(stores)` 재호출은 **1회 과금**(Rules 중복 get 캐시). 실질 추가 0.
- **D1 과의 정합**: 이로써 `stores/menuItems`·`menuOverrides` 양 분기(브랜드/점주) 자가승인이 모두 닫힌다. `data_ownership §2.6` 의 "⚠️ 남은 지점: 점주 분기" 가 해소된다.

---

## 데이터 모델 요약

### 신규 컬렉션: `orderSignals/{orderId}` (위 2-B)
### 신규 거절 사유: `paymentGateRejections.reason = 'SELF_DEALING'` (기존 컬렉션에 enum 1종 추가)
### 클라이언트 입력 추가: `verifyTossPayment({..., deviceId})` (`clientLevel` 과 동일 — 선택 필드, 구버전은 누락 가능, 판정 아닌 신호용)
### 엔티티/DTO: Dart 도메인 엔티티 변경 없음(order 문서 스키마 불변 — 신호는 분리 컬렉션).

---

## 데이터 흐름

```
[결제]  Checkout → PaymentGatewayRepositoryImpl → CloudFunctionsRemoteDataSource.verifyTossPayment(deviceId 추가)
          → CF verifyTossPayment:
              멱등가드 → [1-A 자기거래 가드: stores read, isSelfDealing → permission-denied + SELF_DEALING 기록]
              → 게이트(2-b/2-c) → Toss confirm → batch{ orders, orderLogs, [2-B orderSignals] }
[적립]  orders status→completed → CF onOrderQoinSettled → [1-C isSelfDealing 이면 적립 skip]
[리뷰]  Client reviews create/update → Rules reviewOrderEligible + [1-B 자기 매장 작성 차단(get stores)]
[메뉴]  Owner stores/{id}/menuItems write → Rules 점주 분기 + [3 ownerStoreMenuOk(브랜드 분기)]
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 자기 매장 결제 시도 | CF `permission-denied` → Toss **미호출**(돈 안 움직임) → 체크아웃 "본인 매장은 주문할 수 없습니다" 안내 + `SELF_DEALING` 기록 |
| 자기 매장 리뷰 시도 | Rules 거부(create/update 실패) → 기존 리뷰 실패 UI 경로 |
| 가맹점주 메뉴 자가승인 시도 | Rules 거부 → admin 승인 대기(pending)로 유지 |
| 독립매장 점주 메뉴 등록 | **정상 통과**(approved 즉시) — 회귀 방지 핵심 |
| deviceId 누락(구버전) | 신호 `deviceIdHash: null` 로 저장, 결제는 정상 진행(판정에 안 씀) |
| orderSignals write 실패 | 로그만, 주문 성공을 뒤집지 않음(신호는 주문 성공의 조건이 아니다) ※ 단 같은 batch 면 batch 실패와 묶임 — 결정 대기 D-6 참조 |
| 매장/유저 read 실패(일시) | 1-A/1-C 는 기존 함수 실패 정책 따름(throw→retry 또는 거절 fail-closed) |

---

## 회귀 포인트 (반드시 깨지지 않을 것)

1. **일반 고객 주문**: 타인 매장 주문은 `isSelfDealing=false` → 영향 0. (가드가 ownerId 비교만 하므로)
2. **일반 고객 리뷰**: 본인이 점주/브랜드 아닌 매장 리뷰 → 영향 0.
3. **일반 고객 Qoin 적립**: 영향 0.
4. **독립매장 점주 점포한정 메뉴 등록(approved 즉시)**: D2 가드가 brandId 없음 분기로 **보존**. — 가장 깨지기 쉬운 지점.
5. **가맹매장 점주 운영 update**(soldOut 등, menuOverrides 경로): D2 는 `menuItems` 만 건드림 — menuOverrides 점주 운영 분기 불변.
6. **환불 시 Qoin 회수**: 1-C 는 earn 만 건드림 — 회수 경로 불변.
7. **게이트 off 운영**: 1-A 는 게이트 모드와 독립(상시) → off 여도 자기거래는 막힌다(의도).

---

## 이력 / 감사 추적 — audit_trail §4 체크리스트

1. **돈·권한·정책 값을 바꾸는가?** → 이 묶음은 **값을 바꾸지 않는다**. (a) Layer1 은 거래를 **거절**하고, (b) Layer2 는 신호를 **수집**하며, (c) D2 는 승인 권한 **경계를 Rules 로 집행**할 뿐 적립률/authority/config 같은 설정 값을 쓰지 않는다. → **"설정 변경 이력" 불필요**. (명시 사유: 신규 설정 값 자체가 없음)
2. **덮어쓰기로 사라지는 값?** → 없음. `orderSignals`/`paymentGateRejections` 는 append-only 기록.
3. **거래/기록이 정책 값을 참조만?** → `orderSignals.storeOwnerId`/`storeBrandId` 를 **당시 값으로 박제**(나중 ownerId 변경돼도 자기거래 분석이 흔들리지 않게). Qoin 원장은 기존대로 당시 값 박제 유지.
4. **"누가"?** → `orderSignals.userId`, `paymentGateRejections.uid` 기록됨. D2/리뷰 거부는 행위자 기록 대상 아님(쓰기가 거부됨).
5. **일괄 처리?** → 없음(백필 없음 — Layer2 는 "이 시점 이후" 신호만, priceHistory 와 같은 전방 전용).
6. **CF 로그 의존?** → 거절 이력은 `paymentGateRejections`(영구), 신호는 `orderSignals`(영구) 로 Firestore 에 남긴다. 자기적립 제외만 Cloud Logging(의도된 정책, 값 누락 아님).
7. **권한 판정 필드의 create/update 교차**(§4-7 상시): D2 는 **create 와 update 를 각각 제한**(`noSelfApproveOnCreate`/`OnUpdate` + 독립매장 메타 가드 create/update 양쪽). Rules 하네스에 **create 거부 케이스 + 정상 payload 허용 회귀 케이스**를 둔다(아래 tester).

---

## 배포 단위 (사용자가 돌릴 단위)

> 경로/프로젝트는 `docs/operations.md` 기준. 명령은 전체 한 줄로 실행한다(MEMORY: 명령어 명확성).

1. **Firestore Rules** (D2 + 자기리뷰 + orderSignals):
   ```bash
   cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:rules --project order-app-5957e
   ```
2. **Cloud Functions** (Layer1 결제 거절+Layer2 신호 / Qoin 자기적립 제외):
   ```bash
   cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment,functions:onOrderQoinSettled --project order-app-5957e
   ```
3. **salt secret**(Layer2 해시용, 하드코딩 금지): 배포 전 1회
   ```bash
   cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 functions:secrets:set SIGNAL_HASH_SALT --project order-app-5957e
   ```
4. **앱 빌드**: 클라이언트 `deviceId` 추가는 다음 앱 빌드에 반영(구버전은 null 신호로 수용).

- **배포 순서 권고**: Rules → Functions. orderSignals write 가 Rules 의 `if false`(CF 는 Admin SDK 라 우회)와 무관하나, 자기리뷰/D2 가드를 먼저 세워 창을 줄인다.
- landing/hosting 은 이 묶음과 무관 — 건드리지 않는다(MEMORY: landing 배포 규칙).

---

## 작업 분배

### designer
- **불필요.** 신규 화면/흐름 없음. 유일한 UI 노출은 자기거래 결제 거절 **에러 문구 1개**인데, 기존 `VerifyPaymentFailure` 안내 패턴을 그대로 쓰므로 디자인 산출물 없음. (문구만 developer 가 추가)

### developer
- **CF `verifyTossPayment`**: 1-A 자기거래 가드(매장/유저 read, `isSelfDealing`, Toss confirm 전 거절, `SELF_DEALING` 기록) + 2-B `orderSignals` batch write(deviceId 해시, 카드지문, IP). 매장 read 를 가드/게이트가 공유하도록 소폭 리팩터 권고.
- **CF `onOrderQoinSettled`**: 1-C earn 분기 자기적립 제외(추가 read 최소화).
- **Rules**: 1-B 자기리뷰 차단(`reviews`), 3 D2 점주 분기(`stores/menuItems`, `ownerStoreMenuOk`), `orderSignals` 블록(admin read / write false).
- **클라이언트**: `verifyTossPayment` 호출에 `deviceId` 추가(`cloud_functions_remote_data_source.dart` + repo + install id 유틸). 자기거래 거절 에러 매핑/문구.
- **재사용**: `noSelfApproveOnCreate/OnUpdate`(D1), `recordGateRejection`, `canSellNow` 포팅 패턴, `clientLevel` 전달 패턴, Qoin earn 의 기존 store read.
- **레이어 규칙**: Firebase/Toss 직접 접근은 functions/data 만. `isSelfDealing` 의 Rules/TS 두 구현은 규칙을 이 spec 으로 고정(drift 주의). salt 는 secret 주입(하드코딩 금지).
- `docs/tasks/prelaunch_security_bundle/implementation.md` 작성.

### tester
- **핵심 회귀**(위 "회귀 포인트" 7종) 전부 검증. 특히 **독립매장 점주 approved 메뉴 등록이 여전히 통과**하는지.
- **Rules 하네스**: D2 — 가맹점주 `status:'approved'` create/update 거부 + 독립매장 점주 approved 허용 + 승인메타 자가설정 create/update 양쪽 거부(§4-7). 자기리뷰 — 점주/브랜드 보유자 자기매장 리뷰 거부 + 일반 고객 리뷰 통과.
- **CF 단위**: `isSelfDealing` 참 → Toss confirm 미호출(기존 주입 이음새 `VerifyDeps` 로 단언) + `SELF_DEALING` 기록 1건. 타인 매장 → 통과. deviceId 누락 → null 신호 저장 + 결제 정상. Qoin earn 자기주문 skip / 회수는 자기주문도 통과.
- `docs/tasks/prelaunch_security_bundle/test_report.md` 작성.

---

## 완료 기준

- [ ] Layer1: 자기 매장 결제/리뷰/적립이 모두 차단되고, 타인 매장 플로우는 무영향.
- [ ] Layer2: `orderSignals/{orderId}` 가 주문과 함께 생성되고 admin read 전용, 값은 해시/마스킹형.
- [ ] D2: 가맹점주 자가승인 차단 + 독립매장 점주 approved 등록 보존(회귀 없음).
- [ ] Rules/Functions 두 배포 단위 명확, salt secret 설정.
- [ ] `design.md` — UI 변경 없음으로 생략 명시.
- [ ] `implementation.md` / `test_report.md` 작성.
- [ ] FAIL 없거나 후속 분리.

---

## 사용자 확인이 필요한 결정사항

- **D-1 (Layer1 결제 가드 모드)**: 상시 enforce(권고) vs `PAYMENT_GATE_MODE` 류 모드 스위치. 권고 = 상시(오탐 없음).
- **D-2 (브랜드 보유자 포함 범위)**: 자기거래 판정에 **브랜드 보유자**를 포함할지. 포함 시 리뷰/적립에 `users` read 1회씩 추가. 권고 = 포함(일관성).
- **D-3 (deviceId 소스)**: Firebase Installations ID(신규 의존 無, 권고) vs 로컬 영속 UUID(신규 의존).
- **D-4 (IP 저장 형태)**: `ipHash`(권고, 프라이버시) vs 원본 IP(탐지 정밀도). 탐지 룰이 서브넷/원본을 필요로 할지 미확정 — 지금은 해시 권고, 필요 시 전환.
- **D-5 (신호 저장 위치)**: `orderSignals/{orderId}` 분리 컬렉션(권고, 점주가 고객 기기/IP 못 봄) vs order 문서 직접(점주 read 노출 위험). 권고 = 분리.
- **D-6 (orderSignals batch 묶음)**: 주문 batch 와 **같은 batch**(원자적, 단 신호 write 실패가 주문을 막음) vs **분리 best-effort**(주문 우선, 신호 실패 삼킴). 권고 = 신호는 best-effort(주문 성공이 우선) — 단 멱등 ID 로 재시도 가능.
