# grade_min_reviews 디자인 명세

- 작성: 2026-10-29 / designer
- 근거: `spec.md` (N=3, 미평가=중립 '신규', 등급필터 제외·전체 노출, 미평가 후순위)
- 본질: **새 컴포넌트 없음.** 기존 `GradeBadge._unrated` 분기를 재사용하고 라벨·분기 임계값만 바꾼다. 마커 중립색 1개 추가.

---

## 1. '신규' 중립 배지 (GradeBadge `_unrated`)

현행 `_unrated()` 의 색·크기 보정을 **그대로 유지**하고 라벨만 `미평가` → `신규` 로 교체한다. (reviewCount==0 선례와 같은 톤. 등급 pill 은 미드나잇 채움, 신규 pill 은 연회색 채움+테두리 → 등급이 아님이 즉시 구분됨.)

| 항목 | 값 |
|---|---|
| 라벨 | `신규` (확정) |
| 배경 | `AppColors.surface` |
| 테두리 | 1px `AppColors.border` |
| 텍스트 색 | `AppColors.textBody` |
| 폰트 | 11 / `FontWeight.w700` (rated 등급 라벨 11 bold 와 동일) |
| 패딩 | 가로 9 / 세로 3.5 (border 1px 보정 → rated 의 10/4 와 총 크기 동일, 변경 금지) |
| 모서리 | `BorderRadius.circular(999)` |
| chevron | `showChevron` 시 기존과 동일(14px, `AppColors.textBody`) — 매장 메뉴 헤더만 |

- 분기: `!GradeCalculator.isGraded(reviewCount)` (spec §레이어 3-1). 등급 enum 값(`grade`)은 미평가에서 무시.
- 접근성(Semantics): `'신규 매장, 평가 $reviewCount개'` (0건이면 `'아직 평가가 없는 신규 매장'`). 등급 미부여 이유는 음성으로 전달하지 않는다(과함).
- 클래스 doc 주석의 "평가가 0건이면 … 미평가" 문구를 "평가가 N(3)건 미만이면 중립 `신규`" 로 갱신.
- 다크 모드: 토큰 기반이라 별도 작업 없음.

## 2. 리뷰 개수 노출 결정 (권고)

**미평가 배지에는 개수를 넣지 않는다 (`신규` 만).**
- 등급 배지의 `(N)` 은 "이 등급의 근거 표본 수" 신호다. 미평가에 `신규 (2)` 를 쓰면 pill 폭이 가변이 되고 "2건이면 등급이 곧 나온다" 같은 추가 의미가 생겨 과하다.
- 별도 보조텍스트(헤더 "N건" 등)도 **추가하지 않는다**. 필요하면 후속 개선.
- 효과: 미평가 pill 은 항상 고정 폭 → 카드 레이아웃 흔들림 없음.

## 3. 소비 화면별 처리

모두 GradeBadge 를 거치며 `grade`+`reviewCount` 를 이미 전달하므로 **배지 1곳 수정으로 cascade. 화면별 재디자인 없음, 현행 유지.**

| 화면/위젯 | 처리 |
|---|---|
| store_card (×2) | 현행 유지 |
| frequent_stores_section | 현행 유지 |
| recommended_stores_section / page | 현행 유지 (후순위 정렬은 로직, spec §4) |
| store_menu_header | 현행 유지 (chevron 포함 `신규` pill) |
| store_map_marker_sheet | 현행 유지 (시트 내 배지 자동 `신규`) |
| 점주 my_store_page | 현행 유지 (자기 매장도 동일 표기 — 점주가 "왜 등급이 없나" 를 알 수 있게 별도 안내 문구는 추가하지 않음) |
| 등급 필터 칩 | 변경 없음 (미평가 전용 칩 없음) |

## 4. 지도 마커 중립색

`MapConfig` 에 미평가 분기 추가. 현행 C 등급 마커가 이미 `AppColors.textMuted` 를 쓰므로 **textMuted 재사용 불가**(C 와 혼동).

| 상태 | 마커 색 토큰 |
|---|---|
| S | `AppColors.accent` (기존) |
| A | `AppColors.primaryBright` (기존) |
| B | `AppColors.primary` (기존) |
| C | `AppColors.textMuted` (기존) |
| **미평가(신규)** | **`AppColors.border`** (신규 사용) |

- 근거: 배지 `신규`(surface+border) 와 같은 연회색 계열, 등급 4색 어디와도 겹치지 않으며 "등급 없음" 의 약한 위계가 의도와 맞다.
- 구현: `MapConfig` 에 `static String get unratedMarkerColorHex => _toHex(AppColors.border);` 추가 후, `store_map_tab._syncToMap` 에서 `'color': s.isGraded ? markerColorHexForGrade(s.grade) : MapConfig.unratedMarkerColorHex`. (`markerColorHexForGrade` 시그니처는 StoreGrade 전용이므로 유지.)
- `grade` 필드(`s.grade.asString`)를 JS 가 라벨/분기에 쓰는지 개발자가 확인. 쓰면 미평가는 등급 문자열을 보내지 않거나 `unrated` 로 구분.
- 가시성 주의: gray-200 은 밝은 지도 타일 위에서 옅다. JS 마커에 외곽선(stroke)/그림자가 이미 있으면 그대로 사용. **없고 실기기에서 식별이 어려우면** 대안으로 `AppColors.textMuted` 마커를 쓰되 C 와 구분되도록 JS 측 불투명도/외곽선 차별을 개발자가 판단(사용자 확인 필요 아님, 실기기 확인 항목).

## 5. 상태 UI

신규는 empty 가 아니라 **정상 표시의 변형**. loading/error/empty 는 기존 provider 흐름 그대로. 특이사항: 등급 필터로 미평가가 모두 걸러져 목록이 비면 기존 empty UI 재사용.

## 6. 개발자 전달 사항

1. 배지 분기 지점: `grade_badge.dart` `build()` 의 `reviewCount == 0` → `!GradeCalculator.isGraded(reviewCount)`. `_unrated()` 라벨 `'신규'`, Semantics 문구 갱신. 색·패딩·폰트는 **수정 금지**.
2. 마커 중립색 토큰: `AppColors.border` (`MapConfig.unratedMarkerColorHex`). 색 하드코딩 금지.
3. 리뷰수: 미평가 배지에 개수 표기 없음.
4. 호출부 8곳 수정 불필요.

## 7. 사용자 확인 필요

- 없음(라벨 '신규' 확정). 마커 가시성만 실기기 확인 권장(§4).
