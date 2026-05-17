# 주문 플로우 Phase 1c 사양 (즐겨찾기 본구현 — Favorites)

> **단일 진실원**: 데이터 모델·도메인 결정사항은 [umbrella spec](../order_flow_phase1/spec.md) 의 결정 6 (즐겨찾기 두 컬렉션 분리) 을 따른다. 본 문서는 Phase 1c 한정 운영 범위만 좁혀 정의한다.
>
> Phase 1a 에서 만들어 둔 인터페이스/엔티티 위치를 기준으로 한다.
> - `lib/domain/entities/favorite_store_entity.dart`
> - `lib/domain/entities/favorite_menu_item_entity.dart`
> - `lib/domain/repositories/favorites_repository.dart` (인터페이스 — 본 phase 에서 시그니처 확정 + Impl 작성)

---

## 개요

- **목적**: Phase 1a / 1b 에서 placeholder 스낵바("즐겨찾기는 준비 중입니다 (Phase 1c)") 로 둔 매장 / 음료 ♥ 토글을 실제 Firestore 토글 동작으로 연결한다. umbrella spec 결정 6 의 두 컬렉션 분리 구조를 그대로 구현한다.
- **작업 유형**: 신규 기능 (Domain / Data / Presentation 전 레이어). Phase 1a 의 Entity 와 Repository 인터페이스를 재사용.
- **결제 / OrderLog 는 Phase 3, Phase 2 자동 추천은 본 phase 비범위**.

### 영향 범위

| 레이어 | 영향 |
|---|---|
| 화면 | (수정) `StoreMenuPage` 매장 헤더 ♥ 토글 placeholder → 실제 동작 / (수정) `MenuItemDetailPage` 우상단 ♥ 토글 placeholder → 실제 동작 |
| Domain | (수정) `repositories/favorites_repository.dart` 시그니처 확정 / (신규) UseCase 4종 (toggle store / toggle menu / watch stores Set / watch menu keys Set) |
| Data | (신규) `FavoritesRemoteDataSource` (Firestore `users/{uid}/favoriteStores` + `users/{uid}/favoriteMenuItems`) / (신규) `FavoritesRepositoryImpl` / (신규) Model 2종 (`FavoriteStoreModel`, `FavoriteMenuItemModel`) |
| Presentation | (신규) Providers `favoriteStoreIdsProvider`, `favoriteMenuItemKeysProvider`, DI 체인 (datasource → repository → usecase 별 Provider) / (수정) Phase 1a 의 ♥ placeholder 호출부 |
| 공통 컴포넌트 | (신규) `lib/presentation/common/favorite_toggle_icon_button.dart` |
| 라우팅 | 변경 없음 (현 Phase 1 시리즈는 `Navigator.push` 유지 — Phase 1b 결정 A 와 동일) |
| 권한 / 환경 | 변경 없음 (Firestore 보안 규칙 작성 task 별도. 단, 본 phase 의 컬렉션 경로를 그 task 가 참조해야 함을 메모) |

### 비범위 (Phase 1c)

- **즐겨찾기 리스트 화면** (My Favorites Page) — 사용자 확인 항목 1 참조. 기본 안 (architect 의견): **본 phase 비포함**, Phase 2 자동 추천과 함께 정리.
- Phase 2 자동 추천 로직 / 임계값 활용 (`recommendation_thresholds.dart` 사용)
- 즐겨찾기 정렬·그룹·검색·필터 UI
- 즐겨찾기 batch 동기화 / off-line 큐
- 결제 / OrderLog 기록 (Phase 3)
- Firestore 보안 규칙 작성 (별도 task)

---

## 결정사항 (architect, Phase 1c 한정)

### 결정 A. Repository 인터페이스 시그니처 확정

Phase 1a 에 작성된 `FavoritesRepository` 인터페이스를 그대로 채택. 사용자 요구사항이 "Stream<Set<storeId>>" 형태이지만, 일관성을 위해 **Repository 는 `List<Entity>` 를 반환** 하고 **Set 변환은 Presentation Provider 에서 수행**한다. 이유: 다른 Repository (menu / option) 와의 시그니처 일관성 + 향후 `addedAt` 정렬 / 메타데이터를 활용해야 할 때 entity 가 필요. 본 phase 의 Provider 가 List → Set<id> 변환을 담당.

```dart
abstract class FavoritesRepository {
  Stream<List<FavoriteStoreEntity>> watchFavoriteStores();
  Stream<List<FavoriteMenuItemEntity>> watchFavoriteMenuItems();
  Future<void> toggleFavoriteStore(String storeId);
  Future<void> toggleFavoriteMenuItem({
    required String storeId,
    required String menuItemId,
  });
  Stream<bool> isStoreFavorited(String storeId);
  Stream<bool> isMenuItemFavorited({
    required String storeId,
    required String menuItemId,
  });
}
```

- **현재 로그인 uid 획득은 RepositoryImpl 내부 책임** (생성자 주입된 `FirebaseAuth` 또는 별도 `AuthSession` 추상).
- 비로그인 상태에서 `watch*` 호출 시 빈 List emit, `toggle*` 호출 시 `UnauthenticatedException` 발생 (Presentation 이 사전 가드).

