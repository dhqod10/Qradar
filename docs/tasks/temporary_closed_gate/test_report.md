# temporary_closed_gate 테스트 리포트

기준: spec / design / implementation (사용자 확정 C안 + 디자이너 기본안). 검증 범위: 코드·정적·단위. 실기기는 보류.

## 결과 요약
PASS 7 / FAIL 0 / 보류 1 (실기기) / 경미 지적 2

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 판정 단일화 | PASS | Dart/TS `storeGateReason` 동일 규칙 (승인실패→NOT_SELLABLE, 휴업 무시 / 휴업→TEMPORARILY_CLOSED / null). `canSellNow` = reason==null 파생. 잔여 호출부(migrateStoreApprovalMeta)는 `temporaryClosed:false` 로 기존 거동 불변. 미승인/미지값 거동 불변 |
| 2 | 교차 골든 | PASS | 기존 11행 expect 불변 (+temporaryClosed:false/expectReason), 신규 5행. Dart(`payment_authority_contract_test`)·TS(`paymentAuthority.test.mjs`) 하네스 모두 expectReason+expect 단언. paymentGate G1 휴업 3행 통과 |
| 3 | 서버 | PASS | `paymentGate.ts` GateReason/HTTPS_CODE(failed-precondition)/GATE_TEXT 추가, `storeGateReason` 단일 호출, 거절 로깅은 기존 경로. NOT_SELLABLE 과 구분 |
| 4 | 클라 | PASS | 헤더 pill(error/onPrimary)+배너(AppColors), 상세 _BottomAction 우선순위 휴업>품절>busy>required (+선택중 경쟁 방어), 카트 variant+스낵바, 결제실패 전용 copy (storeNotSellable 문구 불변), `StoreViolation.temporarilyClosed` |
| 5 | 점주 가드 | PASS | `CountActiveStoreOrdersUseCase` -> `storeId ==` + `status whereIn`(paid/accepted/making/ready) 1회 조회, orderBy 없음 (신규 인덱스/Rules 불필요). false→true 일 때만 조회, ≥1건 롤백+확인 다이얼로그, 조회실패→저장+스낵바. 라벨 "임시 휴업" |
| 6 | 레이어/품질 | PASS | presentation/domain Firebase import 없음, `Color(0x` 없음, rules/indexes 무변경. my_store_closing_guide 테스트는 "문구가 임시를 권하지 않음"을 보며 closingGuideMessage 동작 불변 -> 여전히 유효 (통과) |
| 7 | 정적/테스트 | PASS | `flutter analyze` 이슈 0, `flutter test` 927 통과, `functions npm test` 349 통과. diff 는 spec 지점+테스트/골든뿐, 재포맷 노이즈 없음 (29 files, +398/-48) |
| 8 | 실기기 | 보류 | 휴업 토글 -> 손님 담기 차단 -> 결제 거절 / 점주 활성주문 차단: 나중 배치 실테스트 |

## 경미 지적 (FAIL 아님, 우선순위 낮음)
1. `store_menu_page.dart` ~L426: 기존 doc 주석 "검색에서 넘어온 메뉴 안내 띠…" 가 새 `_TemporaryClosedBanner` 클래스 바로 위로 밀려 붙음 (원래 대상 클래스와 분리). 주석 위치 교정 권장.
2. `test/presentation/my_store_closing_guide_test.dart` L14 헤더 주석이 "temporaryClosed 는 주문을 막지 못한다 — spec §6.8" 로 stale (테스트 동작은 유효). 주석만 갱신 권장.

## 배포 전제 (사용자 몫, 미배포)
PAYMENT_GATE_MODE=enforce 이미 enforce. functions 재배포 + 앱 재빌드 필요. 구 앱은 STORE_TEMPORARILY_CLOSED 를 모르는 토큰으로 보고 갈래 C 로 폴백.

## 우선 수정 FAIL
없음.

## 후속 후보
- 위 경미 지적 2건 주석 정리
- 실기기 배치 테스트 (보류 #8)
- 점주 가드는 TOCTOU 수용 (서버 게이트가 백스톱) — 추가 조치 불필요
