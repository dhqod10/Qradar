# 매장 평가 (store_reviews) 테스트 리포트 (정적 검증)

- 검증자: tester / 일자: 2026-10-22
- 범위: 정적 검증 + Rules 하네스 재실행. **라이브(에뮬레이터/실기기) 검증은 미수행** (사용자 수행 예정)
- 기준: spec.md §12 확정, design.md (끝 "잔여 결정 확정" 우선), implementation.md
- 전제로 수용한 사실(재검증 안 함): analyze 0 issue / flutter test 95 pass / CF tsc 통과 / CF 2필드 write / lib/data 포맷 사고 복구 / tmp 파일 제거

## 1. 요약

| 구분 | 개수 |
|---|---|
| PASS | 9 (중점 ①~⑨ 중 ①②③④⑤⑥⑦⑧⑨ 코드 기준. 단 ⑤⑧⑨ 에 아래 보류/권고 부속) |
| FAIL | 1 (F1) |
| 보류 | 3 (H1 CF 조용한 실패, H2 지도 시트·점주 내 매장 렌더 미확인, H3 라이브 M1~M9) |
| 시나리오 결함 | 5 (S1~S5, §6) |
| 권고(Low) | 4 (§7) |

**가장 먼저 수정할 항목: F1 (작성자 익명 코드가 Kakao/Naver 사용자 전원 동일)**

## 2. FAIL

### F1 [High] `maskedQratorName` 이 Kakao 사용자 전원을 `Qrator kaka` 로 표기
- 근거: `functions/src/verifyKakaoToken.ts:82` uid = `kakao_${kakaoUid}` (Naver 도 동일 패턴의 Custom Token 경로, `auth_remote_data_source.dart` 주석 참조). `lib/core/utils/qrator_name.dart` 는 `uid.substring(0, 4)` → Kakao 계정은 항상 `kaka`.
- 영향: spec A3 "Qrator + uid 앞 4자" 의 목적(작성자 구분)이 소셜 로그인 사용자에게는 달성 불가. 리뷰 목록의 모든 Kakao 작성자가 같은 이름. 폼 하단 고지(`Qrator kaka`)도 무의미. 내 평가 판별은 `userId` 비교라 기능 오동작은 아님.
- 원인은 spec/design 의 "앞 4자" 규칙 자체(구현은 그대로 따름). 단위 테스트(`store_review_test.dart` maskedQratorName)도 `a3f9xyz` 같은 가상 uid 만 써서 못 잡음.
- 제안: 접두사(`kakao_`/`naver_`) 제거 후 앞 4자, 또는 uid 끝 4자, 또는 uid 해시 4자. 결정은 architect (A3 재확정 필요, 사용자 확인 사항). 테스트에 `kakao_123456`, `naver_…` 케이스 추가.

## 3. 중점 검증 결과

### ① 카피 문자열 — PASS
design.md "카피 문자열 전체" 와 코드를 글자 단위 대조. 불일치 0건.
- 등급 4종 이름/설명: `grade_copy.dart` 일치
- 폼: AppBar `매장 평가`/`평가 수정`, `이 매장에 대한 내 평가`, `음료·서비스·분위기를 종합해서 골라주세요`, `한마디 남기기`+` (선택)`, hint, `{n}/300`, 안내 2줄(코드 치환), 다른 주문 안내, `평가 등록`/`수정 완료`, 비활성 hint, 이탈 다이얼로그 4문구 일치
- 스낵바 6종: 등록/수정 2종(`order_review_action.dart`), 일반/권한/14일/네트워크 4종(`store_review_form_page.dart`) 일치
- 주문 상세 3상태: `이 매장은 어땠나요?`/`Qrator 의 평가가 매장 등급을 만들어요`/`매장 평가하기`, `오늘까지…`/`{N}일 후…`, `이 매장에 남긴 내 평가`/`{S급} · {이름}`/`평가 수정`, `평가 기간(14일)이 지났어요`, `수정 기간(14일)이 지났어요`, 로드 실패 일치
- 리뷰 목록: AppBar(`매장 평가`/`받은 평가`), 요약, 반영 캡션, `내 평가`/`전체 평가 {N}개`, 날짜 5종+`· 수정됨`, `최근 50개 평가를 보여드려요`, 에러·빈 상태(고객/점주), 로딩 접근성 일치
- 배지 `미평가`(접근성 `아직 평가가 없는 매장`), 점주 지표 `미평가 / - / 0` 일치