### 결정 B. RepositoryImpl 의 uid 획득 — `FirebaseAuth.instance.currentUser` 직접 사용 (Data 레이어)

- `FavoritesRepositoryImpl` 은 `FirebaseAuth` 인스턴스를 생성자로 받는다 (테스트 가능성 + 다른 RepositoryImpl 패턴과 일관성: `auth_repository_impl.dart` 참조).
- RepositoryImpl 이 `_firebaseAuth.currentUser?.uid` 로 현재 uid 를 조회.
- **단, Presentation 측은 비로그인 시점 가드를 별도로 담당**: 토글 호출 직전 `authProvider.value == null` 이면 로그인 유도 다이얼로그를 띄워 호출 자체를 차단 → `UnauthenticatedException` 은 안전망 역할.
- 이유: Presentation 에서 `currentUserId` 를 명시적으로 넘기는 방식도 가능하지만, 인터페이스가 이미 uid 인자를 받지 않는 형태로 Phase 1a 에 확정됐고, 실제 Firestore 보안 규칙도 `request.auth.uid` 기준이 될 것이므로 RepositoryImpl 이 `FirebaseAuth.currentUser` 를 직접 본다.

> **사용자 확인 항목 (architect 의견 첨부)**: 현재 인증 시스템은 `authProvider` (`presentation/customer/auth/auth_provider.dart`) 가 `UserEntity?.uid` 를 노출. **카카오 / 네이버 로그인 시 `uid` 는 `kakao_${id}` / `naver_${id}` 로 Firebase Auth 와 별개**다. 즐겨찾기는 Firestore `users/{uid}/...` 서브컬렉션을 쓰므로 **users 문서의 uid 와 동일한 키**가 필요. `currentUserProfileProvider` (`presentation/customer/auth/providers/user_profile_provider.dart`) 가 `users/{uid}` 를 watch 하므로, **본 phase 는 `authProvider.value?.uid` 를 그대로 사용** (이 uid 는 카카오/네이버 prefix 포함). RepositoryImpl 도 동일 키를 사용해야 하므로 **`FirebaseAuth.instance.currentUser?.uid` 가 아니라 `authProvider` 의 uid 를 RepositoryImpl 에 전달하는 구조**가 필요할 수 있다 — **결정 B 보강**: RepositoryImpl 은 생성자에 `String? Function() currentUid` 형태의 callback (또는 `Stream<String?> uidStream`) 을 주입받고, Presentation 의 `favoritesRepositoryProvider` 가 `ref.watch(authProvider)` 결과를 callback 으로 묶어 전달. 이러면 카카오/네이버 prefix uid 도 동일하게 동작.

### 결정 C. 토글 로직 — 두 컬렉션 분리, 문서 키 규칙

umbrella spec 결정 6 의 키 규칙을 그대로 따른다.

- `users/{uid}/favoriteStores/{storeId}` — 필드 `addedAt: Timestamp`
- `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` — 필드 `storeId: String`, `menuItemId: String`, `addedAt: Timestamp`
  - **compositeId** = `'${storeId}_${menuItemId}'` (storeId / menuItemId 자체에 `_` 가 있어도 첫 `_` 이후 모두를 menuItemId 로 보지 않음. 토글 시 항상 `'${storeId}_${menuItemId}'` 키로 직접 doc 접근하므로 파싱 불필요. **원본 storeId/menuItemId 는 doc 필드에 별도 저장**해 역추적 가능).

토글 알고리즘 (Firestore RW 1회씩):

```
toggleFavoriteStore(storeId):
  doc = users/{uid}/favoriteStores/{storeId}
  exists = await doc.get().exists
  if exists: doc.delete()
  else: doc.set({addedAt: serverTimestamp()})
```

→ **race-safe 트랜잭션은 본 phase 비범위** (1 사용자 동시 더블탭 정도는 Firestore set/delete idempotency 로 허용). 필요 시 향후 transaction 으로 감쌈.

### 결정 D. UI 동작 정책 — 낙관적 UI 채택

사용자 확인 항목 3 (낙관적 UI vs 대기 UI). architect 추천 = **낙관적 UI**.

- `FavoriteToggleIconButton` 의 active 상태는 **`favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider` 의 stream 값**으로 표시.
- 토글 onTap → 즉시 `repository.toggle*` 호출 (await). Stream 이 다시 emit 하면서 자연스럽게 UI 가 갱신됨 (Firestore 라운드트립 ~100~300ms).
- **별도 in-memory optimistic state 는 두지 않음** (이중 진실원 회피). Firestore 응답이 빠르므로 사용자 체감상 "즉시" 와 거의 같음.
- 토글 실패 (예: 네트워크 오류, 권한) 시 stream 값이 변경되지 않으므로 active 상태도 그대로. 추가로 SnackBar "즐겨찾기 저장에 실패했어요" 노출.
- 만약 사용자 테스트에서 체감 지연이 거슬릴 경우 → Phase 2 에서 optimistic in-memory layer 추가 검토 (본 spec 비범위).

