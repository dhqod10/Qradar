# brand_self_approve_guard 테스트 리포트

검증 방식: **정적 리뷰** (firestore.rules diff + 문서 diff + 관련 Repository 코드 대조). Rules 에뮬레이터 하네스 없음 → 실행 검증 아님. 실행 검증은 백로그(하네스 부재) + 사용자 배포 후 수동 스모크로 이관.

## 결과 요약: PASS 7 / FAIL 0 / 보류 1 (Rules 파싱)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 헬퍼 로직 | PASS | create: `get('status','pending')=='pending'` && approvedBy/At `get(..,null)==null` (부재/null 통과, approved/non-null 거부). update: diff 에 해당 키가 있을 때만 값 검사 → status 미변경이면 현재 approved 여도 통과(운영 update 회귀 없음). 신규 get() 0 (map.get 만). status 키 삭제는 `''` != pending 이라 거부(안전 방향). |
| 2 | V1/V2/V3 create·update 각각 적용 | PASS | V1 brands/menuItems, V2 menuOverrides, V3 stores/menuItems 브랜드 분기 모두 create=Create 헬퍼, update=Update 헬퍼 분리 적용. admin 전권·delete(V1/V3 분리 후 원 조건 동일, V2 불변)·점주 분기·`ownerOverrideCreateOk`/`onlyChangedFields` 불변. |
| 3 | 정당 플로우 회귀 | PASS | 브랜드 create(pending/메타 null) 통과. 재제출(→pending, 승인메타 미변경)·내용수정 통과, `leavingRejectedClearsApproval` 미사용. 운영 update 통과. `upsertOverrideCore`(status pending, `set`) : 신규=create 통과, 기존=status 변경 pending OK, approvedBy/At 는 엔티티 값을 그대로 재기록(미변경 → diff 없음)이라 통과. 점주 W2 upsert(`_assertOwnerOfBrandStore`, 점주 분기 불변)·admin approve/reject(isAdmin 분기) 영향 없음. 브랜드/점주 OR 평가라 브랜드 분기 실패가 점주 분기를 막지 않음. |
| 4 | 악의 케이스 차단 | PASS (논리상) | 브랜드의 create/update 로 status→approved/rejected, approvedBy/At non-null 쓰기 모두 헬퍼에서 false → 거부. |
| 5 | menuOverrides 필드명 | PASS | `menu_override_repository_impl.dart` 의 status/approvedBy/approvedAt 와 일치 (master 메뉴도 동일). |
| 6 | 문서 동기화 | PASS | §2.6/§2.8/§5.2/§5.4/§5.5 가 Rules 와 일치, V3 닫힘 + 점주 분기 ⚠️ 잔존(D2) 명시, backlog 등재 확인. |
| 7 | D2 범위 밖 미변경 | PASS | stores/menuItems 의 `isStoreOwner(storeId)` 분기 diff 없음. |
| 8 | Rules 파싱 | **보류** | firebase CLI 15.12.0 에뮬레이터 로드 시도했으나 로컬 Java < 21 이라 기동 불가("firebase-tools no longer supports Java version before 21"). **firebase CLI 파싱 미검증, 정적 구조 리뷰만** (diff 상 괄호·`&&`/`||` 우선순위 정상: 헬퍼 호출은 괄호로 감싸 `||` 결합 안전). 배포는 실행하지 않음. |

## FAIL: 없음

## 보류 / 후속 후보 (우선순위 순)
1. (배포 전 권장) JDK 21+ 설치 후 에뮬레이터 로드로 문법 확인, 또는 배포 시 CLI 컴파일 단계(`firebase deploy --only firestore:rules`)의 오류 출력 확인. 이후 수동 스모크: 브랜드 메뉴 생성/수정/재제출/운영수정/가격 오버라이드, admin 승인/반려, 점주 품절 토글.
2. (낮음) 승인된 오버라이드를 브랜드가 `set` 으로 재제출할 때 approvedAt 을 엔티티 DateTime 으로 재기록 — 마이크로초 왕복 불일치가 있으면 "변경된 non-null" 로 거부될 이론적 위험. 스모크에서 확인.
3. 백로그: Rules 에뮬레이터 하네스 구축(본 가드의 PPA-유사 케이스 추가), D2 stores/menuItems 점주 분기 self-approve(이미 등재).
