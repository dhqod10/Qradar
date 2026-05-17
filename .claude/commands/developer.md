# /developer

기능을 코드로 구현한다.

이 command는 직접 구현하지 않는다.  
반드시 `.claude/agents/developer.md`에 정의된 `developer` subagent에게 구현 작업을 위임한다.

---

## 작업 기능

$ARGUMENTS

---

## 실행 지침

1. 반드시 `.claude/agents/developer.md`에 정의된 `developer` subagent에게 구현 작업을 위임한다.
2. `CLAUDE.md`의 공통 규칙과 Guide Reference Policy를 따른다.
3. 현재 작업의 `docs/tasks/[기능명]/spec.md`를 기준으로 한다.
4. `docs/tasks/[기능명]/design.md`가 있으면 함께 기준으로 삼는다.
5. 새로운 `domain`, `data`, `presentation` 파일을 추가하는 경우 `docs/agents/developer_guide.md`를 참고한다.
6. 아키텍처 또는 파일 위치 판단이 필요하면 `docs/architecture.md`를 참고한다.
7. 구현 결과는 `docs/tasks/[기능명]/implementation.md`에 작성하거나 갱신한다.
8. 이 command는 developer subagent의 결과를 요약해 사용자에게 보고한다.

---

## developer subagent 요청 내용

`.claude/agents/developer.md`의 `developer` subagent에게 다음을 요청한다.

- `spec.md` 요구사항 확인
- `design.md`가 있으면 UI 명세 확인
- 기존 코드 구조 분석
- 재사용 가능한 코드 확인
- Clean Architecture 기준 구현
- Firebase/외부 SDK는 `data` layer에서만 직접 사용
- `presentation` / `domain` layer에서 Firebase/외부 SDK 직접 import 금지
- `AppColors`만 사용
- 요청 범위 밖 코드 수정 금지
- 구현 파일 목록 정리
- 테스트 포인트 정리
- 미구현/보류 항목 정리
- `docs/tasks/[기능명]/implementation.md` 작성 또는 갱신

---

## 완료 후 보고

developer subagent의 결과를 바탕으로 사용자에게 아래 내용을 보고한다.

- 구현 완료 항목
- 생성 또는 수정된 `implementation.md` 경로
- 수정된 주요 파일
- 테스트 포인트
- 미구현/보류 항목
- `flutter analyze` 결과
- 필요한 경우 `flutter test` 결과