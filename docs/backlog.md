# Backlog

확정되지 않았거나 후속 phase 로 미룬 작업을 기록하는 단일 진실원.
각 항목은 추후 `docs/tasks/[기능명]/spec.md` 로 승격될 수 있다.

---

## 현재 남은 작업 (2026-10-21 코드 기준 전수 조사)

Phase 3c 완결 시점의 스냅샷. **문서가 아니라 코드를 읽어 작성했다.**

### 탭에 연결된 미구현 화면

| 화면 | 위치 | 비고 |
|---|---|---|
| 점주 매출 조회 | `owner_scaffold.dart:63` → `OwnerSalesPlaceholder` | 점주 4탭 중 1개가 통째로 빔. 데이터는 이미 존재 |
| 고객 Qoin | `customer/qoin/qoin_page.dart:50` | Phase 4 Qoin 도메인으로 별도 분리 결정됨 |

### 진입점만 있고 동작 없음 (SnackBar `준비 중`)

| 기능 | 위치 |
|---|---|
| 홈 검색 | `customer/home/widgets/home_header.dart:200` |
| 추천 매장 더보기 | `customer/home/widgets/recommended_stores_section.dart:70` |

### 기술 부채 / 품질 (상세는 아래 Follow-up 절)

| # | 항목 | 규모 |
|---|---|---|
| N1 | flow 헬퍼·CTA 핸들러 자동화 테스트 | 중 |
| ~~N2~~ | ~~Rules 테스트 하네스 편입~~ → **완료 (2026-10-21)** `test_rules/` | — |
| ~~N4~~ | ~~`auth_provider.dart` 레이어 정리~~ → **완료 (2026-10-21)** | — |
| N3 | iOS 점주 `notDetermined` 배너 게이트 | 소 |
| N6 | `notificationPermissionPrompted` 필드명 정리 | 마이그레이션 동반 시 |

### 환경 대기

`docs/tasks/ios_apns_setup/spec.md` (출시 1~2주 전 예정) 완료 시 N5 의 보류 4건(T9 / T13 / T-B11 / F22)이 함께 해소된다.

### 출시 준비

`docs/dev_to_prod_checklist.md` 참조.

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

## 주문 운영 흐름

> **2026-10-21 코드 기준 재조사.** 이 절의 상당수가 이미 구현 완료였고 문서만 낡아 있었다.
> 이후 이 절을 수정할 때는 **반드시 코드를 먼저 확인**한다 (`grep` 으로 placeholder 문자열만 보면 죽은 파일에 속는다).

### ✅ 주문 상태 흐름 — 구현 완료
`paid → accepted → making → ready → completed` / `cancelled / refunded`. FCM 푸시 + customer/owner 양쪽 알림.
Phase 3c-1~3c-4 에서 완료. 라이브 검증 완료 (각 sub-phase `test_report.md`).

### ✅ 주문 내역 (Log) — 구현 완료
Log 탭은 `lib/presentation/customer/log/orders_page.dart` (`OrdersPage`) 를 사용한다.
매장명 / 대표 메뉴 / 금액 / 상태 배지(완료·환불 완료) / 상대 시간 노출, 탭 시 `OrderDetailPage` 진입.
재주문은 `lib/presentation/customer/home/widgets/quick_reorder_section.dart` 에 구현돼 있다.
남은 것: **영수증 보기**(PG 영수증 URL 노출) — 미확인, 필요 시 별도 task.

### ✅ 점주 주문 접수 — 구현 완료
`lib/presentation/owner/orders/owner_orders_page.dart` (`OwnerOrdersPage`).
신규 / 조리 중 / 환불 요청 3탭, 접수·거절·조리 시작·준비 완료·픽업 완료 전이 전부 동작.

### ⬜ 점주 매출 조회 — **미구현 (유일하게 탭에 연결된 placeholder)**
`lib/presentation/owner/placeholders/owner_sales_placeholder.dart` 가 `owner_scaffold.dart:63` 에 **실제로 연결돼 있다.**
점주 4개 탭 중 하나가 통째로 비어 있는 상태.
필요: 시간대 / 일 / 월 / 연 / 카드사별 매출 통계. 데이터는 `orders` 컬렉션에 이미 쌓여 있어 집계만 하면 된다.

