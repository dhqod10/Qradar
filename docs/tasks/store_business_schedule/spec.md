# store_business_schedule 기능 명세

매장 영업 스케줄 — 요일별 영업시간 + 정기(반복) 휴무일을 "시간/스케줄 기반 매장 가용성" 한 feature 로 묶어 설계한다.

- 작성: architect
- 작성일: 2026-11-02
- 상태: **설계 초안 — §0 사용자 확인 대기.** 확정 전 하위 에이전트(designer/developer/tester) 미착수.
- backlog: `docs/backlog.md` "⬜ 매장 영업 스케줄 (영업시간 + 정기 휴업)" (L890~)

---

## 0. 사용자 확인이 필요한 결정사항 (권고안 + 대안) — 착수 전 반드시 합의

> 이 feature 는 기존 `temporary_closed_gate` 가 의도적으로 **비범위로 남긴 작업**이다(그 spec §비범위: "`businessHours` 기반 영업/마감 자동 판정 — 손대지 않는다. `_OpenStatusText` 는 표시 전용"). 즉 지금 `businessHours` 는 **손님 화면에 "영업 중/마감" 글자만 그릴 뿐 주문을 막지 않는다.** 이 feature 가 그 표시를 **실제 판매 게이트**로 승격한다. 아래 6개가 그 승격의 성격·범위를 가르는 결정이다.

> ✅ **전부 확정 (2026-11-02, 사용자 승인).**
> - **D0-1 = A안(요일별 맵 `weeklyHours`)** — "토요일 단축근무"처럼 요일마다 다른 시간을 표현해야 하므로 단일구간(B) 미달. 요일 엔트리 부재=그날 휴무.
> - **D0-2 / D0-4 / D0-5 = 권고안대로** (서버 게이트 parity 3단 / 서버 1코드+클라 표시 세분·우선순위 승인>임시휴업>스케줄 / 특정 날짜 포함·공휴일 자동은 후속).
> - **D0-3 = KST 고정, 서버 시계 권위** (국내 전용 가정 확정).
> - **D0-6 = 권고안대로** — 스케줄을 휴무로 저장해도 **진행 중 주문은 자동취소하지 않고 끝까지 진행**, 새 주문만 차단, 저장은 허용(활성주문 가드 없음).
> **designer 전달 UX**: 모델은 요일별이되, 설정 화면에 **"평일(월~금) 일괄 적용"** 등 편의를 제공해 5일을 개별 입력하지 않게 한다(토/일만 따로 조정).

### D0-1. `businessHours` 데이터 모델 — 요일별 시간으로 확장할 것인가 (권고: **예, 요일별 맵**)

**현황(코드 확인):** `BusinessHours` 는 **모든 요일 공통 단일 구간** `{openTime, closeTime}` + `closedDays: List<int>`(요일 휴무, 주석상 "향후 확장 대비"로 **현재 항상 빈 리스트**)다. 즉 "요일별 다른 영업시간"을 지금 모델로는 표현할 수 없다.

| 안 | 내용 | 판정 |
|---|---|---|
| **A (권고)** | `businessHours` 를 **요일별 맵** `weeklyHours: Map<int(1=월..7=일), {open,close}?>` 로 확장. 요일 엔트리 **부재/null = 그날 휴무**. → 요구 (a) 요일별 영업시간 **과** (b) 정기 휴무를 **한 필드**로 표현(월요일 휴무 = 월요일 엔트리 없음). | ✅ 요구사항 (a)"요일별"을 정확히 충족. 휴무를 별도 리스트로 중복 관리할 필요 없음. 단 **모델 변경 + 기존 단일구간 데이터 마이그레이션 + 점주 UI(7행 피커) + `_OpenStatusText` 재작성** 수반 |
| B | 현행 단일 구간 유지 + `closedDays: List<int>`(요일 휴무)만 **활성화**(현재 미사용 필드를 게이트에 연결). | △ 변경 최소(필드 이미 존재, 마이그레이션 불필요). 그러나 **모든 영업일이 같은 시간** — "요일별 다른 시간"(요구 a)을 **충족 못 함**. (b) 정기휴무만 충족 |
| C | 하이브리드: 단일 구간 기본값 + 요일별 **예외** 오버라이드(다른 날과 다른 요일만 맵에 넣음). | △ 유연하나 모델·UI 복잡도 B·A 중간. 대부분 매장이 요일별로 다르지 않다는 가정이면 과설계 |

**권고 A.** 요구사항이 명시적으로 "요일별 영업시간"이므로 단일구간(B)은 요구 미달이다. 마이그레이션·UI 비용은 있으나 이 feature 의 본질이다. **휴무를 요일 엔트리 부재로 통합**하면 "휴무일=영업시간의 그날 아예 닫음 케이스"(backlog 문구)와 모델이 1:1 로 맞는다. → **단, 기존 `closedDays`/`closedDates` 와의 관계는 D0-5 에서 함께 확정.**

**확인 요청:** A/B/C 중 선택. A 면 기존 단일구간 매장(실측 건수 developer 확인) 마이그레이션 방식(점주 재입력 vs 7요일 동일값 백필)도 함께.

### D0-2. 서버 집행(권위) 깊이 — 결제 게이트까지 막을 것인가 (권고: **예, temporaryClosed 와 동일 parity**)

