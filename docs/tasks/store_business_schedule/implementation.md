# store_business_schedule 구현 결과

- 작성: developer / 2026-11-02
- 기준: `spec.md` (§0 확정 + 설계 단계 Q1/Q5/Q7 우선), `design.md`
- 배포: **하지 않음** (사용자 수행). tester 미호출.

## 1. 구현 요약

| 영역 | 내용 |
|---|---|
| 데이터 모델 | `businessHours = {weeklyHours: {"1".."7": {open, close}}}` (1=월..7=일). 요일 키 부재 = 휴무, **빈 맵 = 전체 휴무(명시 저장)**, **필드 부재/해석 불가 = 시간 제한 없음(항상 영업)**. legacy `{openTime, closeTime, closedDays}` 는 읽을 때 7요일 동일 맵으로 흡수(Dart `BusinessHoursModel.tryParse` ↔ TS `parseWeeklyHours`, 교차 골든). legacy 가 빈 문자열/형식 오류면 null 취급(기존 매장이 막히지 않게). |
| 순수 판정 | `evaluateStoreOpenState` / `isStoreOpenNow` / `kstClockOf` — Dart `lib/core/utils/store_sellability.dart` ↔ TS `functions/src/storeSellability.ts`. `StoreOpenState{kind, nextOpenAt, closeAt, todayRange}` 포함. 자정 넘김(전일 구간 검사), closedDates 우선, 8일 탐색, `open==close`/파싱 실패 = 그 요일 닫힘. 시계는 호출자가 KST(요일·분·날짜키)로 주입. |
| 게이트 | `storeGateReason` 에 `scheduleClosedNow` 추가, 우선순위 **승인 > 임시휴업 > 스케줄**. `STORE_CLOSED_SCHEDULE` 신설(`failed-precondition`). `paymentGate.ts` G1 에서 서버 신뢰시계(`new Date()` → KST)로 판정(추가 Firestore 읽기 0). `evaluatePaymentGate(…, now)` / `verifyTossPayment deps.now` 주입점(테스트용). `migrateStoreApprovalMeta` 는 `scheduleClosedNow:false` 명시. |
| 클라 선검증 | `StoreSellabilityInput` 에 `businessHours`/`closedDates`, `ValidateCheckoutUseCase`(기기 시계 KST, `now` 주입 가능) → `StoreViolation.closedSchedule`. 읽기 실패 시 막지 않는 불변식 유지. |
| 결제 실패 / 카트 | `PaymentFailureReason.storeClosedSchedule` + copy("지금은 매장 영업시간이 아니에요"), `CartBannerVariant.storeClosedSchedule`(다음 영업 시각 포함, 매장 문서 못 읽으면 문장 생략), `_onCheckout` 스낵바. |
| 손님 UI | 헤더 `_StoreOpenStatus`(공용 상태로 교체, 자체 시간계산/“마감” 제거; 임시휴업 빨강 / 정기휴무·영업시간아님 중립 pill / `영업 중 · HH:mm까지`), 매장 메뉴 배너 `_ScheduleClosedBanner`, 메뉴 상세 담기 비활성(라벨 + “다음 영업 …” 줄, `_onAddPressed` 경쟁 방어), 홈 카드 배지 `StoreOpenBadge`(Q5). |
| 분 단위 갱신 | `minuteTickProvider`(autoDispose, 분 경계 타이머, `AppLifecycleListener.onResume` 재계산). 스케줄/휴무날짜가 있는 매장에서만 구독 → 미설정 매장은 타이머 0. 홈 카드는 목록 전체 타이머를 걸지 않고 빌드 시 1회 계산. |
| 점주 UI | 공용 `WeeklyScheduleEditor`(평일 묶음↔7행, 복사 바텀시트, 실시간 요약줄, 전체 휴무 경고, 미설정/`스케줄 사용 안 함`, 시작==종료 차단, 24시간 + `ColorScheme.light` 피커). `StoreOperationFormPage`: 섹션순서 영업스케줄→특정 날짜 휴무→임시휴업, closedDates 에디터 개선(요일 포함 라벨/오늘·지남 태그/삭제 터치 확대/지난 날짜 정리), 저장 흐름(검증→카테고리 전부OFF→전체휴무 경고·진행중 주문 안내[차단 아님, 0건이면 생략, 조회 실패는 숫자 없이 안내]→저장중 스피너/IgnorePointer/실패 시 입력 보존). |
| 신규 등록 필수 (Q7) | **`StoreCoreFormPage`(실제 등록 폼)** 신규 등록 시 `WeeklyScheduleEditor(required)` — 미설정/전체 휴무/시작==종료면 등록 버튼 비활성. 수정·재제출 모드는 표시하지 않음(운영 폼 담당). ※ `store_form_page.dart` 는 현재 **호출처가 없는 레거시**라(실제 등록은 `store_core_form_page`) 동일 에디터로 교체만 해 컴파일 유지. |
| 표기 교체 | `my_store_page`(미설정 “영업시간 제한 없음”), 관리자 승인 상세(“미설정”) → `formatWeeklySummary` 공용 포맷터. |

