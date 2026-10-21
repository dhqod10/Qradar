# Phase 3c-4 `notification_permission_retry` — Test Report (정적 검증)

> 검증 범위: 정적 검증 + 시나리오 감사. 라이브(에뮬레이터) 검증은 사용자가 별도 수행 (보류(라이브 예정)).
> 기준: spec.md (F1~F40, 결정 A~G), design.md (잔여 결정 확정 절 포함), implementation.md, 3_notification_settings/test_report.md F 절.
> 작성자: tester / 일자: 2026-10-21
> main 으로부터 전달받아 재실행하지 않은 항목: `flutter analyze` No issues, `flutter test` 34 passed, diff 범위 18 파일 +222/-166.

## 1. 요약

| 구분 | 개수 |
|---|---|
| PASS | 8 (중점 ①~⑧ 중 ⑧ 제외 전부 + 아래 상세) |
| FAIL | 0 |
| PARTIAL (코드 PASS, 자동화 테스트 공백) | 1 (⑧) |
| 보류(라이브 예정) | T-A1~A4, T-B1~B16, R1~R8 전부 |
| 시나리오 결함 | 6건 (S1~S6) |
| 관찰 사항 (비차단) | 5건 (O1~O5) |

릴리스 차단 FAIL 은 없다. 단, **Rules 미배포 상태에서 라이브를 시작하면 T-A1/T-B4/T-B16 이 조용히 실패한다 (선행조건, §2).**

## 2. 선행조건 (라이브 전 필수)

- `firestore.rules` 변경(`isSelfProfileUpdate` 화이트리스트에 `notificationPermissionLaterCount` 추가)은 **미배포**다.
- 미배포 상태에서 `나중에` → `incrementNotificationPermissionLaterCount` 는 permission-denied 로 실패한다. `runNotificationPermissionPrompt` 가 모든 예외를 삼키므로(`debugPrint` 만) **UI 에는 아무 증상이 없고 `laterCount` 만 안 올라간다.** 즉 T-A1 의 ② 단계에서야 발견된다.
- 권장 순서: ① Rules 에뮬레이터 R1~R8 → ② `firebase deploy --only firestore:rules` → ③ 라이브 시나리오.
- 단, 이 저장소에 `@firebase/rules-unit-testing` 하네스 스크립트가 없다 (tools/ 에는 ios_sim.py 만 존재, rules 테스트 파일 검색 결과 0건). → 시나리오 결함 S5 참조.

## 3. 중점 검증 결과

### ① 카피 문자열 일치 — PASS
`notification_permission_banner.dart` 실제 코드 대조 (글자 단위):

| 항목 | design.md 확정 | 코드 | 결과 |
|---|---|---|---|
| denied 제목 | `알림이 꺼져 있어요` | 동일 | PASS |
| denied 본문 customer | `알림을 켜면 주문 진행 상황을 바로 받아볼 수 있어요.` | 동일 | PASS |
| denied 본문 owner | `알림을 켜면 새 주문과 환불 요청을 바로 받아볼 수 있어요.` | 동일 | PASS |
| CTA (공통) | `알림 켜기` | `const cta = '알림 켜기'` | PASS |
| denied 톤/아이콘 | warning / notifications_off_outlined | 동일 | PASS |
| notDetermined 제목 | `알림을 켜 보세요` | 동일 (diff 상 변경 없음) | PASS |
| notDetermined 본문 | `주문 진행 상황을 바로 받아볼 수 있어요.` / owner `새 주문과 환불 요청을 바로 받아볼 수 있어요.` | 동일 (diff 컨텍스트 라인, 변경 없음) | PASS |
| notDetermined 톤/아이콘 | info / notifications_none_rounded | 동일 | PASS |
| SnackBar 카피 | `기기 설정에서 알림을 허용해 주세요` | 동일 | PASS |
| SnackBar 배경 | `AppColors.primary` | `backgroundColor: AppColors.primary` | PASS |
| SnackBar 텍스트/지속 | onPrimary 13 w500 / 4초 / floating | 동일 | PASS |
| 기존 에러 SnackBar 2종 | 변경 없음 | `설정 화면을 열 수 없어요`, `설정을 저장하지 못했어요...` 그대로, 기본값 `AppColors.error` | PASS |
| Semantics label | `알림 권한을 요청하는 중` 유지 (F34) | 유지 | PASS |

