# 홈 화면 구현 보고서

## 개요
`docs/tasks/home/spec.md` + `docs/tasks/home/design.md`를 바탕으로 홈 화면·하단 글로벌 네비게이션·등급 시스템 초안을 구현. 사용자 부재 중 자율 진행.

## 빌드 상태
- `flutter analyze` → **No issues found**
- `flutter test` → **4/4 passed**
- `dart run build_runner build --delete-conflicting-outputs` → 성공 (freezed 3종 + json_serializable 1종 출력)

## 추가된 파일

### core
- [lib/core/constants/menu_categories.dart](lib/core/constants/menu_categories.dart) — 12개 카테고리 상수
- [lib/core/constants/grade_thresholds.dart](lib/core/constants/grade_thresholds.dart) — 등급 임계값 + 기본 위치(서울 시청) + 주변 반경
- [lib/core/utils/distance_calculator.dart](lib/core/utils/distance_calculator.dart) — Haversine + km 포맷터
- [lib/core/utils/grade_calculator.dart](lib/core/utils/grade_calculator.dart) — 평균 점수 → `StoreGrade` 변환

### domain
- [lib/domain/entities/store_grade.dart](lib/domain/entities/store_grade.dart) — S/A/B/C 열거형 + 색상 확장
- [lib/domain/entities/user_location.dart](lib/domain/entities/user_location.dart) — freezed (isFallback 포함)
- [lib/domain/entities/store_entity.dart](lib/domain/entities/store_entity.dart) — freezed
- [lib/domain/entities/review_entity.dart](lib/domain/entities/review_entity.dart) — freezed (향후 읽기용)
- [lib/domain/repositories/store_repository.dart](lib/domain/repositories/store_repository.dart)
- [lib/domain/repositories/location_repository.dart](lib/domain/repositories/location_repository.dart)
- [lib/domain/usecases/get_current_location_use_case.dart](lib/domain/usecases/get_current_location_use_case.dart)
- [lib/domain/usecases/get_nearby_stores_use_case.dart](lib/domain/usecases/get_nearby_stores_use_case.dart)
- [lib/domain/usecases/get_stores_by_categories_use_case.dart](lib/domain/usecases/get_stores_by_categories_use_case.dart)
- [lib/domain/usecases/calculate_distance_use_case.dart](lib/domain/usecases/calculate_distance_use_case.dart)

### data
- [lib/data/models/store_model.dart](lib/data/models/store_model.dart) — Firestore DTO (수동 매퍼, GeoPoint/Timestamp 대응)
- [lib/data/models/review_model.dart](lib/data/models/review_model.dart)
- [lib/data/datasources/remote/store_remote_data_source.dart](lib/data/datasources/remote/store_remote_data_source.dart)
- [lib/data/datasources/remote/location_data_source.dart](lib/data/datasources/remote/location_data_source.dart)
- [lib/data/repositories/store_repository_impl.dart](lib/data/repositories/store_repository_impl.dart)
- [lib/data/repositories/location_repository_impl.dart](lib/data/repositories/location_repository_impl.dart)

### presentation · 홈
- [lib/presentation/customer/home/home_page.dart](lib/presentation/customer/home/home_page.dart) — 전면 재작성
- [lib/presentation/customer/home/providers/home_providers.dart](lib/presentation/customer/home/providers/home_providers.dart) — DI + 상태 Provider
- [lib/presentation/customer/home/widgets/home_header.dart](lib/presentation/customer/home/widgets/home_header.dart)
- [lib/presentation/customer/home/widgets/nearby_stores_section.dart](lib/presentation/customer/home/widgets/nearby_stores_section.dart)
- [lib/presentation/customer/home/widgets/category_filter_section.dart](lib/presentation/customer/home/widgets/category_filter_section.dart)
- [lib/presentation/customer/home/widgets/recommended_stores_section.dart](lib/presentation/customer/home/widgets/recommended_stores_section.dart)
- [lib/presentation/customer/home/widgets/store_card.dart](lib/presentation/customer/home/widgets/store_card.dart) — NearbyStoreCard + RecommendedStoreCard
- [lib/presentation/customer/home/widgets/grade_badge.dart](lib/presentation/customer/home/widgets/grade_badge.dart)
- [lib/presentation/customer/home/widgets/section_title.dart](lib/presentation/customer/home/widgets/section_title.dart)

### presentation · 공통/플레이스홀더
- [lib/presentation/common/bottom_nav/bottom_nav.dart](lib/presentation/common/bottom_nav/bottom_nav.dart)
- [lib/presentation/common/bottom_nav/order_fab.dart](lib/presentation/common/bottom_nav/order_fab.dart)
- [lib/presentation/common/scaffold_with_nav.dart](lib/presentation/common/scaffold_with_nav.dart)
- [lib/presentation/customer/qoin/qoin_page.dart](lib/presentation/customer/qoin/qoin_page.dart)
- [lib/presentation/customer/order/order_page.dart](lib/presentation/customer/order/order_page.dart)
- [lib/presentation/customer/log/log_page.dart](lib/presentation/customer/log/log_page.dart)
- [lib/presentation/customer/more/more_page.dart](lib/presentation/customer/more/more_page.dart)