> **사용자 확인 항목 3 (architect 의견)**: 낙관적 UI 의 별도 캐시는 race condition (네트워크 실패 시 롤백, 동시 다른 디바이스 변경 등) 을 만들기 쉽다. Firestore 의 stream latency 가 통상 100~300ms 라 "대기 UI" 라기보다 "stream-driven UI" 가 적절. 채택.

### 결정 E. 비로그인 처리 — 다이얼로그 + 로그인 페이지 push

토글 시점에 `authProvider.value == null` 이면 **Firestore 호출 전에 다이얼로그**를 띄운다.

- 다이얼로그 본문 (architect 잠정안 — 사용자 확인 항목 2):
  - 제목: "로그인이 필요해요"
  - 본문: "즐겨찾기를 저장하려면 Qrator 로그인이 필요해요." (Qradar 톤 — Qrator 용어 사용)
  - 버튼: "취소" / "로그인하기"
- "로그인하기" → `Navigator.push(MaterialPageRoute(builder: (_) => const LoginPage()))`. 기존 `lib/presentation/customer/auth/login_page.dart` 사용. 로그인 성공 시 `LoginPage` 의 기존 로직이 `RoleRouter` 로 `pushAndRemoveUntil` 하므로 **사용자는 자동으로 즐겨찾기 페이지가 아닌 홈/롤 분기로 이동**. 본 phase 에서는 "토글 흐름 중도 종료 → 사용자가 다시 매장/메뉴를 열어 토글" 흐름으로 간주 (자연스러움).
- **추가 옵션 (보류)**: 로그인 후 원래 화면으로 자동 복귀하는 "post-login deeplink" 는 본 phase 비범위 (라우터 미도입 상태에서 복잡도가 큼).
- 비로그인 상태에서도 ♥ 아이콘 자체는 노출 (inactive 컬러). 탭 시 다이얼로그.

> **사용자 확인 항목 2 (architect 의견)**: 위 텍스트는 Qradar 톤 ("Qrator 로그인이 필요해요"). 다른 톤 선호 시 사용자 확정 후 designer 가 design.md 에 반영.

### 결정 F. 활성 색상 — `AppColors.error` (사용자 요구사항대로)

- 활성 = `Icons.favorite` + `AppColors.error`
- 비활성 = `Icons.favorite_border_rounded` + (위치별 분기)
  - StoreMenuHeader 안: 헤더 배경에 따라 designer 가 결정 (잠정 `AppColors.textHeading` 또는 흰 영역에서 가독성 색)
  - MenuItemDetailPage 우상단 (이미지 위 `_CircleIconButton`): 기존 `AppColors.textHeading` 유지
- `FavoriteToggleIconButton` 은 inactive 컬러를 prop 으로 받아 위치마다 다른 색을 쓸 수 있게 한다.

### 결정 G. 즐겨찾기 리스트 화면 — 본 phase 비포함 (architect 잠정안, 사용자 확인 필요)

> **사용자 확인 항목 1 (architect 의견)**: Phase 2 의 자동 추천 카드와 즐겨찾기 리스트는 UX/UI 가 겹치는 부분이 많다 (둘 다 "내가 자주/지정한 매장·메뉴" 노출). 별도 화면을 Phase 1c 에 만들면 Phase 2 에서 통합/재배치할 가능성이 높아 buy-in 후 다시 손대게 됨. 따라서 **Phase 1c 는 토글 + 시각 표시 + 비로그인 처리** 까지만 좁히고, 리스트 화면은 Phase 2 의 "내 주문 라이프 (자동 추천 + 즐겨찾기)" 와 함께 한 번에 정리 권장.
>
> 단, 사용자가 "지금 당장 리스트 화면이 있어야 한다"고 판단하면 진입점은 다음 후보 중 선택:
> 1. **마이페이지 (mypage)** 의 메뉴 — 가장 자연스러움. 추가 진입점 1개로 끝.
> 2. **홈 상단 배너/카드** — Phase 2 자동 추천과 자리 다툼 가능.
> 3. **주문 탭의 별도 sub-tab** — 카트와 구조가 비슷해지나 카트는 push, 즐겨찾기는 sub-tab 이 되어 정합성 깨짐.
>
> 추천 = 비포함 또는 마이페이지 진입점 1개. **사용자 확정 후 designer/developer 호출 필요**. 본 spec 의 "비범위" 는 비포함 가정으로 작성됨.

---

## 요구사항

### 기능 요구사항

#### 매장 즐겨찾기 토글 (StoreMenuPage 매장 헤더)
- [ ] 헤더 ♥ 영역의 placeholder 스낵바 호출부 제거
- [ ] `FavoriteToggleIconButton` 위젯으로 교체
- [ ] 활성 상태 (현재 매장이 즐겨찾기에 있음) 시 `Icons.favorite` + `AppColors.error`
- [ ] 비활성 상태 시 `Icons.favorite_border_rounded` + 헤더 가독성 컬러
- [ ] 비로그인 상태에서 탭 시 로그인 유도 다이얼로그 (결정 E)
- [ ] 로그인 상태에서 탭 시 `toggleFavoriteStoreUseCase(storeId)` 호출, stream 응답 따라 시각 갱신
- [ ] 토글 실패 시 SnackBar "즐겨찾기 저장에 실패했어요"

