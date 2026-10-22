# Qoin 적립률 계층화 테스트 리포트

검증일 2026-10-22 / 대상 커밋 `9068fa9` (+ 백엔드는 `68ee77a` 에 선행 포함) / 기준 `spec.md` · `design.md` · `implementation.md` · `audit_trail.md` §4 · `data_ownership.md` · CLAUDE.md 절대 규칙

결과 요약: **PASS 14 / FAIL 6 / 보류 3.** 자동 테스트(analyze, flutter 260, TS 50, Rules 163)는 구현자 보고를 신뢰하고 재실행하지 않았다. 대신 테스트가 보지 못하는 곳(실제 주문 경로, Rules 경로 독립 열거, 운영 시나리오)을 코드 추적과 에뮬레이터 임시 스크립트로 검증했다.

---

## FAIL

### F1. [Critical] 브랜드 단계가 실제 앱에서는 한 번도 적용되지 않는다 (주문의 `brandId` 가 항상 null)

- 근거
  - `lib/data/repositories/payment_gateway_repository_impl.dart` `_cartToMap` (L175~) 은 `storeId / storeName / subtotal / discount / totalPrice / items` 만 보낸다. `brandId` 없음. `CartEntity` 에는 `brandId` 필드 자체가 없다.
  - `functions/src/verifyTossPayment.ts` L225 는 `brandId: data.cart.brandId ?? null` → 앱이 보낸 주문은 전부 `orders.brandId = null`.
  - `onOrderQoinSettled` 는 브랜드를 `after.brandId`(주문 문서)에서 읽는다. null 이면 브랜드 문서를 아예 요청하지 않는다 (`refs` 에 push 안 함).
  - spec §1.5 는 "주문 문서에 brandId 가 이미 있다" 를 전제로 채택했으나, 그 값을 채우는 클라이언트 코드는 없다. CF 에뮬레이터 테스트(`emulator.test.mjs` L80, `completeOrder`)는 주문을 `brandId` 를 넣어 직접 시드하므로 이 단절을 잡지 못한다.
- 재현 경로
  1. admin 이 브랜드 A 에 5% 설정 (전역 3%, 산하 매장 S 는 개별 설정 없음).
  2. 고객이 앱으로 S 에서 10,000원 결제 → 점주가 완료 처리.
  3. 기대 500 Qoin / `accrualRateSource: 'brand'`. 실제 300 Qoin / `'global'`.
  - 결과: 브랜드 일괄 적용 · 브랜드 편집 · 우선순위 사슬 화면은 "브랜드 5% 를 따른다" 고 표시하지만 실제 적립은 전역값이다. 화면과 돈이 어긋난다. 원장 `brandId` 도 계속 null 이라 1차 F2 가 의도한 정산 소급 자산도 비어 있다.
- 부수 보안 결함: `cart` 는 클라이언트가 보내는 값이라 `brandId` 를 임의로 지정할 수 있다. 앱을 우회한 호출(callable 직접 호출)로 매장과 무관한 고효율 브랜드(최대 20%)를 지정하면, 개별 설정이 없는 매장에서 그 브랜드 적립률이 적용된다. 이번 변경이 `order.brandId` 를 금액 결정에 쓰기 시작하면서 신뢰 경계가 됐다.
- 수정 방향 (수정은 하지 않음): 적립 시 이미 읽는 `stores/{storeId}` 의 `brandId` 를 신뢰원으로 쓰고 order 의 값은 무시한다. `getAll` 1회 → store 읽고 brand 읽는 2단계가 되므로 spec §5 의 "1 라운드트립" 은 바뀐다. 또는 `verifyTossPayment` 가 store 에서 brandId 를 채운다. 어느 쪽이든 E2E 테스트는 "시드 주문" 이 아니라 실제 `verifyTossPayment` 산출 주문으로 검증해야 한다.

### F2. [Medium] 덮어쓰기가 매장별 이전 값을 기록 없이 지운다 (audit_trail §4-2 위반, spec 의 "통과" 판정이 사실과 다름)

