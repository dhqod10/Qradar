# 주문 플로우 Phase 1b 사양 (Cart 본구현)

> **단일 진실원**: 데이터 모델/도메인 결정사항은 [umbrella spec](../order_flow_phase1/spec.md) 을 따른다. 본 문서는 Phase 1b 운영 범위만 좁혀 정의한다.

## 1. 목적

Phase 1a 에서 만든 메뉴 / 옵션 / 수량 상태와 placeholder "담기" 버튼을 **실제 카트 상태**에 연결한다. 카트 페이지를 신규로 만들고, 다른 매장 메뉴를 담을 때의 충돌을 다이얼로그로 해결한다. 결제는 본 작업 비범위 (Phase 3).

## 2. 범위

### 2-1. 신규 화면
- `CartPage` — 매장 헤더 + 라인 리스트 + 합계 + "결제하기" placeholder + 빈 상태.

### 2-2. Domain
- 신규 entity (freezed):
  - `lib/domain/entities/cart_entity.dart` (`storeId`, `storeName`, `items: List<CartItemEntity>`, `subtotal`)
  - `lib/domain/entities/cart_item_entity.dart` (umbrella spec 5번 결정 따름)
  - `lib/domain/entities/selected_option.dart` (`groupId`, `groupName`, `itemId`, `label`, `priceDelta`)
- 기존 인터페이스 `lib/domain/repositories/cart_repository.dart` 의 시그니처 확정:
  - `Stream<CartEntity?> watchCart()`
  - `Future<void> addItem(CartItemEntity item, {required String storeId, required String storeName})`
  - `Future<void> updateQuantity(String cartItemId, int quantity)`
  - `Future<void> removeItem(String cartItemId)`
  - `Future<void> clear()`
- 신규 usecase:
  - `lib/domain/usecases/watch_cart_use_case.dart`
  - `lib/domain/usecases/add_to_cart_use_case.dart`
  - `lib/domain/usecases/update_cart_item_quantity_use_case.dart`
  - `lib/domain/usecases/remove_cart_item_use_case.dart`
  - `lib/domain/usecases/clear_cart_use_case.dart`

### 2-3. Data
- 신규 model (freezed + json_serializable 또는 manual):
  - `lib/data/models/cart_item_model.dart`
  - `lib/data/models/selected_option_model.dart`
  - `lib/data/models/cart_model.dart`
- 신규 datasource (메모리만):
  - `lib/data/datasources/local/cart_local_data_source.dart` — `StreamController<CartEntity?>` 보유, in-memory 상태. 앱 재시작 시 초기화 (umbrella 결정 5).
- 신규 repository impl:
  - `lib/data/repositories/cart_repository_impl.dart` — Local DataSource 위임.

### 2-4. Presentation
- 신규 providers:
  - `lib/presentation/customer/cart/providers/cart_providers.dart`
    - `cartLocalDataSourceProvider` / `cartRepositoryProvider` / `cartUseCasesProvider` (DI)
    - `cartProvider` (StreamProvider) — 활성 카트 (`CartEntity?`)
    - `cartItemCountProvider` (Provider) — 합산 quantity (뱃지용)
- 신규 widgets:
  - `lib/presentation/customer/cart/widgets/cart_line_tile.dart`
- 페이지: `lib/presentation/customer/cart/cart_page.dart`
- **Phase 1a 화면 수정**:
  - `MenuItemDetailPage` "담기" 버튼 onTap → `addToCartUseCase` 호출 + 매장 충돌 시 다이얼로그 → 성공 시 `Navigator.pop()` + `'카트에 담겼어요'` 토스트
  - `StoreMenuPage` 우상단 카트 아이콘:
    - 카트 비어있으면 회색 + 탭 시 "카트가 비어있어요" 스낵바 (혹은 빈 카트 페이지로 이동해도 OK — 결정: **빈 카트 페이지로 이동**)
    - 라인이 1개 이상이면 primary 색 + 빨간 점/숫자 뱃지 (다른 매장 카트라도 표시)
    - onTap → `Navigator.push(MaterialPageRoute(builder: (_) => CartPage()))`

### 2-5. 비범위
- 영속화 (앱 재시작 시 초기화 OK — umbrella 결정 5).
- 즐겨찾기 (Phase 1c).
- 결제 / OrderLog 기록 (Phase 3).
- 다국어, 다크 모드, 접근성 추가 처리.
- 카트 매장의 음료 가격/품절 변동 검증 (umbrella 라인 508 참조 — Phase 1 비대응).

