# sub-phase 7 patch — menu_option_group_management_item_toggle_patch 구현 명세

> **상태**: DONE — 2026-05-03
> **담당**: developer
> **참조**: spec.md (결정 1~5 APPROVED) / design.md (DONE)

---

## 구현 완료 항목

| # | 항목 | 파일 |
|---|---|---|
| 1 | `OptionGroupSelector` prop 2개 추가 + 내부 private 위젯 3개 신설 | `option_group_selector.dart` |
| 2 | `MasterMenuFormPage` state/prefill/submit/`_hasOperationFieldChange` 보강 | `master_menu_form_page.dart` |
| 3 | `BrandStoreOnlyMenuFormPage` state/prefill/submit/`_hasOperationFieldChange` 보강 | `brand_store_only_menu_form_page.dart` |
| 4 | `OwnerStoreMenuFormPage` state/prefill/submit 교체/`_hasChanged` 보강 | `owner_store_menu_form_page.dart` |

---

## 수정된 파일 목록 (수정만, 신규 없음)

```
lib/presentation/brand/master_menu/widgets/option_group_selector.dart
lib/presentation/brand/master_menu/master_menu_form_page.dart
lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart
lib/presentation/owner/store_menu/owner_store_menu_form_page.dart
```

Domain / Data 레이어 변경 없음.

---

## 핵심 변경 diff 요약

### 1. `option_group_selector.dart`

**새 prop 2개 추가** (하위 호환 — default 값 보유):

```dart
final List<String> disabledOptionItemIds;          // default: const []
final ValueChanged<List<String>> onDisabledItemsChanged;  // default: no-op
```

**그룹 카드 구조 변경**: `CheckboxListTile` 단일 → `Column(CheckboxListTile + _GroupItemTogglePanel)`.  
선택된(active) 그룹에만 `_GroupItemTogglePanel` 노출. inactive 그룹(`_InactiveGroupChip`)은 미노출.

**신설 private 위젯 3개**:

- `_GroupItemTogglePanel`: 그룹 카드 하단 항목 토글 영역. 패널 헤더("이 메뉴에 제공할 항목 선택") + 항목 행 목록 또는 빈 상태.
- `_OptionItemToggleRow`: 항목 1개 row. label(ON: `textBody` / OFF: `textMuted` + strikethrough) + `PriceDeltaLabel`(priceDelta != 0 시만) + `Switch.adaptive`.
- `_ItemEmptyState`: 항목 0개 그룹 체크 시 표시("이 그룹에 항목이 없어요").

**Switch 색상** (sub-phase 5 패턴 동일):
- ON: `activeThumbColor: AppColors.primary` / `activeTrackColor: AppColors.primaryBright.withValues(alpha: 0.3)`
- OFF: `inactiveThumbColor: AppColors.error` / `inactiveTrackColor: AppColors.error.withValues(alpha: 0.3)`

**compositeId 포맷**: `'{groupId}_{itemId}'` — sub-phase 5 `MenuOptionDisableSheet._onItemToggle` 과 동일.

**`_PriceDeltaLabel` 재사용**: `option_item_list_editor.dart` 의 public `PriceDeltaLabel` 위젯을 `_OptionItemToggleRow` 에서 직접 참조. 별도 복사 없음.

---

### 2. `master_menu_form_page.dart`

**state 추가**:
```dart
List<String> _disabledOptionGroupIds = [];
List<String> _disabledOptionItemIds = [];
```

**initState prefill** (등록=빈 배열, 수정/복제=source 값):
```dart
_disabledOptionGroupIds = List<String>.from(source?.disabledOptionGroupIds ?? []);
_disabledOptionItemIds  = List<String>.from(source?.disabledOptionItemIds  ?? []);
```

**`_hasOperationFieldChange` 보강** (결정 J 정합):
```dart
|| !_sortedListEquals(old.disabledOptionGroupIds, next.disabledOptionGroupIds)
|| !_sortedListEquals(old.disabledOptionItemIds,  next.disabledOptionItemIds)
```

**`_sortedListEquals` 헬퍼 추가** (기존 `_listEquals` 재사용):
```dart
bool _sortedListEquals(List<String> a, List<String> b) {
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  return _listEquals(sa, sb);
}
```

**submit 매핑**:
```dart
disabledOptionGroupIds: _disabledOptionGroupIds,
disabledOptionItemIds:  _disabledOptionItemIds,
```

**`OptionGroupSelector` 호출부** 새 prop 전달:
```dart
disabledOptionItemIds: _disabledOptionItemIds,
onDisabledItemsChanged: (updated) => setState(() => _disabledOptionItemIds = updated),
```

---

### 3. `brand_store_only_menu_form_page.dart`

`master_menu_form_page.dart` 와 동일한 패턴 적용:
- state 2개 추가
- initState prefill
- `_hasOperationFieldChange` + `_sortedListEquals` 보강
- submit 매핑
- selector 새 prop 전달

---

### 4. `owner_store_menu_form_page.dart`

- state 2개 추가 + initState prefill (master/brand 폼과 동일).
- **submit 교체**: 기존 `disabledOptionGroupIds: _source?.disabledOptionGroupIds ?? []` / `disabledOptionItemIds: _source?.disabledOptionItemIds ?? []` → state 기반으로 대체.
- **`_hasChanged` 보강**: `disabledOptionGroupIds` / `disabledOptionItemIds` 비교 추가.
- **`_sortedListEquals` 헬퍼 추가** (기존 `_listEqualsString` 재사용).
- selector 새 prop 전달.

