# Phase 3c-3 알림 설정 UI 디자인 명세

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-10-21 | designer | 본 design 최초 작성 (spec 결정 A~E / Q1~Q5 사용자 확정 반영). U1~U8 전수 판단, U3 / U4 / U6 판단 사유 기록 |

---

## 참조한 디자인

- spec: `docs/tasks/order_flow_phase3c/3_notification_settings/spec.md`
- 직전 sub-phase 톤: `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/design.md` (카드 = `surfaceElevated` + `border` + radius 16, 섹션 제목 15/w700)
- 기존 배너: `lib/presentation/owner/orders/widgets/notification_denied_banner.dart` (warning 10% 배경 + warning 테두리 + radius 12)
- 기존 Switch 사용례: `store_core_form_page.dart` (SwitchListTile, 제목 15/w600 + 부제 12 muted), `store_operation_form_page.dart` (Switch + `inactiveTrackColor: surface`)
- 기존 AppBar 사용례: `store_core_form_page.dart` (background 배경, elevation 0, 제목 17/w700 textHeading)
- 진입 타일 선례: `OwnerMorePage._Tile` (ListTile, 아이콘 22, 제목 15/w600, 부제 12 muted, chevron 18)
- 권한 다이얼로그: `notification_permission_dialog.dart` (카피 재검수 대상)
- 역할 흐름: `docs/processes/role_flows.md` §4.1 (customer) / §4.2 (owner) — 진입은 각 역할 **더보기 탭 > 알림 설정 > `Navigator.push`**. 스캐폴드의 하단 탭은 push 된 설정 화면 아래에 남지 않는다 (풀스크린 push, 기존 앱 패턴과 동일).

---

## 화면 구성

### 1. NotificationSettingsPage (신규, `lib/presentation/common/notification/notification_settings_page.dart`)

```
┌─────────────────────────────────┐
│ AppBar  ←   알림 설정            │
├─────────────────────────────────┤
│ ListView  padding: h20 / t8 / b32│
│                                 │
│ [OS 권한 배너]  (denied / notDetermined 일 때만)
│ SizedBox(20)                    │
│                                 │
│ 섹션 헤더  "주문 알림" | "매장 알림"
│ SizedBox(8)                     │
│ ┌─ 토글 카드 ──────────────────┐ │
│ │ 토글 행 1                    │ │
│ │ ───────── divider ───────── │ │
│ │ 토글 행 2                    │ │
│ └──────────────────────────────┘ │
│ SizedBox(12)                    │
│ 하단 안내 (배너 없을 때만)        │
└─────────────────────────────────┘
```

#### 1-1. AppBar

| 항목 | 값 |
|---|---|
| backgroundColor | `AppColors.background` |
| elevation / scrolledUnderElevation | 0 / 0 |
| leading | 기본 뒤로가기 (`Icons.arrow_back_ios_new_rounded`, size 20, color `AppColors.textHeading`). 닫기(X) 아님 — 더보기에서 push 되는 상세 화면이므로 back |
| title | `'알림 설정'` — fontSize 17 / w700 / `AppColors.textHeading` (기존 폼 페이지 AppBar 와 동일) |
| centerTitle | 앱 기존 AppBar 기본값 따름 (별도 지정 없음) |

Scaffold `backgroundColor: AppColors.background`. 바디는 `SafeArea` + `ListView` (작은 화면 / 큰 글꼴 대응 스크롤 보장).

#### 1-2. 섹션 헤더

- 위치: 토글 카드 바로 위, 좌측 정렬 (카드와 같은 20 gutter, 추가 left padding 4)
- 카피: 고객 `'주문 알림'` / 점주 `'매장 알림'`
- 스타일: fontSize 13 / w600 / `AppColors.textMuted`
- 사유: 토글이 2개뿐이라 화면이 빈약해 보이는 것을 막고(spec 전달사항), 카드의 성격을 한 줄로 알린다. 라벨만 있고 설명은 두지 않는다 (심플 유지).

#### 1-3. 토글 카드 (`_SettingsToggleCard`)

| 항목 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| 테두리 | `AppColors.border` 1px |
| borderRadius | 16 (sub-phase 2 `_OrderProgressIndicator` 카드와 동일) |
| clipBehavior | `Clip.antiAlias` (InkWell ripple 이 라운드 안에 머물도록) |
| 행 구분선 | `Divider(height: 1, thickness: 1, color: AppColors.border)` — 행 사이에만, 좌우 inset 16 |

#### 1-4. 토글 행 (`_SettingToggleTile`)

구현 권고: **`SwitchListTile`** 사용 (선례 `store_core_form_page.dart`). 행 전체 탭으로 토글되고, 접근성 semantics(토글 상태 + 제목 + 부제) 가 프레임워크에서 자동 병합되기 때문. 아래 스타일을 `SwitchListTile` 파라미터로 매핑한다.

