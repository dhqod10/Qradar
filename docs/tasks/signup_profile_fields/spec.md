# signup_profile_fields 기능 명세

이메일 회원가입 시 **이름·전화번호**를 수집하고, 홈 화면 인사말에 이름을 표시한다.

---

## §0 사용자 확인 필요 결정사항 (권고 포함)

> 아래는 설계자가 권고안을 정해두었다. 사용자가 짧게 "그대로 / 수정" 만 답하면 된다.
> 설계 본문은 **권고안 기준**으로 작성되어 있다. 결정이 바뀌면 해당 절만 수정한다.

| # | 결정할 것 | 권고안 | 근거 / 트레이드오프 |
|---|---|---|---|
| **D1** | **이름 필수 여부** | **필수** | 홈 인사말·운영 식별의 핵심 목적. 소셜은 이미 이름이 들어오므로 형평상 이메일도 필수가 자연스럽다. 빈 이름이면 인사말이 'Qrator' 폴백으로 떨어져 기능 목적이 반감. |
| **D2** | **전화번호 필수 여부** | **필수 (단순 입력)** | 운영 식별(연락·본인확인)의 실익. 단, 가입 마찰이 커진다는 반론 있음 → **"선택 입력"으로 낮춰도 설계 변경 없음**(폼 검증만 완화). 런칭 전 테스트 규모면 필수로 받아 데이터를 모으는 편을 권고. |
| **D3** | **전화번호 본인인증 수준** | **단순 입력 + 형식 검증만** (SMS 인증 **안 함**) | SMS 본인인증(Firebase Phone Auth)은 비용·구현·UX 부담이 크고 MVP 목적(식별/인사말)엔 과함. 형식 검증(숫자/하이픈, 10~11자리)만. 진짜 본인확인이 필요한 시점(정산·실명 등)에 별도 기능으로. |
| **D4** | **기존 유저(이름 없는) 입력 유도 방식** | **비차단 soft prompt** (선택 입력) | 이미 가입한 유저의 이름/전화는 **백필 불가**(본인 정보). 다음 진입 시 홈 상단에 1회성 안내 배너/카드로 입력 유도하되 **강제·차단 아님**. 과도설계 방지를 위해 **이번 범위에서는 "비범위(후속 task)"로 미루는 것도 가능** → D4-a 참고. |
| **D4-a** | D4를 이번에 할지 | **이번 범위에서 제외(후속)** 권고 | 신규 가입 수집이 핵심. 기존 유저 유도 UX는 별 task로 분리하면 이번 작업이 가벼워진다. **단, Rules/모델의 phone update 경로는 이번에 열어둔다**(나중 유도 때 추가 배포 불필요). |
| **D5** | **소셜(kakao/naver/google) 가입도 전화번호 받을지** | **이번 범위 제외** | 소셜은 provider가 **이름을 이미 제공**(저장됨)하므로 이름 목적은 충족. 전화번호는 소셜 provider가 안 주므로 별도 입력 UX가 필요 → D4의 soft prompt와 동일 성격. 소셜 전화 수집은 D4와 묶어 후속으로. |

> **이름의 저장 위치는 설계자가 확정했다(질문 아님)**: 신규 필드를 만들지 않고 **기존 `displayName` 필드를 재사용**한다. 이미 전 레이어와 홈 인사말이 `displayName`을 쓰고 있어 변경 최소화·일관성 최대. 자세한 근거는 §데이터 모델 참고.

---

## 개요

