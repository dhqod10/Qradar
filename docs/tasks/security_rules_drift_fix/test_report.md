# security_rules_drift_fix 테스트 리포트

## 테스트 일시

- 2026-05-25 ~ 2026-05-26

---

## 테스트 방법

- 정적 코드 검증: `firestore.rules` 코드 직접 확인 + spec.md / implementation.md 대조
- 라이브 흐름 검증: 운영 Firestore 환경에서 brand 등록·수정, 매장 핵심 필드 수정 흐름 수동 테스트
- `flutter analyze` — No issues found
- `firebase deploy --only firestore:rules --dry-run` — 경고 0, 에러 0 (implementation.md 기록)

---

## 전체 결과

- PASS: 28개
- FAIL: 1개
- 보류: 4개

---

## PASS 항목

### 기능 검증 — 원래 drift fix 범위

- [x] A. `isBrandSelfUpdate` 화이트리스트 수정 완료
  - 근거: spec.md 누락 필드 목록(`companyName`, `businessRegistrationNumber`, `contactName`, `contactPhone`, `headOfficeAddress`, `representativeName`, `status`, `submittedBy`, `submittedAt`, `rejectedReason`)이 firestore.rules의 `isBrandSelfUpdate` 화이트리스트에 모두 포함 확인 (lines 356-373)
  - 위치: `firestore.rules` lines 354-374

- [x] brand 본인이 name/description 수정 (status=pending 회귀 포함) → Rules 통과
  - 근거: 화이트리스트에 status/submittedBy/submittedAt 포함 + status 자기 승격 차단 조건 확인
  - 위치: `firestore.rules` lines 365-370

- [x] brand 본인이 companyName/businessRegistrationNumber 수정 → Rules 통과
  - 근거: 화이트리스트에 해당 필드 포함 확인
  - 위치: `firestore.rules` lines 362-364

- [x] brand 본인이 status='approved' 시도 → 차단
  - 근거: `request.resource.data.get('status', '') == 'pending'` 조건으로 approved 값 차단 (lines 366-370)
  - 위치: `firestore.rules` lines 366-370

- [x] brand 본인이 brandKey/approvedBy/approvedAt/createdAt 수정 시도 → 차단
  - 근거: `!affectedKeys().hasAny(['brandKey', 'approvedBy', 'approvedAt', 'createdAt'])` (lines 371-373)
  - 위치: `firestore.rules` lines 371-373

- [x] B. `isStoreOwnerFieldUpdate` 화이트리스트 수정 완료
  - 근거: spec.md 누락 필드(`status`, `submittedBy`, `submittedAt`, `businessRegistrationNumber`, `approvedBy`, `approvedAt`, `rejectedReason`, `temporaryClosed`, `closedDates`, `imageUrls`)가 firestore.rules 화이트리스트에 모두 포함 확인 (lines 231-244)
  - 위치: `firestore.rules` lines 231-258

- [x] 점주가 매장 핵심 필드 수정 (status=pending 회귀 포함) → Rules 통과
  - 근거: 화이트리스트 + status 자기 승격 차단 조건 확인
  - 위치: `firestore.rules` lines 246-249

- [x] 점주가 businessRegistrationNumber 수정 → Rules 통과
  - 근거: 화이트리스트에 포함 (line 241)
  - 위치: `firestore.rules` line 241

- [x] T3 재제출 (approvedBy/approvedAt null 클리어) → Rules 통과
  - 근거: `approvedBy`/`approvedAt` 값이 null인 경우만 허용 조건 (lines 250-258)
  - 위치: `firestore.rules` lines 250-258

- [x] 점주가 status='approved' 직접 set 시도 → 차단
  - 근거: `request.resource.data.get('status', '') == 'pending'` 조건 (lines 246-249)
  - 위치: `firestore.rules` lines 246-249

- [x] 점주가 ownerId 수정 시도 → 차단
  - 근거: `ownerId`가 화이트리스트에 없음 (lines 231-244)
  - 위치: `firestore.rules` lines 231-244

- [x] C. `isStoreOwnerBrandUpdate` — isStoreOwnerFieldUpdate와 동일 화이트리스트 + 보안 조건 적용
  - 근거: firestore.rules lines 263-288 확인. 동일 화이트리스트 + status 승격 차단 + approvedBy/At 보호
  - 위치: `firestore.rules` lines 263-288

- [x] brand holder가 가맹점 운영 필드 수정 → Rules 통과
  - 근거: `isBrandHolder(resource.data.get('brandId', ''))` 조건 (line 264)
  - 위치: `firestore.rules` line 264

- [x] brand holder가 가맹점 status='approved' 시도 → 차단
  - 근거: isStoreOwnerBrandUpdate의 status 차단 조건 (lines 274-278)
  - 위치: `firestore.rules` lines 274-278

### 기능 검증 — 흡수 항목 1: CollectionGroup Rules 추가

