# Phase 3c-4 알림 권한 재권유 구현 내역

## 개요
- 기준: `spec.md` (F1~F40, 결정 A~G), `design.md` (U1~U6 + 잔여 결정 확정 절)
- 목적: F-2 (`later` 사용자 영구 미재권유) 해소 = `laterCount` 기반 최대 3회 재노출, F-1 (Android `notDetermined` 불가) 해소 = 배너 CTA 를 "앱 내 요청 먼저 -> 설정 앱 폴백" 으로 통합.
- Cloud Functions 변경 0건, 마이그레이션 없음.

## 구현 파일

### 신규
- `lib/domain/entities/notification_permission_prompt_state.dart` (+ `.freezed.dart`) — `prompted`, `laterCount`, `hasSeenDialog`, `canPromptAgain`, `kMaxNotificationPermissionPrompts = 3`
- `lib/domain/usecases/should_show_notification_permission_dialog_use_case.dart`
- `lib/presentation/common/notification/notification_permission_prompt_flow.dart` — `runNotificationPermissionPrompt` (결정 G)
- `test/domain/notification_permission_prompt_state_test.dart`
- `test/domain/should_show_notification_permission_dialog_use_case_test.dart`
- `test/data/user_model_later_count_test.dart`

### 수정
- `lib/domain/entities/user_entity.dart` (+ freezed) — `notificationPermissionLaterCount`, `prompted` doc 갱신
- `lib/data/models/user_model.dart` (+ freezed) — 필드, `parseLaterCount` (num 체크 + 음수/NaN/Infinity -> 0), `toEntity`. `toFirestoreForCreate` 미변경
- `lib/domain/repositories/user_repository.dart` — `getNotificationPermissionPrompted` 제거 -> `getNotificationPermissionPromptState`, `incrementNotificationPermissionLaterCount` 신설
- `lib/data/datasources/remote/user_remote_data_source.dart`, `lib/data/repositories/user_repository_impl.dart` — 위 반영. read 1회, `FieldValue.increment(1)`
- `lib/presentation/common/notification/providers/notification_providers.dart` — UseCase provider 추가
- `lib/presentation/common/scaffold_with_nav.dart`, `lib/presentation/owner/owner_scaffold.dart` — 본문을 flow 헬퍼 호출로 교체 (중복 제거), 미사용 import 정리
- `lib/presentation/owner/orders/owner_orders_page.dart` — 배너 게이트를 `state.hasSeenDialog` 로 교체 (조용한 회귀 방지, F22). 배너/CTA 자체는 미변경 (F23)
- `lib/presentation/common/notification/widgets/notification_permission_banner.dart` — `denied` 카피 (제목 `알림이 꺼져 있어요`, 본문 owner/customer 분기, CTA `알림 켜기` 공통). `notDetermined` 카피 무변경
- `lib/presentation/common/notification/notification_settings_page.dart` — 통합 CTA 핸들러
- `lib/presentation/common/notification/notification_permission_dialog.dart` — doc comment 만 갱신 (카피·레이아웃 무변경)
- `firestore.rules` — `isSelfProfileUpdate` 화이트리스트에 `'notificationPermissionLaterCount'` 1개 추가
- 문서: `docs/processes/data_ownership.md` §2.1, `docs/processes/role_flows.md` §4.1/§4.2, `3_notification_settings/spec.md` D-3 주석 (F38~F40)

