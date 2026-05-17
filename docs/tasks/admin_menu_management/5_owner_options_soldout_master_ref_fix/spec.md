# sub-phase 5 patch — 브랜드 매장 마스터 ref 옵션 시트 빈 상태 버그 수정

> **상태**: APPROVED — architect 작성 완료
>
> **본 patch 의 위상**: sub-phase 5 (`5_owner_options_soldout`) 가 완료된 후 발견된 **버그 + 누락된 데이터 흐름** 을 보강하는 후속 작업. sub-phase 5 의 spec / design / implementation / test_report 와 결정사항(W4 옵션 fetch 단계 필터, W6 BottomSheet 구조, A/B/D 분기 등)은 그대로 유지하며, 본 patch 는 그 결정을 충족시키기 위해 빠진 데이터 흐름만 교체한다.
>
> **본 patch 가 별도 폴더로 분리된 이유**: sub-phase 1 patch (`1_brand_master_option_selector_patch/`) 와 동일 패턴. 원 sub-phase 5 의 spec.md 는 이미 767줄의 대형 단일 진실원이며, 본 패치는 1개 시트(`MenuOptionDisableSheet`) + 1개 provider 의 데이터 흐름만 좁게 교체하는 작업이라 별도 폴더로 분리해 추적 가능성을 높인다.
>
> **상위 단일 진실원**:
> - 데이터 모델 / 결정 1~12 / 결정 A~F / 결정 G~J → [`../spec.md`](../spec.md) (umbrella)
> - sub-phase 5 의 W4 (옵션 fetch 단계 필터), W6 (옵션 관리 BottomSheet), 분기 A/B/D, 권한 매트릭스, customer 즉시 반영 → [`../5_owner_options_soldout/spec.md`](../5_owner_options_soldout/spec.md)
> - sub-phase 1 patch 의 옵션 그룹 prefill (`optionGroupRefs` 가 마스터 ref 메뉴에 정상 저장됨을 보장) → [`../1_brand_master_option_selector_patch/spec.md`](../1_brand_master_option_selector_patch/spec.md)
>
> **이 patch 는 새 결정을 만들지 않는다.** 위의 단일 진실원을 그대로 따른다.

---

## 개요

- **목적**: 브랜드 매장 점주가 [`OwnerBrandStoreMenusPage`](../../../../lib/presentation/owner/brand_store/owner_brand_store_menus_page.dart) 에서 **마스터 ref 메뉴**의 옵션 관리 시트를 열 때 옵션 그룹이 정상적으로 표시되도록 데이터 흐름을 교체한다. 현재는 마스터 메뉴에 옵션 그룹이 정상적으로 묶여 있고 admin 승인까지 끝났음에도 시트가 항상 빈 상태("이 메뉴는 옵션이 없어요")를 표시한다.
- **작업 유형**: 버그 수정 (presentation 단계의 데이터 흐름 교체 — 시트가 잘못된 provider 를 watch 하고 있어서 마스터 ref 메뉴 케이스만 항상 null detail 로 떨어지는 문제 해결).

### 배경 / 누락 사실 / 정적 분석으로 확정된 원인

