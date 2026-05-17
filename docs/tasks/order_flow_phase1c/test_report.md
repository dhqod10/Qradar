# order_flow_phase1c 테스트 리포트

## 테스트 일시

- 2026-04-27

---

## 테스트 방법

- 정적 코드 검증 (spec / implementation 교차 대조 + 실제 코드 read)
- Grep 으로 import / 잔존 placeholder / 색상 하드코딩 검증
- 파일 비교 (Phase 1a 엔티티 / Repository interface 변경 여부 + Phase 1b cart_providers.dart / cart_page.dart 변경 여부)
- `flutter analyze` (lib 전체)
- `flutter test` 미실행 (본 phase 신규 단위 테스트 없음, 기존 테스트 회귀 가능성 낮음 — implementation.md 검증)
- `dart run build_runner build` 미실행 (신규 freezed/json_serializable 0건)
- design.md 부재 확인 (사용자 확정 4)

---

## 전체 결과

- PASS: 39개
- FAIL: 0개
- 보류: 2개

---

## PASS 항목

### 1. 레이어 규칙

- [x] **`cloud_firestore` import — data 레이어로만 한정**
  - 근거: `lib/presentation`, `lib/domain` 디렉토리 grep `cloud_firestore|firebase_auth` 결과 → presentation 측은 `lib/presentation/customer/auth/auth_provider.dart` 1건만 매치 (auth 기존 코드, 본 phase 외 영역). domain 0건. 본 phase 신규 코드는 모두 통과.
  - 위치: [favorites_remote_data_source.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/data/datasources/remote/favorites_remote_data_source.dart#L1) (data 레이어, 허용), [favorite_store_model.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/data/models/favorite_store_model.dart#L1), [favorite_menu_item_model.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/data/models/favorite_menu_item_model.dart#L1)

- [x] **Domain UseCase 가 Repository interface 에만 의존**
  - 근거: 4종 UseCase 모두 `qradar/domain/repositories/favorites_repository.dart` 와 `qradar/domain/entities/...` 만 import. 다른 레이어 의존 없음.
  - 위치: [toggle_favorite_store_use_case.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/domain/usecases/toggle_favorite_store_use_case.dart#L1), [toggle_favorite_menu_item_use_case.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/domain/usecases/toggle_favorite_menu_item_use_case.dart#L1), [watch_favorite_stores_use_case.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/domain/usecases/watch_favorite_stores_use_case.dart#L1), [watch_favorite_menu_items_use_case.dart:1](/Users/Byeonguk/Developer/OrderApp/lib/domain/usecases/watch_favorite_menu_items_use_case.dart#L1)

- [x] **RepositoryImpl uid 획득 = callback 패턴, `firebase_auth` 직접 import 0건 (결정 B 보강 반영)**
  - 근거: `FavoritesRepositoryImpl` 의 생성자가 `(FavoritesRemoteDataSource ds, String? Function() currentUidGetter)` 시그니처. `firebase_auth` import 없음. spec 의 사용자 확인 항목 (카카오/네이버 prefix uid 호환) 그대로 반영. Provider 가 `() => ref.read(authProvider).asData?.value?.uid` 로 묶어 주입.
  - 위치: [favorites_repository_impl.dart:13-20](/Users/Byeonguk/Developer/OrderApp/lib/data/repositories/favorites_repository_impl.dart#L13-L20), [favorites_providers.dart:18-24](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/favorites/providers/favorites_providers.dart#L18-L24)

### 2. 컬렉션 경로 / 문서 키 규칙 (umbrella spec 결정 6)

- [x] **`users/{uid}/favoriteStores/{storeId}` — 필드 `addedAt` (Timestamp / serverTimestamp)**
  - 근거: `_favoriteStores(uid)` = `users.doc(uid).collection(favoriteStores)`. doc id 가 storeId (`.doc(storeId)`). 페이로드 `{'addedAt': FieldValue.serverTimestamp()}`.
  - 위치: [favorites_remote_data_source.dart:19-23,74-78](/Users/Byeonguk/Developer/OrderApp/lib/data/datasources/remote/favorites_remote_data_source.dart#L19-L78), [favorite_store_model.dart:42-45](/Users/Byeonguk/Developer/OrderApp/lib/data/models/favorite_store_model.dart#L42-L45), [firestore_paths.dart:22](/Users/Byeonguk/Developer/OrderApp/lib/core/constants/firestore_paths.dart#L22)

- [x] **`users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}` — 필드 `storeId`, `menuItemId`, `addedAt`**
  - 근거: `_favoriteMenuItems(uid)` 컬렉션 + `compositeId` = `'${storeId}_$menuItemId'`. set 페이로드에 storeId / menuItemId / addedAt 3필드 모두 포함.
  - 위치: [favorites_remote_data_source.dart:25-29,86-101](/Users/Byeonguk/Developer/OrderApp/lib/data/datasources/remote/favorites_remote_data_source.dart#L25-L101), [favorite_menu_item_model.dart:50-66](/Users/Byeonguk/Developer/OrderApp/lib/data/models/favorite_menu_item_model.dart#L50-L66), [firestore_paths.dart:25](/Users/Byeonguk/Developer/OrderApp/lib/core/constants/firestore_paths.dart#L25)

### 3. 토글 알고리즘

- [x] **exists 체크 후 set/delete 분기**
  - 근거: `toggleFavoriteStore` / `toggleFavoriteMenuItem` 모두 `getStoreExistsOnce` (또는 `getMenuItemExistsOnce`) 후 `if exists → delete / else → set` 분기. spec 결정 C 그대로.
  - 위치: [favorites_repository_impl.dart:71-97](/Users/Byeonguk/Developer/OrderApp/lib/data/repositories/favorites_repository_impl.dart#L71-L97)

- [x] **uid null → `UnauthenticatedException` throw (toggle 메서드)**
  - 근거: `toggleFavoriteStore` / `toggleFavoriteMenuItem` 둘 다 진입 시 `if (uid == null) throw const UnauthenticatedException();`. 생성자 const 형태로 선언됨.
  - 위치: [favorites_repository_impl.dart:73-74,87-89](/Users/Byeonguk/Developer/OrderApp/lib/data/repositories/favorites_repository_impl.dart#L73-L89), [unauthenticated_exception.dart:6-13](/Users/Byeonguk/Developer/OrderApp/lib/core/errors/unauthenticated_exception.dart#L6-L13)

- [x] **watch* uid null → 빈 List 1회 emit Stream**
  - 근거: `watchFavoriteStores` / `watchFavoriteMenuItems` 모두 uid null 시 `Stream.value(const <FavoriteStoreEntity>[])` (빈 List).
  - 위치: [favorites_repository_impl.dart:25-50](/Users/Byeonguk/Developer/OrderApp/lib/data/repositories/favorites_repository_impl.dart#L25-L50)

- [x] **is*Favorited uid null → `Stream.value(false)`**
  - 근거: `isStoreFavorited` / `isMenuItemFavorited` 모두 uid null 시 `Stream<bool>.value(false)`.
  - 위치: [favorites_repository_impl.dart:53-67](/Users/Byeonguk/Developer/OrderApp/lib/data/repositories/favorites_repository_impl.dart#L53-L67)

### 4. Provider 동작

- [x] **`favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider` 가 `authProvider` 변경에 반응**
  - 근거: 두 Provider 모두 `final user = ref.watch(authProvider).asData?.value;` 로 user 를 watch — authProvider 가 emit 새 상태 시 Provider rebuild. 비로그인 (`user == null`) → `Stream.value(const <String>{})` emit. 로그인 → `watchFavoriteStoresUseCase().call().map(...).toSet()` Stream.
  - 위치: [favorites_providers.dart:60-84](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/favorites/providers/favorites_providers.dart#L60-L84)

- [x] **key composer = `'${storeId}_${menuItemId}'`**
  - 근거: `favoriteMenuItemKeysProvider` 의 map 함수 `(e) => '${e.storeId}_${e.menuItemId}'`. 동일 형식의 헬퍼 `favoriteMenuItemKey(...)` 도 노출 (호출부에서 멤버십 체크 시 동일 키로 비교).
  - 위치: [favorites_providers.dart:80-91](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/favorites/providers/favorites_providers.dart#L80-L91), [menu_item_detail_page.dart:251-252](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L251-L252)

### 5. 공통 위젯 `FavoriteToggleIconButton`

- [x] **시각만 (로직/Firestore 호출 0건)**
  - 근거: `StatelessWidget` 에서 `IconButton` 만 build. `ref` / `Firestore` / `auth` / 호출부 로직 0건. onTap 은 외부에서 prop 으로 받음.
  - 위치: [favorite_toggle_icon_button.dart:10-42](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_toggle_icon_button.dart#L10-L42)

- [x] **props 시그니처 일치**
  - 근거: `bool isActive`, `VoidCallback onTap`, `Color inactiveColor` (default `AppColors.textHeading`), `double iconSize` (default 24). spec 의 `decoration` / `tooltip` 추가는 위젯 활용성 위함이며 과적합 아님.
  - 위치: [favorite_toggle_icon_button.dart:11-26](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_toggle_icon_button.dart#L11-L26)

- [x] **active = `Icons.favorite` + `AppColors.error`**
  - 근거: `Icon(isActive ? Icons.favorite : Icons.favorite_border_rounded, color: isActive ? AppColors.error : inactiveColor, ...)`.
  - 위치: [favorite_toggle_icon_button.dart:35-39](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_toggle_icon_button.dart#L35-L39)

- [x] **inactive = `Icons.favorite_border_rounded` + inactiveColor**
  - 근거: 동일 라인. 분기 일치.
  - 위치: [favorite_toggle_icon_button.dart:35-39](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_toggle_icon_button.dart#L35-L39)

### 6. 비로그인 다이얼로그 (사용자 확정 2)

- [x] **제목 "로그인이 필요해요" 정확 일치**
  - 근거: `Text('로그인이 필요해요')`.
  - 위치: [favorite_login_required_dialog.dart:18-25](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_login_required_dialog.dart#L18-L25)

- [x] **본문 "즐겨찾기를 저장하려면 Qrator 로그인이 필요해요." 정확 일치**
  - 근거: `Text('즐겨찾기를 저장하려면 Qrator 로그인이 필요해요.')`.
  - 위치: [favorite_login_required_dialog.dart:26-33](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_login_required_dialog.dart#L26-L33)

- [x] **버튼 "취소" / "로그인하기" 정확 일치**
  - 근거: `TextButton` 2개의 child Text 가 각각 '취소' / '로그인하기'.
  - 위치: [favorite_login_required_dialog.dart:35-56](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_login_required_dialog.dart#L35-L56)

- [x] **"로그인하기" → `Navigator.push(MaterialPageRoute(builder: (_) => const LoginPage()))`**
  - 근거: 다이얼로그가 true 반환 시 호출부 (`store_menu_page.dart` / `menu_item_detail_page.dart`) 가 `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()))`. 다이얼로그 자체는 결과 bool 만 반환.
  - 위치: [store_menu_page.dart:188-192](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/store/store_menu_page.dart#L188-L192), [menu_item_detail_page.dart:377-381](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L377-L381)

- [x] **다이얼로그 톤 = Phase 1b `_confirmReplaceCart` 와 일치**
  - 근거: `cart_page.dart` 65-117 의 `_confirmClear` (동일 톤) 와 비교 — 배경 `AppColors.surfaceElevated`, 16px radius, title fontWeight.w700 + 16, content fontWeight.w500 + 13, 취소 textMuted, 액션 컬러는 본 phase 만 `AppColors.primary` (긍정 동작 — implementation 결정 6 명시). 폰트/사이즈/radius/배경 모두 정확 일치.
  - 위치: [favorite_login_required_dialog.dart:13-58](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_login_required_dialog.dart#L13-L58) vs [cart_page.dart:65-117](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/cart/cart_page.dart#L65-L117)

### 7. Placeholder 잔존 0건

- [x] **`_showFavoritePlaceholder` grep → 0건**
  - 근거: `lib/` 전체 grep `_showFavoritePlaceholder` → No files found.

- [x] **`'즐겨찾기는 준비 중입니다 (Phase 1c)'` grep → 0건**
  - 근거: `lib/` 전체 grep `즐겨찾기는 준비 중` → No files found.

- [x] **`'Phase 1c 에서 즐겨찾기'` grep → 0건**
  - 근거: `lib/` 전체 grep `Phase 1c 에서 즐겨찾기` → No files found.

### 8. 에러 처리

- [x] **비로그인 토글 → 다이얼로그 노출, Firestore 호출 X (presentation 가드 1차 방어)**
  - 근거: `_onToggleStoreFavorite` / `_onToggleMenuItemFavorite` 두 헬퍼가 `final user = ref.read(authProvider).asData?.value;` 후 `if (user == null) → showFavoriteLoginRequiredDialog → return;`. UseCase 호출 자체가 차단됨.
  - 위치: [store_menu_page.dart:184-194](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/store/store_menu_page.dart#L184-L194), [menu_item_detail_page.dart:373-383](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L373-L383)

- [x] **RepositoryImpl uid 미전달 race → `UnauthenticatedException`**
  - 근거: 가드 통과 후 호출되었지만 그 사이 로그아웃된 race 케이스 — RepositoryImpl 의 `if (uid == null) throw const UnauthenticatedException();` 가 안전망. 호출부에서 `on UnauthenticatedException` 캐치해 다이얼로그 재노출.
  - 위치: [favorites_repository_impl.dart:73-74](/Users/Byeonguk/Developer/OrderApp/lib/data/repositories/favorites_repository_impl.dart#L73-L74), [store_menu_page.dart:198-206](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/store/store_menu_page.dart#L198-L206), [menu_item_detail_page.dart:390-398](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L390-L398)

- [x] **Firestore 쓰기 실패 → SnackBar `'즐겨찾기 저장에 실패했어요'` (정확 일치)**
  - 근거: 두 호출부 모두 generic `catch (_)` → `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('즐겨찾기 저장에 실패했어요'), duration: Duration(seconds: 2)))`. grep 으로 두 위치 모두 확인.
  - 위치: [store_menu_page.dart:207-215](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/store/store_menu_page.dart#L207-L215), [menu_item_detail_page.dart:399-407](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L399-L407)

- [x] **Firestore stream 에러 → 빈 Set fallback**
  - 근거: 호출부에서 `ref.watch(favoriteStoreIdsProvider).asData?.value ?? const <String>{}` (또는 동일 패턴 메뉴키). AsyncError 발생 시 `asData` 가 null 이라 빈 Set fallback. 앱 크래시 0.
  - 위치: [store_menu_page.dart:135-137](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/store/store_menu_page.dart#L135-L137), [menu_item_detail_page.dart:246-250](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L246-L250)

### 9. 색상 토큰

- [x] **active = `AppColors.error`**
  - 근거: `FavoriteToggleIconButton` 의 `color: isActive ? AppColors.error : inactiveColor`. `_CircleIconButton` 안의 ♥ 도 `isFavorite ? AppColors.error : AppColors.textHeading`.
  - 위치: [favorite_toggle_icon_button.dart:37](/Users/Byeonguk/Developer/OrderApp/lib/presentation/common/favorite_toggle_icon_button.dart#L37), [menu_item_detail_page.dart:329-330](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/order/menu/menu_item_detail_page.dart#L329-L330)

- [x] **하드코딩 `Color(0x...)` 0건 (본 phase 추가 파일 한정)**
  - 근거: 본 phase 신규 파일 5종 (`favorite_toggle_icon_button.dart`, `favorite_login_required_dialog.dart`, `favorites_providers.dart`, `favorites_remote_data_source.dart`, `favorites_repository_impl.dart`, `favorite_store_model.dart`, `favorite_menu_item_model.dart`, UseCase 4종) 에 `Color(0x` grep → No matches found.

- [x] **다른 화면 색상에 영향 0건**
  - 근거: 본 phase 가 수정한 파일은 `store_menu_header.dart` (헤더 ♥ 위치만 교체), `store_menu_page.dart` (`_AppBar` 의 isFavorite watch + 헬퍼 추가), `menu_item_detail_page.dart` (`_ImageHeader` ♥ 분기 + 헬퍼 추가) 뿐. 나머지 영역의 색상 변경 없음.

### 10. 사용자 확정사항 부합

- [x] **확정 1 — 즐겨찾기 리스트 화면 신규 0건**
  - 근거: `lib/presentation/customer/order/favorites/` 하위에 `providers/favorites_providers.dart` 만 존재. `MyFavoritesPage` 류 화면 / 마이페이지 진입점 추가 0건.

- [x] **확정 3 — 별도 in-memory 낙관적 캐시 / state 0건**
  - 근거: `favoriteStoreIdsProvider` / `favoriteMenuItemKeysProvider` 모두 `StreamProvider<Set<String>>` 만 노출. 별도 `StateProvider` / `Notifier` 로 in-memory 낙관적 갱신을 두지 않음. 토글 onTap → `await UseCase.call` → Firestore stream emit → Provider rebuild 의 단일 흐름.

- [x] **확정 4 — `docs/tasks/order_flow_phase1c/design.md` 부재**
  - 근거: `ls docs/tasks/order_flow_phase1c/` → `implementation.md`, `spec.md` 만 존재. design.md 부재.

### 11. Phase 1a/1b 정합성

- [x] **Phase 1a 의 `FavoriteStoreEntity` / `FavoriteMenuItemEntity` 변경 0건**
  - 근거: 두 entity 모두 `@freezed` + `(storeId, [menuItemId,] addedAt)` Phase 1a 시그니처 그대로. 본 phase 에서 import 만 함 (Repository 인터페이스 / Model toEntity 변환).
  - 위치: [favorite_store_entity.dart:1-15](/Users/Byeonguk/Developer/OrderApp/lib/domain/entities/favorite_store_entity.dart#L1-L15), [favorite_menu_item_entity.dart:1-16](/Users/Byeonguk/Developer/OrderApp/lib/domain/entities/favorite_menu_item_entity.dart#L1-L16)

- [x] **Phase 1a 의 `FavoritesRepository` interface 변경 0건**
  - 근거: 6 메서드 시그니처 (`watchFavoriteStores` / `watchFavoriteMenuItems` / `toggleFavoriteStore` / `toggleFavoriteMenuItem` / `isStoreFavorited` / `isMenuItemFavorited`) 모두 Phase 1a + spec 결정 A 시그니처 그대로. RepositoryImpl 이 그대로 implement.
  - 위치: [favorites_repository.dart:7-31](/Users/Byeonguk/Developer/OrderApp/lib/domain/repositories/favorites_repository.dart#L7-L31)

- [x] **Phase 1b 의 `cart_providers.dart` 변경 0건**
  - 근거: 본 phase 신규 파일들이 cart_providers.dart 를 import 하지 않음. cart_providers.dart 자체에 favorites 관련 import 없음 — Cart 도메인만 다룸.
  - 위치: [cart_providers.dart:1-62](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/cart/providers/cart_providers.dart#L1-L62)

- [x] **Phase 1b 의 `cart_page.dart` 변경 0건**
  - 근거: cart_page.dart 가 favorites 관련 import / 로직을 추가로 갖지 않음. `_confirmClear` 다이얼로그가 본 phase 다이얼로그와 톤이 같지만 별개 파일에서 자체 보존.
  - 위치: [cart_page.dart](/Users/Byeonguk/Developer/OrderApp/lib/presentation/customer/cart/cart_page.dart)

### 12. flutter analyze

- [x] **`flutter analyze` — 0 issue**
  - 근거: `Analyzing OrderApp... No issues found! (ran in 4.6s)` (lib 전체).

---

## FAIL 항목

> 없음.

---

## 보류 항목

- [ ] **B1 — 사용자 검증 필요한 e2e 시나리오 (수동)**
  - 이유: 정적 검증 + grep + 코드 read 만 수행. Firestore 콘솔 확인 / 카카오·네이버 prefix uid 케이스 / 다른 디바이스 stream 동기화 / 오프라인 SnackBar 등은 실기기 / Firestore 데이터 확인 필요. implementation.md 의 "사용자 검증 필요" 4건과 동일.
  - 필요한 확인:
    - Firestore 콘솔에서 `users/{uid}/favoriteStores/{storeId}` 와 `users/{uid}/favoriteMenuItems/{compositeId}` doc 토글 시 생성/삭제 (특히 카카오/네이버 prefix uid 케이스)
    - 비로그인 다이얼로그 → "로그인하기" → LoginPage → 로그인 → 매장 재진입 → ♥ 정상
    - 다른 디바이스 동일 uid 즐겨찾기 추가 → 본 디바이스 stream 갱신
    - 오프라인 토글 → SnackBar 노출 + 시각 변경 없음
  - 후속 작업 제안: QA 단계 또는 사용자 확인 시 별도 체크리스트로 정리

- [ ] **B2 — Firestore 보안 규칙 미작성 (별도 task)**
  - 이유: spec 명시대로 별도 task. 본 phase 의 컬렉션 경로 (`users/{uid}/favoriteStores/{storeId}`, `users/{uid}/favoriteMenuItems/{compositeId}`) 가 향후 보안 규칙 task 의 입력. 카카오/네이버 prefix uid 와 `request.auth.uid` 정합성 (Firebase Auth 와 별개 키) 도 보안 규칙 task 가 어댑터 레이어 설계 검토 필요.
  - 필요한 확인: 보안 규칙 task 에서 본인 uid 만 read/write 허용 + 카카오/네이버 인증 어댑터 검토
  - 후속 작업 제안: `firestore_security_rules` task 신규 생성

---

## 설계자 전달 메시지

### 요약

- **전체 판단**: spec 결정 A (Repository 시그니처 6 메서드 그대로) / 결정 B 보강 (callback 패턴 — 카카오/네이버 prefix uid 호환) / 결정 C (두 컬렉션 분리 + composite key + addedAt + serverTimestamp) / 결정 D (stream-driven, 별도 in-memory 캐시 0) / 결정 E (다이얼로그 텍스트 + LoginPage push) / 결정 F (active = AppColors.error) 모두 코드에 정확히 반영. Phase 1a 인터페이스 / Phase 1b 카트 영역 변경 0건. 레이어 규칙 (presentation/domain 에 cloud_firestore 0건) 준수. placeholder 스낵바 / 메서드 / "Phase 1c" 문구 모두 잔존 0건. `flutter analyze` clean. **본 phase 종결 가능**.

### 재작업 우선순위

> 없음.

### 후속 task 후보

- **즐겨찾기 리스트 화면 + Phase 2 자동 추천 통합**: 사용자 확정 1 — Phase 1c 비포함. Phase 2 의 "내 주문 라이프 (자동 추천 + 즐겨찾기)" 와 함께 통합 정리.
- **Firestore 보안 규칙 작성 task**: B2. `users/{uid}/favoriteStores/*` / `users/{uid}/favoriteMenuItems/*` 본인 uid 만 read/write. 카카오/네이버 prefix uid 어댑터 설계 포함.
- **Race-safe transaction 토글**: 동시 더블탭 race 의 transaction 화 (현재 set/delete idempotency 로 최종 수렴). 사용자 체감 우선순위 낮음.
- **매장/메뉴 삭제 시 즐겨찾기 cleanup**: Firestore Cloud Function / cron — Phase 2 일감.
- **Optimistic UI 캐시 (Phase 2 검토)**: 사용자 확정 3 — stream-driven 채택. 체감 지연 거슬릴 시 inmemory 낙관적 캐시 추가 검토.
- **Post-login deeplink**: 로그인 후 원래 화면 자동 복귀. 라우터 미도입 (Phase 1 시리즈는 Navigator.push) 상태에서 복잡도 큼. Phase 2 라우터 도입 시 함께 정리.
- **접근성 통합 개선** (Phase 1b 의 H1 후속): `FavoriteToggleIconButton` 에 Semantics label ('즐겨찾기' / '즐겨찾기 해제') 명시 검토 — 본 phase 는 IconButton tooltip prop 만 노출, 호출부에서 미사용. Phase 1 전체 IconButton Semantics 통합 정리 task 와 합치기.

---

## 완료 판단

- [x] 전체 PASS
- [ ] FAIL 있으나 후속 task 로 분리 가능
- [ ] 재작업 필요
