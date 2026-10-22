# 매장 평가 (store_reviews) 기능 명세

- 작성: architect
- 작성일: 2026-10-22
- 상태: 설계 완료, 사용자 결정 대기 (§12)

---

## 개요

Qradar 는 "고품질을 찾는 사람들의 레이더" 이고 사용자는 **Qrator(품질 선별자)** 인데, **선별할 수단이 없다.**
`stores.averageScore` / `reviewCount` 는 UI 에 노출되지만 **갱신 경로가 존재하지 않는다.**

이 task 는 그 입력원을 만든다. 1차 범위는 **입력 → 집계 → 표시** 한 바퀴를 닫는 것까지로 좁힌다.

### 전제 — 별점 아님

평가는 **S / A / B / C 4단계 등급 선택**이다. 1~5 별점이 아니다.
기존 도메인(`StoreGrade`, `GradeCalculator`, `GradeThresholds`)이 이미 그렇게 설계돼 있고 브랜드 컨셉과 맞는다.

> `docs/backlog.md:169` "매장 후기 / 평점 — 1~5점 + 텍스트 리뷰" 는 **낡은 기술**이다. 이 spec 이 우선한다. backlog 갱신 필요(§10).

---

## 1. 사전 조사 결과 (실측, 2026-10-22)

추측 없이 코드 / Rules / 시드를 직접 읽은 결과만 기록한다.

### 1.1 이미 존재하는 것 (중복 설계 금지)

| 항목 | 위치 | 실측 상태 |
|---|---|---|
| `ReviewEntity` | `lib/domain/entities/review_entity.dart` | `id / storeId / userId / grade / comment? / createdAt`. 참조 코드 0건 |
| `ReviewModel` | `lib/data/models/review_model.dart` | `fromFirestore` + `toEntity` 만. **쓰기 메서드 없음** |
| `StoreGrade` | `lib/domain/entities/store_grade.dart` | S/A/B/C enum + `fromString` / `asString` / `label` / `score`(S=4…C=1) / `color` |
| `GradeCalculator` | `lib/core/utils/grade_calculator.dart` | `fromAverage(double)` / `fromReviews(List<StoreGrade>)`. 0건 → C 폴백 |
| `GradeThresholds` | `lib/core/constants/grade_thresholds.dart` | `sMin=3.5 / aMin=2.5 / bMin=1.5` |
| `GradeBadge` | `lib/presentation/customer/home/widgets/grade_badge.dart` | `reviewCount == 0` → `(-)`. 등급 라벨은 항상 표시 |
| `reviews` Rules | `firestore.rules` `match /reviews/{reviewId}` | U-4 안전 기본값. 상세 §1.3 |
| Repository / DataSource / UseCase | — | **없음**. `review_repository.dart` 미존재 |
| 리뷰 UI | — | **없음** |

### 1.2 **핵심 발견 — `grade` 는 Firestore 에서 읽지 않는다**

`lib/data/models/store_model.dart:186`

```dart
grade: GradeCalculator.fromAverage(averageScore),
```

`StoreModel.toEntity()` 가 `averageScore` 에서 **파생**한다. Firestore `stores.grade` 필드는 **읽히지 않는 죽은 필드**다.
(시드는 `'grade': 'A'` 를 쓰지만 무시된다 — 그래서 화면에는 `averageScore 4.6` 기준 **S급**으로 나온다. 시드가 말하는 A 와 불일치.)

→ **집계 주체는 `averageScore` / `reviewCount` 2개만 쓰면 된다. `grade` 는 쓰지 않는다.**

### 1.3 `reviews` Rules 현재 내용 (실측)

```
match /reviews/{reviewId} {
  allow read:   if isSignedIn();
  allow create: if isSignedIn() && request.resource.data.get('userId','') == uid();
  allow update: if isSignedIn() && resource.data.get('userId','') == uid();
  allow delete: if isAdmin() || (isSignedIn() && resource.data.get('userId','') == uid());
}
```

문제점:
- **필드 화이트리스트 없음** → `storeId` 변조, `score` 임의값, `createdAt` 위조 가능
- **자격 검증 없음** → 주문하지 않은 매장에도 리뷰 작성 가능
- **중복 방지 없음** → 자동 ID 로 무한 생성 가능 (등급 조작 가능)
- `update` 가 `storeId` 변경도 허용 → 평가를 다른 매장으로 이동 가능

→ **Rules 보강 필수** (§7.1).

### 1.4 **핵심 발견 — `stores` 는 고객이 절대 못 쓴다**

`firestore.rules:252~` `match /stores/{storeId}` update 허용 분기는 3개뿐:

```
allow update: if isAdmin()
              || isStoreOwnerFieldUpdate(storeId)
              || isStoreOwnerBrandUpdate();
```

그리고 두 점주/브랜드 화이트리스트(`onlyChangedFields([...])`) 에 `averageScore` / `reviewCount` / `grade` 는 **들어 있지 않다.**

| actor | `stores.averageScore` 쓰기 |
|---|---|
| customer | ❌ update 분기 자체에 해당 없음 |
| owner | ❌ 화이트리스트 미포함 |
| brand | ❌ 화이트리스트 미포함 |
| admin | ✅ (운영 수단으로만) |
| Cloud Function (Admin SDK) | ✅ Rules 우회 |

→ **클라이언트 Transaction 집계는 구조적으로 불가능. Cloud Function 이 유일한 선택지다** (§3, D1).
→ owner_sales 와 달리 이번 task 는 **CF 배포가 필요하다.**

### 1.5 시드 데이터 실측 — 스케일 자체가 다르다

`lib/dev/seed/phase1_seed_data.dart`

| 문서 | `grade` | `averageScore` | `reviewCount` |
|---|---|---|---|
| `storeDoc()` (L225~) | `'A'` | **4.6** | **128** |
| `brandStoreDoc()` (L80~) | `'A'` | **4.7** | **54** |

`StoreGrade.score` 의 최대값은 **S = 4**. 즉 실제 리뷰로 계산된 `averageScore` 는 **1.0 ~ 4.0** 범위다.
시드의 `4.6` / `4.7` 은 **1~5 별점 스케일 잔재**이고, 현 도메인에서 **표현 불가능한 값**이다.

- `GradeCalculator.fromAverage(4.6)` → `>= 3.5` → **S급**. 그래서 사용자가 본 `S급 (128)` 이 나온다.
- 실제 리뷰가 1건 들어오면 평균이 1.0~4.0 으로 떨어져 **S → B 급락**처럼 보인다.

→ 정정 필요 (§3.5, D5).

### 1.6 리뷰 작성 자격의 근거 — order lifecycle

`docs/processes/entity_lifecycle.md` + `lib/domain/entities/order_status.dart`

- 정상 종료 상태는 **`completed`** (ready → completed, 점주가 픽업 완료 처리, Rules O7)
- `completedAt` 타임스탬프 존재 (`OrderEntity.completedAt`, Phase 3c 부터 기록)
- `cancelled` / `refunded` 는 종료지만 평가 자격 없음

