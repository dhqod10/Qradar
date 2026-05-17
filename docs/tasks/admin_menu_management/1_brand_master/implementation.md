# Implementation — admin_menu_management / 1_brand_master

## 구현 완료 항목

### Domain

#### 신규 Enum / Entity
- `lib/domain/entities/entity_approval_status.dart` — pending / approved / rejected, `fromString()`
- `lib/domain/entities/menu_item_scope.dart` — brand / store
- `lib/domain/entities/brand_entity.dart` — freezed (id, name, logoUrl, description, status, 승인 메타, createdAt, updatedAt)

#### 수정 Entity
- `lib/domain/entities/menu_item_entity.dart` — scope, brandId, tags, visible, disabledOptionGroupIds, disabledOptionItemIds, status, 승인 메타, updatedAt 추가
- `lib/domain/entities/user_role.dart` — `brand` 멤버 추가
- `lib/domain/entities/user_entity.dart` — `brandId` 필드 추가

#### 신규 Repository 인터페이스
- `lib/domain/repositories/brand_repository.dart` — watchAll, watchPendingForAdmin, watchById, upsertBrand, approveBrand, rejectBrand, deleteBrand
- `lib/domain/repositories/master_menu_item_repository.dart` — watchByBrand, watchPendingForAdmin, createMasterMenuItem, updateMasterMenuItem, deleteWithCascade, cloneAsDraft, countStoresUsingPriceOverride, approveMasterMenuItem, rejectMasterMenuItem

#### 신규 UseCase (15개)
| UseCase | 파일 |
|---|---|
| WatchBrandByIdUseCase | watch_brand_by_id_use_case.dart |
| WatchAllBrandsForAdminUseCase | watch_all_brands_for_admin_use_case.dart |
| WatchPendingBrandsUseCase | watch_pending_brands_use_case.dart |
| UpsertBrandUseCase | upsert_brand_use_case.dart |
| ApproveBrandUseCase | approve_brand_use_case.dart |
| RejectBrandUseCase | reject_brand_use_case.dart |
| WatchMasterMenuItemsUseCase | watch_master_menu_items_use_case.dart |
| WatchPendingMasterMenuItemsUseCase | watch_pending_master_menu_items_use_case.dart |
| CreateMasterMenuItemUseCase | create_master_menu_item_use_case.dart |
| UpdateMasterMenuItemUseCase | update_master_menu_item_use_case.dart |
| DeleteMasterMenuItemUseCase | delete_master_menu_item_use_case.dart |
| CloneMasterMenuItemUseCase | clone_master_menu_item_use_case.dart |
| CountStoresUsingPriceOverrideUseCase | count_stores_using_price_override_use_case.dart |
| ApproveMasterMenuItemUseCase | approve_master_menu_item_use_case.dart |
| RejectMasterMenuItemUseCase | reject_master_menu_item_use_case.dart |

---

### Core

- `lib/core/constants/firestore_paths.dart` — brands, brandMenuItems 컬렉션 경로, Storage prefix, 헬퍼 메서드 추가

---

### Data

#### 신규 / 수정 Model
- `lib/data/models/brand_model.dart` — fromFirestore, fromEntity, toEntity, toFirestore
- `lib/data/models/menu_item_model.dart` — scope, brandId, tags, visible, disabledOption*, status, 승인 메타 직렬화 추가
- `lib/data/models/user_model.dart` — brandId 파싱 추가, toEntity() 전달

#### 신규 DataSource
- `lib/data/datasources/remote/brand_remote_data_source.dart` — streamAll, streamPending, streamById, set, update, delete
- `lib/data/datasources/remote/master_menu_item_remote_data_source.dart` — streamByBrand, streamPending(collectionGroup), fetchById, create, update, delete
- `lib/data/datasources/remote/storage_data_source.dart` — uploadBrandImage, uploadMasterMenuImage, 5MB 검증 추가

#### 신규 RepositoryImpl
- `lib/data/repositories/brand_repository_impl.dart` — upsertBrand(status=pending 자동), approveBrand, rejectBrand
- `lib/data/repositories/master_menu_item_repository_impl.dart` — ownership 검증(_assertOwnership), optionGroupRefs scope 검증(_assertOptionGroupRefsScope), PermissionDeniedException

---

### Presentation

