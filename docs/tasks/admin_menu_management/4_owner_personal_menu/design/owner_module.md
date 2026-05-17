# Owner 모듈 디자인 명세 — sub-phase 4 (owner_personal_menu)

> 파일 위치: `lib/presentation/owner/store_menu/` (신규), `lib/presentation/owner/my_store/` (갱신)
>
> 참조: sub-phase 1 `brand_module.md` (MasterMenuListPage / MasterMenuFormPage / MasterMenuDetailPage 패턴),
> sub-phase 2 `owner_module.md` (OwnerMyStorePage / _StoreActionButtons 구조)

---

## 1. OwnerMyStorePage 갱신 — "메뉴 관리" CTA 추가

- 파일: `presentation/owner/my_store/my_store_page.dart` (기존 파일 갱신)
- 역할: 기존 OwnerMyStorePage 에서 `_StoreActionButtons` 아래에 "메뉴 관리" 버튼을 추가한다.

### 변경 범위

기존 레이아웃 구조를 **최소 변경**한다. 추가되는 위젯은 `_StoreActionButtons` 아래 단독 행 하나뿐이다.

```
CustomScrollView
  ...
  ├─ _StoreMetricsSection (기존 그대로)
  ├─ SizedBox(height: 20)
  ├─ _StoreActionButtons (기존 — 매장 정보 수정 / 운영 정보 수정)
  ├─ SizedBox(height: 12)           ← 신규 추가
  ├─ _MenuManagementButton (신규)   ← 신규 추가 (조건부 노출)
  ├─ SizedBox(height: 32)
  └─ _DangerZone (기존 그대로)
```

### _MenuManagementButton (신규 위젯)

- 파일: `presentation/owner/my_store/widgets/menu_management_button.dart` 또는 `my_store_page.dart` 내부 private 위젯
- 노출 조건: `store.brandId == null && store.status == EntityApprovalStatus.approved` 를 **모두 충족**할 때만 렌더링. 불충족 시 `SizedBox.shrink()`.

```
SizedBox (width: double.infinity, height: 52)
  └─ ElevatedButton.icon
       icon: Icon(Icons.restaurant_menu_rounded, size: 18, color: AppColors.onPrimary)
       label: Text '메뉴 관리'
       style:
         배경: AppColors.primary
         텍스트: AppColors.onPrimary, fontSize 15, w700
         radius: 14
         elevation: 0
```

- 탭 → `Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerStoreMenuListPage(store: store)))`

### Props

```dart
_MenuManagementButton({
  required StoreEntity store,
})
```

### 인터랙션

| 조건 | 렌더링 |
|---|---|
| `store.brandId == null && store.status == approved` | ElevatedButton 노출 |
| `store.brandId != null` | SizedBox.shrink() — brand 매장 점주는 버튼 비노출 |
| `store.status == pending` | SizedBox.shrink() |
| `store.status == rejected` | SizedBox.shrink() |

---

## 2. OwnerStoreMenuListPage (신규)

- 파일: `presentation/owner/store_menu/owner_store_menu_list_page.dart`
- 역할: 개인 매장의 메뉴 목록 + 카드 인라인 visible 토글 + FAB 메뉴 추가 진입
- 참조 패턴: sub-phase 1 `MasterMenuListPage` — status 배지 / "수정 대기" 라벨 / `ApprovalStatusBadge` 제거

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - title: `'메뉴 관리'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`, elevation 0, surfaceTintColor: transparent
  - leading: `Icons.arrow_back_ios_new_rounded`, color `AppColors.textHeading`
- body: `ListView.builder` (단일 컬럼)
- padding: `EdgeInsets.fromLTRB(16, 8, 16, 100)` (하단 FAB 여백)
- FAB: 우하단 `FloatingActionButton.extended`

### FAB 스타일

```
FloatingActionButton.extended(
  icon: Icon(Icons.add_rounded, size: 22, color: AppColors.onPrimary)
  label: Text '메뉴 추가' (fontSize 15, w700, AppColors.onPrimary)
  backgroundColor: AppColors.primary
  elevation: 2
)
```

