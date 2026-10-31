# prelaunch_security_bundle 구현 기록

작성: 2026-10-31 (developer) · 기준: `spec.md`

## 0. 결정사항 (D-1 ~ D-6) — 전부 **잠정 (사용자 검토 대기)**, 코드 주석에 동일 표기

| ID | 채택값 | 코드 위치 |
|---|---|---|
| D-1 | Layer1 결제 가드 **상시 enforce** (모드 스위치 없음) | `verifyTossPayment.ts` 2-a |
| D-2 | 자기거래 = 점주 OR **브랜드 보유자 포함** | `selfDealing.ts`, `onOrderQoinSettled.ts`, rules `notSelfStore` |
| D-3 | deviceId = **Firebase Installations ID** | `cloud_functions_remote_data_source.dart` |
| D-4 | IP = **ipHash** (salt 해시) | `orderSignals.ts` |
| D-5 | 신호 위치 = **`orderSignals/{orderId}` 분리 컬렉션** (admin read / write false) | `firestore.rules` |
| D-6 | orderSignals write = **best-effort** (주문 커밋 후 별도 write, 실패 삼킴) | `orderSignals.ts writeOrderSignal` |

## 1. 구현 내용

### Layer1
- **공통 판정** `functions/src/selfDealing.ts` (신규): `matchSelfDealing`(순수) / `findSelfDealing`(db). `users/{uid}` 는 매장에 유효 brandId 가 있고 점주 불일치일 때만 read. Rules `isStoreOwner`/`isBrandHolder` 와 같은 규칙(공백 brandId 매칭 차단).
- **1-A `verifyTossPayment`**: 멱등가드 직후·게이트 전(2-a)에 `stores/{cart.storeId}` read → 자기거래면 `permission-denied` + `paymentGateRejections.reason='SELF_DEALING'`(`detail:{storeOwnerId, matchedBy}`) 기록, **Toss confirm 미호출**. 기록 실패는 거절 불변(기존 `recordGateRejection`). 매장 문서 없음 → 가드 건너뜀(기존 STORE_NOT_FOUND 동작 유지). 매장/유저 read 실패 → `unavailable`(통과시키지 않음, confirm 전이라 돈 안 움직임). 에러 메시지 끝에 기존 토큰 문법 `[SELF_DEALING]` (`paymentGate.ts` 의 `GateReason`/`GATE_HTTPS_CODE`/`GATE_TEXT` 에 1종 추가).
  - 매장 read 는 게이트 reader 와 공유하지 않고 가드 전용 1회(spec 이 수용한 안). 게이트 off 여도 주문당 stores read 1회가 항상 추가된다.
- **1-B 자기 리뷰 차단** `firestore.rules` `reviews`: `notSelfStore(d)` 를 create/update 양쪽에 추가 (`get(stores)` 의 ownerId != uid 이고 `!isBrandHolder(brandId)`).
- **1-C 자기적립 제외** `onOrderQoinSettled.ts` earn 분기: 이미 읽은 storeSnap 으로 판정(추가 read 0, 브랜드 매장일 때만 users +1), 참이면 `skipped_self_dealing` 로그 후 return. `qoinSettlementIssues` 기록 없음. 회수 분기 불변.