- **목적**: (a) 이메일 회원가입자도 홈 화면에 본인 이름이 표시되게 하고, (b) 운영/관리 측면에서 전화번호로 유저를 식별할 수 있게 한다.
- **작업 유형**: 기존 기능 수정 (이메일 가입 흐름 확장) + Data 스키마 1필드 추가(`phone`)
- **영향 범위**:
  - **화면**: 이메일 가입 폼(`email_signup_page.dart`)에 이름·전화 입력 추가. 홈 인사말은 **이미 `displayName`을 표시**하므로 로직 변경 없음(이름이 채워지면 자동 반영).
  - **Domain**: `UserEntity`에 `phone` 추가. `SignUpWithEmailUseCase` / `AuthRepository.signUpWithEmail` 시그니처에 `name`·`phone` 추가.
  - **Data**: `UserModel`에 `phone` 추가(freezed, `fromFirestore` / `toFirestoreForCreate` / `fromEntity`). 이메일 가입 경로가 `displayName`·`phone`을 `users/{uid}` create payload에 싣도록 연결.
  - **Presentation**: `AuthNotifier.signUpWithEmail`에 `name`·`phone` 파라미터 전파.
  - **공통 컴포넌트**: 전화번호 형식 검증 유틸(간단) — 기존 검증 패턴 재사용.
  - **라우팅**: 변경 없음(가입 성공 → `RoleRouter` → `ScaffoldWithNav` 기존 흐름 유지).
  - **권한 / 환경 설정**: `firestore.rules` `users` 블록 — `isSelfProfileUpdate` 화이트리스트에 `phone` 추가. create는 현재 화이트리스트 방식이 아니라 phone이 이미 허용되나, **명시적으로 phone 허용을 문서화**. `data_ownership.md §2.1` 갱신.
- **비범위**:
  - SMS/Phone Auth 본인인증 (D3)
  - 기존 유저 입력 유도 UX (D4/D4-a — 후속 task 권고)
  - 소셜 가입자 전화번호 수집 (D5 — 후속)
  - 전화번호를 활용한 알림/마케팅/검색 기능
  - 이름/전화 변경(수정) 전용 화면 — 이번엔 Rules/모델 경로만 열어두고 UI는 만들지 않음

---

## 요구사항

### 기능 요구사항

- [ ] 이메일 회원가입 폼에서 이름을 입력받는다(D1: 필수).
- [ ] 이메일 회원가입 폼에서 전화번호를 입력받는다(D2: 필수, 단순 입력).
- [ ] 입력한 이름을 `users/{uid}.displayName`에, 전화번호를 `users/{uid}.phone`에 저장한다.
- [ ] 저장된 이름이 홈 화면 인사말(`"{name}님 어서오세요."`)에 표시된다.
- [ ] 전화번호는 형식 검증만 수행한다(본인인증 없음 — D3).
- [ ] (경로만) 기존 유저가 나중에 `phone`/`displayName`을 수정할 수 있도록 Rules/모델 update 경로를 연다. UI는 비범위.

### UI 요구사항 (designer 산출물로 상세화)

- [ ] 이메일 가입 폼: 이름 TextField, 전화번호 TextField 추가(기존 이메일/비번/비번확인과 일관된 스타일).
- [ ] 전화번호 입력은 숫자 키패드(`keyboardType: phone`), 하이픈 자동/허용 여부는 designer가 정함.
- [ ] 검증 실패 시 필드별 인라인 에러 문구(이름 빈값, 전화 형식오류 등).
- [ ] 색상은 `AppColors`만 사용.

### 상태 요구사항

- [ ] loading: 가입 버튼 제출 중 버튼 비활성/로딩 인디케이터(기존 패턴 유지).
- [ ] error: 이메일 중복·네트워크 실패 등은 기존 `auth_error_message` 경로로 처리. 신규 — 이름/전화 형식 오류는 제출 전 클라이언트 검증.
- [ ] empty: 홈 인사말에서 이름이 비면 기존 폴백(email prefix → 'Qrator') 유지.

---

## 데이터 모델

### 이름은 신규 필드를 만들지 않는다 — `displayName` 재사용

- 현재 `UserEntity` / `UserModel` / `users/{uid}` / 홈 헤더가 모두 **`displayName`**을 "표시 이름"으로 이미 사용 중이다.
  - 소셜 로그인은 provider 이름(kakao nickname / naver name / google displayName)을 `displayName`에 저장한다.
  - 홈 헤더(`home_header.dart`)는 `displayName`이 비어있지 않으면 인사말에 쓴다.
- 이메일 가입자는 Firebase가 `displayName`을 주지 않아 **빈 채로 문서가 생성**되는 것이 유일한 갭이다.
- 따라서 **이메일 가입 폼의 "이름"을 `displayName`에 채운다.** 별도 `name` 필드를 추가하면 홈/소셜과 이중화되어 일관성이 깨진다.

