# web_role_console 테스트 리포트

- 작성: tester / 2026-10-29
- 대상: `landing/console/` (커밋 0619951 `web_role_console`) · 기준: `spec.md`(§5·§6·§18) / `design.md`(§15~17.1) / `implementation.md`
- 검증 환경: `firestore.rules` **859줄 현재 파일** + Firestore 에뮬레이터(`demo-*` 프로젝트 ID) + jsdom(가짜 데이터 계층)
- **운영 Firestore 쓰기 0건 · 운영 Cloud Function 호출 0건 · 배포 0건 · 커밋 0건 · 코드 수정 0건.** (`git status`: 이 리포트 외 변경 없음. `.firebaserc`·`docs/tasks/temporary_closed_gate/` 는 다른 세션의 미추적 파일)
- 테스트 스크립트는 전부 저장소 밖 scratchpad: `/private/tmp/claude-503/-Users-Byeonguk-Developer-OrderApp/c133e8b0-27b6-490e-afeb-77a7d2e2f96b/scratchpad/rc/`

## 0. 요약

| 구분 | 건수 |
|---|---|
| 요청 항목 28개 | **PASS 28 / FAIL 0 / 미검증 0** (단, 일부 PASS 에 범위 단서가 붙는다 — 해당 항목에 명시) |
| 추가 발견 | **FAIL 1 (F1, 데이터 의존·중간)** · 관찰 5 (O1~O5) |
| 이번 세션에 직접 돌려 재현한 것 | 기존 `rc/integ` 88건 · `rc/dom` 88건 · `rc/dom2` 29건 · `rc/unit` 47건 전부 재현 + 독립 작성 Rules 매트릭스 79건 + DOM 프로브 27건 + 가드 310 조합 + legacy 매장 재현 |
| 판정 | **조건부 GO** (§4) |

핵심: 요청한 🔴 `approvedAt` 보호(항목 6~8)는 에뮬레이터에서 **세 경로 모두 통과**했다. 다만 **"승인(approved) 인데 `approvedAt` 이 없는 legacy 매장"** 에서는 콘솔이 "영업은 그대로 계속됩니다" 라고 안내한 뒤 실제로는 `canSellNow` 가 false 가 되는 경로가 있다(F1, 앱도 동일 동작).

---

## 1. 요청 항목별 결과

### 역할 판정 (DV-3)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | `users/{uid}` 읽기 실패 → fail-closed, 데이터 요청 0건 | **PASS** | `t_dom` : `permission-denied` / `timeout` / `unavailable` 3종 모두 셸 없음 + 데이터 호출 0건 + customer 화면 안 열림. 실제 `readUserRole` 은 타 계정 문서 읽기에서 `permission-denied` throw (`rc/integ`). 코드 `console-shell.js checkRole` catch → `renderRoleFail` |
| 2 | 문서/`role` 필드 부재 → `customer`(1번과 구분) | **PASS** | 실제 `classifyRoleDoc` : `exists:false`→`ok/customer(exists:false)`, `{}`→`ok/customer`, `{role:undefined}`→customer. 읽기 실패는 throw 라 별개 경로. 에뮬레이터에서 실제 `users` 문서 부재/필드 부재 모두 확인(`rc/integ`) |
| 3 | 모르는 `role` 문자열 → 5초 자동 로그아웃 | **PASS** | `''`, `'Admin'`(대소문자), `123`, `null`, `'superadmin'` 전부 `kind:'unknown'`. jsdom 에서 5초 후 `signOut` 1회 + 로그인 화면에 안내 문구 (`rc/dom`) |
| 4 | customer 는 자동 로그아웃되지 않는다 | **PASS** | customer 셸에서 5.4초 대기해도 `signOut` 0회 (`rc/dom`) |
| 5 | 역할 변경은 폴링 없이 `permission-denied` 계기 | **PASS** | `permission-denied` → `users` 재확인 1회 → 역할이 바뀌면 셸 재구성 + "권한이 바뀌었어요" 안내, 같으면 평범한 실패 (`rc/dom`). 셸이 열린 채 5.5초 대기 시 `readUserRole` 추가 호출 0 (`t_dom`) |

