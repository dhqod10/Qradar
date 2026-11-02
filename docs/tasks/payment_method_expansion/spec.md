# payment_method_expansion — spec

결제수단 확장: **삼성페이 우선 + 애플페이 후속**. 토스페이먼츠 경로로 붙이는 최소안을 조사·설계한다.

- 작성: architect
- 작성일 / 조사 확인시점: **2026-11-02**
- 상태: **§0 결정 확정 (2026-11-02)** — 삼성페이 런칭 전 목표, 애플페이 등록 병행·코드 후속. 외부 착수(X1 토스 삼성페이 신청, X2 애플페이 등록) 대기 중. X1 활성 후 PoC(C2) → designer → developer UI → tester.
- 성격: 이 spec 은 **구현 지시서가 아니라 조사·단계화 문서**다. 사실에 근거해 "외부 작업"과 "코드 작업"을 분리하고, 불확실한 항목은 단정하지 않고 **확인 필요**로 남긴다.

> ⚠️ **토스·삼성·애플 정책은 자주 바뀐다.** 아래 조사는 2026-11-02 웹 검색 + 공식 문서 기준이며, 착수 직전 재확인한다. 확정 전 코드/계약을 진행하지 않는다.

---

## §0. 사용자 확인 / 행동 필요 (설계자가 사용자에게 전달)

여기만 읽어도 "지금 당장 할 것"과 "코드로 먼저 할 수 있는 것"이 갈린다.

### 0-1. 지금 사용자가 직접 **외부에서 시작**해야 하는 것 (코드로 못 함, 리드타임 있음)

| # | 작업 | 주체 | 비고 / 확인 필요 |
|---|------|------|------------------|
| X1 | **토스페이먼츠 상점관리자에서 삼성페이 간편결제 추가 신청/활성화** | 사용자(대표/정산 담당) | 삼성페이는 "카드 결제만 제공" 간편결제로, 토스페이먼츠를 통해 **별도 카드사 계약 없이** 신청하는 구조로 조사됨. 심사·활성 소요기간은 **토스 확인 필요**. |
| X2 | **애플페이: 토스 추가 계약 + Apple 등록** (후속 Phase) | 사용자 + 개발 | Apple Developer 계정, Merchant ID, 애플페이 결제창이 뜨는 **도메인의 Apple 등록**, iOS 전용·국내 카드만. 리드타임 가장 김. **지금 당장은 불필요** — 삼성페이 먼저. |
| X3 | 결제수단 활성 후 **토스 상점관리자에서 결제 UI(결제수단) 노출 설정** | 사용자 | 위젯은 상점관리자에 등록된 수단만 렌더링한다. 미등록 시 `NOT_REGISTERED_PAYMENT_WIDGET` 에러. |

### 0-2. 외부 등록을 **기다리는 동안 코드로 먼저** 할 수 있는 것

| # | 작업 | 레이어 | 비고 |
|---|------|--------|------|
| C1 | 앱 WebView 외부앱 전환용 **AndroidManifest `queries` / iOS `LSApplicationQueriesSchemes` 앱스킴 보강** | native config | 삼성페이/카드사 앱 복귀에 필요. **삼성페이 정확한 스킴은 확인 필요**(§4-3). 기존에 카카오 스킴만 등록돼 있음. |
| C2 | **PoC/스파이크**: 토스 테스트 상점에 삼성페이를 켜고 현재 `tosspayments_widget_sdk_flutter` 위젯에서 **실제로 노출·전환·복귀되는지** 검증 | data + 수동 | **이 기능 최대 기술 리스크.** 위젯(WebView)에서 삼성페이 앱-투-앱이 되는지 공식 확인이 없어 PoC 로 먼저 못박는다. |
| C3 | 결제수단 선택 UI 정리(삼성페이 타일 라벨/아이콘/서브라벨) | presentation | §4-5 의 "앱 타일 vs 위젯 재선택" 불일치도 이때 정리 여부 결정. |

### 0-3. 설계자 권고 (요약)

