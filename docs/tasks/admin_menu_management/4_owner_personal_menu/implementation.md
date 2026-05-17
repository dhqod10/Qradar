# sub-phase 4 — owner_personal_menu 구현 내역

## 개요

- 구현 목적: `store.brandId == null` 인 개인 매장 점주가 메뉴를 직접 CRUD 할 수 있도록 한다. admin 승인 게이트 없이 저장 즉시 `status=approved` 가 박히며 customer 측에 즉시 반영된다.
- 기준 문서:
  - `docs/tasks/admin_menu_management/4_owner_personal_menu/spec.md`
  - `docs/tasks/admin_menu_management/4_owner_personal_menu/design.md`
- 핵심 정책: 개인 매장 메뉴는 admin 승인 게이트 없음. RepositoryImpl 의 `brandId` 분기로 개인 매장 분기(status=approved)와 브랜드 매장 분기(status=pending, sub-phase 3 동작 보존)를 공존시킨다.

---

## 구현 파일 목록

### 신규 파일

- `lib/presentation/owner/store_menu/owner_store_menu_list_page.dart` — 개인 매장 메뉴 목록 화면. FAB "메뉴 추가", 카드 인라인 visible 토글(V7), long-press 액션 시트(편집/복제/삭제), shimmer 로딩.
- `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` — 메뉴 등록/수정/복제 통합 폼. `editItem`/`prefillItem` nullable 파라미터로 모드 분기. 즉시 반영 배너(D5).
- `lib/presentation/owner/store_menu/owner_store_menu_detail_page.dart` — 메뉴 상세 + `PopupMenuButton` 액션(수정/복제/삭제). status 배지/승인 메타 미노출(D1).
- `lib/presentation/owner/providers/owner_store_menu_providers.dart` — UseCase 5종 Provider + `ownerStoreMenusProvider` StreamProvider.family + 옵션 그룹 FutureProvider.

### 수정 파일

- `lib/data/repositories/menu_item_repository_impl.dart` — 생성자에 `StoreRemoteDataSource? storeRemoteDataSource` 추가(optional). `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `deleteStoreOnlyMenu` 에 `_fetchStoreBrandId` + `_assertOwnerOfPersonalStore` 적용. brandId 분기 로직 삽입.
- `lib/presentation/brand/master_menu/widgets/option_group_selector.dart` — `storeGroups`, `storeId` optional props 추가(V6). storeId 비null 시 마스터/매장 한정 옵션 섹션 헤더 구분.
- `lib/presentation/owner/my_store/my_store_page.dart` — `_MenuManagementButton` 위젯 추가(D3). 노출 조건: `store.brandId == null && store.status == EntityApprovalStatus.approved`.

### 재사용 파일 (변경 없음)

- `lib/domain/entities/menu_item_entity.dart` (sub-phase 1 확장 완료)
- `lib/domain/repositories/menu_item_repository.dart` — 시그니처 불변. `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `updateStoreOnlyMenuOperation` / `deleteStoreOnlyMenu` 그대로.
- `lib/domain/usecases/create_owner_store_menu_use_case.dart`
- `lib/domain/usecases/update_owner_store_menu_use_case.dart`
- `lib/domain/usecases/delete_owner_store_menu_use_case.dart`
- `lib/domain/usecases/clone_owner_store_menu_use_case.dart`
- `lib/domain/usecases/watch_owner_store_menus_use_case.dart`
- `lib/data/models/menu_item_model.dart` (변경 없음)
- `lib/data/datasources/remote/menu_item_remote_data_source.dart` (변경 없음)
- `lib/presentation/common/widgets/image_upload_field.dart`
- `lib/presentation/common/widgets/tag_chips_selector.dart`
- `lib/presentation/brand/master_menu/widgets/visibility_toggle.dart`

---

## 주요 결정사항

### V1. Repository 메서드 — sub-phase 1/3 의 기존 4종 메서드 재사용 + RepositoryImpl 내부 brandId 분기