- 근거: `applyBrandQoinRate.clearOverrides` 는 매장 `qoinAccrualRate` 를 `FieldValue.delete()` 하고 `stores/{id}/qoinRateHistory` 에는 아무것도 쓰지 않는다. 브랜드 이력 1건에는 `clearedCount` 숫자만 있다. spec L578 은 이를 "`clearedCount` 로 남는다 → 통과" 로 판정했으나, 누구의 어떤 값(3%·0%·무효)이 지워졌는지는 어디에도 없다.
- 재현 경로: admin 이 매장 S 를 0% 로 잠금 → 이후 브랜드 편집에서 "덮어쓰기" 실행 → S 의 점주가 자기 매장 이력 화면을 열면 변경 기록이 없는데 적립률이 바뀌어 있다. 브랜드 이력에도 S 의 0% 였다는 정보가 없다.
- 보완 필요: 브랜드 이력에 `clearedZeroCount`(0% 였던 수)와 `clearedInvalidCount`, 또는 지운 매장의 `{storeId, before}` 목록(수백 건이면 하위 문서). 최소한 0% 수는 남아야 `68ee77a` backlog 의 A/C 안 판단 근거가 된다.

### F3. [Medium] `enabled`(비상 정지) 변경 이력에 `changedBy` 가 없다 (audit_trail §4-4)

- 근거: 토글은 클라이언트 직접 쓰기, 이력은 `onQoinConfigWritten` 이 사후 기록하며 `changedBy: null, source: 'direct'`. Firestore 트리거는 요청자 uid 를 모른다. 앱 UI 로 admin 이 끈 것도 "콘솔 직접 수정" 과 구별되지 않는다.
- 재현 경로: admin A 가 앱에서 비상 정지를 켬 → 이력 화면에 행위자 "알 수 없음". 돈이 멈추는 가장 영향이 큰 스위치가 가장 추적이 약하다.
- 보완 방향: `enabled` 도 callable 로 옮기거나(CF 장애 중 끌 수 있어야 한다는 사유는 별도 비상용 경로로 분리), Rules 에서 `enabledChangedBy == uid()` 를 강제하는 필드를 같이 쓰게 한다.
- 참고: spec §4-⑩ 에서 의식적으로 수용한 trade-off 이나, 체크리스트 4번은 "운영자 행위는 uid 를 남긴다" 이므로 FAIL 로 분류한다.

### F4. [Low-Medium] 13번째 적립률 쓰기 경로: 점주가 매장을 삭제 후 같은 ID 로 재생성하면 개별 설정이 사라진다

- 독립 열거 결과 구현자의 12경로(stores create/update 3분기, brands create/update, config create/update/delete, 이력 3종 + CG)는 실제로 전부 막혀 있고 하네스 RH 케이스도 올바른 경로를 때린다 (PASS-1 참조). 단 `stores` 의 `delete` 는 `isAdmin() || isStoreOwner` 라 개별 설정을 **제거**하는 경로가 하나 더 있다.
- 에뮬레이터로 확인 (임시 스크립트, 저장소 밖): OWNER 가 `qoinAccrualRate: 0` 인 자기 매장을 `deleteDoc` → **ALLOWED**, 이어서 같은 ID 로 `setDoc({ownerId, name, status:'pending'})` → **ALLOWED**.
- 영향: admin 이 잠근 0% 를 점주가 해제할 수 있다. 다만 재생성 문서는 `status: pending` 이어야 해서 재승인이 필요하고, 이력 서브컬렉션은 고아가 된다(점주 read 는 `get(store).data` 실패로 거부, admin 만 읽음). 삭제 자체가 이력에 안 남는 것도 같은 문제다.
- 하네스 부재: 이 경로를 검증하는 RH 케이스가 없다. 존재하지 않는 경로를 "전수" 라고 부른 점이 spec §9 의 약점이다.

### F5. [Low-Medium] 일괄 적용 재개·동시 실행에 서버 측 보호가 부족하다

- (a) 재개가 상태를 재검증하지 않는다. `resumeHistoryId` 경로는 이력의 `status` 만 보고 `finishOverwrite` 로 간다. 중단(partial) 이후 admin 이 브랜드 값을 다시 바꿨거나(partial 은 `in_progress` 가 아니라 막히지 않음) 매장에 새 개별 설정을 의도적으로 만들었어도, 재개가 그 개별 설정을 옛 이력의 이름으로 지운다. 이력은 "5% 로 덮어씀" 인데 실제 브랜드 값은 3% 인 상태가 된다.
- (b) 동시 시작 보호가 트랜잭션 밖이다. `running` 조회(`where status == in_progress`) 와 이력 생성 사이가 원자적이지 않고, 트랜잭션은 브랜드 값이 이미 같으면(`sameValue`) 바깥에서 센 `scan.withOverride > 0` 만 보고 두 번째 이력을 만든다. 두 admin(또는 이중 호출)이 scan 구간에 겹치면 이력 2건 + `clearOverrides` 2개 동시 실행 + 카운트 이중 보고. (코드 추론이며 동시 호출 에뮬레이터 재현은 하지 않았다. 구현자의 108회 폴링 테스트는 중간값 노출만 본다.)
- (c) 일괄 진행 중 `setQoinAccrualRate`(매장 단건)가 막히지 않아, 커서가 지나간 매장에 새로 만든 개별 설정은 "전부 초기화됨" 이력에도 불구하고 남는다.

