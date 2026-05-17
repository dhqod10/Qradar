# order_flow_phase2 — 구현 결과

자동 추천 (원클릭 재주문) — Phase 2 본구현 완료. spec.md 의 결정 A~J 와
design.md 의 위젯 명세를 모두 적용했다.

## 완료 항목

### 1. Domain 레이어
- `lib/domain/entities/order_log_entity.dart` — Phase 1a 산출물 그대로 사용
- `lib/domain/entities/frequent_store_entity.dart` — `StoreEntity? store` 동봉 (StoreMenuPage 직진용)
- `lib/domain/entities/frequent_menu_item_entity.dart` — `imageUrl`, `basePrice`, `orderCount`, `isFavorite`, `score`
- `lib/domain/entities/quick_reorder_candidate_entity.dart` — `OrderLogEntity sourceLog` 동봉 (카트 채움 원본)
- `lib/domain/usecases/get_frequent_stores_use_case.dart` — `static compute()` 헬퍼 (logs + favoriteIds + storesById)
- `lib/domain/usecases/get_frequent_menu_items_use_case.dart` — `static compute()` + `static pairKey()`
- `lib/domain/usecases/get_quick_reorder_candidates_use_case.dart` — uid 가드 + `_summarize` ("아메리카노 외 1")
- `lib/domain/usecases/write_order_log_use_case.dart` — Phase 3 결제 hook 용 wrapper

### 2. Data 레이어
- `lib/data/models/order_log_model.dart` — `fromFirestore` / `toFirestore` / `fromEntity` / `toEntity`
  - `items` 는 `List<Map<String,dynamic>>`. `optionsSnapshot` 은 `[{groupId, groupName, itemId, label, priceDelta}]`
  - `paidAt` 은 `Timestamp ↔ DateTime`
- `lib/data/datasources/remote/order_log_remote_data_source.dart`
  - 컬렉션: `users/{uid}/orderLogs/{logId}` (umbrella spec 결정 E)
  - `watchUserLogs(uid)` — `paidAt desc`
  - `appendLog(uid, model)` — `merge: true` (시드 재실행 안전)
- `lib/data/repositories/order_log_repository_impl.dart`
  - `String? Function() currentUidGetter` callback 패턴 (kakao/naver prefix 호환, Phase 1c 와 동일)
  - `appendLog`: uid null → `UnauthenticatedException`
  - `watchUserLogs`: uid null → `Stream.value([])`

### 3. Presentation 레이어
- `lib/presentation/customer/home/providers/recommendation_providers.dart`
  - DI: `orderLogRemoteDataSourceProvider`, `orderLogRepositoryProvider` (uid getter 주입)
  - UseCase Provider 4종
  - State Stream/Provider:
    - `_rawOrderLogsProvider` (private) — 비로그인 시 `[]`, 로그인 시 `repository.watchUserLogs(uid)`
    - `quickReorderCandidatesProvider` — `GetQuickReorderCandidatesUseCase.call()`
    - `storesByIdProvider` (public) — `nearbyStoresProvider` 결과 기반 lookup. FrequentMenuCard 진입에서도 사용
    - `frequentStoresProvider` — logs + favoriteStoreIds + storesById 합성, `compute` 호출
    - `_orderedStoreIdsProvider` (private) — logs 에 등장한 unique storeId 집합
    - `_menuItemsByStoreProvider` (private) — 위 집합의 각 매장 menu stream 동적 watch
    - `frequentMenuItemsProvider` — logs + favoriteMenuItemKeys + menuItemsByStore 합성
- `lib/presentation/customer/cart/widgets/replace_cart_dialog.dart`
  - `Future<bool> showReplaceCartDialog(BuildContext)` — Phase 1b `_confirmReplaceCart` 헬퍼화
  - `menu_item_detail_page.dart` 의 사용처 교체, 인라인 메서드 제거
- `lib/presentation/customer/home/widgets/quick_reorder_section.dart`
  - `QuickReorderSection` (ConsumerWidget) — empty/error → `SizedBox.shrink()`, loading → shimmer
  - `QuickReorderCard` (ConsumerStatefulWidget) — onTap 시 카트 충돌 다이얼로그 → `clearCart` + 라인별 `addItem` 루프 → `CartPage` push
  - 카드 폭 240 / 높이 196, "다시 주문" pill (IgnorePointer)