1. **삼성페이 먼저, 애플페이 후속**으로 단계 분리(§9). 애플페이는 리드타임·제약(iOS 전용·국내카드·도메인 등록)이 커서 지금 계약만 시작하고 구현은 Phase 2.
2. **지금 사용자가 시작할 것 = X1(토스 삼성페이 신청)** 하나. 나머지는 그 결과를 보고.
3. **코드 착수 전 C2 PoC 필수.** 위젯 경로로 삼성페이가 안 되면 설계(네이티브 SDK 필요 여부)가 바뀐다 — 지금은 "된다" 단정 불가.
4. 런칭 전 작업 순서(메모리: C=런칭전용이 마지막)와 충돌하지 않는다 — 본 기능은 B/D 범위의 결제 개선으로, 런칭 전 넣을지 후속으로 뺄지는 사용자 결정(§0-4).

### 0-4. 사용자 결정 — **확정됨 (2026-11-02)**

- **D-A = 예.** X1(삼성페이 토스 신청)을 지금 시작한다. 리드타임 동안 C1(네이티브 스킴)·C2(PoC) 코드 선행 가능.
- **D-B = 등록은 지금 시작, 코드는 나중.** 애플페이 외부 등록 절차(X2: Apple Developer 계정·Merchant ID·도메인 Apple 등록·토스 애플페이 계약)를 **지금 병행 착수**해 리드타임을 줄인다. 실제 코드 구현은 **삼성페이(Phase 1) 완료 후**. (애플페이는 "결국 할 것" — 불필요가 아니라 세팅이 무거워 순서를 뒤로 둔 것.)
- **D-C = 런칭 전 목표.** 삼성페이를 런칭 전에 넣는 것을 목표로 한다. 단 토스 삼성페이 심사 지연 시 런칭을 막지 않도록 PoC·승인 진척에 따라 재평가.

---

## §1. 기능 목적 / 배경

- 갤럭시 사용자가 실물카드 없이 모바일만 들고 다니는 전제 → **삼성페이 필수**. 애플페이도 결국 필요.
- 현재 결제수단은 **카드 + 카카오페이**(토스페이먼츠 결제위젯). 삼성페이/애플페이를 **토스 경로로** 추가하는 것이 목표.
- MVP = **삼성페이를 토스 경로로 붙이는 최소안**. 애플페이는 선행조건만 정리하고 후속 Phase.

---

## §2. 핵심 결론 (조사 요약)

1. **토스페이먼츠는 삼성페이·애플페이를 간편결제로 제공한다**(공식 서비스 페이지). 삼성페이는 별도 카드사 계약 없이 토스를 통해 신청, 애플페이는 추가 계약 + Apple 도메인 등록이 필요. (출처 §15)
2. **결제위젯 경로에서 노출**된다 — 단, 상점관리자에 결제수단을 등록해야 위젯이 렌더링한다. 애플페이는 **iPhone/Mac Safari 에서만** 노출, **국내 카드만** 지원.
3. 현재 앱은 **토스 결제위젯(`tosspayments_widget_sdk_flutter`, WebView 기반)** 을 쓰고, **결제수단 선택은 위젯 안에서** 일어난다(앱이 넘기는 `method` 문자열은 현재 **미사용**). → 상점관리자에 삼성페이를 켜면 **원칙적으로 위젯이 자동 노출**할 수 있다. (단 §4-3 앱 전환 확인 필요)
4. **서버검증 `verifyTossPayment` 는 결제수단에 무관(method-agnostic)** 하다. confirm/금액·orderId 대조/멱등/게이트/Qoin spend/취소·환불 어느 것도 수단별로 분기하지 않는다. → **삼성페이 추가에 서버 코드 변경은 원칙적으로 불필요**(§6).
5. 따라서 **삼성페이 MVP 의 코드 범위는 작다**: ① 네이티브 앱스킴 보강(C1) ② 결제수단 UI 노출(C3) ③ PoC 검증(C2). 무거운 네이티브 SDK(삼성페이 SDK / Apple PassKit 직연동)는 **토스 경로에서는 불필요**(단, C2 PoC 로 위젯 WebView 전환 가능 여부 확인 전제).
6. **최대 리스크 = "위젯(WebView)에서 삼성페이/애플페이 앱-투-앱 전환이 실제로 되는가"** — 공식 문서로 완전 확정 못 함(§4-3, §4-4). **확인 필요 / PoC 필수.**

---

## §3. 현황 조사 (코드 현황)

### 3-1. 결제 파이프라인 (Clean Architecture 현행)

