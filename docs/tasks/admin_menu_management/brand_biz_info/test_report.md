# brand_biz_info — 테스트 리포트

## 테스트 일시

- 2026-10-28

## 배경

- 이 기능(브랜드 사업자 정보 입력/검수)은 최초 Step 3 에서 구현되었으나 `test_report.md` 가 누락된 채 남아 있었다.
- 이후 **payment_server_authority B1** (커밋 `3feb96d`) 이 PII 보호를 위해 사업자 정보 필드를 재구조화했다
  (`companyName` 만 부모 `brands/{id}`, 나머지 PII 5개는 `brands/{id}/private/profile`).
- 본 리포트는 **현행 코드 기준**으로 사업자 정보 입력→저장→검수 흐름을 정적 검증하고 과제를 공식 종료한다.
- 정합화 기준: 같은 디렉토리 `implementation.md` 의 "⚠️ 구조 변경 정합화 (2026-10-28)" 블록.

## 테스트 방법

- 정적 코드 검증 (파일 직접 읽기 / grep)
- 데이터 흐름 추적 (Presentation → Domain UseCase → Data Repository → DataSource)
- Clean Architecture 레이어 경계 / Firebase import 위치 확인
- `flutter analyze` (관련 파일)

## 전체 결과

- PASS: 11
- FAIL: 0
- 보류: 2

---

## PASS 항목

### 입력 (Presentation)

- [x] P1. `BrandInfoFormPage` 가 사업자 정보 6개 입력 필드를 제공
  - `lib/presentation/brand/brand_info/brand_info_form_page.dart`
- [x] P2. 사업자등록번호 정규식 `^\d{3}-\d{2}-\d{5}$` 인라인 검증
  - `brand_info_form_page.dart:19`
- [x] P3. 담당자 연락처 정규식 `^\d{2,3}-\d{3,4}-\d{4}$` 인라인 검증
- [x] P4. `_submit` 이 `companyName` 은 `BrandEntity`, PII 5개는 `BrandPrivateProfileEntity` 로 분리 생성
  - `brand_info_form_page.dart:403~`

### 저장 (Domain → Data)

- [x] P5. `UpsertBrandUseCase.call(brand, {privateProfile})` 시그니처로 PII 전달
  - `lib/domain/usecases/upsert_brand_use_case.dart:15`
- [x] P6. `BrandRepositoryImpl.upsertBrand` 가 PII 를 `private/profile` 로 **merge-set**
  - `lib/data/repositories/brand_repository_impl.dart:83~`
- [x] P7. 저장 실패 시 `BrandPrivateProfileSaveException(brandId)` 로 명시적 에러
  - `brand_repository_impl.dart:134`
- [x] P8. PII 만 변경 시 brand `status` 회귀 없음 (검수 통과 상태 보존)
  - `brand_repository_impl.dart:141`
- [x] P9. 클라이언트는 `brandKey` 를 `private/profile` 에 쓰지 않음 (CF 전담)
  - `brand_repository_impl.dart:176`

### 검수 (Admin)

- [x] P10. admin 승인 상세가 `brandPrivateProfileProvider(brand.id)` 로 PII 별도 조회 후 카드 노출
  - `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart:209, 266`

### 품질

- [x] P11. `flutter analyze` (관련 4개 파일) — No issues found
  - 대상: `brand_private_profile_entity.dart` / `brand_info_form_page.dart` /
    `admin_brand_approval_detail_page.dart` / `brand_repository_impl.dart`

---

## 보류 항목

- [보류-1] 에뮬레이터/실기기 런타임 E2E (입력→Firestore `private/profile` 실제 기록→admin 화면 렌더)
  는 정적 검증 범위 밖. PII 분리 자체의 보안/권한 검증은 payment_server_authority B1 에서 완료·배포됨.
- [보류-2] 레거시 brand 문서(사업자 정보 없음) 마이그레이션은 `migrateBrandPrivateProfile`
  (admin 임시 callable) 소관 — 본 과제 범위 밖.

---

## 결론

- 사업자 정보 입력→분리 저장→admin 검수 흐름이 현행 코드에서 레이어 경계를 지키며 정상 연결됨.
- 기능 코드는 이미 운영 반영·배포 상태이며, 본 리포트로 `brand_biz_info` 과제 문서 세트를 종료한다.
- spec.md / design.md 는 소급 작성하지 않음 — 기능이 payment_server_authority B1 에 흡수되어
  해당 task 문서가 상위 단일 진실원 역할을 한다.
