# Phase 3c — sub-phase 4: 알림 권한 재권유 (`notification_permission_retry`)

> 단일 진실원 / 참고:
> - 발견 근거: [3_notification_settings/test_report.md](../3_notification_settings/test_report.md) **F 절 (F-1 / F-2)**
> - 직전 sub-phase 결정: [3_notification_settings/spec.md](../3_notification_settings/spec.md) 결정 D (D-1 ~ D-5)
> - sticky 정책 도입: [2_customer_notification_and_ui/spec.md](../2_customer_notification_and_ui/spec.md)
> - 역할 흐름: [docs/processes/role_flows.md](../../../processes/role_flows.md) §4.1 / §4.2
> - 데이터 소유권: [docs/processes/data_ownership.md](../../../processes/data_ownership.md) §2.1 (`users/{userId}`)
> - 아키텍처: [docs/architecture.md](../../../architecture.md)

---

## 변경 이력

| 일자 | 변경자 | 변경 내용 |
|---|---|---|
| 2026-10-21 | main | Q1~Q7 전건 확정 (Q2·Q3·Q4 사용자 직접 확인, 나머지 결정안 수용). 설계 변경 없음 — 확정 표기만 반영 |
| 2026-10-21 | architect | 본 spec 최초 작성. F-1 / F-2 를 하나의 sub-phase 로 묶어 설계. 사용자 확정 결정 2건(횟수 제한 / 요청-먼저-설정-폴백) 반영, architect 결정 7건(결정 A~G) + 확인 필요 항목 Q1~Q7 |

---

## 개요

- **목적**: sub-phase 3 라이브 검증에서 발견된 알림 권한 흐름 결함 2건을 해소한다.
  - **F-2 (주 문제)**: `users/{uid}.notificationPermissionPrompted` 가 다이얼로그 결과(`allow` / `later` / `null`)와 **무관하게** `true` 로 set 된다. 그 결과 OS 권한 시트를 이미 소진한 `allow` 그룹과, OS 에 아무것도 요청하지 않은 `later` 그룹이 동일 취급되어 **`later` 사용자가 영구히 재권유를 받지 못한다**. → 다이얼로그 결과별 기록 분기 + `laterCount` 기반 횟수 제한 재노출을 도입한다.
  - **F-1 (파생 문제)**: Android 는 `firebase_messaging` 플러그인 제약으로 `AuthorizationStatus.notDetermined` 에 **도달할 수 없다**(네이티브가 `0`/`1` 만 반환). 그래서 "OS 에 한 번도 요청하지 않은" Android 사용자에게도 `denied` 배너(`설정 열기`, 5탭 경로)가 표시되고, 원터치 재요청 CTA(`알림 켜기`, 2탭 경로)가 사라진다. → 배너 CTA 를 **"앱 내 권한 요청 먼저 시도 → 실패 시 OS 설정 앱 폴백"** 2단계로 통합하여, 어느 state 가 뜨든 동일하게 최단 경로를 시도하게 만든다.
- **작업 유형**: 기존 기능 수정 (버그 수정 + 정책 변경). 신규 화면 없음, 신규 Cloud Function 없음, CF 코드 변경 없음.
- **actor**: customer / owner **양쪽**. brand / admin 은 기존대로 customer 흐름으로 fallback.
- **클라이언트 SDK 직접 write 경로**: `users/{uid}.notificationPermissionLaterCount` — 본인만. Firestore Rules `isSelfProfileUpdate` 화이트리스트 확장 1건이 유일한 Rules 변경.
- **마이그레이션**: **없음**. 신규 필드 부재 → 기본값 `0` fallback (sub-phase 3 `notificationSettings` 와 동일 원칙).

### Phase 3c 로드맵에서의 위치

| sub-phase | 범위 | 상태 |
|---|---|---|
| 3c-1 | Order 조리 단계 전이 + 점주 UI + Rules | 완료 |
| 3c-2 | 고객 FCM 알림 + 진행 인디케이터 + 권한 다이얼로그(sticky 정책 도입) | 완료 |
| 3c-3 | 알림 설정 화면 + 카테고리 on/off + CF 게이트 + 배너 3-state | 완료 (`a559a75`, `eeab9bc`) |
| **3c-4 (본 spec)** | **권한 재권유 정책 (`laterCount`) + 배너 CTA 2단계 통합** | 설계 |

### 영향 범위

| 영역 | 내용 |
|---|---|
| 화면 | `NotificationSettingsPage` (CTA 동작), `OwnerOrdersPage` (배너 노출 게이트), `ScaffoldWithNav` / `OwnerScaffold` (다이얼로그 노출 게이트 + 결과 기록) |
| Widget | `NotificationPermissionBanner` (`denied` state 카피 · CTA 라벨 변경) |
| Provider | `notification_providers.dart` — 신규 UseCase provider 1개 |
| Domain Entity | `UserEntity` 필드 1개 추가, `NotificationPermissionPromptState` 신규 |
| UseCase | `ShouldShowNotificationPermissionDialogUseCase` 신규 1개 |
| Repository Interface | `UserRepository` — 메서드 1개 신설, 1개 시그니처 교체 |
| DataSource | `UserRemoteDataSource` — 메서드 1개 신설, 1개 교체 |
| Model | `UserModel` 필드 1개 + `fromFirestore` 파싱 1줄 |
| Repository Impl | `UserRepositoryImpl` 위임 2건 |
| Firebase | Firestore `users/{uid}` 필드 1개 추가. **Cloud Functions 변경 없음** |
| 공통 컴포넌트 | 신규 — scaffold 2곳 중복 로직을 공통 flow 헬퍼로 추출 |
| 라우팅 | 변경 없음 |
| 권한 / 환경 설정 | `firestore.rules` 화이트리스트 +1 (1줄) |
| 테스트 | 라이브 시나리오 전면 재설계 (Android `notDetermined` 불가 전제) |
| 문서 | `docs/processes/data_ownership.md`, `docs/processes/role_flows.md` |

### 비범위

이번 작업에서 **제외**하는 항목과 사유:

| 제외 항목 | 사유 |
|---|---|
| 시간 기반 쿨다운 (`lastPromptedAt` 등) | 사용자 확정 결정 1 — 필드/검증 경우의 수를 줄이기 위해 횟수 제한만 사용 |
| 기존 `prompted=true` 사용자의 소급 구제 / 마이그레이션 스크립트 | 결정 C 참조. allow/later 구분 정보가 영구 소실되어 복구 불가 |
| Android `notDetermined` 복원을 위한 플러그인 포크 / 네이티브 패치 | 유지보수 비용 > 가치. 결정 E 의 배너 통합으로 사용자 체감 영향이 제거됨 |
| `SharedPreferences` 등 로컬 영속 가드 | 결정 F 참조. OS 권한 카운터와 동기화 불가능하여 가치 없음 |
| 알림 카테고리 추가 (`refundResult` 등) | 별도 후속 과제 |
| 다이얼로그(`NotificationPermissionDialog`) 카피 · 레이아웃 · 반환값 변경 | 재노출 정책만 바뀌고 다이얼로그 자체는 그대로 유효. 변경 0 |
| Cloud Function 측 변경 | `laterCount` 는 클라이언트 전용 정책 필드. CF 는 read 조차 하지 않음 |
| 설정 화면 최초 진입 시 토큰 reconcile (sub-phase 3 관찰사항 ③) | 범위 밖. 별도 후속 |

---

## 사전 확인 결과 (architect 코드 점검)

설계 전 실제 코드를 직접 확인한 결과. developer / tester 는 이 표를 전제로 작업한다.

| 확인 항목 | 결과 |
|---|---|
| `getNotificationPermissionPrompted` 호출처 | **3곳** — `scaffold_with_nav.dart:59`, `owner_scaffold.dart:52`, **`owner_orders_page.dart:71`** (test_report 가 언급하지 않은 세 번째 호출처. 결정 D 에서 다룬다) |
| `markNotificationPermissionPrompted` 호출처 | 2곳 — `scaffold_with_nav.dart:90`, `owner_scaffold.dart:83` |
| 다이얼로그 반환값 | `showNotificationPermissionDialog` → `Future<String?>`, `'allow'` / `'later'` / `null`(dedup·context 만료) |
| 설정 화면 CTA 분기 | `notification_settings_page.dart:265` — `denied` → `_openAppSettings()`, `notDetermined` → `_requestPermission(uid)` |
| `_requestingPermission` | `_NotificationSettingsPageState` 로컬 bool, `finally` 에서 해제, 배너 `isRequesting` 으로 전달 → CTA 비활성 + 16x16 스피너 |
| `NotificationPermissionStatus` | domain enum 4값 (`authorized` / `denied` / `provisional` / `notDetermined`) — 변경 없음 |
| `firestore.rules:90` | `onlyChangedFields(['role','displayName','photoUrl','fcmToken','fcmTokenUpdatedAt','notificationPermissionPrompted','notificationSettings','updatedAt','brandId'])` — 여기에 1개 추가 |
| `onlyChangedFields` 판정 단위 | top-level `affectedKeys()` 기준 (sub-phase 3 A-6 확인). `FieldValue.increment` 도 top-level 키 1개로 집계되어 통과 |
| `UserModelFirestoreX.toFirestoreForCreate()` | `uid/email/displayName/photoUrl/provider/role/createdAt` 만 기록. 알림 관련 필드는 쓰지 않음 → 신규 필드도 **추가하지 않는다** |
| CF 가 `notificationPermissionPrompted` 를 읽는가 | **아니오** (`functions/src/` grep 0건). 의미 변경이 서버에 파급되지 않음 |

---

## architect 결정 (A ~ G)

사용자 확정 2건은 **[확정]**, architect 판단은 **[추천]** 으로 표기한다. 추천 항목은 §사용자 확인 필요 항목 참조.

### 결정 A. 재노출 정책 = `laterCount` 횟수 제한 **[확정]**

| 항목 | 값 |
|---|---|
| Firestore 필드명 | `notificationPermissionLaterCount` |
| 타입 | `number` (정수) |
| 기본값 (필드 부재 시) | `0` |
| 쓰기 주체 | 본인만 (클라이언트 SDK, `FieldValue.increment(1)`) |
| 최대 재노출 | **총 3회 노출까지** → 상수 `kMaxNotificationPermissionPrompts = 3` |
| 증가 시점 | 다이얼로그 결과가 `'later'` 일 때만 |

필드명은 기존 `notificationPermissionPrompted` 와 접두어를 맞춘다 (`users/{uid}` 의 알림 권한 정책 필드 군집). 짧은 `laterCount` 는 다른 도메인의 "나중에" 와 혼동될 여지가 있어 쓰지 않는다.

**카운트 의미 정의 (경계 명확화)**: `laterCount` 는 "**`나중에` 를 선택한 횟수**" 다. 따라서 `laterCount == 0` → 1회차 노출, `1` → 2회차, `2` → 3회차, `3` → **노출 중단**. 즉 노출 가드는 `laterCount >= kMaxNotificationPermissionPrompts` 이며, 총 노출 횟수는 최대 3회다.