`orders` read 권한 (실측): `isAdmin() || userId == uid() || isStoreOwner(storeId)` → 고객은 자기 주문을 읽을 수 있고, **Rules 안에서 `get(orders/{id})` 로 자격 검증 가능**.

`orders` create 는 `if false` (CF 전용) — 단 **Console / Admin SDK 는 Rules 를 우회**하므로, 테스트용 `completed` 주문은 **결제 없이 Console 에서 직접 만들 수 있다** (§9 에서 활용).

### 1.7 리뷰 표시 지점 (실측) — "매장 상세" 화면은 없다

`GradeBadge` 사용처 5곳:

| 위치 | 화면 |
|---|---|
| `customer/home/widgets/store_card.dart:60,149` | 고객 홈 매장 카드 |
| `customer/home/widgets/frequent_stores_section.dart:168` | 자주 가는 매장 |
| `customer/order/widgets/store_map_marker_sheet.dart:90` | 지도 마커 시트 |
| `customer/order/store/widgets/store_menu_header.dart:93` | **매장 메뉴 페이지 헤더** |
| `owner/my_store/my_store_page.dart:473` | 점주 내 매장 |

고객용 "매장 상세" 전용 페이지는 **없다.** 가장 가까운 것은 `customer/order/store/store_menu_page.dart` (메뉴 페이지).
→ 리뷰 목록 진입점은 **`store_menu_header` 의 `GradeBadge` 탭**으로 둔다 (§5.3).

점주 쪽: `my_store_page.dart:737~749` 가 `등급 / 평균 점수 / 리뷰 수` 3-Metric 행. → 여기서 리뷰 목록 진입.

### 1.8 기존 CF 패턴 (재사용)

`functions/src/` — `onOrderCreated` / `onOrderStatusChanged` / `onOrderRefundRequested` 가 **이미 Firestore 트리거 CF 패턴**을 쓴다.

- region: `asia-northeast3` (각 파일에서 개별 지정)
- `functions/src/index.ts` 에서 `export { ... }` 로만 등록
- `admin.initializeApp()` 은 `index.ts` 에서 1회
- 실패는 `console.error` 후 swallow (트리거 CF 재시도 폭주 방지)

→ `onReviewWritten` 도 동일 패턴을 따른다.

### 1.9 Rules 테스트 하네스 (실측)

`test_rules/rules.test.mjs` — `@firebase/rules-unit-testing`, 에뮬레이터 `127.0.0.1:8137`.
`withSecurityRulesDisabled` 로 `users` / `stores` / `orders` 시드 후 `run(name, 'allow'|'deny', fn)` 로 단건 검증.
owner_sales 에서 확장한 구조를 그대로 재사용한다 (§9.1).

---

## 2. 요구사항

### 2.1 1차 범위 (이번 task)

| # | 요구사항 |
|---|---|
| F1 | 고객이 **`completed` 주문**을 근거로 해당 매장에 S/A/B/C 평가 + 선택적 코멘트 작성 |
| F2 | 같은 매장에 대한 자기 평가는 **1건만** 존재. 재주문 후 다시 평가하면 **기존 평가를 갱신** |
| F3 | 작성한 평가 **수정** 가능 (등급 / 코멘트) |
| F4 | `stores.averageScore` / `reviewCount` 가 **Cloud Function 으로 자동 갱신** |
| F5 | 매장 메뉴 페이지에서 **리뷰 목록 조회** (최신순) |
| F6 | 점주가 **자기 매장 리뷰 목록 조회** |
| F7 | 리뷰 0건 매장은 `C급` 이 아니라 **`미평가`** 로 구분 표시 |
| F8 | 시드 데이터의 스케일 불일치(`averageScore 4.6`) 정정 |

### 2.2 2차 범위 (이번에 하지 않음 — 명시적 제외)

owner_sales 의 S1~S6 방식과 동일하게 별 task 로 분리한다.

| # | 항목 | 미루는 이유 |
|---|---|---|
| R1 | **리뷰 삭제 UI** (Rules 는 이미 허용) | 집계는 CF 가 자동 보정하므로 기술 리스크 없음. UI/정책만 남아 1차에서 빼도 안전 |
| R2 | **"내가 쓴 평가" 목록** (Log 탭 내) | `userId` 인덱스 + `storeName` 비정규화 필요. 범위 확대 |
| R3 | **점주 답글** | `reviews` 문서에 점주 쓰기 권한 추가 → 권한 모델 재설계 필요 |
| R4 | **신고 / 차단 / 금칙어 필터** | 운영 도구 + admin 화면 동반 필요 |
| R5 | **베이지안 보정 / 최소 리뷰 수 기반 정렬·추천** | `streamRecommended` 의 `orderBy averageScore desc` 영향 (§8) |
| R6 | **사진 리뷰** | Storage rules + 업로드 파이프라인 |
| R7 | `grade` **Firestore 영속화** + `GradeThresholds` → Remote Config | 현재 파생 방식으로 충분 (§1.2) |
| R8 | 리뷰 **페이지네이션** | 1차는 `limit(50)` 고정 (§6.3) |

---

## 3. 집계 설계 (핵심)

### 3.1 집계 주체 — **Cloud Function `onReviewWritten` 전담** (결정 D1)

| 선택지 | 판정 |
|---|---|
| **A. Cloud Function `onReviewWritten` 전담** | ✅ **추천** |
| B. 클라이언트 Firestore Transaction | ❌ **불가능** — §1.4, 고객은 `stores` update 분기에 해당하지 않음 |
| C. CF + 클라이언트 낙관적 갱신 병행 | ❌ 클라이언트 쓰기가 Rules 로 막혀 의미 없음. 로컬 낙관적 표시는 §3.4 로 대체 |
| D. Rules 화이트리스트에 `averageScore` 추가 | ❌ **금지** — 점주/브랜드가 자기 매장 평점을 자유 조작 가능. 치명적 |

**결론: CF 필수. 이번 task 는 `firebase deploy --only functions` 배포가 필요한 작업이다.**

### 3.2 집계 방식 — **증분(increment) 아님, 전량 재계산(absolute)** (결정 D1-a)

| 방식 | 평가 |
|---|---|
| **집계 쿼리(`count()` + `sum('score')`) 로 절대값 산출 후 overwrite** | ✅ **추천** |
| `FieldValue.increment(delta)` 증분 | ❌ 수정·삭제 보정이 복잡하고, 한 번 틀어지면 영구 누적 오차 |

전량 재계산을 택하는 이유:
1. **멱등(idempotent)** — 같은 트리거가 2번 돌아도 결과 동일
2. **자기 치유** — 시드 오염값(`4.6`), CF 실패로 인한 누락, 수동 Console 조작이 다음 리뷰 1건으로 전부 정정됨 (§3.5 가 여기에 의존)
3. **수정 / 삭제가 생성과 같은 코드 경로** — 보정 로직 불필요 (D4 가 여기에 의존)
4. 집계 쿼리 비용은 인덱스 엔트리 1000개당 1 read — 리뷰 수천 건까지 1 read

