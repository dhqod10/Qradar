# 주문 플로우 Phase 1c 구현 내역 (즐겨찾기 본구현 — Favorites)

## 개요

- **구현 목적**: Phase 1a / 1b 의 ♥ placeholder 스낵바를 실제 Firestore 토글 동작으로 교체. umbrella spec 결정 6 의 "두 컬렉션 분리" 구조를 그대로 구현.
- **기준 문서**:
  - [docs/tasks/order_flow_phase1c/spec.md](spec.md)
  - [docs/tasks/order_flow_phase1/spec.md](../order_flow_phase1/spec.md) — umbrella, 결정 6 (즐겨찾기 두 컬렉션 분리)
  - [docs/tasks/order_flow_phase1b/implementation.md](../order_flow_phase1b/implementation.md) — 다이얼로그 톤 / Provider DI 패턴 참조

본 phase 는 **사용자 확정 4 (designer skip)** 에 따라 design.md 미작성. 본 implementation.md 가 spec + 호출부 코드 정합성을 단일 진실원으로 갖는다.

---

## 구현 파일 목록

### 신규 — Core
- `lib/core/errors/unauthenticated_exception.dart` — 인증 필요 동작 시 RepositoryImpl 이 throw. Presentation 의 가드 누락 / race 시 안전망 역할.

### 신규 — Domain (UseCase 4종)
- `lib/domain/usecases/toggle_favorite_store_use_case.dart` — `Future<void> call(String storeId)`
- `lib/domain/usecases/toggle_favorite_menu_item_use_case.dart` — `Future<void> call({required String storeId, required String menuItemId})`
- `lib/domain/usecases/watch_favorite_stores_use_case.dart` — `Stream<List<FavoriteStoreEntity>> call()`
- `lib/domain/usecases/watch_favorite_menu_items_use_case.dart` — `Stream<List<FavoriteMenuItemEntity>> call()`

### 신규 — Data
- `lib/data/models/favorite_store_model.dart` — plain class (기존 `MenuItemModel` / `SubCategoryModel` 패턴 일치). `fromFirestore` / `fromEntity` / `toEntity` / `toCreatePayload`.
- `lib/data/models/favorite_menu_item_model.dart` — plain class. `compositeId(storeId, menuItemId)` 헬퍼 + `toCreatePayload({storeId, menuItemId})`.
- `lib/data/datasources/remote/favorites_remote_data_source.dart` — Firestore 직접 사용 (절대 규칙 2). stream / once / set / delete 메서드만 노출, "exists 체크 → set/delete" 조립은 RepositoryImpl 책임.
- `lib/data/repositories/favorites_repository_impl.dart` — `FavoritesRepository` 구현. 생성자에 `(FavoritesRemoteDataSource, String? Function() currentUidGetter)` 주입.

### 신규 — Presentation
- `lib/presentation/customer/order/favorites/providers/favorites_providers.dart` — DI 체인 + `favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider` (Set 기반 빠른 멤버십 체크) + `favoriteMenuItemKey(...)` 헬퍼.
- `lib/presentation/common/favorite_toggle_icon_button.dart` — 시각만 담당 (StatelessWidget). active=`Icons.favorite` + `AppColors.error`, inactive=`Icons.favorite_border_rounded` + `inactiveColor` (default `AppColors.textHeading`).
- `lib/presentation/common/favorite_login_required_dialog.dart` — `Future<bool> showFavoriteLoginRequiredDialog(BuildContext)` — Phase 1b `_confirmReplaceCart` 톤 그대로 (surfaceElevated, 16px radius, w700/16 title, w500/13 content). 액션은 "취소" / "로그인하기" — primary 컬러.

### 수정 — Presentation
- `lib/presentation/customer/order/store/widgets/store_menu_header.dart`
  - `StoreMenuHeader` 시그니처에 `bool isFavorite` 신규 추가 (호출부와 정합 유지).
  - 내부 ♥ `IconButton` → `FavoriteToggleIconButton(isActive: isFavorite, onTap: onFavoriteTap, inactiveColor: AppColors.onPrimary)` (헤더 배경이 어두운 그라데이션이라 inactive 는 `onPrimary` 흰색 유지).
