# order_flow_phase1b 디자인 명세 (CartPage + 매장 충돌 다이얼로그 + 카트 뱃지)

## 참조한 디자인
- Figma: 없음. Qradar 디자인 시스템 + Phase 1a 톤(`AppColors`, store_card 카드 데코, store_map_marker_sheet 그림자) 재사용.
- 재사용 컴포넌트: `QuantityStepper` (Phase 1a), `PriceFormatter`, `AppColors`.

---

## 화면 구성

### A. CartPage

- 진입: `Navigator.push(MaterialPageRoute(builder: (_) => const CartPage()))` — 네비게이션 push.
- 레이아웃: `Scaffold` + `CustomScrollView` 또는 `Column` (라인 ListView + 하단 고정 영역).
- 배경: `AppColors.background`.

#### A-1. AppBar
- leading: `Icons.arrow_back_ios_new_rounded` (size 20, `textHeading`).
- title: `'장바구니'` (16, w700, `textHeading`).
- actions:
  - 카트가 비어있지 않을 때만 노출: `TextButton` `'비우기'` (13, w600, `error`). onPressed → 확인 다이얼로그 → `clearCartUseCase`.
- centerTitle: false. background: `AppColors.background`. elevation 0. surfaceTint transparent.

#### A-2. 매장 헤더 (cart != null && items.isNotEmpty 일 때만)
- Padding `EdgeInsets.fromLTRB(20, 12, 20, 0)`.
- Container:
  - decoration: `color: AppColors.surfaceElevated`, `borderRadius: 16`, `border: 1px AppColors.border`.
  - padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 14)`.
  - Row:
    - `Icons.storefront_outlined` (size 18, `primary`).
    - SizedBox(width: 8).
    - Expanded(child: Text(`storeName`, 14, w700, `textHeading`, ellipsis)).

#### A-3. 라인 리스트 (CartLineTile)
- ListView.separated 또는 SliverList. padding `EdgeInsets.fromLTRB(20, 12, 20, 24)`. separator `SizedBox(height: 12)`.
- 각 라인 (`CartLineTile`):
  - Container: `surfaceElevated`, `borderRadius: 16`, `border: 1px border`, padding `12`.
  - Layout (Row, crossAxisAlignment: start):
    - 좌측 80x80 Square 이미지 (CachedNetworkImage + 16 radius). 빈 url → `Icons.local_cafe_outlined` placeholder.
    - SizedBox(width: 12).
    - Expanded(Column, start):
      - Row(spaceBetween):
        - Expanded(Text(menuItemName, 14, w700, `textHeading`, maxLines: 1, ellipsis)).
        - GestureDetector: `Icons.close_rounded` (size 18, `textMuted`) — onTap → `removeCartItemUseCase`.
      - SizedBox(height: 4).
      - 옵션 요약 Text (12, w500, `textMuted`, maxLines: 2, ellipsis): `selectedOptions.map((o) => o.label).join(' · ')`. 빈 배열이면 위젯 자체 생략.
      - SizedBox(height: 8).
      - Row(spaceBetween):
        - QuantityStepper(value: quantity, min: 1, max: 99, onChanged: (q) => updateQuantityUseCase).
          - **기존 QuantityStepper 재사용**. 1 에서 minus 자동 비활성 — 마지막 라인이라도 stepper 로는 삭제하지 않음 (close 아이콘으로만 삭제).
        - Text(`PriceFormatter.formatKrw(lineTotal)`, 14, w700, `primary`).

#### A-4. 빈 상태
- `cart == null || items.isEmpty` 일 때.
- Center, Column(mainAxisSize: min):
  - `Icons.shopping_bag_outlined` (size 56, `textMuted`).
  - SizedBox(height: 12).
  - Text(`'카트가 비어있어요'`, 16, w700, `textHeading`).
  - SizedBox(height: 6).
  - Text(`'담고 싶은 메뉴를 골라보세요'`, 13, w500, `textMuted`).
  - SizedBox(height: 20).
  - ElevatedButton `'메뉴 보러가기'` — `primary` 배경, `onPrimary` 글자, padding 24x12, radius 12. onPressed → `Navigator.pop(context)`.

#### A-5. 하단 고정 결제 영역 (SafeArea 적용)
- `bottomNavigationBar` 또는 `Column` 마지막 자식.
- Container:
  - color: `surfaceElevated`. border-top: `1px AppColors.border`. padding: `EdgeInsets.fromLTRB(20, 14, 20, 14)`.
  - Column(crossAxisAlignment: stretch):
    - Row(spaceBetween):
      - Text(`'합계'`, 13, w500, `textMuted`).
      - Text(`PriceFormatter.formatKrw(subtotal)`, 18, w700, `textHeading`).
    - SizedBox(height: 12).
    - SizedBox(height: 52, child: ElevatedButton `'결제하기'`):
      - 활성: `primary` 배경 + `onPrimary` 글자, w700 16, radius 14. onPressed → SnackBar `'결제는 준비 중입니다 (Phase 3)'`.
      - 비활성(items 없음): 화면이 빈 상태로 빠지므로 이 영역 자체 노출 X.

### B. 매장 충돌 다이얼로그
- 사용처: `MenuItemDetailPage` 담기 버튼.
- 트리거: 활성 카트 storeId ≠ 현재 storeId.
- 위젯: `AlertDialog`.
  - shape: `RoundedRectangleBorder(borderRadius: 16)`.
  - backgroundColor: `surfaceElevated`.
  - title: Text(`'기존 카트를 비울까요?'`, 16, w700, `textHeading`).
  - content: Text(`'다른 매장의 카트가 있어요.\n비우고 새 매장으로 시작할까요?'`, 13, w500, `textBody`).
  - actions:
    - TextButton `'취소'` (color: `textMuted`, w600 14).
    - TextButton `'비우고 시작'` (color: `error`, w700 14).

### C. StoreMenuPage 카트 아이콘 + 뱃지
- 위치: 기존 SliverAppBar `actions` 의 `Icons.shopping_cart_outlined` 자리 재사용.
- 컴포넌트: `Stack` (overflow: visible).
  - 자식 1: `IconButton(Icons.shopping_cart_outlined, color: primary or textHeading)`. 색은 카트 활성 여부와 무관하게 `textHeading` 유지.
  - 자식 2 (count > 0 일 때만): `Positioned(top: 6, right: 6, child: badge)`.
    - badge: `Container(constraints: minWidth 18, height 18, padding: horizontal 5)`.
      - decoration: `color: AppColors.error`, `borderRadius: 999`, border: `2px AppColors.background` (대비 확보).
      - child: Center(Text(`count >= 100 ? '99+' : '$count'`, 10, w700, `onPrimary`)).
- onTap: `Navigator.push(MaterialPageRoute(builder: (_) => CartPage()))` (count 0 일 때도 동일 — CartPage 가 빈 상태 표시).

### D. MenuItemDetailPage 변경
- 담기 버튼 onPressed 흐름:
  1. `canAddToCart` false → 누락 그룹 안내 SnackBar (Phase 1a 그대로).
  2. `canAddToCart` true:
     - `setState(busy=true)` (또는 별도 `addingProvider`) → 버튼 라벨 자리에 `CircularProgressIndicator(strokeWidth: 2, color: onPrimary)`.
     - 활성 카트 ≠ storeId → 다이얼로그 표시. 취소 시 busy=false 후 종료.
     - `cartRepository.addItem(...)`.
     - 성공: `Navigator.pop()` + 매장 메뉴 페이지에서 SnackBar `'카트에 담겼어요'`.
       - **구현 메모**: SnackBar 는 pop 후 직전 화면에서 호출되도록 `BuildContext` 전달이 필요. 간단하게는 `addItem` 완료 후 `if (mounted) ScaffoldMessenger.of(context).showSnackBar(...)` 를 호출 후 즉시 `Navigator.pop()` — Material 의 SnackBar 는 다음 화면으로 자동 전이됨.
     - 실패(catch): SnackBar `'담기에 실패했어요. 잠시 후 다시 시도해주세요'` + busy=false.

---

## 컬러 / 타이포그래피 토큰 매핑

| 위치 | 토큰 |
|---|---|
| Page 배경 | `AppColors.background` |
| 카드/시트 배경 | `AppColors.surfaceElevated` |
| 카드 테두리 | `AppColors.border` |
| 본문 텍스트 | `AppColors.textBody` |
| 헤딩 텍스트 | `AppColors.textHeading` |
| 보조 텍스트 / 비활성 | `AppColors.textMuted` |
| Primary 액션 / 합계 가격 | `AppColors.primary` |
| Primary 글자색 | `AppColors.onPrimary` |
| 삭제 / 비우기 / 충돌 액션 | `AppColors.error` |

---

## 인터랙션 / 모션
- CartLineTile 우상단 close → 즉시 제거 (확인 다이얼로그 없음). 마지막 라인 제거 시 카트 자체 null 로 전이 → 빈 상태 페이드인 (`AnimatedSwitcher`, 200ms).
- AppBar `'비우기'` 버튼은 확인 AlertDialog 1단계 거침 (실수 방지).
- 매장 충돌 다이얼로그는 detail 페이지 위에서 표시. 확인 시 다이얼로그 dismiss → spinner 표시 → addItem → pop.

## 접근성
- 모든 IconButton 에 Semantics label 명시 (`'장바구니'`, `'라인 삭제'`, `'카트 비우기'`).
- QuantityStepper 는 Phase 1a 의 Semantics 처리 그대로.

## 비범위
- 영속화 (메모리 only).
- 결제 화면.
- 즐겨찾기 시각 활성화.
- 카트 라인 옵션 변경 (수정은 메뉴 상세에서 다시 담기 → 기존 라인은 삭제 후 추가).
