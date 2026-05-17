# /architect

사용자 요구사항을 받아 Qradar 기능 설계를 시작한다.

이 command는 직접 설계를 완료하지 않는다.  
반드시 `.claude/agents/architect.md`에 정의된 `architect` subagent에게 설계 작업을 위임한다.

---

## 사용자 요구사항

$ARGUMENTS

---

## 실행 지침

1. 반드시 `.claude/agents/architect.md`에 정의된 `architect` subagent에게 사용자 요구사항 분석과 설계를 위임한다.
2. `CLAUDE.md`의 공통 규칙과 Guide Reference Policy를 따른다.
3. 새 기능 설계이므로 `docs/agents/architect_guide.md`를 참고한다.
4. 아키텍처 판단이 필요하면 `docs/architecture.md`를 참고한다.
5. 설계 결과는 `docs/tasks/[기능명]/spec.md`에 작성하거나 갱신한다.
6. 이 command는 architect subagent의 결과를 요약해 사용자에게 보고한다.

---

## architect subagent 요청 내용

`.claude/agents/architect.md`의 `architect` subagent에게 다음을 요청한다.

- 사용자 요구사항 분석
- 기능 범위 정의
- 비범위 정의
- 영향 범위 정의
- Clean Architecture 기준 레이어 설계
- 필요한 Entity / UseCase / Repository / DataSource / Provider / Page / Widget 정의
- 데이터 흐름 정의
- 에러 처리 정의
- 작업 분배 판단
- `docs/tasks/[기능명]/spec.md` 작성 또는 갱신

---

## 완료 후 보고

architect subagent의 결과를 바탕으로 사용자에게 아래 내용을 보고한다.

- 기능 목적
- 영향 범위
- 생성 또는 수정된 `spec.md` 경로
- designer 호출 필요 여부
- developer 호출 필요 여부
- tester 호출 시점
- 사용자 확인이 필요한 결정사항