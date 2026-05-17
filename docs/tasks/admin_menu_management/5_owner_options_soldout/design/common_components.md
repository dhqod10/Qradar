# 공통 컴포넌트 디자인 명세 — sub-phase 5 (owner_options_soldout)

> 파일 위치:
> - `lib/presentation/owner/store_menu/widgets/sold_out_toggle.dart`
> - `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart`
>
> 참조:
> - sub-phase 4 `_InlineVisibleToggle` 패턴 (Switch.adaptive 즉시 토글)
> - sub-phase 1 `OptionGroupSelector` 패턴 (옵션 그룹 리스트 구조)

---

## 1. _SoldOutToggle (카드 인라인 품절 토글)

- 파일: `presentation/owner/store_menu/widgets/sold_out_toggle.dart`
- 역할: 카드 인라인 품절 즉시 토글. `_InlineVisibleToggle` 과 동등한 UX, `AppColors.error` 톤으로 위험성 강조.
- 재사용 대상: `OwnerStoreMenuListPage`, `OwnerBrandStoreMenusPage`

### 위젯 구조

```
Column
  ├─ Text ('품절', fontSize 9, w600, AppColors.textMuted, textAlign: center)
  ├─ SizedBox(height: 2)
  └─ SizedBox(width: 44)
       └─ Switch.adaptive(
            value: item.soldOut,
            onChanged: isLoading ? null : (v) => onChanged(v),
            activeColor: AppColors.error,
            activeTrackColor: AppColors.error.withOpacity(0.3),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surface,
          )
```

> `_InlineVisibleToggle` 과 같은 패턴. 라벨 "품절" 을 스위치 위에 작게 표시하여 두 스위치가 나란히 있을 때 구분 가능하게 한다.  
> `_InlineVisibleToggle` 도 마찬가지로 라벨 "표시" 를 스위치 위에 추가한다 (designer 결정 — sub-phase 4 `_InlineVisibleToggle` 에도 동일하게 적용 요청).

### Props

```dart
_SoldOutToggle({
  required bool soldOut,
  required bool isLoading,
  required void Function(bool) onChanged,
})
```

### 상태

| 상태 | UI |
|---|---|
| `soldOut == false` | Switch off 상태 — 기본 |
| `soldOut == true` | Switch on — `activeColor: AppColors.error` |
| `isLoading == true` | `Switch.adaptive(onChanged: null)` — 비활성화 (터치 불가) |
| 오류 | onChanged 호출자 측에서 이전 값으로 setState + SnackBar 처리 |

### 인터랙션

| 동작 | 반응 |
|---|---|
| 탭 (off → on) | `onChanged(true)` 호출 → optimistic update → UseCase 호출 |
| 탭 (on → off) | `onChanged(false)` 호출 → optimistic update → UseCase 호출 |
| UseCase 실패 | 이전 값으로 setState 원복 + SnackBar `'변경에 실패했어요'` |
| isLoading | 스위치 disabled |

---

## 2. MenuOptionDisableSheet (옵션 비활성 BottomSheet)

- 파일: `presentation/common/option_disable_sheet/menu_option_disable_sheet.dart`
- 역할: 메뉴 1개에 대한 옵션 그룹 / 항목 비활성 토글 UI. 개인 매장 / 브랜드 매장 양쪽에서 공통 사용.
- 진입: `showModalBottomSheet(isScrollControlled: true, ...)` 로 호출

### Props

```dart
MenuOptionDisableSheet({
  required String storeId,
  required MenuItemEntity menuItem,
  required MenuOptionDisableSheetType menuType,
  // MenuOptionDisableSheetType: personal | brandMasterRef | brandStoreOnly
})
```

