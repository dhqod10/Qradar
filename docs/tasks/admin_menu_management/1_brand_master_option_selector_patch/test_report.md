# sub-phase 1 옵션 selector 보강 patch — 테스트 리포트

## 테스트 일시

- 2026-05-03

---

## 테스트 방법

- 정적 코드 검증 (코드 직접 읽기)
- 문서 교차 검증 (spec.md / design.md / implementation.md 대조)
- `flutter analyze` (변경 파일 단독 + 전체 프로젝트)
- 실기기 동작 검증: 미수행 (정적 검증 범위)

---

## 전체 결과

- PASS: 22개
- FAIL: 0개
- 보류: 8개 (실기기 수동 검증 필요)

---

## PASS 항목

### 기능 검증

- [x] `brandMasterOptionGroupsProvider` 추가 — owner 패턴(`fetchAllMaster → entity 매핑`) 동일 구현
  - 근거: `FutureProvider<List<OptionGroupEntity>>` 타입. `ds.fetchAllMaster()` 호출 후 `models.map((m) => m.toEntity()).toList(growable: false)` 변환. owner 측 `masterOptionGroupsProvider` 패턴과 구조 동일.
  - 위치: `lib/presentation/brand/providers/brand_master_menu_providers.dart` L84-89

- [x] `_brandOptionRemoteDataSourceProvider` private 배치 — 단일 사용처 원칙 충족
  - 근거: `final _brandOptionRemoteDataSourceProvider` (private) 로 선언. `brand_master_menu_providers.dart` 내 단일 사용처.
  - 위치: 동 파일 L77-78

- [x] `_selectedOptionGroupIds` 상태 필드 추가
  - 근거: `List<String> _selectedOptionGroupIds = [];` 선언. 주석으로 "S2 — 항상 master scope" 명시.
  - 위치: `lib/presentation/brand/master_menu/master_menu_form_page.dart` L56

- [x] `initState` prefill — 등록 모드 빈 배열 / 수정·복제 모드 source ID 추출
  - 근거: `source?.optionGroupRefs.map((r) => r.id).toList() ?? []`. `source = widget.editItem ?? widget.sourceForClone` 이므로 등록/수정/복제 3모드 모두 정확히 처리.
  - 위치: 동 파일 L101-103

- [x] submit 매핑 — `OptionGroupRef(scope: OptionScope.master, id: id)` 로 항상 master scope 강제 (S2)
  - 근거: `optionGroupRefs: _selectedOptionGroupIds.map((id) => OptionGroupRef(scope: OptionScope.master, id: id)).toList()`
  - 위치: 동 파일 L191-193

- [x] `OptionGroupSelector` 호출 시 `storeId` 미전달 (S2 UI 방어선)
  - 근거: `OptionGroupSelector(optionGroups: ..., selectedIds: ..., onChanged: ...)` — `storeId` 파라미터 전달 없음. `OptionGroupSelector.build()` 의 `if (storeId != null)` 분기가 트리거되지 않아 master only 리스트만 렌더링.
  - 위치: 동 파일 L422-429

- [x] `_canSubmit` 변경 없음 — 옵션 그룹 선택 조건 미추가
  - 근거: `_canSubmit` = 이미지 + 이름 + 가격 > 0 + 카테고리 선택 4조건만 유지. `_selectedOptionGroupIds` 조건 없음. `optionGroupRefs` 는 선택 필드.
  - 위치: 동 파일 L67-71

- [x] `_hasCoreFieldChange` 변경 없음 — 기존 optionGroupRefs ID 셋 비교 로직 그대로
  - 근거: L122-133 내용이 spec 확인 기준(L118-122 원본)과 동일. `length` 비교 + `_listEquals` ID 순서 비교 이중 구조.
  - 위치: 동 파일 L122-133

- [x] loading/error fallback — `asData?.value ?? []` 적용
  - 근거: `ref.watch(brandMasterOptionGroupsProvider).asData?.value ?? []`. AsyncLoading/AsyncError 모두 빈 배열 폴백으로 OptionGroupSelector 에 전달. 폼 전체는 즉시 조작 가능.
  - 위치: 동 파일 L423-426

- [x] 복제 모드 prefill
  - 근거: `source = widget.editItem ?? widget.sourceForClone` 이므로 `sourceForClone != null` 이면 복제 원본의 `optionGroupRefs` ID 를 그대로 prefill. 복제 모드 진입 조건과 일치.
  - 위치: 동 파일 L85, L101-103

---

### UI 검증

- [x] 섹션 헤더 라벨 "옵션 그룹" 적용
  - 근거: `_sectionLabel('옵션 그룹')` — design.md 확정 라벨 그대로.
  - 위치: 동 파일 L420

