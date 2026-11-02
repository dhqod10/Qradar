# 매장 목록 페이지네이션 (store_list_pagination) 기능 명세

## 개요

- **목적**: "주변매장" 목록이 하드 상한으로 잘려 매장이 많아지면 그 이상을 볼 수 없는 문제를 없앤다. 초기 소량(20건) 조회 + 목록 끝 스크롤 시 추가 조회(무한 스크롤)로 전환해 **절단 제거 + 읽기 코스트 절감**을 동시에 달성한다. "주변매장"의 성격상 **위치 기반(가까운 순)** 정렬은 유지한다.
- **작업 유형**: 기존 기능 수정 (조회/상태관리 리팩터링) + 신규 구조 추가 (geo 쿼리 · 페이지 상태)
- **영향 범위**:
  - 화면: 홈 `주변매장` / `맞춤 추천`(전체보기) / 검색 `매장 검색` / 주문 탭 매장 목록·지도 — 단, **이번 작업 구현 대상은 §1 범위 결정(D0)에 따름**
  - Domain: `StoreRepository` 에 페이지네이션 메서드 추가, 신규 UseCase, 페이지 결과 값객체
  - Data: `StoreRemoteDataSource` geo 쿼리 추가, `StoreModel` geo 인덱스 필드, `StoreRepositoryImpl`
  - Presentation: 새 페이지네이션 Provider(AsyncNotifier), 전체보기/목록 화면의 스크롤 리스너 + footer 상태
  - 공통 컴포넌트: `presentation/common/store_list_states.dart` (footer 로딩/더보기/빈/에러 추가)
  - 권한 / 환경 설정: geo 라이브러리 선택 시 `pubspec.yaml` + Firestore 복합 인덱스 (§0 D1)
  - 데이터 구조: geo 방식 선택 시 `stores` 문서에 geo 인덱스 필드(geohash) 추가 + 1회 마이그레이션
- **비범위**: §2 참조

> ⚠️ 이 spec 은 **핵심 결정(§0)이 사용자 확인으로 확정되기 전에는 구현 착수 금지**다. 특히 D0(범위)·D1(위치 쿼리 방식)이 전체 설계의 분기점이다.

---

## 0. 사용자 확인이 필요한 결정 (확정 전 구현 금지)

### D0 — 이번 작업의 범위 (가장 먼저 결정)

현황 조사 결과(§3) **절단은 `주변매장` 한 곳이 아니라 전 매장 목록이 공유하는 구조적 문제**다. `fetchAll(limit: 100)` 이 `averageScore 내림차순 상위 100` 만 읽고, 홈 주변매장·맞춤추천·검색(매장/메뉴)·주문 탭·지도가 **모두 이 스냅샷에서 파생**된다. 즉 점수 101위 밖 매장은 **바로 옆에 있어도 어디에도 안 보인다** (거리순이 아니라 점수순으로 잘리는 것이 핵심).

| 옵션 | 범위 | 트레이드오프 | 권고 |
|---|---|---|---|
| **D0-a** | 홈 `주변매장`(전체보기) **1곳만** 페이지네이션. 나머지 목록은 현행 스냅샷(100 cap) 유지 | 회귀 위험 최소, 전달 빠름. 단 맞춤추천/검색/주문탭/지도의 100 cap 은 남음 → **후속 과제로 분리** | ★ **권고** (MVP, 점진 전환) |
| D0-b | 스냅샷 자체를 페이지네이션으로 교체 → 파생 목록 전부 영향 | 절단 완전 제거. 단 검색/메뉴검색/지도의 "전수 스냅샷 파생(읽기 0)" 전제가 무너져 재설계 범위 큼, 회귀 위험 높음 | 2차 |

- 권고: **D0-a**. 본 spec 의 상세 설계는 D0-a 기준으로 작성한다. D0-b 선택 시 §3 의 파생 목록 재설계를 별도 spec 으로 승격한다.
- D0-a 로 가도 **나머지 목록의 100 cap 은 별도 백로그 과제(`store_snapshot_truncation`)로 반드시 등록**한다 (알려진 한계로 방치 금지).

### D1 — 위치 기반 쿼리 방식 (핵심)

Firestore 는 2D 근접 쿼리를 직접 못 하고, **클라이언트가 계산하는 거리값으로는 `startAfter` 커서 페이지네이션이 불가능**하다 (커서는 Firestore `orderBy` 필드 위에서만 동작). 따라서 "가까운 순 + 진짜 페이지네이션 + geo 인덱스/CF 없음" 셋을 동시에 만족할 수 없다 — **셋 중 둘만 가능**. 이것이 이 기능의 본질적 결정이다.

