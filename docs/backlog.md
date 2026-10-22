# Backlog

확정되지 않았거나 후속 phase 로 미룬 작업을 기록하는 단일 진실원.
각 항목은 추후 `docs/tasks/[기능명]/spec.md` 로 승격될 수 있다.

---

## 현재 남은 작업 (2026-10-21 코드 기준 전수 조사)

Phase 3c 완결 시점의 스냅샷. **문서가 아니라 코드를 읽어 작성했다.**

### 탭에 연결된 미구현 화면 — **2026-10-22 기준 0건**

| 화면 | 위치 | 비고 |
|---|---|---|
| ~~고객 Qoin~~ | ~~`customer/qoin/qoin_page.dart:50`~~ | **완료 (2026-10-22)** — `docs/tasks/qoin/`. **네비 탭 placeholder 가 모두 사라졌다** |

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

### ✅ 점주 매출 조회 — 1차 구현 완료 (2026-10-22)
`lib/presentation/owner/sales/` (`OwnerSalesPage`). placeholder 는 삭제됐고 **점주 4개 탭이 모두 실구현**됐다.
일/주/월 요약(총 매출·주문 건수·평균 객단가) + 주문 목록 + 환불 주문일 기준 차감, 클라이언트 집계.
문서: `docs/tasks/owner_sales/{spec,design,implementation,test_report}.md`
남은 품질 항목은 아래 "owner_sales 후속", 2차 기능 범위는 "2차 범위 (S1~S6)" 참조.

### 🔜 qoin_accrual_rate_hierarchy — 적립률 계층화 (Qoin 1차 직후 착수 예정)

**2026-10-22 사용자 요구사항 확정.** Qoin 1차는 전역 적립률 하나(`config/qoin.accrualRate`)만 쓴다. 그 위에 계층을 얹는다.

#### 확정된 요구사항

| # | 항목 | 확정 |
|---|---|---|
| H1 | **비용 부담 주체** | **브랜드 / 매장** (플랫폼 아님) |
| H2 | **설정 권한** | **admin 전용.** 점주·브랜드는 **읽기만** |
| H3 | 해석 순서 | 매장 설정 → 없으면 브랜드 설정 → 없으면 전역 기본값. ※ 2026-10-22 Q1 로 **적립 스위치**가 사슬 앞단에 추가됐다 (spec §20.3.1) |
| H4 | 브랜드 일괄 적용 | **별도 기능.** 하위 매장 전체에 적용 |
| H5 | 일괄 적용 시 개별 설정 처리 | **선택식(C안)** — 보존 / 덮어쓰기 중 선택. 덮어쓰기 시 영향 매장 수를 보여주고 확인받는다. **덮어쓰면 개별 설정은 초기화되며 다시 설정해야 한다** |
| H6 | 매장별 적용 적립률 조회 | admin 은 전체 조회, 점주·브랜드는 자기 것 읽기 전용 |

#### H1·H2 분리의 근거

돈을 내는 쪽(브랜드·매장)과 정하는 쪽(admin)이 다르다. 의도된 설계다.

| 권한을 주면 | 결과 |
|---|---|
| 점주 | 자기 비용이라도 상한 없이 올려 과도한 출혈 → 책임 전가 분쟁 |
| 브랜드 | 가맹점 비용으로 본사가 마케팅 → 가맹점 분쟁 |
| **admin** | 요청 검토 후 반영. **기록이 남고 통제된다** |

PG 사가 가맹점 수수료율을 가맹점 마음대로 못 바꾸게 하는 구조와 같다.
읽기를 열어주는 이유: 자기 비용인데 얼마인지 모르면 안 된다.

#### H7 — 적립률 변경 이력 (2026-10-22 사용자 확정, 계층 작업에 **포함**)

`config` 문서를 덮어쓰면 이전 값이 사라진다. **설정 변경 자체를 남겨야 한다.**

남길 항목: **누가 / 언제 / 어느 범위(전역·브랜드·매장) / 이전 값 → 새 값 / 변경 사유(선택)**
일괄 적용은 1건으로 묶되 **영향받은 매장 수와 덮어쓰기 여부**를 함께 남긴다.

