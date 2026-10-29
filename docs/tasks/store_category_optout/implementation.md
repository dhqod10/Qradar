# store_category_optout 구현 기록

- 작성: developer / 2026-10-29
- 기준: `spec.md` (§0.3 A 확정, §0.4), `design.md`, 사용자 확정 UX 3건

## 사용자 확정 UX 반영
1. 전부 OFF: 인라인 경고 배너 + 저장 시 확인 다이얼로그 ("메뉴가 모두 숨겨져요" / "돌아가기" / "저장"). 이미 전부 OFF 로 저장돼 있고 그대로면 다이얼로그 생략.
2. 고객 빈 상태: 중립 문구 ("지금은 주문할 수 있는 메뉴가 없어요" / "매장에서 메뉴 준비 중이에요. 다른 매장을 둘러보세요.").
3. 섹션 위치: 임시 휴무 토글 + 휴무 날짜 에디터 바로 아래 (소개 필드 위).

## 구현 완료 (Phase A 전체)
- StoreEntity `excludedMainCategories` (`@Default([])`) + freezed 재생성.
- StoreModel: 필드/생성자 기본값/`fromFirestore`(부재 -> `[]`)/`fromEntity`/`toEntity`/`toFirestoreForOperationUpdate` 에만 쓰기. create / brandCreate / coreUpdate 맵에는 넣지 않음.
- `UpdateStoreOperationFieldsUseCase` docstring (새 UseCase/Repo 메서드 없음, 모델 경유로 기존 저장 경로 재사용).
- `firestore.rules`: `isStoreOwnerFieldUpdate` / `isStoreOwnerBrandUpdate` 양쪽 화이트리스트에 `excludedMainCategories` 추가 (핵심 필드/승인 메타/Qoin 보호 필드와 분리 유지, status 무변동).
- `isMenuShownOnStoreScreen` 에 `excludedCategoryIds`(기본 빈 집합) 추가 — 매장 탭 / 검색 2단계 / 자동 상세 직행 판정이 같은 함수에서 excluded 반영 (F5 유지).
- `store_menu_providers.dart`: `storeExcludedMainCategoriesProvider`(watchedStoreProvider 파생, AsyncValue), `storeAvailableMainCategoriesProvider` 차집합, `filteredMenuItemsProvider` storeMains/메뉴 필터에 excluded 반영(선택 카테고리가 제외되면 effectiveMain=null 폴백).
- `search_providers.dart` `menuSearchResultsProvider`: 스냅샷(`storeSnapshotProvider`)의 매장별 excluded 로 1단계 결과 필터 (추가 읽기 0).
- `store_menu_page.dart`: excluded 확정 전 `_LoadingShimmer`(플리커 방지), store 구독 에러 시 `_ErrorView`, "가용 카테고리 0" 분기 신규, `_EmptyView` 에 `title`/`subtitle` 파라미터 (기본값 = 기존 문구, 기존 경로 무변경).
- `store_operation_form_page.dart`: "카테고리 노출 설정" 섹션 (Switch 리스트, loading shimmer / error 재시도 / empty / 전부-OFF 배너 / 접근성 Semantics). 저장은 기존 `_submit` 재사용. 저장 계산식 `newExcluded = (원본 중 active 아닌 휴면 코드) ∪ (화면 OFF 인 active 코드)`; active 목록 loading/error 시 원본 보존. "전부 끄기" 판정 = active ≥1 && 전부 OFF.
- `docs/processes/data_ownership.md §2.5` update 화이트리스트 갱신.
- 테스트 추가: `test/core/store_category_optout_test.dart` (판정 함수 + 모델 쓰기 맵 규율).

## 수정/생성 파일
- lib/domain/entities/store_entity.dart (+ .freezed.dart 재생성)
- lib/domain/usecases/update_store_operation_fields_use_case.dart
- lib/data/models/store_model.dart
- lib/core/utils/store_menu_visibility.dart
- lib/presentation/customer/order/store/providers/store_menu_providers.dart
- lib/presentation/customer/order/store/store_menu_page.dart
- lib/presentation/customer/search/providers/search_providers.dart
- lib/presentation/owner/my_store/store_operation_form_page.dart
- firestore.rules
- docs/processes/data_ownership.md
- test/core/store_category_optout_test.dart (신규)