#### 음료 즐겨찾기 토글 (MenuItemDetailPage 우상단)
- [ ] 우상단 `_CircleIconButton` 의 placeholder 스낵바 호출부 제거
- [ ] `FavoriteToggleIconButton` 으로 교체 (CircleIconButton 외형 유지 → 즉, `FavoriteToggleIconButton` 이 외형 prop 을 받거나 wrapper 형태)
- [ ] 활성 = `Icons.favorite` + `AppColors.error`, 비활성 = `Icons.favorite_border_rounded` + `AppColors.textHeading`
- [ ] 비로그인 처리 동일 (결정 E)
- [ ] 키는 `${storeId}_${menuItemId}` (composite) 기반 — `favoriteMenuItemKeysProvider` 의 Set<String> 멤버십 체크
- [ ] `toggleFavoriteMenuItemUseCase(storeId, menuItemId)` 호출

#### Provider 동작
- [ ] `favoriteStoreIdsProvider` — `StreamProvider<Set<String>>`. 비로그인 시 빈 Set emit. 로그인 시 `FavoritesRepository.watchFavoriteStores()` 결과를 `{e.storeId}` 로 매핑.
- [ ] `favoriteMenuItemKeysProvider` — `StreamProvider<Set<String>>`. 비로그인 시 빈 Set. 로그인 시 `'${storeId}_${menuItemId}'` 으로 매핑.
- [ ] 두 Provider 모두 `authProvider` 변경에 반응 (`ref.watch(authProvider)` 후 비로그인이면 Stream.value({}) emit, 로그인이면 repository stream 으로 전환)

### 상태 요구사항

| 화면 영역 | 로딩 | 에러 | 빈 상태 |
|---|---|---|---|
| ♥ 토글 (양 페이지) | 토글 In-flight 인 동안 별도 spinner 없이 stream 변경 대기 (낙관적 UI 채택, 결정 D). 단, 빠른 반복 탭 방지를 위해 각 위젯이 1초 debounce 또는 in-flight flag 유지 가능 | 토글 실패 SnackBar | 비로그인 = inactive 표시 |
| `favoriteStoreIdsProvider` 초기 로드 | initial=`{}` (빈 Set), Firestore 연결 후 자동 갱신 | error 시 빈 Set 으로 fallback + 로그 (앱 크래시 금지) | — |

---

## 데이터 모델

### Entity (재사용 — Phase 1a 작성됨)

#### `FavoriteStoreEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| storeId | String | doc id 와 동일 |
| addedAt | DateTime | 추가 시각 |

#### `FavoriteMenuItemEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| storeId | String | |
| menuItemId | String | |
| addedAt | DateTime | |

### DTO / Model (신규)

#### `FavoriteStoreModel` (`lib/data/models/favorite_store_model.dart`)
- freezed + manual fromFirestore/toFirestore
- 필드: `storeId` (doc.id), `addedAt` (Timestamp ↔ DateTime)
- toEntity / fromEntity 변환 메서드

#### `FavoriteMenuItemModel` (`lib/data/models/favorite_menu_item_model.dart`)
- freezed
- 필드: `storeId` (doc field), `menuItemId` (doc field), `addedAt` (Timestamp)
- doc.id 는 `${storeId}_${menuItemId}` (참고, model 자체는 storeId/menuItemId 분리 필드만 보유)

---

## 레이어 설계

### Domain (`lib/domain/`)

**Entities**: 재사용 (Phase 1a). 변경 없음.

**Repository Interface**: `repositories/favorites_repository.dart` 시그니처 결정 A 그대로 유지 (Phase 1a 와 동일).

**UseCases (신규 4종, `usecases/`)**:
- `toggle_favorite_store_use_case.dart`
  - `class ToggleFavoriteStoreUseCase { Future<void> call(String storeId); }`
- `toggle_favorite_menu_item_use_case.dart`
  - `class ToggleFavoriteMenuItemUseCase { Future<void> call({required String storeId, required String menuItemId}); }`
- `watch_favorite_stores_use_case.dart`
  - `class WatchFavoriteStoresUseCase { Stream<List<FavoriteStoreEntity>> call(); }`
- `watch_favorite_menu_items_use_case.dart`
  - `class WatchFavoriteMenuItemsUseCase { Stream<List<FavoriteMenuItemEntity>> call(); }`

> Set<String> 변환은 Provider 단에서 수행. UseCase 는 Repository 의 List 반환을 그대로 노출 (장기 확장성 + 일관성).

### Data (`lib/data/`)

**Models (신규)**:
- `models/favorite_store_model.dart` (freezed)
- `models/favorite_menu_item_model.dart` (freezed)

