# sub-phase 7 patch — menu_option_group_management_item_toggle_patch 디자인 명세

> **상태**: DONE — 2026-05-03
>
> **spec.md 기준**: `docs/tasks/admin_menu_management/7_menu_option_group_management_item_toggle_patch/spec.md` (결정 1~5 APPROVED)

---

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 패턴 이식)
- 기존 화면 레퍼런스:
  - `docs/tasks/admin_menu_management/5_owner_options_soldout/design/common_components.md` — `MenuOptionDisableSheet` 의 `_OptionDisableGroupRow` / `_OptionDisableItemRow` 시각 패턴 직접 이식
  - `docs/tasks/admin_menu_management/7_menu_option_group_management/design.md` — `OptionGroupSelector` 카드 구조 / `_PriceDeltaLabel` 위젯 / inactive 그룹 칩 패턴
- 색상 토큰: `lib/core/theme/app_colors.dart`

---

## 변경 범위 요약

| 위젯 / 화면 | 유형 | 비고 |
|---|---|---|
| `OptionGroupSelector` | 기존 위젯 확장 | prop 2개 추가 + 내부 private 위젯 신설 |
| `_GroupItemTogglePanel` | 신규 private 위젯 | 그룹 체크 시 항목 list 렌더 컨테이너 |
| `_OptionItemToggleRow` | 신규 private 위젯 | 항목 1개 row (label + priceDelta + Switch) |
| `MasterMenuFormPage` | 기존 폼 보강 | state 신설 / prefill / submit 매핑 / `_hasOperationFieldChange` 보강 |
| `BrandStoreOnlyMenuFormPage` | 기존 폼 보강 | 위와 동일 |
| `OwnerStoreMenuFormPage` | 기존 폼 보강 | state 신설 / prefill / submit 매핑 / `_hasChanged` 보강 |

---

## OptionGroupSelector 위젯 확장 명세

### 개요

기존 `OptionGroupSelector` 는 그룹 체크박스 + 그룹명 + 항목 수/priceDelta 표시까지만 담당했다.  
본 patch 는 **그룹이 체크된 상태에서만** 해당 그룹의 항목 list를 카드 하단에 펼쳐 항목별 ON/OFF Switch를 노출한다.

### 새 prop

```
disabledOptionItemIds: List<String>   // 현재 비활성 항목의 compositeId 목록
onDisabledItemsChanged: ValueChanged<List<String>>  // 항목 토글 시 변경된 목록 전달 콜백
```

두 prop 모두 default 값을 갖는다:
- `disabledOptionItemIds`: `const []`
- `onDisabledItemsChanged`: no-op (`(_) {}`)

기존 prop (`selectedIds`, `onChanged`, 섹션 헤더 등)은 변경 없이 유지한다.

### 전체 구조 변경 (그룹 카드 단위)

기존 그룹 카드 1개 구조:

```
Card
  └─ CheckboxListTile (그룹 체크박스 + 이름 + 항목 수)
```

변경 후 그룹 카드 1개 구조:

```
Card
  └─ Column
       ├─ CheckboxListTile (기존 유지)
       └─ (그룹이 selectedIds에 포함된 경우만) _GroupItemTogglePanel
```

### 레이아웃 변경 시 카드 스타일

그룹 카드 기본 스타일은 sub-phase 7 `OptionGroupSelector` 패턴을 그대로 유지한다:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` 1px |
| borderRadius | 14 |
| shadow | `AppColors.primary` alpha 0.04 |

`_GroupItemTogglePanel` 이 노출될 때 카드 height는 항목 수에 따라 자동 확장된다.  
폼 내부에서 카드가 늘어나면 `SingleChildScrollView` 로 스크롤 처리 (기존 폼 구조 그대로).

---

## _GroupItemTogglePanel 명세

### 역할

그룹 체크박스가 체크된 상태일 때 카드 하단에 렌더된다.  
sub-phase 5 `MenuOptionDisableSheet` 의 항목 구역 패턴을 메뉴 폼 카드 안으로 이식한 위젯이다.

### 구조

```
Column
  ├─ _PanelDivider                         // 체크박스 영역과 항목 영역 구분선
  ├─ _PanelHeader                          // '이 메뉴에 제공할 항목 선택' 헤더
  ├─ [항목 0] _OptionItemToggleRow
  ├─ [항목 구분선]
  ├─ [항목 1] _OptionItemToggleRow
  ├─ ...
  └─ (항목 0개인 경우) _ItemEmptyState     // 빈 상태 대체
