# Qoin 적립률 계층화 테스트 리포트

> **1차 리포트(아래 "1차" 절)는 이력으로 보존한다.** 2차 검증(대상 커밋 `2caf3d3`)은 파일 맨 아래 "2차" 절에 있다. 1차 FAIL 6건의 종결 여부는 2차 절 §C 참조.

---

# 1차 (커밋 `9068fa9`) — 이력

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


---
---

# 2차 (커밋 `2caf3d3`)

검증일 2026-10-22 / 기준 `spec.md` §20(+§20.3.1 개정판·§20.14) · `design.md` §18 개정 2·3 · `implementation.md` 개정 2 · `audit_trail.md` §4 · `data_ownership.md` §2.11/§3 · CLAUDE.md 절대 규칙

**결과 요약: PASS 17 / FAIL 6 / 보류 1.** 돈이 새는 FAIL 은 없다. 배포를 막을 FAIL 도 없다(§ 마지막 "배포 판단"). 자동 테스트는 재실행하지 않았다(`flutter analyze` 만 확인: 이슈 0). 대신 **자동 테스트가 보지 못하는 곳**을 직접 재현했다: CF 에뮬레이터 임시 스크립트, Rules 에뮬레이터 임시 스크립트, 위젯 임시 테스트(저장소에는 남기지 않음, working tree 깨끗). 스크립트는 스크래치패드에 있다.

## 검증 방법 (재현 가능)

- CF 에뮬레이터: 스크래치패드 `cf_probe.mjs` 를 `cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 emulators:exec --only firestore,functions --project order-app-5957e "node <스크래치패드>/cf_probe.mjs q1,n4,race,partial,f2,f3"` 로 실행. 주문은 운영과 같은 `buildOrderData` 로 만들었다(손 시드 0).
- Rules: 같은 방식으로 `rules_probe.cjs`(178 경우의 수, 5필드 × stores/brands × 4역할 × update/merge/deleteField/create + 추가 경로), `rules_probe2.cjs`, 구 Rules(`git show 30315fd:firestore.rules`) 대조.
- Dart: 임시 위젯 테스트로 브랜드 편집 페이지를 pointer / history 가 어긋난 상태로 그려 확인 후 삭제.

---

## A. developer 자진 신고 3건 판정

### A. 브랜드 편집 `이어서 적용` 배너 → **FAIL (S1)** — 1차 H-3 와 같은 패턴이 남아 있다, 그리고 더 나쁜 방향도 있다

코드: 편집 페이지는 `qoinRateHistoryProvider(brand, limit 20)` 의 `asData?.value.where(isUnfinished).firstOrNull` 로 배너를 정한다. 허브·브랜드 목록 태그는 **브랜드 문서의 포인터**(`qoinBulkStatus`)를 쓴다. 같은 사실을 두 화면이 서로 다른 출처로 판정한다.

**임시 위젯 테스트로 재현한 결과**

| 상태 | 허브 | 브랜드 편집 페이지 |
|---|---|---|
| 포인터 `partial` + 이력 스트림 에러 | 배너 **보임** | 배너 **없음**, `이어서 적용` **없음**, 에러 표시도 **없음** (PROBE1: 제목 0 / 버튼 0 / 에러 0) |
| 포인터 **없음**(완료됨) + 옛 이력이 `partial` 로 남음 | 배너 없음 | 배너 **보임 + `이어서 적용` 버튼** (PROBE3: 제목 1 / 버튼 1) → 누르면 서버가 `브랜드 값이 그 뒤에 변경됐어요` 로 거부 |

1. **중단을 알리는 표면은 둘이 아니라 "알리는 곳 + 고치는 곳" 이다.** 허브는 알리기만 하고, 유일한 복구 버튼(`이어서 적용`)은 편집 페이지에만 있다. 허브 배너 탭 → 편집 페이지 → 아무것도 없음 = **막다른 길.** "둘 다 깨지면" 이 아니라 **한쪽(고치는 곳)만 깨져도** 중단은 알려지되 복구할 수 없다.
2. **③~④ 구간 에뮬레이터 재현**: 구 Rules(`30315fd`)로 `admin` 이 `brands/{id}/qoinRateHistory` 를 읽으면 **거부**된다(`rules_probe` 의 "admin read brand history sub" 가 구 Rules 에서만 UNEXPECTED). 이 구간에서 편집 페이지는 PROBE1 상태와 같다 — 에러 문구조차 없다. 사용자는 "이력이 안 보이네" 가 아니라 "배너가 사라졌네 → 중단이 해결됐나?" 로 읽을 위험이 크다. 안전 측 실패가 아니다(1차 H-3 판정이 그대로 적용된다).
3. 이력 20건 창 문제도 같은 뿌리다: 중단 뒤 단건 변경·스위치 변경이 20건 쌓이면 포인터는 `partial` 인데 편집 페이지 배너는 사라진다.
4. 반대 방향(PROBE3)은 A 신고에 없던 **새 결함**이다: 중단 뒤 admin 이 폼에서 그냥 다시 적용(가장 자연스러운 복구)하면 새 이력이 `completed` 가 되고 포인터가 사라지지만 **옛 이력은 영구히 `partial`** 이라, 편집 페이지는 **거짓 경고 + 항상 실패하는 버튼**을 계속 보인다.
- 재현 경로(designer/developer 가 고칠 때): 편집 페이지의 `unfinished` 를 **이력이 아니라 `brand.qoinBulkStatus/qoinBulkHistoryId` 포인터**로 판정하고, 배너 본문에 쓸 `processed/total` 은 `qoinBulkHistoryId` 로 이력 문서 1건을 읽어 채운다(이력 읽기가 실패하면 본문 숫자만 생략하고 배너·버튼은 유지). design §18-8 은 "허브만" 규정했으므로 design 에 편집 페이지 항목 추가가 선행된다.

### B. F5(b) 동시 호출 → **FAIL (S3, Low-Medium)** — 잠금은 의도대로 동작하나, 신고된 불변식 자체가 사실이 아니다