| 항목 | 값 |
|---|---|
| contentPadding | `EdgeInsets.symmetric(horizontal: 16, vertical: 6)` |
| 최소 높이 | 72 (부제 1줄 기준), 부제 2줄이면 내용에 맞춰 자연 확장. 어떤 경우에도 터치 영역 ≥ 48 |
| title | fontSize 15 / w600 / `AppColors.textHeading` |
| subtitle | fontSize 12 / w400 / height 1.4 / `AppColors.textMuted`, 상단 간격 2 |
| subtitle maxLines | 제한 없음 (2줄 허용, ellipsis 금지) |
| 제목-스위치 간격 | 12 (ListTile 기본 gap 사용 가능) |
| tileColor | 투명 (카드 배경 노출) |
| isThreeLine | false (높이는 내용 기준 자연 확장) |

**Switch 색상 (AppColors 만):**

| 속성 | 토큰 | 비고 |
|---|---|---|
| `activeThumbColor` | `AppColors.onPrimary` | ON 썸 |
| `activeTrackColor` | `AppColors.primary` | ON 트랙 = 미드나잇 네이비 포인트 (라이트). 다크 팔레트에서는 primary 가 sky 계열로 자동 전환 |
| `inactiveThumbColor` | `AppColors.textMuted` | OFF 썸 |
| `inactiveTrackColor` | `AppColors.surface` | OFF 트랙 (기존 `store_operation_form_page` 선례) |
| `trackOutlineColor` | OFF: `AppColors.border` / ON: 투명(`WidgetStateProperty` 로 `Colors.transparent` 대신 `AppColors.primary` 사용) | OFF 트랙이 흰 카드 위에서 사라지지 않도록 외곽선 |
| splash / overlay | `AppColors.primary.withValues(alpha: 0.08)` | 행 탭 ripple |

> 강조색으로 `success` / `error` 를 쓰지 않는다. 알림 토글은 중립 설정 항목이며, 브랜드 포인트(primary) 로 ON 을 표현한다.

#### 1-5. 하단 안내 (`_FootNote`)

- 노출 조건: **OS 권한이 `authorized`(또는 provisional) 이고 `_osStatus != null`** 일 때만 (배너가 떠 있을 땐 숨김 — 같은 말 중복 방지)
- 카피: `'알림은 기기 설정에서 알림이 허용된 경우에만 받을 수 있어요.'`
- 스타일: fontSize 12 / `AppColors.textMuted` / height 1.5, 좌우 padding 4
- 사유: 앱 내 토글과 OS 권한의 관계(두 겹 구조)를 정상 상태에서도 한 줄로 알려, "켰는데 왜 안 와요?" 문의를 예방.

#### 1-6. 역할별 토글 확정 카피 (U2)

브랜드 톤 = 반높임체(`-어요` / `-해요`), 담담하고 친근하게. 이모지 / 느낌표 없음.

**고객 (customer, brand / admin fallback 포함)** — 섹션 헤더 `주문 알림`

| 순서 | key | 제목 | 부연 설명 | 기본 |
|---|---|---|---|---|
| 1 | `orderProgress` | `주문 진행 알림` | `접수, 조리 시작, 픽업 준비 소식을 알려드려요` | ON |
| 2 | `pickupComplete` | `픽업 완료 알림` | `픽업이 완료되면 알려드려요` | **OFF** (옵트인) |

**점주 (owner)** — 섹션 헤더 `매장 알림`

| 순서 | key | 제목 | 부연 설명 | 기본 |
|---|---|---|---|---|
| 1 | `newOrder` | `신규 주문 알림` | `새 주문이 들어오면 바로 알려드려요` | ON |
| 2 | `refundRequest` | `환불 요청 알림` | `고객이 환불을 요청하면 알려드려요` | ON |

- 쉼표 나열 (`접수, 조리 시작, 픽업 준비`) 은 가운뎃점(`·`) 보다 반높임체 문장에서 읽기 자연스러워 채택 (spec 잠정안의 `·` 에서 조정).
- 제목에 `알림` 접미를 유지: 페이지 타이틀이 이미 "알림 설정" 이지만, 스크린리더 / 자동화(idb) 에서 토글 단독 라벨이 의미를 갖도록 하기 위함 (§접근성).

#### 1-7. 줄바꿈 / 폭 대응 (U8)

가용 텍스트 폭 = 화면폭 − gutter 40 − 행 padding 32 − Switch 약 52 − gap 12.

| 화면폭 | 가용 폭 | 결과 |
|---|---|---|
| 375pt | 약 239pt | 제목 모두 1줄. 부제 12pt 기준 약 19~20자/줄 → 가장 긴 `접수, 조리 시작, 픽업 준비 소식을 알려드려요`(24자) 는 **2줄**, 나머지 부제는 1~2줄 |
| 430pt | 약 294pt | 부제 대부분 1줄, 가장 긴 문구만 경계. 2줄 되어도 무방 |

- **부제 2줄 허용이 전제**이며 행 높이는 내용에 맞춰 늘어난다 (고정 높이 금지, ellipsis 금지).
- 시스템 글꼴 확대(textScale 1.3) 시에도 행이 늘어나기만 하고 잘리지 않도록 고정 `height` 지정 금지 (`minHeight` 만).

