# sub-phase 6 — upgrade_to_brand 테스트 리포트

## 테스트 일시

- 2026-04-30

---

## 테스트 방법

- 정적 코드 검증 (파일 직접 읽기)
- 문서 교차 검증 (spec.md V1~V10 / design.md D1~D7 / implementation.md)
- `flutter analyze` 실행 확인
- 삭제 대상 파일 존재 여부 확인
- Firebase import 레이어 경계 확인
- 하드코딩 색상 / `Color(0x...)` 검색

---

## 전체 결과

- PASS: 39개
- FAIL: 0개 (FAIL-1, FAIL-2 모두 2026-05-02 해소)
- 보류: 4개

> 회귀: `flutter analyze` 0 issue 재확인 완료.
> FAIL-1: `submitStoreForApproval` 의 `brandId: null` 강제 + `toFirestoreForCreate` 의 `'brandId': null` 하드코딩 제거 → 폼이 매칭한 brandId 가 정상 박힘.
> FAIL-2: `streamByBrand` 에 `status=='approved'` 필터 추가 (V6).

---

## PASS 항목

### 기능 검증 (Domain / Data)

- [x] BrandEntity.brandKey 필드 추가 (`@Default('')`)
  - 근거: spec V1 — `brandKey: String` default `''`
  - 위치: `lib/domain/entities/brand_entity.dart:17`

- [x] BrandEntity freezed 재생성 확인
  - 근거: `brand_entity.freezed.dart` 파일 존재. build_runner 실행 결과 일치
  - 위치: `lib/domain/entities/brand_entity.freezed.dart`

- [x] BrandRepository.findByBrandKey 추상 메서드 추가
  - 근거: spec V4 — `brands.where('brandKey','==',key).where('status','==','approved')`
  - 위치: `lib/domain/repositories/brand_repository.dart:44`

- [x] BrandRemoteDataSource.findByBrandKey 구현
  - 근거: `where('brandKey','==',key).where('status','==','approved').limit(1)` 쿼리 정확히 구현
  - 위치: `lib/data/datasources/remote/brand_remote_data_source.dart:90-98`

- [x] BrandRemoteDataSource.isBrandKeyTaken 구현
  - 근거: spec V1 unique 검증 — `where('brandKey','==',key).limit(1)` status 무관
  - 위치: `lib/data/datasources/remote/brand_remote_data_source.dart:103-109`