- 채택: **(b) 재사용**. `MenuItemRepository` 시그니처 변경 없음. `MenuItemRepositoryImpl` 의 `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `deleteStoreOnlyMenu` 내부에서 `_fetchStoreBrandId(storeId)` private helper 로 매장의 brandId 를 fetch 한 뒤 분기.
- 분기 결과:
  - `brandId == null` (개인 매장) → status=approved 강제, 승인 메타 모두 null, ownership 검증(`_assertOwnerOfPersonalStore`)
  - `brandId != null` (브랜드 매장) → sub-phase 3 동작 그대로 (status=pending, brand uid, role 검증)
- 의존성: 생성자에 `StoreRemoteDataSource? storeRemoteDataSource` 추가(optional). 기존 sub-phase 1/3 DI 는 storeRemoteDataSource 없이 동작하므로 optional 처리로 하위 호환 유지.

### V2. 결정 J 적용 (Core/Operation 분리) — 통합 채택

- 개인 매장은 admin 승인 게이트 없음. Core/Operation 분리의 의미(status 회귀 vs 보존)가 사라짐.
- 폼 저장 시 `updateStoreOnlyMenuCore` 단일 호출. 인라인 visible 토글도 `updateStoreOnlyMenuCore` 를 통해 처리.
- `updateStoreOnlyMenuOperation` 은 brand 매장용(sub-phase 3)이 계속 사용하므로 시그니처 유지, 본 sub-phase UseCase 는 호출하지 않음.

### V3. ownership 검증 — `_assertOwnerOfPersonalStore` private helper

- 구현 위치: `MenuItemRepositoryImpl` line ~294-311
- 검증 로직:
  1. `role == 'admin'` → 무조건 통과
  2. `storeRemoteDataSource == null` → 통과 (테스트 환경 안전망)
  3. `storeModel == null` → `StateError('매장 정보를 불러올 수 없습니다.')`
  4. `storeModel.brandId != null` → `StateError('권한이 없습니다. 브랜드 매장의 메뉴는 브랜드 본사가 관리합니다.')`
  5. `storeModel.ownerId != uid` → `StateError('권한이 없습니다. 본인 매장만 관리할 수 있습니다.')`

### V4. brand 매장 점주의 메뉴 진입 차단 — UI + Repository 양쪽 가드

- UI: `_MenuManagementButton` 의 `isPersonalApproved` 조건(`store.brandId == null && store.status == EntityApprovalStatus.approved`). 조건 불만족 시 `SizedBox.shrink()` 반환.
- Repository: `_assertOwnerOfPersonalStore` 에서 `storeModel.brandId != null` 체크로 안전망 제공.

### V5. 이미지 업로드 정책 — sub-phase 1 패턴 그대로

- `ImageUploadField` + `StorageDataSource.uploadStoreMenuImage` 재사용.
- 경로: `menu_images/store/{storeId}/{menuItemId}/{timestamp}_{filename}`
- 5MB 초과: `ArgumentError` catch → 에러 스낵바, 메뉴 저장 차단.
- 이미지 실패: 일반 예외 catch → 에러 스낵바, 저장 차단.
- 이미지 삭제: `deleteStoreOnlyMenu` 에서는 Storage 정리 미포함(spec 에서 삭제 시 이미지 정리 언급이나 현재 구현에서 dataSource.deleteStoreOnly 직접 호출). 이미지 정리는 미구현/보류 항목 참조.

### V6. 옵션 그룹 선택 UI — master + store 양쪽 노출

- `OptionGroupSelector` 에 `storeGroups: List<OptionGroupEntity>` (default `const []`), `storeId: String?` (default null) 파라미터 추가.
- `storeId != null` 조건에서 `_buildWithSections()` 호출 → "마스터 옵션" / "매장 한정 옵션" 헤더 구분.
- `storeId == null` 조건은 기존 `_buildGroupList(masterGroups)` 그대로 → 기존 마스터 메뉴 폼 호출부 영향 없음.
- 기존 호출부: `optionGroups` positional named parameter 유지(`masterGroups = optionGroups` 내부 alias).

### V7. visible 카드 인라인 토글

- `_InlineVisibleToggle` (`ConsumerStatefulWidget`): 낙관적 UI(`_optimisticValue`) + 로딩 중 `CircularProgressIndicator`.
- 성공 시 `_optimisticValue = null` 원복 → Firestore stream 갱신으로 카드 재렌더.
- 실패 시 `_optimisticValue = null` 원복 + SnackBar `'변경에 실패했어요'`.
- `updateOwnerStoreMenuUseCaseProvider` 호출 (V2 통합 — `updateStoreOnlyMenuCore`).

### V8. 메뉴 복제 — CloneOwnerStoreMenuUseCase

- `_CardActions._clone` / `_ActionSheet` / `OwnerStoreMenuDetailPage._handleAction` 에서 `cloneOwnerStoreMenuUseCaseProvider.call(store.id, item.id)` 호출.
- 반환 값이 null 이면 (원본 fetch 실패) 폼 진입 안 함.
- `prefillItem` 파라미터로 `OwnerStoreMenuFormPage` 진입 → 이름 `'${원본} 복사'`, imageUrl null(이미지 새로 업로드 필요), status=approved.

### V9. 화면 진입 경로 — `OwnerMyStorePage` 내 `_MenuManagementButton`

- `my_store_page.dart` 약 line 1022~1063.
- 매장 상세 영역의 기존 액션 버튼들 아래에 전체 너비 단독 행으로 배치(D3).
- 톤: `AppColors.primary` 배경 + `AppColors.onPrimary` 텍스트 (filled `ElevatedButton.icon`).
- `Navigator.push(MaterialPageRoute(builder: (_) => OwnerStoreMenuListPage(store: store)))`.

### V10. customer 측 case A status 필터 — 자연 정합

- 개인 매장 메뉴는 항상 `status=approved` 박힘 → `watchByStore(storeId, brandId: null)` case A 의 status 필터 자동 통과.
- `visible=true` 인 경우에만 customer 화면에 노출 → 인라인 토글(V7)로 제어 가능.
- 별도 코드 보강 없음.

---

## `MenuItemRepositoryImpl` brandId 분기 상세

### 코드 위치

- 생성자 + optional props: line 29-42
- `_fetchStoreBrandId` private helper: line 283-288
- `_assertOwnerOfPersonalStore` private helper: line 294-311
- `createStoreOnlyMenu` 분기: line 127-169
- `updateStoreOnlyMenuCore` 분기: line 172-212
- `deleteStoreOnlyMenu` 분기: line 228-245

### 두 케이스 비교

| 항목 | 개인 매장 (brandId == null) | 브랜드 매장 (brandId != null) |
|---|---|---|
| ownership 검증 | `_assertOwnerOfPersonalStore`: `store.ownerId == uid && store.brandId == null` | role == 'admin' 또는 role == 'brand' |
| status | `EntityApprovalStatus.approved` 강제 | `EntityApprovalStatus.pending` |
| submittedBy/At | null | currentUid / DateTime.now() |
| approvedBy/At | null | null (admin 이 나중에 채움) |
| rejectedReason | null | null |
| brandId | null | storeBrandId (fetch 한 값) |
| SnackBar | "저장됐어요" | "검토 요청을 보냈어요" (sub-phase 3) |

### sub-phase 3 회귀 보존

- `brandId != null` 분기는 sub-phase 3 의 코드 블록을 그대로 유지. `role != 'admin' && role != 'brand'` 이면 `StateError('권한이 없습니다.')`.
- `_fetchStoreBrandId` 는 `storeRemoteDataSource?.getById(storeId)?.brandId` 구조이므로, storeRemoteDataSource 미주입 시 `null` 반환 → 개인 매장 분기로 폴백(테스트 환경 안전).
- 기존 sub-phase 1/3 의 brand DI Provider 들은 `storeRemoteDataSource` 를 주입하지 않으므로 동작 불변 (단, `null` 반환 → 개인 매장 분기 폴백 — brand 매장용 DI 는 별도 `ownerMenuItemRepositoryProvider` 와 구분됨).

---

## OptionGroupSelector V6 확장

### Props 변경

| 파라미터 | 이전 | 이후 |
|---|---|---|
| `optionGroups` | positional required | positional required (유지, 내부에서 `masterGroups` alias) |
| `storeGroups` | 없음 | `List<OptionGroupEntity> storeGroups = const []` (optional) |
| `storeId` | 없음 | `String? storeId` (optional) |
| `selectedIds` | required | required (유지) |
| `onChanged` | required | required (유지) |

### 기존 호출부 영향

- `BrandMasterMenuFormPage` 등 기존 호출부는 `storeGroups` / `storeId` 미전달 → `storeId == null` 분기 → 기존 master only 렌더(`_buildGroupList(masterGroups, isStore: false)`). 변경 없음.

### 신규 호출부

- `OwnerStoreMenuFormPage`:
  ```dart
  OptionGroupSelector(
    optionGroups: masterGroups,
    storeGroups: storeGroups,
    storeId: widget.store.id,
    selectedIds: _selectedOptionGroupIds,
    onChanged: (ids) => setState(() => _selectedOptionGroupIds = ids),
  )
  ```
- `masterGroups`: `masterOptionGroupsProvider` (`FutureProvider<List<OptionGroupEntity>>`)
- `storeGroups`: `storeOptionGroupsProvider(widget.store.id)` (`FutureProvider.family`)

---

## OwnerMyStorePage CTA 추가

### `_MenuManagementButton` 노출 조건

```dart
final isPersonalApproved = store.brandId == null &&
    store.status == EntityApprovalStatus.approved;