| 안 | 내용 | 판정 |
|---|---|---|
| **A (권고)** | **표시 + 클라 선검증 + 서버 게이트** 3단. `temporaryClosed` 와 완전 동일 결. 서버 `paymentGate` G1 이 "지금 영업시간 밖/정기휴무"면 **Toss confirm 직전 거절**(돈 이동 전). 신규 거절 사유코드 신설(D0-4). | ✅ 클라 우회 방어(조작된 기기 시계·구앱). `temporaryClosed`·품절·자기거래 가드와 같은 백스톱 일관성 |
| B | 표시 + 클라 선검증만(서버 게이트 없음). | ❌ 기기 시계를 조작하면 영업시간 밖에도 결제 통과. 돈 게이트의 신뢰원을 클라로 둠 — 기존 보안 설계(payment_server_authority)와 모순 |
| C | 표시만(주문 차단 없음). | ❌ 요구사항 "주문이 차단된다" 미충족 |

**권고 A.** 단, 서버 게이트가 **시간**에 의존하는 것이 `temporaryClosed`(정적 bool)와의 결정적 차이다 → D0-3(TZ)·§레이어 D1(시간 주입 설계)에서 그 신뢰성을 확정한다.

### D0-3. 시간대(TZ)와 "now" 판정 위치 (권고: **KST 고정 + 서버 시계가 권위**)

- **권고:** 전 매장 **Asia/Seoul(KST, UTC+9, DST 없음) 고정** 가정. 영업시간 문자열("HH:mm")·요일·`closedDates` 모두 KST 로 해석.
- **now 의 권위 = 서버 시계.** `paymentGate`(Cloud Function)가 **자신의 신뢰된 시계**를 KST 로 변환해 "지금 열림?"을 판정한다. 클라(손님 기기)는 **표시·선검증용으로만** 기기 로컬 시계를 쓴다(권위 아님, 드리프트 수용 — `temporary_closed_gate` 선검증이 권위 아닌 것과 동일).
- **대안:** 매장별 TZ 필드(해외 확장 대비). → **기각/후속**. 현재 제품은 국내 전용(operations/product_scope), 매장별 TZ 는 과설계.
- **확인 요청:** "전 매장 KST 고정" 가정 승인 여부. (국내 전용이 맞다면 그대로 진행.)

### D0-4. 거절 사유코드 — 몇 개로 나눌 것인가 + 우선순위 (권고: **게이트는 1개 `STORE_CLOSED_SCHEDULE`, 표시는 클라가 세분**)

- **서버 거절 사유:** `STORE_CLOSED_SCHEDULE` **1개 신설**(`GateReason` 체계에 추가, `failed-precondition`). "영업시간 밖"과 "정기휴무"를 서버는 **한 사유**로 묶는다 — 둘 다 "지금 스케줄상 닫힘"이고 손님 행동 유도(잠시 후/다음 영업일 재시도)가 사실상 같다.
- **표시 문구는 클라가 세분:** 손님 화면/결제 실패 화면에서 **(ⓐ 임시 휴업중 / ⓑ 정기 휴무 / ⓒ 영업시간 아님)** 을 같은 스케줄 데이터로 파생해 **다른 문구**로 보여준다(UX). 서버 사유코드를 쪼개지 않아도 클라가 데이터로 구분 가능.
- **우선순위(단일 장소 고정, §레이어 D1):** ① 승인 실패 → `STORE_NOT_SELLABLE` ② `temporaryClosed` → `STORE_TEMPORARILY_CLOSED` ③ 스케줄상 닫힘 → `STORE_CLOSED_SCHEDULE` ④ `null`. **임시휴업이 스케줄보다 상위**(사용자 지정: 임시휴업=즉시성 상위).
- **대안:** 사유를 `STORE_OUTSIDE_HOURS` / `STORE_REGULAR_HOLIDAY` 2개로 분리. → 서버 복잡도만 늘고 게이트 거동 동일. 기각(표시 세분은 클라로 충분).
- **확인 요청:** 사유 1개 통합 vs 2개 분리. 우선순위 ①>②>③ 승인.

### D0-5. `closedDates`(특정 날짜) 와 공휴일의 v1 범위 (권고: **특정 날짜 게이트 포함 / 공휴일 자동 = 후속**)

- **현황:** `closedDates: List<DateTime>`(특정 날짜 휴무)는 **이미 필드로 존재**하고 운영 필드 화이트리스트/모델에 있으나, `businessHours` 와 마찬가지로 **게이트에 연결 안 됨**(표시·차단 모두 없음).
- **권고:** v1 게이트 입력 = **(요일별 영업시간) + (특정 날짜 `closedDates`)**. `closedDates` 는 필드·저장 경로가 이미 있어 같은 순수 함수에 한 줄로 포함하는 비용이 작다. "오늘이 `closedDates` 에 있으면 영업시간 무관 닫힘"을 ③ 스케줄 사유로 처리.
- **공휴일 자동 휴무**(법정 공휴일 캘린더 연동) = **비범위(후속 분리)**. 외부 공휴일 데이터 소스·연도별 갱신·대체공휴일 로직이 필요해 범위가 크다. 점주가 공휴일을 쉬려면 v1 에선 `closedDates` 에 수동 추가.
- **확인 요청:** `closedDates` 게이트 **포함**(권고) vs v1 은 요일 스케줄만. 공휴일 자동 = 후속 분리 승인.

