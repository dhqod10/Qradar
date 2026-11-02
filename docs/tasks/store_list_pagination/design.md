# 매장 목록 페이지네이션 (store_list_pagination) 디자인 명세

범위: D0-a — 홈 `주변매장` **전체보기** 화면 1곳. 상태 UI(초기 로딩 / 추가 로딩 / 소진 / 빈 / 에러 / 위치 없음)만 다룬다. 카드·레이아웃 재디자인 없음.

## 참조한 디자인

- Figma: 없음 (상태 UI 위주, 기존 공통 위젯 패턴 따름)
- 기존 화면: `RecommendedStoresPage` 패턴의 Sliver 리스트 (전체보기)
- 참고 컴포넌트: `lib/presentation/common/store_list_states.dart` (`StoreListSkeleton`, `StoreListError`, `RecommendedEmptyState`), `lib/presentation/customer/home/widgets/store_card.dart` (StoreOpenBadge · 거리 표기 포함)
- 색상: `AppColors` 토큰만 사용. 하드코딩 금지.

---

## 화면 구성

### 주변매장 전체보기 (기존 화면, 구조 변경 없음)

- 레이아웃: 기존 Sliver 리스트 유지. 아이템 = 기존 매장 카드.
- 배경: `AppColors.background`
- Scroll: 단일 스크롤. 리스트 마지막 sliver 뒤에 **footer sliver 1개** 추가 (상태에 따라 내용 교체).
- 상태 우선순위: 초기 상태(loading / error / empty) > 목록 + footer(loadingMore / loadMoreError / exhausted / idle).

```
[AppBar - 기존]
[위치 폴백 배너 - 위치 없음일 때만, 리스트 최상단 sliver]
[StoreCard x N - 기존 재사용]
[Footer sliver - 상태별 1종]
```

---

## 컴포넌트 목록

### 0. 매장 카드 (재사용, 신규 디자인 없음)

- `store_card.dart` 의 기존 카드를 **그대로 재사용**한다. `StoreOpenBadge`, 거리(`DistanceCalculator.formatKm`) 표기도 변경 없음.
- 거리 표기: **유지**. 거리순 목록이므로 `distanceKm` 가 있으면 현행대로 표시. 위치 폴백(서울시청 기준) 상태에서는 아래 §6 의 안내 배너와 함께 표시하며, 거리 숫자를 숨기지 않는다 (기준 지점이 폴백임은 배너로 고지).
- append 시 카드 간격은 기존 리스트 간격 그대로 (끊김 없이 이어짐). 추가 로드 시 기존 카드 위치/순서 불변 (spec §1).

### 1. 초기 로딩 (첫 20개)

- 재사용: `StoreListSkeleton` (shimmer base `AppColors.surface`, highlight `AppColors.surfaceElevated`).
- 파라미터: `rows: 6`, `rowHeight: 96`, `gap: 12` (카드 실제 높이와 맞추되 기본값 96/12 유지). 좌우 패딩은 실제 리스트와 동일하게 적용.
- 스피너 단독 사용 금지 (레이아웃 점프 방지 목적으로 skeleton 사용).

### 2. 추가 로딩 footer (isLoadingMore)

- 역할: 스크롤 하단 도달 후 다음 20건 로드 중임을 표시. 기존 카드는 그대로 유지.
- 위젯 구조: `Padding` > `Center` > `SizedBox(20x20)` > `CircularProgressIndicator(strokeWidth: 2)`
- 크기: 인디케이터 20x20, footer 전체 높이 약 72 (상하 padding 24 + 20 + 24 = 68, 반올림 72 허용)
- 색상: `AppColors.primary`
- 배경: 투명 (`AppColors.background` 위)
- 접근성: `Semantics(label: '매장을 더 불러오는 중')`
- 반경 확장 중에도 동일 UI (사용자에게 반경 개념 노출하지 않음).

### 3. 소진 footer (exhausted, 목록 1건 이상)

- 역할: 최대 반경까지 확장했고 더 이상 없음을 명시. (spec §8 의 "선택" 항목 -> **표시하기로 결정**. 끝이 어디인지 불확실하면 사용자가 계속 스크롤을 시도함.)
- 위젯 구조: `Padding(vertical: 24)` > `Center` > `Text`
- 문구: `주변에 더 이상 매장이 없어요`
- 텍스트: fontSize 12, w500, `AppColors.textMuted`, 중앙 정렬
- 하단: 바텀 네비/제스처 영역 고려해 `SafeArea` 또는 기존 리스트 bottom padding 유지.
- 상호작용 없음.
- 문구에 km 수치 노출 금지 (반경은 내부 구현 개념).

