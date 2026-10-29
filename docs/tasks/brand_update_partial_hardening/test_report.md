# brand_update_partial_hardening — test_report

검증 방식: 정적 리뷰 + 단위/전체 테스트. 에뮬레이터 Rules 하네스 없음(미실시). 실기기는 보류.

| # | 항목 | 결과 |
|---|---|---|
| 1a | brand upsertBrand coreChanged: set -> 부분 update. 전송 = name/logoUrl/description(null->FieldValue.delete)/companyName/status=pending/submittedBy/submittedAt/updatedAt. createdAt/approvedBy/approvedAt/brandKey/rejectedReason 미전송. 신규등록/logoUrl-only/_writePrivate 불변 | PASS |
| 1b | master 메뉴 updateMasterMenuItemCore: update 유지, createdAt/approvedBy/approvedAt 만 remove. status=pending/submittedBy/At 등 유지 | PASS |
| 1c | override upsertOverrideCore: approvedBy/approvedAt 제거, set merge:true 유지. MenuOverrideModel 에 createdAt 없음 확인 | PASS |
| 2 | 보존 의미: pending 회귀 + submitted 갱신, 승인 메타는 미전송/merge 로 Firestore 값 유지 | PASS |
| 3 | Rules 정적 추론: noSelfApproveOnUpdate 는 affectedKeys 기반 -> approvedAt 미전송이므로 승인된 문서 수정 통과. noSelfApproveOnCreate 는 get(.., null) 이라 키 부재 시 통과(신규 생성 OK). override create/update 양쪽 해당 | PASS (정적) |
| 4 | Clean Architecture: data 레이어 3파일 한정, domain/presentation 시그니처 불변 | PASS |
| 5 | 범위: lib 3 repo + test 1 파일만 변경, 포맷 노이즈 없음, firestore.rules/functions 무변경. (landing/console 변경은 별건 작업 트리, 본 기능 무관) | PASS |
| 6 | flutter analyze: No issues. flutter test: 전체 통과(+921). 이번 실행에서 flaky 실패 재현 안 됨 | PASS |
| 7 | brand_private_profile_repository_test: set->update 기대, 보존키 4종 미전송 단언, sets 비어있음, calls ['update','private'] 정합 | PASS |
| - | 승인된 브랜드 메뉴/정보/오버라이드 실제 수정의 Rules 통과 (에뮬/실기기) | 보류 |

요약: PASS 9 / FAIL 0 / 보류 1.

## 후속 후보
- 메뉴(updateMasterMenuItemCore)/오버라이드(upsertOverrideCore) 경로 단위테스트 부재: payload 에 approvedBy/approvedAt/createdAt 부재 단언 추가 권장.
- Rules 에뮬 테스트 하네스 도입 시 승인 상태 문서 수정 회귀 케이스 추가.
- 실기기 배치 실테스트에서 승인된 브랜드 메뉴 수정 확인.