### ② 확정 사항 준수 — PASS
- `Icons.star*` / `Icons.thumb_*` / ★ : 신규·수정 파일 0건 (저장소 내 2건은 기존 option_group 화면의 `star_rounded`, 이번 변경 아님)
- 기본값 없음: 작성 모드 `_grade = existingReview?.grade` (null), 저장 버튼 비활성. 선택 전 `GradeTile(neutral: true)` 4장 동일, 선택 후 테두리/체크 `AppColors.primary` 고정, 등급색은 타일만 (`grade_selector.dart`, `grade_tile.dart`)
- 익명: `maskedQratorName(userId)` 만 사용. `userName`/`displayName` 참조 0건 (엔티티·모델·DS·화면). 단 F1 참조
- 평균 점수: `showAverage` 기본 false, 점주 페이지에서만 true. 고객 요약은 `Qrator 평가 N개` (평균 미노출). 접근성 라벨도 동일 분기
- 14일: `ReviewWindow` + UseCase 에만. `firestore.rules` 에 `completedAt`/기한 로직 0건
- 삭제 UI / 분포 막대 / 목록 수정 진입: 0건 (`ReviewCard` 는 읽기 전용, 점주 페이지 주석에 명시)

### ③ Rules 보안 — PASS (결함 없음, 아래 관찰 2건)
`reviews` 블록 정밀 검토 (`firestore.rules` L453~515). `git diff` 상 변경 hunk 는 reviews 블록 단 1개.
- **필드 화이트리스트**: create `hasOnly(7)` + `hasAll(6)`, update `hasOnly(8)` + `onlyChangedFields(5)`. 누락 없음. update 에서 `grade/score/orderId` 를 삭제하면 `reviewGradeOk`/`get()` 경로 평가 오류로 deny, `createdAt` 삭제는 onlyChangedFields 로 deny, `comment` 삭제만 허용(의도)
- **grade↔score**: `reviewGradeOk` 가 4쌍 OR 로 일치 강제, `grade in [...]` 선행. `score` 단독 위조 불가 (RV2/RV2b/RV10d PASS). Dart `StoreGrade.score`(S4 A3 B2 C1) 와 매핑 일치
- **get() 1회**: `reviewOrderEligible` 내 `let o = get(...)` 1회, create/update 각각 1회 호출. 중복 get 없음
- **시간 강제**: create `createdAt == request.time`, update `updatedAt == request.time`. create 에 `updatedAt` 은 hasOnly 로 차단. 클라이언트는 `FieldValue.serverTimestamp()` 사용 확인 (`review_model.dart`)
- **stores 블록 무변경**: diff 확인. RV16/16b/17/17b deny PASS
- **문서 ID 강제**: create `reviewId == request.resource.data.storeId + '_' + uid()` + `userId == uid()` → ID/본문 storeId/userId 3자 일치 보장 (storeId 비문자열이면 연산 오류로 deny). update 는 ID 비교 없이 `storeId`/`userId` immutable 로 ID 일관성 유지 (create 시점 보장 + 불변) — 충분
- **주문 자격**: `o.userId==uid()`, `status=='completed'`, `o.storeId==d.storeId`. 존재하지 않는 orderId 는 get 오류로 deny. orders create 는 `if false` 라 클라이언트 위조 주문 불가
- 관찰(비결함): (a) `score == 4` 는 Rules 에서 4.0(double)도 통과하나 sum 결과 동일하고 클라이언트는 int 만 보냄. (b) 삭제 후 재생성 가능하나 doc ID 결정적이라 1인 1표 상한 유지. (c) `read` 가 `isSignedIn()` 이라 `userId` 가 모든 로그인 사용자에게 노출 — "익명" 은 UI 표기 수준이며 스펙(A3)과 일치, 단 uid 자체가 문서에 존재함을 인지할 것
- 하네스 보강 제안(Low): update 시 `userId` 변경, 비작성자 customer update, 숫자 float score, `orderId` 누락 create 케이스 미포함

