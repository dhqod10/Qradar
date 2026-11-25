-- Qradar — 성별·연령대 집계 쿼리 모음
--
-- 전제: BigQuery Extension "Stream Firestore to BigQuery" 로 `orders` 컬렉션을 내보낸 상태.
-- 아래의 `PROJECT.DATASET` 는 설치할 때 정한 실제 이름으로 바꿔 쓴다.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- 이 파일이 미리 피해 두는 세 가지 함정
--
-- 1. **changelog 를 직접 세지 않는다.** 주문은 paid → accepted → making → ready →
--    completed 로 갈 때마다 `orders_raw_changelog` 에 행이 하나씩 더 쌓인다. 거기에
--    바로 SUM 하면 한 주문이 다섯 번 세어진다. 반드시 `orders_raw_latest` 를 본다.
--
-- 2. **연령대를 문자로 정렬하지 않는다.** 저장값이 teens/twenties/thirties… 라서
--    알파벳순은 50대→40대→60대→10대→30대→20대 가 된다. 아래 `age_sort` 로 순번을 붙인다.
--
-- 3. **안 밝힌 주문(null)을 숨기지 않는다.** 성별·출생연도는 선택 항목이라 null 이 섞인다.
--    비율을 낼 때 분모가 "전체"인지 "밝힌 주문"인지에 따라 숫자가 달라지므로,
--    쿼리 3 으로 밝힌 비율을 먼저 확인하고 해석한다.
--
-- 금액 필드: `totalPrice` 가 실제 결제액(소계 − Qoin 할인), `subtotal` 이 할인 전 금액.
-- 환불은 전액 환불만 있다 (processRefund 가 totalPrice 를 그대로 환불한다).
-- ─────────────────────────────────────────────────────────────────────────────


-- 공통 뷰: 주문 1건 = 1행. 아래 쿼리들이 이걸 재사용한다.
-- 한 번 만들어 두면(CREATE VIEW) 매번 붙여 넣지 않아도 된다.
CREATE OR REPLACE VIEW `PROJECT.DATASET.orders_flat` AS
SELECT
  document_id                                          AS order_id,
  JSON_VALUE(data, '$.storeId')                        AS store_id,
  JSON_VALUE(data, '$.storeName')                      AS store_name,
  JSON_VALUE(data, '$.status')                         AS status,
  JSON_VALUE(data, '$.buyerGender')                    AS gender,
  JSON_VALUE(data, '$.buyerAgeRange')                  AS age_range,
  CAST(JSON_VALUE(data, '$.totalPrice') AS INT64)      AS total_price,
  CAST(JSON_VALUE(data, '$.subtotal')   AS INT64)      AS subtotal,
  TIMESTAMP(JSON_VALUE(data, '$.createdAt'))           AS created_at,
  -- 10대 → 60대 이상 순으로 정렬하기 위한 순번. 안 밝힌 주문은 맨 뒤.
  CASE JSON_VALUE(data, '$.buyerAgeRange')
    WHEN 'teens'       THEN 1
    WHEN 'twenties'    THEN 2
    WHEN 'thirties'    THEN 3
    WHEN 'forties'     THEN 4
    WHEN 'fifties'     THEN 5
    WHEN 'sixtiesPlus' THEN 6
    ELSE 99
  END                                                  AS age_sort,
  CASE JSON_VALUE(data, '$.buyerAgeRange')
    WHEN 'teens'       THEN '10대'
    WHEN 'twenties'    THEN '20대'
    WHEN 'thirties'    THEN '30대'
    WHEN 'forties'     THEN '40대'
    WHEN 'fifties'     THEN '50대'
    WHEN 'sixtiesPlus' THEN '60대 이상'
    ELSE '안 밝힘'
  END                                                  AS age_label,
  CASE JSON_VALUE(data, '$.buyerGender')
    WHEN 'male'   THEN '남성'
    WHEN 'female' THEN '여성'
    ELSE '안 밝힘'
  END                                                  AS gender_label
