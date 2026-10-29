# store_category_optout 디자인 명세

- 작성: designer / 2026-10-28
- 기준: `spec.md` (§0.3 택소노미 A 확정, §0.4, §2, §4, §10)
- 레퍼런스: Figma 없음. 기존 `store_operation_form_page.dart` 의 `_InstantNoticeBanner` / `_TemporaryClosedToggle` / `_ClosedDatesEditor` 톤을 재사용한다.
- 색상은 전부 `AppColors` 토큰. `Color(0x...)` / `Colors.white` 금지.

---

## 0. 디자인 결정 요약

| 항목 | 결정 | 근거 |
|---|---|---|
| 토글 형태 | **Switch** (체크박스 아님) | 같은 폼의 `_TemporaryClosedToggle` 과 동일 패턴. 즉시 반영되는 "켜짐/꺼짐" 상태 의미에 부합. 체크박스는 "선택 후 제출" 뉘앙스라 부적합. |
| ON 의미 | ON = 손님에게 노출 (기본 전부 ON) | 데이터는 opt-out(끈 것만 저장)이지만 UI 는 "보여주기" 긍정형으로 통일해 이중부정을 피한다. |
| ON 색상 | `AppColors.primary` (임시휴무의 error 색 사용 금지) | 임시휴무는 "위험/휴무" 의미라 error. 여기 ON 은 정상 상태. |
| 전부 끄기 경고 | **인라인 경고 배너(상시) + 저장 시 확인 다이얼로그** | 토글 조작 중엔 막지 않고(가역) 즉시 인지시키되, 영구 반영 직전 한 번 더 확인. 저장 자체는 허용(spec §10). |
| 빈 상태 | 기존 `_EmptyView` 를 **파라미터화해 재사용** (문구/아이콘 분기) | 레이아웃(앱바 + 중앙 아이콘/제목/버튼) 동일. 문구만 다름. |
| Phase B 칩 | 칩 스타일 **현행 재사용**, 라벨 소스만 교체 | §5 |

---

## 1. 점주 운영 폼 — "카테고리 노출 설정" 섹션

### 1.1 진입 / 위치
- 역할: owner. 진입은 기존 경로 그대로 (내 매장 → 운영 정보 수정 = `StoreOperationFormPage`). 신규 화면/라우트 없음 (`role_flows.md` owner "매장 운영 정보 수정" 흐름에 액션 1개 추가).
- 위치: ListView 맨 끝, **"매장 안내" 필드 아래** (`SizedBox(height: 20)` 후 섹션). 이유: 텍스트/시간 입력 뒤, 제출 바 직전의 "설정성" 항목. 상단 `_InstantNoticeBanner`("저장 즉시 반영")가 이 섹션도 포괄한다.
- 하단 padding 120 은 유지(bottomSheet 가림 방지).

### 1.2 구조

```
[섹션 헤더]  카테고리 노출 설정
[설명 문구]  끄면 손님에게 해당 카테고리가 보이지 않아요. (아래 상세)
[전부 끔 경고 배너]  (조건부, §2.1)
[카드 컨테이너]
   ├ 행: 커피        [Switch]
   ├ Divider
   ├ 행: 논커피      [Switch]
   ├ Divider
   └ 행: 디저트      [Switch]
```

### 1.3 섹션 헤더 / 설명
- 헤더: `_FormField` 의 라벨 스타일과 동일 (fontSize 13, w600, `AppColors.textBody`). 텍스트 **"카테고리 노출 설정"**.
- 설명 (헤더 아래 4px, fontSize 12, `AppColors.textMuted`, height 1.4):
  > 끄면 이 매장의 메뉴 탭과 검색에서 해당 카테고리 메뉴가 모두 사라져요. 나중에 브랜드가 메뉴를 추가해도 다시 켜기 전까지 보이지 않아요.
- 헤더-카드 간격 10, 설명 있으면 설명-카드 간격 10.

### 1.4 카드 컨테이너
- `_TemporaryClosedToggle` 과 동일 껍데기: `Container` decoration `color: AppColors.surfaceElevated`, `borderRadius 12`, `border: AppColors.border` 1px. 내부 padding: 가로 16, 행 세로 4 (행 자체 min height 56).
- 행 사이 구분선: `Divider(height: 1, color: AppColors.border)` (카드 안쪽, 좌우 inset 없음).

