# 배포 런북 — 결제 금액의 서버 권위화 (payment_price_authority)

- 프로젝트: `order-app-5957e` (**`.firebaserc` 가 없으므로 모든 명령에 `--project order-app-5957e` 를 붙인다**)
- 순서 근거: `spec.md` §18 · §18-1 · §18-2 · §13-8
- 선행 런북: `docs/tasks/payment_server_authority/deploy_runbook.md` (같은 패턴 — 전체 한 줄 명령, 중단 기준, 배포 기록)
- **비상 정지는 `docs/operations.md §6.3` 이 단일 진실원이다.** 이 런북은 그 문서를 가리키기만 한다. 다만 **이번 배포 고유의 발동 신호**(무한 거절 루프)는 아래 §비상 정지에 둔다 — 배포 중에만 쓰는 지식이기 때문이다.
- **순서를 바꾸지 말 것.** 특히 ② → ③ → ④ → ⑤ → ⑥ → ⑦ 은 뒤집으면 **매출이 멈추거나 위조가 데이터로 굳는다.**

---

## 0. 이 배포가 선행과 다른 점 — 읽고 시작할 것

### 0-1. ⚠️ 앱이 enforce 보다 **먼저** 나간다 (선행 런북과 순서가 반대다)

| | 선행 `payment_server_authority` | 이번 |
|---|---|---|
| 순서 | 서버 `enforce` → 앱 | **앱 → 서버 `enforce`** (⑥ → ⑦) |
| 이유 | 앱의 선검증이 **막는 장치**다. 서버 안전망 없이 클라이언트가 먼저 막으면 거절 판단이 서버 밖으로 옮겨간다 | 이번 앱 변경은 **막는 장치가 아니라 카트를 고치는 장치**다(재가격). 그리고 **그것이 없으면 enforce 가 무한 거절 루프를 만든다** |

가격이 바뀐 뒤 카트는 스스로 갱신되지 않는다(in-memory, 비영속). 구버전 앱에서 서버가 금액 불일치를 거절하면 고객은 **다시 눌러도 같은 거절**이다 — 돈이 멈추는데 빠져나갈 길이 없다(spec §7-2). 복구 경로(체크아웃 진입 재가격 + 거절 화면의 `최신 가격으로 다시 담기`)가 **앱에 있어야** 거절을 켤 수 있다.

### 0-2. 사고 경로 4개

| # | 경로 | 막는 장치 |
|---|---|---|
| 1 | **① 을 `npm run deploy` 로 치면 금액 게이트가 기준선 측정 전에 올라간다.** 감사 CF 와 `verifyTossPayment` 가 같은 `index.ts` 에서 export 되고 `functions/package.json` 의 `deploy` 는 전 함수 배포다 | ① 은 **함수 단위** 배포. 게다가 `PAYMENT_PRICE_MODE` 기본값이 `off` 라 올라가도 평가하지 않는다 |
| 2 | **⑤ 의 `.env` 파일이 없거나 `PAYMENT_GATE_MODE=enforce` 줄이 빠진 채 재배포하면 선행 게이트가 조용히 `off` 로 떨어진다** (기본값 `off`) | ⑤ 전에 `cat` 으로 **두 줄 다 확인**. 값을 바꾸는 명령은 `grep -v` 로 **해당 키만** 교체한다(`>` 로 덮지 않는다) |
| 3 | **③ Rules 를 조이기 전에 ② 를 건너뛰면** "원래 있던 self-approved" 와 "새로 생긴 것" 을 영구히 구분할 수 없다 | ② 가 ③ 보다 먼저. 기준선을 아래 배포 기록에 **숫자로** 적는다 |
| 4 | **③ 없이 ⑦(enforce) 로 가면 승인 요건이 집행되지 않는 가격을 서버가 "권위 있는 금액" 으로 쓴다** | 중단 기준 §중단 기준 3번 |

### 0-3. Rules 는 단계 파일을 두지 않는다 — 그 판단의 근거

