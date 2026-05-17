# 점주 매장 등록 기능 명세

## 개요
- **목적**: 점주(Owner) 역할 사용자가 앱에서 자신의 매장을 직접 등록할 수 있는 플로우 구축. 등록된 매장은 즉시 고객 홈 화면(주변/추천 섹션)에 노출됨.
- **배경**: 홈 화면 구현은 완료됐지만 `stores` 컬렉션 시드 데이터가 없어 실제 동작 확인이 불가. 사용자(개발자/기획자 본인)가 실제 점주처럼 가입해 매장을 올리고, 다시 고객으로 체험할 수 있도록 실사용 경로를 만든다.
- **영향 범위**:
  - 신규: 사용자 역할(Role) 체계, 점주 전용 화면(매장 등록/관리), `users` Firestore 컬렉션 신설
  - 수정: 로그인/회원가입 플로우(역할 저장), 라우팅(role 분기), `stores` 스키마(ownerId 추가)
- **디자인**: designer 에이전트에서 점주 화면 톤앤매너 확정 예정 (다크 테마 + 기존 Qradar 아이덴티티 계승)

---

## 요구사항

### 역할(Role) 체계
- [ ] `UserRole` enum 도입: `customer` / `owner` / `admin`
- [ ] Firestore `users/{uid}` 문서에 `role` 필드 저장. 최초 로그인 시 기본값 `customer`
- [ ] 로그인 후 역할에 따라 진입 화면 분기
  - `customer` → 기존 `ScaffoldWithNav` (홈/Qoin/주문/Log/더보기)
  - `owner` → 신규 `OwnerScaffold` (내 매장/주문접수/매출/더보기 — 이번 범위는 "내 매장"만 실제 구현)
  - `admin` → 이번 범위 외 placeholder

### 점주 역할 전환 플로우
- [ ] 일반 회원가입/로그인 후 `더보기 → 점주로 등록하기` 메뉴 진입
- [ ] 점주 전환 확인 다이얼로그: "점주로 전환하면 매장을 등록하고 관리할 수 있습니다. 계속하시겠어요?"
- [ ] 확인 시 `users/{uid}.role` 을 `owner`로 업데이트하고 `OwnerScaffold`로 재진입
- [ ] (향후) 점주 승인 절차 도입 대비: 필드 `ownerApprovedAt`, `ownerStatus` 등은 스키마만 준비하고 현 단계에선 즉시 승인

### 매장 등록 화면
- [ ] 최초 owner 전환 후 "내 매장"에 진입하면 `매장 등록하기` CTA 카드 노출
- [ ] 등록 폼 필드
  - 매장명 (필수, 1~30자)
  - 전화번호 (필수, 하이픈 포함 or 숫자만 정규화)
  - 카테고리 (필수, `MenuCategories.all`에서 다중 선택, 최소 1개)
  - 주소 (필수, 텍스트 입력 — 이번 MVP에선 주소 검색 API 미도입)
  - 위치 좌표 (필수, 기본값: 사용자 현재 위치, 추후 지도 선택 UI — 이번 MVP에선 "현재 위치 불러오기" 버튼 1회 클릭)
  - 대표 이미지 (선택, `image_picker` → Firebase Storage 업로드)
  - 운영시간 (선택, 요일별 open/close. MVP는 "매일 동일" 단일 구간만 지원)
  - 간단 소개 (선택, 최대 200자)
- [ ] 저장 버튼 탭 시 Firestore `stores` 문서 생성 + `ownerId = currentUid` 저장
- [ ] 저장 성공 → "내 매장" 상세 화면으로 진입

### 점주 "내 매장" 화면
- [ ] 등록된 매장 정보 카드 표시 (이미지, 매장명, 카테고리 뱃지, 주소, 전화번호, 운영시간)
- [ ] 매장 정보 수정 버튼 → 기존 등록 폼 재사용 (update 모드)
- [ ] 매장 삭제 버튼 (확인 다이얼로그 경유, Firestore `stores/{id}` delete + Storage 이미지 삭제)
- [ ] `averageScore` / `reviewCount` / `grade` 표시(읽기 전용 — 고객 리뷰로 갱신됨)

