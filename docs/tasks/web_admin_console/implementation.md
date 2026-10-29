# web_admin_console 구현 기록

- 입력: `spec.md` (Q1=B / Q2=읽기 넓게+쓰기 좁게 / Q3=A, §7.1·§9.4 2026-10-29 정정 반영), `design.md` (D1~D6 결정 반영)
- 산출물 성격: **Flutter 코드가 아니다.** `landing/admin/` 안의 정적 웹 파일(HTML/CSS/JS). `lib/` 는 건드리지 않았고 `flutter analyze` / `flutter test` / `build_runner` 는 대상이 아니다. 아래 "자기 검증" 이 그 대응물이다.
- **배포하지 않았다.** 코드만 준비했다 (Q3 조건 ③: PG 심사 종료 후 사용자가 배포).
- 상태: 구현 완료. 단 **Firebase 웹 앱 `apiKey`/`appId` 가 비어 있어 실제 Firebase 연동 E2E 는 아직 못 돌렸다** (사용자 준비 항목 1번).

---

## 1. 구현 파일 목록 / 파일별 역할

| 파일 | 줄 수 | 역할 |
|---|---:|---|
| `landing/admin/index.html` | 28 | 진입 HTML. `../assets/style.css`(읽기 전용 참조) → `assets/admin.css` 로드, `admin.js` 모듈 로드. 셸 DOM 은 두지 않는다 |
| `landing/admin/assets/admin.css` | 324 | 콘솔 스타일. `.a-` 접두. **색상 리터럴 0건**, 전부 `var(--…)`, 연한 배경은 `color-mix` 로 변수끼리만 |
| `landing/admin/assets/firebase-config.js` | 39 | Firebase 웹 설정 + `FUNCTIONS_REGION='asia-northeast3'`. **web config 가 시크릿이 아닌 근거를 파일 주석에 명시** (절대규칙 4 대응). `apiKey`/`appId` 는 비어 있음 |
| `landing/admin/assets/admin-data.js` | 309 | **Firebase SDK 접근은 이 파일에서만**. 인증, 읽기 전부(`*FromServer`), 건수(`getCountFromServer`), 쓰기 4종, `issueBrandKey` 호출. `landing/` 이 Clean Architecture 밖인 이유(spec §9.2) 주석 |
| `landing/admin/assets/admin-payloads.js` | 98 | 승인/반려 payload 빌더 + `assertPayload`(키 집합 정확 일치, Qoin 필드 금지, 매장 반려 `approvedAt` 금지). SDK 없음 → node 로 검증 가능 |
| `landing/admin/assets/admin-format.js` | 197 | 날짜/UID/가격/적립률 표시, `esc`, `safeUrl`, 오류 분류(`classifyError`), 오류 문구 표(design §8), 반려 사유 검증. SDK 없음 |
| `landing/admin/assets/admin.js` | 1198 | 인증 게이트(A0), 셸, 해시 라우터, 화면 A1~A9, 승인/반려 모달. 보안 모델 주석(화면 숨김은 편의, 권위는 Rules/CF) |
| `landing/admin/README.md` | 52 | 콘솔 전용 안내(로컬 확인 / 설정 / 배포). `landing/README.md` 는 수정하지 않았다 |

spec §9.1 은 `admin.js` 한 파일을 가정했지만, "데이터 접근 함수와 렌더 함수 분리"(§9.2) 와 payload 검증의 node 실행 가능성을 위해 5개 JS 모듈로 나눴다. 전부 정적 ES 모듈이라 빌드 단계는 여전히 없다.

## 2. 재사용한 기존 구조

