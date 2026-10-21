# Test Report — Phase 3c-3 알림 설정 UI

검증자: tester / 기준: spec.md (F1~F34, U1~U8, T1~T16), design.md, implementation.md
방식: 실제 코드 직접 확인 (developer 표 미의존). 라이브 검증은 2026-10-21 Android Emulator + iOS Simulator 로 수행 (E 절).

## 요약

| 구분 | PASS | FAIL | 보류 |
|---|---|---|---|
| 정적 검증 (Cross-check 3 / F34 / U8 / designer 5 / CA 3 / Rules 3 / 파싱 3 / 빌드 3) | 62 | 0 | 0 |
| 라이브 (T1~T16 + Rules) | 13 | 0 | 3 (T9 / T13 / Rules — 환경·인프라 사유, E 절 참조) |

`flutter analyze`: No issues found / `flutter test`: 4 passed / CF `npm run build`(tsc): 통과 — 모두 직접 재실행.

## A. 정적 검증

### A-1. Cross-check 3종 (독립 재검증) — 전부 PASS

**기본값** (orderProgress / pickupComplete / newOrder / refundRequest)

| 위치 | 값 |
|---|---|
| `lib/domain/entities/notification_settings_entity.dart` @Default | true / **false** / true / true |
| 생성 `notification_settings_entity.freezed.dart:212` | true / **false** / true / true |
| `lib/domain/entities/notification_category.dart` defaultValue | true / **false** / true / true |
| `functions/src/notificationSettings.ts` NOTIFICATION_SETTING_DEFAULTS | true / **false** / true / true |
| spec 결정 B | 일치 |

`pickupComplete` 는 4곳 모두 false → 릴리스 차단 사유 없음. `UserModel`/`UserEntity` 의 `@Default(NotificationSettingsEntity())` 도 동일 기본값을 따름.

**키 문자열**: `NotificationCategory.asString` = `orderProgress/pickupComplete/newOrder/refundRequest` ↔ `UserRepositoryImpl` 이 `category.asString` 으로 변환 → `user_remote_data_source.dart` `'notificationSettings.$key'` ↔ CF `NotificationSettingKey` (`keyof DEFAULTS`) 동일. `UserModelFactory._parseNotificationSettings` 도 `c.asString` 사용. PASS.

**type 문자열**
- CF `new_order`(onOrderCreated.ts:100) / `refund_request`(onOrderRefundRequested.ts:119) / `order_accepted|making|ready|completed`(onOrderStatusChanged.ts 매트릭스) ↔ `RemoteNotificationMessage.fromData` 매핑 (`order_completed` → `orderCompleted` 포함) ↔ `NotificationNavigator` (`orderCompleted` 가 customer `OrderDetailPage` push 분기에 포함). PASS.

### A-2. F1~F34 — 전부 PASS
- F1~F9 (enum/entity/model/datasource/repo): dot-path update + `updatedAt` serverTimestamp, 도메인→키 변환은 data 레이어(`UserRepositoryImpl`). PASS
- F10~F11: `UpdateNotificationSettingUseCase`(예외 전파), `SyncNotificationTokenUseCase`(권한 authorized/provisional + 토큰 null 일 때만 등록, 실패 swallow, 멱등). PASS
- F12~F20: `NotificationSettingsPage` ConsumerStatefulWidget + WidgetsBindingObserver, role 로 판정, `currentUserProfileProvider` watch(신규 stream 없음), initState post-frame + resumed(reconcile) 갱신, 3-state, `AppSettings.openAppSettings`, notDetermined → `RequestNotificationPermissionUseCase` → `RegisterFcmTokenUseCase` (다이얼로그 미경유), optimistic + `_saving` 연타 방지 + 실패 롤백 SnackBar. PASS
- F21~F22: 고객 `more_page.dart`(UpgradeToBrandSection 아래/로그아웃 위), 점주 `owner_more_page.dart`(제목 바로 아래, 고객 모드 전환 위) — design §3-2 일치. PASS
- F23~F24: PASS (A-1)
- F25~F30: helper 신설, 3개 CF 게이트 + `disabled_by_user` 구조화 로그, 매트릭스 `settingKey`, `ready->completed` 신규, index.ts 변경 없음(git status 에 없음). PASS
- F31: `firestore.rules` 화이트리스트에 `notificationSettings` 1개만 추가 (diff 1줄). PASS
- F32~F34: role_flows(고객/점주 행), data_ownership(누락 2개 정정 포함), entity_lifecycle 1줄 반영. PASS