### 🔴 `approvedAt` 보호 (DV-5)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 6 | 점주 핵심 수정 후 `approvedAt` 보존 → `canSellNow` true | **PASS** | 독립 매트릭스 : `stores/s2`(approved) `owner.storeCore` 후 `status:'pending'`, `approvedAt`/`approvedBy` 원값 보존. pending+approvedAt 재수정도 보존. 첫 승인 대기(approvedAt 없음)는 `approvedAt` 키가 생기지 않음 (`rc/integ`). ⚠️ **전제: 서버에 이미 `approvedAt` 이 있을 때.** 없으면 F1 |
| 7 | `rejected` 재제출 payload 는 서버 재읽기로 `rejected` 확인 시에만 | **PASS** | 코드 : `console-data.js submitStoreCore` 가 `runTransaction` 안에서 `tx.get` → `cur.status === 'rejected'` 일 때만 `storeCorePayload(..., {resubmit:true})`. 이 함수 외에 `resubmit`/승인 메타 키를 만드는 곳은 없다(grep). 에뮬레이터 : rejected 매장 재제출 → pending + 메타 4개 null. 점주가 `status` 만 pending 으로 되돌리는 우회는 Rules 가 거부 |
| 8 | 화면은 `rejected` 인데 서버는 이미 `approved` → 쓰지 않고 state-changed | **PASS** | `rc/integ` "화면은 rejected 로 알지만 서버는 approved" : 쓰기 0건 + `state-changed`. DOM : 모달 유지 + "매장 상태가 바뀌었어요" + 새 갈래 문구, 자동 진행 없음 |

### payload 가드 (spec §6)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 9 | 전역 금지 집합 액션 무관 상시 검사 | **PASS** | `t_guard` : 31개 액션 × 10키(Qoin 5 + `availableMainCategories` `averageScore` `reviewCount` `qoinBalance` `brandKey`) = **310 조합 전부** "전역 금지" 메시지로 throw. 어느 액션의 `allowed` 에도 이 키들이 없음. (구현은 `role` 도 추가로 금지) |
| 10 | `exact`/`subset` 이 액션에 맞는가 | **PASS** | `exact` : admin 4 · `owner.storeCoreResubmit` · `owner.overrideCreate`(16키) · `overrideSoldOut`(3) · `overrideOptionDisable`(4) · `activeToggle` 2. `onlyChangedFields` 액션(owner.storeOperation/storeCore, brand.* 핵심·운영, personalMenu*)은 전부 `subset` + `required`. Rules 거동과 대조(매트릭스에서 부분집합 payload 가 실제 통과) |
| 11 | 브랜드 경로 payload 에 `approvedBy`/`approvedAt` 키 없음 | **PASS** | 모든 `brand.*` 액션의 `allowed` 에 두 키 없음 + `forbidden` 에 `APPROVAL_META`. 두 키를 넣으면 전 액션 throw (`t_guard`). 에뮬레이터 : 브랜드 핵심/마스터 핵심/오버라이드 제출 후 승인 메타 보존 |
| 12 | `selectionType` 은 `'multi'` | **PASS** | 폼 `console-forms.js:389,397` 은 `single`/`multi` 만 생성. 가드가 `multiple` 거부(owner/brand 둘 다). 앱 `option_selection_type.dart` `'multi'`, 서버 `optionPricing.ts:78` 확인 |
| 13 | 오버라이드 create 에 `masterMenuItemId` | **PASS** | 점주 create 16키(exact) / 브랜드 create 12 required 모두 포함, 빠지면 throw. 에뮬레이터에서 필드 존재 확인 |

