# 런칭 전에 바꿔야 하는 값 — 체크리스트

전수 테스트(2026-11-26)를 돌리면서 "지금은 테스트용이라 이 값이지만, 출시 전에 반드시 손대야 한다"
고 확인된 것만 모은다. 추측이 아니라 **실제 파일·화면에서 확인한 것**만 적는다.

각 항목은 "지금 값 → 바꿀 값 / 누가 / 언제" 순으로 읽는다.
`[차단]` 은 이걸 안 바꾸면 출시 자체가 깨지는 것, `[정리]` 는 안 바꿔도 돌아가지만 남겨 두면 안 되는 것.

최종 갱신: 2026-11-26

---

## 1. 결제 — 실제 돈이 걸린 값

### 1-1. `[차단]` 토스 클라이언트 키가 데모 키다

| | |
|---|---|
| 위치 | `env.json` → `TOSS_CLIENT_KEY` |
| 지금 | `test_gck_docs_Ovk5rk1EwkEbP0W43n07xlzm` (토스 공개 문서용 데모 키) |
| 바꿀 값 | 토스 심사 통과 후 발급되는 **라이브 클라이언트 키** |
| 시점 | 심사 통과 직후, 스토어 빌드 전 |

이 키로는 실결제가 되지 않는다. 심사 단계에서는 문제되지 않지만, **통과 직후 교체가 런칭
체크리스트의 첫 항목**이다.

### 1-2. `[차단]` 토스 시크릿 키 (서버)

| | |
|---|---|
| 위치 | Firebase Secrets Manager → `TOSS_SECRET_KEY` |
| 지금 | **미확인** — Secrets Manager 에 어느 환경 키가 들어 있는지 직접 봐야 한다 |
| 바꿀 값 | 라이브 시크릿 키 |
| 명령 | `cd /Users/byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 functions:secrets:set TOSS_SECRET_KEY --project order-app-5957e` |

클라이언트 키(1-1)와 **반드시 같은 환경**이어야 한다. 한쪽만 라이브로 바꾸면 승인 단계에서
전부 실패한다. 시크릿을 바꾼 뒤에는 이를 쓰는 함수를 재배포해야 반영된다.

### 1-3. `[확인]` 결제 게이트 모드

| | |
|---|---|
| 위치 | `functions/.env.order-app-5957e` |
| 지금 | `PAYMENT_GATE_MODE=enforce`, `PAYMENT_PRICE_MODE=enforce` |
| 바꿀 값 | **그대로 둔다** — 이미 최종값이다 |

바꿀 필요는 없지만 목록에 둔다. 출시 직전에 누가 `shadow`/`off` 로 내려놓고 잊는 일을 막기
위해서다. 출시 당일 이 파일을 열어 두 줄 다 `enforce` 인지 눈으로 확인한다.
운영 중 긴급 상황에서 내리는 절차는 [docs/operations.md](operations.md) §6.3 에 있다.

### 1-4. `[확인]` 랜딩에 적힌 결제수단 ↔ 토스 콘솔 실제 설정

| | |
|---|---|
| 위치 | `landing/refund.html` 제3조, `landing/index.html` 결제수단 안내 |
| 지금 | "신용·체크카드, 간편결제(카카오페이)" 두 가지만 표기 |
| 해야 할 일 | 토스 개발자센터에서 **켜 둔 수단 목록을 확인**하고 양쪽을 일치시킨다 |

앱에서 결제수단 선택 UI를 뺐기 때문에, 이용자에게 보이는 수단은 **토스 콘솔 설정이 그대로
결정한다**. 켜 둔 게 둘보다 많으면 "정책에 없는 수단으로 결제된다"가 되어 심사 지적 대상이다.
→ 콘솔에서 카드·카카오페이만 남기거나, 켜 둔 수단 전부를 두 페이지에 추가하거나 **둘 중 하나**.

---

## 2. Qoin — 운영 정책값

