# 6_upgrade_to_brand 구현 내역

## 개요

- 구현 목적: brand 가입 흐름을 점주 패턴과 동일하게 통일하고, brand 승인 시 자동 발급되는 `brandKey` 를 점주 매장 등록의 가맹점 연결 수단으로 활용한다.
  - Qrator(고객)가 더보기 페이지에서 브랜드로 전환 → `UserRole.brand` 로 role 갱신 → 브랜드 정보 등록 → admin 승인 시 `brandKey` 자동 발급.
  - 점주는 매장 등록 폼에서 brandKey 를 입력해 brand 와 연결한다.
  - 기존 `SubmitStoreByBrandUseCase` / `BrandStoreFormPage` / `submitStoreForApprovalByBrand` 패스를 완전히 폐기하고 점주 등록 폼 단일 진입점으로 통합.
- 기준 문서:
  - `docs/tasks/admin_menu_management/6_upgrade_to_brand/spec.md`
  - `docs/tasks/admin_menu_management/6_upgrade_to_brand/design.md`

---

## 구현 파일 목록

### 신규 파일

- `lib/domain/usecases/upgrade_to_brand_use_case.dart` — Qrator → brand role 전환 UseCase
- `lib/domain/usecases/lookup_brand_by_key_use_case.dart` — brandKey 로 승인 brand 조회 UseCase
- `lib/core/errors/brand_key_collision_exception.dart` — brandKey 자동 생성 3회 충돌 예외
- `lib/presentation/customer/more/widgets/upgrade_to_brand_section.dart` — MorePage 에 노출되는 브랜드 전환 진입 섹션
- `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart` — 브랜드 전환 확인 다이얼로그

### 수정 파일

- `lib/domain/entities/brand_entity.dart` — `brandKey: String` (`@Default('')`) 필드 추가
- `lib/domain/entities/brand_entity.freezed.dart` — build_runner 재생성 (brandKey 추가 반영)
- `lib/domain/repositories/brand_repository.dart` — `findByBrandKey(String brandKey)` 추상 메서드 추가
- `lib/data/models/brand_model.dart` — `brandKey` 직렬화/역직렬화 추가
- `lib/data/datasources/remote/brand_remote_data_source.dart` — `findByBrandKey` / `isBrandKeyTaken` 메서드 추가
- `lib/data/repositories/brand_repository_impl.dart` — `approveBrand` brandKey 자동 생성, `upsertBrand` 신규 branch batch write, `findByBrandKey` 구현
- `lib/data/repositories/store_repository_impl.dart` — `submitStoreForApproval` 신규 등록 분기에서 `brandId` 전달, `currentBrandIdGetter` 제거 (주석 처리)
- `lib/presentation/customer/more/more_page.dart` — `UpgradeToBrandSection` 추가
- `lib/presentation/customer/auth/providers/user_profile_provider.dart` — `upgradeToBrandUseCaseProvider` 추가
- `lib/presentation/owner/providers/owner_providers.dart` — `ownerLookupBrandByKeyUseCaseProvider` 추가
- `lib/presentation/owner/my_store/store_core_form_page.dart` — `_isBrandFranchise` 토글 + `_brandKeyCtrl` + 형식/서버 이중 검증 + `resolvedBrandId` 로 `StoreEntity.brandId` 설정
- `lib/presentation/brand/brand_info/brand_info_page.dart` — `_BrandKeyRow` 위젯 추가 (approved 일 때 brandKey 표시 + Clipboard 복사)
- `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart` — `_approve` 에서 `BrandKeyCollisionException` catch + SnackBar 처리
- `lib/presentation/brand/stores/brand_stores_page.dart` — FAB 제거, AppBar 타이틀 "가맹점", 빈 상태 `_EmptyView` 추가
- `lib/presentation/brand/providers/brand_store_management_providers.dart` — `SubmitStoreByBrandUseCaseProvider` 제거
- `lib/dev/seed/phase1_seed_data.dart` — `brandDoc()` 에 `brandKey: 'BR-SEED0001'` 추가

