# order_flow_phase2 기능 명세 — 자동 추천 / 원클릭 재주문

> ## ⚑ 우산 spec
>
> 본 phase 는 [docs/tasks/order_flow_phase1/spec.md](../order_flow_phase1/spec.md) 의 결정 7, 8 을 후속 진행한다.
>
> Phase 1 (1a/1b/1c) 결과물은 변경하지 않고 활용만 한다.
>
> ## ⚑ 시드 데이터 전략
>
> Phase 1 시드 트리거 (`MorePage` 앱 버전 long-press → 다이얼로그) 를 그대로 확장한다. `lib/dev/seed/` 폴더 격리 + `// DEV_ONLY_SEED` 주석 마커 정책 유지.

## 개요

- **목적**: Phase 1 에서 깔아둔 즐겨찾기 + OrderLog 인터페이스를 활용해 사용자에게 **빠른 재주문** 과 **자주 찾는 매장/메뉴 추천 카드** 를 제공한다. 결제(Phase 3) 가 미구현인 상태에서도 동작 검증이 가능하도록 OrderLog read 경로 + 시드 데이터를 준비한다.
- **작업 유형**: 신규 기능 (중간 규모)
- **결제는 Phase 3** — 단, OrderLog write 코드는 본 phase 에서 미리 작성해 결제 시 hook 만 추가하면 동작하도록 한다.

### 영향 범위

| 레이어 | 영향 |
|---|---|
| 화면 | (수정) 홈 화면 — 추천 섹션 1~3종 추가 / (신규 없음) |
| Domain | (신규) UseCase 4종 (`GetFrequentStoresUseCase`, `GetFrequentMenuItemsUseCase`, `GetQuickReorderCandidatesUseCase`, `WriteOrderLogUseCase`), Entity 신규: `FrequentStoreEntity`, `FrequentMenuItemEntity`, `QuickReorderCandidateEntity` |
| Data | (신규) `OrderLogModel`, `OrderLogRemoteDataSource`, `OrderLogRepositoryImpl` |
| Presentation | (수정) `home_page.dart`, (신규) `presentation/customer/home/widgets/quick_reorder_section.dart`, `frequent_stores_section.dart`, `frequent_menu_items_section.dart` (이름은 designer 가 확정), 신규 Provider 파일 `presentation/customer/home/providers/recommendation_providers.dart` |
| 공통 컴포넌트 | (신규) `QuickReorderCard`, `FrequentStoreCard`, `FrequentMenuCard` 또는 기존 `StoreCard` 재사용 — designer 결정 |
| 라우팅 | (변경 없음) 카드 → 기존 `StoreMenuPage`(`MaterialPageRoute`) 또는 `MenuItemDetailPage` 진입 |
| 권한 / 환경 설정 | (변경 없음) Firestore 보안 규칙은 별도 task |
| 시드 | (수정) `lib/dev/seed/phase1_seed.dart` 에 OrderLog 더미 5~10건 추가 또는 별도 `phase2_seed.dart` 신설 — 결정 J |

### 비범위

- **Phase 3 결제 본구현** (단, OrderLog write 경로는 본 phase 에서 만들어 둠)
- **ML / 협업 필터링 기반 추천** — 단순 빈도 + 즐겨찾기 boost 만
- **Push 알림 / 시간대별 추천** (출근 시간 ☕ 등) — 추후 Phase
- **추천 결과 검색 / 필터 / 정렬 UI**
- **Firestore 인덱스 / 캐시 최적화** — 데이터 적은 초기 단계 미적용
- **추천 카드 dismiss / "관심 없음" UX** — Phase 3 이후
- **`writeLog` 의 결제 hook 연결** — 결제 Phase 3 작업
- **Phase 2 시드 OrderLog 의 mainCategory 분포 다양화** — 시드 매장 1개 기반 단순 더미만

---

## architect 결정사항 (사용자 확인 요청)

⚠ 아래 결정은 architect 가 정한 잠정안이다. 사용자 승인 후 designer 호출.

### 결정 A. 추천 노출 위치 — 홈 화면 별도 섹션 (잠정안)