## 3. 핵심 결정사항

### 결정 A. 라우팅 — Navigator push 유지 (go_router 미도입)
- Phase 1a 가 `Navigator.push(MaterialPageRoute(...))` 로 통일돼 있음. CartPage 도 동일하게 `Navigator.push` 로 진입.
- umbrella spec 의 `/cart` 경로는 go_router 도입 시점에 일괄 적용. **본 phase 비범위.**

### 결정 B. 카트 라인 식별 키
- `cartItemId = uuid_v4`. 동일 menuItem + 동일 옵션 조합인 경우 새 라인 추가 대신 기존 라인 quantity 증가.
- 옵션 조합 동등성 = `selectedOptions` 의 `(groupId, itemId)` Set 비교.

### 결정 C. 매장 충돌 다이얼로그
- 활성 카트의 `storeId != newItem.storeId` 일 때 `addToCartUseCase` 호출 전에 UI 가 다이얼로그 표시 → 사용자 승인 시 `cartRepository.clear()` 후 `addItem` (UseCase 1회 호출 안에서 묶지 않고 UI 가 흐름 제어).
- 다이얼로그 본문: "기존 매장의 카트가 있어요. 비우고 새 매장으로 시작할까요?" / 버튼: "취소", "비우고 시작".
- 사용자가 취소 시 그대로 종료 (현재 옵션 선택은 유지).

### 결정 D. UUID 의존성
- `package:uuid` 추가. (이미 사용 중인 다른 식별자 발급 위치가 없으면 신규 의존성 추가.)

### 결정 E. CartLocalDataSource 구조
- `BehaviorSubject` 대신 표준 `StreamController<CartEntity?>.broadcast()` + `_current` 캐시 변수.
- 첫 구독 시 `_current` 즉시 emit (`StreamController` 만으로는 latest replay 불가하므로 `Stream` 을 만들 때 `async*` 헬퍼로 latest+broadcast 조합).
- 또는 `riverpod` 의 `StreamProvider` 가 항상 latest 를 보존하므로 LocalDataSource 가 `Stream` + `_current` getter 둘을 노출하는 방식으로 단순화. **채택**: getter + Stream 둘 다 노출 + 단일 broadcast controller.

### 결정 F. CartPage 빈 상태
- 텍스트: "카트가 비어있어요". CTA: "메뉴 보러가기" → `Navigator.pop()`.

### 결정 G. 빌드 가드
- `unitPriceWithOptions = basePrice + Σ(selectedOptions.priceDelta)` (음수 허용 — 텀블러 할인).
- `lineTotal = unitPriceWithOptions × quantity`.
- `subtotal = Σ lineTotal`.
- 음수 합계는 0 으로 클램프 하지 않음 (옵션이 항상 음수 합산 메뉴는 비현실적). 단, 표기 시 `formatKrw` 가 음수도 처리.

### 결정 H. quantity 변경 — UseCase 분리
- `updateCartItemQuantityUseCase(cartItemId, newQuantity)` — newQuantity ≤ 0 이면 자동 `removeItem`.
- CartPage 의 stepper 는 1~99 클램프, 1 에서 minus 누르면 삭제 confirm 없이 즉시 제거 (UX: stepper 가 1 에서 minus 비활성).

### 결정 I. 카트 아이콘 뱃지 노출
- StoreMenuPage 의 카트 아이콘 위치는 Phase 1a 와 동일.
- 카트가 다른 매장의 것이라도 무조건 합산 quantity 뱃지를 표시 (umbrella line 150).
- 뱃지 디자인은 designer 가 결정.

## 4. 데이터 흐름

### 4-1. 메뉴 상세 → 카트 담기
```
MenuItemDetailPage 담기 onPressed
  ├─ canAddToCart 체크 (Phase 1a 그대로)
  ├─ ref.read(cartProvider).value
  │     └─ activeCart != null && activeCart.storeId != storeId
  │         → AlertDialog (취소/비우고 시작)
  │         → 취소: return
  │         → 확인: cartRepository.clear() → 계속
  ├─ buildCartItem(...) (uuid + selectedOptions snapshot + price 계산)
  ├─ cartRepository.addItem(item, storeId, storeName)
  │     └─ 내부에서 동일 옵션 조합 기존 라인 발견 시 quantity += newQuantity
  ├─ Navigator.pop(context) (디테일 → 메뉴 페이지)
  └─ ScaffoldMessenger.showSnackBar('카트에 담겼어요')
```

