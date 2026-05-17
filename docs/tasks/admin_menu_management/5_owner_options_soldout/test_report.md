# test_report — sub-phase 5 (owner_options_soldout)

> 검증 일자: 2026-04-30  
> 검증자: tester  
> 기준 문서: spec.md (W1~W10) / design/ (D1~D6) / implementation.md  
> 대상 코드: lib/ 실제 구현 파일  
> flutter analyze: **0 issues**

---

## 1. 전체 결과 요약

| 구분 | 건수 |
|---|---|
| PASS | 32 |
| FAIL | 0 (FAIL-1, FAIL-2 모두 2026-05-01 해소) |
| 보류 | 4 |

> 회귀: `flutter analyze` 0 issue 재확인 완료.
> FAIL-1: `_BrandMenuManagementButton` 신규 추가 (`my_store_page.dart` `_BrandStoreDetailView` approved 분기).
> FAIL-2: `_mergeForBrandStore` 운영 필드 (soldOut / disabledOption*) status 무관 즉시 머지 + 핵심 필드 (priceOverride / excluded) 는 approved 한정 머지로 분리.

---

## 2. 항목별 결과표

### 2-1. spec W1~W10 (결정사항)

| ID | 항목 | 결과 | 비고 |
|---|---|---|---|
| W1 | Repository 메서드 재사용 — sub-phase 3/4 `updateStoreOnlyMenuOperation` + 신규 `updateOverrideOperationFields` | PASS | `ToggleSoldOutForPersonalMenuUseCase` → `updateStoreOnlyMenuOperation`, `ToggleSoldOutForOverrideUseCase` → `updateOverrideOperationFields` 정상 연결 |
| W2 | 브랜드 매장 마스터 메뉴 upsert — override 신규 시 status='approved' / 기존 시 partial update | PASS | `MenuOverrideRepositoryImpl.updateOverrideOperationFields` 내 `getByStoreAndMaster` 분기 → set/update 정확히 구현, priceOverride=null / excluded=false / updatedBy='owner' / submittedBy=uid 확인 |
| W3 | ownership 분리 — `_assertOwnerOfPersonalStore` + `_assertOwnerOfBrandStore` | PASS (조건부) | `_assertOwnerOfBrandStore`는 `MenuOverrideRepositoryImpl`에 구현됨. `MenuItemRepositoryImpl.updateStoreOnlyMenuOperation`은 `_assertOwnershipOrAdmin`(uid null-check) 사용. implementation.md 에서 "Firestore 보안 규칙 최종 권한 위임"으로 설계 결정이 명시되어 있어 PASS 처리하나, 실기기 검증 보류 항목 참조 |
| W4 | `OptionRepository.getOptionGroupsForMenuItem` 시그니처 변경 + 호출자 갱신 | PASS | named parameters `disabledGroupIds`/`disabledItemIds` 추가 (default `{}`). `GetOptionGroupsForMenuItemUseCase.call`이 `menuItem.disabledOptionGroupIds.toSet()`/`disabledOptionItemIds.toSet()`를 자동 전달 → `menuItemOptionGroupsProvider`를 통해 customer 측 필터 실제 활성화됨. implementation.md의 "미구현" 설명은 오류 — 코드 기준으로 PASS |
| W5 | 카드 인라인 품절 토글 — visible 옆 동등 배치 | PASS | `_InlineVisibleToggle` + `SoldOutToggle` Row 배치, SizedBox(width:4) 간격 확인 |
| W6 | 옵션 비활성 BottomSheet 즉시 저장 (onChange 즉시) | PASS | `_onGroupToggle`/`_onItemToggle` → optimistic setState → `_callSaveUseCase()` 즉시 호출. 실패 시 prevGroupIds/prevItemIds 원복 + SnackBar |
| W7 | `OwnerBrandStoreMenusPage` 신규 | PASS (파일) / FAIL (진입점) | 파일 자체는 완성됨. 단 **진입점(`_BrandMenuManagementButton`)이 `my_store_page.dart`에 미구현** — FAIL-1 참조 |
| W8 | CTA 분리 — 개인 "메뉴 관리" / 브랜드 "메뉴 옵션·품절 관리" | FAIL | `_BrandStoreDetailView`에 "메뉴 옵션·품절 관리" CTA 미존재. `_BrandStoreActionButtons`에 `_BrandMenuManagementButton` 미추가. 브랜드 매장 점주가 `OwnerBrandStoreMenusPage`에 진입 불가 — FAIL-1 |
| W9 | customer 회귀 — 옵션 비활성 / 품절 즉시 반영 | 보류 | 실기기 E2E 검증 필요. 코드 경로는 확인됨 |
| W10 | 시드 데이터 변경 없음 | PASS | 신규 시드 파일 없음 확인 |

