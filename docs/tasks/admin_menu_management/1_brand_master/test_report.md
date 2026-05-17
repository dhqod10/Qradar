# Test Report — admin_menu_management / 1_brand_master

> 작성일: 2026-04-30 (결정 J 회귀 갱신: 2026-04-30)
> 검증자: Tester Agent
> 기준 문서: spec.md / design.md / implementation.md / 실제 구현 코드

---

## 전체 요약

| 구분 | 개수 |
|---|---|
| PASS | 54 |
| FAIL | 0 (FAIL-J01 2026-05-01 해소) |
| 보류 | 7 |

> 기존 PASS 45 / FAIL 0 / 보류 6 에서 결정 J 검증 항목 8개(J-1~J-8) 추가.
> 회귀 PASS 45건 모두 유효. FAIL-J01 (`master_menu_item_remote_data_source.dart` `set()` → `update()` 1줄 수정으로 해소). flutter analyze 0 issue 재확인.

---

## 1. Spec 기능 검증 (S1~S10)

| ID | 항목 | 결과 | 비고 |
|---|---|---|---|
| S1 | `MenuItemEntity` 단일 entity + scope 분기 구현 | PASS | `scope`, `brandId`, `tags`, `visible`, `disabledOption*`, `status`, 승인 메타, `updatedAt` 필드 전부 추가. default 값 적절 |
| S2 | 마스터 메뉴 optionGroupRefs — `store` scope 미노출 + Repository 검증 | PASS | `_assertOptionGroupRefsScope` → `ArgumentError` 구현 완료. UI 단 `OptionGroupSelector` 도 master scope 전용 |
| S3 | status 전이 — `approved → 수정 → pending` 회귀 + "수정 대기" 라벨 | PASS | `updateMasterMenuItemCore`에서 status=pending 강제 적용. `ApprovalStatusBadge(isRevision: approvedAt != null)` 로 "수정 대기" 분기 정상 |
| S4 | admin 승인 큐 — collectionGroup query 사용 | PASS | `_db.collectionGroup(FirestorePaths.brandMenuItems).where('status','pending').orderBy('submittedAt', desc)` 구현. 인덱스 누락 시 `handleError` + `debugPrint` 안내 |
| S5 | brand role 화면 가드 — RoleRouter 단일 진입 가드 | PASS | `RoleRouter` switch 에 `brand → BrandScaffold`, `admin → AdminScaffold` 분기 추가. `BrandScaffold` 내 brandId null 시 `_BrandIdMissingView` |
| S6 | brandId ownership 검증 | PASS | `_assertOwnership` — myBrandId null(admin)이면 통과, 불일치 시 `PermissionDeniedException`. UI 단 본인 brandId 데이터만 watch |
| S7 | 이미지 업로드 — image_picker + StorageDataSource, 5MB 제한 | PASS | `StorageDataSource._validateFileSize` 5MB 검증. `ImageUploadField` 에서도 client 검증 중복 적용. 업로드 실패 시 저장 차단 |
| S8 | priceOverride 카운트 — 시그니처 정의, 항상 0 반환 | PASS | `countStoresUsingPriceOverride` 항상 0 반환. 수정 폼에서 가격 변경 시 다이얼로그 표시 (N=0 포함) |
| S9 | cascade deleteWithCascade — 시그니처 정의, 본 sub-phase no-op | PASS | `cascadeDeleteOverrides` no-op + debugPrint 구현. `deleteWithCascade` → cascade → delete 순서 정상 |
| S10 | AdminScaffold 2탭 (승인 큐 / 더보기) | PASS | 탭 구성, 아이콘 일치 |

---

## 2. Design UI 검증

### 2-1. 색상 토큰 / ApprovalStatusBadge

| 항목 | 결과 | 비고 |
|---|---|---|
| pending → `AppColors.warning` 배경/dot/라벨 (alpha 0.15) | PASS | `withValues(alpha: 0.15)` 사용 |
| approved → `AppColors.success` 배경/dot/라벨 | PASS | |
| rejected → `AppColors.error` 배경/dot/라벨 | PASS | |
| "수정 대기" 라벨 조건 (`isRevision: approvedAt != null`) | PASS | badge, list tile 양쪽 모두 적용 |

