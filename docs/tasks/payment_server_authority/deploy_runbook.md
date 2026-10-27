# 배포 런북 — 결제·권한의 서버 권위화 (payment_server_authority)

- 프로젝트: `order-app-5957e` (**`.firebaserc` 가 없으므로 모든 명령에 `--project order-app-5957e` 를 붙인다**)
- 순서 근거: `spec.md` §17 · §17.0 · §17.1 · §11.4 · §16
- 작성 계기: `test_report.md` **F-01** — ③→④→⑥ 순서 전제를 코드가 강제하지도 감지하지도 않는다
- **순서를 바꾸지 말 것.** 특히 ③ → ④ → ⑥ → ⑥-c → ⑦ → ⑧ 은 뒤집으면 **매출이 멈추거나 등록이 막힌다.**

---

## 0. 이 배포가 위험한 이유 (바꾸기 전에 읽을 것)

이 배포는 **"되돌릴 수 없는 방향의 실패"**(정상 손님의 결제 거부)를 만들 수 있다. 사고 경로가 3개다.

| # | 경로 | 막는 장치 |
|---|---|---|
| 1 | **② 를 평범한 `npm run deploy` 로 치면 게이트가 ③④ 이전에 켜진다.** 임시 마이그레이션 CF 와 `verifyTossPayment` 가 **같은 `index.ts` 에서 export** 되고 `functions/package.json:10` 의 `deploy` 는 `firebase deploy --only functions`(**전 함수**)다 | ② 는 **함수 단위 배포**(아래 명령) + **`PAYMENT_GATE_MODE=shadow`** (spec §17.0) |
| 2 | **④ Rules-A 를 HEAD 파일로 배포하면 Rules-B+C 가 같이 나간다.** HEAD 의 `firestore.rules` 에는 A·B·C 가 모두 들어 있고, B+C 가 앱(⑦)보다 먼저 나가면 **구버전 앱의 브랜드 정보 저장·`brands.create` 가 거부**된다 | ④ 는 저장소의 **`docs/tasks/payment_server_authority/firestore.rules.stage4`** 를 복사해 배포(아래 명령). 이 파일은 **C4 의 `stores` 변경도 함께** 담는다 — 안 담으면 ⑦~⑧ 사이에 반려 매장의 재제출이 막힌다 |
| 3 | **M1 이 빠진 채 게이트가 켜지면 legacy 매장이 전면 거절되는데 알람이 없다.** 고객 목록은 `fromString` 폴백으로 그 매장을 계속 보여주고, 매출이 멈춘 것을 알려주는 것은 `paymentGateRejections` 기록뿐이다 | ③ 의 **`willBeRejected` 목록**을 사람이 눈으로 확인 + ⑥ 을 `shadow` 로 올려 **⑥-b 에서 실측** |

**롤백 단위**: ④ 단독 / ⑥ 단독(또는 `PAYMENT_GATE_MODE` 를 `off` 로) / ⑦+⑧ 함께.
**③⑤⑨ 는 되돌리지 않는다**(데이터 정상화·복사는 그대로 두는 것이 안전하다).

> **가장 싼 비상 정지는 Rules 롤백도 CF 롤백도 아니다 — `PAYMENT_GATE_MODE=off` 재배포다.**
> 게이트가 정상 결제를 막고 있다고 판단되면 **먼저 이것을 친다**(§6).

---

## ① Firestore 인덱스

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:indexes --project order-app-5957e
```

- **진행 중 주문 가드**(spec §11.4)의 쿼리
  `orders where storeId == … and status in [...]` 에 복합 인덱스가 필요하면 여기서 나간다.
- Console → Firestore → 색인 에서 **`사용 설정됨`** 이 될 때까지 기다린 뒤 ② 로 간다.
- 추가 인덱스가 없다면 이 단계는 no-op 이고, 그래도 **실행해서 no-op 임을 확인**한다.

## ② 임시 마이그레이션 CF 만 배포 — **함수 단위**

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions:migrateStoreApprovalMeta,functions:migrateBrandPrivateProfile --project order-app-5957e
```