### 3.3 `score` 필드를 리뷰 문서에 비정규화 (결정 D1-b)

Firestore `sum()` 집계는 **숫자 필드**가 필요하다. `grade` 는 `'S'` 문자열이므로 집계 불가.

→ 리뷰 문서에 `score: int` (S=4 / A=3 / B=2 / C=1) 를 함께 저장한다.

- 클라이언트가 `StoreGrade.score` 로 채운다
- **Rules 가 `grade` ↔ `score` 일치를 강제**한다 (§7.1) — 그래야 비정규화가 조작 수단이 되지 않는다
- `grade` 와 `score` 둘 다 유지: `grade` 는 표시/도메인용, `score` 는 집계용

> 대안(리뷰 전체 문서를 CF 가 읽어 Dart 쪽과 동일하게 계산)은 매장당 리뷰 수에 비례한 read 비용이 들어 기각.

### 3.4 집계식과 반영 지연

```
reviewCount  = count(reviews where storeId == S)
averageScore = reviewCount == 0 ? 0.0 : sum(score) / reviewCount     // 1.0 ~ 4.0
grade        = (저장하지 않음) StoreModel.toEntity() 가 averageScore 에서 파생 (§1.2)
```

반올림: CF 는 `Math.round(avg * 100) / 100` (소수 2자리) 로 저장. 등급 경계(`3.5` / `2.5` / `1.5`) 가 소수 1자리라 2자리면 충분하고, `my_store_page` 의 `toStringAsFixed(1)` 표시와도 충돌하지 않는다.

**반영 지연 (eventual consistency)**:
- 리뷰 문서 쓰기는 **즉시** → 리뷰 목록은 `reviews` 컬렉션 직접 stream 이므로 **즉시 반영**
- `stores.averageScore` / `reviewCount` 는 CF 트리거 후 **수초 지연** → `GradeBadge` 는 늦게 바뀐다
- UI 처리: 작성 완료 후 스낵바에 **"평가가 등급에 반영되기까지 잠시 걸릴 수 있어요"** 안내. 낙관적 로컬 덮어쓰기는 **하지 않는다** (실패 시 거짓 표시 위험)

**동시성**: 절대값 overwrite 이므로 last-write-wins 이고 두 트리거가 동시에 돌아도 같은 값으로 수렴한다. 트리거 순서가 뒤집혀 직전 값이 1건 뒤처질 수 있으나 다음 쓰기에서 자기 치유된다.

**`stores.updatedAt` 은 건드리지 않는다.** 그 필드는 점주 운영 필드(`isStoreOwnerFieldUpdate` 화이트리스트)이고, CF 가 덮으면 점주 화면의 "최종 수정" 이 거짓이 된다. CF 는 `averageScore` / `reviewCount` **2개 필드만** 쓴다.

### 3.5 기존 시드 데이터 처리 (결정 D5)

§1.5 의 `averageScore 4.6 / 4.7`, `reviewCount 128 / 54` 는 **1~5 별점 스케일 잔재**이며 실제 리뷰 0건 상태의 거짓값이다.

처리:
1. `lib/dev/seed/phase1_seed_data.dart` 두 문서에서
   - `'averageScore': 0.0`, `'reviewCount': 0` 으로 수정
   - `'grade': 'A'` **필드 삭제** (§1.2 — 읽히지 않는 죽은 필드. 남겨두면 다음 설계자가 또 오해한다)
2. 이미 운영 Firestore 에 들어간 문서: **별도 마이그레이션 코드를 쓰지 않는다.**
   - 해당 매장에 실제 리뷰 1건이 들어오면 CF 전량 재계산이 **즉시 진실로 덮어쓴다** (§3.2 의 자기 치유)
   - 리뷰가 들어오기 전까지는 거짓 S급이 남으므로, **사용자가 Firebase Console 에서 두 문서의 `averageScore` → `0`, `reviewCount` → `0` 으로 직접 수정**한다 (§12 A5, 2필드 × 2문서 = 수동 4회)
3. `StoreModel.toFirestoreForCreate()` (L223) / 다른 create 경로(L285) 는 이미 `0.0 / 0` 이므로 **변경 불필요**

---

## 4. 작성 자격 · 중복 방지 (결정 D2 / D3)

### 4.1 문서 ID 설계 — `{storeId}_{userId}` (결정 D3)

| 선택지 | 중복 방지 | 자격 검증 | 1인 1표 | 평가 |
|---|---|---|---|---|
| **A. `{storeId}_{userId}`, 본문에 `orderId` 필수** | ✅ 구조적 | ✅ 본문 `orderId` 로 `get(orders/...)` | ✅ | ✅ **추천** |
| B. `{orderId}` | ✅ 구조적 | ✅ `reviewId` 자체가 orderId | ❌ 주문 N건 = N표 → 소액 반복 주문으로 등급 조작 가능 | 대안 |
| C. 자동 ID | ❌ 무제한 | △ | ❌ | ❌ 기각 |

**A 추천 이유**: Qradar 의 제품 가치는 **등급의 신뢰도**다. 1인 1표가 아니면 매장이 지인/본인 반복 주문으로 S급을 살 수 있다.
A 는 재주문 후 재평가를 **같은 문서 update** 로 흡수하므로 "최신 방문 기준 1표" 가 되고, F2 / F3 / D4 가 한 메커니즘으로 해결된다.

**리뷰 문서 스키마 (`reviews/{storeId}_{userId}`)**

| 필드 | 타입 | 비고 |
|---|---|---|
| `storeId` | string | create 후 immutable |
| `userId` | string | `== uid()`, immutable |
| `orderId` | string | 자격 근거 주문. update 시 갱신 허용(재주문 후 재평가) |
| `grade` | string | `'S'\|'A'\|'B'\|'C'` |
| `score` | int | 4/3/2/1. Rules 가 `grade` 와 일치 강제 |
| `comment` | string? | 선택. 최대 300자 (Rules 강제) |
| `createdAt` | timestamp | `request.time` 강제, immutable |
| `updatedAt` | timestamp? | 수정 시 `request.time` 강제 |

### 4.2 작성 자격 (결정 D2)

| 조건 | 강제 지점 |
|---|---|
| 주문 `status == 'completed'` | **Rules + UI** |
| 주문 `userId == uid()` | **Rules + UI** |
| 주문 `storeId == review.storeId` | **Rules + UI** |
| `reviewId == storeId + '_' + uid()` | **Rules** |
| 픽업 완료 후 **14일 이내** | **UI 만** (결정 D2-b) |

**D2-b — 기한 검증은 UI 에만 둔다. 추천안.**
- Rules 에 넣으면 `order.completedAt + duration.value(14,'d')` 비교가 필요한데, **Phase 3c 이전 `completed` 주문에는 `completedAt` 이 없다** (§1.6). null 분기가 들어가면 기한이 사실상 무력화되거나 legacy 주문이 영구 차단된다.
- 기한은 **보안 경계가 아니라 품질 정책**이다. 뚫려도 피해는 "오래된 주문으로 1표" 뿐이고, 1인 1표 구조(§4.1)가 이미 조작 상한을 막는다.
- 대안(Rules 에도 넣기)은 2차 범위로. `completedAt` 백필 이후 재검토.

