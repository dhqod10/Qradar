# support_inquiry — 디자인 명세 (고객센터 문의 게시판, 앱)

> 범위: 고객 앱 3화면 + 진입점 2곳 + 다중 첨부 picker. 웹/관리자 콘솔 UI 는 비범위.
> 원칙: **신규 컴포넌트는 첨부 picker 하나**. 나머지는 기존 리스트/폼/상세/배지 패턴 재사용.
> 색상은 전부 `AppColors` 토큰. `Color(0x...)` / `Colors.white` / `Colors.black` 금지.
> 확정값(2026-11-24): 첨부 3장·5MB·자동 리사이즈·**갤러리+카메라** / 답변 1회 / 수정·삭제 불허·철회만 / 더보기 미확인 dot / 타일 공통 승격 없음 / status 4종 `open·answered·closed·withdrawn`.

---

## 0. 참조

- 기존 화면: `more_page.dart`(`_NotificationSettingsTile`), `order_detail_page.dart`(섹션 카드, `_ActionSection`), `store_review_form_page.dart`(폼), `account_deletion/design.md`(파괴적 확인 톤), `account_suspended_view.dart`(안내 카드 톤)
- 기존 컴포넌트: `approval_status_badge.dart`(pill 배지 구조), `image_upload_field.dart`(시각 언어), `error_dialog.dart`
- Figma: 없음 (기존 패턴 기반)
- 용어: 화면/문구에서 **"Log" 는 쓰지 않는다** (Log = 주문 내역). 문의 쪽은 "문의 / 고객센터 / 답변" 으로만 표기. "Qoin" 은 유형 라벨에서만 등장.

---

## 1. 공통 토큰·스타일 요약

| 항목 | 값 |
|---|---|
| 화면 배경 | `AppColors.background` |
| 카드 | `surfaceElevated` + border `AppColors.border` 1px + radius 16 + padding 16 (주문 상세 섹션 카드와 동일) |
| 화면 좌우 패딩 | 20 (더보기·목록) / 폼·상세는 16~20 중 **20 으로 통일** |
| 제목 텍스트 | 16 w700 `textHeading` |
| 본문 | 14 w400 height 1.5 `textBody` |
| 캡션 | 12 `textMuted` |
| 터치 영역 | 최소 44x44 |
| 로딩 인디케이터 | `AppColors.primary` |

### 1-1. 상태 배지 4종 (`SupportInquiryStatusBadge`)

`ApprovalStatusBadge` 와 **동일 구조** 재사용: pill(radius 999), 높이 24, 가로 패딩 10, 좌측 dot 8px + 라벨 12 w600, `bg = 색.withValues(alpha: 0.15)`, dot·라벨 = 해당 색. 신규 색 정의 없음. `large` 변형(높이 32)은 상세 상단에서만 사용.

| status | 라벨 | dot / 라벨 색 | 배경 | 의미·근거 |
|---|---|---|---|---|
| `open` | 접수 | `AppColors.info` | `info` alpha 0.15 | 진행 중(답변 대기). 경고(노랑)로 하면 "문제 있음" 으로 읽혀 중립 정보색 선택 |
| `answered` | 답변 완료 | `AppColors.success` | `success` alpha 0.15 | 고객이 기다리던 결과. 가장 눈에 띄는 톤 |
| `closed` | 종결 | `AppColors.textMuted` | `AppColors.surface` | 처리 끝, 더는 액션 없음. 중립 회색 |
| `withdrawn` | 철회 | `AppColors.textMuted` | 투명 + border `AppColors.border` 1px | 고객 스스로 거둔 것. closed 보다 한 단계 더 약하게(채움 없음) |

- 모르는 status 는 `closed` 로 렌더(spec 규칙, 액션 노출 금지).
- 색만으로 구분하지 않는다: 라벨 텍스트가 항상 함께 있다.

### 1-2. 유형(category) 라벨

칩/목록/상세 모두 동일 문자열. 순서 고정.

| enum | 라벨 | 아이콘(목록 타일에서는 미사용, 칩에도 미사용 — 텍스트만) |
|---|---|---|
| `order` | 주문 | |
| `refund` | 환불 | |
| `qoin` | Qoin | |
| `account` | 계정 | |
| `store` | 매장 | |
| `bug` | 앱 오류 | |
| `etc` | 기타 | |

모르는 값 → `기타`.

### 1-3. 미확인 답변 정의 (dot 의 단일 기준)

`unread = status ∈ {answered, closed} && answer != null && answerReadAt == null` (`withdrawn` 제외).
**closed 를 포함하는 이유(D1):** 관리자가 답변 후 곧바로 종결하면 고객이 읽기 전에 `closed` 가 될 수 있다. 1차에 FCM 푸시가 없어 dot 이 답변 도착을 아는 **유일한 경로**이므로, `answered` 로만 한정하면 고객이 답변을 영영 모른다. 읽음 처리(Rules C2)도 같은 이유로 `answered`·`closed` 양쪽에서 허용한다.
목록 타일 · 더보기 타일 · 상세 진입 시 읽음 처리가 모두 이 정의를 쓴다.

---

## 2. 진입점 ① 더보기 "고객센터" 타일 (`more_page.dart`)

### 2-1. 위치·구조