- `lib/presentation/customer/home/widgets/frequent_stores_section.dart`
  - `FrequentStoreCard` — width clamp 140~180, 이미지 좌상단 visitCount pill 뱃지 + 본문 "최근 N회 방문"
  - `entity.store == null` 인 항목 hide
- `lib/presentation/customer/home/widgets/frequent_menu_items_section.dart`
  - `FrequentMenuCard` — width clamp 140~180, 정사각 이미지, orderCount pill, "최근 N회 주문" 라벨 대신 가격 노출
  - 카드 onTap → `storesByIdProvider` 에서 StoreEntity 조회 → `StoreMenuPage(store)` push (없으면 진입 보류)
- `lib/presentation/customer/home/home_page.dart`
  - sliver 리스트에 `QuickReorderSection`, `FrequentStoresSection`, `FrequentMenuItemsSection` 추가 (NearbyStoresSection 위)
  - 각 섹션이 자기 위/아래 spacer 를 포함 → empty/error 시 spacer 동시 hide

### 4. 공통 유틸 / 상수
- `lib/core/utils/relative_time_formatter.dart` — `RelativeTimeFormatter.formatKo(now, target)` (오늘/어제/N일 전/N주 전/yyyy.MM.dd)
- `lib/core/constants/recommendation_thresholds.dart` 보강:
  - `favoriteScoreBoost = 5`
  - `quickReorderMaxItems = 3`
  - `frequentStoreMaxItems = 5`
  - `frequentMenuPairMaxItems = 5`
- `lib/core/constants/firestore_paths.dart` 보강:
  - `String orderLogs = 'orderLogs'`
  - `String userOrderLogs(String uid)` 헬퍼

### 5. 시드 (DEV_ONLY_SEED)
- `lib/dev/seed/phase1_seed_data.dart`
  - `static List<Map<String,dynamic>> orderLogs({required String uid, required DateTime now})` 추가
  - 7건: today/-2/-4/-6/-10/-18/-25 일. mi_americano 4회, mi_vanilla_latte 1회, mi_coldbrew 1회, mi_earl_grey 1회, mi_butter_croissant 1회, mi_chocolate_cake 1회 → frequentMenuPair 임계값 통과
- `lib/dev/seed/phase1_seed.dart`
  - `runPhase1Seed({FirebaseFirestore?, String? uid})` 시그니처. uid 있으면 `users/{uid}/orderLogs` 에 7건 batch write
  - `SeedResult.orderLogCount` 필드 추가, summary 에 노출
- `lib/dev/seed/dev_seed_trigger.dart`
  - `ConsumerWidget` 으로 변환 (uid 주입을 위해)
  - 다이얼로그 본문: "...임시 매장 1개 + 메뉴 7개 + 주문 로그 7건..."
  - `ref.read(authProvider).asData?.value?.uid` 를 `runPhase1Seed(uid: ...)` 로 전달

## Firestore 컬렉션 형태 예시

### users/{uid}/orderLogs/{logId}

```
{
  userId: "kakao_1234567",
  storeId: "phase1_seed_store_001",
  storeName: "큐레이더 시드 매장",
  total: 8700,
  paidAt: Timestamp(2026-04-28 ...),
  paymentMethod: "seed",
  items: [
    {
      menuItemId: "mi_americano",
      menuItemName: "아메리카노",
      quantity: 1,
      lineTotal: 4500,
      optionsSnapshot: [
        {
          groupId: "og_master_temperature",
          groupName: "온도",
          itemId: "oi_temp_iced",
          label: "ICED",
          priceDelta: 0
        }
      ]
    },
    { menuItemId: "mi_butter_croissant", menuItemName: "버터 크루아상", quantity: 1, lineTotal: 4200, optionsSnapshot: [] }
  ]
}
```

## 알고리즘 요약