## 배포 필요
- `firestore.rules` (hosting 아님, rules 만): excludedMainCategories 쓰기 허용. **배포 전에는 점주 저장 시 permission-denied.**

## 테스트 포인트 (tester)
- 점주: 카테고리 OFF -> 저장 -> 즉시 반영, store.status 불변(재승인 없음). 개인/가맹/브랜드홀더 모두.
- 전부 OFF: 배너 노출 + 저장 시 다이얼로그(돌아가기=저장 안 함, 저장=진행). 이미 전부 OFF 저장분이면 다이얼로그 없음.
- 휴면 코드 보존: admin 이 카테고리 비활성화 -> 점주 저장 후에도 excluded 에 그 코드 유지.
- 카테고리 목록 loading/error/empty 에서 저장해도 기존 excluded 보존.
- 고객 매장 탭: 끈 카테고리 탭/메뉴 사라짐, 브랜드가 해당 카테고리 마스터 추가해도 계속 숨김(sticky), 선택 중이던 카테고리가 제외되면 전체로 폴백.
- 전부 제외 시 중립 빈 상태 / 원래 메뉴 0건은 기존 "등록된 메뉴가 없어요".
- excluded 확정 전 숨길 메뉴가 잠깐 보이지 않는지.
- per-item override 제외와 독립 AND (카테고리를 다시 켜면 개별 override 상태 복원).
- 검색: 끈 카테고리 메뉴가 메뉴명 검색 결과에 안 뜨고, 결과 행 ⊆ 매장 탭 노출 목록.
- Rules 하네스 (미작성, 에뮬레이터 필요): excludedMainCategories update 허용 / 정상 payload 회귀 / create 케이스.

## 미구현 / 보류 — Phase B
**착수하지 않았다.** 이유:
1. `availableMainCategories` CF 파생은 브랜드 마스터 메뉴 변경이 전 가맹점 문서로 fan-out 되고(마스터 + override + store excluded + 카테고리 active 변경 4개 소스), 비용/정합성 설계 결정이 필요하다. 트리거 없이 백필만 하면 즉시 stale.
2. 클라이언트 전환(홈 칩 -> mainCategories, 필터 -> availableMainCategories, `menuCategories` 및 점주 수동 칩 제거)은 spec §6 순서상 CF 트리거 배포 -> 백필 -> 전환이라, 코드만 먼저 바꾸면 배포 전까지 홈 필터가 깨진다.
- 남은 작업(spec §6): ① CF 트리거 + 파생 계산(순수 TS, menuVisibility.ts 재사용) ② 백필 콜러블(admin, dryRun 기본, `migrationHistory` 1건 + affected) ③ Rules create 가드(`availableMainCategories` 클라이언트 주입 차단) ④ 홈/검색 칩·필터 교체 ⑤ `menuCategories` 제거. 모두 운영 배포 필요.
- Phase A 의 매장 단위 검색(메뉴명 검색)에는 excluded 가 이미 반영돼 있다. 홈 "카테고리로 매장 찾기"(`menuCategories`)는 아직 excluded 를 모른다 (Phase B).
- Rules 하네스 케이스, 설정 변경 이력(audit A2 버킷) 은 spec 대로 보류/미작성.

## flutter analyze / test
- `flutter analyze`: No issues found.
- `flutter test`: 전체 통과 (900+ 건) + 신규 5건 통과.


---

# Phase B 구현 기록 (2026-10-29) — availableMainCategories CF 파생 · 홈 카테고리 전환

기준: `spec.md §12` (사용자 확정 5건: fan-out 권고안 A / 홈 기본 "전체" / designer 생략 / menuCategories deprecate 만 / 백필 보존). **배포하지 않았다(코드 머지까지).**