### Rules 통과 (에뮬레이터, 859줄 파일)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 14 | spec §5 매트릭스 각 역할·액션이 Rules 통과 | **PASS** | 독립 매트릭스(`t_matrix`, 콘솔 데이터 계층을 거치지 않고 `console-payloads.js` 빌더 + 원시 SDK): brand 15 액션 · owner 11 액션(12 중 activeToggle 제외) · admin 3 액션 전부 `ok`. 기존 `rc/integ` 88건도 동일. `payloads.js` 의 `rules:` 줄번호를 859줄 파일과 대조 — 578-604 / 641 / 522-526 / 363-366 / 386-421 / 621-626 / 646-658 / 483-490 모두 실제 위치와 일치 |
| 15 | 브랜드 자기 승인 거부 | **PASS** | pending 문서를 시드한 뒤 : 마스터 `status:'approved'` · 브랜드 문서 `status:'approved'` · 오버라이드 `status:'approved'` · create 에 `status:'approved'` / `approvedAt` 값 · `approvedBy`/`brandKey` 변경 · `approvedAt` 서버타임스탬프 덮어쓰기 — 전부 `permission-denied` |
| 16 | 타 역할/타 소유자의 남의 리소스 쓰기 거부 | **PASS** | 타 브랜드 보유자(마스터/오버라이드/private), 타 점주(`s1` 운영, 개인메뉴), customer(마스터/매장/브랜드/`role` 승격/`qoinBalance`), `users` 문서 없는 계정, owner 의 마스터 삭제·`stores` 삭제, 점주의 `averageScore`/`qoinAccrualRate`/`availableMainCategories`/`ownerId`/`approvedAt` 값/`priceOverride` — 전부 거부. admin 도 Qoin 필드 불가 |
| 17 | Rules 문서 접근 예산 (cascade 청크 8) | **PASS (재현) · 일반화 불가** | 에뮬레이터 재실측 : 서로 다른 매장 **8~18곳 한 배치 삭제 → ok, 19곳 → permission-denied** (구현 기록의 "12 ok/19 거부"와 일치하며 경계는 18/19 로 더 좁혀짐). 한 배치 = `n`개 매장 `get()` + 공통 `users` 1회 ≈ n+1 ≤ 20 이라는 해석과 맞다. 청크 8 → 접근 약 9회로 여유 11. **⚠️ 이것은 에뮬레이터(cloud-firestore-emulator 1.19.8) 값이다. 운영 서버가 같은 계수를 쓴다는 보장이 없고, 운영에서는 확인하지 않았다(운영 쓰기 금지).** 안전 여유는 크지만 운영 첫 cascade 삭제는 소수 매장 브랜드로 먼저 해야 한다 |

### 안전한 UI 동작

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 18 | 낙관적 UI 없음 | **PASS** | 지연 promise 로 응답 전 상태 확인 : owner 운영 저장(해시/토스트 불변, 버튼 "저장 중…") · owner 품절·노출 스위치 · **brand 마스터 노출 스위치**(응답 전 `aria-checked` 불변, 응답 후 변경) |
| 19 | 실패 시 입력 보존, 항목 유지 | **PASS** | 운영 폼 거부 → 입력 보존+해시 유지 · 마스터 핵심 제출 거부 → 입력 보존 · 오버라이드 제출 거부 → 가격 입력값 보존·행 유지·성공 토스트 없음 · 스위치 실패 → 불변 |
| 20 | DOM 에서 비활성화 강제 해제 → Rules 가 거부, 성공 표시 없음 | **PASS (UI 가드는 편의일 뿐임을 확인)** | (a) 변경 없는 운영 폼 저장 버튼 강제 활성화 → 핸들러가 자체 차단(쓰기 0). (b) 마스터 삭제의 이름 입력 확인 강제 우회 → 쓰기 시도 → 서버 거부 시 성공 토스트 없음·항목 유지. (c) 에뮬레이터 : customer 가 `submitBrandCore` 호출 → `permission-denied` (`rc/integ`). 단 O1 참조 — 강제 클릭하면 U6 "현재 가격 못 읽음" 가드를 **우회해 정상 제출 write 가 나간다**(권한 있는 계정의 합법 write 이므로 Rules 로는 막지 않는다) |
| 21 | 건수·목록 로드 실패를 0/빈 목록으로 표시하지 않음 | **PASS** | admin 건수 `permission-denied`/`unavailable` → 배지 "0" 아님·카드 재시도 버튼·"모두 처리" 문구 없음(성공한 0 은 0). owner 메뉴/서브카테고리, brand 마스터/산하 매장 목록 실패 → 오류 블록(빈 상태 문구 아님). 매출 실패는 0원 아님(`rc/dom`) |

