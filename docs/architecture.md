# Qradar 프로젝트 아키텍처

이 문서는 Qradar 프로젝트의 구조, 레이어 책임, 파일 배치, 네이밍 규칙을 정의한다.

Claude Code 작업 시 아키텍처 판단이 필요하면 이 문서를 기준으로 한다.

---

## 1. Clean Architecture 개요

Qradar는 Clean Architecture를 따른다.

레이어 의존 방향은 아래 구조를 지킨다.

```text
presentation → domain ← data
```

각 레이어의 책임은 명확히 분리한다.

| 레이어 | 폴더 | 역할 |
|---|---|---|
| Presentation | `lib/presentation/` | UI, Widget, Page, Riverpod Provider, 사용자 입력 처리 |
| Domain | `lib/domain/` | Entity, UseCase, Repository Interface, 순수 비즈니스 로직 |
| Data | `lib/data/` | DTO(Model), DataSource, Repository 구현체, Firebase/REST API 호출 |

---

## 2. 레이어별 책임

### Presentation Layer

위치:

```text
lib/presentation/
```

역할:

- 화면 UI 구성
- 사용자 입력 처리
- Riverpod Provider를 통한 상태 관리
- UseCase 호출
- 공통 Widget 관리

규칙:

- Firebase 또는 외부 SDK를 직접 import하지 않는다.
- DataSource 또는 Repository 구현체를 직접 호출하지 않는다.
- Domain Layer의 UseCase 또는 Repository Interface 기준으로 동작한다.

---

### Domain Layer

위치:

```text
lib/domain/
```

역할:

- 비즈니스 Entity 정의
- UseCase 정의
- Repository Interface 정의
- 앱의 핵심 비즈니스 규칙 보관

규칙:

- 순수 Dart로 유지한다.
- Firebase, REST API, Flutter UI, 외부 SDK를 직접 알지 않는다.
- Data Layer를 직접 의존하지 않는다.
- UseCase는 단일 책임을 가진다.

---

### Data Layer

위치:

```text
lib/data/
```

역할:

- Firebase / REST API / Local Storage 실제 호출
- DTO(Model) 정의
- Repository Interface 구현
- 외부 데이터 구조를 Domain Entity로 변환

규칙:

- Firebase 또는 외부 SDK 직접 사용은 Data Layer에서만 허용한다.
- Model(DTO)은 외부 응답 구조를 표현한다.
- Repository 구현체는 Domain의 Repository Interface를 구현한다.

---

## 3. 전체 디렉토리 구조

```text
lib/
├── app/
│   ├── app.dart               # MaterialApp, 테마, 전역 설정
│   └── router.dart            # go_router 라우팅 정의
│
├── core/
│   ├── constants/             # 앱 전역 상수
│   ├── errors/                # 공통 예외 클래스
│   ├── extensions/            # Dart extension methods
│   ├── theme/                 # AppTheme, AppColors, 폰트
│   └── utils/                 # 날짜 포맷, 거리 계산 등 유틸 함수
│
├── data/
│   ├── datasources/
│   │   ├── remote/            # Firebase / REST API 호출
│   │   └── local/             # SharedPreferences, Hive 등 로컬 캐시
│   ├── models/                # JSON 직렬화 DTO
│   └── repositories/          # Repository 구현체
│
├── domain/
│   ├── entities/              # 순수 비즈니스 엔티티
│   ├── repositories/          # Repository 인터페이스
│   └── usecases/              # 단일 책임 비즈니스 로직
│
└── presentation/
    ├── common/                # 공통 위젯
    ├── admin/                 # 관리자 화면
    ├── owner/                 # 점주 화면
    └── customer/              # 고객 화면
        ├── auth/
        ├── home/
        ├── store/
        ├── cart/
        ├── order/
        ├── gift/
        └── mypage/
```

---

## 4. 기능별 파일 패턴

하나의 기능은 가능한 한 아래 흐름을 따른다.

예: 인증 기능

```text
lib/
├── domain/
│   ├── entities/
│   │   └── user_entity.dart
│   ├── repositories/
│   │   └── auth_repository.dart
│   └── usecases/
│       ├── sign_in_with_google_use_case.dart
│       ├── sign_in_with_kakao_use_case.dart
│       ├── sign_in_with_naver_use_case.dart
│       └── sign_out_use_case.dart
│
├── data/
│   ├── datasources/remote/
│   │   └── auth_remote_data_source.dart
│   ├── models/
│   │   └── user_model.dart
│   └── repositories/
│       └── auth_repository_impl.dart
│
└── presentation/customer/auth/
    ├── login_page.dart
    └── login_provider.dart
```

---

## 5. 데이터 흐름

기본 데이터 흐름은 아래 순서를 따른다.

```text
UI / Page / Widget
  → Provider
  → UseCase
  → Repository Interface
  → Repository Implementation
  → DataSource
  → Firebase / REST API / Local Storage
```

