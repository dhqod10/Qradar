# admin_menu_management / 1_brand_master 디자인 명세 (인덱스)

> 분량이 크기 때문에 모듈별로 분리한다. 본 파일은 인덱스 역할만 한다.

## 분할 파일

| 파일 | 내용 |
|---|---|
| [design/brand_module.md](design/brand_module.md) | BrandScaffold / BrandInfoPage / BrandFormPage / MasterMenuListPage / MasterMenuFormPage / MasterMenuDetailPage / BrandMorePage |
| [design/admin_module.md](design/admin_module.md) | AdminScaffold / AdminPendingQueuePage / AdminBrandApprovalDetailPage / AdminMasterMenuApprovalDetailPage / AdminMorePage |
| [design/common_components.md](design/common_components.md) | ApprovalStatusBadge / RejectReasonDialog / ImageUploadField / TagChipsSelector / VisibilityToggle / OptionGroupSelector / ApprovalActionsBar / 공통 상태 UI |

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 화면 톤 기반 신규 설계)
- 기존 화면 톤:
  - `lib/presentation/owner/owner_scaffold.dart` — BottomNav 패턴
  - `lib/presentation/owner/more/owner_more_page.dart` — More 페이지 _Tile 패턴
  - Phase 1a `docs/tasks/order_flow_phase1a/design.md` — MenuItemDetailPage 폼 톤 재사용
- 색상 토큰: `lib/core/theme/app_colors.dart`

## 핵심 디자인 결정사항

1. **status 색상 토큰 매핑**
   - `pending` → `AppColors.warning` (배경) + `AppColors.textHeading` (라벨)
   - `approved` → `AppColors.success` (배경) + `AppColors.onPrimary` 계열 (라벨)
   - `rejected` → `AppColors.error` (배경) + `AppColors.onPrimary` 계열 (라벨)

2. **BottomNav 활성 색상**: owner 모듈과 동일하게 `AppColors.accent` 활성 / `AppColors.textMuted` 비활성

3. **폼 패턴**: Phase 1a `MenuItemDetailPage` 톤 재사용. 섹션 카드 구분 + `AppColors.surfaceElevated` 배경 입력창

4. **다이얼로그 톤**: `borderRadius: 16`, `AppColors.surfaceElevated` 배경, title w700/16, content w500/13

5. **이미지 fallback**: 브랜드 로고 → `Icons.storefront_rounded`, 메뉴 이미지 → `Icons.local_cafe_outlined`. 배경 `AppColors.surface`

6. **승인 큐 세그먼트**: `NavigationBar` 스타일 세그먼트 컨트롤 대신 상단 고정 탭 바 (2개 라벨) 사용. `AppColors.primary` 활성 언더라인

7. **AdminScaffold 2탭**: 승인 큐(`Icons.pending_actions_rounded`) / 더보기(`Icons.more_horiz_rounded`)

8. **BrandScaffold 3탭 (sub-phase 1)**: 브랜드 정보 / 마스터 메뉴 / 더보기. 매장 탭은 sub-phase 3 에서 추가.
