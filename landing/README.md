# Qradar 랜딩 페이지 (토스페이먼츠 PG 심사용)

토스페이먼츠 전자결제 가맹점 심사에 제출하는 **공개 홈페이지**다.
Firebase Hosting 으로 배포되며, 심사자가 사업자 정보 · 판매 상품 · 가격 ·
결제 수단 · 환불 정책 · 고객센터를 확인하는 창구다.

- **Firebase 프로젝트**: `order-app-5957e`
- **배포 URL**: https://order-app-5957e.web.app
- **이 폴더의 위치**: `OrderApp` **앱 저장소 안의 하위 폴더**다. 별도 저장소가 아니다.

---

## 🔴 반드시 지킬 규칙

> **전제**: 같은 `OrderApp` 저장소에서 **다른 세션이 결제 관련 배포 작업을 동시에 진행**하고 있다.
> 아래 4개는 그 세션의 작업을 깨뜨리지 않기 위한 규칙이며, 예외가 없다.

### 1. 배포는 hosting 만 — `firebase deploy` 단독 사용 절대 금지

```bash
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

**위 한 줄만 쓴다.** 저장소 루트에서 실행한다 (`firebase.json` 을 읽어야 하므로).

왜 `--only hosting` 이 필수인가:
저장소 루트의 `firebase.json` 에는 `hosting` 외에 `functions` · `firestore` · `storage`
설정이 **같이** 들어 있다. `firebase deploy` 만 치면 운영 중인 결제 함수
(`verifyTossPayment` — **enforce 모드**)와 Firestore Rules 까지 함께 배포되어 사고가 난다.

`--project order-app-5957e` 도 생략하지 않는다. 프로젝트를 명시해 오배포를 막는다.

> **배포 전 확인**: 아래 "사업자 정보 체크리스트" 의 TODO 가 하나라도 남아 있으면 배포하지 않는다.
> `{{상호명}}` 같은 플레이스홀더가 공개 URL 에 노출되면 그 자체로 심사 반려 사유가 된다.
> 내용만 미리 확인하려면 공개되지 않는 로컬 서버를 쓴다 (아래 "로컬 확인").

### 2. `firebase.json` 을 다시 건드리지 않는다

이미 `hosting` 블록이 기존 `functions` / `firestore` / `storage` / `flutter` / `emulators`
설정과 올바르게 **병합**되어 있다 (추가 +30줄, 삭제 0줄).

- `firebase init` 을 **다시 돌리지 않는다.** 이 파일을 덮어쓰면 다른 세션의 배포 설정이 깨진다.
- 수정이 꼭 필요하면 **`hosting` 블록만** 손댄다.
  `functions` / `firestore` / `storage` / `flutter` / `emulators` 블록은 절대 건드리지 않는다.

### 3. git 은 정확한 경로만 — `git add -A` / `git add .` 금지

```bash
cd /Users/Byeonguk/Developer/OrderApp && git add landing/ && git commit -m "..."
```

두 세션이 동시에 작업하므로 `git add -A` 를 쓰면 다른 세션이 작업 중인
파일(결제 코드 · 문서)을 이 커밋에 쓸어담는다.

저장소 루트의 다른 파일(`firestore.rules`, `functions/`, `lib/`, `docs/` 등)은
**건드리지도, 커밋하지도 않는다.**

### 4. 작업 범위는 `landing/` 안으로만

`lib/`, `functions/`, `firestore.rules`, `docs/tasks/` 등은 다른 세션의 작업 영역이다.
**참조는 읽기만 하고, 쓰기 · 수정은 `landing/` 폴더 밖으로 나가지 않는다.**

---

## 로컬 확인 (배포하지 않고 보기)

```bash
cd /Users/Byeonguk/Developer/OrderApp/landing && python3 -m http.server 5500
```

브라우저에서 `http://localhost:5500` 접속. 종료는 터미널에서 `Ctrl+C`.

공개 URL 로 실제 배포 결과를 미리 보고 싶으면 **프리뷰 채널**을 쓴다.
운영 URL(`order-app-5957e.web.app`)을 덮어쓰지 않고 임시 주소를 발급한다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && firebase hosting:channel:deploy preview --project order-app-5957e --expires 7d
```

---

## 페이지 구성

| 파일 | 역할 | 심사 대응 항목 |
|---|---|---|
| `index.html` | 랜딩 본문 | 서비스 소개 · 이용 방법 · **판매 상품 및 가격** · 결제 수단 · **상품 제공(배송) 안내** · 환불 요약 · **고객센터** |
| `terms.html` | 서비스 이용약관 (18조) | 계약 성립 · 결제 · 청약철회 · Qoin · 책임 범위 |
| `privacy.html` | 개인정보처리방침 (14장) | 수집 항목 · 처리위탁 · **국외이전** · 위치정보 · 개인정보보호책임자 |
| `refund.html` | 취소 · 환불 정책 (8조) | **시점별 취소 기준 · 환불 사유 · 환불 소요 기간** |
| `assets/site.js` | **사업자 정보 단일 진실원** + 공통 헤더 · 푸터 주입 | 푸터 필수 표기 전부 |
| `assets/style.css` | 스타일 | 앱 팔레트 토큰을 CSS 변수로 미러링 |
| `assets/favicon.svg` | 파비콘 | — |
| `console/` | **운영 콘솔** (별도 앱 — 심사 대상 아님) | 아래 참조 |

### `console/` — 역할별 운영 콘솔

`landing/console/` 은 심사용 랜딩과 **별개의 앱**이다. 로그인한 사용자의 `users/{uid}.role` 에 따라
admin / brand / owner / customer 섹션이 갈린다. 작업 문서는 `docs/tasks/web_admin_console/` 과
`docs/tasks/web_role_console/`.

- 접근: `/console/index.html` (`trailingSlash:false` + `cleanUrls:false` 라 `/console` 은 아직 404.
  배포 전에 hosting 블록에 rewrite 1줄을 넣어야 한다 — 규칙 2 가 허용하는 범위)
- 🔴 **랜딩에서 `/console` 로 가는 링크를 만들지 않는다.** PG 심사 종료 후 헤더에 로그인 버튼을 단다.
- 🔴 **PG 심사 종료까지 배포하지 않는다.**
- 로컬에서 열어도 **로그인하면 운영 Firebase 에 붙는다.** 쓰기 확인은 테스트 계정으로만.

### 고치는 위치

- **사업자 정보** → `assets/site.js` 상단 `BIZ` 객체. **여기 한 곳만** 고치면 4개 페이지 전부 반영된다.
- **색상** → `assets/style.css` 의 `:root` 변수. 앱의
  `lib/core/theme/color_palette.dart` → `LightMidnightAccentPalette` 값을 그대로 옮긴 것이다.
  새 색을 쓰지 말고 기존 변수를 쓴다.
- **메뉴 · 가격** → `index.html` 의 `#menu` 섹션.
  앱의 `lib/dev/seed/phase1_seed_data.dart` 실제 값과 **일치해야 한다**
  (홈페이지 표기 금액과 실제 결제 금액이 다르면 심사 반려 사유).

