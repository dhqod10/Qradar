# store_list_pagination 테스트 리포트

검증일: 2026-11-02 / 기준: spec.md, design.md, implementation.md + 실제 코드 (배포·백필 미실시)

## 요약
PASS 17 / FAIL 1 / 보류 5

자동 검증: `flutter analyze` 이슈 0, `flutter test` 전체 통과 (1076, 신규 nearby_paged_test.dart 포함), `functions` `tsc --noEmit` 통과.

## PASS
1. 반경 확장 5->10->20->40, 상수는 GradeThresholds 한 곳 (nearbyPaged*). nextRadius 가 40 에서 clamp.
2. 초기 로드: 20건 못 채우면 최대 반경까지 build 안에서 확장. build 가 끝나지 않으므로 skeleton 유지, 40km 에서도 0건일 때만 NearbyEmptyState.
3. 거리순: Repository 가 반경 경계(distance <= radiusKm) 재필터 후 정렬, newItemsOnly 가 id 중복 제거 + 기존 목록 뒤에만 append (순서 불변).
4. 위치 변경 -> userLocationProvider watch 로 build 재실행, 처음부터 재조회. _generation 가드로 늦게 끝난 loadMore 가 새 상태를 덮지 않음.
5. 추가 로드 실패: catch 에서 loaded 보존 + loadMoreFailed=true, canLoadMore=false 라 자동 재호출 없음. retryLoadMore 는 footer 탭에서만 호출.
6. footer 3종(로딩/재시도/소진) + 위치 폴백 배너 + NearbyEmptyState 구현. 빈 목록 시 소진 문구 중복 없음.
7. 폴백 안전장치: 최대 반경 geo 0건 -> fetchAll(100) 1회 폴백. FirebaseException permission-denied 매핑 유지.
8. status==approved 서버 필터 + _filterApproved 이중 방어. legacy(status 없음) 제외는 문서화된 전제.
9. 설정 열기: deniedForever -> AppSettings.openAppSettings, notYetAsked -> PrePermissionDialog + allowAndFetch 재사용, 그 외(위치서비스 off 등) 액션 없음 (의도대로).
10. 범위 준수: git diff 상 홈 스냅샷/맞춤추천/검색/주문탭/지도 파일 무변경. nearby_stores_section.dart 는 SectionTitle trailing 에 "전체보기"(44 높이 터치영역) 1개 추가뿐, preview 데이터/동작 불변. 페이지네이션은 신규 NearbyStoresPage 에만 적용.
11. Clean Architecture: geoflutterfire_plus import 는 store_remote_data_source.dart, store_model.dart (data) 두 곳뿐. domain/presentation 없음.
12. 색상: 신규 코드에 Color(0x...) 없음, AppColors 만 사용. secret 하드코딩 없음.
13. firestore.rules: 점주(isStoreOwnerFieldUpdate) / 브랜드(isStoreOwnerBrandUpdate) 화이트리스트에 'position' 추가. 운영/핵심 필드 분리는 유지 (status 승격 차단, leavingRejectedClearsApproval, Qoin 관리 필드 차단 불변). 앱이 location 변경 시 position 도 함께 쓰므로 누락 시 silent fail 하던 경로가 막힘.
14. firestore.indexes.json: stores(status ASC, position.geohash ASC) 가 fetchNearby 쿼리(status==approved + geohash 범위)와 일치.
15. toFirestoreForCreate / CoreUpdate / BrandCreate 3곳 모두 positionField(location 파생) 동일 헬퍼로 기록. OperationUpdate 는 location 미기록이라 position 도 불필요.
16. backfillStoreGeohash.ts: admin 검증, dryRun 기본 true, 멱등, 400건 청크, migrationHistory 1건, location 없음/좌표 무효는 skip 리포트(자동 보정 없음), 점 표기 update 로 다른 필드 무변경. index.ts export 확인.
17. functions/package.json 의 test 스크립트 변경은 qoin_accrual_backfill(qoinRateReconstruct.test) 분이며 본 기능과 무관 (오염 아님, 참고).

## FAIL
F1. (중간) docs/processes/data_ownership.md 에 position/geohash 반영 누락.
- 현재 diff 의 변경은 qoinBackfillHistory / backfillQoinAccrual 행(다른 작업)뿐. grep "position|geohash|backfillStoreGeohash" 0건.
- 필요: stores 표에 `position {geohash, geopoint}` (location 파생, 조회 전용, 점주/브랜드 update 화이트리스트 포함), CF 표에 `backfillStoreGeohash`(admin, dryRun 기본, migrationHistory 1건). 또한 migrationHistory 행에 이 실행도 남는다는 언급.
- 조치 주체: architect/developer 문서 보강. 코드 영향 없음.

## 보류
H1. 스크롤 트리거(maxScrollExtent-300px): 코드상 pos.extentAfter <= 300 판정 + NotificationListener(vertical) 로 구현 확인. 위젯 테스트 없음 -> 실기기 확인 필요.
H2. 초기 화면을 못 채울 때 자동 loadMore: build 마다 addPostFrameCallback -> _maybeLoadMore (짧은 목록이면 extentAfter=0). 코드 확인, 실기기 확인 필요.
H3. 로딩중/소진/에러 시 트리거 무시: canLoadMore(hasMore && !isLoadingMore && !loadMoreFailed) 로 차단, 코드 확인. 위젯 테스트 없음.
H4. 백필 전 실서버 동작(인덱스 배포, position 백필 후 fetchWithin 결과, 폴백 경로): 배포·백필 금지 범위라 미검증. 배포 순서는 인덱스 -> Rules -> 백필 dryRun -> 실행 -> 앱.
H5. 비차단 관찰: (a) Rules create 가 position 값 검증이 없어 점주가 임의 geohash 를 심을 수 있음(자기 매장 노출 위치 위조, 금액/권한 영향 없음, location 도 점주 자가 입력이라 위험 낮음). (b) build 의 확장 루프는 반경마다 geo 쿼리를 새로 읽어 이전 반경 결과를 재조회(비용 최적화 여지). (c) 폴백(fetchAll 100)이 40km 외 매장도 반환하나 경계 필터에서 걸러져 40km 밖 매장은 결과가 비어 폴백 효과가 40km 이내로 제한됨 -> 백필 전 빈화면 방지 목적상 의도 확인 필요 (거리 필터 전 폴백이라면 40km 이내 legacy 매장은 노출됨, 정상).

## 우선 수정
1. F1 data_ownership.md 에 position/backfillStoreGeohash 반영 (유일한 FAIL, 문서).
