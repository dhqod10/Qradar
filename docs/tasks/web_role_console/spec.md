# web_role_console 기능 명세

## 개요

- **목적**: 완성된 admin 전용 웹 콘솔(`landing/console/`)을 **역할별 운영 콘솔 `/console/`** 로 확장한다. 로그인한 사용자의 `users/{uid}.role` 에 따라 보이는 섹션이 달라지는 **단일 앱**이다.
- **작업 유형**: 기존 기능 확장 (신규 플랫폼 표면의 범위 확대). `landing/console/` 코드를 `landing/console/` 로 **이관**하고 brand / owner / customer 섹션을 추가한다.
- **출발점**: `docs/tasks/web_admin_console/` 의 spec / design / implementation 이 완료돼 있고 `landing/console/` 에 동작하는 콘솔(8파일, JS 약 1,850줄)이 있다. **아직 배포된 적이 없다** (PG 심사 종료 전 배포 보류).
- **랜딩(`landing/*.html`)은 그대로 둔다.** 토스 PG 심사 자료이므로 이번 작업에서 **단 한 글자도 바꾸지 않는다.**

### 이 spec 의 핵심 산출물

화면이 아니라 **§5 의 역할 × 액션 × Firestore 경로 × 허용 필드 × Rules 줄번호 × 통과 여부 매트릭스**다.
Rules 의 필드 화이트리스트가 역할마다 좁게 걸려 있어, 화면을 먼저 그리면 "Rules 가 거부하는 모양의 쓰기" 를 UI 가 전제하게 된다.

### 영향 범위 (요약)

| 영역 | 영향 |
|---|---|
| 화면 | 신규 `landing/console/` (역할별 섹션). **`landing/{index,terms,privacy,refund}.html` 무변경** |
| 화면 | `landing/console/` | **이관 후 제거** (§11) |
| 화면 | `lib/presentation/**` (admin 59 · brand 32 · owner 37 파일) | **무변경.** 읽기 참조만 — 흐름·검증값 복제의 원본 |
| Domain / Data / Presentation (`lib/`) | **없음.** `landing/` 은 Flutter 앱이 아니고 Clean Architecture 레이어 체계 밖이다 (§8.4) |
| Firestore Rules | **변경 없음 — 변경 불가**(§3). 기존 분기 안에서만 동작함을 §5 에서 액션별 검증 |
| Cloud Functions | **변경 없음.** 기존 callable 을 그대로 호출 (§7) |
| Firestore 인덱스 | **변경 없음 — `firestore.indexes.json` 은 `landing/` 밖이라 읽기 전용.** 기존 인덱스로 충분함을 §5 에서 쿼리별 확인 |
| Storage | 규칙 변경 없음. 웹 업로드가 현재 `storage.rules` 를 통과함을 §5.4 에서 확인 |
| `firebase.json` | **hosting 블록만** — rewrite 1줄 추가 (§12) |
| 데이터 | 신규 컬렉션 / 신규 필드 / 신규 status 값 **없음** |
| 테스트 | 브라우저 수동 검증 + §5 매트릭스 실측. `flutter test` 영향 없음 |

---

## 1. 확정 사항 (전제 — 재논의하지 않는다)

사용자가 이미 결정했다. 이 spec 은 전부 이 전제 위에서 쓰였다.

### 확정 1. 단일 앱 `/console/` — 역할별 최상위 경로로 나누지 않는다

`/brand` `/owner` `/admin` 로 쪼개지 않는다.

- 로그인 · 역할 판정 · 셸 · 테이블 · 모달 · 에러 분류 · payload 가드를 **한 번만** 만든다.
- `users.role` 은 **단일 값**이고 Rules `isAllowedSelfRoleChange` (`firestore.rules:158-165`) 가 `customer ↔ owner ↔ brand` 자가 전이를 허용한다 → 역할이 실제로 바뀐다. 경로를 나누면 **역할 변경 후 예전 URL 이 빈 화면**이 된다.
- 기존 `landing/console/` 코드는 **버리지 않고 `/console/` 의 admin 섹션으로 이관**한다 (§11).

### 확정 2. 랜딩 헤더의 "로그인" 버튼은 PG 심사 통과 후에 단다

그 전까지는 **`/console/` URL 직접 접근**으로만 쓴다.

- 심사 중 심사 자료 디렉토리(`landing/`)를 건드리는 배포를 반복하지 않는다.
- 심사자가 누르면 막다른 길이다 — 웹에 회원가입이 없고, 고객은 1차에 기능이 없다.
- 이 버튼 추가는 **별 과제 T9**.

### 확정 3. 역할별 범위

| 역할 | 1차 범위 |
|---|---|
| `admin` | 승인 큐 등 — **기존 `web_admin_console` 범위 전부 이관** |
| `brand` | 마스터 메뉴 · 가격 오버라이드 · 산하 매장 관리 |
| `owner` | **매출 조회 · 메뉴 관리만.** 주문 접수/제조/완료는 **범위 제외** (§2 비범위 N1) |
| `customer` | **지금은 기능 없음.** 단 안내벽이 아니라 **아직 비어 있는 정식 섹션**. 자동 로그아웃 **걸지 않는다** (§10) |

---

## 2. 기능 범위

### 2.1 공통 (셸)

- [ ] **C1. 로그인** — Firebase Auth (Email/Password · Google). 기존 구현 이관.
- [ ] **C2. 역할 판정** — `users/{uid}` 1회 read → `role` 로 섹션 결정. 읽기 **실패**는 fail-closed, 문서/필드 **부재**는 `'customer'` (Rules `userRole()` `firestore.rules:26-30` 와 동일 해석). §9.
- [ ] **C3. 역할별 네비게이션** — 해당 역할의 항목만 렌더. 없는 메뉴를 비활성으로 보여주지 않는다.
- [ ] **C4. 역할 변경 감지/복구** — 섹션 주 read 가 `permission-denied` 면 `users/{uid}` 재확인 → 역할이 달라졌으면 안내 + 셸 재렌더. §9.3.
- [ ] **C5. payload 가드** — 모든 쓰기는 `console-payloads.js` 의 역할별 키 집합 검증을 통과해야 전송된다. §6.
- [ ] **C6. 쓰기 전 확인 단계** — 대상 이름을 다시 보여주고 확인. 낙관적 UI 금지.

### 2.2 admin 섹션 — 기존 범위 이관 (기능 변경 없음)

`web_admin_console` spec §2 의 F1~F7 을 **그대로** 옮긴다. 신규 admin 기능은 추가하지 않는다.
대시보드 / 브랜드 승인 큐 / 매장 승인 큐 / 마스터 메뉴 대기(읽기) / 매장 커스텀 대기(읽기) / 매장 목록 / Qoin 현황(읽기).

### 2.3 brand 섹션 (신규)

- [ ] **B1. 브랜드 정보 조회** — `brands/{myBrandId}` + `brands/{id}/private/profile`(사업자·담당자 PII) + brandKey 표시. 승인 상태 배지.
- [ ] **B2. 브랜드 정보 수정** — 운영 필드 + PII. 핵심 필드(`name`/`description`) 변경 시 `status='pending'` 회귀가 일어난다는 것을 **수정 전에 경고**한다.
- [ ] **B3. 마스터 메뉴 목록 / 상세** — `brands/{id}/menuItems`, `orderBy('displayOrder')`.
- [ ] **B4. 마스터 메뉴 등록 / 핵심 수정 / 운영 수정 / 복제 / 삭제** — 앱의 **A-1 ~ A-5 경로를 그대로**. 핵심 수정은 `status='pending'` 회귀, 운영 수정은 즉시 반영. 삭제는 오버라이드 cascade — **앱에 구현이 없어 콘솔이 새로 만든다**(§11.3-ⓛ). §5.3 W-B8 의 배치 제약 주의.
- [ ] **B5. 브랜드 서브 카테고리 / 옵션 그룹 관리** — `brands/{id}/subCategories`, `/optionGroups`. 이름 중복 금지 · 사용 중 삭제 차단 포함.
- [ ] **B6. 산하 매장 목록 (읽기 전용)** — `stores where brandId == myBrandId`. 앱과 동일하게 **브랜드는 `stores/{id}` 본문을 쓰지 않는다** (§5.3).
- [ ] **B7. 가격 오버라이드 제출** — `stores/{sid}/menuOverrides/{mid}` upsert, `status='pending'` 회귀, `updatedBy='brand'`. **승인은 admin 몫**이다 (§5.7-X2).
- [ ] **B8. 점포 한정 메뉴 (브랜드 매장)** — `stores/{sid}/menuItems`, `status='pending'` 제출.
- [ ] **B9. 검토 현황** — 제출물(마스터 메뉴 / 오버라이드 / 점포 한정 메뉴)의 pending·rejected 트래킹. 앱의 알려진 비정합(§11.3-ⓑ)을 **복제하지 않는다**.
- [ ] **B10. 브랜드 미연결 게이트** — `role=='brand'` 인데 `users.brandId` 가 비면 모든 brand 쓰기가 Rules 에서 실패한다(`isBrandHolder` 가 빈 문자열을 거짓으로 고정, `firestore.rules:57-62`). 이 상태를 **명시 화면**으로 다루고 `claimSubmittedBrand` CF 1회 호출 버튼만 제공한다. **브랜드 신규 등록 폼은 만들지 않는다** (§2.4 비범위 N4).
- [ ] **B11. 적립률 표시 (읽기 전용)** — store/brand/global 3단 해석. `brands/{id}/qoinRateHistory` 조회. **쓰기 없음** (CF 전담).

### 2.4 owner 섹션 (신규)

- [ ] **O1. 내 매장 요약** — `stores where ownerId == uid` (MVP: 점주 1매장 가정, 앱과 동일). 상태 배지 · 평균 점수 · 리뷰 수 · 적립률(읽기 전용).
- [ ] **O2. 매출 조회** — 일 / 주 / 월. `orders where storeId == X && createdAt [start, endExclusive)` `orderBy createdAt desc` `limit 1000`, **서버 강제 읽기**. 집계 정의는 앱의 `aggregateStoreSales` 를 **그대로** (§5.4 주석).
- [ ] **O3. 기간 내 주문 목록** — 환불·취소 포함. 1,000건 절단 표시.
- [ ] **O4. 받은 평가 조회 (읽기 전용)** — `reviews where storeId == X`. 평균 점수 포함(점주 화면 전용). 답글·신고 없음.
- [ ] **O5. 개인 매장 메뉴 관리** — `stores/{id}/menuItems` CRUD + 품절 토글 + 노출 토글. `store.brandId == null && status == 'approved'` 일 때만 노출(앱과 동일 조건).
- [ ] **O6. 브랜드 매장 메뉴 — 품절 · 옵션 비활성만** — `stores/{id}/menuOverrides` 운영 필드. 앱 배너 문구 그대로: "점주는 품절과 옵션 비활성화만 가능해요."
- [ ] **O7. 매장 서브 카테고리 / 옵션 그룹 관리** — 개인 매장만 (앱과 동일).

### 2.5 customer 섹션 (신규 — 비어 있는 정식 섹션)

- [ ] **U1. 내 프로필 조회** — `users/{uid}` 의 표시 이름 / 가입 수단 / Qoin 잔액(읽기 전용).
- [ ] **U2. 주문 내역(Log) 조회** — `users/{uid}/orderLogs`.
- [ ] **U3. Qoin 거래 내역 조회** — `users/{uid}/qoinTransactions`.
- [ ] **U4. "아직 준비 중" 안내** — 리뷰 · 게시글 · QnA 가 들어올 자리를 **빈 섹션으로** 표시. "앱을 쓰세요" 로 돌려보내지 않는다.
- [ ] **U5. 자동 로그아웃 없음** — §10.

### 2.6 UI 요구사항

- [ ] **UI1.** 데스크톱 우선(최소 1024px). 좌측 네비 + 본문. 모바일 폭에서 깨지지 않을 정도만 대응.
- [ ] **UI2.** 색상은 `landing/assets/style.css` 의 기존 CSS 변수만 사용. **새 색상값 도입 금지** (CLAUDE.md 절대규칙 3의 `landing/` 대응물).
- [ ] **UI3.** Qradar 용어 — Qoin / Qrator / Log.
- [ ] **UI4.** 역할 배지를 셸에 표시한다 (관리자 / 브랜드 / 점주 / 고객). 현재 어떤 권한으로 보고 있는지가 상시 보여야 한다.
- [ ] **UI5.** 파괴적 액션(삭제 · 반려 · 핵심 수정으로 인한 status 회귀)은 시각 위계를 분리하고 확인 단계를 둔다.

### 2.7 상태 요구사항

- [ ] **S1.** loading — 목록/카드 단위 스켈레톤.
- [ ] **S2.** error — §14 표대로 구분. 재시도.
- [ ] **S3.** empty — 에러와 **구분**해 표시.
- [ ] **S4.** 미인증 — 로그인 화면만. 데이터 요청 0건.
- [ ] **S5.** 역할 판정 실패 — fail-closed 게이트 (§9.2).
- [ ] **S6.** 섹션 전제 미충족 (brand 미연결 / 매장 없음 / 매장 미승인) — 섹션 안에서 안내. 셸은 유지.

---

## 3. 비범위 (이유 명기)

| # | 제외 항목 | 이유 |
|---|---|---|
| **N1** | **owner 의 주문 접수 / 제조 / 완료** | **운영 사고가 된다.** 웹에 접수 기능이 있으면 점주가 PC 앞에 있어야 주문을 받게 되고, 카운터를 비운 사이 `paid` 주문이 쌓인다. 카운터 업무는 손에 들린 앱이 맞다. 기술적으로는 Rules O1·O5·O6·O7(`firestore.rules:234-298`)이 허용하지만 **의도적으로 만들지 않는다.** |
| **N2** | **게시글 · QnA** | **컬렉션 자체가 `firestore.rules` 에 없다.** fallback deny(`firestore.rules:820-822`)가 전부 거부한다. 새 Rules 가 필요하고 Rules 는 이 세션 **읽기 전용**(§3 제약 2) → **별 과제 T1**. customer 섹션은 이 자리를 비워 둔다(§10). |
| **N3** | **역할 부여 / role 변경 / admin 승격** | 보안 모델상 금지. admin 부여는 Firestore Console 수동 `users.role='admin'` 뿐이고 Rules `isAllowedSelfRoleChange`(`:158-165`)가 자가승격을 차단한다. 콘솔이 남의 `users` 문서를 쓸 수 있으면 **admin 전권 분기(`:128`) 때문에 세션 탈취가 곧 권한 상승**이 된다. §4.2. |
| **N4** | brand 신규 등록 폼 | 브랜드 등록은 `brands` create + `claimSubmittedBrand` CF + `private/profile` create 3단계 트랜잭션성 흐름이고, 중간 실패 시 고아 브랜드 방지 로직이 있다. 로고 업로드도 필수다. 미연결 계정은 **B10 게이트 + claim 버튼**으로 처리하고 등록은 앱에 맡긴다. |
| **N5** | owner 매장 정보 수정 (핵심 · 운영 필드) | 주소 검색(Kakao Kpostal) · `GeoPoint` · 이미지 다중 업로드 의존이고, **핵심 필드 수정은 `status='pending'` 회귀**를 일으켜 매장 재심사를 트리거한다. 보조 표면에서 쏘기에 위험이 크다. → **Q3** |
| **N6** | admin 이 다른 역할 화면을 대행 | **권하지 않는다.** `orders.update` 의 점주 분기(O1·O5·O6·O7)는 `storeOwner` + status 전이 + 허용 필드 3개로 좁은데 admin 분기 **O4(`:224`)는 전권**이다. 점주용 UI 를 admin 권한으로 실행하면 **잘못된 모양의 쓰기가 Rules 에 막히지 않는다** — 오류가 조용히 성공한다. 대행이 필요하면 **별도 설계가 선행**돼야 한다 → 별 과제 T4. |
| **N7** | brand 의 자기 제출물 승인 | Rules 는 허용하지만(§5.7-X2) 승인 경계가 무의미해진다. admin 몫으로 유지. |
| **N8** | Qoin 쓰기 (적립률 · 비상 정지 · 브랜드 일괄 적용) | 돈 값이고 전부 CF 전담 + 상태 기계가 있다. 표면을 2개로 늘리는 결정은 별건. 기존 spec 의 판단을 유지. |
| **N9** | 매장 삭제(`deleteStore`) | 되돌릴 수 없고 Storage·서브컬렉션까지 지운다. 앱 1곳 유지. |
| **N10** | 마이그레이션 / 감사 CF (`migrate*`, `audit*`, `backfill*`) | 임시 운영 도구이고 정리 커밋으로 삭제 예정. |
| **N11** | Naver / Kakao 로그인 | 웹 SDK 미지원·미검증. 콘솔 계정은 Email/Google 로 준비. **운영상 함의: 네이버·카카오로만 가입한 점주·브랜드는 콘솔에 로그인할 수 없다** → **Q5**. |
| **N12** | FCM / 웹 푸시 | VAPID + service worker 가 별도로 필요하고 조회·관리 업무에 불필요. |
| **N13** | 결제 / 환불 / 주문 조회(고객) | 결제 영역이며 **다른 세션이 동시 작업 중**(§3 제약 1). 충돌 회피. |
| **N14** | Flutter 앱 화면 제거·축소 | 웹은 **병행 표면**이다. 앱 기능은 그대로 둔다. |
| **N15** | Firestore Rules / 인덱스 변경 | §3 제약 2. `firestore.indexes.json` 도 `landing/` 밖이다. |
| **N16** | 자동 배포 | 프로덕션 반영은 **사용자가 수행**한다 (§15). |
| **N17** | 앱 코드의 기존 결함 수정 | `lib/` 읽기 전용. 발견한 결함은 §11.3 에 기록하고 **콘솔이 복제하지 않는 선**까지만 한다 → 별 과제 T6. |

