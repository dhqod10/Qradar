# fcm_token_refresh_sync 기능 명세

## 개요

- 목적: 재설치 / 토큰 로테이션 사용자가 **로그인만으로도 `users/{uid}.fcmToken` 이 확실히 재등록**되어 푸시가 조용히 끊기지 않게 한다. 핵심은 **`onTokenRefresh` 스트림 구독 1개 추가**. onOrderStatusChanged CF 가 무효 토큰을 만나면 fcmToken 을 비우므로(정상), 재등록 경로가 약하면 알림이 silent 하게 유실된다.
- 작업 유형: 버그 수정 / 기존 기능 보강 (plumbing 은 이미 존재, **구독 미연결 갭**을 메움)
- 배경: 2026-10-29 알림테스트 중 라이브 재현·조사 완료. `docs/backlog.md` "⬜ FCM 토큰 재등록 갭" 참조. 추가 재조사 불필요.
- 영향 범위:
  - 화면: 없음 (UI 변경 없음)
  - Domain: **변경 없음** — 기존 `RegisterFcmTokenUseCase` 재사용 (신규 use case 신설 안 함)
  - Data: **변경 없음** — `PushNotificationRepository.onTokenRefresh()` · `UserRepository.updateFcmToken()` 이미 존재
  - Presentation: `lib/presentation/customer/auth/auth_provider.dart` 의 `AuthNotifier` 에 구독 추가 (유일한 코드 변경점)
  - 공통 컴포넌트: 없음
  - 라우팅: 없음
  - 권한 / 환경 설정: **Rules 변경 없음** — `users` self-update 화이트리스트에 `fcmToken`/`fcmTokenUpdatedAt`/`updatedAt` 이미 포함
- 비범위:
  - 알림 표시 / 탭 네비게이션 로직 (`main.dart` 의 onBackgroundMessage / onMessage / onMessageOpenedApp / getInitialMessage 핸들러)
  - Cloud Function (onOrderStatusChanged 등)
  - Firestore Rules (이미 화이트리스트 OK)
  - 명시적 로그인-register-null 재시도 로직 (§요구사항 R4 — 구독으로 자연 치유되므로 추가 안 함)
  - UI / 디자인 — **designer 불필요**

---

## 요구사항

### 기능 요구사항

- [ ] R1. 로그인 상태에서 FCM 토큰이 새로 발급 / 로테이션되면 `users/{uid}.fcmToken` 을 자동 갱신한다. (`onTokenRefresh` 구독)
- [ ] R2. 구독 핸들러는 `onTokenRefresh` 이벤트를 **재등록 트리거**로 사용하고, 쓰기는 기존 `RegisterFcmTokenUseCase.call(uid)` 를 통해서만 수행한다 (권한 게이팅·토큰 취득·silent 처리를 register 와 100% 일관되게 재사용).
- [ ] R3. 미로그인 상태에서 들어온 토큰 이벤트는 **무시**한다. 로그아웃 직후 `deleteToken()` 이 유발하는 재발급 토큰이 **fcmToken 을 되살리지 않는다** (로그아웃 레이스 차단).
- [ ] R4. 로그인 직후 `getToken()==null` 레이스(ⓑ)는 **R1 구독으로 자연 치유**된다 (토큰이 준비되면 onTokenRefresh 가 발화 → 로그인 상태이므로 register 성공). **명시적 재시도/폴링은 추가하지 않는다** (과설계 회피 — §설계 결정 D4).
- [ ] R5. 구독은 앱 수명 동안 1개만 유지되고, Notifier 재생성 시 중복 구독되지 않으며 dispose 시 취소된다.

### UI 요구사항

- 없음 (UI 변경 없음)

### 상태 요구사항

- loading / error / empty UI 상태 없음 — 전 과정 **silent**. 토큰 등록 실패가 앱 동작이나 로그인/로그아웃을 막지 않는다 (기존 use case 의 try/catch 정책 유지).

---

## 데이터 모델

### Entity

- 신규 / 변경 없음.

### DTO / Model (기존 — 변경 없음, 참고용)

- 쓰기 대상: `users/{uid}` 문서
  - `fcmToken: String` — 현재 디바이스 FCM 토큰
  - `fcmTokenUpdatedAt: serverTimestamp` — 마지막 갱신 시각 (언제 바뀌었는지 기록)
  - `updatedAt: serverTimestamp`