**증가 방식**: `FieldValue.increment(1)` 을 사용한다. 클라이언트가 현재 값을 읽어 `+1` 해서 쓰는 방식은 다중 기기 동시 로그인 시 lost update 가 발생하고, 노출 횟수를 과소 집계해 재노출이 늘어난다.

### 결정 B. `notificationPermissionPrompted` 와의 관계 = **의미 변경 (필드 유지, 신규 필드 없음)** [추천]

| 옵션 | 판단 |
|---|---|
| (A) 기존 필드 폐기 + 신규 필드 2개(`promptOutcome`, `laterCount`) | ❌ 필드 3개(폐기 1 + 신규 2) 상태가 남고, 기존 필드를 읽지 않게 되면 기존 `prompted=true` 사용자가 **재노출 대상으로 승격**된다 (결정 C 와 충돌). Rules 화이트리스트도 2개 추가 |
| **(B) 기존 필드 유지 + 의미 좁히기 + `laterCount` 1개 추가** [추천] | ✅ 필드 2개. 기존 `prompted=true` 가 그대로 "재노출 제외" 가드로 계속 작동 → **마이그레이션 0**. Rules 추가 1건 |
| (C) 기존 필드 유지 + 의미 유지 + `laterCount` 로만 제어 | ❌ `prompted` 가 여전히 `later` 에도 `true` 가 되면 F-2 가 그대로 남는다. 기각 |

채택 = **(B)**.

**새 의미 정의**

| 필드 | 이전 의미 | **새 의미** |
|---|---|---|
| `notificationPermissionPrompted` | 다이얼로그를 노출한 이력 (결과 무관) | **OS 권한 시트를 소진했다** — 사용자가 `허용` 을 선택해 `requestPermission()` 까지 진행됐다 |
| `notificationPermissionLaterCount` | — | `나중에` 를 선택한 횟수 |

**필드명을 바꾸지 않는 이유**: 리네임은 기존 doc 과의 호환을 위해 양쪽 키를 읽는 fallback 코드를 요구하고, Rules 화이트리스트에도 구/신 2개를 남겨야 한다. 의미 변경은 `prompted=true` 의 **동작상 효과(재노출 제외)가 이전과 동일**하므로 리네임의 비용을 지불할 가치가 없다. 단 **Dart doc comment 와 `data_ownership.md` 의 설명을 새 의미로 반드시 갱신**한다 (요구사항 F14/F15).

**기록 분기 (핵심 수정)**

| 다이얼로그 결과 | OS 요청 | `prompted` | `laterCount` |
|---|---|---|---|
| `'allow'` | 수행 | **`true` 로 set** | 변경 없음 |
| `'later'` | 미수행 | **변경 없음** (`false` 유지) | **`increment(1)`** |
| `null` (dedup / context 만료) | 미수행 | **변경 없음** | **변경 없음** [추천 — Q7] |

`'allow'` 를 선택했으나 OS 가 `denied` 를 반환한 경우에도 `prompted = true` 다. 시트가 소진됐거나(iOS 1회 / Android 2회) 이미 영구 차단된 상태이므로 다이얼로그 재노출의 효과가 0 이다. 이 집단은 설정 화면 배너로 유도한다.

`null` 은 **사용자의 선택이 아니다**. `DialogQueueService` 의 dedup 또는 context 만료로 다이얼로그가 표시조차 되지 않았을 수 있으므로 카운트를 소모시키지 않는다. 결과적으로 다음 진입 시 같은 차수로 다시 노출된다 — 기존 동작(`null` 에도 `prompted=true` → 영구 차단)보다 명백히 개선이다.

### 결정 C. 기존 `prompted=true` 사용자 = **재노출 대상에서 제외 (영구 비노출 유지)** [추천]

이 집단은 `laterCount` 필드가 없고(→ `0`), `prompted=true` 이며, **allow / later 구분 정보가 영구히 소실**된 상태다. 어떤 설계로도 복구 불가능하므로 양자택일이다.

**결정: 제외한다.** 결정 B 의 가드 순서(`prompted == true` → 즉시 중단)가 이를 자동으로 보장하며, 추가 코드나 마이그레이션이 필요 없다.

**사유**

1. **오류 비용이 비대칭이다.**
   - 잘못 **포함**했을 때 → `허용` 을 눌렀고 OS 시트에서 명시적으로 거부한 사용자(= 거부 의사를 두 번 표현한 사용자)에게 다이얼로그를 다시 띄운다. 그들에게 재노출은 **효과가 0**(시트 소진)이면서 동시에 **침해적**이다. 되돌릴 수 없다.
   - 잘못 **제외**했을 때 → `나중에` 를 눌렀던 기존 사용자가 자동 재권유를 받지 못한다. 그러나 이들은 **막다른 길에 있지 않다**: sub-phase 3 이 `더보기 > 알림 설정` 명시 경로를 이미 공급했고, 본 sub-phase 의 결정 E(배너 CTA 통합)로 그 경로가 **플랫폼 무관 2탭**으로 단축된다.
2. **대상 규모가 작다.** 현재 pre-release / 내부 검증 단계이며 기존 사용자 수가 극소수다. 소급 복구에 설계 복잡도를 지불할 근거가 없다.
3. **마이그레이션 0 원칙 유지.** sub-phase 3 의 "필드 부재 → 기본값 fallback" 원칙과 정확히 동일하게, 기존 doc 을 한 건도 건드리지 않는다.

> **따라서 본 sub-phase 의 재노출 정책은 배포 이후 신규로 `나중에` 를 선택한 사용자에게만 적용된다.** tester 는 기존 계정으로 재노출을 검증할 수 없고, 반드시 Firestore 필드를 직접 세팅하거나 신규 계정을 써야 한다 (§테스트 시나리오 T-R 계열).

### 결정 D. 다이얼로그 노출 가드 = 3단 가드 (`prompted` → `laterCount` → **OS 권한 상태**) [추천]

```
1. uid == null                                  → 중단
2. prompted == true                             → 중단   (OS 시트 소진)
3. laterCount >= 3                              → 중단   (재노출 한도 소진)
4. osStatus ∈ {authorized, provisional}         → 중단   ← 신규 가드
5. → 다이얼로그 노출
```

**4번 가드를 신설하는 이유**

- 이미 알림이 허용된 사용자에게 "알림을 받으시겠어요?" 를 띄우는 것은 무의미하다. 사용자가 OS 설정에서 직접 권한을 켠 경우(sub-phase 3 T11 경로)나, `markNotificationPermissionPrompted` write 가 실패한 경우에 발생할 수 있다.
- `laterCount` 로 재노출이 열리면서 이 케이스의 발생 확률이 처음으로 유의미해진다. 가드 없이는 "알림을 이미 받고 있는데 알림을 켜라는 다이얼로그가 또 뜬다" 는 결함이 신설된다.

> ⚠️ **가드 조건을 `osStatus != notDetermined → 중단` 으로 쓰면 안 된다.** Android 는 `notDetermined` 를 반환할 수 없으므로(F-1) 그 조건은 **Android 에서 다이얼로그를 영구히 차단**한다. 반드시 `authorized` / `provisional` 의 **포함(allowlist) 판정**으로 작성한다. 이 판정은 두 플랫폼에서 모두 정확하다.

**`OwnerOrdersPage` 회귀 차단 (세 번째 호출처)**

`owner_orders_page.dart:71` 은 주문 접수 화면의 `denied` 배너를 `prompted == true` 를 전제로 노출한다. 그 전제의 **원래 의도는 "권한 다이얼로그를 한 번이라도 본 사용자"** 이다. 결정 B 로 `prompted` 의 의미가 좁아지면 `나중에` 사용자는 `prompted == false` 가 되어 **이 배너를 보지 못하는 신규 회귀**가 발생한다.

→ 게이트를 `hasSeenDialog == (prompted || laterCount > 0)` 로 교체한다. 이 판정은 도메인 정책이므로 `NotificationPermissionPromptState` 의 getter 로 캡슐화하여 세 호출처가 같은 정의를 공유하게 한다.

### 결정 E. 배너 CTA = 요청 먼저 시도 → 설정 폴백 **[확정]** + `denied` state 카피 통합 [추천]

#### E-1. CTA 동작 — `denied` / `notDetermined` **동일 핸들러**

현재는 state 별로 다른 동작(`denied` → 설정 앱 / `notDetermined` → 권한 요청)이다. 이를 하나로 합친다.

```
CTA 탭
 → _requestingPermission = true
 → (요청 전 상태 스냅샷 statusBefore = _osStatus 를 보관)
 → 세션 내 요청 시도 이력이 있으면(결정 F) → 요청 건너뛰고 설정 앱 열기 → 종료
 → RequestNotificationPermissionUseCase.call()
     ├─ authorized / provisional
     │    → RegisterFcmTokenUseCase.call(uid)
     │    → _refreshOsStatus()   → 배너 소멸 + 하단 안내 노출. 설정 앱 열지 않음
     └─ denied
          → _refreshOsStatus()   → 배너를 denied state 로 갱신
          → statusBefore 에 따라 폴백 분기 (E-2)
 → finally: _requestingPermission = false
```

`_requestingPermission` 은 **요청 + 폴백 판정 + 설정 앱 호출을 모두 감싼다**. 즉 `finally` 는 `AppSettings.openAppSettings()` 호출 **이후**에 해제된다. 중간에 해제하면 설정 앱 전환 직전의 짧은 구간에 CTA 가 다시 탭 가능해져 중복 요청이 발생한다.

#### E-2. 설정 앱 폴백 시점 — 요청 **전** 상태로 분기

| 요청 전 `_osStatus` | 결과 `authorized`/`provisional` | 결과 `denied` |
|---|---|---|
| `notDetermined` (iOS 전용) | 토큰 등록 + 배너 소멸 | 배너를 `denied` 로 전환. **설정 앱 열지 않음** |
| `denied` | 토큰 등록 + 배너 소멸 (Android "실제로는 미요청" 집단의 2탭 완료 경로) | **설정 앱 열기** |

**`notDetermined` 에서 폴백하지 않는 이유**: 이 상태에서는 OS 시트가 **반드시** 뜬다. 따라서 돌아온 `denied` 는 사용자가 방금 시트에서 명시적으로 거부한 결과다. 그 직후 설정 앱으로 전환하는 것은 사용자 의사를 무시하는 침해적 동작이다.