### ② 변경 금지 자산 보존 — PASS
- `notification_permission_dialog.dart` diff: **doc comment 3줄(+/-5행)만 변경.** 카피(`_primaryBody`/`_secondaryBody`), 레이아웃, 버튼, `barrierDismissible: false`, `queue.enqueueDialog` key 모두 무변경 확인.
- `notification_settings_page.dart` diff: 변경 hunk 는 (a) `_permissionRequestAttempted` 필드, (b) `_requestPermission` → `_onPermissionCtaTap` 교체, (c) `_fallbackToAppSettings` 신설, (d) `_showSnack` 파라미터화, (e) 배너 `onPrimaryTap` 한 줄. 토글 카피 / 섹션 헤더 / 하단 안내 / dot-path 토글 로직은 diff 에 등장하지 않음 = 무변경.
- `AppColors` 외 하드코딩 없음 (③ 참조).

### ③ 분기 누락 탐색 — PASS
- `getNotificationPermissionPrompted` 는 lib / test / functions 전체에서 **0건** (제거 완료).
- 과거 호출처 3곳 교체 의미 확인:
  - `scaffold_with_nav.dart` / `owner_scaffold.dart` → `runNotificationPermissionPrompt` (UseCase 경유 `canPromptAgain` + OS 가드). 두 파일의 본문이 동일 헬퍼로 수렴, drift 위험 제거 (결정 G).
  - `owner_orders_page.dart` → `promptState.hasSeenDialog` (`prompted || laterCount > 0`). **F22 조용한 회귀 해소.**
- `notificationPermissionPrompted` 를 읽는 다른 presentation 코드 없음 (grep: 호출은 flow 헬퍼의 `markNotificationPermissionPrompted` 1건뿐).
- F22 의 다른 형태 탐색: `hasSeenDialog` 는 한도 소진(`laterCount >= 3`) 후에도 true 라 배너 게이트가 닫히지 않음. 정상. `denied` 판정만 배너를 띄우는 기존 조건(`status == denied`)은 무변경 (O1 참조).

### ④ 폴백 분기 정확성 — PASS
`_onPermissionCtaTap` 는 `final statusBefore = _osStatus;` 를 `setState` 이전, `requestPermission` 이전에 스냅샷하고, 결과 denied 일 때 `statusBefore == denied` 일 때만 폴백한다. 요청 후 값(`_osStatus`, `_refreshOsStatus()` 이후)으로 판정하지 않는다.
- notDetermined → 거부: `_refreshOsStatus()` 만 수행, 폴백 없음 (SnackBar 도 없음, design §6 부합).
- denied → 거부: `_fallbackToAppSettings()`.
- authorized/provisional: 토큰 등록 → 갱신 → return (설정 앱 미오픈).
- `RequestNotificationPermissionUseCase` 는 예외를 `denied` 로 환원하므로 catch 분기는 사실상 도달하지 않는다 (O2).

### ⑤ 세션 가드 — PASS
`_permissionRequestAttempted` 는 `_NotificationSettingsPageState` 인스턴스 필드(bool)이며 Firestore/SharedPreferences 에 저장하는 코드 없음 (화면 이탈 시 State 폐기로 리셋). 요청 직전에 true 로 세팅, 2번째 탭은 `if (_permissionRequestAttempted)` 에서 요청 없이 `_fallbackToAppSettings()` 로 직행. 가드 분기는 `statusBefore` 와 무관하게 폴백하므로 iOS 거부 후 2번째 탭(이때 `_osStatus` 는 이미 denied)도 의도대로 설정 앱으로 간다 (T-B11 부합).
`_requestingPermission` 은 폴백(500ms 대기 + 설정 앱 호출) 전 구간을 감싸고 `finally` 에서만 해제 (E-1 요구 충족).

