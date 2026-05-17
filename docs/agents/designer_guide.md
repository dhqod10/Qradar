# 디자이너 가이드 (Designer Guide)

## 역할 정의

디자이너는 설계자의 `spec.md`와 사용자가 제공한 Figma / 디자인 레퍼런스를 기반으로, Qradar 디자인 시스템에 맞는 화면 명세를 작성하는 역할이다.

주요 산출물:

- `docs/tasks/[기능명]/design.md`

디자이너는 직접 코드를 구현하지 않는다.  
구현이 필요한 내용은 developer가 구현할 수 있도록 `design.md`에 명확히 기록한다.

---

## 기본 원칙

- `CLAUDE.md`를 따른다.
- 새 화면 또는 새 UI 흐름을 만들 때는 이 가이드를 참고한다.
- 디자인 시스템 판단이 필요하면 이 가이드를 기준으로 한다.
- 화면 구조는 `spec.md`를 기준으로 한다.
- Figma 또는 기존 디자인 레퍼런스가 있으면 우선 확인한다.
- 개발자가 바로 구현 가능한 수준으로 명세한다.
- 모든 색상은 `AppColors` 토큰 기준으로 작성한다.
- 하드코딩 색상은 사용하지 않는다.

---

## 입력 문서

디자이너는 작업 전에 아래 문서를 확인한다.

### 필수

- `docs/tasks/[기능명]/spec.md`

### 조건부

- `docs/design/screens/[화면명]/[화면명].png`
  - Figma export 이미지가 있는 경우
- `docs/design/screens/[화면명]/[화면명].md`
  - Figma 코드 스니펫 또는 메모가 있는 경우
- `docs/design/components/`
  - 공통 컴포넌트를 참고해야 하는 경우
- `docs/architecture.md`
  - 화면 구조와 파일 위치 판단이 필요한 경우

---

## 디자인 레퍼런스 위치

디자인 레퍼런스는 아래 구조를 따른다.

```text
docs/design/
├── screens/
│   └── [화면명]/
│       ├── [화면명].png
│       └── [화면명].md
└── components/
    ├── [컴포넌트명].png
    └── [컴포넌트명].md
```

기준:

- 화면 단위 레퍼런스는 `docs/design/screens/[화면명]/`에 둔다.
- 공통 컴포넌트 레퍼런스는 `docs/design/components/`에 둔다.
- Figma 디자인은 레이아웃과 UX 의도를 우선 참고한다.
- 최종 색상, 간격, 상태 UI는 Qradar 디자인 시스템에 맞게 정리한다.

---

## Figma 디자인 참조 원칙

### 유지할 것

Figma 또는 사용자가 제공한 디자인에서 아래 항목은 최대한 존중한다.

- 전체 레이아웃 구조
- 섹션 배치
- 정보 계층
- 네비게이션 흐름
- 핵심 UX 패턴
- 주요 컴포넌트 배치
- 사용자 의도가 담긴 시각적 흐름

### 조정할 것

아래 항목은 Qradar 디자인 시스템에 맞게 조정한다.

- 색상
- 타이포그래피
- 간격 / 여백
- 그림자 / 라운드
- 컴포넌트 상태
- loading / error / empty UI
- Flutter 구현에 적합하지 않은 구조

---

## Qradar 디자인 시스템

현재 Qradar는 아래 컨셉을 기본으로 한다.

> 밝은 캔버스(화이트 배경) + 미드나잇 네이비 포인트

디자인 원칙:

- 전체 화면은 밝고 단순하게 유지한다.
- 미드나잇 네이비는 강조 요소에 제한적으로 사용한다.
- 카드, 리스트, 입력창은 깨끗하고 가벼운 표면감을 유지한다.
- Qradar 고유 용어와 프리미엄한 감성을 유지한다.
- 화면 코드는 색상 값을 직접 쓰지 않고 `AppColors.xxx` 토큰만 사용한다.

---

## 색상 토큰

색상은 반드시 `AppColors`를 기준으로 명세한다.

색상 토큰의 **단일 진실원**은 `lib/core/theme/app_colors.dart` 와 그 참조 팔레트인 `lib/core/theme/color_palette.dart` 다.  
실제 HEX 값은 활성 팔레트(현재 `LightMidnightAccentPalette`) 가 결정하므로, 디자인 명세에서는 HEX 값이 아닌 **토큰 이름**으로 작성한다. 팔레트 스왑 시 자동으로 최신 색상이 따라간다.  
WebView/HTML 등 외부 컨텍스트에 색상을 전달해야 하는 경우, 헬퍼(예: `MapConfig.markerColorHexForGrade`) 에서 `AppColors` 를 hex 로 변환해 전달한다 — HTML/JS 안에 색상을 하드코딩하지 않는다.

### Brand / Point

