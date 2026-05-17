# 주문 플로우 Phase 1b 구현 내역 (Cart 본구현)

## 구현 파일 목록

### 신규 — Domain
- `lib/domain/usecases/watch_cart_use_case.dart` — `Stream<CartEntity?> call()` (활성 카트 stream)
- `lib/domain/usecases/add_to_cart_use_case.dart` — `call({storeId, storeName, item})` → `repository.addItem`
- `lib/domain/usecases/update_cart_item_quantity_use_case.dart` — `call({cartItemId, quantity})`
- `lib/domain/usecases/remove_cart_item_use_case.dart` — `call(cartItemId)`
- `lib/domain/usecases/clear_cart_use_case.dart` — `call()`

> entity / repository 인터페이스 (`CartEntity`, `CartItemEntity`, `SelectedOption`, `CartRepository`) 는 Phase 1a 에서 모델/시그니처만 만들어 둔 것을 그대로 사용. 이번 phase 에서 추가 변경 없음.

### 신규 — Data
- `lib/data/datasources/local/cart_local_data_source.dart`
  - `CartEntity? _current` + `StreamController<CartEntity?>.broadcast()` 보유
  - `Stream<CartEntity?> watch() async*` — 구독 시 즉시 `_current` replay 후 broadcast forward
  - `addItem({storeId, storeName, item})` — storeId 불일치 시 `ArgumentError` (호출자가 사전에 `clearCart` 해야 함). 동일 dedupKey 라인이면 quantity / lineTotal 머지, 아니면 신규 추가, subtotal 재계산
  - `updateQuantity({cartItemId, quantity})` — quantity ≤ 0 면 `removeItem` 위임
  - `removeItem(cartItemId)` — 마지막 라인 제거 시 카트 자체 null emit
  - `clearCart()` — 카트 null emit (이미 null 이면 no-op)
  - `_dedupKey(item)` = `"${menuItemId}|sortedJoin('${groupId}:${itemId}',',')}"` (선택 순서 무관 안정 키)
- `lib/data/repositories/cart_repository_impl.dart` — DataSource 위임 (Stream / addItem / updateQuantity / removeItem / clearCart)

### 신규 — Presentation
- `lib/presentation/customer/cart/providers/cart_providers.dart`
  - DI: `cartLocalDataSourceProvider` (with `ref.onDispose(ds.dispose)`) → `cartRepositoryProvider` → 5개 useCase Provider
  - `cartProvider` = `StreamProvider<CartEntity?>` — `watchCartUseCase().call()`
  - `cartItemCountProvider` = `Provider<int>` — 라인 quantity 합산 (뱃지용)
- `lib/presentation/customer/cart/widgets/cart_line_tile.dart` — 80×80 thumb + 메뉴명 + 닫기 아이콘 + 옵션 요약 (`selectedOptions.map(label).join(' · ')`) + `QuantityStepper` + `lineTotal` 가격
- `lib/presentation/customer/cart/cart_page.dart`
  - AppBar: 뒤로 + "장바구니" + "비우기" 액션 (확인 다이얼로그 → `clearCartUseCase`)
  - body: `AnimatedSwitcher` (`_CartList` ↔ `_EmptyCart`)
  - `_CartList`: 매장 헤더 카드 + `SliverList.separated` (`CartLineTile`) — quantity 변경 / 라인 삭제 use case 와이어
  - `_EmptyCart`: 아이콘 + 안내 + "메뉴 보러가기" CTA (뒤로가기)
  - `_CheckoutBar`: 합계 + "결제하기" 버튼 — Phase 3 placeholder SnackBar (`'결제는 준비 중입니다 (Phase 3)'`)

### 수정 — Phase 1a 화면 와이어
- `lib/presentation/customer/order/store/store_menu_page.dart`
  - `_AppBar` → `ConsumerWidget` 으로 전환, `cartItemCountProvider` watch
  - `_CartIconButton` 신설: `Stack` (cart icon + 우상단 빨간 뱃지). `count > 99` 면 `99+` 표기. `count == 0` 이면 뱃지 숨김
  - 카트 아이콘 onTap → `Navigator.push(MaterialPageRoute(builder: (_) => CartPage()))`
  - 메뉴 카드 onTap → `MenuItemDetailPage(storeId, storeName, menuItemId)` (storeName 신규 전달)
  - `_showCartPlaceholder` placeholder 함수 제거