- `_NotificationSettingsTile` → `_MoreTile` rename(Q9). 시각 스펙은 **현행 그대로**: `ListTile`, `contentPadding horizontal 20`, leading icon 22 `textBody`, title 15 w600 `textHeading`, subtitle 12 `textMuted`, trailing chevron 18 `textMuted`.
- 알림 설정 타일 **직후**, 기존 `SizedBox(height: 8)`(로그아웃 앞) **앞**에 배치. 두 타일 사이 간격 0 (ListTile 끼리 붙임, 기존 흐름과 동일).
- 타일 값: icon `Icons.support_agent_outlined`, title `고객센터`, subtitle `문의하고 답변을 확인해요`, onTap → `SupportInquiryListPage` push (`MaterialPageRoute`).

### 2-2. 미확인 답변 dot

| 상태 | leading | subtitle |
|---|---|---|
| 미확인 0건 | 아이콘만 | `문의하고 답변을 확인해요` (`textMuted`) |
| 미확인 ≥1건 | 아이콘 우상단에 **dot** | `새 답변이 도착했어요` 12 **w600 `AppColors.primaryBright`** |

- dot: 지름 8, 색 `AppColors.error`, 아이콘 박스(22x22) 기준 우상단 offset(-2, -2)에 `Stack` + `Positioned`. 아이콘과 분리되도록 `surfaceElevated`가 아닌 **`AppColors.background` 색 1.5px 외곽선**(BoxDecoration border) 을 준다.
- 개수 숫자는 표시하지 않는다(dot 만). 1차에서 숫자 배지는 과잉.
- dot 은 **텍스트 변경과 항상 짝**이다(색에만 의존 금지, 스크린리더 `Semantics(label: '고객센터, 새 답변이 도착했어요')`).
- 파생 provider `unreadInquiryAnswerCountProvider` 의 loading/error 에서는 **dot 없음 + 기본 subtitle** (실패가 타일을 깨뜨리지 않는다. fail-quiet).
- 스트림 기반이므로 목록 화면에서 답변 읽음 처리 시 더보기로 돌아오면 자동 소거.

---

## 3. 진입점 ② 주문 상세 "이 주문 문의하기" (`order_detail_page.dart`)

### 3-1. 배치

현재:
```
_PaymentInfoSection → SizedBox(24) → _ActionSection → SizedBox(32)
```
변경:
```
_PaymentInfoSection → SizedBox(24) → _ActionSection
  → SizedBox(16) → _OrderInquiryBlock → SizedBox(32)
```
- `_ActionSection` 의 `switch` 는 **수정하지 않는다.** 새 위젯 `_OrderInquiryBlock` 을 같은 파일 하단에 private 으로 추가(상태 무관, **모든 order.status 에서 노출**).
- `completed`/`cancelled`/`refunded` 에서 `_ActionSection` 이 빈 위젯이면 24+16 으로 간격이 다소 커질 수 있다. **허용**(분기 건드리지 않기 위함). 어색하면 developer 가 16 만 조정.

### 3-2. 블록 외형

- 카드(§1) 전체가 하나의 탭 영역 (`InkWell`, radius 16). 한 줄 `Row`:
  - leading: `Icons.help_outline_rounded` 22 `textBody`
  - 중앙(Expanded): title `이 주문에 문제가 있나요?` 14 w600 `textHeading` / sub `이 주문으로 문의를 남겨 주세요` 12 `textMuted`
  - trailing: `Icons.chevron_right_rounded` 18 `textMuted`
- 주문 취소/환불 CTA(`OutlinedButton`, error 톤)와 시각적으로 경쟁하지 않도록 **버튼이 아닌 낮은 강조의 카드 행**으로 한다.
- 탭 → `SupportInquiryFormPage(presetOrderId: order.id)` push.
- `isActionLoading`(취소 등 처리 중) 일 때는 **탭 비활성**이 아니라 그대로 허용 (문의는 주문 처리와 무관).

---

## 4. 화면 1 — 문의 목록 (`SupportInquiryListPage`)

### 4-1. 레이아웃

- `Scaffold` 배경 `background`, AppBar 제목 `고객센터` (기존 서브 페이지 AppBar 스타일 그대로, 뒤로가기 기본).
- Body: `RefreshIndicator`(color `primary`) + `ListView`(padding `fromLTRB(20, 12, 20, 96)` — 하단 96 은 FAB 가림 방지).
- FAB: **extended FAB** `문의하기` + `Icons.edit_outlined`, 배경 `primary`, 전경 `onPrimary`, 하단 우측 기본 위치. 탭 → `SupportInquiryFormPage()`.
- 목록 맨 위 안내(한 줄 캡션, 카드 아님): `답변은 이 화면에서 확인할 수 있어요` 12 `textMuted`, 하단 gap 12. (1차에 푸시가 없음을 사용자에게 알리는 최소 안내.)
- 목록 맨 아래 푸터 캡션(가운데): `급한 문의는 {kSupportContact} 로 연락해 주세요` 12 `textMuted`. `kSupportContact` 상수 사용(Q7: 게시판이 외부 연락처를 대체하지 않는다). 항목 간 gap 아래 24.
- 목록이 정확히 50건이면 푸터에 추가 줄 `최근 50건까지 표시돼요` 12 `textMuted`.

### 4-2. 목록 타일 (`SupportInquiryTile`)

카드(§1, padding 16), 탭 → 상세. 카드 사이 gap 12.

