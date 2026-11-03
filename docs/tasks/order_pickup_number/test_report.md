# order_pickup_number — 테스트 리포트

기준: spec.md / design.md / implementation.md + 실제 코드 대조. 배포 없음.

## 자동 검증
| 항목 | 결과 |
|---|---|
| functions `npm test` | 557 pass / 0 fail (pickupNumber 포함) |
| functions `tsc --noEmit` | 통과 |
| test_rules `npm test` | 508/508 PASS (PK-1~13 포함) |
| `flutter analyze` | No issues |
| `flutter test` | 전체 통과 (pickup_number_display_test 포함) |

## 항목별 결과
| # | 항목 | 결과 |
|---|---|---|
| 1 | 발급 원자성: 최종 쓰기 runTransaction. 순서 = orders 재확인(read) → 카운터 read → set 3건. 읽기 선행 OK | PASS |
| 1b | 이미 주문 있으면 `{duplicate}` 반환, 재발급·Toss 취소 없음, 기존 status 반환 | PASS |
| 1c | 커밋 전 실패 시 abort → 카운터 불변 (오펀 테스트 존재). Toss confirm/Qoin 예약/Layer2 위치 불변 (Layer2 는 커밋 후) | PASS |
| 2 | 카운터 경로 `stores/{storeId}/pickupCounters/{KST yyyyMMdd}`, approvedAt 기준, 매장 독립, 자정 리셋, 12건 경합 중복 없음 (fake 낙관적 동시성) | PASS |
| 3 | 결제 회귀: 557 테스트 통과. 4개 fake db 수정 타당 — qoinSpend txCount 는 orders/ 를 읽는 트랜잭션을 제외하고 Qoin 원장만 집계, priceAuthority 금액 루프는 pickupCounters 문서만 제외 | PASS |
| 4 | Dart: `int? pickupNumber`, 모델은 fromFirestore 읽기만(toFirestore 미기록), 위젯 hero/badge/inline, 표시 5곳(결제완료, 고객상세, 점주 타일 3종, 점주상세, OrderCard) 적용 확인, "주문 ID" 격하 | PASS |
| 5 | Rules: pickupCounters `read, write: if false`(admin 포함), orders 규칙 불변, PK-1~13 타당 | PASS |
| 6 | 문서 갱신 (data_ownership §2.2/2.4/2.5a/3, audit_trail, entity_lifecycle) 반영 확인 | PASS |
| 7 | 절대규칙: presentation/domain 에 Firebase import 없음 (data 모델만), 색상 AppColors 만 (PickupNumberDisplay 포함), secret 없음 | PASS |
| 8 | 범위 밖 | 보류 (아래) |

PASS 7 / FAIL 0 / 보류 1(+아래 후속 3).

## 범위 밖 기존 문제 타당성 (수정 요구 아님)
- Qoin 미사용 결제 confirm 후 저장 실패 시 Toss 자동취소 없음: 사실. undoQoinReservation 은 예약이 있을 때만 동작하며 batch 시절부터 동일. 보류 기재 적정. 다만 트랜잭션은 batch 보다 abort 가능성(경합 재시도 소진)이 약간 높아 이 구멍의 중요도가 소폭 상승 — 후속 과제 권장.
- OrderLogModel `total`/`paidAt` vs 서버 `totalPrice`/`createdAt` 불일치: 사실, 현재 화면 소비처 없어 영향 없음 (이번 pickupNumber 매핑은 정상).

## 주의 / 보류 사항
1. 보류(범위 오염): 작업 트리에 signup_profile_fields 변경이 공존한다. 특히 `firestore.rules` 의 `phone` 허용 추가, `auth_*`, `user_*`, `email_signup_page`. 이는 이번 기능 변경이 아니며 이 기능이 건드린 것은 아님(커밋 시 분리 필요).
2. 후속: `functions/test/emulator.test.mjs` 는 실제 에뮬레이터 트랜잭션 경합 미실행 (fake 만 검증). 배포 전 `npm run test:emulator` 1회 권장 (batch 가정 없음은 grep 으로 확인, 결제 경로 직접 호출 없음).
3. 후속: 동시 중복 호출 시 tx 내 duplicate 분기에서 `reservation = null` 처리. Qoin 예약이 idempotencyKey 로 멱등이라면 문제 없으나, 실환경 동시 재시도 시나리오는 에뮬레이터에서 확인 권장.
4. 후속: 결제완료 hero 는 currentOrderProvider 스트림 로딩 중 스켈레톤 — 실기기 체감 확인 필요.

## 우선순위
FAIL 없음. 최우선 후속: (1) 커밋 시 signup_profile_fields 분리, (2) 에뮬레이터 결제 E2E 1회.