### 삭제 파일

- `lib/domain/usecases/submit_store_by_brand_use_case.dart` — 폐기 (점주 등록 통합으로 불필요)
- `lib/presentation/brand/stores/brand_store_form_page.dart` — 폐기 (brand 직접 매장 등록 UI 제거)

---

## 주요 결정사항

### V1: brandKey 자동 생성 시점

- 결정: admin 이 brand 를 승인하는 시점(`approveBrand`)에 자동 생성. pending/rejected 상태에서는 `brandKey=''`.
- 이유: 검토 전 key 가 노출되면 무단 사용 가능. 승인 완료 후 단 1회 발급.

### V2-1: upsertBrand 신규 등록 시 batch write

- 결정: `brands/{brandId}` 문서 생성과 `users/{uid}.brandId` 갱신을 Firestore `WriteBatch` 한 번에 commit.
- 이유: 두 write 중 하나만 성공하면 role 은 brand 이지만 brandId 가 없는 일관성 깨진 상태 발생. atomicity 보장.
- 구현: `BrandRepositoryImpl.upsertBrand` isNew 분기 내 `batch.set` + `batch.update` → `batch.commit()`.

### V3: 점주 폼 brandKey 섹션

- 결정: 매장 등록 폼(`StoreCoreFormPage`)에 `SwitchListTile` 토글 + `AnimatedSize` 로 `_BrandKeyField` 표시.
- 이유: 점주가 브랜드 가맹 여부를 명시적으로 선택해야 brandKey 입력 UI 가 노출되어야 UX 혼란 없음.
- 상세: 토글 OFF 시 `_brandKeyCtrl.clear()` + `_brandKeyError = null` 으로 상태 리셋.

### V4: brandKey 이중 검증 (클라이언트 + 서버)

- 결정: 클라이언트 사이드 정규식 검증(`^BR-[A-Z2-9]{8}$`) 통과 후, `LookupBrandByKeyUseCase` 로 서버에서 approved brand 조회. null 이면 "정상 브랜드 키가 아닙니다" SnackBar.
- 이유: 형식 오류는 즉시 피드백, 존재 여부는 서버가 단일 진실원.

### V5: submitStoreForApproval 의 brandKey 매칭

- 결정: `StoreCoreFormPage._submit()` 에서 brandKey 서버 매칭 결과인 `resolvedBrandId` 를 `StoreEntity.brandId` 에 세팅 후 `submitStoreForApprovalUseCase` 를 단일 경로로 호출.
- 이유: brand / 일반 매장 등록을 별도 UseCase 로 분기하지 않아 로직 중복 제거.

### V6: BrandStoresPage 는 read-only (FAB 없음)

- 결정: brand 는 매장을 직접 생성하지 않는다. FAB 제거, 빈 상태에서는 "아직 가맹점이 없어요. 점주에게 브랜드 키를 전달하세요." 안내 텍스트.
- 이유: spec V6 — 매장 등록 진입점은 점주 폼 단일 경로.

### V7: UpgradeToBrandSection 위치

- 결정: `MorePage` 의 `UpgradeToOwnerSection` 바로 아래. 색상 톤은 `AppColors.primary` (점주 섹션 `AppColors.accent` 와 차별화).
- 이유: design.md 지정 위치.

### V8: UpgradeToBrandUseCase 구현

- 결정: `UserRepository.updateRole(uid, UserRole.brand)` 단순 위임.
- 이유: role 갱신은 `UpgradeToOwnerUseCase` 와 동일 패턴 재사용. role 변경 후 RoleRouter 가 Stream 감지로 자동 전환.

### V9: BrandInfoPage brandKey 섹션

- 결정: brand status == approved 이고 brandKey 가 비어있지 않을 때만 `_BrandKeyRow` 표시. 복사 버튼으로 Clipboard 저장 후 "복사됨" SnackBar.
- 이유: pending/rejected 상태에서는 key 미발급 → 불필요한 UI 숨김.

### V10: BrandKeyCollisionException

