# menu_override_integrity — implementation

## 수정 지점
- `lib/data/repositories/menu_override_repository_impl.dart`: `updateOverrideOperationFields` 점주 W2 create data 맵에 `'masterMenuItemId': override.masterMenuItemId` 1줄 추가 (#4). 브랜드 경로/seedExclusionsForStore 무변경.
- `lib/data/datasources/remote/master_menu_item_remote_data_source.dart`: no-op `cascadeDeleteOverrides` 제거 (#3).
- `lib/data/repositories/master_menu_item_repository_impl.dart`: `_menuOverrideRepository` non-nullable + 생성자 `required`; `deleteWithCascade` 는 `deleteAllForMaster` 단일 경로.
- `test/presentation/home_search_stage2_test.dart`: `masterRepo` 에 `menuOverrideRepository: overrideRepo` 주입 (non-null 전환 정합, 1줄).
- DI(`brand_di_providers.dart`) 는 이미 항상 주입 중이라 무변경.

## 결정
- D-1 백필 생략 (menuOverrides 0건 실측). D-2 non-null 전환 완료.
- Rules/CF/인덱스 무변경.

## non-null 전환 영향
`MasterMenuItemRepositoryImpl(` 호출부는 DI 1곳 + 위 테스트 1곳뿐. 테스트만 수정.

## 결과
- flutter analyze: No issues found
- flutter test: 921 전체 통과

## 테스트 포인트
- 점주가 override 없는 메뉴를 품절 처리 -> 생성된 menuOverrides 문서에 masterMenuItemId 존재, collectionGroup where 쿼리에 잡힘.
- 마스터 메뉴 삭제 -> 점주 생성분 포함 모든 매장 override 가 cascade 삭제됨.

## 관찰 (기존 공백, 이번 비범위)
`countStoresUsingPriceOverride` 의 복합 [masterMenuItemId, status] 인덱스가 indexes.json 에 없음.