### 4.3 수정 · 삭제 (결정 D4)

| 동작 | 1차 | 메커니즘 |
|---|---|---|
| 수정 | ✅ 허용 | 같은 문서 update. 변경 허용 필드 `grade / score / comment / orderId / updatedAt` 만 |
| 삭제 | ⬜ **UI 미제공** (2차 R1) | Rules 는 현행 유지(본인 또는 admin). CF 가 삭제 트리거도 재계산하므로 admin 수동 삭제도 안전 |

**집계 보정이 불필요한 이유**: §3.2 전량 재계산. 수정/삭제/생성 모두 `onReviewWritten` 한 경로로 수렴한다.

---

## 5. 레이어 설계

`docs/architecture.md` 기준. 의존 방향 `presentation → domain ← data`.

### 5.1 Domain (순수 Dart, Firebase import 금지)

| 파일 | 변경 | 내용 |
|---|---|---|
| `lib/domain/entities/review_entity.dart` | **수정** | `orderId`(required), `updatedAt`(nullable) 추가. `score` 는 **넣지 않음** — `grade.score` 로 파생 가능한 중복 (저장층 전용 비정규화) |
| `lib/domain/repositories/review_repository.dart` | **신규** | 인터페이스 |
| `lib/domain/usecases/submit_store_review_use_case.dart` | 신규 | 작성/수정 통합 (upsert). 자격 검증(주문 status/소유/매장 일치/14일) 을 여기서 수행 |
| `lib/domain/usecases/get_store_reviews_use_case.dart` | 신규 | `Stream<List<ReviewEntity>>` (매장 단위, 최신순) |
| `lib/domain/usecases/get_my_store_review_use_case.dart` | 신규 | `Stream<ReviewEntity?>` — 내가 이 매장에 쓴 평가 (버튼 라벨 "평가하기"/"평가 수정" 분기용) |

`ReviewRepository` 인터페이스:

```
Stream<List<ReviewEntity>> watchStoreReviews(String storeId, {int limit});
Stream<ReviewEntity?>      watchMyReview({required String storeId, required String userId});
Future<void>               upsertReview({
  required String storeId, required String userId, required String orderId,
  required StoreGrade grade, String? comment,
});
```

> `upsertReview` 가 생성/수정을 모두 담당한다. 문서 ID 가 결정적(`{storeId}_{userId}`)이므로 `set(merge:true)` 가 아니라 **존재 확인 후 create / update 분기** — `createdAt` immutable 과 Rules 화이트리스트를 지키기 위함.

### 5.2 Data

| 파일 | 변경 | 내용 |
|---|---|---|
| `lib/data/models/review_model.dart` | **수정** | `orderId` / `score` / `updatedAt` 추가. `fromFirestore` 보강. `toFirestoreForCreate()` / `toFirestoreForUpdate()` 신규 (`createdAt`/`updatedAt` 은 `FieldValue.serverTimestamp()` 아님 — Rules 가 `request.time` 을 강제하므로 `serverTimestamp()` 사용. §7.1 주의) |
| `lib/data/datasources/remote/review_remote_data_source.dart` | 신규 | `cloud_firestore` 직접 사용은 여기까지 |
| `lib/data/repositories/review_repository_impl.dart` | 신규 | Model ↔ Entity 매핑, 예외 → 도메인 실패 변환 |

`ReviewRemoteDataSource` 쿼리:

```
// 매장 리뷰 목록
collection('reviews').where('storeId','==',storeId)
  .orderBy('createdAt', descending: true).limit(50).snapshots()

// 내 평가 (문서 ID 직접 접근 — 쿼리 불필요)
collection('reviews').doc('${storeId}_$userId').snapshots()
```

### 5.3 Presentation

| 파일 | 변경 | 내용 |
|---|---|---|
| `lib/presentation/customer/review/store_review_form_page.dart` | 신규 | S/A/B/C 선택 + 코멘트. 작성/수정 겸용 |
| `lib/presentation/customer/review/store_reviews_page.dart` | 신규 | 매장 리뷰 목록 (고객) |
| `lib/presentation/customer/review/providers/review_di_providers.dart` | 신규 | DataSource/Repository/UseCase provider (`order_di_providers.dart` 패턴) |
| `lib/presentation/customer/review/providers/store_review_providers.dart` | 신규 | 화면 상태 provider |
| `lib/presentation/customer/review/widgets/grade_selector.dart` | 신규 | S/A/B/C 4지 선택 위젯 (designer 명세) |
| `lib/presentation/customer/review/widgets/review_card.dart` | 신규 | 리뷰 1건 카드 |
| `lib/presentation/customer/order/orders/order_detail_page.dart` | **수정** | `_ActionSection` 의 `case OrderStatus.completed:` (L618) 에 **"매장 평가하기" / "평가 수정" 버튼** 추가 |
| `lib/presentation/customer/order/store/widgets/store_menu_header.dart` | **수정** | `GradeBadge`(L93) 를 탭 가능하게 → `store_reviews_page` 진입 |
| `lib/presentation/customer/home/widgets/grade_badge.dart` | **수정** | `reviewCount == 0` → 라벨 `미평가`, 카운트 숨김 (F7) |
| `lib/presentation/owner/reviews/owner_store_reviews_page.dart` | 신규 | 점주 리뷰 목록 (읽기 전용) |
| `lib/presentation/owner/my_store/my_store_page.dart` | **수정** | L748 `리뷰 수` Metric 탭 → `owner_store_reviews_page` 진입 |

**작성 진입점은 `order_detail_page` 단일**로 한다 (1차). `orders_page`(Log) 카드에 CTA 를 붙이는 것은 범위 확대이고, 주문 상세가 이미 `completed` 주문의 유일한 종착지다.

### 5.4 리뷰 작성 진입점 판정 로직

`order_detail_page` 의 `completed` 분기에서:

```
표시 조건: order.status == completed
버튼 라벨: myReview == null ? '매장 평가하기' : '평가 수정'
비활성 조건: order.completedAt != null && now - completedAt > 14일
             → '평가 기간이 지났어요' 안내 (버튼 숨김)
```

`myReview` 는 `watchMyReview(storeId, uid)` 로 조회. **주문 1건 기준이 아니라 매장 기준**이므로, 같은 매장의 다른 주문 상세에서도 같은 평가가 "수정" 으로 보인다 — D3(1인 1표) 의 의도된 귀결이며, 폼 상단에 **"이 매장에 대한 내 평가"** 라고 명시해 혼선을 막는다 (designer 과제).

---

## 6. 데이터 흐름

### 6.1 작성 / 수정

