# Phase 3c-3 알림 설정 UI 구현 내역

## 개요

- 구현 목적: 알림 설정 화면(고객/점주 공용) + OS 권한 3-state 배너 + 명시 재요청 + `ready→completed` 옵트인 알림 + CF 게이트.
- 기준 문서: `spec.md` (F1~F34, 결정 A~E), `design.md` (U1~U8 + 확정 4건)
- 결정 A~E 준수: A(환불 결과 알림 비범위) / B(`users/{uid}.notificationSettings`, `pickupComplete` 기본 false) / C(역할별 2토글) / D(3-state, sticky 변경 없음, resumed reconcile) / E(CF 게이트, 신규 CF 없음).

---

## 구현 파일 목록

### 신규 (Flutter)
- `lib/domain/entities/notification_category.dart`
- `lib/domain/entities/notification_settings_entity.dart` (+ `.freezed.dart` 생성)
- `lib/domain/usecases/update_notification_setting_use_case.dart`
- `lib/domain/usecases/sync_notification_token_use_case.dart`
- `lib/presentation/common/notification/notification_settings_page.dart`
- `lib/presentation/common/notification/widgets/notification_permission_banner.dart`
- `lib/presentation/common/notification/providers/notification_settings_providers.dart`

### 수정 (Flutter)
- `lib/domain/entities/user_entity.dart` (+ `.freezed.dart`) — `notificationSettings` 필드
- `lib/domain/entities/remote_notification_message.dart` — `orderCompleted` + `'order_completed'`
- `lib/domain/repositories/user_repository.dart` — `updateNotificationSetting`
- `lib/data/models/user_model.dart` (+ `.freezed.dart`) — 필드 / `fromFirestore` fallback 파서 / `toEntity`
- `lib/data/datasources/remote/user_remote_data_source.dart` — dot-path update
- `lib/data/repositories/user_repository_impl.dart` — 위임
- `lib/presentation/common/notification/notification_navigator.dart` — `orderCompleted` 분기 + doc
- `lib/presentation/customer/more/more_page.dart` — 플랫 ListTile 진입 타일 (UpgradeToBrandSection 아래, 로그아웃 위)
- `lib/presentation/owner/more/owner_more_page.dart` — `_Tile` 최상단 추가

### Cloud Function
- 신규: `functions/src/notificationSettings.ts`
- 수정: `functions/src/onOrderCreated.ts` (newOrder 게이트), `onOrderRefundRequested.ts` (refundRequest 게이트), `onOrderStatusChanged.ts` (settingKey + 게이트 + `ready->completed`)
- `functions/src/index.ts` 변경 없음

### Rules
- `firestore.rules` `isSelfProfileUpdate` 화이트리스트에 `'notificationSettings'` 추가:
```diff
- onlyChangedFields(['role','displayName','photoUrl','fcmToken','fcmTokenUpdatedAt','notificationPermissionPrompted','updatedAt','brandId'])
+ onlyChangedFields(['role','displayName','photoUrl','fcmToken','fcmTokenUpdatedAt','notificationPermissionPrompted','notificationSettings','updatedAt','brandId'])
```

### 문서
- `docs/processes/data_ownership.md` §2.1 — `fcmTokenUpdatedAt`, `notificationPermissionPrompted` 누락분 정정 + `notificationSettings` 추가 (F33)
- `docs/processes/role_flows.md` §4.1/§4.2 — "알림 설정 변경" 행 (F32)
- `docs/processes/entity_lifecycle.md` §2.5 — `ready→completed` 옵트인 알림 1줄 (F34)

---

## Cross-check 표

### 1. 기본값 일치

| 키 | 클라이언트 `NotificationSettingsEntity @Default` | `NotificationCategory.defaultValue` | CF `NOTIFICATION_SETTING_DEFAULTS` | spec 결정 B |
|---|---|---|---|---|
| orderProgress | true | true | true | true |
| pickupComplete | **false** | **false** | **false** | **false** |
| newOrder | true | true | true | true |
| refundRequest | true | true | true | true |

`UserModelFactory._parseNotificationSettings` 는 `NotificationCategory.defaultValue` 로 fallback (map 아님/키 부재/비bool → 해당 키만 기본값). CF 는 `typeof === 'boolean'` 검사 후 DEFAULTS fallback.

### 2. 키 문자열 일치

| 카테고리 | domain `NotificationCategory.asString` | Firestore dot-path (`'notificationSettings.$key'`) | CF `NotificationSettingKey` |
|---|---|---|---|
| orderProgress | `orderProgress` | `notificationSettings.orderProgress` | `orderProgress` |
| pickupComplete | `pickupComplete` | `notificationSettings.pickupComplete` | `pickupComplete` |
| newOrder | `newOrder` | `notificationSettings.newOrder` | `newOrder` |
| refundRequest | `refundRequest` | `notificationSettings.refundRequest` | `refundRequest` |