### 수정된 기존 파일
- [lib/main.dart](lib/main.dart) — 스플래시 → `ScaffoldWithNav` 로 이동
- [lib/presentation/customer/auth/login_page.dart](lib/presentation/customer/auth/login_page.dart) — 로그인 후 `ScaffoldWithNav`
- [lib/presentation/customer/auth/email_login_page.dart](lib/presentation/customer/auth/email_login_page.dart)
- [lib/presentation/customer/auth/email_signup_page.dart](lib/presentation/customer/auth/email_signup_page.dart)
- [pubspec.yaml](pubspec.yaml) — `cloud_firestore`, `geolocator`, `cached_network_image`, `shimmer` 추가
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) — 인터넷·위치 권한
- [ios/Runner/Info.plist](ios/Runner/Info.plist) — 위치 권한 사용 설명
- [test/widget_test.dart](test/widget_test.dart) — 구형 템플릿 제거, Grade/Distance 단위 테스트로 교체

## 구현 결정 및 의도

### Repository 패턴
- 도메인/프레젠테이션 레이어는 Firestore SDK를 전혀 import하지 않음. 모든 Firestore 접근은 `StoreRemoteDataSource`에 국한.
- `cloud_firestore`의 `GeoPoint`/`Timestamp`는 `StoreModel` 내부에서 primitive(위도/경도/DateTime)로 변환하여 엔티티로 통과.
- `LocationRepositoryImpl`은 `LocationDataSource`를 경유해 `geolocator`를 사용. 기본 위치 폴백은 Repository 레이어에서 결정 (데이터소스는 실패 시 `null` 반환).

### 등급 시스템
- `StoreGrade` 열거형: `s/a/b/c`, 소문자 식별자 + `label('S급')`/`asString('S')`/`score(4)` 확장.
- `GradeCalculator.fromAverage`는 `GradeThresholds`만 의존하므로 상수값 교체만으로 등급 기준 재조정 가능(추후 Remote Config 연동 대비).
- UI의 `GradeBadge`는 `grade.color` 확장 사용 → S=Gold, A=Electric Blue, B=Sky, C=Slate.

### Provider 구조
- `home_providers.dart` 하나에 DI + 상태 Provider를 모았다. 의존 순서:
  - `_firestoreProvider` → `_storeRemoteDataSourceProvider` → `storeRepositoryProvider` → 각 UseCase Provider
  - `_locationDataSourceProvider` → `locationRepositoryProvider` → `getCurrentLocationUseCaseProvider`
- 상태: `userLocationProvider`(Future) → `nearbyStoresProvider` & `filteredStoresProvider` (location 의존).
- 카테고리 선택은 `NotifierProvider<SelectedCategoriesNotifier, Set<String>>` — 최소 1개 유지 로직을 notifier 내부에 캡슐화.
- `selectedTabIndexProvider`는 `NotifierProvider<int>` (StateProvider는 사용하지 않음).

### 라우팅
- 스플래시에서 auth 결과에 따라 `LoginPage` 또는 `ScaffoldWithNav`로 이동.
- `ScaffoldWithNav`는 `IndexedStack`으로 홈/Qoin/Log/더보기 4화면의 상태를 유지. 주문 FAB은 별도 `MaterialPageRoute(fullscreenDialog: true)`로 모달 전환 (탭 인덱스에 저장하지 않음).

### 이미지/로딩
- `cached_network_image` + `shimmer` 조합. 섹션별 로딩(주변매장 3개, 추천 3개), 에러(아이콘+문구), 빈 상태(카테고리/주변) 처리.
- Pull-to-Refresh로 `userLocation`, `nearbyStores`, `filteredStores`를 모두 invalidate.

### 플랫폼 권한
- Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET` 추가.
- iOS: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` 추가.
- 권한 거부 시 서울 시청 좌표로 폴백하고 SnackBar 안내 (한 번만).

## 알려진 한계 / TODO
- Firestore `stores` 컬렉션의 시드 데이터는 아직 없음. 실제 매장 데이터 없이 실행하면 모든 섹션이 빈 상태로 표시됨. 개발자/점주가 Firestore Console에서 샘플 문서를 직접 생성해야 동작 확인 가능.
- 지리공간 쿼리가 Firestore 기본 기능에 없어 `fetchAll(limit: 100)` + 클라이언트 필터 방식. 매장 수가 수백을 넘으면 Geohash 도입 필요.
- 매장 상세/주문/리뷰 작성 화면은 이번 범위 외. 카드/FAB 탭은 SnackBar로 임시 안내.
- 카테고리 매칭은 `menuCategories` 배열 교집합 OR. AND(모두 포함) 필터는 향후 요구에 따라 추가.