## 2. 생성 / 수정 파일

신규
- `lib/core/utils/store_schedule_format.dart` (요약/다음영업/종료 포맷, 순수)
- `lib/presentation/common/store_open_state.dart` (`storeOpenStateOf`, `minuteTickProvider`, `watchStoreOpenState`, `StoreClosedCopy`)
- `lib/presentation/owner/my_store/widgets/weekly_schedule_editor.dart`
- `test/core/store_schedule_format_test.dart`, `test/presentation/weekly_schedule_editor_test.dart`, `test/presentation/store_schedule_customer_ui_test.dart`

수정 (functions)
- `functions/src/storeSellability.ts`, `paymentGate.ts`, `verifyTossPayment.ts`, `migrateStoreApprovalMeta.ts`
- `functions/test/paymentAuthority.test.mjs`, `paymentGate.test.mjs`

수정 (Dart)
- core/domain/data: `store_sellability.dart`, `business_hours.dart`(+freezed 재생성), `business_hours_model.dart`, `store_model.dart`, `checkout_validation.dart`, `payment_failure.dart`, `validate_checkout_use_case.dart`, `checkout_validation_remote_data_source.dart`, `checkout_validation_repository_impl.dart`
- presentation: `store_menu_header.dart`, `store_menu_page.dart`, `menu_item_detail_page.dart`, `cart_page.dart`, `cart_line_availability.dart`, `cart_availability_banner.dart`, `payment_failure_copy.dart`, `store_card.dart`, `store_operation_form_page.dart`, `store_core_form_page.dart`, `store_form_page.dart`, `my_store_page.dart`, `admin_store_approval_detail_page.dart`
- 테스트/픽스처: `test_fixtures/store_sellability_contract.json`(기존 행 `scheduleClosedNow:false` 추가 + 신규 6행 + `openStateCases` 23 + `parseCases` 11), `test/core/payment_authority_contract_test.dart`, `test/domain/payment_failure_test.dart`, `test/domain/validate_checkout_use_case_test.dart`, `test/presentation/payment_authority_screens_test.dart`, `test_rules/rules.test.mjs`(BS1~3)
- 문서: `docs/processes/data_ownership.md` (businessHours 스키마 주석)

## 3. 결정 / 주의 (spec 대비)

1. **`closedDates` 는 스케줄 미설정이어도 적용**한다(design §2.4 권고). `weeklyHours == null` + 오늘이 closedDates → 닫힘. (Q1 “미설정=항상영업”의 유일한 예외 — 점주가 명시 지정한 날짜이므로.)
2. **오늘이 closedDate 면 전일 자정 넘김 구간도 닫힘**, 반대로 전일(시작일)이 closedDate 면 그 자정 넘김 세션은 없음. 골든에 고정.
3. `storeGateReason` 의 `scheduleClosedNow` 는 필수 인자. `canSellNow` 만 `scheduleClosedNow` 기본 false(승인 전용 판정용 — migrate 이상치).
4. 홈 카드 임시휴업도 배지로 노출(design §3.8 일관성). 영업 중(스케줄 있는 매장)은 success 배지.
5. Rules 변경 **없음**. 회귀 보증용으로 `BS1~3` 3케이스만 추가(스키마 맵 update 허용, status 동시 변경은 여전히 거부).
6. `lib/dev/seed/phase1_seed_data.dart` 의 시드는 과거 `openHour/…` 구조라 신 파서에서 “미설정(null)”로 해석된다(영향 없음, 수정 안 함).

## 4. 검증 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | **No issues found** (0) |
| `flutter test` | **1066 전체 통과** (신규: 교차 골든 Dart 하네스[openState 23 + parse 11 + gate 6], 포맷터, 선검증 스케줄 5, 에디터 위젯 5, 손님 UI 7 등) |
| functions `npm test` (= `tsc` 빌드 + 9개 파일) | **518 pass / 0 fail** (신규: storeSellability 골든 openState 23 + parse 11 + gate 행, `G1 스케줄` 13 케이스[서버 KST 고정시각, confirm 미호출·거절 1건·우선순위·legacy·closedDates·미설정]) |
| `test_rules` (에뮬레이터) | **482/482 PASS** (기존 479 + BS1~3) |

## 5. tester 테스트 포인트

