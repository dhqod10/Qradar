# sub-phase 7 menu_option_group_management — implementation

## 구현 완료 항목

### 1. Domain / Data
- `OptionScope` enum: `master` (legacy), `brand` (신규), `store` 세 값
- `OptionGroupEntity` 확장: `active`, `brandId`, `storeId`, `createdAt`, `updatedAt`
- `OptionGroupRepository` 신규 (CRUD + countUsage + findDuplicateName)
- `OptionGroupRepositoryImpl` 신규
- `OptionGroupRemoteDataSource` 확장 (brand/store 2-tier + legacy master read)
- `OptionGroupModel` 매핑 확장
- `DuplicateOptionGroupNameException`, `OptionGroupInUseException` 신규
- UseCase 신규 6개 (Watch / Upsert / Toggle / Delete / FindDuplicateName / CountUsage)
- `optionGroupRefIds` 평면 필드 도입 (arrayContains 호환 fallback)

### 2. Brand 본사 CRUD UI
- `BrandOptionGroupListPage` — displayOrder 정렬, active Switch, 편집/삭제, FAB, _UsageChip, selectionType/required marker
- `BrandOptionGroupFormPage` (등록/수정 통합) — 디바운스 lookup, race 차단, _isDuplicateChecking 가드
- `OptionGroupDeleteDialog` — 사용 중 차단 + "비활성화로 전환"
- `BrandMorePage` 에 tile 추가 ("옵션 그룹 관리")

### 3. Owner 개인 매장 CRUD UI
- `OwnerStoreOptionGroupListPage` / `OwnerStoreOptionGroupFormPage` — 동일 구조, store scope
- `MyStorePage` 메뉴 관리 영역 진입 CTA — `store.brandId == null` 가드 (가맹점 미노출)

### 4. 핵심 위젯 — `OptionItemListEditor`
- 항목 동적 추가/삭제
- label TextField (1~20자) + 같은 그룹 내 중복 inline 에러
- **priceDelta UX**: 부호 토글 (+/-) + 절댓값 숫자 입력 + "원" 단위
- 음수 표시: "-500원" / 양수: "+500원" / 0: "0원"
- 빈 상태 처리

### 5. 메뉴 폼 selector 갱신
- `MasterMenuFormPage`: master ∪ brand 머지 노출
- `OwnerStoreMenuFormPage`: master ∪ store 머지 노출
- `BrandStoreOnlyMenuFormPage`: selector 통합 — 일부 보강 필요 (사용자 실기기 검증 시 확인)

### 6. 공통 위젯
경로: `lib/presentation/common/widgets/option_groups/`
- `OptionGroupDeleteDialog`
- `OptionItemListEditor`

---

## 신규 / 수정 파일

### 신규
- `lib/core/errors/duplicate_option_group_name_exception.dart`
- `lib/core/errors/option_group_in_use_exception.dart`
- `lib/domain/repositories/option_group_repository.dart`
- `lib/data/repositories/option_group_repository_impl.dart`
- `lib/domain/usecases/watch_option_groups_by_scope_use_case.dart`
- `lib/domain/usecases/upsert_option_group_use_case.dart`
- `lib/domain/usecases/toggle_option_group_active_use_case.dart`
- `lib/domain/usecases/delete_option_group_use_case.dart`
- `lib/domain/usecases/find_duplicate_option_group_name_use_case.dart`
- `lib/domain/usecases/count_option_group_usage_use_case.dart`
- `lib/presentation/brand/option_groups/brand_option_group_list_page.dart`
- `lib/presentation/brand/option_groups/brand_option_group_form_page.dart`
- `lib/presentation/brand/option_groups/providers/brand_option_group_providers.dart`
- `lib/presentation/owner/option_groups/owner_store_option_group_list_page.dart`
- `lib/presentation/owner/option_groups/owner_store_option_group_form_page.dart`
- `lib/presentation/owner/option_groups/providers/owner_option_group_providers.dart`
- `lib/presentation/common/widgets/option_groups/option_group_delete_dialog.dart`
- `lib/presentation/common/widgets/option_groups/option_item_list_editor.dart`

### 수정
- `lib/domain/entities/option_scope.dart` — `brand` 값 추가
- `lib/domain/entities/option_group_entity.dart` — 필드 확장
- `lib/data/models/option_group_model.dart` — 2-tier 매핑
- `lib/data/datasources/remote/option_remote_data_source.dart` — brand/store CRUD 추가
- `lib/presentation/brand/more/brand_more_page.dart` — "옵션 그룹 관리" tile
- `lib/presentation/owner/my_store/my_store_page.dart` — "옵션 그룹 관리" CTA (brandId==null 가드)
- `lib/presentation/brand/master_menu/master_menu_form_page.dart` — selector master ∪ brand
- `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` — selector master ∪ store

---

## flutter analyze 결과

```
Analyzing OrderApp...
No issues found! (ran in 4.4s)
```

---

## 사용자 실기기 검증 핵심 시나리오

### Brand 본사 CRUD
1. BrandMorePage → "옵션 그룹 관리" → FAB → 이름 + selectionType + required + items 입력 → 저장 → Firestore `brands/{brandId}/optionGroups/` 에 저장 확인
2. 같은 brand 내 동일 이름 입력 → 디바운스 후 inline 에러 노출
3. active Switch 토글 → 즉시 반영
4. 사용 중 옵션 그룹 삭제 → 차단 다이얼로그 + "비활성화로 전환"
5. 사용 0개 옵션 그룹 → hard delete

### Owner 개인 매장 CRUD
6. 개인 매장 점주 → MyStorePage → "옵션 그룹 관리" → 동일 흐름
7. 가맹점 매장 점주 → MyStorePage → tile **미노출** 확인

### priceDelta UX
8. 항목 추가 → 부호 토글 (+ → -) → 숫자 입력 → "-500원" 표시 확인
9. 0 입력 → "0원" 표시
10. 같은 그룹 내 동일 label 입력 → inline 에러

### 메뉴 폼 selector 갱신
11. 마스터 메뉴 등록 → "기본 옵션" + "브랜드 옵션" 섹션 분리 노출 확인
12. 개인 매장 메뉴 등록 → "기본 옵션" + "매장 옵션" 섹션 분리 노출 확인
13. 옵션 그룹 선택 → 저장 → Firestore `optionGroupRefs` 정상 박힘

### Customer 회귀
14. 가맹점 매장 진입 → 메뉴 상세 → 옵션 그룹들 정상 노출 (master + brand 머지)
15. 개인 매장 진입 → 메뉴 상세 → master + store 머지 노출

### Firestore 인덱스 (필요 시)
16. arrayContains: {scope, id} 객체 매칭 동작 확인. 안 되면 `optionGroupRefIds` 평면 필드로 자동 fallback (이미 적용)

---

## 미완 / 보류 / 후속

- **`BrandStoreOnlyMenuFormPage` selector 통합**: 일부 미완성 가능성. 사용자 실기기 검증 시 그 폼에서 옵션 그룹 칩이 노출되는지 확인 필요. 누락이면 별도 patch.
- **Firestore 인덱스 갱신**: arrayContains 호환 PoC 결과에 따라 `firestore.indexes.json` 추가 필요할 수 있음.

---

## Follow-up (이번 phase 비범위)
- F3: 옵션 항목 reordering (drag-drop)
- F4: 옵션 항목 단위 active toggle
- F10: `applicableMainCategories` 자동 필터 (메인 카테고리별 옵션 그룹 노출 제한)
- F11: admin 옵션 그룹 모니터링 / 분포 audit