---

## 4. 제약 조건과 보안 모델

### 4.1 이 세션의 제약 (메모리 `project-landing-deploy-rules` / `landing/README.md`)

1. 같은 저장소에서 **다른 세션이 결제 관련 작업을 진행 중**이다.
2. **코드 작성은 `landing/` 안으로 한정.** `lib/` · `functions/` · `firestore.rules` · `firestore.indexes.json` · `storage.rules` 는 **읽기 전용**.
3. **`firebase.json` 은 hosting 블록만.**
4. **배포는 `--only hosting` 만.** 전체 `firebase deploy` 금지.
5. **git 은 `git add <정확한 경로>` 만.**
6. 이 `spec.md` 작성은 사용자가 허용한 예외다. **`docs/tasks/web_role_console/spec.md` 외의 파일을 만들거나 수정하지 않는다.** 특히 `docs/tasks/web_admin_console/` 는 **tester 가 사용 중**이다.

### 4.2 보안 모델 (기존 spec 과 동일하게 유지)

> **콘솔은 클라이언트일 뿐이다.** 권한의 최종 권위는 **Firestore Security Rules 와 Cloud Functions** 다. **화면 숨김 · 탭 미노출 · 버튼 비활성화는 편의이며 보안 장치가 아니다.**

역할별 콘솔에서 이 원칙이 더 중요해지는 이유: 섹션이 역할로 갈리면 "탭이 안 보이니 못 한다" 는 착각이 생기기 쉽다. 실제로는 **URL 해시를 직접 고쳐 다른 역할 섹션의 뷰를 렌더할 수 있다.** 그래도 안전해야 한다 — Rules 가 모든 read/write 를 재판정한다.

설계 요건:

- **R-SEC1.** 각 역할 섹션은 자기 역할이 아니면 **렌더되지 않는 것이 아니라, 렌더돼도 데이터가 안 와야** 한다. 라우터는 역할 밖 해시를 자기 역할 기본 화면으로 되돌리되, 그 리다이렉트를 **보안 근거로 쓰지 않는다.**
- **R-SEC2.** 역할 판정 결과(`C2`)는 **UI 분기 입력일 뿐 신뢰 근거가 아니다.** 모든 요청이 Rules 에서 다시 판정된다.
- **R-SEC3.** CF 는 `requireAdmin()` 등으로 `users/{uid}.role` 을 **서버에서 다시 읽는다**. 클라이언트가 보낸 역할을 믿지 않는다.
- **R-SEC4.** **역할 부여 기능을 만들지 않는다** (§3-N3).
- **R-SEC5.** **admin 대행을 만들지 않는다** (§3-N6).

### 4.3 시크릿 취급

| 값 | 성격 | 취급 |
|---|---|---|
| Firebase **web config** (`apiKey`, `appId`, `projectId`, …) | **시크릿이 아니다.** 브라우저에 반드시 노출되는 공개 식별자. 보호는 Rules + Auth 승인 도메인 + App Check 가 한다 | `landing/console/assets/firebase-config.js` 에 평문. **근거를 파일 주석으로 명시** (기존 파일에 이미 있다 — 이관 시 유지) |
| 서비스 계정 키 / Admin SDK 자격증명 | **진짜 시크릿.** Rules 를 전부 우회 | **웹 · 깃에 절대 금지.** 콘솔은 Admin SDK 를 쓰지 않는다 |
| 토스 시크릿 키 | 진짜 시크릿 | 콘솔 범위 밖. CF 에만 존재 |

CLAUDE.md 절대규칙 4의 취지는 "노출되면 피해가 나는 값을 코드에 두지 않는다" 다. web config 는 노출을 전제로 설계된 값이므로 위반이 아니다.

---

## 5. ★ 역할 × 액션 × 경로 × 허용 필드 × Rules 줄 × 통과 매트릭스

### 5.0 읽는 법과 전제

- 줄번호는 **현재 `firestore.rules` (825줄)** 기준이다.
  > ⚠️ **`docs/tasks/web_admin_console/spec.md` §7.2 의 줄번호는 낡았다.** 그 spec 작성 후 Rules 가 커져 전부 3~5줄 밀렸다 (예: brands read 517→**516**, stores update 336-339→**341-344**, config read 781→**784**). developer / tester 는 **이 매트릭스의 줄번호**를 쓴다.
- **판정 기호**: ✅ 통과 · ⚠️ 조건부 통과(조건 명기) · ❌ Rules 거부 · 🚫 Rules 는 허용하나 **정책상 만들지 않음**
- **`onlyChangedFields(allowed)`** (`firestore.rules:65-67`) = `request.resource.data.diff(resource.data).affectedKeys().hasOnly(allowed)`.
  → **값이 바뀐 키만** 센다. 같은 값을 다시 써도 `affectedKeys` 에 들어가지 않는다. 따라서 **허용 목록의 부분집합을 보내는 것은 항상 안전**하고, **목록 밖 키를 하나라도 바꾸면 update 전체가 거부**된다.
  → **update 전용 장치다. `create` 는 보호하지 않는다** (audit_trail §4-7 의 상시 항목). create 경로는 따로 확인했다.

### 5.1 전역 금지선 — 모든 역할 / 모든 분기에서 거부

| 금지선 | 대상 | Rules | 의미 |
|---|---|---|---|
| `touchesQoinManaged()` | `stores` · `brands` **update** | `:82-84`, 적용 `:341` / `:538` | `qoinAccrualRate` `qoinAccrualEnabled` `qoinBulkHistoryId` `qoinBulkStatus` `qoinBulkAt` 5개(`:75-78`) 중 **하나라도 섞이면 admin 전권 포함 update 전체 거부** |
| `hasQoinManagedOnCreate()` | `stores` · `brands` **create** | `:87-89`, 적용 `:317` / `:521` | create 로도 심을 수 없다 |
| `availableMainCategories` | `stores` | create 금지 `:332`, update 화이트리스트 부재 `:367-379` | CF 전담 파생 필드 (검색 노출 위조 차단) |
| `averageScore` · `reviewCount` | `stores` | update 화이트리스트 부재 `:367-379` | `onReviewWritten` CF 전담 (점주 평점 조작 차단) |
| `brandKey` | `brands` · `brands/{id}/private/profile` | `:569-571`, `:591`/`:594` | `issueBrandKey` CF 전담 |
| `qoinBalance` | `users` | create 금지 `:122`, self update 화이트리스트 부재 `:142` | CF 전담 |
| `ownerId` · `brandId` | `stores` | update 화이트리스트 부재 `:367-379` / `:406-415` | immutable |
| `users.brandId` | `users` | self 화이트리스트 부재 `:142` | `claimSubmittedBrand` CF 전담 (권한 값) |

**콘솔의 어떤 payload 에도 위 필드를 넣지 않는다.** §6 의 가드가 전송 전에 터뜨린다.

### 5.2 공통 / 셸

| # | 액션 | 경로 | 작업 | 보내는/읽는 필드 | Rules | 판정 |
|---|---|---|---|---|---|---|
| G1 | 역할 판정 | `users/{uid}` | read | — | `:108` `isAdmin() \|\| (isSignedIn() && uid()==userId)` | ✅ 본인 문서 |
| G2 | 문서/필드 부재 해석 | `users/{uid}` | read | `role` 부재 → `'customer'` | `:26-30` `userRole()` 가 동일하게 해석 | ✅ Rules 와 일치 |
| G3 | 역할 변경 | `users/{uid}` | update | — | `:139-165` self 화이트리스트 + 전이표 | 🚫 §3-N3 |

### 5.3 brand 섹션

`isBrandHolder(brandId)` = `role=='brand'` **AND** `brandId is string` **AND** `brandId != ''` **AND** `users.brandId == brandId` (`:57-62`).
→ **`users.brandId` 가 비면 brand 의 모든 쓰기가 거부된다.** B10 게이트가 이 상태를 먼저 해소한다.

#### 읽기

| # | 액션 | 경로 / 쿼리 | Rules | 판정 |
|---|---|---|---|---|
| R-B1 | 브랜드 정보 | `brands/{myBrandId}` | `:516` `isSignedIn()` | ✅ |
| R-B2 | 사업자 · 담당자 PII + brandKey | `brands/{id}/private/profile` | `:587-588` `isAdmin() \|\| isBrandHolder \|\| isBrandSubmitter` | ✅ 보유자 |
| R-B3 | 산하 매장 목록 | `stores` where `brandId==X` + `status=='approved'` orderBy `createdAt desc` | `:306` `isSignedIn()` | ✅ 인덱스 `brandId,status,createdAt` **존재** |
| R-B4 | 마스터 메뉴 | `brands/{id}/menuItems` orderBy `displayOrder` | `:606` `isSignedIn()` | ✅ 단일 필드 |
| R-B5 | 브랜드 서브 카테고리 / 옵션 그룹 | `brands/{id}/subCategories`, `/optionGroups` | `:613`, `:620` | ✅ |
| R-B6 | 매장별 오버라이드 | `stores/{sid}/menuOverrides` | `:485` `isSignedIn()` | ✅ |
| R-B7 | 점포 한정 메뉴 | `stores/{sid}/menuItems` | `:459` | ✅ |
| R-B8 | 적립률 이력 | `brands/{id}/qoinRateHistory` | `:577` `isAdmin() \|\| isBrandHolder(brandId)` | ✅ |
| R-B9 | 매장 적립률 이력 | `stores/{sid}/qoinRateHistory` | `:441-443` `… \|\| isBrandHolder(store.brandId)` | ✅ 산하 매장만 |
| R-B10 | 미연결 복구용 조회 | `brands` where `submittedBy==uid` | `:516` | ✅ 단일 필드 |
| R-B11 | 검토 현황 (제출물) | `collectionGroup('menuOverrides')` where `brandId==X` | `:763-765` `isSignedIn()` | ⚠️ **인덱스 미보장.** 기존 CG 인덱스는 `status+submittedAt` 뿐이다 → §16 developer 주의. 인덱스 추가 불가(N15)이므로 **매장별 서브컬렉션 N회 조회**로 간다 |
| R-B12 | 브랜드 PII (타 브랜드) | `brands/{other}/private/profile` | `:587-588` | ❌ 설계상 시도하지 않는다 |

#### 쓰기

| # | 액션 | 경로 | 작업 | **보내야 하는 정확한 필드** | Rules | 판정 |
|---|---|---|---|---|---|---|
| **W-B1** | 브랜드 운영 정보 수정 | `brands/{id}` | update | **화이트리스트의 부분집합만**: `name` `logoUrl` `description` `updatedAt` `companyName` (+핵심 변경 시 `status:'pending'` `submittedBy:<본인uid>` `submittedAt`) | 허용 `:548-555` / `status` 는 `'pending'` 만 `:557-560` / `submittedBy` 는 본인 uid 만 `:564-567` / **`brandKey` `approvedBy` `approvedAt` `createdAt` 변경 금지** `:569-571` / `!touchesQoinManaged()` `:538` | ⚠️ **앱의 full `set(merge:true)` 를 그대로 옮기면 위험하다.** 앱은 `approvedBy`/`approvedAt`/`createdAt` 을 **기존 값 그대로** 다시 써서 `affectedKeys` 에 안 들어가 통과한다. 타임스탬프 왕복에서 1비트라도 달라지면 **승인 메타 변경으로 판정돼 전체 거부**된다. → **콘솔은 변경된 키만 담은 좁은 payload 를 보낸다** (§6 `mode:'subset'`) |
| **W-B2** | 브랜드 PII 수정 | `brands/{id}/private/profile` | update | **정확히 5개 중 변경분**: `businessRegistrationNumber` `representativeName` `contactName` `contactPhone` `headOfficeAddress`. null 은 `deleteField()` | `:592-594` `onlyChangedFields(brandPrivatePiiFields())` (`:93-95`) | ✅ 키 하나라도 추가하면 전체 거부 |
| W-B3 | 브랜드 PII 최초 생성 | `brands/{id}/private/profile` | create | `hasOnly(5개)` — **정확히 그 5개 안에서만** | `:589-591` | ✅ (B10 경로에서만 발생) |
| **W-B4** | 마스터 메뉴 등록 | `brands/{id}/menuItems` | create | 앱 `MenuItemModel.toFirestore()` 전체. 리포 강제값: `scope:'brand'` `status:'pending'` `submittedBy` `submittedAt`, 승인 메타 null. **Firestore 키는 `mainCategory`** (엔티티명 `mainCategoryCode` 아님) | `:607-608` `isAdmin() \|\| isBrandHolder(brandId)` — **필드 제한 없음** | ✅ |
| **W-B5** | 마스터 메뉴 핵심 수정 | `brands/{id}/menuItems/{id}` | update | 전체 맵 + `status:'pending'` 회귀 + `submittedBy`/`submittedAt` 갱신, **`approvedBy`/`approvedAt` 보존** ("수정 대기" 배지 판정에 쓰인다) | `:607-608` 제한 없음 | ✅ |
| **W-B6** | 마스터 메뉴 운영 수정 | 동일 | update | `visible` `tags` `displayOrder` `imageUrl` `updatedAt` **(5개)**. 승인 메타 무변경 | `:607-608` | ✅ ⚠️ 앱은 `disabledOptionGroupIds`/`disabledOptionItemIds` 를 "운영 변경" 으로 **판정만 하고 payload 에 넣지 않는다** (저장 안 됨) → **Q4** |
| W-B7 | 마스터 메뉴 복제 | — | 쓰기 없음 | prefill 전용. 저장은 W-B4 | — | ✅ |
| **W-B8** | 마스터 메뉴 삭제 (cascade) | ① `collectionGroup('menuOverrides')` where `masterMenuItemId==X` delete<br>② `brands/{id}/menuItems/{id}` delete | delete | — | ① `:495-498` `isAdmin() \|\| isStoreOwner \|\| isBrandHolder(store.brandId)` — **문서마다 `get(stores/{storeId})` 1회**<br>② `:607-608` | 🔴 **정정 2026-10-29 — 앱에는 이 cascade 가 없다.** `master_menu_item_remote_data_source.dart:146-154` 의 `cascadeDeleteOverrides` 는 **no-op**(`debugPrint` 한 줄)이다. 주석의 전제("menuOverrides 컬렉션이 아직 없다")가 더 이상 맞지 않아 **마스터를 지워도 오버라이드가 남는다** → 앱 결함 ⓛ. 따라서 **"앱의 490건 청크 배치" 라는 최초 서술은 틀렸다** — 490 청크는 **브랜드 일괄 제외 create** 경로(`menu_override_remote_data_source.dart:132`)에 있는 것이다. 콘솔은 이 cascade 를 **새로 구현**하게 된다. Rules 접근 예산(단일 10 / 배치·트랜잭션 20)은 여전히 설계 제약이나, 한 배치가 **여러 storeId** 에 걸치면 `get()` 이 storeId 수만큼 늘어난다. **동일 경로 중복 `get()` 의 집계 방식은 실측으로 확인**하고 청크 크기를 그에 맞춘다 → tester 필수 실측 |
| **W-B9** | 가격 오버라이드 제출 | `stores/{sid}/menuOverrides/{mid}` | create 또는 update (`set(merge:true)`) | `masterMenuItemId`(문서 ID 와 **같은 값을 필드로도**) `storeId` `brandId` `priceOverride?`(null 이면 키 생략) `excluded` `soldOut`(보존) `disabledOption*`(보존) `status:'pending'` `submittedBy` `submittedAt` `approvedBy?`/`approvedAt?`(보존) `updatedBy:'brand'` `updatedAt` | create `:486-489` / update `:490-494` — **브랜드 보유자 분기는 제한 없음** | ✅ ⚠️ `merge:true` 라 **이전 `rejectedReason` 이 남는다**. 콘솔은 재제출 시 `rejectedReason: null` 을 명시한다 |
| W-B10 | 점포 한정 메뉴 (브랜드 매장) | `stores/{sid}/menuItems` | create/update/delete | `scope:'store'` `brandId:<storeBrandId>` `status:'pending'` `submittedBy` `submittedAt` + 메뉴 필드. 운영 수정은 8키(`visible` `soldOut` `displayOrder` `tags` `imageUrl` `disabledOptionGroupIds` `disabledOptionItemIds` `updatedAt`) | `:460-463` `isAdmin() \|\| isStoreOwner \|\| isBrandHolder(store.brandId)` — 제한 없음 | ✅ |
| W-B11 | 브랜드 서브 카테고리 upsert | `brands/{id}/subCategories/{mainCat}_{millis}` | set(merge) | `mainCategory` `name` `displayOrder` `active` `scope:'brand'` `brandId` `normalizedName` `updatedAt` (+신규 `createdAt`) | `:614-615` `isAdmin() \|\| isBrandHolder(brandId)` | ✅ 문서 ID 는 **클라이언트 생성** |
| W-B12 | 브랜드 옵션 그룹 upsert | `brands/{id}/optionGroups/{id}` | add / set(merge) | `name` `selectionType` `required` `items[{id,label,priceDelta}]` `displayOrder` `active` `updatedAt` (+신규 `createdAt`). **`scope`/`brandId` 는 문서에 저장하지 않는다** (경로가 scope) | `:621-622` | ✅ |
| W-B13 | 서브 카테고리 / 옵션 그룹 삭제 | 동일 | delete | — | `:614-615`, `:621-622` | ✅ 사용 중이면 **클라이언트가 차단** (`collectionGroup('menuItems')` 사용 수 조회) |
| **W-B14** | `stores/{id}` 본문 수정 | `stores/{id}` | update | — | `:403-435` `isStoreOwnerBrandUpdate()` 가 **Rules 상 허용**한다 | 🚫 **만들지 않는다.** 앱도 브랜드에게 매장 본문 쓰기를 주지 않는다(`brand_stores_page` 전체 read-only, V6 결정). 산하 매장은 **서브컬렉션만** 관리한다 |
| W-B15 | 자기 제출물 승인 | `brands/{id}/menuItems`, `stores/{sid}/menuOverrides` | update | `status:'approved'` … | `:607-608`, `:490-494` — **제한 없음 = Rules 가 허용** | 🚫 §5.7-X2 |

