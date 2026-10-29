# web_role_console 구현 기록

- 작성: developer / 2026-10-29
- 입력: `spec.md`(§18 결정 + Q3 정정) · `design.md`(DV-1~24, U1~U11, §17.1 U5·U6 확정 문구) · `docs/tasks/web_admin_console/{design,implementation}.md`
- **Flutter 코드가 아니다.** 산출물은 `landing/console/` 의 정적 웹(HTML/CSS/바닐라 JS). 빌드 단계·npm 없음. `lib/` · `functions/` · `firestore.rules` · `firebase.json` · `landing/` 의 랜딩 4페이지 · `landing/assets/` **무수정**(`git status` 로 확인).
- 운영 Firestore 쓰기 · CF 운영 호출 · 배포 · 커밋: **하지 않음.** Rules 검증은 에뮬레이터(`demo-*` 프로젝트 ID)로만.

---

## 0. 먼저 읽을 것 — 구현 중 발견한 사실 (spec/design 정정 포함)

| # | 발견 | 처리 |
|---|---|---|
| **F1** | **`firestore.rules` 가 825줄 → 859줄로 바뀌었다** (커밋 b87b548 `brand_self_approve_guard`, 배포 완료). 브랜드 분기에 `noSelfApproveOnCreate/Update` 가 `brands/{id}/menuItems` · `stores/{sid}/menuItems`(브랜드 분기) · `stores/{sid}/menuOverrides`(브랜드 분기)에 걸렸다. spec §5 의 "브랜드 보유자 분기는 제한 없음" · X2 는 **낡았다**. | 줄번호를 **859줄 기준으로 전부 다시 읽어** `console-payloads.js` 의 `rules:` 상수에 넣었다. 브랜드 경로 payload 에 `approvedBy`/`approvedAt` **키를 아예 넣지 않는다**(변경분만 담은 좁은 payload). 에뮬레이터 검증도 **현재 파일로** 돌렸다. |
| **F2** | **존재하지 않는 문서에 `updateDoc` 하면 `not-found` 가 아니라 `permission-denied`** 가 온다(Rules 의 `resource.data` 평가 오류 — 에뮬레이터 실측). spec W-O8 의 "`updateDoc` 먼저 → `not-found` 면 create" 는 **동작하지 않는다.** | upsert 는 **트랜잭션(읽기 → 있으면 update / 없으면 create)** 으로 구현(`upsertTx`). stale read 로 create 분기를 타는 레이스(ⓕ)도 같이 막힌다. |
| **F3** | **매장 옵션 그룹 `selectionType` 은 `'multiple'` 이 아니라 `'multi'`** 다. 앱은 브랜드/매장 모두 `OptionSelectionType.asString` 의 `'single'|'multi'` 를 쓰고, 서버 `functions/src/optionPricing.ts:78` 은 `"multi"` 가 아니면 전부 `single` 로 읽는다. spec §16 · W-O9 의 "매장 `multiple`" 은 오기다. | `'multiple'` 을 쓰면 체크아웃에서 **조용히 단일 선택으로 바뀐다.** 가드(`owner.optionGroup` 불변식)가 `multiple` 을 거부한다. |
| **F4** | 마스터 메뉴 삭제 cascade 의 컬렉션 그룹 쿼리(`where masterMenuItemId ==`)는 **단일 필드 컬렉션 그룹 인덱스가 `firestore.indexes.json` 에 없다.** 또 점주 생성 오버라이드는 그 필드가 없는 경우가 있다(ⓑ). | **오버라이드 문서 ID = `masterMenuItemId`** 임을 이용해 **산하 매장별 문서 ID 조회**(`stores where brandId==X` 단일 필드 + 문서 get)로 대상을 찾는다. 인덱스 불필요, 필드 누락 문서도 찾아진다. |
| **F5** | 옵션 그룹 사용 수의 컬렉션 그룹 `arrayContains optionGroupRefIds` 쿼리도 복합 인덱스 보장이 없다. | 브랜드/매장 메뉴를 읽어 **클라이언트에서 센다**(`countOptionGroupUsage`). 하나라도 읽기 실패하면 삭제를 막는다. 서브 카테고리는 `fieldOverrides` 에 컬렉션 그룹 인덱스가 있어 `getCountFromServer` 사용. |
| **F6** | 앱 매장 **핵심 폼**은 `menuCategories` 를 더 이상 수정하지 않는다(deprecated, "기존 값 보존만"). design §9-2 의 카테고리 체크 칩은 앱과 어긋난다. | 앱을 따랐다(DV-13 "앱과 동일"): 핵심 폼 = **매장명 · 사업자등록번호**, 주소·위치는 읽기 전용(U1). `menuCategories` 는 payload 에 없다. |
| **F7** | `users/{uid}/orderLogs` 문서에는 **`status` 필드가 없다**(`order_log_model.dart`). design CU2 의 "상태" 열은 근거가 없다. | 열 구성을 실제 필드로 확정: 주문 일시 · 매장 · 주문 내용 · 금액 · 결제 수단 (DV-15 "없는 열은 뺀다"). Qoin 거래: 일시 · 구분 · Qoin · 잔액 · 매장. |
| **F8** | `firebase.json` 은 이 세션 읽기 전용이라 spec §12 의 `/console` rewrite 를 **추가하지 않았다.** | 안내 주소는 `/console/index.html`. rewrite 추가는 사용자 몫(§7). |
| **F9** | 평균 점수 표기: `grade_min_reviews`(커밋 fa08df5) 의 `docs/tasks/grade_min_reviews/design.md:47` 이 **점주 `my_store_page` 는 "현행 유지"** 라고 정했다. 점주 화면은 리뷰 0건이면 `미평가`/`-`, 아니면 `{S|A|B|C}급` + 평균(소수 1자리)이다. 3건 게이팅(`isGraded`)은 **고객 화면 규칙**이다. | `ownerScoreView()` 가 `my_store_page.dart:754-776` 과 같은 규칙. 임계값을 새로 정하지 않았다. |
| **F10** | 앱 `OptionItemListEditor` 가 새 항목 ID 를 `new_{millis}` 로 **영구 저장**한다. | 같은 형식 + 카운터 접미사(같은 ms 충돌 방지)로 따랐다. |
| **F11** | 점주 오버라이드 5키 화이트리스트에는 **품절과 `disabledOption*` 를 같이 보내는 것도 Rules 상 허용**된다(에뮬레이터 실측). 앱 결함 ⓐ(옵션 비활성이 지워짐)는 Rules 가 아니라 앱의 payload 선택 때문이다. | 콘솔은 품절 3키/옵션 4키를 **exact 모드 가드**로 분리했다. |