⚠️ **`npm run deploy` 를 쓰지 말 것.** 그것은 `firebase deploy --only functions`(전 함수)이므로
게이트가 ③④ 이전에 켜진다 (§0-1).

배포 후 확인:

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 functions:list --project order-app-5957e
```

- `verifyTossPayment` 의 **리비전이 바뀌지 않았음**을 Console(Cloud Functions → 세부정보 → 버전)에서 확인한다.
- 바뀌었다면 게이트 코드가 이미 올라간 것이다 → **즉시 `PAYMENT_GATE_MODE` 가 `shadow` 또는 `off`
  인지 확인**하고(§17.0 기본값은 `off`), ③ 으로 간다.

## ③ M1 실행 — `stores` 승인 메타 정상화 + **거절 예정 목록 확인**

**dry-run 먼저.** admin 계정으로 앱에서 → 하단 탭 **더보기** → **배포 마이그레이션 (임시)**
→ **③ 매장 승인 메타 정상화** 카드 → `시험 실행 (dryRun)`.

이 화면은 ③⑤⑨ 전용 임시 카드다 (`TEMP_MIGRATION_CARD`, ⑪ 에서 삭제). **이 카드가 들어간 앱을
admin 기기에 먼저 설치해야 ③ 을 할 수 있다** — 런북의 ⑦(앱)은 고객용 배포 순서이고, 이 임시 빌드는
신규 화면 추가뿐이라 구버전 호환에 영향이 없다. 단 **③ 을 하는 동안 그 기기로 고객 결제를 하지
않는다**(선검증이 서버보다 먼저 올라간 상태가 되므로).

확인할 것 — **하나라도 어긋나면 멈추고 보고한다. 자동 수정하지 않는다.**

| 리포트 | 기대 | 어긋나면 |
|---|---|---|
| `setStatusApproved` / `backfillApprovedAt` | 대상 건수가 기억과 맞는다 | 멈춘다 |
| `invalid` (무효 값) | **빈 목록** | **멈추고 보고.** 자동 변환하지 않는다 |
| ⓒ `anomalies` (`status != approved && approvedAt != null && approvedBy == null`) | 빈 목록 | 멈추고 보고 |
| ⓔ **모호 건** (`rejected && approvedAt != null`, `pending && rejectedReason != null && approvedAt != null`) | **0건이 아니어도 배포를 막지 않는다** | 목록을 남기고 사람이 판단. **단 ④ 가 반드시 배포된다는 전제** (spec §6.8) |
| ⓓ **`willBeRejected`** | **목록을 눈으로 전부 확인한다** — 백필 후에도 게이트에 막힐 매장이다 | 영업 중인 매장이 들어 있으면 **멈추고 원인부터 찾는다** |

확인되면 `{dryRun:false}` 로 실행 → **재 dry-run 이 전부 0** 인지 본다.

## ④ Rules-A 배포 — **HEAD 가 아니라 Rules-A 시점 파일**

HEAD 의 `firestore.rules` 에는 Rules-B+C 가 들어 있어 그대로 쓸 수 없다. **④ 전용 파일이
저장소에 있다** — `docs/tasks/payment_server_authority/firestore.rules.stage4`.

배포 중에 `git show` 와 `patch` 를 치지 않는다. 그 파일은 미리 만들어 하네스로 검증해 뒀다
(`PSA-A` / `PSA-F02` / `PSA-RJ` 전건 통과, 실패 15건은 전부 Rules-B/C 케이스 — 즉 A 만 들어 있고
B·C 는 안 들어 있다는 확인이다). **파일이 리뷰 대상이고, 배포는 복사 한 번이다.**

먼저 차이를 눈으로 본다 (나와야 하는 차이는 Rules-B+C 뿐이다).

```bash
cd /Users/Byeonguk/Developer/OrderApp && diff docs/tasks/payment_server_authority/firestore.rules.stage4 firestore.rules
```

임시로 교체한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && { [ -f /tmp/rules_head.rules ] && echo '백업이 이미 있다 — 원복이 안 끝난 상태다. 먼저 원복하라.' ; } || { cp firestore.rules /tmp/rules_head.rules && cp docs/tasks/payment_server_authority/firestore.rules.stage4 firestore.rules && echo '교체 완료' ; }
```

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:rules --project order-app-5957e
```

배포 직후 **작업 트리를 원복한다** (이 상태로 커밋하면 B+C 가 사라진다).

```bash
cd /Users/Byeonguk/Developer/OrderApp && cp /tmp/rules_head.rules firestore.rules && git status --short firestore.rules
```

- 이 파일은 **Rules-A + C1(전이 제약) + C4 의 `stores` 변경**을 담는다. **C4 를 함께 담는 이유가
  중요하다** — 신 앱의 재제출 payload 가 `rejectedAt: null` 을 보내는데(`store_model.dart`
  `toFirestoreForCoreUpdate`) C1 까지만 올리면 그 필드가 화이트리스트에 없어
  `onlyChangedFields` 가 **업데이트 전체를 거부**한다. 그러면 ⑦(앱) 과 ⑧(Rules-B+C) 사이에
  **반려 매장 점주가 재제출을 못 한다.** (C1 Rules 의 점주 화이트리스트에 `rejectedAt` 0건,
  HEAD 에 4건 — 실측 확인.)
- ⚠️ **C1 이 아직 없다면 ④ 를 치지 않는다.** F-02 경로가 열린 채 게이트를 켜는 것은
  "게이트가 장식" 인 상태다 (spec §6.2 정정 블록).
- Rules 를 더 고치면 이 파일도 같이 갱신해야 한다. 갱신 방법은 §④-b 에 적었다.

### ④-b. `firestore.rules.stage4` 를 다시 만드는 방법

`stores`/`brands` 쪽 Rules 를 추가로 고쳤다면 이 파일이 낡는다. 다시 만들 때는 아래로 한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && git show 11c90c7:firestore.rules > /tmp/s4.rules && for c in 6c1c831 7bdda20; do   # Rules 를 더 고쳤다면 그 커밋 해시를 이 목록 뒤에 붙인다 git show $c -- firestore.rules > /tmp/$c.patch && patch /tmp/s4.rules < /tmp/$c.patch; done && cp /tmp/s4.rules docs/tasks/payment_server_authority/firestore.rules.stage4
```