```

### _PanelDivider

```
Divider(height: 1, thickness: 1, color: AppColors.border)
```

### _PanelHeader

```
Padding(horizontal: 16, top: 10, bottom: 4)
  └─ Text(
       '이 메뉴에 제공할 항목 선택',
       fontSize: 11,
       fontWeight: w600,
       color: AppColors.primary,
     )
```

### 항목 구분선 (항목 사이)

```
Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16)
```

### 하단 여백

```
SizedBox(height: 8)
```

---

## _OptionItemToggleRow 명세

### 역할

항목 1개의 row: label + priceDelta + ON/OFF Switch.  
sub-phase 5 `_OptionDisableItemRow` 시각 패턴과 동일하게 맞춘다.

### 구조

```
Padding(horizontal: 16, vertical: 10)
  └─ Row (crossAxisAlignment: center)
       ├─ Expanded
       │    └─ Column (crossAxisAlignment: start, mainAxisSize: min)
       │         ├─ Text (항목 이름)          // label
       │         └─ (priceDelta != 0) Text (가격 표시)  // priceDelta
       └─ Switch.adaptive
```

### label 텍스트

| 상태 | 스타일 |
|---|---|
| 항목 ON (기본) | fontSize: 14, fontWeight: w500, color: `AppColors.textBody` |
| 항목 OFF (disabled) | fontSize: 14, fontWeight: w500, color: `AppColors.textMuted`, decoration: `TextDecoration.lineThrough` |

### priceDelta 텍스트

sub-phase 7 `_PriceDeltaLabel` 위젯 규칙 그대로 적용:

| 값 | 표시 | 색상 |
|---|---|---|
| 양수 (+500) | `'+500원'` | `AppColors.success`, fontSize: 12, w600 |
| 음수 (-500) | `'-500원'` | `AppColors.error`, fontSize: 12, w600 |
| 0원 | `'0원'` | `AppColors.textMuted`, fontSize: 12, w500 |

priceDelta == 0 인 경우 priceDelta 텍스트를 노출하지 않는다 (sub-phase 5 `_OptionDisableItemRow` 과 동일 정책).

priceDelta 텍스트 상단 간격:

```
SizedBox(height: 2)
```

### Switch.adaptive

| 속성 | ON 상태 (항목 활성) | OFF 상태 (항목 비활성) |
|---|---|---|
| value | `true` | `false` |
| activeColor (thumbColor) | `AppColors.primary` | — |
| activeTrackColor | `AppColors.primaryBright` alpha 0.3 | — |
| inactiveThumbColor | — | `AppColors.error` |
| inactiveTrackColor | — | `AppColors.error` alpha 0.3 |
| onChanged | 토글 콜백 | 토글 콜백 |

> Switch `value` 는 `!isDisabled` 다. 항목이 `disabledOptionItemIds`에 없으면 ON(true), 있으면 OFF(false).  
> onChanged 내부: OFF → ON 이면 compositeId를 목록에서 제거. ON → OFF 이면 compositeId를 목록에 추가. 변경된 목록 전체를 `onDisabledItemsChanged` 에 전달.

---

## _ItemEmptyState 명세 (항목 0개 그룹)

### 역할

그룹이 체크되었으나 해당 그룹의 `items` 가 비어 있을 때 항목 영역 대신 표시한다.

### 구조

```
Padding(horizontal: 16, vertical: 16)
  └─ Row (crossAxisAlignment: center, spacing: 8)
       ├─ Icon(Icons.list_alt_outlined, size: 16, color: AppColors.textMuted)
       └─ Text(
            '이 그룹에 항목이 없어요',
            fontSize: 13,
            color: AppColors.textMuted,
          )