- 탭 → `Navigator.push` → `OwnerStoreMenuFormPage(storeId: store.id, mode: create)`

### OwnerStoreMenuCard

```
Card (AppColors.surfaceElevated, radius 16, border AppColors.border 1px, shadow AppColors.primary.withOpacity(0.04))
  └─ InkWell (radius 16, onTap: → OwnerStoreMenuDetailPage)
       └─ Padding(12)
            └─ Row
                 ├─ ClipRRect (radius 10, 72×72) ← 메뉴 이미지
                 ├─ SizedBox(width: 12)
                 └─ Expanded
                      ├─ Row
                      │    ├─ Expanded — Text (메뉴 이름, fontSize 15, w700, AppColors.textHeading, maxLines 1, overflow: ellipsis)
                      │    └─ _InlineVisibleToggle (V7 — 인라인 토글)
                      ├─ SizedBox(height: 4)
                      ├─ Text (설명 1줄, fontSize 13, AppColors.textMuted, maxLines 1, overflow: ellipsis)
                      ├─ SizedBox(height: 8)
                      ├─ Row
                      │    ├─ Text ('₩{basePrice}', fontSize 14, w600, AppColors.textHeading)
                      │    └─ Spacer
                      │    └─ _CardActions (편집 / 복제 아이콘)
                      └─ (tags 있으면) SizedBox(height: 6) + Wrap — _TagChipSmall (읽기 전용, 작은 크기)
```

#### 메뉴 이미지 Placeholder

- 배경: `AppColors.surface`, radius 10, 72×72
- 아이콘: `Icons.local_cafe_outlined`, size 28, `AppColors.textMuted`

#### _InlineVisibleToggle (V7)

- 역할: 카드 우상단 visible 즉시 토글. 토글 후 `UpdateOwnerStoreMenuUseCase` 호출 (visible 만 변경된 partial entity).
- 위젯: `CupertinoSwitch` 또는 `Switch.adaptive`

```
Switch.adaptive(
  value: item.visible,
  onChanged: (v) => ref.read(ownerStoreMenuProvider(storeId).notifier).toggleVisible(item, v),
  activeColor: AppColors.primary,
  activeTrackColor: AppColors.primary.withOpacity(0.3),
  inactiveTrackColor: AppColors.surface,
)
```

- 로딩 중: 스위치 disabled + `CircularProgressIndicator` (크기 16, `AppColors.primary`)
- 오류 시: UI 원복 (이전 visible 값으로 되돌림) + SnackBar `'변경에 실패했어요'`

#### _CardActions (편집 / 복제)

```
Row (gap 4)
  ├─ IconButton(Icons.copy_rounded, size 20, AppColors.textMuted, tooltip: '복제')
  │    탭 → CloneOwnerStoreMenuUseCase → OwnerStoreMenuFormPage(mode: create, prefill: cloned)
  └─ IconButton(Icons.edit_rounded, size 20, AppColors.primary, tooltip: '편집')
       탭 → OwnerStoreMenuFormPage(storeId, mode: edit, item: item)
```

#### Long-press 인터랙션

- 카드 long-press → `showModalBottomSheet` 액션 시트:

```
Container (AppColors.surfaceElevated, radius-top 20)
  └─ SafeArea
       └─ Padding(horizontal 16, vertical 8)
            └─ Column
                 ├─ _BottomSheetHandle (8×4 둥근 바, AppColors.border)
                 ├─ SizedBox(height: 8)
                 ├─ ListTile '편집'
                 │    leading: Icon(Icons.edit_rounded, AppColors.primary)
                 │    title: Text('편집', fontSize 15, AppColors.textBody)
                 │    onTap: → OwnerStoreMenuFormPage(edit)
                 ├─ ListTile '복제'
                 │    leading: Icon(Icons.copy_rounded, AppColors.textMuted)
                 │    title: Text('복제', fontSize 15, AppColors.textBody)
                 │    onTap: → CloneUseCase → OwnerStoreMenuFormPage(create, prefill)
                 └─ ListTile '삭제'
                      leading: Icon(Icons.delete_outline_rounded, AppColors.error)
                      title: Text('삭제', fontSize 15, AppColors.error)
                      onTap: → 삭제 확인 다이얼로그
```