- 결정: `_generateUniqueBrandKey` 3회 재시도 모두 충돌 시 `BrandKeyCollisionException` throw. AdminBrandApprovalDetailPage 에서 별도 catch 블록으로 전용 SnackBar 표시.
- 이유: 32^8 ≈ 1.1조 조합이므로 실제 발생 확률 0 에 가깝지만, 발생 시 admin 에게 명확한 피드백 필요.

---

## brandKey 자동 생성 로직

```
alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'  // 32자 (O/0/I/1 제외)
Random.secure() 사용

for attempt in [0, 1, 2]:
  chars = List.generate(8, (_) => alphabet[rng.nextInt(32)])
  key   = 'BR-' + chars.join()
  taken = await _dataSource.isBrandKeyTaken(key)
  if !taken: return key

throw BrandKeyCollisionException()
```

- `isBrandKeyTaken`: `where('brandKey','==',key).limit(1)` — status 무관하게 동일 key 존재 시 true.
- `findByBrandKey`: `where('brandKey','==',key).where('status','==','approved').limit(1)` — 점주 검증용.

---

## users.brandId batch write 원자성

`BrandRepositoryImpl.upsertBrand` 신규 등록 분기:

```
batch.set(brands/{brandId}, model.toFirestore(), merge: true)
batch.update(users/{uid}, {'brandId': brandId})
await batch.commit()
```

두 write 중 하나만 성공하는 불일치 상태를 방지. Firestore WriteBatch 는 all-or-nothing 보장.

기존 수정 분기에서는 `users.brandId` 는 이미 세팅된 상태이므로 batch 불필요.

---

## 점주 매장 등록 brandKey 매칭 흐름

```
StoreCoreFormPage._submit()
  └─ if _isBrandFranchise:
      1. 클라이언트 정규식 검증: ^BR-[A-Z2-9]{8}$
         → 실패 시 _brandKeyError 세팅 (즉시 피드백)
      2. ownerLookupBrandByKeyUseCaseProvider.call(key)
         → null 이면 "정상 브랜드 키가 아닙니다" SnackBar + return
         → matched.id → resolvedBrandId
  └─ StoreEntity(brandId: resolvedBrandId ?? e?.brandId, ...)
  └─ submitStoreForApprovalUseCase.call(entity)
```

`StoreRepositoryImpl.submitStoreForApproval` 신규 등록 시 `brandId: null` 강제 코드를 제거하고 entity 의 brandId 를 그대로 전달.

---

## 폐기된 항목

| 항목 | 폐기 이유 |
|---|---|
| `SubmitStoreByBrandUseCase` (`lib/domain/usecases/submit_store_by_brand_use_case.dart`) | 점주 등록 폼 통합으로 brand 전용 등록 경로 불필요 |
| `BrandStoreFormPage` (`lib/presentation/brand/stores/brand_store_form_page.dart`) | brand 가 매장을 직접 등록하는 UI 제거 |
| `submitStoreForApprovalByBrand` (StoreRepository 메서드) | 동일 이유 |
| `SubmitStoreByBrandUseCaseProvider` (brand_store_management_providers.dart) | 의존 UseCase 삭제에 따른 제거 |
| `StoreRepositoryImpl.currentBrandIdGetter` 파라미터 | 폐기된 메서드의 의존성. 하위 호환 주석만 유지, 내부 사용 없음 |

---

## 시드 데이터 갱신

`lib/dev/seed/phase1_seed_data.dart` `brandDoc()` 에 `'brandKey': 'BR-SEED0001'` 추가.

- 시드 brand ID: `phase3_seed_brand_001`
- 시드 brand store ID: `phase3_brand_store_001`
- 시드 brandKey: `BR-SEED0001` — 테스트 시 점주 폼에 입력하면 Q브루어리 가맹점으로 연결 확인 가능.

주의: 시드 brandKey 는 알파벳 + 숫자 패턴(`^BR-[A-Z2-9]{8}$`)을 만족하지 않아 클라이언트 정규식 검증 실패함. 시드 전용 값으로 테스트 시 실제 발급된 brandKey(랜덤 8자리) 를 사용하거나 정규식 통과하는 값(`BR-ABCD1234` 등)을 Firestore 에 직접 입력해 확인.