- 홈 화면 기존 구조: `NearbyStoresSection` → `CategoryFilterSection` → `RecommendedStoresSection`
- 추천은 **홈 상단 (NearbyStoresSection 위)** 에 노출. 사용자 진입 직후 가장 먼저 보이는 위치.
- 비로그인 / 데이터 부족 시 섹션 자체 숨김 (결정 G 참조).
- **대안**: 별도 탭 신설 (예: 마이 / Log 탭). 단, 현재 BottomNav 변경 비용이 커서 미선택.
- ✅ **사용자 확인**: 홈 상단으로 OK 인지, 아니면 다른 위치 (예: NearbyStoresSection 하단) 인지.

### 결정 B. 추천 카드 종류 — 3종 모두 노출 (잠정안)

1. **다시 주문하기** (Quick Reorder) — 가장 최근 주문 1~3건 (옵션 포함, 매장 + 메뉴 정보 표시)
2. **자주 찾는 매장** (Frequent Stores) — 최근 30일 5회 이상 방문 매장 + 즐겨찾기 매장 상위 N개
3. **자주 찾는 메뉴** (Frequent Menu Items) — 최근 30일 3회 이상 주문한 매장-메뉴 페어 + 즐겨찾기 메뉴

각 섹션은 데이터 부족 시 자동 숨김. 따라서 처음 사용자는 즐겨찾기만 노출, 활동량이 쌓이면 점차 모든 섹션이 노출됨.

- ✅ **사용자 확인**: 3종 모두 vs 일부만 (예: "다시 주문하기" + "자주 찾는 메뉴" 만)

### 결정 C. 원클릭 재주문 UX — 옵션 그대로 카트 채움 + 카트 페이지 이동 (잠정안)

- "다시 주문" 카드 탭 → 해당 OrderLog 의 items 를 그대로 카트에 채움 → `CartPage` 로 이동
- 매장 카트 충돌 시 Phase 1b `_confirmReplaceCart` 다이얼로그 톤 재사용
- 카트에 추가 후 옵션을 바꾸고 싶으면 카트 페이지에서 항목 삭제 → 메뉴로 다시 진입
- **대안**: 메뉴 상세 페이지로 진입해 옵션 재선택 기회 제공 (실수/취소 여지). UX 복잡도 ↑.
- ✅ **사용자 확인**: 카트 채움 + 카트 페이지 직진 vs 메뉴 상세 진입.

### 결정 D. 시드 OrderLog 전략 — Phase 1 시드 트리거 통합 (잠정안)

- 기존 `phase1_seed.dart` 의 매장/메뉴 시드 + OrderLog 5~10건 더미 한 번에 기록.
- 트리거 위치 변경 없음 (`MorePage` 앱 버전 long-press → 같은 다이얼로그).
- 다이얼로그 본문에 "+ 주문 더미 5~10건" 항목 추가 명시.
- **대안**: 별도 트리거 (예: 두 번째 long-press 메뉴 / 시드 다이얼로그에 체크박스). 분리 정리 용이하지만 사용자 조작 복잡.
- ✅ **사용자 확인**: 통합 vs 분리.

### 결정 E. OrderLog 컬렉션 경로 — `users/{uid}/orderLogs/{logId}` (잠정안)

- 우산 spec 결정 7 미확정. 본 phase 에서 확정.
- 잠정안 사유:
  - 즐겨찾기 (`users/{uid}/favoriteStores`, `users/{uid}/favoriteMenuItems`) 와 **컬렉션 위치 일관성**.
  - 사용자별 read 가 절대 다수 (`watchUserLogs(userId)` 가 메인 쿼리). 사용자 서브컬렉션이 자연스러움.
  - 보안 규칙 작성 단순 (`request.auth.uid == userId`).
- **대안**: top-level `orderLogs/{logId}` — 점주/관리자 cross-user 분석 시 유리. 단, 현재 phase 에서 그런 use case 없음.
- ✅ **사용자 확인**: 서브컬렉션 vs top-level. 점주/관리자 분석 use case 가 곧 필요한지 사용자 의견.

### 결정 F. 추천 가중치 — 빈도 기반 + 즐겨찾기 boost (잠정안)

- **자주 찾는 매장 score**:
  - `score = visitCount + (isFavorite ? favoriteBoost : 0)`
  - `visitCount` = 최근 `frequentStoreLookbackDays` (30일) 내 OrderLog 매장별 카운트
  - `favoriteBoost` = 5 (잠정값. 임계값 상수에 추가 권장)
  - score 내림차순 상위 N개