### A-3. U1~U8 — 전부 PASS
토글 카피(고객/점주 제목·부연·섹션 헤더), 배너 3-state 카피/톤(denied=warning, notDetermined=info, authorized=하단 안내), CTA 별도 버튼 + 16x16 로딩, 진입 타일 스펙·부제·위치, `order_completed` 카피(`픽업이 완료됐어요` / `{n}에서 받은 음료, 맛있게 즐겨주세요.`), 다이얼로그 카피 미변경, 스켈레톤/에러 바디, 좌우 gutter 20 등 design 수치와 일치.

### A-4. designer 주의사항 — 전부 PASS
- `NotificationDeniedBanner` / `OwnerOrdersPage` / `ScaffoldWithNav` / `OwnerScaffold` / `NotificationPermissionDialog` : `git status`·`git diff --stat` 에 변경 없음.
- 토글 `onChanged` 항상 non-null, 콜백 내 `_saving` early return (page:107, tile onChanged).
- 배너 CTA 로딩 해제 `finally` (page `_requestPermission`).
- SnackBar `AppColors.error` / 글자 `AppColors.onPrimary`.
- `isOwner = role == owner` → brand/admin 은 고객 토글·카피·배너 audience.

### A-5. Clean Architecture — PASS
- `lib/presentation/common/notification/**`, 신규 domain 파일에 firebase/cloud_firestore import 없음 (grep 0건). `app_settings` 는 선례(NotificationDeniedBanner)와 동일한 플랫폼 호출 전용.
- 신규 파일 위치: domain(entities/usecases) / presentation(common/notification, providers, widgets) 적절. data 의 Firestore 접근은 datasource 에만.
- `Color(0x` / `Colors.` 사용 0건 (grep). `withValues(alpha:)` 는 허용 범위.

### A-6. Firestore Rules — PASS
- `isSelfProfileUpdate` 의 `onlyChangedFields` 에 `notificationSettings` 추가, `uid() == userId` 조건 유지 → 타인 uid update 는 admin 이 아니면 거부 구조. role 전이/brandId 분기 무변경(회귀 없음).
- `onlyChangedFields` 는 top-level `affectedKeys` 기준이므로 dot-path 하위 키 변경도 `notificationSettings` 하나로 집계됨. (실제 거부 동작은 T-Rules 로 라이브 확인)

### A-7. 방어적 파싱 — PASS
- 클라이언트 `_parseNotificationSettings`: map 아님 → 전체 기본값 / 키 없음·비bool → 해당 키만 `defaultValue`.
- CF `isNotificationEnabled`: `userData` undefined, settings 가 object 아님, 값이 boolean 아님 → `DEFAULTS[key]`.

### A-8. 빌드 — PASS (analyze / test / tsc)

## 관찰 사항 (FAIL 아님, 후속 검토)
1. **신규 로직 단위 테스트 없음** — `_parseNotificationSettings`, `isNotificationEnabled`, `SyncNotificationTokenUseCase` 는 순수 함수/UseCase 라 단위 테스트 추가 권장 (현 test 는 4건, 무관한 계산기 테스트). 특히 기본값 drift 방지용 `NotificationCategory.defaultValue` ↔ `NotificationSettingsEntity()` 일치 테스트 권장.
2. **optimistic 해제 타이밍** — 저장 성공 후 `finally` 에서 `_optimistic` 를 즉시 제거. Firestore 로컬 write 는 stream 에 즉시 반영되므로 통상 깜빡임 없음. 네트워크 지연 환경(T3)에서 토글이 순간 되돌아 보이면 보고 필요.
3. `SyncNotificationTokenUseCase` 는 resumed 에서만 호출 (spec F18 일치). 화면 최초 진입 시에는 reconcile 하지 않음 — 의도된 범위.
4. role_flows / data_ownership 갱신은 완료. CF 동시 변경 3개가 모두 "token 조회 이후" 게이트라 토큰 없음 사용자는 기존 로그(`no token`)가 우선 — 정상.

## B. 라이브 검증 매뉴얼 (실행 완료 — 결과는 E 절)

환경: Android Emulator = 고객 / iOS Simulator = 점주(UI 조작만, 알림 수신 불가). iOS 는 `python3 tools/ios_sim.py tap "라벨"` / `list` / `shot`. CF 로그는 `firebase functions:log` 또는 콘솔에서 `disabled_by_user` 확인. Firestore 콘솔로 `users/{uid}` 직접 확인.
점주 → 고객 알림 시나리오는 점주 조작(상태 전이)을 iOS Simulator 에서, 알림 수신 확인은 Android 에서 한다.