### 삭제 확인 다이얼로그

```
showDialog → AlertDialog
  배경: AppColors.surfaceElevated
  radius: 16
  title: Text('메뉴를 삭제할까요?', fontSize 16, w700, AppColors.textHeading)
  content: Text('삭제된 메뉴는 복구할 수 없어요.', fontSize 14, AppColors.textBody)
  actions:
    TextButton '취소'
      텍스트: AppColors.textMuted, fontSize 14, w500
    ElevatedButton '삭제'
      배경: AppColors.error
      텍스트: AppColors.onPrimary, fontSize 14, w700
      radius: 10
      탭 → DeleteOwnerStoreMenuUseCase → SnackBar '삭제됐어요' + 리스트에서 제거
```

### 상태별 UI

#### Loading

- 3개 shimmer 카드 skeleton:
  ```
  shimmer base: AppColors.surface
  shimmer highlight: AppColors.surfaceElevated
  카드 구조: Row (72×72 사각 radius 10 + Column 3줄 텍스트 skeleton)
  radius: 16, margin bottom 10
  ```

#### Error

- 공통 Error 패턴 (sub-phase 1 common_components.md):
  ```
  Center
    └─ Column
         ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
         ├─ SizedBox(height: 16)
         ├─ Text '메뉴를 불러오지 못했어요' (fontSize 16, w700, AppColors.textHeading)
         ├─ SizedBox(height: 8)
         ├─ Text '잠시 후 다시 시도해주세요' (fontSize 13, AppColors.textMuted)
         ├─ SizedBox(height: 24)
         └─ ElevatedButton '다시 시도' (AppColors.primary, radius 12)
  ```

#### Empty (메뉴 0건)

```
Center
  └─ Column
       ├─ Icon(Icons.local_cafe_outlined, size 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '아직 등록된 메뉴가 없어요' (fontSize 16, w600, AppColors.textHeading)
       ├─ SizedBox(height: 8)
       ├─ Text '+ 버튼을 눌러 첫 메뉴를 등록해보세요' (fontSize 13, AppColors.textMuted)
       ├─ SizedBox(height: 24)
       └─ ElevatedButton '+ 첫 메뉴 등록하기'
            배경: AppColors.primary
            텍스트: AppColors.onPrimary, fontSize 15, w700
            radius: 14
            탭 → OwnerStoreMenuFormPage(mode: create)
```

### 인터랙션 정리

| 동작 | 반응 |
|---|---|
| 카드 탭 | `OwnerStoreMenuDetailPage` push |
| 카드 long-press | 액션 시트 (편집 / 복제 / 삭제) |
| visible 토글 | 즉시 반영, 오류 시 원복 |
| 편집 아이콘 탭 | `OwnerStoreMenuFormPage(mode: edit, item)` push |
| 복제 아이콘 탭 | `CloneOwnerStoreMenuUseCase` → `OwnerStoreMenuFormPage(mode: create, prefill)` push |
| 삭제 (액션 시트) | 확인 다이얼로그 → `DeleteOwnerStoreMenuUseCase` → SnackBar `'삭제됐어요'` |
| FAB "메뉴 추가" | `OwnerStoreMenuFormPage(mode: create)` push |

---

## 3. OwnerStoreMenuFormPage (신규)

- 파일: `presentation/owner/store_menu/owner_store_menu_form_page.dart`
- 역할: 메뉴 등록(mode=create) / 수정(mode=edit) / 복제 prefill(mode=create, prefill 있음) 통합 폼
- 참조 패턴: sub-phase 1 `MasterMenuFormPage` — 차이점 아래 명시

### sub-phase 1 MasterMenuFormPage 대비 변경점