### F6. [Low] `docs/processes/data_ownership.md` 미갱신 (Rules 와 문서의 silent drift)

- `qoinAccrualRate` / `config/qoin` / `qoinRateHistory` ×3 / `qoinTransactions` / CF 전담 규칙이 문서에 한 줄도 없다 (`grep` 0건). 1차부터의 누락이 계층화에서도 이어졌다. 테스터 지침상 "코드와 Rules 의 silent drift" 항목이다.

---

## PASS

1. Rules 독립 열거: `qoinAccrualRate`(stores/brands) / `accrualRate`(config) / `qoinRateHistory`(3 서브컬렉션 + CG) / `qoinBalance`(users) 의 도달 경로를 처음부터 끝까지 읽고 직접 셌다. create / update / delete 가 경로마다 따로 막혀 있고(stores create `!hasQoinRateOnCreate`, update 최상위 `!touchesQoinRate()`, brands 동일, config create/update/delete, 이력 `if false`), 구현자의 12경로와 일치한다. 13번째는 F4 하나뿐이다.
2. admin 전능 분기 우회 없음: stores/brands update 는 `!touchesQoinRate()` 가 `isAdmin()` 보다 바깥 조건이고, config 는 `isAdmin()` 안에서 `accrualRate` 변경을 막으며 삭제는 `if false`. `deleteField`, `setDoc(merge)` 모두 RH3b/RH3c/RH9b/RH9c 가 때린다.
3. 와일드카드와 명시 match 충돌 없음: `/{path=**}/qoinRateHistory/{id}` 는 `read: isAdmin()` 만 부여하고 쓰기는 부여하지 않는다. 명시 match 와 OR 로 합쳐져도 더 느슨해지는 쪽이 없다 (RH23~24c).
4. 하네스 RH 케이스가 실제 경로를 때린다: RH13~15 가 3범위 × 4역할 × c/u/d 를 existing/fresh 문서로 구분해 호출하고, 시드에 S_OVR(개별 설정 있음)·S_BR(브랜드 가맹)이 있어 "문서 부재로 인한 가짜 deny" 가 아니다. deny 케이스마다 대응하는 allow 회귀 케이스(RH4b, RH5, RH5c, RH7c, RH7d, RH8, RH11b)가 있다.
5. 기존 클라이언트 쓰기가 막히지 않는다: `store_remote_data_source` 는 전부 `update(fields)`, `brand_remote_data_source.set` 은 `merge: true` 라서 모델이 `qoinAccrualRate` 를 싣지 않는 한 `touchesQoinRate` 에 걸리지 않는다. 모델은 `toFirestore*` 에 이 필드를 넣지 않는다. `SetOptions` 없는 전체 `set` 이 있었다면 개별 설정이 있는 매장 저장이 전부 거부됐을 것이다 — 없음을 확인했다.
6. 경계값 단일 출처: `0.001/0.2` 는 `qoin_policy.dart`(tenths 1/200 → 1/1000, 200/1000 이 TS 의 리터럴과 같은 double) 와 `qoinRate.ts` 에만 있다. `lib/`·`functions/src` 에서 다른 선언을 찾지 못했다. UI 입력(`validateRateInput`)은 `0.03` 을 `tooLow` 로 먼저 거른다.
7. 4층 판정 일치: Dart `fromRaw` / TS `classifyRate` 의 분기 순서가 같다 (부재 → 비number·비유한 → 0 → 범위). 진리표 resolve 20행·classify 14행·callable 13행이 0.0005 / 0.0009 / 0.001 / 0.2 / 0.2001 / 0 / 음수 / 1 / 0.5 / NaN / 문자열 / null 을 덮는다. 전역 0 무효, 격자(0.0305 거부)도 있다.
8. Rules 가 범위 검사를 안 해도 되는 전제가 성립: 적립률 쓰기 클라이언트 경로는 F4 외에 없고 CF 입력은 `isValidCallableRate` 로 검증된다. 남는 우회는 Console/Admin SDK 이며 earn 시점의 `classifyRate` 가 fail-closed 로 받는다.
9. 4값 타입의 예상 밖 값: 문자열·bool·배열·빈 맵·null·NaN·Infinity 는 Dart `raw is! num` / TS `typeof !== 'number'` 로 모두 invalid. `present` 플래그로 부재와 null 을 구분한다.
10. 무효 처리 정책이 spec 과 일치: 무효는 상위 폴백 없이 멈춘다 (store 무효 + brand 유효 → `invalid_store`, 적립 안 함, 로그만). Dart 해석도 같은 순서다. 폴백이 없어서 잘못된 값이 조용히 다른 값으로 돈을 내보내는 일은 없다.
11. 이력 위조·삭제 불가: 이력 3종 모두 admin 포함 create/update/delete `if false`. CF 가 `requireAdmin` 으로 서버에서 role 을 재검증한다. callable 경로 이력은 값과 같은 트랜잭션이라 "성공했는데 이력 없음" 이 구조적으로 불가능하고, 값이 같으면 아무것도 쓰지 않아 재시도 중복도 없다. `changedBy` 는 callable 경로 모두 uid 로 채워진다 (F3 의 `enabled` 제외).
12. 1차 회귀: 비상 정지 토글은 `qoin_kill_switch_card.dart` 로 분리돼 `canUse` 조건과 direct write 경로를 유지한다. 1차 admin 페이지에 잔액/내역 조회 UI 는 원래 없었다 (diff 로 확인). `qoin_di_providers.dart` 이동은 analyze 0건으로 참조 누락 없음. 고객 plate 의 숫자 제거(spec §4-⑨)도 반영.
13. 원장 호환: Dart 는 `accrualRateSource` 를 읽지 않아 필드 없는 과거 원장에서 깨지지 않는다. TS clawback 은 `earn.accrualRateSource ?? null`. 적립 기록이 없는 주문의 회수는 `skipped_no_earn` 으로 로그 후 종료하며 잔액을 건드리지 않는다. 0% 매장이어도 회수는 통과하도록 earn 분기 밖에 있다.
14. H5 보존/덮어쓰기 분기와 화면 경고: preserve 는 한 트랜잭션에서 `completed` 와 함께 `affectedCount = total − withOverride`, `preservedCount = withOverride`. overwrite 는 값+이력 선기록 후 청크 삭제라 중간 상태가 없다. 확인 다이얼로그는 영향 매장 수와 "그중 적립 안 함 N곳도 다시 적립해요" 줄을 따로 보여주고 체크박스를 요구한다 (`qoin_rate_confirm_dialog.dart` L381, `overriddenStopped` 는 라이브 스트림에서 계산). 무효 개별 설정도 `overridden` 에 포함돼 센다. 절대 규칙 1~4: presentation/domain 의 Firebase import 신규 없음, `Color(0x`·`Colors.*` 하드코딩 없음, 하드코딩된 키 없음.

