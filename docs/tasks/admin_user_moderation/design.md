# admin_user_moderation — 디자인 (AccountSuspendedView)

기준: `spec.md` (확정). 범위는 **앱 화면 1개**. 어드민 콘솔(정지/해제/강제탈퇴)은 vanilla JS 라 범위 밖.

## 1. 디자인 결정 요약

| # | 결정 | 근거 |
|---|---|---|
| 1 | 안내 중심 톤. 빨강(`error`) 배경/큰 경고 배너 쓰지 않음. 아이콘 1개만 `AppColors.warning` 계열 | 당황 방지. 차단 사실은 문구로 명확히, 시각은 차분하게 |
| 2 | 전 역할 공통 단일 화면·단일 문구 | spec: 역할 무관 공통 |
| 3 | **정지 사유(`suspensionReason`) 비표시** (권고) | 내부 판단 메모일 수 있고 분쟁·민감 정보 노출 위험. 사유는 고객센터 문의로 안내. 엔티티에 필드 매핑 불요 (`suspended` 만) |
| 4 | CTA 는 `로그아웃` 1개 (주 버튼). 문의는 텍스트 안내 | 정지 유저는 이 화면에 갇힘. 다른 이동 경로 없음 |
| 5 | 새 공통 컴포넌트 없음. 화면 내부 private 위젯만 | 과도설계 금지 |

## 2. 진입 / 네비게이션 (role_flows 관점)

- 진입점: `RoleRouter.build` 의 `data: (user)` 분기에서 `user == null` 처리 직후, role switch **이전**에 `user.suspended == true` 이면 `const AccountSuspendedView()` 반환 (전 역할 공통, 어떤 Scaffold/탭에도 속하지 않는 전체화면).
- push/pop 없음. Router 가 직접 렌더하므로 뒤로가기 대상이 없다. 안드로이드 뒤로가기는 `PopScope(canPop: false)` 로 앱 종료 외 동작 없게 한다 (루트 화면이면 시스템 기본 종료 동작이면 충분 — developer 판단).
- 이탈: 로그아웃 → `authProvider.notifier.signOut()` → 프로필 스트림 null → RoleRouter 가 자동으로 `LoginPage`. 별도 Navigator 호출 불필요.
- 해제 후 재진입: 해제 시 users 스트림이 갱신되면 Router 가 자동으로 정상 Scaffold 로 전환(화면 닫기 불요). 단 Auth 는 disabled+토큰 revoke 상태였으므로 보통 이미 로그아웃되어 있고, 사용자가 **재로그인**하면 정상 진입한다. 화면에 "해제 시 다시 로그인" 안내는 넣지 않는다(정지 해제 보장이 없으므로).

## 3. 화면 구조

`Scaffold(backgroundColor: AppColors.background)`, AppBar 없음. `SafeArea` → 좌우 패딩 24.

```
[SafeArea]
  Spacer (flex 2)
  아이콘 원형 배지
  SizedBox 24
  제목
  SizedBox 12
  본문
  SizedBox 24
  문의 카드
  Spacer (flex 3)
  로그아웃 버튼 (하단 고정)
  SizedBox 16 (+ 하단 safe area)
```

콘텐츠가 길어지는 소형 기기/큰 글꼴 대응: `LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)` 또는 `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)` 로 Spacer 레이아웃을 유지하되 오버플로 방지.

### 3.1 아이콘 배지
- 지름 72 원형, 배경 `AppColors.surface`, 테두리 없음.
- 아이콘 `Icons.block_outlined` (또는 `Icons.lock_outline`) size 36, 색 `AppColors.warning`.
- 중앙 정렬. `Semantics(label: '계정 정지')` 로 장식 아이콘 처리 (`ExcludeSemantics` 로 감싸고 제목이 의미 전달).

### 3.2 제목
- 문구: `계정이 정지되었어요`
- fontSize 20, w700, `AppColors.textHeading`, 중앙 정렬.

### 3.3 본문
- 문구: `운영 정책에 따라 이 계정의 이용이 일시적으로 제한되어 현재 Qradar 서비스를 사용할 수 없어요.`
- fontSize 14, w400, height 1.5, `AppColors.textBody`, 중앙 정렬.
- "일시적으로" 는 해제 가능성을 암시하되 보장하지 않는 표현. 확정 보장 문구(예: "곧 해제됩니다") 금지.
- 정지 사유·일시·처리자 등 내부 메타는 표시하지 않는다.

### 3.4 문의 카드
- 컨테이너: 배경 `AppColors.surfaceElevated`, 테두리 1px `AppColors.border`, radius 12, padding 16, 가로 전체.
- 상단 라벨: `이의가 있거나 문의가 필요하신가요?` fontSize 13, w600, `AppColors.textHeading`.
- 간격 6 후 연락처 텍스트: 공유 상수 값 (현재 `고객센터 문의: (추후 입력)`) fontSize 13, w400, `AppColors.textMuted`. 복사 기능 없음(연락처 확정 후 후속 검토).
- 문구가 길어져도 줄바꿈 허용(`maxLines` 제한 없음).

