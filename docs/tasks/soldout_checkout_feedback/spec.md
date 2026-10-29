# soldout_checkout_feedback 기능 명세

## 개요

- 목적: 장바구니에서 `결제하기` 를 눌렀을 때 품절/판매중지/매장 영업중단 등 **위반으로 체크아웃이 막히는 경우**, 사용자에게 **즉시 보이는 transient 피드백(스낵바)** 을 제공한다. 현재는 위반 라인으로 스크롤만 하고 아무 메시지가 없어 "버튼이 고장난" 느낌(무반응)을 준다.
- 작업 유형: 버그 수정 (UX 피드백 보강)
- 영향 범위:
  - 화면: `lib/presentation/customer/cart/cart_page.dart` (단일 파일)
  - Domain: 없음
  - Data: 없음
  - Presentation: `_CartPageState._onCheckout` 의 `hasViolations` 분기만
  - 공통 컴포넌트: 없음 (신규 위젯 없음)
  - 라우팅: 없음
  - 권한 / 환경 설정: 없음
- 비범위:
  - 서버 결제 게이트 / 선검증 로직 변경 금지 (이미 정상 동작 — 위반 차단은 유지).
  - `CartAvailabilityBanner`(상단 배너) 자체 재설계 금지.
  - 가격 변동(`result.applied.hasChanges`) 분기는 이번 범위 아님 — 이미 스크롤 + 가격 배너로 처리됨.
  - `CheckoutBlockedSheet`(바텀시트) **도입하지 않음** — 아래 "설계 판단" 참조.
  - F1(로그인 세션) / H-01(클라이언트 버전 게이트) 분기는 기존 동작 유지.

---

## 설계 판단 — 스낵바 vs 기존 CheckoutBlockedSheet

`lib/presentation/customer/checkout/widgets/checkout_blocked_sheet.dart`(`CheckoutBlockedSheet`) 재사용 여부를 검토한 결과 **스낵바를 채택**한다. 사유:

- `CheckoutBlockedSheet` 는 **체크아웃 화면(진입 이후)** 전용이다. 보조 액션이 `카트에서 확인하기` / `카트로 돌아가기` 로, 이미 카트에 있는 이 화면에서는 의미가 없다(현재 화면으로 돌아오는 no-op).
- `이 메뉴 빼기` 액션도 카트 라인 타일(`CartLineTile`)의 행 단위 `빼기`/`다시 고르기` 와 중복된다.
- 카트 화면에는 이미 **무엇이/왜 막혔는지** 를 지속적으로 알리는 2중 장치가 있다: 상단 `CartAvailabilityBanner` + 라인별 "품절/판매중지" 뱃지. 빠진 것은 **탭이 등록됐고 왜 진행되지 않았는지** 를 알리는 순간 피드백뿐이다 → 스낵바가 정확한 크기.
- 같은 파일 `_onCheckout` 내 F1 분기(로그인 안내)·`_recheck`(확인 실패 안내)가 이미 `ScaffoldMessenger` 스낵바를 쓴다 → 패턴 일관.

→ 과설계 방지: 신규 위젯/시트 없이 스낵바 한 블록만 추가한다.

---

## 요구사항

### 기능 요구사항

- [ ] `_onCheckout` 의 `if (result.validation.hasViolations)` 분기에서 **기존 `_scrollToFirstViolation()` 호출은 유지**하고, 그 직전(또는 직후)에 transient 피드백 스낵바를 띄운다.
- [ ] 위반 유형에 맞는 문구를 보인다 (아래 표):
  - 매장 단위 위반(`result.validation.store != null`): 매장에서 지금 주문 불가 → 메뉴를 뺄 수 없는 상황.
  - 그 외(메뉴 품절/판매중지 `menus`, 옵션 위반 `optionIssues`): 막힌 메뉴를 빼고 결제하도록 유도.
- [ ] 연타 시 스낵바가 쌓이지 않도록 노출 전 현재 스낵바를 제거한다(`hideCurrentSnackBar()` 또는 `clearSnackBars()`).
- [ ] 스낵바는 짧게 표시한다(기존 패턴과 동일한 `Duration(seconds: 2)` 권장).

### UI 요구사항

- [ ] 스낵바 텍스트 색/배경은 Flutter 기본 `SnackBar` 를 쓰되, 커스텀 색을 지정할 경우 `AppColors` 만 사용한다 (`Color(0x...)` 금지 — CLAUDE.md §2-3). 기존 파일의 스낵바 2곳이 색 지정 없이 기본값을 쓰므로 **동일하게 색 미지정 권장**.
- [ ] "문제 없음/통과" 류 메시지는 띄우지 않는다(design N1 — 위반이 있을 때만 노출되므로 자동 충족).

### 문구 (초안 — 기존 배너 보이스 기준, 개발자 미세조정 허용)

| 조건 | 문구(초안) |
|---|---|
| `validation.store != null` | `지금은 이 매장에서 주문할 수 없어요. 잠시 후 다시 시도해 주세요` |
| 그 외 (메뉴/옵션 위반) | `지금 주문할 수 없는 메뉴가 있어요. 표시된 메뉴를 확인해 주세요` |

문구는 `CartAvailabilityBanner` 의 기존 카피 톤(존댓말, 명령형 완화)을 따른다. 유형을 더 세분(품절/판매중지/옵션)하지 않는다 — 세부는 라인 뱃지와 상단 배너가 이미 지목한다.

### 상태 요구사항

- loading: 해당 없음(스낵바는 검증 완료 후 노출). 기존 `_checkingOut` 스피너 동작 유지.
- error: 해당 없음(검증 실패는 이미 `_recheck`/선검증 무음 정책으로 처리, 이번 범위 아님).
- empty: 해당 없음.