---

### 2. OS 권한 배너 (U3)

#### 2-0. U3 판단 — 기존 `NotificationDeniedBanner` 를 common 으로 승격하지 않고, 설정 화면 전용 `NotificationPermissionBanner` 를 신규 작성한다

**판단: 신규 작성 (승격 안 함). 기존 점주 배너는 변경하지 않는다.**

| 비교 항목 | 기존 `NotificationDeniedBanner` | 설정 화면 요구 |
|---|---|---|
| 상태 수 | 1 (denied 고정) | 2 (denied + notDetermined), 톤이 다름 (warning / info) |
| 동작 | 배너 전체 탭 = `openAppSettings` 고정 | denied = 설정 열기, notDetermined = **OS 권한 시트 호출 (설정 앱 아님)** — 액션이 상태마다 다름 |
| 카피 | 고정 문자열 1개 | 상태 × audience(고객/점주) 별 제목 + 본문 |
| 외곽 여백 | 내부 margin `fromLTRB(16,12,16,4)` 하드코딩 | 설정 화면 ListView gutter 20 에 맞춰야 함 (부모가 제어) |
| CTA | 암묵적 (chevron 만, 버튼 없음) | "알림 켜기"는 **권한 요청이라는 명시적 행동**이므로 눈에 보이는 버튼이 필요 |
| 비동기 | 없음 | 요청 중 CTA 로딩 상태 필요 |

승격하려면 상태 enum / 콜백 / 카피 / 외곽 margin 을 모두 파라미터화해야 해서 사실상 **다른 위젯**이 되고, 점주 주문 화면(`OwnerOrdersPage`) 의 검증 완료된 동작에 회귀 위험만 얹는다. 두 위젯은 시각 언어(`warning` 10% 배경 + `warning` 테두리 + radius 12 + 아이콘 선행)를 공유하므로 **톤 일관성은 새 위젯이 기존 스타일을 계승**하는 것으로 확보한다.
후속(선택): 설정 화면 배너가 안정되면 `OwnerOrdersPage` 의 배너를 이 위젯의 compact 변형으로 통합하는 정리 task 를 별도로 검토. 본 sub-phase 에서는 **`OwnerOrdersPage` import 및 기존 파일 이동·수정 없음**.

위치: `lib/presentation/common/notification/widgets/notification_permission_banner.dart` (공통 위젯, 외부 SDK 없음. `app_settings` 호출은 상위 page 의 콜백으로 주입 — 배너는 순수 표시 위젯으로 유지해도 되고, 직접 호출해도 선례상 허용. developer 판단).

#### 2-1. 3-state 요약

| `_osStatus` | 표시 | 톤 | CTA |
|---|---|---|---|
| `null` (조회 중) | **배너 영역 미노출 (공간도 차지하지 않음)** | — | — |
| `authorized` / `provisional` | 배너 없음 + 하단 안내(`_FootNote`) 노출 | — | — |
| `denied` | 경고 배너 | `warning` | `설정 열기` |
| `notDetermined` | 안내 배너 | `info` | `알림 켜기` |

- `_osStatus == null` 동안 레이아웃 점프를 피하기 위해 **배너 자리를 예약하지 않는다**. 대신 조회 완료 후 배너가 나타날 때 `AnimatedSize(duration: 200ms, curve: Curves.easeOut)` 로 부드럽게 밀어내리는 것을 권장 (optional, 즉시 전환도 허용).
- `getPermissionStatus()` 실패 시 배너 생략 (토글은 정상 동작).

#### 2-2. 배너 구조

```
Container(
  width: double.infinity,
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: tone.withValues(alpha: 0.10),     // tone = warning | info
    border: Border.all(color: tone),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(crossAxisAlignment: start, children: [
    Row(crossAxisAlignment: start, children: [
      Icon(...size 20, color: tone),
      SizedBox(10),
      Expanded(Column(start, [ 제목, SizedBox(4), 본문 ])),
    ]),
    SizedBox(12),
    Align(alignment: centerRight, child: CTA 버튼),
  ]),
)
```

| 요소 | 스타일 |
|---|---|
| 아이콘 | denied: `Icons.notifications_off_outlined` / notDetermined: `Icons.notifications_none_rounded`, size 20, color = tone (`warning` / `info`) |
| 제목 | fontSize 14 / w700 / `AppColors.textHeading` |
| 본문 | fontSize 12 / w400 / height 1.5 / `AppColors.textBody` |
| 외곽 margin | 없음 (부모 ListView 의 gutter 20 사용) |

**CTA 버튼 — "배너 전체 탭" 이 아니라 "별도 버튼" 으로 택일** (사유: ① `알림 켜기` 는 OS 권한 시트를 띄우는 능동적 행동이라 탭 가능 영역임이 명확해야 한다 ② 기존 배너의 chevron-only 방식은 notDetermined 에서 "설정 앱으로 가는 건가?" 라는 오해를 부른다 ③ 접근성 / 자동화에서 버튼 라벨이 곧 식별자).