**`denied` 에서 폴백하는 이유**: 이 상태는 "OS 미요청(Android)" 과 "이미 거부됨" 이 합쳐진 값이다. `denied` 결과가 (a) 시트가 뜨지 않아 즉시 반환된 것인지 (b) 시트가 떴고 사용자가 거부한 것인지는 **플랫폼 API 로 구분할 수 없다**. 그럼에도 폴백이 타당한 근거:
- 요청 전 `denied` 에서 CTA 를 탭했을 때의 **기존(sub-phase 3) 동작은 무조건 설정 앱 열기**였다. 따라서 폴백은 **회귀가 아니라 기존 동작의 보존**이고, 운 좋게 시트가 떠서 허용되면 그만큼 순수 이득이다.
- 경과 시간 측정(`Stopwatch` + 임계값)으로 (a)/(b) 를 추정하는 휴리스틱은 **채택하지 않는다**. 기기 성능·애니메이션 속도에 따라 임계값이 흔들려 오판정이 발생하고, 오판정의 결과가 "거부한 직후 설정 앱으로 끌려감"(= 피하려던 바로 그 문제)이어서 순이득이 음수일 수 있다. 결정론적 규칙을 택한다.

폴백 직전에는 전환 이유를 알리는 안내 SnackBar 를 1회 노출한다 (카피는 designer 확정, §designer 전달사항).

#### E-2 개정 (2026-10-21, 라이브 검증 중 확정) — **1회차 탭에서는 전환하지 않는다**

위 E-2 원안은 `요청 전 denied` + `결과 denied` 에서 **즉시** 설정 앱으로 전환했다. 라이브에서 직접 확인한 결과, 사용자가 OS 시트에서 `거부` 를 누른 **0.5초 뒤 설정 앱으로 끌려가는** 동작이 되며, 이는 거절 의사를 무시하는 것으로 읽힌다. 같은 "방금 거절"인데 iOS(`notDetermined` 경로)에서는 전환하지 않아 **플랫폼 간 일관성도 없었다**.

원안의 근거("기존 동작의 보존")는 유효하나, 보존 대상인 그 기존 동작 자체가 침해적이었다는 것이 판단의 수정 지점이다.

**개정 규칙** — 전환 여부를 `statusBefore` 가 아니라 **탭 차수**로 가른다.

| 탭 | 동작 |
|---|---|
| 1회차 | `requestPermission()` 시도. 결과 `denied` 이고 `statusBefore == denied` 면 **안내 SnackBar 만** (전환 없음) |
| 2회차 이후 | 기존 세션 가드(`_permissionRequestAttempted`)가 요청을 건너뛰고 **안내 + 500ms + 설정 앱** |

`statusBefore == notDetermined` 에서의 거부는 원안대로 **안내도 전환도 하지 않는다** (배너 톤 변화가 피드백).

**이 규칙이 성립하는 이유**: 영구 차단된 사용자는 1회차에 아무 시트도 못 보지만 안내 SnackBar 로 경로를 알게 되고, 재탭하면 세션 가드가 설정 앱으로 보낸다. 즉 **2탭이면 도달**하므로 "죽은 버튼" 문제(F-1 이 고치려던 바로 그것)는 재발하지 않는다. 경과 시간 휴리스틱을 쓰지 않고 **탭 횟수라는 결정론적 신호**만 쓴다는 원안의 원칙도 그대로 지킨다.

구현: `_fallbackToAppSettings()` 를 `_showSettingsHint()`(안내만)와 `_fallbackToAppSettings()`(안내 + 전환, 2회차 전용)로 분리.
검증: T-B6 개정판으로 라이브 PASS (§라이브 검증 결과).

#### E-3. `denied` 배너 카피 변경 [추천 — Q4]

CTA 가 앱 내 요청을 먼저 시도하게 되면서, 현재 `denied` 카피가 **F-1 집단에게 사실과 다른 문장**이 된다. Android 에서 "OS 에 한 번도 요청하지 않은" 사용자가 이 배너를 보는데, 그들의 알림은 기기 설정에서 "꺼진" 것이 아니며 `설정 열기` 는 불필요하게 과한 요구를 시사한다.

| 요소 | 현재 | **변경** |
|---|---|---|
| 제목 | `기기 설정에서 알림이 꺼져 있어요` | `알림이 꺼져 있어요` |
| 본문 (customer) | `알림을 받으려면 기기 설정에서 Qradar 알림을 허용해 주세요.` | `알림을 켜면 주문 진행 상황을 바로 받아볼 수 있어요.` |
| 본문 (owner) | (동일 문장 공용) | `알림을 켜면 새 주문과 환불 요청을 바로 받아볼 수 있어요.` |
| CTA 라벨 | `설정 열기` | `알림 켜기` |
| 톤 | `AppColors.warning` | **`warning` 유지** |
| 아이콘 | `notifications_off_outlined` | 유지 |

- 제목에서 "기기 설정에서" 를 제거하면 두 집단(미요청 / 실제 거부)에 모두 참인 문장이 된다.
- 본문은 `notDetermined` 배너와 달리 **owner / customer 분기를 신설**한다 (현재 `denied` 는 분기 없이 공용 문장).
- 톤은 `warning` 유지: 원인과 무관하게 "지금 알림이 오지 않는다" 는 사실은 동일하며, `info` 로 낮추면 그 사실의 긴급도가 흐려진다.
- `notDetermined` 배너(`알림을 켜 보세요` / `알림 켜기` / `info`)는 **변경 없음**.

**부수 효과 — F-1 의 사용자 체감 영향 제거**: 변경 후 두 state 의 차이는 **톤과 제목 한 줄**뿐이고 CTA 라벨·동작은 동일하다. 따라서 Android 에서 `notDetermined` 에 도달할 수 없다는 플러그인 제약은 **사용자 경험에 더 이상 차이를 만들지 않는다**. 이것이 플러그인 포크를 비범위로 두는 근거다 (§비범위).

### 결정 F. Android OS 거부 카운터 소모 = **감수 + 화면 세션 단위 로컬 가드** [추천]

Android 13+ `POST_NOTIFICATIONS` 는 **2회 거부 시 영구 차단**되며, 이후 `requestPermission()` 은 시트 없이 즉시 `denied` 를 반환한다. 결정 E 의 CTA 는 이 카운터를 소모한다.

**감수하는 이유**

1. **경로를 잃지 않는다.** 영구 차단된 뒤에도 `requestPermission()` 은 즉시 `denied` 를 반환하고, 결정 E-2 의 규칙(`요청 전 denied` + `결과 denied` → 설정 앱)이 그대로 폴백을 수행한다. 즉 최악의 결과가 **현재 sub-phase 3 동작과 동일**하며, 그보다 나빠지지 않는다.
2. 소모 주체가 **사용자의 명시적 탭**이다. 자동 호출이나 백그라운드 요청이 아니다.
3. 카운터를 보존하는 유일한 대안은 "앱 내 요청을 전혀 하지 않기"(= F-1 을 고치지 않기)이며, 그것이 본 sub-phase 의 목적과 정면으로 충돌한다.

**가드 — `laterCount` 와 완전히 별개**

`laterCount` 는 다이얼로그 재노출 횟수를 제어하며, OS 카운터와 아무 관계가 없다 (다이얼로그는 OS 를 호출하지 않는다). OS 카운터 보호는 별도 가드로 처리한다.

| 항목 | 값 |
|---|---|
| 가드 | `_permissionRequestAttempted` — `_NotificationSettingsPageState` **로컬 bool** |
| 의미 | 이 화면 인스턴스에서 `requestPermission()` 을 이미 1회 호출했고 허용되지 않았다 |
| 효과 | 이후 CTA 재탭 시 **요청을 건너뛰고 곧바로 설정 앱을 연다** |
| 리셋 | 화면을 벗어나면 리셋 (영속화하지 않음). 허용에 성공하면 배너 자체가 사라짐 |

**영속화하지 않는 이유**: OS 권한 카운터 값을 읽을 수 있는 API 가 없어 우리 쪽 카운터는 OS 와 **동기화가 불가능**하다. 사용자가 OS 설정에서 알림을 켰다 끄면 즉시 어긋나고, 그 상태로 영속된 가드는 "시트를 띄울 수 있는데 띄우지 않는" 거짓 음성을 만든다. 화면 재진입은 사용자의 새로운 명시적 의사 표현이므로 리셋이 타당하다.

> Android 의 OS 거부 1회는 이 가드 하에서 **화면 진입 1회당 최대 1회**만 소모된다. 즉 "영구 차단" 에 도달하려면 사용자가 알림 설정 화면에 두 번 들어가 두 번 CTA 를 탭하고 두 번 거부해야 한다.

### 결정 G. 로직 중복 제거 = scaffold 2곳 → 공통 flow 헬퍼 1개 [추천]

`ScaffoldWithNav._checkAndRequestNotificationPermission` 과 `OwnerScaffold._checkAndRequestNotificationPermission` 은 **`audience` 한 값만 다른 동일 코드**다. 본 sub-phase 는 여기에 가드 2개 + 결과 분기 기록을 추가하므로, 중복을 유지하면 한쪽만 고치는 drift 위험이 현실적이다 (실제로 F-2 는 두 파일에 동일하게 존재했다).

→ `lib/presentation/common/notification/notification_permission_prompt_flow.dart` 신규. 두 scaffold 는 이 함수를 `audience` 만 바꿔 호출한다.

---

## 요구사항

### 기능 요구사항

#### 데이터 모델 (Domain · Data)

- [ ] **F1** `NotificationPermissionPromptState` 신규 — `lib/domain/entities/notification_permission_prompt_state.dart`. 필드 `prompted` (`bool`, 기본 `false`), `laterCount` (`int`, 기본 `0`). freezed 사용 (기존 entity 선례).
- [ ] **F2** `NotificationPermissionPromptState` 에 getter 2개:
  - `bool get hasSeenDialog => prompted || laterCount > 0;` — 다이얼로그 노출 이력 (결정 D, `OwnerOrdersPage` 게이트)
  - `bool get canPromptAgain => !prompted && laterCount < kMaxNotificationPermissionPrompts;` — 재노출 가능 여부 (OS 상태는 포함하지 않음)
- [ ] **F3** 상수 `kMaxNotificationPermissionPrompts = 3` — 동일 파일에 top-level 상수로 선언. presentation 에 하드코딩 금지.
- [ ] **F4** `UserEntity` 에 `@Default(0) int notificationPermissionLaterCount` 추가. doc comment 에 "`나중에` 선택 횟수. 부재 시 0 fallback" 명시.
- [ ] **F5** `UserEntity.notificationPermissionPrompted` 의 doc comment 를 **새 의미로 교체** — 현재 `/// 알림 권한 다이얼로그 노출 이력 (재요청 방지).` → "OS 권한 시트 소진 이력 (다이얼로그에서 `허용` 선택). 재노출 제외 가드." 취지로 변경.
- [ ] **F6** `UserModel` 에 동일 필드 추가. `@JsonKey(includeFromJson: false, includeToJson: false)` + `@Default(0)` — 기존 `notificationPermissionPrompted` 와 동일 처리.
- [ ] **F7** `UserModelFactory.fromFirestore` 에 방어적 파싱 추가. `data['notificationPermissionLaterCount']` 가 `num` 이면 `.toInt()`, 아니면(부재 / 문자열 / null) **`0`**. Firestore 의 정수는 `int` 로 오지만 `num` 체크로 `double` 저장 케이스까지 흡수한다. 음수는 `0` 으로 clamp 한다.
- [ ] **F8** `UserModelX.toEntity()` 에 필드 전달 추가.
- [ ] **F9** `toFirestoreForCreate()` 에는 **추가하지 않는다** — `users.create` Rules 제약 및 sub-phase 3 선례와 동일. 첫 `나중에` 선택 시 `increment` 로 생성된다.