- **자주 찾는 메뉴 score**:
  - `score = pairOrderCount + (isFavorite ? favoriteBoost : 0)`
  - `pairOrderCount` = 최근 `frequentMenuPairLookbackDays` (30일) 내 (storeId, menuItemId) 페어 카운트
- **빈도 0 이지만 즐겨찾기인 항목**: 즐겨찾기 매장/메뉴는 빈도 부족이어도 boost 만큼 점수 가산되어 노출 가능. 단 임계값 미달 시 노출 X (예: 즐겨찾기만으로는 노출되지 않게 → minVisits 적용).
- **대안 1**: 빈도와 별개로 즐겨찾기 매장 항상 1개는 노출. 사용자 입장에서 "내가 등록한 게 안 보임" 문제 방지.
- **대안 2**: 빈도 multiplier 방식 (`score = visitCount * (isFavorite ? 1.5 : 1.0)`).
- ✅ **사용자 확인**: 잠정안 (additive boost) vs 대안 1 (즐겨찾기 강제 노출) vs 대안 2 (multiplier).

### 결정 G. 비로그인 / 데이터 부족 시 분기 — 섹션 자체 숨김 (잠정안)

- 비로그인 → 모든 추천 섹션 숨김.
- 로그인 + 데이터 0 → 해당 섹션만 숨김 (예: OrderLog 0 → "다시 주문" / "자주 찾는 메뉴" 숨김, 즐겨찾기만 있으면 "자주 찾는 매장" 만 표시).
- **대안**: empty 카드 노출 ("주문하면 여기에 빠른 재주문이 나타나요"). UX 친화적이지만 빈 상태가 시각적 노이즈.
- ✅ **사용자 확인**: 숨김 vs empty 카드 노출.

### 결정 H. UseCase Provider 패턴 — Phase 1 과 동일 (캐시 없음, stream-driven)

- Phase 1c 와 동일하게 `authProvider` 변경 반응형 `StreamProvider`.
- 비로그인 → `Stream.value(<empty>)` 또는 동등.
- 낙관적 캐시 / in-memory state 사용 금지 (Phase 1c 결정 D 와 일관).
- 사용자 확인 불필요 (Phase 1 정책 유지).

### 결정 I. OrderLog DataSource — write 도 미리 작성 (시드/Phase 3 모두 활용)

- 우산 spec 결정 7 은 "Phase 1 은 모델/인터페이스만, DataSource/Impl 은 결제 phase 에서". 본 phase 에서 read+write 모두 작성.
- 사유:
  - read 만 작성 시 시드 OrderLog 를 어떻게 채울지 (Firestore 콘솔 수동 / 별도 스크립트) 가 별도 문제.
  - Phase 3 에서도 write 가 필요. 미리 작성해 두면 Phase 3 에서 결제 콜백만 hook 하면 됨.
  - Repository Interface (`appendLog`) 는 이미 존재. 구현체만 추가.
- 사용자 확인 불필요 (architect 판단).

### 결정 J. 시드 OrderLog 데이터 형태

- Phase 1 시드 매장 (`phase1_seed_store_001`) + 메뉴 6~8개를 활용.
- OrderLog 7건 정도 생성. paidAt 분포: 최근 7일 내 4건, 8~30일 내 3건. 동일 매장 + 다양한 메뉴 + 다양한 옵션.
- 동일 메뉴를 3~4번 반복하는 페어 1개 만들어 "자주 찾는 메뉴" 가 동작하도록 보정.
- 시드 logId = uuid 또는 deterministic prefix (`seed_log_*`). 재실행 시 덮어쓰기.
- 사용자 확인 불필요 (architect 판단).

---

## 요구사항

### 기능 요구사항

#### OrderLog 인프라
- [ ] `data/models/order_log_model.dart` 신규 작성 (Entity 와 1:1 매핑, Firestore 직렬화)
- [ ] `data/datasources/remote/order_log_remote_data_source.dart` 신규 — `appendLog(log)`, `watchUserLogs(uid)`
- [ ] `data/repositories/order_log_repository_impl.dart` 신규 — Phase 1c 와 동일하게 `String? Function() currentUidGetter` callback 패턴
- [ ] uid null → `UnauthenticatedException`
- [ ] Firestore 컬렉션 경로: `users/{uid}/orderLogs/{logId}` (결정 E)
- [ ] paidAt desc 정렬 (Firestore `orderBy('paidAt', descending: true)`)
- [ ] OrderLog stream 에러 → 빈 List fallback (앱 크래시 X)

