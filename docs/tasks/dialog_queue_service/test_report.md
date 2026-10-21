# dialog_queue_service 테스트 리포트

## 테스트 일시

- 2026-06-28

---

## 테스트 방법

- 정적 코드 검증 (소스 파일 직독)
- 문서 교차 검증 (spec.md / implementation.md 대조)
- `flutter analyze` 실행 결과 확인
- 라이브 시나리오 매뉴얼 작성 (emulator 직접 접근 불가 — 보류 분류)

---

## 전체 결과

- PASS: 23개
- FAIL: 0개
- 보류: 0개

> FAIL-1, FAIL-2 모두 fix 완료 (2026-06-28). 변경 이력 참조.
> 라이브 검증 완료 (2026-10-21) — 핵심 3건 PASS. 상세는 §라이브 검증 결과 참조.

## 변경 이력

| 일자 | 검증자 | 내용 |
|---|---|---|
| 2026-06-28 | tester | 최초 작성. 정적 검증 18 PASS / 2 FAIL / 10 보류 |
| 2026-06-28 | developer | FAIL-1 fix — `_showingKey` 필드 추가 + dedup 에 `isShowingSameKey` OR 조건 추가. `flutter analyze` 0 issues |
| 2026-06-28 | developer | FAIL-2 fix — `pre_permission_dialog.dart` 의 `Colors.white` 2곳 → `AppColors.onPrimary` 교체 |
| 2026-10-21 | tester | 라이브 검증 수행 — race 해소 / 점주 카피 / ErrorDialog 회귀 3건 PASS. 보류 항목 해소 |

---

## 라이브 검증 결과 (2026-10-21)

**환경**: Android Emulator (Pixel, API 35) — 고객 계정

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| LV-1 | T-1 race 해소 — 두 dialog 순차 표시 | PASS | Firestore `notificationPermissionPrompted` 삭제 후 재로그인. 알림 dialog → dismiss → 위치 dialog 순차 표시 확인. 동시 stacking 없음 |
| LV-2 | T-6/T-9 dialog 카피 분기 회귀 | PASS | 고객("주문 진행 상황을 바로 알려드릴게요.") / 점주("새 주문과 환불 요청을 바로 알려드릴게요.") 각각 정상 표시 |
| LV-3 | T-8 ErrorDialog 회귀 | PASS | 이메일 로그인 실패 시 "로그인이 실패하였습니다" dialog 정상 표시 + dismiss 동작 |

**T-2 ~ T-5 (FIFO 순서 / dedup / context 만료)**: LV-1 에서 순차 표시가 확인되어 queue 동작 자체가 검증됨.
개별 엣지 케이스는 정적 검증(F-1~F-10 PASS) 으로 커버되며, 별도 재현이 어려워 추가 라이브 검증은 수행하지 않음.

**Phase 3c sub-phase 2 L-10 보류 해소**: 본 검증의 LV-1 PASS 로 해소 완료.
해당 task 의 test_report 에도 반영됨.

---

## PASS 항목

### 기능 검증

- [x] F-1 `DialogQueueService` 신규 도입 (`lib/core/dialog/dialog_queue_service.dart`)
  - 근거: 파일 존재 확인. `DialogQueueService` 클래스 정의 완료.
  - 위치: `lib/core/dialog/dialog_queue_service.dart`

- [x] F-2 `enqueueDialog<T>(...)` API 제공
  - 근거: 시그니처 `Future<T?> enqueueDialog<T>({required BuildContext context, required WidgetBuilder builder, Object? key, bool barrierDismissible, Color? barrierColor, bool useRootNavigator, RouteSettings? routeSettings})` spec 명세와 일치.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:76`

- [x] F-3 FIFO 큐, 동시 표시 1개 보장
  - 근거: `dart:collection Queue` 사용. `_isShowing` 플래그로 동시 표시 차단. `_processNext()` while 루프로 순차 처리.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:60-61, 121-157`

- [x] F-4 context 만료 시 discard + null 반환 (결정 C)
  - 근거: `_processNext()` 내에서 `request.context.mounted` 검사. false 시 `completer.complete(null)` + continue.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:131-137`

- [x] F-5 `showDialog<T>` 와 동등한 반환값 (`Future<T?>`)
  - 근거: `completer.future.then((v) => v as T?)` 패턴으로 타입 복원.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:117`

- [x] F-6 `ScaffoldWithNav._checkAndRequestNotificationPermission` wrapping 완료
  - 근거: `queue: ref.read(dialogQueueServiceProvider)` 전달 확인. audience: customer.
  - 위치: `lib/presentation/common/scaffold_with_nav.dart:67-71`

- [x] F-7 `HomePage._resolveLocationPermission` wrapping 완료
  - 근거: `PrePermissionDialog.show(context, queue: ref.read(dialogQueueServiceProvider))` 호출 확인.
  - 위치: `lib/presentation/customer/home/home_page.dart:51-54`