### 4-2. 카트 보기
```
StoreMenuPage 카트 IconButton onTap
  → Navigator.push(MaterialPageRoute(builder: (_) => CartPage()))
CartPage build
  → ref.watch(cartProvider) → CartEntity?
  → null/empty: 빈 상태
  → otherwise: 헤더 + 라인 리스트 + 합계 + "결제하기" placeholder
```

### 4-3. 라인 수정 / 삭제
```
CartLineTile stepper +/-
  → updateCartItemQuantityUseCase(cartItemId, newQty)
       → quantity <= 0 ? removeItem : 직접 갱신
       → repository → localDataSource → emit new CartEntity (subtotal 재계산)
CartLineTile 삭제 아이콘
  → removeCartItemUseCase(cartItemId)
       → 마지막 라인이면 cart 자체 null 로 emit
```

## 5. 상태 / UI 요구

| 화면 | 로딩 | 에러 | 빈 상태 |
|---|---|---|---|
| CartPage | (메모리이므로 즉시) | 없음 | "카트가 비어있어요" + "메뉴 보러가기" CTA |
| MenuItemDetailPage 담기 진행 중 | 버튼 disabled + 인라인 spinner | catch 블록 → `'담기에 실패했어요'` SnackBar | — |

## 6. 라우팅 / 진입점

- 진입 1: `StoreMenuPage` 카트 아이콘 → `CartPage`
- 진입 2: 디테일 페이지 담기 후 자동 이동은 안 함 (메뉴 페이지로만 pop). 카트 보기는 사용자가 카트 아이콘으로.
- Bottom nav 변경 없음 (cart 는 push 화면).

## 7. 의존성 추가
- `pubspec.yaml`: `uuid: ^4.x` 추가. `flutter pub get` 필요.

## 8. 영향 범위

| 파일 | 변경 |
|---|---|
| `lib/domain/repositories/cart_repository.dart` | 시그니처 확정 (Phase 1a 의 인터페이스를 본 phase 결정대로 갱신, 미구현 메서드 채우기) |
| `lib/data/repositories/cart_repository_impl.dart` | 신규 |
| `lib/data/datasources/local/cart_local_data_source.dart` | 신규 |
| `lib/data/models/cart_*` | 신규 |
| `lib/domain/entities/cart_*` | 신규 (umbrella 모델 따름) |
| `lib/presentation/customer/cart/**` | 신규 |
| `lib/presentation/customer/order/menu/menu_item_detail_page.dart` | "담기" 버튼 실제 동작 + 충돌 다이얼로그 |
| `lib/presentation/customer/order/store/store_menu_page.dart` | 카트 아이콘 onTap + 뱃지 카운트 |
| `pubspec.yaml` | `uuid` 추가 |

## 9. 테스트 포인트 (체크리스트)

- [ ] 같은 매장 메뉴 2종 담기 → 라인 2개 + 합계 일치
- [ ] 같은 메뉴 + 같은 옵션 재담기 → 기존 라인 quantity 증가
- [ ] 같은 메뉴 + 다른 옵션 담기 → 별개 라인
- [ ] 다른 매장 메뉴 담기 → 다이얼로그 노출 → 취소 시 카트 유지
- [ ] 다른 매장 메뉴 담기 → 다이얼로그 → 확인 시 카트 비우고 새 매장으로 시작
- [ ] CartPage stepper +/− 동작 + 1 에서 −는 비활성
- [ ] CartPage 라인 삭제 → 마지막 라인 삭제 시 빈 상태로 전환
- [ ] CartPage "카트 비우기" 버튼 → 즉시 빈 상태
- [ ] StoreMenuPage 카트 아이콘 뱃지 — 다른 매장 카트도 합산 표기
- [ ] 빈 카트 상태에서 카트 아이콘 → CartPage 빈 상태 → "메뉴 보러가기" pop
- [ ] 옵션 priceDelta 음수(텀블러) 합산 → unit/line 합계 음수 허용 + 표기 정상
- [ ] 앱 재시작 시 카트 초기화 (메모리 only)
- [ ] `flutter analyze` clean

## 10. Phase 1c / Phase 3 인터페이스 영향 없음 확인
- `FavoritesRepository` / `OrderLogRepository` 인터페이스에 본 phase 의 변경 없음.
- 카트 영속화는 Phase 2 검토 항목 (umbrella 결정 5).