### 문구 (design §17.1)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 22 | 마스터 핵심 수정 안내 문구, 매장 문구와 비혼합 | **PASS** | `section-brand.js:619` "수정하면 관리자 승인 전까지 고객 메뉴 목록에 보이지 않습니다. 이미 장바구니에 담긴 주문은 결제될 수 있습니다." — §17.1 확정 문구와 일치. 이 모달에 "영업과 주문은 그대로" 없음(DOM 단언). 반대로 매장 핵심 모달(`section-owner.js:428`)만 "영업과 주문은 그대로 계속됩니다" 사용. 브랜드 핵심 폼·점포 한정 메뉴 모달은 노출 영향을 단정하지 않음 |
| 23 | 오버라이드 재제출 모달 현재 적용가 → 재제출 중 적용가 | **PASS** | `section-brand.js:739-743` : "현재 적용가 ₩3,000 → 재제출 중 적용가 ₩4,500" 나란히 + "기준 가격으로 판매됩니다…" + 인상 시 경고 + 제외 오버라이드는 "다시 보입니다". 승인 오버라이드가 없으면 일반 문구. 현재 상태를 못 읽으면 확정 비활성 |
| 24 | 숨김을 보안으로 묘사하는 문구 없음(주석 포함) | **PASS** | `숨김/미노출 ↔ 막/차단/보호/안전/통제` 근접 패턴 grep 0건. 각 섹션 머리 주석은 모두 "숨김·탭 미노출은 **편의**이며 권위는 Rules" 로 반대 방향. 화면 문구의 "숨겨져요/숨김" 은 고객 노출 의미 |

### 범위·회귀

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 25 | 금지 UI 없음 | **PASS** | `brand`/`owner`/`customer` 섹션에 승인·반려 컨트롤 없음(DOM 단언). 데이터 계층의 쓰기 지점 전수(`updateDoc/setDoc/deleteDoc/batch/tx`) 열거 — `users`·`orders` 쓰기 0건, 역할 부여 코드 0건, 모든 payload 쓰기는 `assertPayload` 경유. 점주 주문 접수/제조/완료 화면 없음. 에뮬레이터 : owner 의 `orders` 상태 쓰기도 거부 |
| 26 | 랜딩 4페이지 그대로 | **PASS** | `git diff 0619951~1 HEAD -- landing/index.html terms.html privacy.html refund.html landing/assets` 빈 결과, 작업 트리 변경 없음 |
| 27 | `firebase-config.js` 무변경 | **PASS** | 같은 범위 diff 빈 결과(마지막 변경은 `1a99664` 이관 커밋) |
| 28 | Functions 리전 명시 · SDK 고정 | **PASS (정적 확인)** | `getFunctions(app, FUNCTIONS_REGION)`, `FUNCTIONS_REGION='asia-northeast3'`(functions/src 의 리전과 일치). `httpsCallable` 호출은 `issueBrandKey`·`claimSubmittedBrand` 2곳. gstatic URL 5개 모두 `10.14.1` 고정, 범위 표기 없음. **CF 는 호출하지 않았다**(스텁으로 리전 전달만 확인) |

---

## 2. 결함 / 관찰

### F1 — FAIL (중간, 데이터 의존) : "approved + `approvedAt` 없음" 매장은 핵심 수정 후 영업이 멈춘다

- **재현** (에뮬레이터, `t_legacy.mjs`): `stores/x = {status:'approved', ownerId:o1}`(approvedAt 없음) 또는 `status` 자체가 없는 매장에 대해 `submitStoreCore(id,{name:'새이름'},'A')` 호출.
  - 결과: 둘 다 갈래 **A** 로 분류됨 → 쓰기 성공 → `status:'pending'`, `approvedAt` 없음 → 서버 `canSellNow`(`status==approved || (pending && approvedAt!=null)`) = **false**.
