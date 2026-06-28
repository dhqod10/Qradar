# Phase 3c-2 고객 알림 + 고객 UI 강화 — Test Report

## 변경 이력

| 일자 | 검증자 | 내용 |
|---|---|---|
| 2026-06-21 | tester | 최초 작성. 정적 검증 완료. 라이브 검증 시나리오 매뉴얼 포함 |
| 2026-06-21 | developer | FAIL-1 fix — `notification_permission_dialog.dart:14` `Colors.black` → `AppColors.textHeading` 교체. `flutter analyze` No issues found 재확인 |

---

## 전체 결과 요약

| 구분 | 건수 |
|---|---|
| PASS | 29 |
| FAIL | 0 |
| 보류 (라이브 검증 의존) | 13 |

> FAIL-1 은 fix 완료 — PASS 로 전환됨 (변경 이력 2026-06-21 참조).

---

## FAIL 항목

> 전부 해소됨. 아래는 이력 보존.

### FAIL-1 (해소됨). `notification_permission_dialog.dart` 에서 `Colors.black` 직접 사용 — AppColors 규칙 위반

- **위치**: `lib/presentation/common/notification/notification_permission_dialog.dart:14`
- **위반 코드 (수정 전)**: `barrierColor: Colors.black.withValues(alpha: 0.6)`
- **규칙**: CLAUDE.md 절대 규칙 §3 — "색상은 `AppColors` 만 사용. `Color(0x...)` 직접 하드코딩 금지"
- **fix (2026-06-21)**: `barrierColor: AppColors.textHeading.withValues(alpha: 0.6)` 로 교체. `flutter analyze` No issues found 재확인.
- **비고**: 이 파일은 Phase 3b 에서 생성됐으나, 본 sub-phase 의 `ScaffoldWithNav` 가 이 위젯을 신규 호출 경로로 추가했으므로 본 검증 대상에 포함되었음. Phase 3b 회귀 이슈 동시 해소.

---

## PASS 항목

### A. Cloud Function `onOrderStatusChanged`

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| A-1 | F1: `onDocumentUpdated('orders/{orderId}', region: 'asia-northeast3')` trigger | PASS | `functions/src/onOrderStatusChanged.ts:42-46` — document / region 정확 명시 |
| A-2 | F2: `before.status != after.status` diff 검사 + early return | PASS | `onOrderStatusChanged.ts:61` — `beforeStatus === afterStatus` 시 return |
| A-3 | F3: `paid→accepted` / `accepted→making` / `making→ready` 3건 발화 | PASS | `NOTIFICATION_MATRIX` 에 3개 키 정의 확인 (line 23-40) |
| A-4 | F3: `ready→completed` 미발화 (결정 B) | PASS | `NOTIFICATION_MATRIX` 에 해당 키 없음 + 주석으로 명시 (line 39) |
| A-5 | F4: `users/{userId}.fcmToken` 조회 경로 | PASS | `db.collection("users").doc(userId).get()` — Phase 3b 패턴 동일 (line 86-87) |
| A-6 | F5: FCM data-only payload 구조 (Phase 3b 동일) | PASS | `data: { type, orderId, storeId, title, body }` — F10 key 이름 일치 |
| A-7 | F6: invalid token → fcmToken 필드 delete | PASS | `messaging/invalid-registration-token` / `messaging/registration-token-not-registered` 분기 + `fcmToken: FieldValue.delete()` (line 128-137) |
| A-8 | F7: 기타 발송 실패 swallow + error 로그 | PASS | else 분기에서 `console.error` + 예외 삼킴 (line 140-142) |
| A-9 | F8: status 무변경 skip | PASS | `beforeStatus === afterStatus` → early return (line 61) |
| A-10 | F11: 알림 카피 — design.md 확정안 (`{storeName}에서` 붙여쓰기) | PASS | 구현 코드에서 공백 없이 붙여쓰기 확인 (line 27, 31, 36) |
| A-11 | `index.ts` export 추가 | PASS | `export { onOrderStatusChanged } from "./onOrderStatusChanged";` (index.ts:22) |
| A-12 | asia-northeast3 region 명시 | PASS | `region: "asia-northeast3"` (onOrderStatusChanged.ts:45) |