### 릴리스 차단 (3건)

**T8 기본값 회귀 [차단]**
1. 콘솔에서 고객 user doc 의 `notificationSettings` 필드를 **삭제** (fcmToken 은 유지).
2. 고객 앱에서 주문 → 점주가 접수 / 조리 시작 / 준비 완료 / 픽업 완료 순서로 전이.
3. 기대: 접수·조리·준비 알림 3건 **도착**, 픽업 완료 **미도착** (CF 로그에 `key: pickupComplete, reason: disabled_by_user`). 점주 doc 도 필드 삭제 후 신규 주문·환불 요청 알림 도착 확인.
4. 설정 화면 진입 시 고객: 주문 진행 ON / 픽업 완료 OFF, 점주: 둘 다 ON.

**T9 sticky 우회 [차단]**
1. user doc `notificationPermissionPrompted=true`, fcmToken 삭제. Android 앱 데이터 삭제(권한 notDetermined 상태 재현) 또는 시뮬레이터 권한 초기화 후 재로그인.
2. 더보기 > 알림 설정 > `알림을 켜 보세요` 배너 + `알림 켜기`.
3. 탭 → **앱 내 다이얼로그 없이** OS 권한 시트 → 허용.
4. 기대: 배너 사라지고 하단 안내 노출, `users/{uid}.fcmToken` 등록, 이후 상태 전이 알림 수신.

**T11 토큰 reconcile [차단]**
1. OS 설정에서 앱 알림 OFF (T10 상태) + user doc fcmToken 삭제.
2. 설정 화면에서 `설정 열기` → OS 설정에서 알림 ON → 앱 복귀 (재로그인 없음).
3. 기대: 배너 사라짐 + `fcmToken` 등록 (콘솔 확인).

### 그 외

| T | 시나리오 | 확인 포인트 |
|---|---|---|
| T1 | 고객 설정 진입 | 토글 2개, 픽업 완료 OFF, 섹션 `주문 알림` |
| T2 | 점주 설정 진입 (iOS) | 토글 2개 ON, 섹션 `매장 알림`. brand/admin 계정은 고객 토글 노출 |
| T3 | 주문 진행 OFF | Firestore `orderProgress=false`, 재진입 시 OFF 유지, 실패 시(네트워크 차단) 롤백+빨간 SnackBar |
| T4 | OFF 반영 | 접수/조리/준비 알림 미도착, 로그 `disabled_by_user` |
| T5 | ON 복귀 | 알림 정상 도착 |
| T6 | 픽업 완료 ON | `order_completed` 알림(`픽업이 완료됐어요` / `…받은 음료, 맛있게 즐겨주세요.`) 도착, **탭 → 고객 OrderDetailPage** (foreground / background / terminated 3종) |
| T7 | 픽업 완료 OFF/미설정 | 알림 미도착 |
| T10 | OS 거부 배너 | `기기 설정에서 알림이 꺼져 있어요` + `설정 열기` → OS 설정 앱 |
| T12 | OS 거부 상태 토글 | 토글 활성, 저장 성공, 배너 유지 |
| T13 | 점주 토글 | 신규 주문 OFF → 점주 알림 미도착(`onOrderCreated` 로그), 환불 요청 OFF 동일 |
| T14 | CF 분리 회귀 | 환불 요청 시 알림 1건, 상태 전이 시 환불 CF 가 early return (중복 없음) |
| T15 | dot-path 보존 | 고객 토글 2개 변경 → owner 전환 → 점주 토글 변경 → doc 에 4키 공존, 한 키 변경이 다른 키를 지우지 않음 (콘솔) |
| T16 | sub-phase 1·2 회귀 | 조리 전이, 진행 인디케이터, deep link 3종, 권한 다이얼로그 sticky |
| Rules | 타인 uid update 거부 | 콘솔 Rules Playground 또는 임시 코드로 타인 uid `notificationSettings` update → permission-denied; 본인 update 허용; `role` 임의 변경 거부(회귀) |
| 배너 3-state | 전환 | notDetermined(info/알림 켜기) → denied(warning/설정 열기) → authorized(배너 소멸 + 하단 안내), 알림 켜기 로딩 중 버튼 비활성, 시트 닫기만 하면 notDetermined 유지 |

