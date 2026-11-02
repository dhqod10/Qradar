# search_keyword_enhancement (groundwork) 테스트 리포트

검증일: 2026-11-02 / 범위: groundwork (질의 경로 전환 없음)

## 요약
PASS 21 / FAIL 0 / 보류 3

## 자동 검증
| 항목 | 결과 |
|---|---|
| functions `npm test` (tsc + node --test) | 545/545 PASS |
| test_rules `npm test` | 490/490 PASS (SK-1~6 포함) |
| `flutter analyze` | No issues |
| `flutter test` | 1089 전체 통과 (토크나이저 계약 테스트 포함) |

## 중점 검증
1. 범위 준수 - PASS: lib/presentation, lib/domain/usecases, lib/data/repositories 변경 없음. searchStoreResultsProvider, SearchStoresUseCase, 메뉴 검색, SearchPage 무변경. lib 에서 searchKeywords/토크나이저 참조는 entity, model, tokenizer 파일뿐 (queryTokens 미사용 확인).
2. 읽기전용 필드 - PASS: StoreModel 은 fromFirestore 파싱만. toFirestoreForCreate/CoreUpdate/OperationUpdate/BrandCreate 어디에도 없음. 도메인 엔티티 기본값 [] 로 부재 안전.
3. 토크나이저 동일성 - PASS: Dart(runes), TS(Array.from) 규칙 일치 (trim, 소문자, 공백분할, 단어 prefix, 공백제거 전체 prefix, 삽입순 중복제거, 300 절단, 질의 10개). 양쪽 테스트가 같은 test_fixtures/search_keyword_contract.json 을 읽음.
4. CF 게이트 - PASS: storeSearchSourceChanged 는 생성 true, 삭제 false, name/brandId/menuCategories 비교만 -> 자기 파생(searchKeywords) 쓰기 무시(루프가드). brandNameChanged 는 생성/삭제 제외 name 변경만. 계산 결과 동일 시 write 생략(sameKeywords). 쓰기는 searchKeywords 1필드만. 실패 swallow + 백필 치유.
5. backfill - PASS: requireAdmin, dryRun 기본(!== false), dryRun 쓰기 0, 400건 청크, 전량 재계산 멱등(재실행 affected 0), 실행 시 migrationHistory 1건. (실제 callable 호출은 배포 후 확인 필요 - 보류 1)
6. firestore.rules - PASS: create 가드 `!('searchKeywords' in request.resource.data)`, update 화이트리스트에 부재(owner/brand 거부), 정상 payload 회귀(SK-4/5) 통과, read 허용(SK-6). SK-1~6 케이스 타당.

## CLAUDE.md 절대규칙
- Firebase SDK 는 functions 에만. presentation/domain 에 import 없음: PASS
- secret 하드코딩 없음: PASS
- 색상/UI 변경 없음: PASS

## 판단점 문서화 적정성
- admin searchKeywords update 미차단: 적정. SK-3 테스트와 implementation 보류에 availableMainCategories 와 동일 수준으로 명시.
- menuCategories 저장 코드 그대로 토큰화: 적정. implementation "미구현/보류" 에 명시 (assembleSources 한 곳 + 계약 변경으로 대응).

## 보류
1. backfill 실제 호출/migrationHistory, 트리거 e2e 는 에뮬레이터 케이스 없음, 배포 후 확인 필요 (단위/소스 가드만 검증됨).
2. 범위 밖 변경 감지: `landing/console/assets/console-data.js`, `section-admin.js` 에 백필 버튼(runBackfillSearchKeywords)이 작업 트리에 존재. implementation 은 "landing/console 미접촉(사용자 작업)" 이라 했으므로 사용자가 추가한 것으로 보이나, 이 task 의 groundwork 산출은 아님. 커밋 시 분리 및 landing 배포 규칙(hosting 만, git add landing/) 확인 권장.
3. menuCategories 한글 라벨 매핑 여부는 전환 단계 전 결정 필요 (spec 라벨 해석).

## FAIL
없음. 배포는 수행하지 않음.
