# web_admin_console 기능 명세

## 개요

- **목적**: admin 업무(승인 큐 / Qoin 설정 / 매장 관리 / 메인 카테고리)를 데스크톱 웹 브라우저에서 수행할 수 있는 관리자 콘솔을 만든다. 넓은 화면·키보드·다중 탭이 유리한 업무를 모바일 앱에서 떼어낸다.
- **작업 유형**: 신규 기능 (신규 플랫폼 표면 추가). 기존 Flutter 앱 admin 기능의 **대체가 아니라 병행**.
- **출발점**: `landing/` 에 토스페이먼츠 PG 심사용 정적 사이트가 이미 있고 Firebase Hosting(`order-app-5957e`) 단일 사이트로 배포 중이다. 그 Hosting 위에 관리자 콘솔을 얹는다.
- **상태**: **결정 3건(Q1/Q2/Q3) 미확정.** 이 문서는 결정 전까지 구현 세부를 확정하지 않는다. 결정에 따라 갈리는 부분은 분기로 적었다.

### 영향 범위 (요약)

| 영역 | 영향 |
|---|---|
| 화면 | 신규 웹 화면 (로그인 / 승인 큐 / Qoin / 매장 / 카테고리). 기존 Flutter 화면 **변경 없음** |
| Domain | 없음 (Q1=B). Q1=A 면 재사용만, 신규 없음 |
| Data | 없음 (Q1=B 는 웹 자체 데이터 접근 코드, `lib/` 밖) |
| Presentation | 없음 (`lib/` 읽기 전용) |
| Firestore Rules | **변경 없음 — 변경 불가**(§5). 기존 `isAdmin()` 분기로 충분함을 §7 에서 액션별 검증 |
| Cloud Functions | **변경 없음**. 기존 callable 을 그대로 호출 |
| 배포 | `firebase.json` **hosting 블록만**. `landing/` 산출물 추가 |
| 테스트 | 수동 브라우저 검증 + Rules 통과 여부 표 검증. Flutter 단위 테스트 영향 없음 |

---

## 1. 사용자 확인이 필요한 결정사항 (3건)

> ## ✅ 결정 완료 (2026-10-29, 사용자 확인)
>
> | | 결정 | 내용 |
> |---|---|---|
> | **Q1** | **(B) 새 웹 SPA** | `landing/console/` + Firebase JS SDK. Flutter Web 미채택 |
> | **Q2** | **읽기 넓게 + 쓰기 좁게** | 읽기: 승인 대기 큐 4종 · Qoin 전역 적립률/비상정지 · 매장 목록<br>쓰기: **브랜드 승인/반려 + 매장 승인/반려 2쌍만** |
> | **Q3** | **(A) 같은 사이트 + 조건 ①②③** | `landing/console/` 하위만 · landing 에서 `/admin` 링크 만들지 않음 · **PG 심사 종료까지 배포하지 않음** |
>
> 아래 1절은 결정 근거의 기록으로 남긴다. 구현은 위 결정을 전제로 한다.

### Q1. 재사용 전략 — Flutter Web(A) vs 새 웹 SPA(B)

| | (A) Flutter Web | (B) 새 웹 SPA (`landing/console/`, Firebase JS SDK) |
|---|---|---|
| 재사용 | `lib/presentation/admin/**` 59개 파일 + domain/data 전부 | 0. UI·검증 로직을 다시 쓴다 |
| 일관성 | 앱과 화면·문구·검증이 자동으로 같다 | 두 곳이 갈라질 수 있다 (적립률 범위, 삭제 사유 2~200자 등) |
| 데스크톱 적합성 | 모바일 레이아웃을 그대로 띄운다 — 넓은 화면 이득이 적고 반응형 재작업이 필요 | 처음부터 데스크톱 레이아웃 |
| 번들/초기 로딩 | 수 MB, 초기 로딩 느림 | 수십 KB |
| `landing/` 공존 | Flutter web 빌드 산출물을 `landing/` 안에 넣어야 함(또는 별 사이트). 빌드 단계가 새로 생긴다 | 현재와 같이 빌드 단계 없음 |

**(A)를 지금 막는 것 — "불가능"과 "열려면 무엇이 필요한가"의 분리**

지금 불가능한 이유는 Flutter Web 자체의 한계가 아니라 **이 세션의 권한 범위**다.

1. `lib/firebase_options.dart:18-24` 가 web 플랫폼에 대해 `UnsupportedError` 를 명시적으로 던진다. web 설정 블록이 없다. 열려면 `flutterfire configure` 로 이 파일을 재생성해야 하고 `firebase.json` 의 `flutter.platforms.dart` 블록도 바뀐다 → **둘 다 이 세션에서 금지**(§5).
2. 웹 미지원/미검증 플러그인이 앱 의존성에 있다: `flutter_naver_login`, `tosspayments_widget_sdk_flutter`, `geolocator`. admin 화면이 직접 쓰지 않더라도 **웹 빌드는 앱 전체를 컴파일**하므로 조건부 import / stub 분리 작업이 `lib/` 전반에 필요하다 → **`lib/` 읽기 전용이라 불가**.
3. 로그인 경로: admin 계정이 Naver/Kakao 로 만들어졌다면 웹에서 그 SDK 로 재로그인할 수 없다. 단 `signInWithEmail` 과 Google 은 웹에서 동작하므로 이는 (A)(B) 공통의 **계정 준비 문제**이고 차단 요인은 아니다.

즉 **(A)는 "원리적으로 불가능"이 아니라 "이 세션에서 착수 불가"**다. 열려면: ① `flutterfire configure` 로 web 설정 추가 ② 웹 미지원 플러그인 3종의 플랫폼 분기 ③ admin 화면의 데스크톱 반응형 재작업 ④ `firebase.json` flutter/hosting 동시 수정. ①②④ 는 다른 세션 영역이다.

**권고: (B) 새 웹 SPA.** 근거는 둘이다.
- 제약 때문이 아니라 **업무 성격 때문에도 (B)가 맞다**. 웹으로 옮길 가치가 큰 업무(Q2)는 "목록을 넓게 보고 키보드로 빠르게 처리"다. (A)는 모바일 레이아웃을 그대로 띄우므로 그 이득을 못 준다 — 재사용을 얻는 대신 목적을 잃는다.
- 중복 위험은 **CF 를 그대로 호출**하는 것으로 대부분 없앨 수 있다(§7). 중복되는 것은 화면과 입력 힌트뿐이고, 값 검증의 권위는 CF/Rules 에 있다(§6).

**보류 시 영향**: 아무 코드도 쓸 수 없다. Q1 은 세 결정 중 유일하게 **블로킹**이다.

### Q2. 노출 admin 액션 범위 — 1차에 무엇을 넣는가

웹에서 먼저 할 가치의 기준: **(가)** 목록을 넓게 봐야 하는가 **(나)** 긴 텍스트를 읽/쓰는가 **(다)** 여러 건을 연속 처리하는가 **(라)** 실수 비용이 큰가(큰 화면에서 확인 후 실행하는 게 안전한가).

