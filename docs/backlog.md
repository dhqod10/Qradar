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

### ✅ `stores.delete` 정책 재설계 (Q3 수용의 대가 — 2026-10-22 신규) — **payment_server_authority 로 구현 (코드 완료, 배포 ⑧ 후 확정)**

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

### ✅ 결제 시점 매장 `status` 게이트 — **별도 task 로 분리 확정 (Q-S1)** (2026-10-22 신규) — **payment_server_authority 로 구현 (코드 완료, 배포 ⑥ 후 확정)**

> **`status == 'approved'` 를 그대로 강제하면 안 된다.** 사용자가 "고객 앱에서 안 보이는데 결제가 되는
> 경우의 수가 있나" 를 물어 경우를 열거하다 찾은 제약이다.
>
> `StoreModel.toFirestoreForCoreUpdate` (`lib/data/models/store_model.dart:271`) 가
> `'status': pending` 을 쓴다. 즉 **영업 중인 승인 매장이 이름·주소·전화·설명·카테고리 같은 핵심
> 필드를 수정하면 `status` 가 `pending` 으로 회귀**한다(T3 재제출 흐름). 그 동안 매장은 고객 목록에서
> 사라지지만, **이미 메뉴를 열어 장바구니를 채우고 결제 화면까지 간 고객은 그대로 결제한다.**
> callable 직접 호출 같은 우회가 아니라 평범한 흐름이다. admin 이 반려·정지시킨 직후도 같다.
>
> 그래서 결제에서 `approved` 를 강제하면 **점주가 전화번호 한 줄 고치는 순간 정상 손님의 결제가
> 거부된다.** "돈이 멈추는 방향" 위험이 가설이 아니라 점주의 일상 동작이었다.
>
> 설계는 `approved` 검사가 아니어야 한다. 후보: ⓐ `rejected` 만 막는다 ⓑ 한 번 `approved` 였던
> 매장은 `pending` 회귀 중에도 결제를 허용한다(승인 이력 필드 필요) ⓒ 핵심 필드 수정을 `pending`
> 회귀와 분리한다(그러면 심사 의미가 바뀌므로 `entity_lifecycle.md` 재검토가 따라온다).
> **어느 안이든 "영업 중 매장이 정보를 고치는 동안 결제가 막히지 않는다" 를 불변식으로 두고 시작한다.**



`verifyTossPayment` 가 `stores` 를 **전혀 읽지 않는다**(grep 0). 적립 트리거도 `status` 를 보지 않는다. 따라서 `pending`(미승인 / 재제출 중) 매장도 **callable 직접 호출로 결제가 성립**하고 그 주문은 적립된다. **UI 에서만 막힌다.**

- 걸리는 결정: `qoin_accrual_rate_hierarchy/spec.md` §20.5.6 **#13**(점주의 `stores.delete` → 같은 ID 재생성, 사용자 결정 Q3)의 수용 근거가 "재승인 전까지 주문·적립 불가" 였는데 **서버 보증이 아니다**. 근거를 §21.5 에서 교체했다 (실행에 점주 본인의 SDK 조작이 필요하고, 금액 상한은 브랜드/전역 요율이며, 재승인 요청이 admin 화면에 다시 올라온다).
- 잔여 위험: **적립이 중단된 매장의 점주가 삭제·재생성으로 중단 상태를 지우고 미승인 상태에서 결제를 태워 적립을 재개**할 수 있다.
- 넣을 때의 위험: 결제 거부는 **돈이 멈추는 방향**이다. 매장 `status` 데이터가 한 건이라도 틀어져 있으면 정상 결제가 막힌다.
- 설계자 추천: **별도 task.** 1차 결제부터 있던 Qoin 무관 구멍이고, 계층화 배포 창(Rules·CF·앱·마이그레이션)에 결제 경로를 같이 넣으면 실패 시 원인 분리가 어렵다.
- 참조: `docs/tasks/brand_authorization_hardening/spec.md` §9 · `docs/processes/data_ownership.md` §2.5

---

### ✅ `brands` 문서 read 범위 축소 / `brandKey` 비공개화 (2026-10-22 신규) — **payment_server_authority 로 구현 (코드 완료, 배포 ⑧⑨ 후 확정)**

`match /brands/{brandId} { allow read: if isSignedIn(); }` — 로그인한 누구나 **모든 브랜드의 `brandKey`** 와 `companyName` / `businessRegistrationNumber` / `representativeName` / `contactPhone` / `headOfficeAddress` 를 읽는다.

- **`brandKey` 가 비밀이 아니므로 가맹 신청의 "열쇠" 가 열쇠로 기능하지 않는다.** 점주가 brandKey 를 알고 있다는 사실은 어떤 권한 근거도 되지 못하고, 그래서 매장 create 의 `brandId` 자가 지정을 Rules 로 증명할 수 없다 (`brand_authorization_hardening/spec.md` D5 — 승인 게이트가 유일한 실질 통제).
- 함께 고쳐야 하는 것: 고객 화면의 브랜드 표시 · 점주 매장 등록 폼의 brandKey 조회(`findByBrandKey`) · 브랜드 정보 화면의 brandKey read-only 노출 · `BrandScopeBadge`. 공개 필드와 비공개 필드를 나누거나(공개 서브문서) brandKey 조회를 CF 로 옮긴다.
- 사업자번호·대표자명 공개는 그 자체로 별개 문제다.

---

### ⬜ admin 의 `users.brandId` 교정 화면 (2026-10-22 신규)

`brandId` 를 CF 전담으로 옮기면서 **본인 교정을 의도적으로 막았다**(`brand_authorization_hardening/spec.md` D4). 잘못 연결된 계정의 교정 경로는 지금 **Firebase Console 수동 편집**뿐이다.

- 그래서 교정 행위에 이력이 남지 않는다 (같은 spec §6-2 에서 수용, 사유 명시).
- 화면을 만들 때는 CF + `users/{uid}/roleHistory` 1건을 같은 트랜잭션에 둔다.
- 함께: `users.role` 변경 이력 전반(`audit_trail.md` A4) — `brandId` 조각만 구현됐다.

---

### ⬜ 중단(partial) 표면 인벤토리를 다른 기능으로 확장 (2026-10-22 신규)

`qoin_accrual_rate_hierarchy/spec.md` §21.7 에서 확정한 규칙 — **"한 사실에는 하나의 판정 함수 + 표면 인벤토리 표 + grep 가드"** — 는 Qoin 중단 상태에만 적용됐다. 같은 종류의 "여러 화면이 같은 사실을 서로 다른 출처로 판정" 후보가 남아 있다.

- 후보: 매장/브랜드 **승인 상태**(`status` + `approvedBy`/`rejectedReason` 조합을 여러 화면이 각자 해석), 주문 상태 배지, 전역 비상 정지 표시(고객·점주·admin 3화면).
- 적용 순서: 표면 인벤토리 표를 먼저 만들고(ⓐ 판정 출처 ⓑ **출처 읽기 실패 시 보이는 것** ⓒ 복구 동작), 판정 함수로 모으고, grep 가드를 추가한다.
- `docs/agents/tester_guide.md` 체크리스트에 "같은 사실을 말하는 표면을 전수 열거했는가" 상시 항목 추가 (이번 분배에 포함).