### D0-6. 엣지 정책 (권고안 — 이견만 조정)

1. **자정 넘김(심야영업 22:00~02:00):** 요일별 맵에서 `open > close` 면 자정 넘김으로 해석(기존 `_OpenStatusText` 로직 재사용). 넘어간 새벽 구간이 **어느 요일 소속인지**(영업 시작 요일 기준) 판정 규칙을 §레이어 D1 에 고정.
2. **영업시간 0개 / 전체 휴무:** 사실상 영구 휴업. **막지 않고 점주에게 경고**(designer 경고 UI). 서버는 그 상태면 항상 `STORE_CLOSED_SCHEDULE` 거절.
3. **진행 중 주문 중 영업시간 종료:** **자동 취소/강제 종료 안 함.** 이미 결제된 주문은 그대로 진행(점주가 조리·완료). 서버는 **그 시점 이후 신규 결제만** 막는다. → `temporary_closed_gate` 와 동일 철학.
4. **스케줄 수정 시 활성 주문 가드 — 두지 않음(temporaryClosed 와 차이).** `temporaryClosed` 토글은 "지금 즉시 닫는" 즉발 행위라 진행 중 주문 가드를 뒀지만, 영업 스케줄은 **상시 규칙 설정**이다. 점주가 내일 월요일 휴무를 지정한다고 지금 진행 중 주문을 막을 이유가 없다. 서버 게이트(신규 결제 거절)가 백스톱이므로 스케줄 저장에는 활성주문 조회 가드를 **생략**한다.
- **확인 요청:** 특히 4(스케줄 저장에 활성주문 가드 생략) 동의 여부.

> **§0 종합:** D0-1(요일별 맵) 과 D0-5(closedDates 포함)가 확정돼야 데이터 모델이 닫힌다. D0-2~D0-4 는 "temporaryClosed 패턴을 시간축으로 확장" 이 뼈대이고, 유일한 신규 난점은 **시간 주입(D0-3 + §D1)** 이다.

---

## 1. 개요

- **목적:** 점주가 (a) 요일별 영업 시작/종료 시간과 (b) 정기(반복) 휴무를 지정하면, 영업시간 밖 또는 휴무일에는 고객에게 **"영업시간 아님/정기 휴무"** 로 표시되고 **신규 주문(결제)이 차단**된다.
- **작업 유형:** 기존 필드(`businessHours`/`closedDates`)를 **표시 전용 → 판매 게이트**로 승격 + (D0-1 A 채택 시) 데이터 모델 확장 + 신규 거절 사유코드 + 시간 주입 순수 함수 신설.
- **제어 주체:** 점주(owner) 및 브랜드 홀더(가맹점 운영 필드). admin 강제 아님.
- **반영:** 즉시(운영 필드, 재승인 불필요 — `temporaryClosed`/`excludedMainCategories` 와 동일 패턴).

### 역할 흐름 / 라이프사이클 상의 위치 (role_flows.md / entity_lifecycle.md)

- **role_flows.md** — owner "매장 운영 정보 수정" 흐름(즉시 반영, status 무변동)에 **영업 스케줄 설정** 액션이 들어간다(기존 `businessHours` 피커 위치). customer "매장 진입 → 메뉴 탐색 → 카트 → 결제" 흐름에서, 스케줄상 닫힘이면 **결제 단계가 차단**되고 매장 상세/카트에 휴업 상태가 표시된다.
- **entity_lifecycle.md** — `stores.status`(pending/approved/rejected) 전이에 **영향 없음.** 영업 스케줄은 운영 필드라 `approved` 유지, pending 회귀 없음(§3.3 운영 필드 수정은 status 보존). `temporaryClosed` 가 status 와 직교인 것과 동일. order 전이에도 영향 없음(진행 중 주문 강제 전이 안 함, §0 D0-6-3).

### 영향 범위

- **화면:** 점주 운영 폼(`store_operation_form_page.dart` 영업시간 피커 섹션) + (D0-1 A) 요일별 7행 피커·휴무 지정 UI / 손님 매장 상세 헤더(`store_menu_header.dart` `_OpenStatusText`·배지) / 손님 카트·결제 실패 화면(스케줄 휴업 문구) / 손님 매장 메뉴 페이지 주문 차단 배너(`store_menu_page.dart`, 이미 임시휴업 배너 존재)
- **Domain:** `BusinessHours` 엔티티(D0-1 A 시 요일별 맵) / `StoreSellabilityInput`(스케줄 입력 추가) / `StoreViolation`(스케줄 휴업 추가) / `PaymentFailureReason`(사유 추가) / `validate_checkout_use_case`
- **Data:** `BusinessHoursModel`(매퍼) / `StoreModel`(`toFirestoreForOperationUpdate` 등) / `checkout_validation_remote_data_source`(`RawStoreFields` 에 스케줄 원시 읽기)
- **core/utils:** `store_sellability.dart` — `storeGateReason` 에 스케줄 사유 추가 + **신규 순수 함수 `isStoreOpenNow`**(시간 판정). 한 사실에 하나로 TS 와 동기
- **functions:** `storeSellability.ts`(TS 판정) / 신규 시간 판정 TS 포팅 / `paymentGate.ts`(G1 에 스케줄 사유 + 서버 시계 주입) / `paymentGateReader.ts`(store doc 는 이미 전체 읽음 — 추가 읽기 없음, §D2 확인)
- **Presentation(copy):** `payment_failure_copy.dart`(스케줄 휴업 전용 copy)
- **교차 골든:** `test_fixtures/store_sellability_contract.json` 확장 + 시간 판정용 신규 골든(또는 동일 json 스키마 확장) + Dart/TS 두 하네스
- **권한/환경:** `firestore.rules` — `businessHours`/`closedDates` **이미 운영 필드 화이트리스트에 있음** → (D0-1 A 로 맵 스키마만 바뀌면) **Rules 변경 불필요**(필드명 동일). `data_ownership.md §2.5` 는 필드 의미 주석만 갱신. 배포 시 `PAYMENT_GATE_MODE=enforce` 전제.
- **라우팅:** 변경 없음