### B. Domain enum 확장

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| B-1 | F12: `NotificationType` enum 에 `orderAccepted` / `orderMaking` / `orderReady` 3개 case 추가 | PASS | `remote_notification_message.dart:6-8` 확인 |
| B-2 | F13: `fromData` switch 에 `'order_accepted'` / `'order_making'` / `'order_ready'` 매핑 추가 | PASS | `remote_notification_message.dart:36-40` 확인 |
| B-3 | CF `data.type` 문자열 ↔ 클라이언트 enum 매핑 drift 없음 | PASS | CF: `"order_accepted"/"order_making"/"order_ready"` → 클라이언트: `'order_accepted'/'order_making'/'order_ready'` 1:1 일치 |
| B-4 | `unknown` fallback 분기 유지 | PASS | `_ => NotificationType.unknown` (line 41) |

### C. NotificationNavigator 분기

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| C-1 | F14: `orderAccepted` / `orderMaking` / `orderReady` → customer `OrderDetailPage` push | PASS | `notification_navigator.dart:35-42` — 3개 case fall-through 후 `OrderDetailPage(orderId: orderId)` push |
| C-2 | 기존 `newOrder` / `refundRequest` → `OwnerOrderDetailPage` 유지 | PASS | `notification_navigator.dart:27-32` 변경 없음 |
| C-3 | "Phase 3c 예정" 주석 해소 | PASS | 주석이 "Phase 3c-2 에서 customer status 전이 알림 추가됨" 으로 갱신됨 (`notification_navigator.dart:12-14`) |
| C-4 | orderId 누락 시 early return | PASS | `if (orderId == null) return;` (line 23) |
| C-5 | `unknown` case 처리 (break) | PASS | `case NotificationType.unknown: break;` (line 43-45) |
| C-6 | presentation/domain 레이어에서 Firebase 직접 import 없음 | PASS | `notification_navigator.dart` — firebase 관련 import 없음. 도메인 entity 만 참조 |

### D. ScaffoldWithNav 알림 권한 hook

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| D-1 | F25: `_checkAndRequestNotificationPermission` 메서드 추가 | PASS | `scaffold_with_nav.dart:52-88` — OwnerScaffold 패턴과 1:1 동일 |
| D-2 | F26: `initState` 에 `addPostFrameCallback` 에서 호출 | PASS | `scaffold_with_nav.dart:46-50` |
| D-3 | F27: 권한 허용 시 `RegisterFcmTokenUseCase` 호출 | PASS | `scaffold_with_nav.dart:80-81` |
| D-4 | F28: 결과 무관하게 `markNotificationPermissionPrompted` 호출 | PASS | `scaffold_with_nav.dart:84-87` |
| D-5 | F29: "나중에" 선택 시 OS 권한 요청 skip | PASS | `if (result == 'allow')` 분기 — allow 일 때만 OS 권한 요청 (line 71) |
| D-6 | F30: 기존 Provider 재사용 (신규 Provider 생성 없음) | PASS | `registerFcmTokenUseCaseProvider` / `requestNotificationPermissionUseCaseProvider` / `userRepositoryProvider` 재사용 확인 |
| D-7 | OwnerScaffold 패턴과 완전 동일 | PASS | `owner_scaffold.dart:45-81` vs `scaffold_with_nav.dart:52-88` 비교 — 구조 동일, 로직 동일 |