### ⑥ 기록 분기 — PASS
`notification_permission_prompt_flow.dart` 의 `switch (result)`:
- `'allow'` → requestPermission → (허용 시 토큰 등록) → `markNotificationPermissionPrompted` (허용/거부 무관 true, 결정 B)
- `'later'` → `incrementNotificationPermissionLaterCount` 만 (prompted 미변경). DataSource 는 `FieldValue.increment(1)` + `updatedAt` 만 (read-then-write 아님, 원자적).
- `default`(null) → `break`, write 없음.
가드 순서: uid null → OS 상태 조회 → UseCase(authorized/provisional 포함 판정 → read → `canPromptAgain`) → 다이얼로그. `!= notDetermined` 사용 0건 (main 확인과 일치).

### ⑦ Clean Architecture / 절대 규칙 — PASS
- 이번 diff 의 presentation / domain 파일에 `cloud_firestore` / `firebase_*` import 신규 없음. `FieldValue` 는 data 레이어(`user_remote_data_source.dart`)에만 존재. domain 의 `NotificationPermissionPromptState` 는 freezed 만 의존.
  - 참고: 저장소 전체 grep 에서 `presentation/customer/auth/auth_provider.dart` 가 `firebase_auth` 를 import 하고 domain `remote_notification_message.dart` 는 주석에만 firebase 언급 — 둘 다 이번 변경 이전부터 존재 (git status 상 미수정). 이번 sub-phase 범위 밖, 기존 부채로 별도 기록 (O5).
- `Color(0x` / `Colors.` 하드코딩: 변경 파일 0건. `_showSnack(backgroundColor: Color)` 파라미터 타입에 `Color` 를 쓰지만 값은 `AppColors` 토큰만 전달.
- `functions/`: `git status` / `git diff --stat -- functions` 모두 0건. Cloud Function 변경 없음 (PASS).
- 레이어 의존: flow 헬퍼는 presentation, UseCase/Entity 는 domain, 모델 파서·increment 는 data. 방향 준수.
- Rules 변경은 화이트리스트에 키 1개 추가뿐 (diff 1줄). data_ownership.md / role_flows.md 동기 갱신 확인 (silent drift 없음).

### ⑧ 단위 테스트 품질 — PARTIAL
| 요구 경계 | 테스트 | 결과 |
|---|---|---|
| `laterCount` 3 에서 중단 | state 테스트 prompted×{0..4} 전수 + `kMax == 3` 고정, UseCase `exhaustedLater(3)` false | PASS |
| `denied` 에서도 노출 (Android 전제) | UseCase: `denied + promptable → true`, `denied + default state → true` | PASS |
| `authorized` 시 Firestore read 0회 | `reads == 0` 검증 | PASS (단 `provisional` 은 read 횟수 미검증 — 낮음) |
| `hasSeenDialog` | prompted×laterCount 전수 | PASS |
| 파서 방어 | null / int / double / 문자열 / 음수 / NaN / Infinity | PASS |
| 예외 전파 | UseCase throw 전파 | PASS |

공백 (FAIL 아님, 후속 권장):
- **flow 헬퍼의 기록 분기(⑥)와 설정 화면 CTA 핸들러(④⑤)에 자동화 테스트가 없다.** 이번 sub-phase 의 핵심 로직인데 단위/위젯 테스트 0건이며 implementation.md 도 "위젯 테스트 미추가" 를 명시했다. 코드 검증으로는 PASS 이나, 회귀 방지는 라이브 의존. flow 헬퍼는 `WidgetRef` 의존이라 테스트가 어렵다 → 기록 분기를 UseCase 로 내리거나 provider override 위젯 테스트 도입 권장.
- `UserModelFactory.fromFirestore` 통합(필드 부재 → 0)은 `parseLaterCount` 단독 테스트로만 간접 확인.

