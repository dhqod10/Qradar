# 홈 화면 테마 리프레시 기능 명세

## 개요
- **목적**: 홈 화면을 기존 **다크 전면 테마** → **밝은 캔버스 + 미드나잇 네이비 포인트** 테마로 전환. 이 작업으로 도출된 디자인 원칙이 이후 전 화면 리프레시의 기준이 된다.
- **영향 범위**:
  - 화면: `HomePage` 및 하위 위젯 전부
  - 공통: `BottomNav`, `OrderFab`, `ScaffoldWithNav`의 홈 컨텍스트 노출 부분
  - 코어: 색상 시스템(이미 팔레트 리팩터 완료)
  - 문서: `docs/agents/designer_guide.md` 색상 표 갱신 (부록 항목)
- **레퍼런스 이미지**: [docs/design/screens/home/home.png](docs/design/screens/home/home.png)
- **비범위**:
  - 다른 화면(로그인/매장상세/주문 등) — 이후 별도 task
  - 주/야 자동 전환 — 팔레트 구조만 존재, 런타임 스위칭은 후속
  - 기능 변경(데이터/필터/내비 동작) — 순수 **색상·시각** 리프레시

---

## 요구사항

### 전역 캔버스
- [ ] Scaffold 배경: **흰색** (`AppColors.background`, 현재 팔레트 기준 `#FFFFFF`)
- [ ] 선택적으로 상단에 `#F8FAFC`까지 떨어지는 **미세 그라디언트** 허용 (`AppColors.backgroundGradient`)

### 헤더 (Qradar 브랜드 영역)
- [ ] 배경: **미드나잇 네이비** 단색 또는 네이비 그라디언트 (`AppColors.primary` 기반)
- [ ] 좌하단 코너 **큰 반경 라운드** (`BorderRadius.only(bottomLeft: Radius.circular(24~32))`)로 흰 캔버스와 시각적 분리
- [ ] 내부 텍스트/로고: **흰색** 계열 (`AppColors.onPrimary`)
- [ ] 환영 메시지: "[이름]님 어서오세요"

### 주변매장 카드 (가로 스크롤)
- [ ] 카드 배경: **흰색** (`AppColors.surfaceElevated`)
- [ ] 카드 테두리: 얇은 보더 (`AppColors.border`, 1px)
- [ ] 카드 그림자: 아주 연한 shadow (elevation 1~2 상당)
- [ ] 카드 모서리: `BorderRadius.circular(16~20)` — 홈.png는 `rounded-2xl` ≈ 16dp
- [ ] 등급 배지: 이미지 우상단, **미드나잇 채움 + 흰 글자 + pill 형태** (`rounded-full`)
- [ ] 매장명: 진한 텍스트(`AppColors.textHeading`) bold, 작은 사이즈
- [ ] 별점: **앰버/골드** (`AppColors.accent`) 아이콘 + 수치
- [ ] 거리: 보조 텍스트(`AppColors.textMuted`)

### 카테고리 칩
- [ ] **선택됨**: 미드나잇 채움(`AppColors.primary`) + 흰 글자(`AppColors.onPrimary`), pill(`rounded-full`)
- [ ] **선택 안됨**: 흰 배경 + 얇은 보더(`AppColors.border`) + 기본 텍스트(`AppColors.textBody`)
- [ ] 호버/탭: 밝기 변화 또는 보더 색상 강화 (미드나잇 계열)

### 맞춤 추천 리스트 (세로)
- [ ] 카드 구조: 좌측 이미지(정사각) + 우측 정보 + 우단 `chevron_right`
- [ ] 동일한 화이트 카드 스타일(주변매장과 통일)
- [ ] 등급 배지: 이미지 좌상단 오버레이
- [ ] "전체보기" 링크: **스카이 블루 텍스트**(`AppColors.info` 또는 `AppColors.primaryBright`), underline 없음

### 섹션 타이틀
- [ ] 크기: 18sp 내외, bold
- [ ] 색상: `AppColors.textHeading`

### 하단 네비게이션
- [ ] 배경: **흰색** (`AppColors.surfaceElevated`) + 상단 얇은 보더
- [ ] 활성 탭: 미드나잇(`AppColors.primary`) + 아이콘/텍스트 미드나잇
- [ ] 비활성 탭: `AppColors.textMuted`
- [ ] 중앙 FAB(주문): **미드나잇 배경 + 흰 아이콘**, 글로우는 유지(미드나잇 투명 그림자)

### 상태 UI
- [ ] 로딩: shimmer 기반 → **`AppColors.surface`(gray-100)** ↔ **`AppColors.border`(gray-200)** 로 색상 업데이트
- [ ] 에러: 연한 배경 카드 + 미드나잇 재시도 버튼
- [ ] 빈 상태: 중립 아이콘 + `AppColors.textMuted` 텍스트

---

## 디자인 원칙 (이 task로 확정되는 전역 규칙)