---

## 1. 구현 파일 목록 · 역할

`landing/console/` (이전 파일 수정 + 신규):

| 파일 | 상태 | 역할 | 줄 수(대략) |
|---|---|---|---|
| `index.html` | 수정 | `<title>` 「Qradar 콘솔」, 주석의 `/admin/index.html` → `/console/index.html`, 셸 설명 | 28 |
| `assets/console.js` | **교체** | 진입점(`console-shell.js` 의 `boot()` 만 호출). 이전 1,240줄은 아래 3파일로 분할 | 8 |
| `assets/console-shell.js` | 신규 | 로그인 · 역할 판정 게이트(G0~G3) · 역할별 셸 · 해시 라우터(replace 정규화) · N15 이동 확인 · **역할 변경 복구(C4/G5)** | ~330 |
| `assets/console-ui.js` | 신규 | 공용 상태 `S` · 위젯(skel/banner/empty/error/badge/thumb/kv/table) · 목록 로더 · **대화상자(`openDialog`)** · 폼 빌더(field/switch/saveBar/changeList) · `onReadFail` | ~420 |
| `assets/console-forms.js` | 신규 | **메뉴 폼**(섹션 토글로 등록/핵심/운영/개인 공용) · **옵션 비활성 대화상자** · **서브 카테고리/옵션 그룹 목록+편집+삭제** | ~420 |
| `assets/console-data.js` | 수정 | SDK 접근(SDK import 는 이 파일만, **10.14.1 고정**, Storage import 추가). `readUserRole` → `{kind, exists, role, brandId}`. owner/brand/customer 읽기·쓰기 함수 추가 | ~800 |
| `assets/console-payloads.js` | **재작성** | 역할별 shape(`mode`/`allowed`/`required`/`forbidden`/`invariants`/`rules`) + 전역 금지 집합 상시 검사 + 빌더. admin 4개는 필드 집합 그대로 | ~520 |
| `assets/console-format.js` | 수정(추가) | 역할 판정 순수 함수 `classifyRoleDoc` · KST 매출 기간/집계 · 3갈래 `storeSellClass` · `appliedOverride`(U6) · 점수/Qoin 해석 · 검증 상수 · `saveErrorText` | ~420 |
| `assets/section-admin.js` | 신규(이관) | 기존 admin 화면 A1~A9 + 승인/반려 모달을 **코드 그대로 옮김**. 네비 편입만 | ~830 |
| `assets/section-brand.js` | 신규 | GT1 게이트 · BR1~BR14 | ~620 |
| `assets/section-owner.js` | 신규 | GT3/GT4 · OW1~OW10 | ~560 |
| `assets/section-customer.js` | 신규 | CU1~CU3 + 준비 중 카드(테이블 주도, DV-20) | ~190 |
| `assets/console.css` | 수정(추가) | 스위치·저장 바·탭·변경 요약·U6 비교·준비 중 카드 등. **신규 색상값 0** | +160줄 |
| `README.md` | 수정 | 접근 주소 `/console/index.html`, 파일 표, 역할 설명 | |
| `assets/firebase-config.js` | **무변경** | | |

**섹션 인터페이스**(`section-*.js` 공통): `meta` · `navGroups()` · `contextHtml()` · `start()` · `stop()` · `afterNav()` · `match(parts, alive) → {key, run}`.
셸은 판정된 역할의 섹션만 `import()` 한다(`SECTION_LOADERS`). 이것도 **편의다 — 다른 역할의 코드를 내려받지 않는다는 것이 접근 통제는 아니다**(주석에 그렇게 적었고 보안으로 설명하지 않는다).