#### Repository · DataSource (Domain · Data)

- [ ] **F10** `UserRepository.getNotificationPermissionPrompted(String uid): Future<bool>` 를 **`getNotificationPermissionPromptState(String uid): Future<NotificationPermissionPromptState>` 로 교체**한다. 기존 메서드는 제거한다 (호출처 3곳 전부 수정하므로 유지할 이유 없음).
- [ ] **F11** `UserRepository.incrementNotificationPermissionLaterCount(String uid): Future<void>` 신규.
- [ ] **F12** `UserRemoteDataSource.getNotificationPermissionPromptState` — `_doc(uid).get()` 1회로 두 필드를 함께 읽는다. doc 부재 시 기본값 state 반환. **read 횟수는 기존과 동일(1회)**.
- [ ] **F13** `UserRemoteDataSource.incrementNotificationPermissionLaterCount` — `update({'notificationPermissionLaterCount': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()})`.
- [ ] **F14** `markNotificationPermissionPrompted` 는 **시그니처·구현 변경 없음**. DataSource / Repository 양쪽의 doc comment 를 새 의미(= `허용` 선택 시에만 호출)로 갱신하고, "`나중에` 에는 호출하지 않는다" 를 명시한다.
- [ ] **F15** `UserRepositoryImpl` 에 F10~F13 위임 추가 / 교체.

#### UseCase (Domain)

- [ ] **F16** `ShouldShowNotificationPermissionDialogUseCase` 신규 — `lib/domain/usecases/should_show_notification_permission_dialog_use_case.dart`.
  - 의존: `UserRepository`
  - `Future<bool> call({required String uid, required NotificationPermissionStatus osStatus})`
  - 판정 순서: ① `osStatus ∈ {authorized, provisional}` → `false` (**OS 상태를 먼저 보아 Firestore read 를 절약**) ② `getNotificationPermissionPromptState(uid)` ③ `state.canPromptAgain` 반환
  - 예외는 **전파**한다 (호출부에서 catch → skip. 요구사항 F21)
- [ ] **F17** 기록용 신규 UseCase 는 **만들지 않는다**. `markNotificationPermissionPrompted` / `incrementNotificationPermissionLaterCount` 는 flow 헬퍼가 `userRepositoryProvider` 를 통해 직접 호출한다 — 기존 scaffold 패턴과 동일하며, 단일 repository 호출을 감싸는 UseCase 는 가치가 없다.
- [ ] **F18** `notification_providers.dart` 에 `shouldShowNotificationPermissionDialogUseCaseProvider` 추가.

#### 다이얼로그 노출 흐름 (Presentation)

- [ ] **F19** `notification_permission_prompt_flow.dart` 신규 — 공통 함수 (결정 G).
  - 시그니처(권고): `Future<void> runNotificationPermissionPrompt({required BuildContext context, required WidgetRef ref, required NotificationDialogAudience audience, required bool Function() isMounted})`
  - `isMounted` 를 주입하는 이유: 호출부가 `ConsumerState` 이고 `mounted` 체크가 호출부 생명주기에 묶여 있다. 헬퍼 내부에서 `context.mounted` 만 쓰면 state dispose 후 `ref` 접근이 가능해진다. developer 가 더 적절한 형태를 찾으면 대체 가능하되, **다이얼로그 전후 / 비동기 경계마다 mounted 체크가 보존되어야 한다**.
  - 로직:
    1. `uid` 조회 (`authProvider`). null → return
    2. `osStatus = pushNotificationRepository.getPermissionStatus()`
    3. `shouldShow = shouldShowNotificationPermissionDialogUseCase(uid: uid, osStatus: osStatus)` → false 면 return
    4. mounted 체크 후 `showNotificationPermissionDialog(context, audience: audience, queue: ...)`
    5. 결과 분기 (결정 B 표):
       - `'allow'` → `requestNotificationPermissionUseCase()` → `authorized`/`provisional` 이면 `registerFcmTokenUseCase(uid)` → **그 후** `markNotificationPermissionPrompted(uid)`
       - `'later'` → `incrementNotificationPermissionLaterCount(uid)`
       - `null` → **아무것도 하지 않는다**
- [ ] **F20** `ScaffoldWithNav._checkAndRequestNotificationPermission` / `OwnerScaffold._checkAndRequestNotificationPermission` 의 본문을 F19 호출로 교체한다. `initState` 의 `addPostFrameCallback` 패턴은 유지.
- [ ] **F21** flow 헬퍼 전체를 `try/catch` 로 감싸 **예외를 삼킨다** (로그만). 현재 코드는 `getNotificationPermissionPrompted` 가 throw 하면 unhandled async error 가 된다 — 부수적 결함 수정. 다이얼로그를 띄우지 못하는 것이 앱 진입을 막아선 안 된다.

#### `OwnerOrdersPage` 배너 게이트 (Presentation)

- [ ] **F22** `_refreshNotificationBanner` 의 게이트를 `getNotificationPermissionPromptState(uid)` → `state.hasSeenDialog` 로 교체한다 (결정 D 의 회귀 차단). `hasSeenDialog == false` 면 기존대로 배너 숨김.
- [ ] **F23** 이 화면의 배너(`NotificationDeniedBanner`)와 그 CTA 동작은 **변경하지 않는다** — 본 sub-phase 의 CTA 2단계 변경은 **알림 설정 화면의 `NotificationPermissionBanner` 에만** 적용한다. 사유: 주문 접수 화면은 알림을 켜는 전용 화면이 아니며, 그 화면에서 OS 시트를 띄우면 주문 처리 흐름을 끊고 결정 F 의 화면 세션 가드와도 분리 관리가 필요해진다. 그 배너는 **설정 화면으로 유도하는 역할**로 유지한다.

#### 알림 설정 화면 CTA (Presentation)

- [ ] **F24** `_osStatus` 가 `denied` / `notDetermined` 일 때 CTA 핸들러를 **단일 메서드로 통합**한다 (예: `_onPermissionCtaTap(uid)`). `notification_settings_page.dart:265` 의 state 별 삼항 분기를 제거한다.
- [ ] **F25** 통합 핸들러는 결정 E-1 의 순서를 따른다. 요청 전 `_osStatus` 를 **로컬 변수로 스냅샷** 한 뒤 비동기 호출을 수행한다 (`_refreshOsStatus()` 가 `_osStatus` 를 덮어쓰므로 폴백 판정이 오염된다).
- [ ] **F26** 폴백 분기는 결정 E-2 표를 그대로 구현한다. `provisional` 결과는 `authorized` 와 동일 취급 (기존 선례).
- [ ] **F27** `_permissionRequestAttempted` 로컬 bool 추가 (결정 F). `requestPermission()` 호출 직전에 `true` 로 set 한다. 이미 `true` 면 요청을 건너뛰고 설정 앱을 즉시 연다. 권한이 허용되면 배너가 사라지므로 명시적 리셋은 불필요하다.
- [ ] **F28** `_requestingPermission` 은 **설정 앱 호출까지 포함한 전 구간**을 감싼다 (결정 E-1). `finally` 에서만 해제. 폴백 경로(요청 건너뛰고 설정 앱만 여는 경우)에도 동일하게 적용한다.
- [ ] **F29** `requestPermission()` 이 **예외를 던지는 경우** → 설정 앱 폴백 + 안내 SnackBar. 권한 조회/요청 실패가 사용자를 막다른 길에 두지 않게 한다.
- [ ] **F30** 설정 화면 CTA 는 `notificationPermissionPrompted` / `notificationPermissionLaterCount` 를 **읽지도 쓰지도 않는다** (sub-phase 3 결정 D-2 의 "명시 경로는 sticky 플래그와 무관" 원칙 유지). 설정 화면에서 권한을 허용한 사용자는 결정 D 의 4번 가드(`authorized` → 중단)가 다이얼로그 재노출을 막는다.

#### 배너 위젯 (Presentation)

- [ ] **F31** `NotificationPermissionBanner` 의 `denied` state 카피를 결정 E-3 표대로 변경한다. 본문은 `isOwner` 분기를 신설한다.
- [ ] **F32** `notDetermined` state 의 카피 · 톤 · 아이콘은 **변경하지 않는다**.
- [ ] **F33** 위젯은 **순수 표시 위젯 유지** — `onPrimaryTap` 1개 콜백 주입 구조를 바꾸지 않는다. state 별 CTA 동작 차이가 사라졌으므로 콜백은 1개로 충분하다.
- [ ] **F34** `isRequesting` 스피너 사양(16x16, strokeWidth 2, `AppColors.onPrimary`, Semantics label)은 유지. **Semantics label 은 `알림 권한을 요청하는 중` 으로 유지**한다 — 폴백 구간도 "요청 처리 중" 의 연속이며, 설정 앱 전환은 SnackBar 로 별도 안내된다.

#### Firestore Rules

- [ ] **F35** `firestore.rules:90` 의 `onlyChangedFields` 배열에 `'notificationPermissionLaterCount'` 를 추가한다. **diff 1줄.** 그 외 어떤 규칙도 변경하지 않는다.
- [ ] **F36** 값 범위 검증(`request.resource.data.notificationPermissionLaterCount is int && >= 0` 등)은 **추가하지 않는다**. 사유: 기존 `notificationPermissionPrompted` 와 동일하게, 이 필드는 **자기 doc 의 자기 재노출 횟수**이므로 조작의 피해자와 가해자가 동일인이고 다른 사용자·매장·주문·금액에 영향이 없다. 클라이언트는 어떤 값이 와도 `num` 체크 + 음수 clamp 로 방어한다 (F7). CF 는 읽지 않는다 (F37).
- [ ] **F37** Cloud Functions 는 이 필드를 **읽지 않는다**. `functions/src/` 변경 0.

#### 문서 갱신

- [ ] **F38** `docs/processes/data_ownership.md` §2.1 `users/{userId}` 행 — `onlyChangedFields` 목록에 `notificationPermissionLaterCount` 추가, "변경 가능" 열에도 추가. 그리고 `notificationPermissionPrompted` 의 설명을 **새 의미**로 갱신한다.
- [ ] **F39** `docs/processes/role_flows.md` §4.1 (고객) / §4.2 (점주) — 알림 권한 다이얼로그 관련 행에 "`나중에` 선택 시 최대 3회까지 재노출. `허용` 선택 후에는 재노출 없음(설정 화면 경유)" 를 반영한다.
- [ ] **F40** `docs/tasks/order_flow_phase3c/3_notification_settings/spec.md` 결정 D-3 표에 본 sub-phase 로 **변경됨** 을 가리키는 1줄 주석을 추가한다 (문서 간 모순 방지). 기존 내용은 이력으로 남긴다.