- **포인터 잠금은 정상**: 지연 150ms 로 겹친 호출은 `FAILED_PRECONDITION 이 브랜드에 일괄 적용이 진행 중이에요` 로 거부됐다(스크래치패드 `race` 2번째 케이스). 1차에 지적한 "`running` 조회가 트랜잭션 밖" 은 **닫혔다**(검사가 트랜잭션 안에서 브랜드 문서 read 와 함께 직렬화).
- **하지만 거부가 안 나오는 구간이 있다**: 스캔(`scanStores`)이 트랜잭션 **밖**이라, 첫 호출이 끝난 뒤에 트랜잭션에 도달한 호출은 (a) 포인터는 이미 지워져 있고 (b) 브랜드 값이 같으니 `sameValue` (c) **오래된 스캔의 `withOverride=1500 > 0`** 이라 "할 일 있음" 으로 판단해 **빈 이력을 새로 만든다.**
- **에뮬레이터 실측 (1500곳, 3동시)**: 응답 3개 모두 `changed=true`, `completed`. **브랜드 이력 3건**: `cleared=1500/total=1500` 1건 + `cleared=0/total=1500/processed=0` 2건. developer 의 단언은 `clearedCount>0` 인 이력만 세므로 "이력 1건" 이 통과한다. 신고의 "불변식(브랜드 이력 1건)" 은 **틀렸다**. 매장 이력 1500건 중복 0 · 이중 보고 0 은 맞다(결정적 ID 덕).
- 다른 타이밍(60곳, 지연 300ms/800ms/2500ms)에서는 `changed=false` noop 이 나왔고 이력은 1건이다. 즉 "거부 / noop / 빈 이력 생성" 이 타이밍에 따라 섞인다.
- **noop 이 화면에 무엇으로 보이나**: Dart 어디에서도 `changed` 를 읽지 않는다(grep: `presentation`·`usecases` 에서 소비 0). 결과 카드는 `status == completed` 만 보고 **"적용을 마쳤어요 / 새 적립률 6% / 적용된 매장 0곳 · 초기화된 개별 설정 0곳"** 을 그린다. 이미 같은 값이라 아무것도 안 했다는 사실은 어디에도 없다. "적용했는데 0곳" 으로 읽힌다 — 사용자 질문 기준상 그 자체로 결함.
- 돈 영향 0(빈 이력은 숫자만 지저분). 이력 화면에 "개별 설정 1500곳 중 0곳" 행이 추가되어 감사 기록이 오독된다.
- 수정 방향: 트랜잭션 안에서 `sameValue` 일 때 포인터의 `qoinBulkHistoryId`/완료 시각이 스캔 시작 이후면 noop 처리하거나, `changed=false` 를 결과 카드가 `이미 같은 값이에요` 로 말하게 한다.

### C. Dart 가 CF 응답을 파싱하는 경로 → **PASS (읽기 대조) / 실기기 확인은 보류 1건**

| 대상 | CF 가 보내는 형태 (코드+에뮬레이터 실응답) | Dart 파싱 | 판정 |
|---|---|---|---|
| 레거시 가드 `details` | `{legacyZeroCount: 1, storeIds: ["…"]}` (에뮬레이터 응답으로 직접 확인, F2 스크립트에서 의도치 않게 발생) | `QoinCallable._fromFunctionsException`: `d is Map` → `d['legacyZeroCount'] is num` → `storeIds is List` → `whereType<String>()`. Android 의 `Map<Object?,Object?>` 도 통과 | 형태 일치. `classify('failed-precondition')` = rejected → `failure()` 가 `isLegacyZeroGuard` 를 먼저 본다 |
| 마이그레이션 `raw` | `describeRaw`: 문자열 `"3"` → `"\"3\""`(따옴표 포함 JSON), 숫자 `0.5` → `0.5`, NaN → `NaN`, 부재 → `(absent)` | `parse`: `e['raw']?.toString()`, 카드 `_raw`: `"` 로 시작하면 그대로, 숫자로 파싱되면 그대로 | 일치. **사소한 불일치**: bool `true` / 배열 / 객체는 숫자가 아니라 따옴표가 한 번 더 붙어 `"true"` 로 보인다(타입 표시 취지에 어긋남, 표시 오류, 낮음) |
| 포인터 `qoinBulkStatus` | `"in_progress"` / `"partial"` (Firestore 문자열) | `QoinBulkStatus.fromCode` 의 `code` 가 정확히 같은 두 문자열, `BrandModel.fromFirestore` 단위 테스트 있음 | 일치 |
| 일괄 적용 응답 | `status:"completed"`, 카운트 전부 number | `n(k)` = `(num).toInt()`, `status` 없으면 `partial` 로 폴백 | 일치 (폴백이 안전 측) |
| `partial` 마감 시 | `HttpsError("internal")` | `classify('internal')` → `unknownOutcome` → "결과를 알 수 없어요" 문구 | 서버는 상태를 알지만 화면은 "알 수 없음". 중단은 허브/포인터가 알리므로 허용. S1 이 고쳐져야 의미가 있다 |

- **자동 테스트 공백**: `_fromFunctionsException` 은 private 이라 `details` 파싱을 직접 부르는 테스트가 없다(`qoin_rate_models_test` 는 포인터·모델만). 읽기 대조로는 맞다.
- **보류 1건**: 실기기에서 `FirebaseFunctionsException.details` 가 `Map` 으로 오는지(플러그인이 `additionalData` 를 넘기는 경로)는 에뮬레이터/위젯 테스트로 확인 불가. 배포 ②~③ 후 앱에서 확인: 레거시 `qoinAccrualRate: 0` 인 매장이 하나 있는 브랜드에서 일괄 적용 실행 → "레거시 0% 매장이 있어요 (N곳)" 문구가 뜨면 PASS, 일반 실패 문구가 뜨면 `details` 가 안 넘어온 것. 조작: 앱 admin → Qoin 설정 → 브랜드별 적립률 → 해당 브랜드 → 값 입력 → `덮어쓰고 적용`. 로컬 빌드는 `cd /Users/Byeonguk/Developer/OrderApp && flutter run -d <device-id>`.

---

## B. developer "설계 문제" 4건 판정