#### Domain UseCase
- [ ] `WriteOrderLogUseCase` — 결제 Phase 3 에서 호출할 단순 wrapper (`appendLog` 호출). 본 phase 에서는 시드에서 직접 호출하지 않고 DataSource 를 시드가 직접 사용 (DEV_ONLY 격리 명분).
- [ ] `GetFrequentStoresUseCase` — `Stream<List<FrequentStoreEntity>>`. uid + favoriteStoreIds + OrderLog stream 합성.
- [ ] `GetFrequentMenuItemsUseCase` — `Stream<List<FrequentMenuItemEntity>>`. uid + favoriteMenuKeys + OrderLog stream 합성.
- [ ] `GetQuickReorderCandidatesUseCase` — `Stream<List<QuickReorderCandidateEntity>>`. 가장 최근 OrderLog 1~3건.
- [ ] 모든 UseCase 는 비로그인 시 `Stream.value(const [])` 반환.

#### Presentation
- [ ] `recommendation_providers.dart` 신규:
  - `orderLogRemoteDataSourceProvider`
  - `orderLogRepositoryProvider` (callback uid getter 주입)
  - `writeOrderLogUseCaseProvider`
  - `getFrequentStoresUseCaseProvider`
  - `getFrequentMenuItemsUseCaseProvider`
  - `getQuickReorderCandidatesUseCaseProvider`
  - `frequentStoresProvider` (StreamProvider)
  - `frequentMenuItemsProvider` (StreamProvider)
  - `quickReorderCandidatesProvider` (StreamProvider)
- [ ] `home_page.dart` 수정 — 상단에 추천 섹션 3종 sliver 추가 (노출 분기는 결정 G 따름)
- [ ] 추천 섹션 위젯 3종 신규 (UI 디테일은 designer 결정)
- [ ] "다시 주문하기" 카드 탭 → `addOrderLogToCartUseCase` 또는 `CartRepository.replaceCart(...)` 호출 → `CartPage` push
  - 매장 충돌 → Phase 1b `_confirmReplaceCart` 다이얼로그 (재사용 패턴, 헬퍼화 권장)
- [ ] "자주 찾는 매장" 카드 탭 → `StoreMenuPage(storeId)` push
- [ ] "자주 찾는 메뉴" 카드 탭 → `StoreMenuPage(storeId)` push 후 자동 메뉴 상세 open (또는 곧장 `MenuItemDetailPage`) — designer 결정

#### 시드
- [ ] `phase1_seed.dart` 또는 `phase2_seed.dart` 에 OrderLog 7건 더미 추가
- [ ] 시드 다이얼로그 본문 텍스트 갱신 — 주문 더미 포함 명시
- [ ] `// DEV_ONLY_SEED — order_flow_phase2` 주석 마커

### UI 요구사항 (designer 가 design.md 에서 확정)

- [ ] 추천 섹션 헤더 ("다시 주문하기" / "자주 찾는 매장" / "자주 찾는 메뉴") 톤 일관성 (NearbyStoresSection 헤더 패턴 재사용)
- [ ] QuickReorderCard — 매장명 + 메뉴 요약 (예: "아메리카노 외 1") + 총액 + paidAt 상대시간 + "다시 주문" 버튼/탭
- [ ] FrequentStoreCard / FrequentMenuCard — 기존 StoreCard 재사용 가능성 검토
- [ ] 가로 스크롤 vs 세로 리스트 — designer 결정
- [ ] 비로그인 / empty 시 결정 G 따름

### 상태 요구사항

- [ ] **loading**: 첫 stream emit 전 shimmer 또는 섹션 미노출 (designer 결정)
- [ ] **error**: stream 에러 → 섹션 숨김 + 콘솔 로그 (UI 충격 X)
- [ ] **empty**: 결정 G 분기

---

## 데이터 모델

### Entity 신규

