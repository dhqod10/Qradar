# grade_min_reviews 구현 결과

- 기준: spec.md / design.md (N=3, 미평가='신규' 중립 배지, 필터 좁힘 시 제외·전체 노출, 미평가 후순위)
- Firestore Rules / CF / 스키마 무변경 (reviewCount 는 onReviewWritten 이 이미 집계)

## 수정 지점
| 파일 | 내용 |
|---|---|
| `lib/core/constants/grade_thresholds.dart` | `minReviewsForGrade = 3` |
| `lib/core/utils/grade_calculator.dart` | `isGraded(int)` 추가, `fromReviews` 주석만(소비처 0건, 동작 불변) |
| `lib/domain/entities/store_entity.dart` (+ `.freezed.dart` 재생성) | `const StoreEntity._()` + 파생 getter `isGraded` (저장 필드 아님) |
| `lib/presentation/customer/home/widgets/grade_badge.dart` | 분기 `!GradeCalculator.isGraded(reviewCount)`, 라벨 '신규', Semantics '신규 매장, 평가 N개'(0건: '아직 평가가 없는 신규 매장'). `_unrated()` 색/패딩/폰트 불변. 호출부 8곳 무수정 |
| `lib/presentation/customer/order/providers/order_providers.dart` | 등급 칩이 4개 미만(좁힘)이면 `!isGraded` 제외; 4개 전부면 미평가도 노출. 거리순 정렬 불변 |
| `lib/presentation/customer/home/providers/recommended_stores_providers.dart` | `sortRecommended` 등급순에만 `isGraded` 1차 키(미평가 후순위). 거리순 불변 |
| `lib/core/config/map_config.dart` | `unratedMarkerColorHex` (= `AppColors.border` 유도, 하드코딩 없음) |
| `lib/presentation/customer/order/tabs/store_map_tab.dart` | 미평가는 `color`=중립색, `grade`=`''` |

## 지도 JS 점검 (`assets/map/kakao_map.html`)
- JS 는 `store.grade` 를 핀 안 **라벨 텍스트**(`<div class="label">`)와 `data-grade`(S 만 어두운 글자색 CSS)로 사용. 그대로 두면 미평가 매장에 'C' 등 가짜 등급이 표시되므로, 미평가는 `grade: ''` 를 보내 라벨을 빈 값으로 처리. **JS 수정 없음** (변경 감지 `existing.grade !== s.grade` 도 빈 문자열로 정상 동작).
- 마커: 흰색 stroke(2px) + drop-shadow 존재. 연회색(border) 핀은 밝은 타일에서 옅을 수 있으나 shadow 로 윤곽 확보. **실기기 가시성 확인 권장** (식별 어려우면 textMuted 대안 + 불투명도 차별, design.md §4).

## 검증
- `dart run build_runner build`: 정상 (store_entity.freezed.dart 재생성)
- `flutter analyze`: No issues found
- `flutter test`: 결과는 보고 메시지 참조
- `dart format` 파일 전체 실행 없음 (diff 는 구현분만)

## 테스트 포인트
1. reviewCount 0/1/2 → '신규' pill, 3 → 등급 pill(+개수). 경계 2↔3.
2. 신규 pill 크기가 등급 pill 과 동일 높이(레이아웃 흔들림 없음), store_menu_header chevron 표시.
3. 주문 탭 등급 칩 전체 선택: 미평가 매장 노출. S만 등 좁힘: 미평가 제외(예전 파생 C 로 잘못 매칭되던 것 해소). 좁힘으로 비면 기존 empty UI.
4. 리스트/지도 동일 결과 (같은 provider).
5. 추천 전체보기 등급순: 미평가가 맨 뒤, 거리순은 불변.
6. 지도: 미평가 핀 중립색 + 라벨 빈 값, 등급 핀 기존 색/라벨, 선택 시 확대 정상, 가시성(실기기).
7. 점주 my_store_page 자기 매장 '신규' 표기. Semantics 문구.
