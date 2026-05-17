# sub-phase 7 — menu_option_group_management 테스트 리포트

> **검증 일자**: 2026-05-03
> **검증 유형**: 정적 코드 검증 (Static Analysis)
> **검증자**: Tester Agent

---

## 요약

| 분류 | 건수 |
|---|---|
| PASS | 26 |
| FAIL | 4 |
| 보류 | 6 |

---

## FAIL 항목 (우선순위 순)

---

### FAIL-1. MasterMenuFormPage OptionGroupSelector에 brandGroups 미전달

**우선순위**: P1 (기능 핵심 누락)

**문제**:
`MasterMenuFormPage` 의 `OptionGroupSelector` 호출 시 `optionGroups`(master) 만 전달하고 `brandGroups` 를 전달하지 않는다. 결과적으로 brand 옵션 그룹이 selector UI 에 전혀 노출되지 않는다.

spec 결정 6 및 결정 8에서 MasterMenuFormPage 는 `master ∪ brand` 머지 노출을 요구하며, design.md C2에서도 동일하게 명세한다.

**위치**:
- `lib/presentation/brand/master_menu/master_menu_form_page.dart` L499~506
- `lib/presentation/brand/providers/brand_master_menu_providers.dart` L84~89 (`brandMasterOptionGroupsProvider` 가 master 만 fetch)

**현재 코드**:
```dart
OptionGroupSelector(
  optionGroups: ref
      .watch(brandMasterOptionGroupsProvider)
      .asData
      ?.value ?? [],
  selectedIds: _selectedOptionGroupIds,
  onChanged: (ids) => setState(() => _selectedOptionGroupIds = ids),
),
```
`brandGroups` 파라미터 미전달. `brandMasterOptionGroupsProvider` 는 legacy master 만 fetch.

**`_buildOptionGroupRefs`는 submit 시 brand scope 판별 로직이 있으나** (L149~158), UI 에서 brand 그룹을 선택할 수 없으므로 사실상 dead code가 된다.

**제안 수정 방향**:
1. brand 옵션 그룹을 가져오는 provider (`brandOptionGroupsActiveByIdProvider(brandId)`) 를 `build()` 에서 watch
2. `OptionGroupSelector` 에 `brandGroups:` 파라미터 전달
3. `brandMasterOptionGroupsProvider` 는 master fetch 전용으로 유지하거나 통합 provider 로 교체

---

### FAIL-2. BrandStoreOnlyMenuFormPage OptionGroupSelector 미통합

**우선순위**: P1 (spec 명시 요구사항 미이행)

**문제**:
spec 결정 6 및 스펙 문서 화면 영향 범위에서 `BrandStoreOnlyMenuFormPage` 는 "selector 신규 통합" 이 본 phase 의 명시적 작업 항목이다. design.md C3 에서도 동일하게 명세한다. 그러나 현재 코드에는 `OptionGroupSelector` 위젯이 없고, `optionGroupRefs` 를 단순 보존만 한다.

**위치**:
- `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart` L184
- `OptionGroupSelector` import, widget 사용 없음

**현재 코드 (L184)**:
```dart
optionGroupRefs: (widget.editItem ?? widget.sourceForClone)?.optionGroupRefs ?? [],
```
selector 없이 기존 값을 그대로 pass-through.

**제안 수정 방향**:
1. `_selectedOptionGroupIds` 상태 변수 추가
2. `brandMasterOptionGroupsProvider` (master) + `brandOptionGroupsActiveByIdProvider(brandId)` (brand) watch
3. `OptionGroupSelector(masterGroups: ..., brandGroups: ...)` 위젯 삽입
4. submit 시 `_buildOptionGroupRefs` 로 scope 판별하여 `optionGroupRefs` 구성

**implementation.md 자체 인정**: `'BrandStoreOnlyMenuFormPage selector 통합 — 일부 미완성 가능성'` 으로 명시.

---

### FAIL-3. countUsage — collectionGroup 중복 쿼리 (brandCount + storeCount 중복 합산)

**우선순위**: P2 (기능 오동작)

**문제**:
`OptionGroupRemoteDataSource.countUsage()` 에서 `FirestorePaths.brandMenuItems` 와 `FirestorePaths.menuItems` 를 각각 `collectionGroup` 쿼리하여 결과를 합산한다. 그러나 두 상수 모두 `'menuItems'` 로 동일한 값이므로 Firestore `collectionGroup('menuItems')` 쿼리가 두 번 실행되어 결과가 2배로 합산된다.

Firestore `collectionGroup` 은 컬렉션 이름이 같으면 경로에 무관하게 `brands/{id}/menuItems` 와 `stores/{id}/menuItems` 를 한 번에 조회한다. 따라서 단일 쿼리로 충분하다.

