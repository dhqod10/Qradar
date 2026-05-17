# sub-phase 8 — menu_sub_category_management 테스트 리포트

> **상태**: 정적 검증 완료  
> **날짜**: 2026-05-03  
> **검증 방식**: 정적 코드 검증 (flutter analyze + 소스 직독)

---

## 전체 결과 요약

| 구분 | 개수 |
|---|---|
| PASS | 38 |
| FAIL | 5 |
| 보류 (사용자 실기기 검증 필요) | 12 |

---

## FAIL 항목

### FAIL-1. SubCategoryScope 가 entity 에서 nullable 로 정의됨 (spec 위반)

- **위치**: `lib/domain/entities/sub_category_entity.dart` line 26 — `SubCategoryScope? scope`
- **spec 요구**: `required SubCategoryScope scope` (non-nullable). spec.md 의 Entity 정의 코드블록에서 `required SubCategoryScope scope` 로 명시. "scope 는 default 값을 두지 않는다 (master 가 사라졌으므로 fallback 필요 없음)"
- **현상**: `scope` 가 `SubCategoryScope?` (nullable). legacy global sub 와의 구분용으로 null 허용 처리됨. `upsert` 내부에서 `entity.scope!` 로 force-unwrap 사용 → 런타임 NPE 위험.
- **영향**: `SubCategoryRepositoryImpl.upsert()`, `toggleActive()`, `delete()` 등 UseCase 호출 경로에서 `entity.scope!` force-unwrap 다수 존재. scope==null 인 legacy entity 가 CRUD 경로로 유입되면 NPE 발생.
- **권고**: `scope` 를 `required SubCategoryScope scope` 로 변경하고, legacy 변환 경로(`toEntity()`)에서 scope==null 인 doc 은 brand/store CRUD 경로로 들어오지 않도록 방어.

---

### FAIL-2. BrandMorePage 가맹점 점주 진입 가드 미구현

- **위치**: `lib/presentation/brand/more/brand_more_page.dart`
- **spec 요구**: brand 가맹점 점주(brandAffiliate)에게 "서브 카테고리 관리" tile 미노출. design.md — "현재 사용자가 brand 본사(역할: brandHq)일 때만 이 타일을 노출"
- **현상**: BrandMorePage 에 `currentUserRole` 또는 `currentUserProfileProvider` 기반 조건 분기 없음. 가맹점 점주도 동일 `BrandMorePage` 를 사용한다면 tile 이 항상 노출됨.
- **영향**: 가맹점 점주가 `BrandSubCategoryListPage` 에 접근 가능. UseCase 단 권한 가드도 확인 불가(보안 규칙은 별 task 로 분리).
- **권고**: `BrandMorePage` 에서 `currentUserProfileProvider` 로 role 을 읽어 `brandAffiliate` 이면 tile 빌드 생략.

---

### FAIL-3. DeleteDialog 차단 본문 카피 불일치

- **위치**: `lib/presentation/common/widgets/sub_category_delete_dialog.dart` line 189
- **design.md 확정 카피**: `'이 분류를 사용 중인 메뉴가 {N}개 있어요.\n메뉴를 다른 분류로 먼저 변경해주세요.'`
- **구현 카피**: `'이 분류는 사용 중이라 삭제할 수 없습니다. 비활성화로 전환하시겠어요?'`
- **차이**: design.md 확정 카피와 다름. N(사용 중 개수) 표시 없음. 의미도 다름 (구현은 비활성화 전환 의사를 묻는 문구, design 은 다른 분류로 먼저 변경하라는 안내).
- **권고**: design.md 확정 카피로 교체.

---

### FAIL-4. inactive 경고 라벨 카피 불일치

- **위치**: `lib/presentation/common/widgets/sub_category_chips_selector.dart` line 133
- **design.md 확정 카피**: `'이 분류는 비활성화되었습니다. 다른 분류로 변경해주세요.'`
- **구현 카피**: `'이 분류는 비활성화되었습니다. 다른 분류를 선택해주세요'`
- **차이**: "변경해주세요" → "선택해주세요", 마침표 누락.
- **권고**: design.md 확정 카피로 교체.

---

### FAIL-5. 디바운스 조회 중 저장 버튼 disable 미구현

