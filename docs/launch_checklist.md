# 운영 전환(런칭) 체크리스트

> 테스트 → 프로덕션 전환 시 해야 할 일. 작성 2026-10-30.
> 목표: **승인·심사에 묶인 최소 항목만 런칭 때 남기고, 나머지는 미리 준비.**

---

## 🔴 런칭 때만 가능 (승인·심사·실키 의존 — 줄일 수 없는 최소)

- [ ] **TOSS 라이브 전환** — 사업자 머천트 심사 통과 후 live client key + secret key 적용.
  - 현재: 테스트 키 `test_gck_docs_...`(env.json). → live 키로 교체.
  - secret은 functions env(verifyTossPayment), client는 앱 빌드 dart-define.
- [ ] **소셜 로그인 "배포/검수" 승인** — 카카오/네이버/구글 앱을 개발중 → 공개로.
  - 일부 동의항목(이메일 등)은 검수 필요. **검수 신청은 지금 미리 가능**, 승인만 런칭 전 대기.
- [ ] **앱 스토어 심사·배포** — Play Store / App Store 등록 + release 서명 빌드 + 심사.
- [ ] **테스트 데이터 초기화** — go-live 직전 Firestore 테스트데이터 정리.
  - 대상: 강남점(매장/메뉴/오버라이드), 테스트 계정(customer/owner/brand/admin), 주문, Qoin 원장, 리뷰.
  - 깨끗한 상태에서 공개 시작.

---

## 🟢 지금 준비 가능 (해두면 런칭 때 TOSS만 남음)

- [x] **#1 소셜로그인 audience 구현** — 카카오 서버 app_id 검증 + 네이버 code-exchange(플랜 B: https 중계페이지). (`docs/tasks/social_login_audience/`) **구현+iOS 실기기 검증 완료(2026-10-30), Android 검증 중.** 후속: 프로필 null(backlog SL-1).
- [x] **네이버 client_secret + redirect_uri 등록** — 콘솔 등록 완료(PC웹 환경, `…/auth/naver.html`), secret 재발급+주입(secrets:set) 완료. 실값은 gitignored env 에만.
- [ ] **APNs 키 등록 (iOS 푸시)** — 지금 하면 iOS 푸시 활성 + backlog **N5 보류 4건(T9/T13/T-B11/F22)** 해소. (`docs/tasks/ios_apns_setup/spec.md`)
- [ ] **App Check 설정** — 현재 **미설정**. callable(verifyTossPayment/verifyKakaoToken/verifyNaverToken)을 봇·남용에서 보호. #1 audience 보안과 결이 같아 함께 권장.
- [ ] **release 서명 키 생성** — Android keystore / iOS 배포 인증서·프로비저닝.
- [ ] **스토어 리스팅 초안** — 스크린샷, 설명, 개인정보처리방침 URL(landing에 있음), 지원 연락처.
- [ ] **Qoin 적립률 최종값 확정** — 현재 전역 5%(config/qoin). 런칭 값 결정.
- [ ] **런칭 전 보안·무결성 묶음**
  - [ ] Q3 Layer1 자기거래 가드 (verifyTossPayment self-order 거절 + 자기리뷰 차단 + Qoin 자기적립 제외)
  - [ ] Layer2 신호수집 선제 (order에 기기/카드해시/IP 저장 — 탐지는 나중, 데이터만 미리)
  - [ ] D2 점주 점포한정 메뉴 자가승인 가드
- [ ] **등급 최소리뷰수 단위테스트 보강** (후속 후보)
- [ ] (소소) main.dart 카카오 `nativeAppKey` 하드코딩 → dart-define 이관 (공개키라 급하진 않음)
- [ ] (소소) `countStoresUsingPriceOverride` 복합 [masterMenuItemId,status] 인덱스 — 실행 시 에러나면 추가

---

## ✅ 이미 완료 / 준비됨 (참고)

- [x] 결제 서버 게이트 `PAYMENT_GATE_MODE=enforce` / `PAYMENT_PRICE_MODE=enforce` (배포됨)
- [x] #7 phantom appId → 실앱 수렴 (flutterfire configure, android 1b45f24b / ios 7beb72e4)
- [x] 브랜드 자가승인 Rules 차단 (brand_self_approve_guard, 배포됨)
- [x] 브랜드 write 타임스탬프 왕복 하드닝 (brand_update_partial_hardening)
- [x] temporaryClosed C (임시휴업이 실제로 판매 차단) — functions 배포됨, 앱 반영됨
- [x] 등급 최소 리뷰수(3건) 게이팅 (grade_min_reviews)
- [x] menu_override masterMenuItemId + cascade 정리
- [x] landing 4페이지 (index/privacy/refund/terms) — 개인정보/약관 URL 확보

---

## ℹ️ 메모

- **환경 분리 없음**: 테스트·프로덕션이 동일 Firebase 프로젝트(`order-app-5957e`). 별도 prod 프로젝트를 둘지는 추후 결정(현재는 동일 프로젝트로 go-live 전제).
- **웹 관리자 콘솔**(landing/console, 별도 세션)은 PG 심사 후 배포 예정 — 그 쪽 체크리스트는 web_role_console 참조.
- 소셜 로그인 계정 동일성: 콘솔 작업 시 **기존 카카오/네이버 앱에 웹 플랫폼 추가**(새 앱 생성 금지 — 회원번호 달라져 계정 분리, 되돌리기 어려움).