---

## 2. 기존 코드에서 바뀐 것

| 항목 | 이전 | 이후 |
|---|---|---|
| 역할 판정 | `readUserRole → {admin:boolean}`, 비admin 전부 `renderNotAdmin`(5초 자동 로그아웃) | `{kind:'ok'\|'unknown', exists, role, brandId}`. **읽기 실패 = fail-closed(G2) / 문서·필드 부재 = `customer` / role 이 있는데 모르는 값(null·''·숫자·대소문자 불일치 포함)만 G3(5초 자동 로그아웃)**. `renderNotAdmin` 제거 |
| 역할 변경 | 없음 | 폴링 없음. 섹션 읽기·쓰기가 `permission-denied` → `users/{uid}` **단일 비행 재확인(3초 재사용)** → role·brandId 가 달라졌으면 셸 재구성 + 닫을 수 있는 배너 「권한이 바뀌었어요. 화면을 다시 구성했어요. (점주 → Qrator)」 |
| `S.counts`/`loadAllCounts` | 셸 열면 무조건 | **admin 섹션 `start()` 에서만** |
| 라우터 | `else → #/dashboard` | 섹션별 `match`. 다른 역할 해시·알 수 없는 해시 → 자기 기본 화면으로 **`history.replaceState`** (히스토리 오염 없음). 주석에 「보안이 아니다」 명시 |
| `assertPayload` | 키 집합 정확 일치만 | `mode:'exact'\|'subset'` + `required` + `forbidden` + `invariants`(값 검사) + `rules`(줄번호를 데이터로). **전역 금지 집합 상시 검사**: Qoin 5 + `availableMainCategories` + `averageScore`/`reviewCount` + `qoinBalance` + `brandKey` (+ `role`). 이전 이름(`brandApprove` 등)은 별칭으로 호환 |
| 로그인 화면 문구 | 「Qradar 관리자 콘솔」 | 「Qradar 콘솔」 · 「계정으로 로그인하세요」 · 「Naver·Kakao 로 가입한 계정은 아직 웹에서 로그인할 수 없어요」 |
| `<title>` | 「Qradar 관리자 콘솔」 | 정적 「Qradar 콘솔」, 판정 후 「Qradar · {역할} 콘솔」 |
| admin 화면 | | 동작 변경 없음. `makeLoader` 가 공용으로 이동하며 permission 거부 시 역할 재확인을 거는 것만 추가 |

---

## 3. 액션별 실제 payload

> 모든 payload 는 `console-data.js` 가 전송 직전 `assertPayload(action, payload, {uid, brandId})` 를 통과시킨다. **가드는 개발 중 실수를 터뜨리는 방어선이지 보안이 아니다 — 권위는 Rules.**
> `TS` = `serverTimestamp()`, `DEL` = `deleteField()`. 줄번호는 859줄 `firestore.rules` 기준.

### 3.1 brand