- **위치**: `lib/presentation/brand/sub_categories/brand_sub_category_form_page.dart`, `lib/presentation/owner/sub_categories/owner_store_sub_category_form_page.dart`
- **design.md 요구**: "조회 중 상태에서는 저장 버튼 disabled". `_isDuplicateChecking` 플래그로 디바운스 타이머 실행 중 버튼 비활성화.
- **현상**: `_canSave` 조건에 `_isSaving` 만 포함. 디바운스 타이머가 실행 중인 동안 저장 버튼이 활성화되어 있음. race 방지는 UseCase 가 최종 차단하지만, UX 측면에서 조회 중 저장 버튼이 활성화되어 있어 사용자가 즉시 제출 시 DuplicateSubCategoryNameException 을 받게 됨.
- **권고**: `_isCheckingDuplicate` 플래그를 추가하여 `_canSave` 에 포함. 디바운스 타이머 시작 시 true, 완료 시 false.

---

## PASS 항목

### 아키텍처 / 레이어 규칙

| # | 항목 | 결과 |
|---|---|---|
| A1 | Clean Architecture 레이어 준수 — presentation 에서 Firebase 직접 import 없음 | PASS |
| A2 | AppColors 토큰만 사용 — 하드코딩 `Color(0x...)` 없음 | PASS |
| A3 | SubCategoryRepository (신규 CRUD) / MenuCategoryRepository (read 유지) 책임 분리 | PASS |
| A4 | domain 레이어에서 Firestore import 없음 | PASS |
| A5 | `flutter analyze` 0 issues | PASS |

### scope 2-tier 구조

| # | 항목 | 결과 |
|---|---|---|
| B1 | `SubCategoryScope` enum — brand / store 두 값만 (master 없음) | PASS |
| B2 | brand scope: `brands/{brandId}/subCategories/` 경로 사용 | PASS |
| B3 | store scope: `stores/{storeId}/subCategories/` 경로 사용 | PASS |
| B4 | 글로벌 `subCategories/` write 차단 — 신규 CRUD 경로에서 글로벌 컬렉션 쓰기 없음 | PASS |
| B5 | `SubCategoryRemoteDataSource.streamByMainCategory` — legacy 유지 (customer 호환) | PASS |

### 중복 이름 검증 (옵션 2 — 약한 검증)

| # | 항목 | 결과 |
|---|---|---|
| C1 | `findDuplicateName` UseCase + Repository + DataSource 흐름 구현 | PASS |
| C2 | `normalizedName = name.trim().toLowerCase()` 로 Firestore 에 저장 + 쿼리 | PASS |
| C3 | `excludeId` — 수정 모드 자기 자신 제외 | PASS |
| C4 | brand scope 내 중복 → `DuplicateSubCategoryNameException` throw | PASS |
| C5 | store scope 내 중복 → 동일 예외 | PASS |
| C6 | `UpsertSubCategoryUseCase` 에서 submit 시 race 방지 재호출 | PASS |
| C7 | 폼 디바운스 300ms lookup 구현 (brand/owner 양쪽) | PASS |
| C8 | 중복 시 inline errorText `'이미 같은 이름의 분류가 있어요'` | PASS |
| C9 | `DuplicateSubCategoryNameException` catch → inline error 표시 | PASS |

### 삭제 정책 / active 토글

| # | 항목 | 결과 |
|---|---|---|
| D1 | `delete()` 내부에서 `countUsage` 선행 → 0이면 hard delete, 1이상이면 `SubCategoryInUseException` | PASS |
| D2 | `SubCategoryDeleteDialog` — usageCount >= 1 케이스 차단 본문 + "비활성화로 전환" 버튼 표시 | PASS |
| D3 | DeleteDialog — usageCount == 0 케이스 단순 삭제 확인 | PASS |
| D4 | active Switch 즉시 토글 (`DeactivateConfirmDialog` 없음) | PASS |
| D5 | Switch 성공 시 SnackBar `'분류를 활성화했어요'` / `'분류를 비활성화했어요'` | PASS |
| D6 | Switch 실패 시 SnackBar + 원상복구 | PASS |

### 메뉴 폼 3종 sub-category 칩

| # | 항목 | 결과 |
|---|---|---|
| E1 | `MasterMenuFormPage` — `brandSubCategoriesAllProvider` (brand scope) sub 사용 | PASS |
| E2 | `BrandStoreOnlyMenuFormPage` — `brandSubCategoriesAllProvider` (brand scope) sub 사용 | PASS |
| E3 | `OwnerStoreMenuFormPage` — `storeSubCategoriesByIdProvider` (store scope) sub 사용 | PASS |
| E4 | 메인 카테고리 변경 시 `_selectedSubCategoryId = null` cascade reset (3종 모두) | PASS |
| E5 | `SubCategoryChipsSelector` 공통 위젯 props 주입 방식 (provider 직접 watch X) | PASS |
| E6 | inactive sub prefill 시 `InactiveSubCategoryWarningLabel` 노출 | PASS |
| E7 | sub 선택 사항 — `_canSubmit` 에서 sub 선택 여부 검사 안 함 | PASS |
| E8 | 저장 시 `subCategoryId: _selectedSubCategoryId` entity 에 반영 | PASS |