## 자율 결정 요약 (사용자 확인 요망)
`docs/tasks/home/design.md`에 상세 기록. 핵심:
1. 중앙 FAB 색상을 Electric Blue 그라디언트로 변경 (Figma의 Midnight Navy는 다크 배경에서 충돌).
2. S=Gold, A=Electric Blue, B=Sky, C=Slate 색상 체계 도입.
3. 매장 카드에서 별점 제거, `GradeBadge(등급 + 리뷰수)` 단일 표기로 통합.
4. 카테고리 필터 최소 1개 유지 (UX).
5. 커피 김 애니메이션 생략(MVP), 기본 `Icons.coffee_rounded` 사용.
6. 주변 반경 5 km, 기본 위치 서울 시청(37.5665, 126.9780).

---

## 2026-04-19 추가 수정 (사용자 피드백 반영)

### 1. OrderFab 단순화
- `pulse` 애니메이션 및 `HapticFeedback.lightImpact` 호출 제거 (시뮬레이터 체감 어려움 + 햅틱 불필요).
- 탭 시 `AnimatedScale(0.94)` press 피드백만 유지.
- `SingleTickerProviderStateMixin` · `AnimationController` 제거로 코드 단순화.
- 변경 파일: [lib/presentation/common/bottom_nav/order_fab.dart](lib/presentation/common/bottom_nav/order_fab.dart)

### 2. `#2563EB` → `AppColors.primaryDeep` 승격
- `AppColors`에 `primaryDeep = Color(0xFF2563EB)` 추가. 동시에 기존 `#38BDF8` 하드코딩도 `AppColors.primaryBright`로 치환 완료.
- 변경 파일:
  - [lib/core/theme/app_colors.dart](lib/core/theme/app_colors.dart)
  - [lib/presentation/common/q_logo.dart](lib/presentation/common/q_logo.dart)
  - [lib/presentation/customer/home/widgets/home_header.dart](lib/presentation/customer/home/widgets/home_header.dart)

### 3. 위치 권한 Pre-permission 다이얼로그 도입
Pattern (나) 채택 — OS 네이티브 권한 팝업 **전에** 커스텀 안내 대화상자로 허용/거절을 한번 확인.

신규 파일:
- [lib/domain/entities/location_permission_status.dart](lib/domain/entities/location_permission_status.dart) — `notYetAsked / granted / deniedForever / serviceDisabled` 도메인 enum
- [lib/domain/usecases/check_location_permission_use_case.dart](lib/domain/usecases/check_location_permission_use_case.dart)
- [lib/presentation/customer/home/widgets/pre_permission_dialog.dart](lib/presentation/customer/home/widgets/pre_permission_dialog.dart) — 다크 테마 커스텀 다이얼로그 (`PrePermissionDialog.show(context)`)

수정 파일:
- [lib/domain/repositories/location_repository.dart](lib/domain/repositories/location_repository.dart) — `getPermissionStatus()` 추가
- [lib/data/datasources/remote/location_data_source.dart](lib/data/datasources/remote/location_data_source.dart) — `isServiceEnabled()`, `getPermission()` 메서드 분리 노출
- [lib/data/repositories/location_repository_impl.dart](lib/data/repositories/location_repository_impl.dart) — `geolocator` enum → 도메인 enum 매핑
- [lib/presentation/customer/home/providers/home_providers.dart](lib/presentation/customer/home/providers/home_providers.dart) — `userLocationProvider`를 `AsyncNotifierProvider`로 전환. 초기 상태는 `Completer` 기반 미해결 Future → `allowAndFetch()` 또는 `declineAndFallback()` 호출 시에만 resolve
- [lib/presentation/customer/home/home_page.dart](lib/presentation/customer/home/home_page.dart) — `initState`에서 권한 상태 조회 후 3분기 처리. pull-to-refresh도 권한 재확인 경로로 통일

동작:
- `granted` → 즉시 `allowAndFetch()` (이미 허용된 상태이므로 OS 다이얼로그 없음)
- `notYetAsked` → `PrePermissionDialog` → [허용하기] 시 `allowAndFetch()` 내부에서 `geolocator`가 OS 권한 팝업 트리거. [나중에]/바깥 탭 시 즉시 폴백
- `deniedForever` / `serviceDisabled` → 대화상자 없이 폴백 + SnackBar 안내

### 재검증
- `flutter analyze` → **No issues found**
- `flutter test` → **4/4 PASS** (기존 Grade/Distance 단위 테스트 그대로)