| 액션 | 경로 / 방식 | 실제 payload 키 | Rules |
|---|---|---|---|
| `brand.brandOperation` (BR2) | `brands/{id}` batch update (+ private/profile 같은 배치, DV-14) | **바뀐 것만**: `companyName` · `logoUrl` · `updatedAt:TS`. **`name`/`description`/`status`/승인 메타/`brandKey`/`createdAt` 금지** | :578-604 |
| `brand.privateProfileUpdate` | `brands/{id}/private/profile` | **바뀐 것만** ⊂ {`businessRegistrationNumber` `representativeName` `contactName` `contactPhone` `headOfficeAddress`}. 선택 필드를 비우면 `DEL` | :624-626 |
| `brand.privateProfileCreate` | 같은 경로, **문서 부재 시에만** | 위 5키의 부분집합 (Rules `hasOnly`). spec 은 exact 로 적었으나 선택 필드를 생략해야 해서 subset | :621-623 |
| `brand.brandCore` (BR3) | `brands/{id}` update | **바뀐 것만**: `name`/`description`(비우면 `DEL`) + `status:'pending'` `submittedBy:<본인 uid>` `submittedAt:TS` `rejectedReason:null` `updatedAt:TS`. **`approvedBy`/`approvedAt`/`brandKey`/`createdAt` 없음** | :578-604 |
| `brand.masterMenuCreate` (BR7) | `brands/{id}/menuItems/{auto}` setDoc | `name` `imageUrl` `description?` `mainCategory` `subCategoryId?` `basePrice` `optionGroupRefs` `optionGroupRefIds` `soldOut` `displayOrder` `createdAt:TS` `scope:'brand'` `brandId` `tags` `visible` `disabledOptionGroupIds` `disabledOptionItemIds` `status:'pending'` `submittedBy` `submittedAt:TS` `updatedAt:TS`. **승인 메타 키 없음** | :640 |
| `brand.masterMenuCore` (BR8) | update | **바뀐 핵심 키만** ⊂ {`name` `description` `mainCategory` `subCategoryId` `basePrice` `optionGroupRefs`+`optionGroupRefIds`} + `status:'pending'` `submittedBy` `submittedAt` `rejectedReason:null` `updatedAt`. **`approvedBy`/`approvedAt`/`createdAt` 없음**(보존) | :641 |
| `brand.masterMenuOperation` (BR9, 노출 스위치 포함) | update | **바뀐 것만** ⊂ {`visible` `tags` `displayOrder` `imageUrl` `disabledOptionGroupIds` `disabledOptionItemIds`(Q4)} + `updatedAt` | :641 |
| `brand.overrideSubmitUpdate` (BR13) | `stores/{sid}/menuOverrides/{mid}` **트랜잭션** 중 문서 있음 | `priceOverride`(없으면 `DEL`) `excluded` `status:'pending'` `submittedBy` `submittedAt` `rejectedReason:null` `updatedBy:'brand'` `updatedAt`. **`soldOut`/`disabledOption*`/승인 메타 없음 → 점주 설정·승인 이력 보존** | :522-526 |
| `brand.overrideSubmitCreate` | 같은 트랜잭션 중 문서 부재 | `masterMenuItemId`(문서 ID 와 같은 값을 필드로도) `storeId` `brandId` `priceOverride?` `excluded` `soldOut:false` `disabledOption*:[]` `status:'pending'` `submittedBy` `submittedAt` `updatedBy:'brand'` `updatedAt` | :518-521 |
| `brand.storeOnlyMenuCreate/Core/Operation` (BR14) | `stores/{sid}/menuItems` | create = 마스터 create 와 같은 키(`scope:'store'`). core = 마스터 core 와 같음. ops = 8키 {`visible` `soldOut` `displayOrder` `tags` `imageUrl` `disabledOptionGroupIds` `disabledOptionItemIds`} + `updatedAt` | :483-490 |
| `brand.subCategory` / `brand.optionGroup` / `brand.activeToggle` | `brands/{id}/subCategories\|optionGroups` | 서브: `mainCategory` `name` `displayOrder` `active` `scope:'brand'` `brandId` `normalizedName` `updatedAt`(+신규 `createdAt`), 문서 ID `{mainCategory}_{millis}`. 옵션: `name` `selectionType`(`single\|multi`) `required` `items[{id,label,priceDelta}]` `displayOrder` `active` `updatedAt`(+신규 `createdAt`), **`scope`/`brandId` 저장 안 함**. 토글: `active` `updatedAt` | :646-658 |
| 삭제 cascade (W-B8) | 오버라이드 문서 ID 로 대상 조회 → `writeBatch` 청크(**8개**) delete → 마스터 delete | — | :527-530, :642 |
| `claimSubmittedBrand` CF | `getFunctions(app, 'asia-northeast3')` | `{brandId}` | CF |

### 3.2 owner

| 액션 | 경로 / 방식 | 실제 payload 키 | Rules |
|---|---|---|---|
| `owner.storeOperation` (OW2) | `stores/{id}` update | **바뀐 것만** ⊂ {`phone` `description`(`DEL`) `notice`(`DEL`) `excludedMainCategories`(휴면 코드 보존) `businessHours`(`{openTime,closeTime,closedDays}` \| `DEL`) `temporaryClosed` `closedDates`(Timestamp[]) `imageUrls`+`imageUrl`(imageUrls 변경 시에만)} + `updatedAt`. **핵심 키·`status`·승인 메타 금지** | :386-421 |
| `owner.storeCore` (OW3) | `stores/{id}` **트랜잭션** update, 서버 status ≠ rejected | **바뀐 것만** ⊂ {`name` `businessRegistrationNumber`(비우면 `null`)} + `status:'pending'` `submittedBy` `submittedAt` `updatedAt`. **`approvedBy`/`approvedAt`/`rejectedAt`/`rejectedReason` 키 없음** | :386-421 |
| `owner.storeCoreResubmit` | 같은 트랜잭션, **서버 재읽기로 `status==='rejected'` 확인된 경우에만** | 위 + `approvedBy:null` `approvedAt:null` `rejectedAt:null` `rejectedReason:null` (exact) | :373-380, :386-421 |
| `owner.personalMenuCreate` (OW7) | `stores/{id}/menuItems/{auto}` setDoc | 마스터 create 와 같은 키 **−`brandId` −`submittedBy/At`**, `scope:'store'` `status:'approved'` | :483-486 |
| `owner.personalMenuUpdate` | update | **바뀐 키만** + `updatedAt`. **`createdAt` 없음**(ⓒ) · 비우면 `DEL`(ⓓ) | :487-490 |
| `owner.personalMenuOperation` | update | 8키 중 바뀐 것 + `updatedAt` — **노출/품절 토글은 이 경로**(ⓔ) | :487-490 |
| `owner.overrideSoldOut` (OW8) | `…/menuOverrides/{mid}` **트랜잭션** 중 문서 있음 | **`soldOut` `updatedBy:'owner'` `updatedAt` 3키만** (exact) | :522-526 |
| `owner.overrideOptionDisable` | 같은 곳 | `disabledOptionGroupIds` `disabledOptionItemIds`(복합 id `{groupId}_{itemId}`) `updatedBy:'owner'` `updatedAt` 4키 (exact) | :522-526 |
| `owner.overrideCreate` | 같은 트랜잭션 중 문서 부재 | **16키 exact**: `masterMenuItemId` `storeId` `brandId` `priceOverride:null` `excluded:false` `soldOut` `disabledOptionGroupIds` `disabledOptionItemIds` `status:'approved'` `submittedBy` `submittedAt` `approvedBy:null` `approvedAt:null` `rejectedReason:null` `updatedBy:'owner'` `updatedAt` | :518-521, :506-513 |
| `owner.subCategory` / `owner.optionGroup` / `owner.activeToggle` | `stores/{id}/…` | brand 와 같은 모양(`scope:'store'`+`storeId`) | :470-478, :534-540 |
| 이미지 업로드 | Storage `store_images/{ownerId}/…` · `menu_images/store/{storeId}/{menuId\|new_millis}/…` | 5MB 상한을 클라이언트에서 건다(ⓙ) | storage.rules:23-25 |