| 용도 | 토큰 | 설명 |
|---|---|---|
| 메인 포인트 | `AppColors.primary` | 헤더, 선택 칩, 배지, FAB, 활성 탭, 버튼·아이콘·로고 등 핵심 UI |
| 보조 포인트 | `AppColors.primaryLight` | 그라디언트 종점, 보조 강조 |
| 서브 하이라이트 | `AppColors.primaryBright` | 링크, 보조 액션, 로딩바, 활성화 상태, 하이라이트 |
| 심부 포인트 | `AppColors.primaryDeep` | 헤더 그라디언트, 깊이감 |
| 포인트 위 전경 | `AppColors.onPrimary` | primary 배경 위 텍스트 / 아이콘 |
| 프리미엄 강조 | `AppColors.accent` | Qoin, 별점, 등급/프리미엄 표현 |

### Surface / Background

| 용도 | 토큰 | 설명 |
|---|---|---|
| 전체 배경 | `AppColors.background` | Scaffold 기본 배경 |
| 기본 표면 | `AppColors.surface` | placeholder, 입력창 배경, 비활성 요소, shimmer base |
| 상승 표면 | `AppColors.surfaceElevated` | 카드, 네비 바, 다이얼로그, 입력창 (포커스 가능 면) |
| 경계선 | `AppColors.border` | 카드 보더, 구분선 |

### Text

| 용도 | 토큰 | 설명 |
|---|---|---|
| 제목 | `AppColors.textHeading` | 앱 이름, 섹션 제목, 카드 타이틀, 주요 헤더 |
| 본문 | `AppColors.textBody` | 일반 텍스트 |
| 보조 | `AppColors.textMuted` | 서브타이틀, 설명, 거리, 비활성, 캡션 |

### Semantic

| 용도 | 토큰 |
|---|---|
| 성공 | `AppColors.success` |
| 에러 | `AppColors.error` |
| 경고 | `AppColors.warning` |
| 정보 | `AppColors.info` |

---

## 색상 사용 규칙

- 색상은 반드시 `AppColors.xxx` 형태로 명세한다.
- `Color(0x...)` 직접 사용을 금지한다.
- HEX 값은 설명 용도로만 사용할 수 있고, 구현 지시는 반드시 `AppColors`로 작성한다.
- `Colors.white`, `Colors.black` 직접 사용은 피하고 가능한 경우 `AppColors` 토큰으로 대체한다.
- 포인트 블록 위 텍스트와 아이콘은 `AppColors.onPrimary`를 사용한다.
- 링크성 텍스트는 `AppColors.info` 또는 `AppColors.primaryBright`를 사용한다.
- 경고 / 에러 / 성공 / 정보 상태는 semantic 토큰을 사용한다.

---

## 타이포그래피 기준

### 제목

- 섹션 제목, 카드 타이틀, 주요 헤더
- 권장:
  - fontSize: 16~20
  - fontWeight: w700
  - color: `AppColors.textHeading`

### 본문

- 일반 설명, 리스트 텍스트
- 권장:
  - fontSize: 13~16
  - fontWeight: w400~w500
  - color: `AppColors.textBody`

### 보조 텍스트

- 거리, 설명, 캡션, 비활성 라벨
- 권장:
  - fontSize: 11~13
  - fontWeight: w400~w500
  - color: `AppColors.textMuted`

### 포인트 배경 위 텍스트

- primary 배경 위 텍스트
- color: `AppColors.onPrimary`
- 필요 시 alpha 0.75~0.9 수준으로 계층 구분

---

## 컴포넌트 원칙

### 카드

기본 카드 스타일:

- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- radius: 16
- shadow: 아주 연한 primary alpha 기반
- 다크하고 무거운 shadow 금지

권장 명세 예:

```text
background: AppColors.surfaceElevated
border: AppColors.border / 1px
borderRadius: 16
shadow: AppColors.primary alpha 0.04
```

---

### 버튼

채움 버튼:

- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`
- radius: 12 또는 pill 형태
- 주요 CTA에 사용

라인 / 보조 버튼:

- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border`
- 텍스트: `AppColors.textBody` 또는 `AppColors.primary`

---

### 칩

선택됨:

- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`
- border 없음
- radius: 999 또는 pill

선택 안 됨:

- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border`
- 텍스트: `AppColors.textBody`
- radius: 999 또는 pill

---

### 입력창

기본:

- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border`
- 텍스트: `AppColors.textBody`
- hint: `AppColors.textMuted`

포커스:

- border: `AppColors.primary`
- cursor: `AppColors.primary`

---

### 아이콘

- 활성 상태: `AppColors.primary`
- 비활성 상태: `AppColors.textMuted`
- primary 배경 위: `AppColors.onPrimary`
- 에러 상태: `AppColors.error`
- 정보 상태: `AppColors.info`

---

### FAB / 주요 액션

- 배경: `AppColors.primary` 또는 `AppColors.primary → AppColors.primaryLight`
- 아이콘: `AppColors.onPrimary`
- shadow: `AppColors.primary` alpha 기반
- 과도한 애니메이션은 피하고, 필요한 경우 명세에 duration과 curve를 적는다.

---

### 배지

기본:

- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`
- radius: pill
- 작은 padding