### 3.5 로그아웃 버튼
- 전체 폭 `FilledButton`/기존 Primary 버튼 스타일, 높이 52, radius 기존 앱 버튼과 동일.
- 배경 `AppColors.primary`, 텍스트 `AppColors.onPrimary`, fontSize 16, w600. 라벨 `로그아웃`.
- 탭 시: 즉시 `signOut()` 호출. 확인 다이얼로그 없음 (되돌릴 수 없는 작업 아님, 정지 유저의 유일한 행동).
- 처리 중(연타 방지): 탭 후 버튼 비활성 + 내부 `CircularProgressIndicator`(size 20, strokeWidth 2, `AppColors.onPrimary`). 성공 시 Router 가 화면을 교체하므로 상태 복원 불필요.

## 4. 상태

| 상태 | 처리 |
|---|---|
| 기본 | 위 레이아웃 |
| loading | 화면 자체엔 없음. 프로필 로딩은 Router `_Loading`(기존) 사용 |
| error (signOut 실패) | 기존 `showErrorDialog` (`common/widgets/error_dialog.dart`) 패턴 재사용: 제목 `로그아웃 실패`, 본문 `잠시 후 다시 시도해 주세요.` raw 예외 메시지 미노출. 버튼은 다시 활성화 |
| empty | 해당 없음 |
| 정지 해제 감지 | 스트림 갱신으로 Router 가 자동 전환. 화면 변경 없음 |

## 5. 접근성 / 반응형
- 터치 타겟 로그아웃 버튼 높이 ≥ 48.
- 글꼴 확대 시 스크롤로 대응(§3 참조), 텍스트 고정 높이 금지.
- 다크 모드 별도 없음(AppColors 팔레트 따름).
- 사용 토큰: `background`, `surface`, `surfaceElevated`, `border`, `warning`, `textHeading`, `textBody`, `textMuted`, `primary`, `onPrimary`. `Color(0x...)`/`Colors.*` 금지.

## 6. 개발자 전달 사항

1. **서버가 최종 집행자다.** 이 화면은 UX 안내일 뿐 보안 경계가 아니다 (Auth disabled + 토큰 revoke + `verifyTossPayment` 거절이 집행). 화면 분기에 의존해 권한 차단 로직을 추가하지 말 것.
2. **진입 분기 위치**: `role_router.dart` 의 `user == null` 체크 다음, 알림 deep link `addPostFrameCallback` **이전**에 분기(정지 유저가 알림 탭으로 주문 상세 등으로 이동하지 않도록 pending 을 소비하지 않고 반환).
3. **로그아웃**: `more_page.dart` 와 동일하게 `ref.read(authProvider.notifier).signOut()`. 추가 Navigator 정리 불요 (프로필 null → LoginPage). `AccountSuspendedView` 는 `ConsumerWidget`(또는 로딩 상태를 위해 `ConsumerStatefulWidget`/hooks) 로 구현.
4. **연락처 상수 공유**: 현재 `_supportContact` 는 `lib/presentation/customer/more/more_page.dart` 의 **파일 private** 상수라 다른 파일에서 참조 불가. 권고: 공용 위치(예: `lib/core/constants/support_contact.dart` 의 `kSupportContact`)로 승격하고 `more_page.dart` 도 그것을 참조하게 한다. 출시 전 교체 지점이 1곳이 된다. (소규모 리팩터 — 승격이 부담이면 이 화면에 같은 placeholder 를 두되 출시 체크리스트에 2곳 교체를 명기.)
5. **사유 비표시**: `UserProfile` 에는 `suspended`(bool, 기본 false) 만 매핑하면 충분. `suspensionReason` 은 앱 엔티티에 넣지 않는 것을 권고(불필요한 PII/내부 메모의 클라이언트 노출 방지).
6. **엣지 케이스 (확인 요청)**: 토큰 revoke 후 Firestore 리스너가 permission-denied 를 내거나 users 스트림이 에러를 내면 Router 는 현재 `_ErrorView`(raw error/stack 노출)를 보여준다. 정지 직후 이 경로로 빠질 수 있으니, 에러 시 `LoginPage` 로 보내거나 `signOut` 유도하는 처리가 필요한지 developer/tester 가 확인할 것(본 디자인 범위 밖의 기존 동작 이슈). 또한 정지 계정의 신규 로그인 시도는 Auth 단에서 `user-disabled` 로 실패하므로, 로그인 화면에서 이 코드를 `이용이 제한된 계정이에요. 고객센터에 문의해 주세요.` 정도로 분류해 `showErrorDialog` 로 안내하는 것을 권고(raw message 미노출). 이는 선택 사항이며 사용자 확인 대상.
7. **파일 위치**: `lib/presentation/common/account_suspended_view.dart` (역할 공통이며 `role_router.dart` 와 같은 디렉토리).

## 7. 사용자 확인 필요 사항
- 정지 사유 비표시 권고 수용 여부 (기본: 비표시).
- 연락처 상수 공용 승격 여부 (기본: 승격).
- 로그인 화면 `user-disabled` 에러 문구 추가 여부 (기본: 추가 권고, 선택).