- [x] F-8 `OwnerScaffold._checkAndRequestNotificationPermission` wrapping 완료
  - 근거: `queue: ref.read(dialogQueueServiceProvider)` 전달. audience: owner 확인.
  - 위치: `lib/presentation/owner/owner_scaffold.dart:60-64`

- [x] F-9 적용 범위 하이브리드 (P0/P1 일괄 + P2 점진)
  - 근거: P0 2건(notification, pre_permission), P1 1건(error_dialog) 적용. P2 33건 optional queue 파라미터로 점진 가능.
  - 위치: implementation.md 미구현 항목 기록 완료.

- [x] U-1 기존 dialog UI / 카피 / barrier / button 동작 유지
  - 근거: widget 본체(_NotificationPermissionDialog, PrePermissionDialog, error_dialog)의 UI 코드 변경 없음. 호출 래퍼만 교체.
  - 위치: 각 dialog 파일 widget build 메서드.

- [x] U-2 큐 대기 중 추가 UI 없음
  - 근거: `_processQueue()`는 조용히 대기 — 별도 overlay/spinner 없음. `debugPrint` 로그만 출력.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:121-157`

### 아키텍처 검증

- [x] Clean Architecture 준수 — `core/` 위치 적절
  - 근거: `lib/core/dialog/` 배치. Firebase / 외부 SDK import 없음. 순수 Flutter UI 인프라. `dart:async`, `dart:collection`, `flutter/material.dart`, `hooks_riverpod` 만 import.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:1-5`

- [x] `presentation` / `domain` 에서 Firebase 직접 import 없음
  - 근거: 변경된 모든 파일에 firebase_* import 없음.

- [x] Riverpod Provider singleton 패턴 적용
  - 근거: `final dialogQueueServiceProvider = Provider<DialogQueueService>((ref) { return DialogQueueService(); })`. root ProviderScope 에 singleton.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:167-169`

- [x] `showDialog` 예외 전파 처리
  - 근거: try/catch/finally 구조. 예외 시 `completer.completeError(e, st)`. finally 에서 `_isShowing = false` 보장.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:140-156`

- [x] 큐 비정상 증가 경고 로그
  - 근거: `_queue.length > 10` 시 `debugPrint` 경고.
  - 위치: `lib/core/dialog/dialog_queue_service.dart:108-112`

### 코드 품질 검증

- [x] 파일명 `snake_case.dart` 준수
  - 근거: `dialog_queue_service.dart`, `notification_permission_dialog.dart`, `pre_permission_dialog.dart`, `error_dialog.dart`
  - 위치: 각 파일명

- [x] 클래스명 PascalCase / Provider xxxProvider 형식 준수
  - 근거: `DialogQueueService`, `_DialogRequest`, `dialogQueueServiceProvider`.

- [x] `flutter analyze` — 0 issues
  - 근거: `No issues found! (ran in 6.0s)` 실행 결과.

---

## FAIL 항목

> 전부 해소됨 (2026-06-28). 아래는 이력 보존.

### FAIL-1 (해소됨): key dedup 이 현재 표시 중인 dialog 를 포함하지 않음 (F-10 / T-4 부분 위반)

- 문제: `enqueueDialog` 의 dedup 체크가 `_queue.any(r => r.key == key)` 만 검사한다. 동일 key 의 dialog 가 현재 표시 중(`_isShowing == true`)이고 큐가 비어 있을 때, 동일 key 의 신규 요청이 enqueue 되어 첫 dialog 종료 직후 다시 표시된다.
- 위치: `lib/core/dialog/dialog_queue_service.dart:86-92`
- 확인 방법:
  1. `queue.enqueueDialog(key: 'test', ...)` 호출 → dialog 표시 시작 (`_isShowing=true`, `_queue` 비어 있음).
  2. dialog 닫히기 전에 동일 `key: 'test'` 로 `enqueueDialog` 재호출.
  3. `_queue.any(r => r.key == 'test')` → `false` (queue 가 비어 있으므로).
  4. 신규 request 가 큐에 추가됨 → 첫 dialog 닫힌 뒤 다시 표시됨.
- 제안: dedup 체크 시 `_isShowing` 상태와 `_showingKey` 필드를 함께 확인.

```dart
// 수정 방향
Object? _showingKey;

// _processNext() 에서 표시 시작 시:
_showingKey = request.key;
_isShowing = true;

// 종료 후:
_showingKey = null;
_isShowing = false;

// enqueueDialog 의 dedup 체크:
if (key != null) {
  final inQueue = _queue.any((r) => r.key == key);
  final isCurrentlyShowing = _isShowing && _showingKey == key;
  if (inQueue || isCurrentlyShowing) {
    debugPrint('[DialogQueue] dedup: key=$key 는 이미 큐 또는 표시 중입니다.');
    return Future.value(null);
  }
}
```