- **원인**: `console-format.js storeSellClass` 가 `status==='approved'` 면 `approvedAt` 유무와 상관없이 `'A'`("영업·주문 계속")로 분류한다. `canSellNow` 는 approved 는 `approvedAt` 없이 통과시키지만, **pending 으로 회귀하면 `approvedAt` 이 반드시 있어야** 한다.
- **영향**: 모달이 "영업과 주문은 그대로 계속됩니다" 라고 거짓 안내하고, 실제로 그 매장은 관리자 재승인 전까지 결제가 거절된다. 이 콘솔이 우려하던 "승인 매장이 영업을 멈춘다" 시나리오와 동일한 결과다.
- **조건**: 운영 데이터에 이런 매장이 남아 있을 때만 발생. `migrateStoreApprovalMeta`(M1 백필)가 실행되었다면 0건이다. **운영 데이터는 읽지 않았으므로 실제 해당 여부는 미확인.** 앱의 점주 핵심 수정도 같은 동작이라 콘솔이 만든 회귀는 아니다.
- **제안(코드 수정은 하지 않음)**: `approved && !approvedAt`(및 `status` 부재)를 `'X'`/별도 갈래로 분류해 쓰기를 막고 "관리자에게 문의" 로 안내하거나, 출시 전 관리자가 M1 dry-run 결과(`willBeRejected`)가 0 임을 확인.

### 관찰 (결함 아님)

- **O1** — UI 가드는 UX 일 뿐이다. U6 "현재 가격을 못 읽으면 제출 불가" 와 삭제의 이름 입력 확인은 DOM 에서 풀면 우회된다(강제 클릭 시 `submitPriceOverride(priceOverride:null,…)` 호출 확인). 해당 쓰기는 권한 있는 브랜드 보유자의 정상 pending 제출이라 Rules 가 허용한다. 즉 **U6 "기준 가격으로 판매" 경고를 보지 않고 제출하는 것은 기술적으로 가능**하며 비용은 사용자 본인의 가격 변경에 한정된다.
- **O2** — Rules 의 기존 격차(콘솔 범위 밖): `stores/{sid}/menuItems` 는 `isStoreOwner(storeId)` 분기가 무제한이라 **가맹 매장 점주가 점포 한정 메뉴를 `status:'approved'` 로 직접 만들 수 있다**(`firestore.rules:483-490`, 주석에 "별도 task (D2)"). 콘솔은 가맹 매장 점주에게 이 UI 를 노출하지 않는다(코드·DOM 확인). 규칙 코드 판독이며 이 항목은 에뮬레이터로 실행하지 않았다.
- **O3** — implementation 의 "값 보존에 의존하면 Timestamp 왕복에서 거부" 는 부정확하다. 에뮬레이터에서 읽은 `approvedBy`/`approvedAt` 을 **동일 값 그대로** 재전송하면 통과하고, **`serverTimestamp()` 로 덮거나 다른 값**이면 거부된다. 콘솔은 두 경우 모두 키를 보내지 않으므로 영향 없음. 문서 정정 권고.
- **O4** — 에뮬레이터 실행 환경 : Java 17 이라 `firebase emulators:exec` 불가, 캐시된 jar 를 직접 실행해야 하고 **`LANG=C.UTF-8` 로케일에서는 Rules 평가 오류 메시지 생성이 죽어 쿼리 테스트가 timeout** 된다(`-Duser.language=en -Duser.country=US` + `LANG=en_US.UTF-8` 필요). 이번에도 그대로 재현됨 — implementation §10-9 와 일치.
- **O5** — 사용자 지시문의 `landing/console/console.css` 는 실제로 `landing/console/assets/console.css` 이다(결함 아님).

---

## 3. 미검증 (PASS 로 쓰지 않음)

| 항목 | 사유 |
|---|---|
| 실제 브라우저(Chrome/Safari)에서의 동작, `color-mix`·ES 모듈 호환 | jsdom 만 사용. 운영 Firebase 로 로그인 금지 |
| 실제 Firebase Auth 로 4개 역할 계정 로그인 끝-끝 | 운영 프로젝트 접근 금지 |
| **운영에 배포된 Rules 가 로컬 `firestore.rules`(859줄) 와 동일한가** | 운영 조회 안 함. 이번 모든 Rules 검증은 로컬 파일 기준 |
| 운영 서버 Rules 접근 예산 계수(항목 17) | 에뮬레이터 값만 확인 |
| 운영 데이터의 legacy 매장(F1) 실재 여부 | 운영 데이터 미조회 |
| `issueBrandKey` / `claimSubmittedBrand` 실제 호출 | 운영 CF 호출 금지. 스텁으로 호출 인자·리전만 확인 |
| 이미지 업로드(5MB 상한, Storage) · 매출 숫자의 앱 대조(KST 경계) | 요청 범위 밖이며 실데이터/Storage 필요 (jsdom 에서는 집계 로직만 통과) |
| 스크린리더 접근성 | implementation §10-8 에서도 미검증 |
| `firebase.json` `/console` rewrite | 미적용(읽기 전용 세션이었음). 현재는 `/console/index.html` 로만 접근 |