### Entity — `UserEntity` (lib/domain/entities/user_entity.dart)

추가 필드:

| 필드 | 타입 | 설명 |
|---|---|---|
| `phone` | `String?` (nullable) | 전화번호. 없을 수 있음(소셜/기존 유저). 형식은 저장 전 정규화(숫자만 또는 하이픈 포함 — developer가 데이터소스에서 일관 처리) |

- `displayName`은 **이미 존재**(nullable) — 변경 없음.

### DTO / Model — `UserModel` (lib/data/models/user_model.dart)

- `phone: String?` 추가.
- `fromFirestore`: `phone` 파싱 추가(부재 시 null).
- `toFirestoreForCreate()`: payload에 `displayName`, `phone` 포함(기존에 `displayName`은 이미 포함). **phone이 null/빈값이면 키를 생략**(불필요한 빈 필드 쓰기 방지).
- `fromEntity`: `phone` 복사.
- (선택) update용 partial payload — 기존 `fillProfile` 패턴과 유사하게, 후속 "수정 UI"에서 쓸 수 있도록 developer가 최소 메서드만 준비(이번엔 호출부 없음 — 비범위이므로 메서드 스텁 불필요, Rules만 열어둠).

### Firestore 문서 — `users/{uid}`

```
users/{uid}
  displayName: "홍길동"     ← 이메일 가입 시 폼 입력(기존 필드)
  phone: "01012345678"      ← 신규 (nullable)
  email, photoUrl, provider, role, createdAt, ...  (기존)
```

- **PII 저장 위치 판단**: `users/{uid}`의 `read`는 **`self(uid) OR admin`**뿐이다(공개 아님). 따라서 전화번호를 `users/{uid}`에 직접 저장해도 노출되지 않는다.
  - 참고: `brands/{id}`는 부모 문서 read가 `isSignedIn()`(사실상 공개)이라 PII를 `private/profile` 서브컬렉션으로 분리해야 했으나(`data_ownership.md §2.7a`), `users`는 그럴 필요가 없다. **별도 private 서브컬렉션을 만들지 않는다**(과도설계 방지).

---

## 레이어 설계

### Domain

- **Entity**: `UserEntity` — `phone` 필드 추가.
- **UseCase**: `SignUpWithEmailUseCase.call({email, password, name, phone})` — 파라미터 추가 후 repository에 위임.
- **Repository Interface**: `AuthRepository.signUpWithEmail({email, password, name, phone})` — 시그니처 확장.
  - 참고: `users/{uid}` 문서 생성은 `UserRepository.getOrCreateUserProfile` 경로다. 가입 시 이름/전화를 거기까지 전달하는 방식은 §데이터 흐름 참조.

### Data

- **Model / DTO**: `UserModel`에 `phone` 추가(위 §데이터 모델).
- **DataSource**:
  - `AuthRemoteDataSource.signUpWithEmail`: `createUserWithEmailAndPassword` 후 반환하는 `UserModel`에 **폼에서 받은 `displayName`·`phone`을 실어 반환**(현재는 Firebase가 준 null displayName을 그대로 둠).
  - `UserRemoteDataSource.createIfAbsent`: `toFirestoreForCreate()`가 `displayName`/`phone`을 쓰도록(모델 변경으로 자동 반영).
- **Repository Impl**:
  - `AuthRepositoryImpl.signUpWithEmail`: 파라미터 전파.
  - `UserRepositoryImpl.getOrCreateUserProfile`: 신규 문서 생성 시 authUser(UserEntity)의 `displayName`/`phone`이 create payload에 반영됨(기존 fromEntity 경로 재사용).

### Presentation

- **Provider**: `AuthNotifier.signUpWithEmail({email, password, name, phone})` — UseCase 호출에 파라미터 전달.
- **Page**: `email_signup_page.dart` — 이름/전화 TextField 추가, 제출 시 검증 후 provider 호출.
- **Widget**: 홈 인사말(`home_header.dart`) — **변경 없음**(displayName 자동 반영). designer는 가입 폼 레이아웃만 다룬다.

---

## 데이터 흐름

