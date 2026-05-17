# sub-phase 9 — menu_main_category_admin 테스트 리포트

> **작성일**: 2026-05-03
> **검증 방식**: 정적 분석 (코드 리뷰 + flutter analyze)
> **결과 요약**: PASS 31 / FAIL 2 / 보류 13

---

## 전체 결과 요약

| 구분 | 건수 |
|---|---|
| PASS | 31 |
| FAIL | 2 |
| 보류 (실기기 필요) | 13 |

---

## FAIL 항목

### FAIL-1. firestore.indexes.json 인덱스 필드명 불일치 [우선순위: CRITICAL]

| 항목 | 내용 |
|---|---|
| 파일 | `/firestore.indexes.json` |
| 문제 | `fieldPath: "mainCategoryCode"` 로 작성됨 |
| 실제 Firestore 필드명 | `mainCategory` (MenuItemModel.fromFirestore 및 collectionGroup 쿼리 모두 `'mainCategory'` 사용) |
| 영향 | 배포된 인덱스가 실제 쿼리 필드와 다름. 삭제 차단 쿼리(`countMenuItemUsage`) 및 `countDetailedUsage` 가 인덱스를 활용하지 못하고 오류 또는 풀 스캔 발생 가능. spec 결정 4a 요구사항 미달. |
| 수정 방법 | `firestore.indexes.json` 의 `fieldPath` 를 `"mainCategoryCode"` → `"mainCategory"` 로 변경 후 `firebase deploy --only firestore:indexes` 재배포 |

### FAIL-2. AdminMorePage 타일 타이틀 카피 불일치 [우선순위: HIGH]

| 항목 | 내용 |
|---|---|
| 파일 | `lib/presentation/admin/more/admin_more_page.dart` line 30 |
| 현재 코드 | `title: '메뉴 카테고리 관리'` |
| design.md 확정 카피 | `'메인 카테고리 관리'` |
| 영향 | spec 결정 3 + design.md 카피 확정값(`개발자 전달 특이사항 > 카피 확정값 테이블`)과 불일치. AdminMainCategoryListPage AppBar 타이틀(`'메인 카테고리 관리'`)과도 불일치하여 사용자 혼란 가능. |
| 수정 방법 | `admin_more_page.dart` line 30의 `'메뉴 카테고리 관리'` → `'메인 카테고리 관리'` 변경 |

---

## PASS 항목

### 결정 1: MainCategoryCode enum 완전 제거

| ID | 항목 | 결과 |
|---|---|---|
| P-1-1 | `lib/domain/entities/main_category_code.dart` 파일 삭제됨 | PASS |
| P-1-2 | `MenuItemEntity.mainCategoryCode` 타입이 `String` 으로 변경됨 | PASS |
| P-1-3 | `SubCategoryEntity.mainCategoryCode` 타입이 `String` 으로 변경됨 | PASS |
| P-1-4 | `MenuItemModel.toEntity()` / `fromEntity()` 에서 enum 호출 없음, 직접 String 사용 | PASS |
| P-1-5 | 코드 전체에 `MainCategoryCode` 잔재 없음 (grep 결과 0건) | PASS |
| P-1-6 | `.asString` / `.label` 잔재 없음 (grep 결과 0건) | PASS |
| P-1-7 | `WatchSubCategoriesUseCase` / `MenuCategoryRepository.watchSubCategories` 시그니처가 `String mainCategoryId` 로 변경됨 | PASS |
| P-1-8 | `subCategoriesProvider` family parameter 가 `String` 으로 변경됨 | PASS |
| P-1-9 | `selectedMainCategoryProvider` 가 `Notifier<String?>` 로 변경, 초기값 null | PASS |
| P-1-10 | `storeAvailableMainCategoriesProvider` 반환 타입이 `Set<String>` 으로 변경됨 | PASS |

### 결정 2: seedDefaultsIfEmpty admin 첫 진입 자동 시드

| ID | 항목 | 결과 |
|---|---|---|
| P-2-1 | `MainCategoryRemoteDataSource.seedDefaultsIfEmpty()` 구현됨 (컬렉션 비었을 때만 batch 시드, idempotent) | PASS |
| P-2-2 | 시드 값 3개: coffee/커피/0, nonCoffee/논커피/1, dessert/디저트/2 — spec 명세와 일치 | PASS |
| P-2-3 | `AdminMainCategoryListPage.initState` 에서 `addPostFrameCallback` 으로 `seedDefaultsIfEmpty` 호출 | PASS |

### 결정 3: AdminMorePage 진입 ListTile 존재

| ID | 항목 | 결과 |
|---|---|---|
| P-3-1 | `AdminMorePage` 에 메인 카테고리 관리 `_Tile` 추가됨 (icon: `Icons.category_outlined`, onTap: push → `AdminMainCategoryListPage`) | PASS |
| P-3-2 | 타일 위치: "로그아웃" 타일 위 (design.md 명세 대로) | PASS |

### 결정 4: hard delete 차단 + active 토글