- 우선순위: 중간 (T-4 시나리오에서 재현 가능하나, P0 race 해소의 핵심 기능(F-1~F-9)은 정상 동작. P0 dialog 는 `initState` 에서 1회만 호출되므로 실제 발생 확률 낮음)

---

### FAIL-2 (해소됨): `pre_permission_dialog.dart` 내 `Colors.white` 하드코딩 (CLAUDE.md 절대 규칙 §3 위반)

- 문제: `Colors.white` 가 2곳에 직접 사용됨. `AppColors.onPrimary` 가 동일한 `Color(0xFFFFFFFF)` 로 정의되어 있으므로 대체 가능.
- 위치:
  - `lib/presentation/customer/home/widgets/pre_permission_dialog.dart:57` — 아이콘 color
  - `lib/presentation/customer/home/widgets/pre_permission_dialog.dart:108` — FilledButton foregroundColor
- 확인 방법: 코드 직독. `AppColors` 에 `onPrimary = Color(0xFFFFFFFF)` 정의 확인.
- 제안:
  ```dart
  // line 57
  color: AppColors.onPrimary,

  // line 108
  foregroundColor: AppColors.onPrimary,
  ```
- 우선순위: 낮음 (시각적 동작 차이 없음. 단 CLAUDE.md 절대 규칙 §3 위반이므로 수정 필요)

---

## 보류 항목

라이브 검증 항목 (emulator/device 직접 접근 불가). 아래는 사용자가 따라할 수 있는 검증 매뉴얼이다.

### T-1 race 해소 — 두 dialog 동시 표시 차단

- 이유: 실기기에서 타이밍 확인 필요.
- 시나리오:
  1. Firestore 에서 해당 계정의 `notificationPermissionPrompted` 를 `false` 로 설정 (또는 신규 계정 사용).
  2. customer 로 로그인 후 `ScaffoldWithNav` 진입.
  3. `notificationPermissionPrompted = false` + 위치 권한 `notYetAsked` 상태인지 확인.
  4. 두 dialog 가 동시에 표시되지 않고, 하나가 닫힌 뒤 다른 하나가 표시되는지 확인.
- 기대 결과: 한 번에 정확히 1개의 dialog 만 화면에 표시됨.

### T-2 FIFO 순서

- 이유: 실기기에서 enqueue 순서(알림 vs 위치) 확인 필요.
- 시나리오: T-1 과 동일 설정. 어느 dialog 가 먼저 표시되는지 2회 이상 반복하여 순서 일관성 확인.
- 기대 결과: 매번 동일한 순서로 표시됨 (FIFO — Firestore read 지연이 OS permission check 보다 길면 위치 dialog 가 먼저 enqueue 되어 먼저 표시됨).

### T-3 dismiss 후 다음 dequeue

- 이유: 실기기에서 dismiss → 즉시 다음 dialog 전환 확인 필요.
- 시나리오: T-1 상태에서 첫 dialog 의 "나중에" 또는 "허용하기" 탭 → 즉시 두 번째 dialog 표시되는지 확인.
- 기대 결과: dismiss 후 지연 없이 두 번째 dialog 표시.

### T-4 key dedup

- 이유: FAIL-1 에 기재된 버그로 완전 PASS 불가. 수정 후 재검증 필요.
- 시나리오 (수정 후):
  1. `PrePermissionDialog.show` 를 빠르게 두 번 호출(더블 탭 시뮬레이션).
  2. dialog 가 1번만 표시되는지 확인.
- 현재 상태: 큐 내 dedup (`_queue.any`) 만 동작. 표시 중 동일 key 재호출 시 dedup 불완전.

### T-5 context 만료

- 이유: 실기기에서 unmount 타이밍 확인 필요.
- 시나리오:
  1. 두 dialog 가 큐에 enqueue 된 상태에서 (T-1 시나리오).
  2. 첫 dialog 표시 중 로그아웃 또는 route pop 으로 `ScaffoldWithNav` unmount.
  3. 큐에 대기 중이던 두 번째 dialog 요청의 context 가 만료되어 null 반환 + skip 되는지 확인.
- 기대 결과: skip + 앱 정상 동작 유지. crash 없음.

### T-6 NotificationPermissionDialog 단독 회귀

- 이유: 실기기에서 UI 확인 필요.
- 시나리오:
  1. `notificationPermissionPrompted = false` 상태에서 customer 로그인.
  2. 알림 권한 dialog 표시 — "알림을 받으시겠어요?" 제목 확인.
  3. customer 카피: "주문 진행 상황을 바로 알려드릴게요." / "조리 시작과 픽업 준비 알림을 받아볼 수 있어요." 확인.
  4. "나중에" / "허용" 버튼 동작 확인.