#### 공통 위젯
- `lib/presentation/common/widgets/approval_status_badge.dart` — pending/approved/rejected 배지, isRevision, large variant
- `lib/presentation/common/widgets/reject_reason_dialog.dart` — 반려 사유 입력 다이얼로그
- `lib/presentation/common/widgets/image_upload_field.dart` — 이미지 선택/미리보기/5MB 검증
- `lib/presentation/common/widgets/tag_chips_selector.dart` — recommended/new/best 태그 선택

#### Admin 위젯
- `lib/presentation/admin/widgets/approval_actions_bar.dart` — 반려/승인 버튼 바

#### Brand 위젯
- `lib/presentation/brand/master_menu/widgets/visibility_toggle.dart` — 노출/숨김 Switch
- `lib/presentation/brand/master_menu/widgets/option_group_selector.dart` — master scope 옵션 그룹 선택

#### Brand Provider
- `lib/presentation/brand/providers/brand_di_providers.dart`
- `lib/presentation/brand/providers/brand_info_providers.dart` — myBrandProvider(StreamProvider)
- `lib/presentation/brand/providers/brand_master_menu_providers.dart` — myMasterMenuItemsProvider

#### Admin Provider
- `lib/presentation/admin/providers/admin_di_providers.dart`
- `lib/presentation/admin/providers/admin_brand_approval_providers.dart` — pendingBrandsProvider
- `lib/presentation/admin/providers/admin_master_menu_approval_providers.dart` — pendingMasterMenuItemsProvider

#### Brand 화면
| 화면 | 파일 |
|---|---|
| BrandScaffold (3탭) | brand_scaffold.dart |
| 브랜드 정보/상태 | brand_info/brand_info_page.dart |
| 브랜드 등록/수정 폼 | brand_info/brand_info_form_page.dart |
| 마스터 메뉴 목록 | master_menu/master_menu_list_page.dart |
| 마스터 메뉴 등록/수정/복제 폼 | master_menu/master_menu_form_page.dart |
| 마스터 메뉴 상세 (읽기전용) | master_menu/master_menu_detail_page.dart |
| 더보기 | more/brand_more_page.dart |

#### Admin 화면
| 화면 | 파일 |
|---|---|
| AdminScaffold (2탭) | admin_scaffold.dart |
| 승인 큐 (브랜드/마스터 메뉴 세그먼트) | approval/admin_approval_queue_page.dart |
| 브랜드 승인 상세 | approval/admin_brand_approval_detail_page.dart |
| 마스터 메뉴 승인 상세 | approval/admin_master_menu_approval_detail_page.dart |
| 더보기 | more/admin_more_page.dart |

#### RoleRouter 수정
- `lib/presentation/common/role_router.dart` — `brand` → BrandScaffold, `admin` → AdminScaffold 분기 추가

---

## 주요 설계 결정

| 결정 | 내용 |
|---|---|
| S1 | Firestore 경로: `brands/{brandId}`, `brands/{brandId}/menuItems/{itemId}` |
| S2 | optionGroupRefs scope 검증: store scope 참조 시 PermissionDeniedException |
| S3 | 브랜드/마스터 메뉴 수정 제출 → status=pending 자동 전환 |
| S4 | collectionGroup query 인덱스 누락 시 handleError + debugPrint 안내 |
| S5 | 이미지 업로드: brand_images/{brandId}/, menu_images/brand/{brandId}/ |
| S6 | ownership 검증: brandId 불일치 → PermissionDeniedException |
| S7 | 마스터 메뉴 삭제: store price_override cascade는 no-op (sub-phase 5 이후) |
| S8 | countStoresUsingPriceOverride: 현재 0 반환 (sub-phase 5 이후 구현) |
| S9 | 기존 MenuItemEntity store scope 필드는 default값으로 하위 호환 유지 |
| S10 | admin은 brandId=null이므로 ownership 검증 통과 |

---

## flutter analyze 결과

```
No issues found! (ran in 4.2s)
```

---

## 테스트 포인트