---

### 🔮 UI 전면 개편 (모든 기능 개발 완료 후 — 2026-10-22 사용자 의사)

사용자가 **전반적인 디자인 변경**을 계획하고 있으며, **기능 개발이 전부 끝난 뒤** 착수한다.
지금 하면 같은 화면을 두 번 작업하게 되므로 미룬다.

#### 플랫폼 분화 검토 (개편 때 함께 — 2026-10-28 논의)

운영 단계에서는 역할별로 제공 채널을 나누는 것이 업계 표준이다. 이 개편 시점에 함께 검토한다.
- **관리자(admin)** → 웹 백오피스로 분리 (정산·통계·회원/신고 등 대량 작업은 모바일 비효율, 보안상 소셜 로그인 배제·이메일/SSO 통제)
- **점주(owner)** → 주문 접수는 앱/태블릿 유지(실시간 FCM·알림음 필요), 메뉴/정산/통계 관리는 웹 추가
- **브랜드(본사)** → 가맹점·마스터 메뉴·정산 관리 성격상 웹이 적합
- **고객(customer)** → 앱 중심 유지
- 💡 Flutter 웹 빌드로 기존 Owner/Brand/Admin Scaffold 재활용 가능(전면 재작성 아님). 단 ⓐ 웹 FCM 푸시 제약 → 실시간 접수는 앱/태블릿에 남김, ⓑ 반응형 레이아웃 보강 필요.

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

### F8 (home_search) → payment_server_authority 로 흡수
`home_search` 의 F8(장바구니·결제 품절 검증)은 `docs/tasks/payment_server_authority/` 의 G2 로 흡수됐다 (`home_search/spec.md:1229` 의 "backlog 에 F8 등재" 완료 기준은 이 1행으로 대체 이행). 아래 F8 은 sub-phase 8/7 의 별개 항목(admin 분포 모니터링)이다.

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

---

### ⬜ 계층화 배포 후 잔여 (2026-10-22, 3차 검증 후)

배포를 막지 않는다고 판정해 남긴 것들이다.

- **F-1 서버 측 정밀화** — `staleScan` 가드의 전제("종결 포인터 = 끝까지 마쳤다")는 overwrite
  완료에만 참이다. preserve 완료·단건·스위치로 생긴 종결 포인터 뒤에 같은 값으로 덮어쓰기를
  하면 개별 설정이 남아 있어도 가드가 발동한다(경쟁 상황에서만, 3000매장 50~200ms 간격으로
  재현됨). 화면이 "다시 시도해 달라" 로 구분해 말하는 쪽만 했다. 서버에서 구분하려면 포인터에
  "overwrite 로 끝났는가" 가 필요하다. 돈 영향 없고 재시도로 해소된다.
- **실기기 `FirebaseFunctionsException.details`** — 에뮬레이터에서는 `Map` 으로 오지만 실기기
  확인이 안 됐다. CF 가 message 끝에 `[reason]` 토큰을 함께 실어 이중 장치를 뒀으므로 실패해도
  분류는 된다. 배포 후 라이브에서 확인한다.
- **구버전 앱 + 신 CF 가 섞인 구간** — 배포 순서상 ②~③ 사이다. implementation C8-4 에 분석이
  있으나 실측은 안 했다.
- **운영 인덱스 동작** — 배포 전에는 확인할 수 없다. 런북 ① 참조.

---

### ✅ 브랜드 등록 폼 — 로고 필수 표시 + 빠진 항목 지목 (2026-10-26 수정)

`brand_info_form_page.dart:56` 의 `_canSubmit` 이 로고를 요구한다.

```dart
bool get _canSubmit =>
    (_logoFile != null || (_logoUrl != null && _logoUrl!.isNotEmpty)) && ...
```

그런데 `_sectionLabel('브랜드 로고')` 에는 **`*` 가 없다.** 다른 필수 항목(`회사명 *`,
`담당자 이름 *`, `담당자 연락처 *`)에는 전부 붙어 있어서, 로고만 빠진 것이 더 헷갈린다.

누르면 `필수 항목을 모두 올바르게 입력해주세요` SnackBar 가 뜨지만 **어느 항목인지 말하지
않는다.** 다른 필수 항목을 다 채운 상태였기에 사용자 입장에서는 "다 채웠는데 왜 안 되지" 가
된다. 실제로 라이브 검증 중에 이 지점에서 막혔다.

고칠 것: 로고 라벨에 `*` 추가, 그리고 SnackBar 가 **빠진 항목을 지목**하게 한다.
(`changed:false` 를 화면이 소비하게 한 것과 같은 성격 — "아무 일도 안 일어났다" 를 설명 없이
두지 않는다.)

### ✅ 적립률 화면 조사 오류 (2026-10-26 수정 — `KoreanParticle`)

`지금 적용되는 값` 블록이 `브랜드은 설정 없음` 으로 출력된다. `브랜드는` 이 맞다.
스코프 이름을 문장에 끼워 넣을 때 받침 유무로 조사를 고르지 않는다.

---

### ✅ 묶음 제안 — "서버가 권위를 갖는가" 3건 (2026-10-26) — **`docs/tasks/payment_server_authority/` 로 착수·구현 (배포 대기)**

아래 셋은 **같은 질문**의 다른 얼굴이다. 따로 하면 Rules 를 세 번 배포해야 하고,
Rules 배포는 앱 배포와 순서를 맞춰야 해서(런북 ③→④) 한 번이 훨씬 싸다.

| 과제 | 지금 상태 |
|---|---|
| 결제 시점 매장 `status` 게이트 | 서버가 매장 상태를 전혀 보지 않는다 |
| `brands` read 범위 축소 / `brandKey` 비공개화 | 열쇠가 공개라 권한 근거가 되지 못한다 |
| `stores.delete` 정책 재설계 | 점주가 지우면 하위 데이터가 고아로 남는다 |

**언제 할 것인가 — 실결제가 돌기 전.** 지금은 실결제 0회라 결제 경로를 건드려도
영향받는 주문이 없다. 손님이 돌기 시작하면 난이도가 달라진다 — 잘못 막으면 그
순간 매출이 멈추고 테스트 창도 좁아진다.

**반면 지금 당장 급하지는 않다.** 악용하려면 앱을 우회해 CF 를 직접 호출하고
**자기 돈으로 실제 결제까지** 해야 한다. 동기가 있는 것은 사실상 미승인 매장의
점주 본인뿐이다.

**설계 시 공통 원칙** — 검사와 실행이 **같은 원자적 경계 안**에 있어야 한다.
검사 후 실행 사이에 상태가 바뀌면 같은 구멍이 난다. 일괄 적용의 S3(스캔이
트랜잭션 밖이라 낡은 값을 믿었다)이 정확히 그 틈이었다.

권장 순서: 홈 검색 → **이 묶음** → APNs → 출시 준비 → UI 전면 개편.

---