| 항목 | 값 |
|---|---|
| 위젯 | `FilledButton` (또는 `ElevatedButton`, 기존 앱 `_ErrorBody` 패턴과 동일 스타일) |
| 배경 / 전경 | `AppColors.primary` / `AppColors.onPrimary` |
| 크기 | 높이 40, 좌우 padding 16, 최소 폭 96 |
| 모양 | radius 10, elevation 0 |
| 글자 | fontSize 13 / w600 |
| 로딩 (알림 켜기 요청 중) | 라벨 대신 16×16 `CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)`, 버튼 비활성 (재탭 방지) |
| 터치 영역 | 시각 높이 40 이지만 `MaterialTapTargetSize.padded` 로 **48 보장** |

> 버튼을 `warning` 색으로 칠하지 않는 이유: 라이트 팔레트에서 `warning`(amber) 배경 위 `onPrimary`(white) 대비가 부족하고, 앱 전반의 주 CTA 는 `primary` 이기 때문. 톤은 배경 틴트 / 테두리 / 아이콘만으로 전달한다.

#### 2-3. 상태별 카피 (확정)

| 상태 | audience | 제목 | 본문 | CTA |
|---|---|---|---|---|
| `denied` | 공통 | `기기 설정에서 알림이 꺼져 있어요` | `알림을 받으려면 기기 설정에서 Qradar 알림을 허용해 주세요.` | `설정 열기` |
| `notDetermined` | 고객 | `알림을 켜 보세요` | `주문 진행 상황을 바로 받아볼 수 있어요.` | `알림 켜기` |
| `notDetermined` | 점주 | `알림을 켜 보세요` | `새 주문과 환불 요청을 바로 받아볼 수 있어요.` | `알림 켜기` |

- 카피는 `NotificationPermissionDialog` 의 audience 분기 본문(`주문 진행 상황을 바로 알려드릴게요` / `새 주문과 환불 요청을 바로 알려드릴게요`) 의 의미를 계승해 앱 전체에서 같은 약속을 하도록 맞췄다.
- `denied` 의 `Qradar` 는 앱 이름이므로 영문 표기 유지.

#### 2-4. 인터랙션

| 동작 | 반응 |
|---|---|
| `알림 켜기` 탭 | CTA 로딩 → OS 권한 시트 **직접 호출 (앞단 다이얼로그 없음, 결정 D-2)**. 허용 → 토큰 등록 → 배너 소멸 (`_FootNote` 등장). 거부 → 배너가 `denied` 로 전환 (제목/본문/CTA/톤 교체; `AnimatedSwitcher` 200ms optional). 시트를 밖으로 닫아 `notDetermined` 유지 → 배너 그대로, CTA 로딩 해제 |
| `설정 열기` 탭 | `AppSettings.openAppSettings()`. 실패 시 SnackBar `설정 화면을 열 수 없어요` |
| 앱 복귀 (resumed) | `_osStatus` 재조회 → 허용으로 바뀌었으면 배너 소멸. 이때 토큰 reconcile 은 UI 표시 없이 백그라운드 수행 (사용자에게 노출할 피드백 없음) |
| 토글 영역 | 배너 상태와 무관하게 **항상 활성** (결정 D-4). 비활성 / 회색 처리 금지 |

---

### 3. 진입 타일 (U4)

#### 3-0. U4 판단 — 공통 `MoreTile` 을 이번에 추출하지 않는다. 각 페이지 기존 스타일에 맞춰 개별 구현한다

**판단: 추출하지 않음 (별 task 로 이관 권고).**

사유:
1. spec Q7 및 사용자 입장이 "MorePage 구조 정비 동반 **비권고**". 공통 위젯 추출은 두 More 페이지(및 향후 `OwnerMorePage._Tile` 의 기존 4곳 사용처) 를 함께 건드리는 리팩터링이다.
2. 점주 `OwnerMorePage` 는 이미 private `_Tile` 이 있다 — **타일 1개 추가로 끝난다.** 추출 이득이 없다.
3. 고객 `MorePage` 는 `ListTile` 패턴이 없지만, 추가 대상이 **타일 1개** 뿐이다. 추출 위젯을 만들면 `_Tile` 의 사용처 이전·삭제까지 따라와 회귀 범위가 커진다.
4. 대신 **고객 쪽에 `OwnerMorePage._Tile` 과 시각 스펙이 동일한 private 타일**을 두면, 이후 `more_page_restructure` task 에서 두 `_Tile` 을 하나의 `MoreTile`(`lib/presentation/common/`) 로 합치는 작업이 기계적 치환이 된다. 이를 위해 아래 스펙을 **`OwnerMorePage._Tile` 과 동일하게 유지**한다.

→ 후속 task `more_page_restructure` 발의를 권고 (본 sub-phase 에서는 발의만, 구현 없음).

