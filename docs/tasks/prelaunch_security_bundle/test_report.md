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

## prod 배포 후 검증 (2026-10-31, 오케스트레이터 adb E2E)
> 사용자가 secret(SIGNAL_HASH_SALT) → rules → functions(verifyTossPayment/onOrderQoinSettled/verifyNaverToken) → 앱 재빌드까지 배포 완료 후 실기기(emulator-5554) 자동화로 검증.
- **정상주문 해피패스 (회귀 ②) PASS** — 일반 고객이 강남점 아메리카노 주문 → 토스 테스트결제(퀵계좌이체·000000) → `결제 완료`, 주문 `4eaebd3a-7df…` 생성. **배포된 verifyTossPayment 의 자기거래 가드가 정상주문을 막지 않음**(가드 통과 → Toss confirm → 주문 커밋). orderSignals best-effort write 가 주문 흐름을 깨지 않음(주문 성공).
- **주문상세 썸네일 (imageUrl 회귀) PASS** — 주문 상세에 Q-로고 썸네일 표시, 금액 전 구간 4,500원 일관.
- Rules 하네스 **463/463 PASS** (아래 stale 테스트 1건 교정 후 전건 green).
- **stale 테스트 교정**: `test_rules/rules.test.mjs` PPA-3g 를 `allow`→`deny` 로 수정. 이전 세션 `b87b548`(brand_self_approve_guard V2)가 브랜드 자가승인(menuOverrides status→approved + 승인메타)을 차단하면서 기대값을 뒤집지 않아 실패해 있었다(보안묶음과 무관, menuOverrides 미변경 확인). rules 의도(브랜드는 제출만·승인은 admin 전담)가 맞고 테스트가 틀렸다.

## 사용자 확인 필요 (배포 후, 자격증명/콘솔/계정 의존 — 오케스트레이터 불가)
- **자기거래 차단(핵심 half) 미검증** — 점주/브랜드 계정으로 자기 매장 주문 → 거절 + `paymentGateRejections.reason='SELF_DEALING'` 기록. owner/brand 테스트 계정 자격증명 필요.
- **orderSignals 문서 내용 미검증** — `orderSignals/{4eaebd3a…}` 가 64hex 해시·마스킹형이고 점주/고객 read 불가인지. prod Firestore/콘솔 read 필요.
- **SL-1 이름 표시 미검증** — 현재 로그인 세션이 SL-1 배포 이전 계정이라 홈 인사말이 `Qrator`(폴백). 새로 소셜 로그인(naver/kakao)해야 실명 표시 확인됨. 사용자 자격증명 필요.

## 미구현/후속
- Layer2 탐지·플래그·admin UI(의도적 비범위).
- `docs/processes/{data_ownership,entity_lifecycle}.md` 갱신(orderSignals 추가, §2.6 해소) — architect 후속.
- iOS `pod install`(firebase_app_installations 플러그인 추가분).