- `landing/assets/style.css` 의 `:root` 변수 전부(`--primary`, `--primary-bright`, `--surface*`, `--border`, `--text-*`, `--success/--error/--warning`, `--radius`, `--shadow`, `--wrap`)와 `.skip`, `.qlogo`, `.brand`, `.brand-word` 클래스. **`style.css` 는 수정하지 않았다.** 푸터/고객센터의 비변수 hex 는 복사하지 않았다.
- 전역 요소 규칙(`section`, `table`, `th/td`, `.card`)이 새어 들어오지 않도록 콘솔은 `.a-` 접두 클래스만 쓰고 `<section>` 요소를 쓰지 않는다.
- 로고: `landing/index.html` 인라인 SVG 복제.
- 앱 계약 그대로 옮긴 것: 승인/반려 필드 집합(`StoreModel.approveFields/rejectFields`, `brand_repository_impl.dart` `approveBrand/rejectBrand`), 브랜드 승인 2단계 순서, `issueBrandKey` 응답 검증("키 없는 성공 응답은 실패"), 쿼리 필터(`status==pending`, 마스터 메뉴 `scope==brand`), 매장 `status` 누락 시 `approved` 취급(앱 T1), 전역 적립률 경계(0.1%~20%, 0 무효), 앱 승인 화면의 "승인 버튼은 개인 매장/승인 브랜드에서만 활성"(`StoreBrandLink.approveEnabled`).
- Firestore 색인: 기존 `firestore.indexes.json` 의 `brands`/`menuItems`/`menuOverrides` 복합 색인이 큐 쿼리와 같은 모양이라 새 색인을 요구하지 않는다(확인만, 수정 없음).

## 3. 액션별 실제 payload

`approvedBy` 는 항상 `auth.currentUser.uid`. 시각은 `serverTimestamp()`. 쓰기는 전부 `runTransaction` 안의 `tx.update` 이고, 트랜잭션 안에서 문서를 다시 읽어 `status === 'pending'` 이 아니면 쓰지 않는다.

| 액션 | 순서 | 보내는 필드 |
|---|---|---|
| 브랜드 승인 (D1) | ① 서버에서 pending 재확인 → ② `issueBrandKey({brandId})` (`asia-northeast3`, 30s, 응답 `brandKey` 가 비어 있으면 실패) → ③ update | `status:'approved'`, `approvedBy`, `approvedAt`, `rejectedReason:null`, `updatedAt` |
| 브랜드 반려 | update | `status:'rejected'`, `approvedBy`, `rejectedReason`(trim), `updatedAt` |
| 매장 승인 | (브랜드 연결 시) 연결 브랜드가 서버에서 `approved` 인지 재확인 → update | `status:'approved'`, `approvedBy`, `approvedAt`, `rejectedReason:null`, `updatedAt` |
| 매장 반려 | update | `status:'rejected'`, `approvedBy`, **`rejectedAt`**, `rejectedReason`(trim), `updatedAt` — `approvedAt` 없음 |

- ② 가 실패하면 `brands/{id}` 를 건드리지 않는다(문서 불변). ③ 만 실패하면 "키는 발급되었지만 승인 상태를 저장하지 못했어요. 다시 시도하면 이어서 처리돼요" — `issueBrandKey` 가 멱등이라 재시도 가능.
- design §6-9 축소안(브랜드 승인 버튼 제거)은 폐기했다(D1).
- 콘솔이 쓰는 문서는 `brands/{id}`, `stores/{id}` 의 `update` 뿐이다. `users`는 읽기만 한다.

## 4. 화면 구현 현황 (design A0~A9)

| 화면 | 구현 | 비고 |
|---|---|---|
| A0 인증 게이트 (로그인 / 확인 중 / 비admin / 읽기 실패 / 세션 만료 / 설정 필요) | ✅ | admin 확인 전 셸 DOM·데이터 요청 없음. `users/{uid}` 읽기 실패·타임아웃·형식 이상은 닫힘. "설정 필요" 화면은 design 에 없던 추가 상태(apiKey/appId 공란 대응) |
| A1 대시보드 | ✅ | 건수 카드 4개 독립 로딩/오류/0건, Qoin 요약, 비상 정지 배너 |
| A2/A3 브랜드 큐/상세 | ✅ | 사업자 정보 카드 독립 로딩/오류(오류 시 승인 버튼 아래 경고), 이전/다음 건, 처리된 건은 패널을 상태 배너로 대체 |
| A4/A5 매장 큐/상세 | ✅ | 연결 브랜드 해석(브랜드 전량 1회 조회), 이미지는 새 탭 |
| A6/A7 마스터 메뉴 / 매장 커스텀 | ✅ 읽기 전용 | 행에 링크·버튼 없음. 색인 오류는 식별 문구로 표시(§6 참고) |
| A8 매장 목록 | ✅ | 검색(150ms) + 상태 칩 + 25건 페이징, 두 종류의 empty 구분 |
| A9 Qoin 현황 | ✅ 읽기 전용 | 입력/토글/변경 버튼 0개. 이력 최근 20건 |
| 승인/반려 모달 | ✅ | 확인 단계, 사유 입력(D2 상한 없음·글자수만), 단계 표시, 실패 복귀, 불확실 결과 처리 |