```
presentation  checkout_page.dart (PaymentMethodTile 로 card/kakaoPay 선택)
      ↓ LaunchPaymentUseCase
domain        PaymentGatewayRepository (launchPayment / verifyAndCreateOrder / cancel / refund)
      ↓
data          PaymentGatewayRepositoryImpl
                ├─ TossPaymentRemoteDataSource ── tosspayments_widget_sdk_flutter (WebView 위젯) ── Toss 결제창
                └─ CloudFunctionsRemoteDataSource ── verifyTossPayment / cancelTossPayment / processRefund
functions     verifyTossPayment.ts ── Toss confirm API + 게이트 + 금액 + Qoin spend + orders/orderLogs batch
```

- **SDK 직접 사용은 `data`(TossPaymentRemoteDataSource)와 `functions` 에만** — 절대 규칙 준수. 삼성페이/애플페이 추가도 이 경계를 유지한다.

### 3-2. 중요한 현행 사실 (조사로 확인)

| 항목 | 현황 | 출처(코드) |
|------|------|-----------|
| 결제수단 enum | `PaymentMethod` 에 `samsungPay`, `applePay` **이미 선언됨**(label 포함, "Phase 3b") | `lib/domain/entities/payment_method.dart` |
| PaymentMethod → Toss 문자열 | `samsungPay→'SAMSUNG_PAY'`, `applePay→'APPLEPAY'` 매핑 **이미 존재** | `lib/data/repositories/payment_gateway_repository_impl.dart` `_toTossMethodString` |
| 위젯에 넘기는 method | **현재 미사용** — "SDK 가 위젯에서 선택하게 함". 실제 선택은 Toss 위젯 안에서 | `toss_payment_remote_data_source.dart` 주석 + `_TossPaymentPage` |
| 결제수단 노출 | Toss `renderPaymentMethods` 가 **상점관리자 등록 수단**을 렌더 | 동 파일 |
| 체크아웃 UI | 앱이 `card`/`kakaoPay` 타일만 표시하고 선택값을 서버에 `paymentMethod.name` 으로 전달 | `checkout_page.dart` (라인 372~387) |
| 서버 입력 | `verifyTossPayment` 는 `paymentMethod: string` 을 받지만 **검증/분기에 쓰지 않고 기록용** | `functions/src/verifyTossPayment.ts`, `cloud_functions_remote_data_source.dart` |
| orders 소유권 | `orders` create 는 **`verifyTossPayment` CF 전담**, 클라이언트 직접 생성 불가 | `docs/processes/data_ownership.md` §2.4 |
| 네이티브 스킴 | AndroidManifest 에 `qradar` + 카카오 스킴만. iOS Info.plist 에 `LSApplicationQueriesSchemes` 존재(내용 확인 필요) | `android/.../AndroidManifest.xml`, `ios/Runner/Info.plist` |
| 패키지 | `tosspayments_widget_sdk_flutter: ^2.2.0`, `webview_flutter: ^4.10.0`, `cloud_functions: ^6.1.0` | `pubspec.yaml` |

### 3-3. 관측된 기존 불일치 (이번 기능이 건드리는 영역)

- 앱 타일에서 고른 수단과 **Toss 위젯에서 실제 고른 수단이 다를 수 있다**(위젯이 재선택을 허용). 그래서 `orders.paymentMethod` 가 실제 결제수단과 어긋날 수 있다. 수단별 분석이 필요하면 **Toss confirm 응답의 실제 method 로 기록하도록** 서버에서 보정하는 선택지가 있다(§6-3, 선택·후속). 이번 MVP 필수는 아님.

---

## §4. 조사 — 토스 경로로 삼성페이/애플페이 (근거 + 확인시점 2026-11-02)

### 4-1. 토스 결제위젯으로 삼성페이·애플페이가 되는가? → **원칙적으로 된다(간편결제). 단 위젯 노출/앱전환은 아래 조건.**

- 토스 공식 서비스 페이지: 애플페이·삼성페이를 간편결제로 제공, 각사 개별 계약 없이 토스로 신청. (출처 §15-1)
- 결제위젯 가이드: 애플페이는 **iPhone/Mac Safari 에서만** 노출, 상점관리자에서 **결제 UI 등록 필수**(미등록 시 `NOT_REGISTERED_PAYMENT_WIDGET`). (출처 §15-4)
- **별도 네이티브 결제 SDK 없이 토스 위젯 경로만으로 가능한지**: 간편결제 노출은 위젯 경로로 가능. 그러나 **앱(WebView)에서의 외부앱 전환은 앱스킴 설정이 전제**(§4-3). → "위젯만으로 끝"이 아니라 "위젯 + 앱스킴 설정"이다.