| 옵션 | 방식 | 정확도 | 읽기 코스트 | 구현 복잡도 | 인덱스/의존성 |
|---|---|---|---|---|---|
| **D1-a** geohash | `geoflutterfire_plus` 로 중심+반경 근접 쿼리, 반경 링 확장으로 페이지 | 정확(가까운 순 안정) | 낮음 (반경 내만 읽음) | 중 | geo 라이브러리 + `stores.position.geohash` 필드 + 복합 인덱스(status+geohash) |
| D1-b CF | Cloud Function 이 거리계산 후 정렬·페이지(진짜 커서 20/page) 반환 | 정확 + 정확히 20/page | 읽기가 서버로 이동(과금 유지) + CF 호출비·콜드스타트·지연 | 상 | CF 신규 배포 + data_ownership 등재 |
| D1-c bounding-box | 위도 단일 범위 쿼리 + 경도·거리 클라 정렬 | 근사(원이 아닌 박스) | 중(위도 밴드 읽음) | 중 | `stores.lat` 숫자 필드 + 인덱스. 거리순 커서는 여전히 근사 |
| D1-d score-커서 | 기존 `averageScore` 커서로 20씩 읽고 클라에서 거리 재정렬 | **가까운 순 불안정** (페이지 로드마다 재정렬·위로 끼어듦) | 낮음 | 하 (의존성·마이그레이션 0) | 기존 인덱스로 충분 |

- **권고: D1-a (geohash + `geoflutterfire_plus`)**. 사용자 확정 요구 "가까운 순 유지" 를 **안정적으로** 만족하는 유일한 클라이언트 방식이고, 반경 내만 읽어 "읽기 코스트 절감" 요구에 직접 부합한다. Clean Architecture 상 SDK import 가 data 레이어에 격리되어 규칙 위반도 없다.
- D1-d 는 의존성·마이그레이션 0 으로 가장 싸지만 **"가까운 순" 이 깨진다**(스크롤로 페이지를 더 불러올 때마다 더 가까운 매장이 위로 끼어들어 순서가 요동). 사용자 확정 요구와 충돌하므로 **권고하지 않음** (초저비용 임시방편이 필요할 때만).
- D1-b 는 대규모·정확한 글로벌 커서가 필요할 때의 정답 — **Phase 2 로 연기** 권고.
- D1-c 는 의존성이 적어 보이나 거리순 커서가 근사라 D1-a 대비 이점이 작다. 권고 안 함.

### D2 — 페이지 크기 / 반경 전략 (D1-a 전제)

- **D2-1 페이지 크기 20 확정** (사용자 확정). `GradeThresholds.nearbyPageSize = 20` 로 상수화. 단 geohash 는 "반경 내 전부"를 한 번에 읽으므로 20은 **클라이언트 노출(reveal) 단위**이고, Firestore 읽기 단위는 "반경 링" 이다 (§5 참조).
- **D2-2 시작 반경 / 확장 스텝 / 최대 반경** — 권고: 시작 5km → ×2 확장(5→10→20→40) → 최대 50km 에서 중단(소진 처리). 현행 `nearbyRadiusKm=20` 과 다른 값이므로 확인 필요. 대안: 시작 반경을 현행 20km 유지(초기 읽기량↑, 확장 거의 불필요).
- 권고 확정 시 세 값 모두 `GradeThresholds` 에 상수로 둔다 (리터럴 금지, 기존 컨벤션).

### D3 — geo 라이브러리 / 인덱스 (D1-a 전제)

- **라이브러리**: `geoflutterfire_plus` (유지보수되는 포크) 권고. `geoflutterfire` 원본은 방치됨. 최종 패키지·버전은 developer 가 `docs/operations.md` 기준으로 pin, 본 spec 은 "data 레이어 전용 import" 만 못박는다.
- **geo 필드 스키마**: `stores.position = { geohash: string, geopoint: GeoPoint }` (라이브러리 관례). 기존 `location: GeoPoint` 는 **병행 유지**(호환성) — geo 전용 필드를 추가하는 것이지 기존 필드 제거가 아니다.
- **마이그레이션**: 기존 매장 문서에 `position.geohash` 를 채우는 **1회 백필**. CF 또는 admin 1회 스크립트. §7(감사) 참조 — `migrationHistory` 1건 남긴다.
- **쓰기 경로**: 매장 생성/수정(점주 submit, brand create) 시 `position` 을 함께 기록하도록 `StoreModel.toFirestoreForCreate/BrandCreate/CoreUpdate` 에 geohash 계산 추가. geohash 는 `location` 에서 파생되는 값이므로 **단일 출처(위경도)에서 계산** — 불일치 방지.
- **복합 인덱스**: geohash 범위 쿼리에 `status == approved` equality 를 결합하면 복합 인덱스(`status ASC, position.geohash ASC`)가 필요할 수 있다. developer 가 쿼리 확정 후 `firestore.indexes.json` 에 명시 + 배포. **spec 상 "인덱스 필요"를 명시**한다.

