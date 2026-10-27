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

**dry-run 먼저.** admin 계정으로 앱(또는 임시 callable)에서 `migrateStoreApprovalMeta {dryRun:true}`.

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
cd /Users/Byeonguk/Developer/OrderApp && cp firestore.rules /tmp/rules_head.rules && cp docs/tasks/payment_server_authority/firestore.rules.stage4 firestore.rules
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
cd /Users/Byeonguk/Developer/OrderApp && git show 11c90c7:firestore.rules > /tmp/s4.rules && for c in 6c1c831 7bdda20 <추가커밋>; do git show $c -- firestore.rules > /tmp/$c.patch && patch /tmp/s4.rules < /tmp/$c.patch; done && cp /tmp/s4.rules docs/tasks/payment_server_authority/firestore.rules.stage4
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

admin 계정으로 `migrateBrandPrivateProfile {mode:'copy', dryRun:true}` → 확인 → `{dryRun:false}`.

- 복사는 **private 의 기존 값을 덮지 않는다.**
- ⚠️ **⑤ 가 ⑥ 보다 먼저여야 한다.** 어기면 `issueBrandKey` 가 기존 키를 "이미 발급" 으로 인식하지
  못해 **재승인 때 새 키가 발급되고 기존 키가 무효가 된다** (spec §17.1 / test_report F-01 말미).
- **부모 문서의 PII·brandKey 제거는 ⑨ 다.** 지금 지우면 구버전 앱의 브랜드 정보 화면이 빈다.

## ⑥ 본 Cloud Functions 배포 — **`PAYMENT_GATE_MODE=shadow`**

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions --project order-app-5957e
```

- 배포 전 **`PAYMENT_GATE_MODE` 가 `shadow` 로 설정돼 있는지** 확인한다
  (functions params — `.env` / Secret Manager 중 구현이 택한 곳. `implementation.md` 참조).
- 올라가는 것: `verifyTossPayment`(G1·G2 게이트) · `lookupBrandByKey` · `issueBrandKey` · `deleteStore`.
- **`shadow` 이므로 이 시점에 거절은 발생하지 않는다.** 그래서 ⑥ 을 어떤 방식으로 올려도 안전하다.

## ⑥-b shadow 관측 — **거절을 켜기 전에 실측한다**

Console → Firestore → `paymentGateRejections` 에서 `detail.shadow == true` 기록을 본다.

| 기록 | 판단 |
|---|---|
| 비어 있다 | 정상. ⑥-c 로 간다 |
| 미승인/반려 매장 건만 있다 | 정상(게이트가 잡아야 할 것을 잡았다). ⑥-c 로 간다 |
| **영업 중인 정상 매장 / 품절이 아닌 메뉴가 잡힌다** | **멈춘다.** ③ 의 `willBeRejected` 와 교차 확인하고 원인을 찾는다. `enforce` 로 넘어가면 **그 매장의 매출이 멈춘다** |

관측 기간은 **실결제가 0회이므로 "직접 테스트 결제 몇 건"** 이 전부다 — 자연 트래픽을 기다릴 수 없다.
승인 매장 1곳 정상 결제 + 핵심 필드 수정 직후 결제 + 미승인 매장 호출 3건을 **의도적으로** 만든다.

## ⑥-c `PAYMENT_GATE_MODE=enforce` 전환

**전제 2개를 먼저 확인한다.** ⓐ ④ 라이브 확인 6건 통과 ⓑ ⑥-b 가 깨끗함.

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

(파라미터 값만 바꿔 재배포한다. 구현이 Secret/param 을 어디서 읽는지는 `implementation.md`.)

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

admin 계정으로 `migrateBrandPrivateProfile {mode:'cleanup', dryRun:true}` → 확인 → `{dryRun:false}`.

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

   (파라미터를 `off` 로 바꾼 뒤 실행. 게이트가 **평가조차 하지 않으므로** 즉시 현재 동작으로 돌아간다.)

2. 그래도 결제가 실패하면 게이트 문제가 아니다 → `paymentGateRejections` 와 CF 로그를 본다.
3. Rules 가 원인으로 의심되면 ⑧ → ④ 순서로 되돌린다 (**데이터 마이그레이션은 되돌리지 않는다**).

> ⚠️ **`off` 로 내린 뒤 그대로 잊지 않는다.** `off` 는 구멍이 열린 상태다. 원인을 고치고
> ⑥-b(shadow 관측) → ⑥-c(enforce) 를 **다시 밟는다.**