| 이력이 없으면 | |
|---|---|
| "왜 이 매장만 10%지?" | 추적 불가 |
| 정산 분쟁 | 그 기간의 적립률을 증명 못 함 |
| 오입력 사고 | 언제부터 잘못됐는지 모름 |
| 되돌리기 | 이전 값을 모름 |

> **구분**: 적립 **거래** 이력(`users/{uid}/qoinTransactions`)은 Qoin 1차에 이미 있다. 각 거래에 당시 `orderTotalPrice` / `accrualRate` 가 박제되어 정책이 바뀌어도 과거 내역이 틀리지 않는다. H7 은 그것과 별개로 **설정 변경** 을 남기는 것이다.

#### 설계 시 반드시 다룰 것

- **감사 추적** — H7 참조
- **일괄 적용의 원자성** — 가맹점이 많을 때 일부만 적용되고 실패하면 안 된다
- **CF 해석 비용** — 적립마다 매장·브랜드 문서를 추가로 읽게 된다. ~~주문 문서에 `brandId` 가 이미 있으므로~~ ⚠️ **틀린 전제였다** — 주문의 `brandId` 는 항상 null 이고, 신뢰원은 `stores/{id}.brandId` 다 (tester F1 / spec §19.1)
- **1차 관리자 화면 대체** — Qoin 1차의 전역 전용 설정 화면은 이 작업에서 **계층 화면으로 교체**된다 (1차 작업의 일부 폐기를 전제로 한다)

#### 진행 상태 (2026-10-22)

구현은 `68ee77a`(백엔드) + `9068fa9`(앱/테스트) 에 있고 **미배포**다. tester FAIL 6건 재검토(spec §19) 와 사용자 결정 Q1·Q2·Q3 확정(spec §20) 이 끝났고, **배포 전 필수 항목은 spec §20.10, 배포 순서는 §20.11** 을 따른다.

#### 1차와의 관계

Qoin 1차의 원장·잔액·멱등성·회수·고객 화면은 **그대로 재사용**된다. 바뀌는 것은 "적립률을 어디서 읽느냐" 와 관리자 화면뿐이다.

### ✅ 일괄 적용이 `적립 안 함(0%)` 매장을 덮는 문제 — **2026-10-22 종결 (사용자 결정 Q1)**

**결정: 옵션 A~D 를 전부 기각하고, "적립 사용 안 함" 을 적립률과 분리된 별도 스위치로 둔다.**

설계: `docs/tasks/qoin_accrual_rate_hierarchy/spec.md` **§20** (§20.1 필드 / §20.2 진리표 / §20.3 해석 사슬 / §20.4 마이그레이션 / §20.5 권한·이력)

#### 왜 A~D 가 전부 기각됐나

문제의 뿌리는 "덮을까 말까" 가 아니라 **`qoinAccrualRate` 한 필드가 두 가지를 겸하고 있다**는 것이었다 — "적립률은 얼마냐"(숫자, 덮어도 된다) 와 "적립을 하냐"(스위치, 덮으면 사고). 같은 필드이므로 일괄 적용이 둘을 구분할 수 없었다.

| | 당시 방식 | 기각 사유 |
|---|---|---|
| A | 0% 매장은 덮어쓰기에서도 제외 | **"값이 0이면 건너뛴다" 는 예외 규칙**으로 때우는 안. 서버·클라이언트·다이얼로그 문구·이력 집계 네 곳에 같은 분기를 심고, "왜 이 매장만 안 바뀌었나" 를 계속 설명해야 하며, 나중에 "0% 도 덮고 싶다" 가 나오면 선택지를 다시 만들어야 한다 |
| B | 0% 매장 목록 개별 체크 | 매장이 많으면 비현실적 (당시 판단 유지) |
| C | 3택 (전체 / 0% 제외 / 0% 포함) | 선택지 추가 비용 대비 이득이 작다 (당시 판단 유지) |
| D | 현재안 — 알림만 | 다이얼로그 숫자가 실행 시점과 어긋날 수 있어 보장이 안 된다 |

#### 채택안

```
적립률(qoinAccrualRate)        : 숫자만. 0 금지. 일괄 적용이 덮는다
적립 스위치(qoinAccrualEnabled) : 매장·브랜드 단위. 전용 CF 만 쓴다.
                                 일괄 적용에서 **도달 불가능**
적립률 0% 설정                  → 스위치 끄기로 대체 (사용자: "0%를 하면 자동 사용 안 함")
```