## 핵심 구현 요점
- **가드 (결정 D)**: UseCase 에서 `osStatus ∈ {authorized, provisional}` 포함 판정으로 먼저 중단 (Firestore read 절약), 이후 `state.canPromptAgain`. `!= notDetermined` 형태 미사용 (Android 영구 차단 방지). 테스트로 `denied` 에서도 노출됨을 고정.
- **기록 분기 (결정 B)**: `allow` -> 요청 -> (허용 시 토큰 등록) -> `prompted=true`. `later` -> `increment(1)` 만. `null` -> 무기록.
- **flow 헬퍼**: 전체 try/catch 로 예외 삼킴(F21), 각 비동기 경계마다 `isMounted()` 확인.
- **CTA 핸들러 `_onPermissionCtaTap`**: 요청 전 `_osStatus` 로컬 스냅샷, `_permissionRequestAttempted` 세션 가드(요청 직전 true, 이미 true 면 요청 건너뛰고 폴백), 허용 시 토큰 등록 후 상태 갱신(설정 앱 미오픈), 결과 denied 이면 요청 전이 `denied` 일 때만 폴백. `_requestingPermission` 은 설정 앱 호출까지 포함해 `finally` 에서만 해제. 설정 화면은 `prompted`/`laterCount` 를 읽지도 쓰지도 않음(F30).
- **폴백 SnackBar**: `기기 설정에서 알림을 허용해 주세요`, `AppColors.primary` 배경 + `onPrimary` 글자, 4초, floating, 표시 전 `clearSnackBars()`, 이후 500ms 대기 후 `openAppSettings`. `_showSnack` 는 기본값 error 유지 + 파라미터화. `설정 화면을 열 수 없어요` error SnackBar 는 그대로. iOS `notDetermined` 거부 경로는 SnackBar 없음.

## spec/design 대비 차이 및 참고
- `UserModelFactory.parseLaterCount` 를 public static 으로 분리 (DocumentSnapshot 없이 단위 테스트하기 위함). `fromFirestore` 와 DataSource 의 `getNotificationPermissionPromptState` 가 동일 파서를 공유.
- F29 (요청 예외 시 폴백): 기존 `RequestNotificationPermissionUseCase` 는 내부에서 예외를 삼키고 `denied` 를 반환한다. 따라서 핸들러의 try/catch 는 방어용이며, 실질적으로 예외는 `denied` 결과로 환원되어 E-2 규칙(요청 전 `denied` 일 때만 폴백)을 따른다. iOS `notDetermined` 에서 예외가 난 경우는 폴백하지 않는다 (UseCase 변경 금지 방침으로 유지).
- 기존 `prompted=true` 사용자는 재노출 제외 (결정 C) - 별도 코드 없음.

## 테스트 포인트 (tester)
- 단위 테스트 3종 신규 (`prompted` x `laterCount` 0~4 경계 / `parseLaterCount` / UseCase 4값 osStatus x state).
- 라이브: Firestore 에서 `notificationPermissionLaterCount` 를 0/1/2/3 로 세팅 후 콜드 재시작 -> 노출/미노출. `나중에` -> 값 +1, `prompted` 불변. `허용` -> `prompted=true`. 다이얼로그 `null`(dedup) 시 무기록.
- 기존 `prompted=true` + 필드 부재 계정은 다이얼로그 미노출.
- OS `authorized` 상태 + `laterCount<3` 에서도 미노출.
- 점주 `prompted=false`, `laterCount=1`, OS denied -> 주문 접수 화면 denied 배너 노출 (F22).
- 설정 화면: Android denied 배너 `알림 켜기` -> 시트 -> 허용 시 토큰 등록/배너 소멸, 거부 시 SnackBar 후 설정 앱 (T-B17 체감 평가). 같은 화면 세션 2회차 탭은 요청 없이 설정 앱. iOS notDetermined 거부 -> 배너 denied 로 전환, SnackBar/설정 앱 없음.
- Rules 배포 후 본인 uid 의 `laterCount` increment 허용 확인 (`firebase deploy --only firestore:rules` 필요 - 미배포 상태).

## 미구현 / 보류
- Rules 배포는 수행하지 않음 (로컬 파일 수정만).
- 위젯 테스트는 추가하지 않음.

## 검증
- `dart run build_runner build --delete-conflicting-outputs`: 완료
- `flutter analyze`: No issues found
- `flutter test`: All tests passed (34)