```

---

## 그룹 체크 상태별 렌더 정책

| 그룹 상태 | `_GroupItemTogglePanel` 노출 여부 | 비고 |
|---|---|---|
| `selectedIds` 에 포함 (체크됨) | 노출 | 항목 list 펼침 |
| `selectedIds` 에 미포함 (미체크) | 미노출 | 카드 체크박스만 노출 |
| inactive 그룹 칩 (sub-phase 7 `_InactiveGroupChip`) | 미노출 | 선택 해제만 가능, 항목 운영 불가 |

inactive 그룹은 `selectedIds` 에 포함되어 있더라도 `_GroupItemTogglePanel` 을 렌더하지 않는다.  
inactive 그룹의 경우 sub-phase 7 기존 경고 marker (노란 '비활성' 배지)만 유지한다.

---

## 그룹 체크 해제 시 disabledOptionItemIds 보존 정책

그룹 체크박스를 해제해도 해당 그룹의 compositeId 들은 `_disabledOptionItemIds` state 에서 제거하지 않는다.  
그룹을 다시 체크하면 이전 항목 OFF 상태가 그대로 복원된다.

이 동작을 위젯 레벨에서 구현할 필요 없이, 폼 state(`_disabledOptionItemIds`) 를 그룹 토글이 건드리지 않으면 자동으로 보장된다.

---

## 메뉴 폼 3종 — 옵션 그룹 섹션 변경사항

### 공통

`OptionGroupSelector` 를 호출하는 3개 폼 모두 아래 prop 2개를 추가로 전달한다:

```
disabledOptionItemIds: _disabledOptionItemIds,
onDisabledItemsChanged: (updated) => setState(() => _disabledOptionItemIds = updated),
```

폼 내 섹션 헤더 ("기본 옵션" / "브랜드 옵션" / "매장 옵션") 는 sub-phase 7 결정 그대로 유지한다.

### 폼 길이 변경 안내

그룹을 체크할 때 항목 list 가 펼쳐지면 폼 전체 길이가 늘어난다.  
기존 메뉴 폼이 `SingleChildScrollView` 로 감싸져 있으므로 별도 레이아웃 변경 없이 스크롤로 처리된다.

항목 수가 많을 때 스크롤이 불편할 수 있으나, 별도 "접기" 버튼은 구현하지 않는다.  
그룹 체크박스를 해제하면 자연스럽게 항목 영역이 사라진다.

---

## 인터랙션 정의

| 동작 | 반응 |
|---|---|
| 그룹 체크박스 ON | `selectedIds` 에 그룹 추가 + 카드 하단에 `_GroupItemTogglePanel` 즉시 펼침 |
| 그룹 체크박스 OFF | `selectedIds` 에서 그룹 제거 + `_GroupItemTogglePanel` 즉시 숨김. `_disabledOptionItemIds` 의 해당 그룹 compositeId 들은 그대로 유지 |
| 항목 Switch ON → OFF | 해당 compositeId (`'{groupId}_{itemId}'`) 를 `_disabledOptionItemIds` 에 추가. Switch 즉시 OFF 표시. label 에 strikethrough 적용 |
| 항목 Switch OFF → ON | 해당 compositeId 를 `_disabledOptionItemIds` 에서 제거. Switch 즉시 ON 표시. label strikethrough 해제 |
| inactive 그룹 칩 탭 | 선택 해제만 가능 (sub-phase 7 기존 동작 유지). `_GroupItemTogglePanel` 펼침 없음 |
| 항목 0개 그룹 체크 | `_GroupItemTogglePanel` 내부에 `_ItemEmptyState` 표시 |
| 저장 버튼 탭 | `_disabledOptionItemIds` 를 `MenuItemEntity.disabledOptionItemIds` 에 매핑하여 submit |

### 애니메이션

`_GroupItemTogglePanel` 펼침 / 접힘에 가벼운 `AnimatedSize` 또는 `AnimatedSwitcher` 적용을 권장한다.

| 속성 | 값 |
|---|---|
| duration | `Duration(milliseconds: 200)` |
| curve | `Curves.easeInOut` |

강제 사항은 아니며, 성능 부담이 있을 경우 즉시 렌더로 대체 가능하다.

---

## 상태별 UI

### Loading

`OptionGroupSelector` 는 그룹 목록 로딩 시 기존 shimmer를 유지한다 (sub-phase 7 기존 명세).  
`_GroupItemTogglePanel` 은 `OptionGroupSelector` 가 데이터를 받은 후에만 렌더되므로 별도 loading 상태 없음.

### Error

`OptionGroupSelector` 의 기존 에러 UI 유지. `_GroupItemTogglePanel` 에 별도 에러 UI 없음.

그룹 체크 후 항목 목록 렌더 시 예외가 발생하면 해당 그룹 카드에 `_ItemEmptyState` 를 대체 표시한다.

### Empty

#### 그룹 자체가 없는 경우

기존 sub-phase 7 `OptionGroupSelector` 빈 상태 UI 그대로:

```
Padding(vertical: 16)
  └─ Column (spacing: 8)
       ├─ Text('옵션 그룹이 없어요', fontSize: 14, w500, AppColors.textBody)
       └─ Text('옵션 그룹 관리 화면에서 추가해보세요', fontSize: 12, AppColors.textMuted)
