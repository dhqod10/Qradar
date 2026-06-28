# order_flow_phase3b 디자인 명세 (FCM 푸시 알림 UI)

## 참조한 디자인

- Figma: 없음 (신규 컴포넌트)
- 기존 화면 패턴:
  - `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart` — 아이콘 컨테이너 + 제목 + 본문 + 버튼 2개 배치 패턴 그대로 따름
- 참고 컴포넌트: `Dialog` (Flutter Material) / `FilledButton` / `TextButton`

---

## 1. NotificationPermissionDialog

### 1-1. 진입 경로 (spec.md 결정 A + role_flows.md 점주 흐름)

- 진입점: `OwnerScaffold` (점주 전용 Scaffold) 첫 진입 시
- 조건: `users/{uid}.notificationPermissionPrompted == false` (또는 필드 미존재)
- 타이밍: `initState` 의 `WidgetsBinding.instance.addPostFrameCallback` — 빌드 사이클 방해 방지
- 파일 위치: `lib/presentation/common/notification/notification_permission_dialog.dart`

### 1-2. 레이아웃 / 컨테이너

| 항목 | 값 |
|---|---|
| 위젯 | `Dialog` |
| background | `AppColors.surfaceElevated` |
| borderRadius | 20 |
| insetPadding | `horizontal: 32` |
| 내부 padding | `fromLTRB(24, 28, 24, 20)` |
| 내부 Column | `mainAxisSize: MainAxisSize.min` |

### 1-3. 아이콘 컨테이너

| 항목 | 값 |
|---|---|
| Container 크기 | width: 56, height: 56 |
| 형태 | `BoxShape.circle` |
| 배경 | `LinearGradient(AppColors.primary → AppColors.primaryLight)`, direction: topLeft → bottomRight |
| 아이콘 | `Icons.notifications_active_rounded` |
| 아이콘 크기 | 28 |
| 아이콘 색상 | `AppColors.onPrimary` |

> 아이콘은 `Icons.notifications_active_rounded` 사용. 기존 `upgrade_to_brand_dialog` 의 circle gradient 컨테이너 패턴과 동일하게 구성해 앱 전반의 다이얼로그 일관성 유지.

### 1-4. 제목

| 항목 | 값 |
|---|---|
| 텍스트 | `"알림을 받으시겠어요?"` |
| margin-top (from 아이콘) | SizedBox height: 20 |
| fontSize | 18 |
| fontWeight | w700 |
| color | `AppColors.textHeading` |
| textAlign | center |

> spec.md 원안("주문 알림을 받으시겠어요?")에서 "주문 " 제거. Qradar 톤 기준 — 제목은 짧고 직관적, 부연은 본문에서. 아이콘과 버튼이 이미 문맥을 제공하므로 제목에서 "주문" 반복은 불필요.

### 1-5. 본문 (1차)

| 항목 | 값 |
|---|---|
| 텍스트 | `"새 주문과 환불 요청을 바로 알려드릴게요."` |
| margin-top (from 제목) | SizedBox height: 12 |
| fontSize | 14 |
| fontWeight | w400 |
| height (line-height) | 1.5 |
| color | `AppColors.textBody` |
| textAlign | center |

### 1-6. 본문 (2차 — 보조 설명)

| 항목 | 값 |
|---|---|
| 텍스트 | `"매장을 떠나 있어도 놓치지 않아요."` |
| margin-top (from 본문 1차) | SizedBox height: 6 |
| fontSize | 12 |
| fontWeight | w400 |
| height (line-height) | 1.5 |
| color | `AppColors.textMuted` |
| textAlign | center |

### 1-7. 버튼 영역

| 항목 | 값 |
|---|---|
| margin-top (from 보조 설명) | SizedBox height: 24 |
| 배치 | `Row` — "나중에" (secondary) 왼쪽 / "허용" (primary) 오른쪽 |
| 두 버튼 사이 gap | SizedBox width: 8 |
| 각 버튼 flex | `Expanded` (1:1) |

**"나중에" 버튼 (secondary)**