### 3.3 customer · admin

- customer: **쓰기 없음**(Q6). 읽기만 — `users/{uid}`, `users/{uid}/orderLogs`(paidAt desc, 25건씩), `users/{uid}/qoinTransactions`(createdAt desc, 25건씩).
- admin: 승인/반려 4종 payload 와 `issueBrandKey → status 쓰기` 2단계 **그대로**(필드 집합·순서 변경 없음).

---

## 4. 자기검증 결과

> 테스트 파일은 저장소 밖 scratchpad(`/private/tmp/claude-503/-Users-Byeonguk-Developer-OrderApp/c133e8b0-27b6-490e-afeb-77a7d2e2f96b/scratchpad/rc/`)에 있다. 저장소에 남기지 않았다.

### 4.1 문법 · grep

| 검사 | 결과 |
|---|---|
| ESM 문법 (`node --input-type=module --check < 파일` — 12 JS 전부) | 통과. ⚠️ `node --check 파일.js` 는 이 폴더(package.json 없음)에서 ESM 오류를 **놓친다** — 실제로 템플릿 괄호 오류 1건을 이 방식이 못 잡았고 jsdom 로드에서 발견했다. 위 방식을 쓸 것 |
| 신규 색상 리터럴 | `console.css` · `index.html` · JS 에서 `#hex`/`rgb()`/`hsl()` **0건**. `var(--…)` 는 전부 `style.css` 에 정의된 변수(미정의 0) |
| `landing/{index,terms,privacy,refund}.html` · `landing/assets/style.css` · `firebase-config.js` | diff **0** |
| `lib/` · `functions/` · `firestore.rules` · `firebase.json` · `firestore.indexes.json` · `storage.rules` | diff **0** (`git status` 에 `landing/console/` 밖 변경 없음) |
| 금지 필드가 payload 빌더에 있는가 | 전역 금지 집합은 `assertPayload` 가 상시 검사. 빌더 단위 테스트로 `brandCore`·`menuCore`·`overrideSubmitUpdate`·`storeCore` 에 승인 메타 키 **없음** 확인 |
| `approvedAt`/`approvedBy`/`rejectedAt` 를 쓰는 payload | `admin.*` 승인·반려 4종, `owner.storeCoreResubmit`(null 클리어), `owner.overrideCreate`(null 고정) **뿐**. brand 경로 0건 |
| Firestore create 계열 (`setDoc`/`writeBatch`/`tx.set`) | 메뉴 등록 3곳(마스터·점포 한정·개인), 서브 카테고리/옵션 그룹 신규 2곳, `upsertTx`의 create 분기, `private/profile` create 분기(B3), cascade 삭제 배치, 브랜드 운영 배치. **`stores`/`brands` 문서 create 0건, `addDoc` 0건** |
| 역할 변경 코드 | `users` 문서에 대한 `updateDoc/setDoc/deleteDoc` **0건**(읽기 2곳뿐). 전역 금지에 `role` 포함 |
| 주석에서 숨김을 보안으로 설명 | 하지 않음. 각 파일 머리말에 「편의이며 보안 장치가 아니다」 명시 |

### 4.2 에뮬레이터 + 실제 Rules (859줄) — `integ.test.mjs` · **88 PASS / 0 FAIL**

`console-data.js` 를 CDN import 만 로컬 `firebase` 패키지로 치환한 사본으로 **실제 쓰기 함수**를 호출했다(프로젝트 `demo-rc-test`, Firestore 에뮬레이터 `127.0.0.1:8140`).

