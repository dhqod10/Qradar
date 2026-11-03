# qoin_policy_admin_ui — implementation

작성: developer / 2026-11-03. 웹 콘솔(vanilla JS) 전용. functions / Rules / firebase.json / 인덱스 무변경. 배포 안 함.

## 수정 파일 (landing/console/assets)
- `console-data.js`: callable 쓰기 래퍼 3종 신설 — `setQoinAccrualRate(scope, targetId, {rate|clear, reason})`, `setQoinAccrualEnabled(scope, targetId, enabled, reason)`, `applyBrandQoinRate(brandId, {rate|clear, mode, reason, resumeHistoryId})` (일괄은 120s 타임아웃). 기존 읽기 함수 유지.
- `section-admin.js`:
  - 신규 블록 "Qoin 적립 정책 편집": `parsePctInput`(% → 소수, 0.1% 격자, 0.1~20%), `openQoinRateDialog`(입력 → 확인 2단계 + 사유 필수), `openQoinSwitchDialog`, `openBrandBulkDialog`(preserve/overwrite, 영향 범위 고지, 브랜드 OFF 경고), `openBulkResumeDialog`, `mountQoinPolicy`(브랜드/매장 상세 카드 + 해당 범위 이력 `listQoinHistoryOf`).
  - `viewQoin`: "읽기 전용" 태그 제거, 전역 적립률 변경 버튼(clear 미제공), 브랜드별 설정 진입 목록 추가. 비상정지는 기존 읽기 카드 그대로(토글 없음).
  - `viewBrandDetail` / `viewStoreDetail`: approved 일 때만 Qoin 적립 설정 카드 마운트.
  - 매장 목록: approved 행에 "Qoin 설정 →" 링크 추가 (승인 후 매장 상세로 갈 길이 없었음. 상세 라우트 `#/stores/pending/:id` 재사용).
  - `HIST_FIELD` 에 `accrualEnabled` 추가.

## 동작 요약
- 모든 쓰기는 callable 경유. Firestore 직접 쓰기 0, 이력 코드 신규 0 (서버가 같은 트랜잭션에 기록).
- 일괄 진행 중(`qoinBulkStatus=in_progress` 5분 이내): 브랜드 쓰기 버튼 잠금, 매장은 소속 브랜드 기준 잠금. `partial`/방치 in_progress: 중단 배너 + 재개 버튼(`resumeHistoryId`, mode overwrite).
- 매장: 소속 브랜드 조회 실패 시 쓰기 잠금(서버 잠금 판정 불가).
- 영어 서버 메시지는 노출하지 않고 한국어 일반 문구로 대체.
- spend(`setQoinSpendPolicy`) 미배선, spend 입력 없음. 전역 스위치/비상정지 쓰기 없음.

## 검증
- `node --check` console-data.js / section-admin.js 통과.
- 회귀 점검(코드): 적립소급 폼(`qoinPanelHtml`/`wireQoin`/`runBackfillQoinAccrual`), geo/search 백필(`wireTool`), 회원관리(`viewUsers`/`setUserSuspension`) 코드 미변경. 기존 줄 삭제는 import 줄 확장, 매장 목록 링크 셀, viewQoin 헤더/버튼 부분뿐 (qoin TOOLS 삭제는 선행 작업분).
- 브라우저 실동작 미검증 (배포·실행 안 함).

## 테스트 포인트
1. 전역 적립률 변경: 3, 2.5, 0.1, 20 허용 / 0, 0.05, 20.1, 문자 거부. 확인 단계 전→후 표시, 사유 없으면 진행 불가. 이력 1건.
2. 브랜드/매장 적립률 변경 + "개별 값 삭제"(clear). 값 반영·"실제 적용" 재계산·이력 갱신.
3. 스위치 끄기/켜기 (사유 필수), 이력 `적립 스위치` 행.
4. 브랜드 일괄: preserve / overwrite, 영향 범위 숫자, 완료 토스트, 이력(일괄·덮어쓰기 N개). 진행 중 잠금, partial 재개.
5. 비 approved 브랜드/매장 상세에는 카드 없음. 매장 목록 approved 행 링크.
6. spend 조작 UI 없음, 비상정지 토글 없음.
7. 회귀: #/tools 적립소급 폼, geo/search 백필, #/users.

## 보류 / 참고
- 콘솔 레이아웃 CSS 신규 없음(기존 클래스 + 인라인 스타일). 체크박스/라디오는 기본 스타일.
- 재개 버튼은 `qoinBulkHistoryId` 부재 시 서버가 거부 (UI 비활성 처리 없음).
- 일괄 적용 매장 수 집계는 `listAllStores` 전량 로드를 사용 (정보용, 실패해도 적용 가능).