| 항목 | 값 |
|---|---|
| 위젯 | `TextButton` |
| vertical padding | 14 |
| borderRadius | 12 |
| 텍스트 | `"나중에"` |
| fontSize | 15 |
| fontWeight | w600 |
| color | `AppColors.textMuted` |

**"허용" 버튼 (primary)**

| 항목 | 값 |
|---|---|
| 위젯 | `FilledButton` |
| backgroundColor | `AppColors.primary` |
| foregroundColor | `AppColors.onPrimary` |
| vertical padding | 14 |
| borderRadius | 12 |
| 텍스트 | `"허용"` |
| fontSize | 15 |
| fontWeight | w700 |

### 1-8. 인터랙션 / 상태 전이

| 사용자 동작 | 처리 |
|---|---|
| "허용" 탭 | `Navigator.of(context).pop('allow')` → 호출부에서 OS 권한 다이얼로그 호출 → 결과 무관하게 `notificationPermissionPrompted = true` 영속화 |
| "나중에" 탭 | `Navigator.of(context).pop('later')` → `notificationPermissionPrompted = true` 영속화, 토큰 등록 skip |
| barrier 탭 (다이얼로그 외부) | `barrierDismissible: false` 로 설정 — 명시적 선택 강제. `notificationPermissionPrompted` 미박힘 → 다음 OwnerScaffold 진입 시 재노출 |

> `barrierDismissible: false` 결정 이유: spec.md 에서 "barrier dismiss 시 권한 요청 보류 → 다음 진입 시 재노출"을 요구하므로, 우발적 barrier 탭으로 다이얼로그를 닫는 경우와 명시적 "나중에" 탭을 구분해야 한다. `barrierDismissible: false` 로 barrier 탭 자체를 막아 사용자가 반드시 버튼 중 하나를 선택하게 한다. 단, 이 경우 뒤로가기(Android) / 스와이프 다운(iOS 풀스크린 모달 아님)으로도 닫히지 않으므로 반드시 버튼 2개 중 하나를 노출해야 한다.

### 1-9. 상태 정의

| 상태 | UI |
|---|---|
| 기본 (default) | 위 명세 그대로 |
| loading | 다이얼로그 자체는 loading 상태 없음. "허용" 탭 후 OS 권한 다이얼로그가 시스템에 의해 노출되므로 별도 loading 처리 불필요 |
| error | 토큰 발급 실패 시 silent — 다이얼로그 UI 변화 없음. 에러는 호출부에서 로그만 기록 |
| empty | 해당 없음 |

---

## 2. 알림 본문 마이크로카피

### 2-1. 신규 주문 알림

**Case A (원안)**
- title: `"신규 주문이 들어왔어요"`
- body: `"{storeName} · {firstItemName}{n>1 ? ' 외 N건' : ''} · {totalPrice.toComma()}원"`

**Case B (추천안)**
- title: `"주문이 들어왔어요 · {storeName}"`
- body: `"{firstItemName}{n>1 ? ' 외 N건' : ''} · {totalPrice.toComma()}원"`

**Case C**
- title: `"새 주문 · {storeName}"`
- body: `"{firstItemName}{n>1 ? ' 외 N건' : ''} · {totalPrice.toComma()}원"`

**추천안: Case B**

추천 이유:
- "주문이 들어왔어요"는 자연스러운 구어체 — 알림 특성상 짧고 감각적인 톤이 어울림
- title 에 `storeName` 을 포함해, 다중 매장 점주가 어느 매장 주문인지 title 만으로 즉시 식별
- body 는 아이템 + 금액만 — 최소 정보, 최고 가독성
- "신규" (Case A, C) 보다 "들어왔어요" (Case B) 가 Qradar 의 구어체 톤과 더 잘 맞음

길이 검증 (iOS 알림 1-2줄 기준, 60~80자 내외):
- title: "주문이 들어왔어요 · 카페 알파" → 약 18자 (양호)
- body: "아메리카노 외 2건 · 15,000원" → 약 18자 (양호)

---

### 2-2. 환불 요청 알림

