# sub-phase 5 master ref 옵션 시트 fix — implementation

## 구현 완료 항목

1. **신규 provider 파일 생성** — 시트 전용 DI + 옵션 그룹 fetch family.
2. **`MenuOptionDisableSheet` 의 옵션 fetch 흐름 교체** — `menuItemAllOptionGroupsProvider` (storeId+menuItemId 기반, master ref 케이스에서 항상 null detail) 의존 제거 → `optionGroupsForMenuItemEntityProvider(widget.menuItem)` 로 entity 직접 입력.
3. **store-only / master ref 양 케이스 모두 동일 코드 경로** — `widget.menuItem` 의 `optionGroupRefs` 가 신뢰 가능한 입력원이라 분기 불필요.

---

## 신규 / 수정 파일

### 신규
- `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart`
  - `_sheetOptionRemoteDataSourceProvider` (private) — `OptionRemoteDataSource` 인스턴스.
  - `_sheetOptionRepositoryProvider` (private) — `OptionRepositoryImpl` 주입.
  - `optionGroupsForMenuItemEntityProvider` — `FutureProvider.autoDispose.family<List<OptionGroupEntity>, MenuItemEntity>`. `optionGroupRefs.isEmpty` 면 빈 배열 즉시 반환 (불필요 RPC 절약). disabled 필터 미적용.

### 수정
- `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart`
  - import: `menu_option_disable_sheet_providers.dart` 추가, customer 측 `menu_detail_providers.dart` import 제거.
  - build 본문 watch: `MenuItemKey` 생성 + `menuItemAllOptionGroupsProvider(key)` → `optionGroupsForMenuItemEntityProvider(widget.menuItem)`.
  - 에러 retry 콜백: `ref.invalidate(menuItemAllOptionGroupsProvider(key))` → `ref.invalidate(optionGroupsForMenuItemEntityProvider(widget.menuItem))`.

### 미수정 (의도)
- `lib/data/datasources/remote/menu_item_remote_data_source.dart` — `streamById` 분기 안 함 (영향 큼, spec 비범위).
- `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart` — `menuItemAllOptionGroupsProvider` 자체는 customer 메뉴 상세 흐름이 별도라 손대지 않음.
- `lib/data/repositories/menu_item_repository_impl.dart` — `_mergeForBrandStore` 미변경 (case B 머지 결과의 entity 가 정상 입력원).

---

## 핵심 변경 요약

### Before
```dart
// MenuOptionDisableSheet.build
final key = MenuItemKey(
  storeId: widget.storeId,
  menuItemId: widget.menuItem.id,
);
final groupsAsync = ref.watch(menuItemAllOptionGroupsProvider(key));
// 내부: menuItemDetailProvider(key) → streamById(stores/.../menuItems/{id})
// master ref 메뉴는 stores 하위 doc 없음 → null → 빈 배열 → "옵션 없음" 표시
```

### After
```dart
// MenuOptionDisableSheet.build
final groupsAsync =
    ref.watch(optionGroupsForMenuItemEntityProvider(widget.menuItem));
// widget.menuItem 은 case B 머지 결과 (master ref 도 optionGroupRefs 보존)
// → OptionRepository.getOptionGroupsForMenuItem(entity) 직접 호출
// → master scope ref / store scope ref 모두 정상 fetch
```

---

## 테스트 포인트

### 자동 검증 (정적 분석으로 가능)
- [x] `flutter analyze`: 0 issue (변경 파일 + 전체 프로젝트).
- [x] Clean Architecture: presentation 에서 Firebase 직접 import 없음 (Repository 거침).
- [x] 시트 UI / 마이크로카피 / AppColors 토큰 변경 0.
- [x] customer 측 `menuItemAllOptionGroupsProvider` 자체 미수정 (회귀 영향 없음).

### 사용자 실기기 검증 (필요)
1. **master ref 메뉴 옵션 시트** — 브랜드 본사에서 옵션 그룹을 마스터 메뉴에 추가 + admin 승인 → 점주 매장 진입 → 해당 메뉴 카드의 튜닝 아이콘 → 시트에 옵션 그룹들 정상 노출 (이전엔 빈 상태).
2. **store-only 메뉴 옵션 시트 회귀** — 점포 한정 메뉴 (개인 매장 / 브랜드 점포 한정) 의 옵션 시트도 기존대로 동작.
3. **빈 상태** — 마스터 메뉴에 옵션이 없는 경우 "이 메뉴는 옵션이 없어요" 표시.
4. **옵션 토글 흐름** — 그룹 비활성 / 항목 비활성 토글 → Repository 정상 저장 → 재진입 시 토글 상태 유지.
5. **에러 retry** — 네트워크 끊김 등 실패 시 재시도 버튼이 새 provider 를 invalidate 해서 재호출.

---

## flutter analyze 결과

```
Analyzing 2 items...
No issues found! (ran in 2.0s)
```

전체 프로젝트:
```
Analyzing OrderApp...
No issues found! (ran in 4.2s)
```

---

## 미구현 / 보류

없음. spec 범위 내 전 항목 구현 완료.

비범위(향후 작업 후보):
- `streamById` / `MenuItemRepository.watchById` 자체 분기 — customer 메뉴 상세 등 영향 큰 영역, 별도 phase 필요.
- customer 측 `menuItemAllOptionGroupsProvider` / `menuItemOptionGroupsProvider` 동등 패치 — customer 측에서 master ref 메뉴 상세 진입 시 동일 이슈가 있을 가능성. 검증 후 결정.
- 옵션 그룹 CRUD UI — sub-phase 7 별도 phase.