- 쓰기 경로: `UserRemoteDataSource.updateFcmToken(uid, token)` (Rules self-update 화이트리스트 일치)

---

## 레이어 설계

### Domain (변경 없음 — 재사용)

- UseCase: `RegisterFcmTokenUseCase.call(uid)` → `getPermissionStatus()` 확인 → `getToken()` → `userRepo.updateFcmToken(uid, token)`. 권한 없거나 토큰 null 이면 silent skip.
- Repository Interface: `PushNotificationRepository.onTokenRefresh() : Stream<String>` (이미 선언), `UserRepository.updateFcmToken(uid, token?)` (이미 선언).

### Data (변경 없음 — 재사용)

- `PushNotificationRepositoryImpl.onTokenRefresh()` → `FcmRemoteDataSource.onTokenRefresh()` → `FirebaseMessaging.instance.onTokenRefresh`.
- `UserRemoteDataSourceImpl.updateFcmToken()`.

### Presentation (유일한 변경점)

- `AuthNotifier` (`lib/presentation/customer/auth/auth_provider.dart`):
  - `build()` 에서 `ref.read(pushNotificationRepositoryProvider).onTokenRefresh().listen(...)` 로 **1회 구독**하고 `StreamSubscription` 을 필드에 보관.
  - `ref.onDispose(() => _tokenRefreshSub?.cancel())` 로 취소 등록 (Notifier 재빌드/폐기 시 중복·누수 방지).
  - 리스너 콜백:
    1. `final uid = state.asData?.value?.uid;` — **매 이벤트마다 그때그때 읽는다 (uid 캡처 금지)**.
    2. `if (uid == null) return;` — 미로그인/로그아웃/로그인 진행중(AsyncLoading) 이면 무시.
    3. `await ref.read(registerFcmTokenUseCaseProvider).call(uid);` — 스트림의 토큰 값은 쓰지 않고 register 가 권위 토큰을 재취득한다.
  - **presentation 에서 FirebaseMessaging 직접 import 없음** — repository/use case 경유만 (CLAUDE.md 절대규칙 2 준수).

---

## 데이터 흐름

```text
FirebaseMessaging.onTokenRefresh  (data)
  → FcmRemoteDataSource.onTokenRefresh()
  → PushNotificationRepositoryImpl.onTokenRefresh()      [Stream<String>]
  → AuthNotifier 구독 콜백 (presentation)
       guard: state.asData?.value?.uid (null 이면 중단)
  → RegisterFcmTokenUseCase.call(uid)                    [domain]
       getPermissionStatus() → getToken() → updateFcmToken(uid, token)
  → UserRepository.updateFcmToken()
  → UserRemoteDataSource.updateFcmToken()
  → Firestore users/{uid} { fcmToken, fcmTokenUpdatedAt, updatedAt }
```

---

## 설계 결정 (요청된 4개 쟁점에 대한 답)

### D1. 구독 소유 위치 / 생명주기 → **AuthNotifier.build() + ref.onDispose**

- `AuthNotifier` 가 이미 로그인 시 `registerFcmTokenUseCase`, 로그아웃 시 `clearFcmTokenUseCase` 를 소유한다. 토큰 수명주기의 자연스러운 중앙이다.
- `authProvider` 는 app-global `AsyncNotifierProvider` 로 앱 수명 동안 살아 있어 **토큰은 앱 실행 중 언제든 로테이션**되는 요구와 수명이 일치한다.
- 로그인 상태(uid)를 Notifier 가 이미 들고 있으므로 **게이팅 비용이 0** (D3 참조).
- 별도 provider / 서비스 신설은 상태 공유를 다시 배선해야 해 과설계. 기각.
- Clean Architecture 준수: repository(`onTokenRefresh`) + use case(`register`) 경유만, SDK 직접 import 없음.

### D2. use case 신설 여부 → **신설 안 함 (기존 RegisterFcmTokenUseCase 재사용)**

- `SyncFcmTokenUseCase(uid, token)` 신설안은 **기각**. 스트림 토큰을 직접 쓰면 `getToken()` 1회 호출을 아끼는 이점뿐인데, 그 대가로 **권한 게이팅 정책을 register 와 중복 구현**해야 한다.
- onTokenRefresh 를 "변경 발생 → 재등록" **트리거**로만 쓰고 register 가 권위 토큰을 재취득(동일 토큰)하면 **코드 경로·권한 정책이 단일화**된다. "구독 1개 추가" 라는 본질에 가장 작은 변경.