예: Google 로그인

```text
login_page.dart
  → login_provider.dart
  → sign_in_with_google_use_case.dart
  → auth_repository.dart
  → auth_repository_impl.dart
  → auth_remote_data_source.dart
  → Firebase Auth / Google Sign-In SDK
```

---

## 6. 네이밍 규칙

| 종류 | 규칙 | 예시 |
|---|---|---|
| 파일명 | `snake_case.dart` | `auth_repository.dart` |
| 클래스명 | `PascalCase` | `AuthRepository` |
| Provider | `xxxProvider` | `authProvider` |
| UseCase | `XxxUseCase` | `SignInWithGoogleUseCase` |
| Entity | `XxxEntity` | `UserEntity` |
| Model / DTO | `XxxModel` | `UserModel` |
| DataSource | `XxxRemoteDataSource` / `XxxLocalDataSource` | `AuthRemoteDataSource` |
| Repository Interface | `XxxRepository` | `AuthRepository` |
| Repository Implementation | `XxxRepositoryImpl` | `AuthRepositoryImpl` |

---

## 7. Repository 패턴

Repository 패턴은 Firebase → AWS 또는 자체 서버 전환을 고려해 반드시 유지한다.

원칙:

- Domain Layer는 Repository Interface만 안다.
- Data Layer는 Repository Interface를 구현한다.
- Presentation Layer는 DataSource나 Firebase를 직접 알지 않는다.
- 데이터 소스가 바뀌어도 Domain / Presentation 레이어 변경을 최소화한다.

예:

```text
domain/repositories/store_repository.dart
data/repositories/store_repository_impl.dart
data/datasources/remote/store_remote_data_source.dart
```

---

## 8. 서버 마이그레이션 전략

Qradar는 단계적으로 서버 구조가 확장될 수 있다.

### Phase 1: MVP

- Firebase
- Firestore
- Firebase Auth
- Firebase Storage
- Firebase Functions
- FCM

### Phase 2: 성장기

- AWS ECS 또는 EC2
- AWS RDS(PostgreSQL)
- AWS S3
- AWS SNS + FCM

### Phase 3: 대규모

- 자체 서버 또는 고도화된 백엔드 인프라

마이그레이션을 고려해 Data Layer 의존성을 격리한다.

Firebase 기반 구현은 `data/datasources/remote/`와 `data/repositories/` 내부에 한정한다.

---

## 9. core 폴더 기준

`core/`는 여러 기능에서 공통으로 사용하는 요소를 둔다.

| 폴더 | 역할 |
|---|---|
| `core/constants/` | 전역 상수, 카테고리, 임계값 |
| `core/errors/` | 공통 예외, 실패 타입 |
| `core/extensions/` | Dart extension |
| `core/theme/` | AppColors, AppTheme, 팔레트 |
| `core/utils/` | 날짜, 거리, 등급 계산 등 순수 유틸 |

주의:

- 특정 기능에만 필요한 값은 해당 feature 내부 또는 task 기준으로 관리한다.
- 여러 기능에서 재사용되는 경우에만 core로 올린다.

---

## 10. presentation 폴더 기준

`presentation/`은 사용자 역할과 화면 단위로 나눈다.

```text
presentation/
├── common/
├── admin/
├── owner/
└── customer/
```

기준:

- 여러 화면에서 쓰는 위젯은 `presentation/common/`
- 고객 화면은 `presentation/customer/`
- 점주 화면은 `presentation/owner/`
- 관리자 화면은 `presentation/admin/`

---

## 11. 작업 문서 구조

기능별 작업 문서는 `docs/tasks/[기능명]/`에 둔다.

```text
docs/tasks/[feature]/
├── spec.md
├── design.md
├── implementation.md
└── test_report.md
```

역할:

| 파일 | 작성 주체 | 역할 |
|---|---|---|
| `spec.md` | architect | 요구사항, 레이어 설계, 데이터 흐름 |
| `design.md` | designer | UI 구조, 컴포넌트, 상태 UI |
| `implementation.md` | developer | 구현 파일, 결정사항, 테스트 포인트 |
| `test_report.md` | tester | 검증 결과, PASS/FAIL, 보류 항목 |

---

## 12. 판단 기준

아키텍처 판단이 필요할 때는 아래 기준을 따른다.

- 새 Entity / UseCase / Repository가 필요한가?
- 기존 UseCase로 해결 가능한가?
- DataSource가 Firebase/REST API에 직접 접근하는가?
- Presentation이 Domain을 우회하고 Data에 접근하지 않는가?
- 공통화가 필요한 코드인가, 아직 feature 내부에 둘 코드인가?
- 마이그레이션 시 Domain / Presentation 변경 없이 Data Layer만 교체 가능한가?

이 기준에 맞지 않으면 구조를 재검토한다.