**DataSources (신규)**:
- `datasources/remote/favorites_remote_data_source.dart`
  - 생성자: `FirebaseFirestore? firestore`
  - 메서드:
    - `Stream<List<FavoriteStoreModel>> streamFavoriteStores(String uid)` — `users/{uid}/favoriteStores`, `orderBy('addedAt', descending: true)`
    - `Stream<List<FavoriteMenuItemModel>> streamFavoriteMenuItems(String uid)` — `users/{uid}/favoriteMenuItems`, `orderBy('addedAt', desc)`
    - `Stream<bool> watchStoreExists(String uid, String storeId)` — 단일 doc 존재 여부 stream
    - `Stream<bool> watchMenuItemExists(String uid, String storeId, String menuItemId)` — composite doc id stream
    - `Future<void> setFavoriteStore(String uid, String storeId)` — `set({addedAt: serverTimestamp()})`
    - `Future<void> deleteFavoriteStore(String uid, String storeId)`
    - `Future<void> setFavoriteMenuItem(String uid, String storeId, String menuItemId)` — `set({storeId, menuItemId, addedAt: serverTimestamp()})`
    - `Future<void> deleteFavoriteMenuItem(String uid, String storeId, String menuItemId)`
    - 토글의 "exists 체크 → set/delete" 흐름은 RepositoryImpl 이 조립 (DataSource 는 단순 RW)
  - **Firestore 직접 사용은 본 데이터소스 내부에서만**. 다른 레이어는 import 금지 (절대 규칙 2)

**Repository Implementation (신규)**:
- `repositories/favorites_repository_impl.dart`
  - 생성자 의존성:
    - `FavoritesRemoteDataSource _ds`
    - `String? Function() _currentUidGetter` — 현재 로그인된 사용자의 uid 를 반환 (없으면 null). Provider 에서 `() => ref.read(authProvider).value?.uid` 형태로 주입.
  - 동작:
    - `watchFavoriteStores()` — uid 없으면 `Stream.value(const [])`, 있으면 `_ds.streamFavoriteStores(uid).map(toEntity)`
    - `watchFavoriteMenuItems()` — 동일 패턴
    - `toggleFavoriteStore(storeId)` — uid 없으면 `throw UnauthenticatedException()`, 있으면 1회 doc.get 으로 exists 확인 후 set/delete
    - `toggleFavoriteMenuItem({storeId, menuItemId})` — 동일
    - `isStoreFavorited(storeId)` / `isMenuItemFavorited(...)` — uid 없으면 `Stream.value(false)`, 있으면 `_ds.watchStoreExists(...)`

**Exception (신규 또는 기존 활용)**:
- `core/errors/` 에 `UnauthenticatedException` 가 이미 있는지 확인 후, 없으면 추가 (간단한 클래스). 본 phase 작업 항목.

### Presentation

**Providers (신규)**:
- `lib/presentation/customer/order/favorites/providers/favorites_providers.dart`
  - `favoritesRemoteDataSourceProvider` — `Provider<FavoritesRemoteDataSource>`
  - `favoritesRepositoryProvider` — `Provider<FavoritesRepository>` ; 생성자 callback 으로 `() => ref.read(authProvider).valueOrNull?.uid` 주입
  - `toggleFavoriteStoreUseCaseProvider`
  - `toggleFavoriteMenuItemUseCaseProvider`
  - `watchFavoriteStoresUseCaseProvider`
  - `watchFavoriteMenuItemsUseCaseProvider`
  - `favoriteStoreIdsProvider` — `StreamProvider<Set<String>>` ; `ref.watch(authProvider)` 결과로 분기 (비로그인 → `Stream.value(const <String>{})`, 로그인 → `watchFavoriteStoresUseCase().map((list) => list.map((e) => e.storeId).toSet())`)
  - `favoriteMenuItemKeysProvider` — 동일 패턴, key = `'${e.storeId}_${e.menuItemId}'`
  - `isStoreFavoriteProvider(String storeId)` — `Provider.family<bool, String>` ; `ref.watch(favoriteStoreIdsProvider).valueOrNull?.contains(storeId) ?? false` (편의)
  - `isMenuItemFavoriteProvider((String storeId, String menuItemId))` — 동일 패턴

**공통 위젯 (신규)**:
- `lib/presentation/common/favorite_toggle_icon_button.dart`
  - `class FavoriteToggleIconButton extends ConsumerWidget`
  - props:
    - `bool isActive` (외부에서 watch 결과 주입 — 위젯 내부 watch 가 아닌 prop in 형태로 설계해 designer 가 헤더 / 우상단 Circle 등 환경별로 외형 wrapper 구성 가능)
    - `VoidCallback onTap`
    - `Color inactiveColor` (default `AppColors.textHeading`)
    - `double iconSize` (default 24)
    - `Widget Function(Widget icon)?  decoration` (선택 — Circle 배경 등을 외부에서 wrapping 할 수 있게 함)
  - 동작: active 면 `Icons.favorite` + `AppColors.error`, 아니면 `Icons.favorite_border_rounded` + `inactiveColor`. `IconButton` 으로 onTap.
  - **로그인/Firestore 호출은 위젯 내부에서 안 함**. 호출부 (StoreMenuPage / MenuItemDetailPage) 가 onTap handler 안에서 비로그인 가드 → 다이얼로그 → 토글 호출 흐름을 처리. 위젯은 시각만 담당.