```
order_detail_page (completed)
  → store_review_form_page (grade 선택 + comment)
  → SubmitStoreReviewUseCase
      ├ 자격 검증: order.status==completed / order.userId==uid / order.storeId==storeId / 14일
      └ ReviewRepository.upsertReview
          → ReviewRemoteDataSource
              → reviews/{storeId}_{userId}  create 또는 update   [Rules 검증]
                  ↓ (Firestore 트리거)
              Cloud Function onReviewWritten
                  → count() + sum('score') on reviews where storeId==S
                  → stores/{storeId}.{averageScore, reviewCount} 갱신  [Admin SDK, Rules 우회]
                      ↓
                  StoreModel.toEntity() → GradeCalculator.fromAverage → GradeBadge 갱신
```

### 6.2 조회

```
store_menu_page 헤더 GradeBadge 탭
  → store_reviews_page
  → GetStoreReviewsUseCase → reviews where storeId==S orderBy createdAt desc limit 50

my_store_page '리뷰 수' Metric 탭
  → owner_store_reviews_page  (동일 UseCase 재사용)
```

### 6.3 조회 상한

1차는 **`limit(50)` 고정, 페이지네이션 없음** (2차 R8). 50건 초과 시 목록 하단에 "최근 50개 평가를 보여드려요" 안내.
`reviewCount` 는 CF 집계값이므로 50 을 넘어도 정확히 표시된다.

---

## 7. 인프라 변경 (배포 필요 작업)

owner_sales 는 CF/Rules 변경 0건이었으나, **이번 task 는 3종 모두 배포가 필요하다.**

### 7.1 Firestore Rules — `match /reviews/{reviewId}` 전면 교체

현행 §1.3 → 아래 요구사항으로 보강. (정확한 Rules 문법 작성은 developer 과제)

**create 조건**
- `isSignedIn()`
- `reviewId == request.resource.data.storeId + '_' + uid()`
- `request.resource.data.userId == uid()`
- `request.resource.data.keys().hasOnly(['storeId','userId','orderId','grade','score','comment','createdAt'])`
- `hasAll(['storeId','userId','orderId','grade','score','createdAt'])`
- `grade in ['S','A','B','C']`
- `score` 가 `grade` 와 일치: `(grade=='S' && score==4) || (grade=='A' && score==3) || (grade=='B' && score==2) || (grade=='C' && score==1)`
- `createdAt == request.time`
- `comment` 는 없거나 `is string && size() <= 300`
- **주문 자격** — `let o = get(/databases/$(database)/documents/orders/$(request.resource.data.orderId)).data;`
  - `o.userId == uid()`
  - `o.status == 'completed'`
  - `o.storeId == request.resource.data.storeId`

**update 조건**
- `resource.data.userId == uid()` (본인)
- `onlyChangedFields(['grade','score','comment','orderId','updatedAt'])` → `storeId` / `userId` / `createdAt` **immutable**
- `grade` / `score` 일치 검증 (create 와 동일)
- `updatedAt == request.time`
- `comment` 길이 검증 동일
- **주문 자격** 재검증 (`orderId` 가 바뀌어도 유효해야 함) — create 와 동일 `get()` 검증

**read** — `isSignedIn()` 유지 (변경 없음)
**delete** — 현행 유지 (`isAdmin() || 본인`). 1차 UI 는 없지만 Rules 는 그대로 두고 CF 가 집계를 보정한다.

**stores 블록은 변경하지 않는다.** CF 가 Admin SDK 로 쓰므로 Rules 완화가 전혀 필요 없고, 완화하면 점주 조작 경로가 열린다 (§3.1 D).

> ⚠️ `createdAt == request.time` 을 쓰면 클라이언트는 반드시 `FieldValue.serverTimestamp()` 로 보내야 한다. `DateTime.now()` 를 보내면 Rules 가 거부한다. developer 주의 사항.
> ⚠️ `get()` 1회는 Rules 평가 비용 1 read 다. create/update 당 1회로 제한한다 (중복 `get()` 금지 — `let` 으로 1회 바인딩).

### 7.2 Cloud Function — `onReviewWritten` **신규**

| 항목 | 값 |
|---|---|
| 파일 | `functions/src/onReviewWritten.ts` (신규) |
| 등록 | `functions/src/index.ts` 에 `export { onReviewWritten } from "./onReviewWritten";` 1줄 추가 |
| 트리거 | `onDocumentWritten`, `document: "reviews/{reviewId}"` |
| region | `asia-northeast3` (기존 CF 와 동일) |

로직:
1. `before` / `after` 추출. `storeId = after?.storeId ?? before?.storeId`. 없으면 `console.warn` 후 return
2. **early return** — `before` 와 `after` 가 모두 있고 `score` 와 `storeId` 가 둘 다 무변경이면 skip (코멘트만 수정한 경우 집계 불필요)
3. `storeId` 변경(이론상 Rules 로 차단되지만 admin 경로 존재) 이면 **before/after 양쪽 매장** 재계산
4. 각 대상 매장에 대해
   - `db.collection('reviews').where('storeId','==',sid)` 에 `.count()` + `.aggregate(sum('score'))`
   - `reviewCount = count`, `averageScore = count === 0 ? 0 : Math.round((sum/count)*100)/100`
   - `stores/{sid}` 존재 확인 후 `update({ averageScore, reviewCount })` — **다른 필드 금지, `updatedAt` 금지** (§3.4)
   - 매장 문서 없으면 `console.warn` 후 skip
5. 실패는 `console.error` 후 swallow (기존 트리거 CF 패턴, 재시도 폭주 방지)

**배포**: `cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only functions:onReviewWritten`

### 7.3 Firestore 복합 인덱스 — `firestore.indexes.json`

| # | collection | 필드 | 용도 |
|---|---|---|---|
| I1 | `reviews` | `storeId` ASC, `createdAt` DESC | §5.2 매장 리뷰 목록 |
| I2 | `reviews` | `storeId` ASC, `score` ASC | §7.2 `sum('score')` 집계 쿼리 |

> I2 는 Firestore 집계 쿼리가 합산 필드를 인덱스에 요구하는지에 따라 달라진다. **developer 가 에뮬레이터 / Console 의 인덱스 에러 메시지로 최종 확정**한다 (추측 금지). I1 은 확실히 필요하다.

**배포**: `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only firestore:indexes,firestore:rules`

---

## 8. 기존 기능에 미치는 영향

| 영향 | 내용 | 1차 처리 |
|---|---|---|
| **추천 매장 정렬** | `store_remote_data_source.dart:24` `orderBy('averageScore', descending: true)`. 시드 정정(§3.5) 후 전 매장 `0.0` → 정렬 순서가 사실상 임의 | **수용**. 2차 R5 에서 베이지안 보정 |
| `GradeBadge` 5개 사용처 | F7 변경이 전부에 전파 (홈 카드 / 자주가는 매장 / 지도 시트 / 메뉴 헤더 / 점주 내 매장) | 위젯 1곳 수정으로 일괄 반영. designer 가 `미평가` 표기 확정 |
| `my_store_page` 3-Metric | `등급 / 평균 점수 / 리뷰 수`. 리뷰 0건이면 `C급 / 0.0 / 0` | `등급` → `미평가`, `평균 점수` → `-` 로 분기 (designer) |
| `StoreEntity.grade` | 0건에서도 `C` 폴백 유지 (`GradeCalculator.fromReviews` 계약 불변) | **도메인 변경 없음**. UI 에서만 `reviewCount == 0` 분기 — nullable grade 도입은 범위 과대 |
| `stores.grade` 필드 | 읽히지 않는 죽은 필드 | 시드에서 제거. Firestore 기존 문서의 잔여 필드는 무해하므로 방치 |