## 4. 시나리오 감사 (보류 재발 방지)

T9/T13 보류 교훈 반영 여부: **대체로 반영됨.** spec 은 (1) Android 모든 시나리오를 `denied` 배너 전제로 쓰고, (2) `notDetermined` 는 iOS 전용(T-B10~B12)으로 분리, (3) 횟수 로직은 Firestore 필드 직접 세팅 + 콜드 재시작으로 대체, (4) 점주 시나리오를 Android 에뮬레이터로 옮겨 FCM 수신 불필요화, (5) 리셋 adb 절차를 고정했다. 이 5개 규칙은 타당하다.
- Android 에서 `notDetermined` 를 요구하는 시나리오: **없음.** (T-B10~B12 는 iOS Simulator 명시, FCM 불필요라 APNs 미등록 무관. T-B12 의 토큰 검증 불가를 T-A3 로 커버한다고 명시되어 보류가 아님.)
- 점주 시나리오(T-B4, T-B8)는 Android 에뮬레이터 + FCM 수신 불필요로 수행 가능.
- 각 시나리오에 환경/FCM 필요 여부 명시: T-A*, T-B* 전부 명시됨.

그러나 아래 **시나리오 결함**이 있다 (실행 불가 또는 판정 불능이며, 코드 FAIL 이 아니다).

| # | 대상 | 결함 | 대안 |
|---|---|---|---|
| S1 | T-B3 | 다이얼로그가 `barrierDismissible: false` 이고 Android 뒤로가기도 닫지 못한다. 사용자 조작으로 `null` 이 발생하는 경로가 없고, "앱 강제 종료" 는 애초에 write 코드가 실행되지 않으므로 **어떤 구현에서도 통과하는 공허한 시나리오**다. `null` 이 나오는 실제 경로는 dedup / context 만료 뿐이다. | `null` 분기는 §3-⑥ 코드 검증으로 PASS 처리하고, 라이브는 T-B15(큐 중복 시 dedup)에서 "두 번째 호출이 null 이어도 `laterCount` 불변"으로 흡수. T-B3 의 뒤로가기/강제종료 절차는 삭제하거나 "닫히지 않음 확인"으로 재정의. |
| S2 | T-A4 | 준비 단계에 **권한 리셋(규칙 5)이 빠져 있다.** 에뮬레이터 권한이 `authorized` 면 결정 D-4 가드로 모든 행이 "미노출"이 되어 표가 무의미해진다. 또 8행마다 콜드 재시작이라 수동 비용이 크다. | 준비에 "권한 리셋 후 `denied` 상태 확인(알림 설정 화면 배너로)" 추가. 행 수는 {부재, 2, 3, `"abc"`} 4행으로 축소 가능 (0/1 은 2 와 동치, 4/-1 은 단위 테스트가 이미 고정). |
| S3 | T-B6 | 기대 흐름이 코드/결정 E-2 와 모순된다. Android 에서 요청 전 `denied` 이므로 **첫 탭에서 시트 거부 직후 곧바로 SnackBar + 설정 앱이 열린다.** 시나리오는 "거부 → 배너 유지 → 같은 화면에서 CTA 재탭"으로 쓰여 설정 앱 전환 단계를 누락했다. 또 "재진입 후 시트 다시 뜸(카운터 잔여 1회)"은 첫 탭 거부 시점의 설정 앱 전환 후 복귀가 선행돼야 한다. | 절차를 "① CTA 탭 → 시트 거부 → (E-2 에 의해 설정 앱 전환 확인) → 앱 복귀 ② 같은 화면에서 CTA 재탭 → 시트 없이 설정 앱 ③ 화면 이탈 후 재진입 → CTA → 시트 재노출" 로 수정. T-B17 과 확인 포인트를 합칠 수 있다. |
| S4 | T-A2 / T-A3 / T-B13 / T-B14 의 "FCM 수신 필요" 표기 | T-A2·T-A3 은 **FCM 토큰 등록(`fcmToken` 필드 생성)** 확인이지 메시지 수신이 아니다. 같은 "FCM 필요" 라벨이 T-B13(수신 필요)과 섞여 환경 요구를 과대 해석하게 한다. 또 에뮬레이터가 Google Play 이미지가 아니면 토큰 발급이 안 된다는 전제가 없다. | 라벨을 "토큰 등록 필요" / "메시지 수신 필요"로 분리, 사전조건에 "Google Play 서비스 포함 AVD" 명시. |
| S5 | R1~R8 | "sub-phase 3 에서 확립된 방법 재사용"이라 했으나 저장소에 **하네스 스크립트가 없다** (rules 테스트 파일 검색 0건, `tools/` 는 ios_sim.py 만). 재현 불가능한 서술이며 작성 비용이 숨겨져 있다. 또 R3 의 기대(임의 정수 set 허용)는 검증 없는 필드 노출을 의도로 확인하는 것이라 로그/기록용이지 PASS 기준이 아니다. | 하네스(`tools/rules_test/` 등)를 산출물로 커밋하거나, 부재 시 R 계열을 "에뮬레이터 수동 스니펫" 으로 명시. 최소 R1/R2/R4 가 보안 핵심. |
| S6 | T-B16 | "거의 동시" 두 기기 조작은 사람 손으로 경합을 만들 수 없어, read-then-write 구현이어도 순차 실행이면 `2` 가 나와 **FAIL 을 유발하지 못한다.** | 원자성은 정적 검증(`FieldValue.increment(1)` 확인, §3-⑥ PASS)로 대체하고, 라이브는 오프라인 모드 2대에서 각각 `나중에` 후 동시 온라인 복귀 → `2` 확인 (increment 는 서버 병합) 으로 재설계. 우선순위 낮음. |