| 항목 | MasterMenuFormPage | OwnerStoreMenuFormPage |
|---|---|---|
| 하단 버튼 텍스트 | `'제출 (검토 요청)'` | `'저장'` |
| 저장 후 SnackBar | `'검토 요청을 보냈어요'` | `'저장됐어요'` |
| 상태 회귀 다이얼로그 | 노출 (가격 변경 시 priceOverride 알림) | 미노출 (즉시 반영이므로 불필요) |
| 폼 상단 배너 | 없음 | 즉시 반영 안내 배너 (success 톤) |
| OptionGroupSelector | master scope only | master + store scope (storeId 전달) |
| disabledOption* / soldOut 필드 | 미해당 | 미노출 (sub-phase 5 활성화) |
| Core/Operation 분리 안내 | 노출 (sub-phase 1 결정 J) | 미노출 (V2 통합 결정) |
| ApprovalStatusBadge | 노출 | 미노출 |

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.close_rounded` (create/복제 모드) / `Icons.arrow_back_ios_new_rounded` (edit 모드)
  - leading color: `AppColors.textHeading`
  - title: `'메뉴 추가'` (create) / `'메뉴 수정'` (edit) / `'메뉴 복제'` (create + prefill)
  - title style: fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`, elevation 0, surfaceTintColor: transparent
- body: `SingleChildScrollView` + `Padding(horizontal 20)`
- bottomNavigationBar: 저장 버튼 고정 (_SubmitBar)

### 폼 섹션 (위→아래)

```
Column
  ├─ SizedBox(height: 12)
  ├─ [배너] 즉시 반영 안내
  ├─ SizedBox(height: 16)
  ├─ [섹션] 메뉴 이미지
  ├─ _SectionDivider
  ├─ [섹션] 기본 정보 (이름 / 설명)
  ├─ _SectionDivider
  ├─ [섹션] 가격
  ├─ _SectionDivider
  ├─ [섹션] 카테고리
  ├─ _SectionDivider
  ├─ [섹션] 태그
  ├─ _SectionDivider
  ├─ [섹션] 메뉴 노출
  ├─ _SectionDivider
  ├─ [섹션] 노출 순서
  ├─ _SectionDivider
  ├─ [섹션] 옵션 그룹
  └─ SizedBox(height: 40)
```

`_SectionDivider`: `Divider(height: 32, color: AppColors.border, thickness: 1)` — sub-phase 1 패턴 동일

#### 섹션 헤더 패턴

- fontSize 13, w600, `AppColors.textMuted`, padding bottom 10 — sub-phase 1 패턴 동일

### 즉시 반영 안내 배너 (폼 최상단)

```
Container
  decoration:
    color: AppColors.success.withOpacity(0.08)
    borderRadius: 12
    border: AppColors.success.withOpacity(0.3) 1px
  Padding(horizontal 14, vertical 10)
    └─ Row
         ├─ Icon(Icons.check_circle_outline_rounded, size 16, AppColors.success)
         ├─ SizedBox(width: 8)
         └─ Expanded
              └─ Text('저장 즉시 반영돼요.', fontSize 12, AppColors.success, height 1.4)
```

### 메뉴 이미지 섹션

- `ImageUploadField` (메뉴 이미지 variant, height 180) — sub-phase 1 common_components.md 그대로 재사용
- Firebase Storage 경로: `menu_images/store/{storeId}/{menuItemId}/{timestamp}_{filename}`

### 기본 정보 섹션 (이름 / 설명)

이름 필드:
- TextFormField, maxLength 40, 필수
- 배경: `AppColors.surfaceElevated`, border `AppColors.border`, radius 10
- 포커스 border: `AppColors.primary`
- hint: `'메뉴 이름을 입력해주세요'`, `AppColors.textMuted`
- 텍스트: `AppColors.textBody`, fontSize 15

설명 필드:
- TextFormField, maxLines 3, minLines 2, 선택
- hint: `'메뉴 설명을 입력해주세요 (선택)'`, `AppColors.textMuted`
- 나머지 스타일 동일

### 가격 섹션

- TextFormField, keyboardType: number, 필수 (0보다 큰 값)
- prefix: `Text('₩ ', fontSize 15, AppColors.textMuted)`
- hint: `'0'`
- 스타일: 기본 정보 섹션과 동일