### 1.5 토글 행 (`_CategoryToggleRow`)
- 구성: `Row` [Expanded(Text label) , Switch].
- 라벨: fontSize 14, w600, `AppColors.textHeading`. 텍스트는 `MainCategoryEntity.label` (code 는 표시하지 않음).
- 보조 문구(서브라인, 선택): OFF 일 때만 라벨 아래 2px, fontSize 12, `AppColors.textMuted` — **"손님에게 숨김"**. ON 일 때는 표시 안 함(행 높이 흔들림 방지를 위해 AnimatedSize 또는 min height 56 고정).
- Switch:
  - `value`: 노출 여부 (= code ∉ excluded)
  - `activeThumbColor: AppColors.onPrimary`, `activeTrackColor: AppColors.primary`
  - `inactiveThumbColor: AppColors.textMuted`, `inactiveTrackColor: AppColors.surface`
  - (기존 임시휴무 Switch 가 `activeThumbColor` 를 쓰므로 동일 API 계열 사용; 정확한 파라미터는 developer 가 Flutter 버전에 맞춤)
- 전체 행 탭으로도 토글(`InkWell`, 터치 영역 최소 48dp). 리플은 `AppColors.primary.withValues(alpha: 0.06)` 정도의 기본 splash.
- 상태 변경은 `setState` 로 로컬 폼 상태만 갱신, **저장은 기존 `_submit`(하단 "저장") 경로 재사용**. 토글 즉시 저장이 아님 → 폼 다른 필드와 동일 UX. 저장 시 `copyWith(excludedMainCategories: …)`.

### 1.6 상태

| 상태 | UI |
|---|---|
| loading (`mainCategoriesActiveProvider` loading) | 카드 안에 shimmer 행 3개: 각 높이 56, 라벨 자리 `AppColors.surface` 라운드 6 막대(너비 80), 우측 Switch 자리 `AppColors.surface` 44x24 라운드 12. 기존 shimmer 컴포넌트(`_LoadingShimmer` 계열)가 있으면 재사용. Switch 비활성. |
| error | 카드 대신 한 줄: 아이콘 `Icons.error_outline_rounded` size 16 `AppColors.error` + "카테고리를 불러오지 못했어요" (12, `AppColors.error`) + 우측 TextButton "다시 시도"(`AppColors.primary`) → `ref.invalidate(mainCategoriesActiveProvider)`. **에러 중에도 폼 저장은 가능**하며 이때 기존 `excludedMainCategories` 를 그대로 보존한다(덮어쓰지 않음). |
| empty (활성 메인 카테고리 0개) | 카드 대신 중앙 정렬 텍스트 "설정할 수 있는 카테고리가 없어요" (13, `AppColors.textMuted`), 패딩 20. 섹션 설명 문구는 숨김. 저장 시 excluded 는 보존. |
| 일반 | 위 §1.2~1.5 |
| 저장 중 (`_submitting`) | Switch `onChanged: null` (비활성) — 기존 제출 바의 로딩과 동일 타이밍. |

### 1.7 휴면(dormant) 코드 처리
- `excludedMainCategories` 에 있지만 admin 이 전역 비활성화한 코드는 **목록에 표시하지 않는다**(active 목록만 렌더).
- 저장 시 반드시 보존: `newExcluded = (원본 excluded ∩ active 아닌 코드) ∪ (화면에서 OFF 인 active 코드)`. 즉 화면에 없는 코드를 지우지 않는다(spec §2.1, §10).

### 1.8 Semantics (접근성)
- 각 행: `MergeSemantics` + `Semantics(label: '$label 카테고리 노출', toggled: value, hint: '켜면 손님에게 보이고, 끄면 숨겨져요')`. 스크린리더 읽기: "디저트 카테고리 노출, 켜짐".
- 행 전체가 하나의 토글 포커스(중복 포커스 방지, Switch 자체 semantics 와 병합).
- 경고 배너: `Semantics(liveRegion: true, label: '모든 카테고리가 꺼져 있어요. 손님에게 메뉴가 보이지 않아요')` — 전부 끄는 순간 즉시 읽힘.
- 섹션 헤더: `Semantics(header: true)`.
- OFF 서브라인("손님에게 숨김")은 행 label 에 포함되므로 `ExcludeSemantics` 처리.

