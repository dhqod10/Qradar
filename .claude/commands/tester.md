# /tester

구현 결과를 검증하고 테스트 리포트를 작성한다.

이 command는 직접 검증하지 않는다.  
반드시 `.claude/agents/tester.md`에 정의된 `tester` subagent에게 검증 작업을 위임한다.

---

## 테스트 대상 기능

$ARGUMENTS

---

## 실행 지침

1. 반드시 `.claude/agents/tester.md`에 정의된 `tester` subagent에게 검증 작업을 위임한다.
2. `CLAUDE.md`의 공통 규칙과 Guide Reference Policy를 따른다.
3. 현재 작업의 아래 문서를 기준으로 한다.
   - `docs/tasks/[기능명]/spec.md`
   - `docs/tasks/[기능명]/design.md` 있을 경우
   - `docs/tasks/[기능명]/implementation.md`
4. 테스트 기준 또는 체크리스트가 필요하면 `docs/agents/tester_guide.md`를 참고한다.
5. 아키텍처 판단이 필요하면 `docs/architecture.md`를 참고한다.
6. 테스트 결과는 `docs/tasks/[기능명]/test_report.md`에 작성하거나 갱신한다.
7. 이 command는 tester subagent의 결과를 요약해 사용자에게 보고한다.

---

## tester subagent 요청 내용

`.claude/agents/tester.md`의 `tester` subagent에게 다음을 요청한다.

- `spec.md` 기준 기능 검증
- `design.md` 기준 UI 검증
- `implementation.md` 기준 구현 내역 확인
- 실제 코드 확인
- Clean Architecture 준수 여부 검증
- Firebase/외부 SDK import 위치 검증
- `AppColors` 사용 여부 검증
- 하드코딩 색상 여부 검증
- 에러/로딩/빈 상태 검증
- `flutter analyze` 확인
- 필요한 경우 `flutter test` 확인
- PASS / FAIL / 보류 항목 정리
- `docs/tasks/[기능명]/test_report.md` 작성 또는 갱신

---

## 완료 후 보고

tester subagent의 결과를 바탕으로 사용자에게 아래 내용을 보고한다.

- 전체 결과 요약
- 생성 또는 수정된 `test_report.md` 경로
- PASS / FAIL / 보류 개수
- 우선 수정해야 할 FAIL 항목
- 후속 작업 후보