## 우선순위 / 후속
- FAIL 0건. 수정 필수 항목 없음.
- 라이브 완료 (E 절). T8 · T11 PASS, T9 는 F-1 사유로 보류 → 릴리스 가능 판단.
- 후속 후보: ① 신규 로직 단위 테스트 + 기본값 drift 테스트 ② `more_page_restructure` (MoreTile 통합) ③ `order_refund_result_notification` (환불 결과 알림, `refundResult` 키 추가) ④ 설정 화면 최초 진입 시 reconcile 필요 여부 재검토 ⑤ **`notification_permission_retry`** — 아래 F-1 참조.

---

## F. 라이브 검증 중 발견 (후속 과제)

### F-1. Android 에서 `notDetermined` 상태 도달 불가 — 원터치 재요청 경로 상실

**현상**: Android 에서 OS 권한이 "한 번도 요청되지 않은" 상태여도 설정 화면에 `notDetermined` 배너(`알림을 켜 보세요` / `알림 켜기`)가 아닌 `denied` 배너(`기기 설정에서 알림이 꺼져 있어요` / `설정 열기`)가 표시된다.

**원인**: 우리 코드가 아닌 플러그인 제약.

```java
// firebase_messaging-16.1.3 FlutterFirebaseMessagingPlugin.java:409
permissions.put("authorizationStatus", areNotificationsEnabled ? 1 : 0);
```

```dart
// firebase_messaging_platform_interface-4.7.8 utils.dart:84
case -1: return AuthorizationStatus.notDetermined;  // iOS 전용
case  0: return AuthorizationStatus.denied;
case  1: return AuthorizationStatus.authorized;
```

Android 네이티브는 `0`/`1` 만 반환 → `-1`(notDetermined)이 발생할 수 없다. `design.md` 의 배너 3-state 설계는 실질적으로 iOS 전용.

**실기 확인**: `pm revoke` + `pm clear-permission-flags ... user-set` 으로 네이티브 미요청 상태를 재현한 뒤 설정 화면 진입 → `denied` 배너 표시 확인 (코드 추론과 일치).

**영향**: sub-phase 2 다이얼로그에서 `나중에` 를 선택한 Android 사용자는 원터치 재요청(2탭) 대신 OS 설정 경유(5탭)를 거쳐야 한다. **알림을 켜는 경로 자체는 정상 동작** (T11 에서 실증) → 릴리스 차단 아님.

### F-2. `notificationPermissionPrompted` 가 `allow` / `later` 를 구분하지 않음

`scaffold_with_nav.dart` / `owner_scaffold.dart` 는 다이얼로그 결과와 무관하게 플래그를 `true` 로 설정한다.

```dart
// 결과와 무관하게 플래그 set (재노출 방지)
await ref.read(userRepositoryProvider).markNotificationPermissionPrompted(uid);
```

그러나 두 그룹의 OS 상태는 다르다.

| 선택 | OS 권한 시트 | 재요청 효과 |
|---|---|---|
| `허용` → OS 에서 거부 | 이미 소진 (Android 2회 / iOS 1회 후 영구 차단) | 없음 — 재노출해도 무의미 |
| `나중에` | **미요청** | 있음 — 재노출 시 정상 동작 |

**제안**: `allow` 선택 시에만 플래그를 `true` 로 하고, `later` 는 `false` 유지 + 재노출 가드(`laterCount` 2~3회 제한 또는 `lastPromptedAt` 쿨다운)를 둔다. F-1 에서 경로를 잃는 집단이 정확히 `later` 그룹이므로 **F-1 과 F-2 를 하나의 후속 sub-phase 로 묶어 처리**하는 것을 권장한다.

**범위**: 필드 추가 + Rules 화이트리스트 + spec 결정 항목이 따라붙는 동작 설계 변경 → sub-phase 3 범위 밖. 후속 과제 ⑤ `notification_permission_retry` 로 분리.

---

## E. 라이브 검증 결과 (2026-10-21)

환경: Android Emulator (고객 `dhqod13` / uid `dUFcFv71...`) + iOS Simulator iPhone 17 (점주 / uid `8gnNH8NA...`).
조작은 `adb` / `tools/ios_sim.py` 로 자동 수행, 결제만 사용자가 진행. 근거는 화면 캡처 + 알림 트레이(`dumpsys notification`) + CF 로그(`firebase functions:log`).