FROM `PROJECT.DATASET.orders_raw_latest`
WHERE operation != 'DELETE';   -- 삭제된 문서는 latest 에도 남는다


-- ─────────────────────────────────────────────────────────────────────────────
-- 쿼리 1. 연령대 × 성별 매출 (실제로 팔린 것만)
--
-- completed = 고객이 픽업까지 마친 주문. 취소·환불은 여기 들어오지 않는다.
-- 진행 중(paid/accepted/making/ready)도 뺀다 — 아직 끝나지 않아 뒤집힐 수 있다.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  age_label,
  gender_label,
  COUNT(*)                     AS order_count,
  SUM(total_price)             AS revenue,
  ROUND(AVG(total_price))      AS avg_order_value
FROM `PROJECT.DATASET.orders_flat`
WHERE status = 'completed'
  AND created_at >= TIMESTAMP('2026-01-01')
GROUP BY age_label, gender_label, age_sort
ORDER BY age_sort, gender_label;


-- ─────────────────────────────────────────────────────────────────────────────
-- 쿼리 2. 취소·환불 — 매출과 섞지 않고 따로 본다
--
-- cancelled : 결제 직후 고객 취소 또는 점주 거절 (조리 전)
-- refunded  : 접수 이후 점주가 환불 승인 (전액)
--
-- 두 건은 성격이 달라 한 줄로 합치면 원인을 못 읽는다. 연령대별 취소율이
-- 유독 높은 구간이 있으면 그 구간의 주문 경험에 문제가 있다는 신호다.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  age_label,
  COUNTIF(status = 'completed')                      AS completed_count,
  COUNTIF(status = 'cancelled')                      AS cancelled_count,
  COUNTIF(status = 'refunded')                       AS refunded_count,
  SUM(IF(status = 'cancelled', total_price, 0))      AS cancelled_amount,
  SUM(IF(status = 'refunded',  total_price, 0))      AS refunded_amount,
  -- 종료된 주문(완료+취소+환불) 중 돈이 되돌아간 비율
  SAFE_DIVIDE(
    COUNTIF(status IN ('cancelled', 'refunded')),
    COUNTIF(status IN ('completed', 'cancelled', 'refunded'))
  )                                                  AS refund_or_cancel_rate
FROM `PROJECT.DATASET.orders_flat`
WHERE status IN ('completed', 'cancelled', 'refunded')
  AND created_at >= TIMESTAMP('2026-01-01')
GROUP BY age_label, age_sort
ORDER BY age_sort;


-- ─────────────────────────────────────────────────────────────────────────────
-- 쿼리 3. 얼마나 밝혔나 — 쿼리 1·2 를 해석하기 전에 먼저 본다
--
-- 선택 항목이라 null 이 섞인다. 밝힌 비율이 낮으면 쿼리 1 의 구성비는
-- "밝힌 사람들 사이의 구성비"일 뿐 전체 고객의 구성비가 아니다.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  COUNT(*)                                                  AS total_orders,
  COUNTIF(age_range IS NOT NULL)                            AS with_age,
  COUNTIF(gender IS NOT NULL)                               AS with_gender,
  ROUND(SAFE_DIVIDE(COUNTIF(age_range IS NOT NULL), COUNT(*)) * 100, 1)
                                                            AS age_coverage_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(gender IS NOT NULL), COUNT(*)) * 100, 1)
                                                            AS gender_coverage_pct
FROM `PROJECT.DATASET.orders_flat`
WHERE status = 'completed'
  AND created_at >= TIMESTAMP('2026-01-01');


-- ─────────────────────────────────────────────────────────────────────────────
-- 쿼리 4. 매장별 × 연령대 — 어느 매장이 어떤 나이대를 데려오는가
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  store_name,
  age_label,
  COUNT(*)         AS order_count,
  SUM(total_price) AS revenue
FROM `PROJECT.DATASET.orders_flat`
WHERE status = 'completed'
  AND created_at >= TIMESTAMP('2026-01-01')
GROUP BY store_name, age_label, age_sort
ORDER BY store_name, age_sort;