**위치**:
- `lib/data/datasources/remote/option_group_remote_data_source.dart` L190~207
- `lib/core/constants/firestore_paths.dart` L11 (`brandMenuItems = 'menuItems'`) / L53 (`menuItems = 'menuItems'`)

**현재 코드 (L190~207)**:
```dart
final snap = await _firestore
    .collectionGroup(FirestorePaths.brandMenuItems)   // 'menuItems'
    .where('optionGroupRefIds', arrayContains: id)
    .count().get();
final brandCount = snap.count ?? 0;

final snap2 = await _firestore
    .collectionGroup(FirestorePaths.menuItems)         // 'menuItems' (동일)
    .where('optionGroupRefIds', arrayContains: id)
    .count().get();
final storeCount = snap2.count ?? 0;

return brandCount + storeCount; // 실제로는 동일 결과 × 2
```

**제안 수정 방향**:
두 번째 쿼리 제거. `collectionGroup('menuItems')` 단일 쿼리만 유지.
```dart
final snap = await _firestore
    .collectionGroup('menuItems')
    .where('optionGroupRefIds', arrayContains: id)
    .count().get();
return snap.count ?? 0;
```

---

### FAIL-4. OwnerStoreMenuRepositoryImpl S2-store 검증 미구현

**우선순위**: P2 (아키텍처 / 데이터 정합성)

**문제**:
spec 결정 8 에서 개인 매장 메뉴 repository upsert 시 `optionGroupRefs[scope ∈ {master, store}]` 만 허용하고, brand scope ref 를 차단하도록 명시한다. 그러나 `lib/data/repositories/menu_item_repository_impl.dart` 에는 해당 scope 검증 코드가 없다.

반면 `MasterMenuItemRepositoryImpl` 에는 `_assertOptionGroupRefsScope` 가 구현되어 있다.

**위치**:
- `lib/data/repositories/menu_item_repository_impl.dart` (전체 — 검증 메서드 없음)

**제안 수정 방향**:
`menu_item_repository_impl.dart` 의 upsert 관련 메서드(create/update)에 `_assertOptionGroupRefsScope` 추가:
```dart
void _assertOptionGroupRefsScope(MenuItemEntity item) {
  final hasBrandScope = item.optionGroupRefs.any(
    (r) => r.scope == OptionScope.brand,
  );
  if (hasBrandScope) {
    throw ArgumentError(
      '개인 매장 메뉴의 optionGroupRefs 는 master/store scope 만 허용됩니다.',
    );
  }
}
```

---

## PASS 항목

### Domain / Data 레이어

| # | 항목 | 파일 |
|---|---|---|
| P-01 | `OptionScope` enum: `master`(deprecated), `brand`(신규), `store` 3개 값 + `fromString`/`asString` 완성 | `lib/domain/entities/option_scope.dart` |
| P-02 | `OptionGroupEntity` 확장 필드: `active`, `brandId`, `storeId`, `createdAt`, `updatedAt` 모두 추가 | `lib/domain/entities/option_group_entity.dart` |
| P-03 | `OptionGroupRepository` 인터페이스: `watchByBrand`, `watchByStore`, `upsert`, `toggleActive`, `delete`, `findDuplicateName`, `countUsage` 모두 정의 | `lib/domain/repositories/option_group_repository.dart` |
| P-04 | `OptionGroupRepositoryImpl`: master scope upsert/delete/toggleActive 차단 (ArgumentError) | `lib/data/repositories/option_group_repository_impl.dart` |
| P-05 | `OptionGroupRemoteDataSource` brand/store 2-tier CRUD + findDuplicateName (normalized) + fetchAll | `lib/data/datasources/remote/option_group_remote_data_source.dart` |
| P-06 | `OptionGroupModel` 매핑 확장: `brandId`, `active`, `createdAt`, `updatedAt` + `toEntity`/`fromEntity`/`fromFirestore`/`toFirestore` | `lib/data/models/option_group_model.dart` |
| P-07 | `FirestorePaths` 확장: `brandOptionGroupsSubcollection`, `brandOptionGroupsPath` 신규 | `lib/core/constants/firestore_paths.dart` |
| P-08 | `UpsertOptionGroupUseCase`: submit 전 race-condition 방지 최종 중복 검사 + `DuplicateOptionGroupNameException` throw | `lib/domain/usecases/upsert_option_group_use_case.dart` |
| P-09 | 신규 UseCase 6개 모두 생성: Watch/Upsert/Toggle/Delete/FindDuplicateName/CountUsage | 각 use_case 파일 |
| P-10 | `DuplicateOptionGroupNameException`, `OptionGroupInUseException` 신규 exception 클래스 | `lib/core/errors/` |
| P-11 | `optionGroupRefIds` 평면 필드 동기화: `MenuItemModel.toFirestore()` 에서 `optionGroupRefs` ID 리스트 자동 생성 | `lib/data/models/menu_item_model.dart` L200~203 |
| P-12 | `OptionRepository` (read-only) customer 측: `getBrandOptionGroup` 추가, `getOptionGroupsForMenuItem` 에서 brand scope ref 처리 + active=false 제외 | `lib/data/repositories/option_repository_impl.dart` |