```text
EmailSignupPage (이름·전화·이메일·비번 입력, 클라이언트 검증)
  → AuthNotifier.signUpWithEmail(email, password, name, phone)
  → SignUpWithEmailUseCase.call(...)
  → AuthRepository.signUpWithEmail(...)
  → AuthRemoteDataSource: FirebaseAuth.createUserWithEmailAndPassword
        → UserModel(uid, email, displayName=name, phone=phone, provider='email')
        → UserEntity 반환
  → (가입 성공 후) RoleRouter → currentUserProfileProvider
  → UserRepository.getOrCreateUserProfile(authUser)
  → UserRemoteDataSource.createIfAbsent(toFirestoreForCreate: {displayName, phone, ...})
  → users/{uid} 문서 생성
  → 홈 HomeHeader 가 displayName 으로 인사말 렌더 (기존)
```

> developer는 "폼에서 받은 name/phone이 어느 지점에서 `users/{uid}` create payload에 실리는지"를 반드시 확인한다. 현재 users 생성은 Auth datasource가 아니라 **`getOrCreateUserProfile → createIfAbsent`**에서 일어나므로, name/phone이 `UserEntity`에 실려 그 경로까지 전달되어야 한다(위 흐름 참조).

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 이름 빈값 (D1 필수일 때) | 제출 전 인라인 에러, 가입 차단 |
| 전화번호 빈값 (D2 필수일 때) | 제출 전 인라인 에러, 가입 차단 |
| 전화번호 형식 오류 | 제출 전 인라인 에러(숫자 10~11자리 등), 가입 차단 |
| 이메일 중복 / 약한 비번 / 네트워크 | 기존 `auth_error_message` 변환 경로 유지 |
| 가입은 됐으나 users 문서 생성 실패 | 기존 `getOrCreateUserProfile` 재시도/폴백 경로 유지(이번 범위서 신규 설계 안 함) |
| 홈 인사말에 이름 없음(소셜/기존 유저) | 기존 폴백(email prefix → 'Qrator') 유지 |

---

## 이력 / 감사 추적 (audit_trail.md §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값을 바꾸는가? → 설정 변경 이력 필요? | **아니오.** `displayName`/`phone`은 **본인 소유 프로필 PII**일 뿐, 돈/권한/정책 계수가 아니다. `brandId`처럼 자원 트리 쓰기 권한을 여는 값도 아니다. → **설정 변경 이력 불필요.** (거래 이력과 혼동 금지 — 해당 없음) |
| 2 | 덮어쓰기로 사라지는 값이 있는가? | 가입 시 최초 1회 기록. 수정 UI는 비범위. 추후 수정 기능을 만들 때 "프로필 변경 이력"이 필요한지 그 task에서 재판단(현재는 과도설계 회피, A2와 유사하게 미설계). |
| 3 | 거래/기록 문서가 정책 값을 참조만 하는가? | 해당 없음(거래 문서 아님). |
| 4 | "누가"가 기록되는가? | 본인이 본인 문서를 쓰는 self-write. `uid`가 문서 주인. 운영자 행위 아님 → 별도 행위자 기록 불필요. |
| 5 | 일괄 처리(batch)가 있는가? | 없음. 기존 유저 백필은 **불가**(본인 정보라 서버가 생성 못 함) — D4 soft prompt로만. |
| 6 | CF 로그에 의존하는가? | 아니오. |
| 7 | 권한 판정 필드의 create/update 양쪽 확인 | `phone`은 권한 판정 입력이 아니다. 단 Rules 변경이 있으므로 **정상 payload 회귀 테스트**(가입 create가 여전히 통과, phone self-update가 통과)를 tester 하네스에 둔다. |

**개인정보 수집 비고(최소수집·동의)**: 이름·전화는 개인정보다. 과도설계는 피하되, 가입 폼에 **수집 목적 1줄 고지**(예: "주문 식별 및 서비스 제공을 위해 사용됩니다") 및 약관/개인정보 동의 체크 존재 여부를 designer/기획이 확인한다. **미성년자 정책(B 범위)과의 접점**: 전화번호 수집은 연령 확인과 무관하게 진행하되, 향후 B 범위 미성년자 정책이 확정되면 수집 항목·동의 흐름을 재검토해야 한다(이번 범위에서는 정책 미확정이므로 수집만, 연령 게이트는 비범위).