### 4-2. 삼성페이 (토스 경유)

- 분류: **"카드 결제만 제공" 간편결제** (토스 블로그). 토스머니 같은 복합결제 없음. (출처 §15-2)
- 계약: **별도 카드사 계약 없이 토스페이먼츠를 통해 신청**하는 구조로 조사됨. (출처 §15-2) — **신청·심사 소요기간은 토스 확인 필요.**
- confirm 흐름: 카드 기반이므로 `verifyTossPayment` confirm 로직에 특수 분기 불필요(§6).

### 4-3. 앱(Flutter/WebView) 외부앱 전환 — **최대 확인 필요 항목**

- 토스 결제위젯 가이드: 모바일에서 카드사 화면으로 이동하지 않으면 **카드사 앱스킴 등록 필요**, WebView 가이드 참고. (출처 §15-4)
- 커뮤니티/플러그인 자료: 토스 Flutter 연동은 WebView 가 외부 결제앱을 띄우며, AndroidManifest 에 `queries` 블록(예: 토스 `supertoss`, 삼성카드 앱카드 `mpocket.online.ansimclick`)과 권한, min SDK ≥ 20 등을 추가한다. iOS 는 Info.plist `LSApplicationQueriesSchemes`/URL Types 에 결제앱 스킴 등록. (출처 §15-6, §15-7 — **공식이 아닌 커뮤니티 자료 포함, 검증 전제**)
- **삼성페이 전용 스킴/인텐트는 공식 문서로 확정 못 함.** 위 "삼성카드 앱카드"와 "삼성페이"는 다를 수 있다. → **확인 필요**, C2 PoC 로 실제 전환·복귀 검증.

### 4-4. 애플페이 (토스 경유) — 후속 Phase

- iOS 전용, **국내 카드만** 지원. (출처 §15-8)
- 토스가 Apple Pay 국내 공식 PG. 결제위젯으로 연동 가능하되 **기존 가맹점도 추가 계약 필요**. (출처 §15-5)
- **Apple 도메인 등록**: 애플페이 결제창이 뜨는 도메인을 Apple 에 등록해야 하는 구조(토스 기술블로그). 결제 진행 시 **별도 창이 하나 더 뜨고** 거기서 애플페이 버튼 노출. iOS 17 이후 cross-origin 결제가 가능해졌다는 언급 있음(사용자 건의글, 공식답변 아님). (출처 §15-5, §15-8)
- **인앱 Web（WKWebView）에서 결제위젯 애플페이가 매끄럽게 되는지**: 공식 확정 자료 **미발견 → 확인 필요.** 리스크가 삼성페이보다 크다. → **Phase 2 로 분리**, 계약·도메인 등록 선행.
- iOS 심사 영향 / 엔티틀먼트: 토스 PG 경유(위젯)는 앱이 PassKit Merchant 자격을 직접 쓰지 않을 수 있으나, **직연동이 아니라 PG 위젯 경유라는 전제에서의 엔티틀먼트 요구는 확인 필요.**

### 4-5. 결제수단 선택 UI

- 현재는 앱 타일(card/kakaoPay) + 위젯 내 재선택. 삼성페이를 **상점관리자에 켜면 위젯에 자동 노출**되므로, 앱 타일에 삼성페이를 추가하지 않아도 결제 자체는 가능할 수 있다.
- 다만 UX 상 "삼성페이로 결제" 진입점을 앱 타일에 **명시적으로 노출**할지, 혹은 타일을 없애고 위젯 선택으로 일원화할지는 **designer 결정 사항**(§13).

---

## §5. 외부 선행조건 정리 (사용자 대기작업 — 코드 불가)

### 5-1. 삼성페이 (Phase 1)
- [X1] 토스 상점관리자 → 삼성페이 간편결제 신청/활성화. (소요기간 토스 확인)
- [X3] 활성 후 상점관리자에서 결제수단(결제 UI) 노출 설정.

### 5-2. 애플페이 (Phase 2)
- 토스 애플페이 추가 계약.
- Apple Developer: Merchant ID 발급, 애플페이 도메인 등록(토스 안내 도메인 포함), 엔티틀먼트(확인 필요).
- iOS 빌드/심사 영향 점검.