| 액션 | 가 | 나 | 다 | 라 | 판정 |
|---|:-:|:-:|:-:|:-:|---|
| 승인 큐 — 브랜드 / 매장 | ●  | ● | ● | ● | **1차**. 사업자 정보·주소·로고를 읽고 판단하는 업무. 모바일에서 가장 불편하다 |
| 승인 큐 — 마스터 메뉴 / 매장 커스텀(menuOverrides) | ● | ○ | ● | ○ | **1차 후보(2순위)**. 건수가 많아 연속 처리 이득이 크다 |
| 메인 카테고리 관리 | ○ | ○ | ○ | ○ | **2차**. 값 4~6개의 저빈도 CRUD. 모바일로 충분하다 |
| Qoin 설정 — 전역 적립률 / 비상 정지 | ○ | ○ | ○ | ●●| **2차(또는 읽기 전용으로 1차)**. 돈에 직접 닿는다. 조회는 넓은 화면이 좋지만 쓰기를 표면 2곳으로 늘리는 것은 위험 증가 |
| Qoin 설정 — 브랜드/매장 단건 적립률 | ● | ○ | ● | ● | **2차** |
| Qoin 설정 — 브랜드 일괄 적용(`applyBrandQoinRate`) | ○ | ○ | ○ | ●●●| **비범위**. 중단/이어서 적용 상태 기계(`qoinBulkStatus`)가 있어 두 표면에서 동시 조작하면 꼬인다 |
| 매장 삭제(`deleteStore`) | ○ | ● | ○ | ●●●| **비범위(1차)**. 되돌릴 수 없다. 표면을 늘릴 이유가 없다 |
| 마이그레이션 / 감사 도구 | ○ | ○ | ○ | ● | **비범위**. 임시 도구이고 정리 커밋으로 삭제 예정이다 |

**권고: 1차 = 읽기 전용 운영 대시보드 + 브랜드/매장 승인·반려.**
- **읽기**: 승인 대기 큐 4종(브랜드/마스터메뉴/매장/매장커스텀) 건수와 목록, 현재 Qoin 전역 적립률·비상 정지 상태, 매장 목록. 읽기는 위험이 0 이고 "넓은 화면" 이득이 가장 크다.
- **쓰기**: 브랜드 승인/반려, 매장 승인/반려 **2쌍만**. 반려 사유 입력은 키보드가 있는 웹이 확실히 낫다.
- 그 외 전부 2차/비범위. 쓰기 표면을 늘리는 것 자체가 위험이므로 1차에는 "읽기 넓게, 쓰기 좁게"를 택한다.

**보류 시 영향**: Q1=B 라면 화면 수가 정해지지 않아 designer 작업을 시작할 수 없다. 단 로그인 + 읽기 전용 대시보드는 Q2 와 무관하게 공통이므로 **그만큼은 선행 가능**하다.

### Q3. 호스팅 경계 — 같은 사이트 `/admin`(A) vs 별도 사이트(B)

| | (A) `landing/console/` — 같은 호스팅, 같은 도메인 | (B) 별도 Hosting 사이트 (`qradar-admin.web.app`) |
|---|---|---|
| 설정 | 현재 `firebase.json` hosting 블록 그대로. 파일만 추가 | **hosting 을 target 배열로 바꿔야 한다**(단일 객체 → 배열). Firebase 콘솔에서 사이트 추가 + `firebase target:apply` |
| 배포 명령 | 현재와 동일 (`--only hosting`) | `--only hosting:admin` 등으로 분리. landing 과 독립 배포 가능 |
| PG 심사 영향 | **심사 중인 도메인에 관리자 로그인 화면이 함께 올라간다.** `/admin` 은 링크하지 않아도 URL 로 접근 가능하다 | 심사 도메인은 landing 만. 관리자 화면은 심사 범위 밖 |
| 사고 반경 | 콘솔 배포 실수가 landing(심사 자료) 를 함께 날릴 수 있다 — **같은 `public` 디렉토리 한 번의 배포** | landing 과 완전 분리 |
| 다른 세션과의 충돌 | 같은 hosting 블록·같은 배포 명령을 두 작업이 공유 | hosting 블록 구조 변경이 필요 → **다른 세션과 충돌 위험이 더 크다** |

**PG 심사 판단**: 심사자가 보는 것은 결제 흐름·약관·환불 정책이고, 관리자 로그인 화면이 같은 도메인에 있는 것 자체가 반려 사유가 되지는 않는다. 다만 **심사 중에 심사 자료가 들어 있는 디렉토리를 건드리는 배포를 반복하는 것**이 실질 위험이다(파일 누락·캐시·일시 404). 이것은 Q3 보다 "심사 종료까지 배포하지 않는다"로 다루는 게 맞다.

**권고: (A) 같은 사이트 `landing/console/`, 단 ①~③ 조건부.**
1. `landing/console/` 하위에만 파일을 둔다. 기존 4개 html / `assets/` 는 손대지 않는다.
2. `index.html` 등 landing 페이지에서 `/admin` 으로 가는 **링크를 만들지 않는다**. 숨김은 보안이 아니지만(§6) 심사자 동선에서 빼는 효과는 있다.
3. **PG 심사가 끝날 때까지 배포하지 않는다.** 코드만 머지하고 배포는 심사 종료 후 사용자가 수행한다(§9).

(B)가 더 깨끗하지만 **hosting 블록을 target 구조로 바꾸는 변경이 다른 세션의 배포 명령과 정면 충돌**한다. 분리가 꼭 필요하다는 판단이 서면 심사 종료 후 별 과제(§11-S3)로 옮기는 것을 권한다.

**보류 시 영향**: 파일 경로가 안 정해져 developer 가 디렉토리를 만들 수 없다. 다만 (A)(B) 모두 산출물은 동일한 정적 파일 묶음이라 **경로만 나중에 옮기면 되므로 블로킹은 아니다.**

---

## 2. 기능 범위

Q1=B / Q2=권고안 / Q3=A 를 가정한 1차 범위다. 결정이 바뀌면 이 절을 갱신한다.

### 기능 요구사항

- [ ] F1. **admin 로그인**: Firebase Auth 로 로그인하고 `users/{uid}.role == 'admin'` 을 읽어 확인한다. admin 이 아니면 콘솔 본문을 렌더하지 않고 안내만 띄운다. 로그인 수단은 Email/Password 와 Google (둘 다 웹에서 동작). Naver/Kakao 는 비범위(§3).
- [ ] F2. **대시보드(읽기)**: 승인 대기 건수 4종 — 브랜드(`brands` status=pending), 마스터 메뉴, 매장(`stores` status=pending), 매장 커스텀(`menuOverrides` status=pending). 각 항목에서 해당 목록으로 이동.
- [ ] F3. **브랜드 승인 큐**: pending 브랜드 목록 + 상세(브랜드명/로고/제출자/제출시각/`brands/{id}/private/profile` 사업자 정보) → 승인 / 반려(사유 입력).
- [ ] F4. **매장 승인 큐**: pending 매장 목록 + 상세(매장명/주소/이미지/점주/연결 브랜드) → 승인 / 반려(사유 입력).
- [ ] F5. **Qoin 현황(읽기 전용)**: `config/qoin` 의 `accrualRate`, `enabled`(비상 정지), `enabledChangedBy/At` 표시. 전역 변경 이력(`config/qoin/qoinRateHistory`) 최근 N건 조회.
- [ ] F6. **매장 목록(읽기 전용)**: 전체 매장 status / 브랜드 연결 / 승인 메타 조회 + 검색.
- [ ] F7. 모든 쓰기 액션은 **실행 전 확인 단계**를 거친다(대상 이름을 다시 보여주고 확인).