### ④ Rules 하네스 — PASS
`cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test` 직접 실행: **48/48 PASS**, exit 0. RV16/RV16b/RV17/RV17b (stores 평점 직접 쓰기 deny) 포함 확인. 출력 중 PERMISSION_DENIED 로그는 deny 케이스의 정상 출력. RV20 은 에뮬레이터가 인덱스를 강제하지 않아 I1 동작 증명은 아님(spec 의 "I1 확인 겸용" 문구는 에뮬레이터에서는 성립하지 않음).

### ⑤ CF 로직 — PASS (보류 H1 부속)
`functions/src/onReviewWritten.ts`
- `increment` 없음. `AggregateField.count()` + `sum('score')` 전량 재계산 후 절대값 `update` — PASS
- 멱등: 같은 이벤트 재실행 시 동일 결과 — PASS
- 삭제: `after` 없음/`before` 있음 → `beforeStoreId` 로 대상 포함, early-return 조건은 `before && after` 이므로 미적용. 0건이면 `averageScore 0`, `reviewCount 0` — PASS
- 쓰기 필드 `{averageScore, reviewCount}` 2개, 매장 부재 시 warn 후 skip — PASS
- **H1 [보류/위험] 조용한 실패**: `recomputeStore` 실패(인덱스 I2 누락 `FAILED_PRECONDITION`, 일시 오류)는 `console.error` 후 함수가 정상 종료 → 재시도 없음, 알림 없음, 매장 평점은 다음 리뷰 쓰기 전까지 stale. spec §7.2-5 가 swallow 를 지시했으므로 FAIL 아님. 특히 I2 는 미실측(implementation.md 자인)이라 **배포 직후 첫 리뷰에서 CF 가 실패해도 앱에서는 아무 징후 없이 `미평가`로 남음**. 권고: (1) 배포 후 Functions 로그에서 `FAILED_PRECONDITION` 확인을 완료 기준에 포함, (2) 로그 기반 알림 또는 일시 오류만 rethrow 하여 재시도.
- 관찰(Low): 동시 트리거 2개가 읽기→쓰기 순서가 뒤집히면 한 건 뒤처질 수 있음(spec §3.4 가 수용). 반올림 2자리는 평균이 3.495~3.4999 인 경우(리뷰 200건 이상) 등급 경계를 넘길 수 있으나 실효 무시 가능.

### ⑥ 집계 단일 지점 — PASS
클라이언트에서 평균/건수를 계산하는 코드 0건 (`fold`/`sum`/`length 기반 평균` 없음). 화면은 `store.averageScore`/`reviewCount` 표시만. `list.length` 는 반영 캡션 판정과 50개 안내에만 사용(집계 아님). 등급 파생은 기존 `StoreModel.toEntity()`.

### ⑦ 아키텍처 / 절대 규칙 — PASS
- 의존 방향: domain 의 Firebase import 는 기존 `remote_notification_message.dart` 1건(이번 변경 아님). 신규 domain/core/presentation(review, owner/reviews) cloud_firestore·firebase_* import 0건. Firestore 직접 사용은 `review_remote_data_source.dart`, `review_model.dart`(data) 한정
- `Color(0x` 0건, `Colors.*` 하드코딩 0건 (신규·수정 파일). 전부 `AppColors`
- 시크릿 하드코딩 없음
- 범위 밖 수정: git status 상 수정 파일 12개 전부 spec §5 범위 내. 포맷 사고 잔여 흔적 없음(수정 목록에 lib/data 무관 파일 없음)
- 관찰(Low): `owner/reviews` 가 `customer/review/widgets/store_reviews_view.dart` 를 import (역할 간 presentation 교차 의존). spec 이 재사용을 지시했으나 장기적으로 `presentation/common` 이동 권고. `review_di_providers` 가 data 구현을 조립하는 것은 기존 `order_di_providers` 패턴과 동일