> §0 의 D0·D1 이 확정되기 전까지 designer/developer 를 호출하지 않는다.

---

## 1. 요구사항

### 기능 요구사항 (D0-a + D1-a 기준)

- [ ] 전체 매장 목록 진입 시 **가까운 순 상위 20건만** 초기 노출한다.
- [ ] 목록 맨 아래 스크롤에 닿으면 다음 20건을 추가 로드한다 (무한 스크롤).
- [ ] 더 이상 없을 때(최대 반경 소진)까지 **하드 상한 없이** 계속 로드된다 (절단 제거).
- [ ] 정렬은 **가까운 순(거리 오름차순)** 을 유지하며, 추가 로드로 기존 항목 순서가 요동치지 않는다(링 확장은 항상 더 먼 항목을 **뒤에만** 추가).
- [ ] 거리 미상(위경도 0 등) 매장은 현행과 동일하게 뒤로/제외 처리 (기존 규칙 보존).
- [ ] 읽기는 사용자 주변 반경 내로 한정되어 전체 매장 수와 무관하게 비용이 지역 밀도에 비례한다.

### UI 요구사항

- [ ] 리스트 하단 **footer 로딩 인디케이터**(추가 로드 중).
- [ ] 마지막 페이지 도달 시 로딩 종료(인디케이터 제거). "더 이상 없음" 명시 여부는 designer 결정(경미).
- [ ] 추가 로드 실패 시 **기존 항목 유지 + footer 재시도** (전체 화면 에러로 덮지 않음).
- [ ] 초기 로딩/빈 상태/전체 에러는 기존 공통 위젯(`StoreListSkeleton` / `RecommendedEmptyState` / `StoreListError`) 재사용.
- [ ] 홈 카드 **영업 배지(store_business_schedule)** · **거리 표시** 는 현행 그대로 동작 (카드 레벨 계산이라 페이지네이션과 독립 — 회귀 금지).

### 상태 요구사항

- [ ] 초기 loading / 초기 error(+재시도) / 초기 empty
- [ ] 추가 로드 loading (footer)
- [ ] 추가 로드 error (footer 재시도, 기존 항목 보존)
- [ ] 소진(exhausted) — 더 로드 안 함
- [ ] 위치 권한 없음 → 폴백 중심(서울시청, 현행 `_fallbackLocation`)에서 가까운 순. 기존 pre-permission 흐름 보존.

---

## 2. 비범위

- 맞춤추천/검색(매장·메뉴)/주문 탭/지도 탭의 100 cap 해소 (D0-a 선택 시 — `store_snapshot_truncation` 후속 과제).
- 서버(CF) 기반 거리 정렬·페이지네이션 (D1-b, Phase 2).
- 등급순 등 거리 외 정렬의 페이지네이션 (현행 `맞춤추천` 등급순 토글은 스냅샷 전수 정렬 전제 — D0-a 에서 변경 없음).
- 지도 탭의 뷰포트 기반 동적 로딩.
- 검색어 서버 인덱싱(전문 검색) 도입.

---

## 3. 현황 조사 (설계 근거)

### 3.1 단일 스냅샷 파생 구조

`storeSnapshotProvider`(`home_providers.dart`)가 홈 진입 시 **단 1회** `getApprovedStores(location)` → `fetchAll(limit: 100)` 을 읽고, 아래가 전부 이 값에서 파생된다(추가 읽기 0):