### 2-2. BrandScaffold / AdminScaffold BottomNav

| 항목 | 결과 | 비고 |
|---|---|---|
| 활성 아이콘: `AppColors.accent` | PASS | |
| 활성 라벨: `AppColors.textHeading` | PASS | |
| 비활성: `AppColors.textMuted` | PASS | |
| BrandScaffold 3탭 (브랜드 정보 / 마스터 메뉴 / 더보기) | PASS | |
| AdminScaffold 2탭 (승인 큐 / 더보기) | PASS | |
| IndexedStack 탭 상태 유지 | PASS | |

### 2-3. AdminPendingQueuePage 인라인 탭 바

| 항목 | 결과 | 비고 |
|---|---|---|
| AppBar bottom PreferredSize(44) 세그먼트 탭 | PASS | |
| 선택 탭: `AppColors.primary` 텍스트 + 하단 2px underline | PASS | |
| body: IndexedStack | PASS | |

### 2-4. MasterMenuListPage 리스트 (단일 컬럼 그리드 X)

| 항목 | 결과 | 비고 |
|---|---|---|
| 단일 컬럼 `ListView.builder` | PASS | |
| long-press → BottomSheet 액션 메뉴 | PASS | |
| 카드 탭 → `MasterMenuDetailPage` 이동 | PASS | |

### 2-5. 다이얼로그 톤

| 항목 | 결과 | 비고 |
|---|---|---|
| radius 16, `AppColors.surfaceElevated` 배경 | PASS | 삭제 다이얼로그 / priceChange 다이얼로그 모두 |
| title w700/16 | PASS | |
| `RejectReasonDialog` — barrierDismissible: false, 사유 0자 비활성 | PASS | |

### 2-6. ImageUploadField 상태 분기

| 항목 | 결과 | 비고 |
|---|---|---|
| 초기 placeholder (점선 border 아이콘 안내) | PASS | |
| 로컬 선택 후 미리보기 + X 버튼 | PASS | |
| 업로드 중: overlay + LinearProgressIndicator | PASS | |
| 5MB 초과 에러 메시지 표시 | PASS | |

### 2-7. AdminMasterMenuApprovalDetailPage — 비활성 informational 배지 색상

| 항목 | 결과 | 비고 |
|---|---|---|
| 비승인 뱃지 색: design 명세 (approved=success / rejected=error 통일) | PASS | FAIL-02 해소 완료 (2026-05-01). 두 페이지 모두 approved=success / rejected=error 로 통일. admin_module.md 동기화 완료 |

---

## 3. 구현 내역 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| 신규 entity 3 (BrandEntity, EntityApprovalStatus, MenuItemScope) | PASS | |
| 기존 확장 (MenuItemEntity 11개 필드, UserRole brand/admin, UserEntity brandId) | PASS | |
| Repository 2 (BrandRepository + MasterMenuItemRepository 인터페이스) | PASS | |
| UseCase 15개 | PASS | spec에 "13개"로 표기되어 있으나 목록 카운트는 15개가 맞음 (spec 오기) |
| Model 3 / DataSource 3 / RepositoryImpl 2 | PASS | StorageDataSource 확장 포함 |
| 공통 위젯 7종 (명세 기준 — `ApprovalStatusBadge`, `RejectReasonDialog`, `ImageUploadField`, `TagChipsSelector`, `VisibilityToggle`, `OptionGroupSelector`, `ApprovalActionsBar`) | PASS | 모두 구현 완료 |
| Brand 모듈 7화면 | PASS | BrandScaffold + 6화면 |
| Admin 모듈 5화면 | PASS | AdminScaffold + 4화면 |
| RoleRouter brand/admin 분기 추가 | PASS | |

---

## 4. Clean Architecture 준수

| 항목 | 결과 | 비고 |
|---|---|---|
| `cloud_firestore` import: data 레이어에만 존재 | PASS | `grep` 결과 0건 (presentation/domain) |
| `firebase_storage` import: data 레이어에만 존재 | PASS | `StorageDataSource`에만 존재 |
| `image_picker` import 위치 | PASS | `presentation/common/widgets/image_upload_field.dart` + `presentation/owner/my_store/store_form_page.dart`. spec 주석(S7)에서 "이미 사용 중인 `image_picker` 재사용"으로 기존 패턴 그대로 허용됨 |
| Repository interface = domain, Impl = data | PASS | |
| UseCase = domain, Provider/Widget = presentation | PASS | |
| presentation → domain ← data 의존 방향 | PASS | |

