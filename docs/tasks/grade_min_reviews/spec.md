# grade_min_reviews 기능 명세

등급(S/A/B/C)에 **최소 리뷰 수 게이팅**을 도입해 "리뷰 1건 = 즉시 S급" 문제를 해소한다.

- 작성: 2026-10-29 / architect
- 백로그 출처: `docs/backlog.md` "### ⬜ 등급에 최소 리뷰 수 없음 — '리뷰 1개 = 즉시 S급'"
- 선행 결정: 아래 "제품 결정"은 사용자가 확정함(재질문 불필요).

---

## 개요

- **목적**: 리뷰 표본이 부족한(N건 미만) 매장에 등급을 부여하지 않고 중립 '신규' 상태로 표시해, 등급 조작의 최단 경로(완료주문 1건 → S 리뷰 1개 → 즉시 S급)와 n=1 등급의 통계적 비신뢰를 차단한다.
- **작업 유형**: 기존 기능 수정 (등급 파생 로직 + 표시/필터/정렬 분기).
- **핵심 성질**: 등급은 **Firestore 에 저장되지 않는 파생·표시 값**이다. 데이터 쓰기/스키마/권한 변경은 **없다**(§감사 추적 참조). 유일하게 추가되는 데이터는 코드 상수 1개(`minReviewsForGrade = 3`).

### 확정된 제품 결정 (그대로 반영)

1. **최소 리뷰 수 N = 3.** 리뷰 3건 미만 매장은 등급 미부여 = "미평가/신규".
2. **미달 표시** = 등급 배지 자리에 회색 중립 배지('신규' 또는 '평가 전'). 매장은 정상 노출, 등급만 없음.
3. **등급 필터 처리** = S/A/B/C 필터를 좁히면 미평가 제외, 필터를 좁히지 않은 '전체' 목록·검색에는 정상 노출(발견성 유지).
4. **정렬/추천** = 등급순 정렬·맞춤추천에서 미평가 매장은 등급 있는 매장 **뒤(후순위)**. 과설계 금지, 단순하게.

### 영향 범위

- **화면**: 홈(store_card, frequent_stores_section, recommended_stores_section/page), 주문 리스트/지도 탭, 매장 메뉴 헤더, 지도 마커·마커 시트, 점주 내 매장(my_store_page).
- **Domain**: `StoreEntity` 에 파생 getter `isGraded` 추가.
- **Data**: `StoreModel` — 변경 없음(선택적 주석만). `grade` 파생은 지금처럼 `toEntity()`에서 계산.
- **Core**: `GradeThresholds` 에 상수 1개 추가, `GradeCalculator` 에 판정 헬퍼 1개 추가.
- **Presentation(상태)**: `orderStoresProvider`(필터), `sortRecommended`(정렬).
- **공통 컴포넌트**: `GradeBadge`(임계값 분기), 지도 마커 색상 분기.
- **라우팅 / 권한·환경 설정**: 변경 없음.
- **Firestore Rules / Cloud Function**: **변경 없음**(reviewCount 는 이미 `onReviewWritten` CF 가 집계).

### 비범위 (이번 작업에서 제외)

- `GradeCalculator.fromReviews` 의 동작 변경 — **소비처 없음(lib 내 호출 0건)**. dead path 이므로 N 반영은 하지 않고 doc 주석만 남긴다(§레이어 설계).
- `minReviewsForGrade` 의 런타임 설정화(Remote Config/Firestore config) — 상수로 유지. 임계값 변경은 코드 배포로만 일어나고 git 이력이 추적한다.
- 자기리뷰 차단(reviews create Rules `uid != ownerId`) 등 defense-in-depth — 백로그상 별도·우선순위 낮음. 이번 범위 밖.
- 리뷰/등급 데이터 스키마 변경, 백필, 마이그레이션.

---

## 요구사항

### 기능 요구사항