## 5. 설계와 다르게 구현한 곳 (이유 포함)

1. **매장 승인 버튼 활성 조건 — 앱 기준을 따랐다.** design §A5 는 "연결 브랜드가 이상해도 승인 버튼을 막지 않는다(앱과 동일)"고 적었지만, 실제 앱(`StoreBrandLink.approveEnabled`)은 **개인 매장/승인된 브랜드일 때만** 승인을 켠다(fail-closed). 앱 계약을 옮기는 것이 이 작업의 원칙이므로 앱을 따랐고, 쓰기 직전에 서버에서 브랜드 상태를 다시 확인한다. 반려는 항상 켠다. (Rules 는 이를 강제하지 않는다 — 이것은 앱과 같은 운영 정책을 UI 에 옮긴 편의이며 보안 장치가 아니다.) → **architect 확인 권장.**
2. **개인 매장 표기**: design A4 표는 `personal` 을 "브랜드 확인 필요"로 적었지만 개인 매장은 정상 상태이고 A5 는 "브랜드 없이 등록된 매장"이라 적었다. 큐/목록에서는 "개인 매장(브랜드 없음)"으로 표기했다.
3. **영업시간**: design 은 요일별 표를 가정했지만 실제 `businessHours` 는 `openTime/closeTime/closedDays` 단일 구조(`closedDays` 는 현재 항상 빈 배열)라 "09:00 ~ 18:00" 한 줄로 표시한다.
4. **A7 변경 유형**: design 의 "점포 한정 메뉴"는 `menuOverrides` 가 아니라 `scope==store` `menuItems` 큐의 개념이다. 실제 `menuOverrides` 필드(`priceOverride`, `excluded`, `soldOut`, `disabledOption*`)에 맞춰 "가격 변경 / 이 매장 제외 / 품절 / 옵션 비활성"으로 표시한다. 열 구성: 메뉴(마스터 메뉴 이름 조회) · 매장(이름 조회) · 변경 유형 · 변경 가격 · 제출 시각 · 상태.
5. **A6 열**: 메뉴 · 브랜드 · 가격(`basePrice`) · 제출 시각 · 상태. 브랜드는 경로 `brands/{id}/menuItems/{id}` 에서 얻는다.
6. **사유 길이**: D2 에 따라 `maxlength` 없음. 카운터는 `n자`(`/ 200` 아님).
7. **불확실 결과(타임아웃)**: 트랜잭션 20초, `issueBrandKey` 30초, 읽기 15초. 쓰기 타임아웃은 "반영 여부 불명" 으로 처리하고 확정 버튼을 잠근 뒤 "상태 확인하기"(서버 재조회)를 제공한다.

## 6. 두 컬렉션 그룹 큐의 색인 오류 처리

- `listPendingMenus`/`listPendingOverrides` 는 실패 시 **원본 에러(색인 생성 URL 포함)를 `console.error` 로만** 남기고 화면에는 "목록을 불러오지 못했어요. 인덱스 설정이 필요할 수 있어요." 를 보인다(`failed-precondition` + 메시지에 `index` 포함이면 `index` 로 분류). 건수 카드는 같은 쿼리의 `count` 라 실패하면 사이드바 `!` + 카드 "불러오지 못했어요" 로 보인다(0 으로 표시하지 않음).
- 기존 `firestore.indexes.json` 에 두 큐와 같은 모양의 색인이 이미 있으므로 정상 배포된 프로젝트에서는 나지 않아야 한다.

