# qoin_accrual_backfill_admin_ui 구현 기록

## 수정 파일 (landing/console/assets 만, CF/Rules/firebase.json/인덱스 변경 0)
- `console-data.js`: `runBackfillQoinAccrual(params)` 확장. 서버 지원 키(source/orderIds/storeId/from/to/limit/creditDisabledPeriod/overrideRate/reason)만 전송, null/undefined 미전송. 구형 `(dryRun, source)` 호출도 호환.
- `section-admin.js`: `#/tools` 의 Qoin 패널을 `qoinPanelHtml()` + `wireQoin()` 폼 뷰로 교체. `TOOLS.qoin` 제거. geo/search 는 기존 `toolPanel`/`wireTool` 그대로.

## 동작
- 입력: 대상(issues 기본/orderIds/storeRange/range) 조건부 노출, 건수 상한(기본 200), 꺼진 기간 포함, 고급 접힘 강제 요율(%, 0.1~20%, 0.1% 격자 → 소수 변환, 입력 시 경고 배너), 사유.
- 클라 1차 검증: orderIds 1~500·중복제거·`/` 거부, storeId, from/to(to>from, ≤31일), limit 1~500. 기간 입력은 datetime-local(브라우저 로컬) → millis 전송.
- 미리보기(dryRun=true): 대상 건수/Qoin 합계/스캔/skip 사유(한국어)/truncated 경고/샘플 표(최대 50) + 접힘 raw JSON. eligible=0 이면 빈 상태 + 실행 잠금.
- 입력 변경 시 미리보기 서명 불일치 -> 실행 버튼 잠금 + "입력이 바뀌었어요. 다시 미리보기 하세요". 서명은 reason 제외(reason 은 실행 시점에 입력).
- 실행: 미리보기 성공·서명 일치·대상>0·reason 입력 시에만 활성. openDialog 로 범위 요약 2차 확인 후 dryRun=false 호출. 결과 요약 + historyId 표시, `historyWarning` 은 경고 배너. 에러는 다이얼로그에 표시, 타임아웃 의심 시 멱등 재확인 안내.
- UI 의 Firestore 직접 쓰기 없음.

## 검증
- `node --check` console-data.js / section-admin.js 통과. flutter 무관.
- 회원관리/geo/search 코드 미변경 (viewTools 에서 qoin 호출만 교체).

## 테스트 포인트
- source 전환 시 입력 노출, 검증 메시지, 미리보기 후 입력/조건 변경 -> 실행 잠금, reason 비면 실행 비활성, 강제 요율 경고/격자 거부(예: 0.15, 25), 기간 >31일 거부.
- 실제 commit 은 대상 0건 확인 입력 외 운영 데이터에 실행 금지.
- 실행 결과 historyId/historyWarning 표시 (historyWarning 경로는 수동 재현 어려움, 코드 점검).

## 보류 / 비고
- 브라우저 실동작 미확인(배포 안 함, 오케스트레이터 hosting 배포 예정).
- 강제 요율 입력 시 "별도 확인"은 경고 배너 + 2차 확인 요약에 요율 표기로 대응(추가 확인창 없음).
- CSS 변경 0. `warn` 배너는 기존 클래스 사용(기존 코드에서 동일 사용).