#### 3-1. 타일 공통 스펙 (양쪽 동일, `OwnerMorePage._Tile` 기준)

| 항목 | 값 |
|---|---|
| 위젯 | `ListTile` |
| leading | `Icons.notifications_outlined`, size 22, color `AppColors.textBody` (`textDefault` 호환명 대신 신규 코드는 `textBody` 사용) |
| title | `'알림 설정'` — fontSize 15 / w600 / `AppColors.textHeading` |
| subtitle | fontSize 12 / `AppColors.textMuted` (역할별 카피 아래) |
| trailing | `Icons.chevron_right_rounded`, size 18, `AppColors.textMuted` |
| onTap | `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsPage()))` |
| 최소 높이 | ListTile 기본(부제 있음 → 72) — 터치 영역 ≥ 48 충족 |

| 역할 | 부제 |
|---|---|
| 고객 | `주문 진행 · 픽업 완료 알림을 설정해요` |
| 점주 | `신규 주문 · 환불 요청 알림을 설정해요` |

(타일 부제는 토글 이름을 그대로 요약해 진입 전에 무엇을 바꿀 수 있는지 알린다. 부제는 가운뎃점 사용 — 짧은 명사 나열이라 적합.)

#### 3-2. 위치

**점주 `OwnerMorePage`** — 리스트 **최상단** (제목 "더보기" 바로 아래, `고객 모드로 전환` 위):

```
더보기
 ▸ 알림 설정            ← 신규
 ▸ 고객 모드로 전환
 ▸ 로그아웃
 ▸ 앱 정보
```

사유: 점주에게 알림은 운영 핵심 기능(신규 주문 놓침 = 매출 손실) 이므로 모드 전환 / 로그아웃 같은 계정성 항목보다 앞에 둔다. 기존 `_Tile` 을 그대로 재사용 (신규 위젯 없음).

**고객 `MorePage`** — `UpgradeToBrandSection` 아래, 로그아웃 `TextButton` **위**:

```
더보기
[점주로 전환 카드]       (기존)
[브랜드로 전환 카드]      (기존)
SizedBox(16)             (기존)
 ▸ 알림 설정             ← 신규 (ListTile, 카드 아님)
SizedBox(8)              (신규)
        로그아웃          (기존 TextButton)
SizedBox(24)
        Qradar v0.1.0
```

- 사유: 상단 두 개의 업그레이드 프로모 카드는 "전환 유도" 성격이고, 알림 설정은 일상 설정 항목이므로 프로모 뒤·계정 액션(로그아웃) 앞의 **"설정 영역"**에 둔다. 상단에 두면 프로모 카드(그라디언트 + accent 테두리) 와 시선 경쟁이 생긴다.
- 스타일: **카드로 감싸지 않고 플랫 `ListTile`** 로 둔다 — 주변이 카드(프로모) → 텍스트 버튼(로그아웃) 으로 이미 혼재이므로 타일 1개에 또 다른 컨테이너를 도입하면 톤이 더 어긋난다. 좌우 `contentPadding: EdgeInsets.symmetric(horizontal: 20)` 으로 "더보기" 제목(left 20) 과 좌측선 정렬.
- 기존 `UpgradeToBrandSection` 의 bottom margin 이 있으므로 중복 간격이 생기면 기존 `SizedBox(16)` 하나만 유지하고 타일 아래 `SizedBox(8)` 만 추가 (developer 가 실제 렌더로 간격 확인).
- 고객 쪽 private 타일 이름은 `_NotificationSettingsTile` 등 developer 재량 (공통 추출 시 `_Tile` 로 치환 가능하도록 파라미터 시그니처는 `OwnerMorePage._Tile` 과 동일 `icon/title/subtitle/onTap` 권장).

---

## 상태별 UI

### Loading (`currentUserProfileProvider` loading)

- AppBar 는 즉시 렌더 (제목 "알림 설정" 은 role 비의존).
- 섹션 헤더 / 토글 카드 자리에 스켈레톤: `Container(height: 16, width: 72)` (헤더) + 카드형 박스 `height: 152` (행 2개 × 72 + 구분선 1 + 여유), `AppColors.surface`, radius 16. 기존 `_shimmerBox` 와 동일한 정적 박스 (애니메이션 optional).
- role 이 아직 모르므로 헤더 텍스트는 스켈레톤으로 대체 (잘못된 라벨 깜빡임 방지).
- OS 권한 상태 조회 중(`_osStatus == null`): 배너 영역 미노출 (§2-1).

### Error (프로필 조회 실패)

기존 `_ErrorBody` 패턴 그대로 (본문 중앙):
- 아이콘 `Icons.error_outline_rounded` size 48 `AppColors.error`
- 메시지 `'설정을 불러오지 못했어요'` fontSize 14 `AppColors.textMuted` (원시 예외 문자열 노출 금지)
- 버튼 `다시 시도` (`primary` / `onPrimary`, radius 10) → `ref.invalidate(currentUserProfileProvider)`