1. **레거시 0 가드에 브랜드 자신의 0 포함 → 타당 (PASS).** 브랜드 값 0(= 사실상 꺼짐)을 숫자로 덮으면 산하 전체 적립이 재개된다 — Q1 이 막으려던 바로 그 사고다. spec 이 산하 매장만 언급한 것은 누락이다. 단 **구멍 하나**: `setQoinAccrualRate`(단건)는 같은 가드가 없다. 레거시 0 브랜드에 단건 callable 로 `rate` 를 쓰면 가드 없이 전체 적립이 재개된다. 앱 UI 는 브랜드 쓰기를 항상 `applyBrandQoinRate` 로 보내므로 UI 경로는 안전하고 admin 직접 호출만 해당(낮음). spec 에 "브랜드 자신 포함" 을 명시하고 마이그레이션 완료 뒤엔 어차피 삭제되는 코드다.
2. **옛 `partial` 이 영구히 `partial` → 운영상 문제다 (FAIL S1/S2).** 위 PROBE3(거짓 배너+실패 버튼)이 직접 결과다. 추가로 에뮬레이터(`partial` 시나리오)에서 확인한 것:
   - (i) `partial` 뒤 새 overwrite: 포인터 해제, **옛 이력 `partial` 유지**, 옛 이력 재개 → `FAILED_PRECONDITION`.
   - (ii) `partial` 뒤 **preserve** 적용: 브랜드 값이 바뀌었는데 **포인터가 `partial/옛 id` 로 남는다.** 허브가 계속 "끝나지 않은 일괄 적용" 을 띄우고, 재개는 항상 거부된다.
   - (iii) `partial` 뒤 `setQoinAccrualRate`(브랜드 단건), (iv) `setQoinAccrualEnabled`(브랜드): 둘 다 성공하고 포인터는 `partial` 로 남는다 → 허브 경고 영구화.
   - 탈출구는 **값이 달라지는 overwrite 적용**(또는 남은 개별 설정이 있는 같은 값 overwrite). 개별 설정이 하나도 안 남았고 같은 값이면 noop 이라 **포인터를 지울 방법이 없다**(`sameValue && withOverride==0` → 아무것도 안 함).
   - 수정 방향: 포인터를 쓰는 모든 CF 경로(새 apply 시작, 단건 변경)에서 옛 이력을 `superseded` 로 마감하거나, 포인터를 해제하는 admin 동작(`중단 기록 닫기`)을 둔다. spec 에 추가 규정이 필요하다.
3. **`enabledChangedAt` 미강제 → 안전 측이라는 설명은 반만 맞다 (PASS, 사유 정정).** 직접 Rules 에뮬레이터로 확인:
   - 시각 위조(`enabledChangedAt` 을 2020년으로)는 **허용**되지만 무해하다: 이력의 `changedAt` 은 `serverTimestamp`, 행위자는 `enabledChangedBy == uid()` 로 사칭 불가.
   - **실제 틈은 위조가 아니라 "생략"이다**: admin 이 `enabledChangedBy` 만 쓰고 `enabledChangedAt` 을 안 쓰면 허용되고 이력은 `source:'direct', changedBy:null` 로 **행위자가 지워진다**. 같은 admin 이 이전에 토글했다면 `enabledChangedBy` 조차 안 써도 통과한다(`enabled` 만 단독 update 허용, 이전 uid 와 같으므로). 에뮬레이터 실측: 앱형 토글 → `app_direct`+uid, Console형 → `direct`/null, 행위자 생략형 → `direct`/null.
   - 앱은 항상 둘 다 쓰므로 정상 경로는 안전. 수정은 Rules 한 줄: `enabled` 변경 시 `request.resource.data.enabledChangedAt == request.time` 요구. 우선순위 낮음, 배포 막지 않음.
4. **일괄 완료 화면의 K 줄 숨김을 form 섹션에도 → 과하지 않다 (PASS).** 사실 확인: form 의 K 줄(`qoin_rate_edit_form.dart` L474 `s.disabled > 0 && !brandSwitch.isDisabled`)은 "어느 쪽을 골라도 적립이 시작되지 않아요" 라는 문장이며, 브랜드가 꺼져 있으면 산하 **전체**가 멈추므로 K 줄은 부분 사실이 되어 전체 정지 plate 와 모순된다. design §18 이 다이얼로그/결과 카드에서 같은 이유로 숨기라 했으므로 같은 규칙의 일관된 확장이다. 단 design 에 한 줄 추가해 문서와 코드를 맞출 것(문서 후행).

---

## C. 1차 FAIL 6건 종결 여부

| 1차 | 판정 | 근거 |
|---|---|---|
| F1 | **닫힘 (PASS)** | 주문 문서를 쓰는 곳은 `emulator.test.mjs` L91 하나이고 `buildOrderData` 산출물이다(`orderOverrides` 는 스푸핑용 명시 덧씌우기뿐). `verifyTossPayment` 는 `buildOrderData(data.cart…)`, brandId 는 항상 null, 신뢰원은 `stores.brandId`. T2 골든(Dart `cartToMap` 키 = TS `CONSUMED_CART_KEYS`)이 양쪽을 고정. 내 스크립트도 `buildOrderData` 로 주문을 만들어 브랜드 `source:'brand'` 500 적립 확인 |
| F2 | **닫힘 (PASS)** | 450곳 개별 설정(유효 449 + 무효 `"abc"` 1) 덮어쓰기: 매장 이력에 `op:clearByBulk`, `before`, `beforeState`, `beforeRaw`(무효는 `"abc"`), `bulkHistoryId`, `changedBy`=실행 admin uid, `source:'bulk'`. 개별 설정 없는 매장(455번)은 이력 0. CHUNK 225×2 write = 450 ≤ 500 으로 460곳(2청크) 통과. 브랜드 이력에 `clearedValueCount`/`clearedInvalidCount`. 레거시 0 이 섞이면 가드가 막는다(의도) |
| F3 | **닫힘 (PASS, 단 위 B-3 의 생략 틈)** | 앱 토글(`enabledChangedBy`+`At` 갱신) → `app_direct`+uid, Console 편집/At 미갱신 → `direct`/null 로 **실제 구별**됨(에뮬레이터 트리거) |
| F4 | **닫힘 (PASS)** | 내 Rules 프로브: 점주 delete(개별 설정+스위치 있는 매장) 허용, 같은 ID 재생성(`pending`) 허용, 두 필드 포함 재생성 거부. 하네스 F4a/F4b/F4c/F4c2/F4c3 가 정확히 이 경로를 때리고 시드가 `qoinAccrualRate`+`qoinAccrualEnabled:false` 를 함께 가져 "스위치도 제거되어 적립 사용으로 복귀" 가 반영됐다 |
| F5 | **부분 (FAIL S3)** | (a) 재개 재검증 닫힘: 값 변경·포인터 불일치 거부 확인. (c) 진행 중 단건·스위치 거부는 developer 시드 테스트로 확인. **(b) 위 B** |
| F6 | **부분 (FAIL S5)** | §2.11 은 구현과 대체로 일치하나 아래 드리프트가 남음 |

---

## D. 핵심 회귀 (직접 재현)