```
Row[ category 라벨 (12 w600 textMuted) · 작성일 (12 textMuted)        StatusBadge ]
gap 8
Row[ (unread dot 8, gap 6) Expanded( 제목 15 w600/w700 textHeading, maxLines 1, ellipsis ) ]
gap 4
본문 미리보기 13 textBody maxLines 1 ellipsis  (본문 첫 줄)
```
- 작성일 형식: 기존 앱 날짜 포맷 유지(`yyyy.MM.dd`), 오늘은 `HH:mm` 은 쓰지 않음(단순화).
- **미확인 답변 타일**: 제목 앞 dot(`AppColors.error` 8px) + 제목 **w700**, 카드 border `AppColors.primaryBright` alpha 0.5 (일반은 `border`). 배지는 `답변 완료`. → 목록에서도 "새 답변" 이 한눈에 보인다.
- `withdrawn` / `closed`: 제목·본문 색을 `textMuted` 로 낮춤(처리 끝난 건의 시각 무게 감소).
- 주문 연결 문의: 카테고리 줄 끝에 `· 주문 #{pickupNumber}` 로 이어 붙이지 않는다(복잡). 상세에서만 노출.

### 4-3. 상태 UI

| 상태 | 구성 |
|---|---|
| **loading** | 타일 스켈레톤 4개: 카드 외형 유지, 내부 3줄 막대(`AppColors.surface` base → `surfaceElevated` highlight shimmer, 높이 12/16/12, 폭 40%/70%/90%). 기존 shimmer 컴포넌트가 있으면 재사용 |
| **empty** | 중앙 정렬 Column: 아이콘 `Icons.forum_outlined` 48 `textMuted` / `아직 문의가 없어요` 16 w700 `textBody` / `궁금한 점이나 불편한 점을 남겨 주세요` 13 `textMuted` / gap 20 / 채움 버튼 `문의하기`(h48, radius 12, `primary`/`onPrimary`, 폭 160). 이때 FAB 은 **숨긴다**(CTA 중복 방지) |
| **error** | 중앙 Column: `Icons.error_outline_rounded` 48 `error` / `문의 내역을 불러오지 못했어요` 16 w700 `textHeading` / `잠시 후 다시 시도해 주세요` 13 `textMuted` / `다시 시도` 버튼(`primary`/`onPrimary`, ref.invalidate). 서버 raw message 노출 금지 |
| **data** | 위 리스트 + FAB |

- Pull-to-refresh 는 스트림이라 실질 효과가 없지만 error 상태 복구용으로 유지해도 무방(필수 아님).

---

## 5. 화면 2 — 문의 작성 (`SupportInquiryFormPage({String? presetOrderId})`)

### 5-1. 레이아웃

- AppBar 제목 `문의하기`. 닫기 = 뒤로가기.
- Body: `SingleChildScrollView`(keyboardDismissBehavior onDrag) padding `fromLTRB(20, 16, 20, 24)`, 하단 고정 CTA 영역은 `bottomNavigationBar`(SafeArea + padding 20/12/20/12 + 상단 `border` 1px 구분선, 키보드 올라오면 `viewInsets` 만큼 따라 올라가는 기존 폼 방식 준수).
- 섹션 간 gap 24. 각 섹션 라벨: 14 w700 `textHeading`, 필수는 라벨 뒤 ` *` (`AppColors.error`).

### 5-2. 섹션 순서

1. **안내 배너** (카드 아님, 가벼운 박스)
   - 배경 `AppColors.surface`, radius 12, padding 12, 좌측 `Icons.info_outline_rounded` 16 `textMuted`.
   - 문구 12 `textBody`: `제출한 문의는 수정하거나 삭제할 수 없어요. 답변이 등록되기 전에는 철회할 수 있어요.\n카드 번호·비밀번호 같은 민감한 정보는 적지 마세요.`
2. **유형 \*** — `Wrap(spacing 8, runSpacing 8)` 칩 7개(§1-2 순서). 단일 선택. 칩 스펙: 디자인 가이드 칩 그대로 — 선택 `primary`/`onPrimary` 무 border, 비선택 `surfaceElevated` + border + `textBody`, pill, 높이 36, 가로 패딩 14, 13 w600. 기본 선택 없음(필수 인지). `presetOrderId` 가 있으면 **기본 `주문` 선택**(수정 가능).
3. **관련 주문** (선택) — §5-3
4. **제목 \*** — `TextField` 한 줄, maxLength 60 (내장 카운터 대신 우측 하단 `n/60` 캡션 12 `textMuted`, 초과 입력 불가). hint `제목을 입력해 주세요` (`textMuted`).
5. **내용 \*** — 멀티라인 minLines 6 / maxLines 10, maxLength 2000, 카운터 `n/2000`. hint `어떤 점이 궁금하거나 불편하셨는지 자세히 적어 주세요`.
6. **사진 첨부 (선택)** — §6 picker. 라벨 우측에 `0/3` 캡션.

- 입력창 스타일: 가이드 입력창 규칙(배경 `surfaceElevated`, border `border`, 포커스 border `primary`, cursor `primary`, radius 12, contentPadding 14).
- 필드 에러(서버 `[SUPPORT_INVALID_INPUT]`): 해당 필드 border `error` + 하단 12 `error` 문구.

### 5-3. 관련 주문 행 (`SupportInquiryOrderSummary` + picker sheet)