### 토글 저장 중 / 실패 (U2, F19, F20)

| 구간 | 시각 |
|---|---|
| 저장 중 (in-flight) | **시각 변화 없음.** optimistic 으로 스위치가 즉시 새 값으로 이동. 해당 카테고리의 추가 탭은 내부 `_saving` 집합으로 **무시** (Switch 를 `onChanged: null` 로 바꾸면 회색 flicker 가 생기므로 사용하지 않는다 — 콜백 내부 early return) |
| 저장 성공 | 변화 없음 (stream 이 같은 값 emit) |
| 저장 실패 | 스위치가 **이전 값으로 롤백** + SnackBar |

저장 실패 SnackBar:
- 카피: `'설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'`
- `behavior: SnackBarBehavior.floating`, backgroundColor `AppColors.error`, 텍스트 `AppColors.onPrimary` 13/w500, duration 3s
- 사유: Firestore 쓰기는 로컬 캐시에 즉시 반영되어 정상 경로에서 지연이 거의 없으므로 스피너 / 비활성 표시는 오히려 노이즈. 전체 화면 에러로 전환하지 않는다.

### Empty

해당 없음 (토글은 역할별 고정 2개).

### Unauthenticated

`uid == null` → 빈 화면 방지 위해 early return + pop (방어, 별도 UI 없음).

### 상태 매트릭스 (OS 권한 × 화면)

| OS 권한 | 배너 | 토글 | 하단 안내 |
|---|---|---|---|
| 조회 중 (null) | 없음 | 활성 | 없음 |
| authorized / provisional | 없음 | 활성 | 노출 |
| denied | 경고 배너 + `설정 열기` | **활성** | 없음 |
| notDetermined | 안내 배너 + `알림 켜기` | **활성** | 없음 |

---

## 접근성 (Semantics)

| 대상 | 요구 |
|---|---|
| 토글 행 | `SwitchListTile` 의 병합 semantics 사용 → 스크린리더가 `"주문 진행 알림, 접수, 조리 시작, 픽업 준비 소식을 알려드려요, 스위치, 켜짐"` 으로 읽는다. 제목은 반드시 고유(중복 금지)한 한국어 라벨. 기본 라벨이 병합되어 의도대로 안 읽히면 `Semantics(label: '<제목>', hint: '<부연설명>', toggled: value)` 로 감싸고 내부 텍스트는 `ExcludeSemantics` |
| 자동화 식별자 (idb 등) | 라벨이 명확하므로 라벨 기반 탐색이 1순위. 추가로 Flutter 지원 시 `Semantics(identifier: 'notification_toggle_<key>')` 부여 권장 (예: `notification_toggle_orderProgress`, `notification_toggle_pickupComplete`, `notification_toggle_newOrder`, `notification_toggle_refundRequest`) |
| 배너 | 배너 컨테이너는 `Semantics(container: true, liveRegion: true)` 로 상태 변화(denied ↔ notDetermined ↔ 소멸) 를 스크린리더에 통지. CTA 버튼은 라벨(`알림 켜기` / `설정 열기`) 이 곧 접근성 이름. 로딩 중 `Semantics(label: '알림 권한을 요청하는 중')` |
| 진입 타일 | `ListTile` 기본 semantics (title + subtitle + 버튼 역할) |
| 터치 영역 | 토글 행 전체 ≥ 72(부제 1줄)/자동 확장, 배너 CTA 48 (padded), 진입 타일 ≥ 56 — 모두 ≥ 48 충족 |
| 대비 | `textMuted` 12pt 부제는 라이트 팔레트 흰 카드 위 대비 약 4.8:1 (WCAG AA 충족). 배너 본문은 `textBody` 사용 |

---

## 다크 / 라이트 토큰 매핑

색상은 전부 `AppColors` 토큰. 활성 팔레트(라이트 `LightMidnightAccentPalette` / 다크 팔레트) 전환 시 자동 추종하며 HEX 직접 지정 없음.

| 용도 | 토큰 |
|---|---|
| 화면 배경 / AppBar 배경 | `AppColors.background` |
| AppBar 제목 / 뒤로 아이콘 | `AppColors.textHeading` |
| 섹션 헤더 | `AppColors.textMuted` |
| 토글 카드 배경 | `AppColors.surfaceElevated` |
| 토글 카드 테두리 / 행 구분선 | `AppColors.border` |
| 토글 제목 | `AppColors.textHeading` |
| 토글 부연 설명 | `AppColors.textMuted` |
| Switch ON 트랙 / 썸 | `AppColors.primary` / `AppColors.onPrimary` |
| Switch OFF 트랙 / 썸 / 외곽선 | `AppColors.surface` / `AppColors.textMuted` / `AppColors.border` |
| Switch ripple | `AppColors.primary` (alpha 0.08) |
| 배너 (denied) 배경 / 테두리 / 아이콘 | `AppColors.warning` (alpha 0.10) / `AppColors.warning` / `AppColors.warning` |
| 배너 (notDetermined) 배경 / 테두리 / 아이콘 | `AppColors.info` (alpha 0.10) / `AppColors.info` / `AppColors.info` |
| 배너 제목 / 본문 | `AppColors.textHeading` / `AppColors.textBody` |
| 배너 CTA 배경 / 글자·로딩 | `AppColors.primary` / `AppColors.onPrimary` |
| 하단 안내 | `AppColors.textMuted` |
| 스켈레톤 | `AppColors.surface` |
| 에러 아이콘 / 저장 실패 SnackBar 배경 | `AppColors.error` |
| SnackBar 글자 | `AppColors.onPrimary` |
| 진입 타일 아이콘 / 제목 / 부제 / chevron | `AppColors.textBody` / `AppColors.textHeading` / `AppColors.textMuted` / `AppColors.textMuted` |