- **Q1 PASS**: 브랜드 2%, 매장 4곳(`off`=10% 개별+스위치 off, `offnr`=스위치 off, `ov`=10% 개별, `pl`=없음). 브랜드 5% overwrite → `clearedCount=2, disabledUntouchedCount=2`. 주문 결과: `off` 적립 **없음**(스위치 `false` 유지, 개별 설정만 삭제), `offnr` 없음, `ov` **500 `source:brand`**, `pl` 500. 스위치는 일괄 적용이 쓰지 않는다.
- **N4 PASS**: 브랜드 5%, 매장 개별 10% → 먼저 1000 적립(`source:store`). 브랜드 스위치 off 후 같은 매장 주문 → 적립 **없음**, `qoinSettlementIssues` **미기록**. 환불 → `clawback -1000` **통과**(잔액 0). 매장 스위치 off + 브랜드 on + 매장 개별 10% → 적립 없음.
- **사슬 순서·진리표**: developer 확인을 신뢰(사슬 줄 단위 동일, R06 반전).

## E. Rules 20경로 독립 열거 (처음부터 다시)

보호 필드 5개(`qoinAccrualRate`, `qoinAccrualEnabled`, `qoinBulkHistoryId`, `qoinBulkStatus`, `qoinBulkAt`) × `{stores, brands}` × `{create, update}` = **20 경로**. 코드 읽기로 20 이 맞음을 확인하고 에뮬레이터로 4역할(admin/owner/brand/customer) × `update` / `setDoc(merge)` / `deleteField` / `create` = 160 + 추가 경로를 쏘았다. 보호 필드 값 변경·추가·삭제·full-replace(`set` 으로 필드 누락)·dotted(`qoinAccrualRate.x`)·`config` 의 `accrualRate`/삭제·`qoinSettlementIssues` 쓰기 **전부 거부**. 25건이 "예상 밖" 으로 찍혔으나 전부 **문서에 없는 필드에 대한 `deleteField`(diff 없음, no-op)** 라 쓰기가 아니다(프로브 설계상 허위 양성).

**20 은 맞다. 보호 필드 쓰기 경로의 21번째는 없다.** 다만 "돈의 계수를 결정하는 입력" 으로 범위를 넓히면 **두 경로가 더 있다**:

1. **`stores.brandId` 자가 지정 (create)** — 1차 F1 수정으로 `stores.brandId` 가 금액 신뢰원이 됐는데, 점주의 `stores` create 는 `brandId` 를 검사하지 않는다. 에뮬레이터: 점주가 `brandId:'bA'`(임의 브랜드) 인 `pending` 매장 생성 **ALLOWED**. update 로 `brandId` 변경은 거부(점주·브랜드 모두). 완화 요소: admin 승인 필요 + 승인 상세 화면이 `BrandScopeBadge` 를 표시한다. 하네스에 이 케이스 없음.
2. **자가 `brand` 역할 + 임의 `brandId` → 모든 브랜드/가맹점 Qoin 이력 열람** — 에뮬레이터: `customer` 가 `users/{self}` 에 `{role:'brand', brandId:'bX'}`(허용된 자가 전이) 후 `brands/bX/qoinRateHistory` 와 가맹점 `stores/sX/qoinRateHistory` **읽기 ALLOWED**. `isBrandHolder` 는 `role==brand && users.brandId==brandId` 만 보고 브랜드 승인/소유를 확인하지 않는다. 이력에는 admin uid(`changedBy`)·자유 입력 `reason`·요율 변경 전/후가 있다. 하네스 RH20 은 고정 시드 사용자만 써서 이 경로를 못 잡는다. (users 규칙은 이번 변경 범위 밖의 기존 구멍이지만, 이번에 만든 이력 데이터가 그 위에 올라탔다.)

## F. 과도기 자산 (`TRANSITIONAL(spec §20.4.5)`)

마커가 붙은 파일은 **21개**(코드 20 + `implementation.md`)이고 일괄 삭제 가능한 형태로 모여 있다. 단 **마커 없이 레거시 분기를 가진 파일이 있다**: `lib/presentation/admin/qoin/widgets/qoin_rate_chain.dart`(L120 `setting.isLegacyZero`), `lib/presentation/common/widgets/qoin/qoin_reenable_hint.dart`(L58·64·93·97), `lib/data/models/qoin_config_model.dart`(L24), 테스트 `functions/test/emulator.test.mjs`(섹션 I·`expectOf`), `test/data/qoin_rate_models_test.dart`, `test/presentation/qoin_hub_states_test.dart`, 픽스처 `test_fixtures/qoin_rate_truth_table.json`(`resolve_legacy`, `transitionalExpect` — JSON 이라 주석 불가). 마커 grep 으로만 정리하면 이 파일들이 삭제된 `isLegacyZero`/`QoinRateCellKind.legacyZero` 를 참조해 **컴파일이 깨진다**(조용히 남지는 않음). 가드 테스트(`qoin_architecture_guard_test`)는 3개 파일만 확인한다.

---

## FAIL

### S1. [Medium] 브랜드 편집 페이지의 중단 배너가 이력 스트림에 의존 — 허브와 판정 출처가 다르다
위 §A 참조. 재현 경로: (1) admin 이 일괄 적용 중 중단을 만든다(포인터 `partial`). (2) ③~④ 구간이거나 이력 읽기가 실패하면 허브는 "끝나지 않은 일괄 적용이 있어요" 를 보이고, 탭하면 도착한 편집 페이지에 배너·버튼·에러가 모두 없다. (3) 반대로 중단 후 폼에서 다시 적용해 완료시키면 허브는 깨끗하지만 편집 페이지는 영구히 "일부 매장에는 아직 적용되지 않았어요 / 이어서 적용" 을 보이고 버튼은 항상 실패한다. 증거: 임시 위젯 테스트 PROBE1/PROBE3.

### S2. [Medium-Low] 중단 포인터/이력 수명주기 — 포인터를 지울 수 없는 상태가 있다
위 §B-2. 재현 경로: 포인터 `partial` 상태에서 admin 이 (a) 브랜드 단건 변경, (b) 스위치 토글, (c) preserve 적용 중 하나를 하면 포인터는 `partial/옛 id` 로 남고 허브 경고가 영구화된다. 재개는 항상 `FAILED_PRECONDITION`(문구는 "다시 적용하세요" 로 안내되지만 같은 값 + 남은 개별 설정 0 이면 noop 이라 지울 수 없다). 옛 `partial` 이력은 새 적용 후에도 영구 `partial`. spec 에 규정이 없다 → architect 결정 필요.