### D3. 권한 게이팅 → **register 경유로 유지 (일관성)**

- 토큰 존재가 메시징 활성을 뜻하긴 하나, Android 는 OS 알림 권한 없이도 `getToken()` 이 토큰을 반환한다. register 는 **권한 거부 사용자의 토큰을 쓰지 않도록** `getPermissionStatus() ∈ {authorized, provisional}` 를 확인한다.
- onTokenRefresh 경로도 register 를 통과시켜 **register 와 동일한 권한 정책**을 적용한다. 로테이션은 드문 이벤트라 권한 1회 재확인 비용은 무시 가능.

### D4. 로그인 register null 재시도 → **추가 안 함 (권고)**

- onTokenRefresh 는 **최초 토큰 생성 시에도 발화**한다. 로그인 직후 `getToken()==null` 레이스(ⓑ)는 정확히 "토큰이 아직 안 준비된" 상황이고, 준비되는 순간 onTokenRefresh 가 발화 → 로그인 상태이므로 register 가 성공한다. 즉 R1 구독이 ⓑ를 **자연 치유**한다.
- 구독은 Splash 의 `ref.read(authProvider.future)` 시점에 `build()` 가 실행되며 **앱 초기에 활성화**되어 커버 타이밍도 확보된다.
- 이미 토큰이 있던 재실행에서는 로그인 시 `getToken()` 이 즉시 성공하므로 레이스 자체가 없다. → 명시적 재시도/폴링은 불필요한 복잡도. 기각.
- 보조 안전망인 기존 `SyncNotificationTokenUseCase`(알림 설정 페이지 reconcile)는 **그대로 유지**한다.

---

## 레이스 / 엣지 케이스 처리

| 케이스 | 처리 방식 |
|---|---|
| 미로그인 중 토큰 이벤트 | `state.asData?.value?.uid == null` → 무시 |
| 로그인 진행 중(AsyncLoading) 토큰 이벤트 | asData 가 null → 무시 (직후 `_onSignInSuccess` 의 register 가 처리) |
| 로그아웃 레이스 (clear → deleteToken 이 재발급 토큰 유발) | `signOut()` 이 **가장 먼저 `state=AsyncLoading`** 으로 전환한 뒤 clear 를 호출 → 재발급 이벤트 도착 시 asData 는 null(Loading) 또는 이후 AsyncData(null) → **되살림 write 안 함.** 별도 플래그 불필요 |
| 권한 거부 사용자 토큰 로테이션 | register 의 권한 체크에서 skip (write 안 함) |
| register 내부 오류 / 토큰 null | silent try/catch — 앱 동작·로그인·로그아웃 영향 없음 |
| Notifier 재빌드 | `ref.onDispose` 가 이전 구독 취소 → 중복 구독 없음 |

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 권한 없음 | register 가 silent skip (write 안 함) |
| getToken null | register 가 silent skip. 이후 onTokenRefresh 재발화 시 재시도됨 |
| updateFcmToken 실패(네트워크 등) | register try/catch 로 흡수, throw 없음. 다음 토큰 이벤트/로그인에서 복구 |
| 미로그인 토큰 이벤트 | 조용히 무시 (정상 흐름) |

---

## 이력 / 감사 추적 (audit_trail.md §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** → **아니다.** `fcmToken` 은 디바이스 **푸시 라우팅 토큰**이며 화폐(Qoin)·권한(brandId/role)·정책(적립률 등) 값이 아니다. → **설정 변경 이력 불필요.** (기본값이 "남긴다" 이므로 사유를 여기 명시: 라우팅 토큰은 추적·정산·분쟁의 대상이 아니다.)
2. **덮어쓰기로 사라지는 값이 있는가?** → 이전 `fcmToken`. 단 그것은 이미 **무효가 되어 교체되는 라우팅 토큰**이라 보존 가치가 없다 (오히려 교체가 목적).
3. **정책 값을 참조만 하는가?** → 해당 없음 (정책 값 아님).
4. **"누가"가 기록되는가?** → 본인(self) self-update 이며 `fcmTokenUpdatedAt = serverTimestamp` 로 **언제**가 이미 남는다. 행위자는 구조상 본인(uid) 뿐.
5. **batch 가 있는가?** → 없음 (단건 doc update).
6. **CF 로그에 의존하는가?** → 아니다 (영구 보존 필요 데이터 없음).
7. **권한 판정 필드 create/update 교차 확인?** → 해당 없음 — `fcmToken` 은 권한 판정 입력이 아니며 Rules 변경도 없다.