- [ ] `GradeThresholds.minReviewsForGrade = 3` 추가. N 값은 이 한 곳에만 둔다(리터럴 흩뿌리기 금지).
- [ ] 매장 등급 부여 여부를 `reviewCount >= minReviewsForGrade` 로 판정한다.
- [ ] 미평가 매장도 `store.grade` 필드 자체는 기존대로 계산되어 존재한다(enum 값은 그대로 S/A/B/C). 단 **표시·필터·정렬에서 `isGraded == false` 면 등급을 노출/사용하지 않는다.**
- [ ] **표시**: `isGraded == false` 면 등급 배지 대신 중립 '신규' 배지.
- [ ] **필터**: S/A/B/C 등급 필터를 좁히면(부분 선택) 미평가 제외. 좁히지 않은 상태(전체/모든 등급 선택)에서는 미평가 노출.
- [ ] **정렬(등급순)**: 미평가 매장은 등급 있는 매장 뒤로. 거리순 정렬은 변경 없음.

### UI 요구사항 (designer 확정 대상)

- [ ] 미평가 중립 배지의 라벨 텍스트('신규' 권고 / '평가 전' 허용 / 현행 '미평가' 중 택1), 색(AppColors 토큰), 크기(기존 배지와 정렬).
- [ ] 미평가 매장의 지도 마커 색(중립).
- [ ] 미평가 상태에서 리뷰 개수 표기 노출 여부(1~2건일 때 "(1)" 등).

### 상태 요구사항

- 신규/파생 상태만 다룬다. 비동기 loading/error/empty 상태는 기존 provider 그대로 재사용(변경 없음).

---

## 데이터 모델

### Entity — `StoreEntity` (domain)

| 필드/멤버 | 타입 | 설명 |
|---|---|---|
| `grade` | `StoreGrade` | 기존. `GradeCalculator.fromAverage(averageScore)` 결과. **변경 없음.** |
| `reviewCount` | `int` | 기존. CF `onReviewWritten` 가 매장에 전량 재계산해 쓰는 값. |
| `isGraded` | `bool` (파생 getter, 신규) | `reviewCount >= GradeThresholds.minReviewsForGrade`. 저장 필드 아님. |

- freezed 클래스에 getter 를 추가하려면 private 생성자(`const StoreEntity._();`)가 필요하다. 또는 domain 내 `extension StoreEntityGrading on StoreEntity` 로 제공한다. 둘 중 프로젝트 관례에 맞는 쪽을 developer 가 택한다(권고: private 생성자 + getter, 호출부가 `store.isGraded` 로 단순).
- 참고: `StoreEntity` 는 이미 `core/utils/qoin_rate_resolver` 를 import 한다(domain → core 참조 선례 존재). 따라서 `GradeThresholds`/`GradeCalculator` 참조는 레이어 규칙 위반이 아니다.

### DTO / Model — `StoreModel` (data)

- **변경 없음.** `toEntity()` 의 `grade: GradeCalculator.fromAverage(averageScore)` 는 그대로 둔다. `isGraded` 는 entity getter 로 `reviewCount` 에서 파생되므로 매퍼가 할 일이 없다.
- 선택: `StoreModel.toEntity` 근처에 "미평가 판정은 StoreEntity.isGraded 파생" 주석 1줄.

### 왜 StoreGrade enum 에 값을 추가하지 않는가 (모델링 결정)

**택: (b) StoreGrade 유지 + `StoreEntity.isGraded` 파생 플래그.** (권고안)

| 비교 | (a) enum 에 `unrated/new` 추가 | (b) isGraded 파생 플래그 ✅ |
|---|---|---|
| 파급 | `StoreGrade` 의 모든 switch(`label`/`color`/`score`/`asString`/`fromString`) + `grade_filter_chips` 의 `[s,a,b,c]` 리스트 + `Set<StoreGrade>` 필터 전부 수정 | 표시/필터/정렬 3지점 분기만 |
| 의미 오염 | **StoreGrade 는 이중 용도** — 매장 파생 등급이자 **리뷰 작성 시 사용자가 고르는 평점**(`grade_selector`/`grade_tile`/`grade_copy`). 리뷰에 "미평가"는 존재할 수 없는데 enum 에 섞이면 평점 선택 UI가 깨진다 | 리뷰 평점(StoreGrade)과 매장 "표본 충분 여부"(isGraded)를 분리 |
| 선례 | 없음 | `GradeBadge` 가 이미 `reviewCount == 0` 을 "미평가"로 분기 중 — N=3 으로 임계값만 넓히면 동일 패턴 |
| score=int | `score` getter 가 enum 전수 switch라 새 값에 점수를 억지로 부여해야 함 | 영향 없음 |

