# 공통 컴포넌트 디자인 명세 — sub-phase 4 (owner_personal_menu)

> 본 파일은 sub-phase 4 에서 **확장하거나 신규로 정의하는 컴포넌트**만 다룬다.
>
> 변경 없이 그대로 재사용하는 컴포넌트는 아래 재사용 표를 참고하고, 원본 명세는
> sub-phase 1 [`common_components.md`](../../1_brand_master/design/common_components.md) 를 따른다.

---

## 재사용 위젯 표 (변경 없음)

| 위젯 | 원본 위치 | sub-phase 4 에서의 역할 | 비고 |
|---|---|---|---|
| `ImageUploadField` | `presentation/common/widgets/image_upload_field.dart` | `OwnerStoreMenuFormPage` 의 메뉴 이미지 섹션 | 높이 180, 메뉴 이미지 variant |
| `TagChipsSelector` | `presentation/common/widgets/tag_chips_selector.dart` | `OwnerStoreMenuFormPage` 의 태그 섹션 | 다중 선택, 변경 없음 |
| `VisibilityToggle` | `presentation/brand/master_menu/widgets/visibility_toggle.dart` | `OwnerStoreMenuFormPage` 의 메뉴 노출 섹션 | 라벨 / 도움말 텍스트 동일 |
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | **본 sub-phase 에서 미사용** | 개인 매장 메뉴는 항상 approved, 배지 미노출 (D1 결정) |
| `RejectReasonDialog` | `presentation/common/widgets/reject_reason_dialog.dart` | **본 sub-phase 에서 미사용** | admin 승인 게이트 없음 |

---

## 1. OptionGroupSelector 확장 (V6)

- 원본 파일: `presentation/brand/master_menu/widgets/option_group_selector.dart`
- 역할: 옵션 그룹 다중 선택. 기존은 master scope only. 본 sub-phase 에서 `storeId` 를 받으면 store scope 옵션도 함께 노출.
- 수정 방식: 원본 파일의 Props 확장 + 렌더링 분기 추가. 마스터 메뉴 폼(storeId=null)에서는 기존 동작 유지.

### Props 변경

```dart
OptionGroupSelector({
  required List<OptionGroupEntity> masterGroups,
  List<OptionGroupEntity> storeGroups = const [],   // 신규 — default 빈 리스트
  String? storeId,                                   // 신규 — null 이면 기존 동작 (master only)
  required List<String> selectedIds,
  required ValueChanged<List<String>> onChanged,
})
```

- `storeId == null` → 기존 동작 그대로 (master scope 만 노출, 기존 마스터 메뉴 폼에 영향 없음)
- `storeId != null` → master + store 양쪽 섹션 노출

### 위젯 구조 (storeId != null 인 경우)

```
Column
  ├─ [마스터 옵션 섹션 헤더]
  │    Text '마스터 옵션' (fontSize 12, w600, AppColors.textMuted, padding vertical 8)
  ├─ ListView.builder (shrinkWrap: true, physics: NeverScrollableScrollPhysics)
  │    └─ [각 masterGroup] _OptionGroupItem(group, isStore: false)
  ├─ SizedBox(height: 16)
  ├─ [매장 옵션 섹션 헤더]
  │    Text '매장 한정 옵션' (fontSize 12, w600, AppColors.textMuted, padding vertical 8)
  └─ (storeGroups 비어 있으면) Empty placeholder
  │    Text '등록된 매장 옵션 그룹이 없어요.' (fontSize 13, AppColors.textMuted, padding 16)
  └─ (storeGroups 있으면) ListView.builder (shrinkWrap: true, physics: NeverScrollableScrollPhysics)
       └─ [각 storeGroup] _OptionGroupItem(group, isStore: true)
```

### _OptionGroupItem 스타일 (CheckboxListTile 커스텀)

```
Container (AppColors.surfaceElevated, radius 10, margin bottom 8, border AppColors.border 1px)
  └─ CheckboxListTile
       title: 옵션 그룹 이름 (fontSize 14, w500, AppColors.textBody)
       subtitle: isStore ? '매장 한정 옵션' : '마스터 옵션'
                 (fontSize 11, AppColors.textMuted)
       value: selectedIds.contains(group.id)
       onChanged: (checked) → onChanged(updated selectedIds)
       activeColor: AppColors.primary
       checkboxShape: RoundedRectangleBorder(radius 4)
       controlAffinity: ListTileControlAffinity.leading
```

### 빈 상태 (master scope 목록이 비어있는 경우)

- sub-phase 1 패턴 동일:
  ```
  Text '등록된 옵션 그룹이 없어요.' (fontSize 13, AppColors.textMuted, 중앙 정렬, padding 24)
  ```

