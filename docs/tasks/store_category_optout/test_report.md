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

---

# Phase B 테스트 리포트 (2026-10-29, tester)

- 범위: spec §12 / implementation.md Phase B. **미배포 상태** — 코드·단위 레벨 정적 검증 + 재실행만 수행. 라이브 E2E / 에뮬레이터 / Rules 하네스는 미수행.
- 재실행: `flutter analyze` No issues / `flutter test` 921 All passed / functions `npm run build` + `npm test` 341 pass, 0 fail (신규 availableCategories.test.mjs 포함).
- Phase A FAIL(D1, data_ownership.md §2.5 미갱신) 은 워킹트리에서 갱신 확인 (§2.5 + §3 CF 카탈로그 6행) -> 해소.

## 요약

| 구분 | 개수 |
|---|---|
| PASS | 17 |
| FAIL | 0 |
| 보류 | 6 |

## 체크리스트

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| B1 | computeAvailableMainCategories 개인/가맹 분기, 마스터·store-scope approved&&visible, ∩active −excluded, 정렬·중복제거 | PASS | availableCategories.ts 정적 확인 + 단위 테스트 12건 |
| B2 | menuVisibility `applyOverrideForCustomer` import 재사용 (재포팅/복제 없음) | PASS | import 1건, 로직 복제 없음, 소스 가드 테스트 존재 |
| B3 | 승인 override excluded 만 효력 / 미승인 무효 / soldOut 무영향 | PASS | 테스트 가맹 케이스 |
| B4 | recompute: 저장==계산 시 write 생략, 1필드(`availableMainCategories`)만, 400건 청크 | PASS | commitPlans `changed` 필터 + `{[FIELD]: after}` + CHUNK=400 |
| B5 | 브랜드 fan-out 시 마스터 1회 읽기 공유 | PASS | `shared.masters` 캐시 (loadMasters) |
| B6 | 트리거 5개 존재 + index.ts export | PASS | onStoreOwnMenu/Override/Optout/BrandMaster/MainCategoryActive |
| B7 | diff 게이트: 가격·이름 편집 fan-out 없음, 카테고리/visible/승인/생성/삭제 fan-out | PASS | masterMenuRelevance 지문 `카테고리|visible|approved`, 생성/삭제는 null 대비 달라짐 |
| B8 | 루프 가드: availableMainCategories 만 바뀐 store write 재발화 안 함 | PASS | storeDocNeedsRecompute 키 = excluded(정렬)+brandId 만 |
| B9 | active 플립만 전 매장 / 실패 swallow | PASS | effectiveActive 비교, guarded() console.error |
| B10 | 백필: admin 전용, dryRun 기본 true, dryRun 쓰기 0 + before/after 리포트, 실행 시 migrationHistory 1건(affected/total/executedBy), 멱등(전량 재계산) | PASS (코드) | requireAdmin, `dryRun !== false`, early return. 동작 테스트는 소스 grep 수준 -> 보류 #2 |
| B11 | Rules: stores create `!('availableMainCategories' in ...)`, update 화이트리스트 미포함, menuCategories 승인 리셋 목록 불변 | PASS (정적) | firestore.rules diff 1건. 하네스 미작성 -> 보류 #2 |
| B12 | StoreEntity/Model: 읽기전용, 부재시 [], create/coreUpdate/operationUpdate 등 어떤 toFirestore* 에도 없음 | PASS | 모델 쓰기 맵(272/293/336 부근) 미포함 + 단위 테스트 고정 |
| B13 | 홈 칩: mainCategoriesActiveProvider, 표시 label / 비교 id, loading·error·빈 목록 시 섹션 숨김 | PASS | category_filter_section.dart |
| B14 | selectedCategories 초기 빈집합(전체), 최소1개 제약 제거 | PASS | home_providers.dart |
| B15 | filterByCategories / getStoresByCategories: availableMainCategories 기준, 빈 선택 = 전체 | PASS | usecase·repo + 갱신된 단위 테스트 |
| B16 | 점주 폼: 수동 카테고리 칩/필수검증 제거, 저장 시 menuCategories 기존값 보존(재승인 리셋 안 걸림) | PASS | 두 폼 모두 `existing?.menuCategories ?? []` |
| B17 | menuCategories 필드/매퍼/MenuCategories 상수 유지(deprecate), 아키텍처/디자인 규칙(Firebase import, Color(0x) 신규 없음) | PASS | grep 신규 추가 0건 |

## FAIL
없음.

## 관찰 사항 (FAIL 아님)
1. 신규 점주 등록 직후 `menuCategories` 는 `[]` 로 저장된다 (기존엔 필수 선택). Rules 가 비어있음을 요구하지 않음을 확인했으나(필드 존재 화이트리스트만), 관리자 승인 화면의 카테고리 표시가 빈 값이 된다 — 후속 정리 시 표시 제거 권장.
2. 신규 승인 매장은 메뉴 등록 전까지 `availableMainCategories=[]` 이므로 홈 카테고리 필터에는 미노출 (전체 보기에는 노출). 의도된 동작.
3. 홈 필터 칩 선택 상태가 admin 비활성화로 stale 해지면 0건 (알려진 보류 #3과 동일).
4. 범위 밖 변경(`firebase.json`, `.firebaserc`, `functions/package.json` 의 test 스크립트 외 변경 여부, `docs/tasks/web_admin_console/`)이 워킹트리에 혼재 — 커밋 분리 권장.

## 보류
1. 배포 전 — 라이브 E2E (디저트 끈 매장의 홈 필터 미노출, 브랜드 마스터 추가 fan-out, admin 카테고리 비활성 반영). 배포 순서: CF -> 백필(dryRun 먼저) -> Rules -> 앱. **앱을 백필 전에 배포하면 홈 필터 전부 0건.**
2. 에뮬레이터 통합 / Rules 하네스 미작성 (트리거 대상 집합, 백필 dryRun 쓰기 0·2회 멱등·migrationHistory 동작, create 주입 거부/update 거부/정상 payload 회귀). 현재 백필·소스 가드 테스트는 소스 문자열 검증이라 런타임 동작은 미검증.
3. 세션 중 admin 카테고리 비활성화 시 일시 0건 (앱 재실행 해소).
4. availableMainCategories 부재 매장은 필터 미노출 (백필 선행 필요).
5. menuCategories 물리 제거 (후속 커밋).
6. 위젯 테스트 부재 (홈 칩 로딩/에러/빈 숨김, 점주 폼 저장 시 menuCategories 보존) — 정적 검증만.

## 후속 작업 후보 (우선순위)
1. 배포(CF -> 백필 dryRun -> 실행 -> Rules -> 앱) 후 라이브 E2E 1회.
2. 에뮬레이터 하네스: 백필 dryRun/멱등/migrationHistory + Rules create/update 거부.
3. menuCategories 물리 제거 + 관리자 승인 화면 표시 정리.
4. 홈 칩/점주 폼 위젯 테스트, 범위 밖 변경 분리 커밋.