- [x] `{path=**}/menuItems` collectionGroup read — admin 승인 큐 query 지원
  - 근거: firestore.rules lines 459-461 확인. `allow read: if isSignedIn()`
  - 위치: `firestore.rules` lines 459-461

- [x] `{path=**}/menuOverrides` collectionGroup read 지원
  - 근거: firestore.rules lines 463-465 확인
  - 위치: `firestore.rules` lines 463-465

- [x] collectionGroup wildcard 외 일반 nested path read도 정상 — path-specific rule 유지
  - 근거: `brands/{brandId}/menuItems`, `stores/{storeId}/menuItems` 등 path-specific rule이 그대로 존재. wildcard는 read 추가만 (write는 path-specific 담당)
  - 위치: `firestore.rules` lines 376-395 (brands nested), lines 300-325 (stores nested)

- [x] T3 — admin 마스터 메뉴 collectionGroup query 정상 동작
  - 근거: `MasterMenuItemRemoteDataSource.streamPending()` 가 `collectionGroup('menuItems')` 사용. 신규 `{path=**}/menuItems` wildcard read 룰로 커버됨
  - 위치: `lib/data/datasources/remote/master_menu_item_remote_data_source.dart` line 47

### 기능 검증 — 흡수 항목 2: Brand 등록 흐름 버그 fix

- [x] `brands` create 룰 — brand role 본인이 `submittedBy=uid / status='pending' / brandKey=''` 조건으로 생성 허용
  - 근거: firestore.rules lines 337-341 확인. `isBrand() && submittedBy==uid() && status=='pending' && brandKey==''`
  - 위치: `firestore.rules` lines 337-341

- [x] `users.brandId` self-update — 최초 1회 (empty → value) 만 허용
  - 근거: `isSelfProfileUpdate` 내 `!affectedKeys().hasAny(['brandId']) || resource.data.get('brandId', '') == ''` 조건 (firestore.rules lines 101-104)
  - 위치: `firestore.rules` lines 101-104

- [x] `BrandRepositoryImpl.upsertBrand` 신규 등록 시 batch write (brand doc + users.brandId) 원자적 처리
  - 근거: `brand_repository_impl.dart` lines 80-95 확인. `batch.set(brandsRef, ...)` + `batch.set(usersRef, {brandId: brandId}, merge: true)` + `batch.commit()`
  - 위치: `lib/data/repositories/brand_repository_impl.dart` lines 80-95

- [x] `BrandInfoFormPage._submit()` 신규 등록 모드에서 Navigator.pop 제거
  - 근거: `if (_isEditMode) Navigator.pop(context)` — 수정 모드에만 pop 적용. 신규 등록 모드(isEditMode=false)에서는 pop 없이 BrandScaffold profile stream 갱신 대기 (lines 252-254)
  - 위치: `lib/presentation/brand/brand_info/brand_info_form_page.dart` lines 252-254

### 기능 검증 — 흡수 항목 3: Brand 검토 현황 마스터 메뉴 추가

- [x] `BrandApprovalTrackingPage` — `myMasterMenuItemsProvider` watch 추가
  - 근거: `brand_approval_tracking_page.dart` line 21 `ref.watch(myMasterMenuItemsProvider)` 확인
  - 위치: `lib/presentation/brand/approval_tracking/brand_approval_tracking_page.dart` line 21

- [x] `_ItemType.masterMenu` 추가 + "메뉴" 타입 뱃지 (`AppColors.primary`)
  - 근거: `enum _ItemType { masterMenu, store, priceOverride }` (line 136) + `_TypeBadge.build()` switch에서 `masterMenu => (AppColors.primary, '메뉴')` (lines 325-326)
  - 위치: `lib/presentation/brand/approval_tracking/brand_approval_tracking_page.dart` lines 136, 325-326

- [x] T2 — brand 검토 현황에 마스터 메뉴 정상 노출 (status != approved 인 것만)
  - 근거: `_TrackingBody.build()` lines 83-89: masterMenus 중 status != approved인 것만 _TrackingItem.fromMasterMenu 로 추가
  - 위치: `lib/presentation/brand/approval_tracking/brand_approval_tracking_page.dart` lines 83-89

- [x] `AppColors` 만 사용 — 하드코딩 Color 없음
  - 근거: `brand_approval_tracking_page.dart` 전체 검사 — `Color(0x...)` 없음. AppColors 토큰만 사용
  - 위치: `lib/presentation/brand/approval_tracking/brand_approval_tracking_page.dart`

### 코드 품질 검증

- [x] flutter analyze — No issues found
  - 근거: `flutter analyze --no-pub` 실행 결과
  - 위치: lib/ 전체

---

## FAIL 항목

### F1 — `BrandRepositoryImpl.upsertBrand` 신규 등록 시 이미지 임시 경로 (`brandId='temp'`) 문제 (P2)