### UI 요구사항

- [ ] U1. 데스크톱 우선 레이아웃 (좌측 네비 + 본문, 최소 1024px 기준). 모바일 폭에서도 깨지지 않을 정도만 대응.
- [ ] U2. 색상은 `landing/assets/style.css` 의 기존 CSS 변수(= `lib/core/theme/color_palette.dart` 의 `LightMidnightAccentPalette` 미러링)를 **재사용**한다. 새 색상값을 도입하지 않는다.
- [ ] U3. 승인/반려 버튼은 파괴적 액션과 구분되는 위계를 갖는다. 반려 사유는 필수 입력.
- [ ] U4. Qradar 용어를 쓴다 — Qoin / Qrator / Log.

### 상태 요구사항

- [ ] S1. loading — 각 목록/카드 단위 스켈레톤 또는 로딩 표시.
- [ ] S2. error — 네트워크/권한/CF 실패를 §8 표대로 구분해 표시. 재시도 버튼.
- [ ] S3. empty — "승인 대기 없음" 을 에러와 구분해 표시.
- [ ] S4. 미인증 / 비admin — 본문을 렌더하지 않는다(§6-3).

---

## 3. 비범위 (이유 명기)

| 제외 항목 | 이유 |
|---|---|
| **역할 부여 / admin 승격 기능** | 보안 모델상 금지. admin 부여는 Firestore Console 수동 `users.role='admin'` 만이며 Rules 가 자가승격을 차단한다(§6-2). 콘솔에 이 기능을 만들면 권한 상승 경로가 생긴다 |
| 매장 삭제(`deleteStore`) | 되돌릴 수 없고 Storage·서브컬렉션까지 지운다. 표면을 2개로 늘릴 이유가 없다. 앱에 유지 |
| Qoin 브랜드 일괄 적용(`applyBrandQoinRate`) | `qoinBulkStatus` 중단/재개 상태 기계가 있어 두 표면 동시 조작 시 포인터가 꼬인다. 앱 1곳으로 유지 |
| Qoin 쓰기(적립률 변경 / 비상 정지 토글) | 1차는 읽기 전용. 돈 값의 쓰기 표면을 늘리는 결정은 Q2 답을 받고 2차에서 |
| 메인 카테고리 CRUD | 저빈도·소량. 웹 이득이 작다. 2차 |
| 마이그레이션 / 가격 감사 / 브랜드 링크 감사 | 임시 운영 도구이고 정리 커밋으로 삭제 예정 |
| Naver / Kakao 로그인 | 웹 SDK 미지원·미검증. admin 계정은 Email/Google 로 준비한다 |
| 공지사항 / 배너 / 쿠폰 관리 | 해당 컬렉션이 `firestore.rules` 에 **존재하지 않는다**(`notice` 는 `stores` 문서의 필드다). 새 Rules 가 필요하고 Rules 변경은 이 세션 불가(§5). 별 과제 S2 |
| 주문 조회 / 환불 처리 | 결제 관련 영역이며 **다른 세션이 동시 작업 중**(§5). 충돌 회피 |
| Flutter 앱 admin 화면 제거·축소 | 웹은 병행 표면이다. 앱 기능은 그대로 둔다 |
| Firestore Rules 변경 | §5. 다른 세션 영역 |
| 자동 배포 | 프로덕션 반영은 사용자가 수행한다(§9) |

---

## 4. 영향 범위 (상세)

| 구분 | 대상 | 영향 |
|---|---|---|
| 화면 | 신규 `landing/console/` 정적 페이지 | 신규. 기존 `landing/{index,terms,privacy,refund}.html` 무변경 |
| 화면 | `lib/presentation/admin/**` (59개) | **무변경**. 읽기 참조만 (흐름·분기 조건 복제의 원본) |
| 데이터 | `brands`, `brands/{id}/private/profile`, `stores`, `mainCategories`, `config/qoin`, `config/qoin/qoinRateHistory`, `{path=**}/menuItems`, `{path=**}/menuOverrides`, `users/{uid}` | **읽기**. 스키마 변경 없음 |
| 데이터 | `brands/{id}`, `stores/{id}` 의 승인 메타 필드 | **쓰기**(F3/F4). 기존 앱이 보내는 것과 **동일한 필드 집합**(§7.2) |
| 데이터 | 신규 컬렉션 / 신규 필드 | **없음** |
| Rules | `firestore.rules` | **무변경**. §7 에서 액션별 통과 검증 |
| CF | `functions/**` | **무변경**. 1차 범위에서는 호출조차 없다(§7.1) |
| 배포 | `firebase.json` hosting 블록 | Q3=A 면 **무변경**(파일만 추가). Q3=B 면 target 구조 변경 필요 → 별 과제 |
| 배포 | Firebase Auth 승인된 도메인 | 콘솔에서 호스팅 도메인이 승인 목록에 있어야 로그인이 된다 — 사용자 확인 항목 |
| 테스트 | Flutter `flutter test` | 영향 없음 |
| 테스트 | 신규 | 브라우저 수동 검증 체크리스트 + §7 Rules 통과 검증 |

---

## 5. 제약 조건 (이 세션)

출처: 메모리 `project-landing-deploy-rules`, `landing/README.md`.

1. **같은 저장소에서 다른 세션이 결제 관련 배포 작업을 동시에 진행 중이다.** 공유 파일 변경은 충돌을 만든다.
2. **코드 작성은 `landing/` 안으로 한정.** `lib/` · `functions/` · `firestore.rules` 는 **읽기 전용**. 이 `spec.md` 작성은 사용자가 명시 허용한 예외다.
3. **`firebase.json` 은 hosting 블록만** 수정 가능. `functions` / `firestore` / `storage` / `flutter` / `emulators` 블록 금지.
4. **배포는 `--only hosting` 만.** 전체 `firebase deploy` 금지.
5. **git 은 `git add <정확한 경로>` 만.** `git add -A` / `git add .` 금지.

### 설계에 미치는 결과

| 제약 | 설계 결과 |
|---|---|
| 2 (`lib/` 읽기 전용) | **Q1=(A) Flutter Web 을 이 세션에서 착수할 수 없다.** `firebase_options.dart` 재생성과 플러그인 플랫폼 분기가 모두 `lib/` 수정이다 |
| 2 (`firestore.rules` 읽기 전용) | **Rules 변경이 필요한 어떤 설계도 지금 할 수 없다.** 1차 범위는 기존 `isAdmin()` 분기 안에서만 동작하도록 §7 에서 액션별로 확인했다. 새 컬렉션(공지/배너/쿠폰)은 비범위 → 별 과제 S2 |
| 2 (`functions/` 읽기 전용) | CF 를 **호출만** 한다. 새 CF 를 만들거나 기존 CF 시그니처를 바꾸는 설계 금지 |
| 3 (hosting 블록만) | **Q3 권고가 (A)인 주된 이유.** (B)는 hosting 을 단일 객체에서 target 배열로 바꿔야 하고, 그 구조 변경이 다른 세션의 배포 명령과 충돌한다 |
| 1 + 4 | 배포 타이밍을 사용자가 통제한다. 콘솔은 **코드 머지와 배포를 분리**해 설계한다(배포 전까지 `/admin` 이 없어도 landing 은 정상) |
| 5 | developer 는 커밋 시 `landing/console/...` 경로를 하나씩 명시해 add 한다 |