### 4. 빈 상태 (최대 반경 내 0건)

- 조건: 반경 자동 확장을 끝까지 시도한 뒤에도 0건 (spec §6). 확장 중에는 초기 로딩 skeleton 유지.
- **기존 `RecommendedEmptyState` 재사용 불가** (문구가 "선택한 카테고리에 해당하는 매장이 없습니다" 로 카테고리 필터 전용). `store_list_states.dart` 에 **`NearbyEmptyState`** (또는 `RecommendedEmptyState` 에 title 파라미터 추가) 신설.
- 위젯 구조: `Padding(vertical: 32)` > `Center` > `Column`(아이콘, gap 12, 제목, gap 6, 보조)
- 아이콘: `Icons.storefront_outlined` size 40, `AppColors.textMuted`
- 제목: `주변에 매장이 없어요` — 13, w500, `AppColors.textBody`
- 보조: `위치를 바꾸거나 나중에 다시 확인해 주세요` — 12, `AppColors.textMuted`
- 버튼 없음.

### 5. 에러 / 재시도

#### 5-a. 초기 로드 실패 (전체 화면)

- 재사용: `StoreListError` 그대로 (아이콘 `AppColors.error`, 제목 `AppColors.textHeading`, 설명 `AppColors.textMuted`, 버튼 `AppColors.primary`/`AppColors.onPrimary`).
- 문구: 기본값 유지 (`매장 정보를 불러올 수 없어요` / `잠시 후 다시 시도해 주세요` / `다시 시도`). 예외 원문 노출 금지.
- 재시도 = 초기 로드 재실행.

#### 5-b. 추가 로드 실패 (footer, 기존 목록 보존)

- 역할: 전체 화면 에러로 덮지 않고 목록 하단에 컴팩트 재시도 제공.
- 위젯 구조: `Padding(vertical: 16, horizontal: 16)` > `Column`(center) > [`Row`(아이콘 + 문구)] , gap 8, `TextButton` 재시도
- 아이콘: `Icons.error_outline` size 18, `AppColors.error`
- 문구: `매장을 더 불러오지 못했어요` — 12, w500, `AppColors.textMuted`
- 버튼: `TextButton` `다시 시도` — 13, w600, 글자색 `AppColors.primaryBright`, 최소 터치 영역 44 높이. (footer 이므로 채움 버튼보다 가볍게 텍스트 버튼.)
- 동작: 탭 -> footer 가 즉시 §2 로딩 footer 로 전환 -> `loadMore()` 재호출. 성공 시 append, 실패 시 다시 5-b.
- 실패 상태에서는 스크롤 트리거를 **자동 재호출하지 않는다** (무한 실패 루프 방지). 사용자 탭으로만 재시도.

### 6. 위치 없음 / 위치 못 가져옴 (폴백)

- 역할: 거리순 전제(사용자 위치)가 깨졌을 때 폴백 중심(서울시청)으로 정렬됨을 고지. 목록 자체는 정상 노출 (spec §1: 폴백 중심에서 가까운 순).
- 위젯: 리스트 **최상단 sliver 배너** (스크롤 시 함께 올라감, sticky 아님).
- 구조: `Container` > `Row`(아이콘 20, gap 10, `Expanded` 텍스트 Column, 선택적 액션)
- 배경: `AppColors.surface`, border 1 `AppColors.border`, radius 12, padding 12x14, 외부 margin 좌우는 리스트와 동일 / 하단 12
- 아이콘: `Icons.location_off_outlined` size 20, `AppColors.textMuted`
- 제목: `내 위치를 확인할 수 없어요` — 13, w600, `AppColors.textHeading`
- 설명: `서울시청 기준 가까운 순으로 보여드려요` — 12, `AppColors.textMuted`
- 액션(권한 거부 상태일 때만): 우측 `TextButton` `설정 열기` — 12, w600, `AppColors.primaryBright`. 기존 pre-permission 흐름이 있으면 그 진입점으로 연결, 없으면 앱 설정 열기. 일시적 위치 획득 실패(권한은 있음)는 액션 없음 또는 `다시 시도`로 대체.
- 위치가 복구되어 중심이 바뀌면 spec 대로 목록 전체 리셋(skeleton 부터) 후 배너 제거.
- 이 배너는 목록이 비어 있어도 §4 빈 상태 위에 함께 표시 가능.

---