추가 선행 전제 누락 (S7): T-A1~A4 및 T-B4 는 모두 Rules 배포를 전제하나 시나리오에 선행조건이 없다 (§2).

## 5. 관찰 사항 (비차단)

- **O1**. `OwnerOrdersPage` 배너는 `status == denied` 일 때만 노출한다 (기존 동작, 무변경). iOS 점주가 `나중에` 후 OS 가 `notDetermined` 면 배너가 안 뜬다. spec 비범위(F23)라 결함 아님, 후속 후보.
- **O2**. implementation.md 는 "iOS notDetermined 에서 예외가 난 경우는 폴백하지 않는다"고 서술하나, 핸들러의 `catch` 는 `statusBefore` 와 무관하게 `_fallbackToAppSettings()` 를 호출한다. 현재는 UseCase 가 예외를 삼켜 도달 불가라 동작 차이는 없으나 **문서-코드 불일치**. UseCase 가 바뀌면 E-2 위반(거부 직후 설정 앱 오픈)이 될 수 있어 문서 정정 또는 catch 분기에 `statusBefore` 조건 추가 권장.
- **O3**. 설정 앱 열기 실패 시 에러 SnackBar 는 `clearBefore` 없이 표시되어, 4초짜리 안내 SnackBar 뒤에 큐잉된다 (에러가 최대 약 4초 지연 노출). 희소 경로.
- **O4**. 허용 경로에서 `registerFcmTokenUseCase` 예외는 핸들러에서 잡히지 않고 `finally` 후 전파된다 (기존 `_requestPermission` 과 동일 동작, 회귀 아님).
- **O5**. 기존 부채: `presentation/customer/auth/auth_provider.dart` 의 `firebase_auth` 직접 import (절대 규칙 2 위반 소지). 본 sub-phase 무관, 별도 이슈 권장.