### ⬜ 매장 목록 100건 절단 — **승인 매장 80곳에서 착수** (2026-10-26, home_search D7)

`StoreRemoteDataSource.fetchAll` 이 `orderBy('averageScore', desc).limit(100)` 이다.
홈·주문탭·검색이 **모두 이 100건 스냅샷을 공유**하므로, 승인 매장이 101곳이 되는
순간 평점 하위가 **세 화면 전부에서 사라진다.** 서버에는 있는데 화면에만 없다.

**하필 잘리는 것이 신규 매장이다.** 새로 승인된 매장은 `reviewCount == 0` →
`averageScore == 0` 이라 정렬 맨 아래, 절단선 바로 밑이다. 점주 입장에서는
"승인됐다는데 앱에 안 뜬다" 가 된다.

지금은 매장 7곳이라 드러나지 않는다. **트리거: 승인 매장 80곳**(여유를 둔 숫자).

**고칠 때의 기본안 — "검색만 더 보이게" 가 아니라 애초에 안 자른다.**
`where('status','==','approved')` + limit 상향. 홈 화면에 보여주는 개수는 그대로고
바닥 데이터만 온전해진다. **복합 인덱스 신규 배포가 필요**하므로 인덱스를 먼저
올리고 앱을 나중에 올리는 순서를 지킨다(deploy_runbook ① → ③).

**그다음 단계(매장 수백~수천)** 에서야 "홈은 일부만 받고 검색은 서버가 전체에서
찾는" 구조로 간다. 그때는 클라이언트 필터링을 버리는 결정이므로 별도 task 다.

---

## Follow-up (home_search 검증 후 — 사용자 결정 필요)

### B-1. 앱 전역 Riverpod 자동 재시도 정책 — **후속 확정 (2026-10-26 사용자 결정)**

> **결정: (c) 현행 유지 + home_search 범위만 적용.** 재시도가 도움이 되는 화면이
> 따로 있고(일시적 네트워크 끊김에서 자동 복구), 전역으로 끄면 지하철에서 잠깐
> 끊기는 정도에도 에러 화면이 떠서 다시 비는 것이 사용자 몫이 된다. 일괄 변경은
> Qoin 화면들의 "skeleton → 에러" 전환 시점을 전부 재검증해야 하는 비용도 있다.
> **다만 지금 상태에서는 검색·홈을 제외한 모든 화면의 에러가 약 38초 늦게 뜬다.**
> 지난 사이클에 "에러를 조용히 숨기지 말자" 며 만든 Qoin 화면들도 그 영향을 받는다.
> 재개 시점: 사용자 불편 신고가 생기거나, 화면군별 정책을 정할 여유가 생겼을 때.


- **현상**: Riverpod 3.3.1 기본값은 예외 10회·약 38초(200ms 시작 2배, 상한 6.4s). 읽기가 실패해도 그동안 사용자는 정상 로딩(skeleton)만 본다. 홈, 지난 사이클의 Qoin 화면(허브 partial 배너 / 이력 / 링크 점검) 등 `FutureProvider`/`StreamProvider` 전반에 해당한다.
- **home_search 에서 한 것**: `storeSnapshotProvider` / `menuSearchIndexProvider` 두 곳만 `retry: searchReadRetry`(일시 오류 1회, 0.8초 뒤, 권한 거부는 재시도 없음).
- **전역으로 가지 않은 이유**: ① 38초 안에 자동 복구되던 일시 네트워크 오류를 포기하는 trade-off 가 화면마다 다르다(결제·주문·Qoin 은 재시도가 유용할 수 있다). ② Qoin 화면들은 `skeleton -> 에러` 전환 시점이 이미 검증된 상태라 일괄 변경 시 재검증 범위가 크다. ③ 제품 판단(사용자에게 에러를 얼마나 빨리 보일 것인가)이 필요하다.
- **선택지**: (a) `ProviderScope(retry: …)` 전역 기본값을 `searchReadRetry` 와 같은 "1회 + 권한거부 즉시 실패" 로 (b) 화면군별 적용(Qoin 먼저) (c) 현행 유지.
- **검증 방법**: 이번에 만든 `test/presentation/home_search_real_graph_test.dart` 의 재시도 테스트 패턴(실제 provider + 실제 타이머, override 로 에러 주입 금지)을 재사용한다.

### B-2. 전역 선택 상태 누수

- `selectedMainCategoryProvider` / `selectedSubCategoryIdProvider` 가 전역이라 검색이 아닌 진입(홈·주문 탭)에서는 이전 매장의 선택이 새어 들어간다. 검색 경로는 화면이 바꾼 경우에만 되돌린다. 근본 해결은 family 화 또는 화면 스코프화.

---

### ⬜ 검색 1단계 비용 — 가맹점이 늘면 매장 문서 요약 필드로 전환 (2026-10-26, home_search 2차 D10)

**지금 구조**: 1단계가 메뉴 출처를 매장별로 읽는다.
- 브랜드 마스터(`brands/{id}/menuItems`)는 **공유**된다 — 한 브랜드에 매장 20곳이 있어도 1쿼리
- 점포 한정(`stores/{id}/menuItems`)은 **공유되지 않는다** — 매장마다 1쿼리

후보 30곳이 가맹점으로 꽉 차면 1단계가 17 → 32 쿼리가 된다. **지금은 가맹점이 2곳이라
+2 쿼리이고 사실상 공짜다.** 그래서 점포 한정 메뉴를 검색 범위에 포함했다(사용자 결정) —
"파는데 검색에 안 나온다" 를 설명할 수 없기 때문이다.

**전환 트리거: 가맹점(= `brandId != null` 인 승인 매장) 20곳.**
그 시점에 첫 검색 쿼리가 체감될 만큼 늘어난다.

**전환 방법 — 매장 문서에 메뉴 이름 요약 필드를 둔다.**
```
stores/{storeId}
  menuKeywords: ["시그니처아메리카노", "하우스라떼", …]   ← CF 가 유지
```
매장 문서는 홈 스냅샷에 **이미 들어 있으므로 추가 쿼리가 0** 이 된다. 가맹점이 100곳이어도
1단계 비용이 늘지 않는다.

**대가**: 쓰기 쪽 비용이 생긴다. 메뉴 변경 시 CF 가 매장 문서를 갱신해야 하고, **브랜드
마스터를 고치면 산하 매장 전부**를 갱신해야 한다(fan-out). 갱신이 늦으면 검색 결과가 잠깐
낡는다. 읽기가 쓰기보다 훨씬 잦으므로 보통 이득인 거래지만 공짜는 아니다.

**그 위 단계**: 매장 수백~수천이면 요약 필드로도 부족하고 검색을 서버로 분리한다
(`home_search/spec.md` 의 비범위, 외부 검색 엔진). 단계마다 **이전 단계가 깨질 때** 넘어간다.


---

### ⬜ payment_server_authority 후속 (2026-10-27 신규) — ID 는 기존 N1(알림 테스트)과 충돌하지 않게 `PSA-` 접두