### 2-2. design D1~D6

| ID | 항목 | 결과 | 비고 |
|---|---|---|---|
| D1 | CTA 분리 — 개인/브랜드 상호 배타 | FAIL | W8과 동일 — 브랜드 CTA 미구현 |
| D2 | `_SoldOutToggle` 카드 인라인 (AppColors.error) | PASS | `SoldOutToggle` 위젯: `activeThumbColor: AppColors.error`, `activeTrackColor: AppColors.error.withValues(alpha: 0.3)` 확인 |
| D3 | `_InlineVisibleToggle` "표시" 라벨 추가 | PASS | `_InlineVisibleToggle.build`에 `Text('표시')` Column 구조 확인 |
| D4 | 시트 즉시 저장 (onChange) | PASS | W6와 동일 |
| D5 | 그룹 비활성 시 항목 숨김 + 안내 문구 | PASS | `isGroupDisabled == true` 시 항목 Row 대신 안내 Text 노출 ("그룹을 활성화하면 항목별 관리가 가능해요."), design 명세의 "안내 문구 방식" 채택 |
| D6 | Switch 의미 역전 (`value = !isDisabled`) | PASS | 그룹 Switch: `value: !isGroupDisabled`, 항목 Switch: `value: !isItemDisabled` 확인 |

### 2-3. 신규 구현 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| `MenuOptionDisableSheet` — 구조 (DraggableScrollableSheet / SheetHeader / GroupRow / ItemRow) | PASS | initialChildSize 0.75, min 0.4, max 0.92 / SheetHeader에 메뉴명 + close 아이콘 |
| `MenuOptionDisableSheet` — `_SelectionBadge` (필수/선택 배지) | PASS | `group.required` 분기, AppColors.error / AppColors.textMuted 토큰 사용 |
| `MenuOptionDisableSheet` — Error/Empty 상태 위젯 | PASS | `_ErrorBody` 재시도 버튼, `_EmptyBody` menuType 분기 문구 |
| `MenuOptionDisableSheet` — `_isSaving` 중복 방지 플래그 | PASS | `if (_isSaving) return;` 가드 확인 |
| `SoldOutToggle` — props (soldOut / isLoading / onChanged) | PASS | design 명세와 일치 |
| `OwnerBrandStoreMenusPage` — FAB 없음 | PASS | Scaffold에 floatingActionButton 미존재 |
| `OwnerBrandStoreMenusPage` — `_BrandStoreInfoBanner` | PASS | AppColors.info 토큰, 안내 문구 정확 |
| `OwnerBrandStoreMenusPage` — `_BrandStoreMenuCard` scope 분기 (brand/store) | PASS | `MenuItemScope.brand` 분기: override upsert 경로 / `MenuItemScope.store` 분기: personal 경로 |
| `OwnerBrandStoreMenusPage` — `_ScopeBadge` (마스터/매장 한정) | PASS | AppColors.primary / AppColors.accent 토큰 |
| `OwnerBrandStoreMenusPage` — long-press 액션 시트 ("옵션 관리" 만) | PASS | `_BrandActionSheet`에 "옵션 관리" ListTile만 존재, 편집/삭제 없음 |
| `OwnerBrandStoreMenusPage` — soldOut 오버레이 (AppColors.error 0.06) | PASS | `Positioned.fill` Container 확인 |
| `OwnerStoreMenuListPage` — `SoldOutToggle` 인라인 추가 (W5) | PASS | 카드 Row에 `_InlineVisibleToggle` + `SoldOutToggle` 나란히 배치 |
| `OwnerStoreMenuListPage` — `_ActionSheet`에 "옵션 관리" 최상단 | PASS | ListTile '옵션 관리' → Divider → 편집 순서 |
| `OwnerStoreMenuListPage` — soldOut 상태 오버레이 + 배지 우선순위 | PASS | `if soldOut → _SoldOutBadge elif !visible → _HiddenBadge` |
| `OwnerStoreMenuDetailPage` — PopupMenu '옵션 관리' 최상단 | PASS | `_MenuAction.manageOptions` PopupMenuItem 최상단 |
| `OwnerStoreMenuDetailPage` — soldOut 오버레이 + "품절" 텍스트 | PASS | `_ImageSection`에 Stack 오버레이 구현 확인 |
| `OwnerStoreMenuDetailPage` — `_InfoRow('품절 여부', ...)` + valueColor | PASS | AppColors.error / AppColors.success 조건부 색상 |
| `MenuItemRepositoryImpl.updateStoreOnlyMenuOperation` — disabledOption* / soldOut partial update | PASS | 파셜 맵에 `soldOut`, `disabledOptionGroupIds`, `disabledOptionItemIds` 포함 |
| `MenuOverrideRepositoryImpl.updateOverrideOperationFields` — 신규 메서드 | PASS | W2 upsert 패턴 정확히 구현 |
| `OptionRepositoryImpl.getOptionGroupsForMenuItem` — disabledGroupIds/disabledItemIds 필터 | PASS | compositeId `{groupId}_{itemId}` 매칭, 빈 인자 시 조기 반환 최적화 |
| `ownerBrandStoreMenusProvider` — StreamProvider.family, case B 머지 | PASS | `repo.watchByStore(storeId, brandId: brandId)` 연결 |
| DI 구성 — DataSource/Repository/UseCase Provider 트리 | PASS | `owner_brand_store_menus_providers.dart` 독립 트리 |