### 고객 체험 플로우와의 연결
- [ ] 점주가 등록한 매장은 `stores` 컬렉션 조회에 즉시 포함 → 홈의 주변/추천 섹션에 반영
- [ ] 별도 같은 디바이스/계정에서 `customer` 계정으로 가입하면 점주 등록 매장을 확인 가능

---

## 데이터 모델

### Entity 변경

**UserEntity (수정)**
기존 필드 유지 + 다음 추가:
- `role`: `UserRole` (default customer)
- `createdAt`: DateTime?

**UserRole (신규 enum)**
- `customer`, `owner`, `admin`
- String 매핑: `toString()` / `fromString(String)`

**StoreEntity (수정)**
기존 필드 + 다음 추가:
- `ownerId`: String (auth uid, non-null)
- `phone`: String
- `address`: String
- `description`: String? (소개)
- `businessHours`: `BusinessHours?`

**BusinessHours (신규 freezed)**
- `openTime`: String (e.g. "09:00")
- `closeTime`: String (e.g. "22:00")
- `closedDays`: List<int> (1=월, ..., 7=일) — MVP는 빈 배열

### Firestore 스키마

**users 컬렉션 (신규)**
```
users/{uid}
  - email: string?
  - displayName: string?
  - photoUrl: string?
  - provider: string          ("password" | "google.com" | "kakao" | "naver")
  - role: string              ("customer" | "owner" | "admin")
  - createdAt: timestamp
  - updatedAt: timestamp
```

**stores 컬렉션 (필드 추가)**
```
stores/{storeId}
  - ownerId: string           ★ 신규 (users/{uid} 참조)
  - name: string
  - phone: string             ★ 신규
  - address: string           ★ 신규
  - description: string?      ★ 신규
  - imageUrl: string?
  - location: GeoPoint
  - menuCategories: array<string>
  - businessHours: map?       ★ 신규 { openTime, closeTime, closedDays }
  - averageScore: number      (default 0, 리뷰 생성 시 Cloud Function으로 갱신 — 이번 범위 외)
  - reviewCount: number       (default 0)
  - createdAt: timestamp
  - updatedAt: timestamp
```

---

## 레이어 설계

### Domain
**Entities**
- `lib/domain/entities/user_role.dart` (enum + 매핑)
- `lib/domain/entities/user_entity.dart` (수정: role, createdAt 추가)
- `lib/domain/entities/store_entity.dart` (수정: ownerId, phone, address, description, businessHours)
- `lib/domain/entities/business_hours.dart` (freezed)

**Repository 인터페이스 (신규)**
- `lib/domain/repositories/user_repository.dart`
  - `getOrCreateUserProfile(UserEntity auth)` → UserEntity (최초 로그인 시 `users/{uid}` 생성)
  - `updateRole(String uid, UserRole role)` → void
  - `watchCurrent(String uid)` → Stream<UserEntity?>
- `lib/domain/repositories/store_repository.dart` (수정)
  - `createStore(StoreEntity)` → String (storeId 반환)
  - `updateStore(StoreEntity)` → void
  - `deleteStore(String storeId)` → void
  - `watchByOwner(String ownerId)` → Stream<StoreEntity?> (점주는 1매장 가정)

**UseCases (신규)**
- `lib/domain/usecases/upgrade_to_owner_use_case.dart`
- `lib/domain/usecases/register_store_use_case.dart`
- `lib/domain/usecases/update_store_use_case.dart`
- `lib/domain/usecases/delete_store_use_case.dart`
- `lib/domain/usecases/watch_my_store_use_case.dart`

### Data
**Models (DTO) — 신규/수정**
- `lib/data/models/user_model.dart` (신규, Firestore 매퍼)
- `lib/data/models/store_model.dart` (수정: 신규 필드 매핑)
- `lib/data/models/business_hours_model.dart` (신규)

**DataSources**
- `lib/data/datasources/remote/user_remote_data_source.dart` (신규, Firestore `users` CRUD)
- `lib/data/datasources/remote/store_remote_data_source.dart` (수정: create/update/delete/watchByOwner)
- `lib/data/datasources/remote/storage_data_source.dart` (신규, Firebase Storage 이미지 업로드/삭제)

