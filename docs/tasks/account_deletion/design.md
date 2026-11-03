# account_deletion — 디자인 명세 (회원 탈퇴)

기준: `spec.md` (확정). 색상은 전부 `AppColors` 토큰. `Color(0x...)` 금지. 과도설계 금지 — 애플 심사 최소 요건 + 명확한 고지/확인에 집중.

참고 레퍼런스: `lib/presentation/admin/**/admin_store_delete_page.dart` (전체화면 파괴적 플로우, `AppColors.error.withValues(alpha: 0.06)` 배경 + `alpha: 0.3` 테두리 경고 카드 패턴 재사용).

---

## 1. 진입점 — 더보기 (`customer/more/more_page.dart`)

### 위치
- 로그아웃 `TextButton` 과 `Qradar v0.1.0` 텍스트 사이.
- 순서: `로그아웃` → SizedBox(4) → `회원 탈퇴` → SizedBox(24) → 버전 텍스트.

### 스타일 (눈에 안 띄게, 실수 방지)
- `Center(TextButton)`, 텍스트 `'회원 탈퇴'`
- fontSize 12, fontWeight w400, color `AppColors.textMuted`, `TextDecoration.underline` (색상 `AppColors.textMuted`)
- 빨간색 사용 안 함 (진입점 단계에서는 중립 톤. 위험 강조는 탈퇴 페이지 안에서만).
- 터치 영역: 최소 높이 44 (`TextButton` 기본 `minimumSize: Size(0, 44)`).
- 탭 → role 분기:
  - `customer` → `Navigator.push(MaterialPageRoute(AccountDeletionPage))`
  - `owner` / `brand` → 아래 §4 안내 다이얼로그 (페이지로 이동하지 않음)
  - role 판정은 `authProvider` 의 현재 사용자 role 사용.

> owner_more_page / brand_more_page / admin_more_page 에는 이번 범위에서 탈퇴 진입점을 **추가하지 않는다** (Phase 2). 고객 모드로 전환해 `MorePage` 에 들어온 owner/brand 만 §4 안내를 본다.

---

## 2. AccountDeletionPage (전체화면)

### 구조
`Scaffold(backgroundColor: AppColors.background)`
- AppBar: 제목 `회원 탈퇴`, 기본 뒤로가기. 처리 중에는 뒤로가기 비활성(`PopScope(canPop: !isProcessing)`).
- body: `SafeArea` + `SingleChildScrollView` (padding 20) — 키보드 올라와도 입력 필드가 가려지지 않도록 `resizeToAvoidBottomInset: true`, 스크롤 사용.
- 하단 CTA 는 스크롤 콘텐츠 마지막에 배치(고정 하단바 아님, 단순화).

### 2-1. 상단 경고 헤더
- 아이콘 `Icons.warning_amber_rounded` 32, color `AppColors.error`
- 제목 `정말 탈퇴하시겠어요?` fontSize 20 w700 `AppColors.textHeading`
- 보조 `탈퇴하면 되돌릴 수 없어요. 아래 내용을 꼭 확인해 주세요.` fontSize 14 `AppColors.textBody`
- 간격: 아이콘↔제목 12, 제목↔보조 6, 헤더↔다음 24

### 2-2. 사라지는 항목 카드 (경고 카드)
- Container: padding 16, radius 12, 배경 `AppColors.error.withValues(alpha: 0.06)`, 테두리 `AppColors.error.withValues(alpha: 0.3)` 1px
- 섹션 라벨 `삭제되는 정보` fontSize 13 w700 `AppColors.error`
- 항목 리스트(각 행: 아이콘 `Icons.remove_circle_outline` 16 `AppColors.error` + 텍스트 14 `AppColors.textBody`, 행 간격 8):
  1. `계정 및 로그인 정보 (이메일·소셜 연결)`
  2. `이름 · 전화번호 등 개인정보`
  3. `즐겨찾기한 매장 · 메뉴`
  4. `보유 Qoin` — 이 행만 굵게(w700, `AppColors.textHeading`). 상세는 §2-3 카드로 별도 강조.

### 2-3. Qoin 소멸 경고 (강조 카드)
**Qoin > 0 일 때만 노출.** 2-2 카드 바로 아래, 간격 12.
- Container: padding 16, radius 12, 배경 `AppColors.surface`, 테두리 `AppColors.error` 1.5px
- 좌: 아이콘 `Icons.toll_outlined` 24 `AppColors.error`
- 우 Column:
  - 라벨 `소멸되는 Qoin` fontSize 13 `AppColors.textMuted`
  - 금액 `{N} Qoin` fontSize 24 w800 `AppColors.error` (천 단위 콤마, 기존 Qoin 표기 유틸/포맷 재사용)
  - 고지 `탈퇴하면 남은 Qoin 은 모두 소멸되며 환급·복구되지 않아요.` fontSize 13 `AppColors.textBody`
- **Qoin == 0 (빈 상태)**: 카드 생략. 2-2 의 4번 행도 숨김. (별도 빈 화면 없음 — 경고만 줄어든 정상 화면.)