### E. `_OrderProgressIndicator` 위젯

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| E-1 | F16: `_OrderProgressIndicator` 신규 추가 (horizontal stepper 4단계) | PASS | `order_detail_page.dart:1007-1184` |
| E-2 | F17: 각 단계 도달 여부 timestamp 존재로 판정 | PASS | `_stepState()` 헬퍼: `timestamps[index] != null → completed` (line 1031) |
| E-3 | F18: 현재 단계 `order.status` 로 결정 (index==0 특수 처리 + 직전 timestamp 기준) | PASS | `_stepState()`: `index==0 → current`, `timestamps[index-1] != null → current` (line 1033-1034) |
| E-4 | F19: 각 단계 아래 타임스탬프 `HH:mm` 표시 + 미도달 시 `-` | PASS | `_buildStepLabel()`: `ts != null ? timeFormat.format(ts) : '-'` (line 1174) |
| E-5 | F20: 노출 조건 `cancelled` / `refunded` 시 미노출 | PASS | `_showProgressIndicator()`: `status != cancelled && status != refunded` (line 152-154) |
| E-6 | F21: `_StatusSection` 직후, `_CancelInfoSection` 앞 위치 | PASS | `_OrderDetailBody.build()` line 188-191: 정확한 위치에 삽입 |
| E-7 | shimmer placeholder 추가 (`_shimmerBox(height: 88, radius: 16)`) | PASS | `_OrderDetailShimmer.build()` line 952-953 |
| E-8 | `_stepState` / `_lineCompleted` 헬퍼 design.md 명세 일치 | PASS | design.md `§단계 상태 계산 로직` 의사코드와 구현 코드 1:1 동일 |

### F. UI 색상 / 아이콘 / 레이아웃 (AppColors 준수)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| F-1 | 완료 단계 원: `AppColors.success` 배경 + `AppColors.onPrimary` 체크 | PASS | `_buildStepNode()` line 1114-1118 |
| F-2 | 현재 단계 원: `AppColors.primary` 배경 + `AppColors.onPrimary` 아이콘 | PASS | `_buildStepNode()` line 1119-1123 |
| F-3 | 미도달 단계 원: `AppColors.surface` + `AppColors.border` 테두리 + `AppColors.textMuted` 아이콘 | PASS | `_buildStepNode()` line 1124-1130 |
| F-4 | 연결선: 완료 `AppColors.success` / 미완료 `AppColors.border` | PASS | `_buildStepLine()` line 1150 |
| F-5 | 라벨: 완료/현재 `AppColors.textHeading` w600 / 미도달 `AppColors.textMuted` w400 | PASS | `_buildStepLabel()` line 1167-1170 |
| F-6 | 타임스탬프: 도달 `AppColors.textMuted` / 미도달 `AppColors.border` | PASS | `_buildStepLabel()` line 1175-1176 |
| F-7 | 섹션 제목 `'주문 진행'`: `AppColors.textHeading` / w700 / 15px | PASS | `order_detail_page.dart:1065-1071` |
| F-8 | 카드 배경 `AppColors.surfaceElevated` / border `AppColors.border` / radius 16 / h16 v20 | PASS | `_OrderProgressIndicator.build()` line 1054-1060 |
| F-9 | 4단계 아이콘 (`receipt_long_rounded` / `local_fire_department_rounded` / `check_circle_outline_rounded` / `shopping_bag_outlined`) | PASS | `_icons` 상수 (line 1017-1022) — design.md 일치 |
| F-10 | 수평 스테퍼 레이아웃: `_StepNode(32) + Expanded(_StepLine) × 3` | PASS | `order_detail_page.dart:1075-1085` |
| F-11 | 라벨 Row: `SizedBox(width:40) × 4 + Spacer() × 3` | PASS | `order_detail_page.dart:1088-1098` |
| F-12 | `order_detail_page.dart` 내 `Color(0x...)` 하드코딩 없음 | PASS | grep 결과 — 해당 파일 내 하드코딩 없음 |
| F-13 | `scaffold_with_nav.dart` 내 `Color(0x...)` 하드코딩 없음 | PASS | grep 결과 — 해당 파일 내 하드코딩 없음 |