- **역할 판정**: admin/brand/owner · 문서 부재=customer · role 필드 부재=customer · `role:null`=unknown · `superadmin`=unknown · 타 사용자 문서 읽기=`permission-denied`(읽기 실패 ≠ 부재).
- **brand 쓰기 전부 통과**하고 결과 검증: 브랜드 운영(batch) 후 `status`/`approvedAt`/`brandKey` 불변 · 브랜드 핵심 후 pending + `approvedBy/At`/`createdAt` 보존 · 마스터 등록 pending(승인 메타 키 없음) · 마스터 핵심 수정 후 pending + 승인 메타·`createdAt` 보존 · 마스터 운영(Q4 `disabledOption*` 저장) · 오버라이드 제출 update(**점주 `soldOut`/`disabledOption*`·승인 메타 보존**, `rejectedReason:null`) · create(`masterMenuItemId` 포함) · 가격 비우기=필드 삭제 · 점포 한정 등록/핵심/운영 · 서브 카테고리(중복 이름 인라인)/옵션 그룹.
- **Rules 가 실제로 막는 것(raw 쓰기)**: 브랜드가 자기 마스터 메뉴·오버라이드를 `approved` 로 — **거부**(pending 상태에서 시도) · 승인 메타를 값으로 바꾸기 — 거부(Timestamp 왕복 함정) · customer 의 `qoinBalance`/`brandId` 쓰기 — 거부 · customer 가 UI 를 우회해 `submitBrandCore` 호출 — `permission-denied`.
- **owner**: 운영 저장(바뀐 필드만, `status`/`approvedAt` 불변) · 영업시간·소개 비우기=필드 삭제 · **핵심 수정 3갈래**: approved→pending 이면서 **`approvedAt` 보존**(영업 지속) / 이미 pending+approvedAt 재수정 / 첫 승인 대기에서 `approvedAt` 키가 생기지 않음 / rejected 재제출은 승인 메타 null 클리어 · 🔴 **화면은 rejected 로 알지만 서버는 그 사이 approved 가 된 경우 → `state-changed` 로 쓰지 않고 `approvedAt` 유지 확인** · 브랜드 가맹 매장 핵심 폼 거부 · 개인 메뉴 등록(approved 즉시)/수정(**`createdAt` 불변**)/설명 비우기/운영 8키/삭제 · 품절(기존 문서 3키 — **옵션 비활성·가격 보존**) · 문서 부재 시 16키 create · 옵션 비활성 기존/부재 · 매장 서브 카테고리/옵션 그룹.
- **Rules 실측**: 점주가 가격 변경 시도 거부 · 점주 평점 조작 거부 · **`updateDoc` 부재 문서 = `permission-denied`**(F2) · 남의 매장 주문 조회 거부 · `where storeId==` 없는 주문 쿼리 거부(rules-aware).
- **매출**: 서버 강제 읽기 후 집계(총 5,000 · 환불 1건 3,000 · 객단가 5,000).
- **customer**: 프로필/Log/Qoin 거래 읽기 · 타 사용자 Log 거부.
- **cascade 삭제**: 영향 조회(매장 7곳/19곳) → 청크 8 삭제로 오버라이드 6개·18개 + 마스터 삭제 확인.
- **🔶 Rules 접근 예산 실측(spec W-B8 "tester 필수 실측")**: 서로 다른 매장 N곳을 한 배치로 삭제 — N=8·10·12 **ok** / N=19·20·24 **permission-denied**. 한도는 13~18 사이다. 청크를 **8** 로 두었다(여유 확보). ⚠️ 에뮬레이터 1.19.8 기준이며 운영 서버와 동일하다는 보장은 없다 → tester 가 운영 유사 환경에서 다시 확인할 것.

### 4.3 jsdom 동작 테스트 — `dom.test.mjs` 88 + `dom2.test.mjs` 29 = **117 PASS / 0 FAIL**

`console-data.js` 만 스텁(실제 export 목록에서 생성)으로 바꾸고 나머지 11개 모듈은 **원본 그대로** 로드했다.

- G0 미로그인(데이터 요청 0) · G2 읽기 실패(셸 없음, 읽기 거부 안내) · G3 모르는 role(5초 후 `signOut` 1회 + 로그인 화면 안내) · **customer 문서 부재 → 정상 셸, 5.4초 후에도 `signOut` 없음**, 쓰기 컨트롤 없음, admin 건수 요청 없음 · 해시 정규화(admin→`#/u/profile`, owner `#/b/menus`→`#/o/store`, admin `#/b/`→`#/dashboard`).
- admin 이관 회귀: 셸/칩/건수 4종/배지/`<title>`.
- **owner**: GT3 · 운영 폼에 핵심 입력칸 없음 · **바뀐 필드(전화)만 payload** · 응답 전 이동·토스트 없음(낙관적 UI 금지) · 거부 시 입력 보존 · N15 이동 확인 · **핵심 모달 3갈래**(approved/pending+approvedAt → 「영업과 주문은 그대로 계속됩니다」, 첫 승인 대기 → 「계속됩니다」 **없음**, rejected → 재제출) · 초기 포커스=취소 · `state-changed` 시 모달 유지 + 새 문구 + 자동 진행 없음 · 가맹 매장은 핵심 라우트→`#/o/store`, 서브 카테고리/옵션 네비 없음 · 매출(집계/오류 시 0원 아님/0건은 실제 0/1,000건 절단 안내) · 카테고리 휴면 코드 보존 · 전부 OFF 시 유일한 확인 모달 · 카테고리 로드 실패 시 `excludedMainCategories` 미전송 · 영업시간 한쪽만 입력 오류 · 개인 메뉴 폼 필드 오류/수정 시 바뀐 키만 · 스위치 응답 전 불변 · 가맹 매장 품절 3키·옵션 모달 복합 id.
- **역할 변경(C4)**: 매출 읽기 `permission-denied` → `users` 재확인 → customer 셸 재구성 + 배너 「권한이 바뀌었어요… (점주 → Qrator)」, 추가 읽기 **1회**(폴링 없음) · 역할이 같으면 평범한 읽기 실패.
- **brand**: GT1 (네비 1개·등록 폼 없음·`listSubmittedBrands` 외 요청 없음·claim 후 재읽기→전체 네비·`not_submitter` 전용 문구+재시도 없음·조회 실패 시 연결 버튼 없음) · 마스터 목록/승인 컨트롤 없음 · **U5 문구**(「고객 메뉴 목록에 보이지 않습니다」「이미 장바구니에 담긴 주문은 결제될 수 있습니다」, 매장 문구 「영업과 주문은 그대로」 **없음**) · **U6 모달**(현재 적용가 ₩3,000 → 재제출 중 ₩4,500 나란히, 확정 문구, 가격 인상 경고, 제외 재제출 「다시 보입니다」, 효력 있는 승인 오버라이드가 없으면 일반 안내, 현재 상태를 못 읽으면 제출 불가) · 검토 현황 부분 실패 warn 배너 · 삭제 모달(영향 N개·이름 입력·영향 조회 실패 시 삭제 불가) · 브랜드 운영/핵심 2폼 분리(운영 폼에 `name` 입력칸 없음, 핵심 모달에 노출 단정 문구 없음, 핵심 payload=`name` 만).