| 목록 | Provider | 현재 상한 |
|---|---|---|
| 홈 주변매장(가로) | `nearbyStoresProvider` | 반경 20km 내 take 10 (전체는 스냅샷 100) |
| 홈 맞춤추천 preview/전체보기 | `recommendedStores*Provider` | 스냅샷 100 (카테고리 필터) |
| 검색 매장 | `searchStoreResultsProvider` | 스냅샷 100 |
| 검색 메뉴 인덱스 후보 | `menuSearchIndexProvider` | 스냅샷에서 반경 10km·상위 30 |
| 주문 탭 매장/지도 | `orderBaseStoresProvider` | `getNearbyStores` → `fetchAll(100)` (반경 10km·50건) + 등급(S/A/B/C)·검색 필터 |

### 3.2 절단의 실제 메커니즘 (핵심)

`StoreRemoteDataSource.fetchAll` 은 `orderBy('averageScore', descending: true).limit(100)`. **거리순이 아니라 점수순으로 상위 100** 을 읽고 그 다음에 클라이언트가 거리 계산·정렬한다. 따라서:

- 점수 101위 밖 매장은 **거리와 무관하게 전 목록에서 사라진다** (사용자가 "100건으로 잘린다" 고 체감한 실체).
- 신규/저평점 매장이 바로 옆이어도 안 보일 수 있다 → **위치 우선 제품에서 정합성 문제**.

### 3.3 영업배지·거리와의 상호작용

- 거리(`distanceKm`)는 Repository 가 중심 위치로 계산해 Entity 에 실어 보냄 → 카드가 `DistanceCalculator.formatKm` 표기. 페이지네이션 중심 좌표만 바뀌지 않으면 그대로.
- 영업배지(`StoreOpenBadge`)는 카드가 그려질 때 `store` 필드로 1회 계산 — 목록 조회 방식과 무관. **회귀 위험 없음** (중심/정렬만 바꾸면 됨).

---

## 4. 데이터 모델

### Entity — `StoreEntity`

- 변경 없음. `distanceKm` 기존 필드 그대로 사용. (geo 필드는 Entity 에 올리지 않는다 — 조회 인덱스용 내부 값.)

### 페이지 결과 값객체 (domain, 신규)

```text
StorePage {
  items: List<StoreEntity>   // 이번까지 누적 또는 이번 페이지 (구현에서 Notifier가 누적)
  loadedRadiusKm: double     // 현재까지 읽은 반경
  exhausted: bool            // 최대 반경 소진 → 더 없음
}
```
(순수 Dart. freezed 가능. 명칭은 developer 재량, 책임만 고정.)

### DTO / Model — `StoreModel`

- 신규 Firestore 필드 `position: { geohash: string, geopoint: GeoPoint }` (D1-a).
- `fromFirestore`: `position` 없으면(legacy) null 허용 → 마이그레이션 전 문서 대비. 조회 시 geo 쿼리에 안 걸리므로 **마이그레이션 완료 전까지 geo 경로와 기존 경로 중 안전한 폴백** 필요(§6 에러 처리).
- `toFirestoreForCreate / BrandCreate / CoreUpdate`: 위경도에서 geohash 계산해 `position` 기록.
- 기존 `location: GeoPoint` / `latitude` / `longitude` 병행 유지.

---

## 5. 레이어 설계 (D0-a + D1-a)

### Domain

- **Repository Interface** (`StoreRepository`): 신규 메서드
  ```text
  Future<StorePage> getNearbyStoresPaged({
    required UserLocation center,
    required double radiusKm,   // 이번 링까지 읽을 반경
  });
  ```
  (반경 링 기반. 커서가 아니라 "반경" 이 페이지 경계 — Firestore 거리 커서 불가 때문. §0 D1 참조.)
- **UseCase** (신규, 단일 책임): `GetNearbyStoresPagedUseCase` — Repository 위임 + 거리 오름차순 정렬·dedup 규칙 보장(순수 로직은 static 헬퍼로 분리 가능, 기존 `GetNearbyStoresUseCase.withinRadius` 패턴 참고).
- 기존 `GetNearbyStoresUseCase` 는 D0-a 범위 밖 호출부(주문 탭 등)가 계속 쓰므로 **보존**.

### Data

- **DataSource** (`StoreRemoteDataSource`, 신규 메서드): `fetchNearby({center, radiusKm})` — `geoflutterfire_plus` 로 중심+반경 근접 쿼리(9개 geohash 범위 fan-out), `status == approved` 필터 결합, 거리순 모델 반환. **SDK import 는 여기서만.**
- **RepositoryImpl**: `fetchNearby` 결과를 `_filterApproved` → 거리 계산/정렬(기존 `_attachDistance` 재사용) → `StorePage` 조립. 반경 소진 판정.
- **Model**: §4.

