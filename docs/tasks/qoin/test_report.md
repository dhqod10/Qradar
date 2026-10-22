# Qoin 1차 테스트 리포트 (정적 검증)

- 검증일: 2026-10-22
- 범위: 정적 코드 추적 + Rules 하네스 직접 재실행. 라이브(에뮬레이터/기기) 검증은 미수행 (사용자 수행 예정)
- 기준: spec.md §15, design.md (+ 잔여 결정 확정 절), implementation.md, audit_trail.md §4
- 이미 확인된 항목(analyze / flutter test 129 / tsc / hook grep / Color(0x grep / rules 삭제줄 0)은 중복 검증하지 않음

## 1. 요약

| 구분 | 개수 |
|---|---|
| PASS | ①②③④⑤⑥⑩, ⑦ (users.create 제외), ⑧ Rules 71/71, ⑨ 박제 항목 |
| FAIL | 3 (F1 users.create 로 qoinBalance 위조 가능 / F2 원장에 brandId 없음 / F3 CF 가 20% 상한을 모름) |
| 보류 | 5 |
| 시나리오 결함 | 5 |

우선 수정 순위: F1 (돈 위조 경로) > F2 (배포 전이라 비용 0, 배포 후엔 과거 행 누락) > F3.

## 2. FAIL

### F1. [높음] 신규 가입 시 `users` self-create 로 `qoinBalance` 임의 값 생성 가능
- 위치: `firestore.rules` `match /users/{userId}` 의 `allow create` (L71-74)
- 근거: create 조건은 `uid 일치 + role=='customer' + brandId 부재` 뿐이다. 필드 화이트리스트가 없다. 잔액 보호(`isSelfProfileUpdate` 의 `hasOnly`)는 **update 에만** 적용된다. 하네스 QR9/QR10 도 update 만 검증하고 create 는 검증하지 않는다 (`test_rules/rules.test.mjs` 에 users create + qoinBalance 케이스 없음).
- 영향: 앱이 users 문서를 만들기 전에 (또는 새 계정으로) REST/SDK 로 `{role:'customer', qoinBalance: 999999}` 를 create 하면 임의 잔액이 생긴다. CF 는 `rawBefore` 를 신뢰해 그 위에 더한다 (`onOrderQoinSettled.ts` L82-84). 1차는 사용처가 없어 즉시 피해는 없지만 2차(사용) 시작 시 곧바로 무한 Qoin 이 된다. spec §1.3 의 "클라이언트 쓰기 차단" 불변식 위반.
- 확인 방법: 신규 uid 로 `users/{uid}` create `{role:'customer', qoinBalance:100000}` -> 현재 Rules 는 allow (코드 추적. 라이브 미실행)
- 제안: `allow create` 에 `&& !('qoinBalance' in request.resource.data)` 추가 + 하네스에 create 거부 케이스 추가. 이는 "기존 블록 비수정" 원칙의 예외가 필요하므로 architect 승인 후 진행.

### F2. [중] Qoin 원장에 `brandId` 없음 (audit_trail §5 위반)
- 위치: `functions/src/onOrderQoinSettled.ts` L158-165 (earn), L190-198 (clawback)
- 근거: 원장 필드는 `storeId / storeName / orderTotalPrice / accrualRate` 뿐이다. `OrderModel` 에는 `brandId` 가 있고 (`order_model.dart` L18, L88) 주문 문서에서 바로 복사 가능한데 복사하지 않는다. audit_trail §5 는 "원장 스키마를 정할 때 storeId 와 brandId 를 빠뜨리지 않는다" 를 명시한다.
- 영향: 브랜드별 적립 비용 집계 불가 (매장 -> 브랜드 역조인은 매장이 브랜드를 옮기면 틀림). 아직 미배포라 지금 고치면 과거 행 누락이 0.
- 제안: earn 에 `brandId: after.brandId ?? ""` 추가, clawback 은 earn 문서에서 상속. 모델/엔티티 읽기는 선택. spec 에 필드 추가 반영 필요.

### F3. [중-낮음] CF 가 관리자 UI 의 0.1~20% 경계를 모른다 (방어선이 클라이언트에만 존재)
- 위치: `onOrderQoinSettled.ts` L47 (`rate < 0 || rate > 1`), `firestore.rules` `config/{docId}` (`write: if isAdmin()`, 값 검증 없음)
- 근거: 100배 방어(하한 0.1% / 상한 20%)는 `QoinPolicy` 와 `SaveQoinAccrualRateUseCase` 에만 있다. Console 직접 수정 (QM5 가 바로 그 방식) 이나 향후 다른 쓰기 경로에서 `accrualRate: 0.5` (50%) 가 들어오면 CF 는 그대로 50% 를 적립한다. `0.03` -> `3` 같은 실수는 `>1` 로 막히지만 `0.3` 은 막히지 않는다.
- 제안: CF 에서 `0 < rate <= 0.2` 밖이면 skipped_invalid_rate (하한은 0 도 허용할지 결정 필요) 또는 Rules 에서 `config/qoin` write 시 범위 검증. 상한 상수는 한 곳에서 관리.

## 3. 중점 검증 결과

### ① 100배 오입력 방어 -- PASS
`qoin_policy.dart` `validateRateInput` 추적 결과 (표는 코드 추적, 단위 테스트 `qoin_policy_test.dart` 존재):

| 입력 | 결과 | 근거 |
|---|---|---|
| `0.03` | **tooLow** | value=0.03 < 0.1 이 소수 자릿수(tooPrecise) 검사보다 먼저 (L62-64 vs L70) |
| `0` / `0.` / `.0` | tooLow (`.` 단독은 malformed) | 위와 동일 / L57 |
| `0.1` / `0.10` | valid (tenths=1, 후행 0 제거 후 1자리) | |
| `3` | valid (30) | |
| `20` / `20.0` | valid (200) | |
| `20.1`, `25`, `30` | tooHigh | L65-67 |
| `0.25` | tooPrecise | 하한 통과 후 |
| `1e3`, `-1`, `3%` | malformed (정규식) | 입력 필터가 `[0-9.]` 만 허용하므로 UI 에선 도달 불가 |

- 퍼센트 -> 비율: 파싱은 문자열 분해 후 `whole*10 + frac` **정수**. 저장값은 `tenths/1000` 단일 IEEE 나눗셈 1회 (엄밀히 "정수 연산" 은 파싱까지이고 마지막 변환은 부동소수 1회). tenths 1..200 전부 `round(rate*1000)==tenths` 왕복 일치를 스크립트로 확인 (불일치 0).
- 이중 방어: `SaveQoinAccrualRateUseCase` 가 범위 밖 tenths 를 `ArgumentError` 로 한 번 더 차단.
- 입력 필터 `LengthLimitingTextInputFormatter(5)`: `0.0300` 같은 붙여넣기는 5자로 잘려 `0.030` -> 여전히 tooLow. `3.0001` 은 `3.000` 으로 잘려 valid(3%) 가 되는데 의도와 크게 다르지 않아 무해. (참고)
- 확인 다이얼로그: 저장 직전 항상 표시, 현재 -> 변경 + 10,000원 환산 + 인상 경고(>=2배 또는 >=10%). 저장 값 `newTenths` 는 검증 시점의 값과 동일 (다이얼로그가 modal 이라 입력 변경 불가).
- 단, 이 방어선은 **관리자 화면 경유 시에만** 유효 (F3).

### ② CF 산식 vs 클라이언트 미리보기 -- PASS
- CF: `ppm=round(rate*1e6); floor(total*ppm/1e6)`. 클라이언트: `(10000*tenths)~/1000` (`previewAmount`).
- tenths 1..200 x 결제액 19종 (1, 9, 10, 33, 99, 4500, 4501, 4999, 10000, 18000, 99999, 9,999,999 등) = 3,800 조합을 CF 산식과 정수 산식으로 비교: **불일치 0**.
- 화면의 `10,000원 -> 300 Q` (3%) 는 CF 실제 적립과 일치. 소액(1~99원)의 0 적립은 CF 가 `skipped_zero_amount` 로 처리 -- 고객 안내문구에 "1 Q 미만 버림" 류 설명은 없음 (참고).
- 고객 내역의 사유 문구는 원장에 박제된 `orderTotalPrice` / `accrualRate` 를 사용하며 재계산하지 않음 (표시값이 amount 와 어긋날 가능성은 정책 변경 후에도 없음).

### ③ 멱등성 -- PASS
- 결정적 ID `earn_{orderId}` / `clawback_{orderId}` + `runTransaction` 내 `t.get(txRef)` 선존재 가드 (L76-77). 가드와 쓰기가 같은 트랜잭션이므로 동시 재시도도 직렬화 (Firestore 트랜잭션 경합 시 재시도 후 가드 적중).
- `retry: true` 로 중복 실행이 실제 발생해도 두 번째는 `already_applied`. 이중 적립 경로 없음.
- 주의 (보류 H1): 가드는 orderId 단위라 `completed -> ready -> completed` 왕복은 적립 1회로 수렴 (의도). 반대로 회수 후 재적립은 불가 -- `refunded` 는 종단 상태라 정상.

### ④ 회수 정확성 -- PASS
- 회수액 = `-earn.amount` (L173-184), 재계산 없음. 정책 변경 후에도 회수액==적립액 (산식 경로상 `config` 를 clawback 금액에 쓰지 않음; `config` 는 enabled 판정에만 사용). 원장 clawback 의 `orderTotalPrice/accrualRate` 도 earn 에서 상속.
- earn 없음 -> `skipped_no_earn` 로그 후 return. earn amount 비정상(<=0) -> 에러 로그 후 return.

### ⑤ fail-closed -- PASS
- config 부재 / `enabled !== true` / rate 비number·NaN·Infinity·음수·>1 -> 모두 null 반환 -> **적립과 회수 모두** return (L136-137 이 earn/clawback 분기보다 앞).
- 클라이언트 모델도 동일 기준 (`QoinConfigModel.fromMap`): 비 bool enabled -> false, 무효 rate -> null.
- 끄기 다이얼로그 카피: "이미 적립된 주문이 환불되어도 Qoin 이 회수되지 않아요" + "중단 중에 픽업 완료된 주문은 다시 켜도 자동으로 적립되지 않아요" 명시 확인. 스위치 하단 상태 문구와 Semantics hint 도 "적립과 환불 회수가 모두 멈춰요".
- 부작용 (보류 H2): 중단 중 건너뛴 적립/회수는 **CF 로그에만** 남고 영구 기록이 없다 (audit_trail §4.6). 아래 ⑨.

### ⑥ 비상 정지 분리 -- PASS
- `_onToggleEnabled` 는 `_rateCtrl`, `validateRateInput`, `canSave`, `_savingRate` 어느 것도 참조하지 않음. 저장 호출은 `setQoinEnabledUseCase` -> `_configDoc.update({'enabled': v})` 1필드. 작성 중인 적립률이 딸려 저장되는 경로 없음.
- 반대 방향: `saveAccrualRate` 는 문서가 있으면 `accrualRate` 만 update (enabled 불변), 없으면 `enabled:false` 로 생성 -> 초기값 false 결정 준수.
- 낙관적 갱신 없음 (스위치 값은 항상 스트림 값). 로딩/에러 중 스위치·입력 비노출(값 모른 채 덮어쓰기 방지).
- 사소: `_onToggleEnabled(cfg!, next)` 의 `cfg!` 는 스위치가 `cfg != null` 일 때만 활성이라 안전.

### ⑦ Rules -- PASS (F1 제외)
- `qoinTransactions`: read = 본인/admin, create/update/delete 전부 `false`. 하네스 QR7/QR7b/QR7c 로 **admin 도 거부** 확인.
- `users.qoinBalance` **update** 직접 쓰기: `isSelfProfileUpdate` 의 `onlyChangedFields` (= `diff.affectedKeys().hasOnly`) 화이트리스트에 없어 거부 (QR9/QR10/QR10b/QR11 PASS). admin 의 qoinBalance update 는 허용 (QR12, spec §4.4 수용). **create 경로는 미보호 -> F1.**
- `config/{docId}`: read 로그인 / write admin (QR13-QR17 PASS).
- 기존 블록 수정 여부: `git diff HEAD~6 HEAD -- firestore.rules` = 추가 2 hunk(+22줄), 삭제 0. 기존 `users` / `orders` 블록 무수정 확인.
- 참고: `config/{docId}` 는 임의 문서 ID 에 대해 admin 쓰기 허용 (QR16b 가 이를 허용 케이스로 고정). 향후 다른 설정 문서가 생기면 값 검증은 개별 필요.

### ⑧ Rules 하네스 / CF 에뮬레이터
- `cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test` **직접 실행: 71/71 PASS** (Qoin QR1~QR18 + 변형 전건 PASS). developer 보고와 일치. (Java < 21 경고만 출력)
- CF 에뮬레이터 21/21: **저장소 기준 재현 불가.**
  - 스크립트(`qoin_cf_test.cjs`)는 scratchpad 임시 파일이며 저장소에 없다. 열람해 보니 산식/멱등/회수/fail-closed/불변식을 다루는 합리적 구성이지만 verify 는 못 했다 (라이브 금지).
  - `firebase.json` 의 emulators 에는 `firestore` 만 있고 **functions 에뮬레이터 설정이 없다** (developer 는 CLI 플래그 등 임시 구성으로 실행한 것으로 추정). 재현하려면 `functions` 빌드 + eventarc 포함 에뮬레이터 + 프로젝트 ID 고정이 필요.
  - 에뮬레이터는 `retry:true` 의 재시도 동작을 재현하지 않으므로 ③ 은 어차피 코드 추적이 근거.
  - 조치 제안: 스크립트를 `functions/test/` 또는 `test_rules/` 에 커밋하고 firebase.json 에 functions 에뮬레이터 + `npm run test:cf` 추가 (후속 task).

### ⑨ 이력 / 감사 추적 (audit_trail §4)

| 체크 | 결과 |
|---|---|
| 당시 값 박제 (`orderTotalPrice` / `accrualRate` / `balanceAfter`) | PASS. earn 에 박제, clawback 은 earn 값을 상속. 정책 변경 후 과거 내역 불변 |
| 원장 `storeId` / `storeName` | PASS (단 `storeId` 가 없으면 `""` 로 기록 -- 조용한 빈 값, 보류 H3) |
| 원장 `brandId` | **FAIL (F2)** |
| 적립률 설정 변경 이력 | 후속(H7) 범위 -- FAIL 아님. 확인: `saveAccrualRate` 는 `update({'accrualRate': rate})` 덮어쓰기. 이전 값, 변경자, 시각 모두 소실. `updatedBy/updatedAt` 필드도 없음 |
| 행위자 기록 | `enabled` 토글도 누가/언제 껐는지 기록되지 않음 (H7 에 enabled 토글 포함 여부를 확정 필요 -- 비상 정지는 책임 추적 가치가 가장 큼) |
| CF 로그 의존 | 보류 H2: 중단/무효 설정으로 **건너뛴** 적립·회수는 Cloud Logging 에만 남는다 (보존 기간 제한). 추후 "중단 기간 소급 적립" 판단 근거가 로그뿐이다. 영구 기록(예: skipped 카운터 문서 또는 `config/qoin` 의 enabled 변경 이력)이 필요 |
| 일괄 처리 | 해당 없음 |

### ⑩ 아키텍처 / 절대 규칙 -- PASS
- `lib/presentation`, `lib/domain` 의 firebase/cloud_firestore import 는 Qoin 파일에 0건. 검출된 `auth_error_message.dart`, `remote_notification_message.dart` 는 Qoin 이전부터 존재하는 기존 파일(범위 밖, 참고).
- Firestore 직접 사용은 `qoin_remote_data_source.dart` 한 곳. Repository 인터페이스 2개 분리(`QoinRepository` 읽기 전용 / `QoinConfigAdminRepository`), spec §10.1 "쓰기 메서드 없음" 보존.
- 적립률 값이 Dart/TS 어디에도 상수로 없음 (`config/qoin` 단일 출처). 단 CF 의 `0..1` 범위 상수는 검증용.
- 범위 밖 수정: `users` 관련 `UserModel/UserEntity` 의 `qoinBalance` 필드 추가는 spec 범위. `toFirestoreForCreate` 에 미포함 (F1 의 완화는 아님 -- 서버 Rules 가 막아야 함).
- 참고(낮음): `admin_qoin_settings_page.dart` 가 `presentation/customer/qoin/providers/*` 를 import (admin -> customer 교차). 의존 방향 위반은 아니나 providers 를 공용 위치로 옮기는 정리 후보.
- 커밋 위생: implementation 이 밝힌 대로 qoin 파일 일부가 직전 docs 커밋(51d7b4e, b11b3de)에 섞여 있다 (`admin_qoin_settings_page.dart` 878줄이 docs 커밋에 포함). 기능 문제는 아님.

## 4. 시나리오 (QM1~QM10) 실행 가능성 감사

트리거가 `onDocumentUpdated` 라는 점은 spec §13.4 / implementation 에 명시되어 있고 (`ready` 로 생성 -> `completed` 로 수정), 필드 세트도 `OrderModel.fromFirestore` 와 대조해 충분하다: 모든 필드가 `?? ''` / `?? 0` / `?? DateTime.now()` 로 방어적 파싱이며 (`order_model.dart` L83-113) `userId/storeId/storeName/status/totalPrice` 만 CF 에 필요. `items: []`, `paymentInfo: {}` 허용. 진행 중 배너(`paid~ready`)가 `ready` 상태 주문을 센다는 부수 효과 있음.

시나리오 결함 (FAIL 아님):

| # | 결함 | 대안 |
|---|---|---|
| S1 | **QM1 선행조건 누락**: "적립 정책 문구" 는 `config/qoin` 이 있고 `enabled:true` 여야 보인다. 준비 단계 1이 config 생성만 말하고 값(`accrualRate 0.03`, `enabled true`)을 안 적음. 또 QM1 은 `ready` 주문이 이미 있는 상태라 **진행 중 주문 배너가 보이는 것이 정상**인데 기대 결과에 없음 | 준비에 값 명시, QM1 기대 결과에 배너 추가 (또는 주문 생성 전에 QM1 수행) |
| S2 | **단위/문구 stale**: QM1 "잔액 `0 Qoin`", 실제 구현은 `0 Q` (design 확정) | 문구를 `0 Q` 로 정정 |
| S3 | **관리자 화면 시나리오가 QM 에 전혀 없음** (D4-d 가 spec §15 에서 추가돼 §13.4 미갱신). 0.03 / 0 / 25 / 30 입력 차단, 확인 다이얼로그 환산, 끄기 다이얼로그 카피, 스위치 독립성이 라이브 검증 대상에서 빠짐 | QM11~ 신설: 입력별 에러 문구, `10,000원 -> 300 Q`, 끄기 후 환불 -> 회수 안 됨 (QM6 와 쌍), 문서 부재 시 스위치 비활성 |
| S4 | **QM6 불완전**: "새 주문 전이에 적립 없음" 에 두 번째 주문(`ready`) 생성 절차가 없고, 같은 주문을 재사용하면 `earn_{id}` 가 이미 있어 `already_applied` 로 **fail-closed 와 구분되지 않음** | 신규 주문 `manual_qoin_test_02` 를 `ready` 로 만들고 enabled=false 상태에서 `completed` 로 수정 -> 원장/잔액 불변. 쌍으로 enabled=false 상태에서 QM4 형 환불 회수 안 됨 확인 |
| S5 | **QM7 비현실적**: Console 로 원장 51건 수동 주입 (Admin 쓰기로만 가능, 불변식 `qoinBalance==Σamount` 도 깨짐). QM4/QM2 도 순서 의존 (QM5 의 rate 변경이 QM4 보다 뒤여야 -135) | 테스트 전용 계정에서만 하고 종료 후 정리하거나 단위 테스트(상수 `historyLimit`)로 대체. 순서 의존을 명시 |
| (참고) | 반례 시나리오 부족: 소액 주문 (예: totalPrice 30 원 @3% -> 0 적립, 원장 없음) 과 `completed` 생성 시 비발화를 확인하는 부정 케이스 | 위 S4 처럼 부정 케이스 추가 |

## 5. 보류 / 후속 후보

| # | 내용 | 제안 우선순위 |
|---|---|---|
| H1 | 회수 선행 경합: `completed -> refunded` 의 clawback 이 earn 보다 먼저 실행(예: earn 이 일시 장애로 재시도 대기 중)되면 `skipped_no_earn` 로 **영구 종료**(재시도 없음), 이후 earn 이 성공하면 환불된 주문의 Qoin 이 남는다. 현실 확률은 낮으나 `retry:true` 는 최대 7일 재시도. earn 트랜잭션에서 주문의 현재 status 를 확인하는 방안 검토 | 낮음 |
| H2 | 중단/무효 설정으로 건너뛴 정산의 영구 기록 부재 (CF 로그만) | 중 (H7 와 함께) |
| H3 | `storeId`/`storeName` 부재 시 `""` 로 원장 기록 -- 집계에서 빈 매장으로 섞임. 필수 필드로 보고 skip 하거나 로그 | 낮음 |
| H4 | `enabled` 토글의 행위자/시각 기록 (비상 정지 책임 추적) | H7 확장 시 포함 확정 필요 |
| H5 | 실기기 항목: 스크린리더 `Q` 발음, QM1~QM10 라이브, 운영 인덱스(`failed-precondition` 여부), 중단 시 고객 plate 문구 | 사용자 수행 |

## 6. 라이브 시나리오 수행 전 권장 순서
1. F1 Rules 수정 + 하네스 케이스 추가 (또는 사용자가 위험 수용 결정)
2. F2 brandId 추가 (CF 배포 전)
3. 배포 순서는 implementation.md 의 "사용자 배포 명령" 준수 (config 문서 선행)
4. 시나리오 S1~S5 보정 후 QM 수행

---

## Z. FAIL 3건 처리 (2026-10-22)

### Z-1. F1 — `users` self-create 로 잔액 심기 [**보안 구멍, 수정 완료**]

**가장 심각한 건이었다.** 잔액 보호(`isSelfProfileUpdate` 의 `hasOnly` 화이트리스트)가 **update 에만** 걸려 있고 `allow create` 에는 필드 제한이 없었다.

```
신규 가입 → users/{uid} 를 { role:'customer', qoinBalance: 999999 } 로 직접 생성
→ CF 는 기존 잔액을 읽어 거기에 더한다 (절대값 갱신이지만 before 를 신뢰)
→ 그 값이 그대로 유효해진다
```

1차는 Qoin 사용처가 없어 피해가 없지만, **2차(Qoin 사용)가 붙는 순간 무한 Qoin** 이 된다. 배포 전에 잡은 것이 다행이다.

**수정**: `allow create` 에 `!('qoinBalance' in request.resource.data)` 추가. 기존 `brandId` 차단과 같은 방식이다.

**회귀 테스트 추가** (하네스 **73/73 PASS**)

| 케이스 | 기대 | 결과 |
|---|---|---|
| self-create 에 `qoinBalance` 포함 | deny | **PASS** |
| self-create (`qoinBalance` 없음) | allow | **PASS** |

> 기존 QR9/QR10 은 **update 만** 검증했다. create 경로가 비어 있었던 것이 이 구멍의 원인이며, 이제 하네스가 회귀로 잡는다.

### Z-2. F2 — 원장에 `brandId` 누락 [수정 완료]

`OrderModel` 에는 `brandId` 가 있는데 CF 가 원장에 복사하지 않았다. `audit_trail.md` §5 위반이다.

**나중에 추가하면 과거 원장에 값이 없어 소급 집계가 불가능**하다. 비용 부담 주체를 브랜드·매장으로 확정했으므로(backlog H1) 정산 시 반드시 필요하다. 배포 전이라 과거 행 누락 없이 고쳤다.

`earn` / `clawback` 양쪽에 `brandId` 를 기록한다 (개인 매장은 `null`).

> **오늘 신설한 `audit_trail.md` 가 바로 일한 사례다.** §5 에 "원장 스키마를 정할 때 `storeId` 와 `brandId` 를 빠뜨리지 않는다" 고 적어둔 것이 검증 항목이 되어 잡혔다.

### Z-3. F3 — CF 와 관리자 화면의 적립률 경계 불일치 [수정 완료]

관리자 화면은 0.1~20% 를 강제하는데 CF 는 `0..1` 만 검사했다.

```
Console 에서 accrualRate: 0.5 → CF 통과 → 50% 적립
```

`0.03` → `3` 같은 실수는 막히지만 `0.3` 은 막히지 않았다. **화면 검증은 우회될 수 있으므로 돈을 발행하는 쪽에도 같은 경계가 있어야 한다.**

**수정**: CF 에 `MIN_RATE = 0.001` / `MAX_RATE = 0.2` 를 두고 관리자 화면과 일치시켰다.

### Z-4. 수정 후 검증

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 129 passed |
| `functions` `npm run build`(tsc) | 통과 |
| Rules 하네스 | **73/73 PASS** (F1 회귀 2건 추가) |

### Z-5. ⚠️ 재배포 필요

F1(Rules) 과 F2·F3(CF) 수정은 **배포해야 적용된다.** 이미 배포된 버전에는 구멍이 그대로 있다.

```
cd /Users/Byeonguk/Developer/OrderApp && npx firebase-tools deploy --only firestore:rules
cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && npx firebase-tools deploy --only functions:onOrderQoinSettled
```

`config/qoin` 은 이미 생성·활성화돼 있으므로 다시 만들 필요가 없다.