- `lib/presentation/customer/order/store/store_menu_page.dart`
  - `_AppBar` 가 `favoriteStoreIdsProvider` watch → `isFavorite = favoriteIds.contains(store.id)`.
  - `_onToggleStoreFavorite(context, ref, storeId)` 신규 top-level helper — 비로그인 가드 → 다이얼로그 → LoginPage push / 로그인 시 toggleFavoriteStoreUseCase await + 실패 SnackBar.
  - `_showFavoritePlaceholder` 제거.
- `lib/presentation/customer/order/menu/menu_item_detail_page.dart`
  - `_ImageHeader` 를 `ConsumerWidget` 으로 전환. props 에 `storeId`, `menuItemId` 추가.
  - 우상단 ♥ placeholder SnackBar 제거. `favoriteMenuItemKeysProvider` watch + `favoriteMenuItemKey(...)` 멤버십 체크로 isFavorite 결정.
  - `_CircleIconButton` 시그니처를 `{required IconData icon, required VoidCallback onTap}` → `{required Widget child, required VoidCallback onTap}` 으로 일반화. active 시 빨간 ♥ 를 child 로 넣어 외형(Circle 배경 + 40×40)은 그대로 유지하면서 색만 분기.
  - `_onToggleMenuItemFavorite(...)` top-level helper 신규 — 매장 토글과 같은 패턴.

### 재사용
- `lib/domain/entities/favorite_store_entity.dart` (Phase 1a)
- `lib/domain/entities/favorite_menu_item_entity.dart` (Phase 1a)
- `lib/domain/repositories/favorites_repository.dart` (Phase 1a) — 시그니처 결정 A 와 일치. **변경 없음**.
- `lib/core/constants/firestore_paths.dart` — `favoriteStores`, `favoriteMenuItems` 키 이미 정의됨. **변경 없음**.

### 의존성
- 신규 패키지 없음 (`cloud_firestore`, `hooks_riverpod` 모두 기존).
- `freezed` / `build_runner` 신규 generated 없음 (모델은 plain class).

---

## 주요 결정사항

### 결정 1. 모델 = plain class (spec 의 freezed 가이드와 차이)

- **결정**: `FavoriteStoreModel` / `FavoriteMenuItemModel` 을 plain class 로 작성.
- **이유**: 기존 코드베이스의 다른 모델 (`SubCategoryModel`, `MenuItemModel`, `OptionGroupModel`) 이 모두 plain class 패턴이고, Favorite 모델은 2~3개 필드밖에 없어 freezed 의 `copyWith` / `==` 효용이 거의 없음. **"기존 구조와 패턴을 우선 재사용"** (developer_guide.md 기본 원칙) 을 더 우선시. `UserModel` 만 freezed 인 것은 JSON 직렬화(소셜 로그인 페이로드 호환) 때문이라 본 케이스와 무관.
- **트레이드오프**: spec 결정에 명시된 "freezed + manual fromFirestore/toFirestore" 와 다름. 단, **변환 메서드 (`fromFirestore` / `fromEntity` / `toEntity` / `toCreatePayload`) 의 동작은 spec 그대로**. 추후 필드가 늘어 freezed 가 필요해지면 마이그레이션 단순.

### 결정 2. uid 획득 = callback 패턴 (spec 결정 B 보강)

- **결정**: `FavoritesRepositoryImpl(FavoritesRemoteDataSource ds, String? Function() currentUidGetter)`. Provider 에서 `() => ref.read(authProvider).asData?.value?.uid` 로 묶어 주입.
- **이유**: spec 의 "사용자 확인 항목 (architect 의견 첨부)" 에서 명시된 카카오 / 네이버 prefix uid 호환. `FirebaseAuth.instance.currentUser?.uid` 직접 사용 시 카카오/네이버 사용자가 즐겨찾기를 사용할 수 없게 됨. callback 으로 받아 `authProvider` 의 `UserEntity.uid` (prefix 포함) 를 그대로 사용.
- **`asData?.value` 사용**: 이 코드베이스의 `AsyncNotifier` 는 `valueOrNull` getter 를 노출하지 않아 (`hooks_riverpod` 버전 영향) 기존 `user_profile_provider.dart` 와 동일하게 `asData?.value` 패턴을 채택.

### 결정 3. UI 정책 = stream-driven (사용자 확정 3)

- 별도 in-memory optimistic 캐시 두지 않음. `favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider` 의 `StreamProvider<Set<String>>` 만 single source of truth.
- 토글 onTap → `await UseCase.call(...)` → Firestore stream emit → Set 변경 → UI 갱신.
- 실패 시 시각 변경 없음 + SnackBar `'즐겨찾기 저장에 실패했어요'`.

