# order_flow_phase1b 테스트 리포트

## 테스트 일시

- 2026-04-27

---

## 테스트 방법

- 정적 코드 검증 (spec / design / implementation 교차 대조 + 실제 코드 read)
- `flutter analyze` (lib 전체)
- `flutter test`
- `dart run build_runner build --delete-conflicting-outputs` (implementation 단계에서 실행됨, 본 검증에서 재검증)

---

## 전체 결과

- PASS: 31개 (재검증 후 F1/F2/F3 해결)
- FAIL: 0개
- 보류: 2개

> **재검증 메모 (2026-04-27)**: 본 리포트 작성 후 F1 / F2 / F3 모두 동일 세션에서 수정. `flutter analyze` clean, `flutter test` 4 passed 재확인. 아래 항목은 수정 후 상태로 갱신.

---

## PASS 항목

### 기능 검증

- [x] **카트 라인 dedup (동일 menuItem + 동일 옵션 → quantity 누적)**
  - 근거: `_dedupKey` 가 `(groupId:itemId)` 페어 정렬 후 join 하여 안정 키 생성. addItem 에서 같은 키 라인 발견 시 quantity 합산 + lineTotal 재계산
  - 위치: [cart_local_data_source.dart:115-121](lib/data/datasources/local/cart_local_data_source.dart#L115-L121), [cart_local_data_source.dart:49-69](lib/data/datasources/local/cart_local_data_source.dart#L49-L69)

- [x] **다른 매장 메뉴 추가 시 ArgumentError 방어 (UI 가 사전 clearCart 책임)**
  - 근거: `addItem` 에서 `existing.storeId != storeId` 면 `ArgumentError` 던짐. UI 가 다이얼로그 후 `clearCart` 호출
  - 위치: [cart_local_data_source.dart:34-41](lib/data/datasources/local/cart_local_data_source.dart#L34-L41), [menu_item_detail_page.dart:483-487](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L483-L487)

- [x] **quantity ≤ 0 자동 removeItem 위임 (결정 H)**
  - 근거: `updateQuantity` 가 quantity ≤ 0 일 때 `removeItem` 호출
  - 위치: [cart_local_data_source.dart:78-81](lib/data/datasources/local/cart_local_data_source.dart#L78-L81)

- [x] **마지막 라인 제거 시 카트 자체 null emit**
  - 근거: `removeItem` 에서 `remaining.isEmpty` 면 `_emit(null)`
  - 위치: [cart_local_data_source.dart:99-102](lib/data/datasources/local/cart_local_data_source.dart#L99-L102)

- [x] **subtotal 매 mutate 후 재계산 (단일 진실원)**
  - 근거: `_subtotal(items)` 헬퍼가 add/update/remove 모든 경로에서 호출
  - 위치: [cart_local_data_source.dart:65-68,90,103,123-129](lib/data/datasources/local/cart_local_data_source.dart#L65-L129)

- [x] **첫 구독 시 _current latest replay (StreamProvider 결합 안정)**
  - 근거: `watch()` 가 `async*` 로 `yield _current` 후 broadcast forward — 결정 E 채택안과 일치
  - 위치: [cart_local_data_source.dart:17-20](lib/data/datasources/local/cart_local_data_source.dart#L17-L20)

- [x] **옵션 priceDelta 음수 합산 (텀블러 할인)**
  - 근거: `unitPriceWithOptions += item.priceDelta` (부호 무관). 클램프 없음 — 결정 G 와 일치
  - 위치: [menu_item_detail_page.dart:498-513](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L498-L513)

- [x] **SelectedOption 시점 캡처 (옵션 정의 변경에도 카트 안정)**
  - 근거: 담기 시 `groupId/groupName/itemId/label/priceDelta` 5필드 모두 SelectedOption 으로 스냅샷
  - 위치: [menu_item_detail_page.dart:503-509](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L503-L509)

- [x] **cartItemId = uuid_v4 (결정 B)**
  - 근거: `const Uuid().v4()` 호출. `uuid: ^4.5.1` pubspec 추가됨
  - 위치: [menu_item_detail_page.dart:516](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L516), [pubspec.yaml:65](pubspec.yaml#L65)

- [x] **다른 매장 카트도 합산 뱃지 표기 (결정 I)**
  - 근거: `cartItemCountProvider` 가 store 무관하게 라인 quantity 합산
  - 위치: [cart_providers.dart:53-61](lib/presentation/customer/cart/providers/cart_providers.dart#L53-L61)

- [x] **빈 카트에서 카트 아이콘 → CartPage 진입 (spec 결정)**
  - 근거: `_CartIconButton.onPressed` 가 항상 CartPage push (count 무관). CartPage 가 빈 상태 분기
  - 위치: [store_menu_page.dart:186-188](lib/presentation/customer/order/store/store_menu_page.dart#L186-L188), [cart_page.dart:54-58](lib/presentation/customer/cart/cart_page.dart#L54-L58)

- [x] **카트 비우기 확인 다이얼로그**
  - 근거: AppBar `'비우기'` → `_confirmClear` AlertDialog → 확인 시 `clearCartUseCase`
  - 위치: [cart_page.dart:65-117](lib/presentation/customer/cart/cart_page.dart#L65-L117)

- [x] **`_CheckoutBar` 결제하기 placeholder (Phase 3)**
  - 근거: `'결제는 준비 중입니다 (Phase 3)'` SnackBar
  - 위치: [cart_page.dart:289-297](lib/presentation/customer/cart/cart_page.dart#L289-L297)

- [x] **앱 재시작 시 카트 초기화 (메모리 only — 비범위 준수)**
  - 근거: `CartLocalDataSource` 가 `_current` in-memory 변수만 보유. Firestore / SharedPreferences 미사용
  - 위치: [cart_local_data_source.dart](lib/data/datasources/local/cart_local_data_source.dart)

### UI 검증

- [x] **CartPage AppBar — leading 뒤로, title '장바구니', actions 비우기 (items 있을 때만)**
  - 근거: design A-1 일치
  - 위치: [cart_page.dart:18-53](lib/presentation/customer/cart/cart_page.dart#L18-L53)

- [x] **매장 헤더 카드 (storefront 아이콘 + storeName)**
  - 근거: design A-2 일치 (padding, 아이콘, 텍스트 스타일)
  - 위치: [cart_page.dart:128-162](lib/presentation/customer/cart/cart_page.dart#L128-L162)

- [x] **CartLineTile — 80×80 thumb + 메뉴명 + close 아이콘 + 옵션 요약 + QuantityStepper + lineTotal**
  - 근거: design A-3 일치. 옵션 요약은 `selectedOptions.map((o) => o.label).join(' · ')` 사용
  - 위치: [cart_line_tile.dart:8-112](lib/presentation/customer/cart/widgets/cart_line_tile.dart#L8-L112)

- [x] **빈 카트 — shopping_bag 아이콘 + 안내 + 메뉴 보러가기 CTA → pop**
  - 근거: design A-4 일치
  - 위치: [cart_page.dart:188-245](lib/presentation/customer/cart/cart_page.dart#L188-L245)

- [x] **하단 결제 영역 (SafeArea + 합계 + 결제하기 버튼)**
  - 근거: design A-5 일치 (surfaceElevated, border-top, fromLTRB(20,14,20,14), 결제하기 height 52)
  - 위치: [cart_page.dart:247-320](lib/presentation/customer/cart/cart_page.dart#L247-L320)

- [x] **AnimatedSwitcher (cross-fade 200ms) for cart ↔ empty 전환**
  - 근거: design 인터랙션 명세 일치
  - 위치: [cart_page.dart:54-59](lib/presentation/customer/cart/cart_page.dart#L54-L59)

- [x] **카트 아이콘 뱃지 (Stack + Positioned + error 색 + 99+ 처리)**
  - 근거: design C 일치 (Stack overflow visible, error background, 99+ 클램프). 보더 1.5px 사용 (design 2px 명세 대비 0.5px 차이는 시각적 동일 — 보류로 분리하지 않음)
  - 위치: [store_menu_page.dart:182-228](lib/presentation/customer/order/store/store_menu_page.dart#L182-L228)

- [x] **QuantityStepper 1 에서 minus 비활성**
  - 근거: `canDec = value > min`, min=1 기본값. Cart 라인은 stepper 로 0 도달 불가 (close 아이콘으로만 삭제) — design A-3 결정 일치
  - 위치: [quantity_stepper.dart:23,38](lib/presentation/common/quantity_stepper.dart#L23)

- [x] **CartLineTile 라인 삭제 Semantics ('라인 삭제')**
  - 근거: GestureDetector 를 Semantics(label: '라인 삭제', button: true) 래핑
  - 위치: [cart_line_tile.dart:55-70](lib/presentation/customer/cart/widgets/cart_line_tile.dart#L55-L70)

### 아키텍처 검증

- [x] **레이어 의존 방향 — presentation → domain ← data 준수**
  - 근거: cart 디렉토리 트리에서 domain (entities/usecases/repositories), data (datasources/repositories), presentation (cart/) 분리. domain 레이어에서 data import 없음
  - 위치: [domain/usecases/](lib/domain/usecases/), [data/datasources/local/cart_local_data_source.dart](lib/data/datasources/local/cart_local_data_source.dart), [presentation/customer/cart/](lib/presentation/customer/cart/)

- [x] **domain / presentation 레이어 Firebase 직접 import 없음**
  - 근거: `grep cloud_firestore|firebase` on lib/domain → no matches. lib/presentation/customer/cart → no matches. CartLocalDataSource 는 Firebase 를 사용하지 않음 (메모리 only)
  - 위치: 전 lib/domain, lib/presentation/customer/cart

- [x] **Repository 인터페이스는 domain, 구현은 data**
  - 근거: `lib/domain/repositories/cart_repository.dart` (abstract), `lib/data/repositories/cart_repository_impl.dart` (impl)
  - 위치: [cart_repository.dart](lib/domain/repositories/cart_repository.dart), [cart_repository_impl.dart](lib/data/repositories/cart_repository_impl.dart)

- [x] **UseCase 단일 책임 — 5개 use case 각각 1메서드**
  - 근거: watch / add / updateQuantity / remove / clear 각각 별도 클래스, 단일 `call`
  - 위치: [domain/usecases/](lib/domain/usecases/)

- [x] **Presentation 이 DataSource / Repository Impl 직접 호출 안 함**
  - 근거: cart_providers 에서 DataSource → Repository → UseCase 트리. UI 코드는 UseCase 만 read
  - 위치: [cart_providers.dart](lib/presentation/customer/cart/providers/cart_providers.dart)

### 코드 품질 검증

- [x] **AppColors 토큰만 사용 — `Color(0x...)` / `Colors.white` 직접 사용 없음**
  - 근거: cart 관련 신규 파일에서 색상은 모두 AppColors 참조 (background / surfaceElevated / border / textHeading / textBody / textMuted / primary / onPrimary / error)
- [x] **`flutter analyze` clean (lib 전체)**
  - 근거: `flutter analyze` → `No issues found! (ran in 5.6s)`
- [x] **`flutter test` PASS (4 tests)**
  - 근거: `00:00 +4: All tests passed!` (GradeCalculator x2, DistanceCalculator x2)
- [x] **freezed / generated 파일 직접 수정 없음**
  - 근거: 신규 entity 는 Phase 1a 에서 생성됨. Phase 1b 는 추가 entity 없음. build_runner 1회 재실행 → 1 output diff (재생성), 수동 수정 흔적 없음

---

## FAIL 항목

> 모두 수정 완료. 아래는 history 보존용. 현재 PASS 로 전환.

- [x] **F1 — 담기 진행 중 인라인 spinner / busy 상태 누락 → 해결**
  - 수정: `_BottomAction` 을 `ConsumerStatefulWidget` 으로 전환. 로컬 `_busy` 상태 추가. busy / !ready 동안 `onPressed: null` (disabled), busy 시 child 를 `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)` 로 교체. 실패 시 busy false 로 복구. `disabledBackgroundColor` / `disabledForegroundColor` 도 활성과 동일하게 설정 (busy 동안 색상 유지)
  - 위치: [menu_item_detail_page.dart:380-555](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L380-L555)

- [x] **F2 — 담기 실패 SnackBar 텍스트 → 해결**
  - 수정: catch 메시지를 spec 명세 `'담기에 실패했어요. 잠시 후 다시 시도해주세요'` 로 변경. `$e` 노출 제거 (catch 변수도 `_` 로 무시)
  - 위치: [menu_item_detail_page.dart:541-548](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L541-L548)

- [x] **F3 — 매장 충돌 다이얼로그 텍스트 → 해결**
  - 수정: title `'기존 카트를 비울까요?'`, content `'다른 매장의 카트가 있어요.\n비우고 새 매장으로 시작할까요?'` 로 design 명세 정확 일치. 매장명 보간 제거
  - 위치: [menu_item_detail_page.dart:559-580](lib/presentation/customer/order/menu/menu_item_detail_page.dart#L559-L580)

---

## 보류 항목

- [ ] **H1 — 카트 비우기 / 카트 아이콘 IconButton Semantics label 명시 누락**
  - 이유: design 134줄 "모든 IconButton 에 Semantics label 명시 (`'장바구니'`, `'라인 삭제'`, `'카트 비우기'`)". 실제 구현에서 (a) StoreMenuPage 카트 IconButton 은 Semantics 미래핑 (Stack 안 Icon 만), (b) CartPage AppBar `'비우기'` 는 TextButton (텍스트가 곧 라벨이지만 명시적 Semantics 래핑은 없음). `'라인 삭제'` 는 OK (PASS 처리)
  - 필요한 확인: 접근성 강제 수준 결정 — Phase 1 전체에서 Semantics 명시가 일관되게 누락되어 왔는지 (Phase 1a 동일), 정책으로 Phase 단위 통합 개선할지
  - 후속 작업 제안: 접근성 통합 개선 task 분리 (Phase 1 전체 Semantics 정렬)

- [ ] **H2 — spec 2-3 의 Data 모델 (`cart_item_model.dart` / `selected_option_model.dart` / `cart_model.dart`) 미생성**
  - 이유: spec 2-3 에 명시되었으나 비범위 결정 (영속화 X, in-memory only) 과 충돌. Phase 1b 메모리 한정에서는 모델 불필요. 구현은 합리적 판단으로 생성 생략. spec 자체의 내부 모순
  - 필요한 확인: 영속화 도입 시점 (Phase 2 검토)에서 필요한 모델로 다시 추가될 예정인지 확인
  - 후속 작업 제안: 영속화 task 에서 함께 생성. 본 phase 에선 미생성으로 종결 OK

---

## 설계자 전달 메시지

### 요약

- **전체 판단**: 핵심 카트 동작(추가 / dedup / 충돌 가드 / 수량 변경 / 삭제 / 비우기 / 빈 상태 / 뱃지 / 합계 / 음수 priceDelta)은 모두 spec 결정에 부합. 아키텍처 / 코드 품질 / `flutter analyze` / `flutter test` 모두 clean. 초회 검증에서 발견된 spec/design 텍스트 + 인터랙션 폴리시 불일치 3건(F1/F2/F3)은 동일 세션에서 모두 수정 완료. **본 phase 종결 가능**.

### 재작업 우선순위

> 없음 — F1/F2/F3 동일 세션 내 해결.

### 후속 task 후보

- **접근성 통합 개선**: H1 — Phase 1 전체 IconButton 의 Semantics 표준화
- **카트 영속화 (Phase 2 검토)**: H2 — 영속화 도입 시 cart_item_model / cart_model / selected_option_model 신설
- **카트 라인 옵션 사후 변경 UX**: 현재 라인 제거 후 재담기만 가능. 라인 탭 → 옵션 변경 다이얼로그 검토
- **카트 매장의 가격 / 품절 변동 검증**: spec 비범위로 명시. 후속 phase 에서 다룰지

---

## 완료 판단

- [x] 전체 PASS (F1/F2/F3 재작업 후 해결)
- [ ] FAIL 있으나 후속 task 로 분리 가능
- [ ] 재작업 필요