### 5-3. 환경변수 / 빌드 (단일 진실원: `docs/operations.md`)
- `TOSS_CLIENT_KEY` 는 이미 `--dart-define`/`String.fromEnvironment` 로 주입(하드코딩 금지 준수). **삼성페이/애플페이 추가로 새 클라이언트 키가 필요하진 않음**(같은 상점). 가맹/머천트 식별 정보도 코드 하드코딩 금지 — 상점관리자/계약 영역.

---

## §6. 서버검증(`verifyTossPayment`) 정합성 분석

결론: **삼성페이 추가 = 서버 무변경이 기본.** 근거:

1. **confirm 흐름**: `POST /v1/payments/confirm` 는 `paymentKey/orderId/amount` 로 확정 — 결제수단과 무관. 삼성페이는 카드 기반이라 추가 분기 없음.
2. **금액·orderId 변조 방지**: `amount === cart.totalPrice`, 서버 재계산(priceGate), orderId=idempotencyKey 대조 — 모두 수단 무관.
3. **멱등(idempotencyKey)**: `orders/{idempotencyKey}` 가드 — 수단 무관.
4. **게이트(G1/G2)·Qoin spend**: 매장/메뉴/정책/잔액 기준 — 수단 무관. Qoin spend 차감도 confirm 전 서버 소계 기준이라 삼성페이여도 동일.
5. **취소/환불(`cancelTossPayment`/`processRefund`)**: Toss 취소/환불 API 도 수단 무관(카드 기반). **단, 간편결제 취소 제약(부분취소/기한)이 수단별로 다를 가능성은 확인 필요** — 삼성페이는 카드 기반이라 카드와 동일할 것으로 추정하나 단정 금지.
6. **애플페이**: 동일하게 method-agnostic 으로 수용 가능할 것으로 보이나, 국내카드 전용/취소 제약은 Phase 2 착수 시 재확인.

### 6-3. 선택(후속) — 실제 결제수단 기록 정확화
- 현재 `orders.paymentMethod` 는 **앱이 보낸 값**이라 위젯 재선택과 어긋날 수 있다. 수단별 분석/정산이 필요하면 **Toss confirm 응답의 실제 method/easyPay 코드로 서버가 기록을 보정**하는 소폭 변경을 후속으로 둔다. **MVP 범위 아님.**

---

## §7. 범위 / 비범위

### 범위 (Phase 1 — 삼성페이)
- 삼성페이를 토스 경로로 노출/결제 가능하게 하는 **최소 코드 + 네이티브 설정 + PoC**.
- 외부 선행작업(X1/X3) 정리 및 사용자 가이드.

### 비범위
- 삼성페이 **네이티브 SDK 직연동**(토스 경로로 충분하다는 전제. PoC 결과가 뒤집으면 별도 spec).
- 애플페이 **구현**(Phase 2 — 본 spec 은 선행조건만).
- 네이버페이/토스페이/페이코 등 그 외 수단.
- Qoin spend/적립 정책 변경, 게이트 정책 변경 — **무관**.
- `orders.paymentMethod` 정확화(§6-3) — 후속 선택.

---

## §8. Clean Architecture 레이어 설계 (Phase 1 최소안)

외부 등록(X1) + PoC(C2) 통과를 **전제로 한** 최소 변경. 통과 전에는 C1/PoC 만.

| 레이어 | 변경 | 비고 |
|--------|------|------|
| domain | **변경 거의 없음** — `PaymentMethod.samsungPay` 이미 존재 | 필요 시 label/서브라벨만 |
| data | `TossPaymentRemoteDataSource` — 위젯은 상점관리자 수단을 자동 렌더하므로 **코드 변경 최소**. method 매핑 이미 존재. | SDK 경계 유지 |
| data(functions) | **변경 없음**(§6) | method-agnostic |
| presentation | `checkout_page.dart` / `payment_method_tile.dart` — 삼성페이 타일 노출 여부(디자이너 결정), 아이콘/라벨 | AppColors 만 사용(하드코딩 금지) |
| native(config) | AndroidManifest `queries`/권한, iOS `LSApplicationQueriesSchemes`/URL Types 앱스킴 보강 | **삼성페이 스킴 확인 필요** |

- **신규 Entity/UseCase/Repository/DataSource 불필요.** 기존 결제 파이프라인 재사용. (과도설계 금지 원칙)