| # | 과제 | 근거 |
|---|---|---|
| ✅ ~~**PSA-N1**~~ | **(코드 완료 2026-10-27, 배포 대기 — `payment_price_authority`)** ~~서버 가격 재계산~~ — 클라이언트가 보낸 가격이 그대로 주문·적립 기준이 된다. `verifyTossPayment` 의 금액 검증(`amount === cart.totalPrice`)은 클라 값끼리의 비교라 의미가 없다 | spec §5-6. **Q6 ⓑ — 이번 묶음 직후 최우선.** 게이트(`paymentGate.ts evaluatePaymentGate`)가 이미 `resolved[].merged.basePrice`(마스터 + override 적용 단가) 를 반환한다 → **추가 읽기 0** 으로 닫을 수 있다. 실결제 0회라는 착수 창이 동일하게 적용된다 |
| PSA-N2 | 핵심 필드 수정을 `pending` 회귀와 분리 (심사 정책) | spec §6.2 ⓒ. "이름 고치면 고객 목록에서 사라진다" 기존 결함 포함 |
| PSA-N3 | 매장 `status` 전이 이력 (승인/반려) + `rejectedReason` 덮어쓰기 | spec §9-주의 |
| PSA-N4 | 매장 폐업 신청 흐름 / 소프트 삭제 (점주 공백 해소) | spec §11.1 ⓒ |
| PSA-N5 | `quick_reorder_section` 의 단가 역산 제거 — **우선도 낮춤 (payment_price_authority §11)** | **돈 경로는 체크아웃 재가격이 덮었다** — 역산으로 담긴 옛 단가는 카트 진입·결제 탭에서 현재 문서 가격으로 교정되고 배너가 알린다. 남은 것은 홈 화면이 옛 가격을 **표시**하는 정확성뿐이다. `lineTotal ~/ quantity` 는 가드(`payment_price_guard_test` 7)의 허용 목록 1건으로 남아 있다 |
| PSA-N6 | **`temporaryClosed` 가 아무 일도 하지 않는다** — 점주 스위치가 고객·CF 어디에도 효과가 없다. 할 때는 고객 노출·결제 게이트·점주 표시를 **한 번에** | spec §6.8 |

---

### ⬜ payment_price_authority 후속 (2026-10-27 신규) — 선행 PSA-N1 을 닫으며 등재

| # | 과제 | 근거 |
|---|---|---|
| **PPA-P1** | **서버 견적(quote) 발급** — 시점 차이를 구조적으로 제거(고객이 본 금액이 서버가 보증한 금액). 새 CF + 상태 + 만료 + 멱등 | Q2 ⓑ. 지금은 거절 + 재가격 복구로 창을 "체크아웃 진입 ~ confirm" 으로 줄였다. **`paymentGateRejections.detail.delta` 분포(양·음 양방향의 작은 금액 = 시점 차이)로 빈도를 측정한 뒤** 필요를 판단 |
| **PPA-P2** | **가격 승인 정책의 일관화 — store-scope 옵션 가격 + 옵션 비활성으로 단가 유도 (test_report H-02 묶음)** | Q8 ⓐ/ⓒ. ⓐ 가맹점주가 승인 없이 옵션 `priceDelta` 를 바꾸는 우회로를 서버가 공인한다. ⓑ **같은 뿌리**: 점주 운영 필드(`disabledOptionItemIds`/`disabledOptionGroupIds`)로 필수 `single` 그룹의 저가 선택지를 끄면 선택 가능한 것이 고가 하나뿐이 되어 승인 없이 단가를 바꾼다(`validateSelection` 직접 호출로 확인; 서버·UI 일치, 고객은 선택지를 본다). 결제 정합 결함이 아니라 **가격 승인 정책**이다 — spec §463 이 `disabled*` 를 운영 필드로 허용했으므로 설계자 판단. 착수 근거 = 감사 도구 ⓒ 의 참조 건수(`storePairs`) + 옵션 비활성 건수(현재 도구는 후자를 세지 않는다 — 착수 시 추가). **코드는 아직 건드리지 않았다** |
| PPA-P3 | 주문 문서의 **이름·옵션 라벨도 서버가 구성** | Q4 ⓑ. 지금은 금액 필드만 서버 값 |
| PPA-P4 | **Tier 2 소급 감사** (과거 주문 단가를 `priceHistory` 와 대조) | spec §12-1. `priceHistory` 가 쌓인 뒤에만 의미가 있다 |
| PPA-P5 | Rules 에 금액 필드 **타입·범위 제약** (`basePrice >= 0`, `priceDelta` 정수 등) | spec §13-7. 현재 Rules 에 타입 제약이 전무하다 — Dart/TS 파싱이 갈리는 `0.5` 같은 입력은 R10 이 파서 쪽에서 막았을 뿐 |
| PPA-P6 | 비활성 키 `{groupId}_{itemId}` 를 **쓰는** 화면 3곳(브랜드 옵션 선택기 · 점주/브랜드 비활성 시트)이 형식을 직접 조립한다 — 가드 허용 목록 | payment_price_authority 구현 중 발견. 판정(읽기)은 `option_availability.dart` 1곳이지만 쓰기 쪽이 같은 형식을 따로 만든다. 한 헬퍼로 모으면 가드의 예외가 사라진다 |
| PPA-P7 | **옵션 선택 중복(`duplicate`) 은 spec 의 6종 밖에서 구현자가 추가한 7번째 위반이다** | 음수 `priceDelta` 를 같은 항목으로 반복 선택하면 가격이 깎인다(`multi` 그룹). 설계자 확인 요청 — implementation.md §작업표와 현실의 차이 |
| **PPA-P8** | **금액 게이트 실 어댑터 경로의 에뮬레이터 하네스화 (test_report F-03)** | 단위 테스트가 `fakeReader` 만 써서 scope 경로(master/brand/store)·`storeBrandId` null·`MAX_LINE_QUANTITY` 경계 변이가 생존한다. **코드는 맞다 — tester 가 실 Firestore 로 12건(3 scope 옵션·승인 override·W2·모드 조합) 일회성 확인했다.** 하네스(Firestore 에뮬레이터 + `makeFirestoreGateReader`)는 후속 — 이번 batch 에서 만들지 않았다 |

## 카테고리 / 검색 (2026-10-28 테스트 중 논의 확정)

### ⬜ 검색 동의어(synonym) 레이어 — 세밀 검색
유저 어휘 다양성("탄산"으로 "에이드" 찾기)은 카테고리 중앙화로 풀리지 않는다. 메뉴명 검색(이미 있음, `docs/tasks/home_search`)에 **동의어 확장 레이어**를 얹어야 풀린다 (Uber Eats query-understanding + cuisine synonym 방식). **별도 과제**로 분리.
- **왜:** admin이 카테고리를 "에이드"로 정해도 유저는 "탄산"이라 칠 수 있음 → 카테고리 체계만으로 미해결. 매장-교차 세밀 검색이 필요해질 때 착수.