### 결정 4. 멤버십 체크 = Set + inline `contains` (family Provider 미사용)

- spec 에 "단순 derive 라 family Provider 가 아니라 화면에서 직접 `contains` 체크해도 됨" 명시. **inline `contains` 채택**.
- 이유: 단일 화면에서 매장 1개 / 메뉴 1개 만 체크하면 됨. family Provider 는 인스턴스 수만 늘리고 의미는 동일. Set 기반 `contains` 는 O(1) 라 성능 차이도 없음.

### 결정 5. `_CircleIconButton` 시그니처 일반화 (옵션 a 채택)

- spec 에서 두 옵션 (a) `_CircleIconButton.child` 에 `FavoriteToggleIconButton` 넣기 / (b) `_FavoriteCircleButton` wrapper 신설.
- **(a) 채택, 단 `FavoriteToggleIconButton` 자체는 사용하지 않고 `_CircleIconButton` 의 child 에 그냥 `Icon` 위젯을 넣음**. 이유: `FavoriteToggleIconButton` 은 `IconButton` 기반이라 자체 padding/touch target 이 있어 40×40 Circle 배경 안에서 이중 ripple/padding 이 됨. 외형(Circle 40×40 + InkWell)을 유지하려면 `Icon` 만 child 로 넣고 InkWell 의 onTap 으로 토글 흐름을 직접 호출하는 것이 시각·동작 정합성이 더 깔끔.
- 헤더 ♥ 는 `FavoriteToggleIconButton` 사용 (외형 wrapper 없음 → 정상 동작).

### 결정 6. 비로그인 다이얼로그 = Phase 1b 톤 재사용 (사용자 확정 2)

- `showFavoriteLoginRequiredDialog` 가 Phase 1b 의 `_confirmReplaceCart` 와 같은 시각 (배경 surfaceElevated, 16px radius, title w700/16, content w500/13, 액션 TextButton 두 개).
- **차이점**: 액션 컬러. 카트 충돌은 "비우고 시작" 이 위험 동작이라 `error`. 본 phase 의 "로그인하기" 는 긍정 동작이라 `primary`.

### 결정 7. inactive 컬러 (위치별 분기)

- StoreMenuHeader (헤더 어두운 그라데이션 위) → `AppColors.onPrimary` (흰색) — Phase 1a 외형 유지.
- MenuItemDetailPage `_ImageHeader` 우상단 (흐릿한 surfaceElevated Circle 배경 위) → `AppColors.textHeading` — 기존 `_CircleIconButton` 색 유지.
- active 는 두 곳 모두 `AppColors.error`.

### 결정 8. UnauthenticatedException 안전망

- 정상 흐름은 Presentation 가드 (다이얼로그) 가 비로그인 호출을 막음.
- `RepositoryImpl.toggleFavorite*` 도 uid null 시 `UnauthenticatedException` throw — race (가드 통과 직후 로그아웃 등) 시 안전망 + Firestore 보안 규칙 의도와 정합.
- 호출부 (`store_menu_page` / `menu_item_detail_page`) 가 `on UnauthenticatedException` 캐치 → 다이얼로그 재노출.

---

## spec.md 대비 차이

- **모델 형태**: spec 결정 = freezed. 실제 = plain class. 이유는 결정 1 참조. 동작 / 변환 메서드 / Firestore 페이로드는 spec 그대로.
- **family Provider 미사용**: spec 에 "단순 derive 라 inline `contains` 도 가능" 명시 — inline 으로 채택. spec 이 양쪽을 허용한 부분이라 `차이` 라기보다 `선택`.
- **`_CircleIconButton` 시그니처**: spec 옵션 (a)/(b) 중 (a) 의 변형 (`FavoriteToggleIconButton` 대신 `Icon` 직접) — 이중 padding/ripple 회피.
- 그 외 (UseCase 4종 / DataSource 메서드 / RepositoryImpl 알고리즘 / 다이얼로그 텍스트 / 컬러 / 데이터 흐름): spec 그대로.

## design.md 대비 차이

- design.md 미작성 (사용자 확정 4 — designer skip). 본 implementation.md 가 시각 정의 단일 진실원.

---

## Firestore 컬렉션 doc 형태 예시