---

## 테스트 포인트

### 브랜드 전환 흐름

- [ ] MorePage 에 `UpgradeToBrandSection` 표시 확인 (customer role 인 경우)
- [ ] 다이얼로그 "전환하기" 탭 → `UpgradeToBrandUseCase` 호출 → role = brand 전환 → RoleRouter 자동 이동
- [ ] 다이얼로그 "취소" → role 변화 없음

### brandKey 발급

- [ ] admin 이 brand 승인 시 brandKey 자동 생성 (Firestore `brands/{id}.brandKey` 필드 확인)
- [ ] 승인 SnackBar: "브랜드를 승인했어요. 브랜드 키가 발급되었습니다"
- [ ] `BrandKeyCollisionException` 발생 시 "브랜드 키 발급에 실패했어요" SnackBar (실제 테스트 어려움 — 코드 검토로 확인)

### BrandInfoPage brandKey 표시

- [ ] approved + brandKey 비어있지 않으면 `_BrandKeyRow` 표시
- [ ] 복사 버튼 탭 → Clipboard 에 brandKey 저장 + "복사됨" SnackBar
- [ ] pending/rejected 상태에서는 `_BrandKeyRow` 미노출

### 점주 매장 등록 brandKey 매칭

- [ ] "브랜드 가맹점" 토글 OFF → brandKey 입력 UI 숨김
- [ ] 토글 ON → `_BrandKeyField` 노출
- [ ] 빈 brandKey 제출 → "브랜드 키를 입력해주세요" 인라인 에러
- [ ] 형식 불일치(`abc`) → "올바른 브랜드 키 형식이 아닙니다" 인라인 에러
- [ ] 존재하지 않는 brandKey → "정상 브랜드 키가 아닙니다" SnackBar
- [ ] 유효한 brandKey → 매칭된 brand 의 id 가 `StoreEntity.brandId` 에 설정되어 Firestore 저장
- [ ] 일반 등록(토글 OFF)은 brandId = null 로 저장

### BrandStoresPage

- [ ] FAB 없음 확인
- [ ] 가맹점 없는 경우 `_EmptyView` (안내 텍스트) 표시
- [ ] 가맹점 있는 경우 목록 표시 + 개별 카드 탭 시 `BrandStoreCustomizationPage` 이동

### 회귀 확인

- [ ] Phase 1a/1b (고객 주문 흐름) 무영향
- [ ] Phase 2 (점주 운영 필드 수정) 무영향
- [ ] sub-phase 1/2 (brand 등록/수정/조회) 무영향
- [ ] sub-phase 3 (brand 마스터 메뉴) 무영향
- [ ] sub-phase 4/5 (admin brand 승인/반려) 무영향
- [ ] 점주 기존 매장(brandId=null)은 브랜드 가맹점 토글 OFF 기본값으로 정상 등록

---

## 미구현 / 보류 항목

- **N:1 brand 매핑** (점주 1명이 여러 brand 와 연결): 현재 StoreEntity.brandId 는 단일 값. 향후 요구사항 확정 후 설계.
- **brandKey 회전 (rotation)**: 승인 이후 brandKey 변경 기능 미구현. admin 또는 brand 권한자가 재발급하는 시나리오는 spec 에 미포함.
- **brandKey 입력 실시간 debounce 검증**: 현재는 제출 시점에 서버 검증. 입력 중 실시간 검증 UX 는 보류.
- **upsertBrand 기존 수정 시 brandKey 보존 명시적 단위 테스트**: 코드 주석으로 보존 의도 명시, 자동화 테스트 미작성.

---

## 코드 생성

`BrandEntity` 에 `brandKey` 필드 추가로 `brand_entity.freezed.dart` 재생성 필요.

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 실행한 검증 명령

```
flutter analyze
→ No issues found! (ran in 4.3s)
```
