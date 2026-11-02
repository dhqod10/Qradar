# store_list_pagination 구현 내역

## 개요

- 구현 목적: 홈 `주변매장` **전체보기** 1곳(D0-a)을 "점수순 상위 100 절단" 에서 **geohash 근접 쿼리 + 가까운 순 20건씩 무한 스크롤** 로 전환. 반경 5 -> 10 -> 20 -> 40km 확장.
- 기준 문서: `docs/tasks/store_list_pagination/spec.md`, `design.md`
- 홈 스냅샷(`storeSnapshotProvider`)·맞춤추천·검색·주문 탭·지도·홈 가로 preview 는 **변경 없음**.

---

## 구현 파일 목록

### 신규 파일

- `lib/domain/entities/store_page.dart` — `StorePage {items, loadedRadiusKm, exhausted}`
- `lib/domain/usecases/get_nearby_stores_paged_use_case.dart` — 위임 + 순수 헬퍼(`nextRadius` / `isMaxRadius` / `newItemsOnly`)
- `lib/presentation/customer/home/providers/nearby_paged_providers.dart` — `pagedNearbyStoresProvider`(AsyncNotifier), `NearbyPagedState`
- `lib/presentation/customer/home/nearby_stores_page.dart` — 전체보기 화면 (스크롤 트리거, footer, 배너)
- `functions/src/backfillStoreGeohash.ts` — admin callable, geohash 백필
- `test/domain/nearby_paged_test.dart` — 10 케이스

### 수정 파일

- `pubspec.yaml` / `pubspec.lock` — `geoflutterfire_plus: ^0.0.34`
- `lib/core/constants/grade_thresholds.dart` — `nearbyPageSize=20`, `nearbyPagedStartRadiusKm=5`, `nearbyPagedRadiusFactor=2`, `nearbyPagedMaxRadiusKm=40`
- `lib/domain/repositories/store_repository.dart` — `getNearbyStoresPaged` 추가
- `lib/data/datasources/remote/store_remote_data_source.dart` — `fetchNearby` (geo SDK import 는 여기와 `store_model.dart` 만)
- `lib/data/models/store_model.dart` — `positionField` + create / coreUpdate / brandCreate 에 `position` 기록
- `lib/data/repositories/store_repository_impl.dart` — `getNearbyStoresPaged`
- `lib/presentation/common/store_list_states.dart` — `StoreListLoadingFooter` / `StoreListRetryFooter` / `StoreListEndFooter` / `NearbyEmptyState` / `LocationFallbackBanner` (문구 파라미터)
- `lib/presentation/customer/home/widgets/nearby_stores_section.dart` — 헤더에 `전체보기` 진입 버튼만 추가 (아래 design 차이 참조)
- `firestore.rules` — owner/brand update 화이트리스트에 `position` 추가
- `firestore.indexes.json` — 복합 인덱스 추가
- `functions/src/index.ts` — `backfillStoreGeohash` export 1줄 (다른 task 의 미커밋 변경과 같은 파일; 내 변경은 말미 3줄)
- `docs/processes/data_ownership.md` — stores update 화이트리스트에 `position` 반영

### 재사용 파일

`RecommendedStoreCard`(영업배지·거리 그대로), `StoreListSkeleton`(rows 6), `StoreListError`, `searchReadRetry`, `PrePermissionDialog`, `DistanceCalculator`, `_filterApproved` / `_attachDistance`

---

## 주요 결정사항

- **반경이 페이지 경계**: Repository 는 "반경 R 이내 전부, 가까운 순" 을 돌려주고, Notifier 가 id 중복 제거 후 **뒤에만 append** + 20건 reveal. 반경 경계는 라이브러리 strictMode(2% 버퍼) 대신 Repository 에서 `<= radiusKm` 로 확정해 링 간 중복/누락을 막음.
- **20건 채우기**: 초기 로드·loadMore 모두 노출분이 20 미만이면 최대 반경까지 계속 확장 (확장 중 build 미완 -> skeleton 유지, 최대 반경 0건일 때만 empty).
- **위치 변경 시 리셋**: `build()` 가 `userLocationProvider` 를 watch -> 재빌드 = 처음부터. 늦게 끝난 loadMore 는 `_generation` 으로 폐기.
- **스크롤 트리거**: `extentAfter <= 300`. 스크롤 이벤트 + 매 build 후 postFrame 에서 판정(짧은 목록 연쇄 로드 포함). `canLoadMore`(로딩중/소진/실패 아님) 가 가드. 실패 상태에서는 자동 재호출 없음, footer 탭으로만 `retryLoadMore()`.
- **legacy 안전장치**: geo 쿼리가 **최대 반경에서도 0건**이면 `fetchAll(100)` 폴백 1회 (백필 전 빈 화면 방지). 부분 백필 상태의 누락은 막지 못하므로 **백필 완료를 배포 게이트로** 둔다.
- **쓰기 경로 Rules drift 방지**: owner/brand update 화이트리스트에 `position` 이 없으면 핵심 필드 수정(location 포함 payload)이 통째로 거부됨 -> `firestore.rules` 에 `position` 추가 (create 는 필드 제한 없음). `position` 은 `location` 에서 파생되는 조회 전용 값이라 권한/금액 영향 없음.
- **"설정 열기"**: 기존 pre-permission 흐름(`PrePermissionDialog` + `allowAndFetch`)을 `notYetAsked` 일 때 재사용, `deniedForever` 는 `AppSettings.openAppSettings()`(기존 의존성), `serviceDisabled` 는 액션 없음(앱 설정으로 해결 불가).