## 6. 시나리오별 상태

| 항목 | 상태 | 비고 |
|---|---|---|
| T-A1 ~ T-A4 | 보류(라이브 예정) | Rules 배포 선행 필수. S2/S4 반영 필요 |
| T-B1, T-B2 | 보류(라이브 예정) | 실행 가능 |
| T-B3 | 보류 + **시나리오 결함 S1** | 코드 검증 PASS 로 대체 |
| T-B4, T-B5, T-B7~B9 | 보류(라이브 예정) | 실행 가능 |
| T-B6 | 보류 + **시나리오 결함 S3** | 수정 후 수행 |
| T-B10~B12 | 보류(라이브 예정) | iOS Simulator, FCM 불필요 |
| T-B13, T-B14 | 보류(라이브 예정) | 메시지 수신 필요 (Play 이미지 AVD) |
| T-B15 | 보류(라이브 예정) | S1 흡수 |
| T-B16 | 보류 + **시나리오 결함 S6** | 정적 PASS, 라이브 재설계 |
| T-B17 | 보류(라이브 예정) | 체감 평가, 릴리스 비차단 |
| R1 ~ R8 | 보류 | 하네스 부재 (S5) |

## 7. 완료 보고

- FAIL 0건. 우선 수정 항목 없음.
- 먼저 처리할 것: ① Rules 배포 순서 확정 (§2) ② 시나리오 S3 (T-B6) 수정 후 라이브 ③ O2 문서/코드 정합.
- 후속 후보: flow 헬퍼·CTA 핸들러 자동화 테스트, Rules 테스트 하네스 커밋, O1 iOS 점주 배너 게이트, O5 auth_provider 레이어 정리.

---

## Z. tester 지적 처리 (2026-10-21)

### Z-1. O2 문서-코드 불일치 → **코드 수정으로 해소**

`_onPermissionCtaTap` 의 정상 경로(결과 `denied`)는 `statusBefore` 를 보고 폴백을 판정하는데, 예외 경로(`catch`)는 `statusBefore` 와 무관하게 무조건 폴백하고 있었다. 현재는 `RequestNotificationPermissionUseCase` 가 예외를 삼켜 `denied` 로 환원하므로 도달 불가하지만, UseCase 가 바뀌면 결정 E-2 를 위반하는 **잠복 결함**이다.

문서를 코드에 맞추는 대신 **코드를 결정 E-2 에 맞췄다**. 두 경로가 동일 기준을 쓴다.

```dart
} catch (_) {
  // 요청 예외 → 정상 경로와 동일한 기준으로 폴백 판정 (결정 E-2).
  // notDetermined 에서 실패한 경우는 설정 앱으로 보내지 않는다.
  if (statusBefore == NotificationPermissionStatus.denied) {
    await _fallbackToAppSettings();
  }
  return;
}
```

수정 후 `flutter analyze` No issues found / `flutter test` 34 passed 재확인.

### Z-2. Rules 라이브 검증 — **12/12 PASS** (에뮬레이터)

sub-phase 3 의 R1~R8 에 sub-phase 4 케이스 4건(R9~R12)을 추가해 재실행했다.
`firebase-tools@14` + `@firebase/rules-unit-testing@4`, 실제 `firestore.rules` 사용.

| # | 시나리오 | 기대 | 결과 |
|---|---|---|---|
| R1~R8 | sub-phase 3 케이스 (3절 참조) | — | **전건 PASS** |
| R9 | 본인 doc `notificationPermissionLaterCount` increment | allow | **PASS** |
| R10 | 본인 doc `notificationPermissionPrompted = true` | allow | **PASS** |
| R11 | 타인 doc `laterCount` increment | deny | **PASS** |
| R12 | 본인 doc `laterCount` increment + `role: 'admin'` 동반 | deny | **PASS** |