### Presentation

- **Provider** (신규, 홈 전체보기 전용): `pagedNearbyStoresProvider` = `AsyncNotifier` 가
  - 상태: 누적 `items`, `loadedRadiusKm`, `isLoadingMore`, `exhausted`, `loadMoreError`.
  - `build()`: 시작 반경으로 첫 로드(가까운 순 상위 20 노출).
  - `loadMore()`: 노출분이 바닥나면 (a) 로드된 반경 내 미노출분을 20개 더 reveal, (b) 소진됐으면 반경 확장 → `getNearbyStoresPaged` 재호출 → dedup(id) 후 **뒤에 append**(순서 안정) → 20 reveal. 최대 반경 도달 시 `exhausted`.
  - 중복·누락 방지: 누적 id Set 으로 dedup. 링은 겹칠 수 있으므로 append 전 반드시 dedup.
  - 위치 갱신(재정렬) 시: 중심이 바뀌면 전체 상태 리셋(invalidate) 후 처음부터 — 부분 재정렬은 순서 꼬임 유발하므로 금지.
  - **필터 결합**: 등급/카테고리/검색어 필터가 이 목록에 붙는 경우, 클라이언트 필터 후 20개가 안 차면 **찰 때까지(또는 소진까지) 계속 loadMore** ("load-until-fill"). D0-a 홈 주변매장 전체보기에는 현재 등급 필터가 없으나(등급 필터는 주문 탭), 카테고리 필터(맞춤추천)와 공존 시 이 규칙을 적용.
- **화면**: 홈 `주변매장` 전체보기(= `RecommendedStoresPage` 패턴의 Sliver 리스트) 하단에 스크롤 리스너(`ScrollController` 또는 `NotificationListener`)로 끝 근접 시 `loadMore()` 호출. footer sliver 로 로딩/에러/소진 표시.
- **공통 위젯**: `store_list_states.dart` 에 footer 로딩·footer 재시도 위젯 추가(기존 `StoreListSkeleton/Error/Empty` 와 한 파일).

> 홈의 **가로 `주변매장` preview(take 10)** 는 무한 스크롤 대상이 아니다 — 미리보기이므로 현행 유지. 무한 스크롤은 **전체보기/목록 화면** 에만 적용.

---

## 데이터 흐름

```text
전체보기 Page (ScrollController 끝 감지)
  → pagedNearbyStoresProvider (AsyncNotifier: 누적/반경/소진 상태)
  → GetNearbyStoresPagedUseCase
  → StoreRepository (getNearbyStoresPaged)
  → StoreRepositoryImpl (approved 필터 + 거리정렬 + StorePage 조립)
  → StoreRemoteDataSource (fetchNearby: geoflutterfire_plus 근접 쿼리)
  → Firestore (position.geohash 범위 9쿼리 + status 필터)
```

---

## 6. 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 초기 로드 네트워크 실패 | 전체 화면 `StoreListError` + 재시도 (기존 패턴, `searchReadRetry` 재시도 정책 재사용 가능) |
| 추가 로드(loadMore) 실패 | **기존 항목 유지** + footer 재시도 버튼. 전체 화면 에러로 덮지 않음 |
| 결과 0건 (시작 반경 내) | 반경 자동 확장 시도 → 최대 반경까지 0건이면 `RecommendedEmptyState`("주변에 매장이 없습니다") |
| 마지막 페이지(소진) | `exhausted` → 로딩 종료, footer 인디케이터 제거 |
| 위치 권한 없음 | 폴백 중심(서울시청)에서 가까운 순. 기존 pre-permission 흐름 유지 |
| geo 필드 없는 legacy 문서(마이그레이션 전/부분) | geo 쿼리에서 누락될 수 있음 → **마이그레이션 완료를 배포 게이트로** 두거나, 미완 구간에서 기존 `fetchAll` 폴백 경로 유지(developer 가 전환 안전장치 설계). tester 필수 확인 |
| permission-denied(비로그인) | 기존 `PermissionDeniedException` 변환 경로 보존 |

---

