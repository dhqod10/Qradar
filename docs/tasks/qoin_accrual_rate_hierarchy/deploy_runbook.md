# 배포 런북 — 적립률 계층화 + 브랜드 권한 수정

**두 task 가 한 배포에 나간다.** `qoin_accrual_rate_hierarchy` 와 `brand_authorization_hardening`.

- 프로젝트: `order-app-5957e` (`.firebaserc` 가 없으므로 **모든 명령에 `--project` 를 붙인다**)
- 순서 근거: `spec.md` §20.11 · §21.6, 보안 `spec.md` §8
- **순서를 바꾸지 말 것.** 아래 ③→④ 는 어느 쪽이든 먼저 뒤집으면 돈이 멈추거나 등록이 막힌다.

---

## 왜 이 순서인가 (바꾸기 전에 읽을 것)

**③ 앱 설치가 ④ rules 보다 먼저여야 하는 이유 2개.**

1. 새 rules 는 `config/qoin` 토글에 `enabledChangedBy == uid()` 와
   `enabledChangedAt == request.time` 을 강제한다. 구버전 앱은 그 필드를 보내지 않으므로
   **비상 정지 토글이 거부된다.** 돈을 멈추는 스위치가 막히는 것이 최악이다.
2. 새 rules 는 `users.brandId` self 쓰기를 막는다(D1). 구버전 앱의 `upsertBrand` 는 브랜드
   문서 create 와 `users.brandId` 를 **한 batch** 로 보내므로 batch 전체가 거부되고
   **브랜드 신규 등록이 전면 실패**한다. `flow.test.mjs` 가 이 거부를 고정해 두었다.

**반대 방향(새 앱 + 구 rules, ③~④ 사이)은 안전하다.** 구 rules 의 `config` admin 쓰기가 더
넓고, 적립률·스위치·일괄·마이그레이션·claim 은 전부 CF(Admin SDK)라 rules 를 우회한다.
다만 그 구간에 `qoinRateHistory` 읽기 경로가 구 rules 에 없어 **이력 화면 3곳이
`permission-denied`** 가 된다. ④ 를 ③ 직후에 붙여 그 창을 수 분으로 줄인다.

**② functions 를 먼저 올려도 안전한 이유.** 과도기 호환 분기가 레거시 `0` 을 판독 측에서만
`disabled` 로 읽어 돈 결과가 구버전과 같다. 새 필드를 쓰는 클라이언트가 아직 없어 보호
공백도 0이다.

⚠️ **admin 계정으로 쓰는 기기가 2대 이상이면 ③ 에서 전 기기에 새 빌드를 설치한다.**
안 하면 ④ 이후 구버전 기기에서 비상 정지 토글과 브랜드 신규 등록이 둘 다 막힌다.

**롤백 단위는 ③+④ 를 함께** 되돌린다. ② 는 되돌리지 않는다.

---

## ① Firestore 인덱스

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:indexes --project order-app-5957e
```

`qoinRateHistory.changedAt` COLLECTION_GROUP fieldOverride 가 새로 생긴다. **빌드에 몇 분
걸릴 수 있다.** Console → Firestore → 색인 에서 `사용 설정됨` 이 될 때까지 기다린 뒤 ② 로 간다.

## ② Cloud Functions

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only functions --project order-app-5957e
```

신규 4개가 올라간다 — `setQoinAccrualEnabled`, `claimSubmittedBrand`,
그리고 임시 2개 `migrateQoinZeroRates`, `auditBrandLinks`.
기존 변경 — `onOrderQoinSettled`, `setQoinAccrualRate`, `applyBrandQoinRate`,
`onQoinConfigWritten`, `verifyTossPayment`.

## ③ 앱 빌드·설치 (로컬)

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter devices
```

```bash
cd /Users/Byeonguk/Developer/OrderApp && flutter run -d <device-id> --dart-define-from-file=env.json
```

Android 에뮬레이터는 `arm64-v8a` 다. APK 를 따로 만들 때는
`--target-platform android-arm64` 를 붙여야 용량이 절반으로 준다.
`adb install` 을 쓸 경우 **출력에서 `Success` 를 눈으로 확인**한다 —
`INSTALL_FAILED_INSUFFICIENT_STORAGE` 가 조용히 지나간 적이 있다.

## ④ Firestore 규칙 — ③ 직후에 바로

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 deploy --only firestore:rules --project order-app-5957e
```

여기서 보안 수정(D1·D2·D5)과 `enabledChangedAt` 강제가 동시에 켜진다.

## ⑤ 브랜드 링크 점검 (앱에서)

admin 로그인 → Qoin 설정(또는 더보기) → **브랜드 링크 점검** 카드 → `점검하기`.

기대 기준선은 `brand_authorization_hardening/spec.md` §11 에 있다.

| 분류 | 기대 |
|---|---|
| `ok` | **2** (ChaCha / 낫심플) |
| `orphan_brand` | **1** (`phase3_seed_brand_001`, 시드라 정상) |
| 그 외 전부 | **0** |

다르면 멈추고 보고한다. **자동 교정 버튼은 없다** — `mismatch` 는 공격 증거가 아니다.

## ⑥ 레거시 0% 마이그레이션 (앱에서)

admin → Qoin 설정 → **마이그레이션** 카드 → `대상 확인(dry-run)`.

- 0% 매장 목록과 건수가 기억과 맞는지 본다
- **무효 값 목록이 비어 있는지** 본다. 비어 있지 않으면 멈추고 보고한다 (자동 변환하지 않는다)
- 확인되면 `실행` → 결과가 `migrated` = dry-run 건수, `skipped` 0 인지 본다

## ⑦ 라이브 검증