### UI 요구사항 (designer 위임)

- [ ] **U1** `denied` 배너 카피 확정 — 제목 / 본문(customer · owner) / CTA 라벨. architect 제안은 결정 E-3 표.
- [ ] **U2** `notDetermined` 배너와의 **시각적 구분 유지** — CTA 라벨과 동작이 같아지므로 톤(warning vs info)과 아이콘만으로 구분된다. 이 구분이 충분한지, 아니면 두 state 를 완전히 하나로 합쳐야 하는지 판단.
- [ ] **U3** 설정 앱 폴백 안내 SnackBar 카피 · 톤 확정. architect 제안: `기기 설정에서 알림을 허용해 주세요` / `AppColors.info` 톤 (기존 실패 SnackBar 는 `AppColors.error`). 성공/실패가 아닌 **전환 안내**이므로 error 톤은 부적절.
- [ ] **U4** CTA 로딩 구간이 "앱 내 요청 → (실패 시) 설정 앱 전환" 2단계로 길어진다. 스피너 1개로 전 구간을 덮는 것이 적절한지, 단계별 피드백이 필요한지 판단.
- [ ] **U5** 다이얼로그(`NotificationPermissionDialog`) 카피 · 레이아웃은 **변경 없음** 확정. 재노출 차수에 따른 카피 변화(예: 2회차에 "한 번 더 안내드려요")도 **도입하지 않는다** — 차수를 UI 에 노출하면 사용자가 추적당한다는 인상을 받는다.
- [ ] **U6** `OwnerOrdersPage` 의 `NotificationDeniedBanner` 는 **변경 없음** 확정 (F23).

### 상태 요구사항

- [ ] **S1** loading — CTA 요청 중: 버튼 비활성 + 스피너 (기존 사양). 전 구간(설정 앱 전환 포함) 유지.
- [ ] **S2** error — 권한 요청 예외 / 설정 앱 열기 실패: SnackBar. 배너는 유지되어 재시도 가능.
- [ ] **S3** empty — 해당 없음 (배너 유무로 표현).
- [ ] **S4** 권한 상태 조회 실패 — 기존대로 배너 생략, 토글은 정상 동작 (회귀 금지).
- [ ] **S5** Firestore 기록 실패 (`markNotificationPermissionPrompted` / `increment`) — 사용자에게 노출하지 않는다 (§에러 처리).

---

## 데이터 모델

### Entity

`lib/domain/entities/notification_permission_prompt_state.dart` (신규)

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `prompted` | `bool` | `false` | OS 권한 시트 소진 이력 (`허용` 선택) |
| `laterCount` | `int` | `0` | `나중에` 선택 횟수 |

| getter | 정의 | 용도 |
|---|---|---|
| `hasSeenDialog` | `prompted \|\| laterCount > 0` | `OwnerOrdersPage` 배너 게이트 (F22) |
| `canPromptAgain` | `!prompted && laterCount < kMaxNotificationPermissionPrompts` | 다이얼로그 재노출 가능 여부 (F16) |

top-level 상수: `const int kMaxNotificationPermissionPrompts = 3;`

`UserEntity` 변경: `@Default(0) int notificationPermissionLaterCount` 1개 추가.

### Model / DTO

`UserModel` 에 동일 필드 추가, JSON 직렬화 제외.

`UserModelFactory.fromFirestore` 파싱 규칙:

```
raw = data['notificationPermissionLaterCount']
raw is num  → max(0, raw.toInt())
그 외       → 0
```

`toFirestoreForCreate()` 에는 추가하지 않는다 (F9).

### Firestore 변경

`users/{uid}`:

| 필드 | 타입 | 쓰기 주체 | 비고 |
|---|---|---|---|
| `notificationPermissionLaterCount` | `number` | **본인만** (클라이언트 SDK, `FieldValue.increment(1)`) | 부재 허용 → `0`. CF 는 읽지 않음 |

| 필드 | 변경 | 비고 |
|---|---|---|
| `notificationPermissionPrompted` | **의미 변경** (스키마 변경 없음) | `bool`. 이제 `허용` 선택 시에만 `true` |

**마이그레이션**: 없음. **인덱스**: 없음 (쿼리 대상 아님).

---

## 레이어 설계

### Domain

#### Entity
- `notification_permission_prompt_state.dart` — **신규**. 순수 Dart + freezed. 상수 `kMaxNotificationPermissionPrompts` 동거.
- `user_entity.dart` — **수정**. 필드 1개 + doc comment 2건.
- `notification_permission_status.dart` — **변경 없음**.

#### Repository Interface
`user_repository.dart` — **수정**

| 메서드 | 변경 |
|---|---|
| `getNotificationPermissionPrompted(uid) → Future<bool>` | **제거** |
| `getNotificationPermissionPromptState(uid) → Future<NotificationPermissionPromptState>` | **신규** |
| `incrementNotificationPermissionLaterCount(uid) → Future<void>` | **신규** |
| `markNotificationPermissionPrompted(uid)` | 시그니처 유지, doc comment 갱신 |

#### UseCase
- `should_show_notification_permission_dialog_use_case.dart` — **신규**. 재노출 판정 정책의 단일 진실원. OS 상태를 인자로 받아 **외부 SDK 의존 없이 순수 판정**한다 (domain 순수성 유지).

### Data

#### DataSource
`user_remote_data_source.dart` — **수정**

| 메서드 | 변경 |
|---|---|
| `getNotificationPermissionPrompted` | **제거** |
| `getNotificationPermissionPromptState` | **신규** — `get()` 1회로 두 필드. doc 부재 → 기본값 state |
| `incrementNotificationPermissionLaterCount` | **신규** — `FieldValue.increment(1)` + `updatedAt` serverTimestamp |
| `markNotificationPermissionPrompted` | 변경 없음 (comment 만) |

#### Model
`user_model.dart` — **수정**. 필드 1개 + `fromFirestore` 파싱 + `toEntity` 전달.

#### Repository Implementation
`user_repository_impl.dart` — **수정**. 위임 2건 추가, 1건 제거.
`NotificationPermissionPromptState` 조립은 **DataSource 에서 수행**한다 (dot-path 변환을 DataSource 가 맡는 sub-phase 3 선례와 동일하게, Firestore 원시 타입 → domain 값 객체 변환은 data 레이어 책임).

#### Cloud Functions
**변경 없음.**

### Presentation

#### Page (수정)
- `notification_settings_page.dart` — CTA 통합 핸들러, `_permissionRequestAttempted`, 폴백 분기, 상태 스냅샷.
- `owner_orders_page.dart` — 배너 게이트 1곳 (`hasSeenDialog`).

#### Widget (수정)
- `widgets/notification_permission_banner.dart` — `denied` 카피 + CTA 라벨 + owner/customer 본문 분기.

#### 공통 (신규)
- `common/notification/notification_permission_prompt_flow.dart` — scaffold 2곳 공통 다이얼로그 흐름 (결정 G).

#### Scaffold (수정)
- `common/scaffold_with_nav.dart` / `owner/owner_scaffold.dart` — 본문을 flow 헬퍼 호출로 교체. `initState` + `addPostFrameCallback` 유지.

#### Provider (수정)
- `common/notification/providers/notification_providers.dart` — `shouldShowNotificationPermissionDialogUseCaseProvider` 추가.

### Firestore Rules
`firestore.rules` — `isSelfProfileUpdate` 의 `onlyChangedFields` 배열에 `'notificationPermissionLaterCount'` 1개 추가. 다른 변경 없음.

---

## 데이터 흐름

### A. 앱 진입 — 다이얼로그 노출 판정 (고객 · 점주 공통)

```
ScaffoldWithNav / OwnerScaffold.initState
  → addPostFrameCallback
  → runNotificationPermissionPrompt(audience)
      → authProvider → uid        (null → return)
      → PushNotificationRepository.getPermissionStatus()      [data: FCM SDK]
      → ShouldShowNotificationPermissionDialogUseCase
          ├─ osStatus ∈ {authorized, provisional} → false (Firestore read 없음)
          └─ UserRepository.getNotificationPermissionPromptState(uid)
                → UserRemoteDataSource.get()                  [data: Firestore]
                → state.canPromptAgain
      → false → return
      → true  → showNotificationPermissionDialog(...)
```

### B. 다이얼로그 결과 기록 (F-2 수정의 핵심)

```
result == 'allow'
  → RequestNotificationPermissionUseCase()                    [OS 시트]
      ├─ authorized / provisional → RegisterFcmTokenUseCase(uid)
      └─ denied                   → (아무것도 하지 않음)
  → UserRepository.markNotificationPermissionPrompted(uid)    [prompted = true]

result == 'later'
  → UserRepository.incrementNotificationPermissionLaterCount(uid)
      → update({laterCount: increment(1), updatedAt: serverTimestamp})

result == null
  → (write 없음)
```

### C. 설정 화면 CTA — 요청 먼저, 설정 폴백 (F-1 수정의 핵심)

```
배너 CTA 탭 (denied 또는 notDetermined)
  → statusBefore = _osStatus            (스냅샷)
  → _requestingPermission = true
  → _permissionRequestAttempted == true ?
       YES → openAppSettings() → finally → 종료
       NO  → _permissionRequestAttempted = true
             RequestNotificationPermissionUseCase()
               ├─ authorized / provisional
               │    → RegisterFcmTokenUseCase(uid)
               │    → _refreshOsStatus()        → 배너 소멸 + 하단 안내
               ├─ denied && statusBefore == notDetermined   (iOS: 방금 거부)
               │    → _refreshOsStatus()        → denied 배너로 전환. 설정 앱 X
               └─ denied && statusBefore == denied
                    → _refreshOsStatus()
                    → SnackBar(안내) → openAppSettings()
  → finally: _requestingPermission = false
```

### D. OS 설정 복귀 reconcile (sub-phase 3 D-5 — 변경 없음)

```
didChangeAppLifecycleState(resumed)
  → _refreshOsStatus(reconcile: true)
      → getPermissionStatus() → 배너 state 갱신
      → SyncNotificationTokenUseCase(uid)    (권한 허용 + fcmToken null 일 때만 등록)
```

### E. `OwnerOrdersPage` 배너 게이트

```
_refreshNotificationBanner (initState post-frame / resumed)
  → getNotificationPermissionPromptState(uid)
  → state.hasSeenDialog == false → 배너 숨김, return
  → getPermissionStatus() == denied → 배너 노출
```

---

## 플랫폼별 동작 차이 (반드시 숙지)

F-1 은 iOS 에서 발생하지 않는다. 설계·구현·검증은 아래 차이를 전제로 한다.