### S3. [Low-Medium] F5(b): 스캔이 트랜잭션 밖 → 빈 이력 생성, noop 이 "0곳 적용" 으로 보임
위 §B. 재현: 1500곳 브랜드에 같은 값 overwrite 를 3동시 호출 → 이력 3건(실제 1 + 빈 2, 응답 모두 `changed:true`). 결과 카드는 `changed` 를 읽지 않아 noop 도 "적용을 마쳤어요 · 적용된 매장 0곳".

### S4. [Medium] Rules: 금액 입력 신뢰원(`stores.brandId`)의 자가 지정 + 자가 `brand` 역할로 이력 열람
위 §E. 재현 경로: (1) 점주 계정이 SDK 로 `{ownerId:self, status:'pending', brandId:<고효율 브랜드>}` 매장을 생성 → admin 승인 시 해당 브랜드 요율을 상속(승인 화면에 브랜드 배지는 보인다). (2) 임의 사용자가 `users/{self}` 를 `{role:'brand', brandId:<아무 브랜드>}` 로 바꾸면 그 브랜드와 가맹점의 Qoin 이력(admin uid·reason)을 읽는다. 둘 다 돈이 직접 새지는 않는다(1은 admin 승인 필요).

### S5. [Low] `data_ownership.md` 드리프트 (1차 F6 부분 해소)
- L119·L219 가 존재하지 않는 함수명(`hasQoinRateOnCreate()`, `touchesQoinRate()`)을 가리킨다(실제 `hasQoinManagedOnCreate()`/`touchesQoinManaged()`, `grep` 으로 Rules 에 구명 0건 확인).
- L118·L121·L159 의 stores/brands 행이 `qoinAccrualRate` 만 말하고 `qoinAccrualEnabled`/`qoinBulk*` 가 빠져 있다. 포인터 3필드의 의미·작성자(`applyBrandQoinRate` 만)·읽는 쪽(허브·목록)을 설명하는 곳이 없다.
- §2.11.5 제목이 "설계 확정 / 미구현" 인데 구현됐다. 같은 절의 `skipped_rate_zero` 는 코드에서 삭제됨.
- L120 "재생성 `pending` → admin 재승인 전까지 주문·적립 불가" 는 서버가 보증하지 않는다: `verifyTossPayment` 는 `stores` 를 읽지 않고(grep 0) 적립 트리거도 `status` 를 보지 않는다. UI 에서만 막힌다.

### S6. [Low] 과도기 자산 마커가 불완전 — 정리 커밋 grep 에서 누락되는 파일 7+개
위 §F. 가드 테스트가 3개만 확인.

---

## PASS (2차)

1. C 파싱 3건(레거시 details / 마이그레이션 raw / 포인터 상태) 형태 일치(§A-C). 
2. F1~F4 종결(§C 표).
3. Q1 핵심 회귀 재현 통과(§D).
4. N4 핵심 + 환불 회수 통과 재현(§D).
5. 포인터 잠금: 겹친 호출 거부 확인, `running` 조회는 트랜잭션 안으로 이동해 닫힘.
6. 재개 재검증(값 변경/포인터 불일치 거부), 거부 시 매장 불변.
7. Rules 보호 필드 20경로 전부 거부(독립 열거).
8. 설계 의문 1(브랜드 레거시 0 포함) 타당, 4(K 줄) 타당, 3(`enabledChangedAt`) 수용 가능(사유 정정).
9. 허브 3상태(로딩/에러/없음)는 이력이 에러여도 포인터로 정상 동작(PROBE2: 배너 표시).
10. 앱 → `verifyTossPayment` → 주문 → 적립 경로가 `buildOrderData` 를 공유하고 손 시드 주문 0건.
11. `flutter analyze` 이슈 0 (직접 확인). 
12. 절대 규칙: presentation·domain Firebase import 신규 0, `Color(0x` 신규 0 (developer 확인 신뢰, `flutter analyze` 클린).
13. 매장별 `clearByBulk` 이력이 원인 추적에 충분(before/beforeState/beforeRaw/bulkHistoryId/uid).
14. 앱 토글/Console 구별(F3).
15. 전역 비상 정지 `enabled` 의 Rules 가 타 admin uid 사칭을 거부.
16. `config/qoin` `accrualRate` 쓰기·삭제, `qoinSettlementIssues` 쓰기 전면 거부.
17. 환불 회수는 스위치와 무관하게 통과 (회수 경로가 스위치를 읽지 않음).

## 보류

- H-A. 실기기에서 `FirebaseFunctionsException.details` 가 `Map` 으로 도착하는지(레거시 가드 문구가 뜨는지). 확인 방법은 §A-C 보류 항목.

## 우선순위 제안

1. S1 (+ design §18-8 에 편집 페이지 항목 추가) — 배포 전 수정 권장이나 필수 아님.
2. S2 — architect 규정 먼저(포인터 수명주기).
3. S4 — Rules 한두 줄(`stores` create 에서 점주는 `brandId` 금지, `isBrandHolder` 에 브랜드 승인/소유 확인) + 하네스 케이스 추가. 사용자 판단 필요(users 규칙 변경이라 영향 범위가 큼).
4. S3, S5, S6.

## 배포 판단

돈이 새거나 고객 적립이 틀어지는 FAIL 은 **없다.** 배포를 막는 FAIL 도 없다. 단 ③~④ 구간에서는 S1 때문에 편집 페이지에 이력 에러조차 표시되지 않으니, 배포 절차의 "③ 직후 이력 화면이 권한 오류" 고지에 "브랜드 편집 페이지의 중단 배너도 보이지 않는다" 를 추가하고 ④ 를 ③ 직후에 올릴 것(spec §20.11 의 기존 권고).

---

# 3차 검증 (커밋 `7f5db1c` — 개정 3: S1·S2·S3·S5·S6 + 정정 4건)

범위: 이번 커밋의 변경분과 그 주변만. 자동 테스트(analyze 0 / flutter 447 / TS 86 / CF 에뮬레이터 97 / Rules 332 / flow 27)와 RM07 핀은 architect 가 직접 재실행해 확인했으므로 **다시 돌리지 않았다.** 대신 테스트가 못 보는 곳을 에뮬레이터 임시 스크립트(저장소 밖 스크래치패드, 종료 후 삭제)와 독립 열거로 봤다. 보안 쪽은 `docs/tasks/brand_authorization_hardening/test_report.md`.

결과 요약(이 task 몫): **FAIL 4 (모두 Low~Medium-Low) / 배포 차단 0.** 보안 task 몫 FAIL 2 는 그쪽 문서.