### ⑧ GradeBadge 6개 지점 회귀 — PASS (코드 기준) / H2 보류(렌더)
- 시그니처: `showChevron` 은 optional(기본 false) → 6개 호출부(store_card 2, frequent_stores 1, map_marker_sheet 1, my_store 1, menu_header 1) 컴파일/동작 불변. 호출부 변경은 menu_header 뿐
- `reviewCount > 0` 경로: 레이아웃 동일. `(-)` 분기 제거(0건은 `미평가`로 대체). Semantics 래핑 추가는 시각 불변
- 지도 시트: `GradeBadge` 가 `Row` 의 비유연 자식 — `미평가` 폭(약 51px)이 기존 `C급 (-)`(약 53px) 이하라 오버플로 위험 낮음. 점주 내 매장: `Spacer` 뒤 Row 내, `ApprovalStatusBadge` 와 인접 — 동일 근거로 낮음
- **H2 [보류]** 두 지점은 렌더 미확인(implementation.md 자인). 높이 25px 보정은 4개 지점 실측만 근거. 라이브에서 `미평가` 매장으로 확인 필요
- 메뉴 헤더 padding 16→5, `SizedBox(8)` 제거는 문서화됨 (이름 행 약 3px 상향). 수용

### ⑨ 단위 테스트 품질 — PASS (보강 권고)
- U1: 경계 8개(3.49/3.5/2.49/2.5/1.49/1.5/1.0/4.0) 모두 포함. 양호
- U2: 4등급 `fromString`/`asString` 왕복 + `score` 값 고정. 페이로드 테스트가 B→2, S→4 를 확인하나 4등급 전수 아님 (Rules 매핑과의 일치는 본 리포트가 코드로 확인)
- U3/U5: 14일 경계(정확히 14일 허용 / 14일+1초 만료 / 13일·15일 / null 허용) 및 자격 4종 + 실패 시 repo 미호출 + trim — 양호
- U4: 누락·잘못된 grade 폴백 확인. 단 `grade` 오염 시 `C` 폴백은 "조용히 최저 등급으로 표기"하는 동작이므로 허용 여부는 설계 판단 사항
- **갭**: 익명 이름 테스트가 실제 uid 형식(`kakao_…`)을 쓰지 않아 F1 을 못 잡음. 위젯 테스트 없음(spec 에 요구 없음). 폼 `_canSubmit`/`_isDirty` 로직은 테스트되지 않음(UI 상태 로직)

## 4. 보류

| # | 내용 | 해소 방법 |
|---|---|---|
| H1 | CF 조용한 실패 (특히 I2 인덱스 미실측) | 배포 후 Functions 로그 `FAILED_PRECONDITION` 확인. 필요 시 I2 삭제 또는 알림 |
| H2 | `미평가` 렌더: 지도 시트, 점주 내 매장 | 라이브에서 0건 매장으로 확인 |
| H3 | M1~M9 라이브 | 사용자 수행. §6 의 시나리오 결함 반영 후 |

## 5. 후속 문서 작업 (미수행, architect)
spec §10 X1(backlog 항목 삭제), X3(data_ownership 해소 + CF 카탈로그), X4(role_flows), X5, X6 미반영. 완료 기준(§13)에 포함되어 있으므로 task 종료 전 필요.

## 6. 시나리오 결함 (FAIL 아님)

M1~M9 + 준비 절차를 `OrderModel.fromFirestore` / Rules / 앱 구성과 대조.

