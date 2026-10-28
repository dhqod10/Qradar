# Implementation — 브랜드 사업자 정보 필드 추가 (Step 3)

---

## ⚠️ 구조 변경 정합화 (2026-10-28)

> 아래 "구현 완료 항목"은 **최초 구현 시점(Step 3)** 기준이다. 이후 **payment_server_authority B1**
> (커밋 `3feb96d`) 작업이 PII 보호를 위해 사업자 정보 필드 배치를 아래와 같이 재구조화했으므로,
> **현재 운영 코드는 이 정합화 블록을 단일 진실원으로 따른다.**

### 필드 배치 (현행)

| 필드 | 최초(Step 3) | 현행 |
|------|--------------|------|
| `companyName` (회사명, 필수) | `BrandEntity` | **`BrandEntity` (유지)** |
| `businessRegistrationNumber` | `BrandEntity` | **`BrandPrivateProfileEntity`** (`brands/{id}/private/profile`) |
| `contactName` | `BrandEntity` | **`BrandPrivateProfileEntity`** |
| `contactPhone` | `BrandEntity` | **`BrandPrivateProfileEntity`** |
| `headOfficeAddress` (선택) | `BrandEntity` | **`BrandPrivateProfileEntity`** |
| `representativeName` (선택) | `BrandEntity` | **`BrandPrivateProfileEntity`** |

PII 5개는 부모 `brands/{id}` 문서가 아니라 `brands/{id}/private/profile` 서브컬렉션으로 분리 저장된다.
`brandKey` 는 이 경로에서 클라이언트가 쓰지 않는다 (Cloud Function 전담).

### 현행 데이터 흐름 (검증 완료 2026-10-28)

1. `BrandInfoFormPage._submit` → `BrandEntity(companyName:...)` + `BrandPrivateProfileEntity(PII 5)` 2건 생성
   - `lib/presentation/brand/brand_info/brand_info_form_page.dart:403~` (`신청하기`)
2. `UpsertBrandUseCase.call(brand, privateProfile:)`
   - `lib/domain/usecases/upsert_brand_use_case.dart:15`
3. `BrandRepositoryImpl.upsertBrand` → PII 는 `BrandPrivateProfileModel.toFirestore()` 결과를 `private/profile` 에 **merge-set**
   - `lib/data/repositories/brand_repository_impl.dart:83~`, 저장 실패 시 `BrandPrivateProfileSaveException`
   - PII 만 변경 시 brand `status` 는 회귀하지 않는다 (`brand_repository_impl.dart:141`)
4. admin 승인 상세: `brandPrivateProfileProvider(brand.id)` 로 PII 를 **별도 조회**해 사업자 정보 카드 노출
   - `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart:209, 266`

### 검증

- `flutter analyze` (관련 4개 파일): **No issues found**
- 검증 상세: 같은 디렉토리 `test_report.md` 참조. PII 분리 자체의 보안 검증은 payment_server_authority B1 에서 완료·배포됨.

# Implementation — 브랜드 사업자 정보 필드 추가 (Step 3)

## 구현 완료 항목

### 1. Domain — `BrandEntity` 필드 추가
- 파일: `lib/domain/entities/brand_entity.dart`
- 신규 필드 6개 추가:
  - `companyName` (String, required, default '')
  - `businessRegistrationNumber` (String, required, default '')
  - `contactName` (String, required, default '')
  - `contactPhone` (String, required, default '')
  - `headOfficeAddress` (String?, optional)
  - `representativeName` (String?, optional)
- `dart run build_runner build --delete-conflicting-outputs` 재실행 완료
- freezed 파일: `lib/domain/entities/brand_entity.freezed.dart` 자동 갱신

### 2. Data — `BrandModel` 직렬화 갱신
- 파일: `lib/data/models/brand_model.dart`
- `fromFirestore`: 신규 6개 필드 파싱 추가, legacy doc 호환 (`?? ''` / `as String?`)
- `fromEntity`: 신규 6개 필드 매핑 추가
- `toEntity`: 신규 6개 필드 매핑 추가
- `toFirestore`: 필수 4개 필드 항상 저장, 선택 2개 필드 null 이면 생략

### 3. Presentation — `BrandInfoFormPage` 폼 보강
- 파일: `lib/presentation/brand/brand_info/brand_info_form_page.dart`
- "사업자 정보" 섹션 divider 추가 (`_sectionDivider`)
- 신규 TextField 6개 추가 (회사명 / 사업자등록번호 / 담당자 이름 / 담당자 연락처 / 본사 주소 / 대표자 이름)
- 인라인 에러 데코레이터 `_inputDecorationWithError` 추가
- 검증 로직:
  - 사업자등록번호 정규식: `^\d{3}-\d{2}-\d{5}$`
  - 담당자 연락처 정규식: `^\d{2,3}-\d{3,4}-\d{4}$`
  - 입력 중 실시간 인라인 에러 표시
- `_canSubmit`: 기존 조건 + 회사명 / 사업자번호(형식 통과) / 담당자명 / 연락처(형식 통과) 모두 충족 시 활성화
- `_submit`: `BrandEntity` 생성 시 신규 6개 필드 포함
- 버튼 텍스트: '신청하기'로 변경

### 4. Presentation — `AdminBrandApprovalDetailPage` 사업자 정보 카드 추가
- 파일: `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart`
- `_SectionCardWithTitle` 위젯 추가 (타이틀 + 구분선 + InfoRow 목록)
- 사업자 정보 카드 조건부 노출 (`companyName` 또는 `businessRegistrationNumber` 비어 있지 않을 때)
- 노출 항목: 회사명 / 사업자번호 / 담당자(이름 / 연락처) / 본사 주소(있을 때) / 대표자(있을 때)

### 5. Presentation — `UpgradeToBrandDialog` 안내 보강
- 파일: `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart`
- 본문 첫째 줄: '브랜드 정보와 사업자 정보를 입력하면 관리자 검수가 필요해요. 영업일 1-2일 소요됩니다.'
- 본문 둘째 줄 (보조): '승인 후 마스터 메뉴를 등록하고, 점주는 브랜드 키로 가맹점을 연결할 수 있어요.'

### 6. 시드 갱신
- 파일: `lib/dev/seed/phase1_seed_data.dart`
- `brandDoc()`에 사업자 정보 6개 필드 추가:
  - companyName: '(주)Qradar 시드 브랜드'
  - businessRegistrationNumber: '123-45-67890'
  - contactName: '홍길동'
  - contactPhone: '010-1234-5678'
  - headOfficeAddress: '서울시 강남구 테헤란로 1'
  - representativeName: '김대표'

---

## 수정 파일 목록

| 파일 | 변경 유형 |
|------|----------|
| `lib/domain/entities/brand_entity.dart` | 수정 |
| `lib/domain/entities/brand_entity.freezed.dart` | 자동 재생성 |
| `lib/data/models/brand_model.dart` | 수정 |
| `lib/presentation/brand/brand_info/brand_info_form_page.dart` | 수정 |
| `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart` | 수정 |
| `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart` | 수정 |
| `lib/dev/seed/phase1_seed_data.dart` | 수정 |

---

## flutter analyze 결과

```
No issues found! (ran in 4.6s)
```

---

## 회귀 보호

- legacy Firestore doc (신규 필드 누락) → `?? ''` / `as String?` 기본값 처리로 안전
- 기존 `BrandEntity` 생성 코드에서 신규 필드 생략 시 모두 기본값 적용 (freezed `@Default`)
- sub-phase 1 / 3 / 6 기존 로직 무영향