---

## 보류

### H-1. 0% 덮어쓰기 정책 (backlog `68ee77a`) — 이번 구현의 실제 동작 기록
- 화면 경고 없이 일어나지는 않는다 (PASS-14). 다만 경고는 "N곳도 다시 적립" 한 줄 + 체크박스이며, 그 N 은 화면의 라이브 스트림에서 센 값이다. 서버가 실행 시점에 다시 센 값과 다를 수 있다 (사이에 다른 admin 이 0% 를 걸면 다이얼로그 숫자보다 많이 덮인다). 그리고 결과가 이력에 남지 않는다 (F2). 정책 A/C 중 무엇을 택하든 서버가 "0% 는 건너뜀" 을 집행해야 화면 숫자와 무관하게 안전하다.
- 라이브에서 직접 확인할 조작: 앱 admin → Qoin 설정 → 브랜드 → 산하 매장 1곳을 `적립 안 함` 으로 저장 → 같은 브랜드 편집에서 다른 값 + `개별 설정 덮어쓰기` → 다이얼로그에 "적립 안 함 1곳" 줄이 뜨는지 확인 → 실행 후 해당 매장 상세에서 `상위 설정 따르기` 로 바뀌었는지, 매장 이력에 기록이 없는지(F2) 확인.

### H-2. 무효 값 fail-closed 시 소급 적립 수단 없음
- 무효 값은 Console 편집으로만 생긴다 (CF 가 막음). 그러나 그 사이 완료된 주문은 `skipped_invalid_rate` 로그만 남기고 트리거가 `return` 으로 성공 처리되어 재시도되지 않는다. 값을 고쳐도 그 주문들은 영영 적립되지 않는다 (재처리 CF·수동 보정 경로 없음). 로그는 Cloud Logging 보존 기간에 의존한다 (audit_trail §4-6). 대안: 무효 값 감시 알림, 또는 `skipped_*` 주문을 Firestore 에 기록하는 보정 큐. 우선순위는 사용자 판단.