등급 배지는 색상이 아니라 텍스트로 구분하는 것을 기본으로 한다.  
등급별 색상이 필요한 경우 design.md에 명시적으로 이유를 기록한다.

---

## 상태 UI 기준

사용자에게 보이는 화면은 아래 상태를 반드시 고려한다.

### Loading

- shimmer 또는 progress indicator 사용
- shimmer base: `AppColors.surface`
- shimmer highlight: `AppColors.surfaceElevated`
- progress color: `AppColors.primary`

### Error

- 에러 아이콘: `AppColors.error`
- 제목: `AppColors.textHeading`
- 설명: `AppColors.textMuted`
- 재시도 버튼이 가능한 경우 제공
- 버튼 색상: `AppColors.primary` / `AppColors.onPrimary`

### Empty

- 아이콘: `AppColors.textMuted`
- 안내 문구: `AppColors.textBody`
- 보조 설명: `AppColors.textMuted`
- 사용자가 다음 행동을 알 수 있게 작성

---

## 화면 명세 작성 기준

`design.md`는 developer가 바로 구현할 수 있는 수준으로 작성한다.

반드시 포함할 항목:

- 참조한 디자인
- 화면 구성
- 컴포넌트 목록
- 각 컴포넌트의 위젯 구조
- 크기
- padding / margin / gap
- 색상 토큰
- 텍스트 스타일
- 상태
- 인터랙션
- loading / error / empty UI
- Figma 대비 변경사항
- 개발자 전달 특이사항

---

## design.md 템플릿

```markdown
# [기능명] 디자인 명세

## 참조한 디자인

- Figma:
- 기존 화면:
- 참고 컴포넌트:

---

## 화면 구성

### [화면명]

- 레이아웃:
- 배경:
- SafeArea:
- Scroll:
- AppBar / Header:
- 주요 섹션:

---

## 컴포넌트 목록

### 1. [컴포넌트명]

- 역할:
- 위젯 구조:
- 크기:
- padding:
- margin:
- gap:
- 배경:
- border:
- radius:
- shadow:
- 텍스트:
- 아이콘:
- 상태:
  - default:
  - selected:
  - disabled:
  - loading:
  - error:
  - empty:

### 2. [컴포넌트명]

- 역할:
- 위젯 구조:
- 크기:
- 색상:
- 인터랙션:

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| 탭 | |
| 스와이프 | |
| 입력 | |
| 새로고침 | |

---

## 상태별 UI

### Loading

- 표시 방식:
- 컴포넌트 구조:
- 색상:

### Error

- 표시 방식:
- 문구:
- 재시도 여부:

### Empty

- 표시 방식:
- 문구:
- 다음 행동 안내:

---

## Figma 대비 변경사항

| 항목 | Figma / 기존안 | Qradar 적용 |
|---|---|---|
| 색상 | | |
| 간격 | | |
| 컴포넌트 | | |

---

## 개발자 전달 특이사항

- 구현 시 주의할 점:
- 재사용할 컴포넌트:
- AppColors 토큰:
- 애니메이션 수치:
- 후속 작업:
```

---

## 개발자 전달 기준

디자이너는 developer가 추측하지 않도록 아래 항목을 명확히 작성한다.

- 어떤 기존 컴포넌트를 재사용할지
- 새로 만들어야 하는 컴포넌트는 무엇인지
- 색상 토큰은 무엇인지
- 상태 UI는 어떻게 나뉘는지
- 인터랙션은 어떤 동작인지
- Figma와 다르게 바꾼 이유가 무엇인지

---

## 완료 기준

디자이너는 아래 조건을 만족해야 완료 보고할 수 있다.

- `spec.md` 요구사항을 반영했다.
- 화면 구조를 명확히 작성했다.
- 컴포넌트별 구현 수준 명세를 작성했다.
- 모든 색상을 `AppColors` 기준으로 작성했다.
- loading / error / empty 상태를 정의했다.
- Figma 또는 기존 디자인 대비 변경사항을 기록했다.
- 개발자 전달 특이사항을 작성했다.

---

## 디자이너가 피해야 할 것

- `AppColors`가 아닌 색상 값을 구현 지시로 사용하지 않는다.
- 단순히 “예쁘게”, “적당히”, “깔끔하게”처럼 애매하게 쓰지 않는다.
- 상태 UI를 생략하지 않는다.
- 개발자가 추측해야 하는 크기, 간격, 색상, 상태를 남기지 않는다.
- spec.md에 없는 기능을 임의로 추가하지 않는다.
- 구현 코드 자체를 작성하지 않는다.