---

## 6. 보안 모델 — 권위는 UI 가 아니다

### 6-1. 원칙 (명문화)

> **관리자 콘솔은 클라이언트일 뿐이다.** 모든 권한 판정의 최종 권위는 **Firestore Security Rules 와 Cloud Functions** 에 있다. 콘솔은 Rules 가 허용한 것 이상을 할 수 없고, 콘솔의 화면 숨김·버튼 비활성화는 **편의이지 보안 장치가 아니다**.

따라서:
- 콘솔 코드에 "admin 이면 버튼을 보여준다" 는 분기가 있어도, 그것이 **없어도 안전해야** 한다. 버튼을 DOM 에서 강제로 눌러도 Rules 가 거부한다.
- 콘솔은 **클라이언트가 보낸 역할을 서버가 믿지 않는다**는 기존 설계를 그대로 상속한다. CF 는 `requireAdmin()` 으로 `users/{uid}.role` 을 **서버에서 다시 읽는다**(`functions/src/qoinAdmin.ts`).
- `/admin` 경로를 landing 에서 링크하지 않는 것(Q3 조건 ②)은 **동선 분리이고 접근 통제가 아니다**. URL 을 알면 누구나 열 수 있고, 그래도 안전해야 한다.

### 6-2. admin 권한 부여 경로

- 유일한 경로: **Firestore Console 에서 `users/{uid}.role` 을 수동으로 `'admin'` 으로 설정.**
- Rules 의 `isAllowedSelfRoleChange` 가 자가승격을 차단한다. `users` update 의 self 분기는 `role` 전이 화이트리스트를 거치고, `brandId` 는 화이트리스트에 아예 없다(CF 전담).
- **콘솔에 역할 부여/변경 기능을 만들지 않는다**(§3 비범위 1행). 콘솔이 다른 사용자의 `users` 문서를 쓸 수 있게 되면, Rules 의 admin 전권(`allow update: if isAdmin()`) 때문에 **콘솔 세션 탈취가 곧 권한 상승**이 된다.

### 6-3. 미인증 / 비admin 접근

| 상태 | 콘솔 동작 |
|---|---|
| 미로그인 | 로그인 화면만 렌더 |
| 로그인했으나 `users/{uid}` 없음 또는 `role != 'admin'` | "관리자 권한이 없습니다" 안내 + 로그아웃 버튼. 데이터 요청을 보내지 않는다 |
| role 판정용 `users/{uid}` 읽기가 거부됨 | **admin 아님으로 처리**(fail-closed). Rules 는 `isAdmin() || self` 에게만 읽기를 허용하므로, 본인 문서 읽기 실패는 비정상 상태다 |

### 6-4. 시크릿 취급 — CLAUDE.md 절대규칙 4 와의 관계

CLAUDE.md 절대규칙 4는 "API key, secret, 환경별 설정값을 코드에 하드코딩하지 않는다" 이다. 웹 콘솔에서 이를 다음과 같이 적용한다.

| 값 | 성격 | 취급 |
|---|---|---|
| Firebase **web config** (`apiKey`, `authDomain`, `projectId`, `appId`, `messagingSenderId`) | **시크릿이 아니다.** 프로젝트 공개 식별자이며 브라우저에 반드시 노출된다. 보호는 apiKey 가 아니라 **Rules + Auth 승인 도메인 + App Check** 가 한다 | `landing/console/` 의 JS 에 평문으로 두어도 된다. 규칙 4의 "secret" 에 해당하지 않음을 **파일 주석으로 명시**해 다음 사람이 혼동하지 않게 한다 |
| 서비스 계정 키 / Admin SDK 자격증명 | **진짜 시크릿.** Rules 를 전부 우회한다 | **웹·깃에 절대 넣지 않는다.** 콘솔은 Admin SDK 를 쓰지 않는다. 특권 작업은 전부 기존 CF 를 호출한다 |
| 토스 시크릿 키 등 PG 자격증명 | 진짜 시크릿 | 콘솔 범위 밖. 서버(CF)에만 존재 |
| 환경별 설정 (dev/prod projectId 분기) | 환경값 | 1차는 prod 단일이라 분기 없음. 분기가 생기면 빌드 단계 없는 정적 사이트이므로 **파일 분리**로 다룬다(별 과제) |

규칙 4의 취지는 "노출되면 피해가 나는 값을 코드에 두지 않는다" 이다. web config 는 노출을 전제로 설계된 값이므로 **규칙 4 위반이 아니다**. 단 이 판단을 주석 없이 두면 후속 리뷰에서 매번 재논쟁이 되므로 명시가 요건이다.

---

## 7. 액션 → CF / Firestore 경로 매핑

> **중요한 정정.** 작업 지시에 `approveBrand` 가 Cloud Function 으로 적혀 있었으나, `functions/src/index.ts` 의 export 목록과 `functions/src/**` 전체에 **`approveBrand` / `rejectBrand` / `approveStore` CF 는 존재하지 않는다.** 승인·반려는 `lib/data/repositories/brand_repository_impl.dart:174-199` / `store_repository_impl.dart:133-148` 의 **클라이언트 Firestore 직접 쓰기**이고, Rules 의 admin 전권 분기(`allow update: if isAdmin()`)로 통과한다. 콘솔도 같은 경로를 쓴다.

### 7.1 Cloud Functions (실존 확인 — `functions/src/index.ts`)

리전은 전부 **`asia-northeast3`**. 웹에서 호출할 때 SDK 에 리전을 명시해야 한다(`getFunctions(app, 'asia-northeast3')`).

| 콘솔 액션 | CF | 입력 | 출력 | 주요 에러 코드 | 1차 범위 |
|---|---|---|---|---|---|
| (2차) 전역/브랜드/매장 적립률 변경 | `setQoinAccrualRate` | `{scope:'global'\|'brand'\|'store', targetId?, rate?\|clear?, reason?}` — `rate` 와 `clear` 는 **정확히 하나** | `{before, after, historyId, changed}` | `unauthenticated` / `permission-denied`(admin 아님) / `invalid-argument`(scope·targetId·rate 범위·reason>200자) / `not-found`(대상 없음) / `failed-precondition`(해당 브랜드 일괄 적용 진행 중) | ✗ |
| (2차) 브랜드/매장 적립 스위치 | `setQoinAccrualEnabled` | `{scope:'brand'\|'store', targetId, enabled:bool, reason?}` | 이력 포함 결과 | 위와 동일 계열 | ✗ |
| (비범위) 브랜드 일괄 적용 | `applyBrandQoinRate` | `{brandId, mode:'preserve'\|'overwrite', rate?\|clear?, reason?, resumeHistoryId?}` | 진행/집계 결과 | `failed-precondition`("브랜드 값이 그 뒤에 변경됐어요" / "already completed") / `internal`(중단 — `resumeHistoryId` 로 재개) | ✗ |
| (비범위) 매장 삭제 | `deleteStore` | `{storeId, reason(2~200자, dryRun 아닐 때 필수), dryRun?}` | `{alreadyDeleted}` \| `{dryRun, affected, blockedBy}` \| `{deletionId, phase:'done', affected}` | `failed-precondition` + `details.reason === 'STORE_HAS_INFLIGHT_ORDERS'` (진행 중 주문 가드) / `invalid-argument` / `not-found` | ✗ |
| (2차) brandKey 발급 | `issueBrandKey` | `{brandId}` | `{brandKey, alreadyIssued}` — 멱등 | `not-found`(브랜드 없음) / `aborted`(5회 재시도 실패) | ✗ |
| (2차) brandKey 조회 | `lookupBrandByKey` | `{brandKey}` | `{brandId, name, logoUrl}` | `unauthenticated` / `not-found` / `resource-exhausted`(분당 10회 초과) | ✗ |