### 2-4. Clean Architecture / 절대 규칙

| 항목 | 결과 | 비고 |
|---|---|---|
| presentation/domain 레이어 cloud_firestore 직접 import 0건 | PASS | 신규 파일 모두 확인, data 레이어 한정 |
| AppColors 토큰만 사용, `Color(0x...)` 0건 | PASS | 신규 5개 파일 모두 AppColors 토큰만 사용 |
| `flutter analyze` 0 issues | PASS | |

### 2-5. 회귀 검증

| 항목 | 결과 | 비고 |
|---|---|---|
| Phase 1a 옵션 picker 회귀 — `getOptionGroupsForMenuItem` 시그니처 변경 호환 | PASS | named parameter default `{}` 적용 → 기존 호출자 변경 없음. Dart named parameter 호환 |
| `menuItemOptionGroupsProvider` 기존 동작 보존 | PASS | UseCase 경유로 disabledOption* 자동 전달 (필터 실제 활성화 — W4 완료) |
| `menuItemAllOptionGroupsProvider` 신규 — 시트용 전체 옵션 반환 | PASS | OptionRepository 직접 호출, 인자 없음 → 필터 미적용 |
| sub-phase 4 visible 토글 동작 보존 | PASS | `_InlineVisibleToggle` 로직 변경 없음, 라벨만 추가 |
| sub-phase 3 case B 머지 soldOut/disabledOption* status 무관 즉시 반영 | **FAIL** | `_mergeForBrandStore`에서 override의 `soldOut`/`disabledOptionGroupIds`/`disabledOptionItemIds`를 MenuItemEntity에 복사하지 않음. `approvedOverrides`만 사용하여 status=pending 운영 필드도 미반영 — FAIL-2 |
| sub-phase 3 case B 머지 priceOverride/excluded — approved 시만 적용 | PASS | `approvedOverrides` 필터 후 `basePrice: ov.priceOverride ?? m.basePrice` 적용 |