---

## §9. 단계화 (권고)

### Phase 0 — 결정 + 선행 (지금)
- 사용자: §0-4 D-A/D-B/D-C 결정, X1(삼성페이 토스 신청) 시작.
- 개발: C1(앱스킴 보강) + C2(PoC) 준비 — X1 활성 전이라도 **테스트 상점**으로 PoC 가능 여부 확인.

### Phase 1 — 삼성페이 (코드 범위 작음, 외부 X1 대기)
- 전제: X1 활성 + C2 PoC 통과.
- 작업: native 스킴 보강, UI 노출(디자이너), 회귀·실기기 테스트.
- 서버: 무변경.

### Phase 2 — 애플페이 (후속, 외부 리드타임 큼)
- 전제: 토스 추가 계약 + Apple Merchant/도메인 등록 완료.
- 작업: iOS 빌드/엔티틀먼트/도메인, 위젯 애플페이 노출·전환 검증, 심사.
- 별도 spec 권장(선행조건 완료 시점에 재조사).

### 타이밍 (런칭 전 B 콘솔과의 관계)
- Phase 1(삼성페이)은 서버/정책 무변경이라 리스크가 낮아 런칭 전 포함 **가능**하나, 외부 X1 리드타임에 종속 → **D-C 사용자 결정**.
- Phase 2(애플페이)는 리드타임이 커 **런칭 후 권장**.

---

## §10. 데이터 흐름 (Phase 1, 변경 없음 재확인)

```
checkout → LaunchPaymentUseCase → PaymentGatewayRepositoryImpl.launchPayment
  → TossPaymentRemoteDataSource (위젯, 상점관리자 수단 중 삼성페이 선택 가능)
  → 성공 시 paymentKey/orderId/amount 반환
  → verifyAndCreateOrder → verifyTossPayment CF (삼성페이도 동일 경로)
  → orders/{orderId} + orderLogs batch (CF 전담)
```

---

## §11. 에러 처리

- 기존 매핑 재사용: `VerifyPaymentFailure`, `TossPaymentFailure/Cancelled`, 게이트 거절 토큰.
- 신규 고려:
  - `NOT_REGISTERED_PAYMENT_WIDGET`(상점관리자 미등록) — 삼성페이 미활성 시. 사용자(점주/운영)용 안내로 구분.
  - 외부앱 전환 실패/미복귀(앱스킴 누락) — PoC 에서 재현·처리 설계. 실패 시 "다른 수단으로 결제" 폴백 유지.
  - 애플페이 미지원 환경(안드로이드/구형 iOS) — 노출 자체를 조건부로(iOS only). Phase 2.

---

## §12. 이력 / 감사 추적 — §4 체크리스트 통과

`docs/processes/audit_trail.md` §4 6개 항목 점검:

1. **돈·권한·정책 값을 바꾸는가?** → **아니오.** 결제수단 추가는 **거래 흐름**이지, Qradar 측 정책/권한/config 값 변경이 아니다. 삼성페이/애플페이 활성화는 **토스 상점관리자(외부)** 에서 이뤄지며 우리 Firestore `config`/권한 문서를 바꾸지 않는다. → **신규 "설정 변경 이력" 불필요.** (사유 명시: 외부 PG 설정이며 우리 정책 값이 아님)
2. **덮어쓰기로 사라지는 값?** → 없음. 주문별 `orders.paymentMethod` 는 거래마다 새 문서로 박제.
3. **거래 문서가 정책 값을 참조만?** → 결제수단은 당시 값이 orders 에 기록됨(거래 이력 존재). 단 §3-3/§6-3 의 "앱이 보낸 값 vs 실제 수단" 정확성 이슈는 분석 품질 문제(감사 누락 아님).
4. **"누가"?** → 결제 행위자 uid 는 주문/로그에 기존대로 기록.
5. **batch?** → 없음(수단 추가는 일괄처리 아님).
6. **CF 로그 의존?** → 아니오. 거래 기록은 Firestore orders/orderLogs 에 영구.
7. **(상시) 권한 판정 필드 create/update 교차?** → 해당 없음(권한 필드 미변경).

> 결론: **설정 변경 이력 신규 요구 없음**(사유 = 돈/권한/정책 값 미변경, 외부 PG 설정). 거래 이력은 기존 orders/orderLogs 로 충족. §6-3 정확화는 선택 후속.

