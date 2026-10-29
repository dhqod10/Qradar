# store_category_optout — Phase A 테스트 리포트

- 작성: tester / 2026-10-29
- 범위: spec Phase A 만 (Phase B 는 별도 사이클, 미구현은 FAIL 아님)
- 방식: 코드 정적 검증 + `flutter analyze` / `flutter test` 재실행. 실기기/에뮬레이터 E2E 와 Rules 에뮬레이터는 미수행.

## 요약

| 구분 | 개수 |
|---|---|
| PASS | 17 |
| FAIL | 1 (문서, 경미) |
| 보류 | 7 |

- `flutter analyze`: No issues found.
- `flutter test`: All tests passed (919건, 신규 `test/core/store_category_optout_test.dart` 포함).

## 체크리스트

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 저장 즉시 반영 + status 불변 | PASS (코드) | `toFirestoreForOperationUpdate` 에만 excluded 추가, status 키 없음. Rules 양 분기 화이트리스트에 추가, status 회귀 규칙 불변. 개인/가맹/브랜드홀더 = 같은 경로. 실기기 확인은 보류 |
| 2 | 전부 OFF 배너/다이얼로그 | PASS | `allOff` 배너(liveRegion), `_confirmAllOff` 돌아가기=false→return(미저장), 저장=true 진행, `wasAllOff` 면 생략 |
| 3 | 휴면 코드 보존 | PASS | `_resolveExcluded` = dormant ∪ OFF active. active loading/error(null) 시 원본 반환. empty 면 active 빈 → dormant=원본 전체 보존 |
| 4 | 고객 탭 숨김 / sticky / 선택 폴백 | PASS | 차집합 및 `isMenuShownOnStoreScreen` 의 excluded 반영. excluded 는 store 문서 기준이라 마스터 추가와 무관(sticky). `effectiveMain` 은 storeMains(excluded 반영) 에 없으면 null 폴백 |
| 5 | 전부 제외 중립 빈 상태 / 0건 회귀 | PASS | `allItems.isEmpty` 가 먼저 평가되어 기존 문구 유지, 그 뒤 가용 0 분기에서 중립 문구. `_EmptyView` 기본값 = 기존 문구 |
| 6 | excluded 확정 전 플리커 | PASS | `excludedAsync.isLoading && !hasValue` → shimmer, 에러 시 `_ErrorView` |
| 7 | 카테고리/개별 제외 독립 | PASS | 카테고리는 문서 필드, override 는 별도 → AND 구조. 재활성 시 override 데이터 미변경 |
| 8 | 검색 필터 / 부분집합 | PASS | 같은 `isMenuShownOnStoreScreen` 사용, `storeSnapshotProvider` 파생(추가 읽기 0) |
| A1 | Entity/Model | PASS | `@Default([])`, fromFirestore 부재→`[]`, create/coreUpdate/brandCreate 맵 미포함(단위테스트로 고정) |
| A2 | Clean Architecture | PASS | 변경 파일에 Firebase import 신규 없음. domain 은 순수 필드만 |
| A3 | AppColors / 하드코딩 | PASS | `Color(0x` 신규 없음 |
| A4 | loading/error/empty | PASS | 카테고리 섹션: shimmer / 에러+재시도 / empty 문구 모두 존재 |
| A5 | analyze / test | PASS | 위 참조 |
| A6 | Rules 변경 | PASS | 2줄 추가, 핵심 필드·승인 메타·Qoin 보호 로직 불변 |
| D1 | docs/processes/data_ownership.md §2.5 갱신 | FAIL | implementation.md 는 갱신했다고 기재했으나 실제 미수정 (git 변경 없음, §2.5 화이트리스트에 excludedMainCategories 없음) |

(PASS 합계는 위 항목 + 세부 분기 기준 17건으로 집계.)

## FAIL

1. (낮음/문서) data_ownership.md §2.5 update 화이트리스트에 `excludedMainCategories`(및 기존 누락분 `temporaryClosed, closedDates, imageUrls`) 미반영. CLAUDE.md 상 Rules 와 문서 silent drift 방지 대상. 우선 수정 1순위.

## 관찰 사항 (FAIL 아님)

- Rules 가 `excludedMainCategories` 의 타입(list)/원소 타입을 검증하지 않음. 점주가 비정상 값을 쓰면 클라이언트는 `whereType<String>` 으로 방어하므로 영향 제한적. Phase B 의 Rules 보강 때 `is list` 가드 권장.
- 범위 밖 변경이 워킹트리에 섞여 있음: `image_upload_field.dart`(fit 파라미터), `brand_info_form_page.dart`(logo contain), `firebase.json`, `.firebaserc`, `landing/`. 이 기능 커밋에 포함하지 말고 분리 커밋 권장.
- 검색 결과는 `storeSnapshotProvider`(스냅샷) 기준이라 점주가 막 저장한 직후 갱신은 스냅샷 재조회 시점에 따라 지연될 수 있음. 매장 탭은 `watchedStoreProvider` 구독이라 즉시 반영. (검색 2단계 진입 시 매장 화면이 최종 판정하므로 UX 영향 작음.)

## 보류

1. Phase B 전체 (검색 통합 / menuCategories 은퇴 / CF backfill) — 별도 사이클.
2. 홈 "카테고리로 매장 찾기" excluded 미반영 — Phase B 에서 정합화.
3. `firestore.rules` 미배포 — 배포 전 점주 저장 시 permission-denied (사용자 배포).
4. Rules 에뮬레이터 하네스 미작성. 제안 케이스: (a) 점주 `excludedMainCategories` 단독 update 허용, (b) 가맹/브랜드홀더 동일, (c) excluded + status:'approved' 동시 변경 거부, (d) 타인 매장 거부, (e) create 시 excluded 포함 동작 확인, (f) 기존 정상 payload 회귀.
5. 설정 변경 이력(audit A2) 보류.
6. 위젯/통합 테스트 부재: 폼의 전부 OFF 다이얼로그 분기, 휴면 보존, 매장 페이지 shimmer/중립 빈 상태는 현재 단위 테스트가 커버하지 않음 (정적 검증만). 위젯 테스트 추가 권장.
7. 실기기 E2E (개인/가맹/브랜드홀더 저장 반영, 검색 부분집합) 미수행.

## 후속 작업 후보 (우선순위)

1. data_ownership.md §2.5 갱신 (FAIL 해소).
2. Rules 배포 후 E2E 1회 + 에뮬레이터 하네스 작성.
3. 폼/매장 페이지 위젯 테스트 보강.
4. 범위 밖 변경 분리 커밋.
