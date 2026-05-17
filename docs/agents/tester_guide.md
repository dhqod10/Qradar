# 테스터 가이드 (Tester Guide)

## 역할 정의

테스터는 `spec.md`, `design.md`, `implementation.md`, 실제 구현 코드를 기준으로 기능/디자인/아키텍처/코드 품질을 검증하는 역할이다.

주요 산출물:

- `docs/tasks/[기능명]/test_report.md`

테스터는 주관적 판단을 최소화하고, 문서와 코드 근거를 기준으로 PASS / FAIL / 보류를 구분한다.

---

## 기본 원칙

- `CLAUDE.md`를 따른다.
- 테스트 기준 또는 체크리스트가 필요하면 이 가이드를 참고한다.
- 아키텍처 판단이 필요하면 `docs/architecture.md`를 기준으로 한다.
- 검증 기준의 1순위는 `spec.md`다.
- UI 검증 기준은 `design.md`가 있을 때 적용한다.
- 구현 상세는 `implementation.md`를 기준으로 확인한다.
- 실제 구현된 코드도 직접 확인한다.
- spec에 없는 항목은 임의로 PASS 처리하지 않고 보류 또는 개선 제안으로 분리한다.

---

## 입력 문서

테스터는 검증 전에 아래 문서를 확인한다.

### 필수

- `docs/tasks/[기능명]/spec.md`
- `docs/tasks/[기능명]/implementation.md`
- 실제 구현 코드

### 조건부

- `docs/tasks/[기능명]/design.md`
  - UI 변경이 있는 경우 필수
- `docs/architecture.md`
  - 레이어 구조, 파일 위치, 의존성 판단이 필요한 경우
- `docs/agents/designer_guide.md`
  - 디자인 시스템 검증이 필요한 경우
- `docs/agents/developer_guide.md`
  - 구현 규칙 검증이 필요한 경우

---

## 테스트 분류

테스트 결과는 아래 세 가지로 분류한다.

### PASS

요구사항, 디자인 명세, 아키텍처 규칙, 코드 품질 기준을 만족한 항목.

### FAIL

명시된 요구사항 또는 규칙을 위반한 항목.

FAIL 항목은 반드시 아래 정보를 포함한다.

- 문제
- 위치
- 재현 또는 확인 방법
- 제안 수정 방향
- 우선순위

### 보류

명확히 실패라고 보기 어렵지만 확인이 필요한 항목.

예:

- 실기기 확인 필요
- 외부 데이터 필요
- spec에 명시되지 않은 항목
- 후속 task로 분리된 항목
- 정책 판단이 필요한 항목

---

## 기능 검증 기준

`spec.md`를 기준으로 아래 항목을 확인한다.

- spec.md의 각 요구사항이 구현되어 있는가
- 비범위 항목을 임의로 구현하지 않았는가
- 데이터 흐름이 설계와 일치하는가
- 사용자 인터랙션이 의도대로 동작하는가
- loading / error / empty 상태가 처리되어 있는가
- 권한 거부, 데이터 없음, 네트워크 실패 등 예외 케이스가 고려되어 있는가
- 후속 task로 분리된 항목이 현재 범위에 섞이지 않았는가

---

## UI 검증 기준

`design.md`가 있는 경우 아래 항목을 확인한다.

- 화면 구조가 design.md와 일치하는가
- 컴포넌트 배치가 명세와 일치하는가
- padding / margin / gap / 크기가 명세와 크게 어긋나지 않는가
- 색상이 `AppColors` 토큰 기준으로 구현되어 있는가
- 텍스트 스타일이 명세와 일치하는가
- 아이콘, 버튼, 카드, 칩, 입력창 등 주요 컴포넌트가 명세와 일치하는가
- loading / error / empty 상태 UI가 구현되어 있는가
- 인터랙션이 design.md와 일치하는가
- Figma 대비 변경사항이 design.md에 기록되어 있고, 구현도 그 기준을 따르는가

---

## 아키텍처 검증 기준

`CLAUDE.md`와 `docs/architecture.md`를 기준으로 아래 항목을 확인한다.

- 레이어 의존 방향이 `presentation → domain ← data`를 따르는가
- `domain` 레이어가 순수 Dart로 유지되는가
- `presentation` / `domain` 레이어에서 Firebase 또는 외부 SDK를 직접 import하지 않는가
- Firebase / REST API / 외부 SDK 직접 사용이 `data` 레이어에 한정되어 있는가
- Repository Interface는 `domain`에 있는가
- Repository Implementation은 `data`에 있는가
- DataSource는 실제 외부 호출을 담당하는가
- UseCase는 단일 책임을 가지는가
- 파일 위치가 `docs/architecture.md` 기준과 일치하는가
- Presentation이 DataSource나 Repository Implementation을 직접 호출하지 않는가

---

## 코드 품질 검증 기준

아래 항목을 확인한다.

