# Qradar 주문 플로우 — Phase 1~3 통합 정리

기능정의서 작성을 위한 cross-phase 요약 문서. Phase 1 (1a/1b/1c) + Phase 2 는 구현 완료, Phase 3 은 예정 범위로만 정리한다.

세부 산출물은 각 phase 의 `spec.md` / `design.md` / `implementation.md` / `test_report.md` 를 단일 진실원으로 본다.

---

## 0. 한눈에 보기

| Phase | 부제 | 상태 | 주요 산출물 위치 |
|---|---|---|---|
| **1a** | 매장 메뉴 + 음료 상세 + 옵션 | 완료 | [docs/tasks/order_flow_phase1a/](tasks/order_flow_phase1a/) |
| **1b** | 장바구니 (Cart) 본구현 | 완료 | [docs/tasks/order_flow_phase1b/](tasks/order_flow_phase1b/) |
| **1c** | 즐겨찾기 (Favorites) | 완료 | [docs/tasks/order_flow_phase1c/](tasks/order_flow_phase1c/) |
| **2** | 자동 추천 / 원클릭 재주문 | 완료 (2026-04-30) | [docs/tasks/order_flow_phase2/](tasks/order_flow_phase2/) |
| **3** | 결제 (토스/카카오/네이버페이) | 예정 | — |

데이터 모델 / 결정사항의 단일 진실원: [docs/tasks/order_flow_phase1/spec.md](tasks/order_flow_phase1/spec.md) (umbrella)

---

## 1. Phase 1 — 음료 주문 기본 플로우

> "사용자가 매장을 골라 메뉴를 탐색하고, 옵션을 선택해 카트에 담기까지." 결제 직전 상태.

### 1a. 매장 메뉴 + 음료 상세 + 옵션

**사용자 시나리오**
- 홈 매장 카드 / 주문 탭 매장 리스트 / 지도 마커 시트 → `StoreMenuPage` 진입
- 메인 카테고리(커피·논커피·디저트) 탭 + 부 카테고리 chips → 메뉴 그리드 필터
- 메뉴 카드 → `MenuItemDetailPage` → 옵션 선택 (단일/다중, 필수/선택) + 수량 stepper → 실시간 가격 계산
- "담기" 버튼은 placeholder (Phase 1b 가 본구현)

**신규 화면**
- `StoreMenuPage` — 매장 헤더(이미지/등급뱃지/거리/영업상태/즐겨찾기♥) + 카테고리 탭 + chips + 2열 메뉴 그리드
- `MenuItemDetailPage` — 이미지 + 즐겨찾기♥ + 옵션 그룹 + QuantityStepper + 합계 + "담기"

**주요 Entity / 인터페이스**
- `MainCategoryCode` enum (coffee/nonCoffee/dessert)
- `SubCategoryEntity`, `MenuItemEntity`, `OptionGroupEntity`, `OptionItemEntity`
- `OptionScope` (master/store), `OptionSelectionType` (single/multi)
- `CartItemEntity` (Phase 1b 사용 예정), `FavoriteStoreEntity` / `FavoriteMenuItemEntity` (Phase 1c 사용 예정), `OrderLogEntity` (Phase 2/3 사용 예정) — 인터페이스/모델만

**Firestore 컬렉션**
- `subCategories/{id}` — 글로벌 부 카테고리 (mainCategoryCode 별)
- `optionGroups/{id}` — 글로벌 마스터 옵션 (온도/샷/시럽 등)
- `stores/{storeId}/menuItems/{id}` — 매장 메뉴 (basePrice, optionGroupRefs, soldOut)
- `stores/{storeId}/optionGroups/{id}` — 매장 한정 옵션 (텀블러 할인 등)

**시드**
- `MorePage` `Qradar v0.1.0` 텍스트 long-press → 다이얼로그 → Firestore batch upsert (subCategories 9 + masterOptionGroups 3 + 임시 매장 1 + storeOptionGroups 1 + menuItems 7)
- `kDebugMode` 분기로 release 빌드 차단