### 비범위

- **공휴일 자동 휴무**(법정 공휴일 캘린더 연동) — 후속 분리(D0-5). v1 은 점주가 `closedDates` 수동 추가.
- **매장별 TZ**(해외 확장) — 국내 KST 고정(D0-3).
- **진행 중 주문 자동 취소/강제 종료** — 하지 않음(D0-6-3).
- **스케줄 저장 시 활성 주문 가드** — 두지 않음(D0-6-4, temporaryClosed 와 차이).
- **손님 홈/목록에서 스케줄 휴업 매장 숨김**(노출 필터) — 노출("보여줄까")은 판매("돈 받을까")와 다름. 스케줄 휴업 매장도 계속 보이되 "영업시간 아님"으로 표시(temporary_closed_gate §비범위와 동일 원칙).
- **영업 스케줄 변경 이력(설정 변경 이력)** — 남기지 않음(§8 audit, A2 버킷 보류 사유 명시).
- **"담기 버튼 비활성화" 등 메뉴 레벨 차단** — 기본은 표시 + 결제 차단. 더 깊은 차단은 designer 권고(선택).

---

## 2. 데이터 모델

> 최종 스키마는 **D0-1 확정에 종속**. 아래는 권고안 A(요일별 맵) 기준. B/C 채택 시 developer 가 해당 스키마로 조정.

### 2.1 `businessHours` (운영 필드 — 권고 A: 요일별 맵)

`stores/{storeId}.businessHours`:

```
businessHours: {
  weeklyHours: {           // key = 요일 "1".."7" (1=월 … 7=일, ISO-8601)
    "1": { open: "09:00", close: "18:00" },   // 엔트리 있음 = 그 요일 영업
    "3": { open: "09:00", close: "22:00" },
    // 엔트리 부재 = 그 요일 정기 휴무 (요구 b)
  }
}
```

- **요일 엔트리 부재/null = 그날 휴무.** → 요구 (b) 정기 휴무를 별도 리스트 없이 표현.
- `open`/`close` = "HH:mm" 24시 KST. `open > close` → 자정 넘김(심야영업).
- `open == close` 또는 파싱 실패 → 그 요일 닫힘(보수적, 기존 `_OpenStatusText` 규칙).
- **legacy 호환:** 기존 단일구간 `{openTime, closeTime, closedDays}` 문서는 `fromFirestore` 에서 **7요일 동일 시간 맵으로 해석**(closedDays 에 있는 요일은 엔트리 제외). 마이그레이션 상세는 §7.

> **D0-1 B 채택 시:** `businessHours = {openTime, closeTime, closedDays: List<int>}` 그대로. `closedDays` 를 게이트에 연결만 하면 됨(모델·마이그레이션 변경 없음). **가장 가벼우나 "요일별 다른 시간" 미충족.**

### 2.2 `closedDates` (운영 필드 — 기존, D0-5 로 게이트 연결)

- `closedDates: List<DateTime>` (이미 존재). v1 에서 **게이트 입력으로 승격.** "오늘(KST) 이 `closedDates` 의 날짜(연-월-일)와 일치"하면 영업시간 무관 닫힘.
- 과거 날짜는 무해(판정 시 "오늘"만 비교). developer 가 UI 에서 과거 날짜 정리 여부 판단(선택).

### 2.3 Entity / Model

- **`BusinessHours`(domain):** D0-1 A → `Map<int, BusinessDayHours?> weeklyHours`(또는 freezed 호환 위해 `Map<String, ...>` + 접근자). 기존 `openTime/closeTime/closedDays` 는 deprecate 또는 legacy 접근자로 유지(마이그레이션 완료 후 제거 — 2단계).
- **`BusinessHoursModel`(data):** `fromMap`/`toMap` 를 맵 스키마로. legacy 단일구간 맵도 `fromMap` 에서 흡수(§2.1).
- **`StoreModel`:** `toFirestoreForOperationUpdate` 의 `businessHours`/`closedDates` 직렬화 경로는 **이미 존재**(필드명 불변). 맵 구조만 바뀜.
- **판정 입력 분리(§D4):** `RawStoreFields`/`StoreSellabilityInput` 에 스케줄 원시 읽기 추가.

### 2.4 거절 사유 / 위반 enum