| ID | 항목 | 결과 |
|---|---|---|
| P-4-1 | `MainCategoryRepositoryImpl.delete()` 가 `countUsage > 0` 이면 `MainCategoryInUseException` throw | PASS |
| P-4-2 | `MainCategoryInUseException` 신규 정의됨 (`categoryId`, `usageCount` 포함) | PASS |
| P-4-3 | `MainCategoryDeleteDialog` 에서 usageCount >= 1 이면 삭제 차단 + "비활성화로 전환" 버튼 표시 | PASS |
| P-4-4 | "비활성화로 전환" 탭 시 DeactivateConfirmDialog 를 건너뛰고 직접 `ToggleMainCategoryActiveUseCase(id, false)` 호출 (design 결정 준수) | PASS |
| P-4-5 | `MainCategoryDeactivateConfirmDialog` 영향 데이터(N/M) 표시 — `mainCategoryDetailedUsageProvider` watch, storeCount/menuCount 표시 | PASS |
| P-4-6 | inactive 칩에 `IgnorePointer` 처리 — 폼 3종(MasterMenu/OwnerStoreMenu/BrandStoreOnlyMenu) 모두 확인 | PASS |
| P-4-7 | customer `filteredMenuItemsProvider` 가 active 카테고리 set 으로 inactive 카테고리 메뉴 필터링 (4b 결정 준수) | PASS |

### 결정 4a: collectionGroup 인덱스

| ID | 항목 | 결과 |
|---|---|---|
| P-4a-1 | `firestore.indexes.json` 신규 생성됨, collectionGroup `menuItems` 에 대한 인덱스 엔트리 존재 | PASS (파일 존재) |
| P-4a-2 | fieldPath 값 정확성 | FAIL-1 (별도 기재) |

### admin UI 4종 (A2/A3/A4/B)

| ID | 항목 | 결과 |
|---|---|---|
| P-A2-1 | `AdminMainCategoryListPage` 신규 파일 존재, displayOrder 정렬 stream 사용 | PASS |
| P-A2-2 | loading shimmer 4개 skeleton 구현 | PASS |
| P-A2-3 | error / empty 상태 UI 구현 (카피 design.md 일치) | PASS |
| P-A3-1 | `AdminMainCategoryFormPage` 신규 파일 존재, 등록/수정 통합 | PASS |
| P-A4-1 | `MainCategoryDeleteDialog` 신규 파일 존재 | PASS |
| P-B-1 | `MainCategoryDeactivateConfirmDialog` 신규 파일 존재, 4d Lite 영향 데이터(N/M) 표시 | PASS |
| P-B-2 | 비활성화 버튼이 loading 중 disabled 처리됨 | PASS |

### 카피 확인

| ID | 위치 | 확정 카피 | 실제 코드 | 결과 |
|---|---|---|---|---|
| P-C-1 | InactiveCategoryWarningBanner | `'이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요.'` | 동일 (단, 마침표 포함 — design.md 와 동일) | PASS |
| P-C-2 | MainCategoryDeactivateConfirmDialog 영향 라벨 | `'비활성화하면 영향을 받아요'` | 동일 | PASS |
| P-C-3 | MainCategoryDeleteDialog 차단 본문 | `'이 카테고리에 연결된 메뉴가 {N}개 있어요.\n삭제하려면...'` | 동일 | PASS |
| P-C-4 | AdminMorePage 타일 타이틀 | `'메인 카테고리 관리'` | `'메뉴 카테고리 관리'` | FAIL-2 (별도 기재) |

### 아키텍처 / 코드 품질

| ID | 항목 | 결과 |
|---|---|---|
| P-AR-1 | presentation 레이어에서 Firebase 직접 import 없음 (신규 파일 기준) | PASS |
| P-AR-2 | `AppColors` 토큰만 사용 — 신규 파일들에 `Color(0x...)` 하드코딩 없음 | PASS |
| P-AR-3 | `flutter analyze` 0 issues | PASS |
| P-AR-4 | `InactiveCategoryWarningBanner` 공통 위젯으로 추출 (`lib/presentation/common/widgets/`) — 3개 폼 재사용 | PASS |
| P-AR-5 | `MainCategoryRemoteDataSource` — Firebase import 는 data 레이어에만 존재 | PASS |

### 회귀 검증

| ID | 항목 | 결과 |
|---|---|---|
| P-R-1 | sub-phase 1 `_hasCoreFieldChange` 코드 변경 없음 (line 114 그대로 유지) | PASS |
| P-R-2 | `menuItemAllOptionGroupsProvider` (sub-phase 5 patch) 파일 미변경 (`menu_detail_providers.dart` 에 그대로 존재) | PASS |
| P-R-3 | `MenuCategories.all` (12개 string, 매장 분류 태그) 변경 없음 — `menu_categories.dart` 및 사용처 무수정 | PASS |
| P-R-4 | `mainCategoriesAllProvider` — 3개 폼 모두 watch 중. 수정 모드에서 inactive 카테고리 포함 노출, 신규 모드에서 active only 필터 적용 | PASS |

---

## audit 결과 (결정 4c)

정적 분석으로 확인 가능한 부분:

- `MenuItemModel.fromFirestore` 에서 `mainCategory` 필드 누락 시 default fallback 값: `'coffee'` (line 88)
  - 기존 hotfix 에서 `MainCategoryCode.fromString` default → `coffee` 였던 것과 동일 패턴이 유지됨
  - 이전 hotfix 에서 silent fallback 으로 잘못 박힌 doc (`'etc'`, `'ade'` 등 이상값) 은 정적으로 발견 불가
- 실제 Firestore 데이터의 `mainCategory` 필드 분포 audit (`'coffee'`/`'nonCoffee'`/`'dessert'` 외 값 존재 여부)은 **실기기 필요 항목**으로 분리 (아래 보류 섹션)

---

## 보류 — 사용자 실기기 검증 필요 항목

| # | 시나리오 | 근거 |
|---|---|---|
| H-1 | admin 더보기 → "메인 카테고리 관리" 첫 진입 → 기본 3개 (커피/논커피/디저트) 자동 시드 노출 | seedDefaultsIfEmpty 의 idempotent 동작은 실 Firestore 연결 필요 |
| H-2 | admin Switch true→false → DeactivateConfirmDialog 영향 데이터 N/M 정확성 (collectionGroup 쿼리 실측) | aggregate count 정확도 |
| H-3 | 삭제 차단 쿼리 (collectionGroup 인덱스 배포 후 동작) | FAIL-1 수정 + 인덱스 재배포 후 재검증 필요 |
| H-4 | 수정 모드에서 inactive 카테고리에 묶인 메뉴 진입 시 `InactiveCategoryWarningBanner` 실제 노출 | 실 DB inactive 카테고리 doc 필요 |
| H-5 | 수정 모드 inactive 칩 IgnorePointer — 탭 불가 / active 칩 정상 선택 가능 | 디바이스 터치 인터랙션 |
| H-6 | active=false 카테고리 → customer `MainCategoryTabs` 에서 자동 제외 확인 | 실 DB + 실 디바이스 |
| H-7 | 비활성 후 admin이 다시 active=true 로 토글 → 경고 라벨/marker 즉시 사라짐 | stream 반응 실측 |
| H-8 | 사용 0개 카테고리 hard delete 정상 동작 | 실 Firestore |
| H-9 | 동시 첫 진입 race — 중복 doc 미발생 (idempotent 검증) | 멀티 디바이스 동시 접속 |
| H-10 | sub-phase 1 마스터 메뉴 등록/수정/복제 — 카테고리 칩 정상 (동적 fetch 동작) | 실 DB + 화면 회귀 |
| H-11 | sub-phase 3/4 폼 — 신규 등록 시 active 카테고리만 노출, 저장 정상 | 실 DB + 화면 회귀 |
| H-12 | **[4c audit] 기존 menuItem 의 `mainCategory` 필드 분포**: `'coffee'`/`'nonCoffee'`/`'dessert'` 외 값 존재 여부. 이상값 발견 시 architect 재합의. | Firestore 콘솔 또는 admin 진단 쿼리 |
| H-13 | customer `MainCategoryTabs` 가로 스크롤 동작 (카테고리 4개 이상 추가 후 확인) | 실 디바이스 UX |

---

## 미세 결함 — FAIL 수준 아님 (개선 권고)

| # | 항목 | 내용 |
|---|---|---|
| M-1 | inactive 카테고리 칩 텍스트 | design.md 에서 `'{label} (비활성)'` + `Icons.warning_amber_rounded` 아이콘을 요구했으나, 실제 구현은 label만 표시하고 warning 배경/테두리 색상으로 시각 구분. 기능적 동작(IgnorePointer, warning 배경색)은 정상이며 info 수준 차이. 사용자가 확인 후 수정 또는 허용 결정 가능. |
| M-2 | AdminMorePage 타일 아이콘 | design.md 확정: `Icons.category_rounded`. 실제: `Icons.category_outlined`. 시각적 차이. FAIL-2 수정 시 함께 검토 권장. |

---

## 우선 수정 순서

1. **FAIL-1** (`firestore.indexes.json` 필드명 `mainCategoryCode` → `mainCategory`) — 인덱스 배포 없이는 삭제 차단 쿼리가 실 운영에서 오작동 가능
2. **FAIL-2** (AdminMorePage 타일 타이틀 `'메뉴 카테고리 관리'` → `'메인 카테고리 관리'`) — 단순 문자열 1줄 수정

---

## 후속 작업 후보

| 항목 | 분류 |
|---|---|
| 4d Heavy: FCM/이메일 외부 알림 인프라 | Follow-up F1 (spec 비범위) |
| 메인 카테고리 시각 토큰 (이미지/배너/색상) | Follow-up F2 (spec 비범위) |
| i18n label 다국어화 | Follow-up F3 (spec 비범위) |
| `MenuCategories.all` (매장 분류 태그 12개) 동적화 | Follow-up F4 (spec 비범위, 별도 도메인) |
| inactive 칩 텍스트 `'{label} (비활성)'` + 아이콘 정확도 보강 (M-1) | 차기 polish 작업 후보 |