## 7. 자기 검증 결과

### 7.1 문법 / 참조

- `node --check` : `admin.js`, `admin-data.js`, `admin-format.js`, `admin-payloads.js`, `firebase-config.js` 전부 통과.
- import/export 이름 일치 검사(스크립트): 누락 0건.
- Firebase SDK 10.14.1 의 `firebase-{app,auth,firestore,functions}.js` 에서 쓰는 export 이름(`getDocFromServer`, `getDocsFromServer`, `getCountFromServer`, `runTransaction`, `collectionGroup`, `httpsCallable` 등) 실재 확인(CDN 에서 받아 export 목록 대조).
- 참조 파일 실재: `../assets/style.css`, `../assets/favicon.svg`, `assets/admin.css`, `assets/admin.js` 및 `admin.js` 가 import 하는 모듈 전부 존재.
- 외부 스크립트 버전: 전부 `…/firebasejs/10.14.1/…` 고정. `firebase@` 범위 표기 0건.

### 7.2 grep 자기 검증

| 항목 | 명령 요지 | 결과 |
|---|---|---|
| 색상 리터럴 | `#[0-9a-fA-F]{3,6}\b`, `rgba?(`, `hsla?(` 를 `assets/*.css *.js index.html` 에서 | **0건** |
| Qoin 관리 필드 | `qoinAccrual|qoinBulk` 를 `landing/admin` 전체에서 | **1건** — `admin-payloads.js:20` 금지 목록 상수(`QOIN_MANAGED_FIELDS`). payload 빌더 어디에도 없음 |
| `accrualRate`/`enabled` | `admin-data.js` | 읽기(`getQoinConfig`) 3줄뿐, 쓰기 0건 |
| 반려 경로의 `approvedAt` | `admin-payloads.js` | 승인 빌더 2곳 + 매장 반려 금지 assert. 반려 빌더(`brandRejectPayload`, `storeRejectPayload`)에는 없음 |
| create/set/delete | `setDoc|addDoc|deleteDoc|writeBatch|updateDoc|tx.set|.set(|\bcreate\b` | **0건** (Firestore 쓰기). 매치된 2건은 JS `Map.set`(`admin-data.js:137`, `admin.js:813`). 쓰기는 `tx.update` 1곳(`admin-data.js:238`) |
| `users` 접근 | `'users'` | `readUserRole` 의 `getDocFromServer` 1건(읽기). 쓰기·역할 변경 코드 0건 (`role` 은 `data.role === 'admin'` 판정과 주석뿐) |
| 리전 | `getFunctions(app, FUNCTIONS_REGION)` / `asia-northeast3` | 명시됨 |
| 범위 | `git status` | 변경은 `landing/admin/**` 와 `docs/tasks/web_admin_console/implementation.md` 뿐. `lib/` `functions/` `firestore.rules` 및 `landing/` 기존 파일 diff 0 (`firebase.json` 의 `M` 과 `.firebaserc` 는 이 작업 이전부터 있던 변경이며 건드리지 않음) |

### 7.3 동작 스모크 (임시 환경, 저장소 밖)

실제 Firebase 없이 `admin-data.js` 를 가짜로 바꿔 jsdom 에서 `admin.js` 를 실행해 확인했다(스크립트는 저장소 밖 scratchpad 에만 있고 커밋 대상 아님). 통과한 것:

