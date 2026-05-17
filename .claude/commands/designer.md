# /designer

기능의 UI/UX 명세를 작성한다.

이 command는 직접 디자인 명세를 완료하지 않는다.  
반드시 `.claude/agents/designer.md`에 정의된 `designer` subagent에게 디자인 작업을 위임한다.

---

## 작업 기능

$ARGUMENTS

---

## 실행 지침

1. 반드시 `.claude/agents/designer.md`에 정의된 `designer` subagent에게 디자인 명세 작성을 위임한다.
2. `CLAUDE.md`의 공통 규칙과 Guide Reference Policy를 따른다.
3. 현재 작업의 `docs/tasks/[기능명]/spec.md`를 기준으로 한다.
4. 새 화면 또는 새 UI 흐름을 만드는 경우 `docs/agents/designer_guide.md`를 참고한다.
5. Figma 또는 디자인 레퍼런스가 있으면 아래 위치를 확인한다.
   - `docs/design/screens/[화면명]/[화면명].png`
   - `docs/design/screens/[화면명]/[화면명].md`
   - `docs/design/components/`
6. 디자인 결과는 `docs/tasks/[기능명]/design.md`에 작성하거나 갱신한다.
7. 이 command는 designer subagent의 결과를 요약해 사용자에게 보고한다.

---

## designer subagent 요청 내용

`.claude/agents/designer.md`의 `designer` subagent에게 다음을 요청한다.

- `spec.md` 요구사항 분석
- Figma 또는 디자인 레퍼런스 확인
- 화면 구조 정의
- 컴포넌트 목록 정의
- 컴포넌트별 크기 / 간격 / 색상 / 텍스트 / 상태 정의
- Qradar 디자인 시스템 적용
- `AppColors` 기준 색상 사용
- loading / error / empty 상태 정의
- 인터랙션 정의
- 개발자 전달 특이사항 정리
- `docs/tasks/[기능명]/design.md` 작성 또는 갱신

---

## 완료 후 보고

designer subagent의 결과를 바탕으로 사용자에게 아래 내용을 보고한다.

- 주요 디자인 결정사항
- 생성 또는 수정된 `design.md` 경로
- developer에게 전달할 특이사항
- 사용자 확인이 필요한 디자인 결정사항