선행은 `firestore.rules.stage4` 를 따로 뒀다. HEAD 의 Rules 에 **구 앱을 깨는 뒤 단계(B+C)** 가 같이 들어 있었기 때문이다. 이번은 HEAD 의 `firestore.rules` 에 변경이 **둘뿐이고 둘 다 구 앱·구 CF 와 호환**된다:

| 변경 | 구 앱 영향 | 구 CF 영향 |
|---|---|---|
| `menuOverrides` — 점주는 승인 상태의 핵심 필드를 쓸 수 없다 | 점주 앱의 정상 쓰기(운영 필드 upsert · 매장 등록 시 제외 시드)는 **통과**한다 — 하네스 `PPA-3~3b` | 영향 없음(Admin SDK) |
| `priceHistory` — admin 읽기 전용, write 금지 | 이 컬렉션을 쓰는 앱 코드 0건(가드 테스트) | 트리거는 Admin SDK |

그래서 **HEAD 를 그대로 배포해도 뒤 단계가 같이 나가는 사고가 없다.** 두 변경은 별개 커밋으로 나뉘어 있다(`implementation.md` §커밋 경계) — 하나만 되돌려야 하면 그 커밋만 되돌린다.

### 0-4. 롤백 단위

③ 단독(Rules) / ⑤ 단독 또는 `PAYMENT_PRICE_MODE=off` / ⑥ 단독. **④ 는 되돌리지 않는다**(사람이 판단해 처리한 결과). **가장 싼 비상 정지는 `PAYMENT_PRICE_MODE=off` 재배포다** — `operations.md §6.3`.

---

## ① 감사 CF 만 배포 — **함수 단위**

```bash
cd /Users/Byeonguk/Developer/OrderApp && npm --prefix functions run build && npx --yes firebase-tools@14 deploy --only functions:auditOrderPriceIntegrity --project order-app-5957e
```