**Case A (원안)**
- title: `"환불 요청이 도착했어요"`
- body: `"{storeName} · {firstItemName}{n>1 ? ' 외 N건' : ''} · 사유: {reason.substring(0, 30)}..."`

**Case B (추천안)**
- title: `"환불 요청 · {storeName}"`
- body: `"{firstItemName}{n>1 ? ' 외 N건' : ''} · {reason.substring(0, 25)}"`

**Case C**
- title: `"환불 요청이 들어왔어요 · {storeName}"`
- body: `"{firstItemName}{n>1 ? ' 외 N건' : ''} · 사유: {reason.substring(0, 20)}..."`

**추천안: Case B**

추천 이유:
- "환불 요청이 도착했어요" (원안) 는 부드럽지만 "도착" 이라는 표현이 주문 알림과 혼동될 여지가 있음
- "환불 요청 · {storeName}" — 명사형으로 짧게, 전문적이고 차분한 톤. 점주 입장에서 감정 부담이 적음
- body 에서 "사유:" 접두어를 제거 — 이미 title 에서 환불임을 알고 있으므로 반복 불필요. 공간 효율 ↑
- `reason.substring(0, 25)` — 원안 30자보다 짧게. iOS body 2줄 제한 내에서 아이템명 + 사유가 함께 들어가려면 각각을 짧게 제한해야 함

길이 검증:
- title: "환불 요청 · 카페 알파" → 약 13자 (양호)
- body: "아메리카노 외 1건 · 음료가 너무 달았어요" → 약 22자 (양호)

> 환불 요청은 점주에게 부담스러운 알림이므로 감탄형/느낌표 사용 금지. 명사형 + 차분한 기술 방식 유지.

---

### 2-3. Cloud Function 구현 시 포맷 공식

```
[신규 주문]
title: "주문이 들어왔어요 · {storeName}"
body:  items.length === 1
         ? `${firstItemName} · ${totalPrice.toLocaleString()}원`
         : `${firstItemName} 외 ${items.length - 1}건 · ${totalPrice.toLocaleString()}원`

[환불 요청]
title: "환불 요청 · {storeName}"
body:  items.length === 1
         ? `${firstItemName} · ${reason.substring(0, 25)}`
         : `${firstItemName} 외 ${items.length - 1}건 · ${reason.substring(0, 20)}`
```

> Cloud Function (TypeScript) 에서 `toLocaleString('ko-KR')` 또는 `Number.toLocaleString()` 으로 천 단위 콤마 처리. `reason` 이 25자(신규 주문 케이스) / 20자(다건 케이스) 초과 시 substring 후 `"..."` 미추가 — 알림에서 말줄임표는 OS 가 자동 처리.

---

## 3. 알림 권한 거부 후 재유도 배너

### 3-1. 포함 여부 결정

**본 phase 에 포함 (소규모, 구현 공수 낮음).**

판단 근거:
- `notificationPermissionPrompted = true` 이지만 OS 권한이 `denied` 인 상태는 점주가 "나중에" 탭 후 재방문 시점에 발생 가능
- 이 상태에서 점주는 주문 알림을 받지 못하는데 아무런 안내가 없으면 운영 불편 발생
- 배너 1개 추가이므로 공수가 낮음 — 포함 권장

### 3-2. 노출 조건

```
notificationPermissionPrompted == true
AND OS 알림 권한 status == denied (또는 notDetermined 이 아닌 거부)
```

노출 위치: `OwnerOrdersPage` (점주 첫 탭, 주문 목록) 상단 — `SliverList` 또는 `ListView` 최상단에 `_NotificationDeniedBanner` 위젯 삽입.

> `OwnerScaffold` Scaffold body 가장 위에 삽입하는 것도 가능하나, OwnerOrdersPage 상단이 더 맥락적 — 주문 목록을 보다가 "알림이 꺼져있다" 는 안내가 자연스럽게 연결됨.

파일 위치: `lib/presentation/owner/orders/widgets/notification_denied_banner.dart`

### 3-3. 배너 레이아웃