- [x] 배치 위치 — 카테고리 ↔ 태그 사이 (design.md 안 A 확정)
  - 근거: L388 `_sectionLabel('카테고리 *')` → L419 `_divider()` → L420 `_sectionLabel('옵션 그룹')` → L422 `OptionGroupSelector` → L430 `_divider()` → L431 `_sectionLabel('태그')` 순서.
  - 위치: 동 파일 L419-431

- [x] `_divider()` 스펙 일치 — height:32, color:AppColors.border, thickness:1
  - 근거: `const Divider(height: 32, color: AppColors.border, thickness: 1)` — design.md 명세와 정확히 일치.
  - 위치: 동 파일 L474

- [x] `_sectionLabel()` 스펙 일치 — fontSize:13, fontWeight:w600, color:AppColors.textMuted
  - 근거: `TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)` — design.md 명세와 일치.
  - 위치: 동 파일 L468-472

- [x] `SizedBox(height: 8)` 헤더 ↔ 위젯 간격
  - 근거: `_sectionLabel('옵션 그룹')` → `const SizedBox(height: 8)` → `OptionGroupSelector(...)` 순서.
  - 위치: 동 파일 L420-422

- [x] OptionGroupSelector 내부 AppColors 토큰만 사용 — 하드코딩 색상 없음
  - 근거: `Color(0x...)` 및 `Colors.*` 패턴 없음. `AppColors.surfaceElevated / border / textBody / textMuted / primary / onPrimary` 모두 토큰 사용.
  - 위치: `lib/presentation/brand/master_menu/widgets/option_group_selector.dart` 전체

- [x] `_canSubmit` 필수 표시(`*`) 미부여 — 옵션 그룹은 선택 필드
  - 근거: `_sectionLabel('옵션 그룹')` — `*` 없음. design.md "필수 표시(`*`): 없음" 확정 사항과 일치.
  - 위치: 동 파일 L420

---

### 아키텍처 검증

- [x] `presentation` 레이어에서 Firebase 직접 import 없음
  - 근거: `brand_master_menu_providers.dart` 및 `master_menu_form_page.dart` 에서 `cloud_firestore` / `firebase_*` import 없음. `OptionRemoteDataSource` 를 통해 data 레이어에서만 Firestore 접근.
  - 위치: 두 파일 import 섹션 전체

- [x] domain 레이어 침범 없음 — `OptionGroupEntity` / `OptionGroupRef` / `OptionScope` presentation → domain 단방향
  - 근거: `domain/entities/option_group_entity.dart` 및 `domain/entities/option_scope.dart` import. domain 이 presentation 을 역참조하지 않음.
  - 위치: `master_menu_form_page.dart` L9-10

- [x] freezed/build_runner 변경 불필요 — 새 `.freezed.dart` 파일 미생성
  - 근거: 도메인 모델 변경 없음. `find` 결과 신규 `.freezed.dart` 파일 없음. 기존 `option_group_entity.freezed.dart` 그대로 재사용.
  - 위치: domain/entities 디렉토리

---

### 코드 품질 검증

- [x] Provider 명명 — `brandMasterOptionGroupsProvider` (xxxProvider 패턴, brand prefix 충돌 회피)
  - 근거: spec.md 명명 결정 "brandMasterOptionGroupsProvider" 확정. `xxxProvider` suffix 형식 준수.
  - 위치: `brand_master_menu_providers.dart` L84

- [x] `flutter analyze` 0 issue — 변경 파일 및 전체 프로젝트
  - 근거: 변경 파일 단독 `No issues found! (ran in 1.9s)`. 전체 프로젝트 `No issues found! (ran in 4.2s)`.
  - 실행 결과: 직접 확인

- [x] 미사용 import 없음
  - 근거: `option_group_entity.dart` (`OptionGroupRef` 사용), `option_scope.dart` (`OptionScope` 사용), `option_group_selector.dart` (`OptionGroupSelector` 사용) — 세 import 모두 실제 사용처 존재. flutter analyze 도 0 issue.
  - 위치: `master_menu_form_page.dart` L9-11

---

## FAIL 항목

없음.

---

## 보류 항목

이하 8개 항목은 실기기 수동 검증으로만 확인 가능하다. 정적 검증으로는 PASS/FAIL 판단 불가.

- [ ] **신규 등록 + 옵션 그룹 선택 → Firestore 저장**
  - 이유: `og_master_shot / og_master_syrup / og_master_temperature` 선택 후 제출 시 Firestore `brands/{brandId}/menuItems/{newId}.optionGroupRefs` 에 `[{scope:'master', id}]` 형식으로 저장되는지 실제 DB 확인 필요.
  - 필요한 확인: 실기기 + Firebase Console