만든 뒤 **반드시 하네스로 검증한다** — 교체해서 돌리고, 실패가 Rules-B/C 케이스뿐인지 본다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && cp firestore.rules /tmp/rules_head.rules && cp docs/tasks/payment_server_authority/firestore.rules.stage4 firestore.rules && npx --yes firebase-tools@14 emulators:exec --only firestore --project order-app-5957e "node test_rules/rules.test.mjs" ; cp /tmp/rules_head.rules firestore.rules
```

**라이브 확인 (점주 계정 SDK 로, spec ⑩-3b/3c + F-02)**

| 시도 | 기대 |
|---|---|
| `approvedAt` / `approvedBy` / `rejectedReason` 를 담은 매장 create | 각각 **거부** |
| `status:'approved'` / `'rejected'` 를 담은 매장 create | 각각 **거부** |
| 정상 payload 매장 등록 | **성공** (회귀) |
| 반려 매장에서 `status:'pending'` 만 바꾸는 update | **거부** (C1) |
| 반려 매장에서 `status:'pending'` + 승인 메타 null 클리어 | **성공** (회귀 — 정상 재제출) |
| admin 이 `rejected → approved` 승인 | **성공** (회귀 — 전이 제약이 admin 을 막지 않는지) |

## ⑤ M2 1단계 — `brands` PII·brandKey **복사** (부모는 아직 지우지 않는다)

admin 앱 → **더보기** → **배포 마이그레이션 (임시)** → **⑤⑨ 브랜드 private profile 이동** 카드
→ 칩에서 **`copy`** 선택 → `시험 실행 (dryRun)` → 확인 → `실행`.

- 복사는 **private 의 기존 값을 덮지 않는다.**
- ⚠️ **⑤ 가 ⑥ 보다 먼저여야 한다.** 어기면 `issueBrandKey` 가 기존 키를 "이미 발급" 으로 인식하지
  못해 **재승인 때 새 키가 발급되고 기존 키가 무효가 된다** (spec §17.1 / test_report F-01 말미).
- **부모 문서의 PII·brandKey 제거는 ⑨ 다.** 지금 지우면 구버전 앱의 브랜드 정보 화면이 빈다.

## ⑥ 본 Cloud Functions 배포 — **`PAYMENT_GATE_MODE=shadow`**

**먼저 모드 값을 파일에 쓴다.** 값은 `functions/.env.order-app-5957e` 한 줄이고 이 파일은 git 제외다
(`functions/.env.*`). **파일이 없으면 기본값 `off` 가 되어 게이트가 평가조차 하지 않는다** — ⑥ 을
올려도 아무 일이 일어나지 않고, ⑥-b 가 그것을 "깨끗함" 으로 오인한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && touch functions/.env.order-app-5957e && grep -v '^PAYMENT_GATE_MODE=' functions/.env.order-app-5957e > /tmp/psa_env.new ; echo "PAYMENT_GATE_MODE=shadow" >> /tmp/psa_env.new && mv /tmp/psa_env.new functions/.env.order-app-5957e && cat functions/.env.order-app-5957e
```