- admin → 셸 + 대시보드 건수 카드, 0건은 "0", 건수 조회 실패는 사이드바 `!` + 카드 "–/불러오지 못했어요/다시 시도"(숫자 0 아님).
- 비admin / `users` 읽기 실패 → 셸·`#view`·네비 DOM 없음, **데이터 요청 0건**.
- 브랜드 큐 렌더(이름 HTML 이스케이프), 상세, 사업자 정보 로딩, 반려 모달: 확정 버튼 `aria-disabled`, 빈 사유·공백 사유 거부, trim 한 값이 전달됨, 실패 시 모달 유지 + 사유 보존 + 오류 배너, 성공 시 큐로 이동 + 토스트 "반려했어요".
- 브랜드 승인 `issueKey` 단계 실패 → "브랜드 키 발급에 실패했어요. 승인은 저장되지 않았어요", 모달 취소 후 상세에 영구 배너.
- 매장 상세: 연결 브랜드가 승인 상태가 아니면 승인 버튼 비활성 + 사유 문구, 영업시간 표시.
- 마스터 메뉴 색인 오류 문구, 매장 커스텀 행 매핑, 매장 목록의 반려 메타(`rejectedAt`), Qoin 페이지(입력/textarea 0개).
- payload 빌더: 네 액션의 정확한 키 집합, 매장 반려에 `approvedAt` 추가 / 승인에 Qoin 필드 추가 / 필수 키 누락 / 빈 uid / 공백 사유는 모두 throw.

**이 스모크는 실제 Rules/CF/Auth 를 거치지 않았다.** Rules 통과와 `approvedBy` 기록은 tester 가 실계정으로 확인해야 한다(§10).

## 8. 로컬 확인 방법

1. (한 번) `landing/admin/assets/firebase-config.js` 의 `apiKey`, `appId` 를 채운다(§9-1).
2. 터미널 아무 곳에서나 아래 한 줄 실행(종료는 `Ctrl+C`):

```bash
cd /Users/Byeonguk/Developer/OrderApp/landing && python3 -m http.server 5500
```

3. 브라우저에서 `http://localhost:5500/admin/index.html`. ES 모듈이라 `file://` 로는 동작하지 않는다. `apiKey`/`appId` 를 채우기 전에는 "설정이 필요해요" 화면이 나오는 것이 정상이다.

## 9. 사용자 준비 항목

1. **Firebase 웹 앱 등록 + 설정값 입력.** Firebase Console > 프로젝트 설정 > 내 앱 에서 웹 앱을 추가하고 SDK 설정의 `apiKey`, `appId` 를 `landing/admin/assets/firebase-config.js` 에 채운다. 저장소에 web 설정이 없다(`lib/firebase_options.dart` 는 android/ios 만). android/ios 용 키를 재사용하지 않았다. 이 값은 시크릿이 아니다(파일 주석 참고). **서비스 계정 키는 웹·깃에 절대 넣지 않는다.**
2. **Firebase Auth 승인된 도메인**: Authentication > Settings > 승인된 도메인에 **`localhost`**(로컬 확인용, 기본 포함) 와 **`order-app-5957e.web.app`**(커스텀 도메인이 있으면 함께) 가 있어야 한다. 없으면 `auth/unauthorized-domain` 으로 로그인이 실패하고 콘솔이 그 안내를 보여준다.
3. **로그인 수단**: Authentication > Sign-in method 에서 Email/Password 와 Google 활성화.
4. **관리자 계정**: Firestore Console 에서 해당 `users/{uid}.role` 이 `'admin'` 인지 확인. (콘솔에는 역할 부여 기능이 없다.)
5. 다른 세션의 결제 배포 작업이 진행 중이 아닌지 확인(같은 hosting 블록/명령 공유).

## 10. 배포 절차 (사용자 수행, **PG 심사 종료 후**)

프로젝트 루트(`/Users/Byeonguk/Developer/OrderApp`)의 터미널에서 아래 한 줄. 전체 `firebase deploy` 는 쓰지 않는다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

- 이 명령은 `landing/` 전체(랜딩 4페이지 + `landing/admin/`)를 함께 올린다. 배포 후 `https://order-app-5957e.web.app/{index,terms,privacy,refund}.html` 4개가 그대로인지 확인한다.
- 콘솔 주소: `https://order-app-5957e.web.app/admin/index.html` (`cleanUrls:false` 라 `/admin` 만으로는 열리지 않는다 — spec 별 과제 S7).
- 롤백: `cd /Users/Byeonguk/Developer/OrderApp && firebase hosting:rollback --project order-app-5957e`
- 참고: `firebase.json` 의 `/assets/**` 캐시 헤더는 루트 `assets/` 에만 걸리고 `admin/assets/` 에는 걸리지 않는다. 배포 직후 구버전 JS 가 보이면 강력 새로고침. `landing/admin/README.md` 도 호스팅에 함께 올라가 공개 URL 로 읽힌다(비밀 값 없음).