### 카테고리 섹션

메인 카테고리 (단일 선택):
```
Wrap (spacing 8)
  └─ [각 mainCategory] FilterChip 스타일
       선택: 배경 AppColors.primary, 텍스트 AppColors.onPrimary, radius 999
       미선택: 배경 AppColors.surfaceElevated, border AppColors.border 1px, 텍스트 AppColors.textBody, radius 999
       height: 36, padding horizontal 14
```

메인 카테고리 목록: `'커피'`, `'논커피'`, `'에이드'`, `'스무디'`, `'티'`, `'기타'`

서브 카테고리 (mainCategory 선택 후 노출):
- `DropdownButtonFormField<String>`
- hint: `'서브 카테고리 (선택)'`, `AppColors.textMuted`
- 배경: `AppColors.surfaceElevated`, border `AppColors.border`, radius 10

### 태그 섹션

- `TagChipsSelector` 위젯 재사용 — sub-phase 1 common_components.md 그대로
- 다중 선택, 최대 3개 (`recommended` / `new` / `best`)

### 메뉴 노출 섹션

- `VisibilityToggle` 위젯 재사용 — sub-phase 1 common_components.md 그대로
- 라벨: `'메뉴 노출 여부'`, 도움말: `'비활성화 시 고객에게 노출되지 않습니다'`

### 노출 순서 섹션

- TextFormField, keyboardType: number, 선택
- hint: `'0'`
- 도움말: `'숫자가 낮을수록 앞에 노출됩니다'`, fontSize 12, `AppColors.textMuted`

### 옵션 그룹 섹션

- `OptionGroupSelector` 위젯 확장 버전 — `storeId` 전달로 master + store 양쪽 노출
- 상세: [`common_components.md - OptionGroupSelector 확장`](common_components.md)

### 하단 저장 버튼 (_SubmitBar)

```
Container (bottomNavigationBar)
  decoration: color AppColors.surfaceElevated, border-top AppColors.border 1px
  └─ SafeArea(top: false)
       └─ Padding(horizontal 20, vertical 12)
            └─ SizedBox(width: 전체, height: 52)
                 └─ ElevatedButton '저장'
```

활성 (이미지 + 이름 + 가격(>0) + mainCategory 선택 완료):
- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`, fontSize 16, w700
- radius: 14

비활성 (필수 항목 미충족):
- 배경: `AppColors.surface`
- 텍스트: `AppColors.textMuted`, fontSize 16, w700
- border: `AppColors.border` 1px

로딩 (저장 중):
- 배경: `AppColors.primary`
- `SizedBox(20×20) CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)`

### 인터랙션

| 동작 | 반응 |
|---|---|
| 필수 미충족 + 저장 탭 | SnackBar `'필수 항목을 모두 입력해주세요'` |
| 변경 없음 (edit 모드) | UseCase 호출 없이 Navigator.pop |
| 저장 성공 (create) | `CreateOwnerStoreMenuUseCase` → SnackBar `'저장됐어요'` + Navigator.pop |
| 저장 성공 (edit) | `UpdateOwnerStoreMenuUseCase` → SnackBar `'저장됐어요'` + Navigator.pop |
| 이미지 5MB 초과 | SnackBar `'이미지 용량이 5MB를 초과했습니다'`, 저장 차단 |
| 이미지 업로드 실패 | SnackBar `'이미지 업로드에 실패했어요. 다시 시도해주세요'`, 저장 차단 |
| 저장 실패 (네트워크 등) | SnackBar `'저장에 실패했어요. 다시 시도해주세요'` |

### 복제 모드 prefill 규칙

- `name`: `'{원본 이름} 복사'`
- `imageUrl`: `''` (빈 문자열 — 이미지는 사용자가 다시 업로드)
- `status`: `approved` (자동)
- 승인 메타: 모두 null
- 나머지 필드: 원본 값 그대로

---

## 4. OwnerStoreMenuDetailPage (신규)

- 파일: `presentation/owner/store_menu/owner_store_menu_detail_page.dart`
- 역할: 메뉴 상세 읽기 전용 뷰 + 수정 / 복제 / 삭제 진입
- 참조 패턴: sub-phase 1 `MasterMenuDetailPage` — status 배너 / 승인 메타 섹션 완전 제거

### sub-phase 1 MasterMenuDetailPage 대비 변경점

| 항목 | MasterMenuDetailPage | OwnerStoreMenuDetailPage |
|---|---|---|
| `ApprovalStatusBadge` | 노출 | 미노출 |
| 승인 메타 섹션 (submittedAt / approvedAt / rejectedReason) | 노출 | 미노출 |
| 반려 사유 섹션 | 노출 | 미노출 |
| PopupMenuButton 항목 | 수정 / 복제 / 삭제 | 수정 / 복제 / 삭제 (동일) |

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.arrow_back_ios_new_rounded`, color `AppColors.textHeading`
  - title: 메뉴 이름 (fontSize 16, w700, `AppColors.textHeading`, overflow: ellipsis)
  - backgroundColor: `AppColors.background`, elevation 0, surfaceTintColor: transparent
  - actions: `PopupMenuButton` (⋮ 아이콘, color `AppColors.textHeading`)
    - 항목: `'수정'` / `'복제'` / `'삭제'` (color: `AppColors.error`)
