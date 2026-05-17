# sub-phase 4 — owner_personal_menu 디자인 명세 (인덱스)

> **상태**: APPROVED
>
> **관련 spec**: [`spec.md`](spec.md)
>
> **산출물 구조**:
> - 본 파일 (인덱스 + 주요 결정사항)
> - [`design/owner_module.md`](design/owner_module.md) — OwnerMyStorePage 갱신 + 신규 화면 3종
> - [`design/common_components.md`](design/common_components.md) — OptionGroupSelector 확장 + 재사용 위젯 표

---

## 참조한 디자인

- **sub-phase 1 brand_module.md** — MasterMenuListPage / MasterMenuFormPage / MasterMenuDetailPage 레이아웃 패턴, MasterMenuItemCard 구조, 폼 섹션 구성 및 하단 제출 버튼
- **sub-phase 1 common_components.md** — ImageUploadField / TagChipsSelector / VisibilityToggle / OptionGroupSelector / 공통 상태 UI (Loading / Error / Empty)
- **sub-phase 2 owner_module.md** — OwnerMyStorePage 구조, _StoreActionButtons 배치 패턴
- **lib/core/theme/app_colors.dart** — AppColors 토큰

---

## 주요 디자인 결정사항

### D1. status 배지 / 승인 메타 / 검토 안내 배너 — 모두 미노출

개인 매장 메뉴는 admin 승인 게이트 없이 status=approved 가 즉시 박힌다. 따라서 아래 요소를 화면에서 완전히 제거한다.

- `ApprovalStatusBadge` — OwnerStoreMenuListPage 카드, OwnerStoreMenuDetailPage 모두 미노출
- "수정 대기" 라벨 — 미노출
- "검토 요청을 보냈어요" SnackBar — 미사용. "저장됐어요" 로 통일
- 승인 메타 섹션 (submittedAt / approvedAt / rejectedReason) — 미노출
- status 회귀 안내 다이얼로그 — 미노출 (sub-phase 1 MasterMenuFormPage 에 있던 가격 변경 priceOverride 알림도 불필요)

### D2. SnackBar 문구 통일

| 액션 | SnackBar 문구 |
|---|---|
| 등록 성공 | `'저장됐어요'` |
| 수정 성공 | `'저장됐어요'` |
| visible 토글 성공 | (별도 SnackBar 없음 — 카드 인라인 즉시 반영) |
| 삭제 성공 | `'삭제됐어요'` |
| 복제 후 폼 진입 | (SnackBar 없음 — 폼으로 이동) |
| 필수 항목 미충족 | `'필수 항목을 모두 입력해주세요'` |
| 이미지 5MB 초과 | `'이미지 용량이 5MB를 초과했습니다'` |
| 권한 없음 | `'권한이 없습니다'` |

### D3. OwnerMyStorePage 의 "메뉴 관리" CTA 배치

sub-phase 2 의 `_StoreActionButtons` (매장 정보 수정 / 운영 정보 수정 두 버튼) 아래에 **전체 너비 단독 행**으로 배치한다. 기존 두 버튼 Row 를 훼손하지 않으면서 명확하게 구분한다.

- 톤: `AppColors.primary` 배경 + `AppColors.onPrimary` 텍스트 (filled 버튼) — 메뉴 관리는 점주가 가장 자주 접근하는 핵심 액션이므로 primary 강조
- 기존 두 버튼과 시각적 위계 구분: 기존 두 버튼(OutlinedButton)보다 더 강한 색 → 메뉴 관리 CTA 가 계층적으로 앞에 위치
- 노출 조건: `store.brandId == null && store.status == EntityApprovalStatus.approved`

### D4. OptionGroupSelector 확장 — master + store 그룹 헤더 구분

기존 `OptionGroupSelector` 는 master scope 만 노출. 개인 매장 폼에서는 master + store 양쪽을 노출하되, **두 그룹을 헤더로 구분**한다.

- 헤더 "마스터 옵션" / "매장 옵션" 를 ListTile 위 소형 라벨로 표시
- 각 옵션 그룹의 subtitle 은 scope 에 맞는 텍스트 (`'마스터 옵션'` / `'매장 한정 옵션'`) 로 표시
- storeId 가 null 이면(마스터 메뉴 폼) 기존 동작 유지 (master only)

### D5. 즉시 반영 안내 배너 — 폼 상단 노출

OwnerStoreMenuFormPage 폼 상단에 sub-phase 2 의 StoreOperationFormPage 패턴과 동일하게 success 톤 배너를 표시한다.

- 내용: `'저장 즉시 반영돼요'`
- 배경: `AppColors.success.withOpacity(0.08)`, border `AppColors.success.withOpacity(0.3)`

### D6. visible 카드 인라인 토글 — sub-phase 1 _VisibleToggleButton 패턴 그대로

OwnerStoreMenuListPage 의 각 메뉴 카드에 인라인 visible 토글을 배치한다. 오류 시 UI 원복 + SnackBar `'변경에 실패했어요'`.

---

## 화면 목록 및 파일 경로

| 화면 | 파일 | 분류 |
|---|---|---|
| OwnerMyStorePage | `presentation/owner/my_store/my_store_page.dart` | 갱신 |
| OwnerStoreMenuListPage | `presentation/owner/store_menu/owner_store_menu_list_page.dart` | 신규 |
| OwnerStoreMenuFormPage | `presentation/owner/store_menu/owner_store_menu_form_page.dart` | 신규 |
| OwnerStoreMenuDetailPage | `presentation/owner/store_menu/owner_store_menu_detail_page.dart` | 신규 |
| OwnerStoreMenuCard | `presentation/owner/store_menu/widgets/owner_store_menu_card.dart` | 신규 (선택) |

---

## 상세 명세 위치

- Owner 모듈 전체 (레이아웃 / 컴포넌트 / 상태 UI / 인터랙션): [`design/owner_module.md`](design/owner_module.md)
- OptionGroupSelector 확장 + 재사용 위젯 정리: [`design/common_components.md`](design/common_components.md)

---

## 개발자 전달 특이사항 요약

1. `OwnerStoreMenuListPage` 는 sub-phase 1 의 `MasterMenuListPage` 에서 `ApprovalStatusBadge` 와 "수정 대기" 라벨을 제거한 형태. 코드 복사 후 status 관련 부분만 제거 또는 공통 위젯 추출 검토.
2. `OptionGroupSelector` 에 `storeId` 파라미터 추가 (V6). storeId 있으면 store scope 옵션도 fetch + 섹션 헤더 구분 표시.
3. `OwnerMyStorePage` 의 "메뉴 관리" CTA 는 `store.brandId == null && store.status == EntityApprovalStatus.approved` 조건 모두 충족 시에만 렌더링.
4. SnackBar 문구: "저장됐어요" / "삭제됐어요" (sub-phase 1 의 "검토 요청을 보냈어요" 와 구분).
5. `OwnerStoreMenuFormPage` 에서 `disabledOption*` / `soldOut` 필드 UI 미노출 (entity default 만 — sub-phase 5 활성화).