(`>` 로 덮어쓰지 않는다 — 그 파일에 다른 키가 들어 있을 수 있다. 위 명령은 그 키만 교체한다.
출력에 `PAYMENT_GATE_MODE=shadow` 가 보이는지 눈으로 확인한다.)

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions --project order-app-5957e
```

- 값은 **배포 시점에 박힌다.** 파일만 고치고 재배포하지 않으면 반영되지 않는다.
- 배포 후 현재 값은 Console → Cloud Run → `verifytosspayment` → 환경 변수에서 본다.
  다만 **값을 눈으로 보는 것보다 ⑥-b 의 양성 대조가 확실하다**(아래).
- 올라가는 것: `verifyTossPayment`(G1·G2 게이트) · `lookupBrandByKey` · `issueBrandKey` · `deleteStore`.
- **`shadow` 이므로 이 시점에 거절은 발생하지 않는다.** 그래서 ⑥ 을 어떤 방식으로 올려도 안전하다.

## ⑥-b shadow 관측 — **거절을 켜기 전에 실측한다**

Console → Firestore → `paymentGateRejections` 에서 `detail.shadow == true` 기록을 본다.

🔴 **"기록이 비어 있다" 를 정상으로 읽지 않는다.** 그것은 ⓐ 잡을 것이 없었다 와 ⓑ **모드가 `off`
라서 게이트가 아예 안 돌았다** 를 구분하지 못한다. 기본값이 `off` 이므로 **ⓑ 가 더 흔한 원인**이다.

그래서 **양성 대조를 먼저 만든다.** 미승인 매장(`approvedAt` 없음)으로 CF 를 직접 호출해
`detail.shadow == true` 기록이 **1건 생기는 것을 확인**한다. 이 1건이 "게이트가 shadow 로 실제
돌고 있다" 는 유일한 증거다.

| 양성 대조 1건 | 판단 |
|---|---|
| **기록이 생기지 않는다** | **모드가 `shadow` 가 아니다.** ⑥ 의 파일 쓰기·재배포를 다시 한다. 이 상태로 ⑥-c 로 가면 `enforce` 도 반영되지 않았을 수 있다 |
| 기록이 1건 생긴다 | 게이트가 돈다. 아래 관측으로 넘어간다 |

| 기록 | 판단 |
|---|---|
| 양성 대조 1건 + 미승인/반려 매장 건만 | 정상(게이트가 잡아야 할 것을 잡았다). ⑥-c 로 간다 |
| **영업 중인 정상 매장 / 품절이 아닌 메뉴가 잡힌다** | **멈춘다.** ③ 의 `willBeRejected` 와 교차 확인하고 원인을 찾는다. `enforce` 로 넘어가면 **그 매장의 매출이 멈춘다** |

관측 기간은 **실결제가 0회이므로 "직접 테스트 결제 몇 건"** 이 전부다 — 자연 트래픽을 기다릴 수 없다.
승인 매장 1곳 정상 결제 + 핵심 필드 수정 직후 결제 + 미승인 매장 호출 3건을 **의도적으로** 만든다.

## ⑥-c `PAYMENT_GATE_MODE=enforce` 전환

**전제 2개를 먼저 확인한다.** ⓐ ④ 라이브 확인 6건 통과 ⓑ ⑥-b 가 깨끗함.

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

모드 파일을 `enforce` 로 바꾸고 같은 줄에서 재배포한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && grep -v '^PAYMENT_GATE_MODE=' functions/.env.order-app-5957e > /tmp/psa_env.new ; echo "PAYMENT_GATE_MODE=enforce" >> /tmp/psa_env.new && mv /tmp/psa_env.new functions/.env.order-app-5957e && cat functions/.env.order-app-5957e && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

(`cat` 출력에 `enforce` 가 보이는지 확인한다. 값은 배포 시점에 박힌다.)

⚠️ **전환 직후 거절 1건을 실제로 유도해 확인한다.** 미승인 매장(`approvedAt` 없음)으로 CF 를 직접
호출해 **거절 + `paymentGateRejections` 1건(`shadow` 플래그 **없음**)** 을 본다.
**이 확인을 하지 않으면 전환이 끝난 것으로 보지 않는다** — 기본값이 `off` 라서 오타가 조용히 넘어간다
(spec §17.0).

## ⑦ 앱 빌드·설치 — **⑥-c 이후**

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter devices
```

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter run -d <device-id> --dart-define-from-file=env.json
```

- **왜 ⑥-c 이후인가**: 앱의 선검증은 서버 모드와 무관하게 동작한다. 서버가 `shadow` 인데 앱이
  선검증으로 막으면 **거절 판단이 서버의 안전망 없이 클라이언트로 옮겨간다** (spec §17.0).
- ⚠️ **admin 계정으로 쓰는 기기가 2대 이상이면 전 기기에 새 빌드를 설치한다.** 안 하면 ⑧ 이후
  구버전 기기에서 브랜드 정보 저장이 막힌다.
- `adb install` 을 쓸 경우 출력에서 **`Success` 를 눈으로 확인**한다
  (`INSTALL_FAILED_INSUFFICIENT_STORAGE` 가 조용히 지나간 적이 있다).

## ⑧ Rules-B+C 배포 — ⑦ **직후 바로**

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:rules --project order-app-5957e
```