| 항목 | iOS | Android |
|---|---|---|
| `AuthorizationStatus.notDetermined` 도달 | **가능** | **불가능** — 네이티브가 `0`/`1` 만 반환 (`FlutterFirebaseMessagingPlugin.java:409`) |
| 발생 가능한 배너 state | `notDetermined` / `denied` / 없음(authorized) | **`denied` / 없음(authorized)** 만 |
| "OS 미요청" 사용자가 보는 배너 | `notDetermined` (info / `알림 켜기`) | **`denied`** (warning / `알림 켜기`) |
| CTA 1차 요청 시 OS 시트 | `notDetermined` 일 때만 뜸 | 미요청 또는 1회 거부 상태에서 뜸 |
| OS 권한 요청 횟수 제한 | 1회 (거부 후 영구 차단) | 2회 거부 후 영구 차단 (`POST_NOTIFICATIONS`) |
| "방금 거부" vs "이미 차단" 구분 | **가능** (`statusBefore == notDetermined` 전제) | **불가능** → 설정 앱 폴백 수용 (결정 E-2) |
| 설정 앱 폴백 발생 경로 | `statusBefore == denied` 인 경우만 | `denied` 결과 전부 |
| 결정 E-3 적용 후 사용자 체감 | 변화 거의 없음 (CTA 라벨만 통일) | **5탭 → 2탭** (미요청 집단), 최악의 경우 기존과 동일 |

`provisional` 은 iOS 전용이며 기존 코드와 동일하게 `authorized` 와 같이 취급한다.

---

## 에러 처리

| 케이스 | 처리 방식 | 사용자 노출 |
|---|---|---|
| `getPermissionStatus()` 실패 (flow) | catch → 다이얼로그 노출 skip. 다음 진입 때 재시도 | 없음 |
| `getNotificationPermissionPromptState()` 실패 | catch → 다이얼로그 노출 skip (**기존 unhandled async error 결함 수정**) | 없음 |
| `markNotificationPermissionPrompted()` 실패 | swallow + 로그. 다음 진입 시 다이얼로그가 1회 더 노출될 수 있으나, 권한이 허용됐다면 결정 D 의 4번 가드가 막는다. 거부됐다면 1회 추가 노출을 수용 | 없음 |
| `incrementNotificationPermissionLaterCount()` 실패 | swallow + 로그. 카운트가 증가하지 않아 같은 차수로 재노출 → **최대 3회 보장이 깨져 그 이상 노출될 수 있다. 수용** (대안인 로컬 캐시는 영속성·동기화 비용이 이득을 초과) | 없음 |
| `requestPermission()` 예외 (설정 화면) | catch → 안내 SnackBar + 설정 앱 폴백 (F29) | SnackBar |
| `requestPermission()` 예외 (flow) | catch → 기록 생략, 흐름 종료 | 없음 |
| `registerFcmToken()` 실패 | 기존대로 swallow (sub-phase 3 선례). `resumed` reconcile 이 복구 | 없음 |
| `AppSettings.openAppSettings()` 실패 | 기존 SnackBar `설정 화면을 열 수 없어요` 유지 | SnackBar |
| `getPermissionStatus()` 실패 (설정 화면) | 기존대로 배너 생략, 토글 정상 (회귀 금지) | 없음 |
| `laterCount` 가 비정상 값 (음수 / 문자열 / 거대값) | F7 파싱에서 `0` 또는 clamp. `canPromptAgain` 이 거대값에 대해 자연히 `false` | 없음 |
| Firestore Rules 거부 (타인 doc) | 발생 불가 경로 (항상 자기 uid). 발생 시 위 swallow 규칙 적용 | 없음 |

**원칙**: 권한 재권유는 **부가 기능**이다. 어떤 실패도 앱 진입, 주문 흐름, 알림 설정 토글을 막아서는 안 된다.

---

## 권한 / 보안

### Firestore Rules
- 변경은 `isSelfProfileUpdate` 화이트리스트 +1 (F35) **단 한 줄**. `uid() == userId` 조건, role 전이 화이트리스트, `brandId` empty→value 제약은 **전부 무변경** → 회귀 없음.
- `onlyChangedFields` 는 top-level `affectedKeys()` 기준이므로 `FieldValue.increment` 도 키 1개로 집계되어 통과한다 (sub-phase 3 A-6 확인 사항).

### 조작 / 악용
- `notificationPermissionLaterCount` 를 사용자가 임의 값으로 바꿀 수 있다 (Rules 값 검증 없음, F36). 영향 범위는 **자기 계정의 다이얼로그 노출 횟수**뿐이며 다른 사용자·매장·주문·금액·알림 발송에 영향이 없다. 기존 `notificationPermissionPrompted` 와 동일한 위험 수준이다.
- CF 가 이 필드를 읽지 않으므로 서버 동작을 조작할 수 있는 표면이 없다.
- 클라이언트는 `num` 체크 + 음수 clamp 로 방어한다 (F7).

### FCM
- 토큰 등록 경로(`RegisterFcmTokenUseCase` / `SyncNotificationTokenUseCase`)는 변경 없음. 호출 **시점**만 늘어난다 (설정 화면 CTA 가 `denied` state 에서도 요청을 시도하므로 허용 성공 시 토큰 등록이 추가로 일어날 수 있음) — 두 UseCase 는 멱등하므로 안전 (sub-phase 3 F11 검증 완료).

---

## 작업 분배

### designer — **호출 필요** (경량)

- **UI 변경 필요 여부**: **있음.** 신규 화면·레이아웃 변경은 없고, **카피 · 톤 · 상태 전이 사양**만 바뀐다.
- **디자인 산출물**: `docs/tasks/order_flow_phase3c/4_notification_permission_retry/design.md`
- **전달 사항**
  1. U1 — `denied` 배너 카피 확정 (제목 / 본문 customer·owner / CTA 라벨). architect 제안: 결정 E-3 표. **CTA 라벨이 `설정 열기` → `알림 켜기` 로 바뀌면서 "버튼을 눌러도 설정 앱으로 안 갈 수 있다" 는 동작 변경이 수반된다** — 카피가 그 2단계를 오해 없이 표현하는지 판단.
  2. U2 — `denied` / `notDetermined` 두 배너의 시각적 구분이 톤 + 제목만으로 충분한지. **두 state 를 완전히 통합하는 안(단일 배너)** 도 검토 대상이다. Android 에서는 `notDetermined` 가 발생하지 않으므로 통합하면 iOS 에서만 톤이 변하는 차이가 사라진다.
  3. U3 — 설정 앱 폴백 안내 SnackBar 카피 · 톤. **error 톤 금지** (실패가 아니라 전환 안내).
  4. U4 — 2단계 로딩(요청 → 설정 앱 전환)을 스피너 1개로 덮는 것의 적절성.
  5. **변경 금지 (회귀 방지)**: `NotificationPermissionDialog`(카피·레이아웃·버튼), `notDetermined` 배너, `OwnerOrdersPage` 의 `NotificationDeniedBanner`, 알림 설정 화면의 토글 영역·섹션 헤더·하단 안내 문구, 진입 타일.
  6. `AppColors` 외 색상 사용 금지. 신규 색상 토큰이 필요하면 design.md 에 명시하고 architect 확인을 받을 것.

### developer — **호출 필요**

- **구현 항목**: F1 ~ F40. designer 의 `design.md` 확정 후 착수 (카피가 F31 에 직접 들어감).
- **재사용할 기존 구조**
  - `RequestNotificationPermissionUseCase` / `RegisterFcmTokenUseCase` / `SyncNotificationTokenUseCase` — **변경 없이 재사용**
  - `showNotificationPermissionDialog` + `DialogQueueService` — **변경 없이 재사용** (반환값 `String?` 유지)
  - `NotificationPermissionBanner` 의 `onPrimaryTap` 단일 콜백 구조 — 유지
  - `UserRemoteDataSource._doc(uid).update({... , 'updatedAt': serverTimestamp})` 패턴
  - `WidgetsBindingObserver` + `addPostFrameCallback` 패턴
- **주의할 레이어 규칙**
  - `NotificationPermissionPromptState` 와 `kMaxNotificationPermissionPrompts` 는 **domain**. presentation 에 `3` 을 하드코딩하지 말 것.
  - `FieldValue` / `cloud_firestore` import 는 **DataSource 에만**. flow 헬퍼·UseCase·entity 에 들어가면 절대 규칙 위반.
  - `notification_permission_prompt_flow.dart` 는 presentation 이므로 `ref` / `BuildContext` 사용 가능하나, Firebase SDK 를 직접 import 하지 말 것.
  - `AppColors` 만 사용. `Color(0x...)` / `Colors.*` 금지.
- **명시적 주의사항**
  1. **F10 의 메서드 교체는 호출처가 3곳**이다 (`scaffold_with_nav` / `owner_scaffold` / **`owner_orders_page`**). 세 번째를 빠뜨리면 컴파일 에러로 드러나지만, F22 의 `hasSeenDialog` 교체를 빠뜨리면 **조용한 회귀**가 된다.
  2. **F25 의 상태 스냅샷**: `_refreshOsStatus()` 가 `_osStatus` 를 덮어쓴다. 폴백 판정은 반드시 로컬 변수에 담아둔 요청 **전** 값으로 한다.
  3. **결정 D 의 4번 가드를 `osStatus != notDetermined` 로 쓰면 Android 에서 다이얼로그가 영구 차단된다.** 반드시 `authorized` / `provisional` 포함 판정으로 작성.
  4. `result == null` 에 어떤 write 도 하지 말 것 (결정 B). 기존 코드가 여기서 `prompted=true` 를 쓰고 있으므로 **삭제 대상**이다.
  5. `markNotificationPermissionPrompted` 호출을 `if (result == 'allow')` 블록 **안**으로 옮긴다. 현재 블록 밖에 있는 것이 F-2 의 직접 원인이다.
  6. scaffold 2곳에서 로직을 복제하지 말 것 (결정 G). 같은 코드를 두 번 쓰면 F-2 와 같은 drift 가 재발한다.
  7. `laterCount` 증가는 **반드시 `FieldValue.increment(1)`** (결정 A). read-then-write 금지.
  8. **단위 테스트 추가** (sub-phase 3 관찰사항 ① 의 부채 상환을 본 범위에서 시작):
     - `NotificationPermissionPromptState.hasSeenDialog` / `canPromptAgain` 의 경계값 (`laterCount` = 0/1/2/3/4, `prompted` = true/false 조합)
     - `UserModelFactory.fromFirestore` 의 `notificationPermissionLaterCount` 파싱 (부재 / `int` / `double` / 문자열 / 음수)
     - `ShouldShowNotificationPermissionDialogUseCase` 의 4값 `osStatus` × state 조합 (fake repository)
  9. `flutter analyze` 무경고, `dart run build_runner build --delete-conflicting-outputs` 재생성(freezed 2개 파일), `flutter test` 통과를 `implementation.md` 에 기록.
