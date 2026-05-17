# CLAUDE.md

이 문서는 Claude Code 가 Qradar 저장소에서 작업할 때 따라야 하는 **공통 규칙** 과, 각 역할이 어떤 가이드/문서를 보고 어떤 산출물을 만드는지 정의하는 **Guide Reference Policy** 만 담는다.

상세 내용은 모두 별도 문서에 단일 진실원으로 두며, 이 문서는 그 위치를 가리키는 인덱스 역할에 그친다.

---

## 1. 프로젝트 정체성

**Qradar (Quality Grade Radar)** — 고품질을 찾는 사람들의 레이더 역할을 하는 카페 주문 앱.

브랜드 감성은 프리미엄하고 심플하며, 현재 UI 컨셉은 **밝은 캔버스 + 미드나잇 네이비 포인트**를 기본으로 한다.

### Qradar 고유 용어

| 일반 용어 | Qradar 용어 | 설명 |
|-----------|------------|------|
| 앱 화폐 | **Qoin** | Coin 의 C 를 Q 로 |
| 사용자 | **Qrator** | Curator 의 C 를 Q 로. 품질 선별자 |
| 주문 내역 | **Log** | 선별자가 기록을 남긴다는 의미 |

화면명, 문구, 코드, 문서에서 가능한 한 일관되게 사용한다.

제품 범위(역할/기능 명세)는 [docs/product_scope.md](docs/product_scope.md) 를 참조한다.

---

## 2. 절대 규칙

이 규칙은 모든 역할/모든 문서에 우선한다.

1. **Clean Architecture** 를 따른다. 레이어 의존 방향은 `presentation → domain ← data`.
2. **Firebase / 외부 SDK 직접 사용은 `data` 레이어에서만 허용**한다. `presentation` / `domain` 레이어에서는 직접 import 하지 않는다.
3. **색상은 `AppColors` 만 사용**한다. `Color(0x...)` 직접 하드코딩 금지.
4. **API key, secret, 환경별 설정값을 코드에 하드코딩하지 않는다.** `--dart-define` / `String.fromEnvironment` 또는 `.env` 를 사용한다.

상세 아키텍처 판단은 [docs/architecture.md](docs/architecture.md) 를 단일 진실원으로 따른다.

---

## 3. Guide Reference Policy

각 역할은 아래 표에 따라 운영 정의 / 상세 가이드 / 산출물 위치를 명확히 분리해 사용한다.

| 역할 | 슬래시 커맨드 | 운영 정의 (subagent) | 상세 참고서 | 산출물 |
|---|---|---|---|---|
| 설계자 | `/architect` | [.claude/agents/architect.md](.claude/agents/architect.md) | [docs/agents/architect_guide.md](docs/agents/architect_guide.md) | `docs/tasks/[기능명]/spec.md` |
| 디자이너 | `/designer`  | [.claude/agents/designer.md](.claude/agents/designer.md)   | [docs/agents/designer_guide.md](docs/agents/designer_guide.md)   | `docs/tasks/[기능명]/design.md` |
| 개발자 | `/developer` | [.claude/agents/developer.md](.claude/agents/developer.md) | [docs/agents/developer_guide.md](docs/agents/developer_guide.md) | `docs/tasks/[기능명]/implementation.md` |
| 테스터 | `/tester`    | [.claude/agents/tester.md](.claude/agents/tester.md)       | [docs/agents/tester_guide.md](docs/agents/tester_guide.md)       | `docs/tasks/[기능명]/test_report.md` |

### 참조 우선순위

판단이 필요할 때 다음 순서로 본다.

1. 본 문서 (`CLAUDE.md`) 의 절대 규칙
2. 현재 기능의 task 문서 (`docs/tasks/[기능명]/{spec,design,implementation,test_report}.md`)
3. 해당 역할의 **운영 정의** (`.claude/agents/[role].md`) — 무엇을 해야 하는지의 운영 인터페이스
4. 해당 역할의 **상세 참고서** (`docs/agents/[role]_guide.md`) — 템플릿, 체크리스트, 작성 예시
5. 도메인별 단일 진실원
   - 아키텍처 / 디렉토리 구조 / 네이밍 / Repository 패턴 / 마이그레이션 / 작업 문서 구조: [docs/architecture.md](docs/architecture.md)
   - 디자인 시스템 / 색상 토큰 / 컴포넌트 원칙 / 상태 UI: [docs/agents/designer_guide.md](docs/agents/designer_guide.md)
   - 코드 컨벤션 / freezed / Provider / 에러 처리: [docs/agents/developer_guide.md](docs/agents/developer_guide.md)
   - 제품 범위 / 사용자 역할 / 기능 명세: [docs/product_scope.md](docs/product_scope.md)
   - 기술 스택 / 패키지 / 빌드 명령어 / Firebase 설정 / 환경 변수: [docs/operations.md](docs/operations.md)

같은 규칙이 여러 곳에 보인다면 위 표의 단일 진실원을 따른다.

---

## 4. 작업 워크플로우

```
/architect [요구사항]
  → docs/tasks/[기능명]/spec.md 작성
  → /designer 호출 (UI 변경 있을 때)
      → docs/tasks/[기능명]/design.md 작성
  → /developer 호출
      → 코드 구현
      → docs/tasks/[기능명]/implementation.md 작성
  → /tester 호출
      → docs/tasks/[기능명]/test_report.md 작성
  → 설계자 재검토 (FAIL 있으면 재분배)
```

산출물 디렉토리 구조:

```
docs/tasks/[feature]/
├── spec.md            # architect
├── design.md          # designer
├── implementation.md  # developer
└── test_report.md     # tester
```

---

## 5. 자주 쓰는 명령어 (요약)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d <device-id>
```

전체 명령어 / 빌드 / 환경 변수 / Firebase 설정은 [docs/operations.md](docs/operations.md) 를 참조한다.
