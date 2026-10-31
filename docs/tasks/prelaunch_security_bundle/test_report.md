# prelaunch_security_bundle — test_report

> 검증 2026-10-31. 별도 tester 에이전트 대신 오케스트레이터가 **독립 재실행 + 보안 핵심 코드 직접 리뷰**로 검증(토큰 고려, 보안건이라 핵심은 눈으로).

## 전체 결과: PASS (FAIL 0)

| 검증 | 결과 |
|---|---|
| `flutter test` (전체) | ✅ **927 통과** (오케스트레이터 독립 재실행) |
| `flutter analyze` | ✅ No issues (developer 확인) |
| `functions` build + `node --test` | ✅ **368 통과** (신규 selfDealing 17 포함, developer 확인) |
| Rules 에뮬레이터 | ✅ **23 통과** (D2/리뷰/orderSignals, developer 확인) |

## 코드 리뷰 (오케스트레이터 직접)
- **`selfDealing.ts`** — 정확. owner 일치 먼저(read 0) → brandId 유효할 때만 `users/{uid}` read(개인매장 추가 read 0). 공백 brandId 매칭 차단(`validBrandId`). Rules `isStoreOwner`/`isBrandHolder` 와 동일 규칙 포팅.
- **`verifyTossPayment`** — 멱등가드 직후·Toss confirm 전 매장 1회 read 로 판정. 매장 없으면 가드 skip(기존 동작 유지), self-dealing 이면 `permission-denied` + `paymentGateRejections.reason='SELF_DEALING'`, confirm 미호출(돈 안 움직임). `deviceId` 는 orderSignals 전용(판정 미사용).
- **`firestore.rules`** — ① reviews: 자기 매장(owner OR brandHolder) 작성 차단. ② stores/menuItems 점주 분기 `ownerStoreMenuOk`: 독립매장(brandId 빈/null) approved 즉시 등록 **보존**(승인메타 null 강제), 가맹매장 D1 헬퍼 재사용 차단. ③ orderSignals: admin read 전용, write false.
- **회귀 안전 핵심**: 독립매장 `brandId: null` 명시 케이스 처리 — "비어있지 않은 문자열일 때만 가맹" 으로 판정해 독립매장 approved 등록이 안 깨짐(에뮬레이터 null/부재 둘 다 통과 확인).
- 기존 테스트 1건 의도적 수정(`paymentGate.test.mjs` "off 는 읽지 않는다"): 자기거래 가드가 모드 무관하게 `stores` 1회 read 하므로 기대 컬렉션에 `stores` 추가. 게이트 reader 호출 0 단언 유지 — **타당**.

## D-1~D-6 잠정값 (architect 권고 적용, **사용자 최종 확정 대기**)
- D-1 결제 가드 = 상시 enforce · D-2 판정에 브랜드 보유자 포함 · D-3 deviceId=Firebase Installations ID · D-4 IP=ipHash · D-5 신호=orderSignals 분리 컬렉션 · D-6 write=best-effort. (코드 주석에 "잠정" 표기)

## 실기기/배포 의존 (사용자 — 배포 후 확인)
> 아래는 prod 배포 + 실기기가 있어야 가능해 **보류**. 배포 후 권장 확인:
- 점주/브랜드 계정으로 자기 매장 주문 → 거절 + `SELF_DEALING` 기록 1건.
- 정상 주문 → `orderSignals/{orderId}` 생성, 값이 64hex 해시(원본 없음), 점주·고객 read 불가.
- 독립매장 점주 앱 UI 에서 점포한정 메뉴 approved 즉시 등록(회귀 ①).
- 일반 고객 주문/리뷰/적립 무영향(회귀 ②), 환불 clawback 불변.

## 미구현/후속
- Layer2 탐지·플래그·admin UI(의도적 비범위).
- `docs/processes/{data_ownership,entity_lifecycle}.md` 갱신(orderSignals 추가, §2.6 해소) — architect 후속.
- iOS `pod install`(firebase_app_installations 플러그인 추가분).