### 5.4 owner 섹션

`isStoreOwner(storeId)` = `get(stores/{storeId}).ownerId == uid` (`:45-48`).

#### 읽기

| # | 액션 | 경로 / 쿼리 | Rules | 판정 |
|---|---|---|---|---|
| R-O1 | 내 매장 | `stores` where `ownerId==uid` limit 1 | `:306` `isSignedIn()` | ✅ 단일 필드 (앱 `watchByOwner` 와 동일, orderBy 없음 → 인덱스 불필요) |
| **R-O2** | **매출 원천** | `orders` where `storeId==X` **AND** `createdAt >= start` **AND** `createdAt < endExclusive` orderBy `createdAt desc` limit 1000, **서버 강제** | `:213-215` `isAdmin() \|\| userId==uid \|\| isStoreOwner(storeId)` | ✅ ⚠️ **`where storeId==` 를 빼면 Rules 가 쿼리 전체를 거부**한다(rules-aware query). 인덱스 `storeId ASC, createdAt DESC` **존재** |
| R-O3 | 받은 평가 | `reviews` where `storeId==X` | `:717` `isSignedIn()` | ✅ 인덱스 `storeId,createdAt` 존재 |
| R-O4 | 매장 메뉴 / 오버라이드 / 옵션 / 분류 | `stores/{id}/{menuItems,menuOverrides,optionGroups,subCategories}` | `:459`, `:485`, `:503`, `:449` | ✅ |
| R-O5 | 마스터 메뉴 (브랜드 매장) | `brands/{bid}/menuItems` | `:606` | ✅ |
| R-O6 | 연결 브랜드 기본 정보 | `brands/{bid}` | `:516` | ✅ `name`/`logoUrl` 만 쓴다 |
| **R-O7** | 연결 브랜드 PII | `brands/{bid}/private/profile` | `:587-588` admin / 보유자 / 제출자만 | ❌ **점주는 읽을 수 없다.** 콘솔은 **요청조차 보내지 않는다** |
| R-O8 | 매장 적립률 이력 | `stores/{id}/qoinRateHistory` | `:441-443` `isStoreOwner(storeId)` | ✅ |
| R-O9 | 전역 Qoin 설정 | `config/qoin` | `:784` `isSignedIn()` | ✅ 표시용 |
| R-O10 | 전역 Qoin 이력 | `config/qoin/qoinRateHistory` | `:801-802` `isAdmin()` | ❌ 시도하지 않는다 |

> **매출 집계 정의 — 값을 새로 정하지 않는다** (앱 `lib/domain/usecases/get_store_sales_use_case.dart` `aggregateStoreSales`):
> `completed` → 확정 매출 / `paid`·`accepted`·`making`·`ready` → 진행 중 매출 / `refunded` → `refundInfo.amount ?? totalPrice` 를 환불로 집계하고 **매출에서 제외** / `cancelled` → 건수만.
> **총 매출 = 확정 + 진행 중.** 평균 객단가는 **정수 나눗셈 버림**. 기준 시각은 `createdAt`(환불 시각 아님). 기간은 **KST(UTC+9) 반열린 구간 `[start, endExclusive)`**, 주는 **월요일 시작 / ISO 8601 목요일 소속 주차**. 상한 1,000건 / 최대 12개월 전. 절단 시 "최근 1,000건만 집계했어요".
> 읽기는 **서버 강제**(`getDocsFromServer`). 캐시를 쓰면 **0원이 정상 수치처럼 보인다** — 앱 코드가 주석으로 명시 경고한 지점이다.

#### 쓰기

| # | 액션 | 경로 | 작업 | **보내야 하는 정확한 필드** | Rules | 판정 |
|---|---|---|---|---|---|---|
| **W-O1** | 개인 매장 메뉴 등록 | `stores/{id}/menuItems/{auto}` | create | 앱 전체 payload. 리포 강제: `scope:'store'` `brandId:null` **`status:'approved'`**(승인 큐 미경유, 즉시 반영), `submittedBy`/승인 메타 **키 생략**. `optionGroupRefs` + `optionGroupRefIds` **둘 다** (후자는 `arrayContains` 사용 수 조회용) | `:460-463` `isStoreOwner(storeId)` — **필드 제한 없음** | ✅ 개인 매장(`brandId == null`)만 |
| W-O2 | 개인 매장 메뉴 핵심 수정 | 동일 | update | 전체 payload | `:460-463` | ✅ ⚠️ **`createdAt` 을 넣지 않는다** — 앱은 넣어서 매 수정마다 `createdAt` 이 리셋된다(§11.3-ⓒ). 콘솔은 복제하지 않는다 |
| W-O3 | 개인 매장 메뉴 운영 수정 | 동일 | update | `visible` `soldOut` `displayOrder` `tags` `imageUrl` `disabledOptionGroupIds` `disabledOptionItemIds` `updatedAt` **(8개)** | `:460-463` | ✅ **노출 토글도 이 경로**로 보낸다 (앱은 핵심 전체 update 를 쏜다 — §11.3-ⓔ, 복제하지 않는다) |
| W-O4 | 개인 매장 메뉴 삭제 | 동일 | delete | — | `:460-463` | ✅ |
| **W-O5** | **품절 토글 (브랜드 매장)** | `stores/{id}/menuOverrides/{mid}` | update (문서 존재) | **`soldOut` `updatedBy:'owner'` `updatedAt` 3개만** | `:490-494` 점주 분기 `onlyChangedFields(['soldOut','disabledOptionGroupIds','disabledOptionItemIds','updatedBy','updatedAt'])` — **5개만** | ✅ (3개는 부분집합) ⚠️ **앱처럼 `disabledOption*` 를 같이 보내면 안 된다** — 빈 배열로 덮어써 **옵션 비활성 설정이 전부 지워진다**(§11.3-ⓐ) |
| **W-O6** | 옵션 비활성 (브랜드 매장) | 동일 | update (문서 존재) | `disabledOptionGroupIds` `disabledOptionItemIds` `updatedBy:'owner'` `updatedAt` **4개**. `disabledOptionItemIds` 원소는 **복합 id `{groupId}_{itemId}`**, `disabledOptionGroupIds` 는 groupId 단독 | 동일 `:490-494` | ✅ 포맷을 지켜야 고객 앱 머지가 깨지지 않는다 |
| **W-O7** | 오버라이드 최초 생성 | 동일 | create (문서 부재) | `masterMenuItemId:<문서ID>` `storeId` `brandId` `priceOverride:null` `excluded:false` `soldOut` `disabledOptionGroupIds` `disabledOptionItemIds` `status:'approved'` `submittedBy:<uid>` `submittedAt` `approvedBy:null` `approvedAt:null` `rejectedReason:null` `updatedBy:'owner'` `updatedAt` **(16개)** | `:486-489` 점주 분기 `ownerOverrideCreateOk()` (`:475-482`): `status ∈ {pending,approved,rejected}` **AND** `approvedBy==null` **AND** `approvedAt==null` **AND** (`status!='approved'` **OR** (`priceOverride==null` **AND** `excluded==false`)). `hasOnly` 없음 → **추가 키 허용** | ✅ ⚠️ **`masterMenuItemId` 를 포함한다** — 앱의 이 경로는 빼먹어서 마스터 메뉴 삭제 cascade 와 사용 수 집계에서 누락된다(§11.3-ⓑ). Rules 통과에 영향 없는 **순수 추가** → **Q2** |
| **W-O8** | upsert 분기 방식 | 동일 | — | — | — | ⚠️ **선행 read 기반 분기(앱 방식)를 쓰지 않는다.** stale read 로 create 분기를 타면 Firestore 가 **update 로 판정**해 16키가 5키 화이트리스트에 걸려 `permission-denied` 가 난다. 콘솔은 **`updateDoc` 먼저 → `not-found` 면 create** 순서로 간다 |
| W-O9 | 매장 옵션 그룹 CRUD | `stores/{id}/optionGroups/{id}` | add / set(merge) / update / delete | `name` `selectionType`('single'\|'multiple') `required` `items` `displayOrder` `active` `updatedAt` (+신규 `createdAt`). 토글은 `active` `updatedAt` 2개 | `:504-507` `isStoreOwner(storeId)` 제한 없음 | ✅ 개인 매장만(앱과 동일) |
| W-O10 | 매장 서브 카테고리 CRUD | `stores/{id}/subCategories/{mainCat}_{millis}` | set(merge) / update / delete | `mainCategory` `name` `displayOrder` `active` `scope:'store'` `storeId` `normalizedName` `updatedAt` (+신규 `createdAt`) | `:450-453` 제한 없음 | ✅ 문서 ID **클라이언트 생성** |
| W-O11 | 메뉴 이미지 업로드 | Storage `menu_images/store/{storeId}/{menuItemId}/{millis}_{filename}` | write | — | `storage.rules:23-25` `request.auth != null && size < 10MB && contentType ~ image/*` | ✅ 웹 업로드 가능. ⚠️ 앱은 **5MB** 상한을 클라이언트에서 추가로 걸고 신규 메뉴에 `new_{millis}` 가짜 세그먼트를 쓴다 → 콘솔도 **5MB 상한과 경로 규칙을 동일하게** 지킨다 (`storage.rules` 가 나중에 좁혀질 때 어긋나지 않도록) |
| **W-O12** | 주문 접수 / 제조 / 완료 | `orders/{id}` | update | `status` + 전이 시각 + `updatedAt` (3개) | `:234-239`(O1) `:275-280`(O5) `:284-289`(O6) `:293-298`(O7) — **Rules 는 허용** | 🚫 **§3-N1 운영 사고. 만들지 않는다** |
| W-O13 | 환불 거절 | `orders/{id}` | update | `refundRequest` `updatedAt` | `:263-271`(O3) | 🚫 N1 과 같은 이유 (카운터 업무) |
| W-O14 | 매장 운영 필드 수정 | `stores/{id}` | update | `phone` `description` `notice` `excludedMainCategories` `businessHours` `temporaryClosed` `closedDates` `imageUrls` `imageUrl` `updatedAt` (10개 — **전부 화이트리스트 안**) | `:364-399` `isStoreOwnerFieldUpdate` 화이트리스트 `:367-379` | 🚫 1차 비범위 §3-N5 → **Q3** |
| W-O15 | 매장 핵심 필드 수정 / 재제출 | `stores/{id}` | update | `name` `address` `location`(GeoPoint) `menuCategories` `businessRegistrationNumber` `status:'pending'` `submittedBy` `submittedAt` `updatedAt` (+재제출 시 `approvedBy:null` `approvedAt:null` `rejectedAt:null` `rejectedReason:null`) | 화이트리스트 `:367-379` + `status` 는 `'pending'` 만 `:381-384` + `approvedBy`/`approvedAt`/`rejectedAt` **null 클리어만** `:386-398` + `leavingRejectedClearsApproval()` `:351-356` | 🚫 1차 비범위 §3-N5 → **Q3** |
| W-O16 | 평점 조작 | `stores/{id}` | update | `averageScore` `reviewCount` | 화이트리스트 **부재** `:367-379` | ❌ CF 전담 |
| W-O17 | 매장 자가 승인 | `stores/{id}` | update | `status:'approved'` / `approvedAt:<값>` | `:381-384`, `:386-393` | ❌ 구조적 차단 |

### 5.5 customer 섹션

| # | 액션 | 경로 / 쿼리 | Rules | 판정 |
|---|---|---|---|---|
| R-U1 | 내 프로필 (`displayName` / `provider` / `qoinBalance`) | `users/{uid}` | `:108` | ✅ |
| R-U2 | 주문 내역(Log) | `users/{uid}/orderLogs` | `:171` `isAdmin() \|\| uid()==userId` | ✅ |
| R-U3 | Qoin 거래 원장 | `users/{uid}/qoinTransactions` | `:182` | ✅ |
| R-U4 | 내 주문 | `orders` where `userId==uid` orderBy `createdAt desc` | `:214` `resource.data.userId == uid()` | ✅ 인덱스 `userId,createdAt` **존재** |
| R-U5 | 즐겨찾기 | `users/{uid}/favoriteStores`, `/favoriteMenuItems` | `:197`, `:202` | ✅ (1차 미노출, 확장 지점) |
| R-U6 | 역할 연결 이력 | `users/{uid}/roleHistory` | `:191` | ✅ (1차 미노출) |
| W-U1 | 프로필 수정 | `users/{uid}` | `:139-152` self 화이트리스트(`:142`) — `displayName` `photoUrl` `updatedAt` 등 | 🚫 1차 쓰기 없음 → **Q6** |
| W-U2 | Qoin 잔액 수정 | `users/{uid}` | 화이트리스트 **부재** `:142`, create 금지 `:122` | ❌ CF 전담 |
| W-U3 | 리뷰 작성/수정 | `reviews/{storeId}_{uid}` | `:719-738` | 🚫 1차 비범위 (확장 지점 §10) |
| W-U4 | 게시글 / QnA | — | **컬렉션 부재** → fallback deny `:820-822` | ❌ **별 과제 T1** |

### 5.6 CF 전담 — 역할과 무관하게 클라이언트가 쓸 수 없는 경로