> ### ⚠️ 정정 (2026-10-29) — 1차 CF 호출은 0건이 아니라 **1건**이다
>
> 최초 작성 시 "`approveBrand` CF 이 존재하지 않는다 → 1차 CF 호출 0건" 으로 적었다. **앞 절은 맞고 뒤 절이 틀렸다.**
>
> `approveBrand` 라는 **CF** 은 없지만, 같은 이름의 **리포지토리 메서드**가 CF 을 호출한다:
> [`lib/data/repositories/brand_repository_impl.dart:174-185`](../../../lib/data/repositories/brand_repository_impl.dart)
>
> ```dart
> Future<void> approveBrand(String brandId, String adminUid) async {
>   // 서버가 키를 발급(멱등)한 **뒤에만** 상태를 승인으로 바꾼다. 발급이 던지면 여기서 끝난다 — 문서 불변.
>   await _callables.issueBrandKey(brandId);
>   return _dataSource.update(brandId, { 'status': approved, 'approvedBy': adminUid, ... });
> }
> ```
>
> `docs/processes/role_flows.md` §4.4 도 같다: "**`issueBrandKey` CF 로 brandKey 발급 성공 후에만** status 승인".
>
> **웹이 `status` 만 쓰면 생기는 것**: brandKey 없는 `approved` 브랜드. 앱 승인 큐는 `status=pending` 만 스트림하므로(`watchPendingForAdmin` → `streamPending()`) 그 브랜드는 큐에서 영구히 빠지고 **앱에서도 키를 발급할 경로가 없다.**
>
> **따라서 브랜드 승인은 앱과 동일하게 2단계다**: `issueBrandKey` 성공 → `status` 쓰기. 아래 표의 `issueBrandKey` 행 "1차 범위" 를 **✓** 로 읽어라.
>
> 이것은 §6 보안 모델의 "admin 로직을 웹에서 재구현하지 말고 기존 CF 을 그대로 호출한다" 와 **어긋나지 않는다** — 오히려 그 원칙의 적용이다. 정정된 것은 사실관계이고 정책이 아니다.

**1차 CF 호출은 `issueBrandKey` 1건이다**(브랜드 승인 경로). 나머지 1차 액션(로그인·조회·매장 승인·반려, 브랜드 반려)은 Firestore 직접 접근이다.

### 7.2 Firestore 직접 경로 (1차)

| # | 콘솔 액션 | 경로 | 작업 | 보내는 필드 | Rules 근거 | 통과 |
|---|---|---|---|---|---|---|
| R1 | 로그인 후 role 확인 | `users/{uid}` | read | — | L108 `isAdmin() \|\| self(uid)` | ✅ |
| R2 | 브랜드 대기 목록 | `brands` where status=='pending' | read | — | L517 `allow read: if isSignedIn()` | ✅ |
| R3 | 브랜드 사업자 정보 | `brands/{id}/private/{docId}` | read | — | L584-585 `isAdmin() \|\| isBrandHolder \|\| isBrandSubmitter` | ✅ |
| R4 | **브랜드 승인** | `brands/{id}` | update | `status:'approved'`, `approvedBy:<uid>`, `approvedAt:serverTimestamp`, `rejectedReason:null`, `updatedAt:serverTimestamp` | L533-535 `!touchesQoinManaged() && (isAdmin() \|\| …)` — Qoin 관리 필드를 **건드리지 않으므로** 통과 | ✅ |
| R5 | **브랜드 반려** | `brands/{id}` | update | `status:'rejected'`, `approvedBy:<uid>`, `rejectedReason:<사유>`, `updatedAt` | 위와 동일 | ✅ |
| R6 | 매장 대기 목록 | `stores` where status=='pending' | read | — | L306 `isSignedIn()` | ✅ |
| R7 | **매장 승인** | `stores/{id}` | update | `status:'approved'`, `approvedBy:<uid>`, `approvedAt:serverTimestamp`, `rejectedReason:null`, `updatedAt` (`StoreModel.approveFields`) | L336-339 `!touchesQoinManaged() && (isAdmin() \|\| …)`. `leavingRejectedClearsApproval` 은 **점주/브랜드 분기 내부에만** 걸리므로 admin 승인(rejected→approved + approvedAt 쓰기)이 막히지 않는다 | ✅ |
| R8 | **매장 반려** | `stores/{id}` | update | `status:'rejected'`, `approvedBy:<uid>`, **`rejectedAt`**:serverTimestamp, `rejectedReason`, `updatedAt` (`StoreModel.rejectFields`) — ⚠️ 반려는 `approvedAt` 에 쓰지 **않는다**. 쓰면 결제 게이트 `canSellNow` 의 승인 이력 판정이 오염된다(payment_server_authority §6.8 / F-02) | 동일 | ✅ |
| R9 | 매장 전체 목록 | `stores` | read | — | L306 | ✅ |
| R10 | Qoin 전역 설정 조회 | `config/qoin` | read | — | L781 `isSignedIn()` | ✅ |
| R11 | Qoin 전역 이력 조회 | `config/qoin/qoinRateHistory` | read | — | L798-799 `isAdmin()` | ✅ |
| R12 | 마스터 메뉴 대기 목록 | `{path=**}/menuItems` (collection group) | read | — | L756-758 | ✅ |
| R13 | 매장 커스텀 대기 목록 | `{path=**}/menuOverrides` (collection group) | read | — | L760-763 | ✅ |
| R14 | (2차) 메인 카테고리 CRUD | `mainCategories/{id}` | create/update/delete | `label`, `displayOrder`, `active`, `createdAt`, `updatedAt` | L657-659 `allow create, update, delete: if isAdmin()` | ✅ |
| R15 | (2차) Qoin 비상 정지 토글 | `config/qoin` | update | `enabled`, **`enabledChangedBy:<uid>`(필수)**, **`enabledChangedAt:serverTimestamp`(필수)** | L789-797: `enabled` 변경 시 `enabledChangedBy == uid()` **그리고** `enabledChangedAt == request.time` 을 **반드시 동반**해야 한다. 생략하면 거부 | ✅ (필드 3개 동반 조건부) |
| — | **역할 부여** | `users/{uid}` | update | — | Rules 상 admin 전권으로 **통과하지만** 보안 모델상 **만들지 않는다**(§6-2) | 🚫 정책 금지 |

**Qoin 관리 필드 금지선**: `stores` / `brands` update 는 **모든 분기(admin 전권 포함)** 에서 `touchesQoinManaged()` 가 참이면 거부된다. 적립률·스위치·일괄 포인터는 CF 전담이다. 콘솔의 승인/반려 payload 는 이 필드들을 **절대 포함하지 않아야** 한다 — 하나라도 섞이면 승인 자체가 거부된다.