---

## 2. "전부 끄기" 경고

### 2.1 인라인 경고 배너 (상시, 비차단)
- 조건: 렌더된 active 카테고리가 1개 이상이고 **전부 OFF** 일 때만. 섹션 설명 문구와 카드 사이(간격 10)에 표시. AnimatedSwitcher/AnimatedSize 200ms.
- 스타일: `_InstantNoticeBanner` 와 동일 껍데기, semantic 색만 warning.
  - 배경 `AppColors.warning.withValues(alpha: 0.08)`, 보더 `AppColors.warning.withValues(alpha: 0.3)`, radius 12, padding 가로 14 세로 10.
  - 아이콘 `Icons.warning_amber_rounded` size 16 `AppColors.warning`, 간격 8.
  - 텍스트 fontSize 12, height 1.4, `AppColors.warning`:
    > 모든 카테고리를 끄면 손님에게 메뉴가 하나도 보이지 않아 주문을 받을 수 없어요.
- 이 배너가 떠도 Switch 조작은 막지 않는다(가역, 실수 복구 쉬움).

### 2.2 저장 시 확인 다이얼로그 (전부 OFF 이고 이전 저장값과 다를 때만)
- `AlertDialog`: 배경 `AppColors.surfaceElevated`, radius 16.
- 제목(16, w700, `AppColors.textHeading`): **"메뉴가 모두 숨겨져요"**
- 본문(13, `AppColors.textBody`, height 1.5): "모든 카테고리를 끄면 손님은 이 매장에서 메뉴를 볼 수 없어요. 그래도 저장할까요?"
- 버튼: 왼쪽 TextButton "돌아가기"(`AppColors.textMuted`) = 기본 포커스, 오른쪽 TextButton "저장"(`AppColors.error`, w700 — 파괴적 성격의 노출 중단 강조).
- "돌아가기" → 폼 유지(저장 안 함). "저장" → 기존 `_submit` 진행.
- 이미 저장된 값이 전부 OFF 였고 변경이 없으면 다이얼로그 생략(반복 경고 방지).
- 다이얼로그 Semantics: 기본 AlertDialog semantics 사용, 제목이 읽힘.

---

## 3. 매장 메뉴 탭 — 고객 화면 빈 상태

대상: `lib/presentation/customer/order/store/store_menu_page.dart`

현재 `_EmptyView` 는 `allItems.isEmpty`(원본 메뉴 0건) 에서만 노출된다. 카테고리를 전부 끄면 `allItems` 는 비어있지 않지만 `storeAvailableMainCategoriesProvider` 결과가 0이므로 **분기 조건 추가가 필요**하다(developer).

### 3.1 케이스

| 케이스 | 조건 | 화면 |
|---|---|---|
| (a) 원래 메뉴 없음 | `allItems.isEmpty` | 기존 `_EmptyView` **그대로** ("등록된 메뉴가 없어요") |
| (b) 전부 제외 | `allItems` 있음 ∧ 가용 메인 카테고리(excluded 반영) 0개 | `_EmptyView` 재사용, **문구 변형** |
| (c) 선택 카테고리가 방금 제외됨 | 선택 main ∉ 가용 집합 | 빈 화면 아님. spec §4.2 폴백(선택 해제 → 가용 전체 노출). UI 추가 없음. 단 칩 선택 상태가 "전체"로 자연스럽게 되돌아가면 충분(토스트 불필요). |
| (d) 가용 카테고리 있으나 해당 필터 결과 0 | 기존 `_FilteredEmpty` | 변경 없음 ("해당 분류에 메뉴가 없어요") |

### 3.2 `_EmptyView` 재사용 방식
- 가능: 앱바 포함 레이아웃(CustomScrollView + `_AppBar` + 중앙 Column)이 동일. 생성자에 `title`, `subtitle?`, `icon` 를 옵션 파라미터로 추가(기본값은 현행 값 → (a) 무변경).
- (b) 변형:
  - 아이콘: `Icons.local_cafe_outlined` 유지 (size 56, `AppColors.textMuted`) — 별도 아이콘 불필요.
  - 제목(16, w700, `AppColors.textHeading`): **"지금은 주문할 수 있는 메뉴가 없어요"**
  - 서브문구(신규, 13, `AppColors.textMuted`, 제목 아래 6px, 가로 패딩 32, 중앙 정렬, height 1.5): "매장에서 메뉴 준비 중이에요. 다른 매장을 둘러보세요."
    - 점주가 "안 판다고 끈 것"이라는 내부 사정을 고객에게 노출하지 않는 중립 문구.
  - 버튼: 기존 "뒤로가기" TextButton 유지(`AppColors.primary` 기본 테마색).
