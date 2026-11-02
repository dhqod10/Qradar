# search_keyword_enhancement 구현 기록 (groundwork 범위)

기준: `spec.md`. 사용자 확정: **D1 = groundwork only** (질의 경로 불변), D2 = 매장만, D3~D6 = 권고안.

## 구현 완료

| # | 항목 | 위치 |
|---|---|---|
| 1 | `StoreEntity.searchKeywords` / `StoreModel.searchKeywords` (읽기 전용, `fromFirestore` 파싱만. 어떤 `toFirestore*` 에도 미포함) | `lib/domain/entities/store_entity.dart`, `lib/data/models/store_model.dart` (+ freezed 재생성) |
| 2 | 토크나이저 Dart | `lib/core/utils/search_keyword_tokenizer.dart` (`buildKeywords`, `queryTokens`) |
| 2 | 토크나이저 TS | `functions/src/searchKeywords.ts` |
| 2 | cross-golden 계약 | `test_fixtures/search_keyword_contract.json` (Dart/TS 가 같은 파일을 읽어 동일 벡터 검증) |
| 3 | I/O 코어 (소스 조립, 브랜드명 캐시, 멱등 쓰기) | `functions/src/recomputeSearchKeywords.ts` |
| 3 | 트리거 2개 `onStoreSearchSourceWritten` / `onBrandSearchNameWritten` | `functions/src/onSearchKeywordsSourceWritten.ts` |
| 4 | callable `backfillStoreSearchKeywords` | `functions/src/backfillStoreSearchKeywords.ts` |
| - | export | `functions/src/index.ts` |
| 5 | Rules: create 가드 `!('searchKeywords' in request.resource.data)`; update 화이트리스트는 원래 미포함이라 변경 없음 | `firestore.rules` |
| 6 | data_ownership 갱신 (CF 전담 필드 + CF 카탈로그 3행) | `docs/processes/data_ownership.md` |

토크나이저 규칙: source 별 trim → 소문자 → 공백분할, 단어별 전 prefix + 공백제거 전체 문자열 전 prefix, 삽입순서 보존 중복제거, 300 초과 시 앞에서 절단. 길이는 code point 기준(Dart runes ↔ TS `Array.from`). 질의 토큰: 공백분할·중복제거·최대 10개.

소스 조립: 매장 `name` + (brandId 가 있고 브랜드 문서에 name 이 있으면) 브랜드 `name` + `menuCategories` 문자열 원소 그대로. 주의: `menuCategories` 는 저장된 값(코드 문자열 예 `coffee`)을 그대로 쓴다 — 한글 라벨 매핑은 하지 않았다(spec 의 "라벨" 해석 확인 필요, 아래 보류 참고).

루프 가드: `storeSearchSourceChanged` 가 name/brandId/menuCategories 만 비교 → 트리거 자신의 `searchKeywords` 쓰기는 무시. 계산 결과가 저장값과 같으면 write 생략.

## 테스트 / 검증 결과

- `functions`: `npm test` (tsc build + node --test) 545 pass / 0 fail. `test/searchKeywords.test.mjs` 를 `package.json` test 목록에 등록.
- Rules 하네스 `test_rules` `npm test`: 490/490 PASS (신규 SK-1~SK-6).
- `flutter analyze`: No issues. `flutter test`: 전체 통과 (신규 `test/core/search_keyword_tokenizer_test.dart`).
- 질의 경로 불변: `searchStoreResultsProvider` / `SearchStoresUseCase` / 메뉴 검색 / SearchPage / landing 은 수정하지 않음.

### tester 테스트 포인트
1. Dart↔TS 동일 벡터: 계약 JSON 에 케이스 추가 시 양쪽 테스트가 함께 깨지는지.
2. Rules: SK-1/1b(create 거부), SK-2/2b(owner update 거부), SK-4/5(정상 payload 회귀), SK-6(read).
3. 트리거 게이트: 무관 필드/자기 파생 쓰기 무시, 생성·name·brandId·menuCategories 변경 시 재계산, 브랜드 name 변경만 fan-out (단위 테스트 있음. 에뮬레이터 e2e 는 미작성).
4. backfill: dryRun 쓰기 0, 재실행 `affected: 0`(멱등), 실행 시 `migrationHistory` 1건 (소스 가드 테스트만 있음, 실제 호출은 배포 후).
5. 회귀: 홈/검색/메뉴 검색 동작 불변, 매장 등록·수정 정상.

## 배포 / 백필 준비 절차 (사용자 수행)

1. `firebase deploy --only firestore:rules,functions` (rules 와 CF 신규 3개 export 포함). 앱 릴리스는 불필요(클라이언트는 읽기 필드만 추가).
2. 콘솔(또는 callable)에서 `backfillStoreSearchKeywords` `{dryRun:true}` → `affected` 확인 → `{dryRun:false}` 실행 → 재실행 시 `affected:0` 확인, `migrationHistory` 1건 확인.
3. **인덱스: 추가 불필요.** 질의 전환 전이라 쿼리가 없고, 전환 시에도 단일 필드 array 인덱스는 자동 생성(D5). `firestore.indexes.json` 미변경.

## 미구현 / 보류

- **질의 전환**: `searchStoreResultsProvider` 재배선, `SearchStoresUseCase.rankAndFilter`, `StoreRepository.searchStores`, `StoreRemoteDataSource.searchByKeywords`(array-contains-any), `searchReadRetry` 적용 — 전부 다음 '전환' 단계. 토크나이저 Dart `queryTokens` 는 그때를 위해 준비됨(미사용).
- **메뉴 키워드화(Phase 2)**: 현 클라이언트 fan-out 유지.
- **menuCategories 라벨**: 한글 라벨 사전 매핑 미적용(저장된 문자열 그대로). 필요 시 CF 소스 조립(`assembleSources`) 한 곳과 계약 변경으로 대응.
- **admin 쓰기**: Rules 의 admin 전권 update 분기는 `availableMainCategories` 와 동일하게 `searchKeywords` 를 막지 않는다(SK-3 로 문서화). 막으려면 별도 결정.
- CF 에뮬레이터 e2e(`test:emulator`) 케이스 미추가.
- landing/console 백필 버튼은 사용자 작업(미접촉).