```

#### 그룹은 있으나 항목이 0개인 경우

그룹 체크 시 `_GroupItemTogglePanel` 내부에 `_ItemEmptyState` 렌더:

```
Padding(horizontal: 16, vertical: 16)
  └─ Row (spacing: 8)
       ├─ Icon(Icons.list_alt_outlined, size: 16, AppColors.textMuted)
       └─ Text('이 그룹에 항목이 없어요', fontSize: 13, AppColors.textMuted)
```

---

## 카피 확정값

| 위치 | 카피 |
|---|---|
| `_PanelHeader` | `'이 메뉴에 제공할 항목 선택'` |
| `_ItemEmptyState` | `'이 그룹에 항목이 없어요'` |

---

## 색상 토큰 요약

| 용도 | 토큰 |
|---|---|
| 항목 패널 헤더 텍스트 | `AppColors.primary` |
| 항목 이름 (ON 상태) | `AppColors.textBody` |
| 항목 이름 (OFF 상태) | `AppColors.textMuted` + `TextDecoration.lineThrough` |
| priceDelta 양수 | `AppColors.success` |
| priceDelta 음수 | `AppColors.error` |
| priceDelta 0원 | `AppColors.textMuted` |
| Switch activeColor (thumb) | `AppColors.primary` |
| Switch activeTrackColor | `AppColors.primaryBright` alpha 0.3 |
| Switch inactiveThumbColor | `AppColors.error` |
| Switch inactiveTrackColor | `AppColors.error` alpha 0.3 |
| 항목 구분선 | `AppColors.border` |
| 패널 구분선 | `AppColors.border` |
| 빈 상태 아이콘 | `AppColors.textMuted` |
| 빈 상태 텍스트 | `AppColors.textMuted` |

---

## Figma 대비 변경사항

| 항목 | Figma / 기존안 | Qradar 적용 |
|---|---|---|
| Figma 레퍼런스 | 없음 (신규 UI) | Qradar 디자인 시스템 + sub-phase 5 패턴 이식 |
| 항목 펼침 방식 | — | 그룹 체크 시에만 펼침 (결정 1 A안) |
| 항목 default 상태 | — | 기본 ON (결정 2 A안) |
| Switch 비활성 색상 | — | `AppColors.error` (sub-phase 5 `_OptionDisableItemRow` 패턴 동일) |
| 그룹 미체크 시 항목 | — | 미렌더 (collapse, 노이즈 최소화) |
| inactive 그룹 항목 펼침 | — | 미렌더 (선택 해제만 가능) |

---

## 개발자 전달 특이사항

### 1. 재사용할 기존 위젯 / 패턴

| 재사용 대상 | 위치 | 비고 |
|---|---|---|
| `_OptionDisableItemRow` 시각 패턴 | sub-phase 5 `common_components.md` | `_OptionItemToggleRow` 설계 기반 |
| `_PriceDeltaLabel` 위젯 | sub-phase 7 `option_item_list_editor.dart` | priceDelta 표시에 직접 재사용 |
| `OptionGroupSelector` 카드 구조 | sub-phase 7 기존 | 그대로 유지하고 Column 확장 |
| compositeId 포맷 (`'{groupId}_{itemId}'`) | sub-phase 5 `MenuOptionDisableSheet._onItemToggle` | 동일 포맷 사용 |

### 2. `_GroupItemTogglePanel` 위치

`OptionGroupSelector` 파일 내부 private 위젯으로 추가한다:

```
lib/presentation/brand/master_menu/widgets/option_group_selector.dart
  ├─ OptionGroupSelector (public)
  ├─ _GroupItemTogglePanel (private — 신규)
  └─ _OptionItemToggleRow (private — 신규)