⚠️ **`npm run deploy` 를 쓰지 말 것.** 그것은 `firebase deploy --only functions`(전 함수)이므로 금액 게이트 코드가 기준선 측정 전에 올라간다(§0-2 #1).

배포 후 확인:

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 functions:list --project order-app-5957e
```

- `verifyTossPayment` 의 **리비전이 바뀌지 않았음**을 Console(Cloud Functions → 세부정보 → 버전)에서 확인한다. 바뀌었다면 `PAYMENT_PRICE_MODE` 가 `off` 인지(기본값) 확인하고 계속한다.
- 신규 callable 이므로 선행 ⑥ 에서 한 것처럼 **Cloud Run 호출자 권한**이 필요하면 부여한다(앱에서 호출했을 때 `permission-denied`/`unauthenticated` 가 아니라 호출 자체가 막히면 이 단계 누락이다).

```bash
cd /Users/Byeonguk/Developer/OrderApp && gcloud run services add-iam-policy-binding auditorderpriceintegrity --region=asia-northeast3 --member=allUsers --role=roles/run.invoker --project=order-app-5957e
```

(이 callable 은 서버에서 `users/{uid}.role == 'admin'` 을 직접 검증한다 — 호출자 권한은 문을 여는 것이고 인가는 코드가 한다.)

## ② 실태 측정 — **Rules 보다 먼저**

**이 카드가 들어간 앱을 admin 기기에 먼저 설치한다.** 감사 카드는 고객용 앱과 **같은 빌드**다. 이 빌드의 재가격(R9)은 서버 모드와 무관하게 동작하고 카트를 고칠 뿐이라 구버전 서버·구 Rules 와 충돌하지 않는다 — **이 기기로 고객 결제를 해도 된다.**

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter devices
```

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter run -d <device-id> --dart-define-from-file=env.json
```

admin 계정 → 하단 탭 **더보기** → **배포 마이그레이션 (임시)** → **② ⑨ 가격 감사 (읽기 전용)** 카드 → `측정 실행`.

| 분류 | 기대 | 어긋나면 |
|---|---|---|
| **ⓐ 주문 금액 정합성 위반** (4개 불변식) | **0건** | **멈추고 보고한다.** 이미 일어난 사고다(`amount:1` 류). 목록의 주문 id·소계/라인합/승인액을 기록한다 |
| **ⓑ 점주가 직접 승인한 가격 오버라이드** | **0건** | **④ 의 사람 판단 없이 ⑦ 로 가지 않는다.** 건수·목록을 기록한다 |
| ⓒ 브랜드 메뉴 → 가맹점 옵션 그룹 참조 | 0 이 아니어도 된다 | **측정 값이다.** 후속 P2(가격 승인 정책 일관화)의 착수 근거 — 숫자를 아래 기록에 적는다 |

- 카드에 `운영 필드만 있는 승인 문서 N건` 이 보이는 것은 정상이다(점주의 품절 토글이 만드는 문서: `status:'approved'` + 핵심 필드 없음).
- `응답에 없음` 이 보이면 서버가 그 분류를 안 줬다는 뜻이다 — 0건이 아니다. 카드가 빨갛게 "기준선이 0 이 아니거나 응답이 불완전" 이라고 말한다.
- ⓐ 가 `한도에서 잘림` 이면 기간이 20,000건을 넘은 것이다 — **일부만 본 기준선은 기준선이 아니다.** 입력 인자(`from`/`to`)로 나눠 재는 것은 CF 직접 호출(Console 테스트)로 한다.
- **고치지 않는다.** 이 도구에는 쓰기 버튼이 없다.
- 이 실행 1건은 `migrationHistory` 에 `name: auditOrderPriceIntegrity` 로 남는다(실행자·기간·건수).

**기준선을 아래 "배포 기록" 표에 숫자로 적는다.** 기준선 없이 enforce 하면 "원래 있던 것" 과 "새로 생긴 것" 을 영구히 구분할 수 없다.

## ③ Rules 배포 — 확정 항목 (§13-8 + R16)

**CF 보다 먼저.** 뒤집으면 위조가 데이터로 굳는다. §0-3 대로 HEAD 의 `firestore.rules` 를 그대로 배포한다.

먼저 작업 트리가 의도한 상태인지 본다. 이번 배포에서 `firestore.rules` 를 건드린 커밋은 **둘뿐**(`menuOverrides` / `priceHistory`)이어야 하고 작업 트리는 깨끗해야 한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && git status --short firestore.rules && git log --oneline -5 -- firestore.rules
```

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:rules --project order-app-5957e
```

**라이브 확인 (점주 계정으로, 앱을 우회하는 SDK 호출이 어렵다면 하네스 결과로 대체하고 그 사실을 기록한다)**

| 시도 | 기대 |
|---|---|
| 가맹점주가 자기 매장 `menuOverrides/{id}` 에 `status:'approved'` + `priceOverride` 를 create/update | **거부** (하네스 `PPA-1`·`PPA-2` 12건 — 구 Rules 에서는 전건 허용됐다) |
| 점주가 품절 토글 (앱의 `updateOverrideOperationFields`) | **성공** (회귀 — `PPA-3`·`PPA-3c`) |
| 브랜드 보유자가 가격 제출(pending) · admin 이 승인/반려 | **성공** (회귀 — `PPA-3e~3i`) |
| 가맹점 등록 직후 제외 시드(`excluded:true`, pending) | **성공** (회귀 — `PPA-3b`) |

- **하나라도 회귀가 깨지면 즉시 되돌린다**(`git revert` 한 커밋 + 같은 배포 명령). 점주가 품절 토글을 못 하면 영업이 멈춘다.
- 구버전 앱의 정상 쓰기는 모두 통과하므로 앱보다 먼저 둘 수 있다.

## ④ ⓑ 실태 처리 — 사람이 판단

② 의 ⓑ 가 0 이면 이 단계는 no-op 이다.

0 이 아니면 **목록의 각 건을 사람이 본다**: 정말 브랜드가 승인한 가격인데 승인 메타가 비어 있는 것인가, 점주가 직접 쓴 것인가. 점주가 쓴 것이면 Console 에서 `status` 를 `pending` 으로 돌리거나(가격 효력 중지) 브랜드에 확인 후 정식 승인 경로를 밟는다. **자동으로 고치지 않는다.** 처리 결과를 배포 기록에 적는다. 처리 후 ② 를 다시 쟤서 ⓑ 가 0 인지 본다.

⚠️ 이 단계 없이 ⑦ 로 가면 **self-approved 가격이 서버 공인 금액이 된다.**

## ⑤ 본 CF 배포 — **`PAYMENT_PRICE_MODE=shadow`**

**먼저 모드 파일을 확인한다.** 값은 `functions/.env.order-app-5957e` 의 줄이고 git 제외다. **선행 게이트(`PAYMENT_GATE_MODE=enforce`)가 이 파일에 있다** — 파일이 없거나 그 줄이 빠진 채 재배포하면 선행 게이트가 조용히 `off` 로 떨어진다(§0-2 #2).

```bash
cd /Users/Byeonguk/Developer/OrderApp && cat functions/.env.order-app-5957e
```

출력에 **`PAYMENT_GATE_MODE=enforce`** 가 보여야 한다. 없으면 **멈춘다** — 이 머신은 운영 배포 머신이 아니거나 파일이 유실됐다.

가격 모드 줄만 교체한다 (`>` 로 덮어쓰지 않는다):

```bash
cd /Users/Byeonguk/Developer/OrderApp && grep -v '^PAYMENT_PRICE_MODE=' functions/.env.order-app-5957e > /tmp/ppa_env.new ; echo "PAYMENT_PRICE_MODE=shadow" >> /tmp/ppa_env.new && mv /tmp/ppa_env.new functions/.env.order-app-5957e && cat functions/.env.order-app-5957e
```

출력에 `PAYMENT_GATE_MODE=enforce` 와 `PAYMENT_PRICE_MODE=shadow` **둘 다** 보이는지 눈으로 확인한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && npm --prefix functions test && npx --yes firebase-tools@14 deploy --only functions --project order-app-5957e
```

- 올라가는 것: `verifyTossPayment`(금액 게이트 2-c, shadow) · 가격 이력 트리거 6개(`onMenuPriceWritten` 외 5) · (이미 올라간) 감사 CF.
- **`shadow` 이므로 이 시점에 금액 거절은 발생하지 않는다.** 코드가 올라갈 뿐이다.
- 값은 **배포 시점에 박힌다.** 파일만 고치고 재배포하지 않으면 반영되지 않는다.
- **가격 이력 트리거**는 이 배포부터 쌓이기 시작한다. 과거 가격은 복원할 수 없으므로 미룰수록 못 보는 구간이 는다(spec §17).

## ⑤-b shadow 관측 — **거절을 켜기 전에 실측한다**

Console → Firestore → `paymentGateRejections` 에서 `detail.shadow == true` 이고 `reason` 이 `PRICE_MISMATCH` / `OPTION_UNAVAILABLE` / `READ_FAILED` 인 기록을 본다.

🔴 **"기록이 비어 있다" 를 정상으로 읽지 않는다.** ⓐ 잡을 것이 없었다 와 ⓑ **모드가 `off` 라서 게이트가 안 돌았다** 를 구분하지 못한다. **양성 대조를 먼저 만든다**:

1. 구버전 앱(현재 운영 앱)으로 메뉴를 카트에 담는다.
2. **점주 앱(또는 Console)에서 그 메뉴의 `basePrice` 를 바꾼다.**
3. 구버전 앱에서 결제한다 (구버전은 재가격이 없어 옛 가격으로 결제를 시도한다).

→ shadow 이므로 **결제는 성립하고**, `paymentGateRejections` 에 `reason: PRICE_MISMATCH`, `detail.shadow: true`, `detail.delta` ≠ 0, `detail.lines` 에 그 메뉴의 `clientLineTotal` ≠ `serverLineTotal` 이 **1건 생겨야 한다.** 이 1건이 "금액 게이트가 shadow 로 실제 돌고 있다" 는 유일한 증거다. 또 `priceHistory` 에 그 가격 변경 1건이 생겼는지 함께 본다.

| 양성 대조 | 판단 |
|---|---|
| **기록이 생기지 않는다** | **모드가 `shadow` 가 아니다.** ⑤ 의 파일 쓰기·재배포를 다시 한다. 이 상태로 ⑦ 로 가면 `enforce` 도 반영되지 않았을 수 있다 |
| 기록이 생긴다 | 게이트가 돈다. 아래 관측으로 |

| 관측 | 판단 |
|---|---|
| 양성 대조 건만 | 정상. 정상 결제 기록은 **없어야** 한다 |
| **정상 결제(옵션 포함)가 잡힌다** | **멈추고 원인부터 찾는다.** `enforce` 로 넘어가면 그 결제가 막힌다. `detail.checks` 로 어느 판정식(c1~c6)이 깨졌는지, `detail.lines` 의 서버/클라 값, `detail.optionIssues` 를 본다 |
| `detail.failure: optionGroupCapExceeded` **1건이라도** | **멈춘다.** spec §6-2 의 "도달 불가" 가정이 틀렸다 |
| 유령 ref(`optionIssues[].kind == 'missing'` 이 정상 선택에서 나옴) | 데이터를 먼저 고친다(옵션 그룹 문서 복구 또는 ref 정리). 고치기 전에는 `enforce` 금지 |
| `delta` 가 **음수로 크게** 치우친 건 | 시점 차이가 아니라 조작 의심 신호이므로 보고한다 (시점 차이는 양·음 양방향으로 흩어지고 금액이 작다) |

관측 기간은 **실결제 트래픽이 거의 없다면 "직접 테스트 결제 몇 건"** 이 전부다. 최소: 옵션 없는 정상 결제 1 · **옵션이 붙은 정상 결제 1 (음수 증감 옵션 포함이면 더 좋다)** · 가격 변경 후 결제 1 · 같은 메뉴 옵션만 달리 2줄 1.

## ⑥ 앱 배포 (재가격 포함) — **⑦ 보다 먼저**

(②에서 admin 기기에 이미 설치한 빌드와 같은 빌드다. 고객 기기 전부에 설치한다.)

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter run -d <device-id> --dart-define-from-file=env.json
```

- Android 디버그 APK 용량이 문제면 `--target-platform android-arm64` (선행 배포 환경 메모).
- `adb install` 을 쓸 경우 출력에서 **`Success` 를 눈으로 확인**한다.
- **이 앱이 라이브가 아니면 ⑦ 로 가지 않는다**(무한 거절 루프, §0-1).

설치 후 확인 (서버는 아직 shadow 이므로 결제는 성립한다):

| 시도 | 기대 |
|---|---|
| 카트에 담은 뒤 점주가 가격을 올림 → 카트 화면 진입 | 상단에 **가격 변동 배너**(`메뉴 가격이 올라 …`)와 라인의 이전 금액 취소선·`가격이 올랐어요`. **자동으로 결제로 넘어가지 않는다** |
| 위 상태에서 `결제하기` | 바로 체크아웃으로 가지 않고 **카트에서 한 번 멈춘다**(새 변동이 있을 때만). 한 번 더 누르면 체크아웃 |
| 체크아웃에서 결제 탭 직전에 가격 변경 | `결제 금액이 바뀌었어요` 시트, 결제창은 열리지 않음 |
| 가격 변동이 없을 때 | **어떤 가격 표시도 없다** |

## ⑦ `PAYMENT_PRICE_MODE=enforce` 전환

**전제 3개를 먼저 확인한다.** ⓐ ③ Rules 가 라이브 ⓑ ⑤-b 가 깨끗함 ⓒ ⑥ 앱이 라이브.

```bash
cd /Users/Byeonguk/Developer/OrderApp && grep -v '^PAYMENT_PRICE_MODE=' functions/.env.order-app-5957e > /tmp/ppa_env.new ; echo "PAYMENT_PRICE_MODE=enforce" >> /tmp/ppa_env.new && mv /tmp/ppa_env.new functions/.env.order-app-5957e && cat functions/.env.order-app-5957e && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

(`cat` 출력에 `PAYMENT_GATE_MODE=enforce` 와 `PAYMENT_PRICE_MODE=enforce` 가 **둘 다** 보이는지 확인한다.)

⚠️ **전환 직후 거절 1건을 실제로 유도해 확인한다.** 신버전 앱은 결제 탭 직전에 재가격하므로 일반 조작으로는 서버 거절이 나지 않는다. **결제창(Toss)이 떠 있는 동안 점주 앱/Console 에서 그 메뉴 `basePrice` 를 바꾼다** → 결제창을 마치고 돌아오면 서버가 금액 불일치를 거절한다.

| 기대 | 내용 |
|---|---|
| 거절 화면 | `메뉴 가격이 바뀌었어요` + `최신 가격으로 다시 담기` (금액 숫자 없음) |
| `paymentGateRejections` | `reason: PRICE_MISMATCH` 1건, **`detail.shadow` 키 없음**, `detail.delta` 의 부호가 가격 변경 방향과 맞음 |
| 돈 | Toss 에 승인이 남지 않음(confirm 이 호출되지 않는다) — 테스트 키라 카드사 쪽 사실은 `operations.md §6.6` 대로 미확인 |

**이 확인을 하지 않으면 전환이 끝난 것으로 보지 않는다** — 기본값이 `off` 라서 오타가 조용히 넘어간다.

## ⑧ 라이브 검증

| # | 시도 | 기대 |
|---|---|---|
| 1 | **옵션이 붙은 정상 결제 1건** (음수 증감 옵션이 있으면 포함) | **성공.** 이 항목이 실패하면 **즉시 비상 정지**(`operations.md §6.3`) 후 보고. 주문 문서의 금액이 화면 금액과 같은지 확인 |
| 2 | 가격 변경 직후 결제 (⑦ 의 거절 화면에서) → `최신 가격으로 다시 담기` | 카트로 돌아가 **배너 + 라인 표시** → `결제하기` → 체크아웃 → **결제 성공.** 같은 거절이 반복되지 않는다(무한 루프 없음) |
| 3 | 옵션 항목을 점주가 비활성화한 뒤 담아 둔 카트로 결제 | 체크아웃 시트 `옵션을 다시 골라야 해요` 또는 서버 거절 `선택하신 옵션이 바뀌었어요` → 카트에서 **불가 옵션 라벨만 취소선**, `다시 고르기` 로 메뉴 상세 이동 |
| 4 | 가격을 **내린** 뒤 같은 흐름 | 같은 규칙으로 멈추고 `가격이 내려갔어요`(초록 아님) |
| 5 | 네트워크 차단 상태에서 `최신 가격으로 다시 담기` | 화면에 머문다 · 인라인 오류 · 라벨 `다시 불러오기` · 카트로 이동하지 않음 |
| 6 | 빠른 재주문(옛 가격 역산)으로 담은 뒤 카트 진입 | 현재 가격으로 교정되고 배너가 알린다 |

## ⑨ 재측정

② 와 같은 카드로 `측정 실행`. **ⓐ ⓑ 가 ② 대비 증가 0** 인지 본다. 증가했다면 enforce 이후에 생긴 것이므로 즉시 보고한다.

## ⑩ 정리 커밋 (며칠 뒤)

⑨ 가 증가 0 이고 ⑧ 이 전건 통과일 때만. **감사 CF 와 그 호출 카드를 한 번에 지운다.** 가격 이력 트리거와 `priceHistory` Rules 는 **상시 자산**이라 지우지 않는다.

- 코드: `functions/src/auditOrderPriceIntegrity.ts` · `index.ts` 의 export 1줄 · `functions/test/priceAudit.test.mjs` 의 감사 관련 테스트 · `lib/` 의 `grep -rn TEMP_PRICE_AUDIT_CARD lib test` 로 나오는 파일 전부 · `admin_migration_page.dart` 의 카드 1줄
- 배포 시 함수 삭제: `npx --yes firebase-tools@14 functions:delete auditOrderPriceIntegrity --region asia-northeast3 --project order-app-5957e`
- `payment_authority_guard_test.dart` 의 허용 목록(`auditOrderPriceIntegrity.ts`) 한 줄을 함께 지운다.
- `flutter analyze` · `flutter test` · `functions npm test` · Rules 하네스가 **전건 통과**해야 커밋한다.

---

## 중단 기준 (spec §18-2)

1. ② ⓐ 에 위반이 **1건이라도** 있으면 멈추고 보고한다(이미 일어난 사고).
2. ② ⓑ(self-approved)가 **0 이 아니면** ④ 의 사람 판단 없이 ⑦ 로 가지 않는다.
3. **③ Rules 가 없으면 ⑦ 로 넘어가지 않는다.**
4. ⑤-b 에서 **정상 결제가 잡히면** `enforce` 로 넘어가지 않는다.
5. ⑤-b 에서 **그룹 수 상한 초과 기록이 1건이라도** 나오면 멈춘다.
6. ⑤-b 에서 **유령 ref** 가 나오면 데이터를 먼저 고친다.
7. **⑥(앱)가 라이브가 아니면 ⑦ 로 넘어가지 않는다.**
8. ⑦ 의 **거절 1건 실측을 못 했으면** 전환이 끝난 것으로 보지 않는다.
9. ⑧-1(옵션 포함 정상 결제)이 실패하면 **즉시 비상 정지** 후 보고.
10. ③ 직후 `PPA-3` 류 회귀(점주 품절 토글 등)가 깨지면 ③ 을 되돌린다.

---

## 비상 정지

**방법은 `docs/operations.md §6.3` 이 단일 진실원이다** — 해당 모드를 `off` 로 재배포한다(명령은 §6.2). 이번 배포에서는 **`PAYMENT_PRICE_MODE=off`** 다. **품절 게이트(`PAYMENT_GATE_MODE`)는 건드리지 않는다** — 두 플래그를 나눈 이유가 이것이다.

⚠️ `off` 는 **1원 결제가 가능한 상태**다. 내린 뒤 잊지 않는다. 원인을 고치고 `shadow` → `enforce` 를 다시 밟는다.

**이번 배포 고유의 발동 신호**: 라이브에서 **무한 거절 루프**가 관측될 때 — 같은 고객·같은 카트의 `PRICE_MISMATCH` 거절이 `paymentGateRejections` 에 반복해서 쌓이는 경우(같은 `uid` + 같은 `storeId` 에서 짧은 시간에 2건 이상, `detail.lines` 의 메뉴가 같음). 데이터·앱 원인을 찾기 전에 **먼저 `PAYMENT_PRICE_MODE=off` 로 내린다.** 원인 후보: 앱 재가격과 서버 판정의 산식 불일치(교차 골든이 막지만 골든 밖 입력), 옵션 그룹 문서 시점 차이, 변형 N 화면의 `카트 비우고 메뉴 보러가기` 로도 풀리지 않는 데이터 결함.

---

## 배포 기록

> 이 표는 배포하는 사람이 손으로 채운다. 모드 전환 이력은 Firestore 에 남기지 않으므로(spec §13-2) **전환 시각과 실행자가 여기에만 남는다.**

| 단계 | 일시 | 실행자 | 결과 / 기준선 숫자 |
|---|---|---|---|
| ① 감사 CF | | | |
| ② 측정 ⓐ 주문 위반 | | | 스캔 __ / 위반 __ |
| ② 측정 ⓑ self-approved | | | __ 건 (opsOnlyApproved __ 건) |
| ② 측정 ⓒ store-scope 참조 | | | 참조 __ 건 / 영향 가맹점 쌍 __ |
| ③ Rules | | | |
| ④ ⓑ 처리 | | | |
| ⑤ 본 CF (shadow) | | | `.env` 두 줄 확인: ☐ |
| ⑤-b 양성 대조 | | | |
| ⑥ 앱 | | | |
| ⑦ enforce 전환 | | | 거절 1건 실측: ☐ |
| ⑧ 라이브 검증 | | | |
| ⑨ 재측정 | | | ⓐ __ / ⓑ __ (② 대비 증가 0: ☐) |
| ⑩ 정리 커밋 | | | |