| T | 항목 | 결과 | 근거 |
|---|---|---|---|
| T1 | 고객 설정 진입 | **PASS** | 섹션 `주문 알림`, 토글 2개, 카피 일치, 기본값 진행 ON / 픽업 OFF |
| T2 | 점주 설정 진입 | **PASS** | 섹션 `매장 알림`, 점주 카피, 토글 2개 ON. 진입 타일 subtitle 도 역할 분기 |
| T3 | 토글 저장·유지 | **PASS** | 고객·점주 양쪽에서 OFF 저장 → 재진입 유지. 에러 SnackBar 없음 |
| T4 | `orderProgress` OFF 반영 | **PASS** | 접수/조리/준비 3회 전이 → 알림 트레이 0건 + CF 로그 `key: orderProgress, reason: disabled_by_user` ×3 |
| T5 | ON 복귀 시 수신 | **PASS** | T8 실행분으로 커버 (진행 알림 3건 도착) |
| T6 | `pickupComplete` ON | **PASS** (background) | `픽업이 완료됐어요` / `개인매장에서 받은 음료, 맛있게 즐겨주세요.` 도착 → 탭 → 고객 `OrderDetailPage` 진입. 로그 `[NotifTap] dispatch source=localTap type=NotificationType.orderCompleted orderId=c0ecd27d...` |
| T7 | `pickupComplete` OFF/미설정 | **PASS** | T8 실행분으로 커버 |
| **T8** | 기본값 회귀 **[차단]** | **PASS** | `notificationSettings` 필드 부재 상태에서 진행 3건 도착 / 픽업 완료 미도착. CF 로그 `key: pickupComplete, reason: disabled_by_user`. 알림 `when` 타임스탬프 35초간 불변으로 미발화 확인 |
| T10 | OS 거부 배너 | **PASS** | `기기 설정에서 알림이 꺼져 있어요` + `설정 열기` → `com.android.settings` 포그라운드 전환 확인 |
| **T11** | 토큰 reconcile **[차단]** | **PASS** | fcmToken 삭제 + 권한 OFF → 설정에서 ON → 앱 복귀(재로그인 없음) → 배너 소멸 + 콘솔에서 `fcmToken` 재생성 확인 |
| T12 | 거부 상태 토글 | **PASS** | 토글 활성·저장 성공, 배너 유지 |
| T14 | CF 분리 회귀 | **부분 PASS** | 상태 전이 8회 모두 `onOrderRefundRequested` 가 로그 출력 없이 early return (FCM 0건) → 중복 없음. 환불 요청 방향은 아래 보류 |
| T15 | dot-path 보존 | **PASS** | `orderProgress=false` 저장 후 `pickupComplete=true` 저장 → 앞 값이 기본값으로 복귀하지 않음. 재진입 후에도 유지 |
| T16 | sub-phase 1·2 회귀 | **PASS** (관찰분) | 점주 조리 전이 4단계 정상, 고객 진행 인디케이터 4/4 정상, background deep link 정상, 권한 다이얼로그 sticky 정상(미요청 상태에서도 미노출) |
| **T9** | sticky 우회 **[차단]** | **보류** | Android 재현 불가 (F-1). iOS 는 권한 초기화에 앱 재설치 → 재로그인 필요 + APNs 키 미등록으로 토큰 등록 검증 불가 |
| T13 | 점주 토글 반영 | **보류** | 점주 doc 에 `fcmToken` 자체가 없어 `onOrderCreated.ts:73` 토큰 가드에서 early return → 79행 설정 게이트에 도달하지 않음. 원인은 iOS Simulator + APNs 키 미등록 (환경 제약) |
| Rules | 타인 uid update 거부 | **보류** | emulator / `@firebase/rules-unit-testing` 미구성. 본인 self-update 허용 경로는 모든 토글 저장 성공으로 간접 확인됨. deny 경로는 Console Rules Playground 1분 작업으로 확인 가능 |

### 보완 메모

**T6 의 foreground / terminated**: `NotificationNavigator` 에서 `orderCompleted` 는 `orderAccepted` / `orderMaking` / `orderReady` 와 **동일한 case 블록**을 공유한다 (타입별 분기 없음). 해당 3종의 foreground / terminated 는 sub-phase 2 에서 라이브 PASS (terminated 는 `PendingNotificationHolder` 수정 후 재검증 완료). 따라서 background 만 추가 검증하고 나머지는 코드 동일성으로 커버한다.

**릴리스 판단**: 차단 3건 중 T8 · T11 PASS. T9 는 Android 에서 발생 불가능한 상태를 전제하며, Android 의 대체 경로(`설정 열기` → OS 설정 → 복귀 reconcile)가 T11 에서 실증됐다. T13 · Rules 보류는 환경/인프라 사유이며 코드 결함 근거는 없다. → **릴리스 가능**.