- 미선택: 입력창 외형의 탭 행 — `Icons.receipt_long_outlined` 20 `textMuted` / `관련 주문 선택 (선택사항)` 14 `textMuted` / chevron. 탭 → `SupportInquiryOrderPickerSheet`(바텀시트).
- 선택됨(또는 preset): 같은 외형, 내용 = 매장명 14 w600 `textHeading` + `#{pickupNumber} · {금액}원 · {주문일}` 12 `textMuted`, trailing `Icons.close_rounded` 18(44 터치영역) 으로 **연결 해제**. preset 도 해제 가능(실수로 들어온 경우 대비).
- 바텀시트: radius 상단 20, 핸들, 제목 `문의할 주문 선택` 16 w700, 최근 주문 리스트(최대 10건; 행 = 위 선택됨 외형 + 우측 라디오). 선택 즉시 닫힘. 하단 `연결 안 함` 텍스트 버튼.
  - loading: 행 스켈레톤 3개 / empty: `최근 주문이 없어요` 13 `textMuted` / error: `주문을 불러오지 못했어요` + `다시 시도`.
- 문구에 "Log" 는 쓰지 않는다 (`최근 주문`).

### 5-4. 제출 CTA (하단 고정)

- 풀폭 `h52 / radius 12` 채움 버튼 `문의 접수하기`, `primary`/`onPrimary`.
- 활성 조건: 유형 선택 + 제목 trim ≥1 + 내용 trim ≥1 + 제출·업로드 중 아님. 비활성은 `AppColors.surface` 배경 + `textMuted` 라벨(디자인 가이드 비활성 규칙).
- 제출 중 라벨/상태:
  - 이미지 업로드 중: `사진 업로드 중 (2/3)` + 좌측 16 스피너(`onPrimary`) — 버튼 비활성
  - 서버 전송 중: `접수하는 중…` + 스피너
- **중복 탭 차단**: 제출 시작 즉시 버튼 비활성(spec Q8 클라이언트 처리의 전부). 쿨다운 타이머 없음.
- 제출 중: 폼 전체 `AbsorbPointer` + `PopScope(canPop: false)`(업로드 도중 이탈 방지). 키보드 내림.

### 5-5. 이탈 확인

- 입력이 하나라도 있거나(유형/제목/내용/첨부/주문 변경) 제출 중이 아닐 때 뒤로가기 → 확인 다이얼로그:
  제목 `작성을 취소할까요?` / 본문 `작성 중인 내용이 사라져요.` / `계속 작성`(기본) · `나가기`(`error` 텍스트).
- preset 만 있고 사용자 입력이 없으면 확인 없이 닫는다.

### 5-6. 제출 결과

| 결과 | 처리 |
|---|---|
| 성공 | 폼을 닫고 **상세 화면으로 `pushReplacement`**(inquiryId 는 사전 생성값). 상세 진입 직후 SnackBar `문의가 접수됐어요`. 뒤로가기 시 진입 출처(목록/주문 상세)로 복귀 |
| `[SUPPORT_RATE_LIMITED]` | 버튼 **위**에 인라인 경고 박스(배경 `warning` alpha 0.12, border `warning` alpha 0.4, radius 12, padding 12, 아이콘 `Icons.schedule_rounded` `warning`, 문구 13 `textBody`): `문의를 너무 자주 보냈어요. 잠시 후 다시 시도해 주세요.` 입력·첨부는 **유지**. 박스는 다음 제출 시도 또는 입력 변경 시 사라짐. 분당/일 한도 구분 문구·남은 시간 노출 없음 |
| 이미지 업로드 실패 | §6-5 |
| `[SUPPORT_INVALID_ATTACHMENT]` | SnackBar `첨부를 다시 선택해 주세요` + 첨부 전체 초기화 |
| `[SUPPORT_ORDER_NOT_FOUND]` | 관련 주문 행 하단 12 `error`: `주문 정보를 확인할 수 없어요` + 연결 해제 |
| 네트워크/unavailable | 버튼 위 에러 박스(`error` alpha 0.1 계열, 동일 구조): `네트워크 상태를 확인하고 다시 시도해 주세요.` 재탭 = 재시도(멱등) |
| `[SUPPORT_ACCOUNT_DELETED]` / 세션 만료 | 기존 인증 만료 경로(로그인 화면 유도) |
| 그 외 | `문의를 접수하지 못했어요. 잠시 후 다시 시도해 주세요.` (raw message 금지) |

---

## 6. 신규 컴포넌트 — 다중 첨부 picker (`SupportInquiryAttachmentPicker`)

### 6-1. 구조

> 소스는 **사진 보관함 + 카메라** 두 가지(2026-11-24 확정).

`ImageUploadField` 의 시각 언어(radius, `surface` placeholder, 아이콘, 에러 메시지 위치)를 잇되 **3칸 고정 그리드**.

```
Row (spacing 8)  ── 3 슬롯, 각 Expanded + AspectRatio(1) ──
[ 슬롯1 ][ 슬롯2 ][ 슬롯3 ]
캡션/에러 한 줄 (12)
```
- 슬롯 radius 12. 선택된 이미지 슬롯은 항상 **앞에서부터 채움**(삭제 시 뒤가 앞으로 당겨짐).
- 빈 슬롯은 **그리지 않는다**: `추가 타일 1개 + 채워진 타일들` 만 보인다(남은 칸은 투명). 3장 도달 시 추가 타일이 사라지고 3칸이 모두 이미지.
- 폭이 3등분이라 소형 기기에서도 한 줄 유지(`LayoutBuilder` 불필요).

### 6-2. 추가 타일 + 선택 시트