### 3. type 문자열 일치

| CF `data.type` | CF 게이트 키 | 클라이언트 `fromData` 매핑 | `NotificationNavigator` |
|---|---|---|---|
| `new_order` | newOrder | `NotificationType.newOrder` | OwnerOrderDetailPage |
| `refund_request` | refundRequest | `NotificationType.refundRequest` | OwnerOrderDetailPage |
| `order_accepted` | orderProgress | `orderAccepted` | OrderDetailPage |
| `order_making` | orderProgress | `orderMaking` | OrderDetailPage |
| `order_ready` | orderProgress | `orderReady` | OrderDetailPage |
| `order_completed` (신규) | pickupComplete | `orderCompleted` (신규) | OrderDetailPage (신규) |

---

## 주요 결정사항

- `SyncNotificationTokenUseCase`: 내부에서 `RegisterFcmTokenUseCase` 를 합성. 현재 fcmToken 은 `UserRepository.watchCurrent(uid).first` 로 읽음 (인터페이스 추가 메서드 회피).
- `NotificationPermissionBanner` 는 순수 표시 위젯. `AppSettings.openAppSettings()` 는 page 에서 호출(try/catch + SnackBar).
- 토글은 `SwitchListTile` + page local `_saving` / `_optimistic`. `onChanged` 는 항상 non-null, 진행 중이면 early return. 저장 `finally` 에서 optimistic 해제 → 실패 시 stream 값(원래 값)으로 자연 롤백 + SnackBar(`AppColors.error`).
- 배너 CTA 로딩은 `finally` 로 해제. 배너/하단 안내는 상호 배타. `brand`/`admin` 은 customer 토글·카피.
- `Semantics(identifier: 'notification_toggle_<key>')` 적용 (Flutter 3.41.5 지원).
- Switch 의 `trackOutlineColor` 는 ON=primary, OFF=border (`Colors.transparent` 미사용). 타일 투명 배경은 기본값에 맡김.
- `NotificationDeniedBanner` / `OwnerOrdersPage` / `ScaffoldWithNav` / `OwnerScaffold` / `NotificationPermissionDialog` 미변경.
- `toFirestoreForCreate()` 에 설정 미포함 (spec 준수).

## spec.md 대비 차이
- 없음.

## design.md 대비 차이
- 고객 진입 타일 leading 색은 `AppColors.textBody`, 점주는 기존 `_Tile` 재사용(기존 `textDefault`, `textDark` 유지 — 기존 코드 무변경 원칙). 시각 차이 없음 가정.
- Switch ripple: `SwitchListTile` 에 `splashColor` 파라미터가 없어 `overlayColor` 로 대체.
- 로딩 스켈레톤은 정적 박스(애니메이션 없음, design optional).

---

## 테스트 포인트 (T1~T16)

- [ ] T1/T2 설정 화면 진입 (고객: 픽업 완료 OFF 기본 / 점주: 둘 다 ON)
- [ ] T3~T5 토글 OFF/ON → Firestore 값, CF `disabled_by_user` 로그, 알림 미도착/복귀
- [ ] T6/T7 `order_completed` 옵트인 발화 및 기본 미발화, 탭 시 OrderDetailPage
- [ ] **T8 필드 부재 user doc 기본값 회귀 (최우선)**
- [ ] **T9 prompted=true + notDetermined 에서 "알림 켜기" → 다이얼로그 없이 OS 시트 → fcmToken 등록**
- [ ] T10~T12 denied 배너 / 설정 열기 / resumed reconcile(재로그인 없이 fcmToken 등록) / denied 에서도 토글 활성
- [ ] T13 점주 토글 반영 (newOrder / refundRequest)
- [ ] T14 CF 분리 회귀 (중복 알림 없음)
- [ ] T15 dot-path 보존 + 역할 전환 시 키 공존
- [ ] T16 sub-phase 1·2 회귀
- [ ] Rules: 타인 uid 의 notificationSettings update 거부 (배포 후)
- 라이브 검증은 Android 만 (iOS 는 ios_apns_setup 후).

## 미구현 / 보류 항목
- 환불 결과 알림 (결정 A) — 후속 task `order_refund_result_notification`.
- 공통 `MoreTile` 추출 — 후속 `more_page_restructure` 권고.
- spec 의 "다른 task 영향 추적" 중 architect 후속 인계 문서 갱신(phase3c-2 spec/test_report 노트, ios_apns_setup, operations.md)은 미수행.
- 위젯/단위 테스트는 추가하지 않음 (기존 테스트 스위트 범위 유지).

## 코드 생성
- 필요함 — 실행 완료: `dart run build_runner build --delete-conflicting-outputs`

## 검증
- `flutter analyze`: No issues found
- `flutter test`: All tests passed (4)
- `cd functions && npm run build` (tsc): 통과
