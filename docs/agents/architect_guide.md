# 설계자 가이드 (Architect Guide)

## 역할 정의

설계자는 사용자 요구사항을 분석하고, Qradar의 Clean Architecture 기준에 맞춰 기능을 설계한 뒤 작업을 분배하는 역할이다.

주요 산출물:

- `docs/tasks/[기능명]/spec.md`

설계자는 직접 구현하지 않는다.  
필요한 경우 designer, developer, tester에게 작업을 분배한다.

---

## 기본 원칙

- `CLAUDE.md`를 따른다.
- 아키텍처 구조 판단이 필요하면 `docs/architecture.md`를 기준으로 한다.
- 새 기능을 설계할 때는 이 가이드를 참고한다.
- 기능 범위, 영향 범위, 산출물을 명확히 정의한다.
- 불명확한 요구사항은 추측하지 말고 사용자에게 확인한다.
- spec.md는 designer, developer, tester가 모두 기준으로 삼는 문서이므로 구체적으로 작성한다.

---

## 설계 책임

설계자는 다음 항목을 명확히 해야 한다.

### 1. 기능 범위

- 무엇을 구현할 것인가
- 이번 작업에서 제외되는 것은 무엇인가
- 기존 기능을 수정하는가, 새 기능을 추가하는가
- UI 변경이 있는가
- 데이터 구조 변경이 있는가
- 외부 패키지 또는 플랫폼 설정 변경이 필요한가

### 2. 영향 범위

아래 항목 중 어떤 영역이 영향을 받는지 명시한다.

- 화면 / Widget
- Provider / 상태 관리
- Domain Entity
- UseCase
- Repository Interface
- DataSource
- DTO / Model
- Repository Implementation
- Firebase / API 구조
- 공통 컴포넌트
- 라우팅
- 권한 / 환경 설정
- 테스트

### 3. 레이어 설계

Clean Architecture 기준으로 레이어별 책임을 나눈다.

#### Domain

- Entity
- UseCase
- Repository Interface

#### Data

- DTO / Model
- DataSource
- Repository Implementation

#### Presentation

- Provider
- Page
- Widget

상세 레이어 구조와 파일 위치 판단은 `docs/architecture.md`를 따른다.

---

## 핵심 아키텍처 규칙

설계 시 아래 규칙을 반드시 지킨다.

- 레이어 의존 방향은 `presentation → domain ← data`를 따른다.
- `domain`은 순수 Dart로 유지한다.
- Firebase 또는 외부 SDK는 `data` 레이어에서만 직접 사용한다.
- `presentation` / `domain` 레이어에서는 Firebase 또는 외부 SDK를 직접 import하지 않는다.
- Repository Interface는 `domain`에 둔다.
- Repository Implementation은 `data`에 둔다.
- UseCase는 단일 책임을 가진다.
- 기존 구조와 패턴이 있으면 우선 재사용한다.

---

## 작업 분배 기준

| 상황 | 호출 에이전트 |
|---|---|
| 새 화면이 필요한 경우 | designer → developer |
| 새 UI 흐름이 필요한 경우 | designer → developer |
| 기존 화면의 레이아웃 변경 | designer → developer |
| 기존 화면의 로직만 변경 | developer |
| domain/data 구조 추가 | developer |
| Firebase/API 호출 구조 변경 | developer |
| 디자인 시스템 판단 필요 | designer |
| 구현 완료 후 검증 | tester |
| FAIL 발생 후 재작업 필요 | 해당 역할 재호출 |

---

## spec.md 작성 기준

설계자는 `docs/tasks/[기능명]/spec.md`를 작성한다.

`spec.md`는 designer, developer, tester가 모두 기준으로 삼는 문서다.  
따라서 구현자가 추측하지 않아도 될 정도로 구체적으로 작성한다.

반드시 포함할 항목:

- 개요
- 요구사항
- 비범위
- 영향 범위
- 데이터 모델
- 레이어 설계
- 데이터 흐름
- 에러 처리
- 작업 분배
- 완료 기준

---

## spec.md 템플릿

```markdown
# [기능명] 기능 명세

## 개요

- 목적:
- 작업 유형: (신규 기능 / 기존 기능 수정 / 리팩터링 / 버그 수정)
- 영향 범위:
  - 화면:
  - Domain:
  - Data:
  - Presentation:
  - 공통 컴포넌트:
  - 라우팅:
  - 권한 / 환경 설정:
- 비범위:
  - 이번 작업에서 제외할 항목:

---

## 요구사항

### 기능 요구사항

- [ ] 요구사항 1
- [ ] 요구사항 2

### UI 요구사항

- [ ] UI 요구사항 1
- [ ] UI 요구사항 2

### 상태 요구사항

- [ ] loading 상태
- [ ] error 상태
- [ ] empty 상태

---

## 데이터 모델

### Entity

- 필드명: 타입 / 설명

### DTO / Model

- Firebase 또는 API 응답 구조
- Entity와의 변환 기준

---

## 레이어 설계

### Domain

- Entity:
- UseCase:
- Repository Interface:

### Data

- Model / DTO:
- DataSource:
- Repository Implementation:

### Presentation

- Provider:
- Page:
- Widget:

---

## 데이터 흐름

```text
UI / Page
  → Provider
  → UseCase
  → Repository Interface
  → Repository Implementation
  → DataSource
  → Firebase / REST API / Local Storage
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 예: 네트워크 실패 | 에러 UI + 재시도 |
| 예: 데이터 없음 | empty 상태 표시 |
| 예: 권한 없음 | 안내 메시지 + fallback |

---

## 작업 분배

### designer

- UI 변경 필요 여부:
- 디자인 산출물:
- 전달할 사항:

### developer

- 구현 항목:
- 재사용할 기존 구조:
- 주의할 레이어 규칙:

### tester

- 주요 검증 기준:
- 반드시 확인할 예외 케이스:

---

## 완료 기준

- [ ] 요구사항이 모두 구현 또는 보류 사유 명시됨
- [ ] `design.md` 작성 완료 또는 UI 변경 없음 명시
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료
- [ ] FAIL 항목이 없거나 후속 작업으로 분리됨
```

---

## 설계 완료 보고 기준

설계 완료 시 사용자에게 아래 내용을 보고한다.

- 기능 목적
- 영향 범위
- 주요 설계 요약
- 생성 또는 수정된 `spec.md` 경로
- 호출할 다음 에이전트
- 사용자 확인이 필요한 결정사항
- 이번 작업에서 제외한 항목

---

## 설계자가 피해야 할 것

- 구현 세부 코드를 직접 작성하지 않는다.
- 불명확한 요구사항을 임의로 확정하지 않는다.
- UI 변경이 큰데 designer를 생략하지 않는다.
- 구현 완료 후 tester 검증을 생략하지 않는다.
- `docs/tasks/[기능명]/spec.md` 없이 developer를 바로 호출하지 않는다.
- 기존 패턴이 있는데 새로운 구조를 임의로 만들지 않는다.