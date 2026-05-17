# 홈 화면 기능 명세

## 개요
- **목적**: 로그인한 Qrator가 진입하는 메인 화면. 주변 매장 탐색 + 품질 등급 기반 추천 + 카테고리 필터 + 하단 글로벌 네비게이션 제공
- **영향 범위**:
  - 신규 화면: HomePage
  - 신규 도메인: Store, Grade, Review
  - 신규 공통 위젯: BottomNav (전역 네비게이션)
  - 신규 외부 서비스: 위치 정보(geolocator), Firestore 매장 컬렉션
- **디자인 진행 방식**: 피그마 디자인은 레이아웃 참조용. 상세 디자인은 디자이너 에이전트가 사용자와 협의하며 진행

---

## 요구사항

### 홈 화면
- [ ] 헤더: QLogo + 브랜드 텍스트 + "[사용자명]님 어서오세요" 메시지 (Midnight Navy 배경)
- [ ] 주변매장 섹션: 가로 스크롤 카드 리스트 (등급 배지, 이름, 평점, 거리)
- [ ] 카테고리 섹션: 12개 메뉴 카테고리 칩, 다중 선택 가능
- [ ] 맞춤 추천 섹션: 선택된 카테고리 기반 매장 리스트 (세로)
- [ ] 모든 섹션에 로딩/에러/빈 상태 UI 포함

### 하단 네비게이션 (전역)
- [ ] 5개 탭: 홈 / Qoin / 주문(중앙 FAB) / Log / 더보기
- [ ] 중앙 "주문" 탭: 원형 FAB, 커피컵 아이콘, 글로우 애니메이션
- [ ] Qradar 용어 적용: "주문내역" → "Log"
- [ ] 현재는 홈만 구현, 나머지 탭은 placeholder 화면

### 등급 시스템 (핵심)
- [ ] Qrator가 매장을 S/A/B/C 4단계로 평가
- [ ] 매장의 최종 등급 = 평가의 평균값 기반 계산
  - S=4, A=3, B=2, C=1 내부 점수
  - 평균 3.5 이상 → S, 2.5 이상 → A, 1.5 이상 → B, 1.0 이상 → C
- [ ] 등급 배지 표시 형식: `S급 (124)` — 등급 + 평가 개수
- [ ] 평가 개수 상관없이 등급 표시 (Qrator가 개수 보고 판단)
- [ ] 임계값은 `core/constants/grade_thresholds.dart`에서 관리

### 위치 정보
- [ ] `geolocator` 패키지 사용
- [ ] 앱 최초 실행 시 위치 권한 요청
- [ ] 권한 거부 시 기본 위치(서울 시청) 사용
- [ ] 매장과 Qrator 현재 위치 간 거리 계산 (km 단위, 소수점 1자리)

---

## 데이터 모델

### Entity

**Store**
- `id`: String
- `name`: String
- `imageUrl`: String
- `location`: GeoPoint (위도/경도)
- `grade`: StoreGrade (S / A / B / C)
- `averageScore`: double (내부 계산된 평균 점수)
- `reviewCount`: int
- `menuCategories`: List<String> (12개 중 해당하는 것들)
- `createdAt`: DateTime

**StoreGrade (enum)**
- `S`, `A`, `B`, `C`

**Review** (향후 확장용, 이번 작업은 읽기만)
- `id`: String
- `storeId`: String
- `userId`: String
- `grade`: StoreGrade
- `comment`: String?
- `createdAt`: DateTime

**UserLocation**
- `latitude`: double
- `longitude`: double

### DTO (Firestore)

**stores 컬렉션**
```
stores/{storeId}
  - name: string
  - imageUrl: string
  - location: GeoPoint
  - averageScore: number  (클라우드 함수로 자동 갱신, 초기엔 수동)
  - reviewCount: number
  - menuCategories: array<string>
  - createdAt: timestamp
```

**reviews 컬렉션**
```
reviews/{reviewId}
  - storeId: string
  - userId: string
  - grade: string ("S" | "A" | "B" | "C")
  - comment: string
  - createdAt: timestamp
```

---

## 레이어 설계

### Domain
**Entities**
- `lib/domain/entities/store_entity.dart`
- `lib/domain/entities/store_grade.dart` (enum + 확장)
- `lib/domain/entities/review_entity.dart`
- `lib/domain/entities/user_location.dart`

**Repository 인터페이스**
- `lib/domain/repositories/store_repository.dart`
  - `getNearbyStores(UserLocation, int limit)` → List<Store>
  - `getStoresByCategories(List<String> categories)` → List<Store>
- `lib/domain/repositories/location_repository.dart`
  - `getCurrentLocation()` → UserLocation
  - `requestPermission()` → bool

**UseCases**
- `lib/domain/usecases/get_nearby_stores_use_case.dart`
- `lib/domain/usecases/get_stores_by_categories_use_case.dart`
- `lib/domain/usecases/get_current_location_use_case.dart`
- `lib/domain/usecases/calculate_distance_use_case.dart` (두 GeoPoint 간 거리)

### Data
**Models (DTO)**
- `lib/data/models/store_model.dart` (freezed + json_serializable)
- `lib/data/models/review_model.dart`