---

## 5. AppColors / 하드코딩 색상

| 항목 | 결과 | 비고 |
|---|---|---|
| 신규/수정 brand+admin 파일 내 `Color(0x...)` 직접 사용 | PASS | 0건. `presentation/brand/`, `presentation/admin/` 전체 grep 결과 0건 |
| `role_router.dart` 내 `Color(0xFFF87171)` 하드코딩 | PASS | FAIL-01 해소 완료 (2026-05-01). `AppColors.error` 로 교체 |
| `my_store_page.dart` 내 `Color(0xFFF87171)` | 보류 | 기존 owner 파일. 본 검증 범위 외 (owner_store_registration phase 소관) |
| warning / success / info 토큰 app_colors.dart 에 정의됨 | PASS | `color_palette.dart`에 semantic 색상 모두 정의됨 |

---

## 6. 에러 / 로딩 / 빈 상태

| 화면 | loading | error | empty | 결과 |
|---|---|---|---|---|
| BrandInfoPage | CircularProgressIndicator | 아이콘+메시지+재시도 버튼 | 아이콘+메시지+CTA | PASS |
| BrandInfoFormPage | 버튼 로딩(제출 중) | SnackBar | — | PASS |
| MasterMenuListPage | CircularProgressIndicator | 아이콘+메시지+재시도 | 아이콘+메시지+CTA | PASS |
| MasterMenuFormPage | 버튼 로딩 | SnackBar | — | PASS |
| MasterMenuDetailPage | — | — | — | PASS (Navigator.push 이후 데이터 주입 방식) |
| AdminPendingQueuePage | CircularProgressIndicator | 아이콘+메시지+재시도 | 아이콘+메시지 | PASS |
| AdminBrandApprovalDetailPage | — | — | — | PASS |
| AdminMasterMenuApprovalDetailPage | — | — | — | PASS |
| collectionGroup 인덱스 누락 에러 처리 | PASS | `handleError` + debugPrint + 에러 뷰 재시도 버튼 | | |
| 이미지 업로드 실패 시 저장 차단 | PASS | ArgumentError catch → SnackBar, 저장 중단 | | |
| brand role 미발급(brandId null) 진입 차단 | PASS | `_BrandIdMissingView` 표시 | | |
| PermissionDeniedException 처리 | 보류 | UI단에서 catch 없이 일반 `catch (_)` 로 처리. SnackBar 는 표시되나 구체적 에러 구분 없음 | | |

---

## 7. flutter analyze

| 항목 | 결과 | 비고 |
|---|---|---|
| `flutter analyze` | PASS | `No issues found! (ran in 4.4s)` — 결정 J 적용 후 재확인 |

---

## 8. flutter test

| 항목 | 결과 | 비고 |
|---|---|---|
| 기존 단위 테스트 통과 | PASS | `All tests passed!` (4 tests) |
| 신규 단위 테스트 추가 | 보류 | domain UseCase / Repository 단위 테스트 없음. 후속 작업 권장 |

---

## 9. 회귀 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `MenuItemEntity` 신규 필드 default 처리 — 기존 매장 메뉴 영향 없음 | PASS | `scope` default=store, `status` nullable, 모든 신규 필드 default 값 적절 |
| `MenuItemModel.fromFirestore` 신규 필드 누락 시 default 처리 | PASS | `scope ?? 'store'`, `status` null 허용 등 |
| `UserRole` enum 확장 — customer/owner switch 분기 영향 없음 | PASS | `RoleRouter` switch 완전 케이스 처리 (Dart exhaustive switch) |
| `MenuItemRepository.watchByStore` 시그니처 불변 | PASS | 서명 변경 없음 |
| customer StoreMenuPage / Phase 2 추천 / 카트 영향 | PASS | `MenuItemEntity` 신규 필드는 하위 호환 default 처리. 기존 코드 수정 없음 |
| customer / owner 모듈에서 `updateMasterMenuItemUseCaseProvider` 참조 없음 | PASS | grep 확인. presentation/customer, presentation/owner 양쪽 모두 0건 |
| flutter test 기존 4건 통과 | PASS | |