### 커밋 명령 예시 (실행하지 않았다 — 경로를 하나씩 명시, `git add -A` / `git add .` 금지)

```bash
cd /Users/Byeonguk/Developer/OrderApp && git add landing/admin/index.html landing/admin/README.md landing/admin/assets/admin.css landing/admin/assets/admin.js landing/admin/assets/admin-data.js landing/admin/assets/admin-format.js landing/admin/assets/admin-payloads.js landing/admin/assets/firebase-config.js docs/tasks/web_admin_console/implementation.md && git commit -m "feat: web_admin_console — landing/admin 관리자 콘솔 (승인 큐 4종 조회, 브랜드/매장 승인·반려)"
```

(`spec.md` / `design.md` 는 별도 역할 산출물이라 위 명령에 넣지 않았다. 필요하면 같은 방식으로 경로를 추가한다. `firebase.json` / `.firebaserc` 는 다른 세션 변경이므로 넣지 않는다.)

## 11. 테스트 포인트 (tester)

**필수(spec §14 / design 대응)**
1. 비admin 계정 로그인 → 본문·사이드바 미렌더 + 네트워크 탭에 `brands`/`stores` 등 데이터 요청 없음. 미로그인 직접 접근 → 로그인 화면만.
2. `users/{uid}` 읽기 실패(오프라인/규칙 거부 시뮬레이션) → 닫힘 유지, "다시 시도" 성공 + admin 일 때만 셸.
3. **권위 검증**: 개발자 도구에서 비활성 버튼을 강제로 풀어 클릭 / 비admin 토큰으로 쓰기 시도 → Rules 가 거부하고 콘솔이 성공으로 표시하지 않음.
4. 4개 액션 후 문서 확인: `approvedBy == 로그인 uid`, 매장 반려는 `rejectedAt` 만 쓰고 `approvedAt` 불변(결제 게이트 오염 없음), 브랜드 승인은 `brandKey` 가 `private/profile` 에 존재.
5. 네트워크 탭에서 payload 확인: Qoin 관리 필드 없음, `create`(문서 생성) 요청 없음, `users` 쓰기 없음.
6. 승인/반려 실패(권한 거부·오프라인) 시 모달 유지 + 사유 보존 + 항목이 목록·건수에 그대로 남음. 성공 시에만 큐 이동·서버 재조회·토스트.
7. **브랜드 승인 D1**: `issueBrandKey` 실패(차단/오프라인) → 문서 불변(status/approvedBy 변화 없음). 키 발급 성공 후 쓰기 실패 → 재시도로 이어서 처리됨.
8. 동시성: 다른 탭/앱에서 먼저 승인/반려한 건을 콘솔에서 확정 → "이미 처리된 건이에요 (현재: …)" 로 쓰기 안 함, 확정 잠금.
9. 건수 조회 실패(오프라인) → 사이드바 `!` + 카드 "불러오지 못했어요", **0 이 표시되지 않음**. 정상 0건은 "0 / 대기 없음".
10. 마스터 메뉴·매장 커스텀 큐: 행에 링크/버튼 없음, 색인 오류 시 식별 문구(화면에 URL 노출 없음, 콘솔에만).
11. 매장 승인: 연결 브랜드가 pending/rejected/없음/조회 실패일 때 승인 버튼 비활성 + 사유 문구, 반려는 가능.
12. 세션 만료/로그아웃 → 로그인 화면 + (만료 시) 안내 배너. 직접 로그아웃은 배너 없음.
13. 배포 후 landing 4페이지 회귀 없음.

**권장**
- 반려 사유: 공백만 → 거부, 줄바꿈 유지, 긴 사유(수백 자) 입력 가능(D2), Esc/취소로만 닫힘(입력 중 바깥 클릭 무시), 처리 중 Esc/바깥 클릭 무시, 포커스 트랩.
- 불확실 결과(응답 지연 20초+): "응답을 확인하지 못했어요" + 확정 잠금 + "상태 확인하기".
- 매장 목록: 검색/필터/페이징, 반려 매장 메타가 `rejectedAt` 기준, status 누락 레거시 매장은 "승인됨".
- 1024px 미만 레이아웃(상단 바), 키보드만으로 로그인→승인, `prefers-reduced-motion`.