**Repository 구현체**
- `lib/data/repositories/user_repository_impl.dart` (신규)
- `lib/data/repositories/store_repository_impl.dart` (수정)

### Presentation
**Providers (신규 묶음)**
- `lib/presentation/owner/providers/owner_providers.dart`
  - `myStoreProvider` (StreamProvider)
  - UseCase Provider 묶음
- `lib/presentation/customer/auth/providers/user_profile_provider.dart`
  - `currentUserProfileProvider` (StreamProvider, role 포함)
  - 로그인 성공 후 `getOrCreateUserProfile` 자동 호출

**Pages (신규)**
- `lib/presentation/owner/owner_scaffold.dart` (점주 전용 Scaffold — 탭 2~3개)
- `lib/presentation/owner/my_store/my_store_page.dart` (매장 상세/CTA)
- `lib/presentation/owner/my_store/store_form_page.dart` (등록/수정 공통 폼)
- `lib/presentation/owner/my_store/widgets/store_form_field.dart` (공통 입력 위젯)
- `lib/presentation/owner/my_store/widgets/category_multi_select.dart`
- `lib/presentation/owner/my_store/widgets/image_picker_tile.dart`
- `lib/presentation/customer/more/upgrade_to_owner_section.dart` (더보기 → 점주 전환 메뉴)

**라우팅**
- `lib/presentation/common/role_router.dart` (신규)
  - role 에 따라 `ScaffoldWithNav` / `OwnerScaffold` 반환
  - 로그인 완료 후 `main.dart` / `LoginPage` 가 이 위젯으로 replace

**Placeholder 수정**
- `lib/presentation/customer/more/more_page.dart` — "점주로 등록하기" 항목 추가

### Core
- `lib/core/constants/firestore_paths.dart` (신규 권장) — `users`, `stores`, `reviews` 경로 상수화
- `lib/core/utils/phone_formatter.dart` (신규, 전화번호 정규화)

---

## 데이터 흐름

### 점주 전환
```
더보기 → 점주로 등록하기
  ↓
[확인 다이얼로그]
  ↓ (확인)
UpgradeToOwnerUseCase(uid)
  → UserRepository.updateRole(uid, UserRole.owner)
  → users/{uid}.role = "owner"
  ↓
currentUserProfileProvider 갱신 (StreamProvider)
  ↓
RoleRouter 가 OwnerScaffold 로 전환
```

### 매장 등록
```
OwnerScaffold → MyStorePage
  ↓ (myStoreProvider.data == null)
"매장 등록하기" CTA
  ↓
StoreFormPage (create 모드)
  ↓ (사용자 입력 + 이미지 선택)
RegisterStoreUseCase
  → (이미지 있으면) StorageDataSource.upload → imageUrl
  → StoreRepository.createStore(entity)
  → stores/{storeId} 문서 생성 (ownerId = currentUid)
  ↓
myStoreProvider Stream 가 새 매장 emit
  ↓
MyStorePage 가 매장 상세 렌더링
```

### 고객 홈에 반영
```
stores 컬렉션에 새 문서 append
  ↓ (기존 홈의 nearbyStoresProvider / filteredStoresProvider 가 재조회 시 포함)
```

---

## 에러 처리

| 케이스 | 처리 |
|--------|------|
| 폼 유효성 실패 | 필드별 에러 메시지 inline 표시 |
| 위치 좌표 미획득 | "현재 위치를 불러와주세요" 안내 + 저장 버튼 비활성 |
| 이미지 업로드 실패 | SnackBar + 이미지 없이 저장할지 선택 옵션 |
| Firestore 쓰기 실패 | 에러 다이얼로그 + 재시도 버튼 |
| `users/{uid}` 생성 실패 | 로그인 후 홈 진입 시 Splash 단계에서 재시도 루프(최대 3회) |
| 점주 전환 중 role 롤백 필요 | Firestore update 실패 시 이전 role 유지, SnackBar |

---

## 필요한 패키지

