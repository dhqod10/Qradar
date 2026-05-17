# Backlog

확정되지 않았거나 후속 phase 로 미룬 작업을 기록하는 단일 진실원.
각 항목은 추후 `docs/tasks/[기능명]/spec.md` 로 승격될 수 있다.

---

## 인증 / 계정

### 다중 인증 제공자 계정 통합

**배경**
현재 카카오 / 네이버 / 이메일 인증이 각기 다른 uid (kakao_xxx, naver_xxx, FirebaseAuth uid) 를 발급하므로, 동일 사용자가 다른 provider 로 재로그인하면 별개 계정으로 인식된다. 즐겨찾기 / Log / Qoin 등이 provider 별로 분리되어 쌓인다.

**목표**
한국 커머스/배달앱 (배민, 쿠팡, 토스 등) 처럼 동일 사용자임을 인식해 데이터를 통합한다.

**고려 방향**
1. **휴대폰 번호 기반 통합 (1순위)** — phone verification 도입 후 동일 번호면 자동 merge. 가장 자연스러움.
2. **Firebase `linkWithCredential`** — 로그인된 상태에서 다른 provider 를 명시적으로 연결. 마이페이지에 "다른 계정 연결하기" 메뉴.

**선행 조건**
- phone verification 도입 (별도 task)
- 기존 분리된 데이터 마이그레이션 정책 결정 (기존 즐겨찾기/주문 어떻게 합칠지)

**예상 시점**
Phase 4-5 (phone auth 도입과 함께)

---

## 결제 / 주문 흐름

### Phase 3a — 결제 인프라 + 카드 + 카카오페이
- 토스페이먼츠 PG 통합 (Flutter SDK)
- 결제창 호출 + 결과 콜백
- 결제 완료 → Firestore 주문 doc 생성 (`orders/{orderId}` — status='paid')
- 영수증 link 저장 (PG 사 제공 URL)
- 결제 실패 처리 (앱 내 다이얼로그 + FCM 푸시)
- 환불 흐름 (점주 동의 → PG 환불 API)
- customer/owner 양쪽 UI
- **첫 결제 수단**: 신용/체크카드 + 카카오페이
- Qoin 적립 hook 만 미리 마련 (실제 적립은 Qoin phase)

### Phase 3b — 나머지 결제 수단 활성화
- 네이버페이, 토스페이, 삼성페이, 애플페이
- 계좌이체, 휴대폰 결제, 네이버포인트, 상품권
- PG SDK 옵션 활성화 + UI 추가

### Phase 4 — Qoin 도메인 (별도 분리 — 사용자 결정)
- QoinBalanceEntity / QoinTransactionEntity / QoinRepository
- `users/{uid}/qoinBalance` + `users/{uid}/qoinTransactions/{txId}` 또는 root `qoinTransactions/`
- 적립 / 사용 / 환불 흐름 (atomic Transaction)
- 마이페이지 잔액 표시 / 결제 화면에 Qoin 사용 옵션
- Phase 3a 의 적립 hook 에 연결

---

## 주문 운영 흐름 (Phase 3 완료 후)

### 주문 상태 흐름
`paid → accepted → making → ready → completed` 또는 `cancelled / refunded`. FCM 푸시 + customer/owner 양쪽 알림.

### 주문 내역 (Log)
customer 측 Log 탭. 현재 placeholder. 결제 완료 주문들이 자동 노출. 영수증 보기 / 재주문.

### 점주 주문 접수
`OwnerOrdersPlaceholder` 자리. 신규 주문 listen → 접수/거절 → 상태 변경 → 완료. 거절 시 환불.

### 점주 매출 조회
`OwnerSalesPlaceholder` 자리. 시간대/일/월/연/카드사별 매출 통계.

### 매장 운영시간 자동 차단
운영시간 외 주문 차단. (도메인 일부 있음 — 확인 후 보강.)

### 검색 기능
홈 검색바. 현재 "검색 준비 중" placeholder. 매장/메뉴 검색.

---

## 가치 확장 기능

### 매장 후기 / 평점
1~5점 + 텍스트 리뷰. 매장 상세 화면.

### 선물하기
기프트카드 / 쿠폰 / 음료 선물.

### admin 운영 도구
- 회원 관리 (조회 / 정지 / 탈퇴)
- 전체 매출 조회 (기간 / 매장 / 브랜드)
- 공지사항 / 배너 관리
- 쿠폰 / 이벤트 관리

---

## Follow-up (admin_menu_management 완료 후 미적용)

### F1 — 메뉴 카테고리 비활성화 시 외부 알림
sub-phase 9 의 4d Heavy. FCM/이메일로 매장 운영자에게 알림.

### F4 — 매장 분류 태그 (`MenuCategories.all`) 동적화
sub-phase 9 의 메인 카테고리 admin 관리 패턴 차용. 현재 12개 string 하드코딩.

### F7 — 서브 카테고리 NLP 유사명 감지
sub-phase 8 의 약한 검증 강화. "콜드브루" vs "콜드부루" 같은 오타 자동 감지.

### F8 — admin 서브/옵션 그룹 분포 모니터링
sub-phase 8/7. brand/매장이 만든 사용자 정의 분류/옵션 그룹의 분포 audit.

### F10 — 옵션 그룹 `applicableMainCategories` 자동 필터
sub-phase 7. 메인 카테고리별 옵션 그룹 노출 제한 (예: 에이드 메뉴에 "샷 추가" 자동 숨김).

### F11 — admin 옵션 그룹 모니터링
sub-phase 7. brand/매장 옵션 그룹의 분포 audit.

---