### Layer2 (신호수집만, 탐지/UI 없음)
- `functions/src/orderSignals.ts` (신규): HMAC-SHA256(salt) 해시. 종류 접두사(`device:`/`card:`/`ip:`)로 도메인 분리. 문서 `orderSignals/{orderId}` = `orderId,userId,storeId,storeOwnerId,storeBrandId,deviceIdHash,cardFingerprint,cardCompany,ipHash,createdAt`. `create()` 라 멱등(ALREADY_EXISTS 무시). 원본 deviceId/IP/카드번호 미저장.
- salt = `defineSecret("SIGNAL_HASH_SALT")` (`verifyTossPayment` secrets 에 추가; 코드엔 선언만). salt 가 비어 있으면 신호 생략 + 주문 정상.
- IP = `request.rawRequest.ip`. 카드 지문 = Toss 응답 `card.company|card.number`(이미 마스킹형) 해시, 비카드는 null.
- Rules `orderSignals/{id}`: `read: isAdmin()`, `write: false`.
- 클라이언트: `CloudFunctionsRemoteDataSource.verifyTossPayment` 가 `deviceId`(선택 필드, 실패/없으면 키 생략)를 `clientLevel` 옆에 추가. Firebase SDK 는 data 레이어 안에서만 사용(spec 의 "core 유틸" 대신 데이터소스 내부 주입점 `deviceIdProvider` — Clean Architecture 절대규칙 2 준수). repo/usecase 시그니처 불변 → **골든 계약(qoin_cart_contract 등)·orderBuilder 계약 영향 없음**(deviceId 는 cart 가 아닌 최상위 입력).
- 에러 표면: `PaymentFailureReason.selfDealing`('SELF_DEALING') + `gateFailureCopy` 문구 "본인 매장은 주문할 수 없어요" (기존 갈래 B 재사용, 신규 화면 없음, 색상 변경 없음).

### D2
- `firestore.rules` `stores/{id}/menuItems`: 헬퍼 `ownerStoreMenuOk(storeId, onUpdate)` 추가, 점주 분기를 `isStoreOwner && ownerStoreMenuOk` 로 교체. delete·brand 분기·menuOverrides 불변.
  - 매장 brandId 가 **비어있지 않은 문자열**이면 가맹 → `noSelfApproveOnCreate/OnUpdate` 재사용.
  - 그 외(독립) → approved 허용, 승인 메타(`approvedBy/approvedAt`) 자가설정만 차단(create: null/부재, update: 변경분 diff 기준).
  - **중요 발견**: 독립매장 stores 문서는 `brandId: null` 이 **명시 필드**(`store_model.toFirestore`)다. spec 의 `get('brandId','') == ''` 형태로 쓰면 null 이 가맹으로 오분류돼 독립매장 approved 등록이 깨진다 → `is string && != ''` 로 판정(회귀 방지 핵심).

## 2. 수정/생성 파일
- 신규: `functions/src/selfDealing.ts`, `functions/src/orderSignals.ts`, `functions/test/selfDealing.test.mjs`
- 수정: `functions/src/verifyTossPayment.ts`, `functions/src/onOrderQoinSettled.ts`, `functions/src/paymentGate.ts`, `functions/package.json`(test 스크립트에 신규 테스트 추가), `functions/test/paymentGate.test.mjs`(아래 §4 참고), `firestore.rules`
- 클라: `lib/data/datasources/remote/cloud_functions_remote_data_source.dart`, `lib/domain/entities/payment_failure.dart`, `lib/presentation/customer/checkout/payment_failure_copy.dart`, `test/domain/payment_failure_test.dart`, `pubspec.yaml`, `pubspec.lock`

## 3. 선정 라이브러리 / 버전
- `firebase_app_installations: 0.4.0` (**고정**). 주의: pub 의 `firebase_installations` 는 다른(오래된) 패키지라 쓰지 않았다. `^0.4.5`/0.4.3+ 는 `firebase_core 4.15+` 를 요구해 firebase_auth/messaging/storage 네이티브 SDK 전체가 상향되므로, 0.4.0 으로 고정해 **lock 에서 신규 3패키지만 추가**(기존 firebase_* 버전 불변)되게 했다. 서버: Node 내장 `crypto`(신규 의존 없음).

