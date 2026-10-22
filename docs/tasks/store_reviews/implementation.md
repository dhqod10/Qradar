# 매장 평가 (store_reviews) 구현 내역

기준: `spec.md` (§12 전건 확정), `design.md` (+ 맨 끝 "잔여 결정 확정" 우선).

## 구현 파일

### 인프라 (배포 필요)
- `firestore.rules` — `reviews` 블록 교체 (create/update 필드 화이트리스트, grade-score 일치, 주문 자격 `get()` 1회(`reviewOrderEligible` 안의 `let`), `createdAt/updatedAt == request.time`, comment<=300, immutable storeId/userId/createdAt). **14일은 Rules 에 없음. `stores` 블록 무변경.**
- `firestore.indexes.json` — `reviews(storeId ASC, createdAt DESC, __name__ DESC)` (I1), `reviews(storeId ASC, score ASC, __name__ ASC)` (I2, 아래 실측 참조)
- `functions/src/onReviewWritten.ts` (신규) + `index.ts` export. `count()` + `sum('score')` 전량 재계산, `stores` 에 `averageScore/reviewCount` 2필드만 update. 코멘트만 수정(score/storeId 무변경)이면 early return. storeId 변경 시 양쪽 재계산. 매장 문서 없으면 warn 후 skip. 실패는 console.error 후 swallow.

### Core
- `core/utils/review_window.dart` (14일 판정, 카운트다운 캡션), `core/utils/qrator_name.dart`, `core/errors/review_submit_exception.dart`, `core/errors/network_unavailable_exception.dart`

### Domain
- `ReviewEntity` (+orderId, updatedAt), `ReviewRepository`, `SubmitStoreReviewUseCase`(자격 검증: completed/본인/매장 일치/14일, 코멘트 trim), `GetStoreReviewsUseCase`, `GetMyStoreReviewUseCase`

### Data
- `ReviewModel` (`fromMap` 추가, `toFirestoreForCreate/Update` — `serverTimestamp()`, 코멘트 없으면 create 는 키 생략 / update 는 `FieldValue.delete()`), `ReviewRemoteDataSource` (존재 확인 후 create/update 분기, permission-denied/unavailable 변환), `ReviewRepositoryImpl`

### Presentation
- 신규: `customer/review/` (`store_review_form_page`, `store_reviews_page`, `providers/review_di_providers`, `providers/store_review_providers`, `formatters/review_date_formatter`, `widgets/{grade_tile, grade_copy, grade_selector, review_card, store_reviews_view, order_review_action}`), `owner/reviews/owner_store_reviews_page`
- 수정: `GradeBadge`(`미평가` 분기 + `showChevron` + Semantics), `store_menu_header`(배지 탭), `order_detail_page`(completed 분기를 `OrderReviewAction` 으로 분리, cancelled/refunded 불변), `my_store_page`(0건 표시 `미평가 / - / 0`, `리뷰 수` 탭), `lib/dev/seed/phase1_seed_data.dart`(averageScore 0.0 / reviewCount 0, `grade` 필드 삭제)
- 평균 점수는 `StoreReviewsView(showAverage)` 플래그로 분기 — 점주만 true.

### 테스트
- `test/domain/store_review_test.dart` (U1, U2, U3, U5, 이름 마스킹), `test/data/review_model_test.dart` (U4 + 페이로드), `test/presentation/review_date_formatter_test.dart`
- `test_rules/rules.test.mjs` — RV1~RV20 (+변형) 추가, 총 48/48 PASS (RV16/RV17 포함)

## 검증 결과
- `flutter analyze`: No issues found
- `flutter test`: All tests passed (95)
- `functions` `npm run build`: 통과
- Rules: `cd test_rules && npm test` 48/48 PASS
- CF 에뮬레이터(firestore+functions): CF1~CF9 전건 PASS (CF6 시드 오염 4.6/128 -> 3.0/1 자기 치유, CF9 updatedAt/name/status 불변·`grade` 필드 미생성, CF7 코멘트만 수정 시 stores 쓰기 없음). 테스트 스크립트는 scratchpad 의 일회성 파일이며 저장소에 넣지 않았다.

## 인덱스 실측 결과
- I1: 확정 사항으로 추가.
- I2: **실측하지 못했다.** Firestore 에뮬레이터는 인덱스를 강제하지 않아 에러 메시지로 판별할 수 없고, 운영 프로젝트 `runAggregationQuery` 프로브(owner_sales 방식)는 권한 분류기가 차단했다. 그래서 **보수적으로 추가**했다 (불필요해도 무해, 필요한데 없으면 CF 집계가 `failed-precondition` 으로 swallow 되어 조용히 실패). 배포 후 CF1 시나리오(Console 수동 주문 + 평가 1건) 후 Functions 로그에 `FAILED_PRECONDITION` 이 없는지 확인할 것. 에러가 나면 로그의 링크가 요구 인덱스를 알려 준다. 불필요로 판명되면 I2 를 삭제.