> 다른 안 (위젯이 직접 store/menu 두 모드를 알게 하기) 도 가능하나, **시각 위젯과 비즈니스 로직 분리** 가 더 깔끔. 위 형태 채택.

**호출부 수정**:
- `presentation/customer/order/store/widgets/store_menu_header.dart`:
  - 기존 `onFavoriteTap: () => _showFavoritePlaceholder(context)` 시그니처를 그대로 유지하되, **호출부 (StoreMenuPage `_AppBar`)** 에서 `FavoriteToggleIconButton` 으로 교체. 또는 `store_menu_header.dart` 자체에서 `FavoriteToggleIconButton` 을 위젯 트리에 두고 active 여부를 prop 으로 받음 — designer 결정.
  - `store_menu_page.dart` 의 `_showFavoritePlaceholder` 메서드 + 호출 라인 제거.
- `presentation/customer/order/menu/menu_item_detail_page.dart`:
  - `_ImageHeader` 의 우상단 `_CircleIconButton(icon: Icons.favorite_border_rounded, onTap: ... 스낵바 ...)` 를, **`_CircleIconButton` 외형은 유지** 하면서 내부 아이콘/onTap 을 `FavoriteToggleIconButton` 의 active/onTap 정책으로 교체. 두 가지 구현 옵션:
    - (a) `_CircleIconButton` 의 child 에 `FavoriteToggleIconButton` 을 넣는다 (decoration prop 활용).
    - (b) `_CircleIconButton` 자리에 새 위젯 `_FavoriteCircleButton` 을 둬 내부에서 `FavoriteToggleIconButton` 사용 + Circle 배경 wrapping.
  - 둘 중 designer 가 디자인 시 선택. spec 은 어느 쪽이든 공통 위젯의 active 상태가 `AppColors.error` 로 표현될 것을 보장.

**기존 placeholder 제거 항목** (작업 항목 표기용):
- `store_menu_page.dart` 의 `void _showFavoritePlaceholder(BuildContext context)` + 호출 1곳
- `menu_item_detail_page.dart` 의 `_ImageHeader` 안 ♥ `IconButton` `onTap` placeholder SnackBar (라인 290~298 인근)

**라우팅**: 변경 없음 (Phase 1b 결정 A 동일 — Navigator.push 유지).

---

## 데이터 흐름

### 매장 즐겨찾기 토글 (StoreMenuPage)

```
StoreMenuHeader 의 ♥ 토글 onTap
  ├─ ref.read(authProvider).valueOrNull == null
  │     └─ showDialog(LoginRequiredDialog) → "로그인하기" 시 Navigator.push(LoginPage)
  │     └─ "취소" 시 그대로 종료
  └─ 로그인 상태:
       ├─ try { await ref.read(toggleFavoriteStoreUseCaseProvider).call(storeId); }
       ├─ on UnauthenticatedException → 로그인 다이얼로그 (안전망)
       └─ on Exception → SnackBar('즐겨찾기 저장에 실패했어요')
       (성공 시 별도 처리 없음 — favoriteStoreIdsProvider 가 stream 으로 자동 갱신)

화면 active 표시
  → ref.watch(isStoreFavoriteProvider(storeId)) 또는
     ref.watch(favoriteStoreIdsProvider).valueOrNull?.contains(storeId) ?? false
```

### 음료 즐겨찾기 토글 (MenuItemDetailPage)

```
_ImageHeader 우상단 ♥ onTap → 동일 가드/토글 흐름 (toggleFavoriteMenuItemUseCase 사용)

화면 active 표시
  → ref.watch(favoriteMenuItemKeysProvider).valueOrNull?.contains('${storeId}_${menuItemId}') ?? false
```

### Provider 분기 흐름

```
favoriteStoreIdsProvider build:
  authState = ref.watch(authProvider)
  user = authState.valueOrNull
  if (user == null) yield <String>{}; return;
  yield* watchFavoriteStoresUseCase()
           .map((list) => list.map((e) => e.storeId).toSet())
```

(`favoriteMenuItemKeysProvider` 도 동일 형태, key composer 만 다름)

### Repository 의 토글 — Firestore RW 시퀀스

```
toggleFavoriteStore(storeId):
  uid = _currentUidGetter()
  if (uid == null) throw UnauthenticatedException()
  ref = users/{uid}/favoriteStores/{storeId}
  exists = (await ref.get()).exists
  if (exists) await ref.delete();
  else await ref.set({addedAt: FieldValue.serverTimestamp()});
```