- body: `SingleChildScrollView`

### 주요 섹션 (위→아래)

```
SingleChildScrollView
  └─ Column
       ├─ [이미지 영역] width: 전체, height: 220
       ├─ [기본 정보 섹션] Padding(16)
       ├─ SizedBox(height: 12)
       ├─ [카테고리 / 태그 섹션] _DetailSectionCard
       ├─ SizedBox(height: 12)
       ├─ [가격 섹션] _DetailSectionCard
       └─ SizedBox(height: 12)
       └─ [옵션 그룹 섹션] _DetailSectionCard
       └─ SizedBox(height: 40)
```

### 이미지 영역

- 전체 너비, height 220
- imageUrl 있음: `Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: 220)`
- imageUrl 없음:
  ```
  Container (width: 전체, height: 220, color: AppColors.surface)
    └─ Center
         └─ Icon(Icons.local_cafe_outlined, size 56, AppColors.textMuted)
  ```

### 기본 정보 섹션

```
Padding(horizontal 16, vertical 16)
  └─ Column
       ├─ Text(메뉴 이름, fontSize 22, w700, AppColors.textHeading)
       ├─ SizedBox(height: 8)
       └─ Text(설명, fontSize 14, AppColors.textBody, height 1.5)
            (설명 없으면 '설명이 없어요.', AppColors.textMuted, fontSize 13, italic)
```

> `ApprovalStatusBadge` 는 이 영역에 **포함하지 않는다** (D1 결정).

### _DetailSectionCard 패턴

```
Container (AppColors.surfaceElevated, radius 12, border AppColors.border 1px, padding 16, margin horizontal 16)
```

### 카테고리 / 태그 섹션 (_DetailSectionCard)

```
_DetailSectionCard
  └─ Column
       ├─ _InfoRow('카테고리', '$mainCategory${subCategoryId != null ? ' > $subCategoryId' : ''}')
       ├─ SizedBox(height: 8)
       ├─ _InfoRow('노출 순서', '$displayOrder')
       ├─ SizedBox(height: 8)
       ├─ _InfoRow('메뉴 노출', item.visible ? '노출 중' : '숨김')
       └─ (tags 비어 있지 않으면) SizedBox(height: 12) + Wrap(spacing 6) — TagChip 읽기 전용
```

`_InfoRow`:
```
Row (mainAxisAlignment: spaceBetween)
  ├─ Text(label, fontSize 13, AppColors.textMuted)
  └─ Text(value, fontSize 13, w500, AppColors.textBody)
```

### 가격 섹션 (_DetailSectionCard)

```
_DetailSectionCard
  └─ Row (mainAxisAlignment: spaceBetween)
       ├─ Text('기본가', fontSize 13, AppColors.textMuted)
       └─ Text('₩{basePrice}', fontSize 20, w700, AppColors.textHeading)
```