일괄 적용 코드에 "0 인지" 를 묻는 분기가 **0개**다. 덮어쓸 수 없는 이유가 코드가 아니라 **스키마**이므로 집행 누락이 불가능하고, A 안이 해결하려던 "다이얼로그 숫자와 실행 시점의 괴리" 도 같이 사라진다.

**부수 효과**: 덮어쓴 뒤 스위치를 다시 켜면 0% 가 아니라 **상위(브랜드) 요율**로 적립된다 — 0% 라는 숫자는 저장되지 않고 "사용 안 함" 상태만 남기 때문이다 (spec §20.6.1).

---

### ⬜ `stores.delete` 정책 재설계 (Q3 수용의 대가 — 2026-10-22 신규)

**출처**: `qoin_accrual_rate_hierarchy` tester F4 → 사용자 결정 Q3 ⓐ(수용). 수용의 근거는 "재생성 매장은 `status: 'pending'` 이라 admin 재승인 전까지 적립이 발생하지 않는다" 이고, 그것은 **적립률 1필드의 문제가 아니라 삭제 정책의 문제**임을 드러낸다.

#### 문제 3개

| # | 내용 |
|---|---|
| 1 | **점주가 자기 매장을 하드 삭제할 수 있다** (`stores.delete: isAdmin() \|\| isStoreOwner`). 매장 문서 전체가 사라진다 — 적립률·스위치보다 훨씬 큰 권한이다 |
| 2 | **삭제가 이력에 남지 않는다.** 누가 언제 왜 지웠는지 복원 불가 (`audit_trail.md` §4-2·4-4) |
| 3 | **서브컬렉션이 고아가 된다.** `stores/{id}/qoinRateHistory`, `menuItems`, `subCategories` 등이 부모 없이 남고, 점주 read 는 `get(store)` 실패로 거부되어 **admin 만 읽을 수 있다** |

#### 선택지 (미결정)

| | 방식 |
|---|---|
| A | **소프트 삭제** — `status: 'deleted'` 전이로 바꾸고 하드 삭제는 admin 전용 |
| B | 하드 삭제를 **admin 전용**으로 좁히고 점주는 "폐업 신청" |
| C | 삭제 CF 전담 — 삭제 이력 1건 + 서브컬렉션 정리를 원자적으로 |

#### 함께 볼 것