### ✅ 카테고리 소유권 정책 — 확정 (변경 없음 + opt-out 신규)
- **메인 카테고리 = admin 전용** (현행 유지). 브랜드/가맹점은 메뉴 등록 시 선택만. admin이 `mainCategories` 에 추가로 세분화 가능.
- **서브 카테고리 = 브랜드/가맹점 관리** (현행 유지, 중앙화 **안 함**). 근거: "매장 내 메뉴 구성(display)" 레이어 — 매장-교차 검색 미사용. 업계 표준(POS 메뉴 섹션은 가맹점 자율). 브랜드 내 일관성은 brand-scoped subCategories 공유로 보장.
- **매장별 카테고리 opt-out = 신규** → `store_category_optout` 과제 (점주가 매장별 메인 카테고리 on/off, 즉시 반영). 검색도 메인 카테고리로 통일 + 오염된 `stores.menuCategories` 폐기.

### ⬜ 이미지 fit 정책 — 로고는 contain (일부 반영됨)
`ImageUploadField` 에 `fit` 파라미터 추가 완료, 브랜드 로고 폼은 `BoxFit.contain` 적용(2026-10-28). 브랜드 로고를 **표시**하는 다른 화면(brand_info_page / admin 승인 상세 / 매장 카드 등)이 cover로 로고를 잘라 보이면 동일하게 contain 정렬 검토.

## Qoin / 자기거래 (2026-10-29 테스트 중 질문에서 도출)

### ⬜ Q2 — Qoin 사용(결제/할인) 기능 미구현
현재 Qoin 은 **적립 전용(earn-only)**. 원장 `users/{uid}/qoinTransactions` 는 CF 전담 쓰기이고 관측 type 은 `earn`(+ 환불 회수/clawback). **`spend`/`use`/`redeem`/차감/할인 로직이 코드에 없다**(lib/·functions/src 전체 검색). 장바구니·결제 화면에 Qoin 사용 UI 없음, `qoinBalance` 는 조회만.
- **왜:** 적립한 Qoin 을 쓸 경로가 없으면 적립의 효용이 반감. 운영 전/초기에 "Qoin 결제·부분할인" UX + 서버 차감(원장 `spend` 트랜잭션, 멱등, 잔액 음수 방지, 결제 게이트와 정합) 설계 필요.
- **착수 시 주의:** 차감은 반드시 CF 전담(클라이언트 금액 신뢰 금지), 결제 금액 재계산 게이트(PPA)와 한 경로로 묶기.

### ⬜ Q3 — 자기 매장 주문/접수 가드 없음 (self-dealing)
`userId == store.ownerId` 를 막는 체크가 **order 생성(verifyTossPayment CF)·Firestore Rules 양쪽에 없다**. "고객 모드로 전환"은 role 을 실제 customer 로 다운그레이드(`downgradeToCustomerUseCase`)하지만 매장 `ownerId` 는 유지되므로, 점주가 **고객 모드 전환 → 자기 매장 주문·결제 → 점주 복귀 → 접수·완료**가 전부 가능하고 완료 시 **Qoin 자기적립**까지 된다. 리뷰도 `storeId_userId` 라 자기 매장 평가 가능.
- **영향:** 실제 Toss 결제가 들어가 직접 금전 이득은 제한적이나, **매출·평가(등급) 조작**과 Qoin 파밍 수단. Qradar 등급 신뢰도의 근간을 흔든다.
- **후보 조치:** ⓐ `verifyTossPayment` 에서 `userId == store.ownerId`(및 브랜드 보유자) 주문 거절. ⓑ 자기 매장 리뷰 차단(review create 가드). ⓒ Qoin 적립 시 self-order 제외. — 설계자 판단 후 범위 결정.

### 📌 Q3 결정 (2026-10-29) — 런칭 전 / 층 구조로 접근

논의 결론:
- **Q3(Layer 1: `주문자 uid == store.ownerId` 또는 브랜드 보유자 매칭 가드)는 공개 런칭 직전으로 미룸.** 비공개 테스트 단계라 실제 어뷰징 유인이 없고, Layer 1만 넣으면 "막은 듯한 착각"만 줄 수 있음. 착수 시 세트: `verifyTossPayment` 결제 거절(Toss 미청구) + 자기 매장 리뷰 차단 + Qoin 자기적립 제외. 런칭 로드맵에 Layer 2와 묶어 반영.
- **한계(명시)**: ownerId 매칭은 **같은 계정 / "고객 모드 전환" 경로만** 막는다. **부계정(다른 uid) 우회는 Layer 1으로 못 막음**(sock-puppet). 단 부계정도 매 주문 실제 Toss 결제 수수료를 손해보므로 "공짜 파밍"은 아니며, 실질 위험은 **리뷰/등급 조작**.
- **Layer 2 (탐지) = 프로젝트급**: 기기 ID / 카드 지문(해시) / IP 수집 → 룰 기반 플래그 → **수동 검토**. 어려움의 본질은 코드가 아니라 **지문 신뢰도·오탐 튜닝·운영 워크플로우(admin 검토 UI)·프라이버시/법무**. 공개 런칭 로드맵 항목.
  - **선행 저비용 액션(권장)**: 탐지는 과거 데이터가 있어야 작동 → 공개 전 **신호 수집(order 문서에 기기/카드해시/IP 저장)만 미리 켜두기**. 저장은 저렴, 나중에 "분석할 데이터 없음" 방지.
- **리뷰 무결성 (별도·더 저렴한 레버)**: 자기거래의 주 피해는 리뷰/등급 조작인데, 지문 없이도 "리뷰 = 완료 주문에서만 / 매장당 1인 1리뷰 / 신규계정 가중치 감쇠" 류 규칙으로 상당 부분 완화 가능. → **현재 리뷰 생성 규칙 점검** 후보(Layer 2보다 선행 가치).

## 결제 UX / 서버 게이트 (2026-10-29 X-01 G 테스트 중 발견)

### ⬜ 품절 메뉴 포함 시 "결제하기" 무반응 (피드백 부재)
장바구니에 품절(soldOut) 메뉴가 담긴 상태에서 "결제하기"를 누르면 **아무 반응도 없다**(결제 진행이 막히는 것은 맞지만 사용자에게 안내가 없음). 토스트/스낵바/다이얼로그로 "품절 메뉴를 빼고 결제해 주세요" 같은 **알림을 띄워야 한다**.
- **왜:** 사용자는 버튼이 고장난 줄 안다. 클라이언트 가드(품절 차단)는 동작하지만 피드백이 없어 UX 결함.
- 관측: 2026-10-29 G-02 라이브. 상단 경고 배너 + 아이템 "품절" 뱃지는 뜨지만, 결제하기 탭 자체는 silent no-op.

### ℹ️ 서버 결제 게이트(G-01~G-04) 검증 메모 — 라이브 트리거 불가
라이브 클라이언트가 장바구니/결제 단계에서 메뉴·매장 상태를 **실시간 재검증**해 서버 게이트 도달 전에 막는다(정상 설계). 따라서 서버 게이트(SOLD_OUT/PRICE_MISMATCH/매장상태/OPTION_UNAVAILABLE)는 정상 클라이언트로는 트리거되지 않는다 — "구버전·조작·stale 클라이언트" 백스톱용. 라이브 검증은 **결제 진행 중(Toss 화면) 상태를 틀어야만** 가능(타이밍). 이번엔 코드 레벨(B)로 검증, 에뮬레이터 하네스는 PPA-P8 로 이관.

