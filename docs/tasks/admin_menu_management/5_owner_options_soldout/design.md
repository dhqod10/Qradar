# sub-phase 5 — owner_options_soldout 디자인 명세 (인덱스)

> 작성자: designer
> 참조 spec: `docs/tasks/admin_menu_management/5_owner_options_soldout/spec.md`
> 상태: DONE

---

## 개요

점주의 옵션 비활성 + 품절 토글 UI 명세. 개인 매장 / 브랜드 매장 공통, 즉시 반영.

- **기존 화면 갱신** 2종: `OwnerStoreMenuListPage`, `OwnerStoreMenuDetailPage` (sub-phase 4 산출)
- **기존 화면 갱신** 1종: `OwnerMyStorePage` (sub-phase 2/4 산출) — CTA 분기 추가
- **신규 화면** 1종: `OwnerBrandStoreMenusPage` — 브랜드 매장 점주용 메뉴 리스트
- **신규 위젯** 2종: `MenuOptionDisableSheet` (BottomSheet), `_SoldOutToggle` (카드 인라인)

---

## 파일 구성

| 파일 | 내용 |
|---|---|
| `design/owner_module.md` | OwnerStoreMenuListPage 갱신 / OwnerStoreMenuDetailPage 갱신 / OwnerBrandStoreMenusPage 신규 / OwnerMyStorePage CTA 갱신 |
| `design/common_components.md` | MenuOptionDisableSheet / _SoldOutToggle / _OptionDisableGroupRow / _OptionDisableItemRow |

---

## 디자인 결정사항 요약

### 1. CTA 정책 — 두 CTA 분리 (W8 결정 채택)

`OwnerMyStorePage` 에서 매장 종류에 따라 CTA 를 **분리 노출**한다.

- 개인 매장 (`store.brandId == null`): 기존 `_MenuManagementButton` "메뉴 관리" 유지 → `OwnerStoreMenuListPage`
- 브랜드 매장 (`store.brandId != null`): 신규 `_BrandMenuManagementButton` "메뉴 옵션·품절 관리" 추가 → `OwnerBrandStoreMenusPage`
- 두 버튼은 한 페이지에서 동시 노출되지 않는다 — brandId 분기로 상호 배타 노출.

**사유**: 단일 CTA 로 통합 시 매장 종류에 따라 내부 분기가 복잡해지고 사용자가 어느 화면으로 가는지 예측하기 어렵다. 분리하면 라벨이 권한을 명시해 혼동을 줄인다.

### 2. 카드 인라인 품절 토글 — `_SoldOutToggle` 신규 (W5 결정 채택)

- visible 토글(`_InlineVisibleToggle`) 과 **동등 인라인 배치** — 카드 우상단 Row 에 두 스위치를 나란히.
- `_InlineVisibleToggle` 과 동일한 패턴(`Switch.adaptive`) 을 `_SoldOutToggle` 로 새 위젯으로 추출.
- 색상 차별화: visible 토글 = `AppColors.primary`, 품절 토글 = `AppColors.error`.

### 3. 옵션 비활성 시트 — 즉시 저장 (W6 결정 채택)

`MenuOptionDisableSheet` 에서 토글 onChange 즉시 Repository 호출. 별도 "저장" 버튼 없음.  
닫기(X 버튼 / outside tap) 는 단순 dismiss 만 수행 (저장은 이미 완료).  
실패 시 optimistic update 원복 + SnackBar 표시.

### 4. 그룹 비활성 시 항목 토글 — disabled 처리

그룹 전체 토글이 off(비활성) 상태면 그룹 내 항목들의 `Switch` 를 `onChanged: null` 로 비활성화. "그룹을 활성화하면 항목별 관리가 가능해요" 안내 텍스트 표시.

### 5. 브랜드 매장 카드 visible 토글 — 미노출

`OwnerBrandStoreMenusPage` 의 카드에는 visible 토글을 노출하지 않는다. visible 은 brand 가 관리하는 운영 필드이기 때문이다. 품절 토글(`_SoldOutToggle`) 만 인라인 노출.

### 6. 카드 soldOut + visible 동시 상태 — 품절 우선 시각

- `soldOut == true` : 카드 배경에 `AppColors.error.withOpacity(0.06)` 오버레이 + `_SoldOutBadge` 표시
- `visible == false` (개인 매장 카드): 카드 흐림(`opacity: 0.55`) + `_HiddenBadge` 표시
- 둘 다 true: "품절" 배지 우선 노출, 카드 흐림(`opacity: 0.55`) 도 병행
- 브랜드 매장 카드(`OwnerBrandStoreMenusPage`): visible 토글 없으므로 soldOut 상태만 반영

---

## 화면 / 위젯 목록

| 화면 / 위젯 | 파일 경로 | 상태 |
|---|---|---|
| OwnerMyStorePage 갱신 | `presentation/owner/my_store/my_store_page.dart` | 갱신 |
| OwnerStoreMenuListPage 갱신 | `presentation/owner/store_menu/owner_store_menu_list_page.dart` | 갱신 |
| OwnerStoreMenuDetailPage 갱신 | `presentation/owner/store_menu/owner_store_menu_detail_page.dart` | 갱신 |
| OwnerBrandStoreMenusPage 신규 | `presentation/owner/brand_store/owner_brand_store_menus_page.dart` | 신규 |
| MenuOptionDisableSheet 신규 | `presentation/common/option_disable_sheet/menu_option_disable_sheet.dart` | 신규 |
| _SoldOutToggle 신규 | `presentation/owner/store_menu/widgets/sold_out_toggle.dart` | 신규 |

---

## 상태 UI 정책 (전체 공통)

| 상태 | 처리 방식 |
|---|---|
| 로딩 | `CircularProgressIndicator(color: AppColors.primary)` — 중앙 배치 |
| 에러 | 공통 에러 카드 패턴 (아이콘 `AppColors.error` + 재시도 버튼 `AppColors.primary`) |
| 빈 상태 | 아이콘 `AppColors.textMuted` + 안내 문구 `AppColors.textBody` |
| 권한 없음 | RoleRouter 단계에서 차단 — 화면 내 별도 UI 불필요 |

---

## 상세 명세 파일

- [design/owner_module.md](design/owner_module.md)
- [design/common_components.md](design/common_components.md)