**필드 세트 충분성 — 충분함.** `OrderModel._fromMap` 은 대부분 `?? 기본값` 이며 spec 의 세트(`userId, storeId, storeName, status, totalPrice, subtotal, createdAt/updatedAt/completedAt(Timestamp), items: [], paymentInfo: {}`)로 파싱 실패 없음. `paymentInfo: {}` 는 `PaymentInfoModel.fromMap` 이 전 필드 기본값 처리, `items: []` OK. 필수는 사실상 `userId`, `storeId`, `status`, `createdAt`(Log 쿼리가 `userId == ` + `orderBy createdAt` 이라 누락 시 목록에서 사라짐), `completedAt`(M9/카운트다운). 아래 주의 필요:

| # | 결함 | 영향 | 대안 |
|---|---|---|---|
| S1 | **`status` 오타/타입 오류가 조용히 `paid` 로 폴백** (`OrderStatus.fromCode` orElse → paid). `"completed"` 는 string 이어야 하고 공백/대문자 오류 시 평가 버튼이 안 나옴 | M1 에서 원인 파악 곤란 | 준비 절차에 "status 는 string `completed`, 정확히 소문자" 명시. Rules 도 같은 값을 요구 |
| S2 | **`userId` 는 Firebase Auth uid** (Kakao/Naver 는 `kakao_…` 형태). "내 uid" 를 어디서 구하는지 불명 | 잘못된 값이면 주문이 Log 에 안 보임 | Console > Authentication 에서 계정 uid 복사. 또는 앱 로그인 후 기존 주문 문서의 userId 를 참고 |
| S3 | **앱은 에뮬레이터를 쓰지 않는다** (`useFirestoreEmulator` 0건 → 운영 Firebase). M1~M9 는 **운영 Console 에 주문 문서를 만들고 운영에 Rules/인덱스/CF 가 배포된 뒤에만** 의미 있음 | 배포 전 실행하면 구 Rules 는 `{storeId}_{uid}` 문서 create 를 통과시키지만 CF 가 없어 M3/M5 의 배지 갱신이 영원히 안 일어나 "CF 결함"으로 오인 | M 시작 전 체크리스트에 (1) rules+indexes 배포 (2) I1 인덱스 빌드 완료 확인 (3) CF 배포 (4) A5 리셋 순서 명시. 테스트 주문 문서는 종료 후 삭제(운영 데이터 오염 방지) |
| S4 | **M9 가 M2~M5 와 같은 매장/계정이면 C-1 이 아니라 C-2 경로**: 매장 단위 1표라 이미 평가가 있으면 "평가 기간(14일)이 지났어요"(C-1) 대신 "수정 기간(14일)이 지났어요"(C-2) + 내 평가 요약이 표시. spec 기대("평가 버튼 숨김 + 기간 만료 안내")는 둘 다 만족하나 두 문구 모두 확인하려면 별도 조건 필요 | C-1 미검증으로 끝남 | C-1: 평가가 없는 **다른 매장**의 20일 전 주문 사용(또는 리뷰 문서 삭제 후). C-2: 기존 평가 있는 상태에서 20일 전 주문. 둘 다 수행 |
| S5 | **M7 은 A5(Console 리셋) 선행 필요**: 시드 두 매장은 운영 문서에 `4.6/128`, `4.7/54` 가 남아 있어 리셋 전에는 `S급(128)`로 보임. 또 M3 의 기대값 `S급 (1)` 은 CF 가 전량 재계산으로 덮어쓴 결과이므로 리셋 여부와 무관하게 성립(자기 치유 확인에는 오히려 유리) | M7 이 거짓 FAIL | M7 전에 A5 수행 확인. CF6(자기 치유)를 운영에서 한 번 보려면 리셋 전 매장에서 M2 를 먼저 수행해도 됨 |