- `entity_lifecycle.md` 의 store status 전이에 `deleted` 를 넣을지 (넣으면 주문·메뉴 흐름 전반에 영향)
- 같은 문제가 `brands` / `menuItems` 에도 있는지 전수 조사
- 적립 스위치도 재생성으로 제거된다 (`qoin_accrual_rate_hierarchy/spec.md` §20.5.6 #13)

**우선순위**: 중. 돈으로 직결되지는 않지만(재승인 게이트가 있다) 운영 데이터가 조용히 사라지는 경로다.

---

### ⬜ Qoin 적립 누락분 소급 적립 도구 (Q2 ⓐ 의 후속 — 2026-10-22 신규)

**출처**: `qoin_accrual_rate_hierarchy` H-2 → 사용자 결정 Q2 **ⓐ 기록만**. 기록 수단(`qoinSettlementIssues/{orderId}`)은 계층화 배포분에 포함되고, **소급 적립 도구는 여기로 미룬다.**

#### 왜 누락이 발생하나

적립률·스위치에 무효 값(범위 밖 숫자 / 비number / 비bool)이 들어가면 CF 는 **추측하지 않고 fail-closed 로 멈춘다**. 그런데 트리거가 `return` 으로 **정상 종료**되므로 재시도되지 않고, 트리거 조건(`orders` 의 `* → completed` 전이)은 이미 지나갔다 → 값을 고쳐도 **그 주문들은 영영 적립되지 않는다.** 무효 값은 Firebase Console / Admin SDK 직접 편집으로만 생긴다 (앱·Rules 경로로는 불가능).

#### 지금 만들지 않는 이유

**"어느 시점 요율로 줄 것인가" 가 정책 결정이다.**

| | 요율 | 문제 |
|---|---|---|
| ⓐ | 발생 시점에 의도했던 값 | **알 수 없다** (무효 값이었으므로) |
| ⓑ | 수정 후 값 | 설명하기 쉽다("정상값으로 고친 뒤 그 값으로 지급"). 단 요율이 내려갔다면 고객에게 불리 |
| ⓒ | 그때의 전역 기본값 | 매장·브랜드 정책을 무시한다 |

기록이 쌓이면 **실제 건수와 금액을 보고** 정하는 편이 정확하다. `qoinSettlementIssues` 가 있으면 나중에 만들 수 있고, 없으면 그때 **대상 목록 자체가 없다.**

#### 만들 때 필요한 것

- `qoinSettlementIssues` 를 보는 admin 화면 (건수·금액·매장별 분포)
- 소급 적립 CF — 멱등 ID 를 `earn_{orderId}` 로 유지해야 **중복 적립이 구조적으로 불가능**하다 (1차 멱등 가드 재사용)
- 처리 후 `resolved: true` + 처리자·처리 시각
- 전제: 적립 금액 산식(`computeEarnAmount`)과 원장 스키마는 1차 자산 그대로 쓴다

---

### ⬜ `role_flows.md` 의 Qoin 흐름 drift 정정 (2026-10-22 발견)

`docs/processes/role_flows.md` L123 · L215 가 Qoin 을 아직 **"미구현 — 컬렉션 미정의"** 로 적고 있다. 실제로는 1차(원장·잔액·적립·회수)가 구현 완료이고 계층화(적립률 3계층 + 스위치 + 변경 이력 + admin 화면 4개)가 배포 대기 중이다.

- 갱신 대상: customer 흐름의 Qoin 조회, admin 흐름의 Qoin 설정·스위치·일괄 적용, owner/brand 흐름의 적립률 읽기 1행
- 참조할 단일 진실원: `docs/processes/data_ownership.md` §2.11, `docs/tasks/qoin_accrual_rate_hierarchy/spec.md` §12 · §20.9
- **계층화 배포 후에 한 번에 갱신**한다 (배포 전에 쓰면 또 틀린다)

---

### 🔮 UI 전면 개편 (모든 기능 개발 완료 후 — 2026-10-22 사용자 의사)

사용자가 **전반적인 디자인 변경**을 계획하고 있으며, **기능 개발이 전부 끝난 뒤** 착수한다.
지금 하면 같은 화면을 두 번 작업하게 되므로 미룬다.

#### 왜 비교적 안전한가

Clean Architecture 가 지켜져 있어 **화면이 로직을 들고 있지 않다.**
위젯은 엔티티 값을 **표시만** 하며, 집계는 UseCase 한 곳에만 있다 (`owner_sales` 의 `aggregateStoreSales`, Qoin 의 CF).
`AppColors` 전용 규칙 덕에 색 변경이 한 곳에서 전파된다.

#### ⚠️ 개편 시 반드시 보존할 것

레이아웃을 정리하다 **조용히 날아가기 쉬운 것들**이다. 눈에 보이지 않거나, "불필요해 보이는" 모습을 하고 있다.

**① 접근성 라벨 (`Semantics`)**

눈에 안 보여서 가장 먼저 사라진다. 오늘 공들여 조립한 것들:
- `총 매출 101,500원 / 주문 건수 3건 / 환불 1건, 37,000원 제외` — **음수 하이픈 대신 양수 + "제외"** (기기마다 하이픈 낭독이 다름)
- `540 Q 회수` — 같은 이유
- 기간 라벨 `liveRegion` — 이동 결과 자동 공지
- 등급 선택 `inMutuallyExclusiveGroup` + `checked`

**② 카피 문자열 — 전부 이유가 있다**

| 문구 | 빼면 생기는 일 |
|---|---|
| `결제 직후가 아니라, 매장에서 픽업 완료 처리가 되면 반영돼요` | "적립이 안 됐다" 오해 (실제로 평가 기능에서 발생) |
| `끄면 적립과 환불 회수가 모두 멈춰요` | 모르고 끄면 환불 고객이 Qoin 을 그대로 가짐 — **돈이 샌다** |
| `0.1% 이상 입력해주세요. 3% 는 '3' 으로 입력해요` | 100배 오입력 방어 무력화 |
| `환불은 주문한 날의 매출에서 차감돼요` | "어제 숫자가 왜 줄었지?" 민원 |
| `주문이 많아 최근 1,000건만 집계했어요` | **조용히 틀린 숫자**를 보여주게 됨 |

"문구가 기네" 하고 줄이면 방어 장치가 날아간다.

**③ 조건부 렌더링 규칙**

| 요소 | 규칙 |
|---|---|
| 환불 각주 | 환불 ≥ 1건일 때만 |
| truncated 경고 | 상한 도달 시만 |
| 진행 중 주문 배너 | 미완료 주문 있을 때만 |
| **매출 3행(진행/환불/취소)** | **0건이어도 항상 표시** |

마지막이 함정이다. "0건인데 왜 보여?" 하고 숨기면 **숫자가 생길 때 레이아웃이 흔들린다.**

**④ 상태 구분 — "0" 과 "모름"은 다르다**

에러일 때 `0원` / `0 Q` 로 대체하지 않는다. 로딩 중에도 `0` 을 보여주지 않고 skeleton 을 쓴다.
`owner_sales` 는 `Source.server` 로 캐시 fallback 까지 제거했다 (오프라인에서 캐시 숫자가 정상값처럼 보이는 것을 막기 위해).

**⑤ 위젯에서 집계 금지**

`totalPrice` 를 위젯에서 더하지 않는다. 이 규칙이 깨지면 레이아웃 변경이 **숫자 오류**로 번진다.

#### 진행 방식 (권장)

화면별로 착수 전에 **"건드리면 안 되는 것" 목록을 먼저 뽑는다.**
`store_reviews` 에서 "sub-phase 3 에서 검증 끝난 자산은 변경 금지" 로 못박아 사고를 막은 방식과 같다.
골든 스크린샷(`agent_automation_strategy.md` §5 우선순위 5번)이 있으면 회귀를 기계가 잡을 수 있다 — 개편 전에 갖추면 가치가 가장 큰 시점이다.

### ⬜ owner_sales 후속 (1차 완료 후 남은 품질 항목)

출처: `docs/tasks/owner_sales/test_report.md` §Z-5.

| # | 항목 | 비고 |
|---|---|---|
| Q1 | `isTruncated` 가 `>=` 판정이라 정확히 1,000건일 때도 경고가 뜬다 | 보수적 오탐이라 숫자가 틀리지는 않는다. 정확히 하려면 `limit + 1` 로 조회해 초과 여부를 판정 |
| Q2 | provider·위젯 계약 테스트 0건 | 있었다면 F2(재시도 시 skeleton 미표시)를 정적으로 잡았다. N1 과 함께 처리 |
| ~~Q3~~ | ~~`test_rules` 에 `orders` 시드 + R13~R18 추가~~ → **완료 (2026-10-22)** 18/18 PASS | — |
| ~~Q4~~ | ~~오프라인·재시도 경로 라이브 미검증~~ → **완료 (2026-10-22)** Firestore 만 죽은 호스트로 돌려 검증. F1 은 캐시 데이터가 있는 날짜로 결정적 확인 | — |
| Q5 | **오프라인에서 `다시 시도` 가 시각적 무반응** | 재시도가 3ms 만에 실패해 skeleton 이 한 프레임도 안 그려진다. 버튼이 고장난 것처럼 느껴진다. 개선안: ⓐ 최소 skeleton 노출 시간 보장 ⓑ 즉시 실패 시 SnackBar. 결함은 아니고 UX 흠결 |

### ⬜ `OrderRemoteDataSource.streamPaidByStore` 개명

이름은 `Paid` 지만 실제로는 임의 status 필터를 받는 **범용 메서드**다. 읽는 사람이 `paid` 상태만 가져온다고 오해하기 쉽다.
owner_sales 설계 중 발견. **이번에는 개명하지 않았다** — 주문 접수 탭(`OwnerOrdersPage`)의 3개 탭이 모두 이 메서드를 쓰고 있어 회귀 위험이 이득보다 크다고 판단했다.
주문 접수 탭에 자동화 테스트가 생기면 그때 함께 처리한다 (N1 과 묶을 수 있음).

### ⬜ 점주 매출 조회 — 2차 범위 (1차 착수 시 **의도적으로 제외**한 항목)

1차(`owner_sales` task)는 **일/주/월 요약 + 주문 목록 + 클라이언트 집계** 로 범위를 좁혔다.
아래는 "안 하기로" 한 것이 아니라 **2차로 미룬 것**이며, 1차 화면 구조를 그대로 두고 얹을 수 있게 설계한다.

| # | 항목 | 미룬 이유 | 선행 조건 |
|---|---|---|---|
| S1 | **메뉴별 판매 순위** | `orderItems` 순회가 필요해 집계 로직이 한 단계 더 복잡해진다 | 1차 집계 레이어 완성 |
| S2 | **시간대별 분포 차트** | 차트 라이브러리 도입 여부를 함께 결정해야 한다 (현재 리포지토리에 차트 의존성 없음) | 라이브러리 선정 |
| S3 | **카드사별 매출** | 1차 범위를 좁히기 위해 제외 | ~~PG 응답 저장 여부 확인~~ → **선행조건 해소 (2026-10-21)**. `PaymentInfoEntity` 에 `cardCompany` / `cardNumberMasked` / `easyPayProvider` 가 **이미 저장 중**임을 owner_sales 설계 중 실측 확인 |
| S4 | **연 단위 / 기간 비교** (전월 대비 등) | 1차는 일/주/월까지. 비교 UI 는 별도 판단 | — |
| S6 | **갱신 시각 표기 (`n분 전 기준`)** | `IndexedStack` + `get()` 1회라 오래된 숫자가 남을 수 있다. `StoreSalesEntity.fetchedAt` 추가가 필요한 spec 변경이라 1차 제외. **자정을 넘겨 앱을 켜 둔 경우 '오늘' 이 어제로 남는 한계도 같은 원인** | 라이브에서 체감 여부 확인 |
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

### ✅ 매장 평가 (store_reviews) — 1차 구현 완료 (2026-10-22)

> **2026-10-22 정정.** 기존 기술 "1~5점 + 텍스트 리뷰. 매장 상세 화면" 은 **두 군데가 틀렸다.**
> ① 도메인은 1~5 별점이 아니라 **S/A/B/C 등급**이다 (`StoreGrade`, 내부 점수 S=4 A=3 B=2 C=1).
> ② 고객용 **"매장 상세 화면" 은 존재하지 않는다** (가장 가까운 것은 `store_menu_page`).
> 설계 중 실측으로 드러났다. 이번에도 backlog 가 코드보다 낡아 있었다.

문서: `docs/tasks/store_reviews/{spec,design,implementation,test_report}.md` (D1~D6 / A1~A5 / Q1~Q3 전건 확정)

**라이브 검증 전 구간 PASS** — 평가 작성 → CF 집계 → 등급 반영까지 닫혔다. 실결제 0회.
`[onReviewWritten] recomputed. { reviewCount: 1, averageScore: 1 }` 로 전량 재계산 실증.
Qradar 의 등급에 **입력원이 생겼다.**

핵심 설계
- 집계는 **CF `onReviewWritten` 전담** — `stores` update 화이트리스트에 `averageScore`/`reviewCount` 가 없어 클라이언트 집계가 **구조적으로 불가능**하다. Rules 완화는 점주의 자기 평점 조작을 허용하므로 기각.
- `increment` 가 아니라 **`count()` + `sum('score')` 전량 재계산** → 멱등 + 시드 오염 자기 치유 + 집계 보정 로직 불필요.
- 문서 ID `{storeId}_{userId}` → **1인 1매장 1표**. `{orderId}` 안은 소액 반복 주문으로 등급을 살 수 있어 기각.
- 리뷰 0건은 `C급 (-)` 이 아니라 **`미평가`**.
- `stores.grade` 는 Firestore 에서 읽히지 않는 **파생 필드**다 (`store_model.dart:186`).

배포 필요: `firestore:rules,firestore:indexes` + `functions:onReviewWritten` + Console 시드 리셋(A5)

2차 범위 R1~R8 은 spec 참조 (삭제 UI / 내가 쓴 평가 / 점주 답글 / 신고·금칙어 / 베이지안 정렬 보정 / 사진 리뷰 / grade 영속화 / 페이지네이션).

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