- **TS `GateReason`:** `"STORE_CLOSED_SCHEDULE"` 추가. `GATE_HTTPS_CODE[STORE_CLOSED_SCHEDULE]='failed-precondition'`, `GATE_TEXT` 사람용 문장(예: "지금은 매장 영업시간이 아니에요"). 메뉴 사유 아님.
- **Dart `PaymentFailureReason`:** `storeClosedSchedule('STORE_CLOSED_SCHEDULE')` 추가. `isMenuReason=false`. 토큰 정규식(`[A-Z][A-Z0-9_]{2,39}`) 매치(길이 OK).
- **`StoreViolation`:** `closedSchedule` 추가(현재 `{notSellable, temporarilyClosed, notFound}`).

---

## 3. 레이어 설계

### D1. 시간 판정 + 사유 단일화 — core/utils + functions (핵심, 한 사실에 하나)

**이 feature 의 유일한 신규 난점 = "시간"을 어떻게 순수·교차검증 가능하게 넣는가.** `storeGateReason` 는 지금 시간 입력이 없는 순수 함수다(교차 골든으로 고정). 시간을 직접 넣으면 "now()" 때문에 순수성·테스트성이 깨진다. → **시간 판정을 별도 순수 함수로 분리**하고, 그 결과(bool)만 `storeGateReason` 에 주입한다.

**신규 순수 함수 `isStoreOpenNow`(Dart `store_sellability.dart` + TS `storeSellability.ts`, 같은 규칙):**

```
입력: {
  weeklyHours: Map<int,{open,close}?>,   // KST 요일별 영업시간 (D0-1 A)
  closedDateKeys: Set<String>,           // closedDates 를 "YYYY-MM-DD"(KST) 키 집합으로 정규화
  nowWeekday: int (1..7),                // 호출자가 KST 로 계산해 주입
  nowMinuteOfDay: int (0..1439),         // 호출자가 KST 로 계산해 주입
  nowDateKey: String ("YYYY-MM-DD" KST), // 호출자가 KST 로 계산해 주입
} → bool (지금 영업 중인가)
```

- **시간(now)은 함수 밖에서 계산해 "요일·분·날짜키"로 주입** → 함수는 순수, 골든으로 고정 가능. 서버는 **신뢰된 시계**를, 클라는 기기 시계를 KST 로 변환해 주입(서버가 권위).
- 자정 넘김: `open > close` 면 `[open, 1440) ∪ [0, close)`. 새벽 구간은 **영업을 시작한 요일** 판정에 귀속(§D0-6-1) — 즉 02:00 에 "어제가 영업요일이고 어제 구간이 자정 넘겼는지"도 검사. developer 가 전일(어제 요일)의 자정넘김 구간까지 검사하도록 구현(골든에 02:00 케이스 포함).
- `closedDateKeys.contains(nowDateKey)` → 영업시간 무관 **닫힘**.
- 유효 엔트리 없음/전체 휴무 → 항상 닫힘.

**`storeGateReason` 확장(우선순위 단일 장소):**

입력에 `scheduleClosedNow: bool`(= `!isStoreOpenNow(...)`) 추가. 반환:
```
1. 승인 실패(기존)                        → STORE_NOT_SELLABLE
2. temporaryClosed == true               → STORE_TEMPORARILY_CLOSED
3. scheduleClosedNow == true             → STORE_CLOSED_SCHEDULE
4. else                                  → null
```

- `canSellNow` 는 파생 유지(`storeGateReason(x) == null`). 시그니처에 `scheduleClosedNow`(또는 스케줄 입력 묶음) 필수 인자 추가 → **호출처 전수 수정**(§영향 범위).
- **Dart `store_sellability.dart` ↔ TS `storeSellability.ts` 는 같은 규칙의 복제.** `isStoreOpenNow` 도 양쪽에 동일하게. tester 가 두 파일 동기 + 골든 교차 검증.

### D2. 서버 게이트 — functions/src/paymentGate.ts (서버 권위)

- G1 분기(현 215줄 `storeGateReason({rawStatus, hasApprovedAt, temporaryClosed})`)에 **스케줄 입력 추가**:
  ```
  const now = kstNow();  // 서버 신뢰 시계 → KST (요일/분/날짜키)
  const scheduleClosedNow = !isStoreOpenNow({ weeklyHours, closedDateKeys, ...now });
  const reason = storeGateReason({ rawStatus, hasApprovedAt, temporaryClosed, scheduleClosedNow });
  ```
- **store doc 는 이미 전체를 읽는다**(`paymentGateReader.getStore` → 전체 `RawDoc`). `businessHours`/`closedDates` 가 이미 그 안에 있으므로 **추가 Firestore 읽기 0.** (confirm: developer 가 `store.businessHours`/`store.closedDates` 원시 파싱만 추가.)
- `kstNow()`: UTC→KST(+9h) 순수 변환 헬퍼(DST 없음). 테스트 주입 가능하게 `Date` 또는 ms 인자화(단위 테스트에서 고정 시각 주입).
- 거절 시 기존 경로대로 `verifyTossPayment` 가 `paymentGateRejections/{autoId}` 에 1건 기록(사유 `STORE_CLOSED_SCHEDULE`) — **별도 로깅 코드 불필요**.

### D3. 거절 사유코드 세분화 결정 (D0-4)