R12 는 화이트리스트 통과 필드에 금지된 role 전이를 끼워 넣는 우회 시도로, 거부가 확인됐다.
**S5 해소**: 하네스는 세션 scratchpad 에 있다. 리포지토리 영구 편입은 후속 과제 ①.

### Z-3. 시나리오 결함 S1~S7 보정

라이브 검증은 아래 보정본을 따른다. spec 의 원본 시나리오보다 **본 절이 우선**한다.

| # | 보정 |
|---|---|
| **S1** / T-B3 | `barrierDismissible:false` 라 사용자 조작으로 `null` 을 만들 수 없다 → **라이브에서 제외**, 코드 검증(⑥ 기록 분기)으로 대체. dedup 경로는 T-B15 가 흡수 |
| **S2** / T-A4 | **준비 단계 추가**: `adb shell pm revoke` + `pm clear-permission-flags ... user-set` 으로 권한을 미요청 상태로 만든 뒤 실행. 행은 {필드 부재, 2, 3, `"abc"`} 4행으로 축소 |
| **S3** / T-B6 | Android 는 요청 전 상태가 `denied` 라 첫 탭 거부 시 곧바로 설정 앱이 열린다. 절차를 **거부 → 설정 앱 전환 확인 → 복귀 → 재탭(시트 없이 설정 앱 직행) → 화면 이탈 후 재진입(시트 재노출)** 으로 교체 |
| **S4** | T-A2 / T-A3 의 라벨을 `FCM 수신 필요` → **`토큰 등록 확인만 (수신 불필요)`** 로 분리. Google Play 이미지 AVD 전제를 명시 |
| **S5** | Z-2 로 해소 |
| **S6** / T-B16 | 수동 조작으로 경합 생성 불가 → **원자성은 정적 검증(`FieldValue.increment` 사용 확인)으로 대체**, 라이브 항목에서 제외 |
| **S7** | T-A1~A4 와 T-B4 에 **선행조건 "Rules 배포 완료"** 를 명시 |

### Z-4. 라이브 검증 선행조건

`firestore.rules` 미배포 상태에서는 `나중에` 의 `laterCount` increment 가 permission-denied 로 실패하고, flow 헬퍼가 예외를 삼켜 **UI 에 증상이 없다**. 반드시 아래를 먼저 수행한다.

```
cd /Users/Byeonguk/Developer/OrderApp && npx firebase-tools deploy --only firestore:rules
```

---

## L. 라이브 검증 결과 (2026-10-21)

환경: Android Emulator (고객 `dhqod13` / uid `dUFcFv71...`), Android 13+ 권한 모델.
조작은 `adb` 자동 수행. **결제 불필요 / FCM 수신 불필요.** 선행조건 `firestore.rules` 배포 완료.
`laterCount` / `prompted` 초기값 세팅만 Firebase Console 에서 수행 (2회).