```dart
// domain/entities/frequent_store_entity.dart
class FrequentStoreEntity {
  final String storeId;
  final String storeName;
  final int visitCount;       // 최근 30일
  final bool isFavorite;
  final int score;            // visitCount + favoriteBoost
}

// domain/entities/frequent_menu_item_entity.dart
class FrequentMenuItemEntity {
  final String storeId;
  final String storeName;
  final String menuItemId;
  final String menuItemName;
  final int orderCount;       // 매장-메뉴 페어 카운트, 최근 30일
  final bool isFavorite;
  final int score;
}

// domain/entities/quick_reorder_candidate_entity.dart
class QuickReorderCandidateEntity {
  final String orderLogId;
  final String storeId;
  final String storeName;
  final String summary;       // "아메리카노 외 1"
  final int total;
  final DateTime paidAt;
  final OrderLogEntity sourceLog; // 카트 채울 때 items 그대로 사용
}
```

freezed 적용. score / summary 는 UseCase 가 계산해 주입.

### Entity 변경 없음

- `OrderLogEntity` (Phase 1a 작성, 변경 X)
- `FavoriteStoreEntity`, `FavoriteMenuItemEntity` (Phase 1a 작성, 변경 X)

### Model / DTO 신규

```dart
// data/models/order_log_model.dart
class OrderLogModel {
  // OrderLogEntity 와 1:1
  factory OrderLogModel.fromFirestore(DocumentSnapshot doc) { ... }
  Map<String, dynamic> toFirestore() { ... }
  OrderLogEntity toEntity() { ... }
}
```

Firestore 필드:
- `id` (doc id 와 동일)
- `userId`
- `storeId`, `storeName`
- `items: [{menuItemId, menuItemName, quantity, optionsSnapshot: [...], lineTotal}]`
- `total`
- `paidAt: Timestamp`
- `paymentMethod: string` (현재 시드는 `'seed'`)

### Firestore 문서 예시

`users/{uid}/orderLogs/seed_log_001`:

```json
{
  "id": "seed_log_001",
  "userId": "kakao_xxx",
  "storeId": "phase1_seed_store_001",
  "storeName": "Qradar 시드 카페",
  "items": [
    {
      "menuItemId": "menu_americano",
      "menuItemName": "아메리카노",
      "quantity": 1,
      "optionsSnapshot": [
        {"groupId": "temperature", "itemId": "ice", "label": "아이스", "priceDelta": 0}
      ],
      "lineTotal": 4500
    }
  ],
  "total": 4500,
  "paidAt": Timestamp(2026-04-25 10:23:11),
  "paymentMethod": "seed"
}
```

---

## 레이어 설계

### Domain

- **Entity (신규)**: `FrequentStoreEntity`, `FrequentMenuItemEntity`, `QuickReorderCandidateEntity`
- **Entity (재사용)**: `OrderLogEntity`, `OrderLogItem`, `FavoriteStoreEntity`, `FavoriteMenuItemEntity`
- **UseCase (신규)**:
  - `WriteOrderLogUseCase`
  - `GetFrequentStoresUseCase`
  - `GetFrequentMenuItemsUseCase`
  - `GetQuickReorderCandidatesUseCase`
- **Repository Interface (재사용)**: `OrderLogRepository` (Phase 1a, 변경 없음)

### Data

- **Model (신규)**: `OrderLogModel`
- **DataSource (신규)**: `OrderLogRemoteDataSource`
- **Repository Impl (신규)**: `OrderLogRepositoryImpl` (생성자: `OrderLogRemoteDataSource ds`, `String? Function() currentUidGetter`)

### Presentation

- **Provider (신규)**: `recommendation_providers.dart` (위치: `presentation/customer/home/providers/`)
- **Page (수정)**: `home_page.dart` — 상단에 추천 섹션 3종 추가
- **Widget (신규)**: 추천 섹션 + 카드 위젯 3쌍 (designer 가 위치/이름 확정)
- **Helper (신규/이동)**: `replaceCart` 다이얼로그 헬퍼 — Phase 1b `_confirmReplaceCart` 가 cart_page 내부 private 이면 공통화 권장. spec 단계에서는 cart 영역에 `showReplaceCartDialog(BuildContext)` 헬퍼 신설 권장 (designer/developer 협의).

---

## 데이터 흐름