→ (b)가 파급·명확성 모두 우위. (a)는 **채택하지 않는다.**

---

## 레이어 설계

### Core (`lib/core/...`)

- `constants/grade_thresholds.dart`
  - `static const int minReviewsForGrade = 3;` 추가. 주석에 "등급 부여 최소 리뷰 표본. 미만이면 미평가(신규)" 명시.
- `utils/grade_calculator.dart`
  - `static bool isGraded(int reviewCount) => reviewCount >= GradeThresholds.minReviewsForGrade;` 추가.
  - `fromAverage` : **변경 없음.**
  - `fromReviews` : 동작 변경 없음. "표본 게이팅은 isGraded 가 담당, 이 메서드는 평균→등급 변환만" doc 주석 1줄(소비처 없음, 혼동 방지).

### Domain (`lib/domain/...`)

- `entities/store_entity.dart`
  - `bool get isGraded => GradeCalculator.isGraded(reviewCount);` (private 생성자 추가 또는 extension).
  - UseCase / Repository Interface: **추가·변경 없음.**

### Data (`lib/data/...`)

- `models/store_model.dart`: 변경 없음(주석 선택).
- DataSource / Repository Impl: 변경 없음.

### Presentation (`lib/presentation/...`)

1. **표시 — `GradeBadge` (customer/home/widgets/grade_badge.dart)**
   - 분기 조건을 `reviewCount == 0` → `!GradeCalculator.isGraded(reviewCount)` (= `reviewCount < GradeThresholds.minReviewsForGrade`)로 변경.
   - 모든 `GradeBadge` 호출부(8곳: store_card ×2, frequent_stores_section, store_map_marker_sheet, store_menu_header, my_store_page)가 **이미 `grade` + `reviewCount` 를 함께 전달**하므로 **호출부 수정 불필요** — 임계값 분기 한 곳으로 전 표시 지점이 일괄 적용된다.
   - 중립 배지 라벨/색/크기는 design.md 결과를 따른다(현행 '미평가' pill 재사용 또는 '신규'로 교체).

2. **지도 마커 색 — `store_map_tab.dart` (customer/order/tabs)**
   - 마커 생성부가 `MapConfig.markerColorHexForGrade(s.grade)` 를 **grade 로 직접** 칠한다(GradeBadge 를 거치지 않음 → 자동 cascade 안 됨).
   - `!s.isGraded` 면 등급 색 대신 **중립 색**을 쓰도록 분기(색 값은 designer 확정). 마커 시트 내부의 `GradeBadge` 는 ①로 자동 처리됨.

3. **필터 — `orderStoresProvider` (customer/order/providers/order_providers.dart)**
   - 리스트 탭·지도 탭이 **모두 이 provider 를 공유**하므로 필터 로직은 이 한 곳에만 둔다.
   - 현재: `if (!grades.contains(s.grade)) return false;` — 미평가 매장도 `s.grade`(C 등 파생값)로 매칭되어 잘못 노출/제외됨.
   - 변경 규칙(단순):
     ```
     final bool gradeFilterNarrowed = grades.length < StoreGrade.values.length; // 사용자가 일부 등급만 선택
     // where:
     if (!s.isGraded) {
       if (gradeFilterNarrowed) return false;   // 등급 필터를 좁히면 미평가 제외
       // 전체(모든 등급 선택)면 통과 → 노출
     } else {
       if (!grades.contains(s.grade)) return false;
     }
     // 이후 기존 query 매칭 동일
     ```
   - 근거: 이 UI의 등급 칩은 기본 전체 선택(4개)·최소 1개 유지형이므로 "4개 전부 선택 = 전체(미좁힘)"가 제품 결정 3의 '필터 안 건 전체'에 해당한다.

4. **정렬 — `sortRecommended` (customer/home/providers/recommended_stores_providers.dart)**
   - `RecommendedSort.grade` 분기에서 1차 정렬 키로 `isGraded`(등급 있음 우선)를 추가한 뒤 기존 `averageScore` 내림차순 → 거리 오름차순 유지.
     ```
     // grade 정렬 비교자
     if (a.isGraded != b.isGraded) return a.isGraded ? -1 : 1; // 미평가 후순위
     final c = b.averageScore.compareTo(a.averageScore);
     if (c != 0) return c;
     return (a.distanceKm ?? inf).compareTo(b.distanceKm ?? inf);
     ```
   - `RecommendedSort.distance` : **변경 없음**(거리순에서는 미평가도 거리대로). 제품 결정 4 "단순하게"에 부합.
   - 홈 미리보기(`recommendedPreviewProvider`)는 거리순 기반이라 영향 없음.