- **산출물**: `docs/tasks/order_flow_phase3c/4_notification_permission_retry/implementation.md`

### tester — **호출 필요**

- **주요 검증 기준**: 아래 §테스트 시나리오.
- **반드시 확인할 예외 케이스**
  1. 결정 C 의 기존 사용자 취급 — `prompted=true` + `laterCount` 필드 부재 계정이 **다이얼로그를 보지 않는지**
  2. 결정 D 의 4번 가드 — 권한이 `authorized` 인 상태에서 `laterCount < 3` 이어도 다이얼로그가 뜨지 않는지
  3. `OwnerOrdersPage` 배너 회귀 (F22) — `prompted=false` + `laterCount=1` 점주에게 배너가 뜨는지
  4. sub-phase 3 의 모든 기능 회귀 (토글 저장 / dot-path 보존 / CF 게이트 / reconcile)
- **산출물**: `docs/tasks/order_flow_phase3c/4_notification_permission_retry/test_report.md`

---

## 테스트 시나리오

> ### ⚠️ 설계 전제 — sub-phase 3 의 T9 / T13 보류를 반복하지 않기 위한 규칙
>
> sub-phase 3 에서 T9 는 "Android 에서 `notDetermined` 재현 불가"(F-1), T13 은 "iOS Simulator + APNs 키 미등록으로 점주 토큰 없음" 때문에 보류됐다. 본 sub-phase 의 시나리오는 아래 5개 규칙으로 작성되어 **환경 사유 보류가 발생하지 않는다**.
>
> 1. **Android 에서 `notDetermined` 상태를 요구하는 시나리오를 만들지 않는다.** Android 의 모든 시나리오는 `denied` 배너를 전제로 한다. `notDetermined` 전용 시나리오는 **iOS 전용**으로 분리 표기한다.
> 2. **재노출 횟수 로직은 Firestore 필드 직접 세팅으로 검증한다.** 다이얼로그를 3회 띄우기 위해 실제로 3회 `나중에` 를 누르는 긴 시나리오를 쓰지 않는다. 콘솔에서 `notificationPermissionLaterCount` 를 `0`/`1`/`2`/`3` 으로 세팅 후 앱 **콜드 재시작**하여 노출/미노출을 확인한다. 이 방식에는 플랫폼 제약이 없다.
> 3. **점주 시나리오를 Android 에뮬레이터에서 수행한다.** 점주 계정으로 Android 에뮬레이터에 로그인한다. 본 sub-phase 의 점주 시나리오는 **FCM 메시지 수신을 요구하지 않으므로**(다이얼로그 노출/미노출, 배너 노출, 카운터 증가, 설정 앱 전환) APNs 키 미등록이 걸림돌이 되지 않는다.
> 4. **각 시나리오에 "FCM 수신 필요 여부" 와 "실행 환경" 을 명시한다.** FCM 수신이 필요한 항목은 Android 에서만 수행한다.
> 5. **Android 권한 상태 리셋 절차를 고정한다** (sub-phase 3 F-1 에서 실증된 명령):
>    ```
>    adb shell pm revoke com.example.qradar android.permission.POST_NOTIFICATIONS && adb shell pm clear-permission-flags com.example.qradar android.permission.POST_NOTIFICATIONS user-set user-fixed
>    ```
>    (패키지명은 tester 가 `adb shell pm list packages | grep qradar` 로 확인한다.) 이 절차로 "OS 미요청" 상태가 재현되며, 이때 `requestPermission()` 은 **실제로 OS 시트를 띄운다** → F-1 을 우회하여 본 sub-phase 의 핵심 가치(2탭 완료)를 Android 에서 검증할 수 있다.
>    영구 차단 상태 재현: 위 리셋 후 OS 시트에서 거부 2회, 또는
>    ```
>    adb shell pm set-permission-flags com.example.qradar android.permission.POST_NOTIFICATIONS user-set user-fixed
>    ```

### 릴리스 차단 (4건)

**T-A1. `나중에` 선택 시 재노출 — 핵심 수정 (F-2) [차단]**
- 환경: Android 에뮬레이터 / 고객 / FCM 수신 불필요
- 준비: 콘솔에서 `notificationPermissionPrompted` 와 `notificationPermissionLaterCount` **두 필드 모두 삭제**. 권한 리셋(규칙 5).
- 절차: ① 앱 콜드 시작 → 다이얼로그 노출 → `나중에` ② 콘솔 확인 ③ 앱 강제 종료 후 콜드 재시작
- 기대: ② `notificationPermissionLaterCount == 1`, **`notificationPermissionPrompted` 는 생성되지 않음(또는 false 유지)** ③ 다이얼로그가 **다시 노출**됨

**T-A2. `허용` 선택 시 재노출 없음 [차단]**
- 환경: Android 에뮬레이터 / 고객 / FCM 수신 필요(토큰 등록 확인)
- 준비: 두 필드 삭제 + `fcmToken` 삭제 + 권한 리셋
- 절차: ① 콜드 시작 → 다이얼로그 → `허용` → OS 시트 → **허용** ② 콘솔 확인 ③ 콜드 재시작
- 기대: ② `notificationPermissionPrompted == true`, `laterCount` **부재 유지**, `fcmToken` 등록됨 ③ 다이얼로그 **미노출**
- 변형 ②': `허용` → OS 시트에서 **거부** → `prompted == true`, `laterCount` 부재, 콜드 재시작 시 다이얼로그 **미노출** (OS 시트 소진 → 재노출 무의미)

**T-A3. 배너 CTA 2탭 완료 — 핵심 수정 (F-1) [차단]**
- 환경: Android 에뮬레이터 / 고객 / FCM 수신 필요
- 준비: 권한 리셋(규칙 5) + `fcmToken` 삭제. `prompted=true` 세팅(다이얼로그 방해 제거).
- 절차: ① `더보기 > 알림 설정` 진입 → 배너 확인 ② CTA 탭 ③ OS 시트에서 **허용**
- 기대: ① **`denied` 배너**(F-1 — Android 는 `notDetermined` 불가) + CTA 라벨 `알림 켜기` ② **OS 권한 시트가 뜬다. 설정 앱으로 전환되지 않는다** ③ 배너 소멸 + 하단 안내 노출 + 콘솔에서 `fcmToken` 등록 확인
- **이 시나리오가 F-1 수정의 전부다.** sub-phase 3 에서는 ①이 `설정 열기` 였고 ②에서 설정 앱이 열려 5탭이 필요했다.

**T-A4. 재노출 한도 소진 [차단]**
- 환경: Android 에뮬레이터 / 고객 / FCM 수신 불필요
- 절차: `notificationPermissionPrompted` 삭제 + `notificationPermissionLaterCount` 를 각각 세팅하고 매번 콜드 재시작
- 기대:

| `laterCount` | 다이얼로그 |
|---|---|
| 필드 부재 | **노출** |
| `0` | **노출** |
| `1` | **노출** |
| `2` | **노출** |
| `3` | **미노출** |
| `4` | **미노출** |
| `-1` (비정상) | **노출** (clamp → 0) |
| `"abc"` (비정상) | **노출** (파싱 실패 → 0) |

### 그 외 시나리오

| T | 시나리오 | 환경 | FCM | 확인 포인트 |
|---|---|---|---|---|
| T-B1 | 기존 사용자 취급 (결정 C) | Android / 고객 | 불필요 | `prompted=true` + `laterCount` 필드 **부재** → 콜드 재시작 시 다이얼로그 **미노출**. 재노출 대상 아님을 실증 |
| T-B2 | OS 허용 상태 가드 (결정 D-4) | Android / 고객 | 불필요 | 권한 **허용** 상태 + `prompted` 삭제 + `laterCount=0` → 콜드 재시작 시 다이얼로그 **미노출**. (sub-phase 3 에서는 노출됐을 상태) |
| T-B3 | 다이얼로그 `null` 처리 | Android / 고객 | 불필요 | 다이얼로그 노출 상태에서 **뒤로 가기 / 앱 강제 종료** → 두 필드 모두 **변화 없음**. 재시작 시 같은 차수로 재노출 |
| T-B4 | 점주 다이얼로그 노출 · 기록 | **Android** / 점주 | 불필요 | 점주 계정으로 Android 에뮬레이터 로그인. T-A1 / T-A2 를 점주 audience 카피로 반복 → `나중에` 에 `laterCount=1`, `허용` 에 `prompted=true`. **두 scaffold 가 같은 flow 헬퍼를 쓰는지의 실증** |
| T-B5 | 설정 앱 폴백 (영구 차단) | Android / 고객 | 불필요 | 영구 차단 상태 재현(규칙 5) → 설정 화면 CTA 탭 → **OS 시트 뜨지 않고** 안내 SnackBar + **설정 앱 전환** (`com.android.settings` 포그라운드 확인) |
| T-B6 | 화면 세션 가드 (결정 F) | Android / 고객 | 불필요 | 권한 리셋 → 설정 화면 CTA 탭 → OS 시트에서 **거부** → 배너 유지 → **같은 화면에서 CTA 재탭** → OS 시트가 **뜨지 않고** 설정 앱 전환. 화면을 벗어나 재진입 후 CTA 탭 → OS 시트 **다시 뜸**(OS 카운터 잔여 1회) |
| T-B7 | CTA 로딩 상태 | Android / 고객 | 불필요 | CTA 탭 중 버튼 비활성 + 16x16 스피너. **설정 앱으로 전환되는 순간까지 비활성 유지**. 복귀 후 정상 상태 |
| T-B8 | `OwnerOrdersPage` 배너 회귀 (F22) | **Android** / 점주 | 불필요 | ① `prompted=false` + `laterCount=1` + 권한 거부 → 주문 접수 화면에 `NotificationDeniedBanner` **노출** (← 수정 없으면 안 뜸) ② `prompted=false` + `laterCount` 부재 → **미노출** ③ `prompted=true` → **노출** |
| T-B9 | `denied` 배너 카피 (U1) | Android / 고객·점주 | 불필요 | design.md 확정 카피와 일치. **owner / customer 본문 분기** 확인. 톤 `warning`, 아이콘 유지 |
| T-B10 | `notDetermined` 배너 무변경 (F32) | **iOS Simulator** / 고객 | 불필요 | 앱 삭제·재설치 후 로그인 → 설정 화면 진입 → `알림을 켜 보세요` / `알림 켜기` / info 톤 **그대로**. **iOS 전용** — Android 에서 시도하지 말 것 |
| T-B11 | iOS 방금 거부 → 설정 앱 미오픈 (E-2) | **iOS Simulator** / 고객 | 불필요 | T-B10 상태에서 CTA 탭 → OS 시트 → **거부** → 배너가 `denied` 로 전환되고 **설정 앱이 열리지 않음**. 이후 CTA 재탭 → 설정 앱 전환 (`statusBefore == denied`). **FCM 불필요하여 APNs 키 미등록이 걸림돌 아님** |
| T-B12 | iOS 권한 허용 경로 | **iOS Simulator** / 고객 | 불필요 | T-B10 상태에서 CTA 탭 → OS 시트 → **허용** → 배너 소멸 + 하단 안내. (토큰 등록은 APNs 미등록으로 검증 불가 → **T-A3 에서 Android 로 커버**. 이 사실을 test_report 에 명시하고 보류로 기록하지 말 것) |
| T-B13 | sub-phase 3 전체 회귀 | Android / 고객·점주 | 필요 | 토글 저장·재진입 유지 / dot-path 보존(4키 공존) / CF `disabled_by_user` 게이트 / `resumed` 토큰 reconcile / `pickupComplete` 옵트인 발화 |
| T-B14 | sub-phase 1·2 회귀 | Android / 고객·점주 | 필요 | 조리 단계 전이, 진행 인디케이터, deep link 3종(foreground/background/terminated), `DialogQueueService` 중복 stacking 없음 |
| T-B15 | 다이얼로그 큐 공존 | Android / 고객 | 불필요 | 다이얼로그 노출 조건 + 다른 글로벌 다이얼로그가 동시 발생 → stacking 없이 순차 노출. `null` 반환 시 카운터 미증가 (T-B3 과 결합) |
| T-B16 | 다중 기기 동시 `나중에` | Android 에뮬레이터 2대 또는 에뮬레이터+iOS / 동일 고객 | 불필요 | 양쪽에서 거의 동시에 `나중에` → `laterCount == 2` (`increment` 원자성). read-then-write 라면 `1` 이 되어 FAIL |