```text
HomePage
  ⇅ ref.watch(quickReorderCandidatesProvider)
       ↳ GetQuickReorderCandidatesUseCase
            ↳ OrderLogRepository.watchUserLogs(uid)   ───┐
                ↳ OrderLogRepositoryImpl                 │
                     ↳ OrderLogRemoteDataSource         │
                          ↳ Firestore                    │
                                                         │
  ⇅ ref.watch(frequentStoresProvider)                    │
       ↳ GetFrequentStoresUseCase                        │
            ↳ favoriteStoreIdsProvider (Phase 1c)        │── stream combine
            ↳ OrderLogRepository.watchUserLogs ──────────┘
            ↳ score 계산 (메모리, 순수 함수)
                                                         
  ⇅ ref.watch(frequentMenuItemsProvider)                 
       ↳ GetFrequentMenuItemsUseCase                      
            ↳ favoriteMenuItemKeysProvider (Phase 1c)     
            ↳ OrderLogRepository.watchUserLogs            
            ↳ pair score 계산                             

QuickReorderCard.onTap
  → Phase 1b cart 충돌 다이얼로그 (필요시)
  → CartRepository.replaceCart(items from OrderLog)
  → Navigator.push(CartPage)

FrequentStoreCard.onTap
  → Navigator.push(StoreMenuPage(storeId))

FrequentMenuCard.onTap
  → Navigator.push(StoreMenuPage(storeId)) 또는 MenuItemDetailPage
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 비로그인 상태에서 추천 섹션 진입 | 섹션 자체 숨김 (Stream.value([])) |
| OrderLog stream 에러 (네트워크/권한) | 섹션 숨김 + 콘솔 로그. 사용자 안내 X (방해 최소) |
| OrderLog 0건 (활동 없음) | 섹션 숨김 (결정 G) |
| 즐겨찾기 stream 에러 | 빈 Set fallback (Phase 1c 와 동일) |
| 원클릭 재주문 시 매장 충돌 | Phase 1b 다이얼로그 |
| 원클릭 재주문 시 OrderLog 매장이 폐업/삭제 | (현 phase) StoreMenuPage 진입 후 에러 카드. (추후) 추천 카드 단계에서 hide |
| 원클릭 재주문 시 OrderLog 메뉴가 품절/삭제 | StoreMenuPage 진입 시 카트에 담긴 항목 표시. 결제 시점 검증은 Phase 3. 본 phase 는 best-effort. |
| Firestore write (시드) 실패 | 시드 다이얼로그 SnackBar 에러 (Phase 1 과 동일 패턴) |
| `appendLog` uid null | `UnauthenticatedException` |

---

## 보안 / 환경 설정

- Firestore 보안 규칙 작성은 **별도 task**. 본 phase 에서는 dev 환경 (개방 규칙) 가정.
- 클라이언트는 `request.auth.uid == userId` 패턴이 적용 가능하도록 경로 설계 (결정 E).
- `appendLog` 는 Phase 3 결제 콜백에서 호출. 본 phase 에서는 시드만 호출.
- 환경 변수 / API key 변경 없음.

---

## 작업 분배

### designer

- **UI 변경 필요 여부**: ✅ 필요 (홈 화면 상단 신규 섹션 + 카드 3종)
- **디자인 산출물**: `docs/tasks/order_flow_phase2/design.md`
- **전달할 사항**:
  - 추천 섹션 헤더 톤 = `NearbyStoresSection` 패턴 재사용
  - QuickReorderCard / FrequentStoreCard / FrequentMenuCard 시각 명세
  - 가로 스크롤 vs 세로 리스트 결정
  - 비로그인 / empty 시 섹션 숨김 (결정 G) 적용
  - "다시 주문" 버튼 톤 = Phase 1b "결제하기" 또는 액션 버튼 패턴
  - StoreCard 재사용 가능성 검토 (이미 홈에서 쓰이고 있음)
  - 색상은 AppColors 토큰만

### developer

- **구현 항목**:
  - Domain Entity 3종, UseCase 4종
  - Data Model + DataSource + RepositoryImpl
  - Presentation Provider 파일
  - HomePage 수정 (sliver 3개 추가)
  - 추천 섹션 위젯 3종
  - 시드 OrderLog 추가
  - replaceCart 다이얼로그 공통 헬퍼화 (cart_page 의 `_confirmReplaceCart` 추출)
- **재사용할 기존 구조**:
  - Phase 1a OrderLog Entity / Repository Interface / model freezed 패턴
  - Phase 1c favoritesProvider / authProvider 반응형 패턴
  - Phase 1b 카트 충돌 다이얼로그 톤
  - Phase 1 시드 트리거 (DevSeedTrigger)
  - 홈의 NearbyStoresSection / RecommendedStoresSection 위젯 패턴
- **주의할 레이어 규칙**:
  - cloud_firestore import 는 data 레이어만
  - score 계산은 UseCase 안에서 (domain layer, 순수 함수)
  - Provider 의 stream 합성은 `Rx.combineLatest` 또는 `StreamProvider` + `ref.watch` chain
  - 임계값은 `RecommendationThresholds` 만 사용
  - uid 는 `authProvider.valueOrNull?.uid` (kakao_/naver_ prefix 포함)

### tester

- **주요 검증 기준**:
  - 레이어 규칙 (cloud_firestore import 위치)
  - OrderLog 컬렉션 경로 정확성
  - 비로그인 시 모든 추천 섹션 숨김
  - 즐겨찾기 boost 가 점수에 반영되는지
  - 임계값 미달 시 노출 여부 (잠정안 = 노출 X)
  - 원클릭 재주문 후 카트 상태
  - 매장 충돌 다이얼로그 톤
  - 시드 OrderLog 가 Firestore 에 정상 기록되는지
  - flutter analyze 0 issue
- **반드시 확인할 예외 케이스**:
  - 비로그인 → 추천 영역 노출 X
  - OrderLog 0 + 즐겨찾기 0 → 모든 섹션 숨김
  - OrderLog 0 + 즐겨찾기 ≥ 1 → "자주 찾는 매장" 만 노출 (즐겨찾기 boost 단독으로 임계값 넘는지 결정 F 에 따라)
  - OrderLog 의 매장이 삭제된 상태에서 카드 탭 → 에러 화면
  - OrderLog 의 메뉴가 품절 → 카트 진입 후 표시 정상

---

## 완료 기준

- [ ] 요구사항이 모두 구현 또는 보류 사유 명시됨
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료
- [ ] FAIL 항목이 없거나 후속 작업으로 분리됨
- [ ] flutter analyze 0 issue
- [ ] 시드 매장 + 시드 OrderLog 7건으로 추천 섹션 3종 모두 노출 확인
- [ ] 비로그인 → 모든 추천 섹션 숨김 확인
- [ ] 원클릭 재주문 → 카트 페이지 진입 + 동일 옵션 확인

---

## 사용자 확정사항 (2026-04-29 확정)

사용자가 잠정안 그대로 진행 승인.

- **결정 A**: 추천 노출 위치 = 홈 상단 (NearbyStoresSection 위)
- **결정 B**: 추천 카드 종류 = 3종 모두 (다시 주문 / 자주 찾는 매장 / 자주 찾는 메뉴)
- **결정 C**: 원클릭 재주문 UX = 옵션 그대로 카트 채움 + CartPage 직진. 매장 충돌 시 Phase 1b `_confirmReplaceCart` 톤 재사용.
- **결정 D**: 시드 OrderLog 전략 = Phase 1 시드 트리거 통합 (`MorePage` 앱 버전 long-press 동일 다이얼로그)
- **결정 E**: OrderLog 컬렉션 경로 = `users/{uid}/orderLogs/{logId}` (서브컬렉션)
- **결정 F**: 추천 가중치 = 빈도 기반 + 즐겨찾기 additive boost (`favoriteBoost = 5`). 임계값 미달 항목은 노출 X.
- **결정 G**: 비로그인 / 데이터 부족 시 = 섹션 자체 숨김 (empty 카드 노출 X)

추가 결정 (architect 자체 판단, 사용자 확인 불필요):
- **결정 H**: stream-driven UI (낙관적 캐시 X) — Phase 1 정책 유지
- **결정 I**: OrderLog read+write 모두 본 phase 에서 작성 (Phase 3 hook 만 추가하면 동작)
- **결정 J**: 시드 OrderLog 7건 (최근 7일 4건 + 8~30일 3건, 동일 메뉴 3~4번 반복 페어 1개 포함)
