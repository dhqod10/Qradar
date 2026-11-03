# qoin_policy_admin_ui — test_report

검증: tester / 2026-11-03. 방식: 코드 정독 + `node --check` + 입력검증 함수 단독 실행 + 서버 callable 시그니처 대조 + git diff. 브라우저 실동작·운영 요율 변경은 수행하지 않음(돈 정책).

## 요약
- PASS 22 / FAIL 0 / 보류 3 (전부 경미·후속)
- 배포 영향: hosting 전용. `functions/`, `firestore.rules`, `firebase.json`, 인덱스 diff 0건. (`lib/`·`test/` 변경은 별건 existing_user_phone_collection 작업분이며 이 기능과 무관.)

## 검증 결과

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | `node --check` console-data.js / section-admin.js | PASS | 양쪽 통과 |
| 2 | `setQoinAccrualRate` 래퍼 = callable 시그니처 | PASS | `{scope, targetId?(global 제외), rate XOR clear, reason?}`. 서버 상단 주석과 일치 |
| 3 | `setQoinAccrualEnabled` 래퍼 | PASS | `{scope, targetId, enabled:boolean, reason?}`. 전역 scope 호출 경로 없음 |
| 4 | `applyBrandQoinRate` 래퍼 | PASS | `{brandId, mode, rate XOR clear, reason?, resumeHistoryId?}`. 서버는 재개 시에도 `mode`를 요구하는데 UI 가 `overwrite` 고정 전송(서버가 재개는 overwrite 이력만 허용하므로 일치). 120s 타임아웃 |
| 5 | 기존 읽기 함수 유지 | PASS | getQoinConfig / listQoinHistory / listQoinHistoryOf 그대로 사용 |
| 6 | viewQoin: "읽기 전용" 태그 제거 + 전역 편집(모달 → 2차 확인 → 사유 필수) | PASS | `openQoinRateDialog` 2단계, `allowClear:false` 로 전역 clear 미제공 |
| 7 | 게이트: spend 조작 UI 없음 | PASS | `setQoinSpendPolicy`/`spendEnabled`/`minSpendUnit`/`minCashFloor` 가 console 전체에서 0건 (`section-admin.js` 의 언급은 주석 1줄뿐, import 에도 없음) |
| 8 | 게이트: 비상정지(`config/qoin.enabled`) 토글 없음, 전역 스위치 쓰기 없음 | PASS | 비상정지는 `loadQoinInto` 읽기 카드만. 스위치 다이얼로그는 scope 'brand'/'store' 에서만 호출됨 |
| 9 | 콘솔 Firestore 직접쓰기 0건 | PASS | section-admin.js 에 setDoc/updateDoc/addDoc/deleteDoc/writeBatch/runTransaction/sendUpdate 0건. 신규 쓰기는 `httpsCallable` 3종뿐 |
| 10 | 입력검증 허용 3 / 2.5 / 0.1 / 20 | PASS | `parsePctInput` 단독 실행: 0.03 / 0.025 / 0.001 / 0.2 |
| 11 | 입력검증 거부 0 / 0.05 / 20.1 / 문자 | PASS | 모두 `ok:false`. 추가: 빈값, `1e1`, `-1`, `3.`, `.5`, `0.0` 거부. `3%`·`20.0` 허용(정상). 서버 `isValidCallableRate` 와 같은 0.1% 격자·경계 |
| 12 | 확인단계: 전 → 후 값 표시 + 사유 필수 | PASS | 2단계 화면 "현재 → 새 값" + 사유 표시. `validateReason` 공백 거부, 200자 상한(서버 상한과 동일) |
| 13 | 스위치: 확인 + 사유 필수, OFF 시 회수 유지 고지 | PASS | `openQoinSwitchDialog` |
| 14 | viewBrandDetail/viewStoreDetail: approved 일 때만 카드 마운트 | PASS | `st === 'approved'` 조건 2곳 |
| 15 | 브랜드 일괄 preserve/overwrite, 영향 고지, 브랜드 OFF 경고, overwrite 비가역 경고 | PASS | `openBrandBulkDialog`. 스위치는 건드리지 않는다고 명시 |
| 16 | 진행중 잠금 | PASS | `bulkPointerState`: in_progress 5분 이내 = locked(버튼 disabled). 서버 `BULK_STALE_MS` 와 동일 5분 |
| 17 | partial/방치 in_progress 재개 | PASS | resume 배너 + `resumeHistoryId`. 서버 재개 재검증(포인터·현재값 일치)에 의존 |
| 18 | 매장: 소속 브랜드 일괄 진행중 / 브랜드 조회 실패 시 차단(fail-closed) | PASS | `writeBlocked = locked || parentUnknown`, 안내 배너 |
| 19 | 영어 서버 오류 → 한국어 일반문구 | PASS | `qpErrText`: precondition/invalid 이고 한글 없는 메시지는 일반문구로 치환 |
| 20 | 회귀: 적립소급 폼 / geo·search 백필 / 회원관리 | PASS | `qoinPanelHtml`/`wireQoin`/`runBackfillQoinAccrual`/`wireTool` 호출 유지(491-495행). viewUsers·setUserSuspension 영역에 diff hunk 없음. 이 작업의 삭제 라인은 import·매장목록 링크 셀·viewQoin 헤더뿐(TOOLS.qoin 삭제는 선행 작업분) |
| 21 | 개발자 추가분: 매장목록 "Qoin 설정 →"(approved), viewQoin 브랜드 목록, HIST_FIELD.accrualEnabled | PASS | pending 행 링크 유지, 라우트 `#/stores/pending/:id` 가 approved 도 렌더(상세 카드 조건 확인). 기존 흐름 파괴 없음 |
| 22 | 미정의 식별자 점검 (`node --check` 는 못 잡음) | PASS | field/openDialog/targetBlock/setFieldError/toDate/RATE_*/parse*/resolve*/qoinRateText/listQoinHistoryOf 모두 import 존재·export 확인 |
| 23 | landing 배포 규칙 | PASS | 변경은 landing/console/assets 2파일 + docs 뿐 |