## 1. developer "설계 문제" 5건 판정

### 판정 1. staleScan 가드 — 재현됨. 단 경쟁 조건에서만. 거짓 안내가 맞다 (F-1, Low)

- **순차로는 재현되지 않는다.** preserve 0.06 완료 직후 overwrite 0.06 → 정상 진행(10곳 초기화, 남은 개별 설정 0).
- **경쟁에서는 재현된다.** 3000개 매장(전부 개별 설정) 브랜드에서 B(preserve 0.06)를 먼저 쏘고 20/50/90/140/200ms 뒤 A(overwrite 0.06)를 쏨. 20ms 는 정상 순서, **50·90·140·200ms 4건 전부** A 가 `{changed:false, staleScan:true}`, 이력 문서 1건, **개별 설정 3000곳 그대로.** 서버 로그: `stale scan guard fired. scanStartedAt < qoinBulkAt`.
- 화면: `_UnchangedCard` 는 `staleScan` 을 소비하지 않는다(코드 주석이 "운영자가 알아야 할 사실이 아니다" 라고 적고 있다). 즉 admin 은 "이미 같은 값이에요 · 바뀐 것이 없어요" 를 본다. **값이 같다는 건 참이나, 의도한 "개별 설정 초기화" 가 안 됐다는 사실은 숨는다.** S3(noop 이 거짓으로 보임)와 같은 모양이 가드 안에 남은 것.
- 심각도 Low: 두 admin 이 같은 브랜드에 수백 ms 안에 서로 다른 모드로 같은 값을 적용해야 한다. 돈 영향 없음(적립률은 이미 V), 재시도하면 정상 진행.
- 원인은 developer 진단 그대로: 포인터가 "overwrite 로 끝났는가" 를 모른다. 수정안: 가드 분기에서만 포인터가 가리키는 이력 문서를 1회 읽어 `bulkMode == 'overwrite' && status == 'completed'` 일 때만 발동(가드 분기는 write 가 없어 read-before-write 제약도 없다). 또는 `staleScan` 을 `_UnchangedCard` 가 별도 문구("방금 다른 곳에서 바뀌었어요. 다시 확인하고 적용하세요")로 소비.

### 판정 2. stale `in_progress` — **S2 와 같은 모양의 재발. 맞다. 더 나쁜 변형이 있다 (F-2, Medium-Low)**

에뮬레이터 재현(포인터 `in_progress` + `qoinBulkAt` 20분 전 + 이력 `in_progress`/`lastProgressAt` 20분 전 = CF 인스턴스가 중간에 죽은 상태):