- 배경 `AppColors.surface`, border `AppColors.border` 1px, radius 12.
- 중앙: `Icons.add_photo_alternate_outlined` 24 `textMuted` + 아래 `n/3` 12 w600 `textMuted` (gap 4).
- 제출/업로드 중 비활성(탭 무반응, 투명도 0.5).
- 탭 → **선택 시트**(`showModalBottomSheet`, 상단 radius 20, 배경 `surfaceElevated`, 핸들, padding 상하 8):
  - 제목 `사진 추가` 16 w700 `textHeading` (padding 20/12)
  - 행 1: `Icons.photo_library_outlined` 22 `textBody` / `사진 보관함` 15 w600 `textHeading` — 보조 `최대 {남은 장수}장까지 선택할 수 있어요` 12 `textMuted`
  - 행 2: `Icons.photo_camera_outlined` 22 `textBody` / `카메라로 촬영` 15 w600 `textHeading` — 보조 `촬영한 사진을 바로 첨부해요` 12 `textMuted`
  - 각 행 `ListTile`(높이 56, 터치 영역 44+), 구분선 없음. 하단 `취소` 행 없음(바깥 탭/스와이프로 닫힘).
  - 행 탭 → 시트 닫고 해당 소스 실행.
- 보관함: `ImagePicker.pickMultiImage(limit: 남은 장수, maxWidth: 1600, imageQuality: 85)`.
- 카메라: `ImagePicker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85)` — **1회 1장**. 촬영 후 다시 추가하려면 추가 타일을 한 번 더 탭(연속 촬영 모드 없음).
- **촬영 결과도 보관함 선택과 동일한 규칙**: 3장 상한(남은 장수 0 이면 시트 자체가 열리지 않으므로 추가 타일이 이미 없음), 장당 5MB 검사, `maxWidth 1600 / imageQuality 85` 자동 리사이즈, 앞에서부터 채움, 개별 삭제·진행률·실패 표시가 완전히 같다. 카메라로 얻은 파일은 임시 경로이므로 업로드 완료 또는 폼 폐기 시 정리는 OS 임시 디렉토리에 맡긴다(별도 갤러리 저장 없음).
- 카메라 촬영 취소(`null` 반환) → 아무 일도 없음.

### 6-2a. 카메라 권한 케이스

권한 요청은 `image_picker` 가 소스 진입 시 OS 에 맡긴다(신규 패키지 없음). **사전 안내 다이얼로그 없음** — OS 시스템 팝업이 곧바로 뜬다(사유 문구는 `Info.plist` 로 제공).

| 케이스 | 동작 |
|---|---|
| 최초 요청 → 허용 | 카메라가 열리고 정상 진행 |
| 요청 → 거부(이번만) | 아무 에러 화면 없이 시트가 닫힌 상태로 복귀 + SnackBar `카메라 권한이 필요해요. 사진 보관함에서 선택할 수도 있어요.` |
| 영구 거부 / 설정에서 꺼짐 / 기기 제한 (`camera_access_denied`·`camera_access_restricted` PlatformException) | **안내 다이얼로그**(`AlertDialog`, radius 16): 제목 `카메라를 사용할 수 없어요` 17 w700 `textHeading` / 본문 14 `textBody` `카메라 권한이 꺼져 있어요. 기기 설정 > Qradar > 카메라에서 허용하면 바로 촬영할 수 있어요. 지금은 사진 보관함에서 선택해 주세요.` / 액션 `확인`(`primary`) 하나 |
| 카메라 없는 기기 / 시뮬레이터(`no_available_camera`) | SnackBar `이 기기에서는 카메라를 사용할 수 없어요. 사진 보관함에서 선택해 주세요.` |
| 그 외 예외 | SnackBar `사진을 불러오지 못했어요` |

- 설정 앱 바로가기 버튼(`설정 열기`)은 **1차에 넣지 않는다** — 현재 `permission_handler`/`app_settings` 패키지가 없고, 심사 일정상 의존성을 늘리지 않는다. 문구로 경로만 안내한다. (거부 "이번만" 과 "영구" 는 `image_picker` 만으로 구분되지 않을 수 있으며, 구분 불가 시 두 경우 모두 위 영구 거부 다이얼로그 문구를 사용해도 무방하다.)
- 카메라가 실패해도 항상 사진 보관함이라는 대안 경로를 문구로 제시한다.

### 6-3. 이미지 타일 (선택 후)

- 로컬 `Image.file`, `BoxFit.cover`, radius 12, border `border` 1px.
- **삭제 버튼**: 우상단 안쪽 4px, 시각 지름 22 원형, 배경 `AppColors.primary` alpha 0.75, 아이콘 `Icons.close_rounded` 14 `onPrimary`. 터치 영역은 `GestureDetector`+`SizedBox(44)` 로 확장(타일 모서리를 넘지 않게 정렬). 탭 즉시 삭제(확인 없음 — 되돌릴 수 있는 로컬 선택이므로).
- 타일 탭(삭제 버튼 제외) → 로컬 이미지 확대 뷰어(§9와 동일 위젯, 로컬 파일 모드).
- 삭제 시 `Semantics(label: '첨부 사진 {n} 삭제')`.

### 6-4. 장수 상한·검증 동작

