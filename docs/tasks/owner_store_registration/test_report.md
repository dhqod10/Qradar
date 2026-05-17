# 점주 매장 등록 테스트 리포트

## 테스트 일시
- 2026-04-19

## 전체 결과
- PASS: 24개
- FAIL: 0개
- 보류: 4개 (spec에서 명시적으로 허용/차기 과제로 지정)

---

## 상세 결과

### PASS 항목

#### 기능 검증 (spec.md 기준)

- [x] **UserRole enum 도입** — `lib/domain/entities/user_role.dart` customer/owner/admin + fromString/asString
- [x] **users/{uid} role 필드** — `UserModelFirestoreX.toFirestoreForCreate` + `UserModelFactory.fromFirestore` 에서 role 매핑
- [x] **최초 로그인 기본값 customer** — `UserEntity` 의 `@Default(UserRole.customer)` + `getOrCreateUserProfile` 에서 인증 사용자 → role 미설정 시 customer 로 저장
- [x] **role 기반 진입 화면 분기** — `RoleRouter` 가 `currentUserProfileProvider` 구독하여 OwnerScaffold / ScaffoldWithNav 전환
- [x] **더보기 → 점주 등록 진입점** — `UpgradeToOwnerSection` 이 고객 MorePage 상단에 노출
- [x] **점주 전환 확인 다이얼로그** — `UpgradeToOwnerDialog` 에 "점주로 전환" / "취소" 버튼과 안내 문구
- [x] **users/{uid}.role = "owner" 업데이트** — `UpgradeToOwnerUseCase` → `UserRepository.updateRole`
- [x] **role 변경 시 OwnerScaffold 재진입** — Firestore stream 갱신 → currentUserProfileProvider → RoleRouter 자동 전환
- [x] **매장 미등록 시 CTA 카드** — `MyStorePage._EmptyStateView` (Accent 글로우 + "매장 등록하기" 버튼)
- [x] **등록 폼 필수 필드** — 매장명(max 30) / 전화번호 / 주소 / 카테고리(≥1) / 위치 검증 (`_isValid`)
- [x] **위치 좌표 획득** — `LocationPickerTile` + PrePermissionDialog + CheckLocationPermissionUseCase 재사용
- [x] **대표 이미지 업로드** — image_picker → `StorageDataSource.uploadStoreImage` → downloadUrl
- [x] **운영시간 (매일 동일)** — `_BusinessHoursPicker` 단일 open/close 구간 + showTimePicker 다크 테마
- [x] **소개 (200자)** — `_FormField(maxLength: 200)`
- [x] **저장 시 ownerId = currentUid** — `_submit` 에서 `authProvider.asData?.value.uid` 를 주입
- [x] **저장 성공 후 상세 화면** — myStoreProvider 스트림 갱신 → `_StoreDetailView` 자동 렌더링
- [x] **매장 정보 수정** — `StoreFormPage(existing: store)` update 모드 + `UpdateStoreUseCase`
- [x] **매장 삭제** — `_DangerZone` 확인 다이얼로그 + Storage 이미지 삭제 + `DeleteStoreUseCase`
- [x] **averageScore / reviewCount / grade 표시** — `_StoreMetricsSection` 3열 Row (읽기 전용)
- [x] **고객 홈에 반영** — 동일 `stores` 컬렉션을 공유, 홈의 `nearbyStoresProvider.invalidate` 는 pull-to-refresh로 가능

#### 아키텍처 검증

- [x] **domain 레이어에 Firebase SDK import 없음** — grep 결과 0건
- [x] **presentation 레이어에 Firebase SDK import 최소** — 신규 파일은 모두 0건 (기존 `auth_provider.dart` 만 예외, 보류 항목 참고)
- [x] **레이어 의존 방향 준수** — Repository 인터페이스는 domain, 구현체는 data, UseCase는 domain-only import

#### 코드 품질 검증

- [x] **flutter analyze** — `No issues found! (ran in 3.1s)`
- [x] **build_runner 성공** — 8 outputs 생성, 실패 없음

---

### FAIL 항목

없음.

---

### 보류 항목

- [ ] **`auth_provider.dart` 의 presentation-레이어 Firebase import**
  - 위치: `lib/presentation/customer/auth/auth_provider.dart:1`
  - 이유: 이번 과제 이전에 존재하던 레거시. AuthNotifier 의 `build()` 가 `FirebaseAuth.instance.currentUser` 를 직접 조회합니다. 본 과제 범위 밖이지만 장기적으로 AuthRepository 로 이전 필요.

- [ ] **`#F87171` (에러 색상) 하드코딩**
  - 위치: `lib/presentation/owner/my_store/my_store_page.dart:528,535,566`
  - 이유: design.md 에서 "에러 색상은 이번에도 하드코딩(`#F87171`): `AppColors.error` 승격은 차기 디자인 PR에서 일괄" 로 명시 허용.

- [ ] **폼 필드별 inline 에러 메시지**
  - 위치: `lib/presentation/owner/my_store/store_form_page.dart`
  - 이유: 버튼 비활성 + placeholder 안내로 대체. implementation.md 자율결정 #6 에서 차기 개선으로 분리.

- [ ] **실기기 동작 검증**
  - 이유: 정적 분석(analyze) 레벨에서만 통과. Firestore `users/stores` 문서 실제 생성, 이미지 업로드 라운드트립, role stream 재갱신 후 RoleRouter 전환 타이밍, geolocator 권한 다이얼로그 노출은 실기기/에뮬레이터 실행 필요. implementation.md "실기기 확인 권장 항목" 6건 참고.

---

## 설계자 전달 메시지

- 정적 분석·spec 매핑 기준 전 항목 **PASS**. FAIL 없음.
- 보류 4건은 모두 spec/design 에서 사전에 허용된 항목이거나 기존 레거시로 이번 범위 밖.
- 다음 단계: 사용자 실기기 검증 권장. 다음 항목 우선:
  1. 회원가입 후 Firestore `users/{uid}` 자동 생성 + role=customer 확인
  2. 점주 전환 플로우 전후 RoleRouter 화면 전환
  3. 매장 등록 (이미지 업로드 포함) → 고객 홈 pull-to-refresh 반영
  4. 매장 수정/삭제 왕복
- 실기기 검증에서 이슈 발견 시 spec 재검토 및 developer 재호출 권장.