### 로딩 상태 (옵션 그룹 fetch 중)

- sub-phase 1 패턴 동일:
  ```
  shimmer base: AppColors.surface
  shimmer highlight: AppColors.surfaceElevated
  3개 항목 skeleton (height 52, radius 10)
  ```

### storeId == null 인 경우 (기존 마스터 메뉴 폼 — 변경 없음)

- `masterGroups` 만 렌더링
- 섹션 헤더 없음 (기존 동작 그대로)
- subtitle: `'마스터 옵션'` (기존 동작 그대로)

### 개발자 전달 메모

- `OwnerStoreMenuFormPage` 에서 호출 시:
  ```dart
  OptionGroupSelector(
    masterGroups: masterOptionGroups,        // provider: masterOptionGroupsProvider
    storeGroups: storeOptionGroups,          // provider: storeOptionGroupsProvider(storeId)
    storeId: storeId,
    selectedIds: formState.optionGroupRefs.map((r) => r.id).toList(),
    onChanged: (ids) => formNotifier.updateOptionGroupRefs(ids),
  )
  ```
- `MasterMenuFormPage` 에서 호출 시 (기존 코드 변경 불필요):
  ```dart
  OptionGroupSelector(
    masterGroups: masterOptionGroups,
    // storeGroups, storeId 미전달 → default 빈 리스트 + null → 기존 동작
    selectedIds: ...,
    onChanged: ...,
  )
  ```
- Provider 추가 필요: `storeOptionGroupsProvider(storeId)` — `OptionGroupRepository.getOptionGroupsForStore(storeId)` 호출

---

## 2. _MenuManagementButton (OwnerMyStorePage 전용 신규 위젯)

- 원본 파일 없음 (신규)
- 위치: `presentation/owner/my_store/widgets/menu_management_button.dart` 또는 `my_store_page.dart` 내부 private 위젯
- 역할: 개인 매장 + approved 점주에게만 노출하는 "메뉴 관리" 진입 버튼

### Props

```dart
_MenuManagementButton({
  required StoreEntity store,
})
```

### 렌더링 분기

| 조건 | 렌더링 |
|---|---|
| `store.brandId == null && store.status == EntityApprovalStatus.approved` | ElevatedButton |
| 그 외 모든 경우 | `SizedBox.shrink()` |

### 위젯 구조

```
SizedBox(width: double.infinity, height: 52)
  └─ ElevatedButton.icon(
       icon: Icon(Icons.restaurant_menu_rounded, size: 18, color: AppColors.onPrimary),
       label: Text('메뉴 관리', fontSize 15, w700, AppColors.onPrimary),
       style: ElevatedButton.styleFrom(
         backgroundColor: AppColors.primary,
         elevation: 0,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
       ),
       onPressed: () => Navigator.push(
         context,
         MaterialPageRoute(builder: (_) => OwnerStoreMenuListPage(store: store)),
       ),
     )
```

---

## 3. 상태 UI 통합 정의

모든 신규 화면(OwnerStoreMenuListPage / OwnerStoreMenuFormPage / OwnerStoreMenuDetailPage)에 적용.
sub-phase 1 패턴과 동일하나 문구만 화면별로 다르다.

### Loading

| 화면 | 표시 방식 |
|---|---|
| OwnerStoreMenuListPage | 3개 shimmer 카드 skeleton (72×72 사각 + 텍스트 3줄) |
| OwnerStoreMenuDetailPage | `Center(child: CircularProgressIndicator(color: AppColors.primary))` |
| OwnerStoreMenuFormPage | 저장 버튼 내부 CircularProgressIndicator (저장 중 상태) |

shimmer:
- base: `AppColors.surface`
- highlight: `AppColors.surfaceElevated`
- progress indicator color: `AppColors.primary`

### Error

모든 화면 공통 패턴:
```
Center
  └─ Column
       ├─ Icon(Icons.error_outline_rounded, size 48, AppColors.error)
       ├─ SizedBox(height: 16)
       ├─ Text (화면별 에러 제목, fontSize 16, w700, AppColors.textHeading)
       ├─ SizedBox(height: 8)
       ├─ Text '잠시 후 다시 시도해주세요' (fontSize 13, AppColors.textMuted, 중앙 정렬)
       ├─ SizedBox(height: 24)
       └─ ElevatedButton '다시 시도'
            배경: AppColors.primary, 텍스트: AppColors.onPrimary, radius 12, padding horizontal 24 vertical 12
```

화면별 에러 제목:

| 화면 | 에러 제목 |
|---|---|
| OwnerStoreMenuListPage | `'메뉴를 불러오지 못했어요'` |
| OwnerStoreMenuDetailPage | `'메뉴를 불러오지 못했어요'` |
| OwnerStoreMenuFormPage | 저장 실패는 SnackBar 처리, 에러 페이지 없음 |

### Empty

| 화면 | 아이콘 | 안내 문구 | CTA |
|---|---|---|---|
| OwnerStoreMenuListPage (메뉴 0건) | `Icons.local_cafe_outlined`, 56, `AppColors.textMuted` | `'아직 등록된 메뉴가 없어요'` | `'+ 첫 메뉴 등록하기'` → OwnerStoreMenuFormPage(create) |
| OwnerStoreMenuDetailPage (삭제된 케이스) | `Icons.local_cafe_outlined`, 48, `AppColors.textMuted` | `'메뉴를 찾을 수 없어요'` | `'목록으로 돌아가기'` → Navigator.pop |

---

## 4. SnackBar 스타일 통일

sub-phase 4 에서 사용하는 SnackBar 는 모두 아래 스타일을 따른다.

| 종류 | 배경 색상 | 텍스트 색상 | 문구 예시 |
|---|---|---|---|
| 성공 | `AppColors.primary.withOpacity(0.9)` | `AppColors.onPrimary` | `'저장됐어요'`, `'삭제됐어요'` |
| 경고 / 실패 | `AppColors.error` | `AppColors.onPrimary` | `'이미지 용량이 5MB를 초과했습니다'`, `'권한이 없습니다'` |
| 일반 안내 | `AppColors.textHeading.withOpacity(0.9)` | `AppColors.onPrimary` | `'필수 항목을 모두 입력해주세요'` |

duration: `Duration(seconds: 2)` (표준)

---

## 5. 다이얼로그 스타일 통일

모든 확인 다이얼로그(삭제 등) 공통 스타일:

```
showDialog → Dialog (custom) 또는 AlertDialog
  배경: AppColors.surfaceElevated
  radius: 16
  내부 padding: horizontal 24, vertical 24
  제목: fontSize 16, w700, AppColors.textHeading
  내용: fontSize 14, AppColors.textBody
  버튼 영역:
    TextButton '취소'
      텍스트: AppColors.textMuted, w500, fontSize 14
    ElevatedButton (확인 / 삭제)
      삭제: 배경 AppColors.error, 텍스트 AppColors.onPrimary, w700, fontSize 14, radius 10
```

---

## 6. 개발자 전달 특이사항 (공통 컴포넌트)

1. **OptionGroupSelector 파라미터 확장**: 기존 `masterGroups`, `selectedIds`, `onChanged` Props 에 `storeGroups: []`, `storeId: null` 을 optional 로 추가. default 값이 기존 동작을 보존하므로 `MasterMenuFormPage` 의 호출부 코드 변경 불필요.

2. **storeOptionGroupsProvider(storeId) 신규 등록 필요**: `presentation/owner/providers/owner_store_menu_providers.dart` 에 `OptionGroupRepository.getOptionGroupsForStore(storeId)` 를 wrapping 하는 Provider 추가. fetch 실패 시 빈 리스트 fallback (메뉴 저장 자체는 막지 않음 — 옵션 그룹은 선택 사항).

3. **ApprovalStatusBadge 미사용 확인**: `OwnerStoreMenuListPage` / `OwnerStoreMenuFormPage` / `OwnerStoreMenuDetailPage` 세 화면 모두에서 `ApprovalStatusBadge` import 및 사용 금지. sub-phase 1 코드를 복사할 때 이 부분이 가장 누락되기 쉬운 포인트.

4. **_InlineVisibleToggle 로딩/원복 로직**: visible 토글 후 API 결과를 기다리는 동안 Switch 를 disabled 처리하고, 실패 시 이전 값으로 복원해야 한다. StateNotifier / AsyncNotifier 의 `optimistic update` 패턴 또는 별도 `isTogglingVisible` 상태 변수로 처리.

5. **복제 prefill 이미지 처리**: 복제 시 `imageUrl = ''` 로 설정하여 `ImageUploadField` 가 placeholder 상태로 시작하도록 한다. 원본 이미지를 그대로 복사하지 않는다 (V8 결정).

6. **변경 없음 감지 (edit 모드)**: `OwnerStoreMenuFormPage` 에서 편집 모드 진입 시 원본 entity 와 현재 폼 상태를 비교하여 변경 없으면 `UpdateOwnerStoreMenuUseCase` 호출 없이 `Navigator.pop` 만 수행. `MenuItemEntity.==` 또는 freezed `copyWith` + 비교 로직 활용.