## 상태 매트릭스

| 상태 | 표시 | 컴포넌트 |
|---|---|---|
| 초기 loading | skeleton 6행 | `StoreListSkeleton` (재사용) |
| 초기 error | 전체 에러 + 재시도 | `StoreListError` (재사용) |
| 초기 empty | 빈 안내 | `NearbyEmptyState` (신규/확장) |
| 목록 idle | 카드들, footer 없음 또는 높이 있는 투명 spacer | 기존 카드 |
| 추가 loading | footer 스피너 | footer §2 (신규) |
| 추가 error | footer 문구 + 텍스트 재시도 | footer §5-b (신규) |
| 소진 | footer 안내 문구 | footer §3 (신규) |
| 위치 없음 | 상단 배너 + 정상 목록 | 배너 §6 (신규) |

---

## 인터랙션 / 스크롤 트리거

- 트리거: 스크롤 위치가 `maxScrollExtent - 300px` (약 카드 3개 높이) 이내에 도달하면 `loadMore()` 호출. 고정값은 `GradeThresholds` 류 상수가 아니라 화면 로컬 상수로 둬도 무방 (디자인 값).
- 중복 호출 가드: `isLoadingMore` 중 / `exhausted` / `loadMoreError` 상태에서는 트리거 무시.
- footer 전환은 `AnimatedSwitcher` 200ms fade 권장 (선택). 카드 append 에는 별도 애니메이션 없음 (요동 방지).
- Pull-to-refresh 는 이번 범위 밖 (기존 동작 유지).
- 목록이 한 화면보다 짧아 스크롤이 생기지 않는 경우(초기 20건이 화면을 못 채움)에도 `loadMore()` 가 연쇄 호출될 수 있어야 한다. 레이아웃 후 `maxScrollExtent` 가 0 이하이고 `exhausted` 가 아니면 자동 추가 로드 (developer 구현 필요, 아래 참조).

---

## Figma 대비 변경사항

- Figma 없음. 변경사항은 기존 목록에 footer/배너 sliver 추가뿐. 카드·AppBar·간격 변경 없음.

## 개발자 전달 특이사항

1. **카드 재사용**: `StoreCard`(StoreOpenBadge, 거리 포함) 변경 금지. 영업배지·거리는 회귀 금지 항목.
2. **거리 표기 유지**: 거리순이므로 현행대로 표시. 폴백 위치일 때도 숨기지 않고 §6 배너로 고지.
3. **빈 상태 위젯**: `RecommendedEmptyState` 는 카테고리 전용 문구라 그대로 쓰면 오해를 줌. `NearbyEmptyState` 신설 또는 title/subtitle 파라미터화 필요 (`store_list_states.dart`).
4. **footer 위젯 3종 + 배너 1종 신설**: `store_list_states.dart` 에 loading footer / retry footer / end footer, 위치 폴백 배너. 문구는 파라미터로 받아 재사용성 확보 (기존 파일 컨벤션).
5. **스크롤 트리거 위치**: `maxScrollExtent - 300` 이내. `NotificationListener<ScrollNotification>` 또는 `ScrollController` 중 택일. Sliver 구조이므로 footer 는 `SliverToBoxAdapter`.
6. **짧은 목록 연쇄 로드**: 첫 20건이 화면을 못 채우면 스크롤 이벤트가 안 생겨 추가 로드가 멈춤. 레이아웃 후 postFrame 에서 `maxScrollExtent` 확인 후 `loadMore()` 호출 필요.
7. **에러 루프 방지**: `loadMoreError` 상태에서 자동 재호출 금지, 사용자 탭 재시도만.
8. **반경 비노출**: 사용자 문구에 km/반경 언급 금지. 반경 확장 중에도 로딩 footer 동일.
9. **색상**: 위 모든 색은 `AppColors.*` 토큰. `Colors.*`/`Color(0x...)` 금지.
10. **초기 빈 상태 vs 확장 중**: 반경 자동 확장 중에는 empty 가 아니라 skeleton 유지. 최대 반경 소진 후에만 empty 표시.

## 사용자 확인이 필요한 디자인 결정

- 소진 footer 문구("주변에 더 이상 매장이 없어요") 표시 여부 — spec 에서 "선택"이었으며 본 문서는 **표시**로 결정. 불필요하면 빈 spacer 로 대체 가능.
- 위치 폴백 배너의 `설정 열기` 액션 연결 대상 (기존 pre-permission 흐름 진입점 존재 여부는 developer 확인 후 확정).