## designer 미확인 2건 실측 (Android 에뮬레이터, 실제 렌더, 320dp 강제 + textScale 1.0/1.3)
1. `_CountBadge`(어두운 반투명 채움 + 흰 글자 + 반복 아이콘) vs `미평가`(밝은 `surface` + border + 어두운 글자): **명확히 구분된다.** 자주 가는 매장 카드(140dp)에서 `99회` 와 `미평가` 사이 간격 약 16px. 참고: 기존 `S급 (128)` + `99회` 조합은 0.8px 간격으로 거의 맞닿는다 (이번 변경 이전부터의 문제, `미평가` 는 오히려 여유 증가).
2. 폭 실측 (Roboto/Noto, 추정치 대비):
   - `미평가` 51.1px (추정 53) / 기존 `C급 (-)` 52.9px / `S급 (128)` 66.7px (추정 72)
   - 헤더 chevron 포함: `미평가 >` 67.1px, `S급 (128) >` 82.7px
   - 320dp 메뉴 헤더 (거리 12.3km + 영업 중 + 배지): **overflow 없음**, textScale 1.3 에서도 없음 (`S급 (128) >` 94.9px)
   - 높이: `미평가` 가 border 보정 후에도 1px 작아(24 vs 25) 세로 padding 을 3.5 로 조정해 25px 로 일치시킴. 6개 지점(홈 카드 2종 / 자주 가는 매장 / 지도 시트 / 메뉴 헤더 / 점주 내 매장) 중 앞 3종과 메뉴 헤더는 렌더로 확인, 지도 시트·점주 내 매장은 폭이 `C급 (-)` 이하라 코드상 회귀 없음(렌더 미확인).

## spec/design 대비 차이 · 참고
- 메뉴 헤더 배지 탭 영역: 행 높이를 늘리지 않으려는 design 지시를 지키되 최소 44px 를 확보하기 위해, 헤더 하단 padding 16→5 로 줄이고 배지 위 `SizedBox(8)` 를 제거했다. 시각 위치는 거의 동일하나 이름 행이 약 3px 위로 이동한다.
- 고객 요약 카드 보조줄은 Q2 에 따라 `Qrator 평가 N개` (평균 제외). 점주만 `· 평균 x.x / 4`.
- 고객 `StoreReviewsPage` 의 `store` 는 스냅샷이다 (라이브 구독 안 함). 따라서 "방금 남긴 평가는 등급에 곧 반영돼요" 캡션이 해당 화면에서 CF 반영 후에도 남을 수 있다. 점주 화면은 `myStoreProvider` 로 라이브. 필요 시 `StoreRepository.watchById` 추가(후속).
- 캡션 판정은 목록(내 평가 포함) 길이 기준: `list.length < 50 && list.length != store.reviewCount`.
- 폼은 `OrderEntity` 를 인자로 받는다 (UseCase 자격 검증에 필요). design 의 `storeId/storeName/orderId` 인자를 대체.
- 목록 stream 은 `serverTimestamp` 미확정(pending) 로컬 문서를 일시 제외 (createdAt null 정렬 흔들림 방지); 내 평가 섹션은 `watchMyReview` 로 즉시 보인다.
- 문서 갱신(§10 X1/X3/X4/X5: backlog, data_ownership, role_flows)은 **하지 않았다** — architect 후속.

## 사용자 배포 명령
1. `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only firestore:rules,firestore:indexes` (인덱스 빌드 수 분)
2. `cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only functions:onReviewWritten`
3. Firebase Console: 시드 매장 2문서 `averageScore`→0, `reviewCount`→0 (A5)

## 테스트 포인트 (tester)
- spec §9.1~9.4 전부. M1~M9 는 Console 수동 completed 주문 필요. 특히: 폼 기본 선택 없음 / 선택 시 테두리 primary·타일만 등급색 / 14일 만료(M9) / 코멘트 삭제 후 수정 / 다른 주문에서 진입 시 안내 카드 / 고객 화면에 평균 미노출 / 점주 화면 평균 노출 / 평가 후 수 초 내 `GradeBadge` 갱신 / 지도 시트·점주 내 매장의 `미평가` 렌더.

## 미구현·보류
- 위젯 테스트 없음 (단위만). I2 실측 보류. 삭제 UI / 분포 막대 / 목록 수정 진입은 범위 밖.

## 알려진 사고
- 마무리 단계에서 `dart format lib/data ...` 를 디렉터리 단위로 실행해 **lib/data 하위 55개 무관 파일이 포맷만 변경**됐다. 되돌리기 명령은 보고서 참조.