| 상황 | 동작 |
|---|---|
| 3장 도달 | 추가 타일 제거(= 보관함·카메라 진입점 모두 소멸), 캡션(12 `textMuted`) `최대 3장까지 첨부할 수 있어요 (3/3)` |
| 남은 장수보다 많이 선택 | 시스템 picker 의 `limit` 로 선선택 제한. 일부 OS 가 초과 반환하면 앞에서 남은 장수만 채택 + SnackBar `사진은 최대 3장까지 첨부할 수 있어요` |
| 5MB 초과(리사이즈 후에도) | 해당 파일만 제외 + SnackBar `5MB 이하 사진만 첨부할 수 있어요` (나머지는 정상 추가). 리사이즈 때문에 실제 초과는 드묾 |
| 이미지가 아닌/손상 파일 | 해당 파일 제외 + SnackBar `사진을 불러오지 못했어요` |
| 같은 사진 중복 선택 | 막지 않는다(1차) |
| 사진 보관함 권한 거부 | SnackBar `사진 접근 권한이 필요해요. 기기 설정에서 허용해 주세요.` (카메라는 §6-2a) |

### 6-5. 업로드 진행/실패 (제출 시점에 업로드 — 기존 `ImageUploadField` 와 같은 규칙)

- **타일별 진행 표시**: 업로드 중 타일 위에 `AppColors.primary` alpha 0.45 스크림 + 중앙 원형 determinate 인디케이터(지름 28, 색 `onPrimary`, 트랙 `onPrimary` alpha 0.3). 완료된 타일은 스크림 제거 후 우하단 `Icons.check_circle` 16 `success`(배경 `surfaceElevated` 원)로 표시. 업로드 중 삭제 버튼은 **숨김**.
- 버튼 라벨은 §5-4 의 `사진 업로드 중 (완료수/전체)`.
- **all-or-nothing 실패**(spec): 1장이라도 실패하면 제출 중단 →
  - 실패한 타일: border `AppColors.error` 2px + 중앙 `Icons.refresh_rounded` 24 `error`(스크림 `error` alpha 0.15)
  - picker 하단 에러 문구(12 `error`): `이미지 업로드에 실패했어요. 다시 시도해 주세요.`
  - 모든 타일 업로드 상태는 초기화(이미 올라간 파일은 클라이언트가 best-effort 삭제), 삭제 버튼 복귀. 사용자는 `문의 접수하기`를 다시 누르면 **전체 재업로드**. 실패 타일을 직접 탭해도 동일하게 재시도가 아닌 **확대 보기**(재시도는 CTA 하나로 일원화).
  - 입력한 제목/내용/유형/주문은 모두 유지.

### 6-6. 접근성

- 추가 타일 `Semantics(button: true, label: '사진 추가, 현재 n장, 최대 3장. 사진 보관함 또는 카메라 선택')`.
- 이미지 타일 `Semantics(label: '첨부 사진 n / 총 N, 확대 보기')`.

---

## 7. 화면 3 — 문의 상세 (`SupportInquiryDetailPage({required String inquiryId})`)

### 7-1. 레이아웃

- AppBar 제목 `문의 상세`. Body `SingleChildScrollView` padding `fromLTRB(20, 16, 20, 32)`, 섹션 gap 16. 데이터는 **스트림**(`inquiryDetailProvider`) — 답변이 보는 중에 도착하면 화면이 갱신된다.

### 7-2. 구성 (위 → 아래)

1. **내 문의 카드** (`surfaceElevated` 카드)
   - 상단 Row: `StatusBadge(large)` · 우측 작성일 `yyyy.MM.dd HH:mm` 12 `textMuted`
   - gap 12, 유형 12 w600 `textMuted`, gap 4, 제목 18 w700 `textHeading`
   - 구분선 `border` 1px, 위아래 gap 12
   - 본문 14 `textBody` height 1.5, `SelectableText`(줄바꿈 보존)
   - 첨부가 있으면: gap 16, `Row` 썸네일(`Image.network`/`CachedNetworkImage`, 정사각 3등분, spacing 8, radius 12, border `border`). 탭 → 확대 뷰어(§9). 로딩 placeholder `surface`, 실패 `Icons.broken_image_outlined` `textMuted`.
2. **연결 주문 카드** (`orderSnapshot` 있을 때만): 카드 외형, padding 12, 좌 `Icons.receipt_long_outlined` 20 `textMuted`, 매장명 14 w600 `textHeading`, `#{pickupNumber} · {금액}원 · {주문일}` 12 `textMuted`. 박제 스냅샷을 쓰므로 주문이 삭제돼도 표시. **탭 동작 없음**(1차).
3. **답변 영역** — status 별 분기(§7-3)
4. **하단 액션** — `open` 일 때만 `문의 철회` (§7-4)

### 7-3. 답변 영역 분기

| status | 표시 |
|---|---|
| `open` | **대기 카드**: 배경 `surface`, radius 16, padding 16, 중앙 정렬. 아이콘 `Icons.hourglass_empty_rounded` 24 `textMuted` / `답변을 준비하고 있어요` 15 w600 `textBody` / `확인되는 대로 답변드려요. 답변은 이 화면에서 확인할 수 있어요.` 12 `textMuted`. (처리 기한 약속 문구 금지) |
| `answered` | **답변 카드**(§7-3a) |
| `closed` + 답변 있음 | 답변 카드 + 아래 캡션 `종결된 문의예요` 12 `textMuted` |
| `closed` + 답변 없음 | 대기 카드 대신 안내 카드(`surface`): `종결 처리된 문의예요` 15 w600 `textBody` / `추가로 궁금한 점은 새 문의로 남겨 주세요.` 12 `textMuted` + `새로 문의하기` 라인 버튼 |
| `withdrawn` | 안내 카드(`surface`): `철회한 문의예요` 15 w600 `textBody` / `내용을 고쳐 다시 문의하려면 새로 작성해 주세요.` 12 `textMuted` + `새로 문의하기` 라인 버튼 |