**누락 시나리오 제안**: (a) 다른 주문(2번째 Console 주문)으로 진입 시 "이전에 남긴 평가가 있어요" 카드 (b) 코멘트 삭제 후 수정 → 문서에서 `comment` 필드 제거 확인(Console) (c) 14일 카운트다운 캡션: completedAt 을 11~13일 전으로 (d) 고객 화면에 평균 미노출 / 점주 화면(M8) 평균 노출 (e) 제출 중 뒤로가기 차단, 변경 있을 때 이탈 다이얼로그 (f) 에러 스낵바: 권한(`이 주문으로는 평가할 수 없어요`)은 주문의 `status` 를 `paid` 로 바꿔 폼을 연 채로 저장해 유도 가능, 네트워크는 비행기 모드.

## 7. 권고 (Low)
1. 고객 `StoreReviewsPage` 의 `store` 스냅샷 → CF 반영 후에도 "곧 반영돼요" 캡션이 남을 수 있음 (implementation.md 자인). 후속 `watchById` 권장
2. 하네스에 §3-③ 의 추가 케이스 보강
3. CF 반올림이 경계 근처에서 등급을 올릴 수 있음 (매우 낮음)
4. `owner → customer` presentation 교차 import 정리

## 8. 결론
Rules·CF·집계 단일 지점·확정 사항 준수는 양호하며 **보안 결함 없음**. 차단 요소는 F1(익명 코드 설계 결함) 1건. 라이브 검증 전에 §6 시나리오 결함(특히 S3 배포 순서, S4)을 반영할 것.

---

## Z. FAIL 처리 + 라이브 검증 결과 (2026-10-22)

### Z-1. F1 익명 코드 결함 — **수정 완료**

`maskedQratorName` 이 `uid.substring(0, 4)` 를 써서, Custom Token 경로의 provider 접두사 때문에 소셜 로그인 사용자가 **전원 같은 코드**가 됐다.

```
verifyKakaoToken.ts:82  → uid = `kakao_${kakaoUid}`  → 전원 "Qrator kaka"
verifyNaverToken.ts:82  → uid = `naver_${naverUid}`  → 전원 "Qrator nave"
```

소셜 로그인이 주력인 앱에서 A3("작성자 구분")의 목적이 달성되지 않는다.

**수정**: uid **전체**를 FNV-1a 로 해싱해 4자리 16진수를 만든다. 접두사 형식과 무관하게 분포하고, 같은 uid 는 언제나 같은 코드이며, uid 원문을 역산할 수 없다. `String.hashCode` 는 버전 간 안정성이 보장되지 않아 쓰지 않았다.

**회귀 테스트 추가** — 기존 테스트가 `a3f9xyz` 같은 가상 uid 만 써서 이 문제를 못 잡았다. 실제 형식으로 고정했다.

| 테스트 | 내용 |
|---|---|
| 결정성 | 같은 uid → 항상 같은 코드 |
| 형식 | 4자리 16진수 |
| **회귀** | `kakao_` 3개 / `naver_` 2개가 **서로 다른 코드** |
| **회귀** | 접두사(`kaka`/`nave`)가 코드에 드러나지 않음 |
| 방어 | 짧은 uid / 빈 uid |

### Z-2. 라이브 검증 결과 — 전 구간 PASS