1. 교차 골든: Dart/TS 가 같은 `store_sellability_contract.json` 을 읽는지(gate 우선순위, `openStateCases`, `parseCases`). 두 구현의 `evaluateStoreOpenState` 동치(자정 넘김 02:00, closedDate, 전체휴무, 월말 경계, 8일 초과 null).
2. **Q1 회귀**: `businessHours` 필드 없는 매장 / 시드 구조(`openHour…`) / legacy 빈 문자열 → 주문·결제 통과, 헤더 표시 없음.
3. 서버: `PAYMENT_GATE_MODE=enforce`, 영업시간 밖·휴무일·전체휴무·closedDate → `STORE_CLOSED_SCHEDULE`, `paymentGateRejections` 1건, Toss confirm 0회. 임시휴업 > 스케줄, 미승인 > 스케줄. shadow 는 기록만.
4. 점주 폼: 평일 묶음 편집, 요일별 펼치기/접기(다르면 확인), 복사 시트, 토·일 개별, 요약줄 실시간, 전체 휴무 경고(인라인 + 저장 다이얼로그), 시작==종료 저장 차단(스낵바+스크롤), 24시간 피커(밝은 테마), `스케줄 사용 안 함` → null, 지금부터 닫히는 저장 시 진행중 주문 n>0 안내 / 0건 생략 / 조회 실패 안내, 저장중 스피너+입력 잠금, 실패 시 입력 보존.
5. 신규 등록(`StoreCoreFormPage`): 스케줄 미입력/전체휴무/시작==종료면 등록 버튼 비활성, 정상 입력 시 `businessHours.weeklyHours` 가 매장 문서에 저장(create Rules 통과 확인 포함).
6. 손님: 헤더 pill 3종, 메뉴 배너 3문구, 메뉴 상세 비활성 라벨/다음 영업 줄, 영업 시작 시각 도달 시 자동 활성(분 틱), 앱 resume 재계산, 카트 배너·스낵바·결제 실패 화면, 홈 카드 배지.
7. 기기 시계 드리프트: 표시만 어긋나고 서버가 최종 판정함을 확인.

## 6. 미구현 / 보류

- 공휴일 자동 휴무, 매장별 TZ, 영업 스케줄 변경 이력(audit A2) — spec 비범위.
- 홈 카드 배지는 분 단위 자동 갱신 없음(진입/재빌드 시 계산) — 목록 전체 타이머 회피(design §3.8). 필요하면 후속.
- `store_form_page.dart`(미사용 레거시)는 삭제하지 않고 에디터만 교체. 삭제 여부는 별도 결정.
- 실제 기기 시각 피커/바텀시트 시각 검수(스크린샷)는 수행하지 않음(위젯 테스트까지).

## 7. 배포 순서 (사용자 수행)

1. **functions 먼저**: `storeSellability.ts` / `paymentGate.ts` / `verifyTossPayment.ts` / `migrateStoreApprovalMeta.ts` 재배포. 이 시점엔 모든 기존 매장이 `businessHours` 미설정 또는 legacy 라 영향 없음(Q1). `PAYMENT_GATE_MODE` 가 `enforce` 여야 서버 거절이 실제로 걸림(operations.md). 필요 시 `shadow` 로 먼저 기록만 확인.
2. **앱 빌드 배포**: 요일별 피커·표시·선검증. (구 앱은 서버 사유 `STORE_CLOSED_SCHEDULE` 를 모르는 토큰으로 처리 → 갈래 C(알 수 없는 실패) 문구. 스케줄 설정은 신 앱이 나간 뒤에 시작할 것.)
3. Rules 배포 **불필요**. 백필 CF **불필요**(lazy 흡수).

## 8. 마이그레이션 메모 (기존 테스트 매장 후보정)

- 기존 매장은 `businessHours` 가 없거나 legacy 단일구간이다. legacy 는 읽을 때 7요일 동일(closedDays 제외)로 해석되어 **게이트 결과가 즉시 적용**된다 — legacy `openTime/closeTime` 이 유효한 매장은 배포 직후부터 그 시간 밖 주문이 차단된다. 의도치 않은 차단을 피하려면 배포 전에 legacy 값이 있는 테스트 매장을 확인할 것 (`stores` 에서 `businessHours.openTime` 존재 여부 조회).
- 후보정: 점주가 운영 정보 폼에서 스케줄을 저장하면 신 스키마(`weeklyHours`)로 영속된다. 24시간 테스트 매장은 `스케줄 사용 안 함`(null) 유지 또는 00:00~23:59 설정.
- 시드(`phase1_seed_data.dart`) 매장은 `openHour…` 구조라 미설정으로 해석 — 변경 불필요.