- `새로 문의하기` 라인 버튼: h44, 배경 `surfaceElevated`, border `border`, 텍스트 `primary` 14 w600, radius 12 → `SupportInquiryFormPage()` push (**withdrawn 에서는 제목/본문 프리필 없음** — 1차 단순화. 프리필은 Phase 2 후보).

#### 7-3a. 답변 카드 (`SupportInquiryAnswerCard`) — 내 문의 카드와 시각 구분

내 문의 = 흰 카드(중립), 답변 = **네이비 포인트 톤**.
- 배경 `AppColors.primary` alpha 0.04, border `AppColors.primary` alpha 0.2 1px, radius 16, padding 16.
- 헤더 Row: 원형 아바타 32(`AppColors.primary` 배경, `Icons.support_agent_outlined` 18 `onPrimary`) / 라벨 `Qradar 고객센터` 14 w700 `textHeading` / 우측 답변일 12 `textMuted`.
- gap 12, 답변 본문 14 `textBody` height 1.5, `SelectableText`.
- 카드 위에 작은 섹션 라벨 없이 카드 자체로 구분(마주보는 말풍선 구조 지양 — 스레드는 Phase 2).
- 답변이 막 도착한 순간(스트림 갱신)에는 별도 애니메이션 없음. (과한 효과 지양)

### 7-4. 철회

- `open` 상태일 때만 화면 하단(스크롤 끝) 노출. 버튼: 풀폭 h48, 배경 `surfaceElevated`, border `border`, 텍스트 `textBody` 14 w600, `문의 철회` (진입점 단계에선 위험색을 쓰지 않는다 — account_deletion 선례). radius 12.
- 탭 → **확인 다이얼로그**(`AlertDialog`, 배경 `surfaceElevated`, radius 16):
  - 제목 `문의를 철회할까요?` 17 w700 `textHeading`
  - 본문 14 `textBody`:
    `철회하면 이 문의는 더 이상 처리되지 않아요.\n철회한 문의는 수정하거나 삭제할 수 없고, 내용을 고치려면 새로 작성해야 해요.`
  - 액션: `취소`(`textBody`, **기본 포커스**) · `철회하기`(`AppColors.error` w700)
- 처리 중: 다이얼로그 닫고 버튼 자리에 스피너(`primary`, 20) + 버튼 비활성, 화면 이탈은 허용.
- 성공: 스트림이 `withdrawn` 으로 갱신 → 안내 카드(§7-3)로 자동 전환, SnackBar `문의를 철회했어요`.
- 실패(Rules 거부 = 그 사이 답변이 등록됨): SnackBar `이미 답변이 등록되어 철회할 수 없어요` — 스트림이 이미 `answered` 로 갱신되므로 별도 재조회 불필요. 그 외 실패: `철회하지 못했어요. 잠시 후 다시 시도해 주세요.`
- 철회 버튼은 `answered`/`closed`/`withdrawn` 에서 **렌더하지 않는다**(비활성 표시가 아니라 부재).

### 7-5. 읽음 처리

- 진입 후 첫 데이터 수신 시 `unread` 이면 **한 번만** `markAnswerRead` 호출(post-frame, 실패는 조용히 무시 — UI 에 에러 노출 금지). 이 때문에 답변 카드를 실제로 화면에 렌더한 경우에만 읽음 처리.
- 읽음 처리 성공 시 목록 타일 dot/더보기 dot 은 스트림으로 자동 소거.

### 7-6. 상태 UI

| 상태 | 구성 |
|---|---|
| loading | 카드 스켈레톤 2개(상단 배지 막대 + 3줄 텍스트 막대) |
| error | 목록과 동일 패턴: `문의를 불러오지 못했어요` / `다시 시도` |
| not found (문서 없음/권한 없음) | `Icons.search_off_rounded` 48 `textMuted` / `문의를 찾을 수 없어요` 16 w700 `textBody` / `목록으로` 버튼(`primary`) |

---

## 8. 철회·도배 제한 문구 요약 (구현 편의용)

| 위치 | 문구 |
|---|---|
| 작성 이탈 확인 | 제목 `작성을 취소할까요?` / `작성 중인 내용이 사라져요.` / `계속 작성`·`나가기` |
| 철회 확인 | §7-4 |
| 도배 제한 | `문의를 너무 자주 보냈어요. 잠시 후 다시 시도해 주세요.` |
| 첨부 실패 | `이미지 업로드에 실패했어요. 다시 시도해 주세요.` |
| 철회 거부 | `이미 답변이 등록되어 철회할 수 없어요` |

---

## 9. 첨부 확대 뷰어 (`SupportInquiryImageViewer`, 단순 구현)

- 전체화면 route. 배경 `AppColors.primaryDeep`(검정 대신 브랜드 네이비), 상단 SafeArea 에 닫기 `Icons.close_rounded` 24 `onPrimary`(44 터치) + 중앙 `n / N` 13 `onPrimary`.
- `PageView` + 페이지마다 `InteractiveViewer`(minScale 1, maxScale 4). 단일 이미지면 페이지 인디케이터 숨김.
- 로딩: `CircularProgressIndicator`(`onPrimary`). 실패: `Icons.broken_image_outlined` 40 `onPrimary` alpha 0.6 + `불러오지 못했어요` 13.
- 로컬 파일(작성 중 미리보기)·네트워크(상세) 둘 다 받도록 소스를 추상화(`ImageProvider` 리스트 + 초기 index).
- Hero/스와이프 다운 닫기는 1차 제외.