if (!isPersonalApproved) return const SizedBox.shrink();
```

- `store.brandId != null` → `SizedBox.shrink()` (brand 매장 점주 차단, V4)
- `store.status != approved` → `SizedBox.shrink()` (pending/rejected 차단, V9)

### 진입 흐름

```
OwnerMyStorePage (매장 상세)
  → _MenuManagementButton (개인 매장 + approved 조건 충족 시 노출)
  → ElevatedButton.icon "메뉴 관리" 탭
  → Navigator.push → OwnerStoreMenuListPage(store: store)
  → FAB "메뉴 추가" → OwnerStoreMenuFormPage(store: store)
  → 저장 → CreateOwnerStoreMenuUseCase → RepositoryImpl 개인 매장 분기
```

---

## status 정책 자연 정합 (V10)

개인 매장 메뉴의 `status=approved` 즉시 박힘은 customer 측 두 필터를 자동 통과한다.

1. `watchByStore(storeId, brandId: null)` (case A) 의 status 필터 — approved 통과
2. `visible` 필터 — `visible=true` 기본값, 점주 인라인 토글로 제어

이로 인해 점주 등록 메뉴는 저장 즉시 customer `StoreMenuPage` 에 노출된다. 별도 customer 측 코드 변경 없음.

---

## 테스트 포인트

- [ ] `OwnerMyStorePage` — 개인 매장 + approved 시 "메뉴 관리" CTA 노출 확인
- [ ] `OwnerMyStorePage` — brand 매장 점주 진입 시 CTA 비노출 확인
- [ ] `OwnerMyStorePage` — 개인 매장 pending/rejected 시 CTA 비노출 확인
- [ ] `OwnerStoreMenuListPage` — 메뉴 리스트 정상 노출, 빈 상태 UI, 에러 상태 UI + 재시도 버튼
- [ ] FAB "메뉴 추가" → `OwnerStoreMenuFormPage(store)` 진입
- [ ] 메뉴 신규 등록 → Firestore 문서 `status=approved`, 승인 메타 모두 null 확인
- [ ] 메뉴 신규 등록 → customer `StoreMenuPage` 즉시 노출 확인
- [ ] 메뉴 수정 (이름/가격/카테고리/설명/옵션그룹) → `status=approved` 보존, customer 즉시 반영
- [ ] 메뉴 수정 (visible/tags/displayOrder/imageUrl) → 즉시 반영, status 보존
- [ ] 카드 인라인 visible 토글 → 낙관적 UI 반응, 실패 시 원복 + SnackBar '변경에 실패했어요'
- [ ] visible=false 토글 → customer `StoreMenuPage` 에서 즉시 사라짐 확인
- [ ] 메뉴 삭제 → 다이얼로그 확인 → customer 즉시 제거
- [ ] 메뉴 복제 → `OwnerStoreMenuFormPage` prefill (이름 '${원본} 복사', 이미지 비어있음)
- [ ] 복제 폼 저장 → 신규 문서 생성, status=approved
- [ ] 이미지 5MB 초과 → 에러 스낵바, 메뉴 저장 차단
- [ ] 이미지 업로드 실패 → 에러 스낵바, 메뉴 저장 차단
- [ ] `OptionGroupSelector` — storeId 전달 시 마스터/매장 한정 헤더 구분 노출
- [ ] `OptionGroupSelector` — storeId null 시 기존 master only 동작 유지 (기존 호출부 회귀)
- [ ] 점주가 본인 외 매장 storeId 로 메뉴 조작 → `StateError` (PermissionDenied)
- [ ] 점주가 brand 매장 storeId 로 메뉴 조작 → `StateError` (PermissionDenied, brandId!=null 분기)
- [ ] SnackBar 문구: 저장 성공='저장됐어요', 삭제 성공='삭제됐어요', visible 토글 실패='변경에 실패했어요'

---

## 회귀 검증

### sub-phase 3 brand 매장 점포 한정 메뉴 분기

- `MenuItemRepositoryImpl` 의 `createStoreOnlyMenu` / `updateStoreOnlyMenuCore` / `deleteStoreOnlyMenu` 에서 `brandId != null` 분기는 sub-phase 3 동작 그대로 보존.
- brand 매장에서 점포 한정 메뉴 등록 → status=pending 박힘, admin 승인 큐 등장 확인.
- `updateStoreOnlyMenuOperation` 은 변경 없음 (brand 매장 visible/soldOut/displayOrder 전용).

### sub-phase 1/2 무영향

- `MenuItemRepository` 시그니처 불변.
- `watchByStore(storeId, brandId: null)` case A — 시그니처/동작 불변.
- `watchByStore(storeId, brandId: 'X')` case B — Rx.combineLatest3 머지 흐름 불변.
- `OwnerMyStorePage` 기존 `_StoreActionButtons` (매장 정보 수정 / 운영 정보 수정) 위치 변경 없음.
- `OptionGroupSelector` 기존 호출부 (`storeId` 미전달) → master only 렌더 유지.

### flutter analyze 결과

```
Analyzing OrderApp...
No issues found!
```

---

## spec.md 대비 차이

- `deleteStoreOnlyMenu` 에서 메뉴 삭제 직전 Storage 이미지 정리 (`StorageDataSource.deleteByUrl`) 미구현. spec 에서 언급되었으나 현재 구현에서 `dataSource.deleteStoreOnly` 만 호출. → 보류 항목 참조.
- 이미지 교체 시 이전 이미지 Storage 정리 미구현. 동일 사유로 보류.

---

## design.md 대비 차이

- D2 SnackBar 문구에서 등록/수정 성공 시 `'즉시 반영되었습니다'` 가 아닌 `'저장됐어요'` 로 구현됨. 실제 design.md 의 D2 표에도 `'저장됐어요'` 로 명시되어 있으므로 정합.
- visible 토글 성공 시 별도 SnackBar 없음 — design.md D2 와 동일.

---

## 미구현 / 보류 항목

### 점주 옵션 비활성 / 품절 토글

- 항목: `disabledOptionGroupIds` / `disabledOptionItemIds` / `soldOut` UI 활성화
- 이유: spec V 에서 명시적으로 sub-phase 5 로 이연. 본 sub-phase 폼은 entity default(`[]` / `false`)만 박음.
- 후속 작업: sub-phase 5 `owner_option_soldout`.

### 메뉴 삭제 / 이미지 교체 시 Storage 이미지 정리

- 항목: `deleteStoreOnlyMenu` 직전 `StorageDataSource.deleteByUrl(imageUrl)` 호출, 수정 시 이전 이미지 URL Storage 삭제
- 이유: `deleteStoreOnly` DataSource 레벨에서 이미지 URL 을 가져오는 흐름(watchById 1회 fetch + cancel)이 필요하나 현재 RepositoryImpl 에 미포함. Storage 잔존 이미지는 별도 cleanup 작업으로 이연.
- 후속 작업: 별도 task `storage_cleanup` 또는 sub-phase 5 에서 함께 처리.

### 부 카테고리 선택 UI

- 항목: `subCategoryId` 필드 UI
- 이유: spec 비범위 (별도 phase).
- 현재: `_source?.subCategoryId` 그대로 이어받기만 함.

---

## 코드 생성 필요 여부

- Entity / Model 변경 없음 → `dart run build_runner build` 불필요.

---

## 실행한 검증 명령

```bash
flutter analyze
# Analyzing OrderApp... No issues found!
```
