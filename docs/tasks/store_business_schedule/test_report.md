# store_business_schedule 테스트 리포트

- 검증: tester / 2026-11-02, 대상 커밋 `eb1dac0`
- 기준: spec.md (§0 + Q1/Q5/Q7 추가확정), design.md, implementation.md, CLAUDE.md, architecture.md
- 코드 수정·배포 없음. git 조작은 baseline 대조용 detached checkout 1회 후 `main` 복귀 (working tree 변동 없음).

## 1. 결과 요약

**FAIL 0 / PASS 8개 불변식 전부 / 보류 6**

## 2. 독립 재실행

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 1066 전체 통과 |
| `functions` `npm test` (tsc + 9 파일) | 518 pass / 0 fail |
| `test_rules` 하네스 | 482 PASS / 0 FAIL (BS1~3 포함) |
| `functions` `npm run test:emulator` | 113 PASS / 3 FAIL (CH16, Q1, CF7) |

### 에뮬레이터 3 FAIL = 이 기능과 무관
`eb1dac0~1` detached 에서 동일 조건 재실행 결과 **113 PASS / 3 FAIL, 실패 항목·메시지 동일**
- CH16: `earn 문서 read expected 5 got 6`
- Q1: `켜진 매장은 새 브랜드 값`
- CF7: `쓰기 0 — 문서 지문 동일`

모두 qoin / 브랜드 영역이고 baseline 에서도 그대로 실패한다. 이 기능이 새로 만든 실패는 없다.
(참고: Q1 이름 충돌 주의 — 에뮬레이터의 "Q1"은 Qoin 일괄 덮어쓰기 테스트이고, 이 기능 spec 의 Q1(미설정=항상 영업)과는 다른 것이다.)
복귀 후 `HEAD=eb1dac0`, untracked(`.firebase/`, `.firebaserc`, `docs/tasks/rebrand/`)는 시작 전과 동일.

## 3. 불변식별 결과

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | Q1 기존 매장 안 막힘 | PASS | `parseWeeklyHours`(TS)/`BusinessHoursModel.tryParse`(Dart): 필드 null·부재·비객체·알 수 없는 구조 → null(=무제한). 빈 맵만 전체휴무. legacy 유효 `{openTime,closeTime}` → 7요일 동일맵(closedDays 제외) 흡수. 빈 문자열(`""`)·형식오류(`9:00`) legacy → null(안 막힘). 골든 parseCases 11건에 위 케이스 모두 고정. 시드(`openHour…`)는 openTime/closeTime/weeklyHours 모두 없어 null. 서버 `G1 스케줄: 미설정` 통과 + confirm 호출 확인. |
| 2 | closedDates 예외 | PASS | 스케줄 null + 오늘 closedDate → `regularHoliday`(골든 "미설정(null) + 오늘 closedDate = 휴무"), 서버 G1 케이스 "closedDates 일치 + 스케줄 미설정 → 닫힘" 존재. |
| 3 | 교차 골든 | PASS | `store_sellability_contract.json` (gate 22행 / openState 23 / parse 11)을 Dart(`test/core/payment_authority_contract_test.dart`, `File('test_fixtures/…')`)와 TS(`functions/test/paymentAuthority.test.mjs`, `../../test_fixtures`)가 같은 파일로 읽는다. 한쪽 구현만 바뀌면 해당 하네스가 깨지는 구조. 두 파서의 로직을 대조해 가공 규칙(키 `^[1-7]$`, open/close 문자열, legacy HH:mm 검증, closedDays 숫자만)이 동일함도 확인. |
| 4 | 서버 게이트 | PASS | `paymentGate.ts` G1 에서 `kstClockOf(now)` 로 판정(`now` 기본 `new Date()`, 서버 시계). 매장 문서 1회 read 를 재사용해 **추가 read 0** (diff 에 신규 reader 호출 없음). 우선순위는 `storeGateReason` 한 곳: 승인 > 임시휴업 > 스케줄 (골든 + 서버 케이스 "임시휴업 > 스케줄", "승인 > 스케줄"). `verifyTossPayment deps.now`·`evaluatePaymentGate(…, now)` 주입 테스트 13건, 거절 시 `paymentGateRejections` 1건·Toss confirm 0회 검증. |
| 5 | 순수 판정 | PASS | 자정넘김(전일 구간 검사, 02:00 종료·closedDate 처리), nextOpenAt/closeAt, 8일 탐색(`off<=8`)·null, todayRange(`익일` 표기), 월말 경계 모두 골든 23건에 고정, 통과. UI 는 `storeOpenStateOf`→`evaluateStoreOpenStateAt` 단일 모듈 사용. 이전 `_OpenStatusText`/"마감" 문자열은 `lib` 전체에서 grep 0건. |
| 6 | 회귀 0 | PASS | 전체 스위트(flutter 1066 / functions 518 / rules 482) 통과, 에뮬레이터 결과 baseline 과 동일. Q2: `hasInvalidRow`(open==close)가 운영 폼 `_submit` 저장 차단 + 스크롤, 등록 폼 버튼 비활성에 모두 연결. Q3 일괄 저장 단일 `_submit`. Q6 섹션 순서: 영업스케줄 → 특정 날짜 휴무 → 임시휴업 → 카테고리 (build 순서 확인). |
| 7 | 손님 UI | PASS (실기기 보류) | 헤더 `_StoreOpenStatus`가 임시휴업(빨강) > 정기휴무·영업시간아님(중립) > 영업중 `HH:mm까지`. 메뉴 상세 담기 비활성(`StoreClosedCopy.buttonLabel` + 다음 영업 줄, `_onAddPressed` 방어). 카트 `CartBannerVariant.storeClosedSchedule`, 결제실패 copy `storeClosedSchedule` 분기 존재(switch 누락 없음, analyze 0). 홈 `StoreOpenBadge`. `store_schedule_customer_ui_test` 7건 통과. |
| 8 | 점주/등록 | PASS | `WeeklyScheduleEditor`(평일묶음↔7행·복사·전체휴무 경고·사용 안 함) 위젯 테스트 5건 통과. 저장 흐름: 검증 → 카테고리 → 전체휴무 경고 → 진행 주문 안내(`activeCount` 0건이면 생략, 조회 실패는 숫자 없이 안내, 차단 아님). **StoreCoreFormPage**: `_scheduleOk = _isEdit \|\| (null 아님 && 비어있지 않음 && !hasInvalidRow)` 가 `_isValid`에 포함 → 미설정/전체휴무/시작==종료면 등록 버튼 비활성, 수정·재제출은 에디터 미노출·기존 값 보존(`e==null ? _hours : e.businessHours`). |

