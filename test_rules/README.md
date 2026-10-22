# Firestore Rules 검증 하네스

리포지토리 루트의 `firestore.rules` 를 로컬 Firestore 에뮬레이터에 올려 실제로 allow / deny 를 확인한다.
Firebase Console 의 Rules Playground 는 **제거되어** (`개발 및 테스트` 버튼이 Cloud Shell 튜토리얼로 연결됨) 더 이상 쓸 수 없으므로, Rules 변경 시 이 하네스로 검증한다.

## 실행

```
cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm install
cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test
```

`npm install` 은 최초 1회만 하면 된다. 종료 코드 0 이면 전건 PASS, 1 이면 실패 케이스가 출력된다.

## 전제 조건

- **JDK 17 이상.** `firebase-tools@15` 부터 JDK 21 을 요구하므로 하네스는 **14 로 고정**했다.
  JDK 21 이상으로 올린 뒤에는 `package.json` 의 `firebase-tools@14` 를 올려도 된다.
- 에뮬레이터 포트는 루트 `firebase.json` 의 `emulators.firestore.port` (8137) 를 따른다.
- 네트워크 없이 동작한다. 실제 Firestore 를 건드리지 않는다.

## 케이스

> 2026-10-22 기준 **341건** (`npm test` 출력이 단일 진실원). 아래 표는 최초 12건이다.
> Qoin 적립률 계층화(`RH*`)는 `docs/tasks/qoin_accrual_rate_hierarchy/spec.md` §9 의 쓰기 경로 12개(P1~P12)를 1:1 로 케이스화했다 —
> admin 전권 분기와 create 경로까지 포함한다 (1차 F1: 보호가 update 에만 있었다).

`rules.test.mjs` 참조. 2026-10-21 기준 12건.

| # | 시나리오 | 기대 |
|---|---|---|
| R1 | 타인 doc `notificationSettings` update | deny |
| R2 | 본인 doc `notificationSettings` update | allow |
| R3 | 본인 doc `notificationSettings` 2키 동시 | allow |
| R4 | 본인 doc `uid` 변경 (immutable) | deny |
| R5 | 본인 doc 화이트리스트 밖 필드 추가 | deny |
| R6 | 타인 doc read | deny |
| R7 | 본인 doc read | allow |
| R8 | 본인 doc `fcmToken` update | allow |
| R9 | 본인 doc `notificationPermissionLaterCount` increment | allow |
| R10 | 본인 doc `notificationPermissionPrompted = true` | allow |
| R11 | 타인 doc `laterCount` increment | deny |
| R12 | 본인 doc `laterCount` + `role: 'admin'` 동반 | deny |

R12 는 화이트리스트를 통과하는 필드에 금지된 role 전이를 끼워 넣는 **우회 시도**다.

## 케이스 추가

`rules.test.mjs` 의 `run(이름, 'allow' | 'deny', () => 작업)` 한 줄을 추가하면 된다.
`firestore.rules` 를 고칠 때는 **해당 경로의 deny 케이스를 함께 추가**한다 — allow 만 늘리면 권한이 넓어진 것을 잡지 못한다.

## RM 스위트 — 역할 변조 (brand_authorization_hardening §5)

불변식: **"프로필을 바꿔서 얻을 수 있는 권한은 없다."** `RM01~RM20` 및 변형 42건 (+ `RM-D2` 정상 흐름 11개 호출 지점, `FLOW` 3, `RHIST` 8, `EC` 7).

작성 규칙 (하네스 구조 요구):

- 케이스마다 `users/{uid}` 를 **그 케이스 안에서** 쓰고 (`rmUser()`) 보호 대상을 때린다. 고정 시드 사용자를 재사용하지 않는다 — `RH20` 이 고정 시드만 써서 `role=brand` + `brandId` 없음 경로를 놓쳤다.
- DENY 케이스는 Admin SDK(`withSecurityRulesDisabled`, `rmForce()`)로 **변조 상태를 강제 주입한 뒤 하위 권한을 다시 때린다.** "Rules 가 막으니 그 다음은 볼 필요 없다" 는 가정이 사각의 원인이었다.
- `RM07` (brandId **필드가 없는** 매장 × brandId 없는 brand 계정 → DENY) 은 `isBrandHolder` 의 `brandId is string && brandId != ''` (D2) 의 회귀 핀이다. 검증: `RULES_FILE=<D2 를 뺀 rules> npm test` 로 돌리면 RM07/RM07b/RM09/RM09c/RM10/RM10b 가 ALLOW 가 되어 FAIL 한다.
- `RM18` (approved 남의 브랜드 지정 → ALLOW) 은 의도다 — Rules 는 가맹 관계를 증명할 수 없다(`brandKey` 가 공개). 통제는 admin 승인이다.

`RULES_FILE` 환경변수로 다른 Rules 파일을 올려 mutation 검증을 할 수 있다 (기본은 루트 `firestore.rules`).

## 전환 전 구간 통합 (`flow.test.mjs`)

```
cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm run test:flow
```

Rules(클라이언트 SDK)와 Cloud Function(`claimSubmittedBrand`, Functions 에뮬레이터)을 같은 에뮬레이터 세션에서 이어서 호출해 점주/고객 → 브랜드 전환 9단계를 처음부터 끝까지 한 번 돈다. (functions 빌드 포함, 약 1분.)