### 2-4. 보존 항목 안내 (정보 카드)
- Container: padding 16, radius 12, 배경 `AppColors.surface`, 테두리 `AppColors.border` 1px, 위 간격 12
- 라벨 `보관되는 정보` fontSize 13 w700 `AppColors.textHeading`
- 본문 `주문 내역은 관련 법령(전자상거래법)에 따라 개인정보 없이 보관돼요.` fontSize 13 `AppColors.textBody` (행 앞 아이콘 `Icons.info_outline` 16 `AppColors.info`)

### 2-5. 확인 문구 입력
위 간격 24.
- 안내 `계속하려면 아래에 "탈퇴합니다" 를 입력해 주세요.` fontSize 14 `AppColors.textBody`, 따옴표 안 `탈퇴합니다` 만 w700 `AppColors.error`
- `TextField` (기존 앱 입력 필드 스타일 재사용: filled `AppColors.surface`, radius 12, 테두리 `AppColors.border`)
  - hintText `탈퇴합니다` (`AppColors.textMuted`)
  - 포커스 테두리 `AppColors.error` 1.5px (파괴적 맥락 강조)
  - 입력 일치 시 우측 suffix `Icons.check_circle` 20 `AppColors.success`
  - `autocorrect: false`, `enableSuggestions: false`, `textInputAction: done`
  - 처리 중에는 `enabled: false`

**매칭 규칙 (개발자 필독)**
- 비교: `input.trim() == '탈퇴합니다'` (양끝 공백만 제거, 그 외 완전 일치. 대소문자 개념 없음. 중간 공백/유사 문구 불허).
- 한글 IME 조합 중 상태에서도 `onChanged` 마다 재평가(조합 완료 전엔 불일치로 자연스럽게 비활성).
- fail-closed: dryRun 로딩/에러, 진행 중 주문 존재, 처리 중에는 입력 일치해도 버튼 비활성.

### 2-6. 탈퇴 버튼 (CTA)
위 간격 24, 전체 너비, 높이 52, radius 12.
| 상태 | 스타일 |
|---|---|
| 비활성 (입력 불일치 / 로딩 / 차단) | 배경 `AppColors.error.withValues(alpha: 0.25)`, 텍스트 `AppColors.onPrimary`; `onPressed: null` |
| 활성 (입력 일치) | 배경 `AppColors.error`, 텍스트 `AppColors.onPrimary`, w700 16 |
| 처리 중 | 배경 `AppColors.error`, 텍스트 대신 `CircularProgressIndicator` 20, strokeWidth 2, color `AppColors.onPrimary`; 탭 불가 |
- 라벨 `회원 탈퇴`
- 그 아래 `취소` `TextButton` (`AppColors.textBody`, 간격 8) → pop. 처리 중엔 비활성.
- 실수 방지를 위해 추가 확인 다이얼로그는 두지 않는다 (확인 문구 입력이 그 역할).

---

## 3. 상태별 화면

### 3-1. 로딩 (dryRun 조회 중, 페이지 진입 직후)
- 2-1 헤더는 즉시 표시, 그 아래 영역(2-2 이하)을 중앙 `CircularProgressIndicator` (`AppColors.primaryBright`)로 대체.
- 탈퇴 버튼/입력 숨김 (fail-closed: 판정 전엔 진행 불가).

### 3-2. 조회 에러 (dryRun 실패)
- 중앙 정렬: 아이콘 `Icons.error_outline` 40 `AppColors.error`, 문구 `정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.` 14 `AppColors.textBody`, `다시 시도` OutlinedButton(`AppColors.primaryBright`).
- 기존 공통 에러 뷰 패턴(`qoin_load_error.dart` 등) 있으면 그것을 재사용.
- 탈퇴 불가 (버튼 숨김).

### 3-3. 진행 중 주문 차단 상태 (`inFlightOrderCount > 0`)
2-2 / 2-3 / 2-5 / 2-6 를 **숨기고** 아래 차단 카드만 표시 (헤더는 제목을 `지금은 탈퇴할 수 없어요` 로 교체, 아이콘 `Icons.hourglass_top_rounded` `AppColors.warning`).
- 카드: padding 16, radius 12, 배경 `AppColors.warning.withValues(alpha: 0.10)`, 테두리 `AppColors.warning.withValues(alpha: 0.4)` 1px
- 제목 `진행 중인 주문 {N}건이 있어요` 16 w700 `AppColors.textHeading`
- 본문 `주문이 완료된 후에 탈퇴할 수 있어요. 주문 상태는 Log 에서 확인해 주세요.` 14 `AppColors.textBody`
- 버튼 하나: `확인` (primary 스타일 `AppColors.primary` / `AppColors.onPrimary`) → pop. (탈퇴 버튼은 아예 렌더하지 않거나 비활성 상태로 표시하지 않음 — 불필요한 위험 UI 제거.)
- 필요 시 `Log 보기` 보조 링크는 만들지 않는다(과도설계 방지).

### 3-4. 처리 중 (탈퇴 실행)
- 2-6 버튼 로딩 + 입력/취소/뒤로가기 비활성. 전체 화면 오버레이는 사용하지 않음.
- 화면 하단 안내 `처리 중이에요. 잠시만 기다려 주세요.` 12 `AppColors.textMuted`.