## 알림 / FCM (2026-10-29 알림테스트 중 발견)

### ⬜ FCM 토큰 재등록 갭 — onTokenRefresh 미구독 + 로그인 등록 silent 실패
FCM 토큰 등록은 **로그인 성공 시(auth_provider)** 와 **알림 설정 페이지 토글 시(notification_settings_page:115)** `registerFcmTokenUseCase.call(uid)` 로만 일어난다. 그런데:
1. `onTokenRefresh` 스트림이 데이터소스·리포지토리에 **노출만 돼 있고 어디서도 `.listen` 구독하지 않는다**(lib 전체 검색). 앱 실행 중 토큰이 로테이션되면 `users/{uid}.fcmToken` 이 갱신되지 않아 다음 로그인/설정방문 전까지 **푸시 유실**.
2. `registerFcmTokenUseCase` 는 `getToken()==null` 이면 silent 하게 미등록(정상 설계지만, 로그인 직후 getToken 이 아직 준비 안 됐을 때 null 반환 → 토큰 미등록인데 재시도 트리거 없음). 2026-10-29 테스트에서 재설치 후 로그인했는데 토큰이 빈 채로 남아, **알림 설정 페이지를 열어서야** 정상 토큰(`APA91b…`)이 등록됨.
- **영향:** 재설치/토큰 로테이션 사용자가 로그인만으로는 푸시를 못 받을 수 있다. onOrderStatusChanged 는 무효 토큰을 만나면 `fcmToken` 을 비우므로(정상), 이후 재등록 경로가 약하면 알림이 조용히 끊긴다.
- **후보 조치:** ⓐ 앱 시작/로그인 후 `onTokenRefresh` 구독 → `updateFcmToken`. ⓑ 로그인 시 register 가 null 이면 짧게 재시도(또는 FirebaseMessaging 초기화 완료 후 1회 재호출). ⓒ 홈 진입 시 토큰 존재 보장 체크.
- 관측: 2026-10-29 알림테스트. CF 로그 `[onOrderStatusChanged] Invalid FCM token — clearing`. 토큰 재등록 후 `accepted→making`·`making→ready` 푸시 정상 도착 확인.

## 리뷰 / 등급 무결성 (2026-10-29 점검)

### ✅ 리뷰 생성 규칙 — 이미 탄탄 (점검 결과, 조치 불필요)
- 매장당 **1인 1리뷰**: `reviews/{reviewId}`, reviewId = `{storeId}_{userId}` 강제(Rules).
- **완료 주문 한정**: `reviewOrderEligible` = 본문 orderId 의 주문이 `o.userId==uid && o.status=='completed' && o.storeId==d.storeId`. 실제 구매(완료) 없이는 리뷰 작성 불가.
- 등급↔점수 일치(`reviewGradeOk`), `createdAt==request.time`, 평균/카운트는 **CF(onReviewWritten) 전량 재계산 전담**(점주 조작 불가, stores 블록 미변경).
- 결론: 정직한 클라/같은 계정 경로는 막혀 있음. 남는 리뷰 어뷰징은 **부계정(sock-puppet) = Layer 2(탐지) 영역**(docs/backlog.md Q3 결정 참조).

### ⬜ 등급에 최소 리뷰 수 없음 — "리뷰 1개 = 즉시 S급" (설계 태스크로 분리)
`GradeCalculator.fromAverage(averageScore)` 는 **reviewCount 를 보지 않는다**. 임계값은 평균 점수만(S≥3.5 … ). 그래서 리뷰 1건(S, score=4)이면 평균 4.0 → **바로 S급**. "평가 부족/신규" 상태가 없음.
- **영향 1 (어뷰징)**: 완료주문 1건(자기/부계정) → S 리뷰 1개 → 즉시 S급. **등급 조작의 최단 경로**. 자기거래(Q3)의 주 피해(등급/리뷰 조작)와 직결 — 지문 없이 완화 가능한 가장 싼 레버.
- **영향 2 (신뢰성)**: 악의 없어도 n=1 로 S급은 통계적으로 신뢰 불가. 제품 신뢰도(등급=핵심 가치) 저하.
- **왜 "작은 가드"가 아니라 중간 태스크인가**:
  - `grade_calculator` 에 reviewCount 조건 + **StoreGrade 에 "미평가/평가부족" 개념 신설** 필요.
  - 등급 **표시 전반 파급**: `grade_badge`, `grade_filter_chips`, 매장 카드, 정렬, 홈/검색 등급 필터 — 미평가 매장을 필터·정렬·노출에서 어떻게 다룰지.
  - **제품 결정 필요**: 최소 N(예: 3건), 미달 시 표기(미평가/신규/숨김), 필터·정렬 처리.
- **착수 경로**: /architect 부터 (N·표시방식·필터정렬 정책 확정) → designer(배지/빈상태) → developer → tester.
- **선택적 defense-in-depth(부분적)**: reviews create Rules 에 `uid != store.ownerId`(및 브랜드 보유자) 자기리뷰 차단. Q3 주문 가드와 중복성 있고 부계정은 못 막음 — 우선순위 낮음.

## 웹 세션 인계 — 앱 영역 보안·정합성 8건 (2026-10-29)

전문: `docs/tasks/web_role_console/app_session_handoff.md` (줄번호는 firestore.rules 825줄 기준). 아래는 앱 세션(orderapp-1a) **검증 판정** 포함.