### H-3. 미배포 인덱스와 허브 50건 한계 (§7 시나리오)
- 배포 전에는 admin 허브의 "최근 변경", 전체 이력 화면(`collectionGroup('qoinRateHistory').orderBy('changedAt')`)이 `failed-precondition` 으로 실패한다. 구현자 설계상 허브 partial 배너는 에러 시 조용히 생략되므로, **인덱스 미배포 상태에서는 중단된 일괄 적용이 허브에 영원히 보이지 않는다.** 에뮬레이터는 인덱스를 강제하지 않아 테스트로는 못 잡는다.
- 라이브 확인 (배포 후, 사용자 실행): `cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:indexes --project order-app-5957e` 후, 앱 admin → Qoin 설정 허브에 "최근 변경 …" 이 뜨고 전체 이력 화면이 열리는지 확인.
- 50건 한계가 실제로 문제 되는 시나리오 (허브는 모든 범위가 섞인 최근 50건 안에서만 partial/중단을 판정한다. 각 단건 변경·일괄 적용·`enabled` 토글이 1건씩 쌓인다):
  1. 매장 수 600 규모 초기 세팅: admin 이 매장 개별 적립률을 하루에 50곳 넘게 단건 설정하면 같은 날 중단된 일괄 적용(partial)이 50건 뒤로 밀려 허브에서 사라진다. 브랜드 편집 화면에서만 보이므로 admin 이 해당 브랜드를 열어야 알 수 있다.
  2. 운영기: 매장 100곳이 주 1회 정도 조정된다고 가정하면 주당 약 100건 → 약 3~4일이면 일주일 전 partial 은 윈도우 밖이다. 일괄 중단은 "부분 적용" 상태(일부 매장만 초기화됨)라 방치되면 브랜드 안 매장 적립률이 서로 다른 채 굳는다.
  3. 반대 방향: `in_progress` 가 서버 크래시(540초 타임아웃)로 갱신이 멈추면 5분 후 "중단"으로 판정되는데, 그것도 같은 50건 안에 있을 때만 보인다.
  - 보강 방향: 브랜드 문서에 `qoinBulkPending: historyId` 같은 포인터를 CF 가 유지(허브는 `brands` 스트림에서 판정), 또는 `status` 필터용 CG 복합 인덱스를 배포.

---

## 놓치기 쉬웠던 점 / 프로세스 메모

- 백엔드 전부(`firestore.rules`, `functions/src/*`, 진리표)가 `docs:` 접두 커밋 `68ee77a` 에 들어갔고, `9068fa9` 의 stat 에는 보이지 않는다. 커밋 `9068fa9` 메시지의 "구현 전부" 는 사실과 다르다. 배포 범위를 커밋 단위로 판단하면 Rules/Functions 를 놓친다.
- 테스트가 모두 통과한 이유와 F1 이 안 잡힌 이유는 같다: 에뮬레이터 E2E 가 주문을 직접 시드한다. 이번 기능의 최종 사용자 경로(앱 → `verifyTossPayment` → `orders` → 적립)는 어떤 자동 테스트도 지나가지 않는다.
- 오프-그리드 값(Console 로 넣은 `0.0015`): CF 는 0.15% 로 계산하지만 `QoinPolicy.formatRatePercent` 는 반올림해 `0.2%` 로 표시한다. 유효 범위 안이라 fail-closed 에도 걸리지 않는다. 낮은 우선순위.
- `setQoinAccrualRate` 는 이전 값이 무효(문자열 등)였을 때 이력 `before` 를 `null` 로 기록한다 ("설정 없음" 과 구별 불가). 감사 정밀도 문제.

## 우선순위 제안

1. F1 (주문 brandId — 서버가 store.brandId 를 신뢰원으로) — 배포 전 필수. 이대로 배포하면 브랜드 단계가 죽어 있고 클라이언트 지정 brandId 로 임의 브랜드 요율을 받을 수 있다.
2. F2 + H-1 (덮어쓰기: 0% 보호와 매장별 기록) — 같이 설계하면 한 번에 닫힌다.
3. F3, F4, F5, F6.