1. Console → `stores` → 이전된 매장 1곳: `qoinAccrualRate` **없음** + `qoinAccrualEnabled: false`
2. 그 매장 `qoinRateHistory`: `source:'migration'` / `changedBy` = 본인 uid / `migratedFromRate: 0`
3. Console → `config/qoin.accrualRate` 가 `0.001~0.2` 사이 number 인지
   (**여기가 0 이나 문자열이면 전역 fail-closed 로 전체 적립이 멈춘다**)
4. 앱 admin → 해당 매장 상세의 우선순위 사슬이 **`사용 안 함`** 으로 보이는지
5. 브랜드 일괄 적용을 한 번 실행해 결과 카드 수치와 이력이 맞는지
6. 비상 정지 토글을 껐다 켜보고 이력에 `app_direct` + 본인 uid 가 남는지
7. 점주 계정으로 브랜드 전환을 한 번 해보고 정상 연결되는지 (D1 의 핵심 경로)

## ⑧ 정리 커밋 (며칠 뒤)

⑥ dry-run 이 **0건**, ⑤ 점검이 기준선과 같을 때만.

과도기 자산 5종(판독 호환 분기 / `resolve_legacy` / 레거시 가드 / 임시 callable 2개 /
임시 카드 2개)을 **한 번에** 지우고 `flutter analyze` · `flutter test` ·
`functions npm test` · Rules 하네스가 **전건 통과**해야 커밋한다. 하나라도 실패하면
쪼개지 말고 되돌린다. 가드 테스트가 허용 목록을 빈 집합으로 바꿨을 때 실제 파일 집합과
일치하는지 단언하므로, 빠뜨리면 테스트가 잡는다.

---

## 중단 기준

아래 중 하나라도 나오면 **멈추고 보고**한다.

- ① 인덱스가 `오류` 상태가 된다
- ② 배포가 실패한다 (일부만 올라간 경우 특히)
- ③ 이후 앱이 켜지지 않거나 로그인이 안 된다
- ④ 이후 비상 정지 토글이 거부된다 ← **즉시 rules 롤백**
- ④ 이후 점주의 브랜드 등록이 거부된다 ← **즉시 rules 롤백**
- ⑤ 점검 결과가 기준선과 다르다
- ⑥ dry-run 에 무효 값이 나온다

---

## 실제 배포 기록 (2026-10-26)

### 막혔던 곳 3개 — 다음에 같은 함정을 피하려고 남긴다

**1. 모든 함수가 "Container Healthcheck failed" 로 실패했다.**
`firebase-functions` 가 6.6.0(10개월 전)으로 묵어 있었다. 컨테이너 로그가 끝까지 **비어
있어서** 원인을 못 봤고, 새 코드를 하나도 import 하지 않는 함수 1개만 올려도 같은 증상이라
우리 코드가 아니라는 것만 확인됐다. 7.4.0 으로 올리니 바로 풀렸다 (`tsconfig` 에
`esModuleInterop: true` 필요, 코드 변경 0).

**CLI 가 매 배포마다 띄우던 `outdated version of firebase-functions` 경고가 진짜 원인을
가리키고 있었다.** 배포 경고는 먼저 털고 들어간다.

**2. 실패한 배포가 반쪽짜리 함수를 남긴다.**
`onQoinConfigWritten` 이 트리거 연결 없이 `https` 로 등록돼, 재배포 시
"Changing from an HTTPS function to a background triggered function is not allowed" 가 났다.
`functions:delete` 로 지우고 다시 배포해야 한다. **한 번도 뜬 적 없는 함수라 삭제는 안전하다**
(`functions:list` 에서 메모리가 `---` 면 활성 리비전이 없다는 뜻).

**3. 새로 만든 callable 함수는 "공개 호출 허용" 이 빠진다.**
증상은 앱에서 `점검하지 못했어요` 같은 실패이고, CF 로그에
`The request was not authorized to invoke this service` 가 찍힌다. Firebase callable 은 그
아래 Cloud Run 서비스가 `allUsers` 에게 **Cloud Run 호출자** 를 줘야 한다(인증은 함수 안에서
Firebase 토큰으로 한다). 이 설정은 **함수 생성 시**에만 붙는데, 1번 때문에 생성이 깨지면서
빠졌다. Cloud Run Console 에서 서비스 여러 개를 체크해 한 번에 부여할 수 있다.
**IAM 전파에 1~2분 걸린다** — 바로 재시도하면 여전히 실패한다.

### 결과

- ① 인덱스 ✅ · ② Functions 17/17 ✅ · ③ 앱(Android·iOS) ✅ · ④ Rules ✅
- ⑤ 브랜드 링크 점검 — **기준선과 정확히 일치**(ok 2 / orphan_brand 1 / 나머지 0)
- ⑥ 마이그레이션 dry-run — **대상 0건**. 운영에 0% 매장이 없어 실행 불필요
- ⑦ 라이브 검증
  - 비상 정지 토글 쓰기 **거부 없음**, 이력에 `변경자` 기록 (2차 F3 수정분이 실제로 동작)
  - 브랜드 5% 저장 → 산하 매장이 `브랜드 상속 5%` 로, 나머지 6곳은 `전역 3%` 유지
    → **F1(브랜드 단계가 한 번도 적용되지 않던 결함) 라이브 증명**
  - 이력에 누가/언제/범위/before→after/일괄 영향 범위가 전부 기록
  - 원상복구까지 확인 (ChaCha → 상위 설정 따르기)
- 미확인 1건: 점주의 **브랜드 전환**(D1 `claimSubmittedBrand`) 라이브 경로.
  `flow.test.mjs` 가 전 구간을 덮지만 실물로는 지나보지 않았다.

### 발견한 문구 버그

`지금 적용되는 값` 블록의 `브랜드은 설정 없음` — 조사 오류(`브랜드는`). 정리 커밋 때 수정.