**또 하나의 정정**: 작업 지시에 "menuOverrides 승인 메타" 가 admin 조차 직접 쓸 수 없는 CF 전담 경로로 적혀 있었으나, `firestore.rules:481-497` 을 읽은 결과 **admin / 브랜드 보유자는 `menuOverrides` 의 `status`·`approvedBy`·`approvedAt` 을 직접 쓸 수 있다**(제한은 **점주** 분기에만 걸린다 — `ownerOverrideCreateOk()` 와 update 화이트리스트). 2차에서 매장 커스텀 승인을 웹에 넣을 때 CF 는 필요 없다.

---

## 8. 이력 / 감사 추적 (audit_trail §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값을 바꾸는가? | **1차는 권한 값을 바꾼다.** `stores.status`/`approvedAt` 은 결제 게이트 `canSellNow` 의 판정 입력이므로 **권한 값**이다(좁게 보지 않는다). → 이력 필요. **기존 설계가 이미 충족한다**: 승인/반려는 `approvedBy`·`approvedAt`/`rejectedAt`·`rejectedReason` 를 문서에 남기고, 반려 사유는 필수다. 또한 `onMenuPriceWritten` 계열·`storeDeletionHistory`·`qoinRateHistory` 가 각 영역 이력을 담당한다. **콘솔은 새 정책 값을 도입하지 않으므로 새 이력 스키마가 필요 없다** |
| 2 | 덮어쓰기로 사라지는 값이 있는가? | 승인/반려는 `status`·승인 메타를 덮어쓴다. 이는 **기존 앱과 완전히 동일한 동작**이고 콘솔이 새로 만드는 손실이 아니다. 다만 승인 → 반려 → 승인 반복의 **이전 심사 이력이 문서에 1세대만 남는 것**은 기존 설계의 알려진 한계다 → 별 과제 S4 (승인 이력 서브컬렉션). 이번 범위에서 바꾸지 않는다 |
| 3 | 거래/기록이 정책 값을 참조만 하는가? | 콘솔은 거래 문서를 만들지 않는다. 해당 없음 |
| 4 | "누가" 가 기록되는가? | **예.** 모든 승인/반려 payload 에 `approvedBy = 로그인 uid` 를 넣는다. 콘솔이 이 필드를 빠뜨리면 "Console 수동 편집과 구별되지 않는 이력" 이 된다 → **tester 필수 검증 항목**. (2차) 비상 정지 토글은 Rules 가 `enabledChangedBy`/`At` 을 강제한다 |
| 5 | 일괄 처리가 있는가? | **없다.** 1차는 1건씩 처리한다. 체크박스 다중 승인은 **의도적으로 비범위** — 넣으려면 "대상 수·덮어쓰기 여부" 를 묶어 남기는 이력 설계가 필요하고, 그것은 CF 가 써야 한다(§11-S5) |
| 6 | CF 로그에 의존하지 않는가? | 의존하지 않는다. 판단 근거는 모두 Firestore 문서에 있다 |
| 7 | 권한 판정 필드의 `create`/`update` 교차 확인 | 콘솔은 `stores`/`brands` 를 **create 하지 않는다**(승인 큐는 기존 문서 update 전용). create 경로를 쓰지 않으므로 이 항목의 위험을 구조적으로 피한다. **tester 는 "콘솔이 create 를 보내지 않는다" 를 확인**한다 |

**설정 변경 이력을 새로 만들지 않는 사유**(체크리스트 1의 명시 요건): 콘솔은 **새 정책 값을 도입하지 않고, 기존 앱과 동일한 필드 집합을 동일한 경로로 쓴다.** 이력의 주체·형식·보존이 전부 기존 설계를 그대로 상속하므로 콘솔 전용 이력 스키마는 중복이 된다. **표면이 늘었다는 사실 자체는 기록되지 않는다** — "앱에서 승인했는지 웹에서 승인했는지" 는 남지 않는다. 이것이 운영상 필요하다고 판단되면 별 과제 S6 로 올린다(기존 문서 필드 추가 = `lib/` 호환성 검토 필요 → 지금 불가).

---

## 9. 화면 구성과 데이터 흐름

### 9.1 화면 (Q1=B, Q2=권고안 기준)

```
landing/console/
├── index.html            로그인 + 셸 (좌측 네비 + 본문)
└── assets/
    ├── admin.css         style.css 의 CSS 변수를 재사용
    └── admin.js          Firebase 초기화 / 라우팅 / 데이터 접근
```

좌측 네비: **대시보드 / 승인(브랜드) / 승인(매장) / 매장 목록 / Qoin 현황**.
2차에 **메인 카테고리 / Qoin 설정(쓰기)** 추가. 네비는 1차부터 2차 항목 자리를 비워 두지 않는다(없는 메뉴를 보여주지 않는다).

### 9.2 데이터 흐름

```
브라우저 (landing/console)
  → Firebase JS SDK (Auth / Firestore / Functions[asia-northeast3])
  → Firestore Security Rules  ← 권위 ①
  → (특권 작업만) Cloud Functions requireAdmin()  ← 권위 ②
  → Firestore
```

- 콘솔에는 도메인/데이터 레이어 분리가 적용되지 않는다. **Clean Architecture 는 `lib/` 의 규칙**이고 `landing/` 은 Flutter 앱이 아니다. 다만 "Firebase 접근 코드를 화면 코드와 섞지 않는다"는 정신은 유지한다 — `admin.js` 안에서 **데이터 접근 함수와 렌더 함수를 분리**한다(developer 전달 사항).
- CLAUDE.md 절대규칙 2("Firebase 직접 사용은 data 레이어에서만")는 `lib/` 의 레이어 규칙이다. `landing/` 은 그 레이어 체계 밖이므로 **규칙 2 위반이 아니다.** 이 판단도 주석에 남긴다.

### 9.3 로그인 흐름

```
① 로그인 (Email/Password 또는 Google)
② users/{uid} 1회 read → role
③ role == 'admin'  → 셸 렌더
   그 외 / 읽기 실패 → 안내 + 로그아웃 (fail-closed)
④ 이후 모든 요청은 Rules 가 재판정 (② 결과를 신뢰 근거로 쓰지 않는다)
```

### 9.4 승인 흐름 (브랜드 예)

```
목록(brands status=pending)
  → 상세 (brands/{id} + brands/{id}/private/profile)
  → [승인] 확인 다이얼로그(브랜드명 재확인)
      → brands/{id} update {status, approvedBy:uid, approvedAt, rejectedReason:null, updatedAt}
  → [반려] 사유 입력(필수) → 확인
      → brands/{id} update {status:'rejected', approvedBy:uid, rejectedReason, updatedAt}
  → 성공 시 목록 갱신 / 실패 시 §10 표대로 표시 (목록에서 제거하지 않는다)
```

> **정정 (2026-10-29)**: 위 흐름의 `[승인]` 분기는 **2단계**다. `issueBrandKey(brandId)` CF 를 먼저 호출해 성공한 **뒤에만** `status` 를 쓴다. 앱의 `approveBrand` 와 동일한 순서이며, 이유는 §7.1 정정 블록에 있다.
>
> ```
>   → [승인] 확인 다이얼로그(브랜드명 재확인)
>       → ① issueBrandKey(brandId)  (CF, asia-northeast3, 멱등)
>           실패 → 여기서 중단. brands/{id} 는 손대지 않는다 (문서 불변)
>       → ② brands/{id} update {status, approvedBy:uid, approvedAt, rejectedReason:null, updatedAt}
> ```
>
> `[반려]` 분기는 CF 를 호출하지 않는다. 최초 작성의 "키 발급은 앱에서" 안내 문구 요건은 **철회**한다 — 그 전제가 틀렸다.