- `firebase_storage`: 매장 이미지 업로드
- `image_picker`: 갤러리/카메라에서 이미지 선택
- (이미 설치됨) `cloud_firestore`, `firebase_auth`, `freezed`, `hooks_riverpod`

---

## 범위 외 (차기 과제로 분리)

- 점주 주문 접수/거절/완료 화면
- 매출 조회 대시보드 (시간대/일/월/연)
- 리뷰 평균/등급 자동 갱신 Cloud Function
- 주소 검색 API(카카오/네이버 주소) 연동
- 지도 선택 UI로 좌표 선정
- 운영시간 요일별 개별 설정 UI
- 점주 승인 절차(현 단계는 즉시 승인)
- 관리자(admin) 콘솔

---

## 자율 결정 사항 (설계자 판단 — 사용자 확인 요망)

1. **점주 전환 UX**: 회원가입 시 역할 선택 대신 "더보기 → 점주로 등록하기" 단일 진입점을 채택. 이유: 일반 사용자의 첫 온보딩이 단순해지고, 본인이 원할 때 전환할 수 있음. 앱 첫 인상이 "커피 주문 앱"이라는 일관성을 유지.
2. **매장 1개 제한(MVP)**: 한 점주 계정은 1 매장만 등록 가능. 이유: UX 단순화. 멀티 매장은 체인 기획 확정 후 추가.
3. **즉시 승인**: 현 단계에서는 `role = owner` 로 set 되는 즉시 매장 등록 가능. 스팸/검수 이슈 발생 전까지는 승인 절차를 미룸. 스키마에 `ownerStatus` 필드 여지를 남김.
4. **위치 좌표 획득 방식(MVP)**: 지도 선택 UI 대신 "현재 위치 불러오기" 버튼 1회 클릭 → 점주가 매장 앞에서 등록한다고 가정. 추후 지도 drag pin 도입.
5. **운영시간(MVP)**: 매일 동일 구간 1개만. 휴무일/시간대별 휴게는 차기.
6. **점주 Scaffold 탭**: MVP는 `내 매장` 단일 탭 + `더보기`. `주문 접수`, `매출` 탭은 placeholder로만 배치.

---

## 작업 분배

### designer (우선)
- 점주 OwnerScaffold 톤: 고객 Midnight Navy와 구분되는 포인트(예: Gold accent 강조) 여부 결정
- `MyStorePage` 빈 상태(등록 전) CTA 카드 디자인
- `StoreFormPage` 입력 폼 다크 테마 스타일 가이드
- 점주 전환 확인 다이얼로그 톤
- 산출물: `docs/tasks/owner_store_registration/design.md`

### developer (디자인 확정 후)
- Domain: UserRole, UserEntity/StoreEntity 수정, BusinessHours, UserRepository/StoreRepository 확장, UseCase 5종
- Data: UserModel, BusinessHoursModel, UserRemoteDataSource, StorageDataSource, Repository 구현체 업데이트
- Presentation: OwnerScaffold, MyStorePage, StoreFormPage + 위젯, UpgradeToOwnerSection, RoleRouter, user_profile_provider
- 수정: `main.dart` / `LoginPage` → `RoleRouter` 경유 라우팅, `MorePage` 에 점주 전환 메뉴, `StoreModel`/`StoreRepository` 필드/메서드 확장
- pubspec: `firebase_storage`, `image_picker` 추가
- Firestore 보안 규칙 초안: `users/{uid}` 본인만 쓰기, `stores/{id}` ownerId 일치 시 쓰기 (개발 단계는 완화)
- 산출물: 코드 + `docs/tasks/owner_store_registration/implementation.md`

### tester (구현 후)
- 기능 검증 (회원가입 → 점주 전환 → 매장 등록 → 고객 홈 반영)
- 아키텍처 검증 (Repository 패턴 유지, role 분기 정상)
- 에러 케이스(유효성, 네트워크 실패, 이미지 업로드 실패)
- 산출물: `docs/tasks/owner_store_registration/test_report.md`

---

## 승인 요청
상기 자율 결정 6건 + 작업 분배안에 대해 사용자 승인 후 designer → developer → tester 순서로 진행.