### ⬜ 점주 매출 조회 — 2차 범위 (1차 착수 시 **의도적으로 제외**한 항목)

1차(`owner_sales` task)는 **일/주/월 요약 + 주문 목록 + 클라이언트 집계** 로 범위를 좁혔다.
아래는 "안 하기로" 한 것이 아니라 **2차로 미룬 것**이며, 1차 화면 구조를 그대로 두고 얹을 수 있게 설계한다.

| # | 항목 | 미룬 이유 | 선행 조건 |
|---|---|---|---|
| S1 | **메뉴별 판매 순위** | `orderItems` 순회가 필요해 집계 로직이 한 단계 더 복잡해진다 | 1차 집계 레이어 완성 |
| S2 | **시간대별 분포 차트** | 차트 라이브러리 도입 여부를 함께 결정해야 한다 (현재 리포지토리에 차트 의존성 없음) | 라이브러리 선정 |
| S3 | **카드사별 매출** | PG 응답에 카드사 정보가 저장되고 있는지 미확인 | `orders` 의 결제 정보 필드 실측 |
| S4 | **연 단위 / 기간 비교** (전월 대비 등) | 1차는 일/주/월까지. 비교 UI 는 별도 판단 | — |
| S5 | **Cloud Function 집계 문서** | 1차는 클라이언트 집계. 주문량이 늘어 읽기 비용이 문제될 때 전환 | 전환 기준 수치 정의 + 기존 주문 백필 |

**S5 전환 시점 판단**: 클라이언트 집계는 조회 기간의 주문 수만큼 document read 가 발생한다. 단일 매장 기준으로는 충분하나, 월 주문 수가 수천 건대에 들어가거나 점주가 연 단위 조회를 요구하면 전환을 검토한다.
1차 설계 시 **집계 로직을 UseCase 로 분리**해 두면 S5 전환 때 데이터 소스만 바꾸고 화면은 손대지 않을 수 있다 — architect 에게 이 제약을 전달했다.

### ⬜ 매장 운영시간 자동 차단
운영시간 외 주문 차단. (도메인 일부 있음 — 확인 후 보강.)

### ⬜ 검색 기능
홈 검색바. `home_header.dart:200` 에서 `검색 준비 중입니다` SnackBar. 매장/메뉴 검색.

### ⬜ 추천 매장 더보기
`recommended_stores_section.dart:70` 에서 `준비 중입니다` SnackBar.

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

## Follow-up (order_flow_phase3c 완료 후 미적용)

출처: `docs/tasks/order_flow_phase3c/3_notification_settings/test_report.md` (F 절),
`docs/tasks/order_flow_phase3c/4_notification_permission_retry/test_report.md` (우선순위 / Z 절 / L 절).

### N1 — 알림 권한 flow · CTA 핸들러 자동화 테스트
sub-phase 4 의 단위 테스트는 `NotificationPermissionPromptState` 경계값, `parseLaterCount`, `ShouldShowNotificationPermissionDialogUseCase` 3종을 덮는다. 반면 **`runNotificationPermissionPrompt` 의 기록 분기**(allow→`prompted=true` / later→`increment` / null→write 없음)와 **`_onPermissionCtaTap` 의 폴백·세션 가드 분기**는 자동화 0건이며 코드 검증 + 라이브로만 확인됐다.
이 둘은 회귀가 **조용히** 발생하는 지점이다 (쓰기가 안 돼도 UI 에 증상이 없다). 위젯 테스트 또는 repository fake 를 쓴 flow 단위 테스트를 권장한다.

### ~~N2~~ — Firestore Rules 테스트 하네스 리포지토리 편입 ✅ 완료 (2026-10-21)