---

## §13. 작업 분배 판단

| 역할 | 필요 여부 | 시점 / 범위 |
|------|-----------|-------------|
| **designer** | **필요(소폭)** | 삼성페이 결제수단 타일 노출 여부·아이콘·라벨, "앱 타일 vs 위젯 재선택" 정리. AppColors 준수. Phase 1 UI 가 확정된 **후** 착수. |
| **developer** | **조건부/단계적** | ① 먼저 C1(네이티브 스킴)+C2(PoC) — **외부 X1 활성 전에도 테스트 상점으로 착수 가능.** ② UI/노출은 designer 후. ③ **서버 무변경**. ④ 애플페이(Phase 2)는 외부 선행조건 완료 전 **구현 불가** — 명확히 보류. |
| **tester** | **필요** | PoC 결과 검증 + Phase 1 실기기(갤럭시) 삼성페이 전환·복귀·결제·취소/환불·Qoin 병행 회귀. 애플페이는 Phase 2. |

- **외부 등록 완료 전 구현 불가 부분(명확화)**: 삼성페이 실결제 end-to-end 는 X1 활성 전 불가(테스트 상점 PoC 는 가능). 애플페이 전체는 계약+Apple 등록 전 불가.

---

## §14. 미해결 / 확인 필요 (단정 금지 목록)

1. **[기술·최우선]** 토스 결제위젯(Flutter WebView, `tosspayments_widget_sdk_flutter 2.2.0`)에서 **삼성페이 앱-투-앱 전환·복귀가 실제로 되는가** → C2 PoC.
2. 삼성페이 **전용 앱스킴/인텐트** 정확값 (삼성카드 앱카드와 구분) → 토스 WebView 가이드/삼성 문서.
3. 삼성페이 토스 신청 **심사·소요기간**.
4. 간편결제 **취소/부분취소/환불 제약**이 카드와 다른지(삼성페이).
5. 애플페이 인앱 **WKWebView 지원** 매끄러움 / iOS 17 cross-origin 실제 적용 / 엔티틀먼트 요구.
6. 애플페이 Apple **도메인 등록 대상 도메인**(토스 안내) + iOS 심사 영향.
7. (선택) `orders.paymentMethod` 실제 수단 정확화 필요성(§6-3).

> 위 1~6 은 **착수 직전 토스 개발자센터(docs.tosspayments.com)/고객센터(1544-7772) 로 재확인**. 정책 변동 가능.

---

## §15. 참고 출처 (확인시점 2026-11-02)

1. 토스페이먼츠 서비스 소개 — 간편결제(삼성페이/애플페이 포함) 제공: https://www.tosspayments.com/about/service , https://www.tosspayments.com/services
2. 토스페이먼츠 블로그 — 간편결제 특성(삼성페이=카드결제만): https://www.tosspayments.com/blog/articles/30639
3. 토스페이먼츠 블로그 — Apple Pay 연동 세 가지 방법(결제창/직연동/위젯): https://www.tosspayments.com/blog/articles/paytech-5
4. 토스 결제위젯 연동 가이드(노출 조건/`NOT_REGISTERED_PAYMENT_WIDGET`/앱스킴): https://docs.tosspayments.com/guides/v2/payment-widget/integration
5. 토스페이먼츠 애플페이 PG(공식 파트너/추가 계약): https://toss.im/tossfeed/article/tosspayments-applepay , https://news.mtn.co.kr/news-detail/2023032209243754160
6. 토스 Flutter 연동/WebView 앱스킴·`queries`(커뮤니티·플러그인 자료, 검증 전제): https://pub.dev/packages/tosspayments_widget_sdk_flutter , https://pub.dev/packages/toss_payment
7. WebView 앱스킴 등록 사례(개인 기술블로그, 참고): https://velog.io/@gs0428/Expo-Webview-환경에서-토스페이먼츠-연동하기-feat.-라이브러리-제작
8. 애플페이 제약(iOS/국내카드/도메인 등록/별도 창) — 토스 블로그·기술지원 게시글: https://www.tosspayments.com/blog/articles/paytech-5 , https://techchat.tosspayments.com/m/1168144387537117264

> 일부 출처는 커뮤니티/개인 블로그로 **공식이 아니다**. 공식 확정은 토스 개발자센터·고객센터로 교차검증한다.
