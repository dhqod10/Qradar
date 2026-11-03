# qoin_accrual_backfill_admin_ui 테스트 리포트

방식: 코드 정독 + `node --check` + 로직 검증. 브라우저 실구동 및 운영 commit(dryRun=false) 실행은 하지 않음.

## 결과 요약: PASS 15 / FAIL 0 / 보류 3 (경미 이슈 1건 포함)

| # | 항목 | 결과 |
|---|---|---|
| 1 | node --check console-data.js / section-admin.js | PASS |
| 2 | runBackfillQoinAccrual: 서버 키 9종만 전송, null/undefined 제외, dryRun 항상 boolean | PASS |
| 3 | 구형 `(dryRun, source)` 호환 (typeof object 분기). 현재 구형 호출부는 없음(geo/search 는 별도 함수) | PASS |
| 4 | source 4종 전환 시 입력 노출(orderIds/storeId/range) | PASS |
| 5 | 클라 검증: orderIds 1~500·중복제거·"/" 거부, storeId, to>from, ≤31일, limit 1~500 정수 | PASS |
| 6 | overrideRate: 0.1~20%, 0.1% 격자, %→소수 변환. 서버 isValidCallableRate(0.001~0.2, tenths 격자)와 일치. Math.round(t)/1000 으로 부동소수 오차 없음(0.3→0.003, 20→0.2) | PASS |
| 7 | 강제 요율 입력 시 warn 배너 | PASS |
| 8 | 인터락(a): 미리보기 후 입력 변경 시 서명 불일치 → 실행 잠금 + 안내 배너 | PASS |
| 9 | 인터락(b)(c): same && eligible>0 && reason 모두 충족해야 실행 활성 | PASS |
| 10 | 인터락(d): doCommit 에서 서명/reason/대상 재검증 → openDialog 요약 확인 후 dryRun=false. 미리보기 진행 중 입력 변경 레이스도 서명 스냅샷으로 방어 | PASS |
| 11 | 인터락(e): Firestore 직접 쓰기 없음(callable 만) | PASS |
| 12 | historyId 표시 / historyWarning 경고 배너 / 에러·타임아웃(멱등 안내) 표시 | PASS |
| 13 | 회귀: geo/search wireTool·TOOLS 유지(TOOLS.qoin 만 제거), 회원관리·#/users 코드 diff 무관 | PASS |
| 14 | 배포 경계: git status 상 functions/ firestore.rules firebase.json 변경 0, 수정은 landing/console/assets 2파일뿐 | PASS |
| 15 | XSS: banner/kv/table 값 전부 esc 경유 | PASS |
| 16 | CSS `a-banner warn` 정의 미확인 보류 해소: console.css:74 에 `.a-banner.warn` 정의됨 (리스크 없음) | PASS (보류 해소) |

## 이슈 / 보류
- [경미 UX] 입력을 바꿨다가 미리보기 서명과 같은 값으로 되돌리면 "입력이 바뀌었어요" 배너(msg)가 남은 채 실행 버튼은 활성화됨. 안전성(서명 비교)에는 영향 없음. 되돌림 시 배너 제거 권장.
- [보류 1] overrideRate "별도 확인" 생략: 경고 배너 + 2차 확인 요약에 요율 표기로 대체. commit 직전 요약에 요율이 명시되고 서명 일치·reason 필수라 실제 리스크 낮음. 후속에서 강화 여지(요율 재입력 확인 등).
- [보류 2] 브라우저 실동작 미확인(스피너, hidden/display 토글, datetime-local 파싱, 다이얼로그 흐름). 배포 후 대상 0건 dryRun 으로 스모크 권장. 서버 from/to 가 millis 를 받는지는 spec 근거(ISO/millis)에 의존, callable 실호출 미확인.
- [보류 3] section-admin.js 의 working tree diff 에 이번 작업 외 qoin_policy_admin_ui(정책 편집 UI, console-data.js 의 setQoinAccrualRate 등) 변경이 함께 들어 있음. hosting 배포 시 둘이 같이 나가므로 의도 확인 필요.

## 우선순위 / 후속
1. FAIL 없음. 배포 후 스모크(issues dryRun) 권장.
2. 경미 UX 배너 잔존 수정(선택).
3. qoin_policy_admin_ui 와 번들 배포 여부 확인.