### G. Clean Architecture 준수

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| G-1 | presentation 레이어 Firebase 직접 import 없음 | PASS | 검증 대상 파일 4개 모두 firebase import 없음 확인 |
| G-2 | domain 레이어 Firebase 직접 import 없음 | PASS | `remote_notification_message.dart` — firebase import 없음. 주석에서만 언급 |
| G-3 | `flutter analyze` 0 issues | PASS | `No issues found` (검증 시점 재실행 확인) |

### H. F22~F24 기존 inline 안내 카드 유지

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| H-1 | `OrderStatus.making` 환불 차단 안내 카드 유지 | PASS | `_ActionSection` switch `case making:` (line 567-591) 변경 없음 |
| H-2 | `OrderStatus.ready` 환불 차단 안내 카드 유지 | PASS | `_ActionSection` switch `case ready:` (line 593-616) 변경 없음 |
| H-3 | `OrderStatus.accepted` 환불 요청 버튼 분기 유지 | PASS | `case accepted:` (line 513-564) 변경 없음 |

---

## 보류 항목 (라이브 검증 의존)

라이브 검증은 device/emulator 에서 직접 수행해야 한다. 아래 13개 시나리오의 PASS/FAIL 판단은 §라이브 검증 매뉴얼 을 사용자가 직접 실행해 확인해야 한다.

| # | 보류 항목 | 보류 사유 |
|---|---|---|
| L-1 | T1 — `paid→accepted` FCM 발화 확인 | 실 Android device + 배포된 CF 동작 필요 |
| L-2 | T2 — `accepted→making` FCM 발화 확인 | 동상 |
| L-3 | T3 — `making→ready` FCM 발화 확인 | 동상 |
| L-4 | T4 — `ready→completed` FCM 미발화 확인 | 동상 |
| L-5 | T5 — foreground 알림 탭 → customer `OrderDetailPage` push | 동상 |
| L-6 | T5 — background 알림 탭 → customer `OrderDetailPage` push | 동상 |
| L-7 | T5 — terminated 알림 탭 → customer `OrderDetailPage` push (PendingNotificationHolder) | 동상 |
| L-8 | T6~T10 — 진행 인디케이터 단계별 시각 (paid / accepted / making / ready / completed) | 동상 |
| L-9 | T11 — `cancelled` / `refunded` 시 인디케이터 미노출 | 동상 |
| L-10 | T12 — 고객 첫 로그인 → 권한 다이얼로그 노출 → fcmToken 등록 | 동상 |
| L-11 | T13 — 권한 거절 후 재진입 → 다이얼로그 미노출 (sticky) | 동상 |
| L-12 | 회귀 — 점주 OwnerScaffold 권한 흐름 정상 | 동상 |
| L-13 | 회귀 — Phase 3b 환불 알림 (`onOrderRefundRequested`) 정상 발화 | 동상 |

---

## 라이브 검증 매뉴얼 (사용자 실행용)

### 사전 준비

```
1. Android device / emulator (FCM 수신 가능)
2. firebase deploy --only functions 완료 확인
3. 고객 계정 (신규 or Firestore 에서 notificationPermissionPrompted / fcmToken 삭제 후 재사용)
4. 점주 계정
5. 해당 점주 소속 테스트 주문 1건 생성 (결제 완료 → paid 상태)
```

### T1-T4 — FCM 발화 매트릭스

| 시나리오 | 조작 | 기대 결과 | 확인 |
|---|---|---|---|
| T1 | 점주 "주문 받기" | 고객 device 에 "주문이 접수되었어요" 알림 수신. 본문: `{storeName}에서 주문을 받았어요.` (공백 없이 붙여쓰기) | |
| T2 | 점주 "조리 시작" | 고객에 "음료를 만들고 있어요" 알림 수신. 본문: `{storeName}에서 조리를 시작했어요.` | |
| T3 | 점주 "준비 완료" | 고객에 "픽업 준비가 완료됐어요" 알림 수신. 본문: `{storeName}에서 음료가 준비됐어요. 매장에 방문해 주세요.` | |
| T4 | 점주 "픽업 완료" | 고객 device 에 알림 **도착 안 함** (결정 B). 단, `OrderDetailPage` 의 인디케이터는 4단계 완료로 갱신 | |