### ✅ [해결됨·구현+iOS검증 2026-10-30] 1. 카카오/네이버 토큰 audience(수신자) 미검증 — `functions/src/verifyKakaoToken.ts`, `verifyNaverToken.ts`
**→ `docs/tasks/social_login_audience/` 로 구현 완료.** 카카오=`access_token_info` app_id 대조(KAKAO_APP_ID), 네이버=code-exchange(플랜 B: `https://order-app-5957e.web.app/auth/naver.html` 중계페이지 → `qradar://auth/naver` bounce, 서버 client_secret 교환 + redirect_uri 화이트리스트). 앱 네이버 흐름 `flutter_naver_login`→`flutter_web_auth_2` 교체, client_secret 평문(strings.xml/Info.plist) 제거. **iOS 실기기 카카오·네이버 로그인 + 결제 딥링크 복귀 검증 완료. Android 검증 진행 중.** 운영수정: 네이버 secret 중복 입력(secrets:set 시 값이 두 번 이어붙어 저장됨) 재설정, iOS SceneDelegate `NidThirdPartyLogin` 잔여 import 제거. 아래는 원 분석(이력 보존):
accessToken으로 프로필 API(`kapi.kakao.com/v2/user/me`, `openapi.naver.com/v1/nid/me`) 호출 후 돌아온 id를 그대로 믿고 `kakao_<id>`/`naver_<id>` 커스텀토큰 발급. **토큰이 우리 앱에서 발급된 것인지(app_id/audience) 미검증**(코드 확인).
- **평가**: 실제 하드닝 갭. 단 카카오 user id는 앱별 스코프라 앱그룹 미공유 시 타 앱 토큰은 다른 uid로 매핑 → "특정 피해자 계정 직접 탈취"는 제한적. 네이버는 스코프 특성이 달라 더 노출 가능 → **제대로 된 보안 평가 필요**.
- **해법(인계 제시, 타당)**: 카카오 `/v1/user/access_token_info`로 app_id 검증 / 네이버는 서버가 authorization code를 직접 교환하는 흐름으로 전환.
- 수정 범위: CF 재설계(큼). 웹과 무관하게 앱 경로로 이미 열려 있음.
- **📌 계약 확정 (2026-10-29, 웹 교차영향 때문에 방향만 선결)**: 
  - **네이버 = authorization-code-exchange 로 전환 확정.** 클라(앱·웹)는 access token 대신 **인증 코드**를 CF 에 전달, CF 가 server-side 로 client_secret 교환(코드가 우리 앱 전용이라 audience 자연 보장). verifyNaverToken 입력 계약이 {accessToken} → {code(+state/redirect)} 로 바뀜. **웹 콘솔은 이 계약 위에 네이버 로그인을 구현**(재작업 방지). 
  - **카카오 = 계약 불변**. 클라는 access token 그대로, 서버가 `/v1/user/access_token_info` 로 **app_id 검증만 추가**(웹 영향 0).
  - **구현은 런칭 전**. 지금은 계약/방향만 확정.
  - **구현 시 메모 (웹 세션 피드백 반영)**:
    - ⚠️ **계정 동일성(되돌리기 어려움)**: uid=`naver_<id>`/`kakao_<id>` 를 앱/웹이 공유하려면 **기존 카카오 앱·네이버 애플리케이션에 '웹 플랫폼'을 추가**해야 함. **새 앱을 만들면 회원번호가 달라져 계정이 쪼개짐.** 개발자 콘솔 작업 시 반드시 기존 앱에 웹 추가.
    - **redirect_uri 화이트리스트**: 네이버 콘솔에 콘솔 주소(해시: `/console/index.html`, rewrite 후: `/console`) + 개발용 `localhost` 등록. **CF 는 클라가 보낸 redirect_uri 를 그대로 믿지 말고 서버 화이트리스트와 대조**(오픈 리다이렉트 방지).
    - **웹 측 방어(웹 세션 spec 기록)**: state 저장·대조(CSRF), code 1회용→소비 즉시 URL 제거, 로그인 실패 fail-closed. 카카오는 계약 불변이라 웹도 access token 그대로.
- **심각도 정정(2026-10-29)**: 웹 세션이 당초 🔴 "피해자 계정 직접 탈취"로 서술했으나, 카카오 회원번호가 앱 단위 스코프라 타 앱 토큰은 `kakao_<다른 id>`로 매핑돼 직접 탈취는 성립 안 함 → 양측 합의로 **⚠️(표준 하드닝)로 하향**. 남는 위험 4개: ① 공격자 앱이 Qradar 카카오 앱과 **같은 앱 그룹**이면 회원번호 공유로 성립(앱그룹 구성 미확인) ② **네이버 스코프 특성 상이 가능**(확인 필요) ③ 임의 외부 토큰으로 Firebase 계정 생성 가능한 엔드포인트 → **남용·할당량** 위험 ④ audience 검증은 소셜 로그인 백엔드 표준 요건.

### ✅ [해결됨·배포 2026-10-29] 2. Rules 브랜드 자기승인 — `firestore.rules` (brands/{id}/menuItems ~609, stores/*/menuOverrides 브랜드 분기 ~490)
`allow create,update,delete: if isAdmin() || isBrandHolder(brandId)` — **브랜드 분기에 필드 화이트리스트/onlyChangedFields 없음**. 브랜드 보유자가 `status='approved'` 직접 써서 자기 제출물 자가승인 가능. 승인 경계가 Rules 아닌 앱 리포지토리 `_assertAdminOnly`로만 집행(점주 분기만 onlyChangedFields로 좁음).
- **평가**: 명백한 권한 경계 구멍. 수정 저렴(브랜드 분기 필드 화이트리스트 추가). **우선순위 높음.**
- **해결**: `brand_self_approve_guard` (커밋 b87b548, rules 배포 완료). 헬퍼 noSelfApproveOnCreate/OnUpdate 로 V1 brands/menuItems + V2 stores/menuOverrides + **V3 stores/menuItems(추가 발견)** 브랜드 분기 자가승인 차단. 점주 분기(D2)는 별도 분리 등재.

### ✅ [해결됨 2026-10-29] 3. cascadeDeleteOverrides no-op — `master_menu_item_remote_data_source.dart`
"menuOverrides 컬렉션이 아직 없다" 전제가 낡음 → 마스터 삭제해도 오버라이드 잔존, 같은 id 재생성 시 과거 가격·제외·품절이 되살아남.

### ✅ [해결됨 2026-10-29] 4. 점주 오버라이드 create에 masterMenuItemId 누락 — `menu_override_repository_impl.dart`
브랜드 경로는 넣는데 점주 경로만 빠짐 → collectionGroup 쿼리가 점주 생성분 누락.
- **해결**: `menu_override_integrity` (커밋 예정). #4 = 점주 W2 create 에 `masterMenuItemId: override.masterMenuItemId` 1줄 추가(핵심 기능 버그). #3 = **실은 프로덕션 DI 가 override repo 를 항상 주입해 이미 실제 cascade 가 돌고 있었고**(no-op 은 미주입 폴백), 죽은 no-op 제거 + `deleteWithCascade` 단일경로 수렴 + repo non-null 전환(조용한 폴백 제거). 기존 menuOverrides 0건이라 **백필 불필요**(D-1). Rules/CF/인덱스 무변경.
- **후속 후보(별개)**: `countStoresUsingPriceOverride` 의 복합 [masterMenuItemId, status] 인덱스가 indexes.json 에 없음 — 기존 공백, menu_override_integrity 비범위. 실행 시 에러나면 인덱스 추가 task.

### ✅ [검증됨 — 문제 없음] 5. 품절 토글이 옵션 비활성을 덮어쓸 가능성 → 아님
인라인 품절 토글(`owner_store_menu_list_page.dart _toggleSoldOut`)은 두 경로 모두 `item.copyWith(soldOut:)` / `override.copyWith(soldOut:)` 로 **현재 항목에서 복사** → disabled*(옵션 비활성) 보존. 리포지토리(`menu_override_repository_impl.dart:169-194`)가 soldOut+disabled* 3필드를 함께 쓰지만 호출부가 **빈 배열이 아닌 현재값**을 넘기므로 덮어쓰기 없음. (이론상 좁은 stale-read 레이스만 존재 — 토글이 옵션을 날리는 버그 아님.)