### 2-1. `[확인]` 전역 적립률 5%

| | |
|---|---|
| 위치 | 관리자 앱 → 더보기 → Qoin 설정 (Firestore `config/qoin`) |
| 지금 | 적립률 **5%**, 적립 **켜짐** |
| 바꿀 값 | 출시 시점 정책값 (미정) |

코드가 아니라 **운영 데이터**다. 앱 재배포 없이 관리자 화면에서 바꿀 수 있다.
5%는 테스트 중 편하려고 둔 값인지 실제 정책값인지 아직 확정되지 않았다.
브랜드별·매장별 개별 적립률도 같은 화면에서 따로 잡을 수 있다.

### 2-2. `[차단]` Qoin **사용**(spend) 게이트

| | |
|---|---|
| 위치 | Firestore `config/qoin` → `spendEnabled` |
| 지금 | **꺼짐** (필드 부재 또는 `false` — 코드가 `!= true` 면 전부 차단으로 본다) |
| 바꿀 값 | 아래 두 가지가 정해진 뒤에 `true` |

켜기 전에 반드시 먼저 정해야 하는 것:
1. **토스 최소 결제금액** — Qoin 으로 깎은 뒤 금액이 토스 최소금액 밑으로 내려가면 결제가 깨진다.
2. **점주 정산 (N4)** — Qoin 할인분을 누가 부담하는지. 이게 안 정해지면 점주와 분쟁이 난다.

기능 자체는 완성돼 있고 배포도 가능한 상태다. 꺼 둔 것은 정책이 미정이기 때문이다.

---

## 3. 앱 메타 — 스토어 올리기 전

### 3-1. `[차단]` 앱 내 버전 표기가 실제 버전과 다르다

| | |
|---|---|
| 위치 | `pubspec.yaml` / 각 역할 더보기 화면 4곳 |
| 지금 | pubspec `1.0.0+1` 인데 화면에는 **`Qradar v0.1.0`** 하드코딩 |
| 바꿀 값 | 화면 표기를 `package_info_plus` 등으로 **pubspec 에서 읽게** 바꾸거나, 최소한 숫자를 맞춘다 |

해당 파일: `lib/presentation/{customer/more/more_page,owner/more/owner_more_page,brand/more/brand_more_page,admin/more/admin_more_page}.dart`

버전이 네 군데에 각각 손으로 박혀 있어, 올릴 때마다 네 곳을 같이 고쳐야 한다.
한 번만 읽어 쓰게 바꿔 두면 이 항목이 영구히 사라진다.

---

## 4. 코드에서 들어내야 하는 임시 자산 `[정리]`

배포 작업용으로 넣어 둔 것들이다. 파일 첫 줄에 스스로 "정리 커밋에서 삭제한다"고 적혀 있다.

### 4-1. `TEMP_MIGRATION_CARD` — payment_server_authority 배포 ③⑤⑨ 용

관리자 더보기의 **"배포 마이그레이션 (임시)"** 메뉴가 이것이다. 출시 빌드에 남으면 안 된다.

```
lib/data/datasources/remote/migration_remote_data_source.dart
lib/data/repositories/migration_repository_impl.dart
lib/domain/entities/migration_call_exception.dart
lib/domain/entities/migration_report.dart
lib/domain/repositories/migration_repository.dart
lib/domain/usecases/run_migration_use_cases.dart
lib/presentation/admin/more/admin_migration_page.dart
lib/presentation/admin/widgets/admin_migration_cards.dart
+ lib/presentation/admin/more/admin_more_page.dart 의 진입 버튼
```

### 4-2. `TEMP_PRICE_AUDIT_CARD` — payment_price_authority 배포 ②⑨ 용

```
lib/data/datasources/remote/price_audit_remote_data_source.dart
lib/data/repositories/price_audit_repository_impl.dart
lib/domain/entities/price_audit_report.dart
lib/domain/repositories/price_audit_repository.dart
lib/domain/usecases/run_price_audit_use_case.dart
lib/presentation/admin/widgets/admin_price_audit_card.dart
```