(menu item 도 동일, `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` 에 storeId / menuItemId / addedAt 필드 set.)

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 비로그인 토글 시도 | 로그인 유도 다이얼로그 노출 (Firestore 호출 X) |
| 로그인 상태인데 RepositoryImpl 에 uid 미전달 (race) | `UnauthenticatedException` → 안전망 다이얼로그 |
| Firestore 쓰기 실패 (네트워크/권한) | SnackBar "즐겨찾기 저장에 실패했어요" + 시각 변경 안 됨 |
| Firestore stream 에러 | Provider 의 AsyncError → `valueOrNull` 사용해 빈 Set 으로 fallback (앱 크래시 X). 디버그 로그 |
| 동시 더블탭 | 짧은 시간 내 set→delete→set 호출이 서로 race 해도 Firestore idempotent set/delete 로 최종 상태 수렴. 본 phase 는 transaction 미사용 |
| 매장 / 메뉴가 deleted 됐는데 즐겨찾기에 남아있음 | 본 phase 비대응 (Phase 2 정리 — 매장 삭제 시 cleanup 또는 cron) |

---

## 보안 / 환경 설정

- 변경 없음 (Firestore 보안 규칙 별도 task). 단 본 phase 의 컬렉션 경로 (`users/{uid}/favoriteStores/{storeId}`, `users/{uid}/favoriteMenuItems/{compositeId}`) 가 향후 보안 규칙 task 의 입력. **본인 uid 만 read/write 허용** 되도록 규칙 작성 예정.
- 카카오/네이버 로그인 사용자도 `users/{uid}` 가 동일하게 (prefix 포함) 작성되므로 호환.

---

## 의존성

- 신규 패키지 없음. `cloud_firestore`, `hooks_riverpod`, `freezed_annotation` 모두 기존 사용 중.

---

## 작업 분배

### designer

작성 대상: `docs/tasks/order_flow_phase1c/design.md`

작업 필요 여부 판단: **얕은 시각 분기 (active=AppColors.error / inactive 색) + 로그인 다이얼로그 톤** 정도이므로 designer 호출은 **권장(필수 아님)**. 다음을 정의:

1. **`FavoriteToggleIconButton` 시각** — active / inactive 두 상태 + 위치별 inactive 컬러 가이드 (헤더 vs Circle 배경 위)
2. **StoreMenuHeader 의 ♥ 위치 / 사이즈 / 패딩** — Phase 1a 의 placeholder 자리를 재사용하되 active 컬러 분기 시각 확정
3. **MenuItemDetailPage 의 `_CircleIconButton` 안 ♥** — Circle 배경 + active 시 빨간 아이콘 대비 검토 (기존 `surfaceElevated.withValues(alpha:0.85)` 배경에 active 빨간 ♥ 가독성)
4. **로그인 유도 다이얼로그** — 텍스트 톤 (결정 E 의 잠정안) 확정 + Qradar 다이얼로그 스타일 (이미 Phase 1b 의 카트 충돌 다이얼로그 톤 참조)
5. (조건부) **즐겨찾기 리스트 화면** — 사용자 확정 시 추가 화면 디자인 필요. 본 spec 잠정안은 비포함

> Designer 가 시각 변경을 최소화 한다고 판단하면 design.md 는 짧게 (1~2 페이지) 끝나고 developer 로 넘긴다.

### developer

작성 대상: `docs/tasks/order_flow_phase1c/implementation.md`

핵심 작업 순서:

1. **Domain UseCase 4종 신규 작성**:
   - `lib/domain/usecases/toggle_favorite_store_use_case.dart`
   - `lib/domain/usecases/toggle_favorite_menu_item_use_case.dart`
   - `lib/domain/usecases/watch_favorite_stores_use_case.dart`
   - `lib/domain/usecases/watch_favorite_menu_items_use_case.dart`
2. **Data Models 2종**:
   - `lib/data/models/favorite_store_model.dart`
   - `lib/data/models/favorite_menu_item_model.dart`
   - freezed → `dart run build_runner build --delete-conflicting-outputs`
3. **DataSource 신규**:
   - `lib/data/datasources/remote/favorites_remote_data_source.dart`
   - 컬렉션 경로 상수 사용 (`FirestorePaths.users`, `FirestorePaths.favoriteStores`, `FirestorePaths.favoriteMenuItems` — 모두 기존)
4. **RepositoryImpl 신규**:
   - `lib/data/repositories/favorites_repository_impl.dart`
   - uid getter callback 주입
5. **`UnauthenticatedException`** — `core/errors/` 에 미존재 시 신규 추가
6. **Presentation Providers**:
   - `lib/presentation/customer/order/favorites/providers/favorites_providers.dart` (DI 체인 + `favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider`)
7. **공통 위젯**:
   - `lib/presentation/common/favorite_toggle_icon_button.dart`
8. **호출부 placeholder 제거 + wiring**:
   - `store_menu_page.dart` / `store_menu_header.dart` (매장 ♥)
   - `menu_item_detail_page.dart` (메뉴 ♥)
   - 로그인 유도 다이얼로그 헬퍼 함수 (공통화: `showFavoriteLoginDialog(context)` — `presentation/common/` 또는 favorites 폴더)
9. `flutter analyze` / 시드 매장 + 매장/메뉴 ♥ 토글 수동 검증 (로그인 / 비로그인 / 다른 매장 즐겨찾기 / Firestore 콘솔에 doc 들어가는지)
10. 비로그인 → 다이얼로그 → 로그인 → 다시 매장 진입 → ♥ 활성 정상 표시 흐름 수동 검증