환경: Android Emulator (고객 `dhqod13`), 운영 Firebase. **실결제 0회 / Console 주문 생성 0회** — 어제 테스트로 생성된 실제 `completed` 주문(10/21, 14일 기한 내)을 사용했다.

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| L-1 | 주문 상세 평가 진입점 (평가 전) | **PASS** | `이 매장은 어땠나요?` / `Qrator 의 평가가 매장 등급을 만들어요` / `매장 평가하기` |
| L-2 | 폼 초기 상태 | **PASS** | 라디오 4개 전부 빈 원(**기본 선택값 없음**), 타일 4장 모두 중립 회색, `평가 등록` **비활성** |
| L-3 | 등급 의미 문구 4종 | **PASS** | 최고예요/좋아요/보통이에요/아쉬워요 + 설명 전부 design 일치 |
| L-4 | 별점 메타포 부재 | **PASS** | ★ 없음. 세로 4장 선택 카드 |
| L-5 | **F1 수정 실물 확인** | **PASS** | 폼 고지 `평가는 'Qrator df22' 로 익명 공개되며…` — 해시 기반 4자리 |
| L-6 | **쏠림 방지 (C 선택)** | **PASS** | C 선택 시 테두리 네이비 2px + 체크 네이비 = S 선택과 **동일한 시각 처리**. 타일만 등급색. 경고색 없음 |
| L-7 | 저장 | **PASS** | SnackBar `평가가 등록됐어요. 매장 등급에 반영되기까지 잠시 걸릴 수 있어요` (한 줄 통합) |
| L-8 | 주문 상세 평가 후 상태 전환 | **PASS** | `이 매장에 남긴 내 평가` / `C급 · 아쉬워요` |
| L-9 | **CF 집계** | **PASS** | `[onReviewWritten] recomputed. { storeId: 'TRdrkidlroX7HuONtuay', reviewCount: 1, averageScore: 1 }` |
| L-10 | **인덱스 (H1 해소)** | **PASS** | CF 로그에 `FAILED_PRECONDITION` **없음**. `storeId+score` 인덱스가 실제로 충분함이 실증됨 |
| L-11 | `미평가` 배지 | **PASS** | 홈 `주변매장` 카드에서 리뷰 0건 매장이 `미평가` 로 표시 (기존 `C급 (-)`) |
| L-12 | 고객 화면 평균 미노출 (Q2) | **PASS** | 리뷰 목록 요약에 등급/건수만, 평균 없음 |

#### L-9 집계 정확도 검증

```
C급 선택 → score = 1
CF:  count() = 1, sum('score') = 1
     averageScore = 1 / 1 = 1.0
     GradeCalculator.fromAverage(1.0) → bMin(1.5) 미만 → C급
```

**설계대로 전량 재계산이 동작**한다. increment 방식이었다면 검증할 수 없었을 값이다.

### Z-3. 평가 수정 경로 — **PASS** (추가 검증 2026-10-22)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| L-13 | 수정 진입 버튼 | **PASS** | 주문 상세에 `평가 수정` (평가 전의 `매장 평가하기` 에서 전환) |
| L-14 | 수정 모드 초기 상태 | **PASS** | 제목 `평가 수정`, **기존 등급(C) 미리 선택**, 버튼 `수정 완료`. design 의 "첫 프레임 깜빡임 없음" 요구 충족 |
| L-15 | 변경 없을 때 버튼 | **PASS** | `수정 완료` **비활성** |
| L-16 | 등급 변경 저장 | **PASS** | C → S 변경 후 저장 → 주문 상세가 `S급 · 최고예요` 로 갱신, 타일이 금색(S 고유색)으로 전환 |
| L-17 | **CF 재집계 (수정)** | **PASS** | 아래 |

#### L-17 — 전량 재계산과 1인 1표가 동시에 증명됨

```
04:57  C급 작성  → [onReviewWritten] recomputed. { reviewCount: 1, averageScore: 1 }
05:10  S급 수정  → [onReviewWritten] recomputed. { reviewCount: 1, averageScore: 4 }
```

**`reviewCount` 가 1 로 유지됐다.** `increment` 방식이었다면 2가 됐을 자리다.
- 문서 ID `{storeId}_{userId}` 로 수정이 **같은 문서의 update** 로 흡수됨 (1인 1표)
- `count()` + `sum('score')` 전량 재계산이라 **집계 보정 로직 없이** 평균이 1 → 4 로 정확히 갱신됨

설계 결정 D3(문서 ID)과 D1(전량 재계산)이 함께 작동하는 것을 서버 로그로 확인했다.

### Z-3-1. 스냅샷 store 로 인한 체감 결함 — **수정 완료 (2026-10-22)**

**사용자가 라이브에서 발견했다.** 평가를 남긴 매장이 메뉴 헤더와 평가 목록에서 계속 `미평가` 로 보였다.