### 4.4 단위 테스트 — `unit.test.mjs` **47 PASS / 0 FAIL**

`classifyRoleDoc` · KST 일/주/월 경계(12월→1월, 일요일 소속 주) · `aggregateSales`(환불 `refundInfo.amount ?? totalPrice`, 객단가 버림) · `storeSellClass` · `appliedOverride`/`overrideIsApproved`(서버 `menuVisibility.ts` 와 같은 분기) · `ownerScoreView` · Qoin 3단 해석 · 이미지 5MB · 빌더→가드 통과/거부(금지 키·undefined·빈 payload·불변식).

---

## 5. 로컬 확인 방법

터미널 어디서든 아래 한 줄을 그대로 실행한다. 종료는 `Ctrl+C`.

```
cd /Users/Byeonguk/Developer/OrderApp/landing && python3 -m http.server 5500
```

브라우저에서 `http://localhost:5500/console/index.html` 접속(`file://` 불가, `/console` 은 rewrite 가 없어 열리지 않음).

> ⚠️ **로컬이어도 로그인하면 운영 Firebase(`order-app-5957e`)에 붙는다.** brand/owner 쓰기를 눌러 보면 운영 데이터가 바뀐다. 쓰기 검증은 **읽기 전용 계정(customer)으로 로그인해 읽기 화면만** 확인하거나, 운영 영향이 없는 테스트 계정·테스트 매장을 쓸 것.

역할별로 볼 것: admin(대시보드 건수·승인 큐) / brand(브랜드 연결 게이트 또는 정보·마스터 메뉴·산하 매장 가격 탭) / owner(내 매장·매출·메뉴) / customer(프로필·Log·Qoin, 5초 넘게 머무는지).

---

## 6. 사용자 준비 항목

1. 콘솔로 쓸 계정의 `users/{uid}.role` 이 의도한 값인지 Firestore Console 에서 확인(admin 은 수동 설정만).
2. Firebase Console → Authentication → 승인된 도메인에 `order-app-5957e.web.app`(및 커스텀 도메인), Sign-in method 에 Email/Password·Google 활성.
3. (선택) `firebase.json` hosting 에 `"rewrites": [{ "source": "/console", "destination": "/console/index.html" }]` 추가 — 이 세션은 `firebase.json` 읽기 전용이라 하지 못했다. 없어도 `/console/index.html` 로 동작한다.
4. **토스 PG 심사 종료 후** 배포. 다른 세션의 결제 배포가 진행 중이 아닌지 확인.
5. 네이버·카카오로만 가입한 점주·브랜드는 콘솔에 로그인할 수 없다(Q5, 웹 소셜 로그인 미구현) — 콘솔 계정은 Email/Google 로 준비.

## 7. 배포 절차 (Claude 는 실행하지 않았다)

프로젝트 루트 터미널에서 **아래 한 줄만**. 전체 `firebase deploy` 금지(결제 함수·Rules 까지 올라간다).