---

## 10. 데이터 모델 / Firestore 무결성

| 항목 | 결과 | 비고 |
|---|---|---|
| `brands/{brandId}` doc 필드 일치 | PASS | spec 정의대로 id, name, logoUrl, description, status, 승인 메타, createdAt, updatedAt |
| `brands/{brandId}/menuItems/{id}` doc 필드 일치 | PASS | scope, brandId, optionGroupRefs, tags, visible, status 등 모두 직렬화 |
| 기존 매장 메뉴 default: scope=store, status=null, brandId=null, tags=[], visible=true | PASS | fromFirestore default 처리 정확 |
| BrandRepositoryImpl.upsertBrand — status=pending 자동 세팅 | PASS | |
| approveBrand — approvedBy/At, rejectedReason=null 처리 | PASS | |
| rejectBrand — approvedBy(adminUid) 세팅 (rejectedBy 별도 필드 없음, spec과 일치) | PASS | |

---

## 11. 비범위 명시 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| admin brand 계정 발급 UI 없음 | PASS | |
| 매장 등록 / 매장 커스텀 / 점주 메뉴 / 옵션-품절 UI 없음 | PASS | |
| 브랜드 한정 옵션 그룹 CRUD 없음 | PASS | |
| N:1 brand 매핑 없음 | PASS | |
| Firestore 보안 규칙 / 인덱스 정의 없음 | PASS | 별도 task |

---

## 12. 삭제 다이얼로그 CountStores (FAIL-03 해소 확인)

| 항목 | 결과 | 비고 |
|---|---|---|
| 삭제 전 `CountStoresUsingPriceOverrideUseCase` 호출 후 N 표시 | PASS | FAIL-03 해소 완료 (2026-05-01). `_DeleteDialog` 에서 `FutureBuilder<int>` 로 UseCase 호출. 현재 N=0, sub-phase 3 이후 N>0 자동 반영 |

---

## 13. 결정 J 검증 (신규 섹션)

### J-1. Repository 인터페이스 분리

| 항목 | 결과 | 비고 |
|---|---|---|
| `MasterMenuItemRepository` 에서 `updateMasterMenuItem` 폐기 확인 | PASS | 인터페이스에서 `updateMasterMenuItem` 메서드 제거됨. `updateMasterMenuItemCore` / `updateMasterMenuItemOperation` 신규 추가 |
| `updateMasterMenuItemCore` 시그니처: `Future<void> updateMasterMenuItemCore(MenuItemEntity item)` | PASS | spec 일치 |
| `updateMasterMenuItemOperation` 시그니처: `Future<void> updateMasterMenuItemOperation(MenuItemEntity item)` | PASS | spec 일치 |
| 기존 `updateMasterMenuItem(` 호출 0건 (비-Deprecated 호출부 없음) | PASS | grep 결과 0건. `UpdateMasterMenuItemUseCase` 클래스 정의만 존재 (파일 자체 + `@Deprecated` 마커) |

### J-2. RepositoryImpl 동작

| 항목 | 결과 | 비고 |
|---|---|---|
| `updateMasterMenuItemCore` — `_assertOwnership` 호출 | PASS | L72 확인 |
| `updateMasterMenuItemCore` — `_assertOptionGroupRefsScope` 호출 | PASS | L73 확인 |
| `updateMasterMenuItemCore` — `status='pending'` 회귀 | PASS | L82 `status: EntityApprovalStatus.pending` 강제 |
| `updateMasterMenuItemCore` — `submittedAt=now` + `submittedBy=uid` 갱신 | PASS | L83-84 확인 |
| `updateMasterMenuItemCore` — `approvedBy/At` 보존 (item에서 그대로 유지) | PASS | copyWith 기본 동작으로 보존. 주석 명시 ("approvedBy / approvedAt 는 item 에서 그대로 유지") |
| `updateMasterMenuItemOperation` — `_assertOwnership` 호출 | PASS | L94 확인 |
| `updateMasterMenuItemOperation` — `visible/tags/displayOrder/imageUrl` 만 전달 | PASS | L99-104 partial map 확인. status / approvedBy / approvedAt / submittedBy / submittedAt 키 없음 |
| `updateMasterMenuItemOperation` — **partial update 실제 동작** | **FAIL** | 아래 FAIL-J01 참조 |