---

## 데이터 모델

변경 없음. 판정에 쓰는 기존 타입만 읽는다:

- `CheckoutValidation` (`lib/domain/entities/checkout_validation.dart`)
  - `bool get hasViolations` — 기존 게이트 조건.
  - `StoreViolation? store` — null 이 아니면 매장 단위 위반(문구 분기 기준).
  - `List<MenuViolation> menus`, `List<LineOptionIssue> optionIssues` — 메뉴/옵션 위반.

---

## 레이어 설계

### Domain

변경 없음.

### Data

변경 없음.

### Presentation

- Provider: 변경 없음.
- Page: `cart_page.dart` `_CartPageState._onCheckout` 수정(약 158~161줄 `hasViolations` 분기). 예상 수정량 5줄 내외.
- Widget: 신규 없음.

Clean Architecture: presentation 레이어 단일 파일 수정. Firebase/외부 SDK 직접 import 없음(기존 `ScaffoldMessenger` 사용). 레이어 경계 영향 없음.

---

## 데이터 흐름

```text
결제하기 탭
  → _onCheckout(cart)
  → (기존) refreshAndReprice() 선검증
  → result.validation.hasViolations == true
      → [추가] ScaffoldMessenger 스낵바 (유형별 문구)
      → (기존) _scrollToFirstViolation()
      → return  (체크아웃 진입 안 함 — 기존 동작 유지)
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 위반 존재(품절/판매중지/매장중단/옵션) | 스낵바 노출 + 첫 위반 라인으로 스크롤 + return (체크아웃 차단 유지) |
| 선검증 확인 실패(네트워크/타임아웃) | 이번 범위 아님 — 기존 정책 유지(`hasViolations == false` 로 취급되어 통과, 서버 게이트가 최종 차단) |
| 연타 | `_checkingOut` 가드로 중복 호출 무시 + 스낵바는 노출 전 기존 것 제거 |

---

## 이력 / 감사 추적 (audit_trail §4 체크리스트)

1. 돈·권한·정책 값을 바꾸는가? → **아니오.** 순수 presentation transient 피드백. **설정 변경 이력 불필요.**
2. 덮어쓰기로 사라지는 값? → 없음. **Firestore 쓰기 자체가 없다.**
3. 기록 문서가 정책 값을 참조만 하는가? → 해당 없음(기록 문서 없음).
4. "누가" 기록? → 해당 없음(운영자 행위 아님).
5. batch? → 없음.
6. CF 로그 의존? → 없음.
7. 권한 판정 필드 create/update 교차 확인? → 해당 없음(권한 필드 쓰기 없음).

→ 결론: 이력 요구사항 없음. 결제 게이트 거절 기록(`paymentGateRejections`)은 **서버 CF 전담**이며 이 변경과 무관(비범위).

## 흐름 / 라이프사이클 영향

- `role_flows.md`: customer 결제 진입 흐름의 **차단 분기 UX 보강만** — 흐름/전이 자체는 변경 없음.
- `entity_lifecycle.md`: order/menuItem status 전이 변경 없음(체크아웃에 진입하지 않으므로 order 생성조차 일어나지 않음).

---

## 작업 분배

### designer

- UI 변경 필요 여부: **최소 — designer 생략.** 신규 화면/레이아웃/컴포넌트 없음. 기존 파일에 이미 있는 스낵바 패턴을 그대로 쓰며, 추가되는 것은 유형별 문구 2종뿐이다(위 "문구" 표 제공). 디자인 시스템 판단이 필요한 새 비주얼 요소 없음.
- 디자인 산출물: 없음(design.md 생략, 본 spec 의 문구 표로 대체).

### developer

- 구현 항목: `cart_page.dart` `_onCheckout` 의 `hasViolations` 분기에 유형별 스낵바 추가(스크롤 유지). 노출 전 기존 스낵바 제거.
- 재사용할 기존 구조: 같은 파일의 `ScaffoldMessenger.of(context).showSnackBar(...)` 패턴(F1·`_recheck`), `result.validation.store` 분기.
- 주의할 레이어 규칙: presentation 단일 파일. `AppColors` 외 색상 금지(색 미지정 권장). `CheckoutBlockedSheet` 도입 금지. 가격 변동 분기 손대지 말 것.
- implementation.md 작성.

### tester

- 주요 검증 기준:
  - 품절 메뉴 포함 상태에서 `결제하기` → 스낵바가 뜨고 체크아웃에 진입하지 않음.
  - 매장 영업중단(`store != null`) 위반 → 매장용 문구가 뜸.
  - 메뉴/옵션 위반 → 메뉴용 문구가 뜸.
  - 짧은 카트(스크롤 변화 없음)에서도 피드백이 보임 = 무반응 해소.
  - 위반 없는 정상 카트 → 스낵바 없이 그대로 체크아웃 진입(회귀).
  - 연타 시 스낵바가 쌓이지 않음.
- 반드시 확인할 예외 케이스: 가격 변동만 있는 경우(위반 아님)에는 품절 스낵바가 뜨지 않아야 함.
- `flutter analyze` 통과 / `AppColors` 외 색상 미사용.

---

## 완료 기준

- [ ] 품절/판매중지/매장중단/옵션 위반 시 `결제하기` 가 더 이상 무반응이 아님(스낵바 노출).
- [ ] 스크롤(`_scrollToFirstViolation`) 동작 유지.
- [ ] 서버 게이트/선검증/가격 분기 미변경.
- [ ] `design.md`: UI 변경 없음으로 생략 명시(본 spec 문구 표 사용).
- [ ] `implementation.md` 작성 완료.
- [ ] `test_report.md` 작성 완료.
- [ ] FAIL 항목 없음 또는 후속 분리.