§0 D0-4 확정에 따름. 권고 = 서버 1개(`STORE_CLOSED_SCHEDULE`) + 클라 표시 세분. `STORE_NOT_SELLABLE`/`STORE_TEMPORARILY_CLOSED` 재사용 아님(신설).

### D4. 클라 선검증 — Domain/Data (권위 아님)

- `checkout_validation_remote_data_source.fetchStore` 가 `businessHours`(맵)·`closedDates` 를 **원시 읽어** `RawStoreFields` 에 싣고, repository 가 `StoreSellabilityInput` 으로 전달.
- `validate_checkout_use_case._evaluate`: 기기 로컬 시각을 KST 로 변환해 `isStoreOpenNow` 호출 → `storeGateReason` 분기. `STORE_CLOSED_SCHEDULE → StoreViolation.closedSchedule`. **선검증은 권위 아님**(읽기 실패/시계 드리프트 시 막지 않음 — 서버 백스톱). 기존 불변식 유지.

### D5. 결제 실패 화면 copy — Presentation

- `payment_failure_copy.dart` switch 에 `storeClosedSchedule` case 추가(enum 추가 시 컴파일 오류로 누락 감지 — 기존 패턴). `storeTemporarilyClosed`/`storeNotSellable` 레이아웃 재사용 + 스케줄 맞춤 headline/body("지금은 영업시간이 아니에요" / 다음 영업 안내는 designer).

### D6. 손님 매장 표시 — Presentation

- `store_menu_header.dart`: `_OpenStatusText` 를 **요일별 맵 기준으로 재작성**(D0-1 A) + 스케줄 휴업 시 배지/문구. `_TemporaryClosedBadge`(임시휴업) 가 스케줄보다 우선(우선순위 D0-4). 표시 우선순위: 임시휴업 > 정기휴무/영업시간아님 > 영업중.
- `store_menu_page.dart`: 이미 "임시 휴업중" 주문 차단 배너가 있음(459줄). 스케줄 휴업용 배너 분기 추가(designer 문구). 표시 + 결제 차단이 in-scope. 메뉴 담기 비활성화 깊이는 designer 권고.
- `cart_page.dart`/`cart_availability_banner.dart`: 스케줄 휴업 문구 분기(기존 임시휴업 배너 재사용).

### D7. 데이터 흐름

```text
[손님 결제 — 서버 권위]
verifyTossPayment → evaluatePaymentGate(G1)
  → kstNow()(서버 신뢰 시계) → isStoreOpenNow(weeklyHours, closedDateKeys, now)
  → storeGateReason(rawStatus, hasApprovedAt, temporaryClosed, scheduleClosedNow)
  → 닫힘이면 confirm 전 거절 + STORE_CLOSED_SCHEDULE + paymentGateRejections 1건

[손님 선검증 — 권위 아님]
Cart/Checkout → ValidateCheckoutUseCase → (기기 시각 KST) → isStoreOpenNow → storeGateReason
  → StoreViolation.closedSchedule (읽기/시계 실패 시 막지 않음)

[점주 스케줄 저장 — 즉시 반영]
store_operation_form_page (요일별 피커/휴무 지정)
  → UpdateStoreOperationFieldsUseCase → stores.update(businessHours/closedDates 운영 필드 묶음)
  → status 무변동 (활성 주문 가드 없음 — D0-6-4)
```

---

## 4. 에러 / 엣지 처리

| 케이스 | 처리 |
|---|---|
| 서버 게이트: 스케줄상 닫힘 | confirm 전 거절 + `STORE_CLOSED_SCHEDULE` + `paymentGateRejections` 1건 |
| 선검증 매장 읽기 실패/타임아웃 | `CheckoutValidation.none`(막지 않음) — 서버 백스톱 |
| 기기 시계 드리프트(클라) | 선검증은 권위 아님 — 서버 시계가 최종 판정. 표시만 약간 틀릴 수 있음(수용) |
| 자정 넘김 심야영업(22:00~02:00) | `open>close` 양 구간 + 전일 요일 자정넘김 검사(§D1). 골든에 02:00 케이스 |
| 영업시간 0개 / 전체 휴무 | 항상 닫힘(게이트 거절). 점주에게 경고 UI(막지 않음) |
| 진행 중 주문 중 영업 종료 | 자동 취소 없음. 기존 주문 진행, 신규 결제만 차단(D0-6-3) |
| legacy 단일구간 매장 | `fromFirestore` 에서 7요일 동일 맵 해석(§2.1). 게이트 결과 보존 |
| `closedDates` 과거 날짜 | 무해(오늘만 비교). UI 정리는 선택 |
| 모르는 사유 토큰 | 기존대로 `PaymentFailureReason.unknown`(변경 없음) |

---

## 5. 교차 골든 갱신 범위 (반드시)

`test_fixtures/store_sellability_contract.json` + 두 하네스(Dart `payment_authority_contract_test.dart`, TS `paymentAuthority.test.mjs`)를 함께 확장. 둘이 같은 json 을 읽어야 "한 사실에 하나" 유지.