| 경로 | Rules | 전담 CF |
|---|---|---|
| `orders` **create** | `:218` `allow create: if false` | `verifyTossPayment` |
| `users/{uid}/orderLogs` write | `:172-173` `false` | `verifyTossPayment` |
| `users/{uid}/qoinTransactions` write | `:183-185` `false` (**admin 도 불가**, append-only) | `onOrderQoinSettled` |
| `users/{uid}/roleHistory` write | `:192` `false` | `claimSubmittedBrand` |
| `users.brandId` | self 화이트리스트 부재 `:142` | `claimSubmittedBrand` |
| `users.qoinBalance` | `:122`, `:142` | `onOrderQoinSettled` |
| `{stores,brands,config/qoin}/qoinRateHistory` write | `:444`, `:578`, `:803` `false` | `setQoinAccrualRate` / `setQoinAccrualEnabled` / `applyBrandQoinRate` / `onQoinConfigWritten` |
| `stores.qoinAccrualRate` 등 5개 | `:341` / `:538` `touchesQoinManaged()` | 위 Qoin CF 들 |
| `config/qoin.accrualRate` | `:786`, `:793` | `setQoinAccrualRate` |
| `priceHistory` | `:646` `false` | `onMenuPriceWritten` 계열 (트리거) |
| `brandKeys/{key}` | `:654` `read, write: if false` (**읽기도 불가**) | `issueBrandKey` |
| `brands/{id}/keyHistory` write | `:601` `false` | `issueBrandKey` |
| `brands/*/private/profile.brandKey` | `:591`, `:594` | `issueBrandKey` |
| `stores.availableMainCategories` | `:332`, 화이트리스트 부재 | `onAvailableCategoriesWritten` 계열 |
| `stores.averageScore` / `.reviewCount` | 화이트리스트 부재 | `onReviewWritten` |
| `paymentGateRejections` / `storeDeletionHistory` | `:633`, `:637` `false` | 결제 게이트 / `deleteStore` |
| `qoinSettlementIssues` | `:814` `false` | `onOrderQoinSettled` |

### 5.7 Rules 는 허용하지만 **만들지 않는 것** (정책 금지)

| # | 항목 | Rules | 만들지 않는 이유 |
|---|---|---|---|
| **X1** | **역할 부여 / role 변경** | `:128` `allow update: if isAdmin()` — admin **전권** | 세션 탈취가 곧 권한 상승. §3-N3 |
| **X2** | **brand 의 자기 제출물 승인** | `brands/{id}/menuItems` `:607-608` · `stores/{sid}/menuOverrides` `:490-494` — 브랜드 보유자에게 **필드 제한 없음** → `status:'approved'` 를 스스로 쓸 수 있다 | **승인 경계는 현재 Rules 가 아니라 앱 리포지토리(`_assertAdminOnly`)만 집행한다.** 콘솔이 노출하면 그 경계가 사라진다. 이 비대칭 자체가 **별 과제 T2** |
| **X3** | **owner 주문 상태 전이** | `:234-298` O1/O5/O6/O7 | 운영 사고. §3-N1 |
| **X4** | **brand 의 `stores/{id}` 본문 수정** | `:403-435` `isStoreOwnerBrandUpdate` | 앱도 주지 않는다 (V6 결정). §5.3 W-B14 |
| **X5** | **admin 의 다른 역할 대행** | `:224` O4 **전권** — 점주 분기의 전이·필드 제약을 **받지 않는다** | 잘못된 모양의 쓰기가 막히지 않아 조용히 성공한다. §3-N6 → 별 과제 T4 |

---

## 6. payload 가드 — `console-payloads.js` (역할별 확장)

기존 `landing/console/assets/console-payloads.js` 는 액션별 **정확한 키 집합**을 상수로 두고 `assertPayload` 로 런타임 검증한다 (SDK 미import → node 로 단독 검증 가능). **이 방식을 역할별로 확장**한다.

### 6.1 현재 구조의 한계

`assertPayload` 는 **키 집합의 정확한 일치**만 본다 (`shape` 밖 키 거부 + `shape` 의 모든 키 필수).
승인/반려에는 맞지만 owner/brand 액션에는 부족하다:

- `onlyChangedFields` 화이트리스트 액션(W-B1 · W-B2 · W-O5 · W-O6 · W-O14)은 **부분집합 전송이 정상**이다. 정확 일치를 요구하면 "변경된 것만 보내기" 를 할 수 없다.
- 반대로 **보내면 안 되는 키**(§5.1 금지선, `approvedBy`/`approvedAt`/`brandKey`/`createdAt`)를 액션별로 선언할 곳이 없다.

### 6.2 확장 설계

```
PAYLOAD_SHAPES = {
  '<role>.<action>': {
    mode:      'exact' | 'subset',   // exact = 키 집합 정확 일치, subset = allowed 의 부분집합
    allowed:   [...],                // 허용 키
    required:  [...],                // subset 모드에서도 반드시 있어야 하는 키 (updatedBy / updatedAt 등)
    forbidden: [...],                // 이 액션에서 특별히 금지 (approvedBy / approvedAt / brandKey / createdAt …)
    rules:     'firestore.rules:490-494',  // 근거 — 주석이 아니라 데이터로 둔다
  }
}
```

- **전역 금지 집합**은 액션과 무관하게 항상 검사한다 — `QOIN_MANAGED_FIELDS`(5) + `availableMainCategories` + `averageScore` + `reviewCount` + `qoinBalance` + `brandKey`.
- `rules` 는 **Rules 줄번호를 상수 안에 박아 둔다.** Rules 가 바뀌면 이 문자열이 낡고, 그것이 재검토 신호가 된다. (지금은 `web_admin_console` spec 의 줄번호가 낡은 것을 아무도 못 알아챘다 — §5.0)
- `mode:'exact'` 유지 액션: `admin.brandApprove` `admin.brandReject` `admin.storeApprove` `admin.storeReject` `brand.privateProfileCreate` (Rules `hasOnly`).
- `mode:'subset'` 신규 액션: `brand.brandSelfUpdate` `brand.privateProfileUpdate` `brand.masterMenuOperation` `owner.overrideSoldOut` `owner.overrideOptionDisable` `owner.storeMenuOperation`.
- `owner.overrideCreate` 는 `mode:'exact'` 16키 (§5.4 W-O7) — 키 누락이 Rules 거부가 아닌 **조용한 데이터 결함**(cascade 누락)을 만들므로 정확 일치로 묶는다.

### 6.3 가드의 위치

**`assertPayload` 는 개발 중 실수를 즉시 터뜨리는 방어선이고 보안 장치가 아니다.** 권위는 Rules 다 (기존 파일 주석의 문장을 유지한다). 가드의 값은 "Rules 가 거부할 payload 를 **전송 전에** 알려 주는 것" — Rules 거부는 `permission-denied` 하나로 뭉쳐 와서 어떤 필드가 문제였는지 알려 주지 않기 때문이다.

---

## 7. 액션 → Cloud Function 매핑 (실존 확인)

`functions/src/index.ts` export 목록과 각 파일을 직접 읽어 확인했다. **리전은 전부 `asia-northeast3`** → `getFunctions(app, 'asia-northeast3')` 를 명시해야 한다.

| 콘솔 액션 | CF | 입력 | 출력 | 주요 에러 코드 | 1차 |
|---|---|---|---|---|---|
| **브랜드 승인 (admin)** 1단계 | `issueBrandKey` | `{brandId:string}` | `{brandKey, alreadyIssued}` — **멱등** | `invalid-argument`(brandId 부재 `issueBrandKey.ts:85`) / `not-found`(브랜드 없음 `:44`) / `aborted`(5회 재시도 실패 `:47`) | ✅ |
| **brand 미연결 복구 (B10)** | `claimSubmittedBrand` | `{brandId:string}` | — | `unauthenticated` `:45` / `invalid-argument` `:49` / **`details.reason ∈ {already_linked, not_brand_account, not_submitter, brand_not_found}`** `:34-40` | ✅ |
| (참고) brandKey 조회 | `lookupBrandByKey` | `{brandKey:string}` | `{brandId,name,logoUrl}` | `unauthenticated` `:78` / `not-found` `:37,:42` / `resource-exhausted`(**분당 10회** `:16,:33`) | ✗ (N5 로 매장 등록 비범위) |
| (비범위 N8) 적립률 변경 | `setQoinAccrualRate` | `{scope:'global'\|'brand'\|'store', targetId?, rate?\|clear?, reason?}` — `rate`/`clear` **정확히 하나** | `{before, after, historyId, changed}` | `invalid-argument`(scope `:58` / targetId `:65` / rate 범위 `:84` / reason) / `not-found` `:102` / `failed-precondition`(일괄 적용 진행 중 `:108,:117`) | ✗ |
| (비범위 N8) 적립 스위치 | `setQoinAccrualEnabled` | `{scope:'store'\|'brand', targetId, enabled:bool, reason?}` | 이력 포함 결과 | `invalid-argument` `:52,:55,:58` / `not-found` `:69` / `failed-precondition` `:74,:83` | ✗ |
| (비범위 N8) 브랜드 일괄 적용 | `applyBrandQoinRate` | `{brandId, mode:'preserve'\|'overwrite', rate?\|clear?, reason?, resumeHistoryId?}` | 진행/집계 | `failed-precondition`("브랜드 값이 그 뒤에 변경됐어요" `:231,:236` / "already completed" `:216`) / `internal`(중단 → `resumeHistoryId` 재개 `:508`) | ✗ |
| (비범위 N9) 매장 삭제 | `deleteStore` | `{storeId, reason(2~200자, dryRun 아닐 때 필수), dryRun?}` | `{alreadyDeleted}` \| `{dryRun,affected,blockedBy}` \| `{deletionId,phase:'done',affected}` | `invalid-argument` `:253,:259` / `not-found` `:96` / `failed-precondition` + **`details.reason==='STORE_HAS_INFLIGHT_ORDERS'`** `:116` | ✗ |

**존재하지 않는 CF (기존 spec 의 정정 유지)**: `approveBrand` / `rejectBrand` / `approveStore` / `rejectStore` **CF 은 없다.** 승인·반려는 **클라이언트 Firestore 직접 쓰기**이고 Rules 의 admin 전권 분기로 통과한다. 단 **브랜드 승인은 2단계**다 — `issueBrandKey` 성공 **뒤에만** `status` 를 쓴다. 순서를 뒤집으면 **brandKey 없는 `approved` 브랜드**가 생기고, 앱 승인 큐는 `status=='pending'` 만 스트림하므로 **큐에서 영구히 빠져 키 발급 경로가 없어진다.**

**brand / owner 섹션의 1차 CF 호출은 `claimSubmittedBrand` 1건뿐이다.** 마스터 메뉴 · 오버라이드 · 메뉴 · 옵션 그룹 · 서브 카테고리 · 매출 조회는 **전부 Firestore 직접 접근 + Rules 집행 + 사후 트리거**(`onMenuPriceWritten` 계열, `onReviewWritten`, `onAvailableCategoriesWritten` 계열)다. **기존 CF 를 재구현하지 않는다.**

---

## 8. `/console/` 화면 구성 · 네비게이션 · 데이터 흐름

### 8.1 파일 구성

```
landing/console/
├── index.html                진입 (스크립트·스타일 로드만)
└── assets/
    ├── console.css           ../assets/style.css 의 CSS 변수만 사용 (색상 리터럴 0)
    ├── firebase-config.js    web config (시크릿 아님 — 근거 주석 유지)
    ├── console-data.js       Firebase SDK 접근. **SDK 는 이 파일에서만 import**
    ├── console-payloads.js   역할별 payload 상수 + assertPayload (SDK 없음, node 검증 가능)
    ├── console-format.js     표시 형식 / 에러 분류 / 입력 검증 (SDK 없음)
    ├── console-shell.js      로그인 · 역할 판정 게이트 · 셸 · 라우터 (역할 공통)
    ├── section-admin.js      admin 섹션 뷰 (기존 admin.js 에서 분리)
    ├── section-brand.js      brand 섹션 뷰
    ├── section-owner.js      owner 섹션 뷰
    └── section-customer.js   customer 섹션 뷰
```

> 기존 `admin.js` 는 **1,240줄 단일 파일**이다. 여기에 brand·owner·customer 뷰를 더하면 유지가 안 된다 → **셸/라우터와 섹션 뷰를 파일로 분리**한다. 셸이 역할 판정 후 해당 섹션 모듈만 동적 `import()` 하면 다른 역할의 코드를 내려받지도 않는다.

### 8.2 역할별 네비게이션

해당 역할의 항목만 렌더한다. **없는 메뉴를 비활성으로 보여주지 않는다** (기존 콘솔의 NAV 원칙 유지).

| 역할 | 그룹 / 항목 | 해시 |
|---|---|---|
| `admin` | **운영** 대시보드 / **승인 큐** 브랜드 · 매장 · 마스터 메뉴(읽기) · 매장 커스텀(읽기) / **조회** 매장 목록 · Qoin 현황 | 기존 유지 (`#/dashboard` `#/brands` `#/stores/pending` `#/stores` `#/menus` `#/overrides` `#/qoin`) |
| `brand` | **브랜드** 브랜드 정보 · 검토 현황 / **메뉴** 마스터 메뉴 · 서브 카테고리 · 옵션 그룹 / **가맹점** 산하 매장 | `#/b/info` `#/b/tracking` `#/b/menus` `#/b/subcats` `#/b/options` `#/b/stores` `#/b/stores/{id}` |
| `owner` | **매장** 내 매장 / **운영** 매출 · 받은 평가 / **메뉴** 메뉴 관리 · 서브 카테고리 · 옵션 그룹 | `#/o/store` `#/o/sales` `#/o/reviews` `#/o/menus` `#/o/subcats` `#/o/options` |
| `customer` | **내 정보** 프로필 · 주문 내역(Log) · Qoin | `#/u/profile` `#/u/log` `#/u/qoin` |

- 해시 1단은 **역할 네임스페이스**(`b` / `o` / `u`, admin 은 레거시 호환상 네임스페이스 없음)로 둔다. 역할이 바뀌어도 예전 해시가 **빈 화면이 되지 않고** 자기 역할 기본 화면으로 정규화된다 (확정 1의 근거를 라우터가 집행).
- 역할 밖 해시 → 해당 역할 기본 화면으로 되돌린다. **이 리다이렉트는 보안이 아니다** (R-SEC1).
- **brand 매장 목록은 읽기 전용임을 칩으로 표시**한다 (기존 `읽기` 칩 재사용). "브랜드가 산하 매장을 고칠 수 있다" 는 오해를 UI 가 만들지 않게 한다.

### 8.3 섹션 전제 게이트 (셸 유지, 섹션 안에서 안내)

| 역할 | 전제 | 미충족 시 |
|---|---|---|
| `brand` | `users.brandId` 가 비어 있지 않음 | **B10 게이트.** `brands where submittedBy==uid` 조회 → 1건이면 `claimSubmittedBrand` 호출 버튼, 0건이면 "앱에서 브랜드 등록을 먼저 완료해주세요". **등록 폼 없음** |
| `brand` | 브랜드 `status=='approved'` | 쓰기 허용 (Rules 는 승인 전에도 보유자 쓰기를 허용). 단 **"심사 중 — 고객에게 노출되지 않아요" 배너**를 상시 표시 |
| `owner` | `stores where ownerId==uid` 1건 이상 | "등록된 매장이 없어요 — 앱에서 매장을 등록해주세요" |
| `owner` | `store.status=='approved'` | 매출/메뉴 화면은 열되 상태 배너 표시 (앱 `SalesStoreStatusBanner` 와 동일) |
| `owner` | 메뉴 관리 노출 조건 | `store.brandId == null && status=='approved'` → 개인 매장 메뉴 CRUD. `brandId != null` → **품절·옵션 비활성만** (앱 조건 그대로) |
| `customer` | 없음 | 항상 열린다 |

### 8.4 데이터 흐름

```
브라우저 (landing/console)
  → console-payloads.js  assertPayload   ← 전송 전 가드 (보안 아님, 실수 차단)
  → console-data.js → Firebase JS SDK (Auth / Firestore / Functions[asia-northeast3])
  → Firestore Security Rules                       ← 권위 ①
  → (특권 작업만) Cloud Functions requireAdmin()    ← 권위 ②
  → Firestore
  → (사후) 트리거 CF: priceHistory / averageScore / availableMainCategories
```

- **Clean Architecture 는 `lib/` 의 규칙**이고 `landing/` 은 Flutter 앱이 아니다. CLAUDE.md 절대규칙 2("Firebase 직접 사용은 data 레이어에서만")는 `lib/` 의 레이어 규칙이므로 **위반이 아니다.** 다만 그 정신은 유지한다 — **SDK import 는 `console-data.js` 한 파일에만** 둔다. 이 판단을 **파일 주석으로 남긴다.**
- 낙관적 UI 금지. 쓰기 성공 응답 전에 목록을 바꾸지 않는다.

---