### 3-5. 실패 (탈퇴 실행 실패)
- 페이지 유지, 입력값 유지(재입력 불필요). 버튼 위에 인라인 에러 박스: 배경 `AppColors.error.withValues(alpha: 0.06)`, 아이콘 `Icons.error_outline` 16 `AppColors.error`, 텍스트 14 `AppColors.error`.
- 문구 매핑 (서버 raw message 노출 금지, 토큰 분류):
  | 분류 | 문구 |
  |---|---|
  | `failed` (네트워크/서버) | `탈퇴 처리에 실패했어요. 잠시 후 다시 시도해 주세요.` |
  | `inFlightOrders` (실행 중 서버 재검증에서 차단) | 3-3 차단 상태로 화면 전환 (건수는 응답 값 사용) |
  | `unauthenticated` | `로그인 정보가 만료됐어요. 다시 로그인해 주세요.` 후 로그인 화면 유도 |
- 버튼 라벨은 `다시 시도` 로 바꾸지 않고 `회원 탈퇴` 유지(재탭 = 멱등 재호출, 안전).

### 3-6. 성공
- CF 성공 → 소셜 unlink(best-effort, 실패 무시) → `authProvider.signOut()` → 세션 null → 기존 `ref.listen`/`RoleRouter` 가 `LoginPage` 로 복귀.
- 별도 완료 페이지 없음. `LoginPage` 도착 후 SnackBar `회원 탈퇴가 완료되었어요.` (배경 `AppColors.primary`, 텍스트 `AppColors.onPrimary`, 3초). 스낵바가 라우터 전환으로 유실되면 생략 가능(필수 아님).
- `AccountDeletionPage` 는 라우터 전환으로 스택 전체가 교체되므로 수동 pop 하지 않는다.

---

## 4. owner / brand 안내 (Phase 2 전까지)

`MorePage` 의 `회원 탈퇴` 탭 시 role 이 owner/brand 이면 `AlertDialog` (기존 `error_dialog.dart` 재사용 가능):
- 배경 `AppColors.surface`, 제목 `탈퇴 안내` 18 w700 `AppColors.textHeading`
- 본문 `매장·브랜드 운영자 계정은 앱에서 직접 탈퇴할 수 없어요. 탈퇴를 원하시면 고객센터로 문의해 주세요.` 14 `AppColors.textBody`
- 버튼 `확인` (`AppColors.primaryBright`)
- 고객센터 연락처(이메일/링크)는 운영 확정 후 본문에 추가 — **사용자 확인 필요 사항**.

---

## 5. 개발자 전달 특이사항

1. **확인 문구**: `'탈퇴합니다'` 상수로 정의. 비교는 `trim()` 후 완전 일치. 일치 && `canDelete` && !processing 일 때만 버튼 활성(fail-closed).
2. **진행 중 주문 판정은 서버가 최종 재검증**. dryRun 결과는 UI 분기용일 뿐이며, 실제 실행 시 CF 가 다시 검사해 `[ACCOUNT_HAS_INFLIGHT_ORDERS]` 반환 가능 → 3-3 상태로 전환 처리 필요.
3. **성공 후 네비게이션**: 수동 pushReplacement 금지. `signOut()` 만 호출하면 기존 `ref.listen`/`RoleRouter` 가 LoginPage 로 이동. 소셜 unlink 는 signOut 이전 best-effort, 예외는 삼킨다.
4. **Qoin 표시**: `qoinToForfeit` 가 0 이면 §2-3 카드와 2-2 의 Qoin 행 숨김. 금액 포맷은 기존 Qoin 표기 유틸 재사용.
5. **처리 중 뒤로가기 차단**: `PopScope(canPop: !processing)`. 중복 탭 방지 위해 processing 플래그를 컨트롤러 상태로 관리.
6. **재사용 컴포넌트**: 경고 카드 스타일은 `admin_store_delete_page.dart` 의 error alpha 패턴, 에러 다이얼로그는 `common/widgets/error_dialog.dart`, 에러/재시도 뷰는 `qoin_load_error.dart` 패턴. 신규 공통 컴포넌트 생성 불필요(이 페이지 private 위젯으로 충분).
7. **색상 토큰**: 위 명세의 `AppColors.error / warning / info / success / primary / primaryBright / onPrimary / surface / border / textHeading / textBody / textMuted / background` 만 사용. `withValues(alpha:)` 로 투명도 처리.
8. 텍스트 필드 키보드: 한글 IME 조합 중에도 `onChanged` 로 매칭 재평가, `autocorrect: false`.

## 6. 사용자 확인 필요 사항
- owner/brand 안내 다이얼로그에 넣을 **고객센터 연락 수단**(이메일/링크) 확정.
- (선택) 탈퇴 사유 입력은 spec 에서 "선택/필수 §0 확정"으로 남아 있으나, 본 디자인은 **사유 입력 생략**(과도설계 방지, 애플 심사 불필요). 필요 시 후속 추가.