---

## spec.md 대비 차이

- 최대 반경 50km(권고) -> **40km** (사용자 확정 5->10->20->40).
- 마이그레이션은 CF 방식 선택(`backfillStoreGeohash`, `backfillAvailableMainCategories` 구조 준용).

## design.md 대비 차이

- design 은 `주변매장 전체보기` 를 "기존 화면" 으로 가정했으나 **존재하지 않았다** (홈은 가로 preview 뿐). `NearbyStoresPage` 를 신규 생성하고, 진입을 위해 `NearbyStoresSection` 헤더에 `전체보기` 버튼(맞춤추천과 동일 스타일)만 추가했다. 홈 가로 preview 동작/데이터는 무변경.
- 정렬 바·카테고리 필터·pull-to-refresh 는 넣지 않음(범위 밖).
- idle(대기) 시 footer 는 72px 투명 spacer 로 점프 방지.

---

## 마이그레이션 / 인덱스 준비 절차 (사용자 직접 실행, 나는 배포/생성하지 않음)

**순서가 중요하다. 앱 릴리스 전에 1~4 완료.**

1. `firestore.rules` 배포 (`position` 허용). 앱보다 먼저.
2. `firestore.indexes.json` 배포 -> 복합 인덱스 `stores(status ASC, position.geohash ASC)` 생성, **빌드 완료(READY) 대기**. (미완이면 geo 쿼리가 failed-precondition 으로 실패.)
3. Cloud Function 배포: `backfillStoreGeohash` (`functions/src/index.ts` 에 다른 task 의 미커밋 export 도 있으니 배포 대상 확인).
4. 백필 실행 (admin 계정 callable): 먼저 `{dryRun: true}` (기본) 로 `affected`/`skipped` 확인 -> `{dryRun: false}`. 멱등이라 재실행 안전. 실행 후 `migrationHistory` 에 `name: backfillStoreGeohash` 1건 확인. `skipped`(location 없음/좌표 무효) 매장은 geo 쿼리에 안 잡히므로 수동 점검.
5. 앱 릴리스. 이후 신규 매장/핵심 수정은 앱이 `position` 을 함께 쓴다.
- 주의: `status` 필드가 없는 극단적 legacy 문서는 `status == approved` 서버 필터에서 빠진다 (`migrateStoreApprovalMeta` 완료 전제).

---

## 테스트 포인트

- [ ] 기능: 진입 시 가까운 순 20건, 끝 300px 이내 스크롤 시 +20, 소진까지 하드 상한 없이 로드, 추가 로드 후 기존 순서 불변, 중복 0
- [ ] 짧은 목록: 초기 20건이 화면을 못 채우는 큰 화면에서 자동 연쇄 로드
- [ ] 상태 UI: skeleton(6행) / 로딩 footer / 소진 footer 문구(km 미노출) / `NearbyEmptyState` / 확장 중 empty 깜빡임 없음
- [ ] 에러: 초기 실패 `StoreListError` 재시도, 추가 실패 시 목록 보존 + footer `다시 시도`, 자동 재호출 없음
- [ ] 위치: 권한 거부 -> 배너(+`설정 열기`), 허용 후 복귀 시 목록 리셋·배너 제거, serviceDisabled 는 액션 없음
- [ ] legacy: 백필 전/후, `position` 없는 문서 폴백(최대 반경 0건 시 100건 경로)
- [ ] Rules: 점주/브랜드 핵심 필드 수정(location 변경) 정상 저장, create 정상, 승인 메타 보호 회귀 없음 (emulator 테스트는 미실행)
- [ ] 아키텍처: presentation/domain 에 `geoflutterfire_plus`·Firebase import 없음 (data 만)
- [ ] 회귀: 영업배지/거리 표기, 홈 가로 preview, 맞춤추천·검색·주문 탭·지도

## 미구현 / 보류 항목

- 나머지 목록 100 cap -> `store_snapshot_truncation` 백로그 등록 필요(spec §9) — architect 확인 필요.
- Rules emulator 테스트 케이스(`position` 포함 update 허용) 미추가/미실행.
- 위젯(화면) 테스트 미작성: 상태 전이/반경 확장/소진/실패 재시도는 provider 단위 테스트로 검증, 스크롤 트리거는 수동 확인 필요.
- 기존 매장의 `location` 이 Console/Admin 으로 바뀌면 `position` 이 stale 될 수 있음(백필 재실행으로 치유).

## 코드 생성 필요 여부

- [x] 필요 없음 (freezed/build_runner 대상 변경 없음)

## 검증

- `flutter analyze`: No issues found
- `flutter test`: 전체 1076 통과 (신규 `test/domain/nearby_paged_test.dart` 10 케이스 포함)
- `functions` `tsc --noEmit`: 통과. TS geohash 인코더가 `u4pruydqq`(표준 벡터)와 Dart 라이브러리 값과 일치함을 확인