### 9.5 역할 흐름 / 엔티티 전이와의 관계

`docs/processes/role_flows.md` / `entity_lifecycle.md` 기준:
- **새 역할 흐름을 만들지 않는다.** admin 흐름의 **진입 수단**이 하나 늘어난다(앱 → 앱 + 웹).
- **status 전이 규칙은 바뀌지 않는다.** `brand`: `pending → approved | rejected`, `store`: `pending → approved | rejected` (반려 후 점주 수정 시 `rejected → pending` 재제출). 전이의 주체·조건·결과 필드가 모두 동일하다.
- **새 status 값, 새 전이, 새 엔티티는 없다.**

---

## 10. 에러 처리

### CF 에러 (2차 이후 / `firebase-functions` HttpsError code)

| code | 상황 | 콘솔 처리 |
|---|---|---|
| `unauthenticated` | 세션 만료 | 로그인 화면으로 보내고 "다시 로그인해주세요" |
| `permission-denied` | 서버 재검증에서 admin 아님 | "관리자 권한이 없습니다" + 로그아웃. **화면에서 숨기지 않았던 것이 아니라 권위가 서버에 있다는 정상 동작** |
| `invalid-argument` | 입력 범위·형식 위반 | 해당 입력 필드에 에러 표시. CF message 를 그대로 보여준다(한국어 메시지가 있다) |
| `not-found` | 대상 문서 없음 | "대상을 찾을 수 없습니다. 목록을 새로 고쳐주세요" + 목록 갱신 |
| `failed-precondition` + `details.reason === 'STORE_HAS_INFLIGHT_ORDERS'` | 매장 삭제 중 진행 주문 | 건수를 보여주고 차단. (1차 비범위) |
| `failed-precondition` (기타) | 일괄 적용 진행 중 / 값이 그 사이 변경됨 | CF message 를 그대로 표시 + 새로 고침 유도. **토큰 없는 `failed-precondition` 을 특정 가드로 해석하지 않는다**(기존 `classifyDeleteError` 와 같은 원칙) |
| `resource-exhausted` | `lookupBrandByKey` 분당 10회 초과 | "잠시 후 다시 시도" |
| `aborted` / `internal` | 서버 내부 실패 / 일괄 중단 | "실패했습니다. 다시 시도해주세요". **성공으로 표시하지 않는다**(fail-closed) |
| 응답 파싱 실패 | 기대한 형태가 아닌 응답 | **실패로 처리.** 숫자를 못 읽은 것을 "0건" 으로 읽지 않는다(기존 `parsePreview` 원칙) |

### Firestore Rules 거부

| 상황 | 콘솔 처리 |
|---|---|
| `permission-denied` (read) | 해당 카드만 "권한이 없어 불러올 수 없습니다". 전체 화면을 깨지 않는다 |
| `permission-denied` (write / 승인·반려) | "저장되지 않았습니다" + **목록에서 해당 항목을 제거하지 않는다.** 낙관적 UI 를 쓰지 않는다 — 권한 거부를 성공으로 보이게 하면 안 된다 |
| Qoin 관리 필드가 섞여 거부 | 구현 버그다. 콘솔은 그 필드를 보내지 않아야 한다(§7.2 금지선). tester 검증 항목 |
| `failed-precondition` (Rules `enabledChangedAt` 누락 등) | (2차) 구현 버그. payload 필드 3개 동반 확인 |

### 그 외

| 상황 | 처리 |
|---|---|
| 미인증 / 비admin | §6-3 표 |
| 네트워크 오프라인 | "연결을 확인해주세요" + 재시도. 쓰기 큐를 쌓지 않는다(오프라인 영속성 비활성) |
| Auth 승인 도메인 누락 (`auth/unauthorized-domain`) | 로그인 화면에 "호스팅 도메인을 Firebase Auth 승인 목록에 추가해야 합니다" 안내 — 배포 직후 가장 흔한 실패다 |
| 빈 목록 | empty 상태. 에러와 **구분**해 표시 |

---

## 11. 배포 절차 (사용자가 수행)

> **프로덕션 반영이므로 Claude 가 실행하지 않는다.** 또한 **Q3 권고 조건 ③ — 토스 PG 심사 종료 전에는 배포하지 않는다.** 심사 중에는 코드 머지까지만 진행한다.

### 배포 전 확인 (사용자)

1. Firebase Console → Authentication → Settings → **승인된 도메인**에 `order-app-5957e.web.app` (및 커스텀 도메인)이 있는지 확인. 없으면 웹 로그인이 `auth/unauthorized-domain` 으로 실패한다.
2. Authentication → Sign-in method 에서 **Email/Password 와 Google** 이 활성인지 확인.
3. 관리자 계정의 `users/{uid}.role` 이 `'admin'` 인지 Firestore Console 에서 확인.
4. **다른 세션의 결제 배포 작업이 진행 중이 아닌지** 확인. 같은 hosting 블록·같은 명령을 공유한다.

### 배포 명령

프로젝트 루트(`/Users/Byeonguk/Developer/OrderApp`)의 터미널에서 아래 한 줄을 실행한다.