### 컬러 역할
| 역할 | 토큰 | 사용처 |
|------|------|--------|
| 캔버스 | `background` | Scaffold 기본 |
| 카드/섹션 | `surfaceElevated` | 카드 내부, 모달 |
| 서브 면 | `surface` | 비활성 영역, shimmer base |
| 포인트 (강조 채움) | `primary` | 헤더, 선택 칩, 등급 배지, FAB, 활성 네비 |
| 포인트 위 텍스트 | `onPrimary` | 미드나잇 위 글자 전부 |
| 링크/보조 CTA | `info` (or `primaryBright`) | "전체보기" 등 텍스트 링크 |
| 헤딩 | `textHeading` | 섹션 제목, 매장명 |
| 본문 | `textBody` | 일반 텍스트 |
| 보조 | `textMuted` | 거리, 캡션, 비활성 |
| 경계 | `border` | 카드 보더, 구분선 |
| 강조(브랜드 2차) | `accent` | 별점, Qoin |

### 컴포넌트 규칙
1. **카드**: 흰 배경 + `border` 1px + 얕은 shadow + `radius 16`
2. **칩/배지**: 채움형은 `primary`/`onPrimary`, 라인형은 흰 배경 + `border`
3. **헤더 블록**: `primary` 채움 + 좌하단(또는 하단) 라운드 코너로 캔버스와 분리
4. **리스트 아이템**: 상호작용 있으면 카드로 감싸고 `chevron_right` 말단 배치
5. **텍스트 링크**: 밑줄 없음, 색상만으로 링크 표시(`info`)

### 금지 사항
- `AppColors.*` 외 색상 하드코딩 금지 (기존 원칙 유지)
- 다크 바탕 전제의 `textDark`/`textDefault` 직접 사용보다 의미 기반 `textHeading`/`textBody` 사용 권장 (alias로 호환되지만 새 위젯은 의미 토큰)
- 카드 배경을 네이비 단색으로 쓰지 말 것 — 네이비는 포인트 한정

---

## 레이어 설계

### 변경 대상 (파일)
**Presentation (주 타겟)**
- `lib/presentation/customer/home/home_page.dart` — 배경/스크롤 물리 재확인
- `lib/presentation/customer/home/widgets/home_header.dart` — 미드나잇 블록 + 라운드 코너
- `lib/presentation/customer/home/widgets/nearby_stores_section.dart`
- `lib/presentation/customer/home/widgets/store_card.dart`
- `lib/presentation/customer/home/widgets/grade_badge.dart`
- `lib/presentation/customer/home/widgets/category_filter_section.dart`
- `lib/presentation/customer/home/widgets/recommended_stores_section.dart`
- `lib/presentation/customer/home/widgets/section_title.dart`
- `lib/presentation/common/bottom_nav/bottom_nav.dart`
- `lib/presentation/common/bottom_nav/order_fab.dart`
- `lib/presentation/common/scaffold_with_nav.dart`

**Core (이미 완료된 팔레트 외 추가 없음)**
- `lib/core/theme/app_colors.dart` (유지)
- `lib/core/theme/color_palette.dart` (유지)

**문서**
- `docs/agents/designer_guide.md` — 색상 표/토큰 섹션 이 spec의 원칙으로 교체 (부록성 수정)

### 변경 없음
- Domain/Data 레이어 전체
- Provider/상태 관리 로직

---

## 데이터 흐름
기능 로직 변경 없음 → 기존 흐름 유지. 시각 레이어에서만 토큰 치환.

---

## 에러 처리
시각 리프레시이므로 기능적 에러 경로는 기존 유지. 단, 에러/빈 상태 UI의 **색상만** 새 토큰으로 전환한다.

---

## 작업 분배

### designer (필수, 먼저)
- 레퍼런스: [docs/design/screens/home/home.png](docs/design/screens/home/home.png) + 본 spec의 원칙 섹션
- 산출물: `docs/tasks/home_theme_refresh/design.md`
- 포함 필수:
  - 각 위젯별 색상 토큰 매핑 (구체 토큰명으로 명세)
  - 헤더 라운드 반경/패딩/높이 수치
  - 카드 padding / gap / image ratio
  - 칩 수평/수직 패딩, 글자 크기
  - 하단 네비/FAB 구체 치수와 글로우 스펙
  - 상태 UI(로딩/에러/빈) 시안
  - Figma 원본 대비 조정사항(Qradar 규칙 적용) 명시

### developer (design.md 확정 후)
- 위 `변경 대상` 파일 수정 — 하드코딩된 다크 전제 색상 제거, 의미 토큰으로 치환
- `designer_guide.md` 색상 표를 새 원칙으로 갱신 (유지보수 관점 업데이트)
- 산출물: `docs/tasks/home_theme_refresh/implementation.md`

### tester (구현 후)
- 검증 항목:
  - 라이트 팔레트에서 모든 섹션 가독성(대비) 확인
  - 다크 팔레트 스왑 시에도 렌더 깨짐 없는지(토큰만 쓰면 자동 통과해야 함)
  - 홈.png 레퍼런스 레이아웃/색 배분 일치도
  - 빈 상태/로딩/에러 UI 새 팔레트 적용
  - `AppColors.*` 외 하드코딩 색 없음 (grep 기반)
- 산출물: `docs/tasks/home_theme_refresh/test_report.md`

---

## 완료 기준
- `flutter analyze` clean
- 홈 화면 라이트 팔레트에서 home.png 레퍼런스와 시각적으로 일치
- 팔레트 스왑(`typedef _P = DarkMidnightPalette`) 시 홈 화면 깨지지 않음
- 디자인 원칙이 `designer_guide.md`에 반영되어 이후 화면 작업의 기준으로 사용 가능
