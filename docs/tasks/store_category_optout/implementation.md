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