### `users/{uid}/favoriteStores/{storeId}`
```json
{
  "addedAt": <Timestamp> (서버 타임스탬프)
}
```
- doc.id = storeId 그 자체.
- 컬렉션 키: `FirestorePaths.favoriteStores` (= `'favoriteStores'`).

### `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}`
```json
{
  "storeId": "store_abc123",
  "menuItemId": "menu_xyz789",
  "addedAt": <Timestamp>
}
```
- doc.id = composite `${storeId}_${menuItemId}` (파싱 X — 필드 별도 저장).
- 컬렉션 키: `FirestorePaths.favoriteMenuItems` (= `'favoriteMenuItems'`).

### 쿼리 정렬
- `streamFavoriteStores(uid)` → `orderBy('addedAt', descending: true)`
- `streamFavoriteMenuItems(uid)` → `orderBy('addedAt', descending: true)`

### 토글 알고리즘 (RepositoryImpl)
```
toggleFavoriteStore(storeId):
  uid = currentUidGetter()
  if uid == null: throw UnauthenticatedException()
  exists = await ds.getStoreExistsOnce(uid, storeId)  // doc.get
  if exists: await ds.deleteFavoriteStore(uid, storeId)
  else: await ds.setFavoriteStore(uid, storeId)
```
menu item 도 동일 패턴 (compositeId 사용).

### 보안 규칙 메모 (별도 task)
- 향후 Firestore 보안 규칙 task 가 본 phase 의 컬렉션 경로를 입력으로 받음.
- 본인 uid 만 read/write 허용:
  ```
  match /users/{uid}/favoriteStores/{storeId} {
    allow read, write: if request.auth.uid == uid;
  }
  match /users/{uid}/favoriteMenuItems/{compositeId} {
    allow read, write: if request.auth.uid == uid;
  }
  ```
- **카카오/네이버 prefix uid** 는 Firebase Auth 와 다르므로, 본 phase 의 callback 패턴 + 별도 인증 어댑터가 필요할 수 있음 (보안 규칙 작성 task 의 설계 고려사항).

---

## 테스트 포인트

### 1. 매장 즐겨찾기 토글 (StoreMenuPage)
1. **로그인 상태 매장 ♥ 탭** → 1초 이내 ♥ 가 빨간색 (`AppColors.error`) 으로 활성화. Firestore 콘솔 `users/{uid}/favoriteStores/{storeId}` 에 doc 생성 + `addedAt` 필드 (Timestamp) 보임.
2. **활성 ♥ 다시 탭** → ♥ 가 빈 ♥ (흰색 / inactive) 로 전환. Firestore doc 삭제 확인.
3. **다른 매장 진입 후 ♥ 탭** → 두 매장 모두 즐겨찾기 등록 (서로 독립). 각 매장 진입 시 자기 매장의 ♥ 만 활성.
4. **헤더 시각**: 활성 = `Icons.favorite` + `AppColors.error` / 비활성 = `Icons.favorite_border_rounded` + `AppColors.onPrimary` (헤더 어두운 그라데이션 위 가독성).

### 2. 음료 즐겨찾기 토글 (MenuItemDetailPage)
5. **메뉴 상세 우상단 ♥ 탭** → ♥ 활성 (빨강). Firestore `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` doc 생성 + 필드 `storeId` / `menuItemId` / `addedAt` 보임.
6. **같은 매장 다른 메뉴 ♥** → 두 페어 모두 등록 (storeId 같지만 menuItemId 다름). 각 메뉴 진입 시 자기 메뉴 ♥ 만 활성.
7. **다른 매장 같은 menuItemId 의 메뉴 ♥** → 별개 doc (storeId 다르므로 compositeId 다름).
8. **외형 검증**: `_CircleIconButton` 의 40×40 Circle 배경 (`surfaceElevated` α=0.85) 유지. active 시 Circle 안의 ♥ 만 빨강. 좌상단 뒤로가기 버튼 외형도 변경 없음.

### 3. 비로그인 처리
9. **비로그인 매장 ♥ 탭** → 로그인 다이얼로그 노출 (제목 "로그인이 필요해요" / 본문 "즐겨찾기를 저장하려면 Qrator 로그인이 필요해요." / 버튼 "취소" / "로그인하기"). "취소" → 그대로 종료 (Firestore 호출 없음).
10. **비로그인 다이얼로그 "로그인하기"** → `LoginPage` push. 로그인 성공 → `RoleRouter` 로 `pushAndRemoveUntil` (LoginPage 기존 동작) → 사용자가 다시 매장/메뉴 진입 → ♥ 정상 동작.
11. **비로그인 메뉴 ♥** → 동일 흐름.