### Brand 역할
1. `brand` role 계정 로그인 → BrandScaffold 진입 확인
2. brandId 없는 brand 계정 → `_BrandIdMissingView` 표시 확인
3. 브랜드 최초 등록: 이름/설명/로고 입력 → Firestore `brands/{id}` 문서 생성, status=pending 확인
4. 브랜드 수정 제출 → status 다시 pending으로 변경 확인
5. 로고 이미지 5MB 초과 → 에러 스낵바 표시, 업로드 차단 확인
6. 마스터 메뉴 등록: 이름/가격/이미지/태그 입력 → `brands/{brandId}/menuItems/{id}` 문서 생성 확인
7. 마스터 메뉴 복제 → 별도 draft 문서 생성, status=pending 확인
8. 마스터 메뉴 longpress → 삭제 다이얼로그 + priceOverride count 표시 확인
9. 승인 전 메뉴 노출/숨김 토글 → visible 필드 즉시 반영 확인
10. 반려된 브랜드 → 반려 사유 UI 표시 확인

### Admin 역할
11. `admin` role 계정 로그인 → AdminScaffold 진입 확인
12. 승인 큐 브랜드 탭 → pending 브랜드 목록 표시 확인
13. 승인 큐 마스터 메뉴 탭 → collectionGroup query pending 메뉴 목록 확인
14. 브랜드 승인 → status=approved, approvedBy/approvedAt 기록 확인
15. 브랜드 반려 → RejectReasonDialog 입력 → status=rejected, rejectedReason 저장 확인
16. 마스터 메뉴 승인/반려 동일 플로우 확인
17. collectionGroup 인덱스 미설정 환경 → 에러 뷰 + 재시도 버튼 확인

### 공통
18. 비 brand role 계정에서 BrandScaffold 직접 접근 불가 확인 (RoleRouter 분기)
19. owner/customer role 계정은 기존 화면 그대로 진입 확인

---

## 미구현 / 보류 항목

- `countStoresUsingPriceOverride`: 실제 집계 로직은 sub-phase 5(owner 옵션/soldOut) 이후 구현
- `deleteWithCascade` store price_override 삭제: sub-phase 5 이후 구현
- `optionGroupSelector`: 옵션 그룹 스트림 연동은 sub-phase 3(store customization) 이후 완성
- Firestore collectionGroup 인덱스 수동 설정 필요 (Firebase Console → 인덱스 탭)

---

## 결정 J 적용 — 핵심/운영 필드 분리 (갱신 섹션)

### 개요

umbrella 결정 J (핵심/운영 필드 분리 정책) 를 적용해 Repository / UseCase / Provider / 화면 wiring 을 갱신.

### 변경된 파일 목록

| 파일 | 변경 내용 |
|---|---|
| `lib/domain/repositories/master_menu_item_repository.dart` | `updateMasterMenuItem` 폐기, `updateMasterMenuItemCore` / `updateMasterMenuItemOperation` 신규 |
| `lib/domain/repositories/brand_repository.dart` | `upsertBrand` 주석 갱신 (결정 J 안(a) 내부 분기 명시) |
| `lib/domain/usecases/update_master_menu_item_core_use_case.dart` | 신규 — 핵심 필드 수정, status=pending 회귀 |
| `lib/domain/usecases/update_master_menu_item_operation_use_case.dart` | 신규 — 운영 필드 수정, status 보존 |
| `lib/domain/usecases/update_master_menu_item_use_case.dart` | `@Deprecated` 마커 추가, 내부 위임 `updateMasterMenuItemCore` 로 변경 |
| `lib/data/datasources/remote/brand_remote_data_source.dart` | `fetchById` 메서드 추가 (단발성 조회 — 변경 필드 분석용) |
| `lib/data/repositories/master_menu_item_repository_impl.dart` | `updateMasterMenuItemCore` / `updateMasterMenuItemOperation` 구현 |
| `lib/data/repositories/brand_repository_impl.dart` | `upsertBrand` — 기존 doc fetch 후 변경 필드 분석 (logoUrl만 변경 시 partial update, name/description 변경 시 status=pending 회귀) |
| `lib/presentation/brand/providers/brand_master_menu_providers.dart` | `updateMasterMenuItemUseCaseProvider` 제거, `updateMasterMenuItemCoreUseCaseProvider` / `updateMasterMenuItemOperationUseCaseProvider` 신규 |
| `lib/presentation/brand/master_menu/master_menu_form_page.dart` | `_hasCoreFieldChange` / `_hasOperationFieldChange` 헬퍼 추가, `_submit` 에 변경 필드 분석 분기 추가 |
| `lib/presentation/brand/master_menu/master_menu_list_page.dart` | `_VisibleToggleButton` 위젯 신규, 카드 인라인 visible 즉시 토글 UX 추가 |

