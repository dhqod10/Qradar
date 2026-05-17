# 개발자 가이드 (Developer Guide)

## 역할 정의

개발자는 `spec.md`와 `design.md`를 기준으로 Qradar의 아키텍처와 코드 컨벤션에 맞게 기능을 구현하는 역할이다.

주요 산출물:

- 실제 코드 변경
- `docs/tasks/[기능명]/implementation.md`

개발자는 요구사항을 임의로 확장하지 않는다.  
불명확한 부분은 구현 전에 사용자 또는 architect에게 확인한다.

---

## 기본 원칙

- `CLAUDE.md`를 따른다.
- 아키텍처 구조 판단이 필요하면 `docs/architecture.md`를 기준으로 한다.
- 새로운 `domain`, `data`, `presentation` 파일을 추가할 때는 이 가이드를 참고한다.
- 기존 구조와 패턴을 우선 재사용한다.
- 요청 범위와 무관한 코드는 수정하지 않는다.
- 추측으로 구현하지 않는다.
- 구현 내역은 반드시 `implementation.md`에 기록한다.

---

## 입력 문서

개발자는 구현 전에 아래 문서를 확인한다.

### 필수

- `docs/tasks/[기능명]/spec.md`

### 조건부

- `docs/tasks/[기능명]/design.md`
  - UI 변경이 있는 경우 필수
- `docs/architecture.md`
  - 파일 위치, 레이어 책임, 구조 판단이 필요한 경우
- `docs/agents/designer_guide.md`
  - 디자인 시스템 판단이 필요한 경우
- 기존 관련 코드
  - 동일 패턴이 이미 존재하는지 확인

---

## 구현 절대 규칙

아래 규칙은 반드시 지킨다.

- Clean Architecture를 따른다.
- 레이어 의존 방향은 `presentation → domain ← data`를 따른다.
- `domain`은 순수 Dart로 유지한다.
- Firebase 또는 외부 SDK는 `data` 레이어에서만 직접 사용한다.
- `presentation` / `domain` 레이어에서는 Firebase 또는 외부 SDK를 직접 import하지 않는다.
- Repository Interface는 `domain`에 둔다.
- Repository Implementation은 `data`에 둔다.
- DataSource는 Firebase / REST API / Local Storage 실제 호출을 담당한다.
- UseCase는 단일 책임을 가진다.
- 색상은 반드시 `AppColors`만 사용한다.
- 색상을 직접 하드코딩하지 않는다.
- API key, secret, 환경별 설정값을 코드에 하드코딩하지 않는다.

---

## 구현 순서

새 기능을 구현할 때는 기본적으로 아래 순서를 따른다.

1. `domain/entities/`
2. `domain/repositories/`
3. `domain/usecases/`
4. `data/models/`
5. `data/datasources/`
6. `data/repositories/`
7. `presentation/providers/`
8. `presentation/pages/`
9. `presentation/widgets/`

단, 기존 기능 수정이나 단순 버그 수정은 필요한 범위만 수정한다.

---

## 레이어별 구현 기준

### Domain

Domain 레이어는 앱의 핵심 비즈니스 규칙을 담는다.

포함 가능:

- Entity
- Repository Interface
- UseCase

규칙:

- Flutter UI를 모른다.
- Firebase / REST API / 외부 SDK를 모른다.
- Data Layer 구현체를 모른다.
- Entity는 가능한 한 외부 응답 구조와 분리한다.
- UseCase는 하나의 명확한 책임만 가진다.

예:

```text
lib/domain/entities/store_entity.dart
lib/domain/repositories/store_repository.dart
lib/domain/usecases/get_nearby_stores_use_case.dart
```

---

### Data

Data 레이어는 외부 데이터 접근과 변환을 담당한다.

포함 가능:

- DTO / Model
- Remote DataSource
- Local DataSource
- Repository Implementation

규칙:

- Firebase / REST API / 외부 SDK 직접 사용은 이 레이어에서만 허용한다.
- DTO(Model)는 외부 응답 구조를 표현한다.
- Repository Implementation은 DTO를 Domain Entity로 변환해 반환한다.
- 외부 SDK 타입을 Domain / Presentation으로 노출하지 않는다.

예:

```text
lib/data/models/store_model.dart
lib/data/datasources/remote/store_remote_data_source.dart
lib/data/repositories/store_repository_impl.dart
```

---

### Presentation

Presentation 레이어는 화면과 상태 관리를 담당한다.