### 1b. 장바구니 (Cart) 본구현

**사용자 시나리오**
- 메뉴 상세 "담기" 탭 → 활성 카트 storeId 일치 / 라인 dedup → 카트 라인 추가 → `'카트에 담겼어요'` SnackBar + 자동 pop
- 다른 매장 메뉴 담기 시도 → "기존 카트를 비울까요?" 다이얼로그 → "비우고 시작" / "취소"
- StoreMenuPage 우상단 카트 아이콘에 합산 quantity 뱃지 (99+ 캡)
- `CartPage` — 매장 헤더 + 라인 리스트(80×80 thumb + 옵션 요약 + QuantityStepper + 라인합계 + 닫기) + 빈 상태 + "비우기" + "결제하기" placeholder

**신규 화면**
- `CartPage` — `_CartList` ↔ `_EmptyCart` `AnimatedSwitcher`. 하단 `_CheckoutBar` (합계 + "결제하기" — Phase 3 placeholder SnackBar)

**주요 Entity / UseCase**
- `CartEntity`, `CartItemEntity`, `SelectedOption`
- UseCase 5종: `WatchCart`, `AddToCart`, `UpdateCartItemQuantity`, `RemoveCartItem`, `ClearCart`

**Cart 동작 알고리즘**
- 메모리 only (`StreamController.broadcast()` + `async*` 로 latest replay)
- dedupKey: `"${menuItemId}|sortedJoin('${groupId}:${itemId}', ',')"` — 옵션 순서 무관 안정 키. 동일 dedupKey 라인은 quantity 머지
- `cartItemId = uuid_v4` (uuid 4.5.1 신규 의존성)
- 매장 충돌은 UI 가 사전 가드 → `clearCart` → `addItem`. DataSource 는 storeId mismatch 시 `ArgumentError` (이중 안전망)

**비범위**
- 영속화 (앱 재시작 시 카트 초기화)
- 가격 변경 / 품절 검증 (Phase 3 결제 직전 단계에서)

### 1c. 즐겨찾기 (Favorites)

**사용자 시나리오**
- StoreMenuPage 헤더 ♥ / MenuItemDetailPage 우상단 ♥ → 토글
- 비로그인 시 "로그인이 필요해요" 다이얼로그 → "로그인하기" → `LoginPage` push
- 로그인 시 토글 → Firestore stream emit → ♥ 색 변경 (active=`AppColors.error`, inactive=위치별 분기)

**Firestore 컬렉션**
- `users/{uid}/favoriteStores/{storeId}` — `{addedAt: Timestamp}` (doc.id = storeId)
- `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` — `{storeId, menuItemId, addedAt}` (composite id)

**주요 UseCase**
- `ToggleFavoriteStore`, `ToggleFavoriteMenuItem`, `WatchFavoriteStores`, `WatchFavoriteMenuItems`

**구현 결정**
- uid 획득 = callback 패턴 (`String? Function() currentUidGetter`) — 카카오/네이버 prefix uid 호환 (`FirebaseAuth.currentUser.uid` 직접 사용 금지)
- 멤버십 체크 = Set + inline `contains` (family Provider 미사용)
- 토글 알고리즘: `exists ? delete : set({addedAt: serverTimestamp})`
- `UnauthenticatedException` 안전망 (가드 통과 직후 race 시 차단)

**신규 공통 위젯**
- `FavoriteToggleIconButton` (시각만 담당, StatelessWidget)
- `showFavoriteLoginRequiredDialog(context)` → `Future<bool>` (Phase 1b `_confirmReplaceCart` 톤 재사용)

**비범위**
- 즐겨찾기 리스트 화면 (Phase 2 와 함께 정리 — 결국 Phase 2 도 비포함, 추후 Phase)
- Optimistic UI 캐시 (stream-driven 채택)
- 매장/메뉴 삭제 시 cleanup (별도 cron task)
- Firestore 보안 규칙 (별도 task)