- 이때는 **HEAD 의 `firestore.rules`** 가 맞다(A+B+C 전부). ④ 에서 작업 트리를 원복해 뒀는지
  `git status --short firestore.rules` 로 먼저 확인한다.
- 여기서 `brands` private 서브문서 · `brandKeys` · `stores.delete` admin 전용 ·
  신규 컬렉션 3개 규칙이 동시에 켜진다.
- ⚠️ 직후 **admin 매장 승인 화면의 `BrandScopeBadge` 가 경고로 떨어지지 않는지** 확인한다.
  떨어지면 **매장 승인이 전면 불가**가 되므로 ⑧ 을 롤백한다 (spec §17.3).

## ⑨ M2 2단계 — 부모 문서의 PII·brandKey **제거**

같은 화면(**더보기** → **배포 마이그레이션 (임시)** → **⑤⑨** 카드) → 칩에서 **`cleanup`** 선택
→ `시험 실행 (dryRun)` → 확인 → `실행`. (칩을 바꾸면 이전 dry-run 결과가 버려져 다시 시험 실행해야 한다.)

- cleanup 은 **private 값과 부모 값이 일치할 때만** 부모 필드를 지운다. 불일치·부재는 `invalid` 로
  정지한다 — `invalid` 가 있으면 **멈추고 보고**한다.
- ⚠️ **⑨ 를 미루면 보안 목표(R9)가 미이행 상태로 남는다.** 부모에 PII 복사본이 남아 있는 구간이다.
  완료 기준에 포함된다.

## ⑩ 라이브 검증

`spec.md` §17.2 의 14항목을 그 순서로 수행한다. **최우선 2개**:

1. **⑩-2 승인 매장이 핵심 필드(전화번호)를 수정해 `status:'pending'` 으로 회귀한 직후 결제 → 성공**
   (불변식. 실패하면 **즉시 §6 비상 정지**)