### T5 — Deep link 검증

| 시나리오 | 조작 | 기대 결과 | 확인 |
|---|---|---|---|
| T5-a (foreground) | T1-T3 중 하나를 수행할 때 고객 앱이 foreground | 로컬 알림 배너 표시 → 탭 → `NotificationNavigator` → 고객 `OrderDetailPage(orderId)` push | |
| T5-b (background) | 고객 앱을 background 로 전환 후 T1-T3 수행 | OS 알림 배너 표시 → 탭 → 앱 포그라운드 전환 + customer `OrderDetailPage` push | |
| T5-c (terminated) | 고객 앱 완전 종료 후 T1-T3 수행 | OS 알림 표시 → 탭 → 앱 cold start → `PendingNotificationHolder` → 첫 빌드 후 customer `OrderDetailPage` push | |

### T6-T11 — 진행 인디케이터

| 시나리오 | 조작 | 기대 결과 | 확인 |
|---|---|---|---|
| T6 | `paid` 상태 주문의 `OrderDetailPage` 진입 | 단계 0 (접수) primary 강조 + 단계 1-3 muted. 타임스탬프 모두 `-` | |
| T7 | `accepted` 상태 | 단계 0 success 완료 + 단계 1 primary 강조. `acceptedAt` HH:mm 표시 | |
| T8 | `making` 상태 | 단계 0,1 success + 라인 0,1 success 채움 + 단계 2 primary 강조 | |
| T9 | `ready` 상태 | 단계 0,1,2 success + 라인 0,1,2 모두 채움 + 단계 3 primary 강조 | |
| T10 | `completed` 상태 | 4단계 모두 success + 타임스탬프 4개 모두 HH:mm 표시 | |
| T11 | `cancelled` 또는 `refunded` 상태 | `_OrderProgressIndicator` 미렌더링. `_CancelInfoSection` 또는 inline 안내 카드만 표시 | |

### T12-T13 — 알림 권한 흐름

| 시나리오 | 조작 | 기대 결과 | 확인 |
|---|---|---|---|
| T12 | 고객 신규 로그인 (또는 Firestore `users/{uid}.notificationPermissionPrompted` 삭제 후 재로그인) → `ScaffoldWithNav` 진입 | `NotificationPermissionDialog` 노출 → "허용" → OS 권한 요청 → 허용 → Firestore `users/{uid}.fcmToken` set + `notificationPermissionPrompted = true` | |
| T13 | T12 완료 후 재로그인 또는 ScaffoldWithNav 재진입 | 다이얼로그 미노출 (sticky 확인) | |

### 회귀 검증

| 항목 | 기대 결과 | 확인 |
|---|---|---|
| 점주 `OwnerScaffold` 알림 권한 흐름 | sub-phase 1 과 동일하게 동작 (변경 없음) | |
| 점주 `OwnerOrderDetailPage._TimelineSection` (vertical) | sub-phase 1 과 동일하게 표시 (변경 없음) | |
| `onOrderRefundRequested` 환불 알림 | Phase 3b 와 동일 (변경 없음) | |

---

## Spec / Design / Implementation 간 Drift 확인