산출물: 코드 + `implementation.md` (Firestore 컬렉션에 쌓이는 doc 형태 예시 포함)

### tester

작성 대상: `docs/tasks/order_flow_phase1c/test_report.md`

검증 항목:

- 로그인 상태 매장 ♥ 토글 → Firestore `users/{uid}/favoriteStores/{storeId}` doc 생성/삭제 정상
- 로그인 상태 메뉴 ♥ 토글 → Firestore `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` doc 생성/삭제 정상 + 필드 storeId/menuItemId/addedAt 들어감
- 같은 매장 다시 ♥ 탭 → 토글 (제거 → 재추가)
- 다른 매장 ♥ 탭 → 두 매장 모두 즐겨찾기 (서로 독립)
- 같은 매장 안 다른 메뉴 ♥ 탭 → 두 메뉴 모두 즐겨찾기 (storeId 같음, menuItemId 다름)
- 비로그인 상태 매장 ♥ 탭 → 로그인 다이얼로그 노출 → "취소" 시 그대로 종료
- 비로그인 상태 메뉴 ♥ 탭 → 동일
- 비로그인 다이얼로그 "로그인하기" → LoginPage push → 로그인 성공 → 다시 매장 진입 → 즐겨찾기 정상 동작
- 로그아웃 후 ♥ 즉시 inactive (`favoriteStoreIdsProvider` 가 빈 Set 으로 전환)
- 다른 디바이스에서 같은 uid 로그인 → 즐겨찾기 stream 으로 동기화
- 토글 in-flight 중 SnackBar 실패 케이스 (네트워크 끊고 토글) — 시각 변경 없음 + SnackBar 노출
- 색상: active = `AppColors.error`, 다른 화면에 색 영향 없음
- 레이어: Presentation 에서 `cloud_firestore` import 없음, `domain/` 에서 `cloud_firestore` import 없음
- `flutter analyze` 0 issue
- Phase 1a/1b 의 placeholder 스낵바 ("Phase 1c 에서 즐겨찾기 추가됩니다") 가 코드/UI 모두에서 제거됨

---

## 사용자 확정사항 (2026-04-27)

> 사용자가 architect 추천안을 그대로 채택. 본 phase 작업 입력으로 lock-in.

### 확정 1. 즐겨찾기 리스트 화면 — **Phase 1c 비포함**

- Phase 2 의 자동 추천 카드와 UX 중복 회피. Phase 2 에서 통합 정리.
- 본 phase 는 **토글 + 시각 표시 + 비로그인 처리** 까지만.

### 확정 2. 비로그인 다이얼로그 텍스트 + 로그인 라우트

- 제목: "로그인이 필요해요"
- 본문: "즐겨찾기를 저장하려면 Qrator 로그인이 필요해요."
- 버튼: "취소" / "로그인하기"
- 라우트: `Navigator.push(MaterialPageRoute(builder: (_) => const LoginPage()))` — 기존 `lib/presentation/customer/auth/login_page.dart`. (Phase 1 시리즈는 go_router 미도입)
- 다이얼로그 스타일: Phase 1b 의 카트 충돌 다이얼로그 톤 그대로 재사용.

### 확정 3. UI 정책 — **stream-driven UI**

- 별도 in-memory 낙관적 캐시 없음. Firestore stream (~100~300ms) 에 의존해 자연스러운 갱신.
- 토글 onTap → 즉시 `repository.toggle*` await → stream 재emit → UI 갱신.
- 토글 실패 시 시각 변경 없음 + SnackBar "즐겨찾기 저장에 실패했어요".
- Phase 2 에서 체감 지연 거슬릴 경우 optimistic 캐시 추가 검토 (본 phase 비범위).

### 확정 4. designer skip

- 시각 변경이 (a) ♥ active=`AppColors.error` 분기, (b) 다이얼로그 톤 (Phase 1b 재사용) 정도라 designer 호출 생략.
- developer 가 본 spec + Phase 1b 카트 충돌 다이얼로그 톤 그대로 따라 구현.

---

## 완료 기준

- [ ] `design.md` 작성 (또는 디자인 변경 미미 명시) / `implementation.md` / `test_report.md` 작성 완료
- [ ] `flutter analyze` 0 issue
- [ ] Phase 1a/1b 의 즐겨찾기 placeholder 스낵바 코드/문구 모두 제거 (grep "Phase 1c" 잔존 없음 — placeholder 와 관련된 라인만)
- [ ] 매장/메뉴 ♥ 토글이 실제 Firestore RW 와 동작
- [ ] 비로그인 처리 (다이얼로그 + 로그인 페이지 push) 정상
- [ ] FAIL 항목 0 또는 후속 분리
- [ ] umbrella spec 결정 6 의 컬렉션 구조와 일치 (storeId / menuItems composite 키 / addedAt 필드)
- [ ] Phase 2 자동 추천이 본 RepositoryImpl + Provider 를 변경 없이 재사용 가능 (인터페이스 안정성)