```
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

- 이 명령은 `landing/` 전체(= landing 4개 페이지 + 새 `landing/console/`)를 함께 올린다. **landing 페이지가 깨지지 않았는지 배포 후 반드시 확인**한다.
- **전체 `firebase deploy` 를 실행하지 않는다.** Rules·Functions 가 함께 올라가면 다른 세션의 작업을 덮을 수 있다.

### 배포 후 확인 (사용자)

아래 4개 URL 이 정상인지 브라우저에서 확인한다.

```
https://order-app-5957e.web.app/index.html
https://order-app-5957e.web.app/terms.html
https://order-app-5957e.web.app/privacy.html
https://order-app-5957e.web.app/refund.html
```

그 다음 관리자 콘솔에 접속해 로그인과 승인 큐 조회를 확인한다.

```
https://order-app-5957e.web.app/console/index.html
```

`trailingSlash: false` / `cleanUrls: false` 설정 때문에 **`/admin` 이 아니라 `/console/index.html` 로 접근**해야 한다. `/admin` 으로도 열리게 하려면 hosting 블록에 rewrite 를 추가해야 하고, 그것은 landing 의 URL 동작에도 영향을 주므로 **별 과제 S7** 로 둔다.

### 롤백

```
cd /Users/Byeonguk/Developer/OrderApp && firebase hosting:rollback --project order-app-5957e
```

또는 Firebase Console → Hosting → 이전 버전 → 롤백.

---

## 12. 작업 분배

### designer — **호출 필요**

새 플랫폼의 새 화면 5개이고 데스크톱 레이아웃은 기존 디자인 시스템에 없다.

- 산출물: `docs/tasks/web_admin_console/design.md`
- 전달 사항:
  - **Q1/Q2/Q3 답을 받은 뒤 시작**한다. Q2 가 화면 개수를 결정한다.
  - 색상은 `landing/assets/style.css` 의 기존 CSS 변수를 재사용한다. **새 색상값 도입 금지** (CLAUDE.md 절대규칙 3의 정신 — `AppColors` 대응물이 여기서는 그 CSS 변수다).
  - 데스크톱 1024px 이상 기준. 좌측 네비 + 본문.
  - 승인/반려의 시각 위계, 반려 사유 입력, 확인 단계를 설계한다.
  - loading / error / empty 3종 상태를 **모두** 그린다(§2 상태 요구사항).
  - Qradar 용어(Qoin / Qrator / Log) 적용.

### developer — **호출 필요 (designer 이후)**

- 산출물: `docs/tasks/web_admin_console/implementation.md`
- 구현 항목: §2 의 F1~F7.
- **재사용할 기존 구조**: `landing/assets/style.css` CSS 변수. 승인/반려 **필드 집합**은 `lib/data/models/store_model.dart:338-361`(`approveFields`/`rejectFields`)과 `lib/data/repositories/brand_repository_impl.dart:174-199` 를 **그대로 옮긴다**(값을 새로 정하지 않는다).
- **주의할 규칙**:
  - 코드는 **`landing/console/` 밖으로 나가지 않는다.** `lib/` · `functions/` · `firestore.rules` 수정 금지(§5).
  - `firebase.json` 은 **손대지 않는다**(Q3=A 면 불필요).
  - 승인/반려 payload 에 **Qoin 관리 필드를 넣지 않는다** — 넣으면 Rules 가 전부 거부한다(§7.2).
  - 매장 반려는 `rejectedAt` 에 쓴다. **`approvedAt` 에 쓰지 않는다**(§7.2 R8).
  - Functions 호출 시 리전 `asia-northeast3` 명시(2차).
  - 낙관적 UI 금지 — 쓰기 성공 응답 전에 목록을 바꾸지 않는다.
  - `create` 를 보내지 않는다(§8-7).
  - Firebase web config 가 시크릿이 아닌 이유, `landing/` 이 Clean Architecture 레이어 밖인 이유를 **파일 주석으로 남긴다**(§6-4, §9.2).
  - git 커밋 시 `git add landing/console/...` 처럼 **경로를 하나씩 명시**한다.

### tester — **호출 필요**

- 산출물: `docs/tasks/web_admin_console/test_report.md`
- 주요 검증 기준:
  - §7.2 R1~R13 의 **각 액션이 실제로 Rules 를 통과하는지** (에뮬레이터 또는 테스트 계정).
  - 승인/반려 후 문서에 **`approvedBy` 가 로그인 uid 로 남는지**(§8-4). 빠지면 FAIL.
  - 매장 반려가 `rejectedAt` 에 쓰고 `approvedAt` 을 건드리지 않는지(결제 게이트 오염 방지).
  - 콘솔 payload 에 Qoin 관리 필드가 섞이지 않는지.
  - 콘솔이 `create` 를 보내지 않는지.
- **반드시 확인할 예외 케이스**:
  - **비admin 계정으로 로그인** → 본문이 렌더되지 않고 데이터 요청도 나가지 않는가.
  - **미로그인 상태로 `/console/index.html` 직접 접근** → 로그인 화면만.
  - **DOM 에서 버튼 비활성화를 강제로 풀어 승인 시도** → Rules 가 거부하고 콘솔이 성공으로 표시하지 않는가(권위 검증 — §6-1 의 핵심 테스트).
  - `users/{uid}` 읽기 실패 시 **fail-closed** 인가.
  - 승인 실패 시 목록에서 항목이 사라지지 않는가.
  - **배포 후 landing 4개 페이지가 그대로인가**(회귀).

### 호출 순서

```
(사용자 Q1/Q2/Q3 답) → /designer → /developer → /tester → architect 재검토
```

---

## 13. 별 과제 (지금 못 하는 것)

| # | 과제 | 왜 지금 못 하는가 | 열려면 무엇이 필요한가 |
|---|---|---|---|
| S1 | 승인 직후 brandKey 발급을 콘솔에서 | 1차 범위 축소 결정. CF(`issueBrandKey`)는 멱등이라 기술적 장벽은 없다 | Q2 답. 포함하면 1차 CF 호출이 1건 생긴다 |
| S2 | 공지 / 배너 / 쿠폰 관리 | **해당 컬렉션이 `firestore.rules` 에 없다**(`notice` 는 `stores` 필드). 새 Rules 가 필요하고 Rules 는 이 세션 읽기 전용 | 컬렉션 설계 + `firestore.rules` 변경 + 배포. 다른 세션 작업 종료 후 별 spec |
| S3 | 별도 Hosting 사이트로 분리 | `firebase.json` hosting 을 target 배열 구조로 바꿔야 하고, 다른 세션의 배포 명령과 충돌 | PG 심사 종료 + 다른 세션 종료 + Firebase Console 사이트 추가 + `firebase target:apply` |
| S4 | 승인 심사 이력 서브컬렉션 | 현재 승인 메타는 문서에 1세대만 남아 재심사 이력이 덮인다. 수정은 `lib/` 모델·Rules·CF 전부에 걸친다 | 별 spec. CF 가 이력을 쓰는 설계 필요(audit_trail: 쓰기 주체는 CF 가 기본) |
| S5 | 다중 선택 일괄 승인 | 일괄 처리는 "대상 수·덮어쓰기 여부" 를 묶어 남기는 이력이 필요하고(audit_trail §4-5), 그 쓰기 주체는 CF 여야 한다. `functions/` 는 읽기 전용 | 새 CF + 이력 스키마 설계. 별 spec |
| S6 | 액션 출처(앱/웹) 기록 | 기존 문서에 필드를 추가해야 하고 `lib/` 의 모델 호환성 검토가 필요 | `lib/` 수정 권한 + 모델 변경 검토 |
| S7 | `/admin` (확장자 없이) 접근 | `cleanUrls: false` / `trailingSlash: false` 이고 rewrite 추가는 landing URL 동작에 영향을 준다 | hosting 블록에 `/admin` → `/console/index.html` rewrite 추가. 심사 종료 후 |
| S8 | Flutter Web 전환(Q1=A) | §1-Q1: `firebase_options.dart` web 설정 부재 + 웹 미지원 플러그인 3종 + `lib/` 읽기 전용 | `flutterfire configure`, 플러그인 플랫폼 분기, admin 화면 반응형 재작업, `firebase.json` flutter 블록 수정 |
| S9 | App Check (웹) | 1차 범위 밖. 콘솔의 보호는 Rules + Auth 가 하고 있다 | reCAPTCHA Enterprise 설정 + CF `enforceAppCheck` 검토(= `functions/` 수정) |

---

## 14. 완료 기준

- [ ] Q1 / Q2 / Q3 에 사용자 답을 받고 §2 기능 범위를 확정했다
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료, FAIL 없음 또는 후속 분리
- [ ] §7.2 의 모든 액션이 **Rules 변경 없이** 통과함을 실제로 확인했다
- [ ] 콘솔에 역할 부여 기능이 **없음**을 확인했다
- [ ] 서비스 계정 키가 `landing/` 과 git 어디에도 **없음**을 확인했다
- [ ] 코드가 `landing/` 밖으로 나가지 않았음을 확인했다 (`lib/`·`functions/`·`firestore.rules` diff 0)
- [ ] 배포는 **사용자가** 수행했고 landing 4개 페이지 회귀가 없다