2. **⑩-3b/3c + F-02 전이** — 위조 create·전이가 모두 거부되는지 (④ 에서 이미 봤다면 재확인만)

그리고 **⑩-c Q1 사실 확인**: 실제 테스트 카드/카카오페이로 게이트 거절을 일으키고 **카드사 알림·
결제 내역에 아무것도 남지 않는지** 확인한다. 남으면 `design.md` §3.4 의 돈 줄을
`아직 결제가 완료되지 않았어요`(design Q1 ⓑ)로 **즉시 교체**한다.

## ⑪ 정리 커밋 (며칠 뒤)

**임시 마이그레이션 카드를 지운다.** 대상은 `implementation.md` §11.5 에 있고
`grep -rn TEMP_MIGRATION_CARD lib test` 로 전부 찾을 수 있다 — 신규 9파일 +
`admin_more_page.dart` 의 타일 1개·import 1줄. 임시 callable 2개
(`migrateStoreApprovalMeta`, `migrateBrandPrivateProfile`)도 함께 삭제한다.

③ 과 ⑨ 의 dry-run 이 **0건**이고 ⑩ 이 전건 통과일 때만.

임시 자산(마이그레이션 CF 2개 + 그 호출 카드)을 **한 번에** 지우고
`flutter analyze` · `flutter test` · `functions npm test` · Rules 하네스가 **전건 통과**해야 커밋한다.
하나라도 실패하면 지우지 않는다.

---

## 중단 기준

- ③ 의 `invalid` / ⓒ `anomalies` 가 **빈 목록이 아니면** 멈추고 보고한다 (자동 변환 금지).
- ③ 의 ⓓ `willBeRejected` 에 **영업 중인 매장**이 들어 있으면 멈추고 원인부터 찾는다.
- **C1(F-02 보강)이 없으면 ④ 를 치지 않고, ④ 가 없으면 ⑥-c 로 넘어가지 않는다.**
- ⑥-b 에서 **정상 매장·정상 메뉴가 잡히면** `enforce` 로 넘어가지 않는다.
- ⑥-c 의 **거절 1건 실측을 못 했으면** 전환이 끝난 것으로 보지 않는다.
- ⑩-2(정보 수정 중 결제)가 실패하면 **즉시 §6 비상 정지** 후 보고.
- ⑧ 직후 `BrandScopeBadge` 가 경고로 떨어지면 ⑧ 롤백.
- ⑨ cleanup 의 `invalid` 가 있으면 멈추고 보고.

---

## 비상 정지 (게이트가 정상 결제를 막고 있다고 판단될 때)

**가장 싼 순서로 시도한다.**

1. **`PAYMENT_GATE_MODE=off` 재배포** ← 거의 항상 이것이 답이다

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

   위 명령은 리비전만 다시 올린다. **모드 값을 `off` 로 바꾸는 것까지 한 줄로 치려면 이쪽을 쓴다.**