- [x] BrandRepositoryImpl.approveBrand — brandKey 자동 생성 로직
  - 근거: spec V1 — `Random.secure()` + 32 char alphabet(`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) + 8자리 + 3회 재시도
  - 위치: `lib/data/repositories/brand_repository_impl.dart:130-158`

- [x] brandKey 알파벳 정확성 (`O/0/I/1` 제외)
  - 근거: `const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'` — 32자 정확
  - 위치: `lib/data/repositories/brand_repository_impl.dart:148`

- [x] BrandRepositoryImpl.upsertBrand — 신규 brand batch write (V2-1)
  - 근거: `batch.set(brands/{brandId})` + `batch.update(users/{uid}, {'brandId': brandId})` → `batch.commit()` 원자성 보장
  - 위치: `lib/data/repositories/brand_repository_impl.dart:78-93`

- [x] upsertBrand 신규 등록 시 brandKey='' 강제
  - 근거: spec V1 — 승인 전 brandKey 미발급. `brandKey: ''` copyWith 확인
  - 위치: `lib/data/repositories/brand_repository_impl.dart:69`

- [x] upsertBrand 기존 수정 시 brandKey 보존 (불변성)
  - 근거: 기존 수정 분기에서 brand.brandKey 를 copyWith 하지 않으므로 entity 값 그대로 보존
  - 위치: `lib/data/repositories/brand_repository_impl.dart:96-127`

- [x] BrandRepositoryImpl.findByBrandKey 위임 구현
  - 위치: `lib/data/repositories/brand_repository_impl.dart:161-164`

- [x] BrandKeyCollisionException 정의
  - 근거: spec V10 — 3회 충돌 시 예외
  - 위치: `lib/core/errors/brand_key_collision_exception.dart`

- [x] BrandModel.brandKey 직렬화/역직렬화
  - 근거: `fromFirestore` 누락 시 default `''`, `toFirestore` 포함
  - 위치: `lib/data/models/brand_model.dart:11,46,99`

- [x] UpgradeToBrandUseCase 구현 — 점주 패턴 동일
  - 근거: `UserRepository.updateRole(uid, UserRole.brand)` 단순 위임. spec V2
  - 위치: `lib/domain/usecases/upgrade_to_brand_use_case.dart`

- [x] LookupBrandByKeyUseCase 구현
  - 근거: `BrandRepository.findByBrandKey(brandKey)` 위임. spec V4
  - 위치: `lib/domain/usecases/lookup_brand_by_key_use_case.dart`

- [x] SubmitStoreByBrandUseCase 파일 삭제 확인
  - 근거: `lib/domain/usecases/submit_store_by_brand_use_case.dart` 미존재 (`No such file or directory`)
  - 위치: 삭제됨

- [x] BrandStoreFormPage 파일 삭제 확인
  - 근거: `lib/presentation/brand/stores/brand_store_form_page.dart` 미존재
  - 위치: 삭제됨

- [x] SubmitStoreByBrandUseCaseProvider 제거
  - 근거: `brand_store_management_providers.dart`에 해당 provider 없음. 주석으로 V5 폐기 명시
  - 위치: `lib/presentation/brand/providers/brand_store_management_providers.dart:72-73`

- [x] upgradeToBrandUseCaseProvider 등록
  - 위치: `lib/presentation/customer/auth/providers/user_profile_provider.dart:39-41`

- [x] ownerLookupBrandByKeyUseCaseProvider 등록
  - 위치: `lib/presentation/owner/providers/owner_providers.dart:57-60`

### 기능 검증 (Presentation)

- [x] MorePage — UpgradeToBrandSection 추가 (UpgradeToOwnerSection 아래)
  - 근거: spec V8 위치 요구사항 충족. `UpgradeToOwnerSection` 직후 `UpgradeToBrandSection`
  - 위치: `lib/presentation/customer/more/more_page.dart:30-31`

- [x] UpgradeToBrandSection — UpgradeToBrandDialog 호출 후 UpgradeToBrandUseCase 실행
  - 근거: `confirmed != true` 가드 → `upgradeToBrandUseCaseProvider.call(uid)`
  - 위치: `lib/presentation/customer/more/widgets/upgrade_to_brand_section.dart:88-107`

- [x] UpgradeToBrandSection — 실패 SnackBar 처리
  - 근거: try-catch + SnackBar `'브랜드 전환에 실패했어요: $e'`, `backgroundColor: AppColors.error`
  - 위치: `lib/presentation/customer/more/widgets/upgrade_to_brand_section.dart:98-106`

- [x] UpgradeToBrandDialog — 구조 및 텍스트
  - 근거: `'브랜드로 전환하시겠어요?'`, `'취소'` / `'전환하기'` 버튼. spec / design 일치
  - 위치: `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart`

- [x] StoreCoreFormPage — SwitchListTile 토글 추가 (default false)
  - 근거: spec V3 / design D3. `_isBrandFranchise = false` 초기값
  - 위치: `lib/presentation/owner/my_store/store_core_form_page.dart:47,168-191`

- [x] StoreCoreFormPage — AnimatedSize 200ms / Curves.easeInOut
  - 근거: design D6 / spec V10. `AnimatedSize(duration: 200ms, curve: Curves.easeInOut)`
  - 위치: `lib/presentation/owner/my_store/store_core_form_page.dart:192-201`

- [x] StoreCoreFormPage — brandKey 위치 (폼 최하단 사업자번호 아래)
  - 근거: design D4. 필드 순서: 매장명 → 주소 → 카테고리 → 사업자번호 → 브랜드 가맹점 섹션
  - 위치: `lib/presentation/owner/my_store/store_core_form_page.dart:165-201`

- [x] StoreCoreFormPage — 클라이언트 정규식 `^BR-[A-Z2-9]{8}$` 검증
  - 근거: spec V4 / design D4. 빈 입력 에러 `'브랜드 키를 입력해주세요'`, 형식 불일치 `'올바른 브랜드 키 형식이 아닙니다'`
  - 위치: `lib/presentation/owner/my_store/store_core_form_page.dart:14,262-271`

- [x] StoreCoreFormPage — 서버 매칭 실패 시 SnackBar `'정상 브랜드 키가 아닙니다'`
  - 근거: spec V10 / design D4. `backgroundColor: AppColors.error`, `duration: 3초`
  - 위치: `lib/presentation/owner/my_store/store_core_form_page.dart:291-299`

- [x] StoreCoreFormPage — 토글 OFF 시 _brandKeyCtrl 초기화 및 _brandKeyError null 처리
  - 근거: spec V3 — "토글 OFF: 기존 동작". 상태 리셋 확인
  - 위치: `lib/presentation/owner/my_store/store_core_form_page.dart:183-187`

- [x] BrandInfoPage — _BrandKeyRow 추가 (approved + brandKey 있을 때)
  - 근거: spec V9 / design D5. `status==approved && brandKey.isNotEmpty` 조건 분기
  - 위치: `lib/presentation/brand/brand_info/brand_info_page.dart:162-168`

- [x] BrandInfoPage — brandKey 모노스페이스 폰트
  - 근거: design D7. `fontFamily: 'monospace'`
  - 위치: `lib/presentation/brand/brand_info/brand_info_page.dart:205-209`

- [x] BrandInfoPage — 복사 버튼 + SnackBar `'복사됐어요'`
  - 근거: spec V9 / design D5. `Clipboard.setData` + `backgroundColor: AppColors.primary` + 2초
  - 위치: `lib/presentation/brand/brand_info/brand_info_page.dart:213-231`

- [x] BrandInfoPage — pending 상태 잠금 안내 `'관리자 승인 후 브랜드 키가 발급됩니다'`
  - 근거: spec V10 / design D5
  - 위치: `lib/presentation/brand/brand_info/brand_info_page.dart:251-261`

- [x] BrandInfoPage — rejected 상태 _BrandKeyRow 미노출
  - 근거: design D5. `brand.status != EntityApprovalStatus.rejected` 조건으로 wrapping
  - 위치: `lib/presentation/brand/brand_info/brand_info_page.dart:162-168`

- [x] BrandStoresPage — FAB 제거
  - 근거: spec V6 / design D5. `Scaffold.floatingActionButton` 파라미터 없음
  - 위치: `lib/presentation/brand/stores/brand_stores_page.dart` (Scaffold 전체)

- [x] BrandStoresPage — AppBar 타이틀 `'가맹점'`
  - 근거: design `AppBar.title: '가맹점'`
  - 위치: `lib/presentation/brand/stores/brand_stores_page.dart:34-40`

- [x] BrandStoresPage — 빈 상태 안내 2줄
  - 근거: design D5. `'아직 등록된 가맹점이 없어요'` + `'점주가 브랜드 키를 입력해 매장을 등록하면\n여기에 표시됩니다'`
  - 위치: `lib/presentation/brand/stores/brand_stores_page.dart:196-231`

- [x] AdminBrandApprovalDetailPage — 승인 SnackBar 카피 보강
  - 근거: spec V10 / design. `'브랜드를 승인했어요. 브랜드 키가 발급되었습니다'`, `AppColors.success`, 3초
  - 위치: `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart:35-41`

- [x] AdminBrandApprovalDetailPage — BrandKeyCollisionException catch
  - 근거: spec V10. 별도 catch 블록 + `'브랜드 키 발급에 실패했어요. 다시 시도해주세요'`, `AppColors.error`, 4초
  - 위치: `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart:43-51`

- [x] 시드 brand brandKey 추가 (`'BR-SEED0001'`)
  - 근거: spec V7
  - 위치: `lib/dev/seed/phase1_seed_data.dart:23`

### 아키텍처 검증

- [x] presentation / domain 레이어에 Firebase 직접 import 없음
  - 근거: `grep -rn "cloud_firestore|firebase_storage|rxdart" lib/presentation lib/domain` 결과 0건
  - 위치: 전체 presentation / domain 레이어

- [x] `Random.secure()` 사용 위치 — data 레이어 한정
  - 근거: `grep -rn "Random.secure"` 결과 `brand_repository_impl.dart` 단 1건
  - 위치: `lib/data/repositories/brand_repository_impl.dart:149`

- [x] Repository Interface — domain 레이어
  - 근거: `lib/domain/repositories/brand_repository.dart`, `lib/domain/repositories/menu_override_repository.dart`

- [x] UseCase 단일 책임
  - 근거: `UpgradeToBrandUseCase` (role 갱신 1건), `LookupBrandByKeyUseCase` (brandKey 조회 1건)

### 코드 품질 / flutter analyze

- [x] `flutter analyze` 0 issue
  - 근거: `No issues found! (ran in 4.4s)`

- [x] 파일명 snake_case 준수
  - 근거: 신규 파일 전체 — `upgrade_to_brand_use_case.dart`, `lookup_brand_by_key_use_case.dart`, `upgrade_to_brand_section.dart`, `upgrade_to_brand_dialog.dart`, `brand_key_collision_exception.dart`

---

## FAIL 항목

### FAIL-1 — `submitStoreForApproval` 신규 등록 시 brandId 강제 null 덮어쓰기

- 문제: `StoreCoreFormPage._submit()`에서 `resolvedBrandId`를 `StoreEntity.brandId`에 세팅한 뒤 `submitStoreForApprovalUseCase.call(entity)`를 호출한다. 그런데 `StoreRepositoryImpl.submitStoreForApproval` 신규 등록 분기에서 `store.copyWith(brandId: null, ...)`로 강제 null 처리하고, `StoreRemoteDataSource.create(model)`은 `model.toFirestoreForCreate()`를 호출하는데 여기서도 `'brandId': null`이 하드코딩된다. 따라서 점주가 유효한 brandKey를 입력해 `resolvedBrandId`를 얻더라도 Firestore에는 항상 `brandId=null`로 저장된다. spec V4/V5의 핵심 요구사항 "brandKey 매칭 시 store.brandId 박힘"이 동작하지 않는다.
- 위치:
  - `lib/data/repositories/store_repository_impl.dart:136-143` — `brandId: null` copyWith
  - `lib/data/models/store_model.dart:229` — `toFirestoreForCreate()` 내 `'brandId': null` 하드코딩
  - `lib/data/datasources/remote/store_remote_data_source.dart:55-58` — `create()` → `toFirestoreForCreate()` 호출
- 확인 방법: 점주 매장 등록 폼에서 유효한 brandKey 입력 후 저장 → Firestore `stores/{storeId}.brandId` 필드 확인 시 null
- 제안:
  - `StoreRepositoryImpl.submitStoreForApproval` 신규 등록 분기에서 `brandId: null` copyWith 제거. `store.brandId`를 그대로 유지하거나 entity 값을 보존해야 한다.
  - `StoreModel.toFirestoreForCreate()`의 `'brandId': null` 하드코딩을 `'brandId': brandId`로 변경하거나, `create()` 메서드가 brandId를 별도 파라미터로 받도록 수정한다.
  - 가장 간단한 수정: `store_repository_impl.dart`에서 `brandId: null` → `brandId: store.brandId` (copyWith 자체를 제거하거나 brandId 라인만 제거). `toFirestoreForCreate()`에서도 `'brandId': brandId`로 변경.
- 우선순위: **높음** — spec V4/V5의 핵심 기능(점주 brandKey 매칭 → 가맹점 등록)이 완전히 동작하지 않는 치명적 결함

### FAIL-2 — `streamByBrand` 쿼리에 `status=='approved'` 필터 누락

- 문제: spec V6에서 `BrandStoresPage`가 `where('brandId','==',myBrandId).where('status','==','approved')` query를 사용하도록 명시했는데, `StoreRemoteDataSource.streamByBrand()`는 `where('brandId', isEqualTo: brandId)` 단일 조건만 적용한다. status=pending / rejected 매장도 brand의 가맹점 목록에 노출된다.
- 위치:
  - `lib/data/datasources/remote/store_remote_data_source.dart:96-102` — `streamByBrand` 메서드
- 확인 방법: brand 계정으로 BrandStoresPage 진입 시 status=pending인 매장도 목록에 표시됨
- 제안: `streamByBrand()` 에 `.where('status', isEqualTo: 'approved')` 조건 추가
- 우선순위: **중간** — spec 명세 위반이나 기능 동작 자체는 되며, status=approved 이외 매장이 노출되는 데이터 정합성 문제

---

## 보류 항목

### 보류-1 — 시드 brandKey `'BR-SEED0001'`이 정규식 `^BR-[A-Z2-9]{8}$` 불통과

- 이유: `'BR-SEED0001'`은 `0` 문자(V1 제외 목록)와 소문자 포함으로 정규식 검증 실패. spec에서 시드 brandKey는 관리자 승인 흐름을 우회해 Firestore에 직접 write되므로 클라이언트 정규식 검증을 통과하지 않는다. implementation.md에도 "시드 brandKey는 정규식 통과 불가 — 시드 전용 값"으로 명시되어 있다.
- 영향: BrandInfoPage에서 'BR-SEED0001' 표시 자체는 가능(read-only). 점주가 `'BR-SEED0001'`을 폼에 입력하면 클라이언트 정규식(`^BR-[A-Z2-9]{8}$`) 에서 걸려 서버 조회 전 차단. 시드 데이터로 end-to-end 가맹점 연결 테스트 불가.
- 필요한 확인: 실제 운영에서는 발생 안 하나, 개발 환경 end-to-end 테스트를 위해 시드 brandKey를 `'BR-QBREW001'`처럼 정규식 통과 가능한 값으로 교체하는 것이 바람직함
- 후속 작업 제안: spec V7에서 "시드 brandKey 갱신" 명시 — `'BR-SEED0001'` → 정규식 통과 값(`'BR-QBREW999'` 등)으로 교체하면 개발 환경 검증 편의성 향상. 단, 운영 영향 없어 즉각 수정 불필요

### 보류-2 — `SwitchListTile.activeColor` 미적용 (activeThumbColor만 적용)

- 이유: design.md에서 `activeColor: AppColors.primary` 지정. Flutter의 `SwitchListTile`에서 `activeColor`는 thumb + track 전체에 영향을 주고, `activeThumbColor`는 thumb에만 영향. 구현에서는 `activeThumbColor: AppColors.primary`만 있고 `activeColor`나 `activeTrackColor`가 없어 토글 track이 primary 색상을 따르지 않을 수 있음.
- 필요한 확인: 실기기에서 Switch ON 시 track 색상 확인 필요
- 후속 작업 제안: `activeColor: AppColors.primary` 또는 `activeTrackColor: AppColors.primary.withValues(alpha: 0.5)` 추가 검토

### 보류-3 — `Colors.black.withValues(alpha: 0.6)` barrierColor 하드코딩

- 이유: `UpgradeToBrandDialog`에서 `barrierColor: Colors.black.withValues(alpha: 0.6)` 사용. CLAUDE.md 절대 규칙은 `Color(0x...)` 직접 하드코딩 금지이며 `AppColors`만 허용. `Colors.black`은 Flutter 기본 색상 상수이지 `Color(0x...)` 직접 정의는 아님. `UpgradeToOwnerDialog`도 동일 패턴을 사용하므로 프로젝트 공통 관행으로 볼 여지 있음.
- 필요한 확인: `AppColors`에 barrier 색상 토큰이 있는지 확인 후 토큰 사용 여부 결정
- 후속 작업 제안: 디자인 시스템에 `AppColors.barrierColor` 또는 `AppColors.scrim` 토큰 추가 검토

### 보류-4 — `MenuOverrideRepository.seedExclusionsForStore` 인터페이스/구현 잔류

- 이유: spec V5에서 `MenuOverrideRepository.seedExclusionsForStore` / `MenuOverrideRemoteDataSource.seedExclusionsForStore` 삭제 대상으로 명시. 실제로 해당 메서드가 `lib/domain/repositories/menu_override_repository.dart:57`, `lib/data/repositories/menu_override_repository_impl.dart:123`, `lib/data/datasources/remote/menu_override_remote_data_source.dart:102`에 잔류. 단, 호출부가 없고 `flutter analyze 0 issue`이므로 dead code 상태.
- 필요한 확인: implementation.md에 이 항목이 미구현/보류로 기재되어 있지 않음. spec은 삭제를 명시했으나 실제 삭제되지 않은 상태.
- 후속 작업 제안: 해당 메서드 삭제 작업 developer에게 전달 (호출부 없으므로 flutter analyze에는 영향 없지만 spec 위반 dead code 잔류)

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **재작업 필요** — FAIL-1이 spec V4/V5의 핵심 기능(점주 brandKey 매칭 → 가맹점 등록)을 완전히 파괴하므로 즉시 수정 필요. FAIL-2는 데이터 정합성 문제로 함께 수정 권장.

### 재작업 우선순위

1. **FAIL-1 — submitStoreForApproval의 brandId 강제 null**
   - 이유: 점주가 brandKey를 입력해 매장을 가맹점으로 등록하는 전체 흐름이 동작하지 않는다. sub-phase 6의 핵심 기능 파괴. 수정 범위: `store_repository_impl.dart:138`의 `brandId: null` 제거 + `store_model.dart:229`의 `toFirestoreForCreate()` 내 `'brandId': null` → `'brandId': brandId`로 변경.

2. **FAIL-2 — streamByBrand status 필터 누락**
   - 이유: spec V6 명시 요구사항 위반. pending/rejected 매장이 brand 가맹점 목록에 표시되어 brand 운영자의 혼란 유발. 수정 범위: `store_remote_data_source.dart:streamByBrand()`에 `.where('status', isEqualTo: 'approved')` 추가.

### 후속 task 후보

- **시드 brandKey 수정 (보류-1)**: `'BR-SEED0001'` → 정규식 통과 값으로 교체. 개발 환경 end-to-end 테스트 편의성 향상.
- **seedExclusionsForStore 정리 (보류-4)**: 호출부 없는 dead code 메서드 삭제. spec V5 완전 이행.
- **SwitchListTile activeColor 확인 (보류-2)**: 실기기 track 색상 확인 후 필요 시 `activeColor` 또는 `activeTrackColor` 추가.

---

## admin_menu_management 통합 완료 상태

본 sub-phase 6이 `admin_menu_management` 의 마지막 sub-phase. FAIL-1 / FAIL-2 수정 후 재검증 완료 시 `admin_menu_management` 전체 완료.

현재 상태:
- sub-phase 1 (brand_master): PASS
- sub-phase 2 (store_registration_approval): PASS
- sub-phase 3 (brand_store_customization): PASS
- sub-phase 4 (owner_menu_crud): PASS
- sub-phase 5 (option_management): PASS
- sub-phase 6 (upgrade_to_brand): **FAIL (2건 — 수정 후 재검증 필요)**

---

## 완료 판단

- [ ] 전체 PASS
- [ ] FAIL 있으나 후속 task로 분리 가능
- [x] 재작업 필요 (FAIL-1 / FAIL-2 수정 후 재검증)