## 4. 테스트 결과
- `flutter analyze`: No issues found
- `flutter test`: 927 전부 통과
- `cd functions && npm test`(build 포함): 368 통과 / 0 실패. 신규 `selfDealing.test.mjs` 17건(판정 순수 5, 가드 7: 점주·브랜드보유자 거절+confirm 0회+기록 1건 / 타인매장 통과+users read 0 / 매장 없음 / read 실패 / 기록 실패 불변, 신호 5: 해시만·원본 없음 / deviceId 누락 / 비카드 / write 실패 best-effort / salt 없음).
- 기존 테스트 1건 의도적 수정: `paymentGate.test.mjs` "off 는 읽지 않는다" — 자기거래 가드가 모드와 무관하게 `stores` 1회 read 하므로 기대 컬렉션 집합에 `stores` 추가(게이트 reader 호출 0 단언은 유지).
- **Rules 에뮬레이터 검증 23건 통과** (프로젝트 밖 임시 하네스 — `@firebase/rules-unit-testing` 은 프로젝트 의존이 아니라 레포에 미포함. tester 가 레포 하네스 필요 시 추가): D2(독립 `brandId:null`·부재 approved create 허용 / 독립 update·soldOut 허용 / 독립 메타 자가설정 create·update 거부 / 가맹 approved create 거부·pending 허용·승격 update 거부·메타 update 거부·운영 update 허용 / admin·타 점주), 리뷰(일반 고객 허용 / 점주·브랜드 보유자·가맹점주 자기 매장 거부), orderSignals(admin read 허용 / 점주·고객 read 거부 / admin write 거부).
- 미실시: `onOrderQoinSettled` 자기적립 skip 의 에뮬레이터 트리거 테스트(기존 `test:emulator` 에 케이스 미추가). 코드 경로는 빌드 통과 + 로직 단순.

## 5. 테스트 포인트 (tester)
1. 회귀 ①: 독립매장 점주(`brandId:null`) 앱 UI 에서 점포한정 메뉴 등록·수정 → approved 즉시 성공 (`menu_item_repository_impl` 는 approvedBy/At null 을 보냄).
2. 회귀 ②: 일반 고객 주문/리뷰/적립 무영향.
3. 점주 계정으로 자기 매장 주문 → 결제창 후 confirm 단계에서 "본인 매장은 주문할 수 없어요" 갈래 B 화면, Toss 승인 없음, `paymentGateRejections` 에 `SELF_DEALING` 1건.
4. 브랜드 계정이 자기 브랜드 가맹 매장 주문 → 동일 거절.
5. 정상 주문 후 `orderSignals/{orderId}` 생성 확인(Console, admin) — 해시 64hex, 원본 값 없음. 구버전/무 deviceId → `deviceIdHash:null`.
6. 환불 시 clawback 불변. 자기적립 skip 로그 `skipped_self_dealing`.
7. Rules: 점주/고객은 `orderSignals` read 불가.
8. 결제 UI 는 Toss 결제창이 먼저 뜬 뒤 confirm 에서 거절되는 구조다(서버 가드는 confirm 전). 사용자가 결제창 입력 후 거절을 볼 수 있음 — UX 개선(카트 진입 시 선차단)은 비범위.

## 6. 사용자 배포 순서 (prod 배포·secrets:set 은 실행하지 않았다)
1. salt 설정 (배포 전 1회, 프롬프트에 임의의 긴 랜덤 문자열 입력 — 이후 바꾸면 기존 해시와 상관 불가):
```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 functions:secrets:set SIGNAL_HASH_SALT --project order-app-5957e
```
   (salt 미설정 상태로 Functions 를 배포하면 secret 부재로 배포가 실패한다. 반드시 먼저 설정.)
2. Rules:
```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:rules --project order-app-5957e
```
3. Functions (`verifyTossPayment` 의 secrets 변경 포함):
```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment,functions:onOrderQoinSettled --project order-app-5957e
```
4. 앱: 다음 빌드부터 `deviceId` 포함(구버전은 null 신호). `pubspec.lock` 에 firebase_app_installations 추가됨 → iOS 는 `pod install` 필요할 수 있음.
- 순서: secret → Rules → Functions. landing/hosting 무관.

## 7. 미구현 / 보류
- Layer2 탐지·플래그·admin UI (비범위).
- `docs/processes/data_ownership.md` §2.6/§2.13 · `entity_lifecycle.md` 문서 갱신(orderSignals 컬렉션 추가, "남은 지점: 점주 분기" 해소, SELF_DEALING 사유)은 요청 범위(코드) 밖이라 하지 않았다 — architect 후속 권고.
- `onOrderQoinSettled` 자기적립 skip 에뮬레이터 케이스.
- 카트 진입 시 선차단 UX.
- D-1~D-6 최종 확정은 사용자 검토 대기 (잠정값으로 구현·주석 표기).