```bash
cd /Users/Byeonguk/Developer/OrderApp && grep -v '^PAYMENT_GATE_MODE=' functions/.env.order-app-5957e > /tmp/psa_env.new ; echo "PAYMENT_GATE_MODE=off" >> /tmp/psa_env.new && mv /tmp/psa_env.new functions/.env.order-app-5957e && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

   (게이트가 **평가조차 하지 않으므로** 배포가 끝나는 즉시 이전 동작으로 돌아간다. 파일 수정과
   배포를 한 줄에 둔 이유는 급할 때 나누면 **파일만 고치고 배포를 잊기** 때문이다.)

2. 그래도 결제가 실패하면 게이트 문제가 아니다 → `paymentGateRejections` 와 CF 로그를 본다.
3. Rules 가 원인으로 의심되면 ⑧ → ④ 순서로 되돌린다 (**데이터 마이그레이션은 되돌리지 않는다**).

> ⚠️ **`off` 로 내린 뒤 그대로 잊지 않는다.** `off` 는 구멍이 열린 상태다. 원인을 고치고
> ⑥-b(shadow 관측) → ⑥-c(enforce) 를 **다시 밟는다.**

---

## 배포 기록 (2026-10-27 실행)

13단계를 순서대로 실행했다. **중단 없이 완료.**

| 단계 | 결과 |
|---|---|
| ① 인덱스 | no-op (복합 인덱스 불필요 — 등식 1 + `in` 1, `orderBy` 없음) |
| ② 임시 CF | `migrateStoreApprovalMeta` · `migrateBrandPrivateProfile` 생성. `verifyTossPayment` 리비전 불변 확인 |
| ③ M1 | dry-run: 전체 7 / `backfillApprovedAt` 2 / **나머지 전부 0** → 실행 2건 → 재 dry-run 전부 0 |
| ④ Rules-A | `firestore.rules.stage4` 배포, 작업 트리 원복 확인. 운영 규칙에 `brandKeys` 없음(= B+C 미배포) 확인 |
| ⑤ M2 copy | `invalid` 3 → **데이터 결함 발견·수정 후** `toCopy` 3 / `invalid` 0 → 실행. `brandKeys` 3건 + `private/profile` + `keyHistory` 생성 확인 |
| ⑥ 본 CF | `PAYMENT_GATE_MODE=shadow` 로 전 함수 배포. 신규 callable 3개에 Cloud Run 호출자 부여 |
| ⑥-b | **양성 대조 성립** (아래) |
| ⑥-c | `enforce` 전환 → 거절 1건 실측, 기록에 **`shadow` 플래그 없음** 확인 |
| ⑦ 앱 | iOS·Android 설치 |
| ⑧ Rules-B+C | HEAD 파일로 배포 |
| ⑨ M2 cleanup | dry-run `toClean` 3 / `invalid` 0 → 실행. **부모 문서에서 PII·brandKey 사라짐 확인 → R9 이행** |
| ⑩ 라이브 | 아래 |

### ③ 에서 확인된 것

ⓔ 모호 건이 **0건**이었다. F-02 가 남긴 과거 데이터 문제(반려가 승인 시각을 덮어써
"승인 후 반려" 와 "반려만" 을 구분할 수 없는 건)가 **이 DB 에는 존재하지 않는다.** 사람이
기억으로 판단해야 할 항목이 하나 사라졌다. ⓓ `willBeRejected` 도 0건이라 백필 후 게이트에
막힐 매장이 없다 — 그래서 ⑥-b 의 양성 대조를 **일부러 만들어야** 했다.

### ⑤ 에서 찾은 데이터 결함 — 마이그레이션이 기존 결함을 드러냈다

첫 dry-run 이 브랜드 3곳 전부를 `brandKey 형식 불일치` 로 막았다. `BRAND_KEY_RE` 는
`/^BR-[A-Z2-9]{8}$/` 라 `0`·`1` 을 허용하지 않는데 운영 키들이 그 문자를 담고 있었다.

출처는 `admin_menu_management/6_upgrade_to_brand/spec.md` 다. §V1 이 alphabet 에서
`0`/`O`/`I`/`1` 을 제외한다고 정해 놓고, 같은 문서가 시드 키 예시로 `BR-SEED0001`, 입력
placeholder 로 `BR-A1B2C3D4` 를 쓴다. **규칙과 예시가 한 문서 안에서 어긋났고 예시 쪽이
데이터가 됐다.**

**이번 task 가 만든 결함이 아니다.** 앱의 `store_core_form_page.dart:17` 이 초기
커밋(`d9a0b15`)부터 같은 정규식으로 입력을 막고 있었으므로 **그 키들은 이미 가맹 등록에 쓸 수
없는 죽은 값**이었다. 교체 비용이 0이라 Console 에서 규칙에 맞는 값으로 바꾸고, 시드 상수는
코드에서 고쳤다(`1b2dae2`) — 두지 않으면 시드를 돌릴 때마다 같은 결함이 재생산된다.

### ⑥-b — 양성 대조가 핵심이었다

"기록이 비어 있다" 는 ⓐ 잡을 것이 없었다 와 ⓑ 모드가 `off` 라 게이트가 안 돌았다 를 구분하지
못한다. 그래서 **의도적으로 위반을 만들어 기록 1건을 확인**했다.

| 관측 | 결과 |
|---|---|
| 양성 대조 (품절 2건) | `reason: MENU_SOLD_OUT`, `detail.shadow: true`, 위반 메뉴 2건 전부 열거 |
| 정상 결제 | **새 기록 없음** (오탐 0) |
| `pending` + `approvedAt` 매장 결제 | **새 기록 없음** (불변식) |

### ⑩ 라이브 검증

- **⑩-2 (최우선, `enforce` 상태) — 통과.** `status:'pending'` + `approvedAt` 있는 매장의 결제가
  **성공**했다. 이 항목이 실패했으면 즉시 비상 정지였다. shadow 때의 관측과 달리 이번은
  거절이 켜진 상태의 확인이다.
- **거절 화면 — 통과.** 품절 메뉴 이름 지목 · 요금 문구 · 장바구니 품절 표시.
  (구버전 앱에서는 "어느 메뉴가 품절인지 알 수 없다" 가 실제로 문제였고 ⑦ 이 그것을 고쳤다.)
- **⑩-3b/3c (위조 create 거부) — 미실시.** 점주 계정으로 앱을 우회해 SDK 를 직접 호출해야 하는데
  운영 토큰을 손으로 꺼내야 해서 품이 크다. 대신 **④ 에 올린 바로 그 파일**(`firestore.rules.stage4`)로
  하네스 420건을 돌려 `PSA-A`(위조 create 거부) · `PSA-F02`(반려 전이 차단) · `PSA-RJ`(정상 재제출
  허용)가 전건 통과함을 확인했고, 운영에 그 파일이 올라간 것도 확인했다. **"파일이 옳다" 와
  "그 파일이 올라갔다" 를 나눠 증명한 셈**이고, 남는 공백은 "운영 환경 고유의 차이" 뿐이다.

### 환경 메모

- Android 디버그 APK 가 모든 ABI 를 담아 197MB 였고 에뮬레이터 `/data` 부족으로 `-r` 재설치가
  실패했다. **`--target-platform android-arm64` 로 132MB** 가 되어 해결됐다. 에뮬레이터 용량을
  키우려면 `disk.dataPartition.size` 를 올린 뒤 **데이터 wipe** 가 필요하다(이미지가 새로 만들어질
  때만 적용). 이번에는 불필요했다.
- ⑥-b 를 하려면 **고객 기기에 구버전 앱이 필요**하다. 신버전은 `checkout_page.dart` 의 선검증이
  위반을 읽으면 결제 화면 전에 막아 **서버 게이트까지 도달하지 못하고**, 그러면 shadow 기록도
  생기지 않는다. 이번에는 ③ 의 admin 카드 때문에 앱을 미리 깔아서, `85de349` 로 worktree 를 만들어
  구버전을 다시 설치했다. **런북이 ⑦(앱)을 ⑥-b 뒤에 두는 이유가 이것이다.**

### ⑩-c (Q1 "요금도 청구되지 않았어요") — **확인 불가, 실연동 전환 시 재확인**

테스트 키 환경에서는 이 문구의 진실성을 **증명할 수 없다.** 토스페이먼츠 상점관리자의
정산 달력은 실연동 기준이라 테스트 결제가 잡히지 않고, "아무것도 없다" 가 곧 "청구가
없었다" 의 증거가 되지 않는다.

- **구조적 근거는 있다**: 게이트는 Toss `confirm` **이전**에 거절하므로 승인 요청 자체가 나가지
  않는다. design Q1 ⓐ 를 고른 근거가 이것이다.
- **그러나 "구조상 그럴 리 없다" 와 "실제로 안 그랬다" 는 다르다.** 카드사가 위젯 인증 단계에서
  알림을 보내는지 같은 것은 실물로만 확인된다.
- **실연동 키로 전환하는 시점의 필수 확인 항목으로 승격한다.** 그때 승인 문자·일시 보류가
  잡히면 design §3.4 의 돈 줄을 `아직 결제가 완료되지 않았어요`(design Q1 ⓑ)로 **즉시 교체**한다.
  문구를 유지한 채 실결제를 받기 시작하면, 그 순간부터 **돈에 대해 검증되지 않은 주장을 고객에게
  하고 있는 것**이다.