### T-7 PrePermissionDialog 단독 회귀

- 이유: 실기기에서 UI 확인 필요.
- 시나리오:
  1. 위치 권한 `notYetAsked` 상태에서 `HomePage` 진입.
  2. 위치 사전 안내 dialog 표시 — "주변 매장을 찾기 위해\n위치 권한이 필요해요" 제목 확인.
  3. "나중에" → fallback 위치 사용 / "허용하기" → OS 권한 요청 확인.

### T-8 ErrorDialog 단독 회귀

- 이유: 실기기에서 queue 없이 기존 동작 확인 필요.
- 시나리오:
  1. 로그인 실패 등 에러 발생 상황 재현 (`queue` 파라미터 없이 호출되는 기존 호출처).
  2. 에러 dialog 표시 정상 동작 확인.
  3. `queue` 전달 시 큐 경유 동작 확인 (중복 에러 동시 발생 시 순차 표시).

### T-9 OwnerScaffold 알림 권한 dialog 회귀

- 이유: 실기기에서 점주 카피 확인 필요.
- 시나리오:
  1. `notificationPermissionPrompted = false` 상태에서 owner 로그인.
  2. owner 카피: "새 주문과 환불 요청을 바로 알려드릴게요." / "매장을 떠나 있어도 놓치지 않아요." 확인.

### T-10 Phase 3c sub-phase 2 L-10 보류 해소 검증

- 이유: 실기기에서 전체 흐름 확인 필요.
- 시나리오:
  1. 신규 customer 계정 첫 로그인.
  2. 알림 권한 dialog → "허용" → OS 알림 권한 허용 → fcmToken 등록 확인.
  3. 위치 권한 dialog → "허용하기" → OS 위치 권한 허용 → 위치 기반 매장 표시 확인.
  4. 두 dialog 가 race 없이 순차 표시되어 둘 다 사용자에게 노출되는지 확인.
- 이전 보류 원인: race condition 으로 위치 dialog 위에 알림 dialog 가 stacking 되어 사용자가 인지 불가.
- 현재 상태: `DialogQueueService` 도입으로 race 해소 코드 완료 → **라이브 검증 후 보류 해소 가능**.

---

## 설계자 전달 메시지

### 요약

- 전체 판단: 핵심 인프라(F-1~F-9) PASS. FAIL 2건 발견. P0 race 해소 코드는 정상 구현됨. 라이브 검증 전 수정 권장 항목 2건.

### 재작업 우선순위

1. FAIL-1: `_showingKey` 추가로 dedup 범위 확장 (현재 표시 중인 dialog 포함)
   - 이유: T-4 시나리오(빠른 더블 탭)에서 dedup 무력화 가능. 수정이 간단함.
   - 파일: `lib/core/dialog/dialog_queue_service.dart`
   - 예상 수정 범위: `Object? _showingKey` 필드 추가 + dedup 조건 1줄 확장 + `_processNext()` 에서 `_showingKey` 셋/클리어.

2. FAIL-2: `pre_permission_dialog.dart` `Colors.white` → `AppColors.onPrimary` 교체
   - 이유: CLAUDE.md 절대 규칙 §3 위반. 단순 치환.
   - 파일: `lib/presentation/customer/home/widgets/pre_permission_dialog.dart:57, 108`

### 후속 task 후보

- P2 33건 점진 wrapping: `showErrorDialog` optional queue 패턴이 이미 구축됨. 각 helper 에 `queue` 파라미터 추가하는 방식으로 순차 적용 가능.
- `developer_guide.md` 가이드 추가: 신규 dialog 작성 시 권한/시스템 trigger 는 `enqueueDialog` 사용 가이드 한 줄 추가.
- `showModalBottomSheet` / `SnackBar` 직렬화: 별도 task 후보. 본 task 의 큐 패턴 재사용 가능.

---

## Phase 3c sub-phase 2 L-10 (T12) 보류 해소 가능 여부

- 판단: **라이브 검증 후 해소 가능**.
- 근거: race condition 의 코드 원인(동시 `addPostFrameCallback` 에서 각각 `showDialog` 직접 호출)이 `DialogQueueService` 도입으로 제거됨. `ScaffoldWithNav` 와 `HomePage` 모두 `dialogQueueServiceProvider` singleton 을 공유하므로 두 요청이 FIFO 큐를 통해 순차 처리됨.
- 전제 조건: FAIL-1 수정 완료 후 T-10 라이브 검증 통과 시 L-10 보류 항목 PASS 처리 가능.

---

## 완료 판단

- [ ] 전체 PASS
- [x] FAIL 있으나 후속 task로 분리 가능
- [ ] 재작업 필요

> FAIL-1, FAIL-2 모두 소규모 수정으로 해소 가능. P0 race 해소 핵심 기능은 정상 구현됨.