---

## 2. Phase 2 — 자동 추천 / 원클릭 재주문

> Phase 1 의 즐겨찾기 + OrderLog 인터페이스를 활용해 홈 상단에 "다시 주문 / 자주 찾는 매장 / 자주 찾는 메뉴" 3종 섹션 노출. 결제(Phase 3) 미구현 상태에서도 시드로 검증 가능.

### 사용자 시나리오

- 홈 진입 → 상단(NearbyStoresSection 위)에 3종 섹션이 데이터 임계값 통과 시점에 자동 노출
  - 비로그인 / OrderLog 0 → 모든 섹션 hide
  - 매장 visit ≥ 5 또는 페어 order ≥ 3 시 해당 섹션 노출 (즐겨찾기 boost +5)
- **다시 주문 카드** 탭 → (다른 매장 카트면 충돌 다이얼로그 →) 카트 비우고 OrderLog 라인 그대로 채움 → `CartPage` push
- **자주 찾는 매장 카드** 탭 → `StoreMenuPage` push
- **자주 찾는 메뉴 카드** 탭 → `StoreMenuPage` push (메뉴 상세 자동 open 안 함)

### 추천 알고리즘

| 항목 | 임계값 | 노출 max |
|---|---|---|
| 다시 주문하기 | (없음, 가장 최근부터) | 3 |
| 자주 찾는 매장 | `score = visit + (fav ? 5 : 0) >= 5` 또한 `visit >= 1` | 5 |
| 자주 찾는 메뉴 (페어) | `score = order + (fav ? 5 : 0) >= 3` 또한 `order >= 1` | 5 |

- `lookbackDays = 30` (30일 이전 로그 무시)
- 즐겨찾기 단독 (visit/order 0) 은 임계값 미달이라 자연 제외
- 정렬: score desc → tie-break visit/orderCount desc

상수: [lib/core/constants/recommendation_thresholds.dart](../lib/core/constants/recommendation_thresholds.dart)

### Firestore 컬렉션

`users/{uid}/orderLogs/{logId}` — umbrella spec 결정 7 확정 (Phase 1c 즐겨찾기와 컬렉션 위치 일관성, 사용자별 read 가 메인 쿼리, 보안 규칙 단순)

```jsonc
{
  "userId": "kakao_1234567",
  "storeId": "phase1_seed_store_001",
  "storeName": "큐레이더 시드 매장",
  "total": 8700,
  "paidAt": "<Timestamp>",
  "paymentMethod": "seed",
  "items": [
    {
      "menuItemId": "mi_americano",
      "menuItemName": "아메리카노",
      "quantity": 1,
      "lineTotal": 4500,
      "optionsSnapshot": [
        { "groupId": "og_master_temperature", "groupName": "온도",
          "itemId": "oi_temp_iced", "label": "ICED", "priceDelta": 0 }
      ]
    }
  ]
}
```

### 주요 Entity / UseCase

- `OrderLogEntity` (Phase 1a 작성, 변경 X)
- `FrequentStoreEntity` (`StoreEntity? store` 동봉 — StoreMenuPage 직진용)
- `FrequentMenuItemEntity` (imageUrl, basePrice, orderCount, isFavorite, score)
- `QuickReorderCandidateEntity` (`OrderLogEntity sourceLog` 동봉 — 카트 채움 원본)
- UseCase 4종:
  - `GetFrequentStoresUseCase` — `static compute()` 헬퍼 (logs + favoriteIds + storesById)
  - `GetFrequentMenuItemsUseCase` — `static compute()` + `static pairKey()`
  - `GetQuickReorderCandidatesUseCase` — uid 가드 + `_summarize` ("아메리카노 외 1")
  - `WriteOrderLogUseCase` — Phase 3 결제 hook 용 wrapper (Provider 만 등록, 호출은 Phase 3)

