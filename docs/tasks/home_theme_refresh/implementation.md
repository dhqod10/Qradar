# 홈 화면 테마 리프레시 구현 보고서

## 개요

`docs/tasks/home_theme_refresh/spec.md`와 `design.md`에 명시된대로 홈 화면을 **흰색 캔버스 + 미드나잇 네이비 포인트** 컨셉으로 전환했다. 동시에 컨셉 색상이 주기적으로 교체될 수 있도록 **팔레트 스왑 구조**를 함께 도입했다.

## 팔레트 스왑 구조

- `lib/core/theme/color_palette.dart` (신규): `abstract final class` + `static const` 멤버로 팔레트를 정의. 현재는 `LightMidnightAccentPalette`(라이트 기본)와 `DarkMidnightPalette`(기존 다크 보존) 2종.
- `lib/core/theme/app_colors.dart`: `typedef _P = LightMidnightAccentPalette;` 한 줄로 현재 사용 중인 팔레트를 가리키고, `AppColors`의 정적 상수들이 `_P.xxx`를 그대로 노출한다. 팔레트 교체는 typedef 라인만 바꾸면 되며, 모든 것이 `const`로 유지된다.
- 기존 토큰 이름 유지(`textDark` / `textDefault`)은 새 이름(`textHeading` / `textBody`)의 레거시 alias로 공존한다. 점진적 전환 후 제거 예정.

## 토큰 체계 (현재 라이트 팔레트 기준)

| 카테고리 | 토큰 | 값 |
|---------|------|----|
| Point | primary / primaryLight / primaryBright / primaryDeep | #0F172A / #334155 / #38BDF8 / #020617 |
| On-point | onPrimary | #FFFFFF |
| Accent | accent | #FFD700 |
| Surface | background / surface / surfaceElevated / border | #FFFFFF / #F3F4F6 / #FFFFFF / #E5E7EB |
| Text | textHeading / textBody / textMuted | #0F172A / #1F2937 / #6B7280 |
| Semantic | success / error / warning / info | #16A34A / #DC2626 / #F59E0B / #0EA5E9 |
| Meta | brightness = Brightness.light, backgroundGradient |  |

## 수정 파일 목록

### 코어
- `lib/core/theme/color_palette.dart` — **신규**. 팔레트 2종.
- `lib/core/theme/app_colors.dart` — typedef 기반 delegate로 재작성.
- `lib/main.dart` — `ThemeData`에 `brightness`, `scaffoldBackgroundColor`, `ColorScheme.fromSeed` 토큰 주입.

### 홈 화면 위젯
- `lib/presentation/common/q_logo.dart` — `QLogo`에 `color` 파라미터 추가, `_QLogoPainter`가 주입 색을 사용.
- `lib/presentation/customer/home/widgets/home_header.dart` — 미드나잇 블록. 배경 `primary → primaryDeep` 그라디언트, 라운드 `bottomLeft: 28`, 로고·텍스트 `onPrimary`.
- `lib/presentation/customer/home/widgets/section_title.dart` — `textDark` → `textHeading`.
- `lib/presentation/customer/home/widgets/grade_badge.dart` — 등급별 색 구분 제거, `primary` pill + `onPrimary` 텍스트로 통일.
- `lib/presentation/customer/home/widgets/store_card.dart` — `_cardDecoration()` 공통 추출. `surfaceElevated` 배경 + `border` 1px + 연한 primary 그림자 + 라운드 16.
- `lib/presentation/customer/home/widgets/category_filter_section.dart` — 선택 칩 `primary`+`onPrimary`, 비선택 `surfaceElevated`+`border`+`textBody`. 라운드 999(pill). 글로우 그림자 제거.
- `lib/presentation/customer/home/widgets/nearby_stores_section.dart` — 상태 텍스트 `textDefault` → `textBody`.
- `lib/presentation/customer/home/widgets/recommended_stores_section.dart` — 전체보기 링크 `primaryBright` → `primary`. 에러 타이틀 `textDark` → `textHeading`. 빈 상태 텍스트 `textDefault` → `textBody`.
- `lib/presentation/customer/home/home_page.dart` — RefreshIndicator `primary` / `surfaceElevated`.

### 공통 네비게이션
- `lib/presentation/common/bottom_nav/bottom_nav.dart` — 컨테이너 배경 `surfaceElevated`, 상단 border `AppColors.border`. 활성 아이콘/라벨 `primary` / `textHeading`. Qoin `QLogo`에 활성 여부별 색상 주입.
- `lib/presentation/common/bottom_nav/order_fab.dart` — 그라디언트 `primary → primaryLight`, 아이콘 `onPrimary`, 그림자 `primary` alpha 0.25.

### 문서
- `docs/agents/designer_guide.md` — 색상 테이블을 신규 토큰 체계로 교체. 컴포넌트 원칙을 라이트 테마 기준으로 갱신.

## 기타 결정 및 주의사항

1. **ShaderMask 제거**: 기존 헤더의 radar 텍스트 ShaderMask는 네이비 배경 위에서 대비가 약해 제거. 대신 `onPrimary` 단색으로 가독성 확보.
2. **배지 단일화**: 등급별 색 구분을 제거하고 텍스트(`S급/A급...`)만 유지. 미드나잇 pill로 통일되며, home.png 스펙과 일치.
3. **카드 그림자 경량화**: 기존 진한 다크 그림자 대신 `primary` alpha 0.04의 매우 옅은 그림자. 라이트 배경에서 카드 경계는 border가 주로 담당.
4. **레거시 토큰**: `textDark`, `textDefault`는 새 토큰(`textHeading`, `textBody`)의 alias로 남겨 기존 화면(결제/주문 등) 파괴 없이 점진 전환.
5. **kakao / naver 브랜드 색**: 팔레트와 무관한 고정 색이라 `AppColors`에 리터럴로 직접 유지.
6. **다크 팔레트 보존**: `DarkMidnightPalette`는 사용되지 않지만 `// ignore: unused_element` 없이 참조 가능한 상태로 남아 있음(추후 주/야 토글에 대비).

## 검증

- `flutter analyze` — **No issues found**.
- 빌드 실행은 테스터 단계에서 실제 홈 화면 렌더 스크린샷으로 확인 예정.

## 테스터에게 전달할 포인트

1. 홈 화면 전체가 흰색 캔버스인지, 미드나잇 블록은 상단 헤더에만 한정되는지.
2. 주변매장/맞춤 추천 카드의 배경이 흰색 + 옅은 border + 부드러운 그림자인지.
3. 등급 배지가 모든 카드에서 동일한 네이비 pill + 흰 텍스트인지.
4. 카테고리 칩 선택/비선택 색 전환이 즉각적이고, 선택 상태는 미드나잇 채움인지.
5. 하단 네비게이션이 흰색 바탕 위에 아이콘만 색이 바뀌는지, Qoin 위치의 QLogo 색이 활성 탭에 따라 변하는지.
6. OrderFab이 미드나잇 그라디언트 원형으로 떠 있는지, 탭 시 scale 피드백이 정상인지.
7. Pull-to-refresh 인디케이터가 흰색 배경 위 미드나잇 스피너인지.
8. 로그인 → 홈 진입, 위치 폴백 스낵바 등 기존 플로우 회귀 없음.