---

## 9. 테스트 전략 — 실행 가능성 우선

owner_sales 에서 환경 제약 보류가 쌓인 문제를 반복하지 않는다. **각 시나리오에 필요한 환경과 결제 필요 여부를 명시**한다.

### 9.1 Rules 검증 — `test_rules/rules.test.mjs` 확장 (결제 0회)

**환경**: `firebase emulators:start --only firestore` (포트 8137) + `node test_rules/rules.test.mjs`
**시드**: `withSecurityRulesDisabled` 로 `orders` 문서 직접 주입 → **결제 불필요**

추가 시드:
- `o_done` : `userId=CUSTOMER, storeId=S_A, status='completed', completedAt`
- `o_paid` : `userId=CUSTOMER, storeId=S_A, status='paid'`
- `o_other`: `userId=OTHER,    storeId=S_A, status='completed'`

| # | 시나리오 | 기대 |
|---|---|---|
| RV1 | CUSTOMER 가 `reviews/S_A_{CUSTOMER}` create (orderId=o_done, grade=S, score=4, createdAt=serverTimestamp) | allow |
| RV2 | 같은 내용, `score=4` 인데 `grade='C'` | deny |
| RV3 | 문서 ID 가 `S_A_{CUSTOMER}` 가 아닌 자동 ID | deny |
| RV4 | `orderId=o_paid` (completed 아님) | deny |
| RV5 | `orderId=o_other` (타인 주문) | deny |
| RV6 | `storeId=S_B` 인데 orderId 는 S_A 주문 | deny |
| RV7 | `comment` 301자 | deny |
| RV8 | `createdAt` 을 클라이언트 고정 Timestamp 로 전송 | deny |
| RV9 | 허용 외 필드(`adminNote`) 포함 | deny |
| RV10 | 본인 리뷰 update — `grade`/`score`/`updatedAt` 만 변경 | allow |
| RV11 | 본인 리뷰 update — `storeId` 변경 시도 | deny |
| RV12 | 본인 리뷰 update — `createdAt` 변경 시도 | deny |
| RV13 | OWNER 가 CUSTOMER 리뷰 update | deny |
| RV14 | OWNER 가 CUSTOMER 리뷰 delete | deny |
| RV15 | CUSTOMER 가 본인 리뷰 delete | allow |
| RV16 | OWNER 가 `stores/S_A.averageScore` 직접 update | **deny** (§1.4 회귀 방지 — 가장 중요) |
| RV17 | CUSTOMER 가 `stores/S_A.reviewCount` 직접 update | **deny** |
| RV18 | 비로그인 read | deny |
| RV19 | 로그인 사용자가 타인 리뷰 read | allow |
| RV20 | 매장 리뷰 목록 쿼리 (`storeId ==` + `orderBy createdAt desc` + `limit 50`) | allow (I1 인덱스 동작 확인 겸용) |

### 9.2 Cloud Function 검증 — 에뮬레이터 (결제 0회)

**환경**: `cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build` 후
`cd /Users/Byeonguk/Developer/OrderApp && firebase emulators:start --only firestore,functions`

| # | 시나리오 | 기대 |
|---|---|---|
| CF1 | 리뷰 0건 매장에 `grade=S(4)` 리뷰 1건 생성 | `averageScore=4.0`, `reviewCount=1` |
| CF2 | 같은 매장에 다른 사용자가 `grade=B(2)` 추가 | `averageScore=3.0`, `reviewCount=2` |
| CF3 | CF1 리뷰를 `grade=C(1)` 로 수정 | `averageScore=1.5`, `reviewCount=2` |
| CF4 | 리뷰 1건 삭제 | `averageScore=2.0`, `reviewCount=1` |
| CF5 | 전부 삭제 | `averageScore=0.0`, `reviewCount=0` |
| CF6 | **시드 오염 자기 치유** — `averageScore=4.6/reviewCount=128` 매장에 `grade=A(3)` 리뷰 1건 | `averageScore=3.0`, `reviewCount=1` (§3.5) |
| CF7 | 코멘트만 수정 (grade 무변경) | `stores` 쓰기 발생하지 않음 (early return, 로그로 확인) |
| CF8 | 존재하지 않는 `storeId` 로 리뷰 생성 | CF 가 예외 없이 warn 후 종료 |
| CF9 | CF 실행 전후 `stores.updatedAt` / `name` / `status` 불변 | 2필드만 변경 (§3.4) |

### 9.3 Dart 단위 테스트 (환경 불필요)

| # | 대상 | 내용 |
|---|---|---|
| U1 | `GradeCalculator.fromAverage` | 경계값 `3.49/3.5/2.49/2.5/1.49/1.5/1.0/4.0` (기존 2건 보강) |
| U2 | `StoreGrade.score` ↔ `fromString` ↔ `asString` 왕복 | 4등급 전부 |
| U3 | `SubmitStoreReviewUseCase` 자격 검증 | status≠completed / 타인 주문 / storeId 불일치 / 14일 초과 각각 실패. Repository 는 fake |
| U4 | `ReviewModel.fromFirestore` | 필드 누락 / `score` 없음 / 잘못된 `grade` 문자열 폴백 |
| U5 | 14일 판정 순수 함수 | `completedAt == null` → 허용, 13일/15일 경계 |

**실행**: `cd /Users/Byeonguk/Developer/OrderApp && flutter test`

### 9.4 수동 UI 검증 — **실결제 0회**

`orders` 는 클라이언트 create 가 `if false` 지만 **Console 은 Rules 를 우회**한다 (§1.6).

**준비 (Firebase Console, 결제 없음)**: `orders` 컬렉션에 문서 수동 생성
```
문서 ID: manual_review_test_01
userId: <내 uid>        storeId: <테스트 매장 id>     storeName: <이름>
status: "completed"      totalPrice: 4500             subtotal: 4500
createdAt / updatedAt / completedAt: 현재 시각 (Timestamp)
items: []                paymentInfo: {}
```

| # | 시나리오 | 결제 |
|---|---|---|
| M1 | Log → 해당 주문 상세 → "매장 평가하기" 버튼 노출 | 불필요 |
| M2 | 폼에서 S 선택 + 코멘트 작성 → 저장 성공 + 지연 안내 스낵바 | 불필요 |
| M3 | 수초 후 매장 메뉴 헤더 `GradeBadge` 가 `S급 (1)` 로 갱신 | 불필요 |
| M4 | 같은 주문 상세 재진입 → 버튼이 "평가 수정" 으로 변경, 기존 값 프리필 | 불필요 |
| M5 | 등급 C 로 수정 → 배지가 `C급 (1)` 로 갱신 | 불필요 |
| M6 | `GradeBadge` 탭 → 리뷰 목록에 내 평가 표시 | 불필요 |
| M7 | 리뷰 0건 매장 배지가 `미평가` 로 표시 (F7) | 불필요 |
| M8 | 점주 계정 → 내 매장 → `리뷰 수` 탭 → 리뷰 목록 조회 | 불필요 |
| M9 | `completedAt` 을 20일 전으로 바꾼 주문 → 평가 버튼 숨김 + 기간 만료 안내 | 불필요 |