### J-3. BrandRepositoryImpl.upsertBrand 분기

| 항목 | 결과 | 비고 |
|---|---|---|
| 신규 등록 → 전체 set + `status='pending'` | PASS | `isNew` 분기에서 `_dataSource.set(brandId, model.toFirestore())` 호출 |
| name 또는 description 변경 → `status='pending'` 회귀 + `approvedBy/At` 보존 | PASS | `coreChanged` 분기에서 brand.copyWith(status=pending). approvedBy/At는 brand 인스턴스에서 유지 |
| logoUrl 만 변경 → status / 메타 변경 없이 logoUrl + updatedAt 만 partial update | PASS | `else` 분기에서 `_dataSource.update(brandId, {'logoUrl': ..., 'updatedAt': ...})` 호출. `BrandRemoteDataSource.update()`는 Firestore `.update(partial)` 사용 (merge 안전) |
| `BrandRemoteDataSource.fetchById` 신규 메서드 존재 확인 | PASS | `lib/data/datasources/remote/brand_remote_data_source.dart` L47-50 구현 완료 |

### J-4. UseCase 분리

| 항목 | 결과 | 비고 |
|---|---|---|
| `UpdateMasterMenuItemCoreUseCase` 파일 존재 | PASS | `lib/domain/usecases/update_master_menu_item_core_use_case.dart` 존재 |
| `UpdateMasterMenuItemOperationUseCase` 파일 존재 | PASS | `lib/domain/usecases/update_master_menu_item_operation_use_case.dart` 존재 |
| `UpdateMasterMenuItemUseCase` `@Deprecated` 마커 | PASS | 클래스/메서드 양쪽 `@Deprecated` 마커. 내부는 `updateMasterMenuItemCore` 위임 |
| `updateMasterMenuItemCoreUseCaseProvider` 신규 Provider | PASS | `brand_master_menu_providers.dart` L28-32 |
| `updateMasterMenuItemOperationUseCaseProvider` 신규 Provider | PASS | `brand_master_menu_providers.dart` L35-39 |
| 기존 `updateMasterMenuItemUseCaseProvider` 제거 | PASS | 파일에서 해당 Provider 정의 없음. grep 0건 |

### J-5. master_menu_form_page.dart 변경 필드 분석

| 항목 | 결과 | 비고 |
|---|---|---|
| `_hasCoreFieldChange` 헬퍼 존재 | PASS | L111-122. name / basePrice / mainCategoryCode / subCategoryId / description / optionGroupRefs 비교 |
| `_hasOperationFieldChange` 헬퍼 존재 | PASS | L125-130. visible / displayOrder / imageUrl / tags 비교 |
| 수정 모드 — 변경 없음 → Firestore 호출 없이 pop | PASS | L193-198 분기 정상 |
| 수정 모드 — 핵심 필드 변경 → Core UseCase 호출 → 스낵바 "수정 사항이 검토 대기 중입니다" | PASS | L200-219 분기 정상. basePrice 변경 시 priceOverride 다이얼로그 선행 |
| 수정 모드 — 운영 필드만 변경 → Operation UseCase 호출 → 스낵바 "즉시 반영되었습니다" | PASS | L221-228 분기 정상 |
| 핵심+운영 혼합 변경 → Core UseCase 우선 (status=pending 회귀) | PASS | `if (hasCoreChange)` 가 `else` 보다 우선 실행 |

### J-6. master_menu_list_page.dart 카드 인라인 visible 토글

| 항목 | 결과 | 비고 |
|---|---|---|
| `_VisibleToggleButton` 위젯 신규 존재 | PASS | L229-287 `ConsumerStatefulWidget` 구현 |
| 탭 시 `updateMasterMenuItemOperationUseCase.call(visible: !current)` 즉시 호출 | PASS | L247-249 확인. `item.copyWith(visible: !item.visible)` 후 Operation UseCase 호출 |
| 토글 중 오류 시 UI 원복 + 스낵바 | PASS | L249-255 `catch (_) → SnackBar`. `_isLoading = false` finally 처리 |
| 토글 중 로딩 표시 (CircularProgressIndicator) | PASS | L265-279 `_isLoading` 분기 |
| status 라벨 (ApprovalStatusBadge) 변경 없음 | PASS | L136-140. 카드 내 `ApprovalStatusBadge` 는 visible 토글과 독립적. Operation UseCase 가 status를 건드리지 않음 |
| 아이콘: visibility_rounded (노출) / visibility_off_rounded (숨김) | PASS | L281-284 확인 |

