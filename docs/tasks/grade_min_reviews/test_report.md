# grade_min_reviews 테스트 리포트

기준: spec/design/implementation. 확정값 N=3, 미평가='신규', 등급필터 제외, 미평가 후순위.

## 결과 요약
PASS 12 / FAIL 0 / 보류 3

## PASS
1. GradeThresholds.minReviewsForGrade=3, GradeCalculator.isGraded(reviewCount>=min) 확인.
2. StoreEntity.isGraded 는 파생 getter, `const StoreEntity._()` 추가, freezed 재생성 정합(`extends StoreEntity` + `super._()`). 저장 필드 아님.
3. GradeBadge: 분기 `!isGraded(reviewCount)`, 라벨 '신규', `_unrated()` 스타일 무변경(라벨 텍스트만 변경), 호출부 변경 없음. 경계 2->신규 / 3->등급 pill 은 로직상 확인.
4. 필터(orderStoresProvider): 등급 칩 4개 미만이면 미평가 제외, 4개 전부면 노출. 리스트/지도 공유 provider.
5. 정렬(sortRecommended): 등급순만 isGraded 1차 키, 거리순 불변(early return).
6. 지도: MapConfig.unratedMarkerColorHex 는 AppColors.border 에서 _toHex 로 유도(hex 하드코딩 없음). store_map_tab 미평가에 중립색 + grade ''. kakao_map.html 무수정; 빈 라벨 생성 및 변경감지(color/grade 비교) 정상 동작(코드 확인).
7. 레이어: presentation Firebase import 없음, Color(0x..) 추가 없음.
8. Rules/CF/스키마/assets 무변경 (git status 확인).
9. 범위: lib 변경 9파일(+35/-11), spec 지점 + freezed 재생성만. 재포맷 노이즈 없음.
10. flutter analyze: No issues found.
11. flutter test: 전체 통과 (All tests passed, 921 건 수준).
12. 접근성 Semantics 라벨이 0건/그 외 구분되어 갱신됨.

## FAIL
없음.

## 보류 (실기기, 나중 배치 실테스트)
- B1. 지도 마커 AppColors.border 중립색 가시성 (지도 배경 대비) — 실기기 확인 필요. 특히 우선 확인.
- B2. 신규 pill 크기가 기존 미평가 pill 과 동일한지(배지 크기 일치), 라벨 길이 변화 영향.
- B3. 경계 동작(리뷰 2->3) 및 등급 칩 필터/등급순 정렬 실화면 확인.

## 후속 후보 (FAIL 아님)
- isGraded 경계(2/3), 필터(narrowed), sortRecommended 후순위에 대한 단위 테스트가 추가되지 않았다(test/ 내 isGraded/minReviewsForGrade 참조 없음). 추가 권장.
- GradeCalculator.fromReviews 는 소비처 없음(주석 명시) — 정리 후보.

## 우선 수정
없음 (FAIL 0).