금지: `Color(0x...)`, `Colors.white` / `Colors.black` / `Colors.red.shadeXXX` 직접 사용. (기존 `OwnerMorePage` 의 `Colors.red.shade600` SnackBar 는 선례일 뿐 따르지 않는다.)
`withValues(alpha:)` 로 `AppColors` 토큰에 투명도를 주는 것은 허용 (기존 배너 / 다이얼로그 선례).

---

## 간격 / 타이포 요약

| 요소 | 값 |
|---|---|
| 화면 좌우 gutter | 20 |
| 배너 ↔ 섹션 헤더 | 20 |
| 섹션 헤더 ↔ 카드 | 8 |
| 카드 ↔ 하단 안내 | 12 |
| 하단 여백 | 32 |
| 카드 radius / 배너 radius / 버튼 radius | 16 / 12 / 10 |
| 행 내부 padding | h16 / v6 (+ ListTile 기본 vertical) |
| 폰트 | AppBar 17/w700 · 섹션 헤더 13/w600 · 토글 제목 15/w600 · 부연 12/w400 · 배너 제목 14/w700 · 배너 본문 12 · CTA 13/w600 · 하단 안내 12 |

---

## 알림 카피 확정

### U5. 신규 `order_completed` 알림 (확정)

| 전이 | FCM type | 제목 | 본문 | 게이트 키 |
|---|---|---|---|---|
| `ready -> completed` | `order_completed` | `픽업이 완료됐어요` | `{storeName}에서 받은 음료, 맛있게 즐겨주세요.` | `pickupComplete` |

검수 결과 (spec 잠정안 `{storeName} 주문이 완료됐어요. 맛있게 즐겨주세요.` 에서 **본문만 조정**):
- 제목 `픽업이 완료됐어요`(9자) 와 본문이 "완료됐어요" 를 반복하면 알림 배너에서 같은 말이 두 번 보인다 → 본문은 **행동 이후의 따뜻한 마무리**로 전환.
- 본문에서 `주문이 완료됐어요` 는 "결제/접수 완료" 로 오독될 여지가 있어 회피. 음료를 받은 시점이므로 `받은 음료` 가 맥락상 정확 (기존 3건 본문도 `음료` 어휘 사용).
- `{storeName}에서` **붙여쓰기** — sub-phase 2 확정 규칙 유지.
- 길이: 본문 storeName 20자 가정 시 약 38자 (FCM 권장 60자 이내), 제목 30자 이내 충족. 이모지 / 느낌표 없음, 반높임체 유지 — sub-phase 2 결정 D 톤 정합.
- 옵트인 알림이므로 사용자가 직접 켠 알림이라는 전제로 확인형 문구("도착했어요" 등 정보 고지)보다 마무리 인사형이 적합.

CF 구현 참고 (`NOTIFICATION_MATRIX`): title `'픽업이 완료됐어요'`, body `` `${n}에서 받은 음료, 맛있게 즐겨주세요.` ``

### U6. `NotificationPermissionDialog` 카피 재검수 — **변경 없음**

현 코드의 audience 분기 카피(고객: `주문 진행 상황을 바로 알려드릴게요.` / `조리 시작과 픽업 준비 알림을 받아볼 수 있어요.`, 점주: `새 주문과 환불 요청을 바로 알려드릴게요.` / `매장을 떠나 있어도 놓치지 않아요.`) 는 라이브 검증 PASS 이며 본 sub-phase 설정 화면의 `orderProgress`(접수·조리·준비) / `newOrder`·`refundRequest` 토글 범위와 모순이 없고, §2-3 배너 카피와 약속 내용이 일치한다. 고객 2차 본문이 `조리 시작과 픽업 준비` 만 언급하는 점은 설정 토글 부연(`접수, 조리 시작, 픽업 준비`) 의 부분집합이라 충돌하지 않으므로 수정 사유 없음. 다이얼로그 위젯 코드 변경 불필요.

---

## 개발자 전달 특이사항

### 신규 / 수정 위젯