## 4. 규칙 준수

- Clean Architecture: `lib/presentation|domain|core` 에서 `cloud_firestore`/`firebase_*` import 0건. `store_sellability.dart` 등 core 순수 모듈은 외부 SDK 의존 없음. PASS
- AppColors: 이번 커밋 diff 의 `Color(0x` 신규 추가 0건. PASS
- 시크릿 하드코딩 없음. PASS
- **Rules 무변경 타당**: `firestore.rules` 의 stores owner update 화이트리스트(L392~394, 430~432)에 `businessHours`·`closedDates`·`temporaryClosed`가 이미 포함됨. 권한 판정 입력이 아니므로 추가 차단 불필요. 회귀 BS1(허용)·BS2(전체휴무 허용)·BS3(status 동시 변경 거부) 통과. PASS
- 엔티티 lifecycle: 이 기능은 status 전이를 추가하지 않음(게이트 입력만). `storeGateReason` 승인 조건 불변. PASS

## 5. 보류 (FAIL 아님, 타당성 확인)

1. **배포 전 마이그레이션 경고(implementation §8)는 정확하다.** `parseWeeklyHours`/`tryParse`가 legacy 유효값을 즉시 7요일 맵으로 흡수하므로 legacy `openTime/closeTime` 이 유효한 매장은 배포 직후 그 시간 밖 주문이 서버(`enforce`)에서 `STORE_CLOSED_SCHEDULE` 로 거절된다. 의도된 lazy 흡수이지만 **배포 전 `stores` 에서 `businessHours.openTime` 보유 매장을 조회해 후보정 필요**. 서버 게이트가 `shadow` 면 기록만 된다. (우선 조치)
2. 공휴일 자동 휴무 / 매장별 TZ / 스케줄 변경 이력(audit A2): spec 비범위, 타당.
3. 홈 카드 배지 분 단위 자동 갱신 없음(진입·재빌드 시 계산): 의도된 비용 회피. 영업 시작 직후 홈에서 배지가 잠시 stale 할 수 있음 — 후속 후보.
4. 레거시 `store_form_page.dart` 호출처 0건인데 미삭제(에디터만 교체). 삭제 여부 별도 결정 권고.
5. 실기기 확인 필요: 시각 피커/바텀시트 시각 검수, 분 틱·resume 재계산, 기기 시계 드리프트(서버가 최종 판정이므로 표시만 어긋남). 위젯 테스트까지만 확인됨.
6. 구 앱 빌드는 `STORE_CLOSED_SCHEDULE` 를 모르는 토큰으로 처리(알 수 없는 실패 문구). 앱 배포 후에 스케줄 설정을 시작하도록 §7 순서 준수 필요.

## 6. 우선 조치

FAIL 없음. 가장 먼저 할 일은 보류 1번(배포 전 legacy `businessHours` 보유 테스트 매장 확인·후보정).