### 추가된 UseCase

| UseCase | 파일 | 역할 |
|---|---|---|
| `UpdateMasterMenuItemCoreUseCase` | `update_master_menu_item_core_use_case.dart` | 핵심 필드 수정 — status=pending 회귀 |
| `UpdateMasterMenuItemOperationUseCase` | `update_master_menu_item_operation_use_case.dart` | 운영 필드 수정 — status 보존, 즉시 반영 |

### 폐기된 UseCase

| UseCase | 파일 | 상태 |
|---|---|---|
| `UpdateMasterMenuItemUseCase` | `update_master_menu_item_use_case.dart` | `@Deprecated` 마커. 내부는 `updateMasterMenuItemCore` 위임. 추후 제거 예정 |

### Repository 메서드 변경

#### MasterMenuItemRepository (Domain)

| 메서드 | 변경 |
|---|---|
| `updateMasterMenuItem` | 폐기 (인터페이스에서 제거, Impl 에서 Core 로 대체) |
| `updateMasterMenuItemCore(item)` | 신규 — ownership + optionGroupRefs scope 검증 + status=pending + submittedBy/At 갱신 + approvedBy/At 보존 |
| `updateMasterMenuItemOperation(item)` | 신규 — ownership 검증 + visible/tags/displayOrder/imageUrl partial update + status/승인메타 보존 |

#### BrandRepository (Domain)

- `upsertBrand` 단일 메서드 유지 (운영 필드 1개 — 별도 메서드 분리 ROI 낮음)
- `BrandRepositoryImpl` 내부 분기:
  - 신규 등록 → status=pending 강제
  - 기존 수정, name/description 변경 → status=pending 회귀 + submittedBy/At 갱신
  - 기존 수정, logoUrl 만 변경 → `update(partial)` status/승인메타 보존

### 화면 wiring 변경

#### master_menu_form_page.dart — 변경 필드 분석

- `_hasCoreFieldChange(old, next)`: name / basePrice / mainCategoryCode / subCategoryId / description / optionGroupRefs 비교
- `_hasOperationFieldChange(old, next)`: visible / displayOrder / imageUrl / tags 비교
- `_submit` 수정 모드 분기:
  1. 변경 없음 → pop (호출 없음)
  2. 핵심 필드 포함 → priceOverride 다이얼로그(basePrice 변경 시) → `updateMasterMenuItemCoreUseCase` → 스낵바 "수정 사항이 검토 대기 중입니다"
  3. 운영 필드만 → `updateMasterMenuItemOperationUseCase` → 스낵바 "즉시 반영되었습니다"

#### master_menu_list_page.dart — visible 즉시 토글

- `_VisibleToggleButton` (`ConsumerStatefulWidget`): 카드 인라인 아이콘 버튼
  - `visibility_rounded` (노출) / `visibility_off_rounded` (숨김) 아이콘
  - onTap → `updateMasterMenuItemOperationUseCase.call(item.copyWith(visible: !item.visible))`
  - 로딩 중 `CircularProgressIndicator` 표시, 오류 시 스낵바
  - status 라벨 (ApprovalStatusBadge) 그대로 유지

### 회귀 검증 결과

- `flutter analyze`: **No issues found!**
- 기존 sub-phase 1 신규 등록 / 복제 / 삭제 / 승인 / 반려 흐름: 변경 없음
- `createMasterMenuItemUseCase` / `deleteMasterMenuItemUseCase` / `cloneMasterMenuItemUseCase`: 변경 없음
- `MenuItemEntity` / `MenuItemModel` freezed 필드 변경 없음 — build_runner 재실행 불필요
- customer / owner 모듈에서 `updateMasterMenuItemUseCaseProvider` 참조 없음 (grep 확인)

### 미구현/보류 (결정 J 범위 기준)

- tags / displayOrder / imageUrl 빠른 편집 (카드 인라인 직접 편집): 후속 phase 에서 점진적으로. 현재는 폼에서만 가능
- `brand_info_page.dart` 의 logoUrl 빠른 변경 UX: 본 갱신 비범위 (폼에서 수정)