포함 가능:

- Page
- Widget
- Provider
- Controller / Notifier

규칙:

- Firebase / REST API / 외부 SDK를 직접 import하지 않는다.
- DataSource를 직접 호출하지 않는다.
- UseCase 또는 Provider를 통해 동작한다.
- UI 색상은 `AppColors`를 사용한다.
- 사용자 화면은 loading / error / empty 상태를 고려한다.

예:

```text
lib/presentation/customer/home/home_page.dart
lib/presentation/customer/home/providers/home_providers.dart
lib/presentation/customer/home/widgets/store_card.dart
```

---

## 파일 위치 규칙

파일 위치는 `docs/architecture.md`를 우선 기준으로 한다.

자주 쓰는 기준:

| 유형 | 위치 |
|---|---|
| Entity | `lib/domain/entities/` |
| Repository Interface | `lib/domain/repositories/` |
| UseCase | `lib/domain/usecases/` |
| DTO / Model | `lib/data/models/` |
| Remote DataSource | `lib/data/datasources/remote/` |
| Local DataSource | `lib/data/datasources/local/` |
| Repository Implementation | `lib/data/repositories/` |
| 공통 Widget | `lib/presentation/common/` |
| 고객 화면 | `lib/presentation/customer/` |
| 점주 화면 | `lib/presentation/owner/` |
| 관리자 화면 | `lib/presentation/admin/` |
| 전역 상수 | `lib/core/constants/` |
| 전역 유틸 | `lib/core/utils/` |
| 색상 / 테마 | `lib/core/theme/` |

---

## 네이밍 규칙

| 종류 | 규칙 | 예시 |
|---|---|---|
| 파일명 | `snake_case.dart` | `store_repository.dart` |
| 클래스명 | `PascalCase` | `StoreRepository` |
| Provider | `xxxProvider` | `storeRepositoryProvider` |
| UseCase | `XxxUseCase` | `GetNearbyStoresUseCase` |
| Entity | `XxxEntity` | `StoreEntity` |
| Model / DTO | `XxxModel` | `StoreModel` |
| Remote DataSource | `XxxRemoteDataSource` | `StoreRemoteDataSource` |
| Local DataSource | `XxxLocalDataSource` | `StoreLocalDataSource` |
| Repository Implementation | `XxxRepositoryImpl` | `StoreRepositoryImpl` |

---

## freezed / 코드 생성 기준

Entity와 DTO(Model)는 필요한 경우 `freezed`를 사용한다.

사용 기준:

- 값 객체 또는 상태 비교가 필요한 경우
- `copyWith`, `==`, `hashCode`가 필요한 경우
- JSON 직렬화가 필요한 DTO(Model)
- 불변 객체로 관리할 필요가 있는 경우

코드 생성 명령:

```bash
dart run build_runner build --delete-conflicting-outputs
```

주의:

- 코드 생성이 필요한 파일을 추가하거나 수정했다면 `implementation.md`에 명시한다.
- generated file을 직접 수정하지 않는다.

---

## Provider 구현 기준

Provider는 화면 상태와 UseCase 연결을 담당한다.

기준:

- Provider 이름은 `xxxProvider` 형식을 따른다.
- 단순 비동기 조회는 `FutureProvider`를 사용할 수 있다.
- 복잡한 상태 변경은 `Notifier` 또는 `AsyncNotifier`를 사용한다.
- Provider 내부에서 DataSource를 직접 호출하지 않는다.
- 필요한 의존성은 Repository / UseCase Provider를 통해 주입한다.
- 기존 provider 패턴이 있으면 우선 재사용한다.

---

## 에러 처리 기준

기본 원칙:

- 외부 호출 예외는 DataSource 또는 Repository Implementation에서 처리한다.
- `try-catch` 는 datasource / repository 구현체에서 한다. 잡은 예외는 그대로 위로 던지지 말고 **`Either` 또는 커스텀 `Result` 타입** 으로 변환해 Domain/Presentation 으로 반환한다.
- Presentation에서는 사용자에게 보여줄 error 상태를 처리한다.
- 실패 케이스는 UI에서 loading / error / empty 상태로 표현한다.
- 재시도 가능한 에러는 retry 동작을 제공한다.

비동기 처리:

- 단순 비동기 조회는 `FutureProvider` 를 사용한다.
- 복잡한 상태 변경은 `AsyncNotifier` 또는 `Notifier` 를 사용한다.
- Provider 의 비동기 결과는 `AsyncValue` 로 다루고, UI 는 `when(loading/error/data)` 또는 동등 패턴으로 분기한다.