### list 화면 (brand/owner)

| # | 항목 | 결과 |
|---|---|---|
| F1 | `BrandSubCategoryListPage` — 필터 칩 바 (전체/각 메인) | PASS |
| F2 | 전체 선택 시 섹션 헤더 그룹핑, 특정 메인 선택 시 평면 리스트 | PASS |
| F3 | loading / error / empty 상태 UI 구현 | PASS |
| F4 | `OwnerStoreSubCategoryListPage` — 동일 구조 (storeId 컨텍스트) | PASS |
| F5 | MyStorePage `_SubCategoryManagementButton` — `store.brandId == null && approved` 가드 | PASS |

### 진입점 및 회귀

| # | 항목 | 결과 |
|---|---|---|
| G1 | `BrandMorePage` — "서브 카테고리 관리" tile 추가됨 | PASS |
| G2 | AdminMorePage — sub-category 관련 tile 없음 (회귀 보존) | PASS |
| G3 | `firestore.indexes.json` — menuItems collectionGroup subCategoryId ASC 인덱스 추가 | PASS |
| G4 | `FirestorePaths` — `subCategoriesSubcollection`, `brandSubCategoriesPath`, `storeSubCategoriesPath` 신규 추가 | PASS |
| G5 | `SubCategoryEntity.freezed.dart` build_runner 재생성 확인 | PASS |

---

## 카피 일치 검증

| 위치 | design.md 확정 카피 | 구현 카피 | 결과 |
|---|---|---|---|
| BrandMorePage tile | `'서브 카테고리 관리'` | `'서브 카테고리 관리'` | PASS |
| MyStorePage tile | `'분류 관리'` | `'메뉴 분류 관리'` | 보류 — 의미 동일, 단어 상이 |
| OwnerStoreSubCategoryListPage AppBar | `'분류 관리'` | `'메뉴 분류 관리'` | 보류 — 의미 동일 |
| 중복 이름 inline errorText | `'이미 같은 이름의 분류가 있어요'` | `'이미 같은 이름의 분류가 있어요'` | PASS |
| inactive 경고 라벨 | `'이 분류는 비활성화되었습니다. 다른 분류로 변경해주세요.'` | `'이 분류는 비활성화되었습니다. 다른 분류를 선택해주세요'` | FAIL-4 |
| DeleteDialog 차단 본문 | `'이 분류를 사용 중인 메뉴가 {N}개 있어요.\n메뉴를 다른 분류로 먼저 변경해주세요.'` | `'이 분류는 사용 중이라 삭제할 수 없습니다. 비활성화로 전환하시겠어요?'` | FAIL-3 |
| DeleteDialog 버튼 | `'비활성으로 전환'` | `'비활성화로 전환'` | 보류 — 표현 차이 사소함 |
| empty 제목 | `'등록된 분류가 없어요'` | `'등록된 분류가 없어요'` | PASS |
| 활성화 SnackBar | `'분류를 활성화했어요'` | `'분류를 활성화했어요'` | PASS |
| 비활성화 SnackBar | `'분류를 비활성화했어요'` | `'분류를 비활성화했어요'` | PASS |

---

## 사용자 실기기 검증 필요 항목

### 기능 동작

| # | 시나리오 | 검증 포인트 |
|---|---|---|
| R1 | brand 본사 sub 등록 | BrandMorePage → 서브 카테고리 관리 → FAB → 저장 후 목록 노출 확인 |
| R2 | 중복 이름 차단 (같은 brand) | 동일 이름 입력 → 디바운스 300ms 후 inline 에러 노출 → submit 시 최종 차단 |
| R3 | 대소문자/공백 normalize 차단 | " 콜드브루 " / "COLD브루" 입력 → 기존 "콜드브루" 와 동일 처리 차단 여부 |
| R4 | 다른 scope 간 동일 이름 허용 | brand sub 와 store sub 에 같은 이름 등록 → 허용 확인 |
| R5 | 메인 카테고리 변경 → sub cascade reset | 메인 선택 → sub 선택 → 메인 재선택 → sub 선택 해제 확인 |
| R6 | 수정 모드 inactive sub prefill | sub 를 비활성화 → 해당 sub 가 선택된 메뉴 수정 폼 진입 → warning label 노출 |
| R7 | 삭제 (사용 중) | 메뉴에 sub 연결 → 삭제 시도 → 차단 다이얼로그 노출 → "비활성화로 전환" 동작 |
| R8 | 삭제 (사용 없음) | 사용 0개 sub 삭제 → hard delete 확인 |
| R9 | owner 개인 매장 sub CRUD | MyStorePage → 메뉴 분류 관리 → 등록/수정/삭제 동작 |
| R10 | 가맹점 점주 MyStorePage | brandId 있는 매장 → 메뉴 분류 관리 버튼 미노출 확인 |
| R11 | 저장 후 subCategoryId 반영 | 메뉴 폼에서 sub 선택 → 저장 → Firestore menuItem 문서에 subCategoryId 값 확인 |