- [ ] **수정 모드 prefill — 옵션 그룹 체크 상태 표시**
  - 이유: 옵션 그룹이 묶인 메뉴를 수정 모드로 열었을 때 `_selectedOptionGroupIds` prefill 이 `OptionGroupSelector` 내 `CheckboxListTile` 선택 상태로 렌더링되는지 UI 확인 필요.
  - 필요한 확인: 실기기

- [ ] **수정 모드 — 옵션 그룹 변경 → status=pending 회귀 (결정 J)**
  - 이유: 옵션 그룹 추가/제거 후 저장 시 `updateMasterMenuItemCore` 호출 여부, Firestore `status` 가 `pending` 으로 변경되고 `approvedBy/At` 이 보존되는지 실기기 확인 필요.
  - 필요한 확인: 실기기 + Firebase Console + SnackBar "수정 사항이 검토 대기 중입니다"

- [ ] **수정 모드 — 옵션 그룹 무변경 + 운영 필드만 변경 → status 보존**
  - 이유: 옵션 그룹 그대로 + visible 토글 시 `updateMasterMenuItemOperation` 호출 여부, Firestore `status` 보존 여부 실기기 확인 필요.
  - 필요한 확인: 실기기 + Firebase Console + SnackBar "즉시 반영되었습니다"

- [ ] **혼합 변경 — 옵션 그룹 추가 + 운영 필드 동시 변경 → 핵심 필드 우선**
  - 이유: `_hasCoreFieldChange true` → `updateMasterMenuItemCore` 우선 분기가 실제 동작하는지 실기기 확인 필요.
  - 필요한 확인: 실기기 + SnackBar + Firestore status

- [ ] **복제 모드 prefill + 저장 → 신규 메뉴 생성**
  - 이유: 복제 모드 진입 시 원본 옵션 그룹 prefill + 수정 후 저장 시 신규 `menuItemId` 로 Firestore 에 생성되는지 확인 필요.
  - 필요한 확인: 실기기 + Firebase Console

- [ ] **S2 가드 (UI) — store scope 옵션 그룹 미노출**
  - 이유: `storeId` 미전달로 `_buildWithSections()` 분기가 트리거되지 않는 것은 코드로 확인했으나, 실제 Firestore 에 store scope 옵션 그룹이 있는 환경에서 OptionGroupSelector 목록에 나타나지 않는지 실기기 확인 권장.
  - 필요한 확인: 실기기 (store scope 시드 데이터 있을 때)

- [ ] **점주 매장 자동 동기화 + sub-phase 5 진입 조건 smoke test**
  - 이유: brand 가 옵션 그룹 묶은 마스터 메뉴 등록 → admin 승인 → 점주 매장 메뉴 자동 동기화 → customer 측 옵션 선택 UI 동작 여부는 여러 레이어에 걸친 실기기 E2E 검증 필요.
  - 필요한 확인: 실기기 E2E (admin 승인 + owner 화면 + customer 화면)
  - 후속 작업 제안: sub-phase 5 진입 전 smoke test 로 확인

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **정적 검증 범위 내 전 항목 PASS. FAIL 0건.** 코드는 spec.md / design.md 의 모든 결정사항을 충족하고 있으며, flutter analyze 0 issue 가 확인됐다.

### 재작업 우선순위

재작업 대상 없음.

### 후속 task 후보

1. **실기기 수동 검증 8항목** (위 보류 항목)
   - 이유: 정적 검증으로 확인 불가한 Firestore 저장 내용, status 회귀, 점주/customer 연동은 실기기 확인 필요. 특히 "수정 모드 — 옵션 그룹 변경 → status=pending 회귀" 는 결정 J 핵심 검증이므로 우선 확인 권장.

2. **sub-phase 5 진입 smoke test**
   - 이유: 본 patch 가 sub-phase 5 진입 조건(옵션 묶인 마스터 메뉴 → 점주 동기화)을 충족하는지 E2E 검증이 필요하다. sub-phase 5 본격 작업 전에 smoke test 통과 여부 확인.

3. **sub-phase 7 — 옵션 그룹 CRUD UI (`admin_option_group_management`)**
   - 이유: 현재 `_brandOptionRemoteDataSourceProvider` 는 `brand_master_menu_providers.dart` 에 private 배치. sub-phase 7 진입 시 별도 `brand_option_providers.dart` 로 승격하거나 `brand_di_providers.dart` 에 통합하는 결정 필요.

---

## 완료 판단

- [x] 전체 PASS (정적 검증 범위)
- [ ] FAIL 있으나 후속 task로 분리 가능
- [ ] 재작업 필요