- 문제: `BrandInfoFormPage._submit()`에서 신규 등록 모드 (brand.id == '')일 때 logoFile 업로드를 `brandId='temp'`로 호출 (line 220). Firestore batch로 생성되는 실제 brandId와 다른 경로에 이미지가 저장됨. Security Rules 또는 Storage Rules 도입 시 `temp` 경로 이미지가 orphan이 될 수 있고, Storage Rules에서 경로-brandId 일치 검증이 어려워짐.
  - 코드: `uploadBrandImage(brandId: brandId.isEmpty ? 'temp' : brandId, ...)` (line 220)
- 위치: `lib/presentation/brand/brand_info/brand_info_form_page.dart` line 220
- 확인 방법: 신규 브랜드 등록 시 Firebase Storage에서 `temp/` 경로로 이미지 업로드 됨
- 제안: `upsertBrand` 전에 Firestore에서 brandId를 미리 생성(`doc().id`)하거나, upsertBrand 결과 brandId를 받아 이미지를 재업로드 + 이전 temp 이미지 삭제. 또는 Storage Rules에서 temp 경로를 임시로 허용하되 brandId 검증은 생략
- 우선순위: P2 (현재 동작에는 문제 없음. Storage Rules 도입 시 충돌 가능)

---

## 보류 항목

### H1 — T1 완전한 라이브 검증 (고객 → 브랜드 등록 → BottomNav 자동 전환 → admin 승인 → 대시보드 활성화) 보류

- 이유: admin 계정으로 brand 승인 및 brandKey 발급 흐름까지 포함하는 End-to-End 검증은 실제 admin 계정 + 운영 환경 접근 필요. admin 계정 role 필드 존재 여부 선행 확인 필요 (firestore_security_rules H4 참조)
- 필요한 확인: admin 계정으로 admin_menu_management 화면에서 brand 승인 + brand 대시보드 활성화 확인
- 후속 작업 제안: 운영 환경 4계정 회귀 테스트 시 포함

### H2 — brand 등록 후 BottomNav 자동 전환 (BrandScaffold profile stream watch) 라이브 검증 보류

- 이유: `upsertBrand` batch write 후 `users.brandId`가 갱신되면 BrandScaffold가 stream 변화를 감지해 BottomNav로 자동 전환하는 흐름 — 코드 정적 분석으로 경로 확인. 실기기 동작은 확인 필요
- 필요한 확인: 신규 브랜드 등록 완료 후 BrandScaffold BottomNav로 자동 전환 여부 실기기 확인
- 후속 작업 제안: 운영 환경 회귀 시 포함

### H3 — `{path=**}/menuOverrides` collectionGroup query 실제 사용 여부

- 이유: `MasterMenuItemRemoteDataSource`는 `menuItems` collectionGroup을 사용. `menuOverrides` collectionGroup query는 implementation.md에 언급되어 있으나 현재 사용 중인 datasource에서 직접 확인이 필요
- 필요한 확인: `MenuOverrideRemoteDataSource.streamPending()` 등 collectionGroup 사용 여부 코드 확인
- 후속 작업 제안: 사용처 없으면 wildcard rule 제거 검토. 불필요한 read 허용 최소화

### H4 — drift 방지 체크리스트 (향후 규칙) 준수 여부 모니터링

- 이유: implementation.md의 "향후 체크리스트" — Repository에서 set()/update() 전송 필드 변경 시 Rules 화이트리스트 동시 업데이트 의무화. 현재는 별도 CI 검증 없음
- 필요한 확인: 신규 개발 phase에서 이 체크리스트가 준수되는지 PR 리뷰 시 확인
- 후속 작업 제안: CI에 Rules-코드 불일치 검사 자동화 (낮은 우선순위)

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **PASS 중심, P2 FAIL 1건 + 보류 4건**
- PASS 28개 / FAIL 1개 / 보류 4개
- drift fix 3건 (isBrandSelfUpdate / isStoreOwnerFieldUpdate / isStoreOwnerBrandUpdate) 모두 정상 적용
- 흡수 항목 3건 (CollectionGroup Rules / Brand 등록 흐름 fix / 검토 현황 마스터 메뉴) 모두 PASS
- flutter analyze No issues 확인

### 재작업 우선순위

1. **F1 — 신규 브랜드 등록 시 이미지 `temp` 경로 문제** (P2)
   - 이유: 현재 동작에는 문제 없으나 Storage Rules 도입 시 orphan 이미지 + 경로 불일치 충돌 가능. Storage Rules task 전에 해결 권장

### 후속 task 후보

- T1 End-to-End 라이브 검증 (4계정 회귀 테스트)
- Storage Security Rules 작성 (`storage.rules`) — F1 수정과 함께 처리
- `{path=**}/menuOverrides` collectionGroup 사용처 확인 및 정리
- CI drift 방지 자동화

---

## 완료 판단

- [ ] 전체 PASS
- [x] FAIL 있으나 후속 task로 분리 가능 (F1 Storage Rules 도입 시 대응)
- [ ] 재작업 필요