### 4. 로그아웃 / 다른 디바이스 동기화
12. **로그아웃** → `favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider` 가 `Stream.value(<>)` 로 전환되어 모든 ♥ inactive.
13. **다른 디바이스에서 같은 uid 로 로그인 → 즐겨찾기 추가** → 본 디바이스의 stream 이 자동 갱신되어 ♥ 활성.

### 5. 에러 처리 (수동 시뮬레이션 권장)
14. **오프라인 상태에서 ♥ 탭** → 시각 변경 없음 + SnackBar `'즐겨찾기 저장에 실패했어요'` 노출 (try/catch).
15. **race 시뮬레이션**: 로그인 직후 빠르게 로그아웃하고 ♥ 탭 — `UnauthenticatedException` 캐치 → 다이얼로그 재노출.

### 6. 레이어 / 회귀
16. `flutter analyze` → `No issues found! (ran in 5.2s)`.
17. `presentation` / `domain` 디렉토리에서 `cloud_firestore` import 0건 (절대 규칙 2).
18. Phase 1a/1b 의 `'즐겨찾기는 준비 중입니다 (Phase 1c)'` 스낵바 / `_showFavoritePlaceholder` 메서드 코드 잔존 0건 (grep 검증 완료).
19. **카트 / 결제 등 무관 동작 회귀 X**: 매장/메뉴 진입, 카트 담기, 옵션 선택 등 모두 정상.

---

## 미구현 / 보류 항목

- **즐겨찾기 리스트 화면** (My Favorites Page) — 사용자 확정 1: Phase 1c 비포함. Phase 2 자동 추천과 함께 통합 정리.
- **Phase 2 자동 추천 로직** — `recommendation_thresholds.dart` 활용한 빈도 산정 알고리즘. 본 phase 비범위.
- **매장 / 메뉴 삭제 시 즐겨찾기 cleanup** — 매장/메뉴가 deleted 됐는데 즐겨찾기에 남아있는 경우. Phase 2 cron 또는 cleanup 로직.
- **Optimistic UI 캐시** — 사용자 확정 3: stream-driven. 체감 지연 거슬릴 시 Phase 2 에서 검토.
- **Post-login deeplink** — 로그인 후 원래 화면 자동 복귀. 라우터 미도입 상태에서 복잡도 큼. 본 phase 비범위.
- **Firestore 보안 규칙** — 별도 task. 본 phase 컬렉션 경로가 입력.
- **Race-safe transaction 토글** — 동시 더블탭 race 는 Firestore set/delete idempotency 로 최종 수렴. 필요 시 향후 transaction 으로 감쌈.
- **즐겨찾기 정렬/그룹/검색 UI** — 리스트 화면과 함께 Phase 2.

---

## 코드 생성 필요 여부

- [x] 필요 없음

신규 freezed/json_serializable 파일 없음. 모델은 plain class. `dart run build_runner build` 실행 불필요.

---

## 검증

- `flutter analyze` — `No issues found! (ran in 5.2s)` (lib 전체)
- placeholder 잔존 grep:
  - `_showFavoritePlaceholder` → 0건
  - `'즐겨찾기는 준비 중'` → 0건
  - `'Phase 1c 에서 즐겨찾기'` → 0건
- `flutter test` — 본 phase 신규 단위 테스트 추가 없음 (수동 검증 항목은 위 테스트 포인트 참조). 기존 테스트 무관.

---

## 사용자 검증 필요 (수동 시나리오)

- [ ] Firestore 콘솔에서 `users/{uid}/favoriteStores/{storeId}` 와 `users/{uid}/favoriteMenuItems/{compositeId}` doc 가 토글에 따라 생성/삭제되는지 직접 확인 (특히 카카오/네이버 prefix uid 케이스).
- [ ] 비로그인 다이얼로그 → "로그인하기" → LoginPage 진입 → 로그인 성공 → 매장 재진입 → ♥ 정상 동작 e2e.
- [ ] 다른 디바이스에서 동일 uid 로 즐겨찾기 추가 시 본 디바이스 stream 갱신 (실시간 동기화).
- [ ] 오프라인 상태 토글 시 SnackBar + 시각 변경 없음.