### Rules 검증 (에뮬레이터)

sub-phase 3 에서 확립된 방법을 재사용한다 — Firebase Console 의 Rules Playground 는 제거되었으므로 **로컬 Firestore 에뮬레이터 + `@firebase/rules-unit-testing@4`** 로 수행한다.

| # | 시나리오 | 기대 |
|---|---|---|
| R1 | 본인 doc 의 `notificationPermissionLaterCount` increment | allow |
| R2 | **타인** doc 의 `notificationPermissionLaterCount` increment | deny |
| R3 | 본인 doc 의 `notificationPermissionLaterCount` 를 임의 정수로 set | allow (F36 — 값 검증 없음이 의도대로인지 확인) |
| R4 | 본인 doc 의 `notificationPermissionLaterCount` + 화이트리스트 밖 필드(`isAdmin`) 동반 update | deny |
| R5 | 본인 doc 의 `notificationPermissionPrompted` update (기존 경로 회귀) | allow |
| R6 | 본인 doc 의 `notificationSettings` dot-path update (sub-phase 3 회귀) | allow |
| R7 | 본인 doc 의 `uid` 변경 (immutable 회귀) | deny |
| R8 | 본인 doc 의 `fcmToken` update (T11 경로 회귀) | allow |

### 빌드 검증

`flutter analyze` 무경고 / `flutter test` 전체 통과 (developer 신규 단위 테스트 포함) / `dart run build_runner build --delete-conflicting-outputs` 재생성 산출물이 커밋에 포함됨. tester 는 **직접 재실행**한다. CF 변경이 없으므로 `functions` 빌드는 선택.

---

## 완료 기준

- [ ] F1 ~ F40 이 모두 구현되었거나 보류 사유가 명시됨
- [ ] `design.md` 작성 완료 (U1 ~ U6 확정)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료
- [ ] **릴리스 차단 4건(T-A1 ~ T-A4) 전부 PASS**
- [ ] **환경 사유 보류가 0건** — 보류가 발생하면 해당 시나리오가 §테스트 시나리오 전제 규칙 1~5 중 어느 것을 위반했는지 test_report 에 기록하고, 대체 검증 경로를 제시한다
- [ ] Rules R1 ~ R8 전부 PASS
- [ ] sub-phase 1 / 2 / 3 회귀 없음 (T-B13 / T-B14)
- [ ] `flutter analyze` 무경고 / `flutter test` 통과
- [ ] `docs/processes/data_ownership.md` · `role_flows.md` 갱신 (F38 / F39), sub-phase 3 spec 에 변경 주석 (F40)
- [ ] 절대 규칙 준수 — Clean Architecture 의존 방향, Firebase SDK 는 data 레이어만, `AppColors` 만, 하드코딩된 secret 없음
- [ ] FAIL 항목이 없거나 후속 작업으로 분리됨

---

## 사용자 확인 필요 항목 — **전건 확정 완료 (2026-10-21)**

Q1~Q7 **모두 architect 결정안 그대로 확정**됐다. Q2 · Q3 · Q4 는 사용자에게 직접 확인했고, Q1 · Q5 · Q6 · Q7 은 근거가 타당하고 되돌리기 쉬워 결정안을 수용했다. 아래 `확정` 열 참조.

| # | 항목 | architect 결정 | 확정 | 확인 필요 사유 |
|---|---|---|---|---|
| **Q1** | `notificationPermissionPrompted` **의미 변경** (필드 유지, 리네임 없음) vs 신규 필드 추가 | **의미 변경** (결정 B) | 수용 (미질의) | 같은 이름이 다른 뜻을 갖게 된다. doc comment 와 문서로만 구분되므로, 나중에 코드를 읽는 사람이 오해할 위험을 수용하는지 확인 |
| **Q2** | 기존 `prompted=true` 사용자를 **재노출 대상에서 제외** | **제외** (결정 C) | **확정 — 사용자 직접 확인** | 비가역 결정. `나중에` 를 눌렀던 기존 사용자는 자동 재권유를 영구히 받지 못한다 (명시 경로는 유지). 포함을 택하면 OS 시트를 이미 거부한 사용자에게도 다이얼로그가 뜬다 |
| **Q3** | 최대 노출 횟수 = **3회** (`laterCount` 0·1·2 에서 노출, 3 에서 중단) | **3** (결정 A) | **확정 — 사용자 직접 확인 (총 노출 3회)** | 사용자가 "3회까지" 로 확정했으나, 그것이 **총 노출 3회**(architect 해석)인지 **최초 1회 + 재노출 3회 = 총 4회**인지 경계 확인 |
| **Q4** | `denied` 배너 카피 변경 — 제목 `기기 설정에서 알림이 꺼져 있어요` → `알림이 꺼져 있어요`, CTA `설정 열기` → `알림 켜기` | **변경** (결정 E-3) | **확정 — 사용자 직접 확인** | sub-phase 3 에서 확정·검증된 카피를 되돌린다. 변경하지 않으면 Android 미요청 집단에게 사실과 다른 문장이 남고 F-1 의 체감 영향이 유지된다 |
| **Q5** | 다이얼로그 노출 가드에 **`osStatus ∈ {authorized, provisional}` → 중단** 추가 | **추가** (결정 D) | 수용 (미질의) | 신규 동작. 이것 없이는 "알림을 이미 받고 있는데 알림을 켜라는 다이얼로그가 뜨는" 결함이 `laterCount` 도입과 함께 신설된다 |
| **Q6** | Android 에서 "방금 거부" 와 "이미 차단" 구분 불가 → `denied` 결과에 항상 설정 앱 폴백 | ~~수용~~ → **E-2 개정으로 폐기** (1회차 전환 없음) | **사용자 직접 확인 — 거슬림 판정, 개정** | Android 사용자가 OS 시트에서 거부한 직후 설정 앱으로 전환될 수 있다. 기존 동작(무조건 설정 앱)의 보존이므로 회귀는 아니나, 체감상 거친 동작임 |
| **Q7** | 다이얼로그 결과가 `null`(dedup / context 만료) 일 때 **두 필드 모두 미기록** | **미기록** (결정 B) | 수용 (미질의) | 기존 동작은 `prompted=true` 였다. 변경 후에는 같은 차수로 재노출되므로, 비정상 경로가 반복되면 다이얼로그가 반복 노출될 수 있다 (카운터 소모 없음) |

---

## 다른 task / 코드 영향 추적

| 대상 | 영향 |
|---|---|
| sub-phase 2 spec (sticky 정책) | 정책이 "1회 노출 후 영구 차단" → "`나중에` 3회까지 재노출 + `허용` 후 차단" 으로 **변경**됨. 해당 spec 은 이력으로 보존하고 본 spec 이 새 단일 진실원 |
| sub-phase 3 spec 결정 D-3 표 | `notificationPermissionPrompted` **의미 변경 없음** / `scaffold` **변경 없음** / **자동 재노출 없음** 세 항목이 모두 뒤집힌다 → F40 으로 주석 추가 |
| sub-phase 3 design.md 배너 3-state | `denied` state 카피·CTA 가 변경된다. 새 design.md 가 그 부분의 단일 진실원이 됨 |
| `OwnerOrdersPage` 배너 (sub-phase 3b) | F22 로 게이트 교체. 배너 자체는 무변경 |
| `NotificationDeniedBanner` (3b) | **변경 없음** (F23) |
| Cloud Functions | **변경 없음** |
| `docs/processes/entity_lifecycle.md` | **변경 없음** — `users` 는 status 전이 엔티티가 아니며, order/store/brand/menuItem/refund 의 전이에 영향 없음 |
| `docs/product_scope.md` | **변경 없음** — 기능 범위가 아니라 권한 요청 UX 정책 변경 |

### 후속 과제 (본 sub-phase 범위 밖)

1. `prompted` / `laterCount` 를 하나의 `notificationPermissionPrompt` map 으로 묶는 스키마 정리 (필드 군집이 더 늘어날 때)
2. Android `notDetermined` 복원 — 플러그인 upstream 이슈 제기 또는 네이티브 채널 추가
3. `firebase_messaging` 플러그인 버전 업 시 F-1 재확인 (고쳐졌다면 배너 3-state 의 원래 설계가 살아난다)
4. 설정 화면 최초 진입 시 토큰 reconcile 여부 재검토 (sub-phase 3 관찰사항 ③)
5. Rules 유닛 테스트를 영구 테스트로 리포지토리에 편입 (sub-phase 3 후속 과제 ①)
6. `refundResult` 알림 카테고리 추가 (`order_refund_result_notification`)

---

## 참고 자료

- `docs/tasks/order_flow_phase3c/3_notification_settings/test_report.md` §F (F-1 / F-2 발견 근거 · 증거)
- `docs/tasks/order_flow_phase3c/3_notification_settings/spec.md` 결정 D (D-1 ~ D-5)
- `docs/tasks/order_flow_phase3c/2_customer_notification_and_ui/spec.md` (sticky 정책 도입 배경)
- `firebase_messaging-16.1.3` `FlutterFirebaseMessagingPlugin.java:409` / `firebase_messaging_platform_interface-4.7.8` `utils.dart:84` (F-1 원인)
- Android `POST_NOTIFICATIONS` 런타임 권한 — 2회 거부 후 영구 차단