| 항목 | 임계값 | 노출 max |
|---|---|---|
| 다시 주문하기 | (없음, 가장 최근부터) | 3 |
| 자주 찾는 매장 | `score = visit + (fav ? 5 : 0) >= 5` 또한 `visit >= 1` (`frequentStoreMinVisits = 5`) | 5 |
| 자주 찾는 메뉴 (페어) | `score = order + (fav ? 5 : 0) >= 3` 또한 `order >= 1` (`frequentMenuPairMinVisits = 3`) | 5 |

- lookbackDays 30 — 30일 이전 로그는 무시.
- 즐겨찾기 단독 (visit/order 0) 은 임계값 미달이라 자연 제외.
- 정렬: score desc → tie-break visit/orderCount desc.

## 테스트 포인트

1. **비로그인 진입** — 모든 추천 섹션이 `SizedBox.shrink()`, NearbyStoresSection 이 첫 화면 요소.
2. **로그인 후 시드 미실행** — OrderLog 0 → 추천 섹션 hide. authProvider data 분기 정상.
3. **시드 실행** (more_page 의 앱버전 long-press → "실행")
   - 다시 주문하기 = 3건 (today / -2 / -4)
   - 자주 찾는 매장 = 1건 (큐레이더 시드 매장, visit 7회)
   - 자주 찾는 메뉴 = 1~2건 (mi_americano 4회, fav boost 적용 시 mi_vanilla_latte 도)
4. **즐겨찾기 boost 검증** — Phase 1c 즐겨찾기 토글 후 score 변화 확인 (recommendation 즉시 stream 재구성).
5. **QuickReorderCard 탭** — 카트 비어있는 상태 → 카트 채움 + CartPage push.
6. **QuickReorderCard 매장 충돌** — 다른 매장 카트 활성 상태에서 탭 → showReplaceCartDialog → "비우고 시작" 후 카트 채움.
7. **QuickReorderCard 취소 흐름** — "취소" 시 카트 그대로 유지, busy 풀림.
8. **FrequentStoreCard 탭** → StoreMenuPage 진입.
9. **FrequentMenuCard 탭** → StoreMenuPage 진입 (메뉴 상세 자동 open 안 함).
10. **AnimatedSwitcher** — 비로그인↔로그인 전환 시 200ms 페이드인.
11. **paidAt 상대시간** — 오늘/어제/3일 전/2주 전/yyyy.MM.dd 분기.
12. **flutter analyze** — 0 issue 확인 완료.

## 알려진 제약

- **`storesByIdProvider` 가 `nearbyStoresProvider` 의존** — 5km 반경 외 매장의 OrderLog 는 store entity 가 null 이라 FrequentStoreCard 에서 hide. 시드는 동일 위치라 무관. Phase 3 이후 OrderLog 매장도 별도 lookup 필요.
- **`_menuItemsByStoreProvider` 가 동적 stream watch** — Riverpod 의 family provider 를 loop 로 watch. provider 캐시 덕에 비용은 작지만, 매장 수가 많아지면 lazy fetch 전략 검토.
- **카트 채움 시 `unitPriceWithOptions` 계산** — OrderLogItem 은 lineTotal 만 갖고 있어 `lineTotal / quantity` 로 역산. 옵션이 동일하다는 가정. (기존 결제 흐름이 unitPriceWithOptions 를 별도 저장하지 않기 때문에 이 가정 외 대안이 없음.)
- **시드 OrderLog 가 storeId 단일** — Phase 3 결제 본구현 후 다양한 매장에서 쌓이도록 자연스럽게 분산 예상.

## 미구현 / 보류

- **Phase 3 결제 본구현에서 `WriteOrderLogUseCase` 호출** — 본 phase 비범위. UseCase Provider 만 등록.
- **추천 섹션 "더보기" 페이지** — 본 phase 비범위.
- **추천 카드 dismiss / 관심 없음 UX** — 추후 phase.
- **시간대별 추천** — 추후 phase.
- **Firestore 보안 규칙** — 별도 task.
- **매장/메뉴 삭제 시 OrderLog cleanup** — 비범위. 현 시점 매장/메뉴 삭제는 owner 흐름에서만 발생, 빈도 낮음.

## flutter analyze 결과

```
$ flutter analyze
Analyzing OrderApp...
No issues found! (ran in 3.7s)
```