### 옵션 그룹 섹션 (_DetailSectionCard)

- 섹션 제목: `'옵션 그룹'`, fontSize 13, w600, `AppColors.textMuted`, padding bottom 8
- 선택된 optionGroupRefs 목록 (읽기 전용):
  ```
  ListView.builder (shrinkWrap: true, physics: NeverScrollableScrollPhysics)
    └─ [각 optionGroupRef] ListTile (dense: true)
         title: 옵션 그룹 이름, fontSize 14, w500, AppColors.textBody
         subtitle: scope == 'master' ? '마스터 옵션' : '매장 한정 옵션'
                   (fontSize 11, AppColors.textMuted)
  ```
- 옵션 그룹 없으면: `Text('선택된 옵션 그룹 없음', fontSize 13, AppColors.textMuted)`, padding 16, 중앙 정렬

### 액션 (PopupMenuButton)

```
PopupMenuButton (아이콘: Icons.more_vert_rounded, color: AppColors.textHeading)
  ├─ PopupMenuItem '수정'
  │    탭 → OwnerStoreMenuFormPage(mode: edit, item: item) push
  ├─ PopupMenuItem '복제'
  │    탭 → CloneOwnerStoreMenuUseCase → OwnerStoreMenuFormPage(mode: create, prefill: cloned) push
  └─ PopupMenuItem '삭제' (textStyle: AppColors.error)
       탭 → 삭제 확인 다이얼로그
```

삭제 확인 다이얼로그 스타일: OwnerStoreMenuListPage 의 삭제 다이얼로그와 동일.

삭제 성공 시:
- SnackBar `'삭제됐어요'` + `Navigator.pop` (상세 페이지 pop)

### 상태별 UI

#### Loading

- body 전체: `Center(child: CircularProgressIndicator(color: AppColors.primary))`

#### Error

- body 전체: 공통 Error 패턴
  ```
  Center
    └─ Column
         ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
         ├─ SizedBox(height: 16)
         ├─ Text '메뉴를 불러오지 못했어요' (fontSize 16, w700, AppColors.textHeading)
         ├─ SizedBox(height: 8)
         ├─ Text '잠시 후 다시 시도해주세요' (fontSize 13, AppColors.textMuted)
         ├─ SizedBox(height: 24)
         └─ ElevatedButton '다시 시도' (AppColors.primary, radius 12)
  ```

#### Empty (메뉴 없음 — 삭제된 케이스)

- body 전체:
  ```
  Center
    └─ Column
         ├─ Icon(Icons.local_cafe_outlined, 48, AppColors.textMuted)
         ├─ SizedBox(height: 16)
         ├─ Text '메뉴를 찾을 수 없어요' (fontSize 16, w600, AppColors.textHeading)
         ├─ SizedBox(height: 8)
         ├─ Text '삭제되었거나 존재하지 않는 메뉴예요.' (fontSize 13, AppColors.textMuted)
         ├─ SizedBox(height: 24)
         └─ ElevatedButton '목록으로 돌아가기'
              배경: AppColors.primary
              텍스트: AppColors.onPrimary
              탭 → Navigator.pop
  ```

---

## 5. 화면 흐름 요약

```
OwnerMyStorePage
  (store.brandId==null && approved 일 때만)
  └─ [메뉴 관리] ElevatedButton 탭
       └─ OwnerStoreMenuListPage
            ├─ 카드 탭 → OwnerStoreMenuDetailPage
            │    └─ PopupMenu: 수정 / 복제 / 삭제
            │         ├─ 수정 → OwnerStoreMenuFormPage(edit)
            │         ├─ 복제 → OwnerStoreMenuFormPage(create, prefill)
            │         └─ 삭제 → 다이얼로그 → 삭제 후 pop
            ├─ 카드 long-press → BottomSheet: 편집 / 복제 / 삭제
            ├─ 카드 visible 토글 → 즉시 반영
            └─ FAB "메뉴 추가" → OwnerStoreMenuFormPage(create)
```