### showModalBottomSheet 호출 패턴

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  builder: (_) => MenuOptionDisableSheet(
    storeId: storeId,
    menuItem: menuItem,
    menuType: menuType,
  ),
);
```

### 시트 외형

```
DraggableScrollableSheet(
  initialChildSize: 0.75,
  minChildSize: 0.4,
  maxChildSize: 0.92,
  builder: (context, scrollController) =>
    Container
      decoration:
        color: AppColors.surfaceElevated
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      └─ Column
           ├─ _SheetHeader
           └─ Expanded
                └─ _SheetBody (scrollController 전달)
```

### _SheetHeader

```
Padding(horizontal 20, top 12, bottom 8)
  └─ Column
       ├─ Center
       │    └─ _BottomSheetHandle (8×4 둥근 바, AppColors.border)
       ├─ SizedBox(height: 12)
       └─ Row
            ├─ Expanded
            │    └─ Column (crossAxisAlignment: start)
            │         ├─ Text ('옵션 관리', fontSize 17, w700, AppColors.textHeading)
            │         ├─ SizedBox(height: 4)
            │         └─ Text (menuItem.name, fontSize 13, AppColors.textMuted, maxLines 1, overflow: ellipsis)
            └─ IconButton
                 icon: Icon(Icons.close_rounded, size 22, AppColors.textMuted)
                 onPressed: Navigator.pop
```

### _SheetBody

```
ListView (controller: scrollController, padding: EdgeInsets.fromLTRB(0, 4, 0, 32))
  └─ [각 옵션 그룹] _OptionDisableGroupRow
```

로딩 / 에러 / 빈 상태 — 아래 별도 명세.

### _OptionDisableGroupRow (그룹 row)

각 옵션 그룹에 대한 row. 그룹 전체 비활성 토글 + 하위 항목 row 포함.

```
Column
  ├─ _GroupHeaderRow
  └─ (그룹 활성 상태) Column (항목 rows)
       └─ [각 항목] _OptionDisableItemRow
```

#### _GroupHeaderRow

```
Container
  decoration: color AppColors.surface, (그룹 헤더 배경 — 약한 구분)
  Padding(horizontal 20, vertical 14)
    Row
      ├─ Expanded
      │    └─ Column (crossAxisAlignment: start)
      │         ├─ Row
      │         │    ├─ Text (그룹 이름, fontSize 15, w600, AppColors.textHeading)
      │         │    ├─ SizedBox(width: 6)
      │         │    └─ [필수 여부 배지] _RequiredBadge or _OptionalBadge
      │         └─ (그룹 비활성 시) SizedBox(height: 4) + Text('비활성', fontSize 11, AppColors.error)
      └─ Switch.adaptive(
           value: !isGroupDisabled,  // true=활성, false=비활성
           onChanged: isLoading ? null : (v) => onGroupToggle(!v),
           activeColor: AppColors.primary,
           activeTrackColor: AppColors.primary.withOpacity(0.3),
           inactiveTrackColor: AppColors.error.withOpacity(0.3),
           inactiveThumbColor: AppColors.error,
         )
```

> 그룹 토글의 의미: Switch on = 그룹 활성(정상 운영), Switch off = 그룹 비활성(disabledOptionGroupIds 에 포함)  
> Switch off 상태 색상: `inactiveThumbColor: AppColors.error` — 비활성 상태 위험 강조

_RequiredBadge:

```
Container
  decoration: color AppColors.error.withOpacity(0.08), radius 6
  Padding(horizontal 5, vertical 2)
    Text '필수' (fontSize 10, w600, AppColors.error)
```

_OptionalBadge:

```
Container
  decoration: color AppColors.textMuted.withOpacity(0.10), radius 6
  Padding(horizontal 5, vertical 2)
    Text '선택' (fontSize 10, w500, AppColors.textMuted)
```

#### 그룹 비활성 상태 처리

그룹이 비활성(`isGroupDisabled == true`) 일 때:

```
_GroupHeaderRow: 배경 AppColors.surface (강조 없음)
  └─ 그룹 이름 텍스트: AppColors.textMuted (흐림 처리)
  └─ '비활성' 텍스트: fontSize 11, AppColors.error

(항목 row 는 안내 텍스트로 대체)
Padding(horizontal 20, vertical 8)
  └─ Text('그룹을 활성화하면 항목별 관리가 가능해요.',
           fontSize 12, AppColors.textMuted, italic)
```

### _OptionDisableItemRow (항목 row)

```
Padding(horizontal 20, vertical 10)
  └─ Row
       ├─ Expanded
       │    └─ Column (crossAxisAlignment: start)
       │         ├─ Text (항목 이름, fontSize 14, w500, AppColors.textBody)
       │         └─ (priceDelta != 0) SizedBox(height: 2) +
       │              Text ('+₩{priceDelta}' or '-₩{priceDelta}', fontSize 12, AppColors.textMuted)
       └─ Switch.adaptive(
            value: !isItemDisabled,  // true=활성, false=비활성
            onChanged: (isGroupDisabled || isLoading) ? null : (v) => onItemToggle(!v),
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveTrackColor: AppColors.error.withOpacity(0.3),
            inactiveThumbColor: AppColors.error,
          )
```

항목 비활성 상태 시각:

```
(isItemDisabled == true)
  항목 이름 텍스트: AppColors.textMuted + strikethrough (decoration: TextDecoration.lineThrough)
  (선택) 오른쪽에 Container('비활성', fontSize 9, AppColors.error, radius 4)
```

그룹 비활성 시 항목 disabled 처리:

```
onChanged: (isGroupDisabled || isLoading) ? null : ...
텍스트: AppColors.textMuted.withOpacity(0.5)
```

항목 구분선: `Divider(height: 1, color: AppColors.border, indent: 20, endIndent: 20)` — 항목들 사이에 삽입

### 그룹 사이 구분

```
Divider(height: 8, color: AppColors.border, thickness: 1)
```

또는 그룹 헤더 배경(`AppColors.surface`) 이 자체적으로 섹션 구분 역할.

### 상태별 UI

#### Loading (옵션 그룹 fetch 중)

```
Expanded
  └─ Center
       └─ CircularProgressIndicator(color: AppColors.primary)
```

#### Error (옵션 그룹 fetch 실패)

```
Expanded
  └─ Center
       └─ Column
            ├─ Icon(Icons.error_outline_rounded, 40, AppColors.error)
            ├─ SizedBox(height: 12)
            ├─ Text '옵션을 불러오지 못했어요' (fontSize 14, w600, AppColors.textHeading)
            ├─ SizedBox(height: 6)
            ├─ Text '잠시 후 다시 시도해주세요' (fontSize 12, AppColors.textMuted)
            ├─ SizedBox(height: 20)
            └─ ElevatedButton '다시 시도'
                 배경: AppColors.primary, 텍스트: AppColors.onPrimary
                 radius: 10, padding: horizontal 24, vertical 10
```

#### Empty (옵션 그룹 0건)

```
Expanded
  └─ Center
       └─ Column
            ├─ Icon(Icons.tune_outlined, 40, AppColors.textMuted)
            ├─ SizedBox(height: 12)
            ├─ Text '이 메뉴는 옵션이 없어요' (fontSize 14, w600, AppColors.textHeading)
            └─ SizedBox(height: 6)
            └─ Text '옵션 그룹을 추가하려면 브랜드 본사에 문의하세요.'
                     (fontSize 12, AppColors.textMuted, textAlign: center)
```

> 개인 매장 점주 케이스에는 위 문구 대신: `'옵션 그룹은 메뉴 편집에서 추가할 수 있어요.'`
> → `menuType` 에 따라 문구 분기 (developer 구현 시 주의).

### 토글 즉시 저장 흐름

```
사용자 토글 조작
  → optimistic update (UI 즉시 반영)
  → UseCase 호출 (menuType 분기):
      personal / brandStoreOnly → UpdateDisabledOptionsForPersonalMenuUseCase
      brandMasterRef → UpdateDisabledOptionsForOverrideUseCase
  → 성공: 아무 동작 없음 (UI 이미 반영됨)
  → 실패: 이전 상태로 setState 원복 + SnackBar '변경에 실패했어요'
```

시트 닫기 (`Navigator.pop`): 저장 이미 완료 — 별도 저장 버튼 없음.

### SnackBar 스타일 (공통)

```
SnackBar
  backgroundColor: AppColors.textHeading
  content: Text('변경에 실패했어요', fontSize 13, AppColors.onPrimary)
  duration: Duration(seconds: 2)
  behavior: SnackBarBehavior.floating
  shape: RoundedRectangleBorder(radius 10)
  margin: EdgeInsets.fromLTRB(16, 0, 16, 12)
```

---

## 3. 컴포넌트 관계 요약

```
OwnerStoreMenuListPage
  └─ OwnerStoreMenuCard
       ├─ _InlineVisibleToggle (sub-phase 4 — 라벨 '표시' 추가 요청)
       ├─ _SoldOutToggle (신규 — 라벨 '품절')
       └─ long-press → ActionSheet → MenuOptionDisableSheet(menuType: personal)

OwnerStoreMenuDetailPage
  └─ PopupMenu '옵션 관리' → MenuOptionDisableSheet(menuType: personal)

OwnerBrandStoreMenusPage
  └─ _BrandStoreMenuCard
       ├─ _SoldOutToggle (신규 — visible 토글 없음)
       └─ _BrandCardActions → MenuOptionDisableSheet(menuType: brandMasterRef | brandStoreOnly)

MenuOptionDisableSheet
  └─ ListView
       └─ _OptionDisableGroupRow
            ├─ _GroupHeaderRow (그룹 토글 — Switch off = 비활성)
            └─ [활성 그룹만] _OptionDisableItemRow (항목 토글 — Switch off = 비활성)
```

---

## 4. 개발자 전달 특이사항

1. **_InlineVisibleToggle 라벨 추가**: sub-phase 4 에서 라벨 없이 Switch 만 있었다면, 본 sub-phase 에서 `_SoldOutToggle` 과 나란히 배치될 때 구분이 어려울 수 있다. `_InlineVisibleToggle` 에도 "표시" 라벨을 추가하는 것을 권장한다 (Column: 라벨 + Switch 구조, 9px 텍스트).

2. **Switch onChanged 의미 역전 주의**: 옵션 그룹/항목 토글에서 Switch `value` 는 `!isGroupDisabled` (활성=true, 비활성=false). `onChanged(v)` 내부에서 `isGroupDisabled = !v` 로 처리한다. 항목 토글도 동일.

3. **menuType 분기**: `MenuOptionDisableSheet` 의 저장 로직이 `menuType` 에 따라 다른 UseCase 를 호출한다. developer 는 시트 안에서 Provider 를 통해 분기하거나, 시트 Props 에 `onSave` 콜백을 외부에서 주입하는 방식 중 선택한다 (아키텍처 재량).

4. **DraggableScrollableSheet**: `isScrollControlled: true` + `DraggableScrollableSheet` 조합. 옵션 그룹 수가 많을 경우 90% 까지 확장 가능.

5. **빈 상태 문구 분기**: `menuType == personal` 이면 `'옵션 그룹은 메뉴 편집에서 추가할 수 있어요.'`, `brandMasterRef | brandStoreOnly` 이면 `'옵션 그룹을 추가하려면 브랜드 본사에 문의하세요.'`.

6. **_SoldOutToggle 재사용**: `OwnerStoreMenuListPage` (개인 매장 카드) 와 `OwnerBrandStoreMenusPage` (브랜드 매장 카드) 양쪽에서 동일 위젯 재사용. Props 의 `onChanged` 콜백으로 UseCase 분기는 외부(Provider)에서 처리.

7. **그룹 비활성 시 항목 구역 처리**: 항목 Row 를 렌더링하되 모두 `onChanged: null` + `opacity: 0.4` 로 비활성 표시하는 방법 vs 항목 Row 숨기고 안내 문구만 표시하는 방법 중 선택. designer 결정: **안내 문구 방식** 채택 (항목을 숨기는 것이 더 명확).

8. **OwnerBrandStoreMenusPage 의 menuType 결정**: `MenuItemEntity.scope` 를 보고 분기. `scope == 'brand'` → `menuType: brandMasterRef`, `scope == 'store'` → `menuType: brandStoreOnly`.