| 항목 | 값 |
|---|---|
| 위젯 | `Container` (full width) |
| margin | `EdgeInsets.fromLTRB(16, 12, 16, 4)` |
| padding | `EdgeInsets.symmetric(horizontal: 16, vertical: 12)` |
| background | `AppColors.warning` with `alpha: 0.10` (경고 연한 배경) |
| border | `AppColors.warning` / 1px / `BorderRadius.circular(12)` |
| 내부 배치 | `Row` — 아이콘 + 텍스트(Expanded) + 화살표 아이콘 |

**아이콘 (좌측)**

| 항목 | 값 |
|---|---|
| 아이콘 | `Icons.notifications_off_outlined` |
| 크기 | 20 |
| 색상 | `AppColors.warning` |
| margin-right | SizedBox width: 10 |

**텍스트 영역 (중앙, Expanded)**

| 항목 | 값 |
|---|---|
| 텍스트 | `"알림이 꺼져 있어요. 설정에서 켜주세요."` |
| fontSize | 13 |
| fontWeight | w500 |
| color | `AppColors.textBody` |

**화살표 아이콘 (우측)**

| 항목 | 값 |
|---|---|
| 아이콘 | `Icons.arrow_forward_ios_rounded` |
| 크기 | 14 |
| 색상 | `AppColors.textMuted` |

### 3-4. 인터랙션

| 동작 | 처리 |
|---|---|
| 배너 탭 | `openAppSettings()` — `app_settings` 패키지 또는 `url_launcher` 로 OS 앱 설정 화면 오픈 |
| 배너 닫기 | 닫기 버튼 제공하지 않음 — OS 권한 허용 또는 앱 재시작 후 권한 status 재확인으로 자동 숨김 |

> 설정 화면 복귀 후 배너 자동 숨김: `OwnerOrdersPage` 가 `WidgetsBindingObserver` 로 `AppLifecycleState.resumed` 이벤트 감지 → 권한 status 재확인 → `notified` 상태면 배너 제거. 구현 결정은 developer 에게 위임 (observer 추가 공수 고려).

### 3-5. 상태

| 상태 | UI |
|---|---|
| 권한 granted | 배너 미노출 |
| 권한 denied + prompted = true | 배너 노출 |
| 권한 확인 loading | 배너 미노출 (권한 비동기 확인 중에는 배너 깜빡임 방지를 위해 숨김 유지) |

---

## 4. 인터랙션 요약

| 동작 | 반응 |
|---|---|
| "허용" 탭 | 다이얼로그 닫힘 → OS 권한 다이얼로그 → `notificationPermissionPrompted=true` 영속화 |
| "나중에" 탭 | 다이얼로그 닫힘 → `notificationPermissionPrompted=true` 영속화, 토큰 미등록 |
| barrier 탭 | 막힘 (`barrierDismissible: false`) — 재노출 위해 `notificationPermissionPrompted` 미박힘 |
| 배너 탭 | OS 앱 설정 화면 이동 |

---

## 5. 상태별 UI

### Loading

`NotificationPermissionDialog` 자체에는 loading 상태 없음. 다이얼로그 표시 이전 Firestore 플래그 확인 중에는 다이얼로그 미노출 (사용자가 인지 못하는 수준의 짧은 비동기). `showDialog` 호출 전 await 로 처리.

### Error

- 토큰 발급 실패 / Firestore update 실패: silent. 다이얼로그/배너 UI 변화 없음. 호출부에서 `debugPrint` 로그만.
- 권한 상태 확인 실패: 배너 미노출 (기본 숨김) — 오판으로 인한 배너 오노출보다 미노출이 덜 해롭다.

### Empty

해당 없음.

---

## 6. Figma 대비 변경사항