---

## firestore.rules 변경

`match /users/{userId}`:

1. **create**: 현재 화이트리스트 방식이 아니라 `role=='customer'` 강제 + `brandId`/`qoinBalance` 포함 금지뿐이므로 `phone`은 **이미 허용**된다. 별도 변경 불필요하나, **phone 허용을 주석/문서로 명시**한다.
2. **update** (`isSelfProfileUpdate`의 `onlyChangedFields`): 현재 화이트리스트에 `displayName`은 **있고** `phone`은 **없다**. → **`'phone'`을 화이트리스트에 추가**한다(후속 수정 UI가 추가 배포 없이 동작하도록 — D4-a 근거).
3. 회귀 가드: 기존 가입 create payload(`displayName` 포함 + 이제 `phone` 포함)가 여전히 통과해야 한다(tester 하네스).

`data_ownership.md §2.1` 갱신: update 화이트리스트에 `phone` 추가 반영, create에서 `phone` 허용 명시.

---

## 작업 분배

### designer

- **UI 변경 필요**: 예 (이메일 가입 폼).
- **산출물**: `docs/tasks/signup_profile_fields/design.md`
- **전달 사항**:
  - 이메일 가입 폼에 이름·전화 TextField 추가. 기존 폼 필드 스타일/간격과 일관.
  - 전화번호 입력: 숫자 키패드, 하이픈 처리 방식(자동 포맷 여부) 결정.
  - 필드별 인라인 에러 표기 패턴.
  - 수집 목적 고지 문구 위치(1줄)·동의 체크 필요 여부 확인.
  - **홈 인사말은 변경 없음**(참고만).
  - `AppColors`만 사용.

### developer

- **산출물**: `docs/tasks/signup_profile_fields/implementation.md`
- **구현 항목**:
  - `UserEntity` / `UserModel`에 `phone` 추가(freezed build_runner).
  - `signUpWithEmail` 체인(Page → Provider → UseCase → AuthRepository → DataSource)에 `name`·`phone` 전파.
  - 이메일 가입 시 `displayName`=입력 이름, `phone`=입력 전화가 `users/{uid}` create payload에 실리는 경로 연결(`getOrCreateUserProfile → createIfAbsent`).
  - 전화 형식 검증(클라이언트).
  - `firestore.rules` update 화이트리스트에 `phone` 추가, create phone 허용 주석.
  - `data_ownership.md §2.1` 갱신.
- **재사용할 기존 구조**: `displayName` 전 레이어 경로, `fillProfile`/`createIfAbsent` 패턴, `auth_error_message`, 기존 폼 검증 패턴.
- **주의할 레이어 규칙**: Firebase는 data 레이어에서만. presentation/domain에서 FirebaseAuth/Firestore 직접 import 금지. 색상 `AppColors`만.

### tester

- **산출물**: `docs/tasks/signup_profile_fields/test_report.md`
- **주요 검증 기준**:
  - 이메일 가입 시 이름·전화 입력 → `users/{uid}`에 `displayName`/`phone` 저장 확인.
  - 가입 직후 홈 인사말에 입력한 이름 표시.
  - 전화 형식 오류/빈값 시 가입 차단(D1/D2 결정 반영).
  - 이메일 중복 등 기존 에러 경로 회귀.
  - 소셜 가입자: 기존대로 이름 저장·인사말 표시(회귀).
- **반드시 확인할 예외 케이스**:
  - firestore.rules 회귀: 기존 가입 create payload 통과(하네스), phone self-update 통과, 그 외 필드 변조 거부.
  - phone null(소셜/미입력) 시 홈 폴백 정상.
  - phone 키 생략(빈값) 처리.

---

## 완료 기준

- [ ] §0 결정사항이 사용자 확인으로 확정됨
- [ ] 요구사항이 모두 구현 또는 보류 사유 명시됨
- [ ] `design.md` 작성 완료(가입 폼 UI)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료
- [ ] firestore.rules / data_ownership.md 갱신 반영
- [ ] FAIL 항목이 없거나 후속 작업으로 분리됨