## 구현 완료
- **functions/** (모두 `menuVisibility.ts applyOverrideForCustomer` 재사용, 재포팅 0)
  - `availableCategories.ts`: 순수 `computeAvailableMainCategories` (개인/가맹 분기, 마스터 approved&&visible + override 적용 + store-scope approved&&visible, soldOut 무영향, ∩active −excluded, 정렬·중복 제거), `sameCodeSet`, `masterMenuRelevance`(diff 게이트 지문).
  - `recomputeAvailableCategories.ts`: I/O 코어. `planStore`(전량 재계산, 쓰기 없음) / `commitPlans`(변경분만 400건 청크 배치, `availableMainCategories` 1필드만) / `recomputeStore` / `recomputeBrandStores`(마스터 1회 읽어 공유) / `recomputeAllStores`. 계산값==저장값이면 write 생략.
  - `onAvailableCategoriesWritten.ts`: 트리거 5개 `onStoreOwnMenuWritten`, `onStoreMenuOverrideWritten`, `onStoreOptoutWritten`(excluded/brandId 변경·생성시만 — 자기 파생 쓰기 루프 가드), `onBrandMasterMenuWritten`(카테고리/visible/승인/생성/삭제 diff 게이트), `onMainCategoryActiveWritten`(실효 active 플립시만 전 매장). 실패는 console.error 후 swallow.
  - `backfillAvailableMainCategories.ts`: admin 전용 callable, `dryRun` 기본(true), dryRun 은 쓰기 0 + before/after 리포트, 실행 시 `migrationHistory` 1건(`affected`/`total`/`executedBy`). 상시 정합 도구로 보존(index.ts 주석 명시).
  - `index.ts` export 추가, `package.json` test 스크립트에 `test/availableCategories.test.mjs` 추가.
- **firestore.rules**: `stores` create 에 `!('availableMainCategories' in request.resource.data)` 가드 1건. update 화이트리스트에는 넣지 않음(CF 전담).
- **data_ownership.md**: §2.5 stores "Cloud Function 전담" 에 `availableMainCategories` 추가, §3 CF 카탈로그 6행(트리거 5 + 백필) 추가.
- **클라이언트 전환 (§12.4 1단계)**
  - `StoreEntity`/`StoreModel`: `availableMainCategories` 읽기 전용 (부재 -> `[]`, 어떤 `toFirestore*` 맵에도 없음). freezed 재생성.
  - 홈 칩(`category_filter_section.dart`): `mainCategoriesActiveProvider` 의 active 카테고리, 표시=label / 선택·비교=code(id). 로딩/에러/0건이면 섹션 숨김(전체 매장 그대로).
  - `selectedCategoriesProvider`: 초기값 빈 집합 = "전체", 최소 1개 유지 제약 제거(전부 해제 가능).
  - `GetStoresByCategoriesUseCase.filterByCategories` / `StoreRepositoryImpl.getStoresByCategories`: `availableMainCategories` 기반, 빈 선택 = 필터 없음(전체).
  - 점주 수동 카테고리 칩 제거 (`store_form_page`, `store_core_form_page`): `_CategoryMultiSelect` 위젯/필수 검증 제거. 저장 시 `menuCategories` 는 기존 값 보존(`existing?.menuCategories ?? []`) — 쓰기 맵/모델 필드는 유지(deprecate).
- `menuCategories`/`MenuCategories` 상수: **물리 제거 안 함** (StoreModel/Entity 필드·매퍼, 관리자 승인 화면 표시, seed 데이터 그대로).

## 수정/생성 파일
- 신규: `functions/src/{availableCategories,recomputeAvailableCategories,onAvailableCategoriesWritten,backfillAvailableMainCategories}.ts`, `functions/test/availableCategories.test.mjs`
- 수정: `functions/src/index.ts`, `functions/package.json`, `firestore.rules`, `docs/processes/data_ownership.md`
- 수정(lib): `domain/entities/store_entity.dart`(+freezed), `data/models/store_model.dart`, `data/repositories/store_repository_impl.dart`, `domain/usecases/get_stores_by_categories_use_case.dart`, `presentation/customer/home/providers/home_providers.dart`, `presentation/customer/home/widgets/category_filter_section.dart`, `presentation/owner/my_store/{store_form_page,store_core_form_page}.dart`
- 수정(test): `test/domain/home_search_use_cases_test.dart`(cats -> availableMainCategories, 빈 선택=전체), `test/core/store_category_optout_test.dart`(availableMainCategories 그룹 추가)

## 배포 순서 (사용자 수행 — spec §12.5)
**주의: 이 브랜치의 클라이언트는 이미 `availableMainCategories` 를 읽는다. 2~4 가 끝나기 전에 앱을 배포하면 홈 필터가 전부 0건이 된다. 데이터-먼저 순서 고정.**
1. 코드 머지 (본 작업).
2. CF 배포 (프로젝트 루트): `firebase deploy --only functions` (신규 트리거 5 + 콜러블 1; 기존 함수는 변경 없음).
3. 백필 (admin 로그인 상태로 callable 호출, 앱/콘솔 어디서든): `backfillAvailableMainCategories({dryRun:true})` -> 리포트(total/affected/changes) 확인 -> `{dryRun:false}`. 완료 후 `migrationHistory` 1건 확인.
4. Rules 배포 (프로젝트 루트): `firebase deploy --only firestore:rules` (stores create 가드).
5. 앱 배포 (클라이언트 전환). 3 이 끝난 뒤에만.
6. (후속) `menuCategories` 물리 제거 정리 커밋.

## 테스트 포인트 (tester)
- 순수 계산: 개인/가맹, override excluded(approved 만 효력), soldOut 무영향, ∩active, −excluded, 마스터 pending/rejected/visible=false. (`functions/test/availableCategories.test.mjs`)
- diff 게이트: 가격·이름 편집 = fan-out 없음, 카테고리/visible/승인/생성/삭제 = fan-out. 루프 가드: availableMainCategories 만 바뀐 store write 재발화 없음. active 플립만 전 매장.
- 에뮬레이터(미작성): 트리거 ①~④ 가 올바른 매장 집합을 갱신 / 백필 before-after, 두 번 실행 멱등, migrationHistory 1건 + affected.
- E2E: 점주가 디저트 OFF -> 수 초 내 홈 '디저트' 칩 필터에 해당 매장 안 뜸. 브랜드 첫 디저트 마스터 추가 -> 산하 매장 `dessert` 추가(단 excluded 매장은 제외 유지). admin 카테고리 비활성 -> 칩에서 사라지고 매장 목록 정합.
- 홈: 기본 "전체"(모든 승인 매장), 칩 토글로 필터, 모두 해제 시 전체 복귀, 칩 라벨=label.
- 점주 폼: 카테고리 칩 없이 등록/수정 가능(필수 검증 제거), 수정 시 기존 menuCategories 값 변하지 않음(재승인 트리거 없음).
- Rules 하네스(미작성, 에뮬레이터 필요): availableMainCategories create 주입 거부 / update 거부 / 정상 payload 회귀.

## 미구현 / 보류
- `menuCategories` 물리 제거(StoreModel/Entity/쓰기 맵/Rules 화이트리스트/관리자 표시/seed) — 후속 정리 커밋.
- 홈에서 선택해 둔 카테고리가 세션 중 admin 에 의해 비활성화되면 칩은 사라지나 선택 코드는 남아 0건이 될 수 있음(극히 드묾, 앱 재진입시 해소).
- 에뮬레이터 통합 테스트/Rules 하네스 케이스 미작성. fan-out 은 동기 처리(가정 브랜드당 ≤50, 전 매장 ≤500) — 규모 초과 시 spec §12.1.6 대안 C.
- 홈 필터는 `availableMainCategories` 부재 매장을 어떤 카테고리에도 매칭하지 않음(백필 선행 필수).

## 결과
- `flutter analyze`: No issues found.
- `flutter test`: 전체 통과 (아래 최종 실행 참조).
- `functions` `npm run build` + `npm test`: 통과 (341 pass / 0 fail, 신규 테스트 포함).