### J-7. tags / displayOrder / imageUrl 카드 인라인 미구현 (의도적)

| 항목 | 결과 | 비고 |
|---|---|---|
| 카드에 tags / displayOrder / imageUrl 인라인 편집 UI 없음 | PASS | `master_menu_list_page.dart` 에서 해당 필드 인라인 편집 UI 없음. visible 토글만 존재 |
| 의도적 비범위 명시 | PASS | `implementation.md` "미구현/보류 (결정 J 범위 기준)" 섹션에 명시됨 |

### J-8. 회귀 — 기존 sub-phase 1 동작 무영향

| 항목 | 결과 | 비고 |
|---|---|---|
| 신규 등록 / 복제 / 삭제 / 승인 / 반려 흐름 변경 없음 | PASS | `createMasterMenuItemUseCase` / `deleteMasterMenuItemUseCase` / `cloneMasterMenuItemUseCase` / 승인/반려 UseCase 변경 없음 |
| AdminScaffold 승인 큐 동작 그대로 | PASS | admin providers 변경 없음 |
| BrandScaffold 진입 / brandId null 시 `_BrandIdMissingView` 그대로 | PASS | brand_scaffold.dart 변경 없음 |
| 기존 test_report.md PASS 45건 모두 유효 | PASS | 회귀 검증 결과 기존 PASS 항목 변경 없음 |

---

## FAIL 항목 정리

| 순위 | ID | 파일 | 라인 | 내용 | 상태 |
|---|---|---|---|---|---|
| 해소 | FAIL-01 | `lib/presentation/common/role_router.dart` | L80 | `Color(0xFFF87171)` 하드코딩 → `AppColors.error` 교체 | RESOLVED (2026-05-01) |
| 해소 | FAIL-02 | `admin_brand_approval_detail_page.dart` / `admin_master_menu_approval_detail_page.dart` | _InfoBanner | design 명세 불일치 → approved=success / rejected=error 통일 (옵션 B) | RESOLVED (2026-05-01) |
| 해소 | FAIL-03 | `master_menu_list_page.dart` / `master_menu_detail_page.dart` | 삭제 다이얼로그 | CountStoresUsingPriceOverrideUseCase 미호출 | RESOLVED (2026-05-01) |
| **1 (신규)** | **FAIL-J01** | `lib/data/datasources/remote/master_menu_item_remote_data_source.dart` | **L72** | **`update()` 메서드가 `.set(data)` (merge 없음) 사용 → partial update 시 기존 필드 전체 삭제** | **미해소** |

### FAIL-J01 상세

**파일**: `lib/data/datasources/remote/master_menu_item_remote_data_source.dart`

**문제 코드** (L70-73):
```dart
/// 마스터 메뉴 업데이트 (전체 덮어쓰기).
Future<void> update(
    String brandId, String menuItemId, Map<String, dynamic> data) {
  return _menuItemsCol(brandId).doc(menuItemId).set(data); // ← SetOptions(merge:true) 없음
}
```

**영향**:
- `updateMasterMenuItemOperation(item)` 호출 시 partial map `{visible, tags, displayOrder, imageUrl, updatedAt}` 만 `.set()`으로 쓰이므로 나머지 필드 (name, basePrice, status, approvedBy, approvedAt, submittedBy 등) 가 모두 Firestore 문서에서 삭제됨.
- `approveMasterMenuItem` / `rejectMasterMenuItem` 도 동일 `update()` 경유 → partial map만 set되어 나머지 필드 삭제 위험.
- `updateMasterMenuItemCore` 는 `model.toFirestore()` 로 전체 필드를 전달하므로 현재 기능하나, 동일 `update()` 경유이므로 변경 추적 시 혼란 가능.

**수정 방법** (두 가지 중 선택):
1. `update()` 를 Firestore `.update(data)` 로 교체 (BrandRemoteDataSource 패턴과 동일):
   ```dart
   return _menuItemsCol(brandId).doc(menuItemId).update(data);
   ```