실제로는 CF 집계가 정상 동작했고(`recomputed { reviewCount: 1, averageScore: 4 }`) 홈 카드에는 `S급, 평가 1개` 로 반영돼 있었다. **문제는 화면이 진입 시점 스냅샷 `StoreEntity` 를 들고 있었다는 것**이다.

| 화면 | 수정 전 | 비고 |
|---|---|---|
| 고객 평가 목록 요약 | 스냅샷 | `아직 평가가 없는 매장` 과 `내 평가, S급` 이 **한 화면에 공존** |
| 매장 메뉴 헤더 배지 | 스냅샷 | `미평가 >` 로 남음 |
| 점주 평가 목록 | 라이브(`myStoreProvider`) | 이미 정상이었음 |

`곧 반영돼요` 캡션 조건이 `목록 건수 != store.reviewCount` 라서, 스냅샷이 0인 동안 **이미 반영된 뒤에도 계속 노출**됐다.

**수정**: `StoreRepository.watchById(storeId)` 를 신설(데이터소스 → 리포지토리 → provider)하고, 고객 평가 목록과 매장 메뉴 헤더가 구독값을 쓰도록 했다. 점주 화면이 이미 쓰던 방식과 동일하다.

```dart
final liveStore = ref.watch(watchedStoreProvider(storeId)).asData?.value ?? store;
```

스냅샷을 fallback 으로 남겨 구독 도착 전에도 빈 화면이 생기지 않는다.

**라이브 재검증**

| 지점 | 수정 전 | 수정 후 |
|---|---|---|
| 메뉴 헤더 | `미평가 >` | **`S급, 평가 1개. 평가 목록 보기`** |
| 평가 목록 요약 | `개인매장, 아직 평가가 없는 매장` | **`개인매장, S급, Qrator 평가 1개`** |

**이 유형의 결함은 자동 검증으로 잡히지 않는다.** 기능은 정상이고 단위 테스트·Rules·CF 모두 통과하는데, 사용자는 "반영이 안 됐다" 고 믿는다. T-B17(거부 직후 설정 앱 전환)과 같은 종류다.

### Z-4. 남은 보류

| 항목 | 사유 |
|---|---|
| H2 지도 시트 / 점주 내 매장의 `미평가` 렌더 | 홈 카드·자주 가는 매장·메뉴 헤더 4곳은 렌더 확인됨. 나머지 2곳은 폭이 `C급 (-)` 이하라 코드상 회귀 위험 없음 |
| M9 14일 만료 | 20일 전 `completed` 주문이 필요. Console 로 생성 가능 |
| 점주 리뷰 조회 화면 (평균 노출) | iOS 점주 앱 재빌드 필요. 코드상 `showAverage` 분기는 tester 가 확인 |
| 고객 `StoreReviewsPage` 라이브 구독 | ~~후속~~ → **완료 (Z-3-1)** |
| 시드 오염 자기 치유 (CF6) | developer 가 CF 에뮬레이터로 확인. 운영에서는 A5 리셋으로 이미 정리됨 |

### Z-5. 라이브 중 발생한 환경 사고 (코드 무관)

Android 에뮬레이터 디스크가 94% 차 있어 `adb install` 이 `INSTALL_FAILED_INSUFFICIENT_STORAGE` 로 실패했는데, **설치 출력을 끝까지 확인하지 않아** 이를 "빌드 캐시 문제" 로 오진하고 재빌드를 반복했다. 이후 복구 과정에서 앱 데이터가 초기화돼 재로그인이 필요했다.

재발 방지:
- `adb install` 결과는 `Success` 문자열을 **명시적으로 확인**한다
- 디버그 APK 는 `--target-platform` 으로 기기 ABI 를 맞춘다. **Apple Silicon 의 Android 에뮬레이터는 `arm64-v8a`** 다 (x64 로 빌드하면 설치는 되지만 즉시 크래시한다)
- 에뮬레이터 디스크 여유를 주기적으로 확인한다
