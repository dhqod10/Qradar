# Qradar 관리자 콘솔 (`landing/admin/`)

승인 큐 4종 조회, 브랜드/매장 승인·반려, Qoin 현황 조회, 매장 목록 조회를 데스크톱 웹에서 하는 정적 콘솔이다.
Flutter 앱(`lib/`)이 아니다. 빌드 단계·번들러·npm 이 없고, 브라우저가 이 폴더의 파일을 그대로 읽는다.

> **이 콘솔은 클라이언트일 뿐이다.** 권한의 최종 권위는 Firestore Security Rules 와 Cloud Functions 다.
> 화면 구성은 혼동을 줄이는 편의이며 접근 통제가 아니다. 역할(role) 부여 기능은 없다 —
> admin 승격은 Firestore Console 에서 `users/{uid}.role = 'admin'` 을 수동 설정하는 방법뿐이다.

- 접근 주소: `/admin/index.html` (확장자 없는 `/admin` 은 열리지 않는다 — `cleanUrls:false`)
- landing 페이지에서 이 콘솔로 가는 링크는 **만들지 않는다**
- **토스 PG 심사가 끝나기 전에는 배포하지 않는다**
- 설계 문서: `docs/tasks/web_admin_console/{spec,design,implementation}.md`

## 파일

| 파일 | 역할 |
|---|---|
| `index.html` | 진입 HTML (스크립트·스타일 로드만) |
| `assets/admin.css` | 스타일. `../assets/style.css` 의 CSS 변수만 사용 (색상 리터럴 없음) |
| `assets/firebase-config.js` | Firebase 웹 설정 (**시크릿 아님** — 파일 주석 참고) |
| `assets/admin-data.js` | Firebase SDK 접근(인증/Firestore/Functions) — SDK 는 이 파일에서만 import |
| `assets/admin-payloads.js` | 승인/반려 payload (SDK 없음, 앱 필드 집합 그대로) |
| `assets/admin-format.js` | 표시 형식 / 오류 분류 / 입력 검증 (SDK 없음) |
| `assets/admin.js` | 화면 / 라우터(해시) / 모달 |

## 처음 한 번: 웹 앱 설정 채우기

`lib/firebase_options.dart` 에는 web 블록이 없다. Firebase Console > 프로젝트 설정 > 내 앱 에서 **웹 앱**을 추가하고
SDK 설정의 `apiKey`, `appId` 를 `assets/firebase-config.js` 에 채운다. 비어 있으면 콘솔은 "설정이 필요해요" 화면을 보여준다.
(`apiKey`/`appId` 는 공개 식별자이며 시크릿이 아니다. 서비스 계정 키는 이 폴더에 절대 넣지 않는다.)

## 로컬 확인

터미널(프로젝트 루트와 무관, 아래 한 줄을 그대로)에서 실행한다. 종료는 `Ctrl+C`.

```bash
cd /Users/Byeonguk/Developer/OrderApp/landing && python3 -m http.server 5500
```

브라우저에서 `http://localhost:5500/admin/index.html` 접속. ES 모듈을 쓰므로 `file://` 로 열면 동작하지 않는다.
Firebase Auth 승인된 도메인에 `localhost` 가 있어야 로그인된다 (기본 포함).

## 배포 (사용자가 수행 — PG 심사 종료 후)

프로젝트 루트 터미널에서 아래 한 줄. 전체 `firebase deploy` 는 쓰지 않는다.

```bash
cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting --project order-app-5957e
```

이 명령은 `landing/` 전체(랜딩 4페이지 + 이 콘솔)를 함께 올린다. 배포 뒤 `index.html` `terms.html` `privacy.html` `refund.html` 이 그대로인지 확인한다.