### ✅ [해결됨 2026-10-29] 6. 브랜드 write 타임스탬프 왕복 의존 — `brand_update_partial_hardening`
브랜드 핵심필드 수정 경로가 `_dataSource.set(brandId, model.toFirestore())` 로 **전체 문서**를 보냄(createdAt/approvedAt 포함, copyWith 로 approvedBy/At 보존). Rules `isBrandSelfUpdate` 는 `diff().affectedKeys().hasAny(['brandKey','approvedBy','approvedAt','createdAt'])` 로 이 4개 변경을 금지. → **createdAt/approvedAt 가 read→entity→write 왕복에서 바이트 동일해야만 update 통과.**
- **현재 상태**: flutter test 통과 + 브랜드 수정이 동작한다면 현재 직렬화는 정확 왕복 중(깨진 상태 아님). 단 **brittle** — BrandModel 직렬화나 Timestamp 처리가 바뀌면 브랜드 정보 수정이 조용히 전면 거부될 수 있음.
- **견고한 수정(권고)**: 핵심필드 분기를 full `set` 대신 **부분 `update()`** 로 — 화이트리스트 필드(name/logoUrl/description/phone/address/businessHours/tags/companyName/status:pending/submittedBy/submittedAt/updatedAt)만 보내고 createdAt/approvedAt/brandKey 는 payload 에서 제외. 왕복 의존 제거. data 레이어 소규모. (logoUrl-only 분기는 이미 부분 update 라 안전 — 같은 패턴.)
- **해결(+확장)**: `brand_update_partial_hardening`. 동일 class 가 **브랜드 write 3경로**에 있었고, 배포된 brand_self_approve_guard rules 아래 "이미 승인된 걸 수정" 거부 **라이브 회귀**였음(웹 세션 approvedAt 왕복 지적에서 발견). 3경로 전부 payload 에서 approvedBy/approvedAt/createdAt 제거: ① brand_repository_impl 핵심정보(set→부분update) ② master_menu_item_repository_impl.updateMasterMenuItemCore ③ menu_override_repository_impl.upsertOverrideCore(set merge 유지, 승인메타만 제거). 클라 수정만 — rules 재배포 불필요. 반영은 다음 앱 빌드.

### ⚠️ [검증됨 — 경미/비긴급] 7. firebase_options 가 미등록(phantom) appId 를 가리킴
`firebase apps:list --project order-app-5957e` 실측 — 실제 등록 앱은 **ANDROID `1b45f24b…`(Qradar) / IOS `7beb72e4…`(Radar) / WEB `d44f3e33…`(Admin Console, 웹세션 어제 추가)** 3개뿐.
- **firebase.json + lib/firebase_options.dart 가 가리키는 appId 는 둘 다 미등록(phantom)**: android `eaa7fba…`, ios `619084d9…` — apps:list 에 없음. 과거 등록→삭제→재생성 흔적으로 추정. **google-services.json(android `1b45f24b…`)만 올바름.**
- **"2개 split" 아님(앞선 메모 정정)**: 실재 Android 앱은 1개. 정본 결정 불필요 — 유일 실앱이 정본.
- **현재 무영향 이유**: Firestore/Auth 는 projectId+apiKey 로 동작(appId 미사용), FCM 은 네이티브 google-services.json(맞는 값) 사용. → Dart 쪽 phantom appId 가 아직 안 드러남.
- **올바른 조치**: `flutterfire configure` 1회 → firebase.json·firebase_options.dart·google-services.json 이 실앱(1b45f24b/7beb72e4)으로 수렴(선택지 없음, 재생성 결과 수용). 비긴급.
- **주의**: appId 를 키로 쓰는 Analytics / Crashlytics / App Check 를 나중에 붙이면 그때 phantom appId 가 드러남 → 그 전에 flutterfire configure 권장. (웹세션 firebase apps:list 근거, 앱세션 재확인.)
### ℹ️ 웹 세션 변경 (참고 — lib/·functions/ 무관)
Web 앱 Firebase 등록(`...web:d44f3e33`), `.firebaserc` 신규(default→order-app-5957e), `firebase.json` hosting 블록 추가(diff +30/-0, firestore/storage/functions/flutter/emulators 무변경), `landing/` 신규(토스 랜딩+관리자 콘솔, 미배포).

### ⬜ [분리] stores/menuItems 점주(owner) 분기 self-approve (brand_self_approve_guard D2)
`firestore.rules:458-464` 의 `stores/{storeId}/menuItems` 점주(isStoreOwner) 분기에 필드/status 제약이 없어, 점주가 점포한정 메뉴를 등록(pending) 후 **직접 status='approved' 로 자가승인** 가능(admin 검토 우회). 점포한정 메뉴도 승인 대상(streamPending — stores/*/menuItems).
- **왜 brand_self_approve_guard(D1)와 분리했나**: 점주에겐 **정당한 status:'approved' 쓰기**가 섞여 있고(menuOverrides 점주 운영 upsert 주석 참고, rules:472), **독립 매장(brandId 없음) vs 브랜드 가맹 매장**을 `get(stores).brandId` 로 구분해야 하는 다른 성격의 설계. 블런트 차단은 정당 독립매장 플로우를 깰 수 있음.
- **착수 시**: get(stores).brandId 분기 + 점주가 승인권을 갖는 케이스 정의(독립매장 자동/점주 승인 vs 가맹매장 admin 승인). entity_lifecycle.md §5.4 참조.
- D1(V1 brands/menuItems, V2 stores/menuOverrides 브랜드, V3 stores/menuItems 브랜드)에서 **브랜드 분기는 모두 닫힘** — 남은 건 이 점주 분기 1개.

## 소셜로그인 후속 (2026-10-30, social_login_audience 구현/테스트 중 발견)

### ⬜ SL-1 — 카카오/네이버 로그인 후 프로필(email/name/image) null
커스텀 토큰 세션엔 프로필이 없고, 현재 CF(verifyKakaoToken/verifyNaverToken)가 프로필을 반환하지 않아 `UserModel` 의 email/displayName/photoURL 이 비어 홈 인사말·Firebase Auth 식별자 칸이 `-` 로 보인다. 로그인·uid 연속성엔 지장 없음.
- **해법 후보**: CF 응답에 프로필(email/nickname/image) 포함 → 앱이 최초 1회 users 문서에 반영. (기존에도 provider 별 displayName 소스가 달랐으므로 설계 판단 필요.)

### ⬜ SL-2 — `order_item_row.dart` 이미지 플레이스홀더 비일관
주문상세의 주문내역 라인(`lib/presentation/customer/order/widgets/order_item_row.dart`)만 raw `Image.network` + `Icons.image_not_supported`(투박한 깨진-이미지 아이콘)를 쓴다. 메뉴카드/장바구니 등 나머지는 `CachedNetworkImage` + 공통 플레이스홀더라, 같은 이미지 로드 실패여도 주문상세만 "깨진" 느낌으로 보인다(2026-10-30 iOS 실기기, 옛 주문의 스냅샷 imageUrl 미로드 시 노출).
- **해법**: order_item_row 을 `CachedNetworkImage` + 동일 플레이스홀더로 통일(캐싱/폴백 정합). UI polish, 소규모. **소셜로그인과 무관**(테스트 중 우연 발견).