### 신규 위젯 / Provider

- `QuickReorderSection`, `FrequentStoresSection`, `FrequentMenuItemsSection` — 각자 spacer 포함 → empty/error 시 spacer 동시 hide
- `QuickReorderCard`, `FrequentStoreCard`, `FrequentMenuCard`
- `recommendation_providers.dart`:
  - `_rawOrderLogsProvider` (private) — 비로그인 시 `[]`
  - `quickReorderCandidatesProvider`
  - `storesByIdProvider` (public, `nearbyStoresProvider` 기반 lookup)
  - `frequentStoresProvider`, `frequentMenuItemsProvider`
- `replace_cart_dialog.dart` — Phase 1b `_confirmReplaceCart` 헬퍼화 (`showReplaceCartDialog(BuildContext) → Future<bool>`)

### 시드 (DEV_ONLY)

- `phase1_seed_data.dart` 에 `orderLogs(uid, now)` 추가 — 7건: today/-2/-4/-6/-10/-18/-25 일
- 분포: mi_americano 4회, mi_vanilla_latte 1, mi_coldbrew 1, mi_earl_grey 1, mi_butter_croissant 1, mi_chocolate_cake 1 → 메뉴 페어 임계값 통과
- `runPhase1Seed({uid})` 시그니처 + `dev_seed_trigger.dart` ConsumerWidget 변환 (`authProvider.asData?.value?.uid` 주입)

### 알려진 제약 (Phase 3 또는 후속에서 해소)

- `storesByIdProvider` 가 `nearbyStoresProvider` 의존 — 5km 외 매장 OrderLog 의 `FrequentStoreCard` 는 hide
- 카트 채움 시 `unitPriceWithOptions = lineTotal / quantity` 역산 (OrderLogItem 에 단가 필드 없음)
- `_menuItemsByStoreProvider` 가 매장별 stream 동적 watch — 매장 수 증가 시 lazy fetch 검토

---

## 3. Phase 3 — 결제 (예정 범위)

> umbrella spec 결정 7, Phase 1b `_CheckoutBar`, Phase 2 `WriteOrderLogUseCase` 가 모두 Phase 3 hook 을 가정하고 작성됨.

### 예정 범위

1. **결제 SDK 연동** — 토스페이 / 카카오페이 / 네이버페이
2. **결제 완료 후처리** — 결제 성공 콜백에서 `WriteOrderLogUseCase.call()` → `users/{uid}/orderLogs/{logId}` 기록
3. **CartPage "결제하기" 버튼 본구현** — 현재 `'결제는 준비 중입니다 (Phase 3)'` SnackBar placeholder 를 실제 흐름으로 교체
4. **`paymentMethod` enum 화** — Phase 1a 의 String → enum
5. **카트 검증 단계** — 결제 직전 가격 변경 / 품절 검증 (umbrella spec 결정 5 보강)
6. **`OrderLogItem.unitPriceWithOptions` 필드 추가** — Phase 2 의 `lineTotal/quantity` 역산 제거

### 예정 비범위 (그 다음 Phase 후보)

- 추천 카드 dismiss / "관심 없음" UX
- 시간대별 / push 알림 추천 (출근 시간 ☕ 등)
- 즐겨찾기 리스트 화면
- Firestore 보안 규칙 (별도 task)
- 매장/메뉴 삭제 시 OrderLog / 즐겨찾기 cleanup (별도 cron task)
- 장바구니 영속화 (SharedPreferences / Hive)
- ML 기반 추천 (협업 필터링)

---

## 4. 데이터 모델 / Firestore 컬렉션 일람