---

## 3. FAIL 항목 상세

### FAIL-1 (Critical) — W8 / D1: 브랜드 매장 "메뉴 옵션·품절 관리" CTA 미구현

- **문제**: `OwnerBrandStoreMenusPage`가 구현되어 있으나 진입점이 없음. `my_store_page.dart`의 `_BrandStoreDetailView`에 `_BrandMenuManagementButton`이 미추가. 브랜드 매장 점주가 신규 화면에 진입할 수 없음.
- **위치**: `lib/presentation/owner/my_store/my_store_page.dart` — `_BrandStoreDetailView.build` (L313~375) 및 `_BrandStoreActionButtons` (L1067~1102)
- **확인 방법**: `grep -n "OwnerBrandStoreMenusPage\|메뉴 옵션" lib/presentation/owner/my_store/my_store_page.dart` → 결과 없음
- **수정 방향**:
  1. `my_store_page.dart`의 `_BrandStoreDetailView` 내 SliverList에 `_MenuManagementButton` 위치 아래 (또는 `_BrandStoreActionButtons` 아래)에 `_BrandMenuManagementButton` 위젯 추가.
  2. `_BrandMenuManagementButton` 위젯 구현: `store.brandId != null && store.status == EntityApprovalStatus.approved` 조건, `ElevatedButton.icon`으로 "메뉴 옵션·품절 관리" 라벨, `Navigator.push(MaterialPageRoute(builder: (_) => OwnerBrandStoreMenusPage(store: store)))`.
  3. design `owner_module.md` §1 레이아웃 명세 참조.
- **우선순위**: P0 (기능 완전 차단)

---

### FAIL-2 (High) — spec G: case B 머지에서 override의 운영 필드(soldOut / disabledOption*) 미반영

- **문제**: `MenuItemRepositoryImpl._mergeForBrandStore`에서 override 적용 시 `basePrice`만 복사하고 `soldOut`, `disabledOptionGroupIds`, `disabledOptionItemIds`는 머지된 MenuItemEntity에 반영하지 않음. 또한 `approvedOverrides`만 필터하므로 status=pending/rejected 상태 override의 운영 필드도 미반영됨. spec G / umbrella 머지 규칙 위반 — "운영 필드는 status 무관 즉시 머지".
- **위치**: `lib/data/repositories/menu_item_repository_impl.dart` L89~111 (`_mergeForBrandStore`)
- **확인 방법**: `_mergeForBrandStore` 내 `m.copyWith` 호출부 — `basePrice`만 전달, `soldOut`/`disabledOption*` 미포함. `approvedOverrides` 필터가 운영 필드까지 차단.
- **수정 방향**:
  ```dart
  // 모든 override를 Map으로 구성 (status 무관 — 운영 필드용)
  final allOverrideMap = {
    for (final o in overrides) o.masterMenuItemId: o
  };
  // status=approved override만 핵심 필드(priceOverride/excluded) 적용용
  final approvedOverrideMap = {
    for (final o in overrides.where((o) => o.status == EntityApprovalStatus.approved))
      o.masterMenuItemId: o
  };

  final mergedMaster = approvedMaster
      .where((m) => !(approvedOverrideMap[m.id]?.excluded ?? false))
      .map((m) {
        final approvedOv = approvedOverrideMap[m.id];
        final anyOv = allOverrideMap[m.id];
        return m.copyWith(
          basePrice: approvedOv?.priceOverride ?? m.basePrice,
          soldOut: anyOv?.soldOut ?? m.soldOut,                         // 운영 필드 즉시 반영
          disabledOptionGroupIds: anyOv?.disabledOptionGroupIds ?? m.disabledOptionGroupIds,
          disabledOptionItemIds: anyOv?.disabledOptionItemIds ?? m.disabledOptionItemIds,
        );
      })
      .toList();
  ```
- **우선순위**: P1 (브랜드 매장 품절/옵션 비활성 기능 핵심 동작 불가)