owner 폼은 결정 J 단일 update 경로이므로 `_hasOperationFieldChange` 없이 `_hasChanged` 에 통합.

---

## sub-phase 5 인라인 시트와 필드 공유 (architect 요구 명시)

`MenuOptionDisableSheet` (sub-phase 5) 와 메뉴 폼 `OptionGroupSelector` 항목 토글은
**동일한 `MenuItemEntity.disabledOptionItemIds` 필드**를 건드린다.

두 흐름은 독립 진입 동선으로 동작하며, **마지막 저장(submit) 값이 우선(last-write-wins)**된다.
도메인/레포지터리 단에서 단순 덮어쓰기이므로 별도 동기화 로직 불필요.

- 메뉴 폼에서 항목 OFF 저장 → 인라인 시트 재진입 시 OFF 상태 노출.
- 인라인 시트에서 OFF 저장 → 메뉴 폼 수정 진입 시 OFF prefill.

---

## 구현에서 결정 규칙 준수 확인

| 결정 | 준수 여부 | 비고 |
|---|---|---|
| 결정 1. 그룹 체크 시에만 항목 패널 노출 | 완료 | `isSelected` 조건으로 `_GroupItemTogglePanel` 렌더 |
| 결정 2. 기본 ON (등록 시 빈 배열) | 완료 | initState 등록 모드 `[]` |
| 결정 3. `OptionGroupSelector` 확장 + 내부 private 위젯 | 완료 | `_GroupItemTogglePanel` / `_OptionItemToggleRow` / `_ItemEmptyState` |
| 결정 4. `_hasOperationFieldChange` 에 두 필드 비교 추가 | 완료 | master / brand store-only 폼 |
| 결정 5. customer 측 변경 없음 | 완료 | presentation 변경만, 기존 filter 로직 그대로 |

---

## `flutter analyze` 결과

```
Analyzing OrderApp...
No issues found! (ran in 4.6s)
```

---

## 테스트 포인트 (tester 전달)

### UI 회귀

1. 메뉴 폼(마스터/브랜드 점포한정/owner) 그룹 체크박스 기존 동작 — 선택/해제 정상.
2. 그룹 체크 시 해당 그룹 카드 하단에 "이 메뉴에 제공할 항목 선택" 패널 즉시 노출.
3. 그룹 체크 해제 시 패널 즉시 사라짐. `_disabledOptionItemIds` state 는 유지 (재체크 시 이전 OFF 복원).
4. inactive 그룹 칩(`_InactiveGroupChip`)은 선택되어 있어도 항목 패널 미노출.
5. 항목 0개 그룹 체크 시 "이 그룹에 항목이 없어요" 빈 상태 노출.

### Switch 동작

6. Switch ON → OFF: 해당 compositeId 가 `disabledOptionItemIds` 에 추가됨. label strikethrough 적용.
7. Switch OFF → ON: 해당 compositeId 가 `disabledOptionItemIds` 에서 제거됨. label strikethrough 해제.
8. Switch 색상: ON = primary thumb / primaryBright alpha 0.3 track. OFF = error thumb / error alpha 0.3 track.

### 데이터 정합

9. 신규 메뉴 등록 시 `disabledOptionItemIds == []` 로 저장됨 (Firestore 확인).
10. 수정 모드 진입 시 source 값 prefill — 기존 OFF 항목 Switch 가 OFF 상태로 노출됨.
11. 항목 OFF → 저장 → Firestore 에 compositeId 포함 확인.
12. 항목 ON → 저장 → Firestore 에서 compositeId 제거 확인.

### 결정 J 정합 (마스터 / 브랜드 점포한정 폼)

13. `disabledOptionItemIds` 만 변경 → 저장 시 `UpdateMasterMenuItemOperationUseCase` 호출 → status 보존 (pending 회귀 없음).
14. `disabledOptionGroupIds` 만 변경 → 동일 경로.
15. owner 폼: 두 필드 변경 → `UpdateOwnerStoreMenuUseCase` 단일 경로 → 즉시 반영.

### sub-phase 5 시트 동기화

16. 메뉴 폼에서 항목 OFF 저장 → 인라인 시트(`MenuOptionDisableSheet`) 진입 시 해당 항목 OFF 상태 확인.
17. 인라인 시트에서 항목 OFF 저장 → 메뉴 폼 수정 모드 진입 시 해당 항목 OFF prefill 확인.

### customer 회귀

18. 항목 OFF 저장 → customer 옵션 시트에 해당 항목 미노출.
19. 항목 ON 저장 → customer 옵션 시트에 해당 항목 노출.

### 엣지 케이스

20. 변경 없이 저장 버튼 → UseCase 호출 없이 pop 만 발생.
21. 그룹 체크 해제 후 재체크 → 이전 OFF 항목 state 복원 (`_disabledOptionItemIds` 유지).
22. 저장 실패(네트워크) → 기존 `showErrorDialog` 표시, state 보존.

---

## 미구현/보류 항목

없음. spec.md 결정 1~5 모두 구현 완료.

비범위 Follow-up (spec.md 명시):
- 항목 priceDelta 편집 (sub-phase 7 `OptionItemListEditor` 책임)
- 항목 drag-drop reordering (Follow-up F3)
- `MenuOverride` 동일 흐름 확장 (Follow-up 분리)