## 9. 역할 판정 · 변경 · 실패

### 9.1 판정 흐름

```
① Firebase Auth 로그인 (Email/Password | Google)
② users/{uid} 1회 read
③ 분기
   읽기 성공 + role ∈ {admin, brand, owner, customer} → 해당 섹션 셸
   읽기 성공 + 문서 부재 또는 role 필드 부재        → 'customer' 섹션
                                                      (Rules userRole() `:26-30` 과 동일 해석)
   읽기 성공 + role 이 모르는 문자열                 → fail-closed 게이트 (§9.2)
   읽기 실패 / 타임아웃                              → fail-closed 게이트 (§9.2)
④ 이후 모든 요청은 Rules 가 재판정 (③ 결과를 신뢰 근거로 쓰지 않는다)
```

**문서 부재와 읽기 거부를 구분한다.** `getDoc` 이 `exists:false` 로 **성공**하는 것은 정상 상태(legacy 계정)이고 Rules 가 `'customer'` 로 해석한다. 반면 `permission-denied`/타임아웃은 **비정상**이다 — Rules 는 본인 문서 읽기를 허용하므로(`:108`) 실패할 이유가 없다. 기존 콘솔의 `readUserRole` fail-closed 원칙을 그대로 쓰되, 이 두 경우를 섞지 않는다.

### 9.2 fail-closed 게이트

기존 `renderRoleFail` 을 그대로 쓴다 — 사유 분류(네트워크 / 읽기 거부 / 알 수 없음) + 다시 시도 + 로그아웃. 본문 DOM 도 데이터 요청도 만들지 않는다.

**기존 `renderNotAdmin`(5초 자동 로그아웃)은 더 이상 기본 경로가 아니다.** 역할별 콘솔에서는 admin 이 아닌 계정도 **정당한 사용자**다 → 자동 로그아웃은 **모르는 role 문자열**인 경우에만 남긴다(§10).

### 9.3 역할 변경 중 처리

`users.role` 은 앱에서 바뀔 수 있다 (`customer ↔ owner ↔ brand` 자가 전이 허용, `:158-165`). 콘솔은 역할을 **셸을 열 때 1회** 판정하므로 그 사이 바뀌면 네비가 낡는다.

- **C4 복구 경로**: 섹션의 주 read 가 `permission-denied` 로 실패하면 `users/{uid}` 를 재확인한다. 역할이 달라졌으면 **"권한이 바뀌었어요. 화면을 다시 구성했어요"** 안내 + 셸 재렌더. 같으면 §14 의 평범한 읽기 실패로 처리한다.
- **폴링하지 않는다.** 역할 변경은 드물고, 실패를 계기로 확인하는 쪽이 읽기 비용이 0 에 가깝다.
- 역할 변경으로 **진행 중이던 쓰기가 거부될 수 있다.** 그 거부를 성공으로 표시하지 않는다 (§14).

---

## 10. customer 섹션 — 현재 모습과 향후 확장 지점

### 10.1 지금

고객에게 **기능이 없다.** 그러나 "앱 쓰세요" 안내벽이 아니라 **아직 비어 있는 정식 섹션**으로 설계한다.

- 좌측 네비가 다른 역할과 **같은 모양**으로 보인다 (프로필 / 주문 내역 / Qoin).
- 1차 내용은 **읽기 전용 3화면**(U1~U3). 전부 기존 Rules 로 통과하는 본인 데이터다 (§5.5).
- **자동 로그아웃을 걸지 않는다.** 나중에 고객이 **머물 공간**이기 때문이다. 공용 PC 세션 방치 우려는 자동 로그아웃이 아니라 **명시 로그아웃 버튼 + Auth 기본 세션 만료**로 다룬다.
- "리뷰 · 게시글 · QnA 를 준비하고 있어요" 를 **빈 섹션 자리로** 표시한다 (비활성 메뉴가 아니라 본문 안의 안내).

### 10.2 향후 확장 지점 — 바탕 상태가 기능마다 다르다

| 기능 | 바탕 상태 | 콘솔에 넣을 때 필요한 것 |
|---|---|---|
| **리뷰** | **이미 있다.** `reviews` 컬렉션 + Rules `:695-743` + `onReviewWritten` CF(평점 집계) + `docs/tasks/store_reviews/` | **Rules 변경 불필요.** ① 내 평가 목록 — `reviews where userId==uid` 는 단일 필드라 지금도 가능하지만 `orderBy createdAt` 을 붙이면 **복합 인덱스(`userId,createdAt`)가 없다** → 정렬을 클라이언트에서 하거나 인덱스 추가(N15 로 지금 불가). ② 작성/수정은 `orderId` 주문 자격 `get()` 검증을 통과해야 하고(`:708-714`) `createdAt`/`updatedAt` 이 **`request.time` 과 정확히 같아야** 한다 → `serverTimestamp()` 필수. ③ 14일 기한은 **Rules 가 아니라 UI 가 강제**한다 → 콘솔도 같이 구현해야 한다 |
| **게시글** | **컬렉션 자체가 Rules 에 없다.** fallback deny `:820-822` | **새 Rules 필수** → **별 과제 T1.** 이 세션 불가 |
| **QnA** | 동일 | 동일 → **별 과제 T1** |
| 즐겨찾기 | Rules 있음 `:196-203` | 바로 가능 (1차 미노출) |
| Qoin 사용 | **미구현** (`backlog.md` Q2) | 기능 자체가 미설계 |
| 선물하기 | 미구현 | 미설계 |

**설계에 남기는 확장 지점**: `section-customer.js` 의 라우터를 `#/u/{view}` 로 두고, 뷰 등록을 **테이블 주도**로 만든다. 리뷰/게시글/QnA 는 각각 **뷰 1개 추가**로 끝나야 하고, 셸·네비·에러 분류·payload 가드를 다시 손대지 않아야 한다.

---

## 11. 기존 `landing/console/` 이관 계획

### 11.1 무엇을 그대로 쓰고 무엇을 바꾸는가

| 기존 파일 | 처리 | 바꾸는 것 |
|---|---|---|
| `index.html` | → `landing/console/index.html` | 제목/설명 문구를 "관리자 콘솔" → "운영 콘솔". 로드하는 스크립트 이름 |
| `assets/admin.css` | → `assets/console.css` | **거의 그대로.** 역할 배지 · 빈 섹션 안내 스타일 추가. **색상 리터럴 0 유지** |
| `assets/firebase-config.js` | → 그대로 복사 | **무변경** (근거 주석 포함). ⚠️ `apiKey`/`appId` 가 아직 비어 있으면 콘솔이 "설정이 필요해요" 를 띄운다 — 사용자 선행 작업 |
| `assets/admin-data.js` | → `console-data.js` | `initFirebase` · 타임아웃(read 15s / write 20s / key 30s) · `onAuthChanged` · 로그인 3종 · `readUserRole` · `rows`/`getList`/`getOne`/`countOf` · `guardedUpdate`/`stage`/`assertPendingNow` **전부 유지**. brand/owner/customer 쿼리 함수 **추가**. `readUserRole` 은 `{admin:bool}` → **`{role:string, exists:bool}`** 로 넓힌다 |
| `assets/admin-payloads.js` | → `console-payloads.js` | **§6 대로 확장.** 기존 4개 shape(`brandApprove`/`brandReject`/`storeApprove`/`storeReject`)와 그 주석·`assertPayload` 의 `storeReject`→`approvedAt` 금지 특례는 **그대로 유지**. `mode`/`required`/`forbidden`/`rules` 필드 추가 |
| `assets/admin-format.js` | → `console-format.js` | `esc` · `toDate` · `fmtDateTime` · `fmtKrw` · `safeUrl` · `normalizeStatus` · `STATUS_LABEL` · `validateReason` · `AdminError` · `classifyError` · `readErrorText` · `writeErrorText` · `loginErrorText` **전부 유지**. 매출 기간 포맷(KST 일/주/월 라벨) · 등급 배지(S/A/B/C) 추가 |
| `assets/admin.js` (1,240줄) | → `console-shell.js` + `section-admin.js` 로 **분할** | 셸·게이트·라우터·공용 위젯(`skel` `banner` `emptyBlock` `errorBlock` `statusBadge` `thumb` `kv` `tableHtml` `makeLoader` `navButtons` `detailSkeleton` `panelFailHtml` `toast` `modal`)은 `console-shell.js` 로. admin 뷰(`viewDashboard` `viewBrandQueue` `viewBrandDetail` `viewStoreQueue` `viewStoreDetail` `viewMenus` `viewReadOnlyQueue` …)는 `section-admin.js` 로. **admin 기능 동작은 변경 없음** |
| `README.md` | → `landing/console/README.md` | 접근 주소 · 파일 표 · 역할 설명 갱신 |

### 11.2 이관 순서 (충돌 회피)

1. **tester 가 `docs/tasks/web_admin_console/` 작업을 끝낼 때까지 `landing/console/` 을 건드리지 않는다.** 지금 사용 중이다.
2. test_report 의 FAIL 이 해소된 뒤, **`git mv` 로 한 커밋에 이동**한다 (히스토리 보존).
3. 그 다음 커밋부터 분할·확장. 이동과 수정을 같은 커밋에 섞지 않는다 — 섞으면 diff 가 전부 신규 파일로 보여 "admin 기능이 안 변했다" 를 리뷰에서 증명할 수 없다.

### 11.3 앱에서 발견한 기존 결함 — 콘솔이 **복제하지 않는다**

`lib/` 은 읽기 전용이라 고칠 수 없다. 콘솔이 같은 결함을 재생산하지 않는 선까지만 하고, 앱 수정은 **별 과제 T6**.

| # | 결함 | 콘솔의 처리 |
|---|---|---|
| **ⓐ** | 품절 토글이 `disabledOption*` 를 빈 배열로 덮어써 **옵션 비활성 설정을 전부 지운다** | **3키만 보낸다** (W-O5) |
| **ⓑ** | 점주 오버라이드 create 에 **`masterMenuItemId` 필드 누락** → 마스터 메뉴 삭제 cascade / 사용 수 집계에서 누락 | **포함한다** (W-O7) → Q2 |
| **ⓒ** | 메뉴 핵심 수정이 `createdAt` 을 전체 payload 로 보내 **매 수정마다 현재 시각으로 리셋** | **`createdAt` 을 update 에 넣지 않는다** (W-O2) |
| **ⓓ** | 전체 payload update 가 `if (x != null)` 로 키를 생략해 **`description`/`subCategoryId` 를 비워도 지워지지 않는다** | 비우기를 지원하면 **`deleteField()` 를 명시**한다 |
| **ⓔ** | 노출(visible) 인라인 토글이 **핵심 전체 update** 를 호출 (ⓒ·ⓓ 가 여기서 같이 터진다) | **운영 필드 경로**로 보낸다 (W-O3) |
| **ⓕ** | 오버라이드 upsert 의 **read-then-set 레이스** | `updateDoc` → `not-found` → create 순서 (W-O8) |
| **ⓖ** | brand 검토 현황이 `status=='approved'` 로 필터된 소스를 쓰므로 **매장 pending/rejected 가 절대 표시되지 않는다** | 쿼리를 분리해 올바르게 표시 (B9) |
| **ⓛ** | `cascadeDeleteOverrides` 가 **no-op** (`master_menu_item_remote_data_source.dart:146-154`). 주석의 전제("menuOverrides 컬렉션이 아직 없다")가 낡았다 → **마스터 메뉴를 지워도 매장 오버라이드가 남고**, 같은 id 로 마스터가 재생성되면 과거 가격·제외·품절이 **되살아난다** | 콘솔은 cascade 를 **실제로 수행**한다 (W-B8). 앱 수정은 T6 |
| **ⓗ** | `MasterMenuItemRepositoryImpl.countStoresUsingPriceOverride` 가 **항상 0 을 반환하는 스텁** | 실제 집계 경로(`collectionGroup(menuOverrides)` where `masterMenuItemId` + `status=='approved'` + `priceOverride != null`)를 쓴다 |
| **ⓘ** | `_assertOwnershipOrAdmin` 이 **아무것도 검증하지 않는 빈 함수** | UI 게이팅은 `store.brandId`/`status`/`ownerId` 로 직접 건다. 실권한은 Rules (§4.2) |
| **ⓙ** | 매장 이미지 업로드만 **5MB 검증 누락** | 콘솔은 모든 업로드에 5MB 상한을 건다 |
| **ⓚ** | 죽은 배선 — brand 의 `approveStoreOnlyMenu*` provider(호출 지점 없음), `MenuOverrideModel.toFirestoreForApprove/Reject`(미사용, reject 가 리포와 불일치) | **옮기지 않는다** |

### 11.4 기존 `/admin/` 경로 처리 — **제거 (리다이렉트 없음)**

- **근거**: `landing/console/` 은 **아직 한 번도 배포된 적이 없다** (git status 상 untracked, README 가 "PG 심사 종료까지 배포하지 않는다" 를 명시). 공개 URL 로 존재한 적이 없으므로 **보호할 북마크도 외부 링크도 없다.**
- 따라서 리다이렉트를 두지 않는다. 입구를 2개 두면 "어느 쪽이 최신인가" 를 매번 확인해야 하고, 그 비용이 존재하지 않는 북마크를 지키는 값보다 크다.
- 로컬 개발용 북마크는 사용자에게 **새 주소를 알리는 것**으로 끝낸다 (§15).

---

## 12. 라우팅 · rewrite · `firebase.json`

### 12.1 문제

현재 hosting 블록에 `trailingSlash: false`, `cleanUrls: false` 가 걸려 있다.

- `trailingSlash: false` → `/console/` 는 **301 로 `/console` 로 보내진다.**
- `cleanUrls: false` → `/console` 은 `/console.html` 로도, 디렉토리 인덱스로도 해석되지 않는다.
- 결과: **`/console` 이 404 로 떨어진다.** 그래서 기존 콘솔은 `/console/index.html` 로 접근하도록 안내돼 있었다.

### 12.2 결정 — hosting 블록에 rewrite 1개 추가

규칙 2(§4.1)가 **hosting 블록 수정은 허용**한다. 다른 블록(`functions` / `firestore` / `storage` / `flutter` / `emulators`)은 건드리지 않는다.

`hosting` 객체 안에 다음을 **추가**한다 (기존 키는 그대로):

```
"rewrites": [
  { "source": "/console", "destination": "/console/index.html" }
]
```

- **`/console/**` 로 넓히지 않는다.** Hosting 은 정적 파일을 먼저 찾으므로 넓혀도 자산 로딩이 깨지지는 않지만, 좁은 규칙이 의도를 더 정확히 말한다. 콘솔은 **해시 라우팅**(`#/b/menus`)이라 서버 경로는 `/console` 하나뿐이다.
- **랜딩 URL 동작에 영향이 없다.** `source` 가 `/console` 단일 경로이고, rewrite 는 정적 파일이 없을 때만 동작한다.
- **헤더**: 기존 `**/*.@(html)` 의 `no-cache` 가 `/console/index.html` 에 그대로 적용된다 ✅. 기존 `/assets/**` 의 1시간 캐시는 **루트 기준이라 `/console/assets/**` 에 적용되지 않는다** → 콘솔 자산은 캐시 헤더 없이 간다. **일부러 추가하지 않는다** — 배포 직후 1시간 동안 낡은 콘솔 JS 가 돌면 "고쳤는데 안 바뀐다" 가 된다.
- ⚠️ **리다이렉트 → rewrite 순서는 배포 후 실측 항목이다.** `/console/` → 301 `/console` → rewrite `/console/index.html` 이 기대 동작이지만, 이것은 Hosting 의 처리 순서에 의존하는 경험적 사실이다. **`/console/index.html` 은 rewrite 와 무관하게 항상 열린다** → 1차 안내 주소는 이쪽으로 하고, `/console` 이 열리는지는 배포 후 확인한다 (§15).

### 12.3 해시 라우팅 규칙

- 형태: `#/{ns}/{view}[/{id}]` — `ns ∈ {b, o, u}`, admin 은 레거시 호환상 `ns` 없음.
- 알 수 없는 해시 / 다른 역할의 해시 → 자기 역할 기본 화면으로 교체 (`replace`, 히스토리 오염 방지).
- 역할 기본 화면: admin `#/dashboard` · brand `#/b/info` · owner `#/o/store` · customer `#/u/profile`.

---