**DataSources**
- `lib/data/datasources/remote/store_remote_data_source.dart` (Firestore)
- `lib/data/datasources/remote/location_data_source.dart` (geolocator)

**Repository 구현체**
- `lib/data/repositories/store_repository_impl.dart`
- `lib/data/repositories/location_repository_impl.dart`

### Presentation
**Providers (Riverpod)**
- `lib/presentation/customer/home/providers/home_providers.dart`
  - `userLocationProvider` (FutureProvider)
  - `nearbyStoresProvider` (FutureProvider)
  - `selectedCategoriesProvider` (StateProvider, 초기값: ["추천메뉴"])
  - `filteredStoresProvider` (FutureProvider, selectedCategories 의존)

**Pages / Widgets**
- `lib/presentation/customer/home/home_page.dart` (전면 재작성)
- `lib/presentation/customer/home/widgets/home_header.dart`
- `lib/presentation/customer/home/widgets/nearby_stores_section.dart`
- `lib/presentation/customer/home/widgets/category_filter_section.dart`
- `lib/presentation/customer/home/widgets/recommended_stores_section.dart`
- `lib/presentation/customer/home/widgets/store_card.dart` (공통)
- `lib/presentation/customer/home/widgets/grade_badge.dart` (공통)

**공통 네비게이션**
- `lib/presentation/common/bottom_nav/bottom_nav.dart`
- `lib/presentation/common/bottom_nav/order_fab.dart` (중앙 FAB)
- `lib/presentation/common/scaffold_with_nav.dart` (네비 포함 공통 Scaffold)

**Placeholder 화면**
- `lib/presentation/customer/qoin/qoin_page.dart`
- `lib/presentation/customer/order/order_page.dart`
- `lib/presentation/customer/log/log_page.dart` (주문내역 = Log)
- `lib/presentation/customer/more/more_page.dart`

### Core
- `lib/core/constants/grade_thresholds.dart` (등급 임계값 상수)
- `lib/core/constants/menu_categories.dart` (12개 카테고리 목록)
- `lib/core/utils/grade_calculator.dart` (평균 점수 → 등급 변환)
- `lib/core/utils/distance_calculator.dart` (Haversine 공식)

---

## 데이터 흐름

```
앱 실행
  ↓
userLocationProvider
  → LocationRepository.getCurrentLocation()
  → geolocator (권한 체크 → 현재 위치 반환 or 기본값)
  ↓
nearbyStoresProvider
  → GetNearbyStoresUseCase(location)
  → StoreRepository.getNearbyStores()
  → StoreRemoteDataSource (Firestore)
  → Store 리스트 반환 + 거리 계산
  ↓
HomePage 렌더링
  ↓ (사용자가 카테고리 토글)
selectedCategoriesProvider 업데이트
  ↓
filteredStoresProvider
  → GetStoresByCategoriesUseCase(categories)
  → StoreRepository.getStoresByCategories()
  → 필터링된 매장 리스트 반환
```

---

## 에러 처리

| 케이스 | 처리 |
|--------|------|
| 위치 권한 거부 | 기본 위치(서울 시청)로 폴백, 토스트 안내 |
| Firestore 연결 실패 | 에러 상태 UI + 재시도 버튼 |
| 빈 매장 리스트 | 빈 상태 UI ("주변에 매장이 없습니다") |
| 네트워크 오프라인 | 오프라인 안내 + 캐시 데이터 사용 (향후) |

---

## 필요한 패키지 추가
- `geolocator`: ^13.x (위치 정보)
- `cached_network_image`: ^3.x (매장 이미지 캐싱)
- `cloud_firestore`: ^6.x (기본 설치됨)

---

## 작업 분배

### designer (우선)
- 홈 화면 상세 디자인 (사용자와 협업하며 결정)
- 하단 네비게이션 다크 테마 전환
- 중앙 주문 FAB 디자인 확정 (배경, 글로우 컬러)
- 등급 배지 디자인
- 매장 카드 디자인
- 카테고리 칩 디자인
- 상태 UI (로딩/에러/빈 상태) 정의
- 산출물: `docs/tasks/home/design.md`

### developer (디자인 확정 후)
- 도메인 레이어: Entity, Repository 인터페이스, UseCase
- 데이터 레이어: Model, DataSource, Repository 구현체
- Presentation: Providers, Page, Widgets
- 공통 컴포넌트: BottomNav, ScaffoldWithNav
- 상수/유틸: grade_thresholds, menu_categories, grade_calculator, distance_calculator
- 기존 `home_page.dart` 전면 재작성
- `main.dart` 라우팅 조정 (로그인 후 ScaffoldWithNav로 이동)
- 산출물: 코드 + `docs/tasks/home/implementation.md`

### tester (구현 후)
- spec.md 기준 기능 검증
- design.md 기준 UI 검증
- 아키텍처/컨벤션 검증
- 산출물: `docs/tasks/home/test_report.md`

---

## Firestore 초기 데이터 (개발용)
테스트를 위해 `stores` 컬렉션에 5~10개의 매장 샘플 데이터를 수동 입력하거나 시드 스크립트로 생성. (상세는 developer가 결정)