- `lib/presentation/customer/order/menu/menu_item_detail_page.dart`
  - `MenuItemDetailPage` 생성자에 `required this.storeName` 추가
  - `_BottomAction` → `ConsumerStatefulWidget` 으로 전환 (로컬 `_busy` 상태 보유). `(menuItemKey, menuItem: MenuItemEntity, storeName: String)` 시그니처 — 카트 아이템 빌드/표시명에 필요
  - busy / !ready 동안 버튼 disabled. busy 시 child 가 `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)` 로 교체. `disabledBackgroundColor`/`disabledForegroundColor` 도 활성과 동일 (busy 동안 색상 유지)
  - `_onAddPressed` async 흐름:
    1. `!ready` → 누락 그룹 SnackBar
    2. 활성 카트 storeId ≠ 현재 storeId → `_confirmReplaceCart` 다이얼로그 (title `'기존 카트를 비울까요?'`, content `'다른 매장의 카트가 있어요.\n비우고 새 매장으로 시작할까요?'`) → 확인 시 `clearCartUseCase().call()`
    3. `setState(() => _busy = true)` → 옵션 그룹/선택/수량 read → `SelectedOption` 스냅샷 + `unitPriceWithOptions` (basePrice + Σ priceDelta) 계산
    4. `CartItemEntity(cartItemId: Uuid().v4(), …, lineTotal: unit×qty)` 빌드
    5. `addToCartUseCase().call(storeId, storeName, item)` → 성공 시 `Navigator.pop()` + `'카트에 담겼어요'` SnackBar
    6. catch → busy false 복구 + `'담기에 실패했어요. 잠시 후 다시 시도해주세요'` SnackBar (예외 toString 노출 안 함)

### 의존성
- `pubspec.yaml` — `uuid: ^4.5.1` 추가 (cartItemId 생성)

---

## 주요 결정사항

- **In-memory only**: `CartLocalDataSource` 는 단일 인스턴스 (Provider 트리에서 `ref.onDispose(ds.dispose)`) 가 메모리에 카트를 보유. 앱 재시작 시 초기화 (umbrella 결정 5). Firestore 영속화는 비범위.
- **Stream replay**: `StreamController.broadcast()` 는 기본적으로 latest 를 replay 하지 않으므로, `watch()` 를 `async*` 로 만들어 구독 직후 `yield _current` → `yield* _controller.stream` 으로 최신값 즉시 노출. UI 구독 타이밍에 무관하게 일관된 초기 상태.
- **Dedup key**: `(groupId:itemId)` 페어를 정렬 후 join 하여 메뉴아이템 + 옵션 조합을 안정적으로 식별. 동일 메뉴라도 옵션이 다르면 다른 라인. 옵션이 같으면 quantity 만 누적.
- **Subtotal 재계산**: `addItem` / `updateQuantity` / `removeItem` 모든 mutate 후 `_subtotal(items)` 헬퍼로 항상 재계산 — 단일 진실원.
- **빈 상태 전이**: 마지막 라인 제거 시 카트 자체를 null emit. UI 는 `cartProvider.value == null || items.isEmpty` 에서 `_EmptyCart` 분기. `AnimatedSwitcher` 로 200ms cross-fade.
- **매장 충돌 방어**: `CartLocalDataSource.addItem` 가 storeId mismatch 시 `ArgumentError` 를 던진다 — UI 는 사전에 `clearCart` 호출하는 책임을 진다. 이중 안전장치(데이터 레이어가 silent merge 하지 않게).
- **충돌 다이얼로그 UX**: `MenuItemDetailPage._BottomAction` 에서 `cartProvider.value` read → 다른 매장이면 다이얼로그 (`'다른 매장의 카트가 있어요'` / `'"{storeName}" 의 담은 메뉴를 비우고 시작할까요?'` / 취소·비우고 시작). `error` 컬러 강조.
- **선택 옵션 스냅샷**: `SelectedOption` 으로 `groupId/groupName/itemId/label/priceDelta` 시점 캡처해 카트에 박는다. 추후 옵션 정의가 바뀌어도 카트 라인은 안정적으로 표시 / 합산 가능.
- **카트 뱃지 색**: `AppColors.error` 배경 + `AppColors.onPrimary` 텍스트 + `AppColors.background` 1.5px 보더 (아이콘과 분리감). `count > 99` → `99+`.
- **카트 진입 점**: 빈 카트도 동일 페이지 진입 (별도 SnackBar 분기 없음 — spec 결정). `CartPage._EmptyCart` 가 직접 친절한 안내 + "메뉴 보러가기" CTA 제공.
- **결제 버튼**: Phase 3 placeholder SnackBar `'결제는 준비 중입니다 (Phase 3)'`. 합계 표시는 정상 작동.
- **routing**: 기존 코드베이스 패턴(`Navigator.push(MaterialPageRoute(...))`) 유지. go_router 미사용.
- **build_runner**: 신규 freezed/json_serializable 추가는 없음 (entity 들은 Phase 1a 에서 이미 생성됨). build_runner 1회 실행으로 변동 없음 확인.