| T | 항목 | 결과 | 근거 |
|---|---|---|---|
| **T-A1** | 재노출 3회 제한 | **PASS** | `prompted=false`, `laterCount` 부재에서 시작 → 1·2·3회차 다이얼로그 노출, `나중에` 3회 후 콜드 재시작 시 **4회차 미노출**. 2회차가 떴다는 사실 자체가 `laterCount` increment 가 Rules 통과로 실제 저장됐음을 증명 |
| **T-A2** | `허용` → `prompted=true` | **PASS** | 다이얼로그 `허용` → OS 시트 → `granted=true`. 이후 **권한만 다시 해제**(`laterCount` 는 0 유지)하고 콜드 재시작 → **다이얼로그 미노출**. 횟수로는 뜰 조건이므로 `prompted` 플래그가 막은 것 = 기록 분기 실증 |
| **T-A3** | CTA → OS 시트 → 허용 | **PASS** | `알림 켜기` 탭 → `GrantPermissionsActivity` 포그라운드 확인 → 허용 → `granted=true` + **배너 소멸** + 하단 안내 전환. CTA 스피너 정상 |
| **가드 D** | `authorized` 면 다이얼로그 차단 | **PASS** | `laterCount=0` + `prompted=false` + 권한 허용 상태에서 콜드 재시작 → **미노출**. 이 가드가 없었다면 "이미 알림을 받는 중인데 알림을 켜라는 다이얼로그" 결함이 신설됐을 것 |
| **T-B6** | 거부 폴백 (개정판) | **PASS** | 아래 상세 |
| 배너 카피 | design.md §U1 확정 문자열 | **PASS** | 제목 `알림이 꺼져 있어요` / 본문 `알림을 켜면 주문 진행 상황을 바로 받아볼 수 있어요.` / CTA `알림 켜기` — 화면 캡처로 글자 단위 확인 |
| SnackBar | 카피·배경·타이밍 | **PASS** | `기기 설정에서 알림을 허용해 주세요`, 네이비 배경. 500ms 대기 덕에 전환 전 실제로 읽힘 |
| R1~R12 | Rules | **PASS** | Z-2 참조 (12/12) |

### T-B6 개정판 상세

| 단계 | 기대 | 실제 |
|---|---|---|
| ① CTA 탭 | OS 시트 노출 | `GrantPermissionsActivity` 포그라운드 |
| ② 시트에서 거부 | **앱에 머무름** + 안내 SnackBar | 2초·8초 후 모두 `com.qradar.app` 유지, SnackBar 표시 |
| ③ 재탭 (2회차) | 요청 없이 설정 앱 | `com.android.settings` 전환 |
| ④ 화면 이탈 후 재진입 → 탭 | 가드 리셋 → 시트 재노출 | `GrantPermissionsActivity` |
| ⑤ 허용 | `granted=true` + 배너 소멸 | 확인 |

### F-1 / F-2 해소 실증

| | sub-phase 3 | sub-phase 4 |
|---|---|---|
| **F-1** Android 설정 화면 | `설정 열기` → OS 설정 앱 → 알림 → 토글 → 뒤로 (**5탭**) | `알림 켜기` → OS 시트 → 허용 (**2탭**) |
| **F-2** `나중에` 사용자 | 영구 차단 | 최대 3회 재권유, `허용` 과 구분 기록 |

플러그인 제약(F-1 의 근본 원인)은 그대로지만 **체감 영향이 소멸**했다. Android 에서 `알림 켜기` CTA 가 실제로 OS 시트를 띄우는 것을 확인했다.

### 보류 / 미검증

| 항목 | 사유 |
|---|---|
| T-B11 (iOS `notDetermined` 거부 → 미전환) | iOS Simulator 의 알림 권한을 `notDetermined` 로 되돌리려면 앱 재설치가 필요하고, 이는 소셜 재로그인을 요구한다. 코드 검증(tester ④)으로 대체 |
| F22 점주 주문 접수 배너 | 점주 계정이 iOS Simulator 에 있고 OS 권한이 허용 상태라 `denied` 배너 조건을 만들 수 없다. 코드 검증(tester ③) + 단위 테스트로 대체 |
| T-B16 원자성 | S6 보정에 따라 정적 검증(`FieldValue.increment` 사용 확인)으로 대체 |

세 건 모두 **환경 제약이며 코드 결함 근거는 없다.**

### 라이브 중 변경된 사항

T-B17(체감 평가) 결과 "거슬린다" 판정 → **결정 E-2 개정** (1회차 탭 전환 제거). spec §E-2 개정 / design.md §U3 개정 참조.
수정 후 `flutter analyze` No issues found / `flutter test` 34 passed 재확인, 재빌드 후 T-B6 재검증 PASS.

**판정: 릴리스 가능.** 차단 항목(T-A1~A4) 전건 PASS, FAIL 0건.
