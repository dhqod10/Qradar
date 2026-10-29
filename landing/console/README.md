# Qradar 운영 콘솔 (`landing/console/`)

로그인한 사용자의 `users/{uid}.role` 에 따라 보이는 섹션이 달라지는 **단일 정적 웹 앱**이다.
Flutter 앱(`lib/`)이 아니다. 빌드 단계·번들러·npm 이 없고, 브라우저가 이 폴더의 파일을 그대로 읽는다.

| 역할 | 섹션 | 하는 일 |
|---|---|---|
| `admin` | 승인 큐 · 대시보드 · 매장 목록 · Qoin 현황 | 브랜드/매장 승인·반려 (기존 web_admin_console 이관, 기능 변경 없음) |
| `brand` | 브랜드 정보 · 검토 현황 · 마스터 메뉴 · 서브 카테고리 · 옵션 그룹 · 산하 매장 | 가격 오버라이드·점포 한정 메뉴 제출. 승인은 admin 몫 |
| `owner` | 내 매장 · 매출 · 받은 평가 · 메뉴 관리 · 서브 카테고리 · 옵션 그룹 | 매장 운영/핵심 정보 수정(2폼). **주문 접수·제조·완료 화면은 없다** |
| `customer` | 프로필 · 주문 내역(Log) · Qoin | 읽기 전용. 자동 로그아웃 없음 |

> **이 콘솔은 클라이언트일 뿐이다.** 권한의 최종 권위는 Firestore Security Rules 와 Cloud Functions 다.
> 화면 숨김·탭 미노출·해시 정규화는 혼동을 줄이는 편의이며 접근 통제가 아니다. 역할(role) 부여 기능은 없다 —
> admin 승격은 Firestore Console 에서 `users/{uid}.role = 'admin'` 을 수동 설정하는 방법뿐이다.

- 접근 주소: **`/console/index.html`** (`firebase.json` 에 rewrite 가 없으면 `/console` 은 열리지 않는다 — `cleanUrls:false`)
- landing 페이지에서 이 콘솔로 가는 링크는 **만들지 않는다**
- **토스 PG 심사가 끝나기 전에는 배포하지 않는다**
- 설계 문서: `docs/tasks/web_role_console/{spec,design,implementation}.md`

## 파일

| 파일 | 역할 |
|---|---|
| `index.html` | 진입 HTML (스크립트·스타일 로드만) |
| `assets/console.css` | 스타일. `../assets/style.css` 의 CSS 변수만 사용 (색상 리터럴 없음) |
| `assets/firebase-config.js` | Firebase 웹 설정 (**시크릿 아님** — 파일 주석 참고) |
| `assets/console.js` | 진입점 (`console-shell.js` 의 `boot()` 호출) |
| `assets/console-shell.js` | 로그인 · 역할 판정 게이트 · 셸 · 해시 라우터 · 역할 변경 복구 |
| `assets/console-ui.js` | 공용 위젯 · 상태(S) · 대화상자 · 폼 빌더 |
| `assets/console-forms.js` | 메뉴 폼 · 옵션 비활성 대화상자 · 서브 카테고리/옵션 그룹 목록 (owner·brand 공통) |
| `assets/console-data.js` | Firebase SDK 접근(인증/Firestore/Functions/Storage) — **SDK 는 이 파일에서만 import** (10.14.1 고정) |
| `assets/console-payloads.js` | 쓰기 payload 빌더 + `assertPayload` 가드 (SDK 없음, Rules 줄번호를 데이터로 보유) |
| `assets/console-format.js` | 표시 형식 · 역할 판정(순수) · 매출 집계 · 오류 분류 (SDK 없음) |
| `assets/section-{admin,brand,owner,customer}.js` | 역할별 화면. 판정된 역할의 것만 동적 `import()` |

## 로컬 확인

터미널에서 아래 한 줄을 그대로 실행한다 (어느 폴더에서든). 종료는 `Ctrl+C`.

```bash
cd /Users/Byeonguk/Developer/OrderApp/landing && python3 -m http.server 5500
```

브라우저에서 `http://localhost:5500/console/index.html` 접속. ES 모듈을 쓰므로 `file://` 로 열면 동작하지 않는다.
로컬 정적 서버에는 Hosting rewrite 가 적용되지 않으므로 `/console` 이 아니라 `/console/index.html` 로 연다.
Firebase Auth 승인된 도메인에 `localhost` 가 있어야 로그인된다 (기본 포함). **로컬이어도 로그인하면 운영 Firebase 에 연결된다** — 쓰기를 하면 운영 데이터가 바뀐다.

## 배포 (사용자가 수행 — PG 심사 종료 후)

프로젝트 루트 터미널에서 아래 한 줄. 전체 `firebase deploy` 는 쓰지 않는다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

이 명령은 `landing/` 전체(랜딩 4페이지 + 이 콘솔)를 함께 올린다. 배포 뒤 `index.html` `terms.html` `privacy.html` `refund.html` 이 그대로인지 확인한다.