### Brand 본사 UI

| # | 항목 | 파일 |
|---|---|---|
| P-13 | `BrandMorePage` "옵션 그룹 관리" tile 추가 — `brandId != null` 가드, `Icons.tune_rounded` | `lib/presentation/brand/more/brand_more_page.dart` |
| P-14 | `BrandOptionGroupListPage`: displayOrder asc 정렬, shimmer loading, error retry, empty state, FAB, 카드 레이아웃 | `lib/presentation/brand/option_groups/brand_option_group_list_page.dart` |
| P-15 | `BrandOptionGroupListPage` active Switch 즉시 토글, SnackBar 피드백, 실패 시 원상복구 | 동일 |
| P-16 | `BrandOptionGroupListPage` `_UsageChip` (loading shimmer / 사용 중 N개 / 사용 없음), `_ItemCountChip`, `_SelectionTypeBadge`, `_RequiredMarker` | 동일 |
| P-17 | `BrandOptionGroupFormPage`: 이름 디바운스(300ms) 중복 검증 + inline 에러 "이미 같은 이름의 옵션 그룹이 있어요" | `lib/presentation/brand/option_groups/brand_option_group_form_page.dart` |
| P-18 | `BrandOptionGroupFormPage`: `_isDuplicateChecking` 가드 (`_canSave` 조건), race-condition UseCase 최종 차단 | 동일 |

### Owner 개인 매장 UI

| # | 항목 | 파일 |
|---|---|---|
| P-19 | `MyStorePage` "옵션 그룹 관리" CTA — `store.brandId == null` 가드 (가맹점 미노출) | `lib/presentation/owner/my_store/my_store_page.dart` L1134 |
| P-20 | `OwnerStoreOptionGroupListPage` / `OwnerStoreOptionGroupFormPage` 구조: brand 쪽과 동일 패턴, store scope 적용 | `lib/presentation/owner/option_groups/` |

### 공통 위젯

| # | 항목 | 파일 |
|---|---|---|
| P-21 | `OptionGroupDeleteDialog`: 사용 중 loading → 차단(N개 텍스트, "비활성으로 전환") / 삭제 가능("삭제") 분기 | `lib/presentation/common/widgets/option_groups/option_group_delete_dialog.dart` |
| P-22 | `OptionGroupDeleteDialog` 카피: "이 옵션 그룹을 사용 중인 메뉴가 {N}개 있어요.\n메뉴에서 먼저 제거해주세요." / "비활성으로 전환" 버튼 라벨 | 동일 |
| P-23 | `OptionItemListEditor`: 항목 동적 추가/삭제, label 중복 inline 에러 "같은 이름의 항목이 있어요", priceDelta 부호 토글 | `lib/presentation/common/widgets/option_groups/option_item_list_editor.dart` |
| P-24 | `OptionGroupSelector` 갱신: 섹션 헤더 카피 "기본 옵션" (master) / "브랜드 옵션" (brand) / "매장 옵션" (store) | `lib/presentation/brand/master_menu/widgets/option_group_selector.dart` L128~130 |

### 아키텍처 / 코드 품질

| # | 항목 | 결과 |
|---|---|---|
| P-25 | `flutter analyze` 0 issues | implementation.md 기재 + 재실행 확인 |
| P-26 | presentation / domain 레이어에 Firebase 직접 import 없음 — `cloud_firestore` import 는 data 레이어(`datasources/`, `repositories/`, `models/`)에만 한정 | 전수 확인 |

---

## 카피 일치 검증

| 항목 | spec/design 카피 | 코드 카피 | 결과 |
|---|---|---|---|
| BrandMorePage tile | "옵션 그룹 관리" | "옵션 그룹 관리" | PASS |
| MyStorePage tile | "옵션 그룹 관리" | "옵션 그룹 관리" | PASS |
| 섹션 헤더 — master | "기본 옵션" | "기본 옵션" | PASS |
| 섹션 헤더 — brand | "브랜드 옵션" | "브랜드 옵션" | PASS |
| 섹션 헤더 — store | "매장 옵션" | "매장 옵션" | PASS |
| 중복 이름 inline 에러 | "이미 같은 이름의 옵션 그룹이 있어요" | "이미 같은 이름의 옵션 그룹이 있어요" | PASS |
| 항목 label 중복 inline 에러 | "같은 이름의 항목이 있어요" | "같은 이름의 항목이 있어요" | PASS |
| inactive marker (selector) | "이 옵션 그룹은 비활성화되었습니다." | "이 옵션 그룹은 비활성화되었습니다." | PASS |
| DeleteDialog 차단 본문 | "이 옵션 그룹을 사용 중인 메뉴가 N개 있어요.\n메뉴에서 먼저 제거해주세요." | `'이 옵션 그룹을 사용 중인 메뉴가 $usageCount개 있어요.\n메뉴에서 먼저 제거해주세요.'` | PASS |
| DeleteDialog "비활성으로 전환" 버튼 | "비활성으로 전환" | "비활성으로 전환" | PASS |

