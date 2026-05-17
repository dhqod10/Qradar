# sub-phase 5 master ref 옵션 시트 fix patch — 테스트 리포트

## 테스트 일시

- 2026-05-03

---

## 테스트 방법

- 정적 코드 검증 (코드 직접 읽기)
- 문서 교차 검증 (spec.md / implementation.md 대조)
- `flutter analyze` (변경 파일 + 전체 프로젝트)
- 실기기 검증: 불가 (정적 검증만 수행)

---

## 전체 결과

- PASS: 18개
- FAIL: 0개
- 보류: 5개

---

## PASS 항목

### 기능 검증

- [x] `optionGroupsForMenuItemEntityProvider` 타입 일치 확인
  - 근거: `FutureProvider.autoDispose.family<List<OptionGroupEntity>, MenuItemEntity>` — spec 결정 Y1, 결정 X 와 정확히 일치.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart:25`

- [x] 시트가 신규 provider 를 watch
  - 근거: `ref.watch(optionGroupsForMenuItemEntityProvider(widget.menuItem))` — spec 변경 2 와 일치.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart:188`

- [x] 에러 retry 콜백이 신규 provider 를 invalidate
  - 근거: `ref.invalidate(optionGroupsForMenuItemEntityProvider(widget.menuItem))` — spec 변경 3 과 일치.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart:213`

- [x] 기존 `menuItemAllOptionGroupsProvider` / `MenuItemKey` 의존 완전 제거
  - 근거: `menu_option_disable_sheet.dart` 내 `menu_detail_providers` 관련 import 문 전혀 없음. grep 으로 0 건 확인.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart` (import 섹션 전체)

- [x] `optionGroupRefs.isEmpty` short-circuit 적용
  - 근거: provider 내부 `if (menuItem.optionGroupRefs.isEmpty) return const [];` — spec 변경 4, 요구사항과 일치.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart:27`

- [x] disabled 필터 미적용 (전체 옵션 표시)
  - 근거: `getOptionGroupsForMenuItem(menuItem, disabledGroupIds: const {}, disabledItemIds: const {})` — spec 명시적 결정과 일치. `OptionRepositoryImpl` 내부 로직상 빈 set 전달 시 필터 적용 없이 전체 반환.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart:28-33`

- [x] `GetOptionGroupsForMenuItemUseCase` 미사용 (UseCase 우회)
  - 근거: 시트 및 신규 provider 어디에도 `GetOptionGroupsForMenuItemUseCase` import 없음. `OptionRepository` 직접 호출 확인.
  - 위치: `menu_option_disable_sheet_providers.dart` 전체