| 위젯 | 위치 | 비고 |
|---|---|---|
| `NotificationSettingsPage` | `lib/presentation/common/notification/notification_settings_page.dart` | spec F12 |
| `NotificationPermissionBanner` | `lib/presentation/common/notification/widgets/notification_permission_banner.dart` | **신규** (U3 판단). 입력: `status`(denied / notDetermined), `audience`, `isRequesting`, `onPrimaryTap` |
| `_SettingToggleTile` / `_SettingsToggleCard` | 같은 page 파일 private 또는 `widgets/` | `SwitchListTile` 기반 |
| 고객 진입 타일 | `lib/presentation/customer/more/more_page.dart` 내부 private | `OwnerMorePage._Tile` 과 동일 시그니처·스펙 (U4) |
| 점주 진입 타일 | `lib/presentation/owner/more/owner_more_page.dart` | 기존 `_Tile` 재사용, 리스트 최상단에 추가 |

### 재사용 (신규 작성 금지)

- `NotificationDeniedBanner` — **그대로 둠**. `OwnerOrdersPage` 변경 없음, 파일 이동 없음.
- `currentUserProfileProvider` (토글 상태 stream), `pushNotificationRepositoryProvider.getPermissionStatus()`, `RequestNotificationPermissionUseCase`, `RegisterFcmTokenUseCase`, `app_settings` (spec 에 명시)
- 에러 바디: `order_detail_page.dart` 의 `_ErrorBody` 와 동일 스타일 (private 이므로 복제하거나 설정 화면 내 소형 private 으로 구현)

### 구현 시 주의

1. Switch 색 5개 속성 + `trackOutlineColor` 를 `WidgetStateProperty` 로 지정. `activeThumbColor` 는 Flutter 3.31+ 명칭 (프로젝트 선례 `store_operation_form_page.dart` 와 동일 계열 사용).
2. 토글 `onChanged` 에서 `_saving.contains(category)` 면 return (Switch 를 null 로 만들지 않음).
3. 배너 CTA 의 로딩은 page local state(`_requestingPermission`) 로 관리, 요청 완료/실패/취소 모든 경로에서 `finally` 로 해제.
4. 배너 ↔ 하단 안내 노출은 상호 배타 (§상태 매트릭스).
5. `brand` / `admin` role 은 고객 토글·고객 카피 사용 (배너 audience 도 customer).
6. `Semantics(identifier:)` 는 Flutter 버전 지원 확인 후 적용; 미지원이면 라벨만으로 충분.
7. SnackBar 배경은 `AppColors.error` (하드코딩 Colors.red 금지).
8. CF 카피(`order_completed`) 는 §U5 의 확정 문구를 사용. `NotificationType.orderCompleted` 라우팅은 spec F23/F24 따름 (UI 변경 없음).

### 기존 디자인 대비 변경사항

| 항목 | 기존 | 본 sub-phase |
|---|---|---|
| 알림 설정 화면 | 없음 (권한 sticky 로 재요청 불가) | `NotificationSettingsPage` 신규 (역할별 토글 2개 + OS 권한 3-state 배너) |
| 고객 MorePage | 프로모 카드 2 + 로그아웃 + 버전 | 로그아웃 위에 플랫 `알림 설정` ListTile 1개 추가 (구조 정비 없음) |
| 점주 OwnerMorePage | 전환 / 로그아웃 / 앱 정보 `_Tile` 3개 | `알림 설정` `_Tile` 최상단 추가 |
| OS 권한 거부 배너 | 점주 주문 화면 전용 `NotificationDeniedBanner` | 변경 없음 + 설정 화면 전용 `NotificationPermissionBanner` 별도 신규 (2-state, 명시 CTA) |
| 픽업 완료 알림 카피 | 없음 (미발화) | `픽업이 완료됐어요` / `{storeName}에서 받은 음료, 맛있게 즐겨주세요.` (옵트인) |
| 권한 다이얼로그 카피 | audience 분기 | **변경 없음** |

---

## 사용자 추가 확인 필요 항목

필수 확인 사항은 없다 (Q1~Q5 확정 범위 내). 아래는 사용자 선호에 따라 바꿀 수 있는 **권고 판단**이며, 이견이 없으면 그대로 진행한다.

| # | 항목 | designer 결정 | 대안 |
|---|---|---|---|
| 1 | U3: 배너를 승격하지 않고 신규 작성 | 신규 `NotificationPermissionBanner` (기존 점주 배너 무변경) | 기존 배너를 파라미터화해 승격 (회귀 위험 감수) |
| 2 | U4: 공통 `MoreTile` 미추출, 후속 `more_page_restructure` 발의 권고 | 개별 구현 (시각 스펙 동일 유지) | 이번에 추출 (범위 확대, 사용자 비권고 입장과 상충) |
| 3 | 점주 More 에서 `알림 설정` 을 최상단에 배치 | 최상단 | `고객 모드로 전환` 아래 |
| 4 | `order_completed` 본문 카피 | `{storeName}에서 받은 음료, 맛있게 즐겨주세요.` | spec 잠정안 `{storeName} 주문이 완료됐어요. 맛있게 즐겨주세요.` |