두 묶음 모두 대응하는 **Cloud Function 도 같이 지워야** 한다 (`auditOrderPriceIntegrity`,
`migrateStoreApprovalMeta`, `migrateBrandPrivateProfile`). 앱에서만 지우면 함수는 계속 떠 있다.

### 4-3. 시드 데이터

`lib/dev/seed/` — Phase 1 시드. `phase1_seed_data.dart` 가 "Phase 1 시드 데이터로 생성된
임시 매장입니다" 같은 설명을 들고 있다. 출시 빌드에서 호출되지 않는지 확인하고, 안 쓰면 들어낸다.

---

## 5. 운영 Firestore 에 남아 있는 테스트 데이터 `[정리]`

**이건 코드가 아니라 실제 운영 DB 다.** 지금 테스트 계정으로 만든 것들이 그대로 들어 있고,
출시하면 일반 고객에게 그대로 보인다.

| 무엇 | 지금 | 처리 |
|---|---|---|
| 브랜드 | 큐라다커피 (`BR-BSWCHE62`) | 삭제 또는 실제 브랜드로 교체 |
| 매장 | 큐라다커피 강남점 (서울 강남구 테헤란로 152) | 삭제 |
| 마스터 메뉴 | 카페라떼 / 카푸치노 / 아메리카노 / 아이스 아메리카노 / **카페라떼 복사** | 삭제 |
| 옵션 그룹 | 샷 추가 (+500 / +1000) | 삭제 |
| 진행 중인 주문 | **5건** (paid·accepted 등에서 멈춰 있음) | 완료·취소 처리 후 삭제 |
| 테스트 계정 | `qradar@tmi.com` / `qradar_brand@` / `qradar_owner@` / `qradar_customer@` | 출시 후에도 쓸지 결정 |

⚠️ **진행 중 주문 5건은 지금 매장 삭제를 막고 있다.** 관리자 매장 관리에서 삭제를 누르면
"진행 중인 주문이 5건 있어요"로 차단된다(의도된 가드). 매장을 지우려면 그 주문부터 끝내야 한다.

### 5-1. 테스트 매장 전화번호

O-03 검증 중 매장 전화번호에 **`01095355886`** 를 넣었다. 이건 랜딩 푸터의 고객센터 번호다.
테스트 매장이라 지금은 문제없지만, 매장을 지우거나 실제 번호로 바꿔야 한다.

---

## 6. 심사·법적 표기 — 아직 결정 안 된 것

### 6-1. 통신판매업자 / 중개자 구분

랜딩 푸터가 **"통신판매중개자가 아닌 통신판매업자"** 라고 선언하는데, 실제 구조는 매장이 가격과
메뉴를 직접 등록하는 **중개형에 가깝다**. 심사에서 책임 주체를 캐물으면 설명이 필요하다.

**N4(점주 정산) 결정과 묶여 있어** 아직 확정하지 않았다. §2-2 와 같은 결정이다.

### 6-2. 고객센터 번호가 개인 휴대폰

`010-9535-5886`. 심사에서 지적될 수 있다. 대표번호 발급 여부를 정해야 한다.

### 6-3. 환불 정책의 "부분 환불" 조항

`landing/refund.html` 제4조는 부분 환불을 약속하는데, 구현(`processRefund`)은 **전액 환불만**
가능하다. 조항을 운영에 맞춰 다듬거나, "부분 환불은 고객센터 수동 처리"라고 답할 준비를 한다.

---

## 관련 문서

- 심사 제출 자료: [docs/toss_merchant_review.md](toss_merchant_review.md)
- 결제 게이트 운영: [docs/operations.md](operations.md) §6
- 테스트 시나리오: [docs/test_scenarios.md](test_scenarios.md)