| 항목 | spec.md | design.md | 구현 코드 | 판정 |
|---|---|---|---|---|
| 알림 카피 `paid→accepted` 본문 | `{storeName} 에서 주문을 받았어요.` (공백 있음) | `{storeName}에서 주문을 받았어요.` (공백 없음 — designer 조정) | `${n}에서 주문을 받았어요.` (공백 없음) | design.md 가 spec.md 를 조정 — design.md 확정안 기준으로 구현 일치. **drift 없음** |
| 알림 카피 `accepted→making` | `{storeName} 에서 조리를 시작했어요.` (공백 있음) | `{storeName}에서 조리를 시작했어요.` (공백 없음) | `${n}에서 조리를 시작했어요.` | 동상 — **drift 없음** |
| 알림 카피 `making→ready` | `{storeName} 에서 음료가 준비됐어요. ...` | `{storeName}에서 음료가 준비됐어요. ...` | `${n}에서 음료가 준비됐어요. 매장에 방문해 주세요.` | 동상 — **drift 없음** |
| `_showProgressIndicator` 헬퍼 | cancelled / refunded 시 미노출 | `status != cancelled && status != refunded` | 구현 동일 | **drift 없음** |
| `_stepState` 헬퍼 | timestamp 기반 + index==0 특수 처리 | design.md §단계 상태 계산 로직 명세 | 구현 동일 | **drift 없음** |
| shimmer placeholder height | design.md: height 88 | design.md: 88 | 구현: `height: 88` | **drift 없음** |
| `NotificationNavigator` customer push 분기 | OrderDetailPage push (F14) | 동일 | `OrderDetailPage(orderId: orderId)` | **drift 없음** |

---

## 추가 관찰 사항

### O-1. `NotificationPermissionDialog` 본문 카피 — 점주 중심 문구

`notification_permission_dialog.dart:66-68` 의 본문이 `'새 주문과 환불 요청을 바로 알려드릴게요.'` 로 되어 있다. 이는 점주 관점 알림 문구이다. 고객 관점에서는 `'주문 진행 상황과 픽업 준비 알림을 바로 받아볼 수 있어요.'` 등이 더 적절하다.

본 sub-phase spec 에는 "기존 `NotificationPermissionDialog` 위젯을 재사용" 으로 명시되어 있으므로 이는 spec 범위 내 결정이다. 그러나 고객/점주 공통 다이얼로그를 사용하면 고객 입장에서 내용이 부정확할 수 있다.

- 판정: **spec 범위 내 재사용 결정이므로 FAIL 아님. 후속 개선 후보로 기록.**
- 후속 추천: Phase 3c-3 알림 설정 UI 도입 시 고객/점주 분기 카피 개선 검토.

### O-2. `refundCompleted` status 미처리

검증 대상 작업 지시에서 `refundCompleted` 를 언급했으나, `OrderStatus` enum 에 해당 값이 없다 (`refunded` 만 존재). `_showProgressIndicator` 헬퍼는 `refunded` 만 명시하면 충분하며 현재 코드가 올바른 상태다.

---

## 미해소 보류 항목 정리

| 항목 | 보류 출처 | 처리 경로 |
|---|---|---|
| iOS APNs 검증 | spec 명시 비범위 | `docs/tasks/ios_apns_setup` 별도 task |
| `ready→completed` 옵트인 알림 | 결정 B | Phase 3c-3 알림 설정 UI |
| 알림 설정 UI (toggle) | spec 비범위 | Phase 3c-3 |
| `minInstances` 운영 결정 | sub-phase 1 보완 1 | `cloud_functions_min_instances` task |
| `NotificationPermissionDialog` 고객 카피 개선 | O-1 관찰 | Phase 3c-3 |

---

## 후속 작업 추천 (우선순위 순)

1. **FAIL-1 즉시 수정** — `notification_permission_dialog.dart:14` 의 `Colors.black` → `AppColors.*` 토큰 교체. Phase 3b 회귀이기도 하므로 최우선.
2. **라이브 검증 T1~T13 수행** — 위 §라이브 검증 매뉴얼 순서대로 실행.
3. **spec 완료 기준 문서 갱신** (spec.md §완료 기준 체크리스트 미체크 항목):
   - `entity_lifecycle.md §2.4` customer 알림 진입점 행 추가
   - `role_flows.md §4.1` 알림 수신 행 추가
   - `operations.md` emulator wipe 후 권한 prompt 재발화 운영 가이드 추가
4. **Phase 3c-3 착수** — 알림 설정 UI 도입 + sticky 정책 명시 재요청 경로 제공.