- **스키마 확장:** 각 케이스에 스케줄 입력(`scheduleClosedNow` 또는 `weeklyHours`+주입 now) + `expectReason`(`null`|`STORE_NOT_SELLABLE`|`STORE_TEMPORARILY_CLOSED`|`STORE_CLOSED_SCHEDULE`).
- **기존 행:** `scheduleClosedNow:false` 를 더하고 결과 불변 확인.
- **신규 행(최소):**
  - approved + temporaryClosed:false + scheduleClosedNow:true → `STORE_CLOSED_SCHEDULE`
  - approved + temporaryClosed:true + scheduleClosedNow:true → `STORE_TEMPORARILY_CLOSED`(②가 ③보다 우선)
  - pending-only + scheduleClosedNow:true → `STORE_NOT_SELLABLE`(①우선)
  - approved + 영업시간 내 → `null`
- **`isStoreOpenNow` 전용 골든(신규 또는 확장):** 요일별 맵 × 시각 조합 — 영업 중/영업 밖/정기휴무(엔트리 부재)/자정넘김 02:00/closedDate 일치/전체 휴무. Dart·TS 동일 통과.

---

## 6. 영향 범위 — `canSellNow`/`storeGateReason` 호출처 전수 (signature 변경)

스케줄 입력이 필수 인자로 추가되므로:

| 위치 | 처리 |
|---|---|
| `functions/src/paymentGate.ts` G1(~215) | `kstNow`+`isStoreOpenNow`+`scheduleClosedNow` 주입(§D2) |
| `functions/src/migrateStoreApprovalMeta.ts`(willBeRejected) | **`scheduleClosedNow:false` 로 호출**(승인 전용 판정, 시간 무관). 스케줄 휴업 매장을 마이그레이션 이상치로 오분류 방지 |
| `lib/domain/usecases/validate_checkout_use_case.dart` | 기기 시각 주입 + 분기(§D4) |
| Dart/TS 테스트(contract/authority) | 골든·호출 인자 갱신 |

Rules: **변경 없음**(`businessHours`/`closedDates` 운영 필드 화이트리스트 기포함, 필드명 불변). 맵 스키마 변경은 Rules 가 값 구조를 검증하지 않으므로 무영향.

---

## 7. 마이그레이션 (D0-1 A 채택 시)

- 기존 `businessHours = {openTime, closeTime, closedDays}` 문서 → 요일별 맵. **권고: 읽기 시점 흡수(lazy)** — `BusinessHoursModel.fromMap` 이 legacy 단일구간을 "7요일 동일 시간(closedDays 제외)" 맵으로 **해석만** 하고, 점주가 다음 저장 시 신 스키마로 영속. **일괄 백필 CF 불필요**(표시·게이트가 lazy 해석으로 정확).
- 단, 서버(TS)·클라(Dart) `fromMap` 둘 다 legacy 흡수 로직을 **동일하게** 가져야 함(한 사실에 하나). tester 교차 검증.
- 실측 `businessHours` 보유 매장 수는 developer 가 확인(소규모면 lazy 로 충분).
- **D0-1 B 채택 시:** 마이그레이션 불필요(필드 구조 불변, `closedDays` 활성화만).

---

## 8. 이력 / 감사 추적 (audit_trail.md §4 체크리스트 6항목)

| # | 항목 | 판정 |
|---|---|---|
| 1 | **돈·권한·정책 값을 바꾸는가 → 설정 변경 이력 기본값** | 영업 스케줄(`businessHours`/`closedDates`)은 **"지금 판매하는가"를 좌우하는 운영 상태**다. `temporaryClosed`/`isOpen`/`excludedMainCategories` 와 **동급 운영 필드**이며, Qoin 적립률 같은 **정책 값(돈의 계수)** 도 `users.brandId` 같은 **권한 값**도 아니다. 판매를 막는 효과는 있으나 점주가 수시로 바꾸는 가역 설정이다. → **설정 변경 이력 미도입.** 사유: `audit_trail.md A2`("매장 운영 정보 변경 이력 — 이름·주소·**영업시간** 등, 미설계")가 바로 이 필드의 소속 버킷이다. A2 설계 시 함께 편입 권고. **(판매를 막는 효과가 생기므로 이 판단을 여기 명시한다 — temporary_closed_gate §이력 1 과 동일 규율.)** |
| 2 | 덮어쓰기로 사라지는 값? | 이전 스케줄값 보존 필요성 낮음(운영 상태, 점주가 자기 UI 에서 재확인·복구). 수용. #1 과 동일. |
| 3 | 거래/기록이 정책 값을 참조만? | 해당 없음. `businessHours`/`closedDates` 는 금액·적립 계산에 들어가지 않는다(게이트 입력일 뿐). |
| 4 | "누가"? | **거절 발생은 `paymentGateRejections` 에 남는다**(사유 `STORE_CLOSED_SCHEDULE`, 기존 경로). 스케줄 **변경** 행위자 기록은 #1 사유로 생략. |
| 5 | batch/마이그레이션? | 없음(단건 운영 update). D0-1 A 는 lazy 흡수라 백필 CF 없음(§7). |
| 6 | CF 로그 의존? | 아니다. 거절은 Firestore `paymentGateRejections` 에 영구 기록(기존). |
| (7) | 권한 판정 필드 create/update 교차? | `businessHours`/`closedDates` 는 **권한 판정 입력 아님**(판매 게이트 입력일 뿐, Rules 권한·Qoin 보호와 무관). 이미 운영 화이트리스트에 있어 create/update 추가 가드 불필요. |