---

## 10. 개발자 전달 사항

1. **신규 위젯은 `SupportInquiryAttachmentPicker`(+ 뷰어) 한 종류**다. 배지는 `ApprovalStatusBadge` 구조 복제, 카드·칩·입력창·바텀시트·다이얼로그는 기존 규격 재사용. 타일 공통 승격 없음(Q9).
2. **신규 색 토큰 없음.** 사용 토큰: `primary / primaryBright / primaryDeep / onPrimary / background / surface / surfaceElevated / border / textHeading / textBody / textMuted / success / error / warning / info`. 반투명은 `withValues(alpha:)` 로 표현(`approval_status_badge.dart` 선례).
3. **`_ActionSection` 의 `switch` 는 건드리지 않는다.** `_OrderInquiryBlock` 은 그 뒤에 독립 배치(§3).
4. **미확인 dot 정의는 §1-3 한 곳**에서만 계산(`unreadInquiryAnswerCountProvider` 와 목록 타일이 같은 predicate 를 공유).
5. **읽음 처리는 상세 진입 시 1회**, 실패는 사용자에게 보이지 않는다(§7-5).
6. 제출 중 `PopScope(canPop:false)` + 폼 `AbsorbPointer`, 중복 탭 차단은 버튼 비활성으로 충분(§5-4).
7. **카메라 첨부 — 플랫폼 설정 필수(누락 시 iOS 는 촬영 진입 즉시 크래시)**
   - **iOS `ios/Runner/Info.plist`** 에 `NSCameraUsageDescription` 추가. 문구: `문의에 첨부할 사진을 촬영하기 위해 카메라를 사용해요.` (현재 plist 에 `NSCamera*`·`NSPhotoLibrary*` 키 없음 — 보관함은 iOS 14+ PHPicker 라 별도 키 불필요).
   - **Android `android/app/src/main/AndroidManifest.xml`** 에 `<uses-permission android:name="android.permission.CAMERA"/>` 추가(현재 미선언). `image_picker` 가 CAMERA 선언 시 런타임 권한을 처리한다. 갤러리는 Android 13+ 시스템 photo picker 라 저장소 권한 불필요.
   - 시뮬레이터/에뮬레이터에는 카메라가 없을 수 있다 → `no_available_camera` 처리(§6-2a) 필수, 실기기로 촬영·거부·영구거부 3경로 확인.
   - 신규 패키지 없음(`permission_handler` 미도입). 설정 열기 버튼 없음.
   - 카메라·보관함 공통 후처리(5MB 검사·3장 상한·`maxWidth 1600/imageQuality 85`)는 **한 함수로 모아** 두 소스가 같은 경로를 타게 한다.
8. **첨부는 제출 시점 업로드**(기존 `ImageUploadField` 규칙), all-or-nothing, 실패 시 전체 재업로드(§6-5).
9. 상세 → 철회 성공/답변 도착은 **스트림 갱신으로만** 화면 전환. 수동 재조회 로직 불필요.
10. 푸터의 외부 연락처는 `kSupportContact` 상수 사용(하드코딩 금지).
11. 서버 raw message 는 어디에도 노출하지 않는다. 에러 토큰 → §5-6/§7-4 문구로 매핑.
12. 웹/콘솔 UI 는 이 문서 범위 밖.

---

## 11. 디자인 결정 확정 기록 (결정자: 사용자 / 2026-11-24)

| # | 결정 | 확정 내용 |
|---|---|---|
| 1 | 랜딩 문구 불일치 | 랜딩의 "내 정보 → 고객센터" 는 실제 진입점(**더보기 탭**)과 다르다. **정정은 이 task 범위 밖, 별도 처리 예정**(계획에 포함). 앱 쪽 디자인은 더보기 진입 그대로 |
| 2 | 목록 푸터 `kSupportContact` 병기 | **유지.** 게시판으로 해결되지 않는 문의와 정지 계정(로그인 불가)을 대비한 외부 채널(Q7) |
| 3 | `withdrawn` → "새로 문의하기" | **프리필 없음**(제목·본문 빈 상태로 시작) |
| 4 | 첨부 소스 | **갤러리 + 카메라로 변경(기존 "갤러리 전용" 뒤집힘).** 이유: 음료·상품 하자는 매장에서 바로 찍는 경우가 많아 갤러리 전용이면 "카메라 앱 촬영 → 복귀 → 선택" 2단계가 된다. 설계: 추가 타일 → 선택 시트(사진 보관함 / 카메라로 촬영), 카메라 권한 거부·영구 거부 문구, 3장·5MB·리사이즈 동일 적용(§6-2, §6-2a), 플랫폼 설정(§10-7) |
| 5 | 미확인 dot 색 | **`AppColors.error` 확정.** 근거: 부제가 `새 답변이 도착했어요`(`primaryBright`)로 **함께 바뀌므로 색만으로 의미를 전달하지 않는다**(접근성 충족), `error` 는 앱에서 "주의 필요" 로 가장 보편적으로 읽히는 신호색이며 별도 토큰을 새로 만들지 않아도 된다. **이후 앱의 알림 dot/배지는 이 토큰(`AppColors.error`, 지름 8, 외곽선 `background` 1.5px, 의미 텍스트 병기)을 따른다.** |