- [x] 토글 핸들러 (`_onGroupToggle` / `_onItemToggle` / `_callSaveUseCase`) 변경 없음
  - 근거: spec "수정하지 않는 항목" 에 명시. 코드 확인 결과 토글 로직 원형 유지. optimistic update 패턴 동일.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet.dart:74-182`

- [x] customer 측 `menuItemAllOptionGroupsProvider` / `menuItemDetailProvider` 자체 미수정
  - 근거: `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart` 내 기존 provider 구조 그대로 보존 확인.
  - 위치: `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart`

- [x] `MenuItemRepository.watchById` / `MenuItemRemoteDataSource.streamById` 미수정
  - 근거: `menu_item_remote_data_source.dart`, `menu_item_repository_impl.dart` 의 `streamById` / `watchById` 는 spec 비범위 그대로. 확인 완료.
  - 위치: `lib/data/datasources/remote/menu_item_remote_data_source.dart:29` / `lib/data/repositories/menu_item_repository_impl.dart:130`

### 아키텍처 검증

- [x] presentation 레이어에서 Firebase 직접 import 없음
  - 근거: `menu_option_disable_sheet_providers.dart` 및 `menu_option_disable_sheet.dart` 에 `cloud_firestore` / `firebase_*` import 전혀 없음. `OptionRemoteDataSource` (data) → `OptionRepositoryImpl` (data) → `OptionRepository` (domain) 경유.
  - 위치: `lib/presentation/common/option_disable_sheet/` 전체

- [x] Repository / DataSource 의존이 provider 트리에 정상 결합
  - 근거: `_sheetOptionRemoteDataSourceProvider` → `_sheetOptionRepositoryProvider` → `optionGroupsForMenuItemEntityProvider` 의존 체인 정상. `Provider<OptionRepository>` 타입 명시로 DI 패턴 일관성 유지.
  - 위치: `menu_option_disable_sheet_providers.dart:13-18`

- [x] 신규 provider 파일 위치 정합성
  - 근거: spec 결정 X — `presentation/common/option_disable_sheet/` 에 신규 파일 생성. customer 트리에 추가하지 않음. 확인 완료.
  - 위치: `lib/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart`

- [x] 호출처 시그니처 변경 없음
  - 근거: `OwnerBrandStoreMenusPage` / `OwnerStoreMenuListPage` / `OwnerStoreMenuDetailPage` 세 호출처 모두 `MenuOptionDisableSheet(storeId, menuItem, menuType, [existingOverride])` 시그니처 그대로. grep 확인.
  - 위치: 각 caller 파일

### 코드 품질 검증

- [x] 파일명 snake_case 준수
  - 근거: `menu_option_disable_sheet_providers.dart` — 규칙 준수.

- [x] Provider 네이밍 규칙 (`xxxProvider`) 준수
  - 근거: `optionGroupsForMenuItemEntityProvider`, `_sheetOptionRemoteDataSourceProvider`, `_sheetOptionRepositoryProvider` 모두 준수.

- [x] `autoDispose` 적용 — 캐시 누수 방지
  - 근거: `FutureProvider.autoDispose.family` 적용. 시트 닫히면 자동 정리. spec 결정 Y 권장 사항 충족.
  - 위치: `menu_option_disable_sheet_providers.dart:25`

### 정적 분석

- [x] `flutter analyze` 0 issue
  - 근거: 변경 파일 (2개) 및 전체 프로젝트 모두 "No issues found!" — implementation.md 기록과 재확인 일치.

---

## FAIL 항목

없음.

---

## 보류 항목

- [ ] 마스터 ref 메뉴 옵션 시트 정상 표시 (핵심 시나리오 1)
  - 이유: 정적 검증으로 provider 교체는 확인됐으나, 실제 Firestore 의 `brands/{brandId}/menuItems/{id}.optionGroupRefs` 에 데이터가 있어야 end-to-end 확인 가능. 실기기 필요.
  - 필요한 확인: 마스터 메뉴 1건 + 옵션 그룹 1건 묶임 + admin 승인 완료 상태에서 브랜드 매장 점주 로그인 → 옵션 관리 시트 진입 → 옵션 그룹 정상 표시 여부.

- [ ] 점포 한정 메뉴 옵션 시트 회귀 (시나리오 2 / 3)
  - 이유: 코드 경로는 동일 (`optionGroupsForMenuItemEntityProvider(widget.menuItem)`) 이고 `optionGroupRefs` 가 store scope 면 store 컬렉션 fetch 로 가는 흐름이 `OptionRepositoryImpl` 에 구현되어 있음을 확인. 단, 브랜드 매장 store scope 메뉴 + 개인 매장 양쪽 실기기 확인 권장.
  - 필요한 확인: 점포 한정 메뉴 카드 tune 아이콘 → 시트 정상 표시 + 토글 → Repository 저장 확인.

- [ ] customer 메뉴 상세 회귀 (시나리오 4)
  - 이유: `menu_detail_providers.dart` 자체는 변경 없음 확인. 하지만 실 고객 흐름에서 `menuItemDetailProvider` / `menuItemOptionGroupsProvider` / 가격 합계 / "담기" 버튼 활성 상태 회귀는 실기기 확인 필요.
  - 필요한 확인: customer 계정으로 매장 메뉴 상세 진입, 옵션 선택, 가격 합계, 담기 버튼 정상 동작.

- [ ] fetch 에러 재시도 (네트워크 차단 시나리오)
  - 이유: 에러 retry 콜백이 올바른 provider 를 invalidate 하는 코드는 정적으로 확인. 실제 네트워크 차단 후 에러 UI 표시 → 재시도 버튼 → 정상 fetch 복구는 실기기 확인 필요.
  - 필요한 확인: 디바이스 네트워크 차단 → 시트 진입 → "옵션을 불러오지 못했어요" + 재시도 버튼 → 네트워크 복구 → 재시도 시 정상 표시.

- [ ] `existingOverride` 미전달 패턴 — brandMasterRef 저장 시 override 신규 생성 동작
  - 이유: 호출처(`OwnerBrandStoreMenusPage`)에서 `existingOverride` 를 전달하지 않는 것은 이전 sub-phase 5 구현 그대로이며 본 patch 비범위. `_callSaveUseCase` 의 fallback (`widget.existingOverride ?? MenuOverrideEntity(...)`) 으로 신규 override 가 생성됨을 코드에서 확인. 단, case B 머지 결과 entity 에 이미 override 값이 반영되어 있으므로 첫 진입 시 disabledOptionGroupIds / disabledOptionItemIds 초기값 정합성은 실기기로 검증 필요.
  - 후속 작업 제안: sub-phase 5 test_report 에 등록되어 있는 항목일 가능성 높음. 별도 이슈 트래킹 권장.

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **PASS (정적 검증 완료 — 실기기 5개 항목 보류)**
- FAIL 0건. spec 결정사항 (결정 X, Y, 변경 1~3) 모두 코드에 정확히 반영됨.
- `flutter analyze` 전체 프로젝트 0 issue 확인.
- Clean Architecture 레이어 경계 준수. Firebase 직접 import 없음.
- AppColors 토큰만 사용. 하드코딩 색상 없음.
- customer 측 provider chain 및 `streamById` / `watchById` 미수정 확인.

### 재작업 우선순위

재작업 필요 없음 (FAIL 항목 없음).

### 후속 task 후보

1. **실기기 시나리오 1 (마스터 ref 옵션 시트 핵심 검증)**
   - 이유: 본 patch 의 핵심 버그 수정 목적 검증. 코드 경로는 확인됐으나 실 데이터 기반 end-to-end 확인이 완료 기준 충족에 필요.

2. **customer 측 `menuItemAllOptionGroupsProvider` 동등 패치 검토**
   - 이유: spec 비범위로 명시됐으나, customer 측에서도 master ref 메뉴 상세 진입 시 동일 이슈(`streamById` → store 경로만 조회 → null detail`) 가 있을 가능성. implementation.md 에도 명시됨. 별도 phase 로 분리 권장.

3. **`existingOverride` 호출처 전달 개선**
   - 이유: `OwnerBrandStoreMenusPage` 에서 `MenuOptionDisableSheet` 호출 시 `existingOverride` 를 항상 null 로 전달 중. 최초 토글 시 fallback override 신규 생성이 되나, 이미 저장된 override 값을 UI 진입 시점 즉시 반영하려면 override stream 을 watch 해서 전달하는 편이 정합성 상 더 안전. 단, case B 머지 결과 entity 에 이미 override 값이 포함되어 있어 현재도 논리상 동작하므로 낮은 우선순위.

4. **`streamById` / `MenuItemRepository.watchById` 분기 — brand master 도 조회**
   - 이유: spec 비범위 명시. customer 메뉴 상세 등 영향 범위가 큰 별도 phase 작업.

---

## 완료 판단

- [x] FAIL 없음 — 정적 검증 기준 전 항목 PASS
- [ ] 실기기 시나리오 검증 보류 (사용자 직접 확인 필요)
- [ ] 재작업 불필요