`test_rules/` 로 편입 완료. 실행: `cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test` (최초 1회 `npm install`).
케이스 R1~R12, 실행 결과 12/12 PASS. `firebase.json` 에 `emulators.firestore.port = 8137` 추가.
`firebase-tools@14` 고정 — 15 부터 JDK 21 을 요구하는데 로컬은 JDK 17 이다. 상세는 `test_rules/README.md`.

<details><summary>원래 기술</summary>
sub-phase 3·4 의 Rules 검증(R1~R12)은 `firebase-tools@14` + `@firebase/rules-unit-testing@4` 로 수행했으나, 하네스가 **세션 임시 폴더에만 존재**해 재현이 불가능하다.
편입 시 포함할 것: 시드(고객/점주 doc), R1~R12 케이스, `npm run test:rules` 스크립트, CI 연결 여부 판단.
주의: `firebase-tools@15` 부터 **JDK 21 이상**을 요구한다 (현재 로컬은 JDK 17 이라 14 로 고정해 실행했다).
</details>

### N3 — iOS 점주 `notDetermined` 배너 게이트 (O1)
`OwnerOrdersPage` 배너는 `status == denied` 일 때만 노출한다 (기존 동작). iOS 점주가 `나중에` 를 누른 뒤 OS 가 `notDetermined` 로 남으면 주문 접수 화면에 배너가 뜨지 않는다. sub-phase 4 spec 비범위(F23)로 두었으므로 결함은 아니나, 설정 화면과 동작이 어긋난다.

### ~~N4~~ — `auth_provider.dart` 레이어 정리 (O5) ✅ 완료 (2026-10-21)

`AuthRepository.currentUser` / `AuthRemoteDataSource.currentUser` 를 신설하고, `auth_provider.dart` 의 `firebase_auth` 직접 import 3곳(provider 주입 / `build()` 세션 확인 / `signOut()` uid fallback)을 전부 repository 경유로 바꿨다.
`AuthRemoteDataSourceImpl` 생성자의 `firebaseAuth` 를 optional 로 바꿔 기본값 `FirebaseAuth.instance` 를 data 레이어 안에서 해결하게 했다 (테스트 주입은 그대로 가능).
`authStateChanges` 와 중복이던 `User → UserModel` 변환을 `_toModel` 로 통합.

검증: `grep -rl "package:firebase_\|package:cloud_firestore" lib/presentation/ lib/domain/` → **0건**.

### N5 — APNs 키 등록 후 재검증 대기 항목
`docs/tasks/ios_apns_setup/spec.md` 완료가 선행 조건이다. 아래 항목들이 **환경 사유로 보류** 중이며 코드 결함 근거는 없다.

| 항목 | 출처 | 보류 사유 |
|---|---|---|
| T9 sticky 우회 | 3c-3 | Android 는 `notDetermined` 재현 불가(F-1), iOS 는 APNs 미등록으로 토큰 등록 검증 불가 |
| T13 점주 토글 반영 | 3c-3 | 점주 doc 에 `fcmToken` 이 없어 `onOrderCreated.ts:73` 토큰 가드에서 early return |
| T-B11 iOS 거부 후 미전환 | 3c-4 | iOS Simulator 권한 초기화에 앱 재설치 → 소셜 재로그인 필요 |
| F22 점주 배너 회귀 | 3c-4 | 점주 계정의 OS 권한이 허용 상태라 `denied` 조건 생성 불가 |

APNs 등록 후에는 **점주 기기에서 FCM 토큰이 발급**되므로 T13 과 F22 가 함께 풀린다.

### N6 — `notificationPermissionPrompted` 필드명 정리 (Q1 수용 사항)
sub-phase 4 에서 이 필드의 의미를 "다이얼로그 노출 이력" → "**OS 시트 소진**" 으로 바꿨으나 **이름은 그대로 두었다** (리네임 시 마이그레이션 필요). 이름과 뜻이 어긋나 있어 코드를 처음 읽는 사람이 오해할 수 있다. 다른 마이그레이션을 수행할 일이 생기면 `notificationOsPromptConsumed` 등으로 함께 정리하는 것을 권장한다.

---