주의:

- try-catch를 UI에 과도하게 분산하지 않는다.
- 실패 원인을 숨기지 말고 필요한 경우 `implementation.md`에 기록한다.

---

## UI 구현 기준

UI 구현 시 아래 기준을 따른다.

- `design.md`가 있으면 design.md를 기준으로 구현한다.
- 색상은 반드시 `AppColors`만 사용한다.
- `Color(0x...)` 직접 사용을 금지한다.
- `Colors.white`, `Colors.black`, `Colors.transparent` 사용은 프로젝트 관례에 맞게 최소화한다.
- 사용자에게 보이는 화면은 loading / error / empty 상태를 고려한다.
- 기존 공통 위젯이 있으면 우선 재사용한다.
- 요청 범위를 벗어나는 UI 리팩터링은 하지 않는다.

---

## Qradar 용어 사용

Qradar 고유 용어를 일관되게 사용한다.

| 일반 용어 | Qradar 용어 |
|---|---|
| 포인트 / 코인 | Qoin |
| 사용자 | Qrator |
| 주문 내역 | Log |

화면명, 문구, 주석, 문서에서 가능한 한 Qradar 용어를 따른다.  
단, 코드 가독성을 해치는 경우에는 기존 도메인 명명 규칙을 우선한다.

---

## implementation.md 작성 기준

개발자는 구현 완료 후 `docs/tasks/[기능명]/implementation.md`를 작성하거나 갱신한다.

반드시 포함할 항목:

- 개요
- 구현 파일 목록
- 수정 파일 목록
- 주요 결정사항
- spec.md와 다르게 구현한 부분과 이유
- design.md와 다르게 구현한 부분과 이유
- 테스트 포인트
- 미구현/보류 항목
- 코드 생성 필요 여부
- 실행한 검증 명령

---

## implementation.md 템플릿

```markdown
# [기능명] 구현 내역

## 개요

- 구현 목적:
- 기준 문서:
  - `docs/tasks/[기능명]/spec.md`
  - `docs/tasks/[기능명]/design.md` (있는 경우)

---

## 구현 파일 목록

### 신규 파일

- `lib/...`

### 수정 파일

- `lib/...`

### 재사용 파일

- `lib/...`

---

## 주요 결정사항

- 결정사항 1:
  - 이유:
- 결정사항 2:
  - 이유:

---

## spec.md 대비 차이

- 없음
- 또는:
  - 차이:
  - 이유:

---

## design.md 대비 차이

- 없음
- 또는:
  - 차이:
  - 이유:

---

## 테스트 포인트

- [ ] 기능 동작:
- [ ] 상태 UI:
- [ ] 아키텍처:
- [ ] 에러 처리:
- [ ] 회귀 확인:

---

## 미구현 / 보류 항목

- 항목:
  - 이유:
  - 후속 작업:

---

## 코드 생성 필요 여부

- [ ] 필요 없음
- [ ] 필요함

명령:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 검증

- `flutter analyze`:
- `flutter test`:
```

---

## 완료 기준

개발자는 아래 조건을 만족해야 완료 보고할 수 있다.

- `spec.md` 요구사항을 구현했거나 보류 사유를 명시했다.
- UI 변경이 있으면 `design.md` 기준을 확인했다.
- Clean Architecture 레이어 규칙을 지켰다.
- Firebase/외부 SDK 직접 import 위치가 올바르다.
- `AppColors` 외 색상 하드코딩이 없다.
- `implementation.md`를 작성 또는 갱신했다.
- 코드 변경이 있으면 `flutter analyze` 결과를 확인했다.
- 로직 변경이 있으면 가능한 경우 `flutter test`를 확인했다.

---

## 개발자가 피해야 할 것

- spec.md에 없는 기능을 임의로 추가하지 않는다.
- 요청 범위 밖 리팩터링을 하지 않는다.
- presentation/domain에서 Firebase 또는 외부 SDK를 직접 import하지 않는다.
- DataSource를 Presentation에서 직접 호출하지 않는다.
- 색상을 직접 하드코딩하지 않는다.
- 기존 패턴이 있는데 새로운 구조를 임의로 만들지 않는다.
- generated file을 직접 수정하지 않는다.
- 미구현 항목을 보고 없이 숨기지 않는다.