---

## 심사용 사업자 정보 체크리스트

모두 `assets/site.js` 의 `BIZ` 객체에 입력한다.

> ⚠️ 토스페이먼츠는 **홈페이지 하단의 상호명 · 사업장 주소 · 대표자명이
> 사업자등록증과 한 글자라도 다르면 심사를 반려**한다. 띄어쓰기까지 서류 그대로 입력한다.

| 항목 | `BIZ` 키 | 상태 |
|---|---|---|
| 상호명 | `company` | ⬜ **TODO** — 서류 전달 대기 |
| 대표자명 | `ceo` | ⬜ **TODO** — 서류 전달 대기 |
| 사업자등록번호 | `bizNo` | ⬜ **TODO** |
| 통신판매업 신고번호 | `mailOrderNo` | ⬜ **TODO** |
| 사업장 주소 (우편번호 포함) | `address` | ⬜ **TODO** |
| 고객센터 전화번호 | `tel` | ⬜ **TODO** |
| 고객센터 이메일 | `email` | ⬜ **TODO** |
| 개인정보보호책임자 성명 | `privacyOfficer` | ⬜ **TODO** |
| 개인정보보호책임자 직위 | `privacyOfficerTitle` | ⬜ **TODO** |
| 개인정보 문의 이메일 | `privacyEmail` | ⬜ **TODO** |
| 고객센터 운영시간 | `hours` | ✅ 기본값 입력됨 (평일 10:00~18:00) — 실제와 다르면 수정 |
| 호스팅서비스 제공자 | `hosting` | ✅ Google Cloud Platform (Firebase Hosting) |
| 결제대행사 | `pg` | ✅ 토스페이먼츠 주식회사 |

**통신판매업 신고번호가 없으면 국민카드 심사에서 제외된다.**
(간이과세자 · 비영리기관 · 공공기관은 없어도 된다.)

### 아직 결정되지 않은 것

- **앱 스토어 다운로드 링크** — 미출시로 보여 히어로에 버튼을 두지 않았다.
- **앱 화면 스크린샷** — 섹션 없음.
- 심사는 "테스트 환경이 아닌 **실제 앱에서도 결제 연동 완료**" 를 확인한다.
  스토어 링크 제출 / 테스트 계정(ID · PW) 제출 중 **어느 쪽으로 갈지 결정 필요**.

### 남은 리스크

- 현재 푸터 · 헤더는 `assets/site.js` 가 **런타임에 주입**한다.
  심사자가 JS 비활성 상태나 크롤러로 열면 사업자 정보가 보이지 않는다.
  **서류 값이 확정되면 각 HTML 에 푸터를 직접 박아넣을 것.**
- `terms.html` · `privacy.html` · `refund.html` 은 표준 양식에 Qradar 실제 구조
  (Firebase 국외이전 · `geolocator` 위치정보 · 소셜 로그인 3종 · FCM · 토스 위탁)를
  반영한 **초안이며, 법률 검토를 받지 않았다.**

---

## 참고 (앱 정보 — 읽기 전용)

아래 파일은 **읽기만** 한다. 수정은 다른 세션의 영역이다 (규칙 4).

| 내용 | 경로 |
|---|---|
| 앱 정체성 · 톤 · 고유 용어(Qoin / Qrator / Log) · 절대 규칙 | `/Users/Byeonguk/Developer/OrderApp/CLAUDE.md` |
| 제품 범위 · 역할별 기능 명세 | `/Users/Byeonguk/Developer/OrderApp/docs/product_scope.md` |
| 색상 토큰 접근자 | `/Users/Byeonguk/Developer/OrderApp/lib/core/theme/app_colors.dart` |
| 색상 팔레트 실제 값 | `/Users/Byeonguk/Developer/OrderApp/lib/core/theme/color_palette.dart` |
| 로고 기하 (SVG 재현 원본) | `/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/q_logo.dart` |
| 메뉴 · 가격 실제 값 | `/Users/Byeonguk/Developer/OrderApp/lib/dev/seed/phase1_seed_data.dart` |