| 경로 | 작성 phase | 설명 |
|---|---|---|
| `subCategories/{id}` | 1a | 글로벌 부 카테고리 (mainCategoryCode 별) |
| `optionGroups/{id}` | 1a | 글로벌 마스터 옵션 |
| `stores/{storeId}/menuItems/{id}` | 1a | 매장 메뉴 (basePrice / optionGroupRefs / soldOut) |
| `stores/{storeId}/optionGroups/{id}` | 1a | 매장 한정 옵션 |
| `users/{uid}/favoriteStores/{storeId}` | 1c | 매장 즐겨찾기 (`{addedAt}`) |
| `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` | 1c | 메뉴 즐겨찾기 (`{storeId, menuItemId, addedAt}`) |
| `users/{uid}/orderLogs/{logId}` | 2 (read), 3 (write) | OrderLog (Phase 2 는 시드/추천 read, Phase 3 결제 hook 에서 write) |

## 5. 라우팅 / 진입점 일람

- 화면 push 는 모두 `Navigator.push(MaterialPageRoute(...))` (go_router 미도입 — 추후 일괄 마이그레이션 task)
- StoreMenuPage 진입점:
  - 홈 `NearbyStoresSection` / `RecommendedStoresSection` 카드
  - 주문 탭 `StoreListTab` 카드
  - 주문 탭 `StoreMapTab` 마커 시트 "주문하기"
  - 홈 `FrequentStoresSection` / `FrequentMenuItemsSection` 카드 (Phase 2)
  - 홈 `QuickReorderSection` 카드 → 카트 채움 후 `CartPage` push (Phase 2)
- MenuItemDetailPage 진입점: StoreMenuPage 메뉴 카드
- CartPage 진입점:
  - StoreMenuPage 우상단 카트 아이콘
  - QuickReorderCard onTap (카트 채움 후 자동 push)
- LoginPage 진입점: 즐겨찾기 비로그인 다이얼로그 "로그인하기"

## 6. 공통 위젯 / 헬퍼 일람

- `QuantityStepper` — 1a (1~99 클램프, 좌-/숫자/우+ 형태)
- `OptionGroupSelector` — 1a (단일/다중 분기)
- `FavoriteToggleIconButton` — 1c (시각만 담당)
- `showFavoriteLoginRequiredDialog(context)` — 1c (로그인 가드 다이얼로그)
- `showReplaceCartDialog(context)` — 2 (Phase 1b 인라인 헬퍼화)
- `RelativeTimeFormatter.formatKo(now, target)` — 2 (오늘/어제/N일 전/N주 전/yyyy.MM.dd)
- `PriceFormatter.formatKrw / formatDelta` — 1a (콤마 + 부호)

## 7. 상수 / 임계값 일람

[lib/core/constants/recommendation_thresholds.dart](../lib/core/constants/recommendation_thresholds.dart)

- `frequentStoreLookbackDays = 30`, `frequentStoreMinVisits = 5`
- `frequentMenuPairLookbackDays = 30`, `frequentMenuPairMinVisits = 3`
- `favoriteScoreBoost = 5`
- `quickReorderMaxItems = 3`, `frequentStoreMaxItems = 5`, `frequentMenuPairMaxItems = 5`

[lib/core/constants/firestore_paths.dart](../lib/core/constants/firestore_paths.dart) — 모든 컬렉션 경로 키 단일화

## 8. 시드 / DEV_ONLY 정리 절차

시드가 더 이상 필요 없을 때:

1. `rm -rf lib/dev/seed`
2. [lib/presentation/customer/more/more_page.dart](../lib/presentation/customer/more/more_page.dart) 의 `DevSeedTrigger` import + 래퍼 1줄 제거
3. (선택) Firestore 콘솔에서 시드 doc 삭제 — `subCategories/sc_*` 9건, `optionGroups/og_master_*` 3건, `stores/phase1_seed_store_001` (서브컬렉션 포함), `users/{uid}/orderLogs/seed_*` 7건
4. `flutter analyze` 로 unused import 잔존 0 확인

모든 시드 파일에 `// DEV_ONLY_SEED` 주석 마커가 있어 grep 으로 잔존 추적 가능.