---

## 4. 보류 항목

| ID | 항목 | 사유 |
|---|---|---|
| 보류-1 | customer E2E — 점주 토글 → customer StoreMenuPage/MenuItemDetailPage 즉시 반영 | 실기기 + Firestore stream 검증 필요. 코드 경로는 확인됨 (단, FAIL-2 수정 후 재검증 필요) |
| 보류-2 | override status='pending' 상태에서 점주 운영 필드 토글 → status 보존 | Firestore 실데이터 검증 필요. FAIL-2 수정 후 재검증 |
| 보류-3 | `_assertOwnerOfPersonalStore` / `_assertOwnerOfBrandStore` 실 권한 가드 — 점주가 타인 매장 조작 차단 | Firestore 보안 규칙 미구현 (별도 task). 앱 레이어에서는 uid null-check만. implementation.md 에서 "Firestore 규칙에 위임" 명시 |
| 보류-4 | `excluded == true` (admin 승인 제외) 메뉴 안내 카드 | implementation.md 에서 "비노출 채택"으로 명시. spec W7 에서 양방향 허용. 기능 비범위로 처리 |

---

## 5. implementation.md 보고된 미구현/spec 차이 검토

| 항목 | tester 판단 |
|---|---|
| `MenuOptionDisableSheetType` 통합 (brandStoreOnly → personal) | PASS — spec E 허용 범위 내 구현 단순화. 코드 경로 동일 |
| 시트 저장 타이밍: spec "닫기 시" → design W6 "즉시" 채택 | PASS — spec 과 design 불일치 시 design 우선 (spec §W6 의 BottomSheet 결정이 design 에서 즉시 저장으로 세분화됨) |
| customer `menuItemOptionGroupsProvider`에 disabledOption* 인자 미전달 | **코드 재확인 결과 실제 구현됨** — `GetOptionGroupsForMenuItemUseCase.call`이 menuItem의 필드를 자동 전달. implementation.md의 "미구현" 설명이 오류. PASS |
| `excluded` 메뉴 "매장 제외됨" 안내 카드 미구현 | 보류-4 처리 |

---

## 6. 우선 수정 순서

1. **FAIL-1 (P0)**: `my_store_page.dart`에 `_BrandMenuManagementButton` 추가 → 브랜드 매장 점주 진입 경로 복구
2. **FAIL-2 (P1)**: `_mergeForBrandStore`에서 override 운영 필드(soldOut/disabledOption*) status 무관 즉시 머지 적용

---

## 7. 후속 작업 제안

- **보류-1/2**: FAIL-1/2 수정 후 실기기 E2E 검증 (브랜드 매장 점주 → 품절 토글 → customer 즉시 반영 / status=pending override 운영 필드 보존)
- **보류-3**: `firestore_rules` task에서 `stores/{storeId}` 쓰기 권한 `ownerId == request.auth.uid` 규칙 추가 후 재검증
- **보류-4**: UX 요구에 따라 `excluded=true` 메뉴 별도 섹션(읽기 전용 "매장 제외됨" 행) 노출 여부 결정

---

## 8. admin_menu_management phase 전체 완료 상태

sub-phase 5가 admin_menu_management의 마지막 sub-phase입니다.

- sub-phase 1/2/3/4: 이전 test_report에서 PASS 판정
- sub-phase 5: FAIL 2건 존재

**FAIL-1 (W8 CTA 미구현)과 FAIL-2 (case B 머지 운영 필드 누락)가 수정 완료된 후 admin_menu_management 전체 완료로 판정할 수 있습니다.**

umbrella 전체 완료 기준 항목 중 sub-phase 5 관련:
- 브랜드 매장 품절/옵션 비활성 e2e: FAIL-1/2 수정 필요
- 운영 필드 status 무관 즉시 반영: FAIL-2 수정 필요
- 그 외 role 라우팅 / admin 승인 큐 / customer 회귀: sub-phase 1~4에서 기확인됨 (본 sub-phase 코드 변경 없음)