### 회귀

| # | 시나리오 | 검증 포인트 |
|---|---|---|
| R12 | sub-phase 9 회귀 | 메인 카테고리 목록/폼/삭제 정상 동작 — 충돌 없음 |
| R13 | customer 매장 메뉴 탭 sub 칩 | 가맹점 매장: brand sub 노출 / 개인 매장: store sub 노출 |

### audit

| # | 항목 |
|---|---|
| R14 | 기존 menuItem 의 `subCategoryId` 분포 확인 — 글로벌 sub id / brand sub id / store sub id / null 분류. 불명 id 발견 시 architect 보고. |
| R15 | Firebase Console — menuItems collectionGroup / subCategoryId 단일 필드 인덱스 직접 배포 필요 (implementation.md 수동 작업 항목 확인) |

---

## 보류 항목

| # | 항목 | 사유 |
|---|---|---|
| H1 | MyStorePage 버튼 라벨 `'메뉴 분류 관리'` vs design.md `'분류 관리'` | 의미는 동일. UX 팀/디자이너 최종 확인 후 통일. 기능 동작에는 영향 없음. |
| H2 | OwnerStoreSubCategoryListPage AppBar 타이틀 `'메뉴 분류 관리'` vs design.md `'분류 관리'` | H1 과 동일 이유. |
| H3 | DeleteDialog 버튼 `'비활성화로 전환'` vs design.md `'비활성으로 전환'` | 사소한 표현 차이. 사용자 인지에 영향 없음. 통일 시 수정. |
| H4 | brand 가맹점 점주 BrandMorePage 진입 시나리오 | FAIL-2 수정 전까지 실기기에서 검증 불가. 수정 후 R10 시나리오로 재검증. |
| H5 | AnimatedSwitcher 150ms cascade reset 시각 애니메이션 | 코드에 AnimatedSwitcher 미구현, 대신 setState 즉시 rebuild 처리. 기능 동작은 정상이나 design.md 의 fade 애니메이션 비범위 여부 확인 필요. |

---

## FAIL 우선순위

| 우선순위 | FAIL # | 항목 | 이유 |
|---|---|---|---|
| 1 | FAIL-1 | SubCategoryScope nullable → NPE 위험 | 런타임 크래시 가능. 핵심 도메인 필드 |
| 2 | FAIL-2 | BrandMorePage 가맹점 점주 가드 미구현 | 권한 정책 위반. 가맹점 점주가 brand sub CRUD 접근 가능 |
| 3 | FAIL-3 | DeleteDialog 차단 본문 카피 불일치 | UX 오해 유발. N(사용 수) 미표시 |
| 4 | FAIL-4 | inactive 경고 라벨 카피 불일치 | 확정 카피 불일치 |
| 5 | FAIL-5 | 디바운스 중 저장 버튼 disable 미구현 | UX 정책 미준수 (기능 자체는 UseCase 최종 차단으로 보호) |

---

## 후속 작업 후보

| # | 항목 |
|---|---|
| F-후1 | Firestore 보안 규칙 강화 — `brands/{brandId}/subCategories` write 를 brand 본사 uid 만 허용 (spec Follow-up F1) |
| F-후2 | 가맹점 점주 매장 한정 sub 추가 시나리오 검토 (spec Follow-up F2) |
| F-후3 | 오타/유사명 자동 감지 (spec Follow-up F7) |
| F-후4 | admin 운영 모니터링 도구 (spec Follow-up F8) |
| F-후5 | AnimatedSwitcher 150ms cascade reset 애니메이션 — 현재 즉시 rebuild 방식. 보류 H5 확인 후 추가 여부 결정 |