## 12. 미구현 / 보류 항목과 이유

| 항목 | 이유 |
|---|---|
| 실제 Firebase 연동 검증(Auth/Rules/CF 왕복) | `apiKey`/`appId` 가 저장소에 없고 웹 앱 등록이 사용자 영역. §7.3 스모크는 가짜 데이터 계층 기준 |
| 배포 / `firebase.json` 수정 | Q3 조건 ③ + 범위 제한. 사용자가 PG 심사 후 수행 |
| 재제출 건 구분 표시 | D6 — 판별 필드 정의가 선행 과제 |
| 승인 후 자동 다음 건 이동 | D4 — 서버 반영 확인 전 이동은 낙관적 UI 라 하지 않음 |
| 마스터 메뉴·매장 커스텀 승인/반려 | Q2 — 읽기 전용 |
| 메인 카테고리 CRUD, Qoin 쓰기, 일괄 적용, 매장 삭제, 역할 부여 | spec §3 비범위 |
| App Check, 별도 호스팅 사이트, `/admin` 확장자 없는 접근 | spec 별 과제 S9, S3, S7 |
| 자동 테스트 파일 | 저장소에 JS 테스트 환경이 없고 package.json 금지. 순수 모듈(`admin-payloads.js`, `admin-format.js`)은 node 로 직접 import 해 검증 가능하게 분리해 둠 |

## 13. 알려진 한계

1. **매장 목록은 전량 로드 + 클라이언트 페이징**이다(상한 2000건, 도달 시 "일부만 불러왔어요" 표시). **매장 수가 늘면 서버 페이징(커서 `startAfter` + 서버 검색)이 필요하다.** `listAllStores` 는 페이징 인자를 받는 시그니처로 분리해 두었지만 현재는 무시한다(DV-7). 대응하는 건수 임계 알림은 넣지 않았다.
2. 승인 큐 목록은 서버에서 최대 500건만 가져온다. 초과 시 "처음 500건까지만 불러왔어요" 가 표시되고, 건수(`count`)와 목록 길이가 다를 수 있다.
3. 연결 브랜드 해석을 위해 매장 큐/목록 진입마다 `brands` 전체를 1회 읽는다(브랜드 수가 크게 늘면 비용). 실패하면 해당 칸은 "브랜드를 확인하지 못했어요"로 표시되고 매장 목록은 정상 표시된다.
4. A7 은 행마다 메뉴/매장 이름을 개별 조회한다(고유 id 기준 최대 200건, 초과분은 id 축약 표시).
5. 승인/반려 모두 "1세대 메타만 문서에 남는" 기존 한계를 그대로 상속한다(spec 별 과제 S4). 앱에서 한 승인인지 웹에서 한 승인인지는 남지 않는다(S6).
6. `getCountFromServer` / 컬렉션 그룹 쿼리는 색인 상태에 의존한다. 색인이 없으면 해당 건수/목록만 오류 상태가 되고 나머지 화면은 동작한다.
7. 오프라인 영속성은 쓰지 않는다(메모리 캐시, 읽기는 전부 서버 강제). 쓰기는 트랜잭션이라 오프라인에서 큐에 쌓이지 않고 실패한다.
8. 이미지 URL 은 `http(s)` 만 렌더하며 외부 호스트의 이미지는 `referrerpolicy="no-referrer"` 로 불러온다.

## 14. architect 에게 확인이 필요한 사항

- §5-1: 매장 승인 버튼을 앱처럼 비활성화한 것이 맞는지(design 문구와 앱 코드가 어긋나 앱 코드를 따랐다). design.md 문구 정정을 권한다.
- §5-3, §5-4: design 의 영업시간 요일 표 / "점포 한정 메뉴" 라벨이 실제 필드와 달라 실제 필드에 맞췄다.