## 보류 / 경미 (FAIL 아님)
1. **재개 버튼 비활성 미처리** (implementation 보류 항목): `qoinBulkHistoryId` 부재 시 `resumeHistoryId` 가 빠져 payload 에 rate/clear 도 없어 서버가 `invalid-argument` 로 거부 → 한국어 일반문구 표시. 돈·데이터 영향 없음(fail-safe). **리스크 낮음.** 필요하면 `qoinBulkHistoryId` 없을 때 버튼 disabled.
2. **일괄 영향 범위가 `listAllStores` 전량 읽기** (보류 항목): 정보 표시용이고 실패해도 적용 가능(경고 배너)하며 적용 로직 자체는 서버가 스캔. 매장 수 증가 시 읽기 비용·지연만 문제. **리스크 낮음**, 매장이 수백 건 넘으면 브랜드 단위 쿼리(`where brandId`)로 교체 권장.
3. **오류 문구 일부가 승인 큐 어투**: `writeErrorText` 의 permission/offline/timeout 문구가 "항목은 아직 대기 중이에요" 를 포함해 Qoin 설정 변경 맥락과 어색함. 또한 커스텀 `onError` 라서 기본 핸들러의 세션 만료 처리(`expired` 재로그인)·`unknown`(timeout) 시 확정 버튼 잠금이 적용되지 않음. 적립률은 같은 값이면 서버가 noop 이라 재시도 안전하며, 일괄은 안내 문구가 있어 실해 낮음. 후속 문구 정리 후보.

## 미검증 (한계)
- 실제 브라우저 동작, 모달 2단계 UX, 이력 1건 생성(before/after/changedBy)은 운영 데이터 변경이 필요해 수행하지 않음. 스테이징/에뮬레이터 또는 사용자가 소액·동일값(noop) 호출로 확인 권장. 서버 이력 기록은 기존 CF 책임.

## 결론
FAIL 0. 게이트(spend 미배선·비상정지 토글 없음·전역 스위치 쓰기 없음)와 callable 경유(직접쓰기 0), 입력검증이 코드로 확인됨. 배포(hosting) 진행 가능. 실배포 후 noop(동일값) 호출로 1회 스모크 권장.