| 시나리오 | 결과 |
|---|---|
| (a) 새 overwrite(다른 값) | 완료. 포인터는 새 이력으로 교체. **옛 이력은 `in_progress` 로 영구 잔류.** 옛 id 로 재개 → `FAILED_PRECONDITION "브랜드 값이 그 뒤에 변경됐어요"`. 행은 `resolveHistoryRow` 상 `lastProgressAt` 이 5분 초과 + 포인터 불일치 → **plate 만 있고 버튼 없음, 영구.** |
| (b) **브랜드 단건 적립률 변경** | 변경 성공, **포인터는 `in_progress` 그대로**(supersede 는 `partial` 만). 화면의 stale 배너가 계속 뜨고, `이어서 적용` 은 **항상 실패**("값이 그 뒤에 변경됐어요. 다시 적용하세요"). |
| (b') 그 뒤 같은 값을 `덮어쓰고 적용` / `보존하고 적용` | **둘 다 `{changed:false}` noop, 포인터 그대로 `in_progress`.** 개별 설정 0곳일 때 사용자가 할 수 있는 일이 없다. 탈출구는 "다른 값으로 일괄 적용" 뿐(= 돈이 걸린 동작을 청소 수단으로 강요). |
| (c) 브랜드 스위치 변경 | 포인터 `in_progress` 그대로, 옛 이력 `in_progress` 그대로. |

- **배너가 거짓 약속을 한다.** `QoinPartialBanner.disappearNote` = "이어서 적용을 끝내거나 **브랜드 설정을 다시 바꾸면** 이 안내는 저절로 사라져요". `partial` 에는 참이지만 stale `in_progress`(같은 위젯이 `staleTitle` 로 그림)에는 (b)(c) 에서 거짓이다.
- 근본 원인은 spec §21.2 가 "마감 대상 = `partial`" 만 정했고 `isBulkInProgress` 가 5분 뒤 거짓이 되는 순간부터 포인터가 `in_progress` 라는 값 그대로 **사실상 partial 과 같은 의미**가 되는데 `isBulkPartial` 이 그걸 포함하지 않은 것. 판정 쪽(`resolveBulkBanner`)은 stale 을 중단으로 읽고 CF 마감 쪽(`readPartialHistory`/`supersededPointerFields`/`nothing_left`)은 안 읽는다 — **한 사실에 두 판정**(R1 위반).
- 심각도 Medium-Low: 전제가 "CF 인스턴스가 catch 도 못 탄 채 죽음"(타임아웃 540s 초과·인스턴스 종료)이라 드물다. 돈 영향 없음. 그러나 2차에서 내가 S2 로 올린 "지울 수 없는 상태" 의 정의에 정확히 들어맞는다.
- 수정안(작다): CF 쪽에 `isBulkUnfinished(snap) = partial || (in_progress && stale)` 를 두고 `readPartialHistory`·`supersededPointerFields` 적용 조건·`nothing_left` 조건을 전부 그것으로 교체. Dart `resolveBulkBanner` 와 같은 5분 기준을 상수 1곳에서 공유.

### 판정 3. `config` create 에 `enabledChangedAt` 미강제 — 수용 가능, 단 한 줄로 닫을 수 있다 (H-1, 보류)

- 코드 읽기: create 는 `enabled` 가 있으면 `enabledChangedBy == uid()` 만 요구, update 는 `enabledChangedAt == request.time` 까지 요구. 트리거는 `enabledChangedAt` 이 **바뀌었을 때만** 행위자를 쓰므로 create 에 `enabledChangedAt` 이 없으면 이력은 `source:'direct', changedBy:null` 로 남는다(행위자 정보 손실, **사칭·위조는 불가**).
- 1차 F1 의 "한쪽만 막혔다" 형태와 비슷하나 결과가 다르다: F1 은 돈이 틀어졌고 이건 행위자 라벨이 `direct` 로 안전 측 폴백한다. 또 `config/qoin` 은 이미 존재하는 문서(CF 가 적립률을 쓴다)라 admin 이 create 를 경유할 일이 사실상 없다.
- 비용 1줄이므로 같은 창에서 닫기를 권고: create 의 `enabled` 분기에 `&& request.resource.data.get('enabledChangedAt', null) == request.time`.

### 판정 4. `EntityApprovalStatus.fromString` vs 매장 create Rules — **developer 의 전제가 브랜드에는 해당하지 않는다. 갈리지 않는다 (PASS, 정정)**

- 코드: `BrandModel.fromFirestore` 는 `status: (data['status'] as String?) ?? 'pending'` — **브랜드의 `status` 부재는 `pending` 으로 읽는다.** `toEntity()` 는 이미 채워진 문자열을 `fromString` 에 넘기므로 `approved` 폴백이 개입하지 않는다.
- 에뮬레이터: `status` 필드 없는 브랜드를 가리키는 매장 create → Rules 거부(D5 의도대로). 화면은 `pending` → `unapproved` → "승인되지 않은 브랜드라 승인할 수 없어요" → 승인 버튼 비활성. 감사(`auditBrandLinks`)도 `status !== 'approved'` 로 `store_unapproved_brand`. **셋이 일치한다.**
- `fromString` 의 `approved` 폴백이 실제로 효력을 내는 곳은 `StoreModel`·`MenuOverrideModel` (매장·메뉴의 `status` 부재) — 이건 spec §11.3 이 이미 다룬 T1 레거시 호환이고 이번 변경과 무관.
- 주의 1건(보류 H-2): 기준선 §11.2 의 `store_unapproved_brand = 0` 은 시드 브랜드 `phase3_seed_brand_001` 이 `status` 필드를 갖고 있고 그 브랜드를 가리키는 매장이 없거나 approved 라는 전제다. 시드 문서가 `phase1_seed_store_001` 처럼 `status` 부재이면 감사 카드가 `store_unapproved_brand` 를 보고하는데, 이는 오탐이 아니라 정상 분류다(에뮬레이터로 확인).

### 판정 5. 메뉴 승인 큐 `'브랜드'` 폴백 — **R2 가 막으려던 것의 재발이 맞다 (F-3, Low)**

- spec §21.7 R2 는 "한 사실 = 한 행, 모든 화면 전수" 인데 보안 task 의 표면 인벤토리(§1)는 "브랜드 연결 상태" 사실을 **매장 승인 표면 4개**로만 열거했다. 같은 질문("이 항목이 어느 브랜드 것인가, 그 브랜드가 지금 존재하는가")에 답하는 표면이 인벤토리 밖에 있다.
- 독립 열거(lib 전체 grep): `admin_approval_queue_page.dart:388` `brand?.name ?? '브랜드'` (로딩·미존재·조회 실패를 가짜 이름으로 덮는다) / `owner/my_store/my_store_page.dart:335` `?.name ?? '브랜드 매장'` (점주에게 브랜드 매장이라고 말함. 브랜드가 사라졌어도 동일) / `brand_info_page.dart` `_EmptyView` (아래 보안 문서 F-S2).
- **가드 테스트가 면제를 기계로 굳혔다**: `"메뉴 승인 큐의 브랜드 묶음 타일은 다른 표면이다"` 라는 주석과 함께 검사 대상 파일 4개만 나열. R3(기계로 고정)의 의도는 정반대(전수 grep)다.
- 심각도 Low: 메뉴 문서의 `brandId` 는 `isBrandHolder` 가 쓰기를 통제하므로(D2 이후) 가짜 brandId 가 생기기 어렵고, 승인 대상이 메뉴 묶음이지 적립률 상속이 아니다. 매장 쪽처럼 "admin 이 속는" 위험이 낮다. 그러나 **규칙을 인벤토리로 둔 이유가 사람 판단("다른 표면이니 건드리지 않는다")을 없애려는 것**이었으므로 재발로 판정한다.
- 수정안: 폴백을 `resolveStoreBrandLink` 류의 분류(확인 중 / 미존재 / 조회 실패)로 대체하거나 최소한 표면 인벤토리에 행을 추가하고 가드가 `lib/presentation` 전체에서 `?? '브랜드` 패턴을 찾게 한다.

## 2. 작업표 차이 7건 중 검증이 필요한 4건

| # | 항목 | 판정 |
|---|---|---|
| 1 | `BrandIdMissingView` 신규 작성, 조회 전·실패·연결 실패에서 폼 금지 | **PASS (코드 + 위젯 테스트 대조).** 폼은 `BrandGateNeedsRegistration` 분기 1곳. 테스트가 조회 중/실패/연결 실패(retryable·alreadyLinked·notSubmitter)에서 폼·`새로 등록` 버튼 부재를 단언. **단, 폼의 두 번째 진입점이 남아 있다 → 보안 task F-S2.** |
| 2 | 등록 폼 저장 직후 `ref.invalidate(brandLinkGateProvider)` | **PASS (게이트 경로 한정).** 게이트 안의 폼은 invalidate → 폼 해체 → 방금 만든 브랜드 조회 → 재 claim(멱등). 에뮬레이터로 claim 5동시 호출: `changed` 1건 + `roleHistory` 문서 1건. **`BrandInfoPage._EmptyView` 에서 push 한 폼은 이 경로를 타지 않는다**(F-S2). |
| 3 | `orphan_brand` 정의 불일치 | **구현이 맞고 spec §4.1 문장이 틀렸다.** §4.1 은 "`submittedBy == null` 또는 `approved`" 인 고아만 센다 — D1-2 가 우려한 **"2건 이상 중 연결 안 된 pending 브랜드"** 를 정확히 제외한다. §4.2 조치표는 "`pending` 이고 아무도 가리키지 않으면 삭제" 로 그 pending 을 대상으로 한다. 구현(전수 스캔 후 미참조 전부 + status 동봉)이 두 문장의 합집합이라 과보고 쪽이고 읽기 전용이라 안전. **architect 가 §4.1 문구를 정정할 것.** 에뮬레이터 확인: `phase3_seed_brand_001`(status·submittedBy 부재)·pending(`submittedBy` 있음)·approved(`submittedBy` 부재) 3종이 모두 `orphan_brand`. |
| 4 | 마커 8개, `qoin_hub_states_test.dart` 가 목록 밖 | **목록 밖인 게 맞지 않다 → F-4 (Low, 정리 시점).** 아래. |

(나머지 3건 — `describeRaw` 원인이 Dart, `isUnfinished(` 이력 행 → `resolveHistoryRow`, `.freezed.dart` 제외 — 은 코드 읽기에서 합리적이며 가드 테스트가 지킨다. 재검증하지 않았다.)

### F-4. S6 가드가 "토큰 보유 파일" 만 소유한다 — 정리 시 컴파일이 깨지는 테스트 파일이 목록 밖 (Low)

- 토큰 grep 은 `qoin_hub_states_test.dart` 에 걸리지 않는다(토큰 없음). 그러나 이 파일은 `admin_qoin_migration_card.dart`·`migrate_qoin_zero_rates_use_case.dart`·`qoin_zero_migration_repository.dart`·`qoin_zero_migration_result.dart` 를 import 하고 "임시 마이그레이션 카드" 그룹을 가진다 — 정리 커밋이 지우는 대상들이다. 마커 파일을 지우면 `flutter analyze` 가 이 테스트에서 깨진다. **spec §20.4.5 가 7개 목록에 이 파일을 넣은 이유가 바로 이것이었다**(2차 S6 원문).
- 가드는 `allowed ⊂ marker` 방향만 단언하고 `marker ⊂ allowed` 는 단언하지 않는다. 실측: 마커를 가진 비생성 파일 중 허용 목록에 없는 것이 8개(대부분 마커 grep 으로 잡히는 순수 과도기 파일이라 문제 없음).
- 수정안: 가드에 "허용 목록·마커 파일을 import 하는 `test/` 파일은 마커나 허용 목록 중 하나에 있어야 한다" 를 추가하거나, `qoin_hub_states_test.dart` 에 마커 한 줄을 달고 허용 목록에 넣는다(후자가 즉시 가능한 최소 조치).

## 3. S1·S2·S3 가 닫혔는가

### S1 두 방향 — PASS (위젯 테스트 코드를 읽고 에뮬레이터 CF 동작과 대조)
- ① `PROBE1` 은 **실제 `AdminQoinBrandRateEditPage`** 를 올리고 이력 스트림 에러 + 문서 읽기 에러를 동시에 주입. 배너·`이어서 적용` 있음, 수치 문구만 생략, 에러 문구 없음. 로딩 중에도 즉시 배너. 판정은 포인터 단일 함수.
- ② `PROBE3`: 포인터 `completed`/`superseded` + 옛 이력 `partial` → 배너·버튼 없음(두 상태 모두). 이력 행은 `resolveHistoryRow` 로 종결 줄.
- 표면 5개(허브·목록 태그·편집·정보 plate·이력 행)가 전부 `resolveBulkBanner` 를 호출함을 내가 grep 으로 독립 확인 — 원시 `qoinBulkStatus` 직접 비교는 `qoin_bulk_banner.dart` 한 곳. **단 이 "한 곳" 이 stale in_progress 에서 CF 쪽 판정과 어긋난다(F-2).**

### S2 4경로 — PARTIAL (F-2)
K1~K5(overwrite / preserve / 단건 / 스위치 / nothing_left)는 테스트 코드를 읽고 전부 같은 트랜잭션에서 이력 문서 + 포인터를 마감함을 확인. 이력 문서는 삭제되지 않음. `partial` 대상 "지울 방법이 없는 상태" 는 없다. **`in_progress`(stale) 대상으로는 있다 — 판정 2.**

### S3 — PASS
- 빈 이력: 내 경쟁 재현에서도 가드 발동 시 **이력 문서 수 1**(B 의 것만) — `clearedCount>0` 이 아니라 `brands/{id}/qoinRateHistory` 문서 수로 셌다. K7·K8 도 문서 수 단언.
- 가드는 순서(B 먼저)가 올바르면 동작하지만 판정 1 의 거짓 안내 부작용이 있다.

### `changed` 소비 — PASS (독립 열거)
쓰기 응답 소비자를 `lib` 전체에서 4개 provider(`setQoinAccrualRate/Enabled`, `applyBrandQoinRate`, `runBulkResume`)로 grep: 전역 적립률 페이지 · 매장 편집 · 브랜드 편집(`_apply`, `_resume`) · 이력 화면(`_resume`) · 스위치 카드 = **5개 화면 + 재개 헬퍼 1개**, 가드가 요구한 5와 일치하고 전부 `!r.changed` 분기가 성공 문구보다 앞선다. 누락된 화면 없음.
- 가드 테스트의 약점(Low, 보류 H-3): 파일 수준 `RegExp(r'\.changed')` 라 한 파일에 호출이 2개이면 하나만 읽어도 통과한다. 지금은 사실에 부합하지만 호출 지점별 단언이 아니다. 새 소비자가 provider 가 아닌 repository 를 직접 부르면 `entryPoints` grep 에 안 잡힌다.

## 4. 판정 요약표

| ID | 내용 | 심각도 | 배포 차단 |
|---|---|---|---|
| F-1 | staleScan 가드가 preserve 완료 포인터에도 발동, 화면은 "이미 같은 값" (경쟁에서 재현) | Low | 아니오 |
| F-2 | stale `in_progress` 가 마감되지 않음 + 단건/스위치로 못 지움 + 배너가 거짓 약속 (S2 재발) | Medium-Low | 아니오 (같은 창에서 닫기 권고) |
| F-3 | 메뉴 승인 큐 `'브랜드'` 폴백 + 가드가 면제를 굳힘 (R2 재발) | Low | 아니오 |
| F-4 | S6 가드 한 방향만 — `qoin_hub_states_test.dart` 가 목록 밖 | Low | 아니오 (정리 커밋 전) |
| H-1 | `config` create `enabledChangedAt` | 보류 | — |
| H-2 | 기준선 `store_unapproved_brand = 0` 전제 (시드 브랜드 `status`) | 보류 | — |
| H-3 | `changed` 가드가 파일 수준 | 보류 | — |

## 5. 우선순위

1. F-2 (CF `isBulkUnfinished` 로 마감 조건 통일 + 에뮬레이터 케이스 K10: stale in_progress 4경로).
2. 보안 task F-S1(`submittedBy` 양도) — Rules 한 줄.
3. 보안 task F-S2(dangling 계정의 등록 버튼).
4. F-3, F-1, F-4.

## 6. 내가 이번에 보지 않은 것
- 구버전 앱 + 신 CF 구간 거동(개정 3 ② 후 ③ 전). implementation C8-4.
- 실기기 `details` Map 수신(H-A, 1차 보류 그대로).
- 운영 인덱스·실배포 화면 (배포 금지).