## 13. 이력 / 감사 추적 (`audit_trail.md` §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| **1** | **돈 · 권한 · 정책 값을 바꾸는가?** | **예, 세 종류를 바꾼다.** ⓐ **권한 값** — admin 의 `stores.status`/`approvedAt`, `brands.status`(결제 게이트 `canSellNow` 의 판정 입력). ⓑ **돈 값** — brand 의 `basePrice`·`priceOverride`, owner 의 `basePrice`·옵션 `priceDelta`. ⓒ **정책 값** — 메뉴 노출/제외(`visible`/`excluded`), 승인 상태 회귀. → **설정 변경 이력이 필요하다.** 아래 2·3·4 에서 "기존 설계가 이미 남긴다" 를 경로별로 확인했고, **새 이력 스키마를 만들지 않는 사유**를 §13.1 에 적었다 |
| **2** | 덮어쓰기로 사라지는 값이 있는가? | **있다.** 승인/반려 메타는 문서에 **1세대만** 남아 재심사 이력이 덮인다. 가격은 `priceHistory` 가 before/after 를 남겨 사라지지 않는다. `soldOut`·`visible`·옵션 비활성은 **상태값**이고 복구 가능하므로 이력 대상으로 보지 않는다. 승인 이력 1세대 한계는 **기존 설계의 알려진 한계**이고 콘솔이 새로 만드는 손실이 아니다 → 별 과제 T3 |
| **3** | 거래/기록이 정책 값을 참조만 하는가? | **콘솔은 거래 문서를 만들지 않는다** (`orders` create 는 `:218` 에서 전면 차단, CF 전담). 해당 없음. 매출 조회는 **읽기 전용 집계**이고 결과를 저장하지 않는다 |
| **4** | **"누가" 가 기록되는가?** | **예, 세 경로 모두.** ⓐ 승인/반려 → payload 의 `approvedBy = 로그인 uid` (빠지면 Console 수동 편집과 구별되지 않는 이력이 된다 → **tester 필수 검증**). ⓑ 가격 → `priceHistory.changedBy = actor.authId`, **트리거가 이벤트의 인증 주체를 자동 기록**한다(`functions/src/onMenuPriceWritten.ts:91,:106`) → 콘솔이 할 일이 없다. ⓒ 제출/수정 → `submittedBy` · `updatedBy`(`'admin'`/`'brand'`/`'owner'`). **`updatedBy` 를 역할 문자열로 정확히 채우는 것이 콘솔의 유일한 추가 의무다** |
| **5** | 일괄 처리(batch)가 있는가? | **마스터 메뉴 삭제 cascade 1건**(W-B8)이 유일하다. 앱과 동일하게 **영향 범위(대상 매장 수)를 삭제 전에 사용자에게 보여준다**. 다만 **Firestore 에 묶은 이력을 남기지 않는다** — 그 쓰기 주체는 CF 여야 하고(`audit_trail` "쓰기 주체는 CF 가 기본") `functions/` 는 읽기 전용이다 → 별 과제 T5. **다중 선택 일괄 승인은 의도적으로 비범위** (기존 spec 의 판단 유지) |
| **6** | CF 로그에 의존하지 않는가? | **의존하지 않는다.** 판단 근거는 전부 Firestore 문서(`priceHistory`, 승인 메타, `qoinRateHistory`)에 있다. Cloud Logging 은 보존 기간이 있어 영구 기록으로 믿지 않는다 |
| **7** | 권한 판정 필드의 `create`/`update` **교차 확인** | **했다.** §5 의 모든 행을 create/update 양쪽으로 나눠 적었다. 핵심 확인: ⓐ `stores` create 의 승인 메타 자가 설정 금지(`:325-329`)와 `availableMainCategories` 금지(`:332`) — 콘솔은 **`stores`/`brands` 를 create 하지 않는다**. ⓑ `menuOverrides` 는 점주 create 가 `ownerOverrideCreateOk()`(`:475-482`), update 가 5키 화이트리스트(`:494`)로 **서로 다른 장치**를 쓴다 → W-O7/W-O5 를 따로 검증한다. ⓒ `brands/private/profile` 은 create `hasOnly`(`:591`) / update `onlyChangedFields`(`:594`) 양쪽 모두 5키다. ⓓ **정상 payload 가 여전히 통과하는 회귀 케이스**를 §16 tester 항목에 포함했다 |

### 13.1 새 이력 스키마를 만들지 않는 사유 (체크리스트 1의 명시 요건)

1. **콘솔은 새 정책 값을 도입하지 않는다.** 같은 필드를 같은 경로로 쓰고, 값의 종류와 범위도 앱에서 그대로 옮긴다.
2. **가격 이력은 쓰기 경로와 무관하게 남는다.** `onMenuPriceWritten` 계열 6개 트리거는 **클라이언트 직접 쓰기도 포착**하며 `changedBy` 에 인증 주체 uid 를 기록한다. 웹에서 바꾼 가격도 자동으로 남는다 — **표면이 늘어도 이력에 구멍이 생기지 않는다.** 이것이 트리거 기반 이력의 값이다.
3. **쓰기 주체는 CF 가 기본**(`audit_trail` §4 "남기는 형식")이고 `functions/` 는 이 세션 읽기 전용이다. 클라이언트가 쓰는 이력은 위조·누락되므로 **지금 만들면 안 되는 종류**다.
4. **남지 않는 것을 명시한다**: ⓐ **액션 출처(앱/웹)** — 같은 uid 의 같은 쓰기라 구별되지 않는다 → 별 과제 T7. ⓑ **매장 운영 정보 변경**(`audit_trail` A2 의 기존 공백) — 1차에서 owner 매장 정보 수정을 비범위로 둬서 **이번에는 새로 늘지 않는다**(Q3 가 범위로 바뀌면 이 공백이 웹 표면에도 생긴다 → Q3 의 비용). ⓒ **메뉴 노출/제외·품절 변경** — 상태값으로 보고 남기지 않는다.

---

## 14. 에러 처리

### 14.1 인증 / 역할

| 상황 | 처리 |
|---|---|
| 미로그인 | 로그인 화면만. **데이터 요청 0건** |
| 로그인 성공 + 역할 판정 성공 | 해당 섹션 셸 |
| `users/{uid}` 문서 부재 / `role` 필드 부재 | **`customer` 섹션** (Rules 와 동일 해석, §9.1) |
| `users/{uid}` 읽기 실패 · 타임아웃 | **fail-closed 게이트.** 사유 분류 + 다시 시도 + 로그아웃 |
| `role` 이 모르는 문자열 | fail-closed 게이트. **이 경우만** 자동 로그아웃 유지 |
| 세션 중 역할 변경 | 섹션 read 가 `permission-denied` → `users/{uid}` 재확인 → 달라졌으면 안내 + 셸 재렌더 (§9.3) |
| 세션 만료 | 로그인 화면 + "세션이 만료되었어요. 다시 로그인해주세요." |
| `auth/unauthorized-domain` | "호스팅 도메인을 Firebase Auth 승인 목록에 추가해야 합니다" — **배포 직후 가장 흔한 실패** |
| web config 미설정 | "설정이 필요해요" 게이트 (기존 구현 유지) |

### 14.2 섹션 전제 미충족

| 상황 | 처리 |
|---|---|
| brand 인데 `users.brandId` 없음 | **B10 게이트** — `claimSubmittedBrand` 버튼 또는 "앱에서 등록 먼저". 셸은 유지 |
| `claimSubmittedBrand` 실패 | `details.reason` 별로 다르게 안내 — `already_linked`(새로고침 유도) / `not_brand_account`(역할 안내) / `not_submitter`(권한 안내, **재시도 버튼 없음**) / `brand_not_found` |
| owner 인데 매장 없음 | "등록된 매장이 없어요" + 앱 안내. 셸 유지 |
| 매장/브랜드 미승인 | 화면은 열고 **상태 배너** 표시 |

### 14.3 Firestore Rules 거부

| 상황 | 처리 |
|---|---|
| `permission-denied` (read) | **해당 카드만** "권한이 없어 불러올 수 없습니다". 전체 화면을 깨지 않는다. + §9.3 역할 재확인 |
| `permission-denied` (write) | "저장되지 않았습니다" + **목록에서 항목을 제거하지 않는다.** 낙관적 UI 금지 — 권한 거부를 성공으로 보이게 하면 안 된다 |
| 전역 금지 필드가 섞여 거부 | **구현 버그다.** §6 가드가 전송 전에 터뜨려야 했다. tester 검증 항목 |
| `menuOverrides` 5키 화이트리스트 위반 | **구현 버그.** W-O5/W-O6 의 키 수를 확인. 특히 **create 분기가 update 로 판정된 경우**(W-O8 레이스) |
| 쿼리에 `where storeId==` 누락 | **구현 버그.** rules-aware query 라 쿼리 전체가 거부된다 (R-O2) |
| 인덱스 부재 (`failed-precondition`) | **콘솔은 인덱스를 추가할 수 없다**(N15). 쿼리를 기존 인덱스 안으로 바꾼다. 기존 `failWithIndexHint` 를 유지해 원인을 분명히 보여준다 |

### 14.4 Cloud Function 에러

| code | 처리 |
|---|---|
| `unauthenticated` | 로그인 화면 + "다시 로그인해주세요" |
| `permission-denied` | 서버 재검증 실패 — "권한이 없습니다". **화면을 숨기지 않았던 실수가 아니라 권위가 서버에 있다는 정상 동작** |
| `invalid-argument` | 해당 입력 필드에 에러. CF message 를 그대로 보여준다(한국어 메시지가 있다) |
| `not-found` | "대상을 찾을 수 없습니다. 목록을 새로 고쳐주세요" + 목록 갱신 |
| `failed-precondition` + `details.reason` 토큰 있음 | 토큰별 전용 안내 |
| `failed-precondition` (토큰 없음) | CF message 그대로 + 새로 고침 유도. **토큰 없는 `failed-precondition` 을 특정 가드로 해석하지 않는다** (기존 `classifyDeleteError` 원칙) |
| `resource-exhausted` | "잠시 후 다시 시도" |
| `aborted` / `internal` | "실패했습니다. 다시 시도해주세요". **성공으로 표시하지 않는다** |
| 응답 파싱 실패 | **실패로 처리.** 숫자를 못 읽은 것을 "0건" 으로 읽지 않는다 (기존 `parsePreview` 원칙) |

### 14.5 그 외

| 상황 | 처리 |
|---|---|
| 네트워크 오프라인 | "연결을 확인해주세요" + 재시도. **쓰기 큐를 쌓지 않는다** (오프라인 영속성 비활성) |
| 매출 1,000건 절단 | "주문이 많아 최근 1,000건만 집계했어요" — **에러가 아니다** |
| 매출 0원 | **빈 상태로 표시하되 "조회 실패" 와 구분**한다. 서버 강제 읽기이므로 0원은 사실이다 |
| 이미지 5MB 초과 | "이미지 용량이 5MB를 초과했습니다. (x.xMB)" (앱 문구 그대로) |
| 이름 중복 (서브 카테고리 / 옵션 그룹) | 인라인 — "이미 같은 이름의 분류가 있어요" / "이미 같은 이름의 옵션 그룹이 있어요" (앱 문구 그대로) |
| 사용 중 삭제 시도 | 차단 + 사용 수 표시 (앱과 동일) |
| 빈 목록 | empty 상태. **에러와 구분** |

---

## 15. 배포 절차 (사용자가 수행)

> **프로덕션 반영이므로 Claude 가 실행하지 않는다.** 또한 **토스 PG 심사 종료 전에는 배포하지 않는다** (확정 2). 심사 중에는 코드 머지까지만.

### 15.1 배포 전 확인 (사용자)

1. **다른 세션의 결제 배포 작업이 진행 중이 아닌지** 확인. 같은 hosting 블록·같은 명령을 공유한다.
2. `landing/console/assets/firebase-config.js` 의 `apiKey`·`appId` 가 채워져 있는지. 비어 있으면 "설정이 필요해요" 화면만 나온다.
3. Firebase Console → Authentication → Settings → **승인된 도메인**에 `order-app-5957e.web.app` (및 커스텀 도메인). 없으면 `auth/unauthorized-domain` 으로 로그인이 실패한다.
4. Authentication → Sign-in method 에서 **Email/Password 와 Google** 활성 확인.
5. 콘솔로 쓸 계정의 `users/{uid}.role` 이 의도한 값인지 Firestore Console 에서 확인 (**admin 은 수동 설정만**).
6. `landing/{index,terms,privacy,refund}.html` 의 diff 가 **0** 인지 확인.

### 15.2 로컬 확인 (배포 전, 공개되지 않음)

터미널에서 아래 한 줄을 그대로 실행한다. 종료는 `Ctrl+C`.

```
cd /Users/Byeonguk/Developer/OrderApp/landing && python3 -m http.server 5500
```

브라우저에서 `http://localhost:5500/console/index.html` 로 접속한다. ES 모듈을 쓰므로 `file://` 로 열면 동작하지 않는다. (로컬 정적 서버에는 Hosting 의 rewrite 가 적용되지 않으므로 `/console` 이 아니라 `/console/index.html` 로 연다.)

### 15.3 배포 명령

프로젝트 루트 터미널에서 **아래 한 줄만** 실행한다.