> **실결제가 필요한 시나리오는 1차 범위에 없다.** 결제 → `paid` → `completed` 까지의 실제 흐름 연동은 기존 order_flow task 에서 이미 검증됐고, 이 task 는 `completed` 주문을 **입력으로만** 쓴다.

---

## 10. 조사 중 발견한 문서 / 코드 불일치 (갱신 필요)

| # | 위치 | 현재 기술 | 실제 | 조치 |
|---|---|---|---|---|
| X1 | `docs/backlog.md:169` | "매장 후기 / 평점 — 1~5점 + 텍스트 리뷰. 매장 상세 화면" | 도메인은 S/A/B/C 등급. 매장 상세 화면 자체가 없음 | 구현 완료 후 backlog 항목 **삭제** + 2차 범위 R1~R8 로 대체 기술 |
| X2 | `lib/dev/seed/phase1_seed_data.dart` | `averageScore 4.6/4.7`, `grade:'A'` | 1~5 별점 잔재. 현 스케일 최대 4.0. `grade` 는 읽히지 않음 | §3.5 정정 |
| X3 | `docs/processes/data_ownership.md:247` | "`reviews` Rules 만 있고 UI 없음 / 갱신 경로 없음 — 미구현" | 정확 | 구현 완료 후 **해소 처리** + §2.10 에 `onReviewWritten` CF 전담 명시 |
| X4 | `docs/processes/role_flows.md:127, 212` | "리뷰 작성 — 미구현" | 정확 | 구현 완료 후 customer 4.1 액션표 + owner 4.2 에 진입점 추가 |
| X5 | `docs/processes/data_ownership.md` §3 CF 카탈로그 | `onReviewWritten` 없음 | 신규 | CF 카탈로그에 1행 추가 |
| X6 | `docs/processes/entity_lifecycle.md` | review 엔티티 없음 | 신규 엔티티지만 status 전이 없음 (등급 변경은 전이가 아님) | **다이어그램 추가 불필요.** order `ready→completed` 전이의 **후속 액션**으로 1줄 주석만 추가 |

> `reviews` 는 status 필드가 없는 엔티티이므로 `entity_lifecycle.md` 에 전이 다이어그램을 넣지 않는다. 대신 "completed 주문 → 리뷰 작성 자격 발생" 관계만 기록한다.

---

## 11. 작업 분배

### designer — **호출 필요 (필수)**

신규 화면 3개 + 기존 위젯 3곳 수정. UI 비중이 크다.

산출물: `docs/tasks/store_reviews/design.md`

1. **`store_review_form_page`** — S/A/B/C 선택 UI. 별점 메타포 금지(★ 아이콘 금지). 4개 등급을 동등한 선택지로 보이게 할 것. 각 등급의 **의미 문구**도 정의 (예: S=최고였어요 … C=아쉬웠어요). 코멘트 300자 카운터. 작성/수정 두 상태
2. **`grade_selector` 위젯** — 등급별 색은 `StoreGradeColor.color` (이미 `AppColors` 기반) 활용 여부 판단. 선택/미선택 상태
3. **`store_reviews_page`** — 리뷰 목록. 상단 요약(등급 + 평균 + 건수), 리뷰 카드(등급 배지 / 코멘트 / 작성일 / 작성자 표기 방식 — **Qrator 익명 처리 방식 결정 필요**), 0건 Empty, 로딩 Shimmer, 에러
4. **`review_card`** — 내 평가는 시각적으로 구분 + "수정" 진입
5. **`GradeBadge` F7** — `reviewCount == 0` 일 때 `미평가` 표기 (`(-)` 대체). 5개 사용처 전부에서 레이아웃 깨지지 않는지 확인
6. **`my_store_page` 3-Metric** — 0건일 때 `등급`/`평균 점수` 표기
7. **`order_detail_page` completed 액션** — "매장 평가하기" / "평가 수정" / "평가 기간 만료" 3상태
8. **`owner_store_reviews_page`** — 점주용 읽기 전용 목록. 답글은 2차(R3) 이므로 답글 UI 넣지 말 것
9. **지연 반영 안내** — §3.4 의 스낵바 문구

용어: 사용자 = **Qrator**, 주문 내역 = **Log**. 색상은 `AppColors` 만.

### developer — **호출 필요**

산출물: `docs/tasks/store_reviews/implementation.md`

구현 순서 (의존 역순):
1. `ReviewEntity` / `ReviewModel` 확장 → `dart run build_runner build --delete-conflicting-outputs`
2. `firestore.rules` `reviews` 블록 교체 (§7.1) — **`stores` 블록 건드리지 말 것**
3. `firestore.indexes.json` I1(+I2 확인) 추가
4. `functions/src/onReviewWritten.ts` + `index.ts` export (§7.2)
5. Domain: Repository 인터페이스 + UseCase 3개
6. Data: DataSource + RepositoryImpl
7. Presentation: DI providers → 화면 → 기존 3곳 수정
8. `phase1_seed_data.dart` 정정 (§3.5)
9. `flutter analyze` + `flutter test` 통과

주의:
- `createdAt` / `updatedAt` 은 **`FieldValue.serverTimestamp()`** — Rules 가 `request.time` 을 강제한다 (§7.1 경고)
- `cloud_firestore` / `firebase_functions` import 는 **`data` 레이어만**
- Rules `get()` 은 create/update 당 **1회**로 제한 (`let` 바인딩)
- CF 는 `stores` 의 `averageScore` / `reviewCount` **2필드만** 쓴다. `updatedAt` / `grade` 금지
- `GradeThresholds` 를 CF(TypeScript) 에 복제하지 말 것 — CF 는 등급을 계산하지 않는다 (§1.2)

### tester — **호출 필요**

산출물: `docs/tasks/store_reviews/test_report.md`

§9 전부 수행. **보류 사유로 "결제 필요" 는 받지 않는다** — §9.4 가 Console 수동 주문으로 결제를 제거했다.
RV16 / RV17 (점주·고객의 `stores.averageScore` 직접 쓰기 차단) 과 CF9 (2필드만 변경) 는 **보안 회귀 테스트**이므로 반드시 실행한다.

---

## 12. 사용자 확인이 필요한 결정사항 — **전건 확정 (2026-10-22)**

**D1~D6 / A1~A5 모두 추천안 그대로 확정됐다.**
아래 3건은 사용자에게 **직접 확인**했고, 나머지는 실측 근거로 추천안이 사실상 확정돼 수용했다.