```

### 3. Switch value 방향 주의

항목 Switch 의 `value` 는 `!isDisabled` 다.  
compositeId 가 `disabledOptionItemIds` 에 **없으면** Switch = `true` (ON).  
compositeId 가 `disabledOptionItemIds` 에 **있으면** Switch = `false` (OFF).

sub-phase 5 `_OptionDisableItemRow` 와 동일한 방향이므로 해당 패턴을 참조한다.

### 4. 그룹 토글이 항목 상태를 건드리지 않음

그룹 체크박스 토글(`onChanged` → `selectedIds` 변경)은 `_disabledOptionItemIds` state 를 변경하지 않는다.  
그룹 체크 해제 → 재체크 시 이전 항목 OFF 상태가 그대로 복원되어야 한다.  
이는 폼 state 를 분리 관리(`_selectedOptionGroupIds`, `_disabledOptionItemIds`)함으로써 자연스럽게 보장된다.

### 5. inactive 그룹의 항목 패널 미노출

`_InactiveGroupChip` (sub-phase 7) 은 `selectedIds` 에 포함되어도 항목 패널을 열지 않는다.  
`OptionGroupSelector` 내부에서 그룹 id 가 inactive 목록에 있으면 `_GroupItemTogglePanel` 렌더를 skip 한다.

### 6. 메뉴 폼 3종 — state 추가

각 폼에 아래 2개 state 를 추가한다:

```dart
List<String> _disabledOptionGroupIds = [];
List<String> _disabledOptionItemIds = [];
```

prefill (수정/복제 모드):
```dart
_disabledOptionGroupIds = List.from(source.disabledOptionGroupIds);
_disabledOptionItemIds = List.from(source.disabledOptionItemIds);
```

등록 모드: 두 필드 모두 빈 배열로 시작.

### 7. 운영 필드 변경 분석 함수 보강 (결정 J 정합)

`MasterMenuFormPage._hasOperationFieldChange` / `BrandStoreOnlyMenuFormPage._hasOperationFieldChange` 에 아래 비교를 추가한다:

```dart
|| !_sortedListEquals(_disabledOptionGroupIds, source.disabledOptionGroupIds)
|| !_sortedListEquals(_disabledOptionItemIds, source.disabledOptionItemIds)
```

정렬 후 비교 헬퍼 (`_sortedListEquals`):

```dart
bool _sortedListEquals(List<String> a, List<String> b) {
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  return _listEquals(sa, sb);  // 기존 _listEquals 재사용
}
```

`OwnerStoreMenuFormPage._hasChanged` 에도 동일하게 두 필드 비교를 추가한다.

### 8. submit 시 entity 매핑

```dart
MenuItemEntity(
  ...
  disabledOptionGroupIds: _disabledOptionGroupIds,
  disabledOptionItemIds: _disabledOptionItemIds,
  ...
)
```

기존 `OwnerStoreMenuFormPage` 의 `disabledOptionGroupIds: _source?.disabledOptionGroupIds ?? []` 코드는 state 기반으로 대체한다.

### 9. sub-phase 5 인라인 시트와 동일 필드 공유

`MenuOptionDisableSheet` (sub-phase 5) 와 메뉴 폼 selector 가 같은 `disabledOptionItemIds` 필드를 건드린다.  
두 흐름은 독립적으로 동작하며, 마지막 저장 값이 우선된다 (last-write-wins).  
이 점을 `implementation.md` 에 명시하도록 developer 에게 전달한다.

### 10. 저장 실패 처리

항목 Switch 토글은 즉시 저장이 아닌 폼 state 변경 → 저장 버튼 시점에 일괄 저장 방식이다.  
저장 실패 시 기존 폼 에러 처리 (`showErrorDialog`) 를 그대로 따른다.  
항목 토글 자체는 optimistic update 없이 state 변경만 수행한다.

---

## 완료 기준

- [x] `OptionGroupSelector` 새 prop 2개 (`disabledOptionItemIds`, `onDisabledItemsChanged`) 명세 완료
- [x] `_GroupItemTogglePanel` / `_OptionItemToggleRow` 위젯 명세 완료
- [x] 그룹 체크 ↔ 항목 펼침 인터랙션 정의 완료
- [x] 항목 Switch 색상 / 텍스트 상태 명세 완료
- [x] 항목 0개 빈 상태 카피 및 UI 명세 완료
- [x] inactive 그룹 항목 패널 미노출 정책 명세 완료
- [x] 모든 색상 `AppColors` 토큰으로 명세
- [x] loading / error / empty 상태 정의 완료
- [x] developer 전달 특이사항 작성 완료