1. [`MenuOptionDisableSheet`](../../../../lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart#L191) 는 [`menuItemAllOptionGroupsProvider(MenuItemKey(storeId, menuItemId))`](../../../../lib/presentation/customer/order/menu/providers/menu_detail_providers.dart#L70) 를 watch 한다.
2. 그 provider 는 내부적으로 [`menuItemDetailProvider`](../../../../lib/presentation/customer/order/menu/providers/menu_detail_providers.dart#L52) 를 watch 해서 메뉴 detail 을 fetch 한 뒤, `detail` 이 null 이면 `const []` 를 반환하고 종료한다.
3. `menuItemDetailProvider` 는 [`WatchMenuItemDetailUseCase`](../../../../lib/domain/usecases/watch_menu_item_detail_use_case.dart) → [`MenuItemRepositoryImpl.watchById`](../../../../lib/data/repositories/menu_item_repository_impl.dart#L130) → [`MenuItemRemoteDataSource.streamById`](../../../../lib/data/datasources/remote/menu_item_remote_data_source.dart#L29) 를 거치는데, **`streamById` 는 `stores/{storeId}/menuItems/{menuItemId}` 경로만 본다**.
4. **마스터 ref 메뉴는 그 경로에 doc 자체가 없다.** 마스터 메뉴는 `brands/{brandId}/menuItems/{id}` 에 저장되고, 점주가 보는 마스터 ref 는 [`MenuItemRepositoryImpl._mergeForBrandStore`](../../../../lib/data/repositories/menu_item_repository_impl.dart#L75) 에서 master + override 머지로 만든 가상 entity 다 (case B 머지 결과).
5. 결과적으로 마스터 ref 메뉴에 대해 `menuItemDetailProvider` 가 항상 null 을 반환 → `menuItemAllOptionGroupsProvider` 의 `if (detail == null) return const [];` 분기 → 빈 배열 → 시트가 빈 상태 UI 를 표시.
6. 점포 한정 메뉴 (`stores/.../menuItems/{id}` 에 실제 doc 이 있는 케이스) 는 이 흐름이 정상 동작 → 영향 없음.

요약: **마스터 ref 메뉴만 영향 받는 버그.** 점포 한정 메뉴 / customer 측 메뉴 상세는 문제 없음.

### 해결 방향 (사용자가 결정 — A안)

**A안 — 시트가 `widget.menuItem` 의 `optionGroupRefs` 를 직접 사용**

- 시트는 부모(`OwnerBrandStoreMenusPage`)로부터 이미 case B 머지 결과인 `widget.menuItem` (`MenuItemEntity`) 을 받고 있다. 그 entity 의 `optionGroupRefs` 는 마스터 ref 의 경우 `[{scope:'master', id:'og_xxx'}, ...]` 로 정상 저장되어 있다 (sub-phase 1 patch 로 정상 저장 보장).
- **이 entity 를 그대로 신뢰하고**, `OptionRepository.getOptionGroupsForMenuItem(entity)` 를 직접 호출해서 옵션 그룹들을 fetch 하도록 교체한다.
- 핵심: provider chain 의 `menuItemDetailProvider` 의존을 끊는다 — 시트 한정.

**기각된 안 — B안 (`streamById` 가 brand master 도 조회하도록 분기)**: 영향 범위 너무 큼. customer 측 메뉴 상세 화면 / `menuItemDetailProvider` 를 watch 하는 모든 곳에 영향. 본 patch 비범위 (아래 비범위 참조).

---

## 영향 범위

- **화면 / Widget**: `MenuOptionDisableSheet` 1개. 다른 시트 호출처 (`OwnerStoreMenuListPage`, `OwnerStoreMenuDetailPage`, `OwnerBrandStoreMenusPage`) 의 호출 시그니처는 변경 없음 (`storeId` / `menuItem` / `menuType` / `existingOverride` 그대로 전달).
- **Provider / 상태 관리**: 신규 provider 1개 추가 + 시트의 watch 대상 교체. customer 측 `menuItemAllOptionGroupsProvider` / `menuItemOptionGroupsProvider` / `menuItemDetailProvider` **변경 없음** (다른 화면이 사용 중).
- **Domain Entity**: 변경 없음.
- **UseCase**: 변경 없음. 기존 `GetOptionGroupsForMenuItemUseCase` / `OptionRepository.getOptionGroupsForMenuItem` 재사용.
- **Repository Interface**: 변경 없음.
- **DataSource**: 변경 없음.
- **DTO / Model**: 변경 없음.
- **Repository Implementation**: 변경 없음.
- **Firebase / API 구조**: 변경 없음.
- **공통 컴포넌트**: `MenuOptionDisableSheet` (위치는 `presentation/common/option_disable_sheet/` — 변경 없음).
- **라우팅**: 변경 없음.
- **권한 / 환경 설정**: 변경 없음.
- **테스트**: 마스터 ref 메뉴 옵션 시트 정상 동작 + 점포 한정 메뉴 회귀 + customer 메뉴 상세 회귀.

---

## 비범위

- **`streamById` / `MenuItemRepository.watchById` 자체를 brand master 도 조회하도록 분기하는 변경** — 영향 범위 큼. customer 측 메뉴 상세 화면 / 상위 provider chain (`menuItemOptionGroupsProvider` / `menuItemCurrentPriceProvider` / `menuItemAddToCartReadyProvider` / `menuItemMissingRequiredGroupsProvider`) 에 직접 영향. 별도 phase 또는 후속 작업.
- **customer 측 `menuItemAllOptionGroupsProvider` / `menuItemOptionGroupsProvider` 자체 수정** — customer 메뉴 상세 화면은 별도 흐름이며 (storeId 가 실제 매장 doc 이 있는 매장이라 영향 없음), 별도 검증 후 결정.
- **옵션 그룹 CRUD UI** — sub-phase 7 (별도 phase `admin_option_group_management`).
- **시트의 디자인 / UI / 마이크로카피 변경** — 변경 없음. 빈 상태 / 로딩 / 에러 UI 모두 기존 그대로 유지.
- **`OwnerBrandStoreMenusPage` / `OwnerStoreMenuListPage` / `OwnerStoreMenuDetailPage` 등 호출처 코드** — 변경 없음.

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - sub-phase 5 (`5_owner_options_soldout`) 완료 — `MenuOptionDisableSheet` 시트 위젯 / save UseCase / case B 머지 / brandMasterRef vs personal 분기 모두 구현 완료.
  - sub-phase 1 patch (`1_brand_master_option_selector_patch`) 완료 — 마스터 메뉴에 `optionGroupRefs` 가 정상 저장되어야 본 patch 의 검증이 가능. (현재 완료 상태로 보고 됨)
- **진입 조건**:
  - 마스터 메뉴 1건 이상 + 옵션 그룹 1건 이상 묶여서 admin 승인 완료.
  - 같은 brandId 의 매장 1개 + 점주 계정 + 매장 admin 승인 완료.
  - Firestore `brands/{brandId}/menuItems/{id}.optionGroupRefs` 에 `[{scope:'master', id}, ...]` 가 실제로 들어 있어야 함.

---

## 요구사항

### 기능 요구사항

- [ ] 브랜드 매장 점주가 `OwnerBrandStoreMenusPage` → 마스터 ref 메뉴 카드의 옵션 관리 진입 시 시트에 해당 메뉴의 옵션 그룹들이 정상 표시된다.
- [ ] 시트는 `widget.menuItem.optionGroupRefs` 를 입력으로 받아 `OptionRepository.getOptionGroupsForMenuItem(menuItem)` 으로 옵션 그룹을 fetch 한다.
- [ ] 시트는 `menuItemDetailProvider` / `menuItemAllOptionGroupsProvider` 에 의존하지 않는다 — provider chain 의 `streamById` 경로 의존을 완전히 끊는다.
- [ ] 점포 한정 메뉴 (`MenuItemScope.store`, brandId == null 또는 brandId != null 모두) 의 옵션 시트 동작이 회귀 없이 동작한다.
- [ ] 개인 매장 메뉴의 옵션 시트 동작이 회귀 없이 동작한다.
- [ ] 시트의 비활성/활성 토글 (`_onGroupToggle` / `_onItemToggle` / `_callSaveUseCase`) 동작은 기존과 동일.
- [ ] 시트는 제출 후 옵션 그룹 데이터를 다시 fetch 하지 않는다 — 토글은 optimistic update 로 처리되며 옵션 그룹 자체는 메뉴 진입 시점 1회만 fetch (sub-phase 5 결정 그대로).
- [ ] customer 측 메뉴 상세 (`MenuItemDetailPage`) / `menuItemDetailProvider` 를 watch 하는 모든 화면은 변경 없이 그대로 동작.

### UI 요구사항

- [ ] **시트 외형 변경 없음** — 헤더 / 그룹 row / 항목 row / 빈 상태 / 로딩 / 에러 UI 모두 sub-phase 5 결정 그대로.
- [ ] 빈 상태 (`_EmptyBody`) — `widget.menuItem.optionGroupRefs` 가 비어 있거나 fetch 결과가 빈 배열이면 기존 빈 상태 UI 그대로 표시.
- [ ] 로딩 상태 — 옵션 그룹 fetch 중 `CircularProgressIndicator` 표시 (기존 그대로).
- [ ] 에러 상태 (`_ErrorBody`) — fetch 실패 시 "옵션을 불러오지 못했어요" + 재시도 버튼. 재시도는 새 provider 또는 시트 내부 fetch 를 invalidate.

### 상태 요구사항

- [ ] **loading**: `AsyncLoading` (옵션 그룹 fetch 중) — 기존 UI 그대로.
- [ ] **error**: `AsyncError` — 기존 UI 그대로 + 재시도 가능.
- [ ] **empty**: 옵션 그룹 0건 — 기존 빈 상태 UI 그대로. (점포 한정 메뉴 / 마스터 ref 메뉴 모두 동일한 카피 분기 — `menuType` 에 따라 카피 분기는 기존 로직 그대로.)

---

## 데이터 모델

변경 없음.

- `MenuItemEntity.optionGroupRefs: List<OptionGroupRef>` — 그대로 사용.
- `OptionGroupRef({required OptionScope scope, required String id})` — 그대로.
- `OptionScope { master, store }` — 그대로.
- `MenuItemEntity.disabledOptionGroupIds` / `disabledOptionItemIds` — 그대로 (시트의 토글 입력값).
- `MenuOverrideEntity.disabledOptionGroupIds` / `disabledOptionItemIds` — 그대로 (브랜드 마스터 ref 의 override 저장 입력값).

---

## 레이어 설계

### Domain

변경 없음.

- `OptionRepository.getOptionGroupsForMenuItem(MenuItemEntity, {disabledGroupIds, disabledItemIds})` — 기존 그대로 사용.
- `GetOptionGroupsForMenuItemUseCase` — 기존 그대로 (다만 자동으로 비활성 필터를 적용하므로 시트 한정에는 부적합. 본 patch 는 `OptionRepository` 직접 호출 또는 신규 단순 호출 경로 채택. 아래 결정 X 참조).

### Data

변경 없음. `OptionRepositoryImpl.getOptionGroupsForMenuItem` 그대로 사용.

### Presentation

#### 결정 X — provider 위치 / 이름 / 입력 타입

**위치 결정**: 시트 전용 provider 를 [`lib/presentation/customer/order/menu/providers/menu_detail_providers.dart`](../../../../lib/presentation/customer/order/menu/providers/menu_detail_providers.dart) 에 **추가하지 않는다.** 시트 위치인 [`lib/presentation/common/option_disable_sheet/`](../../../../lib/presentation/common/option_disable_sheet/) 트리에 신규 파일 `menu_option_disable_sheet_providers.dart` 를 생성한다.

- **이유**:
  1. customer/order/menu/providers 트리는 customer 메뉴 상세 화면 전용 — 시트는 owner 트리에서 호출됨. 트리 경계가 다름.
  2. 시트가 `presentation/common/option_disable_sheet/` 에 있으므로 같은 디렉토리에 같은 단일 책임 provider 를 두는 게 응집도 ↑.
  3. 향후 sub-phase 7 (옵션 그룹 CRUD) 에서 시트가 점차 확장되면 같이 이동하기 좋음.
  4. customer 측 `menuItemAllOptionGroupsProvider` 는 그대로 유지 — 다른 화면에서 사용 가능성 + 마이그레이션 비용 회피.

**provider 이름**: `optionGroupsForMenuItemEntityProvider`. 입력 타입 `MenuItemEntity` 자체. (또는 `OptionGroupsForMenuItemEntityKey` 라는 별도 key 타입을 만들지 여부는 아래 결정 Y 에서 결론.)

**reasoning**:
- "Entity 를 직접 입력으로 받음" 을 이름에 명시 → 기존 `MenuItemKey(storeId, menuItemId)` 기반 provider 와 명확히 구분.
- prefix `option` 으로 시작해 옵션 도메인이라는 점 노출.

#### 결정 Y — family key 타입

`MenuItemEntity` 는 freezed 라 `==` / `hashCode` 자동 구현 → family key 로 그대로 사용 가능.

**선택지**:
- (Y1) `FutureProvider.family<List<OptionGroupEntity>, MenuItemEntity>` — entity 자체를 key.
- (Y2) `FutureProvider.family<List<OptionGroupEntity>, OptionGroupsForMenuItemEntityKey>` — `(menuItemId, optionGroupRefs)` 만 키로 쓰는 별도 key 타입.
- (Y3) provider 안 쓰고 시트 안에서 `useMemoized` + `useFuture` (flutter_hooks 사용 중인지 확인 필요) 또는 `FutureBuilder` 직접.

**architect 추천: Y1**

- 이유:
  1. `MenuItemEntity` 가 freezed 라 entity 단위 캐싱 가능.
  2. 시트 동안 메뉴가 외부에서 갱신되더라도(다른 toggling 으로 entity 가 재생성) 시트 내부 fetch 는 한번이면 충분. 부모 화면이 `optimisticSoldOut` 등으로 entity copy 를 새로 만들면 cache miss 가 일어나는 문제는 있으나, 시트 진입 시점의 entity 그대로 사용하므로 영향 없음 (시트 내부에서 menuItem 을 다시 watch 하지 않음).
  3. (Y2) 의 별도 key 타입은 추가 보일러플레이트 비용. (Y3) 는 provider chain 일관성 깨짐.
- **단점 보완**: family 의 cache leak 우려 — provider 를 watch 하는 시트가 닫히면 자동으로 cache 정리됨 (Riverpod 기본 동작 + autoDispose). 명시적으로 `.autoDispose` 적용 권장.

#### 신규 Provider — `optionGroupsForMenuItemEntityProvider`

```dart
// lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart (신규)

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/data/repositories/option_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/option_repository.dart';

// ── DI (시트 한정) ────────────────────────────────────────────────────────
//
// customer 측 menu_detail_providers.dart 의 _optionRemoteDataSourceProvider /
// optionRepositoryProvider 와 동일 인스턴스를 공유할 필요는 없음 (각각 stateless).
// 단일 사용처라 시트 트리에 둠.
final _sheetOptionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

final _sheetOptionRepositoryProvider = Provider<OptionRepository>(
  (ref) => OptionRepositoryImpl(ref.watch(_sheetOptionRemoteDataSourceProvider)),
);

// ── 옵션 그룹 fetch (entity 직접 입력) ────────────────────────────────────
//
// 시트 한정. menuItemDetailProvider 의존을 끊는다.
// disabled 필터는 적용하지 않고 전체 그룹/항목을 반환 — 시트는 모든 옵션을 토글 가능하게 표시.
// (sub-phase 5 의 menuItemAllOptionGroupsProvider 와 동등한 의미 — disabled 필터 없음)
final optionGroupsForMenuItemEntityProvider = FutureProvider.autoDispose
    .family<List<OptionGroupEntity>, MenuItemEntity>((ref, menuItem) async {
  if (menuItem.optionGroupRefs.isEmpty) return const [];
  return ref.watch(_sheetOptionRepositoryProvider).getOptionGroupsForMenuItem(
        menuItem,
        // 시트는 모든 옵션을 표시 후 토글하므로 disabled 필터 미적용.
        disabledGroupIds: const {},
        disabledItemIds: const {},
      );
});
```

> **명시적 결정**: `getOptionGroupsForMenuItem` 호출 시 `disabledGroupIds: const {}` / `disabledItemIds: const {}` 를 전달해 **filter 미적용** — 이는 sub-phase 5 의 `menuItemAllOptionGroupsProvider` 의도 ("점주가 비활성한 항목도 시트에서는 보여서 다시 활성화 가능") 와 동일. `GetOptionGroupsForMenuItemUseCase` 는 entity 의 disabled 필드를 자동 적용하므로 시트에서 직접 호출해서는 안 된다.

#### 수정 Widget — `MenuOptionDisableSheet`

[`lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart`](../../../../lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart) 에 다음 변경을 가한다.

##### 변경 1. import 교체

기존:
```dart
import 'package:qradar/presentation/customer/order/menu/providers/menu_detail_providers.dart' show MenuItemKey, menuItemAllOptionGroupsProvider;
```

신규:
```dart
import 'package:qradar/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart';
```

> `MenuItemKey` import 도 함께 제거 (시트 안에서 더 이상 사용하지 않음).

##### 변경 2. build() 의 watch 대상 교체

기존:
```dart
final key = MenuItemKey(
  storeId: widget.storeId,
  menuItemId: widget.menuItem.id,
);
final groupsAsync = ref.watch(menuItemAllOptionGroupsProvider(key));
```

신규:
```dart
final groupsAsync =
    ref.watch(optionGroupsForMenuItemEntityProvider(widget.menuItem));
```

##### 변경 3. 에러 상태의 retry 콜백 교체

기존:
```dart
error: (err, st) => _ErrorBody(
  onRetry: () => ref.invalidate(menuItemAllOptionGroupsProvider(key)),
),
```

신규:
```dart
error: (err, st) => _ErrorBody(
  onRetry: () => ref.invalidate(
      optionGroupsForMenuItemEntityProvider(widget.menuItem)),
),
```

##### 변경 4. (선택) 옵션 그룹 0건 fast path

`widget.menuItem.optionGroupRefs.isEmpty` 인 경우 provider 가 fetch 없이 즉시 빈 배열을 반환하므로 별도 fast path 코드는 불필요. provider 안에 이미 가드 포함됨.

#### 수정하지 않는 항목

- `MenuOptionDisableSheet` 의 시트 외형 / 헤더 / 그룹 row / 항목 row / 빈 상태 / 에러 UI / 토글 핸들러 / `_callSaveUseCase` — 변경 없음.
- 호출처 `OwnerBrandStoreMenusPage` / `OwnerStoreMenuListPage` / `OwnerStoreMenuDetailPage` — 변경 없음.
- customer 측 `menu_detail_providers.dart` 의 `menuItemAllOptionGroupsProvider` / `menuItemOptionGroupsProvider` / `menuItemDetailProvider` / 그 하위 모든 provider — 변경 없음.
- customer 측 `MenuItemDetailPage` — 변경 없음.
- `MenuItemRepository` / `MenuItemRepositoryImpl.streamById` / `MenuItemRemoteDataSource.streamById` — 변경 없음.

---

## 데이터 흐름

### 변경 후 — 마스터 ref 메뉴 옵션 시트 진입 (정상 동작)

```text
OwnerBrandStoreMenusPage
  → _BrandStoreMenuCard._openOptionSheet
  → showModalBottomSheet → MenuOptionDisableSheet(menuItem=masterRefEntity)
  → ref.watch(optionGroupsForMenuItemEntityProvider(widget.menuItem))
  → OptionRepository.getOptionGroupsForMenuItem(entity, disabled: const {})
  → entity.optionGroupRefs 순회:
    - scope == master → OptionRemoteDataSource.getMaster(id) → optionGroups/{id} 읽기
    - scope == store  → OptionRemoteDataSource.getStore(storeId, id) → stores/{storeId}/optionGroups/{id} 읽기
  → List<OptionGroupEntity>
  → 시트가 그룹 + 항목 토글 UI 렌더
```

### 변경 후 — 점포 한정 메뉴 옵션 시트 진입 (회귀 없음 — 동일 흐름)

```text
OwnerBrandStoreMenusPage 또는 OwnerStoreMenuListPage
  → showModalBottomSheet → MenuOptionDisableSheet(menuItem=storeOnlyEntity)
  → ref.watch(optionGroupsForMenuItemEntityProvider(widget.menuItem))
  → 동일 fetch 흐름. entity.optionGroupRefs 가 store scope 면 store 컬렉션 fetch.
```

### 변경 전 (버그) — 마스터 ref 케이스만 비교용

```text
showModalBottomSheet → MenuOptionDisableSheet
  → ref.watch(menuItemAllOptionGroupsProvider(MenuItemKey(storeId, menuItemId)))
  → ref.watch(menuItemDetailProvider(key)).future
  → WatchMenuItemDetailUseCase
  → MenuItemRepository.watchById
  → MenuItemRemoteDataSource.streamById  ← 여기서 stores/{storeId}/menuItems/{id} 만 본다
  → 마스터 ref 메뉴는 그 경로에 doc 없음 → null
  → menuItemAllOptionGroupsProvider: detail == null → return const []
  → 시트가 빈 상태 표시 ← 버그
```

### 변경 후 — 토글 저장 흐름 (변경 없음)

```text
사용자 토글 → optimistic update (setState) → _callSaveUseCase
  - menuType == personal → updateDisabledOptionsForPersonalMenuUseCase
  - menuType == brandMasterRef → updateDisabledOptionsForOverrideUseCase
  → Repository upsert/update → Firestore
  → 실패 시 prev 값으로 원복 + showErrorDialog
```

토글 저장 흐름은 `widget.menuItem` 의 disabled 필드 + `widget.existingOverride` 를 입력으로 받으므로 본 patch 의 영향 없음.

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| `optionGroupsForMenuItemEntityProvider` 로딩 중 | `CircularProgressIndicator(color: AppColors.primary)` (기존 그대로) |
| `optionGroupsForMenuItemEntityProvider` 에러 (네트워크) | `_ErrorBody` 표시 + 재시도 버튼 → `ref.invalidate` (기존 패턴, 신규 provider 키로 변경) |
| `widget.menuItem.optionGroupRefs` 가 빈 배열 | provider 안에서 `const []` 즉시 반환 → `_EmptyBody` 표시 ("이 메뉴는 옵션이 없어요") |
| fetch 결과가 빈 배열 (옵션 그룹 doc 들이 모두 삭제됨) | `_EmptyBody` 표시 (위와 동일) |
| 부분 실패 (일부 그룹 doc 만 삭제됨) | `OptionRepositoryImpl` 가 null 인 항목을 `whereType<OptionGroupEntity>()` 로 걸러내므로 살아있는 그룹만 표시 (기존 동작 그대로) |
| customer 측 메뉴 상세 진입 시 `menuItemDetailProvider` null | 본 patch 영향 없음 (별도 흐름 — customer 매장의 store-only 메뉴 정상 흐름) |

---

## 작업 분배

### designer 호출 — **불필요 (생략)**

**근거**:
- UI 외형 변경 0. 시트의 헤더 / 그룹 row / 항목 row / 빈 상태 / 로딩 / 에러 UI 모두 sub-phase 5 결정 그대로 유지.
- 마이크로카피 변경 0.
- 색상 / 레이아웃 / 토큰 변경 0.
- 본 patch 는 presentation 레이어의 데이터 흐름 (provider chain) 만 교체하는 작업.
- sub-phase 5 의 design.md 가 이미 시트의 모든 UI 상태를 정의함 → 추가 디자인 산출물 없음.

CLAUDE.md / architect_guide.md 의 작업 분배 표에서 **"기존 화면의 로직만 변경 → developer"** 케이스에 정확히 해당. designer 생략.

### developer 호출 — **다음 단계 (직행)**

설계 완료 후 즉시 호출.

- **구현 항목 (의존 순서)**:
  1. `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart` 신규 생성:
     - `_sheetOptionRemoteDataSourceProvider` (Provider<OptionRemoteDataSource>)
     - `_sheetOptionRepositoryProvider` (Provider<OptionRepository>)
     - `optionGroupsForMenuItemEntityProvider` (FutureProvider.autoDispose.family<List<OptionGroupEntity>, MenuItemEntity>)
  2. `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart` 수정:
     - import 교체 (위 변경 1)
     - build() 의 watch 대상 교체 (위 변경 2)
     - error 상태 retry 콜백 교체 (위 변경 3)
  3. `flutter analyze` 0 issue.
- **재사용할 기존 구조**:
  - `OptionRepository.getOptionGroupsForMenuItem` 시그니처 + `OptionRepositoryImpl` 구현 — 그대로 사용.
  - `OptionRemoteDataSource` — 그대로 사용.
  - 시트 토글 핸들러 (`_onGroupToggle` / `_onItemToggle` / `_callSaveUseCase`) — 변경 없음.
- **주의할 레이어 규칙**:
  - 신규 provider 파일은 presentation 레이어 — `OptionRemoteDataSource` (data) / `OptionRepositoryImpl` (data) 직접 import 가능. 단, presentation → domain 경유는 `OptionRepository` interface 만 노출하도록 `Provider<OptionRepository>` 타입 명시 (DI 패턴 일관성).
  - 시트 위젯은 신규 provider 만 watch — `MenuItemKey` / `menuItemAllOptionGroupsProvider` / `menuItemDetailProvider` 직접 import 절대 금지.
  - `widget.menuItem.optionGroupRefs` 가 본 patch 의 단일 진실원 — 부모(`OwnerBrandStoreMenusPage`)가 case B 머지 결과 entity 를 그대로 전달하므로 이 entity 를 신뢰.
  - `GetOptionGroupsForMenuItemUseCase` 는 disabled 자동 필터를 적용하므로 **시트에서 사용 금지**. 시트는 `OptionRepository.getOptionGroupsForMenuItem` 을 직접 호출 + `disabled` 빈 set 전달.
- **build_runner 영향**: 없음 (freezed/json_serializable 갱신 없음).

### tester 호출

developer 완료 후. `test_report.md` 작성.

---

## 검증 항목 (tester 가 확인할 PASS/FAIL 후보)

### 신규 기능

- [ ] **마스터 ref 메뉴 옵션 시트 정상 표시 (핵심 PASS)**: 브랜드 매장 점주가 `OwnerBrandStoreMenusPage` → 옵션 그룹이 묶인 마스터 ref 메뉴 카드의 옵션 관리 (tune 아이콘) 진입 → 시트에 모든 옵션 그룹 + 항목이 표시된다 (빈 상태 아님).
- [ ] **마스터 ref 메뉴 옵션 토글 → override upsert + customer 즉시 반영**: 시트에서 옵션 그룹/항목 토글 → `stores/{storeId}/menuOverrides/{masterMenuItemId}` doc 의 `disabledOptionGroupIds` / `disabledOptionItemIds` 갱신 → customer 메뉴 상세에서 비활성된 옵션이 보이지 않음 (sub-phase 5 W4 회귀).
- [ ] **마스터 ref 메뉴 옵션 그룹 0건**: 옵션 그룹이 묶이지 않은 마스터 ref 메뉴 진입 → 빈 상태 ("이 메뉴는 옵션이 없어요" + brandMasterRef 카피) 표시.
- [ ] **fetch 에러**: 네트워크 차단 후 시트 진입 → 에러 UI + 재시도 버튼 → 재시도 시 정상 fetch.

### 회귀 (sub-phase 5 / 4 / 3 / 1 무영향)

- [ ] **점포 한정 메뉴 옵션 시트 (브랜드 매장 분기)**: 브랜드 매장의 store scope 메뉴 → 옵션 시트 정상 표시 + 토글 → `stores/{storeId}/menuItems/{id}` partial update 정상.
- [ ] **점포 한정 메뉴 옵션 시트 (개인 매장 분기)**: 개인 매장 (brandId == null) 메뉴 → 옵션 시트 정상 표시 + 토글 정상.
- [ ] **customer 메뉴 상세 회귀**: 고객이 매장 메뉴 상세 진입 → 옵션 그룹 표시 정상 + 옵션 선택 가능 + 가격 합계 정상 + "담기" 버튼 활성/비활성 정상 (`menuItemDetailProvider` / `menuItemOptionGroupsProvider` / `menuItemCurrentPriceProvider` / `menuItemAddToCartReadyProvider` / `menuItemMissingRequiredGroupsProvider` 모두 변경 없음).
- [ ] **점주 품절 토글 회귀 (sub-phase 5)**: 시트와 무관하지만 카드 인라인 품절 토글 동작 정상.
- [ ] **sub-phase 1 patch 무영향**: 마스터 메뉴 등록/수정/복제 + 옵션 그룹 다중 선택 + status=pending 회귀 동작 그대로.
- [ ] **`flutter analyze`**: 0 issue.
- [ ] **import 정리**: `menu_option_disable_sheet.dart` 에서 `menu_detail_providers.dart` import 완전히 제거 (사용하지 않는 `MenuItemKey` / `menuItemAllOptionGroupsProvider` import 잔존 금지).

### 사용자 실기기 검증 (수동)

- [ ] **시나리오 1 — 마스터 ref 메뉴 옵션 토글 → customer 반영**:
  1. brand 계정으로 마스터 메뉴 (예: "아메리카노") 등록 + 옵션 그룹 (예: "샷 추가" / "시럽") 묶기 → admin 승인.
  2. owner 계정으로 같은 brand 의 매장 진입 → `OwnerBrandStoreMenusPage` → 마스터 ref 메뉴 카드의 tune 아이콘 탭.
  3. **시트가 옵션 그룹 + 항목을 정상 표시**해야 함 (현재 버그: 빈 상태). ← **본 patch 의 핵심 검증**
  4. 시럽 그룹 비활성 토글 → optimistic update 즉시 반영.
  5. customer 계정으로 같은 매장 메뉴 상세 진입 → "시럽" 그룹이 보이지 않음 (즉시 반영).
  6. owner 가 다시 활성 토글 → customer 즉시 복원.
- [ ] **시나리오 2 — 점포 한정 메뉴 옵션 토글 (회귀)**:
  1. owner 계정으로 같은 매장에서 점포 한정 추가 메뉴 (예: "지점 한정 라떼") + 옵션 그룹 묶기 → admin 승인.
  2. tune 아이콘 탭 → 시트가 정상 표시 (회귀 없음).
  3. 토글 → 즉시 반영.
- [ ] **시나리오 3 — 개인 매장 메뉴 옵션 토글 (회귀)**:
  1. brandId==null 매장 점주로 메뉴 + 옵션 그룹 등록.
  2. `OwnerStoreMenuListPage` → tune → 시트 정상 표시.
- [ ] **시나리오 4 — customer 메뉴 상세 회귀**:
  1. customer 계정으로 매장 메뉴 상세 진입.
  2. 옵션 선택 / 수량 / 가격 합계 / "담기" 버튼 활성 — 모두 정상.

---

## 사용자 확인이 필요한 결정사항

architect 가 확정한 항목 — 변경 의견이 있으면 사용자가 갱신.

1. **provider 위치**: `presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart` 신규 생성 (architect 결정). customer 트리에 추가하지 않음. → **architect 결정 — 사용자 검토**.
2. **provider 이름**: `optionGroupsForMenuItemEntityProvider` (architect 결정). 대안: `sheetOptionGroupsProvider` / `menuItemOptionGroupsByEntityProvider`. → **architect 결정 — 사용자 검토**.
3. **family key 타입**: `MenuItemEntity` 자체 (Y1). freezed 의 `==` 활용. → **architect 결정 — 사용자 검토**.
4. **autoDispose 적용**: `FutureProvider.autoDispose.family` 적용 (시트 닫히면 자동 정리). → **architect 결정**.
5. **disabled 필터 미적용**: 시트는 모든 옵션을 표시 후 토글하므로 필터 미적용 (sub-phase 5 결정 그대로). → **sub-phase 5 결정 그대로**.
6. **designer 호출 여부**: 생략 (UI 외형 변경 0). → **architect 결정 — 사용자 검토**.

---

## 완료 기준

- [ ] `spec.md` (본 문서) 확정
- [ ] `design.md` — **생략 (UI 변경 없음 — architect 가 명시)**
- [ ] `implementation.md` 작성 완료 (developer)
- [ ] `test_report.md` 작성 완료 (tester) — PASS 또는 보류 사유 명시
- [ ] 마스터 ref 메뉴 옵션 시트 정상 표시 (사용자 시나리오 1 PASS)
- [ ] 점포 한정 메뉴 옵션 시트 회귀 0 (사용자 시나리오 2/3 PASS)
- [ ] customer 메뉴 상세 회귀 0 (사용자 시나리오 4 PASS)
- [ ] sub-phase 5 / 4 / 3 / 1 / 1 patch 회귀 0
- [ ] `flutter analyze` 0 issue
- [ ] customer 측 `menu_detail_providers.dart` 변경 없음
- [ ] `MenuItemRepository.watchById` / `MenuItemRemoteDataSource.streamById` 변경 없음