| 항목 | Figma / 기존안 | Qradar 적용 |
|---|---|---|
| 다이얼로그 패턴 | 없음 (신규) | `upgrade_to_brand_dialog` 와 동일 구조 (radius: 20, padding: 24/28/20, circle gradient 아이콘) |
| 제목 원안 | "주문 알림을 받으시겠어요?" | "알림을 받으시겠어요?" — 짧게 |
| 알림 본문 title 원안 | "신규 주문이 들어왔어요" | "주문이 들어왔어요 · {storeName}" — storeName 을 title 로 이동, body 단순화 |
| 환불 title 원안 | "환불 요청이 도착했어요" | "환불 요청 · {storeName}" — 명사형, 차분한 톤 |
| barrierDismissible | spec 에서 "barrier dismiss = 재노출" 요구 | `barrierDismissible: false` — 사용자가 반드시 버튼 선택. 명시적 선택 후 dismiss 로 재노출 필요 없음 |

---

## 7. 개발자 전달 특이사항

1. **기존 다이얼로그 패턴 재사용**: `upgrade_to_brand_dialog.dart` 의 `Dialog` + circle gradient 아이콘 + `FilledButton`/`TextButton` Row 구조를 그대로 따른다. 별도 신규 컴포넌트 패턴 불필요.

2. **barrierDismissible: false**: `showDialog` 호출 시 `barrierDismissible: false` 필수. 사용자가 버튼을 반드시 선택해야 닫힘.

3. **반환값 처리**: `showDialog<String?>` 반환. 호출부에서 `'allow'` / `'later'` / `null` 분기.
   - `'allow'`: OS 권한 요청 → 성공 시 FCM 토큰 등록 → `notificationPermissionPrompted=true`
   - `'later'`: 토큰 등록 skip → `notificationPermissionPrompted=true`
   - `null`: 도달 불가 (`barrierDismissible: false` 이므로) — 방어 처리는 `'later'` 와 동일하게.

4. **알림 배너 (`notification_denied_banner.dart`)**: `app_settings` 패키지 (`open_settings` 류) 사용 또는 `url_launcher` + 플랫폼별 설정 URL 분기. 개발자가 패키지 선택 결정 (spec.md 비범위).

5. **색상 토큰**:
   - 다이얼로그 배경: `AppColors.surfaceElevated`
   - 아이콘 컨테이너: `AppColors.primary → AppColors.primaryLight` LinearGradient
   - 아이콘 색상: `AppColors.onPrimary`
   - 제목: `AppColors.textHeading`
   - 본문: `AppColors.textBody`
   - 보조 설명: `AppColors.textMuted`
   - primary 버튼: `AppColors.primary` / `AppColors.onPrimary`
   - secondary 버튼 텍스트: `AppColors.textMuted`
   - 배너 배경: `AppColors.warning` alpha 0.10
   - 배너 border: `AppColors.warning`
   - 배너 아이콘: `AppColors.warning`

6. **알림 본문 포맷 (Cloud Function 구현용)**: 2-3 섹션의 TypeScript 포맷 공식 참조. `reason.substring` 길이는 단건 25자 / 다건 20자.

7. **배너 자동 숨김**: `AppLifecycleState.resumed` 감지 후 권한 재확인 로직 구현 여부는 developer 판단에 위임. 구현하지 않으면 앱 재시작 시에만 배너 숨김 (단순 구현).

---

## 8. 사용자 확인이 필요한 디자인 결정사항

| # | 항목 | 현재 결정 | 확인 요청 |
|---|---|---|---|
| D-1 | 다이얼로그 제목 문구 | `"알림을 받으시겠어요?"` | 원안 `"주문 알림을 받으시겠어요?"` 와 중 선택 |
| D-2 | 신규 주문 알림 title | `"주문이 들어왔어요 · {storeName}"` (Case B) | 또는 원안 `"신규 주문이 들어왔어요"` (Case A) |
| D-3 | 환불 요청 알림 title | `"환불 요청 · {storeName}"` (Case B) | 또는 원안 `"환불 요청이 도착했어요"` (Case A) |
| D-4 | 권한 거부 재유도 배너 포함 | 본 phase 포함 | 제외하고 Phase 4로 미룰지 확인 |
| D-5 | barrierDismissible | `false` — 버튼 강제 선택 | 또는 `true` 로 barrier 탭 = "나중에" 처리 (spec 요구사항 재검토 필요) |