> 주의(혼동 방지): 이 기능은 **거래 이력도 설정 변경 이력도 대상이 아니다.** 라우팅 토큰 동기화일 뿐이다.

---

## 데이터 소유권 / 권한 (data_ownership.md 확인)

- `users/{uid}` self-update 화이트리스트에 `fcmToken` / `fcmTokenUpdatedAt` / `updatedAt` 이 **이미 포함**(§2.1) → **Rules 변경 불필요.**
- 본인 문서 self write 이므로 **Cloud Function 불필요** — client SDK 로 직접 쓴다 (data_ownership §3 의 "타인 소유 집계 갱신" 케이스 아님).
- 쓰기 주체·분기 변화 없음.

---

## 작업 분배

### designer

- UI 변경 필요 여부: **없음.** 호출하지 않는다.

### developer

- 구현 항목:
  1. `AuthNotifier` 에 `StreamSubscription<String>? _tokenRefreshSub;` 필드 추가.
  2. `build()` 에서 `pushNotificationRepositoryProvider.onTokenRefresh()` 를 1회 `.listen` 구독, 콜백은 §레이어 설계 Presentation 의 3단계(uid guard → register) 로 구현.
  3. `ref.onDispose(() => _tokenRefreshSub?.cancel())` 등록. 재빌드 대비 기존 구독 취소 후 재구독.
  4. 콜백은 `async` 이되 예외가 밖으로 새지 않게 처리 (register 가 이미 silent 이나 리스너 레벨에서도 안전).
- 재사용할 기존 구조: `registerFcmTokenUseCaseProvider`, `pushNotificationRepositoryProvider`, `RegisterFcmTokenUseCase`, `PushNotificationRepository.onTokenRefresh()`. **신규 use case/provider/파일 생성 금지.**
- 주의할 레이어 규칙: presentation 에서 `firebase_messaging` 직접 import 금지 — repository/use case 경유만. `AppColors`/하드코딩 규칙은 UI 없어 무관.
- 주의할 레이스: uid 는 **콜백 내부에서 매번** `state.asData?.value?.uid` 로 읽는다 (build 시점 캡처 금지). `signOut()` 의 `state=AsyncLoading` 선행 순서를 깨지 말 것 (로그아웃 레이스 가드의 근거).
- 산출물: `docs/tasks/fcm_token_refresh_sync/implementation.md`

### tester

- 주요 검증 기준:
  1. 로그인 상태에서 onTokenRefresh 발화 → `updateFcmToken(uid, newToken)` 호출됨.
  2. 미로그인(uid null) 상태 이벤트 → write 호출 **안 됨**.
  3. 로그아웃 레이스: `signOut()` 진행 중(AsyncLoading)/완료 후 토큰 이벤트 → fcmToken write **안 됨** (되살림 금지).
  4. 권한 거부 상태 토큰 이벤트 → register skip (write 안 됨).
  5. 구독 중복/누수 없음 (재빌드 시 1개 유지, dispose 시 cancel).
  6. 로그인 직후 getToken null → 이후 onTokenRefresh 발화 시 등록되는 ⓑ 치유 흐름.
- 반드시 확인할 예외 케이스: register throw/네트워크 실패 시 silent, 로그인·로그아웃 미차단.
- 테스트 패턴 참고: `test/domain/should_show_notification_permission_dialog_use_case_test.dart` 의 `Fake` 리포지토리 방식. push repository 의 `onTokenRefresh()` 는 `StreamController` 로 주입/모킹.
- `flutter analyze` / `flutter test` 통과.
- 산출물: `docs/tasks/fcm_token_refresh_sync/test_report.md`

---

## 완료 기준

- [ ] R1~R5 가 모두 구현되거나 보류 사유가 명시됨
- [ ] UI 변경 없음 — `design.md` 미작성 (designer 생략) 명시됨
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료 (특히 로그아웃 레이스·미로그인 무시 케이스 PASS)
- [ ] presentation 에서 FirebaseMessaging 직접 import 없음 확인
- [ ] Rules / CF 변경 없음 확인
- [ ] FAIL 항목 없음 또는 후속 작업 분리