---

## 4. 판정 : 조건부 GO

**근거**: 요청한 28개 항목이 모두 에뮬레이터(현재 859줄 Rules) 또는 jsdom 에서 재현되었다. 🔴 `approvedAt` 보호는 세 경로(서버 재읽기 / state-changed / 브랜드 경로 키 부재) 모두 통과했고, 브랜드 자기 승인·타 역할 교차 쓰기·점주 평점/Qoin/승인 메타 조작이 Rules 에서 일관되게 거부된다. 모든 쓰기가 `assertPayload` 를 거치고 `users`/`orders` 에 쓰는 코드는 없다. 랜딩과 `firebase-config.js` 는 무변경이다. 다만 F1 과 미검증 항목(실브라우저·운영 Rules 동일성)이 남아 무조건 GO 는 아니다.

**조건 (출시/링크 공개 전)**
1. **F1 해소 중 하나** : (a) `migrateStoreApprovalMeta` dry-run 으로 운영에 `status:'approved' && approvedAt 없음` 및 `status 부재` 매장이 0건임을 관리자가 확인(읽기 전용), 또는 (b) developer 가 `storeSellClass` 에서 approved 이지만 `approvedAt` 이 없는 매장을 갈래 A 에서 제외하고 쓰기를 막는 수정을 하고 tester 가 재검증.
2. **배포된 Rules == 로컬 859줄 확인** (diff 또는 배포 이력 확인). 같지 않으면 이번 Rules 검증은 무효.
3. **실제 브라우저 + 실제 계정 스모크** : 처음에는 **읽기 전용 화면만** (역할 판정·타 역할 해시·customer 체류). 쓰기 스모크는 데이터를 오염시켜도 되는 계정·매장 하나로 한정하고, 최초 cascade 삭제는 산하 매장이 적은 브랜드에서 한다(항목 17 단서).
4. `landing` 에서 콘솔로 링크하지 않는 현 상태(PG 심사 전)를 유지.

**후속 후보** : O3 문서 정정 · O2 `stores/menuItems` 점주 분기 자가승인 차단(별도 Rules task) · F1 수정 후 재검증.

## 5. 재현 방법

```
# 에뮬레이터 (Java 17, 영어 로케일 필수)
cd <scratchpad>/emu && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 java -Duser.language=en -Duser.country=US \
  -jar ~/.cache/firebase/emulators/cloud-firestore-emulator-v1.19.8.jar --host=127.0.0.1 --port=8172
# 테스트 (scratchpad/rc)
node build.mjs && node build-dom.mjs
FIRESTORE_EMULATOR_HOST=127.0.0.1:8172 node integ.test.mjs        # 88 PASS
FIRESTORE_EMULATOR_HOST=127.0.0.1:8172 node t_matrix.test.mjs     # 68 PASS (독립 Rules 매트릭스)
FIRESTORE_EMULATOR_HOST=127.0.0.1:8172 node t_matrix2.test.mjs    # 11 PASS
FIRESTORE_EMULATOR_HOST=127.0.0.1:8172 node t_budget.mjs          # 8~18 ok / 19 denied
FIRESTORE_EMULATOR_HOST=127.0.0.1:8172 node t_legacy.mjs          # F1 재현
node dom.test.mjs; node dom2.test.mjs; node unit.test.mjs; node t_dom.test.mjs; node t_guard.mjs
for f in landing/console/assets/*.js; do node --input-type=module --check < $f; done   # 12개 파일 문법 OK
```
