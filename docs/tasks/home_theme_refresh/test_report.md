# 홈 화면 테마 리프레시 테스트 리포트

## 테스트 일시
- 2026-04-21

## 테스트 방법
- 정적 코드 검증 (spec.md / design.md / implementation.md 교차 대조)
- `flutter analyze` 실행
- 홈 스코프 하드코딩 색상 grep
- 팔레트 스왑 호환성 정적 확인 (두 팔레트 토큰셋 일치 여부)

## 전체 결과
- PASS: 22개
- FAIL: 4개
- 보류: 4개

---

## 상세 결과

### PASS 항목

**기능 / 구조**
- [x] Scaffold 배경이 `AppColors.background` (흰색) — [scaffold_with_nav.dart:35](lib/presentation/common/scaffold_with_nav.dart#L35)
- [x] 헤더 배경 `primary → primaryDeep` 그라디언트 — [home_header.dart:31-33](lib/presentation/customer/home/widgets/home_header.dart#L31-L33)
- [x] 헤더 좌하단 라운드 28 — [home_header.dart:34-36](lib/presentation/customer/home/widgets/home_header.dart#L34-L36)
- [x] 헤더 내부 로고/텍스트 `onPrimary` — [home_header.dart:46,54,66,74](lib/presentation/customer/home/widgets/home_header.dart#L46)
- [x] 환영 메시지 "`[이름]님 어서오세요.`" — [home_header.dart:77](lib/presentation/customer/home/widgets/home_header.dart#L77)

**카드 / 배지**
- [x] NearbyStoreCard: `surfaceElevated` + `border` 1px + 연한 shadow + radius 16 — [store_card.dart:10-21](lib/presentation/customer/home/widgets/store_card.dart#L10-L21)
- [x] RecommendedStoreCard 동일 `_cardDecoration()` 공유 — [store_card.dart:9-22,129](lib/presentation/customer/home/widgets/store_card.dart#L9-L22)
- [x] GradeBadge 미드나잇 단일 pill (`primary` + `onPrimary`, radius 999) — [grade_badge.dart:23-28](lib/presentation/customer/home/widgets/grade_badge.dart#L23-L28)
- [x] 배지 이미지 우상단/좌상단 Positioned — [store_card.dart:56-63,145-153](lib/presentation/customer/home/widgets/store_card.dart#L56-L63)
- [x] 매장명 `textHeading`, 거리 `textMuted`/`textBody` — 신규 의미 토큰 사용

**칩 / 섹션**
- [x] 선택 칩: `primary` + `onPrimary`, border 없음, pill 999 — [category_filter_section.dart:60-66](lib/presentation/customer/home/widgets/category_filter_section.dart#L60-L66)
- [x] 비선택 칩: `surfaceElevated` + `border` 1px + `textBody` — 동일 파일
- [x] SectionTitle 18sp w700 `textHeading` — [section_title.dart:16-22](lib/presentation/customer/home/widgets/section_title.dart#L16-L22)

**네비 / FAB**
- [x] BottomNav 배경 `surfaceElevated` + 상단 `border` — [bottom_nav.dart:24-29](lib/presentation/common/bottom_nav/bottom_nav.dart#L24-L29)
- [x] 활성 아이콘 `primary`, 비활성 `textMuted` — [bottom_nav.dart:90](lib/presentation/common/bottom_nav/bottom_nav.dart#L90)
- [x] Qoin 탭 QLogo 색상 주입 (활성 `primary` / 비활성 `textMuted`) — [bottom_nav.dart:45-53](lib/presentation/common/bottom_nav/bottom_nav.dart#L45-L53)
- [x] OrderFab 미드나잇 그라디언트 (`primary → primaryLight`) + 아이콘 `onPrimary` — [order_fab.dart:40,51](lib/presentation/common/bottom_nav/order_fab.dart#L40)

**상태 UI**
- [x] Shimmer 베이스/하이라이트 `surface` ↔ `surfaceElevated` (팔레트 스왑 대응) — [nearby_stores_section.dart:66-67](lib/presentation/customer/home/widgets/nearby_stores_section.dart#L66), [recommended_stores_section.dart:84-85](lib/presentation/customer/home/widgets/recommended_stores_section.dart#L84)
- [x] 빈 상태 아이콘 `textMuted` + 본문 `textBody` — [nearby_stores_section.dart:119-128](lib/presentation/customer/home/widgets/nearby_stores_section.dart#L119-L128)

**팔레트 / 품질**
- [x] `AppColors.*` 외 하드코딩 색상 없음 (홈 스코프 grep 클린) — `lib/presentation/customer/home/widgets/pre_permission_dialog.dart` 제외
- [x] `LightMidnightAccentPalette`와 `DarkMidnightPalette` 필드 셋 완전 일치 → typedef 한 줄 교체로 스왑 가능 — [color_palette.dart:25-94](lib/core/theme/color_palette.dart#L25-L94)
- [x] `ThemeData`에 `brightness`, `scaffoldBackgroundColor`, `ColorScheme.fromSeed` 토큰 주입 — [main.dart:28-37](lib/main.dart#L28-L37)
- [x] `flutter analyze` → **No issues found**
- [x] `designer_guide.md` 색상 테이블·컴포넌트 원칙 라이트 테마 기준으로 갱신 — [designer_guide.md](docs/agents/designer_guide.md)

---

### FAIL 항목

- [ ] **"전체보기" 링크 색상 불일치**
  - 문제: design.md §5는 `AppColors.info`(스카이 블루), spec §맞춤 추천은 `info` 또는 `primaryBright`를 지정. 구현은 `AppColors.primary`(미드나잇 단색)로 바뀌어 주변 배지/칩과 시각적으로 구분되지 않음
  - 위치: [recommended_stores_section.dart:32-38](lib/presentation/customer/home/widgets/recommended_stores_section.dart#L32-L38)
  - 재현: `전체보기` Text의 `color` 필드 확인
  - 제안: `AppColors.primary` → `AppColors.info`로 변경. 링크는 밑줄 없이 색상으로만 구분하므로 `info`가 더 인지 가능
  - 우선순위: **중**

- [ ] **에러 상태에 재시도 버튼 없음**
  - 문제: spec §상태 UI가 "에러: 연한 배경 카드 + 미드나잇 재시도 버튼", design.md §에러는 `ElevatedButton bg=primary, 라벨 "다시 시도"`를 명시했으나 구현은 아이콘+문구만 존재 → 사용자가 재시도 불가
  - 위치: [nearby_stores_section.dart:81-108](lib/presentation/customer/home/widgets/nearby_stores_section.dart#L81-L108), [recommended_stores_section.dart:100-135](lib/presentation/customer/home/widgets/recommended_stores_section.dart#L100-L135)
  - 재현: 두 섹션 `_XxxError` 위젯에 버튼 없음
  - 제안: `ElevatedButton`(`primary` bg / `onPrimary` fg / radius 12) 추가 후 onPressed에서 `ref.invalidate(nearbyStoresProvider)` / `ref.invalidate(filteredStoresProvider)` 호출
  - 우선순위: **중** (기능적 영향 있음)

- [ ] **OrderFab 펄스 애니메이션 미구현**
  - 문제: design.md §7이 "2초 주기 글로우 펄스"를 명시(`spreadRadius 0 → 6 → 0, blurRadius: 12, alpha 0 → 0.5 → 0`)했으나 구현은 정적 그림자만 존재
  - 위치: [order_fab.dart:32-57](lib/presentation/common/bottom_nav/order_fab.dart#L32-L57)
  - 재현: `AnimationController`/`AnimatedBuilder`가 없음 (tap scale은 구현됨)
  - 제안: 2000ms `repeat` AnimationController → `AnimatedBuilder`로 2번째 `BoxShadow` 값 보간. 또는 spec 수준에서는 "글로우 유지" 정도만 요구하므로 이 항목을 spec 외 스트레치로 재정의해도 무방
  - 우선순위: **하** (시각 디테일)

- [ ] **BottomNav 상단 shadow 누락**
  - 문제: design.md §6이 `BoxShadow(primary alpha 0.06, blurRadius 12, offset (0,-2))`를 권장했으나 구현은 border만 존재
  - 위치: [bottom_nav.dart:23-29](lib/presentation/common/bottom_nav/bottom_nav.dart#L23-L29)
  - 재현: `BoxDecoration`에 `boxShadow` 필드 없음
  - 제안: `BoxDecoration`에 `boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: Offset(0, -2))]` 추가
  - 우선순위: **하**

---

### 보류 항목

- [ ] **`pre_permission_dialog.dart` 내 하드코딩 `Colors.white`, 구버전 그라디언트**
  - 이유: 이 파일은 spec §변경 대상에 포함되지 않음. home 위젯이지만 one-shot 다이얼로그라 다음 task에서 일괄 정리 권고
  - 위치: [pre_permission_dialog.dart:40,44,51,101,102](lib/presentation/customer/home/widgets/pre_permission_dialog.dart#L40)
  - 참고: `primaryBright → primaryDeep` 그라디언트, `Colors.white` 아이콘, `backgroundColor: AppColors.primaryBright` CTA가 새 라이트 컨셉과 어긋남

- [ ] **OrderFab 크기(64) vs design.md 권고(56)**
  - 이유: 수치 차이. 크기 차는 시각적 디테일로 기능 문제 없음. 디자이너 확인 후 결정

- [ ] **홈에 별점 UI 없음**
  - 이유: spec §주변매장에 "별점: accent" 항목이 있으나 design.md §Figma 대비 변경사항은 "현재 화면에는 별점 미노출, 추후 메뉴에서 사용"으로 명시. 현재 코드에도 별점 컴포넌트 없음 → spec 오탈자 성격

- [ ] **`StoreGradeColor` extension dead code화**
  - 이유: GradeBadge 단일 색 통일로 `extension StoreGradeColor on StoreGrade`가 미사용 dead code. spec 외 항목이지만 후속 정리 권고
  - 위치: [store_grade.dart:72-86](lib/domain/entities/store_grade.dart#L72-L86)

---

## 설계자 전달 메시지

### 요약
**홈 테마 리프레시의 큰 그림(흰 캔버스 + 미드나잇 포인트, 카드/배지/칩/헤더 토큰화, 팔레트 스왑 구조)은 모두 PASS**. `flutter analyze`도 클린. 다만 **기능적 의미가 있는 FAIL 2건**과 **시각적 디테일 FAIL 2건**이 남아있음.

### 재작업 우선순위

1. **에러 상태 재시도 버튼** (developer, 중요) — 사용자 플로우에 영향. spec/design 둘 다 명시하므로 필수 수정.
2. **전체보기 링크 색상 `info`로 복원** (developer, 중) — design.md와 직접 충돌. 미드나잇 톤 통일 의도인지 확인 후 결정.
3. **FAB 펄스 / BottomNav shadow** (developer, 낮음) — 시각 디테일. 이번 리프레시 범위에 포함할지 또는 후속 tiny-polish task로 분리할지 판단 필요.
4. **pre_permission_dialog** (후속 task) — 다이얼로그/모달 리프레시를 별도 spec으로 묶어 점진 진행 권고.

### 판단 요청
- FAIL 1, 2는 developer 재호출로 즉시 수정 가능 (작업량 소형).
- FAIL 3, 4는 spec 범위 재정의 여부 문제 — 설계자 판단.
- 보류 항목은 모두 후속 task 후보.