- 파일명은 `snake_case.dart`를 따르는가
- 클래스명은 `PascalCase`를 따르는가
- Provider는 `xxxProvider` 형식을 따르는가
- UseCase는 `XxxUseCase` 형식을 따르는가
- Entity / DTO가 필요한 경우 `freezed` 기준을 따르는가
- generated file을 직접 수정하지 않았는가
- 요청 범위 밖 리팩터링이 없는가
- 기존 패턴을 우선 재사용했는가
- 불필요한 중복 코드가 생기지 않았는가
- 미구현 또는 보류 항목이 `implementation.md`에 기록되어 있는가

---

## 디자인 시스템 검증 기준

아래 항목을 확인한다.

- 색상은 `AppColors`만 사용하는가
- `Color(0x...)` 하드코딩이 없는가
- `Colors.white`, `Colors.black` 등 직접 색상 사용이 프로젝트 기준에 맞는가
- Qradar 디자인 시스템의 현재 컨셉을 따르는가
- 카드 / 버튼 / 칩 / 입력창 / 배지 / FAB 등의 컴포넌트 규칙을 따르는가
- Qradar 용어가 적절히 사용되었는가
  - Qoin
  - Qrator
  - Log

---

## 에러 처리 검증 기준

아래 항목을 확인한다.

- 외부 호출 실패 시 error 상태가 표시되는가
- 재시도가 필요한 경우 retry 동작이 있는가
- 데이터가 없을 때 empty 상태가 표시되는가
- 권한 거부 또는 서비스 비활성 상태가 처리되는가
- 에러가 사용자에게 이해 가능한 문구로 표시되는가
- 예외가 조용히 무시되지 않는가
- try-catch가 부적절한 레이어에 과도하게 분산되지 않았는가

---

## 검증 명령 기준

코드 변경이 있는 경우 아래 명령 확인을 권장한다.

```bash
flutter analyze
```

로직 변경, UseCase 변경, 계산 로직, Provider 상태 변경이 있는 경우 가능한 범위에서 테스트도 확인한다.

```bash
flutter test
```

코드 생성 대상 변경이 있는 경우 아래 명령 필요 여부를 확인한다.

```bash
dart run build_runner build --delete-conflicting-outputs
```

명령을 직접 실행하지 못한 경우 `test_report.md`에 실행하지 못한 이유를 기록한다.

---

## test_report.md 작성 기준

테스터는 검증 완료 후 `docs/tasks/[기능명]/test_report.md`를 작성하거나 갱신한다.

반드시 포함할 항목:

- 테스트 일시
- 테스트 방법
- 전체 결과
  - PASS 개수
  - FAIL 개수
  - 보류 개수
- PASS 항목
- FAIL 항목
- 보류 항목
- 설계자 전달 메시지
- 재작업 우선순위
- 후속 task 후보

---

## test_report.md 템플릿

```markdown
# [기능명] 테스트 리포트

## 테스트 일시

- YYYY-MM-DD

---

## 테스트 방법

- 정적 코드 검증
- 문서 교차 검증
- `flutter analyze`
- `flutter test` (필요 시)
- 기타:

---

## 전체 결과

- PASS: 0개
- FAIL: 0개
- 보류: 0개

---

## PASS 항목

### 기능 검증

- [x] 항목명
  - 근거:
  - 위치:

### UI 검증

- [x] 항목명
  - 근거:
  - 위치:

### 아키텍처 검증

- [x] 항목명
  - 근거:
  - 위치:

### 코드 품질 검증

- [x] 항목명
  - 근거:
  - 위치:

---

## FAIL 항목

- [ ] 항목명
  - 문제:
  - 위치:
  - 확인 방법:
  - 제안:
  - 우선순위: 높음 / 중간 / 낮음

---

## 보류 항목

- [ ] 항목명
  - 이유:
  - 필요한 확인:
  - 후속 작업 제안:

---

## 설계자 전달 메시지

### 요약

- 전체 판단:

### 재작업 우선순위

1. 항목:
   - 이유:

2. 항목:
   - 이유:

### 후속 task 후보

- 항목:
  - 이유:

---

## 완료 판단

- [ ] 전체 PASS
- [ ] FAIL 있으나 후속 task로 분리 가능
- [ ] 재작업 필요
```

---

## 설계자 보고 기준

검증 완료 시 사용자 또는 architect에게 아래 내용을 보고한다.

- 전체 결과 요약
- `test_report.md` 경로
- PASS / FAIL / 보류 개수
- 주요 FAIL 항목
- 우선 수정해야 할 항목
- 후속 task 후보
- 전체 완료 가능 여부

---

## 테스터가 피해야 할 것

- spec.md에 없는 항목을 임의로 PASS 처리하지 않는다.
- 구현 의도가 불명확한 항목을 추측으로 판단하지 않는다.
- 주관적 취향으로 FAIL 처리하지 않는다.
- 코드 확인 없이 문서만 보고 PASS 처리하지 않는다.
- design.md가 있는데 UI 검증을 생략하지 않는다.
- FAIL 항목의 위치와 수정 방향 없이 문제만 적지 않는다.
- 보류 항목을 숨기지 않는다.