| # | 항목 | 확정 | 방식 |
|---|---|---|---|
| **A3** | 리뷰 작성자 표기 | **익명** — `Qrator` + uid 앞 4자. `userName` 비정규화 하지 않음 | 사용자 직접 확인 |
| **A5** | 시드 매장 오염 평점 | **Console 에서 리셋** — 2문서의 `averageScore`→0, `reviewCount`→0 (4회 편집) | 사용자 직접 확인 |
| **D2-b** | 14일 기한 | **UI 에서만 강제.** Rules 에 넣지 않음 (`completedAt` 백필 불필요) | 사용자 직접 확인 |
| D1 | 집계 주체 | CF `onReviewWritten` 전담 (클라이언트 집계는 Rules 상 **구조적으로 불가**) | 수용 — 실측 근거 |
| D3 | 문서 ID | `{storeId}_{userId}` + 본문 `orderId` 필수 (1인 1매장 1표) | 수용 |
| D4 | 수정·삭제 | 수정 허용, 삭제 UI 는 2차. 전량 재계산이라 집계 보정 로직 불필요 | 수용 |
| D5 | 기존 시드 | A5 로 처리 + CF 자기 치유 | 수용 |
| D6 | 리뷰 0건 표시 | `미평가` 라벨 (`GradeBadge` 1곳 수정 → 5개 사용처 전파) | 수용 |
| A1·A2·A4 | — | spec 원문 추천안 수용 | 수용 |

### A3 확정의 부수 효과

`userName` 비정규화를 하지 않으므로 **닉네임 변경 시 과거 리뷰가 옛 이름으로 남는 문제가 발생하지 않는다.** 리뷰 문서 스키마도 architect 가 설계한 그대로 유지된다.

### A5 실행 시점

**CF 배포 전에 리셋하면** 리셋 직후부터 실 리뷰가 들어오기 전까지 해당 매장이 `미평가` 로 보인다 — 이것이 사실에 부합하는 상태다.
리셋하지 않으면 실제 리뷰 0건인 매장이 계속 S급으로 보인다. 도메인상 나올 수 없는 값(최대 4.0 인데 4.7)이므로 **구현 전에 정리한다.**

---

### (원문) 결정사항과 선택지

※ ①~⑥ 은 요구사항의 결정 항목, A1~A5 는 architect 가 추가로 발견한 항목.

| # | 결정 항목 | 선택지 | **추천안** |
|---|---|---|---|
| **D1** | **집계 주체** (①) | A: CF `onReviewWritten` / B: 클라이언트 Transaction / C: 병행 / D: Rules 완화 | **A.** B·C·D 는 §1.4 실측상 **불가능하거나 위험**. **CF 배포 필요 작업** |
| **D1-a** | 집계 방식 | 전량 재계산 / increment 증분 | **전량 재계산.** 멱등 + 자기 치유 + 수정/삭제 보정 불필요 (§3.2) |
| **D1-b** | `score` 비정규화 | 저장 / CF 가 전 문서 읽어 계산 | **저장.** `sum()` 집계용. Rules 가 `grade` 와 일치 강제 (§3.3) |
| **D2** | **작성 자격** (②) | completed 만 / ready 이후 / 제한 없음 | **`completed` 주문만.** 픽업 완료가 정상 종료 (§1.6) |
| **D2-b** | 기한 | 14일 (UI 만) / 14일 (Rules+UI) / 무제한 | **14일, UI 에서만 강제.** legacy 주문 `completedAt` 부재 때문 (§4.2) |
| **D3** | **중복 방지 / 문서 ID** (③) | `{storeId}_{userId}` / `{orderId}` / 자동 | **`{storeId}_{userId}` + 본문 `orderId`.** 1인 1표 = 등급 신뢰도. 재주문 시 덮어쓰기 (§4.1) |
| **D4** | **수정·삭제** (④) | 수정만 / 수정+삭제 / 둘 다 불가 | **수정만 1차.** 삭제 Rules 는 유지, UI 는 2차(R1). 보정은 D1-a 가 자동 처리 (§4.3) |
| **D5** | **기존 시드 데이터** (⑤) | 시드 코드 정정 + **Console 수동 0 리셋** / 마이그레이션 스크립트 / 방치 | **시드 코드 정정 + Console 수동.** 대상 2문서 뿐이고 실 리뷰 1건이면 CF 가 자동 정정 (§3.5) |
| **D6** | **0건 표시** (⑥) | `미평가` 라벨 / `C급 (-)` 유지 / grade nullable | **`미평가` 라벨.** UI 분기만. 도메인(`fromReviews` → C 폴백) 불변 (§8) |
| **A1** | `stores.grade` 죽은 필드 | 시드에서 제거 / 유지 / CF 가 영속화 | **시드에서 제거.** 읽히지 않는 필드를 남기면 재오해 유발 (§1.2). 영속화는 2차 R7 |
| **A2** | `averageScore` 스케일 | 1.0~4.0 유지 / 1~5 로 재설계 | **1.0~4.0 유지.** `StoreGrade.score` / `GradeThresholds` 가 이미 그 전제 |
| **A3** | 리뷰 작성자 표기 | 익명 / 닉네임 일부 마스킹 / 전체 닉네임 | **결정 필요.** `users.displayName` 비정규화 여부에 영향 (현 스키마에 `userName` 없음). architect 추천: **1차는 `Qrator` + uid 앞 4자** 정도의 익명 표기로 비정규화 회피 |
| **A4** | 작성 진입점 범위 | `order_detail_page` 만 / `orders_page` 카드 CTA 포함 | **`order_detail_page` 만.** 카드 CTA 는 2차 |
| **A5** | 운영 Firestore 수동 작업 | 사용자가 Console 에서 2문서 × 2필드 리셋 수행 | **사용자 확인 필요** — 운영 데이터 직접 수정이므로 architect 가 임의 결정하지 않음 |

**배포가 필요한 작업 (사용자 손이 필요)**
1. `firebase deploy --only firestore:rules,firestore:indexes` — Rules + 인덱스
2. `firebase deploy --only functions:onReviewWritten` — **신규 CF** (owner_sales 와 달리 이번엔 필요)
3. Firebase Console 에서 시드 매장 2문서의 `averageScore`→`0`, `reviewCount`→`0` 수동 수정 (A5)

---

## 13. 완료 기준

- [ ] `reviews` Rules 교체 + RV1~RV20 전건 PASS (특히 RV16/RV17)
- [ ] `onReviewWritten` CF 배포 + CF1~CF9 전건 PASS
- [ ] I1 인덱스 배포 (I2 는 필요 여부 확정 후)
- [ ] `flutter analyze` 0 issue / `flutter test` 전건 PASS (U1~U5 포함)
- [ ] M1~M9 수동 검증 PASS, **실결제 0회**
- [ ] 시드 정정 + 운영 2문서 리셋 완료
- [ ] `backlog.md` / `data_ownership.md` / `role_flows.md` 갱신 (§10 X1·X3·X4·X5)
- [ ] 리뷰 1건 작성 → 수초 내 `GradeBadge` 등급 변동이 눈으로 확인됨 (= 이 task 의 목적)