```
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

배포 후: 랜딩 4페이지(`/index.html` `/terms.html` `/privacy.html` `/refund.html`) 먼저 확인 → `/console/index.html` → 역할별 계정으로 자기 섹션만 보이는지, 다른 역할 해시 입력 시 되돌려지는지, customer 가 자동 로그아웃되지 않는지 확인. 롤백: `cd /Users/Byeonguk/Developer/OrderApp && firebase hosting:rollback --project order-app-5957e`.

---

## 8. 테스트 포인트 (tester)

1. **Rules 실측(운영 유사)**: §3 표의 모든 쓰기가 통과하고, `brand` 자기 승인·점주 가격 변경·평점 조작 등이 거부됨. 특히 **cascade 배치 크기별 접근 예산**(§4.2) 재확인.
2. **🔴 approvedAt**: 승인된 개인 매장의 핵심 수정 후 `approvedAt` 이 남아 있는지(`canSellNow` 유지), `rejected` 재제출 때만 null 인지, 화면이 낡았을 때(그 사이 admin 이 승인) 쓰지 않는지.
3. **브랜드 경로에 승인 메타 키가 없는지** — 네트워크 탭/에뮬레이터 로그로 마스터 핵심 수정·오버라이드 제출 요청을 확인.
4. 역할 4종 계정으로 각 섹션 + 타 역할 해시 입력. customer 5초 이상 체류.
5. 역할 변경 중 세션: 앱에서 owner→customer 로 바꾸고 콘솔의 읽기/쓰기 → 안내+재구성.
6. 오버라이드 U6: 승인된 할인 오버라이드 재제출 시 모달의 두 가격 비교와 실제 적용가(고객 앱 메뉴 가격)가 일치하는지.
7. 마스터 삭제: 오버라이드가 여러 매장에 있을 때 중간 실패 재시도, 점주 생성(필드 누락) 오버라이드까지 지워지는지.
8. 매출: 앱 `OwnerSalesPage` 와 같은 기간·같은 숫자인지(KST 경계, 주 월요일 시작, 환불).
9. 이미지 5MB 초과 거부 · 업로드 일부 실패 시 Firestore 미반영.
10. 브라우저 호환(Chrome/Safari): ES 모듈·동적 import·`color-mix`.

---

## 9. 미구현 · 보류와 이유

| 항목 | 이유 |
|---|---|
| `/console` rewrite (`firebase.json`) | 이 세션 `firebase.json` 읽기 전용 |
| 매장 주소·좌표 수정 | U1 기본안: 좌표 변환에 웹에서 쓸 수 있는 키가 없다(절대규칙 4). 읽기 전용 + 「앱에서 변경해요」 |
| 핵심 폼의 메뉴 카테고리 체크 | 앱이 deprecated 로 뺐다(F6) |
| 마스터 가격 변경 시 「N개 매장에 가격 재정의가 적용 중」 안내(앱 S8) | 앱의 `countStoresUsingPriceOverride` 가 **0 만 돌려주는 스텁**(ⓗ). 콘솔에서 새로 집계하려면 매장 N회 조회가 필요해 보류. 핵심 수정 모달의 U5 문구로 대체 |
| 점주 `reviews` 의 `score` 숫자 표시 | 내부 점수라 노출하지 않음(등급 글자만) |
| Naver/Kakao 로그인 · 푸시 · 게시글/QnA · customer 쓰기 | spec 비범위 |
| 감사/이력 신규 스키마 | spec §13.1 — 새 스키마를 만들지 않는다(별 과제 T3/T5/T7/T10) |
| 실제 브라우저 + 실제 Firebase 끝-끝 확인 | 운영 쓰기 금지라 수행하지 않음. jsdom + 에뮬레이터로 대체 |

## 10. 알려진 한계

1. 매장 사진 편집은 **최대 5장**(콘솔 자체 상한, 앱 규칙 아님). 5장 초과로 이미 저장된 매장은 제거만 가능하다. 앱은 대표 사진 1장만 교체하므로 앱과 동작이 다르다.
2. 영업시간은 **매일 같은 시간**(앱과 동일). 기존 `closedDays` 는 보존한다(앱은 편집 시 비운다).
3. 검토 현황·오버라이드 목록은 **승인된 가맹점**(R-B3 쿼리)만 대상이다. 승인 전 가맹점의 오버라이드는 보이지 않는다.
4. 오버라이드 제출·마스터 메뉴 핵심 수정은 **서버 재읽기와 쓰기가 한 트랜잭션이 아니다**(모달 → 쓰기). 오버라이드는 쓰기가 트랜잭션이지만 모달의 「현재 적용가」는 모달을 연 시점 값이다. 그 사이 admin 이 승인하면 모달 수치가 낡을 수 있다(쓰기 자체는 안전).
5. 정확한 영향 범위 계산(cascade)은 `stores where brandId == X` 를 2,000건까지 읽는다.
6. 목록은 전량 로드 후 클라이언트 필터(admin 매장 목록 2,000건 상한 등 기존 한계 유지).
7. Rules 접근 예산 실측은 에뮬레이터 값이다(§4.2).
8. 이미지 선택 라벨은 `<label role="button">` — 키보드(Enter/Space)는 지원하나 스크린리더 상세 검증은 안 했다.
9. 에뮬레이터 실행 메모: 이 머신은 Java 17 이라 `firebase emulators:exec` 가 거부(요구 21+). 캐시된 `cloud-firestore-emulator-v1.19.8.jar` 를 `java -Duser.language=en -Duser.country=US -jar … --port=8140` 으로 직접 띄웠다(**ko_KR 로케일에서 Rules 평가 오류 메시지 생성이 죽는 에뮬레이터 버그**가 있어 영어 로케일 필수).