5. **등급 필터 칩 — `grade_filter_chips.dart`**: 변경 없음(미평가 전용 칩을 만들지 않는다 — 제품 결정 3). 필터 동작은 ③ provider 에서 처리.

---

## 데이터 흐름

```text
Firestore stores/{id}  (reviewCount 는 onReviewWritten CF 가 집계 — 이미 존재, 변경 없음)
  → StoreModel.fromFirestore
  → StoreModel.toEntity()  : grade = GradeCalculator.fromAverage(averageScore)  [기존]
  → StoreEntity.isGraded   : GradeCalculator.isGraded(reviewCount)              [신규 파생]
  → Provider (orderStoresProvider 필터 / sortRecommended 정렬)
  → Widget (GradeBadge: isGraded 로 등급 배지 vs 신규 배지 / 지도 마커 색 분기)
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| reviewCount 필드 부재(legacy) | `StoreModel.fromFirestore` 가 이미 `0` 폴백 → isGraded=false(신규) 로 안전 표시 |
| 네트워크/로드 실패 | 기존 provider AsyncValue error UI 그대로(변경 없음) |
| 미평가 매장이 등급 필터에서 모두 걸러져 목록 비는 경우 | 기존 empty 상태 UI 재사용(신규 요구 없음) |

새로운 예외 경로는 없다(순수 파생·분기).

---

## 감사 추적 (audit_trail §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** — 아니오. 등급은 Firestore 에 저장되지 않는 **읽기시 파생·표시 값**이다. `minReviewsForGrade` 는 **코드 상수**(GradeThresholds)이며 런타임 설정이 아니다 → 변경은 코드 배포로만 일어나고 **git 이력이 곧 설정 변경 이력**. ⟹ 별도 설정 변경 이력 문서 **불필요**(사유: 저장 상태를 덮어쓰지 않으며, 임계값 변경 추적은 VCS 가 담당).
2. **덮어쓰기로 사라지는 값?** — 없음. 이번 작업은 **쓰기 자체가 없다**(파생 getter + 표시/필터/정렬 분기만).
3. **거래/기록 문서가 정책 값을 참조만?** — 해당 없음. 거래 문서(orders/qoinTransactions)는 건드리지 않음. 등급은 어떤 기록 문서에도 박제되지 않는다(표시 전용).
4. **"누가"가 기록되는가?** — 해당 없음. 운영자 행위 없음.
5. **batch?** — 없음.
6. **CF 로그 의존?** — 없음.
7. **권한 판정 필드의 create/update 교차 확인?** — 해당 없음. Rules 변경 없음. reviewCount 는 기존대로 CF 전담 집계(클라이언트 쓰기 경로 신설 없음).

> 요약: **등급은 파생·표시이므로 이력 대상이 아니다.** 거래 이력·설정 변경 이력 모두 신규 대상 없음.

---

## 프로세스 영향 확인

- **role_flows**: customer 의 발견/탐색 흐름(홈·검색·주문 탭 필터·정렬)에 표시 규칙만 끼어든다. owner 의 '내 매장' 화면은 자기 매장 배지 표시만 영향. 흐름 진입/액션/권한 전이 **변화 없음**.
- **entity_lifecycle**: 등급은 어떤 엔티티의 status 도 아니다(order/store/brand/menuItem/refund 전이와 무관, `EntityApprovalStatus` 와 직교). status 전이 **변화 없음**.
- **data_ownership**: 신규 Firestore 쓰기·권한 매트릭스·CF 전담 작업 **추가 없음**. reviewCount 소유권(CF 전담 집계) 유지.

---

## 작업 분배

### designer (호출 필요 — UI 변경 있음)

- **UI 변경 필요**: 예(중립 '신규' 배지, 지도 마커 중립 색).
- **산출물**: `docs/tasks/grade_min_reviews/design.md`.
- **전달 사항 / 결정 요청**:
  - 중립 배지 라벨: '신규'(권고) / '평가 전' / 현행 '미평가' 중 택1. 색은 **AppColors 토큰만**(현행 `_unrated` 는 surface+border+textBody 사용 — 유지/변경 결정).
  - 미평가 매장 지도 마커 색(AppColors 중립 토큰).
  - 미평가 배지에 리뷰 개수(1~2건) 노출 여부.
  - 크기·정렬은 기존 등급 배지와 시각적 동일성 유지(현행 `_unrated` 가 이미 `_rated` 와 크기 보정됨).

### developer (designer 후 호출)

- **구현 항목**:
  1. `GradeThresholds.minReviewsForGrade = 3`.
  2. `GradeCalculator.isGraded(int)` 추가 (`fromAverage`/`fromReviews` 동작 불변, 주석만).
  3. `StoreEntity.isGraded` 파생 getter(private 생성자 또는 extension).
  4. `GradeBadge` 분기 임계값 `== 0` → `< minReviewsForGrade` (디자인 라벨/색 반영).
  5. `orderStoresProvider` 필터 규칙(§레이어 3) — 리스트·지도 공통.
  6. `sortRecommended` 등급순에 isGraded 1차 키(§레이어 4).
  7. `store_map_tab` 마커 색 `!isGraded` 중립 분기.
- **재사용할 기존 구조**: `GradeBadge` 기존 `_unrated` 분기(precedent), `GradeThresholds` 단일 상수 모음, 기존 provider 파이프라인.
- **주의할 레이어 규칙**: domain(`StoreEntity`)·presentation 에서 Firebase 직접 import 금지(이번엔 해당 없음). 색은 `AppColors` 만. 상수는 `GradeThresholds` 한 곳. StoreModel 쓰기 맵에 손대지 않는다.
- **산출물**: `docs/tasks/grade_min_reviews/implementation.md`.

### tester (developer 후 호출)

- **주요 검증 기준**:
  - reviewCount 경계: 0/1/2 → 미평가(신규 배지), 3 이상 → 등급 배지(경계값 N=3 포함).
  - 리뷰 1건 S(평균 4.0) 매장이 **더 이상 S급 배지로 노출되지 않음**(핵심 회귀 — 백로그 어뷰징 경로 차단 확인).
  - 필터: 등급 칩 일부만 선택 시 미평가 제외 / 4개 전부 선택(전체) 시 미평가 노출 / 검색어와 조합.
  - 정렬: 등급순에서 미평가가 등급 매장 뒤로, 거리순은 미평가 위치 불변.
  - 지도: 미평가 마커 중립 색, 마커 시트 배지 신규 표시.
  - 리스트·지도 탭이 동일 필터 결과 공유 확인.
- **반드시 확인할 예외 케이스**:
  - reviewCount 필드 부재 legacy 매장 → 미평가 처리(0 폴백).
  - 미평가 매장을 등급 필터로 모두 거른 빈 목록 empty 상태.
  - 상수가 GradeThresholds 한 곳에만 있는지(리터럴 3 산재 없음), 레이어 규칙(색/Firebase import) 준수.
  - `GradeCalculator.fromReviews`·Firestore Rules·CF 미변경 확인.
- **산출물**: `docs/tasks/grade_min_reviews/test_report.md`.

---

## 완료 기준

- [ ] `minReviewsForGrade` 상수 추가, 코드 전역에서 리터럴 N 산재 없음.
- [ ] 리뷰 <3 매장이 등급 배지 대신 중립 배지로 표시(홈/주문리스트/지도/메뉴헤더/내매장 전 지점).
- [ ] "리뷰 1건=S급" 회귀 재현 불가(tester 확인).
- [ ] 등급 필터·정렬이 제품 결정 3·4대로 동작.
- [ ] `design.md` 작성 완료.
- [ ] `implementation.md` 작성 완료.
- [ ] `test_report.md` 작성 완료, FAIL 없음 또는 후속 분리.
- [ ] Firestore Rules/CF/스키마 무변경, 감사추적 §4 통과(이력 대상 없음 명시).

---

## 다음 단계

`/designer` → `/developer` → `/tester` → architect 재검토.