```
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

- 이 명령은 `landing/` 전체(랜딩 4페이지 + `landing/console/`)를 함께 올린다.
- **전체 `firebase deploy` 를 쓰지 않는다.** 루트 `firebase.json` 에는 `functions`·`firestore`·`storage` 설정이 같이 들어 있어, 운영 중인 결제 함수(`verifyTossPayment` — enforce 모드)와 Firestore Rules 까지 배포된다.
- `--project order-app-5957e` 도 생략하지 않는다.

### 15.4 배포 후 확인 (사용자)

랜딩 4개가 그대로인지 **먼저** 확인한다.

```
https://order-app-5957e.web.app/index.html
https://order-app-5957e.web.app/terms.html
https://order-app-5957e.web.app/privacy.html
https://order-app-5957e.web.app/refund.html
```

그 다음 콘솔. **아래 주소는 rewrite 와 무관하게 항상 열린다.**

```
https://order-app-5957e.web.app/console/index.html
```

**rewrite 실측** — 아래 두 주소가 콘솔로 열리는지 확인한다 (§12.2 의 경험적 항목).

```
https://order-app-5957e.web.app/console
https://order-app-5957e.web.app/console/
```

열리지 않으면 **안내 주소를 `/console/index.html` 로 유지**하고 rewrite 조정을 별 과제로 둔다. 콘솔 기능에는 영향이 없다.

마지막으로 역할별 로그인을 확인한다 — admin / brand / owner / customer 계정 각각으로 들어가 **자기 섹션만 보이는지**, 그리고 **다른 역할 해시를 직접 입력했을 때 되돌려지는지**.

### 15.5 롤백

```
cd /Users/Byeonguk/Developer/OrderApp && firebase hosting:rollback --project order-app-5957e
```

또는 Firebase Console → Hosting → 이전 버전 → 롤백.

---

## 16. 작업 분배

### designer — **호출 필요**

산출물: `docs/tasks/web_role_console/design.md`

- **Q1~Q6 답을 받은 뒤 시작**한다. Q3(owner 매장 정보 수정)이 화면 개수를 바꾼다.
- **기존 `docs/tasks/web_admin_console/design.md` (1,073줄)를 출발점으로 쓴다.** admin 섹션은 **재디자인하지 않는다** — 셸이 역할 배지와 역할별 네비를 갖도록 확장하는 것까지만.
- 설계할 것:
  - **역할별 네비 구조**(§8.2)와 **역할 배지**(UI4). 현재 어떤 권한으로 보고 있는지가 상시 보여야 한다.
  - **brand 섹션** — 브랜드 정보 / 마스터 메뉴 목록·폼 / 가맹점 목록(읽기 칩) / 매장별 커스터마이즈 2탭 / 검토 현황 / 서브 카테고리 / 옵션 그룹.
  - **owner 섹션** — 내 매장 요약 / 매출(기간 전환 pill + 요약 카드 + 주문 목록) / 받은 평가 / 메뉴 목록·폼 / 브랜드 매장용 "품절·옵션만" 화면.
  - **customer 섹션** — 프로필 / Log / Qoin **3화면 + 빈 섹션 안내**. §10 의 "안내벽이 아니라 비어 있는 정식 섹션" 을 시각적으로 구현한다. 리뷰·게시글·QnA 자리를 **어떻게 비워 둘 것인지**가 이 섹션 디자인의 핵심이다.
  - **섹션 전제 게이트 4종**(§8.3) — brand 미연결 / 매장 없음 / 미승인 / 모르는 역할.
  - **파괴적 액션의 위계**(UI5) — 특히 **"핵심 수정 → status 회귀 → 재심사"** 를 사용자가 저지르기 전에 이해하게 만드는 것. 이것이 brand/owner 섹션에서 가장 사고가 날 지점이다.
  - loading / error / empty **3종 상태를 모두** 그린다 (§2.7).
- **색상**: `landing/assets/style.css` 의 기존 CSS 변수만. **새 색상값 도입 금지.**
- **문구**: 앱 문구를 **그대로 옮긴다.** §14.5 와 §5.4 주석의 문장들은 값이다 — 새로 쓰지 않는다.
- Qradar 용어 — Qoin / Qrator / Log.

### developer — **호출 필요 (designer 이후)**

산출물: `docs/tasks/web_role_console/implementation.md`

**구현 항목**: §2 의 C1~C6 · (admin 이관) · B1~B11 · O1~O7 · U1~U5.

**재사용할 기존 구조** — 값을 새로 정하지 않는다:

| 영역 | 원본 |
|---|---|
| 콘솔 셸 · 게이트 · 라우터 · 공용 위젯 · 에러 분류 | `landing/console/assets/*.js` (§11.1) |
| 승인/반려 필드 집합 | `lib/data/models/store_model.dart` `approveFields`/`rejectFields`, `lib/data/repositories/brand_repository_impl.dart:174-199` |
| 마스터 메뉴 / 메뉴 / 오버라이드 필드 집합 | `lib/data/models/{menu_item_model,menu_override_model}.dart`, `lib/data/repositories/{master_menu_item,menu_item,menu_override}_repository_impl.dart` |
| 매출 집계 | `lib/domain/usecases/get_store_sales_use_case.dart` `aggregateStoreSales`, `lib/domain/entities/sales_period.dart`, `lib/core/utils/kst.dart`, `lib/core/constants/sales_query_limits.dart` |
| 검증 상수 | §16 "그대로 가져갈 상수" |
| 색상 | `landing/assets/style.css` CSS 변수 |

**그대로 가져갈 상수 (값을 새로 정하지 않는다)**:

- status 문자열: `pending` / `approved` / `rejected`. ⚠️ 앱 `fromString` 의 **default 가 `approved`** 다 — 모르는 문자열을 승인으로 읽지 않도록 콘솔은 **명시적으로 3값만** 받는다.
- `updatedBy`: `admin` / `brand` / `owner`.
- 태그 허용값: `recommended` / `new` / `best`.
- `selectionType`: 브랜드 옵션 그룹 `single`/`multi`, **매장 옵션 그룹 `single`/`multiple`** (⚠️ 앱에서 값이 다르다 — 각 경로의 값을 그대로 쓴다).
- `scope`(menuItem): `brand` / `store`. `scope`(optionGroup ref): `master` / `brand` / `store`.
- 길이 제한: 브랜드 이름 30 · 브랜드 설명 60 · 회사명 30 · 담당자 이름 30 · 메뉴 이름 40 · 옵션 그룹 이름 30 · 서브 카테고리 이름 20 · 매장 설명/공지 200.
- 정규식: 사업자번호 `^\d{3}-\d{2}-\d{5}$` · 연락처 `^\d{2,3}-\d{3,4}-\d{4}$` · brandKey `^BR-[A-Z2-9]{8}$`.
- 가격: `basePrice > 0` (상한 없음) · `priceOverride` 는 숫자만, null 허용, 0 허용.
- 이미지 5MB · 중복 검사 디바운스 300ms.
- 매출: 1,000건 상한 · 12개월 전까지 · KST · 주 = 월요일 시작 / ISO 목요일 소속.
- **필드 키 함정**: 엔티티 `mainCategoryCode` → Firestore 키는 **`mainCategory`**. 오버라이드 문서는 `masterMenuItemId` 를 **문서 ID 와 필드 양쪽에** 기록해야 cascade / 집계가 동작한다. `optionGroupRefs` 와 `optionGroupRefIds` 를 **둘 다** 쓴다. `disabledOptionItemIds` 원소는 **복합 id `{groupId}_{itemId}`**.
- 문서 ID 규칙: 서브 카테고리 `{mainCategoryCode}_{millis}` (**클라이언트 생성**) · 오버라이드 `{masterMenuItemId}` · 리뷰 `{storeId}_{userId}`.
- Storage 경로: 메뉴 `menu_images/{brand|store}/{id}/{menuItemId}/{millis}_{filename}` · 브랜드 로고 `brand_images/{brandId}/{millis}_{filename}` · 매장 `store_images/{ownerId}/{millis}_{filename}`.

**주의할 규칙**:

- 코드는 **`landing/console/` 밖으로 나가지 않는다.** `lib/` · `functions/` · `firestore.rules` · `firestore.indexes.json` · `storage.rules` 수정 **금지**.
- `firebase.json` 은 **hosting 블록의 `rewrites` 1개 추가만** (§12.2). 다른 블록 금지.
- **`landing/{index,terms,privacy,refund}.html` 과 `landing/assets/style.css` 를 수정하지 않는다.** 심사 자료다. 콘솔 전용 스타일은 `landing/console/assets/console.css` 에 둔다.
- **§6 의 payload 가드를 먼저 만들고 그 다음 화면을 만든다.** 순서를 뒤집으면 Rules 가 거부하는 모양의 쓰기가 UI 전제로 굳는다.
- **§5.1 전역 금지 필드를 어떤 payload 에도 넣지 않는다.**
- **`menuOverrides` 점주 update 는 Rules 화이트리스트 5개가 상한**이다. 품절 토글은 **3키**, 옵션 비활성은 **4키** (§5.4).
- **오버라이드 upsert 는 `updateDoc` → `not-found` → create 순서** (W-O8).
- **오버라이드 create 에 `masterMenuItemId` 를 넣는다** (W-O7).
- **메뉴 update payload 에 `createdAt` 을 넣지 않는다** (W-O2).
- **브랜드 정보 수정은 좁은 payload** — `approvedBy`/`approvedAt`/`createdAt`/`brandKey` 를 보내지 않는다 (W-B1).
- **매출 쿼리는 `where storeId==` 를 반드시 포함**하고 **서버 강제 읽기**(`getDocsFromServer`)를 쓴다 (R-O2).
- **인덱스를 추가할 수 없다.** 새 쿼리는 §5 의 "인덱스 존재" 표시가 있는 조합만 쓴다. 특히 `collectionGroup('menuOverrides')` + `where brandId` 는 인덱스가 없다 (R-B11).
- **마스터 메뉴 삭제 cascade 는 콘솔이 새로 구현한다** — 앱의 `cascadeDeleteOverrides` 는 no-op 이라 참고할 구현이 없다(ⓛ). 배치의 **서로 다른 `storeId` 개수**를 Rules 접근 예산 안에 둔다 (W-B8).
- Functions 호출 시 리전 **`asia-northeast3`** 명시.
- 브랜드 승인은 **`issueBrandKey` 성공 뒤에만 `status` 쓰기** (§7).
- **낙관적 UI 금지.** `create` 를 `stores`/`brands` 에 보내지 않는다.
- **SDK import 는 `console-data.js` 한 파일에만.**
- Firebase web config 가 시크릿이 아닌 이유, `landing/` 이 Clean Architecture 레이어 밖인 이유를 **파일 주석으로 남긴다** (§4.3, §8.4).
- **§11.3 의 ⓐ~ⓚ 를 복제하지 않는다.** 각 지점에 "앱은 이렇게 하지만 여기서는 이렇게 하는 이유" 를 주석으로 남긴다.
- **이관은 `git mv` 를 먼저 한 커밋으로** (§11.2). git 커밋은 `git add landing/console/...` 처럼 **경로를 하나씩 명시**한다.

### tester — **호출 필요**

산출물: `docs/tasks/web_role_console/test_report.md`

**주요 검증 기준 — §5 매트릭스의 각 행을 실제로 통과/거부하는지 실측한다** (에뮬레이터 또는 역할별 테스트 계정).

- 역할별 계정 **4개**(admin / brand / owner / customer)로 각 섹션의 모든 read 와 write 를 실행한다.
- ✅ 행은 **성공해야** 하고, ❌ 행은 **거부돼야** 하고, 🚫 행은 **콘솔에 기능이 없어야** 한다.

**반드시 확인할 예외 케이스**:

1. **다른 역할의 해시를 직접 입력** (예: customer 계정으로 `#/b/menus`, owner 계정으로 `#/dashboard`) → 되돌려지고, **되돌려지지 않더라도 데이터가 오지 않는가**. §4.2 R-SEC1 의 핵심 테스트.
2. **DOM 에서 버튼 비활성화를 강제로 풀어 쓰기 시도** → Rules 가 거부하고 콘솔이 **성공으로 표시하지 않는가**.
3. **`menuOverrides` 5키 화이트리스트** — 품절 토글이 **3키만** 보내는가. **`disabledOption*` 를 덮어쓰지 않는가** (토글 후 옵션 비활성 설정이 유지되는지 실측 — §11.3-ⓐ).
4. **오버라이드 create 에 `masterMenuItemId` 가 있는가**. 그 뒤 마스터 메뉴 삭제 cascade 가 그 문서를 **실제로 지우는가** (§11.3-ⓑ).
5. **마스터 메뉴 삭제 cascade** — 콘솔이 **새로 구현하는 경로**다(앱은 no-op, ⓛ). 오버라이드가 **20건 넘을 때**, 그리고 **여러 매장에 걸칠 때** 거부되지 않는가. 한 배치의 `get(stores/{storeId})` 가 **서로 다른 storeId 몇 개까지 허용되는지**를 실측으로 정하고 청크 크기를 맞춘다.
6. **브랜드 정보 수정** — 좁은 payload 가 통과하는가. 그리고 **`approvedAt` 에 다른 값을 넣으면 거부되는가** (W-B1 의 양방향 확인).
7. **전역 금지 필드** — Qoin 관리 필드 · `availableMainCategories` · `averageScore` · `reviewCount` · `qoinBalance` · `brandKey` 가 **어떤 payload 에도 없는가**. 일부러 하나 섞어 보내면 가드가 **전송 전에** 터지는가.
8. **정상 payload 회귀** — 금지 검증을 강화한 뒤에도 승인/반려/메뉴 등록/품절 토글이 **여전히 통과하는가** (audit_trail §4-7: 막다가 정상까지 막으면 안 된다).
9. **`approvedBy` 가 로그인 uid 로 남는가** (승인/반려). 빠지면 **FAIL**.
10. **매장 반려가 `rejectedAt` 에 쓰고 `approvedAt` 을 건드리지 않는가** (결제 게이트 `canSellNow` 오염 방지).
11. **`updatedBy` 가 역할 문자열로 정확한가** (`admin`/`brand`/`owner`) — §13 체크리스트 4의 콘솔 유일 의무.
12. **가격 변경이 `priceHistory` 에 남고 `changedBy` 가 웹 로그인 uid 인가** (§13-2 의 핵심 주장 실측).
13. **매출 집계가 앱과 같은 값을 내는가** — 같은 매장·같은 기간을 앱과 웹에서 나란히 조회해 **총 매출 · 건수 · 평균 객단가 · 환불 · 취소**를 비교. 특히 ⓐ 환불이 **매출에서 빠지는지**, ⓑ 진행 중이 **포함되는지**, ⓒ 평균이 **버림**인지, ⓓ KST 주 경계(월요일)와 월 경계가 같은지.
14. **매출 쿼리에서 `where storeId==` 를 뺀 쿼리가 거부되는가** (rules-aware query 확인).
15. **매출 읽기가 서버 강제인가** — 오프라인 후 복귀 시 **0원이 정상처럼 보이지 않는가**.
16. **brand 미연결 계정** (role='brand' + `users.brandId` 없음) → B10 게이트가 뜨고, 쓰기를 시도하면 Rules 가 거부하는가. `claimSubmittedBrand` 의 4가지 `details.reason` 안내가 구분되는가.
17. **owner 의 브랜드 PII 읽기 시도** (`brands/{bid}/private/profile`) → 콘솔이 **요청조차 보내지 않는가** (R-O7).
18. **매장 없는 owner / 미승인 매장 owner** → 섹션 안 안내가 뜨고 셸이 유지되는가.
19. **customer 계정** → 섹션이 열리고 **자동 로그아웃되지 않는가** (§10). U1~U3 이 보이는가.
20. **`users/{uid}` 문서가 없는 계정** → `customer` 로 열리는가 (fail-closed 게이트가 아니라).
21. **`users/{uid}` 읽기 실패** → fail-closed 게이트인가.
22. **세션 중 역할 변경** — 앱에서 `role` 을 바꾼 뒤 콘솔에서 섹션 read 를 트리거 → 안내 + 셸 재렌더되는가 (§9.3).
23. **콘솔에 역할 부여 기능이 없는가** (§3-N3). **owner 주문 접수 기능이 없는가** (§3-N1). **brand 의 자기 승인 기능이 없는가** (§5.7-X2).
24. **콘솔이 `stores`/`brands` 를 create 하지 않는가** (§13-7).
25. **이미지 업로드** — 5MB 상한이 걸리는가. Storage 경로 규칙이 앱과 같은가.
26. **배포 후 랜딩 4페이지 회귀 없음.** `landing/{index,terms,privacy,refund}.html` 과 `landing/assets/style.css` 의 **diff 가 0** 인가.
27. **`lib/` · `functions/` · `firestore.rules` · `firestore.indexes.json` · `storage.rules` 의 diff 가 0** 인가. `firebase.json` 의 diff 가 **hosting 블록의 rewrites 추가뿐**인가.
28. **`console-payloads.js` 가 node 로 단독 실행 검증되는가** (SDK import 없음 — 기존 파일의 성질 유지).
29. **admin 섹션 기능 회귀** — 이관 후 `docs/tasks/web_admin_console/` 의 검증 항목이 **전부 그대로 통과하는가**. admin 동작이 바뀌면 FAIL.

### 호출 순서

```
(사용자 Q1~Q6 답)
  → tester 가 web_admin_console 를 끝낼 때까지 대기 (§11.2)
  → /designer  → docs/tasks/web_role_console/design.md
  → /developer → 코드 + implementation.md
  → /tester    → test_report.md
  → architect 재검토 (FAIL 있으면 재분배)
```

---

> **앱 세션 인계**: 이 spec 작성 중 발견한 `lib/` · `functions/` · `firestore.rules` 영역 문제는
> [`app_session_handoff.md`](./app_session_handoff.md) 에 정리했다 (8건, 각 항목에 [확인됨]/[확인 필요] 표기).

## 17. 별 과제 (지금 못 하는 것)

| # | 과제 | 왜 지금 못 하는가 | 열려면 무엇이 필요한가 |
|---|---|---|---|
| **T1** | **게시글 · QnA** | **컬렉션 자체가 `firestore.rules` 에 없다.** fallback deny(`:820-822`)가 전부 거부한다. `firestore.rules` 는 이 세션 **읽기 전용** | 컬렉션 스키마 설계 + Rules 작성(작성자 본인 검증 · 필드 화이트리스트 · 신고/숨김) + 인덱스 + 배포. **다른 세션 작업 종료 후 별 spec.** customer 섹션은 자리를 비워 뒀다(§10) |
| **T2** | **brand 자기 승인 가능성** | Rules 가 브랜드 보유자에게 `brands/*/menuItems` 와 `stores/*/menuOverrides` 를 **필드 제한 없이** 허용해, 승인 경계를 **앱 리포지토리만** 집행한다 (§5.7-X2). Rules 변경 필요 | `firestore.rules` 변경 — 브랜드 분기에 `status`/`approvedBy`/`approvedAt` 변경 금지 추가. ⚠️ 앱의 `seedExclusionsForStore` 등 기존 쓰기와의 호환 검토 필수 |
| **T3** | 승인 심사 이력 서브컬렉션 | 승인 메타가 문서에 **1세대만** 남아 재심사 이력이 덮인다 (`audit_trail` A5). 수정이 `lib/` 모델 · Rules · CF 전부에 걸친다 | 별 spec. **쓰기 주체는 CF** (`audit_trail` §4) |
| **T4** | **admin 대행 (다른 역할 화면 실행)** | `orders.update` admin 분기 O4(`:224`)가 **전권**이어서 점주용 UI 를 admin 권한으로 실행하면 **잘못된 모양의 쓰기가 Rules 에 막히지 않는다** (§3-N6) | **별도 설계가 선행돼야 한다** — 대행 전용 Rules 분기(또는 CF) + 대행 이력(누가 누구를 대행했는지)이 함께 설계돼야 한다. 그 전에는 만들지 않는다 |
| **T5** | cascade 삭제의 묶은 이력 | 일괄 처리는 "대상 수 · 덮어쓰기 여부" 를 1건으로 묶어 남겨야 하고(`audit_trail` §4-5) 그 쓰기 주체는 CF 여야 한다. `functions/` 읽기 전용 | 새 CF + 이력 스키마. 별 spec |
| **T6** | **앱 기존 결함 수정 (§11.3 ⓐ~ⓚ)** | `lib/` 읽기 전용. 특히 ⓐ(옵션 비활성 소실)와 ⓑ(cascade 누락)는 **운영 데이터에 영향**이 있다 | `lib/` 수정 권한 + 회귀 테스트. **ⓐ·ⓑ 는 우선순위 높음** — 콘솔을 고쳐도 앱에서 같은 사고가 계속 난다 |
| **T7** | 액션 출처(앱/웹) 기록 | 기존 문서에 필드를 추가해야 하고 `lib/` 모델 호환성 검토가 필요 | `lib/` 수정 권한 + 모델 변경 검토 |
| **T8** | `collectionGroup('menuOverrides')` + `brandId` 인덱스 | `firestore.indexes.json` 이 `landing/` 밖이라 읽기 전용. 1차는 매장별 N회 조회로 우회 (R-B11) | 인덱스 추가 + 배포. 산하 매장이 많아지면 필요 |
| **T9** | **랜딩 헤더 "로그인" 버튼** | **확정 2** — PG 심사 종료 후. 심사 중 `landing/` 배포 반복을 피하고, 심사자가 막다른 길을 보지 않게 한다 | PG 심사 통과 확인 → `landing/index.html` 헤더에 `/console/` 링크 1개 추가 → 배포 |
| **T10** | owner 매장 정보 수정 | 1차 비범위(§3-N5). 주소 검색 · GeoPoint · 다중 이미지 의존 + 핵심 수정이 재심사를 트리거 | **Q3** 가 "범위" 로 바뀌면 이번에 포함. 그 경우 `audit_trail` A2(운영 정보 변경 이력 공백)가 웹 표면에도 생긴다는 비용을 함께 받는다 |
| **T11** | 매출 사전집계 CF | 현재 매출은 **클라이언트가 `orders` 를 전부 읽어 합산**한다 (1,000건 상한). 앱 코드에 CF 집계 전환 흔적(`SalesPeriod.bucketKey`)만 있고 CF 도 집계 컬렉션도 없다 | 새 CF + 집계 컬렉션 + Rules. 주문량이 1,000건 상한에 닿으면 필요 |
| **T12** | 별도 Hosting 사이트 분리 | `firebase.json` hosting 을 target 배열 구조로 바꿔야 하고 다른 세션의 배포 명령과 충돌 | PG 심사 종료 + 다른 세션 종료 + Firebase Console 사이트 추가 + `firebase target:apply` |
| **T13** | App Check (웹) | 1차 범위 밖. 현재 보호는 Rules + Auth 승인 도메인 | reCAPTCHA Enterprise 설정 + CF `enforceAppCheck` 검토(= `functions/` 수정) |
| **T14** | `storage.rules` 정밀화 | 현재 규칙은 **인증된 누구나 어디에나** image 를 쓸 수 있는 임시 규칙(`storage.rules:4-6` 이 재작성 필요를 명시). `storage.rules` 는 이 세션 읽기 전용 | 별 spec (`docs/tasks/storage_security_rules/`). 콘솔은 앱과 **같은 경로 규칙**을 지켜 나중에 좁혀질 때 어긋나지 않게 한다 |
| **T15** | 네이버/카카오 로그인 (웹) | **조사 완료 (2026-10-29) — 아래 T15 보강 참조.** 기술적 차단 요인 없음. 미구현일 뿐 | **고객 섹션의 전제조건으로 승격.** Q5 재정의 |
| **T16** | ⚠️ `verifyKakaoToken`/`verifyNaverToken` 의 **토큰 수신자(audience) 미검증** | 아래 T16 상세. **표준 하드닝 누락**(심각도 정정 — 계정 탈취 아님). 웹과 무관하게 이미 존재. `functions/` 는 이 세션 읽기 전용 | **앱 세션으로 이관.** 웹 로그인 추가 전에 처리하는 것이 바람직 |

### T15 보강 — 웹 소셜 로그인은 "불가"가 아니라 "미구현" (2026-10-29 조사)

커스텀 토큰 흐름은 **4단계 중 3단계가 이미 플랫폼 무관하게 완성돼 있다.**

```
① 네이버/카카오 SDK 로그인 → accessToken 획득      ← 여기만 플랫폼 의존. 웹 미구현
② accessToken 을 CF 에 전달                        ← 완성 (플랫폼 무관)
③ CF 가 공급자 API 로 검증 → Firebase 커스텀 토큰   ← 완성 (functions/src/verify{Kakao,Naver}Token.ts)
④ signInWithCustomToken(customToken)               ← Firebase JS SDK 가 웹에서 지원
```

- 앱이 ①에 쓰는 `kakao_flutter_sdk_user` · `flutter_naver_login` 이 **모바일 전용**일 뿐이다. 웹에는 **카카오 JavaScript SDK** · **네이버 OAuth 2.0 웹 로그인**이라는 공식 경로가 있다.
- **`functions/` 수정 없이 가능하다** — ②③을 그대로 호출하면 된다.

**계정 동일성 (중요)**: CF 이 uid 를 `kakao_${kakaoUid}` / `naver_${naverUid}` 로 **결정적으로** 만든다
(`verifyKakaoToken.ts:82`, `verifyNaverToken.ts:82`). 따라서 같은 사람이 앱에서 로그인하든 웹에서
로그인하든 **같은 Firebase uid** 가 되고, 기존 주문내역 · Qoin · 리뷰가 그대로 이어진다.

> 🔴 **되돌리기 어려운 함정**: 카카오 회원번호는 **카카오 앱 단위로 발급**된다(네이버도 동일).
> 웹용으로 **새 카카오 앱 / 네이버 애플리케이션을 만들면 같은 사람에게 다른 번호가 나와 계정이 쪼개진다.**
> 반드시 **기존 앱에 "웹 플랫폼"을 추가**해야 한다. 새로 만들지 않는다.

**사용자 준비 항목**: 카카오 — JavaScript 키 + 웹 플랫폼 도메인 등록(`localhost`, `order-app-5957e.web.app`).
네이버 — 클라이언트 ID + Callback URL 등록. (`env.json` 에는 현재 `TOSS_CLIENT_KEY` 뿐이라 둘 다 신규 값이다.)

**Q5 재정의**: 원래 질문은 "카카오/네이버 계정이 못 들어오는데 괜찮은가" 였으나, 조사 결과 넣을 수 있으므로
질문은 **"웹 콘솔에 카카오·네이버 로그인을 넣을 것인가, 언제 넣을 것인가"** 로 바뀐다.
사용자 판단(2026-10-29): **고객 다수가 카카오/네이버로 보이므로, 고객 섹션(리뷰·게시글·QnA)의 전제조건이다.**
admin 섹션(1차)은 Email/Google 로 충분하므로 **지금 당장 막히는 것은 없다.**

### T16 상세 — 소셜 로그인 CF 의 토큰 수신자 미검증 ⚠️ (심각도 정정됨)

`verifyKakaoToken.ts` 는 받은 `accessToken` 으로 `https://kapi.kakao.com/v2/user/me` 를 호출하고,
돌아온 `id` 를 그대로 믿어 `createCustomToken('kakao_' + id)` 를 발급한다(`:50-85`).
**그 토큰이 어느 카카오 앱에서 발급됐는지 확인하지 않는다.** `verifyNaverToken.ts` 도 같은 구조다.

**심각도 정정 (2026-10-29, 앱 세션 검증)**: 최초 작성의 "피해자 계정 직접 탈취" 는 **과장이었다.**
카카오 회원번호는 **앱 단위 스코프**라 타 앱 토큰은 `kakao_<다른 id>` 로 매핑되어 피해자 계정에 닿지 않는다.
**표준 하드닝 누락 + 조건부 위험**으로 분류한다. 남는 위험: ① 같은 **앱 그룹**이면 회원번호를 공유해 성립
② **네이버는 스코프 특성이 달라 더 노출될 수 있다**(확인 필요) ③ 임의 외부 토큰으로 **Firebase 계정을
만들 수 있는 엔드포인트**라 남용·할당량 문제는 남는다.

**현재 노출**: 웹과 무관하게 **앱 경로로 이미 존재한다.** 웹 로그인을 추가하면 표면이 하나 늘 뿐이다.

**표준 해법**
- 카카오: `https://kapi.kakao.com/v1/user/access_token_info` 로 `app_id` 가 우리 앱인지 검증
- 네이버: 클라이언트가 보낸 accessToken 을 받지 말고, **서버가 authorization code 를 자기 client secret 으로 교환**하는 흐름으로 전환

**이 세션에서 할 수 없다** — `functions/` 읽기 전용이며 다른 세션의 작업 영역이다. 앱 세션으로 이관한다.

---

## 18. 사용자 확인이 필요한 결정사항

| # | 질문 | 분기 | 권고 |
|---|---|---|---|
| **Q1** | **`landing/console/` 이관 시점** | **(A)** tester 가 `web_admin_console` 를 끝내고 FAIL 해소 후 `git mv` → 그 다음 확장 (§11.2) / **(B)** 지금 `landing/console/` 을 새로 만들고 `landing/console/` 은 당분간 둔 뒤 나중에 제거 | **(A).** (B)는 같은 코드가 두 곳에 있는 기간을 만들고, 그 사이 admin 수정이 한쪽에만 들어가면 갈라진다. 다만 (A)는 **tester 작업이 끝날 때까지 이 과제가 대기**한다는 비용이 있다 |
| **Q2** | **오버라이드 create 에 `masterMenuItemId` 를 넣을까** | **(A)** 넣는다 — Rules 통과에 영향 없는 순수 추가이고 cascade 누락(§11.3-ⓑ)을 웹에서는 안 만든다 / **(B)** 앱과 정확히 같게 둔다 — "값을 새로 정하지 않는다" 를 엄격히 | **(A).** 이것은 값을 새로 정하는 것이 아니라 **빠진 식별자를 채우는 것**이다(앱의 seed 경로는 이미 넣는다). 단 **앱 쪽 수정(T6-ⓑ)이 없으면 앱이 만든 문서는 계속 누락**되므로 반쪽이다 — 그 사실을 받아들이는지 확인이 필요하다 |
| **Q3** | **owner 매장 정보 수정을 1차에 넣을까** | **(A)** 비범위 유지 (§3-N5) / **(B)** **운영 필드만** 넣는다 (영업시간 · 임시휴무 · 휴무일 · 전화 · 공지 · 설명 — 10키 전부 Rules 화이트리스트 안, §5.4 W-O14) / **(C)** 핵심 필드까지 | **(A), 차선 (B).** (B)는 Rules 상 안전하고 데스크톱에서 하기 좋은 업무지만, 이미지 다중 업로드와 `excludedMainCategories` 해석 규칙(휴면 코드 보존)을 함께 옮겨야 하고 **운영 정보 변경 이력 공백**(T10)을 웹에도 들인다. **(C)는 권하지 않는다** — 핵심 수정이 `status='pending'` 회귀 = 재심사 트리거다 |
| **Q4** | 마스터 메뉴 운영 수정의 `disabledOption*` | 앱은 이 둘의 변경을 "운영 변경" 으로 **판정만 하고 payload 에 넣지 않아 저장되지 않는다** (§5.3 W-B6). **(A)** 앱과 같게 둔다(저장 안 됨) / **(B)** payload 에 포함해 저장되게 한다 | **(B).** Rules 는 제한이 없고(`:607-608`) 점포 한정 메뉴 경로는 이미 두 키를 포함한다 — 마스터 메뉴만 빠진 것은 **일관성 결함**으로 보인다. 단 사용자가 "마스터 메뉴에서는 의도적으로 안 바꾼다" 로 결정했다면 (A) |
| **Q5** | **네이버/카카오 전용 계정의 콘솔 접근** | 웹은 Email/Google 만 지원한다(§3-N11). 네이버·카카오로만 가입한 점주·브랜드는 **콘솔에 로그인할 수 없다.** **(A)** 1차는 그대로 두고 "콘솔 사용 계정은 Email/Google 로 준비" 를 운영 안내로 / **(B)** 웹 소셜 로그인 조사를 선행 (T15) | **(A).** 단 **이것이 실사용 차단 요인인지 확인이 필요하다** — 실제 점주·브랜드 계정 대부분이 카카오/네이버라면 콘솔이 쓸모없어진다. 사용자가 현재 계정 구성을 아는 쪽이다 |
| **Q6** | customer 섹션에 **쓰기**를 1건이라도 넣을까 | **(A)** 1차는 읽기 전용 3화면 (§2.5) / **(B)** 표시 이름 변경(`displayName` — self 화이트리스트 `:142` 안) 1건을 넣어 "정식 섹션" 을 더 확실히 한다 | **(A).** 쓰기가 생기면 payload 가드·확인 단계·실패 처리가 한 세트 더 필요하고, 고객이 지금 그걸 쓸 이유가 없다. §10 의 "비어 있는 정식 섹션" 은 **읽기 3화면 + 빈 자리 안내**로 충분히 전달된다 |

---

## 19. 완료 기준

- [ ] Q1~Q6 에 사용자 답을 받고 §2 기능 범위를 확정했다
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료, FAIL 없음 또는 후속 분리
- [ ] **§5 매트릭스의 모든 ✅ 행이 Rules 변경 없이 통과하고, 모든 ❌ 행이 실제로 거부됨을 실측했다**
- [ ] **§5.7 의 X1~X5 (역할 부여 · brand 자기 승인 · owner 주문 접수 · brand 매장 본문 수정 · admin 대행) 기능이 콘솔에 없음**을 확인했다
- [ ] §11.3 의 ⓐ~ⓚ 를 콘솔이 복제하지 않았음을 확인했다
- [ ] 역할 4종(admin / brand / owner / customer) 계정으로 각 섹션이 정상 동작하고, 다른 역할 해시 접근 시 데이터가 오지 않음을 확인했다
- [ ] customer 계정이 **자동 로그아웃되지 않음**을 확인했다
- [ ] `console-payloads.js` 가 node 단독 검증을 통과하고, 전역 금지 필드를 섞으면 **전송 전에** 터짐을 확인했다
- [ ] 서비스 계정 키가 `landing/` 과 git 어디에도 **없음**을 확인했다
- [ ] 코드가 `landing/console/` 밖으로 나가지 않았음을 확인했다 (`lib/` · `functions/` · `firestore.rules` · `firestore.indexes.json` · `storage.rules` **diff 0**)
- [ ] `firebase.json` diff 가 **hosting 블록의 rewrites 추가뿐**임을 확인했다
- [ ] `landing/{index,terms,privacy,refund}.html` 과 `landing/assets/style.css` **diff 0** 을 확인했다
- [ ] admin 섹션이 `web_admin_console` 검증 항목을 **전부 그대로 통과**함을 확인했다 (이관 회귀)
- [ ] 배포는 **사용자가** 수행했고 랜딩 4페이지 회귀가 없다

---

## 20. 참조

- `CLAUDE.md` — 절대 규칙 / Guide Reference Policy
- `docs/tasks/web_admin_console/{spec,design,implementation}.md` — **이관 원본.** ⚠️ spec §7.2 의 Rules 줄번호는 낡았다 (§5.0)
- `docs/tasks/store_reviews/` — 리뷰 바탕 상태 (customer 확장 지점)
- `docs/processes/role_flows.md` — §4.1 customer / §4.2 owner / §4.3 brand / §4.4 admin, §5 끼어들기 가이드
- `docs/processes/entity_lifecycle.md` — store / brand / menuItem / menuOverride 전이. **새 status 값 · 새 전이 · 새 엔티티 없음**
- `docs/processes/data_ownership.md` — §2 권한 매트릭스 / §3 CF 전담 카탈로그 / §4 결정 흐름차트
- `docs/processes/audit_trail.md` — §4 체크리스트 (→ §13)
- `docs/operations.md` — 배포 / 환경 / 결제 게이트 운영
- `landing/README.md` — 배포 규칙 4개
- `firestore.rules` (825줄) · `functions/src/index.ts` · `firestore.indexes.json` · `storage.rules` — 이 세션 **읽기 전용**