> **혼동 방지(audit §4 자주 놓치는 것):** 여기엔 **거절 이력**(`paymentGateRejections`)만 있고 **설정 변경 이력(영업시간 변경 기록)** 은 **의도적으로 없다.** 둘은 다르다 — #1 에서 없음 사유(A2 버킷 보류)를 명시했다.

---

## 9. 작업 분배

> **§0 6개 결정 확정 후** 착수. 특히 D0-1(모델)·D0-5(범위)가 데이터 모델을 가른다.

### designer — **호출 필요**

- 사유: (a) 점주 운영 폼 **요일별 영업시간 피커**(D0-1 A → 7행, 요일별 on/off + 시간, 휴무 토글) + 특정 날짜 휴무(`closedDates`) 지정 UI + 전체 휴무 경고, (b) 손님 매장 상세 스케줄 상태 표시("영업시간 아님"/"정기 휴무"/"영업 중", 임시휴업 배지와 우선순위), (c) 손님 주문 차단 배너·카트·결제 실패 화면 스케줄 휴업 문구(임시휴업 패턴 재사용).
- 산출물: `docs/tasks/store_business_schedule/design.md`.
- 전달: `AppColors` 만, 신규 컴포넌트 지양. 기존 `_OpenStatusText`/`_TemporaryClosedBadge`/임시휴업 배너·copy 톤 재사용. 자정 넘김·휴무 요일 표기 UX 포함.

### developer — designer 후 호출

- 순서 권장: `isStoreOpenNow`+`storeGateReason` 확장(Dart/TS, §D1) → 골든 확장(§5) → `kstNow`+서버 게이트(§D2) → Entity/Model(D0-1 확정 스키마)+legacy 흡수(§7) → 클라 선검증/copy/표시(§D4~D6) → 운영 폼 요일별 피커 UI(design.md).
- 재사용: `storeGateReason` 패턴·`paymentGateRejections` 경로·임시휴업 copy/배너, 기존 `_OpenStatusText` 자정넘김 로직.
- 레이어 규칙: Firebase 는 data/functions 만. `store_sellability.dart` 순수 Dart(외부 SDK import 금지). **Dart·TS 판정 동기 필수.** 색상 `AppColors` 만.
- 산출물: `docs/tasks/store_business_schedule/implementation.md`.
- 빌드: `dart run build_runner build --delete-conflicting-outputs`(freezed 재생성), `flutter analyze`, `flutter test`, functions `npm test`/`tsc`.

### tester — developer 후 호출

- `isStoreOpenNow` Dart·TS **동일 규칙**(두 파일 교차) + `storeGateReason` 우선순위(①>②>③) + 교차 골든 두 하네스 통과(자정넘김 02:00·closedDate·전체휴무·요일 엔트리 부재 포함).
- 서버 게이트: 영업시간 밖/휴무일 → `STORE_CLOSED_SCHEDULE` 거절 + `paymentGateRejections` 1건, Toss confirm 미호출. 고정 시각 주입 단위 테스트.
- 선검증: 읽기/시계 실패 시 막지 않음(권위 아님) 불변식 유지.
- legacy 단일구간 흡수: Dart·TS `fromMap` 동일 해석. 신 스키마 round-trip.
- 결제 실패 화면: `STORE_CLOSED_SCHEDULE` 전용 copy 렌더, switch 누락 없음.
- 회귀 0: 기존 주문·`temporaryClosed`·결제·승인 메타·Qoin 흐름 불변. Rules 무변경 회귀(`businessHours`/`closedDates` update 여전히 통과).
- 산출물: `docs/tasks/store_business_schedule/test_report.md`.

---

## 10. 배포 영향 (사용자 조치)

- **functions 재배포:** `storeSellability.ts`(판정+시간), `paymentGate.ts`(사유+서버시계), `migrateStoreApprovalMeta.ts`(signature).
- **앱 재빌드:** 클라 선검증·copy·표시·요일별 피커·enum.
- **게이트 모드:** 서버 거절이 실제로 걸리려면 `PAYMENT_GATE_MODE=enforce`(operations.md). `shadow`=기록만.
- **Rules 배포 불필요**(변경 없음). **백필 CF 불필요**(D0-1 A lazy 흡수).

---

## 11. 완료 기준

- [ ] §0 6개 결정 사용자 확정.
- [ ] `isStoreOpenNow`·`storeGateReason` Dart↔TS 판정 규칙 동기.
- [ ] 교차 골든(json + Dart/TS 하네스) 확장·통과(자정넘김·휴무·전체휴무 포함).
- [ ] `STORE_CLOSED_SCHEDULE` 서버 거절(confirm 전) + 클라 copy·표시 동작.
- [ ] 우선순위 ①STORE_NOT_SELLABLE > ②STORE_TEMPORARILY_CLOSED > ③STORE_CLOSED_SCHEDULE 검증.
- [ ] legacy 단일구간 → 요일별 맵 lazy 흡수(Dart·TS 동일).
- [ ] 회귀 0(주문·temporaryClosed·결제·승인·Qoin).
- [ ] `design.md` / `implementation.md` / `test_report.md` 작성, FAIL 없음(또는 후속 분리).
- [ ] audit §4 6항목 통과(설정 변경 이력 미기록 사유 = A2 버킷 보류 명시).
</content>
</invoke>