## 7. 이력 / 감사 추적 (audit_trail §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** → **아니다.** 읽기(조회) 전용 기능. 매장 문서의 돈/권한/정책 값(가격·적립률·승인상태·역할)을 바꾸지 않는다. → **설정 변경 이력 불필요.** (사유 명시: 본 기능이 추가하는 유일한 쓰기는 `position.geohash` 라는 위경도 파생 **조회 인덱스 값**으로, 정책/권한/금액이 아니다.)
2. **덮어쓰기로 사라지는 값?** → 없음. `position` 은 신규 필드, 기존 `location` 병행 유지.
3. **정책 값 참조만?** → 해당 없음(거래/기록 문서 생성 없음).
4. **"누가"?** → 운영자 쓰기 행위 없음. 단 §5 쓰기 경로(점주/brand 생성·수정)에 geohash 가 얹히는 것은 기존 행위자 메타(`submittedBy` 등)에 이미 포함.
5. **일괄 처리(batch)?** → **있다 — geohash 백필 마이그레이션.** `migrationHistory/{autoId}` 에 1건(실행 시점 + 영향 매장 수 + 덮어쓰기 여부) 남긴다 (§4-5 준수).
6. **CF 로그 의존?** → 영구 기록은 Firestore(`migrationHistory`)에 남기므로 Cloud Logging 의존 아님.
7. **권한 판정 필드 create/update 교차 확인?** → geohash 는 권한 판정 필드가 **아니다.** 다만 쓰기 경로에 필드를 추가하므로, developer 는 `stores` 생성/수정 Rules 가 신규 `position` 필드 때문에 **기존 보호(승인상태·brandId 등) 회귀를 일으키지 않는지** create/update 양쪽 확인 + 정상 payload 허용 회귀 케이스 유지.

→ **결론: 설정 변경 이력 없음(사유 위 명시). 마이그레이션 이력 1건 필수.**

---

## 8. 작업 분배

### designer

- **UI 변경 여부**: 경미(필요). 신규는 **리스트 footer 상태**뿐 — 추가 로딩 스피너 / 추가 로드 실패 재시도 / (선택)"더 이상 없음" 표기. 초기 로딩·빈·전체 에러는 기존 공통 위젯 재사용.
- 디자인 산출물: `design.md` — footer 3상태(로딩/에러재시도/소진) 시각·문구·간격, 스크롤 트리거 지점(끝에서 N px), AppColors 토큰만 사용.
- 전달 사항: 가로 preview 는 변경 없음. 전체보기 화면(Sliver)만 대상.

### developer

- 구현 항목: §5 레이어(Domain 메서드·UseCase·StorePage, Data geo 쿼리·Model geohash·Impl, Presentation AsyncNotifier·스크롤 리스너·footer), geohash 백필 마이그레이션 + `migrationHistory` 1건, `firestore.indexes.json` 복합 인덱스, `pubspec.yaml` geo 라이브러리.
- 재사용할 기존 구조: `_attachDistance`/`_filterApproved`(Impl), `DistanceCalculator`, `store_list_states.dart`, `GradeThresholds` 상수, `searchReadRetry` 재시도 정책, `RecommendedStoresPage` Sliver 패턴.
- 주의할 레이어 규칙: geo SDK import 는 **data 레이어(datasource)에만**. geohash 는 위경도 단일 출처에서 계산(불일치 금지). geo 미완 구간 폴백 안전장치. 상수 리터럴 금지. 중심 변경 시 상태 리셋(부분 재정렬 금지).

### tester

- 주요 검증: 초기 20건·가까운 순 안정·끝 스크롤 추가 로드·소진 종료·중복/누락 0·필터 공존(load-until-fill).
- 반드시 확인할 예외: 결과 0건/최대 반경 소진/추가 로드 실패 시 기존 항목 보존+footer 재시도/위치 권한 없음 폴백/legacy(geo 필드 없는) 문서 폴백/영업배지·거리 표기 회귀 없음.
- 아키텍처: presentation·domain 에 Firebase/geo SDK import 없음. 마이그레이션 `migrationHistory` 기록 확인.
- 회귀 전수: 맞춤추천·검색(매장/메뉴)·주문 탭·지도가 D0-a 범위에서 **변경 전과 동일 동작**(스냅샷 경로 안 깨짐).

---

## 9. 완료 기준

- [ ] §0 D0·D1·D2·D3 사용자 확정 반영
- [ ] 요구사항 모두 구현 또는 보류 사유 명시
- [ ] `design.md` 작성 완료(footer 상태)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료, FAIL 0 또는 후속 분리
- [ ] 100 cap 잔존 목록이 `store_snapshot_truncation` 백로그로 등록됨(D0-a)
- [ ] geohash 마이그레이션 `migrationHistory` 1건 확인
- [ ] 영업배지·거리·기타 목록 회귀 0
```