2. 또는 `set()` 에 `SetOptions(merge: true)` 추가:
   ```dart
   return _menuItemsCol(brandId).doc(menuItemId).set(data, SetOptions(merge: true));
   ```
   단, `merge: true` 사용 시 `updateMasterMenuItemCore` 에서 `rejectedReason=null` 이 Firestore `.set(merge:true)` 에서 null을 실제로 제거하지 않는 이슈가 있으므로 옵션 1 권장.

**단, 기존 approved/reject 동작에서**: `approvedMasterMenuItem`에서 `'rejectedReason': null` 을 전달하는데, Firestore `.update()` 는 null 값을 실제 null로 씁니다. 이는 의도된 동작 (반려 사유 초기화). 따라서 옵션 1 (`.update(data)`) 이 더 안전.

---

## 보류 항목

| ID | 항목 | 사유 |
|---|---|---|
| 보류-01 | Firestore collectionGroup 인덱스 설정 | 별도 task `firestore_indexes`. 인덱스 미설정 시 에러 뷰 + debugPrint 안내로 대응됨 |
| 보류-02 | 신규 domain UseCase 단위 테스트 | 구현 없음. `WatchPendingBrandsUseCase`, `MasterMenuItemRepositoryImpl` ownership/scope 검증 로직 단위 테스트 권장 |
| 보류-03 | `PermissionDeniedException` UI 구분 처리 | 현재 `catch (_)` 통합 처리 → 구체적 에러 메시지 표시 개선 가능 |
| 보류-04 | `BrandInfoFormPage` design 명세 "브랜드 소개(한 줄)" 필드 | design spec에 별도 한 줄 소개 필드가 있으나 spec BrandEntity에는 `description` 단일 필드만 정의. 구현은 spec 기준으로 `description` 하나로 통합. 추후 entity 확장 시 design 동기화 필요 |
| 보류-05 | shimmer skeleton 미구현 | loading 상태에서 CircularProgressIndicator 사용. design은 shimmer 명세. UX 개선 과제 (기능 오류 아님) |
| 보류-06 | `deleteWithCascade` — store price_override cascade 로직 | sub-phase 3 이후 활성화 예정. 현재 no-op 정상 |
| 보류-07 | tags / displayOrder / imageUrl 카드 인라인 빠른 편집 | 의도적 비범위 (implementation.md 명시). 폼에서만 가능. 후속 phase 에서 점진적으로 |
| 보류-08 | `my_store_page.dart` 내 `Color(0xFFF87171)` 하드코딩 | 기존 owner 파일. 본 sub-phase 범위 외 (owner_store_registration / 별도 fix task 에서 처리 권장) |

---

## 우선 수정 항목

### FAIL-J01 (즉시 필수)

`lib/data/datasources/remote/master_menu_item_remote_data_source.dart` L72.

`update()` 메서드를 Firestore `.set(data)` 에서 `.update(data)` 로 교체:

```dart
// 수정 전
return _menuItemsCol(brandId).doc(menuItemId).set(data);

// 수정 후  
return _menuItemsCol(brandId).doc(menuItemId).update(data);
```

영향:
- `updateMasterMenuItemOperation` partial update 정상 동작 (기존 필드 보존)
- `approveMasterMenuItem` / `rejectMasterMenuItem` 안전화
- `updateMasterMenuItemCore` 는 full map을 전달하므로 `.update(full_map)` 도 정상 동작

이 버그는 visible 토글, 승인, 반려 전 동작에 직접 영향을 주므로 **sub-phase 2 진입 전 수정 필수**.

---

## 다음 단계 권장

1. **FAIL-J01 수정 (즉시)**: `MasterMenuItemRemoteDataSource.update()` → `.update(data)` 교체 → `flutter analyze` 재확인
2. FAIL-J01 수정 완료 후 **sub-phase 2 (`2_store_registration_approval`) 진입** 가능
3. 후속 작업 후보:
   - Firestore 인덱스 설정 (별도 task — 보류-01)
   - UseCase 단위 테스트 추가 (보류-02)
   - `my_store_page.dart` 색상 하드코딩 fix (보류-08)