---

## 보류 항목 (사용자 실기기 검증 필요)

| # | 항목 | 사유 |
|---|---|---|
| H-01 | Firestore `optionGroupRefIds` arrayContains 실제 동작 확인 | Firestore 인덱스 생성 여부, countUsage 실제 결과 (FAIL-3 수정 후) | 실기기 |
| H-02 | brand 옵션 그룹 selector UI 노출 (FAIL-1/FAIL-2 수정 후) | 마스터 메뉴 폼 + BrandStoreOnly 폼 에서 "브랜드 옵션" 섹션 노출 확인 | 수정 후 실기기 |
| H-03 | OwnerStoreMenuFormPage "기본 옵션" + "매장 옵션" 섹션 분리 노출 | `storeOptionGroupsProvider` / `masterOptionGroupsProvider` 실 데이터 연동 | 실기기 |
| H-04 | customer `MenuItemDetailPage` brand 가맹점 매장에서 brand scope 옵션 그룹 노출 | `OptionRepository.getOptionGroupsForMenuItem` brand 분기 실 Firestore 경로 동작 | 실기기 |
| H-05 | priceDelta 음수 저장 / 복원 round-trip | Firestore 저장 후 reload 시 음수 값 유지 확인 | 실기기 |
| H-06 | MyStorePage "옵션 그룹 관리" 버튼 위치 (design.md B1) | 현재 `_StoreTile` 대신 `OutlinedButton.icon` 구현. "메뉴 분류 관리" 아래 위치는 동일하나 위젯 형태가 다름. 시각적 일치 확인 필요 | 실기기 |

---

## 정적 검증 결과 vs 실기기 검증 분리

| 검증 항목 | 정적 | 실기기 |
|---|---|---|
| OptionScope enum 3개 값 | PASS | — |
| OptionGroupEntity 필드 확장 | PASS | — |
| Repository 책임 분리 (read-only / CRUD) | PASS | — |
| optionGroupRefIds 평면 필드 동기화 | PASS (코드) | H-01 |
| countUsage 중복 쿼리 버그 | FAIL-3 | — |
| S2 master/brand 허용 + store 차단 (MasterMenu) | PASS | — |
| S2 store (OwnerStore) 검증 미구현 | FAIL-4 | — |
| MasterMenuFormPage brandGroups 미전달 | FAIL-1 | — |
| BrandStoreOnlyMenuFormPage selector 미통합 | FAIL-2 | — |
| OwnerStoreMenuFormPage master ∪ store 머지 | PASS (코드) | H-03 |
| DeleteDialog 사용 중 차단 + 비활성화 전환 | PASS | — |
| active Switch 즉시 토글 (DeactivateConfirmDialog 없음) | PASS | — |
| 중복 이름 검증 (디바운스 + UseCase 최종 차단) | PASS | — |
| 항목 label 중복 client-side 차단 | PASS | — |
| priceDelta 음수 허용 부호 토글 UX | PASS (코드) | H-05 |
| AppColors 토큰만 사용 (하드코딩 없음) | PASS | — |
| Firebase import presentation 레이어 없음 | PASS | — |
| flutter analyze 0 issues | PASS | — |
| customer brand scope 옵션 read 경로 | PASS (코드) | H-04 |

---

## 후속 작업 후보

- **FAIL-1 수정 (P1)**: `MasterMenuFormPage` 에 `brandOptionGroupsActiveByIdProvider(brandId)` watch + `OptionGroupSelector(brandGroups:...)` 전달. `brandMasterOptionGroupsProvider` 승격 또는 병렬 provider 정리.
- **FAIL-2 수정 (P1)**: `BrandStoreOnlyMenuFormPage` 에 selector 통합 (별도 patch phase).
- **FAIL-3 수정 (P2)**: `countUsage` 단일 `collectionGroup('menuItems')` 쿼리로 교체.
- **FAIL-4 수정 (P2)**: `menu_item_repository_impl.dart` 에 `_assertOptionGroupRefsScope` 추가.
- Follow-up F3: 옵션 항목 reordering (drag-drop)
- Follow-up F4: 옵션 항목 단위 active toggle
- Follow-up F10: `applicableMainCategories` 자동 필터
- Follow-up F6: legacy master 시드 폐기 마이그레이션
- Follow-up F1: Firestore 보안 규칙