---

## 테스트 포인트

### 카트 본 동작
1. **빈 상태 진입**: StoreMenuPage 진입 직후 우상단 카트 아이콘 뱃지 없음. 아이콘 탭 시 `CartPage` 가 열리고 `_EmptyCart` 노출. "메뉴 보러가기" 탭 시 뒤로 pop.
2. **첫 라인 추가**: 메뉴 상세 → 옵션 선택 → "담기" 탭 시
   - 상세 페이지가 닫히고 `'카트에 담겼어요'` SnackBar
   - StoreMenuPage 카트 아이콘 뱃지에 1 표시
3. **동일 옵션 재추가**: 같은 메뉴 + 같은 옵션을 다시 담으면 라인은 1개 유지, quantity 만 증가
4. **다른 옵션 추가**: 같은 메뉴라도 옵션이 다르면 라인 분리
5. **수량 +/-**: `CartLineTile` `QuantityStepper` 변경 시 lineTotal / subtotal 즉시 갱신
6. **라인 삭제**: 닫기 아이콘 탭 시 라인 제거. 마지막 라인 제거 시 페이지가 `_EmptyCart` 로 전환되고 `_CheckoutBar` 사라짐
7. **카트 비우기**: AppBar 우상단 "비우기" → 확인 다이얼로그 → 비움 → `_EmptyCart`
8. **카트 뱃지 합산**: 라인 여러 개 + 각 quantity 합 = 뱃지 숫자. 합이 100 이상이면 `99+`

### 매장 충돌
9. **다른 매장 메뉴 담기 — 취소**: 매장 A 카트 보유 상태에서 매장 B 메뉴 "담기" → 다이얼로그에서 "취소" → 카트 변경 없음, 상세 페이지 유지
10. **다른 매장 메뉴 담기 — 비우고 시작**: 같은 상황에서 "비우고 시작" → 카트 비워지고 매장 B 라인 1개로 시작, `Navigator.pop` + `'카트에 담겼어요'` SnackBar

### 필수 옵션 / 합계
11. **필수 그룹 미선택**: "담기" 비활성 컬러 (`AppColors.surface` + `textMuted`). 탭 시 `'그룹명 을(를) 선택해주세요'` SnackBar
12. **합계 실시간**: 옵션 / 수량 변경 시 BottomAction 합계 = (basePrice + Σ priceDelta) × qty
13. **음수 priceDelta (텀블러 -300)**: 합계 정확히 차감

### 결제 placeholder
14. **결제하기 버튼**: `_CheckoutBar` 의 "결제하기" 탭 시 `'결제는 준비 중입니다 (Phase 3)'` SnackBar

### Stream 일관성
15. **카트 페이지 즉시 표시**: StoreMenuPage 에서 카트 아이콘으로 진입했을 때 `cartProvider.value` 가 `null` 깜빡임 없이 즉시 데이터 표시 (latest replay)
16. **Provider 재구독**: 페이지 pop/push 반복 시 카트 상태 유지

---

## 미구현 / 보류

- **영속화**: SharedPreferences / Hive / Firestore 영속화는 Phase 1b 비범위. 앱 재시작 시 카트 비워짐.
- **즐겨찾기 토글**: 그대로 placeholder SnackBar (Phase 1c).
- **결제**: `_CheckoutBar` 의 "결제하기" 는 Phase 3 placeholder.
- **로그인 게이팅**: 카트 담기/조회는 비로그인 상태에서도 작동 (umbrella 결정 따름). 결제 단계에서 분기 예정.
- **옵션 재선택 UX**: 카트 라인의 옵션을 사후 변경하는 UI 없음. 변경하려면 라인 제거 후 다시 담기.

---

## 명령어 결과

- `dart run build_runner build --delete-conflicting-outputs` — 1 output, no errors
- `flutter analyze` — `No issues found! (ran in 5.6s)` (lib 전체)
- `flutter test` — Phase 1b 신규 테스트 추가 없음 (수동 검증 항목은 위 테스트 포인트 참조)