- Semantics: 아이콘 `ExcludeSemantics`; 제목+서브문구는 `Semantics(container: true, liveRegion: false)` 로 하나의 블록 읽기.
- loading / error 는 기존 `_LoadingShimmer` / `_ErrorView` 그대로. excluded 계산을 위해 store 문서 로딩이 추가되면(spec §4.1) **store 로딩 중에는 `_LoadingShimmer`**, store 로딩 실패 시 기존 `_ErrorView`(재시도)를 쓴다. excluded 미확정 상태로 메뉴를 먼저 그려 깜빡이지 않게 한다(숨겨야 할 메뉴가 잠깐 보이는 플리커 금지).

---

## 4. 점주 화면 측 보조 표기 (선택, 권장)
- 점주가 자기 매장 고객 뷰 미리보기를 보는 화면은 본 과제 범위 아님. 추가 UI 없음.

---

## 5. (Phase B 참고) 홈/검색 카테고리 칩

- 파일: `lib/presentation/customer/home/widgets/category_filter_section.dart` (`_CategoryChip`, `Wrap` spacing 8 / runSpacing 8, 가로 패딩 20).
- 판단: **칩 스타일/레이아웃은 현행 그대로 재사용 가능.** 라벨 소스만 `MenuCategories.all`(12종) → `mainCategoriesActiveProvider` 의 `label` 로 교체. 선택 식별자는 label 이 아니라 **code** 사용 권장(필터 키가 availableMainCategories 코드와 일치해야 함).
- 개수 감소(12 → 3~4)로 `Wrap` 이 한 줄에 들어가 레이아웃은 오히려 단순해진다. 재디자인 불필요.
- 추가로 필요한 상태(개발 시 반영): loading 시 기존 칩 자리 shimmer 3개, error/빈 목록 시 섹션 자체 숨김(필터 없이 전체 매장 노출).
- 점주 매장 등록 폼의 수동 `menuCategories` 칩은 Phase B 에서 제거 예정 — 제거 후 해당 영역 여백(20)만 정리.

---

## 6. 개발자 전달 사항

1. 토글 UI 는 **로컬 폼 상태 + 기존 `_submit` 저장**. 토글 즉시 저장 아님. 새 UseCase/Repo 메서드 금지(spec §9).
2. 저장 시 excluded 계산식은 §1.7 (휴면 코드 보존). 카테고리 로드 error/empty 상태에서는 기존 excluded 를 그대로 `copyWith` 에 전달.
3. 전부-OFF 판정은 "렌더된 active 카테고리 전부 OFF" 기준. 카테고리 0개/로딩/에러 시 경고·다이얼로그 비활성.
4. `store_menu_page.dart`: `allItems.isEmpty` 외에 "가용 카테고리 0" 분기를 추가하고 `_EmptyView` 에 문구 파라미터화. excluded 확정 전에는 로딩 상태 유지(플리커 방지).
5. `Switch` 색상 파라미터는 프로젝트의 Flutter 버전에 맞는 API 사용(기존 `_TemporaryClosedToggle` 이 `activeThumbColor` 사용 중).
6. 신규 문구는 모두 본 문서의 문자열 그대로 사용(한국어, 해요체). 새 색상 토큰 추가 없음.
7. Semantics 는 §1.8 / §2 / §3.2 에 명시된 곳만 필수.

## 7. 사용자 확인 필요 결정

1. **저장 시 확인 다이얼로그(§2.2)** 를 넣을지: 기본안은 인라인 배너 + 다이얼로그 둘 다. 배너만으로 충분하다면 다이얼로그 제거 가능.
2. **고객용 빈 상태 문구(§3.2)** 가 "메뉴 준비 중이에요" 로 중립적인데, "이 매장은 현재 주문 가능한 메뉴가 없어요" 처럼 더 직접적으로 할지.
3. 섹션 위치를 폼 맨 끝(기본안) vs 임시 휴무 근처로 둘지.
